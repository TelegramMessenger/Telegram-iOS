// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/image.h"

#include <algorithm>  // swap

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/image.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/common.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/sanitizers.h"

HWY_BEFORE_NAMESPACE();
namespace jxl {

namespace HWY_NAMESPACE {
size_t GetVectorSize() { return HWY_LANES(uint8_t); }
// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE

}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {
namespace {

HWY_EXPORT(GetVectorSize);  // Local function.

// Returns distance [bytes] between the start of two consecutive rows, a
// multiple of vector/cache line size but NOT CacheAligned::kAlias - see below.
size_t BytesPerRow(const size_t xsize, const size_t sizeof_t) {
  const size_t vec_size = VectorSize();
  size_t valid_bytes = xsize * sizeof_t;

  // Allow unaligned accesses starting at the last valid value - this may raise
  // msan errors unless the user calls InitializePaddingForUnalignedAccesses.
  // Skip for the scalar case because no extra lanes will be loaded.
  if (vec_size != 0) {
    valid_bytes += vec_size - sizeof_t;
  }

  // Round up to vector and cache line size.
  const size_t align = std::max(vec_size, CacheAligned::kAlignment);
  size_t bytes_per_row = RoundUpTo(valid_bytes, align);

  // During the lengthy window before writes are committed to memory, CPUs
  // guard against read after write hazards by checking the address, but
  // only the lower 11 bits. We avoid a false dependency between writes to
  // consecutive rows by ensuring their sizes are not multiples of 2 KiB.
  // Avoid2K prevents the same problem for the planes of an Image3.
  if (bytes_per_row % CacheAligned::kAlias == 0) {
    bytes_per_row += align;
  }

  JXL_ASSERT(bytes_per_row % align == 0);
  return bytes_per_row;
}

}  // namespace

size_t VectorSize() {
  static size_t bytes = HWY_DYNAMIC_DISPATCH(GetVectorSize)();
  return bytes;
}

PlaneBase::PlaneBase(const size_t xsize, const size_t ysize,
                     const size_t sizeof_t)
    : xsize_(static_cast<uint32_t>(xsize)),
      ysize_(static_cast<uint32_t>(ysize)),
      orig_xsize_(static_cast<uint32_t>(xsize)),
      orig_ysize_(static_cast<uint32_t>(ysize)) {
  JXL_CHECK(xsize == xsize_);
  JXL_CHECK(ysize == ysize_);

  JXL_ASSERT(sizeof_t == 1 || sizeof_t == 2 || sizeof_t == 4 || sizeof_t == 8);

  bytes_per_row_ = 0;
  // Dimensions can be zero, e.g. for lazily-allocated images. Only allocate
  // if nonzero, because "zero" bytes still have padding/bookkeeping overhead.
  if (xsize != 0 && ysize != 0) {
    bytes_per_row_ = BytesPerRow(xsize, sizeof_t);
    bytes_ = AllocateArray(bytes_per_row_ * ysize);
    JXL_CHECK(bytes_.get());
    InitializePadding(sizeof_t, Padding::kRoundUp);
  }
}

void PlaneBase::InitializePadding(const size_t sizeof_t, Padding padding) {
#if defined(MEMORY_SANITIZER) || HWY_IDE
  if (xsize_ == 0 || ysize_ == 0) return;

  const size_t vec_size = VectorSize();
  if (vec_size == 0) return;  // Scalar mode: no padding needed

  const size_t valid_size = xsize_ * sizeof_t;
  const size_t initialize_size = padding == Padding::kRoundUp
                                     ? RoundUpTo(valid_size, vec_size)
                                     : valid_size + vec_size - sizeof_t;
  if (valid_size == initialize_size) return;

  for (size_t y = 0; y < ysize_; ++y) {
    uint8_t* JXL_RESTRICT row = static_cast<uint8_t*>(VoidRow(y));
#if defined(__clang__) &&                                           \
    ((!defined(__apple_build_version__) && __clang_major__ <= 6) || \
     (defined(__apple_build_version__) &&                           \
      __apple_build_version__ <= 10001145))
    // There's a bug in msan in clang-6 when handling AVX2 operations. This
    // workaround allows tests to pass on msan, although it is slower and
    // prevents msan warnings from uninitialized images.
    std::fill(row, msan::kSanitizerSentinelByte, initialize_size);
#else
    memset(row + valid_size, msan::kSanitizerSentinelByte,
           initialize_size - valid_size);
#endif  // clang6
  }
#endif  // MEMORY_SANITIZER
}

void PlaneBase::Swap(PlaneBase& other) {
  std::swap(xsize_, other.xsize_);
  std::swap(ysize_, other.ysize_);
  std::swap(orig_xsize_, other.orig_xsize_);
  std::swap(orig_ysize_, other.orig_ysize_);
  std::swap(bytes_per_row_, other.bytes_per_row_);
  std::swap(bytes_, other.bytes_);
}

void PadImageToBlockMultipleInPlace(Image3F* JXL_RESTRICT in,
                                    size_t block_dim) {
  const size_t xsize_orig = in->xsize();
  const size_t ysize_orig = in->ysize();
  const size_t xsize = RoundUpTo(xsize_orig, block_dim);
  const size_t ysize = RoundUpTo(ysize_orig, block_dim);
  // Expands image size to the originally-allocated size.
  in->ShrinkTo(xsize, ysize);
  for (size_t c = 0; c < 3; c++) {
    for (size_t y = 0; y < ysize_orig; y++) {
      float* JXL_RESTRICT row = in->PlaneRow(c, y);
      for (size_t x = xsize_orig; x < xsize; x++) {
        row[x] = row[xsize_orig - 1];
      }
    }
    const float* JXL_RESTRICT row_src = in->ConstPlaneRow(c, ysize_orig - 1);
    for (size_t y = ysize_orig; y < ysize; y++) {
      memcpy(in->PlaneRow(c, y), row_src, xsize * sizeof(float));
    }
  }
}

static void DownsampleImage(const ImageF& input, size_t factor,
                            ImageF* output) {
  JXL_ASSERT(factor != 1);
  output->ShrinkTo(DivCeil(input.xsize(), factor),
                   DivCeil(input.ysize(), factor));
  size_t in_stride = input.PixelsPerRow();
  for (size_t y = 0; y < output->ysize(); y++) {
    float* row_out = output->Row(y);
    const float* row_in = input.Row(factor * y);
    for (size_t x = 0; x < output->xsize(); x++) {
      size_t cnt = 0;
      float sum = 0;
      for (size_t iy = 0; iy < factor && iy + factor * y < input.ysize();
           iy++) {
        for (size_t ix = 0; ix < factor && ix + factor * x < input.xsize();
             ix++) {
          sum += row_in[iy * in_stride + x * factor + ix];
          cnt++;
        }
      }
      row_out[x] = sum / cnt;
    }
  }
}

void DownsampleImage(ImageF* image, size_t factor) {
  // Allocate extra space to avoid a reallocation when padding.
  ImageF downsampled(DivCeil(image->xsize(), factor) + kBlockDim,
                     DivCeil(image->ysize(), factor) + kBlockDim);
  DownsampleImage(*image, factor, &downsampled);
  *image = std::move(downsampled);
}

void DownsampleImage(Image3F* opsin, size_t factor) {
  JXL_ASSERT(factor != 1);
  // Allocate extra space to avoid a reallocation when padding.
  Image3F downsampled(DivCeil(opsin->xsize(), factor) + kBlockDim,
                      DivCeil(opsin->ysize(), factor) + kBlockDim);
  downsampled.ShrinkTo(downsampled.xsize() - kBlockDim,
                       downsampled.ysize() - kBlockDim);
  for (size_t c = 0; c < 3; c++) {
    DownsampleImage(opsin->Plane(c), factor, &downsampled.Plane(c));
  }
  *opsin = std::move(downsampled);
}

}  // namespace jxl
#endif  // HWY_ONCE
