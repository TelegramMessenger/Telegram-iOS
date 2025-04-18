// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This C++ example decodes a JPEG XL image progressively (input bytes are
// passed in chunks). The example outputs the intermediate steps to PAM files.

#ifndef __STDC_FORMAT_MACROS
#define __STDC_FORMAT_MACROS
#endif

#include <inttypes.h>
#include <jxl/decode.h>
#include <jxl/decode_cxx.h>
#include <jxl/resizable_parallel_runner.h>
#include <jxl/resizable_parallel_runner_cxx.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <vector>

bool WritePAM(const char* filename, const uint8_t* buffer, size_t w, size_t h) {
  FILE* fp = fopen(filename, "wb");
  if (!fp) {
    fprintf(stderr, "Could not open %s for writing", filename);
    return false;
  }
  fprintf(fp,
          "P7\nWIDTH %" PRIu64 "\nHEIGHT %" PRIu64
          "\nDEPTH 4\nMAXVAL 255\nTUPLTYPE "
          "RGB_ALPHA\nENDHDR\n",
          static_cast<uint64_t>(w), static_cast<uint64_t>(h));
  size_t num_bytes = w * h * 4;
  if (fwrite(buffer, 1, num_bytes, fp) != num_bytes) {
    fclose(fp);
    return false;
  };
  if (fclose(fp) != 0) {
    return false;
  }
  return true;
}

/** Decodes JPEG XL image to 8-bit integer RGBA pixels and an ICC Profile, in a
 * progressive way, saving the intermediate steps.
 */
