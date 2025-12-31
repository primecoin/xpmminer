#include "getwork_client.h"
#include "Debug.h"
#include <cstring>
#include <unistd.h>
#include <sstream>

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
        case LWS_CALLBACK_CLIENT_ESTABLISHED:
            logFormattedWrite(ctx->_log, "WebSocket connection established");
            pthread_mutex_lock(&ctx->_mutex);
            ctx->_connected = true;
            pthread_mutex_unlock(&ctx->_mutex);
            // Request write callback to send data
            lws_callback_on_writable(wsi);
            break;

        case LWS_CALLBACK_CLIENT_RECEIVE:
            if (in && len > 0) {
                ctx->onMessage((const char*)in, len);
            }
            break;

        case LWS_CALLBACK_CLIENT_WRITEABLE:
        {
            // PRIORITY 1: Check for high-priority getwork request first
            pthread_mutex_lock(&ctx->_mutex);
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
            if (ctx->_hasPendingWrites && ctx->_wsi) {
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
            logFormattedWrite(ctx->_log, "WebSocket connection closed");
            pthread_mutex_lock(&ctx->_mutex);
            ctx->_connected = false;
            ctx->_wsi = nullptr;  // Clear pointer to avoid using stale connection
            ctx->_hasWork = false;  // Invalidate work on disconnect
            ctx->_workId++;  // Signal work changed (triggers mining loop restart)
            pthread_mutex_unlock(&ctx->_mutex);

            // Clear pending message queue - old submissions are worthless after disconnect
            pthread_mutex_lock(&ctx->_queueMutex);
            while (!ctx->_pendingMessages.empty()) {
                ctx->_pendingMessages.pop();
            }
            pthread_mutex_unlock(&ctx->_queueMutex);
            break;

        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
            logFormattedWrite(ctx->_log, "WebSocket connection error");
            pthread_mutex_lock(&ctx->_mutex);
            ctx->_connected = false;
            ctx->_wsi = nullptr;  // Clear pointer to avoid using stale connection
            ctx->_hasWork = false;  // Invalidate work on connection error
            ctx->_workId++;  // Signal work changed (triggers mining loop restart)
            pthread_mutex_unlock(&ctx->_mutex);

            // Clear pending message queue - old submissions are worthless after disconnect
            pthread_mutex_lock(&ctx->_queueMutex);
            while (!ctx->_pendingMessages.empty()) {
                ctx->_pendingMessages.pop();
            }
            pthread_mutex_unlock(&ctx->_queueMutex);
            break;

        case LWS_CALLBACK_WSI_DESTROY:
        case LWS_CALLBACK_CLIENT_CLOSED:
            // Additional disconnect callbacks that may fire instead of CLOSED
            logFormattedWrite(ctx->_log, "WebSocket destroyed/closed (callback)");
            pthread_mutex_lock(&ctx->_mutex);
            ctx->_connected = false;
            ctx->_wsi = nullptr;
            ctx->_hasWork = false;  // Invalidate work on disconnect
            ctx->_workId++;  // Signal work changed (triggers mining loop restart)
            pthread_mutex_unlock(&ctx->_mutex);

            // Clear pending message queue
            pthread_mutex_lock(&ctx->_queueMutex);
            while (!ctx->_pendingMessages.empty()) {
                ctx->_pendingMessages.pop();
            }
            pthread_mutex_unlock(&ctx->_queueMutex);
            break;

        default:
            break;
    }

    return 0;
}

