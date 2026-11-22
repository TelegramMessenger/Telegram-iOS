// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/input.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/input.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jpegli/encode_internal.h"
#include "lib/jpegli/error.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/compiler_specific.h"

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {

using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::Rebind;
using hwy::HWY_NAMESPACE::Vec;

using D = HWY_FULL(float);
using DU = HWY_FULL(uint32_t);
using DU8 = Rebind<uint8_t, D>;
using DU16 = Rebind<uint16_t, D>;

constexpr D d;
constexpr DU du;
constexpr DU8 du8;
constexpr DU16 du16;

static constexpr double kMul16 = 1.0 / 257.0;
static constexpr double kMulFloat = 255.0;

template <size_t C>
void ReadUint8Row(const uint8_t* row_in, size_t x0, size_t len,
                  float* row_out[kMaxComponents]) {
  for (size_t x = x0; x < len; ++x) {
    for (size_t c = 0; c < C; ++c) {
      row_out[c][x] = row_in[C * x + c];
    }
  }
}

template <size_t C, bool swap_endianness = false>
void ReadUint16Row(const uint8_t* row_in, size_t x0, size_t len,
                   float* row_out[kMaxComponents]) {
  const uint16_t* row16 = reinterpret_cast<const uint16_t*>(row_in);
  for (size_t x = x0; x < len; ++x) {
    for (size_t c = 0; c < C; ++c) {
      uint16_t val = row16[C * x + c];
      if (swap_endianness) val = JXL_BSWAP16(val);
      row_out[c][x] = val * kMul16;
    }
  }
}

template <size_t C, bool swap_endianness = false>
void ReadFloatRow(const uint8_t* row_in, size_t x0, size_t len,
                  float* row_out[kMaxComponents]) {
  const float* rowf = reinterpret_cast<const float*>(row_in);
  for (size_t x = x0; x < len; ++x) {
    for (size_t c = 0; c < C; ++c) {
      float val = rowf[C * x + c];
      if (swap_endianness) val = BSwapFloat(val);
      row_out[c][x] = val * kMulFloat;
    }
  }
}

void ReadUint8RowSingle(const uint8_t* row_in, size_t len,
                        float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  float* JXL_RESTRICT const row0 = row_out[0];
  for (size_t x = 0; x < simd_len; x += N) {
    Store(ConvertTo(d, PromoteTo(du, LoadU(du8, row_in + x))), d, row0 + x);
  }
  ReadUint8Row<1>(row_in, simd_len, len, row_out);
}

void ReadUint8RowInterleaved2(const uint8_t* row_in, size_t len,
                              float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  Vec<DU8> out0, out1;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved2(du8, row_in + 2 * x, out0, out1);
    Store(ConvertTo(d, PromoteTo(du, out0)), d, row0 + x);
    Store(ConvertTo(d, PromoteTo(du, out1)), d, row1 + x);
  }
  ReadUint8Row<2>(row_in, simd_len, len, row_out);
}

void ReadUint8RowInterleaved3(const uint8_t* row_in, size_t len,
                              float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  float* JXL_RESTRICT const row2 = row_out[2];
  Vec<DU8> out0, out1, out2;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved3(du8, row_in + 3 * x, out0, out1, out2);
    Store(ConvertTo(d, PromoteTo(du, out0)), d, row0 + x);
    Store(ConvertTo(d, PromoteTo(du, out1)), d, row1 + x);
    Store(ConvertTo(d, PromoteTo(du, out2)), d, row2 + x);
  }
  ReadUint8Row<3>(row_in, simd_len, len, row_out);
}

void ReadUint8RowInterleaved4(const uint8_t* row_in, size_t len,
                              float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  float* JXL_RESTRICT const row2 = row_out[2];
  float* JXL_RESTRICT const row3 = row_out[3];
  Vec<DU8> out0, out1, out2, out3;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved4(du8, row_in + 4 * x, out0, out1, out2, out3);
    Store(ConvertTo(d, PromoteTo(du, out0)), d, row0 + x);
    Store(ConvertTo(d, PromoteTo(du, out1)), d, row1 + x);
    Store(ConvertTo(d, PromoteTo(du, out2)), d, row2 + x);
    Store(ConvertTo(d, PromoteTo(du, out3)), d, row3 + x);
  }
  ReadUint8Row<4>(row_in, simd_len, len, row_out);
}

void ReadUint16RowSingle(const uint8_t* row_in, size_t len,
                         float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMul16);
  const uint16_t* JXL_RESTRICT const row =
      reinterpret_cast<const uint16_t*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  for (size_t x = 0; x < simd_len; x += N) {
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, LoadU(du16, row + x)))), d,
          row0 + x);
  }
  ReadUint16Row<1>(row_in, simd_len, len, row_out);
}

