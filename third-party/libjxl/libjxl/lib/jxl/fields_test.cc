// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/fields.h"

#include <stddef.h>
#include <stdint.h>

#include <array>
#include <utility>

#include "lib/jxl/base/span.h"
#include "lib/jxl/common.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_fields.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/headers.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

// Ensures `value` round-trips and in exactly `expected_bits_written`.
void TestU32Coder(const uint32_t value, const size_t expected_bits_written) {
  const U32Enc enc(Val(0), Bits(4), Val(0x7FFFFFFF), Bits(32));

  BitWriter writer;
  BitWriter::Allotment allotment(
      &writer, RoundUpBitsToByteMultiple(U32Coder::MaxEncodedBits(enc)));

  size_t precheck_pos;
  EXPECT_TRUE(U32Coder::CanEncode(enc, value, &precheck_pos));
  EXPECT_EQ(expected_bits_written, precheck_pos);

  EXPECT_TRUE(U32Coder::Write(enc, value, &writer));
  EXPECT_EQ(expected_bits_written, writer.BitsWritten());
  writer.ZeroPadToByte();
  allotment.ReclaimAndCharge(&writer, 0, nullptr);

  BitReader reader(writer.GetSpan());
  const uint32_t decoded_value = U32Coder::Read(enc, &reader);
  EXPECT_EQ(value, decoded_value);
  EXPECT_TRUE(reader.Close());
}

TEST(FieldsTest, U32CoderTest) {
  TestU32Coder(0, 2);
  TestU32Coder(1, 6);
  TestU32Coder(15, 6);
  TestU32Coder(0x7FFFFFFF, 2);
  TestU32Coder(128, 34);
  TestU32Coder(0x7FFFFFFEu, 34);
  TestU32Coder(0x80000000u, 34);
  TestU32Coder(0xFFFFFFFFu, 34);
}

void TestU64Coder(const uint64_t value, const size_t expected_bits_written) {
  BitWriter writer;
  BitWriter::Allotment allotment(
      &writer, RoundUpBitsToByteMultiple(U64Coder::MaxEncodedBits()));

  size_t precheck_pos;
  EXPECT_TRUE(U64Coder::CanEncode(value, &precheck_pos));
  EXPECT_EQ(expected_bits_written, precheck_pos);

  EXPECT_TRUE(U64Coder::Write(value, &writer));
  EXPECT_EQ(expected_bits_written, writer.BitsWritten());

  writer.ZeroPadToByte();
  allotment.ReclaimAndCharge(&writer, 0, nullptr);

  BitReader reader(writer.GetSpan());
  const uint64_t decoded_value = U64Coder::Read(&reader);
  EXPECT_EQ(value, decoded_value);
  EXPECT_TRUE(reader.Close());
}

TEST(FieldsTest, U64CoderTest) {
  // Values that should take 2 bits (selector 00): 0
  TestU64Coder(0, 2);

  // Values that should take 6 bits (2 for selector, 4 for value): 1..16
  TestU64Coder(1, 6);
  TestU64Coder(2, 6);
  TestU64Coder(8, 6);
  TestU64Coder(15, 6);
  TestU64Coder(16, 6);

  // Values that should take 10 bits (2 for selector, 8 for value): 17..272
  TestU64Coder(17, 10);
  TestU64Coder(18, 10);
  TestU64Coder(100, 10);
  TestU64Coder(271, 10);
  TestU64Coder(272, 10);

  // Values that should take 15 bits (2 for selector, 12 for value, 1 for varint
  // end): (0)..273..4095
  TestU64Coder(273, 15);
  TestU64Coder(274, 15);
  TestU64Coder(1000, 15);
  TestU64Coder(4094, 15);
  TestU64Coder(4095, 15);

  // Take 24 bits (of which 20 actual value): (0)..4096..1048575
  TestU64Coder(4096, 24);
  TestU64Coder(4097, 24);
  TestU64Coder(10000, 24);
  TestU64Coder(1048574, 24);
  TestU64Coder(1048575, 24);

  // Take 33 bits (of which 28 actual value): (0)..1048576..268435455
  TestU64Coder(1048576, 33);
  TestU64Coder(1048577, 33);
  TestU64Coder(10000000, 33);
  TestU64Coder(268435454, 33);
  TestU64Coder(268435455, 33);

  // Take 42 bits (of which 36 actual value): (0)..268435456..68719476735
  TestU64Coder(268435456ull, 42);
  TestU64Coder(268435457ull, 42);
  TestU64Coder(1000000000ull, 42);
  TestU64Coder(68719476734ull, 42);
  TestU64Coder(68719476735ull, 42);

  // Take 51 bits (of which 44 actual value): (0)..68719476736..17592186044415
  TestU64Coder(68719476736ull, 51);
  TestU64Coder(68719476737ull, 51);
  TestU64Coder(1000000000000ull, 51);
  TestU64Coder(17592186044414ull, 51);
  TestU64Coder(17592186044415ull, 51);

  // Take 60 bits (of which 52 actual value):
  // (0)..17592186044416..4503599627370495
  TestU64Coder(17592186044416ull, 60);
  TestU64Coder(17592186044417ull, 60);
  TestU64Coder(100000000000000ull, 60);
  TestU64Coder(4503599627370494ull, 60);
  TestU64Coder(4503599627370495ull, 60);

  // Take 69 bits (of which 60 actual value):
  // (0)..4503599627370496..1152921504606846975
  TestU64Coder(4503599627370496ull, 69);
  TestU64Coder(4503599627370497ull, 69);
  TestU64Coder(10000000000000000ull, 69);
  TestU64Coder(1152921504606846974ull, 69);
  TestU64Coder(1152921504606846975ull, 69);

  // Take 73 bits (of which 64 actual value):
  // (0)..1152921504606846976..18446744073709551615
  TestU64Coder(1152921504606846976ull, 73);
  TestU64Coder(1152921504606846977ull, 73);
  TestU64Coder(10000000000000000000ull, 73);
  TestU64Coder(18446744073709551614ull, 73);
  TestU64Coder(18446744073709551615ull, 73);
}

