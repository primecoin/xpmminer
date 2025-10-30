#include "xpmclient_hip.h"

void hipRunBenchmarks(hipCtx_t context,
                      hipDevice_t device,
                      hipModule_t module,
                      unsigned depth,
                      unsigned defaultGroupSize);