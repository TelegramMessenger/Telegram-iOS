# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

add_executable(decode_oneshot ${CMAKE_CURRENT_LIST_DIR}/decode_oneshot.cc)
target_link_libraries(decode_oneshot jxl_dec jxl_threads)
add_executable(decode_progressive ${CMAKE_CURRENT_LIST_DIR}/decode_progressive.cc)
target_link_libraries(decode_progressive jxl_dec jxl_threads)
add_executable(encode_oneshot ${CMAKE_CURRENT_LIST_DIR}/encode_oneshot.cc)
target_link_libraries(encode_oneshot jxl jxl_threads)
