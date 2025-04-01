//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CallDiscardReason.h"
#include "td/telegram/CallId.h"
#include "td/telegram/DhConfig.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/GroupCallId.h"
#include "td/telegram/InputGroupCallId.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/mtproto/DhHandshake.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

#include <memory>

namespace td {

class Td;

struct CallProtocol {
  bool udp_p2p{true};
  bool udp_reflector{true};
  int32 min_layer{65};
  int32 max_layer{65};
  vector<string> library_versions;

  CallProtocol() = default;

  explicit CallProtocol(const td_api::callProtocol &protocol);

  explicit CallProtocol(const telegram_api::phoneCallProtocol &protocol);

  tl_object_ptr<telegram_api::phoneCallProtocol> get_input_phone_call_protocol() const;

  tl_object_ptr<td_api::callProtocol> get_call_protocol_object() const;
};

struct CallConnection {
  enum class Type : int32 { Telegram, Webrtc };
  Type type;
  int64 id;
  string ip;
  string ipv6;
  int32 port;

  // Telegram
  string peer_tag;
  bool is_tcp = false;

  // WebRTC
  string username;
  string password;
  bool supports_turn = false;
  bool supports_stun = false;

  explicit CallConnection(const telegram_api::PhoneConnection &connection);

  tl_object_ptr<td_api::callServer> get_call_server_object() const;
};

struct CallState {
  enum class Type : int32 { Empty, Pending, ExchangingKey, Ready, HangingUp, Discarded, Error } type{Type::Empty};

  CallProtocol protocol;
  vector<CallConnection> connections;
  CallDiscardReason discard_reason;
  bool is_created{false};
  bool is_received{false};
  bool need_debug_information{false};
  bool need_rating{false};
  bool need_log{false};

  int64 key_fingerprint{0};
  string key;
  string config;
  vector<string> emojis_fingerprint;
  string custom_parameters;
  bool allow_p2p{false};

  Status error;

  tl_object_ptr<td_api::CallState> get_call_state_object() const;
};

class CallActor final : public NetQueryCallback {
 public:
  CallActor(Td *td, CallId call_id, ActorShared<> parent, Promise<int64> promise);

  void create_call(UserId user_id, CallProtocol &&protocol, bool is_video, GroupCallId group_call_id,
                   Promise<CallId> &&promise);

  void accept_call(CallProtocol &&protocol, Promise<Unit> promise);

  void update_call_signaling_data(string data);

  void send_call_signaling_data(string &&data, Promise<Unit> promise);

  void discard_call(bool is_disconnected, int32 duration, bool is_video, int64 connection_id, Promise<Unit> promise);

  void rate_call(int32 rating, string comment, vector<td_api::object_ptr<td_api::CallProblem>> &&problems,
                 Promise<Unit> promise);

  void send_call_debug_information(string data, Promise<Unit> promise);

  void send_call_log(td_api::object_ptr<td_api::InputFile> log_file, Promise<Unit> promise);

  void create_conference_call(Promise<Unit> promise);

  void update_call(tl_object_ptr<telegram_api::PhoneCall> call);

 private:
  Td *td_;
  ActorShared<> parent_;
  Promise<int64> call_id_promise_;

  mtproto::DhHandshake dh_handshake_;
  std::shared_ptr<DhConfig> dh_config_;
  bool dh_config_query_sent_{false};
  bool dh_config_ready_{false};

  int32 duration_{0};
  int64 connection_id_{0};

  enum class State : int32 {
    Empty,
    SendRequestQuery,
    WaitRequestResult,
    SendAcceptQuery,
    WaitAcceptResult,
    SendConfirmQuery,
    WaitConfirmResult,
    Ready,
    SendDiscardQuery,
    WaitDiscardResult,
    Discarded
  } state_{State::Empty};
  bool is_accepted_{false};

  bool is_outgoing_{false};
  bool is_video_{false};
  UserId user_id_;
  InputGroupCallId input_group_call_id_;

  CallId local_call_id_;
  int64 call_id_{0};
  bool is_call_id_inited_{false};
  bool has_notification_{false};
  int64 call_access_hash_{0};
  UserId call_admin_user_id_;

  CallState call_state_;
  bool call_state_need_flush_{false};
  bool call_state_has_config_{false};

  NetQueryRef request_query_ref_;

  void update_call_inner(tl_object_ptr<telegram_api::phone_phoneCall> call);

  void update_conference_call(const telegram_api::object_ptr<telegram_api::inputGroupCall> &conference_call);

  tl_object_ptr<telegram_api::inputPhoneCall> get_input_phone_call(const char *source);
  bool load_dh_config();
  void on_dh_config(Result<std::shared_ptr<DhConfig>> r_dh_config, bool dummy);
  void do_load_dh_config(Promise<std::shared_ptr<DhConfig>> promise);

  Status do_update_call(const telegram_api::phoneCallEmpty &call);
  Status do_update_call(const telegram_api::phoneCallWaiting &call);
  Status do_update_call(const telegram_api::phoneCallRequested &call);
  Status do_update_call(const telegram_api::phoneCallAccepted &call);
  Status do_update_call(const telegram_api::phoneCall &call);
  Status do_update_call(const telegram_api::phoneCallDiscarded &call);

  void on_get_call_id();

  void send_received_query();
  void on_received_query_result(Result<NetQueryPtr> r_net_query);

  void try_send_request_query();
  void on_request_query_result(Result<NetQueryPtr> r_net_query);

  void try_send_accept_query();
  void on_accept_query_result(Result<NetQueryPtr> r_net_query);

  void try_send_confirm_query();
  void on_confirm_query_result(Result<NetQueryPtr> r_net_query);

  void try_send_discard_query();
  void on_discard_query_result(Result<NetQueryPtr> r_net_query);

  void on_begin_exchanging_key();

  void on_call_discarded(CallDiscardReason reason, bool need_rating, bool need_debug, bool is_video);

  void on_set_rating_query_result(Result<NetQueryPtr> r_net_query);

  void on_save_debug_query_result(Result<NetQueryPtr> r_net_query);

  void upload_log_file(FileUploadId file_upload_id, Promise<Unit> &&promise);

  void on_upload_log_file(FileUploadId file_upload_id, Promise<Unit> &&promise,
                          telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_log_file_error(FileUploadId file_upload_id, Promise<Unit> &&promise, Status status);

  void do_upload_log_file(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
                          Promise<Unit> &&promise);

  void on_save_log_query_result(FileUploadId file_upload_id, Promise<Unit> promise, Result<NetQueryPtr> r_net_query);

  void on_create_conference_call_result(Promise<Unit> promise, Result<NetQueryPtr> r_net_query);

  void on_get_call_config_result(Result<NetQueryPtr> r_net_query);

  void flush_call_state();

  static vector<string> get_emojis_fingerprint(const string &key, const string &g_a);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const State &state);

  void start_up() final;
  void loop() final;

  Container<Promise<NetQueryPtr>> container_;
  void on_result(NetQueryPtr query) final;
  void send_with_promise(NetQueryPtr query, Promise<NetQueryPtr> promise);

  void timeout_expired() final;
  void hangup() final;

  void on_error(Status status);
};

}  // namespace td
