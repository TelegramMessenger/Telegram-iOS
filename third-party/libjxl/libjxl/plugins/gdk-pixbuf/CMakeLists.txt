# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(PkgConfig)
pkg_check_modules(Gdk-Pixbuf IMPORTED_TARGET gdk-pixbuf-2.0>=2.36)

include(GNUInstallDirs)

if (NOT Gdk-Pixbuf_FOUND)
  message(WARNING "GDK Pixbuf development libraries not found, \
                   the Gdk-Pixbuf plugin will not be built")
  return ()
endif ()

add_library(pixbufloader-jxl MODULE pixbufloader-jxl.c)

# Mark all symbols as hidden by default. The PkgConfig::Gdk-Pixbuf dependency
# will cause fill_info and fill_vtable entry points to be made public.
set_target_properties(pixbufloader-jxl PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN 1
)

# Note: This only needs the decoder library, but we don't install the decoder
# shared library.
target_link_libraries(pixbufloader-jxl jxl jxl_threads lcms2 PkgConfig::Gdk-Pixbuf)

execute_process(COMMAND ${PKG_CONFIG_EXECUTABLE} gdk-pixbuf-2.0 --variable gdk_pixbuf_moduledir --define-variable=prefix=${CMAKE_INSTALL_PREFIX} OUTPUT_VARIABLE GDK_PIXBUF_MODULEDIR OUTPUT_STRIP_TRAILING_WHITESPACE)
install(TARGETS pixbufloader-jxl DESTINATION "${GDK_PIXBUF_MODULEDIR}")

# Instead of the following, we might instead add the
# mime type image/jxl to
# /usr/share/thumbnailers/gdk-pixbuf-thumbnailer.thumbnailer
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/jxl.thumbnailer DESTINATION "${CMAKE_INSTALL_DATADIR}/thumbnailers/")

if(BUILD_TESTING AND NOT CMAKE_CROSSCOMPILING)
  pkg_check_modules(Gdk IMPORTED_TARGET gdk-2.0)
  if (Gdk_FOUND)
    # Test for loading a .jxl file using the pixbufloader library via GDK. This
    # requires to have the image/jxl mime type and loader library configured,
    # which we do in a fake environment in the CMAKE_CURRENT_BINARY_DIR.
    add_executable(pixbufloader_test pixbufloader_test.cc)
    target_link_libraries(pixbufloader_test PkgConfig::Gdk)

    # Create a mime cache for test.
    add_custom_command(
      OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/mime/mime.cache"
      COMMAND env XDG_DATA_HOME=${CMAKE_CURRENT_BINARY_DIR}
        xdg-mime install --novendor
        "${CMAKE_SOURCE_DIR}/plugins/mime/image-jxl.xml"
      DEPENDS "${CMAKE_SOURCE_DIR}/plugins/mime/image-jxl.xml"
    )
    add_custom_target(pixbufloader_test_mime
      DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/mime/mime.cache"
    )
    add_dependencies(pixbufloader_test pixbufloader_test_mime)

    # Use a fake X server to run the test if xvfb is installed.
    find_program (XVFB_PROGRAM xvfb-run)
    if(XVFB_PROGRAM)
      set(XVFB_PROGRAM_PREFIX "${XVFB_PROGRAM};-a")
    else()
      set(XVFB_PROGRAM_PREFIX "")
    endif()

    # libX11.so and libgdk-x11-2.0.so are not compiled with MSAN -> report
    # use-of-uninitialized-value for string some internal string value.
    # TODO(eustas): investigate direct memory leak (32 bytes).
    if (NOT (SANITIZER STREQUAL "msan") AND NOT (SANITIZER STREQUAL "asan"))
      add_test(
        NAME pixbufloader_test_jxl
        COMMAND
          ${XVFB_PROGRAM_PREFIX} $<TARGET_FILE:pixbufloader_test>
          "${CMAKE_CURRENT_SOURCE_DIR}/loaders_test.cache"
          "${CMAKE_SOURCE_DIR}/testdata/jxl/blending/cropped_traffic_light.jxl"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      )
      set_tests_properties(pixbufloader_test_jxl PROPERTIES SKIP_RETURN_CODE 254)
    endif()
  endif()  # Gdk_FOUND
endif()  # BUILD_TESTING
