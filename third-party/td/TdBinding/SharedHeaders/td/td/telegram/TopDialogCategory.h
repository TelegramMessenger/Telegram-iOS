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
#include "td/utils/Slice.h"

namespace td {

enum class TopDialogCategory : int32 {
  Correspondent,
  BotPM,
  BotInline,
  Group,
  Channel,
  Call,
  ForwardUsers,
  ForwardChats,
  BotApp,
  Size
};

CSlice get_top_dialog_category_name(TopDialogCategory category);

TopDialogCategory get_top_dialog_category(const td_api::object_ptr<td_api::TopChatCategory> &category);

TopDialogCategory get_top_dialog_category(const telegram_api::object_ptr<telegram_api::TopPeerCategory> &category);

telegram_api::object_ptr<telegram_api::TopPeerCategory> get_input_top_peer_category(TopDialogCategory category);

}  // namespace td
