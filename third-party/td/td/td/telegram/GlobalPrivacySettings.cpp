//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/GlobalPrivacySettings.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/SuggestedActionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Status.h"

namespace td {

class GetGlobalPrivacySettingsQuery final : public Td::ResultHandler {
  Promise<GlobalPrivacySettings> promise_;

 public:
  explicit GetGlobalPrivacySettingsQuery(Promise<GlobalPrivacySettings> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getGlobalPrivacySettings(), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getGlobalPrivacySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(INFO) << "Receive result for GetGlobalPrivacySettingsQuery: " << to_string(result_ptr.ok());
    promise_.set_value(GlobalPrivacySettings(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetGlobalPrivacySettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetGlobalPrivacySettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(GlobalPrivacySettings settings) {
    send_query(G()->net_query_creator().create(
        telegram_api::account_setGlobalPrivacySettings(settings.get_input_global_privacy_settings()), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_setGlobalPrivacySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

GlobalPrivacySettings::GlobalPrivacySettings(telegram_api::object_ptr<telegram_api::globalPrivacySettings> &&settings)
    : archive_and_mute_new_noncontact_peers_(settings->archive_and_mute_new_noncontact_peers_)
    , keep_archived_unmuted_(settings->keep_archived_unmuted_)
    , keep_archived_folders_(settings->keep_archived_folders_)
    , hide_read_marks_(settings->hide_read_marks_)
    , new_noncontact_peers_require_premium_(settings->new_noncontact_peers_require_premium_)
    , noncontact_peers_paid_star_count_(StarManager::get_star_count(settings->noncontact_peers_paid_stars_))
    , gift_settings_(settings->display_gifts_button_, std::move(settings->disallowed_gifts_)) {
}

GlobalPrivacySettings::GlobalPrivacySettings(td_api::object_ptr<td_api::archiveChatListSettings> &&settings)
    : set_type_(SetType::Archive) {
  if (settings != nullptr) {
    archive_and_mute_new_noncontact_peers_ = settings->archive_and_mute_new_chats_from_unknown_users_;
    keep_archived_unmuted_ = settings->keep_unmuted_chats_archived_;
    keep_archived_folders_ = settings->keep_chats_from_folders_archived_;
  }
}

GlobalPrivacySettings::GlobalPrivacySettings(td_api::object_ptr<td_api::readDatePrivacySettings> &&settings)
    : set_type_(SetType::ReadDate) {
  hide_read_marks_ = settings == nullptr || !settings->show_read_date_;
}

GlobalPrivacySettings::GlobalPrivacySettings(td_api::object_ptr<td_api::newChatPrivacySettings> &&settings)
    : set_type_(SetType::NewChat) {
  new_noncontact_peers_require_premium_ = settings == nullptr || !settings->allow_new_chats_from_unknown_users_;
  noncontact_peers_paid_star_count_ = settings == nullptr ? 0
                                                          : clamp(settings->incoming_paid_message_star_count_,
                                                                  static_cast<int64>(0), static_cast<int64>(1000000));
}

GlobalPrivacySettings::GlobalPrivacySettings(td_api::object_ptr<td_api::giftSettings> &&settings)
    : set_type_(SetType::Gift) {
  gift_settings_ = StarGiftSettings(settings);
}

void GlobalPrivacySettings::apply_changes(const GlobalPrivacySettings &set_settings) {
  CHECK(set_type_ == SetType::None);
  switch (set_settings.set_type_) {
    case SetType::Archive:
      archive_and_mute_new_noncontact_peers_ = set_settings.archive_and_mute_new_noncontact_peers_;
      keep_archived_unmuted_ = set_settings.keep_archived_unmuted_;
      keep_archived_folders_ = set_settings.keep_archived_folders_;
      break;
    case SetType::ReadDate:
      hide_read_marks_ = set_settings.hide_read_marks_;
      break;
    case SetType::NewChat:
      new_noncontact_peers_require_premium_ = set_settings.new_noncontact_peers_require_premium_;
      noncontact_peers_paid_star_count_ = set_settings.noncontact_peers_paid_star_count_;
      break;
    case SetType::Gift:
      gift_settings_ = set_settings.gift_settings_;
      break;
    default:
      UNREACHABLE();
      break;
  }
}

telegram_api::object_ptr<telegram_api::globalPrivacySettings> GlobalPrivacySettings::get_input_global_privacy_settings()
    const {
  CHECK(set_type_ == SetType::None);
  int32 flags = 0;
  if (noncontact_peers_paid_star_count_ > 0) {
    flags |= telegram_api::globalPrivacySettings::NONCONTACT_PEERS_PAID_STARS_MASK;
  }
  auto gifts_settings = gift_settings_.get_disallowed_gifts().get_input_disallowed_gifts_settings();
  if (gifts_settings != nullptr) {
    flags |= telegram_api::globalPrivacySettings::DISALLOWED_GIFTS_MASK;
  }
  return telegram_api::make_object<telegram_api::globalPrivacySettings>(
      flags, archive_and_mute_new_noncontact_peers_, keep_archived_unmuted_, keep_archived_folders_, hide_read_marks_,
      new_noncontact_peers_require_premium_, gift_settings_.get_display_gifts_button(),
      noncontact_peers_paid_star_count_, std::move(gifts_settings));
}

td_api::object_ptr<td_api::archiveChatListSettings> GlobalPrivacySettings::get_archive_chat_list_settings_object()
    const {
  CHECK(set_type_ == SetType::None);
  return td_api::make_object<td_api::archiveChatListSettings>(archive_and_mute_new_noncontact_peers_,
                                                              keep_archived_unmuted_, keep_archived_folders_);
}

td_api::object_ptr<td_api::readDatePrivacySettings> GlobalPrivacySettings::get_read_date_privacy_settings_object()
    const {
  CHECK(set_type_ == SetType::None);
  return td_api::make_object<td_api::readDatePrivacySettings>(!hide_read_marks_);
}

td_api::object_ptr<td_api::newChatPrivacySettings> GlobalPrivacySettings::get_new_chat_privacy_settings_object() const {
  CHECK(set_type_ == SetType::None);
  return td_api::make_object<td_api::newChatPrivacySettings>(!new_noncontact_peers_require_premium_,
                                                             noncontact_peers_paid_star_count_);
}

void GlobalPrivacySettings::get_global_privacy_settings(Td *td, Promise<GlobalPrivacySettings> &&promise) {
  td->create_handler<GetGlobalPrivacySettingsQuery>(std::move(promise))->send();
}

void GlobalPrivacySettings::set_global_privacy_settings(Td *td, GlobalPrivacySettings settings,
                                                        Promise<Unit> &&promise) {
  CHECK(settings.set_type_ != SetType::None);
  if (settings.archive_and_mute_new_noncontact_peers_) {
    send_closure(td->suggested_action_manager_actor_, &SuggestedActionManager::hide_suggested_action,
                 SuggestedAction{SuggestedAction::Type::EnableArchiveAndMuteNewChats});
  }

  get_global_privacy_settings(
      td, PromiseCreator::lambda([td, set_settings = std::move(settings),
                                  promise = std::move(promise)](Result<GlobalPrivacySettings> result) mutable {
        G()->ignore_result_if_closing(result);
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        auto settings = result.move_as_ok();
        settings.apply_changes(set_settings);
        td->create_handler<SetGlobalPrivacySettingsQuery>(std::move(promise))->send(std::move(settings));
      }));
}

}  // namespace td
