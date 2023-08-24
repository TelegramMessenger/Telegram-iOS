/* Copyright (c) the JPEG XL Project Authors. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

#ifndef LIB_JXL_ENCODE_INTERNAL_H_
#define LIB_JXL_ENCODE_INTERNAL_H_

#include <jxl/encode.h>
#include <jxl/memory_manager.h>
#include <jxl/parallel_runner.h>
#include <jxl/types.h>

#include <deque>
#include <vector>

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_fast_lossless.h"
#include "lib/jxl/enc_frame.h"
#include "lib/jxl/memory_manager_internal.h"

namespace jxl {

/* Frame index box 'jxli' will start with Varint() for
NF: has type Varint(): number of frames listed in the index.
TNUM: has type u32: numerator of tick unit.
TDEN: has type u32: denominator of tick unit. Value 0 means the file is
ill-formed. per frame i listed: OFFi: has type Varint(): offset of start byte of
this frame compared to start byte of previous frame from this index in the JPEG
XL codestream. For the first frame, this is the offset from the first byte of
the JPEG XL codestream. Ti: has type Varint(): duration in ticks between the
start of this frame and the start of the next frame in the index. If this is the
last frame in the index, this is the duration in ticks between the start of this
frame and the end of the stream. A tick lasts TNUM / TDEN seconds. Fi: has type
Varint(): amount of frames the next frame in the index occurs after this frame.
If this is the last frame in the index, this is the amount of frames after this
frame in the remainder of the stream. Only frames that are presented by the
decoder are counted for this purpose, this excludes frames that are not intended
for display but for compositing with other frames, such as frames that aren't
the last frame with a duration of 0 ticks.

All the frames listed in jxli are keyframes and the first frame is
present in the list.
There shall be either zero or one Frame Index boxes in a JPEG XL file.
The offsets OFFi per frame are given as bytes in the codestream, not as
bytes in the file format using the box structure. This means if JPEG XL Partial
Codestream boxes are used, the offset is counted within the concatenated
codestream, bytes from box headers or non-codestream boxes are not counted.
*/

typedef struct JxlEncoderFrameIndexBoxEntryStruct {
  bool to_be_indexed;
  uint32_t duration;
  uint64_t OFFi;
} JxlEncoderFrameIndexBoxEntry;

typedef struct JxlEncoderFrameIndexBoxStruct {
  // We always need to record the first frame entry, so presence of the
  // first entry alone is not an indication if it was requested to be
  // stored.
  bool index_box_requested_through_api = false;

  int64_t NF() const { return entries.size(); }
  bool StoreFrameIndexBox() {
    for (auto e : entries) {
      if (e.to_be_indexed) {
        return true;
      }
    }
    return false;
  }
  int32_t TNUM = 1;
  int32_t TDEN = 1000;

  std::vector<JxlEncoderFrameIndexBoxEntry> entries;

  // That way we can ensure that every index box will have the first frame.
  // If the API user decides to mark it as an indexed frame, we call
  // the AddFrame again, this time with requested.
  void AddFrame(uint64_t OFFi, uint32_t duration, bool to_be_indexed) {
    // We call AddFrame to every frame.
    // Recording the first frame is required by the standard.
    // Knowing the last frame is required, since the last indexed frame
    // needs to know how many frames until the end.
    // To be able to tell how many frames there are between each index
    // entry we just record every frame here.
    if (entries.size() == 1) {
      if (OFFi == entries[0].OFFi) {
        // API use for the first frame, let's clear the already recorded first
        // frame.
        entries.clear();
      }
    }
    JxlEncoderFrameIndexBoxEntry e;
    e.to_be_indexed = to_be_indexed;
    e.OFFi = OFFi;
    e.duration = duration;
    entries.push_back(e);
  }
} JxlEncoderFrameIndexBox;

// The encoder options (such as quality, compression speed, ...) for a single
// frame, but not encoder-wide options such as box-related options.
typedef struct JxlEncoderFrameSettingsValuesStruct {
  // lossless is a separate setting from cparams because it is a combination
  // setting that overrides multiple settings inside of cparams.
  bool lossless;
  CompressParams cparams;
  JxlFrameHeader header;
  std::vector<JxlBlendInfo> extra_channel_blend_info;
  std::string frame_name;
  JxlBitDepth image_bit_depth;
  bool frame_index_box = false;
  jxl::AuxOut* aux_out = nullptr;
} JxlEncoderFrameSettingsValues;

typedef std::array<uint8_t, 4> BoxType;

// Utility function that makes a BoxType from a string literal. The string must
// have 4 characters, a 5th null termination character is optional.
constexpr BoxType MakeBoxType(const char* type) {
  return BoxType(
      {{static_cast<uint8_t>(type[0]), static_cast<uint8_t>(type[1]),
        static_cast<uint8_t>(type[2]), static_cast<uint8_t>(type[3])}});
}

constexpr unsigned char kContainerHeader[] = {
    0,   0,   0, 0xc, 'J',  'X', 'L', ' ', 0xd, 0xa, 0x87,
    0xa, 0,   0, 0,   0x14, 'f', 't', 'y', 'p', 'j', 'x',
    'l', ' ', 0, 0,   0,    0,   'j', 'x', 'l', ' '};

constexpr unsigned char kLevelBoxHeader[] = {0, 0, 0, 0x9, 'j', 'x', 'l', 'l'};

