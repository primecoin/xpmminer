#include "hip/hip_runtime.h"
#include "benchmarks_hip.h"

#include "gmpxx.h"

#include "loguru.hpp"
#include <time.h>
#include <chrono>
#include <memory>
#if defined(__GXX_EXPERIMENTAL_CXX0X__) && (__cplusplus < 201103L)
#define steady_clock monotonic_clock
#endif  

#include "prime.h"
#include <math.h> 
#include <set>
#include "gprimes.h"

enum CUDAKernels {
  CUDAKernelGenConfig = 0,
  CUDAKernelSquareBenchmark320,
  CUDAKernelSquareBenchmark352,  
  CUDAKernelMultiplyBenchmark320,
  CUDAKernelMultiplyBenchmark352,
  CUDAKernelFermatTestBenchmark320,
  CUDAKernelFermatTestBenchmark352,
  CUDAKernelHashMod,
  CUDAKernelSieveSetup,
  CUDAKernelSieve,
  CUDAKernelSieveSearch,
  CUDAKernelsNum
};  
 
static const char *gCUDAKernelNames[] = {
  "getconfig",
  "squareBenchmark320",
  "squareBenchmark352",
  "multiplyBenchmark320",
  "multiplyBenchmark352",
  "fermatTestBenchMark320",
  "fermatTestBenchMark352",
  "bhashmodUsePrecalc",
  "setup_sieve",
  "sieve",
  "s_sieve"
};

const unsigned GroupSize = 256;
const unsigned MulOpsNum = 512; 

uint32_t rand32()
{
  uint32_t result = rand();
  result = (result << 16) | rand();
  return result;
}

uint64_t rand64()
{
  uint64_t result = rand();
  result = (result << 16) | rand();
  result = (result << 16) | rand();
  result = (result << 16);
  return result;
} 
 
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
          LOG_F(ERROR, "Invalid number found; chain position is %u, divisor is %u type is %u", i+1, primes[divIdx], fSophieGermain ? 1 : 2);
        return false;
      }
    }
     
    N <<= 1;
    N += (fSophieGermain ? 1 : -1);
  }
  
  return true;
} 

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
              if (*invalidCount < 20)
                LOG_F(ERROR, " * type 1 firstLayer = %u", firstLayer);
              ++*invalidCount;
            }
            
            candidates.insert(candidateMultiplier);
          }
        }
      }
    }

    for (unsigned i = 0; i < layersNum; i++)
      c2Data[i] = c2ptr[wordIdx + sieveWords*i];
     
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
              if (*invalidCount < 20)
                LOG_F(ERROR, " * type 2 firstLayer = %u", firstLayer);
              ++*invalidCount;
            }
            
            candidates.insert(candidateMultiplier);            
          }
        }
      }
    } 
 
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
              if (*invalidCount < 20)
                LOG_F(ERROR, " * type bitwin firstLayer = %u", firstLayer);
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

