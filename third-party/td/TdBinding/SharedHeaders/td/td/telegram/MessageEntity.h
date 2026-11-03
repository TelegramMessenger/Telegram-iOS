//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <utility>

namespace td {

class Dependencies;
class MultiPromiseActor;
class Td;
class UserManager;

class MessageEntity {
 public:
  enum class Type : int32 {
    Mention,
    Hashtag,
    BotCommand,
    Url,
    EmailAddress,
    Bold,
    Italic,
    Code,
    Pre,
    PreCode,
    TextUrl,
    MentionName,
    Cashtag,
    PhoneNumber,
    Underline,
    Strikethrough,
    BlockQuote,
    BankCardNumber,
    MediaTimestamp,
    Spoiler,
    CustomEmoji,
    ExpandableBlockQuote,
    Size
  };
  Type type = Type::Size;
  int32 offset = -1;
  int32 length = -1;
  int32 media_timestamp = -1;
  string argument;
  UserId user_id;
  CustomEmojiId custom_emoji_id;

  MessageEntity() = default;

  MessageEntity(Type type, int32 offset, int32 length, string argument = "")
      : type(type), offset(offset), length(length), argument(std::move(argument)) {
  }
  MessageEntity(int32 offset, int32 length, UserId user_id)
      : type(Type::MentionName), offset(offset), length(length), user_id(user_id) {
  }
  MessageEntity(Type type, int32 offset, int32 length, int32 media_timestamp)
      : type(type), offset(offset), length(length), media_timestamp(media_timestamp) {
    CHECK(type == Type::MediaTimestamp);
  }
  MessageEntity(Type type, int32 offset, int32 length, CustomEmojiId custom_emoji_id)
      : type(type), offset(offset), length(length), custom_emoji_id(custom_emoji_id) {
    CHECK(type == Type::CustomEmoji);
  }

  tl_object_ptr<td_api::textEntity> get_text_entity_object(const UserManager *user_manager) const;

  bool operator==(const MessageEntity &other) const {
    return offset == other.offset && length == other.length && type == other.type &&
           media_timestamp == other.media_timestamp && argument == other.argument && user_id == other.user_id &&
           custom_emoji_id == other.custom_emoji_id;
  }

  bool operator<(const MessageEntity &other) const {
    if (offset != other.offset) {
      return offset < other.offset;
    }
    if (length != other.length) {
      return length > other.length;
    }
    auto priority = get_type_priority(type);
    auto other_priority = get_type_priority(other.type);
    return priority < other_priority;
  }

