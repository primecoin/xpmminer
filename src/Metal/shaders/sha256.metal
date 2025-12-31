/*
 * sha256.metal
 *
 * SHA256 hashing functions for Metal
 * Ported from json_sha256_hip.cpp
 */

#include <metal_stdlib>
#include "common.metal"
using namespace metal;

// Convert uint64 to decimal string, returns length
inline int uint64_to_str(ulong value, thread char* buf) {
    if (value == 0) {
        buf[0] = '0';
        return 1;
    }

    char temp[20];
    int len = 0;
    while (value > 0) {
        temp[len++] = '0' + (value % 10);
        value /= 10;
    }

    // Reverse
    for (int i = 0; i < len; i++) {
        buf[i] = temp[len - 1 - i];
    }

    return len;
}

// Process one SHA256 block
inline void sha256_transform(thread uint* state, constant uchar* block) {
    uint w[64];
    uint a, b, c, d, e, f, g, h, t1, t2;

    // Prepare message schedule
    for (int i = 0; i < 16; i++) {
        w[i] = ((uint)block[i*4] << 24) |
               ((uint)block[i*4+1] << 16) |
               ((uint)block[i*4+2] << 8) |
               ((uint)block[i*4+3]);
    }

    for (int i = 16; i < 64; i++) {
        w[i] = SHA256_SIG1(w[i-2]) + w[i-7] + SHA256_SIG0(w[i-15]) + w[i-16];
    }

    // Initialize working variables
    a = state[0]; b = state[1]; c = state[2]; d = state[3];
    e = state[4]; f = state[5]; g = state[6]; h = state[7];

    // Main loop
    for (int i = 0; i < 64; i++) {
        t1 = h + SHA256_EP1(e) + SHA256_CH(e, f, g) + SHA256_K[i] + w[i];
        t2 = SHA256_EP0(a) + SHA256_MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    // Update state
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

// SHA256 transform with thread-local block buffer
inline void sha256_transform_thread(thread uint* state, thread uchar* block) {
    uint w[64];
    uint a, b, c, d, e, f, g, h, t1, t2;

    // Prepare message schedule
    for (int i = 0; i < 16; i++) {
        w[i] = ((uint)block[i*4] << 24) |
               ((uint)block[i*4+1] << 16) |
               ((uint)block[i*4+2] << 8) |
               ((uint)block[i*4+3]);
    }

    for (int i = 16; i < 64; i++) {
        w[i] = SHA256_SIG1(w[i-2]) + w[i-7] + SHA256_SIG0(w[i-15]) + w[i-16];
    }

    // Initialize working variables
    a = state[0]; b = state[1]; c = state[2]; d = state[3];
    e = state[4]; f = state[5]; g = state[6]; h = state[7];

    // Main loop
    for (int i = 0; i < 64; i++) {
        t1 = h + SHA256_EP1(e) + SHA256_CH(e, f, g) + SHA256_K[i] + w[i];
        t2 = SHA256_EP0(a) + SHA256_MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    // Update state
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

// Complete SHA256 computation starting from midstate
inline void sha256_from_midstate(thread uint* hash_out,
                                 constant uint* midstate,
                                 thread uchar* data,
                                 uint len) {
    uint state[8];
    for (int i = 0; i < 8; i++) {
        state[i] = midstate[i];
    }

    uchar block[64];
    uint idx = 0;

    // Process complete blocks
    while (len >= 64) {
        for (int i = 0; i < 64; i++) {
            block[i] = data[i];
        }
        sha256_transform_thread(state, block);
        data += 64;
        len -= 64;
    }

    // Process final block with padding
    for (idx = 0; idx < len; idx++) {
        block[idx] = data[idx];
    }
    block[idx++] = 0x80; // SHA256 padding

    // If not enough room for length, process this block and start new one
    if (idx > 56) {
        while (idx < 64) block[idx++] = 0;
        sha256_transform_thread(state, block);
        idx = 0;
    }

    // Pad with zeros
    while (idx < 56) block[idx++] = 0;

    // Append length in bits
    // For JSON getwork: 128 bytes before midstate + remaining bytes
    ulong bitlen = (128 + len) * 8;
    for (int i = 7; i >= 0; i--) {
        block[56 + i] = bitlen & 0xff;
        bitlen >>= 8;
    }

    sha256_transform_thread(state, block);

    // Copy output (big-endian)
    for (int i = 0; i < 8; i++) {
        hash_out[i] = state[i];
    }
}

// Full SHA256 (for second hash)
inline void sha256_full(thread uint* hash_out, thread const uchar* data, uint len) {
    uint state[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };

    uchar block[64];
    uint idx = 0;

    // Process complete blocks
    while (len >= 64) {
        for (int i = 0; i < 64; i++) {
            block[i] = data[i];
        }
        sha256_transform_thread(state, block);
        data += 64;
        len -= 64;
    }

    // Final block with padding
    for (idx = 0; idx < len; idx++) {
        block[idx] = data[idx];
    }
    block[idx++] = 0x80;

    if (idx > 56) {
        while (idx < 64) block[idx++] = 0;
        sha256_transform_thread(state, block);
        idx = 0;
    }

    while (idx < 56) block[idx++] = 0;

    ulong bitlen = (len * 8);
    for (int i = 7; i >= 0; i--) {
        block[56 + i] = bitlen & 0xff;
        bitlen >>= 8;
    }

    sha256_transform_thread(state, block);

    for (int i = 0; i < 8; i++) {
        hash_out[i] = state[i];
    }
}
