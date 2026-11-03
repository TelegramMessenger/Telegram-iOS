# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(Qt6 QUIET COMPONENTS Widgets)
if (NOT Qt6_FOUND)
  message(WARNING "Qt6 was not found. The flicker test tool will not be built.")
  return()
endif ()

if (NOT TARGET icc_detect OR NOT TARGET image_loading)
  message(WARNING "Comparison tool not built. The flicker test tool will not be built.")
  return()
endif ()

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)

add_executable(flicker_test WIN32
  main.cc
  parameters.cc
  parameters.h
  setup.cc
  setup.h
  setup.ui
  split_view.cc
  split_view.h
  test_window.cc
  test_window.h
  test_window.ui)

target_link_libraries(flicker_test PUBLIC
  Qt6::Widgets
  image_loading
  icc_detect
)
