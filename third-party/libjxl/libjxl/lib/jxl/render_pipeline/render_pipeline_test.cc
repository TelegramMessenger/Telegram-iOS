// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/render_pipeline/render_pipeline.h"

#include <stdint.h>
#include <stdio.h>

#include <algorithm>
#include <utility>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/jxl/dec_frame.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_file.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/fake_parallel_runner_testonly.h"
#include "lib/jxl/icc_codec.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/jpeg/enc_jpeg_data.h"
#include "lib/jxl/render_pipeline/test_render_pipeline_stages.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

Status DecodeFile(const Span<const uint8_t> file, bool use_slow_pipeline,
                  CodecInOut* io, ThreadPool* pool) {
  Status ret = true;
  {
    BitReader reader(file);
    BitReaderScopedCloser reader_closer(&reader, &ret);
    JXL_RETURN_IF_ERROR(reader.ReadFixedBits<16>() == 0x0AFF);
    JXL_RETURN_IF_ERROR(ReadSizeHeader(&reader, &io->metadata.size));
    JXL_RETURN_IF_ERROR(ReadImageMetadata(&reader, &io->metadata.m));
    io->metadata.transform_data.nonserialized_xyb_encoded =
        io->metadata.m.xyb_encoded;
    JXL_RETURN_IF_ERROR(Bundle::Read(&reader, &io->metadata.transform_data));
    if (io->metadata.m.color_encoding.WantICC()) {
      PaddedBytes icc;
      JXL_RETURN_IF_ERROR(ReadICC(&reader, &icc));
      JXL_RETURN_IF_ERROR(
          io->metadata.m.color_encoding.SetICC(std::move(icc), &GetJxlCms()));
    }
    PassesDecoderState dec_state;
    JXL_RETURN_IF_ERROR(
        dec_state.output_encoding_info.SetFromMetadata(io->metadata));
    JXL_RETURN_IF_ERROR(reader.JumpToByteBoundary());
    io->frames.clear();
    do {
      io->frames.emplace_back(&io->metadata.m);
      // Skip frames that are not displayed.
      do {
        size_t frame_start = reader.TotalBitsConsumed() / kBitsPerByte;
        size_t size_left = file.size() - frame_start;
        JXL_RETURN_IF_ERROR(
            DecodeFrame(&dec_state, pool, file.data() + frame_start, size_left,
                        &io->frames.back(), io->metadata, use_slow_pipeline));
        reader.SkipBits(io->frames.back().decoded_bytes() * kBitsPerByte);
      } while (dec_state.shared->frame_header.frame_type !=
                   FrameType::kRegularFrame &&
               dec_state.shared->frame_header.frame_type !=
                   FrameType::kSkipProgressive);
    } while (!dec_state.shared->frame_header.is_last);

    if (io->frames.empty()) return JXL_FAILURE("Not enough data.");

    if (reader.TotalBitsConsumed() != file.size() * kBitsPerByte) {
      return JXL_FAILURE("Reader position not at EOF.");
    }
    if (!reader.AllReadsWithinBounds()) {
      return JXL_FAILURE("Reader out of bounds read.");
    }
    io->CheckMetadata();
    // reader is closed here.
  }
  return ret;
}

TEST(RenderPipelineTest, Build) {
  RenderPipeline::Builder builder(/*num_c=*/1);
  builder.AddStage(jxl::make_unique<UpsampleXSlowStage>());
  builder.AddStage(jxl::make_unique<UpsampleYSlowStage>());
  builder.AddStage(jxl::make_unique<Check0FinalStage>());
  builder.UseSimpleImplementation();
  FrameDimensions frame_dimensions;
  frame_dimensions.Set(/*xsize=*/1024, /*ysize=*/1024, /*group_size_shift=*/0,
                       /*max_hshift=*/0, /*max_vshift=*/0,
                       /*modular_mode=*/false, /*upsampling=*/1);
  std::move(builder).Finalize(frame_dimensions);
}