void hipMultiplyBenchmark(hipFunction_t *kernels,
                           unsigned groupsNum,                       
                           unsigned mulOperandSize,
                           uint32_t elementsNum,
                           bool isSquaring)
{
  unsigned gmpOpSize = mulOperandSize + (mulOperandSize%2);
  unsigned limbsNum = elementsNum*gmpOpSize;
  hipBuffer<uint32_t> m1;
  hipBuffer<uint32_t> m2;
  hipBuffer<uint32_t> mR;
  hipBuffer<uint32_t> cpuR;
  
  HIP_SAFE_CALL(m1.init(limbsNum, false));
  HIP_SAFE_CALL(m2.init(limbsNum, false));
  HIP_SAFE_CALL(mR.init(limbsNum*2, false));
  HIP_SAFE_CALL(cpuR.init(limbsNum*2, false));

  memset(m1._hostData, 0, limbsNum*sizeof(uint32_t));
  memset(m2._hostData, 0, limbsNum*sizeof(uint32_t));
  memset(mR._hostData, 0, 2*limbsNum*sizeof(uint32_t));
  memset(cpuR._hostData, 0, 2*limbsNum*sizeof(uint32_t));  
  for (unsigned i = 0; i < elementsNum; i++) {
    for (unsigned j = 0; j < mulOperandSize; j++) {
      m1[i*gmpOpSize + j] = rand32();
      m2[i*gmpOpSize + j] = rand32();
    }
  }

  HIP_SAFE_CALL(m1.copyToDevice());
  HIP_SAFE_CALL(m2.copyToDevice());

  hipFunction_t kernel;
  if (isSquaring) {
    if (mulOperandSize == 320/32) {
      kernel = kernels[CUDAKernelSquareBenchmark320];
    } else if (mulOperandSize == 352/32) {
      kernel = kernels[CUDAKernelSquareBenchmark352];
    } else {
      LOG_F(ERROR, "Can't multiply %u-size operands on OpenCL device", mulOperandSize*32);
      return;
    }
  } else {
    if (mulOperandSize == 320/32) {
      kernel = kernels[CUDAKernelMultiplyBenchmark320];
    } else if (mulOperandSize == 352/32) {
      kernel = kernels[CUDAKernelMultiplyBenchmark352];
    } else {
      LOG_F(ERROR, "Can't multiply %u-size operands on OpenCL device", mulOperandSize*32);
      return;
    }
  }

  void *squaringArguments[] = { &m1._deviceData, &mR._deviceData, &elementsNum };
  void *multiplicationArguments[] = { &m1._deviceData, &m2._deviceData, &mR._deviceData, &elementsNum };
  void **arguments = isSquaring ? squaringArguments : multiplicationArguments;
  
  std::unique_ptr<mpz_class[]> cpuM1(new mpz_class[elementsNum]);
  std::unique_ptr<mpz_class[]> cpuM2(new mpz_class[elementsNum]);
  std::unique_ptr<mpz_class[]> cpuResult(new mpz_class[elementsNum]);
  
  for (unsigned i = 0; i < elementsNum; i++) {
    mpz_import(cpuM1[i].get_mpz_t(), mulOperandSize, -1, 4, 0, 0, &m1[i*gmpOpSize]);
    mpz_import(cpuM2[i].get_mpz_t(), mulOperandSize, -1, 4, 0, 0, &m2[i*gmpOpSize]);
    mpz_import(cpuResult[i].get_mpz_t(), mulOperandSize*2, -1, 4, 0, 0, &mR[i*mulOperandSize*2]);
  }

  auto gpuBegin = std::chrono::steady_clock::now();

  HIP_SAFE_CALL(hipModuleLaunchKernel(kernel,
                                elementsNum/GroupSize, 1, 1,
                                GroupSize, 1, 1,
                                0, NULL, arguments, 0));
  HIP_SAFE_CALL(hipDeviceSynchronize());

  auto gpuEnd = std::chrono::steady_clock::now();

  auto cpuBegin = std::chrono::steady_clock::now();

  if (isSquaring) {
    for (unsigned i = 0; i < elementsNum; i++) {
      unsigned gmpLimbsNum = cpuM1[i].get_mpz_t()->_mp_size;
      mp_limb_t *Operand1 = cpuM1[i].get_mpz_t()->_mp_d;
      uint32_t *target = &cpuR[i*mulOperandSize*2];
      for (unsigned j = 0; j < MulOpsNum; j++) {
        mpn_sqr((mp_limb_t*)target, Operand1, gmpLimbsNum);
        memcpy(Operand1, target+mulOperandSize, mulOperandSize*sizeof(uint32_t));
      }
    }
  } else {
    for (unsigned i = 0; i < elementsNum; i++) {
      unsigned gmpLimbsNum = cpuM1[i].get_mpz_t()->_mp_size;
      mp_limb_t *Operand1 = cpuM1[i].get_mpz_t()->_mp_d;
      mp_limb_t *Operand2 = cpuM2[i].get_mpz_t()->_mp_d;
      uint32_t *target = &cpuR[i*mulOperandSize*2];
      for (unsigned j = 0; j < MulOpsNum; j++) {
        mpn_mul_n((mp_limb_t*)target, Operand1, Operand2, gmpLimbsNum);
        memcpy(Operand1, target+mulOperandSize, mulOperandSize*sizeof(uint32_t));
      }
    }
  }

  auto cpuEnd = std::chrono::steady_clock::now();

  HIP_SAFE_CALL(mR.copyToHost());

  for (unsigned i = 0; i < elementsNum; i++) {
    if (memcmp(&mR[i*mulOperandSize*2], &cpuR[i*mulOperandSize*2], 4*mulOperandSize*2) != 0) {
      LOG_F(ERROR, "element index: %u", i);
      LOG_F(ERROR, "gmp: ");
      for (unsigned j = 0; j < mulOperandSize*2; j++)
        LOG_F(ERROR, "%08X ", cpuR[i*mulOperandSize*2 + j]);
      LOG_F(ERROR, "gpu: ");
      for (unsigned j = 0; j < mulOperandSize*2; j++)
        LOG_F(ERROR, "%08X ", mR[i*mulOperandSize*2 + j]);
      LOG_F(ERROR, "results differ!");
      break;
    }
  }

  double gpuTime = std::chrono::duration_cast<std::chrono::microseconds>(gpuEnd-gpuBegin).count() / 1000.0;
  double cpuTime = std::chrono::duration_cast<std::chrono::microseconds>(cpuEnd-cpuBegin).count() / 1000.0;
  double speedup = cpuTime / gpuTime;

  LOG_F(INFO, "%s %u bits CPU time: %.3lf, GPU time: %.3lf (%.3lf times faster)",
        (isSquaring ? "Square" : "Multiply"), mulOperandSize*32, cpuTime, gpuTime, speedup);
}

