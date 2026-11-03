//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

class EmailVerification {
  enum class Type : int32 { None, Code, Apple, Google };
  Type type_ = Type::None;
  string code_;

 public:
  EmailVerification() = default;

  explicit EmailVerification(td_api::object_ptr<td_api::EmailAddressAuthentication> &&code);

  telegram_api::object_ptr<telegram_api::EmailVerification> get_input_email_verification() const;

  bool is_empty() const {
    return type_ == Type::None;
  }

  bool is_email_code() const {
    return type_ == Type::Code;
  }
};

}  // namespace td
