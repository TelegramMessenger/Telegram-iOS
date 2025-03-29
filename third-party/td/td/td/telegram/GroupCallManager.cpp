//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/GroupCallManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/CallId.h"
#include "td/telegram/CallManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogAction.h"
#include "td/telegram/DialogActionManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipantFilter.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"

#include <map>
#include <utility>

namespace td {

class GetGroupCallStreamChannelsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::groupCallStreams>> promise_;

 public:
  explicit GetGroupCallStreamChannelsQuery(Promise<td_api::object_ptr<td_api::groupCallStreams>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, DcId stream_dc_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_getGroupCallStreamChannels(input_group_call_id.get_input_group_call()), {}, stream_dc_id,
        NetQuery::Type::DownloadSmall));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_getGroupCallStreamChannels>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    auto streams = transform(ptr->channels_, [](const tl_object_ptr<telegram_api::groupCallStreamChannel> &channel) {
      return td_api::make_object<td_api::groupCallStream>(channel->channel_, channel->scale_,
                                                          channel->last_timestamp_ms_);
    });
    promise_.set_value(td_api::make_object<td_api::groupCallStreams>(std::move(streams)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetGroupCallStreamQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit GetGroupCallStreamQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, DcId stream_dc_id, int64 time_offset, int32 scale, int32 channel_id,
            int32 video_quality) {
    int32 stream_flags = 0;
    if (channel_id != 0) {
      stream_flags |= telegram_api::inputGroupCallStream::VIDEO_CHANNEL_MASK;
    }
    auto input_stream = make_tl_object<telegram_api::inputGroupCallStream>(
        stream_flags, input_group_call_id.get_input_group_call(), time_offset, scale, channel_id, video_quality);
    int32 flags = 0;
    auto query = G()->net_query_creator().create(
        telegram_api::upload_getFile(flags, false /*ignored*/, false /*ignored*/, std::move(input_stream), 0, 1 << 20),
        {}, stream_dc_id, NetQuery::Type::DownloadSmall);
    query->total_timeout_limit_ = 0;
    send_query(std::move(query));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::upload_getFile>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    if (ptr->get_id() != telegram_api::upload_file::ID) {
      return on_error(Status::Error(500, "Receive unexpected server response"));
    }

    auto file = move_tl_object_as<telegram_api::upload_file>(ptr);
    promise_.set_value(file->bytes_.as_slice().str());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetGroupCallJoinAsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::messageSenders>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetGroupCallJoinAsQuery(Promise<td_api::object_ptr<td_api::messageSenders>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(telegram_api::phone_getGroupCallJoinAs(std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_getGroupCallJoinAs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetGroupCallJoinAsQuery: " << to_string(ptr);

    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetGroupCallJoinAsQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetGroupCallJoinAsQuery");

    promise_.set_value(convert_message_senders_object(td_, ptr->peers_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetGroupCallJoinAsQuery");
    promise_.set_error(std::move(status));
  }
};

class SaveDefaultGroupCallJoinAsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SaveDefaultGroupCallJoinAsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, DialogId as_dialog_id) {
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    auto as_input_peer = td_->dialog_manager_->get_input_peer(as_dialog_id, AccessRights::Read);
    CHECK(as_input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::phone_saveDefaultGroupCallJoinAs(std::move(input_peer), std::move(as_input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_saveDefaultGroupCallJoinAs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto success = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SaveDefaultGroupCallJoinAsQuery: " << success;

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    // td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetGroupCallJoinAsQuery");
    promise_.set_error(std::move(status));
  }
};

class CreateGroupCallQuery final : public Td::ResultHandler {
  Promise<InputGroupCallId> promise_;
  DialogId dialog_id_;

 public:
  explicit CreateGroupCallQuery(Promise<InputGroupCallId> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &title, int32 start_date, bool is_rtmp_stream) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    int32 flags = 0;
    if (!title.empty()) {
      flags |= telegram_api::phone_createGroupCall::TITLE_MASK;
    }
    if (start_date > 0) {
      flags |= telegram_api::phone_createGroupCall::SCHEDULE_DATE_MASK;
    }
    if (is_rtmp_stream) {
      flags |= telegram_api::phone_createGroupCall::RTMP_STREAM_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::phone_createGroupCall(
        flags, false, std::move(input_peer), Random::secure_int32(), title, start_date)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_createGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CreateGroupCallQuery: " << to_string(ptr);

    auto group_call_ids = td_->updates_manager_->get_update_new_group_call_ids(ptr.get());
    if (group_call_ids.empty()) {
      LOG(ERROR) << "Receive wrong CreateGroupCallQuery response " << to_string(ptr);
      return on_error(Status::Error(500, "Receive wrong response"));
    }
    auto group_call_id = group_call_ids[0];
    for (const auto &other_group_call_id : group_call_ids) {
      if (group_call_id != other_group_call_id) {
        LOG(ERROR) << "Receive wrong CreateGroupCallQuery response " << to_string(ptr);
        return on_error(Status::Error(500, "Receive wrong response"));
      }
    }

    td_->updates_manager_->on_get_updates(
        std::move(ptr), PromiseCreator::lambda([promise = std::move(promise_), group_call_id](Unit) mutable {
          promise.set_value(std::move(group_call_id));
        }));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "CreateGroupCallQuery");
    promise_.set_error(std::move(status));
  }
};

class GetGroupCallRtmpStreamUrlGroupCallQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::rtmpUrl>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetGroupCallRtmpStreamUrlGroupCallQuery(Promise<td_api::object_ptr<td_api::rtmpUrl>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool revoke) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(
        G()->net_query_creator().create(telegram_api::phone_getGroupCallStreamRtmpUrl(std::move(input_peer), revoke)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_getGroupCallStreamRtmpUrl>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    promise_.set_value(td_api::make_object<td_api::rtmpUrl>(ptr->url_, ptr->key_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetGroupCallRtmpStreamUrlGroupCallQuery");
    promise_.set_error(std::move(status));
  }
};

class GetGroupCallQuery final : public Td::ResultHandler {
  Promise<tl_object_ptr<telegram_api::phone_groupCall>> promise_;

 public:
  explicit GetGroupCallQuery(Promise<tl_object_ptr<telegram_api::phone_groupCall>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, int32 limit) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_getGroupCall(input_group_call_id.get_input_group_call(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_getGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetGroupCallQuery: " << to_string(ptr);

    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetGroupCallParticipantQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  InputGroupCallId input_group_call_id_;

 public:
  explicit GetGroupCallParticipantQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, vector<tl_object_ptr<telegram_api::InputPeer>> &&input_peers,
            vector<int32> &&source_ids) {
    input_group_call_id_ = input_group_call_id;
    auto limit = narrow_cast<int32>(max(input_peers.size(), source_ids.size()));
    send_query(G()->net_query_creator().create(telegram_api::phone_getGroupParticipants(
        input_group_call_id.get_input_group_call(), std::move(input_peers), std::move(source_ids), string(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_getGroupParticipants>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->group_call_manager_->on_get_group_call_participants(input_group_call_id_, result_ptr.move_as_ok(), false,
                                                             string());

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetGroupCallParticipantsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  InputGroupCallId input_group_call_id_;
  string offset_;

 public:
  explicit GetGroupCallParticipantsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, string offset, int32 limit) {
    input_group_call_id_ = input_group_call_id;
    offset_ = std::move(offset);
    send_query(G()->net_query_creator().create(telegram_api::phone_getGroupParticipants(
        input_group_call_id.get_input_group_call(), vector<tl_object_ptr<telegram_api::InputPeer>>(), vector<int32>(),
        offset_, limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_getGroupParticipants>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->group_call_manager_->on_get_group_call_participants(input_group_call_id_, result_ptr.move_as_ok(), true,
                                                             offset_);

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class StartScheduledGroupCallQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit StartScheduledGroupCallQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_startScheduledGroupCall(input_group_call_id.get_input_group_call())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_startScheduledGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for StartScheduledGroupCallQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "GROUPCALL_NOT_MODIFIED") {
      promise_.set_value(Unit());
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class JoinGroupCallQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  InputGroupCallId input_group_call_id_;
  DialogId as_dialog_id_;
  uint64 generation_ = 0;

 public:
  explicit JoinGroupCallQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  NetQueryRef send(InputGroupCallId input_group_call_id, DialogId as_dialog_id, const string &payload, bool is_muted,
                   bool is_video_stopped, const string &invite_hash, int64 key_fingerprint, uint64 generation) {
    input_group_call_id_ = input_group_call_id;
    as_dialog_id_ = as_dialog_id;
    generation_ = generation;

    tl_object_ptr<telegram_api::InputPeer> join_as_input_peer;
    if (as_dialog_id.is_valid()) {
      join_as_input_peer = td_->dialog_manager_->get_input_peer(as_dialog_id, AccessRights::Read);
    } else {
      join_as_input_peer = make_tl_object<telegram_api::inputPeerSelf>();
    }
    CHECK(join_as_input_peer != nullptr);

    int32 flags = 0;
    if (is_muted) {
      flags |= telegram_api::phone_joinGroupCall::MUTED_MASK;
    }
    if (!invite_hash.empty()) {
      flags |= telegram_api::phone_joinGroupCall::INVITE_HASH_MASK;
    }
    if (is_video_stopped) {
      flags |= telegram_api::phone_joinGroupCall::VIDEO_STOPPED_MASK;
    }
    if (key_fingerprint != 0) {
      flags |= telegram_api::phone_joinGroupCall::KEY_FINGERPRINT_MASK;
    }
    auto query = G()->net_query_creator().create(telegram_api::phone_joinGroupCall(
        flags, false /*ignored*/, false /*ignored*/, input_group_call_id.get_input_group_call(),
        std::move(join_as_input_peer), invite_hash, key_fingerprint,
        telegram_api::make_object<telegram_api::dataJSON>(payload)));
    auto join_query_ref = query.get_weak();
    send_query(std::move(query));
    return join_query_ref;
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_joinGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for JoinGroupCallQuery with generation " << generation_ << ": " << to_string(ptr);
    td_->group_call_manager_->process_join_group_call_response(input_group_call_id_, generation_, std::move(ptr),
                                                               std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class JoinGroupCallPresentationQuery final : public Td::ResultHandler {
  InputGroupCallId input_group_call_id_;
  uint64 generation_ = 0;

 public:
  NetQueryRef send(InputGroupCallId input_group_call_id, const string &payload, uint64 generation) {
    input_group_call_id_ = input_group_call_id;
    generation_ = generation;

    auto query = G()->net_query_creator().create(telegram_api::phone_joinGroupCallPresentation(
        input_group_call_id.get_input_group_call(), make_tl_object<telegram_api::dataJSON>(payload)));
    auto join_query_ref = query.get_weak();
    send_query(std::move(query));
    return join_query_ref;
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_joinGroupCallPresentation>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for JoinGroupCallPresentationQuery with generation " << generation_ << ": "
              << to_string(ptr);
    td_->group_call_manager_->process_join_group_call_presentation_response(input_group_call_id_, generation_,
                                                                            std::move(ptr), Status::OK());
  }

  void on_error(Status status) final {
    td_->group_call_manager_->process_join_group_call_presentation_response(input_group_call_id_, generation_, nullptr,
                                                                            std::move(status));
  }
};

class LeaveGroupCallPresentationQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit LeaveGroupCallPresentationQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_leaveGroupCallPresentation(input_group_call_id.get_input_group_call())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_editGroupCallTitle>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for LeaveGroupCallPresentationQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "PARTICIPANT_PRESENTATION_MISSING") {
      promise_.set_value(Unit());
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class EditGroupCallTitleQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit EditGroupCallTitleQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, const string &title) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_editGroupCallTitle(input_group_call_id.get_input_group_call(), title)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_editGroupCallTitle>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditGroupCallTitleQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "GROUPCALL_NOT_MODIFIED") {
      promise_.set_value(Unit());
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleGroupCallStartSubscriptionQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleGroupCallStartSubscriptionQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, bool start_subscribed) {
    send_query(G()->net_query_creator().create(telegram_api::phone_toggleGroupCallStartSubscription(
        input_group_call_id.get_input_group_call(), start_subscribed)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_toggleGroupCallStartSubscription>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleGroupCallStartSubscriptionQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "GROUPCALL_NOT_MODIFIED") {
      promise_.set_value(Unit());
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleGroupCallSettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleGroupCallSettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int32 flags, InputGroupCallId input_group_call_id, bool join_muted) {
    send_query(G()->net_query_creator().create(telegram_api::phone_toggleGroupCallSettings(
        flags, false /*ignored*/, input_group_call_id.get_input_group_call(), join_muted)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_toggleGroupCallSettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleGroupCallSettingsQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "GROUPCALL_NOT_MODIFIED") {
      promise_.set_value(Unit());
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class InviteToGroupCallQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit InviteToGroupCallQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, vector<tl_object_ptr<telegram_api::InputUser>> input_users) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_inviteToGroupCall(input_group_call_id.get_input_group_call(), std::move(input_users))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_inviteToGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for InviteToGroupCallQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ExportGroupCallInviteQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit ExportGroupCallInviteQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, bool can_self_unmute) {
    int32 flags = 0;
    if (can_self_unmute) {
      flags |= telegram_api::phone_exportGroupCallInvite::CAN_SELF_UNMUTE_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::phone_exportGroupCallInvite(
        flags, false /*ignored*/, input_group_call_id.get_input_group_call())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_exportGroupCallInvite>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    promise_.set_value(std::move(ptr->link_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleGroupCallRecordQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleGroupCallRecordQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, bool is_enabled, const string &title, bool record_video,
            bool use_portrait_orientation) {
    int32 flags = 0;
    if (is_enabled) {
      flags |= telegram_api::phone_toggleGroupCallRecord::START_MASK;
    }
    if (!title.empty()) {
      flags |= telegram_api::phone_toggleGroupCallRecord::TITLE_MASK;
    }
    if (record_video) {
      flags |= telegram_api::phone_toggleGroupCallRecord::VIDEO_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::phone_toggleGroupCallRecord(
        flags, false /*ignored*/, false /*ignored*/, input_group_call_id.get_input_group_call(), title,
        use_portrait_orientation)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_toggleGroupCallRecord>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleGroupCallRecordQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "GROUPCALL_NOT_MODIFIED") {
      promise_.set_value(Unit());
      return;
    }
    promise_.set_error(std::move(status));
  }
};

class EditGroupCallParticipantQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit EditGroupCallParticipantQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, DialogId dialog_id, bool set_is_mited, bool is_muted,
            int32 volume_level, bool set_raise_hand, bool raise_hand, bool set_video_is_stopped, bool video_is_stopped,
            bool set_video_is_paused, bool video_is_paused, bool set_presentation_is_paused,
            bool presentation_is_paused) {
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Know);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (set_raise_hand) {
      flags |= telegram_api::phone_editGroupCallParticipant::RAISE_HAND_MASK;
    } else if (volume_level) {
      flags |= telegram_api::phone_editGroupCallParticipant::VOLUME_MASK;
    } else if (set_is_mited) {
      flags |= telegram_api::phone_editGroupCallParticipant::MUTED_MASK;
    } else if (set_video_is_stopped) {
      flags |= telegram_api::phone_editGroupCallParticipant::VIDEO_STOPPED_MASK;
    } else if (set_video_is_paused) {
      flags |= telegram_api::phone_editGroupCallParticipant::VIDEO_PAUSED_MASK;
    } else if (set_presentation_is_paused) {
      flags |= telegram_api::phone_editGroupCallParticipant::PRESENTATION_PAUSED_MASK;
    }

    send_query(G()->net_query_creator().create(telegram_api::phone_editGroupCallParticipant(
        flags, input_group_call_id.get_input_group_call(), std::move(input_peer), is_muted, volume_level, raise_hand,
        video_is_stopped, video_is_paused, presentation_is_paused)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_editGroupCallParticipant>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditGroupCallParticipantQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CheckGroupCallQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit CheckGroupCallQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, vector<int32> &&audio_sources) {
    for (auto &audio_source : audio_sources) {
      CHECK(audio_source != 0);
    }
    send_query(G()->net_query_creator().create(
        telegram_api::phone_checkGroupCall(input_group_call_id.get_input_group_call(), std::move(audio_sources))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_checkGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    vector<int32> active_audio_sources = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CheckGroupCallQuery: " << active_audio_sources;

    if (!active_audio_sources.empty()) {
      promise_.set_value(Unit());
    } else {
      promise_.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
    }
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class LeaveGroupCallQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit LeaveGroupCallQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id, int32 audio_source) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_leaveGroupCall(input_group_call_id.get_input_group_call(), audio_source)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_leaveGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for LeaveGroupCallQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DiscardGroupCallQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DiscardGroupCallQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(InputGroupCallId input_group_call_id) {
    send_query(G()->net_query_creator().create(
        telegram_api::phone_discardGroupCall(input_group_call_id.get_input_group_call())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::phone_discardGroupCall>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DiscardGroupCallQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

struct GroupCallManager::GroupCall {
  GroupCallId group_call_id;
  DialogId dialog_id;
  string title;
  bool is_inited = false;
  bool is_active = false;
  bool is_rtmp_stream = false;
  bool is_joined = false;
  bool need_rejoin = false;
  bool is_being_joined = false;
  bool is_being_left = false;
  bool is_speaking = false;
  bool can_self_unmute = false;
  bool can_be_managed = false;
  bool has_hidden_listeners = false;
  bool syncing_participants = false;
  bool need_syncing_participants = false;
  bool loaded_all_participants = false;
  bool start_subscribed = false;
  bool is_my_video_paused = false;
  bool is_my_video_enabled = false;
  bool is_my_presentation_paused = false;
  bool mute_new_participants = false;
  bool allowed_toggle_mute_new_participants = false;
  bool joined_date_asc = false;
  bool is_video_recorded = false;
  int32 scheduled_start_date = 0;
  int32 participant_count = 0;
  int32 duration = 0;
  int32 audio_source = 0;
  int32 joined_date = 0;
  int32 record_start_date = 0;
  int32 unmuted_video_count = 0;
  int32 unmuted_video_limit = 0;
  DcId stream_dc_id;
  DialogId as_dialog_id;
  CallId call_id;

  int32 version = -1;
  int32 leave_version = -1;
  int32 title_version = -1;
  int32 start_subscribed_version = -1;
  int32 can_enable_video_version = -1;
  int32 mute_version = -1;
  int32 stream_dc_id_version = -1;
  int32 record_start_date_version = -1;
  int32 scheduled_start_date_version = -1;

  vector<Promise<Unit>> after_join;
  bool have_pending_start_subscribed = false;
  bool pending_start_subscribed = false;
  bool have_pending_is_my_video_paused = false;
  bool pending_is_my_video_paused = false;
  bool have_pending_is_my_video_enabled = false;
  bool pending_is_my_video_enabled = false;
  bool have_pending_is_my_presentation_paused = false;
  bool pending_is_my_presentation_paused = false;
  bool have_pending_mute_new_participants = false;
  bool pending_mute_new_participants = false;
  string pending_title;
  bool have_pending_record_start_date = false;
  int32 pending_record_start_date = 0;
  string pending_record_title;
  bool pending_record_record_video = false;
  bool pending_record_use_portrait_orientation = false;
  uint64 toggle_recording_generation = 0;
};

struct GroupCallManager::GroupCallParticipants {
  vector<GroupCallParticipant> participants;
  string next_offset;
  GroupCallParticipantOrder min_order = GroupCallParticipantOrder::max();
  bool joined_date_asc = false;
  int32 local_unmuted_video_count = 0;

  bool are_administrators_loaded = false;
  vector<DialogId> administrator_dialog_ids;

  struct PendingUpdates {
    FlatHashMap<DialogId, unique_ptr<GroupCallParticipant>, DialogIdHash> updates;
  };
  std::map<int32, PendingUpdates> pending_version_updates_;
  std::map<int32, PendingUpdates> pending_mute_updates_;
};

struct GroupCallManager::GroupCallRecentSpeakers {
  vector<std::pair<DialogId, int32>> users;  // participant + time; sorted by time
  bool is_changed = false;
  vector<std::pair<DialogId, bool>> last_sent_users;
};

struct GroupCallManager::PendingJoinRequest {
  NetQueryRef query_ref;
  uint64 generation = 0;
  int32 audio_source = 0;
  DialogId as_dialog_id;
  int64 key_fingerprint = 0;
  Promise<string> promise;
};

GroupCallManager::GroupCallManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  update_group_call_participant_order_timeout_.set_callback(on_update_group_call_participant_order_timeout_callback);
  update_group_call_participant_order_timeout_.set_callback_data(static_cast<void *>(this));

  check_group_call_is_joined_timeout_.set_callback(on_check_group_call_is_joined_timeout_callback);
  check_group_call_is_joined_timeout_.set_callback_data(static_cast<void *>(this));

  pending_send_speaking_action_timeout_.set_callback(on_pending_send_speaking_action_timeout_callback);
  pending_send_speaking_action_timeout_.set_callback_data(static_cast<void *>(this));

  recent_speaker_update_timeout_.set_callback(on_recent_speaker_update_timeout_callback);
  recent_speaker_update_timeout_.set_callback_data(static_cast<void *>(this));

  sync_participants_timeout_.set_callback(on_sync_participants_timeout_callback);
  sync_participants_timeout_.set_callback_data(static_cast<void *>(this));
}

GroupCallManager::~GroupCallManager() = default;

void GroupCallManager::tear_down() {
  parent_.reset();
}

void GroupCallManager::on_update_group_call_participant_order_timeout_callback(void *group_call_manager_ptr,
                                                                               int64 group_call_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto group_call_manager = static_cast<GroupCallManager *>(group_call_manager_ptr);
  send_closure_later(group_call_manager->actor_id(group_call_manager),
                     &GroupCallManager::on_update_group_call_participant_order_timeout,
                     GroupCallId(narrow_cast<int32>(group_call_id_int)));
}

void GroupCallManager::on_update_group_call_participant_order_timeout(GroupCallId group_call_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Receive update group call participant order timeout in " << group_call_id;
  auto input_group_call_id = get_input_group_call_id(group_call_id).move_as_ok();

  if (!need_group_call_participants(input_group_call_id)) {
    return;
  }

  bool can_self_unmute = get_group_call_can_self_unmute(input_group_call_id);
  auto *participants =
      add_group_call_participants(input_group_call_id, "on_update_group_call_participant_order_timeout");
  update_group_call_participants_order(input_group_call_id, can_self_unmute, participants,
                                       "on_update_group_call_participant_order_timeout");
}

void GroupCallManager::on_check_group_call_is_joined_timeout_callback(void *group_call_manager_ptr,
                                                                      int64 group_call_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto group_call_manager = static_cast<GroupCallManager *>(group_call_manager_ptr);
  send_closure_later(group_call_manager->actor_id(group_call_manager),
                     &GroupCallManager::on_check_group_call_is_joined_timeout,
                     GroupCallId(narrow_cast<int32>(group_call_id_int)));
}

void GroupCallManager::on_check_group_call_is_joined_timeout(GroupCallId group_call_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Receive check group call is_joined timeout in " << group_call_id;
  auto input_group_call_id = get_input_group_call_id(group_call_id).move_as_ok();

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  auto audio_source = group_call->audio_source;
  if (!group_call->is_joined || group_call->is_being_joined ||
      check_group_call_is_joined_timeout_.has_timeout(group_call_id.get()) || audio_source == 0) {
    return;
  }

  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), input_group_call_id, audio_source](Result<Unit> &&result) mutable {
        send_closure(actor_id, &GroupCallManager::finish_check_group_call_is_joined, input_group_call_id, audio_source,
                     std::move(result));
      });
  td_->create_handler<CheckGroupCallQuery>(std::move(promise))->send(input_group_call_id, {audio_source});
}

void GroupCallManager::on_pending_send_speaking_action_timeout_callback(void *group_call_manager_ptr,
                                                                        int64 group_call_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto group_call_manager = static_cast<GroupCallManager *>(group_call_manager_ptr);
  send_closure_later(group_call_manager->actor_id(group_call_manager),
                     &GroupCallManager::on_send_speaking_action_timeout,
                     GroupCallId(narrow_cast<int32>(group_call_id_int)));
}

void GroupCallManager::on_send_speaking_action_timeout(GroupCallId group_call_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Receive send_speaking_action timeout in " << group_call_id;
  auto input_group_call_id = get_input_group_call_id(group_call_id).move_as_ok();

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited && group_call->dialog_id.is_valid());
  if (!group_call->is_joined || !group_call->is_speaking) {
    return;
  }

  CHECK(group_call->as_dialog_id.is_valid());
  on_user_speaking_in_group_call(group_call_id, group_call->as_dialog_id, false, G()->unix_time());

  pending_send_speaking_action_timeout_.add_timeout_in(group_call_id.get(), 4.0);

  td_->dialog_action_manager_->send_dialog_action(group_call->dialog_id, MessageId(), {},
                                                  DialogAction::get_speaking_action(), Promise<Unit>());
}

void GroupCallManager::on_recent_speaker_update_timeout_callback(void *group_call_manager_ptr,
                                                                 int64 group_call_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto group_call_manager = static_cast<GroupCallManager *>(group_call_manager_ptr);
  send_closure_later(group_call_manager->actor_id(group_call_manager),
                     &GroupCallManager::on_recent_speaker_update_timeout,
                     GroupCallId(narrow_cast<int32>(group_call_id_int)));
}

void GroupCallManager::on_recent_speaker_update_timeout(GroupCallId group_call_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Receive recent speaker update timeout in " << group_call_id;
  auto input_group_call_id = get_input_group_call_id(group_call_id).move_as_ok();

  get_recent_speakers(get_group_call(input_group_call_id),
                      false);  // will update the list and send updateGroupCall if needed
}

void GroupCallManager::on_sync_participants_timeout_callback(void *group_call_manager_ptr, int64 group_call_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto group_call_manager = static_cast<GroupCallManager *>(group_call_manager_ptr);
  send_closure_later(group_call_manager->actor_id(group_call_manager), &GroupCallManager::on_sync_participants_timeout,
                     GroupCallId(narrow_cast<int32>(group_call_id_int)));
}

void GroupCallManager::on_sync_participants_timeout(GroupCallId group_call_id) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Receive sync participants timeout in " << group_call_id;
  auto input_group_call_id = get_input_group_call_id(group_call_id).move_as_ok();

  sync_group_call_participants(input_group_call_id);
}

bool GroupCallManager::is_group_call_being_joined(InputGroupCallId input_group_call_id) const {
  return pending_join_requests_.count(input_group_call_id) != 0;
}

bool GroupCallManager::is_group_call_joined(InputGroupCallId input_group_call_id) const {
  auto group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr) {
    return false;
  }
  return group_call->is_joined && !group_call->is_being_left;
}

GroupCallId GroupCallManager::get_group_call_id(InputGroupCallId input_group_call_id, DialogId dialog_id) {
  if (td_->auth_manager_->is_bot() || !input_group_call_id.is_valid()) {
    return GroupCallId();
  }
  return add_group_call(input_group_call_id, dialog_id)->group_call_id;
}

Result<InputGroupCallId> GroupCallManager::get_input_group_call_id(GroupCallId group_call_id) {
  if (!group_call_id.is_valid()) {
    return Status::Error(400, "Invalid group call identifier specified");
  }
  if (group_call_id.get() <= 0 || group_call_id.get() > max_group_call_id_.get()) {
    return Status::Error(400, "Wrong group call identifier specified");
  }
  CHECK(static_cast<size_t>(group_call_id.get()) <= input_group_call_ids_.size());
  auto input_group_call_id = input_group_call_ids_[group_call_id.get() - 1];
  LOG(DEBUG) << "Found " << input_group_call_id;
  return input_group_call_id;
}

GroupCallId GroupCallManager::get_next_group_call_id(InputGroupCallId input_group_call_id) {
  max_group_call_id_ = GroupCallId(max_group_call_id_.get() + 1);
  input_group_call_ids_.push_back(input_group_call_id);
  return max_group_call_id_;
}

GroupCallManager::GroupCall *GroupCallManager::add_group_call(InputGroupCallId input_group_call_id,
                                                              DialogId dialog_id) {
  CHECK(!td_->auth_manager_->is_bot());
  auto &group_call = group_calls_[input_group_call_id];
  if (group_call == nullptr) {
    group_call = make_unique<GroupCall>();
    group_call->group_call_id = get_next_group_call_id(input_group_call_id);
    LOG(INFO) << "Add " << input_group_call_id << " from " << dialog_id << " as " << group_call->group_call_id;
  }
  if (!group_call->dialog_id.is_valid()) {
    group_call->dialog_id = dialog_id;
  }
  return group_call.get();
}

const GroupCallManager::GroupCall *GroupCallManager::get_group_call(InputGroupCallId input_group_call_id) const {
  auto it = group_calls_.find(input_group_call_id);
  if (it == group_calls_.end()) {
    return nullptr;
  } else {
    return it->second.get();
  }
}

GroupCallManager::GroupCall *GroupCallManager::get_group_call(InputGroupCallId input_group_call_id) {
  auto it = group_calls_.find(input_group_call_id);
  if (it == group_calls_.end()) {
    return nullptr;
  } else {
    return it->second.get();
  }
}

Status GroupCallManager::can_join_group_calls(DialogId dialog_id) const {
  TRY_STATUS(td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read, "can_join_group_calls"));
  switch (dialog_id.get_type()) {
    case DialogType::Chat:
    case DialogType::Channel:
      break;
    case DialogType::User:
      return Status::Error(400, "Chat can't have a voice chat");
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      UNREACHABLE();
      break;
  }
  return Status::OK();
}

Status GroupCallManager::can_manage_group_calls(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      if (!td_->chat_manager_->get_chat_permissions(chat_id).can_manage_calls()) {
        return Status::Error(400, "Not enough rights in the chat");
      }
      break;
    }
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      if (!td_->chat_manager_->get_channel_permissions(channel_id).can_manage_calls()) {
        return Status::Error(400, "Not enough rights in the chat");
      }
      break;
    }
    case DialogType::User:
    case DialogType::SecretChat:
      return Status::Error(400, "Chat can't have a voice chat");
    case DialogType::None:
      // OK
      break;
    default:
      UNREACHABLE();
  }
  return Status::OK();
}

bool GroupCallManager::can_manage_group_call(InputGroupCallId input_group_call_id) const {
  auto group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr) {
    return false;
  }
  return can_manage_group_calls(group_call->dialog_id).is_ok();
}

bool GroupCallManager::get_group_call_can_self_unmute(InputGroupCallId input_group_call_id) const {
  auto group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  return group_call->can_self_unmute;
}

bool GroupCallManager::get_group_call_joined_date_asc(InputGroupCallId input_group_call_id) const {
  auto group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  return group_call->joined_date_asc;
}

void GroupCallManager::get_group_call_join_as(DialogId dialog_id,
                                              Promise<td_api::object_ptr<td_api::messageSenders>> &&promise) {
  TRY_STATUS_PROMISE(promise, can_join_group_calls(dialog_id));

  td_->create_handler<GetGroupCallJoinAsQuery>(std::move(promise))->send(dialog_id);
}

void GroupCallManager::set_group_call_default_join_as(DialogId dialog_id, DialogId as_dialog_id,
                                                      Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, can_join_group_calls(dialog_id));

  switch (as_dialog_id.get_type()) {
    case DialogType::User:
      if (as_dialog_id != td_->dialog_manager_->get_my_dialog_id()) {
        return promise.set_error(Status::Error(400, "Can't join voice chat as another user"));
      }
      break;
    case DialogType::Chat:
    case DialogType::Channel:
      if (!td_->dialog_manager_->have_dialog_force(as_dialog_id, "set_group_call_default_join_as 2")) {
        return promise.set_error(Status::Error(400, "Participant chat not found"));
      }
      break;
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't join voice chat as a secret chat"));
    default:
      return promise.set_error(Status::Error(400, "Invalid default participant identifier specified"));
  }
  if (!td_->dialog_manager_->have_input_peer(as_dialog_id, false, AccessRights::Read)) {
    return promise.set_error(Status::Error(400, "Can't access specified default participant chat"));
  }

  td_->create_handler<SaveDefaultGroupCallJoinAsQuery>(std::move(promise))->send(dialog_id, as_dialog_id);
  td_->messages_manager_->on_update_dialog_default_join_group_call_as_dialog_id(dialog_id, as_dialog_id, true);
}

void GroupCallManager::create_voice_chat(DialogId dialog_id, string title, int32 start_date, bool is_rtmp_stream,
                                         Promise<GroupCallId> &&promise) {
  TRY_STATUS_PROMISE(
      promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read, "create_voice_chat"));
  TRY_STATUS_PROMISE(promise, can_manage_group_calls(dialog_id));

  title = clean_name(title, MAX_TITLE_LENGTH);

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), dialog_id, promise = std::move(promise)](Result<InputGroupCallId> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &GroupCallManager::on_voice_chat_created, dialog_id, result.move_as_ok(),
                       std::move(promise));
        }
      });
  td_->create_handler<CreateGroupCallQuery>(std::move(query_promise))
      ->send(dialog_id, title, start_date, is_rtmp_stream);
}

void GroupCallManager::get_voice_chat_rtmp_stream_url(DialogId dialog_id, bool revoke,
                                                      Promise<td_api::object_ptr<td_api::rtmpUrl>> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                        "get_voice_chat_rtmp_stream_url"));
  TRY_STATUS_PROMISE(promise, can_manage_group_calls(dialog_id));

  td_->create_handler<GetGroupCallRtmpStreamUrlGroupCallQuery>(std::move(promise))->send(dialog_id, revoke);
}

void GroupCallManager::on_voice_chat_created(DialogId dialog_id, InputGroupCallId input_group_call_id,
                                             Promise<GroupCallId> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  if (!input_group_call_id.is_valid()) {
    return promise.set_error(Status::Error(500, "Receive invalid group call identifier"));
  }

  td_->messages_manager_->on_update_dialog_group_call(dialog_id, true, true, "on_voice_chat_created");
  td_->messages_manager_->on_update_dialog_group_call_id(dialog_id, input_group_call_id);

  promise.set_value(get_group_call_id(input_group_call_id, dialog_id));
}

void GroupCallManager::get_group_call(GroupCallId group_call_id,
                                      Promise<td_api::object_ptr<td_api::groupCall>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto group_call = get_group_call(input_group_call_id);
  if (group_call != nullptr && group_call->is_inited) {
    return promise.set_value(get_group_call_object(group_call, get_recent_speakers(group_call, false)));
  }

  reload_group_call(input_group_call_id, std::move(promise));
}

void GroupCallManager::on_update_group_call_rights(InputGroupCallId input_group_call_id) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  auto group_call = get_group_call(input_group_call_id);
  if (need_group_call_participants(group_call)) {
    CHECK(group_call != nullptr && group_call->is_inited);
    try_load_group_call_administrators(input_group_call_id, group_call->dialog_id);

    auto *group_call_participants = add_group_call_participants(input_group_call_id, "on_update_group_call_rights");
    if (group_call_participants->are_administrators_loaded) {
      update_group_call_participants_can_be_muted(
          input_group_call_id, can_manage_group_calls(group_call->dialog_id).is_ok(), group_call_participants);
    }
  }

  if (group_call != nullptr && group_call->is_inited) {
    bool can_be_managed = group_call->is_active && can_manage_group_calls(group_call->dialog_id).is_ok();
    if (can_be_managed != group_call->can_be_managed) {
      group_call->can_be_managed = can_be_managed;
      send_update_group_call(group_call, "on_update_group_call_rights");
    }
  }

  reload_group_call(input_group_call_id, Auto());
}

void GroupCallManager::reload_group_call(InputGroupCallId input_group_call_id,
                                         Promise<td_api::object_ptr<td_api::groupCall>> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    return promise.set_error(Status::Error(400, "Bots can't get group call info"));
  }
  if (!input_group_call_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid group call identifier specified"));
  }

  auto &queries = load_group_call_queries_[input_group_call_id];
  queries.push_back(std::move(promise));
  if (queries.size() == 1) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id](
                                                    Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result) {
      send_closure(actor_id, &GroupCallManager::finish_get_group_call, input_group_call_id, std::move(result));
    });
    td_->create_handler<GetGroupCallQuery>(std::move(query_promise))->send(input_group_call_id, 3);
  }
}

void GroupCallManager::finish_get_group_call(InputGroupCallId input_group_call_id,
                                             Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result) {
  G()->ignore_result_if_closing(result);

  auto it = load_group_call_queries_.find(input_group_call_id);
  CHECK(it != load_group_call_queries_.end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  load_group_call_queries_.erase(it);

  if (result.is_ok()) {
    td_->user_manager_->on_get_users(std::move(result.ok_ref()->users_), "finish_get_group_call");
    td_->chat_manager_->on_get_chats(std::move(result.ok_ref()->chats_), "finish_get_group_call");

    if (update_group_call(result.ok()->call_, DialogId()) != input_group_call_id) {
      LOG(ERROR) << "Expected " << input_group_call_id << ", but received " << to_string(result.ok());
      result = Status::Error(500, "Receive another group call");
    }
  }

  if (result.is_error()) {
    fail_promises(promises, result.move_as_error());
    return;
  }

  auto call = result.move_as_ok();
  int32 version = 0;
  if (call->call_->get_id() == telegram_api::groupCall::ID) {
    version = static_cast<const telegram_api::groupCall *>(call->call_.get())->version_;
  }
  process_group_call_participants(input_group_call_id, std::move(call->participants_), version, string(), true, false);
  auto group_call = get_group_call(input_group_call_id);
  if (need_group_call_participants(group_call)) {
    auto *group_call_participants = add_group_call_participants(input_group_call_id, "finish_get_group_call");
    if (group_call_participants->next_offset.empty()) {
      group_call_participants->next_offset = std::move(call->participants_next_offset_);
    }
  }

  CHECK(group_call != nullptr && group_call->is_inited);
  for (auto &promise : promises) {
    if (promise) {
      promise.set_value(get_group_call_object(group_call, get_recent_speakers(group_call, false)));
    }
  }
}

void GroupCallManager::finish_check_group_call_is_joined(InputGroupCallId input_group_call_id, int32 audio_source,
                                                         Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Finish check group call is_joined for " << input_group_call_id;

  if (result.is_error()) {
    auto message = result.error().message();
    if (message == "GROUPCALL_JOIN_MISSING" || message == "GROUPCALL_FORBIDDEN" || message == "GROUPCALL_INVALID") {
      on_group_call_left(input_group_call_id, audio_source, message == "GROUPCALL_JOIN_MISSING");
    }
  }

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  CHECK(audio_source != 0);
  if (!group_call->is_joined || group_call->is_being_joined ||
      check_group_call_is_joined_timeout_.has_timeout(group_call->group_call_id.get()) ||
      group_call->audio_source != audio_source) {
    return;
  }

  int32 next_timeout = result.is_ok() ? CHECK_GROUP_CALL_IS_JOINED_TIMEOUT : 1;
  check_group_call_is_joined_timeout_.set_timeout_in(group_call->group_call_id.get(), next_timeout);
}

const string &GroupCallManager::get_group_call_title(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->pending_title.empty() ? group_call->title : group_call->pending_title;
}

bool GroupCallManager::get_group_call_is_joined(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return (group_call->is_joined || group_call->is_being_joined) && !group_call->is_being_left;
}

bool GroupCallManager::get_group_call_start_subscribed(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->have_pending_start_subscribed ? group_call->pending_start_subscribed
                                                   : group_call->start_subscribed;
}

bool GroupCallManager::get_group_call_is_my_video_paused(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->have_pending_is_my_video_paused ? group_call->pending_is_my_video_paused
                                                     : group_call->is_my_video_paused;
}

bool GroupCallManager::get_group_call_is_my_video_enabled(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->have_pending_is_my_video_enabled ? group_call->pending_is_my_video_enabled
                                                      : group_call->is_my_video_enabled;
}

bool GroupCallManager::get_group_call_is_my_presentation_paused(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->have_pending_is_my_presentation_paused ? group_call->pending_is_my_presentation_paused
                                                            : group_call->is_my_presentation_paused;
}

bool GroupCallManager::get_group_call_mute_new_participants(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->have_pending_mute_new_participants ? group_call->pending_mute_new_participants
                                                        : group_call->mute_new_participants;
}

int32 GroupCallManager::get_group_call_record_start_date(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->have_pending_record_start_date ? group_call->pending_record_start_date
                                                    : group_call->record_start_date;
}

bool GroupCallManager::get_group_call_is_video_recorded(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return group_call->have_pending_record_start_date ? group_call->pending_record_record_video
                                                    : group_call->is_video_recorded;
}

bool GroupCallManager::get_group_call_has_recording(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  return get_group_call_record_start_date(group_call) != 0;
}

bool GroupCallManager::get_group_call_can_enable_video(const GroupCall *group_call) {
  CHECK(group_call != nullptr);
  if (group_call->unmuted_video_limit <= 0) {
    return true;
  }
  return group_call->unmuted_video_count < group_call->unmuted_video_limit;
}

bool GroupCallManager::is_group_call_active(const GroupCall *group_call) {
  return group_call != nullptr && group_call->is_inited && group_call->is_active;
}

bool GroupCallManager::need_group_call_participants(InputGroupCallId input_group_call_id) const {
  return need_group_call_participants(get_group_call(input_group_call_id));
}

bool GroupCallManager::need_group_call_participants(const GroupCall *group_call) {
  if (!is_group_call_active(group_call) || group_call->is_being_left) {
    return false;
  }
  if (group_call->is_joined || group_call->need_rejoin || group_call->is_being_joined) {
    return true;
  }
  return false;
}

void GroupCallManager::on_get_group_call_participants(
    InputGroupCallId input_group_call_id, tl_object_ptr<telegram_api::phone_groupParticipants> &&participants,
    bool is_load, const string &offset) {
  LOG(INFO) << "Receive group call participants: " << to_string(participants);

  CHECK(participants != nullptr);
  td_->user_manager_->on_get_users(std::move(participants->users_), "on_get_group_call_participants");
  td_->chat_manager_->on_get_chats(std::move(participants->chats_), "on_get_group_call_participants");

  if (!need_group_call_participants(input_group_call_id)) {
    return;
  }

  bool is_sync = is_load && offset.empty();
  if (is_sync) {
    auto group_call = get_group_call(input_group_call_id);
    CHECK(group_call != nullptr && group_call->is_inited);
    is_sync = group_call->syncing_participants;
    if (is_sync) {
      group_call->syncing_participants = false;

      if (group_call->version >= participants->version_) {
        LOG(INFO) << "Ignore result of outdated participants sync with version " << participants->version_ << " in "
                  << input_group_call_id << " from " << group_call->dialog_id << ", because current version is "
                  << group_call->version;
        return;
      }
      LOG(INFO) << "Finish syncing participants in " << input_group_call_id << " from " << group_call->dialog_id
                << " with version " << participants->version_;
      group_call->version = participants->version_;
    }
  }

  auto is_empty = participants->participants_.empty();
  process_group_call_participants(input_group_call_id, std::move(participants->participants_), participants->version_,
                                  offset, is_load, is_sync);

  if (!is_sync) {
    on_receive_group_call_version(input_group_call_id, participants->version_);
  }

  if (is_load) {
    auto *group_call_participants = add_group_call_participants(input_group_call_id, "on_get_group_call_participants");
    if (group_call_participants->next_offset == offset) {
      if (!offset.empty() && participants->next_offset_.empty() && group_call_participants->joined_date_asc) {
        LOG(INFO) << "Ignore empty next_offset";
      } else {
        group_call_participants->next_offset = std::move(participants->next_offset_);
      }
    }

    if (is_empty || is_sync) {
      bool need_update = false;
      auto group_call = get_group_call(input_group_call_id);
      CHECK(group_call != nullptr && group_call->is_inited);
      if (is_empty && !group_call->loaded_all_participants) {
        group_call->loaded_all_participants = true;
        need_update = true;
      }

      auto real_participant_count = participants->count_;
      if (!group_call->is_joined) {
        real_participant_count++;
      }
      if (is_empty) {
        auto known_participant_count = static_cast<int32>(group_call_participants->participants.size());
        if (real_participant_count != known_participant_count) {
          LOG(ERROR) << "Receive participant count " << real_participant_count << ", but know "
                     << known_participant_count << " participants in " << input_group_call_id << " from "
                     << group_call->dialog_id;
          real_participant_count = known_participant_count;
        }
      }
      if (!is_empty && is_sync && group_call->loaded_all_participants && real_participant_count > 50) {
        group_call->loaded_all_participants = false;
        need_update = true;
      }
      if (real_participant_count != group_call->participant_count) {
        if (!is_sync) {
          LOG(ERROR) << "Have participant count " << group_call->participant_count << " instead of "
                     << real_participant_count << " in " << input_group_call_id << " from " << group_call->dialog_id;
        }
        need_update |=
            set_group_call_participant_count(group_call, real_participant_count, "on_get_group_call_participants 1");
      }
      if (process_pending_group_call_participant_updates(input_group_call_id)) {
        need_update = false;
      }
      if (group_call->loaded_all_participants || !group_call_participants->min_order.has_video()) {
        set_group_call_unmuted_video_count(group_call, group_call_participants->local_unmuted_video_count,
                                           "on_get_group_call_participants 2");
      }
      if (need_update) {
        send_update_group_call(group_call, "on_get_group_call_participants 3");
      }

      if (is_sync && group_call->need_syncing_participants) {
        group_call->need_syncing_participants = false;
        sync_group_call_participants(input_group_call_id);
      }
    }
  }
}

GroupCallManager::GroupCallParticipants *GroupCallManager::add_group_call_participants(
    InputGroupCallId input_group_call_id, const char *source) {
  LOG_CHECK(need_group_call_participants(input_group_call_id)) << source;

  auto &participants = group_call_participants_[input_group_call_id];
  if (participants == nullptr) {
    participants = make_unique<GroupCallParticipants>();
    participants->joined_date_asc = get_group_call_joined_date_asc(input_group_call_id);
  }
  return participants.get();
}

GroupCallParticipant *GroupCallManager::get_group_call_participant(InputGroupCallId input_group_call_id,
                                                                   DialogId dialog_id, const char *source) {
  return get_group_call_participant(add_group_call_participants(input_group_call_id, source), dialog_id);
}

GroupCallParticipant *GroupCallManager::get_group_call_participant(GroupCallParticipants *group_call_participants,
                                                                   DialogId dialog_id) const {
  if (!dialog_id.is_valid()) {
    return nullptr;
  }
  if (dialog_id == td_->dialog_manager_->get_my_dialog_id()) {
    for (auto &group_call_participant : group_call_participants->participants) {
      if (group_call_participant.is_self) {
        return &group_call_participant;
      }
    }
  } else {
    for (auto &group_call_participant : group_call_participants->participants) {
      if (group_call_participant.dialog_id == dialog_id) {
        return &group_call_participant;
      }
    }
  }
  return nullptr;
}

void GroupCallManager::on_update_group_call_participants(
    InputGroupCallId input_group_call_id, vector<tl_object_ptr<telegram_api::groupCallParticipant>> &&participants,
    int32 version, bool is_recursive) {
  if (G()->close_flag()) {
    return;
  }

  if (!need_group_call_participants(input_group_call_id)) {
    int32 diff = 0;
    int32 video_diff = 0;
    bool need_update = false;
    auto group_call = get_group_call(input_group_call_id);
    for (auto &group_call_participant : participants) {
      GroupCallParticipant participant(group_call_participant, version);
      if (!participant.is_valid()) {
        LOG(ERROR) << "Receive invalid " << to_string(group_call_participant);
        continue;
      }
      if (participant.is_self && group_call != nullptr && group_call->is_being_left) {
        continue;
      }
      if (participant.joined_date == 0) {
        if (group_call == nullptr || version > group_call->leave_version) {
          diff--;
          video_diff += participant.video_diff;
        }
        remove_recent_group_call_speaker(input_group_call_id, participant.dialog_id);
      } else {
        if (group_call == nullptr || version >= group_call->leave_version) {
          if (participant.is_just_joined) {
            diff++;
          }
          video_diff += participant.video_diff;
        }
        on_participant_speaking_in_group_call(input_group_call_id, participant);
      }
    }

    if (is_group_call_active(group_call) && group_call->version == -1) {
      need_update |= set_group_call_participant_count(group_call, group_call->participant_count + diff,
                                                      "on_update_group_call_participants 1");
      need_update |= set_group_call_unmuted_video_count(group_call, group_call->unmuted_video_count + video_diff,
                                                        "on_update_group_call_participants 2");
    }
    if (need_update) {
      send_update_group_call(group_call, "on_update_group_call_participants 3");
    }

    LOG(INFO) << "Ignore updateGroupCallParticipants in " << input_group_call_id;
    return;
  }
  if (version <= 0) {
    LOG(ERROR) << "Ignore updateGroupCallParticipants with invalid version " << version << " in "
               << input_group_call_id;
    return;
  }
  if (participants.empty()) {
    LOG(INFO) << "Ignore empty updateGroupCallParticipants with version " << version << " in " << input_group_call_id;
    return;
  }

  auto *group_call_participants = add_group_call_participants(input_group_call_id, "on_update_group_call_participants");
  if (!is_recursive) {
    vector<DialogId> missing_participants;
    for (auto &group_call_participant : participants) {
      GroupCallParticipant participant(group_call_participant, version);
      if (participant.is_valid() && participant.is_min && participant.joined_date != 0 &&
          get_group_call_participant(group_call_participants, participant.dialog_id) == nullptr) {
        missing_participants.push_back(participant.dialog_id);
      }
    }
    if (!missing_participants.empty()) {
      LOG(INFO) << "Can't apply min updates about " << missing_participants << " in " << input_group_call_id;
      auto input_peers = transform(missing_participants, &DialogManager::get_input_peer_force);
      auto query_promise =
          PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id,
                                  participants = std::move(participants), version](Result<Unit> &&result) mutable {
            send_closure(actor_id, &GroupCallManager::on_update_group_call_participants, input_group_call_id,
                         std::move(participants), version, true);
          });
      td_->create_handler<GetGroupCallParticipantQuery>(std::move(query_promise))
          ->send(input_group_call_id, std::move(input_peers), {});
      return;
    }
  }

  auto &pending_version_updates = group_call_participants->pending_version_updates_[version].updates;
  auto &pending_mute_updates = group_call_participants->pending_mute_updates_[version].updates;
  LOG(INFO) << "Have " << pending_version_updates.size() << " versioned and " << pending_mute_updates.size()
            << " mute pending updates for " << input_group_call_id;
  for (auto &group_call_participant : participants) {
    GroupCallParticipant participant(group_call_participant, version);
    if (!participant.is_valid()) {
      LOG(ERROR) << "Receive invalid " << to_string(group_call_participant);
      continue;
    }
    if (participant.is_min && participant.joined_date != 0) {
      auto old_participant = get_group_call_participant(group_call_participants, participant.dialog_id);
      if (old_participant == nullptr) {
        LOG(ERROR) << "Can't apply min update about " << participant.dialog_id << " in " << input_group_call_id;
        on_receive_group_call_version(input_group_call_id, version, true);
        return;
      }

      participant.update_from(*old_participant);
      CHECK(!participant.is_min);
    }
    auto dialog_id = participant.dialog_id;
    if (dialog_id.get_type() != DialogType::User && participant.joined_date != 0) {
      td_->dialog_manager_->force_create_dialog(dialog_id, "on_update_group_call_participants 4", true);
    }

    bool is_versioned = GroupCallParticipant::is_versioned_update(group_call_participant);
    LOG(INFO) << "Add " << (is_versioned ? "versioned" : "muted") << " update for " << participant;
    if (is_versioned) {
      pending_version_updates[dialog_id] = td::make_unique<GroupCallParticipant>(std::move(participant));
    } else {
      pending_mute_updates[dialog_id] = td::make_unique<GroupCallParticipant>(std::move(participant));
    }
  }

  process_pending_group_call_participant_updates(input_group_call_id);
}

