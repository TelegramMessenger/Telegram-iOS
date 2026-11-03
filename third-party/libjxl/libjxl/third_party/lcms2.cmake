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

add_library(lcms2 STATIC EXCLUDE_FROM_ALL
  lcms/src/cmsalpha.c
  lcms/src/cmscam02.c
  lcms/src/cmscgats.c
  lcms/src/cmscnvrt.c
  lcms/src/cmserr.c
  lcms/src/cmsgamma.c
  lcms/src/cmsgmt.c
  lcms/src/cmshalf.c
  lcms/src/cmsintrp.c
  lcms/src/cmsio0.c
  lcms/src/cmsio1.c
  lcms/src/cmslut.c
  lcms/src/cmsmd5.c
  lcms/src/cmsmtrx.c
  lcms/src/cmsnamed.c
  lcms/src/cmsopt.c
  lcms/src/cmspack.c
  lcms/src/cmspcs.c
  lcms/src/cmsplugin.c
  lcms/src/cmsps2.c
  lcms/src/cmssamp.c
  lcms/src/cmssm.c
  lcms/src/cmstypes.c
  lcms/src/cmsvirt.c
  lcms/src/cmswtpnt.c
  lcms/src/cmsxform.c
  lcms/src/lcms2_internal.h
)
target_include_directories(lcms2
    PUBLIC "${CMAKE_CURRENT_LIST_DIR}/lcms/include")
# This warning triggers with gcc-8.
if (CMAKE_C_COMPILER_ID MATCHES "GNU")
target_compile_options(lcms2
  PRIVATE
    # gcc-only flags.
    -Wno-stringop-truncation
    -Wno-strict-aliasing
)
endif()
# By default LCMS uses sizeof(void*) for memory alignment, but in arm 32-bits we
# can't access doubles not aligned to 8 bytes. This forces the alignment to 8
# bytes.
target_compile_definitions(lcms2
  PRIVATE "-DCMS_PTR_ALIGNMENT=8")
target_compile_definitions(lcms2
  PUBLIC "-DCMS_NO_REGISTER_KEYWORD=1")

# Ensure that a thread safe alternative of gmtime is used in LCMS
include(CheckSymbolExists)
check_symbol_exists(gmtime_r "time.h" HAVE_GMTIME_R)
if (HAVE_GMTIME_R)
  target_compile_definitions(lcms2
    PUBLIC "-DHAVE_GMTIME_R=1")
else()
  check_symbol_exists(gmtime_s "time.h" HAVE_GMTIME_S)
  if (HAVE_GMTIME_S)
    target_compile_definitions(lcms2
      PUBLIC "-DHAVE_GMTIME_S=1")
  endif()
endif()

set_property(TARGET lcms2 PROPERTY POSITION_INDEPENDENT_CODE ON)
