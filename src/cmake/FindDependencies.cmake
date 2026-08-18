# Report missing host dependencies during CMake configuration instead of
# allowing obscure compiler or linker errors later in the build.
function(xpm_require_dependency display_name include_variable required_headers
         library_variable purpose)
  set(include_path "${${include_variable}}")
  set(missing_components "")

  if(NOT include_path)
    list(APPEND missing_components "headers")
  else()
    foreach(required_header IN LISTS required_headers)
      if(NOT EXISTS "${include_path}/${required_header}")
        list(APPEND missing_components "headers")
        break()
      endif()
    endforeach()
  endif()

  if(library_variable)
    set(library_path "${${library_variable}}")
    if(NOT library_path OR NOT EXISTS "${library_path}")
      list(APPEND missing_components "library")
    endif()
  endif()

  if(missing_components)
    list(REMOVE_DUPLICATES missing_components)
    string(JOIN " and " missing_description ${missing_components})
    message(FATAL_ERROR
      "Required dependency ${display_name} was not found (${missing_description}).\n"
      "${purpose}\n"
      "Install the ${display_name} development files and rerun CMake."
    )
  endif()
endfunction()

# GMP
find_path(GMP_INCLUDE_DIRECTORY gmp.h)
find_path(GMPXX_INCLUDE_DIRECTORY gmpxx.h)
find_library(GMP_LIBRARY gmp)
find_library(GMPXX_LIBRARY gmpxx)
xpm_require_dependency(
  "GMP"
  GMP_INCLUDE_DIRECTORY
  "gmp.h"
  GMP_LIBRARY
  "GMP provides the arbitrary-precision arithmetic required by the miner."
)
xpm_require_dependency(
  "GMP"
  GMPXX_INCLUDE_DIRECTORY
  "gmpxx.h"
  ""
  "GMP provides the arbitrary-precision arithmetic required by the miner."
)
list(APPEND GMP_INCLUDE_DIRECTORY "${GMPXX_INCLUDE_DIRECTORY}")
list(REMOVE_DUPLICATES GMP_INCLUDE_DIRECTORY)

# Jansson
find_path(JANSSON_INCLUDE_DIRECTORY jansson.h)
find_library(JANSSON_LIBRARY jansson)
xpm_require_dependency(
  "Jansson"
  JANSSON_INCLUDE_DIRECTORY
  "jansson.h"
  JANSSON_LIBRARY
  "Jansson provides JSON parsing for RPC work and block templates."
)

# CURL
find_path(CURL_INCLUDE_DIRECTORY curl/curl.h)
find_library(CURL_LIBRARY curl)
xpm_require_dependency(
  "libcurl"
  CURL_INCLUDE_DIRECTORY
  "curl/curl.h"
  CURL_LIBRARY
  "libcurl provides HTTP transport for getblocktemplate RPC mining."
)

# Win32 libraries
if (WIN32)
  find_library(PTHREAD_LIBRARY pthreadGC2)
  find_library(Z_LIBRARY z)
endif()