TEST(RenderPipelineTest, CallAllGroups) {
  RenderPipeline::Builder builder(/*num_c=*/1);
  builder.AddStage(jxl::make_unique<UpsampleXSlowStage>());
  builder.AddStage(jxl::make_unique<UpsampleYSlowStage>());
  builder.AddStage(jxl::make_unique<Check0FinalStage>());
  builder.UseSimpleImplementation();
  FrameDimensions frame_dimensions;
  frame_dimensions.Set(/*xsize=*/1024, /*ysize=*/1024, /*group_size_shift=*/0,
                       /*max_hshift=*/0, /*max_vshift=*/0,
                       /*modular_mode=*/false, /*upsampling=*/1);
  auto pipeline = std::move(builder).Finalize(frame_dimensions);
  ASSERT_TRUE(pipeline->PrepareForThreads(1, /*use_group_ids=*/false));

  for (size_t i = 0; i < frame_dimensions.num_groups; i++) {
    auto input_buffers = pipeline->GetInputBuffers(i, 0);
    FillPlane(0.0f, input_buffers.GetBuffer(0).first,
              input_buffers.GetBuffer(0).second);
    input_buffers.Done();
  }

  EXPECT_EQ(pipeline->PassesWithAllInput(), 1);
}

TEST(RenderPipelineTest, BuildFast) {
  RenderPipeline::Builder builder(/*num_c=*/1);
  builder.AddStage(jxl::make_unique<UpsampleXSlowStage>());
  builder.AddStage(jxl::make_unique<UpsampleYSlowStage>());
  builder.AddStage(jxl::make_unique<Check0FinalStage>());
  FrameDimensions frame_dimensions;
  frame_dimensions.Set(/*xsize=*/1024, /*ysize=*/1024, /*group_size_shift=*/0,
                       /*max_hshift=*/0, /*max_vshift=*/0,
                       /*modular_mode=*/false, /*upsampling=*/1);
  std::move(builder).Finalize(frame_dimensions);
}

TEST(RenderPipelineTest, CallAllGroupsFast) {
  RenderPipeline::Builder builder(/*num_c=*/1);
  builder.AddStage(jxl::make_unique<UpsampleXSlowStage>());
  builder.AddStage(jxl::make_unique<UpsampleYSlowStage>());
  builder.AddStage(jxl::make_unique<Check0FinalStage>());
  builder.UseSimpleImplementation();
  FrameDimensions frame_dimensions;
  frame_dimensions.Set(/*xsize=*/1024, /*ysize=*/1024, /*group_size_shift=*/0,
                       /*max_hshift=*/0, /*max_vshift=*/0,
                       /*modular_mode=*/false, /*upsampling=*/1);
  auto pipeline = std::move(builder).Finalize(frame_dimensions);
  ASSERT_TRUE(pipeline->PrepareForThreads(1, /*use_group_ids=*/false));

  for (size_t i = 0; i < frame_dimensions.num_groups; i++) {
    auto input_buffers = pipeline->GetInputBuffers(i, 0);
    FillPlane(0.0f, input_buffers.GetBuffer(0).first,
              input_buffers.GetBuffer(0).second);
    input_buffers.Done();
  }

  EXPECT_EQ(pipeline->PassesWithAllInput(), 1);
}

struct RenderPipelineTestInputSettings {
  // Input image.
  std::string input_path;
  size_t xsize, ysize;
  bool jpeg_transcode = false;
  // Encoding settings.
  CompressParams cparams;
  // Short name for the encoder settings.
  std::string cparams_descr;

  bool add_spot_color = false;

  Splines splines;
};

class RenderPipelineTestParam
    : public ::testing::TestWithParam<RenderPipelineTestInputSettings> {};

