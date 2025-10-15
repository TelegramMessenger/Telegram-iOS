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

class UserId {
  int64 id = 0;

 public:
  static constexpr int64 MAX_USER_ID = (static_cast<int64>(1) << 40) - 1;

  UserId() = default;

  explicit constexpr UserId(int64 user_id) : id(user_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  UserId(T user_id) = delete;

  static vector<UserId> get_user_ids(const vector<int64> &input_user_ids, bool only_valid = false) {
    vector<UserId> user_ids;
    user_ids.reserve(input_user_ids.size());
    for (auto &input_user_id : input_user_ids) {
      UserId user_id(input_user_id);
      if (!only_valid || user_id.is_valid()) {
        user_ids.emplace_back(user_id);
      }
    }
    return user_ids;
  }

  static vector<int64> get_input_user_ids(const vector<UserId> &user_ids) {
    vector<int64> input_user_ids;
    input_user_ids.reserve(user_ids.size());
    for (auto &user_id : user_ids) {
      input_user_ids.emplace_back(user_id.get());
    }
    return input_user_ids;
  }

  bool is_valid() const {
    return 0 < id && id <= MAX_USER_ID;
  }

  int64 get() const {
    return id;
  }

  bool operator==(const UserId &other) const {
    return id == other.id;
  }

  bool operator!=(const UserId &other) const {
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

struct UserIdHash {
  uint32 operator()(UserId user_id) const {
    return Hash<int64>()(user_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, UserId user_id) {
  return string_builder << "user " << user_id.get();
}

}  // namespace td
