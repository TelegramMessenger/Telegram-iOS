//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AuthManager.h"

#include "td/telegram/AttachMenuManager.h"
#include "td/telegram/AuthManager.hpp"
#include "td/telegram/ConfigManager.h"
#include "td/telegram/DialogFilterManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/NewPasswordState.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/OnlineManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/PasswordManager.h"
#include "td/telegram/PromoDataManager.h"
#include "td/telegram/ReactionManager.h"
#include "td/telegram/SendCodeHelper.hpp"
#include "td/telegram/StateManager.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TermsOfService.hpp"
#include "td/telegram/TermsOfServiceManager.h"
#include "td/telegram/ThemeManager.h"
#include "td/telegram/TopDialogManager.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Version.h"

#include "td/utils/base64.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

namespace td {

struct AuthManager::DbState {
  State state_;
  int32 api_id_;
  string api_hash_;
  double expires_at_;

  // WaitEmailAddress and WaitEmailCode
  bool allow_apple_id_ = false;
  bool allow_google_id_ = false;

  // WaitEmailCode
  string email_address_;
  SentEmailCode email_code_info_;
  int32 reset_available_period_ = -1;
  int32 reset_pending_date_ = -1;

  // WaitEmailAddress, WaitEmailCode, WaitCode and WaitRegistration
  SendCodeHelper send_code_helper_;

  // WaitQrCodeConfirmation
  vector<UserId> other_user_ids_;
  string login_token_;
  double login_token_expires_at_ = 0;

  // WaitPassword
  WaitPasswordState wait_password_state_;

  // WaitRegistration
  TermsOfService terms_of_service_;

  DbState() = default;

  static DbState wait_email_address(int32 api_id, string api_hash, bool allow_apple_id, bool allow_google_id,
                                    SendCodeHelper send_code_helper) {
    DbState state(State::WaitEmailAddress, api_id, std::move(api_hash));
    state.send_code_helper_ = std::move(send_code_helper);
    state.allow_apple_id_ = allow_apple_id;
    state.allow_google_id_ = allow_google_id;
    return state;
  }

  static DbState wait_email_code(int32 api_id, string api_hash, bool allow_apple_id, bool allow_google_id,
                                 string email_address, SentEmailCode email_code_info, int32 reset_available_period,
                                 int32 reset_pending_date, SendCodeHelper send_code_helper) {
    DbState state(State::WaitEmailCode, api_id, std::move(api_hash));
    state.send_code_helper_ = std::move(send_code_helper);
    state.allow_apple_id_ = allow_apple_id;
    state.allow_google_id_ = allow_google_id;
    state.email_address_ = std::move(email_address);
    state.email_code_info_ = std::move(email_code_info);
    state.reset_available_period_ = reset_available_period;
    state.reset_pending_date_ = reset_pending_date;
    return state;
  }

  static DbState wait_code(int32 api_id, string api_hash, SendCodeHelper send_code_helper) {
    DbState state(State::WaitCode, api_id, std::move(api_hash));
    state.send_code_helper_ = std::move(send_code_helper);
    return state;
  }

  static DbState wait_qr_code_confirmation(int32 api_id, string api_hash, vector<UserId> other_user_ids,
                                           string login_token, double login_token_expires_at) {
    DbState state(State::WaitQrCodeConfirmation, api_id, std::move(api_hash));
    state.other_user_ids_ = std::move(other_user_ids);
    state.login_token_ = std::move(login_token);
    state.login_token_expires_at_ = login_token_expires_at;
    return state;
  }

  static DbState wait_password(int32 api_id, string api_hash, WaitPasswordState wait_password_state) {
    DbState state(State::WaitPassword, api_id, std::move(api_hash));
    state.wait_password_state_ = std::move(wait_password_state);
    return state;
  }

  static DbState wait_registration(int32 api_id, string api_hash, SendCodeHelper send_code_helper,
                                   TermsOfService terms_of_service) {
    DbState state(State::WaitRegistration, api_id, std::move(api_hash));
    state.send_code_helper_ = std::move(send_code_helper);
    state.terms_of_service_ = std::move(terms_of_service);
    return state;
  }

  template <class StorerT>
  void store(StorerT &storer) const;
  template <class ParserT>
  void parse(ParserT &parser);

 private:
  DbState(State state, int32 api_id, string &&api_hash)
      : state_(state), api_id_(api_id), api_hash_(std::move(api_hash)) {
    auto state_timeout = [state] {
      switch (state) {
        case State::WaitPassword:
        case State::WaitRegistration:
          return 86400;
        case State::WaitEmailAddress:
        case State::WaitEmailCode:
        case State::WaitCode:
        case State::WaitQrCodeConfirmation:
          return 5 * 60;
        default:
          UNREACHABLE();
          return 0;
      }
    }();
    expires_at_ = Time::now() + state_timeout;
  }
};

template <class StorerT>
void AuthManager::DbState::store(StorerT &storer) const {
  using td::store;
  bool has_terms_of_service = !terms_of_service_.get_id().empty();
  bool is_pbkdf2_supported = true;
  bool is_srp_supported = true;
  bool is_wait_registration_supported = true;
  bool is_wait_registration_stores_phone_number = true;
  bool is_wait_qr_code_confirmation_supported = true;
  bool is_time_store_supported = true;
  bool is_reset_email_address_supported = true;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_terms_of_service);
  STORE_FLAG(is_pbkdf2_supported);
  STORE_FLAG(is_srp_supported);
  STORE_FLAG(is_wait_registration_supported);
  STORE_FLAG(is_wait_registration_stores_phone_number);
  STORE_FLAG(is_wait_qr_code_confirmation_supported);
  STORE_FLAG(allow_apple_id_);
  STORE_FLAG(allow_google_id_);
  STORE_FLAG(is_time_store_supported);
  STORE_FLAG(is_reset_email_address_supported);
  END_STORE_FLAGS();
  store(state_, storer);
  store(api_id_, storer);
  store(api_hash_, storer);
  store_time(expires_at_, storer);

  if (has_terms_of_service) {
    store(terms_of_service_, storer);
  }

  if (state_ == State::WaitEmailAddress) {
    store(send_code_helper_, storer);
  } else if (state_ == State::WaitEmailCode) {
    store(send_code_helper_, storer);
    store(email_address_, storer);
    store(email_code_info_, storer);
    store(reset_available_period_, storer);
    store(reset_pending_date_, storer);
  } else if (state_ == State::WaitCode) {
    store(send_code_helper_, storer);
  } else if (state_ == State::WaitQrCodeConfirmation) {
    store(other_user_ids_, storer);
    store(login_token_, storer);
    store_time(login_token_expires_at_, storer);
  } else if (state_ == State::WaitPassword) {
    store(wait_password_state_, storer);
  } else if (state_ == State::WaitRegistration) {
    store(send_code_helper_, storer);
  } else {
    UNREACHABLE();
  }
}

