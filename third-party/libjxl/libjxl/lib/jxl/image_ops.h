// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_IMAGE_OPS_H_
#define LIB_JXL_IMAGE_OPS_H_

// Operations on images.

#include <algorithm>
#include <array>
#include <limits>
#include <vector>

#include "lib/jxl/base/status.h"
#include "lib/jxl/common.h"
#include "lib/jxl/image.h"

namespace jxl {

template <typename T>
void CopyImageTo(const Plane<T>& from, Plane<T>* JXL_RESTRICT to) {
  JXL_ASSERT(SameSize(from, *to));
  if (from.ysize() == 0 || from.xsize() == 0) return;
  for (size_t y = 0; y < from.ysize(); ++y) {
    const T* JXL_RESTRICT row_from = from.ConstRow(y);
    T* JXL_RESTRICT row_to = to->Row(y);
    memcpy(row_to, row_from, from.xsize() * sizeof(T));
  }
}

// Copies `from:rect_from` to `to:rect_to`.
template <typename T>
void CopyImageTo(const Rect& rect_from, const Plane<T>& from,
                 const Rect& rect_to, Plane<T>* JXL_RESTRICT to) {
  JXL_DASSERT(SameSize(rect_from, rect_to));
  JXL_DASSERT(rect_from.IsInside(from));
  JXL_DASSERT(rect_to.IsInside(*to));
  if (rect_from.xsize() == 0) return;
  for (size_t y = 0; y < rect_from.ysize(); ++y) {
    const T* JXL_RESTRICT row_from = rect_from.ConstRow(from, y);
    T* JXL_RESTRICT row_to = rect_to.Row(to, y);
    memcpy(row_to, row_from, rect_from.xsize() * sizeof(T));
  }
}

// Copies `from:rect_from` to `to:rect_to`.
template <typename T>
void CopyImageTo(const Rect& rect_from, const Image3<T>& from,
                 const Rect& rect_to, Image3<T>* JXL_RESTRICT to) {
  JXL_ASSERT(SameSize(rect_from, rect_to));
  for (size_t c = 0; c < 3; c++) {
    CopyImageTo(rect_from, from.Plane(c), rect_to, &to->Plane(c));
  }
}

template <typename T, typename U>
void ConvertPlaneAndClamp(const Rect& rect_from, const Plane<T>& from,
                          const Rect& rect_to, Plane<U>* JXL_RESTRICT to) {
  JXL_ASSERT(SameSize(rect_from, rect_to));
  using M = decltype(T() + U());
  for (size_t y = 0; y < rect_to.ysize(); ++y) {
    const T* JXL_RESTRICT row_from = rect_from.ConstRow(from, y);
    U* JXL_RESTRICT row_to = rect_to.Row(to, y);
    for (size_t x = 0; x < rect_to.xsize(); ++x) {
      row_to[x] =
          std::min<M>(std::max<M>(row_from[x], std::numeric_limits<U>::min()),
                      std::numeric_limits<U>::max());
    }
  }
}

// Copies `from` to `to`.
template <typename T>
void CopyImageTo(const T& from, T* JXL_RESTRICT to) {
  return CopyImageTo(Rect(from), from, Rect(*to), to);
}

// Copies `from:rect_from` to `to:rect_to`; also copies `padding` pixels of
// border around `from:rect_from`, in all directions, whenever they are inside
// the first image.
template <typename T>
void CopyImageToWithPadding(const Rect& from_rect, const T& from,
                            size_t padding, const Rect& to_rect, T* to) {
  size_t xextra0 = std::min(padding, from_rect.x0());
  size_t xextra1 =
      std::min(padding, from.xsize() - from_rect.x0() - from_rect.xsize());
  size_t yextra0 = std::min(padding, from_rect.y0());
  size_t yextra1 =
      std::min(padding, from.ysize() - from_rect.y0() - from_rect.ysize());
  JXL_DASSERT(to_rect.x0() >= xextra0);
  JXL_DASSERT(to_rect.y0() >= yextra0);

  return CopyImageTo(Rect(from_rect.x0() - xextra0, from_rect.y0() - yextra0,
                          from_rect.xsize() + xextra0 + xextra1,
                          from_rect.ysize() + yextra0 + yextra1),
                     from,
                     Rect(to_rect.x0() - xextra0, to_rect.y0() - yextra0,
                          to_rect.xsize() + xextra0 + xextra1,
                          to_rect.ysize() + yextra0 + yextra1),
                     to);
}

template <class ImageIn, class ImageOut>
void Subtract(const ImageIn& image1, const ImageIn& image2, ImageOut* out) {
  using T = typename ImageIn::T;
  const size_t xsize = image1.xsize();
  const size_t ysize = image1.ysize();
  JXL_CHECK(xsize == image2.xsize());
  JXL_CHECK(ysize == image2.ysize());

  for (size_t y = 0; y < ysize; ++y) {
    const T* const JXL_RESTRICT row1 = image1.Row(y);
    const T* const JXL_RESTRICT row2 = image2.Row(y);
    T* const JXL_RESTRICT row_out = out->Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      row_out[x] = row1[x] - row2[x];
    }
  }
}

