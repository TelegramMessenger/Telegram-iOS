//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/PhoneNumberManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/misc.h"
#include "td/telegram/SuggestedAction.h"
#include "td/telegram/SuggestedActionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"

namespace td {

class SendCodeQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::auth_sentCode>> promise_;

 public:
  explicit SendCodeQuery(Promise<telegram_api::object_ptr<telegram_api::auth_sentCode>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const telegram_api::Function &send_code) {
    send_query(G()->net_query_creator().create(send_code));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_sendChangePhoneCode>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    switch (ptr->get_id()) {
      case telegram_api::auth_sentCodeSuccess::ID:
        return on_error(Status::Error(500, "Receive invalid response"));
      case telegram_api::auth_sentCode::ID:
        return promise_.set_value(telegram_api::move_object_as<telegram_api::auth_sentCode>(ptr));
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class RequestFirebaseSmsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit RequestFirebaseSmsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const telegram_api::auth_requestFirebaseSms &query) {
    send_query(G()->net_query_creator().create(query));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::auth_requestFirebaseSms>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ReportMissingCodeQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ReportMissingCodeQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const telegram_api::auth_reportMissingCode &query) {
    send_query(G()->net_query_creator().create(query));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::auth_reportMissingCode>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ChangePhoneQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ChangePhoneQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &phone_number, const string &phone_code_hash, const string &code) {
    send_query(G()->net_query_creator().create(telegram_api::account_changePhone(phone_number, phone_code_hash, code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_changePhone>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_get_user(result_ptr.move_as_ok(), "ChangePhoneQuery");
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class VerifyPhoneQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit VerifyPhoneQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &phone_number, const string &phone_code_hash, const string &code) {
    send_query(G()->net_query_creator().create(telegram_api::account_verifyPhone(phone_number, phone_code_hash, code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_verifyPhone>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ConfirmPhoneQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ConfirmPhoneQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &phone_code_hash, const string &code) {
    send_query(G()->net_query_creator().create(telegram_api::account_confirmPhone(phone_code_hash, code)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_confirmPhone>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

PhoneNumberManager::PhoneNumberManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void PhoneNumberManager::tear_down() {
  parent_.reset();
}

void PhoneNumberManager::inc_generation() {
  generation_++;
  state_ = State::Ok;
  send_code_helper_ = {};
}

void PhoneNumberManager::send_new_send_code_query(
    const telegram_api::Function &send_code, Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise) {
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), generation = generation_, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::auth_sentCode>> r_sent_code) mutable {
        send_closure(actor_id, &PhoneNumberManager::on_send_code_result, std::move(r_sent_code), generation,
                     std::move(promise));
      });
  td_->create_handler<SendCodeQuery>(std::move(query_promise))->send(send_code);
}

void PhoneNumberManager::on_send_code_result(Result<telegram_api::object_ptr<telegram_api::auth_sentCode>> r_sent_code,
                                             int64 generation,
                                             Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise) {
  G()->ignore_result_if_closing(r_sent_code);
  if (r_sent_code.is_error()) {
    return promise.set_error(r_sent_code.move_as_error());
  }
  if (generation != generation_) {
    return promise.set_error(Status::Error(500, "Request was canceled"));
  }
  auto sent_code = r_sent_code.move_as_ok();

  LOG(INFO) << "Receive " << to_string(sent_code);

  switch (sent_code->type_->get_id()) {
    case telegram_api::auth_sentCodeTypeSetUpEmailRequired::ID:
    case telegram_api::auth_sentCodeTypeEmailCode::ID:
      return promise.set_error(Status::Error(500, "Receive incorrect response"));
    default:
      break;
  }

  send_code_helper_.on_sent_code(std::move(sent_code));
  state_ = State::WaitCode;

  promise.set_value(send_code_helper_.get_authentication_code_info_object());
}

void PhoneNumberManager::set_phone_number(string phone_number,
                                          td_api::object_ptr<td_api::phoneNumberAuthenticationSettings> settings,
                                          td_api::object_ptr<td_api::PhoneNumberCodeType> type,
                                          Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise) {
  inc_generation();
  if (phone_number.empty()) {
    return promise.set_error(Status::Error(400, "Phone number must be non-empty"));
  }
  if (type == nullptr) {
    return promise.set_error(Status::Error(400, "Type must be non-empty"));
  }

  switch (type->get_id()) {
    case td_api::phoneNumberCodeTypeChange::ID:
      type_ = Type::ChangePhone;
      send_closure(G()->suggested_action_manager(), &SuggestedActionManager::hide_suggested_action,
                   SuggestedAction{SuggestedAction::Type::CheckPhoneNumber});
      return send_new_send_code_query(send_code_helper_.send_change_phone_code(phone_number, settings),
                                      std::move(promise));
    case td_api::phoneNumberCodeTypeVerify::ID:
      type_ = Type::VerifyPhone;
      return send_new_send_code_query(send_code_helper_.send_verify_phone_code(phone_number, settings),
                                      std::move(promise));
    case td_api::phoneNumberCodeTypeConfirmOwnership::ID: {
      auto hash = std::move(static_cast<td_api::phoneNumberCodeTypeConfirmOwnership *>(type.get())->hash_);
      if (!clean_input_string(hash)) {
        return promise.set_error(Status::Error(400, "Hash must be encoded in UTF-8"));
      }
      if (hash.empty()) {
        return promise.set_error(Status::Error(400, "Hash must be non-empty"));
      }

      type_ = Type::ConfirmPhone;
      return send_new_send_code_query(send_code_helper_.send_confirm_phone_code(hash, phone_number, settings),
                                      std::move(promise));
    }
    default:
      UNREACHABLE();
  }
}

void PhoneNumberManager::send_firebase_sms(const string &token, Promise<Unit> &&promise) {
  if (state_ != State::WaitCode) {
    return promise.set_error(Status::Error(400, "Can't send Firebase SMS"));
  }

  td_->create_handler<RequestFirebaseSmsQuery>(std::move(promise))->send(send_code_helper_.request_firebase_sms(token));
}

void PhoneNumberManager::report_missing_code(const string &mobile_network_code, Promise<Unit> &&promise) {
  if (state_ != State::WaitCode) {
    return promise.set_error(Status::Error(400, "Can't report missing code"));
  }

  td_->create_handler<ReportMissingCodeQuery>(std::move(promise))
      ->send(send_code_helper_.report_missing_code(mobile_network_code));
}

void PhoneNumberManager::resend_authentication_code(
    td_api::object_ptr<td_api::ResendCodeReason> &&reason,
    Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise) {
  if (state_ != State::WaitCode) {
    return promise.set_error(Status::Error(400, "Can't resend code"));
  }

  TRY_RESULT_PROMISE(promise, resend_code, send_code_helper_.resend_code(std::move(reason)));
  send_new_send_code_query(std::move(resend_code), std::move(promise));
}

void PhoneNumberManager::check_code(string code, Promise<Unit> &&promise) {
  if (state_ != State::WaitCode) {
    return promise.set_error(Status::Error(400, "Can't check code"));
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), generation = generation_, promise = std::move(promise)](Result<Unit> result) mutable {
        send_closure(actor_id, &PhoneNumberManager::on_check_code_result, std::move(result), generation,
                     std::move(promise));
      });
  switch (type_) {
    case Type::ChangePhone:
      td_->create_handler<ChangePhoneQuery>(std::move(query_promise))
          ->send(send_code_helper_.phone_number().str(), send_code_helper_.phone_code_hash().str(), code);
      break;
    case Type::VerifyPhone:
      td_->create_handler<VerifyPhoneQuery>(std::move(query_promise))
          ->send(send_code_helper_.phone_number().str(), send_code_helper_.phone_code_hash().str(), code);
      break;
    case Type::ConfirmPhone:
      td_->create_handler<ConfirmPhoneQuery>(std::move(query_promise))
          ->send(send_code_helper_.phone_code_hash().str(), code);
      break;
    default:
      UNREACHABLE();
  }
}

void PhoneNumberManager::on_check_code_result(Result<Unit> result, int64 generation, Promise<Unit> &&promise) {
  G()->ignore_result_if_closing(result);
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }
  if (generation != generation_) {
    return promise.set_error(Status::Error(500, "Request was canceled"));
  }

  inc_generation();

  promise.set_value(Unit());
}

}  // namespace td
