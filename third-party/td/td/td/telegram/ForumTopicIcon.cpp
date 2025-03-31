//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ForumTopicIcon.h"

namespace td {

ForumTopicIcon::ForumTopicIcon(int32 color, int64 custom_emoji_id)
    : color_(color & 0xFFFFFF), custom_emoji_id_(custom_emoji_id) {
}

bool ForumTopicIcon::edit_custom_emoji_id(CustomEmojiId custom_emoji_id) {
  if (custom_emoji_id_ != custom_emoji_id) {
    custom_emoji_id_ = custom_emoji_id;
    return true;
  }
  return false;
}

td_api::object_ptr<td_api::forumTopicIcon> ForumTopicIcon::get_forum_topic_icon_object() const {
  return td_api::make_object<td_api::forumTopicIcon>(color_, custom_emoji_id_.get());
}

bool operator==(const ForumTopicIcon &lhs, const ForumTopicIcon &rhs) {
  return lhs.color_ == rhs.color_ && lhs.custom_emoji_id_ == rhs.custom_emoji_id_;
}

bool operator!=(const ForumTopicIcon &lhs, const ForumTopicIcon &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const ForumTopicIcon &topic_icon) {
  string_builder << "icon color " << topic_icon.color_;
  if (topic_icon.custom_emoji_id_.is_valid()) {
    string_builder << " and " << topic_icon.custom_emoji_id_;
  }
  return string_builder;
}

}  // namespace td
