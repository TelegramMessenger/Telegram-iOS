// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jxl/ans_params.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/dec_ans.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/enc_ans.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

void RoundtripTestcase(int n_histograms, int alphabet_size,
                       const std::vector<Token>& input_values) {
  constexpr uint16_t kMagic1 = 0x9e33;
  constexpr uint16_t kMagic2 = 0x8b04;

  BitWriter writer;
  // Space for magic bytes.
  BitWriter::Allotment allotment_magic1(&writer, 16);
  writer.Write(16, kMagic1);
  allotment_magic1.ReclaimAndCharge(&writer, 0, nullptr);

  std::vector<uint8_t> context_map;
  EntropyEncodingData codes;
  std::vector<std::vector<Token>> input_values_vec;
  input_values_vec.push_back(input_values);

  BuildAndEncodeHistograms(HistogramParams(), n_histograms, input_values_vec,
                           &codes, &context_map, &writer, 0, nullptr);
  WriteTokens(input_values_vec[0], codes, context_map, &writer, 0, nullptr);

  // Magic bytes + padding
  BitWriter::Allotment allotment_magic2(&writer, 24);
  writer.Write(16, kMagic2);
  writer.ZeroPadToByte();
  allotment_magic2.ReclaimAndCharge(&writer, 0, nullptr);

  // We do not truncate the output. Reading past the end reads out zeroes
  // anyway.
  BitReader br(writer.GetSpan());

  ASSERT_EQ(br.ReadBits(16), kMagic1);

  std::vector<uint8_t> dec_context_map;
  ANSCode decoded_codes;
  ASSERT_TRUE(
      DecodeHistograms(&br, n_histograms, &decoded_codes, &dec_context_map));
  ASSERT_EQ(dec_context_map, context_map);
  ANSSymbolReader reader(&decoded_codes, &br);

  for (const Token& symbol : input_values) {
    uint32_t read_symbol =
        reader.ReadHybridUint(symbol.context, &br, dec_context_map);
    ASSERT_EQ(read_symbol, symbol.value);
  }
  ASSERT_TRUE(reader.CheckANSFinalState());

  ASSERT_EQ(br.ReadBits(16), kMagic2);
  EXPECT_TRUE(br.Close());
}

TEST(ANSTest, EmptyRoundtrip) {
  RoundtripTestcase(2, ANS_MAX_ALPHABET_SIZE, std::vector<Token>());
}

TEST(ANSTest, SingleSymbolRoundtrip) {
  for (uint32_t i = 0; i < ANS_MAX_ALPHABET_SIZE; i++) {
    RoundtripTestcase(2, ANS_MAX_ALPHABET_SIZE, {{0, i}});
  }
  for (uint32_t i = 0; i < ANS_MAX_ALPHABET_SIZE; i++) {
    RoundtripTestcase(2, ANS_MAX_ALPHABET_SIZE,
                      std::vector<Token>(1024, {0, i}));
  }
}

#if defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER) || \
    defined(THREAD_SANITIZER)
constexpr size_t kReps = 3;
#else
constexpr size_t kReps = 10;
#endif

void RoundtripRandomStream(int alphabet_size, size_t reps = kReps,
                           size_t num = 1 << 18) {
  constexpr int kNumHistograms = 3;
  Rng rng(0);
  for (size_t i = 0; i < reps; i++) {
    std::vector<Token> symbols;
    for (size_t j = 0; j < num; j++) {
      int context = rng.UniformI(0, kNumHistograms);
      int value = rng.UniformU(0, alphabet_size);
      symbols.emplace_back(context, value);
    }
    RoundtripTestcase(kNumHistograms, alphabet_size, symbols);
  }
}

void RoundtripRandomUnbalancedStream(int alphabet_size) {
  constexpr int kNumHistograms = 3;
  constexpr int kPrecision = 1 << 10;
  Rng rng(0);
  for (size_t i = 0; i < kReps; i++) {
    std::vector<int> distributions[kNumHistograms] = {};
    for (int j = 0; j < kNumHistograms; j++) {
      distributions[j].resize(kPrecision);
      int symbol = 0;
      int remaining = 1;
      for (int k = 0; k < kPrecision; k++) {
        if (remaining == 0) {
          if (symbol < alphabet_size - 1) symbol++;
          // There is no meaning behind this distribution: it's anything that
          // will create a nonuniform distribution and won't have too few
          // symbols usually. Also we want different distributions we get to be
          // sufficiently dissimilar.
          remaining = rng.UniformU(0, kPrecision - k + 1);
        }
        distributions[j][k] = symbol;
        remaining--;
      }
    }
    std::vector<Token> symbols;
    for (int j = 0; j < 1 << 18; j++) {
      int context = rng.UniformI(0, kNumHistograms);
      int value = rng.UniformU(0, kPrecision);
      symbols.emplace_back(context, value);
    }
    RoundtripTestcase(kNumHistograms + 1, alphabet_size, symbols);
  }
}

TEST(ANSTest, RandomStreamRoundtrip3Small) { RoundtripRandomStream(3, 1, 16); }

TEST(ANSTest, RandomStreamRoundtrip3) { RoundtripRandomStream(3); }

TEST(ANSTest, RandomStreamRoundtripBig) {
  RoundtripRandomStream(ANS_MAX_ALPHABET_SIZE);
}

TEST(ANSTest, RandomUnbalancedStreamRoundtrip3) {
  RoundtripRandomUnbalancedStream(3);
}

