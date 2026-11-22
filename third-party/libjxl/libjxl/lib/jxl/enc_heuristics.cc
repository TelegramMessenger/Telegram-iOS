// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_heuristics.h"

#include <stddef.h>
#include <stdint.h>

#include <algorithm>
#include <numeric>
#include <string>

#include "lib/jxl/enc_ac_strategy.h"
#include "lib/jxl/enc_adaptive_quantization.h"
#include "lib/jxl/enc_ar_control_field.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_chroma_from_luma.h"
#include "lib/jxl/enc_gaborish.h"
#include "lib/jxl/enc_modular.h"
#include "lib/jxl/enc_noise.h"
#include "lib/jxl/enc_patch_dictionary.h"
#include "lib/jxl/enc_photon_noise.h"
#include "lib/jxl/enc_quant_weights.h"
#include "lib/jxl/enc_splines.h"
#include "lib/jxl/enc_xyb.h"

namespace jxl {

struct AuxOut;

namespace {
void FindBestBlockEntropyModel(PassesEncoderState& enc_state) {
  if (enc_state.cparams.decoding_speed_tier >= 1) {
    static constexpr uint8_t kSimpleCtxMap[] = {
        // Cluster all blocks together
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  //
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  //
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  //
    };
    static_assert(
        3 * kNumOrders == sizeof(kSimpleCtxMap) / sizeof *kSimpleCtxMap,
        "Update simple context map");

    auto bcm = enc_state.shared.block_ctx_map;
    bcm.ctx_map.assign(std::begin(kSimpleCtxMap), std::end(kSimpleCtxMap));
    bcm.num_ctxs = 2;
    bcm.num_dc_ctxs = 1;
    return;
  }
  if (enc_state.cparams.speed_tier >= SpeedTier::kFalcon) {
    return;
  }
  const ImageI& rqf = enc_state.shared.raw_quant_field;
  // No need to change context modeling for small images.
  size_t tot = rqf.xsize() * rqf.ysize();
  size_t size_for_ctx_model =
      (1 << 10) * enc_state.cparams.butteraugli_distance;
  if (tot < size_for_ctx_model) return;

  struct OccCounters {
    // count the occurrences of each qf value and each strategy type.
    OccCounters(const ImageI& rqf, const AcStrategyImage& ac_strategy) {
      for (size_t y = 0; y < rqf.ysize(); y++) {
        const int32_t* qf_row = rqf.Row(y);
        AcStrategyRow acs_row = ac_strategy.ConstRow(y);
        for (size_t x = 0; x < rqf.xsize(); x++) {
          int ord = kStrategyOrder[acs_row[x].RawStrategy()];
          int qf = qf_row[x] - 1;
          qf_counts[qf]++;
          qf_ord_counts[ord][qf]++;
          ord_counts[ord]++;
        }
      }
    }

    size_t qf_counts[256] = {};
    size_t qf_ord_counts[kNumOrders][256] = {};
    size_t ord_counts[kNumOrders] = {};
  };
  // The OccCounters struct is too big to allocate on the stack.
  std::unique_ptr<OccCounters> counters(
      new OccCounters(rqf, enc_state.shared.ac_strategy));

  // Splitting the context model according to the quantization field seems to
  // mostly benefit only large images.
  size_t size_for_qf_split = (1 << 13) * enc_state.cparams.butteraugli_distance;
  size_t num_qf_segments = tot < size_for_qf_split ? 1 : 2;
  std::vector<uint32_t>& qft = enc_state.shared.block_ctx_map.qf_thresholds;
  qft.clear();
  // Divide the quant field in up to num_qf_segments segments.
  size_t cumsum = 0;
  size_t next = 1;
  size_t last_cut = 256;
  size_t cut = tot * next / num_qf_segments;
  for (uint32_t j = 0; j < 256; j++) {
    cumsum += counters->qf_counts[j];
    if (cumsum > cut) {
      if (j != 0) {
        qft.push_back(j);
      }
      last_cut = j;
      while (cumsum > cut) {
        next++;
        cut = tot * next / num_qf_segments;
      }
    } else if (next > qft.size() + 1) {
      if (j - 1 == last_cut && j != 0) {
        qft.push_back(j);
      }
    }
  }

  // Count the occurrences of each segment.
  std::vector<size_t> counts(kNumOrders * (qft.size() + 1));
  size_t qft_pos = 0;
  for (size_t j = 0; j < 256; j++) {
    if (qft_pos < qft.size() && j == qft[qft_pos]) {
      qft_pos++;
    }
    for (size_t i = 0; i < kNumOrders; i++) {
      counts[qft_pos + i * (qft.size() + 1)] += counters->qf_ord_counts[i][j];
    }
  }

  // Repeatedly merge the lowest-count pair.
  std::vector<uint8_t> remap((qft.size() + 1) * kNumOrders);
  std::iota(remap.begin(), remap.end(), 0);
  std::vector<uint8_t> clusters(remap);
  size_t nb_clusters = Clamp1((int)(tot / size_for_ctx_model / 2), 2, 9);
  size_t nb_clusters_chroma = Clamp1((int)(tot / size_for_ctx_model / 3), 1, 5);
  // This is O(n^2 log n), but n is small.
  while (clusters.size() > nb_clusters) {
    std::sort(clusters.begin(), clusters.end(),
              [&](int a, int b) { return counts[a] > counts[b]; });
    counts[clusters[clusters.size() - 2]] += counts[clusters.back()];
    counts[clusters.back()] = 0;
    remap[clusters.back()] = clusters[clusters.size() - 2];
    clusters.pop_back();
  }
  for (size_t i = 0; i < remap.size(); i++) {
    while (remap[remap[i]] != remap[i]) {
      remap[i] = remap[remap[i]];
    }
  }
  // Relabel starting from 0.
  std::vector<uint8_t> remap_remap(remap.size(), remap.size());
  size_t num = 0;
  for (size_t i = 0; i < remap.size(); i++) {
    if (remap_remap[remap[i]] == remap.size()) {
      remap_remap[remap[i]] = num++;
    }
    remap[i] = remap_remap[remap[i]];
  }
  // Write the block context map.
  auto& ctx_map = enc_state.shared.block_ctx_map.ctx_map;
  ctx_map = remap;
  ctx_map.resize(remap.size() * 3);
  // for chroma, only use up to nb_clusters_chroma separate block contexts
  // (those for the biggest clusters)
  for (size_t i = remap.size(); i < remap.size() * 3; i++) {
    ctx_map[i] = num + Clamp1((int)remap[i % remap.size()], 0,
                              (int)nb_clusters_chroma - 1);
  }
  enc_state.shared.block_ctx_map.num_ctxs =
      *std::max_element(ctx_map.begin(), ctx_map.end()) + 1;
}

}  // namespace

void FindBestDequantMatrices(const CompressParams& cparams,
                             const Image3F& opsin,
                             ModularFrameEncoder* modular_frame_encoder,
                             DequantMatrices* dequant_matrices) {
  // TODO(veluca): quant matrices for no-gaborish.
  // TODO(veluca): heuristics for in-bitstream quant tables.
  *dequant_matrices = DequantMatrices();
  if (cparams.max_error_mode) {
    // Set numerators of all quantization matrices to constant values.
    float weights[3][1] = {{1.0f / cparams.max_error[0]},
                           {1.0f / cparams.max_error[1]},
                           {1.0f / cparams.max_error[2]}};
    DctQuantWeightParams dct_params(weights);
    std::vector<QuantEncoding> encodings(DequantMatrices::kNum,
                                         QuantEncoding::DCT(dct_params));
    DequantMatricesSetCustom(dequant_matrices, encodings,
                             modular_frame_encoder);
    float dc_weights[3] = {1.0f / cparams.max_error[0],
                           1.0f / cparams.max_error[1],
                           1.0f / cparams.max_error[2]};
    DequantMatricesSetCustomDC(dequant_matrices, dc_weights);
  }
}

bool DefaultEncoderHeuristics::HandlesColorConversion(
    const CompressParams& cparams, const ImageBundle& ib) {
  return cparams.noise != Override::kOn && cparams.patches != Override::kOn &&
         cparams.speed_tier >= SpeedTier::kWombat && cparams.resampling == 1 &&
         cparams.color_transform == ColorTransform::kXYB &&
         !cparams.modular_mode && !ib.HasAlpha();
}

namespace {

void StoreMin2(const float v, float& min1, float& min2) {
  if (v < min2) {
    if (v < min1) {
      min2 = min1;
      min1 = v;
    } else {
      min2 = v;
    }
  }
}

void CreateMask(const ImageF& image, ImageF& mask) {
  for (size_t y = 0; y < image.ysize(); y++) {
    auto* row_n = y > 0 ? image.Row(y - 1) : image.Row(y);
    auto* row_in = image.Row(y);
    auto* row_s = y + 1 < image.ysize() ? image.Row(y + 1) : image.Row(y);
    auto* row_out = mask.Row(y);
    for (size_t x = 0; x < image.xsize(); x++) {
      // Center, west, east, north, south values and their absolute difference
      float c = row_in[x];
      float w = x > 0 ? row_in[x - 1] : row_in[x];
      float e = x + 1 < image.xsize() ? row_in[x + 1] : row_in[x];
      float n = row_n[x];
      float s = row_s[x];
      float dw = std::abs(c - w);
      float de = std::abs(c - e);
      float dn = std::abs(c - n);
      float ds = std::abs(c - s);
      float min = std::numeric_limits<float>::max();
      float min2 = std::numeric_limits<float>::max();
      StoreMin2(dw, min, min2);
      StoreMin2(de, min, min2);
      StoreMin2(dn, min, min2);
      StoreMin2(ds, min, min2);
      row_out[x] = min2;
    }
  }
}

// Downsamples the image by a factor of 2 with a kernel that's sharper than
// the standard 2x2 box kernel used by DownsampleImage.
// The kernel is optimized against the result of the 2x2 upsampling kernel used
// by the decoder. Ringing is slightly reduced by clamping the values of the
// resulting pixels within certain bounds of a small region in the original
// image.
void DownsampleImage2_Sharper(const ImageF& input, ImageF* output) {
  const int64_t kernelx = 12;
  const int64_t kernely = 12;

  static const float kernel[144] = {
      -0.000314256996835, -0.000314256996835, -0.000897597057705,
      -0.000562751488849, -0.000176807273646, 0.001864627368902,
      0.001864627368902,  -0.000176807273646, -0.000562751488849,
      -0.000897597057705, -0.000314256996835, -0.000314256996835,
      -0.000314256996835, -0.001527942804748, -0.000121760530512,
      0.000191123989093,  0.010193185932466,  0.058637519197110,
      0.058637519197110,  0.010193185932466,  0.000191123989093,
      -0.000121760530512, -0.001527942804748, -0.000314256996835,
      -0.000897597057705, -0.000121760530512, 0.000946363683751,
      0.007113577630288,  0.000437956841058,  -0.000372823835211,
      -0.000372823835211, 0.000437956841058,  0.007113577630288,
      0.000946363683751,  -0.000121760530512, -0.000897597057705,
      -0.000562751488849, 0.000191123989093,  0.007113577630288,
      0.044592622228814,  0.000222278879007,  -0.162864473015945,
      -0.162864473015945, 0.000222278879007,  0.044592622228814,
      0.007113577630288,  0.000191123989093,  -0.000562751488849,
      -0.000176807273646, 0.010193185932466,  0.000437956841058,
      0.000222278879007,  -0.000913092543974, -0.017071696107902,
      -0.017071696107902, -0.000913092543974, 0.000222278879007,
      0.000437956841058,  0.010193185932466,  -0.000176807273646,
      0.001864627368902,  0.058637519197110,  -0.000372823835211,
      -0.162864473015945, -0.017071696107902, 0.414660099370354,
      0.414660099370354,  -0.017071696107902, -0.162864473015945,
      -0.000372823835211, 0.058637519197110,  0.001864627368902,
      0.001864627368902,  0.058637519197110,  -0.000372823835211,
      -0.162864473015945, -0.017071696107902, 0.414660099370354,
      0.414660099370354,  -0.017071696107902, -0.162864473015945,
      -0.000372823835211, 0.058637519197110,  0.001864627368902,
      -0.000176807273646, 0.010193185932466,  0.000437956841058,
      0.000222278879007,  -0.000913092543974, -0.017071696107902,
      -0.017071696107902, -0.000913092543974, 0.000222278879007,
      0.000437956841058,  0.010193185932466,  -0.000176807273646,
      -0.000562751488849, 0.000191123989093,  0.007113577630288,
      0.044592622228814,  0.000222278879007,  -0.162864473015945,
      -0.162864473015945, 0.000222278879007,  0.044592622228814,
      0.007113577630288,  0.000191123989093,  -0.000562751488849,
      -0.000897597057705, -0.000121760530512, 0.000946363683751,
      0.007113577630288,  0.000437956841058,  -0.000372823835211,
      -0.000372823835211, 0.000437956841058,  0.007113577630288,
      0.000946363683751,  -0.000121760530512, -0.000897597057705,
      -0.000314256996835, -0.001527942804748, -0.000121760530512,
      0.000191123989093,  0.010193185932466,  0.058637519197110,
      0.058637519197110,  0.010193185932466,  0.000191123989093,
      -0.000121760530512, -0.001527942804748, -0.000314256996835,
      -0.000314256996835, -0.000314256996835, -0.000897597057705,
      -0.000562751488849, -0.000176807273646, 0.001864627368902,
      0.001864627368902,  -0.000176807273646, -0.000562751488849,
      -0.000897597057705, -0.000314256996835, -0.000314256996835};

  int64_t xsize = input.xsize();
  int64_t ysize = input.ysize();

  ImageF box_downsample(xsize, ysize);
  CopyImageTo(input, &box_downsample);
  DownsampleImage(&box_downsample, 2);

  ImageF mask(box_downsample.xsize(), box_downsample.ysize());
  CreateMask(box_downsample, mask);

  for (size_t y = 0; y < output->ysize(); y++) {
    float* row_out = output->Row(y);
    const float* row_in[kernely];
    const float* row_mask = mask.Row(y);
    // get the rows in the support
    for (size_t ky = 0; ky < kernely; ky++) {
      int64_t iy = y * 2 + ky - (kernely - 1) / 2;
      if (iy < 0) iy = 0;
      if (iy >= ysize) iy = ysize - 1;
      row_in[ky] = input.Row(iy);
    }

    for (size_t x = 0; x < output->xsize(); x++) {
      // get min and max values of the original image in the support
      float min = std::numeric_limits<float>::max();
      float max = std::numeric_limits<float>::min();
      // kernelx - R and kernely - R are the radius of a rectangular region in
      // which the values of a pixel are bounded to reduce ringing.
      static constexpr int64_t R = 5;
      for (int64_t ky = R; ky + R < kernely; ky++) {
        for (int64_t kx = R; kx + R < kernelx; kx++) {
          int64_t ix = x * 2 + kx - (kernelx - 1) / 2;
          if (ix < 0) ix = 0;
          if (ix >= xsize) ix = xsize - 1;
          min = std::min<float>(min, row_in[ky][ix]);
          max = std::max<float>(max, row_in[ky][ix]);
        }
      }

      float sum = 0;
      for (int64_t ky = 0; ky < kernely; ky++) {
        for (int64_t kx = 0; kx < kernelx; kx++) {
          int64_t ix = x * 2 + kx - (kernelx - 1) / 2;
          if (ix < 0) ix = 0;
          if (ix >= xsize) ix = xsize - 1;
          sum += row_in[ky][ix] * kernel[ky * kernelx + kx];
        }
      }

      row_out[x] = sum;

      // Clamp the pixel within the value  of a small area to prevent ringning.
      // The mask determines how much to clamp, clamp more to reduce more
      // ringing in smooth areas, clamp less in noisy areas to get more
      // sharpness. Higher mask_multiplier gives less clamping, so less
      // ringing reduction.
      const constexpr float mask_multiplier = 1;
      float a = row_mask[x] * mask_multiplier;
      float clip_min = min - a;
      float clip_max = max + a;
      if (row_out[x] < clip_min) {
        row_out[x] = clip_min;
      } else if (row_out[x] > clip_max) {
        row_out[x] = clip_max;
      }
    }
  }
}

void DownsampleImage2_Sharper(Image3F* opsin) {
  // Allocate extra space to avoid a reallocation when padding.
  Image3F downsampled(DivCeil(opsin->xsize(), 2) + kBlockDim,
                      DivCeil(opsin->ysize(), 2) + kBlockDim);
  downsampled.ShrinkTo(downsampled.xsize() - kBlockDim,
                       downsampled.ysize() - kBlockDim);

  for (size_t c = 0; c < 3; c++) {
    DownsampleImage2_Sharper(opsin->Plane(c), &downsampled.Plane(c));
  }
  *opsin = std::move(downsampled);
}

// The default upsampling kernels used by Upsampler in the decoder.
static const constexpr int64_t kSize = 5;

static const float kernel00[25] = {
    -0.01716200f, -0.03452303f, -0.04022174f, -0.02921014f, -0.00624645f,
    -0.03452303f, 0.14111091f,  0.28896755f,  0.00278718f,  -0.01610267f,
    -0.04022174f, 0.28896755f,  0.56661550f,  0.03777607f,  -0.01986694f,
    -0.02921014f, 0.00278718f,  0.03777607f,  -0.03144731f, -0.01185068f,
    -0.00624645f, -0.01610267f, -0.01986694f, -0.01185068f, -0.00213539f,
};
static const float kernel01[25] = {
    -0.00624645f, -0.01610267f, -0.01986694f, -0.01185068f, -0.00213539f,
    -0.02921014f, 0.00278718f,  0.03777607f,  -0.03144731f, -0.01185068f,
    -0.04022174f, 0.28896755f,  0.56661550f,  0.03777607f,  -0.01986694f,
    -0.03452303f, 0.14111091f,  0.28896755f,  0.00278718f,  -0.01610267f,
    -0.01716200f, -0.03452303f, -0.04022174f, -0.02921014f, -0.00624645f,
};
static const float kernel10[25] = {
    -0.00624645f, -0.02921014f, -0.04022174f, -0.03452303f, -0.01716200f,
    -0.01610267f, 0.00278718f,  0.28896755f,  0.14111091f,  -0.03452303f,
    -0.01986694f, 0.03777607f,  0.56661550f,  0.28896755f,  -0.04022174f,
    -0.01185068f, -0.03144731f, 0.03777607f,  0.00278718f,  -0.02921014f,
    -0.00213539f, -0.01185068f, -0.01986694f, -0.01610267f, -0.00624645f,
};
static const float kernel11[25] = {
    -0.00213539f, -0.01185068f, -0.01986694f, -0.01610267f, -0.00624645f,
    -0.01185068f, -0.03144731f, 0.03777607f,  0.00278718f,  -0.02921014f,
    -0.01986694f, 0.03777607f,  0.56661550f,  0.28896755f,  -0.04022174f,
    -0.01610267f, 0.00278718f,  0.28896755f,  0.14111091f,  -0.03452303f,
    -0.00624645f, -0.02921014f, -0.04022174f, -0.03452303f, -0.01716200f,
};

// Does exactly the same as the Upsampler in dec_upsampler for 2x2 pixels, with
// default CustomTransformData.
// TODO(lode): use Upsampler instead. However, it requires pre-initialization
// and padding on the left side of the image which requires refactoring the
// other code using this.
static void UpsampleImage(const ImageF& input, ImageF* output) {
  int64_t xsize = input.xsize();
  int64_t ysize = input.ysize();
  int64_t xsize2 = output->xsize();
  int64_t ysize2 = output->ysize();
  for (int64_t y = 0; y < ysize2; y++) {
    for (int64_t x = 0; x < xsize2; x++) {
      auto kernel = kernel00;
      if ((x & 1) && (y & 1)) {
        kernel = kernel11;
      } else if (x & 1) {
        kernel = kernel10;
      } else if (y & 1) {
        kernel = kernel01;
      }
      float sum = 0;
      int64_t x2 = x / 2;
      int64_t y2 = y / 2;

      // get min and max values of the original image in the support
      float min = std::numeric_limits<float>::max();
      float max = std::numeric_limits<float>::min();

      for (int64_t ky = 0; ky < kSize; ky++) {
        for (int64_t kx = 0; kx < kSize; kx++) {
          int64_t xi = x2 - kSize / 2 + kx;
          int64_t yi = y2 - kSize / 2 + ky;
          if (xi < 0) xi = 0;
          if (xi >= xsize) xi = input.xsize() - 1;
          if (yi < 0) yi = 0;
          if (yi >= ysize) yi = input.ysize() - 1;
          min = std::min<float>(min, input.Row(yi)[xi]);
          max = std::max<float>(max, input.Row(yi)[xi]);
        }
      }

      for (int64_t ky = 0; ky < kSize; ky++) {
        for (int64_t kx = 0; kx < kSize; kx++) {
          int64_t xi = x2 - kSize / 2 + kx;
          int64_t yi = y2 - kSize / 2 + ky;
          if (xi < 0) xi = 0;
          if (xi >= xsize) xi = input.xsize() - 1;
          if (yi < 0) yi = 0;
          if (yi >= ysize) yi = input.ysize() - 1;
          sum += input.Row(yi)[xi] * kernel[ky * kSize + kx];
        }
      }
      output->Row(y)[x] = sum;
      if (output->Row(y)[x] < min) output->Row(y)[x] = min;
      if (output->Row(y)[x] > max) output->Row(y)[x] = max;
    }
  }
}

// Returns the derivative of Upsampler, with respect to input pixel x2, y2, to
// output pixel x, y (ignoring the clamping).
float UpsamplerDeriv(int64_t x2, int64_t y2, int64_t x, int64_t y) {
  auto kernel = kernel00;
  if ((x & 1) && (y & 1)) {
    kernel = kernel11;
  } else if (x & 1) {
    kernel = kernel10;
  } else if (y & 1) {
    kernel = kernel01;
  }

  int64_t ix = x / 2;
  int64_t iy = y / 2;
  int64_t kx = x2 - ix + kSize / 2;
  int64_t ky = y2 - iy + kSize / 2;

  // This should not happen.
  if (kx < 0 || kx >= kSize || ky < 0 || ky >= kSize) return 0;

  return kernel[ky * kSize + kx];
}

// Apply the derivative of the Upsampler to the input, reversing the effect of
// its coefficients. The output image is 2x2 times smaller than the input.
void AntiUpsample(const ImageF& input, ImageF* d) {
  int64_t xsize = input.xsize();
  int64_t ysize = input.ysize();
  int64_t xsize2 = d->xsize();
  int64_t ysize2 = d->ysize();
  int64_t k0 = kSize - 1;
  int64_t k1 = kSize;
  for (int64_t y2 = 0; y2 < ysize2; ++y2) {
    auto* row = d->Row(y2);
    for (int64_t x2 = 0; x2 < xsize2; ++x2) {
      int64_t x0 = x2 * 2 - k0;
      if (x0 < 0) x0 = 0;
      int64_t x1 = x2 * 2 + k1 + 1;
      if (x1 > xsize) x1 = xsize;
      int64_t y0 = y2 * 2 - k0;
      if (y0 < 0) y0 = 0;
      int64_t y1 = y2 * 2 + k1 + 1;
      if (y1 > ysize) y1 = ysize;

      float sum = 0;
      for (int64_t y = y0; y < y1; ++y) {
        const auto* row_in = input.Row(y);
        for (int64_t x = x0; x < x1; ++x) {
          double deriv = UpsamplerDeriv(x2, y2, x, y);
          sum += deriv * row_in[x];
        }
      }
      row[x2] = sum;
    }
  }
}

// Element-wise multiplies two images.
template <typename T>
void ElwiseMul(const Plane<T>& image1, const Plane<T>& image2, Plane<T>* out) {
  const size_t xsize = image1.xsize();
  const size_t ysize = image1.ysize();
  JXL_CHECK(xsize == image2.xsize());
  JXL_CHECK(ysize == image2.ysize());
  JXL_CHECK(xsize == out->xsize());
  JXL_CHECK(ysize == out->ysize());
  for (size_t y = 0; y < ysize; ++y) {
    const T* const JXL_RESTRICT row1 = image1.Row(y);
    const T* const JXL_RESTRICT row2 = image2.Row(y);
    T* const JXL_RESTRICT row_out = out->Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      row_out[x] = row1[x] * row2[x];
    }
  }
}

// Element-wise divides two images.
template <typename T>
void ElwiseDiv(const Plane<T>& image1, const Plane<T>& image2, Plane<T>* out) {
  const size_t xsize = image1.xsize();
  const size_t ysize = image1.ysize();
  JXL_CHECK(xsize == image2.xsize());
  JXL_CHECK(ysize == image2.ysize());
  JXL_CHECK(xsize == out->xsize());
  JXL_CHECK(ysize == out->ysize());
  for (size_t y = 0; y < ysize; ++y) {
    const T* const JXL_RESTRICT row1 = image1.Row(y);
    const T* const JXL_RESTRICT row2 = image2.Row(y);
    T* const JXL_RESTRICT row_out = out->Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      row_out[x] = row1[x] / row2[x];
    }
  }
}

