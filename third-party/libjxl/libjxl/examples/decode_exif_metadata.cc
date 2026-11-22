// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This C++ example decodes a JPEG XL image in one shot (all input bytes
// available at once). The example outputs the pixels and color information to a
// floating point image and an ICC profile on disk.

#include <jxl/decode.h>
#include <jxl/decode_cxx.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <vector>

bool DecodeJpegXlExif(const uint8_t* jxl, size_t size,
                      std::vector<uint8_t>* exif) {
  auto dec = JxlDecoderMake(nullptr);

  // We're only interested in the Exif boxes in this example, so don't
  // subscribe to events related to pixel data.
  if (JXL_DEC_SUCCESS != JxlDecoderSubscribeEvents(dec.get(), JXL_DEC_BOX)) {
    fprintf(stderr, "JxlDecoderSubscribeEvents failed\n");
    return false;
  }
  bool support_decompression = true;
  if (JXL_DEC_SUCCESS != JxlDecoderSetDecompressBoxes(dec.get(), JXL_TRUE)) {
    fprintf(stderr,
            "NOTE: decompressing brob boxes not supported with the currently "
            "used jxl library.\n");
    support_decompression = false;
  }

  JxlDecoderSetInput(dec.get(), jxl, size);
  JxlDecoderCloseInput(dec.get());

  const constexpr size_t kChunkSize = 65536;
  size_t output_pos = 0;

  for (;;) {
    JxlDecoderStatus status = JxlDecoderProcessInput(dec.get());
    if (status == JXL_DEC_ERROR) {
      fprintf(stderr, "Decoder error\n");
      return false;
    } else if (status == JXL_DEC_NEED_MORE_INPUT) {
      fprintf(stderr, "Error, already provided all input\n");
      return false;
    } else if (status == JXL_DEC_BOX) {
      if (!exif->empty()) {
        size_t remaining = JxlDecoderReleaseBoxBuffer(dec.get());
        exif->resize(exif->size() - remaining);
        // No need to wait for JXL_DEC_SUCCESS or decode other boxes.
        return true;
      }
      JxlBoxType type;
      if (JXL_DEC_SUCCESS !=
          JxlDecoderGetBoxType(dec.get(), type, support_decompression)) {
        fprintf(stderr, "Error, failed to get box type\n");
        return false;
      }
      if (!memcmp(type, "Exif", 4)) {
        exif->resize(kChunkSize);
        JxlDecoderSetBoxBuffer(dec.get(), exif->data(), exif->size());
      }
    } else if (status == JXL_DEC_BOX_NEED_MORE_OUTPUT) {
      size_t remaining = JxlDecoderReleaseBoxBuffer(dec.get());
      output_pos += kChunkSize - remaining;
      exif->resize(exif->size() + kChunkSize);
      JxlDecoderSetBoxBuffer(dec.get(), exif->data() + output_pos,
                             exif->size() - output_pos);
    } else if (status == JXL_DEC_SUCCESS) {
      if (!exif->empty()) {
        size_t remaining = JxlDecoderReleaseBoxBuffer(dec.get());
        exif->resize(exif->size() - remaining);
        return true;
      }
      return true;
    } else {
      fprintf(stderr, "Unknown decoder status\n");
      return false;
    }
  }
}

bool LoadFile(const char* filename, std::vector<uint8_t>* out) {
  FILE* file = fopen(filename, "rb");
  if (!file) {
    return false;
  }

  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return false;
  }

  long size = ftell(file);
  // Avoid invalid file or directory.
  if (size >= LONG_MAX || size < 0) {
    fclose(file);
    return false;
  }

  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return false;
  }

  out->resize(size);
  size_t readsize = fread(out->data(), 1, size, file);
  if (fclose(file) != 0) {
    return false;
  }

  return readsize == static_cast<size_t>(size);
}

bool WriteFile(const char* filename, const uint8_t* data, size_t size) {
  FILE* file = fopen(filename, "wb");
  if (!file) {
    fprintf(stderr, "Could not open %s for writing", filename);
    return false;
  }
  fwrite(data, 1, size, file);
  if (fclose(file) != 0) {
    return false;
  }
  return true;
}

int main(int argc, char* argv[]) {
  if (argc != 3) {
    fprintf(stderr,
            "Usage: %s <jxl> <exif>\n"
            "Where:\n"
            "  jxl = input JPEG XL image filename\n"
            "  exif = output exif filename\n"
            "Output files will be overwritten.\n",
            argv[0]);
    return 1;
  }

  const char* jxl_filename = argv[1];
  const char* exif_filename = argv[2];

  std::vector<uint8_t> jxl;
  if (!LoadFile(jxl_filename, &jxl)) {
    fprintf(stderr, "couldn't load %s\n", jxl_filename);
    return 1;
  }

  std::vector<uint8_t> exif;
  if (!DecodeJpegXlExif(jxl.data(), jxl.size(), &exif)) {
    fprintf(stderr, "Error while decoding the jxl file\n");
    return 1;
  }
  if (exif.empty()) {
    printf("No exif data present in this image\n");
  } else {
    // TODO(lode): the exif box data contains the 4-byte TIFF header at the
    // beginning, check whether this is desired to be part of the output, or
    // should be removed.
    if (!WriteFile(exif_filename, exif.data(), exif.size())) {
      fprintf(stderr, "Error while writing the exif file\n");
      return 1;
    }
    printf("Successfully wrote %s\n", exif_filename);
  }
  return 0;
}
