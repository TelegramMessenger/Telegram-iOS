cmake_minimum_required(VERSION 2.8.12)
# When using CMake 3.4 and later, don't export symbols from executables unless
# the CMAKE_ENABLE_EXPORTS variable is set.
if(POLICY CMP0065)
  cmake_policy(SET CMP0065 NEW)
endif()

if(CMAKE_EXECUTABLE_SUFFIX)
  set(CMAKE_EXECUTABLE_SUFFIX_TMP ${CMAKE_EXECUTABLE_SUFFIX})
endif()

project(mozjpeg C)
set(VERSION 4.1.4)
set(COPYRIGHT_YEAR "1991-2023")
string(REPLACE "." ";" VERSION_TRIPLET ${VERSION})
list(GET VERSION_TRIPLET 0 VERSION_MAJOR)
list(GET VERSION_TRIPLET 1 VERSION_MINOR)
list(GET VERSION_TRIPLET 2 VERSION_REVISION)
function(pad_number NUMBER OUTPUT_LEN)
  string(LENGTH "${${NUMBER}}" INPUT_LEN)
  if(INPUT_LEN LESS OUTPUT_LEN)
    math(EXPR ZEROES "${OUTPUT_LEN} - ${INPUT_LEN} - 1")
    set(NUM ${${NUMBER}})
    foreach(C RANGE ${ZEROES})
      set(NUM "0${NUM}")
    endforeach()
    set(${NUMBER} ${NUM} PARENT_SCOPE)
  endif()
endfunction()
pad_number(VERSION_MINOR 3)
pad_number(VERSION_REVISION 3)
set(LIBJPEG_TURBO_VERSION_NUMBER ${VERSION_MAJOR}${VERSION_MINOR}${VERSION_REVISION})

# The libjpeg-turbo build system has never supported and will never support
# being integrated into another build system using add_subdirectory(), because
# doing so would require that we (minimally):
#
# 1. avoid using certain CMake variables, such as CMAKE_SOURCE_DIR,
#    CMAKE_BINARY_DIR, and CMAKE_PROJECT_NAME;
# 2. avoid using implicit include directories and relative paths;
# 3. optionally provide a way to skip the installation of libjpeg-turbo
#    components when the 'install' target is built;
# 4. optionally provide a way to postfix target names, to avoid namespace
#    conflicts;
# 5. restructure the top-level CMakeLists.txt so that it properly sets the
#    PROJECT_VERSION variable; and
# 6. design automated regression tests to ensure that new commits don't break
#    any of the above.
#
# Even if we did all of that, issues would still arise, because it is
# impossible for an upstream build system to anticipate the widely varying
# needs of every downstream build system.  That's why the CMake
# ExternalProject_Add() function exists.  Downstream projects that wish to
# integrate libjpeg-turbo as a subdirectory should either use
# ExternalProject_Add() or make downstream modifications to the libjpeg-turbo
# build system to suit their specific needs.  Please do not file bug reports,
# feature requests, or pull requests regarding this.
if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  message(FATAL_ERROR "The libjpeg-turbo build system cannot be integrated into another build system using add_subdirectory().  Use ExternalProject_Add() instead.")
endif()

# CMake 3.14 and later sets CMAKE_MACOSX_BUNDLE to TRUE by default when
# CMAKE_SYSTEM_NAME is iOS, tvOS, or watchOS, which breaks the libjpeg-turbo
# build.  (Specifically, when CMAKE_MACOSX_BUNDLE is TRUE, executables for
# Apple platforms are built as application bundles, which causes CMake to
# complain that our install() directives for executables do not specify a
# BUNDLE DESTINATION.  Even if CMake did not complain, building executables as
# application bundles would break our iOS packages.)
set(CMAKE_MACOSX_BUNDLE FALSE)

get_property(GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY
  GENERATOR_IS_MULTI_CONFIG)
# If the GENERATOR_IS_MULTI_CONFIG property doesn't exist (CMake < 3.9), then
# set the GENERATOR_IS_MULTI_CONFIG variable manually if the generator is
# Visual Studio or Xcode (the only multi-config generators in CMake < 3.9).
if(NOT GENERATOR_IS_MULTI_CONFIG AND (MSVC_IDE OR XCODE))
  set(GENERATOR_IS_MULTI_CONFIG TRUE)
endif()

string(TIMESTAMP DEFAULT_BUILD "%Y%m%d")
set(BUILD ${DEFAULT_BUILD} CACHE STRING "Build string (default: ${DEFAULT_BUILD})")

# NOTE: On Windows, this does nothing except when using MinGW or Cygwin.
# CMAKE_BUILD_TYPE has no meaning in Visual Studio, and it always defaults to
# Debug when using NMake.
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()
message(STATUS "CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}")

message(STATUS "VERSION = ${VERSION}, BUILD = ${BUILD}")

include(cmakescripts/PackageInfo.cmake)

# Detect CPU type and whether we're building 64-bit or 32-bit code
math(EXPR BITS "${CMAKE_SIZEOF_VOID_P} * 8")
string(TOLOWER ${CMAKE_SYSTEM_PROCESSOR} CMAKE_SYSTEM_PROCESSOR_LC)
set(COUNT 1)
foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})
  if(COUNT GREATER 1)
    message(FATAL_ERROR "libjpeg-turbo contains assembly code, so it cannot be built with multiple values in CMAKE_OSX_ARCHITECTURES.")
  endif()
  math(EXPR COUNT "${COUNT}+1")
endforeach()
if(CMAKE_SYSTEM_PROCESSOR_LC MATCHES "x86_64" OR
  CMAKE_SYSTEM_PROCESSOR_LC MATCHES "amd64" OR
  CMAKE_SYSTEM_PROCESSOR_LC MATCHES "i[0-9]86" OR
  CMAKE_SYSTEM_PROCESSOR_LC MATCHES "x86" OR
  CMAKE_SYSTEM_PROCESSOR_LC MATCHES "ia32")
  if(BITS EQUAL 64 OR CMAKE_C_COMPILER_ABI MATCHES "ELF X32")
    set(CPU_TYPE x86_64)
  else()
    set(CPU_TYPE i386)
  endif()
  if(NOT CMAKE_SYSTEM_PROCESSOR STREQUAL ${CPU_TYPE})
    set(CMAKE_SYSTEM_PROCESSOR ${CPU_TYPE})
  endif()
elseif(CMAKE_SYSTEM_PROCESSOR_LC STREQUAL "aarch64" OR
  CMAKE_SYSTEM_PROCESSOR_LC MATCHES "^arm")
  if(BITS EQUAL 64)
    set(CPU_TYPE arm64)
  else()
    set(CPU_TYPE arm)
  endif()
elseif(CMAKE_SYSTEM_PROCESSOR_LC MATCHES "^ppc" OR
  CMAKE_SYSTEM_PROCESSOR_LC MATCHES "^powerpc")
  set(CPU_TYPE powerpc)
else()
  set(CPU_TYPE ${CMAKE_SYSTEM_PROCESSOR_LC})
endif()
if(CMAKE_OSX_ARCHITECTURES MATCHES "x86_64" OR
  CMAKE_OSX_ARCHITECTURES MATCHES "arm64" OR
  CMAKE_OSX_ARCHITECTURES MATCHES "i386")
  set(CPU_TYPE ${CMAKE_OSX_ARCHITECTURES})
endif()
if(CMAKE_OSX_ARCHITECTURES MATCHES "ppc")
  set(CPU_TYPE powerpc)
endif()
if(MSVC_IDE AND CMAKE_GENERATOR_PLATFORM MATCHES "arm64")
  set(CPU_TYPE arm64)
endif()

message(STATUS "${BITS}-bit build (${CPU_TYPE})")


###############################################################################
# INSTALL DIRECTORIES
###############################################################################

if(WIN32)
  if(MSVC)
    set(CMAKE_INSTALL_DEFAULT_PREFIX "c:/${CMAKE_PROJECT_NAME}")
  else()
    set(CMAKE_INSTALL_DEFAULT_PREFIX "c:/${CMAKE_PROJECT_NAME}-gcc")
  endif()
  if(BITS EQUAL 64)
    set(CMAKE_INSTALL_DEFAULT_PREFIX "${CMAKE_INSTALL_DEFAULT_PREFIX}64")
  endif()
else()
  if(NOT CMAKE_INSTALL_DEFAULT_PREFIX)
    set(CMAKE_INSTALL_DEFAULT_PREFIX /opt/${CMAKE_PROJECT_NAME})
  endif()
endif()
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_DEFAULT_PREFIX}" CACHE PATH
    "Directory into which to install ${CMAKE_PROJECT_NAME} (default: ${CMAKE_INSTALL_DEFAULT_PREFIX})"
    FORCE)
endif()
message(STATUS "CMAKE_INSTALL_PREFIX = ${CMAKE_INSTALL_PREFIX}")

# When the prefix is /opt/${CMAKE_PROJECT_NAME}, we assume that an "official"
# build is being created, and thus we install things into specific locations.

if(CMAKE_INSTALL_PREFIX STREQUAL "${CMAKE_INSTALL_DEFAULT_PREFIX}")
  set(CMAKE_INSTALL_DEFAULT_DATAROOTDIR "")
  set(CMAKE_INSTALL_DEFAULT_DOCDIR "<CMAKE_INSTALL_DATAROOTDIR>/doc")
  set(CMAKE_INSTALL_DEFAULT_JAVADIR "<CMAKE_INSTALL_DATAROOTDIR>/classes")
  if(UNIX AND NOT APPLE)
    if(BITS EQUAL 64)
      set(CMAKE_INSTALL_DEFAULT_LIBDIR "lib64")
    elseif(CMAKE_C_COMPILER_ABI MATCHES "ELF X32")
      set(CMAKE_INSTALL_DEFAULT_LIBDIR "libx32")
    else()
      set(CMAKE_INSTALL_DEFAULT_LIBDIR "lib32")
    endif()
  endif()
endif()

include(cmakescripts/GNUInstallDirs.cmake)

macro(report_directory var)
  if(CMAKE_INSTALL_${var} STREQUAL CMAKE_INSTALL_FULL_${var})
    message(STATUS "CMAKE_INSTALL_${var} = ${CMAKE_INSTALL_${var}}")
  else()
    message(STATUS "CMAKE_INSTALL_${var} = ${CMAKE_INSTALL_${var}} (${CMAKE_INSTALL_FULL_${var}})")
  endif()
  mark_as_advanced(CLEAR CMAKE_INSTALL_${var})
endmacro()

set(DIRLIST "BINDIR;DATAROOTDIR;DOCDIR;INCLUDEDIR;LIBDIR")
if(UNIX)
  list(APPEND DIRLIST "MANDIR")
endif()
foreach(dir ${DIRLIST})
  report_directory(${dir})
endforeach()


###############################################################################
# CONFIGURATION OPTIONS
###############################################################################

macro(boolean_number var)
  if(${var})
    set(${var} 1 ${ARGN})
  else()
    set(${var} 0 ${ARGN})
  endif()
endmacro()