void ReduceRinging(const ImageF& initial, const ImageF& mask, ImageF& down) {
  int64_t xsize2 = down.xsize();
  int64_t ysize2 = down.ysize();

  for (size_t y = 0; y < down.ysize(); y++) {
    const float* row_mask = mask.Row(y);
    float* row_out = down.Row(y);
    for (size_t x = 0; x < down.xsize(); x++) {
      float v = down.Row(y)[x];
      float min = initial.Row(y)[x];
      float max = initial.Row(y)[x];
      for (int64_t yi = -1; yi < 2; yi++) {
        for (int64_t xi = -1; xi < 2; xi++) {
          int64_t x2 = (int64_t)x + xi;
          int64_t y2 = (int64_t)y + yi;
          if (x2 < 0 || y2 < 0 || x2 >= (int64_t)xsize2 ||
              y2 >= (int64_t)ysize2)
            continue;
          min = std::min<float>(min, initial.Row(y2)[x2]);
          max = std::max<float>(max, initial.Row(y2)[x2]);
        }
      }

      row_out[x] = v;

      // Clamp the pixel within the value  of a small area to prevent ringning.
      // The mask determines how much to clamp, clamp more to reduce more
      // ringing in smooth areas, clamp less in noisy areas to get more
      // sharpness. Higher mask_multiplier gives less clamping, so less
      // ringing reduction.
      const constexpr float mask_multiplier = 2;
      float a = row_mask[x] * mask_multiplier;
      float clip_min = min - a;
      float clip_max = max + a;
      if (row_out[x] < clip_min) row_out[x] = clip_min;
      if (row_out[x] > clip_max) row_out[x] = clip_max;
    }
  }
}

