# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# git_version.cmake is a script which creates tools_version_git.h in the build
# directory if building from a git repository.
find_package(Git QUIET)

# Check that this script was invoked with the necessary arguments.
if(NOT IS_DIRECTORY "${JPEGXL_ROOT_DIR}")
  message(FATAL_ERROR "JPEGXL_ROOT_DIR is invalid")
endif()

execute_process(
  COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
  OUTPUT_VARIABLE GIT_REV
  WORKING_DIRECTORY "${JPEGXL_ROOT_DIR}"
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET)

# The define line in the file.
set(JPEGXL_VERSION_DEFINE "#define JPEGXL_VERSION \"${GIT_REV}\"\n")

# Update the header file only if needed.
if(EXISTS "${DST}")
  file(READ "${DST}" ORIG_DST)
  if(NOT ORIG_DST STREQUAL JPEGXL_VERSION_DEFINE)
    message(STATUS "Changing JPEGXL_VERSION to ${GIT_REV}")
    file(WRITE "${DST}" "${JPEGXL_VERSION_DEFINE}")
  endif()
else()
  file(WRITE "${DST}" "${JPEGXL_VERSION_DEFINE}")
endif()
