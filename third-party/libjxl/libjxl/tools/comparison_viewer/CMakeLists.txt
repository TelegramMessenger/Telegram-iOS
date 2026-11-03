# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(Qt6 QUIET COMPONENTS Concurrent Widgets)
if (NOT Qt6_FOUND)
  message(WARNING "Qt6 was not found. The comparison tool will not be built.")
  return()
endif ()

if (NOT TARGET icc_detect)
  message(WARNING "icc_detect not built. The comparison tool will not be built.")
  return ()
endif ()

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)

add_library(image_loading STATIC
  ../viewer/load_jxl.cc
  ../viewer/load_jxl.h
  image_loading.cc
  image_loading.h
)
target_include_directories(image_loading PRIVATE
  $<TARGET_PROPERTY:lcms2,INCLUDE_DIRECTORIES>
)
target_link_libraries(image_loading PUBLIC
  Qt6::Widgets
  jxl-static
  jxl_threads-static
  jxl_extras-static
  lcms2
)

add_executable(compare_codecs WIN32
  codec_comparison_window.cc
  codec_comparison_window.h
  codec_comparison_window.ui
  compare_codecs.cc
  settings.cc
  settings.h
  settings.ui
  split_image_renderer.cc
  split_image_renderer.h
  split_image_view.cc
  split_image_view.h
  split_image_view.ui
)
target_link_libraries(compare_codecs
  image_loading
  Qt6::Concurrent
  Qt6::Widgets
  icc_detect
)

add_executable(compare_images WIN32
  compare_images.cc
  settings.cc
  settings.h
  settings.ui
  split_image_renderer.cc
  split_image_renderer.h
  split_image_view.cc
  split_image_view.h
  split_image_view.ui
)
target_link_libraries(compare_images
  image_loading
  Qt6::Widgets
  icc_detect
)
