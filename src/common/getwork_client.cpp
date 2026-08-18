#include "getwork_client.h"
#include "Debug.h"
#include <cstring>
#include <unistd.h>
#include <sstream>
#include <utility>

#ifdef HAVE_LIBWEBSOCKETS

// Forward declaration of callback
static int wsCallbackImpl(struct lws* wsi, enum lws_callback_reasons reason,
                          void* user, void* in, size_t len);

// WebSocket protocol definition (must be defined before use in attemptReconnect)
static struct lws_protocols protocols[] = {
    {
        "getwork-protocol",
        wsCallbackImpl,
        0,
        4096,
    },
    { NULL, NULL, 0, 0 } // terminator
};

// WebSocket callback implementation (static wrapper)
static int wsCallbackImpl(struct lws* wsi, enum lws_callback_reasons reason,
                          void* user, void* in, size_t len) {
    return GetWorkContext::wsCallback(wsi, reason, user, in, len);
}

// WebSocket callback function
int GetWorkContext::wsCallback(struct lws* wsi, enum lws_callback_reasons reason,
                               void* user, void* in, size_t len) {
    GetWorkContext* ctx = (GetWorkContext*)lws_context_user(lws_get_context(wsi));

    switch (reason) {
        case LWS_CALLBACK_CLIENT_ESTABLISHED: {
            bool becameConnected = false;
            pthread_mutex_lock(&ctx->_mutex);
            if (ctx->_connectionState == ConnectionState::Connecting &&
                ctx->_wsi == wsi) {
                ctx->_connectionState = ConnectionState::Connected;
                ctx->_lastMessageTime = time(0);
                ctx->_lastRequestTime = ctx->_lastMessageTime;
                becameConnected = true;
            }
            bool isActive = ctx->_connectionState == ConnectionState::Connected &&
                            ctx->_wsi == wsi;
            pthread_mutex_unlock(&ctx->_mutex);

            if (!isActive) {
                logFormattedWrite(ctx->_log,
                                  "Ignoring stale WebSocket connection callback");
                return -1;
            }

            if (becameConnected) {
                logFormattedWrite(ctx->_log, "WebSocket connection established");
            }
            // Request write callback to send data
            lws_callback_on_writable(wsi);
            break;
        }

        case LWS_CALLBACK_CLIENT_RECEIVE:
            pthread_mutex_lock(&ctx->_mutex);
            {
                bool isActive =
                    ctx->_connectionState == ConnectionState::Connected &&
                    ctx->_wsi == wsi;
                pthread_mutex_unlock(&ctx->_mutex);
                if (!isActive) {
                    return -1;
                }
            }
            if (in && len > 0) {
                ctx->onMessage((const char*)in, len);
            }
            break;

        case LWS_CALLBACK_CLIENT_WRITEABLE:
        {
            // PRIORITY 1: Check for high-priority getwork request first
            pthread_mutex_lock(&ctx->_mutex);
            bool isActive =
                ctx->_connectionState == ConnectionState::Connected &&
                ctx->_wsi == wsi;
            if (!isActive) {
                pthread_mutex_unlock(&ctx->_mutex);
                return -1;
            }
            bool needsGetwork = ctx->_pendingGetwork;
            if (needsGetwork) {
                ctx->_pendingGetwork = false;  // Clear flag
            }
            pthread_mutex_unlock(&ctx->_mutex);

            if (needsGetwork) {
                // Send getwork immediately (bypasses submit queue)
                ctx->sendGetWorkInternal(wsi);
                // Check if there are still pending submits to process
                pthread_mutex_lock(&ctx->_queueMutex);
                bool hasSubmits = !ctx->_pendingMessages.empty();
                pthread_mutex_unlock(&ctx->_queueMutex);
                if (hasSubmits) {
                    lws_callback_on_writable(wsi);  // Schedule next write for submits
                }
                break;
            }

            // PRIORITY 2: Process pending submit messages from the queue
            pthread_mutex_lock(&ctx->_queueMutex);
            if (!ctx->_pendingMessages.empty()) {
                std::string msg = ctx->_pendingMessages.front();
                ctx->_pendingMessages.pop();
                bool hasMore = !ctx->_pendingMessages.empty();
                pthread_mutex_unlock(&ctx->_queueMutex);

                // Write the queued message
                unsigned char buf[LWS_PRE + 4096];
                size_t len = msg.length();
                if (len > 0 && len < 4096) {
                    memcpy(&buf[LWS_PRE], msg.c_str(), len);
                    lws_write(wsi, &buf[LWS_PRE], len, LWS_WRITE_TEXT);
                }

                // If more messages in queue, request another callback
                if (hasMore) {
                    lws_callback_on_writable(wsi);
                }
            } else {
                pthread_mutex_unlock(&ctx->_queueMutex);
                // No pending messages, send periodic getwork request
                ctx->sendGetWorkInternal(wsi);
            }
            break;
        }

        case LWS_CALLBACK_EVENT_WAIT_CANCELLED:
            // Called when lws_cancel_service() wakes us up from another thread
            // This is the thread-safe way to trigger writes from mining thread
            pthread_mutex_lock(&ctx->_mutex);
            if (ctx->_hasPendingWrites && ctx->_wsi &&
                ctx->_connectionState == ConnectionState::Connected) {
                ctx->_hasPendingWrites = false;
                struct lws* local_wsi = ctx->_wsi;
                pthread_mutex_unlock(&ctx->_mutex);
                // Now safe - we're in lws thread, can call lws_callback_on_writable
                lws_callback_on_writable(local_wsi);
            } else {
                pthread_mutex_unlock(&ctx->_mutex);
            }
            break;

        case LWS_CALLBACK_CLOSED:
            ctx->handleDisconnect(wsi, "WebSocket connection closed");
            break;

        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
            ctx->handleDisconnect(wsi, "WebSocket connection error");
            break;

        case LWS_CALLBACK_WSI_DESTROY:
        case LWS_CALLBACK_CLIENT_CLOSED:
            // Additional disconnect callbacks that may fire instead of CLOSED
            ctx->handleDisconnect(wsi, "WebSocket destroyed/closed (callback)");
            break;

        default:
            break;
    }

    return 0;
}