void ReadUint16RowInterleaved2(const uint8_t* row_in, size_t len,
                               float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMul16);
  const uint16_t* JXL_RESTRICT const row =
      reinterpret_cast<const uint16_t*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  Vec<DU16> out0, out1;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved2(du16, row + 2 * x, out0, out1);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out0))), d, row0 + x);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out1))), d, row1 + x);
  }
  ReadUint16Row<2>(row_in, simd_len, len, row_out);
}

void ReadUint16RowInterleaved3(const uint8_t* row_in, size_t len,
                               float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMul16);
  const uint16_t* JXL_RESTRICT const row =
      reinterpret_cast<const uint16_t*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  float* JXL_RESTRICT const row2 = row_out[2];
  Vec<DU16> out0, out1, out2;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved3(du16, row + 3 * x, out0, out1, out2);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out0))), d, row0 + x);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out1))), d, row1 + x);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out2))), d, row2 + x);
  }
  ReadUint16Row<3>(row_in, simd_len, len, row_out);
}

void ReadUint16RowInterleaved4(const uint8_t* row_in, size_t len,
                               float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMul16);
  const uint16_t* JXL_RESTRICT const row =
      reinterpret_cast<const uint16_t*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  float* JXL_RESTRICT const row2 = row_out[2];
  float* JXL_RESTRICT const row3 = row_out[3];
  Vec<DU16> out0, out1, out2, out3;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved4(du16, row + 4 * x, out0, out1, out2, out3);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out0))), d, row0 + x);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out1))), d, row1 + x);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out2))), d, row2 + x);
    Store(Mul(mul, ConvertTo(d, PromoteTo(du, out3))), d, row3 + x);
  }
  ReadUint16Row<4>(row_in, simd_len, len, row_out);
}

void ReadUint16RowSingleSwap(const uint8_t* row_in, size_t len,
                             float* row_out[kMaxComponents]) {
  ReadUint16Row<1, true>(row_in, 0, len, row_out);
}

void ReadUint16RowInterleaved2Swap(const uint8_t* row_in, size_t len,
                                   float* row_out[kMaxComponents]) {
  ReadUint16Row<2, true>(row_in, 0, len, row_out);
}

void ReadUint16RowInterleaved3Swap(const uint8_t* row_in, size_t len,
                                   float* row_out[kMaxComponents]) {
  ReadUint16Row<3, true>(row_in, 0, len, row_out);
}

void ReadUint16RowInterleaved4Swap(const uint8_t* row_in, size_t len,
                                   float* row_out[kMaxComponents]) {
  ReadUint16Row<4, true>(row_in, 0, len, row_out);
}

void ReadFloatRowSingle(const uint8_t* row_in, size_t len,
                        float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMulFloat);
  const float* JXL_RESTRICT const row = reinterpret_cast<const float*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  for (size_t x = 0; x < simd_len; x += N) {
    Store(Mul(mul, LoadU(d, row + x)), d, row0 + x);
  }
  ReadFloatRow<1>(row_in, simd_len, len, row_out);
}

void ReadFloatRowInterleaved2(const uint8_t* row_in, size_t len,
                              float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMulFloat);
  const float* JXL_RESTRICT const row = reinterpret_cast<const float*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  Vec<D> out0, out1;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved2(d, row + 2 * x, out0, out1);
    Store(Mul(mul, out0), d, row0 + x);
    Store(Mul(mul, out1), d, row1 + x);
  }
  ReadFloatRow<2>(row_in, simd_len, len, row_out);
}

void ReadFloatRowInterleaved3(const uint8_t* row_in, size_t len,
                              float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMulFloat);
  const float* JXL_RESTRICT const row = reinterpret_cast<const float*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  float* JXL_RESTRICT const row2 = row_out[2];
  Vec<D> out0, out1, out2;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved3(d, row + 3 * x, out0, out1, out2);
    Store(Mul(mul, out0), d, row0 + x);
    Store(Mul(mul, out1), d, row1 + x);
    Store(Mul(mul, out2), d, row2 + x);
  }
  ReadFloatRow<3>(row_in, simd_len, len, row_out);
}

void ReadFloatRowInterleaved4(const uint8_t* row_in, size_t len,
                              float* row_out[kMaxComponents]) {
  const size_t N = Lanes(d);
  const size_t simd_len = len & (~(N - 1));
  const auto mul = Set(d, kMulFloat);
  const float* JXL_RESTRICT const row = reinterpret_cast<const float*>(row_in);
  float* JXL_RESTRICT const row0 = row_out[0];
  float* JXL_RESTRICT const row1 = row_out[1];
  float* JXL_RESTRICT const row2 = row_out[2];
  float* JXL_RESTRICT const row3 = row_out[3];
  Vec<D> out0, out1, out2, out3;
  for (size_t x = 0; x < simd_len; x += N) {
    LoadInterleaved4(d, row + 4 * x, out0, out1, out2, out3);
    Store(Mul(mul, out0), d, row0 + x);
    Store(Mul(mul, out1), d, row1 + x);
    Store(Mul(mul, out2), d, row2 + x);
    Store(Mul(mul, out3), d, row3 + x);
  }
  ReadFloatRow<4>(row_in, simd_len, len, row_out);
}

