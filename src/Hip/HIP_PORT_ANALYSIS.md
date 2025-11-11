# HIP Port Analysis - Commit 22d4027

## Executive Summary

This document provides a comprehensive analysis of commit `22d4027adf68c820777436a80df1a25439fee9b3`, which successfully ported the CUDA-based XPMMiner to AMD's HIP platform. The commit transformed non-functional HIP code into a miner capable of running on AMD GPUs through the ROCm/HIP runtime.

**Commit Statistics:**
- 18 files changed
- 5,508 additions (+)
- 4,482 deletions (-)
- Net change: +1,026 lines

## Purpose of the HIP Folder

The HIP folder (`src/hipify/`, later renamed to `src/Hip/`) serves as an **AMD GPU mining implementation** using AMD's HIP (Heterogeneous-compute Interface for Portability) API. HIP is AMD's answer to NVIDIA's CUDA, providing:

1. **Cross-vendor GPU support**: Write once, run on AMD and NVIDIA hardware
2. **ROCm runtime compatibility**: Native support for AMD's ROCm software stack
3. **Runtime kernel compilation**: Uses HIPRTC (HIP Runtime Compilation) to compile GPU kernels at runtime, similar to CUDA's NVRTC
4. **Performance parity**: Aims to achieve similar performance to CUDA miner on AMD hardware

The folder contains a complete mining pipeline including:
- Main mining orchestrator (`xpmclient_hip.cpp`)
- GPU kernels for SHA256 hashing, sieving, and Fermat testing
- Benchmarking tools for performance validation
- Utility functions for HIP API management

---

## Detailed File-by-File Analysis

### 1. src/hipify/CMakeLists.txt (NEW FILE, +140 lines)

**Purpose**: Build system configuration for HIP miner

**Key Components:**

#### ROCm Detection (Lines 3-23)
```cmake
if (NOT DEFINED ROCM_PATH)
    if (NOT DEFINED ENV{ROCM_PATH})
        set(ROCM_PATH "/opt/rocm" CACHE PATH "Path to ROCm installation")
    else()
        set(ROCM_PATH $ENV{ROCM_PATH} CACHE PATH "Path to ROCm installation")
    endif()
endif()

find_package(HIP QUIET)
if (NOT HIP_FOUND)
    message(STATUS "HIP not found. Skipping HIP miner build.")
    return()
endif()
```

