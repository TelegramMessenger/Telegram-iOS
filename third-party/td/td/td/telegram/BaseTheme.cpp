//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BaseTheme.h"

namespace td {

bool is_dark_base_theme(BaseTheme base_theme) {
  switch (base_theme) {
    case BaseTheme::Classic:
    case BaseTheme::Day:
    case BaseTheme::Arctic:
      return false;
    case BaseTheme::Night:
    case BaseTheme::Tinted:
      return true;
    default:
      UNREACHABLE();
      return false;
  }
}

BaseTheme get_base_theme(const telegram_api::object_ptr<telegram_api::BaseTheme> &base_theme) {
  CHECK(base_theme != nullptr);
  switch (base_theme->get_id()) {
    case telegram_api::baseThemeClassic::ID:
      return BaseTheme::Classic;
    case telegram_api::baseThemeDay::ID:
      return BaseTheme::Day;
    case telegram_api::baseThemeNight::ID:
      return BaseTheme::Night;
    case telegram_api::baseThemeTinted::ID:
      return BaseTheme::Tinted;
    case telegram_api::baseThemeArctic::ID:
      return BaseTheme::Arctic;
    default:
      UNREACHABLE();
      return BaseTheme::Classic;
  }
}

}  // namespace td
