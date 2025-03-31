//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SecretChatsManager.h"

#include "td/telegram/DhCache.h"
#include "td/telegram/EncryptedFile.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/SecretChatEvent.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/SecretChatDb.h"
#include "td/telegram/SequenceDispatcher.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/mtproto/DhCallback.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"
#include "td/db/binlog/BinlogInterface.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"

#include <memory>

namespace td {

// seq_no
// 1.
// x_in = 0 if we initiated secret chat.
// x_in = 1 if other client initiated secret chat
// x_out = 1 - x_in
// 2. Send:
// in_seq_no = my_in_seq_no * 2 + x_in
// out_seq_no = my_out_seq_no * 2 + x_out
// my_out_seq_no++;
//
// 3. Receive
// fail_if (in_seq_no % 2 != (1 - x_in)), in_seq_no /= 2.
// fail_if (out_seq_no % 2 != x_out), out_seq_no /= 2.
// drop_if (out_seq_no < my_in_seq_no)
// handle_gap_if(out_seq_no > my_in_seq_no)
// my_in_seq_no++;
//
// fail_if(in_seq_no < his_in_seq_no)
// his_in_seq_no = in_seq_no
// fail_if(my_out_seq_no < his_in_seq_no)
//
// 4. Preventing gaps.
// All messages must be sent in order of out_seq_no
// Messages of older layer have imaginary seq_no = -1
// a. TODO use invokeAfter.
// b. Just don't send next message before server accepted previous one.
//
// 5. Handling gaps.
// TODO
// Just fail chat.

SecretChatsManager::SecretChatsManager(ActorShared<> parent, bool use_secret_chats)
    : use_secret_chats_(use_secret_chats), parent_(std::move(parent)) {
}

void SecretChatsManager::start_up() {
  if (!use_secret_chats_) {
    return;
  }

  class StateCallback final : public StateManager::Callback {
   public:
    explicit StateCallback(ActorId<SecretChatsManager> parent) : parent_(std::move(parent)) {
    }
    bool on_online(bool online_flag) final {
      send_closure(parent_, &SecretChatsManager::on_online, online_flag);
      return parent_.is_alive();
    }

   private:
    ActorId<SecretChatsManager> parent_;
  };
  send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));
}

void SecretChatsManager::create_chat(UserId user_id, int64 user_access_hash, Promise<SecretChatId> promise) {
  int32 random_id;
  ActorId<SecretChatActor> actor;
  do {
    random_id = Random::secure_int32() & 0x7fffffff;
    actor = create_chat_actor(random_id);
  } while (actor.empty());
  send_closure(actor, &SecretChatActor::create_chat, user_id, user_access_hash, random_id, std::move(promise));
}

void SecretChatsManager::cancel_chat(SecretChatId secret_chat_id, bool delete_history, Promise<> promise) {
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Unit());
  send_closure(actor, &SecretChatActor::cancel_chat, delete_history, false, std::move(safe_promise));
}

void SecretChatsManager::send_message(SecretChatId secret_chat_id, tl_object_ptr<secret_api::decryptedMessage> message,
                                      telegram_api::object_ptr<telegram_api::InputEncryptedFile> file,
                                      Promise<> promise) {
  // message->message_ = Random::fast_bool() ? string(1, static_cast<char>(0x80)) : "a";
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Can't find secret chat"));
  send_closure(actor, &SecretChatActor::send_message, std::move(message), std::move(file), std::move(safe_promise));
}
void SecretChatsManager::send_message_action(SecretChatId secret_chat_id,
                                             tl_object_ptr<secret_api::SendMessageAction> action) {
  auto actor = get_chat_actor(secret_chat_id.get());
  if (actor.empty()) {
    return;
  }
  send_closure(actor, &SecretChatActor::send_message_action, std::move(action));
}
void SecretChatsManager::send_read_history(SecretChatId secret_chat_id, int32 date, Promise<> promise) {
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Can't find secret chat"));
  send_closure(actor, &SecretChatActor::send_read_history, date, std::move(safe_promise));
}
void SecretChatsManager::send_open_message(SecretChatId secret_chat_id, int64 random_id, Promise<> promise) {
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Can't find secret chat"));
  send_closure(actor, &SecretChatActor::send_open_message, random_id, std::move(safe_promise));
}