void hipFermatTestBenchmark(hipFunction_t *kernels,
                             unsigned groupsNum, 
                             unsigned operandSize,
                             unsigned elementsNum)
{ 
  unsigned numberLimbsNum = elementsNum*operandSize;
  
  hipBuffer<uint32_t> numbers;
  hipBuffer<uint32_t> gpuResults;
  hipBuffer<uint32_t> cpuResults;
  
  HIP_SAFE_CALL(numbers.init(numberLimbsNum, false));
  HIP_SAFE_CALL(gpuResults.init(numberLimbsNum, false));
  HIP_SAFE_CALL(cpuResults.init(numberLimbsNum, false));
  
  for (unsigned i = 0; i < elementsNum; i++) {
    for (unsigned j = 0; j < operandSize; j++)
      numbers[i*operandSize + j] = (j == operandSize-1) ? (1 << (i % 32)) : rand32();
    if (rand() % 16 == 0) {
      numbers[i*operandSize + operandSize-2] = numbers[i*operandSize + operandSize-1];
      numbers[i*operandSize + operandSize-1] = 0;
    }
    numbers[i*operandSize] |= 0x1; 
  }

  HIP_SAFE_CALL(numbers.copyToDevice());
  HIP_SAFE_CALL(gpuResults.copyToDevice());

  hipFunction_t kernel;
  if (operandSize == 320/32) {
    kernel = kernels[CUDAKernelFermatTestBenchmark320];
  } else if (operandSize == 352/32) {
    kernel = kernels[CUDAKernelFermatTestBenchmark352];
  } else {
    LOG_F(ERROR, "Can't do Fermat test on %ubit operand", operandSize*32);
    return;
  }
  
  std::unique_ptr<mpz_t[]> cpuNumbersBuffer(new mpz_t[elementsNum]);
  std::unique_ptr<mpz_t[]> cpuResultsBuffer(new mpz_t[elementsNum]);
  mpz_class mpzTwo = 2;
  mpz_class mpzE;
  mpz_import(mpzE.get_mpz_t(), operandSize, -1, 4, 0, 0, &numbers[0]);
  for (unsigned i = 0; i < elementsNum; i++) {
    mpz_init(cpuNumbersBuffer[i]);
    mpz_init(cpuResultsBuffer[i]);
    mpz_import(cpuNumbersBuffer[i], operandSize, -1, 4, 0, 0, &numbers[i*operandSize]);
    mpz_import(cpuResultsBuffer[i], operandSize, -1, 4, 0, 0, &cpuResults[i*operandSize]);
  }
  
  void *arguments[] = { &numbers._deviceData, &gpuResults._deviceData, &elementsNum };

  auto gpuBegin = std::chrono::steady_clock::now();  
  
  HIP_SAFE_CALL(hipModuleLaunchKernel(kernel,
                                elementsNum/GroupSize, 1, 1,                                
                                GroupSize, 1, 1,
                                0, NULL, arguments, 0));
  HIP_SAFE_CALL(hipDeviceSynchronize());
  
  auto gpuEnd = std::chrono::steady_clock::now();  
  
  
  for (unsigned i = 0; i < elementsNum; i++) {
    mpz_sub_ui(mpzE.get_mpz_t(), cpuNumbersBuffer[i], 1);
    mpz_powm(cpuResultsBuffer[i], mpzTwo.get_mpz_t(), mpzE.get_mpz_t(), cpuNumbersBuffer[i]);
  }
  
  auto cpuEnd = std::chrono::steady_clock::now();    

  HIP_SAFE_CALL(gpuResults.copyToHost());

  memset(&cpuResults[0], 0, 4*operandSize*elementsNum);
  for (unsigned i = 0; i < elementsNum; i++) {
    size_t exportedLimbs;
    mpz_export(&cpuResults[i*operandSize], &exportedLimbs, -1, 4, 0, 0, cpuResultsBuffer[i]);
    if (memcmp(&gpuResults[i*operandSize], &cpuResults[i*operandSize], 4*operandSize) != 0) {
      LOG_F(ERROR, "element index: %u", i);
      LOG_F(ERROR, "element data: ");
      for (unsigned j = 0; j < operandSize; j++)
        LOG_F(ERROR, "%08X ", numbers[i*operandSize + j]);
      LOG_F(ERROR, "gmp: ");
      for (unsigned j = 0; j < operandSize; j++)
        LOG_F(ERROR, "%08X ", cpuResults[i*operandSize + j]);
      LOG_F(ERROR, "gpu: ");
      for (unsigned j = 0; j < operandSize; j++)
        LOG_F(ERROR, "%08X ", gpuResults[i*operandSize + j]);
      LOG_F(ERROR, "results differ!");
      break;
    }
  }
  
  double gpuTime = std::chrono::duration_cast<std::chrono::microseconds>(gpuEnd-gpuBegin).count() / 1000.0;
  double cpuTime = std::chrono::duration_cast<std::chrono::microseconds>(cpuEnd-gpuEnd).count() / 1000.0;
  double speedup = cpuTime / gpuTime;

  LOG_F(INFO, "Fermat tests %u bits CPU time: %.3lf, GPU time: %.3lf (%.3lf times faster)",
        operandSize*32, cpuTime, gpuTime, speedup);
}