Status TestF16Coder(const float value) {
  size_t max_encoded_bits;
  // It is not a fatal error if it can't be encoded.
  if (!F16Coder::CanEncode(value, &max_encoded_bits)) return false;
  EXPECT_EQ(F16Coder::MaxEncodedBits(), max_encoded_bits);

  BitWriter writer;
  BitWriter::Allotment allotment(&writer,
                                 RoundUpBitsToByteMultiple(max_encoded_bits));

  EXPECT_TRUE(F16Coder::Write(value, &writer));
  EXPECT_EQ(F16Coder::MaxEncodedBits(), writer.BitsWritten());
  writer.ZeroPadToByte();
  allotment.ReclaimAndCharge(&writer, 0, nullptr);

  BitReader reader(writer.GetSpan());
  float decoded_value;
  EXPECT_TRUE(F16Coder::Read(&reader, &decoded_value));
  // All values we test can be represented exactly.
  EXPECT_EQ(value, decoded_value);
  EXPECT_TRUE(reader.Close());
  return true;
}

TEST(FieldsTest, F16CoderTest) {
  for (float sign : {-1.0f, 1.0f}) {
    // (anything less than 1E-3 are subnormals)
    for (float mag : {0.0f, 0.5f, 1.0f, 2.0f, 2.5f, 16.015625f, 1.0f / 4096,
                      1.0f / 16384, 65504.0f}) {
      EXPECT_TRUE(TestF16Coder(sign * mag));
    }
  }

  // Out of range
  EXPECT_FALSE(TestF16Coder(65504.01f));
  EXPECT_FALSE(TestF16Coder(-65505.0f));
}

// Ensures Read(Write()) returns the same fields.
TEST(FieldsTest, TestRoundtripSize) {
  for (int i = 0; i < 8; i++) {
    SizeHeader size;
    ASSERT_TRUE(size.Set(123 + 77 * i, 7 + i));

    size_t extension_bits = 999, total_bits = 999;  // Initialize as garbage.
    ASSERT_TRUE(Bundle::CanEncode(size, &extension_bits, &total_bits));
    EXPECT_EQ(0u, extension_bits);

    BitWriter writer;
    ASSERT_TRUE(WriteSizeHeader(size, &writer, 0, nullptr));
    EXPECT_EQ(total_bits, writer.BitsWritten());
    writer.ZeroPadToByte();

    SizeHeader size2;
    BitReader reader(writer.GetSpan());
    ASSERT_TRUE(ReadSizeHeader(&reader, &size2));
    EXPECT_EQ(total_bits, reader.TotalBitsConsumed());
    EXPECT_TRUE(reader.Close());

    EXPECT_EQ(size.xsize(), size2.xsize());
    EXPECT_EQ(size.ysize(), size2.ysize());
  }
}

