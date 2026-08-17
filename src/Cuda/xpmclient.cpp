/*
 * xpmclient.cpp
 *
 *  Created on: 01.05.2014
 *      Author: mad
 */

#include "xpmclient.h"
#include <getopt.h>
#include <sys/stat.h>
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <memory>
#include <set>
#include <sstream>
#include "benchmarks.h"
#include "primecoin.h"
#include "system.h"
#if defined(__GXX_EXPERIMENTAL_CXX0X__) && (__cplusplus < 201103L)
#define steady_clock monotonic_clock
#endif
#include <math.h>
#include <openssl/bn.h>
#include <openssl/sha.h>
#include <map>
#include "getblocktemplate.h"
#include "getwork_client.h"
#include "prime.h"

void _blkmk_bin2hex(char* out, void* data, size_t datasz) {
    unsigned char* datac = (unsigned char*)data;
    static char hex[] = "0123456789abcdef";
    out[datasz * 2] = '\0';
    for (size_t i = 0; i < datasz; ++i) {
        int j = datasz - 1 - i;
        out[j * 2] = hex[datac[i] >> 4];
        out[(j * 2) + 1] = hex[datac[i] & 15];
    }
}

unsigned gDebug = 0;
static bool gCudaAutoTune = true;
static bool gCudaRetune = false;
int gExtensionsNum = 9;
int gPrimorial = 19;
int gSieveSize = 10;
int gWeaveDepth = 8192;
int gThreadsNum = 1;
int extraNonce = 0;

// Experimental: Submit all chain types (Cunningham1, Cunningham2, BiTwin)
// instead of just BiTwin
static bool gSubmitAllChains = false;

static const char* gWallet = 0;
static const char* gUrl = "127.0.0.1:9912";
static const char* gUserName = 0;
static const char* gPassword = 0;
static const char* gProtocol =
    "getblocktemplate"; // default to existing behavior
static const char* gWsUrl = 0;

std::vector<unsigned> gPrimes2;

// JSON midstate data structure for getwork protocol
struct JsonMidstateData {
    uint32_t
        midstate[8]; // SHA256 state after processing first 128 bytes (2 blocks)
    char remainingPrefix[128]; // Remaining prefix bytes after first 128 bytes
    uint32_t remainingLen; // Length of remaining prefix
    uint32_t totalPrefixLen; // Total length of JSON prefix (for nonce padding
                             // calculation)
};

// Prepare JSON midstate for getwork protocol
// Computes SHA256 state after first 128 bytes of constant JSON prefix
void prepareJsonMidstate(const JsonWork& work, JsonMidstateData* data) {
    if (gDebug) {
        fprintf(stderr, "DEBUG: prepareJsonMidstate() called\n");
        fprintf(
            stderr,
            "DEBUG: parent_hash='%s', merkle='%s', height=%llu, difficulty=%llu\n",
            work.parentHash.c_str(),
            work.merkle.c_str(),
            (unsigned long long)work.height,
            (unsigned long long)work.difficulty);
    }

    // Build JSON prefix up to nonce value
    // Format: {"parent_hash": "0x...", "height": N, "difficulty": N, "merkle":
    // "0x...", "nonce":
    char prefix[256];
    if (gDebug)
        fprintf(stderr, "DEBUG: Calling snprintf...\n");
    int prefixLen = snprintf(
        prefix,
        sizeof(prefix),
        R"({"parent_hash": "%s", "height": %llu, "difficulty": %llu, "merkle": "%s", "nonce": )",
        work.parentHash.c_str(),
        (unsigned long long)work.height,
        (unsigned long long)work.difficulty,
        work.merkle.c_str());
    if (gDebug)
        fprintf(stderr, "DEBUG: snprintf returned prefixLen=%d\n", prefixLen);

    if (prefixLen < 0 || prefixLen >= (int)sizeof(prefix)) {
        LOG_F(ERROR, "JSON prefix too long: %d bytes", prefixLen);
        memset(data, 0, sizeof(JsonMidstateData));
        return;
    }

    data->totalPrefixLen = prefixLen;

    // Compute SHA256 midstate after first 128 bytes (2 complete SHA256 blocks)
    if (gDebug)
        fprintf(
            stderr, "DEBUG: Creating SHA_256 object and calling init()...\n");
    SHA_256 sha;
    sha.init();
    if (gDebug)
        fprintf(stderr, "DEBUG: SHA init done, prefixLen=%d\n", prefixLen);

    if (prefixLen >= 128) {
        if (gDebug)
            fprintf(stderr, "DEBUG: Calling sha.transform() for 2 blocks...\n");
        // Process first 2 blocks (128 bytes)
        sha.transform((const unsigned char*)prefix, 2);
        if (gDebug)
            fprintf(stderr, "DEBUG: sha.transform() completed\n");

        // Copy state to midstate
        for (int i = 0; i < 8; ++i)
            data->midstate[i] = sha.m_h[i];

        // Store remaining prefix (bytes 128+)
        data->remainingLen = prefixLen - 128;
        if (gDebug)
            fprintf(
                stderr,
                "DEBUG: Set remainingLen = %u (prefixLen=%d, 128 bytes processed)\n",
                data->remainingLen,
                prefixLen);
        memcpy(data->remainingPrefix, prefix + 128, data->remainingLen);
        if (gDebug)
            fprintf(
                stderr,
                "DEBUG: Copied %u bytes to remainingPrefix\n",
                data->remainingLen);
    } else {
        // Prefix is shorter than 128 bytes - just initialize midstate to IV
        // and store all prefix as "remaining"
        sha.init();
        for (int i = 0; i < 8; ++i)
            data->midstate[i] = sha.m_h[i];

        data->remainingLen = prefixLen;
        memcpy(data->remainingPrefix, prefix, prefixLen);
    }
    if (gDebug)
        fprintf(
            stderr, "DEBUG: prepareJsonMidstate() completed successfully\n");
}

double GetPrimeDifficulty(unsigned int nBits) {
    return ((double)nBits / (double)(1 << nFractionalBits));
}

PrimeMiner::PrimeMiner(
    unsigned id,
    unsigned threads,
    unsigned sievePerRound,
    unsigned depth,
    unsigned LSize) {
    mID = id;
    mThreads = threads;

    mSievePerRound = sievePerRound;
    mDepth = depth;
    mLSize = LSize;

    mBlockSize = 0;
    mConfig = {0};

    _context = 0;
    mHMFermatStream = 0;
    mSieveStream = 0;
    mHashMod = 0;
    mSieveSetup = 0;
    mSieve = 0;
    mSieveSearch = 0;
    mFermatSetup = 0;
    mFermatKernel352 = 0;
    mFermatKernel320 = 0;
    mFermatCheck = 0;

    MakeExit = false;
}

PrimeMiner::~PrimeMiner() {
    if (mSieveStream)
        cuStreamDestroy(mSieveStream);
    if (mHMFermatStream)
        cuStreamDestroy(mHMFermatStream);
}

bool PrimeMiner::Initialize(
    CUcontext context,
    CUdevice device,
    CUmodule module,
    bool reportConfiguration) {
    _context = context;
    cuCtxSetCurrent(context);

    // Lookup kernels by mangled name
    CUDA_SAFE_CALL(cuModuleGetFunction(
        &mHashMod, module, "_Z18bhashmodUsePrecalcjPjS_S_S_jjjjjjjjjjjj"));
    CUDA_SAFE_CALL(cuModuleGetFunction(
        &mSieveSetup, module, "_Z11setup_sievePjS_PKjS_jS_"));
    CUDA_SAFE_CALL(cuModuleGetFunction(&mSieve, module, "_Z5sievePjS_P5uint2"));
    CUDA_SAFE_CALL(cuModuleGetFunction(
        &mSieveSearch, module, "_Z7s_sievePKjS0_P8fermat_tS2_Pjjjj"));
    CUDA_SAFE_CALL(cuModuleGetFunction(
        &mFermatSetup, module, "_Z12setup_fermatPjPK8fermat_tS_"));
    CUDA_SAFE_CALL(cuModuleGetFunction(
        &mFermatKernel352, module, "_Z13fermat_kernelPhPKj"));
    CUDA_SAFE_CALL(cuModuleGetFunction(
        &mFermatKernel320, module, "_Z16fermat_kernel320PhPKj"));
    CUDA_SAFE_CALL(cuModuleGetFunction(
        &mFermatCheck, module, "_Z12check_fermatP8fermat_tPjS0_S1_PKhPKS_j"));

    // JSON getwork kernel - using extern "C" to avoid name mangling
    CUDA_SAFE_CALL(cuModuleGetFunction(&mJsonHashMod, module, "jsonHashMod"));

    CUDA_SAFE_CALL(cuStreamCreate(&mSieveStream, CU_STREAM_NON_BLOCKING));
    CUDA_SAFE_CALL(cuStreamCreate(&mHMFermatStream, CU_STREAM_NON_BLOCKING));

    // Get miner config
    {
        CUfunction getConfigKernel;
        CUDA_SAFE_CALL(cuModuleGetFunction(
            &getConfigKernel, module, "_Z9getconfigP8config_t"));

        cudaBuffer<config_t> config;
        CUDA_SAFE_CALL(config.init(1, false));
        void* args[] = {&config._deviceData};
        CUDA_SAFE_CALL(cuLaunchKernel(
            getConfigKernel, 1, 1, 1, 1, 1, 1, 0, NULL, args, 0));
        CUDA_SAFE_CALL(cuCtxSynchronize());
        CUDA_SAFE_CALL(config.copyToHost());
        mConfig = *config._hostData;
    }

    if (reportConfiguration) {
        LOG_F(
            INFO,
            "N=%d SIZE=%d STRIPES=%d WIDTH=%d PCOUNT=%d TARGET=%d",
            mConfig.N,
            mConfig.SIZE,
            mConfig.STRIPES,
            mConfig.WIDTH,
            mConfig.PCOUNT,
            mConfig.TARGET);
    }

    int computeUnits;
    CUDA_SAFE_CALL(cuDeviceGetAttribute(
        &computeUnits, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, device));
    mBlockSize = computeUnits * 4 * 64;
    if (reportConfiguration)
        LOG_F(INFO, "GPU %d: has %d CUs", mID, computeUnits);
    return true;
}

void PrimeMiner::FermatInit(pipeline_t& fermat, unsigned mfs) {
    fermat.current = 0;
    fermat.bsize = 0;
    CUDA_SAFE_CALL(fermat.input.init(mfs * mConfig.N, true));
    CUDA_SAFE_CALL(fermat.output.init(mfs, true));

    for (int i = 0; i < 2; ++i) {
        CUDA_SAFE_CALL(fermat.buffer[i].info.init(mfs, true));
        CUDA_SAFE_CALL(
            fermat.buffer[i].count.init(1, false)); // CL_MEM_ALLOC_HOST_PTR
    }
}

void PrimeMiner::FermatDispatch(
    pipeline_t& fermat,
    cudaBuffer<fermat_t> sieveBuffers[SW][FERMAT_PIPELINES][2],
    cudaBuffer<uint32_t> candidatesCountBuffers[SW][2],
    unsigned pipelineIdx,
    int ridx,
    int widx,
    uint64_t& testCount,
    uint64_t& fermatCount,
    CUfunction fermatKernel,
    unsigned sievePerRound) {
    // fermat dispatch
    {
        uint32_t& count = fermat.buffer[ridx].count[0];
        uint32_t left = fermat.buffer[widx].count[0] - fermat.bsize;
        if (left > 0) {
            cuMemcpyDtoDAsync(
                fermat.buffer[ridx].info._deviceData + count * sizeof(fermat_t),
                fermat.buffer[widx].info._deviceData +
                    fermat.bsize * sizeof(fermat_t),
                left * sizeof(fermat_t),
                mHMFermatStream);
            count += left;
        }

        for (int i = 0; i < sievePerRound; ++i) {
            uint32_t& avail = (candidatesCountBuffers[i][ridx])[pipelineIdx];
            if (avail) {
                cuMemcpyDtoDAsync(
                    fermat.buffer[ridx].info._deviceData +
                        count * sizeof(fermat_t),
                    sieveBuffers[i][pipelineIdx][ridx]._deviceData,
                    avail * sizeof(fermat_t),
                    mHMFermatStream);
                count += avail;
                testCount += avail;
                fermatCount += avail;
                avail = 0;
            }
        }

        fermat.buffer[widx].count[0] = 0;
        CUDA_SAFE_CALL(fermat.buffer[widx].count.copyToDevice(mHMFermatStream));

        fermat.bsize = 0;
        if (count > mBlockSize) {
            fermat.bsize = count - (count % mBlockSize);
            {
                // Fermat test setup
                void* arguments[] = {
                    &fermat.input._deviceData,
                    &fermat.buffer[ridx].info._deviceData,
                    &hashBuf._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mFermatSetup,
                    fermat.bsize / 256,
                    1,
                    1,
                    256,
                    1,
                    1,
                    0,
                    mHMFermatStream,
                    arguments,
                    0));
            }

            {
                // Fermat test
                void* arguments[] = {
                    &fermat.output._deviceData, &fermat.input._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    fermatKernel,
                    fermat.bsize / 64,
                    1,
                    1,
                    64,
                    1,
                    1,
                    0,
                    mHMFermatStream,
                    arguments,
                    0));
            }

            {
                // Fermat check
                void* arguments[] = {
                    &fermat.buffer[widx].info._deviceData,
                    &fermat.buffer[widx].count._deviceData,
                    &final.info._deviceData,
                    &final.count._deviceData,
                    &fermat.output._deviceData,
                    &fermat.buffer[ridx].info._deviceData,
                    &mDepth};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mFermatCheck,
                    fermat.bsize / 256,
                    1,
                    1,
                    256,
                    1,
                    1,
                    0,
                    mHMFermatStream,
                    arguments,
                    0));
            }

            //       fermat.buffer[widx].count.copyToHost(mBig);
        } else {
            // printf(" * warning: no enough candidates available (pipeline
            // %u)\n", pipelineIdx);
        }
        // printf("fermat: total of %d infos, bsize = %d\n", count,
        // fermat.bsize);
    }
}

