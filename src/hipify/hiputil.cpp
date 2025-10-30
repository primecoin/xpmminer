#include "hip/hip_runtime.h"
#include "cudautil.h"
#include <string.h>
#include <fstream>
#include <iostream>
#include <memory>

bool cudaCompileKernel(const char *kernelName,
                       const std::vector<const char*> &sources,
                       const char **arguments,
                       int argumentsNum,
                       hipModule_t *module,
                       int majorComputeCapability,
                       int,
                       bool needRebuild) 
{
  std::ifstream testfile(kernelName);
  if(needRebuild || !testfile) {
    LOG_F(INFO, "compiling ...");
    
    std::string sourceFile;
    for (auto &i: sources) {
      std::ifstream stream(i);
      std::string str((std::istreambuf_iterator<char>(stream)), std::istreambuf_iterator<char>());
      sourceFile.append(str);
    }
    
    LOG_F(INFO, "source: %u bytes", (unsigned)sourceFile.size());
    if(sourceFile.size() < 1){
      LOG_F(ERROR, "source files not found or empty");
      return false;
    }
    
    hiprtcProgram prog;
    NVRTC_SAFE_CALL(
      hiprtcCreateProgram(&prog,
                         sourceFile.c_str(),
                         "xpm.cu",
                         0,
                         NULL,
                         NULL));

    hiprtcResult compileResult = hiprtcCompileProgram(prog, argumentsNum, arguments);

    // Obtain compilation log from the program.
    size_t logSize;
    NVRTC_SAFE_CALL(hiprtcGetProgramLogSize(prog, &logSize));
    char *log = new char[logSize];
    NVRTC_SAFE_CALL(hiprtcGetProgramLog(prog, log));

    if (compileResult != HIPRTC_SUCCESS) {
      LOG_F(ERROR, "hiprtcCompileProgram error: %s", hiprtcGetErrorString(compileResult));
      LOG_F(ERROR, "Compilation log:\n%s", log);
      delete[] log;
      return false;
    }

    // Print log even on success if there are warnings
    if (logSize > 1) {
      LOG_F(INFO, "Compilation log:\n%s", log);
    }
    delete[] log;
    
    // Obtain PTX from the program.
    size_t ptxSize;
    NVRTC_SAFE_CALL(hiprtcGetCodeSize(prog, &ptxSize));
    char *ptx = new char[ptxSize];
    NVRTC_SAFE_CALL(hiprtcGetCode(prog, ptx));
    
    // Destroy the program.
    NVRTC_SAFE_CALL(hiprtcDestroyProgram(&prog));
    
    {
      std::ofstream bin(kernelName, std::ofstream::binary | std::ofstream::trunc);
      bin.write(ptx, ptxSize);
      bin.close();      
    }
    
    delete[] ptx;
  }
  
  std::ifstream bfile(kernelName, std::ifstream::binary);
  if(!bfile) {
    return false;
  }  
  
  bfile.seekg(0, bfile.end);
  size_t binsize = bfile.tellg();
  bfile.seekg(0, bfile.beg);
  if(!binsize){
    LOG_F(ERROR, "%s empty", kernelName);
    return false;
  }
  
  std::unique_ptr<char[]> ptx(new char[binsize+1]);
  bfile.read(ptx.get(), binsize);
  bfile.close();
  
  hipError_t result = hipModuleLoadDataEx(module, ptx.get(), 0, 0, 0);
  if (result != hipSuccess) {
    if (result == hipErrorInvalidKernelFile || result == CUDA_ERROR_UNSUPPORTED_PTX_VERSION) {
      LOG_F(WARNING, "GPU Driver version too old, update recommended");
      LOG_F(WARNING, "Workaround: downgrade version in PTX to 6.0 ...");
      char *pv = strstr(ptx.get(), ".version ");
      if (pv) {
        pv[9] = '6';
        pv[11] = '0';
      }

      CUDA_SAFE_CALL(hipModuleLoadDataEx(module, ptx.get(), 0, 0, 0));
    } else {
      const char *msg;
      hipDrvGetErrorName(result, &msg);
      LOG_F(ERROR, "Loading CUDA module failed with error %s", msg);
      return false;
    }
  }

  return true;
}
