// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/decode.h"
#include "lib/jpegli/encode.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/test_utils.h"
#include "lib/jpegli/testing.h"
#include "lib/jxl/sanitizers.h"

namespace jpegli {
namespace {

TEST(EncoderErrorHandlingTest, MinimalSuccess) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  {
    jpeg_compress_struct cinfo;
    const auto try_catch_block = [&]() -> bool {
      ERROR_HANDLER_SETUP(jpegli);
      jpegli_create_compress(&cinfo);
      jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
      cinfo.image_width = 1;
      cinfo.image_height = 1;
      cinfo.input_components = 1;
      jpegli_set_defaults(&cinfo);
      jpegli_start_compress(&cinfo, TRUE);
      JSAMPLE image[1] = {0};
      JSAMPROW row[] = {image};
      jpegli_write_scanlines(&cinfo, row, 1);
      jpegli_finish_compress(&cinfo);
      return true;
    };
    EXPECT_TRUE(try_catch_block());
    jpegli_destroy_compress(&cinfo);
  }
  TestImage output;
  DecodeWithLibjpeg(CompressParams(), DecompressParams(), nullptr, 0, buffer,
                    buffer_size, &output);
  EXPECT_EQ(1, output.xsize);
  EXPECT_EQ(1, output.ysize);
  EXPECT_EQ(1, output.components);
  EXPECT_EQ(0, output.pixels[0]);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NoDestination) {
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
}

TEST(EncoderErrorHandlingTest, NoImageDimensions) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, ImageTooBig) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 100000;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NoInputComponents) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, TooManyInputComponents) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1000;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NoSetDefaults) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[1] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NoStartCompress) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    JSAMPLE image[1] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NoWriteScanlines) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NoWriteAllScanlines) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 2;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[1] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidQuantValue) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    cinfo.quant_tbl_ptrs[0] = jpegli_alloc_quant_table((j_common_ptr)&cinfo);
    for (size_t k = 0; k < DCTSIZE2; ++k) {
      cinfo.quant_tbl_ptrs[0]->quantval[k] = 0;
    }
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[1] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidQuantTableIndex) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].quant_tbl_no = 3;
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[1] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NumberOfComponentsMismatch1) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    cinfo.num_components = 100;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NumberOfComponentsMismatch2) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    cinfo.num_components = 2;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NumberOfComponentsMismatch3) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    cinfo.num_components = 2;
    cinfo.comp_info[1].h_samp_factor = cinfo.comp_info[1].v_samp_factor = 1;
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[1] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NumberOfComponentsMismatch4) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    cinfo.in_color_space = JCS_RGB;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[1] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NumberOfComponentsMismatch5) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_GRAYSCALE;
    jpegli_set_defaults(&cinfo);
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[3] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NumberOfComponentsMismatch6) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;
    jpegli_set_defaults(&cinfo);
    cinfo.num_components = 2;
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[3] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidColorTransform) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_YCbCr;
    jpegli_set_defaults(&cinfo);
    cinfo.jpeg_color_space = JCS_RGB;
    jpegli_start_compress(&cinfo, TRUE);
    JSAMPLE image[3] = {0};
    JSAMPROW row[] = {image};
    jpegli_write_scanlines(&cinfo, row, 1);
    jpegli_finish_compress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, DuplicateComponentIds) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].component_id = 0;
    cinfo.comp_info[1].component_id = 0;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidComponentIndex) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].component_index = 17;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, ArithmeticCoding) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    jpegli_set_defaults(&cinfo);
    cinfo.arith_code = TRUE;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, CCIR601Sampling) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    jpegli_set_defaults(&cinfo);
    cinfo.CCIR601_sampling = TRUE;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript1) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {{1, {0}, 0, 63, 0, 0}};  //
    cinfo.scan_info = kScript;
    cinfo.num_scans = 0;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript2) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {{2, {0, 1}, 0, 63, 0, 0}};  //
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript3) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {{5, {0}, 0, 63, 0, 0}};  //
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript4) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 2;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {{2, {0, 0}, 0, 63, 0, 0}};  //
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript5) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 2;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {{2, {1, 0}, 0, 63, 0, 0}};  //
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript6) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {{1, {0}, 0, 64, 0, 0}};  //
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript7) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {{1, {0}, 2, 1, 0, 0}};  //
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript8) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 2;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {
        {1, {0}, 0, 63, 0, 0}, {1, {1}, 0, 0, 0, 0}, {1, {1}, 1, 63, 0, 0}  //
    };
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript9) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {
        {1, {0}, 0, 1, 0, 0}, {1, {0}, 2, 63, 0, 0},  //
    };
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript10) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 2;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {
        {2, {0, 1}, 0, 0, 0, 0}, {2, {0, 1}, 1, 63, 0, 0}  //
    };
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript11) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {
        {1, {0}, 1, 63, 0, 0}, {1, {0}, 0, 0, 0, 0}  //
    };
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript12) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {
        {1, {0}, 0, 0, 10, 1}, {1, {0}, 0, 0, 1, 0}, {1, {0}, 1, 63, 0, 0}  //
    };
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, InvalidScanScript13) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    static constexpr jpeg_scan_info kScript[] = {
        {1, {0}, 0, 0, 0, 2},
        {1, {0}, 0, 0, 1, 0},
        {1, {0}, 0, 0, 2, 1},  //
        {1, {0}, 1, 63, 0, 0}  //
    };
    cinfo.scan_info = kScript;
    cinfo.num_scans = ARRAY_SIZE(kScript);
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, MCUSizeTooBig) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    jpegli_set_defaults(&cinfo);
    jpegli_set_progressive_level(&cinfo, 0);
    cinfo.comp_info[0].h_samp_factor = 3;
    cinfo.comp_info[0].v_samp_factor = 3;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, RestartIntervalTooBig) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 1;
    jpegli_set_defaults(&cinfo);
    cinfo.restart_interval = 1000000;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, SamplingFactorTooBig) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].h_samp_factor = 5;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncoderErrorHandlingTest, NonIntegralSamplingRatio) {
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    cinfo.image_width = 1;
    cinfo.image_height = 1;
    cinfo.input_components = 3;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].h_samp_factor = 3;
    cinfo.comp_info[1].h_samp_factor = 2;
    jpegli_start_compress(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

constexpr const char* kAddOnTable[] = {"First message",
                                       "Second message with int param %d",
                                       "Third message with string param %s"};

TEST(EncoderErrorHandlingTest, AddOnTableNoParam) {
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    cinfo.err->addon_message_table = kAddOnTable;
    cinfo.err->first_addon_message = 10000;
    cinfo.err->last_addon_message = 10002;
    cinfo.err->msg_code = 10000;
    (*cinfo.err->error_exit)(reinterpret_cast<j_common_ptr>(&cinfo));
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
}

TEST(EncoderErrorHandlingTest, AddOnTableIntParam) {
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    cinfo.err->addon_message_table = kAddOnTable;
    cinfo.err->first_addon_message = 10000;
    cinfo.err->last_addon_message = 10002;
    cinfo.err->msg_code = 10001;
    cinfo.err->msg_parm.i[0] = 17;
    (*cinfo.err->error_exit)(reinterpret_cast<j_common_ptr>(&cinfo));
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
}

TEST(EncoderErrorHandlingTest, AddOnTableNoStringParam) {
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    cinfo.err->addon_message_table = kAddOnTable;
    cinfo.err->first_addon_message = 10000;
    cinfo.err->last_addon_message = 10002;
    cinfo.err->msg_code = 10002;
    memcpy(cinfo.err->msg_parm.s, "MESSAGE PARAM", 14);
    (*cinfo.err->error_exit)(reinterpret_cast<j_common_ptr>(&cinfo));
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
}

static const uint8_t kCompressed0[] = {
    // SOI
    0xff, 0xd8,  //
    // DQT
    0xff, 0xdb, 0x00, 0x43, 0x00, 0x03, 0x02, 0x02, 0x03, 0x02,  //
    0x02, 0x03, 0x03, 0x03, 0x03, 0x04, 0x03, 0x03, 0x04, 0x05,  //
    0x08, 0x05, 0x05, 0x04, 0x04, 0x05, 0x0a, 0x07, 0x07, 0x06,  //
    0x08, 0x0c, 0x0a, 0x0c, 0x0c, 0x0b, 0x0a, 0x0b, 0x0b, 0x0d,  //
    0x0e, 0x12, 0x10, 0x0d, 0x0e, 0x11, 0x0e, 0x0b, 0x0b, 0x10,  //
    0x16, 0x10, 0x11, 0x13, 0x14, 0x15, 0x15, 0x15, 0x0c, 0x0f,  //
    0x17, 0x18, 0x16, 0x14, 0x18, 0x12, 0x14, 0x15, 0x14,        //
    // SOF
    0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01,  //
    0x01, 0x11, 0x00,                                            //
    // DHT
    0xff, 0xc4, 0x00, 0xd2, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01,  //
    0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  //
    0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,  //
    0x09, 0x0a, 0x0b, 0x10, 0x00, 0x02, 0x01, 0x03, 0x03, 0x02,  //
    0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7d,  //
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31,  //
    0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32,  //
    0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52,  //
    0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16,  //
    0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a,  //
    0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45,  //
    0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57,  //
    0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,  //
    0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83,  //
    0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94,  //
    0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5,  //
    0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,  //
    0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7,  //
    0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8,  //
    0xd9, 0xda, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8,  //
    0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8,  //
    0xf9, 0xfa,                                                  //
    // SOS
    0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00,  //
    // entropy coded data
    0xfc, 0xaa, 0xaf,  //
    // EOI
    0xff, 0xd9,  //
};
static const size_t kLen0 = sizeof(kCompressed0);

static const size_t kDQTOffset = 2;
static const size_t kSOFOffset = 71;
static const size_t kDHTOffset = 84;
static const size_t kSOSOffset = 296;

TEST(DecoderErrorHandlingTest, MinimalSuccess) {
  JXL_CHECK(kCompressed0[kDQTOffset] == 0xff);
  JXL_CHECK(kCompressed0[kSOFOffset] == 0xff);
  JXL_CHECK(kCompressed0[kDHTOffset] == 0xff);
  JXL_CHECK(kCompressed0[kSOSOffset] == 0xff);
  jpeg_decompress_struct cinfo = {};
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_mem_src(&cinfo, kCompressed0, kLen0);
    jpegli_read_header(&cinfo, TRUE);
    EXPECT_EQ(1, cinfo.image_width);
    EXPECT_EQ(1, cinfo.image_height);
    jpegli_start_decompress(&cinfo);
    JSAMPLE image[1];
    JSAMPROW row[] = {image};
    jpegli_read_scanlines(&cinfo, row, 1);
    EXPECT_EQ(0, image[0]);
    jpegli_finish_decompress(&cinfo);
    return true;
  };
  EXPECT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);
}

