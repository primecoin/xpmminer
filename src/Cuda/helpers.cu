// CUDA kernel configuration and utility functions
// This file is included first when compiling kernels via NVRTC

// Type definitions (needed before other files are concatenated)
typedef unsigned char uint8_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

// Helper function: 24-bit multiply
// NOTE: On modern NVIDIA GPUs (compute capability 2.0+), __umul24 is SLOWER
// than regular multiplication because the hardware is 32-bit native and must
// emulate 24-bit operations. For RTX 4090 (compute capability 8.9), we use
// standard multiplication.
__device__ __forceinline__ uint32_t mul24(uint32_t a, uint32_t b) {
    // Use regular 32-bit multiply - faster on modern GPUs
    return a * b;
}

// Helper function: conditional select (like ternary operator)
// Returns 'a' if condition is true (non-zero), otherwise returns 'b'
__device__ __forceinline__ uint32_t
select(uint32_t a, uint32_t b, int condition) {
    return condition ? a : b;
}

// 64-bit version
__device__ __forceinline__ uint64_t
select(uint64_t a, uint64_t b, int condition) {
    return condition ? a : b;
}
