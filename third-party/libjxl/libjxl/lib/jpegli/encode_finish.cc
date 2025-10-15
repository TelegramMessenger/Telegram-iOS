// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/encode_finish.h"

#include <cmath>
#include <limits>

#include "lib/jpegli/error.h"
#include "lib/jpegli/memory_manager.h"
#include "lib/jpegli/quant.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/encode_finish.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jpegli/dct-inl.h"

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::GetLane;

using D = HWY_FULL(float);
using DI = HWY_FULL(int32_t);
using DI16 = Rebind<int16_t, HWY_FULL(int32_t)>;

void ReQuantizeBlock(int16_t* block, const float* qmc, float aq_strength,
                     const float* zero_bias_offset,
                     const float* zero_bias_mul) {
  D d;
  DI di;
  DI16 di16;
  const auto aq_mul = Set(d, aq_strength);
  for (size_t k = 0; k < DCTSIZE2; k += Lanes(d)) {
    const auto in = Load(di16, block + k);
    const auto val = ConvertTo(d, PromoteTo(di, in));
    const auto q = Load(d, qmc + k);
    const auto qval = Mul(val, q);
    const auto zb_offset = Load(d, zero_bias_offset + k);
    const auto zb_mul = Load(d, zero_bias_mul + k);
    const auto threshold = Add(zb_offset, Mul(zb_mul, aq_mul));
    const auto nzero_mask = Ge(Abs(qval), threshold);
    const auto iqval = IfThenElseZero(nzero_mask, Round(qval));
    Store(DemoteTo(di16, ConvertTo(di, iqval)), di16, block + k);
  }
}

float BlockError(const int16_t* block, const float* qmc, const float* iqmc,
                 const float aq_strength, const float* zero_bias_offset,
                 const float* zero_bias_mul) {
  D d;
  DI di;
  DI16 di16;
  auto err = Zero(d);
  const auto scale = Set(d, 1.0 / 16);
  const auto aq_mul = Set(d, aq_strength);
  for (size_t k = 0; k < DCTSIZE2; k += Lanes(d)) {
    const auto in = Load(di16, block + k);
    const auto val = ConvertTo(d, PromoteTo(di, in));
    const auto q = Load(d, qmc + k);
    const auto qval = Mul(val, q);
    const auto zb_offset = Load(d, zero_bias_offset + k);
    const auto zb_mul = Load(d, zero_bias_mul + k);
    const auto threshold = Add(zb_offset, Mul(zb_mul, aq_mul));
    const auto nzero_mask = Ge(Abs(qval), threshold);
    const auto iqval = IfThenElseZero(nzero_mask, Round(qval));
    const auto invq = Load(d, iqmc + k);
    const auto rval = Mul(iqval, invq);
    const auto diff = Mul(Sub(val, rval), scale);
    err = Add(err, Mul(diff, diff));
  }
  return GetLane(SumOfLanes(d, err));
}

void ComputeInverseWeights(const float* qmc, float* iqmc) {
  for (int k = 0; k < 64; ++k) {
    iqmc[k] = 1.0f / qmc[k];
  }
}

float ComputePSNR(j_compress_ptr cinfo, int sampling) {
  jpeg_comp_master* m = cinfo->master;
  InitQuantizer(cinfo, QuantPass::SEARCH_SECOND_PASS);
  double error = 0.0;
  size_t num = 0;
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    const float* qmc = m->quant_mul[c];
    const int h_factor = m->h_factor[c];
    const int v_factor = m->v_factor[c];
    const float* zero_bias_offset = m->zero_bias_offset[c];
    const float* zero_bias_mul = m->zero_bias_mul[c];
    HWY_ALIGN float iqmc[64];
    ComputeInverseWeights(qmc, iqmc);
    for (JDIMENSION by = 0; by < comp->height_in_blocks; by += sampling) {
      JBLOCKARRAY ba = GetBlockRow(cinfo, c, by);
      const float* qf = m->quant_field.Row(by * v_factor);
      for (JDIMENSION bx = 0; bx < comp->width_in_blocks; bx += sampling) {
        error += BlockError(&ba[0][bx][0], qmc, iqmc, qf[bx * h_factor],
                            zero_bias_offset, zero_bias_mul);
        num += DCTSIZE2;
      }
    }
  }
  return 4.3429448f * log(num / (error / 255. / 255.));
}

