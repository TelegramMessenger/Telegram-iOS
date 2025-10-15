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

class MessageEffectId {
  int64 id = 0;

 public:
  MessageEffectId() = default;

  explicit constexpr MessageEffectId(int64 message_effect_id) : id(message_effect_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  MessageEffectId(T message_effect_id) = delete;

  bool is_valid() const {
    return id != 0;
  }

  int64 get() const {
    return id;
  }

  bool operator==(const MessageEffectId &other) const {
    return id == other.id;
  }

  bool operator!=(const MessageEffectId &other) const {
    return id != other.id;
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

struct MessageEffectIdHash {
  uint32 operator()(MessageEffectId message_effect_id) const {
    return Hash<int64>()(message_effect_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, MessageEffectId message_effect_id) {
  return string_builder << "message effect " << message_effect_id.get();
}

}  // namespace td
