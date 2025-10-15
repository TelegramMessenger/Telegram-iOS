//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

namespace td {

class DbKey {
  enum class Type { Empty, RawKey, Password };

  Type type() const {
    return type_;
  }

 public:
  bool is_empty() const {
    return type_ == Type::Empty;
  }

  bool is_raw_key() const {
    return type_ == Type::RawKey;
  }

  bool is_password() const {
    return type_ == Type::Password;
  }

  CSlice data() const {
    return data_;
  }

  static DbKey raw_key(string raw_key) {
    DbKey res;
    res.type_ = Type::RawKey;
    res.data_ = std::move(raw_key);
    return res;
  }

  static DbKey password(string password) {
    DbKey res;
    res.type_ = Type::Password;
    res.data_ = std::move(password);
    return res;
  }

  static DbKey empty() {
    return DbKey();
  }

 private:
  Type type_{Type::Empty};
  string data_;
};

}  // namespace td
