// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>
#include <stdlib.h>

#include "lib/extras/codec.h"
#include "lib/extras/tone_mapping.h"
#include "lib/jxl/convolve.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_gamma_correct.h"
#include "lib/jxl/image_bundle.h"
#include "tools/args.h"
#include "tools/cmdline.h"
#include "tools/thread_pool_internal.h"

namespace jxl {
namespace {

constexpr WeightsSeparable5 kPyramidFilter = {
    {HWY_REP4(.375f), HWY_REP4(.25f), HWY_REP4(.0625f)},
    {HWY_REP4(.375f), HWY_REP4(.25f), HWY_REP4(.0625f)}};

// Expects sRGB input.
// Will call consumer(x, y, contrast) for each pixel.
template <typename Consumer>
void Contrast(const jxl::Image3F& image, const Consumer& consumer,
              ThreadPool* const pool) {
  static constexpr WeightsSymmetric3 kLaplacianWeights = {
      {HWY_REP4(-4)}, {HWY_REP4(1)}, {HWY_REP4(0)}};
  ImageF grayscale(image.xsize(), image.ysize());
  static constexpr float kLuminances[3] = {0.2126, 0.7152, 0.0722};
  for (size_t y = 0; y < image.ysize(); ++y) {
    const float* const JXL_RESTRICT input_rows[3] = {
        image.PlaneRow(0, y), image.PlaneRow(1, y), image.PlaneRow(2, y)};
    float* const JXL_RESTRICT row = grayscale.Row(y);

    for (size_t x = 0; x < image.xsize(); ++x) {
      row[x] = LinearToSrgb8Direct(
          kLuminances[0] * Srgb8ToLinearDirect(input_rows[0][x]) +
          kLuminances[1] * Srgb8ToLinearDirect(input_rows[1][x]) +
          kLuminances[2] * Srgb8ToLinearDirect(input_rows[2][x]));
    }
  }

  ImageF laplacian(image.xsize(), image.ysize());
  Symmetric3(grayscale, Rect(grayscale), kLaplacianWeights, pool, &laplacian);
  for (size_t y = 0; y < image.ysize(); ++y) {
    const float* const JXL_RESTRICT row = laplacian.ConstRow(y);
    for (size_t x = 0; x < image.xsize(); ++x) {
      consumer(x, y, std::abs(row[x]));
    }
  }
}

template <typename Consumer>
void Saturation(const jxl::Image3F& image, const Consumer& consumer) {
  for (size_t y = 0; y < image.ysize(); ++y) {
    const float* const JXL_RESTRICT rows[3] = {
        image.PlaneRow(0, y), image.PlaneRow(1, y), image.PlaneRow(2, y)};
    for (size_t x = 0; x < image.xsize(); ++x) {
      // TODO(sboukortt): experiment with other methods of computing the
      // saturation, e.g. C*/L* in LUV/LCh.
      const float mean = (1.f / 3) * (rows[0][x] + rows[1][x] + rows[2][x]);
      const float deviations[3] = {rows[0][x] - mean, rows[1][x] - mean,
                                   rows[2][x] - mean};
      consumer(x, y,
               std::sqrt((1.f / 3) * (deviations[0] * deviations[0] +
                                      deviations[1] * deviations[1] +
                                      deviations[2] * deviations[2])));
    }
  }
}

template <typename Consumer>
void MidToneness(const jxl::Image3F& image, const float sigma,
                 const Consumer& consumer) {
  const float inv_sigma_squared = 1.f / (sigma * sigma);
  const auto Gaussian = [inv_sigma_squared](const float x) {
    return std::exp(-.5f * (x - .5f) * (x - .5f) * inv_sigma_squared);
  };
  for (size_t y = 0; y < image.ysize(); ++y) {
    const float* const JXL_RESTRICT rows[3] = {
        image.PlaneRow(0, y), image.PlaneRow(1, y), image.PlaneRow(2, y)};
    for (size_t x = 0; x < image.xsize(); ++x) {
      consumer(
          x, y,
          Gaussian(rows[0][x]) * Gaussian(rows[1][x]) * Gaussian(rows[2][x]));
    }
  }
}

ImageF ComputeWeights(const jxl::Image3F& image, const float contrast_weight,
                      const float saturation_weight,
                      const float midtoneness_weight,
                      const float midtoneness_sigma, ThreadPool* const pool) {
  ImageF log_weights(image.xsize(), image.ysize());
  ZeroFillImage(&log_weights);

  if (contrast_weight > 0) {
    Contrast(
        image,
        [&log_weights, contrast_weight](const size_t x, const size_t y,
                                        const float weight) {
          log_weights.Row(y)[x] = contrast_weight * std::log(weight);
        },
        pool);
  }

  if (saturation_weight > 0) {
    Saturation(image, [&log_weights, saturation_weight](
                          const size_t x, const size_t y, const float weight) {
      log_weights.Row(y)[x] += saturation_weight * std::log(weight);
    });
  }

  if (midtoneness_weight > 0) {
    MidToneness(image, midtoneness_sigma,
                [&log_weights, midtoneness_weight](
                    const size_t x, const size_t y, const float weight) {
                  log_weights.Row(y)[x] +=
                      midtoneness_weight * std::log(weight);
                });
  }

  ImageF weights = std::move(log_weights);

  for (size_t y = 0; y < weights.ysize(); ++y) {
    float* const JXL_RESTRICT row = weights.Row(y);
    for (size_t x = 0; x < weights.xsize(); ++x) {
      row[x] = std::exp(row[x]);
    }
  }

  return weights;
}

std::vector<ImageF> ComputeWeights(const std::vector<Image3F>& images,
                                   const float contrast_weight,
                                   const float saturation_weight,
                                   const float midtoneness_weight,
                                   const float midtoneness_sigma,
                                   ThreadPool* const pool) {
  std::vector<ImageF> weights;
  weights.reserve(images.size());
  for (const Image3F& image : images) {
    if (image.xsize() != images.front().xsize() ||
        image.ysize() != images.front().ysize()) {
      return {};
    }
    weights.push_back(ComputeWeights(image, contrast_weight, saturation_weight,
                                     midtoneness_weight, midtoneness_sigma,
                                     pool));
  }

  std::vector<float*> rows(images.size());
  for (size_t y = 0; y < images.front().ysize(); ++y) {
    for (size_t i = 0; i < images.size(); ++i) {
      rows[i] = weights[i].Row(y);
    }
    for (size_t x = 0; x < images.front().xsize(); ++x) {
      float sum = 1e-9f;
      for (size_t i = 0; i < images.size(); ++i) {
        sum += rows[i][x];
      }
      const float ratio = 1.f / sum;
      for (size_t i = 0; i < images.size(); ++i) {
        rows[i][x] *= ratio;
      }
    }
  }

  return weights;
}

ImageF Downsample(const ImageF& image, ThreadPool* const pool) {
  ImageF filtered(image.xsize(), image.ysize());
  Separable5(image, Rect(image), kPyramidFilter, pool, &filtered);
  ImageF result(DivCeil(image.xsize(), 2), DivCeil(image.ysize(), 2));
  for (size_t y = 0; y < result.ysize(); ++y) {
    const float* const JXL_RESTRICT filtered_row = filtered.ConstRow(2 * y);
    float* const JXL_RESTRICT row = result.Row(y);
    for (size_t x = 0; x < result.xsize(); ++x) {
      row[x] = filtered_row[2 * x];
    }
  }
  return result;
}

Image3F Downsample(const Image3F& image, ThreadPool* const pool) {
  return Image3F(Downsample(image.Plane(0), pool),
                 Downsample(image.Plane(1), pool),
                 Downsample(image.Plane(2), pool));
}

Image3F PadImageMirror(const Image3F& in, const size_t xborder,
                       const size_t yborder) {
  size_t xsize = in.xsize();
  size_t ysize = in.ysize();
  Image3F out(xsize + 2 * xborder, ysize + 2 * yborder);
  if (xborder > xsize || yborder > ysize) {
    for (size_t c = 0; c < 3; c++) {
      for (int32_t y = 0; y < static_cast<int32_t>(out.ysize()); y++) {
        float* row_out = out.PlaneRow(c, y);
        const float* row_in = in.PlaneRow(
            c, Mirror(y - static_cast<int32_t>(yborder), in.ysize()));
        for (int32_t x = 0; x < static_cast<int32_t>(out.xsize()); x++) {
          int32_t xin = Mirror(x - static_cast<int32_t>(xborder), in.xsize());
          row_out[x] = row_in[xin];
        }
      }
    }
    return out;
  }
  CopyImageTo(Rect(in), in, Rect(xborder, yborder, xsize, ysize), &out);
  for (size_t c = 0; c < 3; c++) {
    // Horizontal pad.
    for (size_t y = 0; y < ysize; y++) {
      for (size_t x = 0; x < xborder; x++) {
        out.PlaneRow(c, y + yborder)[x] =
            in.ConstPlaneRow(c, y)[xborder - x - 1];
        out.PlaneRow(c, y + yborder)[x + xsize + xborder] =
            in.ConstPlaneRow(c, y)[xsize - 1 - x];
      }
    }
    // Vertical pad.
    for (size_t y = 0; y < yborder; y++) {
      memcpy(out.PlaneRow(c, y), out.ConstPlaneRow(c, 2 * yborder - 1 - y),
             out.xsize() * sizeof(float));
      memcpy(out.PlaneRow(c, y + ysize + yborder),
             out.ConstPlaneRow(c, ysize + yborder - 1 - y),
             out.xsize() * sizeof(float));
    }
  }
  return out;
}

Image3F Upsample(const Image3F& image, const bool odd_width,
                 const bool odd_height, ThreadPool* const pool) {
  const Image3F padded = PadImageMirror(image, 1, 1);
  Image3F upsampled(2 * padded.xsize(), 2 * padded.ysize());
  ZeroFillImage(&upsampled);
  for (int c = 0; c < 3; ++c) {
    for (size_t y = 0; y < padded.ysize(); ++y) {
      const float* const JXL_RESTRICT padded_row = padded.ConstPlaneRow(c, y);
      float* const JXL_RESTRICT row = upsampled.PlaneRow(c, 2 * y);
      for (size_t x = 0; x < padded.xsize(); ++x) {
        row[2 * x] = 4 * padded_row[x];
      }
    }
  }
  Image3F filtered(upsampled.xsize(), upsampled.ysize());
  for (int c = 0; c < 3; ++c) {
    Separable5(upsampled.Plane(c), Rect(upsampled), kPyramidFilter, pool,
               &filtered.Plane(c));
  }
  Image3F result(2 * image.xsize() - (odd_width ? 1 : 0),
                 2 * image.ysize() - (odd_height ? 1 : 0));
  CopyImageTo(Rect(2, 2, result.xsize(), result.ysize()), filtered,
              Rect(result), &result);
  return result;
}

std::vector<ImageF> GaussianPyramid(ImageF image, int num_levels,
                                    ThreadPool* pool) {
  std::vector<ImageF> pyramid(num_levels);
  for (int i = 0; i < num_levels - 1; ++i) {
    ImageF downsampled = Downsample(image, pool);
    pyramid[i] = std::move(image);
    image = std::move(downsampled);
  }
  pyramid[num_levels - 1] = std::move(image);
  return pyramid;
}

std::vector<Image3F> LaplacianPyramid(Image3F image, int num_levels,
                                      ThreadPool* pool) {
  std::vector<Image3F> pyramid(num_levels);
  for (int i = 0; i < num_levels - 1; ++i) {
    Image3F downsampled = Downsample(image, pool);
    const bool odd_width = image.xsize() % 2 != 0;
    const bool odd_height = image.ysize() % 2 != 0;
    Subtract(image, Upsample(downsampled, odd_width, odd_height, pool), &image);
    pyramid[i] = std::move(image);
    image = std::move(downsampled);
  }
  pyramid[num_levels - 1] = std::move(image);
  return pyramid;
}

Image3F ReconstructFromLaplacianPyramid(std::vector<Image3F> pyramid,
                                        ThreadPool* const pool) {
  Image3F result = std::move(pyramid.back());
  pyramid.pop_back();
  for (auto it = pyramid.rbegin(); it != pyramid.rend(); ++it) {
    const bool odd_width = it->xsize() % 2 != 0;
    const bool odd_height = it->ysize() % 2 != 0;
    result = Upsample(result, odd_width, odd_height, pool);
    AddTo(Rect(result), *it, &result);
  }
  return result;
}

// Exposure fusion algorithm as described in:
// https://mericam.github.io/exposure_fusion/
//
// That is, given n images of identical size: for each pixel coordinate, one
// weight per input image is computed, indicating how much each input image will
// contribute to the result. There are therefore n weight maps, the sum of which
// is 1 at every pixel.
//
// Those weights are then applied at various scales rather than directly at full
// resolution. To understand how, it helps to familiarize oneself with Laplacian
// and Gaussian pyramids, as described in "The Laplacian Pyramid as a Compact
// Image Code" by P. Burt and E. Adelson:
// http://persci.mit.edu/pub_pdfs/pyramid83.pdf
//
// A Gaussian pyramid of k levels is a sequence of k images in which the first
// image is the original image and each following level is a low-pass-filtered
// version of the previous one. A Laplacian pyramid is obtained from a Gaussian
// pyramid by:
//
//   laplacian_pyramid[i] = gaussian_pyramid[i] − gaussian_pyramid[i + 1].
//   (The last item of the Laplacian pyramid is just the last one from the
//    Gaussian pyramid without subtraction.)
//
// From there, the original image can be reconstructed by adding all the images
// from the Laplacian pyramid together. (If desired, the Gaussian pyramid can be
// reconstructed as well by storing the cumulative sums starting from the end.)
//
// Having established that, the application of the weight images is done by
// constructing a Laplacian pyramid for each input image, as well as a Gaussian
// pyramid for each weight image, and then constructing a Laplacian pyramid such
// that:
//
//   pyramid[i] = sum(laplacian_pyramids[j][i] .* weight_gaussian_pyramids[j][i]
//                      for j in 1..n)
//
// And then reconstructing an image from the pyramid thus obtained.
Image3F ExposureFusion(std::vector<Image3F> images, int num_levels,
                       const float contrast_weight,
                       const float saturation_weight,
                       const float midtoneness_weight,
                       const float midtoneness_sigma, ThreadPool* const pool) {
  std::vector<ImageF> weights =
      ComputeWeights(images, contrast_weight, saturation_weight,
                     midtoneness_weight, midtoneness_sigma, pool);

  std::vector<Image3F> pyramid(num_levels);
  for (size_t i = 0; i < images.size(); ++i) {
    const std::vector<ImageF> weight_pyramid =
        GaussianPyramid(std::move(weights[i]), num_levels, pool);
    const std::vector<Image3F> image_pyramid =
        LaplacianPyramid(std::move(images[i]), num_levels, pool);

    for (int k = 0; k < num_levels; ++k) {
      Image3F product(Product(weight_pyramid[k], image_pyramid[k].Plane(0)),
                      Product(weight_pyramid[k], image_pyramid[k].Plane(1)),
                      Product(weight_pyramid[k], image_pyramid[k].Plane(2)));
      if (pyramid[k].xsize() == 0) {
        pyramid[k] = std::move(product);
      } else {
        AddTo(Rect(product), product, &pyramid[k]);
      }
    }
  }

  return ReconstructFromLaplacianPyramid(std::move(pyramid), pool);
}

}  // namespace
}  // namespace jxl

