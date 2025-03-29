//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/CallActor.h"

#include "td/telegram/DhCache.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/GroupCallManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/as.h"
#include "td/utils/bits.h"
#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"

#include <tuple>

namespace td {

CallProtocol::CallProtocol(const telegram_api::phoneCallProtocol &protocol)
    : udp_p2p(protocol.udp_p2p_)
    , udp_reflector(protocol.udp_reflector_)
    , min_layer(protocol.min_layer_)
    , max_layer(protocol.max_layer_)
    , library_versions(protocol.library_versions_) {
}

tl_object_ptr<telegram_api::phoneCallProtocol> CallProtocol::get_input_phone_call_protocol() const {
  int32 flags = 0;
  if (udp_p2p) {
    flags |= telegram_api::phoneCallProtocol::UDP_P2P_MASK;
  }
  if (udp_reflector) {
    flags |= telegram_api::phoneCallProtocol::UDP_REFLECTOR_MASK;
  }
  return make_tl_object<telegram_api::phoneCallProtocol>(flags, udp_p2p, udp_reflector, min_layer, max_layer,
                                                         vector<string>(library_versions));
}

CallProtocol::CallProtocol(const td_api::callProtocol &protocol)
    : udp_p2p(protocol.udp_p2p_)
    , udp_reflector(protocol.udp_reflector_)
    , min_layer(protocol.min_layer_)
    , max_layer(protocol.max_layer_)
    , library_versions(protocol.library_versions_) {
}

CallConnection::CallConnection(const telegram_api::PhoneConnection &connection) {
  switch (connection.get_id()) {
    case telegram_api::phoneConnection::ID: {
      auto &conn = static_cast<const telegram_api::phoneConnection &>(connection);
      type = Type::Telegram;
      id = conn.id_;
      ip = conn.ip_;
      ipv6 = conn.ipv6_;
      port = conn.port_;
      peer_tag = conn.peer_tag_.as_slice().str();
      is_tcp = conn.tcp_;
      break;
    }
    case telegram_api::phoneConnectionWebrtc::ID: {
      auto &conn = static_cast<const telegram_api::phoneConnectionWebrtc &>(connection);
      type = Type::Webrtc;
      id = conn.id_;
      ip = conn.ip_;
      ipv6 = conn.ipv6_;
      port = conn.port_;
      username = conn.username_;
      password = conn.password_;
      supports_turn = conn.turn_;
      supports_stun = conn.stun_;
      break;
    }
    default:
      UNREACHABLE();
  }
}

tl_object_ptr<td_api::callProtocol> CallProtocol::get_call_protocol_object() const {
  return make_tl_object<td_api::callProtocol>(udp_p2p, udp_reflector, min_layer, max_layer,
                                              vector<string>(library_versions));
}

tl_object_ptr<td_api::callServer> CallConnection::get_call_server_object() const {
  auto server_type = [&]() -> tl_object_ptr<td_api::CallServerType> {
    switch (type) {
      case Type::Telegram:
        return make_tl_object<td_api::callServerTypeTelegramReflector>(peer_tag, is_tcp);
      case Type::Webrtc:
        return make_tl_object<td_api::callServerTypeWebrtc>(username, password, supports_turn, supports_stun);
      default:
        UNREACHABLE();
        return nullptr;
    }
  }();
  return make_tl_object<td_api::callServer>(id, ip, ipv6, port, std::move(server_type));
}

tl_object_ptr<td_api::CallState> CallState::get_call_state_object() const {
  switch (type) {
    case Type::Pending:
      return make_tl_object<td_api::callStatePending>(is_created, is_received);
    case Type::ExchangingKey:
      return make_tl_object<td_api::callStateExchangingKeys>();
    case Type::Ready: {
      auto call_connections = transform(connections, [](auto &c) { return c.get_call_server_object(); });
      return make_tl_object<td_api::callStateReady>(protocol.get_call_protocol_object(), std::move(call_connections),
                                                    config, key, vector<string>(emojis_fingerprint), allow_p2p,
                                                    custom_parameters);
    }
    case Type::HangingUp:
      return make_tl_object<td_api::callStateHangingUp>();
    case Type::Discarded:
      return make_tl_object<td_api::callStateDiscarded>(get_call_discard_reason_object(discard_reason), need_rating,
                                                        need_debug_information, need_log);
    case Type::Error:
      CHECK(error.is_error());
      return make_tl_object<td_api::callStateError>(make_tl_object<td_api::error>(error.code(), error.message().str()));
    case Type::Empty:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

static StringBuilder &operator<<(StringBuilder &string_builder, const CallState::Type &type) {
  switch (type) {
    case CallState::Type::Empty:
      return string_builder << "Empty";
    case CallState::Type::Pending:
      return string_builder << "Pending";
    case CallState::Type::ExchangingKey:
      return string_builder << "ExchangingKey";
    case CallState::Type::Ready:
      return string_builder << "Ready";
    case CallState::Type::HangingUp:
      return string_builder << "HangingUp";
    case CallState::Type::Discarded:
      return string_builder << "Discarded";
    case CallState::Type::Error:
      return string_builder << "Error";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, const CallActor::State &state) {
  string_builder << "state ";
  switch (state) {
    case CallActor::State::Empty:
      return string_builder << "Empty";
    case CallActor::State::SendRequestQuery:
      return string_builder << "SendRequestQuery";
    case CallActor::State::WaitRequestResult:
      return string_builder << "WaitRequestResult";
    case CallActor::State::SendAcceptQuery:
      return string_builder << "SendAcceptQuery";
    case CallActor::State::WaitAcceptResult:
      return string_builder << "WaitAcceptResult";
    case CallActor::State::SendConfirmQuery:
      return string_builder << "SendConfirmQuery";
    case CallActor::State::WaitConfirmResult:
      return string_builder << "WaitConfirmResult";
    case CallActor::State::Ready:
      return string_builder << "Ready";
    case CallActor::State::SendDiscardQuery:
      return string_builder << "SendDiscardQuery";
    case CallActor::State::WaitDiscardResult:
      return string_builder << "WaitDiscardResult";
    case CallActor::State::Discarded:
      return string_builder << "Discarded";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

CallActor::CallActor(Td *td, CallId call_id, ActorShared<> parent, Promise<int64> promise)
    : td_(td), parent_(std::move(parent)), call_id_promise_(std::move(promise)), local_call_id_(call_id) {
}

void CallActor::create_call(UserId user_id, CallProtocol &&protocol, bool is_video, GroupCallId group_call_id,
                            Promise<CallId> &&promise) {
  CHECK(state_ == State::Empty);
  state_ = State::SendRequestQuery;
  is_outgoing_ = true;
  is_video_ = is_video;
  user_id_ = user_id;
  auto r_input_group_call_id = td_->group_call_manager_->get_input_group_call_id(group_call_id);
  if (r_input_group_call_id.is_ok()) {
    input_group_call_id_ = r_input_group_call_id.ok();
  }
  call_state_.protocol = std::move(protocol);
  call_state_.type = CallState::Type::Pending;
  call_state_.is_received = false;
  call_state_need_flush_ = true;
  loop();
  promise.set_value(CallId(local_call_id_));
}

void CallActor::accept_call(CallProtocol &&protocol, Promise<Unit> promise) {
  if (state_ != State::SendAcceptQuery) {
    return promise.set_error(Status::Error(400, "Unexpected acceptCall"));
  }
  is_accepted_ = true;
  call_state_.protocol = std::move(protocol);
  promise.set_value(Unit());
  loop();
}

void CallActor::update_call_signaling_data(string data) {
  if (call_state_.type != CallState::Type::Ready) {
    return;
  }

  auto update = td_api::make_object<td_api::updateNewCallSignalingData>();
  update->call_id_ = local_call_id_.get();
  update->data_ = std::move(data);
  send_closure(G()->td(), &Td::send_update, std::move(update));
}

void CallActor::send_call_signaling_data(string &&data, Promise<Unit> promise) {
  if (call_state_.type != CallState::Type::Ready) {
    return promise.set_error(Status::Error(400, "Call is not active"));
  }

  auto query = G()->net_query_creator().create(
      telegram_api::phone_sendSignalingData(get_input_phone_call("send_call_signaling_data"), BufferSlice(data)));
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([promise = std::move(promise)](Result<NetQueryPtr> r_net_query) mutable {
                      auto res = fetch_result<telegram_api::phone_sendSignalingData>(std::move(r_net_query));
                      if (res.is_error()) {
                        promise.set_error(res.move_as_error());
                      } else {
                        promise.set_value(Unit());
                      }
                    }));
}

void CallActor::discard_call(bool is_disconnected, int32 duration, bool is_video, int64 connection_id,
                             Promise<Unit> promise) {
  promise.set_value(Unit());
  if (state_ == State::Discarded || state_ == State::WaitDiscardResult || state_ == State::SendDiscardQuery) {
    return;
  }
  is_video_ |= is_video;

  if (state_ == State::WaitRequestResult && !request_query_ref_.empty()) {
    LOG(INFO) << "Cancel request call query";
    cancel_query(request_query_ref_);
  }

  switch (call_state_.type) {
    case CallState::Type::Empty:
    case CallState::Type::Pending:
      if (is_outgoing_) {
        call_state_.discard_reason.type_ = CallDiscardReason::Type::Missed;
      } else {
        call_state_.discard_reason.type_ = CallDiscardReason::Type::Declined;
      }
      break;
    case CallState::Type::ExchangingKey:
      call_state_.discard_reason.type_ =
          is_disconnected ? CallDiscardReason::Type::Disconnected : CallDiscardReason::Type::HungUp;
      break;
    case CallState::Type::Ready:
      call_state_.discard_reason.type_ =
          is_disconnected ? CallDiscardReason::Type::Disconnected : CallDiscardReason::Type::HungUp;
      duration_ = duration;
      connection_id_ = connection_id;
      break;
    case CallState::Type::HangingUp:
    case CallState::Type::Discarded:
    case CallState::Type::Error:
    default:
      UNREACHABLE();
      return;
  }

  call_state_.type = CallState::Type::HangingUp;
  call_state_need_flush_ = true;

  state_ = State::SendDiscardQuery;
  loop();
}

void CallActor::rate_call(int32 rating, string comment, vector<td_api::object_ptr<td_api::CallProblem>> &&problems,
                          Promise<Unit> promise) {
  if (!call_state_.need_rating) {
    return promise.set_error(Status::Error(400, "Unexpected sendCallRating"));
  }
  promise.set_value(Unit());

  if (rating == 5) {
    comment.clear();
  }

  FlatHashSet<string> tags;
  for (auto &problem : problems) {
    if (problem == nullptr) {
      continue;
    }

    const char *tag = [problem_id = problem->get_id()] {
      switch (problem_id) {
        case td_api::callProblemEcho::ID:
          return "echo";
        case td_api::callProblemNoise::ID:
          return "noise";
        case td_api::callProblemInterruptions::ID:
          return "interruptions";
        case td_api::callProblemDistortedSpeech::ID:
          return "distorted_speech";
        case td_api::callProblemSilentLocal::ID:
          return "silent_local";
        case td_api::callProblemSilentRemote::ID:
          return "silent_remote";
        case td_api::callProblemDropped::ID:
          return "dropped";
        case td_api::callProblemDistortedVideo::ID:
          return "distorted_video";
        case td_api::callProblemPixelatedVideo::ID:
          return "pixelated_video";
        default:
          UNREACHABLE();
          return "";
      }
    }();
    if (tags.insert(tag).second) {
      if (!comment.empty()) {
        comment += ' ';
      }
      comment += '#';
      comment += tag;
    }
  }

  auto tl_query = telegram_api::phone_setCallRating(0, false /*ignored*/, get_input_phone_call("rate_call"), rating,
                                                    std::move(comment));
  auto query = G()->net_query_creator().create(tl_query);
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_set_rating_query_result, std::move(r_net_query));
                    }));
  loop();
}

void CallActor::on_set_rating_query_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_setCallRating>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
  if (call_state_.need_rating) {
    call_state_.need_rating = false;
    call_state_need_flush_ = true;
    loop();
  }
  send_closure(G()->updates_manager(), &UpdatesManager::on_get_updates, res.move_as_ok(), Promise<Unit>());
}

