# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set(brlibs brotlicommon brotlienc brotlidec)

find_package(PkgConfig QUIET)
if (PkgConfig_FOUND)
  foreach(brlib IN ITEMS ${brlibs})
    string(TOUPPER "${brlib}" BRPREFIX)
    pkg_check_modules("PC_${BRPREFIX}" lib${brlib})
  endforeach()
endif()

find_path(BROTLI_INCLUDE_DIR
  NAMES brotli/decode.h
  HINTS ${PC_BROTLICOMMON_INCLUDEDIR} ${PC_BROTLICOMMON_INCLUDE_DIRS}
)

foreach(brlib IN ITEMS ${brlibs})
  string(TOUPPER "${brlib}" BRPREFIX)
  find_library(${BRPREFIX}_LIBRARY
    NAMES ${${BRPREFIX}_NAMES} ${brlib}
    HINTS ${PC_${BRPREFIX}_LIBDIR} ${PC_${BRPREFIX}_LIBRARY_DIRS}
  )

  if (${BRPREFIX}_LIBRARY AND NOT TARGET ${brlib})
    if(CMAKE_VERSION VERSION_LESS "3.13.5")
    add_library(${brlib} INTERFACE IMPORTED GLOBAL)
      set_property(TARGET ${brlib} PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${BROTLI_INCLUDE_DIR})
      target_link_libraries(${brlib} INTERFACE ${${BRPREFIX}_LIBRARY})
      set_property(TARGET ${brlib} PROPERTY INTERFACE_COMPILE_OPTIONS ${PC_${BRPREFIX}_CFLAGS_OTHER})
    else()
    add_library(${brlib} INTERFACE IMPORTED GLOBAL)
      target_include_directories(${brlib}
        INTERFACE ${BROTLI_INCLUDE_DIR})
      target_link_libraries(${brlib}
        INTERFACE ${${BRPREFIX}_LIBRARY})
      target_link_options(${brlib}
        INTERFACE ${PC_${BRPREFIX}_LDFLAGS_OTHER})
      target_compile_options(${brlib}
        INTERFACE ${PC_${BRPREFIX}_CFLAGS_OTHER})
    endif()
  endif()
endforeach()

if (BROTLICOMMON_FOUND AND BROTLIENC_FOUND AND BROTLIDEC_FOUND)
  set(Brotli_FOUND ON)
else ()
  set(Brotli_FOUND OFF)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Brotli
  FOUND_VAR Brotli_FOUND
  REQUIRED_VARS
    BROTLI_INCLUDE_DIR
    BROTLICOMMON_LIBRARY
    BROTLIENC_LIBRARY
    BROTLIDEC_LIBRARY
  VERSION_VAR Brotli_VERSION
)

mark_as_advanced(
  BROTLI_INCLUDE_DIR
  BROTLICOMMON_LIBRARY
  BROTLIENC_LIBRARY
  BROTLIDEC_LIBRARY
)

if (Brotli_FOUND)
  set(Brotli_LIBRARIES ${BROTLICOMMON_LIBRARY} ${BROTLIENC_LIBRARY} ${BROTLIDEC_LIBRARY})
  set(Brotli_INCLUDE_DIRS ${BROTLI_INCLUDE_DIR})
endif()
