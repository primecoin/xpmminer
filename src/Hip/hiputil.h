#ifndef __HIPLIB_H_
#define __HIPLIB_H_

#include <hip/hip_runtime_api.h>
#include <hip/hiprtc.h>
#include "loguru.hpp"
#include <string>
#include <vector>

#define HIPRTC_SAFE_CALL(x) \
do { \
  hiprtcResult result = x; \
  if (result != HIPRTC_SUCCESS) { \
    LOG_F(ERROR, "\nerror: %i\nfailed with error %s at %s:%d", static_cast<int>(result), hiprtcGetErrorString(result), __FILE__, __LINE__); \
    exit(1); \
  } \
} while(0)

#define HIP_SAFE_CALL(x) \
do { \
  hipError_t result = x; \
  if (result != hipSuccess) { \
    const char *msg; \
    msg = hipGetErrorName(result); \
    LOG_F(ERROR, "\nerror: %i\nfailed with error %s at %s:%d\n", static_cast<int>(result), msg, __FILE__, __LINE__); \
    exit(1); \
  } \
} while(0)


template<typename T>
class hipBuffer {
public:
  size_t _size;
  T *_hostData;
  hipDeviceptr_t _deviceData;

public:
  hipBuffer() : _size(0), _hostData(0), _deviceData(0) {}
  ~hipBuffer() {
    delete[] _hostData;
    if (_deviceData) {
      hipError_t result = hipFree((void*)_deviceData);
      if (result != hipSuccess) {
        const char *msg;
        msg = hipGetErrorName(result);
        LOG_F(ERROR, "HIP memory free failed with error %s code: %i\n", msg, static_cast<int>(result));
      }
    }
  }

  hipError_t init(size_t size, bool hostNoAccess) {
    _size = size;
    if (!hostNoAccess)
      _hostData = new T[size];
    return hipMalloc((void**)&_deviceData, sizeof(T)*size);
  }

  hipError_t copyToDevice() {
    return hipMemcpyHtoD(_deviceData, _hostData, sizeof(T)*_size);
  }

  hipError_t copyToDevice(hipStream_t stream) {
    return hipMemcpyHtoDAsync(_deviceData, _hostData, sizeof(T)*_size, stream);
  }

  hipError_t copyToDevice(T *hostData) {
    return hipMemcpyHtoD(_deviceData, hostData, sizeof(T)*_size);
  }

  hipError_t copyToDevice(T *hostData, hipStream_t stream) {
    return hipMemcpyHtoDAsync(_deviceData, hostData, sizeof(T)*_size, stream);
  }

  hipError_t copyToHost() {
    return hipMemcpyDtoH(_hostData, _deviceData, sizeof(T)*_size);
  }

  hipError_t copyToHost(hipStream_t stream) {
    return hipMemcpyDtoHAsync(_hostData, _deviceData, sizeof(T)*_size, stream);
  }

  T& get(int index) {
    return _hostData[index];
  }

  T& operator[](int index) {
    return _hostData[index];
  }
};


bool hipCompileKernel(const char *kernelName,
                      const std::vector<const char*> &sources,
                      const char **arguments,
                      int argumentsNum,
                      hipModule_t *module,
                      int majorComputeCapability,
                      int minorComputeCapability,
                      bool needRebuild);

#endif //__HIPLIB_H_
