# Metal backend architecture and CUDA differences

The Metal miner implements the same Primecoin mining algorithm as the CUDA and
HIP backends, but it is not a line-for-line CUDA translation. This document
records the data contracts that must stay identical and the places where the
Metal execution and memory model require different code.

## Pipeline invariant

All three GPU backends run the same logical mining pipeline:

1. Double-SHA256 nonce batches from either the canonical `blocktree.get_work`
   JSON or a traditional 80-byte Primecoin block header.
2. Select hashes above `2^255`, choose a primorial multiplier, and validate the
   GPU result on the CPU.
3. Build Cunningham 1 and Cunningham 2 sieve offsets.
4. Sieve a multiplier range and compact 320-bit and 352-bit candidates.
5. Run staged Fermat tests until the configured GPU depth is reached.
6. Recheck completed candidates on the CPU and submit eligible chains.

The algorithm, candidate meaning, integer byte order, and benchmark counters
must match CUDA/HIP. Dispatch geometry, storage, synchronization, and some
kernel organization are Metal-specific.

## Host/shader data contracts

Metal has no C++ header shared directly with Metal Shading Language. Structures
are declared independently in `xpmclient_metal.h` and `shaders/common.metal`, so
field widths and offsets are an ABI.

### `config_t`

`config_t` is nine consecutive 32-bit unsigned values, in this order:

`N, SIZE, STRIPES, WIDTH, PCOUNT, TARGET, LIMIT13, LIMIT14, LIMIT15`

Most kernels currently receive the required fields individually with
`setBytes`, rather than receiving the complete structure. Keeping the mirror
layout still prevents the host and shader definitions from quietly diverging.

### `fermat_t`

`fermat_t` is a 12-byte array-of-structures record:

| Offset | Type | Field | Meaning |
| ---: | --- | --- | --- |
| 0 | `uint32_t` / `uint` | `index` | Multiplier inside the logical sieve range |
| 4 | `uint32_t` / `uint` | `hashid` | Slot in the host hash ring and GPU hash buffer |
| 8 | `uint8_t` / `uchar` | `origin` | First chain layer |
| 9 | `uint8_t` / `uchar` | `chainpos` | Fermat pipeline position |
| 10 | `uint8_t` / `uchar` | `type` | 0=Cunningham1, 1=Cunningham2, 2=BiTwin |
| 11 | `uint8_t` / `uchar` | `reserved` | Explicit padding |

Host-side `static_assert`s enforce this layout. Do not replace the byte fields
with Metal `bool`, an enum with an unspecified base type, or SIMD vector types.

### Integer representation

- SHA256 state words use SHA's big-endian byte order while hashing.
- A completed digest is converted to the miner's little-endian `uint256` limb
  order one 32-bit word at a time. Do not reverse both word order and bytes.
- `hashBuf` stores each multiplied hash as `N` little-endian 32-bit limbs at
  `hashid * N + limb`. It is zero-padded before `mpz_export`.
- Fermat inputs are transposed for coalesced access:
  `fprimes[limb * batch_size + candidate]`.
- `hash_t` contains `uint256` and `mpz_class` objects and is host-only. Only its
  flattened limbs and the small `fermat_t` identifier cross the GPU boundary.
- Metal keeps the JSON nonce offset as 64-bit host/shader data. The hash kernel
  returns a 32-bit index relative to that batch; the host adds the 64-bit batch
  offset exactly once.
- The getblocktemplate kernel uses a 32-bit header nonce. The host supplies the
  SHA-256 midstate after the first 64 header bytes plus the fixed merkle-tail,
  time, and bits words. The kernel constructs the last 16 header bytes and
  SHA-256 padding. Its result is also a batch-relative index.

### Main buffer layouts

