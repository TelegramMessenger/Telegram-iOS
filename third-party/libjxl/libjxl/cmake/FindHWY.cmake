# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(PkgConfig QUIET)
if (PkgConfig_FOUND)
  pkg_check_modules(PC_HWY QUIET libhwy)
  set(HWY_VERSION ${PC_HWY_VERSION})
endif ()

find_path(HWY_INCLUDE_DIR
  NAMES hwy/highway.h
  HINTS ${PC_HWY_INCLUDEDIR} ${PC_HWY_INCLUDE_DIRS}
)

find_library(HWY_LIBRARY
  NAMES ${HWY_NAMES} hwy
  HINTS ${PC_HWY_LIBDIR} ${PC_HWY_LIBRARY_DIRS}
)

if (HWY_INCLUDE_DIR AND NOT HWY_VERSION)
  if (EXISTS "${HWY_INCLUDE_DIR}/hwy/highway.h")
    file(READ "${HWY_INCLUDE_DIR}/hwy/highway.h" HWY_VERSION_CONTENT)

    string(REGEX MATCH "#define HWY_MAJOR +([0-9]+)" _dummy "${HWY_VERSION_CONTENT}")
    set(HWY_VERSION_MAJOR "${CMAKE_MATCH_1}")

    string(REGEX MATCH "#define +HWY_MINOR +([0-9]+)" _dummy "${HWY_VERSION_CONTENT}")
    set(HWY_VERSION_MINOR "${CMAKE_MATCH_1}")

    string(REGEX MATCH "#define +HWY_PATCH +([0-9]+)" _dummy "${HWY_VERSION_CONTENT}")
    set(HWY_VERSION_PATCH "${CMAKE_MATCH_1}")

    set(HWY_VERSION "${HWY_VERSION_MAJOR}.${HWY_VERSION_MINOR}.${HWY_VERSION_PATCH}")
  endif ()
endif ()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(HWY
  FOUND_VAR HWY_FOUND
  REQUIRED_VARS HWY_LIBRARY HWY_INCLUDE_DIR
  VERSION_VAR HWY_VERSION
)

if (HWY_LIBRARY AND NOT TARGET hwy)
  add_library(hwy INTERFACE IMPORTED GLOBAL)

  if(CMAKE_VERSION VERSION_LESS "3.13.5")
    set_property(TARGET hwy PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${HWY_INCLUDE_DIR})
    target_link_libraries(hwy INTERFACE ${HWY_LIBRARY})
    set_property(TARGET hwy PROPERTY INTERFACE_COMPILE_OPTIONS ${PC_HWY_CFLAGS_OTHER})
  else()
    target_include_directories(hwy INTERFACE ${HWY_INCLUDE_DIR})
    target_link_libraries(hwy INTERFACE ${HWY_LIBRARY})
    target_link_options(hwy INTERFACE ${PC_HWY_LDFLAGS_OTHER})
    target_compile_options(hwy INTERFACE ${PC_HWY_CFLAGS_OTHER})
  endif()
endif()

mark_as_advanced(HWY_INCLUDE_DIR HWY_LIBRARY)

if (HWY_FOUND)
    set(HWY_LIBRARIES ${HWY_LIBRARY})
    set(HWY_INCLUDE_DIRS ${HWY_INCLUDE_DIR})
endif ()
