//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogActionManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/BusinessConnectionManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/SecretChatsManager.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/buffer.h"
#include "td/utils/emoji.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"

#include <algorithm>

namespace td {

class SetTypingQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  BusinessConnectionId business_connection_id_;
  int32 generation_ = 0;

 public:
  explicit SetTypingQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  NetQueryRef send(DialogId dialog_id, tl_object_ptr<telegram_api::InputPeer> &&input_peer,
                   MessageId top_thread_message_id, BusinessConnectionId business_connection_id,
                   tl_object_ptr<telegram_api::SendMessageAction> &&action) {
    dialog_id_ = dialog_id;
    business_connection_id_ = business_connection_id;
    CHECK(input_peer != nullptr);

    int32 flags = 0;
    if (top_thread_message_id.is_valid()) {
      flags |= telegram_api::messages_setTyping::TOP_MSG_ID_MASK;
    }

    auto query = G()->net_query_creator().create_with_prefix(
        business_connection_id.get_invoke_prefix(),
        telegram_api::messages_setTyping(flags, std::move(input_peer),
                                         top_thread_message_id.get_server_message_id().get(), std::move(action)),
        td_->business_connection_manager_->get_business_connection_dc_id(business_connection_id));
    query->total_timeout_limit_ = 2;
    auto result = query.get_weak();
    generation_ = result.generation();
    send_query(std::move(query));
    return result;
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setTyping>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    // ignore result
    promise_.set_value(Unit());

    if (business_connection_id_.is_empty()) {
      send_closure_later(G()->dialog_action_manager(), &DialogActionManager::after_set_typing_query, dialog_id_,
                         generation_);
    }
  }

  void on_error(Status status) final {
    if (status.code() == NetQuery::Canceled) {
      return promise_.set_value(Unit());
    }

    if (!business_connection_id_.is_valid() &&
        !td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SetTypingQuery")) {
      LOG(INFO) << "Receive error for set typing: " << status;
    }
    promise_.set_error(std::move(status));

    if (business_connection_id_.is_empty()) {
      send_closure_later(G()->dialog_action_manager(), &DialogActionManager::after_set_typing_query, dialog_id_,
                         generation_);
    }
  }
};

DialogActionManager::DialogActionManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  active_dialog_action_timeout_.set_callback(on_active_dialog_action_timeout_callback);
  active_dialog_action_timeout_.set_callback_data(static_cast<void *>(this));
}

void DialogActionManager::tear_down() {
  parent_.reset();
}

void DialogActionManager::on_active_dialog_action_timeout_callback(void *dialog_action_manager_ptr,
                                                                   int64 dialog_id_int) {
  if (G()->close_flag()) {
    return;
  }

  auto dialog_action_manager = static_cast<DialogActionManager *>(dialog_action_manager_ptr);
  send_closure_later(dialog_action_manager->actor_id(dialog_action_manager),
                     &DialogActionManager::on_active_dialog_action_timeout, DialogId(dialog_id_int));
}

