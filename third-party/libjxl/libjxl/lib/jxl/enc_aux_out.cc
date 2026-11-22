// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_aux_out.h"

#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include <algorithm>
#include <numeric>  // accumulate
#include <sstream>

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"

namespace jxl {

const char* LayerName(size_t layer) {
  switch (layer) {
    case kLayerHeader:
      return "Headers";
    case kLayerTOC:
      return "TOC";
    case kLayerDictionary:
      return "Patches";
    case kLayerSplines:
      return "Splines";
    case kLayerNoise:
      return "Noise";
    case kLayerQuant:
      return "Quantizer";
    case kLayerModularTree:
      return "ModularTree";
    case kLayerModularGlobal:
      return "ModularGlobal";
    case kLayerDC:
      return "DC";
    case kLayerModularDcGroup:
      return "ModularDcGroup";
    case kLayerControlFields:
      return "ControlFields";
    case kLayerOrder:
      return "CoeffOrder";
    case kLayerAC:
      return "ACHistograms";
    case kLayerACTokens:
      return "ACTokens";
    case kLayerModularAcGroup:
      return "ModularAcGroup";
    default:
      JXL_UNREACHABLE("Invalid layer %d\n", static_cast<int>(layer));
  }
}

void AuxOut::LayerTotals::Print(size_t num_inputs) const {
  if (JXL_DEBUG_V_LEVEL > 0) {
    printf("%10" PRId64, static_cast<int64_t>(total_bits));
    if (histogram_bits != 0) {
      printf("   [c/i:%6.2f | hst:%8" PRId64 " | ex:%8" PRId64
             " | h+c+e:%12.3f",
             num_clustered_histograms * 1.0 / num_inputs,
             static_cast<int64_t>(histogram_bits >> 3),
             static_cast<int64_t>(extra_bits >> 3),
             (histogram_bits + clustered_entropy + extra_bits) / 8.0);
      printf("]");
    }
    printf("\n");
  }
}

void AuxOut::Assimilate(const AuxOut& victim) {
  for (size_t i = 0; i < layers.size(); ++i) {
    layers[i].Assimilate(victim.layers[i]);
  }
  num_blocks += victim.num_blocks;
  num_small_blocks += victim.num_small_blocks;
  num_dct4x8_blocks += victim.num_dct4x8_blocks;
  num_afv_blocks += victim.num_afv_blocks;
  num_dct8_blocks += victim.num_dct8_blocks;
  num_dct8x16_blocks += victim.num_dct8x16_blocks;
  num_dct8x32_blocks += victim.num_dct8x32_blocks;
  num_dct16_blocks += victim.num_dct16_blocks;
  num_dct16x32_blocks += victim.num_dct16x32_blocks;
  num_dct32_blocks += victim.num_dct32_blocks;
  num_dct32x64_blocks += victim.num_dct32x64_blocks;
  num_dct64_blocks += victim.num_dct64_blocks;
  num_butteraugli_iters += victim.num_butteraugli_iters;
}

void AuxOut::Print(size_t num_inputs) const {
  if (JXL_DEBUG_V_LEVEL > 0) {
    if (num_inputs == 0) return;

    LayerTotals all_layers;
    for (size_t i = 0; i < layers.size(); ++i) {
      all_layers.Assimilate(layers[i]);
    }

    printf("Average butteraugli iters: %10.2f\n",
           num_butteraugli_iters * 1.0 / num_inputs);

    for (size_t i = 0; i < layers.size(); ++i) {
      if (layers[i].total_bits != 0) {
        printf("Total layer bits %-10s\t", LayerName(i));
        printf("%10f%%", 100.0 * layers[i].total_bits / all_layers.total_bits);
        layers[i].Print(num_inputs);
      }
    }
    printf("Total image size           ");
    all_layers.Print(num_inputs);

    size_t total_blocks = 0;
    size_t total_positions = 0;
    if (total_blocks != 0 && total_positions != 0) {
      printf("\n\t\t  Blocks\t\tPositions\t\t\tBlocks/Position\n");
      printf(" Total:\t\t    %7" PRIuS "\t\t     %7" PRIuS " \t\t\t%10f%%\n\n",
             total_blocks, total_positions,
             100.0 * total_blocks / total_positions);
    }
  }
}

}  // namespace jxl