struct JxlEncoderQueuedFrame {
  JxlEncoderFrameSettingsValues option_values;
  ImageBundle frame;
  std::vector<uint8_t> ec_initialized;
};

struct JxlEncoderQueuedBox {
  BoxType type;
  std::vector<uint8_t> contents;
  bool compress_box;
};

using FJXLFrameUniquePtr =
    std::unique_ptr<JxlFastLosslessFrameState,
                    decltype(&JxlFastLosslessFreeFrameState)>;

// Either a frame, or a box, not both.
// Can also be a FJXL frame.
struct JxlEncoderQueuedInput {
  explicit JxlEncoderQueuedInput(const JxlMemoryManager& memory_manager)
      : frame(nullptr, jxl::MemoryManagerDeleteHelper(&memory_manager)),
        box(nullptr, jxl::MemoryManagerDeleteHelper(&memory_manager)) {}
  MemoryManagerUniquePtr<JxlEncoderQueuedFrame> frame;
  MemoryManagerUniquePtr<JxlEncoderQueuedBox> box;
  FJXLFrameUniquePtr fast_lossless_frame = {nullptr,
                                            JxlFastLosslessFreeFrameState};
};

// Appends a JXL container box header with given type, size, and unbounded
// properties to output.
template <typename T>
void AppendBoxHeader(const jxl::BoxType& type, size_t size, bool unbounded,
                     T* output) {
  uint64_t box_size = 0;
  bool large_size = false;
  if (!unbounded) {
    box_size = size + 8;
    if (box_size >= 0x100000000ull) {
      large_size = true;
    }
  }

  {
    const uint64_t store = large_size ? 1 : box_size;
    for (size_t i = 0; i < 4; i++) {
      output->push_back(store >> (8 * (3 - i)) & 0xff);
    }
  }
  for (size_t i = 0; i < 4; i++) {
    output->push_back(type[i]);
  }

  if (large_size) {
    for (size_t i = 0; i < 8; i++) {
      output->push_back(box_size >> (8 * (7 - i)) & 0xff);
    }
  }
}

}  // namespace jxl

// Internal use only struct, can only be initialized correctly by
// JxlEncoderCreate.
struct JxlEncoderStruct {
  JxlEncoderError error = JxlEncoderError::JXL_ENC_ERR_OK;
  JxlMemoryManager memory_manager;
  jxl::MemoryManagerUniquePtr<jxl::ThreadPool> thread_pool{
      nullptr, jxl::MemoryManagerDeleteHelper(&memory_manager)};
  JxlCmsInterface cms;
  bool cms_set;
  std::vector<jxl::MemoryManagerUniquePtr<JxlEncoderFrameSettings>>
      encoder_options;

  size_t num_queued_frames;
  size_t num_queued_boxes;
  std::vector<jxl::JxlEncoderQueuedInput> input_queue;
  std::deque<uint8_t> output_byte_queue;
  std::deque<jxl::FJXLFrameUniquePtr> output_fast_frame_queue;

  // How many codestream bytes have been written, i.e.,
  // content of jxlc and jxlp boxes. Frame index box jxli
  // requires position indices to point to codestream bytes,
  // so we need to keep track of the total of flushed or queue
  // codestream bytes. These bytes may be in a single jxlc box
  // or across multiple jxlp boxes.
  size_t codestream_bytes_written_beginning_of_frame;
  size_t codestream_bytes_written_end_of_frame;
  jxl::JxlEncoderFrameIndexBox frame_index_box;

  // Force using the container even if not needed
  bool use_container;
  // User declared they will add metadata boxes
  bool use_boxes;

  // TODO(lode): move level into jxl::CompressParams since some C++
  // implementation decisions should be based on it: level 10 allows more
  // features to be used.
  int32_t codestream_level;
  bool store_jpeg_metadata;
  jxl::CodecMetadata metadata;
  std::vector<uint8_t> jpeg_metadata;

  // Wrote any output at all, so wrote the data before the first user added
  // frame or box, such as signature, basic info, ICC profile or jpeg
  // reconstruction box.
  bool wrote_bytes;
  jxl::CompressParams last_used_cparams;
  JxlBasicInfo basic_info;

  // Encoder wrote a jxlp (partial codestream) box, so any next codestream
  // parts must also be written in jxlp boxes, a single jxlc box cannot be
  // used. The counter is used for the 4-byte jxlp box index header.
  size_t jxlp_counter;

  bool frames_closed;
  bool boxes_closed;
  bool basic_info_set;
  bool color_encoding_set;
  bool intensity_target_set;
  bool allow_expert_options = false;
  int brotli_effort = -1;

  // Takes the first frame in the input_queue, encodes it, and appends
  // the bytes to the output_byte_queue.
  JxlEncoderStatus RefillOutputByteQueue();

  bool MustUseContainer() const {
    return use_container || (codestream_level != 5 && codestream_level != -1) ||
           store_jpeg_metadata || use_boxes;
  }

  // Appends the bytes of a JXL box header with the provided type and size to
  // the end of the output_byte_queue. If unbounded is true, the size won't be
  // added to the header and the box will be assumed to continue until EOF.
  void AppendBoxHeader(const jxl::BoxType& type, size_t size, bool unbounded);
};

struct JxlEncoderFrameSettingsStruct {
  JxlEncoder* enc;
  jxl::JxlEncoderFrameSettingsValues values;
};

struct JxlEncoderStatsStruct {
  jxl::AuxOut aux_out;
};

#endif  // LIB_JXL_ENCODE_INTERNAL_H_