void DialogActionManager::on_dialog_action(DialogId dialog_id, MessageId top_thread_message_id,
                                           DialogId typing_dialog_id, DialogAction action, int32 date,
                                           MessageContentType message_content_type) {
  if (td_->auth_manager_->is_bot() || !typing_dialog_id.is_valid()) {
    return;
  }
  if (top_thread_message_id != MessageId() && !top_thread_message_id.is_valid()) {
    LOG(ERROR) << "Ignore " << action << " in the message thread of " << top_thread_message_id;
    return;
  }

  auto dialog_type = dialog_id.get_type();
  if (action == DialogAction::get_speaking_action()) {
    if ((dialog_type != DialogType::Chat && dialog_type != DialogType::Channel) || top_thread_message_id.is_valid()) {
      LOG(ERROR) << "Receive " << action << " in thread of " << top_thread_message_id << " in " << dialog_id;
      return;
    }
    return td_->messages_manager_->on_dialog_speaking_action(dialog_id, typing_dialog_id, date);
  }

  if (td_->dialog_manager_->is_broadcast_channel(dialog_id)) {
    return;
  }

  auto typing_dialog_type = typing_dialog_id.get_type();
  if (typing_dialog_type != DialogType::User && dialog_type != DialogType::Chat && dialog_type != DialogType::Channel) {
    LOG(ERROR) << "Ignore " << action << " of " << typing_dialog_id << " in " << dialog_id;
    return;
  }

  {
    auto message_import_progress = action.get_importing_messages_action_progress();
    if (message_import_progress >= 0) {
      // TODO
      return;
    }
  }

  {
    auto clicking_info = action.get_clicking_animated_emoji_action_info();
    if (!clicking_info.data.empty()) {
      if (date > G()->unix_time() - 10 && dialog_type == DialogType::User && dialog_id == typing_dialog_id) {
        td_->messages_manager_->on_message_animated_emoji_clicked(
            {dialog_id, MessageId(ServerMessageId(clicking_info.message_id))}, std::move(clicking_info.emoji),
            std::move(clicking_info.data));
      }
      return;
    }
  }

  {
    auto emoji = action.get_watching_animations_emoji();
    if (!emoji.empty() &&
        !td_->stickers_manager_->is_sent_animated_emoji_click(dialog_id, remove_emoji_modifiers(emoji))) {
      LOG(DEBUG) << "Ignore unsent " << action;
      return;
    }
  }

  if (!td_->messages_manager_->have_dialog(dialog_id)) {
    LOG(DEBUG) << "Ignore " << action << " in unknown " << dialog_id;
    return;
  }

  if (typing_dialog_type == DialogType::User) {
    if (!td_->user_manager_->have_min_user(typing_dialog_id.get_user_id())) {
      LOG(DEBUG) << "Ignore " << action << " of unknown " << typing_dialog_id.get_user_id();
      return;
    }
  } else {
    if (!td_->dialog_manager_->have_dialog_info_force(typing_dialog_id, "on_dialog_action")) {
      LOG(DEBUG) << "Ignore " << action << " of unknown " << typing_dialog_id;
      return;
    }
    td_->dialog_manager_->force_create_dialog(typing_dialog_id, "on_dialog_action", true);
    if (!td_->messages_manager_->have_dialog(typing_dialog_id)) {
      LOG(ERROR) << "Failed to create typing " << typing_dialog_id;
      return;
    }
  }

  bool is_canceled = action == DialogAction();
  if ((!is_canceled || message_content_type != MessageContentType::None) && typing_dialog_type == DialogType::User) {
    td_->user_manager_->on_update_user_local_was_online(typing_dialog_id.get_user_id(), date);
  }

  if (dialog_type == DialogType::User || dialog_type == DialogType::SecretChat) {
    CHECK(typing_dialog_type == DialogType::User);
    auto user_id = typing_dialog_id.get_user_id();
    if (!td_->user_manager_->is_user_bot(user_id) && !td_->user_manager_->is_user_status_exact(user_id) &&
        !td_->messages_manager_->is_dialog_opened(dialog_id) && !is_canceled) {
      return;
    }
  }

  if (is_canceled) {
    // passed top_thread_message_id must be ignored
    auto actions_it = active_dialog_actions_.find(dialog_id);
    if (actions_it == active_dialog_actions_.end()) {
      return;
    }

    auto &active_actions = actions_it->second;
    auto it = std::find_if(
        active_actions.begin(), active_actions.end(),
        [typing_dialog_id](const ActiveDialogAction &action) { return action.typing_dialog_id == typing_dialog_id; });
    if (it == active_actions.end()) {
      return;
    }

    if (!(typing_dialog_type == DialogType::User && td_->user_manager_->is_user_bot(typing_dialog_id.get_user_id())) &&
        !it->action.is_canceled_by_message_of_type(message_content_type)) {
      return;
    }

    LOG(DEBUG) << "Cancel action of " << typing_dialog_id << " in " << dialog_id;
    top_thread_message_id = it->top_thread_message_id;
    active_actions.erase(it);
    if (active_actions.empty()) {
      active_dialog_actions_.erase(dialog_id);
      LOG(DEBUG) << "Cancel action timeout in " << dialog_id;
      active_dialog_action_timeout_.cancel_timeout(dialog_id.get());
    }
  } else {
    if (date < G()->unix_time() - DIALOG_ACTION_TIMEOUT - 60) {
      LOG(DEBUG) << "Ignore too old action of " << typing_dialog_id << " in " << dialog_id << " sent at " << date;
      return;
    }
    auto &active_actions = active_dialog_actions_[dialog_id];
    auto it = std::find_if(
        active_actions.begin(), active_actions.end(),
        [typing_dialog_id](const ActiveDialogAction &action) { return action.typing_dialog_id == typing_dialog_id; });
    MessageId prev_top_thread_message_id;
    DialogAction prev_action;
    if (it != active_actions.end()) {
      LOG(DEBUG) << "Re-add action of " << typing_dialog_id << " in " << dialog_id;
      prev_top_thread_message_id = it->top_thread_message_id;
      prev_action = it->action;
      active_actions.erase(it);
    } else {
      LOG(DEBUG) << "Add action of " << typing_dialog_id << " in " << dialog_id;
    }

    active_actions.emplace_back(top_thread_message_id, typing_dialog_id, action, Time::now());
    if (top_thread_message_id == prev_top_thread_message_id && action == prev_action) {
      return;
    }
    if (top_thread_message_id != prev_top_thread_message_id && prev_top_thread_message_id.is_valid()) {
      send_update_chat_action(dialog_id, prev_top_thread_message_id, typing_dialog_id, DialogAction());
    }
    if (active_actions.size() == 1u) {
      LOG(DEBUG) << "Set action timeout in " << dialog_id;
      active_dialog_action_timeout_.set_timeout_in(dialog_id.get(), DIALOG_ACTION_TIMEOUT);
    }
  }

  if (top_thread_message_id.is_valid()) {
    send_update_chat_action(dialog_id, MessageId(), typing_dialog_id, action);
  }
  send_update_chat_action(dialog_id, top_thread_message_id, typing_dialog_id, action);
}

