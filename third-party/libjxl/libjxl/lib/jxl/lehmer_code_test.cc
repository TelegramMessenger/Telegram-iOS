// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/lehmer_code.h"

#include <stdint.h>
#include <string.h>

#include <algorithm>
#include <numeric>
#include <vector>

#include "lib/jxl/base/bits.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

template <typename PermutationT>
struct WorkingSet {
  explicit WorkingSet(size_t max_n)
      : padded_n(1ull << CeilLog2Nonzero(max_n + 1)),
        permutation(max_n),
        temp(padded_n),
        lehmer(max_n),
        decoded(max_n) {}

  size_t padded_n;
  std::vector<PermutationT> permutation;
  std::vector<uint32_t> temp;
  std::vector<LehmerT> lehmer;
  std::vector<PermutationT> decoded;
};

template <typename PermutationT>
void Roundtrip(size_t n, WorkingSet<PermutationT>* ws) {
  JXL_ASSERT(n != 0);
  const size_t padded_n = 1ull << CeilLog2Nonzero(n);

  Rng rng(n * 65537 + 13);

  // Ensure indices fit into PermutationT
  EXPECT_LE(n, 1ULL << (sizeof(PermutationT) * 8));

  std::iota(ws->permutation.begin(), ws->permutation.begin() + n, 0);

  // For various random permutations:
  for (size_t rep = 0; rep < 3; ++rep) {
    rng.Shuffle(ws->permutation.data(), n);

    // Must decode to the same permutation
    ComputeLehmerCode(ws->permutation.data(), ws->temp.data(), n,
                      ws->lehmer.data());
    memset(ws->temp.data(), 0, padded_n * 4);
    DecodeLehmerCode(ws->lehmer.data(), ws->temp.data(), n, ws->decoded.data());

    for (size_t i = 0; i < n; ++i) {
      EXPECT_EQ(ws->permutation[i], ws->decoded[i]);
    }
  }
}

// Preallocates arrays and tests n = [begin, end).
template <typename PermutationT>
void RoundtripSizeRange(ThreadPool* pool, uint32_t begin, uint32_t end) {
  ASSERT_NE(0u, begin);  // n = 0 not allowed.
  std::vector<WorkingSet<PermutationT>> working_sets;

  JXL_CHECK(RunOnPool(
      pool, begin, end,
      [&working_sets, end](const size_t num_threads) {
        for (size_t i = 0; i < num_threads; i++) {
          working_sets.emplace_back(end - 1);
        }
        return true;
      },
      [&working_sets](const uint32_t n, const size_t thread) {
        Roundtrip(n, &working_sets[thread]);
      },
      "lehmer test"));
}

TEST(LehmerCodeTest, TestRoundtrips) {
  test::ThreadPoolForTests pool(8);

  RoundtripSizeRange<uint16_t>(&pool, 1, 1026);

  // Ensures PermutationT can fit > 16 bit values.
  RoundtripSizeRange<uint32_t>(&pool, 65536, 65540);
}

}  // namespace
}  // namespace jxl