// Ensure all values can be reached by the encoding.
TEST(FieldsTest, TestCropRect) {
  CodecMetadata metadata;
  for (int32_t i = -999; i < 19000; ++i) {
    FrameHeader f(&metadata);
    f.custom_size_or_origin = true;
    f.frame_origin.x0 = i;
    f.frame_origin.y0 = i;
    f.frame_size.xsize = 1000 + i;
    f.frame_size.ysize = 1000 + i;
    size_t extension_bits = 0, total_bits = 0;
    ASSERT_TRUE(Bundle::CanEncode(f, &extension_bits, &total_bits));
    EXPECT_EQ(0u, extension_bits);
    EXPECT_GE(total_bits, 9u);
  }
}
TEST(FieldsTest, TestPreview) {
  // (div8 cannot represent 4360, but !div8 can go a little higher)
  for (uint32_t i = 1; i < 4360; ++i) {
    PreviewHeader p;
    ASSERT_TRUE(p.Set(i, i));
    size_t extension_bits = 0, total_bits = 0;
    ASSERT_TRUE(Bundle::CanEncode(p, &extension_bits, &total_bits));
    EXPECT_EQ(0u, extension_bits);
    EXPECT_GE(total_bits, 6u);
  }
}

// Ensures Read(Write()) returns the same fields.
TEST(FieldsTest, TestRoundtripFrame) {
  CodecMetadata metadata;
  FrameHeader h(&metadata);
  h.extensions = 0x800;

  size_t extension_bits = 999, total_bits = 999;  // Initialize as garbage.
  ASSERT_TRUE(Bundle::CanEncode(h, &extension_bits, &total_bits));
  EXPECT_EQ(0u, extension_bits);
  BitWriter writer;
  ASSERT_TRUE(WriteFrameHeader(h, &writer, nullptr));
  EXPECT_EQ(total_bits, writer.BitsWritten());
  writer.ZeroPadToByte();

  FrameHeader h2(&metadata);
  BitReader reader(writer.GetSpan());
  ASSERT_TRUE(ReadFrameHeader(&reader, &h2));
  EXPECT_EQ(total_bits, reader.TotalBitsConsumed());
  EXPECT_TRUE(reader.Close());

  EXPECT_EQ(h.extensions, h2.extensions);
  EXPECT_EQ(h.flags, h2.flags);
}

#ifndef JXL_CRASH_ON_ERROR
// Ensure out-of-bounds values cause an error.
TEST(FieldsTest, TestOutOfRange) {
  SizeHeader h;
  ASSERT_TRUE(h.Set(0xFFFFFFFFull, 0xFFFFFFFFull));
  size_t extension_bits = 999, total_bits = 999;  // Initialize as garbage.
  ASSERT_FALSE(Bundle::CanEncode(h, &extension_bits, &total_bits));
}
#endif

struct OldBundle : public Fields {
  OldBundle() { Bundle::Init(this); }
  JXL_FIELDS_NAME(OldBundle)

  Status VisitFields(Visitor* JXL_RESTRICT visitor) override {
    JXL_QUIET_RETURN_IF_ERROR(
        visitor->U32(Val(1), Bits(2), Bits(3), Bits(4), 1, &old_small));
    JXL_QUIET_RETURN_IF_ERROR(visitor->F16(1.125f, &old_f));
    JXL_QUIET_RETURN_IF_ERROR(
        visitor->U32(Bits(7), Bits(12), Bits(16), Bits(32), 0, &old_large));

    JXL_QUIET_RETURN_IF_ERROR(visitor->BeginExtensions(&extensions));
    return visitor->EndExtensions();
  }

  uint32_t old_small;
  float old_f;
  uint32_t old_large;
  uint64_t extensions;
};

struct NewBundle : public Fields {
  NewBundle() { Bundle::Init(this); }
  JXL_FIELDS_NAME(NewBundle)

  Status VisitFields(Visitor* JXL_RESTRICT visitor) override {
    JXL_QUIET_RETURN_IF_ERROR(
        visitor->U32(Val(1), Bits(2), Bits(3), Bits(4), 1, &old_small));
    JXL_QUIET_RETURN_IF_ERROR(visitor->F16(1.125f, &old_f));
    JXL_QUIET_RETURN_IF_ERROR(
        visitor->U32(Bits(7), Bits(12), Bits(16), Bits(32), 0, &old_large));

    JXL_QUIET_RETURN_IF_ERROR(visitor->BeginExtensions(&extensions));
    if (visitor->Conditional(extensions & 1)) {
      JXL_QUIET_RETURN_IF_ERROR(
          visitor->U32(Val(2), Bits(2), Bits(3), Bits(4), 2, &new_small));
      JXL_QUIET_RETURN_IF_ERROR(visitor->F16(-2.0f, &new_f));
    }
    if (visitor->Conditional(extensions & 2)) {
      JXL_QUIET_RETURN_IF_ERROR(
          visitor->U32(Bits(9), Bits(12), Bits(16), Bits(32), 0, &new_large));
    }
    return visitor->EndExtensions();
  }

