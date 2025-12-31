/*
 * xpmclient_metal.mm
 *
 * XPMiner Metal implementation
 * Ported from xpmclient_hip.cpp for Apple Silicon
 *
 * Objective-C++ implementation file
 */

#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "xpmclient_metal.h"
#include "gprimes.h"
#include "sha256.h"
#include "prime.h"
#include <getopt.h>
#include <chrono>
#include <set>

// Include these last to avoid macro conflicts
#include "system.h"
#undef MaxChainLength  // Avoid conflict with const in primecoin.h
#include "primecoin.h"

// Global configuration
unsigned gDebug = 0;
int gExtensionsNum = 9;
int gPrimorial = 19;
int gSieveSize = 10;
int gWeaveDepth = 8192;
int gThreadsNum = 1;
int gPrimeCount = 16384;

static const char* gWsUrl = nullptr;
std::vector<unsigned> gPrimes2;

// Test mode configuration
static const char* gTestDumpDir = nullptr;
static const char* gTestJsonFile = nullptr;
static uint64_t gTestNonce = 0;
static bool gTestMode = false;

//=============================================================================
// Test Mode Helper Functions (forward declarations and implementations)
//=============================================================================

// Dump buffer to binary file
void dumpBuffer(const char* filename, const void* data, size_t size) {
    if (!gTestMode || !gTestDumpDir) return;

    char path[512];
    snprintf(path, sizeof(path), "%s/round_0/%s", gTestDumpDir, filename);

    FILE* f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "Warning: Failed to create dump file: %s\n", path);
        return;
    }

    if (fwrite(data, 1, size, f) != size) {
        fprintf(stderr, "Warning: Failed to write dump file: %s\n", path);
    }

    fclose(f);
}

// Dump Metal buffer to binary file
void dumpMetalBuffer(const char* filename, id<MTLBuffer> buffer, size_t size) {
    if (!gTestMode || !buffer) return;
    dumpBuffer(filename, [buffer contents], size);
}

//=============================================================================
// Forward declarations
bool loadJsonWorkFromFile(const char* filename, JsonWork& work);

//=============================================================================
// JSON midstate preparation
struct JsonMidstateData {
    uint32_t midstate[8];
    char remainingPrefix[128];
    uint32_t remainingLen;
    uint32_t totalPrefixLen;
};

void prepareJsonMidstate(const JsonWork& work, JsonMidstateData* data) {
    // Build JSON prefix: {"parent_hash": "...", "height": N, "difficulty": N, "merkle": "...", "nonce":
    char prefix[256];
    int len = snprintf(prefix, sizeof(prefix),
        "{\"parent_hash\": \"%s\", \"height\": %llu, \"difficulty\": %llu, \"merkle\": \"%s\", \"nonce\": ",
        work.parentHash.c_str(),
        (unsigned long long)work.height,
        (unsigned long long)work.difficulty,
        work.merkle.c_str());

    data->totalPrefixLen = len;

    // Compute SHA256 midstate after first 128 bytes (2 blocks)
    if (len >= 128) {
        SHA_256 ctx;
        ctx.init();
        ctx.update((uint8_t*)prefix, 128);

        // Store midstate
        for (int i = 0; i < 8; i++) {
            data->midstate[i] = ctx.m_h[i];
        }

        // Store remaining bytes
        data->remainingLen = len - 128;
        memcpy(data->remainingPrefix, prefix + 128, data->remainingLen);
    } else {
        // If less than 128 bytes, use correct SHA256 initial state values
        data->midstate[0] = 0x6a09e667;
        data->midstate[1] = 0xbb67ae85;
        data->midstate[2] = 0x3c6ef372;
        data->midstate[3] = 0xa54ff53a;
        data->midstate[4] = 0x510e527f;
        data->midstate[5] = 0x9b05688c;
        data->midstate[6] = 0x1f83d9ab;
        data->midstate[7] = 0x5be0cd19;
        data->remainingLen = len;
        memcpy(data->remainingPrefix, prefix, len);
    }
}

//=============================================================================
// PrimeMiner Implementation
//=============================================================================

PrimeMiner::PrimeMiner(unsigned id, unsigned threads, unsigned sievePerRound,
                       unsigned depth, unsigned LSize) {
    mID = id;
    mThreads = threads;
    mSievePerRound = sievePerRound;
    mDepth = depth;
mLSize = LSize;
    MakeExit = false;

    // WORKAROUND: Initialize duplicate submission tracking (see header comments)
    mHasLastSubmitted = false;

    memset(&mConfig, 0, sizeof(mConfig));
    memset(&mineCtx, 0, sizeof(mineCtx));

    _device = nil;
    _commandQueue = nil;
    _library = nil;

    _jsonHashModPipeline = nil;
    _sieveSetupPipeline = nil;
    _sievePipeline = nil;
    _sieveSearchPipeline = nil;
    _fermatSetupPipeline = nil;
    _fermatKernel352Pipeline = nil;
    _fermatKernel320Pipeline = nil;
    _fermatCheckPipeline = nil;
}

PrimeMiner::~PrimeMiner() {
    // ARC will handle Metal object cleanup
}

void PrimeMiner::FermatInit(pipeline_t& fermat, unsigned mfs) {
    fermat.current = 0;
    fermat.bsize = 0;
    fermat.input.init(_device, mfs * mConfig.N);
    fermat.output.init(_device, mfs);

    for (int i = 0; i < 2; ++i) {
        fermat.buffer[i].info.init(_device, mfs);
        fermat.buffer[i].count.init(_device, 1);
    }
}

void PrimeMiner::FermatDispatch(pipeline_t& fermat,
                                MetalBuffer<fermat_t> sieveBuffers[SW][FERMAT_PIPELINES][2],
                                MetalBuffer<uint32_t> candidatesCountBuffers[SW][2],
                                unsigned pipelineIdx,
                                int ridx,
                                int widx,
                                uint64_t& testCount,
                                uint64_t& fermatCount,
                                id<MTLComputePipelineState> fermatKernel,
                                unsigned sievePerRound) {
    // Copy ridx count from device (written by previous check_fermat kernel)
    // ridx on this iteration was widx on the previous iteration
    uint32_t* ridxDevicePtr = (uint32_t*)fermat.buffer[ridx].count.buffer().contents;
    // FermatDispatch: Process candidates through Fermat pipeline
    fermat.buffer[ridx].count.copyToHost();
    uint32_t& count = fermat.buffer[ridx].count[0];

    // NEW: Log first few candidates in ridx to see what we're starting with
    if (count > 0) {
        fermat.buffer[ridx].info.copyToHost();
        uint32_t toLog = std::min(count, 5u);
        uint32_t chainpos3Input = 0;

//        LOG_F(INFO, "FermatDispatch: ridx buffer starting candidates (first %u):", toLog);
//        for (uint32_t i = 0; i < toLog; i++) {
//            fermat_t* info = &((fermat_t*)fermat.buffer[ridx].info._hostData)[i];
//            LOG_F(INFO, "  ridx[%u]: chainpos=%u type=%u index=%u origin=%u hashid=%u",
//                  i, info->chainpos, info->type, info->index, info->origin, info->hashid);
//        }

        // Count chainpos=3 in input and log their full details
        for (uint32_t i = 0; i < count && i < fermat.buffer[ridx].info._size; i++) {
            fermat_t* info = &((fermat_t*)fermat.buffer[ridx].info._hostData)[i];
            if (info->chainpos == 3) {
//                LOG_F(WARNING, "GPU %d: Found chainpos=3 candidate [%u]: type=%u index=%u origin=%u hashid=%u",
//                      mID, chainpos3Input, info->type, info->index, info->origin, info->hashid);

                // Calculate what the actual prime candidate should be
                // prime = hash * index * 2^layer ± 1
                // where layer = origin + chainpos (or origin + chainpos/2 for BiTwin)
                uint32_t layer = info->origin;
                if (info->type < 2) {
                    layer += info->chainpos;
                } else {  // BiTwin
                    layer += info->chainpos / 2;
                }
                int modifier = (info->type == 1 || (info->type == 2 && (info->chainpos & 1))) ? 1 : -1;

//                LOG_F(WARNING, "  -> This candidate should test: hash[%u] * %u * 2^%u %s 1",
//                      info->hashid, info->index, layer, (modifier > 0) ? "+" : "-");

                chainpos3Input++;
            }
        }
//        if (gDebug && chainpos3Input > 0) {
//            LOG_F(WARNING, "GPU %d: INPUT has %u candidates at chainpos=3 (will test if they reach chainpos=4 which is depth=%u)",
//                  mID, chainpos3Input, mDepth);
//        }
    }

    // Copy untested leftovers from previous iteration
    // The buffer that was ridx in previous iteration (and had original count) is now widx
    // Calculate: left = widx.count (original pre-test count) - bsize (number tested)
    fermat.buffer[widx].count.copyToHost();
    uint32_t widx_original_count = fermat.buffer[widx].count[0];
    uint32_t left = (widx_original_count > fermat.bsize) ? (widx_original_count - fermat.bsize) : 0;
    if (left > 0 && fermat.bsize > 0) {
        //LOG_F(INFO, "FermatDispatch: Copying %u untested leftovers from widx (original count=%u, tested=%u) at offset %u",
//              left, widx_original_count, fermat.bsize, fermat.bsize);
        id<MTLCommandBuffer> copyBuffer = [_commandQueue commandBuffer];
        id<MTLBlitCommandEncoder> blitEncoder = [copyBuffer blitCommandEncoder];
        [blitEncoder copyFromBuffer:fermat.buffer[widx].info.buffer()
                       sourceOffset:fermat.bsize * sizeof(fermat_t)
                           toBuffer:fermat.buffer[ridx].info.buffer()
                  destinationOffset:count * sizeof(fermat_t)
                               size:left * sizeof(fermat_t)];
        [blitEncoder endEncoding];
        [copyBuffer commit];
        [copyBuffer waitUntilCompleted];
        count += left;
    }

    fermat.bsize = 0;  // Reset bsize from previous iteration

    // Collect candidates from all sieves

    for (int i = 0; i < sievePerRound; ++i) {
        candidatesCountBuffers[i][ridx].copyToHost();
        uint32_t& avail = candidatesCountBuffers[i][ridx][pipelineIdx];

//        LOG_F(INFO, "FermatDispatch: Sieve %d has %u candidates available", i, avail);

        if (avail) {
            id<MTLCommandBuffer> copyBuffer = [_commandQueue commandBuffer];
            id<MTLBlitCommandEncoder> blitEncoder = [copyBuffer blitCommandEncoder];
            [blitEncoder copyFromBuffer:sieveBuffers[i][pipelineIdx][ridx].buffer()
                           sourceOffset:0
                               toBuffer:fermat.buffer[ridx].info.buffer()
                      destinationOffset:count * sizeof(fermat_t)
                                   size:avail * sizeof(fermat_t)];
            [blitEncoder endEncoding];
            [copyBuffer commit];
            count += avail;
            testCount += avail;
            fermatCount += avail;
            avail = 0;
        }
    }

    // Copy updated count back to device (we've been accumulating in host memory)
    fermat.buffer[ridx].count.copyToDevice();

    // Run Fermat tests if we have enough candidates
    if (count > mBlockSize) {
        // Reset widx count buffer on device for check_fermat kernel
        fermat.buffer[widx].count[0] = 0;
        fermat.buffer[widx].count.copyToDevice();

        fermat.bsize = count - (count % mBlockSize);

        // CRITICAL: Cap fermat.bsize to buffer capacity to prevent overflow
        unsigned max_fermat_size = fermat.buffer[ridx].info._size;
        if (fermat.bsize > max_fermat_size) {
            LOG_F(WARNING, "FermatDispatch: Capping fermat.bsize from %u to %u (buffer limit)",
                  fermat.bsize, max_fermat_size - (max_fermat_size % mBlockSize));
            fermat.bsize = max_fermat_size - (max_fermat_size % mBlockSize);  // Align down
        }

        id<MTLCommandBuffer> fermatCommandBuffer = [_commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [fermatCommandBuffer computeCommandEncoder];

        // Create debug buffer for setup_fermat (4 threads × 64 uints each)
        id<MTLBuffer> debugBuffer = [_device newBufferWithLength:4 * 64 * sizeof(uint32_t)
                                                         options:MTLResourceStorageModeShared];
        memset([debugBuffer contents], 0, 4 * 64 * sizeof(uint32_t));

        // 1. Setup Fermat test
        [encoder setComputePipelineState:_fermatSetupPipeline];
        [encoder setBuffer:fermat.input.buffer() offset:0 atIndex:0];
        [encoder setBuffer:fermat.buffer[ridx].info.buffer() offset:0 atIndex:1];
        [encoder setBuffer:hashBuf.buffer() offset:0 atIndex:2];
        [encoder setBytes:&mConfig.N length:sizeof(uint32_t) atIndex:3];
        [encoder setBuffer:debugBuffer offset:0 atIndex:4];  // Debug buffer

        MTLSize setupGrid = MTLSizeMake(fermat.bsize / 256, 1, 1);
        MTLSize setupThreadgroup = MTLSizeMake(256, 1, 1);
        [encoder dispatchThreadgroups:setupGrid threadsPerThreadgroup:setupThreadgroup];

        // NEW: Debug - copy fermat.input buffer to host to inspect prime candidates
        // This will show us the actual numbers being tested
        [encoder endEncoding];
        [fermatCommandBuffer commit];
        [fermatCommandBuffer waitUntilCompleted];
        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: setup_fermat completed, copying fprimes buffer to inspect");
        }

//        // DEBUG: Print setup_fermat intermediate values for first 4 candidates
//        uint32_t* debugData = (uint32_t*)[debugBuffer contents];
//        for (int tid = 0; tid < 4; tid++) {
//            uint32_t* dbg = &debugData[tid * 64];
//            LOG_F(INFO, "=== METAL setup_fermat DEBUG (tid=%d) ===", tid);
//            LOG_F(INFO, "Info: index=%u hashid=%u origin=%u chainpos=%u type=%u",
//                  dbg[0], dbg[1], dbg[2], dbg[3], dbg[4]);
//
//            char hex[512];
//            char* p;
//
//            // Hash input (h[])
//            p = hex;
//            for (int i = 10; i >= 0; i--) p += sprintf(p, "%08x ", dbg[5 + i]);
//            LOG_F(INFO, "Hash:           %s", hex);
//
//            // After multiply (m[])
//            p = hex;
//            for (int i = 10; i >= 0; i--) p += sprintf(p, "%08x ", dbg[16 + i]);
//            LOG_F(INFO, "After multiply: %s", hex);
//
//            // After shift (m[])
//            p = hex;
//            for (int i = 10; i >= 0; i--) p += sprintf(p, "%08x ", dbg[28 + i]);
//            LOG_F(INFO, "After shift(%u): %s", dbg[27], hex);
//
//            // Final result (m[])
//            p = hex;
//            for (int i = 10; i >= 0; i--) p += sprintf(p, "%08x ", dbg[40 + i]);
//            LOG_F(INFO, "Final (mod=%d):  %s", (int)dbg[39], hex);
//            LOG_F(INFO, "===============================");
//        }


        // Resume command buffer
        fermatCommandBuffer = [_commandQueue commandBuffer];
        encoder = [fermatCommandBuffer computeCommandEncoder];

        // 2. Run Fermat test kernel (320 or 352)
        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: Dispatching fermat kernel (grid=%u)", (fermat.bsize + 255) / 256);
        }
        [encoder setComputePipelineState:fermatKernel];
        [encoder setBuffer:fermat.output.buffer() offset:0 atIndex:0];
        [encoder setBuffer:fermat.input.buffer() offset:0 atIndex:1];

        MTLSize fermatGrid = MTLSizeMake((fermat.bsize + 255) / 256, 1, 1);
        MTLSize fermatThreadgroup = MTLSizeMake(256, 1, 1);
        [encoder dispatchThreadgroups:fermatGrid threadsPerThreadgroup:fermatThreadgroup];

        // NEW: Copy Fermat test results to check all chainpos levels (matching HIP debug)
        [encoder endEncoding];
        [fermatCommandBuffer commit];
        [fermatCommandBuffer waitUntilCompleted];
        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: Fermat kernel completed, copying results to inspect");
        }

        fermat.output.copyToHost();
        fermat.buffer[ridx].info.copyToHost();
        fermat.input.copyToHost();  // Need input data for debug logging