bool GroupCallManager::process_pending_group_call_participant_updates(InputGroupCallId input_group_call_id) {
  if (!need_group_call_participants(input_group_call_id)) {
    return false;
  }

  auto participants_it = group_call_participants_.find(input_group_call_id);
  if (participants_it == group_call_participants_.end()) {
    return false;
  }
  auto group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  if (group_call->version == -1 || !group_call->is_active) {
    return false;
  }

  std::pair<int32, int32> diff{0, 0};
  bool is_left = false;
  bool need_rejoin = true;
  auto &pending_version_updates = participants_it->second->pending_version_updates_;
  auto &pending_mute_updates = participants_it->second->pending_mute_updates_;

  auto process_mute_updates = [&] {
    while (!pending_mute_updates.empty()) {
      auto it = pending_mute_updates.begin();
      auto version = it->first;
      if (version > group_call->version) {
        return;
      }

      auto &participants = it->second.updates;
      LOG(INFO) << "Process " << participants.size() << " mute updates for " << input_group_call_id;
      for (auto &participant_it : participants) {
        auto &participant = *participant_it.second;
        on_participant_speaking_in_group_call(input_group_call_id, participant);
        auto mute_diff = process_group_call_participant(input_group_call_id, std::move(participant));
        CHECK(mute_diff.first == 0);
        diff.second += mute_diff.second;
      }
      pending_mute_updates.erase(it);
    }
  };

  bool need_update = false;
  while (!pending_version_updates.empty()) {
    process_mute_updates();

    auto it = pending_version_updates.begin();
    auto version = it->first;
    auto &participants = it->second.updates;
    if (version <= group_call->version) {
      for (auto &participant_it : participants) {
        auto &participant = *participant_it.second;
        on_participant_speaking_in_group_call(input_group_call_id, participant);
        if (participant.is_self || participant.joined_date != 0) {
          auto new_diff = process_group_call_participant(input_group_call_id, std::move(participant));
          diff.first += new_diff.first;
          diff.second += new_diff.second;
        }
      }
      LOG(INFO) << "Ignore already applied updateGroupCallParticipants with version " << version << " in "
                << input_group_call_id << " from " << group_call->dialog_id;
      pending_version_updates.erase(it);
      continue;
    }

    if (version == group_call->version + 1) {
      LOG(INFO) << "Process " << participants.size() << " versioned updates for " << input_group_call_id;
      group_call->version = version;
      for (auto &participant_it : participants) {
        auto &participant = *participant_it.second;
        if (participant.is_self && group_call->is_joined &&
            (participant.joined_date == 0) ==
                is_my_audio_source(input_group_call_id, group_call, participant.audio_source)) {
          LOG(INFO) << "Leaving " << input_group_call_id << " after processing update with joined date "
                    << participant.joined_date;
          is_left = true;
          if (participant.joined_date != 0) {
            need_rejoin = false;
          } else {
            continue;
          }
        }
        auto new_diff = process_group_call_participant(input_group_call_id, std::move(participant));
        diff.first += new_diff.first;
        diff.second += new_diff.second;
      }
      pending_version_updates.erase(it);
    } else {
      // found a gap
      if (!group_call->syncing_participants) {
        LOG(INFO) << "Receive " << participants.size() << " group call participant updates with version " << version
                  << ", but current version is " << group_call->version;
        sync_participants_timeout_.add_timeout_in(group_call->group_call_id.get(), 1.0);
      }
      break;
    }
  }

  process_mute_updates();

  if (!pending_mute_updates.empty()) {
    on_receive_group_call_version(input_group_call_id, pending_mute_updates.begin()->first);
  }

  if (pending_version_updates.empty() && pending_mute_updates.empty()) {
    sync_participants_timeout_.cancel_timeout(group_call->group_call_id.get());
  }

  need_update |= set_group_call_participant_count(group_call, group_call->participant_count + diff.first,
                                                  "process_pending_group_call_participant_updates 1");
  need_update |= set_group_call_unmuted_video_count(group_call, group_call->unmuted_video_count + diff.second,
                                                    "process_pending_group_call_participant_updates 2");
  if (is_left && group_call->is_joined) {
    on_group_call_left_impl(group_call, need_rejoin, "process_pending_group_call_participant_updates 3");
    need_update = true;
  }
  need_update |= try_clear_group_call_participants(input_group_call_id);
  if (need_update) {
    send_update_group_call(group_call, "process_pending_group_call_participant_updates 4");
  }

  return need_update;
}

