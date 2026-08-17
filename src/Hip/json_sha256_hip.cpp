#include "hip/hip_runtime.h"

// HashPrimorial constant - number of primes to test divisibility for
#define HashPrimorial 16

// NOTE: SHA256 K constants are already defined in sha256_hip.cpp as 'k[]'
// and shared across all kernels

// SHA256 helper macros
#define ROTR(x,n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x,y,z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTR(x,2) ^ ROTR(x,13) ^ ROTR(x,22))
#define EP1(x) (ROTR(x,6) ^ ROTR(x,11) ^ ROTR(x,25))
#define SIG0(x) (ROTR(x,7) ^ ROTR(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTR(x,17) ^ ROTR(x,19) ^ ((x) >> 10))

// Byte swap for little-endian result
__device__ inline uint32_t bswap32(uint32_t x) {
  return ((x << 24) & 0xff000000) |
         ((x << 8)  & 0x00ff0000) |
         ((x >> 8)  & 0x0000ff00) |
         ((x >> 24) & 0x000000ff);
}

__device__ inline void store_u32_be(uint8_t* out, uint32_t value) {
  out[0] = (uint8_t)(value >> 24);
  out[1] = (uint8_t)(value >> 16);
  out[2] = (uint8_t)(value >> 8);
  out[3] = (uint8_t)value;
}

// NOTE: Primorial divisibility testing constants and functions
// are already defined in sha256_hip.cpp and shared across all kernels.
// We reuse: indexesOne, divisors24one, indexes, divisors24,
// modulos24one, modulos24, multipliers32one, multipliers32,
// offsets32one, offsets32, gPrimes, sum24(), check24(), divisionCheck24()

