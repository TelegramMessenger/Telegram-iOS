//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

class WebAppOpenParameters {
  td_api::object_ptr<td_api::themeParameters> theme_parameters_;
  string application_name_;
  bool is_compact_ = false;
  bool is_full_screen_ = false;

 public:
  explicit WebAppOpenParameters(td_api::object_ptr<td_api::webAppOpenParameters> &&parameters);

  telegram_api::object_ptr<telegram_api::dataJSON> get_input_theme_parameters() const;

  const string &get_application_name() const {
    return application_name_;
  }

  bool is_compact() const {
    return is_compact_;
  }

  bool is_full_screen() const {
    return is_full_screen_;
  }
};

}  // namespace td
