//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReactionManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/PaidReactionType.hpp"
#include "td/telegram/ReactionManager.hpp"
#include "td/telegram/ReactionType.hpp"
#include "td/telegram/SavedMessagesManager.h"
#include "td/telegram/StickerFormat.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"

#include "td/db/SqliteKeyValue.h"
#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

#include <algorithm>
#include <type_traits>

namespace td {

class GetAvailableReactionsQuery final : public Td::ResultHandler {
 public:
  void send(int32 hash) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getAvailableReactions(hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getAvailableReactions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetAvailableReactionsQuery: " << to_string(ptr);
    td_->reaction_manager_->on_get_available_reactions(std::move(ptr));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for GetAvailableReactionsQuery: " << status;
    td_->reaction_manager_->on_get_available_reactions(nullptr);
  }
};

class GetReactionListQuery final : public Td::ResultHandler {
  ReactionListType reaction_list_type_;

 public:
  void send(ReactionListType reaction_list_type, int64 hash) {
    reaction_list_type_ = reaction_list_type;
    switch (reaction_list_type) {
      case ReactionListType::Recent:
        send_query(G()->net_query_creator().create(
            telegram_api::messages_getRecentReactions(ReactionManager::MAX_RECENT_REACTIONS, hash)));
        break;
      case ReactionListType::Top:
        send_query(G()->net_query_creator().create(telegram_api::messages_getTopReactions(200, hash)));
        break;
      case ReactionListType::DefaultTag:
        send_query(G()->net_query_creator().create(telegram_api::messages_getDefaultTagReactions(hash)));
        break;
      default:
        UNREACHABLE();
        break;
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_getRecentReactions::ReturnType,
                               telegram_api::messages_getTopReactions::ReturnType>::value,
                  "");
    static_assert(std::is_same<telegram_api::messages_getRecentReactions::ReturnType,
                               telegram_api::messages_getDefaultTagReactions::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_getRecentReactions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetReactionListQuery: " << to_string(ptr);
    td_->reaction_manager_->on_get_reaction_list(reaction_list_type_, std::move(ptr));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for GetReactionListQuery: " << status;
    td_->reaction_manager_->on_get_reaction_list(reaction_list_type_, nullptr);
  }
};

class ClearRecentReactionsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ClearRecentReactionsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_clearRecentReactions()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_clearRecentReactions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->reaction_manager_->reload_reaction_list(ReactionListType::Recent, "ClearRecentReactionsQuery");
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for clear recent reactions: " << status;
    }
    td_->reaction_manager_->reload_reaction_list(ReactionListType::Recent, "ClearRecentReactionsQuery");
    promise_.set_error(std::move(status));
  }
};

class SetDefaultReactionQuery final : public Td::ResultHandler {
  ReactionType reaction_type_;

 public:
  void send(const ReactionType &reaction_type) {
    reaction_type_ = reaction_type;
    send_query(
        G()->net_query_creator().create(telegram_api::messages_setDefaultReaction(reaction_type.get_input_reaction())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setDefaultReaction>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!result_ptr.ok()) {
      return on_error(Status::Error(400, "Receive false"));
    }

    auto default_reaction = td_->option_manager_->get_option_string("default_reaction", "-");
    if (default_reaction != reaction_type_.get_string()) {
      td_->reaction_manager_->send_set_default_reaction_query();
    } else {
      td_->option_manager_->set_option_empty("default_reaction_needs_sync");
    }
  }

  void on_error(Status status) final {
    if (G()->close_flag()) {
      return;
    }

    LOG(INFO) << "Receive error for SetDefaultReactionQuery: " << status;
    td_->option_manager_->set_option_empty("default_reaction_needs_sync");
    send_closure(G()->config_manager(), &ConfigManager::request_config, false);
  }
};

class GetSavedReactionTagsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_SavedReactionTags>> promise_;