// Convert uint64 to decimal string, returns length
__device__ int uint64_to_str(uint64_t value, char* buf) {
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
__device__ void sha256_transform(uint32_t* state, const uint8_t* block) {
  uint32_t w[16];
  uint32_t a, b, c, d, e, f, g, h, t1, t2;

  // Prepare message schedule
  for (int i = 0; i < 16; i++) {
    w[i] = ((uint32_t)block[i*4] << 24) |
           ((uint32_t)block[i*4+1] << 16) |
           ((uint32_t)block[i*4+2] << 8) |
           ((uint32_t)block[i*4+3]);
  }

  // Initialize working variables
  a = state[0]; b = state[1]; c = state[2]; d = state[3];
  e = state[4]; f = state[5]; g = state[6]; h = state[7];

  // Main loop
  for (int i = 0; i < 64; i++) {
    const int wi = i & 15;
    if (i >= 16) {
      w[wi] = SIG1(w[(i - 2) & 15]) + w[(i - 7) & 15] +
              SIG0(w[(i - 15) & 15]) + w[wi];
    }
    t1 = h + EP1(e) + CH(e, f, g) + k[i] + w[wi];
    t2 = EP0(a) + MAJ(a, b, c);
    h = g; g = f; f = e; e = d + t1;
    d = c; c = b; b = a; a = t1 + t2;
  }

  // Update state
  state[0] += a; state[1] += b; state[2] += c; state[3] += d;
  state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

// Complete SHA256 computation starting from midstate
__device__ void sha256_from_midstate(uint32_t* hash_out, uint32_t* midstate,
                                     const uint8_t* data, uint32_t len,
                                     uint32_t processedLen) {
  uint32_t state[8];
  const uint32_t originalLen = len;
  for (int i = 0; i < 8; i++) {
    state[i] = midstate[i];
  }

  uint8_t block[64];
  uint32_t idx = 0;

  // Process complete blocks
  while (len >= 64) {
    sha256_transform(state, data);
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
    sha256_transform(state, block);
    idx = 0;
  }

  // Pad with zeros
  while (idx < 56) block[idx++] = 0;

  // Append the length of both the prefix represented by the midstate and all
  // bytes supplied here.  `len` may have been reduced by the block loop.
  uint64_t bitlen = (processedLen + originalLen) * 8;
  for (int i = 7; i >= 0; i--) {
    block[56 + i] = bitlen & 0xff;
    bitlen >>= 8;
  }

  sha256_transform(state, block);

  // Copy output (big-endian)
  for (int i = 0; i < 8; i++) {
    hash_out[i] = state[i];
  }
}

// Full SHA256 (for second hash)
__device__ void sha256_full(uint32_t* hash_out, const uint8_t* data, uint32_t len) {
  uint32_t state[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  };

  uint8_t block[64];
  uint32_t idx = 0;
  const uint32_t originalLen = len;

  // Process complete blocks
  while (len >= 64) {
    sha256_transform(state, data);
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
    sha256_transform(state, block);
    idx = 0;
  }

  while (idx < 56) block[idx++] = 0;

  uint64_t bitlen = (uint64_t)originalLen * 8;
  for (int i = 7; i >= 0; i--) {
    block[56 + i] = bitlen & 0xff;
    bitlen >>= 8;
  }

  sha256_transform(state, block);

  for (int i = 0; i < 8; i++) {
    hash_out[i] = state[i];
  }
}

// Main kernel for JSON-based hash modulus (placeholder - needs primorial testing)
extern "C" __global__ void jsonHashMod(
    uint64_t nonceOffset,
    uint32_t *found,
    uint32_t *fcount,
    uint32_t *resultPrimorial,
    uint32_t *midstate,
    const char *remainingPrefix,
    uint32_t remainingLen,
    uint32_t totalPrefixLen
) {
  uint32_t id = blockIdx.x * blockDim.x + threadIdx.x;
  uint64_t nonce = nonceOffset + id;

  // Build complete JSON message in local buffer
  uint8_t message[128]; // Max: remaining prefix + nonce digits + '}'
  uint32_t msgLen = 0;

  // Copy remaining prefix
  for (uint32_t i = 0; i < remainingLen; i++) {
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

  // First SHA256 (from midstate)
  uint32_t hash1[8];
  sha256_from_midstate(
      hash1, midstate, message, msgLen, totalPrefixLen - remainingLen);

  // Second SHA256 (on 32-byte result)
  uint8_t hash1Bytes[32];
  for (int i = 0; i < 8; i++) {
    store_u32_be(&hash1Bytes[i * 4], hash1[i]);
  }

  uint32_t hash2[8];
  sha256_full(hash2, hash1Bytes, 32);

  // Convert each SHA word to the little-endian uint256 limb layout used by
  // the established block-header hash kernel.  Limb order is unchanged;
  // reversing both words and bytes would reverse the conversion twice.
  uint32_t state[9];  // Note: 9 elements for state (8 hash words + padding word)
  for (int i = 0; i < 8; i++) {
    state[i] = bswap32(hash2[i]);
  }
  state[8] = 0;  // Padding word for sum24 calculations

  // Primorial divisibility testing
  // Only test hashes where MSB is set (hash >= 2^255)
  if (state[7] & (1u << 31)) {
    // Count divisors and build primorial bit field
    uint32_t count = !(state[0] & 0x1);  // Count even numbers (divisible by 2)
    uint32_t primorialBitField = count;  // Bit 0: divisible by 2

    // Test divisibility by first 5 primes (3, 5, 7, 13, 17)
    {
      uint32_t acc = sum24(state, 8, modulos24one);
      #pragma unroll
      for (unsigned i = 0; i < 5; i++) {
        unsigned isDivisor = check24(acc, divisors24one[i], multipliers32one[i], offsets32one[i]);
        primorialBitField |= (isDivisor << indexesOne[i]);
        count += isDivisor;
      }
    }

    // Test divisibility by remaining primes (11, 19, 23, ..., 71)
    unsigned lastBit = 0;
    #pragma unroll
    for (unsigned i = 0; i < HashPrimorial-5; i++) {
      unsigned isDivisor =
        divisionCheck24(state, 8, divisors24[i], &modulos24[i*11], multipliers32[i], offsets32[i]);
      primorialBitField |= (isDivisor << indexes[i]);
      lastBit = isDivisor ? i+5 : lastBit;
    }

    // Calculate the multiplier products.  The bit field marks primes that
    // already divide the hash, so those primes must be omitted from the
    // multiplier (matching bhashmodUsePrecalc in sha256_hip.cpp).
    uint32_t prod13l = 1;
    for (unsigned i = 0; i < 8; i++)
      prod13l = (prod13l * (primorialBitField & (1u << i) ? 1u : gPrimes[i]));
    prod13l *= (primorialBitField & (1u << 8) ? 1u : gPrimes[8]);

    uint64_t prod13 = prod13l;
    for (unsigned i = 9; i < 14; i++)
      prod13 *= (primorialBitField & (1u << i) ? 1u : gPrimes[i]);

    uint64_t prod14 = prod13 * (primorialBitField & (1u << 14) ? 1u : gPrimes[14]);
    uint64_t prod15 = prod14 * (primorialBitField & (1u << 15) ? 1u : gPrimes[15]);

    // Validate primorial sizes against limits (LIMIT13/14/15 defined at compile time)
    int p13isValid = ((64-__clzll(prod13)) < LIMIT13);

    int p14Unique = !(p13isValid & (prod14 == prod13));
    int p14isValid = ((64-__clzll(prod14)) < LIMIT14) & p14Unique;

    int p15Unique = !(p13isValid & (prod15 == prod13)) & !(p14isValid & (prod15 == prod14));
    int p15isValid = ((64-__clzll(prod15)) < LIMIT15) & p15Unique;

    // Store valid candidates
    if (p13isValid) {
      const uint32_t index = atomicAdd(fcount, 1);
      if (index < 128) {  // Prevent buffer overflow
        resultPrimorial[index] = (primorialBitField & 0xFFFF) | (13u << 16);
        found[index] = id;
      }
    }

    if (p14isValid) {
      const uint32_t index = atomicAdd(fcount, 1);
      if (index < 128) {
        resultPrimorial[index] = (primorialBitField & 0xFFFF) | (14u << 16);
        found[index] = id;
      }
    }

    if (p15isValid) {
      const uint32_t index = atomicAdd(fcount, 1);
      if (index < 128) {
        resultPrimorial[index] = (primorialBitField & 0xFFFF) | (15u << 16);
        found[index] = id;
      }
    }
  }
}
