cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

set(MEMPROF_SOURCE
  memprof/memprof.cpp
  memprof/memprof.h
)

# memprof - simple library for memory usage profiling
add_library(memprof STATIC ${MEMPROF_SOURCE})
target_include_directories(memprof PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(memprof PRIVATE tdutils)
if (MEMPROF)
  target_compile_definitions(memprof PRIVATE -DUSE_MEMPROF=1)
  if (MEMPROF STREQUAL "SAFE")
    target_compile_definitions(memprof PRIVATE -DUSE_MEMPROF_SAFE=1)
  elseif (MEMPROF STREQUAL "FAST")
    target_compile_definitions(memprof PRIVATE -DUSE_MEMPROF_FAST=1)
  elseif (NOT MEMPROF)
    message(FATAL_ERROR "Unsupported MEMPROF value \"${MEMPROF}\"")
  endif()
endif()

