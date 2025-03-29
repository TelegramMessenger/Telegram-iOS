//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ReactionManager.h"

#include "td/telegram/ReactionType.hpp"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickersManager.hpp"
#include "td/telegram/Td.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ReactionManager::Reaction::store(StorerT &storer) const {
  StickersManager *stickers_manager = storer.context()->td().get_actor_unsafe()->stickers_manager_.get();
  bool has_around_animation = !around_animation_.empty();
  bool has_center_animation = !center_animation_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_active_);
  STORE_FLAG(has_around_animation);
  STORE_FLAG(has_center_animation);
  STORE_FLAG(is_premium_);
  END_STORE_FLAGS();
  td::store(reaction_type_, storer);
  td::store(title_, storer);
  stickers_manager->store_sticker(static_icon_, false, storer, "Reaction");
  stickers_manager->store_sticker(appear_animation_, false, storer, "Reaction");
  stickers_manager->store_sticker(select_animation_, false, storer, "Reaction");
  stickers_manager->store_sticker(activate_animation_, false, storer, "Reaction");
  stickers_manager->store_sticker(effect_animation_, false, storer, "Reaction");
  if (has_around_animation) {
    stickers_manager->store_sticker(around_animation_, false, storer, "Reaction");
  }
  if (has_center_animation) {
    stickers_manager->store_sticker(center_animation_, false, storer, "Reaction");
  }
}

template <class ParserT>
void ReactionManager::Reaction::parse(ParserT &parser) {
  StickersManager *stickers_manager = parser.context()->td().get_actor_unsafe()->stickers_manager_.get();
  bool has_around_animation;
  bool has_center_animation;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_active_);
  PARSE_FLAG(has_around_animation);
  PARSE_FLAG(has_center_animation);
  PARSE_FLAG(is_premium_);
  END_PARSE_FLAGS();
  td::parse(reaction_type_, parser);
  td::parse(title_, parser);
  static_icon_ = stickers_manager->parse_sticker(false, parser);
  appear_animation_ = stickers_manager->parse_sticker(false, parser);
  select_animation_ = stickers_manager->parse_sticker(false, parser);
  activate_animation_ = stickers_manager->parse_sticker(false, parser);
  effect_animation_ = stickers_manager->parse_sticker(false, parser);
  if (has_around_animation) {
    around_animation_ = stickers_manager->parse_sticker(false, parser);
  }
  if (has_center_animation) {
    center_animation_ = stickers_manager->parse_sticker(false, parser);
  }

  is_premium_ = false;
}

template <class StorerT>
void ReactionManager::Reactions::store(StorerT &storer) const {
  bool has_reactions = !reactions_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_reactions);
  END_STORE_FLAGS();
  if (has_reactions) {
    td::store(reactions_, storer);
    td::store(hash_, storer);
  }
}

template <class ParserT>
void ReactionManager::Reactions::parse(ParserT &parser) {
  bool has_reactions;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_reactions);
  END_PARSE_FLAGS();
  if (has_reactions) {
    td::parse(reactions_, parser);
    td::parse(hash_, parser);
  }
}

template <class StorerT>
void ReactionManager::ReactionList::store(StorerT &storer) const {
  bool has_reaction_types = !reaction_types_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_reaction_types);
  END_STORE_FLAGS();
  if (has_reaction_types) {
    td::store(reaction_types_, storer);
    td::store(hash_, storer);
  }
}

template <class ParserT>
void ReactionManager::ReactionList::parse(ParserT &parser) {
  bool has_reaction_types;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_reaction_types);
  END_PARSE_FLAGS();
  if (has_reaction_types) {
    td::parse(reaction_types_, parser);
    td::parse(hash_, parser);
  }
}

template <class StorerT>
void ReactionManager::Effect::store(StorerT &storer) const {
  StickersManager *stickers_manager = storer.context()->td().get_actor_unsafe()->stickers_manager_.get();
  bool has_static_icon = static_icon_id_.is_valid();
  bool has_effect_animation = effect_animation_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_premium_);
  STORE_FLAG(has_static_icon);
  STORE_FLAG(has_effect_animation);
  END_STORE_FLAGS();
  td::store(id_, storer);
  td::store(emoji_, storer);
  if (has_static_icon) {
    stickers_manager->store_sticker(static_icon_id_, false, storer, "Effect");
  }
  stickers_manager->store_sticker(effect_sticker_id_, false, storer, "Effect");
  if (has_effect_animation) {
    stickers_manager->store_sticker(effect_animation_id_, false, storer, "Effect");
  }
}

template <class ParserT>
void ReactionManager::Effect::parse(ParserT &parser) {
  StickersManager *stickers_manager = parser.context()->td().get_actor_unsafe()->stickers_manager_.get();
  bool has_static_icon;
  bool has_effect_animation;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_premium_);
  PARSE_FLAG(has_static_icon);
  PARSE_FLAG(has_effect_animation);
  END_PARSE_FLAGS();
  td::parse(id_, parser);
  td::parse(emoji_, parser);
  if (has_static_icon) {
    static_icon_id_ = stickers_manager->parse_sticker(false, parser);
  }
  effect_sticker_id_ = stickers_manager->parse_sticker(false, parser);
  if (has_effect_animation) {
    effect_animation_id_ = stickers_manager->parse_sticker(false, parser);
  }
}

template <class StorerT>
void ReactionManager::Effects::store(StorerT &storer) const {
  bool has_effects = !effects_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_effects);
  END_STORE_FLAGS();
  if (has_effects) {
    td::store(effects_, storer);
    td::store(hash_, storer);
  }
}

template <class ParserT>
void ReactionManager::Effects::parse(ParserT &parser) {
  bool has_effects;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_effects);
  END_PARSE_FLAGS();
  if (has_effects) {
    td::parse(effects_, parser);
    td::parse(hash_, parser);
  }
}

template <class StorerT>
void ReactionManager::ActiveEffects::store(StorerT &storer) const {
  bool has_reaction_effects = !reaction_effects_.empty();
  bool has_sticker_effects = !sticker_effects_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_reaction_effects);
  STORE_FLAG(has_sticker_effects);
  END_STORE_FLAGS();
  if (has_reaction_effects) {
    td::store(reaction_effects_, storer);
  }
  if (has_sticker_effects) {
    td::store(sticker_effects_, storer);
  }
}

template <class ParserT>
void ReactionManager::ActiveEffects::parse(ParserT &parser) {
  bool has_reaction_effects;
  bool has_sticker_effects;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_reaction_effects);
  PARSE_FLAG(has_sticker_effects);
  END_PARSE_FLAGS();
  if (has_reaction_effects) {
    td::parse(reaction_effects_, parser);
  }
  if (has_sticker_effects) {
    td::parse(sticker_effects_, parser);
  }
}

}  // namespace td