TEST(DecoderErrorHandlingTest, NoSource) {
  jpeg_decompress_struct cinfo = {};
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_read_header(&cinfo, TRUE);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);
}

TEST(DecoderErrorHandlingTest, NoReadHeader) {
  jpeg_decompress_struct cinfo = {};
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_mem_src(&cinfo, kCompressed0, kLen0);
    jpegli_start_decompress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);
}

TEST(DecoderErrorHandlingTest, NoStartDecompress) {
  jpeg_decompress_struct cinfo = {};
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_mem_src(&cinfo, kCompressed0, kLen0);
    jpegli_read_header(&cinfo, TRUE);
    EXPECT_EQ(1, cinfo.image_width);
    EXPECT_EQ(1, cinfo.image_height);
    JSAMPLE image[1];
    JSAMPROW row[] = {image};
    jpegli_read_scanlines(&cinfo, row, 1);
    EXPECT_EQ(0, image[0]);
    jpegli_finish_decompress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);
}

TEST(DecoderErrorHandlingTest, NoReadScanlines) {
  jpeg_decompress_struct cinfo = {};
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_mem_src(&cinfo, kCompressed0, kLen0);
    jpegli_read_header(&cinfo, TRUE);
    EXPECT_EQ(1, cinfo.image_width);
    EXPECT_EQ(1, cinfo.image_height);
    jpegli_start_decompress(&cinfo);
    jpegli_finish_decompress(&cinfo);
    return true;
  };
  EXPECT_FALSE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);
}