void CallActor::send_call_debug_information(string data, Promise<Unit> promise) {
  if (!call_state_.need_debug_information) {
    return promise.set_error(Status::Error(400, "Unexpected sendCallDebugInformation"));
  }
  promise.set_value(Unit());
  auto tl_query = telegram_api::phone_saveCallDebug(get_input_phone_call("send_call_debug_information"),
                                                    make_tl_object<telegram_api::dataJSON>(std::move(data)));
  auto query = G()->net_query_creator().create(tl_query);
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_save_debug_query_result, std::move(r_net_query));
                    }));
  loop();
}

void CallActor::on_save_debug_query_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_saveCallDebug>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
  if (!res.ok() && !call_state_.need_log) {
    call_state_.need_log = true;
    call_state_need_flush_ = true;
  }
  if (call_state_.need_debug_information) {
    call_state_.need_debug_information = false;
    call_state_need_flush_ = true;
  }
  loop();
}

void CallActor::send_call_log(td_api::object_ptr<td_api::InputFile> log_file, Promise<Unit> promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (!call_state_.need_log) {
    return promise.set_error(Status::Error(400, "Unexpected sendCallLog"));
  }

  auto *file_manager = td_->file_manager_.get();
  TRY_RESULT_PROMISE(promise, file_id,
                     file_manager->get_input_file_id(FileType::CallLog, log_file, DialogId(), false, false));

  FileView file_view = file_manager->get_file_view(file_id);
  if (file_view.is_encrypted()) {
    return promise.set_error(Status::Error(400, "Can't use encrypted file"));
  }
  if (!file_view.has_full_local_location() && !file_view.has_generate_location()) {
    return promise.set_error(Status::Error(400, "Need local or generate location to upload call log"));
  }

  upload_log_file({file_id, FileManager::get_internal_upload_id()}, std::move(promise));
}

