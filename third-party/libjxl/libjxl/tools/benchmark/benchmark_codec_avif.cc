// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
#include "tools/benchmark/benchmark_codec_avif.h"

#include <avif/avif.h>

#include "lib/extras/time.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/dec_external_image.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_external_image.h"
#include "tools/cmdline.h"
#include "tools/thread_pool_internal.h"

#define JXL_RETURN_IF_AVIF_ERROR(result)                                       \
  do {                                                                         \
    avifResult jxl_return_if_avif_error_result = (result);                     \
    if (jxl_return_if_avif_error_result != AVIF_RESULT_OK) {                   \
      return JXL_FAILURE("libavif error: %s",                                  \
                         avifResultToString(jxl_return_if_avif_error_result)); \
    }                                                                          \
  } while (false)

namespace jpegxl {
namespace tools {

using ::jxl::CodecInOut;
using ::jxl::ImageBundle;
using ::jxl::PaddedBytes;
using ::jxl::Primaries;
using ::jxl::Span;
using ::jxl::ThreadPool;
using ::jxl::TransferFunction;
using ::jxl::WhitePoint;

namespace {

size_t GetNumThreads(ThreadPool* pool) {
  size_t result = 0;
  const auto count_threads = [&](const size_t num_threads) {
    result = num_threads;
    return true;
  };
  const auto no_op = [&](const uint32_t /*task*/, size_t /*thread*/) {};
  (void)jxl::RunOnPool(pool, 0, 1, count_threads, no_op, "Compress");
  return result;
}

struct AvifArgs {
  avifPixelFormat chroma_subsampling = AVIF_PIXEL_FORMAT_YUV444;
};

AvifArgs* const avifargs = new AvifArgs;

bool ParseChromaSubsampling(const char* arg, avifPixelFormat* subsampling) {
  if (strcmp(arg, "444") == 0) {
    *subsampling = AVIF_PIXEL_FORMAT_YUV444;
    return true;
  }
  if (strcmp(arg, "422") == 0) {
    *subsampling = AVIF_PIXEL_FORMAT_YUV422;
    return true;
  }
  if (strcmp(arg, "420") == 0) {
    *subsampling = AVIF_PIXEL_FORMAT_YUV420;
    return true;
  }
  if (strcmp(arg, "400") == 0) {
    *subsampling = AVIF_PIXEL_FORMAT_YUV400;
    return true;
  }
  return false;
}

void SetUpAvifColor(const ColorEncoding& color, avifImage* const image) {
  bool need_icc = (color.white_point != WhitePoint::kD65);

  image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT709;
  if (!color.HasPrimaries()) {
    need_icc = true;
  } else {
    switch (color.primaries) {
      case Primaries::kSRGB:
        image->colorPrimaries = AVIF_COLOR_PRIMARIES_BT709;
        break;
      case Primaries::k2100:
        image->colorPrimaries = AVIF_COLOR_PRIMARIES_BT2020;
        image->matrixCoefficients = AVIF_MATRIX_COEFFICIENTS_BT2020_NCL;
        break;
      default:
        need_icc = true;
        image->colorPrimaries = AVIF_COLOR_PRIMARIES_UNKNOWN;
        break;
    }
  }

  switch (color.tf.GetTransferFunction()) {
    case TransferFunction::kSRGB:
      image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SRGB;
      break;
    case TransferFunction::kLinear:
      image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_LINEAR;
      break;
    case TransferFunction::kPQ:
      image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084;
      break;
    case TransferFunction::kHLG:
      image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_HLG;
      break;
    default:
      need_icc = true;
      image->transferCharacteristics = AVIF_TRANSFER_CHARACTERISTICS_UNKNOWN;
      break;
  }

  if (need_icc) {
    avifImageSetProfileICC(image, color.ICC().data(), color.ICC().size());
  }
}

Status ReadAvifColor(const avifImage* const image, ColorEncoding* const color) {
  if (image->icc.size != 0) {
    PaddedBytes icc;
    icc.assign(image->icc.data, image->icc.data + image->icc.size);
    return color->SetICC(std::move(icc), &jxl::GetJxlCms());
  }

  color->white_point = WhitePoint::kD65;
  switch (image->colorPrimaries) {
    case AVIF_COLOR_PRIMARIES_BT709:
      color->primaries = Primaries::kSRGB;
      break;
    case AVIF_COLOR_PRIMARIES_BT2020:
      color->primaries = Primaries::k2100;
      break;
    default:
      return JXL_FAILURE("unsupported avif primaries");
  }
  switch (image->transferCharacteristics) {
    case AVIF_TRANSFER_CHARACTERISTICS_BT470M:
      JXL_RETURN_IF_ERROR(color->tf.SetGamma(2.2));
      break;
    case AVIF_TRANSFER_CHARACTERISTICS_BT470BG:
      JXL_RETURN_IF_ERROR(color->tf.SetGamma(2.8));
      break;
    case AVIF_TRANSFER_CHARACTERISTICS_LINEAR:
      color->tf.SetTransferFunction(TransferFunction::kLinear);
      break;
    case AVIF_TRANSFER_CHARACTERISTICS_SRGB:
      color->tf.SetTransferFunction(TransferFunction::kSRGB);
      break;
    case AVIF_TRANSFER_CHARACTERISTICS_SMPTE2084:
      color->tf.SetTransferFunction(TransferFunction::kPQ);
      break;
    case AVIF_TRANSFER_CHARACTERISTICS_HLG:
      color->tf.SetTransferFunction(TransferFunction::kHLG);
      break;
    default:
      return JXL_FAILURE("unsupported avif TRC");
  }
  return color->CreateICC();
}

}  // namespace

Status AddCommandLineOptionsAvifCodec(BenchmarkArgs* args) {
  args->cmdline.AddOptionValue(
      '\0', "avif_chroma_subsampling", "444/422/420/400",
      "default AVIF chroma subsampling (default: 444).",
      &avifargs->chroma_subsampling, &ParseChromaSubsampling);
  return true;
}

class AvifCodec : public ImageCodec {
 public:
  explicit AvifCodec(const BenchmarkArgs& args) : ImageCodec(args) {
    chroma_subsampling_ = avifargs->chroma_subsampling;
  }