// TODO(lode): move this to a separate file enc_downsample.cc
void DownsampleImage2_Iterative(const ImageF& orig, ImageF* output) {
  int64_t xsize = orig.xsize();
  int64_t ysize = orig.ysize();
  int64_t xsize2 = DivCeil(orig.xsize(), 2);
  int64_t ysize2 = DivCeil(orig.ysize(), 2);

  ImageF box_downsample(xsize, ysize);
  CopyImageTo(orig, &box_downsample);
  DownsampleImage(&box_downsample, 2);
  ImageF mask(box_downsample.xsize(), box_downsample.ysize());
  CreateMask(box_downsample, mask);

  output->ShrinkTo(xsize2, ysize2);

  // Initial result image using the sharper downsampling.
  // Allocate extra space to avoid a reallocation when padding.
  ImageF initial(DivCeil(orig.xsize(), 2) + kBlockDim,
                 DivCeil(orig.ysize(), 2) + kBlockDim);
  initial.ShrinkTo(initial.xsize() - kBlockDim, initial.ysize() - kBlockDim);
  DownsampleImage2_Sharper(orig, &initial);

  ImageF down(initial.xsize(), initial.ysize());
  CopyImageTo(initial, &down);
  ImageF up(xsize, ysize);
  ImageF corr(xsize, ysize);
  ImageF corr2(xsize2, ysize2);

  // In the weights map, relatively higher values will allow less ringing but
  // also less sharpness. With all constant values, it optimizes equally
  // everywhere. Even in this case, the weights2 computed from
  // this is still used and differs at the borders of the image.
  // TODO(lode): Make use of the weights field for anti-ringing and clamping,
  // the values are all set to 1 for now, but it is intended to be used for
  // reducing ringing based on the mask, and taking clamping into account.
  ImageF weights(xsize, ysize);
  for (size_t y = 0; y < weights.ysize(); y++) {
    auto* row = weights.Row(y);
    for (size_t x = 0; x < weights.xsize(); x++) {
      row[x] = 1;
    }
  }
  ImageF weights2(xsize2, ysize2);
  AntiUpsample(weights, &weights2);

  const size_t num_it = 3;
  for (size_t it = 0; it < num_it; ++it) {
    UpsampleImage(down, &up);
    corr = LinComb<float>(1, orig, -1, up);
    ElwiseMul(corr, weights, &corr);
    AntiUpsample(corr, &corr2);
    ElwiseDiv(corr2, weights2, &corr2);

    down = LinComb<float>(1, down, 1, corr2);
  }

  ReduceRinging(initial, mask, down);

  // can't just use CopyImage, because the output image was prepared with
  // padding.
  for (size_t y = 0; y < down.ysize(); y++) {
    for (size_t x = 0; x < down.xsize(); x++) {
      float v = down.Row(y)[x];
      output->Row(y)[x] = v;
    }
  }
}

