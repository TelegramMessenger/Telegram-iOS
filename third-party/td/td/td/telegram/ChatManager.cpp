//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ChatManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/BotVerification.h"
#include "td/telegram/BotVerification.hpp"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogAdministrator.h"
#include "td/telegram/DialogInviteLink.hpp"
#include "td/telegram/DialogInviteLinkManager.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/EmojiStatus.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/Global.h"
#include "td/telegram/GroupCallManager.h"
#include "td/telegram/InputGroupCallId.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/MessageTtl.h"
#include "td/telegram/MinChannel.h"
#include "td/telegram/misc.h"
#include "td/telegram/MissingInvitee.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/PeerColor.h"
#include "td/telegram/Photo.h"
#include "td/telegram/Photo.hpp"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/SuggestedActionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/VerificationStatus.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"
#include "td/db/SqliteKeyValue.h"
#include "td/db/SqliteKeyValueAsync.h"

#include "td/actor/MultiPromise.h"
#include "td/actor/SleepActor.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/utf8.h"

#include <limits>
#include <utility>

namespace td {

class CreateChatQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::createdBasicGroupChat>> promise_;

 public:
  explicit CreateChatQuery(Promise<td_api::object_ptr<td_api::createdBasicGroupChat>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(vector<tl_object_ptr<telegram_api::InputUser>> &&input_users, const string &title, MessageTtl message_ttl) {
    int32 flags = telegram_api::messages_createChat::TTL_PERIOD_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_createChat(flags, std::move(input_users), title, message_ttl.get_input_ttl_period())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_createChat>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CreateChatQuery: " << to_string(ptr);
    td_->messages_manager_->on_create_new_dialog(
        std::move(ptr->updates_), MissingInvitees(std::move(ptr->missing_invitees_)), std::move(promise_), Auto());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CreateChannelQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chat>> promise_;

 public:
  explicit CreateChannelQuery(Promise<td_api::object_ptr<td_api::chat>> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &title, bool is_forum, bool is_megagroup, const string &about, const DialogLocation &location,
            bool for_import, MessageTtl message_ttl) {
    int32 flags = telegram_api::channels_createChannel::TTL_PERIOD_MASK;
    if (is_forum) {
      flags |= telegram_api::channels_createChannel::FORUM_MASK;
    } else if (is_megagroup) {
      flags |= telegram_api::channels_createChannel::MEGAGROUP_MASK;
    } else {
      flags |= telegram_api::channels_createChannel::BROADCAST_MASK;
    }
    if (!location.empty()) {
      flags |= telegram_api::channels_createChannel::GEO_POINT_MASK;
    }
    if (for_import) {
      flags |= telegram_api::channels_createChannel::FOR_IMPORT_MASK;
    }

    send_query(G()->net_query_creator().create(telegram_api::channels_createChannel(
        flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, title, about,
        location.get_input_geo_point(), location.get_address(), message_ttl.get_input_ttl_period())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_createChannel>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->messages_manager_->on_create_new_dialog(result_ptr.move_as_ok(), MissingInvitees(), Auto(),
                                                 std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateChannelUsernameQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  string username_;

 public:
  explicit UpdateChannelUsernameQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, const string &username) {
    channel_id_ = channel_id;
    username_ = username;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_updateUsername(std::move(input_channel), username), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_updateUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for UpdateChannelUsernameQuery: " << result;
    if (!result) {
      return on_error(Status::Error(500, "Supergroup username is not updated"));
    }

    td_->chat_manager_->on_update_channel_editable_username(channel_id_, std::move(username_));
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED" || status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_update_channel_editable_username(channel_id_, std::move(username_));
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "UpdateChannelUsernameQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleChannelUsernameQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  string username_;
  bool is_active_;

 public:
  explicit ToggleChannelUsernameQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, string &&username, bool is_active) {
    channel_id_ = channel_id;
    username_ = std::move(username);
    is_active_ = is_active;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleUsername(std::move(input_channel), username_, is_active_), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for ToggleChannelUsernameQuery: " << result;
    td_->chat_manager_->on_update_channel_username_is_active(channel_id_, std::move(username_), is_active_,
                                                             std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED" || status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_update_channel_username_is_active(channel_id_, std::move(username_), is_active_,
                                                               std::move(promise_));
      return;
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleChannelUsernameQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class DeactivateAllChannelUsernamesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit DeactivateAllChannelUsernamesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::channels_deactivateAllUsernames(std::move(input_channel)),
                                               {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_deactivateAllUsernames>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for DeactivateAllChannelUsernamesQuery: " << result;
    td_->chat_manager_->on_deactivate_channel_usernames(channel_id_, std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED" || status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_deactivate_channel_usernames(channel_id_, std::move(promise_));
      return;
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "DeactivateAllChannelUsernamesQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ReorderChannelUsernamesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  vector<string> usernames_;

 public:
  explicit ReorderChannelUsernamesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, vector<string> &&usernames) {
    channel_id_ = channel_id;
    usernames_ = usernames;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_reorderUsernames(std::move(input_channel), std::move(usernames)), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_reorderUsernames>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for ReorderChannelUsernamesQuery: " << result;
    if (!result) {
      return on_error(Status::Error(500, "Supergroup usernames weren't updated"));
    }

    td_->chat_manager_->on_update_channel_active_usernames_order(channel_id_, std::move(usernames_),
                                                                 std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USERNAME_NOT_MODIFIED" || status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_update_channel_active_usernames_order(channel_id_, std::move(usernames_),
                                                                   std::move(promise_));
      return;
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ReorderChannelUsernamesQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class UpdateChannelColorQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit UpdateChannelColorQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool for_profile, AccentColorId accent_color_id,
            CustomEmojiId background_custom_emoji_id) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    int32 flags = 0;
    if (for_profile) {
      flags |= telegram_api::channels_updateColor::FOR_PROFILE_MASK;
    }
    if (accent_color_id.is_valid()) {
      flags |= telegram_api::channels_updateColor::COLOR_MASK;
    }
    if (background_custom_emoji_id.is_valid()) {
      flags |= telegram_api::channels_updateColor::BACKGROUND_EMOJI_ID_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::channels_updateColor(flags, false /*ignored*/, std::move(input_channel), accent_color_id.get(),
                                           background_custom_emoji_id.get()),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_updateColor>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for UpdateChannelColorQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "UpdateChannelColorQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class UpdateChannelEmojiStatusQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit UpdateChannelEmojiStatusQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, const unique_ptr<EmojiStatus> &emoji_status) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_updateEmojiStatus(std::move(input_channel),
                                                 EmojiStatus::get_input_emoji_status(emoji_status)),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_updateEmojiStatus>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for UpdateChannelEmojiStatusQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "UpdateChannelEmojiStatusQuery");
      get_recent_emoji_statuses(td_, Auto());
    }
    promise_.set_error(std::move(status));
  }
};

class SetChannelStickerSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  StickerSetId sticker_set_id_;

 public:
  explicit SetChannelStickerSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, StickerSetId sticker_set_id,
            telegram_api::object_ptr<telegram_api::InputStickerSet> &&input_sticker_set) {
    channel_id_ = channel_id;
    sticker_set_id_ = sticker_set_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_setStickers(std::move(input_channel), std::move(input_sticker_set)), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_setStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for SetChannelStickerSetQuery: " << result;
    if (!result) {
      return on_error(Status::Error(500, "Supergroup sticker set not updated"));
    }

    td_->chat_manager_->on_update_channel_sticker_set(channel_id_, sticker_set_id_);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_update_channel_sticker_set(channel_id_, sticker_set_id_);
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "SetChannelStickerSetQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class SetChannelEmojiStickerSetQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  StickerSetId sticker_set_id_;

 public:
  explicit SetChannelEmojiStickerSetQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, StickerSetId sticker_set_id,
            telegram_api::object_ptr<telegram_api::InputStickerSet> &&input_sticker_set) {
    channel_id_ = channel_id;
    sticker_set_id_ = sticker_set_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_setEmojiStickers(std::move(input_channel), std::move(input_sticker_set)),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_setEmojiStickers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for SetChannelEmojiStickerSetQuery: " << result;
    if (!result) {
      return on_error(Status::Error(500, "Supergroup custom emoji sticker set not updated"));
    }

    td_->chat_manager_->on_update_channel_emoji_sticker_set(channel_id_, sticker_set_id_);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_update_channel_emoji_sticker_set(channel_id_, sticker_set_id_);
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "SetChannelEmojiStickerSetQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class SetChannelBoostsToUnblockRestrictionsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  int32 unrestrict_boost_count_;

 public:
  explicit SetChannelBoostsToUnblockRestrictionsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, int32 unrestrict_boost_count) {
    channel_id_ = channel_id;
    unrestrict_boost_count_ = unrestrict_boost_count;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_setBoostsToUnblockRestrictions(std::move(input_channel), unrestrict_boost_count),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_setBoostsToUnblockRestrictions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for SetChannelBoostsToUnblockRestrictionsQuery: " << to_string(ptr);
    td_->chat_manager_->on_update_channel_unrestrict_boost_count(channel_id_, unrestrict_boost_count_);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_update_channel_unrestrict_boost_count(channel_id_, unrestrict_boost_count_);
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "SetChannelBoostsToUnblockRestrictionsQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleChannelSignaturesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit ToggleChannelSignaturesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool sign_messages, bool show_message_sender) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    int32 flags = 0;
    if (sign_messages) {
      flags |= telegram_api::channels_toggleSignatures::SIGNATURES_ENABLED_MASK;
    }
    if (show_message_sender) {
      flags |= telegram_api::channels_toggleSignatures::PROFILES_ENABLED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleSignatures(flags, false /*ignored*/, false /*ignored*/, std::move(input_channel)),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleSignatures>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleChannelSignaturesQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleChannelSignaturesQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleChannelJoinToSendQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit ToggleChannelJoinToSendQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool join_to_send) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleJoinToSend(std::move(input_channel), join_to_send), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleJoinToSend>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleChannelJoinToSendQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleChannelJoinToSendQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleChannelJoinRequestQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit ToggleChannelJoinRequestQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool join_request) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleJoinRequest(std::move(input_channel), join_request), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleJoinRequest>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleChannelJoinRequestQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleChannelJoinRequestQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class TogglePrehistoryHiddenQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  bool is_all_history_available_;

 public:
  explicit TogglePrehistoryHiddenQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool is_all_history_available) {
    channel_id_ = channel_id;
    is_all_history_available_ = is_all_history_available;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_togglePreHistoryHidden(std::move(input_channel), !is_all_history_available),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_togglePreHistoryHidden>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for TogglePrehistoryHiddenQuery: " << to_string(ptr);

    td_->updates_manager_->on_get_updates(
        std::move(ptr),
        PromiseCreator::lambda([actor_id = G()->chat_manager(), promise = std::move(promise_), channel_id = channel_id_,
                                is_all_history_available = is_all_history_available_](Unit result) mutable {
          send_closure(actor_id, &ChatManager::on_update_channel_is_all_history_available, channel_id,
                       is_all_history_available, std::move(promise));
        }));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "TogglePrehistoryHiddenQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class RestrictSponsoredMessagesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  bool can_have_sponsored_messages_;

 public:
  explicit RestrictSponsoredMessagesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool can_have_sponsored_messages) {
    channel_id_ = channel_id;
    can_have_sponsored_messages_ = can_have_sponsored_messages;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_restrictSponsoredMessages(std::move(input_channel), !can_have_sponsored_messages),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_restrictSponsoredMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for RestrictSponsoredMessagesQuery: " << to_string(ptr);

    td_->updates_manager_->on_get_updates(
        std::move(ptr),
        PromiseCreator::lambda([actor_id = G()->chat_manager(), promise = std::move(promise_), channel_id = channel_id_,
                                can_have_sponsored_messages = can_have_sponsored_messages_](Unit result) mutable {
          send_closure(actor_id, &ChatManager::on_update_channel_can_have_sponsored_messages, channel_id,
                       can_have_sponsored_messages, std::move(promise));
        }));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "RestrictSponsoredMessagesQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleParticipantsHiddenQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  bool has_hidden_participants_;

 public:
  explicit ToggleParticipantsHiddenQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool has_hidden_participants) {
    channel_id_ = channel_id;
    has_hidden_participants_ = has_hidden_participants;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleParticipantsHidden(std::move(input_channel), has_hidden_participants),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleParticipantsHidden>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleParticipantsHiddenQuery: " << to_string(ptr);

    td_->updates_manager_->on_get_updates(
        std::move(ptr),
        PromiseCreator::lambda([actor_id = G()->chat_manager(), promise = std::move(promise_), channel_id = channel_id_,
                                has_hidden_participants = has_hidden_participants_](Unit result) mutable {
          send_closure(actor_id, &ChatManager::on_update_channel_has_hidden_participants, channel_id,
                       has_hidden_participants, std::move(promise));
        }));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleParticipantsHiddenQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleAntiSpamQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  bool has_aggressive_anti_spam_enabled_;

 public:
  explicit ToggleAntiSpamQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool has_aggressive_anti_spam_enabled) {
    channel_id_ = channel_id;
    has_aggressive_anti_spam_enabled_ = has_aggressive_anti_spam_enabled;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleAntiSpam(std::move(input_channel), has_aggressive_anti_spam_enabled),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleAntiSpam>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleAntiSpamQuery: " << to_string(ptr);

    td_->updates_manager_->on_get_updates(
        std::move(ptr),
        PromiseCreator::lambda(
            [actor_id = G()->chat_manager(), promise = std::move(promise_), channel_id = channel_id_,
             has_aggressive_anti_spam_enabled = has_aggressive_anti_spam_enabled_](Unit result) mutable {
              send_closure(actor_id, &ChatManager::on_update_channel_has_aggressive_anti_spam_enabled, channel_id,
                           has_aggressive_anti_spam_enabled, std::move(promise));
            }));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleAntiSpamQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleForumQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit ToggleForumQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, bool is_forum) {
    channel_id_ = channel_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::channels_toggleForum(std::move(input_channel), is_forum),
                                               {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleForum>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleForumQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleForumQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ConvertToGigagroupQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit ConvertToGigagroupQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id) {
    channel_id_ = channel_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::channels_convertToGigagroup(std::move(input_channel)),
                                               {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_convertToGigagroup>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ConvertToGigagroupQuery: " << to_string(ptr);

    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      promise_.set_value(Unit());
      return;
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ConvertToGigagroupQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class EditChatAboutQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  string about_;

  void on_success() {
    switch (dialog_id_.get_type()) {
      case DialogType::Chat:
        return td_->chat_manager_->on_update_chat_description(dialog_id_.get_chat_id(), std::move(about_));
      case DialogType::Channel:
        return td_->chat_manager_->on_update_channel_description(dialog_id_.get_channel_id(), std::move(about_));
      case DialogType::User:
      case DialogType::SecretChat:
      case DialogType::None:
        UNREACHABLE();
    }
  }

 public:
  explicit EditChatAboutQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &about) {
    dialog_id_ = dialog_id;
    about_ = about;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_editChatAbout(std::move(input_peer), about),
                                               {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editChatAbout>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG(DEBUG) << "Receive result for EditChatAboutQuery: " << result;
    if (!result) {
      return on_error(Status::Error(500, "Chat description is not updated"));
    }

    on_success();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_ABOUT_NOT_MODIFIED" || status.message() == "CHAT_NOT_MODIFIED") {
      on_success();
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditChatAboutQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class SetDiscussionGroupQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId broadcast_channel_id_;
  ChannelId group_channel_id_;

 public:
  explicit SetDiscussionGroupQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId broadcast_channel_id,
            telegram_api::object_ptr<telegram_api::InputChannel> broadcast_input_channel, ChannelId group_channel_id,
            telegram_api::object_ptr<telegram_api::InputChannel> group_input_channel) {
    broadcast_channel_id_ = broadcast_channel_id;
    group_channel_id_ = group_channel_id;
    send_query(G()->net_query_creator().create(
        telegram_api::channels_setDiscussionGroup(std::move(broadcast_input_channel), std::move(group_input_channel)),
        {{broadcast_channel_id}, {group_channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_setDiscussionGroup>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(INFO, !result) << "Set discussion group has failed";

    td_->chat_manager_->on_update_channel_linked_channel_id(broadcast_channel_id_, group_channel_id_);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "LINK_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    promise_.set_error(std::move(status));
  }
};

class EditLocationQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  DialogLocation location_;

 public:
  explicit EditLocationQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, const DialogLocation &location) {
    channel_id_ = channel_id;
    location_ = location;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::channels_editLocation(std::move(input_channel), location_.get_input_geo_point(),
                                            location_.get_address()),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_editLocation>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(INFO, !result) << "Edit chat location has failed";

    td_->chat_manager_->on_update_channel_location(channel_id_, location_);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "EditLocationQuery");
    promise_.set_error(std::move(status));
  }
};

class ToggleSlowModeQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  int32 slow_mode_delay_ = 0;

 public:
  explicit ToggleSlowModeQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, int32 slow_mode_delay) {
    channel_id_ = channel_id;
    slow_mode_delay_ = slow_mode_delay;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleSlowMode(std::move(input_channel), slow_mode_delay), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleSlowMode>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleSlowModeQuery: " << to_string(ptr);

    td_->updates_manager_->on_get_updates(
        std::move(ptr),
        PromiseCreator::lambda([actor_id = G()->chat_manager(), promise = std::move(promise_), channel_id = channel_id_,
                                slow_mode_delay = slow_mode_delay_](Unit result) mutable {
          send_closure(actor_id, &ChatManager::on_update_channel_slow_mode_delay, channel_id, slow_mode_delay,
                       std::move(promise));
        }));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      td_->chat_manager_->on_update_channel_slow_mode_delay(channel_id_, slow_mode_delay_, Promise<Unit>());
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ToggleSlowModeQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ReportChannelSpamQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  DialogId sender_dialog_id_;

 public:
  explicit ReportChannelSpamQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, DialogId sender_dialog_id, const vector<MessageId> &message_ids) {
    channel_id_ = channel_id;
    sender_dialog_id_ = sender_dialog_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);

    auto input_peer = td_->dialog_manager_->get_input_peer(sender_dialog_id, AccessRights::Know);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(telegram_api::channels_reportSpam(
        std::move(input_channel), std::move(input_peer), MessageId::get_server_message_ids(message_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_reportSpam>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(INFO, !result) << "Report spam has failed in " << channel_id_;

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (sender_dialog_id_.get_type() != DialogType::Channel) {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "ReportChannelSpamQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ReportChannelAntiSpamFalsePositiveQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit ReportChannelAntiSpamFalsePositiveQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, MessageId message_id) {
    channel_id_ = channel_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);

    send_query(G()->net_query_creator().create(telegram_api::channels_reportAntiSpamFalsePositive(
        std::move(input_channel), message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_reportAntiSpamFalsePositive>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(INFO, !result) << "Report anti-spam false positive has failed in " << channel_id_;

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "ReportChannelAntiSpamFalsePositiveQuery");
    promise_.set_error(std::move(status));
  }
};

class UpdatePaidMessagesPriceQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit UpdatePaidMessagesPriceQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, int64 send_paid_messages_stars) {
    channel_id_ = channel_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::channels_updatePaidMessagesPrice(std::move(input_channel), send_paid_messages_stars)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_updatePaidMessagesPrice>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for UpdatePaidMessagesPriceQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "UpdatePaidMessagesPriceQuery");
    promise_.set_error(std::move(status));
  }
};

class DeleteChatQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteChatQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChatId chat_id) {
    send_query(G()->net_query_creator().create(telegram_api::messages_deleteChat(chat_id.get()), {{chat_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteChat>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(INFO) << "Receive result for DeleteChatQuery: " << result_ptr.ok();
    td_->updates_manager_->get_difference("DeleteChatQuery");
    td_->updates_manager_->on_get_updates(make_tl_object<telegram_api::updates>(), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteChannelQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit DeleteChannelQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::channels_deleteChannel(std::move(input_channel)),
                                               {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_deleteChannel>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteChannelQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "DeleteChannelQuery");
    promise_.set_error(std::move(status));
  }
};

class GetCreatedPublicChannelsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  PublicDialogType type_;

 public:
  explicit GetCreatedPublicChannelsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(PublicDialogType type, bool check_limit) {
    type_ = type;
    int32 flags = 0;
    if (type_ == PublicDialogType::IsLocationBased) {
      flags |= telegram_api::channels_getAdminedPublicChannels::BY_LOCATION_MASK;
    }
    if (type_ == PublicDialogType::ForPersonalDialog) {
      CHECK(!check_limit);
      flags |= telegram_api::channels_getAdminedPublicChannels::FOR_PERSONAL_MASK;
    }
    if (check_limit) {
      flags |= telegram_api::channels_getAdminedPublicChannels::CHECK_LIMIT_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::channels_getAdminedPublicChannels(
        flags, false /*ignored*/, false /*ignored*/, false /*ignored*/)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getAdminedPublicChannels>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto chats_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetCreatedPublicChannelsQuery: " << to_string(chats_ptr);
    switch (chats_ptr->get_id()) {
      case telegram_api::messages_chats::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chats>(chats_ptr);
        td_->chat_manager_->on_get_created_public_channels(type_, std::move(chats->chats_));
        break;
      }
      case telegram_api::messages_chatsSlice::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chatsSlice>(chats_ptr);
        LOG(ERROR) << "Receive chatsSlice in result of GetCreatedPublicChannelsQuery";
        td_->chat_manager_->on_get_created_public_channels(type_, std::move(chats->chats_));
        break;
      }
      default:
        UNREACHABLE();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetGroupsForDiscussionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetGroupsForDiscussionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::channels_getGroupsForDiscussion()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getGroupsForDiscussion>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto chats_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetGroupsForDiscussionQuery: " << to_string(chats_ptr);
    switch (chats_ptr->get_id()) {
      case telegram_api::messages_chats::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chats>(chats_ptr);
        td_->chat_manager_->on_get_dialogs_for_discussion(std::move(chats->chats_));
        break;
      }
      case telegram_api::messages_chatsSlice::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chatsSlice>(chats_ptr);
        LOG(ERROR) << "Receive chatsSlice in result of GetGroupsForDiscussionQuery";
        td_->chat_manager_->on_get_dialogs_for_discussion(std::move(chats->chats_));
        break;
      }
      default:
        UNREACHABLE();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetInactiveChannelsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetInactiveChannelsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::channels_getInactiveChannels()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getInactiveChannels>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetInactiveChannelsQuery: " << to_string(result);
    // don't need to use result->dates_, because chat.last_message.date is more reliable
    td_->user_manager_->on_get_users(std::move(result->users_), "GetInactiveChannelsQuery");
    td_->chat_manager_->on_get_inactive_channels(std::move(result->chats_), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetChatsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetChatsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<int64> &&chat_ids) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getChats(std::move(chat_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getChats>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto chats_ptr = result_ptr.move_as_ok();
    switch (chats_ptr->get_id()) {
      case telegram_api::messages_chats::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chats>(chats_ptr);
        td_->chat_manager_->on_get_chats(std::move(chats->chats_), "GetChatsQuery");
        break;
      }
      case telegram_api::messages_chatsSlice::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chatsSlice>(chats_ptr);
        LOG(ERROR) << "Receive chatsSlice in result of GetChatsQuery";
        td_->chat_manager_->on_get_chats(std::move(chats->chats_), "GetChatsQuery slice");
        break;
      }
      default:
        UNREACHABLE();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetFullChatQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChatId chat_id_;

 public:
  explicit GetFullChatQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChatId chat_id) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getFullChat(chat_id.get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getFullChat>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetFullChatQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetFullChatQuery");
    td_->chat_manager_->on_get_chat_full(std::move(ptr->full_chat_), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_chat_full_failed(chat_id_);
    promise_.set_error(std::move(status));
  }
};

class GetChannelsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit GetChannelsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(tl_object_ptr<telegram_api::InputChannel> &&input_channel) {
    CHECK(input_channel != nullptr);
    if (input_channel->get_id() == telegram_api::inputChannel::ID) {
      channel_id_ = ChannelId(static_cast<const telegram_api::inputChannel *>(input_channel.get())->channel_id_);
    } else if (input_channel->get_id() == telegram_api::inputChannelFromMessage::ID) {
      channel_id_ =
          ChannelId(static_cast<const telegram_api::inputChannelFromMessage *>(input_channel.get())->channel_id_);
    }

    vector<tl_object_ptr<telegram_api::InputChannel>> input_channels;
    input_channels.push_back(std::move(input_channel));
    send_query(G()->net_query_creator().create(telegram_api::channels_getChannels(std::move(input_channels))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getChannels>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    //    LOG(INFO) << "Receive result for GetChannelsQuery: " << to_string(result_ptr.ok());
    auto chats_ptr = result_ptr.move_as_ok();
    switch (chats_ptr->get_id()) {
      case telegram_api::messages_chats::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chats>(chats_ptr);
        td_->chat_manager_->on_get_chats(std::move(chats->chats_), "GetChannelsQuery");
        break;
      }
      case telegram_api::messages_chatsSlice::ID: {
        auto chats = move_tl_object_as<telegram_api::messages_chatsSlice>(chats_ptr);
        LOG(ERROR) << "Receive chatsSlice in result of GetChannelsQuery";
        td_->chat_manager_->on_get_chats(std::move(chats->chats_), "GetChannelsQuery slice");
        break;
      }
      default:
        UNREACHABLE();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "GetChannelsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetFullChannelQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit GetFullChannelQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, tl_object_ptr<telegram_api::InputChannel> &&input_channel) {
    channel_id_ = channel_id;
    send_query(G()->net_query_creator().create(telegram_api::channels_getFullChannel(std::move(input_channel))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getFullChannel>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetFullChannelQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetFullChannelQuery");
    td_->chat_manager_->on_get_chat_full(std::move(ptr->full_chat_), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "GetFullChannelQuery");
    td_->chat_manager_->on_get_channel_full_failed(channel_id_);
    promise_.set_error(std::move(status));
  }
};

ChatManager::ChatManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  channel_emoji_status_timeout_.set_callback(on_channel_emoji_status_timeout_callback);
  channel_emoji_status_timeout_.set_callback_data(static_cast<void *>(this));

  channel_unban_timeout_.set_callback(on_channel_unban_timeout_callback);
  channel_unban_timeout_.set_callback_data(static_cast<void *>(this));

  slow_mode_delay_timeout_.set_callback(on_slow_mode_delay_timeout_callback);
  slow_mode_delay_timeout_.set_callback_data(static_cast<void *>(this));

  get_chat_queries_.set_merge_function([this](vector<int64> query_ids, Promise<Unit> &&promise) {
    TRY_STATUS_PROMISE(promise, G()->close_status());
    td_->create_handler<GetChatsQuery>(std::move(promise))->send(std::move(query_ids));
  });
  get_channel_queries_.set_merge_function([this](vector<int64> query_ids, Promise<Unit> &&promise) {
    TRY_STATUS_PROMISE(promise, G()->close_status());
    CHECK(query_ids.size() == 1);
    auto input_channel = get_input_channel(ChannelId(query_ids[0]));
    if (input_channel == nullptr) {
      return promise.set_error(Status::Error(400, "Channel not found"));
    }
    td_->create_handler<GetChannelsQuery>(std::move(promise))->send(std::move(input_channel));
  });
}

ChatManager::~ChatManager() {
  Scheduler::instance()->destroy_on_scheduler(
      G()->get_gc_scheduler_id(), chats_, chats_full_, unknown_chats_, chat_full_file_source_ids_, min_channels_,
      channels_, channels_full_, unknown_channels_, invalidated_channels_full_, channel_full_file_source_ids_);
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), loaded_from_database_chats_,
                                              unavailable_chat_fulls_, loaded_from_database_channels_,
                                              unavailable_channel_fulls_, linked_channel_ids_, restricted_channel_ids_);
}

void ChatManager::tear_down() {
  parent_.reset();

  LOG(DEBUG) << "Have " << chats_.calc_size() << " basic groups and " << channels_.calc_size()
             << " supergroups to free";
  LOG(DEBUG) << "Have " << chats_full_.calc_size() << " full basic groups and " << channels_full_.calc_size()
             << " full supergroups to free";
}

void ChatManager::on_channel_emoji_status_timeout_callback(void *chat_manager_ptr, int64 channel_id_long) {
  if (G()->close_flag()) {
    return;
  }

  auto chat_manager = static_cast<ChatManager *>(chat_manager_ptr);
  send_closure_later(chat_manager->actor_id(chat_manager), &ChatManager::on_channel_emoji_status_timeout,
                     ChannelId(channel_id_long));
}

void ChatManager::on_channel_emoji_status_timeout(ChannelId channel_id) {
  if (G()->close_flag()) {
    return;
  }

  auto c = get_channel(channel_id);
  CHECK(c != nullptr);
  CHECK(c->is_update_supergroup_sent);

  update_channel(c, channel_id);
}

void ChatManager::on_channel_unban_timeout_callback(void *chat_manager_ptr, int64 channel_id_long) {
  if (G()->close_flag()) {
    return;
  }

  auto chat_manager = static_cast<ChatManager *>(chat_manager_ptr);
  send_closure_later(chat_manager->actor_id(chat_manager), &ChatManager::on_channel_unban_timeout,
                     ChannelId(channel_id_long));
}

void ChatManager::on_channel_unban_timeout(ChannelId channel_id) {
  if (G()->close_flag()) {
    return;
  }

  auto c = get_channel(channel_id);
  CHECK(c != nullptr);

  auto old_status = c->status;
  c->status.update_restrictions();
  if (c->status == old_status) {
    LOG_IF(ERROR, c->status.is_restricted() || c->status.is_banned())
        << "Status of " << channel_id << " wasn't updated: " << c->status;
  } else {
    c->is_changed = true;
  }

  LOG(INFO) << "Update " << channel_id << " status";
  c->is_status_changed = true;
  invalidate_channel_full(channel_id, !c->is_slow_mode_enabled, "on_channel_unban_timeout");
  update_channel(c, channel_id);  // always call, because in case of failure we need to reactivate timeout
}

void ChatManager::on_slow_mode_delay_timeout_callback(void *chat_manager_ptr, int64 channel_id_long) {
  if (G()->close_flag()) {
    return;
  }

  auto chat_manager = static_cast<ChatManager *>(chat_manager_ptr);
  send_closure_later(chat_manager->actor_id(chat_manager), &ChatManager::on_slow_mode_delay_timeout,
                     ChannelId(channel_id_long));
}

void ChatManager::on_slow_mode_delay_timeout(ChannelId channel_id) {
  if (G()->close_flag()) {
    return;
  }

  on_update_channel_slow_mode_next_send_date(channel_id, 0);
}

template <class StorerT>
void ChatManager::Chat::store(StorerT &storer) const {
  using td::store;
  bool has_photo = photo.small_file_id.is_valid();
  bool use_new_rights = true;
  bool has_default_permissions_version = default_permissions_version != -1;
  bool has_pinned_message_version = pinned_message_version != -1;
  bool has_cache_version = cache_version != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(is_active);
  STORE_FLAG(has_photo);
  STORE_FLAG(use_new_rights);
  STORE_FLAG(has_default_permissions_version);
  STORE_FLAG(has_pinned_message_version);
  STORE_FLAG(has_cache_version);
  STORE_FLAG(noforwards);
  END_STORE_FLAGS();

  store(title, storer);
  if (has_photo) {
    store(photo, storer);
  }
  store(participant_count, storer);
  store(date, storer);
  store(migrated_to_channel_id, storer);
  store(version, storer);
  store(status, storer);
  store(default_permissions, storer);
  if (has_default_permissions_version) {
    store(default_permissions_version, storer);
  }
  if (has_pinned_message_version) {
    store(pinned_message_version, storer);
  }
  if (has_cache_version) {
    store(cache_version, storer);
  }
}

template <class ParserT>
void ChatManager::Chat::parse(ParserT &parser) {
  using td::parse;
  bool has_photo;
  bool left;
  bool kicked;
  bool is_creator;
  bool is_administrator;
  bool everyone_is_administrator;
  bool can_edit;
  bool use_new_rights;
  bool has_default_permissions_version;
  bool has_pinned_message_version;
  bool has_cache_version;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(left);
  PARSE_FLAG(kicked);
  PARSE_FLAG(is_creator);
  PARSE_FLAG(is_administrator);
  PARSE_FLAG(everyone_is_administrator);
  PARSE_FLAG(can_edit);
  PARSE_FLAG(is_active);
  PARSE_FLAG(has_photo);
  PARSE_FLAG(use_new_rights);
  PARSE_FLAG(has_default_permissions_version);
  PARSE_FLAG(has_pinned_message_version);
  PARSE_FLAG(has_cache_version);
  PARSE_FLAG(noforwards);
  END_PARSE_FLAGS();

  parse(title, parser);
  if (has_photo) {
    parse(photo, parser);
  }
  parse(participant_count, parser);
  parse(date, parser);
  parse(migrated_to_channel_id, parser);
  parse(version, parser);
  if (use_new_rights) {
    parse(status, parser);
    parse(default_permissions, parser);
  } else {
    if (can_edit != (is_creator || is_administrator || everyone_is_administrator)) {
      LOG(ERROR) << "Have wrong can_edit flag";
    }

    if (kicked || !is_active) {
      status = DialogParticipantStatus::Banned(0);
    } else if (left) {
      status = DialogParticipantStatus::Left();
    } else if (is_creator) {
      status = DialogParticipantStatus::Creator(true, false, string());
    } else if (is_administrator && !everyone_is_administrator) {
      status = DialogParticipantStatus::GroupAdministrator(false);
    } else {
      status = DialogParticipantStatus::Member(0);
    }
    default_permissions = RestrictedRights(true, true, true, true, true, true, true, true, true, true, true, true, true,
                                           everyone_is_administrator, everyone_is_administrator,
                                           everyone_is_administrator, false, ChannelType::Unknown);
  }
  if (has_default_permissions_version) {
    parse(default_permissions_version, parser);
  }
  if (has_pinned_message_version) {
    parse(pinned_message_version, parser);
  }
  if (has_cache_version) {
    parse(cache_version, parser);
  }

  if (!check_utf8(title)) {
    LOG(ERROR) << "Have invalid title \"" << title << '"';
    title.clear();
    cache_version = 0;
  }

  if (status.is_administrator() && !status.is_creator()) {
    status = DialogParticipantStatus::GroupAdministrator(false);
  }
}

template <class StorerT>
void ChatManager::ChatFull::store(StorerT &storer) const {
  using td::store;
  bool has_description = !description.empty();
  bool has_legacy_invite_link = false;
  bool has_photo = !photo.is_empty();
  bool has_invite_link = invite_link.is_valid();
  bool has_bot_commands = !bot_commands.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_description);
  STORE_FLAG(has_legacy_invite_link);
  STORE_FLAG(can_set_username);
  STORE_FLAG(has_photo);
  STORE_FLAG(has_invite_link);
  STORE_FLAG(has_bot_commands);
  END_STORE_FLAGS();
  store(version, storer);
  store(creator_user_id, storer);
  store(participants, storer);
  if (has_description) {
    store(description, storer);
  }
  if (has_photo) {
    store(photo, storer);
  }
  if (has_invite_link) {
    store(invite_link, storer);
  }
  if (has_bot_commands) {
    store(bot_commands, storer);
  }
}

template <class ParserT>
void ChatManager::ChatFull::parse(ParserT &parser) {
  using td::parse;
  bool has_description;
  bool legacy_has_invite_link;
  bool has_photo;
  bool has_invite_link;
  bool has_bot_commands;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_description);
  PARSE_FLAG(legacy_has_invite_link);
  PARSE_FLAG(can_set_username);
  PARSE_FLAG(has_photo);
  PARSE_FLAG(has_invite_link);
  PARSE_FLAG(has_bot_commands);
  END_PARSE_FLAGS();
  parse(version, parser);
  parse(creator_user_id, parser);
  parse(participants, parser);
  if (has_description) {
    parse(description, parser);
  }
  if (legacy_has_invite_link) {
    string legacy_invite_link;
    parse(legacy_invite_link, parser);
  }
  if (has_photo) {
    parse(photo, parser);
  }
  if (has_invite_link) {
    parse(invite_link, parser);
  }
  if (has_bot_commands) {
    parse(bot_commands, parser);
  }
}

template <class StorerT>
void ChatManager::Channel::store(StorerT &storer) const {
  using td::store;
  bool has_photo = photo.small_file_id.is_valid();
  bool legacy_has_username = false;
  bool use_new_rights = true;
  bool has_participant_count = participant_count != 0;
  bool have_default_permissions = true;
  bool has_cache_version = cache_version != 0;
  bool has_restriction_reasons = !restriction_reasons.empty();
  bool legacy_has_active_group_call = false;
  bool has_usernames = !usernames.is_empty();
  bool has_flags2 = true;
  bool has_max_active_story_id = max_active_story_id.is_valid();
  bool has_max_read_story_id = max_read_story_id.is_valid();
  bool has_max_active_story_id_next_reload_time = max_active_story_id_next_reload_time > Time::now();
  bool has_accent_color_id = accent_color_id.is_valid();
  bool has_background_custom_emoji_id = background_custom_emoji_id.is_valid();
  bool has_profile_accent_color_id = profile_accent_color_id.is_valid();
  bool has_profile_background_custom_emoji_id = profile_background_custom_emoji_id.is_valid();
  bool has_boost_level = boost_level != 0;
  bool has_emoji_status = emoji_status != nullptr;
  bool has_bot_verification_icon = bot_verification_icon.is_valid();
  bool has_paid_message_star_count = paid_message_star_count != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(sign_messages);
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(false);
  STORE_FLAG(is_megagroup);
  STORE_FLAG(is_verified);
  STORE_FLAG(has_photo);
  STORE_FLAG(legacy_has_username);
  STORE_FLAG(false);
  STORE_FLAG(use_new_rights);
  STORE_FLAG(has_participant_count);
  STORE_FLAG(have_default_permissions);
  STORE_FLAG(is_scam);
  STORE_FLAG(has_cache_version);
  STORE_FLAG(has_linked_channel);
  STORE_FLAG(has_location);
  STORE_FLAG(is_slow_mode_enabled);
  STORE_FLAG(has_restriction_reasons);
  STORE_FLAG(legacy_has_active_group_call);
  STORE_FLAG(is_fake);
  STORE_FLAG(is_gigagroup);
  STORE_FLAG(noforwards);
  STORE_FLAG(can_be_deleted);
  STORE_FLAG(join_to_send);
  STORE_FLAG(join_request);
  STORE_FLAG(has_usernames);
  STORE_FLAG(has_flags2);
  END_STORE_FLAGS();
  if (has_flags2) {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(is_forum);
    STORE_FLAG(has_max_active_story_id);
    STORE_FLAG(has_max_read_story_id);
    STORE_FLAG(has_max_active_story_id_next_reload_time);
    STORE_FLAG(stories_hidden);
    STORE_FLAG(has_accent_color_id);
    STORE_FLAG(has_background_custom_emoji_id);
    STORE_FLAG(has_profile_accent_color_id);
    STORE_FLAG(has_profile_background_custom_emoji_id);
    STORE_FLAG(has_boost_level);
    STORE_FLAG(has_emoji_status);
    STORE_FLAG(show_message_sender);
    STORE_FLAG(has_bot_verification_icon);
    STORE_FLAG(has_paid_message_star_count);
    END_STORE_FLAGS();
  }

  store(status, storer);
  store(access_hash, storer);
  store(title, storer);
  if (has_photo) {
    store(photo, storer);
  }
  store(date, storer);
  if (has_restriction_reasons) {
    store(restriction_reasons, storer);
  }
  if (has_participant_count) {
    store(participant_count, storer);
  }
  if (is_megagroup) {
    store(default_permissions, storer);
  }
  if (has_cache_version) {
    store(cache_version, storer);
  }
  if (has_usernames) {
    store(usernames, storer);
  }
  if (has_max_active_story_id) {
    store(max_active_story_id, storer);
  }
  if (has_max_read_story_id) {
    store(max_read_story_id, storer);
  }
  if (has_max_active_story_id_next_reload_time) {
    store_time(max_active_story_id_next_reload_time, storer);
  }
  if (has_accent_color_id) {
    store(accent_color_id, storer);
  }
  if (has_background_custom_emoji_id) {
    store(background_custom_emoji_id, storer);
  }
  if (has_profile_accent_color_id) {
    store(profile_accent_color_id, storer);
  }
  if (has_profile_background_custom_emoji_id) {
    store(profile_background_custom_emoji_id, storer);
  }
  if (has_boost_level) {
    store(boost_level, storer);
  }
  if (has_emoji_status) {
    store(emoji_status, storer);
  }
  if (has_bot_verification_icon) {
    store(bot_verification_icon, storer);
  }
  if (has_paid_message_star_count) {
    store(paid_message_star_count, storer);
  }
}

template <class ParserT>
void ChatManager::Channel::parse(ParserT &parser) {
  using td::parse;
  bool has_photo;
  bool legacy_has_username;
  bool legacy_is_restricted;
  bool left;
  bool kicked;
  bool is_creator;
  bool can_edit;
  bool can_moderate;
  bool anyone_can_invite;
  bool use_new_rights;
  bool has_participant_count;
  bool have_default_permissions;
  bool has_cache_version;
  bool has_restriction_reasons;
  bool legacy_has_active_group_call;
  bool has_usernames;
  bool has_flags2;
  bool has_max_active_story_id = false;
  bool has_max_read_story_id = false;
  bool has_max_active_story_id_next_reload_time = false;
  bool has_accent_color_id = false;
  bool has_background_custom_emoji_id = false;
  bool has_profile_accent_color_id = false;
  bool has_profile_background_custom_emoji_id = false;
  bool has_boost_level = false;
  bool has_emoji_status = false;
  bool has_bot_verification_icon = false;
  bool has_paid_message_star_count = false;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(left);
  PARSE_FLAG(kicked);
  PARSE_FLAG(anyone_can_invite);
  PARSE_FLAG(sign_messages);
  PARSE_FLAG(is_creator);
  PARSE_FLAG(can_edit);
  PARSE_FLAG(can_moderate);
  PARSE_FLAG(is_megagroup);
  PARSE_FLAG(is_verified);
  PARSE_FLAG(has_photo);
  PARSE_FLAG(legacy_has_username);
  PARSE_FLAG(legacy_is_restricted);
  PARSE_FLAG(use_new_rights);
  PARSE_FLAG(has_participant_count);
  PARSE_FLAG(have_default_permissions);
  PARSE_FLAG(is_scam);
  PARSE_FLAG(has_cache_version);
  PARSE_FLAG(has_linked_channel);
  PARSE_FLAG(has_location);
  PARSE_FLAG(is_slow_mode_enabled);
  PARSE_FLAG(has_restriction_reasons);
  PARSE_FLAG(legacy_has_active_group_call);
  PARSE_FLAG(is_fake);
  PARSE_FLAG(is_gigagroup);
  PARSE_FLAG(noforwards);
  PARSE_FLAG(can_be_deleted);
  PARSE_FLAG(join_to_send);
  PARSE_FLAG(join_request);
  PARSE_FLAG(has_usernames);
  PARSE_FLAG(has_flags2);
  END_PARSE_FLAGS();
  if (has_flags2) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(is_forum);
    PARSE_FLAG(has_max_active_story_id);
    PARSE_FLAG(has_max_read_story_id);
    PARSE_FLAG(has_max_active_story_id_next_reload_time);
    PARSE_FLAG(stories_hidden);
    PARSE_FLAG(has_accent_color_id);
    PARSE_FLAG(has_background_custom_emoji_id);
    PARSE_FLAG(has_profile_accent_color_id);
    PARSE_FLAG(has_profile_background_custom_emoji_id);
    PARSE_FLAG(has_boost_level);
    PARSE_FLAG(has_emoji_status);
    PARSE_FLAG(show_message_sender);
    PARSE_FLAG(has_bot_verification_icon);
    PARSE_FLAG(has_paid_message_star_count);
    END_PARSE_FLAGS();
  }

  if (use_new_rights) {
    parse(status, parser);
  } else {
    if (kicked) {
      status = DialogParticipantStatus::Banned(0);
    } else if (left) {
      status = DialogParticipantStatus::Left();
    } else if (is_creator) {
      status = DialogParticipantStatus::Creator(true, false, string());
    } else if (can_edit || can_moderate) {
      status = DialogParticipantStatus::ChannelAdministrator(false, is_megagroup);
    } else {
      status = DialogParticipantStatus::Member(0);
    }
  }
  parse(access_hash, parser);
  parse(title, parser);
  if (has_photo) {
    parse(photo, parser);
  }
  if (legacy_has_username) {
    if (has_usernames) {
      parser.set_error("Have invalid channel flags");
      return;
    }
    string username;
    parse(username, parser);
    usernames = Usernames(std::move(username), vector<telegram_api::object_ptr<telegram_api::username>>());
  }
  parse(date, parser);
  if (legacy_is_restricted) {
    string restriction_reason;
    parse(restriction_reason, parser);
    restriction_reasons = get_restriction_reasons(restriction_reason);
  } else if (has_restriction_reasons) {
    parse(restriction_reasons, parser);
  }
  if (has_participant_count) {
    parse(participant_count, parser);
  }
  if (is_megagroup) {
    if (have_default_permissions) {
      parse(default_permissions, parser);
    } else {
      default_permissions = RestrictedRights(true, true, true, true, true, true, true, true, true, true, true, true,
                                             true, false, anyone_can_invite, false, false, ChannelType::Megagroup);
    }
  }
  if (has_cache_version) {
    parse(cache_version, parser);
  }
  if (has_usernames) {
    CHECK(!legacy_has_username);
    parse(usernames, parser);
  }
  if (has_max_active_story_id) {
    parse(max_active_story_id, parser);
  }
  if (has_max_read_story_id) {
    parse(max_read_story_id, parser);
  }
  if (has_max_active_story_id_next_reload_time) {
    parse_time(max_active_story_id_next_reload_time, parser);
  }
  if (has_accent_color_id) {
    parse(accent_color_id, parser);
  }
  if (has_background_custom_emoji_id) {
    parse(background_custom_emoji_id, parser);
  }
  if (has_profile_accent_color_id) {
    parse(profile_accent_color_id, parser);
  }
  if (has_profile_background_custom_emoji_id) {
    parse(profile_background_custom_emoji_id, parser);
  }
  if (has_boost_level) {
    parse(boost_level, parser);
  }
  if (has_emoji_status) {
    parse(emoji_status, parser);
  }
  if (has_bot_verification_icon) {
    parse(bot_verification_icon, parser);
  }
  if (has_paid_message_star_count) {
    parse(paid_message_star_count, parser);
  }

  if (!check_utf8(title)) {
    LOG(ERROR) << "Have invalid title \"" << title << '"';
    title.clear();
    cache_version = 0;
  }
  if (legacy_has_active_group_call) {
    cache_version = 0;
  }
  if (is_megagroup) {
    show_message_sender = true;
  } else {
    if (status.is_restricted()) {
      if (status.is_member()) {
        status = DialogParticipantStatus::Member(0);
      } else {
        status = DialogParticipantStatus::Left();
      }
    }
  }
}

template <class StorerT>
void ChatManager::ChannelFull::store(StorerT &storer) const {
  using td::store;
  bool has_description = !description.empty();
  bool has_administrator_count = administrator_count != 0;
  bool has_restricted_count = restricted_count != 0;
  bool has_banned_count = banned_count != 0;
  bool legacy_has_invite_link = false;
  bool has_sticker_set = sticker_set_id.is_valid();
  bool has_linked_channel_id = linked_channel_id.is_valid();
  bool has_migrated_from_max_message_id = migrated_from_max_message_id.is_valid();
  bool has_migrated_from_chat_id = migrated_from_chat_id.is_valid();
  bool has_location = !location.empty();
  bool has_bot_user_ids = !bot_user_ids.empty();
  bool is_slow_mode_enabled = slow_mode_delay != 0;
  bool is_slow_mode_delay_active = slow_mode_next_send_date != 0;
  bool has_stats_dc_id = stats_dc_id.is_exact();
  bool has_photo = !photo.is_empty();
  bool legacy_has_active_group_call_id = false;
  bool has_invite_link = invite_link.is_valid();
  bool has_bot_commands = !bot_commands.empty();
  bool has_flags2 = true;
  bool has_emoji_sticker_set = emoji_sticker_set_id.is_valid();
  bool has_boost_count = boost_count != 0;
  bool has_unrestrict_boost_count = unrestrict_boost_count != 0;
  bool has_can_have_sponsored_messages = true;
  bool has_bot_verification = bot_verification != nullptr;
  bool has_gift_count = gift_count != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_description);
  STORE_FLAG(has_administrator_count);
  STORE_FLAG(has_restricted_count);
  STORE_FLAG(has_banned_count);
  STORE_FLAG(legacy_has_invite_link);
  STORE_FLAG(has_sticker_set);
  STORE_FLAG(has_linked_channel_id);
  STORE_FLAG(has_migrated_from_max_message_id);
  STORE_FLAG(has_migrated_from_chat_id);
  STORE_FLAG(can_get_participants);
  STORE_FLAG(can_set_username);
  STORE_FLAG(can_set_sticker_set);
  STORE_FLAG(false);  // legacy_can_view_statistics
  STORE_FLAG(is_all_history_available);
  STORE_FLAG(can_set_location);
  STORE_FLAG(has_location);
  STORE_FLAG(has_bot_user_ids);
  STORE_FLAG(is_slow_mode_enabled);
  STORE_FLAG(is_slow_mode_delay_active);
  STORE_FLAG(has_stats_dc_id);
  STORE_FLAG(has_photo);
  STORE_FLAG(is_can_view_statistics_inited);
  STORE_FLAG(can_view_statistics);
  STORE_FLAG(legacy_has_active_group_call_id);
  STORE_FLAG(has_invite_link);
  STORE_FLAG(has_bot_commands);
  STORE_FLAG(can_be_deleted);
  STORE_FLAG(has_aggressive_anti_spam_enabled);
  STORE_FLAG(has_hidden_participants);
  STORE_FLAG(has_flags2);
  END_STORE_FLAGS();
  if (has_flags2) {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_pinned_stories);
    STORE_FLAG(has_emoji_sticker_set);
    STORE_FLAG(has_boost_count);
    STORE_FLAG(has_unrestrict_boost_count);
    STORE_FLAG(can_have_sponsored_messages);
    STORE_FLAG(can_view_revenue);
    STORE_FLAG(has_can_have_sponsored_messages);
    STORE_FLAG(has_paid_media_allowed);
    STORE_FLAG(can_view_star_revenue);
    STORE_FLAG(has_bot_verification);
    STORE_FLAG(has_gift_count);
    STORE_FLAG(has_stargifts_available);
    STORE_FLAG(has_paid_messages_available);
    END_STORE_FLAGS();
  }
  if (has_description) {
    store(description, storer);
  }
  store(participant_count, storer);
  if (has_administrator_count) {
    store(administrator_count, storer);
  }
  if (has_restricted_count) {
    store(restricted_count, storer);
  }
  if (has_banned_count) {
    store(banned_count, storer);
  }
  if (has_sticker_set) {
    store(sticker_set_id, storer);
  }
  if (has_linked_channel_id) {
    store(linked_channel_id, storer);
  }
  if (has_location) {
    store(location, storer);
  }
  if (has_bot_user_ids) {
    store(bot_user_ids, storer);
  }
  if (has_migrated_from_max_message_id) {
    store(migrated_from_max_message_id, storer);
  }
  if (has_migrated_from_chat_id) {
    store(migrated_from_chat_id, storer);
  }
  if (is_slow_mode_enabled) {
    store(slow_mode_delay, storer);
  }
  if (is_slow_mode_delay_active) {
    store(slow_mode_next_send_date, storer);
  }
  store_time(expires_at, storer);
  if (has_stats_dc_id) {
    store(stats_dc_id.get_raw_id(), storer);
  }
  if (has_photo) {
    store(photo, storer);
  }
  if (has_invite_link) {
    store(invite_link, storer);
  }
  if (has_bot_commands) {
    store(bot_commands, storer);
  }
  if (has_emoji_sticker_set) {
    store(emoji_sticker_set_id, storer);
  }
  if (has_boost_count) {
    store(boost_count, storer);
  }
  if (has_unrestrict_boost_count) {
    store(unrestrict_boost_count, storer);
  }
  if (has_bot_verification) {
    store(bot_verification, storer);
  }
  if (has_gift_count) {
    store(gift_count, storer);
  }
}

template <class ParserT>
void ChatManager::ChannelFull::parse(ParserT &parser) {
  using td::parse;
  bool has_description;
  bool has_administrator_count;
  bool has_restricted_count;
  bool has_banned_count;
  bool legacy_has_invite_link;
  bool has_sticker_set;
  bool has_linked_channel_id;
  bool has_migrated_from_max_message_id;
  bool has_migrated_from_chat_id;
  bool legacy_can_view_statistics;
  bool has_location;
  bool has_bot_user_ids;
  bool is_slow_mode_enabled;
  bool is_slow_mode_delay_active;
  bool has_stats_dc_id;
  bool has_photo;
  bool legacy_has_active_group_call_id;
  bool has_invite_link;
  bool has_bot_commands;
  bool has_flags2;
  bool has_emoji_sticker_set = false;
  bool has_boost_count = false;
  bool has_unrestrict_boost_count = false;
  bool has_can_have_sponsored_messages = false;
  bool has_bot_verification = false;
  bool has_gift_count = false;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_description);
  PARSE_FLAG(has_administrator_count);
  PARSE_FLAG(has_restricted_count);
  PARSE_FLAG(has_banned_count);
  PARSE_FLAG(legacy_has_invite_link);
  PARSE_FLAG(has_sticker_set);
  PARSE_FLAG(has_linked_channel_id);
  PARSE_FLAG(has_migrated_from_max_message_id);
  PARSE_FLAG(has_migrated_from_chat_id);
  PARSE_FLAG(can_get_participants);
  PARSE_FLAG(can_set_username);
  PARSE_FLAG(can_set_sticker_set);
  PARSE_FLAG(legacy_can_view_statistics);
  PARSE_FLAG(is_all_history_available);
  PARSE_FLAG(can_set_location);
  PARSE_FLAG(has_location);
  PARSE_FLAG(has_bot_user_ids);
  PARSE_FLAG(is_slow_mode_enabled);
  PARSE_FLAG(is_slow_mode_delay_active);
  PARSE_FLAG(has_stats_dc_id);
  PARSE_FLAG(has_photo);
  PARSE_FLAG(is_can_view_statistics_inited);
  PARSE_FLAG(can_view_statistics);
  PARSE_FLAG(legacy_has_active_group_call_id);
  PARSE_FLAG(has_invite_link);
  PARSE_FLAG(has_bot_commands);
  PARSE_FLAG(can_be_deleted);
  PARSE_FLAG(has_aggressive_anti_spam_enabled);
  PARSE_FLAG(has_hidden_participants);
  PARSE_FLAG(has_flags2);
  END_PARSE_FLAGS();
  if (has_flags2) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_pinned_stories);
    PARSE_FLAG(has_emoji_sticker_set);
    PARSE_FLAG(has_boost_count);
    PARSE_FLAG(has_unrestrict_boost_count);
    PARSE_FLAG(can_have_sponsored_messages);
    PARSE_FLAG(can_view_revenue);
    PARSE_FLAG(has_can_have_sponsored_messages);
    PARSE_FLAG(has_paid_media_allowed);
    PARSE_FLAG(can_view_star_revenue);
    PARSE_FLAG(has_bot_verification);
    PARSE_FLAG(has_gift_count);
    PARSE_FLAG(has_stargifts_available);
    PARSE_FLAG(has_paid_messages_available);
    END_PARSE_FLAGS();
  }
  if (has_description) {
    parse(description, parser);
  }
  parse(participant_count, parser);
  if (has_administrator_count) {
    parse(administrator_count, parser);
  }
  if (has_restricted_count) {
    parse(restricted_count, parser);
  }
  if (has_banned_count) {
    parse(banned_count, parser);
  }
  if (legacy_has_invite_link) {
    string legacy_invite_link;
    parse(legacy_invite_link, parser);
  }
  if (has_sticker_set) {
    parse(sticker_set_id, parser);
  }
  if (has_linked_channel_id) {
    parse(linked_channel_id, parser);
  }
  if (has_location) {
    parse(location, parser);
  }
  if (has_bot_user_ids) {
    parse(bot_user_ids, parser);
  }
  if (has_migrated_from_max_message_id) {
    parse(migrated_from_max_message_id, parser);
  }
  if (has_migrated_from_chat_id) {
    parse(migrated_from_chat_id, parser);
  }
  if (is_slow_mode_enabled) {
    parse(slow_mode_delay, parser);
  }
  if (is_slow_mode_delay_active) {
    parse(slow_mode_next_send_date, parser);
  }
  parse_time(expires_at, parser);
  if (has_stats_dc_id) {
    stats_dc_id = DcId::create(parser.fetch_int());
  }
  if (has_photo) {
    parse(photo, parser);
  }
  if (legacy_has_active_group_call_id) {
    InputGroupCallId input_group_call_id;
    parse(input_group_call_id, parser);
  }
  if (has_invite_link) {
    parse(invite_link, parser);
  }
  if (has_bot_commands) {
    parse(bot_commands, parser);
  }
  if (has_emoji_sticker_set) {
    parse(emoji_sticker_set_id, parser);
  }
  if (has_boost_count) {
    parse(boost_count, parser);
  }
  if (has_unrestrict_boost_count) {
    parse(unrestrict_boost_count, parser);
  }
  if (has_bot_verification) {
    parse(bot_verification, parser);
  }
  if (has_gift_count) {
    parse(gift_count, parser);
  }

  if (legacy_can_view_statistics) {
    LOG(DEBUG) << "Ignore legacy can view statistics flag";
  }
  if (!is_can_view_statistics_inited) {
    can_view_statistics = stats_dc_id.is_exact();
  }
  if (!has_can_have_sponsored_messages) {
    can_have_sponsored_messages = true;
  }
}

