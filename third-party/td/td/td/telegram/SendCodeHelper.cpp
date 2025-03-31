//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SendCodeHelper.h"

#include "td/telegram/misc.h"

#include "td/utils/base64.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Time.h"
#include "td/utils/utf8.h"

namespace td {

void SendCodeHelper::on_sent_code(telegram_api::object_ptr<telegram_api::auth_sentCode> sent_code) {
  phone_code_hash_ = std::move(sent_code->phone_code_hash_);
  sent_code_info_ = get_sent_authentication_code_info(std::move(sent_code->type_));
  next_code_info_ = get_authentication_code_info(std::move(sent_code->next_type_));
  next_code_timestamp_ = Time::now() + sent_code->timeout_;

  if (next_code_info_.type == AuthenticationCodeInfo::Type::None &&
      (sent_code_info_.type == AuthenticationCodeInfo::Type::FirebaseAndroidSafetyNet ||
       sent_code_info_.type == AuthenticationCodeInfo::Type::FirebaseAndroidPlayIntegrity ||
       sent_code_info_.type == AuthenticationCodeInfo::Type::FirebaseIos)) {
    next_code_info_ = {AuthenticationCodeInfo::Type::Sms, sent_code_info_.length, string()};
  }
}

void SendCodeHelper::on_phone_code_hash(string &&phone_code_hash) {
  phone_code_hash_ = std::move(phone_code_hash);
}

td_api::object_ptr<td_api::authorizationStateWaitCode> SendCodeHelper::get_authorization_state_wait_code() const {
  return make_tl_object<td_api::authorizationStateWaitCode>(get_authentication_code_info_object());
}

td_api::object_ptr<td_api::authenticationCodeInfo> SendCodeHelper::get_authentication_code_info_object() const {
  return make_tl_object<td_api::authenticationCodeInfo>(
      phone_number_, get_authentication_code_type_object(sent_code_info_),
      get_authentication_code_type_object(next_code_info_),
      max(static_cast<int32>(next_code_timestamp_ - Time::now() + 1 - 1e-9), 0));
}

Result<telegram_api::auth_resendCode> SendCodeHelper::resend_code(
    td_api::object_ptr<td_api::ResendCodeReason> &&reason) const {
  if (next_code_info_.type == AuthenticationCodeInfo::Type::None) {
    return Status::Error(400, "Authentication code can't be resend");
  }
  int32 flags = 0;
  string reason_str;
  if (reason != nullptr && reason->get_id() == td_api::resendCodeReasonVerificationFailed::ID) {
    reason_str = std::move(static_cast<td_api::resendCodeReasonVerificationFailed *>(reason.get())->error_message_);
  }
  if (!reason_str.empty() && clean_input_string(reason_str)) {
    flags |= telegram_api::auth_resendCode::REASON_MASK;
  }
  return telegram_api::auth_resendCode(flags, phone_number_, phone_code_hash_, reason_str);
}

telegram_api::object_ptr<telegram_api::codeSettings> SendCodeHelper::get_input_code_settings(const Settings &settings) {
  int32 flags = 0;
  vector<BufferSlice> logout_tokens;
  string device_token;
  bool is_app_sandbox = false;
  if (settings != nullptr) {
    if (settings->allow_flash_call_) {
      flags |= telegram_api::codeSettings::ALLOW_FLASHCALL_MASK;
    }
    if (settings->allow_missed_call_) {
      flags |= telegram_api::codeSettings::ALLOW_MISSED_CALL_MASK;
    }
    if (settings->is_current_phone_number_) {
      flags |= telegram_api::codeSettings::CURRENT_NUMBER_MASK;
    }
    if (settings->has_unknown_phone_number_) {
      flags |= telegram_api::codeSettings::UNKNOWN_NUMBER_MASK;
    }
    if (settings->allow_sms_retriever_api_) {
      flags |= telegram_api::codeSettings::ALLOW_APP_HASH_MASK;
    }
    if (settings->firebase_authentication_settings_ != nullptr) {
      flags |= telegram_api::codeSettings::ALLOW_FIREBASE_MASK;
      if (settings->firebase_authentication_settings_->get_id() == td_api::firebaseAuthenticationSettingsIos::ID) {
        flags |= telegram_api::codeSettings::TOKEN_MASK;
        auto ios_settings = static_cast<const td_api::firebaseAuthenticationSettingsIos *>(
            settings->firebase_authentication_settings_.get());
        device_token = ios_settings->device_token_;
        is_app_sandbox = ios_settings->is_app_sandbox_;
      }
    }
    constexpr size_t MAX_LOGOUT_TOKENS = 20;  // server-side limit
    for (const auto &token : settings->authentication_tokens_) {
      auto r_logout_token = base64url_decode(token);
      if (r_logout_token.is_ok()) {
        logout_tokens.push_back(BufferSlice(r_logout_token.ok()));
        if (logout_tokens.size() >= MAX_LOGOUT_TOKENS) {
          break;
        }
      }
    }
    if (!logout_tokens.empty()) {
      flags |= telegram_api::codeSettings::LOGOUT_TOKENS_MASK;
    }
  }
  return telegram_api::make_object<telegram_api::codeSettings>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      false /*ignored*/, std::move(logout_tokens), device_token, is_app_sandbox);
}

