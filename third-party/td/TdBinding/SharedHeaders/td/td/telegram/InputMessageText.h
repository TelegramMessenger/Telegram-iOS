//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class Dependencies;

class Td;

class UserManager;

class InputMessageText {
 public:
  FormattedText text;
  string web_page_url;
  bool disable_web_page_preview = false;
  bool force_small_media = false;
  bool force_large_media = false;
  bool show_above_text = false;
  bool clear_draft = false;

  InputMessageText() = default;
  InputMessageText(FormattedText text, string &&web_page_url, bool disable_web_page_preview, bool force_small_media,
                   bool force_large_media, bool show_above_text, bool clear_draft)
      : text(std::move(text))
      , web_page_url(std::move(web_page_url))
      , disable_web_page_preview(disable_web_page_preview)
      , force_small_media(force_small_media)
      , force_large_media(force_large_media)
      , show_above_text(show_above_text)
      , clear_draft(clear_draft) {
  }

  bool is_empty() const {
    return text.text.empty() && web_page_url.empty();
  }

  void add_dependencies(Dependencies &dependencies) const;

  telegram_api::object_ptr<telegram_api::InputMedia> get_input_media_web_page() const;

  td_api::object_ptr<td_api::inputMessageText> get_input_message_text_object(const UserManager *user_manager) const;
};

bool operator==(const InputMessageText &lhs, const InputMessageText &rhs);
bool operator!=(const InputMessageText &lhs, const InputMessageText &rhs);

Result<InputMessageText> process_input_message_text(const Td *td, DialogId dialog_id,
                                                    tl_object_ptr<td_api::InputMessageContent> &&input_message_content,
                                                    bool is_bot, bool for_draft = false) TD_WARN_UNUSED_RESULT;

}  // namespace td
