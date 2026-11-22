// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <brotli/encode.h>
#include <jxl/codestream_header.h>
#include <jxl/encode.h>
#include <jxl/types.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>

#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_external_image.h"
#include "lib/jxl/enc_fast_lossless.h"
#include "lib/jxl/enc_fields.h"
#include "lib/jxl/enc_file.h"
#include "lib/jxl/enc_icc_codec.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/encode_internal.h"
#include "lib/jxl/exif.h"
#include "lib/jxl/jpeg/enc_jpeg_data.h"
#include "lib/jxl/luminance.h"
#include "lib/jxl/sanitizers.h"

// Debug-printing failure macro similar to JXL_FAILURE, but for the status code
// JXL_ENC_ERROR
#ifdef JXL_CRASH_ON_ERROR
#define JXL_API_ERROR(enc, error_code, format, ...)                          \
  (enc->error = error_code,                                                  \
   ::jxl::Debug(("%s:%d: " format "\n"), __FILE__, __LINE__, ##__VA_ARGS__), \
   ::jxl::Abort(), JXL_ENC_ERROR)
#define JXL_API_ERROR_NOSET(format, ...)                                     \
  (::jxl::Debug(("%s:%d: " format "\n"), __FILE__, __LINE__, ##__VA_ARGS__), \
   ::jxl::Abort(), JXL_ENC_ERROR)
#else  // JXL_CRASH_ON_ERROR
#define JXL_API_ERROR(enc, error_code, format, ...)                            \
  (enc->error = error_code,                                                    \
   ((JXL_DEBUG_ON_ERROR) &&                                                    \
    ::jxl::Debug(("%s:%d: " format "\n"), __FILE__, __LINE__, ##__VA_ARGS__)), \
   JXL_ENC_ERROR)
#define JXL_API_ERROR_NOSET(format, ...)                                     \
  (::jxl::Debug(("%s:%d: " format "\n"), __FILE__, __LINE__, ##__VA_ARGS__), \
   JXL_ENC_ERROR)
#endif  // JXL_CRASH_ON_ERROR

namespace jxl {}  // namespace jxl

uint32_t JxlEncoderVersion(void) {
  return JPEGXL_MAJOR_VERSION * 1000000 + JPEGXL_MINOR_VERSION * 1000 +
         JPEGXL_PATCH_VERSION;
}

namespace {
template <typename T>
void AppendJxlpBoxCounter(uint32_t counter, bool last, T* output) {
  if (last) counter |= 0x80000000;
  for (size_t i = 0; i < 4; i++) {
    output->push_back(counter >> (8 * (3 - i)) & 0xff);
  }
}

void QueueFrame(
    const JxlEncoderFrameSettings* frame_settings,
    jxl::MemoryManagerUniquePtr<jxl::JxlEncoderQueuedFrame>& frame) {
  if (frame_settings->values.lossless) {
    frame->option_values.cparams.SetLossless();
  }

  jxl::JxlEncoderQueuedInput queued_input(frame_settings->enc->memory_manager);
  queued_input.frame = std::move(frame);
  frame_settings->enc->input_queue.emplace_back(std::move(queued_input));
  frame_settings->enc->num_queued_frames++;
}

void QueueFastLosslessFrame(const JxlEncoderFrameSettings* frame_settings,
                            JxlFastLosslessFrameState* fast_lossless_frame) {
  jxl::JxlEncoderQueuedInput queued_input(frame_settings->enc->memory_manager);
  queued_input.fast_lossless_frame.reset(fast_lossless_frame);
  frame_settings->enc->input_queue.emplace_back(std::move(queued_input));
  frame_settings->enc->num_queued_frames++;
}

void QueueBox(JxlEncoder* enc,
              jxl::MemoryManagerUniquePtr<jxl::JxlEncoderQueuedBox>& box) {
  jxl::JxlEncoderQueuedInput queued_input(enc->memory_manager);
  queued_input.box = std::move(box);
  enc->input_queue.emplace_back(std::move(queued_input));
  enc->num_queued_boxes++;
}

// TODO(lode): share this code and the Brotli compression code in enc_jpeg_data
JxlEncoderStatus BrotliCompress(int quality, const uint8_t* in, size_t in_size,
                                jxl::PaddedBytes* out) {
  std::unique_ptr<BrotliEncoderState, decltype(BrotliEncoderDestroyInstance)*>
      enc(BrotliEncoderCreateInstance(nullptr, nullptr, nullptr),
          BrotliEncoderDestroyInstance);
  if (!enc) return JXL_API_ERROR_NOSET("BrotliEncoderCreateInstance failed");

  BrotliEncoderSetParameter(enc.get(), BROTLI_PARAM_QUALITY, quality);
  BrotliEncoderSetParameter(enc.get(), BROTLI_PARAM_SIZE_HINT, in_size);

  constexpr size_t kBufferSize = 128 * 1024;
  jxl::PaddedBytes temp_buffer(kBufferSize);

  size_t avail_in = in_size;
  const uint8_t* next_in = in;

  size_t total_out = 0;

  for (;;) {
    size_t avail_out = kBufferSize;
    uint8_t* next_out = temp_buffer.data();
    jxl::msan::MemoryIsInitialized(next_in, avail_in);
    if (!BrotliEncoderCompressStream(enc.get(), BROTLI_OPERATION_FINISH,
                                     &avail_in, &next_in, &avail_out, &next_out,
                                     &total_out)) {
      return JXL_API_ERROR_NOSET("Brotli compression failed");
    }
    size_t out_size = next_out - temp_buffer.data();
    jxl::msan::UnpoisonMemory(next_out - out_size, out_size);
    out->resize(out->size() + out_size);
    memcpy(out->data() + out->size() - out_size, temp_buffer.data(), out_size);
    if (BrotliEncoderIsFinished(enc.get())) break;
  }

  return JXL_ENC_SUCCESS;
}

// The JXL codestream can have level 5 or level 10. Levels have certain
// restrictions such as max allowed image dimensions. This function checks the
// level required to support the current encoder settings. The debug_string is
// intended to be used for developer API error messages, and may be set to
// nullptr.
int VerifyLevelSettings(const JxlEncoder* enc, std::string* debug_string) {
  const auto& m = enc->metadata.m;

  uint64_t xsize = enc->metadata.size.xsize();
  uint64_t ysize = enc->metadata.size.ysize();
  // The uncompressed ICC size, if it is used.
  size_t icc_size = 0;
  if (m.color_encoding.WantICC()) {
    icc_size = m.color_encoding.ICC().size();
  }

  // Level 10 checks

  if (xsize > (1ull << 30ull) || ysize > (1ull << 30ull) ||
      xsize * ysize > (1ull << 40ull)) {
    if (debug_string) *debug_string = "Too large image dimensions";
    return -1;
  }
  if (icc_size > (1ull << 28)) {
    if (debug_string) *debug_string = "Too large ICC profile size";
    return -1;
  }
  if (m.num_extra_channels > 256) {
    if (debug_string) *debug_string = "Too many extra channels";
    return -1;
  }

  // Level 5 checks

  if (!m.modular_16_bit_buffer_sufficient) {
    if (debug_string) *debug_string = "Too high modular bit depth";
    return 10;
  }
  if (xsize > (1ull << 18ull) || ysize > (1ull << 18ull) ||
      xsize * ysize > (1ull << 28ull)) {
    if (debug_string) *debug_string = "Too large image dimensions";
    return 10;
  }
  if (icc_size > (1ull << 22)) {
    if (debug_string) *debug_string = "Too large ICC profile";
    return 10;
  }
  if (m.num_extra_channels > 4) {
    if (debug_string) *debug_string = "Too many extra channels";
    return 10;
  }
  for (size_t i = 0; i < m.extra_channel_info.size(); ++i) {
    if (m.extra_channel_info[i].type == jxl::ExtraChannel::kBlack) {
      if (debug_string) *debug_string = "CMYK channel not allowed";
      return 10;
    }
  }

  // TODO(lode): also need to check if consecutive composite-still frames total
  // pixel amount doesn't exceed 2**28 in the case of level 5. This should be
  // done when adding frame and requires ability to add composite still frames
  // to be added first.

  // TODO(lode): also need to check animation duration of a frame. This should
  // be done when adding frame, but first requires implementing setting the
  // JxlFrameHeader for a frame.

  // TODO(lode): also need to check properties such as num_splines, num_patches,
  // modular_16bit_buffers and multiple properties of modular trees. However
  // these are not user-set properties so cannot be checked here, but decisions
  // the C++ encoder should be able to make based on the level.

  // All level 5 checks passes, so can return the more compatible level 5
  return 5;
}

size_t BitsPerChannel(JxlDataType data_type) {
  switch (data_type) {
    case JXL_TYPE_UINT8:
      return 8;
    case JXL_TYPE_UINT16:
      return 16;
    case JXL_TYPE_FLOAT:
      return 32;
    case JXL_TYPE_FLOAT16:
      return 16;
    default:
      return 0;  // signals unhandled JxlDataType
  }
}

template <typename T>
uint32_t GetBitDepth(JxlBitDepth bit_depth, const T& metadata,
                     JxlPixelFormat format) {
  if (bit_depth.type == JXL_BIT_DEPTH_FROM_PIXEL_FORMAT) {
    return BitsPerChannel(format.data_type);
  } else if (bit_depth.type == JXL_BIT_DEPTH_FROM_CODESTREAM) {
    return metadata.bit_depth.bits_per_sample;
  } else if (bit_depth.type == JXL_BIT_DEPTH_CUSTOM) {
    return bit_depth.bits_per_sample;
  } else {
    return 0;
  }
}

JxlEncoderStatus CheckValidBitdepth(uint32_t bits_per_sample,
                                    uint32_t exponent_bits_per_sample) {
  if (!exponent_bits_per_sample) {
    // The spec allows up to 31 for bits_per_sample here, but
    // the code does not (yet) support it.
    if (!(bits_per_sample > 0 && bits_per_sample <= 24)) {
      return JXL_API_ERROR_NOSET("Invalid value for bits_per_sample");
    }
  } else if ((exponent_bits_per_sample > 8) ||
             (bits_per_sample > 24 + exponent_bits_per_sample) ||
             (bits_per_sample < 3 + exponent_bits_per_sample)) {
    return JXL_API_ERROR_NOSET("Invalid float description");
  }
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus VerifyInputBitDepth(JxlBitDepth bit_depth,
                                     JxlPixelFormat format) {
  return JXL_ENC_SUCCESS;
}

bool EncodeFrameIndexBox(const jxl::JxlEncoderFrameIndexBox& frame_index_box,
                         jxl::BitWriter& writer) {
  bool ok = true;
  int NF = 0;
  for (size_t i = 0; i < frame_index_box.entries.size(); ++i) {
    if (i == 0 || frame_index_box.entries[i].to_be_indexed) {
      ++NF;
    }
  }
  // Frame index box contents varint + 8 bytes
  // continue with NF * 3 * varint
  // varint max length is 10 for 64 bit numbers, and these numbers
  // are limited to 63 bits.
  static const int kVarintMaxLength = 10;
  static const int kFrameIndexBoxHeaderLength = kVarintMaxLength + 8;
  static const int kFrameIndexBoxElementLength = 3 * kVarintMaxLength;
  const int buffer_size =
      kFrameIndexBoxHeaderLength + NF * kFrameIndexBoxElementLength;
  std::vector<uint8_t> buffer_vec(buffer_size);
  uint8_t* buffer = buffer_vec.data();
  size_t output_pos = 0;
  ok &= jxl::EncodeVarInt(NF, buffer_vec.size(), &output_pos, buffer);
  StoreBE32(frame_index_box.TNUM, &buffer[output_pos]);
  output_pos += 4;
  StoreBE32(frame_index_box.TDEN, &buffer[output_pos]);
  output_pos += 4;
  // When we record a frame in the index, the record needs to know
  // how many frames until the next indexed frame. That is why
  // we store the 'prev' record. That 'prev' record needs to store
  // the offset byte position to previously recorded indexed frame,
  // that's why we also trace previous to the previous frame.
  int prev_prev_ix = -1;  // For position offset (OFFi) delta coding.
  int prev_ix = 0;
  int T_prev = 0;
  int T = 0;
  for (size_t i = 1; i < frame_index_box.entries.size(); ++i) {
    if (frame_index_box.entries[i].to_be_indexed) {
      // Now we can record the previous entry, since we need to store
      // there how many frames until the next one.
      int64_t OFFi = frame_index_box.entries[prev_ix].OFFi;
      if (prev_prev_ix != -1) {
        // Offi needs to be offset of start byte of this frame compared to start
        // byte of previous frame from this index in the JPEG XL codestream. For
        // the first frame, this is the offset from the first byte of the JPEG
        // XL codestream.
        OFFi -= frame_index_box.entries[prev_prev_ix].OFFi;
      }
      int32_t Ti = T_prev;
      int32_t Fi = i - prev_ix;
      ok &= jxl::EncodeVarInt(OFFi, buffer_vec.size(), &output_pos, buffer);
      ok &= jxl::EncodeVarInt(Ti, buffer_vec.size(), &output_pos, buffer);
      ok &= jxl::EncodeVarInt(Fi, buffer_vec.size(), &output_pos, buffer);
      prev_prev_ix = prev_ix;
      prev_ix = i;
      T_prev = T;
      T += frame_index_box.entries[i].duration;
    }
  }
  {
    // Last frame.
    size_t i = frame_index_box.entries.size();
    int64_t OFFi = frame_index_box.entries[prev_ix].OFFi;
    if (prev_prev_ix != -1) {
      OFFi -= frame_index_box.entries[prev_prev_ix].OFFi;
    }
    int32_t Ti = T_prev;
    int32_t Fi = i - prev_ix;
    ok &= jxl::EncodeVarInt(OFFi, buffer_vec.size(), &output_pos, buffer);
    ok &= jxl::EncodeVarInt(Ti, buffer_vec.size(), &output_pos, buffer);
    ok &= jxl::EncodeVarInt(Fi, buffer_vec.size(), &output_pos, buffer);
  }
  // Enough buffer has been allocated, this function should never fail in
  // writing.
  JXL_ASSERT(ok);
  return ok;
}

}  // namespace

JxlEncoderStatus JxlEncoderStruct::RefillOutputByteQueue() {
  jxl::PaddedBytes bytes;

  jxl::JxlEncoderQueuedInput& input = input_queue[0];

  // TODO(lode): split this into 3 functions: for adding the signature and other
  // initial headers (jbrd, ...), one for adding frame, and one for adding user
  // box.

  if (!wrote_bytes) {
    // First time encoding any data, verify the level 5 vs level 10 settings
    std::string level_message;
    int required_level = VerifyLevelSettings(this, &level_message);
    // Only level 5 and 10 are defined, and the function can return -1 to
    // indicate full incompatibility.
    JXL_ASSERT(required_level == -1 || required_level == 5 ||
               required_level == 10);
    // codestream_level == -1 means auto-set to the required level
    if (codestream_level == -1) codestream_level = required_level;
    if (codestream_level == 5 && required_level != 5) {
      // If the required level is 10, return error rather than automatically
      // setting the level to 10, to avoid inadvertently creating a level 10
      // JXL file while intending to target a level 5 decoder.
      return JXL_API_ERROR(
          this, JXL_ENC_ERR_API_USAGE, "%s",
          ("Codestream level verification for level 5 failed: " + level_message)
              .c_str());
    }
    if (required_level == -1) {
      return JXL_API_ERROR(
          this, JXL_ENC_ERR_API_USAGE, "%s",
          ("Codestream level verification for level 10 failed: " +
           level_message)
              .c_str());
    }
    jxl::AuxOut* aux_out =
        input.frame ? input.frame->option_values.aux_out : nullptr;
    jxl::BitWriter writer;
    if (!WriteCodestreamHeaders(&metadata, &writer, aux_out)) {
      return JXL_API_ERROR(this, JXL_ENC_ERR_GENERIC,
                           "Failed to write codestream header");
    }
    // Only send ICC (at least several hundred bytes) if fields aren't enough.
    if (metadata.m.color_encoding.WantICC()) {
      if (!jxl::WriteICC(metadata.m.color_encoding.ICC(), &writer,
                         jxl::kLayerHeader, aux_out)) {
        return JXL_API_ERROR(this, JXL_ENC_ERR_GENERIC,
                             "Failed to write ICC profile");
      }
    }
    // TODO(lode): preview should be added here if a preview image is added

    jxl::BitWriter::Allotment allotment(&writer, 8);
    writer.ZeroPadToByte();
    allotment.ReclaimAndCharge(&writer, jxl::kLayerHeader, aux_out);

    // Not actually the end of frame, but the end of metadata/ICC, but helps
    // the next frame to start here for indexing purposes.
    codestream_bytes_written_end_of_frame +=
        jxl::DivCeil(writer.BitsWritten(), 8);

    bytes = std::move(writer).TakeBytes();

    if (MustUseContainer()) {
      // Add "JXL " and ftyp box.
      output_byte_queue.insert(
          output_byte_queue.end(), jxl::kContainerHeader,
          jxl::kContainerHeader + sizeof(jxl::kContainerHeader));
      if (codestream_level != 5) {
        // Add jxll box directly after the ftyp box to indicate the codestream
        // level.
        output_byte_queue.insert(
            output_byte_queue.end(), jxl::kLevelBoxHeader,
            jxl::kLevelBoxHeader + sizeof(jxl::kLevelBoxHeader));
        output_byte_queue.push_back(codestream_level);
      }

      // Whether to write the basic info and color profile header of the
      // codestream into an early separate jxlp box, so that it comes before
      // metadata or jpeg reconstruction boxes. In theory this could simply
      // always be done, but there's no reason to add an extra box with box
      // header overhead if the codestream will already come immediately after
      // the signature and level boxes.
      bool partial_header =
          store_jpeg_metadata ||
          (use_boxes && (!input.frame && !input.fast_lossless_frame));

      if (partial_header) {
        jxl::AppendBoxHeader(jxl::MakeBoxType("jxlp"), bytes.size() + 4,
                             /*unbounded=*/false, &output_byte_queue);
        AppendJxlpBoxCounter(jxlp_counter++, /*last=*/false,
                             &output_byte_queue);
        output_byte_queue.insert(output_byte_queue.end(), bytes.data(),
                                 bytes.data() + bytes.size());
        bytes.clear();
      }

      if (store_jpeg_metadata && !jpeg_metadata.empty()) {
        jxl::AppendBoxHeader(jxl::MakeBoxType("jbrd"), jpeg_metadata.size(),
                             false, &output_byte_queue);
        output_byte_queue.insert(output_byte_queue.end(), jpeg_metadata.begin(),
                                 jpeg_metadata.end());
      }
    }
    wrote_bytes = true;
  }

  // Choose frame or box processing: exactly one of the two unique pointers (box
  // or frame) in the input queue item is non-null.
  if (input.frame || input.fast_lossless_frame) {
    jxl::MemoryManagerUniquePtr<jxl::JxlEncoderQueuedFrame> input_frame =
        std::move(input.frame);
    if (input.fast_lossless_frame) {
      output_fast_frame_queue.push_back(std::move(input.fast_lossless_frame));
    }
    input_queue.erase(input_queue.begin());
    num_queued_frames--;
    if (input_frame) {
      for (unsigned idx = 0; idx < input_frame->ec_initialized.size(); idx++) {
        if (!input_frame->ec_initialized[idx]) {
          return JXL_API_ERROR(this, JXL_ENC_ERR_API_USAGE,
                               "Extra channel %u is not initialized", idx);
        }
      }

      // TODO(zond): If the input queue is empty and the frames_closed is true,
      // then mark this frame as the last.

      // TODO(zond): Handle progressive mode like EncodeFile does it.
      // TODO(zond): Handle animation like EncodeFile does it, by checking if
      //             JxlEncoderCloseFrames has been called and if the frame
      //             queue is empty (to see if it's the last animation frame).

      if (metadata.m.xyb_encoded) {
        input_frame->option_values.cparams.color_transform =
            jxl::ColorTransform::kXYB;
      } else {
        // TODO(zond): Figure out when to use kYCbCr instead.
        input_frame->option_values.cparams.color_transform =
            jxl::ColorTransform::kNone;
      }
    }

    uint32_t duration;
    uint32_t timecode;
    if (input_frame && metadata.m.have_animation) {
      duration = input_frame->option_values.header.duration;
      timecode = input_frame->option_values.header.timecode;
    } else {
      // If have_animation is false, the encoder should ignore the duration and
      // timecode values. However, assigning them to ib will cause the encoder
      // to write an invalid frame header that can't be decoded so ensure
      // they're the default value of 0 here.
      duration = 0;
      timecode = 0;
    }

    bool last_frame = frames_closed && !num_queued_frames;

    size_t codestream_byte_size = 0;

    jxl::BitWriter writer;

    if (input_frame) {
      jxl::PassesEncoderState enc_state;

      frame_index_box.AddFrame(codestream_bytes_written_end_of_frame, duration,
                               input_frame->option_values.frame_index_box);

      // EncodeFrame creates jxl::FrameHeader object internally based on the
      // FrameInfo, imagebundle, cparams and metadata. Copy the information to
      // these.
      jxl::ImageBundle& ib = input_frame->frame;
      ib.duration = duration;
      ib.timecode = timecode;
      ib.name = input_frame->option_values.frame_name;
      ib.blendmode = static_cast<jxl::BlendMode>(
          input_frame->option_values.header.layer_info.blend_info.blendmode);
      ib.blend =
          input_frame->option_values.header.layer_info.blend_info.blendmode !=
          JXL_BLEND_REPLACE;

      size_t save_as_reference =
          input_frame->option_values.header.layer_info.save_as_reference;
      if (save_as_reference >= 3) {
        return JXL_API_ERROR(
            this, JXL_ENC_ERR_API_USAGE,
            "Cannot use save_as_reference values >=3 (found: %d)",
            (int)save_as_reference);
      }
      ib.use_for_next_frame = !!save_as_reference;

      jxl::FrameInfo frame_info;
      frame_info.is_last = last_frame;
      frame_info.save_as_reference = save_as_reference;
      frame_info.source =
          input_frame->option_values.header.layer_info.blend_info.source;
      frame_info.clamp =
          input_frame->option_values.header.layer_info.blend_info.clamp;
      frame_info.alpha_channel =
          input_frame->option_values.header.layer_info.blend_info.alpha;
      frame_info.extra_channel_blending_info.resize(
          metadata.m.num_extra_channels);
      // If extra channel blend info has not been set, use the blend mode from
      // the layer_info.
      JxlBlendInfo default_blend_info =
          input_frame->option_values.header.layer_info.blend_info;
      for (size_t i = 0; i < metadata.m.num_extra_channels; ++i) {
        auto& to = frame_info.extra_channel_blending_info[i];
        const auto& from =
            i < input_frame->option_values.extra_channel_blend_info.size()
                ? input_frame->option_values.extra_channel_blend_info[i]
                : default_blend_info;
        to.mode = static_cast<jxl::BlendMode>(from.blendmode);
        to.source = from.source;
        to.alpha_channel = from.alpha;
        to.clamp = (from.clamp != 0);
      }

      if (input_frame->option_values.header.layer_info.have_crop) {
        ib.origin.x0 = input_frame->option_values.header.layer_info.crop_x0;
        ib.origin.y0 = input_frame->option_values.header.layer_info.crop_y0;
      }
      JXL_ASSERT(writer.BitsWritten() == 0);
      if (!jxl::EncodeFrame(input_frame->option_values.cparams, frame_info,
                            &metadata, input_frame->frame, &enc_state, cms,
                            thread_pool.get(), &writer,
                            input_frame->option_values.aux_out)) {
        return JXL_API_ERROR(this, JXL_ENC_ERR_GENERIC,
                             "Failed to encode frame");
      }
      codestream_bytes_written_beginning_of_frame =
          codestream_bytes_written_end_of_frame;
      codestream_bytes_written_end_of_frame +=
          jxl::DivCeil(writer.BitsWritten(), 8);

      // Possibly bytes already contains the codestream header: in case this is
      // the first frame, and the codestream header was not encoded as jxlp
      // above.
      bytes.append(std::move(writer).TakeBytes());
      codestream_byte_size = bytes.size();
    } else {
      JXL_CHECK(!output_fast_frame_queue.empty());
      JxlFastLosslessPrepareHeader(output_fast_frame_queue.front().get(),
                                   /*add_image_header=*/0, last_frame);
      codestream_byte_size =
          JxlFastLosslessOutputSize(output_fast_frame_queue.front().get()) +
          bytes.size();
    }

    if (MustUseContainer()) {
      if (last_frame && jxlp_counter == 0) {
        // If this is the last frame and no jxlp boxes were used yet, it's
        // slighly more efficient to write a jxlc box since it has 4 bytes
        // less overhead.
        jxl::AppendBoxHeader(jxl::MakeBoxType("jxlc"), codestream_byte_size,
                             /*unbounded=*/false, &output_byte_queue);
      } else {
        jxl::AppendBoxHeader(jxl::MakeBoxType("jxlp"), codestream_byte_size + 4,
                             /*unbounded=*/false, &output_byte_queue);
        AppendJxlpBoxCounter(jxlp_counter++, last_frame, &output_byte_queue);
      }
    }

    output_byte_queue.insert(output_byte_queue.end(), bytes.data(),
                             bytes.data() + bytes.size());

    if (input_frame) {
      last_used_cparams = input_frame->option_values.cparams;
    }
    if (last_frame && frame_index_box.StoreFrameIndexBox()) {
      bytes.clear();
      EncodeFrameIndexBox(frame_index_box, writer);
      jxl::AppendBoxHeader(jxl::MakeBoxType("jxli"), bytes.size(),
                           /*unbounded=*/false, &output_byte_queue);
    }
  } else {
    // Not a frame, so is a box instead
    jxl::MemoryManagerUniquePtr<jxl::JxlEncoderQueuedBox> box =
        std::move(input.box);
    input_queue.erase(input_queue.begin());
    num_queued_boxes--;

    if (box->compress_box) {
      jxl::PaddedBytes compressed(4);
      // Prepend the original box type in the brob box contents
      for (size_t i = 0; i < 4; i++) {
        compressed[i] = static_cast<uint8_t>(box->type[i]);
      }
      if (JXL_ENC_SUCCESS !=
          BrotliCompress((brotli_effort >= 0 ? brotli_effort : 4),
                         box->contents.data(), box->contents.size(),
                         &compressed)) {
        return JXL_API_ERROR(this, JXL_ENC_ERR_GENERIC,
                             "Brotli compression for brob box failed");
      }
      jxl::AppendBoxHeader(jxl::MakeBoxType("brob"), compressed.size(), false,
                           &output_byte_queue);
      output_byte_queue.insert(output_byte_queue.end(), compressed.data(),
                               compressed.data() + compressed.size());
    } else {
      jxl::AppendBoxHeader(box->type, box->contents.size(), false,
                           &output_byte_queue);
      output_byte_queue.insert(output_byte_queue.end(), box->contents.data(),
                               box->contents.data() + box->contents.size());
    }
  }

  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetColorEncoding(JxlEncoder* enc,
                                            const JxlColorEncoding* color) {
  if (!enc->basic_info_set) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE, "Basic info not yet set");
  }
  if (enc->color_encoding_set) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "Color encoding is already set");
  }
  if (!jxl::ConvertExternalToInternalColorEncoding(
          *color, &enc->metadata.m.color_encoding)) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_GENERIC, "Error in color conversion");
  }
  if (enc->metadata.m.color_encoding.GetColorSpace() ==
      jxl::ColorSpace::kGray) {
    if (enc->basic_info.num_color_channels != 1)
      return JXL_API_ERROR(
          enc, JXL_ENC_ERR_API_USAGE,
          "Cannot use grayscale color encoding with num_color_channels != 1");
  } else {
    if (enc->basic_info.num_color_channels != 3)
      return JXL_API_ERROR(
          enc, JXL_ENC_ERR_API_USAGE,
          "Cannot use RGB color encoding with num_color_channels != 3");
  }
  enc->color_encoding_set = true;
  if (!enc->intensity_target_set) {
    jxl::SetIntensityTarget(&enc->metadata.m);
  }
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetICCProfile(JxlEncoder* enc,
                                         const uint8_t* icc_profile,
                                         size_t size) {
  if (!enc->basic_info_set) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE, "Basic info not yet set");
  }
  if (enc->color_encoding_set) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "ICC profile is already set");
  }
  jxl::PaddedBytes icc;
  icc.assign(icc_profile, icc_profile + size);
  if (!enc->metadata.m.color_encoding.SetICC(
          std::move(icc), enc->cms_set ? &enc->cms : nullptr)) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_BAD_INPUT,
                         "ICC profile could not be set");
  }
  if (enc->metadata.m.color_encoding.GetColorSpace() ==
      jxl::ColorSpace::kGray) {
    if (enc->basic_info.num_color_channels != 1)
      return JXL_API_ERROR(
          enc, JXL_ENC_ERR_BAD_INPUT,
          "Cannot use grayscale ICC profile with num_color_channels != 1");
  } else {
    if (enc->basic_info.num_color_channels != 3)
      return JXL_API_ERROR(
          enc, JXL_ENC_ERR_BAD_INPUT,
          "Cannot use RGB ICC profile with num_color_channels != 3");
    // TODO(jon): also check that a kBlack extra channel is provided in the CMYK
    // case
  }
  enc->color_encoding_set = true;
  if (!enc->intensity_target_set) {
    jxl::SetIntensityTarget(&enc->metadata.m);
  }

  if (!enc->basic_info.uses_original_profile && enc->cms_set) {
    enc->metadata.m.color_encoding.DecideIfWantICC(enc->cms);
  }

  return JXL_ENC_SUCCESS;
}

