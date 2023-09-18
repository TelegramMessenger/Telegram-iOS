// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_DEC_MODULAR_H_
#define LIB_JXL_DEC_MODULAR_H_

#include <stddef.h>

#include <string>

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/dec_cache.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/image.h"
#include "lib/jxl/modular/encoding/encoding.h"
#include "lib/jxl/modular/modular_image.h"

namespace jxl {

struct ModularStreamId {
  enum Kind {
    kGlobalData,
    kVarDCTDC,
    kModularDC,
    kACMetadata,
    kQuantTable,
    kModularAC
  };
  Kind kind;
  size_t quant_table_id;
  size_t group_id;  // DC or AC group id.
  size_t pass_id;   // Only for kModularAC.
  size_t ID(const FrameDimensions& frame_dim) const {
    size_t id = 0;
    switch (kind) {
      case kGlobalData:
        id = 0;
        break;
      case kVarDCTDC:
        id = 1 + group_id;
        break;
      case kModularDC:
        id = 1 + frame_dim.num_dc_groups + group_id;
        break;
      case kACMetadata:
        id = 1 + 2 * frame_dim.num_dc_groups + group_id;
        break;
      case kQuantTable:
        id = 1 + 3 * frame_dim.num_dc_groups + quant_table_id;
        break;
      case kModularAC:
        id = 1 + 3 * frame_dim.num_dc_groups + DequantMatrices::kNum +
             frame_dim.num_groups * pass_id + group_id;
        break;
    };
    return id;
  }
  static ModularStreamId Global() {
    return ModularStreamId{kGlobalData, 0, 0, 0};
  }
  static ModularStreamId VarDCTDC(size_t group_id) {
    return ModularStreamId{kVarDCTDC, 0, group_id, 0};
  }
  static ModularStreamId ModularDC(size_t group_id) {
    return ModularStreamId{kModularDC, 0, group_id, 0};
  }
  static ModularStreamId ACMetadata(size_t group_id) {
    return ModularStreamId{kACMetadata, 0, group_id, 0};
  }
  static ModularStreamId QuantTable(size_t quant_table_id) {
    JXL_ASSERT(quant_table_id < DequantMatrices::kNum);
    return ModularStreamId{kQuantTable, quant_table_id, 0, 0};
  }
  static ModularStreamId ModularAC(size_t group_id, size_t pass_id) {
    return ModularStreamId{kModularAC, 0, group_id, pass_id};
  }
  static size_t Num(const FrameDimensions& frame_dim, size_t passes) {
    return ModularAC(0, passes).ID(frame_dim);
  }
  std::string DebugString() const;
};

class ModularFrameDecoder {
 public:
  void Init(const FrameDimensions& frame_dim) { this->frame_dim = frame_dim; }
  Status DecodeGlobalInfo(BitReader* reader, const FrameHeader& frame_header,
                          bool allow_truncated_group);
  Status DecodeGroup(const Rect& rect, BitReader* reader, int minShift,
                     int maxShift, const ModularStreamId& stream, bool zerofill,
                     PassesDecoderState* dec_state,
                     RenderPipelineInput* render_pipeline_input,
                     bool allow_truncated, bool* should_run_pipeline = nullptr);
  // Decodes a VarDCT DC group (`group_id`) from the given `reader`.
  Status DecodeVarDCTDC(size_t group_id, BitReader* reader,
                        PassesDecoderState* dec_state);
  // Decodes a VarDCT AC Metadata group (`group_id`) from the given `reader`.
  Status DecodeAcMetadata(size_t group_id, BitReader* reader,
                          PassesDecoderState* dec_state);
  // Decodes a RAW quant table from `br` into the given `encoding`, of size
  // `required_size_x x required_size_y`. If `modular_frame_decoder` is passed,
  // its global tree is used, otherwise no global tree is used.
  static Status DecodeQuantTable(size_t required_size_x, size_t required_size_y,
                                 BitReader* br, QuantEncoding* encoding,
                                 size_t idx,
                                 ModularFrameDecoder* modular_frame_decoder);
  // if inplace is true, this can only be called once
  // if it is false, it can be called multiple times (e.g. for progressive
  // steps)
  Status FinalizeDecoding(PassesDecoderState* dec_state, jxl::ThreadPool* pool,
                          bool inplace);
  bool have_dc() const { return have_something; }
  void MaybeDropFullImage();
  bool UsesFullImage() const { return use_full_image; }

 private:
  Status ModularImageToDecodedRect(Image& gi, PassesDecoderState* dec_state,
                                   jxl::ThreadPool* pool,
                                   RenderPipelineInput& render_pipeline_input,
                                   Rect modular_rect);

  Image full_image;
  std::vector<Transform> global_transform;
  FrameDimensions frame_dim;
  bool do_color;
  bool have_something;
  bool use_full_image = true;
  bool all_same_shift;
  Tree tree;
  ANSCode code;
  std::vector<uint8_t> context_map;
  GroupHeader global_header;
};

}  // namespace jxl

#endif  // LIB_JXL_DEC_MODULAR_H_
