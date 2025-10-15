//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <type_traits>

namespace td {

class ServerMessageId {
  int32 id = 0;

 public:
  ServerMessageId() = default;

  explicit constexpr ServerMessageId(int32 message_id) : id(message_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  ServerMessageId(T message_id) = delete;

  bool is_valid() const {
    return id > 0;
  }

  int32 get() const {
    return id;
  }

  bool operator==(const ServerMessageId &other) const {
    return id == other.id;
  }

  bool operator!=(const ServerMessageId &other) const {
    return id != other.id;
  }
};

}  // namespace td
