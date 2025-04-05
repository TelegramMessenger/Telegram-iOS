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

class NotificationGroupId {
 public:
  NotificationGroupId() = default;

  explicit constexpr NotificationGroupId(int32 group_id) : id(group_id) {
  }

  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  NotificationGroupId(T group_id) = delete;

  bool is_valid() const {
    return id > 0;
  }

  int32 get() const {
    return id;
  }

  bool operator==(const NotificationGroupId &other) const {
    return id == other.id;
  }

  bool operator!=(const NotificationGroupId &other) const {
    return id != other.id;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_int(id);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    id = parser.fetch_int();
  }

 private:
  int32 id{0};
};

struct NotificationGroupIdHash {
  uint32 operator()(NotificationGroupId group_id) const {
    return Hash<int32>()(group_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &sb, const NotificationGroupId group_id) {
  return sb << "notification group " << group_id.get();
}

}  // namespace td
