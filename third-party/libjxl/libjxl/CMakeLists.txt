# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Ubuntu bionic ships with cmake 3.10.
cmake_minimum_required(VERSION 3.10)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Honor VISIBILITY_INLINES_HIDDEN on all types of targets.
if(POLICY CMP0063)
  cmake_policy(SET CMP0063 NEW)
endif()
# Pass CMAKE_EXE_LINKER_FLAGS to CC and CXX compilers when testing if they work.
if(POLICY CMP0065)
  cmake_policy(SET CMP0065 NEW)
endif()

# Set PIE flags for POSITION_INDEPENDENT_CODE targets, added in 3.14.
if(POLICY CMP0083)
  cmake_policy(SET CMP0083 NEW)
endif()

project(LIBJXL LANGUAGES C CXX)

include(CheckCXXSourceCompiles)
check_cxx_source_compiles(
   "int main() {
      #if !defined(__EMSCRIPTEN__)
      static_assert(false, \"__EMSCRIPTEN__ is not defined\");
      #endif
      return 0;
    }"
  JPEGXL_EMSCRIPTEN
)

message(STATUS "CMAKE_SYSTEM_PROCESSOR is ${CMAKE_SYSTEM_PROCESSOR}")
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-fsanitize=fuzzer-no-link" CXX_FUZZERS_SUPPORTED)
check_cxx_compiler_flag("-Xclang -mconstructor-aliases" CXX_CONSTRUCTOR_ALIASES_SUPPORTED)
check_cxx_compiler_flag("-fmacro-prefix-map=OLD=NEW" CXX_MACRO_PREFIX_MAP)
check_cxx_compiler_flag("-fno-rtti" CXX_NO_RTTI_SUPPORTED)

# Enabled PIE binaries by default if supported.
include(CheckPIESupported OPTIONAL RESULT_VARIABLE CHECK_PIE_SUPPORTED)
if(CHECK_PIE_SUPPORTED)
  check_pie_supported(LANGUAGES CXX)
  if(CMAKE_CXX_LINK_PIE_SUPPORTED)
    set(CMAKE_POSITION_INDEPENDENT_CODE TRUE)
  endif()
endif()

if(PROVISION_DEPENDENCIES)
  # Run script to provision dependencies.
  find_program (BASH_PROGRAM bash)
  if(BASH_PROGRAM)
    execute_process(
      COMMAND ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/deps.sh
      RESULT_VARIABLE PROVISION_DEPENDENCIES_RESULT)
  endif()
  if(NOT PROVISION_DEPENDENCIES_RESULT EQUAL "0")
    message(FATAL_ERROR "${CMAKE_CURRENT_SOURCE_DIR}/deps.sh failed with ${PROVISION_DEPENDENCIES_RESULT}")
  endif()
endif()

### Project build options:
if(CXX_FUZZERS_SUPPORTED)
  # Enabled by default except on arm64, Windows and Apple builds.
  set(ENABLE_FUZZERS_DEFAULT true)
