//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogParticipantManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChannelParticipantFilter.h"
#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/MissingInvitee.h"
#include "td/telegram/PasswordManager.h"
#include "td/telegram/StoryManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/db/SqliteKeyValueAsync.h"

#include "td/actor/MultiPromise.h"
#include "td/actor/SleepActor.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/format.h"
#include "td/utils/Hints.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"

#include <algorithm>
#include <limits>
#include <tuple>

namespace td {

class GetOnlinesQuery final : public Td::ResultHandler {
  DialogId dialog_id_;

 public:
  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    CHECK(dialog_id.get_type() == DialogType::Channel);
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_getOnlines(std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getOnlines>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    td_->dialog_participant_manager_->on_update_dialog_online_member_count(dialog_id_, result->onlines_, true);
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetOnlinesQuery");
    td_->dialog_participant_manager_->on_update_dialog_online_member_count(dialog_id_, 0, true);
  }
};

class GetChatJoinRequestsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chatJoinRequests>> promise_;
  DialogId dialog_id_;
  bool is_full_list_ = false;

 public:
  explicit GetChatJoinRequestsQuery(Promise<td_api::object_ptr<td_api::chatJoinRequests>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &invite_link, const string &query, int32 offset_date,
            UserId offset_user_id, int32 limit) {
    dialog_id_ = dialog_id;
    is_full_list_ =
        invite_link.empty() && query.empty() && offset_date == 0 && !offset_user_id.is_valid() && limit >= 3;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    auto r_input_user = td_->user_manager_->get_input_user(offset_user_id);
    if (r_input_user.is_error()) {
      r_input_user = make_tl_object<telegram_api::inputUserEmpty>();
    }

    int32 flags = telegram_api::messages_getChatInviteImporters::REQUESTED_MASK;
    if (!invite_link.empty()) {
      flags |= telegram_api::messages_getChatInviteImporters::LINK_MASK;
    }
    if (!query.empty()) {
      flags |= telegram_api::messages_getChatInviteImporters::Q_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_getChatInviteImporters(
        flags, false /*ignored*/, false /*ignored*/, std::move(input_peer), invite_link, query, offset_date,
        r_input_user.move_as_ok(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getChatInviteImporters>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChatJoinRequestsQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetChatJoinRequestsQuery");

    int32 total_count = result->count_;
    if (total_count < static_cast<int32>(result->importers_.size())) {
      LOG(ERROR) << "Receive wrong total count of join requests " << total_count << " in " << dialog_id_;
      total_count = static_cast<int32>(result->importers_.size());
    }
    vector<td_api::object_ptr<td_api::chatJoinRequest>> join_requests;
    vector<int64> recent_requesters;
    for (auto &request : result->importers_) {
      UserId user_id(request->user_id_);
      UserId approver_user_id(request->approved_by_);
      if (!user_id.is_valid() || approver_user_id.is_valid() || !request->requested_) {
        LOG(ERROR) << "Receive invalid join request: " << to_string(request);
        total_count--;
        continue;
      }
      if (recent_requesters.size() < 3) {
        recent_requesters.push_back(user_id.get());
      }
      join_requests.push_back(td_api::make_object<td_api::chatJoinRequest>(
          td_->user_manager_->get_user_id_object(user_id, "chatJoinRequest"), request->date_, request->about_));
    }
    if (is_full_list_) {
      td_->messages_manager_->on_update_dialog_pending_join_requests(dialog_id_, total_count,
                                                                     std::move(recent_requesters));
    }
    promise_.set_value(td_api::make_object<td_api::chatJoinRequests>(total_count, std::move(join_requests)));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetChatJoinRequestsQuery");
    promise_.set_error(std::move(status));
  }
};

class HideChatJoinRequestQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit HideChatJoinRequestQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, UserId user_id, bool approve) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    TRY_RESULT_PROMISE(promise_, input_user, td_->user_manager_->get_input_user(user_id));

    int32 flags = 0;
    if (approve) {
      flags |= telegram_api::messages_hideChatJoinRequest::APPROVED_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_hideChatJoinRequest(
        flags, false /*ignored*/, std::move(input_peer), std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_hideChatJoinRequest>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for HideChatJoinRequestQuery: " << to_string(result);
    td_->updates_manager_->on_get_updates(std::move(result), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "HideChatJoinRequestQuery");
    promise_.set_error(std::move(status));
  }
};

class HideAllChatJoinRequestsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit HideAllChatJoinRequestsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &invite_link, bool approve) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    int32 flags = 0;
    if (approve) {
      flags |= telegram_api::messages_hideAllChatJoinRequests::APPROVED_MASK;
    }
    if (!invite_link.empty()) {
      flags |= telegram_api::messages_hideAllChatJoinRequests::LINK_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_hideAllChatJoinRequests(flags, false /*ignored*/, std::move(input_peer), invite_link)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_hideAllChatJoinRequests>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for HideAllChatJoinRequestsQuery: " << to_string(result);
    td_->updates_manager_->on_get_updates(std::move(result), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "HideAllChatJoinRequestsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetChannelAdministratorsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit GetChannelAdministratorsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, int64 hash) {
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      return promise_.set_error(Status::Error(400, "Supergroup not found"));
    }

    hash = 0;  // to load even only ranks or creator changed

    channel_id_ = channel_id;
    send_query(G()->net_query_creator().create(telegram_api::channels_getParticipants(
        std::move(input_channel), telegram_api::make_object<telegram_api::channelParticipantsAdmins>(), 0,
        std::numeric_limits<int32>::max(), hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getParticipants>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto participants_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChannelAdministratorsQuery: " << to_string(participants_ptr);
    switch (participants_ptr->get_id()) {
      case telegram_api::channels_channelParticipants::ID: {
        auto participants = telegram_api::move_object_as<telegram_api::channels_channelParticipants>(participants_ptr);
        td_->user_manager_->on_get_users(std::move(participants->users_), "GetChannelAdministratorsQuery");
        td_->chat_manager_->on_get_chats(std::move(participants->chats_), "GetChannelAdministratorsQuery");

        auto channel_type = td_->chat_manager_->get_channel_type(channel_id_);
        vector<DialogAdministrator> administrators;
        administrators.reserve(participants->participants_.size());
        for (auto &participant : participants->participants_) {
          DialogParticipant dialog_participant(std::move(participant), channel_type);
          if (!dialog_participant.is_valid() || !dialog_participant.status_.is_administrator_member() ||
              dialog_participant.dialog_id_.get_type() != DialogType::User) {
            LOG(ERROR) << "Receive " << dialog_participant << " as an administrator of " << channel_id_;
            continue;
          }
          administrators.emplace_back(dialog_participant.dialog_id_.get_user_id(),
                                      dialog_participant.status_.get_rank(), dialog_participant.status_.is_creator());
        }

        td_->chat_manager_->on_update_channel_administrator_count(channel_id_,
                                                                  narrow_cast<int32>(administrators.size()));
        td_->dialog_participant_manager_->on_update_dialog_administrators(DialogId(channel_id_),
                                                                          std::move(administrators), true, false);

        break;
      }
      case telegram_api::channels_channelParticipantsNotModified::ID:
        break;
      default:
        UNREACHABLE();
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "GetChannelAdministratorsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetChannelParticipantQuery final : public Td::ResultHandler {
  Promise<DialogParticipant> promise_;
  ChannelId channel_id_;
  DialogId participant_dialog_id_;

 public:
  explicit GetChannelParticipantQuery(Promise<DialogParticipant> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, DialogId participant_dialog_id, tl_object_ptr<telegram_api::InputPeer> &&input_peer) {
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      return promise_.set_error(Status::Error(400, "Supergroup not found"));
    }

    CHECK(input_peer != nullptr);

    channel_id_ = channel_id;
    participant_dialog_id_ = participant_dialog_id;
    send_query(G()->net_query_creator().create(
        telegram_api::channels_getParticipant(std::move(input_channel), std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getParticipant>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto participant = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChannelParticipantQuery: " << to_string(participant);

    td_->user_manager_->on_get_users(std::move(participant->users_), "GetChannelParticipantQuery");
    td_->chat_manager_->on_get_chats(std::move(participant->chats_), "GetChannelParticipantQuery");
    DialogParticipant result(std::move(participant->participant_), td_->chat_manager_->get_channel_type(channel_id_));
    if (!result.is_valid()) {
      LOG(ERROR) << "Receive invalid " << result;
      return promise_.set_error(Status::Error(500, "Receive invalid chat member"));
    }
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    if (status.message() == "USER_NOT_PARTICIPANT") {
      promise_.set_value(DialogParticipant::left(participant_dialog_id_));
      return;
    }

    if (participant_dialog_id_.get_type() != DialogType::Channel) {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "GetChannelParticipantQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class GetChannelParticipantsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::channels_channelParticipants>> promise_;
  ChannelId channel_id_;

 public:
  explicit GetChannelParticipantsQuery(
      Promise<telegram_api::object_ptr<telegram_api::channels_channelParticipants>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, const ChannelParticipantFilter &filter, int32 offset, int32 limit) {
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      return promise_.set_error(Status::Error(400, "Supergroup not found"));
    }

    channel_id_ = channel_id;
    send_query(G()->net_query_creator().create(telegram_api::channels_getParticipants(
        std::move(input_channel), filter.get_input_channel_participants_filter(), offset, limit, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_getParticipants>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto participants_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetChannelParticipantsQuery: " << to_string(participants_ptr);
    switch (participants_ptr->get_id()) {
      case telegram_api::channels_channelParticipants::ID: {
        promise_.set_value(telegram_api::move_object_as<telegram_api::channels_channelParticipants>(participants_ptr));
        break;
      }
      case telegram_api::channels_channelParticipantsNotModified::ID:
        LOG(ERROR) << "Receive channelParticipantsNotModified";
        return on_error(Status::Error(500, "Receive channelParticipantsNotModified"));
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "GetChannelParticipantsQuery");
    promise_.set_error(std::move(status));
  }
};

class AddChatUserQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::failedToAddMembers>> promise_;
  ChatId chat_id_;
  UserId user_id_;

 public:
  explicit AddChatUserQuery(Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(ChatId chat_id, UserId user_id, tl_object_ptr<telegram_api::InputUser> &&input_user, int32 forward_limit) {
    chat_id_ = chat_id;
    user_id_ = user_id;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_addChatUser(chat_id.get(), std::move(input_user), forward_limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_addChatUser>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for AddChatUserQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(
        std::move(ptr->updates_),
        PromiseCreator::lambda(
            [missing_invitees = MissingInvitees(std::move(ptr->missing_invitees_))
                                    .get_failed_to_add_members_object(td_->user_manager_.get()),
             promise = std::move(promise_)](Result<Unit>) mutable { promise.set_value(std::move(missing_invitees)); }));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class EditChatAdminQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChatId chat_id_;
  UserId user_id_;

 public:
  explicit EditChatAdminQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChatId chat_id, UserId user_id, tl_object_ptr<telegram_api::InputUser> &&input_user,
            bool is_administrator) {
    chat_id_ = chat_id;
    user_id_ = user_id;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_editChatAdmin(chat_id.get(), std::move(input_user), is_administrator)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editChatAdmin>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    if (!result) {
      LOG(ERROR) << "Receive false as result of messages.editChatAdmin";
      return on_error(Status::Error(400, "Can't edit chat administrators"));
    }

    // result will come in the updates
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteChatUserQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteChatUserQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChatId chat_id, tl_object_ptr<telegram_api::InputUser> &&input_user, bool revoke_messages) {
    int32 flags = 0;
    if (revoke_messages) {
      flags |= telegram_api::messages_deleteChatUser::REVOKE_HISTORY_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_deleteChatUser(flags, false /*ignored*/, chat_id.get(), std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteChatUser>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteChatUserQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class JoinChannelQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit JoinChannelQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(
        G()->net_query_creator().create(telegram_api::channels_joinChannel(std::move(input_channel)), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_joinChannel>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for JoinChannelQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "JoinChannelQuery");
    promise_.set_error(std::move(status));
  }
};

class InviteToChannelQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::failedToAddMembers>> promise_;
  ChannelId channel_id_;
  vector<UserId> user_ids_;

 public:
  explicit InviteToChannelQuery(Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, vector<UserId> user_ids,
            vector<tl_object_ptr<telegram_api::InputUser>> &&input_users) {
    channel_id_ = channel_id;
    user_ids_ = std::move(user_ids);
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_inviteToChannel(std::move(input_channel), std::move(input_users))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_inviteToChannel>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for InviteToChannelQuery: " << to_string(ptr);
    td_->chat_manager_->invalidate_channel_full(channel_id_, false, "InviteToChannelQuery");
    td_->updates_manager_->on_get_updates(
        std::move(std::move(ptr->updates_)),
        PromiseCreator::lambda(
            [missing_invitees = MissingInvitees(std::move(ptr->missing_invitees_))
                                    .get_failed_to_add_members_object(td_->user_manager_.get()),
             promise = std::move(promise_)](Result<Unit>) mutable { promise.set_value(std::move(missing_invitees)); }));
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "InviteToChannelQuery");
    td_->chat_manager_->invalidate_channel_full(channel_id_, false, "InviteToChannelQuery");
    promise_.set_error(std::move(status));
  }
};

class EditChannelAdminQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  UserId user_id_;
  DialogParticipantStatus status_ = DialogParticipantStatus::Left();

 public:
  explicit EditChannelAdminQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, UserId user_id, tl_object_ptr<telegram_api::InputUser> &&input_user,
            const DialogParticipantStatus &status) {
    channel_id_ = channel_id;
    user_id_ = user_id;
    status_ = status;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::channels_editAdmin(
        std::move(input_channel), std::move(input_user), status.get_chat_admin_rights(), status.get_rank())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_editAdmin>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditChannelAdminQuery: " << to_string(ptr);
    td_->chat_manager_->invalidate_channel_full(channel_id_, false, "EditChannelAdminQuery");
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
    td_->dialog_participant_manager_->on_set_channel_participant_status(channel_id_, DialogId(user_id_), status_);
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "EditChannelAdminQuery");
    td_->chat_manager_->invalidate_channel_full(channel_id_, false, "EditChannelAdminQuery");
    promise_.set_error(std::move(status));
  }
};

class EditChannelBannedQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  DialogId participant_dialog_id_;
  DialogParticipantStatus status_ = DialogParticipantStatus::Left();

 public:
  explicit EditChannelBannedQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, DialogId participant_dialog_id, tl_object_ptr<telegram_api::InputPeer> &&input_peer,
            const DialogParticipantStatus &status) {
    channel_id_ = channel_id;
    participant_dialog_id_ = participant_dialog_id;
    status_ = status;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::channels_editBanned(
        std::move(input_channel), std::move(input_peer), status.get_chat_banned_rights())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_editBanned>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditChannelBannedQuery: " << to_string(ptr);
    td_->chat_manager_->invalidate_channel_full(channel_id_, false, "EditChannelBannedQuery");
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
    td_->dialog_participant_manager_->on_set_channel_participant_status(channel_id_, participant_dialog_id_, status_);
  }

  void on_error(Status status) final {
    if (participant_dialog_id_.get_type() != DialogType::Channel) {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "EditChannelBannedQuery");
    }
    td_->chat_manager_->invalidate_channel_full(channel_id_, false, "EditChannelBannedQuery");
    promise_.set_error(std::move(status));
  }
};

class LeaveChannelQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit LeaveChannelQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id) {
    channel_id_ = channel_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    CHECK(input_channel != nullptr);
    send_query(
        G()->net_query_creator().create(telegram_api::channels_leaveChannel(std::move(input_channel)), {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_leaveChannel>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for LeaveChannelQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "USER_NOT_PARTICIPANT") {
      return td_->chat_manager_->reload_channel(channel_id_, std::move(promise_), "LeaveChannelQuery");
    }
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "LeaveChannelQuery");
    td_->chat_manager_->reload_channel_full(channel_id_, Promise<Unit>(), "LeaveChannelQuery");
    promise_.set_error(std::move(status));
  }
};

class CanEditChannelCreatorQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit CanEditChannelCreatorQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    auto r_input_user = td_->user_manager_->get_input_user(td_->user_manager_->get_my_id());
    CHECK(r_input_user.is_ok());
    send_query(G()->net_query_creator().create(telegram_api::channels_editCreator(
        telegram_api::make_object<telegram_api::inputChannelEmpty>(), r_input_user.move_as_ok(),
        make_tl_object<telegram_api::inputCheckPasswordEmpty>())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_editCreator>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(ERROR) << "Receive result for CanEditChannelCreatorQuery: " << to_string(ptr);
    promise_.set_error(Status::Error(500, "Server doesn't returned error"));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class EditChannelCreatorQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  UserId user_id_;

 public:
  explicit EditChannelCreatorQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, UserId user_id,
            tl_object_ptr<telegram_api::InputCheckPasswordSRP> input_check_password) {
    channel_id_ = channel_id;
    user_id_ = user_id;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      return promise_.set_error(Status::Error(400, "Have no access to the chat"));
    }
    TRY_RESULT_PROMISE(promise_, input_user, td_->user_manager_->get_input_user(user_id));
    send_query(G()->net_query_creator().create(
        telegram_api::channels_editCreator(std::move(input_channel), std::move(input_user),
                                           std::move(input_check_password)),
        {{channel_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_editCreator>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditChannelCreatorQuery: " << to_string(ptr);
    td_->chat_manager_->invalidate_channel_full(channel_id_, false, "EditChannelCreatorQuery");
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->chat_manager_->on_get_channel_error(channel_id_, status, "EditChannelCreatorQuery");
    promise_.set_error(std::move(status));
  }
};

DialogParticipantManager::DialogParticipantManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  update_dialog_online_member_count_timeout_.set_callback(on_update_dialog_online_member_count_timeout_callback);
  update_dialog_online_member_count_timeout_.set_callback_data(static_cast<void *>(this));

  channel_participant_cache_timeout_.set_callback(on_channel_participant_cache_timeout_callback);
  channel_participant_cache_timeout_.set_callback_data(static_cast<void *>(this));
}

DialogParticipantManager::~DialogParticipantManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), user_online_member_dialogs_,
                                              dialog_administrators_, channel_participants_,
                                              cached_channel_participants_);
}

void DialogParticipantManager::tear_down() {
  parent_.reset();
}

void DialogParticipantManager::on_update_dialog_online_member_count_timeout_callback(
    void *dialog_participant_manager_ptr, int64 dialog_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto dialog_participant_manager = static_cast<DialogParticipantManager *>(dialog_participant_manager_ptr);
  send_closure_later(dialog_participant_manager->actor_id(dialog_participant_manager),
                     &DialogParticipantManager::on_update_dialog_online_member_count_timeout, DialogId(dialog_id_int));
}

void DialogParticipantManager::on_update_dialog_online_member_count_timeout(DialogId dialog_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Expired timeout for number of online members in " << dialog_id;
  bool is_open = td_->messages_manager_->is_dialog_opened(dialog_id);
  if (!is_open) {
    send_update_chat_online_member_count(dialog_id, 0);
    return;
  }

  if (dialog_id.get_type() == DialogType::Channel && !td_->dialog_manager_->is_broadcast_channel(dialog_id)) {
    auto participant_count = td_->chat_manager_->get_channel_participant_count(dialog_id.get_channel_id());
    auto has_hidden_participants = td_->chat_manager_->get_channel_effective_has_hidden_participants(
        dialog_id.get_channel_id(), "on_update_dialog_online_member_count_timeout");
    if (participant_count == 0 || participant_count >= 195 || has_hidden_participants) {
      td_->create_handler<GetOnlinesQuery>()->send(dialog_id);
    } else {
      get_channel_participants(dialog_id.get_channel_id(), td_api::make_object<td_api::supergroupMembersFilterRecent>(),
                               string(), 0, 200, 200, Auto());
    }
    return;
  }
  if (dialog_id.get_type() == DialogType::Chat) {
    // we need actual online status state, so we need to reget chat participants
    td_->chat_manager_->repair_chat_participants(dialog_id.get_chat_id());
    return;
  }
}

void DialogParticipantManager::on_update_dialog_online_member_count(DialogId dialog_id, int32 online_member_count,
                                                                    bool is_from_server) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (!dialog_id.is_valid()) {
    LOG(ERROR) << "Receive number of online members in invalid " << dialog_id;
    return;
  }

  if (td_->dialog_manager_->is_broadcast_channel(dialog_id)) {
    LOG_IF(ERROR, online_member_count != 0)
        << "Receive " << online_member_count << " as a number of online members in a channel " << dialog_id;
    return;
  }

  if (online_member_count < 0) {
    LOG(ERROR) << "Receive " << online_member_count << " as a number of online members in a " << dialog_id;
    return;
  }

  set_dialog_online_member_count(dialog_id, online_member_count, is_from_server,
                                 "on_update_dialog_online_member_count");
}

void DialogParticipantManager::on_dialog_opened(DialogId dialog_id) {
  auto online_count_it = dialog_online_member_counts_.find(dialog_id);
  if (online_count_it == dialog_online_member_counts_.end()) {
    return;
  }
  auto &info = online_count_it->second;
  CHECK(!info.is_update_sent);
  if (Time::now() - info.update_time < ONLINE_MEMBER_COUNT_CACHE_EXPIRE_TIME) {
    info.is_update_sent = true;
    send_update_chat_online_member_count(dialog_id, info.online_member_count);
  }
}

void DialogParticipantManager::on_dialog_closed(DialogId dialog_id) {
  auto online_count_it = dialog_online_member_counts_.find(dialog_id);
  if (online_count_it != dialog_online_member_counts_.end()) {
    auto &info = online_count_it->second;
    info.is_update_sent = false;
  }
  update_dialog_online_member_count_timeout_.set_timeout_in(dialog_id.get(), ONLINE_MEMBER_COUNT_CACHE_EXPIRE_TIME);
}

void DialogParticipantManager::set_dialog_online_member_count(DialogId dialog_id, int32 online_member_count,
                                                              bool is_from_server, const char *source) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (online_member_count < 0) {
    LOG(ERROR) << "Receive online_member_count = " << online_member_count << " in " << dialog_id;
    online_member_count = 0;
  }

  switch (dialog_id.get_type()) {
    case DialogType::Chat: {
      auto participant_count = td_->chat_manager_->get_chat_participant_count(dialog_id.get_chat_id());
      if (online_member_count > participant_count) {
        online_member_count = participant_count;
      }
      break;
    }
    case DialogType::Channel: {
      auto participant_count = td_->chat_manager_->get_channel_participant_count(dialog_id.get_channel_id());
      if (participant_count != 0 && online_member_count > participant_count) {
        online_member_count = participant_count;
      }
      break;
    }
    default:
      break;
  }

  bool is_open = td_->messages_manager_->is_dialog_opened(dialog_id);
  auto &info = dialog_online_member_counts_[dialog_id];
  LOG(INFO) << "Change number of online members from " << info.online_member_count << " to " << online_member_count
            << " in " << dialog_id << " from " << source;
  bool need_update = is_open && (!info.is_update_sent || info.online_member_count != online_member_count);
  info.online_member_count = online_member_count;
  info.update_time = Time::now();

  if (need_update) {
    info.is_update_sent = true;
    send_update_chat_online_member_count(dialog_id, online_member_count);
  }
  if (is_open) {
    if (is_from_server) {
      update_dialog_online_member_count_timeout_.set_timeout_in(dialog_id.get(), ONLINE_MEMBER_COUNT_UPDATE_TIME);
    } else {
      update_dialog_online_member_count_timeout_.add_timeout_in(dialog_id.get(), ONLINE_MEMBER_COUNT_UPDATE_TIME);
    }
  }
}

void DialogParticipantManager::send_update_chat_online_member_count(DialogId dialog_id,
                                                                    int32 online_member_count) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  send_closure(
      G()->td(), &Td::send_update,
      td_api::make_object<td_api::updateChatOnlineMemberCount>(
          td_->dialog_manager_->get_chat_id_object(dialog_id, "updateChatOnlineMemberCount"), online_member_count));
}

void DialogParticipantManager::update_user_online_member_count(UserId user_id) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  auto user_it = user_online_member_dialogs_.find(user_id);
  if (user_it == user_online_member_dialogs_.end()) {
    return;
  }
  CHECK(user_it->second != nullptr);
  auto &online_member_dialogs = user_it->second->online_member_dialogs_;

  auto now = G()->unix_time();
  vector<DialogId> expired_dialog_ids;
  for (const auto &it : online_member_dialogs) {
    auto dialog_id = it.first;
    auto time = it.second;
    if (time < now - ONLINE_MEMBER_COUNT_CACHE_EXPIRE_TIME) {
      expired_dialog_ids.push_back(dialog_id);
      continue;
    }

    switch (dialog_id.get_type()) {
      case DialogType::Chat:
        td_->chat_manager_->update_chat_online_member_count(dialog_id.get_chat_id(), false);
        break;
      case DialogType::Channel:
        update_channel_online_member_count(dialog_id.get_channel_id(), false);
        break;
      case DialogType::User:
      case DialogType::SecretChat:
      case DialogType::None:
        UNREACHABLE();
        break;
    }
  }
  for (auto &dialog_id : expired_dialog_ids) {
    online_member_dialogs.erase(dialog_id);
    if (dialog_id.get_type() == DialogType::Channel) {
      drop_cached_channel_participants(dialog_id.get_channel_id());
    }
  }
  if (online_member_dialogs.empty()) {
    user_online_member_dialogs_.erase(user_it);
  }
}

void DialogParticipantManager::update_channel_online_member_count(ChannelId channel_id, bool is_from_server) {
  if (!td_->chat_manager_->is_megagroup_channel(channel_id) ||
      td_->chat_manager_->get_channel_effective_has_hidden_participants(channel_id,
                                                                        "update_channel_online_member_count")) {
    return;
  }

  auto it = cached_channel_participants_.find(channel_id);
  if (it == cached_channel_participants_.end()) {
    return;
  }
  update_dialog_online_member_count(it->second, DialogId(channel_id), is_from_server);
}

void DialogParticipantManager::update_dialog_online_member_count(const vector<DialogParticipant> &participants,
                                                                 DialogId dialog_id, bool is_from_server) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  CHECK(dialog_id.is_valid());

