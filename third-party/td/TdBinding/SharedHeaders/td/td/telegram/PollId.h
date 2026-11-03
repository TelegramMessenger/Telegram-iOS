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

class PollId {
  int64 id = 0;

 public:
  PollId() = default;

  explicit constexpr PollId(int64 poll_id) : id(poll_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  PollId(T poll_id) = delete;

  int64 get() const {
    return id;
  }

  bool operator==(const PollId &other) const {
    return id == other.id;
  }

  bool operator!=(const PollId &other) const {
    return id != other.id;
  }

  bool is_valid() const {
    return id != 0;
  }
};

struct PollIdHash {
  uint32 operator()(PollId poll_id) const {
    return Hash<int64>()(poll_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, PollId poll_id) {
  return string_builder << "poll " << poll_id.get();
}

}  // namespace td