void SecretChatsManager::delete_messages(SecretChatId secret_chat_id, vector<int64> random_ids, Promise<> promise) {
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Unit());
  send_closure(actor, &SecretChatActor::delete_messages, std::move(random_ids), std::move(safe_promise));
}

void SecretChatsManager::delete_all_messages(SecretChatId secret_chat_id, Promise<> promise) {
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Unit());
  send_closure(actor, &SecretChatActor::delete_all_messages, std::move(safe_promise));
}

void SecretChatsManager::notify_screenshot_taken(SecretChatId secret_chat_id, Promise<> promise) {
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Can't find secret chat"));
  send_closure(actor, &SecretChatActor::notify_screenshot_taken, std::move(safe_promise));
}

void SecretChatsManager::send_set_ttl_message(SecretChatId secret_chat_id, int32 ttl, int64 random_id,
                                              Promise<> promise) {
  auto actor = get_chat_actor(secret_chat_id.get());
  auto safe_promise = SafePromise<>(std::move(promise), Status::Error(400, "Can't find secret chat"));
  send_closure(actor, &SecretChatActor::send_set_ttl_message, ttl, random_id, std::move(safe_promise));
}

void SecretChatsManager::on_update_chat(tl_object_ptr<telegram_api::updateEncryption> update) {
  if (!use_secret_chats_ || close_flag_) {
    return;
  }
  PendingChatUpdate pending_update;
  pending_update.online_process_time_ = Timestamp::now();
  if (update->chat_->get_id() == telegram_api::encryptedChatRequested::ID) {
#if TD_ANDROID || TD_DARWIN_IOS
    pending_update.offline_process_time_ = Timestamp::in(1.0);
#else
    pending_update.online_process_time_ = Timestamp::in(2.0);
    pending_update.offline_process_time_ = Timestamp::in(3.0);
#endif
  }
  pending_update.update_ = std::move(update);

  pending_chat_updates_.push_back(std::move(pending_update));
  flush_pending_chat_updates();
}

void SecretChatsManager::do_update_chat(tl_object_ptr<telegram_api::updateEncryption> update) {
  auto actor_id = [this, chat = update->chat_.get()] {
    switch (chat->get_id()) {
      case telegram_api::encryptedChatEmpty::ID:
        return create_chat_actor(static_cast<const telegram_api::encryptedChatEmpty *>(chat)->id_);
      case telegram_api::encryptedChatWaiting::ID:
        return create_chat_actor(static_cast<const telegram_api::encryptedChatWaiting *>(chat)->id_);
      case telegram_api::encryptedChatRequested::ID:
        return create_chat_actor(static_cast<const telegram_api::encryptedChatRequested *>(chat)->id_);
      case telegram_api::encryptedChat::ID:
        return create_chat_actor(static_cast<const telegram_api::encryptedChat *>(chat)->id_);
      case telegram_api::encryptedChatDiscarded::ID:
        return get_chat_actor(static_cast<const telegram_api::encryptedChatDiscarded *>(chat)->id_);
      default:
        UNREACHABLE();
        return ActorId<SecretChatActor>();
    }
  }();
  send_closure(actor_id, &SecretChatActor::update_chat, std::move(update->chat_));
}

