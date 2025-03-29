//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ForumTopicEditedData.h"

namespace td {

td_api::object_ptr<td_api::MessageContent> ForumTopicEditedData::get_message_content_object() const {
  if (edit_is_hidden_ && !(!is_hidden_ && edit_is_closed_ && !is_closed_)) {
    return td_api::make_object<td_api::messageForumTopicIsHiddenToggled>(is_hidden_);
  }
  if (edit_is_closed_) {
    return td_api::make_object<td_api::messageForumTopicIsClosedToggled>(is_closed_);
  }
  return td_api::make_object<td_api::messageForumTopicEdited>(title_, edit_icon_custom_emoji_id_,
                                                              icon_custom_emoji_id_.get());
}

bool operator==(const ForumTopicEditedData &lhs, const ForumTopicEditedData &rhs) {
  return lhs.title_ == rhs.title_ && lhs.icon_custom_emoji_id_ == rhs.icon_custom_emoji_id_ &&
         lhs.edit_icon_custom_emoji_id_ == rhs.edit_icon_custom_emoji_id_ &&
         lhs.edit_is_closed_ == rhs.edit_is_closed_ && lhs.is_closed_ == rhs.is_closed_ &&
         lhs.edit_is_hidden_ == rhs.edit_is_hidden_ && lhs.is_hidden_ == rhs.is_hidden_;
}

bool operator!=(const ForumTopicEditedData &lhs, const ForumTopicEditedData &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const ForumTopicEditedData &topic_edited_data) {
  if (!topic_edited_data.title_.empty()) {
    string_builder << "set title to \"" << topic_edited_data.title_ << '"';
  }
  if (topic_edited_data.edit_icon_custom_emoji_id_) {
    string_builder << "set icon to " << topic_edited_data.icon_custom_emoji_id_;
  }
  if (topic_edited_data.edit_is_closed_) {
    string_builder << "set is_closed to " << topic_edited_data.is_closed_;
  }
  if (topic_edited_data.edit_is_hidden_) {
    string_builder << "set is_hidden to " << topic_edited_data.is_hidden_;
  }
  return string_builder;
}

}  // namespace td
