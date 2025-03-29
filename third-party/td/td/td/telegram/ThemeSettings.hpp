//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ThemeSettings.h"

#include "td/telegram/BackgroundInfo.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ThemeSettings::store(StorerT &storer) const {
  bool has_message_accent_color = message_accent_color_ != accent_color_;
  bool has_background = background_info_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(animate_message_colors_);
  STORE_FLAG(has_message_accent_color);
  STORE_FLAG(has_background);
  END_STORE_FLAGS();
  td::store(accent_color_, storer);
  if (has_message_accent_color) {
    td::store(message_accent_color_, storer);
  }
  if (has_background) {
    td::store(background_info_, storer);
  }
  td::store(base_theme_, storer);
  td::store(message_colors_, storer);
}

template <class ParserT>
void ThemeSettings::parse(ParserT &parser) {
  bool has_message_accent_color;
  bool has_background;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(animate_message_colors_);
  PARSE_FLAG(has_message_accent_color);
  PARSE_FLAG(has_background);
  END_PARSE_FLAGS();
  td::parse(accent_color_, parser);
  if (has_message_accent_color) {
    td::parse(message_accent_color_, parser);
  } else {
    message_accent_color_ = accent_color_;
  }
  if (has_background) {
    td::parse(background_info_, parser);
  }
  td::parse(base_theme_, parser);
  td::parse(message_colors_, parser);
}

}  // namespace td