void CallActor::upload_log_file(FileUploadId file_upload_id, Promise<Unit> &&promise) {
  LOG(INFO) << "Ask to upload call log " << file_upload_id;

  class UploadLogFileCallback final : public FileManager::UploadCallback {
    ActorId<CallActor> actor_id_;
    Promise<Unit> promise_;

   public:
    UploadLogFileCallback(ActorId<CallActor> actor_id, Promise<Unit> &&promise)
        : actor_id_(actor_id), promise_(std::move(promise)) {
    }

    void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
      send_closure_later(actor_id_, &CallActor::on_upload_log_file, file_upload_id, std::move(promise_),
                         std::move(input_file));
    }

    void on_upload_error(FileUploadId file_upload_id, Status error) final {
      send_closure_later(actor_id_, &CallActor::on_upload_log_file_error, file_upload_id, std::move(promise_),
                         std::move(error));
    }
  };

  send_closure(G()->file_manager(), &FileManager::upload, file_upload_id,
               std::make_shared<UploadLogFileCallback>(actor_id(this), std::move(promise)), 1, 0);
}

void CallActor::on_upload_log_file(FileUploadId file_upload_id, Promise<Unit> &&promise,
                                   telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  LOG(INFO) << "Log " << file_upload_id << " has been uploaded";

  do_upload_log_file(file_upload_id, std::move(input_file), std::move(promise));
}