//        // DEBUG: Log first chainpos=3 test case for detailed analysis
//        if (fermat.bsize > 0) {
//            uint32_t* fprimes = (uint32_t*)fermat.input._hostData;
//            uint8_t* results = (uint8_t*)fermat.output._hostData;
//            fermat_t* infos = (fermat_t*)fermat.buffer[ridx].info._hostData;
//
//            // Find first chainpos=3 candidate
//            for (uint32_t i = 0; i < fermat.bsize; i++) {
//                if (infos[i].chainpos == 3) {
//                    // Extract prime for this test
//                    uint32_t e[11];
//                    for (int j = 0; j < 11; j++) {
//                        e[j] = fprimes[fermat.bsize * j + i];
//                    }
//
//                    fprintf(stderr, "\n=== METAL CHAINPOS=3 TEST (tid=%u) ===\n", i);
//                    fprintf(stderr, "Info: index=%u hashid=%u origin=%u chainpos=%u type=%u\n",
//                           infos[i].index, infos[i].hashid, infos[i].origin, infos[i].chainpos, infos[i].type);
//                    fprintf(stderr, "Input prime: %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x\n",
//                           e[10], e[9], e[8], e[7], e[6], e[5], e[4], e[3], e[2], e[1], e[0]);
//                    fprintf(stderr, "Result: %u\n", results[i]);
//                    fprintf(stderr, "=== END METAL CHAINPOS=3 TEST ===\n\n");
//                    break;  // Only log first one
//                }
//            }
//        }

        // Count pass/fail by chainpos (same as HIP debug)
        uint32_t chainpos_tested[10] = {0};
        uint32_t chainpos_passed[10] = {0};

        // SAFETY: Ensure we don't iterate beyond allocated buffer size
        uint32_t safe_bsize = std::min(fermat.bsize, (uint32_t)fermat.buffer[ridx].info._size);
        if (safe_bsize < fermat.bsize) {
            LOG_F(WARNING, "FermatDispatch: fermat.bsize (%u) exceeds buffer size (%zu), clamping to prevent crash",
                  fermat.bsize, fermat.buffer[ridx].info._size);
        }

        for (uint32_t i = 0; i < safe_bsize; i++) {
            fermat_t* info = &((fermat_t*)fermat.buffer[ridx].info._hostData)[i];
            uint8_t result = fermat.output[i];

            if (info->chainpos < 10) {
                chainpos_tested[info->chainpos]++;
                if (result == 1) {
                    chainpos_passed[info->chainpos]++;
                }
            }
        }

        if (gDebug) {
            fprintf(stderr, "\n=== METAL FERMAT DEBUG (pipelineIdx=%u, bits=%s) ===\n",
                    pipelineIdx, pipelineIdx == 0 ? "320" : "352");
            fprintf(stderr, "Input count: %u, Tested (bsize): %u\n",
                    count, fermat.bsize);
            fprintf(stderr, "Chainpos distribution:\n");
            for (int cp = 0; cp < 10; cp++) {
                if (chainpos_tested[cp] > 0) {
                    double pass_rate = (100.0 * chainpos_passed[cp]) / chainpos_tested[cp];
                    fprintf(stderr, "  chainpos=%d: tested=%u passed=%u (%.1f%%)\n",
                           cp, chainpos_tested[cp], chainpos_passed[cp], pass_rate);
                }
            }
            fprintf(stderr, "=======================================\n\n");
        }

        // Resume command buffer
        fermatCommandBuffer = [_commandQueue commandBuffer];
        encoder = [fermatCommandBuffer computeCommandEncoder];

        // 3. Check Fermat results
        [encoder setComputePipelineState:_fermatCheckPipeline];
        [encoder setBuffer:fermat.buffer[widx].info.buffer() offset:0 atIndex:0];
        [encoder setBuffer:fermat.buffer[widx].count.buffer() offset:0 atIndex:1];
        [encoder setBuffer:final.info.buffer() offset:0 atIndex:2];
        [encoder setBuffer:final.count.buffer() offset:0 atIndex:3];
        [encoder setBuffer:fermat.output.buffer() offset:0 atIndex:4];
        [encoder setBuffer:fermat.buffer[ridx].info.buffer() offset:0 atIndex:5];
        [encoder setBytes:&mDepth length:sizeof(uint32_t) atIndex:6];

        MTLSize checkGrid = MTLSizeMake(fermat.bsize / 256, 1, 1);
        MTLSize checkThreadgroup = MTLSizeMake(256, 1, 1);
        [encoder dispatchThreadgroups:checkGrid threadsPerThreadgroup:checkThreadgroup];

        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: Committing command buffer and waiting...");
        }
        [encoder endEncoding];
        [fermatCommandBuffer commit];
        [fermatCommandBuffer waitUntilCompleted];

        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: Command buffer completed, copying results back");
        }
        // Copy passing candidates count from widx buffer (written by check_fermat kernel)
        uint32_t* devicePtr = (uint32_t*)fermat.buffer[widx].count.buffer().contents;
        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: BEFORE copyToHost - device buffer widx count[0]=%u", devicePtr[0]);
        }
        fermat.buffer[widx].count.copyToHost();
        uint32_t passing = fermat.buffer[widx].count[0];

//        // Debug: Check chainpos of first few passing candidates
//        if (passing > 0) {
//            fermat.buffer[widx].info.copyToHost();
//            uint32_t toLog = std::min(passing, 5u);
//            LOG_F(INFO, "FermatDispatch: First %u passed candidates chainpos values:", toLog);
//            for (uint32_t i = 0; i < toLog; i++) {
//                fermat_t* info = &((fermat_t*)fermat.buffer[widx].info._hostData)[i];
//                LOG_F(INFO, "  Candidate %u: chainpos=%u type=%u", i, info->chainpos, info->type);
//            }
//        }

        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: AFTER copyToHost - %u candidates passed Fermat test", passing);
        }

        // NEW: Count candidates by chainpos in the output
        if (gDebug && passing > 0) {
            uint32_t chainposCount[10] = {0};
            uint32_t chainpos3Count = 0;
            for (uint32_t i = 0; i < passing && i < fermat.buffer[widx].info._size; i++) {
                fermat_t* info = &((fermat_t*)fermat.buffer[widx].info._hostData)[i];
                if (info->chainpos < 10) {
                    chainposCount[info->chainpos]++;
                    if (info->chainpos == 3) chainpos3Count++;
                }
            }
            LOG_F(INFO, "FermatDispatch: Output chainpos distribution:");
            for (int cp = 0; cp < 10; cp++) {
                if (chainposCount[cp] > 0) {
                    LOG_F(INFO, "  chainpos=%d: %u candidates", cp, chainposCount[cp]);
                }
            }
//            if (chainpos3Count > 0) {
//                LOG_F(WARNING, "GPU %d: Found %u candidates at chainpos=3, but depth=%u means they need ONE MORE PASS to reach final buffer",
//                      mID, chainpos3Count, mDepth);
//            }
        }

        // NOTE: Do NOT update buffer[ridx].count here!
        // It must retain the original pre-test count so that on next iteration
        // when ridx becomes widx, we can calculate leftovers = widx.count - bsize
        uint32_t leftover = count - fermat.bsize;
        if (gDebug) {
            LOG_F(INFO, "FermatDispatch: Tested %u candidates, %u passed, %u leftovers remain in ridx buffer",
                  fermat.bsize, passing, leftover);
        }
    } else {
        // Not enough candidates - reset bsize but keep count for next iteration
        fermat.bsize = 0;
    }
}

