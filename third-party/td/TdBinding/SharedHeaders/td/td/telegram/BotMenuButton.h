//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Td;

class BotMenuButton {
  string text_;
  string url_;

  friend bool operator==(const BotMenuButton &lhs, const BotMenuButton &rhs);

 public:
  BotMenuButton() = default;

  BotMenuButton(string &&text, string &&url) : text_(std::move(text)), url_(std::move(url)) {
  }

  td_api::object_ptr<td_api::botMenuButton> get_bot_menu_button_object(Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_text = !text_.empty();
    bool has_url = !url_.empty();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_text);
    STORE_FLAG(has_url);
    END_STORE_FLAGS();
    if (has_text) {
      td::store(text_, storer);
    }
    if (has_url) {
      td::store(url_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_text;
    bool has_url;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_text);
    PARSE_FLAG(has_url);
    END_PARSE_FLAGS();
    if (has_text) {
      td::parse(text_, parser);
    }
    if (has_url) {
      td::parse(url_, parser);
    }
  }
};

bool operator==(const BotMenuButton &lhs, const BotMenuButton &rhs);

inline bool operator!=(const BotMenuButton &lhs, const BotMenuButton &rhs) {
  return !(lhs == rhs);
}

unique_ptr<BotMenuButton> get_bot_menu_button(telegram_api::object_ptr<telegram_api::BotMenuButton> &&bot_menu_button);

td_api::object_ptr<td_api::botMenuButton> get_bot_menu_button_object(Td *td, const BotMenuButton *bot_menu_button);

void set_menu_button(Td *td, UserId user_id, td_api::object_ptr<td_api::botMenuButton> &&menu_button,
                     Promise<Unit> &&promise);

void get_menu_button(Td *td, UserId user_id, Promise<td_api::object_ptr<td_api::botMenuButton>> &&promise);

}  // namespace td