tl_object_ptr<telegram_api::InputChannel> ChatManager::get_input_channel(ChannelId channel_id) const {
  const Channel *c = get_channel(channel_id);
  if (c == nullptr) {
    if (td_->auth_manager_->is_bot() && channel_id.is_valid()) {
      return make_tl_object<telegram_api::inputChannel>(channel_id.get(), 0);
    }
    auto it = channel_messages_.find(channel_id);
    if (it != channel_messages_.end()) {
      CHECK(!it->second.empty());
      auto message_full_id = *it->second.begin();
      return make_tl_object<telegram_api::inputChannelFromMessage>(
          get_simple_input_peer(message_full_id.get_dialog_id()),
          message_full_id.get_message_id().get_server_message_id().get(), channel_id.get());
    }
    return nullptr;
  }

  return make_tl_object<telegram_api::inputChannel>(channel_id.get(), c->access_hash);
}

bool ChatManager::have_input_peer_chat(ChatId chat_id, AccessRights access_rights) const {
  return have_input_peer_chat(get_chat(chat_id), access_rights);
}

bool ChatManager::have_input_peer_chat(const Chat *c, AccessRights access_rights) {
  if (c == nullptr) {
    LOG(DEBUG) << "Have no basic group";
    return false;
  }
  if (access_rights == AccessRights::Know) {
    return true;
  }
  if (access_rights == AccessRights::Read) {
    return true;
  }
  if (c->status.is_left()) {
    LOG(DEBUG) << "Have left basic group";
    return false;
  }
  if (access_rights == AccessRights::Write && !c->is_active) {
    LOG(DEBUG) << "Have inactive basic group";
    return false;
  }
  return true;
}

tl_object_ptr<telegram_api::InputPeer> ChatManager::get_input_peer_chat(ChatId chat_id,
                                                                        AccessRights access_rights) const {
  auto c = get_chat(chat_id);
  if (!have_input_peer_chat(c, access_rights)) {
    return nullptr;
  }

  return make_tl_object<telegram_api::inputPeerChat>(chat_id.get());
}

bool ChatManager::have_input_peer_channel(ChannelId channel_id, AccessRights access_rights) const {
  const Channel *c = get_channel(channel_id);
  return have_input_peer_channel(c, channel_id, access_rights);
}

tl_object_ptr<telegram_api::InputPeer> ChatManager::get_input_peer_channel(ChannelId channel_id,
                                                                           AccessRights access_rights) const {
  const Channel *c = get_channel(channel_id);
  if (!have_input_peer_channel(c, channel_id, access_rights)) {
    return nullptr;
  }
  if (c == nullptr) {
    if (td_->auth_manager_->is_bot() && channel_id.is_valid()) {
      return make_tl_object<telegram_api::inputPeerChannel>(channel_id.get(), 0);
    }
    auto it = channel_messages_.find(channel_id);
    CHECK(it != channel_messages_.end());
    CHECK(!it->second.empty());
    auto message_full_id = *it->second.begin();
    return make_tl_object<telegram_api::inputPeerChannelFromMessage>(
        get_simple_input_peer(message_full_id.get_dialog_id()),
        message_full_id.get_message_id().get_server_message_id().get(), channel_id.get());
  }

  return make_tl_object<telegram_api::inputPeerChannel>(channel_id.get(), c->access_hash);
}

tl_object_ptr<telegram_api::InputPeer> ChatManager::get_simple_input_peer(DialogId dialog_id) const {
  CHECK(dialog_id.get_type() == DialogType::Channel);
  auto channel_id = dialog_id.get_channel_id();
  const Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);
  // if (!have_input_peer_channel(c, channel_id, AccessRights::Read)) {
  //   return nullptr;
  // }
  return make_tl_object<telegram_api::inputPeerChannel>(channel_id.get(), c->access_hash);
}

bool ChatManager::have_input_peer_channel(const Channel *c, ChannelId channel_id, AccessRights access_rights,
                                          bool from_linked) const {
  if (c == nullptr) {
    LOG(DEBUG) << "Have no " << channel_id;
    if (td_->auth_manager_->is_bot() && channel_id.is_valid()) {
      return true;
    }
    if (channel_messages_.count(channel_id) != 0) {
      return true;
    }
    return false;
  }
  if (access_rights == AccessRights::Know) {
    return true;
  }
  if (c->status.is_administrator()) {
    return true;
  }
  if (c->status.is_banned()) {
    LOG(DEBUG) << "Was banned in " << channel_id;
    return false;
  }
  if (c->status.is_member()) {
    return true;
  }

  bool is_public = is_channel_public(c);
  if (access_rights == AccessRights::Read) {
    if (is_public) {
      return true;
    }
    if (!from_linked && c->has_linked_channel) {
      auto linked_channel_id = get_linked_channel_id(channel_id);
      if (linked_channel_id.is_valid() && have_channel(linked_channel_id)) {
        if (have_input_peer_channel(get_channel(linked_channel_id), linked_channel_id, access_rights, true)) {
          return true;
        }
      } else {
        return true;
      }
    }
    if (!from_linked && td_->dialog_invite_link_manager_->have_dialog_access_by_invite_link(DialogId(channel_id))) {
      return true;
    }
  } else {
    if (!from_linked && c->is_megagroup && !td_->auth_manager_->is_bot() && c->has_linked_channel) {
      auto linked_channel_id = get_linked_channel_id(channel_id);
      if (linked_channel_id.is_valid() && (is_public || have_channel(linked_channel_id))) {
        return is_public ||
               have_input_peer_channel(get_channel(linked_channel_id), linked_channel_id, AccessRights::Read, true);
      } else {
        return true;
      }
    }
  }
  LOG(DEBUG) << "Have no access to " << channel_id;
  return false;
}

bool ChatManager::is_chat_received_from_server(ChatId chat_id) const {
  const auto *c = get_chat(chat_id);
  return c != nullptr && c->is_received_from_server;
}

bool ChatManager::is_channel_received_from_server(ChannelId channel_id) const {
  const auto *c = get_channel(channel_id);
  return c != nullptr && c->is_received_from_server;
}

const DialogPhoto *ChatManager::get_chat_dialog_photo(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return nullptr;
  }
  return &c->photo;
}

const DialogPhoto *ChatManager::get_channel_dialog_photo(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    auto min_channel = get_min_channel(channel_id);
    if (min_channel != nullptr) {
      return &min_channel->photo_;
    }
    return nullptr;
  }
  return &c->photo;
}

int32 ChatManager::get_chat_accent_color_id_object(ChatId chat_id) const {
  return td_->theme_manager_->get_accent_color_id_object(AccentColorId(chat_id));
}

AccentColorId ChatManager::get_channel_accent_color_id(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    auto min_channel = get_min_channel(channel_id);
    if (min_channel != nullptr && min_channel->accent_color_id_.is_valid()) {
      return min_channel->accent_color_id_;
    }
    return AccentColorId(channel_id);
  }
  if (!c->accent_color_id.is_valid()) {
    return AccentColorId(channel_id);
  }

  return c->accent_color_id;
}

int32 ChatManager::get_channel_accent_color_id_object(ChannelId channel_id) const {
  return td_->theme_manager_->get_accent_color_id_object(get_channel_accent_color_id(channel_id),
                                                         AccentColorId(channel_id));
}

CustomEmojiId ChatManager::get_chat_background_custom_emoji_id(ChatId chat_id) const {
  return CustomEmojiId();
}

CustomEmojiId ChatManager::get_channel_background_custom_emoji_id(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return CustomEmojiId();
  }

  return c->background_custom_emoji_id;
}

int32 ChatManager::get_chat_profile_accent_color_id_object(ChatId chat_id) const {
  return -1;
}

int32 ChatManager::get_channel_profile_accent_color_id_object(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return -1;
  }
  return td_->theme_manager_->get_profile_accent_color_id_object(c->profile_accent_color_id);
}

CustomEmojiId ChatManager::get_chat_profile_background_custom_emoji_id(ChatId chat_id) const {
  return CustomEmojiId();
}

CustomEmojiId ChatManager::get_channel_profile_background_custom_emoji_id(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return CustomEmojiId();
  }

  return c->profile_background_custom_emoji_id;
}

string ChatManager::get_chat_title(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return string();
  }
  return c->title;
}

string ChatManager::get_channel_title(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    auto min_channel = get_min_channel(channel_id);
    if (min_channel != nullptr) {
      return min_channel->title_;
    }
    return string();
  }
  return c->title;
}

RestrictedRights ChatManager::get_chat_default_permissions(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return RestrictedRights(false, false, false, false, false, false, false, false, false, false, false, false, false,
                            false, false, false, false, ChannelType::Unknown);
  }
  return c->default_permissions;
}

RestrictedRights ChatManager::get_channel_default_permissions(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return RestrictedRights(false, false, false, false, false, false, false, false, false, false, false, false, false,
                            false, false, false, false, ChannelType::Unknown);
  }
  return c->default_permissions;
}

td_api::object_ptr<td_api::emojiStatus> ChatManager::get_chat_emoji_status_object(ChatId chat_id) const {
  return nullptr;
}

td_api::object_ptr<td_api::emojiStatus> ChatManager::get_channel_emoji_status_object(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr || c->last_sent_emoji_status == nullptr) {
    return nullptr;
  }
  return c->last_sent_emoji_status->get_emoji_status_object();
}

bool ChatManager::get_chat_has_protected_content(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return false;
  }
  return c->noforwards;
}

bool ChatManager::get_channel_has_protected_content(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return c->noforwards;
}

bool ChatManager::get_channel_stories_hidden(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return c->stories_hidden;
}

bool ChatManager::can_poll_channel_active_stories(ChannelId channel_id) const {
  const Channel *c = get_channel(channel_id);
  return need_poll_channel_active_stories(c, channel_id) && Time::now() >= c->max_active_story_id_next_reload_time;
}

bool ChatManager::can_use_premium_custom_emoji_in_channel(ChannelId channel_id) const {
  if (!is_megagroup_channel(channel_id)) {
    return false;
  }
  auto channel_full = get_channel_full_const(channel_id);
  return channel_full == nullptr || channel_full->emoji_sticker_set_id.is_valid();
}

string ChatManager::get_chat_about(ChatId chat_id) {
  auto chat_full = get_chat_full_force(chat_id, "get_chat_about");
  if (chat_full != nullptr) {
    return chat_full->description;
  }
  return string();
}

string ChatManager::get_channel_about(ChannelId channel_id) {
  auto channel_full = get_channel_full_force(channel_id, false, "get_channel_about");
  if (channel_full != nullptr) {
    return channel_full->description;
  }
  return string();
}

string ChatManager::get_channel_search_text(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return get_channel_title(channel_id);
  }
  return PSTRING() << c->title << ' ' << implode(c->usernames.get_active_usernames());
}

string ChatManager::get_channel_first_username(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return string();
  }
  return c->usernames.get_first_username();
}

string ChatManager::get_channel_editable_username(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return string();
  }
  return c->usernames.get_editable_username();
}

ChannelId ChatManager::get_unsupported_channel_id() {
  return ChannelId(static_cast<int64>(G()->is_test_dc() ? 10304875 : 1535424647));
}

void ChatManager::set_chat_description(ChatId chat_id, const string &description, Promise<Unit> &&promise) {
  auto new_description = strip_empty_characters(description, MAX_DESCRIPTION_LENGTH);
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  if (!get_chat_permissions(c).can_change_info_and_settings()) {
    return promise.set_error(Status::Error(400, "Not enough rights to set chat description"));
  }

  td_->create_handler<EditChatAboutQuery>(std::move(promise))->send(DialogId(chat_id), new_description);
}

void ChatManager::set_channel_username(ChannelId channel_id, const string &username, Promise<Unit> &&promise) {
  const auto *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!get_channel_status(c).is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to change supergroup username"));
  }

  if (!username.empty() && !is_allowed_username(username)) {
    return promise.set_error(Status::Error(400, "Username is invalid"));
  }

  td_->create_handler<UpdateChannelUsernameQuery>(std::move(promise))->send(channel_id, username);
}

void ChatManager::toggle_channel_username_is_active(ChannelId channel_id, string &&username, bool is_active,
                                                    Promise<Unit> &&promise) {
  const auto *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!get_channel_status(c).is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to change username"));
  }
  if (!c->usernames.can_toggle(username)) {
    return promise.set_error(Status::Error(400, "Wrong username specified"));
  }
  td_->create_handler<ToggleChannelUsernameQuery>(std::move(promise))->send(channel_id, std::move(username), is_active);
}

void ChatManager::disable_all_channel_usernames(ChannelId channel_id, Promise<Unit> &&promise) {
  const auto *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!get_channel_status(c).is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to disable usernames"));
  }
  td_->create_handler<DeactivateAllChannelUsernamesQuery>(std::move(promise))->send(channel_id);
}

void ChatManager::reorder_channel_usernames(ChannelId channel_id, vector<string> &&usernames, Promise<Unit> &&promise) {
  const auto *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!get_channel_status(c).is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to reorder usernames"));
  }
  if (!c->usernames.can_reorder_to(usernames)) {
    return promise.set_error(Status::Error(400, "Invalid username order specified"));
  }
  if (usernames.size() <= 1) {
    return promise.set_value(Unit());
  }
  td_->create_handler<ReorderChannelUsernamesQuery>(std::move(promise))->send(channel_id, std::move(usernames));
}

void ChatManager::on_update_channel_username_is_active(ChannelId channel_id, string &&username, bool is_active,
                                                       Promise<Unit> &&promise) {
  auto *c = get_channel(channel_id);
  CHECK(c != nullptr);
  if (!c->usernames.can_toggle(username)) {
    return reload_channel(channel_id, std::move(promise), "on_update_channel_username_is_active");
  }
  on_update_channel_usernames(c, channel_id, c->usernames.toggle(username, is_active));
  update_channel(c, channel_id);
  promise.set_value(Unit());
}

void ChatManager::on_deactivate_channel_usernames(ChannelId channel_id, Promise<Unit> &&promise) {
  auto *c = get_channel(channel_id);
  CHECK(c != nullptr);
  on_update_channel_usernames(c, channel_id, c->usernames.deactivate_all());
  update_channel(c, channel_id);
  promise.set_value(Unit());
}

void ChatManager::on_update_channel_active_usernames_order(ChannelId channel_id, vector<string> &&usernames,
                                                           Promise<Unit> &&promise) {
  auto *c = get_channel(channel_id);
  CHECK(c != nullptr);
  if (!c->usernames.can_reorder_to(usernames)) {
    return reload_channel(channel_id, std::move(promise), "on_update_channel_active_usernames_order");
  }
  on_update_channel_usernames(c, channel_id, c->usernames.reorder_to(std::move(usernames)));
  update_channel(c, channel_id);
  promise.set_value(Unit());
}

void ChatManager::set_channel_accent_color(ChannelId channel_id, AccentColorId accent_color_id,
                                           CustomEmojiId background_custom_emoji_id, Promise<Unit> &&promise) {
  if (!accent_color_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid accent color identifier specified"));
  }

  const auto *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Accent color can be changed only in channel chats"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings_as_administrator()) {
    return promise.set_error(Status::Error(400, "Not enough rights in the channel"));
  }

  td_->create_handler<UpdateChannelColorQuery>(std::move(promise))
      ->send(channel_id, false, accent_color_id, background_custom_emoji_id);
}

void ChatManager::set_channel_profile_accent_color(ChannelId channel_id, AccentColorId profile_accent_color_id,
                                                   CustomEmojiId profile_background_custom_emoji_id,
                                                   Promise<Unit> &&promise) {
  const auto *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings_as_administrator()) {
    return promise.set_error(Status::Error(400, "Not enough rights in the chat"));
  }

  td_->create_handler<UpdateChannelColorQuery>(std::move(promise))
      ->send(channel_id, true, profile_accent_color_id, profile_background_custom_emoji_id);
}

void ChatManager::set_channel_emoji_status(ChannelId channel_id, const unique_ptr<EmojiStatus> &emoji_status,
                                           Promise<Unit> &&promise) {
  const auto *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings_as_administrator()) {
    return promise.set_error(Status::Error(400, "Not enough rights in the chat"));
  }

  if (emoji_status != nullptr) {
    add_recent_emoji_status(td_, *emoji_status);
  }

  td_->create_handler<UpdateChannelEmojiStatusQuery>(std::move(promise))->send(channel_id, emoji_status);
}

void ChatManager::set_channel_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id, Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Chat sticker set can be set only for supergroups"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings_as_administrator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to change supergroup sticker set"));
  }

  telegram_api::object_ptr<telegram_api::InputStickerSet> input_sticker_set;
  if (!sticker_set_id.is_valid()) {
    input_sticker_set = telegram_api::make_object<telegram_api::inputStickerSetEmpty>();
  } else {
    input_sticker_set = td_->stickers_manager_->get_input_sticker_set(sticker_set_id);
    if (input_sticker_set == nullptr) {
      return promise.set_error(Status::Error(400, "Sticker set not found"));
    }
  }

  auto channel_full = get_channel_full(channel_id, false, "set_channel_sticker_set");
  if (channel_full != nullptr && !channel_full->can_set_sticker_set) {
    return promise.set_error(Status::Error(400, "Can't set supergroup sticker set"));
  }

  td_->create_handler<SetChannelStickerSetQuery>(std::move(promise))
      ->send(channel_id, sticker_set_id, std::move(input_sticker_set));
}

void ChatManager::set_channel_emoji_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id,
                                                Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Cuctom emoji sticker set can be set only for supergroups"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings_as_administrator()) {
    return promise.set_error(
        Status::Error(400, "Not enough rights to change custom emoji sticker set in the supergroup"));
  }

  telegram_api::object_ptr<telegram_api::InputStickerSet> input_sticker_set;
  if (!sticker_set_id.is_valid()) {
    input_sticker_set = telegram_api::make_object<telegram_api::inputStickerSetEmpty>();
  } else {
    input_sticker_set = td_->stickers_manager_->get_input_sticker_set(sticker_set_id);
    if (input_sticker_set == nullptr) {
      return promise.set_error(Status::Error(400, "Sticker set not found"));
    }
  }

  td_->create_handler<SetChannelEmojiStickerSetQuery>(std::move(promise))
      ->send(channel_id, sticker_set_id, std::move(input_sticker_set));
}