 public:
  explicit GetSavedReactionTagsQuery(
      Promise<telegram_api::object_ptr<telegram_api::messages_SavedReactionTags>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(SavedMessagesTopicId saved_messages_topic_id, int64 hash) {
    int32 flags = 0;
    telegram_api::object_ptr<telegram_api::InputPeer> saved_input_peer;
    if (saved_messages_topic_id.is_valid()) {
      flags |= telegram_api::messages_getSavedReactionTags::PEER_MASK;
      saved_input_peer = saved_messages_topic_id.get_input_peer(td_);
      CHECK(saved_input_peer != nullptr);
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_getSavedReactionTags(flags, std::move(saved_input_peer), hash),
        {td_->dialog_manager_->get_my_dialog_id()}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getSavedReactionTags>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetSavedReactionTagsQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateSavedReactionTagQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateSavedReactionTagQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const ReactionType &reaction_type, const string &title) {
    int32 flags = 0;
    if (!title.empty()) {
      flags |= telegram_api::messages_updateSavedReactionTag::TITLE_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_updateSavedReactionTag(flags, reaction_type.get_input_reaction(), title)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_updateSavedReactionTag>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetMessageAvailableEffectsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_AvailableEffects>> promise_;

 public:
  explicit GetMessageAvailableEffectsQuery(
      Promise<telegram_api::object_ptr<telegram_api::messages_AvailableEffects>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int32 hash) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getAvailableEffects(hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getAvailableEffects>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetMessageAvailableEffectsQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

ReactionManager::SavedReactionTag::SavedReactionTag(telegram_api::object_ptr<telegram_api::savedReactionTag> &&tag)
    : reaction_type_(tag->reaction_)
    , hash_(reaction_type_.get_hash())
    , title_(std::move(tag->title_))
    , count_(tag->count_) {
}

ReactionManager::SavedReactionTag::SavedReactionTag(const ReactionType &reaction_type, const string &title, int32 count)
    : reaction_type_(reaction_type), hash_(reaction_type_.get_hash()), title_(title), count_(count) {
}

td_api::object_ptr<td_api::savedMessagesTag> ReactionManager::SavedReactionTag::get_saved_messages_tag_object() const {
  return td_api::make_object<td_api::savedMessagesTag>(reaction_type_.get_reaction_type_object(), title_, count_);
}

template <class StorerT>
void ReactionManager::SavedReactionTag::store(StorerT &storer) const {
  bool has_title = !title_.empty();
  bool has_count = count_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_title);
  STORE_FLAG(has_count);
  END_STORE_FLAGS();
  td::store(reaction_type_, storer);
  if (has_title) {
    td::store(title_, storer);
  }
  if (has_count) {
    td::store(count_, storer);
  }
}

template <class ParserT>
void ReactionManager::SavedReactionTag::parse(ParserT &parser) {
  bool has_title;
  bool has_count;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_title);
  PARSE_FLAG(has_count);
  END_PARSE_FLAGS();
  td::parse(reaction_type_, parser);
  hash_ = reaction_type_.get_hash();
  if (has_title) {
    td::parse(title_, parser);
  }
  if (has_count) {
    td::parse(count_, parser);
  }
}

bool operator==(const ReactionManager::SavedReactionTag &lhs, const ReactionManager::SavedReactionTag &rhs) {
  return lhs.reaction_type_ == rhs.reaction_type_ && lhs.title_ == rhs.title_ && lhs.count_ == rhs.count_;
}

bool operator!=(const ReactionManager::SavedReactionTag &lhs, const ReactionManager::SavedReactionTag &rhs) {
  return !(lhs == rhs);
}

bool operator<(const ReactionManager::SavedReactionTag &lhs, const ReactionManager::SavedReactionTag &rhs) {
  if (lhs.count_ != rhs.count_) {
    return lhs.count_ > rhs.count_;
  }
  return lhs.hash_ > rhs.hash_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReactionManager::SavedReactionTag &saved_reaction_tag) {
  return string_builder << "SavedMessagesTag{" << saved_reaction_tag.reaction_type_ << '(' << saved_reaction_tag.title_
                        << ") X " << saved_reaction_tag.count_ << '}';
}

td_api::object_ptr<td_api::savedMessagesTags> ReactionManager::SavedReactionTags::get_saved_messages_tags_object()
    const {
  return td_api::make_object<td_api::savedMessagesTags>(
      transform(tags_, [](const SavedReactionTag &tag) { return tag.get_saved_messages_tag_object(); }));
}

bool ReactionManager::SavedReactionTags::update_saved_messages_tags(const vector<ReactionType> &old_tags,
                                                                    const vector<ReactionType> &new_tags) {
  if (!is_inited_) {
    return false;
  }
  bool is_changed = false;
  for (const auto &old_tag : old_tags) {
    if (!td::contains(new_tags, old_tag)) {
      CHECK(!old_tag.is_empty());
      for (auto it = tags_.begin(); it != tags_.end(); ++it) {
        auto &tag = *it;
        if (tag.reaction_type_ == old_tag) {
          tag.count_--;
          if (!tag.is_valid()) {
            tags_.erase(it);
          }
          is_changed = true;
          break;
        }
      }
    }
  }
  for (const auto &new_tag : new_tags) {
    if (!td::contains(old_tags, new_tag)) {
      CHECK(!new_tag.is_empty());
      is_changed = true;
      bool is_found = false;
      for (auto &tag : tags_) {
        if (tag.reaction_type_ == new_tag) {
          tag.count_++;
          is_found = true;
          break;
        }
      }
      if (!is_found) {
        tags_.emplace_back(new_tag, string(), 1);
      }
    }
  }
  if (is_changed) {
    std::sort(tags_.begin(), tags_.end());
    hash_ = calc_hash();
  }
  return is_changed;
}

bool ReactionManager::SavedReactionTags::set_tag_title(const ReactionType &reaction_type, const string &title) {
  if (!is_inited_) {
    return false;
  }
  for (auto it = tags_.begin(); it != tags_.end(); ++it) {
    auto &tag = *it;
    if (tag.reaction_type_ == reaction_type) {
      if (tag.title_ == title) {
        return false;
      }
      tag.title_ = title;
      if (!tag.is_valid()) {
        tags_.erase(it);
      }
      hash_ = calc_hash();
      return true;
    }
  }
  tags_.emplace_back(reaction_type, title, 0);
  std::sort(tags_.begin(), tags_.end());
  hash_ = calc_hash();
  return true;
}

int64 ReactionManager::SavedReactionTags::calc_hash() const {
  vector<uint64> numbers;
  for (const auto &tag : tags_) {
    numbers.push_back(tag.hash_);
    if (!tag.title_.empty()) {
      numbers.push_back(get_md5_string_hash(tag.title_));
    }
    numbers.push_back(tag.count_);
  }
  return get_vector_hash(numbers);
}

template <class StorerT>
void ReactionManager::SavedReactionTags::store(StorerT &storer) const {
  CHECK(is_inited_);
  BEGIN_STORE_FLAGS();
  END_STORE_FLAGS();
  td::store(tags_, storer);
}

template <class ParserT>
void ReactionManager::SavedReactionTags::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  END_PARSE_FLAGS();
  td::parse(tags_, parser);
  hash_ = calc_hash();
  is_inited_ = true;
}

ReactionManager::ReactionManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

ReactionManager::~ReactionManager() = default;

void ReactionManager::start_up() {
  init();
}

void ReactionManager::tear_down() {
  parent_.reset();
}

void ReactionManager::init() {
  if (G()->close_flag()) {
    return;
  }
  if (is_inited_ || !td_->auth_manager_->is_authorized() || td_->auth_manager_->is_bot()) {
    return;
  }
  is_inited_ = true;

  td_->stickers_manager_->init();

  load_active_reactions();
  load_active_message_effects();
  load_default_paid_reaction_type();

  if (td_->option_manager_->get_option_boolean("default_reaction_needs_sync")) {
    send_set_default_reaction_query();
  }
}

td_api::object_ptr<td_api::emojiReaction> ReactionManager::get_emoji_reaction_object(const string &emoji) const {
  for (auto &reaction : reactions_.reactions_) {
    if (reaction.reaction_type_.get_string() == emoji) {
      return td_api::make_object<td_api::emojiReaction>(
          reaction.reaction_type_.get_string(), reaction.title_, reaction.is_active_,
          td_->stickers_manager_->get_sticker_object(reaction.static_icon_),
          td_->stickers_manager_->get_sticker_object(reaction.appear_animation_),
          td_->stickers_manager_->get_sticker_object(reaction.select_animation_),
          td_->stickers_manager_->get_sticker_object(reaction.activate_animation_),
          td_->stickers_manager_->get_sticker_object(reaction.effect_animation_),
          td_->stickers_manager_->get_sticker_object(reaction.around_animation_),
          td_->stickers_manager_->get_sticker_object(reaction.center_animation_));
    }
  }
  return nullptr;
}

void ReactionManager::get_emoji_reaction(const string &emoji,
                                         Promise<td_api::object_ptr<td_api::emojiReaction>> &&promise) {
  load_reactions();
  if (reactions_.reactions_.empty() && reactions_.are_being_reloaded_) {
    pending_get_emoji_reaction_queries_.emplace_back(emoji, std::move(promise));
    return;
  }
  promise.set_value(get_emoji_reaction_object(emoji));
}

td_api::object_ptr<td_api::availableReactions> ReactionManager::get_sorted_available_reactions(
    ChatReactions available_reactions, ChatReactions active_reactions, int32 row_size, bool is_tag,
    ReactionUnavailabilityReason unavailability_reason) {
  if (is_tag) {
    load_reaction_list(ReactionListType::DefaultTag);
  } else {
    load_reaction_list(ReactionListType::Recent);
  }
  load_reaction_list(ReactionListType::Top);

  if (row_size < 5 || row_size > 25) {
    row_size = 8;
  }

  bool is_premium = td_->option_manager_->get_option_boolean("is_premium");
  bool show_premium = is_premium || is_tag;
  vector<ReactionType> recent_reactions;
  vector<ReactionType> top_reactions;
  if (is_tag) {
    if (is_premium) {
      auto all_tags = get_saved_reaction_tags(SavedMessagesTopicId());
      for (auto &tag : all_tags->tags_) {
        top_reactions.push_back(tag.reaction_type_);
      }
      for (auto &reaction_type : get_reaction_list(ReactionListType::DefaultTag).reaction_types_) {
        if (!td::contains(top_reactions, reaction_type)) {
          top_reactions.push_back(reaction_type);
        }
      }
      for (auto &reaction_type : get_reaction_list(ReactionListType::Top).reaction_types_) {
        if (!td::contains(top_reactions, reaction_type)) {
          top_reactions.push_back(reaction_type);
        }
      }
    } else {
      top_reactions = get_reaction_list(ReactionListType::DefaultTag).reaction_types_;
    }
  } else {
    recent_reactions = get_reaction_list(ReactionListType::Recent).reaction_types_;
    top_reactions = get_reaction_list(ReactionListType::Top).reaction_types_;
  }
  LOG(INFO) << "Have available reactions " << available_reactions << " to be sorted by top reactions " << top_reactions
            << " and recent reactions " << recent_reactions
            << " and paid reaction = " << available_reactions.paid_reactions_available_;
  if (active_reactions.allow_all_custom_ && active_reactions.allow_all_regular_) {
    for (auto &reaction_type : recent_reactions) {
      if (reaction_type.is_custom_reaction()) {
        show_premium = true;
      }
    }
    for (auto &reaction_type : top_reactions) {
      if (reaction_type.is_custom_reaction()) {
        show_premium = true;
      }
    }
  }

  FlatHashSet<ReactionType, ReactionTypeHash> all_available_reaction_types;
  for (const auto &reaction_type : available_reactions.reaction_types_) {
    CHECK(!reaction_type.is_empty());
    all_available_reaction_types.insert(reaction_type);
  }
  if (available_reactions.paid_reactions_available_ ||
      (!available_reactions.reaction_types_.empty() && available_reactions.reaction_types_[0].is_paid_reaction())) {
    all_available_reaction_types.insert(ReactionType::paid());
    top_reactions.insert(top_reactions.begin(), ReactionType::paid());
  }

  vector<td_api::object_ptr<td_api::availableReaction>> top_reaction_objects;
  vector<td_api::object_ptr<td_api::availableReaction>> recent_reaction_objects;
  vector<td_api::object_ptr<td_api::availableReaction>> popular_reaction_objects;
  vector<td_api::object_ptr<td_api::availableReaction>> last_reaction_objects;

  FlatHashSet<ReactionType, ReactionTypeHash> added_custom_reaction_types;
  auto add_reactions = [&](vector<td_api::object_ptr<td_api::availableReaction>> &reaction_objects,
                           const vector<ReactionType> &reaction_types) {
    for (auto &reaction_type : reaction_types) {
      if (all_available_reaction_types.erase(reaction_type) != 0) {
        // add available reaction
        if (reaction_type.is_custom_reaction()) {
          added_custom_reaction_types.insert(reaction_type);
        }
        reaction_objects.push_back(td_api::make_object<td_api::availableReaction>(
            reaction_type.get_reaction_type_object(), is_tag && !is_premium));
      } else if (reaction_type.is_custom_reaction() && available_reactions.allow_all_custom_ &&
                 added_custom_reaction_types.insert(reaction_type).second) {
        // add implicitly available custom reaction
        reaction_objects.push_back(
            td_api::make_object<td_api::availableReaction>(reaction_type.get_reaction_type_object(), !is_premium));
      } else {
        // skip the reaction
      }
    }
  };
  if (show_premium) {
    if (!is_tag && top_reactions.size() > 2 * static_cast<size_t>(row_size)) {
      top_reactions.resize(2 * static_cast<size_t>(row_size));
    }
    add_reactions(top_reaction_objects, top_reactions);
    add_reactions(recent_reaction_objects, recent_reactions);
  } else {
    add_reactions(top_reaction_objects, top_reactions);
  }
  add_reactions(last_reaction_objects, active_reaction_types_);
  add_reactions(last_reaction_objects, available_reactions.reaction_types_);

  if (show_premium) {
    if (recent_reactions.empty()) {
      popular_reaction_objects = std::move(last_reaction_objects);
    } else {
      auto max_objects = 10 * static_cast<size_t>(row_size);
      if (recent_reaction_objects.size() + last_reaction_objects.size() > max_objects) {
        if (last_reaction_objects.size() < max_objects) {
          recent_reaction_objects.resize(max_objects - last_reaction_objects.size());
        } else {
          recent_reaction_objects.clear();
        }
      }
      append(recent_reaction_objects, std::move(last_reaction_objects));
    }
  } else {
    append(top_reaction_objects, std::move(last_reaction_objects));
  }

  CHECK(all_available_reaction_types.empty());

  td_api::object_ptr<td_api::ReactionUnavailabilityReason> reason;
  switch (unavailability_reason) {
    case ReactionUnavailabilityReason::None:
      break;
    case ReactionUnavailabilityReason::AnonymousAdministrator:
      reason = td_api::make_object<td_api::reactionUnavailabilityReasonAnonymousAdministrator>();
      break;
    case ReactionUnavailabilityReason::Guest:
      reason = td_api::make_object<td_api::reactionUnavailabilityReasonGuest>();
      break;
    default:
      UNREACHABLE();
  }

  return td_api::make_object<td_api::availableReactions>(
      std::move(top_reaction_objects), std::move(recent_reaction_objects), std::move(popular_reaction_objects),
      available_reactions.allow_all_custom_, is_tag, std::move(reason));
}

td_api::object_ptr<td_api::availableReactions> ReactionManager::get_available_reactions(int32 row_size) {
  ChatReactions available_reactions;
  available_reactions.reaction_types_ = active_reaction_types_;
  available_reactions.allow_all_custom_ = true;
  return get_sorted_available_reactions(std::move(available_reactions), ChatReactions(true, true), row_size, false,
                                        ReactionUnavailabilityReason::None);
}

void ReactionManager::add_recent_reaction(const ReactionType &reaction_type) {
  load_reaction_list(ReactionListType::Recent);

  auto &recent_reactions = get_reaction_list(ReactionListType::Recent);
  auto &reactions = recent_reactions.reaction_types_;
  if (!reactions.empty() && reactions[0] == reaction_type) {
    return;
  }
  CHECK(!reaction_type.is_paid_reaction());

  add_to_top(reactions, MAX_RECENT_REACTIONS, reaction_type);

  recent_reactions.hash_ = get_reaction_types_hash(reactions);
}

void ReactionManager::clear_recent_reactions(Promise<Unit> &&promise) {
  load_reaction_list(ReactionListType::Recent);

  auto &recent_reactions = get_reaction_list(ReactionListType::Recent);
  if (recent_reactions.reaction_types_.empty()) {
    return promise.set_value(Unit());
  }

  recent_reactions.hash_ = 0;
  recent_reactions.reaction_types_.clear();

  td_->create_handler<ClearRecentReactionsQuery>(std::move(promise))->send();
}

vector<ReactionType> ReactionManager::get_default_tag_reactions() {
  load_reaction_list(ReactionListType::DefaultTag);

  return get_reaction_list(ReactionListType::DefaultTag).reaction_types_;
}

void ReactionManager::reload_reactions() {
  if (G()->close_flag() || reactions_.are_being_reloaded_) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  reactions_.are_being_reloaded_ = true;
  load_reactions();  // must be after are_being_reloaded_ is set to true to avoid recursion
  td_->create_handler<GetAvailableReactionsQuery>()->send(reactions_.hash_);
}

void ReactionManager::reload_reaction_list(ReactionListType reaction_list_type, const char *source) {
  if (G()->close_flag()) {
    return;
  }
  LOG(INFO) << "Reload " << reaction_list_type << " from " << source;
  auto &reaction_list = get_reaction_list(reaction_list_type);
  if (reaction_list.is_being_reloaded_) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  reaction_list.is_being_reloaded_ = true;
  load_reaction_list(reaction_list_type);  // must be after is_being_reloaded_ is set to true to avoid recursion
  td_->create_handler<GetReactionListQuery>()->send(reaction_list_type, reaction_list.hash_);
}

td_api::object_ptr<td_api::updateActiveEmojiReactions> ReactionManager::get_update_active_emoji_reactions_object()
    const {
  return td_api::make_object<td_api::updateActiveEmojiReactions>(
      transform(active_reaction_types_, [](const ReactionType &reaction_type) { return reaction_type.get_string(); }));
}

ReactionManager::ReactionList &ReactionManager::get_reaction_list(ReactionListType reaction_list_type) {
  return reaction_lists_[static_cast<int32>(reaction_list_type)];
}

void ReactionManager::save_active_reactions() {
  LOG(INFO) << "Save " << active_reaction_types_.size() << " active reactions";
  G()->td_db()->get_binlog_pmc()->set("active_reactions", log_event_store(active_reaction_types_).as_slice().str());
}

void ReactionManager::save_reactions() {
  LOG(INFO) << "Save " << reactions_.reactions_.size() << " available reactions";
  are_reactions_loaded_from_database_ = true;
  G()->td_db()->get_binlog_pmc()->set("reactions", log_event_store(reactions_).as_slice().str());
}

void ReactionManager::save_reaction_list(ReactionListType reaction_list_type) {
  auto &reaction_list = get_reaction_list(reaction_list_type);
  LOG(INFO) << "Save " << reaction_list.reaction_types_.size() << ' ' << reaction_list_type;
  reaction_list.is_loaded_from_database_ = true;
  G()->td_db()->get_binlog_pmc()->set(get_reaction_list_type_database_key(reaction_list_type),
                                      log_event_store(reaction_list).as_slice().str());
}

void ReactionManager::load_active_reactions() {
  LOG(INFO) << "Loading active reactions";
  string active_reaction_types = G()->td_db()->get_binlog_pmc()->get("active_reactions");
  if (active_reaction_types.empty()) {
    return reload_reactions();
  }

  auto status = log_event_parse(active_reaction_types_, active_reaction_types);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load active reactions: " << status;
    active_reaction_types_ = {};
    return reload_reactions();
  }

  LOG(INFO) << "Successfully loaded " << active_reaction_types_.size() << " active reactions";

  td_->messages_manager_->set_active_reactions(active_reaction_types_);

  send_closure(G()->td(), &Td::send_update, get_update_active_emoji_reactions_object());
}

void ReactionManager::load_reactions() {
  if (are_reactions_loaded_from_database_) {
    return;
  }
  are_reactions_loaded_from_database_ = true;

  string reactions = G()->td_db()->get_binlog_pmc()->get("reactions");
  if (reactions.empty()) {
    return reload_reactions();
  }

  LOG(INFO) << "Loaded available reactions of size " << reactions.size();
  Reactions new_reactions;
  new_reactions.are_being_reloaded_ = reactions_.are_being_reloaded_;
  auto status = log_event_parse(new_reactions, reactions);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load available reactions: " << status;
    return reload_reactions();
  }
  for (auto &reaction_type : new_reactions.reactions_) {
    if (!reaction_type.is_valid()) {
      LOG(ERROR) << "Loaded invalid reaction";
      return reload_reactions();
    }
  }
  reactions_ = std::move(new_reactions);

  LOG(INFO) << "Successfully loaded " << reactions_.reactions_.size() << " available reactions";

  update_active_reactions();
}

void ReactionManager::load_reaction_list(ReactionListType reaction_list_type) {
  auto &reaction_list = get_reaction_list(reaction_list_type);
  if (reaction_list.is_loaded_from_database_) {
    return;
  }
  reaction_list.is_loaded_from_database_ = true;

  LOG(INFO) << "Loading " << reaction_list_type;
  string reactions_str = G()->td_db()->get_binlog_pmc()->get(get_reaction_list_type_database_key(reaction_list_type));
  if (reactions_str.empty()) {
    return reload_reaction_list(reaction_list_type, "load_reaction_list 1");
  }

  auto status = log_event_parse(reaction_list, reactions_str);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load " << reaction_list_type << ": " << status;
    reaction_list = {};
    return reload_reaction_list(reaction_list_type, "load_reaction_list 2");
  }

