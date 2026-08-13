/*
 * metalutil.h
 *
 * Metal utility functions and buffer management
 * Ported from hiputil.h for Apple Metal API
 */

#ifndef __METALUTIL_H_
#define __METALUTIL_H_

#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "loguru.hpp"
#include <new>
#include <string>
#include <vector>

// Error handling macros for Metal
#define METAL_CHECK(condition, message) \
do { \
  if (!(condition)) { \
    LOG_F(ERROR, "Metal error: %s at %s:%d", message, __FILE__, __LINE__); \
    exit(1); \
  } \
} while(0)

/**
 * MetalBuffer template class
 * Manages memory buffers that can be accessed by both CPU and GPU
 * Uses unified memory on Apple Silicon for efficient data sharing
 */
template<typename T>
class MetalBuffer {
public:
    size_t _size;
    T *_hostData;
    id<MTLBuffer> _deviceBuffer;
    id<MTLDevice> _device;

public:
    MetalBuffer() : _size(0), _hostData(nullptr), _deviceBuffer(nil), _device(nil) {}

    ~MetalBuffer() {
        delete[] _hostData;
        // ARC will automatically release _deviceBuffer
        _deviceBuffer = nil;
    }

    /**
     * Initialize the buffer with specified size
     * @param device Metal device
     * @param size Number of elements (not bytes)
     * @param hostNoAccess If true, skip host-side allocation (GPU-only buffer)
     * @return true if successful, false otherwise
     */
    bool init(id<MTLDevice> device, size_t size, bool hostNoAccess = false) {
        _device = device;
        _size = size;

        if (!hostNoAccess) {
            _hostData = new (std::nothrow) T[size];
            if (!_hostData) {
                LOG_F(ERROR, "Failed to allocate host memory for buffer");
                return false;
            }
        }

        // Use shared storage mode for unified memory access on Apple Silicon
        // This allows zero-copy access between CPU and GPU
        _deviceBuffer = [device newBufferWithLength:sizeof(T) * size
                                            options:MTLResourceStorageModeShared];

        if (!_deviceBuffer) {
            LOG_F(ERROR, "Failed to create Metal buffer");
            delete[] _hostData;
            _hostData = nullptr;
            return false;
        }

        return true;
    }

    /**
     * Copy data from host to device
     * On Apple Silicon with shared memory, this is just a memcpy
     */
    void copyToDevice() {
        if (_hostData && _deviceBuffer) {
            memcpy(_deviceBuffer.contents, _hostData, sizeof(T) * _size);
        }
    }

    /**
     * Copy data from host to device (overload with custom host data)
     */
    void copyToDevice(T *hostData) {
        if (hostData && _deviceBuffer) {
            memcpy(_deviceBuffer.contents, hostData, sizeof(T) * _size);
        }
    }

    /**
     * Copy data from device to host
     * On Apple Silicon with shared memory, this is just a memcpy
     */
    void copyToHost() {
        if (_hostData && _deviceBuffer) {
            memcpy(_hostData, _deviceBuffer.contents, sizeof(T) * _size);
        }
    }

    /**
     * Get element at index (host side)
     */
    T& get(int index) {
        return _hostData[index];
    }

    /**
     * Array subscript operator
     */
    T& operator[](int index) {
        return _hostData[index];
    }

    /**
     * Get the Metal buffer object
     */
    id<MTLBuffer> buffer() const {
        return _deviceBuffer;
    }

    /**
     * Get buffer size in elements
     */
    size_t size() const {
        return _size;
    }

    /**
     * Get buffer size in bytes
     */
    size_t sizeInBytes() const {
        return sizeof(T) * _size;
    }
};

/**
 * Compile Metal shader library from source code
 * @param source Metal shader source code
 * @param device Metal device
 * @param error Output error if compilation fails
 * @return Compiled library or nil on failure
 */
id<MTLLibrary> compileMetalLibrary(NSString* source,
                                    id<MTLDevice> device,
                                    NSError** error);

/**
 * Load precompiled Metal library from file
 * @param path Path to .metallib file
 * @param device Metal device
 * @param error Output error if loading fails
 * @return Loaded library or nil on failure
 */
id<MTLLibrary> loadMetalLibrary(NSString* path,
                                id<MTLDevice> device,
                                NSError** error);

#endif //__METALUTIL_H_
