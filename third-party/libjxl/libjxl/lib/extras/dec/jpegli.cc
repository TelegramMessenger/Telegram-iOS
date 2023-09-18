// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/jpegli.h"

#include <setjmp.h>
#include <stdint.h>

#include <algorithm>
#include <numeric>
#include <utility>
#include <vector>

#include "lib/jpegli/decode.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/sanitizers.h"

namespace jxl {
namespace extras {

namespace {

constexpr unsigned char kExifSignature[6] = {0x45, 0x78, 0x69,
                                             0x66, 0x00, 0x00};
constexpr int kExifMarker = JPEG_APP0 + 1;
constexpr int kICCMarker = JPEG_APP0 + 2;

static inline bool IsJPG(const std::vector<uint8_t>& bytes) {
  if (bytes.size() < 2) return false;
  if (bytes[0] != 0xFF || bytes[1] != 0xD8) return false;
  return true;
}

bool MarkerIsExif(const jpeg_saved_marker_ptr marker) {
  return marker->marker == kExifMarker &&
         marker->data_length >= sizeof kExifSignature + 2 &&
         std::equal(std::begin(kExifSignature), std::end(kExifSignature),
                    marker->data);
}

Status ReadICCProfile(jpeg_decompress_struct* const cinfo,
                      std::vector<uint8_t>* const icc) {
  uint8_t* icc_data_ptr;
  unsigned int icc_data_len;
  if (jpegli_read_icc_profile(cinfo, &icc_data_ptr, &icc_data_len)) {
    icc->assign(icc_data_ptr, icc_data_ptr + icc_data_len);
    free(icc_data_ptr);
    return true;
  }
  return false;
}

void ReadExif(jpeg_decompress_struct* const cinfo,
              std::vector<uint8_t>* const exif) {
  constexpr size_t kExifSignatureSize = sizeof kExifSignature;
  for (jpeg_saved_marker_ptr marker = cinfo->marker_list; marker != nullptr;
       marker = marker->next) {
    // marker is initialized by libjpeg, which we are not instrumenting with
    // msan.
    msan::UnpoisonMemory(marker, sizeof(*marker));
    msan::UnpoisonMemory(marker->data, marker->data_length);
    if (!MarkerIsExif(marker)) continue;
    size_t marker_length = marker->data_length - kExifSignatureSize;
    exif->resize(marker_length);
    std::copy_n(marker->data + kExifSignatureSize, marker_length, exif->data());
    return;
  }
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

JpegliEndianness ConvertEndianness(JxlEndianness type) {
  switch (type) {
    case JXL_NATIVE_ENDIAN:
      return JPEGLI_NATIVE_ENDIAN;
    case JXL_BIG_ENDIAN:
      return JPEGLI_BIG_ENDIAN;
    case JXL_LITTLE_ENDIAN:
      return JPEGLI_LITTLE_ENDIAN;
    default:
      return JPEGLI_NATIVE_ENDIAN;
  }
}

JxlColorSpace ConvertColorSpace(J_COLOR_SPACE colorspace) {
  switch (colorspace) {
    case JCS_GRAYSCALE:
      return JXL_COLOR_SPACE_GRAY;
    case JCS_RGB:
      return JXL_COLOR_SPACE_RGB;
    default:
      return JXL_COLOR_SPACE_UNKNOWN;
  }
}

void MyErrorExit(j_common_ptr cinfo) {
  jmp_buf* env = static_cast<jmp_buf*>(cinfo->client_data);
  (*cinfo->err->output_message)(cinfo);
  jpegli_destroy_decompress(reinterpret_cast<j_decompress_ptr>(cinfo));
  longjmp(*env, 1);
}

void MyOutputMessage(j_common_ptr cinfo) {
#if JXL_DEBUG_WARNING == 1
  char buf[JMSG_LENGTH_MAX + 1];
  (*cinfo->err->format_message)(cinfo, buf);
  buf[JMSG_LENGTH_MAX] = 0;
  JXL_WARNING("%s", buf);
#endif
}

void UnmapColors(uint8_t* row, size_t xsize, int components,
                 JSAMPARRAY colormap, size_t num_colors) {
  JXL_CHECK(colormap != nullptr);
  std::vector<uint8_t> tmp(xsize * components);
  for (size_t x = 0; x < xsize; ++x) {
    JXL_CHECK(row[x] < num_colors);
    for (int c = 0; c < components; ++c) {
      tmp[x * components + c] = colormap[c][row[x]];
    }
  }
  memcpy(row, tmp.data(), tmp.size());
}

}  // namespace

Status DecodeJpeg(const std::vector<uint8_t>& compressed,
                  const JpegDecompressParams& dparams, ThreadPool* pool,
                  PackedPixelFile* ppf) {
  // Don't do anything for non-JPEG files (no need to report an error)
  if (!IsJPG(compressed)) return false;

  // TODO(veluca): use JPEGData also for pixels?

  // We need to declare all the non-trivial destructor local variables before
  // the call to setjmp().
  std::unique_ptr<JSAMPLE[]> row;

  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    // Setup error handling in jpeg library so we can deal with broken jpegs in
    // the fuzzer.
    jpeg_error_mgr jerr;
    jmp_buf env;
    cinfo.err = jpegli_std_error(&jerr);
    jerr.error_exit = &MyErrorExit;
    jerr.output_message = &MyOutputMessage;
    if (setjmp(env)) {
      return false;
    }
    cinfo.client_data = static_cast<void*>(&env);

    jpegli_create_decompress(&cinfo);
    jpegli_mem_src(&cinfo,
                   reinterpret_cast<const unsigned char*>(compressed.data()),
                   compressed.size());
    jpegli_save_markers(&cinfo, kICCMarker, 0xFFFF);
    jpegli_save_markers(&cinfo, kExifMarker, 0xFFFF);
    const auto failure = [&cinfo](const char* str) -> Status {
      jpegli_abort_decompress(&cinfo);
      jpegli_destroy_decompress(&cinfo);
      return JXL_FAILURE("%s", str);
    };
    jpegli_read_header(&cinfo, TRUE);
    // Might cause CPU-zip bomb.
    if (cinfo.arith_code) {
      return failure("arithmetic code JPEGs are not supported");
    }
    int nbcomp = cinfo.num_components;
    if (nbcomp != 1 && nbcomp != 3) {
      return failure("unsupported number of components in JPEG");
    }
    if (dparams.force_rgb) {
      cinfo.out_color_space = JCS_RGB;
    } else if (dparams.force_grayscale) {
      cinfo.out_color_space = JCS_GRAYSCALE;
    }
    if (!ReadICCProfile(&cinfo, &ppf->icc)) {
      ppf->icc.clear();
      // Default to SRGB
      ppf->color_encoding.color_space =
          ConvertColorSpace(cinfo.out_color_space);
      ppf->color_encoding.white_point = JXL_WHITE_POINT_D65;
      ppf->color_encoding.primaries = JXL_PRIMARIES_SRGB;
      ppf->color_encoding.transfer_function = JXL_TRANSFER_FUNCTION_SRGB;
      ppf->color_encoding.rendering_intent = JXL_RENDERING_INTENT_PERCEPTUAL;
    }
    ReadExif(&cinfo, &ppf->metadata.exif);

    ppf->info.xsize = cinfo.image_width;
    ppf->info.ysize = cinfo.image_height;
    if (dparams.output_data_type == JXL_TYPE_UINT8) {
      ppf->info.bits_per_sample = 8;
      ppf->info.exponent_bits_per_sample = 0;
    } else if (dparams.output_data_type == JXL_TYPE_UINT16) {
      ppf->info.bits_per_sample = 16;
      ppf->info.exponent_bits_per_sample = 0;
    } else if (dparams.output_data_type == JXL_TYPE_FLOAT) {
      ppf->info.bits_per_sample = 32;
      ppf->info.exponent_bits_per_sample = 8;
    } else {
      return failure("unsupported data type");
    }
    ppf->info.uses_original_profile = true;

    // No alpha in JPG
    ppf->info.alpha_bits = 0;
    ppf->info.alpha_exponent_bits = 0;
    ppf->info.orientation = JXL_ORIENT_IDENTITY;

    jpegli_set_output_format(&cinfo, ConvertDataType(dparams.output_data_type),
                             ConvertEndianness(dparams.output_endianness));

    if (dparams.num_colors > 0) {
      cinfo.quantize_colors = TRUE;
      cinfo.desired_number_of_colors = dparams.num_colors;
      cinfo.two_pass_quantize = dparams.two_pass_quant;
      cinfo.dither_mode = (J_DITHER_MODE)dparams.dither_mode;
    }

    jpegli_start_decompress(&cinfo);

    ppf->info.num_color_channels = cinfo.out_color_components;
    const JxlPixelFormat format{
        /*num_channels=*/static_cast<uint32_t>(cinfo.out_color_components),
        dparams.output_data_type,
        dparams.output_endianness,
        /*align=*/0,
    };
    ppf->frames.clear();
    // Allocates the frame buffer.
    ppf->frames.emplace_back(cinfo.image_width, cinfo.image_height, format);
    const auto& frame = ppf->frames.back();
    JXL_ASSERT(sizeof(JSAMPLE) * cinfo.out_color_components *
                   cinfo.image_width <=
               frame.color.stride);

    for (size_t y = 0; y < cinfo.image_height; ++y) {
      JSAMPROW rows[] = {reinterpret_cast<JSAMPLE*>(
          static_cast<uint8_t*>(frame.color.pixels()) +
          frame.color.stride * y)};
      jpegli_read_scanlines(&cinfo, rows, 1);
      if (dparams.num_colors > 0) {
        UnmapColors(rows[0], cinfo.output_width, cinfo.out_color_components,
                    cinfo.colormap, cinfo.actual_number_of_colors);
      }
    }

    jpegli_finish_decompress(&cinfo);
    return true;
  };
  bool success = try_catch_block();
  jpegli_destroy_decompress(&cinfo);
  return success;
}

}  // namespace extras
}  // namespace jxl
