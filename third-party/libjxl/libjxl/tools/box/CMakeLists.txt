# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

add_library(box STATIC EXCLUDE_FROM_ALL
  box.cc
  box.h
)
# This library can be included into position independent binaries.
set_target_properties(box PROPERTIES POSITION_INDEPENDENT_CODE TRUE)
jxl_link_libraries(box jxl_base-obj)
target_include_directories(box
  PRIVATE
  "${PROJECT_SOURCE_DIR}"
)

if(JPEGXL_ENABLE_DEVTOOLS)
add_executable(box_list
  box_list_main.cc
)
target_link_libraries(box_list
  box
  ${ATOMICS_LIBRARIES}
)
set_target_properties(box_list PROPERTIES LINK_FLAGS "${JPEGXL_COVERAGE_LINK_FLAGS}")
endif()  # JPEGXL_ENABLE_DEVTOOLS