TEST_P(RenderPipelineTestParam, PipelineTest) {
  RenderPipelineTestInputSettings config = GetParam();

  // Use a parallel runner that randomly shuffles tasks to detect possible
  // border handling bugs.
  FakeParallelRunner fake_pool(/*order_seed=*/123, /*num_threads=*/8);
  ThreadPool pool(&JxlFakeParallelRunner, &fake_pool);
  const PaddedBytes orig = jxl::test::ReadTestData(config.input_path);

  CodecInOut io;
  if (config.jpeg_transcode) {
    ASSERT_TRUE(jpeg::DecodeImageJPG(Span<const uint8_t>(orig), &io));
  } else {
    ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io, &pool));
  }
  io.ShrinkTo(config.xsize, config.ysize);

  if (config.add_spot_color) {
    jxl::ImageF spot(config.xsize, config.ysize);
    jxl::ZeroFillImage(&spot);

    for (size_t y = 0; y < config.ysize; y++) {
      float* JXL_RESTRICT row = spot.Row(y);
      for (size_t x = 0; x < config.xsize; x++) {
        row[x] = ((x ^ y) & 255) * (1.f / 255.f);
      }
    }
    ExtraChannelInfo info;
    info.bit_depth.bits_per_sample = 8;
    info.dim_shift = 0;
    info.type = jxl::ExtraChannel::kSpotColor;
    info.spot_color[0] = 0.5f;
    info.spot_color[1] = 0.2f;
    info.spot_color[2] = 1.f;
    info.spot_color[3] = 0.5f;

    io.metadata.m.extra_channel_info.push_back(info);
    std::vector<jxl::ImageF> ec;
    ec.push_back(std::move(spot));
    io.frames[0].SetExtraChannels(std::move(ec));
  }

  PaddedBytes compressed;

  PassesEncoderState enc_state;
  enc_state.shared.image_features.splines = config.splines;
  ASSERT_TRUE(EncodeFile(config.cparams, &io, &enc_state, &compressed,
                         GetJxlCms(), /*aux_out=*/nullptr, &pool));

  CodecInOut io_default;
  ASSERT_TRUE(DecodeFile(Span<const uint8_t>(compressed),
                         /*use_slow_pipeline=*/false, &io_default, &pool));
  CodecInOut io_slow_pipeline;
  ASSERT_TRUE(DecodeFile(Span<const uint8_t>(compressed),
                         /*use_slow_pipeline=*/true, &io_slow_pipeline, &pool));

  ASSERT_EQ(io_default.frames.size(), io_slow_pipeline.frames.size());
  for (size_t i = 0; i < io_default.frames.size(); i++) {
#if JXL_HIGH_PRECISION
    constexpr float kMaxError = 1e-5;
#else
    constexpr float kMaxError = 5e-4;
#endif
    Image3F def = std::move(*io_default.frames[i].color());
    Image3F pip = std::move(*io_slow_pipeline.frames[i].color());
    JXL_ASSERT_OK(VerifyRelativeError(pip, def, kMaxError, kMaxError, _));
    for (size_t ec = 0; ec < io_default.frames[i].extra_channels().size();
         ec++) {
      JXL_ASSERT_OK(VerifyRelativeError(
          io_slow_pipeline.frames[i].extra_channels()[ec],
          io_default.frames[i].extra_channels()[ec], kMaxError, kMaxError, _));
    }
  }
}

Splines CreateTestSplines() {
  const ColorCorrelationMap cmap;
  std::vector<Spline::Point> control_points{{9, 54},  {118, 159}, {97, 3},
                                            {10, 40}, {150, 25},  {120, 300}};
  const Spline spline{
      control_points,
      /*color_dct=*/
      {{0.03125f, 0.00625f, 0.003125f}, {1.f, 0.321875f}, {1.f, 0.24375f}},
      /*sigma_dct=*/{0.3125f, 0.f, 0.f, 0.0625f}};
  std::vector<Spline> spline_data = {spline};
  std::vector<QuantizedSpline> quantized_splines;
  std::vector<Spline::Point> starting_points;
  for (const Spline& spline : spline_data) {
    quantized_splines.emplace_back(spline, /*quantization_adjustment=*/0,
                                   cmap.YtoXRatio(0), cmap.YtoBRatio(0));
    starting_points.push_back(spline.control_points.front());
  }
  return Splines(/*quantization_adjustment=*/0, std::move(quantized_splines),
                 std::move(starting_points));
}

