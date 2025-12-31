/*
 * json_hashmod.metal
 *
 * JSON-based hash modulus kernel for Metal
 * Ported from json_sha256_hip.cpp
 *
 * This kernel hashes JSON getwork data and tests for primorial divisibility
 */

#include <metal_stdlib>
#include "common.metal"
#include "sha256.metal"
using namespace metal;

#define HashPrimorial 16

// Primorial divisibility testing constants
// These constants enable fast divisibility checks using modular arithmetic

// Indexes for first 5 primes (3, 5, 7, 13, 17)
constant uint indexesOne[] = { 1, 2, 3, 5, 6 };
constant uint divisors24one[] = { 3, 5, 7, 13, 17 };

// Indexes for remaining primes (11, 19, 23, ..., 71)
constant uint indexes[] = { 4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 };
constant uint divisors24[] = { 11, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71 };

// Modulos for 24-bit arithmetic (first 5 primes)
constant uint modulos24one[] = {
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1
};

// Modulos for remaining primes (11 x 14 array)
constant uint modulos24[] = {
    // Prime 11
    1, 13, 1, 3, 1, 7, 1, 1, 1, 3, 1,
    // Prime 19
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 23
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 29
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 31
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 37
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 41
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 43
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 47
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 53
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 59
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 61
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 67
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1,
    // Prime 71
    1, 15, 1, 3, 1, 7, 1, 1, 1, 13, 1
};

// Multiplication constants for fast division
constant uint multipliers32one[] = {
    0xAAAAAAAB, // 3
    0xCCCCCCCD, // 5
    0x24924925, // 7
    0xC4EC4EC5, // 13
    0xF0F0F0F1  // 17
};

constant uint multipliers32[] = {
    0x2E8BA2E9, // 11
    0x86186187, // 19
    0xB21642C9, // 23
    0x8D3DCB09, // 29
    0x08421085, // 31
    0xDD67C8A7, // 37
    0xC65D1B8B, // 41
    0x2FA0BE83, // 43
    0xAE4C415D, // 47
    0x9A90E7D9, // 53
    0x22B63CBF, // 59
    0x08421085, // 61
    0xC9714FBD, // 67
    0x7C32F997  // 71
};

// Offset constants for fast division
constant uint offsets32one[] = {
    1, // 3
    2, // 5
    3, // 7
    3, // 13
    4  // 17
};

constant uint offsets32[] = {
    3,  // 11
    4,  // 19
    4,  // 23
    4,  // 29
    5,  // 31
    5,  // 37
    5,  // 41
    5,  // 43
    5,  // 47
    5,  // 53
    5,  // 59
    6,  // 61
    6,  // 67
    6   // 71
};

// Sum in 24-bit arithmetic (constant memory version)
inline uint sum24_const(constant uint* data, uint size, constant uint* moddata) {
    uint size24 = size * 32;
    size24 += size24 % 24 ? 24 - size24 % 24 : 0;

    uint acc = data[0] & 0x00FFFFFF;
    for (uint i = 0, bitPos = 24; bitPos < size24; bitPos += 24, i++) {
        // Use aligned 32-bit reads instead of unaligned 64-bit cast
        uint idx = bitPos / 32;
        uint lo = data[idx];
        uint hi = (idx + 1 < size) ? data[idx + 1] : 0;
        ulong v64 = (((ulong)hi << 32) | lo) >> (bitPos % 32);
        acc += ((v64 & 0xFFFFFF) * moddata[i]);
    }

    return acc;
}

