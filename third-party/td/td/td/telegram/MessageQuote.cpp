//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageQuote.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/utf8.h"

namespace td {

MessageQuote::~MessageQuote() = default;

MessageQuote::MessageQuote(Td *td,
                           telegram_api::object_ptr<telegram_api::inputReplyToMessage> &input_reply_to_message) {
  CHECK(input_reply_to_message != nullptr);
  if (input_reply_to_message->quote_text_.empty()) {
    return;
  }
  text_ = get_formatted_text(td->user_manager_.get(), std::move(input_reply_to_message->quote_text_),
                             std::move(input_reply_to_message->quote_entities_), true, false, "inputReplyToMessage");
  remove_unallowed_quote_entities(text_);
  position_ = max(0, input_reply_to_message->quote_offset_);
}

MessageQuote::MessageQuote(Td *td, telegram_api::object_ptr<telegram_api::messageReplyHeader> &reply_header) {
  CHECK(reply_header != nullptr);
  if (reply_header->quote_text_.empty()) {
    return;
  }
  text_ = get_formatted_text(td->user_manager_.get(), std::move(reply_header->quote_text_),
                             std::move(reply_header->quote_entities_), true, false, "messageReplyHeader");
  remove_unallowed_quote_entities(text_);
  position_ = max(0, reply_header->quote_offset_);
  is_manual_ = reply_header->quote_;
}

MessageQuote::MessageQuote(Td *td, td_api::object_ptr<td_api::inputTextQuote> quote) {
  if (quote == nullptr) {
    return;
  }
  int32 ltrim_count = 0;
  auto r_text = get_formatted_text(td, td->dialog_manager_->get_my_dialog_id(), std::move(quote->text_),
                                   td->auth_manager_->is_bot(), true, true, false, &ltrim_count);
  if (!r_text.is_ok() || r_text.ok().text.empty()) {
    return;
  }
  text_ = r_text.move_as_ok();
  position_ = quote->position_;
  if (0 <= position_ && position_ <= 1000000) {  // some unreasonably big bound
    position_ += ltrim_count;
  } else {
    position_ = 0;
  }
}

MessageQuote MessageQuote::clone(bool ignore_is_manual) const {
  return {FormattedText(text_), position_, ignore_is_manual ? true : is_manual_};
}

MessageQuote MessageQuote::create_automatic_quote(Td *td, FormattedText &&text) {
  truncate_formatted_text(
      text, static_cast<size_t>(td->option_manager_->get_option_integer("message_reply_quote_length_max")));
  return MessageQuote(std::move(text), 0, false);
}

int MessageQuote::need_quote_changed_warning(const MessageQuote &old_quote, const MessageQuote &new_quote) {
  if (old_quote.position_ != new_quote.position_ &&
      max(old_quote.position_, new_quote.position_) <
          static_cast<int32>(min(old_quote.text_.text.size(), new_quote.text_.text.size()))) {
    // quote position can't change
    return 1;
  }
  if (old_quote.is_manual_ != new_quote.is_manual_) {
    // quote manual property can't change
    return 1;
  }
  if (old_quote.text_ != new_quote.text_) {
    if (old_quote.is_manual_) {
      return 1;
    }
    // automatic quote can change if the original message was edited
    return -1;
  }
  return 0;
}

void MessageQuote::add_dependencies(Dependencies &dependencies) const {
  add_formatted_text_dependencies(dependencies, &text_);  // just in case
}

void MessageQuote::update_input_reply_to_message(Td *td,
                                                 telegram_api::inputReplyToMessage *input_reply_to_message) const {
  CHECK(input_reply_to_message != nullptr);
  if (is_empty()) {
    return;
  }
  CHECK(is_manual_);
  input_reply_to_message->flags_ |= telegram_api::inputReplyToMessage::QUOTE_TEXT_MASK;
  input_reply_to_message->quote_text_ = text_.text;
  input_reply_to_message->quote_entities_ =
      get_input_message_entities(td->user_manager_.get(), text_.entities, "update_input_reply_to_message");
  if (!input_reply_to_message->quote_entities_.empty()) {
    input_reply_to_message->flags_ |= telegram_api::inputReplyToMessage::QUOTE_ENTITIES_MASK;
  }
  if (position_ != 0) {
    input_reply_to_message->flags_ |= telegram_api::inputReplyToMessage::QUOTE_OFFSET_MASK;
    input_reply_to_message->quote_offset_ = position_;
  }
}

// only for draft messages
td_api::object_ptr<td_api::inputTextQuote> MessageQuote::get_input_text_quote_object(
    const UserManager *user_manager) const {
  if (is_empty()) {
    return nullptr;
  }
  CHECK(is_manual_);
  return td_api::make_object<td_api::inputTextQuote>(get_formatted_text_object(user_manager, text_, true, -1),
                                                     position_);
}

td_api::object_ptr<td_api::textQuote> MessageQuote::get_text_quote_object(const UserManager *user_manager) const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::textQuote>(get_formatted_text_object(user_manager, text_, true, -1), position_,
                                                is_manual_);
}

