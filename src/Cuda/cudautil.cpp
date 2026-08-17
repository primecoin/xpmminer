#include "cudautil.h"
#include <string.h>
#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>

namespace {

void hashBytes(uint64_t& hash, const void* data, size_t size) {
    const unsigned char* bytes = static_cast<const unsigned char*>(data);
    for (size_t i = 0; i < size; ++i) {
        hash ^= bytes[i];
        hash *= 1099511628211ull;
    }
}

std::string kernelFingerprint(
    const std::string& source,
    const char** arguments,
    int argumentsNum) {
    uint64_t hash = 1469598103934665603ull;
    hashBytes(hash, source.data(), source.size());
    for (int i = 0; i < argumentsNum; ++i) {
        const char* argument = arguments[i] ? arguments[i] : "";
        hashBytes(hash, argument, strlen(argument));
        const char separator = '\0';
        hashBytes(hash, &separator, sizeof(separator));
    }

    int nvrtcMajor = 0;
    int nvrtcMinor = 0;
    if (nvrtcVersion(&nvrtcMajor, &nvrtcMinor) == NVRTC_SUCCESS) {
        hashBytes(hash, &nvrtcMajor, sizeof(nvrtcMajor));
        hashBytes(hash, &nvrtcMinor, sizeof(nvrtcMinor));
    }

    std::ostringstream stream;
    stream << std::hex << std::setfill('0') << std::setw(16) << hash;
    return stream.str();
}

} // namespace

bool cudaCompileKernel(
    const char* kernelName,
    const std::vector<const char*>& sources,
    const char** arguments,
    int argumentsNum,
    CUmodule* module,
    int majorComputeCapability,
    int,
    bool needRebuild,
    bool verbose) {
    (void)majorComputeCapability;

    std::string sourceFile;
    for (const char* sourcePath : sources) {
        std::ifstream stream(sourcePath, std::ifstream::binary);
        if (!stream) {
            LOG_F(ERROR, "CUDA kernel source not found: %s", sourcePath);
            return false;
        }
        std::string source(
            (std::istreambuf_iterator<char>(stream)),
            std::istreambuf_iterator<char>());
        if (source.empty()) {
            LOG_F(ERROR, "CUDA kernel source is empty: %s", sourcePath);
            return false;
        }
        sourceFile.append(source);
        sourceFile.push_back('\n');
    }

    const std::string fingerprint =
        kernelFingerprint(sourceFile, arguments, argumentsNum);
    const std::string fingerprintPath =
        std::string(kernelName) + ".fingerprint";
    bool cacheMatches = false;
    if (!needRebuild) {
        std::ifstream binaryFile(kernelName, std::ifstream::binary);
        std::ifstream fingerprintFile(fingerprintPath);
        std::string cachedFingerprint;
        if (binaryFile && fingerprintFile &&
            (fingerprintFile >> cachedFingerprint) &&
            cachedFingerprint == fingerprint) {
            cacheMatches = true;
        }
    }

    if (!cacheMatches) {
        if (verbose) {
            LOG_F(INFO, "Compiling CUDA kernel %s...", kernelName);
            LOG_F(INFO, "source: %u bytes", (unsigned)sourceFile.size());
        }

        nvrtcProgram prog;
        NVRTC_SAFE_CALL(nvrtcCreateProgram(
            &prog, sourceFile.c_str(), "xpm.cu", 0, NULL, NULL));

        nvrtcResult compileResult =
            nvrtcCompileProgram(prog, argumentsNum, arguments);

        // Obtain compilation log from the program.
        size_t logSize;
        NVRTC_SAFE_CALL(nvrtcGetProgramLogSize(prog, &logSize));
        std::unique_ptr<char[]> log(new char[std::max<size_t>(logSize, 1)]);
        log[0] = '\0';
        if (logSize)
            NVRTC_SAFE_CALL(nvrtcGetProgramLog(prog, log.get()));

        if (compileResult != NVRTC_SUCCESS) {
            LOG_F(
                ERROR,
                "nvrtcCompileProgram error: %s",
                nvrtcGetErrorString(compileResult));
            if (logSize > 1)
                LOG_F(ERROR, "Compilation log:\n%s", log.get());
            nvrtcDestroyProgram(&prog);
            return false;
        }

        // Print log even on success if there are warnings
        if (verbose && logSize > 1) {
            LOG_F(INFO, "Compilation log:\n%s", log.get());
        }

        // Obtain PTX from the program.
        size_t ptxSize;
        NVRTC_SAFE_CALL(nvrtcGetPTXSize(prog, &ptxSize));
        char* ptx = new char[ptxSize];
        NVRTC_SAFE_CALL(nvrtcGetPTX(prog, ptx));

        // Destroy the program.
        NVRTC_SAFE_CALL(nvrtcDestroyProgram(&prog));

        {
            std::ofstream bin(
                kernelName, std::ofstream::binary | std::ofstream::trunc);
            bin.write(ptx, ptxSize);
            if (!bin) {
                LOG_F(
                    ERROR, "Failed writing CUDA kernel cache: %s", kernelName);
                delete[] ptx;
                return false;
            }
        }

        delete[] ptx;

        std::ofstream fingerprintFile(fingerprintPath, std::ofstream::trunc);
        fingerprintFile << fingerprint << '\n';
        if (!fingerprintFile) {
            LOG_F(
                WARNING,
                "Failed writing CUDA kernel fingerprint: %s",
                fingerprintPath.c_str());
        }
    } else if (verbose) {
        LOG_F(INFO, "Using cached CUDA kernel %s", kernelName);
    }

    std::ifstream bfile(kernelName, std::ifstream::binary);
    if (!bfile) {
        return false;
    }

    bfile.seekg(0, bfile.end);
    size_t binsize = bfile.tellg();
    bfile.seekg(0, bfile.beg);
    if (!binsize) {
        LOG_F(ERROR, "%s empty", kernelName);
        return false;
    }

    std::unique_ptr<char[]> ptx(new char[binsize + 1]);
    bfile.read(ptx.get(), binsize);
    ptx[binsize] = '\0';
    bfile.close();

    if (verbose)
        LOG_F(
            INFO,
            "Loading CUDA module from %s (%zu bytes)",
            kernelName,
            binsize);

    CUresult result = cuModuleLoadDataEx(module, ptx.get(), 0, 0, 0);
    if (result != CUDA_SUCCESS) {
        if (result == CUDA_ERROR_INVALID_PTX ||
            result == CUDA_ERROR_UNSUPPORTED_PTX_VERSION) {
            LOG_F(WARNING, "GPU Driver version too old, update recommended");
            LOG_F(WARNING, "Workaround: downgrade version in PTX to 6.0 ...");
            char* pv = strstr(ptx.get(), ".version ");
            if (pv) {
                pv[9] = '6';
                pv[11] = '0';
            }

            CUDA_SAFE_CALL(cuModuleLoadDataEx(module, ptx.get(), 0, 0, 0));
        } else {
            const char* msg;
            cuGetErrorName(result, &msg);
            LOG_F(ERROR, "Loading CUDA module failed with error %s", msg);
            return false;
        }
    }

    return true;
}
