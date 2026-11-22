//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StarSubscriptionPricing.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"

namespace td {

class UserManager;

class DialogInviteLink {
  string invite_link_;
  string title_;
  UserId creator_user_id_;
  StarSubscriptionPricing pricing_;
  int32 date_ = 0;
  int32 edit_date_ = 0;
  int32 expire_date_ = 0;
  int32 usage_limit_ = 0;
  int32 usage_count_ = 0;
  int32 expired_usage_count_ = 0;
  int32 request_count_ = 0;
  bool creates_join_request_ = false;
  bool is_revoked_ = false;
  bool is_permanent_ = false;

  friend bool operator==(const DialogInviteLink &lhs, const DialogInviteLink &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const DialogInviteLink &invite_link);

 public:
  DialogInviteLink() = default;

  DialogInviteLink(telegram_api::object_ptr<telegram_api::ExportedChatInvite> exported_invite_ptr, bool allow_truncated,
                   bool expect_join_request, const char *source);

  static bool is_valid_invite_link(Slice invite_link, bool allow_truncated = false);

  td_api::object_ptr<td_api::chatInviteLink> get_chat_invite_link_object(const UserManager *user_manager) const;

  bool is_valid() const {
    return !invite_link_.empty() && creator_user_id_.is_valid() && date_ > 0;
  }

  bool is_permanent() const {
    return is_permanent_;
  }

  const string &get_invite_link() const {
    return invite_link_;
  }

  UserId get_creator_user_id() const {
    return creator_user_id_;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const DialogInviteLink &lhs, const DialogInviteLink &rhs);

bool operator!=(const DialogInviteLink &lhs, const DialogInviteLink &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const DialogInviteLink &invite_link);

}  // namespace td