void ReadFloatRowSingleSwap(const uint8_t* row_in, size_t len,
                            float* row_out[kMaxComponents]) {
  ReadFloatRow<1, true>(row_in, 0, len, row_out);
}

void ReadFloatRowInterleaved2Swap(const uint8_t* row_in, size_t len,
                                  float* row_out[kMaxComponents]) {
  ReadFloatRow<2, true>(row_in, 0, len, row_out);
}

void ReadFloatRowInterleaved3Swap(const uint8_t* row_in, size_t len,
                                  float* row_out[kMaxComponents]) {
  ReadFloatRow<3, true>(row_in, 0, len, row_out);
}

void ReadFloatRowInterleaved4Swap(const uint8_t* row_in, size_t len,
                                  float* row_out[kMaxComponents]) {
  ReadFloatRow<4, true>(row_in, 0, len, row_out);
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jpegli {

HWY_EXPORT(ReadUint8RowSingle);
HWY_EXPORT(ReadUint8RowInterleaved2);
HWY_EXPORT(ReadUint8RowInterleaved3);
HWY_EXPORT(ReadUint8RowInterleaved4);
HWY_EXPORT(ReadUint16RowSingle);
HWY_EXPORT(ReadUint16RowInterleaved2);
HWY_EXPORT(ReadUint16RowInterleaved3);
HWY_EXPORT(ReadUint16RowInterleaved4);
HWY_EXPORT(ReadUint16RowSingleSwap);
HWY_EXPORT(ReadUint16RowInterleaved2Swap);
HWY_EXPORT(ReadUint16RowInterleaved3Swap);
HWY_EXPORT(ReadUint16RowInterleaved4Swap);
HWY_EXPORT(ReadFloatRowSingle);
HWY_EXPORT(ReadFloatRowInterleaved2);
HWY_EXPORT(ReadFloatRowInterleaved3);
HWY_EXPORT(ReadFloatRowInterleaved4);
HWY_EXPORT(ReadFloatRowSingleSwap);
HWY_EXPORT(ReadFloatRowInterleaved2Swap);
HWY_EXPORT(ReadFloatRowInterleaved3Swap);
HWY_EXPORT(ReadFloatRowInterleaved4Swap);

void ChooseInputMethod(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  bool swap_endianness =
      (m->endianness == JPEGLI_LITTLE_ENDIAN && !IsLittleEndian()) ||
      (m->endianness == JPEGLI_BIG_ENDIAN && IsLittleEndian());
  m->input_method = nullptr;
  if (m->data_type == JPEGLI_TYPE_UINT8) {
    if (cinfo->raw_data_in || cinfo->input_components == 1) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint8RowSingle);
    } else if (cinfo->input_components == 2) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint8RowInterleaved2);
    } else if (cinfo->input_components == 3) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint8RowInterleaved3);
    } else if (cinfo->input_components == 4) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint8RowInterleaved4);
    }
  } else if (m->data_type == JPEGLI_TYPE_UINT16 && !swap_endianness) {
    if (cinfo->raw_data_in || cinfo->input_components == 1) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowSingle);
    } else if (cinfo->input_components == 2) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowInterleaved2);
    } else if (cinfo->input_components == 3) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowInterleaved3);
    } else if (cinfo->input_components == 4) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowInterleaved4);
    }
  } else if (m->data_type == JPEGLI_TYPE_UINT16 && swap_endianness) {
    if (cinfo->raw_data_in || cinfo->input_components == 1) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowSingleSwap);
    } else if (cinfo->input_components == 2) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowInterleaved2Swap);
    } else if (cinfo->input_components == 3) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowInterleaved3Swap);
    } else if (cinfo->input_components == 4) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadUint16RowInterleaved4Swap);
    }
  } else if (m->data_type == JPEGLI_TYPE_FLOAT && !swap_endianness) {
    if (cinfo->raw_data_in || cinfo->input_components == 1) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowSingle);
    } else if (cinfo->input_components == 2) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowInterleaved2);
    } else if (cinfo->input_components == 3) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowInterleaved3);
    } else if (cinfo->input_components == 4) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowInterleaved4);
    }
  } else if (m->data_type == JPEGLI_TYPE_FLOAT && swap_endianness) {
    if (cinfo->raw_data_in || cinfo->input_components == 1) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowSingleSwap);
    } else if (cinfo->input_components == 2) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowInterleaved2Swap);
    } else if (cinfo->input_components == 3) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowInterleaved3Swap);
    } else if (cinfo->input_components == 4) {
      m->input_method = HWY_DYNAMIC_DISPATCH(ReadFloatRowInterleaved4Swap);
    }
  }
  if (m->input_method == nullptr) {
    JPEGLI_ERROR("Could not find input method.");
  }
}

}  // namespace jpegli
#endif  // HWY_ONCE