template <class ParserT>
void AuthManager::DbState::parse(ParserT &parser) {
  using td::parse;
  bool has_terms_of_service = false;
  bool is_pbkdf2_supported = false;
  bool is_srp_supported = false;
  bool is_wait_registration_supported = false;
  bool is_wait_registration_stores_phone_number = false;
  bool is_wait_qr_code_confirmation_supported = false;
  bool is_time_store_supported = false;
  bool is_reset_email_address_supported = false;
  if (parser.version() >= static_cast<int32>(Version::AddTermsOfService)) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_terms_of_service);
    PARSE_FLAG(is_pbkdf2_supported);
    PARSE_FLAG(is_srp_supported);
    PARSE_FLAG(is_wait_registration_supported);
    PARSE_FLAG(is_wait_registration_stores_phone_number);
    PARSE_FLAG(is_wait_qr_code_confirmation_supported);
    PARSE_FLAG(allow_apple_id_);
    PARSE_FLAG(allow_google_id_);
    PARSE_FLAG(is_time_store_supported);
    PARSE_FLAG(is_reset_email_address_supported);
    END_PARSE_FLAGS();
  }
  if (!is_reset_email_address_supported) {
    return parser.set_error("Have no reset email address support");
  }
  CHECK(is_pbkdf2_supported);
  CHECK(is_srp_supported);
  CHECK(is_wait_registration_supported);
  CHECK(is_wait_registration_stores_phone_number);
  CHECK(is_wait_qr_code_confirmation_supported);
  CHECK(is_time_store_supported);

  parse(state_, parser);
  parse(api_id_, parser);
  parse(api_hash_, parser);
  parse_time(expires_at_, parser);

  if (has_terms_of_service) {
    parse(terms_of_service_, parser);
  }

  if (state_ == State::WaitEmailAddress) {
    parse(send_code_helper_, parser);
  } else if (state_ == State::WaitEmailCode) {
    parse(send_code_helper_, parser);
    parse(email_address_, parser);
    parse(email_code_info_, parser);
    parse(reset_available_period_, parser);
    parse(reset_pending_date_, parser);
  } else if (state_ == State::WaitCode) {
    parse(send_code_helper_, parser);
  } else if (state_ == State::WaitQrCodeConfirmation) {
    parse(other_user_ids_, parser);
    parse(login_token_, parser);
    parse_time(login_token_expires_at_, parser);
  } else if (state_ == State::WaitPassword) {
    parse(wait_password_state_, parser);
  } else if (state_ == State::WaitRegistration) {
    parse(send_code_helper_, parser);
  } else {
    parser.set_error(PSTRING() << "Unexpected " << tag("state", static_cast<int32>(state_)));
  }
}

AuthManager::AuthManager(int32 api_id, const string &api_hash, ActorShared<> parent)
    : parent_(std::move(parent)), api_id_(api_id), api_hash_(api_hash) {
  string auth_str = G()->td_db()->get_binlog_pmc()->get("auth");
  if (auth_str == "ok") {
    string is_bot_str = G()->td_db()->get_binlog_pmc()->get("auth_is_bot");
    if (is_bot_str == "true") {
      is_bot_ = true;
    }
    auto my_id = UserManager::load_my_id();
    if (my_id.is_valid()) {
      // just in case
      LOG(INFO) << "Logged in as " << my_id;
      td_->option_manager_->set_option_integer("my_id", my_id.get());
      update_state(State::Ok);
    } else {
      LOG(ERROR) << "Restore unknown my_id";
      UserManager::send_get_me_query(td_,
                                     PromiseCreator::lambda([this](Result<Unit> result) { update_state(State::Ok); }));
    }
    G()->net_query_dispatcher().check_authorization_is_ok();
  } else if (auth_str == "logout") {
    LOG(WARNING) << "Continue to log out";
    update_state(State::LoggingOut);
  } else if (auth_str == "destroy") {
    LOG(WARNING) << "Continue to destroy auth keys";
    update_state(State::DestroyingKeys);
  } else {
    if (!load_state()) {
      update_state(State::WaitPhoneNumber);
    }
  }
}

void AuthManager::start_up() {
  if (state_ == State::LoggingOut) {
    send_log_out_query();
  } else if (state_ == State::DestroyingKeys) {
    G()->net_query_dispatcher().destroy_auth_keys(PromiseCreator::lambda([](Result<Unit> result) {
      if (result.is_ok()) {
        send_closure_later(G()->td(), &Td::destroy);
      } else {
        LOG(INFO) << "Failed to destroy auth keys";
      }
    }));
  }
}
void AuthManager::tear_down() {
  parent_.reset();
}

bool AuthManager::was_authorized() const {
  return state_ == State::Ok || state_ == State::LoggingOut || state_ == State::DestroyingKeys ||
         state_ == State::Closing;
}

bool AuthManager::is_authorized() const {
  return state_ == State::Ok;
}