void CallActor::on_upload_log_file_error(FileUploadId file_upload_id, Promise<Unit> &&promise, Status status) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  LOG(WARNING) << "Log " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  promise.set_error(Status::Error(status.code() > 0 ? status.code() : 500,
                                  status.message()));  // TODO CHECK that status has always a code
}

void CallActor::do_upload_log_file(FileUploadId file_upload_id,
                                   telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
                                   Promise<Unit> &&promise) {
  if (input_file == nullptr) {
    return promise.set_error(Status::Error(500, "Failed to reupload call log"));
  }

  auto tl_query = telegram_api::phone_saveCallLog(get_input_phone_call("do_upload_log_file"), std::move(input_file));
  send_with_promise(G()->net_query_creator().create(tl_query),
                    PromiseCreator::lambda([actor_id = actor_id(this), file_upload_id,
                                            promise = std::move(promise)](Result<NetQueryPtr> r_net_query) mutable {
                      send_closure(actor_id, &CallActor::on_save_log_query_result, file_upload_id, std::move(promise),
                                   std::move(r_net_query));
                    }));
  loop();
}

void CallActor::on_save_log_query_result(FileUploadId file_upload_id, Promise<Unit> promise,
                                         Result<NetQueryPtr> r_net_query) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  send_closure(G()->file_manager(), &FileManager::delete_partial_remote_location, file_upload_id);

  auto res = fetch_result<telegram_api::phone_saveCallLog>(std::move(r_net_query));
  if (res.is_error()) {
    auto error = res.move_as_error();
    auto bad_parts = FileManager::get_missing_file_parts(error);
    if (!bad_parts.empty()) {
      // TODO on_upload_log_file_parts_missing(file_upload_id, std::move(bad_parts));
      // return;
    }
    return promise.set_error(std::move(error));
  }
  if (call_state_.need_log) {
    call_state_.need_log = false;
    call_state_need_flush_ = true;
  }
  loop();
  promise.set_value(Unit());
}

void CallActor::create_conference_call(Promise<Unit> promise) {
  if (input_group_call_id_.is_valid()) {
    return promise.set_value(Unit());
  }
  auto tl_query = telegram_api::phone_createConferenceCall(get_input_phone_call("create_conference_call"),
                                                           call_state_.key_fingerprint);
  auto query = G()->net_query_creator().create(tl_query);
  send_with_promise(std::move(query), PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise)](
                                                                 Result<NetQueryPtr> r_net_query) mutable {
                      send_closure(actor_id, &CallActor::on_create_conference_call_result, std::move(promise),
                                   std::move(r_net_query));
                    }));
  loop();
}

void CallActor::on_create_conference_call_result(Promise<Unit> promise, Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_createConferenceCall>(std::move(r_net_query));
  if (res.is_error()) {
    return promise.set_error(res.move_as_error());
  }
  update_call_inner(res.move_as_ok());
  if (!input_group_call_id_.is_valid()) {
    return promise.set_error(Status::Error(500, "Receive invalid response"));
  }
  promise.set_value(Unit());
}

void CallActor::update_call(tl_object_ptr<telegram_api::PhoneCall> call) {
  LOG(INFO) << "Receive " << to_string(call);
  auto status = [&] {
    switch (call->get_id()) {
      case telegram_api::phoneCallEmpty::ID:
        return do_update_call(static_cast<const telegram_api::phoneCallEmpty &>(*call));
      case telegram_api::phoneCallWaiting::ID:
        return do_update_call(static_cast<const telegram_api::phoneCallWaiting &>(*call));
      case telegram_api::phoneCallRequested::ID:
        return do_update_call(static_cast<const telegram_api::phoneCallRequested &>(*call));
      case telegram_api::phoneCallAccepted::ID:
        return do_update_call(static_cast<const telegram_api::phoneCallAccepted &>(*call));
      case telegram_api::phoneCall::ID:
        return do_update_call(static_cast<const telegram_api::phoneCall &>(*call));
      case telegram_api::phoneCallDiscarded::ID:
        return do_update_call(static_cast<const telegram_api::phoneCallDiscarded &>(*call));
      default:
        UNREACHABLE();
        return Status::OK();
    }
  }();
  if (status.is_error()) {
    LOG(INFO) << "Receive error " << status << ", while handling update " << to_string(call);
    on_error(std::move(status));
  }
  loop();
}

void CallActor::update_call_inner(tl_object_ptr<telegram_api::phone_phoneCall> call) {
  LOG(INFO) << "Update call with " << to_string(call);
  send_closure(G()->user_manager(), &UserManager::on_get_users, std::move(call->users_), "UpdatePhoneCall");
  update_call(std::move(call->phone_call_));
}

Status CallActor::do_update_call(const telegram_api::phoneCallEmpty &call) {
  return Status::Error(400, "Call is finished");
}

