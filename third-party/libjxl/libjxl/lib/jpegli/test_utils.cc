// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/test_utils.h"

#include <cmath>
#include <fstream>

#include "lib/jpegli/decode.h"
#include "lib/jpegli/encode.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/sanitizers.h"

#if !defined(TEST_DATA_PATH)
#include "tools/cpp/runfiles/runfiles.h"
#endif

namespace jpegli {

#define JPEG_API_FN(name) jpegli_##name
#include "lib/jpegli/test_utils-inl.h"
#undef JPEG_API_FN

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

std::vector<uint8_t> ReadTestData(const std::string& filename) {
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
  return data;
}

void CustomQuantTable::Generate() {
  basic_table.resize(DCTSIZE2);
  quantval.resize(DCTSIZE2);
  switch (table_type) {
    case 0: {
      for (int k = 0; k < DCTSIZE2; ++k) {
        basic_table[k] = k + 1;
      }
      break;
    }
    default:
      for (int k = 0; k < DCTSIZE2; ++k) {
        basic_table[k] = table_type;
      }
  }
  for (int k = 0; k < DCTSIZE2; ++k) {
    quantval[k] = (basic_table[k] * scale_factor + 50U) / 100U;
    quantval[k] = std::max(quantval[k], 1U);
    quantval[k] = std::min(quantval[k], 65535U);
    if (!add_raw) {
      quantval[k] = std::min(quantval[k], force_baseline ? 255U : 32767U);
    }
  }
}

bool PNMParser::ParseHeader(const uint8_t** pos, size_t* xsize, size_t* ysize,
                            size_t* num_channels, size_t* bitdepth) {
  if (pos_[0] != 'P' || (pos_[1] != '5' && pos_[1] != '6')) {
    fprintf(stderr, "Invalid PNM header.");
    return false;
  }
  *num_channels = (pos_[1] == '5' ? 1 : 3);
  pos_ += 2;

  size_t maxval;
  if (!SkipWhitespace() || !ParseUnsigned(xsize) || !SkipWhitespace() ||
      !ParseUnsigned(ysize) || !SkipWhitespace() || !ParseUnsigned(&maxval) ||
      !SkipWhitespace()) {
    return false;
  }
  if (maxval == 0 || maxval >= 65536) {
    fprintf(stderr, "Invalid maxval value.\n");
    return false;
  }
  bool found_bitdepth = false;
  for (int bits = 1; bits <= 16; ++bits) {
    if (maxval == (1u << bits) - 1) {
      *bitdepth = bits;
      found_bitdepth = true;
      break;
    }
  }
  if (!found_bitdepth) {
    fprintf(stderr, "Invalid maxval value.\n");
    return false;
  }

  *pos = pos_;
  return true;
}

bool PNMParser::ParseUnsigned(size_t* number) {
  if (pos_ == end_ || *pos_ < '0' || *pos_ > '9') {
    fprintf(stderr, "Expected unsigned number.\n");
    return false;
  }
  *number = 0;
  while (pos_ < end_ && *pos_ >= '0' && *pos_ <= '9') {
    *number *= 10;
    *number += *pos_ - '0';
    ++pos_;
  }

  return true;
}

bool PNMParser::SkipWhitespace() {
  if (pos_ == end_ || !IsWhitespace(*pos_)) {
    fprintf(stderr, "Expected whitespace.\n");
    return false;
  }
  while (pos_ < end_ && IsWhitespace(*pos_)) {
    ++pos_;
  }
  return true;
}

bool ReadPNM(const std::vector<uint8_t>& data, size_t* xsize, size_t* ysize,
             size_t* num_channels, size_t* bitdepth,
             std::vector<uint8_t>* pixels) {
  if (data.size() < 2) {
    fprintf(stderr, "PNM file too small.\n");
    return false;
  }
  PNMParser parser(data.data(), data.size());
  const uint8_t* pos = nullptr;
  if (!parser.ParseHeader(&pos, xsize, ysize, num_channels, bitdepth)) {
    return false;
  }
  pixels->resize(data.data() + data.size() - pos);
  memcpy(&(*pixels)[0], pos, pixels->size());
  return true;
}

std::string ColorSpaceName(J_COLOR_SPACE colorspace) {
  switch (colorspace) {
    case JCS_UNKNOWN:
      return "UNKNOWN";
    case JCS_GRAYSCALE:
      return "GRAYSCALE";
    case JCS_RGB:
      return "RGB";
    case JCS_YCbCr:
      return "YCbCr";
    case JCS_CMYK:
      return "CMYK";
    case JCS_YCCK:
      return "YCCK";
    default:
      return "";
  }
}

std::string IOMethodName(JpegliDataType data_type,
                         JpegliEndianness endianness) {
  std::string retval;
  if (data_type == JPEGLI_TYPE_UINT8) {
    return "";
  } else if (data_type == JPEGLI_TYPE_UINT16) {
    retval = "UINT16";
  } else if (data_type == JPEGLI_TYPE_FLOAT) {
    retval = "FLOAT";
  }
  if (endianness == JPEGLI_LITTLE_ENDIAN) {
    retval += "LE";
  } else if (endianness == JPEGLI_BIG_ENDIAN) {
    retval += "BE";
  }
  return retval;
}

std::string SamplingId(const CompressParams& jparams) {
  std::stringstream os;
  JXL_CHECK(jparams.h_sampling.size() == jparams.v_sampling.size());
  if (!jparams.h_sampling.empty()) {
    size_t len = jparams.h_sampling.size();
    while (len > 1 && jparams.h_sampling[len - 1] == 1 &&
           jparams.v_sampling[len - 1] == 1) {
      --len;
    }
    os << "SAMP";
    for (size_t i = 0; i < len; ++i) {
      if (i > 0) os << "_";
      os << jparams.h_sampling[i] << "x" << jparams.v_sampling[i];
    }
  }
  return os.str();
}

std::ostream& operator<<(std::ostream& os, const TestImage& input) {
  os << input.xsize << "x" << input.ysize;
  os << IOMethodName(input.data_type, input.endianness);
  if (input.color_space != JCS_RGB) {
    os << "InputColor" << ColorSpaceName((J_COLOR_SPACE)input.color_space);
  }
  if (input.color_space == JCS_UNKNOWN) {
    os << input.components;
  }
  return os;
}

std::ostream& operator<<(std::ostream& os, const CompressParams& jparams) {
  os << "Q" << jparams.quality;
  os << SamplingId(jparams);
  if (jparams.set_jpeg_colorspace) {
    os << "JpegColor"
       << ColorSpaceName((J_COLOR_SPACE)jparams.jpeg_color_space);
  }
  if (!jparams.comp_ids.empty()) {
    os << "CID";
    for (size_t i = 0; i < jparams.comp_ids.size(); ++i) {
      os << jparams.comp_ids[i];
    }
  }
  if (!jparams.quant_indexes.empty()) {
    os << "QIDX";
    for (size_t i = 0; i < jparams.quant_indexes.size(); ++i) {
      os << jparams.quant_indexes[i];
    }
    for (const auto& table : jparams.quant_tables) {
      os << "TABLE" << table.slot_idx << "T" << table.table_type << "F"
         << table.scale_factor
         << (table.add_raw          ? "R"
             : table.force_baseline ? "B"
                                    : "");
    }
  }
  if (jparams.progressive_mode >= 0) {
    os << "P" << jparams.progressive_mode;
  } else if (jparams.simple_progression) {
    os << "Psimple";
  }
  if (jparams.optimize_coding == 1) {
    os << "OptimizedCode";
  } else if (jparams.optimize_coding == 0) {
    os << "FixedCode";
    if (jparams.use_flat_dc_luma_code) {
      os << "FlatDCLuma";
    } else if (jparams.omit_standard_tables) {
      os << "OmitDHT";
    }
  }
  if (!jparams.use_adaptive_quantization) {
    os << "NoAQ";
  }
  if (jparams.restart_interval > 0) {
    os << "R" << jparams.restart_interval;
  }
  if (jparams.restart_in_rows > 0) {
    os << "RR" << jparams.restart_in_rows;
  }
  if (jparams.xyb_mode) {
    os << "XYB";
  } else if (jparams.libjpeg_mode) {
    os << "Libjpeg";
  }
  if (jparams.override_JFIF >= 0) {
    os << (jparams.override_JFIF ? "AddJFIF" : "NoJFIF");
  }
  if (jparams.override_Adobe >= 0) {
    os << (jparams.override_Adobe ? "AddAdobe" : "NoAdobe");
  }
  if (jparams.add_marker) {
    os << "AddMarker";
  }
  if (!jparams.icc.empty()) {
    os << "ICCSize" << jparams.icc.size();
  }
  if (jparams.smoothing_factor != 0) {
    os << "SF" << jparams.smoothing_factor;
  }
  return os;
}

void SetNumChannels(J_COLOR_SPACE colorspace, size_t* channels) {
  if (colorspace == JCS_GRAYSCALE) {
    *channels = 1;
  } else if (colorspace == JCS_RGB || colorspace == JCS_YCbCr) {
    *channels = 3;
  } else if (colorspace == JCS_CMYK || colorspace == JCS_YCCK) {
    *channels = 4;
  } else if (colorspace == JCS_UNKNOWN) {
    JXL_CHECK(*channels <= 4);
  } else {
    JXL_ABORT();
  }
}

void RGBToYCbCr(float r, float g, float b, float* y, float* cb, float* cr) {
  *y = 0.299f * r + 0.587f * g + 0.114f * b;
  *cb = -0.168736f * r - 0.331264f * g + 0.5f * b + 0.5f;
  *cr = 0.5f * r - 0.418688f * g - 0.081312f * b + 0.5f;
}

void ConvertPixel(const uint8_t* input_rgb, uint8_t* out,
                  J_COLOR_SPACE colorspace, size_t num_channels,
                  JpegliDataType data_type = JPEGLI_TYPE_UINT8,
                  bool swap_endianness = JPEGLI_NATIVE_ENDIAN) {
  const float kMul = 255.0f;
  float r = input_rgb[0] / kMul;
  float g = input_rgb[1] / kMul;
  float b = input_rgb[2] / kMul;
  uint8_t out8[MAX_COMPONENTS];
  if (colorspace == JCS_GRAYSCALE) {
    const float Y = 0.299f * r + 0.587f * g + 0.114f * b;
    out8[0] = static_cast<uint8_t>(std::round(Y * kMul));
  } else if (colorspace == JCS_RGB || colorspace == JCS_UNKNOWN) {
    for (size_t c = 0; c < num_channels; ++c) {
      out8[c] = input_rgb[std::min<size_t>(2, c)];
    }
  } else if (colorspace == JCS_YCbCr) {
    float Y, Cb, Cr;
    RGBToYCbCr(r, g, b, &Y, &Cb, &Cr);
    out8[0] = static_cast<uint8_t>(std::round(Y * kMul));
    out8[1] = static_cast<uint8_t>(std::round(Cb * kMul));
    out8[2] = static_cast<uint8_t>(std::round(Cr * kMul));
  } else if (colorspace == JCS_CMYK || colorspace == JCS_YCCK) {
    float K = 1.0f - std::max(r, std::max(g, b));
    float scaleK = 1.0f / (1.0f - K);
    r *= scaleK;
    g *= scaleK;
    b *= scaleK;
    if (colorspace == JCS_CMYK) {
      out8[0] = static_cast<uint8_t>(std::round((1.0f - r) * kMul));
      out8[1] = static_cast<uint8_t>(std::round((1.0f - g) * kMul));
      out8[2] = static_cast<uint8_t>(std::round((1.0f - b) * kMul));
    } else if (colorspace == JCS_YCCK) {
      float Y, Cb, Cr;
      RGBToYCbCr(r, g, b, &Y, &Cb, &Cr);
      out8[0] = static_cast<uint8_t>(std::round(Y * kMul));
      out8[1] = static_cast<uint8_t>(std::round(Cb * kMul));
      out8[2] = static_cast<uint8_t>(std::round(Cr * kMul));
    }
    out8[3] = static_cast<uint8_t>(std::round(K * kMul));
  } else {
    JXL_ABORT("Colorspace %d not supported", colorspace);
  }
  if (data_type == JPEGLI_TYPE_UINT8) {
    memcpy(out, out8, num_channels);
  } else if (data_type == JPEGLI_TYPE_UINT16) {
    for (size_t c = 0; c < num_channels; ++c) {
      uint16_t val = (out8[c] << 8) + out8[c];
      val |= 0x40;  // Make little-endian and big-endian asymmetric
      if (swap_endianness) {
        val = JXL_BSWAP16(val);
      }
      memcpy(&out[sizeof(val) * c], &val, sizeof(val));
    }
  } else if (data_type == JPEGLI_TYPE_FLOAT) {
    for (size_t c = 0; c < num_channels; ++c) {
      float val = out8[c] / 255.0f;
      if (swap_endianness) {
        val = BSwapFloat(val);
      }
      memcpy(&out[sizeof(val) * c], &val, sizeof(val));
    }
  }
}

void ConvertToGrayscale(TestImage* img) {
  if (img->color_space == JCS_GRAYSCALE) return;
  JXL_CHECK(img->data_type == JPEGLI_TYPE_UINT8);
  for (size_t i = 0; i < img->pixels.size(); i += 3) {
    if (img->color_space == JCS_RGB) {
      ConvertPixel(&img->pixels[i], &img->pixels[i / 3], JCS_GRAYSCALE, 1);
    } else if (img->color_space == JCS_YCbCr) {
      img->pixels[i / 3] = img->pixels[i];
    }
  }
  img->pixels.resize(img->pixels.size() / 3);
  img->color_space = JCS_GRAYSCALE;
  img->components = 1;
}

void GeneratePixels(TestImage* img) {
  const std::vector<uint8_t> imgdata = ReadTestData("jxl/flower/flower.pnm");
  size_t xsize, ysize, channels, bitdepth;
  std::vector<uint8_t> pixels;
  JXL_CHECK(ReadPNM(imgdata, &xsize, &ysize, &channels, &bitdepth, &pixels));
  if (img->xsize == 0) img->xsize = xsize;
  if (img->ysize == 0) img->ysize = ysize;
  JXL_CHECK(img->xsize <= xsize);
  JXL_CHECK(img->ysize <= ysize);
  JXL_CHECK(3 == channels);
  JXL_CHECK(8 == bitdepth);
  size_t in_bytes_per_pixel = channels;
  size_t in_stride = xsize * in_bytes_per_pixel;
  size_t x0 = (xsize - img->xsize) / 2;
  size_t y0 = (ysize - img->ysize) / 2;
  SetNumChannels((J_COLOR_SPACE)img->color_space, &img->components);
  size_t out_bytes_per_pixel =
      jpegli_bytes_per_sample(img->data_type) * img->components;
  size_t out_stride = img->xsize * out_bytes_per_pixel;
  bool swap_endianness =
      (img->endianness == JPEGLI_LITTLE_ENDIAN && !IsLittleEndian()) ||
      (img->endianness == JPEGLI_BIG_ENDIAN && IsLittleEndian());
  img->pixels.resize(img->ysize * out_stride);
  for (size_t iy = 0; iy < img->ysize; ++iy) {
    size_t y = y0 + iy;
    for (size_t ix = 0; ix < img->xsize; ++ix) {
      size_t x = x0 + ix;
      size_t idx_in = y * in_stride + x * in_bytes_per_pixel;
      size_t idx_out = iy * out_stride + ix * out_bytes_per_pixel;
      ConvertPixel(&pixels[idx_in], &img->pixels[idx_out],
                   (J_COLOR_SPACE)img->color_space, img->components,
                   img->data_type, swap_endianness);
    }
  }
}

void GenerateRawData(const CompressParams& jparams, TestImage* img) {
  for (size_t c = 0; c < img->components; ++c) {
    size_t xsize = jparams.comp_width(*img, c);
    size_t ysize = jparams.comp_height(*img, c);
    size_t factor_y = jparams.max_v_sample() / jparams.v_samp(c);
    size_t factor_x = jparams.max_h_sample() / jparams.h_samp(c);
    size_t factor = factor_x * factor_y;
    std::vector<uint8_t> plane(ysize * xsize);
    size_t bytes_per_pixel = img->components;
    for (size_t y = 0; y < ysize; ++y) {
      for (size_t x = 0; x < xsize; ++x) {
        int result = 0;
        for (size_t iy = 0; iy < factor_y; ++iy) {
          size_t yy = std::min(y * factor_y + iy, img->ysize - 1);
          for (size_t ix = 0; ix < factor_x; ++ix) {
            size_t xx = std::min(x * factor_x + ix, img->xsize - 1);
            size_t pixel_ix = (yy * img->xsize + xx) * bytes_per_pixel + c;
            result += img->pixels[pixel_ix];
          }
        }
        result = static_cast<uint8_t>((result + factor / 2) / factor);
        plane[y * xsize + x] = result;
      }
    }
    img->raw_data.emplace_back(std::move(plane));
  }
}

void GenerateCoeffs(const CompressParams& jparams, TestImage* img) {
  for (size_t c = 0; c < img->components; ++c) {
    int xsize_blocks = jparams.comp_width(*img, c) / DCTSIZE;
    int ysize_blocks = jparams.comp_height(*img, c) / DCTSIZE;
    std::vector<JCOEF> plane(ysize_blocks * xsize_blocks * DCTSIZE2);
    for (int by = 0; by < ysize_blocks; ++by) {
      for (int bx = 0; bx < xsize_blocks; ++bx) {
        JCOEF* block = &plane[(by * xsize_blocks + bx) * DCTSIZE2];
        for (int k = 0; k < DCTSIZE2; ++k) {
          block[k] = (bx - by) / (k + 1);
        }
      }
    }
    img->coeffs.emplace_back(std::move(plane));
  }
}

void EncodeWithJpegli(const TestImage& input, const CompressParams& jparams,
                      j_compress_ptr cinfo) {
  cinfo->image_width = input.xsize;
  cinfo->image_height = input.ysize;
  cinfo->input_components = input.components;
  if (jparams.xyb_mode) {
    jpegli_set_xyb_mode(cinfo);
  }
  if (jparams.libjpeg_mode) {
    jpegli_enable_adaptive_quantization(cinfo, FALSE);
    jpegli_use_standard_quant_tables(cinfo);
    jpegli_set_progressive_level(cinfo, 0);
  }
  jpegli_set_defaults(cinfo);
  cinfo->in_color_space = (J_COLOR_SPACE)input.color_space;
  jpegli_default_colorspace(cinfo);
  if (jparams.override_JFIF >= 0) {
    cinfo->write_JFIF_header = jparams.override_JFIF;
  }
  if (jparams.override_Adobe >= 0) {
    cinfo->write_Adobe_marker = jparams.override_Adobe;
  }
  if (jparams.set_jpeg_colorspace) {
    jpegli_set_colorspace(cinfo, (J_COLOR_SPACE)jparams.jpeg_color_space);
  }
  if (!jparams.comp_ids.empty()) {
    for (int c = 0; c < cinfo->num_components; ++c) {
      cinfo->comp_info[c].component_id = jparams.comp_ids[c];
    }
  }
  if (!jparams.h_sampling.empty()) {
    for (int c = 0; c < cinfo->num_components; ++c) {
      cinfo->comp_info[c].h_samp_factor = jparams.h_sampling[c];
      cinfo->comp_info[c].v_samp_factor = jparams.v_sampling[c];
    }
  }
  jpegli_set_quality(cinfo, jparams.quality, TRUE);
  if (!jparams.quant_indexes.empty()) {
    for (int c = 0; c < cinfo->num_components; ++c) {
      cinfo->comp_info[c].quant_tbl_no = jparams.quant_indexes[c];
    }
    for (const auto& table : jparams.quant_tables) {
      if (table.add_raw) {
        cinfo->quant_tbl_ptrs[table.slot_idx] =
            jpegli_alloc_quant_table((j_common_ptr)cinfo);
        for (int k = 0; k < DCTSIZE2; ++k) {
          cinfo->quant_tbl_ptrs[table.slot_idx]->quantval[k] =
              table.quantval[k];
        }
        cinfo->quant_tbl_ptrs[table.slot_idx]->sent_table = FALSE;
      } else {
        jpegli_add_quant_table(cinfo, table.slot_idx, &table.basic_table[0],
                               table.scale_factor, table.force_baseline);
      }
    }
  }
  if (jparams.simple_progression) {
    jpegli_simple_progression(cinfo);
    JXL_CHECK(jparams.progressive_mode == -1);
  }
  if (jparams.progressive_mode > 2) {
    const ScanScript& script = kTestScript[jparams.progressive_mode - 3];
    cinfo->scan_info = script.scans;
    cinfo->num_scans = script.num_scans;
  } else if (jparams.progressive_mode >= 0) {
    jpegli_set_progressive_level(cinfo, jparams.progressive_mode);
  }
  jpegli_set_input_format(cinfo, input.data_type, input.endianness);
  jpegli_enable_adaptive_quantization(cinfo, jparams.use_adaptive_quantization);
  cinfo->restart_interval = jparams.restart_interval;
  cinfo->restart_in_rows = jparams.restart_in_rows;
  cinfo->smoothing_factor = jparams.smoothing_factor;
  if (jparams.optimize_coding == 1) {
    cinfo->optimize_coding = TRUE;
  } else if (jparams.optimize_coding == 0) {
    cinfo->optimize_coding = FALSE;
  }
  cinfo->raw_data_in = !input.raw_data.empty();
  if (jparams.optimize_coding == 0 && jparams.use_flat_dc_luma_code) {
    JHUFF_TBL* tbl = cinfo->dc_huff_tbl_ptrs[0];
    memset(tbl, 0, sizeof(*tbl));
    tbl->bits[4] = 15;
    for (int i = 0; i < 15; ++i) tbl->huffval[i] = i;
  }
  if (input.coeffs.empty()) {
    bool write_all_tables = TRUE;
    if (jparams.optimize_coding == 0 && !jparams.use_flat_dc_luma_code &&
        jparams.omit_standard_tables) {
      write_all_tables = FALSE;
      cinfo->dc_huff_tbl_ptrs[0]->sent_table = TRUE;
      cinfo->dc_huff_tbl_ptrs[1]->sent_table = TRUE;
      cinfo->ac_huff_tbl_ptrs[0]->sent_table = TRUE;
      cinfo->ac_huff_tbl_ptrs[1]->sent_table = TRUE;
    }
    jpegli_start_compress(cinfo, write_all_tables);
    if (jparams.add_marker) {
      jpegli_write_marker(cinfo, kSpecialMarker0, kMarkerData,
                          sizeof(kMarkerData));
      jpegli_write_m_header(cinfo, kSpecialMarker1, sizeof(kMarkerData));
      for (size_t p = 0; p < sizeof(kMarkerData); ++p) {
        jpegli_write_m_byte(cinfo, kMarkerData[p]);
      }
      for (size_t i = 0; i < kMarkerSequenceLen; ++i) {
        jpegli_write_marker(cinfo, kMarkerSequence[i], kMarkerData,
                            ((i + 2) % sizeof(kMarkerData)));
      }
    }
    if (!jparams.icc.empty()) {
      jpegli_write_icc_profile(cinfo, jparams.icc.data(), jparams.icc.size());
    }
  }
  if (cinfo->raw_data_in) {
    // Need to copy because jpeg API requires non-const pointers.
    std::vector<std::vector<uint8_t>> raw_data = input.raw_data;
    size_t max_lines = jparams.max_v_sample() * DCTSIZE;
    std::vector<std::vector<JSAMPROW>> rowdata(cinfo->num_components);
    std::vector<JSAMPARRAY> data(cinfo->num_components);
    for (int c = 0; c < cinfo->num_components; ++c) {
      rowdata[c].resize(jparams.v_samp(c) * DCTSIZE);
      data[c] = &rowdata[c][0];
    }
    while (cinfo->next_scanline < cinfo->image_height) {
      for (int c = 0; c < cinfo->num_components; ++c) {
        size_t cwidth = cinfo->comp_info[c].width_in_blocks * DCTSIZE;
        size_t cheight = cinfo->comp_info[c].height_in_blocks * DCTSIZE;
        size_t num_lines = jparams.v_samp(c) * DCTSIZE;
        size_t y0 = (cinfo->next_scanline / max_lines) * num_lines;
        for (size_t i = 0; i < num_lines; ++i) {
          rowdata[c][i] =
              (y0 + i < cheight ? &raw_data[c][(y0 + i) * cwidth] : nullptr);
        }
      }
      size_t num_lines = jpegli_write_raw_data(cinfo, &data[0], max_lines);
      JXL_CHECK(num_lines == max_lines);
    }
  } else if (!input.coeffs.empty()) {
    j_common_ptr comptr = reinterpret_cast<j_common_ptr>(cinfo);
    jvirt_barray_ptr* coef_arrays = reinterpret_cast<jvirt_barray_ptr*>((
        *cinfo->mem->alloc_small)(
        comptr, JPOOL_IMAGE, cinfo->num_components * sizeof(jvirt_barray_ptr)));
    for (int c = 0; c < cinfo->num_components; ++c) {
      size_t xsize_blocks = jparams.comp_width(input, c) / DCTSIZE;
      size_t ysize_blocks = jparams.comp_height(input, c) / DCTSIZE;
      coef_arrays[c] = (*cinfo->mem->request_virt_barray)(
          comptr, JPOOL_IMAGE, FALSE, xsize_blocks, ysize_blocks,
          cinfo->comp_info[c].v_samp_factor);
    }
    jpegli_write_coefficients(cinfo, coef_arrays);
    if (jparams.add_marker) {
      jpegli_write_marker(cinfo, kSpecialMarker0, kMarkerData,
                          sizeof(kMarkerData));
      jpegli_write_m_header(cinfo, kSpecialMarker1, sizeof(kMarkerData));
      for (size_t p = 0; p < sizeof(kMarkerData); ++p) {
        jpegli_write_m_byte(cinfo, kMarkerData[p]);
      }
    }
    for (int c = 0; c < cinfo->num_components; ++c) {
      jpeg_component_info* comp = &cinfo->comp_info[c];
      for (size_t by = 0; by < comp->height_in_blocks; ++by) {
        JBLOCKARRAY ba = (*cinfo->mem->access_virt_barray)(
            comptr, coef_arrays[c], by, 1, true);
        size_t stride = comp->width_in_blocks * sizeof(JBLOCK);
        size_t offset = by * comp->width_in_blocks * DCTSIZE2;
        memcpy(ba[0], &input.coeffs[c][offset], stride);
      }
    }
  } else {
    size_t stride = cinfo->image_width * cinfo->input_components *
                    jpegli_bytes_per_sample(input.data_type);
    std::vector<uint8_t> row_bytes(stride);
    for (size_t y = 0; y < cinfo->image_height; ++y) {
      memcpy(&row_bytes[0], &input.pixels[y * stride], stride);
      JSAMPROW row[] = {row_bytes.data()};
      jpegli_write_scanlines(cinfo, row, 1);
    }
  }
  jpegli_finish_compress(cinfo);
}

bool EncodeWithJpegli(const TestImage& input, const CompressParams& jparams,
                      std::vector<uint8_t>* compressed) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    EncodeWithJpegli(input, jparams, &cinfo);
    return true;
  };
  bool success = try_catch_block();
  jpegli_destroy_compress(&cinfo);
  if (success) {
    compressed->resize(buffer_size);
    std::copy_n(buffer, buffer_size, compressed->data());
  }
  if (buffer) std::free(buffer);
  return success;
}