endif()
find_package(PkgConfig)
if(NOT APPLE AND NOT WIN32 AND NOT HAIKU AND CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
  pkg_check_modules(TCMallocMinimalVersionCheck QUIET IMPORTED_TARGET
      libtcmalloc_minimal)
  if(TCMallocMinimalVersionCheck_FOUND AND
     NOT TCMallocMinimalVersionCheck_VERSION VERSION_EQUAL 2.8.0)
    # Enabled by default except on Windows and Apple builds for
    # tcmalloc != 2.8.0. tcmalloc 2.8.1 already has a fix for this issue.
    set(ENABLE_TCMALLOC_DEFAULT true)
  else()
    message(STATUS
        "tcmalloc version ${TCMallocMinimalVersionCheck_VERSION} -- "
        "tcmalloc 2.8.0 disabled due to "
        "https://github.com/gperftools/gperftools/issues/1204")
  endif()
endif()

check_cxx_source_compiles(
   "int main() {
      #if !defined(HWY_DISABLED_TARGETS)
      static_assert(false, \"HWY_DISABLED_TARGETS is not defined\");
      #endif
      return 0;
    }"
  JXL_HWY_DISABLED_TARGETS_FORCED
)

set(WARNINGS_AS_ERRORS_DEFAULT false)

if((SANITIZER STREQUAL "msan") OR JPEGXL_EMSCRIPTEN)
  set(BUNDLE_LIBPNG_DEFAULT YES)
else()
  set(BUNDLE_LIBPNG_DEFAULT NO)
endif()

# Standard cmake naming for building shared libraries.
get_property(SHARED_LIBS_SUPPORTED GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS)
option(BUILD_SHARED_LIBS "Build shared libraries instead of static ones" ${SHARED_LIBS_SUPPORTED})

set(JPEGXL_ENABLE_FUZZERS ${ENABLE_FUZZERS_DEFAULT} CACHE BOOL
    "Build JPEGXL fuzzer targets.")
set(JPEGXL_ENABLE_DEVTOOLS false CACHE BOOL
    "Build JPEGXL developer tools.")
set(JPEGXL_ENABLE_TOOLS true CACHE BOOL
    "Build JPEGXL user tools: cjxl and djxl.")
set(JPEGXL_ENABLE_JPEGLI true CACHE BOOL
    "Build jpegli library.")
set(JPEGXL_ENABLE_JPEGLI_LIBJPEG true CACHE BOOL
    "Build libjpeg.so shared library based on jpegli.")
set(JPEGXL_INSTALL_JPEGLI_LIBJPEG false CACHE BOOL
    "Install jpegli version of libjpeg.so system-wide.")
set(JPEGLI_LIBJPEG_LIBRARY_VERSION "62.3.0" CACHE STRING
    "Library version of the libjpeg.so shared library that we build.")
set(JPEGLI_LIBJPEG_LIBRARY_SOVERSION "62" CACHE STRING
    "Library so-version of the libjpeg.so shared library that we build.")
set(JPEGXL_ENABLE_DOXYGEN true CACHE BOOL
    "Generate C API documentation using Doxygen.")
set(JPEGXL_ENABLE_MANPAGES true CACHE BOOL
    "Build and install man pages for the command-line tools.")
set(JPEGXL_ENABLE_BENCHMARK true CACHE BOOL
    "Build JPEGXL benchmark tools.")
set(JPEGXL_ENABLE_EXAMPLES true CACHE BOOL
    "Build JPEGXL library usage examples.")
set(JPEGXL_BUNDLE_LIBPNG ${BUNDLE_LIBPNG_DEFAULT} CACHE BOOL
    "Build libpng from source and link it statically.")
set(JPEGXL_ENABLE_JNI true CACHE BOOL
    "Build JPEGXL JNI Java wrapper, if Java dependencies are installed.")
set(JPEGXL_ENABLE_SJPEG true CACHE BOOL
    "Build JPEGXL with support for encoding with sjpeg.")
set(JPEGXL_ENABLE_OPENEXR true CACHE BOOL
    "Build JPEGXL with support for OpenEXR if available.")
set(JPEGXL_ENABLE_SKCMS true CACHE BOOL
    "Build with skcms instead of lcms2.")
set(JPEGXL_BUNDLE_SKCMS true CACHE BOOL
    "When building with skcms, bundle it into libjxl.a.")
set(JPEGXL_ENABLE_VIEWERS false CACHE BOOL
    "Build JPEGXL viewer tools for evaluation.")
set(JPEGXL_ENABLE_TCMALLOC ${ENABLE_TCMALLOC_DEFAULT} CACHE BOOL
    "Build JPEGXL using gperftools (tcmalloc) allocator.")
set(JPEGXL_ENABLE_PLUGINS false CACHE BOOL
    "Build third-party plugins to support JPEG XL in other applications.")
set(JPEGXL_ENABLE_COVERAGE false CACHE BOOL
    "Enable code coverage tracking for libjxl. This also enables debug and disables optimizations.")
set(JPEGXL_ENABLE_SIZELESS_VECTORS false CACHE BOOL
    "Builds in support for SVE/RVV vectorization")
set(JPEGXL_ENABLE_TRANSCODE_JPEG true CACHE BOOL
    "Builds in support for decoding transcoded JXL files back to JPEG,\
 disabling it makes the decoder reject JXL_DEC_JPEG_RECONSTRUCTION events,\
 (default enabled)")
set(JPEGXL_ENABLE_BOXES true CACHE BOOL
    "Builds in support for decoding boxes in JXL files,\
 disabling it makes the decoder reject JXL_DEC_BOX events,\
 (default enabled)")
set(JPEGXL_STATIC false CACHE BOOL
    "Build tools as static binaries.")
set(JPEGXL_WARNINGS_AS_ERRORS ${WARNINGS_AS_ERRORS_DEFAULT} CACHE BOOL
    "Treat warnings as errors during compilation.")
set(JPEGXL_DEP_LICENSE_DIR "" CACHE STRING
    "Directory where to search for system dependencies \"copyright\" files.")
set(JPEGXL_FORCE_NEON false CACHE BOOL
    "Set flags to enable NEON in arm if not enabled by your toolchain.")
set(JPEGXL_TEST_TOOLS false CACHE BOOL
    "Run scripts that test the encoding / decoding tools.")
set(JPEGXL_ENABLE_AVX512 false CACHE BOOL
    "Build with AVX512 support (faster on CPUs that support it, but larger binary size).")
set(JPEGXL_ENABLE_AVX512_ZEN4 false CACHE BOOL
    "Build with Zen4-optimized AVX512 support (faster on CPUs that support it, but larger binary size).")

# Force system dependencies.
set(JPEGXL_FORCE_SYSTEM_BROTLI false CACHE BOOL
    "Force using system installed brotli instead of third_party/brotli source.")
set(JPEGXL_FORCE_SYSTEM_GTEST false CACHE BOOL
    "Force using system installed googletest (gtest/gmock) instead of third_party/googletest source.")
set(JPEGXL_FORCE_SYSTEM_LCMS2 false CACHE BOOL
    "Force using system installed lcms2 instead of third_party/lcms source.")
set(JPEGXL_FORCE_SYSTEM_HWY false CACHE BOOL
    "Force using system installed highway (libhwy-dev) instead of third_party/highway source.")

# Check minimum compiler versions. Older compilers are not supported and fail
# with hard to understand errors.
if (NOT CMAKE_C_COMPILER_ID STREQUAL CMAKE_CXX_COMPILER_ID)
  message(FATAL_ERROR "Different C/C++ compilers set: "
          "${CMAKE_C_COMPILER_ID} vs ${CMAKE_CXX_COMPILER_ID}")
endif()
if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  # Android NDK's toolchain.cmake fakes the clang version in
  # CMAKE_CXX_COMPILER_VERSION with an incorrect number, so ignore this.
  if (NOT CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION MATCHES "clang"
      AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 5)
    message(FATAL_ERROR
      "Minimum Clang version required is Clang 5, please update.")
  endif()
elseif (CMAKE_CXX_COMPILER_ID MATCHES "GNU")
  if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 7)
    message(FATAL_ERROR
      "Minimum GCC version required is 7, please update.")
  endif()
