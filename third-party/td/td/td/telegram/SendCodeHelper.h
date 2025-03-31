//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class SendCodeHelper {
 public:
  void on_sent_code(telegram_api::object_ptr<telegram_api::auth_sentCode> sent_code);

  void on_phone_code_hash(string &&phone_code_hash);

  td_api::object_ptr<td_api::authorizationStateWaitCode> get_authorization_state_wait_code() const;

  td_api::object_ptr<td_api::authenticationCodeInfo> get_authentication_code_info_object() const;

  Result<telegram_api::auth_resendCode> resend_code(td_api::object_ptr<td_api::ResendCodeReason> &&reason) const;

  using Settings = td_api::object_ptr<td_api::phoneNumberAuthenticationSettings>;

  telegram_api::auth_sendCode send_code(string phone_number, const Settings &settings, int32 api_id,
                                        const string &api_hash);

  telegram_api::auth_requestFirebaseSms request_firebase_sms(const string &token);

  telegram_api::auth_reportMissingCode report_missing_code(const string &mobile_network_code);

  telegram_api::account_sendVerifyEmailCode send_verify_email_code(const string &email_address);

  telegram_api::account_sendChangePhoneCode send_change_phone_code(Slice phone_number, const Settings &settings);

  telegram_api::account_sendVerifyPhoneCode send_verify_phone_code(Slice phone_number, const Settings &settings);

  telegram_api::account_sendConfirmPhoneCode send_confirm_phone_code(const string &hash, Slice phone_number,
                                                                     const Settings &settings);

  telegram_api::object_ptr<telegram_api::emailVerifyPurposeLoginSetup> get_email_verify_purpose_login_setup() const;

  Slice phone_number() const {
    return phone_number_;
  }
  Slice phone_code_hash() const {
    return phone_code_hash_;
  }

  template <class StorerT>
  void store(StorerT &storer) const;
  template <class ParserT>
  void parse(ParserT &parser);

 private:
  struct AuthenticationCodeInfo {
    enum class Type : int32 {
      None,
      Message,
      Sms,
      Call,
      FlashCall,
      MissedCall,
      Fragment,
      FirebaseAndroidSafetyNet,
      FirebaseIos,
      SmsWord,
      SmsPhrase,
      FirebaseAndroidPlayIntegrity
    };
    Type type = Type::None;
    int32 length = 0;
    int32 push_timeout = 0;
    int64 cloud_project_number = 0;
    string pattern;

    AuthenticationCodeInfo() = default;
    AuthenticationCodeInfo(Type type, int32 length, string pattern, int32 push_timeout = 0,
                           int64 cloud_project_number = 0)
        : type(type)
        , length(length)
        , push_timeout(push_timeout)
        , cloud_project_number(cloud_project_number)
        , pattern(std::move(pattern)) {
    }

    template <class StorerT>
    void store(StorerT &storer) const;
    template <class ParserT>
    void parse(ParserT &parser);
  };

  string phone_number_;
  string phone_code_hash_;

  SendCodeHelper::AuthenticationCodeInfo sent_code_info_;
  SendCodeHelper::AuthenticationCodeInfo next_code_info_;
  double next_code_timestamp_ = 0.0;

  static AuthenticationCodeInfo get_authentication_code_info(
      tl_object_ptr<telegram_api::auth_CodeType> &&code_type_ptr);
  static AuthenticationCodeInfo get_sent_authentication_code_info(
      tl_object_ptr<telegram_api::auth_SentCodeType> &&sent_code_type_ptr);

  static td_api::object_ptr<td_api::AuthenticationCodeType> get_authentication_code_type_object(
      const AuthenticationCodeInfo &authentication_code_info);

  static telegram_api::object_ptr<telegram_api::codeSettings> get_input_code_settings(const Settings &settings);
};

}  // namespace td