bool GroupCallManager::is_my_audio_source(InputGroupCallId input_group_call_id, const GroupCall *group_call,
                                          int32 audio_source) const {
  auto it = pending_join_requests_.find(input_group_call_id);
  if (it == pending_join_requests_.end()) {
    return audio_source == group_call->audio_source;
  }
  CHECK(it->second != nullptr);

  return audio_source == it->second->audio_source;
}

void GroupCallManager::sync_group_call_participants(InputGroupCallId input_group_call_id) {
  auto group_call = get_group_call(input_group_call_id);
  if (!need_group_call_participants(group_call)) {
    return;
  }
  CHECK(group_call != nullptr && group_call->is_inited);

  sync_participants_timeout_.cancel_timeout(group_call->group_call_id.get());

  if (group_call->syncing_participants) {
    group_call->need_syncing_participants = true;
    return;
  }
  group_call->syncing_participants = true;
  group_call->need_syncing_participants = false;

  LOG(INFO) << "Force participants synchronization in " << input_group_call_id << " from " << group_call->dialog_id;
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id](
                                            Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result) {
    send_closure(actor_id, &GroupCallManager::on_sync_group_call_participants, input_group_call_id, std::move(result));
  });

  td_->create_handler<GetGroupCallQuery>(std::move(promise))->send(input_group_call_id, 100);
}

void GroupCallManager::on_sync_group_call_participants(InputGroupCallId input_group_call_id,
                                                       Result<tl_object_ptr<telegram_api::phone_groupCall>> &&result) {
  if (G()->close_flag() || !need_group_call_participants(input_group_call_id)) {
    return;
  }

  if (result.is_error()) {
    auto group_call = get_group_call(input_group_call_id);
    CHECK(group_call != nullptr && group_call->is_inited);
    CHECK(group_call->syncing_participants);
    group_call->syncing_participants = false;

    sync_participants_timeout_.add_timeout_in(group_call->group_call_id.get(),
                                              group_call->need_syncing_participants ? 0.0 : 1.0);
    return;
  }

  auto call = result.move_as_ok();
  if (call->call_->get_id() == telegram_api::groupCall::ID) {
    auto *group_call = static_cast<const telegram_api::groupCall *>(call->call_.get());
    auto participants = make_tl_object<telegram_api::phone_groupParticipants>(
        group_call->participants_count_, std::move(call->participants_), std::move(call->participants_next_offset_),
        std::move(call->chats_), std::move(call->users_), group_call->version_);
    on_get_group_call_participants(input_group_call_id, std::move(participants), true, string());
  }

  if (update_group_call(call->call_, DialogId()) != input_group_call_id) {
    LOG(ERROR) << "Expected " << input_group_call_id << ", but received " << to_string(result.ok());
  }
}

GroupCallParticipantOrder GroupCallManager::get_real_participant_order(bool can_self_unmute,
                                                                       const GroupCallParticipant &participant,
                                                                       const GroupCallParticipants *participants) {
  auto real_order = participant.get_real_order(can_self_unmute, participants->joined_date_asc);
  if (real_order >= participants->min_order) {
    return real_order;
  }
  if (participant.is_self) {
    return participants->min_order;
  }
  if (real_order.is_valid()) {
    LOG(DEBUG) << "Order " << real_order << " of " << participant.dialog_id << " is less than last known order "
               << participants->min_order;
  }
  return GroupCallParticipantOrder();
}

void GroupCallManager::process_group_call_participants(
    InputGroupCallId input_group_call_id, vector<tl_object_ptr<telegram_api::groupCallParticipant>> &&participants,
    int32 version, const string &offset, bool is_load, bool is_sync) {
  // if receive exactly one participant, then the current user is the only participant
  // there are no reasons to process it independently
  if (offset.empty() && is_load && participants.size() >= 2 && participants[0]->self_) {
    GroupCallParticipant participant(participants[0], version);
    if (participant.is_valid()) {
      process_my_group_call_participant(input_group_call_id, std::move(participant));
    }
    participants.erase(participants.begin());
  }
  if (!need_group_call_participants(input_group_call_id)) {
    for (auto &group_call_participant : participants) {
      GroupCallParticipant participant(group_call_participant, version);
      if (!participant.is_valid()) {
        LOG(ERROR) << "Receive invalid " << to_string(group_call_participant);
        continue;
      }
      if (participant.dialog_id.get_type() != DialogType::User) {
        td_->dialog_manager_->force_create_dialog(participant.dialog_id, "process_group_call_participants", true);
      }

      on_participant_speaking_in_group_call(input_group_call_id, participant);
    }
    return;
  }

  FlatHashSet<DialogId, DialogIdHash> old_participant_dialog_ids;
  if (is_sync) {
    auto *group_call_participants = add_group_call_participants(input_group_call_id, "process_group_call_participants");
    for (auto &participant : group_call_participants->participants) {
      CHECK(participant.dialog_id.is_valid());
      old_participant_dialog_ids.insert(participant.dialog_id);
    }
  }

  auto min_order = GroupCallParticipantOrder::max();
  DialogId debug_min_order_dialog_id;
  bool can_self_unmute = get_group_call_can_self_unmute(input_group_call_id);
  bool joined_date_asc = get_group_call_joined_date_asc(input_group_call_id);
  for (auto &group_call_participant : participants) {
    GroupCallParticipant participant(group_call_participant, version);
    if (!participant.is_valid()) {
      LOG(ERROR) << "Receive invalid " << to_string(group_call_participant);
      continue;
    }
    if (participant.is_min) {
      LOG(ERROR) << "Receive unexpected min " << to_string(group_call_participant);
      continue;
    }
    if (participant.dialog_id.get_type() != DialogType::User) {
      td_->dialog_manager_->force_create_dialog(participant.dialog_id, "process_group_call_participants", true);
    }

    if (is_load) {
      auto real_order = participant.get_server_order(can_self_unmute, joined_date_asc);
      if (real_order > min_order) {
        LOG(ERROR) << "Receive group call participant " << participant.dialog_id << " with order " << real_order
                   << " after group call participant " << debug_min_order_dialog_id << " with order " << min_order;
      } else {
        min_order = real_order;
        debug_min_order_dialog_id = participant.dialog_id;
      }
    }
    if (is_sync) {
      old_participant_dialog_ids.erase(participant.dialog_id);
    }
    process_group_call_participant(input_group_call_id, std::move(participant));
  }
  if (is_load && participants.empty() && !joined_date_asc) {
    // If loaded 0 participants and new participants are added to the beginning of the list,
    // then the end of the list was reached.
    // Set min_order to the minimum possible value to send updates about all participants with order less than
    // the current min_order. There can be such participants if the last loaded participant had a fake active_date.
    min_order = GroupCallParticipantOrder::min();
  }
  if (is_sync) {
    auto *group_call_participants = add_group_call_participants(input_group_call_id, "process_group_call_participants");
    auto &group_participants = group_call_participants->participants;
    for (auto participant_it = group_participants.begin(); participant_it != group_participants.end();) {
      auto &participant = *participant_it;
      if (old_participant_dialog_ids.count(participant.dialog_id) == 0) {
        // successfully synced old user
        ++participant_it;
        continue;
      }

      if (participant.is_self) {
        if (participant.order != min_order) {
          participant.order = min_order;
          send_update_group_call_participant(input_group_call_id, participant, "process_group_call_participants self");
        }
        ++participant_it;
        continue;
      }

      // not synced user and not self, needs to be deleted
      if (participant.order.is_valid()) {
        CHECK(participant.order >= group_call_participants->min_order);
        participant.order = GroupCallParticipantOrder();
        send_update_group_call_participant(input_group_call_id, participant, "process_group_call_participants sync");
      }
      on_remove_group_call_participant(input_group_call_id, participant.dialog_id);
      group_call_participants->local_unmuted_video_count -= participant.get_has_video();
      participant_it = group_participants.erase(participant_it);
    }
    if (group_call_participants->min_order < min_order) {
      // if previously known more users, adjust min_order
      LOG(INFO) << "Decrease min_order from " << group_call_participants->min_order << " to " << min_order << " in "
                << input_group_call_id;
      group_call_participants->min_order = min_order;
      update_group_call_participants_order(input_group_call_id, can_self_unmute, group_call_participants,
                                           "decrease min_order");
    }
  }
  if (is_load) {
    auto *group_call_participants = add_group_call_participants(input_group_call_id, "process_group_call_participants");
    if (group_call_participants->min_order > min_order) {
      LOG(INFO) << "Increase min_order from " << group_call_participants->min_order << " to " << min_order << " in "
                << input_group_call_id;
      group_call_participants->min_order = min_order;
      update_group_call_participants_order(input_group_call_id, can_self_unmute, group_call_participants,
                                           "increase min_order");
    }
  }
}

