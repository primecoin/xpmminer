#include "CSieveOfEratosthenesL1Ext.h"
#include "Debug.h"
#include "benchmarks.h"
#include "config.h"
#include "getblocktemplate.h"
#include "primecoin.h"
#include "system.h"
#include "utils.h"

#include <openssl/bn.h>

#include "getopt.h"
#include <stdlib.h>
#include <algorithm>
#include <memory>

#ifdef DEBUG_MINING_AMD_OPENCL
extern "C" {
#include "GPUPerfAPI.h"
}
#endif

unsigned gDebug = 1;
int gChainLength = 10;
int gExtensionsNum = 9;
int gPrimorial = 19;
int gSieveSize = GPUSieveWindowSize * 112;
int gWeaveDepth = 8192-256;
int extraNonce = 0;

static const char *gWallet = 0;
static const char *gUrl = "127.0.0.1:9912";
static const char *gUserName = 0;
static const char *gPassword = 0;

enum CmdLineOptions {
  clDebug = 0,
  clBenchmark,
  clExtensionsNum,
  clPrimorial,
  clSieveSize,
  clWeaveDepth,
  clPlatrorm,
  clUseCPU,
  clDisableOpt,
  clUrl,
  clUser,
  clPass,
  clWallet,
  clWorkerId,
  clHelp,
  clOptionLast,
  clOptionsNum
};

void initCmdLineOptions(option *options)
{
  options[clDebug] = {"debug", no_argument, 0, 0};
  options[clBenchmark] = {"benchmark", no_argument, 0, 'b'};
  options[clExtensionsNum] = {"extensions-num", required_argument, &gExtensionsNum, 0};
  options[clPrimorial] = {"primorial", required_argument, &gPrimorial, 0};
  options[clSieveSize] = {"sieve-size", required_argument, &gSieveSize, 0};
  options[clWeaveDepth] = {"weave-depth", required_argument, &gWeaveDepth, 0};
  options[clPlatrorm] = {"opencl-platform", required_argument, 0, 0};
  options[clUseCPU] = {"use-cpu", no_argument, 0, 0};
  options[clDisableOpt] = {"disable-opt", no_argument, 0, 0};
  options[clUrl] = {"url", required_argument, 0, 'o'};
  options[clUser] = {"user", required_argument, 0, 'u'};
  options[clPass] = {"pass", required_argument, 0, 'p'};
  options[clWallet] = {"wallet", required_argument, 0, 'w'};
  options[clWorkerId] = {"worker-id", required_argument, &extraNonce, 0};    
  options[clHelp] = {"help", no_argument, 0, 'h'};
  options[clOptionLast] = {0, 0, 0, 0};
}

void primorialsPrint(unsigned count)
{
  PrimeSource primeSource(1000000, 0);
  for (unsigned i = 0; i < 10000; i++) {
    printf("[%u] %u\n", i, primeSource.prime(i));
  }
  
  for (unsigned i = 1; i <= count; i++) {
    mpz_class primorial;
    PrimorialFast(i, primorial, primeSource);
    fprintf(stderr,
            "[%u] (%u) %s\n",
            i,
            (unsigned)mpz_sizeinbase(primorial.get_mpz_t(), 2),
            primorial.get_str(10).c_str());
  }
}

void copyMultiplierToBlock(PrimecoinBlockHeader &header, const mpz_class &primorial, unsigned M)
{
  uint8_t buffer[256];
  BIGNUM *xxx = 0;
  mpz_class targetMultiplier = primorial*M;
  gmp_printf("Multiplier = %Zd\n", targetMultiplier.get_mpz_t());
  BN_dec2bn(&xxx, targetMultiplier.get_str().c_str());
  BN_bn2mpi(xxx, buffer);
  header.multiplier[0] = buffer[3];
  std::reverse_copy(buffer+4, buffer+4+buffer[3], header.multiplier+1);
}

