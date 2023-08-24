// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
SSIMULACRA 2
Structural SIMilarity Unveiling Local And Compression Related Artifacts

Perceptual metric developed by Jon Sneyers (Cloudinary) in July 2022,
updated in April 2023.
Design:
- XYB color space (rescaled to a 0..1 range and with B-Y)
- SSIM map (with correction: no double gamma correction)
- 'blockiness/ringing' map (distorted has edges where original is smooth)
- 'smoothing' map (distorted is smooth where original has edges)
- error maps are computed at 6 scales (1:1 to 1:32) for each component (X,Y,B)
- downscaling is done in linear RGB
- for all 6*3*3=54 maps, two norms are computed: 1-norm (mean) and 4-norm
- a weighted sum of these 54*2=108 norms leads to the final score
- weights were tuned based on a large set of subjective scores
  (CID22, TID2013, Kadid10k, KonFiG-IQA).
*/

#include "tools/ssimulacra2.h"

#include <stdio.h>

#include <cmath>

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_xyb.h"
#include "lib/jxl/gauss_blur.h"
#include "lib/jxl/image_ops.h"

namespace {

using jxl::Image3F;
using jxl::ImageF;

static const float kC2 = 0.0009f;
static const int kNumScales = 6;

Image3F Downsample(const Image3F& in, size_t fx, size_t fy) {
  const size_t out_xsize = (in.xsize() + fx - 1) / fx;
  const size_t out_ysize = (in.ysize() + fy - 1) / fy;
  Image3F out(out_xsize, out_ysize);
  const float normalize = 1.0f / (fx * fy);
  for (size_t c = 0; c < 3; ++c) {
    for (size_t oy = 0; oy < out_ysize; ++oy) {
      float* JXL_RESTRICT row_out = out.PlaneRow(c, oy);
      for (size_t ox = 0; ox < out_xsize; ++ox) {
        float sum = 0.0f;
        for (size_t iy = 0; iy < fy; ++iy) {
          for (size_t ix = 0; ix < fx; ++ix) {
            const size_t x = std::min(ox * fx + ix, in.xsize() - 1);
            const size_t y = std::min(oy * fy + iy, in.ysize() - 1);
            sum += in.PlaneRow(c, y)[x];
          }
        }
        row_out[ox] = sum * normalize;
      }
    }
  }
  return out;
}

void Multiply(const Image3F& a, const Image3F& b, Image3F* mul) {
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < a.ysize(); ++y) {
      const float* JXL_RESTRICT in1 = a.PlaneRow(c, y);
      const float* JXL_RESTRICT in2 = b.PlaneRow(c, y);
      float* JXL_RESTRICT out = mul->PlaneRow(c, y);
      for (size_t x = 0; x < a.xsize(); ++x) {
        out[x] = in1[x] * in2[x];
      }
    }
  }
}

// Temporary storage for Gaussian blur, reused for multiple images.
class Blur {
 public:
  Blur(const size_t xsize, const size_t ysize)
      : rg_(jxl::CreateRecursiveGaussian(1.5)), temp_(xsize, ysize) {}

  void operator()(const ImageF& in, ImageF* JXL_RESTRICT out) {
    jxl::ThreadPool* null_pool = nullptr;
    FastGaussian(rg_, in, null_pool, &temp_, out);
  }

  Image3F operator()(const Image3F& in) {
    Image3F out(in.xsize(), in.ysize());
    operator()(in.Plane(0), &out.Plane(0));
    operator()(in.Plane(1), &out.Plane(1));
    operator()(in.Plane(2), &out.Plane(2));
    return out;
  }

  // Allows reusing across scales.
  void ShrinkTo(const size_t xsize, const size_t ysize) {
    temp_.ShrinkTo(xsize, ysize);
  }

 private:
  hwy::AlignedUniquePtr<jxl::RecursiveGaussian> rg_;
  ImageF temp_;
};