TEST(ANSTest, RandomUnbalancedStreamRoundtripBig) {
  RoundtripRandomUnbalancedStream(ANS_MAX_ALPHABET_SIZE);
}

TEST(ANSTest, UintConfigRoundtrip) {
  for (size_t log_alpha_size = 5; log_alpha_size <= 8; log_alpha_size++) {
    std::vector<HybridUintConfig> uint_config, uint_config_dec;
    for (size_t i = 0; i < log_alpha_size; i++) {
      for (size_t j = 0; j <= i; j++) {
        for (size_t k = 0; k <= i - j; k++) {
          uint_config.emplace_back(i, j, k);
        }
      }
    }
    uint_config.emplace_back(log_alpha_size, 0, 0);
    uint_config_dec.resize(uint_config.size());
    BitWriter writer;
    BitWriter::Allotment allotment(&writer, 10 * uint_config.size());
    EncodeUintConfigs(uint_config, &writer, log_alpha_size);
    allotment.ReclaimAndCharge(&writer, 0, nullptr);
    writer.ZeroPadToByte();
    BitReader br(writer.GetSpan());
    EXPECT_TRUE(DecodeUintConfigs(log_alpha_size, &uint_config_dec, &br));
    EXPECT_TRUE(br.Close());
    for (size_t i = 0; i < uint_config.size(); i++) {
      EXPECT_EQ(uint_config[i].split_token, uint_config_dec[i].split_token);
      EXPECT_EQ(uint_config[i].msb_in_token, uint_config_dec[i].msb_in_token);
      EXPECT_EQ(uint_config[i].lsb_in_token, uint_config_dec[i].lsb_in_token);
    }
  }
}

void TestCheckpointing(bool ans, bool lz77) {
  std::vector<std::vector<Token>> input_values(1);
  for (size_t i = 0; i < 1024; i++) {
    input_values[0].push_back(Token(0, i % 4));
  }
  // up to lz77 window size.
  for (size_t i = 0; i < (1 << 20) - 1022; i++) {
    input_values[0].push_back(Token(0, (i % 5) + 4));
  }
  // Ensure that when the window wraps around, new values are different.
  input_values[0].push_back(Token(0, 0));
  for (size_t i = 0; i < 1024; i++) {
    input_values[0].push_back(Token(0, i % 4));
  }

  std::vector<uint8_t> context_map;
  EntropyEncodingData codes;
  HistogramParams params;
  params.lz77_method = lz77 ? HistogramParams::LZ77Method::kLZ77
                            : HistogramParams::LZ77Method::kNone;
  params.force_huffman = !ans;

  BitWriter writer;
  {
    auto input_values_copy = input_values;
    BuildAndEncodeHistograms(params, 1, input_values_copy, &codes, &context_map,
                             &writer, 0, nullptr);
    WriteTokens(input_values_copy[0], codes, context_map, &writer, 0, nullptr);
    writer.ZeroPadToByte();
  }

  // We do not truncate the output. Reading past the end reads out zeroes
  // anyway.
  BitReader br(writer.GetSpan());
  Status status = true;
  {
    BitReaderScopedCloser bc(&br, &status);

    std::vector<uint8_t> dec_context_map;
    ANSCode decoded_codes;
    ASSERT_TRUE(DecodeHistograms(&br, 1, &decoded_codes, &dec_context_map));
    ASSERT_EQ(dec_context_map, context_map);
    ANSSymbolReader reader(&decoded_codes, &br);

    ANSSymbolReader::Checkpoint checkpoint;
    size_t br_pos = 0;
    constexpr size_t kInterval = ANSSymbolReader::kMaxCheckpointInterval - 2;
    for (size_t i = 0; i < input_values[0].size(); i++) {
      if (i % kInterval == 0 && i > 0) {
        reader.Restore(checkpoint);
        ASSERT_TRUE(br.Close());
        br = BitReader(writer.GetSpan());
        br.SkipBits(br_pos);
        for (size_t j = i - kInterval; j < i; j++) {
          Token symbol = input_values[0][j];
          uint32_t read_symbol =
              reader.ReadHybridUint(symbol.context, &br, dec_context_map);
          ASSERT_EQ(read_symbol, symbol.value) << "j = " << j;
        }
      }
      if (i % kInterval == 0) {
        reader.Save(&checkpoint);
        br_pos = br.TotalBitsConsumed();
      }
      Token symbol = input_values[0][i];
      uint32_t read_symbol =
          reader.ReadHybridUint(symbol.context, &br, dec_context_map);
      ASSERT_EQ(read_symbol, symbol.value) << "i = " << i;
    }
    ASSERT_TRUE(reader.CheckANSFinalState());
  }
  EXPECT_TRUE(status);
}

TEST(ANSTest, TestCheckpointingANS) {
  TestCheckpointing(/*ans=*/true, /*lz77=*/false);
}

TEST(ANSTest, TestCheckpointingPrefix) {
  TestCheckpointing(/*ans=*/false, /*lz77=*/false);
}

TEST(ANSTest, TestCheckpointingANSLZ77) {
  TestCheckpointing(/*ans=*/true, /*lz77=*/true);
}

TEST(ANSTest, TestCheckpointingPrefixLZ77) {
  TestCheckpointing(/*ans=*/false, /*lz77=*/true);
}

}  // namespace
}  // namespace jxl