// Parse incoming JSON-RPC message
void GetWorkContext::onMessage(const char* data, size_t len) {
    // Update last message time for timeout detection
    pthread_mutex_lock(&_mutex);
    _lastMessageTime = time(0);
    pthread_mutex_unlock(&_mutex);

    // Only log full message in debug mode
    // logFormattedWrite(_log, "Received message (%zu bytes): %.*s", len, (int)len, data);

    json_error_t error;
    json_t* root = json_loadb(data, len, 0, &error);

    if (!root) {
        logFormattedWrite(_log, "Failed to parse JSON: %s", error.text);
        return;
    }

    json_t* responseIdValue = json_object_get(root, "id");
    const int responseId =
        responseIdValue && json_is_integer(responseIdValue) ?
            (int)json_integer_value(responseIdValue) : -1;
    auto releaseSubmissionReservation = [&]() {
        pthread_mutex_lock(&_mutex);
        if (_hasSubmittedForWork && _submittedRpcId == responseId) {
            _hasSubmittedForWork = false;
        }
        pthread_mutex_unlock(&_mutex);
    };

    // Check for error in response
    json_t* jerror = json_object_get(root, "error");
    if (jerror && !json_is_null(jerror)) {
        const char* errMsg = json_string_value(json_object_get(jerror, "message"));
        releaseSubmissionReservation();
        logFormattedWrite(_log, "RPC error: %s", errMsg ? errMsg : "unknown");
        json_decref(root);
        return;
    }

    // Get result
    json_t* result = json_object_get(root, "result");
    if (!result) {
        json_decref(root);
        return;
    }

    // Boolean results are submit responses.
    if (json_is_boolean(result)) {
        const bool accepted = json_is_true(result);
        if (accepted) {
            logFormattedWrite(_log, "Block submission accepted");
        } else {
            releaseSubmissionReservation();
            logFormattedWrite(_log, "Block submission rejected");
        }
        json_decref(root);

        if (!accepted)
            return;

        // We're already in lws thread, so directly request new work
        // (don't use triggerRefresh() which would call lws_cancel_service from within lws thread)
        pthread_mutex_lock(&_mutex);
        _needsRefresh = true;
        struct lws* wsi = _wsi;
        pthread_mutex_unlock(&_mutex);

        if (wsi) {
            lws_callback_on_writable(wsi);  // Safe - we're in lws thread
        }
        return;
    }

    // Check if this is an error/string response (like "insufficient work", "stale work")
    if (json_is_string(result)) {
        const char* msg = json_string_value(result);

        // Throttle "stale work" log spam - only log once per block height
        if (msg && strcmp(msg, "stale work") == 0) {
            static uint64_t lastStaleLogHeight = 0;

            pthread_mutex_lock(&_mutex);
            const bool appliesToCurrentWork =
                _hasSubmittedForWork && _submittedRpcId == responseId &&
                _submittedWorkId == _workId;
            uint64_t currentHeight = _currentWork.height;
            bool shouldLog = appliesToCurrentWork &&
                             currentHeight != lastStaleLogHeight;
            if (shouldLog)
                lastStaleLogHeight = currentHeight;
            if (appliesToCurrentWork) {
                // Stop mining until new work arrives.
                _hasWork = false;
                _workId++;
                _hasSubmittedForWork = false;
                _needsRefresh = true;

                // The mutex ordering matches submitWork(), preventing an old
                // response from clearing a newer work item's queued solution.
                pthread_mutex_lock(&_queueMutex);
                while (!_pendingMessages.empty()) {
                    _pendingMessages.pop();
                }
                pthread_mutex_unlock(&_queueMutex);
            }
            struct lws* wsi = appliesToCurrentWork ? _wsi : nullptr;
            pthread_mutex_unlock(&_mutex);

            if (shouldLog) {
                logFormattedWrite(_log,
                                  "Block submission became stale after work advanced (height %lu)",
                                  currentHeight);
            }

            json_decref(root);

            if (wsi) {
                lws_callback_on_writable(wsi);  // Safe - we're in lws thread
            }
            return;
        }

        // For other errors, log normally
        // The node rejected this solution without advancing the work, so allow
        // a later candidate for the same work to be submitted.
        releaseSubmissionReservation();
        logFormattedWrite(_log, "Block submission failed: %s", msg);
        json_decref(root);
        return;
    }

    // Otherwise, parse work fields (getwork response)
    pthread_mutex_lock(&_mutex);

    JsonWork newWork;
    json_t* parentHash = json_object_get(result, "parent_hash");
    json_t* height = json_object_get(result, "height");
    json_t* difficulty = json_object_get(result, "difficulty");
    json_t* merkle = json_object_get(result, "merkle");
    json_t* nonce = json_object_get(result, "nonce");

    if (parentHash && json_is_string(parentHash)) {
        newWork.parentHash = json_string_value(parentHash);
    }
    if (height && json_is_integer(height)) {
        newWork.height = json_integer_value(height);
    }
    if (difficulty && json_is_integer(difficulty)) {
        newWork.difficulty = json_integer_value(difficulty);
    }
    if (merkle && json_is_string(merkle)) {
        newWork.merkle = json_string_value(merkle);
    }
    if (nonce && json_is_integer(nonce)) {
        newWork.nonce = json_integer_value(nonce);
    }

    // Update current work if valid
    if (newWork.isValid()) {
        bool changed = (_currentWork.parentHash != newWork.parentHash ||
                       _currentWork.height != newWork.height);
        _currentWork = newWork;
        if (changed) {
            _workId++;
            _hasSubmittedForWork = false;
            _needsRefresh = false;  // Clear refresh flag when we get new work

            // Clear pending message queue - old submissions are for previous block
            pthread_mutex_lock(&_queueMutex);
            while (!_pendingMessages.empty()) {
                _pendingMessages.pop();
            }
            pthread_mutex_unlock(&_queueMutex);

            logFormattedWrite(_log, "NEW WORK: height=%lu difficulty=%lu parent_hash=%s",
                            newWork.height, newWork.difficulty, newWork.parentHash.c_str());
        }
        _hasWork = true;
        // logFormattedWrite(_log, "Work updated successfully, _hasWork=true");
    } else {
        logFormattedWrite(_log, "WARNING: Received invalid work (missing required fields)");
    }

    pthread_mutex_unlock(&_mutex);
    json_decref(root);
}

