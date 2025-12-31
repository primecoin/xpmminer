cmake_minimum_required(VERSION 3.16)

# Metal is only available on Apple platforms
if(NOT APPLE)
    message(STATUS "Metal miner requires macOS. Skipping.")
    return()
endif()

# Check for Apple Silicon (recommended but not required)
execute_process(
    COMMAND uname -m
    OUTPUT_VARIABLE MACHINE_ARCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT MACHINE_ARCH STREQUAL "arm64")
    message(STATUS "Metal miner is optimized for Apple Silicon (arm64). Current: ${MACHINE_ARCH}")
    message(STATUS "  Building anyway, but performance may be suboptimal on Intel Macs.")
endif()

# Find required frameworks
find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)
find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)

if(NOT METAL_FRAMEWORK)
    message(STATUS "Metal framework not found. Skipping Metal miner.")
    return()
endif()

message(STATUS "Metal framework: ${METAL_FRAMEWORK}")

# Find libwebsockets (for getwork protocol)
find_package(Libwebsockets QUIET)
if(Libwebsockets_FOUND)
    message(STATUS "libwebsockets found: ${Libwebsockets_VERSION}")
else()
    message(STATUS "libwebsockets not found. getwork protocol required for Metal miner.")
    message(STATUS "  Install: brew install libwebsockets")
    return()
endif()

# Compiler settings
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable Objective-C++
enable_language(OBJCXX)
set(CMAKE_OBJCXX_STANDARD 14)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

# Compiler flags
if(CMAKE_COMPILER_IS_GNUCC)
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 6.0)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated -Wno-ignored-attributes")
    endif()
endif()

# Add ARC (Automatic Reference Counting) for Objective-C++
set(CMAKE_OBJCXX_FLAGS "${CMAKE_OBJCXX_FLAGS} -fobjc-arc")

# Include directories
include_directories(
    ${GMP_INCLUDE_DIRECTORY}
    ${OPENSSL_INCLUDE_DIR}
    ${JANSSON_INCLUDE_DIRECTORY}
    ${CMAKE_BINARY_DIR}
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
    ${LIBWEBSOCKETS_INCLUDE_DIRS}
)

add_definitions(-DHAVE_LIBWEBSOCKETS)

# Source files
set(METAL_MINER_SOURCES
    xpmclient_metal.mm
    metalutil.mm
    gprimes.cpp
    sha256.cpp
    prime.cpp
    loguru.cpp
)

# Metal shader files
set(METAL_SHADER_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/shaders/common.metal
    ${CMAKE_CURRENT_SOURCE_DIR}/shaders/sha256.metal
    ${CMAKE_CURRENT_SOURCE_DIR}/shaders/json_hashmod.metal
    ${CMAKE_CURRENT_SOURCE_DIR}/shaders/sieve.metal
    ${CMAKE_CURRENT_SOURCE_DIR}/shaders/fermat.metal
    ${CMAKE_CURRENT_SOURCE_DIR}/shaders/procs.metal
    ${CMAKE_CURRENT_SOURCE_DIR}/shaders/benchmarks.metal
)

# Compile Metal shaders to .air intermediate files
set(METAL_AIR_FILES "")
foreach(SHADER_FILE ${METAL_SHADER_SOURCES})
    get_filename_component(SHADER_NAME ${SHADER_FILE} NAME_WE)
    set(AIR_FILE "${CMAKE_CURRENT_BINARY_DIR}/shaders/${SHADER_NAME}.air")
    list(APPEND METAL_AIR_FILES ${AIR_FILE})

    add_custom_command(
        OUTPUT ${AIR_FILE}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/shaders
        COMMAND xcrun -sdk macosx metal -c ${SHADER_FILE} -o ${AIR_FILE}
        DEPENDS ${SHADER_FILE}
        COMMENT "Compiling Metal shader: ${SHADER_NAME}.metal"
    )
endforeach()

# Link all .air files into a single .metallib
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/default.metallib
    COMMAND xcrun -sdk macosx metallib ${METAL_AIR_FILES} -o ${CMAKE_CURRENT_BINARY_DIR}/default.metallib
    DEPENDS ${METAL_AIR_FILES}
    COMMENT "Creating Metal library: default.metallib"
)

# Custom target for Metal shaders
add_custom_target(metal_shaders ALL
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/default.metallib
)

# Create executable
add_executable(xpmmetal ${METAL_MINER_SOURCES})
add_dependencies(xpmmetal metal_shaders)

# Link libraries
target_link_libraries(xpmmetal
    common
    blkmaker
    ${GMP_LIBRARY}
    ${OPENSSL_CRYPTO_LIBRARY}
    ${OPENSSL_SSL_LIBRARY}
    ${JANSSON_LIBRARY}
    ${LIBWEBSOCKETS_LIBRARIES}
    ${METAL_FRAMEWORK}
    ${FOUNDATION_FRAMEWORK}
    ${QUARTZCORE_FRAMEWORK}
    ${COREFOUNDATION_FRAMEWORK}
)

# Copy metallib to output directory
add_custom_command(TARGET xpmmetal POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_BINARY_DIR}/default.metallib
        $<TARGET_FILE_DIR:xpmmetal>/default.metallib
    COMMENT "Copying Metal library to output directory"
)

# Install
install(TARGETS xpmmetal DESTINATION bin)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/default.metallib
        DESTINATION share/xpmminer)

message(STATUS "Metal miner configuration complete")
message(STATUS "Output executable: xpmmetal")
message(STATUS "Target architecture: ${MACHINE_ARCH}")
message(STATUS "Metal shaders will be compiled to default.metallib")
