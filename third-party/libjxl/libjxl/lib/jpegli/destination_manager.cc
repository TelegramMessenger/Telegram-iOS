// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <string.h>

#include "lib/jpegli/encode.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/memory_manager.h"

namespace jpegli {

constexpr size_t kDestBufferSize = 64 << 10;

struct StdioDestinationManager {
  jpeg_destination_mgr pub;
  FILE* f;
  uint8_t* buffer;

  static void init_destination(j_compress_ptr cinfo) {
    auto dest = reinterpret_cast<StdioDestinationManager*>(cinfo->dest);
    dest->pub.next_output_byte = dest->buffer;
    dest->pub.free_in_buffer = kDestBufferSize;
  }

  static boolean empty_output_buffer(j_compress_ptr cinfo) {
    auto dest = reinterpret_cast<StdioDestinationManager*>(cinfo->dest);
    if (fwrite(dest->buffer, 1, kDestBufferSize, dest->f) != kDestBufferSize) {
      JPEGLI_ERROR("Failed to write to output stream.");
    }
    dest->pub.next_output_byte = dest->buffer;
    dest->pub.free_in_buffer = kDestBufferSize;
    return TRUE;
  }

  static void term_destination(j_compress_ptr cinfo) {
    auto dest = reinterpret_cast<StdioDestinationManager*>(cinfo->dest);
    size_t bytes_left = kDestBufferSize - dest->pub.free_in_buffer;
    if (bytes_left &&
        fwrite(dest->buffer, 1, bytes_left, dest->f) != bytes_left) {
      JPEGLI_ERROR("Failed to write to output stream.");
    }
    fflush(dest->f);
    if (ferror(dest->f)) {
      JPEGLI_ERROR("Failed to write to output stream.");
    }
  }
};

struct MemoryDestinationManager {
  jpeg_destination_mgr pub;
  // Output buffer supplied by the application
  uint8_t** output;
  unsigned long* output_size;
  // Output buffer allocated by us.
  uint8_t* temp_buffer;
  // Current output buffer (either application supplied or allocated by us).
  uint8_t* current_buffer;
  size_t buffer_size;

  static void init_destination(j_compress_ptr cinfo) {}

  static boolean empty_output_buffer(j_compress_ptr cinfo) {
    auto dest = reinterpret_cast<MemoryDestinationManager*>(cinfo->dest);
    uint8_t* next_buffer =
        reinterpret_cast<uint8_t*>(malloc(dest->buffer_size * 2));
    memcpy(next_buffer, dest->current_buffer, dest->buffer_size);
    if (dest->temp_buffer != nullptr) {
      free(dest->temp_buffer);
    }
    dest->temp_buffer = next_buffer;
    dest->current_buffer = next_buffer;
    *dest->output = next_buffer;
    *dest->output_size = dest->buffer_size;
    dest->pub.next_output_byte = next_buffer + dest->buffer_size;
    dest->pub.free_in_buffer = dest->buffer_size;
    dest->buffer_size *= 2;
    return TRUE;
  }

  static void term_destination(j_compress_ptr cinfo) {
    auto dest = reinterpret_cast<MemoryDestinationManager*>(cinfo->dest);
    *dest->output_size = dest->buffer_size - dest->pub.free_in_buffer;
  }
};

}  // namespace jpegli

void jpegli_stdio_dest(j_compress_ptr cinfo, FILE* outfile) {
  if (outfile == nullptr) {
    JPEGLI_ERROR("jpegli_stdio_dest: Invalid destination.");
  }
  if (cinfo->dest && cinfo->dest->init_destination !=
                         jpegli::StdioDestinationManager::init_destination) {
    JPEGLI_ERROR("jpegli_stdio_dest: a different dest manager was already set");
  }
  if (!cinfo->dest) {
    cinfo->dest = reinterpret_cast<jpeg_destination_mgr*>(
        jpegli::Allocate<jpegli::StdioDestinationManager>(cinfo, 1));
  }
  auto dest = reinterpret_cast<jpegli::StdioDestinationManager*>(cinfo->dest);
  dest->f = outfile;
  dest->buffer = jpegli::Allocate<uint8_t>(cinfo, jpegli::kDestBufferSize);
  dest->pub.next_output_byte = dest->buffer;
  dest->pub.free_in_buffer = jpegli::kDestBufferSize;
  dest->pub.init_destination =
      jpegli::StdioDestinationManager::init_destination;
  dest->pub.empty_output_buffer =
      jpegli::StdioDestinationManager::empty_output_buffer;
  dest->pub.term_destination =
      jpegli::StdioDestinationManager::term_destination;
}

void jpegli_mem_dest(j_compress_ptr cinfo, unsigned char** outbuffer,
                     unsigned long* outsize) {
  if (outbuffer == nullptr || outsize == nullptr) {
    JPEGLI_ERROR("jpegli_mem_dest: Invalid destination.");
  }
  if (cinfo->dest && cinfo->dest->init_destination !=
                         jpegli::MemoryDestinationManager::init_destination) {
    JPEGLI_ERROR("jpegli_mem_dest: a different dest manager was already set");
  }
  if (!cinfo->dest) {
    auto dest = jpegli::Allocate<jpegli::MemoryDestinationManager>(cinfo, 1);
    dest->temp_buffer = nullptr;
    cinfo->dest = reinterpret_cast<jpeg_destination_mgr*>(dest);
  }
  auto dest = reinterpret_cast<jpegli::MemoryDestinationManager*>(cinfo->dest);
  dest->pub.init_destination =
      jpegli::MemoryDestinationManager::init_destination;
  dest->pub.empty_output_buffer =
      jpegli::MemoryDestinationManager::empty_output_buffer;
  dest->pub.term_destination =
      jpegli::MemoryDestinationManager::term_destination;
  dest->output = outbuffer;
  dest->output_size = outsize;
  if (*outbuffer == nullptr || *outsize == 0) {
    dest->temp_buffer =
        reinterpret_cast<uint8_t*>(malloc(jpegli::kDestBufferSize));
    *outbuffer = dest->temp_buffer;
    *outsize = jpegli::kDestBufferSize;
  }
  dest->current_buffer = *outbuffer;
  dest->buffer_size = *outsize;
  dest->pub.next_output_byte = dest->current_buffer;
  dest->pub.free_in_buffer = dest->buffer_size;
}