  int32 online_member_count = 0;
  int32 unix_time = G()->unix_time();
  for (const auto &participant : participants) {
    if (participant.dialog_id_.get_type() != DialogType::User) {
      continue;
    }
    auto user_id = participant.dialog_id_.get_user_id();
    if (!td_->user_manager_->is_user_deleted(user_id) && !td_->user_manager_->is_user_bot(user_id)) {
      if (td_->user_manager_->is_user_online(user_id, 0, unix_time)) {
        online_member_count++;
      }
      if (is_from_server) {
        auto &online_member_dialogs = user_online_member_dialogs_[user_id];
        if (online_member_dialogs == nullptr) {
          online_member_dialogs = make_unique<UserOnlineMemberDialogs>();
        }
        online_member_dialogs->online_member_dialogs_[dialog_id] = unix_time;
      }
    }
  }
  on_update_dialog_online_member_count(dialog_id, online_member_count, is_from_server);
}

Status DialogParticipantManager::can_manage_dialog_join_requests(DialogId dialog_id) {
  TRY_STATUS(td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write,
                                                       "can_manage_dialog_join_requests"));

  switch (dialog_id.get_type()) {
    case DialogType::SecretChat:
    case DialogType::User:
      return Status::Error(400, "The chat can't have join requests");
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      if (!td_->chat_manager_->get_chat_is_active(chat_id)) {
        return Status::Error(400, "Chat is deactivated");
      }
      if (!td_->chat_manager_->get_chat_status(chat_id).can_manage_invite_links()) {
        return Status::Error(400, "Not enough rights to manage chat join requests");
      }
      break;
    }
    case DialogType::Channel:
      if (!td_->chat_manager_->get_channel_status(dialog_id.get_channel_id()).can_manage_invite_links()) {
        return Status::Error(400, "Not enough rights to manage chat join requests");
      }
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  return Status::OK();
}