// In-place.
template <typename Tin, typename Tout>
void SubtractFrom(const Plane<Tin>& what, Plane<Tout>* to) {
  const size_t xsize = what.xsize();
  const size_t ysize = what.ysize();
  for (size_t y = 0; y < ysize; ++y) {
    const Tin* JXL_RESTRICT row_what = what.ConstRow(y);
    Tout* JXL_RESTRICT row_to = to->Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      row_to[x] -= row_what[x];
    }
  }
}

// In-place.
template <typename Tin, typename Tout>
void AddTo(const Plane<Tin>& what, Plane<Tout>* to) {
  const size_t xsize = what.xsize();
  const size_t ysize = what.ysize();
  for (size_t y = 0; y < ysize; ++y) {
    const Tin* JXL_RESTRICT row_what = what.ConstRow(y);
    Tout* JXL_RESTRICT row_to = to->Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      row_to[x] += row_what[x];
    }
  }
}

template <typename Tin, typename Tout>
void AddTo(Rect rectFrom, const Plane<Tin>& what, Rect rectTo,
           Plane<Tout>* to) {
  JXL_ASSERT(SameSize(rectFrom, rectTo));
  const size_t xsize = rectTo.xsize();
  const size_t ysize = rectTo.ysize();
  for (size_t y = 0; y < ysize; ++y) {
    const Tin* JXL_RESTRICT row_what = rectFrom.ConstRow(what, y);
    Tout* JXL_RESTRICT row_to = rectTo.Row(to, y);
    for (size_t x = 0; x < xsize; ++x) {
      row_to[x] += row_what[x];
    }
  }
}

// Returns linear combination of two grayscale images.
template <typename T>
Plane<T> LinComb(const T lambda1, const Plane<T>& image1, const T lambda2,
                 const Plane<T>& image2) {
  const size_t xsize = image1.xsize();
  const size_t ysize = image1.ysize();
  JXL_CHECK(xsize == image2.xsize());
  JXL_CHECK(ysize == image2.ysize());
  Plane<T> out(xsize, ysize);
  for (size_t y = 0; y < ysize; ++y) {
    const T* const JXL_RESTRICT row1 = image1.Row(y);
    const T* const JXL_RESTRICT row2 = image2.Row(y);
    T* const JXL_RESTRICT row_out = out.Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      row_out[x] = lambda1 * row1[x] + lambda2 * row2[x];
    }
  }
  return out;
}

// Multiplies image by lambda in-place
template <typename T>
void ScaleImage(const T lambda, Plane<T>* image) {
  for (size_t y = 0; y < image->ysize(); ++y) {
    T* const JXL_RESTRICT row = image->Row(y);
    for (size_t x = 0; x < image->xsize(); ++x) {
      row[x] = lambda * row[x];
    }
  }
}

// Multiplies image by lambda in-place
template <typename T>
void ScaleImage(const T lambda, Image3<T>* image) {
  for (size_t c = 0; c < 3; ++c) {
    ScaleImage(lambda, &image->Plane(c));
  }
}

template <typename T>
Plane<T> Product(const Plane<T>& a, const Plane<T>& b) {
  Plane<T> c(a.xsize(), a.ysize());
  for (size_t y = 0; y < a.ysize(); ++y) {
    const T* const JXL_RESTRICT row_a = a.Row(y);
    const T* const JXL_RESTRICT row_b = b.Row(y);
    T* const JXL_RESTRICT row_c = c.Row(y);
    for (size_t x = 0; x < a.xsize(); ++x) {
      row_c[x] = row_a[x] * row_b[x];
    }
  }
  return c;
}

