# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Example project using libjxl.

cmake_minimum_required(VERSION 3.10)

project(SAMPLE_LIBJXL LANGUAGES C CXX)

# Use pkg-config to find libjxl.
find_package(PkgConfig)
pkg_check_modules(Jxl REQUIRED IMPORTED_TARGET libjxl)
pkg_check_modules(JxlThreads REQUIRED IMPORTED_TARGET libjxl_threads)

# Build the example encoder/decoder binaries using the default shared libraries
# installed.
add_executable(decode_oneshot decode_oneshot.cc)
target_link_libraries(decode_oneshot PkgConfig::Jxl PkgConfig::JxlThreads)

add_executable(decode_progressive decode_progressive.cc)
target_link_libraries(decode_progressive PkgConfig::Jxl PkgConfig::JxlThreads)

add_executable(encode_oneshot encode_oneshot.cc)
target_link_libraries(encode_oneshot PkgConfig::Jxl PkgConfig::JxlThreads)


# Building a static binary with the static libjxl dependencies. How to load
# static library configs from pkg-config and how to build static binaries
# depends on the platform, and building static binaries in general has problems.
# If you don't need static binaries you can remove this section.
add_library(StaticJxl INTERFACE IMPORTED GLOBAL)
set_target_properties(StaticJxl PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${Jxl_STATIC_INCLUDE_DIR}"
    INTERFACE_COMPILE_OPTIONS "${Jxl_STATIC_CFLAGS_OTHER}"
    INTERFACE_LINK_LIBRARIES "${Jxl_STATIC_LDFLAGS}"
)
add_library(StaticJxlThreads INTERFACE IMPORTED GLOBAL)
set_target_properties(StaticJxlThreads PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${JxlThreads_STATIC_INCLUDE_DIR}"
    INTERFACE_COMPILE_OPTIONS "${JxlThreads_STATIC_CFLAGS_OTHER}"
    # libgcc uses weak symbols for pthread which means that -lpthread is not
    # linked when compiling a static binary. This is a platform-specific fix for
    # that.
    INTERFACE_LINK_LIBRARIES
      "${JxlThreads_STATIC_LDFLAGS} -Wl,--whole-archive -lpthread -Wl,--no-whole-archive"
)

add_executable(decode_oneshot_static decode_oneshot.cc)
target_link_libraries(decode_oneshot_static
  -static StaticJxl StaticJxlThreads)

add_executable(encode_oneshot_static encode_oneshot.cc)
target_link_libraries(encode_oneshot_static
  -static StaticJxl StaticJxlThreads)