void ChatManager::set_channel_unrestrict_boost_count(ChannelId channel_id, int32 unrestrict_boost_count,
                                                     Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Unrestrict boost count can be set only for supergroups"));
  }
  if (!get_channel_status(c).can_restrict_members()) {
    return promise.set_error(
        Status::Error(400, "Not enough rights to change unrestrict boost count set in the supergroup"));
  }
  if (unrestrict_boost_count < 0 || unrestrict_boost_count > 8) {
    return promise.set_error(Status::Error(400, "Invalid new value for the unrestrict boost count specified"));
  }

  td_->create_handler<SetChannelBoostsToUnblockRestrictionsQuery>(std::move(promise))
      ->send(channel_id, unrestrict_boost_count);
}

void ChatManager::toggle_channel_sign_messages(ChannelId channel_id, bool sign_messages, bool show_message_sender,
                                               Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (get_channel_type(c) == ChannelType::Megagroup) {
    return promise.set_error(Status::Error(400, "Message signatures can't be toggled in supergroups"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings()) {
    return promise.set_error(Status::Error(400, "Not enough rights to toggle channel sign messages"));
  }

  td_->create_handler<ToggleChannelSignaturesQuery>(std::move(promise))
      ->send(channel_id, sign_messages, show_message_sender);
}

void ChatManager::toggle_channel_join_to_send(ChannelId channel_id, bool join_to_send, Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (get_channel_type(c) == ChannelType::Broadcast || c->is_gigagroup) {
    return promise.set_error(Status::Error(400, "The method can be called only for ordinary supergroups"));
  }
  if (!get_channel_status(c).can_restrict_members()) {
    return promise.set_error(Status::Error(400, "Not enough rights"));
  }

  td_->create_handler<ToggleChannelJoinToSendQuery>(std::move(promise))->send(channel_id, join_to_send);
}

void ChatManager::toggle_channel_join_request(ChannelId channel_id, bool join_request, Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (get_channel_type(c) == ChannelType::Broadcast || c->is_gigagroup) {
    return promise.set_error(Status::Error(400, "The method can be called only for ordinary supergroups"));
  }
  if (!get_channel_status(c).can_restrict_members()) {
    return promise.set_error(Status::Error(400, "Not enough rights"));
  }

  td_->create_handler<ToggleChannelJoinRequestQuery>(std::move(promise))->send(channel_id, join_request);
}

void ChatManager::toggle_channel_is_all_history_available(ChannelId channel_id, bool is_all_history_available,
                                                          Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings()) {
    return promise.set_error(Status::Error(400, "Not enough rights to toggle all supergroup history availability"));
  }
  if (get_channel_type(c) != ChannelType::Megagroup) {
    return promise.set_error(Status::Error(400, "Message history can be hidden in supergroups only"));
  }
  if (c->is_forum && !is_all_history_available) {
    return promise.set_error(Status::Error(400, "Message history can't be hidden in forum supergroups"));
  }
  if (c->has_linked_channel && !is_all_history_available) {
    return promise.set_error(Status::Error(400, "Message history can't be hidden in discussion supergroups"));
  }
  // it can be toggled in public chats, but will not affect them

  td_->create_handler<TogglePrehistoryHiddenQuery>(std::move(promise))->send(channel_id, is_all_history_available);
}

void ChatManager::toggle_channel_can_have_sponsored_messages(ChannelId channel_id, bool can_have_sponsored_messages,
                                                             Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!get_channel_status(c).is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to disable sponsored messages"));
  }
  if (get_channel_type(c) != ChannelType::Broadcast) {
    return promise.set_error(Status::Error(400, "Sponsored messages can be disabled only in channels"));
  }

  td_->create_handler<RestrictSponsoredMessagesQuery>(std::move(promise))
      ->send(channel_id, can_have_sponsored_messages);
}

Status ChatManager::can_hide_chat_participants(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return Status::Error(400, "Basic group not found");
  }
  if (!get_chat_permissions(c).is_creator()) {
    return Status::Error(400, "Not enough rights to hide group members");
  }
  if (c->participant_count < td_->option_manager_->get_option_integer("hidden_members_group_size_min")) {
    return Status::Error(400, "The basic group is too small");
  }
  return Status::OK();
}

Status ChatManager::can_hide_channel_participants(ChannelId channel_id, const ChannelFull *channel_full) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return Status::Error(400, "Supergroup not found");
  }
  if (!get_channel_status(c).can_restrict_members()) {
    return Status::Error(400, "Not enough rights to hide group members");
  }
  if (get_channel_type(c) != ChannelType::Megagroup) {
    return Status::Error(400, "Group members are hidden by default in channels");
  }
  if (channel_full != nullptr && channel_full->has_hidden_participants) {
    return Status::OK();
  }
  if (c->participant_count > 0 &&
      c->participant_count < td_->option_manager_->get_option_integer("hidden_members_group_size_min")) {
    return Status::Error(400, "The supergroup is too small");
  }
  return Status::OK();
}

void ChatManager::toggle_channel_has_hidden_participants(ChannelId channel_id, bool has_hidden_participants,
                                                         Promise<Unit> &&promise) {
  auto channel_full = get_channel_full_force(channel_id, true, "toggle_channel_has_hidden_participants");
  TRY_STATUS_PROMISE(promise, can_hide_channel_participants(channel_id, channel_full));

  td_->create_handler<ToggleParticipantsHiddenQuery>(std::move(promise))->send(channel_id, has_hidden_participants);
}

Status ChatManager::can_toggle_chat_aggressive_anti_spam(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return Status::Error(400, "Basic group not found");
  }
  if (!get_chat_permissions(c).is_creator()) {
    return Status::Error(400, "Not enough rights to enable aggressive anti-spam checks");
  }
  if (c->participant_count <
      td_->option_manager_->get_option_integer("aggressive_anti_spam_supergroup_member_count_min")) {
    return Status::Error(400, "The basic group is too small");
  }
  return Status::OK();
}

Status ChatManager::can_toggle_channel_aggressive_anti_spam(ChannelId channel_id,
                                                            const ChannelFull *channel_full) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return Status::Error(400, "Supergroup not found");
  }
  if (!get_channel_status(c).can_delete_messages()) {
    return Status::Error(400, "Not enough rights to enable aggressive anti-spam checks");
  }
  if (get_channel_type(c) != ChannelType::Megagroup) {
    return Status::Error(400, "Aggressive anti-spam checks can be enabled in supergroups only");
  }
  if (c->is_gigagroup) {
    return Status::Error(400, "Aggressive anti-spam checks can't be enabled in broadcast supergroups");
  }
  if (channel_full != nullptr && channel_full->has_aggressive_anti_spam_enabled) {
    return Status::OK();
  }
  if (c->has_location || begins_with(c->usernames.get_editable_username(), "translation_")) {
    return Status::OK();
  }
  if (c->participant_count > 0 && c->participant_count < td_->option_manager_->get_option_integer(
                                                             "aggressive_anti_spam_supergroup_member_count_min")) {
    return Status::Error(400, "The supergroup is too small");
  }
  return Status::OK();
}

void ChatManager::toggle_channel_has_aggressive_anti_spam_enabled(ChannelId channel_id,
                                                                  bool has_aggressive_anti_spam_enabled,
                                                                  Promise<Unit> &&promise) {
  auto channel_full = get_channel_full_force(channel_id, true, "toggle_channel_has_aggressive_anti_spam_enabled");
  TRY_STATUS_PROMISE(promise, can_toggle_channel_aggressive_anti_spam(channel_id, channel_full));

  td_->create_handler<ToggleAntiSpamQuery>(std::move(promise))->send(channel_id, has_aggressive_anti_spam_enabled);
}

void ChatManager::toggle_channel_is_forum(ChannelId channel_id, bool is_forum, Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (c->is_forum == is_forum) {
    return promise.set_value(Unit());
  }
  if (!get_channel_status(c).is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to convert the group to a forum"));
  }
  if (get_channel_type(c) != ChannelType::Megagroup) {
    return promise.set_error(Status::Error(400, "Forums can be enabled in supergroups only"));
  }

  td_->create_handler<ToggleForumQuery>(std::move(promise))->send(channel_id, is_forum);
}

void ChatManager::convert_channel_to_gigagroup(ChannelId channel_id, Promise<Unit> &&promise) {
  if (!can_convert_channel_to_gigagroup(channel_id)) {
    return promise.set_error(Status::Error(400, "Can't convert the chat to a broadcast group"));
  }

  td_->suggested_action_manager_->remove_dialog_suggested_action(
      SuggestedAction{SuggestedAction::Type::ConvertToGigagroup, DialogId(channel_id)});

  td_->create_handler<ConvertToGigagroupQuery>(std::move(promise))->send(channel_id);
}

void ChatManager::set_channel_description(ChannelId channel_id, const string &description, Promise<Unit> &&promise) {
  auto new_description = strip_empty_characters(description, MAX_DESCRIPTION_LENGTH);
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  if (!get_channel_permissions(channel_id, c).can_change_info_and_settings()) {
    return promise.set_error(Status::Error(400, "Not enough rights to set chat description"));
  }

  td_->create_handler<EditChatAboutQuery>(std::move(promise))->send(DialogId(channel_id), new_description);
}

void ChatManager::set_channel_discussion_group(DialogId dialog_id, DialogId discussion_dialog_id,
                                               Promise<Unit> &&promise) {
  if (!dialog_id.is_valid() && !discussion_dialog_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid chat identifiers specified"));
  }

  ChannelId broadcast_channel_id;
  telegram_api::object_ptr<telegram_api::InputChannel> broadcast_input_channel;
  if (dialog_id.is_valid()) {
    if (!td_->dialog_manager_->have_dialog_force(dialog_id, "set_channel_discussion_group 1")) {
      return promise.set_error(Status::Error(400, "Chat not found"));
    }

    if (dialog_id.get_type() != DialogType::Channel) {
      return promise.set_error(Status::Error(400, "Chat is not a channel"));
    }

    broadcast_channel_id = dialog_id.get_channel_id();
    const Channel *c = get_channel(broadcast_channel_id);
    if (c == nullptr) {
      return promise.set_error(Status::Error(400, "Chat info not found"));
    }

    if (c->is_megagroup) {
      return promise.set_error(Status::Error(400, "Chat is not a channel"));
    }
    if (!c->status.can_change_info_and_settings_as_administrator()) {
      return promise.set_error(Status::Error(400, "Not enough rights in the channel"));
    }

    broadcast_input_channel = get_input_channel(broadcast_channel_id);
    CHECK(broadcast_input_channel != nullptr);
  } else {
    broadcast_input_channel = telegram_api::make_object<telegram_api::inputChannelEmpty>();
  }

  ChannelId group_channel_id;
  telegram_api::object_ptr<telegram_api::InputChannel> group_input_channel;
  if (discussion_dialog_id.is_valid()) {
    if (!td_->dialog_manager_->have_dialog_force(discussion_dialog_id, "set_channel_discussion_group 2")) {
      return promise.set_error(Status::Error(400, "Discussion chat not found"));
    }
    if (discussion_dialog_id.get_type() != DialogType::Channel) {
      return promise.set_error(Status::Error(400, "Discussion chat is not a supergroup"));
    }

    group_channel_id = discussion_dialog_id.get_channel_id();
    const Channel *c = get_channel(group_channel_id);
    if (c == nullptr) {
      return promise.set_error(Status::Error(400, "Discussion chat info not found"));
    }

    if (!c->is_megagroup) {
      return promise.set_error(Status::Error(400, "Discussion chat is not a supergroup"));
    }
    if (!c->status.is_administrator() || !c->status.can_pin_messages()) {
      return promise.set_error(Status::Error(400, "Not enough rights in the supergroup"));
    }

    group_input_channel = get_input_channel(group_channel_id);
    CHECK(group_input_channel != nullptr);
  } else {
    group_input_channel = telegram_api::make_object<telegram_api::inputChannelEmpty>();
  }

  td_->create_handler<SetDiscussionGroupQuery>(std::move(promise))
      ->send(broadcast_channel_id, std::move(broadcast_input_channel), group_channel_id,
             std::move(group_input_channel));
}

void ChatManager::set_channel_location(ChannelId channel_id, const DialogLocation &location, Promise<Unit> &&promise) {
  if (location.empty()) {
    return promise.set_error(Status::Error(400, "Invalid chat location specified"));
  }

  const Channel *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Chat is not a supergroup"));
  }
  if (!c->status.is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights in the supergroup"));
  }

  td_->create_handler<EditLocationQuery>(std::move(promise))->send(channel_id, location);
}

void ChatManager::set_channel_slow_mode_delay(DialogId dialog_id, int32 slow_mode_delay, Promise<Unit> &&promise) {
  vector<int32> allowed_slow_mode_delays{0, 10, 30, 60, 300, 900, 3600};
  if (!td::contains(allowed_slow_mode_delays, slow_mode_delay)) {
    return promise.set_error(Status::Error(400, "Invalid new value for slow mode delay"));
  }

  if (!dialog_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid chat identifier specified"));
  }
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "set_channel_slow_mode_delay")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  if (dialog_id.get_type() != DialogType::Channel) {
    return promise.set_error(Status::Error(400, "Chat is not a supergroup"));
  }

  auto channel_id = dialog_id.get_channel_id();
  const Channel *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Chat is not a supergroup"));
  }
  if (!get_channel_status(c).can_restrict_members()) {
    return promise.set_error(Status::Error(400, "Not enough rights in the supergroup"));
  }

  td_->create_handler<ToggleSlowModeQuery>(std::move(promise))->send(channel_id, slow_mode_delay);
}

void ChatManager::get_channel_statistics_dc_id(DialogId dialog_id, bool for_full_statistics, Promise<DcId> &&promise) {
  if (!dialog_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid chat identifier specified"));
  }
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "get_channel_statistics_dc_id")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  if (dialog_id.get_type() != DialogType::Channel) {
    return promise.set_error(Status::Error(400, "Chat is not a channel"));
  }

  auto channel_id = dialog_id.get_channel_id();
  const Channel *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }

  auto channel_full = get_channel_full_force(channel_id, false, "get_channel_statistics_dc_id");
  if (channel_full == nullptr || !channel_full->stats_dc_id.is_exact() ||
      (for_full_statistics && !channel_full->can_view_statistics)) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), channel_id, for_full_statistics,
                                                 promise = std::move(promise)](Result<Unit> result) mutable {
      send_closure(actor_id, &ChatManager::get_channel_statistics_dc_id_impl, channel_id, for_full_statistics,
                   std::move(promise));
    });
    send_get_channel_full_query(channel_full, channel_id, std::move(query_promise), "get_channel_statistics_dc_id");
    return;
  }

  promise.set_value(DcId(channel_full->stats_dc_id));
}

void ChatManager::get_channel_statistics_dc_id_impl(ChannelId channel_id, bool for_full_statistics,
                                                    Promise<DcId> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto channel_full = get_channel_full(channel_id, false, "get_channel_statistics_dc_id_impl");
  if (channel_full == nullptr) {
    return promise.set_error(Status::Error(400, "Chat full info not found"));
  }

  if (!channel_full->stats_dc_id.is_exact() || (for_full_statistics && !channel_full->can_view_statistics)) {
    return promise.set_error(Status::Error(400, "Chat statistics are not available"));
  }

  promise.set_value(DcId(channel_full->stats_dc_id));
}

bool ChatManager::can_get_channel_message_statistics(ChannelId channel_id) const {
  CHECK(!td_->auth_manager_->is_bot());
  const Channel *c = get_channel(channel_id);
  if (c == nullptr || c->is_megagroup) {
    return false;
  }

  auto channel_full = get_channel_full(channel_id);
  if (channel_full != nullptr) {
    return channel_full->stats_dc_id.is_exact();
  }

  return c->status.can_post_messages();
}

bool ChatManager::can_get_channel_story_statistics(ChannelId channel_id) const {
  CHECK(!td_->auth_manager_->is_bot());
  const Channel *c = get_channel(channel_id);
  if (c == nullptr || c->is_megagroup) {
    return false;
  }

  auto channel_full = get_channel_full(channel_id);
  if (channel_full != nullptr) {
    return channel_full->stats_dc_id.is_exact();
  }

  return c->status.can_post_messages();
}

bool ChatManager::can_convert_channel_to_gigagroup(ChannelId channel_id) const {
  const Channel *c = get_channel(channel_id);
  return c == nullptr || get_channel_type(c) != ChannelType::Megagroup || !get_channel_status(c).is_creator() ||
         c->is_gigagroup ||
         c->default_permissions != RestrictedRights(false, false, false, false, false, false, false, false, false,
                                                    false, false, false, false, false, false, false, false,
                                                    ChannelType::Unknown);
}

void ChatManager::report_channel_spam(ChannelId channel_id, const vector<MessageId> &message_ids,
                                      Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Spam can be reported only in supergroups"));
  }
  if (!c->status.is_administrator()) {
    return promise.set_error(Status::Error(400, "Spam can be reported only by chat administrators"));
  }

  FlatHashMap<DialogId, vector<MessageId>, DialogIdHash> server_message_ids;
  for (auto &message_id : message_ids) {
    TRY_STATUS_PROMISE(promise, MessagesManager::can_report_message(message_id));
    auto sender_dialog_id = td_->messages_manager_->get_dialog_message_sender({DialogId(channel_id), message_id});
    CHECK(sender_dialog_id.get_type() != DialogType::SecretChat);
    if (sender_dialog_id.is_valid() && sender_dialog_id != td_->dialog_manager_->get_my_dialog_id() &&
        td_->dialog_manager_->have_input_peer(sender_dialog_id, false, AccessRights::Know)) {
      server_message_ids[sender_dialog_id].push_back(message_id);
    }
  }
  if (server_message_ids.empty()) {
    return promise.set_value(Unit());
  }

  MultiPromiseActorSafe mpas{"ReportSupergroupSpamMultiPromiseActor"};
  mpas.add_promise(std::move(promise));
  auto lock_promise = mpas.get_promise();

  for (auto &it : server_message_ids) {
    td_->create_handler<ReportChannelSpamQuery>(mpas.get_promise())->send(channel_id, it.first, it.second);
  }

  lock_promise.set_value(Unit());
}

void ChatManager::report_channel_anti_spam_false_positive(ChannelId channel_id, MessageId message_id,
                                                          Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "The chat is not a supergroup"));
  }
  if (!c->status.is_administrator()) {
    return promise.set_error(
        Status::Error(400, "Anti-spam checks false positives can be reported only by chat administrators"));
  }

  if (!message_id.is_valid() || !message_id.is_server()) {
    return promise.set_error(Status::Error(400, "Invalid message identifier specified"));
  }

  td_->create_handler<ReportChannelAntiSpamFalsePositiveQuery>(std::move(promise))->send(channel_id, message_id);
}

void ChatManager::set_channel_send_paid_messages_star_count(DialogId dialog_id, int64 send_paid_messages_star_count,
                                                            Promise<Unit> &&promise) {
  if (!dialog_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid chat identifier specified"));
  }
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "set_channel_send_paid_messages_star_count")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  if (dialog_id.get_type() != DialogType::Channel) {
    return promise.set_error(Status::Error(400, "Chat is not a supergroup"));
  }

  auto channel_id = dialog_id.get_channel_id();
  const Channel *c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  if (!c->is_megagroup) {
    return promise.set_error(Status::Error(400, "Chat is not a supergroup"));
  }
  if (!get_channel_status(c).can_restrict_members()) {
    return promise.set_error(Status::Error(400, "Not enough rights in the supergroup"));
  }
  if (send_paid_messages_star_count < 0 || send_paid_messages_star_count > 1000000) {
    return promise.set_error(Status::Error(400, "Invalid number of Telegram Stars specified"));
  }

  td_->create_handler<UpdatePaidMessagesPriceQuery>(std::move(promise))
      ->send(channel_id, send_paid_messages_star_count);
}

void ChatManager::delete_chat(ChatId chat_id, Promise<Unit> &&promise) {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  if (!get_chat_status(c).is_creator()) {
    return promise.set_error(Status::Error(400, "Not enough rights to delete the chat"));
  }
  if (!c->is_active) {
    return promise.set_error(Status::Error(400, "Chat is already deactivated"));
  }

  td_->create_handler<DeleteChatQuery>(std::move(promise))->send(chat_id);
}

void ChatManager::delete_channel(ChannelId channel_id, Promise<Unit> &&promise) {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  if (!get_channel_can_be_deleted(c)) {
    return promise.set_error(Status::Error(400, "The chat can't be deleted"));
  }

  td_->create_handler<DeleteChannelQuery>(std::move(promise))->send(channel_id);
}

vector<ChannelId> ChatManager::get_channel_ids(vector<tl_object_ptr<telegram_api::Chat>> &&chats, const char *source) {
  vector<ChannelId> channel_ids;
  for (auto &chat : chats) {
    auto channel_id = get_channel_id(chat);
    if (!channel_id.is_valid()) {
      LOG(ERROR) << "Receive invalid " << channel_id << " from " << source << " in " << to_string(chat);
      continue;
    }
    on_get_chat(std::move(chat), source);
    if (have_channel(channel_id)) {
      channel_ids.push_back(channel_id);
    }
  }
  return channel_ids;
}

vector<DialogId> ChatManager::get_dialog_ids(vector<tl_object_ptr<telegram_api::Chat>> &&chats, const char *source) {
  vector<DialogId> dialog_ids;
  for (auto &chat : chats) {
    auto channel_id = get_channel_id(chat);
    if (!channel_id.is_valid()) {
      auto chat_id = get_chat_id(chat);
      if (!chat_id.is_valid()) {
        LOG(ERROR) << "Receive invalid chat from " << source << " in " << to_string(chat);
      } else {
        dialog_ids.push_back(DialogId(chat_id));
      }
    } else {
      dialog_ids.push_back(DialogId(channel_id));
    }
    on_get_chat(std::move(chat), source);
  }
  return dialog_ids;
}

void ChatManager::return_created_public_dialogs(Promise<td_api::object_ptr<td_api::chats>> &&promise,
                                                const vector<ChannelId> &channel_ids) {
  if (!promise) {
    return;
  }

  auto total_count = narrow_cast<int32>(channel_ids.size());
  promise.set_value(td_api::make_object<td_api::chats>(
      total_count, transform(channel_ids, [](ChannelId channel_id) { return DialogId(channel_id).get(); })));
}

bool ChatManager::is_suitable_created_public_channel(PublicDialogType type, const Channel *c) {
  if (c == nullptr || !c->status.is_creator()) {
    return false;
  }

  switch (type) {
    case PublicDialogType::HasUsername:
      return c->usernames.has_editable_username();
    case PublicDialogType::IsLocationBased:
      return c->has_location;
    case PublicDialogType::ForPersonalDialog:
      return !c->is_megagroup && c->usernames.has_first_username();
    default:
      UNREACHABLE();
      return false;
  }
}

void ChatManager::get_created_public_dialogs(PublicDialogType type,
                                             Promise<td_api::object_ptr<td_api::chats>> &&promise, bool from_binlog) {
  auto index = static_cast<int32>(type);
  if (created_public_channels_inited_[index]) {
    return return_created_public_dialogs(std::move(promise), created_public_channels_[index]);
  }

  if (get_created_public_channels_queries_[index].empty() && G()->use_message_database()) {
    auto pmc_key = PSTRING() << "public_channels" << index;
    auto str = G()->td_db()->get_binlog_pmc()->get(pmc_key);
    if (!str.empty()) {
      auto r_channel_ids = transform(full_split(Slice(str), ','), [](Slice str) -> Result<ChannelId> {
        TRY_RESULT(channel_id_int, to_integer_safe<int64>(str));
        ChannelId channel_id(channel_id_int);
        if (!channel_id.is_valid()) {
          return Status::Error("Have invalid channel ID");
        }
        return channel_id;
      });
      if (any_of(r_channel_ids, [](const auto &r_channel_id) { return r_channel_id.is_error(); })) {
        LOG(ERROR) << "Can't parse " << str;
        G()->td_db()->get_binlog_pmc()->erase(pmc_key);
      } else {
        Dependencies dependencies;
        vector<ChannelId> channel_ids;
        for (auto &r_channel_id : r_channel_ids) {
          auto channel_id = r_channel_id.move_as_ok();
          dependencies.add_dialog_and_dependencies(DialogId(channel_id));
          channel_ids.push_back(channel_id);
        }
        if (!dependencies.resolve_force(td_, "get_created_public_dialogs")) {
          G()->td_db()->get_binlog_pmc()->erase(pmc_key);
        } else {
          for (auto channel_id : channel_ids) {
            if (is_suitable_created_public_channel(type, get_channel(channel_id))) {
              created_public_channels_[index].push_back(channel_id);
            }
          }
          created_public_channels_inited_[index] = true;

          if (from_binlog) {
            return_created_public_dialogs(std::move(promise), created_public_channels_[index]);
            promise = {};
          }
        }
      }
    }
  }

  reload_created_public_dialogs(type, std::move(promise));
}

void ChatManager::reload_created_public_dialogs(PublicDialogType type,
                                                Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  auto index = static_cast<int32>(type);
  get_created_public_channels_queries_[index].push_back(std::move(promise));
  if (get_created_public_channels_queries_[index].size() == 1) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), type](Result<Unit> &&result) {
      send_closure(actor_id, &ChatManager::finish_get_created_public_dialogs, type, std::move(result));
    });
    td_->create_handler<GetCreatedPublicChannelsQuery>(std::move(query_promise))->send(type, false);
  }
}

void ChatManager::finish_get_created_public_dialogs(PublicDialogType type, Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);

  auto index = static_cast<int32>(type);
  auto promises = std::move(get_created_public_channels_queries_[index]);
  reset_to_empty(get_created_public_channels_queries_[index]);
  if (result.is_error()) {
    return fail_promises(promises, result.move_as_error());
  }

  CHECK(created_public_channels_inited_[index]);
  for (auto &promise : promises) {
    return_created_public_dialogs(std::move(promise), created_public_channels_[index]);
  }
}

void ChatManager::update_created_public_channels(Channel *c, ChannelId channel_id) {
  for (auto type :
       {PublicDialogType::HasUsername, PublicDialogType::IsLocationBased, PublicDialogType::ForPersonalDialog}) {
    auto index = static_cast<int32>(type);
    if (!created_public_channels_inited_[index]) {
      continue;
    }
    bool was_changed = false;
    if (!is_suitable_created_public_channel(type, c)) {
      was_changed = td::remove(created_public_channels_[index], channel_id);
    } else {
      if (!td::contains(created_public_channels_[index], channel_id)) {
        created_public_channels_[index].push_back(channel_id);
        was_changed = true;
      }
    }
    if (was_changed) {
      save_created_public_channels(type);

      reload_created_public_dialogs(type, Promise<td_api::object_ptr<td_api::chats>>());
    }
  }
}

void ChatManager::on_get_created_public_channels(PublicDialogType type,
                                                 vector<tl_object_ptr<telegram_api::Chat>> &&chats) {
  auto index = static_cast<int32>(type);
  auto channel_ids = get_channel_ids(std::move(chats), "on_get_created_public_channels");
  if (created_public_channels_inited_[index] && created_public_channels_[index] == channel_ids) {
    return;
  }
  created_public_channels_[index].clear();
  for (auto channel_id : channel_ids) {
    td_->dialog_manager_->force_create_dialog(DialogId(channel_id), "on_get_created_public_channels");
    if (is_suitable_created_public_channel(type, get_channel(channel_id))) {
      created_public_channels_[index].push_back(channel_id);
    }
  }
  created_public_channels_inited_[index] = true;

  save_created_public_channels(type);
}

void ChatManager::save_created_public_channels(PublicDialogType type) {
  auto index = static_cast<int32>(type);
  CHECK(created_public_channels_inited_[index]);
  if (G()->use_message_database()) {
    G()->td_db()->get_binlog_pmc()->set(
        PSTRING() << "public_channels" << index,
        implode(
            transform(created_public_channels_[index], [](auto channel_id) { return PSTRING() << channel_id.get(); }),
            ','));
  }
}

void ChatManager::check_created_public_dialogs_limit(PublicDialogType type, Promise<Unit> &&promise) {
  td_->create_handler<GetCreatedPublicChannelsQuery>(std::move(promise))->send(type, true);
}

bool ChatManager::are_created_public_broadcasts_inited() const {
  return created_public_channels_inited_[2];
}

const vector<ChannelId> &ChatManager::get_created_public_broadcasts() const {
  return created_public_channels_[2];
}

vector<DialogId> ChatManager::get_dialogs_for_discussion(Promise<Unit> &&promise) {
  if (dialogs_for_discussion_inited_) {
    promise.set_value(Unit());
    return transform(dialogs_for_discussion_, [&](DialogId dialog_id) {
      td_->dialog_manager_->force_create_dialog(dialog_id, "get_dialogs_for_discussion");
      return dialog_id;
    });
  }

  td_->create_handler<GetGroupsForDiscussionQuery>(std::move(promise))->send();
  return {};
}

void ChatManager::on_get_dialogs_for_discussion(vector<tl_object_ptr<telegram_api::Chat>> &&chats) {
  dialogs_for_discussion_inited_ = true;
  dialogs_for_discussion_ = get_dialog_ids(std::move(chats), "on_get_dialogs_for_discussion");
}

void ChatManager::update_dialogs_for_discussion(DialogId dialog_id, bool is_suitable) {
  if (!dialogs_for_discussion_inited_) {
    return;
  }

  if (is_suitable) {
    if (!td::contains(dialogs_for_discussion_, dialog_id)) {
      LOG(DEBUG) << "Add " << dialog_id << " to list of suitable discussion chats";
      dialogs_for_discussion_.insert(dialogs_for_discussion_.begin(), dialog_id);
    }
  } else {
    if (td::remove(dialogs_for_discussion_, dialog_id)) {
      LOG(DEBUG) << "Remove " << dialog_id << " from list of suitable discussion chats";
    }
  }
}

vector<DialogId> ChatManager::get_inactive_channels(Promise<Unit> &&promise) {
  if (inactive_channel_ids_inited_) {
    promise.set_value(Unit());
    return transform(inactive_channel_ids_, [&](ChannelId channel_id) { return DialogId(channel_id); });
  }

  td_->create_handler<GetInactiveChannelsQuery>(std::move(promise))->send();
  return {};
}

void ChatManager::on_get_inactive_channels(vector<tl_object_ptr<telegram_api::Chat>> &&chats, Promise<Unit> &&promise) {
  auto channel_ids = get_channel_ids(std::move(chats), "on_get_inactive_channels");

  MultiPromiseActorSafe mpas{"GetInactiveChannelsMultiPromiseActor"};
  mpas.add_promise(
      PromiseCreator::lambda([actor_id = actor_id(this), channel_ids, promise = std::move(promise)](Unit) mutable {
        send_closure(actor_id, &ChatManager::on_create_inactive_channels, std::move(channel_ids), std::move(promise));
      }));
  mpas.set_ignore_errors(true);
  auto lock_promise = mpas.get_promise();

  for (auto channel_id : channel_ids) {
    td_->messages_manager_->create_dialog(DialogId(channel_id), false, mpas.get_promise());
  }

  lock_promise.set_value(Unit());
}

void ChatManager::on_create_inactive_channels(vector<ChannelId> &&channel_ids, Promise<Unit> &&promise) {
  inactive_channel_ids_inited_ = true;
  inactive_channel_ids_ = std::move(channel_ids);
  promise.set_value(Unit());
}

void ChatManager::remove_inactive_channel(ChannelId channel_id) {
  if (inactive_channel_ids_inited_ && td::remove(inactive_channel_ids_, channel_id)) {
    LOG(DEBUG) << "Remove " << channel_id << " from list of inactive channels";
  }
}

void ChatManager::register_message_channels(MessageFullId message_full_id, vector<ChannelId> channel_ids) {
  auto dialog_id = message_full_id.get_dialog_id();
  CHECK(dialog_id.get_type() == DialogType::Channel);
  if (!have_channel(dialog_id.get_channel_id())) {
    return;
  }
  for (auto channel_id : channel_ids) {
    CHECK(channel_id.is_valid());
    if (!have_channel(channel_id)) {
      channel_messages_[channel_id].insert(message_full_id);

      // get info about the channel
      get_channel_queries_.add_query(channel_id.get(), Promise<Unit>(), "register_message_channels");
    }
  }
}

void ChatManager::unregister_message_channels(MessageFullId message_full_id, vector<ChannelId> channel_ids) {
  if (channel_messages_.empty()) {
    // fast path
    return;
  }
  for (auto channel_id : channel_ids) {
    auto it = channel_messages_.find(channel_id);
    if (it != channel_messages_.end()) {
      it->second.erase(message_full_id);
      if (it->second.empty()) {
        channel_messages_.erase(it);
      }
    }
  }
}

ChatId ChatManager::get_chat_id(const tl_object_ptr<telegram_api::Chat> &chat) {
  CHECK(chat != nullptr);
  switch (chat->get_id()) {
    case telegram_api::chatEmpty::ID:
      return ChatId(static_cast<const telegram_api::chatEmpty *>(chat.get())->id_);
    case telegram_api::chat::ID:
      return ChatId(static_cast<const telegram_api::chat *>(chat.get())->id_);
    case telegram_api::chatForbidden::ID:
      return ChatId(static_cast<const telegram_api::chatForbidden *>(chat.get())->id_);
    default:
      return ChatId();
  }
}

ChannelId ChatManager::get_channel_id(const tl_object_ptr<telegram_api::Chat> &chat) {
  CHECK(chat != nullptr);
  switch (chat->get_id()) {
    case telegram_api::channel::ID:
      return ChannelId(static_cast<const telegram_api::channel *>(chat.get())->id_);
    case telegram_api::channelForbidden::ID:
      return ChannelId(static_cast<const telegram_api::channelForbidden *>(chat.get())->id_);
    default:
      return ChannelId();
  }
}

DialogId ChatManager::get_dialog_id(const tl_object_ptr<telegram_api::Chat> &chat) {
  auto channel_id = get_channel_id(chat);
  if (channel_id.is_valid()) {
    return DialogId(channel_id);
  }
  return DialogId(get_chat_id(chat));
}

class ChatManager::ChatLogEvent {
 public:
  ChatId chat_id;
  const Chat *c_in = nullptr;
  unique_ptr<Chat> c_out;

  ChatLogEvent() = default;

  ChatLogEvent(ChatId chat_id, const Chat *c) : chat_id(chat_id), c_in(c) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(chat_id, storer);
    td::store(*c_in, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(chat_id, parser);
    td::parse(c_out, parser);
  }
};

void ChatManager::save_chat(Chat *c, ChatId chat_id, bool from_binlog) {
  if (!G()->use_chat_info_database()) {
    return;
  }
  CHECK(c != nullptr);
  if (!c->is_saved) {
    if (!from_binlog) {
      auto log_event = ChatLogEvent(chat_id, c);
      auto storer = get_log_event_storer(log_event);
      if (c->log_event_id == 0) {
        c->log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::Chats, storer);
      } else {
        binlog_rewrite(G()->td_db()->get_binlog(), c->log_event_id, LogEvent::HandlerType::Chats, storer);
      }
    }

    save_chat_to_database(c, chat_id);
    return;
  }
}

void ChatManager::on_binlog_chat_event(BinlogEvent &&event) {
  if (!G()->use_chat_info_database()) {
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  ChatLogEvent log_event;
  if (log_event_parse(log_event, event.get_data()).is_error()) {
    LOG(ERROR) << "Failed to load a basic group from binlog";
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  auto chat_id = log_event.chat_id;
  if (have_chat(chat_id) || !chat_id.is_valid()) {
    LOG(ERROR) << "Skip adding already added " << chat_id;
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  LOG(INFO) << "Add " << chat_id << " from binlog";
  chats_.set(chat_id, std::move(log_event.c_out));

  Chat *c = get_chat(chat_id);
  CHECK(c != nullptr);
  c->log_event_id = event.id_;

  update_chat(c, chat_id, true, false);
}

string ChatManager::get_chat_database_key(ChatId chat_id) {
  return PSTRING() << "gr" << chat_id.get();
}

string ChatManager::get_chat_database_value(const Chat *c) {
  return log_event_store(*c).as_slice().str();
}

void ChatManager::save_chat_to_database(Chat *c, ChatId chat_id) {
  CHECK(c != nullptr);
  if (c->is_being_saved) {
    return;
  }
  if (loaded_from_database_chats_.count(chat_id)) {
    save_chat_to_database_impl(c, chat_id, get_chat_database_value(c));
    return;
  }
  if (load_chat_from_database_queries_.count(chat_id) != 0) {
    return;
  }

  load_chat_from_database_impl(chat_id, Auto());
}

void ChatManager::save_chat_to_database_impl(Chat *c, ChatId chat_id, string value) {
  CHECK(c != nullptr);
  CHECK(load_chat_from_database_queries_.count(chat_id) == 0);
  CHECK(!c->is_being_saved);
  c->is_being_saved = true;
  c->is_saved = true;
  LOG(INFO) << "Trying to save to database " << chat_id;
  G()->td_db()->get_sqlite_pmc()->set(
      get_chat_database_key(chat_id), std::move(value), PromiseCreator::lambda([chat_id](Result<> result) {
        send_closure(G()->chat_manager(), &ChatManager::on_save_chat_to_database, chat_id, result.is_ok());
      }));
}

void ChatManager::on_save_chat_to_database(ChatId chat_id, bool success) {
  if (G()->close_flag()) {
    return;
  }

  Chat *c = get_chat(chat_id);
  CHECK(c != nullptr);
  CHECK(c->is_being_saved);
  CHECK(load_chat_from_database_queries_.count(chat_id) == 0);
  c->is_being_saved = false;

  if (!success) {
    LOG(ERROR) << "Failed to save " << chat_id << " to database";
    c->is_saved = false;
  } else {
    LOG(INFO) << "Successfully saved " << chat_id << " to database";
  }
  if (c->is_saved) {
    if (c->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), c->log_event_id);
      c->log_event_id = 0;
    }
  } else {
    save_chat(c, chat_id, c->log_event_id != 0);
  }
}

void ChatManager::load_chat_from_database(Chat *c, ChatId chat_id, Promise<Unit> promise) {
  if (loaded_from_database_chats_.count(chat_id)) {
    promise.set_value(Unit());
    return;
  }

  CHECK(c == nullptr || !c->is_being_saved);
  load_chat_from_database_impl(chat_id, std::move(promise));
}

void ChatManager::load_chat_from_database_impl(ChatId chat_id, Promise<Unit> promise) {
  LOG(INFO) << "Load " << chat_id << " from database";
  auto &load_chat_queries = load_chat_from_database_queries_[chat_id];
  load_chat_queries.push_back(std::move(promise));
  if (load_chat_queries.size() == 1u) {
    G()->td_db()->get_sqlite_pmc()->get(get_chat_database_key(chat_id), PromiseCreator::lambda([chat_id](string value) {
                                          send_closure(G()->chat_manager(), &ChatManager::on_load_chat_from_database,
                                                       chat_id, std::move(value), false);
                                        }));
  }
}

void ChatManager::on_load_chat_from_database(ChatId chat_id, string value, bool force) {
  if (G()->close_flag() && !force) {
    // the chat is in Binlog and will be saved after restart
    return;
  }

  CHECK(chat_id.is_valid());
  if (!loaded_from_database_chats_.insert(chat_id).second) {
    return;
  }

  auto it = load_chat_from_database_queries_.find(chat_id);
  vector<Promise<Unit>> promises;
  if (it != load_chat_from_database_queries_.end()) {
    promises = std::move(it->second);
    CHECK(!promises.empty());
    load_chat_from_database_queries_.erase(it);
  }

  LOG(INFO) << "Successfully loaded " << chat_id << " of size " << value.size() << " from database";
  //  G()->td_db()->get_sqlite_pmc()->erase(get_chat_database_key(chat_id), Auto());
  //  return;

  Chat *c = get_chat(chat_id);
  if (c == nullptr) {
    if (!value.empty()) {
      c = add_chat(chat_id);

      if (log_event_parse(*c, value).is_error()) {
        LOG(ERROR) << "Failed to load " << chat_id << " from database";
        chats_.erase(chat_id);
      } else {
        c->is_saved = true;
        update_chat(c, chat_id, true, true);
      }
    }
  } else {
    CHECK(!c->is_saved);  // chat can't be saved before load completes
    CHECK(!c->is_being_saved);
    auto new_value = get_chat_database_value(c);
    if (value != new_value) {
      save_chat_to_database_impl(c, chat_id, std::move(new_value));
    } else if (c->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), c->log_event_id);
      c->log_event_id = 0;
    }
  }

  if (c != nullptr && c->migrated_to_channel_id.is_valid() &&
      !have_channel_force(c->migrated_to_channel_id, "on_load_chat_from_database")) {
    LOG(ERROR) << "Can't find " << c->migrated_to_channel_id << " from " << chat_id;
  }

  set_promises(promises);
}

