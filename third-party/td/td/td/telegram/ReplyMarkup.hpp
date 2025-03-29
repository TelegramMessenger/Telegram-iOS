//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ReplyMarkup.h"
#include "td/telegram/RequestedDialogType.hpp"
#include "td/telegram/Version.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void store(const KeyboardButton &button, StorerT &storer) {
  bool has_url = !button.url.empty();
  bool has_requested_dialog_type = button.requested_dialog_type != nullptr;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_url);
  STORE_FLAG(has_requested_dialog_type);
  END_STORE_FLAGS();
  store(button.type, storer);
  store(button.text, storer);
  if (has_url) {
    store(button.url, storer);
  }
  if (has_requested_dialog_type) {
    store(button.requested_dialog_type, storer);
  }
}

template <class ParserT>
void parse(KeyboardButton &button, ParserT &parser) {
  bool has_url;
  bool has_requested_dialog_type;
  if (parser.version() >= static_cast<int32>(Version::AddKeyboardButtonFlags)) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_url);
    PARSE_FLAG(has_requested_dialog_type);
    END_PARSE_FLAGS();
  } else {
    has_url = false;
    has_requested_dialog_type = false;
  }
  parse(button.type, parser);
  parse(button.text, parser);
  if (has_url) {
    parse(button.url, parser);
  }
  if (has_requested_dialog_type) {
    parse(button.requested_dialog_type, parser);
  }
}

template <class StorerT>
void store(const InlineKeyboardButton &button, StorerT &storer) {
  bool has_id = button.id != 0;
  bool has_user_id = button.user_id.is_valid();
  bool has_forward_text = !button.forward_text.empty();
  bool has_data = !button.data.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_id);
  STORE_FLAG(has_user_id);
  STORE_FLAG(has_forward_text);
  STORE_FLAG(has_data);
  END_STORE_FLAGS();
  store(button.type, storer);
  if (has_id) {
    store(button.id, storer);
  }
  if (has_user_id) {
    store(button.user_id, storer);
  }
  store(button.text, storer);
  if (has_forward_text) {
    store(button.forward_text, storer);
  }
  if (has_data) {
    store(button.data, storer);
  }
}

template <class ParserT>
void parse(InlineKeyboardButton &button, ParserT &parser) {
  if (parser.version() >= static_cast<int32>(Version::AddKeyboardButtonFlags)) {
    bool has_id;
    bool has_user_id;
    bool has_forward_text;
    bool has_data;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_id);
    PARSE_FLAG(has_user_id);
    PARSE_FLAG(has_forward_text);
    PARSE_FLAG(has_data);
    END_PARSE_FLAGS();
    parse(button.type, parser);
    if (has_id) {
      parse(button.id, parser);
    }
    if (has_user_id) {
      parse(button.user_id, parser);
    }
    parse(button.text, parser);
    if (has_forward_text) {
      parse(button.forward_text, parser);
    }
    if (has_data) {
      parse(button.data, parser);
    }
  } else {
    parse(button.type, parser);
    if (button.type == InlineKeyboardButton::Type::UrlAuth) {
      if (parser.version() >= static_cast<int32>(Version::Support64BitIds)) {
        parse(button.id, parser);
      } else {
        int32 old_id;
        parse(old_id, parser);
        button.id = old_id;
      }
    }
    parse(button.text, parser);
    parse(button.data, parser);
  }
}

template <class StorerT>
void store(const ReplyMarkup &reply_markup, StorerT &storer) {
  bool has_keyboard = !reply_markup.keyboard.empty();
  bool has_inline_keyboard = !reply_markup.inline_keyboard.empty();
  bool has_placeholder = !reply_markup.placeholder.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(reply_markup.is_personal);
  STORE_FLAG(reply_markup.need_resize_keyboard);
  STORE_FLAG(reply_markup.is_one_time_keyboard);
  STORE_FLAG(has_keyboard);
  STORE_FLAG(has_inline_keyboard);
  STORE_FLAG(has_placeholder);
  STORE_FLAG(reply_markup.is_persistent);
  END_STORE_FLAGS();
  store(reply_markup.type, storer);
  if (has_keyboard) {
    store(reply_markup.keyboard, storer);
  }
  if (has_inline_keyboard) {
    store(reply_markup.inline_keyboard, storer);
  }
  if (has_placeholder) {
    store(reply_markup.placeholder, storer);
  }
}

template <class ParserT>
void parse(ReplyMarkup &reply_markup, ParserT &parser) {
  bool has_keyboard;
  bool has_inline_keyboard;
  bool has_placeholder;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(reply_markup.is_personal);
  PARSE_FLAG(reply_markup.need_resize_keyboard);
  PARSE_FLAG(reply_markup.is_one_time_keyboard);
  PARSE_FLAG(has_keyboard);
  PARSE_FLAG(has_inline_keyboard);
  PARSE_FLAG(has_placeholder);
  PARSE_FLAG(reply_markup.is_persistent);
  END_PARSE_FLAGS();
  parse(reply_markup.type, parser);
  if (has_keyboard) {
    parse(reply_markup.keyboard, parser);
  }
  if (has_inline_keyboard) {
    parse(reply_markup.inline_keyboard, parser);
  }
  if (has_placeholder) {
    parse(reply_markup.placeholder, parser);
  }
}

}  // namespace td
