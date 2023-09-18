// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <hwy/targets.h>
#include <vector>

#include "lib/jpegli/decode.h"

namespace {

// Externally visible value to ensure pixels are used in the fuzzer.
int external_code = 0;

template <typename It>
void Consume(const It& begin, const It& end) {
  for (auto it = begin; it < end; ++it) {
    if (*it == 0) {
      external_code ^= ~0;
    } else {
      external_code ^= *it;
    }
  }
}

// Options for the fuzzing
struct FuzzSpec {
  size_t chunk_size;
  JpegliDataType output_type;
  JpegliEndianness output_endianness;
  int crop_output;
};

static constexpr uint8_t kFakeEoiMarker[2] = {0xff, 0xd9};
static constexpr size_t kNumSourceBuffers = 4;

class SourceManager {
 public:
  SourceManager(const uint8_t* data, size_t len, size_t max_chunk_size)
      : data_(data), len_(len), max_chunk_size_(max_chunk_size) {
    pub_.skip_input_data = skip_input_data;
    pub_.resync_to_restart = jpegli_resync_to_restart;
    pub_.term_source = term_source;
    pub_.init_source = init_source;
    pub_.fill_input_buffer = fill_input_buffer;
    if (max_chunk_size_ == 0) max_chunk_size_ = len;
    buffers_.resize(kNumSourceBuffers, std::vector<uint8_t>(max_chunk_size_));
    Reset();
  }

  void Reset() {
    pub_.next_input_byte = nullptr;
    pub_.bytes_in_buffer = 0;
    pos_ = 0;
    chunk_idx_ = 0;
  }

 private:
  jpeg_source_mgr pub_;
  const uint8_t* data_;
  size_t len_;
  size_t chunk_idx_;
  size_t pos_;
  size_t max_chunk_size_;
  std::vector<std::vector<uint8_t>> buffers_;

  static void init_source(j_decompress_ptr cinfo) {}

  static boolean fill_input_buffer(j_decompress_ptr cinfo) {
    auto src = reinterpret_cast<SourceManager*>(cinfo->src);
    if (src->pos_ < src->len_) {
      size_t remaining = src->len_ - src->pos_;
      size_t chunk_size = std::min(remaining, src->max_chunk_size_);
      size_t next_idx = ++src->chunk_idx_ % kNumSourceBuffers;
      // Larger number of chunks causes fuzzer timuout.
      if (src->chunk_idx_ >= (1u << 15)) {
        chunk_size = remaining;
        next_idx = src->buffers_.size();
        src->buffers_.emplace_back(chunk_size);
      }
      uint8_t* next_buffer = src->buffers_[next_idx].data();
      memcpy(next_buffer, src->data_ + src->pos_, chunk_size);
      src->pub_.next_input_byte = next_buffer;
      src->pub_.bytes_in_buffer = chunk_size;
    } else {
      src->pub_.next_input_byte = kFakeEoiMarker;
      src->pub_.bytes_in_buffer = 2;
      src->len_ += 2;
    }
    src->pos_ += src->pub_.bytes_in_buffer;
    return TRUE;
  }

  static void skip_input_data(j_decompress_ptr cinfo, long num_bytes) {
    auto src = reinterpret_cast<SourceManager*>(cinfo->src);
    if (num_bytes <= 0) {
      return;
    }
    if (src->pub_.bytes_in_buffer >= static_cast<size_t>(num_bytes)) {
      src->pub_.bytes_in_buffer -= num_bytes;
      src->pub_.next_input_byte += num_bytes;
    } else {
      src->pos_ += num_bytes - src->pub_.bytes_in_buffer;
      src->pub_.bytes_in_buffer = 0;
    }
  }

  static void term_source(j_decompress_ptr cinfo) {}
};

bool DecodeJpeg(const uint8_t* data, size_t size, size_t max_pixels,
                const FuzzSpec& spec, std::vector<uint8_t>* pixels,
                size_t* xsize, size_t* ysize) {
  SourceManager src(data, size, spec.chunk_size);
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    jpeg_error_mgr jerr;
    jmp_buf env;
    cinfo.err = jpegli_std_error(&jerr);
    if (setjmp(env)) {
      return false;
    }
    cinfo.client_data = reinterpret_cast<void*>(&env);
    cinfo.err->error_exit = [](j_common_ptr cinfo) {
      jmp_buf* env = reinterpret_cast<jmp_buf*>(cinfo->client_data);
      jpegli_destroy(cinfo);
      longjmp(*env, 1);
    };
    cinfo.err->emit_message = [](j_common_ptr cinfo, int msg_level) {};
    jpegli_create_decompress(&cinfo);
    cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);
    jpegli_read_header(&cinfo, TRUE);
    *xsize = cinfo.image_width;
    *ysize = cinfo.image_height;
    size_t num_pixels = *xsize * *ysize;
    if (num_pixels > max_pixels) return false;
    jpegli_set_output_format(&cinfo, spec.output_type, spec.output_endianness);
    jpegli_start_decompress(&cinfo);
    if (spec.crop_output) {
      JDIMENSION xoffset = cinfo.output_width / 3;
      JDIMENSION xsize_cropped = cinfo.output_width / 3;
      jpegli_crop_scanline(&cinfo, &xoffset, &xsize_cropped);
    }

    size_t bytes_per_sample = jpegli_bytes_per_sample(spec.output_type);
    size_t stride =
        bytes_per_sample * cinfo.output_components * cinfo.output_width;
    size_t buffer_size = *ysize * stride;
    pixels->resize(buffer_size);
    for (size_t y = 0; y < *ysize; ++y) {
      JSAMPROW rows[] = {pixels->data() + y * stride};
      jpegli_read_scanlines(&cinfo, rows, 1);
    }
    Consume(pixels->cbegin(), pixels->cend());
    jpegli_finish_decompress(&cinfo);
    return true;
  };
  bool success = try_catch_block();
  jpegli_destroy_decompress(&cinfo);
  return success;
}

int TestOneInput(const uint8_t* data, size_t size) {
  if (size < 4) return 0;
  uint32_t flags = 0;
  size_t used_flag_bits = 0;
  memcpy(&flags, data + size - 4, 4);
  size -= 4;

  const auto getFlag = [&flags, &used_flag_bits](size_t max_value) {
    size_t limit = 1;
    while (limit <= max_value) {
      limit <<= 1;
      used_flag_bits++;
      if (used_flag_bits > 32) abort();
    }
    uint32_t result = flags % limit;
    flags /= limit;
    return result % (max_value + 1);
  };

  FuzzSpec spec;
  spec.output_type = static_cast<JpegliDataType>(getFlag(JPEGLI_TYPE_UINT16));
  spec.output_endianness =
      static_cast<JpegliEndianness>(getFlag(JPEGLI_BIG_ENDIAN));
  uint32_t chunks = getFlag(15);
  spec.chunk_size = chunks ? 1u << (chunks - 1) : 0;
  spec.crop_output = getFlag(1);

  std::vector<uint8_t> pixels;
  size_t xsize, ysize;
  size_t max_pixels = 1 << 21;

  const auto targets = hwy::SupportedAndGeneratedTargets();
  hwy::SetSupportedTargetsForTest(targets[getFlag(targets.size() - 1)]);
  DecodeJpeg(data, size, max_pixels, spec, &pixels, &xsize, &ysize);
  hwy::SetSupportedTargetsForTest(0);

  return 0;
}

}  // namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  return TestOneInput(data, size);
}
