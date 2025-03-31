//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/SendCodeHelper.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class PhoneNumberManager final : public Actor {
 public:
  PhoneNumberManager(Td *td, ActorShared<> parent);

  void set_phone_number(string phone_number, td_api::object_ptr<td_api::phoneNumberAuthenticationSettings> settings,
                        td_api::object_ptr<td_api::PhoneNumberCodeType> type,
                        Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise);

  void send_firebase_sms(const string &token, Promise<Unit> &&promise);

  void report_missing_code(const string &mobile_network_code, Promise<Unit> &&promise);

  void resend_authentication_code(td_api::object_ptr<td_api::ResendCodeReason> &&reason,
                                  Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise);

  void check_code(string code, Promise<Unit> &&promise);

 private:
  enum class Type : int32 { ChangePhone, VerifyPhone, ConfirmPhone };
  enum class State : int32 { Ok, WaitCode } state_ = State::Ok;

  void tear_down() final;

  void inc_generation();

  void send_new_send_code_query(const telegram_api::Function &send_code,
                                Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise);

  void on_send_code_result(Result<telegram_api::object_ptr<telegram_api::auth_sentCode>> r_sent_code, int64 generation,
                           Promise<td_api::object_ptr<td_api::authenticationCodeInfo>> &&promise);

  void on_check_code_result(Result<Unit> result, int64 generation, Promise<Unit> &&promise);

  Td *td_;
  ActorShared<> parent_;

  Type type_;
  SendCodeHelper send_code_helper_;
  int64 generation_ = 0;
};

}  // namespace td