bool GroupCallManager::update_group_call_participant_can_be_muted(bool can_manage,
                                                                  const GroupCallParticipants *participants,
                                                                  GroupCallParticipant &participant) {
  bool is_admin = td::contains(participants->administrator_dialog_ids, participant.dialog_id);
  return participant.update_can_be_muted(can_manage, is_admin);
}

void GroupCallManager::update_group_call_participants_can_be_muted(InputGroupCallId input_group_call_id,
                                                                   bool can_manage,
                                                                   GroupCallParticipants *participants) {
  CHECK(participants != nullptr);
  LOG(INFO) << "Update group call participants can_be_muted in " << input_group_call_id;
  for (auto &participant : participants->participants) {
    if (update_group_call_participant_can_be_muted(can_manage, participants, participant) &&
        participant.order.is_valid()) {
      send_update_group_call_participant(input_group_call_id, participant,
                                         "update_group_call_participants_can_be_muted");
    }
  }
}

void GroupCallManager::update_group_call_participants_order(InputGroupCallId input_group_call_id, bool can_self_unmute,
                                                            GroupCallParticipants *participants, const char *source) {
  for (auto &participant : participants->participants) {
    auto new_order = get_real_participant_order(can_self_unmute, participant, participants);
    if (new_order != participant.order) {
      participant.order = new_order;
      send_update_group_call_participant(input_group_call_id, participant, "process_group_call_participants load");
    }
  }

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  update_group_call_participant_order_timeout_.set_timeout_in(group_call->group_call_id.get(),
                                                              UPDATE_GROUP_CALL_PARTICIPANT_ORDER_TIMEOUT);
}

void GroupCallManager::process_my_group_call_participant(InputGroupCallId input_group_call_id,
                                                         GroupCallParticipant &&participant) {
  CHECK(participant.is_valid());
  CHECK(participant.is_self);
  if (!need_group_call_participants(input_group_call_id)) {
    return;
  }
  auto my_participant = get_group_call_participant(input_group_call_id, td_->dialog_manager_->get_my_dialog_id(),
                                                   "process_my_group_call_participant");
  if (my_participant == nullptr || my_participant->is_fake || my_participant->joined_date < participant.joined_date ||
      (my_participant->joined_date <= participant.joined_date &&
       my_participant->audio_source != participant.audio_source)) {
    process_group_call_participant(input_group_call_id, std::move(participant));
  }
}

std::pair<int32, int32> GroupCallManager::process_group_call_participant(InputGroupCallId input_group_call_id,
                                                                         GroupCallParticipant &&participant) {
  if (!participant.is_valid()) {
    LOG(ERROR) << "Receive invalid " << participant;
    return {0, 0};
  }
  if (!need_group_call_participants(input_group_call_id)) {
    return {0, 0};
  }

  LOG(INFO) << "Process " << participant << " in " << input_group_call_id;

  if (participant.is_self) {
    auto *group_call = get_group_call(input_group_call_id);
    CHECK(group_call != nullptr && group_call->is_inited);
    auto can_self_unmute = group_call->is_active && !participant.get_is_muted_by_admin();
    if (can_self_unmute != group_call->can_self_unmute) {
      group_call->can_self_unmute = can_self_unmute;
      send_update_group_call(group_call, "process_group_call_participant 1");
      sync_group_call_participants(input_group_call_id);  // participant order is different for administrators
    }
  }

  bool can_self_unmute = get_group_call_can_self_unmute(input_group_call_id);
  bool can_manage = can_manage_group_call(input_group_call_id);
  auto *participants = add_group_call_participants(input_group_call_id, "process_group_call_participant");
  for (size_t i = 0; i < participants->participants.size(); i++) {
    auto &old_participant = participants->participants[i];
    if (old_participant.dialog_id == participant.dialog_id || (old_participant.is_self && participant.is_self)) {
      if (participant.joined_date == 0) {
        LOG(INFO) << "Remove " << old_participant;
        if (old_participant.order.is_valid()) {
          send_update_group_call_participant(input_group_call_id, participant, "process_group_call_participant remove");
        }
        on_remove_group_call_participant(input_group_call_id, old_participant.dialog_id);
        remove_recent_group_call_speaker(input_group_call_id, old_participant.dialog_id);
        int32 unmuted_video_diff = -old_participant.get_has_video();
        participants->local_unmuted_video_count += unmuted_video_diff;
        participants->participants.erase(participants->participants.begin() + i);
        return {-1, unmuted_video_diff};
      }

      if (old_participant.version > participant.version) {
        LOG(INFO) << "Ignore outdated update of " << old_participant.dialog_id;
        return {0, 0};
      }

      if (old_participant.dialog_id != participant.dialog_id) {
        on_remove_group_call_participant(input_group_call_id, old_participant.dialog_id);
        on_add_group_call_participant(input_group_call_id, participant.dialog_id);
      }

      participant.update_from(old_participant);

      participant.is_just_joined = false;
      participant.order = get_real_participant_order(can_self_unmute, participant, participants);
      update_group_call_participant_can_be_muted(can_manage, participants, participant);

      LOG(INFO) << "Edit " << old_participant << " to " << participant;
      if (old_participant != participant && (old_participant.order.is_valid() || participant.order.is_valid())) {
        send_update_group_call_participant(input_group_call_id, participant, "process_group_call_participant edit");
        if (old_participant.dialog_id != participant.dialog_id) {
          // delete old self-participant; shouldn't affect correct apps
          old_participant.order = GroupCallParticipantOrder();
          send_update_group_call_participant(input_group_call_id, old_participant,
                                             "process_group_call_participant edit self");
        }
      }
      on_participant_speaking_in_group_call(input_group_call_id, participant);
      int32 unmuted_video_diff = participant.get_has_video() - old_participant.get_has_video();
      participants->local_unmuted_video_count += unmuted_video_diff;
      old_participant = std::move(participant);
      return {0, unmuted_video_diff};
    }
  }

  if (participant.joined_date == 0) {
    LOG(INFO) << "Remove unknown " << participant;
    remove_recent_group_call_speaker(input_group_call_id, participant.dialog_id);
    return {-1, participant.video_diff};
  }

  CHECK(!participant.is_min);
  int diff = participant.is_just_joined ? 1 : 0;
  participant.order = get_real_participant_order(can_self_unmute, participant, participants);
  if (participant.is_just_joined) {
    LOG(INFO) << "Add new " << participant;
  } else {
    LOG(INFO) << "Receive new " << participant;
  }
  participant.is_just_joined = false;
  participants->local_unmuted_video_count += participant.get_has_video();
  update_group_call_participant_can_be_muted(can_manage, participants, participant);
  participants->participants.push_back(std::move(participant));
  if (participants->participants.back().order.is_valid()) {
    send_update_group_call_participant(input_group_call_id, participants->participants.back(),
                                       "process_group_call_participant add");
  } else {
    auto *group_call = get_group_call(input_group_call_id);
    CHECK(group_call != nullptr && group_call->is_inited);
    if (group_call->loaded_all_participants) {
      group_call->loaded_all_participants = false;
      send_update_group_call(group_call, "process_group_call_participant 2");
    }
  }
  on_add_group_call_participant(input_group_call_id, participants->participants.back().dialog_id);
  on_participant_speaking_in_group_call(input_group_call_id, participants->participants.back());
  return {diff, participants->participants.back().video_diff};
}

void GroupCallManager::on_add_group_call_participant(InputGroupCallId input_group_call_id,
                                                     DialogId participant_dialog_id) {
  auto &participants = participant_id_to_group_call_id_[participant_dialog_id];
  CHECK(!td::contains(participants, input_group_call_id));
  participants.push_back(input_group_call_id);
}

void GroupCallManager::on_remove_group_call_participant(InputGroupCallId input_group_call_id,
                                                        DialogId participant_dialog_id) {
  auto it = participant_id_to_group_call_id_.find(participant_dialog_id);
  CHECK(it != participant_id_to_group_call_id_.end());
  bool is_removed = td::remove(it->second, input_group_call_id);
  CHECK(is_removed);
  if (it->second.empty()) {
    participant_id_to_group_call_id_.erase(it);
  }
}

void GroupCallManager::on_update_dialog_about(DialogId dialog_id, const string &about, bool from_server) {
  auto it = participant_id_to_group_call_id_.find(dialog_id);
  if (it == participant_id_to_group_call_id_.end()) {
    return;
  }
  CHECK(!it->second.empty());

  for (const auto &input_group_call_id : it->second) {
    auto participant = get_group_call_participant(input_group_call_id, dialog_id, "on_update_dialog_about");
    CHECK(participant != nullptr);
    if ((from_server || participant->is_fake) && participant->about != about) {
      participant->about = about;
      if (participant->order.is_valid()) {
        send_update_group_call_participant(input_group_call_id, *participant, "on_update_dialog_about");
      }
    }
  }
}

int32 GroupCallManager::cancel_join_group_call_request(InputGroupCallId input_group_call_id, GroupCall *group_call) {
  auto it = pending_join_requests_.find(input_group_call_id);
  if (it == pending_join_requests_.end()) {
    CHECK(group_call == nullptr || !group_call->is_being_joined);
    return 0;
  }
  CHECK(group_call != nullptr);
  CHECK(group_call->is_being_joined);
  group_call->is_being_joined = false;

  CHECK(it->second != nullptr);
  if (!it->second->query_ref.empty()) {
    cancel_query(it->second->query_ref);
  }
  it->second->promise.set_error(Status::Error(200, "Canceled"));
  auto audio_source = it->second->audio_source;
  pending_join_requests_.erase(it);
  return audio_source;
}

int32 GroupCallManager::cancel_join_group_call_presentation_request(InputGroupCallId input_group_call_id) {
  auto it = pending_join_presentation_requests_.find(input_group_call_id);
  if (it == pending_join_presentation_requests_.end()) {
    return 0;
  }

  CHECK(it->second != nullptr);
  if (!it->second->query_ref.empty()) {
    cancel_query(it->second->query_ref);
  }
  it->second->promise.set_error(Status::Error(200, "Canceled"));
  auto audio_source = it->second->audio_source;
  pending_join_presentation_requests_.erase(it);
  return audio_source;
}

void GroupCallManager::get_group_call_streams(GroupCallId group_call_id,
                                              Promise<td_api::object_ptr<td_api::groupCallStreams>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(input_group_call_id,
                      PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, promise = std::move(promise)](
                                                 Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
                        if (result.is_error()) {
                          promise.set_error(result.move_as_error());
                        } else {
                          send_closure(actor_id, &GroupCallManager::get_group_call_streams, group_call_id,
                                       std::move(promise));
                        }
                      }));
    return;
  }
  if (!group_call->is_active || !group_call->stream_dc_id.is_exact()) {
    return promise.set_error(Status::Error(400, "Group call can't be streamed"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(PromiseCreator::lambda(
          [actor_id = actor_id(this), group_call_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(result.move_as_error());
            } else {
              send_closure(actor_id, &GroupCallManager::get_group_call_streams, group_call_id, std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), input_group_call_id, audio_source = group_call->audio_source,
       promise = std::move(promise)](Result<td_api::object_ptr<td_api::groupCallStreams>> &&result) mutable {
        send_closure(actor_id, &GroupCallManager::finish_get_group_call_streams, input_group_call_id, audio_source,
                     std::move(result), std::move(promise));
      });
  td_->create_handler<GetGroupCallStreamChannelsQuery>(std::move(query_promise))
      ->send(input_group_call_id, group_call->stream_dc_id);
}

void GroupCallManager::finish_get_group_call_streams(InputGroupCallId input_group_call_id, int32 audio_source,
                                                     Result<td_api::object_ptr<td_api::groupCallStreams>> &&result,
                                                     Promise<td_api::object_ptr<td_api::groupCallStreams>> &&promise) {
  if (!G()->close_flag() && result.is_error()) {
    auto message = result.error().message();
    if (message == "GROUPCALL_JOIN_MISSING" || message == "GROUPCALL_FORBIDDEN" || message == "GROUPCALL_INVALID") {
      on_group_call_left(input_group_call_id, audio_source, message == "GROUPCALL_JOIN_MISSING");
    }
  }

  promise.set_result(std::move(result));
}

void GroupCallManager::get_group_call_stream_segment(GroupCallId group_call_id, int64 time_offset, int32 scale,
                                                     int32 channel_id,
                                                     td_api::object_ptr<td_api::GroupCallVideoQuality> quality,
                                                     Promise<string> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(input_group_call_id,
                      PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, time_offset, scale, channel_id,
                                              quality = std::move(quality), promise = std::move(promise)](
                                                 Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
                        if (result.is_error()) {
                          promise.set_error(result.move_as_error());
                        } else {
                          send_closure(actor_id, &GroupCallManager::get_group_call_stream_segment, group_call_id,
                                       time_offset, scale, channel_id, std::move(quality), std::move(promise));
                        }
                      }));
    return;
  }
  if (!group_call->is_active || !group_call->stream_dc_id.is_exact()) {
    return promise.set_error(Status::Error(400, "Group call can't be streamed"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(PromiseCreator::lambda(
          [actor_id = actor_id(this), group_call_id, time_offset, scale, channel_id, quality = std::move(quality),
           promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(result.move_as_error());
            } else {
              send_closure(actor_id, &GroupCallManager::get_group_call_stream_segment, group_call_id, time_offset,
                           scale, channel_id, std::move(quality), std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  int32 video_quality = 0;
  if (quality != nullptr) {
    switch (quality->get_id()) {
      case td_api::groupCallVideoQualityThumbnail::ID:
        video_quality = 0;
        break;
      case td_api::groupCallVideoQualityMedium::ID:
        video_quality = 1;
        break;
      case td_api::groupCallVideoQualityFull::ID:
        video_quality = 2;
        break;
      default:
        UNREACHABLE();
    }
  }

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, audio_source = group_call->audio_source,
                              promise = std::move(promise)](Result<string> &&result) mutable {
        send_closure(actor_id, &GroupCallManager::finish_get_group_call_stream_segment, input_group_call_id,
                     audio_source, std::move(result), std::move(promise));
      });
  td_->create_handler<GetGroupCallStreamQuery>(std::move(query_promise))
      ->send(input_group_call_id, group_call->stream_dc_id, time_offset, scale, channel_id, video_quality);
}

void GroupCallManager::finish_get_group_call_stream_segment(InputGroupCallId input_group_call_id, int32 audio_source,
                                                            Result<string> &&result, Promise<string> &&promise) {
  if (!G()->close_flag()) {
    if (result.is_ok()) {
      auto *group_call = get_group_call(input_group_call_id);
      CHECK(group_call != nullptr);
      if (group_call->is_inited && check_group_call_is_joined_timeout_.has_timeout(group_call->group_call_id.get())) {
        check_group_call_is_joined_timeout_.set_timeout_in(group_call->group_call_id.get(),
                                                           CHECK_GROUP_CALL_IS_JOINED_TIMEOUT);
      }
    } else {
      auto message = result.error().message();
      if (message == "GROUPCALL_JOIN_MISSING" || message == "GROUPCALL_FORBIDDEN" || message == "GROUPCALL_INVALID") {
        on_group_call_left(input_group_call_id, audio_source, message == "GROUPCALL_JOIN_MISSING");
      }
    }
  }

  promise.set_result(std::move(result));
}

void GroupCallManager::start_scheduled_group_call(GroupCallId group_call_id, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(input_group_call_id,
                      PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, promise = std::move(promise)](
                                                 Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
                        if (result.is_error()) {
                          promise.set_error(result.move_as_error());
                        } else {
                          send_closure(actor_id, &GroupCallManager::start_scheduled_group_call, group_call_id,
                                       std::move(promise));
                        }
                      }));
    return;
  }
  if (!group_call->can_be_managed) {
    return promise.set_error(Status::Error(400, "Not enough rights to start the group call"));
  }
  if (!group_call->is_active) {
    return promise.set_error(Status::Error(400, "Group call already ended"));
  }
  if (group_call->scheduled_start_date == 0) {
    return promise.set_value(Unit());
  }

  td_->create_handler<StartScheduledGroupCallQuery>(std::move(promise))->send(input_group_call_id);
}

void GroupCallManager::join_group_call(GroupCallId group_call_id, DialogId as_dialog_id, int32 audio_source,
                                       string &&payload, bool is_muted, bool is_my_video_enabled,
                                       const string &invite_hash, int64 key_fingerprint, Promise<string> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr);
  if (group_call->is_inited && !group_call->is_active) {
    return promise.set_error(Status::Error(400, "Group call is finished"));
  }
  bool need_update = false;
  bool old_is_joined = get_group_call_is_joined(group_call);
  bool is_rejoin = group_call->need_rejoin;
  if (group_call->need_rejoin) {
    group_call->need_rejoin = false;
    need_update = true;
  }

  cancel_join_group_call_request(input_group_call_id, group_call);

  bool have_as_dialog_id = true;
  {
    auto my_dialog_id = td_->dialog_manager_->get_my_dialog_id();
    if (!as_dialog_id.is_valid()) {
      as_dialog_id = my_dialog_id;
    }
    auto dialog_type = as_dialog_id.get_type();
    if (dialog_type == DialogType::User) {
      if (as_dialog_id != my_dialog_id) {
        return promise.set_error(Status::Error(400, "Can't join voice chat as another user"));
      }
      if (!td_->user_manager_->have_user_force(as_dialog_id.get_user_id(), "join_group_call")) {
        have_as_dialog_id = false;
      }
    } else {
      if (!td_->dialog_manager_->have_dialog_force(as_dialog_id, "join_group_call")) {
        return promise.set_error(Status::Error(400, "Join as chat not found"));
      }
    }
    if (!td_->dialog_manager_->have_input_peer(as_dialog_id, false, AccessRights::Read)) {
      return promise.set_error(Status::Error(400, "Can't access the join as participant"));
    }
  }

  if (group_call->is_being_left) {
    group_call->is_being_left = false;
  }
  group_call->is_being_joined = true;

  auto generation = ++join_group_request_generation_;
  auto &request = pending_join_requests_[input_group_call_id];
  request = make_unique<PendingJoinRequest>();
  request->generation = generation;
  request->audio_source = audio_source;
  request->as_dialog_id = as_dialog_id;
  request->key_fingerprint = key_fingerprint;
  request->promise = std::move(promise);

  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), generation, input_group_call_id](Result<Unit> &&result) {
        CHECK(result.is_error());
        send_closure(actor_id, &GroupCallManager::finish_join_group_call, input_group_call_id, generation,
                     result.move_as_error());
      });
  request->query_ref = td_->create_handler<JoinGroupCallQuery>(std::move(query_promise))
                           ->send(input_group_call_id, as_dialog_id, payload, is_muted, !is_my_video_enabled,
                                  invite_hash, key_fingerprint, generation);

  if (group_call->dialog_id.is_valid()) {
    td_->messages_manager_->on_update_dialog_default_join_group_call_as_dialog_id(group_call->dialog_id, as_dialog_id,
                                                                                  true);
  } else {
    if (as_dialog_id.get_type() != DialogType::User) {
      td_->dialog_manager_->force_create_dialog(as_dialog_id, "join_group_call");
    }
  }
  if (group_call->is_inited && have_as_dialog_id) {
    GroupCallParticipant participant;
    participant.is_self = true;
    participant.dialog_id = as_dialog_id;
    participant.about = td_->dialog_manager_->get_dialog_about(participant.dialog_id);
    participant.audio_source = audio_source;
    participant.joined_date = G()->unix_time();
    // if can_self_unmute has never been inited from self-participant,
    // it contains reasonable default "!call.mute_new_participants || call.can_be_managed"
    participant.server_is_muted_by_admin = !group_call->can_self_unmute && !can_manage_group_call(input_group_call_id);
    participant.server_is_muted_by_themselves = is_muted && !participant.server_is_muted_by_admin;
    participant.is_just_joined = !is_rejoin;
    participant.video_diff = get_group_call_can_enable_video(group_call) && is_my_video_enabled;
    participant.is_fake = true;
    auto diff = process_group_call_participant(input_group_call_id, std::move(participant));
    if (diff.first != 0) {
      CHECK(diff.first == 1);
      need_update |= set_group_call_participant_count(group_call, group_call->participant_count + diff.first,
                                                      "join_group_call 1", true);
    }
    if (diff.second != 0) {
      CHECK(diff.second == 1);
      need_update |= set_group_call_unmuted_video_count(group_call, group_call->unmuted_video_count + diff.second,
                                                        "join_group_call 2");
    }
  }
  if (group_call->is_my_video_enabled != is_my_video_enabled) {
    group_call->is_my_video_enabled = is_my_video_enabled;
    if (!is_my_video_enabled) {
      group_call->is_my_video_paused = false;
    }
    need_update = true;
  }
  if (old_is_joined != get_group_call_is_joined(group_call)) {
    need_update = true;
  }
  if (group_call->is_inited && need_update) {
    send_update_group_call(group_call, "join_group_call 3");
  }

  try_load_group_call_administrators(input_group_call_id, group_call->dialog_id);
}

