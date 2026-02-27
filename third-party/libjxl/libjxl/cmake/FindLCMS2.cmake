# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(PkgConfig QUIET)
if (PkgConfig_FOUND)
  pkg_check_modules(PC_LCMS2 QUIET libLCMS2)
  set(LCMS2_VERSION ${PC_LCMS2_VERSION})
endif ()

find_path(LCMS2_INCLUDE_DIR
  NAMES lcms2.h
  HINTS ${PC_LCMS2_INCLUDEDIR} ${PC_LCMS2_INCLUDE_DIRS}
)

find_library(LCMS2_LIBRARY
  NAMES ${LCMS2_NAMES} lcms2 liblcms2 lcms-2 liblcms-2
  HINTS ${PC_LCMS2_LIBDIR} ${PC_LCMS2_LIBRARY_DIRS}
)

if (LCMS2_INCLUDE_DIR AND NOT LCMS_VERSION)
    file(READ ${LCMS2_INCLUDE_DIR}/lcms2.h LCMS2_VERSION_CONTENT)
    string(REGEX MATCH "#define[ \t]+LCMS_VERSION[ \t]+([0-9]+)[ \t]*\n" LCMS2_VERSION_MATCH ${LCMS2_VERSION_CONTENT})
    if (LCMS2_VERSION_MATCH)
        string(SUBSTRING ${CMAKE_MATCH_1} 0 1 LCMS2_VERSION_MAJOR)
        string(SUBSTRING ${CMAKE_MATCH_1} 1 2 LCMS2_VERSION_MINOR)
        set(LCMS2_VERSION "${LCMS2_VERSION_MAJOR}.${LCMS2_VERSION_MINOR}")
    endif ()
endif ()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LCMS2
  FOUND_VAR LCMS2_FOUND
  REQUIRED_VARS LCMS2_LIBRARY LCMS2_INCLUDE_DIR
  VERSION_VAR LCMS2_VERSION
)

if (LCMS2_LIBRARY AND NOT TARGET lcms2)
  add_library(lcms2 INTERFACE IMPORTED GLOBAL)

  if(CMAKE_VERSION VERSION_LESS "3.13.5")
    set_property(TARGET lcms2 PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${LCMS2_INCLUDE_DIR})
    target_link_libraries(lcms2 INTERFACE ${LCMS2_LIBRARY})
    set_property(TARGET lcms2 PROPERTY INTERFACE_COMPILE_OPTIONS ${PC_LCMS2_CFLAGS_OTHER})
  else()
    target_include_directories(lcms2 INTERFACE ${LCMS2_INCLUDE_DIR})
    target_link_libraries(lcms2 INTERFACE ${LCMS2_LIBRARY})
    target_link_options(lcms2 INTERFACE ${PC_LCMS2_LDFLAGS_OTHER})
    target_compile_options(lcms2 INTERFACE ${PC_LCMS2_CFLAGS_OTHER})
  endif()
endif()

mark_as_advanced(LCMS2_INCLUDE_DIR LCMS2_LIBRARY)

if (LCMS2_FOUND)
    set(LCMS2_LIBRARIES ${LCMS2_LIBRARY})
    set(LCMS2_INCLUDE_DIRS ${LCMS2_INCLUDE_DIR})
endif ()
