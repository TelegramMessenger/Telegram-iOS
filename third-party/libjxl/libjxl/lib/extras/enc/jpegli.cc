// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/jpegli.h"

#include <jxl/codestream_header.h>
#include <setjmp.h>
#include <stdint.h>

#include "lib/extras/enc/encode.h"
#include "lib/jpegli/encode.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_xyb.h"

namespace jxl {
namespace extras {

namespace {

void MyErrorExit(j_common_ptr cinfo) {
  jmp_buf* env = static_cast<jmp_buf*>(cinfo->client_data);
  (*cinfo->err->output_message)(cinfo);
  jpegli_destroy_compress(reinterpret_cast<j_compress_ptr>(cinfo));
  longjmp(*env, 1);
}

Status VerifyInput(const PackedPixelFile& ppf) {
  const JxlBasicInfo& info = ppf.info;
  JXL_RETURN_IF_ERROR(Encoder::VerifyBasicInfo(info));
  if (ppf.frames.size() != 1) {
    return JXL_FAILURE("JPEG input must have exactly one frame.");
  }
  const PackedImage& image = ppf.frames[0].color;
  JXL_RETURN_IF_ERROR(Encoder::VerifyImageSize(image, info));
  if (image.format.data_type == JXL_TYPE_FLOAT16) {
    return JXL_FAILURE("FLOAT16 input is not supported.");
  }
  JXL_RETURN_IF_ERROR(Encoder::VerifyBitDepth(image.format.data_type,
                                              info.bits_per_sample,
                                              info.exponent_bits_per_sample));
  if ((image.format.data_type == JXL_TYPE_UINT8 && info.bits_per_sample != 8) ||
      (image.format.data_type == JXL_TYPE_UINT16 &&
       info.bits_per_sample != 16)) {
    return JXL_FAILURE("Only full bit depth unsigned types are supported.");
  }
  return true;
}

Status GetColorEncoding(const PackedPixelFile& ppf, const JxlCmsInterface* cms,
                        ColorEncoding* color_encoding) {
  if (!ppf.icc.empty()) {
    PaddedBytes icc;
    icc.assign(ppf.icc.data(), ppf.icc.data() + ppf.icc.size());
    JXL_RETURN_IF_ERROR(color_encoding->SetICC(std::move(icc), cms));
  } else {
    JXL_RETURN_IF_ERROR(ConvertExternalToInternalColorEncoding(
        ppf.color_encoding, color_encoding));
  }
  if (color_encoding->ICC().empty()) {
    return JXL_FAILURE("Invalid color encoding.");
  }
  return true;
}

bool HasICCProfile(const std::vector<uint8_t>& app_data) {
  size_t pos = 0;
  while (pos < app_data.size()) {
    if (pos + 16 > app_data.size()) return false;
    uint8_t marker = app_data[pos + 1];
    size_t marker_len = (app_data[pos + 2] << 8) + app_data[pos + 3] + 2;
    if (marker == 0xe2 && memcmp(&app_data[pos + 4], "ICC_PROFILE", 12) == 0) {
      return true;
    }
    pos += marker_len;
  }
  return false;
}

Status WriteAppData(j_compress_ptr cinfo,
                    const std::vector<uint8_t>& app_data) {
  size_t pos = 0;
  while (pos < app_data.size()) {
    if (pos + 4 > app_data.size()) {
      return JXL_FAILURE("Incomplete APP header.");
    }
    uint8_t marker = app_data[pos + 1];
    size_t marker_len = (app_data[pos + 2] << 8) + app_data[pos + 3] + 2;
    if (app_data[pos] != 0xff || marker < 0xe0 || marker > 0xef) {
      return JXL_FAILURE("Invalid APP marker %02x %02x", app_data[pos], marker);
    }
    if (marker_len <= 4) {
      return JXL_FAILURE("Invalid APP marker length.");
    }
    if (pos + marker_len > app_data.size()) {
      return JXL_FAILURE("Incomplete APP data");
    }
    jpegli_write_marker(cinfo, marker, &app_data[pos + 4], marker_len - 4);
    pos += marker_len;
  }
  return true;
}

static constexpr int kICCMarker = 0xe2;
constexpr unsigned char kICCSignature[12] = {
    0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00};
static constexpr uint8_t kUnknownTf = 2;
static constexpr unsigned char kCICPTagSignature[4] = {0x63, 0x69, 0x63, 0x70};
static constexpr size_t kCICPTagSize = 12;

bool FindCICPTag(const uint8_t* icc_data, size_t len, bool is_first_chunk,
                 size_t* cicp_offset, size_t* cicp_length, uint8_t* cicp_tag,
                 size_t* cicp_pos) {
  if (is_first_chunk) {
    // Look up the offset of the CICP tag from the first chunk of ICC data.
    if (len < 132) {
      return false;
    }
    uint32_t tag_count = LoadBE32(&icc_data[128]);
    if (len < 132 + 12 * tag_count) {
      return false;
    }
    for (uint32_t i = 0; i < tag_count; ++i) {
      if (memcmp(&icc_data[132 + 12 * i], kCICPTagSignature, 4) == 0) {
        *cicp_offset = LoadBE32(&icc_data[136 + 12 * i]);
        *cicp_length = LoadBE32(&icc_data[140 + 12 * i]);
      }
    }
    if (*cicp_length < kCICPTagSize) {
      return false;
    }
  }
  if (*cicp_offset < len) {
    size_t n_bytes = std::min(len - *cicp_offset, kCICPTagSize - *cicp_pos);
    memcpy(&cicp_tag[*cicp_pos], &icc_data[*cicp_offset], n_bytes);
    *cicp_pos += n_bytes;
    *cicp_offset = 0;
  } else {
    *cicp_offset -= len;
  }
  return true;
}

uint8_t LookupCICPTransferFunctionFromAppData(const uint8_t* app_data,
                                              size_t len) {
  size_t last_index = 0;
  size_t cicp_offset = 0;
  size_t cicp_length = 0;
  uint8_t cicp_tag[kCICPTagSize] = {};
  size_t cicp_pos = 0;
  size_t pos = 0;
  while (pos < len) {
    const uint8_t* marker = &app_data[pos];
    if (pos + 4 > len) {
      return kUnknownTf;
    }
    size_t marker_size = (marker[2] << 8) + marker[3] + 2;
    if (pos + marker_size > len) {
      return kUnknownTf;
    }
    if (marker_size < 18 || marker[0] != 0xff || marker[1] != kICCMarker ||
        memcmp(&marker[4], kICCSignature, 12) != 0) {
      pos += marker_size;
      continue;
    }
    uint8_t index = marker[16];
    uint8_t total = marker[17];
    const uint8_t* payload = marker + 18;
    const size_t payload_size = marker_size - 18;
    if (index != last_index + 1 || index > total) {
      return kUnknownTf;
    }
    if (!FindCICPTag(payload, payload_size, last_index == 0, &cicp_offset,
                     &cicp_length, &cicp_tag[0], &cicp_pos)) {
      return kUnknownTf;
    }
    if (cicp_pos == kCICPTagSize) {
      break;
    }
    ++last_index;
  }
  if (cicp_pos >= kCICPTagSize && memcmp(cicp_tag, kCICPTagSignature, 4) == 0) {
    return cicp_tag[9];
  }
  return kUnknownTf;
}

uint8_t LookupCICPTransferFunctionFromICCProfile(const uint8_t* icc_data,
                                                 size_t len) {
  size_t cicp_offset = 0;
  size_t cicp_length = 0;
  uint8_t cicp_tag[kCICPTagSize] = {};
  size_t cicp_pos = 0;
  if (!FindCICPTag(icc_data, len, true, &cicp_offset, &cicp_length,
                   &cicp_tag[0], &cicp_pos)) {
    return kUnknownTf;
  }
  if (cicp_pos >= kCICPTagSize && memcmp(cicp_tag, kCICPTagSignature, 4) == 0) {
    return cicp_tag[9];
  }
  return kUnknownTf;
}

JpegliDataType ConvertDataType(JxlDataType type) {
  switch (type) {
    case JXL_TYPE_UINT8:
      return JPEGLI_TYPE_UINT8;
    case JXL_TYPE_UINT16:
      return JPEGLI_TYPE_UINT16;
    case JXL_TYPE_FLOAT:
      return JPEGLI_TYPE_FLOAT;
    default:
      return JPEGLI_TYPE_UINT8;
  }
}

JpegliEndianness ConvertEndianness(JxlEndianness endianness) {
  switch (endianness) {
    case JXL_NATIVE_ENDIAN:
      return JPEGLI_NATIVE_ENDIAN;
    case JXL_LITTLE_ENDIAN:
      return JPEGLI_LITTLE_ENDIAN;
    case JXL_BIG_ENDIAN:
      return JPEGLI_BIG_ENDIAN;
    default:
      return JPEGLI_NATIVE_ENDIAN;
  }
}

void ToFloatRow(const uint8_t* row_in, JxlPixelFormat format, size_t len,
                float* row_out) {
  bool is_little_endian =
      (format.endianness == JXL_LITTLE_ENDIAN ||
       (format.endianness == JXL_NATIVE_ENDIAN && IsLittleEndian()));
  static constexpr double kMul8 = 1.0 / 255.0;
  static constexpr double kMul16 = 1.0 / 65535.0;
  if (format.data_type == JXL_TYPE_UINT8) {
    for (size_t x = 0; x < len; ++x) {
      row_out[x] = row_in[x] * kMul8;
    }
  } else if (format.data_type == JXL_TYPE_UINT16 && is_little_endian) {
    for (size_t x = 0; x < len; ++x) {
      row_out[x] = LoadLE16(&row_in[2 * x]) * kMul16;
    }
  } else if (format.data_type == JXL_TYPE_UINT16 && !is_little_endian) {
    for (size_t x = 0; x < len; ++x) {
      row_out[x] = LoadBE16(&row_in[2 * x]) * kMul16;
    }
  } else if (format.data_type == JXL_TYPE_FLOAT && is_little_endian) {
    for (size_t x = 0; x < len; ++x) {
      row_out[x] = LoadLEFloat(&row_in[4 * x]);
    }
  } else if (format.data_type == JXL_TYPE_FLOAT && !is_little_endian) {
    for (size_t x = 0; x < len; ++x) {
      row_out[x] = LoadBEFloat(&row_in[4 * x]);
    }
  }
}

Status EncodeJpegToTargetSize(const PackedPixelFile& ppf,
                              const JpegSettings& jpeg_settings,
                              size_t target_size, ThreadPool* pool,
                              std::vector<uint8_t>* output) {
  output->clear();
  size_t best_error = std::numeric_limits<size_t>::max();
  float distance0 = -1.0f;
  float distance1 = -1.0f;
  float distance = 1.0f;
  for (int step = 0; step < 15; ++step) {
    JpegSettings settings = jpeg_settings;
    settings.libjpeg_quality = 0;
    settings.distance = distance;
    settings.target_size = 0;
    std::vector<uint8_t> compressed;
    JXL_RETURN_IF_ERROR(EncodeJpeg(ppf, settings, pool, &compressed));
    size_t size = compressed.size();
    // prefer being under the target size to being over it
    size_t error = size < target_size
                       ? target_size - size
                       : static_cast<size_t>(1.2f * (size - target_size));
    if (error < best_error) {
      best_error = error;
      std::swap(*output, compressed);
    }
    float rel_error = size * 1.0f / target_size;
    if (std::abs(rel_error - 1.0f) < 0.002f) {
      break;
    }
    if (size < target_size) {
      distance1 = distance;
    } else {
      distance0 = distance;
    }
    if (distance1 == -1) {
      distance *= std::pow(rel_error, 1.5) * 1.05;
    } else if (distance0 == -1) {
      distance *= std::pow(rel_error, 1.5) * 0.95;
    } else {
      distance = 0.5 * (distance0 + distance1);
    }
  }
  return true;
}

}  // namespace

Status EncodeJpeg(const PackedPixelFile& ppf, const JpegSettings& jpeg_settings,
                  ThreadPool* pool, std::vector<uint8_t>* compressed) {
  if (jpeg_settings.libjpeg_quality > 0) {
    auto encoder = Encoder::FromExtension(".jpg");
    encoder->SetOption("q", std::to_string(jpeg_settings.libjpeg_quality));
    if (!jpeg_settings.libjpeg_chroma_subsampling.empty()) {
      encoder->SetOption("chroma_subsampling",
                         jpeg_settings.libjpeg_chroma_subsampling);
    }
    EncodedImage encoded;
    JXL_RETURN_IF_ERROR(encoder->Encode(ppf, &encoded, pool));
    size_t target_size = encoded.bitstreams[0].size();
    return EncodeJpegToTargetSize(ppf, jpeg_settings, target_size, pool,
                                  compressed);
  }
  if (jpeg_settings.target_size > 0) {
    return EncodeJpegToTargetSize(ppf, jpeg_settings, jpeg_settings.target_size,
                                  pool, compressed);
  }
  JXL_RETURN_IF_ERROR(VerifyInput(ppf));

  const JxlCmsInterface& cms = GetJxlCms();

  ColorEncoding color_encoding;
  JXL_RETURN_IF_ERROR(GetColorEncoding(ppf, &cms, &color_encoding));

  ColorSpaceTransform c_transform(cms);
  ColorEncoding xyb_encoding;
  if (jpeg_settings.xyb) {
    if (ppf.info.num_color_channels != 3) {
      return JXL_FAILURE("Only RGB input is supported in XYB mode.");
    }
    if (HasICCProfile(jpeg_settings.app_data)) {
      return JXL_FAILURE("APP data ICC profile is not supported in XYB mode.");
    }
    const ColorEncoding& c_desired = ColorEncoding::LinearSRGB(false);
    JXL_RETURN_IF_ERROR(
        c_transform.Init(color_encoding, c_desired, 255.0f, ppf.info.xsize, 1));
    xyb_encoding.SetColorSpace(jxl::ColorSpace::kXYB);
    xyb_encoding.rendering_intent = jxl::RenderingIntent::kPerceptual;
    JXL_RETURN_IF_ERROR(xyb_encoding.CreateICC());
  }
  const ColorEncoding& output_encoding =
      jpeg_settings.xyb ? xyb_encoding : color_encoding;

  // We need to declare all the non-trivial destructor local variables
  // before the call to setjmp().
  std::vector<uint8_t> pixels;
  unsigned char* output_buffer = nullptr;
  unsigned long output_size = 0;
  std::vector<uint8_t> row_bytes;
  size_t rowlen = RoundUpTo(ppf.info.xsize, VectorSize());
  hwy::AlignedFreeUniquePtr<float[]> xyb_tmp =
      hwy::AllocateAligned<float>(6 * rowlen);
  hwy::AlignedFreeUniquePtr<float[]> premul_absorb =
      hwy::AllocateAligned<float>(VectorSize() * 12);
  ComputePremulAbsorb(255.0f, premul_absorb.get());

  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    jpeg_error_mgr jerr;
    jmp_buf env;
    cinfo.err = jpegli_std_error(&jerr);
    jerr.error_exit = &MyErrorExit;
    if (setjmp(env)) {
      return false;
    }
    cinfo.client_data = static_cast<void*>(&env);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &output_buffer, &output_size);
    const JxlBasicInfo& info = ppf.info;
    cinfo.image_width = info.xsize;
    cinfo.image_height = info.ysize;
    cinfo.input_components = info.num_color_channels;
    cinfo.in_color_space =
        cinfo.input_components == 1 ? JCS_GRAYSCALE : JCS_RGB;
    if (jpeg_settings.xyb) {
      jpegli_set_xyb_mode(&cinfo);
    } else if (jpeg_settings.use_std_quant_tables) {
      jpegli_use_standard_quant_tables(&cinfo);
    }
    uint8_t cicp_tf = kUnknownTf;
    if (!jpeg_settings.app_data.empty()) {
      cicp_tf = LookupCICPTransferFunctionFromAppData(
          jpeg_settings.app_data.data(), jpeg_settings.app_data.size());
    } else if (!output_encoding.IsSRGB()) {
      cicp_tf = LookupCICPTransferFunctionFromICCProfile(
          output_encoding.ICC().data(), output_encoding.ICC().size());
    }
    jpegli_set_cicp_transfer_function(&cinfo, cicp_tf);
    jpegli_set_defaults(&cinfo);
    if (!jpeg_settings.chroma_subsampling.empty()) {
      if (jpeg_settings.chroma_subsampling == "444") {
        cinfo.comp_info[0].h_samp_factor = 1;
        cinfo.comp_info[0].v_samp_factor = 1;
      } else if (jpeg_settings.chroma_subsampling == "440") {
        cinfo.comp_info[0].h_samp_factor = 1;
        cinfo.comp_info[0].v_samp_factor = 2;
      } else if (jpeg_settings.chroma_subsampling == "422") {
        cinfo.comp_info[0].h_samp_factor = 2;
        cinfo.comp_info[0].v_samp_factor = 1;
      } else if (jpeg_settings.chroma_subsampling == "420") {
        cinfo.comp_info[0].h_samp_factor = 2;
        cinfo.comp_info[0].v_samp_factor = 2;
      } else {
        return false;
      }
      for (int i = 1; i < cinfo.num_components; ++i) {
        cinfo.comp_info[i].h_samp_factor = 1;
        cinfo.comp_info[i].v_samp_factor = 1;
      }
    }
    jpegli_enable_adaptive_quantization(
        &cinfo, jpeg_settings.use_adaptive_quantization);
    if (jpeg_settings.psnr_target > 0.0) {
      jpegli_set_psnr(&cinfo, jpeg_settings.psnr_target,
                      jpeg_settings.search_tolerance,
                      jpeg_settings.min_distance, jpeg_settings.max_distance);
    } else if (jpeg_settings.quality > 0.0) {
      float distance = jpegli_quality_to_distance(jpeg_settings.quality);
      jpegli_set_distance(&cinfo, distance, TRUE);
    } else {
      jpegli_set_distance(&cinfo, jpeg_settings.distance, TRUE);
    }
    jpegli_set_progressive_level(&cinfo, jpeg_settings.progressive_level);
    cinfo.optimize_coding = jpeg_settings.optimize_coding;
    if (!jpeg_settings.app_data.empty()) {
      // Make sure jpegli_start_compress() does not write any APP markers.
      cinfo.write_JFIF_header = false;
      cinfo.write_Adobe_marker = false;
    }
    const PackedImage& image = ppf.frames[0].color;
    if (jpeg_settings.xyb) {
      jpegli_set_input_format(&cinfo, JPEGLI_TYPE_FLOAT, JPEGLI_NATIVE_ENDIAN);
    } else {
      jpegli_set_input_format(&cinfo, ConvertDataType(image.format.data_type),
                              ConvertEndianness(image.format.endianness));
    }
    jpegli_start_compress(&cinfo, TRUE);
    if (!jpeg_settings.app_data.empty()) {
      JXL_RETURN_IF_ERROR(WriteAppData(&cinfo, jpeg_settings.app_data));
    }
    if ((jpeg_settings.app_data.empty() && !output_encoding.IsSRGB()) ||
        jpeg_settings.xyb) {
      jpegli_write_icc_profile(&cinfo, output_encoding.ICC().data(),
                               output_encoding.ICC().size());
    }
    const uint8_t* pixels = reinterpret_cast<const uint8_t*>(image.pixels());
    if (jpeg_settings.xyb) {
      float* src_buf = c_transform.BufSrc(0);
      float* dst_buf = c_transform.BufDst(0);
      for (size_t y = 0; y < image.ysize; ++y) {
        // convert to float
        ToFloatRow(&pixels[y * image.stride], image.format, 3 * image.xsize,
                   src_buf);
        // convert to linear srgb
        if (!c_transform.Run(0, src_buf, dst_buf)) {
          return false;
        }
        // deinterleave channels
        float* row0 = &xyb_tmp[0];
        float* row1 = &xyb_tmp[rowlen];
        float* row2 = &xyb_tmp[2 * rowlen];
        for (size_t x = 0; x < image.xsize; ++x) {
          row0[x] = dst_buf[3 * x + 0];
          row1[x] = dst_buf[3 * x + 1];
          row2[x] = dst_buf[3 * x + 2];
        }
        // convert to xyb
        LinearRGBRowToXYB(row0, row1, row2, premul_absorb.get(), image.xsize);
        // scale xyb
        ScaleXYBRow(row0, row1, row2, image.xsize);
        // interleave channels
        float* row_out = &xyb_tmp[3 * rowlen];
        for (size_t x = 0; x < image.xsize; ++x) {
          row_out[3 * x + 0] = row0[x];
          row_out[3 * x + 1] = row1[x];
          row_out[3 * x + 2] = row2[x];
        }
        // feed to jpegli as native endian floats
        JSAMPROW row[] = {reinterpret_cast<uint8_t*>(row_out)};
        jpegli_write_scanlines(&cinfo, row, 1);
      }
    } else {
      row_bytes.resize(image.stride);
      if (cinfo.num_components == (int)image.format.num_channels) {
        for (size_t y = 0; y < info.ysize; ++y) {
          memcpy(&row_bytes[0], pixels + y * image.stride, image.stride);
          JSAMPROW row[] = {row_bytes.data()};
          jpegli_write_scanlines(&cinfo, row, 1);
        }
      } else {
        for (size_t y = 0; y < info.ysize; ++y) {
          int bytes_per_channel =
              PackedImage::BitsPerChannel(image.format.data_type) / 8;
          int bytes_per_pixel = cinfo.num_components * bytes_per_channel;
          for (size_t x = 0; x < info.xsize; ++x) {
            memcpy(&row_bytes[x * bytes_per_pixel],
                   &pixels[y * image.stride + x * image.pixel_stride()],
                   bytes_per_pixel);
          }
          JSAMPROW row[] = {row_bytes.data()};
          jpegli_write_scanlines(&cinfo, row, 1);
        }
      }
    }
    jpegli_finish_compress(&cinfo);
    compressed->resize(output_size);
    std::copy_n(output_buffer, output_size, compressed->data());
    return true;
  };
  bool success = try_catch_block();
  jpegli_destroy_compress(&cinfo);
  if (output_buffer) free(output_buffer);
  return success;
}

}  // namespace extras
}  // namespace jxl
