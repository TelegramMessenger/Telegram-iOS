# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

find_package(Threads REQUIRED)

include(jxl_lists.cmake)

### Define the jxl_threads shared or static target library. The ${target}
# parameter should already be created with add_library(), but this function
# sets all the remaining common properties.
function(_set_jxl_threads _target)
  target_compile_options(${_target} PRIVATE ${JPEGXL_INTERNAL_FLAGS})
  target_compile_options(${_target} PUBLIC ${JPEGXL_COVERAGE_FLAGS})
  set_property(TARGET ${_target} PROPERTY POSITION_INDEPENDENT_CODE ON)

  target_include_directories(${_target}
    PRIVATE
      "${PROJECT_SOURCE_DIR}"
    PUBLIC
      "${CMAKE_CURRENT_SOURCE_DIR}/include"
      "${CMAKE_CURRENT_BINARY_DIR}/include")

  target_link_libraries(${_target}
    PUBLIC ${JPEGXL_COVERAGE_FLAGS} Threads::Threads
  )

  set_target_properties(${_target} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN 1
    DEFINE_SYMBOL JXL_THREADS_INTERNAL_LIBRARY_BUILD
  )

  # Always install the library as jxl_threads.{a,so} file without the "-static"
  # suffix, except in Windows.
  if (NOT WIN32 OR MINGW)
    set_target_properties(${_target} PROPERTIES OUTPUT_NAME "jxl_threads")
  endif()
  install(TARGETS ${_target}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
endfunction()

### Static library.
add_library(jxl_threads-static STATIC ${JPEGXL_INTERNAL_THREADS_SOURCES})
_set_jxl_threads(jxl_threads-static)

# Make jxl_threads symbols neither imported nor exported when using the static
# library. These will have hidden visibility anyway in the static library case
# in unix.
target_compile_definitions(jxl_threads-static
  PUBLIC -DJXL_THREADS_STATIC_DEFINE)


### Public shared library.
if (BUILD_SHARED_LIBS)
add_library(jxl_threads SHARED ${JPEGXL_INTERNAL_THREADS_SOURCES})
_set_jxl_threads(jxl_threads)

set_target_properties(jxl_threads PROPERTIES
  VERSION ${JPEGXL_LIBRARY_VERSION}
  SOVERSION ${JPEGXL_LIBRARY_SOVERSION}
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")

  set_target_properties(jxl_threads PROPERTIES
      LINK_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/jxl/jxl.version)
  if(APPLE)
  set_property(TARGET ${target} APPEND_STRING PROPERTY
      LINK_FLAGS "-Wl,-exported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/jxl/jxl_osx.syms")
  elseif(WIN32)
    # Nothing needed here, we use __declspec(dllexport) (jxl_threads_export.h)
  else()
  set_property(TARGET jxl_threads APPEND_STRING PROPERTY
      LINK_FLAGS " -Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/jxl/jxl.version")
  endif()  # APPLE

# Compile the shared library such that the JXL_THREADS_EXPORT symbols are
# exported. Users of the library will not set this flag and therefore import
# those symbols.
target_compile_definitions(jxl_threads
  PRIVATE -DJXL_THREADS_INTERNAL_LIBRARY_BUILD)

# Generate the jxl/jxl_threads_export.h header, we only need to generate it once
# but we can use it from both libraries.
generate_export_header(jxl_threads
  BASE_NAME JXL_THREADS
  EXPORT_FILE_NAME include/jxl/jxl_threads_export.h)
else()
add_library(jxl_threads ALIAS jxl_threads-static)
# When not building the shared library generate the jxl_threads_export.h header
# only based on the static target.
generate_export_header(jxl_threads-static
  BASE_NAME JXL_THREADS
  EXPORT_FILE_NAME include/jxl/jxl_threads_export.h)
endif()  # BUILD_SHARED_LIBS


### Add a pkg-config file for libjxl_threads.

# Allow adding prefix if CMAKE_INSTALL_INCLUDEDIR not absolute.
if(IS_ABSOLUTE "${CMAKE_INSTALL_INCLUDEDIR}")
    set(PKGCONFIG_TARGET_INCLUDES "${CMAKE_INSTALL_INCLUDEDIR}")
else()
    set(PKGCONFIG_TARGET_INCLUDES "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
endif()
# Allow adding prefix if CMAKE_INSTALL_LIBDIR not absolute.
if(IS_ABSOLUTE "${CMAKE_INSTALL_LIBDIR}")
    set(PKGCONFIG_TARGET_LIBS "${CMAKE_INSTALL_LIBDIR}")
else()
    set(PKGCONFIG_TARGET_LIBS "\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}")
endif()

set(JPEGXL_THREADS_LIBRARY_REQUIRES "")
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/threads/libjxl_threads.pc.in"
               "libjxl_threads.pc" @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libjxl_threads.pc"
  DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