option(ENABLE_SHARED "Build shared libraries" TRUE)
boolean_number(ENABLE_SHARED)
option(ENABLE_STATIC "Build static libraries" TRUE)
boolean_number(ENABLE_STATIC)
option(REQUIRE_SIMD "Generate a fatal error if SIMD extensions are not available for this platform (default is to fall back to a non-SIMD build)" FALSE)
boolean_number(REQUIRE_SIMD)
option(PNG_SUPPORTED "Enable PNG support (requires libpng)" TRUE)
boolean_number(PNG_SUPPORTED)
option(WITH_12BIT "Encode/decode JPEG images with 12-bit samples (implies WITH_ARITH_DEC=0 WITH_ARITH_ENC=0 WITH_JAVA=0 WITH_SIMD=0 WITH_TURBOJPEG=0 )" FALSE)
boolean_number(WITH_12BIT)
option(WITH_ARITH_DEC "Include arithmetic decoding support when emulating the libjpeg v6b API/ABI" FALSE)
boolean_number(WITH_ARITH_DEC)
option(WITH_ARITH_ENC "Include arithmetic encoding support when emulating the libjpeg v6b API/ABI" FALSE)
boolean_number(WITH_ARITH_ENC)
if(CMAKE_C_COMPILER_ABI MATCHES "ELF X32")
  set(WITH_JAVA 0)
else()
  option(WITH_JAVA "Build Java wrapper for the TurboJPEG API library (implies ENABLE_SHARED=1)" FALSE)
  boolean_number(WITH_JAVA)
endif()
option(WITH_JPEG7 "Emulate libjpeg v7 API/ABI (this makes ${CMAKE_PROJECT_NAME} backward-incompatible with libjpeg v6b)" FALSE)
boolean_number(WITH_JPEG7)
option(WITH_JPEG8 "Emulate libjpeg v8 API/ABI (this makes ${CMAKE_PROJECT_NAME} backward-incompatible with libjpeg v6b)" FALSE)
boolean_number(WITH_JPEG8)
option(WITH_MEM_SRCDST "Include in-memory source/destination manager functions when emulating the libjpeg v6b or v7 API/ABI" TRUE)
boolean_number(WITH_MEM_SRCDST)
option(WITH_SIMD "Include SIMD extensions, if available for this platform" TRUE)
boolean_number(WITH_SIMD)
option(WITH_TURBOJPEG "Include the TurboJPEG API library and associated test programs" TRUE)
boolean_number(WITH_TURBOJPEG)
option(WITH_FUZZ "Build fuzz targets" FALSE)

macro(report_option var desc)
  if(${var})
    message(STATUS "${desc} enabled (${var} = ${${var}})")
  else()
    message(STATUS "${desc} disabled (${var} = ${${var}})")
  endif()
endmacro()

if(WITH_JAVA)
  set(ENABLE_SHARED 1)
endif()

# Explicitly setting CMAKE_POSITION_INDEPENDENT_CODE=FALSE disables PIC for all
# targets, which will cause the shared library builds to fail.  Thus, if shared
# libraries are enabled and CMAKE_POSITION_INDEPENDENT_CODE is explicitly set
# to FALSE, we need to unset it, thus restoring the default behavior
# (automatically using PIC for shared library targets.)
if(DEFINED CMAKE_POSITION_INDEPENDENT_CODE AND
  NOT CMAKE_POSITION_INDEPENDENT_CODE AND ENABLE_SHARED)
  unset(CMAKE_POSITION_INDEPENDENT_CODE CACHE)
endif()

report_option(ENABLE_SHARED "Shared libraries")
report_option(ENABLE_STATIC "Static libraries")

if(ENABLE_SHARED)
  set(CMAKE_INSTALL_RPATH ${CMAKE_INSTALL_FULL_LIBDIR})
endif()

if(WITH_JPEG8 OR WITH_JPEG7)
  set(WITH_ARITH_ENC 1)
  set(WITH_ARITH_DEC 1)
endif()
if(WITH_JPEG8)
  set(WITH_MEM_SRCDST 0)
endif()

if(WITH_12BIT)
  set(WITH_ARITH_DEC 0)
  set(WITH_ARITH_ENC 0)
  set(WITH_JAVA 0)
  set(WITH_SIMD 0)
  set(WITH_TURBOJPEG 0)
  set(BITS_IN_JSAMPLE 12)
else()
  set(BITS_IN_JSAMPLE 8)
endif()
report_option(WITH_12BIT "12-bit JPEG support")

if(WITH_ARITH_DEC)
  set(D_ARITH_CODING_SUPPORTED 1)
endif()
if(NOT WITH_12BIT)
  report_option(WITH_ARITH_DEC "Arithmetic decoding support")
endif()

if(WITH_ARITH_ENC)
  set(C_ARITH_CODING_SUPPORTED 1)
endif()
if(NOT WITH_12BIT)
  report_option(WITH_ARITH_ENC "Arithmetic encoding support")
endif()

if(NOT WITH_12BIT)
  report_option(WITH_TURBOJPEG "TurboJPEG API library")
  report_option(WITH_JAVA "TurboJPEG Java wrapper")
endif()

if(WITH_MEM_SRCDST)
  set(MEM_SRCDST_SUPPORTED 1)
  set(MEM_SRCDST_FUNCTIONS "global:  jpeg_mem_dest;  jpeg_mem_src;")
endif()
if(NOT WITH_JPEG8)
  report_option(WITH_MEM_SRCDST "In-memory source/destination managers")
endif()

# 0: Original libjpeg v6b/v7/v8 API/ABI
#
# libjpeg v6b/v7 API/ABI emulation:
# 1: + In-memory source/destination managers (libjpeg-turbo 1.3.x)
# 2: + Partial image decompression functions (libjpeg-turbo 1.5.x)
# 3: + ICC functions (libjpeg-turbo 2.0.x)
#
# libjpeg v8 API/ABI emulation:
# 1: + Partial image decompression functions (libjpeg-turbo 1.5.x)
# 2: + ICC functions (libjpeg-turbo 2.0.x)
set(SO_AGE 2)
if(WITH_MEM_SRCDST)
  set(SO_AGE 3)
endif()

if(WITH_JPEG8)
  set(JPEG_LIB_VERSION 80)
elseif(WITH_JPEG7)
  set(JPEG_LIB_VERSION 70)
else()
  set(JPEG_LIB_VERSION 62)
endif()

math(EXPR JPEG_LIB_VERSION_DIV10 "${JPEG_LIB_VERSION} / 10")
math(EXPR JPEG_LIB_VERSION_MOD10 "${JPEG_LIB_VERSION} % 10")
if(JPEG_LIB_VERSION STREQUAL "62")
  set(DEFAULT_SO_MAJOR_VERSION ${JPEG_LIB_VERSION})
else()
  set(DEFAULT_SO_MAJOR_VERSION ${JPEG_LIB_VERSION_DIV10})
endif()
if(JPEG_LIB_VERSION STREQUAL "80")
  set(DEFAULT_SO_MINOR_VERSION 2)
else()
  set(DEFAULT_SO_MINOR_VERSION 0)
endif()

# This causes SO_MAJOR_VERSION/SO_MINOR_VERSION to reset to defaults if
# WITH_JPEG7 or WITH_JPEG8 has changed.
if((DEFINED WITH_JPEG7_INT AND NOT WITH_JPEG7 EQUAL WITH_JPEG7_INT) OR
  (DEFINED WITH_JPEG8_INT AND NOT WITH_JPEG8 EQUAL WITH_JPEG8_INT))
  set(FORCE_SO_VERSION "FORCE")
endif()
set(WITH_JPEG7_INT ${WITH_JPEG7} CACHE INTERNAL "")
set(WITH_JPEG8_INT ${WITH_JPEG8} CACHE INTERNAL "")

set(SO_MAJOR_VERSION ${DEFAULT_SO_MAJOR_VERSION} CACHE STRING
  "Major version of the libjpeg API shared library (default: ${DEFAULT_SO_MAJOR_VERSION})"
  ${FORCE_SO_VERSION})
set(SO_MINOR_VERSION ${DEFAULT_SO_MINOR_VERSION} CACHE STRING
  "Minor version of the libjpeg API shared library (default: ${DEFAULT_SO_MINOR_VERSION})"
  ${FORCE_SO_VERSION})

set(JPEG_LIB_VERSION_DECIMAL "${JPEG_LIB_VERSION_DIV10}.${JPEG_LIB_VERSION_MOD10}")
message(STATUS "Emulating libjpeg API/ABI v${JPEG_LIB_VERSION_DECIMAL} (WITH_JPEG7 = ${WITH_JPEG7}, WITH_JPEG8 = ${WITH_JPEG8})")
message(STATUS "libjpeg API shared library version = ${SO_MAJOR_VERSION}.${SO_AGE}.${SO_MINOR_VERSION}")

# Because the TurboJPEG API library uses versioned symbols and changes the
# names of functions whenever they are modified in a backward-incompatible
# manner, it is always backward-ABI-compatible with itself, so the major and
# minor SO versions don't change.  However, we increase the middle number (the
# SO "age") whenever functions are added to the API, because adding functions
# affects forward API/ABI compatibility.
set(TURBOJPEG_SO_MAJOR_VERSION 0)
# 0: TurboJPEG 1.3.x API
# 1: TurboJPEG 1.4.x API
#    The TurboJPEG 1.5.x API modified some of the function prototypes, adding
#    the const keyword in front of pointers to unmodified buffers, but that did
#    not affect forward API/ABI compatibility.
# 2: TurboJPEG 2.0.x API
#    The TurboJPEG 2.1.x API modified the behavior of the tjDecompressHeader3()
#    function so that it accepts "abbreviated table specification" (AKA
#    "tables-only") datastreams as well as JPEG images, but that did not affect
#    forward API/ABI compatibility.
set(TURBOJPEG_SO_AGE 2)
set(TURBOJPEG_SO_VERSION 0.${TURBOJPEG_SO_AGE}.0)


###############################################################################
# COMPILER SETTINGS
###############################################################################

if(MSVC)
  option(WITH_CRT_DLL
    "Link all ${CMAKE_PROJECT_NAME} libraries and executables with the C run-time DLL (msvcr*.dll) instead of the static C run-time library (libcmt*.lib.)  The default is to use the C run-time DLL only with the libraries and executables that need it."
    FALSE)
  if(NOT WITH_CRT_DLL)
    # Use the static C library for all build types
    foreach(var CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
      CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO)
      if(${var} MATCHES "/MD")
        string(REGEX REPLACE "/MD" "/MT" ${var} "${${var}}")
      endif()
    endforeach()
  endif()
  add_definitions(-D_CRT_NONSTDC_NO_WARNINGS)
endif()

if(CMAKE_COMPILER_IS_GNUCC OR CMAKE_C_COMPILER_ID STREQUAL "Clang")
  # Use the maximum optimization level for release builds
  foreach(var CMAKE_C_FLAGS_RELEASE CMAKE_C_FLAGS_RELWITHDEBINFO)
    if(${var} MATCHES "-O2")
      string(REGEX REPLACE "-O2" "-O3" ${var} "${${var}}")
    endif()
  endforeach()
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
  if(CMAKE_C_COMPILER_ID MATCHES "SunPro")
    # Use the maximum optimization level for release builds
    foreach(var CMAKE_C_FLAGS_RELEASE CMAKE_C_FLAGS_RELWITHDEBINFO)
      if(${var} MATCHES "-xO3")
        string(REGEX REPLACE "-xO3" "-xO5" ${var} "${${var}}")
      endif()
      if(${var} MATCHES "-xO2")
        string(REGEX REPLACE "-xO2" "-xO5" ${var} "${${var}}")
      endif()
    endforeach()
  endif()