endif()

message(STATUS
    "Compiled IDs C:${CMAKE_C_COMPILER_ID}, C++:${CMAKE_CXX_COMPILER_ID}")

# Always disable SSSE3 since it is rare to have SSSE3 but not SSE4
set(HWY_DISABLED_TARGETS "HWY_SSSE3")
if (NOT JPEGXL_ENABLE_AVX512)
  message(STATUS "Disabled AVX512 (set JPEGXL_ENABLE_AVX512 to enable it)")
  set(HWY_DISABLED_TARGETS "${HWY_DISABLED_TARGETS}|HWY_AVX3")
  add_definitions(-DFJXL_ENABLE_AVX512=0)
endif()
if (NOT JPEGXL_ENABLE_AVX512_ZEN4)
  message(STATUS "Disabled AVX512_ZEN4 (set JPEGXL_ENABLE_AVX512_ZEN4 to enable it)")
  set(HWY_DISABLED_TARGETS "${HWY_DISABLED_TARGETS}|HWY_AVX3_ZEN4")
endif()



# CMAKE_EXPORT_COMPILE_COMMANDS is used to generate the compilation database
# used by clang-tidy.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(JPEGXL_STATIC)
  set(BUILD_SHARED_LIBS 0)
  # Clang developers say that in case to use "static" we have to build stdlib
  # ourselves; for real use case we don't care about stdlib, as it is "granted",
  # so just linking all other libraries is fine.
  if (NOT MSVC AND NOT APPLE)
    set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
    set(CMAKE_EXE_LINKER_FLAGS
        "${CMAKE_EXE_LINKER_FLAGS} -static -static-libgcc -static-libstdc++")
  endif()