  Status ParseParam(const std::string& param) override {
    if (param.compare(0, 3, "yuv") == 0) {
      if (param.size() != 6) return false;
      return ParseChromaSubsampling(param.c_str() + 3, &chroma_subsampling_);
    }
    if (param.compare(0, 10, "log2_cols=") == 0) {
      log2_cols = strtol(param.c_str() + 10, nullptr, 10);
      return true;
    }
    if (param.compare(0, 10, "log2_rows=") == 0) {
      log2_rows = strtol(param.c_str() + 10, nullptr, 10);
      return true;
    }
    if (param[0] == 's') {
      speed_ = strtol(param.c_str() + 1, nullptr, 10);
      return true;
    }
    if (param == "aomenc") {
      encoder_ = AVIF_CODEC_CHOICE_AOM;
      return true;
    }
    if (param == "aomdec") {
      decoder_ = AVIF_CODEC_CHOICE_AOM;
      return true;
    }
    if (param == "aom") {
      encoder_ = AVIF_CODEC_CHOICE_AOM;
      decoder_ = AVIF_CODEC_CHOICE_AOM;
      return true;
    }
    if (param == "rav1e") {
      encoder_ = AVIF_CODEC_CHOICE_RAV1E;
      return true;
    }
    if (param == "dav1d") {
      decoder_ = AVIF_CODEC_CHOICE_DAV1D;
      return true;
    }
    if (param.compare(0, 2, "a=") == 0) {
      std::string subparam = param.substr(2);
      size_t pos = subparam.find('=');
      if (pos == std::string::npos) {
        codec_specific_options_.emplace_back(subparam, "");
      } else {
        std::string key = subparam.substr(0, pos);
        std::string value = subparam.substr(pos + 1);
        codec_specific_options_.emplace_back(key, value);
      }
      return true;
    }
    return ImageCodec::ParseParam(param);
  }