void DialogParticipantManager::fix_pending_join_requests(DialogId dialog_id, int32 &pending_join_request_count,
                                                         vector<UserId> &pending_join_request_user_ids) const {
  bool need_drop_pending_join_requests = [&] {
    if (pending_join_request_count < 0) {
      return true;
    }
    switch (dialog_id.get_type()) {
      case DialogType::User:
      case DialogType::SecretChat:
        return true;
      case DialogType::Chat: {
        auto chat_id = dialog_id.get_chat_id();
        auto status = td_->chat_manager_->get_chat_status(chat_id);
        if (!status.can_manage_invite_links()) {
          return true;
        }
        break;
      }
      case DialogType::Channel: {
        auto channel_id = dialog_id.get_channel_id();
        auto status = td_->chat_manager_->get_channel_permissions(channel_id);
        if (!status.can_manage_invite_links()) {
          return true;
        }
        break;
      }
      case DialogType::None:
      default:
        UNREACHABLE();
    }
    return false;
  }();
  if (need_drop_pending_join_requests) {
    pending_join_request_count = 0;
    pending_join_request_user_ids.clear();
  } else if (static_cast<size_t>(pending_join_request_count) < pending_join_request_user_ids.size()) {
    LOG(ERROR) << "Fix pending join request count from " << pending_join_request_count << " to "
               << pending_join_request_user_ids.size();
    pending_join_request_count = narrow_cast<int32>(pending_join_request_user_ids.size());
  }

  static constexpr size_t MAX_PENDING_JOIN_REQUESTS = 3;
  if (pending_join_request_user_ids.size() > MAX_PENDING_JOIN_REQUESTS) {
    pending_join_request_user_ids.resize(MAX_PENDING_JOIN_REQUESTS);
  }
}

void DialogParticipantManager::get_dialog_join_requests(
    DialogId dialog_id, const string &invite_link, const string &query,
    td_api::object_ptr<td_api::chatJoinRequest> offset_request, int32 limit,
    Promise<td_api::object_ptr<td_api::chatJoinRequests>> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_join_requests(dialog_id));

  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }

  UserId offset_user_id;
  int32 offset_date = 0;
  if (offset_request != nullptr) {
    offset_user_id = UserId(offset_request->user_id_);
    offset_date = offset_request->date_;
  }

  td_->create_handler<GetChatJoinRequestsQuery>(std::move(promise))
      ->send(dialog_id, invite_link, query, offset_date, offset_user_id, limit);
}

void DialogParticipantManager::process_dialog_join_request(DialogId dialog_id, UserId user_id, bool approve,
                                                           Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_join_requests(dialog_id));
  td_->create_handler<HideChatJoinRequestQuery>(std::move(promise))->send(dialog_id, user_id, approve);
}

void DialogParticipantManager::process_dialog_join_requests(DialogId dialog_id, const string &invite_link, bool approve,
                                                            Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, can_manage_dialog_join_requests(dialog_id));
  td_->create_handler<HideAllChatJoinRequestsQuery>(std::move(promise))->send(dialog_id, invite_link, approve);
}

void DialogParticipantManager::speculative_update_dialog_administrators(DialogId dialog_id, UserId user_id,
                                                                        const DialogParticipantStatus &new_status,
                                                                        const DialogParticipantStatus &old_status) {
  if (new_status.is_administrator_member() == old_status.is_administrator_member() &&
      new_status.get_rank() == old_status.get_rank()) {
    return;
  }
  auto it = dialog_administrators_.find(dialog_id);
  if (it == dialog_administrators_.end()) {
    return;
  }
  auto administrators = it->second;
  if (new_status.is_administrator_member()) {
    bool is_found = false;
    for (auto &administrator : administrators) {
      if (administrator.get_user_id() == user_id) {
        is_found = true;
        if (administrator.get_rank() != new_status.get_rank() ||
            administrator.is_creator() != new_status.is_creator()) {
          administrator = DialogAdministrator(user_id, new_status.get_rank(), new_status.is_creator());
          on_update_dialog_administrators(dialog_id, std::move(administrators), true, false);
        }
        break;
      }
    }
    if (!is_found) {
      administrators.emplace_back(user_id, new_status.get_rank(), new_status.is_creator());
      on_update_dialog_administrators(dialog_id, std::move(administrators), true, false);
    }
  } else {
    size_t i = 0;
    while (i != administrators.size() && administrators[i].get_user_id() != user_id) {
      i++;
    }
    if (i != administrators.size()) {
      administrators.erase(administrators.begin() + i);
      on_update_dialog_administrators(dialog_id, std::move(administrators), true, false);
    }
  }
}

td_api::object_ptr<td_api::chatAdministrators> DialogParticipantManager::get_chat_administrators_object(
    const vector<DialogAdministrator> &dialog_administrators) {
  auto administrator_objects = transform(dialog_administrators, [this](const DialogAdministrator &administrator) {
    return administrator.get_chat_administrator_object(td_->user_manager_.get());
  });
  return td_api::make_object<td_api::chatAdministrators>(std::move(administrator_objects));
}

void DialogParticipantManager::get_dialog_administrators(
    DialogId dialog_id, Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "get_dialog_administrators")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::SecretChat:
      return promise.set_value(td_api::make_object<td_api::chatAdministrators>());
    case DialogType::Chat:
    case DialogType::Channel:
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
      return;
  }

  auto it = dialog_administrators_.find(dialog_id);
  if (it != dialog_administrators_.end()) {
    reload_dialog_administrators(dialog_id, it->second, Auto());  // update administrators cache
    return promise.set_value(get_chat_administrators_object(it->second));
  }

  if (G()->use_chat_info_database()) {
    LOG(INFO) << "Load administrators of " << dialog_id << " from database";
    G()->td_db()->get_sqlite_pmc()->get(
        get_dialog_administrators_database_key(dialog_id),
        PromiseCreator::lambda(
            [actor_id = actor_id(this), dialog_id, promise = std::move(promise)](string value) mutable {
              send_closure(actor_id, &DialogParticipantManager::on_load_dialog_administrators_from_database, dialog_id,
                           std::move(value), std::move(promise));
            }));
    return;
  }

  reload_dialog_administrators(dialog_id, {}, std::move(promise));
}

string DialogParticipantManager::get_dialog_administrators_database_key(DialogId dialog_id) {
  return PSTRING() << "adm" << (-dialog_id.get());
}

void DialogParticipantManager::on_load_dialog_administrators_from_database(
    DialogId dialog_id, string value, Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (value.empty()) {
    return reload_dialog_administrators(dialog_id, {}, std::move(promise));
  }

  vector<DialogAdministrator> administrators;
  if (log_event_parse(administrators, value).is_error()) {
    return reload_dialog_administrators(dialog_id, {}, std::move(promise));
  }

  LOG(INFO) << "Successfully loaded " << administrators.size() << " administrators in " << dialog_id
            << " from database";

  MultiPromiseActorSafe load_users_multipromise{"LoadUsersMultiPromiseActor"};
  load_users_multipromise.add_promise(
      PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, administrators,
                              promise = std::move(promise)](Result<Unit> result) mutable {
        send_closure(actor_id, &DialogParticipantManager::on_load_administrator_users_finished, dialog_id,
                     std::move(administrators), std::move(result), std::move(promise));
      }));

  auto lock_promise = load_users_multipromise.get_promise();

  for (auto &administrator : administrators) {
    td_->user_manager_->get_user(administrator.get_user_id(), 3, load_users_multipromise.get_promise());
  }

  lock_promise.set_value(Unit());
}

void DialogParticipantManager::on_load_administrator_users_finished(
    DialogId dialog_id, vector<DialogAdministrator> administrators, Result<> result,
    Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (result.is_error()) {
    return reload_dialog_administrators(dialog_id, {}, std::move(promise));
  }

  auto it = dialog_administrators_.emplace(dialog_id, std::move(administrators)).first;
  reload_dialog_administrators(dialog_id, it->second, Auto());  // update administrators cache
  promise.set_value(get_chat_administrators_object(it->second));
}

void DialogParticipantManager::on_update_dialog_administrators(DialogId dialog_id,
                                                               vector<DialogAdministrator> &&administrators,
                                                               bool have_access, bool from_database) {
  LOG(INFO) << "Update administrators in " << dialog_id << " to " << administrators;
  if (have_access) {
    CHECK(dialog_id.is_valid());
    std::sort(administrators.begin(), administrators.end(),
              [](const DialogAdministrator &lhs, const DialogAdministrator &rhs) {
                return lhs.get_user_id().get() < rhs.get_user_id().get();
              });

    auto it = dialog_administrators_.find(dialog_id);
    if (it != dialog_administrators_.end()) {
      if (it->second == administrators) {
        return;
      }
      it->second = std::move(administrators);
    } else {
      it = dialog_administrators_.emplace(dialog_id, std::move(administrators)).first;
    }

    if (G()->use_chat_info_database() && !from_database) {
      LOG(INFO) << "Save administrators of " << dialog_id << " to database";
      G()->td_db()->get_sqlite_pmc()->set(get_dialog_administrators_database_key(dialog_id),
                                          log_event_store(it->second).as_slice().str(), Auto());
    }
  } else {
    dialog_administrators_.erase(dialog_id);
    if (G()->use_chat_info_database()) {
      G()->td_db()->get_sqlite_pmc()->erase(get_dialog_administrators_database_key(dialog_id), Auto());
    }
  }
}

void DialogParticipantManager::reload_dialog_administrators(
    DialogId dialog_id, const vector<DialogAdministrator> &dialog_administrators,
    Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise) {
  auto dialog_type = dialog_id.get_type();
  if (dialog_type == DialogType::Chat &&
      !td_->chat_manager_->get_chat_permissions(dialog_id.get_chat_id()).is_member()) {
    return promise.set_value(td_api::make_object<td_api::chatAdministrators>());
  }
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (promise) {
          if (result.is_ok()) {
            send_closure(actor_id, &DialogParticipantManager::on_reload_dialog_administrators, dialog_id,
                         std::move(promise));
          } else {
            promise.set_error(result.move_as_error());
          }
        }
      });
  switch (dialog_type) {
    case DialogType::Chat:
      td_->chat_manager_->load_chat_full(dialog_id.get_chat_id(), false, std::move(query_promise),
                                         "reload_dialog_administrators");
      break;
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      if (td_->chat_manager_->is_broadcast_channel(channel_id) &&
          !td_->chat_manager_->get_channel_status(channel_id).is_administrator()) {
        return query_promise.set_error(Status::Error(400, "Administrator list is inaccessible"));
      }
      auto hash = get_vector_hash(transform(dialog_administrators, [](const DialogAdministrator &administrator) {
        return static_cast<uint64>(administrator.get_user_id().get());
      }));
      td_->create_handler<GetChannelAdministratorsQuery>(std::move(query_promise))->send(channel_id, hash);
      break;
    }
    default:
      UNREACHABLE();
  }
}

void DialogParticipantManager::on_reload_dialog_administrators(
    DialogId dialog_id, Promise<td_api::object_ptr<td_api::chatAdministrators>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto it = dialog_administrators_.find(dialog_id);
  if (it != dialog_administrators_.end()) {
    return promise.set_value(get_chat_administrators_object(it->second));
  }

  LOG(ERROR) << "Failed to load administrators in " << dialog_id;
  promise.set_error(Status::Error(500, "Failed to find chat administrators"));
}

void DialogParticipantManager::send_update_chat_member(DialogId dialog_id, UserId agent_user_id, int32 date,
                                                       const DialogInviteLink &invite_link, bool via_join_request,
                                                       bool via_dialog_filter_invite_link,
                                                       const DialogParticipant &old_dialog_participant,
                                                       const DialogParticipant &new_dialog_participant) {
  CHECK(td_->auth_manager_->is_bot());
  td_->dialog_manager_->force_create_dialog(dialog_id, "send_update_chat_member", true);
  send_closure(G()->td(), &Td::send_update,
               td_api::make_object<td_api::updateChatMember>(
                   td_->dialog_manager_->get_chat_id_object(dialog_id, "updateChatMember"),
                   td_->user_manager_->get_user_id_object(agent_user_id, "updateChatMember"), date,
                   invite_link.get_chat_invite_link_object(td_->user_manager_.get()), via_join_request,
                   via_dialog_filter_invite_link,
                   td_->chat_manager_->get_chat_member_object(old_dialog_participant, "updateChatMember old"),
                   td_->chat_manager_->get_chat_member_object(new_dialog_participant, "updateChatMember new")));
}

