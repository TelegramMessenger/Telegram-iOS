//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/MessageId.h"
#include "td/mtproto/MtprotoQuery.h"
#include "td/mtproto/PacketInfo.h"
#include "td/mtproto/RawConnection.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/logging.h"
#include "td/utils/Named.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StorerBase.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_parsers.h"

#include <utility>

namespace td {

extern int VERBOSITY_NAME(mtproto);

namespace mtproto_api {
class new_session_created;
class bad_msg_notification;
class bad_server_salt;
class msgs_ack;
class gzip_packed;
class pong;
class future_salts;
class msgs_state_info;
class msgs_all_info;
class msg_detailed_info;
class msg_new_detailed_info;
class DestroyAuthKeyRes;
class destroy_auth_key_ok;
class destroy_auth_key_fail;
class destroy_auth_key_none;
}  // namespace mtproto_api

namespace mtproto {

class AuthData;

class SessionConnection final
    : public Named
    , private RawConnection::Callback {
 public:
  enum class Mode : int32 { Tcp, Http, HttpLongPoll };
  SessionConnection(Mode mode, unique_ptr<RawConnection> raw_connection, AuthData *auth_data);
  SessionConnection(const SessionConnection &) = delete;
  SessionConnection &operator=(const SessionConnection &) = delete;
  SessionConnection(SessionConnection &&) = delete;
  SessionConnection &operator=(SessionConnection &&) = delete;
  ~SessionConnection() = default;

  PollableFdInfo &get_poll_info();
  unique_ptr<RawConnection> move_as_raw_connection();

  // Interface
  MessageId send_query(BufferSlice buffer, bool gzip_flag, MessageId message_id,
                       vector<MessageId> invoke_after_message_ids, bool use_quick_ack);

  std::pair<MessageId, BufferSlice> encrypted_bind(int64 perm_key, int64 nonce, int32 expires_at);

  void get_state_info(MessageId message_id);

  void resend_answer(MessageId message_id);

  void cancel_answer(MessageId message_id);

  void destroy_key();

  void set_online(bool online_flag, bool is_main);

  void force_ack();

  Slice get_debug_str() const {
    return raw_connection_ == nullptr ? Slice() : raw_connection_->extra().debug_str;
  }

  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual ~Callback() = default;

    virtual void on_connected() = 0;
    virtual void on_closed(Status status) = 0;

    virtual void on_server_salt_updated() = 0;
    virtual void on_server_time_difference_updated(bool force) = 0;

    virtual void on_new_session_created(uint64 unique_id, MessageId first_message_id) = 0;
    virtual void on_session_failed(Status status) = 0;

    virtual void on_container_sent(MessageId container_message_id, vector<MessageId> message_ids) = 0;
    virtual Status on_pong(double ping_time, double pong_time, double current_time) = 0;

    virtual Status on_update(BufferSlice packet) = 0;

    virtual void on_message_ack(MessageId message_id) = 0;
    virtual Status on_message_result_ok(MessageId message_id, BufferSlice packet, size_t original_size) = 0;
    virtual void on_message_result_error(MessageId message_id, int code, string message) = 0;
    virtual void on_message_failed(MessageId message_id, Status status) = 0;
    virtual void on_message_info(MessageId message_id, int32 state, MessageId answer_message_id, int32 answer_size,
                                 int32 source) = 0;

    virtual Status on_destroy_auth_key() = 0;
  };

  double flush(SessionConnection::Callback *callback);

  // NB: Do not call force_close after on_closed callback
  void force_close(SessionConnection::Callback *callback);

 private:
  static constexpr int ACK_DELAY = 30;                  // 30s
  static constexpr double QUERY_DELAY = 0.001;          // 0.001s
  static constexpr double RESEND_ANSWER_DELAY = 0.001;  // 0.001s

  struct MsgInfo {
    MessageId message_id;
    int32 seq_no;
    size_t size;
  };

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MsgInfo &info);

  bool online_flag_ = false;
  bool is_main_ = false;
  bool was_moved_ = false;

  double rtt() const {
    return max(2.0, raw_connection_->extra().rtt * 1.5 + 1);
  }

  double read_disconnect_delay() const {
    return online_flag_ ? rtt() * 3.5 : 135 + random_delay_;
  }

  double ping_disconnect_delay() const {
    return online_flag_ && is_main_ ? rtt() * 2.5 : 135 + random_delay_;
  }

  double ping_may_delay() const {
    return online_flag_ ? rtt() * 0.5 : 30 + random_delay_;
  }

  double ping_must_delay() const {
    return online_flag_ ? rtt() : 60 + random_delay_;
  }

  double http_max_wait() const {
    return 25.0;  // 25s. Longer could be closed by proxy
  }
  static constexpr int HTTP_MAX_AFTER = 10;  // 0.01s
  static constexpr int HTTP_MAX_DELAY = 30;  // 0.03s

  vector<MtprotoQuery> to_send_;
  vector<MessageId> to_ack_message_ids_;
  double force_send_at_ = 0;