endif()  # JPEGXL_STATIC

# Threads
set(THREADS_PREFER_PTHREAD_FLAG YES)
find_package(Threads REQUIRED)

# These settings are important to drive check_cxx_source_compiles
# See CMP0067 (min cmake version is 3.10 anyway)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD_REQUIRED YES)

# Atomics
find_package(Atomics REQUIRED)

if(JPEGXL_STATIC)
  if (MINGW)
    # In MINGW libstdc++ uses pthreads directly. When building statically a
    # program (regardless of whether the source code uses pthread or not) the
    # toolchain will add stdc++ and pthread to the linking step but stdc++ will
    # be linked statically while pthread will be linked dynamically.
    # To avoid this and have pthread statically linked with need to pass it in
    # the command line with "-Wl,-Bstatic -lpthread -Wl,-Bdynamic" but the
    # linker will discard it if not used by anything else up to that point in
    # the linker command line. If the program or any dependency don't use
    # pthread directly -lpthread is discarded and libstdc++ (added by the
    # toolchain later) will then use the dynamic version. For this we also need
    # to pass -lstdc++ explicitly before -lpthread. For pure C programs -lstdc++
    # will be discarded anyway.
    # This adds these flags as dependencies for *all* targets. Adding this to
    # CMAKE_EXE_LINKER_FLAGS instead would cause them to be included before any
    # object files and therefore discarded. This should be set in the
    # INTERFACE_LINK_LIBRARIES of Threads::Threads but some third_part targets
    # don't depend on it.
    link_libraries(-Wl,-Bstatic -lstdc++ -lpthread -Wl,-Bdynamic)
  elseif(CMAKE_USE_PTHREADS_INIT)
    # "whole-archive" is not supported on OSX.
    if (NOT APPLE)
      # Set pthreads as a whole-archive, otherwise weak symbols in the static
      # libraries will discard pthreads symbols leading to segmentation fault at
      # runtime.
      message(STATUS "Using -lpthread as --whole-archive")
      set_target_properties(Threads::Threads PROPERTIES
        INTERFACE_LINK_LIBRARIES
            "-Wl,--whole-archive;-lpthread;-Wl,--no-whole-archive")
    endif()
  endif()
endif()  # JPEGXL_STATIC

if (JPEGXL_EMSCRIPTEN)
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pthread")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -pthread")
endif()

if (CXX_MACRO_PREFIX_MAP)
  add_compile_options(-fmacro-prefix-map=${CMAKE_CURRENT_SOURCE_DIR}=.)
endif()

if (CXX_NO_RTTI_SUPPORTED)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-rtti")
endif()

# Internal flags for coverage builds:
set(JPEGXL_COVERAGE_FLAGS)
set(JPEGXL_COVERAGE_LINK_FLAGS)

if (MSVC)
  # TODO(janwas): add flags
  add_definitions(-D_CRT_SECURE_NO_WARNINGS)
