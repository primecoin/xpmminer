/*
 * sieve.metal
 *
 * Sieve of Eratosthenes kernels for Metal
 * Ported from sieve_hip.cpp
 *
 * NOTE: This is a simplified version. Full implementation requires
 * additional complexity for optimal performance.
 */

#include <metal_stdlib>
#include "common.metal"
using namespace metal;

/*
 * Setup Sieve Kernel
 *
 * Computes sieve offsets for each prime
 * Uses modular inverse to find starting positions
 */
kernel void setup_sieve(
    device uint* offset1            [[buffer(0)]],
    device uint* offset2            [[buffer(1)]],
    constant uint* vPrimes          [[buffer(2)]],
    device uint* hash               [[buffer(3)]],
    constant uint& hashid           [[buffer(4)]],
    constant uint* modulos          [[buffer(5)]],
    constant uint& N                [[buffer(6)]],
    constant uint& PCOUNT           [[buffer(7)]],
    constant uint& WIDTH            [[buffer(8)]],
    uint tid [[thread_position_in_grid]])
{
    uint nPrime = vPrimes[tid];

    // Calculate fixed factor mod
    uint tmp[12];  // Assuming N <= 12
    for (uint i = 0; i < N; i++) {
        tmp[i] = hash[hashid * N + i];
    }

    // Local modulos copy
    uint localModulos[11];
    for (uint i = 0; i < N - 2; i++) {
        localModulos[i] = modulos[PCOUNT * i + tid];
    }

    uint nFixedFactorMod = mod32(tmp, N - 1, localModulos, nPrime);

    if (nFixedFactorMod == 0) {
        for (uint line = 0; line < WIDTH; line++) {
            offset1[PCOUNT * line + tid] = 0;
            offset2[PCOUNT * line + tid] = 0;
        }
        return;
    }

    uint nFixedInverse = int_invert(nFixedFactorMod, nPrime);
    for (uint layer = 0; layer < WIDTH; layer++) {
        offset1[PCOUNT * layer + tid] = nFixedInverse;
        offset2[PCOUNT * layer + tid] = nPrime - nFixedInverse;
        nFixedInverse = (nFixedInverse & 0x1) ?
            (nFixedInverse + nPrime) / 2 : nFixedInverse / 2;
    }
}

/*
 * Main Sieve Kernel
 *
 * Performs Sieve of Eratosthenes using threadgroup (shared) memory
 * Marks composite numbers for exclusion
 *
 * Ported from sieve_hip.cpp with full logic
 */