void DialogParticipantManager::on_update_bot_stopped(UserId user_id, int32 date, bool is_stopped, bool force) {
  CHECK(td_->auth_manager_->is_bot());
  if (date <= 0 || !td_->user_manager_->have_user_force(user_id, "on_update_bot_stopped")) {
    LOG(ERROR) << "Receive invalid updateBotStopped by " << user_id << " at " << date;
    return;
  }
  auto my_user_id = td_->user_manager_->get_my_id();
  if (!td_->user_manager_->have_user_force(my_user_id, "on_update_bot_stopped 2")) {
    if (!force) {
      td_->user_manager_->get_me(PromiseCreator::lambda([actor_id = actor_id(this), user_id, date, is_stopped](Unit) {
        send_closure(actor_id, &DialogParticipantManager::on_update_bot_stopped, user_id, date, is_stopped, true);
      }));
      return;
    }
    LOG(ERROR) << "Have no self-user to process updateBotStopped";
  }

  DialogParticipant old_dialog_participant(DialogId(my_user_id), user_id, date, DialogParticipantStatus::Banned(0));
  DialogParticipant new_dialog_participant(DialogId(my_user_id), user_id, date, DialogParticipantStatus::Member(0));
  if (is_stopped) {
    std::swap(old_dialog_participant.status_, new_dialog_participant.status_);
  }

  send_update_chat_member(DialogId(user_id), user_id, date, DialogInviteLink(), false, false, old_dialog_participant,
                          new_dialog_participant);
}

void DialogParticipantManager::on_update_chat_participant(
    ChatId chat_id, UserId user_id, int32 date, DialogInviteLink invite_link, bool via_join_request,
    telegram_api::object_ptr<telegram_api::ChatParticipant> old_participant,
    telegram_api::object_ptr<telegram_api::ChatParticipant> new_participant) {
  CHECK(td_->auth_manager_->is_bot());
  if (!chat_id.is_valid() || !user_id.is_valid() || date <= 0 ||
      (old_participant == nullptr && new_participant == nullptr)) {
    LOG(ERROR) << "Receive invalid updateChatParticipant in " << chat_id << " by " << user_id << " at " << date << ": "
               << to_string(old_participant) << " -> " << to_string(new_participant);
    return;
  }

  if (!td_->chat_manager_->have_chat(chat_id)) {
    LOG(ERROR) << "Receive updateChatParticipant in unknown " << chat_id;
    return;
  }
  auto chat_date = td_->chat_manager_->get_chat_date(chat_id);
  auto chat_status = td_->chat_manager_->get_chat_status(chat_id);
  auto is_creator = chat_status.is_creator();

  DialogParticipant old_dialog_participant;
  DialogParticipant new_dialog_participant;
  if (old_participant != nullptr) {
    old_dialog_participant = DialogParticipant(std::move(old_participant), chat_date, is_creator);
    if (new_participant == nullptr) {
      new_dialog_participant = DialogParticipant::left(old_dialog_participant.dialog_id_);
    } else {
      new_dialog_participant = DialogParticipant(std::move(new_participant), chat_date, is_creator);
    }
  } else {
    new_dialog_participant = DialogParticipant(std::move(new_participant), chat_date, is_creator);
    old_dialog_participant = DialogParticipant::left(new_dialog_participant.dialog_id_);
  }
  if (old_dialog_participant.dialog_id_ != new_dialog_participant.dialog_id_ || !old_dialog_participant.is_valid() ||
      !new_dialog_participant.is_valid()) {
    LOG(ERROR) << "Receive wrong updateChatParticipant: " << old_dialog_participant << " -> " << new_dialog_participant;
    return;
  }
  if (new_dialog_participant.dialog_id_ == DialogId(td_->user_manager_->get_my_id()) &&
      new_dialog_participant.status_ != chat_status && false) {
    LOG(ERROR) << "Have status " << chat_status << " after receiving updateChatParticipant in " << chat_id << " by "
               << user_id << " at " << date << " from " << old_dialog_participant << " to " << new_dialog_participant;
  }

  send_update_chat_member(DialogId(chat_id), user_id, date, invite_link, via_join_request, false,
                          old_dialog_participant, new_dialog_participant);
}

void DialogParticipantManager::on_update_channel_participant(
    ChannelId channel_id, UserId user_id, int32 date, DialogInviteLink invite_link, bool via_join_request,
    bool via_dialog_filter_invite_link, telegram_api::object_ptr<telegram_api::ChannelParticipant> old_participant,
    telegram_api::object_ptr<telegram_api::ChannelParticipant> new_participant) {
  CHECK(td_->auth_manager_->is_bot());
  if (!channel_id.is_valid() || !user_id.is_valid() || date <= 0 ||
      (old_participant == nullptr && new_participant == nullptr)) {
    LOG(ERROR) << "Receive invalid updateChannelParticipant in " << channel_id << " by " << user_id << " at " << date
               << ": " << to_string(old_participant) << " -> " << to_string(new_participant);
    return;
  }
  if (!td_->chat_manager_->have_channel(channel_id)) {
    LOG(ERROR) << "Receive updateChannelParticipant in unknown " << channel_id;
    return;
  }

  DialogParticipant old_dialog_participant;
  DialogParticipant new_dialog_participant;
  auto channel_type = td_->chat_manager_->get_channel_type(channel_id);
  if (old_participant != nullptr) {
    old_dialog_participant = DialogParticipant(std::move(old_participant), channel_type);
    if (new_participant == nullptr) {
      new_dialog_participant = DialogParticipant::left(old_dialog_participant.dialog_id_);
    } else {
      new_dialog_participant = DialogParticipant(std::move(new_participant), channel_type);
    }
  } else {
    new_dialog_participant = DialogParticipant(std::move(new_participant), channel_type);
    old_dialog_participant = DialogParticipant::left(new_dialog_participant.dialog_id_);
  }
  if (old_dialog_participant.dialog_id_ != new_dialog_participant.dialog_id_ || !old_dialog_participant.is_valid() ||
      !new_dialog_participant.is_valid()) {
    LOG(ERROR) << "Receive wrong updateChannelParticipant: " << old_dialog_participant << " -> "
               << new_dialog_participant;
    return;
  }
  if (new_dialog_participant.status_.is_administrator() && user_id == td_->user_manager_->get_my_id() &&
      !new_dialog_participant.status_.can_be_edited()) {
    LOG(ERROR) << "Fix wrong can_be_edited in " << new_dialog_participant << " from " << channel_id << " changed from "
               << old_dialog_participant;
    new_dialog_participant.status_.toggle_can_be_edited();
  }
  if (old_dialog_participant.status_.is_banned() && DialogId(user_id) == old_dialog_participant.dialog_id_) {
    LOG(ERROR) << "User changed self status in " << channel_id << " from " << old_dialog_participant << " to "
               << new_dialog_participant;
  }

  if (old_dialog_participant.dialog_id_ == td_->dialog_manager_->get_my_dialog_id() &&
      old_dialog_participant.status_.is_administrator() && !new_dialog_participant.status_.is_administrator()) {
    drop_channel_participant_cache(channel_id);
  } else if (have_channel_participant_cache(channel_id)) {
    add_channel_participant_to_cache(channel_id, new_dialog_participant, true);
  }

  auto channel_status = td_->chat_manager_->get_channel_status(channel_id);
  if (new_dialog_participant.dialog_id_ == td_->dialog_manager_->get_my_dialog_id() &&
      new_dialog_participant.status_ != channel_status && false) {
    LOG(ERROR) << "Have status " << channel_status << " after receiving updateChannelParticipant in " << channel_id
               << " by " << user_id << " at " << date << " from " << old_dialog_participant << " to "
               << new_dialog_participant;
  }

  send_update_chat_member(DialogId(channel_id), user_id, date, invite_link, via_join_request,
                          via_dialog_filter_invite_link, old_dialog_participant, new_dialog_participant);
}

void DialogParticipantManager::on_update_chat_invite_requester(DialogId dialog_id, UserId user_id, string about,
                                                               int32 date, DialogInviteLink invite_link) {
  CHECK(td_->auth_manager_->is_bot());
  if (date <= 0 || !td_->user_manager_->have_user_force(user_id, "on_update_chat_invite_requester") ||
      !td_->dialog_manager_->have_dialog_info_force(dialog_id, "on_update_chat_invite_requester")) {
    LOG(ERROR) << "Receive invalid updateBotChatInviteRequester by " << user_id << " in " << dialog_id << " at "
               << date;
    return;
  }
  DialogId user_dialog_id(user_id);
  td_->dialog_manager_->force_create_dialog(dialog_id, "on_update_chat_invite_requester", true);
  td_->dialog_manager_->force_create_dialog(user_dialog_id, "on_update_chat_invite_requester");

  send_closure(G()->td(), &Td::send_update,
               td_api::make_object<td_api::updateNewChatJoinRequest>(
                   td_->dialog_manager_->get_chat_id_object(dialog_id, "updateNewChatJoinRequest"),
                   td_api::make_object<td_api::chatJoinRequest>(
                       td_->user_manager_->get_user_id_object(user_id, "updateNewChatJoinRequest"), date, about),
                   td_->dialog_manager_->get_chat_id_object(user_dialog_id, "updateNewChatJoinRequest 2"),
                   invite_link.get_chat_invite_link_object(td_->user_manager_.get())));
}

void DialogParticipantManager::get_dialog_participant(DialogId dialog_id, DialogId participant_dialog_id,
                                                      Promise<td_api::object_ptr<td_api::chatMember>> &&promise) {
  auto new_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), promise = std::move(promise)](Result<DialogParticipant> &&result) mutable {
        TRY_RESULT_PROMISE(promise, dialog_participant, std::move(result));
        send_closure(actor_id, &DialogParticipantManager::finish_get_dialog_participant, std::move(dialog_participant),
                     std::move(promise));
      });
  do_get_dialog_participant(dialog_id, participant_dialog_id, std::move(new_promise));
}

void DialogParticipantManager::finish_get_dialog_participant(
    DialogParticipant &&dialog_participant, Promise<td_api::object_ptr<td_api::chatMember>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  auto participant_dialog_id = dialog_participant.dialog_id_;
  bool is_user = participant_dialog_id.get_type() == DialogType::User;
  if ((is_user && !td_->user_manager_->have_user(participant_dialog_id.get_user_id())) ||
      (!is_user && !td_->messages_manager_->have_dialog(participant_dialog_id))) {
    return promise.set_error(Status::Error(400, "Member not found"));
  }

  promise.set_value(td_->chat_manager_->get_chat_member_object(dialog_participant, "finish_get_dialog_participant"));
}

void DialogParticipantManager::do_get_dialog_participant(DialogId dialog_id, DialogId participant_dialog_id,
                                                         Promise<DialogParticipant> &&promise) {
  LOG(INFO) << "Receive getChatMember request to get " << participant_dialog_id << " in " << dialog_id;
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "do_get_dialog_participant")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User: {
      auto my_user_id = td_->user_manager_->get_my_id();
      auto peer_user_id = dialog_id.get_user_id();
      if (participant_dialog_id == DialogId(my_user_id)) {
        return promise.set_value(DialogParticipant::private_member(my_user_id, peer_user_id));
      }
      if (participant_dialog_id == dialog_id) {
        return promise.set_value(DialogParticipant::private_member(peer_user_id, my_user_id));
      }

      return promise.set_error(Status::Error(400, "Member not found"));
    }
    case DialogType::Chat:
      if (participant_dialog_id.get_type() != DialogType::User) {
        return promise.set_value(DialogParticipant::left(participant_dialog_id));
      }
      return td_->chat_manager_->get_chat_participant(dialog_id.get_chat_id(), participant_dialog_id.get_user_id(),
                                                      std::move(promise));
    case DialogType::Channel:
      return get_channel_participant(dialog_id.get_channel_id(), participant_dialog_id, std::move(promise));
    case DialogType::SecretChat: {
      auto my_user_id = td_->user_manager_->get_my_id();
      auto peer_user_id = td_->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
      if (participant_dialog_id == DialogId(my_user_id)) {
        return promise.set_value(DialogParticipant::private_member(my_user_id, peer_user_id));
      }
      if (peer_user_id.is_valid() && participant_dialog_id == DialogId(peer_user_id)) {
        return promise.set_value(DialogParticipant::private_member(peer_user_id, my_user_id));
      }

      return promise.set_error(Status::Error(400, "Member not found"));
    }
    case DialogType::None:
    default:
      UNREACHABLE();
      return;
  }
}

