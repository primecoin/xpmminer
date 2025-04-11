#ifndef SYSTEM_H
#define SYSTEM_H

#include <stdint.h>
#include <chrono>
#if defined(__GXX_EXPERIMENTAL_CXX0X__) && (__cplusplus < 201103L)
#define steady_clock monotonic_clock
#endif  

#define MaxChainLength 20

struct PrimeSource;
struct GetBlockTemplateContext;
struct SubmitContext;
struct OpenCLPlatrormContext;
struct OpenCLDeviceContext;

struct MineContext {
    PrimeSource* primeSource;
    GetBlockTemplateContext* gbp;
    SubmitContext* submit;
    unsigned threadIdx;
    OpenCLPlatrormContext *platform;
    OpenCLDeviceContext *device;
    uint64_t totalRoundsNum;
    uint64_t foundChains[MaxChainLength];
    double speed;
    void* log;
};

enum PathTy {
  PtExecutable = 0,
  PtLibrary,
  PtData
};

typedef std::chrono::time_point<std::chrono::steady_clock> timeMark;

timeMark getTimeMark();
uint64_t usDiff(timeMark first, timeMark second);

const char *installPrefix();
const char *buildPath(PathTy type, const char *fileName);
void xsleep(unsigned seconds);

void printMiningStats(timeMark workBeginPoint, MineContext* mineCtx, int threadsNum, double sieveSizeInGb, unsigned blockHeight, double difficulty);
#endif // SYSTEM_H