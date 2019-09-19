cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

add_library(lite-client-common lite-client-common.cpp lite-client-common.h)
target_link_libraries(lite-client-common PUBLIC tdutils tdactor adnllite tl_api tl_lite_api tl-lite-utils ton_crypto ton_block)

add_executable(lite-client lite-client.cpp lite-client.h)
target_link_libraries(lite-client tdutils tdactor adnllite tl_api tl_lite_api tl-lite-utils ton_crypto ton_block
  terminal lite-client-common)
