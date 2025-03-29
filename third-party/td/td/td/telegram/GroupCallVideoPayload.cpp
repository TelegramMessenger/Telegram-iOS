//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/GroupCallVideoPayload.h"

#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"

namespace td {

bool operator==(const GroupCallVideoPayload &lhs, const GroupCallVideoPayload &rhs) {
  if (lhs.source_groups_.size() != rhs.source_groups_.size() || lhs.endpoint_ != rhs.endpoint_ ||
      lhs.is_paused_ != rhs.is_paused_) {
    return false;
  }
  for (size_t i = 0; i < lhs.source_groups_.size(); i++) {
    if (lhs.source_groups_[i].semantics_ != rhs.source_groups_[i].semantics_ ||
        lhs.source_groups_[i].source_ids_ != rhs.source_groups_[i].source_ids_) {
      return false;
    }
  }
  return true;
}

bool GroupCallVideoPayload::is_empty() const {
  return endpoint_.empty() || source_groups_.empty();
}

td_api::object_ptr<td_api::groupCallParticipantVideoInfo>
GroupCallVideoPayload::get_group_call_participant_video_info_object() const {
  if (is_empty()) {
    return nullptr;
  }

  auto get_group_call_video_source_group_object = [](const GroupCallVideoSourceGroup &group) {
    return td_api::make_object<td_api::groupCallVideoSourceGroup>(group.semantics_, vector<int32>(group.source_ids_));
  };
  return td_api::make_object<td_api::groupCallParticipantVideoInfo>(
      transform(source_groups_, get_group_call_video_source_group_object), endpoint_, is_paused_);
}

GroupCallVideoPayload::GroupCallVideoPayload(const telegram_api::groupCallParticipantVideo *video) {
  if (video == nullptr) {
    return;
  }

  endpoint_ = video->endpoint_;
  source_groups_ = transform(video->source_groups_, [](auto &&source_group) {
    GroupCallVideoSourceGroup result;
    result.semantics_ = source_group->semantics_;
    result.source_ids_ = source_group->sources_;
    return result;
  });
  if (!is_empty()) {
    is_paused_ = video->paused_;
  }
}

}  // namespace td
