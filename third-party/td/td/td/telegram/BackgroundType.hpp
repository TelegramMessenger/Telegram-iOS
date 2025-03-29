//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BackgroundType.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BackgroundType::store(StorerT &storer) const {
  using td::store;
  bool has_fill = fill_.top_color_ != 0 || fill_.bottom_color_ != 0;
  bool has_intensity = intensity_ != 0;
  auto fill_type = fill_.get_type();
  bool is_gradient = fill_type == BackgroundFill::Type::Gradient;
  bool is_freeform_gradient = fill_type == BackgroundFill::Type::FreeformGradient;
  bool has_theme_name = !theme_name_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_blurred_);
  STORE_FLAG(is_moving_);
  STORE_FLAG(has_fill);
  STORE_FLAG(has_intensity);
  STORE_FLAG(is_gradient);
  STORE_FLAG(is_freeform_gradient);
  STORE_FLAG(has_theme_name);
  END_STORE_FLAGS();
  store(type_, storer);
  if (is_freeform_gradient) {
    store(fill_.top_color_, storer);
    store(fill_.bottom_color_, storer);
    store(fill_.third_color_, storer);
    store(fill_.fourth_color_, storer);
  } else if (has_fill) {
    store(fill_.top_color_, storer);
    if (is_gradient) {
      store(fill_.bottom_color_, storer);
      store(fill_.rotation_angle_, storer);
    }
  }
  if (has_intensity) {
    store(intensity_, storer);
  }
  if (has_theme_name) {
    store(theme_name_, storer);
  }
}

template <class ParserT>
void BackgroundType::parse(ParserT &parser) {
  using td::parse;
  bool has_fill;
  bool has_intensity;
  bool is_gradient;
  bool is_freeform_gradient;
  bool has_theme_name;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_blurred_);
  PARSE_FLAG(is_moving_);
  PARSE_FLAG(has_fill);
  PARSE_FLAG(has_intensity);
  PARSE_FLAG(is_gradient);
  PARSE_FLAG(is_freeform_gradient);
  PARSE_FLAG(has_theme_name);
  END_PARSE_FLAGS();
  parse(type_, parser);
  if (is_freeform_gradient) {
    parse(fill_.top_color_, parser);
    parse(fill_.bottom_color_, parser);
    parse(fill_.third_color_, parser);
    parse(fill_.fourth_color_, parser);
  } else if (has_fill) {
    parse(fill_.top_color_, parser);
    if (is_gradient) {
      parse(fill_.bottom_color_, parser);
      parse(fill_.rotation_angle_, parser);
    } else {
      fill_.bottom_color_ = fill_.top_color_;
    }
  }
  if (has_intensity) {
    parse(intensity_, parser);
  }
  if (has_theme_name) {
    parse(theme_name_, parser);
  }
}

}  // namespace td