void SecretChatsManager::on_new_message(tl_object_ptr<telegram_api::EncryptedMessage> &&message_ptr,
                                        Promise<Unit> &&promise) {
  if (!use_secret_chats_ || close_flag_) {
    return promise.set_value(Unit());
  }
  CHECK(message_ptr != nullptr);

  auto event = make_unique<log_event::InboundSecretMessage>();
  event->promise = std::move(promise);
  switch (message_ptr->get_id()) {
    case telegram_api::encryptedMessage::ID: {
      auto message = telegram_api::move_object_as<telegram_api::encryptedMessage>(message_ptr);
      event->chat_id = message->chat_id_;
      event->date = message->date_;
      event->encrypted_message = std::move(message->bytes_);
      event->file = EncryptedFile::get_encrypted_file(std::move(message->file_));
      break;
    }
    case telegram_api::encryptedMessageService::ID: {
      auto message = telegram_api::move_object_as<telegram_api::encryptedMessageService>(message_ptr);
      event->chat_id = message->chat_id_;
      event->date = message->date_;
      event->encrypted_message = std::move(message->bytes_);
      break;
    }
    default:
      UNREACHABLE();
  }
  add_inbound_message(std::move(event));
}

void SecretChatsManager::replay_binlog_event(BinlogEvent &&binlog_event) {
  if (!use_secret_chats_) {
    binlog_erase(G()->td_db()->get_binlog(), binlog_event.id_);
    return;
  }
  auto r_message = log_event::SecretChatEvent::from_buffer_slice(binlog_event.data_as_buffer_slice());
  LOG_IF(FATAL, r_message.is_error()) << "Failed to deserialize event: " << r_message.error();
  auto message = r_message.move_as_ok();
  message->set_log_event_id(binlog_event.id_);
  LOG(INFO) << "Process binlog event " << *message;
  switch (message->get_type()) {
    case log_event::SecretChatEvent::Type::InboundSecretMessage:
      return replay_inbound_message(unique_ptr<log_event::InboundSecretMessage>(
          static_cast<log_event::InboundSecretMessage *>(message.release())));
    case log_event::SecretChatEvent::Type::OutboundSecretMessage:
      return replay_outbound_message(unique_ptr<log_event::OutboundSecretMessage>(
          static_cast<log_event::OutboundSecretMessage *>(message.release())));
    case log_event::SecretChatEvent::Type::CloseSecretChat:
      return replay_close_chat(
          unique_ptr<log_event::CloseSecretChat>(static_cast<log_event::CloseSecretChat *>(message.release())));
    case log_event::SecretChatEvent::Type::CreateSecretChat:
      return replay_create_chat(
          unique_ptr<log_event::CreateSecretChat>(static_cast<log_event::CreateSecretChat *>(message.release())));
    default:
      LOG(FATAL) << "Unknown log event type " << tag("type", format::as_hex(static_cast<int32>(message->get_type())));
  }
}

void SecretChatsManager::binlog_replay_finish() {
  binlog_replay_finish_flag_ = true;
  for (auto &it : id_to_actor_) {
    send_closure(it.second, &SecretChatActor::binlog_replay_finish);
  }
}

void SecretChatsManager::replay_inbound_message(unique_ptr<log_event::InboundSecretMessage> message) {
  LOG(INFO) << "Replay inbound secret message in chat " << message->chat_id;
  auto actor = get_chat_actor(message->chat_id);
  send_closure_later(actor, &SecretChatActor::replay_inbound_message, std::move(message));
}

void SecretChatsManager::add_inbound_message(unique_ptr<log_event::InboundSecretMessage> message) {
  LOG(INFO) << "Process inbound secret message in chat " << message->chat_id;

  auto actor = get_chat_actor(message->chat_id);
  send_closure(actor, &SecretChatActor::add_inbound_message, std::move(message));
}

void SecretChatsManager::replay_close_chat(unique_ptr<log_event::CloseSecretChat> message) {
  LOG(INFO) << "Replay close secret chat " << message->chat_id;

  auto actor = get_chat_actor(message->chat_id);
  send_closure_later(actor, &SecretChatActor::replay_close_chat, std::move(message));
}

void SecretChatsManager::replay_create_chat(unique_ptr<log_event::CreateSecretChat> message) {
  LOG(INFO) << "Replay create secret chat " << message->random_id;

  auto actor = create_chat_actor(message->random_id);
  send_closure_later(actor, &SecretChatActor::replay_create_chat, std::move(message));
}