void *mine(void *arg)
{
  PrimeSource primeSource(1000000, gWeaveDepth+256);
  CPrimalityTestParams testParams(bitsFromDifficulty(10));  
  MineContext *ctx = (MineContext*)arg;
  OpenCLDeviceContext &device = *ctx->device;
  
  mpz_class primorial;
  PrimorialFast(gPrimorial, primorial, primeSource);  
  if (int error = OpenCLKernelsPrepare(*ctx->platform, device, primeSource, primorial, GPUMaxSieveSize,
                                       gWeaveDepth+256, MaxChainLength, gExtensionsNum))
    exit(error);
  
  blktemplate_t *workTemplate = 0;
  PrimecoinBlockHeader work;
  unsigned dataId;
  mpz_class blockHeaderHash;

  unsigned realSieveSize = gSieveSize + gSieveSize/2*gExtensionsNum;    
  const unsigned checkInterval = 8;
  double roundSizeInGb = (uint64_t)checkInterval*realSieveSize*device.groupsNum / 1000000000.0;
  unsigned roundsNum = 0;    

  std::unique_ptr<GPUNonceAndHash[]> nonceAndHash(new GPUNonceAndHash[device.groupsNum]); 
  std::unique_ptr<FermatQueue[]> queue(new FermatQueue[device.groupsNum]);
  std::unique_ptr<FermatTestResults[]> results_(new FermatTestResults[device.groupsNum]);
  memset(nonceAndHash.get(), 0, sizeof(GPUNonceAndHash)*device.groupsNum);
  memset(queue.get(), 0, sizeof(FermatQueue)*device.groupsNum);

  timeMark localWorkBegin = getTimeMark();
  while (1) {
    bool hasChanged;
    while ( !(workTemplate = ctx->gbp->get(ctx->threadIdx, workTemplate, &dataId, &hasChanged)) )
      usleep(1000);
    
    timeMark roundBegin = getTimeMark();    

    if (hasChanged) {
      cl_int result[2];
      cl_event event[2];
      
      work.version = workTemplate->version;
      memcpy(work.hashPrevBlock, workTemplate->prevblk, 32);
      memcpy(work.hashMerkleRoot, workTemplate->_mrklroot, 32);
      work.time = workTemplate->curtime;
      work.bits = *(uint32_t*)workTemplate->diffbits;
      memset(nonceAndHash.get(), 0, sizeof(GPUNonceAndHash)*device.groupsNum);

      OpenCLNewBlockPrepare(device, device.groupsNum, work,
                            nonceAndHash.get(), queue.get());
    }

    if (OpenCLMiningRound(device, device.groupsNum, results_.get())) {
      for (unsigned groupIdx = 0; groupIdx < device.groupsNum; groupIdx++) {
        FermatTestResults &results = results_[groupIdx];
        for (unsigned i = 0; i < results.size; i++) {
          unsigned chainLength = results.resultChainLength[i];
          ctx->foundChains[chainLength]++;
          if (chainLength >= chainLengthFromBits(work.bits)) {
            // TODO: check block
            printf("chain found!\n");
            uint8_t hash1[32];
            uint8_t hashData[32];    
            work.nonce = results.resultNonces[i];        
            sha256(hash1, &work, 80);
            sha256(hashData, hash1, 32);                      
            mpz_class blockHeaderHash;
            mpz_import(blockHeaderHash.get_mpz_t(),
                       32 / sizeof(unsigned long),
                       -1,
                       sizeof(unsigned long),
                       -1,
                       0,
                       hashData);
            unsigned triedMultiplier = results.resultMultipliers[i];
            mpz_class fixedMultiplier = blockHeaderHash*primorial;     
            mpz_class chainOrigin = fixedMultiplier * triedMultiplier;

            CPrimalityTestParams testParams(bitsFromDifficulty(10));
            testParams.candidateType = results.resultTypes[i];

            ProbablePrimeChainTestFast(chainOrigin, testParams);
            std::string chainName = GetPrimeChainName(testParams.candidateType, testParams.chainLength);
            fprintf(stderr, "Found chain: %s\n", chainName.c_str());

            std::string nbitsTarget = TargetToString(work.bits);
            fprintf(stderr, "Target (nbits): %s\n", nbitsTarget.c_str());

            gmp_printf("chainOrigin: %Zd\n", chainOrigin.get_mpz_t());
            copyMultiplierToBlock(work, primorial, results.resultMultipliers[i]);
            ctx->submit->submitBlock(workTemplate, work, dataId); 
            printf("\n");
          }
        }
      }
    }
      
    roundsNum++;
    if (roundsNum == checkInterval) {
      timeMark point = getTimeMark();
      uint64_t timeElapsed = usDiff(localWorkBegin, point);
        
      ctx->totalRoundsNum += checkInterval*device.groupsNum;
      ctx->speed = roundSizeInGb / (timeElapsed / 1000000.0);
        
      roundsNum = 0;
      localWorkBegin = getTimeMark();
    }
  }
}