void hipHashmodBenchmark(hipFunction_t *kernels,
                          unsigned defaultGroupSize,
                          unsigned groupsNum,
                          mpz_class *allPrimorials,
                          unsigned mPrimorial)
{
  LOG_F(INFO, " *** hashmod benchmark ***");
  
  const unsigned iterationsNum = 64;
  hipFunction_t mHashMod = kernels[CUDAKernelHashMod];
  
  PrimeMiner::search_t hashmod;
  PrimeMiner::block_t blockheader;
  
  HIP_SAFE_CALL(hashmod.midstate.init(8*sizeof(uint32_t), false));
  HIP_SAFE_CALL(hashmod.found.init(32768, false));
  HIP_SAFE_CALL(hashmod.primorialBitField.init(2048, false));
  HIP_SAFE_CALL(hashmod.count.init(1, false));

  uint64_t totalTime = 0;
  unsigned totalHashes = 0;
  unsigned numhash = 64*131072;

  unsigned multiplierSizes[128];
  memset(multiplierSizes, 0, sizeof(multiplierSizes));
  
  uint64_t phashCount[20];
  memset(phashCount, 0, sizeof(phashCount));
  
  for (unsigned i = 0; i < iterationsNum; i++) {
    sha256precalcData precalcData;
    
    {
      uint8_t *pHeader = (uint8_t*)&blockheader;
      for (unsigned i = 0; i < sizeof(blockheader); i++)
        pHeader[i] = rand32();
      blockheader.version = PrimeMiner::block_t::CURRENT_VERSION;
      blockheader.nonce = 1;  
      precalcSHA256(&blockheader, hashmod.midstate._hostData, &precalcData);
    }    

    hashmod.count[0] = 0;
    HIP_SAFE_CALL(hashmod.midstate.copyToDevice());
    HIP_SAFE_CALL(hashmod.count.copyToDevice());
    
    int nonceOffset = 0;
    void *arguments[] = {
      &nonceOffset,
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
      &precalcData.temp2_3
    };
    
    auto gpuBegin = std::chrono::steady_clock::now();  

    HIP_SAFE_CALL(hipModuleLaunchKernel(mHashMod,
                                  numhash/defaultGroupSize, 1, 1,                                
                                  defaultGroupSize, 1, 1,
                                  0, NULL, arguments, 0));
    HIP_SAFE_CALL(hipDeviceSynchronize());    
    
    auto gpuEnd = std::chrono::steady_clock::now();  
    
    HIP_SAFE_CALL(hashmod.found.copyToHost());
    HIP_SAFE_CALL(hashmod.primorialBitField.copyToHost());
    HIP_SAFE_CALL(hashmod.count.copyToHost());
    
    totalTime += std::chrono::duration_cast<std::chrono::microseconds>(gpuEnd-gpuBegin).count();
    totalHashes += hashmod.count[0];
    
    for (unsigned i = 0; i < hashmod.count[0]; i++) {
      uint256 hashValue;
      PrimeMiner::block_t b = blockheader;
      b.nonce = hashmod.found[i];
      
      uint32_t primorialBitField = hashmod.primorialBitField[i];
      uint32_t primorialIdx = primorialBitField >> 16;
      uint64_t realPrimorial = 1;
      for (unsigned j = 0; j < primorialIdx+1; j++) {
        if (primorialBitField & (1 << j))
          realPrimorial *= gPrimes[j];
      }      
      
      phashCount[primorialIdx]++;

      mpz_class mpzRealPrimorial;        
      mpz_import(mpzRealPrimorial.get_mpz_t(), 2, -1, 4, 0, 0, &realPrimorial);            
      primorialIdx = std::max(mPrimorial, primorialIdx) - mPrimorial;
      mpz_class mpzHashMultiplier = allPrimorials[primorialIdx] / mpzRealPrimorial;
      unsigned hashMultiplierSize = mpz_sizeinbase(mpzHashMultiplier.get_mpz_t(), 2);      
      multiplierSizes[hashMultiplierSize]++;
      
      SHA_256 sha;
      sha.init();
      sha.update((const unsigned char*)&b, sizeof(b));
      sha.final((unsigned char*)&hashValue);
      sha.init();
      sha.update((const unsigned char*)&hashValue, sizeof(uint256));
      sha.final((unsigned char*)&hashValue);      
      
      if(hashValue < (uint256(1) << 255)){
        LOG_F(INFO, " * error: hash does not meet minimum.");
        continue;
      }
      
        
      mpz_class mpzHash;
      mpz_set_uint256(mpzHash.get_mpz_t(), hashValue);
      if(!mpz_divisible_p(mpzHash.get_mpz_t(), mpzRealPrimorial.get_mpz_t())){
        LOG_F(INFO, " * error: mpz_divisible_ui_p failed.");
        continue;
      }    
      
      
      uint32_t multiplierBitField = hashmod.primorialBitField[i];
      
      unsigned multiplierCount = 0;
      for (unsigned j = 0; j < 32; j++)
        multiplierCount += ((multiplierBitField & (1 << j)) != 0);
    }
  }
  
  double averageHashes = (double)totalHashes / iterationsNum;
  LOG_F(INFO, " MHash per second: %.3lf", iterationsNum*numhash / (double)totalTime);
  LOG_F(INFO, " Hash per iteration: %.3lf (%.6lf %%)", averageHashes, averageHashes*100/numhash);
 
  uint64_t totalSize = 0;
  unsigned hashes = 0;
  for (unsigned i = 0; i < 128; i++) {
    if (multiplierSizes[i]) {
      hashes += multiplierSizes[i];
      totalSize += multiplierSizes[i] * i;
    }
  }
  LOG_F(INFO, " Average hash multiplier size: %.3lf", totalSize / (double)hashes);
  
  for (unsigned i = 0; i < 20; i++) {
    if (phashCount[i]) {
      LOG_F(INFO, "   Hashed with primorial %u is %.3lf%%", i, phashCount[i] / (double)hashes * 100.0);
    }
  }
}