void SecretChatsManager::replay_outbound_message(unique_ptr<log_event::OutboundSecretMessage> message) {
  LOG(INFO) << "Replay outbound secret message in chat " << message->chat_id;

  auto actor = get_chat_actor(message->chat_id);
  send_closure_later(actor, &SecretChatActor::replay_outbound_message, std::move(message));
}

ActorId<SecretChatActor> SecretChatsManager::get_chat_actor(int32 id) {
  return create_chat_actor_impl(id, false);
}

ActorId<SecretChatActor> SecretChatsManager::create_chat_actor(int32 id) {
  return create_chat_actor_impl(id, true);
}

unique_ptr<SecretChatActor::Context> SecretChatsManager::make_secret_chat_context(int32 id) {
  class Context final : public SecretChatActor::Context {
   public:
    Context(int32 id, ActorShared<SecretChatsManager> parent, unique_ptr<SecretChatDb> secret_chat_db)
        : secret_chat_id_(SecretChatId(id)), parent_(std::move(parent)), secret_chat_db_(std::move(secret_chat_db)) {
      sequence_dispatcher_ = create_actor<SequenceDispatcher>("SecretChat SequenceDispatcher");
    }
    Context(const Context &) = delete;
    Context &operator=(const Context &) = delete;
    Context(Context &&) = delete;
    Context &operator=(Context &&) = delete;
    ~Context() final {
      send_closure(std::move(sequence_dispatcher_), &SequenceDispatcher::close_silent);
    }

    mtproto::DhCallback *dh_callback() final {
      return DhCache::instance();
    }
    NetQueryCreator &net_query_creator() final {
      return G()->net_query_creator();
    }
    BinlogInterface *binlog() final {
      return G()->td_db()->get_binlog();
    }
    SecretChatDb *secret_chat_db() final {
      return secret_chat_db_.get();
    }
    std::shared_ptr<DhConfig> dh_config() final {
      return G()->get_dh_config();
    }
    void set_dh_config(std::shared_ptr<DhConfig> dh_config) final {
      G()->set_dh_config(std::move(dh_config));
    }
    void send_net_query(NetQueryPtr query, ActorShared<NetQueryCallback> callback, bool ordered) final {
      if (ordered) {
        send_closure(sequence_dispatcher_, &SequenceDispatcher::send_with_callback, std::move(query),
                     std::move(callback));
      } else {
        G()->net_query_dispatcher().dispatch_with_callback(std::move(query), std::move(callback));
      }
    }

    bool get_config_option_boolean(const string &name) const final {
      return G()->get_option_boolean(name);
    }

    int32 unix_time() final {
      return G()->unix_time();
    }

    bool close_flag() final {
      return G()->close_flag();
    }

    void on_update_secret_chat(int64 access_hash, UserId user_id, SecretChatState state, bool is_outbound, int32 ttl,
                               int32 date, string key_hash, int32 layer, FolderId initial_folder_id) final {
      send_closure(G()->user_manager(), &UserManager::on_update_secret_chat, secret_chat_id_, access_hash, user_id,
                   state, is_outbound, ttl, date, key_hash, layer, initial_folder_id);
    }

    void on_inbound_message(UserId user_id, MessageId message_id, int32 date, unique_ptr<EncryptedFile> file,
                            tl_object_ptr<secret_api::decryptedMessage> message, Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_get_secret_message, secret_chat_id_, user_id,
                         message_id, date, std::move(file), std::move(message), std::move(promise));
    }

    void on_send_message_error(int64 random_id, Status error, Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_send_secret_message_error, random_id,
                         std::move(error), std::move(promise));
    }

    void on_send_message_ack(int64 random_id) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_send_message_get_quick_ack, random_id);
    }
    void on_send_message_ok(int64 random_id, MessageId message_id, int32 date, unique_ptr<EncryptedFile> file,
                            Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_send_secret_message_success, random_id,
                         message_id, date, std::move(file), std::move(promise));
    }
    void on_delete_messages(std::vector<int64> random_ids, Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::delete_secret_messages, secret_chat_id_,
                         std::move(random_ids), std::move(promise));
    }
    void on_flush_history(bool remove_from_dialog_list, MessageId message_id, Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::delete_secret_chat_history, secret_chat_id_,
                         remove_from_dialog_list, message_id, std::move(promise));
    }
    void on_read_message(int64 random_id, Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::open_secret_message, secret_chat_id_, random_id,
                         std::move(promise));
    }
    void on_screenshot_taken(UserId user_id, MessageId message_id, int32 date, int64 random_id,
                             Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_secret_chat_screenshot_taken, secret_chat_id_,
                         user_id, message_id, date, random_id, std::move(promise));
    }
    void on_set_ttl(UserId user_id, MessageId message_id, int32 date, int32 ttl, int64 random_id,
                    Promise<> promise) final {
      send_closure_later(G()->messages_manager(), &MessagesManager::on_secret_chat_ttl_changed, secret_chat_id_,
                         user_id, message_id, date, ttl, random_id, std::move(promise));
    }

   private:
    SecretChatId secret_chat_id_;
    ActorOwn<SequenceDispatcher> sequence_dispatcher_;
    ActorShared<SecretChatsManager> parent_;
    unique_ptr<SecretChatDb> secret_chat_db_;
  };
  return make_unique<Context>(id, actor_shared(this, id),
                              td::make_unique<SecretChatDb>(G()->td_db()->get_binlog_pmc_shared(), id));
}

