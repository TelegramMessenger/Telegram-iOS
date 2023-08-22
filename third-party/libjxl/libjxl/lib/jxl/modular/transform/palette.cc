// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/modular/transform/palette.h"

namespace jxl {

Status InvPalette(Image &input, uint32_t begin_c, uint32_t nb_colors,
                  uint32_t nb_deltas, Predictor predictor,
                  const weighted::Header &wp_header, ThreadPool *pool) {
  if (input.nb_meta_channels < 1) {
    return JXL_FAILURE("Error: Palette transform without palette.");
  }
  std::atomic<int> num_errors{0};
  int nb = input.channel[0].h;
  uint32_t c0 = begin_c + 1;
  if (c0 >= input.channel.size()) {
    return JXL_FAILURE("Channel is out of range.");
  }
  size_t w = input.channel[c0].w;
  size_t h = input.channel[c0].h;
  if (nb < 1) return JXL_FAILURE("Corrupted transforms");
  for (int i = 1; i < nb; i++) {
    input.channel.insert(
        input.channel.begin() + c0 + 1,
        Channel(w, h, input.channel[c0].hshift, input.channel[c0].vshift));
  }
  const Channel &palette = input.channel[0];
  const pixel_type *JXL_RESTRICT p_palette = input.channel[0].Row(0);
  intptr_t onerow = input.channel[0].plane.PixelsPerRow();
  intptr_t onerow_image = input.channel[c0].plane.PixelsPerRow();
  const int bit_depth = std::min(input.bitdepth, 24);

  if (w == 0) {
    // Nothing to do.
    // Avoid touching "empty" channels with non-zero height.
  } else if (nb_deltas == 0 && predictor == Predictor::Zero) {
    if (nb == 1) {
      JXL_RETURN_IF_ERROR(RunOnPool(
          pool, 0, h, ThreadPool::NoInit,
          [&](const uint32_t task, size_t /* thread */) {
            const size_t y = task;
            pixel_type *p = input.channel[c0].Row(y);
            for (size_t x = 0; x < w; x++) {
              const int index = Clamp1<int>(p[x], 0, (pixel_type)palette.w - 1);
              p[x] = palette_internal::GetPaletteValue(
                  p_palette, index, /*c=*/0,
                  /*palette_size=*/palette.w,
                  /*onerow=*/onerow, /*bit_depth=*/bit_depth);
            }
          },
          "UndoChannelPalette"));
    } else {
      JXL_RETURN_IF_ERROR(RunOnPool(
          pool, 0, h, ThreadPool::NoInit,
          [&](const uint32_t task, size_t /* thread */) {
            const size_t y = task;
            std::vector<pixel_type *> p_out(nb);
            const pixel_type *p_index = input.channel[c0].Row(y);
            for (int c = 0; c < nb; c++)
              p_out[c] = input.channel[c0 + c].Row(y);
            for (size_t x = 0; x < w; x++) {
              const int index = p_index[x];
              for (int c = 0; c < nb; c++) {
                p_out[c][x] = palette_internal::GetPaletteValue(
                    p_palette, index, /*c=*/c,
                    /*palette_size=*/palette.w,
                    /*onerow=*/onerow, /*bit_depth=*/bit_depth);
              }
            }
          },
          "UndoPalette"));
    }
  } else {
    // Parallelized per channel.
    ImageI indices = std::move(input.channel[c0].plane);
    input.channel[c0].plane = ImageI(indices.xsize(), indices.ysize());
    if (predictor == Predictor::Weighted) {
      JXL_RETURN_IF_ERROR(RunOnPool(
          pool, 0, nb, ThreadPool::NoInit,
          [&](const uint32_t c, size_t /* thread */) {
            Channel &channel = input.channel[c0 + c];
            weighted::State wp_state(wp_header, channel.w, channel.h);
            for (size_t y = 0; y < channel.h; y++) {
              pixel_type *JXL_RESTRICT p = channel.Row(y);
              const pixel_type *JXL_RESTRICT idx = indices.Row(y);
              for (size_t x = 0; x < channel.w; x++) {
                int index = idx[x];
                pixel_type_w val = 0;
                const pixel_type palette_entry =
                    palette_internal::GetPaletteValue(
                        p_palette, index, /*c=*/c,
                        /*palette_size=*/palette.w, /*onerow=*/onerow,
                        /*bit_depth=*/bit_depth);
                if (index < static_cast<int32_t>(nb_deltas)) {
                  PredictionResult pred =
                      PredictNoTreeWP(channel.w, p + x, onerow_image, x, y,
                                      predictor, &wp_state);
                  val = pred.guess + palette_entry;
                } else {
                  val = palette_entry;
                }
                p[x] = val;
                wp_state.UpdateErrors(p[x], x, y, channel.w);
              }
            }
          },
          "UndoDeltaPaletteWP"));
    } else {
      JXL_RETURN_IF_ERROR(RunOnPool(
          pool, 0, nb, ThreadPool::NoInit,
          [&](const uint32_t c, size_t /* thread */) {
            Channel &channel = input.channel[c0 + c];
            for (size_t y = 0; y < channel.h; y++) {
              pixel_type *JXL_RESTRICT p = channel.Row(y);
              const pixel_type *JXL_RESTRICT idx = indices.Row(y);
              for (size_t x = 0; x < channel.w; x++) {
                int index = idx[x];
                pixel_type_w val = 0;
                const pixel_type palette_entry =
                    palette_internal::GetPaletteValue(
                        p_palette, index, /*c=*/c,
                        /*palette_size=*/palette.w,
                        /*onerow=*/onerow, /*bit_depth=*/bit_depth);
                if (index < static_cast<int32_t>(nb_deltas)) {
                  PredictionResult pred = PredictNoTreeNoWP(
                      channel.w, p + x, onerow_image, x, y, predictor);
                  val = pred.guess + palette_entry;
                } else {
                  val = palette_entry;
                }
                p[x] = val;
              }
            }
          },
          "UndoDeltaPaletteNoWP"));
    }
  }
  if (c0 >= input.nb_meta_channels) {
    // Palette was done on normal channels
    input.nb_meta_channels--;
  } else {
    // Palette was done on metachannels
    JXL_ASSERT(static_cast<int>(input.nb_meta_channels) >= 2 - nb);
    input.nb_meta_channels -= 2 - nb;
    JXL_ASSERT(begin_c + nb - 1 < input.nb_meta_channels);
  }
  input.channel.erase(input.channel.begin(), input.channel.begin() + 1);
  return num_errors.load(std::memory_order_relaxed) == 0;
}

Status MetaPalette(Image &input, uint32_t begin_c, uint32_t end_c,
                   uint32_t nb_colors, uint32_t nb_deltas, bool lossy) {
  JXL_RETURN_IF_ERROR(CheckEqualChannels(input, begin_c, end_c));

  size_t nb = end_c - begin_c + 1;
  if (begin_c >= input.nb_meta_channels) {
    // Palette was done on normal channels
    input.nb_meta_channels++;
  } else {
    // Palette was done on metachannels
    JXL_ASSERT(end_c < input.nb_meta_channels);
    // we remove nb-1 metachannels and add one
    input.nb_meta_channels += 2 - nb;
  }
  input.channel.erase(input.channel.begin() + begin_c + 1,
                      input.channel.begin() + end_c + 1);
  Channel pch(nb_colors + nb_deltas, nb);
  pch.hshift = -1;
  pch.vshift = -1;
  input.channel.insert(input.channel.begin(), std::move(pch));
  return true;
}

}  // namespace jxl
