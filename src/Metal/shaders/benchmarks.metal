/*
 * benchmarks.metal
 *
 * Benchmark kernels for performance testing
 * Mirrors HIP benchmark functionality
 */

#include "common.metal"
#include "procs.metal"

// Multiply benchmark for 320-bit numbers
// Performs MulOpsNum consecutive multiplications
kernel void multiplyBenchmark320(device uint* m1 [[buffer(0)]],
                                  device uint* m2 [[buffer(1)]],
                                  device uint* result [[buffer(2)]],
                                  constant uint& elementsNum [[buffer(3)]],
                                  uint gid [[thread_position_in_grid]],
                                  uint gsize [[threads_per_grid]])
{
    const uint operandSize = 320 / 32;  // 10 uint32s
    const uint gmpOperandSize = 10;
    const uint MulOpsNum = 512;  // Match HIP

    // Grid-stride loop - match HIP pattern
    for (uint i = gid; i < elementsNum; i += gsize) {
        thread uint op1[operandSize];
        thread uint op2[operandSize];

        // Load operands
        for (uint j = 0; j < operandSize; j++) {
            op1[j] = m1[i * gmpOperandSize + j];
            op2[j] = m2[i * gmpOperandSize + j];
        }

        thread uint tempResult[operandSize * 2];

        // Perform repeated multiplication using optimized function
        for (uint repeatNum = 0; repeatNum < MulOpsNum; repeatNum++) {
            mulProductScan320to320(tempResult, op1, op2);
            // Copy upper half back to op1 for next iteration (match HIP)
            for (uint k = 0; k < operandSize; k++) {
                op1[k] = tempResult[k + operandSize];
            }
        }

        // Write result
        for (uint j = 0; j < operandSize * 2; j++) {
            result[i * operandSize * 2 + j] = tempResult[j];
        }
    }
}

// Multiply benchmark for 352-bit numbers
kernel void multiplyBenchmark352(device uint* m1 [[buffer(0)]],
                                  device uint* m2 [[buffer(1)]],
                                  device uint* result [[buffer(2)]],
                                  constant uint& elementsNum [[buffer(3)]],
                                  uint gid [[thread_position_in_grid]],
                                  uint gsize [[threads_per_grid]])
{
    const uint operandSize = 352 / 32;  // 11 uint32s
    const uint gmpOperandSize = 12;
    const uint MulOpsNum = 512;  // Match HIP

    // Grid-stride loop - match HIP pattern
    for (uint i = gid; i < elementsNum; i += gsize) {
        thread uint op1[operandSize];
        thread uint op2[operandSize];

        // Load operands
        for (uint j = 0; j < operandSize; j++) {
            op1[j] = m1[i * gmpOperandSize + j];
            op2[j] = m2[i * gmpOperandSize + j];
        }

        thread uint tempResult[operandSize * 2];

        // Perform repeated multiplication using optimized function
        for (uint repeatNum = 0; repeatNum < MulOpsNum; repeatNum++) {
            mulProductScan352to352(tempResult, op1, op2);
            // Copy upper half back to op1 for next iteration
            for (uint k = 0; k < operandSize; k++) {
                op1[k] = tempResult[k + operandSize];
            }
        }

        // Write result
        for (uint j = 0; j < operandSize * 2; j++) {
            result[i * operandSize * 2 + j] = tempResult[j];
        }
    }
}

// Square benchmark for 320-bit numbers
kernel void squareBenchmark320(device uint* m1 [[buffer(0)]],
                                device uint* result [[buffer(1)]],
                                constant uint& elementsNum [[buffer(2)]],
                                uint gid [[thread_position_in_grid]],
                                uint gsize [[threads_per_grid]])
{
    const uint operandSize = 320 / 32;  // 10 uint32s
    const uint gmpOperandSize = 10;
    const uint MulOpsNum = 512;  // Match HIP

    // Grid-stride loop - match HIP pattern
    for (uint i = gid; i < elementsNum; i += gsize) {
        thread uint op1[operandSize];

        // Load operand
        for (uint j = 0; j < operandSize; j++) {
            op1[j] = m1[i * gmpOperandSize + j];
        }

        thread uint tempResult[operandSize * 2];

        // Perform repeated squaring using optimized function
        for (uint repeatNum = 0; repeatNum < MulOpsNum; repeatNum++) {
            sqrProductScan320(tempResult, op1);
            // Copy upper half back to op1 for next iteration
            for (uint k = 0; k < operandSize; k++) {
                op1[k] = tempResult[k + operandSize];
            }
        }

        // Write result
        for (uint j = 0; j < operandSize * 2; j++) {
            result[i * operandSize * 2 + j] = tempResult[j];
        }
    }
}

// Square benchmark for 352-bit numbers
kernel void squareBenchmark352(device uint* m1 [[buffer(0)]],
                                device uint* result [[buffer(1)]],
                                constant uint& elementsNum [[buffer(2)]],
                                uint gid [[thread_position_in_grid]],
                                uint gsize [[threads_per_grid]])
{
    const uint operandSize = 352 / 32;  // 11 uint32s
    const uint gmpOperandSize = 12;
    const uint MulOpsNum = 512;  // Match HIP

    // Grid-stride loop - match HIP pattern
    for (uint i = gid; i < elementsNum; i += gsize) {
        thread uint op1[operandSize];

        // Load operand
        for (uint j = 0; j < operandSize; j++) {
            op1[j] = m1[i * gmpOperandSize + j];
        }

        thread uint tempResult[operandSize * 2];

        // Perform repeated squaring using optimized function
        for (uint repeatNum = 0; repeatNum < MulOpsNum; repeatNum++) {
            sqrProductScan352(tempResult, op1);
            // Copy upper half back to op1 for next iteration
            for (uint k = 0; k < operandSize; k++) {
                op1[k] = tempResult[k + operandSize];
            }
        }

        // Write result
        for (uint j = 0; j < operandSize * 2; j++) {
            result[i * operandSize * 2 + j] = tempResult[j];
        }
    }
}
