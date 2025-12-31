/*
 * common.metal
 *
 * Common types and constants shared across Metal kernels
 * Ported from HIP implementation for xpmclient
 */

#ifndef COMMON_METAL_H
#define COMMON_METAL_H

#include <metal_stdlib>
using namespace metal;

// Macro to extract upper 32 bits of 64-bit value
#define UPPER32(val) ((uint)((val) >> 32))

// Use native 64-bit multiply + shift instead of mulhi intrinsic for better efficiency
// This computes (a * b) >> 32, which is the high word of the 64-bit product
// More efficient on Apple Silicon than calling mulhi intrinsic
#define UMULHI(a, b) UPPER32(((ulong)(a)) * ((ulong)(b)))

// Fermat test candidate info
// Must match the C++ struct fermat_t in xpmclient_metal.h
struct fermat_t {
    uint index;      // Multiplier index
    uint hashid;     // Hash identifier
    uchar origin;    // Starting layer/offset
    uchar chainpos;  // Position in prime chain
    uchar type;      // Chain type: 0=Cunningham1, 1=Cunningham2, 2=BiTwin
    uchar reserved;  // Padding for alignment
};

// Miner configuration structure
// Must match the C++ struct config_t in xpmclient_metal.h
struct config_t {
    uint N;          // Number of hash limbs (typically 12)
    uint SIZE;       // Sieve size
    uint STRIPES;    // Number of sieve stripes
    uint WIDTH;      // Chain width
    uint PCOUNT;     // Prime count
    uint TARGET;     // Target chain length
    uint LIMIT13;    // 13-prime primorial limit
    uint LIMIT14;    // 14-prime primorial limit
    uint LIMIT15;    // 15-prime primorial limit
};

// Common constants
// Suppress unused variable warnings - these are used by other Metal shaders
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-const-variable"

constant uint N_HASH_LIMBS = 12;  // Default number of hash limbs

// Sieve size constant - MUST match mConfig.SIZE in xpmclient_metal.mm
// Set to 4096 (16KB) - Metal only allocates 16KB threadgroup memory (verified via staticThreadgroupMemoryLength)
#ifndef METAL_SIEVE_SIZE
#define METAL_SIEVE_SIZE 4096
#endif

// Prime chain types
constant uint CHAIN_CUNNINGHAM1 = 0;  // 2n+1 chain
constant uint CHAIN_CUNNINGHAM2 = 1;  // 2n-1 chain
constant uint CHAIN_BITWIN = 2;       // Both types

// Maximum values
constant uint MAX_SIEVE_OUTPUT = 128 * 1024;
constant uint MAX_PIPELINE_WIDTH = 512;
constant uint MAX_SIEVE_WIDTH = 40;  // Balanced for Metal memory constraints

// SHA256 constants
constant uint SHA256_H_INIT[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

constant uint SHA256_K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

// First 20 primes for primorial testing
constant uint SMALL_PRIMES[20] = {
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
    31, 37, 41, 43, 47, 53, 59, 61, 67, 71
};

// Sieve constants for 1024 threads per threadgroup (LSIZELOG2 == 10)
// Matches CUDA default configuration for optimal performance
constant uint LSIZE = 1024;
constant uint LSIZELOG2 = 10;
constant uint NLIFO = 4;  // LIFO buffer depth for prime prefetching

// Batch sizes for phase 1 sieving (for 1024 threads)
// These control how many threads process each batch of primes
constant uint nps_all[8] = { 4, 4, 5, 6, 7, 7, 7, 9 };
constant uint S1RUNS = 8;  // Number of batches

// Helper function: byte swap for endianness conversion
inline uint bswap32(uint x) {
    return ((x << 24) & 0xff000000) |
           ((x << 8)  & 0x00ff0000) |
           ((x >> 8)  & 0x0000ff00) |
           ((x >> 24) & 0x000000ff);
}

// Helper function: rotate right
inline uint rotr(uint x, uint n) {
    return (x >> n) | (x << (32 - n));
}

// Helper function: rotate left
inline uint rotl(uint x, uint n) {
    return (x << n) | (x >> (32 - n));
}

// SHA256 helper macros
#define SHA256_CH(x, y, z) ((x & y) ^ (~x & z))
#define SHA256_MAJ(x, y, z) ((x & y) ^ (x & z) ^ (y & z))
#define SHA256_EP0(x) (rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22))
#define SHA256_EP1(x) (rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25))
#define SHA256_SIG0(x) (rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3))
#define SHA256_SIG1(x) (rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10))

// Integer inversion using extended Euclidean algorithm
// Used for modular arithmetic in sieve
inline uint int_invert(uint a, uint modulus) {
    int u = 1, v = 0;
    uint b = modulus;

    while (a) {
        uint q = b / a;
        uint r = b % a;
        int m = u - q * v;

        b = a;
        a = r;
        u = v;
        v = m;
    }

    if (u < 0) {
        return modulus + u;
    }

    return (uint)u;
}

// Modulo operation for multi-limb integers (constant memory)
inline uint mod32_const(constant uint* in,
                        uint inSize,
                        constant uint* modulos,
                        uint mod) {
    ulong r = 0;

    for (int i = inSize - 1; i >= 0; i--) {
        r = (r << 32) + in[i];
        r %= mod;
    }

    return (uint)r;
}

// Modulo operation for multi-limb integers (thread memory)
inline uint mod32(thread const uint* in,
                  uint inSize,
                  thread const uint* modulos,
                  uint mod) {
    ulong r = 0;

    for (int i = inSize - 1; i >= 0; i--) {
        r = (r << 32) + in[i];
        r %= mod;
    }

    return (uint)r;
}

// Left shift for multi-limb integer
// CRITICAL: Must iterate backwards (high to low) to avoid overwriting data before reading it
inline void shl(thread uint* data, uint limbs, uint bits) {
    if (bits >= 32) {
        uint words = bits / 32;
        bits = bits % 32;

        // Move words first (this part is correct - already backwards)
        for (int i = limbs - 1; i >= (int)words; i--) {
            data[i] = data[i - words];
        }
        for (uint i = 0; i < words; i++) {
            data[i] = 0;
        }
    }

    if (bits > 0) {
        // FIXED: Iterate backwards like HIP to avoid data corruption
        for (int i = limbs - 1; i > 0; i--) {
            data[i] = (data[i] << bits) | (data[i-1] >> (32 - bits));
        }
        data[0] = data[0] << bits;
    }
}

// Compare multi-limb integers
// Returns: -1 if a < b, 0 if a == b, 1 if a > b
inline int cmp(constant uint* a, constant uint* b, uint limbs) {
    for (int i = limbs - 1; i >= 0; i--) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
    }
    return 0;
}

#endif // COMMON_METAL_H
