//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/e2e/utils.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <memory>
#include <ostream>

namespace tde2e_core {

class BitString {
 public:
  static td::int64 get_counter_value();
  BitString() = default;
  explicit BitString(size_t bits);
  BitString(std::shared_ptr<char> ptr, size_t offset, size_t size);
  explicit BitString(td::Slice key_data);
  BitString(const BitString &) = default;
  BitString &operator=(const BitString &other);
  BitString(BitString &&) noexcept = default;
  BitString &operator=(BitString &&other) noexcept;
  ~BitString();

  size_t bit_length() const;
  td::uint8 get_bit(size_t pos) const;

  bool operator==(const BitString &other) const;
  size_t common_prefix_length(const BitString &other) const;
  BitString substr(size_t pos, size_t length = SIZE_MAX) const;

  friend std::ostream &operator<<(std::ostream &os, const BitString &bits);
  friend td::StringBuilder &operator<<(td::StringBuilder &string_builder, const BitString &bits);

  template <class StorerT>
  friend void store(const BitString &bs, StorerT &storer);
  template <class ParserT>
  friend BitString fetch_bit_string(ParserT &parser);
  template <class ParserT>
  friend BitString fetch_bit_string(ParserT &parser, BitString &base_bs);

  static td::Result<std::string> serialize_for_network(const BitString &bs);
  static td::Result<BitString> fetch_from_network(td::Slice data);

  // TODO: make following fields private
  std::shared_ptr<char> data_;
  size_t bits_size_{};
  td::int32 bytes_size_{};
  td::uint8 begin_bit_{};
  td::uint8 end_bit_{};
};

}  // namespace tde2e_core