void DialogParticipantManager::get_channel_participant(ChannelId channel_id, DialogId participant_dialog_id,
                                                       Promise<DialogParticipant> &&promise) {
  LOG(INFO) << "Trying to get " << participant_dialog_id << " as member of " << channel_id;

  auto input_peer = td_->dialog_manager_->get_input_peer(participant_dialog_id, AccessRights::Know);
  if (input_peer == nullptr) {
    return promise.set_error(Status::Error(400, "Member not found"));
  }
  if (td_->chat_manager_->is_broadcast_channel(channel_id) &&
      !td_->chat_manager_->get_channel_status(channel_id).is_administrator()) {
    return promise.set_error(Status::Error(400, "Member list is inaccessible"));
  }

  if (have_channel_participant_cache(channel_id)) {
    auto *participant = get_channel_participant_from_cache(channel_id, participant_dialog_id);
    if (participant != nullptr) {
      return promise.set_value(DialogParticipant{*participant});
    }
  }

  if (td_->auth_manager_->is_bot() && participant_dialog_id == td_->dialog_manager_->get_my_dialog_id() &&
      td_->chat_manager_->have_channel(channel_id)) {
    // bots don't need inviter information
    td_->chat_manager_->reload_channel(channel_id, Auto(), "get_channel_participant");
    return promise.set_value(DialogParticipant{participant_dialog_id, participant_dialog_id.get_user_id(),
                                               td_->chat_manager_->get_channel_date(channel_id),
                                               td_->chat_manager_->get_channel_status(channel_id)});
  }

  auto on_result_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), channel_id, participant_dialog_id,
                              promise = std::move(promise)](Result<DialogParticipant> r_dialog_participant) mutable {
        TRY_RESULT_PROMISE(promise, dialog_participant, std::move(r_dialog_participant));
        send_closure(actor_id, &DialogParticipantManager::finish_get_channel_participant, channel_id,
                     participant_dialog_id, std::move(dialog_participant), std::move(promise));
      });

  td_->create_handler<GetChannelParticipantQuery>(std::move(on_result_promise))
      ->send(channel_id, participant_dialog_id, std::move(input_peer));
}

void DialogParticipantManager::finish_get_channel_participant(ChannelId channel_id, DialogId participant_dialog_id,
                                                              DialogParticipant &&dialog_participant,
                                                              Promise<DialogParticipant> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  CHECK(dialog_participant.is_valid());  // checked in GetChannelParticipantQuery
  if (dialog_participant.dialog_id_ != participant_dialog_id) {
    LOG(ERROR) << "Receive " << dialog_participant.dialog_id_ << " in " << channel_id << " instead of requested "
               << participant_dialog_id;
    return promise.set_error(Status::Error(500, "Data is unavailable"));
  }

  LOG(INFO) << "Receive " << dialog_participant.dialog_id_ << " as a member of a channel " << channel_id;

  dialog_participant.status_.update_restrictions();
  if (have_channel_participant_cache(channel_id)) {
    add_channel_participant_to_cache(channel_id, dialog_participant, false);
  }
  promise.set_value(std::move(dialog_participant));
}

std::pair<int32, vector<DialogId>> DialogParticipantManager::search_among_dialogs(const vector<DialogId> &dialog_ids,
                                                                                  const string &query,
                                                                                  int32 limit) const {
  Hints hints;

  auto unix_time = G()->unix_time();
  for (auto dialog_id : dialog_ids) {
    if (!td_->dialog_manager_->have_dialog_info(dialog_id)) {
      continue;
    }
    if (query.empty()) {
      hints.add(dialog_id.get(), Slice(" "));
    } else {
      hints.add(dialog_id.get(), td_->dialog_manager_->get_dialog_search_text(dialog_id));
    }
    if (dialog_id.get_type() == DialogType::User) {
      hints.set_rating(dialog_id.get(), -td_->user_manager_->get_user_was_online(dialog_id.get_user_id(), unix_time));
    }
  }

  auto result = hints.search(query, limit, true);
  return {narrow_cast<int32>(result.first), transform(result.second, [](int64 key) { return DialogId(key); })};
}

DialogParticipants DialogParticipantManager::search_private_chat_participants(UserId peer_user_id, const string &query,
                                                                              int32 limit,
                                                                              DialogParticipantFilter filter) const {
  auto my_user_id = td_->user_manager_->get_my_id();
  vector<DialogId> dialog_ids;
  if (filter.is_dialog_participant_suitable(td_, DialogParticipant::private_member(my_user_id, peer_user_id))) {
    dialog_ids.push_back(DialogId(my_user_id));
  }
  if (peer_user_id.is_valid() && peer_user_id != my_user_id &&
      filter.is_dialog_participant_suitable(td_, DialogParticipant::private_member(peer_user_id, my_user_id))) {
    dialog_ids.push_back(DialogId(peer_user_id));
  }

  auto result = search_among_dialogs(dialog_ids, query, limit);
  return {result.first, transform(result.second, [&](DialogId dialog_id) {
            auto user_id = dialog_id.get_user_id();
            return DialogParticipant::private_member(user_id, user_id == my_user_id ? peer_user_id : my_user_id);
          })};
}

void DialogParticipantManager::search_chat_participants(ChatId chat_id, const string &query, int32 limit,
                                                        DialogParticipantFilter filter,
                                                        Promise<DialogParticipants> &&promise) {
  if (limit < 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be non-negative"));
  }

  auto load_chat_full_promise = PromiseCreator::lambda([actor_id = actor_id(this), chat_id, query, limit, filter,
                                                        promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      send_closure(actor_id, &DialogParticipantManager::do_search_chat_participants, chat_id, query, limit, filter,
                   std::move(promise));
    }
  });
  td_->chat_manager_->load_chat_full(chat_id, false, std::move(load_chat_full_promise), "search_chat_participants");
}

void DialogParticipantManager::do_search_chat_participants(ChatId chat_id, const string &query, int32 limit,
                                                           DialogParticipantFilter filter,
                                                           Promise<DialogParticipants> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  const auto *participants = td_->chat_manager_->get_chat_participants(chat_id);
  if (participants == nullptr) {
    return promise.set_error(Status::Error(500, "Can't find basic group full info"));
  }

  vector<DialogId> dialog_ids;
  for (const auto &participant : *participants) {
    if (filter.is_dialog_participant_suitable(td_, participant)) {
      dialog_ids.push_back(participant.dialog_id_);
    }
  }

  int32 total_count;
  std::tie(total_count, dialog_ids) = search_among_dialogs(dialog_ids, query, limit);
  td_->story_manager_->on_view_dialog_active_stories(dialog_ids);
  vector<DialogParticipant> dialog_participants;
  for (auto dialog_id : dialog_ids) {
    for (const auto &participant : *participants) {
      if (participant.dialog_id_ == dialog_id) {
        dialog_participants.push_back(participant);
        break;
      }
    }
  }
  promise.set_value(DialogParticipants{total_count, std::move(dialog_participants)});
}

void DialogParticipantManager::get_channel_participants(ChannelId channel_id,
                                                        td_api::object_ptr<td_api::SupergroupMembersFilter> &&filter,
                                                        string additional_query, int32 offset, int32 limit,
                                                        int32 additional_limit, Promise<DialogParticipants> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_GET_CHANNEL_PARTICIPANTS) {
    limit = MAX_GET_CHANNEL_PARTICIPANTS;
  }

  if (offset < 0) {
    return promise.set_error(Status::Error(400, "Parameter offset must be non-negative"));
  }

  if (td_->chat_manager_->is_broadcast_channel(channel_id) &&
      !td_->chat_manager_->get_channel_status(channel_id).is_administrator()) {
    return promise.set_error(Status::Error(400, "Member list is inaccessible"));
  }

  ChannelParticipantFilter participant_filter(filter);
  auto get_channel_participants_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), channel_id, filter = participant_filter,
       additional_query = std::move(additional_query), offset, limit, additional_limit, promise = std::move(promise)](
          Result<telegram_api::object_ptr<telegram_api::channels_channelParticipants>> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &DialogParticipantManager::on_get_channel_participants, channel_id, std::move(filter),
                       offset, limit, std::move(additional_query), additional_limit, result.move_as_ok(),
                       std::move(promise));
        }
      });
  td_->create_handler<GetChannelParticipantsQuery>(std::move(get_channel_participants_promise))
      ->send(channel_id, participant_filter, offset, limit);
}

void DialogParticipantManager::on_get_channel_participants(
    ChannelId channel_id, ChannelParticipantFilter &&filter, int32 offset, int32 limit, string additional_query,
    int32 additional_limit, telegram_api::object_ptr<telegram_api::channels_channelParticipants> &&channel_participants,
    Promise<DialogParticipants> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  td_->user_manager_->on_get_users(std::move(channel_participants->users_), "on_get_channel_participants");
  td_->chat_manager_->on_get_chats(std::move(channel_participants->chats_), "on_get_channel_participants");
  int32 total_count = channel_participants->count_;
  auto participants = std::move(channel_participants->participants_);
  LOG(INFO) << "Receive " << participants.size() << " " << filter << " members in " << channel_id;

  bool is_full = offset == 0 && static_cast<int32>(participants.size()) < limit && total_count < limit;
  bool has_hidden_participants =
      td_->chat_manager_->get_channel_effective_has_hidden_participants(channel_id, "on_get_channel_participants");
  bool is_full_recent = is_full && filter.is_recent() && !has_hidden_participants;

  auto channel_type = td_->chat_manager_->get_channel_type(channel_id);
  vector<DialogParticipant> result;
  for (auto &participant_ptr : participants) {
    auto debug_participant = to_string(participant_ptr);
    result.emplace_back(std::move(participant_ptr), channel_type);
    const auto &participant = result.back();
    UserId participant_user_id;
    if (participant.dialog_id_.get_type() == DialogType::User) {
      participant_user_id = participant.dialog_id_.get_user_id();
    }
    if (!participant.is_valid() || (filter.is_bots() && !td_->user_manager_->is_user_bot(participant_user_id)) ||
        (filter.is_administrators() && !participant.status_.is_administrator()) ||
        ((filter.is_recent() || filter.is_contacts() || filter.is_search()) && !participant.status_.is_member()) ||
        (filter.is_contacts() && !td_->user_manager_->is_user_contact(participant_user_id)) ||
        (filter.is_restricted() && !participant.status_.is_restricted()) ||
        (filter.is_banned() && !participant.status_.is_banned())) {
      bool skip_error = ((filter.is_administrators() || filter.is_bots()) &&
                         td_->user_manager_->is_user_deleted(participant_user_id)) ||
                        (filter.is_contacts() && participant_user_id == td_->user_manager_->get_my_id());
      if (!skip_error) {
        LOG(ERROR) << "Receive " << participant << ", while searching for " << filter << " in " << channel_id
                   << " with offset " << offset << " and limit " << limit << ": " << oneline(debug_participant);
      }
      result.pop_back();
      total_count--;
    }
  }

  if (total_count < narrow_cast<int32>(result.size())) {
    LOG(ERROR) << "Receive total_count = " << total_count << ", but have at least " << result.size() << " " << filter
               << " members in " << channel_id;
    total_count = static_cast<int32>(result.size());
  } else if (is_full && total_count > static_cast<int32>(result.size())) {
    LOG(ERROR) << "Fix total number of " << filter << " members from " << total_count << " to " << result.size()
               << " in " << channel_id << " for request with limit " << limit << " and received " << participants.size()
               << " results";
    total_count = static_cast<int32>(result.size());
  }

  auto is_megagroup = td_->chat_manager_->is_megagroup_channel(channel_id);
  const auto max_participant_count = is_megagroup ? 975 : 195;
  auto participant_count =
      filter.is_recent() && !has_hidden_participants && total_count != 0 && total_count < max_participant_count
          ? total_count
          : -1;
  int32 administrator_count =
      filter.is_administrators() || (filter.is_recent() && has_hidden_participants) ? total_count : -1;
  if (is_full && (filter.is_administrators() || filter.is_bots() || filter.is_recent())) {
    vector<DialogAdministrator> administrators;
    vector<UserId> bot_user_ids;
    {
      if (filter.is_recent()) {
        for (const auto &participant : result) {
          if (participant.dialog_id_.get_type() == DialogType::User) {
            auto participant_user_id = participant.dialog_id_.get_user_id();
            if (participant.status_.is_administrator()) {
              administrators.emplace_back(participant_user_id, participant.status_.get_rank(),
                                          participant.status_.is_creator());
            }
            if (is_full_recent && td_->user_manager_->is_user_bot(participant_user_id)) {
              bot_user_ids.push_back(participant_user_id);
            }
          }
        }
        administrator_count = narrow_cast<int32>(administrators.size());

        if (is_megagroup && !td_->auth_manager_->is_bot() && is_full_recent) {
          set_cached_channel_participants(channel_id, result);
          update_channel_online_member_count(channel_id, true);
        }
      } else if (filter.is_administrators()) {
        for (const auto &participant : result) {
          if (participant.dialog_id_.get_type() == DialogType::User) {
            administrators.emplace_back(participant.dialog_id_.get_user_id(), participant.status_.get_rank(),
                                        participant.status_.is_creator());
          }
        }
      } else if (filter.is_bots()) {
        bot_user_ids = transform(result, [](const DialogParticipant &participant) {
          CHECK(participant.dialog_id_.get_type() == DialogType::User);
          return participant.dialog_id_.get_user_id();
        });
      }
    }
    if (filter.is_administrators() || filter.is_recent()) {
      on_update_dialog_administrators(DialogId(channel_id), std::move(administrators), true, false);
    }
    if (filter.is_bots() || is_full_recent) {
      td_->chat_manager_->on_update_channel_bot_user_ids(channel_id, std::move(bot_user_ids));
    }
  }
  if (have_channel_participant_cache(channel_id)) {
    for (const auto &participant : result) {
      add_channel_participant_to_cache(channel_id, participant, false);
    }
  }

  if (participant_count != -1) {
    td_->chat_manager_->on_update_channel_participant_count(channel_id, participant_count);
  }
  if (administrator_count != -1) {
    td_->chat_manager_->on_update_channel_administrator_count(channel_id, administrator_count);
  }

  if (!additional_query.empty()) {
    auto dialog_ids = transform(result, [](const DialogParticipant &participant) { return participant.dialog_id_; });
    std::pair<int32, vector<DialogId>> result_dialog_ids =
        search_among_dialogs(dialog_ids, additional_query, additional_limit);

    total_count = result_dialog_ids.first;
    FlatHashSet<DialogId, DialogIdHash> result_dialog_ids_set;
    for (auto result_dialog_id : result_dialog_ids.second) {
      CHECK(result_dialog_id.is_valid());
      result_dialog_ids_set.insert(result_dialog_id);
    }
    auto all_participants = std::move(result);
    result.clear();
    for (auto &participant : all_participants) {
      if (result_dialog_ids_set.count(participant.dialog_id_)) {
        result_dialog_ids_set.erase(participant.dialog_id_);
        result.push_back(std::move(participant));
      }
    }
  }

  vector<DialogId> participant_dialog_ids;
  for (const auto &participant : result) {
    participant_dialog_ids.push_back(participant.dialog_id_);
  }
  td_->story_manager_->on_view_dialog_active_stories(std::move(participant_dialog_ids));

  promise.set_value(DialogParticipants{total_count, std::move(result)});
}

