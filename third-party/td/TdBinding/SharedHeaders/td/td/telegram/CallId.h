//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class CallId {
 public:
  CallId() = default;

  explicit constexpr CallId(int32 call_id) : id(call_id) {
  }

  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  CallId(T call_id) = delete;

  bool is_valid() const {
    return id != 0;
  }

  int32 get() const {
    return id;
  }

  auto get_call_id_object() const {
    return td_api::make_object<td_api::callId>(id);
  }

  bool operator==(const CallId &other) const {
    return id == other.id;
  }

 private:
  int32 id{0};
};

struct CallIdHash {
  uint32 operator()(CallId call_id) const {
    return Hash<int32>()(call_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &sb, const CallId call_id) {
  return sb << "call " << call_id.get();
}

}  // namespace td