// Internal: Send getwork request (called from callback with valid wsi)
void GetWorkContext::sendGetWorkInternal(struct lws* wsi) {
    pthread_mutex_lock(&_mutex);
    int id = _rpcId++;
    pthread_mutex_unlock(&_mutex);

    json_t* request = json_object();
    if (!request) {
        logFormattedWrite(_log, "ERROR: Failed to create JSON object");
        return;
    }

    json_object_set_new(request, "jsonrpc", json_string("2.0"));
    json_object_set_new(request, "id", json_integer(id));
    json_object_set_new(request, "method", json_string("blocktree.get_work"));
    json_object_set_new(request, "params", json_array());

    char* requestStr = json_dumps(request, JSON_COMPACT);
    json_decref(request);

    if (!requestStr) {
        logFormattedWrite(_log, "ERROR: json_dumps failed");
        return;
    }

    unsigned char buf[LWS_PRE + 4096];
    size_t len = strlen(requestStr);
    if (len == 0 || len >= 4096) {
        logFormattedWrite(_log, "ERROR: Invalid request length: %zu", len);
        free(requestStr);
        return;
    }

    memcpy(&buf[LWS_PRE], requestStr, len);
    int wrote = lws_write(wsi, &buf[LWS_PRE], len, LWS_WRITE_TEXT);

    if (wrote < 0) {
        logFormattedWrite(_log, "ERROR: lws_write failed with code %d", wrote);
    }

    free(requestStr);
}

