// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/jpg.h"

#if JPEGXL_ENABLE_JPEG
#include <jpeglib.h>
#include <setjmp.h>
#endif
#include <stdint.h>

#include <algorithm>
#include <numeric>
#include <utility>
#include <vector>

#include "lib/extras/size_constraints.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/sanitizers.h"

namespace jxl {
namespace extras {

#if JPEGXL_ENABLE_JPEG
namespace {

constexpr unsigned char kICCSignature[12] = {
    0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00};
constexpr int kICCMarker = JPEG_APP0 + 2;

constexpr unsigned char kExifSignature[6] = {0x45, 0x78, 0x69,
                                             0x66, 0x00, 0x00};
constexpr int kExifMarker = JPEG_APP0 + 1;

static inline bool IsJPG(const Span<const uint8_t> bytes) {
  if (bytes.size() < 2) return false;
  if (bytes[0] != 0xFF || bytes[1] != 0xD8) return false;
  return true;
}

bool MarkerIsICC(const jpeg_saved_marker_ptr marker) {
  return marker->marker == kICCMarker &&
         marker->data_length >= sizeof kICCSignature + 2 &&
         std::equal(std::begin(kICCSignature), std::end(kICCSignature),
                    marker->data);
}
bool MarkerIsExif(const jpeg_saved_marker_ptr marker) {
  return marker->marker == kExifMarker &&
         marker->data_length >= sizeof kExifSignature + 2 &&
         std::equal(std::begin(kExifSignature), std::end(kExifSignature),
                    marker->data);
}

Status ReadICCProfile(jpeg_decompress_struct* const cinfo,
                      std::vector<uint8_t>* const icc) {
  constexpr size_t kICCSignatureSize = sizeof kICCSignature;
  // ICC signature + uint8_t index + uint8_t max_index.
  constexpr size_t kICCHeadSize = kICCSignatureSize + 2;
  // Markers are 1-indexed, and we keep them that way in this vector to get a
  // convenient 0 at the front for when we compute the offsets later.
  std::vector<size_t> marker_lengths;
  int num_markers = 0;
  int seen_markers_count = 0;
  bool has_num_markers = false;
  for (jpeg_saved_marker_ptr marker = cinfo->marker_list; marker != nullptr;
       marker = marker->next) {
    // marker is initialized by libjpeg, which we are not instrumenting with
    // msan.
    msan::UnpoisonMemory(marker, sizeof(*marker));
    msan::UnpoisonMemory(marker->data, marker->data_length);
    if (!MarkerIsICC(marker)) continue;

    const int current_marker = marker->data[kICCSignatureSize];
    if (current_marker == 0) {
      return JXL_FAILURE("inconsistent JPEG ICC marker numbering");
    }
    const int current_num_markers = marker->data[kICCSignatureSize + 1];
    if (current_marker > current_num_markers) {
      return JXL_FAILURE("inconsistent JPEG ICC marker numbering");
    }
    if (has_num_markers) {
      if (current_num_markers != num_markers) {
        return JXL_FAILURE("inconsistent numbers of JPEG ICC markers");
      }
    } else {
      num_markers = current_num_markers;
      has_num_markers = true;
      marker_lengths.resize(num_markers + 1);
    }

    size_t marker_length = marker->data_length - kICCHeadSize;

    if (marker_length == 0) {
      // NB: if we allow empty chunks, then the next check is incorrect.
      return JXL_FAILURE("Empty ICC chunk");
    }

    if (marker_lengths[current_marker] != 0) {
      return JXL_FAILURE("duplicate JPEG ICC marker number");
    }
    marker_lengths[current_marker] = marker_length;
    seen_markers_count++;
  }

  if (marker_lengths.empty()) {
    // Not an error.
    return false;
  }

  if (seen_markers_count != num_markers) {
    JXL_DASSERT(has_num_markers);
    return JXL_FAILURE("Incomplete set of ICC chunks");
  }

  std::vector<size_t> offsets = std::move(marker_lengths);
  std::partial_sum(offsets.begin(), offsets.end(), offsets.begin());
  icc->resize(offsets.back());

  for (jpeg_saved_marker_ptr marker = cinfo->marker_list; marker != nullptr;
       marker = marker->next) {
    if (!MarkerIsICC(marker)) continue;
    const uint8_t* first = marker->data + kICCHeadSize;
    uint8_t current_marker = marker->data[kICCSignatureSize];
    size_t offset = offsets[current_marker - 1];
    size_t marker_length = offsets[current_marker] - offset;
    std::copy_n(first, marker_length, icc->data() + offset);
  }

  return true;
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

void MyErrorExit(j_common_ptr cinfo) {
  jmp_buf* env = static_cast<jmp_buf*>(cinfo->client_data);
  (*cinfo->err->output_message)(cinfo);
  jpeg_destroy_decompress(reinterpret_cast<j_decompress_ptr>(cinfo));
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
#endif

bool CanDecodeJPG() {
#if JPEGXL_ENABLE_JPEG
  return true;
#else
  return false;
#endif
}

Status DecodeImageJPG(const Span<const uint8_t> bytes,
                      const ColorHints& color_hints, PackedPixelFile* ppf,
                      const SizeConstraints* constraints,
                      const JPGDecompressParams* dparams) {
#if JPEGXL_ENABLE_JPEG
  // Don't do anything for non-JPEG files (no need to report an error)
  if (!IsJPG(bytes)) return false;

  // TODO(veluca): use JPEGData also for pixels?

  // We need to declare all the non-trivial destructor local variables before
  // the call to setjmp().
  std::unique_ptr<JSAMPLE[]> row;

  const auto try_catch_block = [&]() -> bool {
    jpeg_decompress_struct cinfo = {};
    // Setup error handling in jpeg library so we can deal with broken jpegs in
    // the fuzzer.
    jpeg_error_mgr jerr;
    jmp_buf env;
    cinfo.err = jpeg_std_error(&jerr);
    jerr.error_exit = &MyErrorExit;
    jerr.output_message = &MyOutputMessage;
    if (setjmp(env)) {
      return false;
    }
    cinfo.client_data = static_cast<void*>(&env);

    jpeg_create_decompress(&cinfo);
    jpeg_mem_src(&cinfo, reinterpret_cast<const unsigned char*>(bytes.data()),
                 bytes.size());
    jpeg_save_markers(&cinfo, kICCMarker, 0xFFFF);
    jpeg_save_markers(&cinfo, kExifMarker, 0xFFFF);
    const auto failure = [&cinfo](const char* str) -> Status {
      jpeg_abort_decompress(&cinfo);
      jpeg_destroy_decompress(&cinfo);
      return JXL_FAILURE("%s", str);
    };
    int read_header_result = jpeg_read_header(&cinfo, TRUE);
    // TODO(eustas): what about JPEG_HEADER_TABLES_ONLY?
    if (read_header_result == JPEG_SUSPENDED) {
      return failure("truncated JPEG input");
    }
    if (!VerifyDimensions(constraints, cinfo.image_width, cinfo.image_height)) {
      return failure("image too big");
    }
    // Might cause CPU-zip bomb.
    if (cinfo.arith_code) {
      return failure("arithmetic code JPEGs are not supported");
    }
    int nbcomp = cinfo.num_components;
    if (nbcomp != 1 && nbcomp != 3) {
      return failure("unsupported number of components in JPEG");
    }
    if (!ReadICCProfile(&cinfo, &ppf->icc)) {
      ppf->icc.clear();
      // Default to SRGB
      // Actually, (cinfo.output_components == nbcomp) will be checked after
      // `jpeg_start_decompress`.
      ppf->color_encoding.color_space =
          (nbcomp == 1) ? JXL_COLOR_SPACE_GRAY : JXL_COLOR_SPACE_RGB;
      ppf->color_encoding.white_point = JXL_WHITE_POINT_D65;
      ppf->color_encoding.primaries = JXL_PRIMARIES_SRGB;
      ppf->color_encoding.transfer_function = JXL_TRANSFER_FUNCTION_SRGB;
      ppf->color_encoding.rendering_intent = JXL_RENDERING_INTENT_PERCEPTUAL;
    }
    ReadExif(&cinfo, &ppf->metadata.exif);
    if (!ApplyColorHints(color_hints, /*color_already_set=*/true,
                         /*is_gray=*/false, ppf)) {
      return failure("ApplyColorHints failed");
    }

    ppf->info.xsize = cinfo.image_width;
    ppf->info.ysize = cinfo.image_height;
    // Original data is uint, so exponent_bits_per_sample = 0.
    ppf->info.bits_per_sample = BITS_IN_JSAMPLE;
    JXL_ASSERT(BITS_IN_JSAMPLE == 8 || BITS_IN_JSAMPLE == 16);
    ppf->info.exponent_bits_per_sample = 0;
    ppf->info.uses_original_profile = true;

    // No alpha in JPG
    ppf->info.alpha_bits = 0;
    ppf->info.alpha_exponent_bits = 0;

    ppf->info.num_color_channels = nbcomp;
    ppf->info.orientation = JXL_ORIENT_IDENTITY;

    if (dparams && dparams->num_colors > 0) {
      cinfo.quantize_colors = TRUE;
      cinfo.desired_number_of_colors = dparams->num_colors;
      cinfo.two_pass_quantize = dparams->two_pass_quant;
      cinfo.dither_mode = (J_DITHER_MODE)dparams->dither_mode;
    }

    jpeg_start_decompress(&cinfo);
    JXL_ASSERT(cinfo.out_color_components == nbcomp);
    JxlDataType data_type =
        ppf->info.bits_per_sample <= 8 ? JXL_TYPE_UINT8 : JXL_TYPE_UINT16;

    const JxlPixelFormat format{
        /*num_channels=*/static_cast<uint32_t>(nbcomp),
        data_type,
        /*endianness=*/JXL_NATIVE_ENDIAN,
        /*align=*/0,
    };
    ppf->frames.clear();
    // Allocates the frame buffer.
    ppf->frames.emplace_back(cinfo.image_width, cinfo.image_height, format);
    const auto& frame = ppf->frames.back();
    JXL_ASSERT(sizeof(JSAMPLE) * cinfo.out_color_components *
                   cinfo.image_width <=
               frame.color.stride);

    if (cinfo.quantize_colors) {
      jxl::msan::UnpoisonMemory(cinfo.colormap, cinfo.out_color_components *
                                                    sizeof(cinfo.colormap[0]));
      for (int c = 0; c < cinfo.out_color_components; ++c) {
        jxl::msan::UnpoisonMemory(
            cinfo.colormap[c],
            cinfo.actual_number_of_colors * sizeof(cinfo.colormap[c][0]));
      }
    }
    for (size_t y = 0; y < cinfo.image_height; ++y) {
      JSAMPROW rows[] = {reinterpret_cast<JSAMPLE*>(
          static_cast<uint8_t*>(frame.color.pixels()) +
          frame.color.stride * y)};
      jpeg_read_scanlines(&cinfo, rows, 1);
      msan::UnpoisonMemory(rows[0], sizeof(JSAMPLE) * cinfo.output_components *
                                        cinfo.image_width);
      if (dparams && dparams->num_colors > 0) {
        UnmapColors(rows[0], cinfo.output_width, cinfo.out_color_components,
                    cinfo.colormap, cinfo.actual_number_of_colors);
      }
    }

    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    return true;
  };

  return try_catch_block();
#else
  return false;
#endif
}

}  // namespace extras
}  // namespace jxl
