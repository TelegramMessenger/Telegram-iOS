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
#include "td/utils/StringBuilder.h"

namespace td {

class UserManager;

class BusinessChatLink {
  string link_;
  FormattedText text_;
  string title_;
  int32 view_count_ = 0;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessChatLink &link);

 public:
  BusinessChatLink(const UserManager *user_manager, telegram_api::object_ptr<telegram_api::businessChatLink> &&link);

  bool is_valid() const {
    return !link_.empty();
  }

  td_api::object_ptr<td_api::businessChatLink> get_business_chat_link_object(const UserManager *user_manager) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessChatLink &link);

class BusinessChatLinks {
  vector<BusinessChatLink> business_chat_links_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessChatLinks &links);

 public:
  BusinessChatLinks(const UserManager *user_manager,
                    vector<telegram_api::object_ptr<telegram_api::businessChatLink>> &&links);

  td_api::object_ptr<td_api::businessChatLinks> get_business_chat_links_object(const UserManager *user_manager) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessChatLinks &links);

}  // namespace td