// Public: Trigger a getwork request
void GetWorkContext::sendGetWork() {
    pthread_mutex_lock(&_mutex);
    bool shouldSend = (_connectionState == ConnectionState::Connected &&
                       _wsi != nullptr);
    if (shouldSend) {
        _hasPendingWrites = true;  // Signal pending write
        _pendingGetwork = true;    // Mark as high-priority getwork request
    }
    pthread_mutex_unlock(&_mutex);

    if (shouldSend) {
        lws_cancel_service(_wsContext);  // Thread-safe wake up
    }
}

#endif // HAVE_LIBWEBSOCKETS

void GetWorkContext::handleDisconnect(struct lws* wsi, const char* message) {
#ifdef HAVE_LIBWEBSOCKETS
    bool wasActive = false;

    pthread_mutex_lock(&_mutex);
    if (_wsi == wsi) {
        wasActive = true;
        _wsi = nullptr;
        _connectionState = ConnectionState::Disconnected;
        _hasPendingWrites = false;
        _pendingGetwork = false;
        _needsRefresh = false;
        if (_hasWork) {
            _hasWork = false;
            _workId++;  // Signal work changed (triggers mining loop restart)
        }
        _hasSubmittedForWork = false;
    }
    pthread_mutex_unlock(&_mutex);

    // A single connection can emit CLOSED, CLIENT_CLOSED, and WSI_DESTROY.
    // Only the callback for the active socket is allowed to mutate shared state.
    if (!wasActive) {
        return;
    }

    logFormattedWrite(_log, "%s", message);

    // Old submissions are worthless after disconnect.
    pthread_mutex_lock(&_queueMutex);
    while (!_pendingMessages.empty()) {
        _pendingMessages.pop();
    }
    pthread_mutex_unlock(&_queueMutex);
#else
    (void)wsi;
    (void)message;
#endif
}

// Attempt to reconnect to WebSocket server
void GetWorkContext::attemptReconnect() {
#ifdef HAVE_LIBWEBSOCKETS
    pthread_mutex_lock(&_mutex);
    if (_stopRequested || _connectionState != ConnectionState::Disconnected) {
        pthread_mutex_unlock(&_mutex);
        return;
    }
    _connectionState = ConnectionState::Connecting;
    _lastReconnectAttempt = time(0);
    pthread_mutex_unlock(&_mutex);

    logFormattedWrite(_log, "Attempting WebSocket connection...");

    // Try to establish new connection
    struct lws_client_connect_info ccinfo;
    memset(&ccinfo, 0, sizeof(ccinfo));

    ccinfo.context = _wsContext;
    ccinfo.address = _host.c_str();
    ccinfo.port = _port;
    ccinfo.path = _path.c_str();
    ccinfo.host = _host.c_str();
    ccinfo.origin = _host.c_str();
    ccinfo.protocol = protocols[0].name;
    ccinfo.ssl_connection = 0; // No SSL for ws://

    struct lws* new_wsi = lws_client_connect_via_info(&ccinfo);

    pthread_mutex_lock(&_mutex);
    if (_connectionState == ConnectionState::Connecting) {
        if (new_wsi) {
            // ESTABLISHED is delivered later by lws_service; record the only
            // socket whose callbacks are allowed to mutate this context.
            _wsi = new_wsi;
        } else {
            _connectionState = ConnectionState::Disconnected;
            _wsi = nullptr;
        }
    }
    pthread_mutex_unlock(&_mutex);

    if (!new_wsi) {
        logFormattedWrite(_log, "WebSocket connection attempt failed");
    } else {
        logFormattedWrite(_log, "WebSocket connection initiated");
    }
#endif
}