double tothe4th(double x) {
  x *= x;
  x *= x;
  return x;
}
void SSIMMap(const Image3F& m1, const Image3F& m2, const Image3F& s11,
             const Image3F& s22, const Image3F& s12, double* plane_averages) {
  const double onePerPixels = 1.0 / (m1.ysize() * m1.xsize());
  for (size_t c = 0; c < 3; ++c) {
    double sum1[2] = {0.0};
    for (size_t y = 0; y < m1.ysize(); ++y) {
      const float* JXL_RESTRICT row_m1 = m1.PlaneRow(c, y);
      const float* JXL_RESTRICT row_m2 = m2.PlaneRow(c, y);
      const float* JXL_RESTRICT row_s11 = s11.PlaneRow(c, y);
      const float* JXL_RESTRICT row_s22 = s22.PlaneRow(c, y);
      const float* JXL_RESTRICT row_s12 = s12.PlaneRow(c, y);
      for (size_t x = 0; x < m1.xsize(); ++x) {
        float mu1 = row_m1[x];
        float mu2 = row_m2[x];
        float mu11 = mu1 * mu1;
        float mu22 = mu2 * mu2;
        float mu12 = mu1 * mu2;
        /* Correction applied compared to the original SSIM formula, which has:

             luma_err = 2 * mu1 * mu2 / (mu1^2 + mu2^2)
                      = 1 - (mu1 - mu2)^2 / (mu1^2 + mu2^2)

           The denominator causes error in the darks (low mu1 and mu2) to weigh
           more than error in the brights (high mu1 and mu2). This would make
           sense if values correspond to linear luma. However, the actual values
           are either gamma-compressed luma (which supposedly is already
           perceptually uniform) or chroma (where weighing green more than red
           or blue more than yellow does not make any sense at all). So it is
           better to simply drop this denominator.
        */
        float num_m = 1.0 - (mu1 - mu2) * (mu1 - mu2);
        float num_s = 2 * (row_s12[x] - mu12) + kC2;
        float denom_s = (row_s11[x] - mu11) + (row_s22[x] - mu22) + kC2;

        // Use 1 - SSIM' so it becomes an error score instead of a quality
        // index. This makes it make sense to compute an L_4 norm.
        double d = 1.0 - (num_m * num_s / denom_s);
        d = std::max(d, 0.0);
        sum1[0] += d;
        sum1[1] += tothe4th(d);
      }
    }
    plane_averages[c * 2] = onePerPixels * sum1[0];
    plane_averages[c * 2 + 1] = sqrt(sqrt(onePerPixels * sum1[1]));
  }
}

void EdgeDiffMap(const Image3F& img1, const Image3F& mu1, const Image3F& img2,
                 const Image3F& mu2, double* plane_averages) {
  const double onePerPixels = 1.0 / (img1.ysize() * img1.xsize());
  for (size_t c = 0; c < 3; ++c) {
    double sum1[4] = {0.0};
    for (size_t y = 0; y < img1.ysize(); ++y) {
      const float* JXL_RESTRICT row1 = img1.PlaneRow(c, y);
      const float* JXL_RESTRICT row2 = img2.PlaneRow(c, y);
      const float* JXL_RESTRICT rowm1 = mu1.PlaneRow(c, y);
      const float* JXL_RESTRICT rowm2 = mu2.PlaneRow(c, y);
      for (size_t x = 0; x < img1.xsize(); ++x) {
        double d1 = (1.0 + std::abs(row2[x] - rowm2[x])) /
                        (1.0 + std::abs(row1[x] - rowm1[x])) -
                    1.0;

        // d1 > 0: distorted has an edge where original is smooth
        //         (indicating ringing, color banding, blockiness, etc)
        double artifact = std::max(d1, 0.0);
        sum1[0] += artifact;
        sum1[1] += tothe4th(artifact);

        // d1 < 0: original has an edge where distorted is smooth
        //         (indicating smoothing, blurring, smearing, etc)
        double detail_lost = std::max(-d1, 0.0);
        sum1[2] += detail_lost;
        sum1[3] += tothe4th(detail_lost);
      }
    }
    plane_averages[c * 4] = onePerPixels * sum1[0];
    plane_averages[c * 4 + 1] = sqrt(sqrt(onePerPixels * sum1[1]));
    plane_averages[c * 4 + 2] = onePerPixels * sum1[2];
    plane_averages[c * 4 + 3] = sqrt(sqrt(onePerPixels * sum1[3]));
  }
}