void printHelpMessage() 
{
  printf("Opensource primecoin GPU miner, usage:\n");
  printf("  xpmclminer <arguments>\n\n");
  printf("  -h or --help: show this help message\n");
  printf("  -b or --benchmark: run benchmark and exit\n");
  printf("  -o or --url <HostAddress:port>: address of primecoin RPC client, default: %s\n", gUrl);
  printf("  -u or --user <UserName>: user name for primecoin RPC client\n");
  printf("  -p or --pass <Password>: password for primecoin RPC client\n");
  printf("  -w or --wallet: wallet address for coin receiving\n");
  printf("  --debug: show additional mining information\n");
  printf("  --extensions-num <number>: Eratosthenes sieve extensions number (default: %u)\n", gExtensionsNum);
  printf("  --primorial <number>: primorial number (default: %u)\n", gPrimorial);
  printf("  --sieve-size <number>: Eratosthenes sieve size, must be multiply of sieving window size(%u) (default: %u)\n",
         GPUSieveWindowSize, gSieveSize);
  printf("  --weave-depth <number>: Eratosthenes sieve weave depth (default: %u)\n", gWeaveDepth);
  printf("  --opencl-platform: OpenCL platform name, (default: Advanced Micro Devices, Inc.)\n");
  printf("  --use-cpu: run code on CPU (for debugging purposes)\n");
  printf("  --disable-opt: disables OpenCL code optimizations (for debugging purposes)\n");
  printf("  --worker-id: unique identifier of your worker, used in block creation. ");
  printf("All your rigs must have different worker IDs! (default: current time value)\n");
}

