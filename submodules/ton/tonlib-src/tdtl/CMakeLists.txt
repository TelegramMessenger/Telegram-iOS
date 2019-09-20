cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

#SOURCE SETS
set(TDTL_SOURCE
  td/tl/tl_config.cpp
  td/tl/tl_core.cpp
  td/tl/tl_file_outputer.cpp
  td/tl/tl_file_utils.cpp
  td/tl/tl_generate.cpp
  td/tl/tl_outputer.cpp
  td/tl/tl_string_outputer.cpp
  td/tl/tl_writer.cpp

  td/tl/tl_config.h
  td/tl/tl_core.h
  td/tl/tl_file_outputer.h
  td/tl/tl_file_utils.h
  td/tl/tl_generate.h
  td/tl/tl_outputer.h
  td/tl/tl_simple.h
  td/tl/tl_simple_parser.h
  td/tl/tl_string_outputer.h
  td/tl/tl_writer.h
)

add_library(tdtl STATIC ${TDTL_SOURCE})
target_include_directories(tdtl PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
#TODO
#target_compile_options(tdtl PRIVATE "-std=c++03")