bool ChatManager::have_chat_force(ChatId chat_id, const char *source) {
  return get_chat_force(chat_id, source) != nullptr;
}

ChatManager::Chat *ChatManager::get_chat_force(ChatId chat_id, const char *source) {
  if (!chat_id.is_valid()) {
    return nullptr;
  }

  Chat *c = get_chat(chat_id);
  if (c != nullptr) {
    if (c->migrated_to_channel_id.is_valid() && !have_channel_force(c->migrated_to_channel_id, source)) {
      LOG(ERROR) << "Can't find " << c->migrated_to_channel_id << " from " << chat_id << " from " << source;
    }

    return c;
  }
  if (!G()->use_chat_info_database()) {
    return nullptr;
  }
  if (loaded_from_database_chats_.count(chat_id)) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load " << chat_id << " from database from " << source;
  on_load_chat_from_database(chat_id, G()->td_db()->get_sqlite_sync_pmc()->get(get_chat_database_key(chat_id)), true);
  return get_chat(chat_id);
}

class ChatManager::ChannelLogEvent {
 public:
  ChannelId channel_id;
  const Channel *c_in = nullptr;
  unique_ptr<Channel> c_out;

  ChannelLogEvent() = default;

  ChannelLogEvent(ChannelId channel_id, const Channel *c) : channel_id(channel_id), c_in(c) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(channel_id, storer);
    td::store(*c_in, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(channel_id, parser);
    td::parse(c_out, parser);
  }
};

void ChatManager::save_channel(Channel *c, ChannelId channel_id, bool from_binlog) {
  if (!G()->use_chat_info_database()) {
    return;
  }
  CHECK(c != nullptr);
  if (!c->is_saved) {
    if (!from_binlog) {
      auto log_event = ChannelLogEvent(channel_id, c);
      auto storer = get_log_event_storer(log_event);
      if (c->log_event_id == 0) {
        c->log_event_id = binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::Channels, storer);
      } else {
        binlog_rewrite(G()->td_db()->get_binlog(), c->log_event_id, LogEvent::HandlerType::Channels, storer);
      }
    }

    save_channel_to_database(c, channel_id);
    return;
  }
}

void ChatManager::on_binlog_channel_event(BinlogEvent &&event) {
  if (!G()->use_chat_info_database()) {
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  ChannelLogEvent log_event;
  if (log_event_parse(log_event, event.get_data()).is_error()) {
    LOG(ERROR) << "Failed to load a supergroup from binlog";
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  auto channel_id = log_event.channel_id;
  if (have_channel(channel_id) || !channel_id.is_valid()) {
    LOG(ERROR) << "Skip adding already added " << channel_id;
    binlog_erase(G()->td_db()->get_binlog(), event.id_);
    return;
  }

  LOG(INFO) << "Add " << channel_id << " from binlog";
  channels_.set(channel_id, std::move(log_event.c_out));

  Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);
  c->log_event_id = event.id_;

  update_channel(c, channel_id, true, false);
}

string ChatManager::get_channel_database_key(ChannelId channel_id) {
  return PSTRING() << "ch" << channel_id.get();
}

string ChatManager::get_channel_database_value(const Channel *c) {
  return log_event_store(*c).as_slice().str();
}

void ChatManager::save_channel_to_database(Channel *c, ChannelId channel_id) {
  CHECK(c != nullptr);
  if (c->is_being_saved) {
    return;
  }
  if (loaded_from_database_channels_.count(channel_id)) {
    save_channel_to_database_impl(c, channel_id, get_channel_database_value(c));
    return;
  }
  if (load_channel_from_database_queries_.count(channel_id) != 0) {
    return;
  }

  load_channel_from_database_impl(channel_id, Auto());
}

void ChatManager::save_channel_to_database_impl(Channel *c, ChannelId channel_id, string value) {
  CHECK(c != nullptr);
  CHECK(load_channel_from_database_queries_.count(channel_id) == 0);
  CHECK(!c->is_being_saved);
  c->is_being_saved = true;
  c->is_saved = true;
  LOG(INFO) << "Trying to save to database " << channel_id;
  G()->td_db()->get_sqlite_pmc()->set(
      get_channel_database_key(channel_id), std::move(value), PromiseCreator::lambda([channel_id](Result<> result) {
        send_closure(G()->chat_manager(), &ChatManager::on_save_channel_to_database, channel_id, result.is_ok());
      }));
}

void ChatManager::on_save_channel_to_database(ChannelId channel_id, bool success) {
  if (G()->close_flag()) {
    return;
  }

  Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);
  CHECK(c->is_being_saved);
  CHECK(load_channel_from_database_queries_.count(channel_id) == 0);
  c->is_being_saved = false;

  if (!success) {
    LOG(ERROR) << "Failed to save " << channel_id << " to database";
    c->is_saved = false;
  } else {
    LOG(INFO) << "Successfully saved " << channel_id << " to database";
  }
  if (c->is_saved) {
    if (c->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), c->log_event_id);
      c->log_event_id = 0;
    }
  } else {
    save_channel(c, channel_id, c->log_event_id != 0);
  }
}

void ChatManager::load_channel_from_database(Channel *c, ChannelId channel_id, Promise<Unit> promise) {
  if (loaded_from_database_channels_.count(channel_id)) {
    promise.set_value(Unit());
    return;
  }

  CHECK(c == nullptr || !c->is_being_saved);
  load_channel_from_database_impl(channel_id, std::move(promise));
}

void ChatManager::load_channel_from_database_impl(ChannelId channel_id, Promise<Unit> promise) {
  LOG(INFO) << "Load " << channel_id << " from database";
  auto &load_channel_queries = load_channel_from_database_queries_[channel_id];
  load_channel_queries.push_back(std::move(promise));
  if (load_channel_queries.size() == 1u) {
    G()->td_db()->get_sqlite_pmc()->get(get_channel_database_key(channel_id),
                                        PromiseCreator::lambda([channel_id](string value) {
                                          send_closure(G()->chat_manager(), &ChatManager::on_load_channel_from_database,
                                                       channel_id, std::move(value), false);
                                        }));
  }
}

void ChatManager::on_load_channel_from_database(ChannelId channel_id, string value, bool force) {
  if (G()->close_flag() && !force) {
    // the channel is in Binlog and will be saved after restart
    return;
  }

  CHECK(channel_id.is_valid());
  if (!loaded_from_database_channels_.insert(channel_id).second) {
    return;
  }

  auto it = load_channel_from_database_queries_.find(channel_id);
  vector<Promise<Unit>> promises;
  if (it != load_channel_from_database_queries_.end()) {
    promises = std::move(it->second);
    CHECK(!promises.empty());
    load_channel_from_database_queries_.erase(it);
  }

  LOG(INFO) << "Successfully loaded " << channel_id << " of size " << value.size() << " from database";
  //  G()->td_db()->get_sqlite_pmc()->erase(get_channel_database_key(channel_id), Auto());
  //  return;

  Channel *c = get_channel(channel_id);
  if (c == nullptr) {
    if (!value.empty()) {
      c = add_channel(channel_id, "on_load_channel_from_database");

      if (log_event_parse(*c, value).is_error()) {
        LOG(ERROR) << "Failed to load " << channel_id << " from database";
        channels_.erase(channel_id);
      } else {
        c->is_saved = true;
        update_channel(c, channel_id, true, true);
      }
    }
  } else {
    CHECK(!c->is_saved);  // channel can't be saved before load completes
    CHECK(!c->is_being_saved);
    bool is_new = false;
    if (!value.empty()) {
      Channel temp_c;
      if (log_event_parse(temp_c, value).is_ok()) {
        if (c->participant_count == 0 && temp_c.participant_count != 0) {
          c->participant_count = temp_c.participant_count;
          CHECK(c->is_update_supergroup_sent);
          send_closure(G()->td(), &Td::send_update, get_update_supergroup_object(channel_id, c));
        }

        c->status.update_restrictions();
        temp_c.status.update_restrictions();
        if (temp_c.status != c->status) {
          on_channel_status_changed(c, channel_id, temp_c.status, c->status);
          CHECK(!c->is_being_saved);
        }

        if (temp_c.usernames != c->usernames) {
          on_channel_usernames_changed(c, channel_id, temp_c.usernames, c->usernames);
          CHECK(!c->is_being_saved);
        }
      } else {
        is_new = true;
      }
    } else {
      is_new = true;
    }
    auto new_value = get_channel_database_value(c);
    if (value != new_value) {
      save_channel_to_database_impl(c, channel_id, std::move(new_value));
    } else if (c->log_event_id != 0) {
      binlog_erase(G()->td_db()->get_binlog(), c->log_event_id);
      c->log_event_id = 0;
    }
    if (is_new && !c->status.is_banned()) {
      c->status.update_restrictions();
      on_channel_status_changed(c, channel_id, DialogParticipantStatus::Banned(0), c->status);
    }
  }

  set_promises(promises);
}

bool ChatManager::have_channel_force(ChannelId channel_id, const char *source) {
  return get_channel_force(channel_id, source) != nullptr;
}

ChatManager::Channel *ChatManager::get_channel_force(ChannelId channel_id, const char *source) {
  if (!channel_id.is_valid()) {
    return nullptr;
  }

  Channel *c = get_channel(channel_id);
  if (c != nullptr) {
    return c;
  }
  if (!G()->use_chat_info_database()) {
    return nullptr;
  }
  if (loaded_from_database_channels_.count(channel_id)) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load " << channel_id << " from database from " << source;
  on_load_channel_from_database(channel_id,
                                G()->td_db()->get_sqlite_sync_pmc()->get(get_channel_database_key(channel_id)), true);
  return get_channel(channel_id);
}

void ChatManager::save_chat_full(const ChatFull *chat_full, ChatId chat_id) {
  if (!G()->use_chat_info_database()) {
    return;
  }

  LOG(INFO) << "Trying to save to database full " << chat_id;
  CHECK(chat_full != nullptr);
  G()->td_db()->get_sqlite_pmc()->set(get_chat_full_database_key(chat_id), get_chat_full_database_value(chat_full),
                                      Auto());
}

string ChatManager::get_chat_full_database_key(ChatId chat_id) {
  return PSTRING() << "grf" << chat_id.get();
}

string ChatManager::get_chat_full_database_value(const ChatFull *chat_full) {
  return log_event_store(*chat_full).as_slice().str();
}

void ChatManager::on_load_chat_full_from_database(ChatId chat_id, string value) {
  LOG(INFO) << "Successfully loaded full " << chat_id << " of size " << value.size() << " from database";
  //  G()->td_db()->get_sqlite_pmc()->erase(get_chat_full_database_key(chat_id), Auto());
  //  return;

  if (get_chat_full(chat_id) != nullptr || value.empty()) {
    return;
  }

  ChatFull *chat_full = add_chat_full(chat_id);
  auto status = log_event_parse(*chat_full, value);
  if (status.is_error()) {
    // can't happen unless database is broken
    LOG(ERROR) << "Repair broken full " << chat_id << ' ' << format::as_hex_dump<4>(Slice(value));

    // just clean all known data about the chat and pretend that there was nothing in the database
    chats_full_.erase(chat_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_chat_full_database_key(chat_id), Auto());
    return;
  }

  Dependencies dependencies;
  dependencies.add(chat_id);
  dependencies.add(chat_full->creator_user_id);
  for (auto &participant : chat_full->participants) {
    dependencies.add_message_sender_dependencies(participant.dialog_id_);
    dependencies.add(participant.inviter_user_id_);
  }
  dependencies.add(chat_full->invite_link.get_creator_user_id());
  if (!dependencies.resolve_force(td_, "on_load_chat_full_from_database")) {
    chats_full_.erase(chat_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_chat_full_database_key(chat_id), Auto());
    return;
  }

  Chat *c = get_chat(chat_id);
  CHECK(c != nullptr);

  bool need_invite_link = c->is_active && c->status.can_manage_invite_links();
  bool have_invite_link = chat_full->invite_link.is_valid();
  if (need_invite_link != have_invite_link) {
    if (need_invite_link) {
      // ignore ChatFull without invite link
      chats_full_.erase(chat_id);
      return;
    } else {
      chat_full->invite_link = DialogInviteLink();
    }
  }

  if (!is_same_dialog_photo(td_->file_manager_.get(), DialogId(chat_id), chat_full->photo, c->photo, false)) {
    chat_full->photo = Photo();
    if (c->photo.small_file_id.is_valid()) {
      reload_chat_full(chat_id, Auto(), "on_load_chat_full_from_database");
    }
  }

  auto photo = std::move(chat_full->photo);
  chat_full->photo = Photo();
  on_update_chat_full_photo(chat_full, chat_id, std::move(photo));

  td_->group_call_manager_->on_update_dialog_about(DialogId(chat_id), chat_full->description, false);

  chat_full->is_update_chat_full_sent = true;
  update_chat_full(chat_full, chat_id, "on_load_chat_full_from_database", true);
}

ChatManager::ChatFull *ChatManager::get_chat_full_force(ChatId chat_id, const char *source) {
  if (!have_chat_force(chat_id, source)) {
    return nullptr;
  }

  ChatFull *chat_full = get_chat_full(chat_id);
  if (chat_full != nullptr) {
    return chat_full;
  }
  if (!G()->use_chat_info_database()) {
    return nullptr;
  }
  if (!unavailable_chat_fulls_.insert(chat_id).second) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load full " << chat_id << " from database from " << source;
  on_load_chat_full_from_database(chat_id,
                                  G()->td_db()->get_sqlite_sync_pmc()->get(get_chat_full_database_key(chat_id)));
  return get_chat_full(chat_id);
}

void ChatManager::save_channel_full(const ChannelFull *channel_full, ChannelId channel_id) {
  if (!G()->use_chat_info_database()) {
    return;
  }

  LOG(INFO) << "Trying to save to database full " << channel_id;
  CHECK(channel_full != nullptr);
  G()->td_db()->get_sqlite_pmc()->set(get_channel_full_database_key(channel_id),
                                      get_channel_full_database_value(channel_full), Auto());
}

string ChatManager::get_channel_full_database_key(ChannelId channel_id) {
  return PSTRING() << "chf" << channel_id.get();
}

string ChatManager::get_channel_full_database_value(const ChannelFull *channel_full) {
  return log_event_store(*channel_full).as_slice().str();
}

void ChatManager::on_load_channel_full_from_database(ChannelId channel_id, string value, const char *source) {
  LOG(INFO) << "Successfully loaded full " << channel_id << " of size " << value.size() << " from database from "
            << source;
  //  G()->td_db()->get_sqlite_pmc()->erase(get_channel_full_database_key(channel_id), Auto());
  //  return;

  if (get_channel_full(channel_id, true, "on_load_channel_full_from_database") != nullptr || value.empty()) {
    return;
  }

  ChannelFull *channel_full = add_channel_full(channel_id);
  auto status = log_event_parse(*channel_full, value);
  if (status.is_error()) {
    // can't happen unless database is broken
    LOG(ERROR) << "Repair broken full " << channel_id << ' ' << format::as_hex_dump<4>(Slice(value));

    // just clean all known data about the channel and pretend that there was nothing in the database
    channels_full_.erase(channel_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_channel_full_database_key(channel_id), Auto());
    return;
  }

  Dependencies dependencies;
  dependencies.add(channel_id);
  // must not depend on the linked_dialog_id itself, because message database can be disabled
  // the Dialog will be forcely created in update_channel_full
  dependencies.add_dialog_dependencies(DialogId(channel_full->linked_channel_id));
  dependencies.add(channel_full->migrated_from_chat_id);
  for (auto bot_user_id : channel_full->bot_user_ids) {
    dependencies.add(bot_user_id);
  }
  if (channel_full->bot_verification != nullptr) {
    channel_full->bot_verification->add_dependencies(dependencies);
  }
  dependencies.add(channel_full->invite_link.get_creator_user_id());
  if (!dependencies.resolve_force(td_, source)) {
    channels_full_.erase(channel_id);
    G()->td_db()->get_sqlite_pmc()->erase(get_channel_full_database_key(channel_id), Auto());
    return;
  }

  Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);

  bool need_invite_link = c->status.can_manage_invite_links();
  bool have_invite_link = channel_full->invite_link.is_valid();
  if (need_invite_link != have_invite_link) {
    if (need_invite_link) {
      // ignore ChannelFull without invite link
      channels_full_.erase(channel_id);
      return;
    } else {
      channel_full->invite_link = DialogInviteLink();
    }
  }

  if (!is_same_dialog_photo(td_->file_manager_.get(), DialogId(channel_id), channel_full->photo, c->photo, false)) {
    channel_full->photo = Photo();
    if (c->photo.small_file_id.is_valid()) {
      channel_full->expires_at = 0.0;
    }
  }
  auto photo = std::move(channel_full->photo);
  channel_full->photo = Photo();
  on_update_channel_full_photo(channel_full, channel_id, std::move(photo));

  if (channel_full->participant_count < channel_full->administrator_count) {
    channel_full->participant_count = channel_full->administrator_count;
  }
  if (c->participant_count != 0 && c->participant_count != channel_full->participant_count) {
    channel_full->participant_count = c->participant_count;

    if (channel_full->participant_count < channel_full->administrator_count) {
      channel_full->participant_count = channel_full->administrator_count;
      channel_full->expires_at = 0.0;

      c->participant_count = channel_full->participant_count;
      c->is_changed = true;
    }
  }
  if (c->can_be_deleted != channel_full->can_be_deleted) {
    c->can_be_deleted = channel_full->can_be_deleted;
    c->need_save_to_database = true;
  }

  if (invalidated_channels_full_.erase(channel_id) > 0 ||
      (!c->is_slow_mode_enabled && channel_full->slow_mode_delay != 0)) {
    do_invalidate_channel_full(channel_full, channel_id, !c->is_slow_mode_enabled);
  }

  td_->group_call_manager_->on_update_dialog_about(DialogId(channel_id), channel_full->description, false);

  send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(channel_id),
                     channel_full->bot_user_ids, true);

  update_channel(c, channel_id);

  channel_full->is_update_channel_full_sent = true;
  update_channel_full(channel_full, channel_id, "on_load_channel_full_from_database", true);

  if (channel_full->expires_at == 0.0) {
    load_channel_full(channel_id, true, Auto(), "on_load_channel_full_from_database");
  }
}

ChatManager::ChannelFull *ChatManager::get_channel_full_force(ChannelId channel_id, bool only_local,
                                                              const char *source) {
  if (!have_channel_force(channel_id, source)) {
    return nullptr;
  }

  ChannelFull *channel_full = get_channel_full(channel_id, only_local, source);
  if (channel_full != nullptr) {
    return channel_full;
  }
  if (!G()->use_chat_info_database()) {
    return nullptr;
  }
  if (!unavailable_channel_fulls_.insert(channel_id).second) {
    return nullptr;
  }

  LOG(INFO) << "Trying to load full " << channel_id << " from database from " << source;
  on_load_channel_full_from_database(
      channel_id, G()->td_db()->get_sqlite_sync_pmc()->get(get_channel_full_database_key(channel_id)), source);
  return get_channel_full(channel_id, only_local, source);
}

void ChatManager::update_chat(Chat *c, ChatId chat_id, bool from_binlog, bool from_database) {
  CHECK(c != nullptr);

  if (c->is_being_updated) {
    LOG(ERROR) << "Detected recursive update of " << chat_id;
  }
  c->is_being_updated = true;
  SCOPE_EXIT {
    c->is_being_updated = false;
  };

  bool need_update_chat_full = false;
  if (c->is_photo_changed) {
    td_->messages_manager_->on_dialog_photo_updated(DialogId(chat_id));
    c->is_photo_changed = false;

    auto chat_full = get_chat_full(chat_id);  // must not load ChatFull
    if (chat_full != nullptr &&
        !is_same_dialog_photo(td_->file_manager_.get(), DialogId(chat_id), chat_full->photo, c->photo, false)) {
      on_update_chat_full_photo(chat_full, chat_id, Photo());
      if (chat_full->is_update_chat_full_sent) {
        need_update_chat_full = true;
      }
      if (c->photo.small_file_id.is_valid()) {
        reload_chat_full(chat_id, Auto(), "update_chat");
      }
    }
  }
  if (c->is_title_changed) {
    td_->messages_manager_->on_dialog_title_updated(DialogId(chat_id));
    c->is_title_changed = false;
  }
  if (c->is_default_permissions_changed) {
    td_->messages_manager_->on_dialog_default_permissions_updated(DialogId(chat_id));
    c->is_default_permissions_changed = false;
  }
  if (c->is_is_active_changed) {
    update_dialogs_for_discussion(DialogId(chat_id), c->is_active && c->status.is_creator());
    c->is_is_active_changed = false;
    td_->messages_manager_->on_dialog_access_updated(DialogId(chat_id));
  }
  if (c->is_status_changed) {
    if (!c->status.can_manage_invite_links()) {
      td_->messages_manager_->drop_dialog_pending_join_requests(DialogId(chat_id));
    }
    if (!from_database) {
      // if the chat is empty, this can add it to a chat list or remove it from a chat list
      send_closure_later(G()->messages_manager(), &MessagesManager::try_update_dialog_pos, DialogId(chat_id));

      if (c->is_update_basic_group_sent) {
        // reload the chat to repair its status if it is changed back after receiving of outdated data
        create_actor<SleepActor>(
            "ReloadChatSleepActor", 1.0, PromiseCreator::lambda([actor_id = actor_id(this), chat_id](Unit) {
              send_closure(actor_id, &ChatManager::reload_chat, chat_id, Promise<Unit>(), "ReloadChatSleepActor");
            }))
            .release();
      }
    }
    td_->messages_manager_->on_dialog_access_updated(DialogId(chat_id));
    c->is_status_changed = false;
  }
  if (c->is_noforwards_changed) {
    td_->messages_manager_->on_dialog_has_protected_content_updated(DialogId(chat_id));
    c->is_noforwards_changed = false;
  }

  if (need_update_chat_full) {
    auto chat_full = get_chat_full(chat_id);
    CHECK(chat_full != nullptr);
    update_chat_full(chat_full, chat_id, "update_chat");
  }

  LOG(DEBUG) << "Update " << chat_id << ": need_save_to_database = " << c->need_save_to_database
             << ", is_changed = " << c->is_changed;
  c->need_save_to_database |= c->is_changed;
  if (c->need_save_to_database) {
    if (!from_database) {
      c->is_saved = false;
    }
    c->need_save_to_database = false;
  }
  if (c->is_changed) {
    send_closure(G()->td(), &Td::send_update, get_update_basic_group_object(chat_id, c));
    c->is_changed = false;
    c->is_update_basic_group_sent = true;
  }

  if (!from_database) {
    save_chat(c, chat_id, from_binlog);
  }

  if (c->cache_version != Chat::CACHE_VERSION && !c->is_repaired && have_input_peer_chat(c, AccessRights::Read) &&
      !G()->close_flag()) {
    c->is_repaired = true;

    LOG(INFO) << "Repairing cache of " << chat_id;
    reload_chat(chat_id, Promise<Unit>(), "update_chat");
  }
}

void ChatManager::update_channel(Channel *c, ChannelId channel_id, bool from_binlog, bool from_database) {
  CHECK(c != nullptr);

  if (c->is_being_updated) {
    LOG(ERROR) << "Detected recursive update of " << channel_id;
  }
  c->is_being_updated = true;
  SCOPE_EXIT {
    c->is_being_updated = false;
  };

  bool need_update_channel_full = false;
  if (c->is_photo_changed) {
    td_->messages_manager_->on_dialog_photo_updated(DialogId(channel_id));
    c->is_photo_changed = false;

    auto channel_full = get_channel_full(channel_id, true, "update_channel");
    if (channel_full != nullptr &&
        !is_same_dialog_photo(td_->file_manager_.get(), DialogId(channel_id), channel_full->photo, c->photo, false)) {
      on_update_channel_full_photo(channel_full, channel_id, Photo());
      if (channel_full->is_update_channel_full_sent) {
        need_update_channel_full = true;
      }
      if (c->photo.small_file_id.is_valid()) {
        if (channel_full->expires_at > 0.0) {
          channel_full->expires_at = 0.0;
          channel_full->need_save_to_database = true;
        }
        send_get_channel_full_query(channel_full, channel_id, Auto(), "update_channel");
      }
    }
  }
  if (c->is_accent_color_changed) {
    td_->messages_manager_->on_dialog_accent_colors_updated(DialogId(channel_id));
    c->is_accent_color_changed = false;
  }
  if (c->is_title_changed) {
    td_->messages_manager_->on_dialog_title_updated(DialogId(channel_id));
    c->is_title_changed = false;
  }
  if (c->is_status_changed) {
    c->status.update_restrictions();
    auto until_date = c->status.get_until_date();
    double left_time = 0;
    if (until_date > 0) {
      left_time = until_date - G()->server_time() + 2;
      if (left_time <= 0) {
        c->status.update_restrictions();
        CHECK(c->status.get_until_date() == 0);
      }
    }
    if (left_time > 0 && left_time < 366 * 86400) {
      channel_unban_timeout_.set_timeout_in(channel_id.get(), left_time);
    } else {
      channel_unban_timeout_.cancel_timeout(channel_id.get());
    }

    if (c->is_megagroup) {
      update_dialogs_for_discussion(DialogId(channel_id), c->status.is_administrator() && c->status.can_pin_messages());
    }
    if (!c->status.is_member()) {
      remove_inactive_channel(channel_id);
    }
    if (!c->status.can_manage_invite_links()) {
      td_->messages_manager_->drop_dialog_pending_join_requests(DialogId(channel_id));
    }
    if (!from_database && c->is_update_supergroup_sent) {
      // reload the channel to repair its status if it is changed back after receiving of outdated data
      create_actor<SleepActor>("ReloadChannelSleepActor", 1.0,
                               PromiseCreator::lambda([actor_id = actor_id(this), channel_id](Unit) {
                                 send_closure(actor_id, &ChatManager::reload_channel, channel_id, Promise<Unit>(),
                                              "ReloadChannelSleepActor");
                               }))
          .release();
    }
    td_->messages_manager_->on_dialog_access_updated(DialogId(channel_id));
    c->is_status_changed = false;
  }
  if (c->is_username_changed) {
    if (c->status.is_creator()) {
      update_created_public_channels(c, channel_id);
    }
    td_->messages_manager_->on_dialog_access_updated(DialogId(channel_id));
    c->is_username_changed = false;
  }
  if (c->is_default_permissions_changed) {
    td_->messages_manager_->on_dialog_default_permissions_updated(DialogId(channel_id));
    if (c->default_permissions != RestrictedRights(false, false, false, false, false, false, false, false, false, false,
                                                   false, false, false, false, false, false, false,
                                                   ChannelType::Unknown)) {
      td_->suggested_action_manager_->remove_dialog_suggested_action(
          SuggestedAction{SuggestedAction::Type::ConvertToGigagroup, DialogId(channel_id)});
    }
    c->is_default_permissions_changed = false;
  }
  if (c->is_has_location_changed) {
    if (c->status.is_creator()) {
      update_created_public_channels(c, channel_id);
    }
    td_->messages_manager_->on_dialog_access_updated(DialogId(channel_id));
    c->is_has_location_changed = false;
  }
  if (c->is_creator_changed) {
    update_created_public_channels(c, channel_id);
    c->is_creator_changed = false;
  }
  if (c->is_noforwards_changed) {
    td_->messages_manager_->on_dialog_has_protected_content_updated(DialogId(channel_id));
    c->is_noforwards_changed = false;
  }
  if (c->is_stories_hidden_changed) {
    send_closure_later(td_->story_manager_actor_, &StoryManager::on_dialog_active_stories_order_updated,
                       DialogId(channel_id), "update_channel stories_hidden");
    c->is_stories_hidden_changed = false;
  }
  auto unix_time = G()->unix_time();
  auto effective_emoji_status = EmojiStatus::get_effective_emoji_status(c->emoji_status, true, unix_time);
  if (effective_emoji_status != c->last_sent_emoji_status) {
    if (c->last_sent_emoji_status != nullptr) {
      channel_emoji_status_timeout_.cancel_timeout(channel_id.get());
    }
    c->last_sent_emoji_status = std::move(effective_emoji_status);
    if (c->last_sent_emoji_status != nullptr) {
      auto until_date = c->last_sent_emoji_status->get_until_date();
      auto left_time = until_date - unix_time;
      if (left_time >= 0 && left_time < 30 * 86400) {
        channel_emoji_status_timeout_.set_timeout_in(channel_id.get(), left_time);
      }
    }

    td_->messages_manager_->on_dialog_emoji_status_updated(DialogId(channel_id));
  }
  c->is_emoji_status_changed = false;

  if (!td_->auth_manager_->is_bot()) {
    if (c->restriction_reasons.empty()) {
      restricted_channel_ids_.erase(channel_id);
    } else {
      restricted_channel_ids_.insert(channel_id);
    }
  }

  if (from_binlog || from_database) {
    td_->dialog_manager_->on_dialog_usernames_received(DialogId(channel_id), c->usernames, true);
  }

  if (!is_channel_public(c) && !c->has_linked_channel) {
    send_closure_later(G()->messages_manager(), &MessagesManager::on_update_dialog_default_send_message_as_dialog_id,
                       DialogId(channel_id), DialogId(), false);
  }

  if (need_update_channel_full) {
    auto channel_full = get_channel_full(channel_id, true, "update_channel");
    CHECK(channel_full != nullptr);
    update_channel_full(channel_full, channel_id, "update_channel");
  }

  LOG(DEBUG) << "Update " << channel_id << ": need_save_to_database = " << c->need_save_to_database
             << ", is_changed = " << c->is_changed;
  c->need_save_to_database |= c->is_changed;
  if (c->need_save_to_database) {
    if (!from_database) {
      c->is_saved = false;
    }
    c->need_save_to_database = false;
  }
  if (c->is_changed) {
    send_closure(G()->td(), &Td::send_update, get_update_supergroup_object(channel_id, c));
    c->is_changed = false;
    c->is_update_supergroup_sent = true;
  }

  if (!from_database) {
    save_channel(c, channel_id, from_binlog);
  }

  bool have_read_access = have_input_peer_channel(c, channel_id, AccessRights::Read);
  if (c->had_read_access && !have_read_access) {
    send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_deleted, DialogId(channel_id),
                       Promise<Unit>());
  }
  c->had_read_access = have_read_access;

  if (c->cache_version != Channel::CACHE_VERSION && !c->is_repaired &&
      have_input_peer_channel(c, channel_id, AccessRights::Read) && !G()->close_flag()) {
    c->is_repaired = true;

    LOG(INFO) << "Repairing cache of " << channel_id;
    reload_channel(channel_id, Promise<Unit>(), "update_channel");
  }
}

void ChatManager::update_chat_full(ChatFull *chat_full, ChatId chat_id, const char *source, bool from_database) {
  CHECK(chat_full != nullptr);

  if (chat_full->is_being_updated) {
    LOG(ERROR) << "Detected recursive update of full " << chat_id << " from " << source;
  }
  chat_full->is_being_updated = true;
  SCOPE_EXIT {
    chat_full->is_being_updated = false;
  };

  unavailable_chat_fulls_.erase(chat_id);  // don't needed anymore

  chat_full->need_send_update |= chat_full->is_changed;
  chat_full->need_save_to_database |= chat_full->is_changed;
  chat_full->is_changed = false;
  if (chat_full->need_send_update || chat_full->need_save_to_database) {
    LOG(INFO) << "Update full " << chat_id << " from " << source;
  }
  if (chat_full->need_send_update) {
    vector<DialogAdministrator> administrators;
    vector<UserId> bot_user_ids;
    for (const auto &participant : chat_full->participants) {
      if (participant.status_.is_administrator() && participant.dialog_id_.get_type() == DialogType::User) {
        administrators.emplace_back(participant.dialog_id_.get_user_id(), participant.status_.get_rank(),
                                    participant.status_.is_creator());
      }
      if (participant.dialog_id_.get_type() == DialogType::User) {
        auto user_id = participant.dialog_id_.get_user_id();
        if (td_->user_manager_->is_user_bot(user_id)) {
          bot_user_ids.push_back(user_id);
        }
      }
    }
    td::remove_if(chat_full->bot_commands, [&bot_user_ids](const BotCommands &commands) {
      return !td::contains(bot_user_ids, commands.get_bot_user_id());
    });

    td_->dialog_participant_manager_->on_update_dialog_administrators(DialogId(chat_id), std::move(administrators),
                                                                      chat_full->version != -1, from_database);
    send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(chat_id),
                       std::move(bot_user_ids), from_database);

    {
      Chat *c = get_chat(chat_id);
      CHECK(c == nullptr || c->is_update_basic_group_sent);
    }
    if (!chat_full->is_update_chat_full_sent) {
      LOG(ERROR) << "Send partial updateBasicGroupFullInfo for " << chat_id << " from " << source;
      chat_full->is_update_chat_full_sent = true;
    }
    send_closure(
        G()->td(), &Td::send_update,
        make_tl_object<td_api::updateBasicGroupFullInfo>(get_basic_group_id_object(chat_id, "update_chat_full"),
                                                         get_basic_group_full_info_object(chat_id, chat_full)));
    chat_full->need_send_update = false;
  }
  if (chat_full->need_save_to_database) {
    if (!from_database) {
      save_chat_full(chat_full, chat_id);
    }
    chat_full->need_save_to_database = false;
  }
}

void ChatManager::update_channel_full(ChannelFull *channel_full, ChannelId channel_id, const char *source,
                                      bool from_database) {
  CHECK(channel_full != nullptr);

  if (channel_full->is_being_updated) {
    LOG(ERROR) << "Detected recursive update of full " << channel_id << " from " << source;
  }
  channel_full->is_being_updated = true;
  SCOPE_EXIT {
    channel_full->is_being_updated = false;
  };

  unavailable_channel_fulls_.erase(channel_id);  // don't needed anymore

  CHECK(channel_full->participant_count >= channel_full->administrator_count);

  if (channel_full->is_slow_mode_next_send_date_changed) {
    auto now = G()->server_time();
    if (channel_full->slow_mode_next_send_date > now + 3601) {
      channel_full->slow_mode_next_send_date = static_cast<int32>(now) + 3601;
    }
    if (channel_full->slow_mode_next_send_date <= now) {
      channel_full->slow_mode_next_send_date = 0;
    }
    if (channel_full->slow_mode_next_send_date == 0) {
      slow_mode_delay_timeout_.cancel_timeout(channel_id.get());
    } else {
      slow_mode_delay_timeout_.set_timeout_in(channel_id.get(), channel_full->slow_mode_next_send_date - now + 0.002);
    }
    channel_full->is_slow_mode_next_send_date_changed = false;
  }

  if (channel_full->need_save_to_database) {
    channel_full->is_changed |= td::remove_if(
        channel_full->bot_commands, [bot_user_ids = &channel_full->bot_user_ids](const BotCommands &commands) {
          return !td::contains(*bot_user_ids, commands.get_bot_user_id());
        });
  }

  channel_full->need_send_update |= channel_full->is_changed;
  channel_full->need_save_to_database |= channel_full->is_changed;
  channel_full->is_changed = false;
  if (channel_full->need_send_update || channel_full->need_save_to_database) {
    LOG(INFO) << "Update full " << channel_id << " from " << source;
  }
  if (channel_full->need_send_update) {
    if (channel_full->linked_channel_id.is_valid()) {
      td_->dialog_manager_->force_create_dialog(DialogId(channel_full->linked_channel_id), "update_channel_full", true);
    }

    {
      Channel *c = get_channel(channel_id);
      CHECK(c == nullptr || c->is_update_supergroup_sent);
    }
    if (!channel_full->is_update_channel_full_sent) {
      LOG(ERROR) << "Send partial updateSupergroupFullInfo for " << channel_id << " from " << source;
      channel_full->is_update_channel_full_sent = true;
    }
    send_closure(
        G()->td(), &Td::send_update,
        make_tl_object<td_api::updateSupergroupFullInfo>(get_supergroup_id_object(channel_id, "update_channel_full"),
                                                         get_supergroup_full_info_object(channel_id, channel_full)));
    channel_full->need_send_update = false;
  }
  if (channel_full->need_save_to_database) {
    if (!from_database) {
      save_channel_full(channel_full, channel_id);
    }
    channel_full->need_save_to_database = false;
  }
}