void JxlEncoderInitBasicInfo(JxlBasicInfo* info) {
  info->have_container = JXL_FALSE;
  info->xsize = 0;
  info->ysize = 0;
  info->bits_per_sample = 8;
  info->exponent_bits_per_sample = 0;
  info->intensity_target = 0.f;
  info->min_nits = 0.f;
  info->relative_to_max_display = JXL_FALSE;
  info->linear_below = 0.f;
  info->uses_original_profile = JXL_FALSE;
  info->have_preview = JXL_FALSE;
  info->have_animation = JXL_FALSE;
  info->orientation = JXL_ORIENT_IDENTITY;
  info->num_color_channels = 3;
  info->num_extra_channels = 0;
  info->alpha_bits = 0;
  info->alpha_exponent_bits = 0;
  info->alpha_premultiplied = JXL_FALSE;
  info->preview.xsize = 0;
  info->preview.ysize = 0;
  info->intrinsic_xsize = 0;
  info->intrinsic_ysize = 0;
  info->animation.tps_numerator = 10;
  info->animation.tps_denominator = 1;
  info->animation.num_loops = 0;
  info->animation.have_timecodes = JXL_FALSE;
}

void JxlEncoderInitFrameHeader(JxlFrameHeader* frame_header) {
  // For each field, the default value of the specification is used. Depending
  // on whether an animation frame, or a composite still blending frame,
  // is used, different fields have to be set up by the user after initing
  // the frame header.
  frame_header->duration = 0;
  frame_header->timecode = 0;
  frame_header->name_length = 0;
  // In the specification, the default value of is_last is !frame_type, and the
  // default frame_type is kRegularFrame which has value 0, so is_last is true
  // by default. However, the encoder does not use this value (the field exists
  // for the decoder to set) since last frame is determined by usage of
  // JxlEncoderCloseFrames instead.
  frame_header->is_last = JXL_TRUE;
  frame_header->layer_info.have_crop = JXL_FALSE;
  frame_header->layer_info.crop_x0 = 0;
  frame_header->layer_info.crop_y0 = 0;
  // These must be set if have_crop is enabled, but the default value has
  // have_crop false, and these dimensions 0. The user must set these to the
  // desired size after enabling have_crop (which is not yet implemented).
  frame_header->layer_info.xsize = 0;
  frame_header->layer_info.ysize = 0;
  JxlEncoderInitBlendInfo(&frame_header->layer_info.blend_info);
  frame_header->layer_info.save_as_reference = 0;
}