  LOG(INFO) << "Successfully loaded " << reaction_list.reaction_types_.size() << ' ' << reaction_list_type;
}

void ReactionManager::update_active_reactions() {
  vector<ReactionType> active_reaction_types;
  for (auto &reaction : reactions_.reactions_) {
    if (reaction.is_active_) {
      active_reaction_types.emplace_back(reaction.reaction_type_);
    }
  }
  if (active_reaction_types == active_reaction_types_) {
    return;
  }
  active_reaction_types_ = active_reaction_types;

  save_active_reactions();

  send_closure(G()->td(), &Td::send_update, get_update_active_emoji_reactions_object());

  td_->messages_manager_->set_active_reactions(std::move(active_reaction_types));
}

void ReactionManager::on_get_available_reactions(
    tl_object_ptr<telegram_api::messages_AvailableReactions> &&available_reactions_ptr) {
  CHECK(reactions_.are_being_reloaded_);
  reactions_.are_being_reloaded_ = false;

  auto get_emoji_reaction_queries = std::move(pending_get_emoji_reaction_queries_);
  pending_get_emoji_reaction_queries_.clear();
  SCOPE_EXIT {
    for (auto &query : get_emoji_reaction_queries) {
      query.second.set_value(get_emoji_reaction_object(query.first));
    }
  };

  if (available_reactions_ptr == nullptr) {
    // failed to get available reactions
    return;
  }

  int32 constructor_id = available_reactions_ptr->get_id();
  if (constructor_id == telegram_api::messages_availableReactionsNotModified::ID) {
    LOG(INFO) << "Available reactions are not modified";
    return;
  }

  CHECK(constructor_id == telegram_api::messages_availableReactions::ID);
  auto available_reactions = move_tl_object_as<telegram_api::messages_availableReactions>(available_reactions_ptr);
  vector<Reaction> new_reactions;
  for (auto &available_reaction : available_reactions->reactions_) {
    Reaction reaction;
    reaction.is_active_ = !available_reaction->inactive_;
    reaction.is_premium_ = available_reaction->premium_;
    reaction.reaction_type_ = ReactionType(std::move(available_reaction->reaction_));
    reaction.title_ = std::move(available_reaction->title_);
    reaction.static_icon_ =
        td_->stickers_manager_
            ->on_get_sticker_document(std::move(available_reaction->static_icon_), StickerFormat::Webp, "static_icon")
            .second;
    reaction.appear_animation_ = td_->stickers_manager_
                                     ->on_get_sticker_document(std::move(available_reaction->appear_animation_),
                                                               StickerFormat::Tgs, "appear_animation")
                                     .second;
    reaction.select_animation_ = td_->stickers_manager_
                                     ->on_get_sticker_document(std::move(available_reaction->select_animation_),
                                                               StickerFormat::Tgs, "select_animation")
                                     .second;
    reaction.activate_animation_ = td_->stickers_manager_
                                       ->on_get_sticker_document(std::move(available_reaction->activate_animation_),
                                                                 StickerFormat::Tgs, "activate_animation")
                                       .second;
    reaction.effect_animation_ = td_->stickers_manager_
                                     ->on_get_sticker_document(std::move(available_reaction->effect_animation_),
                                                               StickerFormat::Tgs, "effect_animation")
                                     .second;
    reaction.around_animation_ = td_->stickers_manager_
                                     ->on_get_sticker_document(std::move(available_reaction->around_animation_),
                                                               StickerFormat::Tgs, "around_animation")
                                     .second;
    reaction.center_animation_ = td_->stickers_manager_
                                     ->on_get_sticker_document(std::move(available_reaction->center_icon_),
                                                               StickerFormat::Tgs, "center_animation")
                                     .second;

    if (!reaction.is_valid()) {
      LOG(ERROR) << "Receive invalid " << reaction.reaction_type_;
      continue;
    }
    if (reaction.is_premium_) {
      LOG(ERROR) << "Receive premium " << reaction.reaction_type_;
      continue;
    }

    new_reactions.push_back(std::move(reaction));
  }
  reactions_.reactions_ = std::move(new_reactions);
  reactions_.hash_ = available_reactions->hash_;

  save_reactions();

  update_active_reactions();
}

