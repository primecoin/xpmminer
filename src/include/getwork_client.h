#ifndef __GETWORK_CLIENT_H_
#define __GETWORK_CLIENT_H_

#include "getwork.h"
#include <pthread.h>

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

    // JSON-RPC request ID counter
    int _rpcId;

    void onMessage(const char* data, size_t len);
    void sendGetWork();
    void attemptReconnect();  // Try to reconnect to WebSocket server
    static void* runThread(void* arg);

public:
    GetWorkContext(void* log, const char* wsUrl);
    ~GetWorkContext();

    void run();
    bool get(unsigned idx, JsonWork* work, bool* hasChanged);
    uint64_t getBlockHeight();
    double getDifficulty();
    bool isConnected();  // Check if WebSocket is connected
    void requestWork();  // Request fresh work immediately
    void triggerRefresh();  // Set refresh flag and request work
    bool waitForNewWork(const JsonWork& oldWork, int timeoutMs);  // Poll until work changes

    bool submitWork(const JsonWork& work, uint32_t nonce,
                   const mpz_class& multiplier);
};

#endif // __GETWORK_CLIENT_H_