Status CallActor::do_update_call(const telegram_api::phoneCallWaiting &call) {
  if (state_ != State::WaitRequestResult && state_ != State::WaitAcceptResult) {
    return Status::OK();
  }

  if (state_ == State::WaitAcceptResult) {
    LOG(DEBUG) << "Do update call to Waiting";
    on_begin_exchanging_key();
  } else {
    LOG(DEBUG) << "Do update call to Waiting";
    if ((call.flags_ & telegram_api::phoneCallWaiting::RECEIVE_DATE_MASK) != 0) {
      if (!call_state_.is_received) {
        call_state_.is_received = true;
        call_state_need_flush_ = true;
      }
      int64 call_ring_timeout_ms = G()->get_option_integer("call_ring_timeout_ms", 90000);
      set_timeout_in(static_cast<double>(call_ring_timeout_ms) * 0.001);
    }
  }

  call_id_ = call.id_;
  call_access_hash_ = call.access_hash_;
  is_call_id_inited_ = true;
  call_admin_user_id_ = UserId(call.admin_id_);
  update_conference_call(call.conference_call_);
  on_get_call_id();

  if (call.video_ && !is_video_) {
    is_video_ = true;
    call_state_need_flush_ = true;
  }
  if (!call_state_.is_created) {
    call_state_.is_created = true;
    call_state_need_flush_ = true;
  }

  return Status::OK();
}

Status CallActor::do_update_call(const telegram_api::phoneCallRequested &call) {
  if (state_ != State::Empty) {
    return Status::OK();
  }
  LOG(DEBUG) << "Do update call to Requested";
  call_id_ = call.id_;
  call_access_hash_ = call.access_hash_;
  is_call_id_inited_ = true;
  update_conference_call(call.conference_call_);
  is_video_ |= call.video_;
  call_admin_user_id_ = UserId(call.admin_id_);
  on_get_call_id();

  dh_handshake_.set_g_a_hash(call.g_a_hash_.as_slice());
  state_ = State::SendAcceptQuery;

  call_state_.type = CallState::Type::Pending;
  call_state_.is_created = true;
  call_state_.is_received = true;
  call_state_need_flush_ = true;

  send_received_query();
  return Status::OK();
}

tl_object_ptr<telegram_api::inputPhoneCall> CallActor::get_input_phone_call(const char *source) {
  LOG_CHECK(is_call_id_inited_) << source;
  return make_tl_object<telegram_api::inputPhoneCall>(call_id_, call_access_hash_);
}

Status CallActor::do_update_call(const telegram_api::phoneCallAccepted &call) {
  if (state_ != State::WaitRequestResult) {
    return Status::OK();
  }

  LOG(DEBUG) << "Do update call to Accepted";
  if (!is_call_id_inited_) {
    call_id_ = call.id_;
    call_access_hash_ = call.access_hash_;
    is_call_id_inited_ = true;
    call_admin_user_id_ = UserId(call.admin_id_);
    on_get_call_id();
  }
  update_conference_call(call.conference_call_);
  is_video_ |= call.video_;
  dh_handshake_.set_g_a(call.g_b_.as_slice());
  TRY_STATUS(dh_handshake_.run_checks(true, DhCache::instance()));
  std::tie(call_state_.key_fingerprint, call_state_.key) = dh_handshake_.gen_key();
  state_ = State::SendConfirmQuery;
  on_begin_exchanging_key();
  return Status::OK();
}

void CallActor::on_begin_exchanging_key() {
  call_state_.type = CallState::Type::ExchangingKey;
  call_state_need_flush_ = true;
  int64 call_receive_timeout_ms = G()->get_option_integer("call_receive_timeout_ms", 20000);
  auto timeout = static_cast<double>(call_receive_timeout_ms) * 0.001;
  LOG(INFO) << "Set call timeout to " << timeout;
  set_timeout_in(timeout);
}

void CallActor::update_conference_call(const telegram_api::object_ptr<telegram_api::inputGroupCall> &conference_call) {
  InputGroupCallId input_group_call_id;
  if (conference_call != nullptr) {
    input_group_call_id = InputGroupCallId(conference_call);
  }
  if (input_group_call_id_ != input_group_call_id) {
    input_group_call_id_ = input_group_call_id;
    call_state_need_flush_ = true;
  }
}

Status CallActor::do_update_call(const telegram_api::phoneCall &call) {
  if (state_ != State::WaitAcceptResult && state_ != State::WaitConfirmResult) {
    if (state_ == State::Ready) {
      update_conference_call(call.conference_call_);
    }
    return Status::OK();
  }
  cancel_timeout();

  LOG(DEBUG) << "Do update call to Ready from " << state_;
  if (state_ == State::WaitAcceptResult) {
    dh_handshake_.set_g_a(call.g_a_or_b_.as_slice());
    TRY_STATUS(dh_handshake_.run_checks(true, DhCache::instance()));
    std::tie(call_state_.key_fingerprint, call_state_.key) = dh_handshake_.gen_key();
  }
  if (call_state_.key_fingerprint != call.key_fingerprint_) {
    return Status::Error(400, "Key fingerprints mismatch");
  }

  state_ = State::Ready;
  is_video_ |= call.video_;
  call_state_.emojis_fingerprint =
      get_emojis_fingerprint(call_state_.key, is_outgoing_ ? dh_handshake_.get_g_b() : dh_handshake_.get_g_a());

  for (auto &connection : call.connections_) {
    call_state_.connections.emplace_back(*connection);
  }
  call_state_.protocol = CallProtocol(*call.protocol_);
  call_state_.allow_p2p = call.p2p_allowed_;
  if (call.custom_parameters_ != nullptr) {
    call_state_.custom_parameters = std::move(call.custom_parameters_->data_);
  }
  update_conference_call(call.conference_call_);
  call_state_.type = CallState::Type::Ready;
  call_state_need_flush_ = true;

  return Status::OK();
}