endif()

string(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_UC)

set(EFFECTIVE_C_FLAGS "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE_UC}}")
message(STATUS "Compiler flags = ${EFFECTIVE_C_FLAGS}")

set(EFFECTIVE_LD_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_EXE_LINKER_FLAGS_${CMAKE_BUILD_TYPE_UC}}")
message(STATUS "Linker flags = ${EFFECTIVE_LD_FLAGS}")

include(CheckCSourceCompiles)
include(CheckIncludeFiles)
include(CheckTypeSize)

check_type_size("size_t" SIZE_T)
check_type_size("unsigned long" UNSIGNED_LONG)

if(SIZE_T EQUAL UNSIGNED_LONG)
  check_c_source_compiles("int main(int argc, char **argv) { unsigned long a = argc;  return __builtin_ctzl(a); }"
    HAVE_BUILTIN_CTZL)
endif()
if(MSVC)
  check_include_files("intrin.h" HAVE_INTRIN_H)
endif()

if(UNIX)
  if(CMAKE_CROSSCOMPILING)
    set(RIGHT_SHIFT_IS_UNSIGNED 0)
  else()
    include(CheckCSourceRuns)
    check_c_source_runs("
      #include <stdio.h>
      #include <stdlib.h>
      int is_shifting_signed (long arg) {
        long res = arg >> 4;
        if (res == -0x7F7E80CL)
          return 1; /* right shift is signed */
        /* see if unsigned-shift hack will fix it. */
        /* we can't just test exact value since it depends on width of long... */
        res |= (~0L) << (32-4);
        if (res == -0x7F7E80CL)
          return 0; /* right shift is unsigned */
        printf(\"Right shift isn't acting as I expect it to.\\\\n\");
        printf(\"I fear the JPEG software will not work at all.\\\\n\\\\n\");
        return 0; /* try it with unsigned anyway */
      }
      int main (void) {
        exit(is_shifting_signed(-0x7F7E80B1L));
      }" RIGHT_SHIFT_IS_UNSIGNED)
  endif()
endif()

if(MSVC)
  set(INLINE_OPTIONS "__inline;inline")
else()
  set(INLINE_OPTIONS "__inline__;inline")
endif()
option(FORCE_INLINE "Force function inlining" TRUE)
boolean_number(FORCE_INLINE)
if(FORCE_INLINE)
  if(MSVC)
    list(INSERT INLINE_OPTIONS 0 "__forceinline")
  else()
    list(INSERT INLINE_OPTIONS 0 "inline __attribute__((always_inline))")
    list(INSERT INLINE_OPTIONS 0 "__inline__ __attribute__((always_inline))")
  endif()
endif()
foreach(inline ${INLINE_OPTIONS})
  check_c_source_compiles("${inline} static int foo(void) { return 0; } int main(void) { return foo(); }"
    INLINE_WORKS)
  if(INLINE_WORKS)
    set(INLINE ${inline})
    break()
  endif()
endforeach()
if(NOT INLINE_WORKS)
  message(FATAL_ERROR "Could not determine how to inline functions.")
endif()
message(STATUS "INLINE = ${INLINE} (FORCE_INLINE = ${FORCE_INLINE})")

if(MSVC)
  set(THREAD_LOCAL "__declspec(thread)")
else()
  set(THREAD_LOCAL "__thread")
endif()
check_c_source_compiles("${THREAD_LOCAL} int i;  int main(void) { i = 0;  return i; }" HAVE_THREAD_LOCAL)
if(HAVE_THREAD_LOCAL)
  message(STATUS "THREAD_LOCAL = ${THREAD_LOCAL}")
else()
  message(WARNING "Thread-local storage is not available.  The TurboJPEG API library's global error handler will not be thread-safe.")
  unset(THREAD_LOCAL)
endif()

if(UNIX AND NOT APPLE)
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/conftest.map "VERS_1 { global: *; };")
  set(CMAKE_REQUIRED_FLAGS
    "-Wl,--version-script,${CMAKE_CURRENT_BINARY_DIR}/conftest.map")
  check_c_source_compiles("int main(void) { return 0; }" HAVE_VERSION_SCRIPT)
  set(CMAKE_REQUIRED_FLAGS)
  file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/conftest.map)
  if(HAVE_VERSION_SCRIPT)
    message(STATUS "Linker supports GNU-style version scripts")
    set(MAPFLAG "-Wl,--version-script,")
    set(TJMAPFLAG "-Wl,--version-script,")
  else()
    message(STATUS "Linker does not support GNU-style version scripts")
    if(CMAKE_SYSTEM_NAME STREQUAL "SunOS")
      # The Solaris linker doesn't like our version script for the libjpeg API
      # library, but the version script for the TurboJPEG API library should
      # still work.
      file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/conftest.map
        "VERS_1 { global: foo;  local: *; }; VERS_2 { global: foo2; } VERS_1;")
      set(CMAKE_REQUIRED_FLAGS "-Wl,-M,${CMAKE_CURRENT_BINARY_DIR}/conftest.map -shared")
      check_c_source_compiles("int foo() { return 0; } int foo2() { return 2; }"
        HAVE_MAPFILE)
      set(CMAKE_REQUIRED_FLAGS)
      file(REMOVE ${CMAKE_CURRENT_BINARY_DIR}/conftest.map)
      if(HAVE_MAPFILE)
        message(STATUS "Linker supports mapfiles")
        set(TJMAPFLAG "-Wl,-M,")
      else()
        message(STATUS "Linker does not support mapfiles")
      endif()
    endif()
  endif()
endif()

# Generate files
if(WIN32)
  configure_file(win/jconfig.h.in jconfig.h)
else()
  configure_file(jconfig.h.in jconfig.h)
endif()
configure_file(jconfigint.h.in jconfigint.h)
configure_file(jversion.h.in jversion.h)
if(UNIX)
  configure_file(libjpeg.map.in libjpeg.map)
endif()

# Include directories and compiler definitions
include_directories(${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR})


###############################################################################
# TARGETS
###############################################################################

if(CMAKE_EXECUTABLE_SUFFIX_TMP)
  set(CMAKE_EXECUTABLE_SUFFIX ${CMAKE_EXECUTABLE_SUFFIX_TMP})
endif()
message(STATUS "CMAKE_EXECUTABLE_SUFFIX = ${CMAKE_EXECUTABLE_SUFFIX}")

set(JPEG_SOURCES jcapimin.c jcapistd.c jccoefct.c jccolor.c jcdctmgr.c jchuff.c jcext.c
  jcicc.c jcinit.c jcmainct.c jcmarker.c jcmaster.c jcomapi.c jcparam.c
  jcphuff.c jcprepct.c jcsample.c jctrans.c jdapimin.c jdapistd.c jdatadst.c
  jdatasrc.c jdcoefct.c jdcolor.c jddctmgr.c jdhuff.c jdicc.c jdinput.c
  jdmainct.c jdmarker.c jdmaster.c jdmerge.c jdphuff.c jdpostct.c jdsample.c
  jdtrans.c jerror.c jfdctflt.c jfdctfst.c jfdctint.c jidctflt.c jidctfst.c
  jidctint.c jidctred.c jquant1.c jquant2.c jutils.c jmemmgr.c jmemnobs.c)

if(WITH_ARITH_ENC OR WITH_ARITH_DEC)
  set(JPEG_SOURCES ${JPEG_SOURCES} jaricom.c)
endif()

if(WITH_ARITH_ENC)
  set(JPEG_SOURCES ${JPEG_SOURCES} jcarith.c)
endif()

if(WITH_ARITH_DEC)
  set(JPEG_SOURCES ${JPEG_SOURCES} jdarith.c)
endif()

if(WITH_SIMD)
  add_subdirectory(simd)
  if(NEON_INTRINSICS)
    add_definitions(-DNEON_INTRINSICS)
  endif()
elseif(NOT WITH_12BIT)
  message(STATUS "SIMD extensions: None (WITH_SIMD = ${WITH_SIMD})")
endif()
if(WITH_SIMD)
  message(STATUS "SIMD extensions: ${CPU_TYPE} (WITH_SIMD = ${WITH_SIMD})")
  if(MSVC_IDE OR XCODE)
    set_source_files_properties(${SIMD_OBJS} PROPERTIES GENERATED 1)
  endif()
else()
  add_library(simd OBJECT jsimd_none.c)
  if(NOT WIN32 AND (CMAKE_POSITION_INDEPENDENT_CODE OR ENABLE_SHARED))
    set_target_properties(simd PROPERTIES POSITION_INDEPENDENT_CODE 1)
  endif()
endif()

if(WITH_JAVA)
  add_subdirectory(java)
endif()

if(ENABLE_SHARED)
  add_subdirectory(sharedlib)
endif()

if(ENABLE_STATIC)
  add_library(jpeg-static STATIC ${JPEG_SOURCES} $<TARGET_OBJECTS:simd>
    ${SIMD_OBJS})
  if(NOT MSVC)
    set_target_properties(jpeg-static PROPERTIES OUTPUT_NAME jpeg)
  endif()
endif()

if(WITH_TURBOJPEG)
  if(ENABLE_SHARED)
    set(TURBOJPEG_SOURCES ${JPEG_SOURCES} $<TARGET_OBJECTS:simd> ${SIMD_OBJS}
      turbojpeg.c transupp.c jdatadst-tj.c jdatasrc-tj.c rdbmp.c rdppm.c
      wrbmp.c wrppm.c)
    set(TJMAPFILE ${CMAKE_CURRENT_SOURCE_DIR}/turbojpeg-mapfile)
    if(WITH_JAVA)
      set(TURBOJPEG_SOURCES ${TURBOJPEG_SOURCES} turbojpeg-jni.c)
      include_directories(${JAVA_INCLUDE_PATH} ${JAVA_INCLUDE_PATH2})
      set(TJMAPFILE ${CMAKE_CURRENT_SOURCE_DIR}/turbojpeg-mapfile.jni)
    endif()
    if(MSVC)
      configure_file(${CMAKE_SOURCE_DIR}/win/turbojpeg.rc.in
        ${CMAKE_BINARY_DIR}/win/turbojpeg.rc)
      set(TURBOJPEG_SOURCES ${TURBOJPEG_SOURCES}
        ${CMAKE_BINARY_DIR}/win/turbojpeg.rc)
    endif()
    add_library(turbojpeg SHARED ${TURBOJPEG_SOURCES})
    set_property(TARGET turbojpeg PROPERTY COMPILE_FLAGS
      "-DBMP_SUPPORTED -DPPM_SUPPORTED")
    if(WIN32)
      set_target_properties(turbojpeg PROPERTIES DEFINE_SYMBOL DLLDEFINE)
    endif()
    if(MINGW)
      set_target_properties(turbojpeg PROPERTIES LINK_FLAGS -Wl,--kill-at)
    endif()
    if(APPLE AND (NOT CMAKE_OSX_DEPLOYMENT_TARGET OR
                  CMAKE_OSX_DEPLOYMENT_TARGET VERSION_GREATER 10.4))
      if(NOT CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG)
        set(CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG "-Wl,-rpath,")
      endif()
      set_target_properties(turbojpeg PROPERTIES MACOSX_RPATH 1)
    endif()
    set_target_properties(turbojpeg PROPERTIES
      SOVERSION ${TURBOJPEG_SO_MAJOR_VERSION} VERSION ${TURBOJPEG_SO_VERSION})
    if(TJMAPFLAG)
      set_target_properties(turbojpeg PROPERTIES
        LINK_FLAGS "${TJMAPFLAG}${TJMAPFILE}")
    endif()

    add_executable(tjunittest tjunittest.c tjutil.c md5/md5.c md5/md5hl.c)
    target_link_libraries(tjunittest turbojpeg)
    if(UNIX)
      target_link_libraries(tjunittest m)
    endif()

    add_executable(tjbench tjbench.c tjutil.c)
    target_link_libraries(tjbench turbojpeg)
    if(UNIX)
      target_link_libraries(tjbench m)
    endif()

    add_executable(tjexample tjexample.c)
    target_link_libraries(tjexample turbojpeg)
    if(UNIX)
      target_link_libraries(tjexample m)
  endif()
  endif()

  if(ENABLE_STATIC)
    add_library(turbojpeg-static STATIC ${JPEG_SOURCES} $<TARGET_OBJECTS:simd>
      ${SIMD_OBJS} turbojpeg.c transupp.c jdatadst-tj.c jdatasrc-tj.c rdbmp.c
      rdppm.c wrbmp.c wrppm.c)
    set_property(TARGET turbojpeg-static PROPERTY COMPILE_FLAGS
      "-DBMP_SUPPORTED -DPPM_SUPPORTED")
    if(NOT MSVC)
      set_target_properties(turbojpeg-static PROPERTIES OUTPUT_NAME turbojpeg)
    endif()

    add_executable(tjunittest-static tjunittest.c tjutil.c md5/md5.c
      md5/md5hl.c)
    target_link_libraries(tjunittest-static turbojpeg-static)
    if(UNIX)
      target_link_libraries(tjunittest-static m)
    endif()

    add_executable(tjbench-static tjbench.c tjutil.c)
    target_link_libraries(tjbench-static turbojpeg-static)
    if(UNIX)
      target_link_libraries(tjbench-static m)
    endif()
  endif()
