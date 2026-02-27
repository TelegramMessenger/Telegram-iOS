# Copyright (c) the JPEG XL Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

add_library(skcms-obj OBJECT EXCLUDE_FROM_ALL skcms/skcms.cc)
target_include_directories(skcms-obj PUBLIC "${CMAKE_CURRENT_LIST_DIR}/skcms/")

# This library is meant to be compiled/used by external libs (such as plugins)
# that need to use skcms. We use a wrapper for libjxl.
add_library(skcms-interface INTERFACE)
target_sources(skcms-interface INTERFACE ${CMAKE_CURRENT_LIST_DIR}/skcms/skcms.cc)
target_include_directories(skcms-interface INTERFACE ${CMAKE_CURRENT_LIST_DIR}/skcms)

include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-Wno-psabi" CXX_WPSABI_SUPPORTED)
if(CXX_WPSABI_SUPPORTED)
  target_compile_options(skcms-obj PRIVATE -Wno-psabi)
  target_compile_options(skcms-interface INTERFACE -Wno-psabi)
endif()

if(JPEGXL_BUNDLE_SKCMS)
  target_compile_options(skcms-obj PRIVATE -DJPEGXL_BUNDLE_SKCMS=1)
  if(MSVC)
    target_compile_options(skcms-obj
      PRIVATE /FI${CMAKE_CURRENT_SOURCE_DIR}/../lib/jxl/enc_jxl_skcms.h)
  else()
    target_compile_options(skcms-obj
      PRIVATE -include ${CMAKE_CURRENT_SOURCE_DIR}/../lib/jxl/enc_jxl_skcms.h)
  endif()
endif()

set_target_properties(skcms-obj PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN 1
)

add_library(skcms STATIC EXCLUDE_FROM_ALL $<TARGET_OBJECTS:skcms-obj>)
target_include_directories(skcms
  PUBLIC $<TARGET_PROPERTY:skcms-obj,INCLUDE_DIRECTORIES>)

