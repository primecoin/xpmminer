// Simple inline multiplication for benchmarks - uses standard schoolbook
// algorithm
__device__ void simpleMul256(
    uint32_t* result,
    const uint32_t* op1,
    const uint32_t* op2) {
    // Zero result
    for (int i = 0; i < 16; i++)
        result[i] = 0;

    // Schoolbook multiplication
    for (int i = 0; i < 8; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 8; j++) {
            uint64_t product =
                (uint64_t)op1[i] * (uint64_t)op2[j] + result[i + j] + carry;
            result[i + j] = (uint32_t)product;
            carry = product >> 32;
        }
        result[i + 8] = (uint32_t)carry;
    }
}

__device__ void simpleMul384(
    uint32_t* result,
    const uint32_t* op1,
    const uint32_t* op2) {
    // Zero result
    for (int i = 0; i < 24; i++)
        result[i] = 0;

    // Schoolbook multiplication
    for (int i = 0; i < 12; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 12; j++) {
            uint64_t product =
                (uint64_t)op1[i] * (uint64_t)op2[j] + result[i + j] + carry;
            result[i + j] = (uint32_t)product;
            carry = product >> 32;
        }
        result[i + 12] = (uint32_t)carry;
    }
}

extern "C" __global__ void multiplyBenchmark256(
    uint32_t* m1,
    uint32_t* m2,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 8
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t op1[OperandSize];
        uint32_t op2[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++) {
            op1[j] = m1[i * OperandSize + j];
            op2[j] = m2[i * OperandSize + j];
        }

        uint32_t result[16];

        for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
            simpleMul256(result, op1, op2);
            // Copy lower half (OpenCL-compatible approach)
            for (unsigned k = 0; k < 8; k++)
                op1[k] = result[k];
        }

        for (unsigned j = 0; j < OperandSize * 2; j++)
            out[i * OperandSize * 2 + j] = result[j];
    }
#undef OperandSize
}

extern "C" __global__ void multiplyBenchmark384(
    uint32_t* m1,
    uint32_t* m2,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 12
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t op1[OperandSize];
        uint32_t op2[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++) {
            op1[j] = m1[i * OperandSize + j];
            op2[j] = m2[i * OperandSize + j];
        }

        uint32_t result[24];

        for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
            simpleMul384(result, op1, op2);
            // Copy lower half (OpenCL-compatible approach)
            for (unsigned k = 0; k < 12; k++)
                op1[k] = result[k];
        }

        for (unsigned j = 0; j < OperandSize * 2; j++)
            out[i * OperandSize * 2 + j] = result[j];
    }
#undef OperandSize
}

extern "C" __global__ void squareBenchmark320(
    uint32_t* m1,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 10
#define GmpOperandSize 10
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t op1[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++)
            op1[j] = m1[i * GmpOperandSize + j];

        uint32_t result[20];

        for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
            sqrProductScan320(result, op1);
            for (unsigned k = 0; k < 10; k++)
                op1[k] = result[k + 10];
        }

        for (unsigned j = 0; j < OperandSize * 2; j++)
            out[i * OperandSize * 2 + j] = result[j];
    }
#undef GmpOperandSize
#undef OperandSize
}

extern "C" __global__ void squareBenchmark352(
    uint32_t* m1,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 11
#define GmpOperandSize 12
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t op1[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++)
            op1[j] = m1[i * GmpOperandSize + j];

        uint32_t result[22];
        for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
            sqrProductScan352(result, op1);
            for (unsigned k = 0; k < 11; k++)
                op1[k] = result[k + 11];
        }

        for (unsigned j = 0; j < OperandSize * 2; j++)
            out[i * OperandSize * 2 + j] = result[j];
    }
#undef GmpOperandSize
#undef OperandSize
}

extern "C" __global__ void multiplyBenchmark320(
    uint32_t* m1,
    uint32_t* m2,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 10
#define GmpOperandSize 10
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t op1[OperandSize];
        uint32_t op2[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++)
            op1[j] = m1[i * GmpOperandSize + j];
        for (unsigned j = 0; j < OperandSize; j++)
            op2[j] = m2[i * GmpOperandSize + j];

        uint32_t result[20];

        for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
            mulProductScan320to320(result, op1, op2);
            for (unsigned k = 0; k < 10; k++)
                op1[k] = result[k + 10];
        }

        for (unsigned j = 0; j < OperandSize * 2; j++)
            out[i * OperandSize * 2 + j] = result[j];
    }
#undef GmpOperandSize
#undef OperandSize
}

extern "C" __global__ void multiplyBenchmark352(
    uint32_t* m1,
    uint32_t* m2,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 11
#define GmpOperandSize 12
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t op1[OperandSize];
        uint32_t op2[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++)
            op1[j] = m1[i * GmpOperandSize + j];
        for (unsigned j = 0; j < OperandSize; j++)
            op2[j] = m2[i * GmpOperandSize + j];

        uint32_t result[22];

        for (unsigned repeatNum = 0; repeatNum < 512; repeatNum++) {
            mulProductScan352to352(result, op1, op2);
            for (unsigned k = 0; k < 11; k++)
                op1[k] = result[k + 11];
        }

        for (unsigned j = 0; j < OperandSize * 2; j++)
            out[i * OperandSize * 2 + j] = result[j];
    }

#undef GmpOperandSize
#undef OperandSize
}

extern "C" __global__ void fermatTestBenchMark320(
    uint32_t* numbers,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 10
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t result[10];
        uint32_t lNumbers[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++)
            lNumbers[j] = numbers[i * OperandSize + j];

        FermatTest320(lNumbers, result);

        for (unsigned j = 0; j < OperandSize; j++)
            out[i * OperandSize + j] = result[j];
    }
#undef OperandSize
}

extern "C" __global__ void fermatTestBenchMark352(
    uint32_t* numbers,
    uint32_t* out,
    unsigned elementsNum) {
#define OperandSize 11
    unsigned globalSize = gridDim.x * blockDim.x;
    unsigned globalId = blockIdx.x * blockDim.x + threadIdx.x;
    for (unsigned i = globalId; i < elementsNum; i += globalSize) {
        uint32_t result[11];
        uint32_t lNumbers[OperandSize];
        for (unsigned j = 0; j < OperandSize; j++)
            lNumbers[j] = numbers[i * OperandSize + j];

        FermatTest352(lNumbers, result);

        for (unsigned j = 0; j < OperandSize; j++)
            out[i * OperandSize + j] = result[j];
    }
#undef OperandSize
}
