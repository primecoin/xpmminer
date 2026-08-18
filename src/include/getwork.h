#ifndef __GETWORK_H_
#define __GETWORK_H_

#include <string>
#include <cstdint>

// JSON-RPC getwork structure
// Represents work received from server via mining.getwork method
struct JsonWork {
    std::string parentHash;    // hex string
    uint64_t height;
    uint64_t difficulty;
    std::string merkle;        // transactions_root hex
    uint64_t nonce;

    // For tracking work changes
    bool isValid() const { return !parentHash.empty(); }

    // Initialize with default values
    JsonWork() : height(0), difficulty(0), nonce(0) {}
};

#endif // __GETWORK_H_
