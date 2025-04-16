#include "system.h"
#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/time.h>
#endif

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "config.h"

timeMark getTimeMark()
{
  return std::chrono::steady_clock::now();
}


uint64_t usDiff(timeMark first, timeMark second)
{
  return std::chrono::duration_cast<std::chrono::microseconds>(second-first).count();
}

const char *installPrefix()
{
  return CMAKE_INSTALL_PREFIX;
}

const char *buildPath(PathTy type, const char *fileName)
{
#ifdef WIN32
  char Prefix[MAX_PATH];
  DWORD pathSize =
  GetModuleFileName(GetModuleHandle(NULL), Prefix, sizeof(Prefix));
  
  char *p = Prefix + pathSize;
  while (p > Prefix) {
    if (*p == '\\') {
      *p = 0;
      break;
    }
    p--;
  }
  
  const char *dir = "\\";
#else
  // TODO: сделать директорию установки настраиваемой
  const char Prefix[] = CMAKE_INSTALL_PREFIX;
  
  const char *dir;
  switch (type) {
    case PtExecutable :
      dir = "/bin/";
      break;
    case PtLibrary :
      dir = "/lib/";
      break;
    case PtData :
      dir = "/share/xpmminer/";
      break;
  }
#endif  
  char *path = (char*)
  malloc(sizeof(Prefix)-1 + strlen(dir) + strlen(fileName) + 1);
  strcpy(path, Prefix);
  strcat(path, dir);
  strcat(path, fileName);
  return (const char*)path;
  
}

void xsleep(unsigned seconds)
{
#ifndef WIN32
    sleep(seconds);
#else
    Sleep(seconds*1000);
#endif   
}

void printMiningStats(timeMark workBeginPoint, MineContext* mineCtx, int threadsNum, double sieveSizeInGb, unsigned blockHeight, double difficulty)
{
    static timeMark lastPrintTime = getTimeMark();
    uint64_t timeElapsed = usDiff(lastPrintTime, getTimeMark());
    if (timeElapsed < 60000000) {  
        return;
    }
    lastPrintTime = getTimeMark();

    printf(" ** block: %u, difficulty: %.3lf\n", blockHeight, difficulty);
    
    timeMark currentPoint = getTimeMark();    
    uint64_t elapsedTime = usDiff(workBeginPoint, currentPoint);
    double speed = 0.0;
    double averageSpeed = 0.0;
    uint64_t foundChains[MaxChainLength] = {0};
    
    for (int i = 0; i < threadsNum; i++) {
        for (unsigned chIdx = 1; chIdx < MaxChainLength; chIdx++)
            foundChains[chIdx] += mineCtx[i].foundChains[chIdx];
        
        double threadAvgSpeed = (sieveSizeInGb * mineCtx[i].totalRoundsNum) / (elapsedTime / 1000000.0);
        speed += mineCtx[i].speed;
        averageSpeed += threadAvgSpeed;
        
        printf("    [thread %u] %.3lfG, average: %.3lfG\n", i+1, mineCtx[i].speed, threadAvgSpeed);
    }
    
    printf(" ** total speed: %.3lfG, average: %.3lfG\n", speed, averageSpeed);
    unsigned chIdx;
    
    for (chIdx = 1; chIdx < MaxChainLength && foundChains[chIdx]; chIdx++) {
        double chainsPerSec = foundChains[chIdx] / (elapsedTime / 1000000.0);
        printf("   * chains/%u: %lu %.3lf/sec ",
                chIdx, foundChains[chIdx], chainsPerSec);
        if (chIdx >= 7)
            printf("%.3lf/hour ", chainsPerSec * 3600.0);
    }
    printf("\n\n");
}
