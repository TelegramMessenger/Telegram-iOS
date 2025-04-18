# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(PkgConfig)
pkg_check_modules(Gimp IMPORTED_TARGET gimp-2.0>=2.10 gimpui-2.0>=2.10)

if (NOT Gimp_FOUND)
  message(WARNING "Gimp development libraries not found, the Gimp plugin will not be built")
  return ()
endif ()

add_executable(file-jxl WIN32
  common.h
  common.cc
  file-jxl-load.cc
  file-jxl-load.h
  file-jxl-save.cc
  file-jxl-save.h
  file-jxl.cc)
target_link_libraries(file-jxl jxl jxl_threads PkgConfig::Gimp)

target_include_directories(file-jxl PUBLIC
    ${PROJECT_SOURCE_DIR})  # for plugins/gimp absolute paths.

pkg_get_variable(GIMP_LIB_DIR gimp-2.0 gimplibdir)
install(TARGETS file-jxl RUNTIME DESTINATION "${GIMP_LIB_DIR}/plug-ins/file-jxl/")
