# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

include(jxl_lists.cmake)

# benchmark.h doesn't work in our MINGW set up since it ends up including the
# wrong stdlib header. We don't run gbench on MINGW targets anyway.
if(NOT MINGW)

# This is the Google benchmark project (https://github.com/google/benchmark).
find_package(benchmark QUIET)

if(benchmark_FOUND)
  if(JPEGXL_STATIC AND NOT MINGW)
    # benchmark::benchmark hardcodes the librt.so which obviously doesn't
    # compile in static mode.
    set_target_properties(benchmark::benchmark PROPERTIES
      INTERFACE_LINK_LIBRARIES "Threads::Threads;-lrt")
  endif()

  # Compiles all the benchmark files into a single binary. Individual benchmarks
  # can be run with --benchmark_filter.
  add_executable(jxl_gbench "${JPEGXL_INTERNAL_GBENCH_SOURCES}" gbench_main.cc)

  target_compile_definitions(jxl_gbench PRIVATE
    -DTEST_DATA_PATH="${JPEGXL_TEST_DATA_PATH}")
  target_link_libraries(jxl_gbench
    jxl_extras-static
    jxl-static
    benchmark::benchmark
  )
endif() # benchmark_FOUND

endif() # MINGW