template <typename T>
void FillImage(const T value, Plane<T>* image) {
  for (size_t y = 0; y < image->ysize(); ++y) {
    T* const JXL_RESTRICT row = image->Row(y);
    for (size_t x = 0; x < image->xsize(); ++x) {
      row[x] = value;
    }
  }
}

template <typename T>
void ZeroFillImage(Plane<T>* image) {
  if (image->xsize() == 0) return;
  for (size_t y = 0; y < image->ysize(); ++y) {
    T* const JXL_RESTRICT row = image->Row(y);
    memset(row, 0, image->xsize() * sizeof(T));
  }
}

// Mirrors out of bounds coordinates and returns valid coordinates unchanged.
// We assume the radius (distance outside the image) is small compared to the
// image size, otherwise this might not terminate.
// The mirror is outside the last column (border pixel is also replicated).
static inline int64_t Mirror(int64_t x, const int64_t xsize) {
  JXL_DASSERT(xsize != 0);

  // TODO(janwas): replace with branchless version
  while (x < 0 || x >= xsize) {
    if (x < 0) {
      x = -x - 1;
    } else {
      x = 2 * xsize - 1 - x;
    }
  }
  return x;
}

// Wrap modes for ensuring X/Y coordinates are in the valid range [0, size):

// Mirrors (repeating the edge pixel once). Useful for convolutions.
struct WrapMirror {
  JXL_INLINE int64_t operator()(const int64_t coord, const int64_t size) const {
    return Mirror(coord, size);
  }
};

// Returns the same coordinate: required for TFNode with Border(), or useful
// when we know "coord" is already valid (e.g. interior of an image).
struct WrapUnchanged {
  JXL_INLINE int64_t operator()(const int64_t coord, int64_t /*size*/) const {
    return coord;
  }
};

// Similar to Wrap* but for row pointers (reduces Row() multiplications).

class WrapRowMirror {
 public:
  template <class ImageOrView>
  WrapRowMirror(const ImageOrView& image, size_t ysize)
      : first_row_(image.ConstRow(0)), last_row_(image.ConstRow(ysize - 1)) {}

  const float* operator()(const float* const JXL_RESTRICT row,
                          const int64_t stride) const {
    if (row < first_row_) {
      const int64_t num_before = first_row_ - row;
      // Mirrored; one row before => row 0, two before = row 1, ...
      return first_row_ + num_before - stride;
    }
    if (row > last_row_) {
      const int64_t num_after = row - last_row_;
      // Mirrored; one row after => last row, two after = last - 1, ...
      return last_row_ - num_after + stride;
    }
    return row;
  }

 private:
  const float* const JXL_RESTRICT first_row_;
  const float* const JXL_RESTRICT last_row_;
};

struct WrapRowUnchanged {
  JXL_INLINE const float* operator()(const float* const JXL_RESTRICT row,
                                     int64_t /*stride*/) const {
    return row;
  }
};

// Sets "thickness" pixels on each border to "value". This is faster than
// initializing the entire image and overwriting valid/interior pixels.
template <typename T>
void SetBorder(const size_t thickness, const T value, Plane<T>* image) {
  const size_t xsize = image->xsize();
  const size_t ysize = image->ysize();
  // Top: fill entire row
  for (size_t y = 0; y < std::min(thickness, ysize); ++y) {
    T* const JXL_RESTRICT row = image->Row(y);
    std::fill(row, row + xsize, value);
  }

  // Bottom: fill entire row
  for (size_t y = ysize - thickness; y < ysize; ++y) {
    T* const JXL_RESTRICT row = image->Row(y);
    std::fill(row, row + xsize, value);
  }

  // Left/right: fill the 'columns' on either side, but only if the image is
  // big enough that they don't already belong to the top/bottom rows.
  if (ysize >= 2 * thickness) {
    for (size_t y = thickness; y < ysize - thickness; ++y) {
      T* const JXL_RESTRICT row = image->Row(y);
      std::fill(row, row + thickness, value);
      std::fill(row + xsize - thickness, row + xsize, value);
    }
  }
}