void GroupCallManager::start_group_call_screen_sharing(GroupCallId group_call_id, int32 audio_source, string &&payload,
                                                       Promise<string> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr);
  if (!group_call->is_inited || !group_call->is_active) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined || group_call->is_being_left) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, audio_source, payload = std::move(payload),
                                  promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::start_group_call_screen_sharing, group_call_id, audio_source,
                           std::move(payload), std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  cancel_join_group_call_presentation_request(input_group_call_id);

  auto generation = ++join_group_request_generation_;
  auto &request = pending_join_presentation_requests_[input_group_call_id];
  request = make_unique<PendingJoinRequest>();
  request->generation = generation;
  request->audio_source = audio_source;
  request->promise = std::move(promise);

  request->query_ref =
      td_->create_handler<JoinGroupCallPresentationQuery>()->send(input_group_call_id, payload, generation);

  bool need_update = false;
  if (group_call->is_inited && need_update) {
    send_update_group_call(group_call, "start_group_call_screen_sharing");
  }
}

void GroupCallManager::end_group_call_screen_sharing(GroupCallId group_call_id, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr);
  if (!group_call->is_inited || !group_call->is_active) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined || group_call->is_being_left) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(PromiseCreator::lambda(
          [actor_id = actor_id(this), group_call_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::end_group_call_screen_sharing, group_call_id,
                           std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  cancel_join_group_call_presentation_request(input_group_call_id);

  group_call->have_pending_is_my_presentation_paused = false;
  group_call->pending_is_my_presentation_paused = false;

  td_->create_handler<LeaveGroupCallPresentationQuery>(std::move(promise))->send(input_group_call_id);
}

void GroupCallManager::try_load_group_call_administrators(InputGroupCallId input_group_call_id, DialogId dialog_id) {
  if (!dialog_id.is_valid() || !need_group_call_participants(input_group_call_id) ||
      can_manage_group_calls(dialog_id).is_error()) {
    LOG(INFO) << "Don't need to load administrators in " << input_group_call_id << " from " << dialog_id;
    return;
  }

  auto promise =
      PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id](Result<DialogParticipants> &&result) {
        send_closure(actor_id, &GroupCallManager::finish_load_group_call_administrators, input_group_call_id,
                     std::move(result));
      });
  td_->dialog_participant_manager_->search_dialog_participants(
      dialog_id, string(), 100, DialogParticipantFilter(td_api::make_object<td_api::chatMembersFilterAdministrators>()),
      std::move(promise));
}

void GroupCallManager::finish_load_group_call_administrators(InputGroupCallId input_group_call_id,
                                                             Result<DialogParticipants> &&result) {
  if (G()->close_flag()) {
    return;
  }
  if (result.is_error()) {
    LOG(WARNING) << "Failed to get administrators of " << input_group_call_id << ": " << result.error();
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!need_group_call_participants(group_call)) {
    return;
  }
  CHECK(group_call != nullptr);
  if (!group_call->dialog_id.is_valid() || !can_manage_group_calls(group_call->dialog_id).is_ok()) {
    return;
  }

  vector<DialogId> administrator_dialog_ids;
  auto participants = result.move_as_ok();
  for (auto &administrator : participants.participants_) {
    if (administrator.status_.can_manage_calls() &&
        administrator.dialog_id_ != td_->dialog_manager_->get_my_dialog_id()) {
      administrator_dialog_ids.push_back(administrator.dialog_id_);
    }
  }

  auto *group_call_participants =
      add_group_call_participants(input_group_call_id, "finish_load_group_call_administrators");
  if (group_call_participants->are_administrators_loaded &&
      group_call_participants->administrator_dialog_ids == administrator_dialog_ids) {
    return;
  }

  LOG(INFO) << "Set administrators of " << input_group_call_id << " to " << administrator_dialog_ids;
  group_call_participants->are_administrators_loaded = true;
  group_call_participants->administrator_dialog_ids = std::move(administrator_dialog_ids);

  update_group_call_participants_can_be_muted(input_group_call_id, true, group_call_participants);
}

void GroupCallManager::process_join_group_call_response(InputGroupCallId input_group_call_id, uint64 generation,
                                                        tl_object_ptr<telegram_api::Updates> &&updates,
                                                        Promise<Unit> &&promise) {
  auto it = pending_join_requests_.find(input_group_call_id);
  if (it == pending_join_requests_.end() || it->second->generation != generation) {
    LOG(INFO) << "Ignore JoinGroupCallQuery response with " << input_group_call_id << " and generation " << generation;
    return;
  }

  td_->updates_manager_->on_get_updates(std::move(updates),
                                        PromiseCreator::lambda([promise = std::move(promise)](Unit) mutable {
                                          promise.set_error(Status::Error(500, "Wrong join response received"));
                                        }));
}

void GroupCallManager::process_join_group_call_presentation_response(InputGroupCallId input_group_call_id,
                                                                     uint64 generation,
                                                                     tl_object_ptr<telegram_api::Updates> &&updates,
                                                                     Status status) {
  auto it = pending_join_presentation_requests_.find(input_group_call_id);
  if (it == pending_join_presentation_requests_.end() || it->second->generation != generation) {
    LOG(INFO) << "Ignore JoinGroupCallPresentationQuery response with " << input_group_call_id << " and generation "
              << generation;
    return;
  }
  auto promise = std::move(it->second->promise);
  pending_join_presentation_requests_.erase(it);

  if (status.is_error()) {
    return promise.set_error(std::move(status));
  }
  CHECK(updates != nullptr);

  string params = UpdatesManager::extract_join_group_call_presentation_params(updates.get());
  if (params.empty()) {
    return promise.set_error(
        Status::Error(500, "Wrong start group call screen sharing response received: parameters are missing"));
  }
  td_->updates_manager_->on_get_updates(
      std::move(updates), PromiseCreator::lambda([params = std::move(params), promise = std::move(promise)](
                                                     Unit) mutable { promise.set_value(std::move(params)); }));
}

bool GroupCallManager::on_join_group_call_response(InputGroupCallId input_group_call_id, string json_response) {
  auto it = pending_join_requests_.find(input_group_call_id);
  if (it == pending_join_requests_.end()) {
    return false;
  }
  CHECK(it->second != nullptr);

  auto group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr);
  group_call->is_joined = true;
  group_call->need_rejoin = false;
  group_call->is_being_joined = false;
  group_call->is_being_left = false;
  group_call->joined_date = G()->unix_time();
  group_call->audio_source = it->second->audio_source;
  group_call->as_dialog_id = it->second->as_dialog_id;
  it->second->promise.set_value(std::move(json_response));
  if (group_call->audio_source != 0) {
    check_group_call_is_joined_timeout_.set_timeout_in(group_call->group_call_id.get(),
                                                       CHECK_GROUP_CALL_IS_JOINED_TIMEOUT);
  }
  pending_join_requests_.erase(it);
  try_clear_group_call_participants(input_group_call_id);
  process_group_call_after_join_requests(input_group_call_id, "on_join_group_call_response");
  return true;
}

void GroupCallManager::finish_join_group_call(InputGroupCallId input_group_call_id, uint64 generation, Status error) {
  CHECK(error.is_error());
  auto it = pending_join_requests_.find(input_group_call_id);
  if (it == pending_join_requests_.end() || (generation != 0 && it->second->generation != generation)) {
    return;
  }
  it->second->promise.set_error(std::move(error));
  auto as_dialog_id = it->second->as_dialog_id;
  pending_join_requests_.erase(it);

  if (G()->close_flag()) {
    return;
  }

  GroupCall *group_call = get_group_call(input_group_call_id);
  bool need_update = false;
  if (group_call != nullptr && group_call->is_being_joined) {
    bool old_is_joined = get_group_call_is_joined(group_call);
    group_call->is_being_joined = false;
    need_update |= old_is_joined != get_group_call_is_joined(group_call);
  }
  remove_recent_group_call_speaker(input_group_call_id, as_dialog_id);
  if (try_clear_group_call_participants(input_group_call_id)) {
    CHECK(group_call != nullptr);
    need_update = true;
  }
  if (need_update && group_call->is_inited) {
    send_update_group_call(group_call, "finish_join_group_call");
  }
  process_group_call_after_join_requests(input_group_call_id, "finish_join_group_call");

  if (group_call != nullptr && group_call->dialog_id.is_valid()) {
    update_group_call_dialog(group_call, "finish_join_group_call", false);
    td_->dialog_manager_->reload_dialog_info_full(group_call->dialog_id, "finish_join_group_call");
  }
}

void GroupCallManager::process_group_call_after_join_requests(InputGroupCallId input_group_call_id,
                                                              const char *source) {
  GroupCall *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    return;
  }
  if (group_call->is_being_joined || group_call->need_rejoin) {
    LOG(ERROR) << "Failed to process after-join requests from " << source << ": " << group_call->is_being_joined << " "
               << group_call->need_rejoin;
    return;
  }
  if (group_call->after_join.empty()) {
    return;
  }

  if (!group_call->is_active || group_call->is_being_left || !group_call->is_joined) {
    fail_promises(group_call->after_join, Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  } else {
    set_promises(group_call->after_join);
  }
}

void GroupCallManager::set_group_call_title(GroupCallId group_call_id, string title, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(
        input_group_call_id,
        PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, title, promise = std::move(promise)](
                                   Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure(actor_id, &GroupCallManager::set_group_call_title, group_call_id, std::move(title),
                         std::move(promise));
          }
        }));
    return;
  }
  if (!group_call->is_active || !group_call->can_be_managed) {
    return promise.set_error(Status::Error(400, "Can't change group call title"));
  }

  title = clean_name(title, MAX_TITLE_LENGTH);
  if (title == get_group_call_title(group_call)) {
    return promise.set_value(Unit());
  }

  // there is no reason to save promise; we will send an update with actual value anyway

  if (group_call->pending_title.empty()) {
    send_edit_group_call_title_query(input_group_call_id, title);
  }
  group_call->pending_title = std::move(title);
  send_update_group_call(group_call, "set_group_call_title");
  promise.set_value(Unit());
}

void GroupCallManager::send_edit_group_call_title_query(InputGroupCallId input_group_call_id, const string &title) {
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, title](Result<Unit> result) {
    send_closure(actor_id, &GroupCallManager::on_edit_group_call_title, input_group_call_id, title, std::move(result));
  });
  td_->create_handler<EditGroupCallTitleQuery>(std::move(promise))->send(input_group_call_id, title);
}

void GroupCallManager::on_edit_group_call_title(InputGroupCallId input_group_call_id, const string &title,
                                                Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call)) {
    return;
  }

  if (group_call->pending_title != title && group_call->can_be_managed) {
    // need to send another request
    send_edit_group_call_title_query(input_group_call_id, group_call->pending_title);
    return;
  }

  bool is_different = group_call->pending_title != group_call->title;
  if (is_different && group_call->can_be_managed) {
    LOG(ERROR) << "Failed to set title to " << group_call->pending_title << " in " << input_group_call_id << ": "
               << result.error();
  }
  group_call->pending_title.clear();
  if (is_different) {
    send_update_group_call(group_call, "on_set_group_call_title failed");
  }
}

void GroupCallManager::toggle_group_call_is_my_video_paused(GroupCallId group_call_id, bool is_my_video_paused,
                                                            Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call)) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, is_my_video_paused,
                                  promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::toggle_group_call_is_my_video_paused, group_call_id,
                           is_my_video_paused, std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  if (is_my_video_paused == get_group_call_is_my_video_paused(group_call)) {
    return promise.set_value(Unit());
  }

  // there is no reason to save promise; we will send an update with actual value anyway

  group_call->pending_is_my_video_paused = is_my_video_paused;
  if (!group_call->have_pending_is_my_video_paused) {
    group_call->have_pending_is_my_video_paused = true;
    send_toggle_group_call_is_my_video_paused_query(input_group_call_id, group_call->as_dialog_id, is_my_video_paused);
  }
  send_update_group_call(group_call, "toggle_group_call_is_my_video_paused");
  promise.set_value(Unit());
}

void GroupCallManager::send_toggle_group_call_is_my_video_paused_query(InputGroupCallId input_group_call_id,
                                                                       DialogId as_dialog_id, bool is_my_video_paused) {
  auto promise =
      PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, is_my_video_paused](Result<Unit> result) {
        send_closure(actor_id, &GroupCallManager::on_toggle_group_call_is_my_video_paused, input_group_call_id,
                     is_my_video_paused, std::move(result));
      });
  td_->create_handler<EditGroupCallParticipantQuery>(std::move(promise))
      ->send(input_group_call_id, as_dialog_id, false, false, 0, false, false, false, false, true, is_my_video_paused,
             false, false);
}

void GroupCallManager::on_toggle_group_call_is_my_video_paused(InputGroupCallId input_group_call_id,
                                                               bool is_my_video_paused, Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || !group_call->have_pending_is_my_video_paused) {
    return;
  }

  if (result.is_error()) {
    group_call->have_pending_is_my_video_paused = false;
    LOG(ERROR) << "Failed to set is_my_video_paused to " << is_my_video_paused << " in " << input_group_call_id << ": "
               << result.error();
    if (group_call->pending_is_my_video_paused != group_call->is_my_video_paused) {
      send_update_group_call(group_call, "on_toggle_group_call_is_my_video_paused failed");
    }
  } else {
    group_call->is_my_video_paused = is_my_video_paused;
    if (group_call->pending_is_my_video_paused != is_my_video_paused) {
      // need to send another request
      send_toggle_group_call_is_my_video_paused_query(input_group_call_id, group_call->as_dialog_id,
                                                      group_call->pending_is_my_video_paused);
      return;
    }

    group_call->have_pending_is_my_video_paused = false;
  }
}

void GroupCallManager::toggle_group_call_is_my_video_enabled(GroupCallId group_call_id, bool is_my_video_enabled,
                                                             Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call)) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, is_my_video_enabled,
                                  promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::toggle_group_call_is_my_video_enabled, group_call_id,
                           is_my_video_enabled, std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  if (is_my_video_enabled == get_group_call_is_my_video_enabled(group_call)) {
    return promise.set_value(Unit());
  }

  // there is no reason to save promise; we will send an update with actual value anyway

  group_call->pending_is_my_video_enabled = is_my_video_enabled;
  if (!group_call->have_pending_is_my_video_enabled) {
    group_call->have_pending_is_my_video_enabled = true;
    send_toggle_group_call_is_my_video_enabled_query(input_group_call_id, group_call->as_dialog_id,
                                                     is_my_video_enabled);
  }
  send_update_group_call(group_call, "toggle_group_call_is_my_video_enabled");
  promise.set_value(Unit());
}

void GroupCallManager::send_toggle_group_call_is_my_video_enabled_query(InputGroupCallId input_group_call_id,
                                                                        DialogId as_dialog_id,
                                                                        bool is_my_video_enabled) {
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), input_group_call_id, is_my_video_enabled](Result<Unit> result) {
        send_closure(actor_id, &GroupCallManager::on_toggle_group_call_is_my_video_enabled, input_group_call_id,
                     is_my_video_enabled, std::move(result));
      });
  td_->create_handler<EditGroupCallParticipantQuery>(std::move(promise))
      ->send(input_group_call_id, as_dialog_id, false, false, 0, false, false, true, !is_my_video_enabled, false, false,
             false, false);
}

void GroupCallManager::on_toggle_group_call_is_my_video_enabled(InputGroupCallId input_group_call_id,
                                                                bool is_my_video_enabled, Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || !group_call->have_pending_is_my_video_enabled) {
    return;
  }

  if (result.is_error()) {
    group_call->have_pending_is_my_video_enabled = false;
    LOG(ERROR) << "Failed to set is_my_video_enabled to " << is_my_video_enabled << " in " << input_group_call_id
               << ": " << result.error();
    if (group_call->pending_is_my_video_enabled != group_call->is_my_video_enabled) {
      send_update_group_call(group_call, "on_toggle_group_call_is_my_video_enabled failed");
    }
  } else {
    group_call->is_my_video_enabled = is_my_video_enabled;
    if (group_call->pending_is_my_video_enabled != is_my_video_enabled) {
      // need to send another request
      send_toggle_group_call_is_my_video_enabled_query(input_group_call_id, group_call->as_dialog_id,
                                                       group_call->pending_is_my_video_enabled);
      return;
    }

    group_call->have_pending_is_my_video_enabled = false;
  }
}

void GroupCallManager::toggle_group_call_is_my_presentation_paused(GroupCallId group_call_id,
                                                                   bool is_my_presentation_paused,
                                                                   Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call)) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, is_my_presentation_paused,
                                  promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::toggle_group_call_is_my_presentation_paused, group_call_id,
                           is_my_presentation_paused, std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  if (is_my_presentation_paused == get_group_call_is_my_presentation_paused(group_call)) {
    return promise.set_value(Unit());
  }

  // there is no reason to save promise; we will send an update with actual value anyway

  group_call->pending_is_my_presentation_paused = is_my_presentation_paused;
  if (!group_call->have_pending_is_my_presentation_paused) {
    group_call->have_pending_is_my_presentation_paused = true;
    send_toggle_group_call_is_my_presentation_paused_query(input_group_call_id, group_call->as_dialog_id,
                                                           is_my_presentation_paused);
  }
  send_update_group_call(group_call, "toggle_group_call_is_my_presentation_paused");
  promise.set_value(Unit());
}

void GroupCallManager::send_toggle_group_call_is_my_presentation_paused_query(InputGroupCallId input_group_call_id,
                                                                              DialogId as_dialog_id,
                                                                              bool is_my_presentation_paused) {
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), input_group_call_id, is_my_presentation_paused](Result<Unit> result) {
        send_closure(actor_id, &GroupCallManager::on_toggle_group_call_is_my_presentation_paused, input_group_call_id,
                     is_my_presentation_paused, std::move(result));
      });
  td_->create_handler<EditGroupCallParticipantQuery>(std::move(promise))
      ->send(input_group_call_id, as_dialog_id, false, false, 0, false, false, false, false, false, false, true,
             is_my_presentation_paused);
}

