// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/image_ops.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <utility>

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

template <typename T>
void TestPacked(const size_t xsize, const size_t ysize) {
  Plane<T> image1(xsize, ysize);
  RandomFillImage(&image1);
  const std::vector<T>& packed = PackedFromImage(image1);
  const Plane<T>& image2 = ImageFromPacked(packed, xsize, ysize);
  JXL_EXPECT_OK(SamePixels(image1, image2, _));
}

TEST(ImageTest, TestPacked) {
  TestPacked<uint8_t>(1, 1);
  TestPacked<uint8_t>(7, 1);
  TestPacked<uint8_t>(1, 7);

  TestPacked<int16_t>(1, 1);
  TestPacked<int16_t>(7, 1);
  TestPacked<int16_t>(1, 7);

  TestPacked<uint16_t>(1, 1);
  TestPacked<uint16_t>(7, 1);
  TestPacked<uint16_t>(1, 7);

  TestPacked<float>(1, 1);
  TestPacked<float>(7, 1);
  TestPacked<float>(1, 7);
}

// Ensure entire payload is readable/writable for various size/offset combos.
TEST(ImageTest, TestAllocator) {
  Rng rng(0);
  const size_t k32 = 32;
  const size_t kAlign = CacheAligned::kAlignment;
  for (size_t size : {k32 * 1, k32 * 2, k32 * 3, k32 * 4, k32 * 5,
                      CacheAligned::kAlias, 2 * CacheAligned::kAlias + 4}) {
    for (size_t offset = 0; offset <= CacheAligned::kAlias; offset += kAlign) {
      uint8_t* bytes =
          static_cast<uint8_t*>(CacheAligned::Allocate(size, offset));
      JXL_CHECK(reinterpret_cast<uintptr_t>(bytes) % kAlign == 0);
      // Ensure we can write/read the last byte. Use RNG to fool the compiler
      // into thinking the write is necessary.
      memset(bytes, 0, size);
      bytes[size - 1] = 1;                       // greatest element
      uint32_t pos = rng.UniformU(0, size - 1);  // random but != greatest
      JXL_CHECK(bytes[pos] < bytes[size - 1]);

      CacheAligned::Free(bytes);
    }
  }
}

template <typename T>
void TestFillImpl(Image3<T>* img, const char* layout) {
  FillImage(T(1), img);
  for (size_t y = 0; y < img->ysize(); ++y) {
    for (size_t c = 0; c < 3; ++c) {
      T* JXL_RESTRICT row = img->PlaneRow(c, y);
      for (size_t x = 0; x < img->xsize(); ++x) {
        if (row[x] != T(1)) {
          printf("Not 1 at c=%" PRIuS " %" PRIuS ", %" PRIuS " (%" PRIuS
                 " x %" PRIuS ") (%s)\n",
                 c, x, y, img->xsize(), img->ysize(), layout);
          abort();
        }
        row[x] = T(2);
      }
    }
  }

  // Same for ZeroFillImage and swapped c/y loop ordering.
  ZeroFillImage(img);
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < img->ysize(); ++y) {
      T* JXL_RESTRICT row = img->PlaneRow(c, y);
      for (size_t x = 0; x < img->xsize(); ++x) {
        if (row[x] != T(0)) {
          printf("Not 0 at c=%" PRIuS " %" PRIuS ", %" PRIuS " (%" PRIuS
                 " x %" PRIuS ") (%s)\n",
                 c, x, y, img->xsize(), img->ysize(), layout);
          abort();
        }
        row[x] = T(3);
      }
    }
  }
}

template <typename T>
void TestFillT() {
  for (uint32_t xsize : {0, 1, 15, 16, 31, 32}) {
    for (uint32_t ysize : {0, 1, 15, 16, 31, 32}) {
      Image3<T> image(xsize, ysize);
      TestFillImpl(&image, "size ctor");

      Image3<T> planar(Plane<T>(xsize, ysize), Plane<T>(xsize, ysize),
                       Plane<T>(xsize, ysize));
      TestFillImpl(&planar, "planar");
    }
  }
}

// Ensure y/c/x and c/y/x loops visit pixels no more than once.
TEST(ImageTest, TestFill) {
  TestFillT<uint8_t>();
  TestFillT<int16_t>();
  TestFillT<float>();
  TestFillT<double>();
}

TEST(ImageTest, CopyImageToWithPaddingTest) {
  Plane<uint32_t> src(100, 61);
  for (size_t y = 0; y < src.ysize(); y++) {
    for (size_t x = 0; x < src.xsize(); x++) {
      src.Row(y)[x] = x * 1000 + y;
    }
  }
  Rect src_rect(10, 20, 30, 40);
  EXPECT_TRUE(src_rect.IsInside(src));

  Plane<uint32_t> dst(60, 50);
  FillImage(0u, &dst);
  Rect dst_rect(20, 5, 30, 40);
  EXPECT_TRUE(dst_rect.IsInside(dst));

  CopyImageToWithPadding(src_rect, src, /*padding=*/2, dst_rect, &dst);

  // ysize is + 3 instead of + 4 because we are at the y image boundary on the
  // source image.
  Rect padded_dst_rect(20 - 2, 5 - 2, 30 + 4, 40 + 3);
  for (size_t y = 0; y < dst.ysize(); y++) {
    for (size_t x = 0; x < dst.xsize(); x++) {
      if (Rect(x, y, 1, 1).IsInside(padded_dst_rect)) {
        EXPECT_EQ((x - dst_rect.x0() + src_rect.x0()) * 1000 +
                      (y - dst_rect.y0() + src_rect.y0()),
                  dst.Row(y)[x]);
      } else {
        EXPECT_EQ(0u, dst.Row(y)[x]);
      }
    }
  }
}

}  // namespace
}  // namespace jxl
