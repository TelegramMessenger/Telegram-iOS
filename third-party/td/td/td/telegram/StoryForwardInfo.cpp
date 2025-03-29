//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StoryForwardInfo.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

StoryForwardInfo::StoryForwardInfo(Td *td, telegram_api::object_ptr<telegram_api::storyFwdHeader> &&fwd_header) {
  CHECK(fwd_header != nullptr);
  is_modified_ = fwd_header->modified_;
  if (fwd_header->from_ != nullptr) {
    dialog_id_ = DialogId(fwd_header->from_);
    story_id_ = StoryId(fwd_header->story_id_);
    if (!dialog_id_.is_valid() || !story_id_.is_server()) {
      LOG(ERROR) << "Receive " << to_string(fwd_header);
      dialog_id_ = {};
      story_id_ = {};
    } else {
      td->dialog_manager_->force_create_dialog(dialog_id_, "StoryForwardInfo", true);
    }
  } else if ((fwd_header->flags_ & telegram_api::storyFwdHeader::FROM_NAME_MASK) != 0) {
    if (fwd_header->story_id_ != 0) {
      LOG(ERROR) << "Receive " << to_string(fwd_header);
    }
    sender_name_ = std::move(fwd_header->from_name_);
  } else {
    LOG(ERROR) << "Receive " << to_string(fwd_header);
  }
}

void StoryForwardInfo::hide_sender_if_needed(Td *td) {
  // currently, there is no need to hide sender client-side
}

void StoryForwardInfo::add_dependencies(Dependencies &dependencies) const {
  // don't try to load original story
  dependencies.add_dialog_and_dependencies(dialog_id_);
}

td_api::object_ptr<td_api::storyRepostInfo> StoryForwardInfo::get_story_repost_info_object(Td *td) const {
  auto origin = [&]() -> td_api::object_ptr<td_api::StoryOrigin> {
    if (dialog_id_.is_valid() && story_id_.is_valid()) {
      return td_api::make_object<td_api::storyOriginPublicStory>(
          td->dialog_manager_->get_chat_id_object(dialog_id_, "storyOriginPublicStory"), story_id_.get());
    }
    return td_api::make_object<td_api::storyOriginHiddenUser>(sender_name_);
  }();
  return td_api::make_object<td_api::storyRepostInfo>(std::move(origin), is_modified_);
}

bool operator==(const StoryForwardInfo &lhs, const StoryForwardInfo &rhs) {
  return lhs.dialog_id_ == rhs.dialog_id_ && lhs.story_id_ == rhs.story_id_ && lhs.sender_name_ == rhs.sender_name_ &&
         lhs.is_modified_ == rhs.is_modified_;
}

}  // namespace td