std::vector<RenderPipelineTestInputSettings> GeneratePipelineTests() {
  std::vector<RenderPipelineTestInputSettings> all_tests;

  std::pair<size_t, size_t> sizes[] = {
      {3, 8}, {128, 128}, {256, 256}, {258, 258}, {533, 401}, {777, 777},
  };

  for (auto size : sizes) {
    RenderPipelineTestInputSettings settings;
    settings.input_path = "jxl/flower/flower.png";
    settings.xsize = size.first;
    settings.ysize = size.second;

    // Base settings.
    settings.cparams.butteraugli_distance = 1.0;
    settings.cparams.patches = Override::kOff;
    settings.cparams.dots = Override::kOff;
    settings.cparams.gaborish = Override::kOff;
    settings.cparams.epf = 0;
    settings.cparams.color_transform = ColorTransform::kXYB;

    {
      auto s = settings;
      s.cparams_descr = "NoGabNoEpfNoPatches";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams.color_transform = ColorTransform::kNone;
      s.cparams_descr = "NoGabNoEpfNoPatchesNoXYB";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams.gaborish = Override::kOn;
      s.cparams_descr = "GabNoEpfNoPatches";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams.epf = 1;
      s.cparams_descr = "NoGabEpf1NoPatches";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams.epf = 2;
      s.cparams_descr = "NoGabEpf2NoPatches";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams.epf = 3;
      s.cparams_descr = "NoGabEpf3NoPatches";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams.gaborish = Override::kOn;
      s.cparams.epf = 3;
      s.cparams_descr = "GabEpf3NoPatches";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams_descr = "Splines";
      s.splines = CreateTestSplines();
      all_tests.push_back(s);
    }

    for (size_t ups : {2, 4, 8}) {
      {
        auto s = settings;
        s.cparams.resampling = ups;
        s.cparams_descr = "Ups" + std::to_string(ups);
        all_tests.push_back(s);
      }
      {
        auto s = settings;
        s.cparams.resampling = ups;
        s.cparams.epf = 1;
        s.cparams_descr = "Ups" + std::to_string(ups) + "EPF1";
        all_tests.push_back(s);
      }
      {
        auto s = settings;
        s.cparams.resampling = ups;
        s.cparams.gaborish = Override::kOn;
        s.cparams.epf = 1;
        s.cparams_descr = "Ups" + std::to_string(ups) + "GabEPF1";
        all_tests.push_back(s);
      }
    }

    {
      auto s = settings;
      s.cparams_descr = "Noise";
      s.cparams.photon_noise_iso = 3200;
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams_descr = "NoiseUps";
      s.cparams.photon_noise_iso = 3200;
      s.cparams.resampling = 2;
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams_descr = "ModularLossless";
      s.cparams.modular_mode = true;
      s.cparams.butteraugli_distance = 0;
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams_descr = "ProgressiveDC";
      s.cparams.progressive_dc = 1;
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams_descr = "ModularLossy";
      s.cparams.modular_mode = true;
      s.cparams.butteraugli_distance = 1.f;
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.input_path = "jxl/flower/flower_alpha.png";
      s.cparams_descr = "AlphaVarDCT";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.input_path = "jxl/flower/flower_alpha.png";
      s.cparams_descr = "AlphaVarDCTUpsamplingEPF";
      s.cparams.epf = 1;
      s.cparams.ec_resampling = 2;
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams.modular_mode = true;
      s.cparams.butteraugli_distance = 0;
      s.input_path = "jxl/flower/flower_alpha.png";
      s.cparams_descr = "AlphaLossless";
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.input_path = "jxl/flower/flower_alpha.png";
      s.cparams_descr = "AlphaDownsample";
      s.cparams.ec_resampling = 2;
      all_tests.push_back(s);
    }

    {
      auto s = settings;
      s.cparams_descr = "SpotColor";
      s.add_spot_color = true;
      all_tests.push_back(s);
    }
  }

#if JPEGXL_ENABLE_TRANSCODE_JPEG
  for (const char* input : {"jxl/flower/flower.png.im_q85_444.jpg",
                            "jxl/flower/flower.png.im_q85_420.jpg",
                            "jxl/flower/flower.png.im_q85_422.jpg",
                            "jxl/flower/flower.png.im_q85_440.jpg"}) {
    RenderPipelineTestInputSettings settings;
    settings.input_path = input;
    settings.jpeg_transcode = true;
    settings.xsize = 2268;
    settings.ysize = 1512;
    settings.cparams_descr = "Default";
    all_tests.push_back(settings);
  }

#endif

  {
    RenderPipelineTestInputSettings settings;
    settings.input_path = "jxl/grayscale_patches.png";
    settings.xsize = 1011;
    settings.ysize = 277;
    settings.cparams_descr = "Patches";
    all_tests.push_back(settings);
  }

  {
    RenderPipelineTestInputSettings settings;
    settings.input_path = "jxl/grayscale_patches.png";
    settings.xsize = 1011;
    settings.ysize = 277;
    settings.cparams.photon_noise_iso = 1000;
    settings.cparams_descr = "PatchesAndNoise";
    all_tests.push_back(settings);
  }

  {
    RenderPipelineTestInputSettings settings;
    settings.input_path = "jxl/grayscale_patches.png";
    settings.xsize = 1011;
    settings.ysize = 277;
    settings.cparams.resampling = 2;
    settings.cparams_descr = "PatchesAndUps2";
    all_tests.push_back(settings);
  }

  return all_tests;
}

