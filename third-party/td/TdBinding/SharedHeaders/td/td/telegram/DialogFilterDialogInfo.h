//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/FolderId.h"

#include "td/utils/common.h"

namespace td {

struct DialogFilterDialogInfo {
  DialogId dialog_id_;
  FolderId folder_id_;
  bool has_unread_mentions_ = false;
  bool is_muted_ = false;
  bool has_unread_messages_ = false;
};

}  // namespace td
