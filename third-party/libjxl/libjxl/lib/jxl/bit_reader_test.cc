// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stddef.h>
#include <stdint.h>

#include <array>
#include <vector>

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

TEST(BitReaderTest, ExtendsWithZeroes) {
  for (size_t size = 4; size < 32; ++size) {
    std::vector<uint8_t> data(size, 0xff);

    for (size_t n_bytes = 0; n_bytes < size; n_bytes++) {
      BitReader br(Span<const uint8_t>(data.data(), n_bytes));
      // Read all the bits
      for (size_t i = 0; i < n_bytes * kBitsPerByte; i++) {
        ASSERT_EQ(br.ReadBits(1), 1u) << "n_bytes=" << n_bytes << " i=" << i;
      }

      // PEEK more than the declared size - all will be zero. Cannot consume.
      for (size_t i = 0; i < BitReader::kMaxBitsPerCall; i++) {
        ASSERT_EQ(br.PeekBits(i), 0u)
            << "size=" << size << "n_bytes=" << n_bytes << " i=" << i;
      }

      EXPECT_TRUE(br.Close());
    }
  }
}

struct Symbol {
  uint32_t num_bits;
  uint32_t value;
};

// Reading from output gives the same values.
TEST(BitReaderTest, TestRoundTrip) {
  test::ThreadPoolForTests pool(8);
  EXPECT_TRUE(RunOnPool(
      &pool, 0, 1000, ThreadPool::NoInit,
      [](const uint32_t task, size_t /* thread */) {
        constexpr size_t kMaxBits = 8000;
        BitWriter writer;
        BitWriter::Allotment allotment(&writer, kMaxBits);

        std::vector<Symbol> symbols;
        symbols.reserve(1000);

        Rng rng(55537 + 129 * task);

        for (;;) {
          const uint32_t num_bits = rng.UniformU(1, 33);
          if (writer.BitsWritten() + num_bits > kMaxBits) break;
          const uint32_t value = rng.UniformU(0, 1ULL << num_bits);
          symbols.push_back({num_bits, value});
          writer.Write(num_bits, value);
        }

        writer.ZeroPadToByte();
        allotment.ReclaimAndCharge(&writer, 0, nullptr);
        BitReader reader(writer.GetSpan());
        for (const Symbol& s : symbols) {
          EXPECT_EQ(s.value, reader.ReadBits(s.num_bits));
        }
        EXPECT_TRUE(reader.Close());
      },
      "TestTBitReaderRoundTrip"));
}

// SkipBits is the same as reading that many bits.
TEST(BitReaderTest, TestSkip) {
  test::ThreadPoolForTests pool(8);
  EXPECT_TRUE(RunOnPool(
      &pool, 0, 96, ThreadPool::NoInit,
      [](const uint32_t task, size_t /* thread */) {
        constexpr size_t kSize = 100;

        for (size_t skip = 0; skip < 128; ++skip) {
          BitWriter writer;
          BitWriter::Allotment allotment(&writer, kSize * kBitsPerByte);
          // Start with "task" 1-bits.
          for (size_t i = 0; i < task; ++i) {
            writer.Write(1, 1);
          }

          // Write 0-bits that we will skip over
          for (size_t i = 0; i < skip; ++i) {
            writer.Write(1, 0);
          }

          // Write terminator bits '101'
          writer.Write(3, 5);
          EXPECT_EQ(task + skip + 3, writer.BitsWritten());
          writer.ZeroPadToByte();
          AuxOut aux_out;
          allotment.ReclaimAndCharge(&writer, 0, &aux_out);
          EXPECT_LT(aux_out.layers[0].total_bits, kSize * 8);

          BitReader reader1(writer.GetSpan());
          BitReader reader2(writer.GetSpan());
          // Verify initial 1-bits
          for (size_t i = 0; i < task; ++i) {
            EXPECT_EQ(1u, reader1.ReadBits(1));
            EXPECT_EQ(1u, reader2.ReadBits(1));
          }

          // SkipBits or manually read "skip" bits
          reader1.SkipBits(skip);
          for (size_t i = 0; i < skip; ++i) {
            EXPECT_EQ(0u, reader2.ReadBits(1))
                << " skip=" << skip << " i=" << i;
          }
          EXPECT_EQ(reader1.TotalBitsConsumed(), reader2.TotalBitsConsumed());

          // Ensure both readers see the terminator bits.
          EXPECT_EQ(5u, reader1.ReadBits(3));
          EXPECT_EQ(5u, reader2.ReadBits(3));

          EXPECT_TRUE(reader1.Close());
          EXPECT_TRUE(reader2.Close());
        }
      },
      "TestSkip"));
}