std::ostream& operator<<(std::ostream& os,
                         const RenderPipelineTestInputSettings& c) {
  std::string filename;
  size_t pos = c.input_path.find_last_of('/');
  if (pos == std::string::npos) {
    filename = c.input_path;
  } else {
    filename = c.input_path.substr(pos + 1);
  }
  std::replace_if(
      filename.begin(), filename.end(), [](char c) { return !isalnum(c); },
      '_');
  os << filename << "_" << (c.jpeg_transcode ? "JPEG_" : "") << c.xsize << "x"
     << c.ysize << "_" << c.cparams_descr;
  return os;
}

std::string PipelineTestDescription(
    const testing::TestParamInfo<RenderPipelineTestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JXL_GTEST_INSTANTIATE_TEST_SUITE_P(RenderPipelineTest, RenderPipelineTestParam,
                                   testing::ValuesIn(GeneratePipelineTests()),
                                   PipelineTestDescription);

TEST(RenderPipelineDecodingTest, Animation) {
  FakeParallelRunner fake_pool(/*order_seed=*/123, /*num_threads=*/8);
  ThreadPool pool(&JxlFakeParallelRunner, &fake_pool);

  PaddedBytes compressed =
      jxl::test::ReadTestData("jxl/blending/cropped_traffic_light.jxl");

  CodecInOut io_default;
  ASSERT_TRUE(DecodeFile(Span<const uint8_t>(compressed),
                         /*use_slow_pipeline=*/false, &io_default, &pool));
  CodecInOut io_slow_pipeline;
  ASSERT_TRUE(DecodeFile(Span<const uint8_t>(compressed),
                         /*use_slow_pipeline=*/true, &io_slow_pipeline, &pool));

  ASSERT_EQ(io_default.frames.size(), io_slow_pipeline.frames.size());
  for (size_t i = 0; i < io_default.frames.size(); i++) {
#if JXL_HIGH_PRECISION
    constexpr float kMaxError = 1e-5;
#else
    constexpr float kMaxError = 1e-4;
#endif

    Image3F fast_pipeline = std::move(*io_default.frames[i].color());
    Image3F slow_pipeline = std::move(*io_slow_pipeline.frames[i].color());
    JXL_ASSERT_OK(VerifyRelativeError(slow_pipeline, fast_pipeline, kMaxError,
                                      kMaxError, _))
    for (size_t ec = 0; ec < io_default.frames[i].extra_channels().size();
         ec++) {
      JXL_ASSERT_OK(VerifyRelativeError(
          io_slow_pipeline.frames[i].extra_channels()[ec],
          io_default.frames[i].extra_channels()[ec], kMaxError, kMaxError, _));
    }
  }
}

}  // namespace
}  // namespace jxl