bool DecodeJpegXlProgressive(const uint8_t* jxl, size_t size,
                             const char* filename, size_t chunksize) {
  std::vector<uint8_t> pixels;
  std::vector<uint8_t> icc_profile;
  size_t xsize = 0, ysize = 0;

  // Multi-threaded parallel runner.
  auto runner = JxlResizableParallelRunnerMake(nullptr);

  auto dec = JxlDecoderMake(nullptr);
  if (JXL_DEC_SUCCESS !=
      JxlDecoderSubscribeEvents(dec.get(), JXL_DEC_BASIC_INFO |
                                               JXL_DEC_COLOR_ENCODING |
                                               JXL_DEC_FULL_IMAGE)) {
    fprintf(stderr, "JxlDecoderSubscribeEvents failed\n");
    return false;
  }

  if (JXL_DEC_SUCCESS != JxlDecoderSetParallelRunner(dec.get(),
                                                     JxlResizableParallelRunner,
                                                     runner.get())) {
    fprintf(stderr, "JxlDecoderSetParallelRunner failed\n");
    return false;
  }

  JxlBasicInfo info;
  JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};

  size_t seen = 0;
  JxlDecoderSetInput(dec.get(), jxl, chunksize);
  size_t remaining = chunksize;

  for (;;) {
    JxlDecoderStatus status = JxlDecoderProcessInput(dec.get());

    if (status == JXL_DEC_ERROR) {
      fprintf(stderr, "Decoder error\n");
      return false;
    } else if (status == JXL_DEC_NEED_MORE_INPUT || status == JXL_DEC_SUCCESS ||
               status == JXL_DEC_FULL_IMAGE) {
      seen += remaining - JxlDecoderReleaseInput(dec.get());
      printf("Flushing after %" PRIu64 " bytes\n", static_cast<uint64_t>(seen));
      if (status == JXL_DEC_NEED_MORE_INPUT &&
          JXL_DEC_SUCCESS != JxlDecoderFlushImage(dec.get())) {
        printf("flush error (no preview yet)\n");
      } else {
        char fname[1024];
        if (snprintf(fname, 1024, "%s-%" PRIu64 ".pam", filename,
                     static_cast<uint64_t>(seen)) >= 1024) {
          fprintf(stderr, "Filename too long\n");
          return false;
        };
        if (!WritePAM(fname, pixels.data(), xsize, ysize)) {
          fprintf(stderr, "Error writing progressive output\n");
        }
      }
      remaining = size - seen;
      if (remaining > chunksize) remaining = chunksize;
      if (remaining == 0) {
        if (status == JXL_DEC_NEED_MORE_INPUT) {
          fprintf(stderr, "Error, already provided all input\n");
          return false;
        } else {
          return true;
        }
      }
      JxlDecoderSetInput(dec.get(), jxl + seen, remaining);
    } else if (status == JXL_DEC_BASIC_INFO) {
      if (JXL_DEC_SUCCESS != JxlDecoderGetBasicInfo(dec.get(), &info)) {
        fprintf(stderr, "JxlDecoderGetBasicInfo failed\n");
        return false;
      }
      xsize = info.xsize;
      ysize = info.ysize;
      JxlResizableParallelRunnerSetThreads(
          runner.get(),
          JxlResizableParallelRunnerSuggestThreads(info.xsize, info.ysize));
    } else if (status == JXL_DEC_COLOR_ENCODING) {
      // Get the ICC color profile of the pixel data
      size_t icc_size;
      if (JXL_DEC_SUCCESS !=
          JxlDecoderGetICCProfileSize(
              dec.get(), JXL_COLOR_PROFILE_TARGET_ORIGINAL, &icc_size)) {
        fprintf(stderr, "JxlDecoderGetICCProfileSize failed\n");
        return false;
      }
      icc_profile.resize(icc_size);
      if (JXL_DEC_SUCCESS != JxlDecoderGetColorAsICCProfile(
                                 dec.get(), JXL_COLOR_PROFILE_TARGET_ORIGINAL,
                                 icc_profile.data(), icc_profile.size())) {
        fprintf(stderr, "JxlDecoderGetColorAsICCProfile failed\n");
        return false;
      }
    } else if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
      size_t buffer_size;
      if (JXL_DEC_SUCCESS !=
          JxlDecoderImageOutBufferSize(dec.get(), &format, &buffer_size)) {
        fprintf(stderr, "JxlDecoderImageOutBufferSize failed\n");
        return false;
      }
      if (buffer_size != xsize * ysize * 4) {
        fprintf(stderr, "Invalid out buffer size %" PRIu64 " != %" PRIu64 "\n",
                static_cast<uint64_t>(buffer_size),
                static_cast<uint64_t>(xsize * ysize * 4));
        return false;
      }
      pixels.resize(xsize * ysize * 4);
      if (JXL_DEC_SUCCESS != JxlDecoderSetImageOutBuffer(dec.get(), &format,
                                                         pixels.data(),
                                                         pixels.size())) {
        fprintf(stderr, "JxlDecoderSetImageOutBuffer failed\n");
        return false;
      }
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

int main(int argc, char* argv[]) {
  if (argc < 3) {
    fprintf(
        stderr,
        "Usage: %s <jxl> <basename> [chunksize]\n"
        "Where:\n"
        "  jxl = input JPEG XL image filename\n"
        "  basename = prefix of output filenames\n"
        "  chunksize = loads chunksize bytes at a time and writes\n"
        "              intermediate results to basename-[bytes loaded].pam\n"
        "Output files will be overwritten.\n",
        argv[0]);
    return 1;
  }

  const char* jxl_filename = argv[1];
  const char* png_filename = argv[2];

  std::vector<uint8_t> jxl;
  if (!LoadFile(jxl_filename, &jxl)) {
    fprintf(stderr, "couldn't load %s\n", jxl_filename);
    return 1;
  }
  size_t chunksize = jxl.size();
  if (argc > 3) {
    long cs = atol(argv[3]);
    if (cs < 100) {
      fprintf(stderr, "Chunk size is too low, try at least 100 bytes\n");
      return 1;
    }
    chunksize = cs;
  }

  if (!DecodeJpegXlProgressive(jxl.data(), jxl.size(), png_filename,
                               chunksize)) {
    fprintf(stderr, "Error while decoding the jxl file\n");
    return 1;
  }
  return 0;
}
