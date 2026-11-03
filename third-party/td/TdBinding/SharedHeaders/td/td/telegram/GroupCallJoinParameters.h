//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

struct GroupCallJoinParameters {
  string payload_;
  int32 audio_source_ = 0;
  bool is_muted_ = false;
  bool is_my_video_enabled_ = false;

  static Result<GroupCallJoinParameters> get_group_call_join_parameters(
      td_api::object_ptr<td_api::groupCallJoinParameters> &&parameters, bool allow_empty);

  bool is_empty() const {
    return payload_.empty();
  }
};

}  // namespace td
