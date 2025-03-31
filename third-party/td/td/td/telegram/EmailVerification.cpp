//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/EmailVerification.h"

#include "td/telegram/misc.h"

namespace td {

EmailVerification::EmailVerification(td_api::object_ptr<td_api::EmailAddressAuthentication> &&code) {
  if (code == nullptr) {
    return;
  }
  switch (code->get_id()) {
    case td_api::emailAddressAuthenticationCode::ID:
      type_ = Type::Code;
      code_ = static_cast<const td_api::emailAddressAuthenticationCode *>(code.get())->code_;
      break;
    case td_api::emailAddressAuthenticationAppleId::ID:
      type_ = Type::Apple;
      code_ = static_cast<const td_api::emailAddressAuthenticationAppleId *>(code.get())->token_;
      break;
    case td_api::emailAddressAuthenticationGoogleId::ID:
      type_ = Type::Google;
      code_ = static_cast<const td_api::emailAddressAuthenticationGoogleId *>(code.get())->token_;
      break;
    default:
      UNREACHABLE();
      break;
  }
  if (!clean_input_string(code_)) {
    *this = {};
  }
}

telegram_api::object_ptr<telegram_api::EmailVerification> EmailVerification::get_input_email_verification() const {
  switch (type_) {
    case Type::Code:
      return telegram_api::make_object<telegram_api::emailVerificationCode>(code_);
    case Type::Apple:
      return telegram_api::make_object<telegram_api::emailVerificationApple>(code_);
    case Type::Google:
      return telegram_api::make_object<telegram_api::emailVerificationGoogle>(code_);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

}  // namespace td
