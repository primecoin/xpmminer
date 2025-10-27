cmake_minimum_required(VERSION 3.16)

# ROCm/HIP Configuration
if (NOT DEFINED ROCM_PATH)
    if (NOT DEFINED ENV{ROCM_PATH})
        set(ROCM_PATH "/opt/rocm" CACHE PATH "Path to ROCm installation")
    else()
        set(ROCM_PATH $ENV{ROCM_PATH} CACHE PATH "Path to ROCm installation")
    endif()
endif()

# Set HIP platform to AMD
set(HIP_PLATFORM "amd" CACHE STRING "HIP platform (amd or nvidia)")
set(HIP_RUNTIME "rocclr" CACHE STRING "HIP runtime")

# Find HIP
list(APPEND CMAKE_PREFIX_PATH ${ROCM_PATH})
find_package(HIP REQUIRED)

if (NOT HIP_FOUND)
    message(FATAL_ERROR "HIP not found. Please install ROCm.")
endif()

message(STATUS "HIP found: ${HIP_VERSION}")
message(STATUS "HIP platform: ${HIP_PLATFORM}")
message(STATUS "ROCm path: ${ROCM_PATH}")

# Find HIPRTC library
find_library(HIP_HIPRTC_LIBRARY hiprtc
    HINTS ${ROCM_PATH}/lib
    REQUIRED
)

if (NOT HIP_HIPRTC_LIBRARY)
    message(FATAL_ERROR "HIPRTC library not found")
endif()

message(STATUS "HIPRTC library: ${HIP_HIPRTC_LIBRARY}")

# Compiler flags
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (CMAKE_COMPILER_IS_GNUCC)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 6.0)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated -Wno-ignored-attributes")
  endif()
endif()

if (WIN32)
  message(FATAL_ERROR "HIP miner does not support Windows. Use Linux.")
elseif(APPLE)
  message(FATAL_ERROR "HIP miner does not support macOS. Use Linux with AMD GPU.")
else()
  message("Building HIP miner for Linux")
  add_definitions(-DLINUX)
  if (STATIC_BUILD)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -static-libgcc -static-libstdc++")
  endif()
endif()

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
endif()

# Include directories
include_directories(
  ${GMP_INCLUDE_DIRECTORY}
  ${OPENSSL_INCLUDE_DIR}
  ${JANSSON_INCLUDE_DIRECTORY}
  ${CURL_INCLUDE_DIRECTORY}
  ${CMAKE_BINARY_DIR}
  ${CMAKE_SOURCE_DIR}
  ${CMAKE_SOURCE_DIR}/xpm/cuda  # For kernel source files at runtime
  ${HIP_INCLUDE_DIRS}
  ${ROCM_PATH}/include
)

# Source files
set(HIP_MINER_SOURCES
    xpmclient_hip.cpp
    benchmarks_hip.cpp
    hiputil_auto.cpp
    gprimes.cpp
    sha256.cpp
    prime.cpp
    loguru.cpp
)

# Create executable
add_executable(xpmhip ${HIP_MINER_SOURCES})

# Set HIP compiler for the target (important!)
set_source_files_properties(${HIP_MINER_SOURCES} PROPERTIES HIP_SOURCE_PROPERTY_FORMAT 1)

# Link libraries
target_link_libraries(xpmhip
  common
  blkmaker
  ${GMP_LIBRARY}
  ${OPENSSL_CRYPTO_LIBRARY}
  ${OPENSSL_SSL_LIBRARY}
  ${CURL_LIBRARY}
  ${JANSSON_LIBRARY}
  hip::host        # HIP runtime
  ${HIP_HIPRTC_LIBRARY}  # HIPRTC for runtime compilation
  dl
)

# Install target
install(TARGETS xpmhip DESTINATION bin)

# Copy kernel source files to xpm/cuda directory for runtime compilation
# Note: HIPRTC will read these files at runtime
install(FILES
    fermat_hip.cpp
    sha256_hip.cpp
    sieve_hip.cpp
    procs_hip.cpp
    benchmarks_hip.cpp
    DESTINATION share/xpmminer/hip
)

message(STATUS "HIP miner configuration complete")
message(STATUS "Output executable: xpmhip")
message(STATUS "Kernel files will be read from xpm/cuda at runtime")
message(STATUS "Note: Ensure GPU architecture (gfxNNN) is set correctly for your AMD GPU")
