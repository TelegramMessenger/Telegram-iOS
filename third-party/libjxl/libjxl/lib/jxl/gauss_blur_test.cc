// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/gauss_blur.h"

#include <cmath>
#include <hwy/targets.h>
#include <vector>

#include "lib/extras/time.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/convolve.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {

bool NearEdge(const int64_t width, const int64_t peak) {
  // When around 3*sigma from the edge, there is negligible truncation.
  return peak < 10 || peak > width - 10;
}

// Follow the curve downwards by scanning right from `peak` and verifying
// identical values at the same offset to the left.
void VerifySymmetric(const int64_t width, const int64_t peak,
                     const float* out) {
  const double tolerance = NearEdge(width, peak) ? 0.015 : 6E-7;
  for (int64_t i = 1;; ++i) {
    // Stop if we passed either end of the array
    if (peak - i < 0 || peak + i >= width) break;
    EXPECT_GT(out[peak + i - 1] + tolerance, out[peak + i]);  // descending
    EXPECT_NEAR(out[peak - i], out[peak + i], tolerance);     // symmetric
  }
}

void TestImpulseResponse(size_t width, size_t peak) {
  const auto rg3 = CreateRecursiveGaussian(3.0);
  const auto rg4 = CreateRecursiveGaussian(4.0);
  const auto rg5 = CreateRecursiveGaussian(5.0);

  // Extra padding for 4x unrolling
  auto in = hwy::AllocateAligned<float>(width + 3);
  memset(in.get(), 0, sizeof(float) * (width + 3));
  in[peak] = 1.0f;

  auto out3 = hwy::AllocateAligned<float>(width + 3);
  auto out4 = hwy::AllocateAligned<float>(width + 3);
  auto out5 = hwy::AllocateAligned<float>(width + 3);
  FastGaussian1D(rg3, in.get(), width, out3.get());
  FastGaussian1D(rg4, out3.get(), width, out4.get());
  FastGaussian1D(rg5, in.get(), width, out5.get());

  VerifySymmetric(width, peak, out3.get());
  VerifySymmetric(width, peak, out4.get());
  VerifySymmetric(width, peak, out5.get());

  // Wider kernel has flatter peak
  EXPECT_LT(out5[peak] + 0.05, out3[peak]);

  // Gauss3 o Gauss4 ~= Gauss5
  const double tolerance = NearEdge(width, peak) ? 0.04 : 0.01;
  for (size_t i = 0; i < width; ++i) {
    EXPECT_NEAR(out4[i], out5[i], tolerance);
  }
}

void TestImpulseResponseForWidth(size_t width) {
  for (size_t i = 0; i < width; ++i) {
    TestImpulseResponse(width, i);
  }
}

TEST(GaussBlurTest, ImpulseResponse) {
  TestImpulseResponseForWidth(10);  // tiny even
  TestImpulseResponseForWidth(15);  // small odd
  TestImpulseResponseForWidth(32);  // power of two
  TestImpulseResponseForWidth(31);  // power of two - 1
  TestImpulseResponseForWidth(33);  // power of two + 1
}

ImageF Convolve(const ImageF& in, const std::vector<float>& kernel) {
  return ConvolveAndSample(in, kernel, 1);
}

// Higher-precision version for accuracy test.
ImageF ConvolveAndTransposeF64(const ImageF& in,
                               const std::vector<double>& kernel) {
  JXL_ASSERT(kernel.size() % 2 == 1);
  ImageF out(in.ysize(), in.xsize());
  const int r = kernel.size() / 2;
  std::vector<float> row_tmp(in.xsize() + 2 * r);
  float* const JXL_RESTRICT rowp = &row_tmp[r];
  const double* const kernelp = &kernel[r];
  for (size_t y = 0; y < in.ysize(); ++y) {
    ExtrapolateBorders(in.Row(y), rowp, in.xsize(), r);
    for (size_t x = 0, ox = 0; x < in.xsize(); ++x, ++ox) {
      double sum = 0.0;
      for (int i = -r; i <= r; ++i) {
        sum += rowp[std::max<int>(
                   0, std::min<int>(static_cast<int>(x) + i, in.xsize()))] *
               kernelp[i];
      }
      out.Row(ox)[y] = static_cast<float>(sum);
    }
  }
  return out;
}