void PrimeMiner::Mining(GetBlockTemplateContext* gbp, SubmitContext* submit) {
    cuCtxSetCurrent(_context);
    time_t starttime = time(0);
    unsigned int dataId;
    bool hasChanged;
    blktemplate_t* workTemplate = 0;
    MineContext mineCtx;

    stats_t stats;
    stats.id = mID;
    stats.errors = 0;
    stats.fps = 0;
    stats.primeprob = 0;
    stats.cpd = 0;

    // Initialize MineContext
    memset(&mineCtx, 0, sizeof(MineContext));
    double sieveSizeInGb = (double)(mConfig.SIZE * 32 * mConfig.STRIPES) /
        (1024.0 * 1024.0 * 1024.0);
    timeMark workBeginPoint = getTimeMark();

    const unsigned mPrimorial = 13;
    uint64_t fermatCount = 1;
    uint64_t primeCount = 1;

    time_t time1 = time(0);
    time_t time2 = time(0);
    uint64_t testCount = 0;

    unsigned iteration = 0;
    mpz_class primorial[maxHashPrimorial];
    block_t blockheader;
    search_t hashmod;
    sha256precalcData precalcData;

    lifoBuffer<hash_t> hashes(PW);
    cudaBuffer<uint32_t> sieveBuf[2];
    cudaBuffer<uint32_t> sieveOff[2];
    cudaBuffer<fermat_t> sieveBuffers[SW][FERMAT_PIPELINES][2];
    cudaBuffer<uint32_t> candidatesCountBuffers[SW][2];
    pipeline_t fermat320;
    pipeline_t fermat352;
    CPrimalityTestParamsCuda testParams;
    std::vector<fermat_t> candis;
    unsigned numHashCoeff = 32768;

    cudaBuffer<uint32_t> primeBuf[maxHashPrimorial];
    cudaBuffer<uint32_t> primeBuf2[maxHashPrimorial];

    CUevent sieveEvent;
    CUDA_SAFE_CALL(cuEventCreate(&sieveEvent, CU_EVENT_BLOCKING_SYNC));

    for (unsigned i = 0; i < maxHashPrimorial - mPrimorial; i++) {
        CUDA_SAFE_CALL(primeBuf[i].init(mConfig.PCOUNT, true));
        CUDA_SAFE_CALL(primeBuf[i].copyToDevice(&gPrimes[mPrimorial + i + 1]));
        CUDA_SAFE_CALL(primeBuf2[i].init(mConfig.PCOUNT * 2, true));
        CUDA_SAFE_CALL(
            primeBuf2[i].copyToDevice(&gPrimes2[2 * (mPrimorial + i) + 2]));
        mpz_class p = 1;
        for (unsigned j = 0; j <= mPrimorial + i; j++)
            p *= gPrimes[j];
        primorial[i] = p;
    }

    {
        unsigned primorialbits = mpz_sizeinbase(primorial[0].get_mpz_t(), 2);
        mpz_class sievesize = mConfig.SIZE * 32 * mConfig.STRIPES;
        unsigned sievebits = mpz_sizeinbase(sievesize.get_mpz_t(), 2);
        LOG_F(
            INFO,
            "GPU %d: primorial = %s (%d bits)",
            mID,
            primorial[0].get_str(10).c_str(),
            primorialbits);
        LOG_F(
            INFO,
            "GPU %d: sieve size = %s (%d bits)",
            mID,
            sievesize.get_str(10).c_str(),
            sievebits);
    }

    CUDA_SAFE_CALL(hashmod.midstate.init(8, false));
    CUDA_SAFE_CALL(hashmod.found.init(128, false));
    CUDA_SAFE_CALL(hashmod.primorialBitField.init(128, false));
    CUDA_SAFE_CALL(hashmod.count.init(1, false));
    CUDA_SAFE_CALL(hashBuf.init(PW * mConfig.N, false));

    for (int sieveIdx = 0; sieveIdx < SW; ++sieveIdx) {
        for (int instIdx = 0; instIdx < 2; ++instIdx) {
            for (int pipelineIdx = 0; pipelineIdx < FERMAT_PIPELINES;
                 pipelineIdx++)
                CUDA_SAFE_CALL(
                    sieveBuffers[sieveIdx][pipelineIdx][instIdx].init(
                        MSO, true));

            CUDA_SAFE_CALL(
                candidatesCountBuffers[sieveIdx][instIdx].init(
                    FERMAT_PIPELINES, false)); // CL_MEM_ALLOC_HOST_PTR
        }
    }

    for (int k = 0; k < 2; ++k) {
        CUDA_SAFE_CALL(
            sieveBuf[k].init(
                mConfig.SIZE * mConfig.STRIPES / 2 * mConfig.WIDTH, true));
        CUDA_SAFE_CALL(sieveOff[k].init(mConfig.PCOUNT * mConfig.WIDTH, true));
    }

    CUDA_SAFE_CALL(
        final.info.init(MFS / (4 * mDepth), false)); // CL_MEM_ALLOC_HOST_PTR
    CUDA_SAFE_CALL(final.count.init(1, false)); // CL_MEM_ALLOC_HOST_PTR

    FermatInit(fermat320, MFS);
    FermatInit(fermat352, MFS);

    cudaBuffer<uint32_t> modulosBuf[maxHashPrimorial];
    unsigned modulosBufferSize = mConfig.PCOUNT * (mConfig.N - 1);
    for (unsigned bufIdx = 0; bufIdx < maxHashPrimorial - mPrimorial;
         bufIdx++) {
        cudaBuffer<uint32_t>& current = modulosBuf[bufIdx];
        CUDA_SAFE_CALL(current.init(modulosBufferSize, false));
        for (unsigned i = 0; i < mConfig.PCOUNT; i++) {
            mpz_class X = 1;
            for (unsigned j = 0; j < mConfig.N - 1; j++) {
                X <<= 32;
                mpz_class mod = X % gPrimes[i + mPrimorial + bufIdx + 1];
                current[mConfig.PCOUNT * j + i] = mod.get_ui();
            }
        }

        CUDA_SAFE_CALL(current.copyToDevice());
    }

    int loadworkaccount = 0;
    bool run = true;
    while (run) {
        {
            time_t currtime = time(0);
            time_t elapsed = currtime - time1;
            if (elapsed > 11) {
                time1 = currtime;
            }

            elapsed = currtime - time2;
            if (elapsed > 15) {
                stats.fps = testCount / elapsed;
                time2 = currtime;
                testCount = 0;
            }
        }

        stats.primeprob =
            pow(double(primeCount) / double(fermatCount), 1. / mDepth) -
            0.0003 *
                (double(mConfig.TARGET - 1) / 2. - double(mDepth - 1) / 2.);
        stats.cpd = 24. * 3600. * double(stats.fps) *
            pow(stats.primeprob, mConfig.TARGET);

        // get work
        bool reset = false;
        {
            while (!(
                workTemplate = gbp->get(0, workTemplate, &dataId, &hasChanged)))
                usleep(100);
            if (workTemplate && hasChanged) {
                run = true; // ReceivePub(work, worksub);
                reset = true;
            }
        }
        if (!run)
            break;

        // reset if new work
        if (reset) {
            hashes.clear();
            hashmod.count[0] = 0;
            fermat320.bsize = 0;
            fermat320.buffer[0].count[0] = 0;
            fermat320.buffer[1].count[0] = 0;
            fermat352.bsize = 0;
            fermat352.buffer[0].count[0] = 0;
            fermat352.buffer[1].count[0] = 0;
            final.count[0] = 0;

            for (int sieveIdx = 0; sieveIdx < SW; ++sieveIdx) {
                for (int instIdx = 0; instIdx < 2; ++instIdx) {
                    for (int pipelineIdx = 0; pipelineIdx < FERMAT_PIPELINES;
                         pipelineIdx++)
                        (candidatesCountBuffers[sieveIdx]
                                               [instIdx])[pipelineIdx] = 0;
                }
            }

            printf("version is %u\n", workTemplate->version);
            blockheader.version = workTemplate->version;
            char blkhex[128];
            _blkmk_bin2hex(blkhex, workTemplate->prevblk, 32);
            blockheader.hashPrevBlock.SetHex(blkhex);
            _blkmk_bin2hex(blkhex, workTemplate->_mrklroot, 32);
            blockheader.hashMerkleRoot.SetHex(blkhex);
            blockheader.time = workTemplate->curtime;
            blockheader.bits = *(uint32_t*)workTemplate->diffbits;
            blockheader.nonce = 1;
            testParams.nBits = blockheader.bits;

            unsigned target = TargetGetLength(blockheader.bits);
            precalcSHA256(
                &blockheader, hashmod.midstate._hostData, &precalcData);
            hashmod.count[0] = 0;
            CUDA_SAFE_CALL(hashmod.midstate.copyToDevice(mHMFermatStream));
            CUDA_SAFE_CALL(hashmod.count.copyToDevice(mHMFermatStream));
        }

        // hashmod fetch & dispatch
        {
            fflush(stdout);
            for (unsigned i = 0; i < hashmod.count[0]; ++i) {
                hash_t hash;
                hash.iter = iteration;
                hash.time = blockheader.time;
                hash.nonce = hashmod.found[i];
                uint32_t primorialBitField = hashmod.primorialBitField[i];
                uint32_t primorialIdx = primorialBitField >> 16;
                uint64_t realPrimorial = 1;
                for (unsigned j = 0; j < primorialIdx + 1; j++) {
                    if (primorialBitField & (1 << j))
                        realPrimorial *= gPrimes[j];
                }

                mpz_class mpzRealPrimorial;
                mpz_import(
                    mpzRealPrimorial.get_mpz_t(),
                    2,
                    -1,
                    4,
                    0,
                    0,
                    &realPrimorial);
                primorialIdx = std::max(mPrimorial, primorialIdx) - mPrimorial;
                mpz_class mpzHashMultiplier =
                    primorial[primorialIdx] / mpzRealPrimorial;
                unsigned hashMultiplierSize =
                    mpz_sizeinbase(mpzHashMultiplier.get_mpz_t(), 2);
                mpz_import(
                    mpzRealPrimorial.get_mpz_t(),
                    2,
                    -1,
                    4,
                    0,
                    0,
                    &realPrimorial);

                block_t b = blockheader;
                b.nonce = hash.nonce;

                SHA_256 sha;
                sha.init();
                sha.update((const unsigned char*)&b, sizeof(b));
                sha.final((unsigned char*)&hash.hash);
                sha.init();
                sha.update((const unsigned char*)&hash.hash, sizeof(uint256));
                sha.final((unsigned char*)&hash.hash);

                if (hash.hash < (uint256(1) << 255)) {
                    LOG_F(WARNING, "hash does not meet minimum.\n");
                    stats.errors++;
                    continue;
                }

                mpz_class mpzHash;
                mpz_set_uint256(mpzHash.get_mpz_t(), hash.hash);
                if (!mpz_divisible_p(
                        mpzHash.get_mpz_t(), mpzRealPrimorial.get_mpz_t())) {
                    LOG_F(WARNING, "mpz_divisible_ui_p failed.\n");
                    stats.errors++;
                    continue;
                }

                hash.primorialIdx = primorialIdx;
                hash.primorial = mpzHashMultiplier;
                hash.shash = mpzHash * hash.primorial;

                unsigned hid = hashes.push(hash);
                memset(
                    &hashBuf[hid * mConfig.N], 0, sizeof(uint32_t) * mConfig.N);
                mpz_export(
                    &hashBuf[hid * mConfig.N],
                    0,
                    -1,
                    4,
                    0,
                    0,
                    hashes.get(hid).shash.get_mpz_t());
            }

            if (hashmod.count[0])
                CUDA_SAFE_CALL(hashBuf.copyToDevice(mSieveStream));

            hashmod.count[0] = 0;

            int numhash =
                ((int)(16 * mSievePerRound) - (int)hashes.remaining()) *
                numHashCoeff;

            if (numhash > 0) {
                numhash += mLSize - numhash % mLSize;
                if (blockheader.nonce > (1u << 31)) {
                    blockheader.time += mThreads;
                    blockheader.nonce = 1;
                    precalcSHA256(
                        &blockheader, hashmod.midstate._hostData, &precalcData);
                }

                CUDA_SAFE_CALL(hashmod.midstate.copyToDevice(mHMFermatStream));
                CUDA_SAFE_CALL(hashmod.count.copyToDevice(mHMFermatStream));

                void* arguments[] = {
                    &blockheader.nonce,
                    &hashmod.found._deviceData,
                    &hashmod.count._deviceData,
                    &hashmod.primorialBitField._deviceData,
                    &hashmod.midstate._deviceData,
                    &precalcData.merkle,
                    &precalcData.time,
                    &precalcData.nbits,
                    &precalcData.W0,
                    &precalcData.W1,
                    &precalcData.new1_0,
                    &precalcData.new1_1,
                    &precalcData.new1_2,
                    &precalcData.new2_0,
                    &precalcData.new2_1,
                    &precalcData.new2_2,
                    &precalcData.temp2_3};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mHashMod,
                    numhash / mLSize,
                    1,
                    1,
                    mLSize,
                    1,
                    1,
                    0,
                    mHMFermatStream,
                    arguments,
                    0));

                blockheader.nonce += numhash;
            }
        }

        int ridx = iteration % 2;
        int widx = ridx xor 1;

        // sieve dispatch
        for (unsigned i = 0; i < mSievePerRound; i++) {
            if (hashes.empty()) {
                if (!reset) {
                    numHashCoeff += 32768;
                    LOG_F(
                        WARNING,
                        "ran out of hashes, increasing sha256 work size coefficient to %u",
                        numHashCoeff);
                }
                break;
            }

            int hid = hashes.pop();
            unsigned primorialIdx = hashes.get(hid).primorialIdx;

            CUDA_SAFE_CALL(
                candidatesCountBuffers[i][widx].copyToDevice(mSieveStream));

            {
                void* arguments[] = {
                    &sieveOff[0]._deviceData,
                    &sieveOff[1]._deviceData,
                    &primeBuf[primorialIdx]._deviceData,
                    &hashBuf._deviceData,
                    &hid,
                    &modulosBuf[primorialIdx]._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieveSetup,
                    mConfig.PCOUNT / mLSize,
                    1,
                    1,
                    mLSize,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));
            }

            {
                void* arguments[] = {
                    &sieveBuf[0]._deviceData,
                    &sieveOff[0]._deviceData,
                    &primeBuf2[primorialIdx]._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieve,
                    mConfig.STRIPES / 2,
                    mConfig.WIDTH,
                    1,
                    mLSize,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));
            }

            {
                void* arguments[] = {
                    &sieveBuf[1]._deviceData,
                    &sieveOff[1]._deviceData,
                    &primeBuf2[primorialIdx]._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieve,
                    mConfig.STRIPES / 2,
                    mConfig.WIDTH,
                    1,
                    mLSize,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));
            }

            {
                uint32_t multiplierSize =
                    mpz_sizeinbase(hashes.get(hid).shash.get_mpz_t(), 2);
                void* arguments[] = {
                    &sieveBuf[0]._deviceData,
                    &sieveBuf[1]._deviceData,
                    &sieveBuffers[i][0][widx]._deviceData,
                    &sieveBuffers[i][1][widx]._deviceData,
                    &candidatesCountBuffers[i][widx]._deviceData,
                    &hid,
                    &multiplierSize,
                    &mDepth};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieveSearch,
                    (mConfig.SIZE * mConfig.STRIPES / 2) / 256,
                    1,
                    1,
                    256,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));

                CUDA_SAFE_CALL(cuEventRecord(sieveEvent, mSieveStream));
            }
        }

        // get candis
        int numcandis = final.count[0];
        numcandis = std::min(numcandis, (int) final.info._size);
        numcandis = std::max(numcandis, 0);
        candis.resize(numcandis);
        primeCount += numcandis;
        if (numcandis)
            memcpy(
                &candis[0], final.info._hostData, numcandis * sizeof(fermat_t));

        final.count[0] = 0;
        CUDA_SAFE_CALL(final.count.copyToDevice(mHMFermatStream));
        FermatDispatch(
            fermat320,
            sieveBuffers,
            candidatesCountBuffers,
            0,
            ridx,
            widx,
            testCount,
            fermatCount,
            mFermatKernel320,
            mSievePerRound);
        FermatDispatch(
            fermat352,
            sieveBuffers,
            candidatesCountBuffers,
            1,
            ridx,
            widx,
            testCount,
            fermatCount,
            mFermatKernel352,
            mSievePerRound);

        // copyToHost (cuMemcpyDtoHAsync) always blocking sync call!
        // syncronize our stream one time per iteration
        // sieve stream is first because it much bigger
        CUDA_SAFE_CALL(cuEventSynchronize(sieveEvent));