int NumTestScanScripts() { return kNumTestScripts; }

void DumpImage(const TestImage& image, const std::string fn) {
  JXL_CHECK(image.components == 1 || image.components == 3);
  size_t bytes_per_sample = jpegli_bytes_per_sample(image.data_type);
  uint32_t maxval = (1u << (8 * bytes_per_sample)) - 1;
  char type = image.components == 1 ? '5' : '6';
  std::ofstream out(fn.c_str(), std::ofstream::binary);
  out << "P" << type << std::endl
      << image.xsize << " " << image.ysize << std::endl
      << maxval << std::endl;
  out.write(reinterpret_cast<const char*>(image.pixels.data()),
            image.pixels.size());
  out.close();
}

double DistanceRms(const TestImage& input, const TestImage& output,
                   size_t start_line, size_t num_lines, double* max_diff) {
  size_t stride = input.xsize * input.components;
  size_t start_offset = start_line * stride;
  auto get_sample = [&](const TestImage& im, const std::vector<uint8_t>& data,
                        size_t idx) -> double {
    size_t bytes_per_sample = jpegli_bytes_per_sample(im.data_type);
    bool is_little_endian =
        (im.endianness == JPEGLI_LITTLE_ENDIAN ||
         (im.endianness == JPEGLI_NATIVE_ENDIAN && IsLittleEndian()));
    size_t offset = start_offset + idx * bytes_per_sample;
    JXL_CHECK(offset < data.size());
    const uint8_t* p = &data[offset];
    if (im.data_type == JPEGLI_TYPE_UINT8) {
      static const double mul8 = 1.0 / 255.0;
      return p[0] * mul8;
    } else if (im.data_type == JPEGLI_TYPE_UINT16) {
      static const double mul16 = 1.0 / 65535.0;
      return (is_little_endian ? LoadLE16(p) : LoadBE16(p)) * mul16;
    } else if (im.data_type == JPEGLI_TYPE_FLOAT) {
      return (is_little_endian ? LoadLEFloat(p) : LoadBEFloat(p));
    }
    return 0.0;
  };
  double diff2 = 0.0;
  size_t num_samples = 0;
  if (max_diff) *max_diff = 0.0;
  if (!input.pixels.empty() && !output.pixels.empty()) {
    num_samples = num_lines * stride;
    for (size_t i = 0; i < num_samples; ++i) {
      double sample_orig = get_sample(input, input.pixels, i);
      double sample_output = get_sample(output, output.pixels, i);
      double diff = sample_orig - sample_output;
      if (max_diff) *max_diff = std::max(*max_diff, 255.0 * std::abs(diff));
      diff2 += diff * diff;
    }
  } else {
    JXL_CHECK(!input.raw_data.empty());
    JXL_CHECK(!output.raw_data.empty());
    for (size_t c = 0; c < input.raw_data.size(); ++c) {
      JXL_CHECK(c < output.raw_data.size());
      num_samples += input.raw_data[c].size();
      for (size_t i = 0; i < input.raw_data[c].size(); ++i) {
        double sample_orig = get_sample(input, input.raw_data[c], i);
        double sample_output = get_sample(output, output.raw_data[c], i);
        double diff = sample_orig - sample_output;
        if (max_diff) *max_diff = std::max(*max_diff, 255.0 * std::abs(diff));
        diff2 += diff * diff;
      }
    }
  }
  return std::sqrt(diff2 / num_samples) * 255.0;
}

