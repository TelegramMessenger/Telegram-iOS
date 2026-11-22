// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/jpg.h"

#if JPEGXL_ENABLE_JPEG
#include <jpeglib.h>
#include <setjmp.h>
#endif
#include <stdint.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <fstream>
#include <iterator>
#include <memory>
#include <numeric>
#include <sstream>
#include <utility>
#include <vector>

#include "lib/extras/exif.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/sanitizers.h"
#if JPEGXL_ENABLE_SJPEG
#include "sjpeg.h"
#include "sjpegi.h"
#endif

namespace jxl {
namespace extras {

#if JPEGXL_ENABLE_JPEG
namespace {

constexpr unsigned char kICCSignature[12] = {
    0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00};
constexpr int kICCMarker = JPEG_APP0 + 2;
constexpr size_t kMaxBytesInMarker = 65533;

constexpr unsigned char kExifSignature[6] = {0x45, 0x78, 0x69,
                                             0x66, 0x00, 0x00};
constexpr int kExifMarker = JPEG_APP0 + 1;

enum class JpegEncoder {
  kLibJpeg,
  kSJpeg,
};

#define ARRAY_SIZE(X) (sizeof(X) / sizeof((X)[0]))

// Popular jpeg scan scripts
// The fields of the individual scans are:
// comps_in_scan, component_index[], Ss, Se, Ah, Al
static constexpr jpeg_scan_info kScanScript1[] = {
    {1, {0}, 0, 0, 0, 0},   //
    {1, {1}, 0, 0, 0, 0},   //
    {1, {2}, 0, 0, 0, 0},   //
    {1, {0}, 1, 8, 0, 0},   //
    {1, {0}, 9, 63, 0, 0},  //
    {1, {1}, 1, 63, 0, 0},  //
    {1, {2}, 1, 63, 0, 0},  //
};
static constexpr size_t kNumScans1 = ARRAY_SIZE(kScanScript1);

static constexpr jpeg_scan_info kScanScript2[] = {
    {1, {0}, 0, 0, 0, 0},   //
    {1, {1}, 0, 0, 0, 0},   //
    {1, {2}, 0, 0, 0, 0},   //
    {1, {0}, 1, 2, 0, 1},   //
    {1, {0}, 3, 63, 0, 1},  //
    {1, {0}, 1, 63, 1, 0},  //
    {1, {1}, 1, 63, 0, 0},  //
    {1, {2}, 1, 63, 0, 0},  //
};
static constexpr size_t kNumScans2 = ARRAY_SIZE(kScanScript2);

static constexpr jpeg_scan_info kScanScript3[] = {
    {1, {0}, 0, 0, 0, 0},   //
    {1, {1}, 0, 0, 0, 0},   //
    {1, {2}, 0, 0, 0, 0},   //
    {1, {0}, 1, 63, 0, 2},  //
    {1, {0}, 1, 63, 2, 1},  //
    {1, {0}, 1, 63, 1, 0},  //
    {1, {1}, 1, 63, 0, 0},  //
    {1, {2}, 1, 63, 0, 0},  //
};
static constexpr size_t kNumScans3 = ARRAY_SIZE(kScanScript3);

static constexpr jpeg_scan_info kScanScript4[] = {
    {3, {0, 1, 2}, 0, 0, 0, 1},  //
    {1, {0}, 1, 5, 0, 2},        //
    {1, {2}, 1, 63, 0, 1},       //
    {1, {1}, 1, 63, 0, 1},       //
    {1, {0}, 6, 63, 0, 2},       //
    {1, {0}, 1, 63, 2, 1},       //
    {3, {0, 1, 2}, 0, 0, 1, 0},  //
    {1, {2}, 1, 63, 1, 0},       //
    {1, {1}, 1, 63, 1, 0},       //
    {1, {0}, 1, 63, 1, 0},       //
};
static constexpr size_t kNumScans4 = ARRAY_SIZE(kScanScript4);

static constexpr jpeg_scan_info kScanScript5[] = {
    {3, {0, 1, 2}, 0, 0, 0, 1},  //
    {1, {0}, 1, 5, 0, 2},        //
    {1, {1}, 1, 5, 0, 2},        //
    {1, {2}, 1, 5, 0, 2},        //
    {1, {1}, 6, 63, 0, 2},       //
    {1, {2}, 6, 63, 0, 2},       //
    {1, {0}, 6, 63, 0, 2},       //
    {1, {0}, 1, 63, 2, 1},       //
    {1, {1}, 1, 63, 2, 1},       //
    {1, {2}, 1, 63, 2, 1},       //
    {3, {0, 1, 2}, 0, 0, 1, 0},  //
    {1, {0}, 1, 63, 1, 0},       //
    {1, {1}, 1, 63, 1, 0},       //
    {1, {2}, 1, 63, 1, 0},       //
};
static constexpr size_t kNumScans5 = ARRAY_SIZE(kScanScript5);

// default progressive mode of jpegli
static constexpr jpeg_scan_info kScanScript6[] = {
    {3, {0, 1, 2}, 0, 0, 0, 0},  //
    {1, {0}, 1, 2, 0, 0},        //
    {1, {1}, 1, 2, 0, 0},        //
    {1, {2}, 1, 2, 0, 0},        //
    {1, {0}, 3, 63, 0, 2},       //
    {1, {1}, 3, 63, 0, 2},       //
    {1, {2}, 3, 63, 0, 2},       //
    {1, {0}, 3, 63, 2, 1},       //
    {1, {1}, 3, 63, 2, 1},       //
    {1, {2}, 3, 63, 2, 1},       //
    {1, {0}, 3, 63, 1, 0},       //
    {1, {1}, 3, 63, 1, 0},       //
    {1, {2}, 3, 63, 1, 0},       //
};
static constexpr size_t kNumScans6 = ARRAY_SIZE(kScanScript6);

// Adapt RGB scan info to grayscale jpegs.
void FilterScanComponents(const jpeg_compress_struct* cinfo,
                          jpeg_scan_info* si) {
  const int all_comps_in_scan = si->comps_in_scan;
  si->comps_in_scan = 0;
  for (int j = 0; j < all_comps_in_scan; ++j) {
    const int component = si->component_index[j];
    if (component < cinfo->input_components) {
      si->component_index[si->comps_in_scan++] = component;
    }
  }
}

Status SetJpegProgression(int progressive_id,
                          std::vector<jpeg_scan_info>* scan_infos,
                          jpeg_compress_struct* cinfo) {
  if (progressive_id < 0) {
    return true;
  }
  if (progressive_id == 0) {
    jpeg_simple_progression(cinfo);
    return true;
  }
  constexpr const jpeg_scan_info* kScanScripts[] = {kScanScript1, kScanScript2,
                                                    kScanScript3, kScanScript4,
                                                    kScanScript5, kScanScript6};
  constexpr size_t kNumScans[] = {kNumScans1, kNumScans2, kNumScans3,
                                  kNumScans4, kNumScans5, kNumScans6};
  if (progressive_id > static_cast<int>(ARRAY_SIZE(kNumScans))) {
    return JXL_FAILURE("Unknown jpeg scan script id %d", progressive_id);
  }
  const jpeg_scan_info* scan_script = kScanScripts[progressive_id - 1];
  const size_t num_scans = kNumScans[progressive_id - 1];
  // filter scan script for number of components
  for (size_t i = 0; i < num_scans; ++i) {
    jpeg_scan_info scan_info = scan_script[i];
    FilterScanComponents(cinfo, &scan_info);
    if (scan_info.comps_in_scan > 0) {
      scan_infos->emplace_back(std::move(scan_info));
    }
  }
  cinfo->scan_info = scan_infos->data();
  cinfo->num_scans = scan_infos->size();
  return true;
}

bool IsSRGBEncoding(const JxlColorEncoding& c) {
  return ((c.color_space == JXL_COLOR_SPACE_RGB ||
           c.color_space == JXL_COLOR_SPACE_GRAY) &&
          c.primaries == JXL_PRIMARIES_SRGB &&
          c.white_point == JXL_WHITE_POINT_D65 &&
          c.transfer_function == JXL_TRANSFER_FUNCTION_SRGB);
}

void WriteICCProfile(jpeg_compress_struct* const cinfo,
                     const std::vector<uint8_t>& icc) {
  constexpr size_t kMaxIccBytesInMarker =
      kMaxBytesInMarker - sizeof kICCSignature - 2;
  const int num_markers =
      static_cast<int>(DivCeil(icc.size(), kMaxIccBytesInMarker));
  size_t begin = 0;
  for (int current_marker = 0; current_marker < num_markers; ++current_marker) {
    const size_t length = std::min(kMaxIccBytesInMarker, icc.size() - begin);
    jpeg_write_m_header(
        cinfo, kICCMarker,
        static_cast<unsigned int>(length + sizeof kICCSignature + 2));
    for (const unsigned char c : kICCSignature) {
      jpeg_write_m_byte(cinfo, c);
    }
    jpeg_write_m_byte(cinfo, current_marker + 1);
    jpeg_write_m_byte(cinfo, num_markers);
    for (size_t i = 0; i < length; ++i) {
      jpeg_write_m_byte(cinfo, icc[begin]);
      ++begin;
    }
  }
}
void WriteExif(jpeg_compress_struct* const cinfo,
               const std::vector<uint8_t>& exif) {
  jpeg_write_m_header(
      cinfo, kExifMarker,
      static_cast<unsigned int>(exif.size() + sizeof kExifSignature));
  for (const unsigned char c : kExifSignature) {
    jpeg_write_m_byte(cinfo, c);
  }
  for (size_t i = 0; i < exif.size(); ++i) {
    jpeg_write_m_byte(cinfo, exif[i]);
  }
}

Status SetChromaSubsampling(const std::string& subsampling,
                            jpeg_compress_struct* const cinfo) {
  const std::pair<const char*,
                  std::pair<std::array<uint8_t, 3>, std::array<uint8_t, 3>>>
      options[] = {{"444", {{{1, 1, 1}}, {{1, 1, 1}}}},
                   {"420", {{{2, 1, 1}}, {{2, 1, 1}}}},
                   {"422", {{{2, 1, 1}}, {{1, 1, 1}}}},
                   {"440", {{{1, 1, 1}}, {{2, 1, 1}}}}};
  for (const auto& option : options) {
    if (subsampling == option.first) {
      for (size_t i = 0; i < 3; i++) {
        cinfo->comp_info[i].h_samp_factor = option.second.first[i];
        cinfo->comp_info[i].v_samp_factor = option.second.second[i];
      }
      return true;
    }
  }
  return false;
}

struct JpegParams {
  // Common between sjpeg and libjpeg
  int quality = 100;
  std::string chroma_subsampling = "444";
  // Libjpeg parameters
  int progressive_id = -1;
  bool optimize_coding = true;
  bool is_xyb = false;
  // Sjpeg parameters
  int libjpeg_quality = 0;
  std::string libjpeg_chroma_subsampling = "444";
  float psnr_target = 0;
  std::string custom_base_quant_fn;
  float search_q_start = 65.0f;
  float search_q_min = 1.0f;
  float search_q_max = 100.0f;
  int search_max_iters = 20;
  float search_tolerance = 0.1f;
  float search_q_precision = 0.01f;
  float search_first_iter_slope = 3.0f;
  bool enable_adaptive_quant = true;
};

Status EncodeWithLibJpeg(const PackedImage& image, const JxlBasicInfo& info,
                         const std::vector<uint8_t>& icc,
                         std::vector<uint8_t> exif, const JpegParams& params,
                         std::vector<uint8_t>* bytes) {
  if (BITS_IN_JSAMPLE != 8 || sizeof(JSAMPLE) != 1) {
    return JXL_FAILURE("Only 8 bit JSAMPLE is supported.");
  }
  jpeg_compress_struct cinfo = {};
  jpeg_error_mgr jerr;
  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_compress(&cinfo);
  unsigned char* buffer = nullptr;
  unsigned long size = 0;
  jpeg_mem_dest(&cinfo, &buffer, &size);
  cinfo.image_width = image.xsize;
  cinfo.image_height = image.ysize;
  cinfo.input_components = info.num_color_channels;
  cinfo.in_color_space = info.num_color_channels == 1 ? JCS_GRAYSCALE : JCS_RGB;
  jpeg_set_defaults(&cinfo);
  cinfo.optimize_coding = params.optimize_coding;
  if (cinfo.input_components == 3) {
    JXL_RETURN_IF_ERROR(
        SetChromaSubsampling(params.chroma_subsampling, &cinfo));
  }
  if (params.is_xyb) {
    // Tell libjpeg not to convert XYB data to YCbCr.
    jpeg_set_colorspace(&cinfo, JCS_RGB);
  }
  jpeg_set_quality(&cinfo, params.quality, TRUE);
  std::vector<jpeg_scan_info> scan_infos;
  JXL_RETURN_IF_ERROR(
      SetJpegProgression(params.progressive_id, &scan_infos, &cinfo));
  jpeg_start_compress(&cinfo, TRUE);
  if (!icc.empty()) {
    WriteICCProfile(&cinfo, icc);
  }
  if (!exif.empty()) {
    ResetExifOrientation(exif);
    WriteExif(&cinfo, exif);
  }
  if (cinfo.input_components > 3 || cinfo.input_components < 0)
    return JXL_FAILURE("invalid numbers of components");

  std::vector<uint8_t> row_bytes(image.stride);
  const uint8_t* pixels = reinterpret_cast<const uint8_t*>(image.pixels());
  if (cinfo.num_components == (int)image.format.num_channels &&
      image.format.data_type == JXL_TYPE_UINT8) {
    for (size_t y = 0; y < info.ysize; ++y) {
      memcpy(&row_bytes[0], pixels + y * image.stride, image.stride);
      JSAMPROW row[] = {row_bytes.data()};
      jpeg_write_scanlines(&cinfo, row, 1);
    }
  } else if (image.format.data_type == JXL_TYPE_UINT8) {
    for (size_t y = 0; y < info.ysize; ++y) {
      const uint8_t* image_row = pixels + y * image.stride;
      for (size_t x = 0; x < info.xsize; ++x) {
        const uint8_t* image_pixel = image_row + x * image.pixel_stride();
        memcpy(&row_bytes[x * cinfo.num_components], image_pixel,
               cinfo.num_components);
      }
      JSAMPROW row[] = {row_bytes.data()};
      jpeg_write_scanlines(&cinfo, row, 1);
    }
  } else {
    for (size_t y = 0; y < info.ysize; ++y) {
      const uint8_t* image_row = pixels + y * image.stride;
      for (size_t x = 0; x < info.xsize; ++x) {
        const uint8_t* image_pixel = image_row + x * image.pixel_stride();
        for (int c = 0; c < cinfo.num_components; ++c) {
          uint32_t val16 = (image_pixel[2 * c] << 8) + image_pixel[2 * c + 1];
          row_bytes[x * cinfo.num_components + c] = (val16 + 128) / 257;
        }
      }
      JSAMPROW row[] = {row_bytes.data()};
      jpeg_write_scanlines(&cinfo, row, 1);
    }
  }
  jpeg_finish_compress(&cinfo);
  jpeg_destroy_compress(&cinfo);
  bytes->resize(size);
  // Compressed image data is initialized by libjpeg, which we are not
  // instrumenting with msan.
  msan::UnpoisonMemory(buffer, size);
  std::copy_n(buffer, size, bytes->data());
  std::free(buffer);
  return true;
}

#if JPEGXL_ENABLE_SJPEG
struct MySearchHook : public sjpeg::SearchHook {
  uint8_t base_tables[2][64];
  float q_start;
  float q_precision;
  float first_iter_slope;
  void ReadBaseTables(const std::string& fn) {
    const uint8_t kJPEGAnnexKMatrices[2][64] = {
        {16, 11, 10, 16, 24,  40,  51,  61,  12, 12, 14, 19, 26,  58,  60,  55,
         14, 13, 16, 24, 40,  57,  69,  56,  14, 17, 22, 29, 51,  87,  80,  62,
         18, 22, 37, 56, 68,  109, 103, 77,  24, 35, 55, 64, 81,  104, 113, 92,
         49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99},
        {17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99,
         24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99,
         99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
         99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99}};
    memcpy(base_tables[0], kJPEGAnnexKMatrices[0], sizeof(base_tables[0]));
    memcpy(base_tables[1], kJPEGAnnexKMatrices[1], sizeof(base_tables[1]));
    if (!fn.empty()) {
      std::ifstream f(fn);
      std::string line;
      int idx = 0;
      while (idx < 128 && std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;
        std::istringstream line_stream(line);
        std::string token;
        while (idx < 128 && std::getline(line_stream, token, ',')) {
          uint8_t val = std::stoi(token);
          base_tables[idx / 64][idx % 64] = val;
          idx++;
        }
      }
    }
  }
  bool Setup(const sjpeg::EncoderParam& param) override {
    sjpeg::SearchHook::Setup(param);
    q = q_start;
    return true;
  }
  void NextMatrix(int idx, uint8_t dst[64]) override {
    float factor = (q <= 0)       ? 5000.0f
                   : (q < 50.0f)  ? 5000.0f / q
                   : (q < 100.0f) ? 2 * (100.0f - q)
                                  : 0.0f;
    sjpeg::SetQuantMatrix(base_tables[idx], factor, dst);
  }
  bool Update(float result) override {
    value = result;
    if (fabs(value - target) < tolerance * target) {
      return true;
    }
    if (value > target) {
      qmax = q;
    } else {
      qmin = q;
    }
    if (qmin == qmax) {
      return true;
    }
    const float last_q = q;
    if (pass == 0) {
      q += first_iter_slope *
           (for_size ? 0.1 * std::log(target / value) : (target - value));
      q = std::max(qmin, std::min(qmax, q));
    } else {
      q = (qmin + qmax) / 2.;
    }
    return (pass > 0 && fabs(q - last_q) < q_precision);
  }
  ~MySearchHook() override {}
};
#endif

Status EncodeWithSJpeg(const PackedImage& image, const JxlBasicInfo& info,
                       const std::vector<uint8_t>& icc,
                       std::vector<uint8_t> exif, const JpegParams& params,
                       std::vector<uint8_t>* bytes) {
#if !JPEGXL_ENABLE_SJPEG
  return JXL_FAILURE("JPEG XL was built without sjpeg support");
#else
  if (image.format.data_type != JXL_TYPE_UINT8) {
    return JXL_FAILURE("Unsupported pixel data type");
  }
  if (info.alpha_bits > 0) {
    return JXL_FAILURE("alpha is not supported");
  }
  sjpeg::EncoderParam param(params.quality);
  if (!icc.empty()) {
    param.iccp.assign(icc.begin(), icc.end());
  }
  if (!exif.empty()) {
    ResetExifOrientation(exif);
    param.exif.assign(exif.begin(), exif.end());
  }
  if (params.chroma_subsampling == "444") {
    param.yuv_mode = SJPEG_YUV_444;
  } else if (params.chroma_subsampling == "420") {
    param.yuv_mode = SJPEG_YUV_420;
  } else if (params.chroma_subsampling == "420sharp") {
    param.yuv_mode = SJPEG_YUV_SHARP;
  } else {
    return JXL_FAILURE("sjpeg does not support this chroma subsampling mode");
  }
  param.adaptive_quantization = params.enable_adaptive_quant;
  std::unique_ptr<MySearchHook> hook;
  if (params.libjpeg_quality > 0) {
    JpegParams libjpeg_params;
    libjpeg_params.quality = params.libjpeg_quality;
    libjpeg_params.chroma_subsampling = params.libjpeg_chroma_subsampling;
    std::vector<uint8_t> libjpeg_bytes;
    JXL_RETURN_IF_ERROR(EncodeWithLibJpeg(image, info, icc, exif,
                                          libjpeg_params, &libjpeg_bytes));
    param.target_mode = sjpeg::EncoderParam::TARGET_SIZE;
    param.target_value = libjpeg_bytes.size();
  }
  if (params.psnr_target > 0) {
    param.target_mode = sjpeg::EncoderParam::TARGET_PSNR;
    param.target_value = params.psnr_target;
  }
  if (param.target_mode != sjpeg::EncoderParam::TARGET_NONE) {
    param.passes = params.search_max_iters;
    param.tolerance = params.search_tolerance;
    param.qmin = params.search_q_min;
    param.qmax = params.search_q_max;
    hook.reset(new MySearchHook());
    hook->ReadBaseTables(params.custom_base_quant_fn);
    hook->q_start = params.search_q_start;
    hook->q_precision = params.search_q_precision;
    hook->first_iter_slope = params.search_first_iter_slope;
    param.search_hook = hook.get();
  }
  size_t stride = info.xsize * 3;
  const uint8_t* pixels = reinterpret_cast<const uint8_t*>(image.pixels());
  std::string output;
  JXL_RETURN_IF_ERROR(
      sjpeg::Encode(pixels, image.xsize, image.ysize, stride, param, &output));
  bytes->assign(
      reinterpret_cast<const uint8_t*>(output.data()),
      reinterpret_cast<const uint8_t*>(output.data() + output.size()));
  return true;
#endif
}

Status EncodeImageJPG(const PackedImage& image, const JxlBasicInfo& info,
                      const std::vector<uint8_t>& icc,
                      std::vector<uint8_t> exif, JpegEncoder encoder,
                      const JpegParams& params, ThreadPool* pool,
                      std::vector<uint8_t>* bytes) {
  if (params.quality > 100) {
    return JXL_FAILURE("please specify a 0-100 JPEG quality");
  }

  switch (encoder) {
    case JpegEncoder::kLibJpeg:
      JXL_RETURN_IF_ERROR(
          EncodeWithLibJpeg(image, info, icc, std::move(exif), params, bytes));
      break;
    case JpegEncoder::kSJpeg:
      JXL_RETURN_IF_ERROR(
          EncodeWithSJpeg(image, info, icc, std::move(exif), params, bytes));
      break;
    default:
      return JXL_FAILURE("tried to use an unknown JPEG encoder");
  }

  return true;
}

class JPEGEncoder : public Encoder {
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    std::vector<JxlPixelFormat> formats;
    for (const uint32_t num_channels : {1, 2, 3, 4}) {
      for (JxlEndianness endianness : {JXL_BIG_ENDIAN, JXL_LITTLE_ENDIAN}) {
        formats.push_back(JxlPixelFormat{/*num_channels=*/num_channels,
                                         /*data_type=*/JXL_TYPE_UINT8,
                                         /*endianness=*/endianness,
                                         /*align=*/0});
      }
      formats.push_back(JxlPixelFormat{/*num_channels=*/num_channels,
                                       /*data_type=*/JXL_TYPE_UINT16,
                                       /*endianness=*/JXL_BIG_ENDIAN,
                                       /*align=*/0});
    }
    return formats;
  }
  Status Encode(const PackedPixelFile& ppf, EncodedImage* encoded_image,
                ThreadPool* pool = nullptr) const override {
    JXL_RETURN_IF_ERROR(VerifyBasicInfo(ppf.info));
    JpegEncoder jpeg_encoder = JpegEncoder::kLibJpeg;
    JpegParams params;
    for (const auto& it : options()) {
      if (it.first == "q") {
        std::istringstream is(it.second);
        JXL_RETURN_IF_ERROR(static_cast<bool>(is >> params.quality));
      } else if (it.first == "libjpeg_quality") {
        std::istringstream is(it.second);
        JXL_RETURN_IF_ERROR(static_cast<bool>(is >> params.libjpeg_quality));
      } else if (it.first == "chroma_subsampling") {
        params.chroma_subsampling = it.second;
      } else if (it.first == "libjpeg_chroma_subsampling") {
        params.libjpeg_chroma_subsampling = it.second;
      } else if (it.first == "jpeg_encoder") {
        if (it.second == "libjpeg") {
          jpeg_encoder = JpegEncoder::kLibJpeg;
        } else if (it.second == "sjpeg") {
          jpeg_encoder = JpegEncoder::kSJpeg;
        } else {
          return JXL_FAILURE("unknown jpeg encoder \"%s\"", it.second.c_str());
        }
      } else if (it.first == "progressive") {
        std::istringstream is(it.second);
        JXL_RETURN_IF_ERROR(static_cast<bool>(is >> params.progressive_id));
      } else if (it.first == "optimize" && it.second == "OFF") {
        params.optimize_coding = false;
      } else if (it.first == "adaptive_q" && it.second == "OFF") {
        params.enable_adaptive_quant = false;
      } else if (it.first == "psnr") {
        params.psnr_target = std::stof(it.second);
      } else if (it.first == "base_quant_fn") {
        params.custom_base_quant_fn = it.second;
      } else if (it.first == "search_q_start") {
        params.search_q_start = std::stof(it.second);
      } else if (it.first == "search_q_min") {
        params.search_q_min = std::stof(it.second);
      } else if (it.first == "search_q_max") {
        params.search_q_max = std::stof(it.second);
      } else if (it.first == "search_max_iters") {
        params.search_max_iters = std::stoi(it.second);
      } else if (it.first == "search_tolerance") {
        params.search_tolerance = std::stof(it.second);
      } else if (it.first == "search_q_precision") {
        params.search_q_precision = std::stof(it.second);
      } else if (it.first == "search_first_iter_slope") {
        params.search_first_iter_slope = std::stof(it.second);
      }
    }
    params.is_xyb = (ppf.color_encoding.color_space == JXL_COLOR_SPACE_XYB);
    std::vector<uint8_t> icc;
    if (!IsSRGBEncoding(ppf.color_encoding)) {
      icc = ppf.icc;
    }
    encoded_image->bitstreams.clear();
    encoded_image->bitstreams.reserve(ppf.frames.size());
    for (const auto& frame : ppf.frames) {
      JXL_RETURN_IF_ERROR(VerifyPackedImage(frame.color, ppf.info));
      encoded_image->bitstreams.emplace_back();
      JXL_RETURN_IF_ERROR(EncodeImageJPG(
          frame.color, ppf.info, icc, ppf.metadata.exif, jpeg_encoder, params,
          pool, &encoded_image->bitstreams.back()));
    }
    return true;
  }
};

}  // namespace
#endif

std::unique_ptr<Encoder> GetJPEGEncoder() {
#if JPEGXL_ENABLE_JPEG
  return jxl::make_unique<JPEGEncoder>();
#else
  return nullptr;
#endif
}

}  // namespace extras
}  // namespace jxl
