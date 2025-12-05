include_directories(
  ${GMP_INCLUDE_DIRECTORY}
  ${OPENSSL_INCLUDE_DIR}
)

# Add libwebsockets support if available
if (Libwebsockets_FOUND)
  include_directories(${LIBWEBSOCKETS_INCLUDE_DIRS})
  add_definitions(-DHAVE_LIBWEBSOCKETS)
endif()

add_library(common STATIC
  CSieveOfEratosthenesL1Ext.cpp
  getblocktemplate.cpp
  getwork_client.cpp
  primecoin.cpp
  system.cpp
)