void ChatManager::on_get_chat(tl_object_ptr<telegram_api::Chat> &&chat, const char *source) {
  LOG(DEBUG) << "Receive from " << source << ' ' << to_string(chat);
  switch (chat->get_id()) {
    case telegram_api::chatEmpty::ID:
      on_get_chat_empty(static_cast<telegram_api::chatEmpty &>(*chat), source);
      break;
    case telegram_api::chat::ID:
      on_get_chat(static_cast<telegram_api::chat &>(*chat), source);
      break;
    case telegram_api::chatForbidden::ID:
      on_get_chat_forbidden(static_cast<telegram_api::chatForbidden &>(*chat), source);
      break;
    case telegram_api::channel::ID:
      on_get_channel(static_cast<telegram_api::channel &>(*chat), source);
      break;
    case telegram_api::channelForbidden::ID:
      on_get_channel_forbidden(static_cast<telegram_api::channelForbidden &>(*chat), source);
      break;
    default:
      UNREACHABLE();
  }
}

void ChatManager::on_get_chats(vector<tl_object_ptr<telegram_api::Chat>> &&chats, const char *source) {
  for (auto &chat : chats) {
    auto constuctor_id = chat->get_id();
    if (constuctor_id == telegram_api::channel::ID || constuctor_id == telegram_api::channelForbidden::ID) {
      // apply info about megagroups before corresponding chats
      on_get_chat(std::move(chat), source);
      chat = nullptr;
    }
  }
  for (auto &chat : chats) {
    if (chat != nullptr) {
      on_get_chat(std::move(chat), source);
      chat = nullptr;
    }
  }
}

void ChatManager::on_get_chat_full(tl_object_ptr<telegram_api::ChatFull> &&chat_full_ptr, Promise<Unit> &&promise) {
  LOG(INFO) << "Receive " << to_string(chat_full_ptr);
  if (chat_full_ptr->get_id() == telegram_api::chatFull::ID) {
    auto chat = move_tl_object_as<telegram_api::chatFull>(chat_full_ptr);
    ChatId chat_id(chat->id_);
    Chat *c = get_chat(chat_id);
    if (c == nullptr) {
      LOG(ERROR) << "Can't find " << chat_id;
      return promise.set_value(Unit());
    }
    if (c->version >= c->pinned_message_version) {
      auto pinned_message_id = MessageId(ServerMessageId(chat->pinned_msg_id_));
      LOG(INFO) << "Receive pinned " << pinned_message_id << " in " << chat_id << " with version " << c->version
                << ". Current version is " << c->pinned_message_version;
      td_->messages_manager_->on_update_dialog_last_pinned_message_id(DialogId(chat_id), pinned_message_id);
      if (c->version > c->pinned_message_version) {
        c->pinned_message_version = c->version;
        c->need_save_to_database = true;
        update_chat(c, chat_id);
      }
    }

    td_->messages_manager_->on_update_dialog_folder_id(DialogId(chat_id), FolderId(chat->folder_id_));

    td_->messages_manager_->on_update_dialog_has_scheduled_server_messages(DialogId(chat_id), chat->has_scheduled_);

    {
      InputGroupCallId input_group_call_id;
      if (chat->call_ != nullptr) {
        input_group_call_id = InputGroupCallId(chat->call_);
      }
      td_->messages_manager_->on_update_dialog_group_call_id(DialogId(chat_id), input_group_call_id);
    }

    {
      DialogId default_join_group_call_as_dialog_id;
      if (chat->groupcall_default_join_as_ != nullptr) {
        default_join_group_call_as_dialog_id = DialogId(chat->groupcall_default_join_as_);
      }
      // use send closure later to not create synchronously default_join_group_call_as_dialog_id
      send_closure_later(G()->messages_manager(),
                         &MessagesManager::on_update_dialog_default_join_group_call_as_dialog_id, DialogId(chat_id),
                         default_join_group_call_as_dialog_id, false);
    }

    td_->messages_manager_->on_update_dialog_message_ttl(DialogId(chat_id), MessageTtl(chat->ttl_period_));

    td_->messages_manager_->on_update_dialog_is_translatable(DialogId(chat_id), !chat->translations_disabled_);

    ChatFull *chat_full = add_chat_full(chat_id);
    on_update_chat_full_invite_link(chat_full, std::move(chat->exported_invite_));
    auto photo = get_photo(td_, std::move(chat->chat_photo_), DialogId(chat_id));
    // on_update_chat_photo should be a no-op if server sent consistent data
    on_update_chat_photo(c, chat_id, as_dialog_photo(td_->file_manager_.get(), DialogId(chat_id), 0, photo, false),
                         false);
    on_update_chat_full_photo(chat_full, chat_id, std::move(photo));
    if (chat_full->description != chat->about_) {
      chat_full->description = std::move(chat->about_);
      chat_full->is_changed = true;
      td_->group_call_manager_->on_update_dialog_about(DialogId(chat_id), chat_full->description, true);
    }
    if (chat_full->can_set_username != chat->can_set_username_) {
      chat_full->can_set_username = chat->can_set_username_;
      chat_full->need_save_to_database = true;
    }

    on_get_chat_participants(std::move(chat->participants_), false);
    td_->messages_manager_->on_update_dialog_notify_settings(DialogId(chat_id), std::move(chat->notify_settings_),
                                                             "on_get_chat_full");

    td_->messages_manager_->on_update_dialog_available_reactions(
        DialogId(chat_id), std::move(chat->available_reactions_), chat->reactions_limit_, false);

    td_->messages_manager_->on_update_dialog_theme_name(DialogId(chat_id), std::move(chat->theme_emoticon_));

    td_->messages_manager_->on_update_dialog_pending_join_requests(DialogId(chat_id), chat->requests_pending_,
                                                                   std::move(chat->recent_requesters_));

    auto bot_commands = td_->user_manager_->get_bot_commands(std::move(chat->bot_info_), &chat_full->participants);
    if (chat_full->bot_commands != bot_commands) {
      chat_full->bot_commands = std::move(bot_commands);
      chat_full->is_changed = true;
    }

    if (c->is_changed) {
      LOG(ERROR) << "Receive inconsistent chatPhoto and chatPhotoInfo for " << chat_id;
      update_chat(c, chat_id);
    }

    chat_full->is_update_chat_full_sent = true;
    update_chat_full(chat_full, chat_id, "on_get_chat_full");
  } else {
    CHECK(chat_full_ptr->get_id() == telegram_api::channelFull::ID);
    auto channel = move_tl_object_as<telegram_api::channelFull>(chat_full_ptr);
    ChannelId channel_id(channel->id_);
    auto c = get_channel(channel_id);
    if (c == nullptr) {
      LOG(ERROR) << "Can't find " << channel_id;
      return promise.set_value(Unit());
    }

    invalidated_channels_full_.erase(channel_id);

    if (!G()->close_flag()) {
      auto channel_full = get_channel_full(channel_id, true, "on_get_channel_full");
      if (channel_full != nullptr) {
        if (channel_full->repair_request_version != 0 &&
            channel_full->repair_request_version < channel_full->speculative_version) {
          LOG(INFO) << "Receive ChannelFull with request version " << channel_full->repair_request_version
                    << ", but current speculative version is " << channel_full->speculative_version;

          channel_full->repair_request_version = channel_full->speculative_version;

          auto input_channel = get_input_channel(channel_id);
          CHECK(input_channel != nullptr);
          td_->create_handler<GetFullChannelQuery>(std::move(promise))->send(channel_id, std::move(input_channel));
          return;
        }
        channel_full->repair_request_version = 0;
      }
    }

    td_->messages_manager_->on_update_dialog_notify_settings(DialogId(channel_id), std::move(channel->notify_settings_),
                                                             "on_get_channel_full");

    td_->messages_manager_->on_update_dialog_background(DialogId(channel_id), std::move(channel->wallpaper_));

    td_->messages_manager_->on_update_dialog_available_reactions(
        DialogId(channel_id), std::move(channel->available_reactions_), channel->reactions_limit_,
        channel->paid_reactions_available_);

    td_->messages_manager_->on_update_dialog_theme_name(DialogId(channel_id), std::move(channel->theme_emoticon_));

    td_->messages_manager_->on_update_dialog_pending_join_requests(DialogId(channel_id), channel->requests_pending_,
                                                                   std::move(channel->recent_requesters_));

    td_->messages_manager_->on_update_dialog_message_ttl(DialogId(channel_id), MessageTtl(channel->ttl_period_));

    td_->messages_manager_->on_update_dialog_view_as_messages(DialogId(channel_id), channel->view_forum_as_messages_);

    td_->messages_manager_->on_update_dialog_is_translatable(DialogId(channel_id), !channel->translations_disabled_);

    send_closure_later(td_->story_manager_actor_, &StoryManager::on_get_dialog_stories, DialogId(channel_id),
                       std::move(channel->stories_), Promise<Unit>());

    ChannelFull *channel_full = add_channel_full(channel_id);

    bool have_participant_count = (channel->flags_ & telegram_api::channelFull::PARTICIPANTS_COUNT_MASK) != 0;
    auto participant_count = have_participant_count ? channel->participants_count_ : channel_full->participant_count;
    auto administrator_count = 0;
    if ((channel->flags_ & telegram_api::channelFull::ADMINS_COUNT_MASK) != 0) {
      administrator_count = channel->admins_count_;
    } else if (c->is_megagroup || c->status.is_administrator()) {
      // in megagroups and administered channels don't drop known number of administrators
      administrator_count = channel_full->administrator_count;
    }
    if (participant_count < administrator_count) {
      participant_count = administrator_count;
    }
    auto restricted_count = channel->banned_count_;
    auto banned_count = channel->kicked_count_;
    auto can_get_participants = channel->can_view_participants_;
    auto has_hidden_participants = channel->participants_hidden_;
    auto can_set_username = channel->can_set_username_;
    auto can_set_sticker_set = channel->can_set_stickers_;
    auto can_set_location = channel->can_set_location_;
    auto is_all_history_available = !channel->hidden_prehistory_;
    auto can_have_sponsored_messages = !channel->restricted_sponsored_;
    auto has_aggressive_anti_spam_enabled = channel->antispam_;
    auto can_view_statistics = channel->can_view_stats_;
    auto can_view_revenue = channel->can_view_revenue_;
    auto has_pinned_stories = channel->stories_pinned_available_;
    auto boost_count = channel->boosts_applied_;
    auto unrestrict_boost_count = channel->boosts_unrestrict_;
    auto has_paid_media_allowed = channel->paid_media_allowed_;
    auto can_view_star_revenue = channel->can_view_stars_revenue_;
    auto bot_verification = BotVerification::get_bot_verification(std::move(channel->bot_verification_));
    auto gift_count = channel->stargifts_count_;
    auto has_stargifts_available = channel->stargifts_available_;
    auto has_paid_messages_available = channel->paid_messages_available_;
    StickerSetId sticker_set_id;
    if (channel->stickerset_ != nullptr) {
      sticker_set_id =
          td_->stickers_manager_->on_get_sticker_set(std::move(channel->stickerset_), true, "on_get_channel_full");
    }
    StickerSetId emoji_sticker_set_id;
    if (channel->emojiset_ != nullptr) {
      emoji_sticker_set_id =
          td_->stickers_manager_->on_get_sticker_set(std::move(channel->emojiset_), true, "on_get_channel_full");
    }
    DcId stats_dc_id;
    if ((channel->flags_ & telegram_api::channelFull::STATS_DC_MASK) != 0) {
      stats_dc_id = DcId::create(channel->stats_dc_);
    }
    if (!stats_dc_id.is_exact() && can_view_statistics) {
      LOG(ERROR) << "Receive can_view_statistics == true, but invalid statistics DC ID in " << channel_id;
      can_view_statistics = false;
    }

    channel_full->repair_request_version = 0;
    channel_full->expires_at = Time::now() + CHANNEL_FULL_EXPIRE_TIME;
    if (channel_full->participant_count != participant_count ||
        channel_full->administrator_count != administrator_count ||
        channel_full->restricted_count != restricted_count || channel_full->banned_count != banned_count ||
        channel_full->can_get_participants != can_get_participants ||
        channel_full->can_set_sticker_set != can_set_sticker_set ||
        channel_full->can_set_location != can_set_location ||
        channel_full->can_view_statistics != can_view_statistics || channel_full->stats_dc_id != stats_dc_id ||
        channel_full->sticker_set_id != sticker_set_id || channel_full->emoji_sticker_set_id != emoji_sticker_set_id ||
        channel_full->is_all_history_available != is_all_history_available ||
        channel_full->can_have_sponsored_messages != can_have_sponsored_messages ||
        channel_full->has_aggressive_anti_spam_enabled != has_aggressive_anti_spam_enabled ||
        channel_full->has_hidden_participants != has_hidden_participants ||
        channel_full->has_pinned_stories != has_pinned_stories || channel_full->boost_count != boost_count ||
        channel_full->unrestrict_boost_count != unrestrict_boost_count || channel_full->gift_count != gift_count ||
        channel_full->can_view_revenue != can_view_revenue ||
        channel_full->has_paid_media_allowed != has_paid_media_allowed ||
        channel_full->can_view_star_revenue != can_view_star_revenue ||
        channel_full->bot_verification != bot_verification ||
        channel_full->has_stargifts_available != has_stargifts_available ||
        channel_full->has_paid_messages_available != has_paid_messages_available) {
      channel_full->participant_count = participant_count;
      channel_full->administrator_count = administrator_count;
      channel_full->restricted_count = restricted_count;
      channel_full->banned_count = banned_count;
      channel_full->can_get_participants = can_get_participants;
      channel_full->has_hidden_participants = has_hidden_participants;
      channel_full->can_set_sticker_set = can_set_sticker_set;
      channel_full->can_set_location = can_set_location;
      channel_full->can_view_statistics = can_view_statistics;
      channel_full->stats_dc_id = stats_dc_id;
      channel_full->sticker_set_id = sticker_set_id;
      channel_full->emoji_sticker_set_id = emoji_sticker_set_id;
      channel_full->is_all_history_available = is_all_history_available;
      channel_full->can_have_sponsored_messages = can_have_sponsored_messages;
      channel_full->has_aggressive_anti_spam_enabled = has_aggressive_anti_spam_enabled;
      channel_full->has_pinned_stories = has_pinned_stories;
      channel_full->boost_count = boost_count;
      channel_full->unrestrict_boost_count = unrestrict_boost_count;
      channel_full->gift_count = gift_count;
      channel_full->can_view_revenue = can_view_revenue;
      channel_full->has_paid_media_allowed = has_paid_media_allowed;
      channel_full->can_view_star_revenue = can_view_star_revenue;
      channel_full->bot_verification = std::move(bot_verification);
      channel_full->has_stargifts_available = has_stargifts_available;
      channel_full->has_paid_messages_available = has_paid_messages_available;

      channel_full->is_changed = true;
    }
    if (channel_full->description != channel->about_) {
      channel_full->description = std::move(channel->about_);
      channel_full->is_changed = true;
      td_->group_call_manager_->on_update_dialog_about(DialogId(channel_id), channel_full->description, true);
    }

    if (have_participant_count && c->participant_count != participant_count) {
      c->participant_count = participant_count;
      c->is_changed = true;
      update_channel(c, channel_id);
    }
    if (!channel_full->is_can_view_statistics_inited) {
      channel_full->is_can_view_statistics_inited = true;
      channel_full->need_save_to_database = true;
    }
    if (channel_full->can_set_username != can_set_username) {
      channel_full->can_set_username = can_set_username;
      channel_full->need_save_to_database = true;
    }

    auto photo = get_photo(td_, std::move(channel->chat_photo_), DialogId(channel_id));
    // on_update_channel_photo should be a no-op if server sent consistent data
    on_update_channel_photo(
        c, channel_id, as_dialog_photo(td_->file_manager_.get(), DialogId(channel_id), c->access_hash, photo, false),
        false);
    on_update_channel_full_photo(channel_full, channel_id, std::move(photo));

    auto read_outbox_max_message_id = MessageId(ServerMessageId(channel->read_outbox_max_id_));
    if (read_outbox_max_message_id.is_valid()) {
      td_->messages_manager_->read_history_outbox(DialogId(channel_id), read_outbox_max_message_id);
    }
    if ((channel->flags_ & telegram_api::channelFull::AVAILABLE_MIN_ID_MASK) != 0) {
      td_->messages_manager_->on_update_channel_max_unavailable_message_id(
          channel_id, MessageId(ServerMessageId(channel->available_min_id_)), "ChannelFull");
    }
    td_->messages_manager_->on_read_channel_inbox(channel_id, MessageId(ServerMessageId(channel->read_inbox_max_id_)),
                                                  channel->unread_count_, channel->pts_, "ChannelFull");

    on_update_channel_full_invite_link(channel_full, std::move(channel->exported_invite_));

    td_->messages_manager_->on_update_dialog_is_blocked(DialogId(channel_id), channel->blocked_, false);

    td_->messages_manager_->on_update_dialog_last_pinned_message_id(
        DialogId(channel_id), MessageId(ServerMessageId(channel->pinned_msg_id_)));

    td_->messages_manager_->on_update_dialog_folder_id(DialogId(channel_id), FolderId(channel->folder_id_));

    td_->messages_manager_->on_update_dialog_has_scheduled_server_messages(DialogId(channel_id),
                                                                           channel->has_scheduled_);
    {
      InputGroupCallId input_group_call_id;
      if (channel->call_ != nullptr) {
        input_group_call_id = InputGroupCallId(channel->call_);
      }
      td_->messages_manager_->on_update_dialog_group_call_id(DialogId(channel_id), input_group_call_id);
    }
    {
      DialogId default_join_group_call_as_dialog_id;
      if (channel->groupcall_default_join_as_ != nullptr) {
        default_join_group_call_as_dialog_id = DialogId(channel->groupcall_default_join_as_);
      }
      // use send closure later to not create synchronously default_join_group_call_as_dialog_id
      send_closure_later(G()->messages_manager(),
                         &MessagesManager::on_update_dialog_default_join_group_call_as_dialog_id, DialogId(channel_id),
                         default_join_group_call_as_dialog_id, false);
    }
    {
      DialogId default_send_message_as_dialog_id;
      if (channel->default_send_as_ != nullptr) {
        default_send_message_as_dialog_id = DialogId(channel->default_send_as_);
      }
      // use send closure later to not create synchronously default_send_message_as_dialog_id
      send_closure_later(G()->messages_manager(), &MessagesManager::on_update_dialog_default_send_message_as_dialog_id,
                         DialogId(channel_id), default_send_message_as_dialog_id, false);
    }

    if (participant_count >= 190 || !can_get_participants || has_hidden_participants) {
      td_->dialog_participant_manager_->on_update_dialog_online_member_count(DialogId(channel_id),
                                                                             channel->online_count_, true);
    }

    vector<UserId> bot_user_ids;
    for (const auto &bot_info : channel->bot_info_) {
      UserId user_id(bot_info->user_id_);
      if (!td_->user_manager_->is_user_bot(user_id)) {
        continue;
      }

      bot_user_ids.push_back(user_id);
    }
    on_update_channel_full_bot_user_ids(channel_full, channel_id, std::move(bot_user_ids));

    auto bot_commands = td_->user_manager_->get_bot_commands(std::move(channel->bot_info_), nullptr);
    if (channel_full->bot_commands != bot_commands) {
      channel_full->bot_commands = std::move(bot_commands);
      channel_full->is_changed = true;
    }

    ChannelId linked_channel_id;
    if ((channel->flags_ & telegram_api::channelFull::LINKED_CHAT_ID_MASK) != 0) {
      linked_channel_id = ChannelId(channel->linked_chat_id_);
      auto linked_channel = get_channel_force(linked_channel_id, "ChannelFull");
      if (linked_channel == nullptr || c->is_megagroup == linked_channel->is_megagroup ||
          channel_id == linked_channel_id) {
        LOG(ERROR) << "Failed to add a link between " << channel_id << " and " << linked_channel_id;
        linked_channel_id = ChannelId();
      }
    }
    on_update_channel_full_linked_channel_id(channel_full, channel_id, linked_channel_id);

    on_update_channel_full_location(channel_full, channel_id, DialogLocation(td_, std::move(channel->location_)));

    if (c->is_megagroup) {
      on_update_channel_full_slow_mode_delay(channel_full, channel_id, channel->slowmode_seconds_,
                                             channel->slowmode_next_send_date_);
    }
    if (channel_full->can_be_deleted != channel->can_delete_channel_) {
      channel_full->can_be_deleted = channel->can_delete_channel_;
      channel_full->need_save_to_database = true;
    }
    if (c->can_be_deleted != channel_full->can_be_deleted) {
      c->can_be_deleted = channel_full->can_be_deleted;
      c->need_save_to_database = true;
    }

    auto migrated_from_chat_id = ChatId(channel->migrated_from_chat_id_);
    auto migrated_from_max_message_id = MessageId(ServerMessageId(channel->migrated_from_max_id_));
    if (channel_full->migrated_from_chat_id != migrated_from_chat_id ||
        channel_full->migrated_from_max_message_id != migrated_from_max_message_id) {
      channel_full->migrated_from_chat_id = migrated_from_chat_id;
      channel_full->migrated_from_max_message_id = migrated_from_max_message_id;
      channel_full->is_changed = true;
    }

    if (c->is_changed) {
      LOG(ERROR) << "Receive inconsistent chatPhoto and chatPhotoInfo for " << channel_id;
      update_channel(c, channel_id);
    }

    channel_full->is_update_channel_full_sent = true;
    update_channel_full(channel_full, channel_id, "on_get_channel_full");

    if (linked_channel_id.is_valid()) {
      auto linked_channel_full = get_channel_full_force(linked_channel_id, true, "on_get_channel_full");
      on_update_channel_full_linked_channel_id(linked_channel_full, linked_channel_id, channel_id);
      if (linked_channel_full != nullptr) {
        update_channel_full(linked_channel_full, linked_channel_id, "on_get_channel_full 2");
      }
    }

    td_->suggested_action_manager_->set_dialog_pending_suggestions(DialogId(channel_id),
                                                                   std::move(channel->pending_suggestions_));
  }
  promise.set_value(Unit());
}

void ChatManager::on_get_chat_full_failed(ChatId chat_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Failed to get full " << chat_id;
}

void ChatManager::on_get_channel_full_failed(ChannelId channel_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Failed to get full " << channel_id;
  auto channel_full = get_channel_full(channel_id, true, "on_get_channel_full");
  if (channel_full != nullptr) {
    channel_full->repair_request_version = 0;
  }
}

void ChatManager::on_ignored_restriction_reasons_changed() {
  restricted_channel_ids_.foreach([&](const ChannelId &channel_id) {
    send_closure(G()->td(), &Td::send_update, get_update_supergroup_object(channel_id, get_channel(channel_id)));
  });
}

void ChatManager::update_chat_online_member_count(ChatId chat_id, bool is_from_server) {
  auto chat_full = get_chat_full(chat_id);
  if (chat_full != nullptr) {
    update_chat_online_member_count(chat_full, chat_id, false);
  }
}

void ChatManager::update_chat_online_member_count(const ChatFull *chat_full, ChatId chat_id, bool is_from_server) {
  td_->dialog_participant_manager_->update_dialog_online_member_count(chat_full->participants, DialogId(chat_id),
                                                                      is_from_server);
}

void ChatManager::on_get_chat_participants(tl_object_ptr<telegram_api::ChatParticipants> &&participants_ptr,
                                           bool from_update) {
  switch (participants_ptr->get_id()) {
    case telegram_api::chatParticipantsForbidden::ID: {
      auto participants = move_tl_object_as<telegram_api::chatParticipantsForbidden>(participants_ptr);
      ChatId chat_id(participants->chat_id_);
      if (!chat_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << chat_id;
        return;
      }

      if (!have_chat_force(chat_id, "on_get_chat_participants")) {
        LOG(ERROR) << chat_id << " not found";
        return;
      }

      if (from_update) {
        drop_chat_full(chat_id);
      }
      break;
    }
    case telegram_api::chatParticipants::ID: {
      auto participants = move_tl_object_as<telegram_api::chatParticipants>(participants_ptr);
      ChatId chat_id(participants->chat_id_);
      if (!chat_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << chat_id;
        return;
      }

      const Chat *c = get_chat_force(chat_id, "chatParticipants");
      if (c == nullptr) {
        LOG(ERROR) << chat_id << " not found";
        return;
      }

      ChatFull *chat_full = get_chat_full_force(chat_id, "telegram_api::chatParticipants");
      if (chat_full == nullptr) {
        LOG(INFO) << "Ignore update of members for unknown full " << chat_id;
        return;
      }

      UserId new_creator_user_id;
      vector<DialogParticipant> new_participants;
      new_participants.reserve(participants->participants_.size());

      for (auto &participant_ptr : participants->participants_) {
        DialogParticipant dialog_participant(std::move(participant_ptr), c->date, c->status.is_creator());
        if (!dialog_participant.is_valid()) {
          LOG(ERROR) << "Receive invalid " << dialog_participant;
          continue;
        }

        LOG_IF(ERROR, !td_->dialog_manager_->have_dialog_info(dialog_participant.dialog_id_))
            << "Have no information about " << dialog_participant.dialog_id_ << " as a member of " << chat_id;
        LOG_IF(ERROR, !td_->user_manager_->have_user(dialog_participant.inviter_user_id_))
            << "Have no information about " << dialog_participant.inviter_user_id_ << " as a member of " << chat_id;
        if (dialog_participant.joined_date_ < c->date) {
          LOG_IF(ERROR, dialog_participant.joined_date_ < c->date - 30 && c->date >= 1486000000)
              << "Wrong join date = " << dialog_participant.joined_date_ << " for " << dialog_participant.dialog_id_
              << ", " << chat_id << " was created at " << c->date;
          dialog_participant.joined_date_ = c->date;
        }
        if (dialog_participant.status_.is_creator() && dialog_participant.dialog_id_.get_type() == DialogType::User) {
          new_creator_user_id = dialog_participant.dialog_id_.get_user_id();
        }
        new_participants.push_back(std::move(dialog_participant));
      }

      if (chat_full->creator_user_id != new_creator_user_id) {
        if (new_creator_user_id.is_valid() && chat_full->creator_user_id.is_valid()) {
          LOG(ERROR) << "Group creator has changed from " << chat_full->creator_user_id << " to " << new_creator_user_id
                     << " in " << chat_id;
        }
        chat_full->creator_user_id = new_creator_user_id;
        chat_full->is_changed = true;
      }

      on_update_chat_full_participants(chat_full, chat_id, std::move(new_participants), participants->version_,
                                       from_update);
      if (from_update) {
        update_chat_full(chat_full, chat_id, "on_get_chat_participants");
      }
      break;
    }
    default:
      UNREACHABLE();
  }
}

const DialogParticipant *ChatManager::get_chat_participant(ChatId chat_id, UserId user_id) const {
  auto chat_full = get_chat_full(chat_id);
  if (chat_full == nullptr) {
    return nullptr;
  }
  return get_chat_full_participant(chat_full, DialogId(user_id));
}

const DialogParticipant *ChatManager::get_chat_full_participant(const ChatFull *chat_full, DialogId dialog_id) {
  for (const auto &dialog_participant : chat_full->participants) {
    if (dialog_participant.dialog_id_ == dialog_id) {
      return &dialog_participant;
    }
  }
  return nullptr;
}

const vector<DialogParticipant> *ChatManager::get_chat_participants(ChatId chat_id) const {
  auto chat_full = get_chat_full(chat_id);
  if (chat_full == nullptr) {
    return nullptr;
  }
  return &chat_full->participants;
}

tl_object_ptr<td_api::chatMember> ChatManager::get_chat_member_object(const DialogParticipant &dialog_participant,
                                                                      const char *source) const {
  return td_api::make_object<td_api::chatMember>(
      get_message_sender_object(td_, dialog_participant.dialog_id_, source),
      td_->user_manager_->get_user_id_object(dialog_participant.inviter_user_id_, "chatMember.inviter_user_id"),
      dialog_participant.joined_date_, dialog_participant.status_.get_chat_member_status_object());
}

bool ChatManager::on_get_channel_error(ChannelId channel_id, const Status &status, const char *source) {
  LOG(INFO) << "Receive " << status << " in " << channel_id << " from " << source;
  if (status.message() == CSlice("BOT_METHOD_INVALID")) {
    LOG(ERROR) << "Receive BOT_METHOD_INVALID from " << source;
    return true;
  }
  if (G()->is_expected_error(status)) {
    return true;
  }
  if (status.message() == "CHANNEL_PRIVATE" || status.message() == "CHANNEL_PUBLIC_GROUP_NA") {
    if (!channel_id.is_valid()) {
      LOG(ERROR) << "Receive " << status.message() << " in invalid " << channel_id << " from " << source;
      return false;
    }

    auto c = get_channel(channel_id);
    if (c == nullptr) {
      if (Slice(source) == Slice("GetChannelDifferenceQuery") || Slice(source) == Slice("GetChannelsQuery")) {
        // get channel difference after restart
        // get channel from server by its identifier
        return true;
      }
      LOG(ERROR) << "Receive " << status.message() << " in not found " << channel_id << " from " << source;
      return false;
    }

    auto debug_channel_object = oneline(to_string(get_supergroup_object(channel_id, c)));
    if (c->status.is_member()) {
      LOG(INFO) << "Emulate leaving " << channel_id;
      // TODO we also may try to write to a public channel
      telegram_api::channelForbidden channel_forbidden(0 /*ignored*/, !c->is_megagroup, c->is_megagroup,
                                                       channel_id.get(), c->access_hash, c->title, 0);
      on_get_channel_forbidden(channel_forbidden, "CHANNEL_PRIVATE");
    } else if (!c->status.is_banned()) {
      if (!c->usernames.is_empty()) {
        LOG(INFO) << "Drop usernames of " << channel_id;
        on_update_channel_usernames(c, channel_id, Usernames());
      }

      on_update_channel_has_location(c, channel_id, false);

      on_update_channel_linked_channel_id(channel_id, ChannelId());

      update_channel(c, channel_id);

      td_->dialog_invite_link_manager_->remove_dialog_access_by_invite_link(DialogId(channel_id));
    }
    invalidate_channel_full(channel_id, !c->is_slow_mode_enabled, source);
    LOG_IF(ERROR, have_input_peer_channel(c, channel_id, AccessRights::Read))
        << "Have read access to channel after receiving CHANNEL_PRIVATE. Channel state: "
        << oneline(to_string(get_supergroup_object(channel_id, c)))
        << ". Previous channel state: " << debug_channel_object;

    return true;
  }
  return false;
}

bool ChatManager::speculative_add_count(int32 &count, int32 delta_count, int32 min_count) {
  auto new_count = count + delta_count;
  if (new_count < min_count) {
    new_count = min_count;
  }
  if (new_count == count) {
    return false;
  }

  count = new_count;
  return true;
}

void ChatManager::speculative_add_channel_participants(ChannelId channel_id, const vector<UserId> &added_user_ids,
                                                       UserId inviter_user_id, int32 date, bool by_me) {
  td_->dialog_participant_manager_->add_cached_channel_participants(channel_id, added_user_ids, inviter_user_id, date);
  auto channel_full = get_channel_full_force(channel_id, true, "speculative_add_channel_participants");

  int32 delta_participant_count = 0;
  for (auto user_id : added_user_ids) {
    if (!user_id.is_valid()) {
      continue;
    }

    delta_participant_count++;
    if (channel_full != nullptr && td_->user_manager_->is_user_bot(user_id) &&
        !td::contains(channel_full->bot_user_ids, user_id)) {
      channel_full->bot_user_ids.push_back(user_id);
      channel_full->need_save_to_database = true;
      reload_channel_full(channel_id, Promise<Unit>(), "speculative_add_channel_participants");

      send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(channel_id),
                         channel_full->bot_user_ids, false);
    }
  }
  if (channel_full != nullptr) {
    if (channel_full->is_changed) {
      channel_full->speculative_version++;
    }
    update_channel_full(channel_full, channel_id, "speculative_add_channel_participants");
  }
  if (delta_participant_count == 0) {
    return;
  }

  speculative_add_channel_participant_count(channel_id, delta_participant_count, by_me);
}

void ChatManager::speculative_delete_channel_participant(ChannelId channel_id, UserId deleted_user_id, bool by_me) {
  if (!deleted_user_id.is_valid()) {
    return;
  }

  td_->dialog_participant_manager_->delete_cached_channel_participant(channel_id, deleted_user_id);

  if (td_->user_manager_->is_user_bot(deleted_user_id)) {
    auto channel_full = get_channel_full_force(channel_id, true, "speculative_delete_channel_participant");
    if (channel_full != nullptr && td::remove(channel_full->bot_user_ids, deleted_user_id)) {
      channel_full->need_save_to_database = true;
      update_channel_full(channel_full, channel_id, "speculative_delete_channel_participant");

      send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(channel_id),
                         channel_full->bot_user_ids, false);
    }
  }

  speculative_add_channel_participant_count(channel_id, -1, by_me);
}

void ChatManager::speculative_add_channel_participant_count(ChannelId channel_id, int32 delta_participant_count,
                                                            bool by_me) {
  if (by_me) {
    // Currently, ignore all changes made by the current user, because they may have been already counted
    invalidate_channel_full(channel_id, false, "speculative_add_channel_participant_count");  // just in case
    return;
  }

  auto channel_full = get_channel_full_force(channel_id, true, "speculative_add_channel_participant_count");
  auto min_count = channel_full == nullptr ? 0 : channel_full->administrator_count;

  auto c = get_channel_force(channel_id, "speculative_add_channel_participant_count");
  if (c != nullptr && c->participant_count != 0 &&
      speculative_add_count(c->participant_count, delta_participant_count, min_count)) {
    c->is_changed = true;
    update_channel(c, channel_id);
  }

  if (channel_full == nullptr) {
    return;
  }

  channel_full->is_changed |=
      speculative_add_count(channel_full->participant_count, delta_participant_count, min_count);

  if (channel_full->is_changed) {
    channel_full->speculative_version++;
  }

  update_channel_full(channel_full, channel_id, "speculative_add_channel_participant_count");
}

void ChatManager::speculative_add_channel_user(ChannelId channel_id, UserId user_id,
                                               const DialogParticipantStatus &new_status,
                                               const DialogParticipantStatus &old_status) {
  auto c = get_channel_force(channel_id, "speculative_add_channel_user");
  // channel full must be loaded before c->participant_count is updated, because on_load_channel_full_from_database
  // must copy the initial c->participant_count before it is speculatibely updated
  auto channel_full = get_channel_full_force(channel_id, true, "speculative_add_channel_user");
  int32 min_count = 0;
  LOG(INFO) << "Speculatively change status of " << user_id << " in " << channel_id << " from " << old_status << " to "
            << new_status;
  if (channel_full != nullptr) {
    channel_full->is_changed |= speculative_add_count(
        channel_full->administrator_count, new_status.is_administrator_member() - old_status.is_administrator_member());
    min_count = channel_full->administrator_count;
  }

  if (c != nullptr && c->participant_count != 0 &&
      speculative_add_count(c->participant_count, new_status.is_member() - old_status.is_member(), min_count)) {
    c->is_changed = true;
    update_channel(c, channel_id);
  }

  td_->dialog_participant_manager_->update_cached_channel_participant_status(channel_id, user_id, new_status);

  if (channel_full == nullptr) {
    return;
  }

  channel_full->is_changed |= speculative_add_count(channel_full->participant_count,
                                                    new_status.is_member() - old_status.is_member(), min_count);
  channel_full->is_changed |=
      speculative_add_count(channel_full->restricted_count, new_status.is_restricted() - old_status.is_restricted());
  channel_full->is_changed |=
      speculative_add_count(channel_full->banned_count, new_status.is_banned() - old_status.is_banned());

  if (channel_full->is_changed) {
    channel_full->speculative_version++;
  }

  if (new_status.is_member() != old_status.is_member() && td_->user_manager_->is_user_bot(user_id)) {
    if (new_status.is_member()) {
      if (!td::contains(channel_full->bot_user_ids, user_id)) {
        channel_full->bot_user_ids.push_back(user_id);
        channel_full->need_save_to_database = true;
        reload_channel_full(channel_id, Promise<Unit>(), "speculative_add_channel_user");

        send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(channel_id),
                           channel_full->bot_user_ids, false);
      }
    } else {
      if (td::remove(channel_full->bot_user_ids, user_id)) {
        channel_full->need_save_to_database = true;

        send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(channel_id),
                           channel_full->bot_user_ids, false);
      }
    }
  }

  update_channel_full(channel_full, channel_id, "speculative_add_channel_user");
}

void ChatManager::invalidate_channel_full(ChannelId channel_id, bool need_drop_slow_mode_delay, const char *source) {
  LOG(INFO) << "Invalidate supergroup full for " << channel_id << " from " << source;
  auto channel_full = get_channel_full(channel_id, true, "invalidate_channel_full");  // must not load ChannelFull
  if (channel_full != nullptr) {
    do_invalidate_channel_full(channel_full, channel_id, need_drop_slow_mode_delay);
    update_channel_full(channel_full, channel_id, source);
  } else if (channel_id.is_valid()) {
    invalidated_channels_full_.insert(channel_id);
  }
}

void ChatManager::do_invalidate_channel_full(ChannelFull *channel_full, ChannelId channel_id,
                                             bool need_drop_slow_mode_delay) {
  CHECK(channel_full != nullptr);
  td_->dialog_manager_->on_dialog_info_full_invalidated(DialogId(channel_id));
  if (channel_full->expires_at >= Time::now()) {
    channel_full->expires_at = 0.0;
    channel_full->need_save_to_database = true;
  }
  if (need_drop_slow_mode_delay && channel_full->slow_mode_delay != 0) {
    channel_full->slow_mode_delay = 0;
    channel_full->slow_mode_next_send_date = 0;
    channel_full->is_slow_mode_next_send_date_changed = true;
    channel_full->is_changed = true;
  }
}

