// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_DEC_PATCH_DICTIONARY_H_
#define LIB_JXL_DEC_PATCH_DICTIONARY_H_

// Chooses reference patches, and avoids encoding them once per occurrence.

#include <stddef.h>
#include <string.h>
#include <sys/types.h>

#include <tuple>
#include <vector>

#include "lib/jxl/base/status.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/image.h"
#include "lib/jxl/opsin_params.h"

namespace jxl {

enum class PatchBlendMode : uint8_t {
  // The new values are the old ones. Useful to skip some channels.
  kNone = 0,
  // The new values (in the crop) replace the old ones: sample = new
  kReplace = 1,
  // The new values (in the crop) get added to the old ones: sample = old + new
  kAdd = 2,
  // The new values (in the crop) get multiplied by the old ones:
  // sample = old * new
  // This blend mode is only supported if BlendColorSpace is kEncoded. The
  // range of the new value matters for multiplication purposes, and its
  // nominal range of 0..1 is computed the same way as this is done for the
  // alpha values in kBlend and kAlphaWeightedAdd.
  kMul = 3,
  // The new values (in the crop) replace the old ones if alpha>0:
  // For first alpha channel:
  // alpha = old + new * (1 - old)
  // For other channels if !alpha_associated:
  // sample = ((1 - new_alpha) * old * old_alpha + new_alpha * new) / alpha
  // For other channels if alpha_associated:
  // sample = (1 - new_alpha) * old + new
  // The alpha formula applies to the alpha used for the division in the other
  // channels formula, and applies to the alpha channel itself if its
  // blend_channel value matches itself.
  // If using kBlendAbove, new is the patch and old is the original image; if
  // using kBlendBelow, the meaning is inverted.
  kBlendAbove = 4,
  kBlendBelow = 5,
  // The new values (in the crop) are added to the old ones if alpha>0:
  // For first alpha channel: sample = sample = old + new * (1 - old)
  // For other channels: sample = old + alpha * new
  kAlphaWeightedAddAbove = 6,
  kAlphaWeightedAddBelow = 7,
  kNumBlendModes,
};

inline bool UsesAlpha(PatchBlendMode mode) {
  return mode == PatchBlendMode::kBlendAbove ||
         mode == PatchBlendMode::kBlendBelow ||
         mode == PatchBlendMode::kAlphaWeightedAddAbove ||
         mode == PatchBlendMode::kAlphaWeightedAddBelow;
}
inline bool UsesClamp(PatchBlendMode mode) {
  return UsesAlpha(mode) || mode == PatchBlendMode::kMul;
}

struct PatchBlending {
  PatchBlendMode mode;
  uint32_t alpha_channel;
  bool clamp;
};

// Position and size of the patch in the reference frame.
struct PatchReferencePosition {
  size_t ref, x0, y0, xsize, ysize;
};

struct PatchPosition {
  // Position of top-left corner of the patch in the image.
  size_t x, y;
  size_t ref_pos_idx;
};

struct PassesSharedState;

// Encoder-side helper class to encode the PatchesDictionary.
class PatchDictionaryEncoder;

class PatchDictionary {
 public:
  PatchDictionary() = default;

  void SetPassesSharedState(const PassesSharedState* shared) {
    shared_ = shared;
  }

  bool HasAny() const { return !positions_.empty(); }

  Status Decode(BitReader* br, size_t xsize, size_t ysize,
                bool* uses_extra_channels);

  void Clear() {
    positions_.clear();
    ComputePatchTree();
  }

  // Adds patches to a segment of `xsize` pixels, starting at `inout`, assumed
  // to be located at position (x0, y) in the frame.
  void AddOneRow(float* const* inout, size_t y, size_t x0, size_t xsize) const;

  // Returns dependencies of this patch dictionary on reference frame ids as a
  // bit mask: bits 0-3 indicate reference frame 0-3.
  int GetReferences() const;

  std::vector<size_t> GetPatchesForRow(size_t y) const;

 private:
  friend class PatchDictionaryEncoder;

  const PassesSharedState* shared_;
  std::vector<PatchPosition> positions_;
  std::vector<PatchReferencePosition> ref_positions_;
  std::vector<PatchBlending> blendings_;

  // Interval tree on the y coordinates of the patches.
  struct PatchTreeNode {
    ssize_t left_child;
    ssize_t right_child;
    size_t y_center;
    // Range of patches in sorted_patches_y0_ and sorted_patches_y1_ that
    // contain the row y_center.
    size_t start;
    size_t num;
  };
  std::vector<PatchTreeNode> patch_tree_;
  // Number of patches for each row.
  std::vector<size_t> num_patches_;
  std::vector<std::pair<size_t, size_t>> sorted_patches_y0_;
  std::vector<std::pair<size_t, size_t>> sorted_patches_y1_;

  void ComputePatchTree();
};

}  // namespace jxl

#endif  // LIB_JXL_DEC_PATCH_DICTIONARY_H_
