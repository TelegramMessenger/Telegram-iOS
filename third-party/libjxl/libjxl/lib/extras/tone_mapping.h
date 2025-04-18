// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_TONE_MAPPING_H_
#define LIB_EXTRAS_TONE_MAPPING_H_

#include "lib/jxl/codec_in_out.h"

namespace jxl {

// Important: after calling this, the result will contain many out-of-gamut
// colors. It is very strongly recommended to call GamutMap afterwards to
// rectify this.
Status ToneMapTo(std::pair<float, float> display_nits, CodecInOut* io,
                 ThreadPool* pool = nullptr);

// `preserve_saturation` indicates to what extent to favor saturation over
// luminance when mapping out-of-gamut colors to Rec. 2020. 0 preserves
// luminance at the complete expense of saturation, while 1 gives the most
// saturated color with the same hue that Rec. 2020 can represent even if it
// means lowering the luminance. Values in between correspond to linear mixtures
// of those two extremes.
Status GamutMap(CodecInOut* io, float preserve_saturation,
                ThreadPool* pool = nullptr);

}  // namespace jxl

#endif  // LIB_EXTRAS_TONE_MAPPING_H_
