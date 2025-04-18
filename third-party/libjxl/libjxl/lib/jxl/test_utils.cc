// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/test_utils.h"

#include <fstream>
#include <memory>
#include <string>
#include <vector>

#include "lib/extras/metrics.h"
#include "lib/extras/packed_image_convert.h"
#include "lib/jxl/base/float.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_external_image.h"
#include "lib/jxl/enc_file.h"

#if !defined(TEST_DATA_PATH)
#include "tools/cpp/runfiles/runfiles.h"
#endif

namespace jxl {
namespace test {

#if defined(TEST_DATA_PATH)
std::string GetTestDataPath(const std::string& filename) {
  return std::string(TEST_DATA_PATH "/") + filename;
}
#else
using bazel::tools::cpp::runfiles::Runfiles;
const std::unique_ptr<Runfiles> kRunfiles(Runfiles::Create(""));
std::string GetTestDataPath(const std::string& filename) {
  std::string root(JPEGXL_ROOT_PACKAGE "/testdata/");
  return kRunfiles->Rlocation(root + filename);
}
#endif

PaddedBytes ReadTestData(const std::string& filename) {
  std::string full_path = GetTestDataPath(filename);
  fprintf(stderr, "ReadTestData %s\n", full_path.c_str());
  std::ifstream file(full_path, std::ios::binary);
  std::vector<char> str((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());
  JXL_CHECK(file.good());
  const uint8_t* raw = reinterpret_cast<const uint8_t*>(str.data());
  std::vector<uint8_t> data(raw, raw + str.size());
  printf("Test data %s is %d bytes long.\n", filename.c_str(),
         static_cast<int>(data.size()));
  PaddedBytes result;
  result.append(data);
  return result;
}

void DefaultAcceptedFormats(extras::JXLDecompressParams& dparams) {
  if (dparams.accepted_formats.empty()) {
    for (const uint32_t num_channels : {1, 2, 3, 4}) {
      dparams.accepted_formats.push_back(
          {num_channels, JXL_TYPE_FLOAT, JXL_LITTLE_ENDIAN, /*align=*/0});
    }
  }
}

Status DecodeFile(extras::JXLDecompressParams dparams,
                  const Span<const uint8_t> file, CodecInOut* JXL_RESTRICT io,
                  ThreadPool* pool) {
  DefaultAcceptedFormats(dparams);
  SetThreadParallelRunner(dparams, pool);
  extras::PackedPixelFile ppf;
  JXL_RETURN_IF_ERROR(DecodeImageJXL(file.data(), file.size(), dparams,
                                     /*decoded_bytes=*/nullptr, &ppf));
  JXL_RETURN_IF_ERROR(ConvertPackedPixelFileToCodecInOut(ppf, pool, io));
  return true;
}

void JxlBasicInfoSetFromPixelFormat(JxlBasicInfo* basic_info,
                                    const JxlPixelFormat* pixel_format) {
  JxlEncoderInitBasicInfo(basic_info);
  switch (pixel_format->data_type) {
    case JXL_TYPE_FLOAT:
      basic_info->bits_per_sample = 32;
      basic_info->exponent_bits_per_sample = 8;
      break;
    case JXL_TYPE_FLOAT16:
      basic_info->bits_per_sample = 16;
      basic_info->exponent_bits_per_sample = 5;
      break;
    case JXL_TYPE_UINT8:
      basic_info->bits_per_sample = 8;
      basic_info->exponent_bits_per_sample = 0;
      break;
    case JXL_TYPE_UINT16:
      basic_info->bits_per_sample = 16;
      basic_info->exponent_bits_per_sample = 0;
      break;
    default:
      JXL_ABORT("Unhandled JxlDataType");
  }
  if (pixel_format->num_channels < 3) {
    basic_info->num_color_channels = 1;
  } else {
    basic_info->num_color_channels = 3;
  }
  if (pixel_format->num_channels == 2 || pixel_format->num_channels == 4) {
    basic_info->alpha_exponent_bits = basic_info->exponent_bits_per_sample;
    basic_info->alpha_bits = basic_info->bits_per_sample;
    basic_info->num_extra_channels = 1;
  } else {
    basic_info->alpha_exponent_bits = 0;
    basic_info->alpha_bits = 0;
  }
}

ColorEncoding ColorEncodingFromDescriptor(const ColorEncodingDescriptor& desc) {
  ColorEncoding c;
  c.SetColorSpace(desc.color_space);
  if (desc.color_space != ColorSpace::kXYB) {
    c.white_point = desc.white_point;
    c.primaries = desc.primaries;
    c.tf.SetTransferFunction(desc.tf);
  }
  c.rendering_intent = desc.rendering_intent;
  JXL_CHECK(c.CreateICC());
  return c;
}

namespace {
void CheckSameEncodings(const std::vector<ColorEncoding>& a,
                        const std::vector<ColorEncoding>& b,
                        const std::string& check_name,
                        std::stringstream& failures) {
  JXL_CHECK(a.size() == b.size());
  for (size_t i = 0; i < a.size(); ++i) {
    if ((a[i].ICC() == b[i].ICC()) ||
        ((a[i].primaries == b[i].primaries) && a[i].tf.IsSame(b[i].tf))) {
      continue;
    }
    failures << "CheckSameEncodings " << check_name << ": " << i
             << "-th encoding mismatch\n";
  }
}
}  // namespace

bool Roundtrip(const CodecInOut* io, const CompressParams& cparams,
               extras::JXLDecompressParams dparams,
               CodecInOut* JXL_RESTRICT io2, std::stringstream& failures,
               size_t* compressed_size, ThreadPool* pool, AuxOut* aux_out) {
  DefaultAcceptedFormats(dparams);
  if (compressed_size) {
    *compressed_size = static_cast<size_t>(-1);
  }
  PaddedBytes compressed;

  std::vector<ColorEncoding> original_metadata_encodings;
  std::vector<ColorEncoding> original_current_encodings;
  std::vector<ColorEncoding> metadata_encodings_1;
  std::vector<ColorEncoding> metadata_encodings_2;
  std::vector<ColorEncoding> current_encodings_2;
  original_metadata_encodings.reserve(io->frames.size());
  original_current_encodings.reserve(io->frames.size());
  metadata_encodings_1.reserve(io->frames.size());
  metadata_encodings_2.reserve(io->frames.size());
  current_encodings_2.reserve(io->frames.size());

  for (const ImageBundle& ib : io->frames) {
    // Remember original encoding, will be returned by decoder.
    original_metadata_encodings.push_back(ib.metadata()->color_encoding);
    // c_current should not change during encoding.
    original_current_encodings.push_back(ib.c_current());
  }

  std::unique_ptr<PassesEncoderState> enc_state =
      jxl::make_unique<PassesEncoderState>();
  JXL_CHECK(EncodeFile(cparams, io, enc_state.get(), &compressed, GetJxlCms(),
                       aux_out, pool));

  for (const ImageBundle& ib1 : io->frames) {
    metadata_encodings_1.push_back(ib1.metadata()->color_encoding);
  }

  // Should still be in the same color space after encoding.
  CheckSameEncodings(metadata_encodings_1, original_metadata_encodings,
                     "original vs after encoding", failures);

  JXL_CHECK(DecodeFile(dparams, Span<const uint8_t>(compressed), io2, pool));
  JXL_CHECK(io2->frames.size() == io->frames.size());

  for (const ImageBundle& ib2 : io2->frames) {
    metadata_encodings_2.push_back(ib2.metadata()->color_encoding);
    current_encodings_2.push_back(ib2.c_current());
  }

  // We always produce the original color encoding if a color transform hook is
  // set.
  CheckSameEncodings(current_encodings_2, original_current_encodings,
                     "current: original vs decoded", failures);

  // Decoder returns the originals passed to the encoder.
  CheckSameEncodings(metadata_encodings_2, original_metadata_encodings,
                     "metadata: original vs decoded", failures);

  if (compressed_size) {
    *compressed_size = compressed.size();
  }

  return failures.str().empty();
}

size_t Roundtrip(const extras::PackedPixelFile& ppf_in,
                 extras::JXLCompressParams cparams,
                 extras::JXLDecompressParams dparams, ThreadPool* pool,
                 extras::PackedPixelFile* ppf_out) {
  DefaultAcceptedFormats(dparams);
  SetThreadParallelRunner(cparams, pool);
  SetThreadParallelRunner(dparams, pool);
  std::vector<uint8_t> compressed;
  JXL_CHECK(extras::EncodeImageJXL(cparams, ppf_in, /*jpeg_bytes=*/nullptr,
                                   &compressed));
  size_t decoded_bytes = 0;
  JXL_CHECK(extras::DecodeImageJXL(compressed.data(), compressed.size(),
                                   dparams, &decoded_bytes, ppf_out));
  JXL_CHECK(decoded_bytes == compressed.size());
  return compressed.size();
}

std::vector<ColorEncodingDescriptor> AllEncodings() {
  std::vector<ColorEncodingDescriptor> all_encodings;
  all_encodings.reserve(300);
  ColorEncoding c;

  for (ColorSpace cs : Values<ColorSpace>()) {
    if (cs == ColorSpace::kUnknown || cs == ColorSpace::kXYB) continue;
    c.SetColorSpace(cs);

    for (WhitePoint wp : Values<WhitePoint>()) {
      if (wp == WhitePoint::kCustom) continue;
      if (c.ImplicitWhitePoint() && c.white_point != wp) continue;
      c.white_point = wp;

      for (Primaries primaries : Values<Primaries>()) {
        if (primaries == Primaries::kCustom) continue;
        if (!c.HasPrimaries()) continue;
        c.primaries = primaries;

        for (TransferFunction tf : Values<TransferFunction>()) {
          if (tf == TransferFunction::kUnknown) continue;
          if (c.tf.SetImplicit() &&
              (c.tf.IsGamma() || c.tf.GetTransferFunction() != tf)) {
            continue;
          }
          c.tf.SetTransferFunction(tf);

          for (RenderingIntent ri : Values<RenderingIntent>()) {
            ColorEncodingDescriptor cdesc;
            cdesc.color_space = cs;
            cdesc.white_point = wp;
            cdesc.primaries = primaries;
            cdesc.tf = tf;
            cdesc.rendering_intent = ri;
            all_encodings.push_back(cdesc);
          }
        }
      }
    }
  }

  return all_encodings;
}

jxl::CodecInOut SomeTestImageToCodecInOut(const std::vector<uint8_t>& buf,
                                          size_t num_channels, size_t xsize,
                                          size_t ysize) {
  jxl::CodecInOut io;
  io.SetSize(xsize, ysize);
  io.metadata.m.SetAlphaBits(16);
  io.metadata.m.color_encoding = jxl::ColorEncoding::SRGB(
      /*is_gray=*/num_channels == 1 || num_channels == 2);
  JxlPixelFormat format = {static_cast<uint32_t>(num_channels), JXL_TYPE_UINT16,
                           JXL_BIG_ENDIAN, 0};
  JXL_CHECK(ConvertFromExternal(
      jxl::Span<const uint8_t>(buf.data(), buf.size()), xsize, ysize,
      jxl::ColorEncoding::SRGB(/*is_gray=*/num_channels < 3),
      /*bits_per_sample=*/16, format,
      /*pool=*/nullptr,
      /*ib=*/&io.Main()));
  return io;
}

bool Near(double expected, double value, double max_dist) {
  double dist = expected > value ? expected - value : value - expected;
  return dist <= max_dist;
}

float LoadLEFloat16(const uint8_t* p) {
  uint16_t bits16 = LoadLE16(p);
  return LoadFloat16(bits16);
}

float LoadBEFloat16(const uint8_t* p) {
  uint16_t bits16 = LoadBE16(p);
  return LoadFloat16(bits16);
}

size_t GetPrecision(JxlDataType data_type) {
  switch (data_type) {
    case JXL_TYPE_UINT8:
      return 8;
    case JXL_TYPE_UINT16:
      return 16;
    case JXL_TYPE_FLOAT:
      // Floating point mantissa precision
      return 24;
    case JXL_TYPE_FLOAT16:
      return 11;
    default:
      JXL_ABORT("Unhandled JxlDataType");
  }
}

size_t GetDataBits(JxlDataType data_type) {
  switch (data_type) {
    case JXL_TYPE_UINT8:
      return 8;
    case JXL_TYPE_UINT16:
      return 16;
    case JXL_TYPE_FLOAT:
      return 32;
    case JXL_TYPE_FLOAT16:
      return 16;
    default:
      JXL_ABORT("Unhandled JxlDataType");
  }
}

std::vector<double> ConvertToRGBA32(const uint8_t* pixels, size_t xsize,
                                    size_t ysize, const JxlPixelFormat& format,
                                    double factor) {
  std::vector<double> result(xsize * ysize * 4);
  size_t num_channels = format.num_channels;
  bool gray = num_channels == 1 || num_channels == 2;
  bool alpha = num_channels == 2 || num_channels == 4;
  JxlEndianness endianness = format.endianness;
  // Compute actual type:
  if (endianness == JXL_NATIVE_ENDIAN) {
    endianness = IsLittleEndian() ? JXL_LITTLE_ENDIAN : JXL_BIG_ENDIAN;
  }

  size_t stride =
      xsize * jxl::DivCeil(GetDataBits(format.data_type) * num_channels,
                           jxl::kBitsPerByte);
  if (format.align > 1) stride = jxl::RoundUpTo(stride, format.align);

  if (format.data_type == JXL_TYPE_UINT8) {
    // Multiplier to bring to 0-1.0 range
    double mul = factor > 0.0 ? factor : 1.0 / 255.0;
    for (size_t y = 0; y < ysize; ++y) {
      for (size_t x = 0; x < xsize; ++x) {
        size_t j = (y * xsize + x) * 4;
        size_t i = y * stride + x * num_channels;
        double r = pixels[i];
        double g = gray ? r : pixels[i + 1];
        double b = gray ? r : pixels[i + 2];
        double a = alpha ? pixels[i + num_channels - 1] : 255;
        result[j + 0] = r * mul;
        result[j + 1] = g * mul;
        result[j + 2] = b * mul;
        result[j + 3] = a * mul;
      }
    }
  } else if (format.data_type == JXL_TYPE_UINT16) {
    JXL_ASSERT(endianness != JXL_NATIVE_ENDIAN);
    // Multiplier to bring to 0-1.0 range
    double mul = factor > 0.0 ? factor : 1.0 / 65535.0;
    for (size_t y = 0; y < ysize; ++y) {
      for (size_t x = 0; x < xsize; ++x) {
        size_t j = (y * xsize + x) * 4;
        size_t i = y * stride + x * num_channels * 2;
        double r, g, b, a;
        if (endianness == JXL_BIG_ENDIAN) {
          r = (pixels[i + 0] << 8) + pixels[i + 1];
          g = gray ? r : (pixels[i + 2] << 8) + pixels[i + 3];
          b = gray ? r : (pixels[i + 4] << 8) + pixels[i + 5];
          a = alpha ? (pixels[i + num_channels * 2 - 2] << 8) +
                          pixels[i + num_channels * 2 - 1]
                    : 65535;
        } else {
          r = (pixels[i + 1] << 8) + pixels[i + 0];
          g = gray ? r : (pixels[i + 3] << 8) + pixels[i + 2];
          b = gray ? r : (pixels[i + 5] << 8) + pixels[i + 4];
          a = alpha ? (pixels[i + num_channels * 2 - 1] << 8) +
                          pixels[i + num_channels * 2 - 2]
                    : 65535;
        }
        result[j + 0] = r * mul;
        result[j + 1] = g * mul;
        result[j + 2] = b * mul;
        result[j + 3] = a * mul;
      }
    }
  } else if (format.data_type == JXL_TYPE_FLOAT) {
    JXL_ASSERT(endianness != JXL_NATIVE_ENDIAN);
    for (size_t y = 0; y < ysize; ++y) {
      for (size_t x = 0; x < xsize; ++x) {
        size_t j = (y * xsize + x) * 4;
        size_t i = y * stride + x * num_channels * 4;
        double r, g, b, a;
        if (endianness == JXL_BIG_ENDIAN) {
          r = LoadBEFloat(pixels + i);
          g = gray ? r : LoadBEFloat(pixels + i + 4);
          b = gray ? r : LoadBEFloat(pixels + i + 8);
          a = alpha ? LoadBEFloat(pixels + i + num_channels * 4 - 4) : 1.0;
        } else {
          r = LoadLEFloat(pixels + i);
          g = gray ? r : LoadLEFloat(pixels + i + 4);
          b = gray ? r : LoadLEFloat(pixels + i + 8);
          a = alpha ? LoadLEFloat(pixels + i + num_channels * 4 - 4) : 1.0;
        }
        result[j + 0] = r;
        result[j + 1] = g;
        result[j + 2] = b;
        result[j + 3] = a;
      }
    }
  } else if (format.data_type == JXL_TYPE_FLOAT16) {
    JXL_ASSERT(endianness != JXL_NATIVE_ENDIAN);
    for (size_t y = 0; y < ysize; ++y) {
      for (size_t x = 0; x < xsize; ++x) {
        size_t j = (y * xsize + x) * 4;
        size_t i = y * stride + x * num_channels * 2;
        double r, g, b, a;
        if (endianness == JXL_BIG_ENDIAN) {
          r = LoadBEFloat16(pixels + i);
          g = gray ? r : LoadBEFloat16(pixels + i + 2);
          b = gray ? r : LoadBEFloat16(pixels + i + 4);
          a = alpha ? LoadBEFloat16(pixels + i + num_channels * 2 - 2) : 1.0;
        } else {
          r = LoadLEFloat16(pixels + i);
          g = gray ? r : LoadLEFloat16(pixels + i + 2);
          b = gray ? r : LoadLEFloat16(pixels + i + 4);
          a = alpha ? LoadLEFloat16(pixels + i + num_channels * 2 - 2) : 1.0;
        }
        result[j + 0] = r;
        result[j + 1] = g;
        result[j + 2] = b;
        result[j + 3] = a;
      }
    }
  } else {
    JXL_ASSERT(false);  // Unsupported type
  }
  return result;
}

size_t ComparePixels(const uint8_t* a, const uint8_t* b, size_t xsize,
                     size_t ysize, const JxlPixelFormat& format_a,
                     const JxlPixelFormat& format_b,
                     double threshold_multiplier) {
  // Convert both images to equal full precision for comparison.
  std::vector<double> a_full = ConvertToRGBA32(a, xsize, ysize, format_a);
  std::vector<double> b_full = ConvertToRGBA32(b, xsize, ysize, format_b);
  bool gray_a = format_a.num_channels < 3;
  bool gray_b = format_b.num_channels < 3;
  bool alpha_a = !(format_a.num_channels & 1);
  bool alpha_b = !(format_b.num_channels & 1);
  size_t bits_a = GetPrecision(format_a.data_type);
  size_t bits_b = GetPrecision(format_b.data_type);
  size_t bits = std::min(bits_a, bits_b);
  // How much distance is allowed in case of pixels with lower bit depths, given
  // that the double precision float images use range 0-1.0.
  // E.g. in case of 1-bit this is 0.5 since 0.499 must map to 0 and 0.501 must
  // map to 1.
  double precision = 0.5 * threshold_multiplier / ((1ull << bits) - 1ull);
  if (format_a.data_type == JXL_TYPE_FLOAT16 ||
      format_b.data_type == JXL_TYPE_FLOAT16) {
    // Lower the precision for float16, because it currently looks like the
    // scalar and wasm implementations of hwy have 1 less bit of precision
    // than the x86 implementations.
    // TODO(lode): Set the required precision back to 11 bits when possible.
    precision = 0.5 * threshold_multiplier / ((1ull << (bits - 1)) - 1ull);
  }
  size_t numdiff = 0;
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      size_t i = (y * xsize + x) * 4;
      bool ok = true;
      if (gray_a || gray_b) {
        if (!Near(a_full[i + 0], b_full[i + 0], precision)) ok = false;
        // If the input was grayscale and the output not, then the output must
        // have all channels equal.
        if (gray_a && b_full[i + 0] != b_full[i + 1] &&
            b_full[i + 2] != b_full[i + 2]) {
          ok = false;
        }
      } else {
        if (!Near(a_full[i + 0], b_full[i + 0], precision) ||
            !Near(a_full[i + 1], b_full[i + 1], precision) ||
            !Near(a_full[i + 2], b_full[i + 2], precision)) {
          ok = false;
        }
      }
      if (alpha_a && alpha_b) {
        if (!Near(a_full[i + 3], b_full[i + 3], precision)) ok = false;
      } else {
        // If the input had no alpha channel, the output should be opaque
        // after roundtrip.
        if (alpha_b && !Near(1.0, b_full[i + 3], precision)) ok = false;
      }
      if (!ok) numdiff++;
    }
  }
  return numdiff;
}

double DistanceRMS(const uint8_t* a, const uint8_t* b, size_t xsize,
                   size_t ysize, const JxlPixelFormat& format) {
  // Convert both images to equal full precision for comparison.
  std::vector<double> a_full = ConvertToRGBA32(a, xsize, ysize, format);
  std::vector<double> b_full = ConvertToRGBA32(b, xsize, ysize, format);
  double sum = 0.0;
  for (size_t y = 0; y < ysize; y++) {
    double row_sum = 0.0;
    for (size_t x = 0; x < xsize; x++) {
      size_t i = (y * xsize + x) * 4;
      for (size_t c = 0; c < format.num_channels; ++c) {
        double diff = a_full[i + c] - b_full[i + c];
        row_sum += diff * diff;
      }
    }
    sum += row_sum;
  }
  sum /= (xsize * ysize);
  return sqrt(sum);
}

float ButteraugliDistance(const extras::PackedPixelFile& a,
                          const extras::PackedPixelFile& b, ThreadPool* pool) {
  CodecInOut io0;
  JXL_CHECK(ConvertPackedPixelFileToCodecInOut(a, pool, &io0));
  CodecInOut io1;
  JXL_CHECK(ConvertPackedPixelFileToCodecInOut(b, pool, &io1));
  // TODO(eustas): simplify?
  return ButteraugliDistance(io0.frames, io1.frames, ButteraugliParams(),
                             GetJxlCms(),
                             /*distmap=*/nullptr, pool);
}

float Butteraugli3Norm(const extras::PackedPixelFile& a,
                       const extras::PackedPixelFile& b, ThreadPool* pool) {
  CodecInOut io0;
  JXL_CHECK(ConvertPackedPixelFileToCodecInOut(a, pool, &io0));
  CodecInOut io1;
  JXL_CHECK(ConvertPackedPixelFileToCodecInOut(b, pool, &io1));
  ButteraugliParams ba;
  ImageF distmap;
  ButteraugliDistance(io0.frames, io1.frames, ba, GetJxlCms(), &distmap, pool);
  return ComputeDistanceP(distmap, ba, 3);
}

float ComputeDistance2(const extras::PackedPixelFile& a,
                       const extras::PackedPixelFile& b) {
  CodecInOut io0;
  JXL_CHECK(ConvertPackedPixelFileToCodecInOut(a, nullptr, &io0));
  CodecInOut io1;
  JXL_CHECK(ConvertPackedPixelFileToCodecInOut(b, nullptr, &io1));
  return ComputeDistance2(io0.Main(), io1.Main(), GetJxlCms());
}

bool SameAlpha(const extras::PackedPixelFile& a,
               const extras::PackedPixelFile& b) {
  JXL_CHECK(a.info.xsize == b.info.xsize);
  JXL_CHECK(a.info.ysize == b.info.ysize);
  JXL_CHECK(a.info.alpha_bits == b.info.alpha_bits);
  JXL_CHECK(a.info.alpha_exponent_bits == b.info.alpha_exponent_bits);
  JXL_CHECK(a.info.alpha_bits > 0);
  JXL_CHECK(a.frames.size() == b.frames.size());
  for (size_t i = 0; i < a.frames.size(); ++i) {
    const extras::PackedImage& color_a = a.frames[i].color;
    const extras::PackedImage& color_b = b.frames[i].color;
    JXL_CHECK(color_a.format.num_channels == color_b.format.num_channels);
    JXL_CHECK(color_a.format.data_type == color_b.format.data_type);
    JXL_CHECK(color_a.format.endianness == color_b.format.endianness);
    JXL_CHECK(color_a.pixels_size == color_b.pixels_size);
    size_t pwidth =
        extras::PackedImage::BitsPerChannel(color_a.format.data_type) / 8;
    size_t num_color = color_a.format.num_channels < 3 ? 1 : 3;
    const uint8_t* p_a = reinterpret_cast<const uint8_t*>(color_a.pixels());
    const uint8_t* p_b = reinterpret_cast<const uint8_t*>(color_b.pixels());
    for (size_t y = 0; y < a.info.ysize; ++y) {
      for (size_t x = 0; x < a.info.xsize; ++x) {
        size_t idx =
            ((y * a.info.xsize + x) * color_a.format.num_channels + num_color) *
            pwidth;
        if (memcmp(&p_a[idx], &p_b[idx], pwidth) != 0) {
          return false;
        }
      }
    }
  }
  return true;
}

bool SamePixels(const extras::PackedImage& a, const extras::PackedImage& b) {
  JXL_CHECK(a.xsize == b.xsize);
  JXL_CHECK(a.ysize == b.ysize);
  JXL_CHECK(a.format.num_channels == b.format.num_channels);
  JXL_CHECK(a.format.data_type == b.format.data_type);
  JXL_CHECK(a.format.endianness == b.format.endianness);
  JXL_CHECK(a.pixels_size == b.pixels_size);
  const uint8_t* p_a = reinterpret_cast<const uint8_t*>(a.pixels());
  const uint8_t* p_b = reinterpret_cast<const uint8_t*>(b.pixels());
  for (size_t y = 0; y < a.ysize; ++y) {
    for (size_t x = 0; x < a.xsize; ++x) {
      size_t idx = (y * a.xsize + x) * a.pixel_stride();
      if (memcmp(&p_a[idx], &p_b[idx], a.pixel_stride()) != 0) {
        printf("Mismatch at row %" PRIuS " col %" PRIuS "\n", y, x);
        printf("  a: ");
        for (size_t j = 0; j < a.pixel_stride(); ++j) {
          printf(" %3u", p_a[idx + j]);
        }
        printf("\n  b: ");
        for (size_t j = 0; j < a.pixel_stride(); ++j) {
          printf(" %3u", p_b[idx + j]);
        }
        printf("\n");
        return false;
      }
    }
  }
  return true;
}

bool SamePixels(const extras::PackedPixelFile& a,
                const extras::PackedPixelFile& b) {
  JXL_CHECK(a.info.xsize == b.info.xsize);
  JXL_CHECK(a.info.ysize == b.info.ysize);
  JXL_CHECK(a.info.bits_per_sample == b.info.bits_per_sample);
  JXL_CHECK(a.info.exponent_bits_per_sample == b.info.exponent_bits_per_sample);
  JXL_CHECK(a.frames.size() == b.frames.size());
  for (size_t i = 0; i < a.frames.size(); ++i) {
    const auto& frame_a = a.frames[i];
    const auto& frame_b = b.frames[i];
    if (!SamePixels(frame_a.color, frame_b.color)) {
      return false;
    }
    JXL_CHECK(frame_a.extra_channels.size() == frame_b.extra_channels.size());
    for (size_t j = 0; j < frame_a.extra_channels.size(); ++j) {
      if (!SamePixels(frame_a.extra_channels[i], frame_b.extra_channels[i])) {
        return false;
      }
    }
  }
  return true;
}

}  // namespace test

bool operator==(const jxl::PaddedBytes& a, const jxl::PaddedBytes& b) {
  if (a.size() != b.size()) return false;
  if (memcmp(a.data(), b.data(), a.size()) != 0) return false;
  return true;
}

// Allow using EXPECT_EQ on jxl::PaddedBytes
bool operator!=(const jxl::PaddedBytes& a, const jxl::PaddedBytes& b) {
  return !(a == b);
}

}  // namespace jxl
