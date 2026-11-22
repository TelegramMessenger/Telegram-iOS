// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdint.h>

#include "lib/jxl/base/random.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/modular/encoding/encoding.h"
#include "lib/jxl/modular/transform/transform.h"

namespace jpegxl {
namespace tools {

using ::jxl::BitReader;
using ::jxl::BitReaderScopedCloser;
using ::jxl::Channel;
using ::jxl::GroupHeader;
using ::jxl::Image;
using ::jxl::ModularOptions;
using ::jxl::pixel_type;
using ::jxl::Rng;
using ::jxl::Span;
using ::jxl::Status;
using ::jxl::Transform;
using ::jxl::weighted::Header;

namespace {
void FillChannel(Channel& ch, Rng& rng) {
  auto p = &ch.plane;
  const size_t w = ch.w;
  const size_t h = ch.h;
  for (size_t y = 0; y < h; ++y) {
    pixel_type* row = p->Row(y);
    for (size_t x = 0; x < w; ++x) {
      row[x] = rng.UniformU(0, 0x80000000);
    }
  }
}
template <typename T>
void AssertEq(T a, T b) {
  if (a != b) __builtin_trap();
}
}  // namespace

int TestOneInput(const uint8_t* data, size_t size) {
  static Status nevermind = true;
  BitReader reader(Span<const uint8_t>(data, size));
  BitReaderScopedCloser reader_closer(&reader, &nevermind);

  Rng rng(reader.ReadFixedBits<56>());

  // One of {0, 1, _2_, 3}; "2" will be filtered out soon.
  size_t nb_chans = static_cast<size_t>(reader.ReadFixedBits<8>()) & 0x3;
  size_t nb_extra = static_cast<size_t>(reader.ReadFixedBits<8>()) & 0x7;
  // 1..32
  size_t bit_depth =
      (static_cast<size_t>(reader.ReadFixedBits<8>()) & 0x1F) + 1;
  // {0, 1, 2, 3}
  size_t log_upsampling =
      (static_cast<size_t>(reader.ReadFixedBits<8>()) & 0x3);
  size_t upsampling = 1 << log_upsampling;

  size_t w_orig = static_cast<size_t>(reader.ReadFixedBits<16>());
  size_t h_orig = static_cast<size_t>(reader.ReadFixedBits<16>());
  size_t w = jxl::DivCeil(w_orig, upsampling);
  size_t h = jxl::DivCeil(h_orig, upsampling);

  if ((nb_chans == 2) || ((nb_chans + nb_extra) == 0) || (w * h == 0) ||
      ((w_orig * h_orig * (nb_chans + nb_extra)) > (1 << 23))) {
    return 0;
  }

  std::vector<int> hshift;
  std::vector<int> vshift;
  std::vector<size_t> ec_upsampling;

  for (size_t c = 0; c < nb_chans; c++) {
    hshift.push_back(static_cast<int>(reader.ReadFixedBits<8>()) & 1);
    vshift.push_back(static_cast<int>(reader.ReadFixedBits<8>()) & 1);
  }

  for (size_t ec = 0; ec < nb_extra; ec++) {
    size_t log_ec_upsampling =
        (static_cast<size_t>(reader.ReadFixedBits<8>()) & 0x3);
    log_ec_upsampling = std::max(log_ec_upsampling, log_upsampling);
    ec_upsampling.push_back(1 << log_ec_upsampling);
  }

  Image image(w, h, bit_depth, nb_chans + nb_extra);

  for (size_t c = 0; c < nb_chans; c++) {
    Channel& ch = image.channel[c];
    ch.hshift = hshift[c];
    ch.vshift = vshift[c];
    ch.shrink(jxl::DivCeil(w, 1 << hshift[c]), jxl::DivCeil(h, 1 << vshift[c]));
  }

  for (size_t ec = 0; ec < nb_extra; ec++) {
    Channel& ch = image.channel[ec + nb_chans];
    size_t ch_up = ec_upsampling[ec];
    int up_level =
        jxl::CeilLog2Nonzero(ch_up) - jxl::CeilLog2Nonzero(upsampling);
    ch.shrink(jxl::DivCeil(w_orig, ch_up), jxl::DivCeil(h_orig, ch_up));
    ch.hshift = ch.vshift = up_level;
  }

  GroupHeader header;
  if (!jxl::Bundle::Read(&reader, &header)) return 0;
  Header w_header;
  if (!jxl::Bundle::Read(&reader, &w_header)) return 0;

  // TODO(eustas): give it a try?
  if (!reader.AllReadsWithinBounds()) return 0;

  image.transform = header.transforms;
  for (Transform& transform : image.transform) {
    if (!transform.MetaApply(image)) return 0;
  }
  if (image.error) return 0;

  ModularOptions options;
  if (!ValidateChannelDimensions(image, options)) return 0;

  for (size_t i = 0; i < image.channel.size(); ++i) {
    FillChannel(image.channel[i], rng);
  }

  image.undo_transforms(w_header);

  AssertEq(image.error, false);
  AssertEq<size_t>(image.nb_meta_channels, 0);
  AssertEq(image.channel.size(), nb_chans + nb_extra);

  for (size_t c = 0; c < nb_chans; c++) {
    const Channel& ch = image.channel[c];
    AssertEq(ch.hshift, hshift[c]);
    AssertEq(ch.vshift, vshift[c]);
    AssertEq(ch.w, jxl::DivCeil(w, 1 << hshift[c]));
    AssertEq(ch.h, jxl::DivCeil(h, 1 << vshift[c]));
  }

  for (size_t ec = 0; ec < nb_extra; ec++) {
    const Channel& ch = image.channel[ec + nb_chans];
    size_t ch_up = ec_upsampling[ec];
    int up_level =
        jxl::CeilLog2Nonzero(ch_up) - jxl::CeilLog2Nonzero(upsampling);
    AssertEq(ch.w, jxl::DivCeil(w_orig, ch_up));
    AssertEq(ch.h, jxl::DivCeil(h_orig, ch_up));
    AssertEq(ch.hshift, up_level);
    AssertEq(ch.vshift, up_level);
  }

  return 0;
}

}  // namespace tools
}  // namespace jpegxl

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  return jpegxl::tools::TestOneInput(data, size);
}
