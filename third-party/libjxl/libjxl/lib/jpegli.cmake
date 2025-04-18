# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

include(compatibility.cmake)
include(jxl_lists.cmake)

set(JPEGLI_INTERNAL_LIBS
  hwy
  Threads::Threads
  ${ATOMICS_LIBRARIES}
)

# JPEGLIB setup
set(BITS_IN_JSAMPLE 8)
set(MEM_SRCDST_SUPPORTED 1)

if(JPEGLI_LIBJPEG_LIBRARY_SOVERSION STREQUAL "62")
  set(JPEG_LIB_VERSION 62)
elseif(JPEGLI_LIBJPEG_LIBRARY_SOVERSION STREQUAL "7")
  set(JPEG_LIB_VERSION 70)
elseif(JPEGLI_LIBJPEG_LIBRARY_SOVERSION STREQUAL "8")
  set(JPEG_LIB_VERSION 80)
endif()

configure_file(
  ../third_party/libjpeg-turbo/jconfig.h.in include/jpegli/jconfig.h)
configure_file(
  ../third_party/libjpeg-turbo/jpeglib.h include/jpegli/jpeglib.h COPYONLY)
configure_file(
  ../third_party/libjpeg-turbo/jmorecfg.h include/jpegli/jmorecfg.h COPYONLY)

add_library(jpegli-static STATIC EXCLUDE_FROM_ALL "${JPEGXL_INTERNAL_JPEGLI_SOURCES}")
target_compile_options(jpegli-static PRIVATE "${JPEGXL_INTERNAL_FLAGS}")
target_compile_options(jpegli-static PUBLIC ${JPEGXL_COVERAGE_FLAGS})
set_property(TARGET jpegli-static PROPERTY POSITION_INDEPENDENT_CODE ON)
target_include_directories(jpegli-static PRIVATE
  "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}>"
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>"
  "${JXL_HWY_INCLUDE_DIRS}"
)
target_include_directories(jpegli-static PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include/jpegli>"
)
target_link_libraries(jpegli-static PUBLIC ${JPEGLI_INTERNAL_LIBS})

#
# Tests for jpegli-static
#

find_package(JPEG)
if(JPEG_FOUND AND BUILD_TESTING)
# TODO(eustas): merge into jxl_tests.cmake?

add_library(jpegli_libjpeg_util-obj OBJECT
  ${JPEGXL_INTERNAL_JPEGLI_LIBJPEG_HELPER_FILES}
)
target_include_directories(jpegli_libjpeg_util-obj PRIVATE
  "${PROJECT_SOURCE_DIR}"
  "${JPEG_INCLUDE_DIRS}"
)
target_compile_options(jpegli_libjpeg_util-obj PRIVATE
  "${JPEGXL_INTERNAL_FLAGS}" "${JPEGXL_COVERAGE_FLAGS}")

# Individual test binaries:
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/tests)
foreach (TESTFILE IN LISTS JPEGXL_INTERNAL_JPEGLI_TESTS)
  # The TESTNAME is the name without the extension or directory.
  get_filename_component(TESTNAME ${TESTFILE} NAME_WE)
  add_executable(${TESTNAME} ${TESTFILE}
    $<TARGET_OBJECTS:jpegli_libjpeg_util-obj>
    ${JPEGXL_INTERNAL_JPEGLI_TESTLIB_FILES}
  )
  target_compile_options(${TESTNAME} PRIVATE
    ${JPEGXL_INTERNAL_FLAGS}
    # Add coverage flags to the test binary so code in the private headers of
    # the library is also instrumented when running tests that execute it.
    ${JPEGXL_COVERAGE_FLAGS}
  )
  target_compile_definitions(${TESTNAME} PRIVATE
    -DTEST_DATA_PATH="${JPEGXL_TEST_DATA_PATH}")
  target_include_directories(${TESTNAME} PRIVATE
    "${PROJECT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${CMAKE_CURRENT_BINARY_DIR}/include"
  )
  target_link_libraries(${TESTNAME}
    hwy
    jpegli-static
    gmock
    GTest::GTest
    GTest::Main
    ${JPEG_LIBRARIES}
  )
  set_target_properties(${TESTNAME} PROPERTIES LINK_FLAGS "${JPEGXL_COVERAGE_LINK_FLAGS}")
  # Output test targets in the test directory.
  set_target_properties(${TESTNAME} PROPERTIES PREFIX "tests/")
  if (WIN32 AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set_target_properties(${TESTNAME} PROPERTIES COMPILE_FLAGS "-Wno-error")
  endif ()
  jxl_discover_tests(${TESTNAME})
endforeach ()
endif()

#
# Build libjpeg.so that links to libjpeg-static
#

if (JPEGXL_ENABLE_JPEGLI_LIBJPEG AND NOT APPLE AND NOT WIN32 AND NOT JPEGXL_EMSCRIPTEN)
add_library(jpegli-libjpeg-obj OBJECT "${JPEGXL_INTERNAL_JPEGLI_WRAPPER_SOURCES}")
target_compile_options(jpegli-libjpeg-obj PRIVATE ${JPEGXL_INTERNAL_FLAGS})
target_compile_options(jpegli-libjpeg-obj PUBLIC ${JPEGXL_COVERAGE_FLAGS})
set_property(TARGET jpegli-libjpeg-obj PROPERTY POSITION_INDEPENDENT_CODE ON)
target_include_directories(jpegli-libjpeg-obj PRIVATE
  "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}>"
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include/jpegli>"
)
target_compile_definitions(jpegli-libjpeg-obj PUBLIC
  ${JPEGLI_LIBJPEG_OBJ_COMPILE_DEFINITIONS}
)
set(JPEGLI_LIBJPEG_INTERNAL_OBJECTS $<TARGET_OBJECTS:jpegli-libjpeg-obj>)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/jpegli)
add_library(jpeg SHARED ${JPEGLI_LIBJPEG_INTERNAL_OBJECTS})
target_link_libraries(jpeg PUBLIC ${JPEGXL_COVERAGE_FLAGS})
target_link_libraries(jpeg PRIVATE jpegli-static)
set_target_properties(jpeg PROPERTIES
  VERSION ${JPEGLI_LIBJPEG_LIBRARY_VERSION}
  SOVERSION ${JPEGLI_LIBJPEG_LIBRARY_SOVERSION}
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/jpegli"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/jpegli")

# Add a jpeg.version file as a version script to tag symbols with the
# appropriate version number.
set_target_properties(jpeg PROPERTIES
  LINK_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/jpegli/jpeg.version.${JPEGLI_LIBJPEG_LIBRARY_SOVERSION})
set_property(TARGET jpeg APPEND_STRING PROPERTY
  LINK_FLAGS " -Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/jpegli/jpeg.version.${JPEGLI_LIBJPEG_LIBRARY_SOVERSION}")

if (JPEGXL_INSTALL_JPEGLI_LIBJPEG)
  install(TARGETS jpeg
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
  install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/include/jpegli/"
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
endif()

# This hides the default visibility symbols from static libraries bundled into
# the shared library. In particular this prevents exposing symbols from hwy
# in the shared library.
if(LINKER_SUPPORT_EXCLUDE_LIBS)
  set_property(TARGET jpeg APPEND_STRING PROPERTY
    LINK_FLAGS " ${LINKER_EXCLUDE_LIBS_FLAG}")
endif()
endif()