// Verifies byte order and different groupings of bits.
TEST(BitReaderTest, TestOrder) {
  constexpr size_t kMaxBits = 16;

  // u(1) - bits written into LSBs of first byte
  {
    BitWriter writer;
    BitWriter::Allotment allotment(&writer, kMaxBits);
    for (size_t i = 0; i < 5; ++i) {
      writer.Write(1, 1);
    }
    for (size_t i = 0; i < 5; ++i) {
      writer.Write(1, 0);
    }
    for (size_t i = 0; i < 6; ++i) {
      writer.Write(1, 1);
    }

    writer.ZeroPadToByte();
    allotment.ReclaimAndCharge(&writer, 0, nullptr);
    BitReader reader(writer.GetSpan());
    EXPECT_EQ(0x1Fu, reader.ReadFixedBits<8>());
    EXPECT_EQ(0xFCu, reader.ReadFixedBits<8>());
    EXPECT_TRUE(reader.Close());
  }

  // u(8) - get bytes in the same order
  {
    BitWriter writer;
    BitWriter::Allotment allotment(&writer, kMaxBits);
    writer.Write(8, 0xF8);
    writer.Write(8, 0x3F);

    writer.ZeroPadToByte();
    allotment.ReclaimAndCharge(&writer, 0, nullptr);
    BitReader reader(writer.GetSpan());
    EXPECT_EQ(0xF8u, reader.ReadFixedBits<8>());
    EXPECT_EQ(0x3Fu, reader.ReadFixedBits<8>());
    EXPECT_TRUE(reader.Close());
  }

  // u(16) - little-endian bytes
  {
    BitWriter writer;
    BitWriter::Allotment allotment(&writer, kMaxBits);
    writer.Write(16, 0xF83F);

    writer.ZeroPadToByte();
    allotment.ReclaimAndCharge(&writer, 0, nullptr);
    BitReader reader(writer.GetSpan());
    EXPECT_EQ(0x3Fu, reader.ReadFixedBits<8>());
    EXPECT_EQ(0xF8u, reader.ReadFixedBits<8>());
    EXPECT_TRUE(reader.Close());
  }

  // Non-byte-aligned, mixed sizes
  {
    BitWriter writer;
    BitWriter::Allotment allotment(&writer, kMaxBits);
    writer.Write(1, 1);
    writer.Write(3, 6);
    writer.Write(8, 0xDB);
    writer.Write(4, 8);

    writer.ZeroPadToByte();
    allotment.ReclaimAndCharge(&writer, 0, nullptr);
    BitReader reader(writer.GetSpan());
    EXPECT_EQ(0xBDu, reader.ReadFixedBits<8>());
    EXPECT_EQ(0x8Du, reader.ReadFixedBits<8>());
    EXPECT_TRUE(reader.Close());
  }
}

TEST(BitReaderTest, TotalCountersTest) {
  uint8_t buf[8] = {1, 2, 3, 4};
  BitReader reader(Span<const uint8_t>(buf, sizeof(buf)));

  EXPECT_EQ(sizeof(buf), reader.TotalBytes());
  EXPECT_EQ(0u, reader.TotalBitsConsumed());
  reader.ReadFixedBits<1>();
  EXPECT_EQ(1u, reader.TotalBitsConsumed());

  reader.ReadFixedBits<10>();
  EXPECT_EQ(11u, reader.TotalBitsConsumed());

  reader.ReadFixedBits<4>();
  EXPECT_EQ(15u, reader.TotalBitsConsumed());

  reader.ReadFixedBits<1>();
  EXPECT_EQ(16u, reader.TotalBitsConsumed());

  reader.ReadFixedBits<16>();
  EXPECT_EQ(32u, reader.TotalBitsConsumed());

  EXPECT_TRUE(reader.Close());
}

TEST(BitReaderTest, MoveTest) {
  uint8_t buf[8] = {1, 2, 3, 4};
  BitReader reader2;
  {
    BitReader reader1(Span<const uint8_t>(buf, sizeof(buf)));

    EXPECT_EQ(0u, reader1.TotalBitsConsumed());
    reader1.ReadFixedBits<16>();
    EXPECT_EQ(16u, reader1.TotalBitsConsumed());

    reader2 = std::move(reader1);
    // From this point reader1 is invalid, but can continue to access reader2
    // and we don't need to call Close() on reader1.
  }

  EXPECT_EQ(16u, reader2.TotalBitsConsumed());
  EXPECT_EQ(3U, reader2.ReadFixedBits<8>());
  EXPECT_EQ(24u, reader2.TotalBitsConsumed());

  EXPECT_TRUE(reader2.Close());
}

}  // namespace
}  // namespace jxl