// Parse incoming JSON-RPC message
void GetWorkContext::onMessage(const char* data, size_t len) {
    // Update last message time for timeout detection
    _lastMessageTime = time(0);

    // Only log full message in debug mode
    // logFormattedWrite(_log, "Received message (%zu bytes): %.*s", len, (int)len, data);

    json_error_t error;
    json_t* root = json_loadb(data, len, 0, &error);

    if (!root) {
        logFormattedWrite(_log, "Failed to parse JSON: %s", error.text);
        return;
    }

    // Check for error in response
    json_t* jerror = json_object_get(root, "error");
    if (jerror && !json_is_null(jerror)) {
        const char* errMsg = json_string_value(json_object_get(jerror, "message"));
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

    // Check if this is a submit response (result is boolean true)
    if (json_is_boolean(result) && json_is_true(result)) {
        json_decref(root);

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
            uint64_t currentHeight = _currentWork.height;
            bool shouldLog = (currentHeight != lastStaleLogHeight);
            if (shouldLog) {
                lastStaleLogHeight = currentHeight;
            }
            pthread_mutex_unlock(&_mutex);

            if (shouldLog) {
                logFormattedWrite(_log, "Block submission failed: stale work (height %lu)", currentHeight);
            }

            // Clear pending message queue - all pending submissions are stale
            pthread_mutex_lock(&_queueMutex);
            while (!_pendingMessages.empty()) {
                _pendingMessages.pop();
            }
            pthread_mutex_unlock(&_queueMutex);

            // Request new work directly (we're in lws thread)
            json_decref(root);

            pthread_mutex_lock(&_mutex);
            // Stop mining until new work arrives
            _hasWork = false;
            _workId++;
            _needsRefresh = true;
            struct lws* wsi = _wsi;
            pthread_mutex_unlock(&_mutex);

            if (wsi) {
                lws_callback_on_writable(wsi);  // Safe - we're in lws thread
            }
            return;
        }

        // For other errors, log normally
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
    bool shouldSend = (_wsi != nullptr);
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

// Attempt to reconnect to WebSocket server
void GetWorkContext::attemptReconnect() {
#ifdef HAVE_LIBWEBSOCKETS
    pthread_mutex_lock(&_mutex);
    bool connected = _connected;
    pthread_mutex_unlock(&_mutex);

    if (connected) {
        return;  // Already connected
    }

    logFormattedWrite(_log, "Attempting to reconnect to WebSocket server...");

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
    _wsi = new_wsi;
    pthread_mutex_unlock(&_mutex);

    if (!new_wsi) {
        logFormattedWrite(_log, "Reconnection attempt failed");
    } else {
        logFormattedWrite(_log, "Reconnection initiated...");
    }
#endif
}

// Thread function
void* GetWorkContext::runThread(void* arg) {
    GetWorkContext* ctx = (GetWorkContext*)arg;

#ifdef HAVE_LIBWEBSOCKETS
    time_t lastRequest = 0;
    while (true) {
        // Service WebSocket connection
        if (ctx->_wsContext) {
            lws_service(ctx->_wsContext, 50);
        }

        time_t now = time(0);

        // Check connection status every 20 seconds
        if (now - lastRequest >= 20) {
            pthread_mutex_lock(&ctx->_mutex);
            bool connected = ctx->_connected;
            struct lws* wsi = ctx->_wsi;
            time_t lastMsg = ctx->_lastMessageTime;
            pthread_mutex_unlock(&ctx->_mutex);

            // Check for timeout (no messages for 30 seconds)
            if (connected && (now - lastMsg) > 30) {
                logFormattedWrite(ctx->_log, "Connection timeout - no messages for %ld seconds", now - lastMsg);
                pthread_mutex_lock(&ctx->_mutex);
                ctx->_connected = false;
                ctx->_hasWork = false;
                ctx->_workId++;
                pthread_mutex_unlock(&ctx->_mutex);
                connected = false;  // Fall through to reconnect logic
            }

            if (connected && wsi) {
                // Connected: request new work
                lws_callback_on_writable(wsi);
            } else {
                // Disconnected: attempt to reconnect
                ctx->attemptReconnect();
            }
            lastRequest = now;
        }

        usleep(50000); // 50ms
    }
#else
    logFormattedWrite(ctx->_log, "ERROR: getwork requires libwebsockets, but it was not found at build time");
    return nullptr;
#endif
}

// Constructor
GetWorkContext::GetWorkContext(void* log, const char* wsUrl) :
    _log(log), _wsUrl(wsUrl), _host(""), _path("/"), _port(80),
#ifdef HAVE_LIBWEBSOCKETS
    _wsContext(nullptr), _wsi(nullptr),
#endif
    _workId(0), _connected(false), _hasWork(false), _needsRefresh(false), _hasPendingWrites(false), _pendingGetwork(false), _lastMessageTime(time(0)), _lastSubmitTime(0), _rpcId(1)
{
    pthread_mutex_init(&_mutex, 0);
    pthread_mutex_init(&_queueMutex, 0);

#ifdef HAVE_LIBWEBSOCKETS
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

    logFormattedWrite(_log, "Connecting to WebSocket: host=%s port=%d path=%s",
                     _host.c_str(), _port, _path.c_str());

    // Connect to WebSocket server
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

    _wsi = lws_client_connect_via_info(&ccinfo);
    if (!_wsi) {
        logFormattedWrite(_log, "Failed to initiate WebSocket connection");
    } else {
        logFormattedWrite(_log, "WebSocket connection initiated...");
    }
#endif
}

// Destructor
GetWorkContext::~GetWorkContext() {
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
    pthread_create(&_thread, 0, runThread, this);
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
    bool connected = _connected;
    pthread_mutex_unlock(&_mutex);
    return connected;
}

// Request fresh work immediately
void GetWorkContext::requestWork() {
#ifdef HAVE_LIBWEBSOCKETS
    pthread_mutex_lock(&_mutex);
    bool shouldRequest = (_connected && _wsi != nullptr);
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
        if (!_connected) {
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
bool GetWorkContext::submitWork(const JsonWork& work, uint32_t nonce,
                                const mpz_class& multiplier) {
#ifdef HAVE_LIBWEBSOCKETS
    // Check if work is stale BEFORE queuing
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

    // Queue the message instead of writing directly (thread-safe)
    pthread_mutex_lock(&_queueMutex);
    // Limit queue size to 1 to prioritize getwork requests
    // When shares are found rapidly, we only keep the most recent submit
    while (_pendingMessages.size() >= 1) {
        _pendingMessages.pop();  // Drop oldest submit to make room for new one
    }
    _pendingMessages.push(std::string(requestStr));
    pthread_mutex_unlock(&_queueMutex);
    free(requestStr);

    // Set flag and wake up event loop (thread-safe way)
    pthread_mutex_lock(&_mutex);
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