Status CallActor::do_update_call(const telegram_api::phoneCallDiscarded &call) {
  LOG(DEBUG) << "Do update call to Discarded";
  update_conference_call(call.conference_call_);
  on_call_discarded(get_call_discard_reason(call.reason_), call.need_rating_, call.need_debug_, call.video_);
  return Status::OK();
}

void CallActor::on_get_call_id() {
  if (call_id_promise_) {
    int64 call_id = call_id_;
    call_id_promise_.set_value(std::move(call_id));
    call_id_promise_ = {};
  }
}

void CallActor::on_call_discarded(CallDiscardReason reason, bool need_rating, bool need_debug, bool is_video) {
  if (state_ != State::Discarded) {
    state_ = State::Discarded;
    call_state_need_flush_ = true;
  }
  if (is_video && !is_video_) {
    is_video_ = true;
    call_state_need_flush_ = true;
  }
  if (call_state_.discard_reason != reason && reason.type_ != CallDiscardReason::Type::Empty) {
    call_state_.discard_reason = std::move(reason);
    call_state_need_flush_ = true;
  }
  if (call_state_.type != CallState::Type::Error) {
    if (call_state_.need_rating != need_rating || call_state_.need_debug_information != need_debug ||
        call_state_.type != CallState::Type::Discarded) {
      call_state_.need_rating = need_rating;
      call_state_.need_debug_information = need_debug;
      call_state_.type = CallState::Type::Discarded;
      call_state_need_flush_ = true;
    }
  }
}

bool CallActor::load_dh_config() {
  if (dh_config_ready_) {
    LOG(DEBUG) << "Dh config is ready";
    return true;
  }
  if (!dh_config_query_sent_) {
    dh_config_query_sent_ = true;
    do_load_dh_config(PromiseCreator::lambda([actor_id = actor_id(this)](Result<std::shared_ptr<DhConfig>> dh_config) {
      send_closure(actor_id, &CallActor::on_dh_config, std::move(dh_config), false);
    }));
  }
  LOG(INFO) << "Dh config is not loaded";
  return false;
}

void CallActor::on_error(Status status) {
  CHECK(status.is_error());
  LOG(INFO) << "Receive error " << status;

  if (state_ == State::WaitRequestResult && !request_query_ref_.empty()) {
    LOG(INFO) << "Cancel request call query";
    cancel_query(request_query_ref_);
  }
  if (state_ == State::WaitDiscardResult || state_ == State::Discarded) {
    state_ = State::Discarded;
  } else {
    state_ = State::SendDiscardQuery;
    call_state_.discard_reason.type_ = call_state_.type == CallState::Type::Pending
                                           ? CallDiscardReason::Type::Missed
                                           : CallDiscardReason::Type::Disconnected;
  }

  call_state_.type = CallState::Type::Error;
  call_state_.error = std::move(status);
  call_state_need_flush_ = true;
}

void CallActor::on_dh_config(Result<std::shared_ptr<DhConfig>> r_dh_config, bool dummy) {
  if (r_dh_config.is_error()) {
    return on_error(r_dh_config.move_as_error());
  }

  dh_config_ = r_dh_config.move_as_ok();
  auto check_result = mtproto::DhHandshake::check_config(dh_config_->g, dh_config_->prime, DhCache::instance());
  if (check_result.is_error()) {
    return on_error(std::move(check_result));
  }

  dh_config_ready_ = true;
  yield();
}

void CallActor::do_load_dh_config(Promise<std::shared_ptr<DhConfig>> promise) {
  //TODO: move to external actor
  auto dh_config = G()->get_dh_config();
  int32 version = 0;
  if (dh_config) {
    version = dh_config->version;
  }
  int random_length = 0;
  telegram_api::messages_getDhConfig tl_query(version, random_length);
  auto query = G()->net_query_creator().create(tl_query);
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this), old_dh_config = std::move(dh_config),
                                            promise = std::move(promise)](Result<NetQueryPtr> result_query) mutable {
                      promise.set_result([&]() -> Result<std::shared_ptr<DhConfig>> {
                        TRY_RESULT(query, std::move(result_query));
                        TRY_RESULT(new_dh_config, fetch_result<telegram_api::messages_getDhConfig>(std::move(query)));
                        if (new_dh_config->get_id() == telegram_api::messages_dhConfig::ID) {
                          auto dh = move_tl_object_as<telegram_api::messages_dhConfig>(new_dh_config);
                          auto dh_config = std::make_shared<DhConfig>();
                          dh_config->version = dh->version_;
                          dh_config->prime = dh->p_.as_slice().str();
                          dh_config->g = dh->g_;
                          Random::add_seed(dh->random_.as_slice());
                          G()->set_dh_config(dh_config);
                          return std::move(dh_config);
                        } else if (new_dh_config->get_id() == telegram_api::messages_dhConfigNotModified::ID) {
                          auto dh = move_tl_object_as<telegram_api::messages_dhConfigNotModified>(new_dh_config);
                          Random::add_seed(dh->random_.as_slice());
                        }
                        if (old_dh_config) {
                          return std::move(old_dh_config);
                        }
                        return Status::Error(500, "Can't load DhConfig");
                      }());
                    }));
}