void ReQuantizeCoeffs(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  InitQuantizer(cinfo, QuantPass::SEARCH_SECOND_PASS);
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    const float* qmc = m->quant_mul[c];
    const int h_factor = m->h_factor[c];
    const int v_factor = m->v_factor[c];
    const float* zero_bias_offset = m->zero_bias_offset[c];
    const float* zero_bias_mul = m->zero_bias_mul[c];
    for (JDIMENSION by = 0; by < comp->height_in_blocks; ++by) {
      JBLOCKARRAY ba = GetBlockRow(cinfo, c, by);
      const float* qf = m->quant_field.Row(by * v_factor);
      for (JDIMENSION bx = 0; bx < comp->width_in_blocks; ++bx) {
        ReQuantizeBlock(&ba[0][bx][0], qmc, qf[bx * h_factor], zero_bias_offset,
                        zero_bias_mul);
      }
    }
  }
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jpegli {
namespace {
HWY_EXPORT(ComputePSNR);
HWY_EXPORT(ReQuantizeCoeffs);

void ReQuantizeCoeffs(j_compress_ptr cinfo) {
  HWY_DYNAMIC_DISPATCH(ReQuantizeCoeffs)(cinfo);
}

float ComputePSNR(j_compress_ptr cinfo, int sampling) {
  return HWY_DYNAMIC_DISPATCH(ComputePSNR)(cinfo, sampling);
}

void UpdateDistance(j_compress_ptr cinfo, float distance) {
  float distances[NUM_QUANT_TBLS] = {distance, distance, distance};
  SetQuantMatrices(cinfo, distances, /*add_two_chroma_tables=*/true);
}

float Clamp(float val, float minval, float maxval) {
  return std::max(minval, std::min(maxval, val));
}

#define PSNR_SEARCH_DBG 0

float FindDistanceForPSNR(j_compress_ptr cinfo) {
  constexpr int kMaxIters = 20;
  const float psnr_target = cinfo->master->psnr_target;
  const float tolerance = cinfo->master->psnr_tolerance;
  const float min_dist = cinfo->master->min_distance;
  const float max_dist = cinfo->master->max_distance;
  float d = Clamp(1.0f, min_dist, max_dist);
  for (int sampling : {4, 1}) {
    float best_diff = std::numeric_limits<float>::max();
    float best_distance = 0.0f;
    float best_psnr = 0.0;
    float dmin = min_dist;
    float dmax = max_dist;
    bool found_lower_bound = false;
    bool found_upper_bound = false;
    for (int i = 0; i < kMaxIters; ++i) {
      UpdateDistance(cinfo, d);
      float psnr = ComputePSNR(cinfo, sampling);
      if (psnr > psnr_target) {
        dmin = d;
        found_lower_bound = true;
      } else {
        dmax = d;
        found_upper_bound = true;
      }
#if (PSNR_SEARCH_DBG > 1)
      printf("sampling %d iter %2d d %7.4f psnr %.2f", sampling, i, d, psnr);
      if (found_upper_bound && found_lower_bound) {
        printf("    d-interval: [ %7.4f .. %7.4f ]", dmin, dmax);
      }
      printf("\n");
#endif
      float diff = std::abs(psnr - psnr_target);
      if (diff < best_diff) {
        best_diff = diff;
        best_distance = d;
        best_psnr = psnr;
      }
      if (diff < tolerance * psnr_target || dmin == dmax) {
        break;
      }
      if (!found_lower_bound || !found_upper_bound) {
        d *= std::exp(0.15f * (psnr - psnr_target));
      } else {
        d = 0.5f * (dmin + dmax);
      }
      d = Clamp(d, min_dist, max_dist);
    }
    d = best_distance;
    if (sampling == 1 && PSNR_SEARCH_DBG) {
      printf("Final PSNR %.2f at distance %.4f\n", best_psnr, d);
    }
  }
  return d;
}

}  // namespace

void QuantizetoPSNR(j_compress_ptr cinfo) {
  float distance = FindDistanceForPSNR(cinfo);
  UpdateDistance(cinfo, distance);
  ReQuantizeCoeffs(cinfo);
}

}  // namespace jpegli
#endif  // HWY_ONCE