ImageF ConvolveF64(const ImageF& in, const std::vector<double>& kernel) {
  ImageF tmp = ConvolveAndTransposeF64(in, kernel);
  return ConvolveAndTransposeF64(tmp, kernel);
}

void TestDirac2D(size_t xsize, size_t ysize, double sigma) {
  ImageF in(xsize, ysize);
  ZeroFillImage(&in);
  // We anyway ignore the border below, so might as well choose the middle.
  in.Row(ysize / 2)[xsize / 2] = 1.0f;

  ImageF temp(xsize, ysize);
  ImageF out(xsize, ysize);
  const auto rg = CreateRecursiveGaussian(sigma);
  ThreadPool* null_pool = nullptr;
  FastGaussian(rg, in, null_pool, &temp, &out);

  const std::vector<float> kernel =
      GaussianKernel(static_cast<int>(4 * sigma), static_cast<float>(sigma));
  const ImageF expected = Convolve(in, kernel);

  const double max_l1 = sigma < 1.5 ? 5E-3 : 6E-4;
  const size_t border = 2 * sigma;

  JXL_ASSERT_OK(VerifyRelativeError(expected, out, max_l1, 1E-8, _, border));
}

TEST(GaussBlurTest, Test2D) {
  const std::vector<int> dimensions{6, 15, 17, 64, 50, 49};
  for (int xsize : dimensions) {
    for (int ysize : dimensions) {
      for (double sigma : {1.0, 2.5, 3.6, 7.0}) {
        TestDirac2D(static_cast<size_t>(xsize), static_cast<size_t>(ysize),
                    sigma);
      }
    }
  }
}

// Slow (44 sec). To run, remove the disabled prefix.
TEST(GaussBlurTest, DISABLED_SlowTestDirac1D) {
  const double sigma = 7.0;
  const auto rg = CreateRecursiveGaussian(sigma);

  // IPOL accuracy test uses 10^-15 tolerance, this is 2*10^-11.
  const size_t radius = static_cast<size_t>(7 * sigma);
  const std::vector<double> kernel = GaussianKernel(radius, sigma);

  const size_t length = 16384;
  ImageF inputs(length, 1);
  ZeroFillImage(&inputs);

  auto outputs = hwy::AllocateAligned<float>(length);

  // One per center position
  auto sum_abs_err = hwy::AllocateAligned<double>(length);
  std::fill(sum_abs_err.get(), sum_abs_err.get() + length, 0.0);

  for (size_t center = radius; center < length - radius; ++center) {
    inputs.Row(0)[center - 1] = 0.0f;  // reset last peak, entire array now 0
    inputs.Row(0)[center] = 1.0f;
    FastGaussian1D(rg, inputs.Row(0), length, outputs.get());

    const ImageF outputs_fir = ConvolveF64(inputs, kernel);

    for (size_t i = 0; i < length; ++i) {
      const float abs_err = std::abs(outputs[i] - outputs_fir.Row(0)[i]);
      sum_abs_err[i] += static_cast<double>(abs_err);
    }
  }

  const double max_abs_err =
      *std::max_element(sum_abs_err.get(), sum_abs_err.get() + length);
  printf("Max abs err: %.8e\n", max_abs_err);
}

