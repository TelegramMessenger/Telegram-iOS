//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StoryViewer.h"

#include "td/telegram/BlockListId.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/Td.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"

namespace td {

StoryViewer::StoryViewer(Td *td, telegram_api::object_ptr<telegram_api::StoryView> &&story_view_ptr) {
  CHECK(story_view_ptr != nullptr);
  switch (story_view_ptr->get_id()) {
    case telegram_api::storyView::ID: {
      auto story_view = telegram_api::move_object_as<telegram_api::storyView>(story_view_ptr);
      UserId user_id(story_view->user_id_);
      if (!user_id.is_valid() || story_view->date_ <= 0) {
        break;
      }
      type_ = Type::View;
      actor_dialog_id_ = DialogId(user_id);
      date_ = story_view->date_;
      is_blocked_ = story_view->blocked_;
      is_blocked_for_stories_ = story_view->blocked_my_stories_from_;
      reaction_type_ = ReactionType(story_view->reaction_);
      break;
    }
    case telegram_api::storyViewPublicForward::ID: {
      auto story_view = telegram_api::move_object_as<telegram_api::storyViewPublicForward>(story_view_ptr);
      auto date = MessagesManager::get_message_date(story_view->message_);
      auto message_full_id = td->messages_manager_->on_get_message(std::move(story_view->message_), false, true, false,
                                                                   "storyViewPublicForward");
      if (!message_full_id.get_message_id().is_valid() || date <= 0) {
        break;
      }
      type_ = Type::Forward;
      actor_dialog_id_ = td->messages_manager_->get_dialog_message_sender(message_full_id);
      date_ = date;
      is_blocked_ = story_view->blocked_;
      is_blocked_for_stories_ = story_view->blocked_my_stories_from_;
      message_full_id_ = message_full_id;
      break;
    }
    case telegram_api::storyViewPublicRepost::ID: {
      auto story_view = telegram_api::move_object_as<telegram_api::storyViewPublicRepost>(story_view_ptr);
      auto owner_dialog_id = DialogId(story_view->peer_id_);
      if (!owner_dialog_id.is_valid()) {
        break;
      }
      auto story_id = td->story_manager_->on_get_story(owner_dialog_id, std::move(story_view->story_));
      auto date = td->story_manager_->get_story_date({owner_dialog_id, story_id});
      if (date <= 0) {
        break;
      }
      type_ = Type::Repost;
      actor_dialog_id_ = owner_dialog_id;
      date_ = date;
      is_blocked_ = story_view->blocked_;
      is_blocked_for_stories_ = story_view->blocked_my_stories_from_;
      story_id_ = story_id;
      break;
    }
    default:
      UNREACHABLE();
      break;
  }

  if (is_valid()) {
    td->messages_manager_->on_update_dialog_is_blocked(actor_dialog_id_, is_blocked_, is_blocked_for_stories_);
  }
}

StoryViewer::StoryViewer(Td *td, telegram_api::object_ptr<telegram_api::StoryReaction> &&story_reaction_ptr) {
  CHECK(story_reaction_ptr != nullptr);
  switch (story_reaction_ptr->get_id()) {
    case telegram_api::storyReaction::ID: {
      auto story_reaction = telegram_api::move_object_as<telegram_api::storyReaction>(story_reaction_ptr);
      DialogId actor_dialog_id(story_reaction->peer_id_);
      if (!actor_dialog_id.is_valid() || story_reaction->date_ <= 0) {
        break;
      }
      type_ = Type::View;
      actor_dialog_id_ = actor_dialog_id;
      date_ = story_reaction->date_;
      reaction_type_ = ReactionType(story_reaction->reaction_);
      break;
    }
    case telegram_api::storyReactionPublicForward::ID: {
      auto story_reaction = telegram_api::move_object_as<telegram_api::storyReactionPublicForward>(story_reaction_ptr);
      auto date = MessagesManager::get_message_date(story_reaction->message_);
      auto message_full_id = td->messages_manager_->on_get_message(std::move(story_reaction->message_), false, true,
                                                                   false, "storyReactionPublicForward");
      if (!message_full_id.get_message_id().is_valid() || date <= 0) {
        break;
      }
      type_ = Type::Forward;
      actor_dialog_id_ = td->messages_manager_->get_dialog_message_sender(message_full_id);
      date_ = date;
      message_full_id_ = message_full_id;
      break;
    }
    case telegram_api::storyReactionPublicRepost::ID: {
      auto story_reaction = telegram_api::move_object_as<telegram_api::storyReactionPublicRepost>(story_reaction_ptr);
      auto owner_dialog_id = DialogId(story_reaction->peer_id_);
      if (!owner_dialog_id.is_valid()) {
        break;
      }
      auto story_id = td->story_manager_->on_get_story(owner_dialog_id, std::move(story_reaction->story_));
      auto date = td->story_manager_->get_story_date({owner_dialog_id, story_id});
      if (date <= 0) {
        break;
      }
      type_ = Type::Repost;
      actor_dialog_id_ = owner_dialog_id;
      date_ = date;
      story_id_ = story_id;
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

td_api::object_ptr<td_api::storyInteraction> StoryViewer::get_story_interaction_object(Td *td) const {
  CHECK(is_valid());
  auto type = [&]() -> td_api::object_ptr<td_api::StoryInteractionType> {
    switch (type_) {
      case Type::View:
        return td_api::make_object<td_api::storyInteractionTypeView>(reaction_type_.get_reaction_type_object());
      case Type::Forward: {
        auto message_object =
            td->messages_manager_->get_message_object(message_full_id_, "storyInteractionTypeForward");
        CHECK(message_object != nullptr);
        return td_api::make_object<td_api::storyInteractionTypeForward>(std::move(message_object));
      }
      case Type::Repost: {
        auto story_object = td->story_manager_->get_story_object({actor_dialog_id_, story_id_});
        CHECK(story_object != nullptr);
        return td_api::make_object<td_api::storyInteractionTypeRepost>(std::move(story_object));
      }
      default:
        UNREACHABLE();
        return nullptr;
    }
  }();
  auto block_list_id = BlockListId(is_blocked_, is_blocked_for_stories_);
  return td_api::make_object<td_api::storyInteraction>(
      get_message_sender_object(td, actor_dialog_id_, "storyInteraction"), date_, block_list_id.get_block_list_object(),
      std::move(type));
}

bool StoryViewer::is_valid() const {
  return type_ != Type::None && actor_dialog_id_.is_valid() && date_ > 0;
}

StringBuilder &operator<<(StringBuilder &string_builder, const StoryViewer &viewer) {
  return string_builder << '[' << viewer.actor_dialog_id_ << " with " << viewer.reaction_type_ << " at " << viewer.date_
                        << ']';
}

StoryViewers::StoryViewers(Td *td, int32 total_count, int32 total_forward_count, int32 total_reaction_count,
                           vector<telegram_api::object_ptr<telegram_api::StoryView>> &&story_views,
                           string &&next_offset)
    : total_count_(total_count)
    , total_forward_count_(total_forward_count)
    , total_reaction_count_(total_reaction_count)
    , next_offset_(std::move(next_offset)) {
  for (auto &story_view : story_views) {
    StoryViewer story_viewer(td, std::move(story_view));
    if (!story_viewer.is_valid()) {
      LOG(ERROR) << "Receive invalid story interaction";
      continue;
    }
    story_viewers_.push_back(std::move(story_viewer));
  }
}

StoryViewers::StoryViewers(Td *td, int32 total_count,
                           vector<telegram_api::object_ptr<telegram_api::StoryReaction>> &&story_reactions,
                           string &&next_offset)
    : total_count_(total_count), next_offset_(std::move(next_offset)) {
  for (auto &story_reaction : story_reactions) {
    StoryViewer story_viewer(td, std::move(story_reaction));
    if (!story_viewer.is_valid()) {
      LOG(ERROR) << "Receive invalid story interaction";
      continue;
    }
    story_viewers_.push_back(std::move(story_viewer));
  }
}

vector<UserId> StoryViewers::get_viewer_user_ids() const {
  vector<UserId> result;
  for (const auto &story_viewer : story_viewers_) {
    auto user_id = story_viewer.get_viewer_user_id();
    if (user_id.is_valid()) {
      result.push_back(user_id);
    }
  }
  return result;
}

vector<DialogId> StoryViewers::get_actor_dialog_ids() const {
  return transform(story_viewers_, [](auto &viewer) { return viewer.get_actor_dialog_id(); });
}

td_api::object_ptr<td_api::storyInteractions> StoryViewers::get_story_interactions_object(Td *td) const {
  return td_api::make_object<td_api::storyInteractions>(
      total_count_, total_forward_count_, total_reaction_count_,
      transform(story_viewers_,
                [td](const StoryViewer &story_viewer) { return story_viewer.get_story_interaction_object(td); }),
      next_offset_);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StoryViewers &viewers) {
  return string_builder << viewers.story_viewers_;
}

}  // namespace td