bool PrimeMiner::Initialize(id<MTLDevice> device) {
    @autoreleasepool {
        _device = device;

        LOG_F(INFO, "Initializing Metal GPU %d: %s", mID, [device.name UTF8String]);

        // Check GPU capabilities
        // According to Metal spec: Only Apple2 and Apple3 are limited to 512 threads/threadgroup
        // Apple4+ (including M1/M2/M3/M4) all support 1024 threads/threadgroup
        NSUInteger maxThreadsPerThreadgroup = 1024;
        bool supportsLSize1024 = true;

        #if TARGET_OS_MAC
        if (@available(macOS 11.0, *)) {
            // Check if GPU is limited to 512 (only Apple2/Apple3)
            if ([device supportsFamily:MTLGPUFamilyApple4] ||
                [device supportsFamily:MTLGPUFamilyApple5] ||
                [device supportsFamily:MTLGPUFamilyApple6] ||
                [device supportsFamily:MTLGPUFamilyApple7] ||
                [device supportsFamily:MTLGPUFamilyApple8] ||
                [device supportsFamily:MTLGPUFamilyApple9]) {
                // Apple4+ (M1/M2/M3/M4 and newer) - supports 1024
                supportsLSize1024 = true;
                maxThreadsPerThreadgroup = 1024;
                LOG_F(INFO, "GPU Family: Apple4+ (M1/M2/M3/M4) - supports LSIZE=1024");
            } else {
                // Apple2/Apple3 or older - limited to 512
                supportsLSize1024 = false;
                maxThreadsPerThreadgroup = 512;
                LOG_F(INFO, "GPU Family: Apple2/Apple3 (Legacy) - limited to LSIZE=512");
            }
        } else {
            // macOS < 11.0 - likely older GPU, use conservative default
            supportsLSize1024 = false;
            maxThreadsPerThreadgroup = 512;
            LOG_F(INFO, "macOS < 11.0 - using conservative LSIZE=512");
        }
        #else
        supportsLSize1024 = true;
        maxThreadsPerThreadgroup = 1024;
        #endif

        LOG_F(INFO, "Max threads per threadgroup: %lu", (unsigned long)maxThreadsPerThreadgroup);

        // Create command queue
        _commandQueue = [device newCommandQueue];
        if (!_commandQueue) {
            LOG_F(ERROR, "Failed to create command queue");
            return false;
        }

        // Load shader library
        NSError* error = nil;

        // Try to load precompiled metallib
        NSString* execPath = [[NSProcessInfo processInfo] arguments][0];
        NSString* execDir = [execPath stringByDeletingLastPathComponent];
        NSString* metallibPath = [execDir stringByAppendingPathComponent:@"default.metallib"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:metallibPath]) {
            LOG_F(INFO, "Loading Metal library from: %s", [metallibPath UTF8String]);
            _library = loadMetalLibrary(metallibPath, device, &error);
        } else {
            LOG_F(ERROR, "Metal library not found at: %s", [metallibPath UTF8String]);
            return false;
        }

        if (!_library) {
            LOG_F(ERROR, "Failed to load Metal library");
            return false;
        }

        // Create compute pipeline states
        auto createPipeline = [&](NSString* name) -> id<MTLComputePipelineState> {
            id<MTLFunction> function = [_library newFunctionWithName:name];
            if (!function) {
                LOG_F(ERROR, "Failed to find function: %s", [name UTF8String]);
                return nil;
            }

            NSError* err = nil;
            id<MTLComputePipelineState> pipeline =
                [device newComputePipelineStateWithFunction:function error:&err];

            if (!pipeline) {
                LOG_F(ERROR, "Failed to create pipeline for %s: %s",
                      [name UTF8String], [[err localizedDescription] UTF8String]);
            }

            return pipeline;
        };

        _jsonHashModPipeline = createPipeline(@"jsonHashMod");
        _sieveSetupPipeline = createPipeline(@"setup_sieve");
        _sievePipeline = createPipeline(@"sieve");
        _sieveSearchPipeline = createPipeline(@"s_sieve");
        _fermatSetupPipeline = createPipeline(@"setup_fermat");
        _fermatKernel320Pipeline = createPipeline(@"fermat_kernel320");
        _fermatKernel352Pipeline = createPipeline(@"fermat_kernel352");
        _fermatCheckPipeline = createPipeline(@"check_fermat");

        // Log threadgroup memory usage for sieve kernel
        LOG_F(INFO, "Sieve kernel threadgroup memory: %lu bytes (SIZE=%u → %u bytes)",
              (unsigned long)[_sievePipeline threadExecutionWidth],
              mConfig.SIZE, mConfig.SIZE * sizeof(uint32_t));
        LOG_F(INFO, "Sieve kernel max total threads per threadgroup: %lu",
              (unsigned long)[_sievePipeline maxTotalThreadsPerThreadgroup]);
        if (@available(macOS 11.0, *)) {
            LOG_F(INFO, "Sieve kernel static threadgroup memory: %lu bytes",
                  (unsigned long)[_sievePipeline staticThreadgroupMemoryLength]);
        }

        if (!_jsonHashModPipeline || !_sieveSetupPipeline || !_sievePipeline ||
            !_sieveSearchPipeline || !_fermatSetupPipeline ||
            !_fermatKernel320Pipeline || !_fermatKernel352Pipeline ||
            !_fermatCheckPipeline) {
            LOG_F(ERROR, "Failed to create all required pipeline states");
            return false;
        }

        // Benchmark pipelines (optional - only used in benchmark mode)
        _multiplyBenchmark320Pipeline = createPipeline(@"multiplyBenchmark320");
        _multiplyBenchmark352Pipeline = createPipeline(@"multiplyBenchmark352");
        _squareBenchmark320Pipeline = createPipeline(@"squareBenchmark320");
        _squareBenchmark352Pipeline = createPipeline(@"squareBenchmark352");

        // Set config based on GPU capabilities
        // Match HIP/CUDA configurations for optimal performance
		mConfig.N = 12;
        mConfig.SIZE = 4096;    // Single-pass sieve - fits in 16KB threadgroup memory
        mConfig.STRIPES = 210;  // NICE
        mConfig.WIDTH = 20;     // Matches HIP/CUDA

        if (supportsLSize1024) {
            // Apple4+ (M1/M2/M3/M4): Use 1024 threads per threadgroup
            mLSize = 1024;
            LOG_F(INFO, "GPU Family: Apple4+ - using LSIZE=1024");
        } else {
            // Apple2/3 (Legacy): Limited to 512 threads per threadgroup
            mLSize = 512;
            LOG_F(INFO, "GPU Family: Apple2/3 - using LSIZE=512");
        }

        // PCOUNT is configurable via --prime-count parameter
        mConfig.PCOUNT = gPrimeCount;
        unsigned checksPerThread = mConfig.PCOUNT / mLSize;
        LOG_F(INFO, "Configuration: PCOUNT=%u, LSIZE=%u → %u prime checks per thread",
              mConfig.PCOUNT, mLSize, checksPerThread);

        mConfig.TARGET = 10;
        mConfig.LIMIT13 = 25;
        mConfig.LIMIT14 = 28;
        mConfig.LIMIT15 = 31;

        // Set block size based on GPU capabilities
        // For Apple Silicon, use a reasonable default
        mBlockSize = 256 * 4 * 64;  // Similar to HIP: CUs * 4 * 64
        LOG_F(INFO, "GPU %d: Block size = %u", mID, mBlockSize);

        LOG_F(INFO, "Metal GPU %d initialized successfully", mID);
        return true;
    }
}

// Benchmark helper functions
static uint32_t rand32() {
    uint32_t result = rand();
    result = (result << 16) | rand();
    return result;
}

