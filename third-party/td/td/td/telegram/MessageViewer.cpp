//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageViewer.h"

#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"

namespace td {

MessageViewer::MessageViewer(telegram_api::object_ptr<telegram_api::readParticipantDate> &&read_date)
    : MessageViewer(UserId(read_date->user_id_), read_date->date_) {
}

td_api::object_ptr<td_api::messageViewer> MessageViewer::get_message_viewer_object(UserManager *user_manager) const {
  return td_api::make_object<td_api::messageViewer>(
      user_manager->get_user_id_object(user_id_, "get_message_viewer_object"), date_);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageViewer &viewer) {
  return string_builder << '[' << viewer.user_id_ << " at " << viewer.date_ << ']';
}

MessageViewers::MessageViewers(vector<telegram_api::object_ptr<telegram_api::readParticipantDate>> &&read_dates) {
  for (auto &read_date : read_dates) {
    message_viewers_.emplace_back(std::move(read_date));
    auto user_id = message_viewers_.back().get_user_id();
    if (!user_id.is_valid()) {
      LOG(ERROR) << "Receive invalid " << user_id << " as a viewer of a message";
      message_viewers_.pop_back();
    }
  }
}

vector<UserId> MessageViewers::get_user_ids() const {
  return transform(message_viewers_, [](auto &viewer) { return viewer.get_user_id(); });
}

td_api::object_ptr<td_api::messageViewers> MessageViewers::get_message_viewers_object(UserManager *user_manager) const {
  return td_api::make_object<td_api::messageViewers>(
      transform(message_viewers_, [user_manager](const MessageViewer &message_viewer) {
        return message_viewer.get_message_viewer_object(user_manager);
      }));
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageViewers &viewers) {
  return string_builder << viewers.message_viewers_;
}

}  // namespace td