void CallActor::send_received_query() {
  auto tl_query = telegram_api::phone_receivedCall(get_input_phone_call("send_received_query"));
  auto query = G()->net_query_creator().create(tl_query);
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_received_query_result, std::move(r_net_query));
                    }));
}

void CallActor::on_received_query_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_receivedCall>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
}

void CallActor::try_send_request_query() {
  if (G()->close_flag()) {
    return;
  }
  LOG(INFO) << "Trying to send request query";
  if (!load_dh_config()) {
    return;
  }
  dh_handshake_.set_config(dh_config_->g, dh_config_->prime);
  auto r_input_user = td_->user_manager_->get_input_user(user_id_);
  if (r_input_user.is_error()) {
    return on_error(r_input_user.move_as_error());
  }
  int32 flags = 0;
  if (is_video_) {
    flags |= telegram_api::phone_requestCall::VIDEO_MASK;
  }
  telegram_api::object_ptr<telegram_api::inputGroupCall> input_group_call;
  if (input_group_call_id_.is_valid()) {
    flags |= telegram_api::phone_requestCall::CONFERENCE_CALL_MASK;
    input_group_call = input_group_call_id_.get_input_group_call();
  }
  auto tl_query = telegram_api::phone_requestCall(
      flags, false /*ignored*/, r_input_user.move_as_ok(), std::move(input_group_call), Random::secure_int32(),
      BufferSlice(dh_handshake_.get_g_b_hash()), call_state_.protocol.get_input_phone_call_protocol());
  auto query = G()->net_query_creator().create(tl_query);
  state_ = State::WaitRequestResult;
  int64 call_receive_timeout_ms = G()->get_option_integer("call_receive_timeout_ms", 20000);
  auto timeout = static_cast<double>(call_receive_timeout_ms) * 0.001;
  LOG(INFO) << "Set call timeout to " << timeout;
  set_timeout_in(timeout);
  query->total_timeout_limit_ =
      static_cast<int32>(clamp(call_receive_timeout_ms + 999, static_cast<int64>(10000), static_cast<int64>(100000))) /
      1000;
  request_query_ref_ = query.get_weak();
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_request_query_result, std::move(r_net_query));
                    }));
}

void CallActor::on_request_query_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_requestCall>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
  update_call_inner(res.move_as_ok());
}

//phone.acceptCall#3bd2b4a0 peer:InputPhoneCall g_b:bytes protocol:PhoneCallProtocol = phone.PhoneCall;
void CallActor::try_send_accept_query() {
  LOG(INFO) << "Trying to send accept query";
  if (!load_dh_config()) {
    return;
  }
  if (!is_accepted_) {
    LOG(DEBUG) << "Call is not accepted";
    return;
  }
  dh_handshake_.set_config(dh_config_->g, dh_config_->prime);
  auto tl_query = telegram_api::phone_acceptCall(get_input_phone_call("try_send_accept_query"),
                                                 BufferSlice(dh_handshake_.get_g_b()),
                                                 call_state_.protocol.get_input_phone_call_protocol());
  auto query = G()->net_query_creator().create(tl_query);
  state_ = State::WaitAcceptResult;
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_accept_query_result, std::move(r_net_query));
                    }));
}

void CallActor::on_accept_query_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_acceptCall>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
  update_call_inner(res.move_as_ok());
}

//phone.confirmCall#2efe1722 peer:InputPhoneCall g_a:bytes key_fingerprint:long protocol:PhoneCallProtocol = phone.PhoneCall;
void CallActor::try_send_confirm_query() {
  LOG(INFO) << "Trying to send confirm query";
  if (!load_dh_config()) {
    return;
  }
  auto tl_query = telegram_api::phone_confirmCall(get_input_phone_call("try_send_confirm_query"),
                                                  BufferSlice(dh_handshake_.get_g_b()), call_state_.key_fingerprint,
                                                  call_state_.protocol.get_input_phone_call_protocol());
  auto query = G()->net_query_creator().create(tl_query);
  state_ = State::WaitConfirmResult;
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_confirm_query_result, std::move(r_net_query));
                    }));
}

void CallActor::on_confirm_query_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_confirmCall>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
  update_call_inner(res.move_as_ok());
}

void CallActor::try_send_discard_query() {
  if (call_id_ == 0) {
    LOG(INFO) << "Failed to send discard query, because call_id_ is unknown";
    CallDiscardReason reason;
    reason.type_ = CallDiscardReason::Type::Missed;
    on_call_discarded(std::move(reason), false, false, is_video_);
    yield();
    return;
  }
  LOG(INFO) << "Trying to send discard query";
  int32 flags = 0;
  if (is_video_) {
    flags |= telegram_api::phone_discardCall::VIDEO_MASK;
  }
  auto tl_query = telegram_api::phone_discardCall(
      flags, false /*ignored*/, get_input_phone_call("try_send_discard_query"), duration_,
      get_input_phone_call_discard_reason(call_state_.discard_reason), connection_id_);
  auto query = G()->net_query_creator().create(tl_query);
  state_ = State::WaitDiscardResult;
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_discard_query_result, std::move(r_net_query));
                    }));
}