int main(int argc, const char** argv) {
  jpegxl::tools::ThreadPoolInternal pool;

  jpegxl::tools::CommandLineParser parser;
  float max_nits = 0;
  parser.AddOptionValue('m', "max_nits", "nits",
                        "maximum luminance in the image", &max_nits,
                        &jpegxl::tools::ParseFloat, 0);
  float preserve_saturation = .1f;
  parser.AddOptionValue(
      's', "preserve_saturation", "0..1",
      "to what extent to try and preserve saturation over luminance",
      &preserve_saturation, &jpegxl::tools::ParseFloat, 0);
  int64_t num_levels = -1;
  parser.AddOptionValue('l', "num_levels", "1..",
                        "number of levels in the pyramid", &num_levels,
                        &jpegxl::tools::ParseInt64, 0);
  float contrast_weight = 0.f;
  parser.AddOptionValue('c', "contrast_weight", "0..",
                        "importance of contrast when computing weights",
                        &contrast_weight, &jpegxl::tools::ParseFloat, 0);
  float saturation_weight = .2f;
  parser.AddOptionValue('a', "saturation_weight", "0..",
                        "importance of saturation when computing weights",
                        &saturation_weight, &jpegxl::tools::ParseFloat, 0);
  float midtoneness_weight = 1.f;
  parser.AddOptionValue('t', "midtoneness_weight", "0..",
                        "importance of \"midtoneness\" when computing weights",
                        &midtoneness_weight, &jpegxl::tools::ParseFloat, 0);
  float midtoneness_sigma = .2f;
  parser.AddOptionValue('g', "midtoneness_sigma", "0..",
                        "spread of the function that computes midtoneness",
                        &midtoneness_sigma, &jpegxl::tools::ParseFloat, 0);
  const char* input_filename = nullptr;
  auto input_filename_option = parser.AddPositionalOption(
      "input", true, "input image", &input_filename, 0);
  const char* output_filename = nullptr;
  auto output_filename_option = parser.AddPositionalOption(
      "output", true, "output image", &output_filename, 0);

  if (!parser.Parse(argc, argv)) {
    fprintf(stderr, "See -h for help.\n");
    return EXIT_FAILURE;
  }

  if (parser.HelpFlagPassed()) {
    parser.PrintHelp();
    return EXIT_SUCCESS;
  }

  if (!parser.GetOption(input_filename_option)->matched()) {
    fprintf(stderr, "Missing input filename.\nSee -h for help.\n");
    return EXIT_FAILURE;
  }
  if (!parser.GetOption(output_filename_option)->matched()) {
    fprintf(stderr, "Missing output filename.\nSee -h for help.\n");
    return EXIT_FAILURE;
  }

  jxl::CodecInOut image;
  jxl::extras::ColorHints color_hints;
  color_hints.Add("color_space", "RGB_D65_202_Rel_PeQ");
  std::vector<uint8_t> encoded;
  JXL_CHECK(jpegxl::tools::ReadFile(input_filename, &encoded));
  JXL_CHECK(jxl::SetFromBytes(jxl::Span<const uint8_t>(encoded), color_hints,
                              &image, &pool));

  if (max_nits > 0) {
    image.metadata.m.SetIntensityTarget(max_nits);
  } else {
    max_nits = image.metadata.m.IntensityTarget();
  }

  std::vector<jxl::Image3F> input_images;

  if (max_nits <= 4 * jxl::kDefaultIntensityTarget) {
    jxl::CodecInOut sRGB_image;
    jxl::Image3F color(image.xsize(), image.ysize());
    CopyImageTo(*image.Main().color(), &color);
    sRGB_image.SetFromImage(std::move(color), image.Main().c_current());
    JXL_CHECK(sRGB_image.Main().TransformTo(jxl::ColorEncoding::SRGB(),
                                            jxl::GetJxlCms(), &pool));
    input_images.push_back(std::move(*sRGB_image.Main().color()));
  }

  for (int i = 0; i < 4; ++i) {
    const float target = std::ldexp(jxl::kDefaultIntensityTarget, 2 - i);
    if (target >= max_nits) continue;
    jxl::CodecInOut tone_mapped_image;
    jxl::Image3F color(image.xsize(), image.ysize());
    CopyImageTo(*image.Main().color(), &color);
    tone_mapped_image.SetFromImage(std::move(color), image.Main().c_current());
    tone_mapped_image.metadata.m.SetIntensityTarget(
        image.metadata.m.IntensityTarget());
    JXL_CHECK(jxl::ToneMapTo({0, target}, &tone_mapped_image, &pool));
    JXL_CHECK(jxl::GamutMap(&tone_mapped_image, preserve_saturation, &pool));
    JXL_CHECK(tone_mapped_image.Main().TransformTo(jxl::ColorEncoding::SRGB(),
                                                   jxl::GetJxlCms(), &pool));
    input_images.push_back(std::move(*tone_mapped_image.Main().color()));
  }

  if (num_levels < 1) {
    num_levels = jxl::FloorLog2Nonzero(std::min(image.xsize(), image.ysize()));
  }

  jxl::Image3F fused = jxl::ExposureFusion(
      std::move(input_images), num_levels, contrast_weight, saturation_weight,
      midtoneness_weight, midtoneness_sigma, &pool);

  jxl::CodecInOut output;
  output.SetFromImage(std::move(fused), jxl::ColorEncoding::SRGB());

  JXL_CHECK(jxl::Encode(output, output_filename, &encoded, &pool));
  JXL_CHECK(jpegxl::tools::WriteFile(output_filename, encoded));
}
