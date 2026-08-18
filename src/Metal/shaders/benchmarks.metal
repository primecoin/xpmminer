/*
 * benchmarks.metal
 *
 * Benchmark kernels for performance testing
 * Mirrors HIP benchmark functionality
 */

#include "common.metal"
#include "procs.metal"

// Isolates the high 32 bits of a 32x32-bit multiply. Keeping this in a
// dedicated kernel lets the host validate alternative UMULHI implementations
// before they are used by the production Montgomery arithmetic.
kernel void umulhiCorrectnessBenchmark(device const uint2* operands [[buffer(0)]],
                                        device uint* results [[buffer(1)]],
                                        uint gid [[thread_position_in_grid]])
{
    uint2 operand = operands[gid];
    results[gid] = UMULHI(operand.x, operand.y);
}

kernel void umulhiThroughputBenchmark(device const uint2* operands [[buffer(0)]],
                                      device uint* results [[buffer(1)]],
                                      constant uint& iterations [[buffer(2)]],
                                      uint gid [[thread_position_in_grid]])
{
    uint x = operands[gid].x;
    uint y = operands[gid].y;

    for (uint i = 0; i < iterations; ++i) {
        x = UMULHI(x ^ (0x9e3779b9u + i), y);
        y = y * 1664525u + 1013904223u;
    }

    results[gid] = x;
}

kernel void multiplySingle320Benchmark(device const uint* op1 [[buffer(0)]],
                                       device const uint* op2 [[buffer(1)]],
                                       device uint* results [[buffer(2)]],
                                       uint gid [[thread_position_in_grid]])
{
    uint a[10];
    uint b[10];
    uint product[20];
    for (uint i = 0; i < 10; ++i) {
        a[i] = op1[gid * 10 + i];
        b[i] = op2[gid * 10 + i];
    }
    mulProductScan320to320(product, a, b);
    for (uint i = 0; i < 20; ++i) {
        results[gid * 20 + i] = product[i];
    }
}

// One 32-lane SIMD group cooperatively computes one 320x320-bit product.
// Lanes 0..19 calculate convolution columns; lane 0 performs the short carry
// chain after collecting column sums through register shuffles.
kernel void multiplySimdgroup320Benchmark(device const uint* op1 [[buffer(0)]],
                                           device const uint* op2 [[buffer(1)]],
                                           device uint* results [[buffer(2)]],
                                           uint gid [[thread_position_in_grid]],
                                           uint lane [[thread_index_in_simdgroup]],
                                           uint simdSize [[threads_per_simdgroup]])
{
    uint candidate = gid / simdSize;
    ulong columnLow = 0;
    uint columnHigh = 0;

    if (lane < 20) {
        int first = max(0, (int)lane - 9);
        int last = min(9, (int)lane);
        for (int i = first; i <= last; ++i) {
            ulong product = (ulong)op1[candidate * 10 + i] *
                            (ulong)op2[candidate * 10 + ((int)lane - i)];
            ulong previous = columnLow;
            columnLow += product;
            columnHigh += columnLow < previous ? 1u : 0u;
        }
    }

    uint columnLoWord = (uint)columnLow;
    uint columnMidWord = (uint)(columnLow >> 32);
    ulong carry = 0;
    for (uint column = 0; column < 20; ++column) {
        uint lowWord = simd_shuffle(columnLoWord, (ushort)column);
        uint midWord = simd_shuffle(columnMidWord, (ushort)column);
        uint high = simd_shuffle(columnHigh, (ushort)column);
        if (lane == 0) {
            ulong low = (ulong)lowWord | ((ulong)midWord << 32);
            ulong previous = low;
            low += carry;
            high += low < previous ? 1u : 0u;
            results[candidate * 20 + column] = (uint)low;
            carry = (low >> 32) | ((ulong)high << 32);
        }
    }
}

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
