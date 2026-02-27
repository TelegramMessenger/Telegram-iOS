//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class ChannelId {
  int64 id = 0;

 public:
  // the last (1 << 31) - 1 identifiers will be used for secret chat dialog identifiers
  static constexpr int64 MAX_CHANNEL_ID = 1000000000000ll - (1ll << 31);

  ChannelId() = default;

  explicit constexpr ChannelId(int64 channel_id) : id(channel_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  ChannelId(T channel_id) = delete;

  bool is_valid() const {
    return 0 < id && id < MAX_CHANNEL_ID;
  }

  int64 get() const {
    return id;
  }

  bool operator==(const ChannelId &other) const {
    return id == other.id;
  }

  bool operator!=(const ChannelId &other) const {
    return id != other.id;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_long(id);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    if (parser.version() >= static_cast<int32>(Version::Support64BitIds)) {
      id = parser.fetch_long();
    } else {
      id = parser.fetch_int();
    }
  }
};

struct ChannelIdHash {
  uint32 operator()(ChannelId channel_id) const {
    return Hash<int64>()(channel_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, ChannelId channel_id) {
  return string_builder << "supergroup " << channel_id.get();
}

}  // namespace td
