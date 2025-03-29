//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/BitString.h"

#include "td/utils/bits.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#ifndef TG_ENGINE
#include "td/utils/ThreadSafeCounter.h"
#endif
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"
#include "td/utils/tl_storers.h"

#include <algorithm>
#include <cstring>

namespace tde2e_core {

namespace {
td::uint8 begin_mask(size_t start_bit) {
  return 0xFF >> start_bit;
}
td::uint8 end_mask(size_t end_bit) {
  return static_cast<td::uint8>(0xFF << (8 - end_bit));
}
td::uint8 create_mask(size_t start_bit, size_t end_bit) {
  return begin_mask(start_bit) & end_mask(end_bit);
}

size_t count_common_bits(td::uint8 byte1, td::uint8 byte2, size_t start_bit, size_t end_bit) {
  return td::count_leading_zeroes32(((byte1 ^ byte2) & begin_mask(start_bit)) >> (8 - end_bit)) +
         (end_bit - start_bit) - 32;
}
#ifndef TG_ENGINE
td::NamedThreadSafeCounter::CounterRef &get_bit_string_counter() {
  static auto counter = td::NamedThreadSafeCounter::get_default().get_counter("BitString");
  return counter;
}
#endif
}  // namespace

td::int64 BitString::get_counter_value() {
  return 0;
}

BitString::BitString(size_t bits) : BitString(nullptr, 0, bits) {
}

BitString::BitString(std::shared_ptr<char> ptr, size_t offset, size_t size) {
  size_t begin = offset;
  size_t end = offset + size;

  size_t begin_byte = (begin + 7) / 8;
  size_t end_byte = end / 8;

  bits_size_ = size;
  bytes_size_ = static_cast<td::int32>(end_byte) - static_cast<td::int32>(begin_byte);
  begin_bit_ = begin % 8;
  end_bit_ = end % 8;
  CHECK(bytes_size_ != -1 || (begin_bit_ && end_bit_));
  if (!ptr) {
    auto full_size = bytes_size_ + (begin_bit_ != 0) + (end_bit_ != 0);
    ptr = std::shared_ptr<char>(new char[full_size], std::default_delete<char[]>());
    td::MutableSlice(ptr.get(), full_size).fill_zero();
#ifndef TG_ENGINE
    get_bit_string_counter().add(+1);
#endif
    data_ = std::shared_ptr<char>(ptr, ptr.get() + (begin_bit_ != 0));
  } else {
    data_ = std::shared_ptr<char>(ptr, ptr.get() + begin_byte);
  }
}

BitString::BitString(td::Slice key_data) : BitString(nullptr, 0, key_data.size() * 8) {
  td::MutableSlice(data_.get(), key_data.size()).copy_from(key_data);
}

BitString::~BitString() {
  if (data_.use_count() == 1) {
#ifndef TG_ENGINE
    get_bit_string_counter().add(-1);
#endif
  }
}

BitString &BitString::operator=(const BitString &other) {
  if (&other == this) {
    return *this;
  }
  LOG_CHECK(!data_) << static_cast<void *>(data_.get());
  data_ = other.data_;
  bits_size_ = other.bits_size_;
  bytes_size_ = other.bytes_size_;
  begin_bit_ = other.begin_bit_;
  end_bit_ = other.end_bit_;
  return *this;
}

BitString &BitString::operator=(BitString &&other) noexcept {
  LOG_CHECK(!data_) << static_cast<void *>(data_.get());
  data_ = std::move(other.data_);
  bits_size_ = other.bits_size_;
  bytes_size_ = other.bytes_size_;
  begin_bit_ = other.begin_bit_;
  end_bit_ = other.end_bit_;
  return *this;
}

size_t BitString::bit_length() const {
  return bits_size_;
}

td::uint8 BitString::get_bit(size_t pos) const {
  CHECK(pos < bit_length());
  size_t absolute_bit_pos = pos + begin_bit_;
  size_t byte_index = absolute_bit_pos / 8 - (begin_bit_ != 0);
  size_t bit_index = 7 - (absolute_bit_pos % 8);  // Big-endian bit order
  return (data_.get()[byte_index] >> bit_index) & 1;
}

bool BitString::operator==(const BitString &other) const {
  if (bit_length() != other.bit_length()) {
    return false;
  }
  if (bit_length() == 0) {
    return true;
  }
  CHECK(begin_bit_ == other.begin_bit_);
  CHECK(bytes_size_ == other.bytes_size_);
  CHECK(end_bit_ == other.end_bit_);

  auto ptr1 = data_.get();
  auto ptr2 = other.data_.get();
  if (bytes_size_ == -1) {
    td::uint8 mask = create_mask(begin_bit_, end_bit_);
    return (ptr1[-1] & mask) == (ptr2[-1] & mask);
  }

  if (begin_bit_ != 0) {
    td::uint8 first_byte_mask = begin_mask(begin_bit_);
    if ((ptr1[-1] & first_byte_mask) != (ptr2[-1] & first_byte_mask)) {
      return false;
    }
  }

  if (end_bit_ != 0) {
    td::uint8 last_byte_mask = end_mask(end_bit_);
    if ((ptr1[bytes_size_] & last_byte_mask) != (ptr2[bytes_size_] & last_byte_mask)) {
      return false;
    }
  }

  return std::memcmp(ptr1, ptr2, bytes_size_) == 0;
}

size_t BitString::common_prefix_length(const BitString &other) const {
  CHECK(begin_bit_ == other.begin_bit_);
  //CHECK(bytes_size_ == other.bytes_size_);
  //CHECK(end_bit_ == other.end_bit_);

  td::uint8 begin_bit;
  td::uint8 end_bit;
  td::int32 bytes_size;
  auto min_length = std::min(bit_length(), other.bit_length());
  if (bit_length() < other.bit_length()) {
    begin_bit = begin_bit_;
    end_bit = end_bit_;
    bytes_size = bytes_size_;
  } else {
    begin_bit = other.begin_bit_;
    end_bit = other.end_bit_;
    bytes_size = other.bytes_size_;
  }

  auto ptr1 = data_.get();
  auto ptr2 = other.data_.get();

  if (bytes_size == -1) {
    auto res = count_common_bits(ptr1[-1], ptr2[-1], begin_bit, end_bit);
    CHECK(res <= min_length);
    return res;
  }

  size_t res = 0;

  if (begin_bit != 0) {
    td::uint8 first_byte_mask = begin_mask(begin_bit);
    td::uint8 byte1 = ptr1[-1] & first_byte_mask;
    td::uint8 byte2 = ptr2[-1] & first_byte_mask;
    if (byte1 != byte2) {
      res += count_common_bits(byte1, byte2, begin_bit, 8);
      CHECK(res <= min_length);
      return res;
    }
    res += 8 - begin_bit;
  }

  size_t first_diff = std::mismatch(ptr1, ptr1 + bytes_size, ptr2).first - ptr1;
  res += first_diff * 8;
  if (td::narrow_cast<int>(first_diff) != bytes_size) {
    res += count_common_bits(ptr1[first_diff], ptr2[first_diff], 0, 8);
    CHECK(res <= min_length);
    return res;
  }

  if (end_bit != 0) {
    res += count_common_bits(ptr1[bytes_size], ptr2[bytes_size], 0, end_bit);
    CHECK(res <= min_length);
    return res;
  }
  CHECK(res <= min_length);
  return res;
}

BitString BitString::substr(size_t pos, size_t length) const {
  auto size = bit_length();
  CHECK(pos <= size);
  size_t new_length = std::min(length, size - pos);
  return BitString(std::shared_ptr<char>(data_, data_.get() - (begin_bit_ != 0)), begin_bit_ + pos, new_length);
}

template <class StorerT>
void store(const BitString &bs, StorerT &storer) {
  using td::store;
  auto ptr = bs.data_.get();

  store(static_cast<td::uint32>((static_cast<td::uint16>(bs.begin_bit_) << 16) |
                                static_cast<td::uint16>(bs.begin_bit_ + bs.bit_length())),
        storer);

  size_t n = 0;
  if (bs.bytes_size_ == -1) {
    td::uint8 mask = create_mask(bs.begin_bit_, bs.end_bit_);
    storer.store_binary(static_cast<td::uint8>(ptr[-1] & mask));
    n = 1;
  } else {
    if (bs.begin_bit_ != 0) {
      td::uint8 first_byte_mask = begin_mask(bs.begin_bit_);
      storer.store_binary(static_cast<td::uint8>(ptr[-1] & first_byte_mask));
      n++;
    }

    storer.store_slice(td::Slice(ptr, bs.bytes_size_));
    n += bs.bytes_size_;

    if (bs.end_bit_ != 0) {
      auto last_byte_mask = end_mask(bs.end_bit_);
      storer.store_binary(static_cast<td::uint8>(ptr[bs.bytes_size_] & last_byte_mask));
      n++;
    }
  }
  while (n % 4 != 0) {
    storer.store_binary(static_cast<td::uint8>(0));
    n++;
  }
}

template <class ParserT>
BitString fetch_bit_string(ParserT &parser) {
  BitString base_bs;
  return fetch_bit_string(parser, base_bs);
}

template <class ParserT>
BitString fetch_bit_string(ParserT &parser, BitString &base_bs) {
  using td::parse;
  td::uint32 begin_end;
  parse(begin_end, parser);

  size_t begin = begin_end >> 16;
  size_t end = begin_end & 0xFFFF;
  auto bs = base_bs.data_ ? base_bs.substr(0, end - begin) : BitString(nullptr, begin, end - begin);

  auto ptr = bs.data_.get();

  size_t n = 0;
  td::uint8 byte;
  if (bs.bytes_size_ == -1) {
    td::uint8 mask = create_mask(bs.begin_bit_, bs.end_bit_);
    byte = parser.template fetch_binary<td::uint8>();
    ptr[-1] |= byte & mask;
    n = 1;
  } else {
    if (bs.begin_bit_ != 0) {
      byte = parser.template fetch_binary<td::uint8>();
      td::uint8 first_byte_mask = begin_mask(bs.begin_bit_);
      ptr[-1] |= byte & first_byte_mask;
      n++;
    }

    td::MutableSlice(ptr, bs.bytes_size_).copy_from(parser.template fetch_string_raw<td::Slice>(bs.bytes_size_));
    n += bs.bytes_size_;

    if (bs.end_bit_ != 0) {
      byte = parser.template fetch_binary<td::uint8>();
      auto last_byte_mask = end_mask(bs.end_bit_);
      ptr[bs.bytes_size_] |= byte & last_byte_mask;
      n++;
    }
  }
  while (n % 4 != 0) {
    byte = parser.template fetch_binary<td::uint8>();
    n++;
  }
  return bs;
}
template void store<td::TlStorerUnsafe>(const BitString &bs, td::TlStorerUnsafe &storer);
template void store<td::TlStorerCalcLength>(const BitString &bs, td::TlStorerCalcLength &storer);

template BitString fetch_bit_string<td::TlParser>(td::TlParser &fetch_bit_stringr);
template BitString fetch_bit_string<td::TlParser>(td::TlParser &fetch_bit_stringr, BitString &base_bs);

td::Result<std::string> BitString::serialize_for_network(const BitString &bs) {
  td::TlStorerCalcLength calc_length;
  store(bs, calc_length);
  std::string buf(calc_length.get_length(), 0);
  td::TlStorerUnsafe storer(td::MutableSlice(buf).ubegin());
  store(bs, storer);
  return buf;
}
td::Result<BitString> BitString::fetch_from_network(td::Slice data) {
  td::TlParser parser(data);
  auto res = fetch_bit_string(parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  return res;
}

std::ostream &operator<<(std::ostream &os, const BitString &bits) {
  os << static_cast<td::uint32>(bits.begin_bit_) << ' ' << bits.bytes_size_ << ' '
     << static_cast<td::uint32>(bits.end_bit_) << ' ';
  for (size_t i = 0; i < bits.bit_length(); ++i) {
    os << static_cast<int>(bits.get_bit(i));
  }
  os << ' ' << bits.data_.get();
  return os;
}

td::StringBuilder &operator<<(td::StringBuilder &string_builder, const BitString &bits) {
  string_builder << static_cast<td::uint32>(bits.begin_bit_) << ' ' << bits.bytes_size_ << ' '
                 << static_cast<td::uint32>(bits.end_bit_) << ' ';
  for (size_t i = 0; i < bits.bit_length(); ++i) {
    string_builder << static_cast<int>(bits.get_bit(i));
  }
  string_builder << ' ' << bits.data_.get();
  return string_builder;
}

}  // namespace tde2e_core