int main(int argc, char **argv)
{
  srand(time(0));  
  blkmk_sha256_impl = sha256;  
  option gOptions[clOptionsNum];
  
  bool isBenchmark = false;
  bool useCPU = false;
  bool disableOpt = false;
  int index = 0, c;
  initCmdLineOptions(gOptions);
  const char *platform = "Advanced Micro Devices, Inc.";
  while ((c = getopt_long(argc, argv, "bo:u:p:w:h", gOptions, &index)) != -1) {
    switch (c) {
      case 0 :
        switch (index) {
          case clDebug :
            gDebug = 1;
            break;
          case clExtensionsNum :
            gExtensionsNum = atoi(optarg);
            break;
          case clPrimorial :
            gPrimorial = atoi(optarg);
            if (gPrimorial > 19) {
              fprintf(stderr, "OpenCL implementation does not support more than 384-bit "
                              "multiprecision arithmetic, primorial limited to 19\n");
              exit(1);
            }
            break;
          case clSieveSize :
            gSieveSize = atoi(optarg);
            if (gSieveSize % GPUSieveWindowSize != 0) {
              fprintf(stderr, "Sieve size must be a multiple of %u\n", GPUSieveWindowSize);
              exit(1);
            }
            if (gSieveSize > GPUMaxSieveSize) {
              fprintf(stderr, "Sieve size limited by %u, you try launch with %u\n",
                      GPUMaxSieveSize, gSieveSize);
              exit(1);
            }
            break;
          case clWeaveDepth :
            gWeaveDepth = atoi(optarg);
            break;
          case clWorkerId :
            extraNonce = atoi(optarg);
            break;
          case clPlatrorm :
            platform = optarg;
            break;
          case clUseCPU :
            useCPU = true;
            break;
          case clDisableOpt :
            disableOpt = true;
            break;
        }
        break;
      case 'b' :
        isBenchmark = true;
        break;
      case 'o' :
        gUrl = optarg;
        break;
      case 'u' :
        gUserName = optarg;
        break;
      case 'p' :
        gPassword = optarg;
        break;
      case 'w' :
        gWallet = optarg;
        break;
      case 'h' :
        printHelpMessage();
        exit(0);
        break;
      case ':' :
        fprintf(stderr, "Error: option %s missing argument\n",
                gOptions[index].name);
        break;
      case '?' :
        fprintf(stderr, "Error: invalid option %s\n", argv[optind-1]);
        break;
      default :
        break;
    }
  }
  
  if ((!gUserName || !gPassword) && !isBenchmark) {
    fprintf(stderr, "Error: you must specify user name and password\n");
    exit(1);
  }
  
  if (!gWallet && !isBenchmark) {
    fprintf(stderr, "Error: you must specify wallet\n");
    exit(1);
  }
  
  if (extraNonce == 0)
    extraNonce = time(0);  
  
#ifdef DEBUG_MINING_AMD_OPENCL
  if (GPA_Initialize() != GPA_STATUS_OK)
    return logError(1, stderr, "GPA_Initialize error\n");
#endif
  
  std::vector<unsigned> devices;
  OpenCLPlatrormContext ctx;
  if (int error = OpenCLInit(ctx, platform, devices, gPrimorial, gSieveSize,
                             GPUSieveWindowSize, gWeaveDepth,
                             gExtensionsNum, gChainLength, useCPU, disableOpt))
    return error;
  
  PrimeSource primeSource(10000000, gWeaveDepth + 256);  
  mpz_class primorial;
  PrimorialFast(gPrimorial, primorial, primeSource);
  
  if (isBenchmark) {
    for (size_t i = 0; i < ctx.devicesNum; i++) {
      printf(" * GPU %u benchmark start:\n", (unsigned)i+1);
      OpenCLDeviceContext &device = ctx.devices[i];          
      if (int error = OpenCLKernelsPrepare(ctx, device, primeSource, primorial, GPUMaxSieveSize,
                                           gWeaveDepth+256, MaxChainLength, gExtensionsNum))
        return error;      

      multiplyBenchmark(device, 256/32, 262144);
      multiplyBenchmark(device, 384/32, 262144);
      multiplyBenchmark(device, 448/32, 262144);
      moduloBenchmark(device, 512/32, 384/32, 262144);
      moduloBenchmark(device, 640/32, 512/32, 262144);      
      fermatTestBenchmark(device, 256/32, 65536);      
      fermatTestBenchmark(device, 384/32, 65536);
      fermatTestBenchmark(device, 448/32, 65536);      
      
      printf("   * sieve with checking results\n");
      sieveBenchmark(primeSource, primorial, device, 10.5, true);         

      printf("   * sieve performance test\n");      
      sieveBenchmark(primeSource, primorial, device, 10.5, false);      
      
      printf("   * mine with checking results\n");      
      gpuMinerBenchmark(device, 10.5, 32, true);      
      
      printf("   * mine performance test\n");        
      gpuMinerBenchmark(device, 10.5, 32, false);
    }
    
    return 0;
  }
 
  void *display = 0;
  void *log = 0;
 
  GetBlockTemplateContext gbp(log, gUrl, gUserName, gPassword, gWallet, 4, ctx.devicesNum, extraNonce);
  gbp.run();
  
  MineContext *mineCtx = new MineContext[ctx.devicesNum];  
  for (unsigned i = 0; i < ctx.devicesNum; i++) {
    pthread_t thread;    
    mineCtx[i].primeSource = &primeSource;
    mineCtx[i].gbp = &gbp;
    mineCtx[i].platform = &ctx;
    mineCtx[i].device = &ctx.devices[i];
    mineCtx[i].threadIdx = i;
    mineCtx[i].totalRoundsNum = 0;
    memset(mineCtx[i].foundChains, 0, sizeof(mineCtx->foundChains)); 
    mineCtx[i].submit = new SubmitContext(log, gUrl, gUserName, gPassword);    
    mineCtx[i].log = log;
    pthread_create(&thread, 0, mine, &mineCtx[i]);
  }
  
  unsigned realSieveSize = gSieveSize + gSieveSize/2*gExtensionsNum;    
  double sieveSizeInGb = realSieveSize / 1000000000.0;
  timeMark workBeginPoint = getTimeMark();
  
  {
    time_t rawtime;
    struct tm * timeinfo;          
    char buffer[80];
    time (&rawtime);
    timeinfo = localtime(&rawtime);
    strftime(buffer,80, "%d-%m-%Y %H:%M:%S", timeinfo);
    printf(" ** xpmclminer started %s %s %s worker %i **\n", buffer, gUrl, gWallet, extraNonce);
  }  
  
  unsigned counter = 0;
  while (true) {
    xsleep(5);
    printMiningStats(workBeginPoint, mineCtx, ctx.devicesNum, sieveSizeInGb, gbp.getBlockHeight(), gbp.getDifficulty());

    // Workaround about AMD Catalyst bug (prevents performance dropping on
    // Multi-GPU configurations
    if ((counter++ % 16) == 0) {
      for (size_t i = 0; i < ctx.devicesNum; i++) {
        cl_event event;
        OpenCLDeviceContext &device = ctx.devices[i];          
        size_t globalThreads[1] = { device.groupsNum*device.groupSize};
        size_t localThreads[1] = { device.groupSize };        
        if ((clEnqueueNDRangeKernel(device.queue, device.kernels[CLKernelEmpty],
                                    1, 0, globalThreads, localThreads, 0, 0, &event)) == CL_SUCCESS) {
          clReleaseEvent(event);
        }
      }
    }
  }
  
  return 0;
}