void DownsampleImage2_Iterative(Image3F* opsin) {
  // Allocate extra space to avoid a reallocation when padding.
  Image3F downsampled(DivCeil(opsin->xsize(), 2) + kBlockDim,
                      DivCeil(opsin->ysize(), 2) + kBlockDim);
  downsampled.ShrinkTo(downsampled.xsize() - kBlockDim,
                       downsampled.ysize() - kBlockDim);

  Image3F rgb(opsin->xsize(), opsin->ysize());
  OpsinParams opsin_params;  // TODO: use the ones that are actually used
  opsin_params.Init(kDefaultIntensityTarget);
  OpsinToLinear(*opsin, Rect(rgb), nullptr, &rgb, opsin_params);

  ImageF mask(opsin->xsize(), opsin->ysize());
  ButteraugliParams butter_params;
  ButteraugliComparator butter(rgb, butter_params);
  butter.Mask(&mask);
  ImageF mask_fuzzy(opsin->xsize(), opsin->ysize());

  for (size_t c = 0; c < 3; c++) {
    DownsampleImage2_Iterative(opsin->Plane(c), &downsampled.Plane(c));
  }
  *opsin = std::move(downsampled);
}
}  // namespace

Status DefaultEncoderHeuristics::LossyFrameHeuristics(
    PassesEncoderState* enc_state, ModularFrameEncoder* modular_frame_encoder,
    const ImageBundle* original_pixels, Image3F* opsin,
    const JxlCmsInterface& cms, ThreadPool* pool, AuxOut* aux_out) {
  CompressParams& cparams = enc_state->cparams;
  PassesSharedState& shared = enc_state->shared;

  // Compute parameters for noise synthesis.
  if (shared.frame_header.flags & FrameHeader::kNoise) {
    if (cparams.photon_noise_iso == 0) {
      // Don't start at zero amplitude since adding noise is expensive -- it
      // significantly slows down decoding, and this is unlikely to
      // completely go away even with advanced optimizations. After the
      // kNoiseModelingRampUpDistanceRange we have reached the full level,
      // i.e. noise is no longer represented by the compressed image, so we
      // can add full noise by the noise modeling itself.
      static const float kNoiseModelingRampUpDistanceRange = 0.6;
      static const float kNoiseLevelAtStartOfRampUp = 0.25;
      static const float kNoiseRampupStart = 1.0;
      // TODO(user) test and properly select quality_coef with smooth
      // filter
      float quality_coef = 1.0f;
      const float rampup = (cparams.butteraugli_distance - kNoiseRampupStart) /
                           kNoiseModelingRampUpDistanceRange;
      if (rampup < 1.0f) {
        quality_coef = kNoiseLevelAtStartOfRampUp +
                       (1.0f - kNoiseLevelAtStartOfRampUp) * rampup;
      }
      if (rampup < 0.0f) {
        quality_coef = kNoiseRampupStart;
      }
      if (!GetNoiseParameter(*opsin, &shared.image_features.noise_params,
                             quality_coef)) {
        shared.frame_header.flags &= ~FrameHeader::kNoise;
      }
    }
  }
  if (enc_state->shared.frame_header.upsampling != 1 &&
      !cparams.already_downsampled) {
    // In VarDCT mode, LossyFrameHeuristics takes care of running downsampling
    // after noise, if necessary.
    if (cparams.resampling == 2) {
      // TODO(lode): use the regular DownsampleImage, or adapt to the custom
      // coefficients, if there is are custom upscaling coefficients in
      // CustomTransformData
      if (cparams.speed_tier <= SpeedTier::kSquirrel) {
        // TODO(lode): DownsampleImage2_Iterative is currently too slow to
        // be used for squirrel, make it faster, and / or enable it only for
        // kitten.
        DownsampleImage2_Iterative(opsin);
      } else {
        DownsampleImage2_Sharper(opsin);
      }
    } else {
      DownsampleImage(opsin, cparams.resampling);
    }
    PadImageToBlockMultipleInPlace(opsin);
  }

  if (cparams.butteraugli_distance < 0) {
    return JXL_FAILURE("Expected non-negative distance");
  }

  // Find and subtract splines.
  if (cparams.speed_tier <= SpeedTier::kSquirrel) {
    // If we do already have them, they were passed upstream to EncodeFile.
    if (!shared.image_features.splines.HasAny()) {
      shared.image_features.splines = FindSplines(*opsin);
    }
    JXL_RETURN_IF_ERROR(shared.image_features.splines.InitializeDrawCache(
        opsin->xsize(), opsin->ysize(), shared.cmap));
    shared.image_features.splines.SubtractFrom(opsin);
  }

  // Find and subtract patches/dots.
  if (ApplyOverride(cparams.patches,
                    cparams.speed_tier <= SpeedTier::kSquirrel)) {
    FindBestPatchDictionary(*opsin, enc_state, cms, pool, aux_out);
    PatchDictionaryEncoder::SubtractFrom(shared.image_features.patches, opsin);
  }

  static const float kAcQuant = 0.79f;
  const float quant_dc = InitialQuantDC(cparams.butteraugli_distance);
  Quantizer& quantizer = enc_state->shared.quantizer;
  // We don't know the quant field yet, but for computing the global scale
  // assuming that it will be the same as for Falcon mode is good enough.
  quantizer.ComputeGlobalScaleAndQuant(
      quant_dc, kAcQuant / cparams.butteraugli_distance, 0);

  // TODO(veluca): we can now run all the code from here to FindBestQuantizer
  // (excluded) one rect at a time. Do that.

  // Dependency graph:
  //
  // input: either XYB or input image
  //
  // input image -> XYB [optional]
  // XYB -> initial quant field
  // XYB -> Gaborished XYB
  // Gaborished XYB -> CfL1
  // initial quant field, Gaborished XYB, CfL1 -> ACS
  // initial quant field, ACS, Gaborished XYB -> EPF control field
  // initial quant field -> adjusted initial quant field
  // adjusted initial quant field, ACS -> raw quant field
  // raw quant field, ACS, Gaborished XYB -> CfL2
  //
  // output: Gaborished XYB, CfL, ACS, raw quant field, EPF control field.

  ArControlFieldHeuristics ar_heuristics;
  AcStrategyHeuristics acs_heuristics;
  CfLHeuristics cfl_heuristics;

  if (!opsin->xsize()) {
    JXL_ASSERT(HandlesColorConversion(cparams, *original_pixels));
    *opsin = Image3F(RoundUpToBlockDim(original_pixels->xsize()),
                     RoundUpToBlockDim(original_pixels->ysize()));
    opsin->ShrinkTo(original_pixels->xsize(), original_pixels->ysize());
    ToXYB(*original_pixels, pool, opsin, cms, /*linear=*/nullptr);
    PadImageToBlockMultipleInPlace(opsin);
  }

  // Compute an initial estimate of the quantization field.
  // Call InitialQuantField only in Hare mode or slower. Otherwise, rely
  // on simple heuristics in FindBestAcStrategy, or set a constant for Falcon
  // mode.
  if (cparams.speed_tier > SpeedTier::kHare) {
    enc_state->initial_quant_field =
        ImageF(shared.frame_dim.xsize_blocks, shared.frame_dim.ysize_blocks);
    enc_state->initial_quant_masking =
        ImageF(shared.frame_dim.xsize_blocks, shared.frame_dim.ysize_blocks);
    float q = kAcQuant / cparams.butteraugli_distance;
    FillImage(q, &enc_state->initial_quant_field);
    FillImage(1.0f / (q + 0.001f), &enc_state->initial_quant_masking);
  } else {
    // Call this here, as it relies on pre-gaborish values.
    float butteraugli_distance_for_iqf = cparams.butteraugli_distance;
    if (!shared.frame_header.loop_filter.gab) {
      butteraugli_distance_for_iqf *= 0.73f;
    }
    enc_state->initial_quant_field = InitialQuantField(
        butteraugli_distance_for_iqf, *opsin, shared.frame_dim, pool, 1.0f,
        &enc_state->initial_quant_masking);
    quantizer.SetQuantField(quant_dc, enc_state->initial_quant_field, nullptr);
  }

  // TODO(veluca): do something about animations.

  // Apply inverse-gaborish.
  if (shared.frame_header.loop_filter.gab) {
    // Unsure why better to do some more gaborish on X and B than Y.
    float weight[3] = {
        1.0036278514398933f,
        0.99406123118127299f,
        0.99719338015886894f,
    };
    GaborishInverse(opsin, weight, pool);
  }

  FindBestDequantMatrices(cparams, *opsin, modular_frame_encoder,
                          &enc_state->shared.matrices);

  cfl_heuristics.Init(*opsin);
  acs_heuristics.Init(*opsin, enc_state);

  auto process_tile = [&](const uint32_t tid, const size_t thread) {
    size_t n_enc_tiles =
        DivCeil(enc_state->shared.frame_dim.xsize_blocks, kEncTileDimInBlocks);
    size_t tx = tid % n_enc_tiles;
    size_t ty = tid / n_enc_tiles;
    size_t by0 = ty * kEncTileDimInBlocks;
    size_t by1 = std::min((ty + 1) * kEncTileDimInBlocks,
                          enc_state->shared.frame_dim.ysize_blocks);
    size_t bx0 = tx * kEncTileDimInBlocks;
    size_t bx1 = std::min((tx + 1) * kEncTileDimInBlocks,
                          enc_state->shared.frame_dim.xsize_blocks);
    Rect r(bx0, by0, bx1 - bx0, by1 - by0);

    // For speeds up to Wombat, we only compute the color correlation map
    // once we know the transform type and the quantization map.
    if (cparams.speed_tier <= SpeedTier::kSquirrel) {
      cfl_heuristics.ComputeTile(r, *opsin, enc_state->shared.matrices,
                                 /*ac_strategy=*/nullptr,
                                 /*raw_quant_field=*/nullptr,
                                 /*quantizer=*/nullptr, /*fast=*/false, thread,
                                 &enc_state->shared.cmap);
    }

    // Choose block sizes.
    acs_heuristics.ProcessRect(r);

    // Choose amount of post-processing smoothing.
    // TODO(veluca): should this go *after* AdjustQuantField?
    ar_heuristics.RunRect(r, *opsin, enc_state, thread);

    // Always set the initial quant field, so we can compute the CfL map with
    // more accuracy. The initial quant field might change in slower modes, but
    // adjusting the quant field with butteraugli when all the other encoding
    // parameters are fixed is likely a more reliable choice anyway.
    AdjustQuantField(enc_state->shared.ac_strategy, r,
                     cparams.butteraugli_distance,
                     &enc_state->initial_quant_field);
    quantizer.SetQuantFieldRect(enc_state->initial_quant_field, r,
                                &enc_state->shared.raw_quant_field);

    // Compute a non-default CfL map if we are at Hare speed, or slower.
    if (cparams.speed_tier <= SpeedTier::kHare) {
      cfl_heuristics.ComputeTile(
          r, *opsin, enc_state->shared.matrices, &enc_state->shared.ac_strategy,
          &enc_state->shared.raw_quant_field, &enc_state->shared.quantizer,
          /*fast=*/cparams.speed_tier >= SpeedTier::kWombat, thread,
          &enc_state->shared.cmap);
    }
  };
  JXL_RETURN_IF_ERROR(RunOnPool(
      pool, 0,
      DivCeil(enc_state->shared.frame_dim.xsize_blocks, kEncTileDimInBlocks) *
          DivCeil(enc_state->shared.frame_dim.ysize_blocks,
                  kEncTileDimInBlocks),
      [&](const size_t num_threads) {
        ar_heuristics.PrepareForThreads(num_threads);
        cfl_heuristics.PrepareForThreads(num_threads);
        return true;
      },
      process_tile, "Enc Heuristics"));

  acs_heuristics.Finalize(aux_out);
  if (cparams.speed_tier <= SpeedTier::kHare) {
    cfl_heuristics.ComputeDC(/*fast=*/cparams.speed_tier >= SpeedTier::kWombat,
                             &enc_state->shared.cmap);
  }

  // Refine quantization levels.
  FindBestQuantizer(original_pixels, *opsin, enc_state, cms, pool, aux_out);

  // Choose a context model that depends on the amount of quantization for AC.
  if (cparams.speed_tier < SpeedTier::kFalcon) {
    FindBestBlockEntropyModel(*enc_state);
  }
  return true;
}

}  // namespace jxl
