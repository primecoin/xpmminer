#include "hip/hip_runtime.h"
#include "hiputil.h"
#include <string.h>
#include <fstream>
#include <iostream>
#include <memory>

bool hipCompileKernel(const char *kernelName,
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
    HIPRTC_SAFE_CALL(
      hiprtcCreateProgram(&prog,
                         sourceFile.c_str(),
                         "xpm.hip",
                         0,
                         NULL,
                         NULL));

    hiprtcResult compileResult = hiprtcCompileProgram(prog, argumentsNum, arguments);

    // Obtain compilation log from the program.
    size_t logSize;
    HIPRTC_SAFE_CALL(hiprtcGetProgramLogSize(prog, &logSize));
    char *log = new char[logSize];
    HIPRTC_SAFE_CALL(hiprtcGetProgramLog(prog, log));

    // Always print log to help with debugging
    if (logSize > 1) {
      LOG_F(INFO, "HIPRTC Compilation log:\n%s", log);
    }

    if (compileResult != HIPRTC_SUCCESS) {
      LOG_F(ERROR, "hiprtcCompileProgram error: %s", hiprtcGetErrorString(compileResult));
      if (logSize > 1) {
        LOG_F(ERROR, "Compilation errors:\n%s", log);
      }
      delete[] log;
      return false;
    }
    delete[] log;

    // Obtain PTX from the program.
    size_t ptxSize;
    HIPRTC_SAFE_CALL(hiprtcGetCodeSize(prog, &ptxSize));
    char *ptx = new char[ptxSize];
    HIPRTC_SAFE_CALL(hiprtcGetCode(prog, ptx));

    // Destroy the program.
    HIPRTC_SAFE_CALL(hiprtcDestroyProgram(&prog));

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

  std::unique_ptr<char[]> code(new char[binsize+1]);
  bfile.read(code.get(), binsize);
  bfile.close();

  LOG_F(INFO, "Loading HIP module from %s (%zu bytes)", kernelName, binsize);

  hipError_t result = hipModuleLoadData(module, code.get());
  if (result != hipSuccess) {
    const char *msg = hipGetErrorName(result);
    LOG_F(ERROR, "Loading HIP module failed with error %s", msg);
    LOG_F(ERROR, "Module size: %zu bytes, first 16 bytes: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x",
          binsize,
          (unsigned char)code[0], (unsigned char)code[1], (unsigned char)code[2], (unsigned char)code[3],
          (unsigned char)code[4], (unsigned char)code[5], (unsigned char)code[6], (unsigned char)code[7],
          (unsigned char)code[8], (unsigned char)code[9], (unsigned char)code[10], (unsigned char)code[11],
          (unsigned char)code[12], (unsigned char)code[13], (unsigned char)code[14], (unsigned char)code[15]);
    return false;
  }

  LOG_F(INFO, "HIP module loaded successfully");
  return true;
}
