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

    // Print log if there are warnings or errors
    if (logSize > 1) {
      LOG_F(INFO, "Compilation log:\n%s", log);
    }
    delete[] log;

    if (compileResult != HIPRTC_SUCCESS) {
      LOG_F(ERROR, "hiprtcCompileProgram error: %s", hiprtcGetErrorString(compileResult));
      return false;
    }

    // Obtain code (machine code or LLVM bitcode) from the program.
    // Note: HIP uses hiprtcGetCode() instead of nvrtcGetPTX()
    size_t codeSize;
    HIPRTC_SAFE_CALL(hiprtcGetCodeSize(prog, &codeSize));
    char *code = new char[codeSize];
    HIPRTC_SAFE_CALL(hiprtcGetCode(prog, code));

    // Destroy the program.
    HIPRTC_SAFE_CALL(hiprtcDestroyProgram(&prog));

    {
      std::ofstream bin(kernelName, std::ofstream::binary | std::ofstream::trunc);
      bin.write(code, codeSize);
      bin.close();
    }

    delete[] code;
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

  hipError_t result = hipModuleLoadData(module, code.get());
  if (result != hipSuccess) {
    const char *msg;
    msg = hipGetErrorName(result);
    LOG_F(ERROR, "Loading HIP module failed with error %s", msg);
    return false;
  }

  return true;
}