void DialogActionManager::send_update_chat_action(DialogId dialog_id, MessageId top_thread_message_id,
                                                  DialogId typing_dialog_id, const DialogAction &action) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  LOG(DEBUG) << "Send " << action << " of " << typing_dialog_id << " in thread of " << top_thread_message_id << " in "
             << dialog_id;
  send_closure(G()->td(), &Td::send_update,
               td_api::make_object<td_api::updateChatAction>(
                   td_->dialog_manager_->get_chat_id_object(dialog_id, "updateChatAction"), top_thread_message_id.get(),
                   get_message_sender_object(td_, typing_dialog_id, "send_update_chat_action"),
                   action.get_chat_action_object()));
}

void DialogActionManager::send_dialog_action(DialogId dialog_id, MessageId top_thread_message_id,
                                             BusinessConnectionId business_connection_id, DialogAction action,
                                             Promise<Unit> &&promise) {
  bool as_business = business_connection_id.is_valid();
  if (as_business) {
    TRY_STATUS_PROMISE(promise,
                       td_->business_connection_manager_->check_business_connection(business_connection_id, dialog_id));
  } else if (!td_->dialog_manager_->have_dialog_force(dialog_id, "send_dialog_action")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (top_thread_message_id != MessageId() &&
      (!top_thread_message_id.is_valid() || !top_thread_message_id.is_server())) {
    return promise.set_error(Status::Error(400, "Invalid message thread specified"));
  }

  if (!as_business && td_->dialog_manager_->is_forum_channel(dialog_id) && !top_thread_message_id.is_valid()) {
    top_thread_message_id = MessageId(ServerMessageId(1));
  }

  tl_object_ptr<telegram_api::InputPeer> input_peer;
  if (action == DialogAction::get_speaking_action()) {
    if (as_business) {
      return promise.set_error(Status::Error(400, "Can't use the action"));
    }
    input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return promise.set_error(Status::Error(400, "Have no access to the chat"));
    }
  } else if (as_business) {
    input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Know);
  } else {
    if (!td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Write)) {
      if (td_->auth_manager_->is_bot()) {
        return promise.set_error(Status::Error(400, "Have no write access to the chat"));
      }
      return promise.set_value(Unit());
    }

    if (td_->dialog_manager_->is_dialog_action_unneeded(dialog_id)) {
      LOG(INFO) << "Skip unneeded " << action << " in " << dialog_id;
      return promise.set_value(Unit());
    }

    input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
  }

  if (dialog_id.get_type() == DialogType::SecretChat) {
    CHECK(!as_business);
    send_closure(G()->secret_chats_manager(), &SecretChatsManager::send_message_action, dialog_id.get_secret_chat_id(),
                 action.get_secret_input_send_message_action());
    promise.set_value(Unit());
    return;
  }

  CHECK(input_peer != nullptr);

  auto new_query_ref = td_->create_handler<SetTypingQuery>(std::move(promise))
                           ->send(dialog_id, std::move(input_peer), top_thread_message_id, business_connection_id,
                                  action.get_input_send_message_action());
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  auto &query_ref = set_typing_query_[dialog_id];
  if (!query_ref.empty()) {
    LOG(INFO) << "Cancel previous send chat action query";
    cancel_query(query_ref);
  }
  query_ref = std::move(new_query_ref);
}