/* Get all components in more or less 0..1 range
   Range of Rec2020 with these adjustments:
    X: 0.017223..0.998838
    Y: 0.010000..0.855303
    B: 0.048759..0.989551
   Range of sRGB:
    X: 0.204594..0.813402
    Y: 0.010000..0.855308
    B: 0.272295..0.938012
   The maximum pixel-wise difference has to be <= 1 for the ssim formula to make
   sense.
*/
void MakePositiveXYB(jxl::Image3F& img) {
  for (size_t y = 0; y < img.ysize(); ++y) {
    float* JXL_RESTRICT rowY = img.PlaneRow(1, y);
    float* JXL_RESTRICT rowB = img.PlaneRow(2, y);
    float* JXL_RESTRICT rowX = img.PlaneRow(0, y);
    for (size_t x = 0; x < img.xsize(); ++x) {
      rowB[x] = (rowB[x] - rowY[x]) + 0.55f;
      rowX[x] = rowX[x] * 14.f + 0.42f;
      rowY[x] += 0.01f;
    }
  }
}

void AlphaBlend(jxl::ImageBundle& img, float bg) {
  for (size_t y = 0; y < img.ysize(); ++y) {
    float* JXL_RESTRICT r = img.color()->PlaneRow(0, y);
    float* JXL_RESTRICT g = img.color()->PlaneRow(1, y);
    float* JXL_RESTRICT b = img.color()->PlaneRow(2, y);
    const float* JXL_RESTRICT a = img.alpha()->Row(y);
    for (size_t x = 0; x < img.xsize(); ++x) {
      r[x] = a[x] * r[x] + (1.f - a[x]) * bg;
      g[x] = a[x] * g[x] + (1.f - a[x]) * bg;
      b[x] = a[x] * b[x] + (1.f - a[x]) * bg;
    }
  }
}

}  // namespace

