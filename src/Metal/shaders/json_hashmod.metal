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
    0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1
};

// Modulos for remaining primes (11 x 14 array)
constant uint modulos24[] = {
    0x5,  0x3,  0x4,  0x9,  0x1,  0x5,  0x3,  0x4,  0x9,  0x1,  0x5, // 11
    0x7,  0xb,  0x1,  0x7,  0xb,  0x1,  0x7,  0xb,  0x1,  0x7,  0xb, // 19
    0x4,  0x10, 0x12, 0x3,  0xc,  0x2,  0x8,  0x9,  0xd,  0x6,  0x1, // 23
    0x14, 0x17, 0x19, 0x7,  0x18, 0x10, 0x1,  0x14, 0x17, 0x19, 0x7, // 29
    0x10, 0x8,  0x4,  0x2,  0x1,  0x10, 0x8,  0x4,  0x2,  0x1,  0x10, // 31
    0xa,  0x1a, 0x1,  0xa,  0x1a, 0x1,  0xa,  0x1a, 0x1,  0xa,  0x1a, // 37
    0x10, 0xa,  0x25, 0x12, 0x1,  0x10, 0xa,  0x25, 0x12, 0x1,  0x10, // 41
    0x23, 0x15, 0x4,  0xb,  0x29, 0x10, 0x1,  0x23, 0x15, 0x4,  0xb, // 43
    0x2,  0x4,  0x8,  0x10, 0x20, 0x11, 0x22, 0x15, 0x2a, 0x25, 0x1b, // 47
    0xd,  0xa,  0x18, 0x2f, 0x1c, 0x2e, 0xf,  0x24, 0x2c, 0x2a, 0x10, // 53
    0x23, 0x2d, 0x29, 0x13, 0x10, 0x1d, 0xc,  0x7,  0x9,  0x14, 0x33, // 59
    0x14, 0x22, 0x9,  0x3a, 0x1,  0x14, 0x22, 0x9,  0x3a, 0x1,  0x14, // 61
    0xe,  0x3e, 0x40, 0x19, 0xf,  0x9,  0x3b, 0x16, 0x28, 0x18, 0x1, // 67
    0x3a, 0x1b, 0x4,  0x13, 0x25, 0x10, 0x5,  0x6,  0x40, 0x14, 0x18  // 71
};

// Multiplication constants for fast division
constant uint multipliers32one[] = {
    0xAAAAAAAB, // 3
    0x66666667, // 5
    0x92492493, // 7
    0x4EC4EC4F, // 13
    0x78787879  // 17
};

constant uint multipliers32[] = {
    0x2E8BA2E9, // 11
    0x6BCA1AF3, // 19
    0xB21642C9, // 23
    0x8D3DCB09, // 29
    0x84210843, // 31
    0xDD67C8A7, // 37
    0x63E7063F, // 41
    0x2FA0BE83, // 43
    0xAE4C415D, // 47
    0x4D4873ED, // 53
    0x22B63CBF, // 59
    0x4325C53F, // 61
    0x07A44C6B, // 67
    0xE6C2B449  // 71
};

// Offset constants for fast division
constant uint offsets32one[] = {
    1, // 3
    1, // 5
    2, // 7
    2, // 13
    3  // 17
};