void DialogActionManager::cancel_send_dialog_action_queries(DialogId dialog_id) {
  auto it = set_typing_query_.find(dialog_id);
  if (it == set_typing_query_.end()) {
    return;
  }
  if (!it->second.empty()) {
    cancel_query(it->second);
  }
  set_typing_query_.erase(it);
}

void DialogActionManager::after_set_typing_query(DialogId dialog_id, int32 generation) {
  auto it = set_typing_query_.find(dialog_id);
  if (it != set_typing_query_.end() && (!it->second.is_alive() || it->second.generation() == generation)) {
    set_typing_query_.erase(it);
  }
}

void DialogActionManager::on_active_dialog_action_timeout(DialogId dialog_id) {
  LOG(DEBUG) << "Receive active dialog action timeout in " << dialog_id;
  auto actions_it = active_dialog_actions_.find(dialog_id);
  if (actions_it == active_dialog_actions_.end()) {
    return;
  }
  CHECK(!actions_it->second.empty());

  auto now = Time::now();
  DialogId prev_typing_dialog_id;
  while (actions_it->second[0].start_time + DIALOG_ACTION_TIMEOUT < now + 0.1) {
    CHECK(actions_it->second[0].typing_dialog_id != prev_typing_dialog_id);
    prev_typing_dialog_id = actions_it->second[0].typing_dialog_id;
    on_dialog_action(dialog_id, actions_it->second[0].top_thread_message_id, actions_it->second[0].typing_dialog_id,
                     DialogAction(), 0);

    actions_it = active_dialog_actions_.find(dialog_id);
    if (actions_it == active_dialog_actions_.end()) {
      return;
    }
    CHECK(!actions_it->second.empty());
  }

  LOG(DEBUG) << "Schedule next action timeout in " << dialog_id;
  active_dialog_action_timeout_.add_timeout_in(dialog_id.get(),
                                               actions_it->second[0].start_time + DIALOG_ACTION_TIMEOUT - now);
}

void DialogActionManager::clear_active_dialog_actions(DialogId dialog_id) {
  LOG(DEBUG) << "Clear active dialog actions in " << dialog_id;
  auto actions_it = active_dialog_actions_.find(dialog_id);
  while (actions_it != active_dialog_actions_.end()) {
    CHECK(!actions_it->second.empty());
    on_dialog_action(dialog_id, actions_it->second[0].top_thread_message_id, actions_it->second[0].typing_dialog_id,
                     DialogAction(), 0);
    actions_it = active_dialog_actions_.find(dialog_id);
  }
}

}  // namespace td