void ChatManager::on_update_chat_full_photo(ChatFull *chat_full, ChatId chat_id, Photo photo) {
  CHECK(chat_full != nullptr);
  if (photo != chat_full->photo) {
    chat_full->photo = std::move(photo);
    chat_full->is_changed = true;
  }

  auto photo_file_ids = photo_get_file_ids(chat_full->photo);
  if (chat_full->registered_photo_file_ids == photo_file_ids) {
    return;
  }

  auto &file_source_id = chat_full->file_source_id;
  if (!file_source_id.is_valid()) {
    file_source_id = chat_full_file_source_ids_.get(chat_id);
    if (file_source_id.is_valid()) {
      VLOG(file_references) << "Move " << file_source_id << " inside of " << chat_id;
      chat_full_file_source_ids_.erase(chat_id);
    } else {
      VLOG(file_references) << "Need to create new file source for full " << chat_id;
      file_source_id = td_->file_reference_manager_->create_chat_full_file_source(chat_id);
    }
  }

  td_->file_manager_->change_files_source(file_source_id, chat_full->registered_photo_file_ids, photo_file_ids,
                                          "on_update_chat_full_photo");
  chat_full->registered_photo_file_ids = std::move(photo_file_ids);
}

void ChatManager::on_update_channel_full_photo(ChannelFull *channel_full, ChannelId channel_id, Photo photo) {
  CHECK(channel_full != nullptr);
  if (photo != channel_full->photo) {
    channel_full->photo = std::move(photo);
    channel_full->is_changed = true;
  }

  auto photo_file_ids = photo_get_file_ids(channel_full->photo);
  if (channel_full->registered_photo_file_ids == photo_file_ids) {
    return;
  }

  auto &file_source_id = channel_full->file_source_id;
  if (!file_source_id.is_valid()) {
    file_source_id = channel_full_file_source_ids_.get(channel_id);
    if (file_source_id.is_valid()) {
      VLOG(file_references) << "Move " << file_source_id << " inside of " << channel_id;
      channel_full_file_source_ids_.erase(channel_id);
    } else {
      VLOG(file_references) << "Need to create new file source for full " << channel_id;
      file_source_id = td_->file_reference_manager_->create_channel_full_file_source(channel_id);
    }
  }

  td_->file_manager_->change_files_source(file_source_id, channel_full->registered_photo_file_ids, photo_file_ids,
                                          "on_update_channel_full_photo");
  channel_full->registered_photo_file_ids = std::move(photo_file_ids);
}

void ChatManager::on_update_chat_full_invite_link(ChatFull *chat_full,
                                                  tl_object_ptr<telegram_api::ExportedChatInvite> &&invite_link) {
  CHECK(chat_full != nullptr);
  if (update_permanent_invite_link(chat_full->invite_link,
                                   DialogInviteLink(std::move(invite_link), false, false, "ChatFull"))) {
    chat_full->is_changed = true;
  }
}

void ChatManager::on_update_channel_full_invite_link(ChannelFull *channel_full,
                                                     tl_object_ptr<telegram_api::ExportedChatInvite> &&invite_link) {
  CHECK(channel_full != nullptr);
  if (update_permanent_invite_link(channel_full->invite_link,
                                   DialogInviteLink(std::move(invite_link), false, false, "ChannelFull"))) {
    channel_full->is_changed = true;
  }
}

void ChatManager::remove_linked_channel_id(ChannelId channel_id) {
  if (!channel_id.is_valid()) {
    return;
  }

  auto linked_channel_id = linked_channel_ids_.get(channel_id);
  if (linked_channel_id.is_valid()) {
    linked_channel_ids_.erase(channel_id);
    linked_channel_ids_.erase(linked_channel_id);
  }
}

ChannelId ChatManager::get_linked_channel_id(ChannelId channel_id) const {
  auto channel_full = get_channel_full(channel_id);
  if (channel_full != nullptr) {
    return channel_full->linked_channel_id;
  }

  return linked_channel_ids_.get(channel_id);
}

void ChatManager::on_update_channel_full_linked_channel_id(ChannelFull *channel_full, ChannelId channel_id,
                                                           ChannelId linked_channel_id) {
  auto old_linked_channel_id = get_linked_channel_id(channel_id);
  LOG(INFO) << "Uplate linked channel in " << channel_id << " from " << old_linked_channel_id << " to "
            << linked_channel_id;

  if (channel_full != nullptr && channel_full->linked_channel_id != linked_channel_id &&
      channel_full->linked_channel_id.is_valid()) {
    get_channel_force(channel_full->linked_channel_id, "on_update_channel_full_linked_channel_id 10");
    get_channel_full_force(channel_full->linked_channel_id, true, "on_update_channel_full_linked_channel_id 0");
  }
  auto old_linked_linked_channel_id = get_linked_channel_id(linked_channel_id);

  remove_linked_channel_id(channel_id);
  remove_linked_channel_id(linked_channel_id);
  if (channel_id.is_valid() && linked_channel_id.is_valid()) {
    linked_channel_ids_.set(channel_id, linked_channel_id);
    linked_channel_ids_.set(linked_channel_id, channel_id);
  }

  if (channel_full != nullptr && channel_full->linked_channel_id != linked_channel_id) {
    if (channel_full->linked_channel_id.is_valid()) {
      // remove link from a previously linked channel_full
      auto linked_channel =
          get_channel_force(channel_full->linked_channel_id, "on_update_channel_full_linked_channel_id 11");
      if (linked_channel != nullptr && linked_channel->has_linked_channel) {
        linked_channel->has_linked_channel = false;
        linked_channel->is_changed = true;
        update_channel(linked_channel, channel_full->linked_channel_id);
        reload_channel(channel_full->linked_channel_id, Auto(), "on_update_channel_full_linked_channel_id 21");
      }
      auto linked_channel_full =
          get_channel_full_force(channel_full->linked_channel_id, true, "on_update_channel_full_linked_channel_id 1");
      if (linked_channel_full != nullptr && linked_channel_full->linked_channel_id == channel_id) {
        linked_channel_full->linked_channel_id = ChannelId();
        linked_channel_full->is_changed = true;
        update_channel_full(linked_channel_full, channel_full->linked_channel_id,
                            "on_update_channel_full_linked_channel_id 3");
      }
    }

    channel_full->linked_channel_id = linked_channel_id;
    channel_full->is_changed = true;

    if (channel_full->linked_channel_id.is_valid()) {
      // add link from a newly linked channel_full
      auto linked_channel =
          get_channel_force(channel_full->linked_channel_id, "on_update_channel_full_linked_channel_id 12");
      if (linked_channel != nullptr && !linked_channel->has_linked_channel) {
        linked_channel->has_linked_channel = true;
        linked_channel->is_changed = true;
        update_channel(linked_channel, channel_full->linked_channel_id);
        reload_channel(channel_full->linked_channel_id, Auto(), "on_update_channel_full_linked_channel_id 22");
      }
      auto linked_channel_full =
          get_channel_full_force(channel_full->linked_channel_id, true, "on_update_channel_full_linked_channel_id 2");
      if (linked_channel_full != nullptr && linked_channel_full->linked_channel_id != channel_id) {
        linked_channel_full->linked_channel_id = channel_id;
        linked_channel_full->is_changed = true;
        update_channel_full(linked_channel_full, channel_full->linked_channel_id,
                            "on_update_channel_full_linked_channel_id 4");
      }
    }
  }

  Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);
  if (linked_channel_id.is_valid() != c->has_linked_channel) {
    c->has_linked_channel = linked_channel_id.is_valid();
    c->is_changed = true;
    update_channel(c, channel_id);
  }

  if (old_linked_channel_id != linked_channel_id) {
    // must be called after the linked channel is changed
    td_->messages_manager_->on_dialog_linked_channel_updated(DialogId(channel_id), old_linked_channel_id,
                                                             linked_channel_id);
  }

  if (linked_channel_id.is_valid()) {
    auto new_linked_linked_channel_id = get_linked_channel_id(linked_channel_id);
    LOG(INFO) << "Uplate linked channel in " << linked_channel_id << " from " << old_linked_linked_channel_id << " to "
              << new_linked_linked_channel_id;
    if (old_linked_linked_channel_id != new_linked_linked_channel_id) {
      // must be called after the linked channel is changed
      td_->messages_manager_->on_dialog_linked_channel_updated(
          DialogId(linked_channel_id), old_linked_linked_channel_id, new_linked_linked_channel_id);
    }
  }
}

void ChatManager::on_update_channel_full_location(ChannelFull *channel_full, ChannelId channel_id,
                                                  const DialogLocation &location) {
  if (channel_full->location != location) {
    channel_full->location = location;
    channel_full->is_changed = true;
  }

  Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);
  on_update_channel_has_location(c, channel_id, !location.empty());
  update_channel(c, channel_id);
}

void ChatManager::on_update_channel_full_slow_mode_delay(ChannelFull *channel_full, ChannelId channel_id,
                                                         int32 slow_mode_delay, int32 slow_mode_next_send_date) {
  if (slow_mode_delay < 0) {
    LOG(ERROR) << "Receive slow mode delay " << slow_mode_delay << " in " << channel_id;
    slow_mode_delay = 0;
  }

  if (channel_full->slow_mode_delay != slow_mode_delay) {
    channel_full->slow_mode_delay = slow_mode_delay;
    channel_full->is_changed = true;
  }
  on_update_channel_full_slow_mode_next_send_date(channel_full, slow_mode_next_send_date);

  Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);
  bool is_slow_mode_enabled = slow_mode_delay != 0;
  if (is_slow_mode_enabled != c->is_slow_mode_enabled) {
    c->is_slow_mode_enabled = is_slow_mode_enabled;
    c->is_changed = true;
    update_channel(c, channel_id);
  }
}

void ChatManager::on_update_channel_full_slow_mode_next_send_date(ChannelFull *channel_full,
                                                                  int32 slow_mode_next_send_date) {
  if (slow_mode_next_send_date < 0) {
    LOG(ERROR) << "Receive slow mode next send date " << slow_mode_next_send_date;
    slow_mode_next_send_date = 0;
  }
  if (channel_full->slow_mode_delay == 0 && slow_mode_next_send_date > 0) {
    LOG(ERROR) << "Slow mode is disabled, but next send date is " << slow_mode_next_send_date;
    slow_mode_next_send_date = 0;
  }

  if (slow_mode_next_send_date != 0) {
    auto now = G()->unix_time();
    if (slow_mode_next_send_date <= now) {
      slow_mode_next_send_date = 0;
    }
    if (slow_mode_next_send_date > now + 3601) {
      slow_mode_next_send_date = now + 3601;
    }
  }
  if (channel_full->slow_mode_next_send_date != slow_mode_next_send_date) {
    channel_full->slow_mode_next_send_date = slow_mode_next_send_date;
    channel_full->is_slow_mode_next_send_date_changed = true;
    if (channel_full->unrestrict_boost_count == 0 || channel_full->boost_count < channel_full->unrestrict_boost_count) {
      channel_full->is_changed = true;
    } else {
      channel_full->need_save_to_database = true;
    }
  }
}

bool ChatManager::update_permanent_invite_link(DialogInviteLink &invite_link, DialogInviteLink new_invite_link) {
  if (new_invite_link != invite_link) {
    if (invite_link.is_valid() && invite_link.get_invite_link() != new_invite_link.get_invite_link()) {
      // old link was invalidated
      td_->dialog_invite_link_manager_->invalidate_invite_link_info(invite_link.get_invite_link());
    }

    invite_link = std::move(new_invite_link);
    return true;
  }
  return false;
}

void ChatManager::repair_chat_participants(ChatId chat_id) {
  send_get_chat_full_query(chat_id, Auto(), "repair_chat_participants");
}

void ChatManager::on_update_chat_add_user(ChatId chat_id, UserId inviter_user_id, UserId user_id, int32 date,
                                          int32 version) {
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id;
    return;
  }
  if (!td_->user_manager_->have_user(user_id)) {
    LOG(ERROR) << "Can't find " << user_id;
    return;
  }
  if (!td_->user_manager_->have_user(inviter_user_id)) {
    LOG(ERROR) << "Can't find " << inviter_user_id;
    return;
  }
  LOG(INFO) << "Receive updateChatParticipantAdd to " << chat_id << " with " << user_id << " invited by "
            << inviter_user_id << " at " << date << " with version " << version;

  ChatFull *chat_full = get_chat_full_force(chat_id, "on_update_chat_add_user");
  if (chat_full == nullptr) {
    LOG(INFO) << "Ignoring update about members of " << chat_id;
    return;
  }
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    LOG(ERROR) << "Receive updateChatParticipantAdd for unknown " << chat_id << ". Couldn't apply it";
    repair_chat_participants(chat_id);
    return;
  }
  if (c->status.is_left()) {
    // possible if updates come out of order
    LOG(WARNING) << "Receive updateChatParticipantAdd for left " << chat_id << ". Couldn't apply it";

    repair_chat_participants(chat_id);  // just in case
    return;
  }
  if (on_update_chat_full_participants_short(chat_full, chat_id, version)) {
    for (auto &participant : chat_full->participants) {
      if (participant.dialog_id_ == DialogId(user_id)) {
        if (participant.inviter_user_id_ != inviter_user_id) {
          LOG(ERROR) << user_id << " was readded to " << chat_id << " by " << inviter_user_id
                     << ", previously invited by " << participant.inviter_user_id_;
          participant.inviter_user_id_ = inviter_user_id;
          participant.joined_date_ = date;
          repair_chat_participants(chat_id);
        } else {
          // Possible if update comes twice
          LOG(INFO) << user_id << " was readded to " << chat_id;
        }
        return;
      }
    }
    chat_full->participants.push_back(DialogParticipant{DialogId(user_id), inviter_user_id, date,
                                                        user_id == chat_full->creator_user_id
                                                            ? DialogParticipantStatus::Creator(true, false, string())
                                                            : DialogParticipantStatus::Member(0)});
    update_chat_online_member_count(chat_full, chat_id, false);
    chat_full->is_changed = true;
    update_chat_full(chat_full, chat_id, "on_update_chat_add_user");

    // Chat is already updated
    if (chat_full->version == c->version &&
        narrow_cast<int32>(chat_full->participants.size()) != c->participant_count) {
      LOG(ERROR) << "Number of members in " << chat_id << " with version " << c->version << " is "
                 << c->participant_count << " but there are " << chat_full->participants.size()
                 << " members in the ChatFull";
      repair_chat_participants(chat_id);
    }
  }
}

void ChatManager::on_update_chat_edit_administrator(ChatId chat_id, UserId user_id, bool is_administrator,
                                                    int32 version) {
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id;
    return;
  }
  if (!td_->user_manager_->have_user(user_id)) {
    LOG(ERROR) << "Can't find " << user_id;
    return;
  }
  LOG(INFO) << "Receive updateChatParticipantAdmin in " << chat_id << " with " << user_id << ", administrator rights "
            << (is_administrator ? "enabled" : "disabled") << " with version " << version;

  auto c = get_chat_force(chat_id, "on_update_chat_edit_administrator");
  if (c == nullptr) {
    LOG(INFO) << "Ignoring update about members of unknown " << chat_id;
    return;
  }

  if (c->status.is_left()) {
    // possible if updates come out of order
    LOG(WARNING) << "Receive updateChatParticipantAdmin for left " << chat_id << ". Couldn't apply it";

    repair_chat_participants(chat_id);  // just in case
    return;
  }
  if (version <= -1) {
    LOG(ERROR) << "Receive wrong version " << version << " for " << chat_id;
    return;
  }
  CHECK(c->version >= 0);

  auto status = is_administrator ? DialogParticipantStatus::GroupAdministrator(c->status.is_creator())
                                 : DialogParticipantStatus::Member(0);
  if (version > c->version) {
    if (version != c->version + 1) {
      LOG(INFO) << "Administrators of " << chat_id << " with version " << c->version
                << " has changed, but new version is " << version;
      repair_chat_participants(chat_id);
      return;
    }

    c->version = version;
    c->need_save_to_database = true;
    if (user_id == td_->user_manager_->get_my_id() && !c->status.is_creator()) {
      // if chat with version was already received, then the update is already processed
      // so we need to call on_update_chat_status only if version > c->version
      on_update_chat_status(c, chat_id, status);
    }
    update_chat(c, chat_id);
  }

  ChatFull *chat_full = get_chat_full_force(chat_id, "on_update_chat_edit_administrator");
  if (chat_full != nullptr) {
    if (chat_full->version + 1 == version) {
      for (auto &participant : chat_full->participants) {
        if (participant.dialog_id_ == DialogId(user_id)) {
          participant.status_ = std::move(status);
          chat_full->is_changed = true;
          update_chat_full(chat_full, chat_id, "on_update_chat_edit_administrator");
          return;
        }
      }
    }

    // can't find chat member or version have increased too much
    repair_chat_participants(chat_id);
  }
}

void ChatManager::on_update_chat_delete_user(ChatId chat_id, UserId user_id, int32 version) {
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id;
    return;
  }
  if (!td_->user_manager_->have_user(user_id)) {
    LOG(ERROR) << "Can't find " << user_id;
    return;
  }
  LOG(INFO) << "Receive updateChatParticipantDelete from " << chat_id << " with " << user_id << " and version "
            << version;

  ChatFull *chat_full = get_chat_full_force(chat_id, "on_update_chat_delete_user");
  if (chat_full == nullptr) {
    LOG(INFO) << "Ignoring update about members of " << chat_id;
    return;
  }
  const Chat *c = get_chat_force(chat_id, "on_update_chat_delete_user");
  if (c == nullptr) {
    LOG(ERROR) << "Receive updateChatParticipantDelete for unknown " << chat_id;
    repair_chat_participants(chat_id);
    return;
  }
  if (user_id == td_->user_manager_->get_my_id()) {
    LOG_IF(WARNING, c->status.is_member()) << "User was removed from " << chat_id
                                           << " but it is not left the group. Possible if updates comes out of order";
    return;
  }
  if (c->status.is_left()) {
    // possible if updates come out of order
    LOG(INFO) << "Receive updateChatParticipantDelete for left " << chat_id;

    repair_chat_participants(chat_id);
    return;
  }
  if (on_update_chat_full_participants_short(chat_full, chat_id, version)) {
    for (size_t i = 0; i < chat_full->participants.size(); i++) {
      if (chat_full->participants[i].dialog_id_ == DialogId(user_id)) {
        chat_full->participants[i] = chat_full->participants.back();
        chat_full->participants.resize(chat_full->participants.size() - 1);
        chat_full->is_changed = true;
        update_chat_online_member_count(chat_full, chat_id, false);
        update_chat_full(chat_full, chat_id, "on_update_chat_delete_user");

        if (static_cast<int32>(chat_full->participants.size()) != c->participant_count) {
          repair_chat_participants(chat_id);
        }
        return;
      }
    }
    LOG(ERROR) << "Can't find basic group member " << user_id << " in " << chat_id << " to be removed";
    repair_chat_participants(chat_id);
  }
}

void ChatManager::on_update_chat_status(Chat *c, ChatId chat_id, DialogParticipantStatus status) {
  if (c->status != status) {
    LOG(INFO) << "Update " << chat_id << " status from " << c->status << " to " << status;
    bool need_reload_group_call = c->status.can_manage_calls() != status.can_manage_calls();
    bool need_drop_invite_link = c->status.can_manage_invite_links() && !status.can_manage_invite_links();

    c->status = std::move(status);
    c->is_status_changed = true;

    if (c->status.is_left()) {
      c->participant_count = 0;
      c->version = -1;
      c->default_permissions_version = -1;
      c->pinned_message_version = -1;

      drop_chat_full(chat_id);
    } else if (need_drop_invite_link) {
      ChatFull *chat_full = get_chat_full_force(chat_id, "on_update_chat_status");
      if (chat_full != nullptr) {
        on_update_chat_full_invite_link(chat_full, nullptr);
        update_chat_full(chat_full, chat_id, "on_update_chat_status");
      }
    }
    if (need_reload_group_call) {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_update_dialog_group_call_rights,
                         DialogId(chat_id));
    }

    c->is_changed = true;
  }
}

void ChatManager::on_update_chat_default_permissions(ChatId chat_id, RestrictedRights default_permissions,
                                                     int32 version) {
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id;
    return;
  }
  auto c = get_chat_force(chat_id, "on_update_chat_default_permissions");
  if (c == nullptr) {
    LOG(INFO) << "Ignoring update about unknown " << chat_id;
    return;
  }

  LOG(INFO) << "Receive updateChatDefaultBannedRights in " << chat_id << " with " << default_permissions
            << " and version " << version << ". Current version is " << c->version;

  if (c->status.is_left()) {
    // possible if updates come out of order
    LOG(WARNING) << "Receive updateChatDefaultBannedRights for left " << chat_id << ". Couldn't apply it";

    repair_chat_participants(chat_id);  // just in case
    return;
  }
  if (version <= -1) {
    LOG(ERROR) << "Receive wrong version " << version << " for " << chat_id;
    return;
  }
  CHECK(c->version >= 0);

  if (version > c->version) {
    // this should be unreachable, because version and default permissions must be already updated from
    // the chat object in on_get_chat
    if (version != c->version + 1) {
      LOG(INFO) << "Default permissions of " << chat_id << " with version " << c->version
                << " has changed, but new version is " << version;
      repair_chat_participants(chat_id);
      return;
    }

    LOG_IF(ERROR, default_permissions == c->default_permissions)
        << "Receive updateChatDefaultBannedRights in " << chat_id << " with version " << version
        << " and default_permissions = " << default_permissions
        << ", but default_permissions are not changed. Current version is " << c->version;
    c->version = version;
    c->need_save_to_database = true;
    on_update_chat_default_permissions(c, chat_id, default_permissions, version);
    update_chat(c, chat_id);
  }
}