void DialogParticipantManager::search_dialog_participants(DialogId dialog_id, const string &query, int32 limit,
                                                          DialogParticipantFilter filter,
                                                          Promise<DialogParticipants> &&promise) {
  LOG(INFO) << "Receive searchChatMembers request to search for \"" << query << "\" in " << dialog_id << " with filter "
            << filter;
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "search_dialog_participants")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (limit < 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be non-negative"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_value(search_private_chat_participants(dialog_id.get_user_id(), query, limit, filter));
    case DialogType::Chat:
      return search_chat_participants(dialog_id.get_chat_id(), query, limit, filter, std::move(promise));
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      if (filter.has_query()) {
        return get_channel_participants(channel_id, filter.get_supergroup_members_filter_object(query), string(), 0,
                                        limit, 0, std::move(promise));
      } else {
        return get_channel_participants(channel_id, filter.get_supergroup_members_filter_object(string()), query, 0,
                                        100, limit, std::move(promise));
      }
    }
    case DialogType::SecretChat: {
      auto peer_user_id = td_->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
      return promise.set_value(search_private_chat_participants(peer_user_id, query, limit, filter));
    }
    case DialogType::None:
    default:
      UNREACHABLE();
      promise.set_error(Status::Error(500, "Wrong chat type"));
  }
}

void DialogParticipantManager::add_dialog_participant(
    DialogId dialog_id, UserId user_id, int32 forward_limit,
    Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "add_dialog_participant")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't add members to a private chat"));
    case DialogType::Chat:
      return add_chat_participant(dialog_id.get_chat_id(), user_id, forward_limit, std::move(promise));
    case DialogType::Channel:
      return add_channel_participant(dialog_id.get_channel_id(), user_id, DialogParticipantStatus::Left(),
                                     std::move(promise));
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't add members to a secret chat"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogParticipantManager::add_dialog_participants(
    DialogId dialog_id, const vector<UserId> &user_ids,
    Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "add_dialog_participants")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't add members to a private chat"));
    case DialogType::Chat:
      if (user_ids.size() == 1) {
        return add_chat_participant(dialog_id.get_chat_id(), user_ids[0], 0, std::move(promise));
      }
      return promise.set_error(Status::Error(400, "Can't add many members at once to a basic group chat"));
    case DialogType::Channel:
      return add_channel_participants(dialog_id.get_channel_id(), user_ids, std::move(promise));
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't add members to a secret chat"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogParticipantManager::set_dialog_participant_status(
    DialogId dialog_id, DialogId participant_dialog_id,
    td_api::object_ptr<td_api::ChatMemberStatus> &&chat_member_status, Promise<Unit> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "set_dialog_participant_status")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Chat member status can't be changed in private chats"));
    case DialogType::Chat: {
      auto status = get_dialog_participant_status(chat_member_status, ChannelType::Unknown);
      if (participant_dialog_id.get_type() != DialogType::User) {
        if (status == DialogParticipantStatus::Left()) {
          return promise.set_value(Unit());
        } else {
          return promise.set_error(Status::Error(400, "Chats can't be members of basic groups"));
        }
      }
      return set_chat_participant_status(dialog_id.get_chat_id(), participant_dialog_id.get_user_id(), status, false,
                                         std::move(promise));
    }
    case DialogType::Channel:
      return set_channel_participant_status(dialog_id.get_channel_id(), participant_dialog_id,
                                            std::move(chat_member_status), std::move(promise));
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Chat member status can't be changed in secret chats"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogParticipantManager::ban_dialog_participant(DialogId dialog_id, DialogId participant_dialog_id,
                                                      int32 banned_until_date, bool revoke_messages,
                                                      Promise<Unit> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "ban_dialog_participant")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't ban members in private chats"));
    case DialogType::Chat:
      if (participant_dialog_id.get_type() != DialogType::User) {
        return promise.set_error(Status::Error(400, "Can't ban chats in basic groups"));
      }
      return delete_chat_participant(dialog_id.get_chat_id(), participant_dialog_id.get_user_id(), revoke_messages,
                                     std::move(promise));
    case DialogType::Channel:
      // must use td_api::chatMemberStatusBanned to properly fix banned_until_date
      return set_channel_participant_status(dialog_id.get_channel_id(), participant_dialog_id,
                                            td_api::make_object<td_api::chatMemberStatusBanned>(banned_until_date),
                                            std::move(promise));
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't ban members in secret chats"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogParticipantManager::leave_dialog(DialogId dialog_id, Promise<Unit> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "leave_dialog")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't leave private chats"));
    case DialogType::Chat:
      return delete_chat_participant(dialog_id.get_chat_id(), td_->user_manager_->get_my_id(), false,
                                     std::move(promise));
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      auto old_status = td_->chat_manager_->get_channel_status(channel_id);
      auto new_status = old_status;
      new_status.set_is_member(false);
      return restrict_channel_participant(channel_id, td_->dialog_manager_->get_my_dialog_id(), std::move(new_status),
                                          std::move(old_status), std::move(promise));
    }
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't leave secret chats"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

Promise<td_api::object_ptr<td_api::failedToAddMembers>> DialogParticipantManager::wrap_failed_to_add_members_promise(
    Promise<Unit> &&promise) {
  return PromiseCreator::lambda(
      [promise = std::move(promise)](Result<td_api::object_ptr<td_api::failedToAddMembers>> &&result) mutable {
        if (result.is_ok()) {
          if (result.ok()->failed_to_add_members_.empty()) {
            promise.set_value(Unit());
          } else {
            promise.set_error(Status::Error(403, "USER_PRIVACY_RESTRICTED"));
          }
        } else {
          promise.set_error(result.move_as_error());
        }
      });
}

void DialogParticipantManager::add_chat_participant(ChatId chat_id, UserId user_id, int32 forward_limit,
                                                    Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise) {
  if (!td_->chat_manager_->get_chat_is_active(chat_id)) {
    if (!td_->chat_manager_->have_chat(chat_id)) {
      return promise.set_error(Status::Error(400, "Chat info not found"));
    }
    return promise.set_error(Status::Error(400, "Chat is deactivated"));
  }
  if (forward_limit < 0) {
    return promise.set_error(Status::Error(400, "Can't forward negative number of messages"));
  }
  auto permissions = td_->chat_manager_->get_chat_permissions(chat_id);
  if (user_id != td_->user_manager_->get_my_id()) {
    if (!permissions.can_invite_users()) {
      return promise.set_error(Status::Error(400, "Not enough rights to invite members to the group chat"));
    }
  } else if (permissions.is_banned()) {
    return promise.set_error(Status::Error(400, "User was kicked from the chat"));
  }
  // TODO upper bound on forward_limit

  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  // TODO invoke after
  td_->create_handler<AddChatUserQuery>(std::move(promise))
      ->send(chat_id, user_id, std::move(input_user), forward_limit);
}

void DialogParticipantManager::set_chat_participant_status(ChatId chat_id, UserId user_id,
                                                           DialogParticipantStatus status, bool is_recursive,
                                                           Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  if (!status.is_member()) {
    return delete_chat_participant(chat_id, user_id, false, std::move(promise));
  }
  if (status.is_creator()) {
    return promise.set_error(Status::Error(400, "Can't change owner in basic group chats"));
  }
  if (status.is_restricted()) {
    return promise.set_error(Status::Error(400, "Can't restrict users in basic group chats"));
  }

  if (!td_->chat_manager_->get_chat_is_active(chat_id)) {
    if (!td_->chat_manager_->have_chat(chat_id)) {
      return promise.set_error(Status::Error(400, "Chat info not found"));
    }
    return promise.set_error(Status::Error(400, "Chat is deactivated"));
  }

  if (!is_recursive) {
    auto load_chat_full_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), chat_id, user_id, status = std::move(status),
                                promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &DialogParticipantManager::set_chat_participant_status, chat_id, user_id, status,
                         true, std::move(promise));
          }
        });
    return td_->chat_manager_->load_chat_full(chat_id, false, std::move(load_chat_full_promise),
                                              "set_chat_participant_status");
  }

  auto participant = td_->chat_manager_->get_chat_participant(chat_id, user_id);
  if (participant == nullptr && !status.is_administrator()) {
    // the user isn't a member, but needs to be added
    return add_chat_participant(chat_id, user_id, 0, wrap_failed_to_add_members_promise(std::move(promise)));
  }

  auto permissions = td_->chat_manager_->get_chat_permissions(chat_id);
  if (!permissions.can_promote_members()) {
    return promise.set_error(Status::Error(400, "Need owner rights in the group chat"));
  }

  if (user_id == td_->user_manager_->get_my_id()) {
    return promise.set_error(Status::Error(400, "Can't promote or demote self"));
  }

  if (participant == nullptr) {
    // the user must be added first
    CHECK(status.is_administrator());
    auto add_chat_participant_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), chat_id, user_id, promise = std::move(promise)](
                                   Result<td_api::object_ptr<td_api::failedToAddMembers>> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else if (!result.ok()->failed_to_add_members_.empty()) {
            promise.set_error(Status::Error(403, "USER_PRIVACY_RESTRICTED"));
          } else {
            send_closure(actor_id, &DialogParticipantManager::send_edit_chat_admin_query, chat_id, user_id, true,
                         std::move(promise));
          }
        });

    return add_chat_participant(chat_id, user_id, 0, std::move(add_chat_participant_promise));
  }

  send_edit_chat_admin_query(chat_id, user_id, status.is_administrator(), std::move(promise));
}

void DialogParticipantManager::send_edit_chat_admin_query(ChatId chat_id, UserId user_id, bool is_administrator,
                                                          Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  td_->create_handler<EditChatAdminQuery>(std::move(promise))
      ->send(chat_id, user_id, std::move(input_user), is_administrator);
}

void DialogParticipantManager::delete_chat_participant(ChatId chat_id, UserId user_id, bool revoke_messages,
                                                       Promise<Unit> &&promise) {
  if (!td_->chat_manager_->get_chat_is_active(chat_id)) {
    if (!td_->chat_manager_->have_chat(chat_id)) {
      return promise.set_error(Status::Error(400, "Chat info not found"));
    }
    return promise.set_error(Status::Error(400, "Chat is deactivated"));
  }

  auto my_id = td_->user_manager_->get_my_id();
  auto permissions = td_->chat_manager_->get_chat_permissions(chat_id);
  if (permissions.is_left()) {
    if (user_id == my_id) {
      if (revoke_messages) {
        return td_->messages_manager_->delete_dialog_history(DialogId(chat_id), true, false, std::move(promise));
      }
      return promise.set_value(Unit());
    } else {
      return promise.set_error(Status::Error(400, "Not in the chat"));
    }
  }
  /* TODO
  if (user_id != my_id) {
    if (!permissions.is_creator()) {  // creator can delete anyone
      auto participant = get_chat_participant(chat_id, user_id);
      if (participant != nullptr) {  // if have no information about participant, just send request to the server
        if (c->everyone_is_administrator) {
          // if all are administrators, only invited by me participants can be deleted
          if (participant->inviter_user_id_ != my_id) {
            return promise.set_error(Status::Error(400, "Need to be inviter of a user to kick it from a basic group"));
          }
        } else {
          // otherwise, only creator can kick administrators
          if (participant->status_.is_administrator()) {
            return promise.set_error(
                Status::Error(400, "Only the creator of a basic group can kick group administrators"));
          }
          // regular users can be kicked by administrators and their inviters
          if (!permissions.is_administrator() && participant->inviter_user_id_ != my_id) {
            return promise.set_error(Status::Error(400, "Need to be inviter of a user to kick it from a basic group"));
          }
        }
      }
    }
  }
  */
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  // TODO invoke after
  td_->create_handler<DeleteChatUserQuery>(std::move(promise))->send(chat_id, std::move(input_user), revoke_messages);
}

