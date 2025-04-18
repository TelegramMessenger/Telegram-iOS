// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_LIBJPEG_TEST_UTIL_H_
#define LIB_JPEGLI_LIBJPEG_TEST_UTIL_H_

#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jpegli/test_params.h"

namespace jpegli {

// Verifies that an image encoded with libjpegli can be decoded with libjpeg,
// and checks that the jpeg coding metadata matches jparams.
void DecodeAllScansWithLibjpeg(const CompressParams& jparams,
                               const DecompressParams& dparams,
                               const std::vector<uint8_t>& compressed,
                               std::vector<TestImage>* output_progression);
// Returns the number of bytes read from compressed.
size_t DecodeWithLibjpeg(const CompressParams& jparams,
                         const DecompressParams& dparams,
                         const uint8_t* table_stream, size_t table_stream_size,
                         const uint8_t* compressed, size_t len,
                         TestImage* output);
void DecodeWithLibjpeg(const CompressParams& jparams,
                       const DecompressParams& dparams,
                       const std::vector<uint8_t>& compressed,
                       TestImage* output);

}  // namespace jpegli

#endif  // LIB_JPEGLI_LIBJPEG_TEST_UTIL_H_
