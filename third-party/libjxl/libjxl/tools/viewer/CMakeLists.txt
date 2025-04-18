# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(Qt6 QUIET COMPONENTS Widgets)
if (NOT Qt6_FOUND)
  message(WARNING "Qt6 was not found. The directory viewer will not be built.")
  return()
endif ()

if (NOT TARGET icc_detect)
  message(WARNING "The directory viewer depends on the comparison tool and will also not be built.")
  return ()
endif ()

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)

add_executable(viewer WIN32
  load_jxl.cc
  load_jxl.h
  main.cc
  viewer_window.cc
  viewer_window.h
  viewer_window.ui
)
target_include_directories(viewer PRIVATE
  $<TARGET_PROPERTY:lcms2,INCLUDE_DIRECTORIES>
  "${PROJECT_SOURCE_DIR}"
)
target_link_libraries(viewer
  Qt6::Widgets
  icc_detect
  jxl
  jxl_threads
  lcms2
)