void DialogParticipantManager::add_channel_participant(
    ChannelId channel_id, UserId user_id, const DialogParticipantStatus &old_status,
    Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  if (td_->auth_manager_->is_bot()) {
    return promise.set_error(Status::Error(400, "Bots can't add new chat members"));
  }

  if (!td_->chat_manager_->have_channel(channel_id)) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  if (user_id == td_->user_manager_->get_my_id()) {
    // join the channel
    auto my_status = td_->chat_manager_->get_channel_status(channel_id);
    if (my_status.is_banned()) {
      return promise.set_error(Status::Error(400, "Can't return to kicked from chat"));
    }
    if (my_status.is_member()) {
      return promise.set_value(MissingInvitees().get_failed_to_add_members_object(td_->user_manager_.get()));
    }

    auto &queries = join_channel_queries_[channel_id];
    queries.push_back(std::move(promise));
    if (queries.size() == 1u) {
      auto new_status = my_status;
      bool was_speculatively_updated = false;
      if (!td_->chat_manager_->get_channel_join_request(channel_id)) {
        new_status.set_is_member(true);
        was_speculatively_updated = true;
        speculative_add_channel_user(channel_id, user_id, new_status, my_status);
      }
      auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), channel_id, was_speculatively_updated,
                                                   old_status = std::move(my_status),
                                                   new_status = std::move(new_status)](Result<Unit> result) mutable {
        send_closure(actor_id, &DialogParticipantManager::on_join_channel, channel_id, was_speculatively_updated,
                     std::move(old_status), std::move(new_status), std::move(result));
      });
      td_->create_handler<JoinChannelQuery>(std::move(query_promise))->send(channel_id);
    }
    return;
  }

  if (!td_->chat_manager_->get_channel_permissions(channel_id).can_invite_users()) {
    return promise.set_error(Status::Error(400, "Not enough rights to invite members to the supergroup chat"));
  }

  speculative_add_channel_user(channel_id, user_id, DialogParticipantStatus::Member(0), old_status);
  vector<tl_object_ptr<telegram_api::InputUser>> input_users;
  input_users.push_back(std::move(input_user));
  td_->create_handler<InviteToChannelQuery>(std::move(promise))->send(channel_id, {user_id}, std::move(input_users));
}

void DialogParticipantManager::on_join_channel(ChannelId channel_id, bool was_speculatively_updated,
                                               DialogParticipantStatus &&old_status,
                                               DialogParticipantStatus &&new_status, Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);

  auto it = join_channel_queries_.find(channel_id);
  CHECK(it != join_channel_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  join_channel_queries_.erase(it);

  if (result.is_ok()) {
    for (auto &promise : promises) {
      promise.set_value(MissingInvitees().get_failed_to_add_members_object(td_->user_manager_.get()));
    }
  } else {
    if (was_speculatively_updated) {
      speculative_add_channel_user(channel_id, td_->user_manager_->get_my_id(), old_status, new_status);
    }
    fail_promises(promises, result.move_as_error());
  }
}

void DialogParticipantManager::add_channel_participants(
    ChannelId channel_id, const vector<UserId> &user_ids,
    Promise<td_api::object_ptr<td_api::failedToAddMembers>> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    return promise.set_error(Status::Error(400, "Bots can't add new chat members"));
  }

  if (!td_->chat_manager_->have_channel(channel_id)) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }

  if (!td_->chat_manager_->get_channel_permissions(channel_id).can_invite_users()) {
    return promise.set_error(Status::Error(400, "Not enough rights to invite members to the supergroup chat"));
  }

  vector<tl_object_ptr<telegram_api::InputUser>> input_users;
  for (auto user_id : user_ids) {
    TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

    if (user_id == td_->user_manager_->get_my_id()) {
      // can't invite self
      continue;
    }
    input_users.push_back(std::move(input_user));

    speculative_add_channel_user(channel_id, user_id, DialogParticipantStatus::Member(0),
                                 DialogParticipantStatus::Left());
  }

  if (input_users.empty()) {
    return promise.set_value(MissingInvitees().get_failed_to_add_members_object(td_->user_manager_.get()));
  }

  td_->create_handler<InviteToChannelQuery>(std::move(promise))->send(channel_id, user_ids, std::move(input_users));
}

void DialogParticipantManager::set_channel_participant_status(
    ChannelId channel_id, DialogId participant_dialog_id,
    td_api::object_ptr<td_api::ChatMemberStatus> &&chat_member_status, Promise<Unit> &&promise) {
  if (!td_->chat_manager_->have_channel(channel_id)) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  auto new_status = get_dialog_participant_status(chat_member_status, td_->chat_manager_->get_channel_type(channel_id));

  if (participant_dialog_id == td_->dialog_manager_->get_my_dialog_id()) {
    // fast path is needed, because get_channel_status may return Creator, while GetChannelParticipantQuery returning Left
    return set_channel_participant_status_impl(channel_id, participant_dialog_id, std::move(new_status),
                                               td_->chat_manager_->get_channel_status(channel_id), std::move(promise));
  }
  if (participant_dialog_id.get_type() != DialogType::User) {
    if (new_status.is_administrator() || new_status.is_member() || new_status.is_restricted()) {
      return promise.set_error(Status::Error(400, "Other chats can be only banned or unbanned"));
    }
    // always pretend that old_status is different
    return restrict_channel_participant(
        channel_id, participant_dialog_id, std::move(new_status),
        new_status.is_banned() ? DialogParticipantStatus::Left() : DialogParticipantStatus::Banned(0),
        std::move(promise));
  }

  auto on_result_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), channel_id, participant_dialog_id, new_status,
                              promise = std::move(promise)](Result<DialogParticipant> r_dialog_participant) mutable {
        if (r_dialog_participant.is_error()) {
          return promise.set_error(r_dialog_participant.move_as_error());
        }

        send_closure(actor_id, &DialogParticipantManager::set_channel_participant_status_impl, channel_id,
                     participant_dialog_id, std::move(new_status), r_dialog_participant.ok().status_,
                     std::move(promise));
      });

  get_channel_participant(channel_id, participant_dialog_id, std::move(on_result_promise));
}

void DialogParticipantManager::set_channel_participant_status_impl(ChannelId channel_id, DialogId participant_dialog_id,
                                                                   DialogParticipantStatus new_status,
                                                                   DialogParticipantStatus old_status,
                                                                   Promise<Unit> &&promise) {
  if (old_status == new_status && !old_status.is_creator()) {
    return promise.set_value(Unit());
  }
  CHECK(participant_dialog_id.get_type() == DialogType::User);

  LOG(INFO) << "Change status of " << participant_dialog_id << " in " << channel_id << " from " << old_status << " to "
            << new_status;
  bool need_add = false;
  bool need_promote = false;
  bool need_restrict = false;
  if (new_status.is_creator() || old_status.is_creator()) {
    if (!old_status.is_creator()) {
      return promise.set_error(Status::Error(400, "Can't add another owner to the chat"));
    }
    if (!new_status.is_creator()) {
      return promise.set_error(Status::Error(400, "Can't remove chat owner"));
    }
    auto user_id = td_->user_manager_->get_my_id();
    if (participant_dialog_id != DialogId(user_id)) {
      return promise.set_error(Status::Error(400, "Not enough rights to edit chat owner rights"));
    }
    if (new_status.is_member() == old_status.is_member()) {
      // change rank and is_anonymous
      auto r_input_user = td_->user_manager_->get_input_user(user_id);
      CHECK(r_input_user.is_ok());
      td_->create_handler<EditChannelAdminQuery>(std::move(promise))
          ->send(channel_id, user_id, r_input_user.move_as_ok(), new_status);
      return;
    }
    if (new_status.is_member()) {
      // creator not member -> creator member
      need_add = true;
    } else {
      // creator member -> creator not member
      need_restrict = true;
    }
  } else if (new_status.is_administrator()) {
    need_promote = true;
  } else if (!new_status.is_member() || new_status.is_restricted()) {
    if (new_status.is_member() && !old_status.is_member()) {
      // TODO there is no way in server API to invite someone and change restrictions
      // we need to first add user and change restrictions again after that
      // but if restrictions aren't changed, then adding is enough
      auto copy_old_status = old_status;
      copy_old_status.set_is_member(true);
      if (copy_old_status == new_status) {
        need_add = true;
      } else {
        need_restrict = true;
      }
    } else {
      need_restrict = true;
    }
  } else {
    // regular member
    if (old_status.is_administrator()) {
      need_promote = true;
    } else if (old_status.is_restricted() || old_status.is_banned()) {
      need_restrict = true;
    } else {
      CHECK(!old_status.is_member());
      need_add = true;
    }
  }

  if (need_promote) {
    if (participant_dialog_id.get_type() != DialogType::User) {
      return promise.set_error(Status::Error(400, "Can't promote chats to chat administrators"));
    }
    return promote_channel_participant(channel_id, participant_dialog_id.get_user_id(), new_status, old_status,
                                       std::move(promise));
  } else if (need_restrict) {
    return restrict_channel_participant(channel_id, participant_dialog_id, std::move(new_status), std::move(old_status),
                                        std::move(promise));
  } else {
    CHECK(need_add);
    if (participant_dialog_id.get_type() != DialogType::User) {
      return promise.set_error(Status::Error(400, "Can't add chats as chat members"));
    }
    return add_channel_participant(channel_id, participant_dialog_id.get_user_id(), old_status,
                                   wrap_failed_to_add_members_promise(std::move(promise)));
  }
}

void DialogParticipantManager::promote_channel_participant(ChannelId channel_id, UserId user_id,
                                                           const DialogParticipantStatus &new_status,
                                                           const DialogParticipantStatus &old_status,
                                                           Promise<Unit> &&promise) {
  LOG(INFO) << "Promote " << user_id << " in " << channel_id << " from " << old_status << " to " << new_status;
  if (user_id == td_->user_manager_->get_my_id()) {
    if (new_status.is_administrator()) {
      return promise.set_error(Status::Error(400, "Can't promote self"));
    }
    CHECK(new_status.is_member());
    // allow to demote self. TODO is it allowed server-side?
  } else {
    if (!td_->chat_manager_->get_channel_permissions(channel_id).can_promote_members()) {
      return promise.set_error(Status::Error(400, "Not enough rights"));
    }

    CHECK(!old_status.is_creator());
    CHECK(!new_status.is_creator());
  }

  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

  speculative_add_channel_user(channel_id, user_id, new_status, old_status);
  td_->create_handler<EditChannelAdminQuery>(std::move(promise))
      ->send(channel_id, user_id, std::move(input_user), new_status);
}

void DialogParticipantManager::restrict_channel_participant(ChannelId channel_id, DialogId participant_dialog_id,
                                                            DialogParticipantStatus &&new_status,
                                                            DialogParticipantStatus &&old_status,
                                                            Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  LOG(INFO) << "Restrict " << participant_dialog_id << " in " << channel_id << " from " << old_status << " to "
            << new_status;
  if (!td_->chat_manager_->have_channel(channel_id)) {
    return promise.set_error(Status::Error(400, "Chat info not found"));
  }
  auto my_status = td_->chat_manager_->get_channel_status(channel_id);
  if (!my_status.is_member() && !my_status.is_creator()) {
    if (participant_dialog_id == td_->dialog_manager_->get_my_dialog_id()) {
      if (new_status.is_member()) {
        return promise.set_error(Status::Error(400, "Can't unrestrict self"));
      }
      return promise.set_value(Unit());
    } else {
      return promise.set_error(Status::Error(400, "Not in the chat"));
    }
  }
  auto input_peer = td_->dialog_manager_->get_input_peer(participant_dialog_id, AccessRights::Know);
  if (input_peer == nullptr) {
    return promise.set_error(Status::Error(400, "Member not found"));
  }

  if (participant_dialog_id == td_->dialog_manager_->get_my_dialog_id()) {
    if (new_status.is_restricted() || new_status.is_banned()) {
      return promise.set_error(Status::Error(400, "Can't restrict self"));
    }
    if (new_status.is_member()) {
      return promise.set_error(Status::Error(400, "Can't unrestrict self"));
    }

    // leave the channel
    speculative_add_channel_user(channel_id, participant_dialog_id.get_user_id(), new_status, my_status);
    td_->create_handler<LeaveChannelQuery>(std::move(promise))->send(channel_id);
    return;
  }

  switch (participant_dialog_id.get_type()) {
    case DialogType::User:
      // ok;
      break;
    case DialogType::Channel:
      if (new_status.is_administrator() || new_status.is_member() || new_status.is_restricted()) {
        return promise.set_error(Status::Error(400, "Other chats can be only banned or unbanned"));
      }
      break;
    default:
      return promise.set_error(Status::Error(400, "Can't restrict the chat"));
  }

  CHECK(!old_status.is_creator());
  CHECK(!new_status.is_creator());

  if (!td_->chat_manager_->get_channel_permissions(channel_id).can_restrict_members()) {
    return promise.set_error(Status::Error(400, "Not enough rights to restrict/unrestrict chat member"));
  }

  if (old_status.is_member() && !new_status.is_member() && !new_status.is_banned()) {
    // we can't make participant Left without kicking it first
    auto on_result_promise = PromiseCreator::lambda([actor_id = actor_id(this), channel_id, participant_dialog_id,
                                                     new_status = std::move(new_status),
                                                     promise = std::move(promise)](Result<> result) mutable {
      if (result.is_error()) {
        return promise.set_error(result.move_as_error());
      }

      create_actor<SleepActor>(
          "RestrictChannelParticipantSleepActor", 1.0,
          PromiseCreator::lambda([actor_id, channel_id, participant_dialog_id, new_status = std::move(new_status),
                                  promise = std::move(promise)](Unit) mutable {
            send_closure(actor_id, &DialogParticipantManager::restrict_channel_participant, channel_id,
                         participant_dialog_id, std::move(new_status), DialogParticipantStatus::Banned(0),
                         std::move(promise));
          }))
          .release();
    });

    promise = std::move(on_result_promise);
    new_status = DialogParticipantStatus::Banned(G()->unix_time() + 60);
  }

  if (new_status.is_member() && !old_status.is_member()) {
    // there is no way in server API to invite someone and change restrictions
    // we need to first change restrictions and then try to add the user
    CHECK(participant_dialog_id.get_type() == DialogType::User);
    new_status.set_is_member(false);
    auto on_result_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), channel_id, participant_dialog_id, old_status = new_status,
                                promise = std::move(promise)](Result<> result) mutable {
          if (result.is_error()) {
            return promise.set_error(result.move_as_error());
          }

          create_actor<SleepActor>(
              "AddChannelParticipantSleepActor", 1.0,
              PromiseCreator::lambda([actor_id, channel_id, participant_dialog_id, old_status = std::move(old_status),
                                      promise = std::move(promise)](Unit) mutable {
                send_closure(actor_id, &DialogParticipantManager::add_channel_participant, channel_id,
                             participant_dialog_id.get_user_id(), old_status,
                             wrap_failed_to_add_members_promise(std::move(promise)));
              }))
              .release();
        });

    promise = std::move(on_result_promise);
  }

  if (participant_dialog_id.get_type() == DialogType::User) {
    speculative_add_channel_user(channel_id, participant_dialog_id.get_user_id(), new_status, old_status);
  }
  td_->create_handler<EditChannelBannedQuery>(std::move(promise))
      ->send(channel_id, participant_dialog_id, std::move(input_peer), new_status);
}