// Benchmark: Multiply performance
void metalMultiplyBenchmark(id<MTLDevice> device,
                             id<MTLCommandQueue> commandQueue,
                             id<MTLComputePipelineState> pipeline,
                             unsigned mulOperandSize,
                             uint32_t elementsNum,
                             bool isSquaring) {
    @autoreleasepool {
        srand(12345);  // Consistent seed

        const uint32_t MulOpsNum = 512;  // Match HIP (kernels now use 512 instead of 16384)
        const uint32_t GroupSize = 256;  // Match HIP group size
        const uint32_t cpuElementsNum = 1024;  // Reduce CPU work to 1/64th
        unsigned gmpOpSize = mulOperandSize + (mulOperandSize % 2);
        unsigned limbsNum = elementsNum * gmpOpSize;

        // Allocate host and device buffers
        std::vector<uint32_t> m1Data(limbsNum, 0);
        std::vector<uint32_t> m2Data(limbsNum, 0);
        std::vector<uint32_t> cpuResult(cpuElementsNum * mulOperandSize * 2, 0);

        // Initialize with random data
        for (unsigned i = 0; i < elementsNum; i++) {
            for (unsigned j = 0; j < mulOperandSize; j++) {
                m1Data[i * gmpOpSize + j] = rand32();
                m2Data[i * gmpOpSize + j] = rand32();
            }
        }

        // Create Metal buffers
        id<MTLBuffer> m1Buf = [device newBufferWithBytes:m1Data.data()
                                                  length:limbsNum * sizeof(uint32_t)
                                                 options:MTLResourceStorageModeShared];
        id<MTLBuffer> m2Buf = [device newBufferWithBytes:m2Data.data()
                                                  length:limbsNum * sizeof(uint32_t)
                                                 options:MTLResourceStorageModeShared];
        id<MTLBuffer> resultBuf = [device newBufferWithLength:limbsNum * 2 * sizeof(uint32_t)
                                                       options:MTLResourceStorageModeShared];

        // GPU benchmark
        auto gpuStart = std::chrono::steady_clock::now();

        id<MTLCommandBuffer> cmdBuffer = [commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [cmdBuffer computeCommandEncoder];
        [encoder setComputePipelineState:pipeline];

        if (isSquaring) {
            [encoder setBuffer:m1Buf offset:0 atIndex:0];
            [encoder setBuffer:resultBuf offset:0 atIndex:1];
            [encoder setBytes:&elementsNum length:sizeof(uint32_t) atIndex:2];
        } else {
            [encoder setBuffer:m1Buf offset:0 atIndex:0];
            [encoder setBuffer:m2Buf offset:0 atIndex:1];
            [encoder setBuffer:resultBuf offset:0 atIndex:2];
            [encoder setBytes:&elementsNum length:sizeof(uint32_t) atIndex:3];
        }

        // Fix: Use dispatchThreadgroups with proper GroupSize instead of dispatchThreads
        MTLSize gridSize = MTLSizeMake(elementsNum / GroupSize, 1, 1);
        MTLSize threadgroupSize = MTLSizeMake(GroupSize, 1, 1);
        [encoder dispatchThreadgroups:gridSize threadsPerThreadgroup:threadgroupSize];
        [encoder endEncoding];
        [cmdBuffer commit];
        [cmdBuffer waitUntilCompleted];

        auto gpuEnd = std::chrono::steady_clock::now();

        // CPU benchmark using GMP (only test subset of elements)
        auto cpuStart = std::chrono::steady_clock::now();

        for (unsigned i = 0; i < cpuElementsNum; i++) {
            mpz_class cpuM1, cpuM2;
            mpz_import(cpuM1.get_mpz_t(), mulOperandSize, -1, 4, 0, 0, &m1Data[i * gmpOpSize]);
            mpz_import(cpuM2.get_mpz_t(), mulOperandSize, -1, 4, 0, 0, &m2Data[i * gmpOpSize]);

            unsigned gmpLimbsNum = cpuM1.get_mpz_t()->_mp_size;
            mp_limb_t *Operand1 = cpuM1.get_mpz_t()->_mp_d;
            mp_limb_t *Operand2 = cpuM2.get_mpz_t()->_mp_d;
            uint32_t *target = &cpuResult[i * mulOperandSize * 2];

            for (unsigned j = 0; j < MulOpsNum; j++) {
                if (isSquaring) {
                    mpn_sqr((mp_limb_t*)target, Operand1, gmpLimbsNum);
                } else {
                    mpn_mul_n((mp_limb_t*)target, Operand1, Operand2, gmpLimbsNum);
                }
                memcpy(Operand1, target + mulOperandSize, mulOperandSize * sizeof(uint32_t));
            }
        }

        auto cpuEnd = std::chrono::steady_clock::now();

        // Calculate performance metrics
        double gpuTime = std::chrono::duration_cast<std::chrono::microseconds>(gpuEnd - gpuStart).count() / 1000.0;
        double cpuTime = std::chrono::duration_cast<std::chrono::microseconds>(cpuEnd - cpuStart).count() / 1000.0;

        double gpuTotalOps = (double)elementsNum * MulOpsNum;
        double cpuTotalOps = (double)cpuElementsNum * MulOpsNum;
        double gpuMopsPerSec = (gpuTotalOps / 1000000.0) / (gpuTime / 1000.0);
        double cpuMopsPerSec = (cpuTotalOps / 1000000.0) / (cpuTime / 1000.0);

        // Speedup should be based on throughput, not time (since CPU and GPU process different amounts)
        double speedup = gpuMopsPerSec / cpuMopsPerSec;

        LOG_F(INFO, "%s %u bits: GPU %.0lf Mops/s, CPU %.0lf Mops/s (%.2lfx faster)",
              (isSquaring ? "Square" : "Multiply"), mulOperandSize * 32, gpuMopsPerSec, cpuMopsPerSec, speedup);
    }
}

// Benchmark: Fermat test performance
void metalFermatTestBenchmark(id<MTLDevice> device,
                               id<MTLCommandQueue> commandQueue,
                               id<MTLComputePipelineState> fermat320,
                               id<MTLComputePipelineState> fermat352,
                               unsigned elementsNum) {
    @autoreleasepool {
        srand(12345);  // Use same seed as HIP for consistency

        // Test both 320-bit and 352-bit
        for (int bits : {320, 352}) {
            unsigned operandSize = bits / 32;
            id<MTLComputePipelineState> kernel = (bits == 320) ? fermat320 : fermat352;

            // Create buffers
            id<MTLBuffer> numbers = [device newBufferWithLength:elementsNum * operandSize * sizeof(uint32_t)
                                                        options:MTLResourceStorageModeShared];
            id<MTLBuffer> gpuResults = [device newBufferWithLength:elementsNum * sizeof(uint8_t)
                                                        options:MTLResourceStorageModeShared];

            // Generate random test primes
            uint32_t* numbersData = (uint32_t*)[numbers contents];
            for (unsigned i = 0; i < elementsNum; i++) {
                for (unsigned j = 0; j < operandSize; j++) {
                    numbersData[i * operandSize + j] = (j == operandSize - 1) ?
                                                         (1 << (i % 32)) : (uint32_t)rand();
                }
                numbersData[i * operandSize] |= 0x1;  // Make odd
            }

            // === GPU BENCHMARK ===
            auto gpuStart = std::chrono::steady_clock::now();

            id<MTLCommandBuffer> cmdBuffer = [commandQueue commandBuffer];
            id<MTLComputeCommandEncoder> encoder = [cmdBuffer computeCommandEncoder];
            [encoder setComputePipelineState:kernel];
            [encoder setBuffer:gpuResults offset:0 atIndex:0];
            [encoder setBuffer:numbers offset:0 atIndex:1];

            MTLSize grid = MTLSizeMake((elementsNum + 255) / 256, 1, 1);
            MTLSize threadgroup = MTLSizeMake(256, 1, 1);
            [encoder dispatchThreadgroups:grid threadsPerThreadgroup:threadgroup];
            [encoder endEncoding];
            [cmdBuffer commit];
            [cmdBuffer waitUntilCompleted];

            auto gpuEnd = std::chrono::steady_clock::now();

            // === CPU BENCHMARK (using GMP) ===
            auto cpuStart = std::chrono::steady_clock::now();

            std::unique_ptr<uint32_t[]> cpuResults(new uint32_t[elementsNum]);
            for (unsigned i = 0; i < elementsNum; i++) {
                mpz_class number;
                mpz_import(number.get_mpz_t(), operandSize, -1, 4, 0, 0, &numbersData[i * operandSize]);

                // Fermat test: a^(n-1) mod n == 1 (using base 2)
                mpz_class base = 2;
                mpz_class exponent = number - 1;
                mpz_class result;
                mpz_powm(result.get_mpz_t(), base.get_mpz_t(), exponent.get_mpz_t(), number.get_mpz_t());

                cpuResults[i] = (result == 1) ? 1 : 0;
            }

            auto cpuEnd = std::chrono::steady_clock::now();

            // === CALCULATE METRICS ===
            double gpuTime = std::chrono::duration_cast<std::chrono::microseconds>(gpuEnd - gpuStart).count() / 1000.0;
            double cpuTime = std::chrono::duration_cast<std::chrono::microseconds>(cpuEnd - cpuStart).count() / 1000.0;
            double gpuMopsPerSec = ((double)elementsNum / 1000000.0) / (gpuTime / 1000.0);
            double cpuMopsPerSec = ((double)elementsNum / 1000000.0) / (cpuTime / 1000.0);
            double speedup = cpuTime / gpuTime;

            LOG_F(INFO, "Fermat tests %d bits: GPU %.2lf Mops/s, CPU %.2lf Mops/s (%.2lfx faster)",
                  bits, gpuMopsPerSec, cpuMopsPerSec, speedup);
        }
    }
}

// Hashmod benchmark - DISABLED (will be added with getblocktemplate support)
void metalHashmodBenchmark(PrimeMiner* miner) {
    @autoreleasepool {
        // Skipped - will be implemented when getblocktemplate support is added
    }
}

// CPU trial division test for prime chains (from HIP benchmarks_hip.cpp)
bool trialDivisionChainTest(uint32_t *primes,
                            mpz_class &N,
                            bool fSophieGermain,
                            unsigned chainLength,
                            unsigned depth,
                            bool print)
{
    N += (fSophieGermain ? -1 : 1);
    for (unsigned i = 0; i < chainLength; i++) {
        for (unsigned divIdx = 0; divIdx < depth; divIdx += 16) {
            if (mpz_tdiv_ui(N.get_mpz_t(), primes[divIdx]) == 0) {
                if (print)
                    LOG_F(ERROR, "Invalid number found; chain position is %u, divisor is %u type is %u",
                          i+1, primes[divIdx], fSophieGermain ? 1 : 2);
                return false;
            }
        }

        N <<= 1;
        N += (fSophieGermain ? 1 : -1);
    }

    return true;
}

// CPU sieve validation - parses sieve bitmap and validates all candidates
bool sieveResultsTest(uint32_t *primes,
                      mpz_class &fixedMultiplier,
                      const uint8_t *cunningham1,
                      const uint8_t *cunningham2,
                      unsigned sieveSize,
                      unsigned chainLength,
                      unsigned depth,
                      unsigned extensionsNum,
                      std::set<mpz_class> &candidates,
                      unsigned *invalidCount)
{
    const uint32_t layersNum = chainLength + extensionsNum;
    const uint32_t *c1ptr = (const uint32_t*)cunningham1;
    const uint32_t *c2ptr = (const uint32_t*)cunningham2;
    unsigned sieveWords = sieveSize/32;

    for (unsigned wordIdx = 0; wordIdx < sieveWords; wordIdx++) {
        uint32_t c1Data[layersNum];
        uint32_t c2Data[layersNum];

        for (unsigned i = 0; i < layersNum; i++)
            c1Data[i] = c1ptr[wordIdx + sieveWords*i];

        // Check Cunningham1 chains
        for (unsigned firstLayer = 0; firstLayer <= layersNum-chainLength; firstLayer++) {
            uint32_t mask = 0;
            for (unsigned layer = 0; layer < chainLength; layer++)
                mask |= c1Data[firstLayer + layer];

            if (mask != 0xFFFFFFFF) {
                for (unsigned bit = 0; bit < 32; bit++) {
                    if ((~mask & (1 << bit))) {
                        mpz_class candidateMultiplier = (mpz_class)(sieveSize + wordIdx*32 + bit) << firstLayer;
                        mpz_class chainOrigin = fixedMultiplier*candidateMultiplier;
                        if (!trialDivisionChainTest(primes, chainOrigin, true, chainLength, depth, *invalidCount < 20)) {
                            ++*invalidCount;
                        }
                        candidates.insert(candidateMultiplier);
                    }
                }
            }
        }

        for (unsigned i = 0; i < layersNum; i++)
            c2Data[i] = c2ptr[wordIdx + sieveWords*i];

        // Check Cunningham2 chains
        for (unsigned firstLayer = 0; firstLayer <= layersNum-chainLength; firstLayer++) {
            uint32_t mask = 0;
            for (unsigned layer = 0; layer < chainLength; layer++)
                mask |= c2Data[firstLayer + layer];

            if (mask != 0xFFFFFFFF) {
                for (unsigned bit = 0; bit < 32; bit++) {
                    if ((~mask & (1 << bit))) {
                        mpz_class candidateMultiplier = (mpz_class)(sieveSize + wordIdx*32 + bit) << firstLayer;
                        mpz_class chainOrigin = fixedMultiplier*candidateMultiplier;
                        if (!trialDivisionChainTest(primes, chainOrigin, false, chainLength, depth, *invalidCount < 20)) {
                            ++*invalidCount;
                        }
                        candidates.insert(candidateMultiplier);
                    }
                }
            }
        }

        // Check BiTwin chains
        unsigned bitwinLayers = chainLength / 2 + chainLength % 2;
        for (unsigned firstLayer = 0; firstLayer <= layersNum-bitwinLayers; firstLayer++) {
            uint32_t mask = 0;
            for (unsigned layer = 0; layer < chainLength/2; layer++)
                mask |= c1Data[firstLayer + layer] | c2Data[firstLayer + layer];
            if (chainLength & 0x1)
                mask |= c1Data[firstLayer + chainLength/2];

            if (mask != 0xFFFFFFFF) {
                for (unsigned bit = 0; bit < 32; bit++) {
                    if ((~mask & (1 << bit))) {
                        mpz_class candidateMultiplier = (mpz_class)(sieveSize + wordIdx*32 + bit) << firstLayer;
                        mpz_class chainOrigin = fixedMultiplier*candidateMultiplier;
                        mpz_class chainOriginExtra = chainOrigin;
                        if (!trialDivisionChainTest(primes, chainOrigin, true, (chainLength+1)/2, depth, *invalidCount < 20) ||
                            !trialDivisionChainTest(primes, chainOriginExtra, false, chainLength/2, depth, *invalidCount < 20)) {
                            ++*invalidCount;
                        }
                        candidates.insert(candidateMultiplier);
                    }
                }
            }
        }
    }

    return true;
}

// Sieve check benchmark - validates GPU sieve correctness vs CPU
void metalSieveCheckBenchmark(PrimeMiner* miner) {
    @autoreleasepool {
        // Not implemented - requires complete work generation pipeline
    }
}

// Sieve performance benchmark (measures throughput)
void metalSievePerfBenchmark(PrimeMiner* miner) {
    @autoreleasepool {
        // Not implemented - requires complete buffer initialization
    }
}

// Comprehensive benchmark suite
void runMetalBenchmarks(id<MTLDevice> device, PrimeMiner* miner) {
    @autoreleasepool {
        config_t cfg = miner->getConfig();

        LOG_F(INFO, "Benchmarking %s", [device.name UTF8String]);
        LOG_F(INFO, "Configuration: SIZE=%u, STRIPES=%u, WIDTH=%u, PCOUNT=%u, LSIZE=%u",
              cfg.SIZE, cfg.STRIPES, cfg.WIDTH, cfg.PCOUNT, miner->mLSize);

        // Get command queue and pipelines from miner
        id<MTLCommandQueue> commandQueue = miner->_commandQueue;

        // 1. Multiply benchmarks (match HIP order)
        const uint32_t elementsNum = 65536;  // Match HIP
        LOG_F(INFO, " *** multiply benchmarks ***");
        metalMultiplyBenchmark(device, commandQueue, miner->_multiplyBenchmark320Pipeline,
                              320 / 32, elementsNum, false);
        metalMultiplyBenchmark(device, commandQueue, miner->_multiplyBenchmark352Pipeline,
                              352 / 32, elementsNum, false);

        // 2. Square benchmarks
        LOG_F(INFO, " *** square benchmarks ***");
        metalMultiplyBenchmark(device, commandQueue, miner->_squareBenchmark320Pipeline,
                              320 / 32, elementsNum, true);
        metalMultiplyBenchmark(device, commandQueue, miner->_squareBenchmark352Pipeline,
                              352 / 32, elementsNum, true);

        // 3. Fermat test benchmarks
        metalFermatTestBenchmark(device, commandQueue,
                                miner->_fermatKernel320Pipeline,
                                miner->_fermatKernel352Pipeline,
                                262144);  // Same as HIP

        // 4. Hashmod benchmark
        metalHashmodBenchmark(miner);

        // 5. Sieve correctness check
        metalSieveCheckBenchmark(miner);

        // 6. Sieve performance benchmark
        metalSievePerfBenchmark(miner);

        LOG_F(INFO, "Benchmarks complete.");
    }
}

void PrimeMiner::MiningGetWork(GetWorkContext* ctx) {
    @autoreleasepool {
        JsonWork currentWork;
        bool hasChanged;

        memset(&mineCtx, 0, sizeof(MineContext));
        mineCtx.threadIdx = mID;

        // Initialize buffers
        LOG_F(INFO, "GPU %d: Initializing buffers", mID);

        mJsonMidstateBuf.init(_device, 8);
        mJsonRemainingPrefixBuf.init(_device, 128);
        mJsonFoundBuf.init(_device, 128);
        mJsonPrimorialBuf.init(_device, 128);
        mJsonCountBuf.init(_device, 1);
        hashBuf.init(_device, PW * mConfig.N);

        // Initialize sieve and fermat buffers
        for (int sieveIdx = 0; sieveIdx < SW; ++sieveIdx) {
            for (int instIdx = 0; instIdx < 2; ++instIdx) {
                for (int pipelineIdx = 0; pipelineIdx < FERMAT_PIPELINES; pipelineIdx++)
                    mSieveBuffers[sieveIdx][pipelineIdx][instIdx].init(_device, MSO);

                mCandidatesCountBuffers[sieveIdx][instIdx].init(_device, FERMAT_PIPELINES);
            }
        }

        for (int k = 0; k < 2; ++k) {
            mSieveBuf[k].init(_device, mConfig.SIZE * mConfig.STRIPES / 2 * mConfig.WIDTH);
            mSieveOff[k].init(_device, mConfig.PCOUNT * mConfig.WIDTH);
        }

        final.info.init(_device, MFS / (4 * mDepth));
        final.count.init(_device, 1);

        FermatInit(mFermat320, MFS);
        FermatInit(mFermat352, MFS);

        // Primorial configuration - used for both prime buffers and hash validation
        const unsigned mPrimorial = 13;  // Fixed primorial index for buffer allocation

        // Initialize prime buffers and modulos buffers
        for (unsigned i = 0; i < maxHashPrimorial - mPrimorial; i++) {
            mPrimeBuf[i].init(_device, mConfig.PCOUNT);
            // Copy primes to device
            for (unsigned j = 0; j < mConfig.PCOUNT; j++) {
                mPrimeBuf[i][j] = gPrimes[mPrimorial + i + 1 + j];
            }
            mPrimeBuf[i].copyToDevice();

            mPrimeBuf2[i].init(_device, mConfig.PCOUNT * 2);
            // Copy doubled primes to device
            for (unsigned j = 0; j < mConfig.PCOUNT * 2; j++) {
                mPrimeBuf2[i][j] = gPrimes2[2 * (mPrimorial + i) + 2 + j];
            }
            mPrimeBuf2[i].copyToDevice();

            // Initialize modulos buffer
            unsigned modulosBufferSize = mConfig.PCOUNT * (mConfig.N - 1);
            mModulosBuf[i].init(_device, modulosBufferSize);
            for (unsigned j = 0; j < mConfig.PCOUNT; j++) {
                mpz_class X = 1;
                for (unsigned k = 0; k < mConfig.N - 1; k++) {
                    X <<= 32;
                    mpz_class mod = X % gPrimes[j + mPrimorial + i + 1];
                    mModulosBuf[i][mConfig.PCOUNT * k + j] = mod.get_ui();
                }
            }
            mModulosBuf[i].copyToDevice();
        }

        JsonMidstateData midstateData;
        uint64_t nonce = 0;
        uint64_t roundWorkId = 0;

        // Mining state
        unsigned iteration = 0;
        time_t timeValidationLog = time(0);
        uint64_t testCount = 0;
        uint64_t fermatCount = 0;
        unsigned numHashCoeff = 32768;  // Adaptive hash generation coefficient (matches HIP)

        // Hash buffer and primorial array
        lifoBuffer<hash_t> hashes(PW);
        mpz_class primorial[maxHashPrimorial - mPrimorial];

        // Initialize primorial array (using mPrimorial from buffer initialization above)
        for (unsigned i = 0; i < maxHashPrimorial - mPrimorial; i++) {
            mpz_class p = 1;
            for (unsigned j = 0; j <= mPrimorial + i; j++)
                p *= gPrimes[j];
            primorial[i] = p;
        }

        // Log primorial info
        {
            unsigned primorialbits = mpz_sizeinbase(primorial[0].get_mpz_t(), 2);
            mpz_class sievesize = mConfig.SIZE * 32 * mConfig.STRIPES;
            unsigned sievebits = mpz_sizeinbase(sievesize.get_mpz_t(), 2);
            LOG_F(INFO, "GPU %d: primorial = %s (%d bits)", mID, primorial[0].get_str(10).c_str(), primorialbits);
            LOG_F(INFO, "GPU %d: sieve size = %s (%d bits)", mID, sievesize.get_str(10).c_str(), sievebits);
        }

        LOG_F(INFO, "GPU %d: Starting JSON getwork mining loop", mID);

        // Initialize ALL candidate count buffers to 0 (both ridx and widx)
        // This matches HIP behavior at src/Hip/xpmclient_hip.cpp lines 631-635
        // Ensures iteration 0 reads 0 candidates from ridx=0, not garbage
        for (int sieveIdx = 0; sieveIdx < mSievePerRound; sieveIdx++) {
            for (int instIdx = 0; instIdx < 2; instIdx++) {
                for (int pipelineIdx = 0; pipelineIdx < FERMAT_PIPELINES; pipelineIdx++) {
                    mCandidatesCountBuffers[sieveIdx][instIdx][pipelineIdx] = 0;
                }
                mCandidatesCountBuffers[sieveIdx][instIdx].copyToDevice();
            }
        }
        LOG_F(INFO, "GPU %d: Initialized all candidate count buffers to 0", mID);

        // In test mode, load work from file once
        if (gTestMode) {
            LOG_F(INFO, "GPU %d: Test mode - loading work from file", mID);
            if (!loadJsonWorkFromFile(gTestJsonFile, currentWork)) {
                LOG_F(ERROR, "GPU %d: Failed to load test JSON work", mID);
                return;
            }
            hasChanged = true;
            nonce = gTestNonce;
            roundWorkId = 0;
            iteration = 0;

            // WORKAROUND: Reset duplicate tracking for test work
            mHasLastSubmitted = false;

            LOG_F(INFO, "GPU %d: Test work - height %llu, difficulty %llu",
                  mID, (unsigned long long)currentWork.height,
                  (unsigned long long)currentWork.difficulty);

            prepareJsonMidstate(currentWork, &midstateData);

            // Copy midstate to GPU
            for (int i = 0; i < 8; i++) {
                mJsonMidstateBuf[i] = midstateData.midstate[i];
            }
            mJsonMidstateBuf.copyToDevice();

            // Copy remaining prefix to GPU
            for (unsigned i = 0; i < midstateData.remainingLen; i++) {
                mJsonRemainingPrefixBuf[i] = midstateData.remainingPrefix[i];
            }
            mJsonRemainingPrefixBuf.copyToDevice();
        }

        while (!MakeExit) {
            // Get work from server (skip in test mode)
            if (!gTestMode) {
                while (!ctx->get(mID, &currentWork, &hasChanged)) {
                    usleep(100000);  // 100ms

                    if (!ctx->isConnected()) {
                        LOG_F(WARNING, "GPU %d: Disconnected, waiting...", mID);
                        usleep(1000000);  // 1s
                    }
                }

                if (hasChanged) {
                    // Decode difficulty: chain_length + fractional (matches HIP lines 1400-1402)
                    double decodedDifficulty = (currentWork.difficulty >> 24) +
                                              ((currentWork.difficulty & 0xFFFFFF) / (double)(1 << 24));
                    unsigned target = TargetGetLength(currentWork.difficulty);

                    LOG_F(INFO, "GPU %d: New work - height %llu, difficulty %.5f, difficulty(raw) %llu, target length %u",
                          mID, (unsigned long long)currentWork.height,
                          decodedDifficulty, (unsigned long long)currentWork.difficulty, target);

                    // Reset for new work
                    nonce = 0;
                    roundWorkId = ctx->getWorkId();
                    iteration = 0;
                    hashes.clear();

                    // WORKAROUND: Reset duplicate tracking on new work
                    // This ensures we don't suppress legitimate finds on new work
                    mHasLastSubmitted = false;
                    prepareJsonMidstate(currentWork, &midstateData);

                    // Copy midstate to GPU
                    for (int i = 0; i < 8; i++) {
                        mJsonMidstateBuf[i] = midstateData.midstate[i];
                    }
                    mJsonMidstateBuf.copyToDevice();

                    // Copy remaining prefix to GPU
                    for (unsigned i = 0; i < midstateData.remainingLen; i++) {
                        mJsonRemainingPrefixBuf[i] = midstateData.remainingPrefix[i];
                    }
                    mJsonRemainingPrefixBuf.copyToDevice();
                }

                // Check for stale work
                if (ctx->getWorkId() != roundWorkId) {
                    LOG_F(WARNING, "GPU %d: Work changed during mining, restarting round", mID);
                    continue;
                }
            }

            // Validate input: check if JSON prefix is too long
            // Maximum safe size: 150 bytes remaining + 20 nonce digits + 1 closing brace = 171
            if (midstateData.remainingLen > 150) {
                LOG_F(ERROR, "GPU %d: JSON prefix too long: %u bytes (max 150). Skipping work.",
                      mID, midstateData.remainingLen);
                continue;
            }

            // Adaptive hash generation - matches HIP
            int numhash = ((int)(16 * mSievePerRound) - (int)hashes.remaining()) * numHashCoeff;
            if (numhash < 0) numhash = 0;  // Safety check

            // Only align if we have work to do
            if (numhash > 0) {
                numhash += mLSize - numhash % mLSize;  // Align to threadgroup size
            }

            // Only dispatch hash kernel if we need more hashes
            if (numhash > 0) {
                // Reset counter
                mJsonCountBuf[0] = 0;
            mJsonCountBuf.copyToDevice();

            // Create command buffer
            id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
            commandBuffer.label = @"JSON Hash Modulus";

            // Add error handler
            [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
                if (buffer.error) {
                    LOG_F(ERROR, "GPU %d: Command buffer error: %s",
                          mID, [[buffer.error localizedDescription] UTF8String]);
                }
            }];

            id<MTLComputeCommandEncoder> encoder =
                [commandBuffer computeCommandEncoder];
            encoder.label = @"JSON Hash Modulus Encoder";

            // Encode jsonHashMod kernel
            if (gDebug) {
                LOG_F(INFO, "GPU %d: Dispatching jsonHashMod kernel (numhash=%d, threadgroup=%u)",
                      mID, numhash, mLSize);
            }
            [encoder setComputePipelineState:_jsonHashModPipeline];
            [encoder setBytes:&nonce length:sizeof(uint64_t) atIndex:0];
            [encoder setBuffer:mJsonFoundBuf.buffer() offset:0 atIndex:1];
            [encoder setBuffer:mJsonCountBuf.buffer() offset:0 atIndex:2];
            [encoder setBuffer:mJsonPrimorialBuf.buffer() offset:0 atIndex:3];
            [encoder setBuffer:mJsonMidstateBuf.buffer() offset:0 atIndex:4];
            [encoder setBuffer:mJsonRemainingPrefixBuf.buffer() offset:0 atIndex:5];
            [encoder setBytes:&midstateData.remainingLen length:sizeof(uint32_t) atIndex:6];
            [encoder setBytes:&midstateData.totalPrefixLen length:sizeof(uint32_t) atIndex:7];
            [encoder setBytes:&mConfig.LIMIT13 length:sizeof(uint32_t) atIndex:8];
            [encoder setBytes:&mConfig.LIMIT14 length:sizeof(uint32_t) atIndex:9];
            [encoder setBytes:&mConfig.LIMIT15 length:sizeof(uint32_t) atIndex:10];

            MTLSize gridSize = MTLSizeMake(numhash, 1, 1);
            MTLSize threadgroupSize = MTLSizeMake(mLSize, 1, 1);
            [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];

            [encoder endEncoding];

            // Add timeout protection to prevent system freeze
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
                dispatch_semaphore_signal(sema);
            }];

            [commandBuffer commit];
            if (gDebug) {
                LOG_F(INFO, "GPU %d: Waiting for kernel completion...", mID);
            }

            // Wait with 5 second timeout
            long result = dispatch_semaphore_wait(sema,
                dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

            if (result != 0) {
                LOG_F(ERROR, "GPU %d: Kernel timeout after 5 seconds! GPU may be hung.", mID);
                return;
            }

            if (gDebug) {
                LOG_F(INFO, "GPU %d: Kernel completed, status: %ld", mID, (long)commandBuffer.status);
            }

            // Process results
            mJsonCountBuf.copyToHost();
            unsigned foundCount = mJsonCountBuf[0];

            if (gDebug) {
                LOG_F(INFO, "GPU %d: jsonHashMod found %u candidates", mID, foundCount);
            }

            if (foundCount > 0) {
                mJsonFoundBuf.copyToHost();
                mJsonPrimorialBuf.copyToHost();

                if (gDebug) {
                    LOG_F(INFO, "GPU %d: Starting CPU validation of %u candidates", mID, foundCount);
                }

                // Process found candidates - validate on CPU before sending to sieve
                unsigned processCount = std::min(foundCount, 128u);
                unsigned validCount = 0;
                unsigned failedMinimum = 0;
                unsigned failedDivisible = 0;

                for (unsigned i = 0; i < processCount; i++) {
                    uint64_t candidateNonce = nonce + mJsonFoundBuf[i];
                    uint32_t primorialBitField = mJsonPrimorialBuf[i];
                    uint32_t primorialIdx = primorialBitField >> 16;  // Extract index (13, 14, or 15)

                    // Calculate realPrimorial from bit field
                    uint64_t realPrimorial = 1;
                    for (unsigned j = 0; j < primorialIdx + 1; j++) {
                        if (primorialBitField & (1 << j))
                            realPrimorial *= gPrimes[j];
                    }

                    // Reconstruct full JSON with this nonce
                    char jsonStr[512];
                    int jsonLen = snprintf(jsonStr, sizeof(jsonStr),
                        R"({"parent_hash": "%s", "height": %llu, "difficulty": %llu, "merkle": "%s", "nonce": %llu})",
                        currentWork.parentHash.c_str(),
                        (unsigned long long)currentWork.height,
                        (unsigned long long)currentWork.difficulty,
                        currentWork.merkle.c_str(),
                        (unsigned long long)candidateNonce);

                    // Compute SHA256(SHA256(json))
                    SHA_256 sha1;
                    sha1.init();
                    sha1.update((const unsigned char*)jsonStr, jsonLen);
                    unsigned char hash1[32];
                    sha1.final(hash1);

                    SHA_256 sha2;
                    sha2.init();
                    sha2.update(hash1, 32);
                    unsigned char hash2[32];
                    sha2.final(hash2);

                    // Convert to uint256 in little-endian
                    char hashHex[65];
                    for (int j = 0; j < 32; j++) {
                        snprintf(hashHex + j * 2, 3, "%02x", hash2[31 - j]);  // Reverse for little-endian
                    }
                    hashHex[64] = 0;

                    uint256 hash256;
                    hash256.SetHex(hashHex);

                    // Validate hash meets minimum (>= 2^255)
                    if (hash256 < (uint256(1) << 255)) {
                        failedMinimum++;
                        continue;
                    }

                    // Convert to mpz and validate divisibility
                    mpz_class mpzHash;
                    mpz_set_uint256(mpzHash.get_mpz_t(), hash256);

                    mpz_class mpzRealPrimorial;
                    mpz_import(mpzRealPrimorial.get_mpz_t(), 2, -1, 4, 0, 0, &realPrimorial);
                    unsigned adjustedIdx = std::max(mPrimorial, primorialIdx) - mPrimorial;
                    mpz_class mpzHashMultiplier = primorial[adjustedIdx] / mpzRealPrimorial;

                    if (!mpz_divisible_p(mpzHash.get_mpz_t(), mpzRealPrimorial.get_mpz_t())) {
                        failedDivisible++;
                        continue;
                    }

                    // Create hash_t and add to buffer
                    hash_t hash;
                    hash.iter = iteration;
                    hash.nonce = (uint32_t)candidateNonce;
                    hash.time = 0;  // Not used in getwork mode
                    hash.hash = hash256;
                    hash.primorialIdx = adjustedIdx;
                    hash.primorial = mpzHashMultiplier;
                    hash.shash = mpzHash * hash.primorial;

                    unsigned hid = hashes.push(hash);
                    memset(&hashBuf[hid * mConfig.N], 0, sizeof(uint32_t) * mConfig.N);
                    mpz_export(&hashBuf[hid * mConfig.N], 0, -1, 4, 0, 0, hashes.get(hid).shash.get_mpz_t());
                    validCount++;

                    // CHECKPOINT 1: Dump first valid candidate for test mode
                    if (gTestMode && validCount == 1) {
                        LOG_F(INFO, "GPU %d: Test mode - dumping checkpoint 1 (JSON/Hash)", mID);

                        // Dump JSON input
                        dumpBuffer("01_json_input.bin", jsonStr, jsonLen);

                        // Dump SHA256 hash (32 bytes)
                        dumpBuffer("01_sha256_hash.bin", hash2, 32);

                        // Dump shash (11 uint32s = 44 bytes)
                        dumpBuffer("01_shash.bin", &hashBuf[hid * mConfig.N], 11 * sizeof(uint32_t));

                        LOG_F(INFO, "GPU %d: Checkpoint 1 dumps complete", mID);
                        LOG_F(INFO, "  JSON: %s", jsonStr);
                        LOG_F(INFO, "  Nonce: %llu", (unsigned long long)candidateNonce);
                        LOG_F(INFO, "  Hash (hex): %s", hashHex);
                    }
                }

                // Log validation stats periodically (matches HIP at lines 1584-1596)
                time_t currtime = time(0);
                bool shouldLog = gDebug || (currtime - timeValidationLog >= 60);

                if (validCount > 0) {
                    hashBuf.copyToDevice();

                    if (shouldLog) {
                        LOG_F(INFO, "GPU %d: Validated %u/%u candidates (failed: %u minimum, %u divisibility)",
                              mID, validCount, processCount, failedMinimum, failedDivisible);
                        timeValidationLog = currtime;
                    }
                } else if (processCount > 0 && gDebug) {
                    LOG_F(WARNING, "GPU %d: 0/%u candidates validated (failed: %u minimum, %u divisibility)",
                          mID, processCount, failedMinimum, failedDivisible);
                }
            }  // End of if (numhash > 0)

                // TODO: Sieve and Fermat pipeline will be implemented here
                // TODO: Next steps:
                // - Run sieve kernels (setup_sieve, sieve, s_sieve)
                // - Run Fermat tests (fermat_kernel320, fermat_kernel352)
                // - Verify chains on CPU
                // - Submit valid blocks via ctx->submitWork()
            }

            // Sieve pipeline dispatch
            int ridx = iteration % 2;
            int widx = ridx ^ 1;

            if (gDebug) {
                LOG_F(INFO, "GPU %d: Sieve pipeline - hashes buffer has %zu candidates, mSievePerRound=%u",
                      mID, hashes.remaining(), mSievePerRound);
            }

            for (unsigned i = 0; i < mSievePerRound; i++) {
                if (gDebug) {
                    LOG_F(INFO, "GPU %d: Sieve round %u/%u starting", mID, i, mSievePerRound);
                }

                if (hashes.empty()) {
                    if (!hasChanged) {  // Don't increase on new work (matches HIP's "if (!reset)")
                        numHashCoeff += 32768;
                        LOG_F(WARNING, "GPU %d: Ran out of hashes, increasing sha256 work size coefficient to %u",
                              mID, numHashCoeff);
                    }
                    break;
                }

                int hid = hashes.pop();
                if (gDebug) {
                    LOG_F(INFO, "GPU %d: Processing hash %d (primorialIdx will be determined)", mID, hid);
                }
                unsigned primorialIdx = hashes.get(hid).primorialIdx;

                if (gDebug) {
                    LOG_F(INFO, "GPU %d: Hash %d has primorialIdx=%u", mID, hid, primorialIdx);
                }

                // Reset candidate count for this sieve
                mCandidatesCountBuffers[i][widx][0] = 0;
                mCandidatesCountBuffers[i][widx][1] = 0;
                mCandidatesCountBuffers[i][widx].copyToDevice();

                if (gDebug) {
                    LOG_F(INFO, "GPU %d: Creating command buffer for sieve kernels", mID);
                }

                // CHECKPOINT 2: In test mode, run setup_sieve separately and dump
                if (gTestMode && i == 0 && iteration == 0) {
                    LOG_F(INFO, "Checkpoint 2: Running setup_sieve separately for dump");

                    id<MTLCommandBuffer> setupOnlyBuffer = [_commandQueue commandBuffer];
                    id<MTLComputeCommandEncoder> setupEncoder = [setupOnlyBuffer computeCommandEncoder];

                    [setupEncoder setComputePipelineState:_sieveSetupPipeline];
                    [setupEncoder setBuffer:mSieveOff[0].buffer() offset:0 atIndex:0];
                    [setupEncoder setBuffer:mSieveOff[1].buffer() offset:0 atIndex:1];
                    [setupEncoder setBuffer:mPrimeBuf[primorialIdx].buffer() offset:0 atIndex:2];
                    [setupEncoder setBuffer:hashBuf.buffer() offset:0 atIndex:3];
                    [setupEncoder setBytes:&hid length:sizeof(uint32_t) atIndex:4];
                    [setupEncoder setBuffer:mModulosBuf[primorialIdx].buffer() offset:0 atIndex:5];
                    [setupEncoder setBytes:&mConfig.N length:sizeof(uint32_t) atIndex:6];
                    [setupEncoder setBytes:&mConfig.PCOUNT length:sizeof(uint32_t) atIndex:7];
                    [setupEncoder setBytes:&mConfig.WIDTH length:sizeof(uint32_t) atIndex:8];

                    MTLSize setupGrid = MTLSizeMake(mConfig.PCOUNT / mLSize, 1, 1);
                    MTLSize setupThreadgroup = MTLSizeMake(mLSize, 1, 1);
                    [setupEncoder dispatchThreadgroups:setupGrid threadsPerThreadgroup:setupThreadgroup];
                    [setupEncoder endEncoding];

                    [setupOnlyBuffer commit];
                    [setupOnlyBuffer waitUntilCompleted];

                    // Copy buffers to host and dump
                    mSieveOff[0].copyToHost();
                    mSieveOff[1].copyToHost();

                    LOG_F(INFO, "Checkpoint 2: Dumping setup_sieve outputs");
                    dumpMetalBuffer("02_offset1.bin", mSieveOff[0].buffer(), mConfig.PCOUNT * mConfig.WIDTH * sizeof(uint32_t));
                    dumpMetalBuffer("02_offset2.bin", mSieveOff[1].buffer(), mConfig.PCOUNT * mConfig.WIDTH * sizeof(uint32_t));
                    dumpMetalBuffer("02_hash_buffer.bin", hashBuf.buffer(), mConfig.N * sizeof(uint32_t));
                    LOG_F(INFO, "Checkpoint 2 complete");
                }

                // Create command buffer for sieve operations
                id<MTLCommandBuffer> sieveCommandBuffer = [_commandQueue commandBuffer];
                id<MTLComputeCommandEncoder> encoder = [sieveCommandBuffer computeCommandEncoder];

                // 1. Setup sieve kernel (skip in test mode if already done for checkpoint)
                @try {
                    if (!(gTestMode && i == 0 && iteration == 0)) {
                        [encoder setComputePipelineState:_sieveSetupPipeline];
                        [encoder setBuffer:mSieveOff[0].buffer() offset:0 atIndex:0];
                        [encoder setBuffer:mSieveOff[1].buffer() offset:0 atIndex:1];
                        [encoder setBuffer:mPrimeBuf[primorialIdx].buffer() offset:0 atIndex:2];
                        [encoder setBuffer:hashBuf.buffer() offset:0 atIndex:3];
                        [encoder setBytes:&hid length:sizeof(uint32_t) atIndex:4];
                        [encoder setBuffer:mModulosBuf[primorialIdx].buffer() offset:0 atIndex:5];
                        [encoder setBytes:&mConfig.N length:sizeof(uint32_t) atIndex:6];
                        [encoder setBytes:&mConfig.PCOUNT length:sizeof(uint32_t) atIndex:7];
                        [encoder setBytes:&mConfig.WIDTH length:sizeof(uint32_t) atIndex:8];

                        // Need PCOUNT total threads (one per prime)
                        MTLSize setupGrid = MTLSizeMake(mConfig.PCOUNT / mLSize, 1, 1);  // Number of threadgroups
                        MTLSize setupThreadgroup = MTLSizeMake(mLSize, 1, 1);
                        [encoder dispatchThreadgroups:setupGrid threadsPerThreadgroup:setupThreadgroup];
                    }

                // CRITICAL: Force setup_sieve completion before sieve kernels
                // Without this, setup_sieve may not finish before sieve reads the offset buffers
                // This is the root cause of all-zero offsets!
                [encoder endEncoding];
                [sieveCommandBuffer commit];
                [sieveCommandBuffer waitUntilCompleted];

                if (gDebug && i == 0 && hid == 0) {
                    LOG_F(INFO, "DEBUG: setup_sieve completed, status: %ld", (long)sieveCommandBuffer.status);
                }

                // Recreate command buffer and encoder for remaining kernels
                sieveCommandBuffer = [_commandQueue commandBuffer];
                encoder = [sieveCommandBuffer computeCommandEncoder];

                // Calculate SIEVERANGE constants
                // These determine different processing strategies for primes of different sizes
                uint32_t windowSize = mConfig.SIZE * 32;  // Sieve window in bits
                uint32_t threadsNum = mLSize;  // LSIZE (now 512 instead of hardcoded 256)
                uint32_t sieveRange1 = 0, sieveRange2 = 0, sieveRange3 = 0;

                // Get prime array from mPrimeBuf2
                // mPrimeBuf2 is a uint2 array: {prime, float_as_uint(1.0f/prime)}
                struct Prime2 { uint32_t prime; uint32_t invFloat; };
                Prime2* primes = (Prime2*)mPrimeBuf2[primorialIdx].buffer().contents;
                for (unsigned i = 0; i < mConfig.PCOUNT / threadsNum; i++) {
                    // Access prime at position i * threadsNum (every threadsNum-th prime)
                    uint32_t prime = primes[i * threadsNum].prime;
                    if (sieveRange1 == 0 && windowSize / prime <= 2)
                        sieveRange1 = i;
                    if (sieveRange2 == 0 && windowSize / prime <= 1)
                        sieveRange2 = i;
                    if (sieveRange3 == 0 && prime >= windowSize)
                        sieveRange3 = i;
                }

                // If ranges weren't set (all primes smaller than window), set to max
                if (sieveRange2 == 0) sieveRange2 = mConfig.PCOUNT / threadsNum;
                if (sieveRange3 == 0) sieveRange3 = mConfig.PCOUNT / threadsNum;

                // Debug: Log SIEVERANGE values
                if (gDebug && i == 0) {
                    LOG_F(INFO, "SIEVE DEBUG: windowSize=%u, PCOUNT=%u, threadsNum=%u",
                          windowSize, mConfig.PCOUNT, threadsNum);
                    LOG_F(INFO, "SIEVE DEBUG: SIEVERANGE1=%u, SIEVERANGE2=%u, SIEVERANGE3=%u",
                          sieveRange1, sieveRange2, sieveRange3);
                    LOG_F(INFO, "SIEVE DEBUG: First 5 primes (every 256th): %u, %u, %u, %u, %u",
                          primes[0].prime, primes[256].prime, primes[512].prime,
                          primes[768].prime, primes[1024].prime);
                }

                // Debug: Check if offset buffers are actually different
                if (gDebug && i == 0 && hid == 0) {
                    mSieveOff[0].copyToHost();
                    mSieveOff[1].copyToHost();

                    int diff_count = 0;
                    int same_count = 0;
                    for (uint32_t j = 0; j < std::min(100u, mConfig.PCOUNT); j++) {
                        if (mSieveOff[0][j] != mSieveOff[1][j]) {
                            diff_count++;
                        } else {
                            same_count++;
                        }
                    }
                    LOG_F(INFO, "DEBUG OFFSETS: offset[0] vs offset[1]: %d different, %d same (first 100)",
                          diff_count, same_count);

                    // Show first 10 values
                    LOG_F(INFO, "DEBUG offset[0] first 10: %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x",
                          mSieveOff[0][0], mSieveOff[0][1], mSieveOff[0][2], mSieveOff[0][3], mSieveOff[0][4],
                          mSieveOff[0][5], mSieveOff[0][6], mSieveOff[0][7], mSieveOff[0][8], mSieveOff[0][9]);
                    LOG_F(INFO, "DEBUG offset[1] first 10: %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x",
                          mSieveOff[1][0], mSieveOff[1][1], mSieveOff[1][2], mSieveOff[1][3], mSieveOff[1][4],
                          mSieveOff[1][5], mSieveOff[1][6], mSieveOff[1][7], mSieveOff[1][8], mSieveOff[1][9]);
                }

                // 2. Single-pass sieve (SIZE=4096 fits in 16KB threadgroup memory)
                [encoder setComputePipelineState:_sievePipeline];

                MTLSize sieveGrid = MTLSizeMake((mConfig.STRIPES / 2) * mConfig.WIDTH, 1, 1);
                MTLSize sieveThreadgroup = MTLSizeMake(mLSize, 1, 1);

                // Pass A: Cunningham1 chain (CH1)
                [encoder setBuffer:mSieveBuf[0].buffer() offset:0 atIndex:0];
                [encoder setBuffer:mSieveOff[0].buffer() offset:0 atIndex:1];
                [encoder setBuffer:mPrimeBuf2[primorialIdx].buffer() offset:0 atIndex:2];
                [encoder setBytes:&mConfig.SIZE length:sizeof(uint32_t) atIndex:3];
                [encoder setBytes:&mConfig.STRIPES length:sizeof(uint32_t) atIndex:4];
                [encoder setBytes:&mConfig.PCOUNT length:sizeof(uint32_t) atIndex:5];
                [encoder setBytes:&sieveRange1 length:sizeof(uint32_t) atIndex:6];
                [encoder setBytes:&sieveRange2 length:sizeof(uint32_t) atIndex:7];
                [encoder setBytes:&sieveRange3 length:sizeof(uint32_t) atIndex:8];
                [encoder setBytes:&mConfig.PCOUNT length:sizeof(uint32_t) atIndex:9];  // SCOUNT = PCOUNT
                [encoder dispatchThreadgroups:sieveGrid threadsPerThreadgroup:sieveThreadgroup];

                // Pass B: Cunningham2 chain (CH2)
                [encoder setBuffer:mSieveBuf[1].buffer() offset:0 atIndex:0];
                [encoder setBuffer:mSieveOff[1].buffer() offset:0 atIndex:1];
                [encoder setBuffer:mPrimeBuf2[primorialIdx].buffer() offset:0 atIndex:2];
                [encoder setBytes:&mConfig.SIZE length:sizeof(uint32_t) atIndex:3];
                [encoder setBytes:&mConfig.STRIPES length:sizeof(uint32_t) atIndex:4];
                [encoder setBytes:&mConfig.PCOUNT length:sizeof(uint32_t) atIndex:5];
                [encoder setBytes:&sieveRange1 length:sizeof(uint32_t) atIndex:6];
                [encoder setBytes:&sieveRange2 length:sizeof(uint32_t) atIndex:7];
                [encoder setBytes:&sieveRange3 length:sizeof(uint32_t) atIndex:8];
                [encoder setBytes:&mConfig.PCOUNT length:sizeof(uint32_t) atIndex:9];
                [encoder dispatchThreadgroups:sieveGrid threadsPerThreadgroup:sieveThreadgroup];

                // 3. Sieve search kernel (processes the 4096-element sieve)
                [encoder setComputePipelineState:_sieveSearchPipeline];
                [encoder setBuffer:mSieveBuf[0].buffer() offset:0 atIndex:0];
                [encoder setBuffer:mSieveBuf[1].buffer() offset:0 atIndex:1];
                [encoder setBuffer:mSieveBuffers[i][0][widx].buffer() offset:0 atIndex:2];
                [encoder setBuffer:mSieveBuffers[i][1][widx].buffer() offset:0 atIndex:3];
                [encoder setBuffer:mCandidatesCountBuffers[i][widx].buffer() offset:0 atIndex:4];
                [encoder setBytes:&hid length:sizeof(uint32_t) atIndex:5];

                uint32_t multiplierSize = mpz_sizeinbase(hashes.get(hid).shash.get_mpz_t(), 2);
                [encoder setBytes:&multiplierSize length:sizeof(uint32_t) atIndex:6];
                [encoder setBytes:&mDepth length:sizeof(uint32_t) atIndex:7];
                [encoder setBytes:&mConfig.TARGET length:sizeof(uint32_t) atIndex:8];
                [encoder setBytes:&mConfig.WIDTH length:sizeof(uint32_t) atIndex:9];
                [encoder setBytes:&mConfig.SIZE length:sizeof(uint32_t) atIndex:10];
                [encoder setBytes:&mConfig.STRIPES length:sizeof(uint32_t) atIndex:11];

                MTLSize searchGrid = MTLSizeMake((mConfig.SIZE * mConfig.STRIPES / 2) / mLSize, 1, 1);
                MTLSize searchThreadgroup = MTLSizeMake(mLSize, 1, 1);
                [encoder dispatchThreadgroups:searchGrid threadsPerThreadgroup:searchThreadgroup];

                // Debug: Check sieve output for first sieve in each round
                if (gDebug && i == 0 && hid < 5) {  // Only log for first few hashes
                    LOG_F(INFO, "SIEVE DEBUG: About to commit sieve kernels for hash %d", hid);
                }

                    [encoder endEncoding];
                    [sieveCommandBuffer commit];

                    // CRITICAL FIX: Wait for sieve to complete before next round
                    // All 4 sieve rounds write to the same mSieveBuf[0/1] buffers
                    // Without waiting, they run in parallel and overwrite each other's data
                    // This matches HIP's sequential execution using a single stream
                    [sieveCommandBuffer waitUntilCompleted];

                    // Debug: Check sieve output for first hash
                    if (gDebug && i == 0 && hid == 0) {
                        mSieveBuf[0].copyToHost();
                        LOG_F(INFO, "SIEVE DEBUG: Sieve buffer output (first 10): %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x",
                              mSieveBuf[0][0], mSieveBuf[0][1], mSieveBuf[0][2], mSieveBuf[0][3], mSieveBuf[0][4],
                              mSieveBuf[0][5], mSieveBuf[0][6], mSieveBuf[0][7], mSieveBuf[0][8], mSieveBuf[0][9]);
                    }

                    // CHECKPOINT 3: Dump sieve outputs (once in test mode)
                    if (gTestMode && i == 0 && iteration == 0) {
                        mSieveBuf[0].copyToHost();
                        mSieveBuf[1].copyToHost();

                        LOG_F(INFO, "Checkpoint 3: Dumping sieve outputs");
                        dumpMetalBuffer("03_sieve_buffer1.bin", mSieveBuf[0].buffer(), mConfig.SIZE * mConfig.STRIPES / 2 * mConfig.WIDTH * sizeof(uint32_t));
                        dumpMetalBuffer("03_sieve_buffer2.bin", mSieveBuf[1].buffer(), mConfig.SIZE * mConfig.STRIPES / 2 * mConfig.WIDTH * sizeof(uint32_t));
                        LOG_F(INFO, "Checkpoint 3 complete");

                        // CHECKPOINT 4: Dump s_sieve outputs (candidates extracted from sieve)
                        mSieveBuffers[i][0][widx].copyToHost();
                        mSieveBuffers[i][1][widx].copyToHost();
                        mCandidatesCountBuffers[i][widx].copyToHost();

                        LOG_F(INFO, "Checkpoint 4: Dumping s_sieve outputs");
                        dumpMetalBuffer("04_found320.bin", mSieveBuffers[i][0][widx].buffer(), MSO * sizeof(fermat_t));
                        dumpMetalBuffer("04_found352.bin", mSieveBuffers[i][1][widx].buffer(), MSO * sizeof(fermat_t));
                        dumpMetalBuffer("04_fcount.bin", mCandidatesCountBuffers[i][widx].buffer(), FERMAT_PIPELINES * sizeof(uint32_t));
                        LOG_F(INFO, "Checkpoint 4 complete");
                    }

                    // Don't wait - let it run asynchronously
                    // Debug: Check what types of candidates the sieve found
                    if (gDebug && i == 0 && hid == 0) {
                        // Check if mSieveBuf[0] and mSieveBuf[1] have candidate-viable data
                        mSieveBuf[0].copyToHost();
                        mSieveBuf[1].copyToHost();
                        uint32_t buf0_not_full = 0, buf1_not_full = 0;
                        for (uint32_t j = 0; j < std::min(1000u, mConfig.SIZE * mConfig.STRIPES / 2); j++) {
                            if (mSieveBuf[0][j] != 0xFFFFFFFF) buf0_not_full++;
                            if (mSieveBuf[1][j] != 0xFFFFFFFF) buf1_not_full++;
                        }
                        LOG_F(INFO, "DEBUG: mSieveBuf[0] has %u/%u non-saturated values (potential CH1 candidates)",
                              buf0_not_full, 1000);
                        LOG_F(INFO, "DEBUG: mSieveBuf[1] has %u/%u non-saturated values (potential CH2 candidates)",
                              buf1_not_full, 1000);

                        // Show first 10 values from each buffer
                        LOG_F(INFO, "DEBUG: mSieveBuf[0] first 10: %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x",
                              mSieveBuf[0][0], mSieveBuf[0][1], mSieveBuf[0][2], mSieveBuf[0][3], mSieveBuf[0][4],
                              mSieveBuf[0][5], mSieveBuf[0][6], mSieveBuf[0][7], mSieveBuf[0][8], mSieveBuf[0][9]);
                        LOG_F(INFO, "DEBUG: mSieveBuf[1] first 10: %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x",
                              mSieveBuf[1][0], mSieveBuf[1][1], mSieveBuf[1][2], mSieveBuf[1][3], mSieveBuf[1][4],
                              mSieveBuf[1][5], mSieveBuf[1][6], mSieveBuf[1][7], mSieveBuf[1][8], mSieveBuf[1][9]);
                    }

                    if (gDebug && i == 0) {
                        mCandidatesCountBuffers[i][widx].copyToHost();
                        uint32_t count320 = mCandidatesCountBuffers[i][widx][0];
                        uint32_t count352 = mCandidatesCountBuffers[i][widx][1];

                        // Sample ALL candidates (not just first 100) to check type distribution
                        if (count320 > 0 || count352 > 0) {
                            mSieveBuffers[i][0][widx].copyToHost();
                            mSieveBuffers[i][1][widx].copyToHost();

                            uint32_t type_counts[3] = {0, 0, 0};  // CH1, CH2, BiTwin

                            // Count ALL 320-bit candidates
                            for (uint32_t j = 0; j < count320; j++) {
                                fermat_t* candidates = (fermat_t*)mSieveBuffers[i][0][widx]._hostData;
                                if (candidates[j].type < 3) {
                                    type_counts[candidates[j].type]++;
                                }
                            }
                            // Count ALL 352-bit candidates
                            for (uint32_t j = 0; j < count352; j++) {
                                fermat_t* candidates = (fermat_t*)mSieveBuffers[i][1][widx]._hostData;
                                if (candidates[j].type < 3) {
                                    type_counts[candidates[j].type]++;
                                }
                            }

                            LOG_F(INFO, "GPU %d: Sieve found %u+%u candidates. Type distribution (ALL): CH1=%u, CH2=%u, BiTwin=%u",
                                  mID, count320, count352, type_counts[0], type_counts[1], type_counts[2]);
                        }
                    }

                    if (gDebug) {
                        LOG_F(INFO, "GPU %d: Sieve kernels dispatched successfully for hash %d", mID, hid);
                    }
                } @catch (NSException *exception) {
                    LOG_F(ERROR, "GPU %d: Exception during sieve dispatch: %s",
                          mID, [[exception description] UTF8String]);
                }
            }

            // Get final candidates from previous iteration
            uint32_t* finalDevicePtr = (uint32_t*)final.count.buffer().contents;
            if (gDebug) {
                LOG_F(INFO, "GPU %d: BEFORE copyToHost - device buffer final.count[0]=%u (mDepth=%u)",
                      mID, finalDevicePtr[0], mDepth);
            }
            final.count.copyToHost();
            int numcandis = final.count[0];
            numcandis = std::min(numcandis, (int)final.info._size);
            numcandis = std::max(numcandis, 0);

            if (gDebug) {
                LOG_F(INFO, "GPU %d: Fermat results from previous iteration: %d candidates passed (chainpos reached depth=%u)",
                      mID, numcandis, mDepth);
            }

            std::vector<fermat_t> candis(numcandis);
            if (numcandis > 0) {
                final.info.copyToHost();
                memcpy(&candis[0], final.info._hostData, numcandis * sizeof(fermat_t));
            }

            // Reset final count
            final.count[0] = 0;
            final.count.copyToDevice();

            // Dispatch Fermat tests for 320-bit and 352-bit
            FermatDispatch(mFermat320, mSieveBuffers, mCandidatesCountBuffers, 0, ridx, widx,
                          testCount, fermatCount, _fermatKernel320Pipeline, mSievePerRound);
            FermatDispatch(mFermat352, mSieveBuffers, mCandidatesCountBuffers, 1, ridx, widx,
                          testCount, fermatCount, _fermatKernel352Pipeline, mSievePerRound);

            // CPU chain validation and submission
            CPrimalityTestParamsCuda testParams;
            testParams.nBits = currentWork.difficulty;  // Set difficulty target (matches HIP line 1397)

            unsigned skippedOutOfBounds = 0;
            unsigned skippedTooOld = 0;

            for (unsigned i = 0; i < candis.size(); ++i) {
                fermat_t& candi = candis[i];

                // Bounds check: hashid must be within circular buffer range
                if (candi.hashid >= PW) {
                    skippedOutOfBounds++;
                    if (gDebug && i < 10) {
                        LOG_F(ERROR, "GPU %d: Candidate %u has invalid hashid %u >= PW %u, skipping",
                              mID, i, candi.hashid, PW);
                    }
                    continue;
                }

                hash_t& hash = hashes.get(candi.hashid);

                // Age check: hash must not be too old (like HIP does at line 1440)
                unsigned age = iteration - hash.iter;
                if (age > PW/2) {
                    skippedTooOld++;
                    if (gDebug && i < 10) {
                        LOG_F(WARNING, "GPU %d: Candidate %u age %u > PW/2 (%u), hashid=%u, skipping",
                              mID, i, age, PW/2, candi.hashid);
                    }
                    continue;
                }

                mpz_class origin = hash.shash;
                mpz_class multi;
                mpz_import(multi.get_mpz_t(), 1, -1, 4, 0, 0, &candi.index);
                multi <<= candi.origin;  // CRITICAL: Left shift by origin (matches HIP line 1738)
                origin *= multi;

                // Adjust for chain type
                if (candi.type == 0) {
                    origin -= 1;  // Cunningham1
                } else if (candi.type == 1) {
                    origin += 1;  // Cunningham2
                }

                // Set candidate type for CPU validation (matches HIP line 1742)
                testParams.nCandidateType = candi.type + 1;

                // Test chain (use mDepth as base to continue from where GPU left off - matches HIP line 1743)
                bool isblock = ProbablePrimeChainTestFastCuda(origin, testParams, mDepth);

                // Log detailed validation only in debug mode
                if (gDebug && i < 10) {
                    double chainLength = testParams.nChainLength / 16777216.0;
                    const char* typeName = (candi.type == 0) ? "Cunningham1" :
                                           (candi.type == 1) ? "Cunningham2" :
                                           (candi.type == 2) ? "BiTwin" : "Unknown";
                    LOG_F(INFO, "GPU %d: Candidate %u: type=%s chainpos=%u chainLength=%.6f difficulty=%.6f",
                          mID, i, typeName, candi.chainpos, chainLength, currentWork.difficulty / 16777216.0);
                }

                // Match HIP's submission logic exactly (line 1496)
                // Use ONLY the testParams.nChainLength check, no redundant isblock check
                if (testParams.nChainLength >= currentWork.difficulty) {
                    // ========================================================================
                    // WORKAROUND: Check for duplicate candidate BEFORE any output
                    // ========================================================================
                    // WHY THIS EXISTS:
                    //   The fermat pipeline is somehow producing the SAME candidate multiple
                    //   times in rapid succession (within 0.3 seconds). This causes:
                    //   - Duplicate share submissions to the pool (pool rejects them)
                    //   - Wasted network bandwidth
                    //   - Misleading logs showing "block found" multiple times
                    //
                    // WHAT THIS DOES:
                    //   Compare current candidate against the last processed one.
                    //   If identical, skip EVERYTHING (printf, submission, logs).
                    //
                    // FIX: Track ALL candidates (BiTwin, Cunningham1, Cunningham2)
                    //   Previously only tracked BiTwin submissions, so non-BiTwin duplicates
                    //   were never suppressed!
                    //
                    // THIS IS NOT A FIX! This just hides the symptom!
                    //   The real problem is in the fermat pipeline or buffer management.
                    //   See header file (xpmclient_metal.h) for details on proper fix.
                    // ========================================================================
                    bool isDuplicate = false;
                    if (mHasLastSubmitted && origin == mLastSubmittedCandidate) {
                        isDuplicate = true;
                        // Silently skip - this candidate was already processed
                    }

                    // ONLY process if NOT duplicate
                    if (!isDuplicate) {
                        // Print candidate origin for all chains that meet difficulty (matches HIP format at line 1497)
                        printf("\ncandis[%u] = %s\n", i, origin.get_str(10).c_str());

                        // Normalization is NOT needed for JSON getwork
                        // The server expects multiplier such that: SHA256(work) * multiplier = exact prime origin
                        // Normalization changes the origin, causing server validation to fail

                        bool submitted = false;

                        // Submit work via getwork protocol - ONLY BiTwin chains (type 3) - matches HIP line 1519-1532
                        if (testParams.nCandidateType == PRIME_CHAIN_BI_TWIN) {
                            // Check if work has changed before submitting (prevent stale submissions)
                            if (ctx->getWorkId() != roundWorkId) {
                                LOG_F(INFO, "GPU %d: Skipping stale submission (work changed)", mID);
                            } else {
                                // Calculate target multiplier = primorial * multi (matches HIP line 1500)
                                mpz_class targetMultiplier = hash.primorial * multi;

                                // Submit work
                                submitted = ctx->submitWork(currentWork, hash.nonce, targetMultiplier);

                                // If submitted, trigger refresh request (don't wait, continue mining)
                                if (submitted) {
                                    ctx->triggerRefresh();  // Request new work immediately
                                }
                            }
                        }

                        // WORKAROUND: Track this candidate to prevent future duplicates
                        // Track ALL candidates (BiTwin, C1, C2), not just submitted ones!
                        mLastSubmittedCandidate = origin;
                        mHasLastSubmitted = true;

                        // Log share found for ALL chains (matches HIP format at line 1534-1537)
                        std::string chainName = GetPrimeChainName(testParams.nCandidateType, testParams.nChainLength);
                        const char* submitStatus = (testParams.nCandidateType == PRIME_CHAIN_BI_TWIN) ?
                                                   (submitted ? "yes" : "failed") : "skipped (not BiTwin)";
                        LOG_F(1, "GPU %d found share: %s (submitted: %s)", mID, chainName.c_str(), submitStatus);

                        // Log block found for ALL chains (matches HIP format at line 1539-1544)
                        if (isblock) {
                            LOG_F(1, "GPU %d found BLOCK!", mID);
                            std::string nbitsTarget = TargetToString(testParams.nBits);
                            LOG_F(1, "Found chain: %s", chainName.c_str());
                            LOG_F(1, "Target (nbits): %s\n----------------------------------------------------------------------", nbitsTarget.c_str());
                        }

                        // Update statistics
                        unsigned chainLengthInt = testParams.nChainLength >> 24;
                        if (chainLengthInt < MaxChainLength) {
                            mineCtx.foundChains[chainLengthInt]++;
                        }
                    }  // End of !isDuplicate
                }
            }

            // Report skipped candidates
            if (gDebug && (skippedOutOfBounds > 0 || skippedTooOld > 0)) {
                LOG_F(WARNING, "GPU %d: Skipped %u candidates (out of bounds: %u, too old: %u) from total %zu",
                      mID, skippedOutOfBounds + skippedTooOld, skippedOutOfBounds, skippedTooOld, candis.size());
            }

            nonce += numhash;
            iteration++;

            // Update statistics
            mineCtx.totalRoundsNum++;

            // Exit after first iteration in test mode (checkpoints are dumped)
            if (gTestMode && iteration >= 1) {
                LOG_F(INFO, "GPU %d: Test mode complete, exiting after iteration %u", mID, iteration);
                break;
            }
        }

        LOG_F(INFO, "GPU %d: Mining loop exited", mID);
    }
}