void ReactionManager::on_get_reaction_list(ReactionListType reaction_list_type,
                                           tl_object_ptr<telegram_api::messages_Reactions> &&reactions_ptr) {
  auto &reaction_list = get_reaction_list(reaction_list_type);
  CHECK(reaction_list.is_being_reloaded_);
  reaction_list.is_being_reloaded_ = false;

  if (reactions_ptr == nullptr) {
    // failed to get reactions
    return;
  }

  int32 constructor_id = reactions_ptr->get_id();
  if (constructor_id == telegram_api::messages_reactionsNotModified::ID) {
    LOG(INFO) << "List of " << reaction_list_type << " is not modified";
    return;
  }

  CHECK(constructor_id == telegram_api::messages_reactions::ID);
  auto reactions = move_tl_object_as<telegram_api::messages_reactions>(reactions_ptr);
  auto new_reaction_types = ReactionType::get_reaction_types(reactions->reactions_);
  if (new_reaction_types == reaction_list.reaction_types_ && reaction_list.hash_ == reactions->hash_) {
    LOG(INFO) << "List of " << reaction_list_type << " is not modified";
    return;
  }
  reaction_list.reaction_types_ = std::move(new_reaction_types);
  reaction_list.hash_ = reactions->hash_;

  auto expected_hash = get_reaction_types_hash(reaction_list.reaction_types_);
  if (reaction_list.hash_ != expected_hash) {
    LOG(ERROR) << "Receive hash " << reaction_list.hash_ << " instead of " << expected_hash << " for "
               << reaction_list_type << reaction_list.reaction_types_;
  }

  save_reaction_list(reaction_list_type);
}