void JxlEncoderInitBlendInfo(JxlBlendInfo* blend_info) {
  // Default blend mode in the specification is 0. Note that combining
  // blend mode of replace with a duration is not useful, but the user has to
  // manually set duration in case of animation, or manually change the blend
  // mode in case of composite stills, so initing to a combination that is not
  // useful on its own is not an issue.
  blend_info->blendmode = JXL_BLEND_REPLACE;
  blend_info->source = 0;
  blend_info->alpha = 0;
  blend_info->clamp = 0;
}

JxlEncoderStatus JxlEncoderSetBasicInfo(JxlEncoder* enc,
                                        const JxlBasicInfo* info) {
  if (!enc->metadata.size.Set(info->xsize, info->ysize)) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE, "Invalid dimensions");
  }
  if (JXL_ENC_SUCCESS != CheckValidBitdepth(info->bits_per_sample,
                                            info->exponent_bits_per_sample)) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE, "Invalid bit depth");
  }

  enc->metadata.m.bit_depth.bits_per_sample = info->bits_per_sample;
  enc->metadata.m.bit_depth.exponent_bits_per_sample =
      info->exponent_bits_per_sample;
  enc->metadata.m.bit_depth.floating_point_sample =
      (info->exponent_bits_per_sample != 0u);
  enc->metadata.m.modular_16_bit_buffer_sufficient =
      (!info->uses_original_profile || info->bits_per_sample <= 12) &&
      info->alpha_bits <= 12;
  if ((info->intrinsic_xsize > 0 || info->intrinsic_ysize > 0) &&
      (info->intrinsic_xsize != info->xsize ||
       info->intrinsic_ysize != info->ysize)) {
    if (info->intrinsic_xsize > (1ull << 30ull) ||
        info->intrinsic_ysize > (1ull << 30ull) ||
        !enc->metadata.m.intrinsic_size.Set(info->intrinsic_xsize,
                                            info->intrinsic_ysize)) {
      return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                           "Invalid intrinsic dimensions");
    }
    enc->metadata.m.have_intrinsic_size = true;
  }

  // The number of extra channels includes the alpha channel, so for example and
  // RGBA with no other extra channels, has exactly num_extra_channels == 1
  enc->metadata.m.num_extra_channels = info->num_extra_channels;
  enc->metadata.m.extra_channel_info.resize(enc->metadata.m.num_extra_channels);
  if (info->num_extra_channels == 0 && info->alpha_bits) {
    return JXL_API_ERROR(
        enc, JXL_ENC_ERR_API_USAGE,
        "when alpha_bits is non-zero, the number of channels must be at least "
        "1");
  }
  // If the user provides non-zero alpha_bits, we make the channel info at index
  // zero the appropriate alpha channel.
  if (info->alpha_bits) {
    JxlExtraChannelInfo channel_info;
    JxlEncoderInitExtraChannelInfo(JXL_CHANNEL_ALPHA, &channel_info);
    channel_info.bits_per_sample = info->alpha_bits;
    channel_info.exponent_bits_per_sample = info->alpha_exponent_bits;
    if (JxlEncoderSetExtraChannelInfo(enc, 0, &channel_info)) {
      return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                           "Problem setting extra channel info for alpha");
    }
  }

  enc->metadata.m.xyb_encoded = !info->uses_original_profile;
  if (info->orientation > 0 && info->orientation <= 8) {
    enc->metadata.m.orientation = info->orientation;
  } else {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid value for orientation field");
  }
  if (info->num_color_channels != 1 && info->num_color_channels != 3) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid number of color channels");
  }
  if (info->intensity_target != 0) {
    enc->metadata.m.SetIntensityTarget(info->intensity_target);
    enc->intensity_target_set = true;
  } else if (enc->color_encoding_set) {
    // If this is false, JxlEncoderSetColorEncoding will be called later and we
    // will get one more chance to call jxl::SetIntensityTarget, after the color
    // encoding is indeed set.
    jxl::SetIntensityTarget(&enc->metadata.m);
    enc->intensity_target_set = true;
  }
  enc->metadata.m.tone_mapping.min_nits = info->min_nits;
  enc->metadata.m.tone_mapping.relative_to_max_display =
      info->relative_to_max_display;
  enc->metadata.m.tone_mapping.linear_below = info->linear_below;
  enc->basic_info = *info;
  enc->basic_info_set = true;

  enc->metadata.m.have_animation = info->have_animation;
  if (info->have_animation) {
    if (info->animation.tps_denominator < 1) {
      return JXL_API_ERROR(
          enc, JXL_ENC_ERR_API_USAGE,
          "If animation is used, tps_denominator must be >= 1");
    }
    if (info->animation.tps_numerator < 1) {
      return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                           "If animation is used, tps_numerator must be >= 1");
    }
    enc->metadata.m.animation.tps_numerator = info->animation.tps_numerator;
    enc->metadata.m.animation.tps_denominator = info->animation.tps_denominator;
    enc->metadata.m.animation.num_loops = info->animation.num_loops;
    enc->metadata.m.animation.have_timecodes = info->animation.have_timecodes;
  }
  std::string level_message;
  int required_level = VerifyLevelSettings(enc, &level_message);
  if (required_level == -1 ||
      (static_cast<int>(enc->codestream_level) < required_level &&
       enc->codestream_level != -1)) {
    return JXL_API_ERROR(
        enc, JXL_ENC_ERR_API_USAGE, "%s",
        ("Codestream level verification for level " +
         std::to_string(enc->codestream_level) + " failed: " + level_message)
            .c_str());
  }
  return JXL_ENC_SUCCESS;
}