// Sum in 24-bit arithmetic (thread memory version)
inline uint sum24(thread const uint* data, uint size, constant uint* moddata) {
    uint size24 = size * 32;
    size24 += size24 % 24 ? 24 - size24 % 24 : 0;

    uint acc = data[0] & 0x00FFFFFF;
    for (uint i = 0, bitPos = 24; bitPos < size24; bitPos += 24, i++) {
        // Use aligned 32-bit reads instead of unaligned 64-bit cast
        uint idx = bitPos / 32;
        uint lo = data[idx];
        uint hi = (idx + 1 < size) ? data[idx + 1] : 0;
        ulong v64 = (((ulong)hi << 32) | lo) >> (bitPos % 32);
        acc += ((v64 & 0xFFFFFF) * moddata[i]);
    }

    return acc;
}

// Check divisibility using fast division
inline uint check24(uint X, uint divisor, uint inversedMultiplier, uint offset) {
    return X == divisor * (UMULHI(X, inversedMultiplier) >> offset);
}

// Division check combining sum24 and check24 (thread memory version)
inline uint divisionCheck24(thread const uint* data,
                            uint size,
                            uint divisor,
                            constant uint* moddata,
                            uint inversedMultiplier,
                            uint offset) {
    return check24(sum24(data, size, moddata), divisor, inversedMultiplier, offset);
}

/**
 * JSON Hash Modulus Kernel
 *
 * Computes SHA256(SHA256(JSON)) and tests for primorial divisibility
 *
 * @param nonceOffset Starting nonce value for this batch
 * @param found Output buffer for found nonces
 * @param fcount Output counter for found candidates
 * @param resultPrimorial Output buffer for primorial bit fields
 * @param midstate SHA256 midstate (precomputed for JSON prefix)
 * @param remainingPrefix Remaining JSON prefix after midstate point
 * @param remainingLen Length of remaining prefix
 * @param totalPrefixLen Total JSON prefix length (for validation)
 * @param LIMIT13/14/15 Primorial size limits (passed via buffer or constant)
 */