bool ReactionManager::is_active_reaction(const ReactionType &reaction_type) const {
  return td::contains(active_reaction_types_, reaction_type);
}

void ReactionManager::set_default_reaction(ReactionType reaction_type, Promise<Unit> &&promise) {
  if (reaction_type.is_empty()) {
    return promise.set_error(Status::Error(400, "Default reaction must be non-empty"));
  }
  if (reaction_type.is_paid_reaction()) {
    return promise.set_error(Status::Error(400, "Can't set paid reaction as default"));
  }
  if (!reaction_type.is_custom_reaction() && !is_active_reaction(reaction_type)) {
    return promise.set_error(Status::Error(400, "Can't set inactive reaction as default"));
  }

  if (td_->option_manager_->get_option_string("default_reaction", "-") != reaction_type.get_string()) {
    td_->option_manager_->set_option_string("default_reaction", reaction_type.get_string());
    if (!td_->option_manager_->get_option_boolean("default_reaction_needs_sync")) {
      td_->option_manager_->set_option_boolean("default_reaction_needs_sync", true);
      send_set_default_reaction_query();
    }
  }
  promise.set_value(Unit());
}

void ReactionManager::send_set_default_reaction_query() {
  td_->create_handler<SetDefaultReactionQuery>()->send(
      ReactionType(td_->option_manager_->get_option_string("default_reaction")));
}

void ReactionManager::load_all_saved_reaction_tags_from_database() {
  if (are_all_tags_loaded_from_database_ || all_tags_.is_inited_ || !G()->use_message_database()) {
    return;
  }
  are_all_tags_loaded_from_database_ = true;

  auto value = G()->td_db()->get_sqlite_sync_pmc()->get(get_saved_messages_tags_database_key(SavedMessagesTopicId()));
  if (!value.empty()) {
    if (log_event_parse(all_tags_, value).is_ok()) {
      send_update_saved_messages_tags(SavedMessagesTopicId(), &all_tags_, true);
    } else {
      LOG(ERROR) << "Failed to load all tags from database";
      all_tags_ = {};
    }
  }
  reload_saved_messages_tags(SavedMessagesTopicId(), Auto());
}

void ReactionManager::load_saved_reaction_tags_from_database(SavedMessagesTopicId saved_messages_topic_id,
                                                             SavedReactionTags *tags) {
  if (!G()->use_message_database()) {
    return;
  }

  auto value = G()->td_db()->get_sqlite_sync_pmc()->get(get_saved_messages_tags_database_key(saved_messages_topic_id));
  if (value.empty()) {
    return;
  }
  if (log_event_parse(*tags, value).is_error()) {
    LOG(ERROR) << "Failed to load all tags from database";
    *tags = {};
    return;
  }

  send_update_saved_messages_tags(saved_messages_topic_id, tags, true);
  reload_saved_messages_tags(saved_messages_topic_id, Auto());
}

ReactionManager::SavedReactionTags *ReactionManager::get_saved_reaction_tags(
    SavedMessagesTopicId saved_messages_topic_id) {
  if (saved_messages_topic_id == SavedMessagesTopicId()) {
    load_all_saved_reaction_tags_from_database();
    return &all_tags_;
  }
  auto &tags = topic_tags_[saved_messages_topic_id];
  if (tags == nullptr) {
    tags = make_unique<SavedReactionTags>();
    load_saved_reaction_tags_from_database(saved_messages_topic_id, tags.get());
  }
  return tags.get();
}