  struct ServiceQuery {
    enum Type { GetStateInfo, ResendAnswer } type_;
    MessageId container_message_id_;
    vector<int64> msg_ids_;
  };
  vector<MessageId> to_resend_answer_message_ids_;
  vector<MessageId> to_cancel_answer_message_ids_;
  vector<MessageId> to_get_state_info_message_ids_;
  FlatHashMap<MessageId, ServiceQuery, MessageIdHash> service_queries_;

  // nobody cleans up this map. But it should be really small.
  FlatHashMap<MessageId, vector<MessageId>, MessageIdHash> container_to_service_message_id_;

  double random_delay_ = 0;
  double last_read_at_ = 0;
  double last_ping_at_ = 0;
  double last_pong_at_ = 0;
  double real_last_read_at_ = 0;
  double real_last_pong_at_ = 0;
  MessageId last_ping_message_id_;
  MessageId last_ping_container_message_id_;

  uint64 last_read_size_ = 0;
  uint64 last_write_size_ = 0;

  bool need_destroy_auth_key_ = false;
  bool sent_destroy_auth_key_ = false;
  double destroy_auth_key_send_time_ = 0.0;

  double flush_packet_at_ = 0;

  double last_get_future_salt_at_ = 0;
  enum { Init, Run, Fail, Closed } state_;
  Mode mode_;
  bool connected_flag_ = false;

  MessageId container_message_id_;
  MessageId main_message_id_;
  double created_at_ = 0;

  unique_ptr<RawConnection> raw_connection_;
  AuthData *const auth_data_;
  SessionConnection::Callback *callback_ = nullptr;
  BufferSlice *current_buffer_slice_ = nullptr;

  BufferSlice as_buffer_slice(Slice packet);
  auto set_buffer_slice(BufferSlice *buffer_slice) TD_WARN_UNUSED_RESULT {
    auto old_buffer_slice = current_buffer_slice_;
    current_buffer_slice_ = buffer_slice;
    return ScopeExit() + [&to = current_buffer_slice_, from = old_buffer_slice] {
      to = from;
    };
  }

  void reset_server_time_difference(MessageId message_id);

  static Status parse_message(TlParser &parser, MsgInfo *info, Slice *packet,
                              bool crypto_flag = true) TD_WARN_UNUSED_RESULT;
  Status parse_packet(TlParser &parser) TD_WARN_UNUSED_RESULT;
  Status on_packet_container(const MsgInfo &info, Slice packet) TD_WARN_UNUSED_RESULT;
  Status on_packet_rpc_result(const MsgInfo &info, Slice packet) TD_WARN_UNUSED_RESULT;

  template <class T>
  Status on_packet(const MsgInfo &info, const T &packet) TD_WARN_UNUSED_RESULT;

  Status on_packet(const MsgInfo &info,
                   const mtproto_api::new_session_created &new_session_created) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info,
                   const mtproto_api::bad_msg_notification &bad_msg_notification) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::bad_server_salt &bad_server_salt) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::msgs_ack &msgs_ack) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::gzip_packed &gzip_packed) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::pong &pong) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::future_salts &salts) TD_WARN_UNUSED_RESULT;

  Status on_msgs_state_info(const vector<int64> &msg_ids, Slice info) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::msgs_state_info &msgs_state_info) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::msgs_all_info &msgs_all_info) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::msg_detailed_info &msg_detailed_info) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info,
                   const mtproto_api::msg_new_detailed_info &msg_new_detailed_info) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info, const mtproto_api::destroy_auth_key_ok &destroy_auth_key) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info,
                   const mtproto_api::destroy_auth_key_none &destroy_auth_key) TD_WARN_UNUSED_RESULT;
  Status on_packet(const MsgInfo &info,
                   const mtproto_api::destroy_auth_key_fail &destroy_auth_key) TD_WARN_UNUSED_RESULT;
  Status on_destroy_auth_key(const mtproto_api::DestroyAuthKeyRes &destroy_auth_key);

  Status on_slice_packet(const MsgInfo &info, Slice packet) TD_WARN_UNUSED_RESULT;
  Status on_main_packet(const PacketInfo &packet_info, Slice packet) TD_WARN_UNUSED_RESULT;
  void on_message_failed(MessageId message_id, Status status);
  void on_message_failed_inner(MessageId message_id);

  void do_close(Status status);

  void send_ack(MessageId message_id);
  void send_crypto(const Storer &storer, uint64 quick_ack_token);
  void send_before(double tm);
  bool may_ping() const;
  bool must_ping() const;
  bool must_flush_packet();
  void flush_packet();

  Status init() TD_WARN_UNUSED_RESULT;
  Status do_flush() TD_WARN_UNUSED_RESULT;

  Status before_write() final TD_WARN_UNUSED_RESULT;
  Status on_raw_packet(const PacketInfo &packet_info, BufferSlice packet) final;
  Status on_quick_ack(uint64 quick_ack_token) final;
  void on_read(size_t size) final;
};

}  // namespace mtproto
}  // namespace td
