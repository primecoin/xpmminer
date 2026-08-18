# Modern CUDA detection using CUDAToolkit (CMake 3.17+)
# Falls back to legacy FindCUDA for older CMake versions
cmake_minimum_required(VERSION 3.10)

# Try modern CUDAToolkit first (CMake 3.17+)
if (${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.17.0")
  find_package(CUDAToolkit QUIET)
  if (CUDAToolkit_FOUND)
    set(CUDA_FOUND TRUE)
    set(CUDA_INCLUDE_DIRS ${CUDAToolkit_INCLUDE_DIRS})
    message(STATUS "CUDA Toolkit found: ${CUDAToolkit_VERSION}")
    message(STATUS "CUDA Include: ${CUDAToolkit_INCLUDE_DIRS}")
  endif()
else()
  # Legacy FindCUDA for older CMake
  find_package(CUDA QUIET)
  if (CUDA_FOUND)
    message(STATUS "CUDA found (legacy): ${CUDA_VERSION}")
  endif()
endif()

# If CUDA not found, skip building
if (NOT CUDA_FOUND)
  message(STATUS
    "CUDA Toolkit was not found, so the CUDA miner will not be built. "
    "Install the NVIDIA CUDA Toolkit development files and rerun CMake."
  )
  return()
endif()

# Platform-specific libraries
set(LIBRARIES ${GMP_LIBRARY})
if (WIN32)
  set(LIBRARIES ${LIBRARIES} ws2_32 advapi32 wldap32)
  add_definitions(-D_WIN32 -D__WINDOWS__ -D__USE_MINGW_ANSI_STDIO=0)
  message("Building CUDA miner for Windows")
else()
  set(LIBRARIES ${LIBRARIES} dl)
  add_definitions(-DLINUX)
  message("Building CUDA miner for Linux")
  if (STATIC_BUILD)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -static-libgcc -static-libstdc++")
  endif()
endif()

# Compiler flags
if (CMAKE_COMPILER_IS_GNUCC)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 6.0)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated -Wno-ignored-attributes")
  endif()
endif()

if (APPLE)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DCL_SILENCE_DEPRECATION")
endif()

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
endif()

include_directories(
  ${GMP_INCLUDE_DIRECTORY}
  ${OPENSSL_INCLUDE_DIR}
  ${JANSSON_INCLUDE_DIRECTORY}
  ${CURL_INCLUDE_DIRECTORY}
  ${CMAKE_BINARY_DIR}
)

if (Libwebsockets_FOUND)
  include_directories(${LIBWEBSOCKETS_INCLUDE_DIRS})
  add_definitions(-DHAVE_LIBWEBSOCKETS)
endif()

add_executable(xpmcuda
    xpmclient.cpp
    benchmarks.cpp
    cudautil.cpp
    sha256.cpp
    prime.cpp
    loguru.cpp
  )

target_include_directories(xpmcuda PUBLIC
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/xpm/cuda
    ${CUDA_INCLUDE_DIRS}
  )

# Link libraries - use modern CUDAToolkit targets if available
if (${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.17.0" AND CUDAToolkit_FOUND)
  # Modern CMake 3.17+ with CUDAToolkit
  target_link_libraries(xpmcuda
    common
    blkmaker
    ${LIBRARIES}
    ${OPENSSL_CRYPTO_LIBRARY}
    ${OPENSSL_SSL_LIBRARY}
    ${CURL_LIBRARY}
    ${JANSSON_LIBRARY}
    CUDA::cuda_driver
    CUDA::nvrtc
  )

  if (Libwebsockets_FOUND)
    target_link_libraries(xpmcuda ${LIBWEBSOCKETS_LIBRARIES})
  endif()
else()
  # Legacy FindCUDA
  find_library(CUDA_DRIVER_LIBRARY cuda
    HINTS ${CUDA_TOOLKIT_ROOT_DIR}/lib64 ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
    PATHS /usr/local/cuda/lib64 /usr/lib/x86_64-linux-gnu
  )
  find_library(CUDA_nvrtc_LIBRARY nvrtc
    HINTS ${CUDA_TOOLKIT_ROOT_DIR}/lib64 ${CUDA_TOOLKIT_ROOT_DIR}/lib/x64
    PATHS /usr/local/cuda/lib64 /usr/lib/x86_64-linux-gnu
  )

  if (NOT CUDA_DRIVER_LIBRARY)
    message(FATAL_ERROR
      "The CUDA driver development library (libcuda) was not found. "
      "Install the NVIDIA CUDA development files and rerun CMake."
    )
  endif()
  if (NOT CUDA_nvrtc_LIBRARY)
    message(FATAL_ERROR
      "The CUDA runtime compilation library (libnvrtc) was not found. "
      "Install the NVIDIA CUDA Toolkit development files and rerun CMake."
    )
  endif()

  target_link_libraries(xpmcuda
    common
    blkmaker
    ${LIBRARIES}
    ${OPENSSL_CRYPTO_LIBRARY}
    ${OPENSSL_SSL_LIBRARY}
    ${CURL_LIBRARY}
    ${JANSSON_LIBRARY}
    ${CUDA_DRIVER_LIBRARY}
    ${CUDA_nvrtc_LIBRARY}
  )

  if (Libwebsockets_FOUND)
    target_link_libraries(xpmcuda ${LIBWEBSOCKETS_LIBRARIES})
  endif()
endif()

# Copy every NVRTC source used by xpmclient.cpp. This target runs on every build
# so editing only a runtime-compiled kernel cannot leave a stale build-tree copy.
# copy_if_different keeps the no-change path inexpensive.
set(CUDA_KERNEL_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/helpers.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/procs.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/fermat.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/sieve.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/sha256.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/json_sha256.cu
    ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks.cu
)
add_custom_target(xpmcuda_kernels ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/xpm/cuda
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CUDA_KERNEL_SOURCES}
        ${CMAKE_CURRENT_BINARY_DIR}/xpm/cuda/
    COMMENT "Copying CUDA kernel source files to build directory for NVRTC runtime compilation"
    VERBATIM
)
add_dependencies(xpmcuda xpmcuda_kernels)

message(STATUS "CUDA miner configuration complete")
message(STATUS "Output executable: xpmcuda")
