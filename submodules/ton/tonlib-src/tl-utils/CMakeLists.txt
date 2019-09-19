cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

set(TL_UTILS_SOURCE
  common-utils.hpp
  tl-utils.hpp
  tl-utils.cpp
)

add_library(tl-utils STATIC ${TL_UTILS_SOURCE})

target_include_directories(tl-utils PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(tl-utils PUBLIC tl_api ton_crypto )

set(TL_LITE_UTILS_SOURCE
  common-utils.hpp
  lite-utils.hpp
  lite-utils.cpp
)

add_library(tl-lite-utils STATIC ${TL_LITE_UTILS_SOURCE})

target_include_directories(tl-lite-utils PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>)
target_link_libraries(tl-lite-utils PUBLIC tl_lite_api ton_crypto )