inline void sieve_impl(
    device uint* gsieve_all,
    device uint* offset_all,
    constant uint2* primes,
    constant uint& SIZE,
    constant uint& STRIPES,
    constant uint& PCOUNT,
    constant uint& SIEVERANGE1,
    constant uint& SIEVERANGE2,
    constant uint& SIEVERANGE3,
    constant uint& SCOUNT,
    threadgroup uint* sieve_local,
    uint tid,
    uint gid)
{
    // Apple GPUs expose at most 32 KiB of threadgroup memory. A logical HIP
    // SIZE=12288 stripe therefore runs as two 6144-word local-memory tiles.
    // The output remains one contiguous logical stripe for s_sieve.
    const uint id = tid;
    const uint tileCount = SIZE > 8192 ? 2 : 1;
    const uint tileSize = SIZE / tileCount;
    const uint logicalGid = gid / tileCount;
    const uint tile = gid % tileCount;
    const uint stripe = logicalGid % (STRIPES / 2);
    const uint line = logicalGid / (STRIPES / 2);

    // Single-pass sieve: entry calculation matches HIP
    const uint entry = SIZE * 32 * (stripe + STRIPES / 2) +
                       tile * tileSize * 32;
    const float fentry = float(entry);  // Convert value to float, NOT reinterpret bits

    device uint* offset = &offset_all[PCOUNT * line];

    // Initialize threadgroup sieve to zeros
    for (uint i = id; i < tileSize; i += LSIZE) {
        sieve_local[i] = 0;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Phase 1: Batch processing with nps_all[]
    uint poff = 0;

    for (uint b = 0; b < S1RUNS; b++) {
        uint nps = nps_all[b];
        const uint var = LSIZE >> nps;
        const uint lpoff = id & (var - 1);
        uint ip = id >> (LSIZELOG2 - nps);

        const uint2 tmp1 = primes[poff + ip];
        const uint prime = tmp1.x;
        const float fiprime = as_type<float>(tmp1.y);

        const uint loffset = offset[poff + ip];
        const uint orb = (loffset >> 31) ^ 0x1;
        uint pos = loffset & 0x7FFFFFFF;

        poff += 1u << nps;
        pos += ((uint)(fentry * fiprime) * prime);
        pos -= entry;
        pos += ((int)pos < 0 ? prime : 0);
        if (STRIPES > 256)
            pos += ((int)pos < 0 ? prime : 0);
        pos += (lpoff * prime);

        uint4 vpos = {pos,
                      pos + (var * prime),
                      pos + (var * 2 * prime),
                      pos + (var * 3 * prime)};

        if (var * 4 >= 32) {
            threadgroup atomic_uint* s1 = (threadgroup atomic_uint*)&sieve_local[vpos.x >> 5];
            threadgroup atomic_uint* s2 = (threadgroup atomic_uint*)&sieve_local[vpos.y >> 5];
            threadgroup atomic_uint* s3 = (threadgroup atomic_uint*)&sieve_local[vpos.z >> 5];
            threadgroup atomic_uint* s4 = (threadgroup atomic_uint*)&sieve_local[vpos.w >> 5];
            threadgroup atomic_uint* se = (threadgroup atomic_uint*)&sieve_local[tileSize];
            uint bit1 = orb << (vpos.x % 32);
            uint bit2 = orb << (vpos.y % 32);
            uint bit3 = orb << (vpos.z % 32);
            uint bit4 = orb << (vpos.w % 32);
            const uint add = var * 4 * prime >> 5;
            while (s4 < se) {
                atomic_fetch_or_explicit(s1, bit1, memory_order_relaxed);
                atomic_fetch_or_explicit(s2, bit2, memory_order_relaxed);
                atomic_fetch_or_explicit(s3, bit3, memory_order_relaxed);
                atomic_fetch_or_explicit(s4, bit4, memory_order_relaxed);
                s1 += add;
                s2 += add;
                s3 += add;
                s4 += add;
            }

            if (s1 < se)
                atomic_fetch_or_explicit(s1, bit1, memory_order_relaxed);
            if (s2 < se)
                atomic_fetch_or_explicit(s2, bit2, memory_order_relaxed);
            if (s3 < se)
                atomic_fetch_or_explicit(s3, bit3, memory_order_relaxed);
        } else {
            const uint add = var * 4 * prime;
            while (vpos.w < tileSize * 32) {
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.x >> 5], orb << (vpos.x % 32), memory_order_relaxed);
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.y >> 5], orb << (vpos.y % 32), memory_order_relaxed);
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.z >> 5], orb << (vpos.z % 32), memory_order_relaxed);
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.w >> 5], orb << (vpos.w % 32), memory_order_relaxed);
                vpos.x += add;
                vpos.y += add;
                vpos.z += add;
                vpos.w += add;
            }

            if (vpos.x < tileSize * 32)
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.x >> 5], orb << (vpos.x % 32), memory_order_relaxed);
            if (vpos.y < tileSize * 32)
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.y >> 5], orb << (vpos.y % 32), memory_order_relaxed);
            if (vpos.z < tileSize * 32)
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.z >> 5], orb << (vpos.z % 32), memory_order_relaxed);
        }
    }

    // Phase 2: LIFO buffer for larger primes
    constant uint2* pprimes = &primes[id];
    device uint* poffset = &offset[id];

    uint plifo[NLIFO];
    uint fiplifo[NLIFO];
    uint olifo[NLIFO];

    for (uint i = 0; i < NLIFO; ++i) {
        pprimes += LSIZE;
        poffset += LSIZE;

        const uint2 tmp = *pprimes;
        plifo[i] = tmp.x;
        fiplifo[i] = tmp.y;
        olifo[i] = *poffset;
    }

    uint lpos = 0;

    for (uint ip = 1; ip < SIEVERANGE3; ++ip) {
        const uint prime = plifo[lpos];
        const float fiprime = as_type<float>(fiplifo[lpos]);
        uint pos = olifo[lpos];

        pos += ((uint)(fentry * fiprime) * prime);
        pos -= entry;
        pos += ((int)pos < 0 ? prime : 0);

        uint index = pos >> 5;

        if (ip < SIEVERANGE1) {
            uint2 vpos = {pos, pos + prime};

            const uint add = 2 * prime;
            while (vpos.y < tileSize * 32) {
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.x >> 5], 1u << (vpos.x % 32), memory_order_relaxed);
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.y >> 5], 1u << (vpos.y % 32), memory_order_relaxed);
                vpos.x += add;
                vpos.y += add;
            }

            if (vpos.x < tileSize * 32)
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[vpos.x >> 5], 1u << (vpos.x % 32), memory_order_relaxed);
        } else if (ip < SIEVERANGE2) {
            if (index < tileSize) {
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[index], 1u << (pos % 32), memory_order_relaxed);
                pos += prime;
                index = pos >> 5;
                if (index < tileSize) {
                    atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[index], 1u << (pos % 32), memory_order_relaxed);
                    pos += prime;
                    index = pos >> 5;
                    if (index < tileSize) {
                        atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[index], 1u << (pos % 32), memory_order_relaxed);
                    }
                }
            }
        } else if (ip < SIEVERANGE3) {
            if (index < tileSize) {
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[index], 1u << (pos % 32), memory_order_relaxed);
                pos += prime;
                index = pos >> 5;
                if (index < tileSize) {
                    atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[index], 1u << (pos % 32), memory_order_relaxed);
                }
            }
        } else {
            if (index < tileSize) {
                atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[index], 1u << (pos % 32), memory_order_relaxed);
            }
        }

        if (ip + NLIFO < SCOUNT / LSIZE) {
            pprimes += LSIZE;
            poffset += LSIZE;

            const uint2 tmp = *pprimes;
            plifo[lpos] = tmp.x;
            fiplifo[lpos] = tmp.y;
            olifo[lpos] = *poffset;
        }

        lpos++;
        lpos = lpos % NLIFO;
    }

    for (uint ip = SIEVERANGE3; ip < SCOUNT / LSIZE; ++ip) {
        const uint prime = plifo[lpos];
        const float fiprime = as_type<float>(fiplifo[lpos]);
        uint pos = olifo[lpos];

        pos += ((uint)(fentry * fiprime) * prime);
        pos -= entry;
        pos += ((int)pos < 0 ? prime : 0);

        uint index = pos >> 5;
        if (index < tileSize)
            atomic_fetch_or_explicit((threadgroup atomic_uint*)&sieve_local[index], 1u << (pos % 32), memory_order_relaxed);

        if (ip + NLIFO < SCOUNT / LSIZE) {
            pprimes += LSIZE;
            poffset += LSIZE;

            const uint2 tmp = *pprimes;
            plifo[lpos] = tmp.x;
            fiplifo[lpos] = tmp.y;
            olifo[lpos] = *poffset;
        }

        lpos++;
        lpos = lpos % NLIFO;
    }

    // Synchronize and copy threadgroup memory to device memory
    threadgroup_barrier(mem_flags::mem_threadgroup);
    device uint* gsieve = &gsieve_all[
        SIZE * (STRIPES / 2 * line + stripe) + tile * tileSize];
    for (uint i = id; i < tileSize; i += LSIZE) {
        gsieve[i] = sieve_local[i];
    }
}

