#include "xpmclient.h"

void cudaRunBenchmarks(hipCtx_t context,
                       hipDevice_t device,
                       hipModule_t module,
                       unsigned depth,
                       unsigned defaultGroupSize);
