//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

class StoryNotificationSettings {
 public:
  const bool need_dialog_settings_ = false;
  const bool need_top_dialogs_ = false;
  const bool are_muted_ = false;
  const bool hide_sender_ = false;
  const int64 ringtone_id_ = 0;

  StoryNotificationSettings(bool need_dialog_settings, bool need_top_dialogs, bool are_muted, bool hide_sender,
                            int64 ringtone_id)
      : need_dialog_settings_(need_dialog_settings)
      , need_top_dialogs_(need_top_dialogs)
      , are_muted_(are_muted)
      , hide_sender_(hide_sender)
      , ringtone_id_(ringtone_id) {
  }
};

}  // namespace td
