//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/EmailVerification.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/NewPasswordState.h"
#include "td/telegram/SecureStorage.h"
#include "td/telegram/SentEmailCode.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/optional.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

namespace td {

struct TempPasswordState {
  bool has_temp_password = false;
  string temp_password;
  int32 valid_until = 0;  // unix_time

  tl_object_ptr<td_api::temporaryPasswordState> get_temporary_password_state_object() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    using ::td::store;
    CHECK(has_temp_password);
    store(temp_password, storer);
    store(valid_until, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using ::td::parse;
    has_temp_password = true;
    parse(temp_password, parser);
    parse(valid_until, parser);
  }
};

class PasswordManager final : public NetQueryCallback {
 public:
  using State = tl_object_ptr<td_api::passwordState>;
  using TempState = tl_object_ptr<td_api::temporaryPasswordState>;
  using ResetPasswordResult = tl_object_ptr<td_api::ResetPasswordResult>;
  using PasswordInputSettings = tl_object_ptr<telegram_api::account_passwordInputSettings>;

  explicit PasswordManager(ActorShared<> parent) : parent_(std::move(parent)) {
  }

  static tl_object_ptr<telegram_api::InputCheckPasswordSRP> get_input_check_password(Slice password, Slice client_salt,
                                                                                     Slice server_salt, int32 g,
                                                                                     Slice p, Slice B, int64 id);

  static Result<PasswordInputSettings> get_password_input_settings(string new_password, string new_hint,
                                                                   const NewPasswordState &state);

  void get_state(Promise<State> promise);
  void set_password(string current_password, string new_password, string new_hint, bool set_recovery_email_address,
                    string recovery_email_address, Promise<State> promise);

  void set_login_email_address(string new_login_email_address, Promise<SentEmailCode> promise);
  void resend_login_email_address_code(Promise<SentEmailCode> promise);
  void check_login_email_address_code(EmailVerification &&code, Promise<Unit> promise);

  void set_recovery_email_address(string password, string new_recovery_email_address, Promise<State> promise);
  void get_recovery_email_address(string password, Promise<tl_object_ptr<td_api::recoveryEmailAddress>> promise);
  void check_recovery_email_address_code(string code, Promise<State> promise);
  void resend_recovery_email_address_code(Promise<State> promise);
  void cancel_recovery_email_address_verification(Promise<State> promise);

  void send_email_address_verification_code(string email, Promise<SentEmailCode> promise);
  void resend_email_address_verification_code(Promise<SentEmailCode> promise);
  void check_email_address_verification_code(string code, Promise<Unit> promise);

  void request_password_recovery(Promise<SentEmailCode> promise);
  void check_password_recovery_code(string code, Promise<Unit> promise);
  void recover_password(string code, string new_password, string new_hint, Promise<State> promise);

  void reset_password(Promise<ResetPasswordResult> promise);
  void cancel_password_reset(Promise<Unit> promise);

  void get_secure_secret(string password, Promise<secure_storage::Secret> promise);
  void get_input_check_password_srp(string password,
                                    Promise<tl_object_ptr<telegram_api::InputCheckPasswordSRP>> &&promise);

  void get_temp_password_state(Promise<TempState> promise) /*const*/;
  void create_temp_password(string password, int32 timeout, Promise<TempState> promise);
  void drop_temp_password();
  void drop_cached_secret();

  static TempPasswordState get_temp_password_state_sync();

 private:
  ActorShared<> parent_;

  struct PasswordState {
    bool has_password = false;
    string password_hint;
    bool has_recovery_email_address = false;
    bool has_secure_values = false;
    SentEmailCode unconfirmed_recovery_email_code;
    string login_email_pattern;
    int32 pending_reset_date = 0;

    string current_client_salt;
    string current_server_salt;
    int32 current_srp_g = 0;
    string current_srp_p;
    string current_srp_B;
    int64 current_srp_id = 0;

    NewPasswordState new_state;

    State get_password_state_object() const {
      return td_api::make_object<td_api::passwordState>(
          has_password, password_hint, has_recovery_email_address, has_secure_values,
          unconfirmed_recovery_email_code.get_email_address_authentication_code_info_object(), login_email_pattern,
          pending_reset_date);
    }
  };

  struct PasswordPrivateState {
    string email;
    optional<secure_storage::Secret> secret;
  };

  struct PasswordFullState {
    PasswordState state;
    PasswordPrivateState private_state;
  };

  struct UpdateSettings {
    string current_password;

    bool update_password = false;
    string new_password;
    string new_hint;

    bool update_secure_secret = false;

    bool update_recovery_email_address = false;
    string recovery_email_address;
  };

  optional<secure_storage::Secret> secret_;
  double secret_expire_time_ = 0;

  TempPasswordState temp_password_state_;
  Promise<TempState> create_temp_password_promise_;

  string last_set_login_email_address_;
  string last_verified_email_address_;

  int32 last_code_length_ = 0;

  static Result<secure_storage::Secret> decrypt_secure_secret(
      Slice password, tl_object_ptr<telegram_api::SecurePasswordKdfAlgo> algo_ptr, Slice secret, int64 secret_id);

  static BufferSlice calc_password_hash(Slice password, Slice client_salt, Slice server_salt);

  static Result<BufferSlice> calc_password_srp_hash(Slice password, Slice client_salt, Slice server_salt, int32 g,
                                                    Slice p);

  static tl_object_ptr<telegram_api::InputCheckPasswordSRP> get_input_check_password(Slice password,
                                                                                     const PasswordState &state);

  static Result<PasswordInputSettings> get_password_input_settings(const UpdateSettings &update_settings,
                                                                   bool has_password, const NewPasswordState &state,
                                                                   const PasswordPrivateState *private_state);

  void do_recover_password(string code, PasswordInputSettings &&new_settings, Promise<State> &&promise);

  void update_password_settings(UpdateSettings update_settings, Promise<State> promise);
  void do_update_password_settings(UpdateSettings update_settings, PasswordFullState full_state, Promise<bool> promise);
  void do_update_password_settings_impl(UpdateSettings update_settings, PasswordState state,
                                        PasswordPrivateState private_state, Promise<bool> promise);
  void on_get_code_length(int32 code_length);
  void do_get_state(Promise<PasswordState> promise);
  void get_full_state(string password, Promise<PasswordFullState> promise);
  void do_get_secure_secret(bool allow_recursive, string password, Promise<secure_storage::Secret> promise);
  void do_get_full_state(string password, PasswordState state, Promise<PasswordFullState> promise);
  void cache_secret(secure_storage::Secret secret);

  void do_create_temp_password(string password, int32 timeout, PasswordState &&password_state,
                               Promise<TempPasswordState> promise);
  void on_finish_create_temp_password(Result<TempPasswordState> result, bool dummy);

  void on_result(NetQueryPtr query) final;

  void start_up() final;
  void timeout_expired() final;
  void hangup() final;

  Container<Promise<NetQueryPtr>> container_;
  void send_with_promise(NetQueryPtr query, Promise<NetQueryPtr> promise);
};

}  // namespace td
