// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/downsample.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/downsample.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jpegli/encode_internal.h"
#include "lib/jpegli/error.h"

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::Vec;

using D = HWY_CAPPED(float, 8);
constexpr D d;

void DownsampleRow2x1(const float* row_in, size_t len, float* row_out) {
  const size_t N = Lanes(d);
  const size_t len_out = len / 2;
  const auto mul = Set(d, 0.5f);
  Vec<D> v0, v1;
  for (size_t x = 0; x < len_out; x += N) {
    LoadInterleaved2(d, row_in + 2 * x, v0, v1);
    Store(Mul(mul, Add(v0, v1)), d, row_out + x);
  }
}

void DownsampleRow3x1(const float* row_in, size_t len, float* row_out) {
  const size_t N = Lanes(d);
  const size_t len_out = len / 3;
  const auto mul = Set(d, 1.0f / 3);
  Vec<D> v0, v1, v2;
  for (size_t x = 0; x < len_out; x += N) {
    LoadInterleaved3(d, row_in + 3 * x, v0, v1, v2);
    Store(Mul(mul, Add(Add(v0, v1), v2)), d, row_out + x);
  }
}

void DownsampleRow4x1(const float* row_in, size_t len, float* row_out) {
  const size_t N = Lanes(d);
  const size_t len_out = len / 4;
  const auto mul = Set(d, 0.25f);
  Vec<D> v0, v1, v2, v3;
  for (size_t x = 0; x < len_out; x += N) {
    LoadInterleaved4(d, row_in + 4 * x, v0, v1, v2, v3);
    Store(Mul(mul, Add(Add(v0, v1), Add(v2, v3))), d, row_out + x);
  }
}

void Downsample2x1(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow2x1(rows_in[0], len, row_out);
}

void Downsample3x1(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow3x1(rows_in[0], len, row_out);
}

void Downsample4x1(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow4x1(rows_in[0], len, row_out);
}

void Downsample1x2(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  const size_t N = Lanes(d);
  const auto mul = Set(d, 0.5f);
  float* row0 = rows_in[0];
  float* row1 = rows_in[1];
  for (size_t x = 0; x < len; x += N) {
    Store(Mul(mul, Add(Load(d, row0 + x), Load(d, row1 + x))), d, row_out + x);
  }
}

void Downsample2x2(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  const size_t N = Lanes(d);
  const size_t len_out = len / 2;
  const auto mul = Set(d, 0.25f);
  float* row0 = rows_in[0];
  float* row1 = rows_in[1];
  Vec<D> v0, v1, v2, v3;
  for (size_t x = 0; x < len_out; x += N) {
    LoadInterleaved2(d, row0 + 2 * x, v0, v1);
    LoadInterleaved2(d, row1 + 2 * x, v2, v3);
    Store(Mul(mul, Add(Add(v0, v1), Add(v2, v3))), d, row_out + x);
  }
}

void Downsample3x2(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow3x1(rows_in[0], len, rows_in[0]);
  DownsampleRow3x1(rows_in[1], len, rows_in[1]);
  Downsample1x2(rows_in, len / 3, row_out);
}

void Downsample4x2(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow4x1(rows_in[0], len, rows_in[0]);
  DownsampleRow4x1(rows_in[1], len, rows_in[1]);
  Downsample1x2(rows_in, len / 4, row_out);
}

void Downsample1x3(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  const size_t N = Lanes(d);
  const auto mul = Set(d, 1.0f / 3);
  float* row0 = rows_in[0];
  float* row1 = rows_in[1];
  float* row2 = rows_in[2];
  for (size_t x = 0; x < len; x += N) {
    const auto in0 = Load(d, row0 + x);
    const auto in1 = Load(d, row1 + x);
    const auto in2 = Load(d, row2 + x);
    Store(Mul(mul, Add(Add(in0, in1), in2)), d, row_out + x);
  }
}

void Downsample2x3(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow2x1(rows_in[0], len, rows_in[0]);
  DownsampleRow2x1(rows_in[1], len, rows_in[1]);
  DownsampleRow2x1(rows_in[2], len, rows_in[2]);
  Downsample1x3(rows_in, len / 2, row_out);
}