endif()

if(WIN32)
  set(USE_SETMODE "-DUSE_SETMODE")
endif()
if(WITH_12BIT)
  set(COMPILE_FLAGS "-DGIF_SUPPORTED -DPPM_SUPPORTED ${USE_SETMODE}")
else()
  set(COMPILE_FLAGS "-DBMP_SUPPORTED -DGIF_SUPPORTED -DPPM_SUPPORTED -DTARGA_SUPPORTED ${USE_SETMODE}")
  set(CJPEG_BMP_SOURCES rdbmp.c rdtarga.c)
  set(DJPEG_BMP_SOURCES wrbmp.c wrtarga.c)

  if(PNG_SUPPORTED)
    report_option(PNG_SUPPORTED "PNG reading support")
    set(COMPILE_FLAGS "${COMPILE_FLAGS} -DPNG_SUPPORTED")
    set(CJPEG_BMP_SOURCES ${CJPEG_BMP_SOURCES} rdpng.c)
  endif()
endif()

if(ENABLE_STATIC)
  add_executable(cjpeg-static cjpeg.c cdjpeg.c rdgif.c rdppm.c rdjpeg.c rdswitch.c
    ${CJPEG_BMP_SOURCES})
  set_property(TARGET cjpeg-static PROPERTY COMPILE_FLAGS ${COMPILE_FLAGS})
  target_link_libraries(cjpeg-static jpeg-static)
  if(UNIX)
    target_link_libraries(cjpeg-static m)
  endif()

  if(PNG_SUPPORTED)
    # to avoid finding shared library from CMake cache
    unset(PNG_LIBRARY CACHE)
    unset(PNG_LIBRARY_RELEASE CACHE)
    unset(PNG_LIBRARY_DEBUG CACHE)
    unset(ZLIB_LIBRARY CACHE)
    unset(ZLIB_LIBRARY_RELEASE CACHE)
    unset(ZLIB_LIBRARY_DEBUG CACHE)

    if (APPLE)
      find_package(ZLIB REQUIRED) # macos doesn't have static zlib
    endif()
    set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_STATIC_LIBRARY_SUFFIX})
    find_package(PNG 1.6 REQUIRED)
    if (NOT APPLE)
      find_package(ZLIB REQUIRED)
    endif()
    target_include_directories(cjpeg-static PUBLIC ${PNG_INCLUDE_DIR} ${ZLIB_INCLUDE_DIR})
    target_link_libraries(cjpeg-static ${PNG_LIBRARY} ${ZLIB_LIBRARY})
  endif()

  add_executable(djpeg-static djpeg.c cdjpeg.c rdcolmap.c rdswitch.c wrgif.c
    wrppm.c ${DJPEG_BMP_SOURCES})
  set_property(TARGET djpeg-static PROPERTY COMPILE_FLAGS ${COMPILE_FLAGS})
  target_link_libraries(djpeg-static jpeg-static)
  if(UNIX)
    target_link_libraries(djpeg-static m)
  endif()

  add_executable(jpegtran-static jpegtran.c cdjpeg.c rdswitch.c transupp.c)
  target_link_libraries(jpegtran-static jpeg-static)
  if(UNIX)
    target_link_libraries(jpegtran-static m)
  endif()

  set_property(TARGET jpegtran-static PROPERTY COMPILE_FLAGS "${USE_SETMODE}")
endif()

add_executable(rdjpgcom rdjpgcom.c)

add_executable(wrjpgcom wrjpgcom.c)


###############################################################################
# TESTS
###############################################################################

if(WITH_FUZZ)
  add_subdirectory(fuzz)
endif()

add_executable(strtest strtest.c)

add_subdirectory(md5)

if(GENERATOR_IS_MULTI_CONFIG)
  set(OBJDIR "\${CTEST_CONFIGURATION_TYPE}/")
else()
  set(OBJDIR "")
endif()

enable_testing()

if(WITH_12BIT)
  set(TESTORIG testorig12.jpg)
  set(MD5_JPEG_RGB_ISLOW 9d7369207c520d37f2c1cbfcb82b2964)
  set(MD5_JPEG_RGB_ISLOW2 a00bd20d8ae49684640ef7177d2e0b64)
  set(MD5_PPM_RGB_ISLOW f3301d2219783b8b3d942b7239fa50c0)
  set(MD5_JPEG_422_IFAST_OPT 7322e3bd2f127f7de4b40d4480ce60e4)
  set(MD5_PPM_422_IFAST 79807fa552899e66a04708f533e16950)
  set(MD5_JPEG_440_ISLOW e25c1912e38367be505a89c410c1c2d2)
  set(MD5_PPM_440_ISLOW e7d2e26288870cfcb30f3114ad01e380)
  set(MD5_PPM_422M_IFAST 07737bfe8a7c1c87aaa393a0098d16b0)
  set(MD5_JPEG_420_IFAST_Q100_PROG 9447cef4803d9b0f74bcf333cc710a29)
  set(MD5_PPM_420_Q100_IFAST 1b3730122709f53d007255e8dfd3305e)
  set(MD5_PPM_420M_Q100_IFAST 980a1a3c5bf9510022869d30b7d26566)
  set(MD5_JPEG_GRAY_ISLOW 235c90707b16e2e069f37c888b2636d9)
  set(MD5_PPM_GRAY_ISLOW 7213c10af507ad467da5578ca5ee1fca)
  set(MD5_PPM_GRAY_ISLOW_RGB e96ee81c30a6ed422d466338bd3de65d)
  set(MD5_JPEG_420S_IFAST_OPT 7af8e60be4d9c227ec63ac9b6630855e)

  set(MD5_JPEG_3x2_FLOAT_PROG_SSE a8c17daf77b457725ec929e215b603f8)
  set(MD5_PPM_3x2_FLOAT_SSE 42876ab9e5c2f76a87d08db5fbd57956)
  set(MD5_JPEG_3x2_FLOAT_PROG_NO_FP_CONTRACT a8c17daf77b457725ec929e215b603f8)
  set(MD5_PPM_3x2_FLOAT_NO_FP_CONTRACT ${MD5_PPM_3x2_FLOAT_SSE})
  set(MD5_JPEG_3x2_FLOAT_PROG_FP_CONTRACT
    ${MD5_JPEG_3x2_FLOAT_PROG_NO_FP_CONTRACT})
  set(MD5_PPM_3x2_FLOAT_FP_CONTRACT ${MD5_PPM_3x2_FLOAT_SSE})
  set(MD5_JPEG_3x2_FLOAT_PROG_387 bc6dbbefac2872f6b9d6c4a0ae60c3c0)
  set(MD5_PPM_3x2_FLOAT_387 bcc5723c61560463ac60f772e742d092)
  set(MD5_JPEG_3x2_FLOAT_PROG_MSVC e27840755870fa849872e58aa0cd1400)
  set(MD5_PPM_3x2_FLOAT_MSVC 6c2880b83bb1aa41dfe330e7a9768690)

  set(MD5_JPEG_3x2_IFAST_PROG 1396cc2b7185cfe943d408c9d305339e)
  set(MD5_PPM_3x2_IFAST 3975985ef6eeb0a2cdc58daa651ccc00)
  set(MD5_PPM_420M_ISLOW_2_1 4ca6be2a6f326ff9eaab63e70a8259c0)
  set(MD5_PPM_420M_ISLOW_15_8 12aa9f9534c1b3d7ba047322226365eb)
  set(MD5_PPM_420M_ISLOW_13_8 f7e22817c7b25e1393e4ec101e9d4e96)
  set(MD5_PPM_420M_ISLOW_11_8 800a16f9f4dc9b293197bfe11be10a82)
  set(MD5_PPM_420M_ISLOW_9_8 06b7a92a9bc69f4dc36ec40f1937d55c)
  set(MD5_PPM_420M_ISLOW_7_8 3ec444a14a4ab4eab88ffc49c48eca43)
  set(MD5_PPM_420M_ISLOW_3_4 3e726b7ea872445b19437d1c1d4f0d93)
  set(MD5_PPM_420M_ISLOW_5_8 a8a771abdc94301d20ffac119b2caccd)
  set(MD5_PPM_420M_ISLOW_1_2 b419124dd5568b085787234866102866)
  set(MD5_PPM_420M_ISLOW_3_8 343d19015531b7bbe746124127244fa8)
  set(MD5_PPM_420M_ISLOW_1_4 35fd59d866e44659edfa3c18db2a3edb)
  set(MD5_PPM_420M_ISLOW_1_8 ccaed48ac0aedefda5d4abe4013f4ad7)
  set(MD5_PPM_420_ISLOW_SKIP15_31 86664cd9dc956536409e44e244d20a97)
  set(MD5_PPM_420_ISLOW_PROG_CROP62x62_71_71 b1fd2e6de6a6db2b3f5447a0b774a117)
  set(MD5_PPM_444_ISLOW_SKIP1_6 4bfeeafcbaeb2ec4b32a71cc72f64fbc)
  set(MD5_PPM_444_ISLOW_PROG_CROP98x98_13_13 e6d8226f43bb30afe927e8b96646b147)
  set(MD5_JPEG_CROP cdb35ff4b4519392690ea040c56ea99c)
