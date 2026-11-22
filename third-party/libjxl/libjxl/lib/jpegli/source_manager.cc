// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/decode.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/memory_manager.h"

namespace jpegli {

void init_mem_source(j_decompress_ptr cinfo) {}
void init_stdio_source(j_decompress_ptr cinfo) {}

void skip_input_data(j_decompress_ptr cinfo, long num_bytes) {
  if (num_bytes <= 0) return;
  while (num_bytes > static_cast<long>(cinfo->src->bytes_in_buffer)) {
    num_bytes -= cinfo->src->bytes_in_buffer;
    (*cinfo->src->fill_input_buffer)(cinfo);
  }
  cinfo->src->next_input_byte += num_bytes;
  cinfo->src->bytes_in_buffer -= num_bytes;
}

void term_source(j_decompress_ptr cinfo) {}

boolean EmitFakeEoiMarker(j_decompress_ptr cinfo) {
  static constexpr uint8_t kFakeEoiMarker[2] = {0xff, 0xd9};
  cinfo->src->next_input_byte = kFakeEoiMarker;
  cinfo->src->bytes_in_buffer = 2;
  return TRUE;
}

constexpr size_t kStdioBufferSize = 64 << 10;

struct StdioSourceManager {
  jpeg_source_mgr pub;
  FILE* f;
  uint8_t* buffer;

  static boolean fill_input_buffer(j_decompress_ptr cinfo) {
    auto src = reinterpret_cast<StdioSourceManager*>(cinfo->src);
    size_t num_bytes_read = fread(src->buffer, 1, kStdioBufferSize, src->f);
    if (num_bytes_read == 0) {
      return EmitFakeEoiMarker(cinfo);
    }
    src->pub.next_input_byte = src->buffer;
    src->pub.bytes_in_buffer = num_bytes_read;
    return TRUE;
  }
};

}  // namespace jpegli

void jpegli_mem_src(j_decompress_ptr cinfo, const unsigned char* inbuffer,
                    unsigned long insize) {
  if (cinfo->src && cinfo->src->init_source != jpegli::init_mem_source) {
    JPEGLI_ERROR("jpegli_mem_src: a different source manager was already set");
  }
  if (!cinfo->src) {
    cinfo->src = jpegli::Allocate<jpeg_source_mgr>(cinfo, 1);
  }
  cinfo->src->next_input_byte = inbuffer;
  cinfo->src->bytes_in_buffer = insize;
  cinfo->src->init_source = jpegli::init_mem_source;
  cinfo->src->fill_input_buffer = jpegli::EmitFakeEoiMarker;
  cinfo->src->skip_input_data = jpegli::skip_input_data;
  cinfo->src->resync_to_restart = jpegli_resync_to_restart;
  cinfo->src->term_source = jpegli::term_source;
}

void jpegli_stdio_src(j_decompress_ptr cinfo, FILE* infile) {
  if (cinfo->src && cinfo->src->init_source != jpegli::init_stdio_source) {
    JPEGLI_ERROR("jpeg_stdio_src: a different source manager was already set");
  }
  if (!cinfo->src) {
    cinfo->src = reinterpret_cast<jpeg_source_mgr*>(
        jpegli::Allocate<jpegli::StdioSourceManager>(cinfo, 1));
  }
  auto src = reinterpret_cast<jpegli::StdioSourceManager*>(cinfo->src);
  src->f = infile;
  src->buffer = jpegli::Allocate<uint8_t>(cinfo, jpegli::kStdioBufferSize);
  src->pub.next_input_byte = src->buffer;
  src->pub.bytes_in_buffer = 0;
  src->pub.init_source = jpegli::init_stdio_source;
  src->pub.fill_input_buffer = jpegli::StdioSourceManager::fill_input_buffer;
  src->pub.skip_input_data = jpegli::skip_input_data;
  src->pub.resync_to_restart = jpegli_resync_to_restart;
  src->pub.term_source = jpegli::term_source;
}