#ifdef HAVE_LIBWEBSOCKETS
void GetWorkContext::serviceTimerCallback(lws_sorted_usec_list_t* sul) {
    ServiceTimer* timer = lws_container_of(sul, ServiceTimer, sul);
    GetWorkContext* ctx = timer->owner;
    const time_t now = time(0);

    pthread_mutex_lock(&ctx->_mutex);
    bool stopRequested = ctx->_stopRequested;
    ConnectionState state = ctx->_connectionState;
    struct lws* wsi = ctx->_wsi;
    time_t lastMsg = ctx->_lastMessageTime;
    time_t lastRequest = ctx->_lastRequestTime;
    time_t lastReconnect = ctx->_lastReconnectAttempt;
    pthread_mutex_unlock(&ctx->_mutex);

    if (stopRequested) {
        return;
    }

    // A timed-out socket must be closed before another connection is
    // started. Its close callback transitions Disconnecting -> Disconnected.
    if (state == ConnectionState::Connected && wsi &&
        (now - lastMsg) > 30) {
        bool closeActiveSocket = false;
        pthread_mutex_lock(&ctx->_mutex);
        if (ctx->_connectionState == ConnectionState::Connected &&
            ctx->_wsi == wsi) {
            ctx->_connectionState = ConnectionState::Disconnecting;
            ctx->_hasPendingWrites = false;
            ctx->_pendingGetwork = false;
            if (ctx->_hasWork) {
                ctx->_hasWork = false;
                ctx->_workId++;
            }
            ctx->_hasSubmittedForWork = false;
            closeActiveSocket = true;
        }
        pthread_mutex_unlock(&ctx->_mutex);

        if (closeActiveSocket) {
            logFormattedWrite(ctx->_log,
                              "Connection timeout - no messages for %ld seconds",
                              now - lastMsg);
            lws_set_timeout(wsi, PENDING_TIMEOUT_CLOSE_SEND,
                            LWS_TO_KILL_ASYNC);
        }
    } else if (state == ConnectionState::Connected && wsi &&
               now - lastRequest >= 20) {
        // Connected: request new work periodically.
        pthread_mutex_lock(&ctx->_mutex);
        ctx->_lastRequestTime = now;
        pthread_mutex_unlock(&ctx->_mutex);
        lws_callback_on_writable(wsi);
    } else if (state == ConnectionState::Disconnected &&
               now - lastReconnect >= 5) {
        ctx->attemptReconnect();
    }

    lws_sul_schedule(ctx->_wsContext, 0, &ctx->_serviceTimer.sul,
                     serviceTimerCallback, LWS_US_PER_SEC);
}
#endif