void JxlEncoderInitExtraChannelInfo(JxlExtraChannelType type,
                                    JxlExtraChannelInfo* info) {
  info->type = type;
  info->bits_per_sample = 8;
  info->exponent_bits_per_sample = 0;
  info->dim_shift = 0;
  info->name_length = 0;
  info->alpha_premultiplied = JXL_FALSE;
  info->spot_color[0] = 0;
  info->spot_color[1] = 0;
  info->spot_color[2] = 0;
  info->spot_color[3] = 0;
  info->cfa_channel = 0;
}

JXL_EXPORT JxlEncoderStatus JxlEncoderSetUpsamplingMode(JxlEncoder* enc,
                                                        const int64_t factor,
                                                        const int64_t mode) {
  // for convenience, allow calling this with factor 1 and just make it a no-op
  if (factor == 1) return JXL_ENC_SUCCESS;
  if (factor != 2 && factor != 4 && factor != 8)
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid upsampling factor");
  if (mode < -1)
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE, "Invalid upsampling mode");
  if (mode > 1)
    return JXL_API_ERROR(enc, JXL_ENC_ERR_NOT_SUPPORTED,
                         "Unsupported upsampling mode");

  const size_t count = (factor == 2 ? 15 : (factor == 4 ? 55 : 210));
  auto& td = enc->metadata.transform_data;
  float* weights = (factor == 2 ? td.upsampling2_weights
                                : (factor == 4 ? td.upsampling4_weights
                                               : td.upsampling8_weights));
  if (mode == -1) {
    // Default fancy upsampling: don't signal custom weights
    enc->metadata.transform_data.custom_weights_mask &= ~(factor >> 1);
  } else if (mode == 0) {
    // Nearest neighbor upsampling
    enc->metadata.transform_data.custom_weights_mask |= (factor >> 1);
    memset(weights, 0, sizeof(float) * count);
    if (factor == 2) {
      weights[9] = 1.f;
    } else if (factor == 4) {
      for (int i : {19, 24, 49}) weights[i] = 1.f;
    } else if (factor == 8) {
      for (int i : {39, 44, 49, 54, 119, 124, 129, 174, 179, 204}) {
        weights[i] = 1.f;
      }
    }
  } else if (mode == 1) {
    // 'Pixel dots' upsampling (nearest-neighbor with cut corners)
    JxlEncoderSetUpsamplingMode(enc, factor, 0);
    if (factor == 4) {
      weights[19] = 0.f;
      weights[24] = 0.5f;
    } else if (factor == 8) {
      for (int i : {39, 44, 49, 119}) weights[i] = 0.f;
      for (int i : {54, 124}) weights[i] = 0.5f;
    }
  }
  return JXL_ENC_SUCCESS;
}

JXL_EXPORT JxlEncoderStatus JxlEncoderSetExtraChannelInfo(
    JxlEncoder* enc, size_t index, const JxlExtraChannelInfo* info) {
  if (index >= enc->metadata.m.num_extra_channels) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid value for the index of extra channel");
  }
  if (JXL_ENC_SUCCESS != CheckValidBitdepth(info->bits_per_sample,
                                            info->exponent_bits_per_sample)) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE, "Invalid bit depth");
  }

  jxl::ExtraChannelInfo& channel = enc->metadata.m.extra_channel_info[index];
  channel.type = static_cast<jxl::ExtraChannel>(info->type);
  channel.bit_depth.bits_per_sample = info->bits_per_sample;
  enc->metadata.m.modular_16_bit_buffer_sufficient &=
      info->bits_per_sample <= 12;
  channel.bit_depth.exponent_bits_per_sample = info->exponent_bits_per_sample;
  channel.bit_depth.floating_point_sample = info->exponent_bits_per_sample != 0;
  channel.dim_shift = info->dim_shift;
  channel.name = "";
  channel.alpha_associated = (info->alpha_premultiplied != 0);
  channel.cfa_channel = info->cfa_channel;
  channel.spot_color[0] = info->spot_color[0];
  channel.spot_color[1] = info->spot_color[1];
  channel.spot_color[2] = info->spot_color[2];
  channel.spot_color[3] = info->spot_color[3];
  std::string level_message;
  int required_level = VerifyLevelSettings(enc, &level_message);
  if (required_level == -1 ||
      (static_cast<int>(enc->codestream_level) < required_level &&
       enc->codestream_level != -1)) {
    return JXL_API_ERROR(
        enc, JXL_ENC_ERR_API_USAGE, "%s",
        ("Codestream level verification for level " +
         std::to_string(enc->codestream_level) + " failed: " + level_message)
            .c_str());
  }
  return JXL_ENC_SUCCESS;
}

JXL_EXPORT JxlEncoderStatus JxlEncoderSetExtraChannelName(JxlEncoder* enc,
                                                          size_t index,
                                                          const char* name,
                                                          size_t size) {
  if (index >= enc->metadata.m.num_extra_channels) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid value for the index of extra channel");
  }
  enc->metadata.m.extra_channel_info[index].name =
      std::string(name, name + size);
  return JXL_ENC_SUCCESS;
}

JxlEncoderFrameSettings* JxlEncoderFrameSettingsCreate(
    JxlEncoder* enc, const JxlEncoderFrameSettings* source) {
  auto opts = jxl::MemoryManagerMakeUnique<JxlEncoderFrameSettings>(
      &enc->memory_manager);
  if (!opts) return nullptr;
  opts->enc = enc;
  if (source != nullptr) {
    opts->values = source->values;
  } else {
    opts->values.lossless = false;
  }
  opts->values.cparams.level = enc->codestream_level;
  opts->values.cparams.ec_distance.resize(enc->metadata.m.num_extra_channels,
                                          -1);

  JxlEncoderFrameSettings* ret = opts.get();
  enc->encoder_options.emplace_back(std::move(opts));
  return ret;
}

