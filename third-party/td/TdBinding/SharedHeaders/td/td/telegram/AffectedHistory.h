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

struct AffectedHistory {
  int32 pts_;
  int32 pts_count_;
  bool is_final_;

  explicit AffectedHistory(tl_object_ptr<telegram_api::messages_affectedHistory> &&affected_history)
      : pts_(affected_history->pts_)
      , pts_count_(affected_history->pts_count_)
      , is_final_(affected_history->offset_ <= 0) {
  }

  explicit AffectedHistory(tl_object_ptr<telegram_api::messages_affectedFoundMessages> &&affected_history)
      : pts_(affected_history->pts_)
      , pts_count_(affected_history->pts_count_)
      , is_final_(affected_history->offset_ <= 0) {
  }
};

}  // namespace td