void TestRandom(size_t xsize, size_t ysize, float min, float max, double sigma,
                double max_l1, double max_rel) {
  printf("%4" PRIuS " x %4" PRIuS " %4.1f %4.1f sigma %.1f\n", xsize, ysize,
         min, max, sigma);
  ImageF in(xsize, ysize);
  RandomFillImage(&in, min, max, 65537 + xsize * 129 + ysize);
  // FastGaussian/Convolve handle borders differently, so keep those pixels 0.
  const size_t border = 4 * sigma;
  SetBorder(border, 0.0f, &in);

  ImageF temp(xsize, ysize);
  ImageF out(xsize, ysize);
  const auto rg = CreateRecursiveGaussian(sigma);
  ThreadPool* null_pool = nullptr;
  FastGaussian(rg, in, null_pool, &temp, &out);

  const std::vector<float> kernel =
      GaussianKernel(static_cast<int>(4 * sigma), static_cast<float>(sigma));
  const ImageF expected = Convolve(in, kernel);

  JXL_ASSERT_OK(VerifyRelativeError(expected, out, max_l1, max_rel, _, border));
}

void TestRandomForSizes(float min, float max, double sigma) {
  double max_l1 = 6E-3;
  double max_rel = 3E-3;
  TestRandom(128, 1, min, max, sigma, max_l1, max_rel);
  TestRandom(1, 128, min, max, sigma, max_l1, max_rel);
  TestRandom(30, 201, min, max, sigma, max_l1 * 1.6, max_rel * 1.2);
  TestRandom(201, 30, min, max, sigma, max_l1 * 1.6, max_rel * 1.2);
  TestRandom(201, 201, min, max, sigma, max_l1 * 2.0, max_rel * 1.2);
}

TEST(GaussBlurTest, TestRandom) {
  // small non-negative
  TestRandomForSizes(0.0f, 10.0f, 3.0f);
  TestRandomForSizes(0.0f, 10.0f, 7.0f);

  // small negative
  TestRandomForSizes(-4.0f, -1.0f, 3.0f);
  TestRandomForSizes(-4.0f, -1.0f, 7.0f);

  // mixed positive/negative
  TestRandomForSizes(-6.0f, 6.0f, 3.0f);
  TestRandomForSizes(-6.0f, 6.0f, 7.0f);
}