void ReactionManager::get_saved_messages_tags(SavedMessagesTopicId saved_messages_topic_id,
                                              Promise<td_api::object_ptr<td_api::savedMessagesTags>> &&promise) {
  if (!saved_messages_topic_id.is_valid() && saved_messages_topic_id != SavedMessagesTopicId()) {
    return promise.set_error(Status::Error(400, "Invalid Saved Messages topic specified"));
  }
  const auto *tags = get_saved_reaction_tags(saved_messages_topic_id);
  if (tags->is_inited_) {
    return promise.set_value(tags->get_saved_messages_tags_object());
  }
  reload_saved_messages_tags(saved_messages_topic_id, std::move(promise));
}

void ReactionManager::reload_saved_messages_tags(SavedMessagesTopicId saved_messages_topic_id,
                                                 Promise<td_api::object_ptr<td_api::savedMessagesTags>> &&promise) {
  auto &promises = saved_messages_topic_id == SavedMessagesTopicId()
                       ? pending_get_all_saved_reaction_tags_queries_
                       : pending_get_topic_saved_reaction_tags_queries_[saved_messages_topic_id];
  promises.push_back(std::move(promise));
  if (promises.size() != 1) {
    return;
  }
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), saved_messages_topic_id](
                                 Result<telegram_api::object_ptr<telegram_api::messages_SavedReactionTags>> r_tags) {
        send_closure(actor_id, &ReactionManager::on_get_saved_messages_tags, saved_messages_topic_id,
                     std::move(r_tags));
      });
  const auto *tags = get_saved_reaction_tags(saved_messages_topic_id);
  td_->create_handler<GetSavedReactionTagsQuery>(std::move(query_promise))->send(saved_messages_topic_id, tags->hash_);
}

void ReactionManager::on_get_saved_messages_tags(
    SavedMessagesTopicId saved_messages_topic_id,
    Result<telegram_api::object_ptr<telegram_api::messages_SavedReactionTags>> &&r_tags) {
  G()->ignore_result_if_closing(r_tags);
  vector<Promise<td_api::object_ptr<td_api::savedMessagesTags>>> promises;
  if (saved_messages_topic_id == SavedMessagesTopicId()) {
    promises = std::move(pending_get_all_saved_reaction_tags_queries_);
    reset_to_empty(pending_get_all_saved_reaction_tags_queries_);
  } else {
    auto it = pending_get_topic_saved_reaction_tags_queries_.find(saved_messages_topic_id);
    CHECK(it != pending_get_topic_saved_reaction_tags_queries_.end());
    promises = std::move(it->second);
    pending_get_topic_saved_reaction_tags_queries_.erase(it);
  }
  CHECK(!promises.empty());

  if (r_tags.is_error()) {
    return fail_promises(promises, r_tags.move_as_error());
  }

  auto tags_ptr = r_tags.move_as_ok();
  bool need_send_update = false;
  auto *reaction_tags = get_saved_reaction_tags(saved_messages_topic_id);
  switch (tags_ptr->get_id()) {
    case telegram_api::messages_savedReactionTagsNotModified::ID:
      if (!reaction_tags->is_inited_) {
        LOG(ERROR) << "Receive messages.savedReactionTagsNotModified for non-inited tags";
      }
      break;
    case telegram_api::messages_savedReactionTags::ID: {
      auto tags = telegram_api::move_object_as<telegram_api::messages_savedReactionTags>(tags_ptr);
      vector<SavedReactionTag> saved_reaction_tags;
      for (auto &tag : tags->tags_) {
        saved_reaction_tags.emplace_back(std::move(tag));
        if (!saved_reaction_tags.back().is_valid()) {
          LOG(ERROR) << "Receive " << saved_reaction_tags.back();
          saved_reaction_tags.pop_back();
        }
      }
      std::sort(saved_reaction_tags.begin(), saved_reaction_tags.end());
      reaction_tags->hash_ = tags->hash_;
      if (saved_reaction_tags != reaction_tags->tags_) {
        reaction_tags->tags_ = std::move(saved_reaction_tags);
        need_send_update = true;
      }
      if (reaction_tags->hash_ != reaction_tags->calc_hash()) {
        LOG(ERROR) << "Receive unexpected Saved Messages tag hash";
      }
      reaction_tags->is_inited_ = true;
      break;
    }
    default:
      UNREACHABLE();
  }

  if (need_send_update) {
    send_update_saved_messages_tags(saved_messages_topic_id, reaction_tags);
  }
  for (auto &promise : promises) {
    if (promise) {
      promise.set_value(reaction_tags->get_saved_messages_tags_object());
    }
  }
}

string ReactionManager::get_saved_messages_tags_database_key(SavedMessagesTopicId saved_messages_topic_id) {
  return PSTRING() << "saved_messages_tags" << saved_messages_topic_id.get_unique_id();
}

td_api::object_ptr<td_api::updateSavedMessagesTags> ReactionManager::get_update_saved_messages_tags_object(
    SavedMessagesTopicId saved_messages_topic_id, const SavedReactionTags *tags) const {
  CHECK(tags != nullptr);
  return td_api::make_object<td_api::updateSavedMessagesTags>(
      td_->saved_messages_manager_->get_saved_messages_topic_id_object(saved_messages_topic_id),
      tags->get_saved_messages_tags_object());
}

void ReactionManager::send_update_saved_messages_tags(SavedMessagesTopicId saved_messages_topic_id,
                                                      const SavedReactionTags *tags, bool from_database) {
  send_closure(G()->td(), &Td::send_update, get_update_saved_messages_tags_object(saved_messages_topic_id, tags));
  if (!from_database && G()->use_message_database()) {
    G()->td_db()->get_sqlite_pmc()->set(get_saved_messages_tags_database_key(saved_messages_topic_id),
                                        log_event_store(*tags).as_slice().str(), Promise<Unit>());
  }
}

void ReactionManager::on_update_saved_reaction_tags(Promise<Unit> &&promise) {
  reload_saved_messages_tags(
      SavedMessagesTopicId(),
      PromiseCreator::lambda(
          [promise = std::move(promise)](Result<td_api::object_ptr<td_api::savedMessagesTags>> result) mutable {
            promise.set_value(Unit());
          }));
}

void ReactionManager::update_saved_messages_tags(SavedMessagesTopicId saved_messages_topic_id,
                                                 const vector<ReactionType> &old_tags,
                                                 const vector<ReactionType> &new_tags) {
  if (old_tags == new_tags) {
    return;
  }
  auto *all_tags = get_saved_reaction_tags(SavedMessagesTopicId());
  if (all_tags->update_saved_messages_tags(old_tags, new_tags)) {
    send_update_saved_messages_tags(SavedMessagesTopicId(), all_tags);
  }
  if (saved_messages_topic_id != SavedMessagesTopicId() && saved_messages_topic_id.get_input_peer(td_) != nullptr) {
    auto *tags = get_saved_reaction_tags(saved_messages_topic_id);
    if (tags->update_saved_messages_tags(old_tags, new_tags)) {
      send_update_saved_messages_tags(saved_messages_topic_id, tags);
    }
  }
}

