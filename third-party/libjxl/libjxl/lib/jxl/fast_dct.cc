// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/fast_dct.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/base/random.h"
#include "lib/jxl/dct-inl.h"
#include "lib/jxl/fast_dct-inl.h"
HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {
namespace {
void BenchmarkFloatIDCT32x32() { TestFloatIDCT<32, 32>(); }
void BenchmarkFastIDCT32x32() { TestFastIDCT<32, 32>(); }
}  // namespace
// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {
HWY_EXPORT(BenchmarkFloatIDCT32x32);
HWY_EXPORT(BenchmarkFastIDCT32x32);
void BenchmarkFloatIDCT32x32() {
  HWY_DYNAMIC_DISPATCH(BenchmarkFloatIDCT32x32)();
}
void BenchmarkFastIDCT32x32() {
  HWY_DYNAMIC_DISPATCH(BenchmarkFastIDCT32x32)();
}
}  // namespace jxl
#endif