JxlEncoderStatus JxlEncoderSetFrameLossless(
    JxlEncoderFrameSettings* frame_settings, const JXL_BOOL lossless) {
  if (lossless && frame_settings->enc->basic_info_set &&
      frame_settings->enc->metadata.m.xyb_encoded) {
    return JXL_API_ERROR(
        frame_settings->enc, JXL_ENC_ERR_API_USAGE,
        "Set uses_original_profile=true for lossless encoding");
  }
  frame_settings->values.lossless = lossless;
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetFrameDistance(
    JxlEncoderFrameSettings* frame_settings, float distance) {
  if (distance < 0.f || distance > 25.f) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Distance has to be in [0.0..25.0] (corresponding to "
                         "quality in [0.0..100.0])");
  }
  if (distance > 0.f && distance < 0.01f) {
    distance = 0.01f;
  }
  frame_settings->values.cparams.butteraugli_distance = distance;
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetExtraChannelDistance(
    JxlEncoderFrameSettings* frame_settings, size_t index, float distance) {
  if (index >= frame_settings->enc->metadata.m.num_extra_channels) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid value for the index of extra channel");
  }
  if (distance != -1.f && (distance < 0.f || distance > 25.f)) {
    return JXL_API_ERROR(
        frame_settings->enc, JXL_ENC_ERR_API_USAGE,
        "Distance has to be -1 or in [0.0..25.0] (corresponding to "
        "quality in [0.0..100.0])");
  }
  if (distance > 0.f && distance < 0.01f) {
    distance = 0.01f;
  }

  if (index >= frame_settings->values.cparams.ec_distance.size()) {
    // This can only happen if JxlEncoderFrameSettingsCreate() was called before
    // JxlEncoderSetBasicInfo().
    frame_settings->values.cparams.ec_distance.resize(
        frame_settings->enc->metadata.m.num_extra_channels, -1);
  }

  frame_settings->values.cparams.ec_distance[index] = distance;
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderFrameSettingsSetOption(
    JxlEncoderFrameSettings* frame_settings, JxlEncoderFrameSettingId option,
    int64_t value) {
  // check if value is -1, 0 or 1 for Override-type options
  switch (option) {
    case JXL_ENC_FRAME_SETTING_NOISE:
    case JXL_ENC_FRAME_SETTING_DOTS:
    case JXL_ENC_FRAME_SETTING_PATCHES:
    case JXL_ENC_FRAME_SETTING_GABORISH:
    case JXL_ENC_FRAME_SETTING_MODULAR:
    case JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE:
    case JXL_ENC_FRAME_SETTING_GROUP_ORDER:
    case JXL_ENC_FRAME_SETTING_RESPONSIVE:
    case JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC:
    case JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC:
    case JXL_ENC_FRAME_SETTING_LOSSY_PALETTE:
    case JXL_ENC_FRAME_SETTING_JPEG_RECON_CFL:
    case JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES:
      if (value < -1 || value > 1) {
        return JXL_API_ERROR(
            frame_settings->enc, JXL_ENC_ERR_API_USAGE,
            "Option value has to be -1 (default), 0 (off) or 1 (on)");
      }
      break;
    default:
      break;
  }

  switch (option) {
    case JXL_ENC_FRAME_SETTING_EFFORT:
      if (frame_settings->enc->allow_expert_options) {
        if (value < 1 || value > 10) {
          return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                               "Encode effort has to be in [1..10]");
        }
      } else {
        if (value < 1 || value > 9) {
          return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                               "Encode effort has to be in [1..9]");
        }
      }
      frame_settings->values.cparams.speed_tier =
          static_cast<jxl::SpeedTier>(10 - value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_BROTLI_EFFORT:
      if (value < -1 || value > 11) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Brotli effort has to be in [-1..11]");
      }
      // set cparams for brotli use in JPEG frames
      frame_settings->values.cparams.brotli_effort = value;
      // set enc option for brotli use in brob boxes
      frame_settings->enc->brotli_effort = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_DECODING_SPEED:
      if (value < 0 || value > 4) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                             "Decoding speed has to be in [0..4]");
      }
      frame_settings->values.cparams.decoding_speed_tier = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_RESAMPLING:
      if (value != -1 && value != 1 && value != 2 && value != 4 && value != 8) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Resampling factor has to be 1, 2, 4 or 8");
      }
      frame_settings->values.cparams.resampling = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING:
      // TODO(lode): the jxl codestream allows choosing a different resampling
      // factor for each extra channel, independently per frame. Move this
      // option to a JxlEncoderFrameSettings-option that can be set per extra
      // channel, so needs its own function rather than
      // JxlEncoderFrameSettingsSetOption due to the extra channel index
      // argument required.
      if (value != -1 && value != 1 && value != 2 && value != 4 && value != 8) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Resampling factor has to be 1, 2, 4 or 8");
      }
      frame_settings->values.cparams.ec_resampling = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_ALREADY_DOWNSAMPLED:
      if (value < 0 || value > 1) {
        return JXL_ENC_ERROR;
      }
      frame_settings->values.cparams.already_downsampled = (value == 1);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_NOISE:
      frame_settings->values.cparams.noise = static_cast<jxl::Override>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_DOTS:
      frame_settings->values.cparams.dots = static_cast<jxl::Override>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_PATCHES:
      frame_settings->values.cparams.patches =
          static_cast<jxl::Override>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_EPF:
      if (value < -1 || value > 3) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "EPF value has to be in [-1..3]");
      }
      frame_settings->values.cparams.epf = static_cast<int>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_GABORISH:
      frame_settings->values.cparams.gaborish =
          static_cast<jxl::Override>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_MODULAR:
      frame_settings->values.cparams.modular_mode = (value == 1);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE:
      frame_settings->values.cparams.keep_invisible =
          static_cast<jxl::Override>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_GROUP_ORDER:
      frame_settings->values.cparams.centerfirst = (value == 1);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_X:
      if (value < -1) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Center x coordinate has to be -1 or positive");
      }
      frame_settings->values.cparams.center_x = static_cast<size_t>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_Y:
      if (value < -1) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Center y coordinate has to be -1 or positive");
      }
      frame_settings->values.cparams.center_y = static_cast<size_t>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_RESPONSIVE:
      frame_settings->values.cparams.responsive = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC:
      frame_settings->values.cparams.progressive_mode = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC:
      frame_settings->values.cparams.qprogressive_mode = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC:
      if (value < -1 || value > 2) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Progressive DC has to be in [-1..2]");
      }
      frame_settings->values.cparams.progressive_dc = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_PALETTE_COLORS:
      if (value < -1 || value > 70913) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..70913]");
      }
      if (value == -1) {
        frame_settings->values.cparams.palette_colors = 1 << 10;
      } else {
        frame_settings->values.cparams.palette_colors = value;
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_LOSSY_PALETTE:
      // TODO(lode): the defaults of some palette settings depend on others.
      // See the logic in cjxl. Similar for other settings. This should be
      // handled in the encoder during JxlEncoderProcessOutput (or,
      // alternatively, in the cjxl binary like now)
      frame_settings->values.cparams.lossy_palette = (value == 1);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM:
      if (value < -1 || value > 2) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..2]");
      }
      if (value == -1) {
        frame_settings->values.cparams.color_transform =
            jxl::ColorTransform::kXYB;
      } else {
        frame_settings->values.cparams.color_transform =
            static_cast<jxl::ColorTransform>(value);
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE:
      if (value < -1 || value > 41) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..41]");
      }
      frame_settings->values.cparams.colorspace = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_MODULAR_GROUP_SIZE:
      if (value < -1 || value > 3) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..3]");
      }
      frame_settings->values.cparams.modular_group_size_shift = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR:
      if (value < -1 || value > 15) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..15]");
      }
      frame_settings->values.cparams.options.predictor =
          static_cast<jxl::Predictor>(value);
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS:
      // The max allowed value can in theory be higher. However, it depends on
      // the effort setting. 11 is the highest safe value that doesn't cause
      // tree_samples to be >= 64 in the encoder. The specification may allow
      // more than this. With more fine tuning higher values could be allowed.
      // For N-channel images, the largest useful value is N-1.
      if (value < -1 || value > 11) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..11]");
      }
      if (value == -1) {
        frame_settings->values.cparams.options.max_properties = 0;
      } else {
        frame_settings->values.cparams.options.max_properties = value;
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_JPEG_RECON_CFL:
      if (value == -1) {
        frame_settings->values.cparams.force_cfl_jpeg_recompression = true;
      } else {
        frame_settings->values.cparams.force_cfl_jpeg_recompression = value;
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_INDEX_BOX:
      frame_settings->values.frame_index_box = true;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_PHOTON_NOISE:
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                           "Float option, try setting it with "
                           "JxlEncoderFrameSettingsSetFloatOption");
    case JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES:
      frame_settings->values.cparams.jpeg_compress_boxes = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_BUFFERING:
      if (value < 0 || value > 3) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                             "Buffering has to be in [0..3]");
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_JPEG_KEEP_EXIF:
      frame_settings->values.cparams.jpeg_keep_exif = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_JPEG_KEEP_XMP:
      frame_settings->values.cparams.jpeg_keep_xmp = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_JPEG_KEEP_JUMBF:
      frame_settings->values.cparams.jpeg_keep_jumbf = value;
      return JXL_ENC_SUCCESS;

    default:
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                           "Unknown option");
  }
}

JxlEncoderStatus JxlEncoderFrameSettingsSetFloatOption(
    JxlEncoderFrameSettings* frame_settings, JxlEncoderFrameSettingId option,
    float value) {
  switch (option) {
    case JXL_ENC_FRAME_SETTING_PHOTON_NOISE:
      if (value < 0) return JXL_ENC_ERROR;
      // TODO(lode): add encoder setting to set the 8 floating point values of
      // the noise synthesis parameters per frame for more fine grained control.
      frame_settings->values.cparams.photon_noise_iso = value;
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT:
      if (value < -1.f || value > 100.f) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be smaller than 100");
      }
      // This value is called "iterations" or "nb_repeats" in cjxl, but is in
      // fact a fraction in range 0.0-1.0, with the default value 0.5.
      // Convert from floating point percentage to floating point fraction here.
      if (value < -.5f) {
        // TODO(lode): for this and many other settings (also in
        // JxlEncoderFrameSettingsSetOption), avoid duplicating the default
        // values here and in enc_params.h and options.h, have one location
        // where the defaults are specified.
        frame_settings->values.cparams.options.nb_repeats = 0.5f;
      } else {
        frame_settings->values.cparams.options.nb_repeats = value * 0.01f;
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GLOBAL_PERCENT:
      if (value < -1.f || value > 100.f) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..100]");
      }
      if (value < -.5f) {
        frame_settings->values.cparams.channel_colors_pre_transform_percent =
            95.0f;
      } else {
        frame_settings->values.cparams.channel_colors_pre_transform_percent =
            value;
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GROUP_PERCENT:
      if (value < -1.f || value > 100.f) {
        return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                             "Option value has to be in [-1..100]");
      }
      if (value < -.5f) {
        frame_settings->values.cparams.channel_colors_percent = 80.0f;
      } else {
        frame_settings->values.cparams.channel_colors_percent = value;
      }
      return JXL_ENC_SUCCESS;
    case JXL_ENC_FRAME_SETTING_EFFORT:
    case JXL_ENC_FRAME_SETTING_DECODING_SPEED:
    case JXL_ENC_FRAME_SETTING_RESAMPLING:
    case JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING:
    case JXL_ENC_FRAME_SETTING_ALREADY_DOWNSAMPLED:
    case JXL_ENC_FRAME_SETTING_NOISE:
    case JXL_ENC_FRAME_SETTING_DOTS:
    case JXL_ENC_FRAME_SETTING_PATCHES:
    case JXL_ENC_FRAME_SETTING_EPF:
    case JXL_ENC_FRAME_SETTING_GABORISH:
    case JXL_ENC_FRAME_SETTING_MODULAR:
    case JXL_ENC_FRAME_SETTING_KEEP_INVISIBLE:
    case JXL_ENC_FRAME_SETTING_GROUP_ORDER:
    case JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_X:
    case JXL_ENC_FRAME_SETTING_GROUP_ORDER_CENTER_Y:
    case JXL_ENC_FRAME_SETTING_RESPONSIVE:
    case JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC:
    case JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC:
    case JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC:
    case JXL_ENC_FRAME_SETTING_PALETTE_COLORS:
    case JXL_ENC_FRAME_SETTING_LOSSY_PALETTE:
    case JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM:
    case JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE:
    case JXL_ENC_FRAME_SETTING_MODULAR_GROUP_SIZE:
    case JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR:
    case JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS:
    case JXL_ENC_FRAME_SETTING_JPEG_RECON_CFL:
    case JXL_ENC_FRAME_INDEX_BOX:
    case JXL_ENC_FRAME_SETTING_BROTLI_EFFORT:
    case JXL_ENC_FRAME_SETTING_FILL_ENUM:
    case JXL_ENC_FRAME_SETTING_JPEG_COMPRESS_BOXES:
    case JXL_ENC_FRAME_SETTING_BUFFERING:
    case JXL_ENC_FRAME_SETTING_JPEG_KEEP_EXIF:
    case JXL_ENC_FRAME_SETTING_JPEG_KEEP_XMP:
    case JXL_ENC_FRAME_SETTING_JPEG_KEEP_JUMBF:
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                           "Int option, try setting it with "
                           "JxlEncoderFrameSettingsSetOption");
    default:
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_NOT_SUPPORTED,
                           "Unknown option");
  }
}
JxlEncoder* JxlEncoderCreate(const JxlMemoryManager* memory_manager) {
  JxlMemoryManager local_memory_manager;
  if (!jxl::MemoryManagerInit(&local_memory_manager, memory_manager)) {
    return nullptr;
  }

  void* alloc =
      jxl::MemoryManagerAlloc(&local_memory_manager, sizeof(JxlEncoder));
  if (!alloc) return nullptr;
  JxlEncoder* enc = new (alloc) JxlEncoder();
  enc->memory_manager = local_memory_manager;
  // TODO(sboukortt): add an API function to set this.
  enc->cms = jxl::GetJxlCms();
  enc->cms_set = true;

  // Initialize all the field values.
  JxlEncoderReset(enc);

  return enc;
}