void ReactionManager::set_saved_messages_tag_title(ReactionType reaction_type, string title, Promise<Unit> &&promise) {
  if (reaction_type.is_empty()) {
    return promise.set_error(Status::Error(400, "Reaction type must be non-empty"));
  }
  if (reaction_type.is_paid_reaction()) {
    return promise.set_error(Status::Error(400, "Invalid reaction specified"));
  }
  title = clean_name(title, MAX_TAG_TITLE_LENGTH);

  auto *all_tags = get_saved_reaction_tags(SavedMessagesTopicId());
  if (all_tags->set_tag_title(reaction_type, title)) {
    send_update_saved_messages_tags(SavedMessagesTopicId(), all_tags);
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> result) mutable {
        if (result.is_ok()) {
          send_closure(actor_id, &ReactionManager::on_update_saved_reaction_tags, std::move(promise));
        } else {
          promise.set_error(result.move_as_error());
        }
      });
  td_->create_handler<UpdateSavedReactionTagQuery>(std::move(query_promise))->send(reaction_type, title);
}

td_api::object_ptr<td_api::messageEffect> ReactionManager::get_message_effect_object(const Effect &effect) const {
  auto type = [&]() -> td_api::object_ptr<td_api::MessageEffectType> {
    if (effect.is_sticker()) {
      return td_api::make_object<td_api::messageEffectTypePremiumSticker>(
          td_->stickers_manager_->get_sticker_object(effect.effect_sticker_id_));
    }
    return td_api::make_object<td_api::messageEffectTypeEmojiReaction>(
        td_->stickers_manager_->get_sticker_object(effect.effect_sticker_id_),
        td_->stickers_manager_->get_sticker_object(effect.effect_animation_id_));
  }();
  return td_api::make_object<td_api::messageEffect>(effect.id_.get(),
                                                    td_->stickers_manager_->get_sticker_object(effect.static_icon_id_),
                                                    effect.emoji_, effect.is_premium_, std::move(type));
}

td_api::object_ptr<td_api::messageEffect> ReactionManager::get_message_effect_object(MessageEffectId effect_id) const {
  for (auto &effect : message_effects_.effects_) {
    if (effect.id_ == effect_id) {
      return get_message_effect_object(effect);
    }
  }
  return nullptr;
}

td_api::object_ptr<td_api::updateAvailableMessageEffects> ReactionManager::get_update_available_message_effects_object()
    const {
  auto get_raw_effect_ids = [](const vector<MessageEffectId> &message_effect_ids) {
    return transform(message_effect_ids, [](MessageEffectId effect_id) { return effect_id.get(); });
  };
  return td_api::make_object<td_api::updateAvailableMessageEffects>(
      get_raw_effect_ids(active_message_effects_.reaction_effects_),
      get_raw_effect_ids(active_message_effects_.sticker_effects_));
}

void ReactionManager::reload_message_effects() {
  if (G()->close_flag() || message_effects_.are_being_reloaded_) {
    return;
  }
  CHECK(!td_->auth_manager_->is_bot());
  message_effects_.are_being_reloaded_ = true;
  load_message_effects();  // must be after are_being_reloaded_ is set to true to avoid recursion
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this)](
          Result<telegram_api::object_ptr<telegram_api::messages_AvailableEffects>> r_effects) mutable {
        send_closure(actor_id, &ReactionManager::on_get_message_effects, std::move(r_effects));
      });
  td_->create_handler<GetMessageAvailableEffectsQuery>(std::move(promise))->send(message_effects_.hash_);
}

void ReactionManager::load_message_effects() {
  if (are_message_effects_loaded_from_database_) {
    return;
  }
  are_message_effects_loaded_from_database_ = true;

  string message_effects = G()->td_db()->get_binlog_pmc()->get("message_effects");
  if (message_effects.empty()) {
    return reload_message_effects();
  }
  LOG(INFO) << "Loaded message effects of size " << message_effects.size();

  Effects new_message_effects;
  new_message_effects.are_being_reloaded_ = message_effects_.are_being_reloaded_;
  auto status = log_event_parse(new_message_effects, message_effects);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load message effects: " << status;
    return reload_message_effects();
  }
  for (auto &effect : new_message_effects.effects_) {
    if (!effect.is_valid()) {
      LOG(ERROR) << "Loaded invalid message effect";
      return reload_message_effects();
    }
  }
  message_effects_ = std::move(new_message_effects);

  LOG(INFO) << "Successfully loaded " << message_effects_.effects_.size() << " message effects";

  update_active_message_effects();
}

void ReactionManager::save_message_effects() {
  LOG(INFO) << "Save " << message_effects_.effects_.size() << " message effects";
  are_message_effects_loaded_from_database_ = true;
  G()->td_db()->get_binlog_pmc()->set("message_effects", log_event_store(message_effects_).as_slice().str());
}

void ReactionManager::on_get_message_effects(
    Result<telegram_api::object_ptr<telegram_api::messages_AvailableEffects>> r_effects) {
  G()->ignore_result_if_closing(r_effects);
  CHECK(message_effects_.are_being_reloaded_);
  message_effects_.are_being_reloaded_ = false;

  auto get_message_effect_queries = std::move(pending_get_message_effect_queries_);
  pending_get_message_effect_queries_.clear();
  SCOPE_EXIT {
    for (auto &query : get_message_effect_queries) {
      query.second.set_value(get_message_effect_object(query.first));
    }
  };

  if (r_effects.is_error()) {
    return;
  }
  auto message_effects = r_effects.move_as_ok();

  switch (message_effects->get_id()) {
    case telegram_api::messages_availableEffectsNotModified::ID:
      break;
    case telegram_api::messages_availableEffects::ID: {
      auto effects = telegram_api::move_object_as<telegram_api::messages_availableEffects>(message_effects);
      FlatHashMap<int64, FileId> stickers;
      for (auto &document : effects->documents_) {
        auto sticker = td_->stickers_manager_->on_get_sticker_document(std::move(document), StickerFormat::Unknown,
                                                                       "on_get_message_effects");
        if (sticker.first != 0 && sticker.second.is_valid()) {
          stickers.emplace(sticker.first, sticker.second);
        } else {
          LOG(ERROR) << "Receive " << sticker.first << ' ' << sticker.second;
        }
      }
      vector<Effect> new_effects;
      bool was_sticker = false;
      bool have_invalid_order = false;
      for (const auto &available_effect : effects->effects_) {
        Effect effect;
        effect.id_ = MessageEffectId(available_effect->id_);
        effect.emoji_ = std::move(available_effect->emoticon_);
        effect.is_premium_ = available_effect->premium_required_;
        if (available_effect->static_icon_id_ != 0) {
          auto it = stickers.find(available_effect->static_icon_id_);
          if (it == stickers.end()) {
            LOG(ERROR) << "Can't find " << available_effect->static_icon_id_;
          } else {
            auto sticker_id = it->second;
            if (td_->stickers_manager_->get_sticker_format(sticker_id) != StickerFormat::Webp) {
              LOG(ERROR) << "Receive static sticker in wrong format";
            } else {
              effect.static_icon_id_ = sticker_id;
            }
          }
        }
        if (available_effect->effect_sticker_id_ != 0) {
          auto it = stickers.find(available_effect->effect_sticker_id_);
          if (it == stickers.end()) {
            LOG(ERROR) << "Can't find " << available_effect->effect_sticker_id_;
          } else {
            auto sticker_id = it->second;
            if (td_->stickers_manager_->get_sticker_format(sticker_id) != StickerFormat::Tgs) {
              LOG(ERROR) << "Receive effect sticker in wrong format";
            } else {
              effect.effect_sticker_id_ = sticker_id;
            }
          }
        }
        if (available_effect->effect_animation_id_ != 0) {
          auto it = stickers.find(available_effect->effect_animation_id_);
          if (it == stickers.end()) {
            LOG(ERROR) << "Can't find " << available_effect->effect_animation_id_;
          } else {
            auto sticker_id = it->second;
            if (td_->stickers_manager_->get_sticker_format(sticker_id) != StickerFormat::Tgs) {
              LOG(ERROR) << "Receive effect animation in wrong format";
            } else {
              effect.effect_animation_id_ = sticker_id;
            }
          }
        }
        if (effect.is_valid()) {
          if (was_sticker && !effect.is_sticker()) {
            have_invalid_order = true;
          }
          new_effects.push_back(std::move(effect));
        } else {
          LOG(ERROR) << "Receive " << to_string(available_effect);
        }
      }
      if (have_invalid_order) {
        LOG(ERROR) << "Have invalid effect order";
        std::stable_sort(new_effects.begin(), new_effects.end(),
                         [](const Effect &lhs, const Effect &rhs) { return !lhs.is_sticker() && rhs.is_sticker(); });
      }

      message_effects_.effects_ = std::move(new_effects);
      message_effects_.hash_ = effects->hash_;

      save_message_effects();

      update_active_message_effects();
      break;
    }
    default:
      UNREACHABLE();
  }
}

