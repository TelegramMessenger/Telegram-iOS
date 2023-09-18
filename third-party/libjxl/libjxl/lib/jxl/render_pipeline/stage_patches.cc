// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/render_pipeline/stage_patches.h"

namespace jxl {
namespace {
class PatchDictionaryStage : public RenderPipelineStage {
 public:
  PatchDictionaryStage(const PatchDictionary* patches, size_t num_channels)
      : RenderPipelineStage(RenderPipelineStage::Settings()),
        patches_(*patches),
        num_channels_(num_channels) {}

  void ProcessRow(const RowInfo& input_rows, const RowInfo& output_rows,
                  size_t xextra, size_t xsize, size_t xpos, size_t ypos,
                  size_t thread_id) const final {
    JXL_ASSERT(xpos == 0 || xpos >= xextra);
    size_t x0 = xpos ? xpos - xextra : 0;
    std::vector<float*> row_ptrs(num_channels_);
    for (size_t i = 0; i < num_channels_; i++) {
      row_ptrs[i] = GetInputRow(input_rows, i, 0) + x0 - xpos;
    }
    patches_.AddOneRow(row_ptrs.data(), ypos, x0, xsize + xextra + xpos - x0);
  }

  RenderPipelineChannelMode GetChannelMode(size_t c) const final {
    return c < num_channels_ ? RenderPipelineChannelMode::kInPlace
                             : RenderPipelineChannelMode::kIgnored;
  }

  const char* GetName() const override { return "Patches"; }

 private:
  const PatchDictionary& patches_;
  const size_t num_channels_;
};
}  // namespace

std::unique_ptr<RenderPipelineStage> GetPatchesStage(
    const PatchDictionary* patches, size_t num_channels) {
  return jxl::make_unique<PatchDictionaryStage>(patches, num_channels);
}

}  // namespace jxl