// Thread function
void* GetWorkContext::runThread(void* arg) {
    GetWorkContext* ctx = (GetWorkContext*)arg;

#ifdef HAVE_LIBWEBSOCKETS
    if (!ctx->_wsContext) {
        logFormattedWrite(ctx->_log,
                          "ERROR: WebSocket context was not initialized");
        return nullptr;
    }

    pthread_mutex_lock(&ctx->_mutex);
    ctx->_lastRequestTime = time(0);
    ctx->_lastReconnectAttempt = ctx->_lastRequestTime;
    pthread_mutex_unlock(&ctx->_mutex);

    ctx->attemptReconnect();
    lws_sul_schedule(ctx->_wsContext, 0, &ctx->_serviceTimer.sul,
                     serviceTimerCallback, LWS_US_PER_SEC);

    while (true) {
        pthread_mutex_lock(&ctx->_mutex);
        bool stopRequested = ctx->_stopRequested;
        pthread_mutex_unlock(&ctx->_mutex);

        if (stopRequested) {
            break;
        }

        // Since libwebsockets 3.2 the timeout argument is ignored; its own
        // scheduler wakes this service call for connection maintenance.
        if (ctx->_wsContext) {
            lws_service(ctx->_wsContext, 0);
        }
    }

    // lws_sul_cancel() is not available in older distro releases such as
    // libwebsockets 4.3.  Scheduling with LWS_SET_TIMER_USEC_CANCEL is the
    // backwards-compatible cancellation API and remains supported by newer
    // libwebsockets releases.
    lws_sul_schedule(ctx->_wsContext, 0, &ctx->_serviceTimer.sul, nullptr,
                     LWS_SET_TIMER_USEC_CANCEL);
    return nullptr;
#else
    logFormattedWrite(ctx->_log, "ERROR: getwork requires libwebsockets, but it was not found at build time");
    return nullptr;
#endif
}

// Constructor
GetWorkContext::GetWorkContext(void* log, const char* wsUrl) :
    _log(log), _wsUrl(wsUrl), _host(""), _path("/"), _port(80),
#ifdef HAVE_LIBWEBSOCKETS
    _wsContext(nullptr), _wsi(nullptr), _serviceTimer(),
#endif
    _threadStarted(false), _stopRequested(false), _workId(0),
    _connectionState(ConnectionState::Disconnected), _hasWork(false),
    _hasSubmittedForWork(false), _submittedWorkId(0), _submittedRpcId(0),
    _needsRefresh(false), _hasPendingWrites(false), _pendingGetwork(false),
    _lastMessageTime(time(0)), _lastSubmitTime(0),
    _lastRequestTime(0), _lastReconnectAttempt(0), _rpcId(1)
{
    pthread_mutex_init(&_mutex, 0);
    pthread_mutex_init(&_queueMutex, 0);

#ifdef HAVE_LIBWEBSOCKETS
    _serviceTimer.owner = this;
    logFormattedWrite(_log, "Initializing WebSocket connection to %s", wsUrl);

    // Create WebSocket context
    struct lws_context_creation_info info;
    memset(&info, 0, sizeof(info));

    info.port = CONTEXT_PORT_NO_LISTEN;
    info.protocols = protocols;
    info.gid = -1;
    info.uid = -1;
    info.user = this;

    _wsContext = lws_create_context(&info);
    if (!_wsContext) {
        logFormattedWrite(_log, "Failed to create WebSocket context");
        return;
    }

    // Parse WebSocket URL (ws://host:port/path)
    const char* urlStart = wsUrl;
    if (strncmp(urlStart, "ws://", 5) == 0) {
        urlStart += 5;
    }

    // Extract host and port
    _port = 80;
    const char* pathStart = strchr(urlStart, '/');
    const char* portStart = strchr(urlStart, ':');

    if (portStart && (!pathStart || portStart < pathStart)) {
        // Has port
        _host = std::string(urlStart, portStart - urlStart);
        _port = atoi(portStart + 1);
    } else {
        // No port
        size_t hostLen = pathStart ? (pathStart - urlStart) : strlen(urlStart);
        _host = std::string(urlStart, hostLen);
    }

    _path = pathStart ? std::string(pathStart) : "/";

    logFormattedWrite(_log, "WebSocket target: host=%s port=%d path=%s",
                     _host.c_str(), _port, _path.c_str());
#endif
}

// Destructor
GetWorkContext::~GetWorkContext() {
    pthread_mutex_lock(&_mutex);
    _stopRequested = true;
    bool threadStarted = _threadStarted;
    pthread_mutex_unlock(&_mutex);

    if (threadStarted) {
#ifdef HAVE_LIBWEBSOCKETS
        if (_wsContext) {
            lws_cancel_service(_wsContext);
        }
#endif
        pthread_join(_thread, nullptr);
    }

#ifdef HAVE_LIBWEBSOCKETS
    if (_wsContext) {
        lws_context_destroy(_wsContext);
    }
#endif
    pthread_mutex_destroy(&_mutex);
    pthread_mutex_destroy(&_queueMutex);
}

