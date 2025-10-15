//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageEntity.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"

namespace td {

class TermsOfService {
  string id_;
  FormattedText text_;
  int32 min_user_age_ = 0;
  bool show_popup_ = true;

 public:
  explicit TermsOfService(telegram_api::object_ptr<telegram_api::help_termsOfService> terms = nullptr);

  Slice get_id() const {
    return id_;
  }

  td_api::object_ptr<td_api::termsOfService> get_terms_of_service_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

}  // namespace td