| Data | Metal layout | Notes |
| --- | --- | --- |
| JSON midstate | 8 `uint32_t` words | State after complete 64-byte prefix blocks |
| JSON remainder | Up to 128 bytes | Prefix bytes not represented by the midstate |
| JSON results | 128 relative indices + 128 primorial bitfields + atomic count | The count may exceed storage; the host clamps to 128 |
| Block-header input | 8-word midstate + merkle-tail/time/bits words | The nonce is supplied per batch; the full header never crosses to each GPU thread |
| Prime table | `PCOUNT` `uint32_t` values | Starts after the selected primorial |
| Prime/reciprocal table | `PCOUNT` pairs `{prime, float_bits(1/prime)}` | Host stores the reciprocal bit pattern as `uint32_t`; shader uses `as_type<float>` |
| Modulo table | `(N - 1) * PCOUNT` words | Indexed as `limb * PCOUNT + prime_index` |
| Sieve offsets | `WIDTH * PCOUNT` words per chain side | Indexed as `line * PCOUNT + prime_index` |
| Sieve bits | `WIDTH * (STRIPES / 2) * SIZE` words per chain side | Indexed as `[line][stripe][word]` |
| Sieve candidates | `fermat_t[MSO]` for each size class and pipeline slot | Counts 0 and 1 select 320- and 352-bit queues |
| Fermat result | One byte per candidate | Compacted into continuation or final `fermat_t` buffers |

## Memory model

CUDA's `cudaBuffer` owns distinct host and device allocations and uses explicit
driver copies, often asynchronously on a stream. `MetalBuffer` currently owns:

- an optional C++ `new[]` host mirror; and
- an `MTLBuffer` using `MTLResourceStorageModeShared`.

On Apple silicon the CPU and GPU share physical memory, but the two pointers in
`MetalBuffer` are still different allocations. `copyToDevice()` and
`copyToHost()` are `memcpy` operations between the host mirror and
`MTLBuffer.contents`; they are not aliases. GPU-only buffers omit the host
mirror. Some hot or diagnostic paths intentionally access `.contents`
directly.

A completed Metal command buffer is the visibility boundary before the CPU
reads results or reuses shared scratch storage. CUDA stream/event ordering is
implemented with ordered encoders and command buffers. The current sieve path
also waits between jobs because all jobs reuse `mSieveBuf[0/1]`.

## Kernel arguments and compilation

CUDA launches kernels with a `void*` argument array and obtains functions from
an NVRTC module. Its generated `config.cu` makes geometry such as `SIZE` and
`PCOUNT` compile-time data.

Metal binds every resource to an explicit `[[buffer(n)]]` index. The matching
Objective-C++ call must use the same `atIndex:n`; changing either side alone is
an ABI break. Small scalar values are passed with `setBytes`, while arrays use
`MTLBuffer` objects.

Normal Metal builds compile all shaders into `default.metallib`. Runtime values
carry the selected `SIZE`, `STRIPES`, and `PCOUNT`, so a configuration change
does not require NVRTC-style recompilation. `METAL_SIEVE_SIZE=4096` remains the
fixed local-array capacity of the static sieve kernel. The optional
`XPM_METAL_SHADER_SOURCE_DIR` path is a developer override for runtime-compiling
the JSON and sieve shader group; it is not the production loading path.

The project invokes `xcrun metal` and `xcrun metallib` without forcing
`-sdk macosx`. New Xcode releases install the compiler as a separate Metal
toolchain, and forcing the SDK can select Xcode's legacy launcher instead.

## Threadgroups and the tiled sieve

CUDA's sieve maps one logical stripe/line group to a block whose shared array is
`SIZE` words. Apple GPUs expose a smaller threadgroup-memory ceiling, reported
at runtime by `maxThreadgroupMemoryLength`. A direct CUDA configuration with
`SIZE=12288` would require 48 KiB and cannot fit in the 32 KiB limit used by the
current Apple GPU path.

Metal preserves the CUDA-visible logical layout by tiling only the local work:

| Logical `SIZE` | Tiles | Words per tile | Threadgroup memory |
| ---: | ---: | ---: | ---: |
| 4096 | 1 | 4096 | 16 KiB, static kernel |
| 8192 | 1 | 8192 | 32 KiB, dynamic threadgroup memory |
| 12288 | 2 | 6144 | 24 KiB per dispatch group |

For a tiled dispatch, `gid / tileCount` selects the logical line/stripe and
`gid % tileCount` selects the tile. Each group writes to its tile's offset in
the original contiguous `[line][stripe][SIZE]` buffer. The search kernel sees
the complete logical sieve and therefore does not need a tiled variant.

Sieve range thresholds must use the local tile window (`tileWords * 32`), not
the full logical window. Host dispatch count and shader tile decoding must be
changed together if more sizes are added.