void JxlEncoderReset(JxlEncoder* enc) {
  enc->thread_pool.reset();
  enc->input_queue.clear();
  enc->num_queued_frames = 0;
  enc->num_queued_boxes = 0;
  enc->encoder_options.clear();
  enc->output_byte_queue.clear();
  enc->output_fast_frame_queue.clear();
  enc->codestream_bytes_written_beginning_of_frame = 0;
  enc->codestream_bytes_written_end_of_frame = 0;
  enc->wrote_bytes = false;
  enc->jxlp_counter = 0;
  enc->metadata = jxl::CodecMetadata();
  enc->last_used_cparams = jxl::CompressParams();
  enc->frames_closed = false;
  enc->boxes_closed = false;
  enc->basic_info_set = false;
  enc->color_encoding_set = false;
  enc->intensity_target_set = false;
  enc->use_container = false;
  enc->use_boxes = false;
  enc->codestream_level = -1;
  JxlEncoderInitBasicInfo(&enc->basic_info);
}

void JxlEncoderDestroy(JxlEncoder* enc) {
  if (enc) {
    JxlMemoryManager local_memory_manager = enc->memory_manager;
    // Call destructor directly since custom free function is used.
    enc->~JxlEncoder();
    jxl::MemoryManagerFree(&local_memory_manager, enc);
  }
}

JxlEncoderError JxlEncoderGetError(JxlEncoder* enc) { return enc->error; }

JxlEncoderStatus JxlEncoderUseContainer(JxlEncoder* enc,
                                        JXL_BOOL use_container) {
  if (enc->wrote_bytes) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "this setting can only be set at the beginning");
  }
  enc->use_container = static_cast<bool>(use_container);
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderStoreJPEGMetadata(JxlEncoder* enc,
                                             JXL_BOOL store_jpeg_metadata) {
  if (enc->wrote_bytes) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "this setting can only be set at the beginning");
  }
  enc->store_jpeg_metadata = static_cast<bool>(store_jpeg_metadata);
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetCodestreamLevel(JxlEncoder* enc, int level) {
  if (level != -1 && level != 5 && level != 10) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_NOT_SUPPORTED, "invalid level");
  }
  if (enc->wrote_bytes) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "this setting can only be set at the beginning");
  }
  enc->codestream_level = level;
  return JXL_ENC_SUCCESS;
}

int JxlEncoderGetRequiredCodestreamLevel(const JxlEncoder* enc) {
  return VerifyLevelSettings(enc, nullptr);
}

void JxlEncoderSetCms(JxlEncoder* enc, JxlCmsInterface cms) {
  jxl::msan::MemoryIsInitialized(&cms, sizeof(cms));
  enc->cms = cms;
  enc->cms_set = true;
}

JxlEncoderStatus JxlEncoderSetParallelRunner(JxlEncoder* enc,
                                             JxlParallelRunner parallel_runner,
                                             void* parallel_runner_opaque) {
  if (enc->thread_pool) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "parallel runner already set");
  }
  enc->thread_pool = jxl::MemoryManagerMakeUnique<jxl::ThreadPool>(
      &enc->memory_manager, parallel_runner, parallel_runner_opaque);
  if (!enc->thread_pool) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_GENERIC,
                         "error setting parallel runner");
  }
  return JXL_ENC_SUCCESS;
}

namespace {
JxlEncoderStatus GetCurrentDimensions(
    const JxlEncoderFrameSettings* frame_settings, size_t& xsize,
    size_t& ysize) {
  xsize = frame_settings->enc->metadata.xsize();
  ysize = frame_settings->enc->metadata.ysize();
  if (frame_settings->values.header.layer_info.have_crop) {
    xsize = frame_settings->values.header.layer_info.xsize;
    ysize = frame_settings->values.header.layer_info.ysize;
  }
  if (frame_settings->values.cparams.already_downsampled) {
    size_t factor = frame_settings->values.cparams.resampling;
    xsize = jxl::DivCeil(xsize, factor);
    ysize = jxl::DivCeil(ysize, factor);
  }
  if (xsize == 0 || ysize == 0) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "zero-sized frame is not allowed");
  }
  return JXL_ENC_SUCCESS;
}
}  // namespace

JxlEncoderStatus JxlEncoderAddJPEGFrame(
    const JxlEncoderFrameSettings* frame_settings, const uint8_t* buffer,
    size_t size) {
  if (frame_settings->enc->frames_closed) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Frame input is already closed");
  }

  jxl::CodecInOut io;
  if (!jxl::jpeg::DecodeImageJPG(jxl::Span<const uint8_t>(buffer, size), &io)) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_BAD_INPUT,
                         "Error during decode of input JPEG");
  }

  if (!frame_settings->enc->color_encoding_set) {
    if (!SetColorEncodingFromJpegData(
            *io.Main().jpeg_data,
            &frame_settings->enc->metadata.m.color_encoding)) {
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_BAD_INPUT,
                           "Error in input JPEG color space");
    }
  }

  if (!frame_settings->enc->basic_info_set) {
    JxlBasicInfo basic_info;
    JxlEncoderInitBasicInfo(&basic_info);
    basic_info.xsize = io.Main().jpeg_data->width;
    basic_info.ysize = io.Main().jpeg_data->height;
    basic_info.uses_original_profile = true;
    if (JxlEncoderSetBasicInfo(frame_settings->enc, &basic_info) !=
        JXL_ENC_SUCCESS) {
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                           "Error setting basic info");
    }
  }

  if (frame_settings->enc->metadata.m.xyb_encoded) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Can't XYB encode a lossless JPEG");
  }
  if (!io.blobs.exif.empty()) {
    JxlOrientation orientation = static_cast<JxlOrientation>(
        frame_settings->enc->metadata.m.orientation);
    jxl::InterpretExif(io.blobs.exif, &orientation);
    frame_settings->enc->metadata.m.orientation = orientation;
  }
  if (!io.blobs.exif.empty() && frame_settings->values.cparams.jpeg_keep_exif) {
    size_t exif_size = io.blobs.exif.size();
    // Exif data in JPEG is limited to 64k
    if (exif_size > 0xFFFF) {
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                           "Exif larger than possible in JPEG?");
    }
    exif_size += 4;  // prefix 4 zero bytes for tiff offset
    std::vector<uint8_t> exif(exif_size);
    memcpy(exif.data() + 4, io.blobs.exif.data(), io.blobs.exif.size());
    JxlEncoderUseBoxes(frame_settings->enc);
    JxlEncoderAddBox(frame_settings->enc, "Exif", exif.data(), exif_size,
                     frame_settings->values.cparams.jpeg_compress_boxes);
  }
  if (!io.blobs.xmp.empty() && frame_settings->values.cparams.jpeg_keep_xmp) {
    JxlEncoderUseBoxes(frame_settings->enc);
    JxlEncoderAddBox(frame_settings->enc, "xml ", io.blobs.xmp.data(),
                     io.blobs.xmp.size(),
                     frame_settings->values.cparams.jpeg_compress_boxes);
  }
  if (!io.blobs.jumbf.empty() &&
      frame_settings->values.cparams.jpeg_keep_jumbf) {
    JxlEncoderUseBoxes(frame_settings->enc);
    JxlEncoderAddBox(frame_settings->enc, "jumb", io.blobs.jumbf.data(),
                     io.blobs.jumbf.size(),
                     frame_settings->values.cparams.jpeg_compress_boxes);
  }
  if (frame_settings->enc->store_jpeg_metadata) {
    if (!frame_settings->values.cparams.jpeg_keep_exif ||
        !frame_settings->values.cparams.jpeg_keep_xmp) {
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                           "Need to preserve EXIF and XMP to allow JPEG "
                           "bitstream reconstruction");
    }
    jxl::jpeg::JPEGData data_in = *io.Main().jpeg_data;
    jxl::PaddedBytes jpeg_data;
    if (!jxl::jpeg::EncodeJPEGData(data_in, &jpeg_data,
                                   frame_settings->values.cparams)) {
      return JXL_API_ERROR(
          frame_settings->enc, JXL_ENC_ERR_JBRD,
          "JPEG bitstream reconstruction data cannot be encoded");
    }
    frame_settings->enc->jpeg_metadata = std::vector<uint8_t>(
        jpeg_data.data(), jpeg_data.data() + jpeg_data.size());
  }

  auto queued_frame = jxl::MemoryManagerMakeUnique<jxl::JxlEncoderQueuedFrame>(
      &frame_settings->enc->memory_manager,
      // JxlEncoderQueuedFrame is a struct with no constructors, so we use the
      // default move constructor there.
      jxl::JxlEncoderQueuedFrame{
          frame_settings->values,
          jxl::ImageBundle(&frame_settings->enc->metadata.m),
          {}});
  if (!queued_frame) {
    // TODO(jon): when can this happen? is this an API usage error?
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                         "No frame queued?");
  }
  queued_frame->frame.SetFromImage(std::move(*io.Main().color()),
                                   io.Main().c_current());
  size_t xsize, ysize;
  if (GetCurrentDimensions(frame_settings, xsize, ysize) != JXL_ENC_SUCCESS) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                         "bad dimensions");
  }
  if (xsize != static_cast<size_t>(io.Main().jpeg_data->width) ||
      ysize != static_cast<size_t>(io.Main().jpeg_data->height)) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                         "JPEG dimensions don't match frame dimensions");
  }
  std::vector<jxl::ImageF> extra_channels(
      frame_settings->enc->metadata.m.num_extra_channels);
  for (auto& extra_channel : extra_channels) {
    extra_channel = jxl::ImageF(xsize, ysize);
    queued_frame->ec_initialized.push_back(0);
  }
  queued_frame->frame.SetExtraChannels(std::move(extra_channels));
  queued_frame->frame.jpeg_data = std::move(io.Main().jpeg_data);
  queued_frame->frame.color_transform = io.Main().color_transform;
  queued_frame->frame.chroma_subsampling = io.Main().chroma_subsampling;

  QueueFrame(frame_settings, queued_frame);
  return JXL_ENC_SUCCESS;
}