**Why**:
- Gracefully handles missing ROCm installation (doesn't fail build)
- Supports custom ROCm paths via environment variable
- Allows project to build on systems without AMD GPU support

#### HIPRTC Library Discovery (Lines 31-38)
```cmake
find_library(HIP_HIPRTC_LIBRARY hiprtc
    HINTS ${ROCM_PATH}/lib
)
```

**Why**:
- HIPRTC is required for runtime kernel compilation
- Unlike CUDA's static compilation, HIP kernels are compiled when the miner starts
- This enables GPU-specific optimizations (gfx906, gfx1030, etc.)

#### Platform Restrictions (Lines 55-64)
```cmake
if (WIN32)
  message(FATAL_ERROR "HIP miner does not support Windows. Use Linux.")
elseif(APPLE)
  message(FATAL_ERROR "HIP miner does not support macOS. Use Linux with AMD GPU.")
```

**Why**:
- ROCm only supports Linux
- Windows/macOS support would require different drivers (not implemented)

#### Kernel Source Auto-Copy (Lines 116-123)
```cmake
file(GLOB HIP_KERNEL_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/*_hip.cpp")
add_custom_command(TARGET xpmhip POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${HIP_KERNEL_SOURCES}
        ${CMAKE_CURRENT_BINARY_DIR}/xpm/cuda/
    COMMENT "Copying HIP kernel source files to build directory for HIPRTC runtime compilation"
)
```

**Why**:
- HIPRTC reads kernel source code at runtime from disk
- Kernel files must be in `xpm/cuda/` directory (path compatibility with CUDA version)
- Auto-copy ensures `make` produces immediately runnable binary

---

### 2. src/hipify/hiputil.h (MODIFIED, 102→100 lines)

**Purpose**: HIP utility macros and wrapper classes

#### Change 1: Header Guard Rename
```diff
-#ifndef __CUDALIB_H_
-#define __CUDALIB_H_
+#ifndef __HIPLIB_H_
+#define __HIPLIB_H_
```

**Why**: Correct naming for HIP-specific header

#### Change 2: Macro Renames
```diff
-#define NVRTC_SAFE_CALL(x)
+#define HIPRTC_SAFE_CALL(x)

-#define CUDA_SAFE_CALL(x)
+#define HIP_SAFE_CALL(x)
```

**Why**:
- NVRTC → HIPRTC: Reflects HIP Runtime Compiler (HIPRTC) vs NVIDIA Runtime Compiler (NVRTC)
- CUDA → HIP: Reflects HIP API naming conventions
- Both macros internally use their respective types (`hiprtcResult` and `hipError_t`)

#### Change 3: Error Handling Style
```diff
-    const char *msg;
-    hipDrvGetErrorName(result, &msg);
+    const char *msg = hipGetErrorName(result);
```

**Why**:
- Uses direct return value instead of out-parameter pattern
- Cleaner, more concise code style

#### Change 4: Class Rename
```diff
-class cudaBuffer {
+class hipBuffer {
```

**Why**:
- Consistent naming convention
- Used throughout codebase for GPU memory management
- Template class for type-safe device memory

#### Change 5: Memory Free Fix
```diff
-      hipError_t result = hipFree(_deviceData);
+      hipError_t result = hipFree((void*)_deviceData);
```

**Why**:
- `_deviceData` is `hipDeviceptr_t` (integer type on HIP)
- `hipFree()` expects `void*` pointer
- Explicit cast resolves type mismatch

#### Change 6: Function Rename
```diff
-bool cudaCompileKernel(...)
+bool hipCompileKernel(...)
```

**Why**: Semantic accuracy for HIP runtime compilation

---

### 3. src/hipify/hiputil.cpp (MODIFIED, major refactor)

**Purpose**: Implementation of HIP runtime kernel compilation

#### Key Changes:

**A. Error Handling Updates**
```cpp
// Old: CUDA_SAFE_CALL(...)
// New: HIP_SAFE_CALL(...)
```
Applied to all ~20 HIP API calls throughout file.

**B. Compilation Options for AMD GPUs**
```cpp
const char *compileOptions[] = {
  "--offload-arch=gfx906",  // Vega 20, MI50/60
  "--offload-arch=gfx908",  // MI100
  "--offload-arch=gfx90a",  // MI210/250
  "--offload-arch=gfx1030", // Navi 21 (RX 6800/6900)
  "-munsafe-fp-atomics",    // Enable faster atomic operations
  "-ffast-math",            // Aggressive floating-point optimizations
};
```

**Why**:
- Different AMD architectures require different instruction sets
- `-munsafe-fp-atomics`: Enables hardware atomic operations (critical for mining performance)
- `-ffast-math`: Trades precision for speed (acceptable for primality testing)
- Multi-arch compilation ensures wide GPU compatibility

**C. Runtime Compilation Flow**
```cpp
hiprtcCreateProgram()     // Parse kernel source
hiprtcCompileProgram()    // Compile to ISA
hiprtcGetCode()           // Extract binary
hipModuleLoadData()       // Load into GPU
hipModuleGetFunction()    // Get kernel entry points
```

**Why**:
- Allows GPU-specific optimizations unavailable at build time
- Different from CUDA which can use pre-compiled PTX

---

### 4. src/hipify/xpmclient_hip.h (MODIFIED, 118 lines changed)

**Purpose**: Main mining orchestrator header

#### Change 1: Include Update
```diff
-#include "cudautil.h"
+#include "hiputil.h"
```

#### Change 2: Struct Rename and Extension
```diff
-struct CUDADeviceInfo {
+struct HIPDeviceInfo {
+  char gcnArchName[256];  // NEW: AMD-specific architecture name
```

**Why**:
- AMD uses GCN/RDNA architecture names (gfx906, gfx1030, etc.)
- NVIDIA uses compute capability (7.5, 8.6, etc.)
- Need to store arch name for diagnostic/optimization purposes

#### Change 3: Buffer Type Updates
```diff
-    cudaBuffer<uint32_t> midstate;
-    cudaBuffer<uint32_t> found;
+    hipBuffer<uint32_t> midstate;
+    hipBuffer<uint32_t> found;
```

**Why**: Consistent use of `hipBuffer` template class (20+ occurrences)

#### Change 4: Whitespace Normalization
Multiple trailing spaces removed throughout file.

**Why**: Code hygiene (doesn't affect functionality)

---

### 5. src/hipify/xpmclient_hip.cpp (MODIFIED, 370 changes)

**Purpose**: Main mining logic implementation

This is the most critical file with extensive changes. Breaking down by category:

#### A. API Call Replacements (150+ occurrences)

| Old CUDA API | New HIP API | Purpose |
|-------------|-------------|---------|
| `CUDA_SAFE_CALL` | `HIP_SAFE_CALL` | Error handling macro |
| `cuInit()` | `hipInit()` | Initialize runtime |
| `cuDeviceGet()` | `hipDeviceGet()` | Get device handle |
| `cuDeviceGetAttribute()` | `hipDeviceGetAttribute()` | Query device properties |
| `cuDeviceGetName()` | `hipDeviceGetName()` | Get device name |
| `cuCtxCreate()` | `hipCtxCreate()` | Create execution context |
| `cuMemAlloc()` | `hipMalloc()` | Allocate device memory |
| `cuMemcpyHtoD()` | `hipMemcpyHtoD()` | Host-to-device transfer |
| `cuMemcpyDtoH()` | `hipMemcpyDtoH()` | Device-to-host transfer |
| `cuModuleLaunchKernel()` | `hipModuleLaunchKernel()` | Launch GPU kernel |
| `cuCtxSynchronize()` | `hipDeviceSynchronize()` | Wait for GPU completion |

#### B. Device Information Extraction
```cpp
// OLD (CUDA):
cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, device);
cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, device);

// NEW (HIP):
hipDeviceGetAttribute(&gcnArch, hipDeviceAttributeGcnArch, device);
hipDeviceGetName(deviceInfo.gcnArchName, sizeof(deviceInfo.gcnArchName), device);
```

**Why**:
- AMD doesn't use "compute capability" concept
- GCN arch number maps to generation (gfx906 = arch 906)
- More informative device naming

#### C. Benchmark Mode Independence
```cpp
// Added conditional RPC initialization:
if (!benchmarkMode) {
    gbp = new GetBlockTemplateContext(...);
    submit = new SubmitContext(...);
} else {
    gbp = nullptr;
    submit = nullptr;
}
```

**Why**:
- Previous code required RPC server even in benchmark mode
- Benchmark only tests GPU compute, doesn't need network
- Allows offline performance testing

#### D. Work Fetch Logic Updates
```cpp
if (gbp && gbp->get()->data) {
    // Mining logic
} else if (benchmarkMode) {
    // Benchmark logic
} else {
    // Wait for work
}
```

**Why**:
- Handles null `gbp` pointer in benchmark mode
- Prevents segmentation faults
- Clean separation of mining vs benchmarking paths

---

### 6. src/hipify/benchmarks_hip.cpp (MODIFIED, 402 changes)

**Purpose**: GPU performance benchmarking suite

#### Major Restructuring:

**Before**: Single monolithic 959-line file containing both host and device code

**After**: Split into two files:
- `benchmarks_hip.cpp`: Host-side orchestration (40KB)
- `benchmarks_kernels_hip.cpp`: Device-side kernels (NEW, 8KB)

#### Key Algorithm Changes:

**A. Benchmark Alignment with OpenCL Standard**
```cpp
// CUDA approach: Copy upper half of multiplication result
memcpy(Operand1, target+mulOperandSize, mulOperandSize*sizeof(uint32_t));

// OpenCL/HIP approach: Copy lower half
memcpy(Operand1, target, gmpLimbsNum*sizeof(mp_limb_t));
```

**Why**:
- OpenCL and HIP have different modular arithmetic conventions
- Lower-half approach matches AMD GPU instruction behavior
- Ensures GPU results match CPU validation

**B. Performance Metric Changes**
```cpp
// Old: Report time only
LOG_F(INFO, "multiply 320 bits: %.3lfms", gpuTime);

// New: Report operations/second + speedup
LOG_F(INFO, "Multiply %u bits: GPU %.0lf Mops/s, CPU %.0lf Mops/s (%.2fx faster)",
      mulOperandSize*32, gpuMopsPerSec, cpuMopsPerSec, speedup);
```

**Why**:
- Ops/sec is architecture-independent metric
- Allows fair comparison across CUDA, OpenCL, HIP
- Speedup ratio shows GPU advantage clearly

**C. Memory Layout Validation**
```cpp
for (unsigned i = 0; i < elementsNum; i++) {
  if (memcmp(&mR[i*mulOperandSize*2], &cpuR[i*mulOperandSize*2],
             4*mulOperandSize*2) != 0) {
    // Print detailed error...
  }
}
```

**Why**:
- Catches endianness issues
- Validates memory transfer correctness
- Critical for debugging GPU-CPU data flow

---

### 7. src/hipify/benchmarks_kernels_hip.cpp (NEW FILE, +258 lines)

**Purpose**: Device-side benchmark kernel implementations

#### Contents:
```cpp
extern "C" __global__ void multiplyBenchmark256(...) { }
extern "C" __global__ void multiplyBenchmark384(...) { }
extern "C" __global__ void fermatTestBenchmark256(...) { }
extern "C" __global__ void fermatTestBenchmark384(...) { }
```

**Key Features:**

**A. extern "C" Linkage**
```cpp
extern "C" __global__ void kernel_name(...)
```

**Why**:
- Prevents C++ name mangling
- HIPRTC needs predictable symbol names for `hipModuleGetFunction()`
- Ensures kernel can be found at runtime

**B. Fixed-Size Arithmetic Operations**
```cpp
// 256-bit multiplication benchmark
for (int i = 0; i < 512; i++) {
    // Montgomery multiplication
    monMul256(operand1, operand2, modulus, invModulus);
}
```

**Why**:
- Tests raw computational throughput
- 512 iterations per thread = measurable timing
- Specific bit sizes (256, 384) match Primecoin requirements

**C. Fermat Test Implementation**
```cpp
// Probabilistic primality test: 2^(N-1) ≡ 1 (mod N)
mpz_class exponent = N - 1;
modular_exponentiation(2, exponent, N);
```

**Why**:
- Core algorithm for Primecoin mining
- GPU acceleration critical for throughput
- Benchmark validates correctness + performance

---

### 8. src/hipify/fermat_hip.cpp (MODIFIED, 55 changes)

**Purpose**: Fermat primality test GPU kernels

#### Critical Changes:

**A. Type Definitions for HIPRTC**
```cpp
// NEW: Added at top of file
typedef unsigned char uint8_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
```

**Why**:
- HIPRTC doesn't automatically include standard headers
- Runtime compilation needs explicit type definitions
- CUDA includes these by default (HIP doesn't)

**B. Forward Declarations**
```cpp
__device__ void monSqr320(uint32_t *op, const uint32_t *mod, uint32_t invm);
__device__ void monMul320(uint32_t *op1, const uint32_t *op2, const uint32_t *mod, uint32_t invm);
__device__ void redcHalf320(uint32_t *op, const uint32_t *mod, uint32_t invm);
// ... and 15+ more
```

**Why**:
- Each kernel file compiled independently by HIPRTC
- Cross-file device function calls need declarations
- Links to `procs_hip.cpp` implementations

**C. ROCm Compiler Bug Workaround**
```cpp
// WORKAROUND: ROCm/HIP compiler optimization bug
// Without volatile access, the compiler incorrectly optimizes away writes inside mulProductScan352to32
// This forces the compiler to treat m[] as having side effects
volatile uint32_t* vm = (volatile uint32_t*)m;
(void)vm[0];
```

**Why**:
- ROCm compiler has aggressive optimization bug
- Writes to array `m[]` get eliminated incorrectly
- Volatile access forces compiler to preserve operations
- Documented workaround for known issue

**D. Kernel Export Declarations**
```diff
-__global__ void fermat_kernel320(...)
+extern "C" __global__ void fermat_kernel320(...)
```

**Why**:
- All kernel functions need `extern "C"` for runtime compilation
- Applied to 6 kernel functions: `getconfig`, `setup_fermat`, `fermat_kernel`, `fermat_kernel320`, `check_fermat`, `setup_sieve`

**E. Memory Access Optimization**
```cpp
extern "C" __global__ void fermat_kernel(
    uint8_t * __restrict__ result,
    const uint32_t * __restrict__ fprimes)
```

**Why**:
- `__restrict__` keyword tells compiler pointers don't alias
- Enables more aggressive optimization
- Critical for GPU memory bandwidth

---

### 9. src/hipify/sha256_hip.cpp (MODIFIED, 11 changes)

**Purpose**: SHA256 hashing and hash modulus GPU kernel

#### Key Changes:

**A. Multiply Optimization**
```diff
-    // Use regular multiply - faster on modern GPUs (CC 2.0+)
-    prod13l = mul24(prod13l, select(...));
+    // AMD optimization: Use standard 32-bit multiply instead of __umul24
+    // Modern GPUs (RDNA/CDNA) have native 32-bit ALUs; 24-bit ops require emulation
+    prod13l = (prod13l * select(...));
```

**Why**:
- CUDA's `__umul24()` is fast on older NVIDIA GPUs (limited precision hardware)
- AMD RDNA/CDNA have full 32-bit ALUs (no 24-bit shortcut)
- Standard `*` operator compiles to native instruction on AMD
- `__umul24()` emulation on AMD would be slower

**B. Kernel Export**
```diff
-__global__ void bhashmodUsePrecalc(...)
+extern "C" __global__ void bhashmodUsePrecalc(...)
```

**Why**: Runtime compilation visibility

**C. Comment Updates**
Removed outdated "CC 2.0+" (CUDA Compute Capability) references.

**Why**: Irrelevant for AMD GPUs

---

### 10. src/hipify/sieve_hip.cpp (MODIFIED, 9 changes)

**Purpose**: Sieve of Eratosthenes GPU implementation

#### Changes:

**A. Kernel Exports**
```diff
-__global__ void sieve(...)
+extern "C" __global__ void sieve(...)

-__global__ void s_sieve(...)
+extern "C" __global__ void s_sieve(...)
```

**B. Comment Cleanup**
Removed 3 instances of "Use regular multiply - faster on modern GPUs (CC 2.0+)"

**Why**:
- Comments referred to CUDA-specific optimization decisions
- Not applicable to AMD GPUs
- Code already uses standard multiplication

---

### 11. src/hipify/gprimes.h + gprimes.cpp (MASSIVE REFACTOR)

#### Before:
- `gprimes.h`: 3,076 lines of prime number array definitions

#### After:
- `gprimes.h`: 7 lines (declarations only)
- `gprimes.cpp`: 3,076 lines (NEW FILE with implementations)

**New gprimes.h contents:**
```cpp
#ifndef GPRIMES_H
#define GPRIMES_H

extern unsigned gPrimes[96*1024];
extern unsigned gPrimes2[96*1024*2];

#endif
```

**Why This Refactor?**

**A. Compilation Organization**
- Before: Every `.cpp` that included `gprimes.h` compiled 3,076 lines
- After: Only `gprimes.cpp` compiles the data

**B. Memory Optimization**
- Before: Each translation unit had copy of prime tables (linker removed duplicates)
- After: Single copy in `gprimes.o` object file
- Reduces intermediate object file size

**C. Standard Practice**
- Headers should have declarations only
- Implementations belong in `.cpp` files
- Matches C++ best practices

**Contents of Prime Tables:**
```cpp
unsigned gPrimes[96*1024] = {
  2, 3, 5, 7, 11, 13, 17, 19, 23, 29, ...
  // 98,304 primes (up to 1,257,787)
};

unsigned gPrimes2[96*1024*2] = {
  // Doubled array for sieve offsets
};
```

**Purpose**:
- Used for sieve of Eratosthenes algorithm
- Pre-computed for GPU kernel initialization
- Critical for primality testing performance

---

### 12. src/hipify/prime.cpp + prime.h (MODIFIED, 1 change each)

#### Changes:
```diff
-#include "cuda_runtime.h"
+// (removed include)
```

**Why**:
- `prime.cpp` contains CPU-only code (no GPU kernels)
- Including `cuda_runtime.h` was unnecessary
- Reduces compilation dependencies

**File Purpose:**
- Primecoin-specific prime number utilities
- Block header hashing
- Prime chain verification
- Used by both CPU and GPU code paths

---

### 13. src/hipify/benchmarks.cpp (DELETED, -959 lines)

**Why Deleted?**

This file was the old CUDA-style monolithic benchmark file. Replaced by:
1. `benchmarks_hip.cpp` (host code)
2. `benchmarks_kernels_hip.cpp` (device code)

The split improves:
- Code organization (separation of concerns)
- Build parallelization (two smaller files can compile in parallel)
- Runtime compilation (kernels separate from host logic)

---

## Summary of API Migrations

### Complete API Mapping Table

| Category | CUDA API | HIP API | Count |
|----------|----------|---------|-------|
| **Initialization** | `cuInit()` | `hipInit()` | 1 |
| **Device Management** | `cuDeviceGet()` | `hipDeviceGet()` | 1 |
| | `cuDeviceGetCount()` | `hipGetDeviceCount()` | 1 |
| | `cuDeviceGetName()` | `hipDeviceGetName()` | 1 |
| | `cuDeviceGetAttribute()` | `hipDeviceGetAttribute()` | 15+ |
| **Context Management** | `cuCtxCreate()` | `hipCtxCreate()` | 1 |
| | `cuCtxDestroy()` | `hipCtxDestroy()` | 1 |
| | `cuCtxSetCurrent()` | `hipCtxSetCurrent()` | 5+ |
| | `cuCtxSynchronize()` | `hipDeviceSynchronize()` | 20+ |
| **Memory Management** | `cuMemAlloc()` | `hipMalloc()` | 30+ |
| | `cuMemFree()` | `hipFree()` | 30+ |
| | `cuMemcpyHtoD()` | `hipMemcpyHtoD()` | 40+ |
| | `cuMemcpyDtoH()` | `hipMemcpyDtoH()` | 40+ |
| | `cuMemcpyHtoDAsync()` | `hipMemcpyHtoDAsync()` | 10+ |
| **Module/Kernel** | `cuModuleLoadData()` | `hipModuleLoadData()` | 1 |
| | `cuModuleGetFunction()` | `hipModuleGetFunction()` | 12 |
| | `cuModuleLaunchKernel()` | `hipModuleLaunchKernel()` | 15+ |
| **Runtime Compilation** | `nvrtcCreateProgram()` | `hiprtcCreateProgram()` | 1 |
| | `nvrtcCompileProgram()` | `hiprtcCompileProgram()` | 1 |
| | `nvrtcGetPTXSize()` | `hiprtcGetCodeSize()` | 1 |
| | `nvrtcGetPTX()` | `hiprtcGetCode()` | 1 |
| | `nvrtcDestroyProgram()` | `hiprtcDestroyProgram()` | 1 |
| **Stream Management** | `cuStreamCreate()` | `hipStreamCreate()` | 2 |
| | `cuStreamSynchronize()` | `hipStreamSynchronize()` | 10+ |
| **Error Handling** | `cuGetErrorName()` | `hipGetErrorName()` | 20+ |
| | `CUDA_SUCCESS` | `hipSuccess` | 50+ |
| **Device Functions** | `__mul24()` | Standard `*` | 3 |

**Total API call updates: 300+**

---

## Architecture-Specific Optimizations

### AMD GPU Optimization Strategies

#### 1. Atomic Operations
```cpp
// Compiler flag: -munsafe-fp-atomics
```
**Effect**: Enables hardware atomic operations on floating-point values
**Benefit**: Uses native AMD GPU atomic instructions instead of software emulation
**Trade-off**: Non-deterministic ordering (acceptable for mining)

#### 2. Fast Math
```cpp
// Compiler flag: -ffast-math
```
**Effect**: Aggressive floating-point optimizations
**Benefit**: Allows compiler to use faster floating-point instructions
**Trade-off**: Reduced precision (safe for 256+ bit integers)

#### 3. Native Integer Multiplication
```cpp
// Replace CUDA __mul24() with standard *
prod = a * b;  // Compiles to v_mul_u32 on GCN/RDNA
```
**Effect**: Direct hardware instruction usage
**Benefit**: Removes 24-bit emulation overhead on AMD hardware

#### 4. Restrict Pointers
```cpp
void kernel(const uint32_t * __restrict__ data)
```
**Effect**: Compiler assumes no pointer aliasing
**Benefit**: Enables memory coalescing optimizations

#### 5. Multi-Architecture Compilation
```cpp
--offload-arch=gfx906   // Vega 20 (MI50/60)
--offload-arch=gfx908   // CDNA 1 (MI100)
--offload-arch=gfx90a   // CDNA 2 (MI210/250)
--offload-arch=gfx1030  // RDNA 2 (RX 6800/6900)
```
**Effect**: Generates optimized code for each GPU generation
**Benefit**: Allows use of architecture-specific instructions and optimizations
