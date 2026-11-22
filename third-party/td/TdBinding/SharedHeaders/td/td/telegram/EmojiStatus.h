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
#include "td/utils/Promise.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Td;

class EmojiStatus {
  CustomEmojiId custom_emoji_id_;

  int64 collectible_id_ = 0;
  string title_;
  string slug_;
  CustomEmojiId model_custom_emoji_id_;
  CustomEmojiId pattern_custom_emoji_id_;
  int32 center_color_ = 0;
  int32 edge_color_ = 0;
  int32 pattern_color_ = 0;
  int32 text_color_ = 0;

  int32 until_date_ = 0;

  friend bool operator==(const EmojiStatus &lhs, const EmojiStatus &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const EmojiStatus &contact);

 public:
  EmojiStatus() = default;

  explicit EmojiStatus(const td_api::object_ptr<td_api::emojiStatus> &emoji_status);

  static unique_ptr<EmojiStatus> get_emoji_status(const td_api::object_ptr<td_api::emojiStatus> &emoji_status);

  explicit EmojiStatus(telegram_api::object_ptr<telegram_api::EmojiStatus> &&emoji_status);

  static unique_ptr<EmojiStatus> get_emoji_status(telegram_api::object_ptr<telegram_api::EmojiStatus> &&emoji_status);

  static unique_ptr<EmojiStatus> clone_emoji_status(const unique_ptr<EmojiStatus> &emoji_status);

  telegram_api::object_ptr<telegram_api::EmojiStatus> get_input_emoji_status() const;

  static telegram_api::object_ptr<telegram_api::EmojiStatus> get_input_emoji_status(
      const unique_ptr<EmojiStatus> &emoji_status);

  td_api::object_ptr<td_api::emojiStatus> get_emoji_status_object() const;

  static td_api::object_ptr<td_api::emojiStatus> get_emoji_status_object(const unique_ptr<EmojiStatus> &emoji_status);

  EmojiStatus get_effective_emoji_status(bool is_premium, int32 unix_time) const;

  static unique_ptr<EmojiStatus> get_effective_emoji_status(const unique_ptr<EmojiStatus> &emoji_status,
                                                            bool is_premium, int32 unix_time);

  bool is_empty() const {
    return !custom_emoji_id_.is_valid() && (collectible_id_ == 0 || title_.empty() ||
                                            !model_custom_emoji_id_.is_valid() || !pattern_custom_emoji_id_.is_valid());
  }

  CustomEmojiId get_custom_emoji_id() const {
    return custom_emoji_id_;
  }

  int32 get_until_date() const {
    return until_date_;
  }

  void clear_until_date() {
    until_date_ = 0;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_custom_emoji_id = custom_emoji_id_.is_valid();
    bool has_until_date = until_date_ != 0;
    bool has_collectible_id = collectible_id_ != 0;
    bool has_title = !title_.empty();
    bool has_slug = !slug_.empty();
    bool has_gift = model_custom_emoji_id_.is_valid() || pattern_custom_emoji_id_.is_valid() || center_color_ != 0 ||
                    edge_color_ != 0 || pattern_color_ != 0 || text_color_ != 0;
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_custom_emoji_id);
    STORE_FLAG(has_until_date);
    STORE_FLAG(has_collectible_id);
    STORE_FLAG(has_title);
    STORE_FLAG(has_slug);
    STORE_FLAG(has_gift);
    END_STORE_FLAGS();
    if (has_custom_emoji_id) {
      td::store(custom_emoji_id_, storer);
    }
    if (has_until_date) {
      td::store(until_date_, storer);
    }
    if (has_collectible_id) {
      td::store(collectible_id_, storer);
    }
    if (has_title) {
      td::store(title_, storer);
    }
    if (has_slug) {
      td::store(slug_, storer);
    }
    if (has_gift) {
      td::store(model_custom_emoji_id_, storer);
      td::store(pattern_custom_emoji_id_, storer);
      td::store(center_color_, storer);
      td::store(edge_color_, storer);
      td::store(pattern_color_, storer);
      td::store(text_color_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_custom_emoji_id;
    bool has_until_date;
    bool has_collectible_id;
    bool has_title;
    bool has_slug;
    bool has_gift;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_custom_emoji_id);
    PARSE_FLAG(has_until_date);
    PARSE_FLAG(has_collectible_id);
    PARSE_FLAG(has_title);
    PARSE_FLAG(has_slug);
    PARSE_FLAG(has_gift);
    END_PARSE_FLAGS();
    if (has_custom_emoji_id) {
      td::parse(custom_emoji_id_, parser);
    }
    if (has_until_date) {
      td::parse(until_date_, parser);
    }
    if (has_collectible_id) {
      td::parse(collectible_id_, parser);
    }
    if (has_title) {
      td::parse(title_, parser);
    }
    if (has_slug) {
      td::parse(slug_, parser);
    }
    if (has_gift) {
      td::parse(model_custom_emoji_id_, parser);
      td::parse(pattern_custom_emoji_id_, parser);
      td::parse(center_color_, parser);
      td::parse(edge_color_, parser);
      td::parse(pattern_color_, parser);
      td::parse(text_color_, parser);
    }
  }
};

bool operator==(const EmojiStatus &lhs, const EmojiStatus &rhs);

inline bool operator!=(const EmojiStatus &lhs, const EmojiStatus &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const EmojiStatus &emoji_status);

StringBuilder &operator<<(StringBuilder &string_builder, const unique_ptr<EmojiStatus> &emoji_status);

td_api::object_ptr<td_api::emojiStatusCustomEmojis> get_emoji_status_custom_emojis_object(
    const vector<CustomEmojiId> &custom_emoji_ids);

void get_default_emoji_statuses(Td *td, Promise<td_api::object_ptr<td_api::emojiStatusCustomEmojis>> &&promise);

void get_default_channel_emoji_statuses(Td *td, Promise<td_api::object_ptr<td_api::emojiStatusCustomEmojis>> &&promise);

void get_recent_emoji_statuses(Td *td, Promise<td_api::object_ptr<td_api::emojiStatuses>> &&promise);

void add_recent_emoji_status(Td *td, EmojiStatus emoji_status);

void clear_recent_emoji_statuses(Td *td, Promise<Unit> &&promise);

void get_upgraded_gift_emoji_statuses(Td *td, Promise<td_api::object_ptr<td_api::emojiStatuses>> &&promise);

}  // namespace td
