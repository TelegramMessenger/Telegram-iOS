// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_TYPES_H_
#define LIB_JPEGLI_TYPES_H_

#if defined(__cplusplus) || defined(c_plusplus)
extern "C" {
#endif

//
// New API structs and functions that are not available in libjpeg
//
// NOTE: This part of the API is still experimental and will probably change in
// the future.
//

typedef enum {
  JPEGLI_TYPE_FLOAT = 0,
  JPEGLI_TYPE_UINT8 = 2,
  JPEGLI_TYPE_UINT16 = 3,
} JpegliDataType;

typedef enum {
  JPEGLI_NATIVE_ENDIAN = 0,
  JPEGLI_LITTLE_ENDIAN = 1,
  JPEGLI_BIG_ENDIAN = 2,
} JpegliEndianness;

int jpegli_bytes_per_sample(JpegliDataType data_type);

#if defined(__cplusplus) || defined(c_plusplus)
}  // extern "C"
#endif

#endif  // LIB_JPEGLI_TYPES_H_