//=============================================================================
// Test Mode Helper Functions
//=============================================================================

// Load JsonWork from a JSON file for test mode
bool loadJsonWorkFromFile(const char* filename, JsonWork& work) {
    FILE* f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "Error: Cannot open test JSON file: %s\n", filename);
        return false;
    }

    // Read entire file
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    std::string content(size, '\0');
    if (fread(&content[0], 1, size, f) != (size_t)size) {
        fprintf(stderr, "Error: Failed to read test JSON file\n");
        fclose(f);
        return false;
    }
    fclose(f);

    // Parse JSON (simple manual parsing for the specific format)
    auto findValue = [&](const char* key) -> std::string {
        std::string searchKey = std::string("\"") + key + "\":";
        size_t pos = content.find(searchKey);
        if (pos == std::string::npos) return "";

        pos += searchKey.length();
        // Skip whitespace
        while (pos < content.length() && isspace(content[pos])) pos++;

        // Check if value is a string (quoted) or number
        if (content[pos] == '"') {
            pos++;  // Skip opening quote
            size_t end = content.find('"', pos);
            if (end == std::string::npos) return "";
            return content.substr(pos, end - pos);
        } else {
            // Number
            size_t end = pos;
            while (end < content.length() && (isdigit(content[end]) || content[end] == '.')) end++;
            return content.substr(pos, end - pos);
        }
    };

    work.parentHash = findValue("parent_hash");
    std::string heightStr = findValue("height");
    std::string difficultyStr = findValue("difficulty");
    work.merkle = findValue("merkle");

    if (work.parentHash.empty() || heightStr.empty() || difficultyStr.empty() || work.merkle.empty()) {
        fprintf(stderr, "Error: Invalid JSON format in test file\n");
        return false;
    }

    work.height = strtoull(heightStr.c_str(), nullptr, 10);
    work.difficulty = strtoull(difficultyStr.c_str(), nullptr, 10);
    work.nonce = 0;

    return true;
}

