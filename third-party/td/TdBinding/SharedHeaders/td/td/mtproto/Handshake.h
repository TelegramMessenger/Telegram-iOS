//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/AuthKey.h"
#include "td/mtproto/RSA.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StorerBase.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/UInt.h"

namespace td {
namespace mtproto {

class DhCallback;

class AuthKeyHandshakeContext {
 public:
  virtual ~AuthKeyHandshakeContext() = default;
  virtual DhCallback *get_dh_callback() = 0;
  virtual PublicRsaKeyInterface *get_public_rsa_key_interface() = 0;
};

class AuthKeyHandshake {
 public:
  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual ~Callback() = default;
    virtual void send_no_crypto(const Storer &storer) = 0;
  };

  AuthKeyHandshake(int32 dc_id, int32 expires_in);

  void set_timeout_in(double timeout_in);

  bool is_ready_for_finish() const;

  void on_finish();

  void resume(Callback *connection);

  Status on_message(Slice message, Callback *connection, AuthKeyHandshakeContext *context) TD_WARN_UNUSED_RESULT;

  void clear();

  const AuthKey &get_auth_key() const {
    return auth_key_;
  }

  AuthKey release_auth_key() {
    return std::move(auth_key_);
  }

  double get_server_time_diff() const {
    return server_time_diff_;
  }

  uint64 get_server_salt() const {
    return server_salt_;
  }

 private:
  enum class State : int32 { Start, ResPQ, ServerDHParams, DHGenResponse, Finish };
  State state_ = State::Start;
  enum class Mode : int32 { Main, Temp };
  Mode mode_ = Mode::Main;
  int32 dc_id_ = 0;
  int32 expires_in_ = 0;
  double expires_at_ = 0;

  double start_time_ = 0;
  double timeout_in_ = 0;

  AuthKey auth_key_;
  double server_time_diff_ = 0;
  uint64 server_salt_ = 0;

  UInt128 nonce_;
  UInt128 server_nonce_;
  UInt256 new_nonce_;

  string last_query_;

  template <class T>
  static string store_object(const T &object);

  void send(Callback *connection, const Storer &storer);
  static void do_send(Callback *connection, const Storer &storer);

  Status on_start(Callback *connection) TD_WARN_UNUSED_RESULT;
  Status on_res_pq(Slice message, Callback *connection, PublicRsaKeyInterface *public_rsa_key) TD_WARN_UNUSED_RESULT;
  Status on_server_dh_params(Slice message, Callback *connection, DhCallback *dh_callback) TD_WARN_UNUSED_RESULT;
  Status on_dh_gen_response(Slice message, Callback *connection) TD_WARN_UNUSED_RESULT;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const State &state);
};

}  // namespace mtproto
}  // namespace td
