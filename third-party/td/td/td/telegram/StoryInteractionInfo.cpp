//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StoryInteractionInfo.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"

#include <algorithm>

namespace td {

StoryInteractionInfo::StoryInteractionInfo(Td *td, telegram_api::object_ptr<telegram_api::storyViews> &&story_views) {
  if (story_views == nullptr) {
    return;
  }
  for (auto &viewer_id : story_views->recent_viewers_) {
    UserId user_id(viewer_id);
    if (user_id.is_valid() && td->user_manager_->have_min_user(user_id)) {
      if (recent_viewer_user_ids_.size() == MAX_RECENT_VIEWERS) {
        LOG(ERROR) << "Receive too many recent story viewers: " << story_views->recent_viewers_;
        break;
      }
      recent_viewer_user_ids_.push_back(user_id);
    } else {
      LOG(ERROR) << "Receive " << user_id << " as recent viewer";
    }
  }
  view_count_ = story_views->views_count_;
  if (view_count_ < 0) {
    LOG(ERROR) << "Receive " << view_count_ << " story views";
    view_count_ = 0;
  }
  forward_count_ = story_views->forwards_count_;
  if (forward_count_ < 0) {
    LOG(ERROR) << "Receive " << forward_count_ << " story forwards";
    forward_count_ = 0;
  }
  reaction_count_ = story_views->reactions_count_;
  if (reaction_count_ < 0) {
    LOG(ERROR) << "Receive " << reaction_count_ << " story reactions";
    reaction_count_ = 0;
  }
  has_viewers_ = story_views->has_viewers_;

  FlatHashSet<ReactionType, ReactionTypeHash> added_reaction_types;
  for (auto &reaction : story_views->reactions_) {
    ReactionType reaction_type(reaction->reaction_);
    if (reaction_type.is_empty() || reaction_type.is_paid_reaction()) {
      LOG(ERROR) << "Receive " << to_string(reaction);
      continue;
    }
    if (!added_reaction_types.insert(reaction_type).second) {
      LOG(ERROR) << "Receive again " << to_string(reaction);
      continue;
    }
    if (reaction->count_ == 0) {
      LOG(ERROR) << "Receive " << to_string(reaction);
      continue;
    }
    reaction_counts_.emplace_back(std::move(reaction_type), reaction->count_);
  }
  std::sort(reaction_counts_.begin(), reaction_counts_.end());
}

void StoryInteractionInfo::add_dependencies(Dependencies &dependencies) const {
  for (auto user_id : recent_viewer_user_ids_) {
    dependencies.add(user_id);
  }
}

void StoryInteractionInfo::set_chosen_reaction_type(const ReactionType &new_reaction_type,
                                                    const ReactionType &old_reaction_type) {
  if (!old_reaction_type.is_empty()) {
    CHECK(!old_reaction_type.is_paid_reaction());
    for (auto it = reaction_counts_.begin(); it != reaction_counts_.end(); ++it) {
      if (it->first == old_reaction_type) {
        it->second--;
        if (it->second == 0) {
          reaction_counts_.erase(it);
        }
        break;
      }
    }
  }
  if (!new_reaction_type.is_empty()) {
    CHECK(!new_reaction_type.is_paid_reaction());
    bool is_found = false;
    for (auto it = reaction_counts_.begin(); it != reaction_counts_.end(); ++it) {
      if (it->first == old_reaction_type) {
        it->second++;
        is_found = true;
      }
    }
    if (!is_found) {
      reaction_counts_.emplace_back(new_reaction_type, 1);
    }
  }
  std::sort(reaction_counts_.begin(), reaction_counts_.end());
}

bool StoryInteractionInfo::set_recent_viewer_user_ids(vector<UserId> &&user_ids) {
  if (recent_viewer_user_ids_.empty() && view_count_ > 0) {
    // don't update recent viewers for stories with expired viewers
    return false;
  }
  if (user_ids.size() > MAX_RECENT_VIEWERS) {
    user_ids.resize(MAX_RECENT_VIEWERS);
  }
  if (recent_viewer_user_ids_.size() < user_ids.size() && user_ids.size() <= static_cast<size_t>(view_count_)) {
    return false;
  }
  if (recent_viewer_user_ids_ != user_ids) {
    recent_viewer_user_ids_ = std::move(user_ids);
    return true;
  }
  return false;
}

bool StoryInteractionInfo::definitely_has_no_user(UserId user_id) const {
  return !is_empty() && view_count_ == static_cast<int32>(recent_viewer_user_ids_.size()) &&
         !contains(recent_viewer_user_ids_, user_id);
}

td_api::object_ptr<td_api::storyInteractionInfo> StoryInteractionInfo::get_story_interaction_info_object(Td *td) const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::storyInteractionInfo>(
      view_count_, forward_count_, reaction_count_,
      td->user_manager_->get_user_ids_object(recent_viewer_user_ids_, "get_story_interaction_info_object"));
}

bool operator==(const StoryInteractionInfo &lhs, const StoryInteractionInfo &rhs) {
  return lhs.recent_viewer_user_ids_ == rhs.recent_viewer_user_ids_ && lhs.reaction_counts_ == rhs.reaction_counts_ &&
         lhs.view_count_ == rhs.view_count_ && lhs.forward_count_ == rhs.forward_count_ &&
         lhs.reaction_count_ == rhs.reaction_count_ && lhs.has_viewers_ == rhs.has_viewers_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const StoryInteractionInfo &info) {
  return string_builder << info.view_count_ << " views and " << info.forward_count_ << " forwards with "
                        << info.reaction_count_ << " reactions by " << info.recent_viewer_user_ids_;
}

}  // namespace td
