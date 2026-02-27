//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ReactionType.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

#include <utility>

namespace td {

class Dependencies;
class Td;

class StoryInteractionInfo {
  vector<UserId> recent_viewer_user_ids_;
  vector<std::pair<ReactionType, int32>> reaction_counts_;
  int32 view_count_ = -1;
  int32 forward_count_ = 0;
  int32 reaction_count_ = 0;
  bool has_viewers_ = false;

  static constexpr size_t MAX_RECENT_VIEWERS = 3;

  friend bool operator==(const StoryInteractionInfo &lhs, const StoryInteractionInfo &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StoryInteractionInfo &info);

 public:
  StoryInteractionInfo() = default;

  StoryInteractionInfo(Td *td, telegram_api::object_ptr<telegram_api::storyViews> &&story_views);

  bool is_empty() const {
    return view_count_ < 0;
  }

  bool has_hidden_viewers() const {
    return view_count_ < 0 || !has_viewers_;
  }

  void add_dependencies(Dependencies &dependencies) const;

  bool set_counts(int32 view_count, int32 reaction_count) {
    if (view_count != view_count_ || reaction_count != reaction_count_) {
      view_count = view_count_;
      reaction_count = reaction_count_;
      return true;
    }
    return false;
  }

  void set_chosen_reaction_type(const ReactionType &new_reaction_type, const ReactionType &old_reaction_type);

  int32 get_view_count() const {
    return view_count_;
  }

  int32 get_reaction_count() const {
    return reaction_count_;
  }

  const vector<std::pair<ReactionType, int32>> &get_reaction_counts() const {
    return reaction_counts_;
  }

  bool definitely_has_no_user(UserId user_id) const;

  bool set_recent_viewer_user_ids(vector<UserId> &&user_ids);

  td_api::object_ptr<td_api::storyInteractionInfo> get_story_interaction_info_object(Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StoryInteractionInfo &lhs, const StoryInteractionInfo &rhs);

inline bool operator!=(const StoryInteractionInfo &lhs, const StoryInteractionInfo &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StoryInteractionInfo &info);

}  // namespace td