else()
  set(TESTORIG testorig.jpg)
  set(MD5_JPEG_RGB_ISLOW 1d44a406f61da743b5fd31c0a9abdca3)
  set(MD5_JPEG_RGB_ISLOW2 31d121e57b6c2934c890a7fc7763bcd4)
  set(MD5_PPM_RGB_ISLOW 00a257f5393fef8821f2b88ac7421291)
  set(MD5_BMP_RGB_ISLOW_565 f07d2e75073e4bb10f6c6f4d36e2e3be)
  set(MD5_BMP_RGB_ISLOW_565D 4cfa0928ef3e6bb626d7728c924cfda4)
  set(MD5_JPEG_422_IFAST_OPT 2540287b79d913f91665e660303ab2c8)
  set(MD5_PPM_422_IFAST 35bd6b3f833bad23de82acea847129fa)
  set(MD5_JPEG_440_ISLOW 368200a98a9d5041170a6232491522f9)
  set(MD5_PPM_440_ISLOW 59d718725c83d37a0b59b7e4e355d2fb)
  set(MD5_PPM_422M_IFAST 8dbc65323d62cca7c91ba02dd1cfa81d)
  set(MD5_BMP_422M_IFAST_565 3294bd4d9a1f2b3d08ea6020d0db7065)
  set(MD5_BMP_422M_IFAST_565D da98c9c7b6039511be4a79a878a9abc1)
  set(MD5_JPEG_420_IFAST_Q100_PROG 0ba15f9dab81a703505f835f9dbbac6d)
  set(MD5_PPM_420_Q100_IFAST 5a732542015c278ff43635e473a8a294)
  set(MD5_PPM_420M_Q100_IFAST ff692ee9323a3b424894862557c092f1)
  set(MD5_JPEG_GRAY_ISLOW 72b51f894b8f4a10b3ee3066770aa38d)
  set(MD5_PPM_GRAY_ISLOW 8d3596c56eace32f205deccc229aa5ed)
  set(MD5_PPM_GRAY_ISLOW_RGB 116424ac07b79e5e801f00508eab48ec)
  set(MD5_BMP_GRAY_ISLOW_565 12f78118e56a2f48b966f792fedf23cc)
  set(MD5_BMP_GRAY_ISLOW_565D bdbbd616441a24354c98553df5dc82db)
  set(MD5_JPEG_420S_IFAST_OPT 388708217ac46273ca33086b22827ed8)

  set(MD5_JPEG_3x2_FLOAT_PROG_SSE 343e3f8caf8af5986ebaf0bdc13b5c71)
  set(MD5_PPM_3x2_FLOAT_SSE 1a75f36e5904d6fc3a85a43da9ad89bb)
  set(MD5_JPEG_3x2_FLOAT_PROG_NO_FP_CONTRACT 9bca803d2042bd1eb03819e2bf92b3e5)
  set(MD5_PPM_3x2_FLOAT_NO_FP_CONTRACT f6bfab038438ed8f5522fbd33595dcdc)
  set(MD5_JPEG_3x2_FLOAT_PROG_FP_CONTRACT
    ${MD5_JPEG_3x2_FLOAT_PROG_NO_FP_CONTRACT})
  set(MD5_PPM_3x2_FLOAT_FP_CONTRACT 0e917a34193ef976b679a6b069b1be26)
  set(MD5_JPEG_3x2_FLOAT_PROG_387 1657664a410e0822c924b54f6f65e6e9)
  set(MD5_PPM_3x2_FLOAT_387 cb0a1f027f3d2917c902b5640214e025)
  set(MD5_JPEG_3x2_FLOAT_PROG_MSVC 7999ce9cd0ee9b6c7043b7351ab7639d)
  set(MD5_PPM_3x2_FLOAT_MSVC 28cdc448a6b75e97892f0e0f8d4b21f3)

  set(MD5_JPEG_3x2_IFAST_PROG 1ee5d2c1a77f2da495f993c8c7cceca5)
  set(MD5_PPM_3x2_IFAST fd283664b3b49127984af0a7f118fccd)
  set(MD5_JPEG_420_ISLOW_ARI e986fb0a637a8d833d96e8a6d6d84ea1)
  set(MD5_JPEG_444_ISLOW_PROGARI 0a8f1c8f66e113c3cf635df0a475a617)
  set(MD5_PPM_420M_IFAST_ARI 57251da28a35b46eecb7177d82d10e0e)
  set(MD5_JPEG_420_ISLOW 9a68f56bc76e466aa7e52f415d0f4a5f)
  set(MD5_PPM_420M_ISLOW_2_1 9f9de8c0612f8d06869b960b05abf9c9)
  set(MD5_PPM_420M_ISLOW_15_8 b6875bc070720b899566cc06459b63b7)
  set(MD5_PPM_420M_ISLOW_13_8 bc3452573c8152f6ae552939ee19f82f)
  set(MD5_PPM_420M_ISLOW_11_8 d8cc73c0aaacd4556569b59437ba00a5)
  set(MD5_PPM_420M_ISLOW_9_8 d25e61bc7eac0002f5b393aa223747b6)
  set(MD5_PPM_420M_ISLOW_7_8 ddb564b7c74a09494016d6cd7502a946)
  set(MD5_PPM_420M_ISLOW_3_4 8ed8e68808c3fbc4ea764fc9d2968646)
  set(MD5_PPM_420M_ISLOW_5_8 a3363274999da2366a024efae6d16c9b)
  set(MD5_PPM_420M_ISLOW_1_2 e692a315cea26b988c8e8b29a5dbcd81)
  set(MD5_PPM_420M_ISLOW_3_8 79eca9175652ced755155c90e785a996)
  set(MD5_PPM_420M_ISLOW_1_4 79cd778f8bf1a117690052cacdd54eca)
  set(MD5_PPM_420M_ISLOW_1_8 391b3d4aca640c8567d6f8745eb2142f)
  set(MD5_BMP_420_ISLOW_256 4980185e3776e89bd931736e1cddeee6)
  set(MD5_BMP_420_ISLOW_565 bf9d13e16c4923b92e1faa604d7922cb)
  set(MD5_BMP_420_ISLOW_565D 6bde71526acc44bcff76f696df8638d2)
  set(MD5_BMP_420M_ISLOW_565 8dc0185245353cfa32ad97027342216f)
  set(MD5_BMP_420M_ISLOW_565D ce034037d212bc403330df6f915c161b)
  set(MD5_PPM_420_ISLOW_SKIP15_31 c4c65c1e43d7275cd50328a61e6534f0)
  set(MD5_PPM_420_ISLOW_ARI_SKIP16_139 087c6b123db16ac00cb88c5b590bb74a)
  set(MD5_PPM_420_ISLOW_PROG_CROP62x62_71_71 f2c1179887f0ff6c5689ed881ea3f32c)
  set(MD5_PPM_420_ISLOW_ARI_CROP53x53_4_4 886c6775af22370257122f8b16207e6d)
  set(MD5_PPM_444_ISLOW_SKIP1_6 2f4d84e9832ce741f5f0666a84632a5a)
  set(MD5_PPM_444_ISLOW_PROG_CROP98x98_13_13 d04ed9d1a2a059455b343bf07a2433a3)
  set(MD5_PPM_444_ISLOW_ARI_CROP37x37_0_0 cb57b32bd6d03e35432362f7bf184b6d)
  set(MD5_JPEG_CROP b4197f377e621c4e9b1d20471432610d)
endif()

if(WITH_JAVA)
  add_test(TJUnitTest
    ${Java_JAVA_EXECUTABLE} ${JAVAARGS} -cp java/turbojpeg.jar
      -Djava.library.path=${CMAKE_CURRENT_BINARY_DIR}/${OBJDIR}
      TJUnitTest)
  add_test(TJUnitTest-yuv
    ${Java_JAVA_EXECUTABLE} ${JAVAARGS} -cp java/turbojpeg.jar
      -Djava.library.path=${CMAKE_CURRENT_BINARY_DIR}/${OBJDIR}
      TJUnitTest -yuv)
  add_test(TJUnitTest-yuv-nopad
    ${Java_JAVA_EXECUTABLE} ${JAVAARGS} -cp java/turbojpeg.jar
      -Djava.library.path=${CMAKE_CURRENT_BINARY_DIR}/${OBJDIR}
      TJUnitTest -yuv -noyuvpad)
  add_test(TJUnitTest-bi
    ${Java_JAVA_EXECUTABLE} ${JAVAARGS} -cp java/turbojpeg.jar
      -Djava.library.path=${CMAKE_CURRENT_BINARY_DIR}/${OBJDIR}
      TJUnitTest -bi)
  add_test(TJUnitTest-bi-yuv
    ${Java_JAVA_EXECUTABLE} ${JAVAARGS} -cp java/turbojpeg.jar
      -Djava.library.path=${CMAKE_CURRENT_BINARY_DIR}/${OBJDIR}
      TJUnitTest -bi -yuv)
  add_test(TJUnitTest-bi-yuv-nopad
    ${Java_JAVA_EXECUTABLE} ${JAVAARGS} -cp java/turbojpeg.jar
      -Djava.library.path=${CMAKE_CURRENT_BINARY_DIR}/${OBJDIR}
      TJUnitTest -bi -yuv -noyuvpad)
endif()

set(TEST_LIBTYPES "")
if(ENABLE_SHARED)
  set(TEST_LIBTYPES ${TEST_LIBTYPES} shared)
endif()
if(ENABLE_STATIC)
  set(TEST_LIBTYPES ${TEST_LIBTYPES} static)
endif()

set(TESTIMAGES ${CMAKE_CURRENT_SOURCE_DIR}/testimages)
set(MD5CMP ${CMAKE_CURRENT_BINARY_DIR}/md5/md5cmp)
if(CMAKE_CROSSCOMPILING)
  file(RELATIVE_PATH TESTIMAGES ${CMAKE_CURRENT_BINARY_DIR} ${TESTIMAGES})
  file(RELATIVE_PATH MD5CMP ${CMAKE_CURRENT_BINARY_DIR} ${MD5CMP})
endif()

# The output of the floating point DCT/IDCT algorithms differs depending on the
# type of floating point math used, so the FLOATTEST CMake variable must be
# set in order to tell the testing system which floating point results it
# should expect:
#
# sse = validate against the expected results from the libjpeg-turbo SSE SIMD
#       extensions
# no-fp-contract = validate against the expected results from the C code when
#                  floating point expression contraction is disabled (the
#                  default with Clang, with GCC when building for platforms
#                  that lack fused multiply-add [FMA] instructions, or when
#                  passing -ffp-contract=off to the compiler)
# fp-contract = validate against the expected results from the C code when
#               floating point expression contraction is enabled (the default
#               with GCC when building for platforms that have fused multiply-
#               add [FMA] instructions or when passing -ffp-contract=fast to
#               the compiler)
# 387 = validate against the expected results from the C code when the 387 FPU
#       is being used for floating point math (which is generally the default
#       with x86 compilers)
# msvc = validate against the expected results from the C code when compiled
#        with a 32-bit version of Visual C++

if(CPU_TYPE STREQUAL "x86_64" OR CPU_TYPE STREQUAL "i386")
  if(WITH_SIMD)
    set(DEFAULT_FLOATTEST sse)
  elseif(CPU_TYPE STREQUAL "x86_64")
    set(DEFAULT_FLOATTEST no-fp-contract)
  # else we can't really set an intelligent default for i386.  The appropriate
  # value could be no-fp-contract, fp-contract, 387, or msvc, depending on the
  # compiler and compiler options.  We leave it to the user to set FLOATTEST
  # manually.
  endif()
