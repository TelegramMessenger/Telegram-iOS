if ((CMAKE_MAJOR_VERSION LESS 3) OR (CMAKE_VERSION VERSION_LESS "3.10"))
  message(FATAL_ERROR "CMake >= 3.10 is required")
endif()

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
