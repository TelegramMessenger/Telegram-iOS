// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/decode.h>
#include <jxl/decode_cxx.h>
#include <jxl/thread_parallel_runner.h>
#include <jxl/thread_parallel_runner_cxx.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <hwy/targets.h>
#include <map>
#include <mutex>
#include <random>
#include <vector>

namespace {

// Externally visible value to ensure pixels are used in the fuzzer.
int external_code = 0;

constexpr const size_t kStreamingTargetNumberOfChunks = 128;

// Options for the fuzzing
struct FuzzSpec {
  JxlDataType output_type;
  JxlEndianness output_endianness;
  size_t output_align;
  bool get_alpha;
  bool get_grayscale;
  bool use_streaming;
  bool jpeg_to_pixels;  // decode to pixels even if it is JPEG-reconstructible
  // Whether to use the callback mechanism for the output image or not.
  bool use_callback;
  bool keep_orientation;
  bool decode_boxes;
  bool coalescing;
  // Used for random variation of chunk sizes, extra channels, ... to get
  uint32_t random_seed;
};

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

template <typename T>
void Consume(const T& entry) {
  const uint8_t* begin = reinterpret_cast<const uint8_t*>(&entry);
  Consume(begin, begin + sizeof(T));
}

// use_streaming: if true, decodes the data in small chunks, if false, decodes
// it in one shot.
bool DecodeJpegXl(const uint8_t* jxl, size_t size, size_t max_pixels,
                  const FuzzSpec& spec, std::vector<uint8_t>* pixels,
                  std::vector<uint8_t>* jpeg, size_t* xsize, size_t* ysize,
                  std::vector<uint8_t>* icc_profile) {
  // Multi-threaded parallel runner. Limit to max 2 threads since the fuzzer
  // itself is already multithreaded.
  size_t num_threads =
      std::min<size_t>(2, JxlThreadParallelRunnerDefaultNumWorkerThreads());
  auto runner = JxlThreadParallelRunnerMake(nullptr, num_threads);

  std::mt19937 mt(spec.random_seed);
  std::exponential_distribution<> dis_streaming(kStreamingTargetNumberOfChunks);

  auto dec = JxlDecoderMake(nullptr);
  if (JXL_DEC_SUCCESS !=
      JxlDecoderSubscribeEvents(
          dec.get(), JXL_DEC_BASIC_INFO | JXL_DEC_COLOR_ENCODING |
                         JXL_DEC_PREVIEW_IMAGE | JXL_DEC_FRAME |
                         JXL_DEC_FULL_IMAGE | JXL_DEC_JPEG_RECONSTRUCTION |
                         JXL_DEC_BOX)) {
    return false;
  }
  if (JXL_DEC_SUCCESS != JxlDecoderSetParallelRunner(dec.get(),
                                                     JxlThreadParallelRunner,
                                                     runner.get())) {
    return false;
  }
  if (JXL_DEC_SUCCESS !=
      JxlDecoderSetKeepOrientation(dec.get(), spec.keep_orientation)) {
    abort();
  }
  if (JXL_DEC_SUCCESS != JxlDecoderSetCoalescing(dec.get(), spec.coalescing)) {
    abort();
  }
  JxlBasicInfo info;
  uint32_t channels = (spec.get_grayscale ? 1 : 3) + (spec.get_alpha ? 1 : 0);
  JxlPixelFormat format = {channels, spec.output_type, spec.output_endianness,
                           spec.output_align};

  if (!spec.use_streaming) {
    // Set all input at once
    JxlDecoderSetInput(dec.get(), jxl, size);
    JxlDecoderCloseInput(dec.get());
  }

  bool seen_basic_info = false;
  bool seen_color_encoding = false;
  bool seen_preview = false;
  bool seen_need_image_out = false;
  bool seen_full_image = false;
  bool seen_frame = false;
  uint32_t num_frames = 0;
  bool seen_jpeg_reconstruction = false;
  bool seen_jpeg_need_more_output = false;
  // If streaming and seen around half the input, test flushing
  bool tested_flush = false;

  // Size made available for the streaming input, emulating a subset of the
  // full input size.
  size_t streaming_size = 0;
  size_t leftover = size;
  size_t preview_xsize = 0;
  size_t preview_ysize = 0;
  bool want_preview = false;
  std::vector<uint8_t> preview_pixels;

  std::vector<uint8_t> extra_channel_pixels;

  // Callback function used when decoding with use_callback.
  struct DecodeCallbackData {
    JxlBasicInfo info;
    size_t xsize = 0;
    size_t ysize = 0;
    std::mutex called_rows_mutex;
    // For each row stores the segments of the row being called. For each row
    // the sum of all the int values in the map up to [i] (inclusive) tell how
    // many times a callback included the pixel i of that row.
    std::vector<std::map<uint32_t, int>> called_rows;

    // Use the pixel values.
    uint32_t value = 0;
  };
  DecodeCallbackData decode_callback_data;
  auto decode_callback = +[](void* opaque, size_t x, size_t y,
                             size_t num_pixels, const void* pixels) {
    DecodeCallbackData* data = static_cast<DecodeCallbackData*>(opaque);
    if (num_pixels > data->xsize) abort();
    if (x + num_pixels > data->xsize) abort();
    if (y >= data->ysize) abort();
    if (num_pixels && !pixels) abort();
    // Keep track of the segments being called by the callback.
    {
      const std::lock_guard<std::mutex> lock(data->called_rows_mutex);
      data->called_rows[y][x]++;
      data->called_rows[y][x + num_pixels]--;
      data->value += *static_cast<const uint8_t*>(pixels);
    }
  };

  JxlExtraChannelInfo extra_channel_info;

  std::vector<uint8_t> box_buffer;

  if (spec.decode_boxes &&
      JXL_DEC_SUCCESS != JxlDecoderSetDecompressBoxes(dec.get(), JXL_TRUE)) {
    // error ignored, can still fuzz if it doesn't brotli-decompress brob boxes.
  }

  for (;;) {
    JxlDecoderStatus status = JxlDecoderProcessInput(dec.get());
    if (status == JXL_DEC_ERROR) {
      return false;
    } else if (status == JXL_DEC_NEED_MORE_INPUT) {
      if (spec.use_streaming) {
        size_t remaining = JxlDecoderReleaseInput(dec.get());
        // move any remaining bytes to the front if necessary
        size_t used = streaming_size - remaining;
        jxl += used;
        leftover -= used;
        streaming_size -= used;
        size_t chunk_size = std::max<size_t>(
            1, size * std::min<double>(1.0, dis_streaming(mt)));
        size_t add_size =
            std::min<size_t>(chunk_size, leftover - streaming_size);
        if (add_size == 0) {
          // End of the streaming data reached
          return false;
        }
        streaming_size += add_size;
        if (JXL_DEC_SUCCESS !=
            JxlDecoderSetInput(dec.get(), jxl, streaming_size)) {
          return false;
        }
        if (leftover == streaming_size) {
          // All possible input bytes given
          JxlDecoderCloseInput(dec.get());
        }

        if (!tested_flush && seen_frame) {
          // Test flush max once to avoid too slow fuzzer run
          tested_flush = true;
          JxlDecoderFlushImage(dec.get());
        }
      } else {
        return false;
      }
    } else if (status == JXL_DEC_JPEG_NEED_MORE_OUTPUT) {
      if (want_preview) abort();  // expected preview before frame
      if (spec.jpeg_to_pixels) abort();
      if (!seen_jpeg_reconstruction) abort();
      seen_jpeg_need_more_output = true;
      size_t used_jpeg_output =
          jpeg->size() - JxlDecoderReleaseJPEGBuffer(dec.get());
      jpeg->resize(std::max<size_t>(4096, jpeg->size() * 2));
      uint8_t* jpeg_buffer = jpeg->data() + used_jpeg_output;
      size_t jpeg_buffer_size = jpeg->size() - used_jpeg_output;

      if (JXL_DEC_SUCCESS !=
          JxlDecoderSetJPEGBuffer(dec.get(), jpeg_buffer, jpeg_buffer_size)) {
        return false;
      }
    } else if (status == JXL_DEC_BASIC_INFO) {
      if (seen_basic_info) abort();  // already seen basic info
      seen_basic_info = true;

      memset(&info, 0, sizeof(info));
      if (JXL_DEC_SUCCESS != JxlDecoderGetBasicInfo(dec.get(), &info)) {
        return false;
      }
      Consume(info);

      *xsize = info.xsize;
      *ysize = info.ysize;
      decode_callback_data.info = info;
      size_t num_pixels = *xsize * *ysize;
      // num_pixels overflow
      if (*xsize != 0 && num_pixels / *xsize != *ysize) return false;
      // limit max memory of this fuzzer test
      if (num_pixels > max_pixels) return false;

      if (info.have_preview) {
        want_preview = true;
        preview_xsize = info.preview.xsize;
        preview_ysize = info.preview.ysize;
        size_t preview_num_pixels = preview_xsize * preview_ysize;
        // num_pixels overflow
        if (preview_xsize != 0 &&
            preview_num_pixels / preview_xsize != preview_ysize) {
          return false;
        }
        // limit max memory of this fuzzer test
        if (preview_num_pixels > max_pixels) return false;
      }

      for (size_t ec = 0; ec < info.num_extra_channels; ++ec) {
        memset(&extra_channel_info, 0, sizeof(extra_channel_info));
        if (JXL_DEC_SUCCESS !=
            JxlDecoderGetExtraChannelInfo(dec.get(), ec, &extra_channel_info)) {
          abort();
        }
        Consume(extra_channel_info);
        std::vector<char> ec_name(extra_channel_info.name_length + 1);
        if (JXL_DEC_SUCCESS != JxlDecoderGetExtraChannelName(dec.get(), ec,
                                                             ec_name.data(),
                                                             ec_name.size())) {
          abort();
        }
        Consume(ec_name.cbegin(), ec_name.cend());
      }
    } else if (status == JXL_DEC_COLOR_ENCODING) {
      if (!seen_basic_info) abort();     // expected basic info first
      if (seen_color_encoding) abort();  // already seen color encoding
      seen_color_encoding = true;

      // Get the ICC color profile of the pixel data
      size_t icc_size;
      if (JXL_DEC_SUCCESS !=
          JxlDecoderGetICCProfileSize(dec.get(), JXL_COLOR_PROFILE_TARGET_DATA,
                                      &icc_size)) {
        return false;
      }
      icc_profile->resize(icc_size);
      if (JXL_DEC_SUCCESS != JxlDecoderGetColorAsICCProfile(
                                 dec.get(), JXL_COLOR_PROFILE_TARGET_DATA,
                                 icc_profile->data(), icc_profile->size())) {
        return false;
      }
      if (want_preview) {
        size_t preview_size;
        if (JXL_DEC_SUCCESS !=
            JxlDecoderPreviewOutBufferSize(dec.get(), &format, &preview_size)) {
          return false;
        }
        preview_pixels.resize(preview_size);
        if (JXL_DEC_SUCCESS != JxlDecoderSetPreviewOutBuffer(
                                   dec.get(), &format, preview_pixels.data(),
                                   preview_pixels.size())) {
          abort();
        }
      }
    } else if (status == JXL_DEC_PREVIEW_IMAGE) {
      if (seen_preview) abort();
      if (!want_preview) abort();
      if (!seen_color_encoding) abort();
      want_preview = false;
      seen_preview = true;
      Consume(preview_pixels.cbegin(), preview_pixels.cend());
    } else if (status == JXL_DEC_FRAME ||
               status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
      if (want_preview) abort();          // expected preview before frame
      if (!seen_color_encoding) abort();  // expected color encoding first
      if (status == JXL_DEC_FRAME) {
        if (seen_frame) abort();  // already seen JXL_DEC_FRAME
        seen_frame = true;
        JxlFrameHeader frame_header;
        memset(&frame_header, 0, sizeof(frame_header));
        if (JXL_DEC_SUCCESS !=
            JxlDecoderGetFrameHeader(dec.get(), &frame_header)) {
          abort();
        }
        decode_callback_data.xsize = frame_header.layer_info.xsize;
        decode_callback_data.ysize = frame_header.layer_info.ysize;
        if (!spec.coalescing) {
          decode_callback_data.called_rows.clear();
        }
        decode_callback_data.called_rows.resize(decode_callback_data.ysize);
        Consume(frame_header);
        std::vector<char> frame_name(frame_header.name_length + 1);
        if (JXL_DEC_SUCCESS != JxlDecoderGetFrameName(dec.get(),
                                                      frame_name.data(),
                                                      frame_name.size())) {
          abort();
        }
        Consume(frame_name.cbegin(), frame_name.cend());
        // When not testing streaming, test that JXL_DEC_NEED_IMAGE_OUT_BUFFER
        // occurs instead, so do not set buffer now.
        if (!spec.use_streaming) continue;
      }
      if (status == JXL_DEC_NEED_IMAGE_OUT_BUFFER) {
        // expected JXL_DEC_FRAME instead
        if (!seen_frame) abort();
        // already should have set buffer if streaming
        if (spec.use_streaming) abort();
        // already seen need image out
        if (seen_need_image_out) abort();
        seen_need_image_out = true;
      }

      if (info.num_extra_channels > 0) {
        std::uniform_int_distribution<> dis(0, info.num_extra_channels);
        size_t ec_index = dis(mt);
        // There is also a probability no extra channel is chosen
        if (ec_index < info.num_extra_channels) {
          size_t ec_index = info.num_extra_channels - 1;
          size_t ec_size;
          if (JXL_DEC_SUCCESS != JxlDecoderExtraChannelBufferSize(
                                     dec.get(), &format, &ec_size, ec_index)) {
            return false;
          }
          extra_channel_pixels.resize(ec_size);
          if (JXL_DEC_SUCCESS !=
              JxlDecoderSetExtraChannelBuffer(dec.get(), &format,
                                              extra_channel_pixels.data(),
                                              ec_size, ec_index)) {
            return false;
          }
        }
      }

      if (spec.use_callback) {
        if (JXL_DEC_SUCCESS !=
            JxlDecoderSetImageOutCallback(dec.get(), &format, decode_callback,
                                          &decode_callback_data)) {
          return false;
        }
      } else {
        // Use the pixels output buffer.
        size_t buffer_size;
        if (JXL_DEC_SUCCESS !=
            JxlDecoderImageOutBufferSize(dec.get(), &format, &buffer_size)) {
          return false;
        }
        pixels->resize(buffer_size);
        void* pixels_buffer = (void*)pixels->data();
        size_t pixels_buffer_size = pixels->size();
        if (JXL_DEC_SUCCESS !=
            JxlDecoderSetImageOutBuffer(dec.get(), &format, pixels_buffer,
                                        pixels_buffer_size)) {
          return false;
        }
      }
    } else if (status == JXL_DEC_JPEG_RECONSTRUCTION) {
      // Do not check preview precedence here, since this event only declares
      // that JPEG is going to be decoded; though, when first byte of JPEG
      // arrives (JXL_DEC_JPEG_NEED_MORE_OUTPUT) it is certain that preview
      // should have been produced already.
      if (seen_jpeg_reconstruction) abort();
      seen_jpeg_reconstruction = true;
      if (!spec.jpeg_to_pixels) {
        // Make sure buffer is allocated, but current size is too small to
        // contain valid JPEG.
        jpeg->resize(1);
        uint8_t* jpeg_buffer = jpeg->data();
        size_t jpeg_buffer_size = jpeg->size();
        if (JXL_DEC_SUCCESS !=
            JxlDecoderSetJPEGBuffer(dec.get(), jpeg_buffer, jpeg_buffer_size)) {
          return false;
        }
      }
    } else if (status == JXL_DEC_FULL_IMAGE) {
      if (want_preview) abort();  // expected preview before frame
      if (!spec.jpeg_to_pixels && seen_jpeg_reconstruction) {
        if (!seen_jpeg_need_more_output) abort();
        jpeg->resize(jpeg->size() - JxlDecoderReleaseJPEGBuffer(dec.get()));
      } else {
        // expected need image out or frame first
        if (!seen_need_image_out && !seen_frame) abort();
      }

      seen_full_image = true;  // there may be multiple if animated

      // There may be a next animation frame so expect those again:
      seen_need_image_out = false;
      seen_frame = false;
      num_frames++;

      // "Use" all the pixels; MSAN needs a conditional to count as usage.
      Consume(pixels->cbegin(), pixels->cend());
      Consume(jpeg->cbegin(), jpeg->cend());

      // When not coalescing, check that the whole (possibly cropped) frame was
      // sent
      if (seen_need_image_out && spec.use_callback && spec.coalescing) {
        // Check that the callback sent all the pixels
        for (uint32_t y = 0; y < decode_callback_data.ysize; y++) {
          // Check that each row was at least called once.
          if (decode_callback_data.called_rows[y].empty()) abort();
          uint32_t last_idx = 0;
          int calls = 0;
          for (auto it : decode_callback_data.called_rows[y]) {
            if (it.first > last_idx) {
              if (static_cast<uint32_t>(calls) != 1) abort();
            }
            calls += it.second;
            last_idx = it.first;
          }
        }
      }
      // Nothing to do. Do not yet return. If the image is an animation, more
      // full frames may be decoded. This example only keeps the last one.
    } else if (status == JXL_DEC_SUCCESS) {
      if (!seen_full_image) abort();  // expected full image before finishing

      // When decoding we may not get seen_need_image_out unless we were
      // decoding the image to pixels.
      if (seen_need_image_out && spec.use_callback && spec.coalescing) {
        // Check that the callback sent all the pixels
        for (uint32_t y = 0; y < decode_callback_data.ysize; y++) {
          // Check that each row was at least called once.
          if (decode_callback_data.called_rows[y].empty()) abort();
          uint32_t last_idx = 0;
          int calls = 0;
          for (auto it : decode_callback_data.called_rows[y]) {
            if (it.first > last_idx) {
              if (static_cast<uint32_t>(calls) != num_frames) abort();
            }
            calls += it.second;
            last_idx = it.first;
          }
        }
      }

      // All decoding successfully finished.
      // It's not required to call JxlDecoderReleaseInput(dec.get()) here since
      // the decoder will be destroyed.
      return true;
    } else if (status == JXL_DEC_BOX) {
      if (spec.decode_boxes) {
        if (!box_buffer.empty()) {
          size_t remaining = JxlDecoderReleaseBoxBuffer(dec.get());
          size_t box_size = box_buffer.size() - remaining;
          if (box_size != 0) {
            Consume(box_buffer.begin(), box_buffer.begin() + box_size);
            box_buffer.clear();
          }
        }
        box_buffer.resize(64);
        JxlDecoderSetBoxBuffer(dec.get(), box_buffer.data(), box_buffer.size());
      }
    } else if (status == JXL_DEC_BOX_NEED_MORE_OUTPUT) {
      if (!spec.decode_boxes) {
        abort();  // Not expected when not setting output buffer
      }
      size_t remaining = JxlDecoderReleaseBoxBuffer(dec.get());
      size_t box_size = box_buffer.size() - remaining;
      box_buffer.resize(box_buffer.size() * 2);
      JxlDecoderSetBoxBuffer(dec.get(), box_buffer.data() + box_size,
                             box_buffer.size() - box_size);
    } else {
      return false;
    }
  }
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
  // Allows some different possible variations in the chunk sizes of the
  // streaming case
  spec.random_seed = flags ^ size;
  spec.get_alpha = !!getFlag(1);
  spec.get_grayscale = !!getFlag(1);
  spec.use_streaming = !!getFlag(1);
  spec.jpeg_to_pixels = !!getFlag(1);
  spec.use_callback = !!getFlag(1);
  spec.keep_orientation = !!getFlag(1);
  spec.coalescing = !!getFlag(1);
  spec.output_type = static_cast<JxlDataType>(getFlag(JXL_TYPE_FLOAT16));
  spec.output_endianness = static_cast<JxlEndianness>(getFlag(JXL_BIG_ENDIAN));
  spec.output_align = getFlag(16);
  spec.decode_boxes = !!getFlag(1);

  std::vector<uint8_t> pixels;
  std::vector<uint8_t> jpeg;
  std::vector<uint8_t> icc;
  size_t xsize, ysize;
  size_t max_pixels = 1 << 21;

  const auto targets = hwy::SupportedAndGeneratedTargets();
  hwy::SetSupportedTargetsForTest(targets[getFlag(targets.size() - 1)]);
  DecodeJpegXl(data, size, max_pixels, spec, &pixels, &jpeg, &xsize, &ysize,
               &icc);
  hwy::SetSupportedTargetsForTest(0);

  return 0;
}

}  // namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  return TestOneInput(data, size);
}
