//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class CustomEmojiId {
  int64 id = 0;

 public:
  CustomEmojiId() = default;

  explicit constexpr CustomEmojiId(int64 custom_emoji_id) : id(custom_emoji_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  CustomEmojiId(T custom_emoji_id) = delete;

  bool is_valid() const {
    return id != 0;
  }

  int64 get() const {
    return id;
  }

  bool operator==(const CustomEmojiId &other) const {
    return id == other.id;
  }

  bool operator!=(const CustomEmojiId &other) const {
    return id != other.id;
  }

  static vector<CustomEmojiId> get_custom_emoji_ids(const vector<int64> &document_ids) {
    vector<CustomEmojiId> custom_emoji_ids;
    custom_emoji_ids.reserve(document_ids.size());
    for (auto &document_id : document_ids) {
      custom_emoji_ids.emplace_back(document_id);
    }
    return custom_emoji_ids;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_long(id);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    id = parser.fetch_long();
  }
};

struct CustomEmojiIdHash {
  uint32 operator()(CustomEmojiId custom_emoji_id) const {
    return Hash<int64>()(custom_emoji_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, CustomEmojiId custom_emoji_id) {
  return string_builder << "custom emoji " << custom_emoji_id.get();
}

}  // namespace td