telegram_api::auth_sendCode SendCodeHelper::send_code(string phone_number, const Settings &settings, int32 api_id,
                                                      const string &api_hash) {
  phone_number_ = std::move(phone_number);
  return telegram_api::auth_sendCode(phone_number_, api_id, api_hash, get_input_code_settings(settings));
}

telegram_api::auth_requestFirebaseSms SendCodeHelper::request_firebase_sms(const string &token) {
  string safety_net_token;
  string play_integrity_token;
  string ios_push_secret;
  int32 flags = 0;
#if TD_ANDROID
  if (sent_code_info_.type == AuthenticationCodeInfo::Type::FirebaseAndroidSafetyNet) {
    flags |= telegram_api::auth_requestFirebaseSms::SAFETY_NET_TOKEN_MASK;
    safety_net_token = token;
  } else if (sent_code_info_.type == AuthenticationCodeInfo::Type::FirebaseAndroidPlayIntegrity) {
    flags |= telegram_api::auth_requestFirebaseSms::PLAY_INTEGRITY_TOKEN_MASK;
    play_integrity_token = token;
  }
#elif TD_DARWIN
  if (sent_code_info_.type == AuthenticationCodeInfo::Type::FirebaseIos) {
    flags |= telegram_api::auth_requestFirebaseSms::IOS_PUSH_SECRET_MASK;
    ios_push_secret = token;
  }
#endif
  return telegram_api::auth_requestFirebaseSms(flags, phone_number_, phone_code_hash_, safety_net_token,
                                               play_integrity_token, ios_push_secret);
}

telegram_api::auth_reportMissingCode SendCodeHelper::report_missing_code(const string &mobile_network_code) {
  return telegram_api::auth_reportMissingCode(phone_number_, phone_code_hash_, mobile_network_code);
}

telegram_api::account_sendVerifyEmailCode SendCodeHelper::send_verify_email_code(const string &email_address) {
  return telegram_api::account_sendVerifyEmailCode(get_email_verify_purpose_login_setup(), email_address);
}

telegram_api::account_sendChangePhoneCode SendCodeHelper::send_change_phone_code(Slice phone_number,
                                                                                 const Settings &settings) {
  phone_number_ = phone_number.str();
  return telegram_api::account_sendChangePhoneCode(phone_number_, get_input_code_settings(settings));
}

telegram_api::account_sendVerifyPhoneCode SendCodeHelper::send_verify_phone_code(Slice phone_number,
                                                                                 const Settings &settings) {
  phone_number_ = phone_number.str();
  return telegram_api::account_sendVerifyPhoneCode(phone_number_, get_input_code_settings(settings));
}

