//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/InputMessageText.h"

#include "td/telegram/MessageEntity.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void store(const InputMessageText &input_message_text, StorerT &storer) {
  bool has_web_page_url = !input_message_text.web_page_url.empty();
  bool has_empty_text = input_message_text.text.text.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(input_message_text.disable_web_page_preview);
  STORE_FLAG(input_message_text.clear_draft);
  STORE_FLAG(input_message_text.force_small_media);
  STORE_FLAG(input_message_text.force_large_media);
  STORE_FLAG(has_web_page_url);
  STORE_FLAG(has_empty_text);
  END_STORE_FLAGS();
  if (!has_empty_text) {
    store(input_message_text.text, storer);
  }
  if (has_web_page_url) {
    store(input_message_text.web_page_url, storer);
  }
}

template <class ParserT>
void parse(InputMessageText &input_message_text, ParserT &parser) {
  bool has_web_page_url;
  bool has_empty_text;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(input_message_text.disable_web_page_preview);
  PARSE_FLAG(input_message_text.clear_draft);
  PARSE_FLAG(input_message_text.force_small_media);
  PARSE_FLAG(input_message_text.force_large_media);
  PARSE_FLAG(has_web_page_url);
  PARSE_FLAG(has_empty_text);
  END_PARSE_FLAGS();
  if (!has_empty_text) {
    parse(input_message_text.text, parser);
  }
  if (has_web_page_url) {
    parse(input_message_text.web_page_url, parser);
  }
}

}  // namespace td