double DistanceRms(const TestImage& input, const TestImage& output,
                   double* max_diff) {
  return DistanceRms(input, output, 0, output.ysize, max_diff);
}

void VerifyOutputImage(const TestImage& input, const TestImage& output,
                       size_t start_line, size_t num_lines, double max_rms,
                       double max_diff) {
  double max_d;
  double rms = DistanceRms(input, output, start_line, num_lines, &max_d);
  printf("rms: %f, max_rms: %f, max_d: %f,  max_diff: %f\n", rms, max_rms,
         max_d, max_diff);
  JXL_CHECK(rms <= max_rms);
  JXL_CHECK(max_d <= max_diff);
}

void VerifyOutputImage(const TestImage& input, const TestImage& output,
                       double max_rms, double max_diff) {
  JXL_CHECK(output.xsize == input.xsize);
  JXL_CHECK(output.ysize == input.ysize);
  JXL_CHECK(output.components == input.components);
  JXL_CHECK(output.color_space == input.color_space);
  if (!input.coeffs.empty()) {
    JXL_CHECK(input.coeffs.size() == input.components);
    JXL_CHECK(output.coeffs.size() == input.components);
    for (size_t c = 0; c < input.components; ++c) {
      JXL_CHECK(output.coeffs[c].size() == input.coeffs[c].size());
      JXL_CHECK(0 == memcmp(input.coeffs[c].data(), output.coeffs[c].data(),
                            input.coeffs[c].size()));
    }
  } else {
    VerifyOutputImage(input, output, 0, output.ysize, max_rms, max_diff);
  }
}

}  // namespace jpegli