  bool operator!=(const MessageEntity &rhs) const {
    return !(*this == rhs);
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  tl_object_ptr<td_api::TextEntityType> get_text_entity_type_object(const UserManager *user_manager) const;

  static int get_type_priority(Type type);
};

StringBuilder &operator<<(StringBuilder &string_builder, const MessageEntity::Type &message_entity_type);

StringBuilder &operator<<(StringBuilder &string_builder, const MessageEntity &message_entity);

struct FormattedText {
  string text;
  vector<MessageEntity> entities;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

struct FormattedTextHash {
  uint32 operator()(const FormattedText &formatted_text) const {
    auto hash = Hash<string>()(formatted_text.text);
    for (auto &entity : formatted_text.entities) {
      hash = combine_hashes(hash, Hash<int32>()(static_cast<int32>(entity.type)));
      hash = combine_hashes(hash, Hash<int32>()(entity.length));
      hash = combine_hashes(hash, Hash<int32>()(entity.offset));
    }
    return hash;
  }
};

StringBuilder &operator<<(StringBuilder &string_builder, const FormattedText &text);

inline bool operator==(const FormattedText &lhs, const FormattedText &rhs) {
  return lhs.text == rhs.text && lhs.entities == rhs.entities;
}

inline bool operator!=(const FormattedText &lhs, const FormattedText &rhs) {
  return !(lhs == rhs);
}

const FlatHashSet<Slice, SliceHash> &get_valid_short_usernames();

Result<vector<MessageEntity>> get_message_entities(const UserManager *user_manager,
                                                   vector<tl_object_ptr<td_api::textEntity>> &&input_entities,
                                                   bool allow_all = false);

vector<tl_object_ptr<td_api::textEntity>> get_text_entities_object(const UserManager *user_manager,
                                                                   const vector<MessageEntity> &entities,
                                                                   bool skip_bot_commands, int32 max_media_timestamp);

td_api::object_ptr<td_api::formattedText> get_formatted_text_object(const UserManager *user_manager,
                                                                    const FormattedText &text, bool skip_bot_commands,
                                                                    int32 max_media_timestamp);

void keep_only_custom_emoji(FormattedText &text);

void remove_premium_custom_emoji_entities(const Td *td, vector<MessageEntity> &entities, bool remove_unknown);

void remove_unallowed_entities(const Td *td, FormattedText &text, DialogId dialog_id);

vector<MessageEntity> find_entities(Slice text, bool skip_bot_commands, bool skip_media_timestamps);

vector<Slice> find_mentions(Slice str);
vector<Slice> find_bot_commands(Slice str);
vector<Slice> find_hashtags(Slice str);
vector<Slice> find_cashtags(Slice str);
vector<Slice> find_bank_card_numbers(Slice str);
vector<Slice> find_tg_urls(Slice str);
bool is_email_address(Slice str);
vector<std::pair<Slice, bool>> find_urls(Slice str);               // slice + is_email_address
vector<std::pair<Slice, int32>> find_media_timestamps(Slice str);  // slice + media_timestamp

void remove_empty_entities(vector<MessageEntity> &entities);

Slice get_first_url(const FormattedText &text);

bool is_visible_url(const FormattedText &text, const string &url);

Result<vector<MessageEntity>> parse_markdown(string &text);

Result<vector<MessageEntity>> parse_markdown_v2(string &text);

FormattedText parse_markdown_v3(FormattedText text);

FormattedText get_markdown_v3(FormattedText text);

Result<vector<MessageEntity>> parse_html(string &str);

vector<tl_object_ptr<telegram_api::MessageEntity>> get_input_message_entities(const UserManager *user_manager,
                                                                              const vector<MessageEntity> &entities,
                                                                              const char *source);

vector<tl_object_ptr<telegram_api::MessageEntity>> get_input_message_entities(const UserManager *user_manager,
                                                                              const FormattedText *text,
                                                                              const char *source);

vector<tl_object_ptr<secret_api::MessageEntity>> get_input_secret_message_entities(
    const vector<MessageEntity> &entities, int32 layer);

vector<MessageEntity> get_message_entities(Td *td, vector<tl_object_ptr<secret_api::MessageEntity>> &&secret_entities,
                                           bool is_premium, MultiPromiseActor &load_data_multipromise);

telegram_api::object_ptr<telegram_api::textWithEntities> get_input_text_with_entities(const UserManager *user_manager,
                                                                                      const FormattedText &text,
                                                                                      const char *source);

FormattedText get_formatted_text(const UserManager *user_manager, string &&text,
                                 vector<telegram_api::object_ptr<telegram_api::MessageEntity>> &&server_entities,
                                 bool skip_media_timestamps, bool skip_trim, const char *source);

FormattedText get_formatted_text(const UserManager *user_manager,
                                 telegram_api::object_ptr<telegram_api::textWithEntities> text_with_entities,
                                 bool skip_media_timestamps, bool skip_trim, const char *source);

void fix_entities(vector<MessageEntity> &entities);

// like clean_input_string but also validates entities
Status fix_formatted_text(string &text, vector<MessageEntity> &entities, bool allow_empty, bool skip_new_entities,
                          bool skip_bot_commands, bool skip_media_timestamps, bool skip_trim,
                          int32 *ltrim_count = nullptr) TD_WARN_UNUSED_RESULT;

FormattedText get_message_text(const UserManager *user_manager, string message_text,
                               vector<tl_object_ptr<telegram_api::MessageEntity>> &&server_entities,
                               bool skip_new_entities, bool skip_media_timestamps, int32 send_date, bool from_album,
                               const char *source);

void truncate_formatted_text(FormattedText &text, size_t length);

Result<FormattedText> get_formatted_text(const Td *td, DialogId dialog_id,
                                         td_api::object_ptr<td_api::formattedText> &&text, bool is_bot,
                                         bool allow_empty, bool skip_media_timestamps, bool skip_trim,
                                         int32 *ltrim_count = nullptr);

void add_formatted_text_dependencies(Dependencies &dependencies, const FormattedText *text);

bool has_media_timestamps(const FormattedText *text, int32 min_media_timestamp, int32 max_media_timestamp);

bool has_bot_commands(const FormattedText *text);

bool need_always_skip_bot_commands(const UserManager *user_manager, DialogId dialog_id, bool is_bot);

}  // namespace td