Metal uses `threadgroup` memory and `threadgroup_barrier` where CUDA uses
`__shared__` memory and `__syncthreads`. The default modern Apple path uses 1024
threads per threadgroup; capability checks select a smaller value for legacy
families. Never assume CUDA warp size when using Metal SIMD-group operations.

## Metal-specific code paths

- `jsonHashMod` and `blockHashMod` have different SHA-256 front ends but call
  one shared primorial filter. From CPU validation through sieve, Fermat, chain
  normalization, and statistics, both protocols use the same host pipeline.
- CUDA/HIP use an aggressively precomputed block-header SHA schedule. Metal's
  initial getblocktemplate implementation reconstructs the single remaining
  SHA block and runs the ordinary MSL schedule. This is simpler to validate on
  Apple GPUs and keeps optimization separate from consensus correctness.
- A template change clears hash, sieve-count, Fermat, final-candidate, and
  duplicate-submission state before the new midstate is dispatched. At nonce
  rollover the header time is advanced and its fixed SHA inputs are rebuilt.
- getblocktemplate accepts and submits Cunningham 1, Cunningham 2, and BiTwin
  chains. The BiTwin-only default remains specific to the pool getwork path.
- The sieve has a 4096-word static kernel and a dynamic-threadgroup-memory
  kernel for larger/tiled configurations.
- The modular inverse is implemented directly in MSL. Its coefficient order is
  covered by the benchmark's CPU/GPU offset regression check.
- 32-bit multiply-high uses a 64-bit product and shift because that maps well
  to Apple GPU code generation. The benchmark validates it with deterministic
  vectors before reporting throughput.
- `check_fermat_simd` is a Metal-specific candidate-compaction experiment that
  reserves output space once per SIMD group. Production currently uses the
  scalar-atomic `check_fermat`; `-b` checks equivalence and reports the A/B
  result before this optimization can be enabled safely.
- Metal creates separate 320- and 352-bit Fermat pipeline states. CUDA selects
  corresponding module functions but shares the same logical limb-major input
  contract.
- Command encoding replaces CUDA launch argument arrays. Pipeline creation also
  validates every required shader function when the miner starts.

## Correctness and performance checks

Use both benchmark modes; they answer different questions:

```sh
./xpmmetal -b
./xpmmetal --metal-sieve-words 8192 --metal-stripes 316 -P 16384 \
  --mining-benchmark 30
```

`-b` validates arithmetic, Fermat results, candidate compaction, modular
inverses, static/dynamic sieve equivalence, determinism, multiple sieve
geometries, and exact CPU/GPU block-header hashes across 4096 nonces.
`--mining-benchmark` runs the real deterministic getwork pipeline without
network or submission and reports hashes, effective sieve scan, candidates
entering Fermat, final candidates, and CPU validation mismatches.

Traditional node mining is selected explicitly so existing Metal getwork
commands remain compatible:

```sh
./xpmmetal --protocol getblocktemplate \
  --url 127.0.0.1:9912 --rpc-user USER --rpc-password PASS \
  --wallet PRIMECOIN_ADDRESS [--worker-id 0]
```

The RPC URL defaults to `127.0.0.1:9912` when `--url` is omitted. The wallet is
required; RPC credentials depend on the node configuration.

An isolated kernel throughput number is not a miner-performance result. Compare
backends using the end-to-end benchmark with the same deterministic work, while
also recording each backend's `SIZE`, `STRIPES`, `PCOUNT`, batch size, and hash
coefficient.

## Porting checklist

When moving a CUDA/HIP change into Metal:

1. Preserve scalar widths, byte order, limb order, and `fermat_t` offsets.
2. Decide whether data belongs in a host-only object, a host mirror, shared
   `MTLBuffer` storage, or threadgroup memory.
3. Translate every kernel parameter into a stable Metal buffer index.
4. Replace stream/event dependencies with explicit command-buffer ordering and
   wait before CPU reads or scratch-buffer reuse.
5. Recalculate threadgroup memory; tile the local work without changing the
   logical global layout when necessary.
6. Treat SIMD-group width as a Metal property, not as a CUDA warp constant.
7. Run `-b`, then the end-to-end mining benchmark. A fast result with a
   candidate-count or CPU-validation mismatch is a correctness failure.