void ReactionManager::save_active_message_effects() {
  LOG(INFO) << "Save " << active_message_effects_.reaction_effects_.size() << " + "
            << active_message_effects_.sticker_effects_.size() << " available message effects";
  G()->td_db()->get_binlog_pmc()->set("active_message_effects",
                                      log_event_store(active_message_effects_).as_slice().str());
}

void ReactionManager::load_active_message_effects() {
  LOG(INFO) << "Loading active message effects";
  string active_message_effects = G()->td_db()->get_binlog_pmc()->get("active_message_effects");
  if (active_message_effects.empty()) {
    return reload_message_effects();
  }

  auto status = log_event_parse(active_message_effects_, active_message_effects);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load active message effects: " << status;
    active_message_effects_ = {};
    return reload_message_effects();
  }

  LOG(INFO) << "Successfully loaded " << active_message_effects_.reaction_effects_.size() << " + "
            << active_message_effects_.sticker_effects_.size() << " active message effects";

  send_closure(G()->td(), &Td::send_update, get_update_available_message_effects_object());
}

void ReactionManager::update_active_message_effects() {
  ActiveEffects active_message_effects;
  for (auto &effect : message_effects_.effects_) {
    if (effect.is_sticker()) {
      active_message_effects.sticker_effects_.push_back(effect.id_);
    } else {
      active_message_effects.reaction_effects_.push_back(effect.id_);
    }
  }
  if (active_message_effects.reaction_effects_ == active_message_effects_.reaction_effects_ &&
      active_message_effects.sticker_effects_ == active_message_effects_.sticker_effects_) {
    return;
  }
  active_message_effects_ = std::move(active_message_effects);

  save_active_message_effects();

  send_closure(G()->td(), &Td::send_update, get_update_available_message_effects_object());
}

void ReactionManager::get_message_effect(MessageEffectId effect_id,
                                         Promise<td_api::object_ptr<td_api::messageEffect>> &&promise) {
  load_message_effects();
  if (message_effects_.effects_.empty() && message_effects_.are_being_reloaded_) {
    pending_get_message_effect_queries_.emplace_back(effect_id, std::move(promise));
    return;
  }
  promise.set_value(get_message_effect_object(effect_id));
}

void ReactionManager::send_update_default_paid_reaction_type() const {
  send_closure(G()->td(), &Td::send_update, default_paid_reaction_type_.get_update_default_paid_reaction_type(td_));
}

void ReactionManager::on_update_default_paid_reaction_type(PaidReactionType type) {
  if (type.is_valid() && type != default_paid_reaction_type_) {
    default_paid_reaction_type_ = type;
    save_default_paid_reaction_type();
    send_update_default_paid_reaction_type();
  }
}

void ReactionManager::load_default_paid_reaction_type() {
  string type = G()->td_db()->get_binlog_pmc()->get("default_paid_reaction_type");
  if (!type.empty()) {
    auto status = log_event_parse(default_paid_reaction_type_, type);
    if (status.is_error()) {
      LOG(ERROR) << "Can't load default paid reaction type: " << status;
      default_paid_reaction_type_ = {};
      save_default_paid_reaction_type();
    } else {
      Dependencies dependencies;
      default_paid_reaction_type_.add_dependencies(dependencies);
      if (!default_paid_reaction_type_.is_valid() ||
          !dependencies.resolve_force(td_, "load_default_paid_reaction_type")) {
        default_paid_reaction_type_ = {};
        save_default_paid_reaction_type();
      }
    }
  } else if (td_->option_manager_->have_option("is_paid_reaction_anonymous")) {
    auto is_anonymous = td_->option_manager_->get_option_boolean("is_paid_reaction_anonymous");
    default_paid_reaction_type_ = PaidReactionType::legacy(is_anonymous);
    save_default_paid_reaction_type();
    td_->option_manager_->set_option_empty("is_paid_reaction_anonymous");
  }
  send_update_default_paid_reaction_type();
}

void ReactionManager::save_default_paid_reaction_type() const {
  LOG(INFO) << "Save " << default_paid_reaction_type_;
  G()->td_db()->get_binlog_pmc()->set("default_paid_reaction_type",
                                      log_event_store(default_paid_reaction_type_).as_slice().str());
}

PaidReactionType ReactionManager::get_default_paid_reaction_type() const {
  return default_paid_reaction_type_;
}

void ReactionManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (!active_reaction_types_.empty()) {
    updates.push_back(get_update_active_emoji_reactions_object());
  }
  if (all_tags_.is_inited_) {
    updates.push_back(get_update_saved_messages_tags_object(SavedMessagesTopicId(), &all_tags_));
  }
  for (auto &it : topic_tags_) {
    updates.push_back(get_update_saved_messages_tags_object(it.first, it.second.get()));
  }
  if (!active_message_effects_.is_empty()) {
    updates.push_back(get_update_available_message_effects_object());
  }
  updates.push_back(default_paid_reaction_type_.get_update_default_paid_reaction_type(td_));
}

}  // namespace td
