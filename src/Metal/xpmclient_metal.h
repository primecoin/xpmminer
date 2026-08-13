/*
 * xpmclient_metal.h
 *
 * XPMiner Metal implementation header
 * Ported from xpmclient_hip.h for Apple Silicon
 */

#ifndef XPMCLIENT_METAL_H_
#define XPMCLIENT_METAL_H_

#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include <gmp.h>
#include <gmpxx.h>
#include "getwork_client.h"
#include "metalutil.h"
#include "uint256.h"
#include "sha256.h"
#include "system.h"

#define FERMAT_PIPELINES 2

#define PW 512        // Pipeline width (number of hashes to store)
#define SW 16         // Maximum number of sieves in one iteration
#define MSO 128*1024  // Max sieve output
#define MFS 2*SW*MSO  // Max fermat size

const unsigned maxHashPrimorial = 16;

extern unsigned gPrimes[96*1024];
extern std::vector<unsigned> gPrimes2;

// Statistics structure
struct stats_t {
    unsigned id;
    unsigned errors;
    unsigned fps;
    double primeprob;
    double cpd;

    stats_t() {
        id = 0;
        errors = 0;
        fps = 0;
        primeprob = 0;
        cpd = 0;
    }
};

// Miner configuration structure
// Must match Metal shader struct in common.metal
struct config_t {
    uint32_t N;          // Number of hash limbs
    uint32_t SIZE;       // Sieve size
    uint32_t STRIPES;    // Number of sieve stripes
    uint32_t WIDTH;      // Chain width
    uint32_t PCOUNT;     // Prime count
    uint32_t TARGET;     // Target chain length
    uint32_t LIMIT13;    // 13-prime primorial limit
    uint32_t LIMIT14;    // 14-prime primorial limit
    uint32_t LIMIT15;    // 15-prime primorial limit
};

// Fermat test candidate structure
// Must match Metal shader struct in common.metal
struct fermat_t {
    uint32_t index;      // Multiplier index
    uint32_t hashid;     // Hash identifier
    uint8_t origin;      // Starting layer
    uint8_t chainpos;    // Position in chain
    uint8_t type;        // Chain type (0=Cunningham1, 1=Cunningham2, 2=BiTwin)
    uint8_t reserved;    // Padding
};

// Metal device information
struct MetalDeviceInfo {
    int index;
    id<MTLDevice> device;
    std::string name;
    uint64_t recommendedMaxWorkingSetSize;
    bool supportsAppleGPUFamily5;  // Apple GPU family 5+ (M1 and later)
};

// LIFO buffer template
template<typename T> class lifoBuffer {
private:
    T *_data;
    size_t _size;
    size_t _readPos;
    size_t _writePos;

    size_t nextPos(size_t pos) { return (pos + 1) % _size; }

public:
    lifoBuffer(size_t size) : _size(size), _readPos(0), _writePos(0) {
        _data = new T[size];
    }

    ~lifoBuffer() { delete[] _data; }

    size_t readPos() const { return _readPos; }
    size_t writePos() const { return _writePos; }
    T *data() const { return _data; }
    T& get(size_t index) const { return _data[index]; }

    bool empty() const {
        return _readPos == _writePos;
    }

    size_t remaining() const {
        return _writePos >= _readPos ?
            _writePos - _readPos :
            _size - (_readPos - _writePos);
    }

    void clear() {
        _readPos = _writePos;
    }

    size_t push(const T& element) {
        size_t oldWritePos = _writePos;
        size_t nextWritePos = nextPos(_writePos);
        if (nextWritePos != _readPos) {
            _data[_writePos] = element;
            _writePos = nextWritePos;
        }
        return oldWritePos;
    }

    size_t pop() {
        size_t oldReadPos = _readPos;
        if (!empty())
            _readPos = nextPos(_readPos);
        return oldReadPos;
    }
};

// Main PrimeMiner class
class PrimeMiner {
public:
    // Block header structure
    struct block_t {
        static const int CURRENT_VERSION = 2;

        int version;
        uint256 hashPrevBlock;
        uint256 hashMerkleRoot;
        unsigned int time;
        unsigned int bits;
        unsigned int nonce;
    };

    // Search state structure
    struct search_t {
        MetalBuffer<uint32_t> midstate;
        MetalBuffer<uint32_t> found;
        MetalBuffer<uint32_t> primorialBitField;
        MetalBuffer<uint32_t> count;
    };

    // Hash candidate structure
    struct hash_t {
        unsigned iter;
        uint64_t nonce;
        unsigned time;
        uint256 hash;
        mpz_class shash;
        mpz_class primorial;
        unsigned primorialIdx;
    };

    // Fermat test info structure
    struct info_t {
        MetalBuffer<fermat_t> info;
        MetalBuffer<uint32_t> count;
    };

    // Fermat pipeline structure
    struct pipeline_t {
        unsigned current;
        unsigned bsize;
        MetalBuffer<uint32_t> input;
        MetalBuffer<uint8_t> output;
        info_t buffer[2];
    };

    PrimeMiner(unsigned id, unsigned threads, unsigned sievePerRound,
               unsigned depth, unsigned LSize);
    ~PrimeMiner();

    bool Initialize(id<MTLDevice> device);
    config_t getConfig() { return mConfig; }

    bool MakeExit;
    void MiningGetWork(GetWorkContext* ctx);

