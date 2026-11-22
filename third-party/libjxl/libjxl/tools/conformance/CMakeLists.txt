# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

if(BUILD_TESTING AND CMAKE_EXECUTABLE_SUFFIX STREQUAL "")
# Script to validate the tooling.
find_program (BASH_PROGRAM bash)
if(BASH_PROGRAM)
  add_test(
    NAME conformance_tooling_test
    COMMAND
        ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/tooling_test.sh
        ${CMAKE_BINARY_DIR} ${JPEGXL_TEST_DATA_PATH})
  # Skip the test if dependencies are not available.
  set_tests_properties(conformance_tooling_test PROPERTIES SKIP_RETURN_CODE 254)
endif()
endif() # BUILD_TESTING
