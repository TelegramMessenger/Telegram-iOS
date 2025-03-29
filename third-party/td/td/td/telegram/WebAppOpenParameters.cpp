//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/WebAppOpenParameters.h"

#include "td/telegram/misc.h"
#include "td/telegram/ThemeManager.h"

namespace td {

WebAppOpenParameters::WebAppOpenParameters(td_api::object_ptr<td_api::webAppOpenParameters> &&parameters) {
  if (parameters != nullptr) {
    theme_parameters_ = std::move(parameters->theme_);
    application_name_ = std::move(parameters->application_name_);
    if (!clean_input_string(application_name_)) {
      application_name_.clear();
    }
    if (parameters->mode_ != nullptr) {
      switch (parameters->mode_->get_id()) {
        case td_api::webAppOpenModeCompact::ID:
          is_compact_ = true;
          break;
        case td_api::webAppOpenModeFullSize::ID:
          break;
        case td_api::webAppOpenModeFullScreen::ID:
          is_full_screen_ = true;
          break;
        default:
          UNREACHABLE();
      }
    }
  }
}

telegram_api::object_ptr<telegram_api::dataJSON> WebAppOpenParameters::get_input_theme_parameters() const {
  if (theme_parameters_ == nullptr) {
    return nullptr;
  }
  return telegram_api::make_object<telegram_api::dataJSON>(
      ThemeManager::get_theme_parameters_json_string(theme_parameters_));
}

}  // namespace td
