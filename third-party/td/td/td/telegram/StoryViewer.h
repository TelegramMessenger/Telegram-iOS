//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/ReactionType.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class StoryViewer {
  enum class Type : int32 { None, View, Forward, Repost };
  Type type_ = Type::None;

  DialogId actor_dialog_id_;
  int32 date_ = 0;
  bool is_blocked_ = false;
  bool is_blocked_for_stories_ = false;

  ReactionType reaction_type_;     // for View
  MessageFullId message_full_id_;  // for Forward
  StoryId story_id_;               // for Repost

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StoryViewer &viewer);

 public:
  StoryViewer(Td *td, telegram_api::object_ptr<telegram_api::StoryView> &&story_view_ptr);

  StoryViewer(Td *td, telegram_api::object_ptr<telegram_api::StoryReaction> &&story_reaction_ptr);

  UserId get_viewer_user_id() const {
    return type_ == Type::View ? actor_dialog_id_.get_user_id() : UserId();
  }

  DialogId get_actor_dialog_id() const {
    return actor_dialog_id_;
  }

  bool is_valid() const;

  td_api::object_ptr<td_api::storyInteraction> get_story_interaction_object(Td *td) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const StoryViewer &viewer);

class StoryViewers {
  int32 total_count_ = 0;
  int32 total_forward_count_ = 0;
  int32 total_reaction_count_ = 0;
  vector<StoryViewer> story_viewers_;
  string next_offset_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StoryViewers &viewers);

 public:
  StoryViewers(Td *td, int32 total_count, int32 total_forward_count, int32 total_reaction_count,
               vector<telegram_api::object_ptr<telegram_api::StoryView>> &&story_views, string &&next_offset);

  StoryViewers(Td *td, int32 total_count,
               vector<telegram_api::object_ptr<telegram_api::StoryReaction>> &&story_reactions, string &&next_offset);

  vector<UserId> get_viewer_user_ids() const;

  vector<DialogId> get_actor_dialog_ids() const;

  td_api::object_ptr<td_api::storyInteractions> get_story_interactions_object(Td *td) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const StoryViewers &viewers);

}  // namespace td
