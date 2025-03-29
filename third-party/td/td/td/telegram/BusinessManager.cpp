//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/BusinessAwayMessage.h"
#include "td/telegram/BusinessChatLink.h"
#include "td/telegram/BusinessConnectedBot.h"
#include "td/telegram/BusinessGreetingMessage.h"
#include "td/telegram/BusinessIntro.h"
#include "td/telegram/BusinessRecipients.h"
#include "td/telegram/BusinessWorkHours.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogLocation.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/InputBusinessChatLink.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

namespace td {

class GetConnectedBotsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::businessConnectedBot>> promise_;

 public:
  explicit GetConnectedBotsQuery(Promise<td_api::object_ptr<td_api::businessConnectedBot>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getConnectedBots(), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getConnectedBots>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetConnectedBotsQuery: " << to_string(result);

    td_->user_manager_->on_get_users(std::move(result->users_), "GetConnectedBotsQuery");
    if (result->connected_bots_.size() > 1u) {
      return on_error(Status::Error(500, "Receive invalid response"));
    }
    if (result->connected_bots_.empty()) {
      return promise_.set_value(nullptr);
    }
    auto bot = BusinessConnectedBot(std::move(result->connected_bots_[0]));
    if (!bot.is_valid()) {
      return on_error(Status::Error(500, "Receive invalid bot"));
    }
    promise_.set_value(bot.get_business_connected_bot_object(td_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateConnectedBotQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UpdateConnectedBotQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const BusinessConnectedBot &bot, telegram_api::object_ptr<telegram_api::InputUser> &&input_user) {
    int32 flags = 0;
    if (bot.get_can_reply()) {
      flags |= telegram_api::account_updateConnectedBot::CAN_REPLY_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateConnectedBot(flags, false /*ignored*/, false /*ignored*/, std::move(input_user),
                                                 bot.get_recipients().get_input_business_bot_recipients(td_)),
        {{"me"}}));
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> &&input_user) {
    int32 flags = telegram_api::account_updateConnectedBot::DELETED_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateConnectedBot(flags, false /*ignored*/, false /*ignored*/, std::move(input_user),
                                                 BusinessRecipients().get_input_business_bot_recipients(td_)),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateConnectedBot>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for UpdateConnectedBotQuery: " << to_string(ptr);
    td_->messages_manager_->hide_all_business_bot_manager_bars();
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleConnectedBotPausedQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit ToggleConnectedBotPausedQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool is_paused) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::account_toggleConnectedBotPaused(std::move(input_peer), is_paused), {{"me"}, {dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_toggleConnectedBotPaused>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!result_ptr.ok()) {
      LOG(INFO) << "Failed to toggle business bot is paused";
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleConnectedBotPausedQuery");
    promise_.set_error(std::move(status));
  }
};

class DisablePeerConnectedBotQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit DisablePeerConnectedBotQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::account_disablePeerConnectedBot(std::move(input_peer)),
                                               {{"me"}, {dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_disablePeerConnectedBot>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!result_ptr.ok()) {
      LOG(INFO) << "Failed to remove business bot";
    } else {
      td_->messages_manager_->on_update_dialog_business_bot_removed(dialog_id_);
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DisablePeerConnectedBotQuery");
    promise_.set_error(std::move(status));
  }
};

class GetBusinessChatLinksQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::businessChatLinks>> promise_;

 public:
  explicit GetBusinessChatLinksQuery(Promise<td_api::object_ptr<td_api::businessChatLinks>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getBusinessChatLinks(), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getBusinessChatLinks>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetBusinessChatLinksQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetBusinessChatLinksQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetBusinessChatLinksQuery");
    promise_.set_value(BusinessChatLinks(td_->user_manager_.get(), std::move(ptr->links_))
                           .get_business_chat_links_object(td_->user_manager_.get()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CreateBusinessChatLinkQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::businessChatLink>> promise_;

 public:
  explicit CreateBusinessChatLinkQuery(Promise<td_api::object_ptr<td_api::businessChatLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(InputBusinessChatLink &&link) {
    send_query(G()->net_query_creator().create(
        telegram_api::account_createBusinessChatLink(link.get_input_business_chat_link(td_->user_manager_.get())),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_createBusinessChatLink>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CreateBusinessChatLinkQuery: " << to_string(ptr);
    promise_.set_value(BusinessChatLink(td_->user_manager_.get(), std::move(ptr))
                           .get_business_chat_link_object(td_->user_manager_.get()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class EditBusinessChatLinkQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::businessChatLink>> promise_;

 public:
  explicit EditBusinessChatLinkQuery(Promise<td_api::object_ptr<td_api::businessChatLink>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &link, InputBusinessChatLink &&input_link) {
    send_query(
        G()->net_query_creator().create(telegram_api::account_editBusinessChatLink(
                                            link, input_link.get_input_business_chat_link(td_->user_manager_.get())),
                                        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_editBusinessChatLink>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditBusinessChatLinkQuery: " << to_string(ptr);
    promise_.set_value(BusinessChatLink(td_->user_manager_.get(), std::move(ptr))
                           .get_business_chat_link_object(td_->user_manager_.get()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteBusinessChatLinkQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteBusinessChatLinkQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &link) {
    send_query(G()->net_query_creator().create(telegram_api::account_deleteBusinessChatLink(link), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_deleteBusinessChatLink>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ResolveBusinessChatLinkQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::businessChatLinkInfo>> promise_;

 public:
  explicit ResolveBusinessChatLinkQuery(Promise<td_api::object_ptr<td_api::businessChatLinkInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &link) {
    send_query(G()->net_query_creator().create(telegram_api::account_resolveBusinessChatLink(link), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_resolveBusinessChatLink>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ResolveBusinessChatLinkQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "ResolveBusinessChatLinkQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "ResolveBusinessChatLinkQuery");

    auto text = get_message_text(td_->user_manager_.get(), std::move(ptr->message_), std::move(ptr->entities_), true,
                                 true, 0, false, "ResolveBusinessChatLinkQuery");
    if (text.text[0] == '@') {
      text.text = ' ' + text.text;
      for (auto &entity : text.entities) {
        entity.offset++;
      }
    }
    DialogId dialog_id(ptr->peer_);
    if (dialog_id.get_type() != DialogType::User) {
      LOG(ERROR) << "Receive " << dialog_id;
      return on_error(Status::Error(500, "Receive invalid business chat"));
    }
    remove_unallowed_entities(td_, text, dialog_id);
    td_->dialog_manager_->force_create_dialog(dialog_id, "ResolveBusinessChatLinkQuery");

    promise_.set_value(td_api::make_object<td_api::businessChatLinkInfo>(
        td_->dialog_manager_->get_chat_id_object(dialog_id, "businessChatLinkInfo"),
        get_formatted_text_object(td_->user_manager_.get(), text, true, -1)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateBusinessLocationQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogLocation location_;

 public:
  explicit UpdateBusinessLocationQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogLocation &&location) {
    location_ = std::move(location);
    int32 flags = 0;
    if (!location_.empty()) {
      flags |= telegram_api::account_updateBusinessLocation::GEO_POINT_MASK;
    }
    if (!location_.get_address().empty()) {
      flags |= telegram_api::account_updateBusinessLocation::ADDRESS_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateBusinessLocation(flags, location_.get_input_geo_point(), location_.get_address()),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateBusinessLocation>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_update_my_user_location(std::move(location_));

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateBusinessWorkHoursQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  BusinessWorkHours work_hours_;

 public:
  explicit UpdateBusinessWorkHoursQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(BusinessWorkHours &&work_hours) {
    work_hours_ = std::move(work_hours);
    int32 flags = 0;
    if (!work_hours_.is_empty()) {
      flags |= telegram_api::account_updateBusinessWorkHours::BUSINESS_WORK_HOURS_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateBusinessWorkHours(flags, work_hours_.get_input_business_work_hours()), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateBusinessWorkHours>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_update_my_user_work_hours(std::move(work_hours_));

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateBusinessGreetingMessageQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  BusinessGreetingMessage greeting_message_;

 public:
  explicit UpdateBusinessGreetingMessageQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(BusinessGreetingMessage &&greeting_message) {
    greeting_message_ = std::move(greeting_message);
    int32 flags = 0;
    if (!greeting_message_.is_empty()) {
      flags |= telegram_api::account_updateBusinessGreetingMessage::MESSAGE_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::account_updateBusinessGreetingMessage(
                                                   flags, greeting_message_.get_input_business_greeting_message(td_)),
                                               {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateBusinessGreetingMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_update_my_user_greeting_message(std::move(greeting_message_));

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateBusinessAwayMessageQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  BusinessAwayMessage away_message_;

 public:
  explicit UpdateBusinessAwayMessageQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(BusinessAwayMessage &&away_message) {
    away_message_ = std::move(away_message);
    int32 flags = 0;
    if (!away_message_.is_empty()) {
      flags |= telegram_api::account_updateBusinessAwayMessage::MESSAGE_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_updateBusinessAwayMessage(flags, away_message_.get_input_business_away_message(td_)),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateBusinessAwayMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_update_my_user_away_message(std::move(away_message_));

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateBusinessIntroQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  BusinessIntro intro_;

 public:
  explicit UpdateBusinessIntroQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(BusinessIntro &&intro) {
    intro_ = std::move(intro);
    int32 flags = 0;
    if (!intro_.is_empty()) {
      flags |= telegram_api::account_updateBusinessIntro::INTRO_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::account_updateBusinessIntro(flags, intro_.get_input_business_intro(td_)), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateBusinessIntro>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_update_my_user_intro(std::move(intro_));

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

BusinessManager::BusinessManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void BusinessManager::tear_down() {
  parent_.reset();
}

void BusinessManager::get_business_connected_bot(Promise<td_api::object_ptr<td_api::businessConnectedBot>> &&promise) {
  td_->create_handler<GetConnectedBotsQuery>(std::move(promise))->send();
}

void BusinessManager::set_business_connected_bot(td_api::object_ptr<td_api::businessConnectedBot> &&bot,
                                                 Promise<Unit> &&promise) {
  if (bot == nullptr) {
    return promise.set_error(Status::Error(400, "Bot must be non-empty"));
  }
  BusinessConnectedBot connected_bot(std::move(bot));
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(connected_bot.get_user_id()));
  td_->create_handler<UpdateConnectedBotQuery>(std::move(promise))->send(connected_bot, std::move(input_user));
}

void BusinessManager::delete_business_connected_bot(UserId bot_user_id, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, td_->user_manager_->get_input_user(bot_user_id));
  td_->create_handler<UpdateConnectedBotQuery>(std::move(promise))->send(std::move(input_user));
}

void BusinessManager::toggle_business_connected_bot_dialog_is_paused(DialogId dialog_id, bool is_paused,
                                                                     Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise,
                     td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write,
                                                               "toggle_business_connected_bot_dialog_is_paused"));
  if (dialog_id.get_type() != DialogType::User) {
    return promise.set_error(Status::Error(400, "The chat has no connected bot"));
  }
  td_->messages_manager_->on_update_dialog_business_bot_is_paused(dialog_id, is_paused);
  td_->create_handler<ToggleConnectedBotPausedQuery>(std::move(promise))->send(dialog_id, is_paused);
}

void BusinessManager::remove_business_connected_bot_from_dialog(DialogId dialog_id, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write,
                                                                        "remove_business_connected_bot_from_dialog"));
  if (dialog_id.get_type() != DialogType::User) {
    return promise.set_error(Status::Error(400, "The chat has no connected bot"));
  }
  td_->messages_manager_->on_update_dialog_business_bot_removed(dialog_id);
  td_->create_handler<DisablePeerConnectedBotQuery>(std::move(promise))->send(dialog_id);
}

void BusinessManager::get_business_chat_links(Promise<td_api::object_ptr<td_api::businessChatLinks>> &&promise) {
  td_->create_handler<GetBusinessChatLinksQuery>(std::move(promise))->send();
}

void BusinessManager::create_business_chat_link(td_api::object_ptr<td_api::inputBusinessChatLink> &&link_info,
                                                Promise<td_api::object_ptr<td_api::businessChatLink>> &&promise) {
  td_->create_handler<CreateBusinessChatLinkQuery>(std::move(promise))
      ->send(InputBusinessChatLink(td_, std::move(link_info)));
}

void BusinessManager::edit_business_chat_link(const string &link,
                                              td_api::object_ptr<td_api::inputBusinessChatLink> &&link_info,
                                              Promise<td_api::object_ptr<td_api::businessChatLink>> &&promise) {
  td_->create_handler<EditBusinessChatLinkQuery>(std::move(promise))
      ->send(link, InputBusinessChatLink(td_, std::move(link_info)));
}

void BusinessManager::delete_business_chat_link(const string &link, Promise<Unit> &&promise) {
  td_->create_handler<DeleteBusinessChatLinkQuery>(std::move(promise))->send(link);
}

void BusinessManager::get_business_chat_link_info(const string &link,
                                                  Promise<td_api::object_ptr<td_api::businessChatLinkInfo>> &&promise) {
  td_->create_handler<ResolveBusinessChatLinkQuery>(std::move(promise))->send(link);
}

void BusinessManager::set_business_location(DialogLocation &&location, Promise<Unit> &&promise) {
  td_->create_handler<UpdateBusinessLocationQuery>(std::move(promise))->send(std::move(location));
}

void BusinessManager::set_business_work_hours(BusinessWorkHours &&work_hours, Promise<Unit> &&promise) {
  td_->create_handler<UpdateBusinessWorkHoursQuery>(std::move(promise))->send(std::move(work_hours));
}

void BusinessManager::set_business_greeting_message(BusinessGreetingMessage &&greeting_message,
                                                    Promise<Unit> &&promise) {
  td_->create_handler<UpdateBusinessGreetingMessageQuery>(std::move(promise))->send(std::move(greeting_message));
}

void BusinessManager::set_business_away_message(BusinessAwayMessage &&away_message, Promise<Unit> &&promise) {
  td_->create_handler<UpdateBusinessAwayMessageQuery>(std::move(promise))->send(std::move(away_message));
}

void BusinessManager::set_business_intro(BusinessIntro &&intro, Promise<Unit> &&promise) {
  td_->create_handler<UpdateBusinessIntroQuery>(std::move(promise))->send(std::move(intro));
}

}  // namespace td