// Start background thread
void GetWorkContext::run() {
    pthread_mutex_lock(&_mutex);
    if (_threadStarted) {
        pthread_mutex_unlock(&_mutex);
        return;
    }
    _stopRequested = false;
    pthread_mutex_unlock(&_mutex);

    if (pthread_create(&_thread, 0, runThread, this) == 0) {
        pthread_mutex_lock(&_mutex);
        _threadStarted = true;
        pthread_mutex_unlock(&_mutex);
    } else {
        logFormattedWrite(_log, "Failed to start WebSocket service thread");
    }
}

// Get work (called by mining threads)
bool GetWorkContext::get(unsigned idx, JsonWork* work, bool* hasChanged) {
    pthread_mutex_lock(&_mutex);

    if (!_hasWork) {
        pthread_mutex_unlock(&_mutex);
        return false;
    }

    static uint64_t lastWorkId = 0;
    *hasChanged = (_workId != lastWorkId);

    if (*hasChanged) {
        *work = _currentWork;
        lastWorkId = _workId;
    }

    pthread_mutex_unlock(&_mutex);
    return true;
}

// Get block height
uint64_t GetWorkContext::getBlockHeight() {
    pthread_mutex_lock(&_mutex);
    uint64_t h = _currentWork.height;
    pthread_mutex_unlock(&_mutex);
    return h;
}

// Get difficulty
double GetWorkContext::getDifficulty() {
    pthread_mutex_lock(&_mutex);
    double d = (double)_currentWork.difficulty;
    pthread_mutex_unlock(&_mutex);
    return d;
}

// Get work ID (changes when block changes)
uint64_t GetWorkContext::getWorkId() {
    pthread_mutex_lock(&_mutex);
    uint64_t id = _workId;
    pthread_mutex_unlock(&_mutex);
    return id;
}

// Check if connected
bool GetWorkContext::isConnected() {
    pthread_mutex_lock(&_mutex);
    bool connected = (_connectionState == ConnectionState::Connected);
    pthread_mutex_unlock(&_mutex);
    return connected;
}

// Request fresh work immediately
void GetWorkContext::requestWork() {
#ifdef HAVE_LIBWEBSOCKETS
    pthread_mutex_lock(&_mutex);
    bool shouldRequest = (_connectionState == ConnectionState::Connected &&
                          _wsi != nullptr);
    if (shouldRequest) {
        _hasPendingWrites = true;  // Signal pending work request
        _pendingGetwork = true;    // Mark as high-priority getwork request
    }
    pthread_mutex_unlock(&_mutex);

    if (shouldRequest) {
        lws_cancel_service(_wsContext);  // Thread-safe wake up
    }
#endif
}

// Trigger work refresh (set flag and request)
void GetWorkContext::triggerRefresh() {
    pthread_mutex_lock(&_mutex);
    // Only trigger if not already refreshing (avoid redundant requests)
    if (!_needsRefresh) {
        _needsRefresh = true;
        pthread_mutex_unlock(&_mutex);
        requestWork();
        // logFormattedWrite(_log, "Triggered work refresh");
    } else {
        pthread_mutex_unlock(&_mutex);
        // logFormattedWrite(_log, "Work refresh already in progress");
    }
}

// Wait for work to change (poll until we get newer work)
// After block submission, we need height to increase OR parent_hash to change
bool GetWorkContext::waitForNewWork(const JsonWork& oldWork, int timeoutMs) {
    int elapsed = 0;
    const int pollInterval = 100; // 100ms between polls

    while (elapsed < timeoutMs) {
        pthread_mutex_lock(&_mutex);
        // Check if disconnected - exit immediately
        if (_connectionState != ConnectionState::Connected) {
            pthread_mutex_unlock(&_mutex);
            logFormattedWrite(_log, "WebSocket disconnected while waiting for new work");
            return false;
        }

        // Check if we got genuinely new work:
        // - Height must be greater (we built on top of submitted block)
        // - OR parent_hash changed (reorganization or different chain tip)
        bool gotNewWork = (_currentWork.height > oldWork.height ||
                          _currentWork.parentHash != oldWork.parentHash);
        uint64_t currentHeight = _currentWork.height;
        std::string currentParent = _currentWork.parentHash;
        pthread_mutex_unlock(&_mutex);

        if (gotNewWork) {
            logFormattedWrite(_log, "Got new work after %dms (old height=%lu, new height=%lu)",
                            elapsed, oldWork.height, currentHeight);
            return true;
        }

        usleep(pollInterval * 1000);
        elapsed += pollInterval;

        // Request work periodically while waiting
        if (elapsed % 500 == 0) {
            requestWork();
        }
    }

    logFormattedWrite(_log, "Timeout waiting for new work after %dms (still at height %lu)",
                     timeoutMs, oldWork.height);
    return false;
}