else ()
  # Global compiler flags for all targets here and in subdirectories.
  add_definitions(
    # Avoid changing the binary based on the current time and date.
    -D__DATE__="redacted"
    -D__TIMESTAMP__="redacted"
    -D__TIME__="redacted"
  )

  # TODO(eustas): JXL currently compiles, but does not pass tests...
  if (NOT JXL_HWY_DISABLED_TARGETS_FORCED)
    if (NOT JPEGXL_ENABLE_SIZELESS_VECTORS)
      set(HWY_DISABLED_TARGETS "${HWY_DISABLED_TARGETS}|HWY_SVE|HWY_SVE2|HWY_SVE_256|HWY_SVE2_128|HWY_RVV")
    endif()
    add_definitions(-DHWY_DISABLED_TARGETS=\(${HWY_DISABLED_TARGETS}\))
  endif()

  # In CMake before 3.12 it is problematic to pass repeated flags like -Xclang.
  # For this reason we place them in CMAKE_CXX_FLAGS instead.
  # See https://gitlab.kitware.com/cmake/cmake/issues/15826

  # Machine flags.
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -funwind-tables")
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Xclang -mrelax-all")
  endif()
  if (CXX_CONSTRUCTOR_ALIASES_SUPPORTED)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Xclang -mconstructor-aliases")
  endif()

  if(WIN32)
    # Not supported by clang-cl, but frame pointers are default on Windows
  else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-omit-frame-pointer")
  endif()

  # CPU flags - remove once we have NEON dynamic dispatch

  # TODO(janwas): this also matches M1, but only ARMv7 is intended/needed.
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
    if(JPEGXL_FORCE_NEON)
      # GCC requires these flags, otherwise __ARM_NEON is undefined.
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} \
        -mfpu=neon-vfpv4 -mfloat-abi=hard")
    endif()
  endif()

  # Force build with optimizations in release mode.
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O2")

  add_compile_options(
    # Ignore this to allow redefining __DATE__ and others.
    -Wno-builtin-macro-redefined

    # Global warning settings.
    -Wall
  )

  if (JPEGXL_WARNINGS_AS_ERRORS)
    add_compile_options(-Werror)
  endif ()

  if(JPEGXL_ENABLE_COVERAGE)
    set(JPEGXL_COVERAGE_FLAGS
        -g -O0 -fprofile-arcs -ftest-coverage
        -DJXL_ENABLE_ASSERT=0 -DJXL_ENABLE_CHECK=0
    )
    set(JPEGXL_COVERAGE_LINK_FLAGS
        --coverage
    )
  endif()  # JPEGXL_ENABLE_COVERAGE
endif ()  # !MSVC

include(GNUInstallDirs)

# Separately build/configure testing frameworks and other third_party libraries
# to allow disabling tests in those libraries.
include(third_party/testing.cmake)
add_subdirectory(third_party)
# Copy the JXL license file to the output build directory.
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
               ${PROJECT_BINARY_DIR}/LICENSE.jpeg-xl COPYONLY)

# Enable tests regardless of where they are defined.
enable_testing()
include(CTest)
# Specify default location of `testdata`:
if(NOT DEFINED JPEGXL_TEST_DATA_PATH)
  set(JPEGXL_TEST_DATA_PATH "${PROJECT_SOURCE_DIR}/testdata")
endif()

# Libraries.
add_subdirectory(lib)

if(BUILD_TESTING)
  # Script to run tests over the source code in bash.
  find_program (BASH_PROGRAM bash)
  if(BASH_PROGRAM)
    add_test(
      NAME bash_test
      COMMAND ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/bash_test.sh)
  endif()
endif() # BUILD_TESTING

# Documentation generated by Doxygen
if(JPEGXL_ENABLE_DOXYGEN)
  find_package(Doxygen)
  if(DOXYGEN_FOUND)
    set(DOXYGEN_GENERATE_HTML "YES")
    set(DOXYGEN_GENERATE_XML "YES")
    set(DOXYGEN_STRIP_FROM_PATH "${CMAKE_CURRENT_SOURCE_DIR}/lib/include")
    set(DOXYGEN_USE_MDFILE_AS_MAINPAGE "README.md")
    if(JPEGXL_WARNINGS_AS_ERRORS)
      set(DOXYGEN_WARN_AS_ERROR "YES")
    endif()
    set(DOXYGEN_QUIET "YES")
    doxygen_add_docs(doc
      "${CMAKE_CURRENT_SOURCE_DIR}/lib/include"
      "${CMAKE_CURRENT_SOURCE_DIR}/doc/api.txt"
      WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
      COMMENT "Generating C API documentation")

    # Add sphinx doc build step for readthedocs.io (requires doxygen too).
    find_program(SPHINX_BUILD_PROGRAM sphinx-build)
    if(SPHINX_BUILD_PROGRAM)
      add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/rtd/nonexistent"
        COMMENT "Generating readthedocs.io output on ${CMAKE_CURRENT_BINARY_DIR}/rtd"
        COMMAND ${SPHINX_BUILD_PROGRAM} -q -W -b html -j auto
          ${CMAKE_SOURCE_DIR}/doc/sphinx
          ${CMAKE_CURRENT_BINARY_DIR}/rtd
        DEPENDS doc
      )
      # This command runs the documentation generation every time since the output
      # target file doesn't exist.
      add_custom_target(rtd-html
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/rtd/nonexistent
      )
    else() # SPHINX_BUILD_PROGRAM\
      message(WARNING "sphinx-build not found, skipping rtd documentation")
    endif() # SPHINX_BUILD_PROGRAM

  else()
    # Create a "doc" target for compatibility since "doc" is not otherwise added to
    # the build when doxygen is not installed.
    add_custom_target(doc false
      COMMENT "Error: Can't generate doc since Doxygen not installed.")
  endif() # DOXYGEN_FOUND