kernel void jsonHashMod(
    constant ulong& nonceOffset           [[buffer(0)]],
    device uint* found                    [[buffer(1)]],
    device atomic_uint* fcount            [[buffer(2)]],
    device uint* resultPrimorial          [[buffer(3)]],
    constant uint* midstate               [[buffer(4)]],
    constant char* remainingPrefix        [[buffer(5)]],
    constant uint& remainingLen           [[buffer(6)]],
    constant uint& totalPrefixLen         [[buffer(7)]],
    constant uint& LIMIT13                [[buffer(8)]],
    constant uint& LIMIT14                [[buffer(9)]],
    constant uint& LIMIT15                [[buffer(10)]],
    uint tid [[thread_position_in_grid]])
{
    ulong nonce = nonceOffset + tid;

    // Build complete JSON message in thread-local buffer
    uchar message[256];  // Increased from 128 to handle worst-case JSON prefix
    uint msgLen = 0;

    // Copy remaining prefix
    for (uint i = 0; i < remainingLen; i++) {
        message[msgLen++] = remainingPrefix[i];
    }

    // Append nonce digits
    char nonceStr[20];
    int nonceLen = uint64_to_str(nonce, nonceStr);
    for (int i = 0; i < nonceLen; i++) {
        message[msgLen++] = nonceStr[i];
    }

    // Append closing brace
    message[msgLen++] = '}';

    // Safety check: skip malformed/oversized messages
    if (msgLen > 200) {
        return;
    }

    // First SHA256 (from midstate)
    uint hash1[8];
    sha256_from_midstate(hash1, midstate, message, msgLen);

    // Second SHA256 (on 32-byte result)
    uint hash2[8];
    sha256_full(hash2, (thread const uchar*)hash1, 32);

    // Convert to little-endian for primorial testing
    // Note: Using alignas to ensure proper alignment for constant pointer access
    alignas(8) uint state[9];  // 9 elements: 8 hash words + 1 padding
    for (int i = 0; i < 8; i++) {
        state[i] = bswap32(hash2[7 - i]);  // Reverse order and byte swap
    }
    state[8] = 0;  // Padding word

    // Primorial divisibility testing
    // Only test hashes where MSB is set (hash >= 2^255)
    if (state[7] & (1u << 31)) {
        // Count divisors and build primorial bit field
        uint count = !(state[0] & 0x1);  // Divisible by 2
        uint primorialBitField = count;  // Bit 0: divisible by 2

        // Test divisibility by first 5 primes (3, 5, 7, 13, 17)
        {
            uint acc = sum24(state, 8, modulos24one);
            for (uint i = 0; i < 5; i++) {
                uint isDivisor = check24(acc, divisors24one[i],
                                        multipliers32one[i], offsets32one[i]);
                primorialBitField |= (isDivisor << indexesOne[i]);
                count += isDivisor;
            }
        }

        // Test divisibility by remaining primes (11, 19, 23, ..., 71)
        uint lastBit = 0;
        for (uint i = 0; i < HashPrimorial - 5; i++) {
            uint isDivisor = divisionCheck24(state, 8, divisors24[i],
                                             &modulos24[i * 11],
                                             multipliers32[i], offsets32[i]);
            primorialBitField |= (isDivisor << indexes[i]);
            lastBit = isDivisor ? i + 5 : lastBit;
        }

        // Calculate primorial products for validation
        // prod13 = product of first 13 primes that divide the hash
        uint prod13l = 1;
        for (uint i = 0; i < 8; i++) {
            prod13l = (prod13l * (primorialBitField & (1u << i) ? SMALL_PRIMES[i] : 1u));
        }
        prod13l *= (primorialBitField & (1u << 8) ? SMALL_PRIMES[8] : 1u);

        ulong prod13 = prod13l;
        for (uint i = 9; i < 14; i++) {
            prod13 *= (primorialBitField & (1u << i) ? SMALL_PRIMES[i] : 1u);
        }

        ulong prod14 = prod13 * (primorialBitField & (1u << 14) ? SMALL_PRIMES[14] : 1u);
        ulong prod15 = prod14 * (primorialBitField & (1u << 15) ? SMALL_PRIMES[15] : 1u);

        // Validate primorial sizes against limits
        // clz = count leading zeros; (64 - clz) gives bit length
        int p13isValid = ((64 - clz(prod13)) < LIMIT13);

        int p14Unique = !(p13isValid & (prod14 == prod13));
        int p14isValid = ((64 - clz(prod14)) < LIMIT14) & p14Unique;

        int p15Unique = !(p13isValid & (prod15 == prod13)) &
                        !(p14isValid & (prod15 == prod14));
        int p15isValid = ((64 - clz(prod15)) < LIMIT15) & p15Unique;

        // Store valid candidates
        if (p13isValid) {
            uint index = atomic_fetch_add_explicit(fcount, 1, memory_order_relaxed);
            if (index < 128) {  // Prevent buffer overflow
                resultPrimorial[index] = (primorialBitField & 0xFFFF) | (13u << 16);
                found[index] = (uint)nonce;
            }
        }

        if (p14isValid) {
            uint index = atomic_fetch_add_explicit(fcount, 1, memory_order_relaxed);
            if (index < 128) {
                resultPrimorial[index] = (primorialBitField & 0xFFFF) | (14u << 16);
                found[index] = (uint)nonce;
            }
        }

        if (p15isValid) {
            uint index = atomic_fetch_add_explicit(fcount, 1, memory_order_relaxed);
            if (index < 128) {
                resultPrimorial[index] = (primorialBitField & 0xFFFF) | (15u << 16);
                found[index] = (uint)nonce;
            }
        }
    }
}

/**
 * Minimal Test Kernel
 *
 * Simple kernel to verify Metal dispatch works correctly.
 * Writes a magic value (0xDEADBEEF) to output buffer.
 *
 * @param output Output buffer
 */
kernel void testKernel(device uint* output [[buffer(0)]],
                       uint tid [[thread_position_in_grid]])
{
    if (tid == 0) {
        output[0] = 0xDEADBEEF;
    }
}
