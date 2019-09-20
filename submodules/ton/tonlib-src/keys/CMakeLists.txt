cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

set(KEYS_SOURCE
  keys.cpp
  encryptor.cpp
  keys.hpp
  encryptor.h
  encryptor.hpp
)

add_library(keys STATIC ${KEYS_SOURCE})

target_include_directories(keys PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(keys PUBLIC tdactor ton_crypto tl_api tl-utils )
