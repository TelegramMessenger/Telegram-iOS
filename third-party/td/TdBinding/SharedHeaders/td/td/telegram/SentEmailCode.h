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
#include "td/utils/tl_helpers.h"

namespace td {

class SentEmailCode {
  string email_address_pattern_;
  int32 code_length_ = 0;

 public:
  SentEmailCode() = default;

  SentEmailCode(string &&email_address_pattern, int32 code_length)
      : email_address_pattern_(std::move(email_address_pattern)), code_length_(code_length) {
  }

  explicit SentEmailCode(telegram_api::object_ptr<telegram_api::account_sentEmailCode> &&email_code);

  td_api::object_ptr<td_api::emailAddressAuthenticationCodeInfo> get_email_address_authentication_code_info_object()
      const;

  bool is_empty() const {
    return email_address_pattern_.empty();
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(email_address_pattern_, storer);
    td::store(code_length_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(email_address_pattern_, parser);
    td::parse(code_length_, parser);
  }
};

}  // namespace td