/*
The final score is based on a weighted sum of 108 sub-scores:
- for 6 scales (1:1 to 1:32, downsampled in linear RGB)
- for 3 components (X, Y, B-Y, rescaled to 0..1 range)
- using 2 norms (the 1-norm and the 4-norm)
- over 3 error maps:
    - SSIM' (SSIM without the spurious gamma correction term)
    - "ringing" (distorted edges where there are no orig edges)
    - "blurring" (orig edges where there are no distorted edges)

The weights were obtained by running Nelder-Mead simplex search,
optimizing to minimize MSE for the CID22 training set and to
maximize Kendall rank correlation (and with a lower weight,
also Pearson correlation) with the CID22 training set and the
TID2013, Kadid10k and KonFiG-IQA datasets.
Validation was done on the CID22 validation set.

Final results after tuning (Kendall | Spearman | Pearson):
   CID22:     0.6903 | 0.8805 | 0.8583
   TID2013:   0.6590 | 0.8445 | 0.8471
   KADID-10k: 0.6175 | 0.8133 | 0.8030
   KonFiG(F): 0.7668 | 0.9194 | 0.9136
*/
double Msssim::Score() const {
  double ssim = 0.0;
  constexpr double weight[108] = {0.0,
                                  0.0007376606707406586,
                                  0.0,
                                  0.0,
                                  0.0007793481682867309,
                                  0.0,
                                  0.0,
                                  0.0004371155730107379,
                                  0.0,
                                  1.1041726426657346,
                                  0.00066284834129271,
                                  0.00015231632783718752,
                                  0.0,
                                  0.0016406437456599754,
                                  0.0,
                                  1.8422455520539298,
                                  11.441172603757666,
                                  0.0,
                                  0.0007989109436015163,
                                  0.000176816438078653,
                                  0.0,
                                  1.8787594979546387,
                                  10.94906990605142,
                                  0.0,
                                  0.0007289346991508072,
                                  0.9677937080626833,
                                  0.0,
                                  0.00014003424285435884,
                                  0.9981766977854967,
                                  0.00031949755934435053,
                                  0.0004550992113792063,
                                  0.0,
                                  0.0,
                                  0.0013648766163243398,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  7.466890328078848,
                                  0.0,
                                  17.445833984131262,
                                  0.0006235601634041466,
                                  0.0,
                                  0.0,
                                  6.683678146179332,
                                  0.00037724407979611296,
                                  1.027889937768264,
                                  225.20515300849274,
                                  0.0,
                                  0.0,
                                  19.213238186143016,
                                  0.0011401524586618361,
                                  0.001237755635509985,
                                  176.39317598450694,
                                  0.0,
                                  0.0,
                                  24.43300999870476,
                                  0.28520802612117757,
                                  0.0004485436923833408,
                                  0.0,
                                  0.0,
                                  0.0,
                                  34.77906344483772,
                                  44.835625328877896,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0008680556573291698,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0005313191874358747,
                                  0.0,
                                  0.00016533814161379112,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0004179171803251336,
                                  0.0017290828234722833,
                                  0.0,
                                  0.0020827005846636437,
                                  0.0,
                                  0.0,
                                  8.826982764996862,
                                  23.19243343998926,
                                  0.0,
                                  95.1080498811086,
                                  0.9863978034400682,
                                  0.9834382792465353,
                                  0.0012286405048278493,
                                  171.2667255897307,
                                  0.9807858872435379,
                                  0.0,
                                  0.0,
                                  0.0,
                                  0.0005130064588990679,
                                  0.0,
                                  0.00010854057858411537};

  size_t i = 0;
  char ch[] = "XYB";
  const bool verbose = false;
  for (size_t c = 0; c < 3; ++c) {
    for (size_t scale = 0; scale < scales.size(); ++scale) {
      for (size_t n = 0; n < 2; n++) {
#ifdef SSIMULACRA2_OUTPUT_RAW_SCORES_FOR_WEIGHT_TUNING
        printf("%.12f,%.12f,%.12f,", scales[scale].avg_ssim[c * 2 + n],
               scales[scale].avg_edgediff[c * 4 + n],
               scales[scale].avg_edgediff[c * 4 + 2 + n]);
#endif
        if (verbose) {
          printf("%f from channel %c ssim, scale 1:%i, %" PRIuS
                 "-norm (weight %f)\n",
                 weight[i] * std::abs(scales[scale].avg_ssim[c * 2 + n]), ch[c],
                 1 << scale, n * 3 + 1, weight[i]);
        }
        ssim += weight[i++] * std::abs(scales[scale].avg_ssim[c * 2 + n]);
        if (verbose) {
          printf("%f from channel %c ringing, scale 1:%i, %" PRIuS
                 "-norm (weight %f)\n",
                 weight[i] * std::abs(scales[scale].avg_edgediff[c * 4 + n]),
                 ch[c], 1 << scale, n * 3 + 1, weight[i]);
        }
        ssim += weight[i++] * std::abs(scales[scale].avg_edgediff[c * 4 + n]);
        if (verbose) {
          printf(
              "%f from channel %c blur, scale 1:%i, %" PRIuS
              "-norm (weight %f)\n",
              weight[i] * std::abs(scales[scale].avg_edgediff[c * 4 + n + 2]),
              ch[c], 1 << scale, n * 3 + 1, weight[i]);
        }
        ssim +=
            weight[i++] * std::abs(scales[scale].avg_edgediff[c * 4 + n + 2]);
      }
    }
  }

  ssim = ssim * 0.9562382616834844;
  ssim = 2.326765642916932 * ssim - 0.020884521182843837 * ssim * ssim +
         6.248496625763138e-05 * ssim * ssim * ssim;
  if (ssim > 0) {
    ssim = 100.0 - 10.0 * pow(ssim, 0.6276336467831387);
  } else {
    ssim = 100.0;
  }
  return ssim;
}