  uint32_t old_small;
  float old_f;
  uint32_t old_large;
  uint64_t extensions;

  // If extensions & 1
  uint32_t new_small = 2;
  float new_f = -2.0f;
  // If extensions & 2
  uint32_t new_large = 0;
};

TEST(FieldsTest, TestNewDecoderOldData) {
  OldBundle old_bundle;
  old_bundle.old_large = 123;
  old_bundle.old_f = 3.75f;
  old_bundle.extensions = 0;

  // Write to bit stream
  const size_t kMaxOutBytes = 999;
  BitWriter writer;
  // Make sure values are initialized by code under test.
  size_t extension_bits = 12345, total_bits = 12345;
  ASSERT_TRUE(Bundle::CanEncode(old_bundle, &extension_bits, &total_bits));
  ASSERT_LE(total_bits, kMaxOutBytes * kBitsPerByte);
  EXPECT_EQ(0u, extension_bits);
  AuxOut aux_out;
  ASSERT_TRUE(Bundle::Write(old_bundle, &writer, kLayerHeader, &aux_out));

  BitWriter::Allotment allotment(&writer,
                                 kMaxOutBytes * kBitsPerByte - total_bits);
  writer.Write(20, 0xA55A);  // sentinel
  writer.ZeroPadToByte();
  allotment.ReclaimAndCharge(&writer, kLayerHeader, nullptr);

  ASSERT_LE(writer.GetSpan().size(), kMaxOutBytes);
  BitReader reader(writer.GetSpan());
  NewBundle new_bundle;
  ASSERT_TRUE(Bundle::Read(&reader, &new_bundle));
  EXPECT_EQ(reader.TotalBitsConsumed(),
            aux_out.layers[kLayerHeader].total_bits);
  EXPECT_EQ(reader.ReadBits(20), 0xA55Au);
  EXPECT_TRUE(reader.Close());

  // Old fields are the same in both
  EXPECT_EQ(old_bundle.extensions, new_bundle.extensions);
  EXPECT_EQ(old_bundle.old_small, new_bundle.old_small);
  EXPECT_EQ(old_bundle.old_f, new_bundle.old_f);
  EXPECT_EQ(old_bundle.old_large, new_bundle.old_large);
  // New fields match their defaults
  EXPECT_EQ(2u, new_bundle.new_small);
  EXPECT_EQ(-2.0f, new_bundle.new_f);
  EXPECT_EQ(0u, new_bundle.new_large);
}

TEST(FieldsTest, TestOldDecoderNewData) {
  NewBundle new_bundle;
  new_bundle.old_large = 123;
  new_bundle.extensions = 3;
  new_bundle.new_f = 999.0f;
  new_bundle.new_large = 456;

  // Write to bit stream
  constexpr size_t kMaxOutBytes = 999;
  BitWriter writer;
  // Make sure values are initialized by code under test.
  size_t extension_bits = 12345, total_bits = 12345;
  ASSERT_TRUE(Bundle::CanEncode(new_bundle, &extension_bits, &total_bits));
  EXPECT_NE(0u, extension_bits);
  AuxOut aux_out;
  ASSERT_TRUE(Bundle::Write(new_bundle, &writer, kLayerHeader, &aux_out));
  ASSERT_LE(aux_out.layers[kLayerHeader].total_bits,
            kMaxOutBytes * kBitsPerByte);

  BitWriter::Allotment allotment(
      &writer,
      kMaxOutBytes * kBitsPerByte - aux_out.layers[kLayerHeader].total_bits);
  // Ensure Read skips the additional fields
  writer.Write(20, 0xA55A);  // sentinel
  writer.ZeroPadToByte();
  allotment.ReclaimAndCharge(&writer, kLayerHeader, nullptr);

  BitReader reader(writer.GetSpan());
  OldBundle old_bundle;
  ASSERT_TRUE(Bundle::Read(&reader, &old_bundle));
  EXPECT_EQ(reader.TotalBitsConsumed(),
            aux_out.layers[kLayerHeader].total_bits);
  EXPECT_EQ(reader.ReadBits(20), 0xA55Au);
  EXPECT_TRUE(reader.Close());

  // Old fields are the same in both
  EXPECT_EQ(new_bundle.extensions, old_bundle.extensions);
  EXPECT_EQ(new_bundle.old_small, old_bundle.old_small);
  EXPECT_EQ(new_bundle.old_f, old_bundle.old_f);
  EXPECT_EQ(new_bundle.old_large, old_bundle.old_large);
  // (Can't check new fields because old decoder doesn't know about them)
}

}  // namespace
}  // namespace jxl