tl_object_ptr<td_api::AuthorizationState> AuthManager::get_authorization_state_object(State authorization_state) const {
  switch (authorization_state) {
    case State::WaitPhoneNumber:
      return make_tl_object<td_api::authorizationStateWaitPhoneNumber>();
    case State::WaitEmailAddress:
      return make_tl_object<td_api::authorizationStateWaitEmailAddress>(allow_apple_id_, allow_google_id_);
    case State::WaitEmailCode: {
      td_api::object_ptr<td_api::EmailAddressResetState> reset_state;
      if (reset_pending_date_ > 0) {
        reset_state =
            td_api::make_object<td_api::emailAddressResetStatePending>(max(reset_pending_date_ - G()->unix_time(), 0));
      } else if (reset_available_period_ >= 0) {
        reset_state = td_api::make_object<td_api::emailAddressResetStateAvailable>(reset_available_period_);
      }
      return make_tl_object<td_api::authorizationStateWaitEmailCode>(
          allow_apple_id_, allow_google_id_, email_code_info_.get_email_address_authentication_code_info_object(),
          std::move(reset_state));
    }
    case State::WaitCode:
      return send_code_helper_.get_authorization_state_wait_code();
    case State::WaitQrCodeConfirmation:
      return make_tl_object<td_api::authorizationStateWaitOtherDeviceConfirmation>("tg://login?token=" +
                                                                                   base64url_encode(login_token_));
    case State::WaitPassword:
      return make_tl_object<td_api::authorizationStateWaitPassword>(
          wait_password_state_.hint_, wait_password_state_.has_recovery_, wait_password_state_.has_secure_values_,
          wait_password_state_.email_address_pattern_);
    case State::WaitRegistration:
      return make_tl_object<td_api::authorizationStateWaitRegistration>(
          terms_of_service_.get_terms_of_service_object());
    case State::Ok:
      return make_tl_object<td_api::authorizationStateReady>();
    case State::LoggingOut:
    case State::DestroyingKeys:
      return make_tl_object<td_api::authorizationStateLoggingOut>();
    case State::Closing:
      return make_tl_object<td_api::authorizationStateClosing>();
    case State::None:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

tl_object_ptr<td_api::AuthorizationState> AuthManager::get_current_authorization_state_object() const {
  if (state_ == State::None) {
    return nullptr;
  } else {
    return get_authorization_state_object(state_);
  }
}

void AuthManager::get_state(uint64 query_id) {
  if (state_ == State::None) {
    pending_get_authorization_state_requests_.push_back(query_id);
  } else {
    send_closure(G()->td(), &Td::send_result, query_id, get_authorization_state_object(state_));
  }
}

void AuthManager::check_bot_token(uint64 query_id, string bot_token) {
  if (state_ == State::WaitPhoneNumber && net_query_id_ == 0) {
    // can ignore previous checks
    was_check_bot_token_ = false;  // TODO can we remove was_check_bot_token_?
  }
  if (state_ != State::WaitPhoneNumber) {
    return on_query_error(query_id, Status::Error(400, "Call to checkAuthenticationBotToken unexpected"));
  }
  if (!send_code_helper_.phone_number().empty() || was_qr_code_request_) {
    return on_query_error(
        query_id, Status::Error(400, "Cannot set bot token after authentication began. You need to log out first"));
  }
  if (was_check_bot_token_ && bot_token_ != bot_token) {
    return on_query_error(query_id, Status::Error(400, "Cannot change bot token. You need to log out first"));
  }

  on_new_query(query_id);
  bot_token_ = std::move(bot_token);
  was_check_bot_token_ = true;
  start_net_query(NetQueryType::BotAuthentication,
                  G()->net_query_creator().create_unauth(
                      telegram_api::auth_importBotAuthorization(0, api_id_, api_hash_, bot_token_)));
}

void AuthManager::request_qr_code_authentication(uint64 query_id, vector<UserId> other_user_ids) {
  if (state_ != State::WaitPhoneNumber) {
    if ((state_ == State::WaitEmailAddress || state_ == State::WaitEmailCode || state_ == State::WaitCode ||
         state_ == State::WaitPassword || state_ == State::WaitRegistration) &&
        net_query_id_ == 0) {
      // ok
    } else {
      return on_query_error(query_id, Status::Error(400, "Call to requestQrCodeAuthentication unexpected"));
    }
  }
  if (was_check_bot_token_) {
    return on_query_error(
        query_id,
        Status::Error(400,
                      "Cannot request QR code authentication after bot token was entered. You need to log out first"));
  }
  for (auto &other_user_id : other_user_ids) {
    if (!other_user_id.is_valid()) {
      return on_query_error(query_id, Status::Error(400, "Invalid user_id among other user_ids"));
    }
  }

  other_user_ids_ = std::move(other_user_ids);
  send_code_helper_ = SendCodeHelper();
  terms_of_service_ = TermsOfService();
  was_qr_code_request_ = true;

  on_new_query(query_id);

  send_export_login_token_query();
}

void AuthManager::send_export_login_token_query() {
  poll_export_login_code_timeout_.cancel_timeout();
  start_net_query(NetQueryType::RequestQrCode,
                  G()->net_query_creator().create_unauth(telegram_api::auth_exportLoginToken(
                      api_id_, api_hash_, UserId::get_input_user_ids(other_user_ids_))));
}

void AuthManager::set_login_token_expires_at(double login_token_expires_at) {
  login_token_expires_at_ = login_token_expires_at;
  poll_export_login_code_timeout_.cancel_timeout();
  poll_export_login_code_timeout_.set_callback(std::move(on_update_login_token_static));
  poll_export_login_code_timeout_.set_callback_data(static_cast<void *>(td_));
  poll_export_login_code_timeout_.set_timeout_at(login_token_expires_at_);
}

void AuthManager::on_update_login_token_static(void *td) {
  if (G()->close_flag()) {
    return;
  }
  static_cast<Td *>(td)->auth_manager_->on_update_login_token();
}

void AuthManager::on_update_login_token() {
  if (G()->close_flag()) {
    return;
  }
  if (state_ != State::WaitQrCodeConfirmation) {
    return;
  }

  send_export_login_token_query();
}

void AuthManager::set_phone_number(uint64 query_id, string phone_number,
                                   td_api::object_ptr<td_api::phoneNumberAuthenticationSettings> settings) {
  if (state_ != State::WaitPhoneNumber) {
    if ((state_ == State::WaitEmailAddress || state_ == State::WaitEmailCode || state_ == State::WaitCode ||
         state_ == State::WaitPassword || state_ == State::WaitRegistration) &&
        net_query_id_ == 0) {
      // ok
    } else {
      return on_query_error(query_id, Status::Error(400, "Call to setAuthenticationPhoneNumber unexpected"));
    }
  }
  if (was_check_bot_token_) {
    return on_query_error(
        query_id, Status::Error(400, "Cannot set phone number after bot token was entered. You need to log out first"));
  }
  if (phone_number.empty()) {
    return on_query_error(query_id, Status::Error(400, "Phone number must be non-empty"));
  }

  other_user_ids_.clear();
  was_qr_code_request_ = false;

  allow_apple_id_ = false;
  allow_google_id_ = false;
  email_address_ = {};
  email_code_info_ = {};
  reset_available_period_ = -1;
  reset_pending_date_ = -1;
  code_ = string();
  email_code_ = {};

  if (send_code_helper_.phone_number() != phone_number) {
    send_code_helper_ = SendCodeHelper();
    terms_of_service_ = TermsOfService();
  }

  on_new_query(query_id);

  start_net_query(NetQueryType::SendCode, G()->net_query_creator().create_unauth(send_code_helper_.send_code(
                                              std::move(phone_number), settings, api_id_, api_hash_)));
}

void AuthManager::set_firebase_token(uint64 query_id, string token) {
  if (state_ != State::WaitCode) {
    return on_query_error(query_id, Status::Error(400, "Call to sendAuthenticationFirebaseSms unexpected"));
  }
  on_new_query(query_id);

  start_net_query(NetQueryType::RequestFirebaseSms,
                  G()->net_query_creator().create_unauth(send_code_helper_.request_firebase_sms(token)));
}

void AuthManager::report_missing_code(uint64 query_id, string mobile_network_code) {
  if (state_ != State::WaitCode) {
    return on_query_error(query_id, Status::Error(400, "Call to reportAuthenticationCodeMissing unexpected"));
  }
  G()->net_query_dispatcher().dispatch_with_callback(
      G()->net_query_creator().create_unauth(send_code_helper_.report_missing_code(mobile_network_code)),
      actor_shared(this));
}

void AuthManager::set_email_address(uint64 query_id, string email_address) {
  if (state_ != State::WaitEmailAddress) {
    if (state_ == State::WaitEmailCode && net_query_id_ == 0) {
      // ok
    } else {
      return on_query_error(query_id, Status::Error(400, "Call to setAuthenticationEmailAddress unexpected"));
    }
  }
  if (email_address.empty()) {
    return on_query_error(query_id, Status::Error(400, "Email address must be non-empty"));
  }

  email_address_ = std::move(email_address);

  on_new_query(query_id);

  start_net_query(NetQueryType::SendEmailCode,
                  G()->net_query_creator().create_unauth(send_code_helper_.send_verify_email_code(email_address_)));
}

void AuthManager::resend_authentication_code(uint64 query_id, td_api::object_ptr<td_api::ResendCodeReason> &&reason) {
  if (state_ != State::WaitCode) {
    if (state_ == State::WaitEmailCode) {
      on_new_query(query_id);
      start_net_query(NetQueryType::SendEmailCode,
                      G()->net_query_creator().create_unauth(send_code_helper_.send_verify_email_code(email_address_)));
      return;
    }

    return on_query_error(query_id, Status::Error(400, "Call to resendAuthenticationCode unexpected"));
  }

  auto r_resend_code = send_code_helper_.resend_code(std::move(reason));
  if (r_resend_code.is_error()) {
    return on_query_error(query_id, r_resend_code.move_as_error());
  }

  on_new_query(query_id);

  start_net_query(NetQueryType::SendCode, G()->net_query_creator().create_unauth(r_resend_code.move_as_ok()));
}

void AuthManager::send_auth_sign_in_query() {
  bool is_email = !email_code_.is_empty();
  int32 flags =
      is_email ? telegram_api::auth_signIn::EMAIL_VERIFICATION_MASK : telegram_api::auth_signIn::PHONE_CODE_MASK;
  start_net_query(NetQueryType::SignIn,
                  G()->net_query_creator().create_unauth(telegram_api::auth_signIn(
                      flags, send_code_helper_.phone_number().str(), send_code_helper_.phone_code_hash().str(), code_,
                      is_email ? email_code_.get_input_email_verification() : nullptr)));
}

void AuthManager::check_email_code(uint64 query_id, EmailVerification &&code) {
  if (code.is_empty()) {
    return on_query_error(query_id, Status::Error(400, "Code must be non-empty"));
  }
  if (state_ != State::WaitEmailCode && !(state_ == State::WaitEmailAddress && code.is_email_code())) {
    return on_query_error(query_id, Status::Error(400, "Call to checkAuthenticationEmailCode unexpected"));
  }

  code_ = string();
  email_code_ = std::move(code);

  on_new_query(query_id);
  if (email_address_.empty()) {
    send_auth_sign_in_query();
  } else {
    start_net_query(
        NetQueryType::VerifyEmailAddress,
        G()->net_query_creator().create_unauth(telegram_api::account_verifyEmail(
            send_code_helper_.get_email_verify_purpose_login_setup(), email_code_.get_input_email_verification())));
  }
}

void AuthManager::reset_email_address(uint64 query_id) {
  if (state_ != State::WaitEmailCode) {
    return on_query_error(query_id, Status::Error(400, "Call to resetAuthenticationEmailAddress unexpected"));
  }

  on_new_query(query_id);
  start_net_query(NetQueryType::ResetEmailAddress,
                  G()->net_query_creator().create_unauth(telegram_api::auth_resetLoginEmail(
                      send_code_helper_.phone_number().str(), send_code_helper_.phone_code_hash().str())));
}

void AuthManager::check_code(uint64 query_id, string code) {
  if (state_ != State::WaitCode) {
    return on_query_error(query_id, Status::Error(400, "Call to checkAuthenticationCode unexpected"));
  }

  code_ = std::move(code);
  email_code_ = {};

  on_new_query(query_id);
  send_auth_sign_in_query();
}

void AuthManager::register_user(uint64 query_id, string first_name, string last_name, bool disable_notification) {
  if (state_ != State::WaitRegistration) {
    return on_query_error(query_id, Status::Error(400, "Call to registerUser unexpected"));
  }

  on_new_query(query_id);
  first_name = clean_name(first_name, MAX_NAME_LENGTH);
  if (first_name.empty()) {
    return on_current_query_error(Status::Error(400, "First name must be non-empty"));
  }

  last_name = clean_name(last_name, MAX_NAME_LENGTH);
  int32 flags = 0;
  if (disable_notification) {
    flags |= telegram_api::auth_signUp::NO_JOINED_NOTIFICATIONS_MASK;
  }
  start_net_query(NetQueryType::SignUp, G()->net_query_creator().create_unauth(telegram_api::auth_signUp(
                                            flags, false /*ignored*/, send_code_helper_.phone_number().str(),
                                            send_code_helper_.phone_code_hash().str(), first_name, last_name)));
}

void AuthManager::check_password(uint64 query_id, string password) {
  if (state_ != State::WaitPassword) {
    return on_query_error(query_id, Status::Error(400, "Call to checkAuthenticationPassword unexpected"));
  }

  LOG(INFO) << "Have SRP ID " << wait_password_state_.srp_id_;
  on_new_query(query_id);
  checking_password_ = true;
  password_ = std::move(password);
  recovery_code_.clear();
  new_password_.clear();
  new_hint_.clear();
  start_net_query(NetQueryType::GetPassword,
                  G()->net_query_creator().create_unauth(telegram_api::account_getPassword()));
}

void AuthManager::request_password_recovery(uint64 query_id) {
  if (state_ != State::WaitPassword) {
    return on_query_error(query_id, Status::Error(400, "Call to requestAuthenticationPasswordRecovery unexpected"));
  }

  on_new_query(query_id);
  start_net_query(NetQueryType::RequestPasswordRecovery,
                  G()->net_query_creator().create_unauth(telegram_api::auth_requestPasswordRecovery()));
}

void AuthManager::check_password_recovery_code(uint64 query_id, string code) {
  if (state_ != State::WaitPassword) {
    return on_query_error(query_id, Status::Error(400, "Call to checkAuthenticationPasswordRecoveryCode unexpected"));
  }

  on_new_query(query_id);
  start_net_query(NetQueryType::CheckPasswordRecoveryCode,
                  G()->net_query_creator().create_unauth(telegram_api::auth_checkRecoveryPassword(code)));
}

void AuthManager::recover_password(uint64 query_id, string code, string new_password, string new_hint) {
  if (state_ != State::WaitPassword) {
    return on_query_error(query_id, Status::Error(400, "Call to recoverAuthenticationPassword unexpected"));
  }

  on_new_query(query_id);
  checking_password_ = true;
  if (!new_password.empty()) {
    password_.clear();
    recovery_code_ = std::move(code);
    new_password_ = std::move(new_password);
    new_hint_ = std::move(new_hint);
    start_net_query(NetQueryType::GetPassword,
                    G()->net_query_creator().create_unauth(telegram_api::account_getPassword()));
    return;
  }
  start_net_query(NetQueryType::RecoverPassword,
                  G()->net_query_creator().create_unauth(telegram_api::auth_recoverPassword(0, code, nullptr)));
}

void AuthManager::log_out(uint64 query_id) {
  if (state_ == State::Closing) {
    return on_query_error(query_id, Status::Error(400, "Already logged out"));
  }
  if (state_ == State::LoggingOut || state_ == State::DestroyingKeys) {
    return on_query_error(query_id, Status::Error(400, "Already logging out"));
  }
  on_new_query(query_id);
  if (state_ != State::Ok) {
    // TODO: could skip full logout if still no authorization
    // TODO: send auth.cancelCode if state_ == State::WaitCode
    LOG(WARNING) << "Destroying auth keys by user request";
    destroy_auth_keys();
    on_current_query_ok();
  } else {
    LOG(WARNING) << "Logging out by user request";
    G()->td_db()->get_binlog_pmc()->set("auth", "logout");
    update_state(State::LoggingOut);
    send_log_out_query();
  }
}

void AuthManager::send_log_out_query() {
  // we can lose authorization while logging out, but still may need to resend the request,
  // so we pretend that it doesn't require authorization
  auto query = G()->net_query_creator().create_unauth(telegram_api::auth_logOut());
  query->make_high_priority();
  start_net_query(NetQueryType::LogOut, std::move(query));
}

void AuthManager::delete_account(uint64 query_id, string reason, string password) {
  if (state_ != State::Ok && state_ != State::WaitPassword) {
    return on_query_error(query_id, Status::Error(400, "Need to log in first"));
  }
  if (password.empty() || state_ != State::Ok) {
    on_new_query(query_id);
    LOG(INFO) << "Deleting account";
    start_net_query(NetQueryType::DeleteAccount,
                    G()->net_query_creator().create_unauth(telegram_api::account_deleteAccount(0, reason, nullptr)));
  } else {
    send_closure(G()->password_manager(), &PasswordManager::get_input_check_password_srp, password,
                 PromiseCreator::lambda(
                     [actor_id = actor_id(this), query_id, reason = std::move(reason)](
                         Result<tl_object_ptr<telegram_api::InputCheckPasswordSRP>> r_input_password) mutable {
                       send_closure(actor_id, &AuthManager::do_delete_account, query_id, std::move(reason),
                                    std::move(r_input_password));
                     }));
  }
}

void AuthManager::do_delete_account(uint64 query_id, string reason,
                                    Result<tl_object_ptr<telegram_api::InputCheckPasswordSRP>> r_input_password) {
  if (r_input_password.is_error()) {
    return on_query_error(query_id, r_input_password.move_as_error());
  }

  on_new_query(query_id);
  LOG(INFO) << "Deleting account with password";
  int32 flags = telegram_api::account_deleteAccount::PASSWORD_MASK;
  start_net_query(NetQueryType::DeleteAccount, G()->net_query_creator().create(telegram_api::account_deleteAccount(
                                                   flags, reason, r_input_password.move_as_ok())));
}

void AuthManager::on_closing(bool destroy_flag) {
  auto new_state = destroy_flag ? State::LoggingOut : State::Closing;
  if (new_state != state_) {
    update_state(new_state);
  }
}

void AuthManager::on_new_query(uint64 query_id) {
  if (query_id_ != 0) {
    on_current_query_error(Status::Error(400, "Another authorization query has started"));
  }
  checking_password_ = false;
  net_query_id_ = 0;
  net_query_type_ = NetQueryType::None;
  query_id_ = query_id;
  // TODO: cancel older net_query
}

void AuthManager::on_current_query_error(Status status) {
  if (query_id_ == 0) {
    return;
  }
  auto id = query_id_;
  query_id_ = 0;
  net_query_id_ = 0;
  net_query_type_ = NetQueryType::None;
  checking_password_ = false;
  on_query_error(id, std::move(status));
}

void AuthManager::on_query_error(uint64 query_id, Status status) {
  send_closure(G()->td(), &Td::send_error, query_id, std::move(status));
}

void AuthManager::on_current_query_ok() {
  if (query_id_ == 0) {
    return;
  }
  auto id = query_id_;
  net_query_id_ = 0;
  net_query_type_ = NetQueryType::None;
  query_id_ = 0;
  send_ok(id);
}

void AuthManager::send_ok(uint64 query_id) {
  send_closure(G()->td(), &Td::send_result, query_id, td_api::make_object<td_api::ok>());
}

void AuthManager::start_net_query(NetQueryType net_query_type, NetQueryPtr net_query) {
  // TODO: cancel old net_query?
  net_query_type_ = net_query_type;
  net_query_id_ = net_query->id();
  G()->net_query_dispatcher().dispatch_with_callback(std::move(net_query), actor_shared(this));
}

void AuthManager::on_sent_code(telegram_api::object_ptr<telegram_api::auth_SentCode> &&sent_code_ptr) {
  LOG(INFO) << "Receive " << to_string(sent_code_ptr);
  auto sent_code_id = sent_code_ptr->get_id();
  if (sent_code_id != telegram_api::auth_sentCode::ID) {
    CHECK(sent_code_id == telegram_api::auth_sentCodeSuccess::ID);
    auto sent_code_success = move_tl_object_as<telegram_api::auth_sentCodeSuccess>(sent_code_ptr);
    return on_get_authorization(std::move(sent_code_success->authorization_));
  }
  auto sent_code = telegram_api::move_object_as<telegram_api::auth_sentCode>(sent_code_ptr);
  auto code_type_id = sent_code->type_->get_id();
  if (code_type_id == telegram_api::auth_sentCodeTypeSetUpEmailRequired::ID) {
    auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeSetUpEmailRequired>(std::move(sent_code->type_));
    send_code_helper_.on_phone_code_hash(std::move(sent_code->phone_code_hash_));
    allow_apple_id_ = code_type->apple_signin_allowed_;
    allow_google_id_ = code_type->google_signin_allowed_;
    update_state(State::WaitEmailAddress);
  } else if (code_type_id == telegram_api::auth_sentCodeTypeEmailCode::ID) {
    auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeEmailCode>(std::move(sent_code->type_));
    send_code_helper_.on_phone_code_hash(std::move(sent_code->phone_code_hash_));
    allow_apple_id_ = code_type->apple_signin_allowed_;
    allow_google_id_ = code_type->google_signin_allowed_;
    email_address_.clear();
    if (!code_type->email_pattern_.empty() || email_code_info_.is_empty()) {
      email_code_info_ = SentEmailCode(std::move(code_type->email_pattern_), code_type->length_);
    }
    reset_available_period_ = -1;
    reset_pending_date_ = -1;
    if (code_type->reset_pending_date_ > 0) {
      reset_pending_date_ = code_type->reset_pending_date_;
    } else if ((code_type->flags_ & telegram_api::auth_sentCodeTypeEmailCode::RESET_AVAILABLE_PERIOD_MASK) != 0) {
      reset_available_period_ = max(code_type->reset_available_period_, 0);
    }
    if (email_code_info_.is_empty()) {
      email_code_info_ = SentEmailCode("<unknown>", code_type->length_);
      CHECK(!email_code_info_.is_empty());
    }
    update_state(State::WaitEmailCode);
  } else {
    send_code_helper_.on_sent_code(std::move(sent_code));
    update_state(State::WaitCode);
  }
  on_current_query_ok();
}

void AuthManager::on_send_code_result(NetQueryPtr &&net_query) {
  auto r_sent_code = fetch_result<telegram_api::auth_sendCode>(std::move(net_query));
  if (r_sent_code.is_error()) {
    return on_current_query_error(r_sent_code.move_as_error());
  }
  on_sent_code(r_sent_code.move_as_ok());
}

void AuthManager::on_send_email_code_result(NetQueryPtr &&net_query) {
  auto r_sent_code = fetch_result<telegram_api::account_sendVerifyEmailCode>(std::move(net_query));
  if (r_sent_code.is_error()) {
    return on_current_query_error(r_sent_code.move_as_error());
  }
  auto sent_code = r_sent_code.move_as_ok();

  LOG(INFO) << "Receive " << to_string(sent_code);

  email_code_info_ = SentEmailCode(std::move(sent_code));
  if (email_code_info_.is_empty()) {
    return on_current_query_error(Status::Error(500, "Receive invalid response"));
  }

  update_state(State::WaitEmailCode);
  on_current_query_ok();
}

void AuthManager::on_verify_email_address_result(NetQueryPtr &&net_query) {
  auto r_email_verified = fetch_result<telegram_api::account_verifyEmail>(std::move(net_query));
  if (r_email_verified.is_error()) {
    return on_current_query_error(r_email_verified.move_as_error());
  }
  auto email_verified = r_email_verified.move_as_ok();

  LOG(INFO) << "Receive " << to_string(email_verified);
  if (email_verified->get_id() != telegram_api::account_emailVerifiedLogin::ID) {
    return on_current_query_error(Status::Error(500, "Receive invalid response"));
  }
  reset_available_period_ = -1;
  reset_pending_date_ = -1;

  auto verified_login = telegram_api::move_object_as<telegram_api::account_emailVerifiedLogin>(email_verified);
  on_sent_code(std::move(verified_login->sent_code_));
}

void AuthManager::on_reset_email_address_result(NetQueryPtr &&net_query) {
  auto r_sent_code = fetch_result<telegram_api::auth_resetLoginEmail>(std::move(net_query));
  if (r_sent_code.is_error()) {
    if (reset_available_period_ > 0 && reset_pending_date_ == -1 &&
        r_sent_code.error().message() == "TASK_ALREADY_EXISTS") {
      reset_pending_date_ = G()->unix_time() + reset_available_period_;
      reset_available_period_ = -1;
      update_state(State::WaitEmailCode);
    }
    return on_current_query_error(r_sent_code.move_as_error());
  }
  on_sent_code(r_sent_code.move_as_ok());
}

void AuthManager::on_request_qr_code_result(NetQueryPtr &&net_query, bool is_import) {
  auto r_login_token = fetch_result<telegram_api::auth_exportLoginToken>(std::move(net_query));
  if (r_login_token.is_ok()) {
    auto login_token = r_login_token.move_as_ok();

    if (is_import) {
      CHECK(DcId::is_valid(imported_dc_id_));
      G()->net_query_dispatcher().set_main_dc_id(imported_dc_id_);
      imported_dc_id_ = -1;
    }

    on_get_login_token(std::move(login_token));
    return;
  }
  auto status = r_login_token.move_as_error();

  LOG(INFO) << "Receive " << status << " for login token " << (is_import ? "import" : "export");
  if (is_import) {
    imported_dc_id_ = -1;
  }
  if (query_id_ != 0) {
    on_current_query_error(std::move(status));
  } else {
    login_code_retry_delay_ = clamp(2 * login_code_retry_delay_, 1, 60);
    set_login_token_expires_at(Time::now() + login_code_retry_delay_);
  }
}

void AuthManager::on_get_login_token(tl_object_ptr<telegram_api::auth_LoginToken> login_token) {
  LOG(INFO) << "Receive " << to_string(login_token);

  login_code_retry_delay_ = 0;

  CHECK(login_token != nullptr);
  switch (login_token->get_id()) {
    case telegram_api::auth_loginToken::ID: {
      auto token = move_tl_object_as<telegram_api::auth_loginToken>(login_token);
      login_token_ = token->token_.as_slice().str();
      set_login_token_expires_at(Time::now() + td::max(token->expires_ - G()->server_time(), 1.0));
      update_state(State::WaitQrCodeConfirmation);
      on_current_query_ok();
      break;
    }
    case telegram_api::auth_loginTokenMigrateTo::ID: {
      auto token = move_tl_object_as<telegram_api::auth_loginTokenMigrateTo>(login_token);
      if (!DcId::is_valid(token->dc_id_)) {
        LOG(ERROR) << "Receive wrong DC " << token->dc_id_;
        return;
      }
      on_current_query_ok();

      imported_dc_id_ = token->dc_id_;
      start_net_query(NetQueryType::ImportQrCode, G()->net_query_creator().create_unauth(
                                                      telegram_api::auth_importLoginToken(std::move(token->token_)),
                                                      DcId::internal(token->dc_id_)));
      break;
    }
    case telegram_api::auth_loginTokenSuccess::ID: {
      auto token = move_tl_object_as<telegram_api::auth_loginTokenSuccess>(login_token);
      on_get_authorization(std::move(token->authorization_));
      break;
    }
    default:
      UNREACHABLE();
  }
}

void AuthManager::on_get_password_result(NetQueryPtr &&net_query) {
  auto r_password = fetch_result<telegram_api::account_getPassword>(std::move(net_query));
  if (r_password.is_error() && query_id_ != 0) {
    return on_current_query_error(r_password.move_as_error());
  }
  auto password = r_password.is_ok() ? r_password.move_as_ok() : nullptr;
  LOG(INFO) << "Receive password info: " << to_string(password);

  wait_password_state_ = WaitPasswordState();
  Result<NewPasswordState> r_new_password_state;
  if (password != nullptr && password->current_algo_ != nullptr) {
    switch (password->current_algo_->get_id()) {
      case telegram_api::passwordKdfAlgoUnknown::ID:
        return on_current_query_error(Status::Error(400, "Application update is needed to log in"));
      case telegram_api::passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow::ID: {
        auto algo = move_tl_object_as<telegram_api::passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow>(
            password->current_algo_);
        wait_password_state_.current_client_salt_ = algo->salt1_.as_slice().str();
        wait_password_state_.current_server_salt_ = algo->salt2_.as_slice().str();
        wait_password_state_.srp_g_ = algo->g_;
        wait_password_state_.srp_p_ = algo->p_.as_slice().str();
        wait_password_state_.srp_B_ = password->srp_B_.as_slice().str();
        wait_password_state_.srp_id_ = password->srp_id_;
        wait_password_state_.hint_ = std::move(password->hint_);
        wait_password_state_.has_recovery_ = password->has_recovery_;
        wait_password_state_.has_secure_values_ = password->has_secure_values_;
        break;
      }
      default:
        UNREACHABLE();
    }

    r_new_password_state =
        get_new_password_state(std::move(password->new_algo_), std::move(password->new_secure_algo_));
  } else if (was_qr_code_request_) {
    imported_dc_id_ = -1;
    login_code_retry_delay_ = clamp(2 * login_code_retry_delay_, 1, 60);
    set_login_token_expires_at(Time::now() + login_code_retry_delay_);
    return;
  } else {
    send_auth_sign_in_query();
    return;
  }

  if (imported_dc_id_ != -1) {
    G()->net_query_dispatcher().set_main_dc_id(imported_dc_id_);
    imported_dc_id_ = -1;
  }

  if (state_ == State::WaitPassword && checking_password_) {
    if (!new_password_.empty()) {
      if (r_new_password_state.is_error()) {
        return on_current_query_error(r_new_password_state.move_as_error());
      }

      auto r_new_settings = PasswordManager::get_password_input_settings(std::move(new_password_), std::move(new_hint_),
                                                                         r_new_password_state.ok());
      if (r_new_settings.is_error()) {
        return on_current_query_error(r_new_settings.move_as_error());
      }

      int32 flags = telegram_api::auth_recoverPassword::NEW_SETTINGS_MASK;
      start_net_query(NetQueryType::RecoverPassword,
                      G()->net_query_creator().create_unauth(
                          telegram_api::auth_recoverPassword(flags, recovery_code_, r_new_settings.move_as_ok())));
      return;
    }
    LOG(INFO) << "Have SRP ID " << wait_password_state_.srp_id_;
    auto hash = PasswordManager::get_input_check_password(password_, wait_password_state_.current_client_salt_,
                                                          wait_password_state_.current_server_salt_,
                                                          wait_password_state_.srp_g_, wait_password_state_.srp_p_,
                                                          wait_password_state_.srp_B_, wait_password_state_.srp_id_);

    start_net_query(NetQueryType::CheckPassword,
                    G()->net_query_creator().create_unauth(telegram_api::auth_checkPassword(std::move(hash))));
  } else {
    update_state(State::WaitPassword);
    on_current_query_ok();
  }
}

void AuthManager::on_request_password_recovery_result(NetQueryPtr &&net_query) {
  auto r_email_address_pattern = fetch_result<telegram_api::auth_requestPasswordRecovery>(std::move(net_query));
  if (r_email_address_pattern.is_error()) {
    return on_current_query_error(r_email_address_pattern.move_as_error());
  }
  auto email_address_pattern = r_email_address_pattern.move_as_ok();
  wait_password_state_.email_address_pattern_ = std::move(email_address_pattern->email_pattern_);
  update_state(State::WaitPassword);
  on_current_query_ok();
}

void AuthManager::on_check_password_recovery_code_result(NetQueryPtr &&net_query) {
  auto r_success = fetch_result<telegram_api::auth_checkRecoveryPassword>(std::move(net_query));
  if (r_success.is_error()) {
    return on_current_query_error(r_success.move_as_error());
  }
  if (!r_success.ok()) {
    return on_current_query_error(Status::Error(400, "Invalid recovery code"));
  }
  on_current_query_ok();
}

void AuthManager::on_request_firebase_sms_result(NetQueryPtr &&net_query) {
  auto r_bool = fetch_result<telegram_api::auth_requestFirebaseSms>(std::move(net_query));
  if (r_bool.is_error()) {
    return on_current_query_error(r_bool.move_as_error());
  }
  on_current_query_ok();
}

void AuthManager::on_authentication_result(NetQueryPtr &&net_query, bool is_from_current_query) {
  auto r_sign_in = fetch_result<telegram_api::auth_signIn>(std::move(net_query));
  if (r_sign_in.is_error()) {
    if (is_from_current_query) {
      return on_current_query_error(r_sign_in.move_as_error());
    }
    return;
  }
  on_get_authorization(r_sign_in.move_as_ok());
}

void AuthManager::on_log_out_result(NetQueryPtr &&net_query) {
  auto r_log_out = fetch_result<telegram_api::auth_logOut>(std::move(net_query));
  if (r_log_out.is_ok()) {
    auto logged_out = r_log_out.move_as_ok();
    if (!logged_out->future_auth_token_.empty()) {
      td_->option_manager_->set_option_string("authentication_token",
                                              base64url_encode(logged_out->future_auth_token_.as_slice()));
    }
  } else if (r_log_out.error().code() != 401) {
    LOG(ERROR) << "Receive error for auth.logOut: " << r_log_out.error();
  }
  destroy_auth_keys();
  on_current_query_ok();
}

void AuthManager::on_account_banned() const {
  if (is_bot()) {
    return;
  }
  LOG(ERROR) << "Your account was banned for suspicious activity. If you think that this is a mistake, please try to "
                "log in from an official mobile app and send an email to recover the account by following instructions "
                "provided by the app";
}

void AuthManager::on_authorization_lost(string source) {
  if (state_ == State::LoggingOut && net_query_type_ == NetQueryType::LogOut) {
    LOG(INFO) << "Ignore authorization loss because of " << source << ", while logging out";
    return;
  }
  if (state_ == State::Closing || state_ == State::DestroyingKeys) {
    LOG(INFO) << "Ignore duplicate authorization loss because of " << source;
    return;
  }
  LOG(WARNING) << "Lost authorization because of " << source;
  if (source == "USER_DEACTIVATED_BAN") {
    on_account_banned();
  }
  destroy_auth_keys();
}

void AuthManager::destroy_auth_keys() {
  if (state_ == State::Closing || state_ == State::DestroyingKeys) {
    LOG(INFO) << "Already destroying auth keys";
    return;
  }
  update_state(State::DestroyingKeys);
  G()->td_db()->get_binlog_pmc()->set("auth", "destroy");
  G()->net_query_dispatcher().destroy_auth_keys(PromiseCreator::lambda([](Result<Unit> result) {
    if (result.is_ok()) {
      send_closure_later(G()->td(), &Td::destroy);
    } else {
      LOG(INFO) << "Failed to destroy auth keys";
    }
  }));
}

void AuthManager::on_delete_account_result(NetQueryPtr &&net_query) {
  auto r_delete_account = fetch_result<telegram_api::account_deleteAccount>(std::move(net_query));
  if (r_delete_account.is_ok()) {
    if (!r_delete_account.ok()) {
      // status = Status::Error(500, "Receive false as result of the request");
    }
  } else {
    auto status = r_delete_account.move_as_error();
    if (status.message() != "USER_DEACTIVATED") {
      LOG(WARNING) << "Request account.deleteAccount failed: " << status;
      // TODO handle some errors
      return on_current_query_error(std::move(status));
    }
  }

  destroy_auth_keys();
  on_current_query_ok();
}

void AuthManager::on_get_authorization(tl_object_ptr<telegram_api::auth_Authorization> auth_ptr) {
  if (state_ == State::Ok) {
    LOG(WARNING) << "Ignore duplicate auth.Authorization";
    return on_current_query_ok();
  }
  CHECK(auth_ptr != nullptr);
  if (auth_ptr->get_id() == telegram_api::auth_authorizationSignUpRequired::ID) {
    auto sign_up_required = telegram_api::move_object_as<telegram_api::auth_authorizationSignUpRequired>(auth_ptr);
    terms_of_service_ = TermsOfService(std::move(sign_up_required->terms_of_service_));
    update_state(State::WaitRegistration);
    return on_current_query_ok();
  }
  auto auth = telegram_api::move_object_as<telegram_api::auth_authorization>(auth_ptr);

  td_->option_manager_->set_option_integer("authorization_date", G()->unix_time());
  if (was_check_bot_token_) {
    is_bot_ = true;
    G()->td_db()->get_binlog_pmc()->set("auth_is_bot", "true");
  }
  G()->td_db()->get_binlog_pmc()->set("auth", "ok");
  code_.clear();
  password_.clear();
  recovery_code_.clear();
  new_password_.clear();
  new_hint_.clear();
  state_ = State::Ok;
  if (auth->user_->get_id() == telegram_api::user::ID) {
    auto *user = static_cast<telegram_api::user *>(auth->user_.get());
    if (!user->self_) {
      LOG(ERROR) << "Receive invalid authorization for " << to_string(auth->user_);
      user->self_ = true;
    }
  }
  td_->user_manager_->on_get_user(std::move(auth->user_), "on_get_authorization");
  update_state(State::Ok);
  if (!td_->user_manager_->get_my_id().is_valid()) {
    LOG(ERROR) << "Server didsn't send proper authorization";
    on_current_query_error(Status::Error(500, "Server didn't send proper authorization"));
    log_out(0);
    return;
  }
  if (auth->tmp_sessions_ > 0) {
    td_->option_manager_->set_option_integer("session_count", auth->tmp_sessions_);
  }
  if (auth->setup_password_required_ && auth->otherwise_relogin_days_ > 0) {
    td_->option_manager_->set_option_integer("otherwise_relogin_days", auth->otherwise_relogin_days_);
  }
  if (!auth->future_auth_token_.empty()) {
    td_->option_manager_->set_option_string("authentication_token",
                                            base64url_encode(auth->future_auth_token_.as_slice()));
  }
  td_->attach_menu_manager_->init();
  td_->messages_manager_->on_authorization_success();
  td_->dialog_filter_manager_->on_authorization_success();  // must be after MessagesManager::on_authorization_success()
                                                            // to have folders created
  td_->notification_manager_->init();
  td_->online_manager_->init();
  td_->promo_data_manager_->init();
  td_->reaction_manager_->init();
  td_->stickers_manager_->init();
  td_->terms_of_service_manager_->init();
  td_->theme_manager_->init();
  td_->top_dialog_manager_->init();
  td_->updates_manager_->get_difference("on_get_authorization");
  if (!is_bot()) {
    G()->td_db()->get_binlog_pmc()->set("fetched_marks_as_unread", "1");
  }
  send_closure(G()->config_manager(), &ConfigManager::request_config, false);
  on_current_query_ok();
}

void AuthManager::on_result(NetQueryPtr net_query) {
  NetQueryType type = NetQueryType::None;
  LOG(INFO) << "Receive result of query " << net_query->id() << ", expecting " << net_query_id_ << " with type "
            << static_cast<int32>(net_query_type_);
  if (net_query->id() == net_query_id_) {
    net_query_id_ = 0;
    type = net_query_type_;
    net_query_type_ = NetQueryType::None;
    if (net_query->is_error()) {
      if ((type == NetQueryType::SendCode || type == NetQueryType::SendEmailCode ||
           type == NetQueryType::VerifyEmailAddress || type == NetQueryType::SignIn ||
           type == NetQueryType::RequestQrCode || type == NetQueryType::ImportQrCode) &&
          net_query->error().code() == 401 && net_query->error().message() == CSlice("SESSION_PASSWORD_NEEDED")) {
        auto dc_id = DcId::main();
        if (type == NetQueryType::ImportQrCode) {
          CHECK(DcId::is_valid(imported_dc_id_));
          dc_id = DcId::internal(imported_dc_id_);
        }
        net_query->clear();
        start_net_query(NetQueryType::GetPassword,
                        G()->net_query_creator().create_unauth(telegram_api::account_getPassword(), dc_id));
        return;
      }
      if (net_query->error().message() == CSlice("PHONE_NUMBER_BANNED")) {
        on_account_banned();
      }
      if (type != NetQueryType::LogOut && type != NetQueryType::DeleteAccount) {
        if (query_id_ != 0) {
          if (state_ == State::WaitPhoneNumber) {
            other_user_ids_.clear();
            send_code_helper_ = SendCodeHelper();
            terms_of_service_ = TermsOfService();
            was_qr_code_request_ = false;
            was_check_bot_token_ = false;
          }
          on_current_query_error(net_query->move_as_error());
          return;
        }
        if (type != NetQueryType::RequestQrCode && type != NetQueryType::ImportQrCode &&
            type != NetQueryType::GetPassword) {
          LOG(INFO) << "Ignore error for net query of type " << static_cast<int32>(type);
          type = NetQueryType::None;
        }
      }
    }
  } else if (net_query->is_ok() && net_query->ok_tl_constructor() == telegram_api::auth_authorization::ID) {
    type = NetQueryType::Authentication;
  }
  switch (type) {
    case NetQueryType::None:
      net_query->clear();
      break;
    case NetQueryType::SignIn:
    case NetQueryType::SignUp:
    case NetQueryType::BotAuthentication:
    case NetQueryType::CheckPassword:
    case NetQueryType::RecoverPassword:
      on_authentication_result(std::move(net_query), true);
      break;
    case NetQueryType::Authentication:
      on_authentication_result(std::move(net_query), false);
      break;
    case NetQueryType::SendCode:
      on_send_code_result(std::move(net_query));
      break;
    case NetQueryType::SendEmailCode:
      on_send_email_code_result(std::move(net_query));
      break;
    case NetQueryType::VerifyEmailAddress:
      on_verify_email_address_result(std::move(net_query));
      break;
    case NetQueryType::ResetEmailAddress:
      on_reset_email_address_result(std::move(net_query));
      break;
    case NetQueryType::RequestQrCode:
      on_request_qr_code_result(std::move(net_query), false);
      break;
    case NetQueryType::ImportQrCode:
      on_request_qr_code_result(std::move(net_query), true);
      break;
    case NetQueryType::GetPassword:
      on_get_password_result(std::move(net_query));
      break;
    case NetQueryType::RequestPasswordRecovery:
      on_request_password_recovery_result(std::move(net_query));
      break;
    case NetQueryType::CheckPasswordRecoveryCode:
      on_check_password_recovery_code_result(std::move(net_query));
      break;
    case NetQueryType::RequestFirebaseSms:
      on_request_firebase_sms_result(std::move(net_query));
      break;
    case NetQueryType::LogOut:
      on_log_out_result(std::move(net_query));
      break;
    case NetQueryType::DeleteAccount:
      on_delete_account_result(std::move(net_query));
      break;
    default:
      UNREACHABLE();
  }
}

void AuthManager::update_state(State new_state, bool should_save_state) {
  bool skip_update = (state_ == State::LoggingOut || state_ == State::DestroyingKeys) &&
                     (new_state == State::LoggingOut || new_state == State::DestroyingKeys);
  state_ = new_state;
  if (should_save_state) {
    save_state();
  }
  if (new_state == State::LoggingOut || new_state == State::DestroyingKeys) {
    send_closure(G()->state_manager(), &StateManager::on_logging_out, true);
  }
  if (!skip_update) {
    send_closure(G()->td(), &Td::send_update,
                 make_tl_object<td_api::updateAuthorizationState>(get_authorization_state_object(state_)));
  }

  if (!pending_get_authorization_state_requests_.empty()) {
    auto query_ids = std::move(pending_get_authorization_state_requests_);
    for (auto query_id : query_ids) {
      send_closure(G()->td(), &Td::send_result, query_id, get_authorization_state_object(state_));
    }
  }
}

bool AuthManager::load_state() {
  auto data = G()->td_db()->get_binlog_pmc()->get("auth_state");
  if (data.empty()) {
    LOG(INFO) << "Have no saved auth_state. Waiting for phone number";
    return false;
  }
  DbState db_state;
  auto status = log_event_parse(db_state, data);
  if (status.is_error()) {
    LOG(INFO) << "Ignore auth_state: " << status;
    return false;
  }
  if (db_state.api_id_ != api_id_ || db_state.api_hash_ != api_hash_) {
    LOG(INFO) << "Ignore auth_state: api_id or api_hash changed";
    return false;
  }
  if (db_state.expires_at_ <= Time::now()) {
    LOG(INFO) << "Ignore auth_state: expired";
    return false;
  }

  LOG(INFO) << "Load auth_state from database: " << tag("state", static_cast<int32>(db_state.state_));
  if (db_state.state_ == State::WaitEmailAddress) {
    allow_apple_id_ = db_state.allow_apple_id_;
    allow_google_id_ = db_state.allow_google_id_;
    send_code_helper_ = std::move(db_state.send_code_helper_);
  } else if (db_state.state_ == State::WaitEmailCode) {
    allow_apple_id_ = db_state.allow_apple_id_;
    allow_google_id_ = db_state.allow_google_id_;
    email_address_ = std::move(db_state.email_address_);
    email_code_info_ = std::move(db_state.email_code_info_);
    reset_available_period_ = db_state.reset_available_period_;
    reset_pending_date_ = db_state.reset_pending_date_;
    send_code_helper_ = std::move(db_state.send_code_helper_);
  } else if (db_state.state_ == State::WaitCode) {
    send_code_helper_ = std::move(db_state.send_code_helper_);
  } else if (db_state.state_ == State::WaitQrCodeConfirmation) {
    other_user_ids_ = std::move(db_state.other_user_ids_);
    login_token_ = std::move(db_state.login_token_);
    set_login_token_expires_at(db_state.login_token_expires_at_);
  } else if (db_state.state_ == State::WaitPassword) {
    wait_password_state_ = std::move(db_state.wait_password_state_);
  } else if (db_state.state_ == State::WaitRegistration) {
    send_code_helper_ = std::move(db_state.send_code_helper_);
    terms_of_service_ = std::move(db_state.terms_of_service_);
  } else {
    UNREACHABLE();
  }
  update_state(db_state.state_, false);
  return true;
}

void AuthManager::save_state() {
  if (state_ != State::WaitEmailAddress && state_ != State::WaitEmailCode && state_ != State::WaitCode &&
      state_ != State::WaitQrCodeConfirmation && state_ != State::WaitPassword && state_ != State::WaitRegistration) {
    if (state_ != State::Closing) {
      G()->td_db()->get_binlog_pmc()->erase("auth_state");
    }
    return;
  }

  DbState db_state = [&] {
    if (state_ == State::WaitEmailAddress) {
      return DbState::wait_email_address(api_id_, api_hash_, allow_apple_id_, allow_google_id_, send_code_helper_);
    } else if (state_ == State::WaitEmailCode) {
      return DbState::wait_email_code(api_id_, api_hash_, allow_apple_id_, allow_google_id_, email_address_,
                                      email_code_info_, reset_available_period_, reset_pending_date_,
                                      send_code_helper_);
    } else if (state_ == State::WaitCode) {
      return DbState::wait_code(api_id_, api_hash_, send_code_helper_);
    } else if (state_ == State::WaitQrCodeConfirmation) {
      return DbState::wait_qr_code_confirmation(api_id_, api_hash_, other_user_ids_, login_token_,
                                                login_token_expires_at_);
    } else if (state_ == State::WaitPassword) {
      return DbState::wait_password(api_id_, api_hash_, wait_password_state_);
    } else {
      CHECK(state_ == State::WaitRegistration);
      return DbState::wait_registration(api_id_, api_hash_, send_code_helper_, terms_of_service_);
    }
  }();
  G()->td_db()->get_binlog_pmc()->set("auth_state", log_event_store(db_state).as_slice().str());
}

}  // namespace td