else()
  if((CPU_TYPE STREQUAL "powerpc" OR CPU_TYPE STREQUAL "arm64") AND
    NOT CMAKE_C_COMPILER_ID STREQUAL "Clang" AND NOT MSVC)
    set(DEFAULT_FLOATTEST fp-contract)
  else()
    set(DEFAULT_FLOATTEST no-fp-contract)
  endif()
endif()

# This causes FLOATTEST to reset to the default value if WITH_SIMD has
# changed.
if(DEFINED WITH_SIMD_INT AND NOT WITH_SIMD EQUAL WITH_SIMD_INT)
  set(FORCE_FLOATTEST "FORCE")
endif()
set(WITH_SIMD_INT ${WITH_SIMD} CACHE INTERNAL "")
set(FLOATTEST ${DEFAULT_FLOATTEST} CACHE STRING
  "The type of floating point math used by the floating point DCT/IDCT algorithms.  This tells the testing system which numerical results it should expect from those tests.  [sse = libjpeg-turbo x86/x86-64 SIMD extensions, no-fp-contract = generic FPU with floating point expression contraction disabled, fp-contract = generic FPU with floating point expression contraction enabled, 387 = 387 FPU, msvc = 32-bit Visual Studio] (default = ${DEFAULT_FLOATTEST})"
  ${FORCE_FLOATTEST})
message(STATUS "FLOATTEST = ${FLOATTEST}")

if(FLOATTEST)
  string(TOUPPER ${FLOATTEST} FLOATTEST_UC)
  string(REGEX REPLACE "-" "_" FLOATTEST_UC ${FLOATTEST_UC})
  string(TOLOWER ${FLOATTEST} FLOATTEST)
  if(NOT FLOATTEST STREQUAL "sse" AND
    NOT FLOATTEST STREQUAL "no-fp-contract" AND
    NOT FLOATTEST STREQUAL "fp-contract" AND NOT FLOATTEST STREQUAL "387" AND
    NOT FLOATTEST STREQUAL "msvc")
    message(FATAL_ERROR "\"${FLOATTEST}\" is not a valid value for FLOATTEST.")
  endif()
endif()

