#ifndef __GETWORK_CLIENT_H_
#define __GETWORK_CLIENT_H_

#include "getwork.h"
#include <pthread.h>
#include <queue>
#include <string>

#ifdef HAVE_LIBWEBSOCKETS
#include <libwebsockets.h>
#endif

#include <jansson.h>
#include <gmp.h>
#include <gmpxx.h>

class GetWorkContext {
public:
    // WebSocket callback must be public for protocol array
#ifdef HAVE_LIBWEBSOCKETS
    static int wsCallback(struct lws* wsi, enum lws_callback_reasons reason,
                         void* user, void* in, size_t len);
#endif

private:
    void* _log;
    std::string _wsUrl;           // ws://host:port/path
    std::string _host;            // Parsed hostname
    std::string _path;            // Parsed path
    int _port;                    // Parsed port

#ifdef HAVE_LIBWEBSOCKETS
    struct lws_context* _wsContext;
    struct lws* _wsi;
#endif

    pthread_mutex_t _mutex;
    pthread_t _thread;

    JsonWork _currentWork;
    uint64_t _workId;             // increments on new work
    bool _connected;
    bool _hasWork;
    bool _needsRefresh;           // Flag to force work refresh
    bool _hasPendingWrites;       // Flag to signal pending writes (thread-safe)
    bool _pendingGetwork;         // Flag for high-priority getwork request
    time_t _lastMessageTime;      // Track last received message for timeout detection
    time_t _lastSubmitTime;       // Track last submit time for throttling

    // JSON-RPC request ID counter
    int _rpcId;

    // Message queue for thread-safe WebSocket writes
    std::queue<std::string> _pendingMessages;
    pthread_mutex_t _queueMutex;

    void onMessage(const char* data, size_t len);
    void sendGetWork();
    void sendGetWorkInternal(struct lws* wsi);  // Internal version called from callback
    void attemptReconnect();  // Try to reconnect to WebSocket server
    static void* runThread(void* arg);

public:
    GetWorkContext(void* log, const char* wsUrl);
    ~GetWorkContext();

    void run();
    bool get(unsigned idx, JsonWork* work, bool* hasChanged);
    uint64_t getBlockHeight();
    double getDifficulty();
    uint64_t getWorkId();  // Get current work ID (changes when block changes)
    bool isConnected();  // Check if WebSocket is connected
    void requestWork();  // Request fresh work immediately
    void triggerRefresh();  // Set refresh flag and request work
    bool waitForNewWork(const JsonWork& oldWork, int timeoutMs);  // Poll until work changes

    bool submitWork(const JsonWork& work, uint64_t nonce,
                   const mpz_class& multiplier);
};

#endif // __GETWORK_CLIENT_H_
