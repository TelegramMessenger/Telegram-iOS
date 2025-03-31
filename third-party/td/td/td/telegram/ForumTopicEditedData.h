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

class ForumTopicEditedData {
  string title_;
  CustomEmojiId icon_custom_emoji_id_;
  bool edit_icon_custom_emoji_id_ = false;
  bool edit_is_closed_ = false;
  bool is_closed_ = false;
  bool edit_is_hidden_ = false;
  bool is_hidden_ = false;

  friend bool operator==(const ForumTopicEditedData &lhs, const ForumTopicEditedData &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ForumTopicEditedData &topic_edited_data);

  friend class ForumTopicInfo;

 public:
  ForumTopicEditedData() = default;

  ForumTopicEditedData(string &&title, bool edit_icon_custom_emoji_id, int64 icon_custom_emoji_id, bool edit_is_closed,
                       bool is_closed, bool edit_is_hidden, bool is_hidden)
      : title_(std::move(title))
      , icon_custom_emoji_id_(icon_custom_emoji_id)
      , edit_icon_custom_emoji_id_(edit_icon_custom_emoji_id)
      , edit_is_closed_(edit_is_closed)
      , is_closed_(is_closed)
      , edit_is_hidden_(edit_is_hidden)
      , is_hidden_(is_hidden) {
  }

  bool is_empty() const {
    return title_.empty() && !edit_icon_custom_emoji_id_ && !edit_is_closed_ && !edit_is_hidden_;
  }

  const string &get_title() const {
    return title_;
  }

  td_api::object_ptr<td_api::MessageContent> get_message_content_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const ForumTopicEditedData &lhs, const ForumTopicEditedData &rhs);
bool operator!=(const ForumTopicEditedData &lhs, const ForumTopicEditedData &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const ForumTopicEditedData &topic_edited_data);

}  // namespace td