// Create test dump directory structure
bool createTestDumpDir(int roundNum) {
    if (!gTestDumpDir) return false;

    // Create main directory
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "mkdir -p \"%s/round_%d\"", gTestDumpDir, roundNum);
    if (system(cmd) != 0) {
        fprintf(stderr, "Error: Failed to create dump directory\n");
        return false;
    }

    return true;
}

//=============================================================================
// Main Function
//=============================================================================

int main(int argc, char** argv) {
    // Parse command-line arguments
    bool runBenchmark = false;
    static struct option longOptions[] = {
        {"url", required_argument, 0, 'u'},
        {"debug", no_argument, 0, 'd'},
        {"primorial", required_argument, 0, 'p'},
        {"sieve-size", required_argument, 0, 's'},
        {"weave-depth", required_argument, 0, 'w'},
        {"extensions-num", required_argument, 0, 'e'},
        {"prime-count", required_argument, 0, 'P'},
        {"benchmark", no_argument, 0, 'b'},
        {"test-dump", required_argument, 0, 'D'},
        {"test-json", required_argument, 0, 'J'},
        {"test-nonce", required_argument, 0, 'N'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    int c;
    while ((c = getopt_long(argc, argv, "u:dp:s:w:e:P:bh", longOptions, nullptr)) != -1) {
        switch (c) {
            case 'u': gWsUrl = optarg; break;
            case 'd': gDebug = 1; break;
            case 'p': gPrimorial = atoi(optarg); break;
            case 's': gSieveSize = atoi(optarg); break;
            case 'w': gWeaveDepth = atoi(optarg); break;
            case 'e': gExtensionsNum = atoi(optarg); break;
            case 'P': gPrimeCount = atoi(optarg); break;
            case 'b': runBenchmark = true; break;
            case 'D':
                gTestDumpDir = optarg;
                gTestMode = true;
                break;
            case 'J':
                gTestJsonFile = optarg;
                break;
            case 'N':
                gTestNonce = strtoull(optarg, nullptr, 10);
                break;
            case 'h':
                printf("XPMiner Metal - Primecoin miner for Apple Silicon\n\n");
                printf("Usage: xpmmetal [options]\n");
                printf("  -u, --url <url>             WebSocket URL (required for mining)\n");
                printf("  -d, --debug                 Enable debug output\n");
                printf("  -p, --primorial <n>         Primorial index (default: 19)\n");
                printf("  -s, --sieve-size <n>        Sieve size (default: 10)\n");
                printf("  -w, --weave-depth <n>       Weave depth (default: 8192)\n");
                printf("  -e, --extensions-num <n>    Extensions number (default: 9)\n");
                printf("  -P, --prime-count <n>       Prime count for sieving (default: 16384)\n");
                printf("                              Try: 8192, 16384, 32768, or 65536\n");
                printf("  -b, --benchmark             Run performance benchmarks to measure GPU speed\n");
                printf("      --test-dump <dir>       Enable test mode, dump checkpoints to <dir>\n");
                printf("      --test-json <file>      Load test JSON work from <file>\n");
                printf("      --test-nonce <n>        Starting nonce for test mode (default: 0)\n");
                printf("  -h, --help                  Show this help\n");
                return 0;
            default:
                fprintf(stderr, "Try 'xpmmetal --help' for more information.\n");
                return 1;
        }
    }

    // Test mode validation
    if (gTestMode) {
        if (!gTestJsonFile) {
            fprintf(stderr, "Error: --test-json required when using --test-dump\n");
            return 1;
        }
        // In test mode, URL is optional (we read from file)
    } else if (!runBenchmark && !gWsUrl) {
        fprintf(stderr, "Error: WebSocket URL required for mining\n");
        fprintf(stderr, "Usage: xpmmetal --url ws://host:port/path\n");
        fprintf(stderr, "   or: xpmmetal --benchmark (to run tests)\n");
        fprintf(stderr, "   or: xpmmetal --test-dump <dir> --test-json <file> (for debugging)\n");
        return 1;
    }

    @autoreleasepool {
        // Initialize logging (matches HIP setup at lines 1972-1978)
        loguru::init(argc, argv);
        loguru::g_stderr_verbosity = 1;  // Show LOG_F(1, ...) messages (important events like block found)
        if (gDebug) {
            loguru::g_stderr_verbosity = loguru::Verbosity_INFO;  // Show all LOG_F(INFO, ...) debug messages
        }

        // Get Metal device
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            LOG_F(ERROR, "Metal is not supported on this device");
            return 1;
        }

        LOG_F(INFO, "Using Metal device: %s", [device.name UTF8String]);
        LOG_F(INFO, "Recommended max working set size: %llu MB",
              device.recommendedMaxWorkingSetSize / (1024 * 1024));

        // Initialize prime tables
        LOG_F(INFO, "Generating prime tables...");
        generatePrimes(gPrimes, 96 * 1024);

        // Initialize gPrimes2 (prime + 1/prime pairs)
        int np = 96 * 1024;
        gPrimes2.resize(np * 2);
        for (int i = 0; i < np; ++i) {
            unsigned prime = gPrimes[i];
            float fiprime = 1.f / float(prime);
            gPrimes2[i * 2] = prime;
            memcpy(&gPrimes2[i * 2 + 1], &fiprime, sizeof(float));
        }

        LOG_F(INFO, "Prime tables generated");

        // If test mode, set up dump directory and load test work
        if (gTestMode) {
            LOG_F(INFO, "Test mode enabled");
            LOG_F(INFO, "  Dump directory: %s", gTestDumpDir);
            LOG_F(INFO, "  JSON file: %s", gTestJsonFile);
            LOG_F(INFO, "  Starting nonce: %llu", (unsigned long long)gTestNonce);

            // Create dump directory
            if (!createTestDumpDir(0)) {
                LOG_F(ERROR, "Failed to create dump directory");
                return 1;
            }

            LOG_F(INFO, "Test dump directory created: %s/round_0", gTestDumpDir);
        }

        // If benchmark mode, run benchmarks and exit
        if (runBenchmark) {
            LOG_F(INFO, "Running Metal benchmarks...");
            LOG_F(INFO, "Device: %s", [device.name UTF8String]);

            // Create miner instance for benchmarking
            PrimeMiner miner(0, 1, 4, 4, 1024);
            if (!miner.Initialize(device)) {
                LOG_F(ERROR, "Failed to initialize miner for benchmarking");
                return 1;
            }

            // Run comprehensive benchmarks
            runMetalBenchmarks(device, &miner);

            LOG_F(INFO, "Benchmarks complete.");
            return 0;
        }

        // Create getwork context (or use test work in test mode)
        GetWorkContext* getworkCtx = nullptr;

        if (!gTestMode) {
            LOG_F(INFO, "Connecting to %s", gWsUrl);
            getworkCtx = new GetWorkContext(nullptr, gWsUrl);
            getworkCtx->run();
        } else {
            LOG_F(INFO, "Test mode: Will use test JSON work from %s", gTestJsonFile);
        }

        // Create miner
        // depth=4 matches HIP miner (candidates that reach this depth go to CPU validation)
        // LSize will be auto-detected based on GPU family (1024 for Apple4+, 512 for Apple2/3)
        PrimeMiner miner(0, 1, 4, 4, 1024);
        if (!miner.Initialize(device)) {
            LOG_F(ERROR, "Failed to initialize miner");
            return 1;
        }

        // DEBUGGING: Pause before mining to allow debugger attachment
        if (gDebug) {
            LOG_F(INFO, "Miner initialized. Process ID: %d", getpid());
            LOG_F(INFO, "==============================================");
            LOG_F(INFO, "READY FOR DEBUGGING");
            LOG_F(INFO, "1. Attach Xcode debugger now (Debug -> Attach to Process)");
            LOG_F(INFO, "2. Or attach lldb: lldb -p %d", getpid());
            LOG_F(INFO, "3. Press ENTER to start mining...");
            LOG_F(INFO, "==============================================");
            getchar();
        }

        // Start mining
        LOG_F(INFO, "Starting mining...");
        miner.MiningGetWork(getworkCtx);
    }

    return 0;
}
