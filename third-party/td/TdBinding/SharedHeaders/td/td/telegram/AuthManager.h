//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/EmailVerification.h"
#include "td/telegram/net/NetActor.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/SendCodeHelper.h"
#include "td/telegram/SentEmailCode.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TermsOfService.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"
#include "td/actor/Timeout.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class AuthManager final : public NetActor {
 public:
  AuthManager(int32 api_id, const string &api_hash, ActorShared<> parent);

  bool is_bot() const {
    return is_bot_ || net_query_type_ == NetQueryType::BotAuthentication;
  }

  bool is_authorized() const;
  bool was_authorized() const;
  void get_state(uint64 query_id);

  void set_phone_number(uint64 query_id, string phone_number,
                        td_api::object_ptr<td_api::phoneNumberAuthenticationSettings> settings);
  void set_firebase_token(uint64 query_id, string token);
  void report_missing_code(uint64 query_id, string mobile_network_code);
  void set_email_address(uint64 query_id, string email_address);
  void resend_authentication_code(uint64 query_id, td_api::object_ptr<td_api::ResendCodeReason> &&reason);
  void check_email_code(uint64 query_id, EmailVerification &&code);
  void reset_email_address(uint64 query_id);
  void check_code(uint64 query_id, string code);
  void register_user(uint64 query_id, string first_name, string last_name, bool disable_notification);
  void request_qr_code_authentication(uint64 query_id, vector<UserId> other_user_ids);
  void check_bot_token(uint64 query_id, string bot_token);
  void check_password(uint64 query_id, string password);
  void request_password_recovery(uint64 query_id);
  void check_password_recovery_code(uint64 query_id, string code);
  void recover_password(uint64 query_id, string code, string new_password, string new_hint);
  void log_out(uint64 query_id);
  void delete_account(uint64 query_id, string reason, string password);

  void on_update_login_token();

  void on_authorization_lost(string source);
  void on_closing(bool destroy_flag);

  // can return nullptr if state isn't initialized yet
  tl_object_ptr<td_api::AuthorizationState> get_current_authorization_state_object() const;

 private:
  static constexpr size_t MAX_NAME_LENGTH = 64;  // server side limit

  enum class State : int32 {
    None,
    WaitPhoneNumber,
    WaitCode,
    WaitQrCodeConfirmation,
    WaitPassword,
    WaitRegistration,
    WaitEmailAddress,
    WaitEmailCode,
    Ok,
    LoggingOut,
    DestroyingKeys,
    Closing
  } state_ = State::None;

  enum class NetQueryType : int32 {
    None,
    SignIn,
    SignUp,
    SendCode,
    SendEmailCode,
    VerifyEmailAddress,
    ResetEmailAddress,
    RequestQrCode,
    ImportQrCode,
    GetPassword,
    CheckPassword,
    RequestPasswordRecovery,
    CheckPasswordRecoveryCode,
    RecoverPassword,
    RequestFirebaseSms,
    BotAuthentication,
    Authentication,
    LogOut,
    DeleteAccount
  };

  struct WaitPasswordState {
    string current_client_salt_;
    string current_server_salt_;
    int32 srp_g_ = 0;
    string srp_p_;
    string srp_B_;
    int64 srp_id_ = 0;
    string hint_;
    bool has_recovery_ = false;
    bool has_secure_values_ = false;
    string email_address_pattern_;

    template <class StorerT>
    void store(StorerT &storer) const;
    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct DbState;

  bool load_state();
  void save_state();

  ActorShared<> parent_;

  // STATE
  // from constructor
  int32 api_id_;
  string api_hash_;

  // State::WaitEmailAddress
  bool allow_apple_id_ = false;
  bool allow_google_id_ = false;

  // State::WaitEmailCode
  string email_address_;
  SentEmailCode email_code_info_;
  int32 reset_available_period_ = -1;
  int32 reset_pending_date_ = -1;
  EmailVerification email_code_;

  // State::WaitCode
  SendCodeHelper send_code_helper_;
  string code_;

  // State::WaitQrCodeConfirmation
  vector<UserId> other_user_ids_;
  string login_token_;
  double login_token_expires_at_ = 0.0;
  int32 imported_dc_id_ = -1;

  // State::WaitPassword
  string password_;

  // State::WaitRegistration
  TermsOfService terms_of_service_;

  // for bots
  string bot_token_;

  uint64 query_id_ = 0;

  WaitPasswordState wait_password_state_;

  string recovery_code_;
  string new_password_;
  string new_hint_;

  int32 login_code_retry_delay_ = 0;
  Timeout poll_export_login_code_timeout_;

  bool checking_password_ = false;
  bool was_qr_code_request_ = false;
  bool was_check_bot_token_ = false;
  bool is_bot_ = false;
  uint64 net_query_id_ = 0;
  NetQueryType net_query_type_ = NetQueryType::None;

  vector<uint64> pending_get_authorization_state_requests_;

  void on_new_query(uint64 query_id);
  void on_current_query_error(Status status);
  void on_current_query_ok();
  void start_net_query(NetQueryType net_query_type, NetQueryPtr net_query);

  static void on_update_login_token_static(void *td);
  void send_export_login_token_query();
  void set_login_token_expires_at(double login_token_expires_at);

  void do_delete_account(uint64 query_id, string reason,
                         Result<tl_object_ptr<telegram_api::InputCheckPasswordSRP>> r_input_password);

  void send_auth_sign_in_query();
  void send_log_out_query();
  void destroy_auth_keys();

  void on_account_banned() const;

  void on_sent_code(telegram_api::object_ptr<telegram_api::auth_SentCode> &&sent_code_ptr);

  void on_send_code_result(NetQueryPtr &&net_query);
  void on_send_email_code_result(NetQueryPtr &&net_query);
  void on_verify_email_address_result(NetQueryPtr &&net_query);
  void on_reset_email_address_result(NetQueryPtr &&net_query);
  void on_request_qr_code_result(NetQueryPtr &&net_query, bool is_import);
  void on_get_password_result(NetQueryPtr &&net_query);
  void on_request_password_recovery_result(NetQueryPtr &&net_query);
  void on_check_password_recovery_code_result(NetQueryPtr &&net_query);
  void on_request_firebase_sms_result(NetQueryPtr &&net_query);
  void on_authentication_result(NetQueryPtr &&net_query, bool is_from_current_query);
  void on_log_out_result(NetQueryPtr &&net_query);
  void on_delete_account_result(NetQueryPtr &&net_query);
  void on_get_login_token(tl_object_ptr<telegram_api::auth_LoginToken> login_token);
  void on_get_authorization(tl_object_ptr<telegram_api::auth_Authorization> auth_ptr);

  void on_result(NetQueryPtr net_query) final;

  void update_state(State new_state, bool should_save_state = true);
  tl_object_ptr<td_api::AuthorizationState> get_authorization_state_object(State authorization_state) const;

  static void send_ok(uint64 query_id);
  static void on_query_error(uint64 query_id, Status status);

  void start_up() final;
  void tear_down() final;
};

}  // namespace td