constant uint offsets32[] = {
    1,  // 11
    3,  // 19
    4,  // 23
    4,  // 29
    4,  // 31
    5,  // 37
    4,  // 41
    3,  // 43
    5,  // 47
    4,  // 53
    3,  // 59
    4,  // 61
    1,  // 67
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

inline void store_u32_be(thread uchar* out, uint value) {
    out[0] = (uchar)(value >> 24);
    out[1] = (uchar)(value >> 16);
    out[2] = (uchar)(value >> 8);
    out[3] = (uchar)value;
}

// Apply the Primecoin hash gate and emit the usable primorial variants.  Both
// getwork JSON hashing and getblocktemplate block-header hashing must use the
// exact same filtering rules so the downstream sieve sees equivalent inputs.
inline void emit_hash_candidates(thread const uint* state,
                                 uint foundValue,
                                 device uint* found,
                                 device atomic_uint* fcount,
                                 device uint* resultPrimorial,
                                 uint LIMIT13,
                                 uint LIMIT14,
                                 uint LIMIT15) {
    // Primecoin searches only the upper half of the uint256 range.
    if (!(state[7] & (1u << 31))) {
        return;
    }

    uint count = !(state[0] & 0x1);
    uint primorialBitField = count;

    {
        uint acc = sum24(state, 8, modulos24one);
        for (uint i = 0; i < 5; i++) {
            uint isDivisor = check24(acc, divisors24one[i],
                                    multipliers32one[i], offsets32one[i]);
            primorialBitField |= (isDivisor << indexesOne[i]);
            count += isDivisor;
        }
    }

    for (uint i = 0; i < HashPrimorial - 5; i++) {
        uint isDivisor = divisionCheck24(state, 8, divisors24[i],
                                         &modulos24[i * 11],
                                         multipliers32[i], offsets32[i]);
        primorialBitField |= (isDivisor << indexes[i]);
    }

    // A set bit means the hash already contains that prime.  Omit it from the
    // multiplier passed to the sieve, matching the CUDA/HIP block hash path.
    uint prod13l = 1;
    for (uint i = 0; i < 9; i++) {
        prod13l *= primorialBitField & (1u << i) ? 1u : SMALL_PRIMES[i];
    }

    ulong prod13 = prod13l;
    for (uint i = 9; i < 14; i++) {
        prod13 *= primorialBitField & (1u << i) ? 1u : SMALL_PRIMES[i];
    }

    ulong prod14 = prod13 *
        (primorialBitField & (1u << 14) ? 1u : SMALL_PRIMES[14]);
    ulong prod15 = prod14 *
        (primorialBitField & (1u << 15) ? 1u : SMALL_PRIMES[15]);

    int p13isValid = ((64 - clz(prod13)) < LIMIT13);
    int p14isValid = ((64 - clz(prod14)) < LIMIT14) &
                     !(p13isValid & (prod14 == prod13));
    int p15isValid = ((64 - clz(prod15)) < LIMIT15) &
                     !(p13isValid & (prod15 == prod13)) &
                     !(p14isValid & (prod15 == prod14));

    if (p13isValid) {
        uint index = atomic_fetch_add_explicit(fcount, 1, memory_order_relaxed);
        if (index < 128) {
            resultPrimorial[index] = (primorialBitField & 0xFFFF) | (13u << 16);
            found[index] = foundValue;
        }
    }
    if (p14isValid) {
        uint index = atomic_fetch_add_explicit(fcount, 1, memory_order_relaxed);
        if (index < 128) {
            resultPrimorial[index] = (primorialBitField & 0xFFFF) | (14u << 16);
            found[index] = foundValue;
        }
    }
    if (p15isValid) {
        uint index = atomic_fetch_add_explicit(fcount, 1, memory_order_relaxed);
        if (index < 128) {
            resultPrimorial[index] = (primorialBitField & 0xFFFF) | (15u << 16);
            found[index] = foundValue;
        }
    }
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

    // prepareJsonMidstate prehashes every complete fixed-prefix block, leaving
    // at most 63 prefix bytes plus 20 nonce digits and the closing brace.
    // Keeping this scratch array small reduces each hashing thread's register /
    // stack footprint on Apple GPUs.
    uchar message[96];
    uint msgLen = 0;

    if (remainingLen >= 64) {
        return;
    }

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
    if (msgLen > 84) {
        return;
    }

    // First SHA256 (from midstate)
    uint hash1[8];
    sha256_from_midstate(hash1, midstate, message, msgLen,
                         totalPrefixLen - remainingLen);

    // Second SHA256 (on 32-byte result)
    uchar hash1Bytes[32];
    for (uint i = 0; i < 8; i++) {
        store_u32_be(&hash1Bytes[i * 4], hash1[i]);
    }

    uint hash2[8];
    sha256_full(hash2, hash1Bytes, 32);

    // Convert each SHA word to the little-endian uint256 limb layout used by
    // the established block-header hash kernel. Limb order is unchanged.
    alignas(8) uint state[9];  // 9 elements: 8 hash words + 1 padding
    for (int i = 0; i < 8; i++) {
        state[i] = bswap32(hash2[i]);
    }
    state[8] = 0;  // Padding word

    emit_hash_candidates(state, tid, found, fcount, resultPrimorial,
                         LIMIT13, LIMIT14, LIMIT15);
}

inline void block_header_hash(thread uint* state,
                              constant uint* midstate,
                              uint merkle,
                              uint blockTime,
                              uint nbits,
                              uint nonce) {
    uchar tail[64];
    for (uint i = 0; i < 64; i++) {
        tail[i] = 0;
    }

    // precalcSHA256 supplies these values in SHA message-word byte order.
    store_u32_be(&tail[0], merkle);
    store_u32_be(&tail[4], blockTime);
    store_u32_be(&tail[8], nbits);
    store_u32_be(&tail[12], bswap32(nonce));
    tail[16] = 0x80;
    store_u32_be(&tail[60], 640u);

    uint first[8];
    for (uint i = 0; i < 8; i++) {
        first[i] = midstate[i];
    }
    sha256_transform_thread(first, tail);

    uchar firstBytes[32];
    for (uint i = 0; i < 8; i++) {
        store_u32_be(&firstBytes[i * 4], first[i]);
    }
    uint second[8];
    sha256_full(second, firstBytes, 32);

    for (uint i = 0; i < 8; i++) {
        state[i] = bswap32(second[i]);
    }
    state[8] = 0;
}

/**
 * Hash a traditional 80-byte Primecoin block header.
 *
 * The host supplies the SHA-256 state after the first 64 header bytes and the
 * three fixed words in the remaining header.  Metal constructs the nonce word
 * and padding, finishes the first SHA-256, then computes the second SHA-256.
 * `found` stores a batch-relative thread index so the host can use the same
 * nonce reconstruction as the JSON kernel.
 */
kernel void blockHashMod(
    constant uint& nonceOffset             [[buffer(0)]],
    device uint* found                     [[buffer(1)]],
    device atomic_uint* fcount             [[buffer(2)]],
    device uint* resultPrimorial           [[buffer(3)]],
    constant uint* midstate                [[buffer(4)]],
    constant uint& merkle                  [[buffer(5)]],
    constant uint& blockTime               [[buffer(6)]],
    constant uint& nbits                   [[buffer(7)]],
    constant uint& LIMIT13                 [[buffer(8)]],
    constant uint& LIMIT14                 [[buffer(9)]],
    constant uint& LIMIT15                 [[buffer(10)]],
    uint tid [[thread_position_in_grid]]) {
    alignas(8) uint state[9];
    block_header_hash(state, midstate, merkle, blockTime, nbits,
                      nonceOffset + tid);

    emit_hash_candidates(state, tid, found, fcount, resultPrimorial,
                         LIMIT13, LIMIT14, LIMIT15);
}

// Exact hash output used by the isolated correctness benchmark.  Keeping this
// separate from blockHashMod avoids adding production buffer traffic.
kernel void blockHashDebug(
    constant uint& nonceOffset             [[buffer(0)]],
    constant uint* midstate                [[buffer(1)]],
    constant uint& merkle                  [[buffer(2)]],
    constant uint& blockTime               [[buffer(3)]],
    constant uint& nbits                   [[buffer(4)]],
    device uint* output                    [[buffer(5)]],
    uint tid [[thread_position_in_grid]]) {
    alignas(8) uint state[9];
    block_header_hash(state, midstate, merkle, blockTime, nbits,
                      nonceOffset + tid);
    for (uint i = 0; i < 8; i++) {
        output[tid * 8 + i] = state[i];
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