#ifdef __WINDOWS__
        CUDA_SAFE_CALL(cuCtxSynchronize());
#endif
        for (unsigned i = 0; i < mSievePerRound; i++)
            CUDA_SAFE_CALL(
                candidatesCountBuffers[i][widx].copyToHost(mSieveStream));

        // Synchronize Fermat stream, copy all needed data
        CUDA_SAFE_CALL(hashmod.found.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(hashmod.primorialBitField.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(hashmod.count.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(
            fermat320.buffer[widx].count.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(
            fermat352.buffer[widx].count.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(final.info.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(final.count.copyToHost(mHMFermatStream));

        // adjust sieves per round
        if (fermat320.buffer[ridx].count[0] &&
            fermat320.buffer[ridx].count[0] < mBlockSize &&
            fermat352.buffer[ridx].count[0] &&
            fermat352.buffer[ridx].count[0] < mBlockSize) {
            mSievePerRound = std::min((unsigned)SW, mSievePerRound + 1);
            LOG_F(
                WARNING,
                "not enough candidates (%u available, must be more than %u",
                std::max(
                    fermat320.buffer[ridx].count[0],
                    fermat352.buffer[ridx].count[0]),
                mBlockSize);

            LOG_F(WARNING, "increase sieves per round to %u", mSievePerRound);
        }

        // check candis
        if (candis.size()) {
            mpz_class nOrigin;
            mpz_class multi;
            for (unsigned i = 0; i < candis.size(); ++i) {
                fermat_t& candi = candis[i];
                hash_t& hash = hashes.get(candi.hashid);

                unsigned age = iteration - hash.iter;
                if (age > PW / 2)
                    LOG_F(WARNING, "candidate age > PW/2 with %d", age);

                multi = candi.index;
                multi <<= candi.origin;
                nOrigin = hash.shash;
                nOrigin *= multi;

                testParams.nCandidateType =
                    candi.type + 1; // nCandidateType must follow chain type
                                    // convention of node
                bool isblock =
                    ProbablePrimeChainTestFastCuda(nOrigin, testParams, mDepth);
                unsigned chainlength = TargetGetLength(testParams.nChainLength);

                // Update chain stats for all found chains
                if (chainlength > 0) {
                    // Update stats for the found chain and all shorter ones
                    for (unsigned k = 1; k < chainlength; k++) {
                        mineCtx.foundChains[k]++;
                    }
                    mineCtx.foundChains[chainlength]++;
                }

                while (multi % 2 == 0 && nOrigin % 4 == 0) {
                    mpz_class nOriginNormalize = nOrigin / 2;
                    CPrimalityTestParamsCuda testParamsNormalize = testParams;

                    if (ProbablePrimeChainTestFastCuda(
                            nOriginNormalize, testParamsNormalize, mDepth)) {
                        if ((testParams.nCandidateType == 1 &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize - 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false)) ||
                            (testParams.nCandidateType == 2 &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize + 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false)) ||
                            (testParams.nCandidateType == 3 &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize - 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false) &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize + 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false))) {
                            unsigned chainlengthNormalize = TargetGetLength(
                                testParamsNormalize.nChainLength);
                            if (chainlengthNormalize > chainlength) {
                                multi /= 2;
                                nOrigin = nOriginNormalize;
                                chainlength = chainlengthNormalize;
                                testParams = testParamsNormalize;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }
                ProbablePrimeChainTestFastCuda(nOrigin, testParams, mDepth);
                if (testParams.nChainLength >= blockheader.bits) {
                    printf(
                        "\ncandis[%d] = %s\n", i, nOrigin.get_str(10).c_str());
                    PrimecoinBlockHeader work;
                    work.version = blockheader.version;
                    char blkhex[128];
                    _blkmk_bin2hex(blkhex, workTemplate->prevblk, 32);
                    memcpy(work.hashPrevBlock, workTemplate->prevblk, 32);
                    memcpy(work.hashMerkleRoot, workTemplate->_mrklroot, 32);
                    work.time = hash.time;
                    work.bits = blockheader.bits;
                    work.nonce = hash.nonce;
                    uint8_t buffer[256];
                    BIGNUM* xxx = 0;
                    mpz_class targetMultiplier = hash.primorial * multi;
                    BN_dec2bn(&xxx, targetMultiplier.get_str().c_str());
                    BN_bn2mpi(xxx, buffer);
                    work.multiplier[0] = buffer[3];
                    std::reverse_copy(
                        buffer + 4,
                        buffer + 4 + buffer[3],
                        work.multiplier + 1);
                    submit->submitBlock(workTemplate, work, dataId);
                    std::string chainName = GetPrimeChainName(
                        testParams.nCandidateType, testParams.nChainLength);
                    LOG_F(1, "GPU %d found share: %s", mID, chainName.c_str());
                    if (isblock) {
                        LOG_F(1, "GPU %d found BLocK!", mID);
                        std::string nbitsTarget =
                            TargetToString(testParams.nBits);
                        LOG_F(1, "Found chain:%s", chainName.c_str());
                        LOG_F(
                            1,
                            "Target (nbits):%s\n----------------------------------------------------------------------",
                            nbitsTarget.c_str());
                    }
                } else if (chainlength < mDepth) {
                    LOG_F(
                        WARNING,
                        "ProbablePrimeChainTestFast %ubits %d/%d",
                        (unsigned)mpz_sizeinbase(nOrigin.get_mpz_t(), 2),
                        chainlength,
                        mDepth);
                    LOG_F(WARNING, "origin: %s", nOrigin.get_str().c_str());
                    LOG_F(WARNING, "type: %u", (unsigned)candi.type);
                    LOG_F(WARNING, "multiplier: %u", (unsigned)candi.index);
                    LOG_F(WARNING, "layer: %u", (unsigned)candi.origin);
                    LOG_F(
                        WARNING,
                        "hash primorial: %s",
                        hash.primorial.get_str().c_str());
                    LOG_F(WARNING, "primorial multipliers: ");
                    for (unsigned i = 0; i < mPrimorial;) {
                        if (hash.primorial % gPrimes[i] == 0) {
                            hash.primorial /= gPrimes[i];
                            LOG_F(WARNING, " * [%u]%u", i + 1, gPrimes[i]);
                        } else {
                            i++;
                        }
                    }
                    stats.errors++;
                }
            }
        }

        // Update mining stats
        mineCtx.speed = (double)testCount / 1000000.0; // Convert to millions
        mineCtx.totalRoundsNum++;

        // Print mining stats
        MineContext* mineCtxArray =
            &mineCtx; // Create a pointer to our single MineContext
        printMiningStats(
            workBeginPoint,
            mineCtxArray,
            1,
            sieveSizeInGb,
            workTemplate ? workTemplate->height : 0,
            GetPrimeDifficulty(blockheader.bits),
            4);

        if (MakeExit)
            break;

        iteration++;
    }

    LOG_F(INFO, "GPU %d stopped.", mID);
}

MiningBenchmarkResult PrimeMiner::MiningGetWork(
    GetWorkContext* ctx,
    unsigned benchmarkSeconds,
    bool reportBenchmarkResults) {
    MiningBenchmarkResult benchmarkResult;
    cuCtxSetCurrent(_context);
    const bool benchmarkMode = benchmarkSeconds > 0;
    time_t starttime = time(0);
    JsonWork currentWork;
    bool hasChanged;
    MineContext mineCtx;

    stats_t stats;
    stats.id = mID;
    stats.errors = 0;
    stats.fps = 0;
    stats.primeprob = 0;
    stats.cpd = 0;

    // Initialize MineContext
    memset(&mineCtx, 0, sizeof(MineContext));
    double sieveSizeInGb = (double)(mConfig.SIZE * 32 * mConfig.STRIPES) /
        (1024.0 * 1024.0 * 1024.0);
    timeMark workBeginPoint = getTimeMark();

    const unsigned mPrimorial = 13;
    uint64_t fermatCount = 1;
    uint64_t primeCount = 1;

    time_t time1 = time(0);
    time_t time2 = time(0);
    time_t timeValidationLog = time(0); // For periodic validation logging
    uint64_t testCount = 0;
    uint64_t roundWorkId = 0; // Track work ID to detect stale work
    uint64_t benchmarkHashesDispatched = 0;
    uint64_t benchmarkGpuMatches = 0;
    uint64_t benchmarkMatchesRetained = 0;
    uint64_t benchmarkValidHashes = 0;
    uint64_t benchmarkSieveJobs = 0;
    uint64_t benchmarkSieveCandidates = 0;
    uint64_t benchmarkFinalCandidates = 0;
    uint64_t benchmarkCpuCandidates = 0;
    uint64_t benchmarkShares = 0;
    uint64_t benchmarkHashStarvations = 0;
    uint64_t benchmarkPipelineErrors = 0;
    std::chrono::steady_clock::time_point benchmarkStart;

    unsigned iteration = 0;
    mpz_class primorial[maxHashPrimorial];
    search_t hashmod;

    lifoBuffer<hash_t> hashes(PW);
    cudaBuffer<uint32_t> sieveBuf[2];
    cudaBuffer<uint32_t> sieveOff[2];
    cudaBuffer<fermat_t> sieveBuffers[SW][FERMAT_PIPELINES][2];
    cudaBuffer<uint32_t> candidatesCountBuffers[SW][2];
    pipeline_t fermat320;
    pipeline_t fermat352;
    CPrimalityTestParamsCuda testParams;
    std::vector<fermat_t> candis;
    unsigned numHashCoeff = 32768;

    cudaBuffer<uint32_t> primeBuf[maxHashPrimorial];
    cudaBuffer<uint32_t> primeBuf2[maxHashPrimorial];

    CUevent sieveEvent;
    CUDA_SAFE_CALL(cuEventCreate(&sieveEvent, CU_EVENT_BLOCKING_SYNC));

    for (unsigned i = 0; i < maxHashPrimorial - mPrimorial; i++) {
        CUDA_SAFE_CALL(primeBuf[i].init(mConfig.PCOUNT, true));
        CUDA_SAFE_CALL(primeBuf[i].copyToDevice(&gPrimes[mPrimorial + i + 1]));
        CUDA_SAFE_CALL(primeBuf2[i].init(mConfig.PCOUNT * 2, true));
        CUDA_SAFE_CALL(
            primeBuf2[i].copyToDevice(&gPrimes2[2 * (mPrimorial + i) + 2]));
        mpz_class p = 1;
        for (unsigned j = 0; j <= mPrimorial + i; j++)
            p *= gPrimes[j];
        primorial[i] = p;
    }

    {
        unsigned primorialbits = mpz_sizeinbase(primorial[0].get_mpz_t(), 2);
        mpz_class sievesize = mConfig.SIZE * 32 * mConfig.STRIPES;
        unsigned sievebits = mpz_sizeinbase(sievesize.get_mpz_t(), 2);
        LOG_F(
            INFO,
            "GPU %d: primorial = %s (%d bits)",
            mID,
            primorial[0].get_str(10).c_str(),
            primorialbits);
        LOG_F(
            INFO,
            "GPU %d: sieve size = %s (%d bits)",
            mID,
            sievesize.get_str(10).c_str(),
            sievebits);
    }

    if (gDebug)
        fprintf(stderr, "DEBUG: Initializing hashmod buffers...\n");
    CUDA_SAFE_CALL(hashmod.midstate.init(8, false));
    CUDA_SAFE_CALL(hashmod.found.init(128, false));
    CUDA_SAFE_CALL(hashmod.primorialBitField.init(128, false));
    CUDA_SAFE_CALL(hashmod.count.init(1, false));
    if (gDebug)
        fprintf(stderr, "DEBUG: hashmod buffers initialized successfully\n");
    CUDA_SAFE_CALL(hashBuf.init(PW * mConfig.N, false));

    for (int sieveIdx = 0; sieveIdx < SW; ++sieveIdx) {
        for (int instIdx = 0; instIdx < 2; ++instIdx) {
            for (int pipelineIdx = 0; pipelineIdx < FERMAT_PIPELINES;
                 pipelineIdx++)
                CUDA_SAFE_CALL(
                    sieveBuffers[sieveIdx][pipelineIdx][instIdx].init(
                        MSO, true));

            CUDA_SAFE_CALL(
                candidatesCountBuffers[sieveIdx][instIdx].init(
                    FERMAT_PIPELINES, false));
        }
    }

    for (int k = 0; k < 2; ++k) {
        CUDA_SAFE_CALL(
            sieveBuf[k].init(
                mConfig.SIZE * mConfig.STRIPES / 2 * mConfig.WIDTH, true));
        CUDA_SAFE_CALL(sieveOff[k].init(mConfig.PCOUNT * mConfig.WIDTH, true));
    }

    CUDA_SAFE_CALL(final.info.init(MFS / (4 * mDepth), false));
    CUDA_SAFE_CALL(final.count.init(1, false));

    FermatInit(fermat320, MFS);
    FermatInit(fermat352, MFS);

    cudaBuffer<uint32_t> modulosBuf[maxHashPrimorial];
    unsigned modulosBufferSize = mConfig.PCOUNT * (mConfig.N - 1);
    for (unsigned bufIdx = 0; bufIdx < maxHashPrimorial - mPrimorial;
         bufIdx++) {
        cudaBuffer<uint32_t>& current = modulosBuf[bufIdx];
        CUDA_SAFE_CALL(current.init(modulosBufferSize, false));
        for (unsigned i = 0; i < mConfig.PCOUNT; i++) {
            mpz_class X = 1;
            for (unsigned j = 0; j < mConfig.N - 1; j++) {
                X <<= 32;
                mpz_class mod = X % gPrimes[i + mPrimorial + bufIdx + 1];
                current[mConfig.PCOUNT * j + i] = mod.get_ui();
            }
        }

        CUDA_SAFE_CALL(current.copyToDevice());
    }

    int loadworkaccount = 0;
    bool run = true;
    JsonMidstateData midstateData; // Store midstate data for current work
    memset(&midstateData, 0, sizeof(JsonMidstateData)); // Initialize to zeros
    uint64_t nonce = 0; // Nonce counter for JSON hash generation

    // Initialize JSON getwork mode buffers
    CUDA_SAFE_CALL(mJsonMidstateBuf.init(8, false));
    CUDA_SAFE_CALL(mJsonRemainingPrefixBuf.init(128, false));
    CUDA_SAFE_CALL(mJsonFoundBuf.init(128, false));
    CUDA_SAFE_CALL(mJsonPrimorialBuf.init(128, false));
    CUDA_SAFE_CALL(mJsonCountBuf.init(1, false));

    LOG_F(INFO, "GPU %d: Starting getwork mining loop", mID);

    if (benchmarkMode) {
        currentWork.parentHash =
            "0x38929713c8e87a2ec3bfded09d579788617788b5abacbe42c80161d8c1ebe22f";
        currentWork.height = 3058000;
        currentWork.difficulty = 10ull << 24;
        currentWork.merkle =
            "0x96cc5fa7338faeff2371f7216b0d14b11197105730ea8df9dc75b17a730d4db4";
        currentWork.nonce = 0;
        benchmarkStart = std::chrono::steady_clock::now();
        LOG_F(
            INFO,
            "GPU %d: Starting %u-second end-to-end getwork benchmark "
            "(deterministic work, network and submission excluded)",
            mID,
            benchmarkSeconds);
    }

    while (run) {
        {
            time_t currtime = time(0);
            time_t elapsed = currtime - time1;
            if (elapsed > 11) {
                time1 = currtime;
            }

            elapsed = currtime - time2;
            if (elapsed > 15) {
                stats.fps = testCount / elapsed;
                time2 = currtime;
                testCount = 0;
            }
        }

        stats.primeprob =
            pow(double(primeCount) / double(fermatCount), 1. / mDepth) -
            0.0003 *
                (double(mConfig.TARGET - 1) / 2. - double(mDepth - 1) / 2.);
        stats.cpd = 24. * 3600. * double(stats.fps) *
            pow(stats.primeprob, mConfig.TARGET);

        // Get work from WebSocket context, or reset deterministic benchmark
        // work on its first iteration.
        bool reset = benchmarkMode && iteration == 0;
        if (!benchmarkMode) {
            // Try to get work, but don't loop forever if disconnected
            int attempts = 0;
            static bool disconnectLogged =
                false; // Track if we've logged disconnection
            while (!ctx->get(mID, &currentWork, &hasChanged)) {
                usleep(100000); // 100ms
                attempts++;
                // Check connection every second
                if (attempts >= 10) {
                    if (!ctx->isConnected()) {
                        // Only log once when disconnected, not every 2 seconds
                        if (!disconnectLogged) {
                            LOG_F(
                                WARNING,
                                "GPU %d: Disconnected from server, waiting for reconnection...",
                                mID);
                            disconnectLogged = true;
                        }
                        attempts = 0;
                        usleep(1000000); // Wait 1 second before retrying
                    } else {
                        attempts = 0; // Reset counter if still connected
                        disconnectLogged = false; // Reset flag when reconnected
                    }
                }
            }

            if (currentWork.isValid() && hasChanged) {
                run = true;
                reset = true;
                roundWorkId = ctx->getWorkId(); // Store work ID for this round
            }
        }

        if (!run)
            break;

        // Reset state on new work
        if (reset) {
            hashes.clear();
            hashmod.count[0] = 0;
            nonce = 0; // Reset nonce counter for new work
            fermat320.bsize = 0;
            fermat320.buffer[0].count[0] = 0;
            fermat320.buffer[1].count[0] = 0;
            fermat352.bsize = 0;
            fermat352.buffer[0].count[0] = 0;
            fermat352.buffer[1].count[0] = 0;
            final.count[0] = 0;

            for (int sieveIdx = 0; sieveIdx < SW; ++sieveIdx) {
                for (int instIdx = 0; instIdx < 2; ++instIdx) {
                    for (int pipelineIdx = 0; pipelineIdx < FERMAT_PIPELINES;
                         pipelineIdx++)
                        (candidatesCountBuffers[sieveIdx]
                                               [instIdx])[pipelineIdx] = 0;
                }
            }

            // Set difficulty target from work
            testParams.nBits = currentWork.difficulty;
            unsigned target = TargetGetLength(currentWork.difficulty);

            // Decode difficulty: chain_length + fractional
            double decodedDifficulty = (currentWork.difficulty >> 24) +
                ((currentWork.difficulty & 0xFFFFFF) / (double)(1 << 24));

            LOG_F(
                INFO,
                "GPU %d: New work - height %llu, difficulty %.5f, difficulty(raw) %llu, target length %u",
                mID,
                (unsigned long long)currentWork.height,
                decodedDifficulty,
                (unsigned long long)currentWork.difficulty,
                target);

            // Prepare JSON midstate for new work
            prepareJsonMidstate(currentWork, &midstateData);

            // Copy midstate and remaining prefix to GPU
            for (int i = 0; i < 8; i++) {
                mJsonMidstateBuf[i] = midstateData.midstate[i];
            }
            CUDA_SAFE_CALL(mJsonMidstateBuf.copyToDevice());

            for (unsigned i = 0; i < midstateData.remainingLen; i++) {
                mJsonRemainingPrefixBuf[i] = midstateData.remainingPrefix[i];
            }
            CUDA_SAFE_CALL(mJsonRemainingPrefixBuf.copyToDevice());

            LOG_F(
                INFO,
                "GPU %d: JSON midstate prepared (prefix_len=%u)",
                mID,
                midstateData.totalPrefixLen);
        }

        // Check if work has changed during mining (detect stale work)
        if (!benchmarkMode && ctx->getWorkId() != roundWorkId) {
            LOG_F(
                WARNING,
                "GPU %d: Work changed during mining, restarting round",
                mID);
            continue; // Go back to get new work
        }

        // JSON-based hash generation on GPU
        int numhash = ((int)(16 * mSievePerRound) - (int)hashes.remaining()) *
            numHashCoeff;

        if (numhash > 0) {
            // Align to mLSize boundary
            numhash += mLSize - numhash % mLSize;
            if (benchmarkMode)
                benchmarkHashesDispatched += (uint64_t)numhash;

            mJsonCountBuf[0] = 0;
            CUDA_SAFE_CALL(mJsonCountBuf.copyToDevice(mHMFermatStream));

            uint64_t nonceOffset = nonce;
            uint32_t remainingLen = midstateData.remainingLen;
            uint32_t totalPrefixLen = midstateData.totalPrefixLen;

            void* arguments[] = {
                &nonceOffset,
                &mJsonFoundBuf._deviceData,
                &mJsonCountBuf._deviceData,
                &mJsonPrimorialBuf._deviceData,
                &mJsonMidstateBuf._deviceData,
                &mJsonRemainingPrefixBuf._deviceData,
                &remainingLen,
                &totalPrefixLen};

            CUDA_SAFE_CALL(cuLaunchKernel(
                mJsonHashMod,
                numhash / mLSize,
                1,
                1,
                mLSize,
                1,
                1,
                0,
                mHMFermatStream,
                arguments,
                0));

            nonce += numhash; // Increment nonce for next batch

            CUDA_SAFE_CALL(mJsonCountBuf.copyToHost(mHMFermatStream));
            CUDA_SAFE_CALL(cuStreamSynchronize(mHMFermatStream));

            unsigned foundCount = mJsonCountBuf[0];
            if (benchmarkMode)
                benchmarkGpuMatches += foundCount;
            if (foundCount > 0) {
                CUDA_SAFE_CALL(mJsonFoundBuf.copyToHost(mHMFermatStream));
                CUDA_SAFE_CALL(mJsonPrimorialBuf.copyToHost(mHMFermatStream));
                CUDA_SAFE_CALL(cuStreamSynchronize(mHMFermatStream));

                // Process found candidates
                unsigned processCount = std::min(foundCount, 128u);
                if (benchmarkMode)
                    benchmarkMatchesRetained += processCount;
                unsigned validCount = 0;
                unsigned failedMinimum = 0;
                unsigned failedDivisible = 0;

                for (unsigned i = 0; i < processCount; i++) {
                    uint64_t nonce = nonceOffset + mJsonFoundBuf[i];
                    uint32_t primorialBitField = mJsonPrimorialBuf[i];
                    uint32_t primorialIdx = primorialBitField >> 16;

                    // Calculate realPrimorial from bit field
                    uint64_t realPrimorial = 1;
                    for (unsigned j = 0; j < primorialIdx + 1; j++) {
                        if (primorialBitField & (1 << j))
                            realPrimorial *= gPrimes[j];
                    }

                    // Reconstruct full JSON with this nonce
                    char jsonStr[512];
                    int jsonLen = snprintf(
                        jsonStr,
                        sizeof(jsonStr),
                        R"({"parent_hash": "%s", "height": %llu, "difficulty": %llu, "merkle": "%s", "nonce": %llu})",
                        currentWork.parentHash.c_str(),
                        (unsigned long long)currentWork.height,
                        (unsigned long long)currentWork.difficulty,
                        currentWork.merkle.c_str(),
                        (unsigned long long)nonce);

                    if (gDebug && i == 0) {
                        fprintf(stderr, "\n=== DEBUG: Candidate %u ===\n", i);
                        fprintf(
                            stderr, "JSON (%d bytes): %s\n", jsonLen, jsonStr);
                    }

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
                        sprintf(hashHex + j * 2, "%02x", hash2[31 - j]);
                    }
                    hashHex[64] = 0;

                    if (gDebug && i == 0) {
                        fprintf(
                            stderr,
                            "SHA256(SHA256(json)) little-endian hex: %s\n",
                            hashHex);
                    }

                    uint256 hash256;
                    hash256.SetHex(hashHex);

                    // Validate hash meets minimum
                    if (hash256 < (uint256(1) << 255)) {
                        failedMinimum++;
                        continue;
                    }

                    // Convert to mpz and validate divisibility
                    mpz_class mpzHash;
                    mpz_set_uint256(mpzHash.get_mpz_t(), hash256);

                    mpz_class mpzRealPrimorial;
                    mpz_import(
                        mpzRealPrimorial.get_mpz_t(),
                        2,
                        -1,
                        4,
                        0,
                        0,
                        &realPrimorial);
                    unsigned adjustedIdx =
                        std::max(mPrimorial, primorialIdx) - mPrimorial;
                    mpz_class mpzHashMultiplier =
                        primorial[adjustedIdx] / mpzRealPrimorial;

                    if (!mpz_divisible_p(
                            mpzHash.get_mpz_t(),
                            mpzRealPrimorial.get_mpz_t())) {
                        failedDivisible++;
                        continue;
                    }

                    // Create hash_t and add to buffer
                    hash_t hash;
                    hash.iter = iteration;
                    hash.nonce = (uint32_t)nonce;
                    hash.time = 0;
                    hash.hash = hash256;
                    hash.primorialIdx = adjustedIdx;
                    hash.primorial = mpzHashMultiplier;
                    hash.shash = mpzHash * hash.primorial;

                    unsigned hid = hashes.push(hash);
                    memset(
                        &hashBuf[hid * mConfig.N],
                        0,
                        sizeof(uint32_t) * mConfig.N);
                    mpz_export(
                        &hashBuf[hid * mConfig.N],
                        0,
                        -1,
                        4,
                        0,
                        0,
                        hashes.get(hid).shash.get_mpz_t());
                    validCount++;
                }

                if (benchmarkMode)
                    benchmarkValidHashes += validCount;

                if (validCount > 0) {
                    CUDA_SAFE_CALL(hashBuf.copyToDevice(mSieveStream));

                    time_t currtime = time(0);
                    bool shouldLog =
                        gDebug || (currtime - timeValidationLog >= 60);
                    if (shouldLog) {
                        LOG_F(
                            INFO,
                            "GPU %d: Validated %u/%u candidates (failed: %u minimum, %u divisibility)",
                            mID,
                            validCount,
                            processCount,
                            failedMinimum,
                            failedDivisible);
                        timeValidationLog = currtime;
                    }
                } else if (processCount > 0 && gDebug) {
                    LOG_F(
                        WARNING,
                        "GPU %d: 0/%u candidates validated (failed: %u minimum, %u divisibility)",
                        mID,
                        processCount,
                        failedMinimum,
                        failedDivisible);
                }
            }
        }

        int ridx = iteration % 2;
        int widx = ridx ^ 1;

        // Sieve dispatch (reuses existing sieve kernels)
        for (unsigned i = 0; i < mSievePerRound; i++) {
            if (hashes.empty()) {
                if (benchmarkMode)
                    benchmarkHashStarvations++;
                if (!reset) {
                    numHashCoeff += 32768;
                    LOG_F(
                        WARNING,
                        "ran out of hashes, increasing sha256 work size coefficient to %u",
                        numHashCoeff);
                }
                break;
            }

            int hid = hashes.pop();
            if (benchmarkMode)
                benchmarkSieveJobs++;
            unsigned primorialIdx = hashes.get(hid).primorialIdx;

            CUDA_SAFE_CALL(
                candidatesCountBuffers[i][widx].copyToDevice(mSieveStream));

            {
                void* arguments[] = {
                    &sieveOff[0]._deviceData,
                    &sieveOff[1]._deviceData,
                    &primeBuf[primorialIdx]._deviceData,
                    &hashBuf._deviceData,
                    &hid,
                    &modulosBuf[primorialIdx]._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieveSetup,
                    mConfig.PCOUNT / mLSize,
                    1,
                    1,
                    mLSize,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));
            }

            {
                void* arguments[] = {
                    &sieveBuf[0]._deviceData,
                    &sieveOff[0]._deviceData,
                    &primeBuf2[primorialIdx]._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieve,
                    mConfig.STRIPES / 2,
                    mConfig.WIDTH,
                    1,
                    mLSize,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));
            }

            {
                void* arguments[] = {
                    &sieveBuf[1]._deviceData,
                    &sieveOff[1]._deviceData,
                    &primeBuf2[primorialIdx]._deviceData};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieve,
                    mConfig.STRIPES / 2,
                    mConfig.WIDTH,
                    1,
                    mLSize,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));
            }

            {
                uint32_t multiplierSize =
                    mpz_sizeinbase(hashes.get(hid).shash.get_mpz_t(), 2);
                void* arguments[] = {
                    &sieveBuf[0]._deviceData,
                    &sieveBuf[1]._deviceData,
                    &sieveBuffers[i][0][widx]._deviceData,
                    &sieveBuffers[i][1][widx]._deviceData,
                    &candidatesCountBuffers[i][widx]._deviceData,
                    &hid,
                    &multiplierSize,
                    &mDepth};

                CUDA_SAFE_CALL(cuLaunchKernel(
                    mSieveSearch,
                    (mConfig.SIZE * mConfig.STRIPES / 2) / 256,
                    1,
                    1,
                    256,
                    1,
                    1,
                    0,
                    mSieveStream,
                    arguments,
                    0));

                CUDA_SAFE_CALL(cuEventRecord(sieveEvent, mSieveStream));
            }
        }

        // Get candidates
        int numcandis = final.count[0];
        numcandis = std::min(numcandis, (int) final.info._size);
        numcandis = std::max(numcandis, 0);
        if (benchmarkMode)
            benchmarkFinalCandidates += (uint64_t)numcandis;
        candis.resize(numcandis);
        primeCount += numcandis;
        if (numcandis)
            memcpy(
                &candis[0], final.info._hostData, numcandis * sizeof(fermat_t));

        final.count[0] = 0;
        CUDA_SAFE_CALL(final.count.copyToDevice(mHMFermatStream));
        const uint64_t benchmarkFermatBefore = fermatCount;
        FermatDispatch(
            fermat320,
            sieveBuffers,
            candidatesCountBuffers,
            0,
            ridx,
            widx,
            testCount,
            fermatCount,
            mFermatKernel320,
            mSievePerRound);
        FermatDispatch(
            fermat352,
            sieveBuffers,
            candidatesCountBuffers,
            1,
            ridx,
            widx,
            testCount,
            fermatCount,
            mFermatKernel352,
            mSievePerRound);
        if (benchmarkMode)
            benchmarkSieveCandidates += fermatCount - benchmarkFermatBefore;

        CUDA_SAFE_CALL(cuEventSynchronize(sieveEvent));
        for (unsigned i = 0; i < mSievePerRound; i++)
            CUDA_SAFE_CALL(
                candidatesCountBuffers[i][widx].copyToHost(mSieveStream));

        CUDA_SAFE_CALL(hashmod.found.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(hashmod.primorialBitField.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(hashmod.count.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(
            fermat320.buffer[widx].count.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(
            fermat352.buffer[widx].count.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(final.info.copyToHost(mHMFermatStream));
        CUDA_SAFE_CALL(final.count.copyToHost(mHMFermatStream));

        CUDA_SAFE_CALL(cuStreamSynchronize(mHMFermatStream));

        // Adjust sieves per round
        if (fermat320.buffer[ridx].count[0] &&
            fermat320.buffer[ridx].count[0] < mBlockSize &&
            fermat352.buffer[ridx].count[0] &&
            fermat352.buffer[ridx].count[0] < mBlockSize) {
            mSievePerRound = std::min((unsigned)SW, mSievePerRound + 1);
            LOG_F(
                WARNING,
                "not enough candidates (%u available, must be more than %u",
                std::max(
                    fermat320.buffer[ridx].count[0],
                    fermat352.buffer[ridx].count[0]),
                mBlockSize);

            LOG_F(WARNING, "increase sieves per round to %u", mSievePerRound);
        }

        // Check candidates and submit if valid
        if (candis.size()) {
            mpz_class nOrigin;
            mpz_class multi;
            for (unsigned i = 0; i < candis.size(); ++i) {
                fermat_t& candi = candis[i];
                hash_t& hash = hashes.get(candi.hashid);

                unsigned age = iteration - hash.iter;
                if (age > PW / 2)
                    LOG_F(WARNING, "candidate age > PW/2 with %d", age);

                multi = candi.index;
                multi <<= candi.origin;
                nOrigin = hash.shash;
                nOrigin *= multi;

                testParams.nCandidateType = candi.type + 1;
                if (benchmarkMode)
                    benchmarkCpuCandidates++;
                // Independently verify the GPU-tested prefix in benchmark
                // mode. Starting at mDepth would trust the result and make
                // the pipeline-error counter unable to detect a bad prefix.
                bool isblock = ProbablePrimeChainTestFastCuda(
                    nOrigin, testParams, benchmarkMode ? 0 : mDepth);
                unsigned chainlength = TargetGetLength(testParams.nChainLength);
                if (benchmarkMode && chainlength < mDepth)
                    benchmarkPipelineErrors++;

                // Update chain stats
                if (chainlength > 0) {
                    for (unsigned k = 1; k < chainlength; k++) {
                        mineCtx.foundChains[k]++;
                    }
                    mineCtx.foundChains[chainlength]++;
                }

                // Normalize multiplier
                while (multi % 2 == 0 && nOrigin % 4 == 0) {
                    mpz_class nOriginNormalize = nOrigin / 2;
                    CPrimalityTestParamsCuda testParamsNormalize = testParams;

                    if (ProbablePrimeChainTestFastCuda(
                            nOriginNormalize, testParamsNormalize, mDepth)) {
                        if ((testParams.nCandidateType == 1 &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize - 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false)) ||
                            (testParams.nCandidateType == 2 &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize + 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false)) ||
                            (testParams.nCandidateType == 3 &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize - 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false) &&
                             FermatProbablePrimalityTestFastCuda(
                                 nOriginNormalize + 1,
                                 chainlength,
                                 testParamsNormalize,
                                 false))) {
                            unsigned chainlengthNormalize = TargetGetLength(
                                testParamsNormalize.nChainLength);
                            if (chainlengthNormalize > chainlength) {
                                multi /= 2;
                                nOrigin = nOriginNormalize;
                                chainlength = chainlengthNormalize;
                                testParams = testParamsNormalize;
                            } else {
                                break;
                            }
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }

                ProbablePrimeChainTestFastCuda(nOrigin, testParams, mDepth);
                if (testParams.nChainLength >= currentWork.difficulty) {
                    if (benchmarkMode) {
                        benchmarkShares++;
                        continue;
                    }
                    printf(
                        "\ncandis[%d] = %s\n", i, nOrigin.get_str(10).c_str());

                    mpz_class targetMultiplier = hash.primorial * multi;

                    bool submitted = false;

                    // Submit work via getwork protocol
                    // Default: ONLY BiTwin chains (type 3)
                    // Experimental: With --submit-all-chains flag, also submit
                    // Cunningham1 and Cunningham2
                    bool shouldSubmit =
                        (testParams.nCandidateType == PRIME_CHAIN_BI_TWIN) ||
                        (gSubmitAllChains &&
                         (testParams.nCandidateType ==
                              PRIME_CHAIN_CUNNINGHAM1 ||
                          testParams.nCandidateType ==
                              PRIME_CHAIN_CUNNINGHAM2));

                    if (shouldSubmit) {
                        // Check if work has changed before submitting
                        if (ctx->getWorkId() != roundWorkId) {
                            LOG_F(
                                INFO,
                                "GPU %d: Skipping stale submission (work changed)",
                                mID);
                        } else {
                            submitted = ctx->submitWork(
                                currentWork, hash.nonce, targetMultiplier);

                            if (submitted) {
                                ctx->triggerRefresh();
                            }
                        }
                    }

                    std::string chainName = GetPrimeChainName(
                        testParams.nCandidateType, testParams.nChainLength);
                    const char* submitStatus;
                    if (shouldSubmit) {
                        submitStatus = submitted ? "yes" : "failed";
                    } else {
                        if (testParams.nCandidateType == PRIME_CHAIN_BI_TWIN) {
                            submitStatus =
                                "skipped (BiTwin but shouldn't happen)";
                        } else {
                            submitStatus = gSubmitAllChains
                                ? "skipped (unknown type)"
                                : "skipped (not BiTwin, use --submit-all-chains)";
                        }
                    }
                    LOG_F(
                        1,
                        "GPU %d found share: %s (submitted: %s)",
                        mID,
                        chainName.c_str(),
                        submitStatus);

                    if (isblock) {
                        LOG_F(1, "GPU %d found BLOCK!", mID);
                        std::string nbitsTarget =
                            TargetToString(testParams.nBits);
                        LOG_F(1, "Found chain: %s", chainName.c_str());
                        LOG_F(
                            1,
                            "Target (nbits): %s\n----------------------------------------------------------------------",
                            nbitsTarget.c_str());
                    }
                } else if (chainlength < mDepth) {
                    LOG_F(
                        WARNING,
                        "ProbablePrimeChainTestFast %ubits %d/%d",
                        (unsigned)mpz_sizeinbase(nOrigin.get_mpz_t(), 2),
                        chainlength,
                        mDepth);
                    LOG_F(WARNING, "origin: %s", nOrigin.get_str().c_str());
                    LOG_F(WARNING, "type: %u", (unsigned)candi.type);
                    LOG_F(WARNING, "multiplier: %u", (unsigned)candi.index);
                    LOG_F(WARNING, "layer: %u", (unsigned)candi.origin);
                    stats.errors++;
                }
            }
        }

        // Update mining stats
        mineCtx.speed = (double)testCount / 1000000.0;
        mineCtx.totalRoundsNum++;

        if (!benchmarkMode) {
            MineContext* mineCtxArray = &mineCtx;
            printMiningStats(
                workBeginPoint,
                mineCtxArray,
                1,
                sieveSizeInGb,
                currentWork.height,
                GetPrimeDifficulty(currentWork.difficulty),
                4);
        }

        if (MakeExit)
            break;

        iteration++;

        if (benchmarkMode) {
            const double elapsed =
                std::chrono::duration<double>(
                    std::chrono::steady_clock::now() - benchmarkStart)
                    .count();
            if (elapsed >= benchmarkSeconds) {
                const double sieveRange =
                    (double)mConfig.SIZE * 32.0 * mConfig.STRIPES;
                const double retainedPercent = benchmarkGpuMatches == 0
                    ? 100.0
                    : 100.0 * (double)benchmarkMatchesRetained /
                        (double)benchmarkGpuMatches;
                benchmarkResult.completed =
                    benchmarkSieveJobs > 0 && benchmarkPipelineErrors == 0;
                benchmarkResult.elapsedSeconds = elapsed;
                benchmarkResult.effectiveScanGps =
                    sieveRange * benchmarkSieveJobs / elapsed / 1000000000.0;
                benchmarkResult.sieveCandidatesPerSecond =
                    benchmarkSieveCandidates / elapsed;
                benchmarkResult.finalCandidatesPerSecond =
                    benchmarkFinalCandidates / elapsed;
                benchmarkResult.pipelineErrors = benchmarkPipelineErrors;

                if (reportBenchmarkResults) {
                    LOG_F(INFO, "%s", "");
                    LOG_F(
                        INFO,
                        "=== End-to-end blocktree.get_work benchmark (CUDA) ===");
                    LOG_F(
                        INFO,
                        "Configuration: SIZE=%u, STRIPES=%u, PCOUNT=%u, "
                        "LSIZE=%u, sieves/round=%u, Fermat batch=%u, "
                        "hash coefficient=%u",
                        mConfig.SIZE,
                        mConfig.STRIPES,
                        mConfig.PCOUNT,
                        mLSize,
                        mSievePerRound,
                        mBlockSize,
                        numHashCoeff);
                    LOG_F(
                        INFO,
                        "Wall time: %.3f s, loop iterations: %u, sieve jobs: %llu",
                        elapsed,
                        iteration,
                        (unsigned long long)benchmarkSieveJobs);
                    LOG_F(
                        INFO,
                        "JSON hashes dispatched: %.3f M/s (%llu total)",
                        benchmarkHashesDispatched / elapsed / 1000000.0,
                        (unsigned long long)benchmarkHashesDispatched);
                    LOG_F(
                        INFO,
                        "GPU hash matches: %.1f/s; retained for CPU: %.1f/s "
                        "(%.4f%% retained)",
                        benchmarkGpuMatches / elapsed,
                        benchmarkMatchesRetained / elapsed,
                        retainedPercent);
                    LOG_F(
                        INFO,
                        "CPU-validated hashes feeding sieve: %.1f/s",
                        benchmarkValidHashes / elapsed);
                    LOG_F(
                        INFO,
                        "Effective end-to-end sieve scan: %.3f G/s",
                        benchmarkResult.effectiveScanGps);
                    LOG_F(
                        INFO,
                        "Sieve candidates feeding Fermat: %.1f/s (%llu total)",
                        benchmarkResult.sieveCandidatesPerSecond,
                        (unsigned long long)benchmarkSieveCandidates);
                    LOG_F(
                        INFO,
                        "Final GPU candidates: %.1f/s; CPU chain checks: %.1f/s; "
                        "shares meeting target: %llu",
                        benchmarkResult.finalCandidatesPerSecond,
                        benchmarkCpuCandidates / elapsed,
                        (unsigned long long)benchmarkShares);
                    LOG_F(
                        INFO,
                        "Hash-starved loop iterations: %llu; pipeline validation errors: %llu",
                        (unsigned long long)benchmarkHashStarvations,
                        (unsigned long long)benchmarkPipelineErrors);
                    LOG_F(
                        INFO,
                        "=======================================================");
                }
                break;
            }
        }
    }

    CUDA_SAFE_CALL(cuEventDestroy(sieveEvent));
    if (!benchmarkMode || reportBenchmarkResults)
        LOG_F(INFO, "GPU %d stopped.", mID);
    return benchmarkResult;
}

MiningBenchmarkResult PrimeMiner::BenchmarkMining(
    unsigned benchmarkSeconds,
    bool reportResults) {
    return MiningGetWork(nullptr, benchmarkSeconds, reportResults);
}

namespace {

struct CudaKernelConfig {
    unsigned size;
    unsigned stripes;
    unsigned primeCount;
    unsigned lsize;
    unsigned nlifo;
};

struct TunedCudaModule {
    CudaKernelConfig config;
    CUmodule module;
    MiningBenchmarkResult result;
    bool usable;

    explicit TunedCudaModule(const CudaKernelConfig& value)
        : config(value), module(nullptr), usable(false) {}
};

constexpr unsigned kCudaAutotuneCacheVersion = 2;
constexpr unsigned kCudaPrefetchDepths[] = {1, 2, 4, 6, 8, 12, 16};
constexpr unsigned kCudaAutotuneScreenSeconds = 1;
constexpr unsigned kCudaGeometryFinalSeconds = 3;
constexpr unsigned kCudaAutotuneFinalSeconds = 5;
constexpr size_t kCudaGeometryFinalistCount = 3;
constexpr size_t kCudaAutotuneFinalistCount = 3;
constexpr const char* kCudaCacheDirectory = "xpmcuda-cache";

bool ensureCudaCacheDirectory() {
    struct stat info{};
    if (stat(kCudaCacheDirectory, &info) == 0) {
        if (S_ISDIR(info.st_mode))
            return true;
        LOG_F(
            ERROR,
            "CUDA cache path exists but is not a directory: %s",
            kCudaCacheDirectory);
        return false;
    }
    if (errno != ENOENT) {
        LOG_F(
            ERROR,
            "Could not inspect CUDA cache directory %s: %s",
            kCudaCacheDirectory,
            std::strerror(errno));
        return false;
    }
    if (mkdir(kCudaCacheDirectory, 0755) == 0)
        return true;
    if (errno == EEXIST && stat(kCudaCacheDirectory, &info) == 0 &&
        S_ISDIR(info.st_mode)) {
        return true;
    }
    LOG_F(
        ERROR,
        "Could not create CUDA cache directory %s: %s",
        kCudaCacheDirectory,
        std::strerror(errno));
    return false;
}

std::string safeCudaName(const char* value) {
    std::string result = value ? value : "unknown";
    for (char& character : result) {
        if (!std::isalnum(static_cast<unsigned char>(character)) &&
            character != '-' && character != '_') {
            character = '_';
        }
    }
    return result;
}

unsigned exactLog2(unsigned value) {
    unsigned result = 0;
    while (value > 1) {
        value >>= 1;
        ++result;
    }
    return result;
}

bool getCudaDeviceLimits(
    const CUDADeviceInfo& device,
    int* maxThreadsPerBlock,
    int* sharedMemoryPerBlock,
    int* multiprocessorCount) {
    return cuDeviceGetAttribute(
               maxThreadsPerBlock,
               CU_DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK,
               device.device) == CUDA_SUCCESS &&
        cuDeviceGetAttribute(
            sharedMemoryPerBlock,
            CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK,
            device.device) == CUDA_SUCCESS &&
        cuDeviceGetAttribute(
            multiprocessorCount,
            CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT,
            device.device) == CUDA_SUCCESS;
}

bool isUsableCudaConfig(
    const CudaKernelConfig& config,
    const CUDADeviceInfo& device) {
    if (config.size == 0 || config.stripes == 0 || (config.stripes & 1u) ||
        config.primeCount == 0) {
        return false;
    }
    if (config.lsize < 128 || config.lsize > 1024 ||
        (config.lsize & (config.lsize - 1)) != 0 ||
        config.primeCount % config.lsize != 0 || config.nlifo < 1 ||
        config.nlifo > 16 || config.primeCount / config.lsize <= config.nlifo) {
        return false;
    }

    int maxThreadsPerBlock = 0;
    int sharedMemoryPerBlock = 0;
    int multiprocessorCount = 0;
    if (!getCudaDeviceLimits(
            device,
            &maxThreadsPerBlock,
            &sharedMemoryPerBlock,
            &multiprocessorCount)) {
        return false;
    }
    (void)multiprocessorCount;
    if (config.lsize > (unsigned)maxThreadsPerBlock ||
        (uint64_t)config.size * sizeof(uint32_t) >
            (uint64_t)sharedMemoryPerBlock) {
        return false;
    }
    return ((uint64_t)config.size * config.stripes / 2) % 256 == 0;
}

std::vector<CudaKernelConfig> cudaAutotuneCandidates(
    const CUDADeviceInfo& device) {
    std::vector<CudaKernelConfig> result;
    auto add = [&](unsigned size,
                   unsigned stripes,
                   unsigned primeCount,
                   unsigned lsize) {
        CudaKernelConfig candidate{size, stripes, primeCount, lsize, 4};
        if (!isUsableCudaConfig(candidate, device))
            return;
        for (const CudaKernelConfig& existing : result) {
            if (existing.size == candidate.size &&
                existing.stripes == candidate.stripes &&
                existing.primeCount == candidate.primeCount &&
                existing.lsize == candidate.lsize &&
                existing.nlifo == candidate.nlifo) {
                return;
            }
        }
        result.push_back(candidate);
    };

    // Roughly equal 82.6M-number ranges, spanning the shared-memory and
    // workgroup trade-offs that proved important on Metal and HIP.
    add(12288, 210, 65536, 1024); // historical CUDA baseline
    add(12288, 210, 65536, 512);
    add(12288, 210, 65536, 256);
    add(8192, 316, 65536, 1024);
    add(8192, 316, 65536, 512);
    add(8192, 316, 65536, 256);
    add(8192, 316, 65536, 128);
    add(6144, 420, 65536, 1024);
    add(6144, 420, 65536, 512);
    add(6144, 420, 65536, 256);
    add(4096, 630, 65536, 512);
    add(4096, 630, 65536, 256);

    // Refine the neighborhood around the historical shape while keeping the
    // total scan range within 0.4%. These points expose occupancy transitions
    // without turning the tuner into a large Cartesian product.
    add(11264, 230, 65536, 512);
    add(9216, 280, 65536, 512);

    // A shallower weave reduces sieve work but increases Fermat traffic. The
    // real-pipeline score determines whether the complete trade-off wins.
    add(8192, 316, 32768, 1024);
    add(8192, 316, 32768, 512);
    add(12288, 210, 32768, 512);
    add(12288, 210, 36864, 512);
    add(12288, 210, 40960, 512);
    add(12288, 210, 49152, 512);
    add(12288, 210, 57344, 512);
    add(12288, 210, 81920, 512);
    return result;
}

std::string cudaKernelCacheName(
    const CUDADeviceInfo& device,
    const CudaKernelConfig& config) {
    std::ostringstream stream;
    stream << kCudaCacheDirectory << "/kernelxpm_sm"
           << device.majorComputeCapability << device.minorComputeCapability
           << "_s" << config.size << "_t" << config.stripes << "_p"
           << config.primeCount << "_l" << config.lsize << "_f" << config.nlifo
           << ".ptx";
    return stream.str();
}

std::string cudaAutotuneCacheName(const CUDADeviceInfo& device) {
    int driverVersion = 0;
    int nvrtcMajor = 0;
    int nvrtcMinor = 0;
    int maxThreadsPerBlock = 0;
    int sharedMemoryPerBlock = 0;
    int multiprocessorCount = 0;
    cuDriverGetVersion(&driverVersion);
    nvrtcVersion(&nvrtcMajor, &nvrtcMinor);
    getCudaDeviceLimits(
        device,
        &maxThreadsPerBlock,
        &sharedMemoryPerBlock,
        &multiprocessorCount);
    std::ostringstream stream;
    stream << kCudaCacheDirectory << "/autotune-" << safeCudaName(device.name)
           << "-sm" << device.majorComputeCapability
           << device.minorComputeCapability << "-cu" << multiprocessorCount
           << "-drv" << driverVersion << "-nvrtc" << nvrtcMajor << '_'
           << nvrtcMinor << ".cfg";
    return stream.str();
}

bool compileCudaModule(
    const CUDADeviceInfo& device,
    const CudaKernelConfig& config,
    CUmodule* module,
    bool verbose) {
    if (!ensureCudaCacheDirectory())
        return false;

    const unsigned width = 20;
    const unsigned target = 10;
    const unsigned multiplierSizeLimits[3] = {24, 31, 35};
    unsigned ranges[3] = {0, 0, 0};
    const unsigned primeGroups = config.primeCount / config.lsize;
    const unsigned windowSize = config.size * 32;
    for (unsigned i = 0; i < primeGroups; ++i) {
        unsigned prime = gPrimes[13 + i * config.lsize];
        if (ranges[0] == 0 && windowSize / prime <= 2)
            ranges[0] = i;
        if (ranges[1] == 0 && windowSize / prime <= 1)
            ranges[1] = i;
        if (ranges[2] == 0 && windowSize / prime == 0)
            ranges[2] = i;
    }
    if (ranges[0] == 0)
        ranges[0] = primeGroups;
    if (ranges[1] == 0)
        ranges[1] = primeGroups;
    if (ranges[2] == 0)
        ranges[2] = primeGroups;

    std::vector<std::string> ownedOptions;
    auto define = [&](const char* name, unsigned value) {
        ownedOptions.push_back(
            std::string("-D") + name + "=" + std::to_string(value));
    };
    ownedOptions.push_back(
        std::string("--gpu-architecture=compute_") +
        std::to_string(device.majorComputeCapability) +
        std::to_string(device.minorComputeCapability));
    define("STRIPES", config.stripes);
    define("WIDTH", width);
    define("PCOUNT", config.primeCount);
    define("TARGET", target);
    define("SIZE", config.size);
    define("LSIZE", config.lsize);
    define("LSIZELOG2", exactLog2(config.lsize));
    define("NLIFO", config.nlifo);
    define("LIMIT13", multiplierSizeLimits[0]);
    define("LIMIT14", multiplierSizeLimits[1]);
    define("LIMIT15", multiplierSizeLimits[2]);
    define("SIEVERANGE1", ranges[0]);
    define("SIEVERANGE2", ranges[1]);
    define("SIEVERANGE3", ranges[2]);

    std::vector<const char*> options;
    options.reserve(ownedOptions.size());
    for (const std::string& option : ownedOptions)
        options.push_back(option.c_str());

    const std::vector<const char*> sources = {
        "xpm/cuda/helpers.cu",
        "xpm/cuda/procs.cu",
        "xpm/cuda/fermat.cu",
        "xpm/cuda/sieve.cu",
        "xpm/cuda/sha256.cu",
        "xpm/cuda/json_sha256.cu",
        "xpm/cuda/benchmarks.cu"};
    const std::string kernelName = cudaKernelCacheName(device, config);
    CUDA_SAFE_CALL(cuCtxSetCurrent(device.context));
    return cudaCompileKernel(
        kernelName.c_str(),
        sources,
        options.data(),
        (int)options.size(),
        module,
        device.majorComputeCapability,
        device.minorComputeCapability,
        false,
        verbose);
}

bool loadCudaAutotuneCache(
    const CUDADeviceInfo& device,
    CudaKernelConfig* config,
    double* score) {
    if (!ensureCudaCacheDirectory())
        return false;
    std::ifstream file(cudaAutotuneCacheName(device));
    unsigned version = 0;
    CudaKernelConfig cached{};
    double cachedScore = 0.0;
    if (!(file >> version >> cached.size >> cached.stripes >>
          cached.primeCount >> cached.lsize >> cached.nlifo >> cachedScore) ||
        version != kCudaAutotuneCacheVersion ||
        !isUsableCudaConfig(cached, device)) {
        return false;
    }
    *config = cached;
    *score = cachedScore;
    return true;
}

void saveCudaAutotuneCache(
    const CUDADeviceInfo& device,
    const CudaKernelConfig& config,
    double score) {
    if (!ensureCudaCacheDirectory())
        return;
    const std::string path = cudaAutotuneCacheName(device);
    std::ofstream file(path, std::ofstream::trunc);
    file << kCudaAutotuneCacheVersion << ' ' << config.size << ' '
         << config.stripes << ' ' << config.primeCount << ' ' << config.lsize
         << ' ' << config.nlifo << ' ' << std::setprecision(17) << score
         << '\n';
    if (!file)
        LOG_F(
            WARNING, "Could not save CUDA autotune result to %s", path.c_str());
}

bool selectCudaConfiguration(
    const CUDADeviceInfo& device,
    unsigned devicesNum,
    unsigned depth,
    CudaKernelConfig* selectedConfig,
    CUmodule* selectedModule) {
    const CudaKernelConfig safeConfig{12288, 210, 65536, 1024, 4};

    if (!gCudaAutoTune) {
        *selectedConfig = safeConfig;
        if (!compileCudaModule(device, safeConfig, selectedModule, true))
            return false;
        LOG_F(
            INFO,
            "CUDA autotune disabled; using LSIZE=%u SIZE=%u STRIPES=%u "
            "PCOUNT=%u NLIFO=%u",
            safeConfig.lsize,
            safeConfig.size,
            safeConfig.stripes,
            safeConfig.primeCount,
            safeConfig.nlifo);
        return true;
    }

    CudaKernelConfig cachedConfig{};
    double cachedScore = 0.0;
    if (!gCudaRetune &&
        loadCudaAutotuneCache(device, &cachedConfig, &cachedScore)) {
        if (compileCudaModule(
                device, cachedConfig, selectedModule, gDebug != 0)) {
            *selectedConfig = cachedConfig;
            LOG_F(
                INFO,
                "CUDA autotune cache selected LSIZE=%u SIZE=%u STRIPES=%u "
                "PCOUNT=%u NLIFO=%u (%.3f G/s)",
                cachedConfig.lsize,
                cachedConfig.size,
                cachedConfig.stripes,
                cachedConfig.primeCount,
                cachedConfig.nlifo,
                cachedScore);
            return true;
        }
        LOG_F(
            WARNING, "Cached CUDA configuration could not be loaded; retuning");
    }

    const std::vector<CudaKernelConfig> candidates =
        cudaAutotuneCandidates(device);
    if (candidates.empty()) {
        LOG_F(ERROR, "No CUDA autotune configuration fits this device");
        return false;
    }

    size_t prefetchVariantCount = 0;
    for (unsigned depthValue : kCudaPrefetchDepths) {
        if (depthValue != 4)
            ++prefetchVariantCount;
    }
    const size_t totalConfigurations = candidates.size() + prefetchVariantCount;
    LOG_F(
        INFO,
        "Starting CUDA autotune on GPU %d (%zu staged configurations; first "
        "run may take a while, results are cached)...",
        device.index,
        totalConfigurations);
    const bool showProgress = !gDebug && isatty(fileno(stderr));
    const size_t progressTotal = totalConfigurations * 2 +
        kCudaGeometryFinalistCount + kCudaAutotuneFinalistCount;
    auto renderProgress = [&](size_t completed) {
        if (!showProgress)
            return;
        constexpr size_t barWidth = 28;
        const size_t filled = completed * barWidth / progressTotal;
        const size_t percent = completed * 100 / progressTotal;
        fprintf(stderr, "\rCUDA autotune GPU %d [", device.index);
        for (size_t i = 0; i < barWidth; ++i)
            fputc(i < filled ? '#' : '-', stderr);
        fprintf(
            stderr, "] %3zu%% (%zu/%zu)", percent, completed, progressTotal);
        if (completed == progressTotal)
            fputc('\n', stderr);
        fflush(stderr);
    };

    const auto oldStderrVerbosity = loguru::g_stderr_verbosity;
    if (!gDebug)
        loguru::g_stderr_verbosity = loguru::Verbosity_ERROR;

    std::vector<TunedCudaModule> modules;
    modules.reserve(totalConfigurations);
    size_t progress = 0;
    renderProgress(progress);
    for (const CudaKernelConfig& candidate : candidates) {
        modules.emplace_back(candidate);
        TunedCudaModule& compiled = modules.back();
        if (compileCudaModule(
                device, candidate, &compiled.module, gDebug != 0)) {
            compiled.usable = true;
        }
        renderProgress(++progress);
    }

    int bestIndex = -1;
    double bestScore = 0.0;
    auto benchmarkCandidate = [&](size_t i,
                                  unsigned benchmarkSeconds,
                                  const char* phase,
                                  size_t phaseIndex,
                                  size_t phaseCount) {
        TunedCudaModule& candidate = modules[i];
        if (candidate.usable) {
            PrimeMiner miner(
                device.index, devicesNum, 5, depth, candidate.config.lsize);
            if (miner.Initialize(
                    device.context, device.device, candidate.module, false)) {
                candidate.result =
                    miner.BenchmarkMining(benchmarkSeconds, false);
                if (candidate.result.completed &&
                    (bestIndex < 0 ||
                     candidate.result.effectiveScanGps > bestScore)) {
                    bestIndex = (int)i;
                    bestScore = candidate.result.effectiveScanGps;
                }
                if (gDebug) {
                    LOG_F(
                        INFO,
                        "CUDA autotune %s %zu/%zu: LSIZE=%u SIZE=%u "
                        "STRIPES=%u PCOUNT=%u NLIFO=%u => %.3f G/s, "
                        "%.1f candidates/s, errors=%llu",
                        phase,
                        phaseIndex,
                        phaseCount,
                        candidate.config.lsize,
                        candidate.config.size,
                        candidate.config.stripes,
                        candidate.config.primeCount,
                        candidate.config.nlifo,
                        candidate.result.effectiveScanGps,
                        candidate.result.sieveCandidatesPerSecond,
                        (unsigned long long)candidate.result.pipelineErrors);
                }
            }
        }
        renderProgress(++progress);
    };

    const size_t geometryCount = modules.size();
    for (size_t i = 0; i < geometryCount; ++i)
        benchmarkCandidate(
            i,
            kCudaAutotuneScreenSeconds,
            "screen",
            i + 1,
            totalConfigurations);

    if (bestIndex >= 0) {
        std::vector<size_t> geometryFinalists;
        for (size_t i = 0; i < geometryCount; ++i) {
            if (modules[i].result.completed)
                geometryFinalists.push_back(i);
        }
        std::sort(
            geometryFinalists.begin(),
            geometryFinalists.end(),
            [&](size_t lhs, size_t rhs) {
                return modules[lhs].result.effectiveScanGps >
                    modules[rhs].result.effectiveScanGps;
            });
        if (geometryFinalists.size() > kCudaGeometryFinalistCount)
            geometryFinalists.resize(kCudaGeometryFinalistCount);

        const int screenBestIndex = bestIndex;
        const double screenBestScore = bestScore;
        bestIndex = -1;
        bestScore = 0.0;
        for (size_t rank = 0; rank < geometryFinalists.size(); ++rank) {
            benchmarkCandidate(
                geometryFinalists[rank],
                kCudaGeometryFinalSeconds,
                "geometry finalist",
                rank + 1,
                geometryFinalists.size());
        }
        if (bestIndex < 0) {
            bestIndex = screenBestIndex;
            bestScore = screenBestScore;
        }
    }

    if (bestIndex >= 0) {
        const CudaKernelConfig bestGeometry = modules[bestIndex].config;
        const size_t prefetchBegin = modules.size();
        for (unsigned depthValue : kCudaPrefetchDepths) {
            if (depthValue == bestGeometry.nlifo)
                continue;
            CudaKernelConfig candidate = bestGeometry;
            candidate.nlifo = depthValue;
            modules.emplace_back(candidate);
            TunedCudaModule& compiled = modules.back();
            if (isUsableCudaConfig(candidate, device) &&
                compileCudaModule(
                    device, candidate, &compiled.module, gDebug != 0)) {
                compiled.usable = true;
            }
            renderProgress(++progress);
        }
        for (size_t i = prefetchBegin; i < modules.size(); ++i)
            benchmarkCandidate(
                i,
                kCudaAutotuneScreenSeconds,
                "screen",
                i + 1,
                totalConfigurations);

        std::vector<size_t> finalists;
        for (size_t i = 0; i < modules.size(); ++i) {
            const CudaKernelConfig& config = modules[i].config;
            if (modules[i].result.completed &&
                config.size == bestGeometry.size &&
                config.stripes == bestGeometry.stripes &&
                config.primeCount == bestGeometry.primeCount &&
                config.lsize == bestGeometry.lsize) {
                finalists.push_back(i);
            }
        }
        std::sort(
            finalists.begin(), finalists.end(), [&](size_t lhs, size_t rhs) {
                return modules[lhs].result.effectiveScanGps >
                    modules[rhs].result.effectiveScanGps;
            });
        if (finalists.size() > kCudaAutotuneFinalistCount)
            finalists.resize(kCudaAutotuneFinalistCount);

        const int screenBestIndex = bestIndex;
        const double screenBestScore = bestScore;
        bestIndex = -1;
        bestScore = 0.0;
        for (size_t rank = 0; rank < finalists.size(); ++rank) {
            benchmarkCandidate(
                finalists[rank],
                kCudaAutotuneFinalSeconds,
                "finalist",
                rank + 1,
                finalists.size());
        }
        if (bestIndex < 0) {
            bestIndex = screenBestIndex;
            bestScore = screenBestScore;
        }
        if (progress < progressTotal)
            renderProgress(progressTotal);
    }

    loguru::g_stderr_verbosity = oldStderrVerbosity;

    if (bestIndex < 0) {
        LOG_F(ERROR, "CUDA autotune found no correct, usable configuration");
        for (TunedCudaModule& candidate : modules) {
            if (candidate.module)
                cuModuleUnload(candidate.module);
        }
        return false;
    }

    *selectedConfig = modules[bestIndex].config;
    *selectedModule = modules[bestIndex].module;
    modules[bestIndex].module = nullptr;
    for (TunedCudaModule& candidate : modules) {
        if (candidate.module)
            cuModuleUnload(candidate.module);
    }
    saveCudaAutotuneCache(device, *selectedConfig, bestScore);
    LOG_F(
        INFO,
        "CUDA autotune selected LSIZE=%u SIZE=%u STRIPES=%u PCOUNT=%u "
        "NLIFO=%u (end-to-end %.3f G/s)",
        selectedConfig->lsize,
        selectedConfig->size,
        selectedConfig->stripes,
        selectedConfig->primeCount,
        selectedConfig->nlifo,
        bestScore);
    return true;
}

} // namespace

enum CmdLineOptions {
    clDebug = 0,
    clThreadsNum,
    clBenchmark,
    clMiningBenchmark,
    clExtensionsNum,
    clPrimorial,
    clSieveSize,
    clWeaveDepth,
    clUrl,
    clUser,
    clPass,
    clWallet,
    clWorkerId,
    clProtocol,
    clWsUrl,
    clSubmitAllChains,
    clNoCudaAutotune,
    clCudaRetune,
    clHelp,
    clOptionLast,
    clOptionsNum
};

void printHelpMessage() {
    printf("Opensource primecoin CPU miner, usage:\n");
    printf("  xpmclminer <arguments>\n\n");
    printf("  -h or --help: show this help message\n");
    printf("  -b or --benchmark: run benchmark and exit\n");
    printf(
        "  --mining-benchmark <seconds>: run the real blocktree.get_work mining pipeline offline\n");
    printf(
        "  -o or --url <HostAddress:port>: address of primecoin RPC client, default: %s\n",
        gUrl);
    printf("  -u or --user <UserName>: user name for primecoin RPC client\n");
    printf("  -p or --pass <Password>: password for primecoin RPC client\n");
    printf("  -w or --wallet: wallet address for coin receiving\n");
    printf("  --debug: show additional mining information\n");
    printf(
        "  --protocol <getblocktemplate|getwork>: mining protocol (default: getblocktemplate)\n");
    printf("  --ws-url <ws://host:port>: WebSocket URL for getwork protocol\n");
    printf(
        "  --submit-all-chains: [EXPERIMENTAL] Submit all chain types (Cunningham1,\n");
    printf(
        "                       Cunningham2, BiTwin) instead of only BiTwin chains\n");
    printf(
        "  --no-cuda-autotune: use the safe CUDA kernel configuration without tuning\n");
    printf(
        "  --cuda-retune: ignore the cached CUDA configuration and tune again\n");
    printf(
        "  --extensions-num <number>: Eratosthenes sieve extensions number (default: %u)\n",
        gExtensionsNum);
    printf(
        "  --primorial <number>: primorial number (default: %u)\n", gPrimorial);
    printf(
        "  --sieve-size <number>: Eratosthenes sieve size (default: %u)\n",
        gSieveSize);
    printf(
        "  --weave-depth <number>: Eratosthenes sieve weave depth (default: %u)\n",
        gWeaveDepth);
    printf(
        "  --worker-id: unique identifier of your worker, used in block creation. ");
    printf(
        "All your rigs must have different worker IDs! (default: current time value)\n");
}

void initCmdLineOptions(option* options) {
    options[clDebug] = {"debug", no_argument, 0, 0};
    options[clThreadsNum] = {"threads", required_argument, &gThreadsNum, 0};
    options[clBenchmark] = {"benchmark", no_argument, 0, 'b'};
    options[clMiningBenchmark] = {"mining-benchmark", required_argument, 0, 0};
    options[clExtensionsNum] = {
        "extensions-num", required_argument, &gExtensionsNum, 0};
    options[clPrimorial] = {"primorial", required_argument, &gPrimorial, 0};
    options[clSieveSize] = {"sieve-size", required_argument, &gSieveSize, 0};
    options[clWeaveDepth] = {"weave-depth", required_argument, &gWeaveDepth, 0};
    options[clUrl] = {"url", required_argument, 0, 'o'};
    options[clUser] = {"user", required_argument, 0, 'u'};
    options[clPass] = {"pass", required_argument, 0, 'p'};
    options[clWallet] = {"wallet", required_argument, 0, 'w'};
    options[clWorkerId] = {"worker-id", required_argument, &extraNonce, 0};
    options[clProtocol] = {"protocol", required_argument, 0, 0};
    options[clWsUrl] = {"ws-url", required_argument, 0, 0};
    options[clSubmitAllChains] = {"submit-all-chains", no_argument, 0, 0};
    options[clNoCudaAutotune] = {"no-cuda-autotune", no_argument, 0, 0};
    options[clCudaRetune] = {"cuda-retune", no_argument, 0, 0};
    options[clHelp] = {"help", no_argument, 0, 'h'};
    options[clOptionLast] = {0, 0, 0, 0};
}

int main(int argc, char** argv) {
    char logFileName[64];
    {
        auto t = std::time(nullptr);
        auto now = std::localtime(&t);
        snprintf(
            logFileName,
            sizeof(logFileName),
            "miner-%04u-%02u-%02u.log",
            now->tm_year + 1900,
            now->tm_mon + 1,
            now->tm_mday);
    }
    loguru::g_stderr_verbosity = loguru::Verbosity_OFF;
    loguru::g_preamble_thread = false;
    loguru::g_preamble_file = false;
    loguru::g_flush_interval_ms = 100;
    loguru::init(argc, argv);
    loguru::add_file(logFileName, loguru::Append, loguru::Verbosity_INFO);
    loguru::g_stderr_verbosity = 1;

    srand(time(0));
    blkmk_sha256_impl = sha256;
    PrimeSource primeSource(10000000, gWeaveDepth + 256);
    option gOptions[clOptionsNum];
    bool isBenchmark = false;
    unsigned miningBenchmarkSeconds = 0;
    int index = 0, c;
    initCmdLineOptions(gOptions);
    const char* platform = "NVIDIA CUDA";
    while ((c = getopt_long(argc, argv, "bo:u:p:w:h", gOptions, &index)) !=
           -1) {
        switch (c) {
            case 0:
                switch (index) {
                    case clDebug:
                        gDebug = 1;
                        break;
                    case clMiningBenchmark:
                        miningBenchmarkSeconds =
                            (unsigned)strtoul(optarg, nullptr, 10);
                        break;
                    case clExtensionsNum:
                        gExtensionsNum = atoi(optarg);
                        break;
                    case clPrimorial:
                        gPrimorial = atoi(optarg);
                        break;
                    case clThreadsNum:
                        gThreadsNum = atoi(optarg);
                        break;
                    case clWorkerId:
                        extraNonce = atoi(optarg);
                        break;
                    case clProtocol:
                        gProtocol = optarg;
                        break;
                    case clWsUrl:
                        gWsUrl = optarg;
                        break;
                    case clSubmitAllChains:
                        gSubmitAllChains = true;
                        break;
                    case clNoCudaAutotune:
                        gCudaAutoTune = false;
                        break;
                    case clCudaRetune:
                        gCudaRetune = true;
                        break;
                }
                break;
            case 'b':
                isBenchmark = true;
                break;
            case 'o':
                gUrl = optarg;
                break;
            case 'u':
                gUserName = optarg;
                break;
            case 'p':
                gPassword = optarg;
                break;
            case 'w':
                gWallet = optarg;
                break;
            case 'h':
                printHelpMessage();
                exit(0);
            case ':':
                fprintf(
                    stderr,
                    "Error: option %s missing argument\n",
                    gOptions[index].name);
                break;
            case '?':
                fprintf(stderr, "Error: invalid option %s\n", argv[optind - 1]);
                break;
            default:
                break;
        }
    }

    if (isBenchmark && miningBenchmarkSeconds > 0) {
        fprintf(
            stderr, "Error: choose either --benchmark or --mining-benchmark\n");
        exit(1);
    }

    if (!gCudaAutoTune && gCudaRetune) {
        fprintf(
            stderr,
            "Error: --cuda-retune cannot be combined with --no-cuda-autotune\n");
        exit(1);
    }

    // Validate protocol selection
    bool useGetWork = miningBenchmarkSeconds > 0;
    if (miningBenchmarkSeconds == 0) {
        if (strcmp(gProtocol, "getwork") == 0) {
            useGetWork = true;
            if (!gWsUrl && !isBenchmark) {
                fprintf(
                    stderr, "Error: --ws-url required for getwork protocol\n");
                printHelpMessage();
                exit(1);
            }
        } else if (strcmp(gProtocol, "getblocktemplate") != 0) {
            fprintf(
                stderr,
                "Error: --protocol must be either 'getblocktemplate' or 'getwork'\n");
            printHelpMessage();
            exit(1);
        }
    }

    // Wallet is only required for getblocktemplate protocol
    if (!gWallet && !isBenchmark && miningBenchmarkSeconds == 0 &&
        !useGetWork) {
        fprintf(stderr, "Error: you must specify wallet\n");
        printHelpMessage();
        exit(1);
    }

    printf("block sum is %d\n", gThreadsNum);
    printf(
        "Using protocol: %s\n",
        miningBenchmarkSeconds > 0 ? "blocktree.get_work benchmark"
                                   : gProtocol);

    // Log experimental feature status
    if (gSubmitAllChains) {
        LOG_F(
            WARNING,
            "[EXPERIMENTAL] Submit all chains enabled: BiTwin, Cunningham1, Cunningham2 will be submitted");
    } else {
        LOG_F(
            INFO,
            "Submit mode: BiTwin chains only (use --submit-all-chains for experimental mode)");
    }

    // Only initialize RPC contexts if NOT in benchmark mode
    GetBlockTemplateContext* getblock = nullptr;
    SubmitContext* submit = nullptr;
    GetWorkContext* getwork = nullptr;

    if (!isBenchmark && miningBenchmarkSeconds == 0) {
        if (useGetWork) {
            // getwork protocol - WebSocket-based
            getwork = new GetWorkContext(0, gWsUrl);
            getwork->run();
        } else {
            // getblocktemplate protocol - HTTP RPC (existing code path)
            getblock = new GetBlockTemplateContext(
                0,
                gUrl,
                gUserName,
                gPassword,
                gWallet,
                4,
                gThreadsNum,
                extraNonce);
            getblock->run();
            submit = new SubmitContext(0, gUrl, gUserName, gPassword);
        }
    }
    blktemplate_t* workTemplate = 0;
    unsigned int dataId;
    bool hasChanged;
    // while(!(workTemplate = getblock->get(0, workTemplate, &dataId,
    // &hasChanged) ) ) {
    //   printf("blocktemplate %ld\n", (long int)workTemplate);
    //   usleep(500);
    // }
    // printf("blocktemplate_rwrqwrqw %ld\n", (long int)workTemplate);
    // printf("block height %d\n", workTemplate->height);

    {
        int np = sizeof(gPrimes) / sizeof(unsigned);
        gPrimes2.resize(np * 2);
        for (int i = 0; i < np; ++i) {
            unsigned prime = gPrimes[i];
            float fiprime = 1.f / float(prime);
            gPrimes2[i * 2] = prime;
            memcpy(&gPrimes2[i * 2 + 1], &fiprime, sizeof(float));
        }
    }

    std::vector<CUDADeviceInfo> gpus;
    int devicesNum = 0;
    CUDA_SAFE_CALL(cuInit(0));
    CUDA_SAFE_CALL(cuDeviceGetCount(&devicesNum));
    printf("number of devices %d\n", devicesNum);
    std::map<int, int> mDeviceMap;
    std::map<int, int> mDeviceMapRev;

    for (unsigned i = 0; i < devicesNum; i++) {
        char name[128];
        CUDADeviceInfo info;
        mDeviceMap[i] = gpus.size();
        mDeviceMapRev[gpus.size()] = i;
        info.index = i;
        CUDA_SAFE_CALL(cuDeviceGet(&info.device, i));
        CUDA_SAFE_CALL(cuDeviceGetAttribute(
            &info.majorComputeCapability,
            CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR,
            info.device));
        CUDA_SAFE_CALL(cuDeviceGetAttribute(
            &info.minorComputeCapability,
            CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR,
            info.device));

// CUDA 12.0+ uses new cuCtxCreate API
// Signature: cuCtxCreate(CUcontext* pctx, CUctxCreateParams* ctxCreateParams,
// unsigned int flags, CUdevice dev) For basic context creation, pass NULL for
// ctxCreateParams
#if CUDA_VERSION >= 13000
        CUDA_SAFE_CALL(
            cuCtxCreate(&info.context, NULL, CU_CTX_SCHED_AUTO, info.device));
#else
        // Legacy API: cuCtxCreate(CUcontext* pctx, unsigned int flags, CUdevice
        // dev)
        CUDA_SAFE_CALL(
            cuCtxCreate(&info.context, CU_CTX_SCHED_AUTO, info.device));
#endif

        CUDA_SAFE_CALL(cuDeviceGetName(name, sizeof(name), info.device));
        strncpy(info.name, name, sizeof(info.name) - 1);
        info.name[sizeof(info.name) - 1] = '\0';
        gpus.push_back(info);
        LOG_F(
            INFO,
            "[%i] %s; Compute capability %i.%i",
            (int)gpus.size() - 1,
            name,
            info.majorComputeCapability,
            info.minorComputeCapability);
    }

    int depth = 5 - 1;
    depth = std::max(depth, 2);
    depth = std::min(depth, 5);

    std::vector<CUmodule> modules(gpus.size(), nullptr);
    std::vector<CudaKernelConfig> selectedConfigs(gpus.size());
    for (unsigned i = 0; i < gpus.size(); ++i) {
        if (!selectCudaConfiguration(
                gpus[i],
                (unsigned)gpus.size(),
                depth,
                &selectedConfigs[i],
                &modules[i])) {
            return false;
        }
    }

    if (isBenchmark) {
        // Run benchmarks and exit
        for (unsigned i = 0; i < gpus.size(); i++) {
            cudaRunBenchmarks(
                gpus[i].context,
                gpus[i].device,
                modules[i],
                depth,
                selectedConfigs[i].lsize);
        }
        return 0;
    }

    // Normal mining mode
    unsigned int sievePerRound = 5;
    for (unsigned i = 0; i < gpus.size(); ++i) {
        PrimeMiner* miner = new PrimeMiner(
            i, gpus.size(), sievePerRound, depth, selectedConfigs[i].lsize);
        miner->Initialize(gpus[i].context, gpus[i].device, modules[i]);

        if (useGetWork) {
            // JSON getwork protocol
            miner->MiningGetWork(getwork, miningBenchmarkSeconds);
        } else {
            // getblocktemplate protocol (existing)
            miner->Mining(getblock, submit);
        }
    }

    return 0;
}