void ChatManager::on_update_chat_default_permissions(Chat *c, ChatId chat_id, RestrictedRights default_permissions,
                                                     int32 version) {
  if (c->default_permissions != default_permissions && version >= c->default_permissions_version) {
    LOG(INFO) << "Update " << chat_id << " default permissions from " << c->default_permissions << " to "
              << default_permissions << " and version from " << c->default_permissions_version << " to " << version;
    c->default_permissions = default_permissions;
    c->default_permissions_version = version;
    c->is_default_permissions_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_chat_noforwards(Chat *c, ChatId chat_id, bool noforwards) {
  if (c->noforwards != noforwards) {
    LOG(INFO) << "Update " << chat_id << " has_protected_content from " << c->noforwards << " to " << noforwards;
    c->noforwards = noforwards;
    c->is_noforwards_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_chat_pinned_message(ChatId chat_id, MessageId pinned_message_id, int32 version) {
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id;
    return;
  }
  auto c = get_chat_force(chat_id, "on_update_chat_pinned_message");
  if (c == nullptr) {
    LOG(INFO) << "Ignoring update about unknown " << chat_id;
    return;
  }

  LOG(INFO) << "Receive updateChatPinnedMessage in " << chat_id << " with " << pinned_message_id << " and version "
            << version << ". Current version is " << c->version << "/" << c->pinned_message_version;

  if (c->status.is_left()) {
    // possible if updates come out of order
    repair_chat_participants(chat_id);  // just in case
    return;
  }
  if (version <= -1) {
    LOG(ERROR) << "Receive wrong version " << version << " for " << chat_id;
    return;
  }
  CHECK(c->version >= 0);

  if (version >= c->pinned_message_version) {
    if (version != c->version + 1 && version != c->version) {
      LOG(INFO) << "Pinned message of " << chat_id << " with version " << c->version
                << " has changed, but new version is " << version;
      repair_chat_participants(chat_id);
    } else if (version == c->version + 1) {
      c->version = version;
      c->need_save_to_database = true;
    }
    td_->messages_manager_->on_update_dialog_last_pinned_message_id(DialogId(chat_id), pinned_message_id);
    if (version > c->pinned_message_version) {
      LOG(INFO) << "Change pinned message version of " << chat_id << " from " << c->pinned_message_version << " to "
                << version;
      c->pinned_message_version = version;
      c->need_save_to_database = true;
    }
    update_chat(c, chat_id);
  }
}

void ChatManager::on_update_chat_participant_count(Chat *c, ChatId chat_id, int32 participant_count, int32 version,
                                                   const string &debug_str) {
  if (version <= -1) {
    LOG(ERROR) << "Receive wrong version " << version << " in " << chat_id << debug_str;
    return;
  }

  if (version < c->version) {
    // some outdated data
    LOG(INFO) << "Receive number of members in " << chat_id << " with version " << version << debug_str
              << ", but current version is " << c->version;
    return;
  }

  if (c->participant_count != participant_count) {
    if (version == c->version && participant_count != 0) {
      // version is not changed when deleted user is removed from the chat
      LOG_IF(ERROR, c->participant_count != participant_count + 1)
          << "Number of members in " << chat_id << " has changed from " << c->participant_count << " to "
          << participant_count << ", but version " << c->version << " remains unchanged" << debug_str;
      repair_chat_participants(chat_id);
    }

    c->participant_count = participant_count;
    c->version = version;
    c->is_changed = true;
    return;
  }

  if (version > c->version) {
    c->version = version;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_chat_photo(Chat *c, ChatId chat_id,
                                       tl_object_ptr<telegram_api::ChatPhoto> &&chat_photo_ptr) {
  on_update_chat_photo(
      c, chat_id, get_dialog_photo(td_->file_manager_.get(), DialogId(chat_id), 0, std::move(chat_photo_ptr)), true);
}

void ChatManager::on_update_chat_photo(Chat *c, ChatId chat_id, DialogPhoto &&photo, bool invalidate_photo_cache) {
  if (td_->auth_manager_->is_bot()) {
    photo.minithumbnail.clear();
  }

  if (need_update_dialog_photo(c->photo, photo)) {
    LOG(DEBUG) << "Update photo of " << chat_id << " from " << c->photo << " to " << photo;
    c->photo = std::move(photo);
    c->is_photo_changed = true;
    c->need_save_to_database = true;

    if (invalidate_photo_cache) {
      auto chat_full = get_chat_full(chat_id);  // must not load ChatFull
      if (chat_full != nullptr) {
        if (!chat_full->photo.is_empty()) {
          chat_full->photo = Photo();
          chat_full->is_changed = true;
        }
        if (c->photo.small_file_id.is_valid()) {
          reload_chat_full(chat_id, Auto(), "on_update_chat_photo");
        }
        update_chat_full(chat_full, chat_id, "on_update_chat_photo");
      }
    }
  } else if (need_update_dialog_photo_minithumbnail(c->photo.minithumbnail, photo.minithumbnail)) {
    c->photo.minithumbnail = std::move(photo.minithumbnail);
    c->is_photo_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_chat_title(Chat *c, ChatId chat_id, string &&title) {
  if (c->title != title) {
    c->title = std::move(title);
    c->is_title_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_chat_active(Chat *c, ChatId chat_id, bool is_active) {
  if (c->is_active != is_active) {
    c->is_active = is_active;
    c->is_is_active_changed = true;
    c->is_changed = true;
  }
}

void ChatManager::on_update_chat_migrated_to_channel_id(Chat *c, ChatId chat_id, ChannelId migrated_to_channel_id) {
  if (c->migrated_to_channel_id != migrated_to_channel_id && migrated_to_channel_id.is_valid()) {
    LOG_IF(ERROR, c->migrated_to_channel_id.is_valid())
        << "Upgraded supergroup ID for " << chat_id << " has changed from " << c->migrated_to_channel_id << " to "
        << migrated_to_channel_id;
    c->migrated_to_channel_id = migrated_to_channel_id;
    c->is_changed = true;
  }
}

void ChatManager::on_update_chat_description(ChatId chat_id, string &&description) {
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id;
    return;
  }

  auto chat_full = get_chat_full_force(chat_id, "on_update_chat_description");
  if (chat_full == nullptr) {
    return;
  }
  if (chat_full->description != description) {
    chat_full->description = std::move(description);
    chat_full->is_changed = true;
    update_chat_full(chat_full, chat_id, "on_update_chat_description");
    td_->group_call_manager_->on_update_dialog_about(DialogId(chat_id), chat_full->description, true);
  }
}

bool ChatManager::on_update_chat_full_participants_short(ChatFull *chat_full, ChatId chat_id, int32 version) {
  if (version <= -1) {
    LOG(ERROR) << "Receive wrong version " << version << " for " << chat_id;
    return false;
  }
  if (chat_full->version == -1) {
    // chat members are unknown, nothing to update
    return false;
  }

  if (chat_full->version + 1 == version) {
    chat_full->version = version;
    return true;
  }

  LOG(INFO) << "Number of members in " << chat_id << " with version " << chat_full->version
            << " has changed, but new version is " << version;
  repair_chat_participants(chat_id);
  return false;
}

void ChatManager::on_update_chat_full_participants(ChatFull *chat_full, ChatId chat_id,
                                                   vector<DialogParticipant> participants, int32 version,
                                                   bool from_update) {
  if (version <= -1) {
    LOG(ERROR) << "Receive members with wrong version " << version << " in " << chat_id;
    return;
  }

  if (version < chat_full->version) {
    // some outdated data
    LOG(WARNING) << "Receive members of " << chat_id << " with version " << version << " but current version is "
                 << chat_full->version;
    return;
  }

  if ((chat_full->participants.size() != participants.size() && version == chat_full->version) ||
      (from_update && version != chat_full->version + 1)) {
    LOG(INFO) << "Members of " << chat_id << " has changed";
    // this is possible in very rare situations
    repair_chat_participants(chat_id);
  }

  chat_full->participants = std::move(participants);
  chat_full->version = version;
  chat_full->is_changed = true;
  update_chat_online_member_count(chat_full, chat_id, true);
}

void ChatManager::drop_chat_full(ChatId chat_id) {
  ChatFull *chat_full = get_chat_full_force(chat_id, "drop_chat_full");
  if (chat_full == nullptr) {
    return;
  }

  LOG(INFO) << "Drop basicGroupFullInfo of " << chat_id;
  on_update_chat_full_photo(chat_full, chat_id, Photo());
  // chat_full->creator_user_id = UserId();
  chat_full->participants.clear();
  chat_full->bot_commands.clear();
  chat_full->version = -1;
  on_update_chat_full_invite_link(chat_full, nullptr);
  update_chat_online_member_count(chat_full, chat_id, true);
  chat_full->is_changed = true;
  update_chat_full(chat_full, chat_id, "drop_chat_full");
}

void ChatManager::on_update_channel_photo(Channel *c, ChannelId channel_id,
                                          tl_object_ptr<telegram_api::ChatPhoto> &&chat_photo_ptr) {
  on_update_channel_photo(
      c, channel_id,
      get_dialog_photo(td_->file_manager_.get(), DialogId(channel_id), c->access_hash, std::move(chat_photo_ptr)),
      true);
}

void ChatManager::on_update_chat_bot_commands(ChatId chat_id, BotCommands &&bot_commands) {
  auto chat_full = get_chat_full_force(chat_id, "on_update_chat_bot_commands");
  if (chat_full != nullptr && BotCommands::update_all_bot_commands(chat_full->bot_commands, std::move(bot_commands))) {
    chat_full->is_changed = true;
    update_chat_full(chat_full, chat_id, "on_update_chat_bot_commands");
  }
}

void ChatManager::on_update_chat_permanent_invite_link(ChatId chat_id, const DialogInviteLink &invite_link) {
  auto chat_full = get_chat_full_force(chat_id, "on_update_chat_permanent_invite_link");
  if (chat_full != nullptr && update_permanent_invite_link(chat_full->invite_link, invite_link)) {
    chat_full->is_changed = true;
    update_chat_full(chat_full, chat_id, "on_update_chat_permanent_invite_link");
  }
}

void ChatManager::on_update_channel_photo(Channel *c, ChannelId channel_id, DialogPhoto &&photo,
                                          bool invalidate_photo_cache) {
  if (td_->auth_manager_->is_bot()) {
    photo.minithumbnail.clear();
  }

  if (need_update_dialog_photo(c->photo, photo)) {
    LOG(DEBUG) << "Update photo of " << channel_id << " from " << c->photo << " to " << photo;
    c->photo = std::move(photo);
    c->is_photo_changed = true;
    c->need_save_to_database = true;

    if (invalidate_photo_cache) {
      auto channel_full = get_channel_full(channel_id, true, "on_update_channel_photo");  // must not load ChannelFull
      if (channel_full != nullptr) {
        if (!channel_full->photo.is_empty()) {
          channel_full->photo = Photo();
          channel_full->is_changed = true;
        }
        if (c->photo.small_file_id.is_valid()) {
          if (channel_full->expires_at > 0.0) {
            channel_full->expires_at = 0.0;
            channel_full->need_save_to_database = true;
          }
          reload_channel_full(channel_id, Auto(), "on_update_channel_photo");
        }
        update_channel_full(channel_full, channel_id, "on_update_channel_photo");
      }
    }
  } else if (need_update_dialog_photo_minithumbnail(c->photo.minithumbnail, photo.minithumbnail)) {
    c->photo.minithumbnail = std::move(photo.minithumbnail);
    c->is_photo_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_emoji_status(Channel *c, ChannelId channel_id,
                                                 unique_ptr<EmojiStatus> emoji_status) {
  if (c->emoji_status != emoji_status) {
    LOG(DEBUG) << "Change emoji status of " << channel_id << " from " << c->emoji_status << " to " << emoji_status;
    c->emoji_status = std::move(emoji_status);
    c->is_emoji_status_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_accent_color_id(Channel *c, ChannelId channel_id, AccentColorId accent_color_id) {
  if (accent_color_id == AccentColorId(channel_id) || !accent_color_id.is_valid()) {
    accent_color_id = AccentColorId();
  }
  if (c->accent_color_id != accent_color_id) {
    c->accent_color_id = accent_color_id;
    c->is_accent_color_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_background_custom_emoji_id(Channel *c, ChannelId channel_id,
                                                               CustomEmojiId background_custom_emoji_id) {
  if (c->background_custom_emoji_id != background_custom_emoji_id) {
    c->background_custom_emoji_id = background_custom_emoji_id;
    c->is_accent_color_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_profile_accent_color_id(Channel *c, ChannelId channel_id,
                                                            AccentColorId profile_accent_color_id) {
  if (!profile_accent_color_id.is_valid()) {
    profile_accent_color_id = AccentColorId();
  }
  if (c->profile_accent_color_id != profile_accent_color_id) {
    c->profile_accent_color_id = profile_accent_color_id;
    c->is_accent_color_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_profile_background_custom_emoji_id(
    Channel *c, ChannelId channel_id, CustomEmojiId profile_background_custom_emoji_id) {
  if (c->profile_background_custom_emoji_id != profile_background_custom_emoji_id) {
    c->profile_background_custom_emoji_id = profile_background_custom_emoji_id;
    c->is_accent_color_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_title(Channel *c, ChannelId channel_id, string &&title) {
  if (c->title != title) {
    c->title = std::move(title);
    c->is_title_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_status(Channel *c, ChannelId channel_id, DialogParticipantStatus &&status) {
  if (c->status != status) {
    LOG(INFO) << "Update " << channel_id << " status from " << c->status << " to " << status;
    if (c->is_update_supergroup_sent) {
      on_channel_status_changed(c, channel_id, c->status, status);
    }
    c->status = status;
    c->is_status_changed = true;
    c->is_changed = true;
  }
}

void ChatManager::on_channel_status_changed(Channel *c, ChannelId channel_id, const DialogParticipantStatus &old_status,
                                            const DialogParticipantStatus &new_status) {
  CHECK(c->is_update_supergroup_sent);
  bool have_channel_full = get_channel_full(channel_id) != nullptr;

  if (old_status.can_post_stories() != new_status.can_post_stories()) {
    td_->story_manager_->update_dialogs_to_send_stories(channel_id, new_status.can_post_stories());
  }

  bool need_reload_group_call = old_status.can_manage_calls() != new_status.can_manage_calls();
  if (old_status.can_manage_invite_links() && !new_status.can_manage_invite_links()) {
    auto channel_full = get_channel_full(channel_id, true, "on_channel_status_changed");
    if (channel_full != nullptr) {  // otherwise invite_link will be dropped when the channel is loaded
      on_update_channel_full_invite_link(channel_full, nullptr);
      do_invalidate_channel_full(channel_full, channel_id, !c->is_slow_mode_enabled);
      update_channel_full(channel_full, channel_id, "on_channel_status_changed");
    }
  } else {
    invalidate_channel_full(channel_id, !c->is_slow_mode_enabled, "on_channel_status_changed");
  }

  if (old_status.is_creator() != new_status.is_creator()) {
    c->is_creator_changed = true;

    send_get_channel_full_query(nullptr, channel_id, Auto(), "update channel owner");
    td_->dialog_participant_manager_->reload_dialog_administrators(DialogId(channel_id), {}, Auto());
    td_->suggested_action_manager_->remove_dialog_suggested_action(
        SuggestedAction{SuggestedAction::Type::ConvertToGigagroup, DialogId(channel_id)});
  }

  if (old_status.is_member() != new_status.is_member() || new_status.is_banned()) {
    td_->dialog_invite_link_manager_->remove_dialog_access_by_invite_link(DialogId(channel_id));

    if (new_status.is_member() || new_status.is_creator()) {
      reload_channel_full(channel_id,
                          PromiseCreator::lambda([channel_id](Unit) { LOG(INFO) << "Reloaded full " << channel_id; }),
                          "on_channel_status_changed");
    }
  }
  if (need_reload_group_call) {
    send_closure_later(G()->messages_manager(), &MessagesManager::on_update_dialog_group_call_rights,
                       DialogId(channel_id));
  }
  bool is_bot = td_->auth_manager_->is_bot();
  if (is_bot && old_status.is_administrator() && !new_status.is_administrator()) {
    td_->dialog_participant_manager_->drop_channel_participant_cache(channel_id);
  }
  if (is_bot && old_status.is_member() && !new_status.is_member() && !G()->use_message_database()) {
    send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_deleted, DialogId(channel_id),
                       Promise<Unit>());
  }
  if (!is_bot && old_status.is_member() != new_status.is_member()) {
    DialogId dialog_id(channel_id);
    if (new_status.is_member()) {
      send_closure_later(td_->story_manager_actor_, &StoryManager::reload_dialog_expiring_stories, dialog_id);
    } else {
      send_closure_later(td_->story_manager_actor_, &StoryManager::on_dialog_active_stories_order_updated, dialog_id,
                         "on_channel_status_changed");
    }

    send_closure_later(G()->messages_manager(), &MessagesManager::force_create_dialog, dialog_id,
                       "on_channel_status_changed", true, true);
  }

  // must not load ChannelFull, because must not change the Channel
  CHECK(have_channel_full == (get_channel_full(channel_id) != nullptr));
}

void ChatManager::on_update_channel_default_permissions(Channel *c, ChannelId channel_id,
                                                        RestrictedRights default_permissions) {
  if (c->is_megagroup && c->default_permissions != default_permissions) {
    LOG(INFO) << "Update " << channel_id << " default permissions from " << c->default_permissions << " to "
              << default_permissions;
    c->default_permissions = default_permissions;
    c->is_default_permissions_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_has_location(Channel *c, ChannelId channel_id, bool has_location) {
  if (c->has_location != has_location) {
    LOG(INFO) << "Update " << channel_id << " has_location from " << c->has_location << " to " << has_location;
    c->has_location = has_location;
    c->is_has_location_changed = true;
    c->is_changed = true;
  }
}

void ChatManager::on_update_channel_noforwards(Channel *c, ChannelId channel_id, bool noforwards) {
  if (c->noforwards != noforwards) {
    LOG(INFO) << "Update " << channel_id << " has_protected_content from " << c->noforwards << " to " << noforwards;
    c->noforwards = noforwards;
    c->is_noforwards_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_story_ids(ChannelId channel_id, StoryId max_active_story_id,
                                              StoryId max_read_story_id) {
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id;
    return;
  }

  Channel *c = get_channel_force(channel_id, "on_update_channel_story_ids");
  if (c != nullptr) {
    on_update_channel_story_ids_impl(c, channel_id, max_active_story_id, max_read_story_id);
    update_channel(c, channel_id);
  } else {
    LOG(INFO) << "Ignore update channel story identifiers about unknown " << channel_id;
  }
}

void ChatManager::on_update_channel_story_ids_impl(Channel *c, ChannelId channel_id, StoryId max_active_story_id,
                                                   StoryId max_read_story_id) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  if (max_active_story_id != StoryId() && !max_active_story_id.is_server()) {
    LOG(ERROR) << "Receive max active " << max_active_story_id << " for " << channel_id;
    return;
  }
  if (max_read_story_id != StoryId() && !max_read_story_id.is_server()) {
    LOG(ERROR) << "Receive max read " << max_read_story_id << " for " << channel_id;
    return;
  }

  auto has_unread_stories = get_channel_has_unread_stories(c);
  if (c->max_active_story_id != max_active_story_id) {
    LOG(DEBUG) << "Change last active story of " << channel_id << " from " << c->max_active_story_id << " to "
               << max_active_story_id;
    c->max_active_story_id = max_active_story_id;
    c->need_save_to_database = true;
  }
  if (need_poll_channel_active_stories(c, channel_id)) {
    auto max_active_story_id_next_reload_time = Time::now() + MAX_ACTIVE_STORY_ID_RELOAD_TIME;
    if (max_active_story_id_next_reload_time >
        c->max_active_story_id_next_reload_time + MAX_ACTIVE_STORY_ID_RELOAD_TIME / 5) {
      LOG(DEBUG) << "Change max_active_story_id_next_reload_time of " << channel_id;
      c->max_active_story_id_next_reload_time = max_active_story_id_next_reload_time;
      c->need_save_to_database = true;
    }
  }
  if (!max_active_story_id.is_valid()) {
    CHECK(max_read_story_id == StoryId());
    if (c->max_read_story_id != StoryId()) {
      LOG(DEBUG) << "Drop last read " << c->max_read_story_id << " of " << channel_id;
      c->max_read_story_id = StoryId();
      c->need_save_to_database = true;
    }
  } else if (max_read_story_id.get() > c->max_read_story_id.get()) {
    LOG(DEBUG) << "Change last read story of " << channel_id << " from " << c->max_read_story_id << " to "
               << max_read_story_id;
    c->max_read_story_id = max_read_story_id;
    c->need_save_to_database = true;
  }
  if (has_unread_stories != get_channel_has_unread_stories(c)) {
    LOG(DEBUG) << "Change has_unread_stories of " << channel_id << " to " << !has_unread_stories;
    c->is_changed = true;
  }
}

void ChatManager::on_update_channel_max_read_story_id(ChannelId channel_id, StoryId max_read_story_id) {
  CHECK(channel_id.is_valid());

  Channel *c = get_channel(channel_id);
  if (c != nullptr) {
    on_update_channel_max_read_story_id(c, channel_id, max_read_story_id);
    update_channel(c, channel_id);
  }
}

void ChatManager::on_update_channel_max_read_story_id(Channel *c, ChannelId channel_id, StoryId max_read_story_id) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  auto has_unread_stories = get_channel_has_unread_stories(c);
  if (max_read_story_id.get() > c->max_read_story_id.get()) {
    LOG(DEBUG) << "Change last read story of " << channel_id << " from " << c->max_read_story_id << " to "
               << max_read_story_id;
    c->max_read_story_id = max_read_story_id;
    c->need_save_to_database = true;
  }
  if (has_unread_stories != get_channel_has_unread_stories(c)) {
    LOG(DEBUG) << "Change has_unread_stories of " << channel_id << " to " << !has_unread_stories;
    c->is_changed = true;
  }
}

void ChatManager::on_update_channel_stories_hidden(ChannelId channel_id, bool stories_hidden) {
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id;
    return;
  }

  Channel *c = get_channel_force(channel_id, "on_update_channel_stories_hidden");
  if (c != nullptr) {
    on_update_channel_stories_hidden(c, channel_id, stories_hidden);
    update_channel(c, channel_id);
  } else {
    LOG(INFO) << "Ignore update channel stories are archived about unknown " << channel_id;
  }
}

void ChatManager::on_update_channel_stories_hidden(Channel *c, ChannelId channel_id, bool stories_hidden) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (c->stories_hidden != stories_hidden) {
    LOG(DEBUG) << "Change stories are archived of " << channel_id << " to " << stories_hidden;
    c->stories_hidden = stories_hidden;
    c->is_stories_hidden_changed = true;
    c->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_bot_verification_icon(Channel *c, ChannelId channel_id,
                                                          CustomEmojiId bot_verification_icon) {
  if (c->bot_verification_icon != bot_verification_icon) {
    c->bot_verification_icon = bot_verification_icon;
    c->is_changed = true;
  }
}

void ChatManager::on_update_channel_participant_count(ChannelId channel_id, int32 participant_count) {
  Channel *c = get_channel(channel_id);
  if (c == nullptr || c->participant_count == participant_count) {
    return;
  }

  c->participant_count = participant_count;
  c->is_changed = true;
  update_channel(c, channel_id);

  auto channel_full = get_channel_full(channel_id, true, "on_update_channel_participant_count");
  if (channel_full != nullptr && channel_full->participant_count != participant_count) {
    if (channel_full->administrator_count > participant_count) {
      channel_full->administrator_count = participant_count;
    }
    channel_full->participant_count = participant_count;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_participant_count");
  }
}

void ChatManager::on_update_channel_editable_username(ChannelId channel_id, string &&username) {
  Channel *c = get_channel(channel_id);
  CHECK(c != nullptr);
  on_update_channel_usernames(c, channel_id, c->usernames.change_editable_username(std::move(username)));
  update_channel(c, channel_id);
}

void ChatManager::on_update_channel_usernames(ChannelId channel_id, Usernames &&usernames) {
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id;
    return;
  }

  Channel *c = get_channel_force(channel_id, "on_update_channel_usernames");
  if (c != nullptr) {
    on_update_channel_usernames(c, channel_id, std::move(usernames));
    update_channel(c, channel_id);
  } else {
    LOG(INFO) << "Ignore update channel usernames about unknown " << channel_id;
  }
}

void ChatManager::on_update_channel_usernames(Channel *c, ChannelId channel_id, Usernames &&usernames) {
  if (c->usernames != usernames) {
    td_->dialog_manager_->on_dialog_usernames_updated(DialogId(channel_id), c->usernames, usernames);
    td_->messages_manager_->on_dialog_usernames_updated(DialogId(channel_id), c->usernames, usernames);
    if (c->is_update_supergroup_sent) {
      on_channel_usernames_changed(c, channel_id, c->usernames, usernames);
    }

    c->usernames = std::move(usernames);
    c->is_username_changed = true;
    c->is_changed = true;
  } else {
    td_->dialog_manager_->on_dialog_usernames_received(DialogId(channel_id), usernames, false);
  }
}

void ChatManager::on_channel_usernames_changed(const Channel *c, ChannelId channel_id, const Usernames &old_usernames,
                                               const Usernames &new_usernames) {
  bool have_channel_full = get_channel_full(channel_id) != nullptr;
  if (!old_usernames.has_first_username() || !new_usernames.has_first_username()) {
    // moving channel from private to public can change availability of chat members
    invalidate_channel_full(channel_id, !c->is_slow_mode_enabled, "on_channel_usernames_changed");
  }

  // must not load ChannelFull, because must not change the Channel
  CHECK(have_channel_full == (get_channel_full(channel_id) != nullptr));
}

void ChatManager::on_update_channel_description(ChannelId channel_id, string &&description) {
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_description");
  if (channel_full == nullptr) {
    return;
  }
  if (channel_full->description != description) {
    channel_full->description = std::move(description);
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_description");
    td_->group_call_manager_->on_update_dialog_about(DialogId(channel_id), channel_full->description, true);
  }
}

void ChatManager::on_update_channel_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id) {
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_sticker_set");
  if (channel_full == nullptr) {
    return;
  }
  if (channel_full->sticker_set_id != sticker_set_id) {
    channel_full->sticker_set_id = sticker_set_id;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_sticker_set");
  }
}

void ChatManager::on_update_channel_emoji_sticker_set(ChannelId channel_id, StickerSetId sticker_set_id) {
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_emoji_sticker_set");
  if (channel_full == nullptr) {
    return;
  }
  if (channel_full->emoji_sticker_set_id != sticker_set_id) {
    channel_full->emoji_sticker_set_id = sticker_set_id;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_emoji_sticker_set");
  }
}

void ChatManager::on_update_channel_unrestrict_boost_count(ChannelId channel_id, int32 unrestrict_boost_count) {
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_unrestrict_boost_count");
  if (channel_full == nullptr) {
    return;
  }
  if (channel_full->unrestrict_boost_count != unrestrict_boost_count) {
    channel_full->unrestrict_boost_count = unrestrict_boost_count;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_unrestrict_boost_count");
  }
}

void ChatManager::on_update_channel_gift_count(ChannelId channel_id, int32 gift_count, bool is_added) {
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_gift_count");
  if (channel_full == nullptr) {
    return;
  }
  if (is_added) {
    gift_count = max(0, channel_full->gift_count + gift_count);
  } else if (gift_count < 0) {
    LOG(ERROR) << "Receive " << gift_count << " as gift count with " << channel_id;
    gift_count = 0;
  }
  if (channel_full->gift_count != gift_count) {
    channel_full->gift_count = gift_count;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_gift_count");
  }
}

void ChatManager::on_update_channel_linked_channel_id(ChannelId channel_id, ChannelId group_channel_id) {
  if (channel_id.is_valid()) {
    auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_linked_channel_id 1");
    on_update_channel_full_linked_channel_id(channel_full, channel_id, group_channel_id);
    if (channel_full != nullptr) {
      update_channel_full(channel_full, channel_id, "on_update_channel_linked_channel_id 3");
    }
  }
  if (group_channel_id.is_valid()) {
    auto channel_full = get_channel_full_force(group_channel_id, true, "on_update_channel_linked_channel_id 2");
    on_update_channel_full_linked_channel_id(channel_full, group_channel_id, channel_id);
    if (channel_full != nullptr) {
      update_channel_full(channel_full, group_channel_id, "on_update_channel_linked_channel_id 4");
    }
  }
}

void ChatManager::on_update_channel_location(ChannelId channel_id, const DialogLocation &location) {
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_location");
  if (channel_full != nullptr) {
    on_update_channel_full_location(channel_full, channel_id, location);
    update_channel_full(channel_full, channel_id, "on_update_channel_location");
  }
}

void ChatManager::on_update_channel_slow_mode_delay(ChannelId channel_id, int32 slow_mode_delay,
                                                    Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_slow_mode_delay");
  if (channel_full != nullptr) {
    on_update_channel_full_slow_mode_delay(channel_full, channel_id, slow_mode_delay, 0);
    update_channel_full(channel_full, channel_id, "on_update_channel_slow_mode_delay");
  }
  promise.set_value(Unit());
}

void ChatManager::on_update_channel_slow_mode_next_send_date(ChannelId channel_id, int32 slow_mode_next_send_date) {
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_slow_mode_next_send_date");
  if (channel_full != nullptr) {
    on_update_channel_full_slow_mode_next_send_date(channel_full, slow_mode_next_send_date);
    update_channel_full(channel_full, channel_id, "on_update_channel_slow_mode_next_send_date");
  }
}

void ChatManager::on_update_channel_bot_user_ids(ChannelId channel_id, vector<UserId> &&bot_user_ids) {
  CHECK(channel_id.is_valid());
  if (!have_channel(channel_id)) {
    LOG(ERROR) << channel_id << " not found";
    return;
  }

  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_bot_user_ids");
  if (channel_full == nullptr) {
    send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(channel_id),
                       std::move(bot_user_ids), false);
    return;
  }
  on_update_channel_full_bot_user_ids(channel_full, channel_id, std::move(bot_user_ids));
  update_channel_full(channel_full, channel_id, "on_update_channel_bot_user_ids");
}

void ChatManager::on_update_channel_full_bot_user_ids(ChannelFull *channel_full, ChannelId channel_id,
                                                      vector<UserId> &&bot_user_ids) {
  CHECK(channel_full != nullptr);
  send_closure_later(G()->messages_manager(), &MessagesManager::on_dialog_bots_updated, DialogId(channel_id),
                     bot_user_ids, false);
  if (channel_full->bot_user_ids != bot_user_ids) {
    channel_full->bot_user_ids = std::move(bot_user_ids);
    channel_full->need_save_to_database = true;
  }
}

void ChatManager::on_update_channel_is_all_history_available(ChannelId channel_id, bool is_all_history_available,
                                                             Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_is_all_history_available");
  if (channel_full != nullptr && channel_full->is_all_history_available != is_all_history_available) {
    channel_full->is_all_history_available = is_all_history_available;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_is_all_history_available");
  }
  promise.set_value(Unit());
}

void ChatManager::on_update_channel_can_have_sponsored_messages(ChannelId channel_id, bool can_have_sponsored_messages,
                                                                Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_can_have_sponsored_messages");
  if (channel_full != nullptr && channel_full->can_have_sponsored_messages != can_have_sponsored_messages) {
    channel_full->can_have_sponsored_messages = can_have_sponsored_messages;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_can_have_sponsored_messages");
  }
  promise.set_value(Unit());
}

void ChatManager::on_update_channel_has_hidden_participants(ChannelId channel_id, bool has_hidden_participants,
                                                            Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_has_hidden_participants");
  if (channel_full != nullptr && channel_full->has_hidden_participants != has_hidden_participants) {
    channel_full->has_hidden_participants = has_hidden_participants;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_has_hidden_participants");
  }
  promise.set_value(Unit());
}

void ChatManager::on_update_channel_has_aggressive_anti_spam_enabled(ChannelId channel_id,
                                                                     bool has_aggressive_anti_spam_enabled,
                                                                     Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  CHECK(channel_id.is_valid());
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_has_aggressive_anti_spam_enabled");
  if (channel_full != nullptr && channel_full->has_aggressive_anti_spam_enabled != has_aggressive_anti_spam_enabled) {
    channel_full->has_aggressive_anti_spam_enabled = has_aggressive_anti_spam_enabled;
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_has_aggressive_anti_spam_enabled");
  }
  promise.set_value(Unit());
}

void ChatManager::on_update_channel_has_pinned_stories(ChannelId channel_id, bool has_pinned_stories) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id;
    return;
  }

  ChannelFull *channel_full = get_channel_full_force(channel_id, true, "on_update_channel_has_pinned_stories");
  if (channel_full == nullptr || channel_full->has_pinned_stories == has_pinned_stories) {
    return;
  }
  channel_full->has_pinned_stories = has_pinned_stories;
  channel_full->is_changed = true;
  update_channel_full(channel_full, channel_id, "on_update_channel_has_pinned_stories");
}

void ChatManager::on_update_channel_default_permissions(ChannelId channel_id, RestrictedRights default_permissions) {
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id;
    return;
  }

  Channel *c = get_channel_force(channel_id, "on_update_channel_default_permissions");
  if (c != nullptr) {
    on_update_channel_default_permissions(c, channel_id, std::move(default_permissions));
    update_channel(c, channel_id);
  } else {
    LOG(INFO) << "Ignore update channel default permissions about unknown " << channel_id;
  }
}

FileSourceId ChatManager::get_chat_full_file_source_id(ChatId chat_id) {
  if (!chat_id.is_valid()) {
    return FileSourceId();
  }

  auto chat_full = get_chat_full(chat_id);
  if (chat_full != nullptr) {
    VLOG(file_references) << "Don't need to create file source for full " << chat_id;
    // chat full was already added, source ID was registered and shouldn't be needed
    return chat_full->is_update_chat_full_sent ? FileSourceId() : chat_full->file_source_id;
  }

  auto &source_id = chat_full_file_source_ids_[chat_id];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_chat_full_file_source(chat_id);
  }
  VLOG(file_references) << "Return " << source_id << " for full " << chat_id;
  return source_id;
}

FileSourceId ChatManager::get_channel_full_file_source_id(ChannelId channel_id) {
  if (!channel_id.is_valid()) {
    return FileSourceId();
  }

  auto channel_full = get_channel_full(channel_id);
  if (channel_full != nullptr) {
    VLOG(file_references) << "Don't need to create file source for full " << channel_id;
    // channel full was already added, source ID was registered and shouldn't be needed
    return channel_full->is_update_channel_full_sent ? FileSourceId() : channel_full->file_source_id;
  }

  auto &source_id = channel_full_file_source_ids_[channel_id];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_channel_full_file_source(channel_id);
  }
  VLOG(file_references) << "Return " << source_id << " for full " << channel_id;
  return source_id;
}

void ChatManager::create_new_chat(const vector<UserId> &user_ids, const string &title, MessageTtl message_ttl,
                                  Promise<td_api::object_ptr<td_api::createdBasicGroupChat>> &&promise) {
  auto new_title = clean_name(title, MAX_TITLE_LENGTH);
  if (new_title.empty()) {
    return promise.set_error(Status::Error(400, "Title must be non-empty"));
  }

  vector<telegram_api::object_ptr<telegram_api::InputUser>> input_users;
  for (auto user_id : user_ids) {
    TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));
    input_users.push_back(std::move(input_user));
  }

  td_->create_handler<CreateChatQuery>(std::move(promise))->send(std::move(input_users), new_title, message_ttl);
}

void ChatManager::create_new_channel(const string &title, bool is_forum, bool is_megagroup, const string &description,
                                     const DialogLocation &location, bool for_import, MessageTtl message_ttl,
                                     Promise<td_api::object_ptr<td_api::chat>> &&promise) {
  auto new_title = clean_name(title, MAX_TITLE_LENGTH);
  if (new_title.empty()) {
    return promise.set_error(Status::Error(400, "Title must be non-empty"));
  }

  td_->create_handler<CreateChannelQuery>(std::move(promise))
      ->send(new_title, is_forum, is_megagroup, strip_empty_characters(description, MAX_DESCRIPTION_LENGTH), location,
             for_import, message_ttl);
}

bool ChatManager::have_chat(ChatId chat_id) const {
  return chats_.count(chat_id) > 0;
}

const ChatManager::Chat *ChatManager::get_chat(ChatId chat_id) const {
  return chats_.get_pointer(chat_id);
}

ChatManager::Chat *ChatManager::get_chat(ChatId chat_id) {
  return chats_.get_pointer(chat_id);
}

ChatManager::Chat *ChatManager::add_chat(ChatId chat_id) {
  CHECK(chat_id.is_valid());
  auto &chat_ptr = chats_[chat_id];
  if (chat_ptr == nullptr) {
    chat_ptr = make_unique<Chat>();
  }
  return chat_ptr.get();
}

bool ChatManager::get_chat(ChatId chat_id, int left_tries, Promise<Unit> &&promise) {
  if (!chat_id.is_valid()) {
    promise.set_error(Status::Error(400, "Invalid basic group identifier"));
    return false;
  }

  if (!have_chat(chat_id)) {
    if (left_tries > 2 && G()->use_chat_info_database()) {
      send_closure_later(actor_id(this), &ChatManager::load_chat_from_database, nullptr, chat_id, std::move(promise));
      return false;
    }

    if (left_tries > 1) {
      get_chat_queries_.add_query(chat_id.get(), std::move(promise), "get_chat");
      return false;
    }

    promise.set_error(Status::Error(400, "Group not found"));
    return false;
  }

  promise.set_value(Unit());
  return true;
}

void ChatManager::reload_chat(ChatId chat_id, Promise<Unit> &&promise, const char *source) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (!chat_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid basic group identifier"));
  }

  get_chat_queries_.add_query(chat_id.get(), std::move(promise), source);
}

const ChatManager::ChatFull *ChatManager::get_chat_full(ChatId chat_id) const {
  return chats_full_.get_pointer(chat_id);
}

ChatManager::ChatFull *ChatManager::get_chat_full(ChatId chat_id) {
  return chats_full_.get_pointer(chat_id);
}

ChatManager::ChatFull *ChatManager::add_chat_full(ChatId chat_id) {
  CHECK(chat_id.is_valid());
  auto &chat_full_ptr = chats_full_[chat_id];
  if (chat_full_ptr == nullptr) {
    chat_full_ptr = make_unique<ChatFull>();
  }
  return chat_full_ptr.get();
}

bool ChatManager::is_chat_full_outdated(const ChatFull *chat_full, const Chat *c, ChatId chat_id,
                                        bool only_participants) const {
  CHECK(c != nullptr);
  CHECK(chat_full != nullptr);
  if (!c->is_active && chat_full->version == -1) {
    return false;
  }

  if (chat_full->version != c->version) {
    LOG(INFO) << "Have outdated ChatFull " << chat_id << " with current version " << chat_full->version
              << " and chat version " << c->version;
    return true;
  }

  if (!only_participants && c->is_active && c->status.can_manage_invite_links() && !chat_full->invite_link.is_valid()) {
    LOG(INFO) << "Have outdated invite link in " << chat_id;
    return true;
  }

  if (!only_participants &&
      !is_same_dialog_photo(td_->file_manager_.get(), DialogId(chat_id), chat_full->photo, c->photo, false)) {
    LOG(INFO) << "Have outdated chat photo in " << chat_id;
    return true;
  }

  LOG(DEBUG) << "Full " << chat_id << " is up-to-date with version " << chat_full->version << " and photos " << c->photo
             << '/' << chat_full->photo;
  return false;
}

void ChatManager::load_chat_full(ChatId chat_id, bool force, Promise<Unit> &&promise, const char *source) {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Group not found"));
  }

  auto chat_full = get_chat_full_force(chat_id, source);
  if (chat_full == nullptr) {
    LOG(INFO) << "Full " << chat_id << " not found";
    return send_get_chat_full_query(chat_id, std::move(promise), source);
  }

  if (is_chat_full_outdated(chat_full, c, chat_id, false)) {
    LOG(INFO) << "Have outdated full " << chat_id;
    if (td_->auth_manager_->is_bot() && !force) {
      return send_get_chat_full_query(chat_id, std::move(promise), source);
    }

    send_get_chat_full_query(chat_id, Auto(), source);
  }

  vector<DialogId> participant_dialog_ids;
  for (const auto &dialog_participant : chat_full->participants) {
    participant_dialog_ids.push_back(dialog_participant.dialog_id_);
  }
  td_->story_manager_->on_view_dialog_active_stories(std::move(participant_dialog_ids));

  promise.set_value(Unit());
}

void ChatManager::reload_chat_full(ChatId chat_id, Promise<Unit> &&promise, const char *source) {
  send_get_chat_full_query(chat_id, std::move(promise), source);
}

void ChatManager::send_get_chat_full_query(ChatId chat_id, Promise<Unit> &&promise, const char *source) {
  LOG(INFO) << "Get full " << chat_id << " from " << source;
  if (!chat_id.is_valid()) {
    return promise.set_error(Status::Error(500, "Invalid chat_id"));
  }
  auto send_query = PromiseCreator::lambda([td = td_, chat_id](Result<Promise<Unit>> &&promise) {
    if (promise.is_ok() && !G()->close_flag()) {
      td->create_handler<GetFullChatQuery>(promise.move_as_ok())->send(chat_id);
    }
  });

  get_chat_full_queries_.add_query(DialogId(chat_id).get(), std::move(send_query), std::move(promise));
}

int32 ChatManager::get_chat_date(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return 0;
  }
  return c->date;
}

int32 ChatManager::get_chat_participant_count(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return 0;
  }
  return c->participant_count;
}

bool ChatManager::get_chat_is_active(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return false;
  }
  return c->is_active;
}

ChannelId ChatManager::get_chat_migrated_to_channel_id(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return ChannelId();
  }
  return c->migrated_to_channel_id;
}

DialogParticipantStatus ChatManager::get_chat_status(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return DialogParticipantStatus::Banned(0);
  }
  return get_chat_status(c);
}

DialogParticipantStatus ChatManager::get_chat_status(const Chat *c) {
  if (!c->is_active) {
    return DialogParticipantStatus::Banned(0);
  }
  return c->status;
}

DialogParticipantStatus ChatManager::get_chat_permissions(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return DialogParticipantStatus::Banned(0);
  }
  return get_chat_permissions(c);
}

DialogParticipantStatus ChatManager::get_chat_permissions(const Chat *c) const {
  if (!c->is_active) {
    return DialogParticipantStatus::Banned(0);
  }
  return c->status.apply_restrictions(c->default_permissions, false, td_->auth_manager_->is_bot());
}

bool ChatManager::is_appointed_chat_administrator(ChatId chat_id) const {
  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return false;
  }
  return c->status.is_administrator();
}

bool ChatManager::is_channel_public(ChannelId channel_id) const {
  return is_channel_public(get_channel(channel_id));
}

bool ChatManager::is_channel_public(const Channel *c) {
  return c != nullptr && (c->usernames.has_first_username() || c->has_location);
}

ChannelType ChatManager::get_channel_type(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    auto min_channel = get_min_channel(channel_id);
    if (min_channel != nullptr) {
      return min_channel->is_megagroup_ ? ChannelType::Megagroup : ChannelType::Broadcast;
    }
    return ChannelType::Unknown;
  }
  return get_channel_type(c);
}

ChannelType ChatManager::get_channel_type(const Channel *c) {
  if (c->is_megagroup) {
    return ChannelType::Megagroup;
  }
  return ChannelType::Broadcast;
}

bool ChatManager::is_broadcast_channel(ChannelId channel_id) const {
  return get_channel_type(channel_id) == ChannelType::Broadcast;
}

bool ChatManager::is_megagroup_channel(ChannelId channel_id) const {
  return get_channel_type(channel_id) == ChannelType::Megagroup;
}

bool ChatManager::is_forum_channel(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return c->is_forum;
}

int32 ChatManager::get_channel_date(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return 0;
  }
  return c->date;
}

DialogParticipantStatus ChatManager::get_channel_status(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return DialogParticipantStatus::Banned(0);
  }
  return get_channel_status(c);
}

DialogParticipantStatus ChatManager::get_channel_status(const Channel *c) {
  c->status.update_restrictions();
  return c->status;
}

DialogParticipantStatus ChatManager::get_channel_permissions(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return DialogParticipantStatus::Banned(0);
  }
  return get_channel_permissions(channel_id, c);
}

DialogParticipantStatus ChatManager::get_channel_permissions(ChannelId channel_id, const Channel *c) const {
  c->status.update_restrictions();
  bool is_booster = false;
  if (!td_->auth_manager_->is_bot() && c->is_megagroup) {
    auto channel_full = get_channel_full_const(channel_id);
    if (channel_full == nullptr || (channel_full->unrestrict_boost_count > 0 &&
                                    channel_full->boost_count >= channel_full->unrestrict_boost_count)) {
      is_booster = true;
    }
  }
  return c->status.apply_restrictions(c->default_permissions, is_booster, td_->auth_manager_->is_bot());
}

int32 ChatManager::get_channel_participant_count(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return 0;
  }
  return c->participant_count;
}

bool ChatManager::get_channel_is_verified(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return c->is_verified;
}

td_api::object_ptr<td_api::verificationStatus> ChatManager::get_channel_verification_status_object(
    ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return nullptr;
  }
  return get_channel_verification_status_object(c);
}

td_api::object_ptr<td_api::verificationStatus> ChatManager::get_channel_verification_status_object(
    const Channel *c) const {
  return get_verification_status_object(td_, c->is_verified, c->is_scam, c->is_fake, c->bot_verification_icon);
}

bool ChatManager::get_channel_sign_messages(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return get_channel_sign_messages(c);
}

bool ChatManager::get_channel_sign_messages(const Channel *c) {
  return c->sign_messages;
}

bool ChatManager::get_channel_show_message_sender(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return get_channel_show_message_sender(c);
}

bool ChatManager::get_channel_show_message_sender(const Channel *c) {
  return c->show_message_sender;
}

bool ChatManager::get_channel_has_linked_channel(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return get_channel_has_linked_channel(c);
}

bool ChatManager::get_channel_has_linked_channel(const Channel *c) {
  return c->has_linked_channel;
}

bool ChatManager::get_channel_can_be_deleted(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return get_channel_can_be_deleted(c);
}

bool ChatManager::get_channel_can_be_deleted(const Channel *c) {
  return c->can_be_deleted;
}

bool ChatManager::get_channel_join_to_send(const Channel *c) {
  return c->join_to_send || !c->is_megagroup || !c->has_linked_channel;
}

bool ChatManager::get_channel_join_request(ChannelId channel_id) const {
  auto c = get_channel(channel_id);
  if (c == nullptr) {
    return false;
  }
  return get_channel_join_request(c);
}

bool ChatManager::get_channel_join_request(const Channel *c) {
  return c->join_request && c->is_megagroup && (is_channel_public(c) || c->has_linked_channel);
}

ChannelId ChatManager::get_channel_linked_channel_id(ChannelId channel_id, const char *source) {
  auto channel_full = get_channel_full_const(channel_id);
  if (channel_full == nullptr) {
    channel_full = get_channel_full_force(channel_id, true, source);
    if (channel_full == nullptr) {
      return ChannelId();
    }
  }
  return channel_full->linked_channel_id;
}

int32 ChatManager::get_channel_slow_mode_delay(ChannelId channel_id, const char *source) {
  auto channel_full = get_channel_full_const(channel_id);
  if (channel_full == nullptr) {
    channel_full = get_channel_full_force(channel_id, true, source);
    if (channel_full == nullptr) {
      return 0;
    }
  }
  return channel_full->slow_mode_delay;
}

bool ChatManager::get_channel_effective_has_hidden_participants(ChannelId channel_id, const char *source) {
  auto c = get_channel_force(channel_id, "get_channel_effective_has_hidden_participants");
  if (c == nullptr) {
    return true;
  }
  if (get_channel_status(c).is_administrator()) {
    return false;
  }

  auto channel_full = get_channel_full_const(channel_id);
  if (channel_full == nullptr) {
    channel_full = get_channel_full_force(channel_id, true, source);
    if (channel_full == nullptr) {
      return true;
    }
  }
  return channel_full->has_hidden_participants || !channel_full->can_get_participants;
}

int32 ChatManager::get_channel_my_boost_count(ChannelId channel_id) {
  auto channel_full = get_channel_full_const(channel_id);
  if (channel_full == nullptr) {
    channel_full = get_channel_full_force(channel_id, true, "get_channel_my_boost_count");
    if (channel_full == nullptr) {
      return 0;
    }
  }
  return channel_full->boost_count;
}

bool ChatManager::have_channel(ChannelId channel_id) const {
  return channels_.count(channel_id) > 0;
}

bool ChatManager::have_min_channel(ChannelId channel_id) const {
  return min_channels_.count(channel_id) > 0;
}

const MinChannel *ChatManager::get_min_channel(ChannelId channel_id) const {
  return min_channels_.get_pointer(channel_id);
}

void ChatManager::add_min_channel(ChannelId channel_id, const MinChannel &min_channel) {
  if (have_channel(channel_id) || have_min_channel(channel_id) || !channel_id.is_valid()) {
    return;
  }
  min_channels_.set(channel_id, td::make_unique<MinChannel>(min_channel));
}

const ChatManager::Channel *ChatManager::get_channel(ChannelId channel_id) const {
  return channels_.get_pointer(channel_id);
}

ChatManager::Channel *ChatManager::get_channel(ChannelId channel_id) {
  return channels_.get_pointer(channel_id);
}

ChatManager::Channel *ChatManager::add_channel(ChannelId channel_id, const char *source) {
  CHECK(channel_id.is_valid());
  auto &channel_ptr = channels_[channel_id];
  if (channel_ptr == nullptr) {
    channel_ptr = make_unique<Channel>();
    min_channels_.erase(channel_id);
  }
  return channel_ptr.get();
}

bool ChatManager::get_channel(ChannelId channel_id, int left_tries, Promise<Unit> &&promise) {
  if (!channel_id.is_valid()) {
    promise.set_error(Status::Error(400, "Invalid supergroup identifier"));
    return false;
  }

  if (!have_channel(channel_id)) {
    if (left_tries > 2 && G()->use_chat_info_database()) {
      send_closure_later(actor_id(this), &ChatManager::load_channel_from_database, nullptr, channel_id,
                         std::move(promise));
      return false;
    }

    if (left_tries > 1 && td_->auth_manager_->is_bot()) {
      get_channel_queries_.add_query(channel_id.get(), std::move(promise), "get_channel");
      return false;
    }

    promise.set_error(Status::Error(400, "Supergroup not found"));
    return false;
  }

  promise.set_value(Unit());
  return true;
}

void ChatManager::reload_channel(ChannelId channel_id, Promise<Unit> &&promise, const char *source) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (!channel_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid supergroup identifier"));
  }

  have_channel_force(channel_id, source);
  auto input_channel = get_input_channel(channel_id);
  if (input_channel == nullptr) {
    // requests with 0 access_hash must not be merged
    td_->create_handler<GetChannelsQuery>(std::move(promise))
        ->send(telegram_api::make_object<telegram_api::inputChannel>(channel_id.get(), 0));
    return;
  }

  get_channel_queries_.add_query(channel_id.get(), std::move(promise), source);
}

const ChatManager::ChannelFull *ChatManager::get_channel_full_const(ChannelId channel_id) const {
  return channels_full_.get_pointer(channel_id);
}

const ChatManager::ChannelFull *ChatManager::get_channel_full(ChannelId channel_id) const {
  return channels_full_.get_pointer(channel_id);
}

ChatManager::ChannelFull *ChatManager::get_channel_full(ChannelId channel_id, bool only_local, const char *source) {
  auto channel_full = channels_full_.get_pointer(channel_id);
  if (channel_full == nullptr) {
    return nullptr;
  }

  if (!only_local && channel_full->is_expired() && !td_->auth_manager_->is_bot()) {
    send_get_channel_full_query(channel_full, channel_id, Auto(), source);
  }

  return channel_full;
}

ChatManager::ChannelFull *ChatManager::add_channel_full(ChannelId channel_id) {
  CHECK(channel_id.is_valid());
  auto &channel_full_ptr = channels_full_[channel_id];
  if (channel_full_ptr == nullptr) {
    channel_full_ptr = make_unique<ChannelFull>();
  }
  return channel_full_ptr.get();
}

void ChatManager::load_channel_full(ChannelId channel_id, bool force, Promise<Unit> &&promise, const char *source) {
  auto channel_full = get_channel_full_force(channel_id, true, source);
  if (channel_full == nullptr) {
    return send_get_channel_full_query(channel_full, channel_id, std::move(promise), source);
  }
  if (channel_full->is_expired()) {
    if (td_->auth_manager_->is_bot() && !force) {
      return send_get_channel_full_query(channel_full, channel_id, std::move(promise), "load expired channel_full");
    }

    Promise<Unit> new_promise;
    if (promise) {
      new_promise = PromiseCreator::lambda([channel_id](Result<Unit> result) {
        if (result.is_error()) {
          LOG(INFO) << "Failed to reload expired " << channel_id << ": " << result.error();
        } else {
          LOG(INFO) << "Reloaded expired " << channel_id;
        }
      });
    }
    send_get_channel_full_query(channel_full, channel_id, std::move(new_promise), "load expired channel_full");
  }

  promise.set_value(Unit());
}

void ChatManager::reload_channel_full(ChannelId channel_id, Promise<Unit> &&promise, const char *source) {
  send_get_channel_full_query(get_channel_full(channel_id, true, "reload_channel_full"), channel_id, std::move(promise),
                              source);
}

void ChatManager::send_get_channel_full_query(ChannelFull *channel_full, ChannelId channel_id, Promise<Unit> &&promise,
                                              const char *source) {
  auto input_channel = get_input_channel(channel_id);
  if (input_channel == nullptr) {
    return promise.set_error(Status::Error(400, "Supergroup not found"));
  }

  if (!have_input_peer_channel(channel_id, AccessRights::Read)) {
    return promise.set_error(Status::Error(400, "Can't access the chat"));
  }

  if (channel_full != nullptr) {
    if (!promise) {
      if (channel_full->repair_request_version != 0) {
        LOG(INFO) << "Skip get full " << channel_id << " request from " << source;
        return;
      }
      channel_full->repair_request_version = channel_full->speculative_version;
    } else {
      channel_full->repair_request_version = std::numeric_limits<uint32>::max();
    }
  }

  LOG(INFO) << "Get full " << channel_id << " from " << source;
  auto send_query = PromiseCreator::lambda(
      [td = td_, channel_id, input_channel = std::move(input_channel)](Result<Promise<Unit>> &&promise) mutable {
        if (promise.is_ok() && !G()->close_flag()) {
          td->create_handler<GetFullChannelQuery>(promise.move_as_ok())->send(channel_id, std::move(input_channel));
        }
      });
  get_chat_full_queries_.add_query(DialogId(channel_id).get(), std::move(send_query), std::move(promise));
}

