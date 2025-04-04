//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AccentColorId.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/telegram_api.h"

namespace td {

struct PeerColor {
  AccentColorId accent_color_id_;
  CustomEmojiId background_custom_emoji_id_;

  explicit PeerColor(const telegram_api::object_ptr<telegram_api::peerColor> &peer_color);
};

}  // namespace td