void GroupCallManager::on_toggle_group_call_is_my_presentation_paused(InputGroupCallId input_group_call_id,
                                                                      bool is_my_presentation_paused,
                                                                      Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || !group_call->have_pending_is_my_presentation_paused) {
    return;
  }

  if (result.is_error()) {
    group_call->have_pending_is_my_presentation_paused = false;
    LOG(ERROR) << "Failed to set is_my_presentation_paused to " << is_my_presentation_paused << " in "
               << input_group_call_id << ": " << result.error();
    if (group_call->pending_is_my_presentation_paused != group_call->is_my_presentation_paused) {
      send_update_group_call(group_call, "on_toggle_group_call_is_my_presentation_paused failed");
    }
  } else {
    group_call->is_my_presentation_paused = is_my_presentation_paused;
    if (group_call->pending_is_my_presentation_paused != is_my_presentation_paused) {
      // need to send another request
      send_toggle_group_call_is_my_presentation_paused_query(input_group_call_id, group_call->as_dialog_id,
                                                             group_call->pending_is_my_presentation_paused);
      return;
    }

    group_call->have_pending_is_my_presentation_paused = false;
  }
}

void GroupCallManager::toggle_group_call_start_subscribed(GroupCallId group_call_id, bool start_subscribed,
                                                          Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(input_group_call_id,
                      PromiseCreator::lambda(
                          [actor_id = actor_id(this), group_call_id, start_subscribed, promise = std::move(promise)](
                              Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
                            if (result.is_error()) {
                              promise.set_error(result.move_as_error());
                            } else {
                              send_closure(actor_id, &GroupCallManager::toggle_group_call_start_subscribed,
                                           group_call_id, start_subscribed, std::move(promise));
                            }
                          }));
    return;
  }
  if (!group_call->is_active || group_call->scheduled_start_date <= 0) {
    return promise.set_error(Status::Error(400, "Group call isn't scheduled"));
  }

  if (start_subscribed == get_group_call_start_subscribed(group_call)) {
    return promise.set_value(Unit());
  }

  // there is no reason to save promise; we will send an update with actual value anyway

  group_call->pending_start_subscribed = start_subscribed;
  if (!group_call->have_pending_start_subscribed) {
    group_call->have_pending_start_subscribed = true;
    send_toggle_group_call_start_subscription_query(input_group_call_id, start_subscribed);
  }
  send_update_group_call(group_call, "toggle_group_call_start_subscribed");
  promise.set_value(Unit());
}

void GroupCallManager::send_toggle_group_call_start_subscription_query(InputGroupCallId input_group_call_id,
                                                                       bool start_subscribed) {
  auto promise =
      PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, start_subscribed](Result<Unit> result) {
        send_closure(actor_id, &GroupCallManager::on_toggle_group_call_start_subscription, input_group_call_id,
                     start_subscribed, std::move(result));
      });
  td_->create_handler<ToggleGroupCallStartSubscriptionQuery>(std::move(promise))
      ->send(input_group_call_id, start_subscribed);
}

void GroupCallManager::on_toggle_group_call_start_subscription(InputGroupCallId input_group_call_id,
                                                               bool start_subscribed, Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || !group_call->have_pending_start_subscribed) {
    return;
  }

  if (result.is_error()) {
    group_call->have_pending_start_subscribed = false;
    LOG(ERROR) << "Failed to set enabled_start_notification to " << start_subscribed << " in " << input_group_call_id
               << ": " << result.error();
    if (group_call->pending_start_subscribed != group_call->start_subscribed) {
      send_update_group_call(group_call, "on_toggle_group_call_start_subscription failed");
    }
  } else {
    if (group_call->pending_start_subscribed != start_subscribed) {
      // need to send another request
      send_toggle_group_call_start_subscription_query(input_group_call_id, group_call->pending_start_subscribed);
      return;
    }

    group_call->have_pending_start_subscribed = false;
    if (group_call->start_subscribed != start_subscribed) {
      LOG(ERROR) << "Failed to set enabled_start_notification to " << start_subscribed << " in " << input_group_call_id;
      send_update_group_call(group_call, "on_toggle_group_call_start_subscription failed 2");
    }
  }
}

void GroupCallManager::toggle_group_call_mute_new_participants(GroupCallId group_call_id, bool mute_new_participants,
                                                               Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(input_group_call_id,
                      PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, mute_new_participants,
                                              promise = std::move(promise)](
                                                 Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
                        if (result.is_error()) {
                          promise.set_error(result.move_as_error());
                        } else {
                          send_closure(actor_id, &GroupCallManager::toggle_group_call_mute_new_participants,
                                       group_call_id, mute_new_participants, std::move(promise));
                        }
                      }));
    return;
  }
  if (!group_call->is_active || !group_call->can_be_managed || !group_call->allowed_toggle_mute_new_participants) {
    return promise.set_error(Status::Error(400, "Can't change mute_new_participants setting"));
  }

  if (mute_new_participants == get_group_call_mute_new_participants(group_call)) {
    return promise.set_value(Unit());
  }

  // there is no reason to save promise; we will send an update with actual value anyway

  group_call->pending_mute_new_participants = mute_new_participants;
  if (!group_call->have_pending_mute_new_participants) {
    group_call->have_pending_mute_new_participants = true;
    send_toggle_group_call_mute_new_participants_query(input_group_call_id, mute_new_participants);
  }
  send_update_group_call(group_call, "toggle_group_call_mute_new_participants");
  promise.set_value(Unit());
}

void GroupCallManager::send_toggle_group_call_mute_new_participants_query(InputGroupCallId input_group_call_id,
                                                                          bool mute_new_participants) {
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), input_group_call_id, mute_new_participants](Result<Unit> result) {
        send_closure(actor_id, &GroupCallManager::on_toggle_group_call_mute_new_participants, input_group_call_id,
                     mute_new_participants, std::move(result));
      });
  int32 flags = telegram_api::phone_toggleGroupCallSettings::JOIN_MUTED_MASK;
  td_->create_handler<ToggleGroupCallSettingsQuery>(std::move(promise))
      ->send(flags, input_group_call_id, mute_new_participants);
}

void GroupCallManager::on_toggle_group_call_mute_new_participants(InputGroupCallId input_group_call_id,
                                                                  bool mute_new_participants, Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || !group_call->have_pending_mute_new_participants) {
    return;
  }

  if (result.is_error()) {
    group_call->have_pending_mute_new_participants = false;
    if (group_call->can_be_managed && group_call->allowed_toggle_mute_new_participants) {
      LOG(ERROR) << "Failed to set mute_new_participants to " << mute_new_participants << " in " << input_group_call_id
                 << ": " << result.error();
    }
    if (group_call->pending_mute_new_participants != group_call->mute_new_participants) {
      send_update_group_call(group_call, "on_toggle_group_call_mute_new_participants failed");
    }
  } else {
    if (group_call->pending_mute_new_participants != mute_new_participants) {
      // need to send another request
      send_toggle_group_call_mute_new_participants_query(input_group_call_id,
                                                         group_call->pending_mute_new_participants);
      return;
    }

    group_call->have_pending_mute_new_participants = false;
    if (group_call->mute_new_participants != mute_new_participants) {
      LOG(ERROR) << "Failed to set mute_new_participants to " << mute_new_participants << " in " << input_group_call_id;
      send_update_group_call(group_call, "on_toggle_group_call_mute_new_participants failed 2");
    }
  }
}

void GroupCallManager::revoke_group_call_invite_link(GroupCallId group_call_id, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(input_group_call_id,
                      PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, promise = std::move(promise)](
                                                 Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
                        if (result.is_error()) {
                          promise.set_error(result.move_as_error());
                        } else {
                          send_closure(actor_id, &GroupCallManager::revoke_group_call_invite_link, group_call_id,
                                       std::move(promise));
                        }
                      }));
    return;
  }
  if (!group_call->is_active || !group_call->can_be_managed) {
    return promise.set_error(Status::Error(400, "Can't reset invite hash in the group call"));
  }

  int32 flags = telegram_api::phone_toggleGroupCallSettings::RESET_INVITE_HASH_MASK;
  td_->create_handler<ToggleGroupCallSettingsQuery>(std::move(promise))->send(flags, input_group_call_id, false);
}

void GroupCallManager::invite_group_call_participants(GroupCallId group_call_id, vector<UserId> &&user_ids,
                                                      Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  vector<tl_object_ptr<telegram_api::InputUser>> input_users;
  auto my_user_id = td_->user_manager_->get_my_id();
  for (auto user_id : user_ids) {
    TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(user_id));

    if (user_id == my_user_id) {
      // can't invite self
      continue;
    }
    input_users.push_back(std::move(input_user));
  }

  if (input_users.empty()) {
    return promise.set_value(Unit());
  }

  td_->create_handler<InviteToGroupCallQuery>(std::move(promise))->send(input_group_call_id, std::move(input_users));
}

void GroupCallManager::get_group_call_invite_link(GroupCallId group_call_id, bool can_self_unmute,
                                                  Promise<string> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(input_group_call_id,
                      PromiseCreator::lambda(
                          [actor_id = actor_id(this), group_call_id, can_self_unmute, promise = std::move(promise)](
                              Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
                            if (result.is_error()) {
                              promise.set_error(result.move_as_error());
                            } else {
                              send_closure(actor_id, &GroupCallManager::get_group_call_invite_link, group_call_id,
                                           can_self_unmute, std::move(promise));
                            }
                          }));
    return;
  }
  if (!group_call->is_active) {
    return promise.set_error(Status::Error(400, "Can't get group call invite link"));
  }

  if (can_self_unmute && !group_call->can_be_managed) {
    return promise.set_error(Status::Error(400, "Not enough rights in the group call"));
  }

  td_->create_handler<ExportGroupCallInviteQuery>(std::move(promise))->send(input_group_call_id, can_self_unmute);
}

void GroupCallManager::toggle_group_call_recording(GroupCallId group_call_id, bool is_enabled, string title,
                                                   bool record_video, bool use_portrait_orientation,
                                                   Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr || !group_call->is_inited) {
    reload_group_call(
        input_group_call_id,
        PromiseCreator::lambda(
            [actor_id = actor_id(this), group_call_id, is_enabled, title, record_video, use_portrait_orientation,
             promise = std::move(promise)](Result<td_api::object_ptr<td_api::groupCall>> &&result) mutable {
              if (result.is_error()) {
                promise.set_error(result.move_as_error());
              } else {
                send_closure(actor_id, &GroupCallManager::toggle_group_call_recording, group_call_id, is_enabled,
                             std::move(title), record_video, use_portrait_orientation, std::move(promise));
              }
            }));
    return;
  }
  if (!group_call->is_active || !group_call->can_be_managed) {
    return promise.set_error(Status::Error(400, "Can't manage group call recording"));
  }

  title = clean_name(title, MAX_TITLE_LENGTH);

  if (is_enabled == get_group_call_has_recording(group_call)) {
    return promise.set_value(Unit());
  }

  // there is no reason to save promise; we will send an update with actual value anyway

  if (!group_call->have_pending_record_start_date) {
    send_toggle_group_call_recording_query(input_group_call_id, is_enabled, title, record_video,
                                           use_portrait_orientation, toggle_recording_generation_ + 1);
  }
  group_call->have_pending_record_start_date = true;
  group_call->pending_record_start_date = is_enabled ? G()->unix_time() : 0;
  group_call->pending_record_title = std::move(title);
  group_call->pending_record_record_video = record_video;
  group_call->pending_record_use_portrait_orientation = use_portrait_orientation;
  group_call->toggle_recording_generation = ++toggle_recording_generation_;
  send_update_group_call(group_call, "toggle_group_call_recording");
  promise.set_value(Unit());
}

void GroupCallManager::send_toggle_group_call_recording_query(InputGroupCallId input_group_call_id, bool is_enabled,
                                                              const string &title, bool record_video,
                                                              bool use_portrait_orientation, uint64 generation) {
  auto promise =
      PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, generation](Result<Unit> result) {
        send_closure(actor_id, &GroupCallManager::on_toggle_group_call_recording, input_group_call_id, generation,
                     std::move(result));
      });
  td_->create_handler<ToggleGroupCallRecordQuery>(std::move(promise))
      ->send(input_group_call_id, is_enabled, title, record_video, use_portrait_orientation);
}

void GroupCallManager::on_toggle_group_call_recording(InputGroupCallId input_group_call_id, uint64 generation,
                                                      Result<Unit> &&result) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call)) {
    return;
  }

  CHECK(group_call->have_pending_record_start_date);

  if (group_call->toggle_recording_generation != generation && group_call->can_be_managed) {
    // need to send another request
    send_toggle_group_call_recording_query(input_group_call_id, group_call->pending_record_start_date != 0,
                                           group_call->pending_record_title, group_call->pending_record_record_video,
                                           group_call->pending_record_use_portrait_orientation,
                                           group_call->toggle_recording_generation);
    return;
  }

  auto current_record_start_date = get_group_call_record_start_date(group_call);
  auto current_is_video_recorded = get_group_call_is_video_recorded(group_call);
  group_call->have_pending_record_start_date = false;
  if (current_record_start_date != get_group_call_record_start_date(group_call) ||
      current_is_video_recorded != get_group_call_is_video_recorded(group_call)) {
    send_update_group_call(group_call, "on_toggle_group_call_recording");
  }
}

void GroupCallManager::set_group_call_participant_is_speaking(GroupCallId group_call_id, int32 audio_source,
                                                              bool is_speaking, Promise<Unit> &&promise, int32 date) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call)) {
    return promise.set_value(Unit());
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, audio_source, is_speaking,
                                  promise = std::move(promise), date](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_value(Unit());
            } else {
              send_closure(actor_id, &GroupCallManager::set_group_call_participant_is_speaking, group_call_id,
                           audio_source, is_speaking, std::move(promise), date);
            }
          }));
      return;
    }
    return promise.set_value(Unit());
  }
  if (audio_source == 0) {
    audio_source = group_call->audio_source;
    if (audio_source == 0) {
      return promise.set_error(Status::Error(400, "Can't speak without joining the group call"));
    }
  }

  bool is_recursive = false;
  if (date == 0) {
    date = G()->unix_time();
  } else {
    is_recursive = true;
  }
  if (group_call->audio_source != 0 && audio_source != group_call->audio_source && !is_recursive && is_speaking &&
      check_group_call_is_joined_timeout_.has_timeout(group_call_id.get())) {
    check_group_call_is_joined_timeout_.set_timeout_in(group_call_id.get(), CHECK_GROUP_CALL_IS_JOINED_TIMEOUT);
  }
  DialogId dialog_id =
      set_group_call_participant_is_speaking_by_source(input_group_call_id, audio_source, is_speaking, date);
  if (!dialog_id.is_valid()) {
    if (!is_recursive) {
      auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, audio_source, is_speaking,
                                                   promise = std::move(promise), date](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          promise.set_value(Unit());
        } else {
          send_closure(actor_id, &GroupCallManager::set_group_call_participant_is_speaking, group_call_id, audio_source,
                       is_speaking, std::move(promise), date);
        }
      });
      td_->create_handler<GetGroupCallParticipantQuery>(std::move(query_promise))
          ->send(input_group_call_id, {}, {audio_source});
    } else {
      LOG(INFO) << "Failed to find participant with source " << audio_source << " in " << group_call_id << " from "
                << group_call->dialog_id;
      promise.set_value(Unit());
    }
    return;
  }

  if (is_speaking) {
    on_user_speaking_in_group_call(group_call_id, dialog_id, date, false, is_recursive);
  }

  if (group_call->audio_source == audio_source && group_call->is_speaking != is_speaking) {
    group_call->is_speaking = is_speaking;
    if (is_speaking && group_call->dialog_id.is_valid()) {
      pending_send_speaking_action_timeout_.add_timeout_in(group_call_id.get(), 0.0);
    }
  }

  promise.set_value(Unit());
}

void GroupCallManager::toggle_group_call_participant_is_muted(GroupCallId group_call_id, DialogId dialog_id,
                                                              bool is_muted, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || group_call->is_being_left) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, dialog_id, is_muted,
                                  promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::toggle_group_call_participant_is_muted, group_call_id,
                           dialog_id, is_muted, std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  auto participants = add_group_call_participants(input_group_call_id, "toggle_group_call_participant_is_muted");
  auto participant = get_group_call_participant(participants, dialog_id);
  if (participant == nullptr) {
    return promise.set_error(Status::Error(400, "Can't find group call participant"));
  }
  dialog_id = participant->dialog_id;

  bool can_manage = can_manage_group_call(input_group_call_id);
  bool is_admin = td::contains(participants->administrator_dialog_ids, dialog_id);

  auto participant_copy = *participant;
  if (!participant_copy.set_pending_is_muted(is_muted, can_manage, is_admin)) {
    return promise.set_error(Status::Error(400, PSLICE() << "Can't " << (is_muted ? "" : "un") << "mute user"));
  }
  if (participant_copy == *participant) {
    return promise.set_value(Unit());
  }
  *participant = std::move(participant_copy);

  participant->pending_is_muted_generation = ++toggle_is_muted_generation_;
  if (participant->order.is_valid()) {
    send_update_group_call_participant(input_group_call_id, *participant, "toggle_group_call_participant_is_muted");
  }

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, dialog_id,
                                               generation = participant->pending_is_muted_generation,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
      promise = Promise<Unit>();
    }
    send_closure(actor_id, &GroupCallManager::on_toggle_group_call_participant_is_muted, input_group_call_id, dialog_id,
                 generation, std::move(promise));
  });
  td_->create_handler<EditGroupCallParticipantQuery>(std::move(query_promise))
      ->send(input_group_call_id, dialog_id, true, is_muted, 0, false, false, false, false, false, false, false, false);
}

void GroupCallManager::on_toggle_group_call_participant_is_muted(InputGroupCallId input_group_call_id,
                                                                 DialogId dialog_id, uint64 generation,
                                                                 Promise<Unit> &&promise) {
  if (G()->close_flag()) {
    return promise.set_value(Unit());
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || group_call->is_being_left || !group_call->is_joined) {
    return promise.set_value(Unit());
  }

  auto participants = add_group_call_participants(input_group_call_id, "on_toggle_group_call_participant_is_muted");
  auto participant = get_group_call_participant(participants, dialog_id);
  if (participant == nullptr || participant->pending_is_muted_generation != generation) {
    return promise.set_value(Unit());
  }

  CHECK(participant->have_pending_is_muted);
  participant->have_pending_is_muted = false;
  bool can_manage = can_manage_group_call(input_group_call_id);
  if (update_group_call_participant_can_be_muted(can_manage, participants, *participant) ||
      participant->server_is_muted_by_themselves != participant->pending_is_muted_by_themselves ||
      participant->server_is_muted_by_admin != participant->pending_is_muted_by_admin ||
      participant->server_is_muted_locally != participant->pending_is_muted_locally) {
    LOG(ERROR) << "Failed to mute/unmute " << dialog_id << " in " << input_group_call_id;
    if (participant->order.is_valid()) {
      send_update_group_call_participant(input_group_call_id, *participant,
                                         "on_toggle_group_call_participant_is_muted");
    }
  }
  promise.set_value(Unit());
}

void GroupCallManager::set_group_call_participant_volume_level(GroupCallId group_call_id, DialogId dialog_id,
                                                               int32 volume_level, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));
  if (volume_level < GroupCallParticipant::MIN_VOLUME_LEVEL || volume_level > GroupCallParticipant::MAX_VOLUME_LEVEL) {
    return promise.set_error(Status::Error(400, "Wrong volume level specified"));
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || group_call->is_being_left) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, dialog_id, volume_level,
                                  promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::set_group_call_participant_volume_level, group_call_id,
                           dialog_id, volume_level, std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  auto participant =
      get_group_call_participant(input_group_call_id, dialog_id, "set_group_call_participant_volume_level");
  if (participant == nullptr) {
    return promise.set_error(Status::Error(400, "Can't find group call participant"));
  }
  dialog_id = participant->dialog_id;

  if (participant->is_self) {
    return promise.set_error(Status::Error(400, "Can't change self volume level"));
  }

  if (participant->get_volume_level() == volume_level) {
    return promise.set_value(Unit());
  }

  participant->pending_volume_level = volume_level;
  participant->pending_volume_level_generation = ++set_volume_level_generation_;
  if (participant->order.is_valid()) {
    send_update_group_call_participant(input_group_call_id, *participant, "set_group_call_participant_volume_level");
  }

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, dialog_id,
                                               generation = participant->pending_volume_level_generation,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
      promise = Promise<Unit>();
    }
    send_closure(actor_id, &GroupCallManager::on_set_group_call_participant_volume_level, input_group_call_id,
                 dialog_id, generation, std::move(promise));
  });
  td_->create_handler<EditGroupCallParticipantQuery>(std::move(query_promise))
      ->send(input_group_call_id, dialog_id, false, false, volume_level, false, false, false, false, false, false,
             false, false);
}