void CallActor::on_discard_query_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_discardCall>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
  send_closure(G()->updates_manager(), &UpdatesManager::on_get_updates, res.move_as_ok(), Promise<Unit>());
}

void CallActor::flush_call_state() {
  if (G()->close_flag()) {
    return;
  }
  if (call_state_need_flush_) {
    if (!is_outgoing_) {
      if (call_state_.type == CallState::Type::Pending) {
        if (!has_notification_) {
          has_notification_ = true;
          send_closure(G()->notification_manager(), &NotificationManager::add_call_notification,
                       DialogId(call_admin_user_id_), local_call_id_);
        }
      } else {
        if (has_notification_) {
          has_notification_ = false;
          send_closure(G()->notification_manager(), &NotificationManager::remove_call_notification,
                       DialogId(call_admin_user_id_), local_call_id_);
        }
      }
    }

    if (call_state_.type == CallState::Type::Ready && !call_state_has_config_) {
      return;
    }
    call_state_need_flush_ = false;

    auto peer_id = is_outgoing_ ? user_id_ : call_admin_user_id_;
    auto group_call_id = td_->group_call_manager_->get_group_call_id(input_group_call_id_, DialogId()).get();
    auto update = td_api::make_object<td_api::updateCall>(td_api::make_object<td_api::call>(
        local_call_id_.get(), 0, is_outgoing_, is_video_, call_state_.get_call_state_object(), group_call_id));
    send_closure(G()->user_manager(), &UserManager::get_user_id_object_async, peer_id,
                 [td_actor = G()->td(), update = std::move(update)](Result<int64> r_user_id) mutable {
                   if (r_user_id.is_ok()) {
                     update->call_->user_id_ = r_user_id.ok();
                     send_closure(td_actor, &Td::send_update, std::move(update));
                   }
                 });
  }
}

void CallActor::start_up() {
  auto tl_query = telegram_api::phone_getCallConfig();
  auto query = G()->net_query_creator().create(tl_query);
  send_with_promise(std::move(query),
                    PromiseCreator::lambda([actor_id = actor_id(this)](Result<NetQueryPtr> r_net_query) {
                      send_closure(actor_id, &CallActor::on_get_call_config_result, std::move(r_net_query));
                    }));
}

void CallActor::on_get_call_config_result(Result<NetQueryPtr> r_net_query) {
  auto res = fetch_result<telegram_api::phone_getCallConfig>(std::move(r_net_query));
  if (res.is_error()) {
    return on_error(res.move_as_error());
  }
  call_state_.config = res.ok()->data_;
  call_state_has_config_ = true;
}

void CallActor::loop() {
  LOG(DEBUG) << "Enter loop for " << call_id_ << " in " << state_ << '/' << call_state_.type;
  flush_call_state();
  switch (state_) {
    case State::SendRequestQuery:
      try_send_request_query();
      break;
    case State::SendAcceptQuery:
      try_send_accept_query();
      break;
    case State::SendConfirmQuery:
      try_send_confirm_query();
      break;
    case State::SendDiscardQuery:
      try_send_discard_query();
      break;
    case State::Discarded: {
      if (call_state_.type == CallState::Type::Discarded &&
          (call_state_.need_rating || call_state_.need_debug_information || call_state_.need_log)) {
        break;
      }
      LOG(INFO) << "Close " << local_call_id_;
      container_.for_each(
          [](auto id, Promise<NetQueryPtr> &promise) { promise.set_error(Global::request_aborted_error()); });
      stop();
      break;
    }
    default:
      break;
  }
}

void CallActor::timeout_expired() {
  on_error(Status::Error(4005000, "Call timeout expired"));
  yield();
}

void CallActor::on_result(NetQueryPtr query) {
  auto token = get_link_token();
  container_.extract(token).set_value(std::move(query));
  yield();  // Call loop AFTER all events from the promise are executed
}

void CallActor::send_with_promise(NetQueryPtr query, Promise<NetQueryPtr> promise) {
  auto id = container_.create(std::move(promise));
  G()->net_query_dispatcher().dispatch_with_callback(std::move(query), actor_shared(this, id));
}

void CallActor::hangup() {
  container_.for_each(
      [](auto id, Promise<NetQueryPtr> &promise) { promise.set_error(Global::request_aborted_error()); });
  stop();
}

vector<string> CallActor::get_emojis_fingerprint(const string &key, const string &g_a) {
  string str = key + g_a;
  unsigned char sha256_buf[32];
  sha256(str, {sha256_buf, 32});

  vector<string> result;
  result.reserve(4);
  for (int i = 0; i < 4; i++) {
    uint64 num = big_endian_to_host64(as<uint64>(sha256_buf + 8 * i));
    result.push_back(get_emoji_fingerprint(num));
  }
  return result;
}

}  // namespace td