// Computes the minimum and maximum pixel value.
template <typename T>
void ImageMinMax(const Plane<T>& image, T* const JXL_RESTRICT min,
                 T* const JXL_RESTRICT max) {
  *min = std::numeric_limits<T>::max();
  *max = std::numeric_limits<T>::lowest();
  for (size_t y = 0; y < image.ysize(); ++y) {
    const T* const JXL_RESTRICT row = image.Row(y);
    for (size_t x = 0; x < image.xsize(); ++x) {
      *min = std::min(*min, row[x]);
      *max = std::max(*max, row[x]);
    }
  }
}

// Copies pixels, scaling their value relative to the "from" min/max by
// "to_range". Example: U8 [0, 255] := [0.0, 1.0], to_range = 1.0 =>
// outputs [0.0, 1.0].
template <typename FromType, typename ToType>
void ImageConvert(const Plane<FromType>& from, const float to_range,
                  Plane<ToType>* const JXL_RESTRICT to) {
  JXL_ASSERT(SameSize(from, *to));
  FromType min_from, max_from;
  ImageMinMax(from, &min_from, &max_from);
  const float scale = to_range / (max_from - min_from);
  for (size_t y = 0; y < from.ysize(); ++y) {
    const FromType* const JXL_RESTRICT row_from = from.Row(y);
    ToType* const JXL_RESTRICT row_to = to->Row(y);
    for (size_t x = 0; x < from.xsize(); ++x) {
      row_to[x] = static_cast<ToType>((row_from[x] - min_from) * scale);
    }
  }
}

template <typename From>
Plane<float> ConvertToFloat(const Plane<From>& from) {
  float factor = 1.0f / std::numeric_limits<From>::max();
  if (std::is_same<From, double>::value || std::is_same<From, float>::value) {
    factor = 1.0f;
  }
  Plane<float> to(from.xsize(), from.ysize());
  for (size_t y = 0; y < from.ysize(); ++y) {
    const From* const JXL_RESTRICT row_from = from.Row(y);
    float* const JXL_RESTRICT row_to = to.Row(y);
    for (size_t x = 0; x < from.xsize(); ++x) {
      row_to[x] = row_from[x] * factor;
    }
  }
  return to;
}

template <typename T>
Plane<T> ImageFromPacked(const std::vector<T>& packed, const size_t xsize,
                         const size_t ysize) {
  Plane<T> out(xsize, ysize);
  for (size_t y = 0; y < ysize; ++y) {
    T* const JXL_RESTRICT row = out.Row(y);
    const T* const JXL_RESTRICT packed_row = &packed[y * xsize];
    memcpy(row, packed_row, xsize * sizeof(T));
  }
  return out;
}

template <typename T>
void Image3Max(const Image3<T>& image, std::array<T, 3>* out_max) {
  for (size_t c = 0; c < 3; ++c) {
    T max = std::numeric_limits<T>::min();
    for (size_t y = 0; y < image.ysize(); ++y) {
      const T* JXL_RESTRICT row = image.ConstPlaneRow(c, y);
      for (size_t x = 0; x < image.xsize(); ++x) {
        max = std::max(max, row[x]);
      }
    }
    (*out_max)[c] = max;
  }
}

// Computes the sum of the pixels in `rect`.
template <typename T>
T ImageSum(const Plane<T>& image, const Rect& rect) {
  T result = 0;
  for (size_t y = 0; y < rect.ysize(); ++y) {
    const T* JXL_RESTRICT row = rect.ConstRow(image, y);
    for (size_t x = 0; x < rect.xsize(); ++x) {
      result += row[x];
    }
  }
  return result;
}

template <typename T>
std::vector<T> PackedFromImage(const Plane<T>& image, const Rect& rect) {
  const size_t xsize = rect.xsize();
  const size_t ysize = rect.ysize();
  std::vector<T> packed(xsize * ysize);
  for (size_t y = 0; y < rect.ysize(); ++y) {
    memcpy(&packed[y * xsize], rect.ConstRow(image, y), xsize * sizeof(T));
  }
  return packed;
}

