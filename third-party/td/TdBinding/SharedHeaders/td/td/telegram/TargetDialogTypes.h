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
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class TargetDialogTypes {
  int64 mask_ = 0;

  static constexpr int64 USERS_MASK = 1;
  static constexpr int64 BOTS_MASK = 2;
  static constexpr int64 CHATS_MASK = 4;
  static constexpr int64 BROADCASTS_MASK = 8;
  static constexpr int64 FULL_MASK = USERS_MASK | BOTS_MASK | CHATS_MASK | BROADCASTS_MASK;

  friend bool operator==(const TargetDialogTypes &lhs, const TargetDialogTypes &rhs);
  friend bool operator!=(const TargetDialogTypes &lhs, const TargetDialogTypes &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const TargetDialogTypes &types);

 public:
  TargetDialogTypes() = default;

  explicit TargetDialogTypes(int64 mask) : mask_(mask) {
  }

  explicit TargetDialogTypes(const vector<telegram_api::object_ptr<telegram_api::InlineQueryPeerType>> &types);

  static Result<TargetDialogTypes> get_target_dialog_types(const td_api::object_ptr<td_api::targetChatTypes> &types);

  int64 get_mask() const {
    return mask_;
  }

  int64 get_full_mask() const {
    return mask_ == 0 ? FULL_MASK : mask_;
  }

  vector<telegram_api::object_ptr<telegram_api::InlineQueryPeerType>> get_input_peer_types() const;

  td_api::object_ptr<td_api::targetChatTypes> get_target_chat_types_object() const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const TargetDialogTypes &types);

}  // namespace td