kernel void sieve(
    device uint* gsieve_all         [[buffer(0)]],
    device uint* offset_all         [[buffer(1)]],
    constant uint2* primes          [[buffer(2)]],
    constant uint& SIZE             [[buffer(3)]],
    constant uint& STRIPES          [[buffer(4)]],
    constant uint& PCOUNT           [[buffer(5)]],
    constant uint& SIEVERANGE1      [[buffer(6)]],
    constant uint& SIEVERANGE2      [[buffer(7)]],
    constant uint& SIEVERANGE3      [[buffer(8)]],
    constant uint& SCOUNT           [[buffer(9)]],
    uint tid [[thread_position_in_threadgroup]],
    uint gid [[threadgroup_position_in_grid]])
{
    threadgroup uint sieve_local[METAL_SIEVE_SIZE];
    sieve_impl(gsieve_all, offset_all, primes, SIZE, STRIPES, PCOUNT,
               SIEVERANGE1, SIEVERANGE2, SIEVERANGE3, SCOUNT,
               sieve_local, tid, gid);
}

kernel void sieve_dynamic(
    device uint* gsieve_all         [[buffer(0)]],
    device uint* offset_all         [[buffer(1)]],
    constant uint2* primes          [[buffer(2)]],
    constant uint& SIZE             [[buffer(3)]],
    constant uint& STRIPES          [[buffer(4)]],
    constant uint& PCOUNT           [[buffer(5)]],
    constant uint& SIEVERANGE1      [[buffer(6)]],
    constant uint& SIEVERANGE2      [[buffer(7)]],
    constant uint& SIEVERANGE3      [[buffer(8)]],
    constant uint& SCOUNT           [[buffer(9)]],
    threadgroup uint* sieve_local   [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint gid [[threadgroup_position_in_grid]])
{
    sieve_impl(gsieve_all, offset_all, primes, SIZE, STRIPES, PCOUNT,
               SIEVERANGE1, SIEVERANGE2, SIEVERANGE3, SCOUNT,
               sieve_local, tid, gid);
}

/*
 * Sieve Search Kernel
 *
 * Scans sieve results to find prime chain candidates
 * Identifies Cunningham and BiTwin chains
 */
kernel void s_sieve(
    constant uint* gsieve1          [[buffer(0)]],
    constant uint* gsieve2          [[buffer(1)]],
    device fermat_t* found320       [[buffer(2)]],
    device fermat_t* found352       [[buffer(3)]],
    device atomic_uint* fcount      [[buffer(4)]],
    constant uint& hashid           [[buffer(5)]],
    constant uint& hashSize         [[buffer(6)]],
    constant uint& depth            [[buffer(7)]],
    constant uint& TARGET           [[buffer(8)]],
    constant uint& WIDTH            [[buffer(9)]],
    constant uint& SIZE             [[buffer(10)]],
    constant uint& STRIPES          [[buffer(11)]],
    uint tid [[thread_position_in_grid]])
{
    // Load sieve data for this thread
    uint tmp1[40];  // WIDTH, max 40 (balanced for Metal constraints)
    for (uint i = 0; i < WIDTH; i++) {
        tmp1[i] = gsieve1[SIZE * STRIPES / 2 * i + tid];
    }

    // Search for Cunningham1 chains (type 0)
    for (uint start = 0; start <= WIDTH - TARGET; start++) {
        uint mask = 0;
        for (uint line = 0; line < TARGET; line++) {
            mask |= tmp1[start + line];
        }

        if (mask != 0xFFFFFFFF) {
            uint bit = 31 - clz(~mask);
            uint multiplier = bit + tid * 32 + SIZE * 32 * STRIPES / 2;
            uint maxSize = hashSize + (32 - clz(multiplier)) + start + depth;

            uint addr = atomic_fetch_add_explicit(
                &fcount[(maxSize <= 320) ? 0 : 1], 1, memory_order_relaxed);

            fermat_t info;
            info.index = multiplier;
            info.origin = start;
            info.chainpos = 0;
            info.type = 0;  // Cunningham1
            info.hashid = hashid;

            if (maxSize <= 320 && addr < 128 * 1024) {
                found320[addr] = info;
            } else if (addr < 128 * 1024) {
                found352[addr] = info;
            }
        }
    }

    // Search for Cunningham2 chains (type 1)
    uint tmp2[40];  // WIDTH, max 40 (balanced for Metal constraints)
    for (uint i = 0; i < WIDTH; i++) {
        tmp2[i] = gsieve2[SIZE * STRIPES / 2 * i + tid];
    }

    for (uint start = 0; start <= WIDTH - TARGET; start++) {
        uint mask = 0;
        for (uint line = 0; line < TARGET; line++) {
            mask |= tmp2[start + line];
        }

        if (mask != 0xFFFFFFFF) {
            uint bit = 31 - clz(~mask);
            uint multiplier = bit + tid * 32 + SIZE * 32 * STRIPES / 2;
            uint maxSize = hashSize + (32 - clz(multiplier)) + start + depth;

            uint addr = atomic_fetch_add_explicit(
                &fcount[(maxSize <= 320) ? 0 : 1], 1, memory_order_relaxed);

            fermat_t info;
            info.index = multiplier;
            info.origin = start;
            info.chainpos = 0;
            info.type = 1;  // Cunningham2
            info.hashid = hashid;

            if (maxSize <= 320 && addr < 128 * 1024) {
                found320[addr] = info;
            } else if (addr < 128 * 1024) {
                found352[addr] = info;
            }
        }
    }

    // Search for BiTwin chains (type 2)
    const uint bitwinLayers = (TARGET / 2) + (TARGET % 2);
    for (uint i = 0; i < WIDTH; i++) {
        tmp2[i] |= tmp1[i];  // Combine both sieves
    }

    for (uint start = 0; start <= WIDTH - bitwinLayers; start++) {
        uint mask = 0;
        for (uint line = 0; line < TARGET / 2; line++) {
            mask |= tmp2[start + line];
        }

        if (TARGET & 1u) {
            mask |= tmp1[start + TARGET / 2];
        }

        if (mask != 0xFFFFFFFF) {
            uint bit = 31 - clz(~mask);
            uint multiplier = bit + tid * 32 + SIZE * 32 * STRIPES / 2;
            uint maxSize = hashSize + (32 - clz(multiplier)) + start + (depth / 2) + (depth & 1);

            uint addr = atomic_fetch_add_explicit(
                &fcount[(maxSize <= 320) ? 0 : 1], 1, memory_order_relaxed);

            fermat_t info;
            info.index = multiplier;
            info.origin = start;
            info.chainpos = 0;
            info.type = 2;  // BiTwin
            info.hashid = hashid;

            if (maxSize <= 320 && addr < 128 * 1024) {
                found320[addr] = info;
            } else if (addr < 128 * 1024) {
                found352[addr] = info;
            }
        }
    }
}
