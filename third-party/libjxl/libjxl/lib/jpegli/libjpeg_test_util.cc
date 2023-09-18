// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/libjpeg_test_util.h"

/* clang-format off */
#include <stdio.h>
#include <jpeglib.h>
#include <setjmp.h>
/* clang-format on */

#include "lib/jxl/sanitizers.h"

namespace jpegli {

namespace {

#define JPEG_API_FN(name) jpeg_##name
#include "lib/jpegli/test_utils-inl.h"
#undef JPEG_API_FN

void ReadOutputPass(j_decompress_ptr cinfo, const DecompressParams& dparams,
                    TestImage* output) {
  JDIMENSION xoffset = 0;
  JDIMENSION yoffset = 0;
  JDIMENSION xsize_cropped = cinfo->output_width;
  JDIMENSION ysize_cropped = cinfo->output_height;
  if (dparams.crop_output) {
    xoffset = xsize_cropped = cinfo->output_width / 3;
    yoffset = ysize_cropped = cinfo->output_height / 3;
    jpeg_crop_scanline(cinfo, &xoffset, &xsize_cropped);
    JXL_CHECK(xsize_cropped == cinfo->output_width);
  }
  output->xsize = xsize_cropped;
  output->ysize = ysize_cropped;
  output->components = cinfo->out_color_components;
  if (cinfo->quantize_colors) {
    jxl::msan::UnpoisonMemory(cinfo->colormap, cinfo->out_color_components *
                                                   sizeof(cinfo->colormap[0]));
    for (int c = 0; c < cinfo->out_color_components; ++c) {
      jxl::msan::UnpoisonMemory(
          cinfo->colormap[c],
          cinfo->actual_number_of_colors * sizeof(cinfo->colormap[c][0]));
    }
  }
  if (!cinfo->raw_data_out) {
    size_t stride = output->xsize * output->components;
    output->pixels.resize(output->ysize * stride);
    output->color_space = cinfo->out_color_space;
    if (yoffset > 0) {
      jpeg_skip_scanlines(cinfo, yoffset);
    }
    for (size_t y = 0; y < output->ysize; ++y) {
      JSAMPROW rows[] = {
          reinterpret_cast<JSAMPLE*>(&output->pixels[y * stride])};
      JXL_CHECK(1 == jpeg_read_scanlines(cinfo, rows, 1));
      jxl::msan::UnpoisonMemory(
          rows[0], sizeof(JSAMPLE) * cinfo->output_components * output->xsize);
      if (cinfo->quantize_colors) {
        UnmapColors(rows[0], cinfo->output_width, cinfo->out_color_components,
                    cinfo->colormap, cinfo->actual_number_of_colors);
      }
    }
    if (cinfo->output_scanline < cinfo->output_height) {
      jpeg_skip_scanlines(cinfo, cinfo->output_height - cinfo->output_scanline);
    }
  } else {
    output->color_space = cinfo->jpeg_color_space;
    for (int c = 0; c < cinfo->num_components; ++c) {
      size_t xsize = cinfo->comp_info[c].width_in_blocks * DCTSIZE;
      size_t ysize = cinfo->comp_info[c].height_in_blocks * DCTSIZE;
      std::vector<uint8_t> plane(ysize * xsize);
      output->raw_data.emplace_back(std::move(plane));
    }
    while (cinfo->output_scanline < cinfo->output_height) {
      size_t iMCU_height = cinfo->max_v_samp_factor * DCTSIZE;
      JXL_CHECK(cinfo->output_scanline == cinfo->output_iMCU_row * iMCU_height);
      std::vector<std::vector<JSAMPROW>> rowdata(cinfo->num_components);
      std::vector<JSAMPARRAY> data(cinfo->num_components);
      for (int c = 0; c < cinfo->num_components; ++c) {
        size_t xsize = cinfo->comp_info[c].width_in_blocks * DCTSIZE;
        size_t ysize = cinfo->comp_info[c].height_in_blocks * DCTSIZE;
        size_t num_lines = cinfo->comp_info[c].v_samp_factor * DCTSIZE;
        rowdata[c].resize(num_lines);
        size_t y0 = cinfo->output_iMCU_row * num_lines;
        for (size_t i = 0; i < num_lines; ++i) {
          rowdata[c][i] =
              y0 + i < ysize ? &output->raw_data[c][(y0 + i) * xsize] : nullptr;
        }
        data[c] = &rowdata[c][0];
      }
      JXL_CHECK(iMCU_height ==
                jpeg_read_raw_data(cinfo, &data[0], iMCU_height));
    }
  }
  JXL_CHECK(cinfo->total_iMCU_rows ==
            DivCeil(cinfo->image_height, cinfo->max_v_samp_factor * DCTSIZE));
}

void DecodeWithLibjpeg(const CompressParams& jparams,
                       const DecompressParams& dparams, j_decompress_ptr cinfo,
                       TestImage* output) {
  if (jparams.add_marker) {
    jpeg_save_markers(cinfo, kSpecialMarker0, 0xffff);
    jpeg_save_markers(cinfo, kSpecialMarker1, 0xffff);
  }
  if (!jparams.icc.empty()) {
    jpeg_save_markers(cinfo, JPEG_APP0 + 2, 0xffff);
  }
  JXL_CHECK(JPEG_REACHED_SOS ==
            jpeg_read_header(cinfo, /*require_image=*/TRUE));
  if (!jparams.icc.empty()) {
    uint8_t* icc_data = nullptr;
    unsigned int icc_len;
    JXL_CHECK(jpeg_read_icc_profile(cinfo, &icc_data, &icc_len));
    JXL_CHECK(icc_data);
    jxl::msan::UnpoisonMemory(icc_data, icc_len);
    JXL_CHECK(0 == memcmp(jparams.icc.data(), icc_data, icc_len));
    free(icc_data);
  }
  SetDecompressParams(dparams, cinfo);
  VerifyHeader(jparams, cinfo);
  if (dparams.output_mode == COEFFICIENTS) {
    jvirt_barray_ptr* coef_arrays = jpeg_read_coefficients(cinfo);
    JXL_CHECK(coef_arrays != nullptr);
    CopyCoefficients(cinfo, coef_arrays, output);
  } else {
    JXL_CHECK(jpeg_start_decompress(cinfo));
    VerifyScanHeader(jparams, cinfo);
    ReadOutputPass(cinfo, dparams, output);
  }
  JXL_CHECK(jpeg_finish_decompress(cinfo));
}

}  // namespace

// Verifies that an image encoded with libjpegli can be decoded with libjpeg,
// and checks that the jpeg coding metadata matches jparams.
void DecodeAllScansWithLibjpeg(const CompressParams& jparams,
                               const DecompressParams& dparams,
                               const std::vector<uint8_t>& compressed,
                               std::vector<TestImage>* output_progression) {
  jpeg_decompress_struct cinfo = {};
  const auto try_catch_block = [&]() {
    jpeg_error_mgr jerr;
    jmp_buf env;
    cinfo.err = jpeg_std_error(&jerr);
    if (setjmp(env)) {
      return false;
    }
    cinfo.client_data = reinterpret_cast<void*>(&env);
    cinfo.err->error_exit = [](j_common_ptr cinfo) {
      (*cinfo->err->output_message)(cinfo);
      jmp_buf* env = reinterpret_cast<jmp_buf*>(cinfo->client_data);
      jpeg_destroy(cinfo);
      longjmp(*env, 1);
    };
    jpeg_create_decompress(&cinfo);
    jpeg_mem_src(&cinfo, compressed.data(), compressed.size());
    if (jparams.add_marker) {
      jpeg_save_markers(&cinfo, kSpecialMarker0, 0xffff);
      jpeg_save_markers(&cinfo, kSpecialMarker1, 0xffff);
    }
    JXL_CHECK(JPEG_REACHED_SOS ==
              jpeg_read_header(&cinfo, /*require_image=*/TRUE));
    cinfo.buffered_image = TRUE;
    SetDecompressParams(dparams, &cinfo);
    VerifyHeader(jparams, &cinfo);
    JXL_CHECK(jpeg_start_decompress(&cinfo));
    // start decompress should not read the whole input in buffered image mode
    JXL_CHECK(!jpeg_input_complete(&cinfo));
    JXL_CHECK(cinfo.output_scan_number == 0);
    int sos_marker_cnt = 1;  // read header reads the first SOS marker
    while (!jpeg_input_complete(&cinfo)) {
      JXL_CHECK(cinfo.input_scan_number == sos_marker_cnt);
      if (dparams.skip_scans && (cinfo.input_scan_number % 2) != 1) {
        int result = JPEG_SUSPENDED;
        while (result != JPEG_REACHED_SOS && result != JPEG_REACHED_EOI) {
          result = jpeg_consume_input(&cinfo);
        }
        if (result == JPEG_REACHED_SOS) ++sos_marker_cnt;
        continue;
      }
      SetScanDecompressParams(dparams, &cinfo, cinfo.input_scan_number);
      JXL_CHECK(jpeg_start_output(&cinfo, cinfo.input_scan_number));
      // start output sets output_scan_number, but does not change
      // input_scan_number
      JXL_CHECK(cinfo.output_scan_number == cinfo.input_scan_number);
      JXL_CHECK(cinfo.input_scan_number == sos_marker_cnt);
      VerifyScanHeader(jparams, &cinfo);
      TestImage output;
      ReadOutputPass(&cinfo, dparams, &output);
      output_progression->emplace_back(std::move(output));
      // read scanlines/read raw data does not change input/output scan number
      if (!cinfo.progressive_mode) {
        JXL_CHECK(cinfo.input_scan_number == sos_marker_cnt);
        JXL_CHECK(cinfo.output_scan_number == cinfo.input_scan_number);
      }
      JXL_CHECK(jpeg_finish_output(&cinfo));
      ++sos_marker_cnt;  // finish output reads the next SOS marker or EOI
      if (dparams.output_mode == COEFFICIENTS) {
        jvirt_barray_ptr* coef_arrays = jpeg_read_coefficients(&cinfo);
        JXL_CHECK(coef_arrays != nullptr);
        CopyCoefficients(&cinfo, coef_arrays, &output_progression->back());
      }
    }
    JXL_CHECK(jpeg_finish_decompress(&cinfo));
    return true;
  };
  JXL_CHECK(try_catch_block());
  jpeg_destroy_decompress(&cinfo);
}

// Returns the number of bytes read from compressed.
size_t DecodeWithLibjpeg(const CompressParams& jparams,
                         const DecompressParams& dparams,
                         const uint8_t* table_stream, size_t table_stream_size,
                         const uint8_t* compressed, size_t len,
                         TestImage* output) {
  jpeg_decompress_struct cinfo = {};
  size_t bytes_read;
  const auto try_catch_block = [&]() {
    jpeg_error_mgr jerr;
    jmp_buf env;
    cinfo.err = jpeg_std_error(&jerr);
    if (setjmp(env)) {
      return false;
    }
    cinfo.client_data = reinterpret_cast<void*>(&env);
    cinfo.err->error_exit = [](j_common_ptr cinfo) {
      (*cinfo->err->output_message)(cinfo);
      jmp_buf* env = reinterpret_cast<jmp_buf*>(cinfo->client_data);
      jpeg_destroy(cinfo);
      longjmp(*env, 1);
    };
    jpeg_create_decompress(&cinfo);
    if (table_stream != nullptr) {
      jpeg_mem_src(&cinfo, table_stream, table_stream_size);
      jpeg_read_header(&cinfo, FALSE);
    }
    jpeg_mem_src(&cinfo, compressed, len);
    DecodeWithLibjpeg(jparams, dparams, &cinfo, output);
    bytes_read = len - cinfo.src->bytes_in_buffer;
    return true;
  };
  JXL_CHECK(try_catch_block());
  jpeg_destroy_decompress(&cinfo);
  return bytes_read;
}

void DecodeWithLibjpeg(const CompressParams& jparams,
                       const DecompressParams& dparams,
                       const std::vector<uint8_t>& compressed,
                       TestImage* output) {
  DecodeWithLibjpeg(jparams, dparams, nullptr, 0, compressed.data(),
                    compressed.size(), output);
}

}  // namespace jpegli