void DialogParticipantManager::on_set_channel_participant_status(ChannelId channel_id, DialogId participant_dialog_id,
                                                                 DialogParticipantStatus status) {
  if (G()->close_flag() || participant_dialog_id == td_->dialog_manager_->get_my_dialog_id()) {
    return;
  }

  status.update_restrictions();
  if (have_channel_participant_cache(channel_id)) {
    update_channel_participant_status_cache(channel_id, participant_dialog_id, std::move(status));
  }
}

void DialogParticipantManager::speculative_add_channel_user(ChannelId channel_id, UserId user_id,
                                                            const DialogParticipantStatus &new_status,
                                                            const DialogParticipantStatus &old_status) {
  speculative_update_dialog_administrators(DialogId(channel_id), user_id, new_status, old_status);

  td_->chat_manager_->speculative_add_channel_user(channel_id, user_id, new_status, old_status);
}

void DialogParticipantManager::on_channel_participant_cache_timeout_callback(void *dialog_participant_manager_ptr,
                                                                             int64 channel_id_long) {
  if (G()->close_flag()) {
    return;
  }

  auto dialog_participant_manager = static_cast<DialogParticipantManager *>(dialog_participant_manager_ptr);
  send_closure_later(dialog_participant_manager->actor_id(dialog_participant_manager),
                     &DialogParticipantManager::on_channel_participant_cache_timeout, ChannelId(channel_id_long));
}

void DialogParticipantManager::on_channel_participant_cache_timeout(ChannelId channel_id) {
  if (G()->close_flag()) {
    return;
  }

  auto channel_participants_it = channel_participants_.find(channel_id);
  if (channel_participants_it == channel_participants_.end()) {
    return;
  }

  auto &participants = channel_participants_it->second.participants_;
  auto min_access_date = G()->unix_time() - CHANNEL_PARTICIPANT_CACHE_TIME;
  table_remove_if(participants,
                  [min_access_date](const auto &it) { return it.second.last_access_date_ < min_access_date; });

  if (participants.empty()) {
    channel_participants_.erase(channel_participants_it);
  } else {
    channel_participant_cache_timeout_.set_timeout_in(channel_id.get(), CHANNEL_PARTICIPANT_CACHE_TIME);
  }
}

bool DialogParticipantManager::have_channel_participant_cache(ChannelId channel_id) const {
  if (!td_->auth_manager_->is_bot()) {
    return false;
  }
  return td_->chat_manager_->get_channel_status(channel_id).is_administrator();
}

void DialogParticipantManager::add_channel_participant_to_cache(ChannelId channel_id,
                                                                const DialogParticipant &dialog_participant,
                                                                bool allow_replace) {
  CHECK(channel_id.is_valid());
  CHECK(dialog_participant.is_valid());
  auto &participants = channel_participants_[channel_id];
  if (participants.participants_.empty()) {
    channel_participant_cache_timeout_.set_timeout_in(channel_id.get(), CHANNEL_PARTICIPANT_CACHE_TIME);
  }
  auto &participant_info = participants.participants_[dialog_participant.dialog_id_];
  if (participant_info.last_access_date_ > 0 && !allow_replace) {
    return;
  }
  participant_info.participant_ = dialog_participant;
  participant_info.last_access_date_ = G()->unix_time();
}

void DialogParticipantManager::update_channel_participant_status_cache(
    ChannelId channel_id, DialogId participant_dialog_id, DialogParticipantStatus &&dialog_participant_status) {
  CHECK(channel_id.is_valid());
  CHECK(participant_dialog_id.is_valid());
  auto channel_participants_it = channel_participants_.find(channel_id);
  if (channel_participants_it == channel_participants_.end()) {
    return;
  }
  auto &participants = channel_participants_it->second;
  auto it = participants.participants_.find(participant_dialog_id);
  if (it == participants.participants_.end()) {
    return;
  }
  auto &participant_info = it->second;
  LOG(INFO) << "Update cached status of " << participant_dialog_id << " in " << channel_id << " from "
            << participant_info.participant_.status_ << " to " << dialog_participant_status;
  participant_info.participant_.status_ = std::move(dialog_participant_status);
  participant_info.last_access_date_ = G()->unix_time();
}

void DialogParticipantManager::drop_channel_participant_cache(ChannelId channel_id) {
  channel_participants_.erase(channel_id);
}

const DialogParticipant *DialogParticipantManager::get_channel_participant_from_cache(ChannelId channel_id,
                                                                                      DialogId participant_dialog_id) {
  auto channel_participants_it = channel_participants_.find(channel_id);
  if (channel_participants_it == channel_participants_.end()) {
    return nullptr;
  }

  auto &participants = channel_participants_it->second.participants_;
  CHECK(!participants.empty());
  auto it = participants.find(participant_dialog_id);
  if (it != participants.end()) {
    it->second.participant_.status_.update_restrictions();
    it->second.last_access_date_ = G()->unix_time();
    return &it->second.participant_;
  }
  return nullptr;
}

void DialogParticipantManager::set_cached_channel_participants(ChannelId channel_id,
                                                               vector<DialogParticipant> participants) {
  cached_channel_participants_[channel_id] = std::move(participants);
}

void DialogParticipantManager::drop_cached_channel_participants(ChannelId channel_id) {
  cached_channel_participants_.erase(channel_id);
}

void DialogParticipantManager::add_cached_channel_participants(ChannelId channel_id,
                                                               const vector<UserId> &added_user_ids,
                                                               UserId inviter_user_id, int32 date) {
  auto it = cached_channel_participants_.find(channel_id);
  if (it == cached_channel_participants_.end()) {
    return;
  }
  auto &participants = it->second;
  bool is_participants_cache_changed = false;
  for (auto user_id : added_user_ids) {
    if (!user_id.is_valid()) {
      continue;
    }

    bool is_found = false;
    for (const auto &participant : participants) {
      if (participant.dialog_id_ == DialogId(user_id)) {
        is_found = true;
        break;
      }
    }
    if (!is_found) {
      is_participants_cache_changed = true;
      participants.emplace_back(DialogId(user_id), inviter_user_id, date, DialogParticipantStatus::Member(0));
    }
  }
  if (is_participants_cache_changed) {
    update_channel_online_member_count(channel_id, false);
  }
}

void DialogParticipantManager::delete_cached_channel_participant(ChannelId channel_id, UserId deleted_user_id) {
  if (!deleted_user_id.is_valid()) {
    return;
  }

  auto it = cached_channel_participants_.find(channel_id);
  if (it == cached_channel_participants_.end()) {
    return;
  }
  auto &participants = it->second;
  for (size_t i = 0; i < participants.size(); i++) {
    if (participants[i].dialog_id_ == DialogId(deleted_user_id)) {
      participants.erase(participants.begin() + i);
      update_channel_online_member_count(channel_id, false);
      break;
    }
  }
}

void DialogParticipantManager::update_cached_channel_participant_status(ChannelId channel_id, UserId user_id,
                                                                        const DialogParticipantStatus &status) {
  auto it = cached_channel_participants_.find(channel_id);
  if (it == cached_channel_participants_.end()) {
    return;
  }
  auto &participants = it->second;
  bool is_found = false;
  for (size_t i = 0; i < participants.size(); i++) {
    if (participants[i].dialog_id_ == DialogId(user_id)) {
      if (!status.is_member()) {
        participants.erase(participants.begin() + i);
        update_channel_online_member_count(channel_id, false);
      } else {
        participants[i].status_ = status;
      }
      is_found = true;
      break;
    }
  }
  if (!is_found && status.is_member()) {
    participants.emplace_back(DialogId(user_id), td_->user_manager_->get_my_id(), G()->unix_time(), status);
    update_channel_online_member_count(channel_id, false);
  }
}

void DialogParticipantManager::can_transfer_ownership(Promise<CanTransferOwnershipResult> &&promise) {
  auto request_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<Unit> r_result) mutable {
    CHECK(r_result.is_error());

    auto error = r_result.move_as_error();
    CanTransferOwnershipResult result;
    if (error.message() == "PASSWORD_HASH_INVALID") {
      return promise.set_value(std::move(result));
    }
    if (error.message() == "PASSWORD_MISSING") {
      result.type = CanTransferOwnershipResult::Type::PasswordNeeded;
      return promise.set_value(std::move(result));
    }
    if (begins_with(error.message(), "PASSWORD_TOO_FRESH_")) {
      result.type = CanTransferOwnershipResult::Type::PasswordTooFresh;
      result.retry_after = to_integer<int32>(error.message().substr(Slice("PASSWORD_TOO_FRESH_").size()));
      if (result.retry_after < 0) {
        result.retry_after = 0;
      }
      return promise.set_value(std::move(result));
    }
    if (begins_with(error.message(), "SESSION_TOO_FRESH_")) {
      result.type = CanTransferOwnershipResult::Type::SessionTooFresh;
      result.retry_after = to_integer<int32>(error.message().substr(Slice("SESSION_TOO_FRESH_").size()));
      if (result.retry_after < 0) {
        result.retry_after = 0;
      }
      return promise.set_value(std::move(result));
    }
    promise.set_error(std::move(error));
  });

  td_->create_handler<CanEditChannelCreatorQuery>(std::move(request_promise))->send();
}

td_api::object_ptr<td_api::CanTransferOwnershipResult>
DialogParticipantManager::get_can_transfer_ownership_result_object(CanTransferOwnershipResult result) {
  switch (result.type) {
    case CanTransferOwnershipResult::Type::Ok:
      return td_api::make_object<td_api::canTransferOwnershipResultOk>();
    case CanTransferOwnershipResult::Type::PasswordNeeded:
      return td_api::make_object<td_api::canTransferOwnershipResultPasswordNeeded>();
    case CanTransferOwnershipResult::Type::PasswordTooFresh:
      return td_api::make_object<td_api::canTransferOwnershipResultPasswordTooFresh>(result.retry_after);
    case CanTransferOwnershipResult::Type::SessionTooFresh:
      return td_api::make_object<td_api::canTransferOwnershipResultSessionTooFresh>(result.retry_after);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void DialogParticipantManager::transfer_dialog_ownership(DialogId dialog_id, UserId user_id, const string &password,
                                                         Promise<Unit> &&promise) {
  if (!td_->dialog_manager_->have_dialog_force(dialog_id, "transfer_dialog_ownership")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (!td_->user_manager_->have_user_force(user_id, "transfer_dialog_ownership")) {
    return promise.set_error(Status::Error(400, "User not found"));
  }
  if (td_->user_manager_->is_user_bot(user_id)) {
    return promise.set_error(Status::Error(400, "User is a bot"));
  }
  if (td_->user_manager_->is_user_deleted(user_id)) {
    return promise.set_error(Status::Error(400, "User is deleted"));
  }
  if (password.empty()) {
    return promise.set_error(Status::Error(400, "PASSWORD_HASH_INVALID"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't transfer chat ownership"));
    case DialogType::Channel:
      send_closure(
          td_->password_manager_, &PasswordManager::get_input_check_password_srp, password,
          PromiseCreator::lambda([actor_id = actor_id(this), channel_id = dialog_id.get_channel_id(), user_id,
                                  promise = std::move(promise)](
                                     Result<tl_object_ptr<telegram_api::InputCheckPasswordSRP>> result) mutable {
            if (result.is_error()) {
              return promise.set_error(result.move_as_error());
            }
            send_closure(actor_id, &DialogParticipantManager::transfer_channel_ownership, channel_id, user_id,
                         result.move_as_ok(), std::move(promise));
          }));
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogParticipantManager::transfer_channel_ownership(
    ChannelId channel_id, UserId user_id,
    telegram_api::object_ptr<telegram_api::InputCheckPasswordSRP> input_check_password, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  td_->create_handler<EditChannelCreatorQuery>(std::move(promise))
      ->send(channel_id, user_id, std::move(input_check_password));
}

void DialogParticipantManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  for (const auto &it : dialog_online_member_counts_) {
    auto dialog_id = it.first;
    if (it.second.is_update_sent && td_->messages_manager_->is_dialog_opened(dialog_id)) {
      updates.push_back(td_api::make_object<td_api::updateChatOnlineMemberCount>(
          td_->dialog_manager_->get_chat_id_object(dialog_id, "updateChatOnlineMemberCount"),
          it.second.online_member_count));
    }
  }
}

}  // namespace td