void hipSieveTestBenchmark(hipFunction_t *kernels,
                            unsigned defaultGroupSize,
                            unsigned groupsNum,
                            mpz_class *allPrimorial,
                            unsigned mPrimorial,
                            config_t mConfig,
                            unsigned mDepth,
                            bool checkCandidates)
{
  LOG_F(INFO, " *** sieve (%s) benchmark ***", checkCandidates ? "check" : "performance");
  
  hipFunction_t mHashMod = kernels[CUDAKernelHashMod];
  hipFunction_t mSieveSetup = kernels[CUDAKernelSieveSetup];
  hipFunction_t mSieve = kernels[CUDAKernelSieve];
  hipFunction_t mSieveSearch = kernels[CUDAKernelSieveSearch];
  
  PrimeMiner::search_t hashmod;
  PrimeMiner::block_t blockheader;
  lifoBuffer<PrimeMiner::hash_t> hashes(PW);
  hipBuffer<uint32_t> hashBuf;
  hipBuffer<uint32_t> sieveBuf[2];
  hipBuffer<uint32_t> sieveOff[2];  
  hipBuffer<PrimeMiner::fermat_t> sieveBuffers[64][FERMAT_PIPELINES];
  hipBuffer<uint32_t> candidatesCountBuffers[64];

  hipBuffer<uint32_t> primeBuf[maxHashPrimorial];
  hipBuffer<uint32_t> primeBuf2[maxHashPrimorial];
  
  for (unsigned i = 0; i < maxHashPrimorial - mPrimorial; i++) {
    HIP_SAFE_CALL(primeBuf[i].init(mConfig.PCOUNT, true));
    HIP_SAFE_CALL(primeBuf[i].copyToDevice(&gPrimes[mPrimorial+i+1]));
    HIP_SAFE_CALL(primeBuf2[i].init(mConfig.PCOUNT*2, true));
    HIP_SAFE_CALL(primeBuf2[i].copyToDevice(&gPrimes2[2*(mPrimorial+i)+2]));
  }
  
  hipBuffer<uint32_t> modulosBuf[maxHashPrimorial];
  unsigned modulosBufferSize = mConfig.PCOUNT*(mConfig.N-1);   
  for (unsigned bufIdx = 0; bufIdx < maxHashPrimorial-mPrimorial; bufIdx++) {
    hipBuffer<uint32_t> &current = modulosBuf[bufIdx];
    HIP_SAFE_CALL(current.init(modulosBufferSize, false));
    for (unsigned i = 0; i < mConfig.PCOUNT; i++) {
      mpz_class X = 1;
      for (unsigned j = 0; j < mConfig.N-1; j++) {
        X <<= 32;
        mpz_class mod = X % gPrimes[i+mPrimorial+bufIdx+1];
        current[mConfig.PCOUNT*j+i] = mod.get_ui();
      }
    }
    
    HIP_SAFE_CALL(current.copyToDevice());
  }
  
  HIP_SAFE_CALL(hashmod.midstate.init(8, false));
  HIP_SAFE_CALL(hashmod.found.init(2048, false));
  HIP_SAFE_CALL(hashmod.primorialBitField.init(2048, false));
  HIP_SAFE_CALL(hashmod.count.init(1, false));
  HIP_SAFE_CALL(hashBuf.init(PW*mConfig.N, false));

  unsigned numhash = 1048576;
  unsigned foundHashNum = 0;
  unsigned hashm[32];
  memset(hashm, 0, sizeof(hashm));
  sha256precalcData precalcData;

  while (foundHashNum < 64) {
    {
      uint8_t *pHeader = (uint8_t*)&blockheader;
      for (unsigned i = 0; i < sizeof(blockheader); i++)
        pHeader[i] = rand();
      blockheader.version = PrimeMiner::block_t::CURRENT_VERSION;
      blockheader.nonce = 1;
      precalcSHA256(&blockheader, hashmod.midstate._hostData, &precalcData);
    }

    hashmod.count[0] = 0;
    HIP_SAFE_CALL(hashmod.midstate.copyToDevice());
    HIP_SAFE_CALL(hashmod.count.copyToDevice());

    int nonceOffset = 0;
    void *arguments[] = {
      &nonceOffset,
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
      &precalcData.temp2_3
    };

    HIP_SAFE_CALL(hipModuleLaunchKernel(mHashMod,
                                  numhash/defaultGroupSize, 1, 1,
                                  defaultGroupSize, 1, 1,
                                  0, NULL, arguments, 0));

    HIP_SAFE_CALL(hashmod.found.copyToHost());
    HIP_SAFE_CALL(hashmod.primorialBitField.copyToHost());
    HIP_SAFE_CALL(hashmod.count.copyToHost());
    HIP_SAFE_CALL(hipDeviceSynchronize());

    for(unsigned i = 0; i < hashmod.count[0]; ++i) {
      PrimeMiner::hash_t hash;
      hash.time = blockheader.time;
      hash.nonce = hashmod.found[i];
      uint32_t primorialBitField = hashmod.primorialBitField[i];
      uint32_t primorialIdx = primorialBitField >> 16;
      uint64_t realPrimorial = 1;
      for (unsigned j = 0; j < primorialIdx+1; j++) {
        if (primorialBitField & (1 << j))
          realPrimorial *= gPrimes[j];
      }

      mpz_class mpzRealPrimorial;
      mpz_import(mpzRealPrimorial.get_mpz_t(), 2, -1, 4, 0, 0, &realPrimorial);
      primorialIdx = std::max(mPrimorial, primorialIdx) - mPrimorial;
      mpz_class mpzHashMultiplier = allPrimorial[primorialIdx] / mpzRealPrimorial;
      unsigned hashMultiplierSize = mpz_sizeinbase(mpzHashMultiplier.get_mpz_t(), 2);
      mpz_import(mpzRealPrimorial.get_mpz_t(), 2, -1, 4, 0, 0, &realPrimorial);

      PrimeMiner::block_t b = blockheader;
      b.nonce = hash.nonce;

      SHA_256 sha;
      sha.init();
      sha.update((const unsigned char*)&b, sizeof(b));
      sha.final((unsigned char*)&hash.hash);
      sha.init();
      sha.update((const unsigned char*)&hash.hash, sizeof(uint256));
      sha.final((unsigned char*)&hash.hash);

      if(hash.hash < (uint256(1) << 255)){
        LOG_F(INFO, " * error: hash does not meet minimum.");
        continue;
      }

      mpz_class mpzHash;
      mpz_set_uint256(mpzHash.get_mpz_t(), hash.hash);
      if(!mpz_divisible_p(mpzHash.get_mpz_t(), mpzRealPrimorial.get_mpz_t())){
        LOG_F(INFO, " * error: mpz_divisible_ui_p failed.");
        continue;
      }

      mpz_set_uint256(mpzHash.get_mpz_t(), hash.hash);
      hash.primorialIdx = primorialIdx;
      hash.primorial = mpzHashMultiplier;
      hash.shash = mpzHash * hash.primorial;
      unsigned hid = hashes.push(hash);
      if (hid >= 64)
        break;
      memset(&hashBuf[hid*mConfig.N], 0, sizeof(uint32_t)*mConfig.N);
      mpz_export(&hashBuf[hid*mConfig.N], 0, -1, 4, 0, 0, hashes.get(hid).shash.get_mpz_t());
      foundHashNum = hid+1;
    }
  }

  HIP_SAFE_CALL(hashBuf.copyToDevice());

  for(int sieveIdx = 0; sieveIdx < 64; ++sieveIdx) {
    for (int pipelineIdx = 0; pipelineIdx < FERMAT_PIPELINES; pipelineIdx++)
      HIP_SAFE_CALL(sieveBuffers[sieveIdx][pipelineIdx].init(MSO, false));
      
    HIP_SAFE_CALL(candidatesCountBuffers[sieveIdx].init(FERMAT_PIPELINES, false));
  }  
  
  for(int k = 0; k < 2; ++k){
    HIP_SAFE_CALL(sieveBuf[k].init(mConfig.SIZE*mConfig.STRIPES/2*mConfig.WIDTH, false));
    HIP_SAFE_CALL(sieveOff[k].init(mConfig.PCOUNT*mConfig.WIDTH, false));
  }  

  unsigned count = checkCandidates ? 1 : foundHashNum;
  unsigned candidates320[64];
  unsigned candidates352[64];

  auto gpuBegin = std::chrono::steady_clock::now();  
  
  for (unsigned i = 0; i < count; i++) {
    uint32_t hid = hashes.pop();
    unsigned primorialIdx = hashes.get(hid).primorialIdx;
    
    {
      void *arguments[] = {
        &sieveOff[0]._deviceData,
        &sieveOff[1]._deviceData,
        &primeBuf[primorialIdx]._deviceData,
        &hashBuf._deviceData,
        &hid,
        &modulosBuf[primorialIdx]._deviceData
      };
      
      HIP_SAFE_CALL(hipModuleLaunchKernel(mSieveSetup,
                                    mConfig.PCOUNT/defaultGroupSize, 1, 1,                                
                                    defaultGroupSize, 1, 1,
                                    0, NULL, arguments, 0));
    }

    {
      void *arguments[] = {
        &sieveBuf[0]._deviceData,
        &sieveOff[0]._deviceData,
        &primeBuf2[primorialIdx]._deviceData
      };
      
      HIP_SAFE_CALL(hipModuleLaunchKernel(mSieve,
                                    mConfig.STRIPES/2, mConfig.WIDTH, 1,
                                    defaultGroupSize, 1, 1,
                                    0, NULL, arguments, 0));
    }
    
    {
      void *arguments[] = {
        &sieveBuf[1]._deviceData,
        &sieveOff[1]._deviceData,
        &primeBuf2[primorialIdx]._deviceData
      };
      
      HIP_SAFE_CALL(hipModuleLaunchKernel(mSieve,
                                    mConfig.STRIPES/2, mConfig.WIDTH, 1,
                                    defaultGroupSize, 1, 1,
                                    0, NULL, arguments, 0));
    }

    candidatesCountBuffers[i][0] = 0;
    candidatesCountBuffers[i][1] = 0;
    HIP_SAFE_CALL(candidatesCountBuffers[i].copyToDevice());
        
    {
      uint32_t multiplierSize = mpz_sizeinbase(hashes.get(hid).shash.get_mpz_t(), 2);
      void *arguments[] = {
        &sieveBuf[0]._deviceData,
        &sieveBuf[1]._deviceData,
        &sieveBuffers[i][0]._deviceData,
        &sieveBuffers[i][1]._deviceData,
        &candidatesCountBuffers[i]._deviceData,
        &hid,
        &multiplierSize,
        &mDepth
      };
  
      HIP_SAFE_CALL(hipModuleLaunchKernel(mSieveSearch,
                                    (mConfig.SIZE*mConfig.STRIPES/2)/128, 1, 1,
                                    128, 1, 1,
                                    0, NULL, arguments, 0));
          
      HIP_SAFE_CALL(candidatesCountBuffers[i].copyToHost());
    }

    if (checkCandidates) {
      HIP_SAFE_CALL(sieveBuf[0].copyToHost());
      HIP_SAFE_CALL(sieveBuf[1].copyToHost());
      HIP_SAFE_CALL(sieveBuffers[i][0].copyToHost());
      HIP_SAFE_CALL(sieveBuffers[i][1].copyToHost());
      HIP_SAFE_CALL(hipDeviceSynchronize()); 
      
      std::set<mpz_class> multipliers;
      unsigned invalidCount = 0;
      sieveResultsTest(gPrimes,
                       hashes.get(hid).shash,
                       (uint8_t*)sieveBuf[0]._hostData,
                       (uint8_t*)sieveBuf[1]._hostData,
                       mConfig.SIZE*32*mConfig.STRIPES/2,
                       mConfig.TARGET,
                       mConfig.PCOUNT,
                       mConfig.WIDTH-mConfig.TARGET,
                       multipliers,
                       &invalidCount);

      unsigned n320 = candidatesCountBuffers[i][0];
      unsigned n352 = candidatesCountBuffers[i][1];
      unsigned diff = 0;
      for (unsigned j = 0; j < n320; j++) {
        PrimeMiner::fermat_t &c = sieveBuffers[i][0].get(j);
        mpz_class X = ((mpz_class)c.index) << c.origin;
        diff += !multipliers.count(X);
      }
      
      for (unsigned j = 0; j < n352; j++) {
        PrimeMiner::fermat_t &c = (sieveBuffers[i][1]).get(j);
        mpz_class X = ((mpz_class)c.index) << c.origin;
        diff += !multipliers.count(X);
      }      
      
      double coeff = fabs(n320+n352 - multipliers.size()) / multipliers.size();

      if (coeff <= 0.01) {
        LOG_F(INFO, " * [%s] found candidates by CPU: %u by GPU: %u",
               coeff <= 0.01  ? "OK" : "FAILED",
               (unsigned)multipliers.size(),
               n320 + n352);
        LOG_F(INFO, " * [%s] invalid candidates: %u", !invalidCount ? "OK" : "FAILED", invalidCount);
        LOG_F(INFO, " * [%s] CPU/GPU candidates difference: %u", !diff ? "OK" : "FAILED", diff);
      } else {
        LOG_F(ERROR, " * [%s] found candidates by CPU: %u by GPU: %u",
               coeff <= 0.01  ? "OK" : "FAILED",
               (unsigned)multipliers.size(),
               n320 + n352);
        LOG_F(ERROR, " * [%s] invalid candidates: %u", !invalidCount ? "OK" : "FAILED", invalidCount);
        LOG_F(ERROR, " * [%s] CPU/GPU candidates difference: %u", !diff ? "OK" : "FAILED", diff);
      }
    }
  }

  if (!checkCandidates) {
    HIP_SAFE_CALL(hipDeviceSynchronize()); 
    auto gpuEnd = std::chrono::steady_clock::now();  
    auto totalTime = std::chrono::duration_cast<std::chrono::microseconds>(gpuEnd-gpuBegin).count();
    double iterationTime = (double)totalTime / count;
    uint64_t bitsInSieve = mConfig.SIZE*32*mConfig.STRIPES/2*mConfig.WIDTH;
    double scanSpeed = bitsInSieve / iterationTime;
  
    unsigned n320 = 0, n352 = 0;
    for (unsigned i = 0; i < count; i++) {
      n320 += candidatesCountBuffers[i][0];
      n352 += candidatesCountBuffers[i][1];
    }

    LOG_F(INFO, " * iterations: %u", count);
    LOG_F(INFO, " * scan speed: %.3lf G", scanSpeed/1000.0);
    LOG_F(INFO, " * iteration time: %.3lfms", iterationTime/1000.0);
    LOG_F(INFO, " * candidates per second: %.3lf", (n320+n352)/(totalTime/1000000.0));
    LOG_F(INFO, " * candidates per iteration: %.2lf (%.2lf 320bit, %.2lf 352bit)",
           (double)(n320+n352) / count,
           (double)n320 / count,
           (double)n352 / count);
    LOG_F(INFO, " * 320bit/352bit ratio: %.3lf/1", (double)n320/(double)n352);
  }
}