static const size_t kMaxImageWidth = 0xffff;
JSAMPLE kOutputBuffer[MAX_COMPONENTS * kMaxImageWidth];

bool ParseCompressed(const std::vector<uint8_t>& compressed) {
  jpeg_decompress_struct cinfo = {};
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_mem_src(&cinfo, compressed.data(), compressed.size());
    jpegli_read_header(&cinfo, TRUE);
    jpegli_start_decompress(&cinfo);
    for (JDIMENSION i = 0; i < cinfo.output_height; ++i) {
      JSAMPROW row[] = {kOutputBuffer};
      jpegli_read_scanlines(&cinfo, row, 1);
    }
    jpegli_finish_decompress(&cinfo);
    return true;
  };
  bool retval = try_catch_block();
  jpegli_destroy_decompress(&cinfo);
  return retval;
}

TEST(DecoderErrorHandlingTest, NoSOI) {
  for (int pos : {0, 1}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[pos] = 0;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
}

TEST(DecoderErrorHandlingTest, InvalidDQT) {
  // Bad marker length
  for (int diff : {-2, -1, 1, 2}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kDQTOffset + 3] += diff;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // inavlid table index / precision
  for (int val : {0x20, 0x05}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kDQTOffset + 4] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // zero quant value
  for (int k : {0, 1, 17, 63}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kDQTOffset + 5 + k] = 0;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
}

TEST(DecoderErrorHandlingTest, InvalidSOF) {
  // Bad marker length
  for (int diff : {-2, -1, 1, 2}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOFOffset + 3] += diff;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // zero width, height or num_components
  for (int pos : {6, 8, 9}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOFOffset + pos] = 0;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // invalid data precision
  for (int val : {0, 1, 127}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOFOffset + 4] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // too many num_components
  for (int val : {5, 255}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOFOffset + 9] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // invalid sampling factors
  for (int val : {0x00, 0x01, 0x10, 0x15, 0x51}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOFOffset + 11] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // invalid quant table index
  for (int val : {5, 17}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOFOffset + 12] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
}

TEST(DecoderErrorHandlingTest, InvalidDHT) {
  // Bad marker length
  for (int diff : {-2, -1, 1, 2}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kDHTOffset + 3] += diff;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kDHTOffset + 2] += 17;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // inavlid table slot_id
  for (int val : {0x05, 0x15, 0x20}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kDHTOffset + 4] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
}

TEST(DecoderErrorHandlingTest, InvalidSOS) {
  // Invalid comps_in_scan
  for (int val : {2, 5, 17}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOSOffset + 4] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // invalid Huffman table indexes
  for (int val : {0x05, 0x50, 0x15, 0x51}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOSOffset + 6] = val;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
  // invalid Ss/Se
  for (int pos : {7, 8}) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    compressed[kSOSOffset + pos] = 64;
    EXPECT_FALSE(ParseCompressed(compressed));
  }
}

TEST(DecoderErrorHandlingTest, MutateSingleBytes) {
  for (size_t pos = 0; pos < kLen0; ++pos) {
    std::vector<uint8_t> compressed(kCompressed0, kCompressed0 + kLen0);
    for (int val : {0x00, 0x0f, 0xf0, 0xff}) {
      compressed[pos] = val;
      ParseCompressed(compressed);
    }
  }
}

}  // namespace
}  // namespace jpegli