void GroupCallManager::on_set_group_call_participant_volume_level(InputGroupCallId input_group_call_id,
                                                                  DialogId dialog_id, uint64 generation,
                                                                  Promise<Unit> &&promise) {
  if (G()->close_flag()) {
    return promise.set_value(Unit());
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || group_call->is_being_left || !group_call->is_joined) {
    return promise.set_value(Unit());
  }

  auto participant =
      get_group_call_participant(input_group_call_id, dialog_id, "on_set_group_call_participant_volume_level");
  if (participant == nullptr || participant->pending_volume_level_generation != generation) {
    return promise.set_value(Unit());
  }

  CHECK(participant->pending_volume_level != 0);
  if (participant->volume_level != participant->pending_volume_level) {
    LOG(ERROR) << "Failed to set volume level of " << dialog_id << " in " << input_group_call_id;
    participant->pending_volume_level = 0;
    if (participant->order.is_valid()) {
      send_update_group_call_participant(input_group_call_id, *participant,
                                         "on_set_group_call_participant_volume_level");
    }
  } else {
    participant->pending_volume_level = 0;
  }
  promise.set_value(Unit());
}

void GroupCallManager::toggle_group_call_participant_is_hand_raised(GroupCallId group_call_id, DialogId dialog_id,
                                                                    bool is_hand_raised, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || group_call->is_being_left) {
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  if (!group_call->is_joined) {
    if (group_call->is_being_joined || group_call->need_rejoin) {
      group_call->after_join.push_back(
          PromiseCreator::lambda([actor_id = actor_id(this), group_call_id, dialog_id, is_hand_raised,
                                  promise = std::move(promise)](Result<Unit> &&result) mutable {
            if (result.is_error()) {
              promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
            } else {
              send_closure(actor_id, &GroupCallManager::toggle_group_call_participant_is_hand_raised, group_call_id,
                           dialog_id, is_hand_raised, std::move(promise));
            }
          }));
      return;
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }

  auto participants = add_group_call_participants(input_group_call_id, "toggle_group_call_participant_is_hand_raised");
  auto participant = get_group_call_participant(participants, dialog_id);
  if (participant == nullptr) {
    return promise.set_error(Status::Error(400, "Can't find group call participant"));
  }
  dialog_id = participant->dialog_id;

  if (is_hand_raised == participant->get_is_hand_raised()) {
    return promise.set_value(Unit());
  }

  if (!participant->is_self) {
    if (is_hand_raised) {
      return promise.set_error(Status::Error(400, "Can't raise others hand"));
    } else {
      if (!can_manage_group_call(input_group_call_id)) {
        return promise.set_error(Status::Error(400, "Have not enough rights in the group call"));
      }
    }
  }

  participant->have_pending_is_hand_raised = true;
  participant->pending_is_hand_raised = is_hand_raised;
  participant->pending_is_hand_raised_generation = ++toggle_is_hand_raised_generation_;
  if (participant->order.is_valid()) {
    send_update_group_call_participant(input_group_call_id, *participant,
                                       "toggle_group_call_participant_is_hand_raised");
  }

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, dialog_id,
                                               generation = participant->pending_is_hand_raised_generation,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
      promise = Promise<Unit>();
    }
    send_closure(actor_id, &GroupCallManager::on_toggle_group_call_participant_is_hand_raised, input_group_call_id,
                 dialog_id, generation, std::move(promise));
  });
  td_->create_handler<EditGroupCallParticipantQuery>(std::move(query_promise))
      ->send(input_group_call_id, dialog_id, false, false, 0, true, is_hand_raised, false, false, false, false, false,
             false);
}

void GroupCallManager::on_toggle_group_call_participant_is_hand_raised(InputGroupCallId input_group_call_id,
                                                                       DialogId dialog_id, uint64 generation,
                                                                       Promise<Unit> &&promise) {
  if (G()->close_flag()) {
    return promise.set_value(Unit());
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || group_call->is_being_left || !group_call->is_joined) {
    return promise.set_value(Unit());
  }

  auto participant =
      get_group_call_participant(input_group_call_id, dialog_id, "on_toggle_group_call_participant_is_hand_raised");
  if (participant == nullptr || participant->pending_is_hand_raised_generation != generation) {
    return promise.set_value(Unit());
  }

  CHECK(participant->have_pending_is_hand_raised);
  participant->have_pending_is_hand_raised = false;
  if (participant->get_is_hand_raised() != participant->pending_is_hand_raised) {
    LOG(ERROR) << "Failed to change raised hand state for " << dialog_id << " in " << input_group_call_id;
    if (participant->order.is_valid()) {
      send_update_group_call_participant(input_group_call_id, *participant,
                                         "on_toggle_group_call_participant_is_hand_raised");
    }
  }
  promise.set_value(Unit());
}

void GroupCallManager::load_group_call_participants(GroupCallId group_call_id, int32 limit, Promise<Unit> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }

  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!need_group_call_participants(group_call)) {
    return promise.set_error(Status::Error(400, "Can't load group call participants"));
  }
  CHECK(group_call != nullptr && group_call->is_inited);
  if (group_call->loaded_all_participants) {
    return promise.set_value(Unit());
  }

  string next_offset;
  auto participants_it = group_call_participants_.find(input_group_call_id);
  if (participants_it != group_call_participants_.end()) {
    CHECK(participants_it->second != nullptr);
    next_offset = participants_it->second->next_offset;
  }
  if (limit == 1 && next_offset.empty()) {
    // prevent removing self as the first user and deducing that there are no more participants
    limit = 2;
  }
  td_->create_handler<GetGroupCallParticipantsQuery>(std::move(promise))
      ->send(input_group_call_id, std::move(next_offset), limit);
}

void GroupCallManager::leave_group_call(GroupCallId group_call_id, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));

  auto *group_call = get_group_call(input_group_call_id);
  if (!is_group_call_active(group_call) || group_call->is_being_left || !group_call->is_joined) {
    if (group_call != nullptr) {
      bool old_is_joined = get_group_call_is_joined(group_call);
      if (cancel_join_group_call_request(input_group_call_id, group_call) != 0) {
        if (try_clear_group_call_participants(input_group_call_id) ||
            old_is_joined != get_group_call_is_joined(group_call)) {
          send_update_group_call(group_call, "leave_group_call 1");
        }
        process_group_call_after_join_requests(input_group_call_id, "leave_group_call 1");
        return promise.set_value(Unit());
      }
    }
    if (group_call != nullptr && group_call->need_rejoin) {
      group_call->need_rejoin = false;
      send_update_group_call(group_call, "leave_group_call");
      if (try_clear_group_call_participants(input_group_call_id)) {
        send_update_group_call(group_call, "leave_group_call 2");
      }
      process_group_call_after_join_requests(input_group_call_id, "leave_group_call 2");
      return promise.set_value(Unit());
    }
    return promise.set_error(Status::Error(400, "GROUPCALL_JOIN_MISSING"));
  }
  auto audio_source = cancel_join_group_call_request(input_group_call_id, group_call);
  if (audio_source == 0) {
    audio_source = group_call->audio_source;
  }
  group_call->is_being_left = true;
  group_call->need_rejoin = false;
  group_call->pending_is_my_video_enabled = false;
  group_call->have_pending_is_my_video_enabled = true;
  group_call->is_my_video_paused = false;
  group_call->have_pending_is_my_video_paused = true;
  try_clear_group_call_participants(input_group_call_id);
  send_update_group_call(group_call, "leave_group_call");

  process_group_call_after_join_requests(input_group_call_id, "leave_group_call 3");

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), input_group_call_id, audio_source,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_ok()) {
      // just in case
      send_closure(actor_id, &GroupCallManager::on_group_call_left, input_group_call_id, audio_source, false);
    }
    promise.set_result(std::move(result));
  });
  td_->create_handler<LeaveGroupCallQuery>(std::move(query_promise))->send(input_group_call_id, audio_source);
}

void GroupCallManager::on_group_call_left(InputGroupCallId input_group_call_id, int32 audio_source, bool need_rejoin) {
  if (G()->close_flag()) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  if (group_call->is_joined && group_call->audio_source == audio_source) {
    on_group_call_left_impl(group_call, need_rejoin, "on_group_call_left");
    send_update_group_call(group_call, "on_group_call_left");
  }
}

void GroupCallManager::on_group_call_left_impl(GroupCall *group_call, bool need_rejoin, const char *source) {
  CHECK(group_call != nullptr && group_call->is_inited && group_call->is_joined);
  LOG(INFO) << "Leave " << group_call->group_call_id << " in " << group_call->dialog_id
            << " with need_rejoin = " << need_rejoin << " from " << source;
  group_call->is_joined = false;
  group_call->need_rejoin = need_rejoin && !group_call->is_being_left;
  if (group_call->need_rejoin && group_call->dialog_id.is_valid()) {
    auto dialog_id = group_call->dialog_id;
    if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read) ||
        (dialog_id.get_type() == DialogType::Chat &&
         !td_->chat_manager_->get_chat_status(dialog_id.get_chat_id()).is_member())) {
      group_call->need_rejoin = false;
    }
  }
  group_call->is_being_left = false;
  group_call->is_speaking = false;
  group_call->is_my_video_paused = false;
  group_call->is_my_video_enabled = false;
  group_call->is_my_presentation_paused = false;
  group_call->have_pending_is_my_video_enabled = false;
  group_call->have_pending_is_my_video_paused = false;
  if (!group_call->is_active) {
    group_call->can_be_managed = false;
  }
  group_call->joined_date = 0;
  group_call->audio_source = 0;
  check_group_call_is_joined_timeout_.cancel_timeout(group_call->group_call_id.get());
  auto input_group_call_id = get_input_group_call_id(group_call->group_call_id).ok();
  try_clear_group_call_participants(input_group_call_id);
  if (!group_call->need_rejoin) {
    if (group_call->is_being_joined) {
      LOG(ERROR) << "Left a being joined group call. Did you change audio_source_id without leaving the group call?";
    } else {
      process_group_call_after_join_requests(input_group_call_id, "on_group_call_left_impl");
    }
  }
}

void GroupCallManager::discard_group_call(GroupCallId group_call_id, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_group_call_id, get_input_group_call_id(group_call_id));
  td_->create_handler<DiscardGroupCallQuery>(std::move(promise))->send(input_group_call_id);
}

void GroupCallManager::on_update_group_call_connection(string &&connection_params) {
  if (!pending_group_call_join_params_.empty()) {
    LOG(ERROR) << "Receive duplicate connection params";
  }
  pending_group_call_join_params_ = std::move(connection_params);
}

void GroupCallManager::on_update_group_call(tl_object_ptr<telegram_api::GroupCall> group_call_ptr, DialogId dialog_id) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  if (dialog_id != DialogId() && !dialog_id.is_valid()) {
    LOG(ERROR) << "Receive " << to_string(group_call_ptr) << " in invalid " << dialog_id;
    dialog_id = DialogId();
  }
  auto input_group_call_id = update_group_call(group_call_ptr, dialog_id);
  if (input_group_call_id.is_valid()) {
    LOG(INFO) << "Update " << input_group_call_id << " from " << dialog_id;
  } else {
    LOG(ERROR) << "Receive invalid " << to_string(group_call_ptr);
  }
}

bool GroupCallManager::try_clear_group_call_participants(InputGroupCallId input_group_call_id) {
  auto group_call = get_group_call(input_group_call_id);
  if (need_group_call_participants(group_call)) {
    return false;
  }
  if (group_call != nullptr) {
    update_group_call_participant_order_timeout_.cancel_timeout(group_call->group_call_id.get());
    remove_recent_group_call_speaker(input_group_call_id, group_call->as_dialog_id);
  }

  auto participants_it = group_call_participants_.find(input_group_call_id);
  if (participants_it == group_call_participants_.end()) {
    return false;
  }

  auto participants = std::move(participants_it->second);
  CHECK(participants != nullptr);
  group_call_participants_.erase(participants_it);

  CHECK(group_call != nullptr && group_call->is_inited);
  LOG(INFO) << "Clear participants in " << input_group_call_id << " from " << group_call->dialog_id;
  bool need_update = false;
  if (group_call->loaded_all_participants) {
    group_call->loaded_all_participants = false;
    need_update = true;
  }
  group_call->leave_version = group_call->version;
  group_call->version = -1;

  for (auto &participant : participants->participants) {
    if (participant.order.is_valid()) {
      CHECK(participant.order >= participants->min_order);
      participant.order = GroupCallParticipantOrder();
      send_update_group_call_participant(input_group_call_id, participant, "try_clear_group_call_participants 1");

      if (participant.is_self) {
        need_update |= set_group_call_participant_count(group_call, group_call->participant_count - 1,
                                                        "try_clear_group_call_participants 2");
        if (participant.get_has_video()) {
          need_update |= set_group_call_unmuted_video_count(group_call, group_call->unmuted_video_count - 1,
                                                            "try_clear_group_call_participants 3");
        }
      }
    }
    on_remove_group_call_participant(input_group_call_id, participant.dialog_id);
  }
  participants->local_unmuted_video_count = 0;

  if (group_call_participants_.empty()) {
    CHECK(participant_id_to_group_call_id_.empty());
  }
  return need_update;
}

InputGroupCallId GroupCallManager::update_group_call(const tl_object_ptr<telegram_api::GroupCall> &group_call_ptr,
                                                     DialogId dialog_id) {
  CHECK(group_call_ptr != nullptr);

  InputGroupCallId input_group_call_id;
  GroupCall call;
  call.is_inited = true;

  switch (group_call_ptr->get_id()) {
    case telegram_api::groupCall::ID: {
      auto group_call = static_cast<const telegram_api::groupCall *>(group_call_ptr.get());
      input_group_call_id = InputGroupCallId(group_call->id_, group_call->access_hash_);
      call.is_active = true;
      call.is_rtmp_stream = group_call->rtmp_stream_;
      call.has_hidden_listeners = group_call->listeners_hidden_;
      call.title = group_call->title_;
      call.start_subscribed = group_call->schedule_start_subscribed_;
      call.mute_new_participants = group_call->join_muted_;
      call.joined_date_asc = group_call->join_date_asc_;
      call.allowed_toggle_mute_new_participants = group_call->can_change_join_muted_;
      call.participant_count = group_call->participants_count_;
      call.unmuted_video_count = group_call->unmuted_video_count_;
      call.unmuted_video_limit = group_call->unmuted_video_limit_;
      if ((group_call->flags_ & telegram_api::groupCall::STREAM_DC_ID_MASK) != 0) {
        call.stream_dc_id = DcId::create(group_call->stream_dc_id_);
        if (!call.stream_dc_id.is_exact()) {
          LOG(ERROR) << "Receive invalid stream DC ID " << call.stream_dc_id << " in " << input_group_call_id;
          call.stream_dc_id = DcId();
        }
      } else {
        call.stream_dc_id = DcId();
      }
      if ((group_call->flags_ & telegram_api::groupCall::RECORD_START_DATE_MASK) != 0) {
        call.record_start_date = group_call->record_start_date_;
        call.is_video_recorded = group_call->record_video_active_;
        if (call.record_start_date <= 0) {
          LOG(ERROR) << "Receive invalid record start date " << group_call->record_start_date_ << " in "
                     << input_group_call_id;
          call.record_start_date = 0;
          call.is_video_recorded = false;
        }
      } else {
        call.record_start_date = 0;
        call.is_video_recorded = false;
      }
      if ((group_call->flags_ & telegram_api::groupCall::SCHEDULE_DATE_MASK) != 0) {
        call.scheduled_start_date = group_call->schedule_date_;
        if (call.scheduled_start_date <= 0) {
          LOG(ERROR) << "Receive invalid scheduled start date " << group_call->schedule_date_ << " in "
                     << input_group_call_id;
          call.scheduled_start_date = 0;
        }
      } else {
        call.scheduled_start_date = 0;
      }
      if (call.scheduled_start_date == 0) {
        call.start_subscribed = false;
      }
      call.call_id = td_->call_manager_->get_call_id(group_call->conference_from_call_);

      call.version = group_call->version_;
      call.title_version = group_call->version_;
      call.can_enable_video_version = group_call->version_;
      call.start_subscribed_version = group_call->version_;
      call.mute_version = group_call->version_;
      call.stream_dc_id_version = group_call->version_;
      call.record_start_date_version = group_call->version_;
      call.scheduled_start_date_version = group_call->version_;
      break;
    }
    case telegram_api::groupCallDiscarded::ID: {
      auto group_call = static_cast<const telegram_api::groupCallDiscarded *>(group_call_ptr.get());
      input_group_call_id = InputGroupCallId(group_call->id_, group_call->access_hash_);
      call.duration = group_call->duration_;
      finish_join_group_call(input_group_call_id, 0, Status::Error(400, "Group call ended"));
      break;
    }
    default:
      UNREACHABLE();
  }
  if (!input_group_call_id.is_valid() || call.participant_count < 0) {
    return {};
  }

  string join_params = std::move(pending_group_call_join_params_);
  pending_group_call_join_params_.clear();

  bool need_update = false;
  auto *group_call = add_group_call(input_group_call_id, dialog_id);
  call.group_call_id = group_call->group_call_id;
  call.dialog_id = dialog_id.is_valid() ? dialog_id : group_call->dialog_id;
  call.can_be_managed = call.is_active && can_manage_group_calls(call.dialog_id).is_ok();
  call.can_self_unmute = call.is_active && (!call.mute_new_participants || call.can_be_managed);
  if (!group_call->dialog_id.is_valid()) {
    group_call->dialog_id = dialog_id;
  }
  if (call.is_active && join_params.empty() && !group_call->is_joined &&
      (group_call->need_rejoin || group_call->is_being_joined)) {
    call.participant_count++;
  }
  LOG(INFO) << "Update " << call.group_call_id << " with " << group_call->participant_count
            << " participants and version " << group_call->version;
  if (!group_call->is_inited) {
    call.is_joined = group_call->is_joined;
    call.need_rejoin = group_call->need_rejoin;
    call.is_being_left = group_call->is_being_left;
    call.is_speaking = group_call->is_speaking;
    call.is_my_video_paused = group_call->is_my_video_paused;
    call.is_my_video_enabled = group_call->is_my_video_enabled;
    call.is_my_presentation_paused = group_call->is_my_presentation_paused;
    call.syncing_participants = group_call->syncing_participants;
    call.need_syncing_participants = group_call->need_syncing_participants;
    call.loaded_all_participants = group_call->loaded_all_participants;
    call.audio_source = group_call->audio_source;
    call.as_dialog_id = group_call->as_dialog_id;
    *group_call = std::move(call);

    need_update = true;
    if (need_group_call_participants(group_call)) {
      if (process_pending_group_call_participant_updates(input_group_call_id)) {
        need_update = false;
      }
      try_load_group_call_administrators(input_group_call_id, group_call->dialog_id);
    } else {
      group_call->version = -1;
    }
  } else {
    if (!group_call->is_active) {
      // never update ended calls
    } else if (!call.is_active) {
      // always update to an ended call, dropping also is_joined, is_speaking and other local flags
      fail_promises(group_call->after_join, Status::Error(400, "Group call ended"));
      *group_call = std::move(call);
      need_update = true;
    } else {
      if (call.is_rtmp_stream != group_call->is_rtmp_stream) {
        group_call->is_rtmp_stream = call.is_rtmp_stream;
        need_update = true;
      }
      if (call.has_hidden_listeners != group_call->has_hidden_listeners) {
        group_call->has_hidden_listeners = call.has_hidden_listeners;
        need_update = true;
      }
      if ((call.unmuted_video_count != group_call->unmuted_video_count ||
           call.unmuted_video_limit != group_call->unmuted_video_limit) &&
          call.can_enable_video_version >= group_call->can_enable_video_version) {
        auto old_can_enable_video = get_group_call_can_enable_video(group_call);
        group_call->unmuted_video_count = call.unmuted_video_count;
        group_call->unmuted_video_limit = call.unmuted_video_limit;
        group_call->can_enable_video_version = call.can_enable_video_version;
        if (old_can_enable_video != get_group_call_can_enable_video(group_call)) {
          need_update = true;
        }
      }
      if (call.start_subscribed != group_call->start_subscribed &&
          call.start_subscribed_version >= group_call->start_subscribed_version) {
        auto old_start_subscribed = get_group_call_start_subscribed(group_call);
        group_call->start_subscribed = call.start_subscribed;
        group_call->start_subscribed_version = call.start_subscribed_version;
        if (old_start_subscribed != get_group_call_start_subscribed(group_call)) {
          need_update = true;
        }
      }
      auto mute_flags_changed =
          call.mute_new_participants != group_call->mute_new_participants ||
          call.allowed_toggle_mute_new_participants != group_call->allowed_toggle_mute_new_participants;
      if (mute_flags_changed && call.mute_version >= group_call->mute_version) {
        auto old_mute_new_participants = get_group_call_mute_new_participants(group_call);
        need_update |= (call.allowed_toggle_mute_new_participants && call.can_be_managed) !=
                       (group_call->allowed_toggle_mute_new_participants && group_call->can_be_managed);
        group_call->mute_new_participants = call.mute_new_participants;
        group_call->allowed_toggle_mute_new_participants = call.allowed_toggle_mute_new_participants;
        group_call->mute_version = call.mute_version;
        if (old_mute_new_participants != get_group_call_mute_new_participants(group_call)) {
          need_update = true;
        }
      }
      if (call.title != group_call->title && call.title_version >= group_call->title_version) {
        string old_group_call_title = get_group_call_title(group_call);
        group_call->title = std::move(call.title);
        group_call->title_version = call.title_version;
        if (old_group_call_title != get_group_call_title(group_call)) {
          need_update = true;
        }
      }
      if (call.can_be_managed != group_call->can_be_managed) {
        group_call->can_be_managed = call.can_be_managed;
        need_update = true;
      }
      if (call.stream_dc_id != group_call->stream_dc_id &&
          call.stream_dc_id_version >= group_call->stream_dc_id_version) {
        group_call->stream_dc_id = call.stream_dc_id;
        group_call->stream_dc_id_version = call.stream_dc_id_version;
      }
      // flag call.joined_date_asc must not change
      if ((call.record_start_date != group_call->record_start_date ||
           call.is_video_recorded != group_call->is_video_recorded) &&
          call.record_start_date_version >= group_call->record_start_date_version) {
        int32 old_record_start_date = get_group_call_record_start_date(group_call);
        bool old_is_video_recorded = get_group_call_is_video_recorded(group_call);
        group_call->record_start_date = call.record_start_date;
        group_call->is_video_recorded = call.is_video_recorded;
        group_call->record_start_date_version = call.record_start_date_version;
        if (old_record_start_date != get_group_call_record_start_date(group_call) ||
            old_is_video_recorded != get_group_call_is_video_recorded(group_call)) {
          need_update = true;
        }
      }
      if (call.scheduled_start_date != group_call->scheduled_start_date &&
          call.scheduled_start_date_version >= group_call->scheduled_start_date_version) {
        LOG_IF(ERROR, group_call->scheduled_start_date == 0) << input_group_call_id << " became scheduled";
        group_call->scheduled_start_date = call.scheduled_start_date;
        group_call->scheduled_start_date_version = call.scheduled_start_date_version;
        need_update = true;
      }
      if (call.version > group_call->version) {
        if (group_call->version != -1) {
          // if we know group call version, then update participants only by corresponding updates
          on_receive_group_call_version(input_group_call_id, call.version);
        } else {
          need_update |= set_group_call_participant_count(group_call, call.participant_count, "update_group_call");
          if (need_group_call_participants(group_call) && !join_params.empty() && group_call->version == -1) {
            LOG(INFO) << "Init " << call.group_call_id << " version to " << call.version;
            group_call->version = call.version;
            if (process_pending_group_call_participant_updates(input_group_call_id)) {
              need_update = false;
            }
          }
        }
      } else if (call.version == group_call->version) {
        set_group_call_participant_count(group_call, call.participant_count, "update_group_call fix");
        need_update = true;
      }
    }
  }
  if (!group_call->is_active && group_call_recent_speakers_.erase(group_call->group_call_id) != 0) {
    need_update = true;
  }
  if (!join_params.empty()) {
    need_update |= on_join_group_call_response(input_group_call_id, std::move(join_params));
  }
  update_group_call_dialog(group_call, "update_group_call", false);  // must be after join response is processed
  need_update |= try_clear_group_call_participants(input_group_call_id);
  if (need_update) {
    send_update_group_call(group_call, "update_group_call");
  }
  return input_group_call_id;
}

