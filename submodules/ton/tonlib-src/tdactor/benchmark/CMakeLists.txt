cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

set(BENCHMARK_SOURCE
  benchmark.cpp
  third_party/mp-queue.c

  third_party/FAAArrayQueue.h
  third_party/LCRQueue.h
  third_party/LazyIndexArrayQueue.h
  third_party/MoodyCamelQueue.h
)
add_executable(benchmark ${BENCHMARK_SOURCE})
target_include_directories(benchmark PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_link_libraries(benchmark PRIVATE tdactor)

if (MSVC)
  set_property(SOURCE benchmark.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " /wd4457 /wd4316")
endif()