void hipRunBenchmarks(hipCtx_t context,
                       hipDevice_t device,
                       hipModule_t module,
                       unsigned depth,
                       unsigned defaultGroupSize)
{
  hipCtxSetCurrent(context);

  srand(12345);
  const unsigned mPrimorial = 13;
  char deviceName[128];
  int computeUnits;
  hipBuffer<config_t> mConfig;
  mpz_class allPrimorials[maxHashPrimorial];
  HIP_SAFE_CALL(hipDeviceGetName(deviceName, sizeof(deviceName), device));
  HIP_SAFE_CALL(hipDeviceGetAttribute(&computeUnits, hipDeviceAttributeMultiprocessorCount, device));
  LOG_F(INFO, "Benchmarking %s; %u compute units", deviceName, computeUnits);

  std::unique_ptr<hipFunction_t[]> kernels(new hipFunction_t[CUDAKernelsNum]);
  for (unsigned i = 0; i < CUDAKernelsNum; i++)
    HIP_SAFE_CALL(hipModuleGetFunction(&kernels[i], module, gCUDAKernelNames[i]));

  // Get miner config
  {
    HIP_SAFE_CALL(mConfig.init(1, false));
    void *args[] = { &mConfig._deviceData };
    HIP_SAFE_CALL(hipModuleLaunchKernel(kernels[CUDAKernelGenConfig],
                                  1, 1, 1,
                                  1, 1, 1,
                                  0, NULL, args, 0));
    HIP_SAFE_CALL(hipDeviceSynchronize());
    HIP_SAFE_CALL(mConfig.copyToHost());
  }

  {
    for (unsigned i = 0; i < maxHashPrimorial - mPrimorial; i++) {
      mpz_class p = 1;
      for(unsigned j = 0; j <= mPrimorial+i; j++)
        p *= gPrimes[j];

      allPrimorials[i] = p;
    }
  }
  
  hipMultiplyBenchmark(kernels.get(), computeUnits*4, 320/32, 262144, true);
  hipMultiplyBenchmark(kernels.get(), computeUnits*4, 320/32, 262144, false);
  hipMultiplyBenchmark(kernels.get(), computeUnits*4, 352/32, 262144, true);
  hipMultiplyBenchmark(kernels.get(), computeUnits*4, 352/32, 262144, false);
  hipFermatTestBenchmark(kernels.get(), computeUnits*4, 320/32, 262144);
  hipFermatTestBenchmark(kernels.get(), computeUnits*4, 352/32, 262144);
  hipHashmodBenchmark(kernels.get(), defaultGroupSize, 0, allPrimorials, mPrimorial);
  hipSieveTestBenchmark(kernels.get(), defaultGroupSize, computeUnits*4, allPrimorials, mPrimorial, *mConfig._hostData, depth, true);
  hipSieveTestBenchmark(kernels.get(), defaultGroupSize, computeUnits*4, allPrimorials, mPrimorial, *mConfig._hostData, depth, false);  
}