void Downsample3x3(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow3x1(rows_in[0], len, rows_in[0]);
  DownsampleRow3x1(rows_in[1], len, rows_in[1]);
  DownsampleRow3x1(rows_in[2], len, rows_in[2]);
  Downsample1x3(rows_in, len / 3, row_out);
}

void Downsample4x3(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow4x1(rows_in[0], len, rows_in[0]);
  DownsampleRow4x1(rows_in[1], len, rows_in[1]);
  DownsampleRow4x1(rows_in[2], len, rows_in[2]);
  Downsample1x3(rows_in, len / 4, row_out);
}

void Downsample1x4(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  const size_t N = Lanes(d);
  const auto mul = Set(d, 0.25f);
  float* row0 = rows_in[0];
  float* row1 = rows_in[1];
  float* row2 = rows_in[2];
  float* row3 = rows_in[3];
  for (size_t x = 0; x < len; x += N) {
    const auto in0 = Load(d, row0 + x);
    const auto in1 = Load(d, row1 + x);
    const auto in2 = Load(d, row2 + x);
    const auto in3 = Load(d, row3 + x);
    Store(Mul(mul, Add(Add(in0, in1), Add(in2, in3))), d, row_out + x);
  }
}

void Downsample2x4(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow2x1(rows_in[0], len, rows_in[0]);
  DownsampleRow2x1(rows_in[1], len, rows_in[1]);
  DownsampleRow2x1(rows_in[2], len, rows_in[2]);
  DownsampleRow2x1(rows_in[3], len, rows_in[3]);
  Downsample1x4(rows_in, len / 2, row_out);
}

void Downsample3x4(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow3x1(rows_in[0], len, rows_in[0]);
  DownsampleRow3x1(rows_in[1], len, rows_in[1]);
  DownsampleRow3x1(rows_in[2], len, rows_in[2]);
  DownsampleRow3x1(rows_in[3], len, rows_in[3]);
  Downsample1x4(rows_in, len / 3, row_out);
}

void Downsample4x4(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                   float* row_out) {
  DownsampleRow4x1(rows_in[0], len, rows_in[0]);
  DownsampleRow4x1(rows_in[1], len, rows_in[1]);
  DownsampleRow4x1(rows_in[2], len, rows_in[2]);
  DownsampleRow4x1(rows_in[3], len, rows_in[3]);
  Downsample1x4(rows_in, len / 4, row_out);
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jpegli {

HWY_EXPORT(Downsample1x2);
HWY_EXPORT(Downsample1x3);
HWY_EXPORT(Downsample1x4);
HWY_EXPORT(Downsample2x1);
HWY_EXPORT(Downsample2x2);
HWY_EXPORT(Downsample2x3);
HWY_EXPORT(Downsample2x4);
HWY_EXPORT(Downsample3x1);
HWY_EXPORT(Downsample3x2);
HWY_EXPORT(Downsample3x3);
HWY_EXPORT(Downsample3x4);
HWY_EXPORT(Downsample4x1);
HWY_EXPORT(Downsample4x2);
HWY_EXPORT(Downsample4x3);
HWY_EXPORT(Downsample4x4);

void NullDownsample(float* rows_in[MAX_SAMP_FACTOR], size_t len,
                    float* row_out) {}

void ChooseDownsampleMethods(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  for (int c = 0; c < cinfo->num_components; c++) {
    m->downsample_method[c] = nullptr;
    jpeg_component_info* comp = &cinfo->comp_info[c];
    const int h_factor = cinfo->max_h_samp_factor / comp->h_samp_factor;
    const int v_factor = cinfo->max_v_samp_factor / comp->v_samp_factor;
    if (v_factor == 1) {
      if (h_factor == 1) {
        m->downsample_method[c] = NullDownsample;
      } else if (h_factor == 2) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample2x1);
      } else if (h_factor == 3) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample3x1);
      } else if (h_factor == 4) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample4x1);
      }
    } else if (v_factor == 2) {
      if (h_factor == 1) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample1x2);
      } else if (h_factor == 2) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample2x2);
      } else if (h_factor == 3) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample3x2);
      } else if (h_factor == 4) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample4x2);
      }
    } else if (v_factor == 3) {
      if (h_factor == 1) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample1x2);
      } else if (h_factor == 2) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample2x2);
      } else if (h_factor == 3) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample3x2);
      } else if (h_factor == 4) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample4x2);
      }
    } else if (v_factor == 4) {
      if (h_factor == 1) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample1x4);
      } else if (h_factor == 2) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample2x4);
      } else if (h_factor == 3) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample3x4);
      } else if (h_factor == 4) {
        m->downsample_method[c] = HWY_DYNAMIC_DISPATCH(Downsample4x4);
      }
    }
    if (m->downsample_method[c] == nullptr) {
      JPEGLI_ERROR("Unsupported downsampling ratio %dx%d", h_factor, v_factor);
    }
  }
}

