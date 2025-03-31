//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageReaction.h"

#include "td/telegram/MessageReactor.hpp"
#include "td/telegram/MinChannel.hpp"
#include "td/telegram/ReactionType.hpp"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MessageReaction::store(StorerT &storer) const {
  CHECK(!is_empty());
  bool has_recent_chooser_dialog_ids = !recent_chooser_dialog_ids_.empty();
  bool has_recent_chooser_min_channels = !recent_chooser_min_channels_.empty();
  bool has_my_recent_chooser_dialog_id = my_recent_chooser_dialog_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_chosen_);
  STORE_FLAG(has_recent_chooser_dialog_ids);
  STORE_FLAG(has_recent_chooser_min_channels);
  STORE_FLAG(has_my_recent_chooser_dialog_id);
  END_STORE_FLAGS();
  td::store(reaction_type_, storer);
  td::store(choose_count_, storer);
  if (has_recent_chooser_dialog_ids) {
    td::store(recent_chooser_dialog_ids_, storer);
  }
  if (has_recent_chooser_min_channels) {
    td::store(recent_chooser_min_channels_, storer);
  }
  if (has_my_recent_chooser_dialog_id) {
    td::store(my_recent_chooser_dialog_id_, storer);
  }
}

template <class ParserT>
void MessageReaction::parse(ParserT &parser) {
  bool has_recent_chooser_dialog_ids;
  bool has_recent_chooser_min_channels;
  bool has_my_recent_chooser_dialog_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_chosen_);
  PARSE_FLAG(has_recent_chooser_dialog_ids);
  PARSE_FLAG(has_recent_chooser_min_channels);
  PARSE_FLAG(has_my_recent_chooser_dialog_id);
  END_PARSE_FLAGS();
  td::parse(reaction_type_, parser);
  td::parse(choose_count_, parser);
  if (has_recent_chooser_dialog_ids) {
    td::parse(recent_chooser_dialog_ids_, parser);
  }
  if (has_recent_chooser_min_channels) {
    td::parse(recent_chooser_min_channels_, parser);
  }
  if (has_my_recent_chooser_dialog_id) {
    td::parse(my_recent_chooser_dialog_id_, parser);
    if (!my_recent_chooser_dialog_id_.is_valid() ||
        !td::contains(recent_chooser_dialog_ids_, my_recent_chooser_dialog_id_)) {
      return parser.set_error("Invalid recent reaction chooser");
    }
  }
  fix_choose_count();

  if (is_empty() || reaction_type_.is_empty()) {
    parser.set_error("Invalid message reaction");
  }
}

template <class StorerT>
void UnreadMessageReaction::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_big_);
  END_STORE_FLAGS();
  td::store(reaction_type_, storer);
  td::store(sender_dialog_id_, storer);
}

template <class ParserT>
void UnreadMessageReaction::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_big_);
  END_PARSE_FLAGS();
  td::parse(reaction_type_, parser);
  td::parse(sender_dialog_id_, parser);
  if (reaction_type_.is_empty()) {
    parser.set_error("Invalid unread message reaction");
  }
}

template <class StorerT>
void MessageReactions::store(StorerT &storer) const {
  bool has_reactions = !reactions_.empty();
  bool has_unread_reactions = !unread_reactions_.empty();
  bool has_chosen_reaction_order = !chosen_reaction_order_.empty();
  bool has_top_reactors = !top_reactors_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_min_);
  STORE_FLAG(need_polling_);
  STORE_FLAG(can_get_added_reactions_);
  STORE_FLAG(has_unread_reactions);
  STORE_FLAG(has_reactions);
  STORE_FLAG(has_chosen_reaction_order);
  STORE_FLAG(are_tags_);
  STORE_FLAG(has_top_reactors);
  END_STORE_FLAGS();
  if (has_reactions) {
    td::store(reactions_, storer);
  }
  if (has_unread_reactions) {
    td::store(unread_reactions_, storer);
  }
  if (has_chosen_reaction_order) {
    td::store(chosen_reaction_order_, storer);
  }
  if (has_top_reactors) {
    td::store(top_reactors_, storer);
  }
}

template <class ParserT>
void MessageReactions::parse(ParserT &parser) {
  bool has_reactions;
  bool has_unread_reactions;
  bool has_chosen_reaction_order;
  bool has_top_reactors;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_min_);
  PARSE_FLAG(need_polling_);
  PARSE_FLAG(can_get_added_reactions_);
  PARSE_FLAG(has_unread_reactions);
  PARSE_FLAG(has_reactions);
  PARSE_FLAG(has_chosen_reaction_order);
  PARSE_FLAG(are_tags_);
  PARSE_FLAG(has_top_reactors);
  END_PARSE_FLAGS();
  if (has_reactions) {
    td::parse(reactions_, parser);
  }
  if (has_unread_reactions) {
    td::parse(unread_reactions_, parser);
  }
  if (has_chosen_reaction_order) {
    td::parse(chosen_reaction_order_, parser);
  }
  if (has_top_reactors) {
    td::parse(top_reactors_, parser);
  }
}

}  // namespace td