endif() # JPEGXL_ENABLE_DOXYGEN

if(JPEGXL_ENABLE_MANPAGES)
  find_program(ASCIIDOC a2x)
  if(ASCIIDOC)
    file(STRINGS "${ASCIIDOC}" ASCIIDOC_SHEBANG LIMIT_COUNT 1)
    if(ASCIIDOC_SHEBANG MATCHES "/sh|/bash" OR MINGW)
      set(ASCIIDOC_PY_FOUND ON)
      # Run the program directly and set ASCIIDOC as empty.
      set(ASCIIDOC_PY "${ASCIIDOC}")
      set(ASCIIDOC "")
    elseif(ASCIIDOC_SHEBANG MATCHES "python2")
      find_package(Python2 COMPONENTS Interpreter)
      set(ASCIIDOC_PY_FOUND "${Python2_Interpreter_FOUND}")
      set(ASCIIDOC_PY Python2::Interpreter)
    elseif(ASCIIDOC_SHEBANG MATCHES "python3")
      find_package(Python3 COMPONENTS Interpreter)
      set(ASCIIDOC_PY_FOUND "${Python3_Interpreter_FOUND}")
      set(ASCIIDOC_PY Python3::Interpreter)
    else()
      find_package(Python COMPONENTS Interpreter QUIET)
      if(NOT Python_Interpreter_FOUND)
        find_program(ASCIIDOC_PY python)
        if(ASCIIDOC_PY)
          set(ASCIIDOC_PY_FOUND ON)
        endif()
      else()
        set(ASCIIDOC_PY_FOUND "${Python_Interpreter_FOUND}")
        set(ASCIIDOC_PY Python::Interpreter)
      endif()
    endif()

    if (ASCIIDOC_PY_FOUND)
      set(MANPAGE_FILES "")
      set(MANPAGES "")
      foreach(PAGE IN ITEMS cjxl djxl)
        # Invoking the Python interpreter ourselves instead of running the a2x binary
        # directly is necessary on MSYS2, otherwise it is run through cmd.exe which
        # does not recognize it.
        add_custom_command(
          OUTPUT "${PAGE}.1"
          COMMAND "${ASCIIDOC_PY}"
          ARGS ${ASCIIDOC}
            --format manpage --destination-dir="${CMAKE_CURRENT_BINARY_DIR}"
            "${CMAKE_CURRENT_SOURCE_DIR}/doc/man/${PAGE}.txt"
          MAIN_DEPENDENCY "${CMAKE_CURRENT_SOURCE_DIR}/doc/man/${PAGE}.txt")
        list(APPEND MANPAGE_FILES "${CMAKE_CURRENT_BINARY_DIR}/${PAGE}.1")
        list(APPEND MANPAGES "${PAGE}.1")
      endforeach()
      add_custom_target(manpages ALL DEPENDS ${MANPAGES})
      install(FILES ${MANPAGE_FILES} DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)
    endif()  # ASCIIDOC_PY_FOUND
  else()
    message(WARNING "asciidoc was not found, the man pages will not be installed.")
  endif()  # ASCIIDOC
endif()  # JPEGXL_ENABLE_MANPAGES

# Example usage code.
if (JPEGXL_ENABLE_EXAMPLES)
  include(examples/examples.cmake)
endif ()

# Plugins for third-party software
if (JPEGXL_ENABLE_PLUGINS)
  add_subdirectory(plugins)
endif ()

# Binary tools
add_subdirectory(tools)
