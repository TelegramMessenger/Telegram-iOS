//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BotMenuButton.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

namespace td {

class SetBotMenuButtonQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetBotMenuButtonQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId user_id, telegram_api::object_ptr<telegram_api::BotMenuButton> input_bot_menu_button) {
    auto input_user = user_id.is_valid() ? td_->user_manager_->get_input_user(user_id).move_as_ok()
                                         : make_tl_object<telegram_api::inputUserEmpty>();
    send_query(G()->net_query_creator().create(
        telegram_api::bots_setBotMenuButton(std::move(input_user), std::move(input_bot_menu_button))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_setBotMenuButton>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!result_ptr.ok()) {
      LOG(ERROR) << "Receive false as result of SetBotMenuButtonQuery";
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetBotMenuButtonQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::botMenuButton>> promise_;

 public:
  explicit GetBotMenuButtonQuery(Promise<td_api::object_ptr<td_api::botMenuButton>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(UserId user_id) {
    auto input_user = user_id.is_valid() ? td_->user_manager_->get_input_user(user_id).move_as_ok()
                                         : make_tl_object<telegram_api::inputUserEmpty>();
    send_query(G()->net_query_creator().create(telegram_api::bots_getBotMenuButton(std::move(input_user))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_getBotMenuButton>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetBotMenuButtonQuery: " << to_string(ptr);
    auto bot_menu_button = get_bot_menu_button(std::move(ptr));
    promise_.set_value(bot_menu_button == nullptr ? td_api::make_object<td_api::botMenuButton>()
                                                  : bot_menu_button->get_bot_menu_button_object(td_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

unique_ptr<BotMenuButton> get_bot_menu_button(telegram_api::object_ptr<telegram_api::BotMenuButton> &&bot_menu_button) {
  if (bot_menu_button == nullptr) {
    return nullptr;
  }
  switch (bot_menu_button->get_id()) {
    case telegram_api::botMenuButtonCommands::ID:
      return nullptr;
    case telegram_api::botMenuButtonDefault::ID:
      return td::make_unique<BotMenuButton>(string(), "default");
    case telegram_api::botMenuButton::ID: {
      auto button = telegram_api::move_object_as<telegram_api::botMenuButton>(bot_menu_button);
      if (button->text_.empty()) {
        LOG(ERROR) << "Receive bot menu button with empty text: " << to_string(button);
        return nullptr;
      }
      return td::make_unique<BotMenuButton>(std::move(button->text_), std::move(button->url_));
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

td_api::object_ptr<td_api::botMenuButton> BotMenuButton::get_bot_menu_button_object(Td *td) const {
  bool is_bot = td->auth_manager_->is_bot();
  return td_api::make_object<td_api::botMenuButton>(text_, is_bot ? url_ : "menu://" + url_);
}

bool operator==(const BotMenuButton &lhs, const BotMenuButton &rhs) {
  return lhs.text_ == rhs.text_ && lhs.url_ == rhs.url_;
}

td_api::object_ptr<td_api::botMenuButton> get_bot_menu_button_object(Td *td, const BotMenuButton *bot_menu_button) {
  if (bot_menu_button == nullptr) {
    return nullptr;
  }
  return bot_menu_button->get_bot_menu_button_object(td);
}

void set_menu_button(Td *td, UserId user_id, td_api::object_ptr<td_api::botMenuButton> &&menu_button,
                     Promise<Unit> &&promise) {
  if (!user_id.is_valid() && user_id != UserId()) {
    return promise.set_error(Status::Error(400, "User not found"));
  }

  telegram_api::object_ptr<telegram_api::BotMenuButton> input_bot_menu_button;
  if (menu_button == nullptr) {
    input_bot_menu_button = telegram_api::make_object<telegram_api::botMenuButtonCommands>();
  } else if (menu_button->text_.empty()) {
    if (menu_button->url_ != "default") {
      return promise.set_error(Status::Error(400, "Menu button text must be non-empty"));
    }
    input_bot_menu_button = telegram_api::make_object<telegram_api::botMenuButtonDefault>();
  } else {
    if (!clean_input_string(menu_button->text_)) {
      return promise.set_error(Status::Error(400, "Menu button text must be encoded in UTF-8"));
    }
    if (!clean_input_string(menu_button->url_)) {
      return promise.set_error(Status::Error(400, "Menu button URL must be encoded in UTF-8"));
    }
    auto r_url = LinkManager::check_link(menu_button->url_, true, !G()->is_test_dc());
    if (r_url.is_error()) {
      return promise.set_error(Status::Error(400, PSLICE() << "Menu button Web App " << r_url.error().message()));
    }
    input_bot_menu_button = telegram_api::make_object<telegram_api::botMenuButton>(menu_button->text_, r_url.ok());
  }

  td->create_handler<SetBotMenuButtonQuery>(std::move(promise))->send(user_id, std::move(input_bot_menu_button));
}

void get_menu_button(Td *td, UserId user_id, Promise<td_api::object_ptr<td_api::botMenuButton>> &&promise) {
  if (!user_id.is_valid() && user_id != UserId()) {
    return promise.set_error(Status::Error(400, "User not found"));
  }

  td->create_handler<GetBotMenuButtonQuery>(std::move(promise))->send(user_id);
}

}  // namespace td