ActorId<SecretChatActor> SecretChatsManager::create_chat_actor_impl(int32 id, bool can_be_empty) {
  if (id == 0) {
    return Auto();
  }
  auto it_flag = id_to_actor_.emplace(id, ActorOwn<SecretChatActor>());
  if (it_flag.second) {
    LOG(INFO) << "Create SecretChatActor: " << tag("id", id);
    it_flag.first->second =
        create_actor<SecretChatActor>(PSLICE() << "SecretChat " << id, id, make_secret_chat_context(id), can_be_empty);
    if (binlog_replay_finish_flag_) {
      send_closure(it_flag.first->second, &SecretChatActor::binlog_replay_finish);
    }
  }
  return it_flag.first->second.get();
}

void SecretChatsManager::hangup() {
  close_flag_ = true;
  for (auto &it : id_to_actor_) {
    LOG(INFO) << "Ask to close SecretChatActor " << tag("id", it.first);
    it.second.reset();
  }
  if (id_to_actor_.empty()) {
    stop();
  }
}

void SecretChatsManager::hangup_shared() {
  CHECK(use_secret_chats_);
  auto token = get_link_token();
  auto it = id_to_actor_.find(static_cast<int32>(token));
  CHECK(it != id_to_actor_.end());
  LOG(INFO) << "Close SecretChatActor " << tag("id", it->first);
  it->second.release();
  id_to_actor_.erase(it);
  if (close_flag_ && id_to_actor_.empty()) {
    stop();
  }
}

void SecretChatsManager::timeout_expired() {
  flush_pending_chat_updates();
}

void SecretChatsManager::flush_pending_chat_updates() {
  if (close_flag_ || !use_secret_chats_) {
    return;
  }
  auto it = pending_chat_updates_.begin();
  while (it != pending_chat_updates_.end() &&
         (is_online_ ? it->online_process_time_.is_in_past() : it->offline_process_time_.is_in_past())) {
    do_update_chat(std::move(it->update_));
    ++it;
  }
  if (it != pending_chat_updates_.end()) {
    set_timeout_at(is_online_ ? it->online_process_time_.at() : it->offline_process_time_.at());
  }
  pending_chat_updates_.erase(pending_chat_updates_.begin(), it);
}

void SecretChatsManager::on_online(bool is_online) {
  if (is_online_ == is_online) {
    return;
  }

  is_online_ = is_online;
  flush_pending_chat_updates();
}

}  // namespace td