  Status Compress(const std::string& filename, const CodecInOut* io,
                  ThreadPool* pool, std::vector<uint8_t>* compressed,
                  SpeedStats* speed_stats) override {
    double elapsed_convert_image = 0;
    size_t max_threads = GetNumThreads(pool);
    const double start = jxl::Now();
    {
      const auto depth =
          std::min<int>(16, io->metadata.m.bit_depth.bits_per_sample);
      std::unique_ptr<avifEncoder, void (*)(avifEncoder*)> encoder(
          avifEncoderCreate(), &avifEncoderDestroy);
      encoder->codecChoice = encoder_;
      // TODO(sboukortt): configure this separately.
      encoder->minQuantizer = 0;
      encoder->maxQuantizer = 63;
      encoder->tileColsLog2 = log2_cols;
      encoder->tileRowsLog2 = log2_rows;
      encoder->speed = speed_;
      encoder->maxThreads = max_threads;
      for (const auto& opts : codec_specific_options_) {
        avifEncoderSetCodecSpecificOption(encoder.get(), opts.first.c_str(),
                                          opts.second.c_str());
      }
      avifAddImageFlags add_image_flags = AVIF_ADD_IMAGE_FLAG_SINGLE;
      if (io->metadata.m.have_animation) {
        encoder->timescale = std::lround(
            static_cast<float>(io->metadata.m.animation.tps_numerator) /
            io->metadata.m.animation.tps_denominator);
        add_image_flags = AVIF_ADD_IMAGE_FLAG_NONE;
      }
      for (const ImageBundle& ib : io->frames) {
        std::unique_ptr<avifImage, void (*)(avifImage*)> image(
            avifImageCreate(ib.xsize(), ib.ysize(), depth, chroma_subsampling_),
            &avifImageDestroy);
        image->width = ib.xsize();
        image->height = ib.ysize();
        image->depth = depth;
        SetUpAvifColor(ib.c_current(), image.get());
        std::unique_ptr<avifRWData, void (*)(avifRWData*)> icc_freer(
            &image->icc, &avifRWDataFree);
        avifRGBImage rgb_image;
        avifRGBImageSetDefaults(&rgb_image, image.get());
        rgb_image.format =
            ib.HasAlpha() ? AVIF_RGB_FORMAT_RGBA : AVIF_RGB_FORMAT_RGB;
        avifRGBImageAllocatePixels(&rgb_image);
        std::unique_ptr<avifRGBImage, void (*)(avifRGBImage*)> pixels_freer(
            &rgb_image, &avifRGBImageFreePixels);
        const double start_convert_image = jxl::Now();
        JXL_RETURN_IF_ERROR(ConvertToExternal(
            ib, depth, /*float_out=*/false,
            /*num_channels=*/ib.HasAlpha() ? 4 : 3, JXL_NATIVE_ENDIAN,
            /*stride=*/rgb_image.rowBytes, pool, rgb_image.pixels,
            rgb_image.rowBytes * rgb_image.height,
            /*out_callback=*/{}, jxl::Orientation::kIdentity));
        const double end_convert_image = jxl::Now();
        elapsed_convert_image += end_convert_image - start_convert_image;
        JXL_RETURN_IF_AVIF_ERROR(avifImageRGBToYUV(image.get(), &rgb_image));
        JXL_RETURN_IF_AVIF_ERROR(avifEncoderAddImage(
            encoder.get(), image.get(), ib.duration, add_image_flags));
      }
      avifRWData buffer = AVIF_DATA_EMPTY;
      JXL_RETURN_IF_AVIF_ERROR(avifEncoderFinish(encoder.get(), &buffer));
      compressed->assign(buffer.data, buffer.data + buffer.size);
      avifRWDataFree(&buffer);
    }
    const double end = jxl::Now();
    speed_stats->NotifyElapsed(end - start - elapsed_convert_image);
    return true;
  }

