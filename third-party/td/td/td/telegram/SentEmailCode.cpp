//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SentEmailCode.h"

#include "td/utils/logging.h"

namespace td {

SentEmailCode::SentEmailCode(telegram_api::object_ptr<telegram_api::account_sentEmailCode> &&email_code)
    : email_address_pattern_(std::move(email_code->email_pattern_)), code_length_(email_code->length_) {
  if (code_length_ < 0 || code_length_ >= 100) {
    LOG(ERROR) << "Receive wrong email code length " << code_length_;
    code_length_ = 0;
  }
}

td_api::object_ptr<td_api::emailAddressAuthenticationCodeInfo>
SentEmailCode::get_email_address_authentication_code_info_object() const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::emailAddressAuthenticationCodeInfo>(email_address_pattern_, code_length_);
}

}  // namespace td
