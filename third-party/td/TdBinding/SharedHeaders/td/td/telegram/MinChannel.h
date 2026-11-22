//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AccentColorId.h"
#include "td/telegram/Photo.h"

#include "td/utils/common.h"

namespace td {

struct MinChannel {
  string title_;
  DialogPhoto photo_;
  AccentColorId accent_color_id_;
  bool is_megagroup_ = false;
};

}  // namespace td