TEST(GaussBlurTest, TestSign) {
  const size_t xsize = 500;
  const size_t ysize = 606;
  ImageF in(xsize, ysize);

  ZeroFillImage(&in);
  const float center[33 * 33] = {
      -0.128445f, -0.098473f, -0.121883f, -0.093601f, 0.095665f,  -0.271332f,
      -0.705475f, -1.324005f, -2.020741f, -1.329464f, 1.834064f,  4.787300f,
      5.834560f,  5.272720f,  3.967960f,  3.547935f,  3.432732f,  3.383015f,
      3.239326f,  3.290806f,  3.298954f,  3.397808f,  3.359730f,  3.533844f,
      3.511856f,  3.436787f,  3.428310f,  3.460209f,  3.550011f,  3.590942f,
      3.593109f,  3.560005f,  3.443165f,  0.089741f,  0.179230f,  -0.032997f,
      -0.182610f, 0.005669f,  -0.244759f, -0.395123f, -0.514961f, -1.003529f,
      -1.798656f, -2.377975f, 0.222191f,  3.957664f,  5.946804f,  5.543129f,
      4.290096f,  3.621010f,  3.407257f,  3.392494f,  3.345367f,  3.391903f,
      3.441605f,  3.429260f,  3.444969f,  3.507130f,  3.518612f,  3.443111f,
      3.475948f,  3.536148f,  3.470333f,  3.628311f,  3.600243f,  3.292892f,
      -0.226730f, -0.573616f, -0.762165f, -0.398739f, -0.189842f, -0.275921f,
      -0.446739f, -0.550037f, -0.461033f, -0.724792f, -1.448349f, -1.814064f,
      -0.491032f, 2.817703f,  5.213242f,  5.675629f,  4.864548f,  3.876324f,
      3.535587f,  3.530312f,  3.413765f,  3.386261f,  3.404854f,  3.383472f,
      3.420830f,  3.326496f,  3.257877f,  3.362152f,  3.489609f,  3.619587f,
      3.555805f,  3.423164f,  3.309708f,  -0.483940f, -0.502926f, -0.592983f,
      -0.492527f, -0.413616f, -0.482555f, -0.475506f, -0.447990f, -0.338120f,
      -0.189072f, -0.376427f, -0.910828f, -1.878044f, -1.937927f, 1.423218f,
      4.871609f,  5.767548f,  5.103741f,  3.983868f,  3.633003f,  3.458263f,
      3.507309f,  3.247021f,  3.220612f,  3.326061f,  3.352814f,  3.291061f,
      3.322739f,  3.444302f,  3.506207f,  3.556839f,  3.529575f,  3.457024f,
      -0.408161f, -0.431343f, -0.454369f, -0.356419f, -0.380924f, -0.399452f,
      -0.439476f, -0.412189f, -0.306816f, -0.008213f, -0.325813f, -0.537842f,
      -0.984100f, -1.805332f, -2.028198f, 0.773205f,  4.423046f,  5.604839f,
      5.231617f,  4.080299f,  3.603008f,  3.498741f,  3.517010f,  3.333897f,
      3.381336f,  3.342617f,  3.369686f,  3.434155f,  3.490452f,  3.607029f,
      3.555298f,  3.702297f,  3.618679f,  -0.503609f, -0.578564f, -0.419014f,
      -0.239883f, 0.269836f,  0.022984f,  -0.455067f, -0.621777f, -0.304176f,
      -0.163792f, -0.490250f, -0.466637f, -0.391792f, -0.657940f, -1.498035f,
      -1.895836f, 0.036537f,  3.462456f,  5.586445f,  5.658791f,  4.434784f,
      3.423435f,  3.318848f,  3.202328f,  3.532764f,  3.436687f,  3.354881f,
      3.356941f,  3.382645f,  3.503902f,  3.512867f,  3.632366f,  3.537312f,
      -0.274734f, -0.658829f, -0.726532f, -0.281254f, 0.053196f,  -0.064991f,
      -0.608517f, -0.720966f, -0.070602f, -0.111320f, -0.440956f, -0.492180f,
      -0.488762f, -0.569283f, -1.012741f, -1.582779f, -2.101479f, -1.392380f,
      2.451153f,  5.555855f,  6.096313f,  5.230045f,  4.068172f,  3.404274f,
      3.392586f,  3.326065f,  3.156670f,  3.284828f,  3.347012f,  3.319252f,
      3.352310f,  3.610790f,  3.499847f,  -0.150600f, -0.314445f, -0.093575f,
      -0.057384f, 0.053688f,  -0.189255f, -0.263515f, -0.318653f, 0.053246f,
      0.080627f,  -0.119553f, -0.152454f, -0.305420f, -0.404869f, -0.385944f,
      -0.689949f, -1.204914f, -1.985748f, -1.711361f, 1.260658f,  4.626896f,
      5.888351f,  5.450989f,  4.070587f,  3.539200f,  3.383492f,  3.296318f,
      3.267334f,  3.436028f,  3.463005f,  3.502625f,  3.522282f,  3.403763f,
      -0.348049f, -0.302303f, -0.137016f, -0.041737f, -0.164001f, -0.358849f,
      -0.469627f, -0.428291f, -0.375797f, -0.246346f, -0.118950f, -0.084229f,
      -0.205681f, -0.241199f, -0.391796f, -0.323151f, -0.241211f, -0.834137f,
      -1.684219f, -1.972137f, 0.448399f,  4.019985f,  5.648144f,  5.647846f,
      4.295094f,  3.641884f,  3.374790f,  3.197342f,  3.425545f,  3.507481f,
      3.478065f,  3.430889f,  3.341900f,  -1.016304f, -0.959221f, -0.909466f,
      -0.810715f, -0.590729f, -0.594467f, -0.646721f, -0.629364f, -0.528561f,
      -0.551819f, -0.301086f, -0.149101f, -0.060146f, -0.162220f, -0.326210f,
      -0.156548f, -0.036293f, -0.426098f, -1.145470f, -1.628998f, -2.003052f,
      -1.142891f, 2.885162f,  5.652863f,  5.718426f,  4.911140f,  3.234222f,
      3.473373f,  3.577183f,  3.271603f,  3.410435f,  3.505489f,  3.434032f,
      -0.508911f, -0.438797f, -0.437450f, -0.627426f, -0.511745f, -0.304874f,
      -0.274246f, -0.261841f, -0.228466f, -0.342491f, -0.528206f, -0.490082f,
      -0.516350f, -0.361694f, -0.398514f, -0.276020f, -0.210369f, -0.355938f,
      -0.402622f, -0.538864f, -1.249573f, -2.100105f, -0.996178f, 1.886410f,
      4.929745f,  5.630871f,  5.444199f,  4.042740f,  3.739189f,  3.691399f,
      3.391956f,  3.469696f,  3.431232f,  0.204849f,  0.205433f,  -0.131927f,
      -0.367908f, -0.374378f, -0.126820f, -0.186951f, -0.228565f, -0.081776f,
      -0.143143f, -0.379230f, -0.598701f, -0.458019f, -0.295586f, -0.407730f,
      -0.245853f, -0.043140f, 0.024242f,  -0.038998f, -0.044151f, -0.425991f,
      -1.240753f, -1.943146f, -2.174755f, 0.523415f,  4.376751f,  5.956558f,
      5.850082f,  4.403152f,  3.517399f,  3.560753f,  3.554836f,  3.471985f,
      -0.508503f, -0.109783f, 0.057747f,  0.190079f,  -0.257153f, -0.591980f,
      -0.666771f, -0.525391f, -0.293060f, -0.489731f, -0.304855f, -0.259644f,
      -0.367825f, -0.346977f, -0.292889f, -0.215652f, -0.120705f, -0.176010f,
      -0.422905f, -0.114647f, -0.289749f, -0.374203f, -0.606754f, -1.127949f,
      -1.994583f, -0.588058f, 3.415840f,  5.603470f,  5.811581f,  4.959423f,
      3.721760f,  3.710499f,  3.785461f,  -0.554588f, -0.565517f, -0.434578f,
      -0.012482f, -0.284660f, -0.699795f, -0.957535f, -0.755135f, -0.382034f,
      -0.321552f, -0.287571f, -0.279537f, -0.314972f, -0.256287f, -0.372818f,
      -0.316017f, -0.287975f, -0.365639f, -0.512589f, -0.420692f, -0.436485f,
      -0.295353f, -0.451958f, -0.755459f, -1.272358f, -2.301353f, -1.776161f,
      1.572483f,  4.826286f,  5.741898f,  5.162853f,  4.028049f,  3.686325f,
      -0.495590f, -0.664413f, -0.760044f, -0.152634f, -0.286480f, -0.340462f,
      0.076477f,  0.187706f,  -0.068787f, -0.293491f, -0.361145f, -0.292515f,
      -0.140671f, -0.190723f, -0.333302f, -0.368168f, -0.192581f, -0.154499f,
      -0.236544f, -0.124405f, -0.208321f, -0.465607f, -0.883080f, -1.104813f,
      -1.210567f, -1.415665f, -1.924683f, -1.634758f, 0.601017f,  4.276672f,
      5.501350f,  5.331257f,  3.809288f,  -0.727722f, -0.533619f, -0.511524f,
      -0.470688f, -0.610710f, -0.575130f, -0.311115f, -0.090420f, -0.297676f,
      -0.646118f, -0.742805f, -0.485050f, -0.330910f, -0.275417f, -0.357037f,
      -0.425598f, -0.481876f, -0.488941f, -0.393551f, -0.051105f, -0.090755f,
      -0.328674f, -0.536369f, -0.533684f, -0.336960f, -0.689194f, -1.187195f,
      -1.860954f, -2.290253f, -0.424774f, 3.050060f,  5.083332f,  5.291920f,
      -0.343605f, -0.190975f, -0.303692f, -0.456512f, -0.681820f, -0.690693f,
      -0.416729f, -0.286446f, -0.442055f, -0.709148f, -0.569160f, -0.382423f,
      -0.402321f, -0.383362f, -0.366413f, -0.290718f, -0.110069f, -0.220280f,
      -0.279018f, -0.255424f, -0.262081f, -0.487556f, -0.444492f, -0.250500f,
      -0.119583f, -0.291557f, -0.537781f, -1.104073f, -1.737091f, -1.697441f,
      -0.323456f, 2.042049f,  4.605103f,  -0.310631f, -0.279568f, -0.012695f,
      -0.160130f, -0.358746f, -0.421101f, -0.559677f, -0.474136f, -0.416565f,
      -0.561817f, -0.534672f, -0.519157f, -0.767197f, -0.605831f, -0.186523f,
      0.219872f,  0.264984f,  -0.193432f, -0.363182f, -0.467472f, -0.462009f,
      -0.571053f, -0.522476f, -0.315903f, -0.237427f, -0.147320f, -0.100201f,
      -0.237568f, -0.763435f, -1.242043f, -2.135159f, -1.409485f, 1.236370f,
      -0.474247f, -0.517906f, -0.410217f, -0.542244f, -0.795986f, -0.590004f,
      -0.388863f, -0.462921f, -0.810627f, -0.778637f, -0.512486f, -0.718025f,
      -0.710854f, -0.482513f, -0.318233f, -0.194962f, -0.220116f, -0.421673f,
      -0.534233f, -0.403339f, -0.389332f, -0.407303f, -0.437355f, -0.469730f,
      -0.359600f, -0.352745f, -0.466755f, -0.414585f, -0.430756f, -0.656822f,
      -1.237038f, -2.046097f, -1.574898f, -0.593815f, -0.582165f, -0.336098f,
      -0.372612f, -0.554386f, -0.410603f, -0.428276f, -0.647644f, -0.640720f,
      -0.582207f, -0.414112f, -0.435547f, -0.435505f, -0.332561f, -0.248116f,
      -0.340221f, -0.277855f, -0.352699f, -0.377319f, -0.230850f, -0.313267f,
      -0.446270f, -0.346237f, -0.420422f, -0.530781f, -0.400341f, -0.463661f,
      -0.209091f, -0.056705f, -0.011772f, -0.169388f, -0.736275f, -1.463017f,
      -0.752701f, -0.668865f, -0.329765f, -0.299347f, -0.245667f, -0.286999f,
      -0.520420f, -0.675438f, -0.255753f, 0.141357f,  -0.079639f, -0.419476f,
      -0.374069f, -0.046253f, 0.116116f,  -0.145847f, -0.380371f, -0.563412f,
      -0.638634f, -0.310116f, -0.260914f, -0.508404f, -0.465508f, -0.527824f,
      -0.370979f, -0.305595f, -0.244694f, -0.254490f, 0.009968f,  -0.050201f,
      -0.331219f, -0.614960f, -0.788208f, -0.483242f, -0.367516f, -0.186951f,
      -0.180031f, 0.129711f,  -0.127811f, -0.384750f, -0.499542f, -0.418613f,
      -0.121635f, 0.203197f,  -0.167290f, -0.397270f, -0.355461f, -0.218746f,
      -0.376785f, -0.521698f, -0.721581f, -0.845741f, -0.535439f, -0.220882f,
      -0.309067f, -0.555248f, -0.690342f, -0.664948f, -0.390102f, 0.020355f,
      -0.130447f, -0.173252f, -0.170059f, -0.633663f, -0.956001f, -0.621696f,
      -0.388302f, -0.342262f, -0.244370f, -0.386948f, -0.401421f, -0.172979f,
      -0.206163f, -0.450058f, -0.525789f, -0.549274f, -0.349251f, -0.474613f,
      -0.667976f, -0.435600f, -0.175369f, -0.196877f, -0.202976f, -0.242481f,
      -0.258369f, -0.189133f, -0.395397f, -0.765499f, -0.944016f, -0.850967f,
      -0.631561f, -0.152493f, -0.046432f, -0.262066f, -0.195919f, 0.048218f,
      0.084972f,  0.039902f,  0.000618f,  -0.404430f, -0.447456f, -0.418076f,
      -0.631935f, -0.717415f, -0.502888f, -0.530514f, -0.747826f, -0.704041f,
      -0.674969f, -0.516853f, -0.418446f, -0.327740f, -0.308815f, -0.481636f,
      -0.440083f, -0.481720f, -0.341053f, -0.283897f, -0.324368f, -0.352829f,
      -0.434349f, -0.545589f, -0.533104f, -0.472755f, -0.570496f, -0.557735f,
      -0.708176f, -0.493332f, -0.194416f, -0.186249f, -0.256710f, -0.271835f,
      -0.304752f, -0.431267f, -0.422398f, -0.646725f, -0.680801f, -0.249031f,
      -0.058567f, -0.213890f, -0.383949f, -0.540291f, -0.549877f, -0.225567f,
      -0.037174f, -0.499874f, -0.641010f, -0.628044f, -0.390549f, -0.311497f,
      -0.542313f, -0.569565f, -0.473408f, -0.331245f, -0.357197f, -0.285599f,
      -0.200157f, -0.201866f, -0.124428f, -0.346016f, -0.392311f, -0.264496f,
      -0.285370f, -0.436974f, -0.523483f, -0.410461f, -0.267925f, -0.055016f,
      -0.382458f, -0.319771f, -0.049927f, 0.124329f,  0.266102f,  -0.106606f,
      -0.773647f, -0.973053f, -0.708206f, -0.486137f, -0.319923f, -0.493900f,
      -0.490860f, -0.324986f, -0.147346f, -0.146088f, -0.161758f, -0.084396f,
      -0.379494f, 0.041626f,  -0.113361f, -0.277767f, 0.083366f,  0.126476f,
      0.139057f,  0.038040f,  0.038162f,  -0.242126f, -0.411736f, -0.370049f,
      -0.455357f, -0.039257f, 0.264442f,  -0.271492f, -0.425346f, -0.514847f,
      -0.448650f, -0.580399f, -0.652603f, -0.774803f, -0.692524f, -0.579578f,
      -0.465206f, -0.386265f, -0.458012f, -0.446594f, -0.284893f, -0.345448f,
      -0.350876f, -0.440350f, -0.360378f, -0.270428f, 0.237213f,  -0.063602f,
      -0.364529f, -0.179867f, 0.078197f,  0.117947f,  -0.093410f, -0.359119f,
      -0.480961f, -0.540638f, -0.436287f, -0.598576f, -0.253735f, -0.060093f,
      -0.549145f, -0.808327f, -0.698593f, -0.595764f, -0.582508f, -0.497353f,
      -0.480892f, -0.584240f, -0.665791f, -0.690903f, -0.743446f, -0.796677f,
      -0.782391f, -0.649010f, -0.628139f, -0.880848f, -0.829361f, -0.373272f,
      -0.223667f, 0.174572f,  -0.348743f, -0.798901f, -0.692307f, -0.607609f,
      -0.401455f, -0.480919f, -0.450798f, -0.435413f, -0.322338f, -0.228382f,
      -0.450466f, -0.504440f, -0.477402f, -0.662224f, -0.583397f, -0.217445f,
      -0.157459f, -0.079584f, -0.226168f, -0.488720f, -0.669624f, -0.666878f,
      -0.565311f, -0.549625f, -0.364601f, -0.497627f, -0.736897f, -0.763023f,
      -0.741020f, -0.404503f, 0.184814f,  -0.075315f, -0.281513f, -0.532906f,
      -0.405800f, -0.313438f, -0.536652f, -0.403381f, 0.011967f,  0.103310f,
      -0.269848f, -0.508656f, -0.445923f, -0.644859f, -0.617870f, -0.500927f,
      -0.371559f, -0.125580f, 0.028625f,  -0.154713f, -0.442024f, -0.492764f,
      -0.199371f, 0.236305f,  0.225925f,  0.075577f,  -0.285812f, -0.437145f,
      -0.374260f, -0.156693f, -0.129635f, -0.243206f, -0.123058f, 0.162148f,
      -0.313152f, -0.337982f, -0.358421f, 0.040070f,  0.038925f,  -0.333313f,
      -0.351662f, 0.023014f,  0.091362f,  -0.282890f, -0.373253f, -0.389050f,
      -0.532707f, -0.423347f, -0.349968f, -0.287045f, -0.202442f, -0.308430f,
      -0.222801f, -0.106323f, -0.056358f, 0.027222f,  0.390732f,  0.033558f,
      -0.160088f, -0.382217f, -0.535282f, -0.515900f, -0.022736f, 0.165665f,
      -0.111408f, -0.233784f, -0.312357f, -0.541885f, -0.480022f, -0.482513f,
      -0.246254f, 0.132244f,  0.090134f,  0.234634f,  -0.089249f, -0.460854f,
      -0.515457f, -0.450874f, -0.311031f, -0.387680f, -0.360554f, -0.179241f,
      -0.283817f, -0.475815f, -0.246399f, -0.388958f, -0.551140f, -0.496239f,
      -0.559879f, -0.379761f, -0.254288f, -0.395111f, -0.613018f, -0.459427f,
      -0.263580f, -0.268929f, 0.080826f,  0.115616f,  -0.097324f, -0.325310f,
      -0.480450f, -0.313286f, -0.310371f, -0.517361f, -0.288288f, -0.112679f,
      -0.173241f, -0.221664f, -0.039452f, -0.107578f, -0.089630f, -0.483768f,
      -0.571087f, -0.497108f, -0.321533f, -0.375492f, -0.540363f, -0.406815f,
      -0.388512f, -0.514561f, -0.540192f, -0.402412f, -0.232246f, -0.304749f,
      -0.383724f, -0.679596f, -0.685463f, -0.694538f, -0.642937f, -0.425789f,
      0.103271f,  -0.194862f, -0.487999f, -0.717281f, -0.681850f, -0.709286f,
      -0.615398f, -0.554245f, -0.254681f, -0.049950f, -0.002914f, -0.095383f,
      -0.370911f, -0.564224f, -0.242714f};
  const size_t xtest = xsize / 2;
  const size_t ytest = ysize / 2;

  for (intptr_t dy = -16; dy <= 16; ++dy) {
    float* row = in.Row(ytest + dy);
    for (intptr_t dx = -16; dx <= 16; ++dx)
      row[xtest + dx] = center[(dy + 16) * 33 + (dx + 16)];
  }

  const double sigma = 7.155933;

  ImageF temp(xsize, ysize);
  ImageF out_rg(xsize, ysize);
  const auto rg = CreateRecursiveGaussian(sigma);
  ThreadPool* null_pool = nullptr;
  FastGaussian(rg, in, null_pool, &temp, &out_rg);

  ImageF out_old;
  {
    const std::vector<float> kernel =
        GaussianKernel(static_cast<int>(4 * sigma), static_cast<float>(sigma));
    printf("old kernel size %" PRIuS "\n", kernel.size());
    out_old = Convolve(in, kernel);
  }

  printf("rg %.4f old %.4f\n", out_rg.Row(ytest)[xtest],
         out_old.Row(ytest)[xtest]);
}

}  // namespace jxl
