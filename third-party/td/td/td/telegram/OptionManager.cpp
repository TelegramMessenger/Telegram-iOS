//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/OptionManager.h"

#include "td/telegram/AccountManager.h"
#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/CountryInfoManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/GitCommitHash.h"
#include "td/telegram/Global.h"
#include "td/telegram/JsonValue.h"
#include "td/telegram/LanguagePackManager.h"
#include "td/telegram/net/MtprotoHeader.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/OnlineManager.h"
#include "td/telegram/ReactionType.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StorageManager.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/TopDialogManager.h"
#include "td/telegram/UserManager.h"

#include "td/db/KeyValueSyncInterface.h"
#include "td/db/TsSeqKeyValue.h"

#include "td/actor/actor.h"

#include "td/utils/algorithm.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

#include <cmath>
#include <functional>
#include <limits>

namespace td {

OptionManager::OptionManager(Td *td)
    : td_(td)
    , current_scheduler_id_(Scheduler::instance()->sched_id())
    , options_(td::make_unique<TsSeqKeyValue>())
    , option_pmc_(G()->td_db()->get_config_pmc_shared()) {
  send_unix_time_update();

  auto &options = options_->inner();

  option_pmc_->for_each([&](Slice name, Slice value) {
    if (name == "utc_time_offset") {
      return;
    }
    CHECK(!name.empty());
    options.set(name, value);
    if (!is_internal_option(name)) {
      send_closure(G()->td(), &Td::send_update,
                   td_api::make_object<td_api::updateOption>(name.str(), get_option_value_object(value)));
    } else {
      auto update = get_internal_option_update(name);
      if (update != nullptr) {
        send_closure(G()->td(), &Td::send_update, std::move(update));
      }
    }
  });

  auto utc_time_offset = PSTRING() << 'I' << Clocks::tz_offset();
  options.set("utc_time_offset", utc_time_offset);
  send_closure(G()->td(), &Td::send_update,
               td_api::make_object<td_api::updateOption>("utc_time_offset", get_option_value_object(utc_time_offset)));

  bool is_test_dc = G()->is_test_dc();
  auto set_default_integer_option = [&](string name, int64 value) {
    if (options.isset(name)) {
      if (false && options.get(name) != (PSTRING() << 'I' << value)) {
        LOG(ERROR) << "Option " << name << " has default value " << value << " instead of "
                   << options.get(name).substr(1);
      }
      return;
    }
    auto str_value = PSTRING() << 'I' << value;
    options.set(name, str_value);
    option_pmc_->set(name, str_value);

    if (!is_internal_option(name)) {
      send_closure(
          G()->td(), &Td::send_update,
          td_api::make_object<td_api::updateOption>(name, td_api::make_object<td_api::optionValueInteger>(value)));
    }
  };
  set_default_integer_option("telegram_service_notifications_chat_id",
                             DialogId(UserManager::get_service_notifications_user_id()).get());
  set_default_integer_option("replies_bot_chat_id", DialogId(UserManager::get_replies_bot_user_id()).get());
  set_default_integer_option("verification_codes_bot_chat_id",
                             DialogId(UserManager::get_verification_codes_bot_user_id()).get());
  set_default_integer_option("group_anonymous_bot_user_id", UserManager::get_anonymous_bot_user_id().get());
  set_default_integer_option("channel_bot_user_id", UserManager::get_channel_bot_user_id().get());
  set_default_integer_option("anti_spam_bot_user_id", UserManager::get_anti_spam_bot_user_id().get());
  set_default_integer_option("message_caption_length_max", 1024);
  set_default_integer_option("message_reply_quote_length_max", 1024);
  set_default_integer_option("story_caption_length_max", 200);
  set_default_integer_option("bio_length_max", 70);
  set_default_integer_option("suggested_video_note_length", 384);
  set_default_integer_option("suggested_video_note_video_bitrate", 1000);
  set_default_integer_option("suggested_video_note_audio_bitrate", 64);
  set_default_integer_option("notification_sound_duration_max", 5);
  set_default_integer_option("notification_sound_size_max", 307200);
  set_default_integer_option("notification_sound_count_max", is_test_dc ? 5 : 100);
  set_default_integer_option("chat_folder_count_max", is_test_dc ? 3 : 10);
  set_default_integer_option("chat_folder_chosen_chat_count_max", is_test_dc ? 5 : 100);
  set_default_integer_option("aggressive_anti_spam_supergroup_member_count_min", is_test_dc ? 1 : 200);
  set_default_integer_option("pinned_forum_topic_count_max", is_test_dc ? 3 : 5);
  set_default_integer_option("story_stealth_mode_past_period", 300);
  set_default_integer_option("story_stealth_mode_future_period", 1500);
  set_default_integer_option("story_stealth_mode_cooldown_period", 3 * 3600);
  set_default_integer_option("giveaway_additional_chat_count_max", is_test_dc ? 3 : 10);
  set_default_integer_option("giveaway_country_count_max", is_test_dc ? 3 : 10);
  set_default_integer_option("giveaway_boost_count_per_premium", 4);
  set_default_integer_option("giveaway_duration_max", 31 * 86400);
  set_default_integer_option("premium_gift_boost_count", 3);
  set_default_integer_option("chat_boost_level_max", is_test_dc ? 10 : 100);
  set_default_integer_option("chat_available_reaction_count_max", 100);
  set_default_integer_option("channel_bg_icon_level_min", is_test_dc ? 1 : 4);
  set_default_integer_option("channel_custom_wallpaper_level_min", is_test_dc ? 4 : 10);
  set_default_integer_option("channel_emoji_status_level_min", is_test_dc ? 2 : 8);
  set_default_integer_option("channel_profile_bg_icon_level_min", is_test_dc ? 1 : 7);
  set_default_integer_option("channel_restrict_sponsored_level_min", is_test_dc ? 5 : 50);
  set_default_integer_option("channel_wallpaper_level_min", is_test_dc ? 3 : 9);
  set_default_integer_option("pm_read_date_expire_period", 604800);
  set_default_integer_option("group_transcribe_level_min", is_test_dc ? 4 : 6);
  set_default_integer_option("group_emoji_stickers_level_min", is_test_dc ? 1 : 4);
  set_default_integer_option("group_profile_bg_icon_level_min", is_test_dc ? 1 : 5);
  set_default_integer_option("group_emoji_status_level_min", is_test_dc ? 2 : 8);
  set_default_integer_option("group_wallpaper_level_min", is_test_dc ? 3 : 9);
  set_default_integer_option("group_custom_wallpaper_level_min", is_test_dc ? 4 : 10);
  set_default_integer_option("quick_reply_shortcut_count_max", is_test_dc ? 10 : 100);
  set_default_integer_option("quick_reply_shortcut_message_count_max", 20);
  set_default_integer_option("business_start_page_title_length_max", 32);
  set_default_integer_option("business_start_page_message_length_max", 70);
  set_default_integer_option("premium_download_speedup", 10);
  set_default_integer_option("premium_upload_speedup", 10);
  set_default_integer_option("upload_premium_speedup_notify_period", is_test_dc ? 30 : 3600);
  set_default_integer_option("business_chat_link_count_max", is_test_dc ? 5 : 100);
  set_default_integer_option("pinned_story_count_max", 3);
  set_default_integer_option("fact_check_length_max", 1024);
  set_default_integer_option("star_withdrawal_count_min", is_test_dc ? 10 : 1000);
  set_default_integer_option("story_link_area_count_max", 3);
  set_default_integer_option("paid_media_message_star_count_max", 10000);
  set_default_integer_option("bot_media_preview_count_max", 12);
  set_default_integer_option("paid_reaction_star_count_max", 10000);
  set_default_integer_option("subscription_star_count_max", 10000);
  set_default_integer_option("usd_to_thousand_star_rate", 1410);
  set_default_integer_option("thousand_star_to_usd_rate", 1300);
  set_default_integer_option("gift_text_length_max", 128);
  set_default_integer_option("gift_sell_period", is_test_dc ? 300 : 90 * 86400);
  set_default_integer_option("affiliate_program_commission_per_mille_min", 1);
  set_default_integer_option("affiliate_program_commission_per_mille_max", 800);
  set_default_integer_option("bot_verification_custom_description_length_max", 70);
  set_default_integer_option("paid_message_star_count_max", 10000);
  set_default_integer_option("paid_message_earnings_per_mille", 850);
  set_default_integer_option("pinned_gift_count_max", 6);

  if (options.isset("my_phone_number") || !options.isset("my_id")) {
    update_premium_options();
  }

  set_option_empty("archive_and_mute_new_chats_from_unknown_users");
  set_option_empty("business_intro_title_length_max");
  set_option_empty("business_intro_message_length_max");
  set_option_empty("channel_custom_accent_color_boost_level_min");
  set_option_empty("chat_filter_count_max");
  set_option_empty("chat_filter_chosen_chat_count_max");
  set_option_empty("forum_member_count_min");
  set_option_empty("themed_emoji_statuses_sticker_set_id");
  set_option_empty("themed_premium_statuses_sticker_set_id");
  set_option_empty("usd_to_1000_star_rate");
  set_option_empty("1000_star_to_usd_rate");
  set_option_empty("is_location_visible");
}

OptionManager::~OptionManager() = default;

void OptionManager::update_premium_options() {
  bool is_premium = get_option_boolean("is_premium");
  if (is_premium) {
    set_option_integer("saved_animations_limit", get_option_integer("saved_gifs_limit_premium", 400));
    set_option_integer("favorite_stickers_limit", get_option_integer("stickers_faved_limit_premium", 10));
    set_option_integer("chat_folder_count_max", get_option_integer("dialog_filters_limit_premium", 20));
    set_option_integer("chat_folder_chosen_chat_count_max",
                       get_option_integer("dialog_filters_chats_limit_premium", 200));
    set_option_integer("pinned_chat_count_max", get_option_integer("dialogs_pinned_limit_premium", 100));
    set_option_integer("pinned_archived_chat_count_max",
                       get_option_integer("dialogs_folder_pinned_limit_premium", 200));
    set_option_integer("pinned_saved_messages_topic_count_max",
                       get_option_integer("saved_dialogs_pinned_limit_premium", 100));
    set_option_integer("bio_length_max", get_option_integer("about_length_limit_premium", 140));
    set_option_integer("chat_folder_invite_link_count_max", get_option_integer("chatlist_invites_limit_premium", 20));
    set_option_integer("added_shareable_chat_folder_count_max",
                       get_option_integer("chatlists_joined_limit_premium", 20));
    set_option_integer("active_story_count_max", get_option_integer("story_expiring_limit_premium", 100));
    set_option_integer("story_caption_length_max", get_option_integer("story_caption_length_limit_premium", 2048));
    set_option_integer("weekly_sent_story_count_max", get_option_integer("stories_sent_weekly_limit_premium", 700));
    set_option_integer("monthly_sent_story_count_max", get_option_integer("stories_sent_monthly_limit_premium", 3000));
    set_option_integer("story_suggested_reaction_area_count_max",
                       get_option_integer("stories_suggested_reactions_limit_premium", 5));

    set_option_boolean("can_set_new_chat_privacy_settings", true);
    set_option_boolean("can_use_text_entities_in_story_caption", true);
  } else {
    set_option_integer("saved_animations_limit", get_option_integer("saved_gifs_limit_default", 200));
    set_option_integer("favorite_stickers_limit", get_option_integer("stickers_faved_limit_default", 5));
    set_option_integer("chat_folder_count_max", get_option_integer("dialog_filters_limit_default", 10));
    set_option_integer("chat_folder_chosen_chat_count_max",
                       get_option_integer("dialog_filters_chats_limit_default", 100));
    set_option_integer("pinned_chat_count_max", get_option_integer("dialogs_pinned_limit_default", 5));
    set_option_integer("pinned_archived_chat_count_max",
                       get_option_integer("dialogs_folder_pinned_limit_default", 100));
    set_option_integer("pinned_saved_messages_topic_count_max",
                       get_option_integer("saved_dialogs_pinned_limit_default", 5));
    set_option_integer("bio_length_max", get_option_integer("about_length_limit_default", 70));
    set_option_integer("chat_folder_invite_link_count_max", get_option_integer("chatlist_invites_limit_default", 3));
    set_option_integer("added_shareable_chat_folder_count_max",
                       get_option_integer("chatlists_joined_limit_default", 2));
    set_option_integer("active_story_count_max", get_option_integer("story_expiring_limit_default", 3));
    set_option_integer("story_caption_length_max", get_option_integer("story_caption_length_limit_default", 200));
    set_option_integer("weekly_sent_story_count_max", get_option_integer("stories_sent_weekly_limit_default", 7));
    set_option_integer("monthly_sent_story_count_max", get_option_integer("stories_sent_monthly_limit_default", 30));
    set_option_integer("story_suggested_reaction_area_count_max",
                       get_option_integer("stories_suggested_reactions_limit_default", 1));

    set_option_boolean("can_set_new_chat_privacy_settings", !get_option_boolean("need_premium_for_new_chat_privacy"));
    set_option_boolean("can_use_text_entities_in_story_caption",
                       !get_option_boolean("need_premium_for_story_caption_entities"));
  }
}

void OptionManager::on_td_inited() {
  is_td_inited_ = true;

  for (auto &request : pending_get_options_) {
    get_option(request.first, std::move(request.second));
  }
  reset_to_empty(pending_get_options_);
}

void OptionManager::set_option_boolean(Slice name, bool value) {
  set_option(name, value ? Slice("Btrue") : Slice("Bfalse"));
}

void OptionManager::set_option_empty(Slice name) {
  set_option(name, Slice());
}

void OptionManager::set_option_integer(Slice name, int64 value) {
  set_option(name, PSLICE() << 'I' << value);
}

void OptionManager::set_option_string(Slice name, Slice value) {
  set_option(name, PSLICE() << 'S' << value);
}

bool OptionManager::have_option(Slice name) const {
  return options_->isset(name.str());
}

bool OptionManager::get_option_boolean(Slice name, bool default_value) const {
  auto value = get_option(name);
  if (value.empty()) {
    return default_value;
  }
  if (value == "Btrue") {
    return true;
  }
  if (value == "Bfalse") {
    return false;
  }
  LOG(ERROR) << "Found \"" << value << "\" instead of boolean option " << name;
  return default_value;
}

int64 OptionManager::get_option_integer(Slice name, int64 default_value) const {
  auto value = get_option(name);
  if (value.empty()) {
    return default_value;
  }
  if (value[0] != 'I') {
    LOG(ERROR) << "Found \"" << value << "\" instead of integer option " << name;
    return default_value;
  }
  return to_integer<int64>(value.substr(1));
}

string OptionManager::get_option_string(Slice name, string default_value) const {
  auto value = get_option(name);
  if (value.empty()) {
    return default_value;
  }
  if (value[0] != 'S') {
    LOG(ERROR) << "Found \"" << value << "\" instead of string option " << name;
    return default_value;
  }
  return value.substr(1);
}

void OptionManager::set_option(Slice name, Slice value) {
  CHECK(!name.empty());
  CHECK(Scheduler::instance()->sched_id() == current_scheduler_id_);
  if (value.empty()) {
    if (options_->erase(name.str()) == 0) {
      return;
    }
    option_pmc_->erase(name.str());
  } else {
    if (options_->set(name, value) == 0) {
      return;
    }
    option_pmc_->set(name.str(), value.str());
  }

  if (!G()->close_flag() && is_td_inited_) {
    on_option_updated(name);
  }

  if (!is_internal_option(name)) {
    send_closure(G()->td(), &Td::send_update,
                 td_api::make_object<td_api::updateOption>(name.str(), get_option_value_object(get_option(name))));
  } else {
    auto update = get_internal_option_update(name);
    if (update != nullptr) {
      send_closure(G()->td(), &Td::send_update, std::move(update));
    }
  }
}

string OptionManager::get_option(Slice name) const {
  return options_->get(name.str());
}

td_api::object_ptr<td_api::OptionValue> OptionManager::get_unix_time_option_value_object() {
  return td_api::make_object<td_api::optionValueInteger>(G()->unix_time());
}

void OptionManager::send_unix_time_update() {
  last_sent_server_time_difference_ = G()->get_server_time_difference();
  td_->send_update(td_api::make_object<td_api::updateOption>("unix_time", get_unix_time_option_value_object()));
}

void OptionManager::on_update_server_time_difference() {
  // can be called from any thread
  if (std::abs(G()->get_server_time_difference() - last_sent_server_time_difference_) < 0.5) {
    return;
  }

  send_unix_time_update();
}

bool OptionManager::is_internal_option(Slice name) {
  static const FlatHashSet<Slice, SliceHash> internal_options{"about_length_limit_default",
                                                              "about_length_limit_premium",
                                                              "aggressive_anti_spam_supergroup_member_count_min",
                                                              "animated_emoji_zoom",
                                                              "animation_search_emojis",
                                                              "animation_search_provider",
                                                              "authorization_autoconfirm_period",
                                                              "base_language_pack_version",
                                                              "business_features",
                                                              "call_receive_timeout_ms",
                                                              "call_ring_timeout_ms",
                                                              "can_edit_fact_check",
                                                              "caption_length_limit_default",
                                                              "caption_length_limit_premium",
                                                              "channel_bg_icon_level_min",
                                                              "channel_custom_wallpaper_level_min",
                                                              "channel_emoji_status_level_min",
                                                              "channel_profile_bg_icon_level_min",
                                                              "channel_restrict_sponsored_level_min",
                                                              "channel_wallpaper_level_min",
                                                              "channels_limit_default",
                                                              "channels_limit_premium",
                                                              "channels_public_limit_default",
                                                              "channels_public_limit_premium",
                                                              "channels_read_media_period",
                                                              "chat_read_mark_expire_period",
                                                              "chat_read_mark_size_threshold",
                                                              "chatlist_invites_limit_default",
                                                              "chatlist_invites_limit_premium",
                                                              "chatlists_joined_limit_default",
                                                              "chatlists_joined_limit_premium",
                                                              "dc_txt_domain_name",
                                                              "default_reaction",
                                                              "default_reaction_needs_sync",
                                                              "dialog_filters_chats_limit_default",
                                                              "dialog_filters_chats_limit_premium",
                                                              "dialog_filters_limit_default",
                                                              "dialog_filters_limit_premium",
                                                              "dialogs_folder_pinned_limit_default",
                                                              "dialogs_folder_pinned_limit_premium",
                                                              "dialogs_pinned_limit_default",
                                                              "dialogs_pinned_limit_premium",
                                                              "dice_emojis",
                                                              "dice_success_values",
                                                              "dismiss_birthday_contact_today",
                                                              "edit_time_limit",
                                                              "emoji_sounds",
                                                              "fragment_prefixes",
                                                              "group_transcribe_level_min",
                                                              "group_emoji_stickers_level_min",
                                                              "group_profile_bg_icon_level_min",
                                                              "group_emoji_status_level_min",
                                                              "group_wallpaper_level_min",
                                                              "group_custom_wallpaper_level_min",
                                                              "hidden_members_group_size_min",
                                                              "ignored_restriction_reasons",
                                                              "language_pack_version",
                                                              "my_phone_number",
                                                              "need_premium_for_new_chat_privacy",
                                                              "need_premium_for_story_caption_entities",
                                                              "need_synchronize_archive_all_stories",
                                                              "notification_cloud_delay_ms",
                                                              "notification_default_delay_ms",
                                                              "online_cloud_timeout_ms",
                                                              "online_update_period_ms",
                                                              "otherwise_relogin_days",
                                                              "pm_read_date_expire_period",
                                                              "premium_bot_username",
                                                              "premium_features",
                                                              "premium_invoice_slug",
                                                              "premium_manage_subscription_url",
                                                              "rating_e_decay",
                                                              "reactions_uniq_max",
                                                              "reactions_user_max_default",
                                                              "reactions_user_max_premium",
                                                              "recent_stickers_limit",
                                                              "recommended_channels_limit_default",
                                                              "recommended_channels_limit_premium",
                                                              "restriction_add_platforms",
                                                              "revoke_pm_inbox",
                                                              "revoke_time_limit",
                                                              "revoke_pm_time_limit",
                                                              "saved_animations_limit",
                                                              "saved_dialogs_pinned_limit_default",
                                                              "saved_dialogs_pinned_limit_premium",
                                                              "saved_gifs_limit_default",
                                                              "saved_gifs_limit_premium",
                                                              "session_count",
                                                              "since_last_open",
                                                              "starref_start_param_prefixes",
                                                              "stickers_faved_limit_default",
                                                              "stickers_faved_limit_premium",
                                                              "stickers_normal_by_emoji_per_premium_num",
                                                              "stickers_premium_by_emoji_num",
                                                              "stories_changelog_user_id",
                                                              "stories_sent_monthly_limit_default",
                                                              "stories_sent_monthly_limit_premium",
                                                              "stories_sent_weekly_limit_default",
                                                              "stories_sent_weekly_limit_premium",
                                                              "stories_suggested_reactions_limit_default",
                                                              "stories_suggested_reactions_limit_premium",
                                                              "story_caption_length_limit_default",
                                                              "story_caption_length_limit_premium",
                                                              "story_expiring_limit_default",
                                                              "story_expiring_limit_premium",
                                                              "ton_proxy_address",
                                                              "upload_premium_speedup_notify_period",
                                                              "video_ignore_alt_documents",
                                                              "video_note_size_max",
                                                              "weather_bot_username",
                                                              "webfile_dc_id"};
  return internal_options.count(name) > 0;
}

td_api::object_ptr<td_api::Update> OptionManager::get_internal_option_update(Slice name) const {
  if (name == "default_reaction") {
    return ReactionType(get_option_string(name)).get_update_default_reaction_type();
  }
  if (name == "otherwise_relogin_days") {
    auto days = narrow_cast<int32>(get_option_integer(name));
    if (days > 0) {
      vector<SuggestedAction> added_actions{SuggestedAction{SuggestedAction::Type::SetPassword, DialogId(), days}};
      return get_update_suggested_actions_object(added_actions, {}, "get_internal_option_update");
    }
  }
  return nullptr;
}

const vector<Slice> &OptionManager::get_synchronous_options() {
  static const vector<Slice> options{"version", "commit_hash"};
  return options;
}

bool OptionManager::is_synchronous_option(Slice name) {
  return td::contains(get_synchronous_options(), name);
}

void OptionManager::on_option_updated(Slice name) {
  switch (name[0]) {
    case 'a':
      if (name == "animated_emoji_zoom") {
        // nothing to do: animated emoji zoom is updated only at launch
      }
      if (name == "animation_search_emojis") {
        td_->animations_manager_->on_update_animation_search_emojis();
      }
      if (name == "animation_search_provider") {
        td_->animations_manager_->on_update_animation_search_provider();
      }
      if (name == "authorization_autoconfirm_period") {
        td_->account_manager_->update_unconfirmed_authorization_timeout(true);
      }
      break;
    case 'b':
      if (name == "base_language_pack_version") {
        send_closure(td_->language_pack_manager_, &LanguagePackManager::on_language_pack_version_changed, true, -1);
      }
      break;
    case 'c':
      if (name == "connection_parameters") {
        if (G()->mtproto_header().set_parameters(get_option_string(name))) {
          G()->net_query_dispatcher().update_mtproto_header();
        }
      }
      break;
    case 'd':
      if (name == "dice_emojis") {
        send_closure(td_->stickers_manager_actor_, &StickersManager::on_update_dice_emojis);
      }
      if (name == "dice_success_values") {
        send_closure(td_->stickers_manager_actor_, &StickersManager::on_update_dice_success_values);
      }
      if (name == "disable_animated_emoji") {
        td_->stickers_manager_->on_update_disable_animated_emojis();
      }
      if (name == "disable_contact_registered_notifications") {
        send_closure(td_->notification_manager_actor_,
                     &NotificationManager::on_disable_contact_registered_notifications_changed);
      }
      if (name == "disable_top_chats") {
        send_closure(td_->top_dialog_manager_actor_, &TopDialogManager::update_is_enabled, !get_option_boolean(name));
      }
      if (name == "dismiss_birthday_contact_today") {
        send_closure(td_->user_manager_actor_, &UserManager::reload_contact_birthdates, true);
      }
      break;
    case 'e':
      if (name == "emoji_sounds") {
        send_closure(td_->stickers_manager_actor_, &StickersManager::on_update_emoji_sounds);
      }
      break;
    case 'f':
      if (name == "favorite_stickers_limit") {
        td_->stickers_manager_->on_update_favorite_stickers_limit();
      }
      if (name == "fragment_prefixes") {
        send_closure(td_->country_info_manager_actor_, &CountryInfoManager::on_update_fragment_prefixes);
      }
      break;
    case 'i':
      if (name == "ignored_restriction_reasons") {
        send_closure(td_->chat_manager_actor_, &ChatManager::on_ignored_restriction_reasons_changed);
        send_closure(td_->user_manager_actor_, &UserManager::on_ignored_restriction_reasons_changed);
      }
      if (name == "is_emulator") {
        if (G()->mtproto_header().set_is_emulator(get_option_boolean(name))) {
          G()->net_query_dispatcher().update_mtproto_header();
        }
      }
      if (name == "is_premium") {
        update_premium_options();
      }
      break;
    case 'l':
      if (name == "language_pack_id") {
        send_closure(td_->language_pack_manager_, &LanguagePackManager::on_language_code_changed);
        if (G()->mtproto_header().set_language_code(get_option_string(name))) {
          G()->net_query_dispatcher().update_mtproto_header();
        }
        send_closure(td_->attach_menu_manager_actor_, &AttachMenuManager::reload_attach_menu_bots, Promise<Unit>());
      }
      if (name == "language_pack_version") {
        send_closure(td_->language_pack_manager_, &LanguagePackManager::on_language_pack_version_changed, false, -1);
      }
      if (name == "localization_target") {
        send_closure(td_->language_pack_manager_, &LanguagePackManager::on_language_pack_changed);
        if (G()->mtproto_header().set_language_pack(get_option_string(name))) {
          G()->net_query_dispatcher().update_mtproto_header();
        }
      }
      break;
    case 'm':
      if (name == "my_phone_number") {
        send_closure(G()->config_manager(), &ConfigManager::reget_config, Promise<Unit>());
      }
      break;
    case 'n':
      if (name == "need_premium_for_new_chat_privacy") {
        update_premium_options();
      }
      if (name == "need_premium_for_story_caption_entities") {
        update_premium_options();
      }
      if (name == "need_synchronize_archive_all_stories") {
        send_closure(td_->story_manager_actor_, &StoryManager::try_synchronize_archive_all_stories);
      }
      if (name == "notification_cloud_delay_ms") {
        send_closure(td_->notification_manager_actor_, &NotificationManager::on_notification_cloud_delay_changed);
      }
      if (name == "notification_default_delay_ms") {
        send_closure(td_->notification_manager_actor_, &NotificationManager::on_notification_default_delay_changed);
      }
      if (name == "notification_group_count_max") {
        send_closure(td_->notification_manager_actor_, &NotificationManager::on_notification_group_count_max_changed,
                     true);
      }
      if (name == "notification_group_size_max") {
        send_closure(td_->notification_manager_actor_, &NotificationManager::on_notification_group_size_max_changed);
      }
      break;
    case 'o':
      if (name == "online_cloud_timeout_ms") {
        send_closure(td_->notification_manager_actor_, &NotificationManager::on_online_cloud_timeout_changed);
      }
      break;
    case 'r':
      if (name == "rating_e_decay") {
        send_closure(td_->top_dialog_manager_actor_, &TopDialogManager::update_rating_e_decay);
      }
      if (name == "recent_stickers_limit") {
        td_->stickers_manager_->on_update_recent_stickers_limit();
      }
      break;
    case 's':
      if (name == "saved_animations_limit") {
        td_->animations_manager_->on_update_saved_animations_limit();
      }
      if (name == "session_count") {
        G()->net_query_dispatcher().update_session_count();
      }
      break;
    case 'u':
      if (name == "use_pfs") {
        G()->net_query_dispatcher().update_use_pfs();
      }
      if (name == "use_storage_optimizer") {
        send_closure(td_->storage_manager_, &StorageManager::update_use_storage_optimizer);
      }
      if (name == "utc_time_offset") {
        if (G()->mtproto_header().set_tz_offset(static_cast<int32>(get_option_integer(name)))) {
          G()->net_query_dispatcher().update_mtproto_header();
        }
      }
      break;
    default:
      break;
  }
}

void OptionManager::get_option(const string &name, Promise<td_api::object_ptr<td_api::OptionValue>> &&promise) {
  bool is_bot = td_->auth_manager_ != nullptr && td_->auth_manager_->is_authorized() && td_->auth_manager_->is_bot();
  auto wrap_promise = [this, &promise, &name] {
    return PromiseCreator::lambda([this, promise = std::move(promise), name](Unit result) mutable {
      // the option is already updated on success, ignore errors
      promise.set_value(get_option_value_object(get_option(name)));
    });
  };
  switch (name[0]) {
    // all these options should be added to getCurrentState
    case 'c':
      if (!is_bot && name == "can_ignore_sensitive_content_restrictions") {
        return send_closure_later(td_->config_manager_, &ConfigManager::get_content_settings, wrap_promise());
      }
      break;
    case 'd':
      if (!is_bot && name == "disable_contact_registered_notifications") {
        if (is_td_inited_) {
          send_closure_later(td_->notification_manager_actor_,
                             &NotificationManager::get_disable_contact_registered_notifications, wrap_promise());
        } else {
          pending_get_options_.emplace_back(name, std::move(promise));
        }
        return;
      }
      break;
    case 'i':
      if (!is_bot && name == "ignore_sensitive_content_restrictions") {
        return send_closure_later(td_->config_manager_, &ConfigManager::get_content_settings, wrap_promise());
      }
      break;
    case 'o':
      if (name == "online") {
        return promise.set_value(td_api::make_object<td_api::optionValueBoolean>(td_->online_manager_->is_online()));
      }
      break;
    case 'u':
      if (name == "unix_time") {
        return promise.set_value(get_unix_time_option_value_object());
      }
      break;
  }
  wrap_promise().set_value(Unit());
}

td_api::object_ptr<td_api::OptionValue> OptionManager::get_option_synchronously(Slice name) {
  CHECK(!name.empty());
  switch (name[0]) {
    case 'c':
      if (name == "commit_hash") {
        return td_api::make_object<td_api::optionValueString>(get_git_commit_hash());
      }
      break;
    case 'v':
      if (name == "version") {
        return td_api::make_object<td_api::optionValueString>("1.8.46");
      }
      break;
  }
  UNREACHABLE();
}

void OptionManager::set_option(const string &name, td_api::object_ptr<td_api::OptionValue> &&value,
                               Promise<Unit> &&promise) {
  int32 value_constructor_id = value == nullptr ? td_api::optionValueEmpty::ID : value->get_id();

  auto set_integer_option = [&](Slice option_name, int64 min_value = 0,
                                int64 max_value = std::numeric_limits<int32>::max()) {
    if (name != option_name) {
      return false;
    }
    if (value_constructor_id == td_api::optionValueEmpty::ID) {
      set_option_empty(option_name);
    } else {
      if (value_constructor_id != td_api::optionValueInteger::ID) {
        promise.set_error(Status::Error(400, PSLICE() << "Option \"" << name << "\" must have integer value"));
        return false;
      }

      int64 int_value = static_cast<td_api::optionValueInteger *>(value.get())->value_;
      if (int_value < min_value || int_value > max_value) {
        promise.set_error(Status::Error(400, PSLICE() << "Option's \"" << name << "\" value " << int_value
                                                      << " is outside of the valid range [" << min_value << ", "
                                                      << max_value << "]"));
        return false;
      }
      set_option_integer(name, int_value);
    }
    promise.set_value(Unit());
    return true;
  };

  auto set_boolean_option = [&](Slice option_name) {
    if (name != option_name) {
      return false;
    }
    if (value_constructor_id == td_api::optionValueEmpty::ID) {
      set_option_empty(name);
    } else {
      if (value_constructor_id != td_api::optionValueBoolean::ID) {
        promise.set_error(Status::Error(400, PSLICE() << "Option \"" << name << "\" must have boolean value"));
        return false;
      }

      bool bool_value = static_cast<td_api::optionValueBoolean *>(value.get())->value_;
      set_option_boolean(name, bool_value);
    }
    promise.set_value(Unit());
    return true;
  };

  auto set_string_option = [&](Slice option_name, std::function<bool(Slice)> check_value) {
    if (name != option_name) {
      return false;
    }
    if (value_constructor_id == td_api::optionValueEmpty::ID) {
      set_option_empty(name);
    } else {
      if (value_constructor_id != td_api::optionValueString::ID) {
        promise.set_error(Status::Error(400, PSLICE() << "Option \"" << name << "\" must have string value"));
        return false;
      }

      const string &str_value = static_cast<td_api::optionValueString *>(value.get())->value_;
      if (str_value.empty()) {
        set_option_empty(name);
      } else {
        if (check_value(str_value)) {
          set_option_string(name, str_value);
        } else {
          promise.set_error(Status::Error(400, PSLICE() << "Option \"" << name << "\" can't have specified value"));
          return false;
        }
      }
    }
    promise.set_value(Unit());
    return true;
  };

  bool is_bot = td_->auth_manager_ != nullptr && td_->auth_manager_->is_authorized() && td_->auth_manager_->is_bot();
  switch (name[0]) {
    case 'a':
      if (set_boolean_option("always_parse_markdown")) {
        return;
      }
      /*
      if (!is_bot && set_boolean_option("archive_all_stories")) {
        set_option_boolean("need_synchronize_archive_all_stories", true);
        return;
      }
      */
      break;
    case 'c':
      if (!is_bot && set_string_option("connection_parameters", [](Slice value) {
            string value_copy = value.str();
            auto r_json_value = get_json_value(value_copy);
            if (r_json_value.is_error()) {
              return false;
            }
            return r_json_value.ok()->get_id() == td_api::jsonValueObject::ID;
          })) {
        return;
      }
      break;
    case 'd':
      if (!is_bot && set_boolean_option("disable_animated_emoji")) {
        return;
      }
      if (!is_bot && set_boolean_option("disable_contact_registered_notifications")) {
        return;
      }
      if (set_boolean_option("disable_network_statistics")) {
        return;
      }
      if (set_boolean_option("disable_persistent_network_statistics")) {
        return;
      }
      if (!is_bot && set_boolean_option("disable_sent_scheduled_message_notifications")) {
        return;
      }
      if (set_boolean_option("disable_time_adjustment_protection")) {
        return;
      }
      if (!is_bot && set_boolean_option("disable_top_chats")) {
        return;
      }
      if (name == "drop_notification_ids") {
        G()->td_db()->get_binlog_pmc()->erase("notification_id_current");
        G()->td_db()->get_binlog_pmc()->erase("notification_group_id_current");
        return promise.set_value(Unit());
      }
      break;
    case 'i':
      if (set_boolean_option("ignore_background_updates")) {
        return;
      }
      if (set_boolean_option("ignore_default_disable_notification")) {
        return;
      }
      if (set_boolean_option("ignore_file_names")) {
        return;
      }
      if (set_boolean_option("ignore_inline_thumbnails")) {
        return;
      }
      if (set_boolean_option("ignore_platform_restrictions")) {
        return;
      }
      if (set_boolean_option("is_emulator")) {
        return;
      }
      if (!is_bot && name == "ignore_sensitive_content_restrictions") {
        if (!get_option_boolean("can_ignore_sensitive_content_restrictions")) {
          return promise.set_error(
              Status::Error(400, "Option \"ignore_sensitive_content_restrictions\" can't be changed by the user"));
        }

        if (value_constructor_id != td_api::optionValueBoolean::ID &&
            value_constructor_id != td_api::optionValueEmpty::ID) {
          return promise.set_error(
              Status::Error(400, "Option \"ignore_sensitive_content_restrictions\" must have boolean value"));
        }

        auto ignore_sensitive_content_restrictions = value_constructor_id == td_api::optionValueBoolean::ID &&
                                                     static_cast<td_api::optionValueBoolean *>(value.get())->value_;
        send_closure_later(td_->config_manager_, &ConfigManager::set_content_settings,
                           ignore_sensitive_content_restrictions, std::move(promise));
        return;
      }
      break;
    case 'l':
      if (!is_bot && set_string_option("language_pack_database_path", [](Slice value) { return true; })) {
        return;
      }
      if (!is_bot && set_string_option("language_pack_id", LanguagePackManager::check_language_code_name)) {
        return;
      }
      if (!is_bot && set_string_option("localization_target", LanguagePackManager::check_language_pack_name)) {
        return;
      }
      break;
    case 'm':
      if (set_integer_option("message_unload_delay", 60, 86400)) {
        return;
      }
      break;
    case 'n':
      if (!is_bot &&
          set_integer_option("notification_group_count_max", NotificationManager::MIN_NOTIFICATION_GROUP_COUNT_MAX,
                             NotificationManager::MAX_NOTIFICATION_GROUP_COUNT_MAX)) {
        return;
      }
      if (!is_bot &&
          set_integer_option("notification_group_size_max", NotificationManager::MIN_NOTIFICATION_GROUP_SIZE_MAX,
                             NotificationManager::MAX_NOTIFICATION_GROUP_SIZE_MAX)) {
        return;
      }
      break;
    case 'o':
      if (name == "online") {
        if (value_constructor_id != td_api::optionValueBoolean::ID &&
            value_constructor_id != td_api::optionValueEmpty::ID) {
          return promise.set_error(Status::Error(400, "Option \"online\" must have boolean value"));
        }
        bool is_online = value_constructor_id == td_api::optionValueEmpty::ID ||
                         static_cast<const td_api::optionValueBoolean *>(value.get())->value_;
        td_->online_manager_->set_is_online(is_online);
        if (!is_bot) {
          send_closure(td_->state_manager_, &StateManager::on_online, is_online);
        }
        return promise.set_value(Unit());
      }
      break;
    case 'p':
      if (set_boolean_option("prefer_ipv6")) {
        send_closure(td_->state_manager_, &StateManager::on_network_updated);
        return;
      }
      if (set_boolean_option("process_pinned_messages_as_mentions")) {
        return;
      }
      break;
    case 'r':
      // temporary option
      if (set_boolean_option("reuse_uploaded_photos_by_hash")) {
        return;
      }
      break;
    case 's':
      if (set_integer_option("storage_max_files_size")) {
        return;
      }
      if (set_integer_option("storage_max_time_from_last_access")) {
        return;
      }
      if (set_integer_option("storage_max_file_count")) {
        return;
      }
      if (set_integer_option("storage_immunity_delay")) {
        return;
      }
      if (set_boolean_option("store_all_files_in_files_directory")) {
        return;
      }
      break;
    case 't':
      if (set_boolean_option("test_flood_wait")) {
        return;
      }
      break;
    case 'u':
      if (set_boolean_option("use_pfs")) {
        return;
      }
      if (set_boolean_option("use_quick_ack")) {
        return;
      }
      if (set_boolean_option("use_storage_optimizer")) {
        return;
      }
      if (set_integer_option("utc_time_offset", -12 * 60 * 60, 14 * 60 * 60)) {
        return;
      }
      break;
    case 'X':
    case 'x': {
      if (name.size() > 255) {
        return promise.set_error(Status::Error(400, "Option name is too long"));
      }
      switch (value_constructor_id) {
        case td_api::optionValueBoolean::ID:
          set_option_boolean(name, static_cast<const td_api::optionValueBoolean *>(value.get())->value_);
          break;
        case td_api::optionValueEmpty::ID:
          set_option_empty(name);
          break;
        case td_api::optionValueInteger::ID:
          set_option_integer(name, static_cast<const td_api::optionValueInteger *>(value.get())->value_);
          break;
        case td_api::optionValueString::ID:
          set_option_string(name, static_cast<const td_api::optionValueString *>(value.get())->value_);
          break;
        default:
          UNREACHABLE();
      }
      return promise.set_value(Unit());
    }
  }

  if (promise) {
    promise.set_error(Status::Error(400, "Option can't be set"));
  }
}

td_api::object_ptr<td_api::OptionValue> OptionManager::get_option_value_object(Slice value) {
  if (value.empty()) {
    return td_api::make_object<td_api::optionValueEmpty>();
  }

  switch (value[0]) {
    case 'B':
      if (value == "Btrue") {
        return td_api::make_object<td_api::optionValueBoolean>(true);
      }
      if (value == "Bfalse") {
        return td_api::make_object<td_api::optionValueBoolean>(false);
      }
      break;
    case 'I':
      return td_api::make_object<td_api::optionValueInteger>(to_integer<int64>(value.substr(1)));
    case 'S':
      return td_api::make_object<td_api::optionValueString>(value.substr(1).str());
  }

  return td_api::make_object<td_api::optionValueString>(value.str());
}

void OptionManager::get_common_state(vector<td_api::object_ptr<td_api::Update>> &updates) {
  for (auto option_name : get_synchronous_options()) {
    updates.push_back(
        td_api::make_object<td_api::updateOption>(option_name.str(), get_option_synchronously(option_name)));
  }
}

void OptionManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  get_common_state(updates);

  updates.push_back(td_api::make_object<td_api::updateOption>(
      "online", td_api::make_object<td_api::optionValueBoolean>(td_->online_manager_->is_online())));

  updates.push_back(td_api::make_object<td_api::updateOption>("unix_time", get_unix_time_option_value_object()));

  for (const auto &option : options_->get_all()) {
    if (!is_internal_option(option.first)) {
      updates.push_back(
          td_api::make_object<td_api::updateOption>(option.first, get_option_value_object(option.second)));
    } else {
      auto update = get_internal_option_update(option.first);
      if (update != nullptr) {
        updates.push_back(std::move(update));
      }
    }
  }
}

}  // namespace td
