//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

// append-only
enum class BaseTheme : int32 { Classic, Day, Night, Tinted, Arctic };

bool is_dark_base_theme(BaseTheme base_theme);

BaseTheme get_base_theme(const telegram_api::object_ptr<telegram_api::BaseTheme> &base_theme);

}  // namespace td
