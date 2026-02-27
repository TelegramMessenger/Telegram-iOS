//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class ForumTopicIcon {
  int32 color_ = 0x6FB9F0;
  CustomEmojiId custom_emoji_id_;

  friend bool operator==(const ForumTopicIcon &lhs, const ForumTopicIcon &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ForumTopicIcon &topic_icon);

 public:
  ForumTopicIcon() = default;
  ForumTopicIcon(int32 color, int64 custom_emoji_id);

  bool edit_custom_emoji_id(CustomEmojiId custom_emoji_id);

  td_api::object_ptr<td_api::forumTopicIcon> get_forum_topic_icon_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const ForumTopicIcon &lhs, const ForumTopicIcon &rhs);
bool operator!=(const ForumTopicIcon &lhs, const ForumTopicIcon &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const ForumTopicIcon &topic_icon);

}  // namespace td