Msssim ComputeSSIMULACRA2(const jxl::ImageBundle& orig,
                          const jxl::ImageBundle& dist, float bg) {
  Msssim msssim;

  jxl::Image3F img1(orig.xsize(), orig.ysize());
  jxl::Image3F img2(img1.xsize(), img1.ysize());

  jxl::ImageBundle orig2 = orig.Copy();
  jxl::ImageBundle dist2 = dist.Copy();

  if (orig.HasAlpha()) AlphaBlend(orig2, bg);
  if (dist.HasAlpha()) AlphaBlend(dist2, bg);
  orig2.ClearExtraChannels();
  dist2.ClearExtraChannels();

  JXL_CHECK(orig2.TransformTo(jxl::ColorEncoding::LinearSRGB(orig2.IsGray()),
                              jxl::GetJxlCms()));
  JXL_CHECK(dist2.TransformTo(jxl::ColorEncoding::LinearSRGB(dist2.IsGray()),
                              jxl::GetJxlCms()));

  jxl::ToXYB(orig2, nullptr, &img1, jxl::GetJxlCms(), nullptr);
  jxl::ToXYB(dist2, nullptr, &img2, jxl::GetJxlCms(), nullptr);
  MakePositiveXYB(img1);
  MakePositiveXYB(img2);

  Image3F mul(img1.xsize(), img1.ysize());
  Blur blur(img1.xsize(), img1.ysize());

  for (int scale = 0; scale < kNumScales; scale++) {
    if (img1.xsize() < 8 || img1.ysize() < 8) {
      break;
    }
    if (scale) {
      orig2.SetFromImage(Downsample(*orig2.color(), 2, 2),
                         jxl::ColorEncoding::LinearSRGB(orig2.IsGray()));
      dist2.SetFromImage(Downsample(*dist2.color(), 2, 2),
                         jxl::ColorEncoding::LinearSRGB(dist2.IsGray()));
      img1.ShrinkTo(orig2.xsize(), orig2.ysize());
      img2.ShrinkTo(orig2.xsize(), orig2.ysize());
      jxl::ToXYB(orig2, nullptr, &img1, jxl::GetJxlCms(), nullptr);
      jxl::ToXYB(dist2, nullptr, &img2, jxl::GetJxlCms(), nullptr);
      MakePositiveXYB(img1);
      MakePositiveXYB(img2);
    }
    mul.ShrinkTo(img1.xsize(), img1.ysize());
    blur.ShrinkTo(img1.xsize(), img1.ysize());

    Multiply(img1, img1, &mul);
    Image3F sigma1_sq = blur(mul);

    Multiply(img2, img2, &mul);
    Image3F sigma2_sq = blur(mul);

    Multiply(img1, img2, &mul);
    Image3F sigma12 = blur(mul);

    Image3F mu1 = blur(img1);
    Image3F mu2 = blur(img2);

    MsssimScale sscale;
    SSIMMap(mu1, mu2, sigma1_sq, sigma2_sq, sigma12, sscale.avg_ssim);
    EdgeDiffMap(img1, mu1, img2, mu2, sscale.avg_edgediff);
    msssim.scales.push_back(sscale);
  }
  return msssim;
}

Msssim ComputeSSIMULACRA2(const jxl::ImageBundle& orig,
                          const jxl::ImageBundle& distorted) {
  return ComputeSSIMULACRA2(orig, distorted, 0.5f);
}
