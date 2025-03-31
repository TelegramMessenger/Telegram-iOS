//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Support.h"

#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/buffer.h"
#include "td/utils/Status.h"

namespace td {

static td_api::object_ptr<td_api::userSupportInfo> get_user_support_info_object(
    Td *td, telegram_api::object_ptr<telegram_api::help_UserInfo> user_info) {
  CHECK(user_info != nullptr);
  auto result = td_api::make_object<td_api::userSupportInfo>();
  FormattedText message;
  if (user_info->get_id() == telegram_api::help_userInfo::ID) {
    auto info = telegram_api::move_object_as<telegram_api::help_userInfo>(user_info);
    message = get_message_text(td->user_manager_.get(), std::move(info->message_), std::move(info->entities_), true,
                               true, info->date_, false, "get_user_support_info_object");
    result->author_ = std::move(info->author_);
    result->date_ = info->date_;
  }
  result->message_ = get_formatted_text_object(td->user_manager_.get(), message, true, 0);
  return result;
}

class GetUserInfoQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::userSupportInfo>> promise_;

 public:
  explicit GetUserInfoQuery(Promise<td_api::object_ptr<td_api::userSupportInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(UserId user_id) {
    auto r_input_user = td_->user_manager_->get_input_user(user_id);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }

    send_query(G()->net_query_creator().create(telegram_api::help_getUserInfo(r_input_user.move_as_ok())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getUserInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(get_user_support_info_object(td_, result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class EditUserInfoQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::userSupportInfo>> promise_;

 public:
  explicit EditUserInfoQuery(Promise<td_api::object_ptr<td_api::userSupportInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(UserId user_id, FormattedText &&formatted_text) {
    auto r_input_user = td_->user_manager_->get_input_user(user_id);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }

    send_query(G()->net_query_creator().create(telegram_api::help_editUserInfo(
        r_input_user.move_as_ok(), formatted_text.text,
        get_input_message_entities(td_->user_manager_.get(), &formatted_text, "EditUserInfoQuery"))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_editUserInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(get_user_support_info_object(td_, result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetSupportNameQuery final : public Td::ResultHandler {
  Promise<string> promise_;

 public:
  explicit GetSupportNameQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::help_getSupportName()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getSupportName>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(std::move(result_ptr.ok_ref()->name_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

void get_user_info(Td *td, UserId user_id, Promise<td_api::object_ptr<td_api::userSupportInfo>> &&promise) {
  td->create_handler<GetUserInfoQuery>(std::move(promise))->send(user_id);
}

void set_user_info(Td *td, UserId user_id, td_api::object_ptr<td_api::formattedText> &&message,
                   Promise<td_api::object_ptr<td_api::userSupportInfo>> &&promise) {
  TRY_RESULT_PROMISE(
      promise, formatted_text,
      get_formatted_text(td, td->dialog_manager_->get_my_dialog_id(), std::move(message), false, true, true, false));
  td->create_handler<EditUserInfoQuery>(std::move(promise))->send(user_id, std::move(formatted_text));
}

void get_support_name(Td *td, Promise<string> &&promise) {
  td->create_handler<GetSupportNameQuery>(std::move(promise))->send();
}

}  // namespace td
