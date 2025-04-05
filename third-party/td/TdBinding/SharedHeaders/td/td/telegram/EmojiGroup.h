//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

class StickersManager;

class EmojiGroup {
  string title_;
  CustomEmojiId icon_custom_emoji_id_;
  vector<string> emojis_;
  bool is_greeting_ = false;
  bool is_premium_ = false;

 public:
  EmojiGroup() = default;

  explicit EmojiGroup(telegram_api::object_ptr<telegram_api::EmojiGroup> &&emoji_group);

  td_api::object_ptr<td_api::emojiCategory> get_emoji_category_object(StickersManager *stickers_manager) const;

  CustomEmojiId get_icon_custom_emoji_id() const {
    return icon_custom_emoji_id_;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

class EmojiGroupList {
  string used_language_codes_;
  int32 hash_ = 0;
  vector<EmojiGroup> emoji_groups_;
  double next_reload_time_ = 0.0;

 public:
  EmojiGroupList() = default;

  EmojiGroupList(string used_language_codes, int32 hash,
                 vector<telegram_api::object_ptr<telegram_api::EmojiGroup>> &&emoji_groups);

  td_api::object_ptr<td_api::emojiCategories> get_emoji_categories_object(StickersManager *stickers_manager) const;

  const string &get_used_language_codes() const {
    return used_language_codes_;
  }

  int32 get_hash() const {
    return hash_;
  }

  bool is_expired() const;

  void update_next_reload_time();

  vector<CustomEmojiId> get_icon_custom_emoji_ids() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

}  // namespace td