foreach(libtype ${TEST_LIBTYPES})
  if(libtype STREQUAL "static")
    set(suffix -static)
  endif()
  if(WITH_TURBOJPEG)
    add_test(tjunittest-${libtype}
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjunittest${suffix})
    add_test(tjunittest-${libtype}-alloc
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjunittest${suffix} -alloc)
    add_test(tjunittest-${libtype}-yuv
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjunittest${suffix} -yuv)
    add_test(tjunittest-${libtype}-yuv-alloc
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjunittest${suffix} -yuv -alloc)
    add_test(tjunittest-${libtype}-yuv-nopad
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjunittest${suffix} -yuv -noyuvpad)
    add_test(tjunittest-${libtype}-bmp
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjunittest${suffix} -bmp)

    set(MD5_PPM_GRAY_TILE b8f5defbd8e76a1d557b860b457bcd05)
    set(MD5_PPM_420_8x8_TILE cb8bb3f7de153b4cfbf6cc6f36b43bf0)
    set(MD5_PPM_420_16x16_TILE a144f52396cba331bb85c6b43d1deedc)
    set(MD5_PPM_420_32x32_TILE 5d6a7c35bb44adc89581466b253ef920)
    set(MD5_PPM_420_64x64_TILE 4e4c1a3d7ea4bace4f868bcbe83b7050)
    set(MD5_PPM_420_128x128_TILE d8b12baac07d24d9705d712359ae2181)
    set(MD5_PPM_420M_8x8_TILE bc25320e1f4c31ce2e610e43e9fd173c)
    set(MD5_PPM_420M_TILE 391df0063a66d7656f18f3a5cb107357)
    set(MD5_PPM_422_8x8_TILE d83dacd9fc73b0a6f10c09acad64eb1e)
    set(MD5_PPM_422_16x16_TILE 35077fb610d72dd743b1eb0cbcfe10fb)
    set(MD5_PPM_422_32x32_TILE 06a45b730ffa26990af4930140c3233b)
    set(MD5_PPM_422_64x64_TILE 007d991538e571e6e56c54b6224b060a)
    set(MD5_PPM_422_128x128_TILE f0b5617d578f5e13c8eee215d64d4877)
    set(MD5_PPM_422M_8x8_TILE 828941d7f41cd6283abd6beffb7fd51d)
    set(MD5_PPM_422M_TILE df4b4c784feb513d250c2dd76d61fa1a)
    set(MD5_PPM_444_TILE c757cfea44ac6439fea03ef57d04b7de)

    # Test compressing from/decompressing to an arbitrary subregion of a larger
    # image buffer
    add_test(tjbench-${libtype}-tile-cp
      ${CMAKE_COMMAND} -E copy_if_different ${TESTIMAGES}/testorig.ppm
        testout_tile.ppm)
    add_test(tjbench-${libtype}-tile
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjbench${suffix} testout_tile.ppm 95
        -rgb -quiet -tile -benchtime 0.01 -warmup 0)
    set_tests_properties(tjbench-${libtype}-tile
      PROPERTIES DEPENDS tjbench-${libtype}-tile-cp)

    add_test(tjbench-${libtype}-tilem-cp
      ${CMAKE_COMMAND} -E copy_if_different ${TESTIMAGES}/testorig.ppm
        testout_tilem.ppm)
    add_test(tjbench-${libtype}-tilem
      ${CMAKE_CROSSCOMPILING_EMULATOR} tjbench${suffix} testout_tilem.ppm 95
        -rgb -fastupsample -quiet -tile -benchtime 0.01 -warmup 0)
    set_tests_properties(tjbench-${libtype}-tilem
      PROPERTIES DEPENDS tjbench-${libtype}-tilem-cp)
  endif()

  # These tests are carefully crafted to provide full coverage of as many of
  # the underlying algorithms as possible (including all of the
  # SIMD-accelerated ones.)

  macro(add_bittest PROG NAME ARGS OUTFILE INFILE MD5SUM)
    add_test(${PROG}-${libtype}-${NAME}
      ${CMAKE_CROSSCOMPILING_EMULATOR} ${PROG}${suffix} ${ARGS}
        -outfile ${OUTFILE} ${INFILE})
    add_test(${PROG}-${libtype}-${NAME}-cmp
      ${CMAKE_CROSSCOMPILING_EMULATOR} ${MD5CMP} ${MD5SUM} ${OUTFILE})
    set_tests_properties(${PROG}-${libtype}-${NAME}-cmp PROPERTIES
      DEPENDS ${PROG}-${libtype}-${NAME})
    if(${ARGC} GREATER 6)
      set(DEPENDS ${ARGN})
      set_tests_properties(${PROG}-${libtype}-${NAME} PROPERTIES
        DEPENDS ${DEPENDS})
    endif()
  endmacro()

  # CC: null  SAMP: fullsize  FDCT: islow  ENT: huff
  add_bittest(cjpeg rgb-islow "-revert;-rgb;-dct;int;-icc;${TESTIMAGES}/test1.icc"
    testout_rgb_islow.jpg ${TESTIMAGES}/testorig.ppm
    ${MD5_JPEG_RGB_ISLOW})

  # CC: null  SAMP: fullsize  IDCT: islow  ENT: huff
  add_bittest(djpeg rgb-islow "-dct;int;-ppm;-icc;testout_rgb_islow.icc"
    testout_rgb_islow.ppm testout_rgb_islow.jpg
    ${MD5_PPM_RGB_ISLOW} cjpeg-${libtype}-rgb-islow)

  add_test(djpeg-${libtype}-rgb-islow-icc-cmp
    ${CMAKE_CROSSCOMPILING_EMULATOR} ${MD5CMP}
      b06a39d730129122e85c1363ed1bbc9e testout_rgb_islow.icc)
  set_tests_properties(djpeg-${libtype}-rgb-islow-icc-cmp PROPERTIES
    DEPENDS djpeg-${libtype}-rgb-islow)

  add_bittest(jpegtran icc "-revert;-copy;all;-icc;${TESTIMAGES}/test2.icc"
    testout_rgb_islow2.jpg testout_rgb_islow.jpg
    ${MD5_JPEG_RGB_ISLOW2} cjpeg-${libtype}-rgb-islow)

  if(NOT WITH_12BIT)
    # CC: RGB->RGB565  SAMP: fullsize  IDCT: islow  ENT: huff
    add_bittest(djpeg rgb-islow-565 "-dct;int;-rgb565;-dither;none;-bmp"
      testout_rgb_islow_565.bmp testout_rgb_islow.jpg
      ${MD5_BMP_RGB_ISLOW_565} cjpeg-${libtype}-rgb-islow)

    # CC: RGB->RGB565 (dithered)  SAMP: fullsize  IDCT: islow  ENT: huff
    add_bittest(djpeg rgb-islow-565D "-dct;int;-rgb565;-bmp"
      testout_rgb_islow_565D.bmp testout_rgb_islow.jpg
      ${MD5_BMP_RGB_ISLOW_565D} cjpeg-${libtype}-rgb-islow)
  endif()

  # CC: RGB->YCC  SAMP: fullsize/h2v1  FDCT: ifast  ENT: 2-pass huff
  add_bittest(cjpeg 422-ifast-opt "-revert;-sample;2x1;-dct;fast;-opt"
    testout_422_ifast_opt.jpg ${TESTIMAGES}/testorig.ppm
    ${MD5_JPEG_422_IFAST_OPT})

  # CC: YCC->RGB  SAMP: fullsize/h2v1 fancy  IDCT: ifast  ENT: huff
  add_bittest(djpeg 422-ifast "-dct;fast"
    testout_422_ifast.ppm testout_422_ifast_opt.jpg
    ${MD5_PPM_422_IFAST} cjpeg-${libtype}-422-ifast-opt)

  # CC: RGB->YCC  SAMP: fullsize/h1v2  FDCT: islow  ENT: huff
  add_bittest(cjpeg 440-islow "-sample;1x2;-dct;int"
    testout_440_islow.jpg ${TESTIMAGES}/testorig.ppm
    ${MD5_JPEG_440_ISLOW})

  # CC: YCC->RGB  SAMP: fullsize/h1v2 fancy  IDCT: islow  ENT: huff
  add_bittest(djpeg 440-islow "-dct;int"
    testout_440_islow.ppm testout_440_islow.jpg
    ${MD5_PPM_440_ISLOW} cjpeg-${libtype}-440-islow)

  # CC: YCC->RGB  SAMP: h2v1 merged  IDCT: ifast  ENT: huff
  add_bittest(djpeg 422m-ifast "-dct;fast;-nosmooth"
    testout_422m_ifast.ppm testout_422_ifast_opt.jpg
    ${MD5_PPM_422M_IFAST} cjpeg-${libtype}-422-ifast-opt)

  if(NOT WITH_12BIT)
    # CC: YCC->RGB565  SAMP: h2v1 merged  IDCT: ifast  ENT: huff
    add_bittest(djpeg 422m-ifast-565
      "-dct;int;-nosmooth;-rgb565;-dither;none;-bmp"
      testout_422m_ifast_565.bmp testout_422_ifast_opt.jpg
      ${MD5_BMP_422M_IFAST_565} cjpeg-${libtype}-422-ifast-opt)

    # CC: YCC->RGB565 (dithered)  SAMP: h2v1 merged  IDCT: ifast  ENT: huff
    add_bittest(djpeg 422m-ifast-565D "-dct;int;-nosmooth;-rgb565;-bmp"
      testout_422m_ifast_565D.bmp testout_422_ifast_opt.jpg
      ${MD5_BMP_422M_IFAST_565D} cjpeg-${libtype}-422-ifast-opt)
  endif()

  # CC: RGB->YCC  SAMP: fullsize/h2v2  FDCT: ifast  ENT: prog huff
  add_bittest(cjpeg 420-q100-ifast-prog
    "-revert;-sample;2x2;-quality;100;-dct;fast;-scans;${TESTIMAGES}/test.scan"
    testout_420_q100_ifast_prog.jpg ${TESTIMAGES}/testorig.ppm
    ${MD5_JPEG_420_IFAST_Q100_PROG})

  # CC: YCC->RGB  SAMP: fullsize/h2v2 fancy  IDCT: ifast  ENT: prog huff
  add_bittest(djpeg 420-q100-ifast-prog "-dct;fast"
    testout_420_q100_ifast.ppm testout_420_q100_ifast_prog.jpg
    ${MD5_PPM_420_Q100_IFAST} cjpeg-${libtype}-420-q100-ifast-prog)

  # CC: YCC->RGB  SAMP: h2v2 merged  IDCT: ifast  ENT: prog huff
  add_bittest(djpeg 420m-q100-ifast-prog "-dct;fast;-nosmooth"
    testout_420m_q100_ifast.ppm testout_420_q100_ifast_prog.jpg
    ${MD5_PPM_420M_Q100_IFAST} cjpeg-${libtype}-420-q100-ifast-prog)

  # CC: RGB->Gray  SAMP: fullsize  FDCT: islow  ENT: huff
  add_bittest(cjpeg gray-islow "-revert;-gray;-dct;int"
    testout_gray_islow.jpg ${TESTIMAGES}/testorig.ppm
    ${MD5_JPEG_GRAY_ISLOW})

  # CC: Gray->Gray  SAMP: fullsize  IDCT: islow  ENT: huff
  add_bittest(djpeg gray-islow "-dct;int"
    testout_gray_islow.ppm testout_gray_islow.jpg
    ${MD5_PPM_GRAY_ISLOW} cjpeg-${libtype}-gray-islow)

  # CC: Gray->RGB  SAMP: fullsize  IDCT: islow  ENT: huff
  add_bittest(djpeg gray-islow-rgb "-dct;int;-rgb"
    testout_gray_islow_rgb.ppm testout_gray_islow.jpg
    ${MD5_PPM_GRAY_ISLOW_RGB} cjpeg-${libtype}-gray-islow)

  if(NOT WITH_12BIT)
    # CC: Gray->RGB565  SAMP: fullsize  IDCT: islow  ENT: huff
    add_bittest(djpeg gray-islow-565 "-dct;int;-rgb565;-dither;none;-bmp"
      testout_gray_islow_565.bmp testout_gray_islow.jpg
      ${MD5_BMP_GRAY_ISLOW_565} cjpeg-${libtype}-gray-islow)

    # CC: Gray->RGB565 (dithered)  SAMP: fullsize  IDCT: islow  ENT: huff
    add_bittest(djpeg gray-islow-565D "-dct;int;-rgb565;-bmp"
      testout_gray_islow_565D.bmp testout_gray_islow.jpg
      ${MD5_BMP_GRAY_ISLOW_565D} cjpeg-${libtype}-gray-islow)
  endif()

  # CC: RGB->YCC  SAMP: fullsize smooth/h2v2 smooth  FDCT: islow
  # ENT: 2-pass huff
  add_bittest(cjpeg 420s-ifast-opt "-revert;-sample;2x2;-smooth;1;-dct;int;-opt"
    testout_420s_ifast_opt.jpg ${TESTIMAGES}/testorig.ppm
    ${MD5_JPEG_420S_IFAST_OPT})

  if(FLOATTEST)
    # CC: RGB->YCC  SAMP: fullsize/int  FDCT: float  ENT: prog huff
    add_bittest(cjpeg 3x2-float-prog "-revert;-sample;3x2;-dct;float;-prog"
      testout_3x2_float_prog.jpg ${TESTIMAGES}/testorig.ppm
      ${MD5_JPEG_3x2_FLOAT_PROG_${FLOATTEST_UC}})

    # CC: YCC->RGB  SAMP: fullsize/int  IDCT: float  ENT: prog huff
    add_bittest(djpeg 3x2-float-prog "-dct;float"
      testout_3x2_float.ppm testout_3x2_float_prog.jpg
      ${MD5_PPM_3x2_FLOAT_${FLOATTEST_UC}} cjpeg-${libtype}-3x2-float-prog)
  endif()

    # CC: RGB->YCC  SAMP: fullsize/int  FDCT: ifast  ENT: prog huff
  add_bittest(cjpeg 3x2-ifast-prog "-revert;-sample;3x2;-dct;fast;-prog"
    testout_3x2_ifast_prog.jpg ${TESTIMAGES}/testorig.ppm
    ${MD5_JPEG_3x2_IFAST_PROG})

  # CC: YCC->RGB  SAMP: fullsize/int  IDCT: ifast  ENT: prog huff
  add_bittest(djpeg 3x2-ifast-prog "-dct;fast"
    testout_3x2_ifast.ppm testout_3x2_ifast_prog.jpg
    ${MD5_PPM_3x2_IFAST} cjpeg-${libtype}-3x2-ifast-prog)

  if(WITH_ARITH_ENC)
    # CC: YCC->RGB  SAMP: fullsize/h2v2  FDCT: islow  ENT: arith
    add_bittest(cjpeg 420-islow-ari "-revert;-dct;int;-arithmetic"
      testout_420_islow_ari.jpg ${TESTIMAGES}/testorig.ppm
      ${MD5_JPEG_420_ISLOW_ARI})

    add_bittest(jpegtran 420-islow-ari "-revert;-arithmetic"
      testout_420_islow_ari2.jpg ${TESTIMAGES}/testimgint.jpg
      ${MD5_JPEG_420_ISLOW_ARI})

    # CC: YCC->RGB  SAMP: fullsize  FDCT: islow  ENT: prog arith
    add_bittest(cjpeg 444-islow-progari
      "-revert;-sample;1x1;-dct;int;-prog;-arithmetic"
      testout_444_islow_progari.jpg ${TESTIMAGES}/testorig.ppm
      ${MD5_JPEG_444_ISLOW_PROGARI})
  endif()

  if(WITH_ARITH_DEC)
    # CC: RGB->YCC  SAMP: h2v2 merged  IDCT: ifast  ENT: arith
    add_bittest(djpeg 420m-ifast-ari "-fast;-skip;1,20;-ppm"
      testout_420m_ifast_ari.ppm ${TESTIMAGES}/testimgari.jpg
      ${MD5_PPM_420M_IFAST_ARI})

    add_bittest(jpegtran 420-islow "-revert"
      testout_420_islow.jpg ${TESTIMAGES}/testimgari.jpg
      ${MD5_JPEG_420_ISLOW})
  endif()

  # 2/1--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 16x16 islow  ENT: huff
  # 15/8--  CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 15x15 islow  ENT: huff
  # 13/8--  CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 13x13 islow  ENT: huff
  # 11/8--  CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 11x11 islow  ENT: huff
  # 9/8--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 9x9 islow  ENT: huff
  # 7/8--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 7x7 islow/14x14 islow
  #         ENT: huff
  # 3/4--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 6x6 islow/12x12 islow
  #         ENT: huff
  # 5/8--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 5x5 islow/10x10 islow
  #         ENT: huff
  # 1/2--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 4x4 islow/8x8 islow
  #         ENT: huff
  # 3/8--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 3x3 islow/6x6 islow
  #         ENT: huff
  # 1/4--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 2x2 islow/4x4 islow
  #         ENT: huff
  # 1/8--   CC: YCC->RGB  SAMP: h2v2 merged  IDCT: 1x1 islow/2x2 islow
  #         ENT: huff
  foreach(scale 2_1 15_8 13_8 11_8 9_8 7_8 3_4 5_8 1_2 3_8 1_4 1_8)
    string(REGEX REPLACE "_" "/" scalearg ${scale})
    add_bittest(djpeg 420m-islow-${scale}
      "-dct;int;-scale;${scalearg};-nosmooth;-ppm"
      testout_420m_islow_${scale}.ppm ${TESTIMAGES}/${TESTORIG}
      ${MD5_PPM_420M_ISLOW_${scale}})
  endforeach()

  if(NOT WITH_12BIT)
    # CC: YCC->RGB (dithered)  SAMP: h2v2 fancy  IDCT: islow  ENT: huff
    add_bittest(djpeg 420-islow-256 "-dct;int;-colors;256;-bmp"
      testout_420_islow_256.bmp ${TESTIMAGES}/${TESTORIG}
      ${MD5_BMP_420_ISLOW_256})

    # CC: YCC->RGB565  SAMP: h2v2 fancy  IDCT: islow  ENT: huff
    add_bittest(djpeg 420-islow-565 "-dct;int;-rgb565;-dither;none;-bmp"
      testout_420_islow_565.bmp ${TESTIMAGES}/${TESTORIG}
      ${MD5_BMP_420_ISLOW_565})

    # CC: YCC->RGB565 (dithered)  SAMP: h2v2 fancy  IDCT: islow  ENT: huff
    add_bittest(djpeg 420-islow-565D "-dct;int;-rgb565;-bmp"
      testout_420_islow_565D.bmp ${TESTIMAGES}/${TESTORIG}
      ${MD5_BMP_420_ISLOW_565D})

    # CC: YCC->RGB565  SAMP: h2v2 merged  IDCT: islow  ENT: huff
    add_bittest(djpeg 420m-islow-565
      "-dct;int;-nosmooth;-rgb565;-dither;none;-bmp"
      testout_420m_islow_565.bmp ${TESTIMAGES}/${TESTORIG}
      ${MD5_BMP_420M_ISLOW_565})

    # CC: YCC->RGB565 (dithered)  SAMP: h2v2 merged  IDCT: islow  ENT: huff
    add_bittest(djpeg 420m-islow-565D "-dct;int;-nosmooth;-rgb565;-bmp"
      testout_420m_islow_565D.bmp ${TESTIMAGES}/${TESTORIG}
      ${MD5_BMP_420M_ISLOW_565D})
  endif()

  # Partial decode tests.  These tests are designed to cover all of the
  # possible code paths in jpeg_skip_scanlines().

  # Context rows: Yes  Intra-iMCU row: Yes  iMCU row prefetch: No   ENT: huff
  add_bittest(djpeg 420-islow-skip15_31 "-dct;int;-skip;15,31;-ppm"
    testout_420_islow_skip15,31.ppm ${TESTIMAGES}/${TESTORIG}
    ${MD5_PPM_420_ISLOW_SKIP15_31})

  # Context rows: Yes  Intra-iMCU row: No   iMCU row prefetch: Yes  ENT: arith
  if(WITH_ARITH_DEC)
    add_bittest(djpeg 420-islow-ari-skip16_139 "-dct;int;-skip;16,139;-ppm"
      testout_420_islow_ari_skip16,139.ppm ${TESTIMAGES}/testimgari.jpg
      ${MD5_PPM_420_ISLOW_ARI_SKIP16_139})
  endif()

  # Context rows: Yes  Intra-iMCU row: No   iMCU row prefetch: No   ENT: prog huff
  add_test(cjpeg-${libtype}-420-islow-prog
    ${CMAKE_CROSSCOMPILING_EMULATOR} cjpeg${suffix} -dct int -prog
      -outfile testout_420_islow_prog.jpg ${TESTIMAGES}/testorig.ppm)
  add_bittest(djpeg 420-islow-prog-crop62x62_71_71
    "-dct;int;-crop;62x62+71+71;-ppm"
    testout_420_islow_prog_crop62x62,71,71.ppm testout_420_islow_prog.jpg
    ${MD5_PPM_420_ISLOW_PROG_CROP62x62_71_71} cjpeg-${libtype}-420-islow-prog)

  # Context rows: Yes  Intra-iMCU row: No   iMCU row prefetch: No   ENT: arith
  if(WITH_ARITH_DEC)
    add_bittest(djpeg 420-islow-ari-crop53x53_4_4
      "-dct;int;-crop;53x53+4+4;-ppm"
      testout_420_islow_ari_crop53x53,4,4.ppm ${TESTIMAGES}/testimgari.jpg
      ${MD5_PPM_420_ISLOW_ARI_CROP53x53_4_4})
  endif()

  # Context rows: No   Intra-iMCU row: Yes  ENT: huff
  add_test(cjpeg-${libtype}-444-islow
    ${CMAKE_CROSSCOMPILING_EMULATOR} cjpeg${suffix} -dct int -sample 1x1
      -outfile testout_444_islow.jpg ${TESTIMAGES}/testorig.ppm)
  add_bittest(djpeg 444-islow-skip1_6 "-dct;int;-skip;1,6;-ppm"
    testout_444_islow_skip1,6.ppm testout_444_islow.jpg
    ${MD5_PPM_444_ISLOW_SKIP1_6} cjpeg-${libtype}-444-islow)

  # Context rows: No   Intra-iMCU row: No   ENT: prog huff
  add_test(cjpeg-${libtype}-444-islow-prog
    ${CMAKE_CROSSCOMPILING_EMULATOR} cjpeg${suffix} -dct int -prog -sample 1x1
      -outfile testout_444_islow_prog.jpg ${TESTIMAGES}/testorig.ppm)
  add_bittest(djpeg 444-islow-prog-crop98x98_13_13
    "-dct;int;-crop;98x98+13+13;-ppm"
    testout_444_islow_prog_crop98x98,13,13.ppm testout_444_islow_prog.jpg
    ${MD5_PPM_444_ISLOW_PROG_CROP98x98_13_13} cjpeg-${libtype}-444-islow-prog)

  # Context rows: No   Intra-iMCU row: No   ENT: arith
  if(WITH_ARITH_ENC)
    add_test(cjpeg-${libtype}-444-islow-ari
      ${CMAKE_CROSSCOMPILING_EMULATOR} cjpeg${suffix} -dct int -arithmetic
        -sample 1x1 -outfile testout_444_islow_ari.jpg
        ${TESTIMAGES}/testorig.ppm)
    if(WITH_ARITH_DEC)
      add_bittest(djpeg 444-islow-ari-crop37x37_0_0
        "-dct;int;-crop;37x37+0+0;-ppm"
        testout_444_islow_ari_crop37x37,0,0.ppm testout_444_islow_ari.jpg
        ${MD5_PPM_444_ISLOW_ARI_CROP37x37_0_0} cjpeg-${libtype}-444-islow-ari)
    endif()
  endif()

  add_bittest(jpegtran crop "-revert;-crop;120x90+20+50;-transpose;-perfect"
    testout_crop.jpg ${TESTIMAGES}/${TESTORIG}
    ${MD5_JPEG_CROP})