// Submit work
bool GetWorkContext::submitWork(const JsonWork& work, uint64_t nonce,
                                const mpz_class& multiplier) {
#ifdef HAVE_LIBWEBSOCKETS
    // Reject obviously stale work before spending time serializing it. The
    // same check is repeated atomically with queue insertion below because a
    // new work response may arrive while the JSON request is being built.
    pthread_mutex_lock(&_mutex);
    bool isStale = !_hasWork ||  // No valid work available
                   (work.height != _currentWork.height ||
                    work.parentHash != _currentWork.parentHash);
    int id = _rpcId++;
    pthread_mutex_unlock(&_mutex);

    if (isStale) {
        // Silently drop stale submission - work already changed
        return false;
    }

    json_t* request = json_object();
    json_object_set_new(request, "jsonrpc", json_string("2.0"));
    json_object_set_new(request, "id", json_integer(id));
    json_object_set_new(request, "method", json_string("blocktree.submit_work"));

    // Build params object
    json_t* params = json_object();
    json_object_set_new(params, "parent_hash", json_string(work.parentHash.c_str()));
    json_object_set_new(params, "height", json_integer(work.height));
    json_object_set_new(params, "difficulty", json_integer(work.difficulty));
    json_object_set_new(params, "merkle", json_string(work.merkle.c_str()));
    json_object_set_new(params, "nonce", json_integer(nonce));

    // Convert multiplier to string and send as JSON string (not integer) to preserve full precision
    // Large multipliers exceed int64 range, so we must use string representation
    std::string multStr = multiplier.get_str();
    json_object_set_new(params, "multiplier", json_string(multStr.c_str()));

    json_t* paramsArray = json_array();
    json_array_append_new(paramsArray, params);
    json_object_set_new(request, "params", paramsArray);

    char* requestStr = json_dumps(request, JSON_COMPACT);
    json_decref(request);

    if (!requestStr) {
        return false;
    }

    std::string serializedRequest(requestStr);
    free(requestStr);

    // Reserve this work ID and queue its first solution as one atomic state
    // transition. Metal can return several valid chains in one completed GPU
    // batch; without this gate the WebSocket thread can transmit several of
    // them before the first accepted block advances the node.
    pthread_mutex_lock(&_mutex);
    isStale = !_hasWork ||
              work.height != _currentWork.height ||
              work.parentHash != _currentWork.parentHash;
    const bool alreadySubmitted =
        _hasSubmittedForWork && _submittedWorkId == _workId;
    if (isStale || alreadySubmitted) {
        pthread_mutex_unlock(&_mutex);
        return false;
    }

    pthread_mutex_lock(&_queueMutex);
    while (!_pendingMessages.empty()) {
        _pendingMessages.pop();
    }
    _pendingMessages.push(std::move(serializedRequest));
    pthread_mutex_unlock(&_queueMutex);

    _hasSubmittedForWork = true;
    _submittedWorkId = _workId;
    _submittedRpcId = id;
    _hasPendingWrites = true;
    pthread_mutex_unlock(&_mutex);

    // lws_cancel_service is the ONLY thread-safe lws call
    // This will trigger LWS_CALLBACK_EVENT_WAIT_CANCELLED in the lws thread
    lws_cancel_service(_wsContext);

    // Already logged as "found share" in main mining code
    return true;  // Message queued successfully
#else
    logFormattedWrite(_log, "ERROR: submitWork requires libwebsockets");
    return false;
#endif
}