template <typename T>
std::vector<T> PackedFromImage(const Plane<T>& image) {
  return PackedFromImage(image, Rect(image));
}

template <typename From>
Image3F ConvertToFloat(const Image3<From>& from) {
  return Image3F(ConvertToFloat(from.Plane(0)), ConvertToFloat(from.Plane(1)),
                 ConvertToFloat(from.Plane(2)));
}

template <typename Tin, typename Tout>
void Subtract(const Image3<Tin>& image1, const Image3<Tin>& image2,
              Image3<Tout>* out) {
  const size_t xsize = image1.xsize();
  const size_t ysize = image1.ysize();
  JXL_CHECK(xsize == image2.xsize());
  JXL_CHECK(ysize == image2.ysize());

  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < ysize; ++y) {
      const Tin* const JXL_RESTRICT row1 = image1.ConstPlaneRow(c, y);
      const Tin* const JXL_RESTRICT row2 = image2.ConstPlaneRow(c, y);
      Tout* const JXL_RESTRICT row_out = out->PlaneRow(c, y);
      for (size_t x = 0; x < xsize; ++x) {
        row_out[x] = row1[x] - row2[x];
      }
    }
  }
}

// Adds `what` of the size of `rect` to `to` in the position of `rect`.
template <typename Tin, typename Tout>
void AddTo(const Rect& rect, const Image3<Tin>& what, Image3<Tout>* to) {
  const size_t xsize = what.xsize();
  const size_t ysize = what.ysize();
  JXL_ASSERT(xsize == rect.xsize());
  JXL_ASSERT(ysize == rect.ysize());
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < ysize; ++y) {
      const Tin* JXL_RESTRICT row_what = what.ConstPlaneRow(c, y);
      Tout* JXL_RESTRICT row_to = rect.PlaneRow(to, c, y);
      for (size_t x = 0; x < xsize; ++x) {
        row_to[x] += row_what[x];
      }
    }
  }
}

// Initializes all planes to the same "value".
template <typename T>
void FillImage(const T value, Image3<T>* image) {
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < image->ysize(); ++y) {
      T* JXL_RESTRICT row = image->PlaneRow(c, y);
      for (size_t x = 0; x < image->xsize(); ++x) {
        row[x] = value;
      }
    }
  }
}

template <typename T>
void FillPlane(const T value, Plane<T>* image) {
  for (size_t y = 0; y < image->ysize(); ++y) {
    T* JXL_RESTRICT row = image->Row(y);
    for (size_t x = 0; x < image->xsize(); ++x) {
      row[x] = value;
    }
  }
}

template <typename T>
void FillImage(const T value, Image3<T>* image, Rect rect) {
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < rect.ysize(); ++y) {
      T* JXL_RESTRICT row = rect.PlaneRow(image, c, y);
      for (size_t x = 0; x < rect.xsize(); ++x) {
        row[x] = value;
      }
    }
  }
}

template <typename T>
void FillPlane(const T value, Plane<T>* image, Rect rect) {
  for (size_t y = 0; y < rect.ysize(); ++y) {
    T* JXL_RESTRICT row = rect.Row(image, y);
    for (size_t x = 0; x < rect.xsize(); ++x) {
      row[x] = value;
    }
  }
}

template <typename T>
void ZeroFillImage(Image3<T>* image) {
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < image->ysize(); ++y) {
      T* JXL_RESTRICT row = image->PlaneRow(c, y);
      if (image->xsize() != 0) memset(row, 0, image->xsize() * sizeof(T));
    }
  }
}

template <typename T>
void ZeroFillPlane(Plane<T>* image, Rect rect) {
  for (size_t y = 0; y < rect.ysize(); ++y) {
    T* JXL_RESTRICT row = rect.Row(image, y);
    memset(row, 0, rect.xsize() * sizeof(T));
  }
}

// Same as above, but operates in-place. Assumes that the `in` image was
// allocated large enough.
void PadImageToBlockMultipleInPlace(Image3F* JXL_RESTRICT in,
                                    size_t block_dim = kBlockDim);

// Downsamples an image by a given factor.
void DownsampleImage(Image3F* opsin, size_t factor);
void DownsampleImage(ImageF* image, size_t factor);

}  // namespace jxl

#endif  // LIB_JXL_IMAGE_OPS_H_
