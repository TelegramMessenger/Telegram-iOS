// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/toc.h"

#include "lib/jxl/base/random.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/common.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_toc.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

void Roundtrip(size_t num_entries, bool permute, Rng* rng) {
  // Generate a random permutation.
  std::vector<coeff_order_t> permutation(num_entries);
  std::vector<coeff_order_t> inv_permutation(num_entries);
  for (size_t i = 0; i < num_entries; i++) {
    permutation[i] = i;
    inv_permutation[i] = i;
  }
  if (permute) {
    rng->Shuffle(permutation.data(), permutation.size());
    for (size_t i = 0; i < num_entries; i++) {
      inv_permutation[permutation[i]] = i;
    }
  }

  // Generate num_entries groups of random (byte-aligned) length
  std::vector<BitWriter> group_codes(num_entries);
  for (BitWriter& writer : group_codes) {
    const size_t max_bits = (*rng)() & 0xFFF;
    BitWriter::Allotment allotment(&writer, max_bits + kBitsPerByte);
    size_t i = 0;
    for (; i + BitWriter::kMaxBitsPerCall < max_bits;
         i += BitWriter::kMaxBitsPerCall) {
      writer.Write(BitWriter::kMaxBitsPerCall, 0);
    }
    for (; i < max_bits; i += 1) {
      writer.Write(/*n_bits=*/1, 0);
    }
    writer.ZeroPadToByte();
    AuxOut aux_out;
    allotment.ReclaimAndCharge(&writer, 0, &aux_out);
  }

  BitWriter writer;
  AuxOut aux_out;
  ASSERT_TRUE(WriteGroupOffsets(group_codes, permute ? &permutation : nullptr,
                                &writer, &aux_out));

  BitReader reader(writer.GetSpan());
  std::vector<uint64_t> group_offsets;
  std::vector<uint32_t> group_sizes;
  uint64_t total_size;
  ASSERT_TRUE(ReadGroupOffsets(num_entries, &reader, &group_offsets,
                               &group_sizes, &total_size));
  ASSERT_EQ(num_entries, group_offsets.size());
  ASSERT_EQ(num_entries, group_sizes.size());
  EXPECT_TRUE(reader.Close());

  uint64_t prefix_sum = 0;
  for (size_t i = 0; i < num_entries; ++i) {
    EXPECT_EQ(prefix_sum, group_offsets[inv_permutation[i]]);

    EXPECT_EQ(0u, group_codes[i].BitsWritten() % kBitsPerByte);
    prefix_sum += group_codes[i].BitsWritten() / kBitsPerByte;

    if (i + 1 < num_entries) {
      EXPECT_EQ(
          group_offsets[inv_permutation[i]] + group_sizes[inv_permutation[i]],
          group_offsets[inv_permutation[i + 1]]);
    }
  }
  EXPECT_EQ(prefix_sum, total_size);
}

TEST(TocTest, Test) {
  Rng rng(0);
  for (size_t num_entries = 1; num_entries < 10; ++num_entries) {
    for (bool permute : std::vector<bool>{false, true}) {
      Roundtrip(num_entries, permute, &rng);
    }
  }
}

}  // namespace
}  // namespace jxl
