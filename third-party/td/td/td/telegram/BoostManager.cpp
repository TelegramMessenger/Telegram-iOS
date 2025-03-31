//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BoostManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"

#include <algorithm>

namespace td {

static td_api::object_ptr<td_api::chatBoost> get_chat_boost_object(
    Td *td, const telegram_api::object_ptr<telegram_api::boost> &boost) {
  auto source = [&]() -> td_api::object_ptr<td_api::ChatBoostSource> {
    if (boost->giveaway_) {
      UserId user_id(boost->user_id_);
      if (!user_id.is_valid() || boost->unclaimed_) {
        user_id = UserId();
      }
      auto giveaway_message_id = MessageId(ServerMessageId(boost->giveaway_msg_id_));
      if (!giveaway_message_id.is_valid()) {
        giveaway_message_id = MessageId::min();
      }
      return td_api::make_object<td_api::chatBoostSourceGiveaway>(
          td->user_manager_->get_user_id_object(user_id, "chatBoostSourceGiveaway"), boost->used_gift_slug_,
          StarManager::get_star_count(boost->stars_), giveaway_message_id.get(), boost->unclaimed_);
    }
    if (boost->gift_) {
      UserId user_id(boost->user_id_);
      if (!user_id.is_valid()) {
        return nullptr;
      }
      return td_api::make_object<td_api::chatBoostSourceGiftCode>(
          td->user_manager_->get_user_id_object(user_id, "chatBoostSourceGiftCode"), boost->used_gift_slug_);
    }

    UserId user_id(boost->user_id_);
    if (!user_id.is_valid()) {
      return nullptr;
    }
    return td_api::make_object<td_api::chatBoostSourcePremium>(
        td->user_manager_->get_user_id_object(user_id, "chatBoostSourcePremium"));
  }();
  if (source == nullptr) {
    LOG(ERROR) << "Receive " << to_string(boost);
    return nullptr;
  }
  return td_api::make_object<td_api::chatBoost>(boost->id_, max(boost->multiplier_, 1), std::move(source), boost->date_,
                                                max(boost->expires_, 0));
}

static td_api::object_ptr<td_api::chatBoostSlots> get_chat_boost_slots_object(
    Td *td, telegram_api::object_ptr<telegram_api::premium_myBoosts> &&my_boosts) {
  td->user_manager_->on_get_users(std::move(my_boosts->users_), "GetMyBoostsQuery");
  td->chat_manager_->on_get_chats(std::move(my_boosts->chats_), "GetMyBoostsQuery");
  vector<td_api::object_ptr<td_api::chatBoostSlot>> slots;
  for (auto &my_boost : my_boosts->my_boosts_) {
    auto expiration_date = my_boost->expires_;
    if (expiration_date <= G()->unix_time()) {
      continue;
    }

    auto start_date = max(0, my_boost->date_);
    auto cooldown_until_date = max(0, my_boost->cooldown_until_date_);
    DialogId dialog_id;
    if (my_boost->peer_ != nullptr) {
      dialog_id = DialogId(my_boost->peer_);
      if (!dialog_id.is_valid()) {
        LOG(ERROR) << "Receive " << to_string(my_boost);
        continue;
      }
    }
    if (dialog_id.is_valid()) {
      td->dialog_manager_->force_create_dialog(dialog_id, "GetMyBoostsQuery", true);
    } else {
      start_date = 0;
      cooldown_until_date = 0;
    }
    slots.push_back(td_api::make_object<td_api::chatBoostSlot>(
        my_boost->slot_, td->dialog_manager_->get_chat_id_object(dialog_id, "GetMyBoostsQuery"), start_date,
        expiration_date, cooldown_until_date));
  }
  return td_api::make_object<td_api::chatBoostSlots>(std::move(slots));
}

class GetMyBoostsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatBoostSlots>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetMyBoostsQuery(Promise<td_api::object_ptr<td_api::chatBoostSlots>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::premium_getMyBoosts(), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::premium_getMyBoosts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetMyBoostsQuery: " << to_string(result);
    promise_.set_value(get_chat_boost_slots_object(td_, std::move(result)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetBoostsStatusQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatBoostStatus>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetBoostsStatusQuery(Promise<td_api::object_ptr<td_api::chatBoostStatus>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(
        G()->net_query_creator().create(telegram_api::premium_getBoostsStatus(std::move(input_peer)), {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::premium_getBoostsStatus>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetBoostsStatusQuery: " << to_string(result);
    if (result->level_ < 0 || result->current_level_boosts_ < 0 || result->boosts_ < result->current_level_boosts_ ||
        (result->next_level_boosts_ != 0 && result->boosts_ >= result->next_level_boosts_)) {
      LOG(ERROR) << "Receive invalid " << to_string(result);
      if (result->level_ < 0) {
        result->level_ = 0;
      }
      if (result->current_level_boosts_ < 0) {
        result->current_level_boosts_ = 0;
      }
      if (result->boosts_ < result->current_level_boosts_) {
        result->boosts_ = result->current_level_boosts_;
      }
      if (result->next_level_boosts_ != 0 && result->boosts_ >= result->next_level_boosts_) {
        result->next_level_boosts_ = result->boosts_ + 1;
      }
    }
    int32 premium_member_count = 0;
    double premium_member_percentage = 0.0;
    if (result->premium_audience_ != nullptr) {
      premium_member_count = max(0, static_cast<int32>(result->premium_audience_->part_));
      auto participant_count = max(static_cast<int32>(result->premium_audience_->total_), premium_member_count);
      if (dialog_id_.get_type() == DialogType::Channel) {
        td_->chat_manager_->on_update_channel_participant_count(dialog_id_.get_channel_id(), participant_count);
      }
      if (participant_count > 0) {
        premium_member_percentage = 100.0 * premium_member_count / participant_count;
      }
    }
    auto giveaways = transform(
        std::move(result->prepaid_giveaways_),
        [](telegram_api::object_ptr<telegram_api::PrepaidGiveaway> giveaway_ptr)
            -> td_api::object_ptr<td_api::prepaidGiveaway> {
          switch (giveaway_ptr->get_id()) {
            case telegram_api::prepaidGiveaway::ID: {
              auto giveaway = telegram_api::move_object_as<telegram_api::prepaidGiveaway>(giveaway_ptr);
              return td_api::make_object<td_api::prepaidGiveaway>(
                  giveaway->id_, giveaway->quantity_,
                  td_api::make_object<td_api::giveawayPrizePremium>(giveaway->months_), 0, giveaway->date_);
            }
            case telegram_api::prepaidStarsGiveaway::ID: {
              auto giveaway = telegram_api::move_object_as<telegram_api::prepaidStarsGiveaway>(giveaway_ptr);
              return td_api::make_object<td_api::prepaidGiveaway>(
                  giveaway->id_, giveaway->quantity_,
                  td_api::make_object<td_api::giveawayPrizeStars>(StarManager::get_star_count(giveaway->stars_)),
                  giveaway->boosts_, giveaway->date_);
            }
            default:
              UNREACHABLE();
              return nullptr;
          }
        });
    auto boost_count = max(0, result->boosts_);
    auto gift_code_boost_count = clamp(result->gift_boosts_, 0, boost_count);
    promise_.set_value(td_api::make_object<td_api::chatBoostStatus>(
        result->boost_url_, std::move(result->my_boost_slots_), result->level_, gift_code_boost_count, boost_count,
        result->current_level_boosts_, result->next_level_boosts_, premium_member_count, premium_member_percentage,
        std::move(giveaways)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetBoostsStatusQuery");
    promise_.set_error(std::move(status));
  }
};

class ApplyBoostQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatBoostSlots>> promise_;
  DialogId dialog_id_;

 public:
  explicit ApplyBoostQuery(Promise<td_api::object_ptr<td_api::chatBoostSlots>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, vector<int32> slot_ids) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(
        G()->net_query_creator().create(telegram_api::premium_applyBoost(telegram_api::premium_applyBoost::SLOTS_MASK,
                                                                         std::move(slot_ids), std::move(input_peer)),
                                        {{dialog_id}, {"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::premium_applyBoost>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ApplyBoostQuery: " << to_string(result);
    promise_.set_value(get_chat_boost_slots_object(td_, std::move(result)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ApplyBoostQuery");
    promise_.set_error(std::move(status));
  }
};

class GetBoostsListQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::foundChatBoosts>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetBoostsListQuery(Promise<td_api::object_ptr<td_api::foundChatBoosts>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool only_gift_codes, const string &offset, int32 limit) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    CHECK(input_peer != nullptr);
    int32 flags = 0;
    if (only_gift_codes) {
      flags |= telegram_api::premium_getBoostsList::GIFTS_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::premium_getBoostsList(flags, false /*ignored*/, std::move(input_peer), offset, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::premium_getBoostsList>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetBoostsListQuery: " << to_string(result);
    td_->user_manager_->on_get_users(std::move(result->users_), "GetBoostsListQuery");

    auto total_count = result->count_;
    vector<td_api::object_ptr<td_api::chatBoost>> boosts;
    for (auto &boost : result->boosts_) {
      auto chat_boost_object = get_chat_boost_object(td_, boost);
      if (chat_boost_object == nullptr || chat_boost_object->expiration_date_ <= G()->unix_time()) {
        continue;
      }
      boosts.push_back(std::move(chat_boost_object));
    }
    promise_.set_value(
        td_api::make_object<td_api::foundChatBoosts>(total_count, std::move(boosts), result->next_offset_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetBoostsListQuery");
    promise_.set_error(std::move(status));
  }
};

class GetUserBoostsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::foundChatBoosts>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetUserBoostsQuery(Promise<td_api::object_ptr<td_api::foundChatBoosts>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, UserId user_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    CHECK(input_peer != nullptr);
    auto r_input_user = td_->user_manager_->get_input_user(user_id);
    CHECK(r_input_user.is_ok());
    send_query(G()->net_query_creator().create(
        telegram_api::premium_getUserBoosts(std::move(input_peer), r_input_user.move_as_ok())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::premium_getUserBoosts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetUserBoostsQuery: " << to_string(result);
    td_->user_manager_->on_get_users(std::move(result->users_), "GetUserBoostsQuery");

    auto total_count = result->count_;
    vector<td_api::object_ptr<td_api::chatBoost>> boosts;
    for (auto &boost : result->boosts_) {
      auto chat_boost_object = get_chat_boost_object(td_, boost);
      if (chat_boost_object == nullptr || chat_boost_object->expiration_date_ <= G()->unix_time()) {
        continue;
      }
      boosts.push_back(std::move(chat_boost_object));
    }
    promise_.set_value(
        td_api::make_object<td_api::foundChatBoosts>(total_count, std::move(boosts), result->next_offset_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetUserBoostsQuery");
    promise_.set_error(std::move(status));
  }
};

BoostManager::BoostManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void BoostManager::tear_down() {
  parent_.reset();
}

td_api::object_ptr<td_api::chatBoostLevelFeatures> BoostManager::get_chat_boost_level_features_object(
    bool for_megagroup, int32 level) const {
  int32 actual_level =
      clamp(level, 0, static_cast<int32>(td_->option_manager_->get_option_integer("chat_boost_level_max")));
  auto have_enough_boost_level = [&](Slice name) {
    auto needed_boost_level = narrow_cast<int32>(td_->option_manager_->get_option_integer(
        PSLICE() << (for_megagroup ? "group" : "channel") << '_' << name << "_level_min"));
    return needed_boost_level != 0 && actual_level >= needed_boost_level;
  };
  auto theme_counts = td_->theme_manager_->get_dialog_boost_available_count(actual_level, for_megagroup);
  auto can_set_profile_background_custom_emoji = have_enough_boost_level("profile_bg_icon");
  auto can_set_background_custom_emoji = have_enough_boost_level("bg_icon");
  auto can_set_emoji_status = have_enough_boost_level("emoji_status");
  auto can_set_custom_background = have_enough_boost_level("custom_wallpaper");
  auto can_set_custom_emoji_sticker_set = have_enough_boost_level("emoji_stickers");
  auto can_recognize_speech = have_enough_boost_level("transcribe");
  auto can_restrict_sponsored_messages = have_enough_boost_level("restrict_sponsored");
  return td_api::make_object<td_api::chatBoostLevelFeatures>(
      level, actual_level, for_megagroup ? 0 : actual_level, theme_counts.title_color_count_,
      theme_counts.profile_accent_color_count_, can_set_profile_background_custom_emoji,
      theme_counts.accent_color_count_, can_set_background_custom_emoji, can_set_emoji_status,
      theme_counts.chat_theme_count_, can_set_custom_background, can_set_custom_emoji_sticker_set, can_recognize_speech,
      can_restrict_sponsored_messages);
}

td_api::object_ptr<td_api::chatBoostFeatures> BoostManager::get_chat_boost_features_object(bool for_megagroup) const {
  vector<int32> big_levels;
  auto get_min_boost_level = [&](Slice name) {
    auto min_level = narrow_cast<int32>(td_->option_manager_->get_option_integer(
        PSLICE() << (for_megagroup ? "group" : "channel") << '_' << name << "_level_min", 1000000000));
    if (min_level > 10 && min_level < 1000000) {
      big_levels.push_back(min_level);
    }
    return min_level;
  };
  auto result = td_api::make_object<td_api::chatBoostFeatures>(
      Auto(), get_min_boost_level("profile_bg_icon"), get_min_boost_level("bg_icon"),
      get_min_boost_level("emoji_status"), get_min_boost_level("wallpaper"), get_min_boost_level("custom_wallpaper"),
      get_min_boost_level("emoji_stickers"), get_min_boost_level("transcribe"),
      get_min_boost_level("restrict_sponsored"));
  for (int32 level = 1; level <= 10; level++) {
    result->features_.push_back(get_chat_boost_level_features_object(for_megagroup, level));
  }
  td::unique(big_levels);
  for (auto level : big_levels) {
    result->features_.push_back(get_chat_boost_level_features_object(for_megagroup, level));
  }
  return result;
}

void BoostManager::get_boost_slots(Promise<td_api::object_ptr<td_api::chatBoostSlots>> &&promise) {
  td_->create_handler<GetMyBoostsQuery>(std::move(promise))->send();
}

void BoostManager::get_dialog_boost_status(DialogId dialog_id,
                                           Promise<td_api::object_ptr<td_api::chatBoostStatus>> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                        "get_dialog_boost_status"));
  td_->create_handler<GetBoostsStatusQuery>(std::move(promise))->send(dialog_id);
}

void BoostManager::boost_dialog(DialogId dialog_id, vector<int32> slot_ids,
                                Promise<td_api::object_ptr<td_api::chatBoostSlots>> &&promise) {
  TRY_STATUS_PROMISE(promise,
                     td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read, "boost_dialog"));
  if (slot_ids.empty()) {
    return get_boost_slots(std::move(promise));
  }

  td_->create_handler<ApplyBoostQuery>(std::move(promise))->send(dialog_id, slot_ids);
}

Result<std::pair<string, bool>> BoostManager::get_dialog_boost_link(DialogId dialog_id) {
  TRY_STATUS(td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read, "get_dialog_boost_link"));
  if (dialog_id.get_type() != DialogType::Channel) {
    return Status::Error(400, "Can't boost the chat");
  }

  SliceBuilder sb;
  sb << LinkManager::get_t_me_url() << "boost";

  auto username = td_->chat_manager_->get_channel_first_username(dialog_id.get_channel_id());
  bool is_public = !username.empty();
  if (is_public) {
    sb << '/' << username;
  } else {
    sb << "?c=" << dialog_id.get_channel_id().get();
  }

  return std::make_pair(sb.as_cslice().str(), is_public);
}

void BoostManager::get_dialog_boost_link_info(Slice url, Promise<DialogBoostLinkInfo> &&promise) {
  auto r_dialog_boost_link_info = LinkManager::get_dialog_boost_link_info(url);
  if (r_dialog_boost_link_info.is_error()) {
    return promise.set_error(Status::Error(400, r_dialog_boost_link_info.error().message()));
  }

  auto info = r_dialog_boost_link_info.move_as_ok();
  auto query_promise = PromiseCreator::lambda(
      [info, promise = std::move(promise)](Result<DialogId> &&result) mutable { promise.set_value(std::move(info)); });
  td_->dialog_manager_->resolve_dialog(info.username, info.channel_id, std::move(query_promise));
}

td_api::object_ptr<td_api::chatBoostLinkInfo> BoostManager::get_chat_boost_link_info_object(
    const DialogBoostLinkInfo &info) const {
  CHECK(info.username.empty() == info.channel_id.is_valid());

  bool is_public = !info.username.empty();
  DialogId dialog_id =
      is_public ? td_->dialog_manager_->get_resolved_dialog_by_username(info.username) : DialogId(info.channel_id);
  return td_api::make_object<td_api::chatBoostLinkInfo>(
      is_public, td_->dialog_manager_->get_chat_id_object(dialog_id, "chatBoostLinkInfo"));
}

void BoostManager::get_dialog_boosts(DialogId dialog_id, bool only_gift_codes, const string &offset, int32 limit,
                                     Promise<td_api::object_ptr<td_api::foundChatBoosts>> &&promise) {
  TRY_STATUS_PROMISE(
      promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read, "get_dialog_boosts"));
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }

  td_->create_handler<GetBoostsListQuery>(std::move(promise))->send(dialog_id, only_gift_codes, offset, limit);
}

void BoostManager::get_user_dialog_boosts(DialogId dialog_id, UserId user_id,
                                          Promise<td_api::object_ptr<td_api::foundChatBoosts>> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                        "get_user_dialog_boosts"));
  if (!user_id.is_valid()) {
    return promise.set_error(Status::Error(400, "User not found"));
  }

  td_->create_handler<GetUserBoostsQuery>(std::move(promise))->send(dialog_id, user_id);
}

void BoostManager::on_update_dialog_boost(DialogId dialog_id, telegram_api::object_ptr<telegram_api::boost> &&boost) {
  CHECK(td_->auth_manager_->is_bot());
  if (!dialog_id.is_valid() || !td_->dialog_manager_->have_dialog_info_force(dialog_id, "on_update_dialog_boost")) {
    LOG(ERROR) << "Receive updateBotChatBoost in " << dialog_id;
    return;
  }
  auto chat_boost_object = get_chat_boost_object(td_, boost);
  if (chat_boost_object == nullptr) {
    LOG(ERROR) << "Receive wrong updateBotChatBoost in " << dialog_id << ": " << to_string(boost);
    return;
  }
  td_->dialog_manager_->force_create_dialog(dialog_id, "on_update_dialog_boost", true);
  send_closure(
      G()->td(), &Td::send_update,
      td_api::make_object<td_api::updateChatBoost>(
          td_->dialog_manager_->get_chat_id_object(dialog_id, "updateChatBoost"), std::move(chat_boost_object)));
}

}  // namespace td