void GroupCallManager::on_receive_group_call_version(InputGroupCallId input_group_call_id, int32 version,
                                                     bool immediate_sync) {
  auto *group_call = get_group_call(input_group_call_id);
  if (!need_group_call_participants(group_call)) {
    return;
  }
  CHECK(group_call != nullptr && group_call->is_inited);
  if (group_call->version == -1) {
    return;
  }
  if (version <= group_call->version) {
    return;
  }
  if (group_call->syncing_participants) {
    return;
  }

  // found a gap
  LOG(INFO) << "Receive version " << version << " for group call " << input_group_call_id;
  auto *group_call_participants = add_group_call_participants(input_group_call_id, "on_receive_group_call_version");
  group_call_participants->pending_version_updates_[version];  // reserve place for updates
  if (immediate_sync) {
    sync_participants_timeout_.set_timeout_in(group_call->group_call_id.get(), 0.0);
  } else {
    sync_participants_timeout_.add_timeout_in(group_call->group_call_id.get(), 1.0);
  }
}

void GroupCallManager::on_participant_speaking_in_group_call(InputGroupCallId input_group_call_id,
                                                             const GroupCallParticipant &participant) {
  auto active_date = td::max(participant.active_date, participant.joined_date - 60);
  if (active_date < G()->unix_time() - RECENT_SPEAKER_TIMEOUT) {
    return;
  }

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr) {
    return;
  }

  on_user_speaking_in_group_call(group_call->group_call_id, participant.dialog_id, participant.server_is_muted_by_admin,
                                 active_date, !participant.is_min);
}

void GroupCallManager::on_user_speaking_in_group_call(GroupCallId group_call_id, DialogId dialog_id,
                                                      bool is_muted_by_admin, int32 date, bool is_recursive) {
  if (G()->close_flag()) {
    return;
  }
  if (date < G()->unix_time() - RECENT_SPEAKER_TIMEOUT) {
    return;
  }

  auto input_group_call_id = get_input_group_call_id(group_call_id).move_as_ok();

  auto *group_call = get_group_call(input_group_call_id);
  if (group_call != nullptr && group_call->is_inited && !group_call->is_active) {
    return;
  }
  if (group_call->has_hidden_listeners && is_muted_by_admin) {
    return;
  }

  if (!td_->dialog_manager_->have_dialog_info_force(dialog_id, "on_user_speaking_in_group_call") ||
      (!is_recursive && need_group_call_participants(group_call) &&
       get_group_call_participant(input_group_call_id, dialog_id, "on_user_speaking_in_group_call") == nullptr)) {
    if (is_recursive) {
      LOG(ERROR) << "Failed to find speaking " << dialog_id << " from " << input_group_call_id;
    } else {
      auto query_promise = PromiseCreator::lambda(
          [actor_id = actor_id(this), group_call_id, dialog_id, is_muted_by_admin, date](Result<Unit> &&result) {
            if (!G()->close_flag() && result.is_ok()) {
              send_closure(actor_id, &GroupCallManager::on_user_speaking_in_group_call, group_call_id, dialog_id,
                           is_muted_by_admin, date, true);
            }
          });
      vector<tl_object_ptr<telegram_api::InputPeer>> input_peers;
      input_peers.push_back(DialogManager::get_input_peer_force(dialog_id));
      td_->create_handler<GetGroupCallParticipantQuery>(std::move(query_promise))
          ->send(input_group_call_id, std::move(input_peers), {});
    }
    return;
  }

  LOG(INFO) << "Add " << dialog_id << " as recent speaker at " << date << " in " << input_group_call_id;
  auto &recent_speakers = group_call_recent_speakers_[group_call_id];
  if (recent_speakers == nullptr) {
    recent_speakers = make_unique<GroupCallRecentSpeakers>();
  }

  for (size_t i = 0; i < recent_speakers->users.size(); i++) {
    if (recent_speakers->users[i].first == dialog_id) {
      if (recent_speakers->users[i].second >= date) {
        LOG(INFO) << "Ignore outdated speaking information";
        return;
      }
      recent_speakers->users[i].second = date;
      while (i > 0 && recent_speakers->users[i - 1].second < date) {
        std::swap(recent_speakers->users[i - 1], recent_speakers->users[i]);
        i--;
      }
      on_group_call_recent_speakers_updated(group_call, recent_speakers.get());
      return;
    }
  }

  for (size_t i = 0; i <= recent_speakers->users.size(); i++) {
    if (i == recent_speakers->users.size() || recent_speakers->users[i].second <= date) {
      if (dialog_id.get_type() != DialogType::User) {
        td_->dialog_manager_->force_create_dialog(dialog_id, "on_user_speaking_in_group_call", true);
      }
      recent_speakers->users.insert(recent_speakers->users.begin() + i, {dialog_id, date});
      break;
    }
  }
  static constexpr size_t MAX_RECENT_SPEAKERS = 3;
  if (recent_speakers->users.size() > MAX_RECENT_SPEAKERS) {
    recent_speakers->users.pop_back();
  }

  on_group_call_recent_speakers_updated(group_call, recent_speakers.get());
}

void GroupCallManager::remove_recent_group_call_speaker(InputGroupCallId input_group_call_id, DialogId dialog_id) {
  auto *group_call = get_group_call(input_group_call_id);
  if (group_call == nullptr) {
    return;
  }

  auto recent_speakers_it = group_call_recent_speakers_.find(group_call->group_call_id);
  if (recent_speakers_it == group_call_recent_speakers_.end()) {
    return;
  }
  auto &recent_speakers = recent_speakers_it->second;
  CHECK(recent_speakers != nullptr);
  for (size_t i = 0; i < recent_speakers->users.size(); i++) {
    if (recent_speakers->users[i].first == dialog_id) {
      LOG(INFO) << "Remove " << dialog_id << " from recent speakers in " << input_group_call_id << " from "
                << group_call->dialog_id;
      recent_speakers->users.erase(recent_speakers->users.begin() + i);
      on_group_call_recent_speakers_updated(group_call, recent_speakers.get());
      return;
    }
  }
}

void GroupCallManager::on_group_call_recent_speakers_updated(const GroupCall *group_call,
                                                             GroupCallRecentSpeakers *recent_speakers) {
  if (group_call == nullptr || !group_call->is_inited || recent_speakers->is_changed) {
    if (group_call != nullptr) {
      LOG(INFO) << "Don't need to send update of recent speakers in " << group_call->group_call_id << " from "
                << group_call->dialog_id;
    }
    return;
  }

  recent_speakers->is_changed = true;

  LOG(INFO) << "Schedule update of recent speakers in " << group_call->group_call_id << " from "
            << group_call->dialog_id;
  const double MAX_RECENT_SPEAKER_UPDATE_DELAY = 0.5;
  recent_speaker_update_timeout_.set_timeout_in(group_call->group_call_id.get(), MAX_RECENT_SPEAKER_UPDATE_DELAY);
}

DialogId GroupCallManager::set_group_call_participant_is_speaking_by_source(InputGroupCallId input_group_call_id,
                                                                            int32 audio_source, bool is_speaking,
                                                                            int32 date) {
  CHECK(audio_source != 0);
  auto participants_it = group_call_participants_.find(input_group_call_id);
  if (participants_it == group_call_participants_.end()) {
    return DialogId();
  }

  for (auto &participant : participants_it->second->participants) {
    if (participant.audio_source == audio_source || participant.presentation_audio_source == audio_source) {
      if (is_speaking && participant.get_is_muted_by_admin()) {
        // don't allow to show as speaking muted by admin participants
        return DialogId();
      }
      if (participant.is_speaking != is_speaking) {
        participant.is_speaking = is_speaking;
        if (is_speaking) {
          participant.local_active_date = max(participant.local_active_date, date);
        }
        bool can_self_unmute = get_group_call_can_self_unmute(input_group_call_id);
        auto old_order = participant.order;
        participant.order = get_real_participant_order(can_self_unmute, participant, participants_it->second.get());
        if (participant.order.is_valid() || old_order.is_valid()) {
          send_update_group_call_participant(input_group_call_id, participant,
                                             "set_group_call_participant_is_speaking_by_source");
        }
      }

      return participant.dialog_id;
    }
  }
  return DialogId();
}

bool GroupCallManager::set_group_call_participant_count(GroupCall *group_call, int32 count, const char *source,
                                                        bool force_update) {
  CHECK(group_call != nullptr);
  CHECK(group_call->is_inited);
  if (group_call->participant_count == count) {
    return false;
  }

  LOG(DEBUG) << "Set " << group_call->group_call_id << " participant count to " << count << " from " << source;
  auto input_group_call_id = get_input_group_call_id(group_call->group_call_id).ok();
  if (count < 0) {
    LOG(ERROR) << "Participant count became negative in " << group_call->group_call_id << " in "
               << group_call->dialog_id << " from " << source;
    count = 0;
    reload_group_call(input_group_call_id, Auto());
  }

  bool result = false;
  if (need_group_call_participants(group_call)) {
    auto known_participant_count = static_cast<int32>(
        add_group_call_participants(input_group_call_id, "set_group_call_participant_count")->participants.size());
    if (count < known_participant_count) {
      if (group_call->is_joined) {
        LOG(ERROR) << "Participant count became " << count << " from " << source << ", which is less than known "
                   << known_participant_count << " number of participants in " << input_group_call_id << " from "
                   << group_call->dialog_id;
      }
      count = known_participant_count;
    } else if (group_call->loaded_all_participants && !group_call->has_hidden_listeners &&
               count > known_participant_count) {
      if (group_call->joined_date_asc) {
        group_call->loaded_all_participants = false;
        result = true;
      } else {
        count = known_participant_count;
      }
    }
  }

  if (group_call->participant_count == count) {
    return result;
  }

  group_call->participant_count = count;
  update_group_call_dialog(group_call, source, force_update);
  return true;
}

bool GroupCallManager::set_group_call_unmuted_video_count(GroupCall *group_call, int32 count, const char *source) {
  CHECK(group_call != nullptr);
  CHECK(group_call->is_inited);

  auto participants_it = group_call_participants_.find(get_input_group_call_id(group_call->group_call_id).ok());
  if (participants_it != group_call_participants_.end()) {
    auto group_call_participants = participants_it->second.get();
    CHECK(group_call_participants != nullptr);
    CHECK(group_call_participants->local_unmuted_video_count >= 0);
    CHECK(static_cast<size_t>(group_call_participants->local_unmuted_video_count) <=
          group_call_participants->participants.size());
    if (group_call->loaded_all_participants || !group_call_participants->min_order.has_video()) {
      if (group_call_participants->local_unmuted_video_count != count &&
          group_call->unmuted_video_count != group_call_participants->local_unmuted_video_count) {
        LOG(INFO) << "Use local count " << group_call_participants->local_unmuted_video_count
                  << " of unmuted videos instead of " << count;
      }
      count = group_call_participants->local_unmuted_video_count;
    }
  }

  if (count < 0) {
    LOG(ERROR) << "Video participant count became negative in " << group_call->group_call_id << " in "
               << group_call->dialog_id << " from " << source;
    count = 0;
    auto input_group_call_id = get_input_group_call_id(group_call->group_call_id).ok();
    reload_group_call(input_group_call_id, Auto());
  }

  if (group_call->unmuted_video_count == count) {
    return false;
  }

  LOG(DEBUG) << "Set " << group_call->group_call_id << " video participant count to " << count << " from " << source;

  auto old_can_enable_video = get_group_call_can_enable_video(group_call);
  group_call->unmuted_video_count = count;
  return old_can_enable_video != get_group_call_can_enable_video(group_call);
}

void GroupCallManager::update_group_call_dialog(const GroupCall *group_call, const char *source, bool force) {
  CHECK(group_call != nullptr);
  if (!group_call->dialog_id.is_valid()) {
    return;
  }

  td_->messages_manager_->on_update_dialog_group_call(group_call->dialog_id, group_call->is_active,
                                                      group_call->participant_count == 0, source, force);
}

vector<td_api::object_ptr<td_api::groupCallRecentSpeaker>> GroupCallManager::get_recent_speakers(
    const GroupCall *group_call, bool for_update) {
  CHECK(group_call != nullptr && group_call->is_inited);

  auto recent_speakers_it = group_call_recent_speakers_.find(group_call->group_call_id);
  if (recent_speakers_it == group_call_recent_speakers_.end()) {
    return Auto();
  }

  auto *recent_speakers = recent_speakers_it->second.get();
  CHECK(recent_speakers != nullptr);
  LOG(INFO) << "Found " << recent_speakers->users.size() << " recent speakers in " << group_call->group_call_id
            << " from " << group_call->dialog_id;
  auto now = G()->unix_time();
  while (!recent_speakers->users.empty() && recent_speakers->users.back().second < now - RECENT_SPEAKER_TIMEOUT) {
    recent_speakers->users.pop_back();
  }

  vector<std::pair<DialogId, bool>> recent_speaker_users;
  for (auto &recent_speaker : recent_speakers->users) {
    recent_speaker_users.emplace_back(recent_speaker.first, recent_speaker.second > now - 8);
  }

  if (recent_speakers->is_changed) {
    recent_speakers->is_changed = false;
    recent_speaker_update_timeout_.cancel_timeout(group_call->group_call_id.get());
  }
  if (!recent_speaker_users.empty()) {
    auto next_timeout = recent_speakers->users.back().second + RECENT_SPEAKER_TIMEOUT - now + 1;
    if (recent_speaker_users[0].second) {  // if someone is speaking, recheck in 1 second
      next_timeout = 1;
    }
    recent_speaker_update_timeout_.add_timeout_in(group_call->group_call_id.get(), next_timeout);
  }

  auto get_result = [recent_speaker_users, td = td_] {
    return transform(recent_speaker_users, [td](const std::pair<DialogId, bool> &recent_speaker_user) {
      return td_api::make_object<td_api::groupCallRecentSpeaker>(
          get_message_sender_object(td, recent_speaker_user.first, "get_recent_speakers"), recent_speaker_user.second);
    });
  };
  if (recent_speakers->last_sent_users != recent_speaker_users) {
    recent_speakers->last_sent_users = std::move(recent_speaker_users);

    if (!for_update) {
      // the change must be received through update first
      LOG(INFO) << "Send update about " << group_call->group_call_id << " from get_recent_speakers";
      send_closure(G()->td(), &Td::send_update, get_update_group_call_object(group_call, get_result()));
    }
  }

  return get_result();
}

tl_object_ptr<td_api::groupCall> GroupCallManager::get_group_call_object(
    const GroupCall *group_call, vector<td_api::object_ptr<td_api::groupCallRecentSpeaker>> recent_speakers) {
  CHECK(group_call != nullptr);
  CHECK(group_call->is_inited);

  int32 scheduled_start_date = group_call->scheduled_start_date;
  bool is_active = scheduled_start_date == 0 ? group_call->is_active : false;
  bool is_joined = get_group_call_is_joined(group_call);
  bool start_subscribed = get_group_call_start_subscribed(group_call);
  bool is_my_video_enabled = get_group_call_is_my_video_enabled(group_call);
  bool is_my_video_paused = is_my_video_enabled && get_group_call_is_my_video_paused(group_call);
  bool mute_new_participants = get_group_call_mute_new_participants(group_call);
  bool can_toggle_mute_new_participants =
      group_call->is_active && group_call->can_be_managed && group_call->allowed_toggle_mute_new_participants;
  bool can_enable_video = get_group_call_can_enable_video(group_call);
  int32 record_start_date = get_group_call_record_start_date(group_call);
  int32 record_duration = record_start_date == 0 ? 0 : max(G()->unix_time() - record_start_date + 1, 1);
  bool is_video_recorded = get_group_call_is_video_recorded(group_call);
  return td_api::make_object<td_api::groupCall>(
      group_call->group_call_id.get(), group_call->call_id.get(), get_group_call_title(group_call),
      scheduled_start_date, start_subscribed, is_active, group_call->is_rtmp_stream, is_joined, group_call->need_rejoin,
      group_call->can_be_managed, group_call->participant_count, group_call->has_hidden_listeners,
      group_call->loaded_all_participants, std::move(recent_speakers), is_my_video_enabled, is_my_video_paused,
      can_enable_video, mute_new_participants, can_toggle_mute_new_participants, record_duration, is_video_recorded,
      group_call->duration);
}

tl_object_ptr<td_api::updateGroupCall> GroupCallManager::get_update_group_call_object(
    const GroupCall *group_call, vector<td_api::object_ptr<td_api::groupCallRecentSpeaker>> recent_speakers) {
  return td_api::make_object<td_api::updateGroupCall>(get_group_call_object(group_call, std::move(recent_speakers)));
}

tl_object_ptr<td_api::updateGroupCallParticipant> GroupCallManager::get_update_group_call_participant_object(
    GroupCallId group_call_id, const GroupCallParticipant &participant) {
  return td_api::make_object<td_api::updateGroupCallParticipant>(group_call_id.get(),
                                                                 participant.get_group_call_participant_object(td_));
}

void GroupCallManager::send_update_group_call(const GroupCall *group_call, const char *source) {
  LOG(INFO) << "Send update about " << group_call->group_call_id << " from " << source;
  send_closure(G()->td(), &Td::send_update,
               get_update_group_call_object(group_call, get_recent_speakers(group_call, true)));
}

void GroupCallManager::send_update_group_call_participant(GroupCallId group_call_id,
                                                          const GroupCallParticipant &participant, const char *source) {
  LOG(INFO) << "Send update about " << participant << " in " << group_call_id << " from " << source;
  send_closure(G()->td(), &Td::send_update, get_update_group_call_participant_object(group_call_id, participant));
}

void GroupCallManager::send_update_group_call_participant(InputGroupCallId input_group_call_id,
                                                          const GroupCallParticipant &participant, const char *source) {
  auto group_call = get_group_call(input_group_call_id);
  CHECK(group_call != nullptr && group_call->is_inited);
  send_update_group_call_participant(group_call->group_call_id, participant, source);
}

}  // namespace td