bool operator==(const MessageQuote &lhs, const MessageQuote &rhs) {
  return lhs.text_ == rhs.text_ && lhs.position_ == rhs.position_ && lhs.is_manual_ == rhs.is_manual_;
}

bool operator!=(const MessageQuote &lhs, const MessageQuote &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageQuote &quote) {
  if (!quote.is_empty()) {
    string_builder << " with " << quote.text_.text.size() << (!quote.is_manual_ ? " automatically" : "")
                   << " quoted bytes";
    if (quote.position_ != 0) {
      string_builder << " at position " << quote.position_;
    }
  }
  return string_builder;
}

void MessageQuote::remove_unallowed_quote_entities(FormattedText &text) {
  auto is_allowed_quote_entity = [](const MessageEntity &entity) {
    switch (entity.type) {
      case MessageEntity::Type::Bold:
      case MessageEntity::Type::Italic:
      case MessageEntity::Type::Underline:
      case MessageEntity::Type::Strikethrough:
      case MessageEntity::Type::Spoiler:
      case MessageEntity::Type::CustomEmoji:
        return true;
      default:
        return false;
    }
  };

  td::remove_if(text.entities, [&](const auto &entity) { return !is_allowed_quote_entity(entity); });
}

int32 MessageQuote::search_quote(FormattedText &&text, FormattedText &&quote, int32 quote_position) {
  auto process_quote_entities = [](FormattedText &text, int32 length) {
    remove_unallowed_quote_entities(text);
    td::remove_if(text.entities, [length](const MessageEntity &entity) {
      if (entity.offset < 0 || entity.offset >= length) {
        return true;
      }
      if (entity.length <= 0 || entity.length > length - entity.offset) {
        return true;
      }
      return false;
    });
    remove_empty_entities(text.entities);
    fix_entities(text.entities);
    remove_empty_entities(text.entities);
  };
  auto length = narrow_cast<int32>(utf8_utf16_length(text.text));
  auto quote_length = narrow_cast<int32>(utf8_utf16_length(quote.text));
  if (quote_length == 0 || quote_length > length) {
    return -1;
  }
  process_quote_entities(text, length);
  process_quote_entities(quote, quote_length);

  quote_position = clamp(quote_position, 0, length - 1);
  vector<size_t> byte_positions;
  byte_positions.reserve(length);
  for (size_t i = 0; i < text.text.size(); i++) {
    auto c = static_cast<unsigned char>(text.text[i]);
    if (is_utf8_character_first_code_unit(c)) {
      byte_positions.push_back(i);
      if (c >= 0xf0) {  // >= 4 bytes in symbol => surrogate pair
        byte_positions.push_back(string::npos);
      }
    }
  }
  CHECK(byte_positions.size() == static_cast<size_t>(length));
  auto check_position = [&text, &quote, &byte_positions, length, quote_length](int32 position) {
    if (position < 0 || position > length - quote_length) {
      return false;
    }
    auto byte_position = byte_positions[position];
    if (byte_position == string::npos || text.text[byte_position] != quote.text[0] ||
        Slice(text.text).substr(byte_position, quote.text.size()) != quote.text) {
      return false;
    }
    return true;
  };
  for (int32 i = 0; quote_position - i >= 0 || quote_position + i + 1 <= length - quote_length; i++) {
    if (check_position(quote_position - i)) {
      return quote_position - i;
    }
    if (check_position(quote_position + i + 1)) {
      return quote_position + i + 1;
    }
  }
  return -1;
}

}  // namespace td
