// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This binary tool lists the boxes of any box-based format (JPEG XL,
// JPEG 2000, MP4, ...).
// This exists as a test for manual verification, rather than an actual tool.

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/printf_macros.h"
#include "tools/box/box.h"
#include "tools/file_io.h"

namespace jpegxl {
namespace tools {

int RunMain(int argc, const char* argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <filename>", argv[0]);
    return 1;
  }

  jxl::PaddedBytes compressed;
  if (!ReadFile(argv[1], &compressed)) return 1;
  fprintf(stderr, "Read %" PRIuS " compressed bytes\n", compressed.size());

  const uint8_t* in = compressed.data();
  size_t available_in = compressed.size();

  fprintf(stderr, "File size: %" PRIuS "\n", compressed.size());

  while (available_in != 0) {
    const uint8_t* start = in;
    Box box;
    if (!ParseBoxHeader(&in, &available_in, &box)) {
      fprintf(stderr, "Failed at %" PRIuS "\n",
              compressed.size() - available_in);
      break;
    }

    size_t data_size = box.data_size_given ? box.data_size : available_in;
    size_t header_size = in - start;
    size_t box_size = header_size + data_size;

    for (size_t i = 0; i < sizeof(box.type); i++) {
      char c = box.type[i];
      if (c < 32 || c > 127) {
        printf("Unprintable character in box type, likely not a box file.\n");
        return 0;
      }
    }

    printf("box: \"%.4s\" box_size:%" PRIuS " data_size:%" PRIuS, box.type,
           box_size, data_size);
    if (!memcmp("uuid", box.type, 4)) {
      printf(" -- extended type:\"%.16s\"", box.extended_type);
    }
    if (!memcmp("ftyp", box.type, 4) && data_size > 4) {
      std::string ftype(in, in + 4);
      printf(" -- ftype:\"%s\"", ftype.c_str());
    }
    printf("\n");

    if (data_size > available_in) {
      fprintf(
          stderr, "Unexpected end of file %" PRIuS " %" PRIuS " %" PRIuS "\n",
          static_cast<size_t>(box.data_size), available_in, compressed.size());
      break;
    }

    in += data_size;
    available_in -= data_size;
  }

  return 0;
}

}  // namespace tools
}  // namespace jpegxl

int main(int argc, const char* argv[]) {
  return jpegxl::tools::RunMain(argc, argv);
}