static bool CanDoFastLossless(const JxlEncoderFrameSettings* frame_settings,
                              const JxlPixelFormat* pixel_format,
                              bool has_alpha) {
  if (!frame_settings->values.lossless) {
    return false;
  }
  // TODO(veluca): many of the following options could be made to work, but are
  // just not implemented in FJXL's frame header handling yet.
  if (frame_settings->values.frame_index_box) {
    return false;
  }
  if (frame_settings->values.header.layer_info.have_crop) {
    return false;
  }
  if (frame_settings->enc->metadata.m.have_animation) {
    return false;
  }
  if (frame_settings->values.cparams.speed_tier != jxl::SpeedTier::kLightning) {
    return false;
  }
  if (frame_settings->values.image_bit_depth.type ==
          JxlBitDepthType::JXL_BIT_DEPTH_CUSTOM &&
      frame_settings->values.image_bit_depth.bits_per_sample !=
          frame_settings->enc->metadata.m.bit_depth.bits_per_sample) {
    return false;
  }
  // TODO(veluca): implement support for LSB-padded input in fast_lossless.
  if (frame_settings->values.image_bit_depth.type ==
          JxlBitDepthType::JXL_BIT_DEPTH_FROM_PIXEL_FORMAT &&
      frame_settings->values.image_bit_depth.bits_per_sample % 8 != 0) {
    return false;
  }
  if (!frame_settings->values.frame_name.empty()) {
    return false;
  }
  // No extra channels other than alpha.
  if (!(has_alpha && frame_settings->enc->metadata.m.num_extra_channels == 1) &&
      frame_settings->enc->metadata.m.num_extra_channels != 0) {
    return false;
  }
  if (frame_settings->enc->metadata.m.bit_depth.bits_per_sample > 16) {
    return false;
  }
  if (pixel_format->data_type != JxlDataType::JXL_TYPE_FLOAT16 &&
      pixel_format->data_type != JxlDataType::JXL_TYPE_UINT16 &&
      pixel_format->data_type != JxlDataType::JXL_TYPE_UINT8) {
    return false;
  }
  if ((frame_settings->enc->metadata.m.bit_depth.bits_per_sample > 8) !=
      (pixel_format->data_type == JxlDataType::JXL_TYPE_UINT16 ||
       pixel_format->data_type == JxlDataType::JXL_TYPE_FLOAT16)) {
    return false;
  }
  if (!((pixel_format->num_channels == 1 || pixel_format->num_channels == 3) &&
        !has_alpha) &&
      !((pixel_format->num_channels == 2 || pixel_format->num_channels == 4) &&
        has_alpha)) {
    return false;
  }

  return true;
}

JxlEncoderStatus JxlEncoderAddImageFrame(
    const JxlEncoderFrameSettings* frame_settings,
    const JxlPixelFormat* pixel_format, const void* buffer, size_t size) {
  if (!frame_settings->enc->basic_info_set ||
      (!frame_settings->enc->color_encoding_set &&
       !frame_settings->enc->metadata.m.xyb_encoded)) {
    // Basic Info must be set, and color encoding must be set directly,
    // or set to XYB via JxlBasicInfo.uses_original_profile = JXL_FALSE
    // Otherwise, this is an API misuse.
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Basic info or color encoding not set yet");
  }

  if (frame_settings->enc->frames_closed) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Frame input already closed");
  }
  if (pixel_format->num_channels < 3) {
    if (frame_settings->enc->basic_info.num_color_channels != 1) {
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                           "Grayscale pixel format input for an RGB image");
    }
  } else {
    if (frame_settings->enc->basic_info.num_color_channels != 3) {
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                           "RGB pixel format input for a grayscale image");
    }
  }

  bool has_alpha = frame_settings->enc->metadata.m.HasAlpha();

  size_t xsize, ysize;
  if (GetCurrentDimensions(frame_settings, xsize, ysize) != JXL_ENC_SUCCESS) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                         "bad dimensions");
  }

  // All required conditions to do fast-lossless.
  if (CanDoFastLossless(frame_settings, pixel_format, has_alpha)) {
    const size_t bytes_per_pixel =
        pixel_format->data_type == JxlDataType::JXL_TYPE_UINT8
            ? pixel_format->num_channels
            : pixel_format->num_channels * 2;
    const size_t last_row_size = xsize * bytes_per_pixel;
    const size_t align = pixel_format->align;
    const size_t row_size =
        (align > 1 ? jxl::DivCeil(last_row_size, align) * align
                   : last_row_size);
    const size_t bytes_to_read = row_size * (ysize - 1) + last_row_size;
    if (bytes_to_read > size) {
      return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                           "provided image buffer too small");
    }
    const bool big_endian =
        pixel_format->endianness == JXL_BIG_ENDIAN ||
        (pixel_format->endianness == JXL_NATIVE_ENDIAN && !IsLittleEndian());

    auto runner = +[](void* void_pool, void* opaque, void fun(void*, size_t),
                      size_t count) {
      auto* pool = reinterpret_cast<jxl::ThreadPool*>(void_pool);
      JXL_CHECK(jxl::RunOnPool(
          pool, 0, count, jxl::ThreadPool::NoInit,
          [&](size_t i, size_t) { fun(opaque, i); }, "Encode fast lossless"));
    };
    QueueFastLosslessFrame(
        frame_settings,
        JxlFastLosslessPrepareFrame(
            reinterpret_cast<const unsigned char*>(buffer), xsize, row_size,
            ysize, pixel_format->num_channels,
            frame_settings->enc->metadata.m.bit_depth.bits_per_sample,
            big_endian, /*effort=*/2, frame_settings->enc->thread_pool.get(),
            runner));
    return JXL_ENC_SUCCESS;
  }

  auto queued_frame = jxl::MemoryManagerMakeUnique<jxl::JxlEncoderQueuedFrame>(
      &frame_settings->enc->memory_manager,
      // JxlEncoderQueuedFrame is a struct with no constructors, so we use the
      // default move constructor there.
      jxl::JxlEncoderQueuedFrame{
          frame_settings->values,
          jxl::ImageBundle(&frame_settings->enc->metadata.m),
          {}});

  if (!queued_frame) {
    // TODO(jon): when can this happen? is this an API usage error?
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                         "No frame queued?");
  }

  jxl::ColorEncoding c_current;
  if (!frame_settings->enc->color_encoding_set) {
    if ((pixel_format->data_type == JXL_TYPE_FLOAT) ||
        (pixel_format->data_type == JXL_TYPE_FLOAT16)) {
      c_current =
          jxl::ColorEncoding::LinearSRGB(pixel_format->num_channels < 3);
    } else {
      c_current = jxl::ColorEncoding::SRGB(pixel_format->num_channels < 3);
    }
  } else {
    c_current = frame_settings->enc->metadata.m.color_encoding;
  }
  uint32_t num_channels = pixel_format->num_channels;
  size_t has_interleaved_alpha =
      static_cast<size_t>(num_channels == 2 || num_channels == 4);
  if (has_interleaved_alpha >
      frame_settings->enc->metadata.m.num_extra_channels) {
    return JXL_API_ERROR(
        frame_settings->enc, JXL_ENC_ERR_API_USAGE,
        "number of extra channels mismatch (need 1 extra channel for alpha)");
  }
  std::vector<jxl::ImageF> extra_channels(
      frame_settings->enc->metadata.m.num_extra_channels);
  for (auto& extra_channel : extra_channels) {
    extra_channel = jxl::ImageF(xsize, ysize);
  }
  queued_frame->frame.SetExtraChannels(std::move(extra_channels));
  for (auto& ec_info : frame_settings->enc->metadata.m.extra_channel_info) {
    if (has_interleaved_alpha && ec_info.type == jxl::ExtraChannel::kAlpha) {
      queued_frame->ec_initialized.push_back(1);
      has_interleaved_alpha = 0;  // only first Alpha is initialized
    } else {
      queued_frame->ec_initialized.push_back(0);
    }
  }
  queued_frame->frame.origin.x0 =
      frame_settings->values.header.layer_info.crop_x0;
  queued_frame->frame.origin.y0 =
      frame_settings->values.header.layer_info.crop_y0;
  queued_frame->frame.use_for_next_frame =
      (frame_settings->values.header.layer_info.save_as_reference != 0u);
  queued_frame->frame.blendmode =
      frame_settings->values.header.layer_info.blend_info.blendmode ==
              JXL_BLEND_REPLACE
          ? jxl::BlendMode::kReplace
          : jxl::BlendMode::kBlend;
  queued_frame->frame.blend =
      frame_settings->values.header.layer_info.blend_info.source > 0;

  if (JXL_ENC_SUCCESS !=
      VerifyInputBitDepth(frame_settings->values.image_bit_depth,
                          *pixel_format)) {
    return JXL_API_ERROR_NOSET("Invalid input bit depth");
  }
  size_t bits_per_sample =
      GetBitDepth(frame_settings->values.image_bit_depth,
                  frame_settings->enc->metadata.m, *pixel_format);
  const uint8_t* uint8_buffer = reinterpret_cast<const uint8_t*>(buffer);
  if (!jxl::ConvertFromExternal(
          jxl::Span<const uint8_t>(uint8_buffer, size), xsize, ysize, c_current,
          bits_per_sample, *pixel_format,
          frame_settings->enc->thread_pool.get(), &(queued_frame->frame))) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid input buffer");
  }
  if (frame_settings->values.lossless &&
      frame_settings->enc->metadata.m.xyb_encoded) {
    return JXL_API_ERROR(
        frame_settings->enc, JXL_ENC_ERR_API_USAGE,
        "Set uses_original_profile=true for lossless encoding");
  }
  queued_frame->option_values.cparams.level =
      frame_settings->enc->codestream_level;

  QueueFrame(frame_settings, queued_frame);
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderUseBoxes(JxlEncoder* enc) {
  if (enc->wrote_bytes) {
    return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                         "this setting can only be set at the beginning");
  }
  enc->use_boxes = true;
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderAddBox(JxlEncoder* enc, const JxlBoxType type,
                                  const uint8_t* contents, size_t size,
                                  JXL_BOOL compress_box) {
  if (!enc->use_boxes) {
    return JXL_API_ERROR(
        enc, JXL_ENC_ERR_API_USAGE,
        "must set JxlEncoderUseBoxes at the beginning to add boxes");
  }
  if (compress_box) {
    if (memcmp("jxl", type, 3) == 0) {
      return JXL_API_ERROR(
          enc, JXL_ENC_ERR_API_USAGE,
          "brob box may not contain a type starting with \"jxl\"");
    }
    if (memcmp("jbrd", type, 4) == 0) {
      return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                           "jbrd box may not be brob compressed");
    }
    if (memcmp("brob", type, 4) == 0) {
      // The compress_box will compress an existing non-brob box into a brob
      // box. If already giving a valid brotli-compressed brob box, set
      // compress_box to false since it is already compressed.
      return JXL_API_ERROR(enc, JXL_ENC_ERR_API_USAGE,
                           "a brob box cannot contain another brob box");
    }
  }

  auto box = jxl::MemoryManagerMakeUnique<jxl::JxlEncoderQueuedBox>(
      &enc->memory_manager);

  box->type = jxl::MakeBoxType(type);
  box->contents.assign(contents, contents + size);
  box->compress_box = !!compress_box;
  QueueBox(enc, box);
  return JXL_ENC_SUCCESS;
}