void ChatManager::get_chat_participant(ChatId chat_id, UserId user_id, Promise<DialogParticipant> &&promise) {
  LOG(INFO) << "Trying to get " << user_id << " as member of " << chat_id;

  auto c = get_chat(chat_id);
  if (c == nullptr) {
    return promise.set_error(Status::Error(400, "Group not found"));
  }

  if (td_->auth_manager_->is_bot() && user_id == td_->user_manager_->get_my_id()) {
    // bots don't need inviter information
    reload_chat(chat_id, Auto(), "get_chat_participant");
    return promise.set_value(DialogParticipant{DialogId(user_id), user_id, c->date, c->status});
  }

  auto chat_full = get_chat_full_force(chat_id, "get_chat_participant");
  if (chat_full == nullptr || (td_->auth_manager_->is_bot() && is_chat_full_outdated(chat_full, c, chat_id, true))) {
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this), chat_id, user_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
          TRY_STATUS_PROMISE(promise, std::move(result));
          send_closure(actor_id, &ChatManager::finish_get_chat_participant, chat_id, user_id, std::move(promise));
        });
    send_get_chat_full_query(chat_id, std::move(query_promise), "get_chat_participant");
    return;
  }

  if (is_chat_full_outdated(chat_full, c, chat_id, true)) {
    send_get_chat_full_query(chat_id, Auto(), "get_chat_participant lazy");
  }

  finish_get_chat_participant(chat_id, user_id, std::move(promise));
}

void ChatManager::finish_get_chat_participant(ChatId chat_id, UserId user_id, Promise<DialogParticipant> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  const auto *participant = get_chat_participant(chat_id, user_id);
  if (participant == nullptr) {
    return promise.set_value(DialogParticipant::left(DialogId(user_id)));
  }

  promise.set_value(DialogParticipant(*participant));
}

void ChatManager::on_update_channel_administrator_count(ChannelId channel_id, int32 administrator_count) {
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_administrator_count");
  if (channel_full != nullptr && channel_full->administrator_count != administrator_count) {
    channel_full->administrator_count = administrator_count;
    channel_full->is_changed = true;

    if (channel_full->participant_count < channel_full->administrator_count) {
      channel_full->participant_count = channel_full->administrator_count;

      auto c = get_channel(channel_id);
      if (c != nullptr && c->participant_count != channel_full->participant_count) {
        c->participant_count = channel_full->participant_count;
        c->is_changed = true;
        update_channel(c, channel_id);
      }
    }

    update_channel_full(channel_full, channel_id, "on_update_channel_administrator_count");
  }
}

void ChatManager::on_update_channel_bot_commands(ChannelId channel_id, BotCommands &&bot_commands) {
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_bot_commands");
  if (channel_full != nullptr &&
      BotCommands::update_all_bot_commands(channel_full->bot_commands, std::move(bot_commands))) {
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_bot_commands");
  }
}

void ChatManager::on_update_channel_permanent_invite_link(ChannelId channel_id, const DialogInviteLink &invite_link) {
  auto channel_full = get_channel_full_force(channel_id, true, "on_update_channel_permanent_invite_link");
  if (channel_full != nullptr && update_permanent_invite_link(channel_full->invite_link, invite_link)) {
    channel_full->is_changed = true;
    update_channel_full(channel_full, channel_id, "on_update_channel_permanent_invite_link");
  }
}

void ChatManager::on_get_chat_empty(telegram_api::chatEmpty &chat, const char *source) {
  ChatId chat_id(chat.id_);
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id << " from " << source;
    return;
  }

  if (!have_chat(chat_id)) {
    LOG(ERROR) << "Have no information about " << chat_id << " but received chatEmpty from " << source;
  }
}

void ChatManager::on_get_chat(telegram_api::chat &chat, const char *source) {
  auto debug_str = PSTRING() << " from " << source << " in " << oneline(to_string(chat));
  ChatId chat_id(chat.id_);
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id << debug_str;
    return;
  }

  DialogParticipantStatus status = [&] {
    if (chat.creator_) {
      return DialogParticipantStatus::Creator(!chat.left_, false, string());
    } else if (chat.admin_rights_ != nullptr) {
      return DialogParticipantStatus(false, std::move(chat.admin_rights_), string(), ChannelType::Unknown);
    } else if (chat.left_) {
      return DialogParticipantStatus::Left();
    } else {
      return DialogParticipantStatus::Member(0);
    }
  }();

  ChannelId migrated_to_channel_id;
  if (chat.migrated_to_ != nullptr) {
    switch (chat.migrated_to_->get_id()) {
      case telegram_api::inputChannelFromMessage::ID:
      case telegram_api::inputChannelEmpty::ID:
        LOG(ERROR) << "Receive invalid information about upgraded supergroup for " << chat_id << debug_str;
        break;
      case telegram_api::inputChannel::ID: {
        auto input_channel = move_tl_object_as<telegram_api::inputChannel>(chat.migrated_to_);
        migrated_to_channel_id = ChannelId(input_channel->channel_id_);
        if (!have_channel_force(migrated_to_channel_id, source)) {
          if (!migrated_to_channel_id.is_valid()) {
            LOG(ERROR) << "Receive invalid " << migrated_to_channel_id << debug_str;
          } else {
            // temporarily create the channel
            Channel *c = add_channel(migrated_to_channel_id, "on_get_chat");
            c->access_hash = input_channel->access_hash_;
            c->title = chat.title_;
            c->status = DialogParticipantStatus::Left();
            c->is_megagroup = true;

            // we definitely need to call update_channel, because client should know about every added channel
            update_channel(c, migrated_to_channel_id);

            // get info about the channel
            get_channel_queries_.add_query(migrated_to_channel_id.get(), Promise<Unit>(), "on_get_chat");
          }
        }
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  Chat *c = get_chat_force(chat_id, source);  // to load versions
  if (c == nullptr) {
    c = add_chat(chat_id);
  }
  on_update_chat_title(c, chat_id, std::move(chat.title_));
  if (!status.is_left()) {
    on_update_chat_participant_count(c, chat_id, chat.participants_count_, chat.version_, debug_str);
  } else {
    chat.photo_ = nullptr;
  }
  if (c->date != chat.date_) {
    LOG_IF(ERROR, c->date != 0) << "Chat creation date has changed from " << c->date << " to " << chat.date_
                                << debug_str;
    c->date = chat.date_;
    c->need_save_to_database = true;
  }
  on_update_chat_status(c, chat_id, std::move(status));
  on_update_chat_default_permissions(c, chat_id, RestrictedRights(chat.default_banned_rights_, ChannelType::Unknown),
                                     chat.version_);
  on_update_chat_photo(c, chat_id, std::move(chat.photo_));
  on_update_chat_active(c, chat_id, !chat.deactivated_);
  on_update_chat_noforwards(c, chat_id, chat.noforwards_);
  on_update_chat_migrated_to_channel_id(c, chat_id, migrated_to_channel_id);
  LOG_IF(INFO, !c->is_active && !migrated_to_channel_id.is_valid()) << chat_id << " is deactivated" << debug_str;
  if (c->cache_version != Chat::CACHE_VERSION) {
    c->cache_version = Chat::CACHE_VERSION;
    c->need_save_to_database = true;
  }
  c->is_received_from_server = true;
  update_chat(c, chat_id);

  td_->messages_manager_->on_update_dialog_group_call(DialogId(chat_id), chat.call_active_, !chat.call_not_empty_,
                                                      "receive chat");
}

void ChatManager::on_get_chat_forbidden(telegram_api::chatForbidden &chat, const char *source) {
  ChatId chat_id(chat.id_);
  if (!chat_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << chat_id << " from " << source;
    return;
  }

  bool is_uninited = get_chat_force(chat_id, source) == nullptr;
  Chat *c = add_chat(chat_id);
  on_update_chat_title(c, chat_id, std::move(chat.title_));
  // chat participant count will be updated in on_update_chat_status
  on_update_chat_photo(c, chat_id, nullptr);
  if (c->date != 0) {
    c->date = 0;  // removed in 38-th layer
    c->need_save_to_database = true;
  }
  on_update_chat_status(c, chat_id, DialogParticipantStatus::Banned(0));
  if (is_uninited) {
    on_update_chat_active(c, chat_id, true);
    on_update_chat_migrated_to_channel_id(c, chat_id, ChannelId());
  } else {
    // leave active and migrated to as is
  }
  if (c->cache_version != Chat::CACHE_VERSION) {
    c->cache_version = Chat::CACHE_VERSION;
    c->need_save_to_database = true;
  }
  c->is_received_from_server = true;
  update_chat(c, chat_id);
}

void ChatManager::on_get_channel(telegram_api::channel &channel, const char *source) {
  ChannelId channel_id(channel.id_);
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id << " from " << source << ": " << to_string(channel);
    return;
  }

  if (channel.flags_ == 0 && channel.access_hash_ == 0 && channel.title_.empty()) {
    Channel *c = get_channel_force(channel_id, source);
    if (c != nullptr) {
      LOG(ERROR) << "Receive from " << source << " empty " << channel_id << ": " << to_string(channel) << ", have "
                 << to_string(get_supergroup_object(channel_id, c));
    }
    if (c == nullptr && !have_min_channel(channel_id)) {
      min_channels_.set(channel_id, td::make_unique<MinChannel>());
    }
    return;
  }

  bool is_min = channel.min_;
  auto access_hash = channel.access_hash_;
  bool has_linked_channel = channel.has_link_;
  bool sign_messages = channel.signatures_;
  bool join_to_send = channel.join_to_send_;
  bool join_request = channel.join_request_;
  bool is_slow_mode_enabled = channel.slowmode_enabled_;
  bool is_megagroup = channel.megagroup_;
  bool is_verified = channel.verified_;
  bool is_scam = channel.scam_;
  bool is_fake = channel.fake_;
  bool is_gigagroup = channel.gigagroup_;
  bool is_forum = channel.forum_;
  bool have_participant_count = (channel.flags_ & telegram_api::channel::PARTICIPANTS_COUNT_MASK) != 0;
  int32 participant_count = channel.participants_count_;
  bool stories_available = channel.stories_max_id_ > 0;
  bool stories_unavailable = channel.stories_unavailable_;
  bool show_message_sender = channel.signature_profiles_;
  auto boost_level = channel.level_;
  auto paid_message_star_count = channel.send_paid_messages_stars_;

  if (have_participant_count) {
    auto channel_full = get_channel_full_const(channel_id);
    if (channel_full != nullptr && channel_full->administrator_count > participant_count) {
      participant_count = channel_full->administrator_count;
    }
  }

  LOG_IF(ERROR, channel.broadcast_ == is_megagroup)
      << "Receive wrong channel flag is_broadcast == is_megagroup == " << is_megagroup << " from " << source << ": "
      << oneline(to_string(channel));

  if (is_megagroup) {
    LOG_IF(ERROR, sign_messages) << "Need to sign messages in the supergroup " << channel_id << " from " << source;
    sign_messages = true;
    show_message_sender = true;
  } else {
    LOG_IF(ERROR, is_slow_mode_enabled && channel_id.get() >= 8000000000)
        << "Slow mode enabled in the " << channel_id << " from " << source;
    LOG_IF(ERROR, is_gigagroup) << "Receive broadcast group as " << channel_id << " from " << source;
    LOG_IF(ERROR, is_forum) << "Receive broadcast forum as " << channel_id << " from " << source;
    is_slow_mode_enabled = false;
    is_gigagroup = false;
    is_forum = false;
    paid_message_star_count = 0;
  }
  if (is_gigagroup) {
    td_->suggested_action_manager_->remove_dialog_suggested_action(
        SuggestedAction{SuggestedAction::Type::ConvertToGigagroup, DialogId(channel_id)});
  }

  if (is_min) {
    Channel *c = get_channel_force(channel_id, source);
    if (c != nullptr) {
      LOG(DEBUG) << "Receive known min " << channel_id;

      auto old_join_to_send = get_channel_join_to_send(c);
      auto old_join_request = get_channel_join_request(c);
      on_update_channel_title(c, channel_id, std::move(channel.title_));
      on_update_channel_usernames(c, channel_id,
                                  Usernames(std::move(channel.username_), std::move(channel.usernames_)));
      if (!c->status.is_banned()) {
        on_update_channel_photo(c, channel_id, std::move(channel.photo_));
      }
      on_update_channel_has_location(c, channel_id, channel.has_geo_);
      on_update_channel_noforwards(c, channel_id, channel.noforwards_);
      on_update_channel_emoji_status(c, channel_id, EmojiStatus::get_emoji_status(std::move(channel.emoji_status_)));

      if (c->has_linked_channel != has_linked_channel || c->is_slow_mode_enabled != is_slow_mode_enabled ||
          c->is_megagroup != is_megagroup || c->is_scam != is_scam || c->is_fake != is_fake ||
          c->is_gigagroup != is_gigagroup || c->is_forum != is_forum || c->boost_level != boost_level ||
          c->paid_message_star_count != paid_message_star_count) {
        c->has_linked_channel = has_linked_channel;
        c->is_slow_mode_enabled = is_slow_mode_enabled;
        c->is_megagroup = is_megagroup;
        c->is_scam = is_scam;
        c->is_fake = is_fake;
        c->is_gigagroup = is_gigagroup;
        if (c->is_forum != is_forum) {
          c->is_forum = is_forum;
          send_closure_later(G()->messages_manager(), &MessagesManager::on_update_dialog_is_forum, DialogId(channel_id),
                             is_forum);
        }
        c->boost_level = boost_level;
        c->paid_message_star_count = paid_message_star_count;

        c->is_changed = true;
        invalidate_channel_full(channel_id, !c->is_slow_mode_enabled, "on_get_min_channel");
      }
      if (!td_->auth_manager_->is_bot()) {
        auto restriction_reasons = get_restriction_reasons(std::move(channel.restriction_reason_));
        if (restriction_reasons != c->restriction_reasons) {
          c->restriction_reasons = std::move(restriction_reasons);
          c->is_changed = true;
        }
        on_update_channel_bot_verification_icon(c, channel_id, CustomEmojiId(channel.bot_verification_icon_));
      }
      if (c->join_to_send != join_to_send || c->join_request != join_request) {
        c->join_to_send = join_to_send;
        c->join_request = join_request;

        c->need_save_to_database = true;
      }
      // sign_messages isn't known for min-channels
      if (c->is_verified != is_verified) {
        c->is_verified = is_verified;

        c->is_changed = true;
      }
      if (old_join_to_send != get_channel_join_to_send(c) || old_join_request != get_channel_join_request(c)) {
        c->is_changed = true;
      }

      // must be after setting of c->is_megagroup
      on_update_channel_default_permissions(c, channel_id,
                                            RestrictedRights(channel.default_banned_rights_, ChannelType::Megagroup));

      update_channel(c, channel_id);
    } else {
      auto min_channel = td::make_unique<MinChannel>();
      min_channel->photo_ =
          get_dialog_photo(td_->file_manager_.get(), DialogId(channel_id), access_hash, std::move(channel.photo_));
      if (td_->auth_manager_->is_bot()) {
        min_channel->photo_.minithumbnail.clear();
      }
      PeerColor peer_color(channel.color_);
      min_channel->accent_color_id_ = peer_color.accent_color_id_;
      min_channel->title_ = std::move(channel.title_);
      min_channel->is_megagroup_ = is_megagroup;

      min_channels_.set(channel_id, std::move(min_channel));
    }
    return;
  }
  if (access_hash == 0) {
    LOG(ERROR) << "Receive non-min " << channel_id << " without access_hash from " << source;
    return;
  }

  DialogParticipantStatus status = [&] {
    if (channel.creator_) {
      bool is_anonymous = channel.admin_rights_ != nullptr &&
                          (channel.admin_rights_->flags_ & telegram_api::chatAdminRights::ANONYMOUS_MASK) != 0;
      return DialogParticipantStatus::Creator(!channel.left_, is_anonymous, string());
    } else if (channel.admin_rights_ != nullptr) {
      return DialogParticipantStatus(false, std::move(channel.admin_rights_), string(),
                                     is_megagroup ? ChannelType::Megagroup : ChannelType::Broadcast);
    } else if (channel.banned_rights_ != nullptr) {
      return DialogParticipantStatus(!channel.left_, std::move(channel.banned_rights_),
                                     is_megagroup ? ChannelType::Megagroup : ChannelType::Broadcast);
    } else if (channel.left_) {
      return DialogParticipantStatus::Left();
    } else {
      return DialogParticipantStatus::Member(channel.subscription_until_date_);
    }
  }();
  if (status.is_creator()) {
    // to correctly calculate is_ownership_transferred in on_update_channel_status
    get_channel_force(channel_id, source);
  }

  Channel *c = add_channel(channel_id, "on_get_channel");
  auto old_join_to_send = get_channel_join_to_send(c);
  auto old_join_request = get_channel_join_request(c);
  if (c->access_hash != access_hash) {
    c->access_hash = access_hash;
    c->need_save_to_database = true;
  }
  if (c->date != channel.date_) {
    c->date = channel.date_;
    c->is_changed = true;
  }

  bool need_update_participant_count = have_participant_count && participant_count != c->participant_count;
  if (need_update_participant_count) {
    c->participant_count = participant_count;
    c->is_changed = true;
  }

  bool need_invalidate_channel_full = false;
  if (c->has_linked_channel != has_linked_channel || c->is_slow_mode_enabled != is_slow_mode_enabled ||
      c->is_megagroup != is_megagroup || c->is_scam != is_scam || c->is_fake != is_fake ||
      c->is_gigagroup != is_gigagroup || c->is_forum != is_forum || c->boost_level != boost_level ||
      c->paid_message_star_count != paid_message_star_count) {
    c->has_linked_channel = has_linked_channel;
    c->is_slow_mode_enabled = is_slow_mode_enabled;
    c->is_megagroup = is_megagroup;
    c->is_scam = is_scam;
    c->is_fake = is_fake;
    c->is_gigagroup = is_gigagroup;
    if (c->is_forum != is_forum) {
      c->is_forum = is_forum;
      send_closure_later(G()->messages_manager(), &MessagesManager::on_update_dialog_is_forum, DialogId(channel_id),
                         is_forum);
    }
    c->boost_level = boost_level;
    c->paid_message_star_count = paid_message_star_count;

    c->is_changed = true;
    need_invalidate_channel_full = true;
  }
  if (!td_->auth_manager_->is_bot()) {
    auto restriction_reasons = get_restriction_reasons(std::move(channel.restriction_reason_));
    if (restriction_reasons != c->restriction_reasons) {
      c->restriction_reasons = std::move(restriction_reasons);
      c->is_changed = true;
    }
    on_update_channel_bot_verification_icon(c, channel_id, CustomEmojiId(channel.bot_verification_icon_));
  }
  if (c->join_to_send != join_to_send || c->join_request != join_request) {
    c->join_to_send = join_to_send;
    c->join_request = join_request;

    c->need_save_to_database = true;
  }
  if (c->is_verified != is_verified || c->sign_messages != sign_messages ||
      c->show_message_sender != show_message_sender) {
    c->is_verified = is_verified;
    c->sign_messages = sign_messages;
    c->show_message_sender = show_message_sender;

    c->is_changed = true;
  }
  if (old_join_to_send != get_channel_join_to_send(c) || old_join_request != get_channel_join_request(c)) {
    c->is_changed = true;
  }

  on_update_channel_title(c, channel_id, std::move(channel.title_));
  on_update_channel_photo(c, channel_id, std::move(channel.photo_));
  PeerColor peer_color(channel.color_);
  on_update_channel_accent_color_id(c, channel_id, peer_color.accent_color_id_);
  on_update_channel_background_custom_emoji_id(c, channel_id, peer_color.background_custom_emoji_id_);
  PeerColor profile_peer_color(channel.profile_color_);
  on_update_channel_profile_accent_color_id(c, channel_id, profile_peer_color.accent_color_id_);
  on_update_channel_profile_background_custom_emoji_id(c, channel_id, profile_peer_color.background_custom_emoji_id_);
  on_update_channel_status(c, channel_id, std::move(status));
  on_update_channel_usernames(
      c, channel_id,
      Usernames(std::move(channel.username_),
                std::move(channel.usernames_)));  // uses status, must be called after on_update_channel_status
  on_update_channel_has_location(c, channel_id, channel.has_geo_);
  on_update_channel_noforwards(c, channel_id, channel.noforwards_);
  on_update_channel_emoji_status(c, channel_id, EmojiStatus::get_emoji_status(std::move(channel.emoji_status_)));
  if (!td_->auth_manager_->is_bot() && !channel.stories_hidden_min_) {
    on_update_channel_stories_hidden(c, channel_id, channel.stories_hidden_);
  }
  // must be after setting of c->is_megagroup
  on_update_channel_default_permissions(c, channel_id,
                                        RestrictedRights(channel.default_banned_rights_, ChannelType::Megagroup));
  if (!td_->auth_manager_->is_bot() && (stories_available || stories_unavailable)) {
    // update at the end, because it calls need_poll_channel_active_stories
    on_update_channel_story_ids_impl(c, channel_id, StoryId(channel.stories_max_id_), StoryId());
  }

  if (c->cache_version != Channel::CACHE_VERSION) {
    c->cache_version = Channel::CACHE_VERSION;
    c->need_save_to_database = true;
  }
  c->is_received_from_server = true;
  update_channel(c, channel_id);

  if (need_update_participant_count) {
    auto channel_full = get_channel_full(channel_id, true, "on_get_channel");
    if (channel_full != nullptr && channel_full->participant_count != participant_count) {
      channel_full->participant_count = participant_count;
      channel_full->is_changed = true;
      update_channel_full(channel_full, channel_id, "on_get_channel");
    }
  }

  if (need_invalidate_channel_full) {
    invalidate_channel_full(channel_id, !c->is_slow_mode_enabled, "on_get_channel");
  }

  td_->messages_manager_->on_update_dialog_group_call(DialogId(channel_id), channel.call_active_,
                                                      !channel.call_not_empty_, "receive channel");
}

void ChatManager::on_get_channel_forbidden(telegram_api::channelForbidden &channel, const char *source) {
  ChannelId channel_id(channel.id_);
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Receive invalid " << channel_id << " from " << source << ": " << to_string(channel);
    return;
  }

  if (channel.flags_ == 0 && channel.access_hash_ == 0 && channel.title_.empty()) {
    Channel *c = get_channel_force(channel_id, source);
    LOG(ERROR) << "Receive empty " << to_string(channel) << " from " << source << ", have "
               << to_string(get_supergroup_object(channel_id, c));
    if (c == nullptr && !have_min_channel(channel_id)) {
      min_channels_.set(channel_id, td::make_unique<MinChannel>());
    }
    return;
  }

  Channel *c = add_channel(channel_id, "on_get_channel_forbidden");
  auto old_join_to_send = get_channel_join_to_send(c);
  auto old_join_request = get_channel_join_request(c);
  if (c->access_hash != channel.access_hash_) {
    c->access_hash = channel.access_hash_;
    c->need_save_to_database = true;
  }
  if (c->date != 0) {
    c->date = 0;
    c->is_changed = true;
  }

  bool sign_messages = false;
  bool show_message_sender = false;
  bool join_to_send = false;
  bool join_request = false;
  bool is_slow_mode_enabled = false;
  bool is_megagroup = channel.megagroup_;
  bool is_verified = false;
  bool is_scam = false;
  bool is_fake = false;

  LOG_IF(ERROR, channel.broadcast_ == is_megagroup)
      << "Receive wrong channel flag is_broadcast == is_megagroup == " << is_megagroup << " from " << source << ": "
      << oneline(to_string(channel));

  if (is_megagroup) {
    sign_messages = true;
    show_message_sender = true;
  }

  bool need_invalidate_channel_full = false;
  if (c->is_slow_mode_enabled != is_slow_mode_enabled || c->is_megagroup != is_megagroup ||
      !c->restriction_reasons.empty() || c->is_scam != is_scam || c->is_fake != is_fake ||
      c->join_to_send != join_to_send || c->join_request != join_request) {
    // c->has_linked_channel = has_linked_channel;
    c->is_slow_mode_enabled = is_slow_mode_enabled;
    c->is_megagroup = is_megagroup;
    c->restriction_reasons.clear();
    c->is_scam = is_scam;
    c->is_fake = is_fake;
    c->join_to_send = join_to_send;
    c->join_request = join_request;

    c->is_changed = true;
    need_invalidate_channel_full = true;
  }
  if (c->join_to_send != join_to_send || c->join_request != join_request) {
    c->join_to_send = join_to_send;
    c->join_request = join_request;

    c->need_save_to_database = true;
  }
  if (c->is_verified != is_verified || c->sign_messages != sign_messages ||
      c->show_message_sender != show_message_sender) {
    c->is_verified = is_verified;
    c->sign_messages = sign_messages;
    c->show_message_sender = show_message_sender;

    c->is_changed = true;
  }
  if (old_join_to_send != get_channel_join_to_send(c) || old_join_request != get_channel_join_request(c)) {
    c->is_changed = true;
  }

  on_update_channel_title(c, channel_id, std::move(channel.title_));
  on_update_channel_photo(c, channel_id, nullptr);
  on_update_channel_status(c, channel_id, DialogParticipantStatus::Banned(channel.until_date_));
  // on_update_channel_usernames(c, channel_id, Usernames());  // don't know if channel usernames are empty, so don't update it
  // on_update_channel_has_location(c, channel_id, false);
  on_update_channel_noforwards(c, channel_id, false);
  on_update_channel_emoji_status(c, channel_id, nullptr);
  on_update_channel_bot_verification_icon(c, channel_id, CustomEmojiId());
  td_->messages_manager_->on_update_dialog_group_call(DialogId(channel_id), false, false, "on_get_channel_forbidden");
  // must be after setting of c->is_megagroup
  tl_object_ptr<telegram_api::chatBannedRights> banned_rights;  // == nullptr
  on_update_channel_default_permissions(c, channel_id, RestrictedRights(banned_rights, ChannelType::Megagroup));

  bool need_drop_participant_count = c->participant_count != 0;
  if (need_drop_participant_count) {
    c->participant_count = 0;
    c->is_changed = true;
  }

  if (c->cache_version != Channel::CACHE_VERSION) {
    c->cache_version = Channel::CACHE_VERSION;
    c->need_save_to_database = true;
  }
  c->is_received_from_server = true;
  update_channel(c, channel_id);

  if (need_drop_participant_count) {
    auto channel_full = get_channel_full(channel_id, true, "on_get_channel_forbidden");
    if (channel_full != nullptr && channel_full->participant_count != 0) {
      channel_full->participant_count = 0;
      channel_full->administrator_count = 0;
      channel_full->is_changed = true;
      update_channel_full(channel_full, channel_id, "on_get_channel_forbidden 2");
    }
  }
  if (need_invalidate_channel_full) {
    invalidate_channel_full(channel_id, !c->is_slow_mode_enabled, "on_get_channel_forbidden 3");
  }
}

td_api::object_ptr<td_api::updateBasicGroup> ChatManager::get_update_basic_group_object(ChatId chat_id, const Chat *c) {
  if (c == nullptr) {
    return get_update_unknown_basic_group_object(chat_id);
  }
  return td_api::make_object<td_api::updateBasicGroup>(get_basic_group_object(chat_id, c));
}

td_api::object_ptr<td_api::updateBasicGroup> ChatManager::get_update_unknown_basic_group_object(ChatId chat_id) {
  return td_api::make_object<td_api::updateBasicGroup>(td_api::make_object<td_api::basicGroup>(
      chat_id.get(), 0, DialogParticipantStatus::Banned(0).get_chat_member_status_object(), true, 0));
}

int64 ChatManager::get_basic_group_id_object(ChatId chat_id, const char *source) const {
  if (chat_id.is_valid() && get_chat(chat_id) == nullptr && unknown_chats_.count(chat_id) == 0) {
    LOG(ERROR) << "Have no information about " << chat_id << " from " << source;
    unknown_chats_.insert(chat_id);
    send_closure(G()->td(), &Td::send_update, get_update_unknown_basic_group_object(chat_id));
  }
  return chat_id.get();
}

tl_object_ptr<td_api::basicGroup> ChatManager::get_basic_group_object(ChatId chat_id) {
  return get_basic_group_object(chat_id, get_chat(chat_id));
}

tl_object_ptr<td_api::basicGroup> ChatManager::get_basic_group_object(ChatId chat_id, const Chat *c) {
  if (c == nullptr) {
    return nullptr;
  }
  if (c->migrated_to_channel_id.is_valid()) {
    get_channel_force(c->migrated_to_channel_id, "get_basic_group_object");
  }
  return get_basic_group_object_const(chat_id, c);
}

tl_object_ptr<td_api::basicGroup> ChatManager::get_basic_group_object_const(ChatId chat_id, const Chat *c) const {
  return make_tl_object<td_api::basicGroup>(
      chat_id.get(), c->participant_count, get_chat_status(c).get_chat_member_status_object(), c->is_active,
      get_supergroup_id_object(c->migrated_to_channel_id, "get_basic_group_object"));
}

tl_object_ptr<td_api::basicGroupFullInfo> ChatManager::get_basic_group_full_info_object(ChatId chat_id) const {
  return get_basic_group_full_info_object(chat_id, get_chat_full(chat_id));
}

tl_object_ptr<td_api::basicGroupFullInfo> ChatManager::get_basic_group_full_info_object(
    ChatId chat_id, const ChatFull *chat_full) const {
  CHECK(chat_full != nullptr);
  auto bot_commands = transform(chat_full->bot_commands, [td = td_](const BotCommands &commands) {
    return commands.get_bot_commands_object(td);
  });
  auto members = transform(chat_full->participants, [this](const DialogParticipant &dialog_participant) {
    return get_chat_member_object(dialog_participant, "get_basic_group_full_info_object");
  });
  return make_tl_object<td_api::basicGroupFullInfo>(
      get_chat_photo_object(td_->file_manager_.get(), chat_full->photo), chat_full->description,
      td_->user_manager_->get_user_id_object(chat_full->creator_user_id, "basicGroupFullInfo"), std::move(members),
      can_hide_chat_participants(chat_id).is_ok(), can_toggle_chat_aggressive_anti_spam(chat_id).is_ok(),
      chat_full->invite_link.get_chat_invite_link_object(td_->user_manager_.get()), std::move(bot_commands));
}

td_api::object_ptr<td_api::updateSupergroup> ChatManager::get_update_supergroup_object(ChannelId channel_id,
                                                                                       const Channel *c) const {
  if (c == nullptr) {
    return get_update_unknown_supergroup_object(channel_id);
  }
  return td_api::make_object<td_api::updateSupergroup>(get_supergroup_object(channel_id, c));
}

td_api::object_ptr<td_api::updateSupergroup> ChatManager::get_update_unknown_supergroup_object(
    ChannelId channel_id) const {
  auto min_channel = get_min_channel(channel_id);
  bool is_megagroup = min_channel == nullptr ? false : min_channel->is_megagroup_;
  return td_api::make_object<td_api::updateSupergroup>(td_api::make_object<td_api::supergroup>(
      channel_id.get(), nullptr, 0, DialogParticipantStatus::Banned(0).get_chat_member_status_object(), 0, 0, false,
      false, false, false, !is_megagroup, false, false, !is_megagroup, false, false, nullptr, false, string(), 0, false,
      false));
}

int64 ChatManager::get_supergroup_id_object(ChannelId channel_id, const char *source) const {
  if (channel_id.is_valid() && get_channel(channel_id) == nullptr && unknown_channels_.count(channel_id) == 0) {
    if (have_min_channel(channel_id)) {
      LOG(INFO) << "Have only min " << channel_id << " received from " << source;
    } else {
      LOG(ERROR) << "Have no information about " << channel_id << " received from " << source;
    }
    unknown_channels_.insert(channel_id);
    send_closure(G()->td(), &Td::send_update, get_update_unknown_supergroup_object(channel_id));
  }
  return channel_id.get();
}

bool ChatManager::need_poll_channel_active_stories(const Channel *c, ChannelId channel_id) const {
  return c != nullptr && !get_channel_status(c).is_member() &&
         have_input_peer_channel(c, channel_id, AccessRights::Read);
}

bool ChatManager::get_channel_has_unread_stories(const Channel *c) {
  CHECK(c != nullptr);
  return c->max_active_story_id.get() > c->max_read_story_id.get();
}

td_api::object_ptr<td_api::supergroup> ChatManager::get_supergroup_object(ChannelId channel_id) const {
  return get_supergroup_object(channel_id, get_channel(channel_id));
}

td_api::object_ptr<td_api::supergroup> ChatManager::get_supergroup_object(ChannelId channel_id,
                                                                          const Channel *c) const {
  if (c == nullptr) {
    return nullptr;
  }
  return td_api::make_object<td_api::supergroup>(
      channel_id.get(), c->usernames.get_usernames_object(), c->date,
      get_channel_status(c).get_chat_member_status_object(), c->participant_count, c->boost_level,
      c->has_linked_channel, c->has_location, c->sign_messages, c->show_message_sender, get_channel_join_to_send(c),
      get_channel_join_request(c), c->is_slow_mode_enabled, !c->is_megagroup, c->is_gigagroup, c->is_forum,
      get_channel_verification_status_object(c), get_restriction_reason_has_sensitive_content(c->restriction_reasons),
      get_restriction_reason_description(c->restriction_reasons), c->paid_message_star_count,
      c->max_active_story_id.is_valid(), get_channel_has_unread_stories(c));
}

tl_object_ptr<td_api::supergroupFullInfo> ChatManager::get_supergroup_full_info_object(ChannelId channel_id) const {
  return get_supergroup_full_info_object(channel_id, get_channel_full(channel_id));
}

tl_object_ptr<td_api::supergroupFullInfo> ChatManager::get_supergroup_full_info_object(
    ChannelId channel_id, const ChannelFull *channel_full) const {
  CHECK(channel_full != nullptr);
  double slow_mode_delay_expires_in = 0;
  if (channel_full->slow_mode_next_send_date != 0 &&
      (channel_full->unrestrict_boost_count == 0 || channel_full->boost_count < channel_full->unrestrict_boost_count)) {
    slow_mode_delay_expires_in = max(channel_full->slow_mode_next_send_date - G()->server_time(), 1e-3);
  }
  auto bot_commands = transform(channel_full->bot_commands, [td = td_](const BotCommands &commands) {
    return commands.get_bot_commands_object(td);
  });
  auto bot_verification = channel_full->bot_verification == nullptr
                              ? nullptr
                              : channel_full->bot_verification->get_bot_verification_object(td_);
  bool has_hidden_participants = channel_full->has_hidden_participants || !channel_full->can_get_participants;
  return td_api::make_object<td_api::supergroupFullInfo>(
      get_chat_photo_object(td_->file_manager_.get(), channel_full->photo), channel_full->description,
      channel_full->participant_count, channel_full->administrator_count, channel_full->restricted_count,
      channel_full->banned_count, DialogId(channel_full->linked_channel_id).get(), channel_full->slow_mode_delay,
      slow_mode_delay_expires_in, channel_full->has_paid_messages_available, channel_full->has_paid_media_allowed,
      channel_full->can_get_participants, has_hidden_participants,
      can_hide_channel_participants(channel_id, channel_full).is_ok(), channel_full->can_set_sticker_set,
      channel_full->can_set_location, channel_full->can_view_statistics, channel_full->can_view_revenue,
      channel_full->can_view_star_revenue, channel_full->has_stargifts_available,
      can_toggle_channel_aggressive_anti_spam(channel_id, channel_full).is_ok(), channel_full->is_all_history_available,
      channel_full->can_have_sponsored_messages, channel_full->has_aggressive_anti_spam_enabled,
      channel_full->has_paid_media_allowed, channel_full->has_pinned_stories, channel_full->gift_count,
      channel_full->boost_count, channel_full->unrestrict_boost_count, channel_full->sticker_set_id.get(),
      channel_full->emoji_sticker_set_id.get(), channel_full->location.get_chat_location_object(),
      channel_full->invite_link.get_chat_invite_link_object(td_->user_manager_.get()), std::move(bot_commands),
      std::move(bot_verification),
      get_basic_group_id_object(channel_full->migrated_from_chat_id, "get_supergroup_full_info_object"),
      channel_full->migrated_from_max_message_id.get());
}

void ChatManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  for (auto chat_id : unknown_chats_) {
    if (!have_chat(chat_id)) {
      updates.push_back(get_update_unknown_basic_group_object(chat_id));
    }
  }
  for (auto channel_id : unknown_channels_) {
    if (!have_channel(channel_id)) {
      updates.push_back(get_update_unknown_supergroup_object(channel_id));
    }
  }

  channels_.foreach([&](const ChannelId &channel_id, const unique_ptr<Channel> &channel) {
    updates.push_back(get_update_supergroup_object(channel_id, channel.get()));
  });
  // chat objects can contain channel_id, so they must be sent after channels
  chats_.foreach([&](const ChatId &chat_id, const unique_ptr<Chat> &chat) {
    updates.push_back(td_api::make_object<td_api::updateBasicGroup>(get_basic_group_object_const(chat_id, chat.get())));
  });

  channels_full_.foreach([&](const ChannelId &channel_id, const unique_ptr<ChannelFull> &channel_full) {
    updates.push_back(td_api::make_object<td_api::updateSupergroupFullInfo>(
        channel_id.get(), get_supergroup_full_info_object(channel_id, channel_full.get())));
  });
  chats_full_.foreach([&](const ChatId &chat_id, const unique_ptr<ChatFull> &chat_full) {
    updates.push_back(td_api::make_object<td_api::updateBasicGroupFullInfo>(
        chat_id.get(), get_basic_group_full_info_object(chat_id, chat_full.get())));
  });
}

}  // namespace td