void DownsampleInputBuffer(j_compress_ptr cinfo) {
  if (cinfo->max_h_samp_factor == 1 && cinfo->max_v_samp_factor == 1) {
    return;
  }
  jpeg_comp_master* m = cinfo->master;
  const size_t iMCU_height = DCTSIZE * cinfo->max_v_samp_factor;
  const size_t y0 = m->next_iMCU_row * iMCU_height;
  const size_t y1 = y0 + iMCU_height;
  const size_t xsize_padded = m->xsize_blocks * DCTSIZE;
  for (int c = 0; c < cinfo->num_components; c++) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    const int h_factor = cinfo->max_h_samp_factor / comp->h_samp_factor;
    const int v_factor = cinfo->max_v_samp_factor / comp->v_samp_factor;
    if (h_factor == 1 && v_factor == 1) {
      continue;
    }
    auto& input = *m->smooth_input[c];
    auto& output = *m->raw_data[c];
    const size_t yout0 = y0 / v_factor;
    float* rows_in[MAX_SAMP_FACTOR];
    for (size_t yin = y0, yout = yout0; yin < y1; yin += v_factor, ++yout) {
      for (int iy = 0; iy < v_factor; ++iy) {
        rows_in[iy] = input.Row(yin + iy);
      }
      float* row_out = output.Row(yout);
      (*m->downsample_method[c])(rows_in, xsize_padded, row_out);
    }
  }
}

void ApplyInputSmoothing(j_compress_ptr cinfo) {
  if (!cinfo->smoothing_factor) {
    return;
  }
  jpeg_comp_master* m = cinfo->master;
  const float kW1 = cinfo->smoothing_factor / 1024.0;
  const float kW0 = 1.0f - 8.0f * kW1;
  const size_t iMCU_height = DCTSIZE * cinfo->max_v_samp_factor;
  const ssize_t y0 = m->next_iMCU_row * iMCU_height;
  const ssize_t y1 = y0 + iMCU_height;
  const ssize_t xsize_padded = m->xsize_blocks * DCTSIZE;
  for (int c = 0; c < cinfo->num_components; c++) {
    auto& input = m->input_buffer[c];
    auto& output = *m->smooth_input[c];
    if (m->next_iMCU_row == 0) {
      input.CopyRow(-1, 0, 1);
    }
    if (m->next_iMCU_row + 1 == cinfo->total_iMCU_rows) {
      size_t last_row = m->ysize_blocks * DCTSIZE - 1;
      input.CopyRow(last_row + 1, last_row, 1);
    }
    // TODO(szabadka) SIMDify this.
    for (ssize_t y = y0; y < y1; ++y) {
      const float* row_t = input.Row(y - 1);
      const float* row_m = input.Row(y);
      const float* row_b = input.Row(y + 1);
      float* row_out = output.Row(y);
      for (ssize_t x = 0; x < xsize_padded; ++x) {
        float val_tl = row_t[x - 1];
        float val_tm = row_t[x];
        float val_tr = row_t[x + 1];
        float val_ml = row_m[x - 1];
        float val_mm = row_m[x];
        float val_mr = row_m[x + 1];
        float val_bl = row_b[x - 1];
        float val_bm = row_b[x];
        float val_br = row_b[x + 1];
        float val1 = (val_tl + val_tm + val_tr + val_ml + val_mr + val_bl +
                      val_bm + val_br);
        row_out[x] = val_mm * kW0 + val1 * kW1;
      }
    }
  }
}

}  // namespace jpegli
#endif  // HWY_ONCE
