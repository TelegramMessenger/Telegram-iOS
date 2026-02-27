// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_bit_writer.h"

#include <string.h>  // memcpy

#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/enc_aux_out.h"

namespace jxl {

BitWriter::Allotment::Allotment(BitWriter* JXL_RESTRICT writer, size_t max_bits)
    : max_bits_(max_bits) {
  if (writer == nullptr) return;
  prev_bits_written_ = writer->BitsWritten();
  const size_t prev_bytes = writer->storage_.size();
  const size_t next_bytes = DivCeil(max_bits, kBitsPerByte);
  writer->storage_.resize(prev_bytes + next_bytes);
  parent_ = writer->current_allotment_;
  writer->current_allotment_ = this;
}

BitWriter::Allotment::~Allotment() {
  if (!called_) {
    // Not calling is a bug - unused storage will not be reclaimed.
    JXL_UNREACHABLE("Did not call Allotment::ReclaimUnused");
  }
}

void BitWriter::Allotment::FinishedHistogram(BitWriter* JXL_RESTRICT writer) {
  if (writer == nullptr) return;
  JXL_ASSERT(!called_);              // Call before ReclaimUnused
  JXL_ASSERT(histogram_bits_ == 0);  // Do not call twice
  JXL_ASSERT(writer->BitsWritten() >= prev_bits_written_);
  histogram_bits_ = writer->BitsWritten() - prev_bits_written_;
}

void BitWriter::Allotment::ReclaimAndCharge(BitWriter* JXL_RESTRICT writer,
                                            size_t layer,
                                            AuxOut* JXL_RESTRICT aux_out) {
  size_t used_bits, unused_bits;
  PrivateReclaim(writer, &used_bits, &unused_bits);

#if 0
  printf("Layer %s bits: max %" PRIuS " used %" PRIuS " unused %" PRIuS "\n",
         LayerName(layer), MaxBits(), used_bits, unused_bits);
#endif

  // This may be a nested call with aux_out == null. Whenever we know that
  // aux_out is null, we can call ReclaimUnused directly.
  if (aux_out != nullptr) {
    aux_out->layers[layer].total_bits += used_bits;
    aux_out->layers[layer].histogram_bits += HistogramBits();
  }
}

void BitWriter::Allotment::PrivateReclaim(BitWriter* JXL_RESTRICT writer,
                                          size_t* JXL_RESTRICT used_bits,
                                          size_t* JXL_RESTRICT unused_bits) {
  JXL_ASSERT(!called_);  // Do not call twice
  called_ = true;
  if (writer == nullptr) return;

  JXL_ASSERT(writer->BitsWritten() >= prev_bits_written_);
  *used_bits = writer->BitsWritten() - prev_bits_written_;
  JXL_ASSERT(*used_bits <= max_bits_);
  *unused_bits = max_bits_ - *used_bits;

  // Reclaim unused bytes whole bytes from writer's allotment.
  const size_t unused_bytes = *unused_bits / kBitsPerByte;  // truncate
  JXL_ASSERT(writer->storage_.size() >= unused_bytes);
  writer->storage_.resize(writer->storage_.size() - unused_bytes);
  writer->current_allotment_ = parent_;
  // Ensure we don't also charge the parent for these bits.
  auto parent = parent_;
  while (parent != nullptr) {
    parent->prev_bits_written_ += *used_bits;
    parent = parent->parent_;
  }
}

void BitWriter::AppendByteAligned(const Span<const uint8_t>& span) {
  if (span.empty()) return;
  storage_.resize(storage_.size() + span.size() + 1);  // extra zero padding

  // Concatenate by copying bytes because both source and destination are bytes.
  JXL_ASSERT(BitsWritten() % kBitsPerByte == 0);
  size_t pos = BitsWritten() / kBitsPerByte;
  memcpy(storage_.data() + pos, span.data(), span.size());
  pos += span.size();
  storage_[pos++] = 0;  // for next Write
  JXL_ASSERT(pos <= storage_.size());
  bits_written_ += span.size() * kBitsPerByte;
}

void BitWriter::AppendByteAligned(const BitWriter& other) {
  JXL_ASSERT(other.BitsWritten() % kBitsPerByte == 0);
  JXL_ASSERT(other.BitsWritten() / kBitsPerByte != 0);

  AppendByteAligned(other.GetSpan());
}

void BitWriter::AppendByteAligned(const std::vector<BitWriter>& others) {
  // Total size to add so we can preallocate
  size_t other_bytes = 0;
  for (const BitWriter& writer : others) {
    JXL_ASSERT(writer.BitsWritten() % kBitsPerByte == 0);
    other_bytes += writer.BitsWritten() / kBitsPerByte;
  }
  if (other_bytes == 0) {
    // No bytes to append: this happens for example when creating per-group
    // storage for groups, but not writing anything in them for e.g. lossless
    // images with no alpha. Do nothing.
    return;
  }
  storage_.resize(storage_.size() + other_bytes + 1);  // extra zero padding

  // Concatenate by copying bytes because both source and destination are bytes.
  JXL_ASSERT(BitsWritten() % kBitsPerByte == 0);
  size_t pos = BitsWritten() / kBitsPerByte;
  for (const BitWriter& writer : others) {
    const Span<const uint8_t> span = writer.GetSpan();
    if (!span.empty()) {
      memcpy(storage_.data() + pos, span.data(), span.size());
      pos += span.size();
    }
  }
  storage_[pos++] = 0;  // for next Write
  JXL_ASSERT(pos <= storage_.size());
  bits_written_ += other_bytes * kBitsPerByte;
}

// TODO(lode): avoid code duplication
void BitWriter::AppendByteAligned(
    const std::vector<std::unique_ptr<BitWriter>>& others) {
  // Total size to add so we can preallocate
  size_t other_bytes = 0;
  for (const auto& writer : others) {
    JXL_ASSERT(writer->BitsWritten() % kBitsPerByte == 0);
    other_bytes += writer->BitsWritten() / kBitsPerByte;
  }
  if (other_bytes == 0) {
    // No bytes to append: this happens for example when creating per-group
    // storage for groups, but not writing anything in them for e.g. lossless
    // images with no alpha. Do nothing.
    return;
  }
  storage_.resize(storage_.size() + other_bytes + 1);  // extra zero padding

  // Concatenate by copying bytes because both source and destination are bytes.
  JXL_ASSERT(BitsWritten() % kBitsPerByte == 0);
  size_t pos = BitsWritten() / kBitsPerByte;
  for (const auto& writer : others) {
    const Span<const uint8_t> span = writer->GetSpan();
    memcpy(storage_.data() + pos, span.data(), span.size());
    pos += span.size();
  }
  storage_[pos++] = 0;  // for next Write
  JXL_ASSERT(pos <= storage_.size());
  bits_written_ += other_bytes * kBitsPerByte;
}

// Example: let's assume that 3 bits (Rs below) have been written already:
// BYTE+0       BYTE+1       BYTE+2
// 0000 0RRR    ???? ????    ???? ????
//
// Now, we could write up to 5 bits by just shifting them left by 3 bits and
// OR'ing to BYTE-0.
//
// For n > 5 bits, we write the lowest 5 bits as above, then write the next
// lowest bits into BYTE+1 starting from its lower bits and so on.
void BitWriter::Write(size_t n_bits, uint64_t bits) {
  JXL_DASSERT((bits >> n_bits) == 0);
  JXL_DASSERT(n_bits <= kMaxBitsPerCall);
  uint8_t* p = &storage_[bits_written_ / kBitsPerByte];
  const size_t bits_in_first_byte = bits_written_ % kBitsPerByte;
  bits <<= bits_in_first_byte;
#if JXL_BYTE_ORDER_LITTLE
  uint64_t v = *p;
  // Last (partial) or next byte to write must be zero-initialized!
  // PaddedBytes initializes the first, and Write/Append maintain this.
  JXL_DASSERT(v >> bits_in_first_byte == 0);
  v |= bits;
  memcpy(p, &v, sizeof(v));  // Write bytes: possibly more than n_bits/8
#else
  *p++ |= static_cast<uint8_t>(bits & 0xFF);
  for (size_t bits_left_to_write = n_bits + bits_in_first_byte;
       bits_left_to_write >= 9; bits_left_to_write -= 8) {
    bits >>= 8;
    *p++ = static_cast<uint8_t>(bits & 0xFF);
  }
  *p = 0;
#endif
  bits_written_ += n_bits;
}
}  // namespace jxl