telegram_api::account_sendConfirmPhoneCode SendCodeHelper::send_confirm_phone_code(const string &hash,
                                                                                   Slice phone_number,
                                                                                   const Settings &settings) {
  phone_number_ = phone_number.str();
  return telegram_api::account_sendConfirmPhoneCode(hash, get_input_code_settings(settings));
}

SendCodeHelper::AuthenticationCodeInfo SendCodeHelper::get_authentication_code_info(
    tl_object_ptr<telegram_api::auth_CodeType> &&code_type_ptr) {
  if (code_type_ptr == nullptr) {
    return AuthenticationCodeInfo();
  }

  switch (code_type_ptr->get_id()) {
    case telegram_api::auth_codeTypeSms::ID:
      return {AuthenticationCodeInfo::Type::Sms, 0, string()};
    case telegram_api::auth_codeTypeCall::ID:
      return {AuthenticationCodeInfo::Type::Call, 0, string()};
    case telegram_api::auth_codeTypeFlashCall::ID:
      return {AuthenticationCodeInfo::Type::FlashCall, 0, string()};
    case telegram_api::auth_codeTypeMissedCall::ID:
      return {AuthenticationCodeInfo::Type::MissedCall, 0, string()};
    case telegram_api::auth_codeTypeFragmentSms::ID:
      return {AuthenticationCodeInfo::Type::Fragment, 0, string()};
    default:
      UNREACHABLE();
      return AuthenticationCodeInfo();
  }
}

SendCodeHelper::AuthenticationCodeInfo SendCodeHelper::get_sent_authentication_code_info(
    tl_object_ptr<telegram_api::auth_SentCodeType> &&sent_code_type_ptr) {
  CHECK(sent_code_type_ptr != nullptr);
  switch (sent_code_type_ptr->get_id()) {
    case telegram_api::auth_sentCodeTypeApp::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeApp>(sent_code_type_ptr);
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::Message, code_type->length_, ""};
    }
    case telegram_api::auth_sentCodeTypeSms::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeSms>(sent_code_type_ptr);
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::Sms, code_type->length_, ""};
    }
    case telegram_api::auth_sentCodeTypeCall::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeCall>(sent_code_type_ptr);
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::Call, code_type->length_, ""};
    }
    case telegram_api::auth_sentCodeTypeFlashCall::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeFlashCall>(sent_code_type_ptr);
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::FlashCall, 0, std::move(code_type->pattern_)};
    }
    case telegram_api::auth_sentCodeTypeMissedCall::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeMissedCall>(sent_code_type_ptr);
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::MissedCall, code_type->length_,
                                    std::move(code_type->prefix_)};
    }
    case telegram_api::auth_sentCodeTypeFragmentSms::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeFragmentSms>(sent_code_type_ptr);
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::Fragment, code_type->length_,
                                    std::move(code_type->url_)};
    }
    case telegram_api::auth_sentCodeTypeFirebaseSms::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeFirebaseSms>(sent_code_type_ptr);
#if TD_ANDROID
      if ((code_type->flags_ & telegram_api::auth_sentCodeTypeFirebaseSms::NONCE_MASK) != 0) {
        return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::FirebaseAndroidSafetyNet, code_type->length_,
                                      code_type->nonce_.as_slice().str()};
      }
      if ((code_type->flags_ & telegram_api::auth_sentCodeTypeFirebaseSms::PLAY_INTEGRITY_NONCE_MASK) != 0) {
        return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::FirebaseAndroidPlayIntegrity, code_type->length_,
                                      code_type->play_integrity_nonce_.as_slice().str(), 0,
                                      code_type->play_integrity_project_id_};
      }
#elif TD_DARWIN
      if ((code_type->flags_ & telegram_api::auth_sentCodeTypeFirebaseSms::RECEIPT_MASK) != 0) {
        return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::FirebaseIos, code_type->length_,
                                      std::move(code_type->receipt_), code_type->push_timeout_};
      }