JXL_EXPORT JxlEncoderStatus JxlEncoderSetExtraChannelBuffer(
    const JxlEncoderFrameSettings* frame_settings,
    const JxlPixelFormat* pixel_format, const void* buffer, size_t size,
    uint32_t index) {
  if (index >= frame_settings->enc->metadata.m.num_extra_channels) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid value for the index of extra channel");
  }
  if (!frame_settings->enc->basic_info_set ||
      !frame_settings->enc->color_encoding_set) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Basic info has to be set first");
  }
  if (frame_settings->enc->input_queue.empty()) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "First add image frame, then extra channels");
  }
  if (frame_settings->enc->frames_closed) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Frame input already closed");
  }
  size_t xsize, ysize;
  if (GetCurrentDimensions(frame_settings, xsize, ysize) != JXL_ENC_SUCCESS) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_GENERIC,
                         "bad dimensions");
  }
  JxlPixelFormat ec_format = *pixel_format;
  ec_format.num_channels = 1;
  if (JXL_ENC_SUCCESS !=
      VerifyInputBitDepth(frame_settings->values.image_bit_depth, ec_format)) {
    return JXL_API_ERROR_NOSET("Invalid input bit depth");
  }
  size_t bits_per_sample = GetBitDepth(
      frame_settings->values.image_bit_depth,
      frame_settings->enc->metadata.m.extra_channel_info[index], ec_format);
  const uint8_t* uint8_buffer = reinterpret_cast<const uint8_t*>(buffer);
  auto queued_frame = frame_settings->enc->input_queue.back().frame.get();
  if (!jxl::ConvertFromExternal(jxl::Span<const uint8_t>(uint8_buffer, size),
                                xsize, ysize, bits_per_sample, ec_format, 0,
                                frame_settings->enc->thread_pool.get(),
                                &queued_frame->frame.extra_channels()[index])) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Failed to set buffer for extra channel");
  }
  queued_frame->ec_initialized[index] = 1;

  return JXL_ENC_SUCCESS;
}

void JxlEncoderCloseFrames(JxlEncoder* enc) { enc->frames_closed = true; }

void JxlEncoderCloseBoxes(JxlEncoder* enc) { enc->boxes_closed = true; }

void JxlEncoderCloseInput(JxlEncoder* enc) {
  JxlEncoderCloseFrames(enc);
  JxlEncoderCloseBoxes(enc);
}
JxlEncoderStatus JxlEncoderProcessOutput(JxlEncoder* enc, uint8_t** next_out,
                                         size_t* avail_out) {
  while (*avail_out >= 32 &&
         (!enc->output_byte_queue.empty() ||
          !enc->output_fast_frame_queue.empty() || !enc->input_queue.empty())) {
    if (!enc->output_byte_queue.empty()) {
      size_t to_copy = std::min(*avail_out, enc->output_byte_queue.size());
      std::copy_n(enc->output_byte_queue.begin(), to_copy, *next_out);
      *next_out += to_copy;
      *avail_out -= to_copy;
      enc->output_byte_queue.erase(enc->output_byte_queue.begin(),
                                   enc->output_byte_queue.begin() + to_copy);
    } else if (!enc->output_fast_frame_queue.empty()) {
      size_t count = JxlFastLosslessWriteOutput(
          enc->output_fast_frame_queue.front().get(), *next_out, *avail_out);
      *next_out += count;
      *avail_out -= count;
      if (count == 0) {
        enc->output_fast_frame_queue.pop_front();
      }

    } else if (!enc->input_queue.empty()) {
      if (enc->RefillOutputByteQueue() != JXL_ENC_SUCCESS) {
        return JXL_ENC_ERROR;
      }
    }
  }

  if (!enc->output_byte_queue.empty() ||
      !enc->output_fast_frame_queue.empty() || !enc->input_queue.empty()) {
    return JXL_ENC_NEED_MORE_OUTPUT;
  }
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetFrameHeader(
    JxlEncoderFrameSettings* frame_settings,
    const JxlFrameHeader* frame_header) {
  if (frame_header->layer_info.blend_info.source > 3) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "invalid blending source index");
  }
  // If there are no extra channels, it's ok for the value to be 0.
  if (frame_header->layer_info.blend_info.alpha != 0 &&
      frame_header->layer_info.blend_info.alpha >=
          frame_settings->enc->metadata.m.extra_channel_info.size()) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "alpha blend channel index out of bounds");
  }

  frame_settings->values.header = *frame_header;
  // Setting the frame header resets the frame name, it must be set again with
  // JxlEncoderSetFrameName if desired.
  frame_settings->values.frame_name = "";

  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetExtraChannelBlendInfo(
    JxlEncoderFrameSettings* frame_settings, size_t index,
    const JxlBlendInfo* blend_info) {
  if (index >= frame_settings->enc->metadata.m.num_extra_channels) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "Invalid value for the index of extra channel");
  }

  if (frame_settings->values.extra_channel_blend_info.size() !=
      frame_settings->enc->metadata.m.num_extra_channels) {
    JxlBlendInfo default_blend_info;
    JxlEncoderInitBlendInfo(&default_blend_info);
    frame_settings->values.extra_channel_blend_info.resize(
        frame_settings->enc->metadata.m.num_extra_channels, default_blend_info);
  }
  frame_settings->values.extra_channel_blend_info[index] = *blend_info;
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetFrameName(JxlEncoderFrameSettings* frame_settings,
                                        const char* frame_name) {
  std::string str = frame_name ? frame_name : "";
  if (str.size() > 1071) {
    return JXL_API_ERROR(frame_settings->enc, JXL_ENC_ERR_API_USAGE,
                         "frame name can be max 1071 bytes long");
  }
  frame_settings->values.frame_name = str;
  frame_settings->values.header.name_length = str.size();
  return JXL_ENC_SUCCESS;
}

JxlEncoderStatus JxlEncoderSetFrameBitDepth(
    JxlEncoderFrameSettings* frame_settings, const JxlBitDepth* bit_depth) {
  if (bit_depth->type != JXL_BIT_DEPTH_FROM_PIXEL_FORMAT &&
      bit_depth->type != JXL_BIT_DEPTH_FROM_CODESTREAM) {
    return JXL_API_ERROR_NOSET(
        "Only JXL_BIT_DEPTH_FROM_PIXEL_FORMAT and "
        "JXL_BIT_DEPTH_FROM_CODESTREAM is implemented "
        "for input buffers.");
  }
  frame_settings->values.image_bit_depth = *bit_depth;
  return JXL_ENC_SUCCESS;
}

void JxlColorEncodingSetToSRGB(JxlColorEncoding* color_encoding,
                               JXL_BOOL is_gray) {
  ConvertInternalToExternalColorEncoding(jxl::ColorEncoding::SRGB(is_gray),
                                         color_encoding);
}

void JxlColorEncodingSetToLinearSRGB(JxlColorEncoding* color_encoding,
                                     JXL_BOOL is_gray) {
  ConvertInternalToExternalColorEncoding(
      jxl::ColorEncoding::LinearSRGB(is_gray), color_encoding);
}

void JxlEncoderAllowExpertOptions(JxlEncoder* enc) {
  enc->allow_expert_options = true;
}

JXL_EXPORT void JxlEncoderSetDebugImageCallback(
    JxlEncoderFrameSettings* frame_settings, JxlDebugImageCallback callback,
    void* opaque) {
  frame_settings->values.cparams.debug_image = callback;
  frame_settings->values.cparams.debug_image_opaque = opaque;
}

JXL_EXPORT JxlEncoderStats* JxlEncoderStatsCreate() {
  return new JxlEncoderStats();
}

JXL_EXPORT void JxlEncoderStatsDestroy(JxlEncoderStats* stats) {
  if (stats) delete stats;
}

JXL_EXPORT void JxlEncoderCollectStats(JxlEncoderFrameSettings* frame_settings,
                                       JxlEncoderStats* stats) {
  if (!stats) return;
  frame_settings->values.aux_out = &stats->aux_out;
}

JXL_EXPORT size_t JxlEncoderStatsGet(const JxlEncoderStats* stats,
                                     JxlEncoderStatsKey key) {
  if (!stats) return 0;
  const jxl::AuxOut& aux_out = stats->aux_out;
  switch (key) {
    case JXL_ENC_STAT_HEADER_BITS:
      return aux_out.layers[jxl::kLayerHeader].total_bits;
    case JXL_ENC_STAT_TOC_BITS:
      return aux_out.layers[jxl::kLayerTOC].total_bits;
    case JXL_ENC_STAT_DICTIONARY_BITS:
      return aux_out.layers[jxl::kLayerDictionary].total_bits;
    case JXL_ENC_STAT_SPLINES_BITS:
      return aux_out.layers[jxl::kLayerSplines].total_bits;
    case JXL_ENC_STAT_NOISE_BITS:
      return aux_out.layers[jxl::kLayerNoise].total_bits;
    case JXL_ENC_STAT_QUANT_BITS:
      return aux_out.layers[jxl::kLayerQuant].total_bits;
    case JXL_ENC_STAT_MODULAR_TREE_BITS:
      return aux_out.layers[jxl::kLayerModularTree].total_bits;
    case JXL_ENC_STAT_MODULAR_GLOBAL_BITS:
      return aux_out.layers[jxl::kLayerModularGlobal].total_bits;
    case JXL_ENC_STAT_DC_BITS:
      return aux_out.layers[jxl::kLayerDC].total_bits;
    case JXL_ENC_STAT_MODULAR_DC_GROUP_BITS:
      return aux_out.layers[jxl::kLayerModularDcGroup].total_bits;
    case JXL_ENC_STAT_CONTROL_FIELDS_BITS:
      return aux_out.layers[jxl::kLayerControlFields].total_bits;
    case JXL_ENC_STAT_COEF_ORDER_BITS:
      return aux_out.layers[jxl::kLayerOrder].total_bits;
    case JXL_ENC_STAT_AC_HISTOGRAM_BITS:
      return aux_out.layers[jxl::kLayerAC].total_bits;
    case JXL_ENC_STAT_AC_BITS:
      return aux_out.layers[jxl::kLayerACTokens].total_bits;
    case JXL_ENC_STAT_MODULAR_AC_GROUP_BITS:
      return aux_out.layers[jxl::kLayerModularAcGroup].total_bits;
    case JXL_ENC_STAT_NUM_SMALL_BLOCKS:
      return aux_out.num_small_blocks;
    case JXL_ENC_STAT_NUM_DCT4X8_BLOCKS:
      return aux_out.num_dct4x8_blocks;
    case JXL_ENC_STAT_NUM_AFV_BLOCKS:
      return aux_out.num_afv_blocks;
    case JXL_ENC_STAT_NUM_DCT8_BLOCKS:
      return aux_out.num_dct8_blocks;
    case JXL_ENC_STAT_NUM_DCT8X32_BLOCKS:
      return aux_out.num_dct16_blocks;
    case JXL_ENC_STAT_NUM_DCT16_BLOCKS:
      return aux_out.num_dct16x32_blocks;
    case JXL_ENC_STAT_NUM_DCT16X32_BLOCKS:
      return aux_out.num_dct32_blocks;
    case JXL_ENC_STAT_NUM_DCT32_BLOCKS:
      return aux_out.num_dct32x64_blocks;
    case JXL_ENC_STAT_NUM_DCT32X64_BLOCKS:
      return aux_out.num_dct32x64_blocks;
    case JXL_ENC_STAT_NUM_DCT64_BLOCKS:
      return aux_out.num_dct64_blocks;
    case JXL_ENC_STAT_NUM_BUTTERAUGLI_ITERS:
      return aux_out.num_butteraugli_iters;
    default:
      return 0;
  }
}

JXL_EXPORT void JxlEncoderStatsMerge(JxlEncoderStats* stats,
                                     const JxlEncoderStats* other) {
  if (!stats || !other) return;
  stats->aux_out.Assimilate(other->aux_out);
}
