#include "hiputil.h"
#include <string.h>
#include <algorithm>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>
#include "hip/hip_runtime.h"

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

    int runtimeVersion = 0;
    if (hipRuntimeGetVersion(&runtimeVersion) == hipSuccess)
        hashBytes(hash, &runtimeVersion, sizeof(runtimeVersion));

    std::ostringstream stream;
    stream << std::hex << std::setfill('0') << std::setw(16) << hash;
    return stream.str();
}

} // namespace

bool hipCompileKernel(
    const char* kernelName,
    const std::vector<const char*>& sources,
    const char** arguments,
    int argumentsNum,
    hipModule_t* module,
    int majorComputeCapability,
    int,
    bool needRebuild,
    bool verbose) {
    (void)majorComputeCapability;

    std::string sourceFile;
    for (const char* sourcePath : sources) {
        std::ifstream stream(sourcePath, std::ifstream::binary);
        if (!stream) {
            LOG_F(ERROR, "HIP kernel source not found: %s", sourcePath);
            return false;
        }
        std::string source(
            (std::istreambuf_iterator<char>(stream)),
            std::istreambuf_iterator<char>());
        if (source.empty()) {
            LOG_F(ERROR, "HIP kernel source is empty: %s", sourcePath);
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
            LOG_F(INFO, "Compiling HIP kernel %s...", kernelName);
            LOG_F(INFO, "source: %u bytes", (unsigned)sourceFile.size());
        }

        hiprtcProgram prog;
        HIPRTC_SAFE_CALL(hiprtcCreateProgram(
            &prog, sourceFile.c_str(), "xpm.hip", 0, NULL, NULL));

        hiprtcResult compileResult =
            hiprtcCompileProgram(prog, argumentsNum, arguments);

        // Obtain compilation log from the program.
        size_t logSize;
        HIPRTC_SAFE_CALL(hiprtcGetProgramLogSize(prog, &logSize));
        std::unique_ptr<char[]> log(new char[std::max<size_t>(logSize, 1)]);
        log[0] = '\0';
        if (logSize)
            HIPRTC_SAFE_CALL(hiprtcGetProgramLog(prog, log.get()));

        if (verbose && logSize > 1) {
            LOG_F(INFO, "HIPRTC Compilation log:\n%s", log.get());
        }

        if (compileResult != HIPRTC_SUCCESS) {
            LOG_F(
                ERROR,
                "hiprtcCompileProgram error: %s",
                hiprtcGetErrorString(compileResult));
            if (logSize > 1) {
                LOG_F(ERROR, "Compilation errors:\n%s", log.get());
            }
            hiprtcDestroyProgram(&prog);
            return false;
        }

        // Obtain PTX from the program.
        size_t ptxSize;
        HIPRTC_SAFE_CALL(hiprtcGetCodeSize(prog, &ptxSize));
        char* ptx = new char[ptxSize];
        HIPRTC_SAFE_CALL(hiprtcGetCode(prog, ptx));

        // Destroy the program.
        HIPRTC_SAFE_CALL(hiprtcDestroyProgram(&prog));

        {
            std::ofstream bin(
                kernelName, std::ofstream::binary | std::ofstream::trunc);
            bin.write(ptx, ptxSize);
            if (!bin) {
                LOG_F(ERROR, "Failed writing HIP kernel cache: %s", kernelName);
                delete[] ptx;
                return false;
            }
        }

        delete[] ptx;

        std::ofstream fingerprintFile(
            fingerprintPath, std::ofstream::trunc);
        fingerprintFile << fingerprint << '\n';
        if (!fingerprintFile) {
            LOG_F(
                WARNING,
                "Failed writing HIP kernel fingerprint: %s",
                fingerprintPath.c_str());
        }
    } else if (verbose) {
        LOG_F(INFO, "Using cached HIP kernel %s", kernelName);
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

    std::unique_ptr<char[]> code(new char[binsize + 1]);
    bfile.read(code.get(), binsize);
    bfile.close();

    if (verbose)
        LOG_F(INFO, "Loading HIP module from %s (%zu bytes)", kernelName, binsize);

    hipError_t result = hipModuleLoadData(module, code.get());
    if (result != hipSuccess) {
        const char* msg = hipGetErrorName(result);
        LOG_F(ERROR, "Loading HIP module failed with error %s", msg);
        LOG_F(
            ERROR,
            "Module size: %zu bytes, first 16 bytes: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x",
            binsize,
            (unsigned char)code[0],
            (unsigned char)code[1],
            (unsigned char)code[2],
            (unsigned char)code[3],
            (unsigned char)code[4],
            (unsigned char)code[5],
            (unsigned char)code[6],
            (unsigned char)code[7],
            (unsigned char)code[8],
            (unsigned char)code[9],
            (unsigned char)code[10],
            (unsigned char)code[11],
            (unsigned char)code[12],
            (unsigned char)code[13],
            (unsigned char)code[14],
            (unsigned char)code[15]);
        return false;
    }

    if (verbose)
        LOG_F(INFO, "HIP module loaded successfully");
    return true;
}
