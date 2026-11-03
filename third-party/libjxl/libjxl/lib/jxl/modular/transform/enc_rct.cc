// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/modular/transform/enc_rct.h"

#include "lib/jxl/base/status.h"
#include "lib/jxl/common.h"
#include "lib/jxl/modular/modular_image.h"
#include "lib/jxl/modular/transform/transform.h"  // CheckEqualChannels

namespace jxl {

Status FwdRCT(Image& input, size_t begin_c, size_t rct_type, ThreadPool* pool) {
  JXL_RETURN_IF_ERROR(CheckEqualChannels(input, begin_c, begin_c + 2));
  if (rct_type == 0) {  // noop
    return false;
  }
  // Permutation: 0=RGB, 1=GBR, 2=BRG, 3=RBG, 4=GRB, 5=BGR
  int permutation = rct_type / 7;
  // 0-5 values have the low bit corresponding to Third and the high bits
  // corresponding to Second. 6 corresponds to YCoCg.
  //
  // Second: 0=nop, 1=SubtractFirst, 2=SubtractAvgFirstThird
  //
  // Third: 0=nop, 1=SubtractFirst
  int custom = rct_type % 7;
  size_t m = begin_c;
  size_t w = input.channel[m + 0].w;
  size_t h = input.channel[m + 0].h;
  int second = (custom % 7) >> 1;
  int third = (custom % 7) & 1;
  const auto do_rct = [&](const int y, const int thread) {
    const pixel_type* in0 = input.channel[m + (permutation % 3)].Row(y);
    const pixel_type* in1 =
        input.channel[m + ((permutation + 1 + permutation / 3) % 3)].Row(y);
    const pixel_type* in2 =
        input.channel[m + ((permutation + 2 - permutation / 3) % 3)].Row(y);
    pixel_type* out0 = input.channel[m].Row(y);
    pixel_type* out1 = input.channel[m + 1].Row(y);
    pixel_type* out2 = input.channel[m + 2].Row(y);
    if (custom == 6) {
      for (size_t x = 0; x < w; x++) {
        pixel_type R = in0[x];
        pixel_type G = in1[x];
        pixel_type B = in2[x];
        out1[x] = R - B;
        pixel_type tmp = B + (out1[x] >> 1);
        out2[x] = G - tmp;
        out0[x] = tmp + (out2[x] >> 1);
      }
    } else {
      for (size_t x = 0; x < w; x++) {
        pixel_type First = in0[x];
        pixel_type Second = in1[x];
        pixel_type Third = in2[x];
        if (second == 1) {
          Second = Second - First;
        } else if (second == 2) {
          Second = Second - ((First + Third) >> 1);
        }
        if (third) Third = Third - First;
        out0[x] = First;
        out1[x] = Second;
        out2[x] = Third;
      }
    }
  };
  return RunOnPool(pool, 0, h, ThreadPool::NoInit, do_rct, "FwdRCT");
}

}  // namespace jxl