endforeach()

add_custom_target(testclean COMMAND ${CMAKE_COMMAND} -P
  ${CMAKE_CURRENT_SOURCE_DIR}/cmakescripts/testclean.cmake)

configure_file(croptest.in croptest @ONLY)
add_custom_target(croptest
  COMMAND echo croptest
  COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/croptest)

if(WITH_TURBOJPEG)
  configure_file(tjbenchtest.in tjbenchtest @ONLY)
  configure_file(tjexampletest.in tjexampletest @ONLY)
  if(WIN32)
    set(BASH bash)
  endif()
  if(WITH_JAVA)
    configure_file(tjbenchtest.java.in tjbenchtest.java @ONLY)
    configure_file(tjexampletest.java.in tjexampletest.java @ONLY)
    add_custom_target(tjtest
      COMMAND echo tjbenchtest
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest
      COMMAND echo tjbenchtest -alloc
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -alloc
      COMMAND echo tjbenchtest -yuv
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -yuv
      COMMAND echo tjbenchtest -yuv -alloc
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -yuv -alloc
      COMMAND echo tjbenchtest -progressive
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -progressive
      COMMAND echo tjbenchtest -progressive -yuv
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -progressive -yuv
      COMMAND echo tjexampletest
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjexampletest
      COMMAND echo tjbenchtest.java
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest.java
      COMMAND echo tjbenchtest.java -yuv
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest.java -yuv
      COMMAND echo tjbenchtest.java -progressive
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest.java -progressive
      COMMAND echo tjbenchtest.java -progressive -yuv
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest.java
        -progressive -yuv
      COMMAND echo tjexampletest.java
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjexampletest.java
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest
        ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest.java
        ${CMAKE_CURRENT_BINARY_DIR}/tjexampletest
        ${CMAKE_CURRENT_BINARY_DIR}/tjexampletest.java)
  else()
    add_custom_target(tjtest
      COMMAND echo tjbenchtest
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest
      COMMAND echo tjbenchtest -alloc
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -alloc
      COMMAND echo tjbenchtest -yuv
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -yuv
      COMMAND echo tjbenchtest -yuv -alloc
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -yuv -alloc
      COMMAND echo tjbenchtest -progressive
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -progressive
      COMMAND echo tjbenchtest -progressive -yuv
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest -progressive -yuv
      COMMAND echo tjexampletest
      COMMAND ${BASH} ${CMAKE_CURRENT_BINARY_DIR}/tjexampletest
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/tjbenchtest
        ${CMAKE_CURRENT_BINARY_DIR}/tjexampletest)
  endif()
endif()


###############################################################################
# INSTALLATION
###############################################################################

set(EXE ${CMAKE_EXECUTABLE_SUFFIX})

if(WITH_TURBOJPEG)
  if(ENABLE_SHARED)
    install(TARGETS turbojpeg EXPORT ${CMAKE_PROJECT_NAME}Targets
      INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
      LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(TARGETS tjbench
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    if(NOT CMAKE_VERSION VERSION_LESS "3.1" AND MSVC AND
      CMAKE_C_LINKER_SUPPORTS_PDB)
      install(FILES "$<TARGET_PDB_FILE:turbojpeg>"
        DESTINATION ${CMAKE_INSTALL_BINDIR} OPTIONAL)
    endif()
  endif()
  if(ENABLE_STATIC)
    install(TARGETS turbojpeg-static EXPORT ${CMAKE_PROJECT_NAME}Targets
      INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
    if(NOT ENABLE_SHARED)
      if(GENERATOR_IS_MULTI_CONFIG)
        set(DIR "${CMAKE_CURRENT_BINARY_DIR}/\${CMAKE_INSTALL_CONFIG_NAME}")
      else()
        set(DIR ${CMAKE_CURRENT_BINARY_DIR})
      endif()
      install(PROGRAMS ${DIR}/tjbench-static${EXE}
        DESTINATION ${CMAKE_INSTALL_BINDIR} RENAME tjbench${EXE})
    endif()
  endif()
  install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/turbojpeg.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
endif()

if(ENABLE_STATIC)
  install(TARGETS jpeg-static EXPORT ${CMAKE_PROJECT_NAME}Targets
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
  if(NOT ENABLE_SHARED)
    if(GENERATOR_IS_MULTI_CONFIG)
      set(DIR "${CMAKE_CURRENT_BINARY_DIR}/\${CMAKE_INSTALL_CONFIG_NAME}")
    else()
      set(DIR ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    install(PROGRAMS ${DIR}/cjpeg-static${EXE}
      DESTINATION ${CMAKE_INSTALL_BINDIR} RENAME cjpeg${EXE})
    install(PROGRAMS ${DIR}/djpeg-static${EXE}
      DESTINATION ${CMAKE_INSTALL_BINDIR} RENAME djpeg${EXE})
    install(PROGRAMS ${DIR}/jpegtran-static${EXE}
      DESTINATION ${CMAKE_INSTALL_BINDIR} RENAME jpegtran${EXE})
  endif()
endif()

install(TARGETS rdjpgcom wrjpgcom RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/README.ijg
  ${CMAKE_CURRENT_SOURCE_DIR}/README.md ${CMAKE_CURRENT_SOURCE_DIR}/example.txt
  ${CMAKE_CURRENT_SOURCE_DIR}/tjexample.c
  ${CMAKE_CURRENT_SOURCE_DIR}/libjpeg.txt
  ${CMAKE_CURRENT_SOURCE_DIR}/structure.txt
  ${CMAKE_CURRENT_SOURCE_DIR}/usage.txt ${CMAKE_CURRENT_SOURCE_DIR}/wizard.txt
  ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.md DESTINATION ${CMAKE_INSTALL_DOCDIR})
if(WITH_JAVA)
  install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/java/TJExample.java
    DESTINATION ${CMAKE_INSTALL_DOCDIR})
endif()

if(UNIX OR MINGW)
  install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cjpeg.1
    ${CMAKE_CURRENT_SOURCE_DIR}/djpeg.1 ${CMAKE_CURRENT_SOURCE_DIR}/jpegtran.1
    ${CMAKE_CURRENT_SOURCE_DIR}/rdjpgcom.1
    ${CMAKE_CURRENT_SOURCE_DIR}/wrjpgcom.1
    DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)
endif()
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/pkgscripts/libjpeg.pc
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
if(WITH_TURBOJPEG)
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/pkgscripts/libturbojpeg.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
endif()
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/pkgscripts/${CMAKE_PROJECT_NAME}Config.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/pkgscripts/${CMAKE_PROJECT_NAME}ConfigVersion.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${CMAKE_PROJECT_NAME})
install(EXPORT ${CMAKE_PROJECT_NAME}Targets
  NAMESPACE ${CMAKE_PROJECT_NAME}::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${CMAKE_PROJECT_NAME})

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/jconfig.h
  ${CMAKE_CURRENT_SOURCE_DIR}/jerror.h ${CMAKE_CURRENT_SOURCE_DIR}/jmorecfg.h
  ${CMAKE_CURRENT_SOURCE_DIR}/jpeglib.h
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

include(cmakescripts/BuildPackages.cmake)

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmakescripts/cmake_uninstall.cmake.in"
  "cmake_uninstall.cmake" IMMEDIATE @ONLY)

add_custom_target(uninstall COMMAND ${CMAKE_COMMAND} -P cmake_uninstall.cmake)