#endif
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::Sms, code_type->length_, ""};
    }
    case telegram_api::auth_sentCodeTypeSmsWord::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeSmsWord>(sent_code_type_ptr);
      if (utf8_length(code_type->beginning_) > 1u) {
        LOG(ERROR) << "Receive \"" << code_type->beginning_ << "\" as word first letter";
        code_type->beginning_ = string();
      }
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::SmsWord, 0, code_type->beginning_};
    }
    case telegram_api::auth_sentCodeTypeSmsPhrase::ID: {
      auto code_type = move_tl_object_as<telegram_api::auth_sentCodeTypeSmsPhrase>(sent_code_type_ptr);
      return AuthenticationCodeInfo{AuthenticationCodeInfo::Type::SmsPhrase, 0, code_type->beginning_};
    }
    case telegram_api::auth_sentCodeTypeEmailCode::ID:
    case telegram_api::auth_sentCodeTypeSetUpEmailRequired::ID:
    default:
      UNREACHABLE();
      return AuthenticationCodeInfo();
  }
}

td_api::object_ptr<td_api::AuthenticationCodeType> SendCodeHelper::get_authentication_code_type_object(
    const AuthenticationCodeInfo &authentication_code_info) {
  switch (authentication_code_info.type) {
    case AuthenticationCodeInfo::Type::None:
      return nullptr;
    case AuthenticationCodeInfo::Type::Message:
      return td_api::make_object<td_api::authenticationCodeTypeTelegramMessage>(authentication_code_info.length);
    case AuthenticationCodeInfo::Type::Sms:
      return td_api::make_object<td_api::authenticationCodeTypeSms>(authentication_code_info.length);
    case AuthenticationCodeInfo::Type::Call:
      return td_api::make_object<td_api::authenticationCodeTypeCall>(authentication_code_info.length);
    case AuthenticationCodeInfo::Type::FlashCall:
      return td_api::make_object<td_api::authenticationCodeTypeFlashCall>(authentication_code_info.pattern);
    case AuthenticationCodeInfo::Type::MissedCall:
      return td_api::make_object<td_api::authenticationCodeTypeMissedCall>(authentication_code_info.pattern,
                                                                           authentication_code_info.length);
    case AuthenticationCodeInfo::Type::Fragment:
      return td_api::make_object<td_api::authenticationCodeTypeFragment>(authentication_code_info.pattern,
                                                                         authentication_code_info.length);
    case AuthenticationCodeInfo::Type::FirebaseAndroidSafetyNet:
      return td_api::make_object<td_api::authenticationCodeTypeFirebaseAndroid>(
          td_api::make_object<td_api::firebaseDeviceVerificationParametersSafetyNet>(authentication_code_info.pattern),
          authentication_code_info.length);
    case AuthenticationCodeInfo::Type::FirebaseAndroidPlayIntegrity:
      return td_api::make_object<td_api::authenticationCodeTypeFirebaseAndroid>(
          td_api::make_object<td_api::firebaseDeviceVerificationParametersPlayIntegrity>(
              base64url_encode(authentication_code_info.pattern), authentication_code_info.cloud_project_number),
          authentication_code_info.length);
    case AuthenticationCodeInfo::Type::FirebaseIos:
      return td_api::make_object<td_api::authenticationCodeTypeFirebaseIos>(
          authentication_code_info.pattern, authentication_code_info.push_timeout, authentication_code_info.length);
    case AuthenticationCodeInfo::Type::SmsWord:
      return td_api::make_object<td_api::authenticationCodeTypeSmsWord>(authentication_code_info.pattern);
    case AuthenticationCodeInfo::Type::SmsPhrase:
      return td_api::make_object<td_api::authenticationCodeTypeSmsPhrase>(authentication_code_info.pattern);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::emailVerifyPurposeLoginSetup>
SendCodeHelper::get_email_verify_purpose_login_setup() const {
  return telegram_api::make_object<telegram_api::emailVerifyPurposeLoginSetup>(phone_number_, phone_code_hash_);
}

}  // namespace td