  Status Decompress(const std::string& filename,
                    const Span<const uint8_t> compressed, ThreadPool* pool,
                    CodecInOut* io, SpeedStats* speed_stats) override {
    io->frames.clear();
    size_t max_threads = GetNumThreads(pool);
    double elapsed_convert_image = 0;
    const double start = jxl::Now();
    {
      std::unique_ptr<avifDecoder, void (*)(avifDecoder*)> decoder(
          avifDecoderCreate(), &avifDecoderDestroy);
      decoder->codecChoice = decoder_;
      decoder->maxThreads = max_threads;
      JXL_RETURN_IF_AVIF_ERROR(avifDecoderSetIOMemory(
          decoder.get(), compressed.data(), compressed.size()));
      JXL_RETURN_IF_AVIF_ERROR(avifDecoderParse(decoder.get()));
      const bool has_alpha = decoder->alphaPresent;
      io->metadata.m.have_animation = decoder->imageCount > 1;
      io->metadata.m.animation.tps_numerator = decoder->timescale;
      io->metadata.m.animation.tps_denominator = 1;
      io->metadata.m.SetUintSamples(decoder->image->depth);
      io->SetSize(decoder->image->width, decoder->image->height);
      avifResult next_image;
      while ((next_image = avifDecoderNextImage(decoder.get())) ==
             AVIF_RESULT_OK) {
        ColorEncoding color;
        JXL_RETURN_IF_ERROR(ReadAvifColor(decoder->image, &color));
        avifRGBImage rgb_image;
        avifRGBImageSetDefaults(&rgb_image, decoder->image);
        rgb_image.format =
            has_alpha ? AVIF_RGB_FORMAT_RGBA : AVIF_RGB_FORMAT_RGB;
        avifRGBImageAllocatePixels(&rgb_image);
        std::unique_ptr<avifRGBImage, void (*)(avifRGBImage*)> pixels_freer(
            &rgb_image, &avifRGBImageFreePixels);
        JXL_RETURN_IF_AVIF_ERROR(avifImageYUVToRGB(decoder->image, &rgb_image));
        const double start_convert_image = jxl::Now();
        {
          JxlPixelFormat format = {
              (has_alpha ? 4u : 3u),
              (rgb_image.depth <= 8 ? JXL_TYPE_UINT8 : JXL_TYPE_UINT16),
              JXL_NATIVE_ENDIAN, 0};
          ImageBundle ib(&io->metadata.m);
          JXL_RETURN_IF_ERROR(ConvertFromExternal(
              Span<const uint8_t>(rgb_image.pixels,
                                  rgb_image.height * rgb_image.rowBytes),
              rgb_image.width, rgb_image.height, color, rgb_image.depth, format,
              pool, &ib));
          io->frames.push_back(std::move(ib));
        }
        const double end_convert_image = jxl::Now();
        elapsed_convert_image += end_convert_image - start_convert_image;
      }
      if (next_image != AVIF_RESULT_NO_IMAGES_REMAINING) {
        JXL_RETURN_IF_AVIF_ERROR(next_image);
      }
    }
    const double end = jxl::Now();
    speed_stats->NotifyElapsed(end - start - elapsed_convert_image);
    return true;
  }

 protected:
  avifPixelFormat chroma_subsampling_;
  avifCodecChoice encoder_ = AVIF_CODEC_CHOICE_AUTO;
  avifCodecChoice decoder_ = AVIF_CODEC_CHOICE_AUTO;
  int speed_ = AVIF_SPEED_DEFAULT;
  int log2_cols = 0;
  int log2_rows = 0;
  std::vector<std::pair<std::string, std::string>> codec_specific_options_;
};

ImageCodec* CreateNewAvifCodec(const BenchmarkArgs& args) {
  return new AvifCodec(args);
}

}  // namespace tools
}  // namespace jpegxl
