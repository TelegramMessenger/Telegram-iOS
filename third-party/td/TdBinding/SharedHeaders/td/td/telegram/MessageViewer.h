//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class UserManager;

class MessageViewer {
  UserId user_id_;
  int32 date_ = 0;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MessageViewer &viewer);

 public:
  explicit MessageViewer(telegram_api::object_ptr<telegram_api::readParticipantDate> &&read_date);

  MessageViewer(UserId user_id, int32 date) : user_id_(user_id), date_(td::max(date, static_cast<int32>(0))) {
  }

  UserId get_user_id() const {
    return user_id_;
  }

  bool is_empty() const {
    return user_id_ == UserId() && date_ == 0;
  }

  td_api::object_ptr<td_api::messageViewer> get_message_viewer_object(UserManager *user_manager) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const MessageViewer &viewer);

class MessageViewers {
  vector<MessageViewer> message_viewers_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MessageViewers &viewers);

 public:
  MessageViewers() = default;

  explicit MessageViewers(vector<telegram_api::object_ptr<telegram_api::readParticipantDate>> &&read_dates);

  vector<UserId> get_user_ids() const;

  td_api::object_ptr<td_api::messageViewers> get_message_viewers_object(UserManager *user_manager) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const MessageViewers &viewers);

}  // namespace td