    // Allow benchmark functions to access private members
    friend void runMetalBenchmarks(id<MTLDevice> device, PrimeMiner* miner);
    friend bool metalSieveEvaluate(PrimeMiner* miner, bool autoTune);
    friend void metalSievePerfBenchmark(PrimeMiner* miner);
    friend void metalSieveCheckBenchmark(PrimeMiner* miner);
    friend void metalHashmodBenchmark(PrimeMiner* miner);

private:
    void FermatInit(pipeline_t& fermat, unsigned mfs);
    void FermatDispatch(pipeline_t& fermat,
                        MetalBuffer<fermat_t> sieveBuffers[SW][FERMAT_PIPELINES][2],
                        MetalBuffer<uint32_t> candidatesCountBuffers[SW][2],
                        unsigned pipelineIdx,
                        int ridx,
                        int widx,
                        uint64_t& testCount,
                        uint64_t& fermatCount,
                        id<MTLComputePipelineState> fermatKernel,
                        unsigned sievePerRound);

    unsigned mID;
    unsigned mThreads;

    config_t mConfig;
    unsigned mSievePerRound;
    unsigned mBlockSize;
    uint32_t mDepth;
    unsigned mLSize;

    // Metal objects
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;

    // Compute pipeline states
    id<MTLComputePipelineState> _testKernelPipeline;    // Minimal test kernel
    id<MTLComputePipelineState> _jsonHashModPipeline;
    id<MTLComputePipelineState> _sieveSetupPipeline;
    id<MTLComputePipelineState> _sievePipeline;
    id<MTLComputePipelineState> _sieveDynamicPipeline;
    id<MTLComputePipelineState> _sieveSearchPipeline;
    id<MTLComputePipelineState> _fermatSetupPipeline;
    id<MTLComputePipelineState> _fermatKernel352Pipeline;
    id<MTLComputePipelineState> _fermatKernel320Pipeline;
    id<MTLComputePipelineState> _fermatCheckPipeline;
    id<MTLComputePipelineState> _fermatCheckSimdPipeline;

    // Benchmark pipeline states
    id<MTLComputePipelineState> _multiplyBenchmark320Pipeline;
    id<MTLComputePipelineState> _multiplyBenchmark352Pipeline;
    id<MTLComputePipelineState> _squareBenchmark320Pipeline;
    id<MTLComputePipelineState> _squareBenchmark352Pipeline;
    id<MTLComputePipelineState> _umulhiCorrectnessBenchmarkPipeline;
    id<MTLComputePipelineState> _umulhiThroughputBenchmarkPipeline;
    id<MTLComputePipelineState> _multiplySingle320BenchmarkPipeline;
    id<MTLComputePipelineState> _multiplySimdgroup320BenchmarkPipeline;

    // JSON getwork mode buffers
    MetalBuffer<uint32_t> mJsonMidstateBuf;         // JSON SHA256 midstate
    MetalBuffer<char> mJsonRemainingPrefixBuf;      // Remaining JSON prefix
    MetalBuffer<uint32_t> mJsonFoundBuf;            // Found nonces
    MetalBuffer<uint32_t> mJsonPrimorialBuf;        // Primorial bit fields
    MetalBuffer<uint32_t> mJsonCountBuf;            // Count of found candidates

    // Common buffers
    info_t final;
    MetalBuffer<uint32_t> hashBuf;

    // Sieve buffers
    MetalBuffer<uint32_t> mSieveBuf[2];         // Sieve data (double buffered)
    MetalBuffer<uint32_t> mSieveOff[2];         // Sieve offsets (double buffered)
    MetalBuffer<uint32_t> mPrimeBuf[maxHashPrimorial];    // Prime tables
    MetalBuffer<uint32_t> mPrimeBuf2[maxHashPrimorial];   // Prime tables (doubled)
    MetalBuffer<uint32_t> mModulosBuf[maxHashPrimorial];  // Modulo tables
    MetalBuffer<fermat_t> mSieveBuffers[SW][FERMAT_PIPELINES][2];  // Sieve output buffers
    MetalBuffer<uint32_t> mCandidatesCountBuffers[SW][2];  // Candidate count buffers

    // Fermat pipelines
    pipeline_t mFermat320;
    pipeline_t mFermat352;

    timeMark workBeginPoint;
    ::MineContext mineCtx;

    // ============================================================================
    // WORKAROUND FOR DUPLICATE SUBMISSION BUG - DO NOT DELETE THESE COMMENTS!
    // ============================================================================
    // ISSUE: Same candidate (same mpz_class value) gets submitted multiple times
    //        within milliseconds, causing duplicate share submissions to pool.
    //
    // EVIDENCE: Log shows identical candis[0] values submitted 3-4 times:
    //   candis[0] = 30112003849830760221162601293053920188671698466234131...
    //   Submitted at: 543.996s, 544.090s, 544.182s, 544.273s (0.3 second span)
    //
    // ROOT CAUSE (SUSPECTED):
    //   1. Fermat pipeline double-buffering may process same candidates twice
    //   2. Buffer wraparound in lifoBuffer might re-expose old candidates
    //   3. Race condition between fermat check and buffer management
    //   4. Lack of adaptive hash generation (NOW FIXED) caused hash starvation,
    //      leading to same hashes being reprocessed
    //
    // PROPER FIX NEEDED:
    //   - Debug fermat pipeline to find why candidates duplicate
    //   - Check buffer index management in FermatDispatch
    //   - Verify fermat output deduplication logic
    //   - Add candidate tracking in fermat pipeline
    //
    // WORKAROUND: Track last submitted candidate and skip if duplicate
    //   This is a BAND-AID, not a cure! Fix the root cause!
    // ============================================================================
    mpz_class mLastSubmittedCandidate;
    bool mHasLastSubmitted;
};

#endif /* XPMCLIENT_METAL_H_ */
