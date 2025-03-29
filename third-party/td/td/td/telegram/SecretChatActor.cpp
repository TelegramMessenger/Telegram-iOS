//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SecretChatActor.h"

#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/secret_api.hpp"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/telegram_api.hpp"
#include "td/telegram/UniqueId.h"

#include "td/mtproto/PacketInfo.h"
#include "td/mtproto/PacketStorer.h"
#include "td/mtproto/Transport.h"
#include "td/mtproto/utils.h"

#include "td/db/binlog/BinlogHelper.h"
#include "td/db/binlog/BinlogInterface.h"

#include "td/actor/MultiPromise.h"

#include "td/utils/as.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StorerBase.h"
#include "td/utils/Time.h"
#include "td/utils/tl_parsers.h"

#include <array>
#include <tuple>
#include <type_traits>

//#define G GLOBAL_SHOULD_NOT_BE_USED_HERE
#undef G

namespace td {

class SecretImpl {
 public:
  explicit SecretImpl(const Storer &data) : data(data) {
  }
  template <class StorerT>
  void do_store(StorerT &storer) const {
    storer.store_binary(static_cast<int32>(data.size()));
    storer.store_storer(data);
  }

 private:
  const Storer &data;
};

SecretChatActor::SecretChatActor(int32 id, unique_ptr<Context> context, bool can_be_empty)
    : context_(std::move(context)), can_be_empty_(can_be_empty) {
  auth_state_.id = id;
}

template <class T>
NetQueryPtr SecretChatActor::create_net_query(QueryType type, const T &function) {
  return context_->net_query_creator().create(UniqueId::next(UniqueId::Type::Default, static_cast<uint8>(type)),
                                              nullptr, function, {}, DcId::main(), NetQuery::Type::Common,
                                              NetQuery::AuthFlag::On);
}

void SecretChatActor::update_chat(telegram_api::object_ptr<telegram_api::EncryptedChat> chat) {
  if (close_flag_) {
    return;
  }
  check_status(on_update_chat(std::move(chat)));
  loop();
}

void SecretChatActor::create_chat(UserId user_id, int64 user_access_hash, int32 random_id,
                                  Promise<SecretChatId> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Empty) {
    promise.set_error(Status::Error(500, "Bad random_id"));
    check_status(Status::Error("Unexpected request_chat"));
    loop();
    return;
  }

  auto event = make_unique<log_event::CreateSecretChat>();
  event->user_id = user_id;
  event->user_access_hash = user_access_hash;
  event->random_id = random_id;
  event->set_log_event_id(binlog_add(context_->binlog(), LogEvent::HandlerType::SecretChats, create_storer(*event)));
  do_create_chat_impl(std::move(event));
  promise.set_value(SecretChatId(random_id));
  loop();
}

void SecretChatActor::on_result_resendable(NetQueryPtr net_query, Promise<NetQueryPtr> promise) {
  LOG(INFO) << "In on_result_resendable: " << net_query << " " << close_flag_;
  if (context_->close_flag()) {
    return;
  }

  auto key = UniqueId::extract_key(net_query->id());
  if (close_flag_) {
    if (key == static_cast<uint8>(QueryType::DiscardEncryption)) {
      discard_encryption_promise_.set_value(Unit());
    }
    return;
  }
  check_status([&] {
    switch (key) {
      case static_cast<uint8>(QueryType::DhConfig):
        return on_dh_config(std::move(net_query));
      case static_cast<uint8>(QueryType::EncryptedChat):
        return on_update_chat(std::move(net_query));
      case static_cast<uint8>(QueryType::Message):
        on_outbound_send_message_result(std::move(net_query), std::move(promise));
        return Status::OK();
      case static_cast<uint8>(QueryType::ReadHistory):
        return on_read_history(std::move(net_query));
      case static_cast<uint8>(QueryType::Ignore):
        return Status::OK();
      default:
        UNREACHABLE();
        return Status::OK();
    }
  }());

  loop();
}

void SecretChatActor::replay_close_chat(unique_ptr<log_event::CloseSecretChat> event) {
  do_close_chat_impl(event->delete_history, event->is_already_discarded, event->log_event_id(), Promise<Unit>());
}

void SecretChatActor::replay_create_chat(unique_ptr<log_event::CreateSecretChat> event) {
  if (close_flag_) {
    return;
  }
  do_create_chat_impl(std::move(event));
}

void SecretChatActor::add_inbound_message(unique_ptr<log_event::InboundSecretMessage> message) {
  SCOPE_EXIT {
    if (message) {
      message->promise.set_value(Unit());
    }
  };
  if (close_flag_) {
    return;
  }
  if (auth_state_.state != State::Ready) {
    LOG(ERROR) << "Ignore unexpected update: " << tag("message", *message);
    return;
  }
  check_status(do_inbound_message_encrypted(std::move(message)));
  loop();
}

void SecretChatActor::replay_inbound_message(unique_ptr<log_event::InboundSecretMessage> message) {
  if (close_flag_) {
    return;
  }
  if (auth_state_.state != State::Ready) {
    LOG(ERROR) << "Ignore unexpected replay inbound message: " << tag("message", *message);
    return;
  }

  CHECK(!binlog_replay_finish_flag_);
  CHECK(message->decrypted_message_layer);  // from binlog
  if (message->is_pending) {                // wait for gaps?
    // check_status(do_inbound_message_decrypted_unchecked(std::move(message)), -1);
    do_inbound_message_decrypted_pending(std::move(message));
  } else {  // just replay
    LOG_CHECK(message->message_id > last_binlog_message_id_)
        << tag("last_binlog_message_id", last_binlog_message_id_) << tag("message_id", message->message_id);
    last_binlog_message_id_ = message->message_id;
    check_status(do_inbound_message_decrypted(std::move(message)));
  }
  loop();
}

void SecretChatActor::replay_outbound_message(unique_ptr<log_event::OutboundSecretMessage> message) {
  if (close_flag_) {
    return;
  }
  if (auth_state_.state != State::Ready) {
    LOG(ERROR) << "Ignore unexpected replay outbound message: " << tag("message", *message);
    return;
  }
  CHECK(!binlog_replay_finish_flag_);
  LOG_CHECK(message->message_id > last_binlog_message_id_)
      << tag("last_binlog_message_id", last_binlog_message_id_) << tag("message_id", message->message_id);
  last_binlog_message_id_ = message->message_id;
  do_outbound_message_impl(std::move(message), Promise<>());
  loop();
}

// NB: my_seq_no is just after message is sent, i.e. my_out_seq_no is already incremented
Result<BufferSlice> SecretChatActor::create_encrypted_message(int32 my_in_seq_no, int32 my_out_seq_no,
                                                              tl_object_ptr<secret_api::DecryptedMessage> &message) {
  mtproto::AuthKey *auth_key = &pfs_state_.auth_key;
  auto in_seq_no = my_in_seq_no * 2 + auth_state_.x;
  auto out_seq_no = my_out_seq_no * 2 - 1 - auth_state_.x;

  auto layer = current_layer();
  BufferSlice random_bytes(31);
  Random::secure_bytes(random_bytes.as_mutable_slice().ubegin(), random_bytes.size());
  auto message_with_layer = secret_api::make_object<secret_api::decryptedMessageLayer>(
      std::move(random_bytes), layer, in_seq_no, out_seq_no, std::move(message));
  LOG(INFO) << "Create message " << to_string(message_with_layer);
  auto storer = TLObjectStorer<secret_api::decryptedMessageLayer>(*message_with_layer);
  auto new_storer = mtproto::PacketStorer<SecretImpl>(storer);
  mtproto::PacketInfo packet_info;
  packet_info.type = mtproto::PacketInfo::EndToEnd;
  packet_info.version = 2;
  packet_info.is_creator = auth_state_.x == 0;
  auto packet_writer = mtproto::Transport::write(new_storer, *auth_key, &packet_info);
  message = std::move(message_with_layer->message_);
  return packet_writer.as_buffer_slice();
}

void SecretChatActor::send_message(tl_object_ptr<secret_api::DecryptedMessage> message,
                                   telegram_api::object_ptr<telegram_api::InputEncryptedFile> file, Promise<> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  send_message_impl(std::move(message), std::move(file), SendFlag::External | SendFlag::Push, std::move(promise));
}

void SecretChatActor::send_message_impl(tl_object_ptr<secret_api::DecryptedMessage> message,
                                        telegram_api::object_ptr<telegram_api::InputEncryptedFile> file, int32 flags,
                                        Promise<> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    LOG(ERROR) << "Ignore send_message: " << tag("message", to_string(message)) << tag("file", to_string(file));
    return promise.set_error(Status::Error(400, "Chat is not accessible"));
  }
  LOG_CHECK(binlog_replay_finish_flag_) << "Trying to send message before binlog replay is finished: "
                                        << to_string(*message) << to_string(file);
  int64 random_id = 0;
  downcast_call(*message, [&](auto &x) { random_id = x.random_id_; });

  auto it = random_id_to_outbound_message_state_token_.find(random_id);
  if (it != random_id_to_outbound_message_state_token_.end()) {
    return on_outbound_outer_send_message_promise(it->second, std::move(promise));
  }

  auto binlog_event = make_unique<log_event::OutboundSecretMessage>();
  binlog_event->chat_id = auth_state_.id;
  binlog_event->random_id = random_id;
  binlog_event->file = log_event::EncryptedInputFile::from_input_encrypted_file(file);
  binlog_event->message_id = seq_no_state_.message_id + 1;
  binlog_event->my_in_seq_no = seq_no_state_.my_in_seq_no;
  binlog_event->my_out_seq_no = seq_no_state_.my_out_seq_no + 1;
  binlog_event->his_in_seq_no = seq_no_state_.his_in_seq_no;
  binlog_event->encrypted_message =
      create_encrypted_message(binlog_event->my_in_seq_no, binlog_event->my_out_seq_no, message).move_as_ok();
  binlog_event->need_notify_user = (flags & SendFlag::Push) == 0;
  binlog_event->is_external = (flags & SendFlag::External) != 0;
  binlog_event->is_silent = (message->get_id() == secret_api::decryptedMessage::ID &&
                             (static_cast<const secret_api::decryptedMessage *>(message.get())->flags_ &
                              secret_api::decryptedMessage::SILENT_MASK) != 0);
  if (message->get_id() == secret_api::decryptedMessageService::ID) {
    binlog_event->is_rewritable = false;
    auto service_message = move_tl_object_as<secret_api::decryptedMessageService>(message);
    binlog_event->action = std::move(service_message->action_);
  } else {
    binlog_event->is_rewritable = true;
  }

  do_outbound_message_impl(std::move(binlog_event), std::move(promise));
}

void SecretChatActor::send_message_action(tl_object_ptr<secret_api::SendMessageAction> action) {
  if (close_flag_) {
    return;
  }
  if (auth_state_.state != State::Ready) {
    LOG(ERROR) << "Ignore send_message_action: " << tag("message", to_string(action));
    return;
  }
  bool flag = action->get_id() != secret_api::sendMessageCancelAction::ID;

  auto net_query =
      create_net_query(QueryType::Ignore, telegram_api::messages_setEncryptedTyping(get_input_chat(), flag));
  if (!set_typing_query_.empty()) {
    LOG(INFO) << "Cancel previous set typing query";
    cancel_query(set_typing_query_);
  }
  set_typing_query_ = net_query.get_weak();
  context_->send_net_query(std::move(net_query), actor_shared(this), false);
}

void SecretChatActor::send_read_history(int32 date, Promise<> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    LOG(ERROR) << "Ignore send_read_history: " << tag("date", date);
    promise.set_error(Status::Error(400, "Can't access the chat"));
    return;
  }

  if (date <= last_read_history_date_) {
    return promise.set_value(Unit());
  }

  if (read_history_promise_) {
    LOG(INFO) << "Cancel previous read history request in secret chat " << auth_state_.id;
    read_history_promise_.set_value(Unit());
    cancel_query(read_history_query_);
  }

  auto net_query =
      create_net_query(QueryType::ReadHistory, telegram_api::messages_readEncryptedHistory(get_input_chat(), date));
  read_history_query_ = net_query.get_weak();
  last_read_history_date_ = date;
  read_history_promise_ = std::move(promise);
  LOG(INFO) << "Send read history request with date " << date << " in secret chat " << auth_state_.id;
  context_->send_net_query(std::move(net_query), actor_shared(this), false);
}

void SecretChatActor::send_open_message(int64 random_id, Promise<> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    promise.set_error(Status::Error(400, "Can't access the chat"));
    return;
  }
  std::vector<int64> random_ids{random_id};
  send_action(make_tl_object<secret_api::decryptedMessageActionReadMessages>(std::move(random_ids)), SendFlag::Push,
              std::move(promise));
}

void SecretChatActor::delete_message(int64 random_id, Promise<> promise) {
  if (auth_state_.state == State::Closed) {
    promise.set_value(Unit());
    return;
  }
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    promise.set_error(Status::Error(400, "Can't access the chat"));
    return;
  }
  return delete_messages(std::vector<int64>{random_id}, std::move(promise));
}

void SecretChatActor::delete_messages(std::vector<int64> random_ids, Promise<> promise) {
  if (auth_state_.state == State::Closed) {
    promise.set_value(Unit());
    return;
  }
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    promise.set_error(Status::Error(400, "Can't access the chat"));
    return;
  }
  send_action(make_tl_object<secret_api::decryptedMessageActionDeleteMessages>(std::move(random_ids)), SendFlag::Push,
              std::move(promise));
}
void SecretChatActor::delete_all_messages(Promise<> promise) {
  if (auth_state_.state == State::Closed) {
    promise.set_value(Unit());
    return;
  }
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    promise.set_error(Status::Error(400, "Can't access the chat"));
    return;
  }
  send_action(make_tl_object<secret_api::decryptedMessageActionFlushHistory>(), SendFlag::Push, std::move(promise));
}

void SecretChatActor::notify_screenshot_taken(Promise<> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    promise.set_error(Status::Error(400, "Can't access the chat"));
    return;
  }
  send_action(make_tl_object<secret_api::decryptedMessageActionScreenshotMessages>(vector<int64>()), SendFlag::Push,
              std::move(promise));
}

void SecretChatActor::send_set_ttl_message(int32 ttl, int64 random_id, Promise<> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  if (auth_state_.state != State::Ready) {
    promise.set_error(Status::Error(400, "Can't access the chat"));
    return;
  }
  send_message_impl(secret_api::make_object<secret_api::decryptedMessageService>(
                        random_id, make_tl_object<secret_api::decryptedMessageActionSetMessageTTL>(ttl)),
                    nullptr, SendFlag::External | SendFlag::Push, std::move(promise));
}

void SecretChatActor::send_action(tl_object_ptr<secret_api::DecryptedMessageAction> action, int32 flags,
                                  Promise<> promise) {
  send_message_impl(
      secret_api::make_object<secret_api::decryptedMessageService>(Random::secure_int64(), std::move(action)), nullptr,
      flags, std::move(promise));
}

void SecretChatActor::binlog_replay_finish() {
  on_his_in_seq_no_updated();
  LOG(INFO) << "Binlog replay is finished with SeqNoState " << seq_no_state_;
  LOG(INFO) << "Binlog replay is finished with PfsState " << pfs_state_;
  binlog_replay_finish_flag_ = true;
  if (auth_state_.state == State::Ready) {
    auto my_layer = static_cast<int32>(SecretChatLayer::Current);
    if (config_state_.my_layer < my_layer) {
      send_action(secret_api::make_object<secret_api::decryptedMessageActionNotifyLayer>(my_layer), SendFlag::None,
                  Promise<>());
    }
  }
  yield();
}

void SecretChatActor::loop() {
  if (close_flag_) {
    return;
  }
  if (!binlog_replay_finish_flag_) {
    return;
  }

  check_status(do_loop());
}

Status SecretChatActor::do_loop() {
  TRY_STATUS(run_auth());
  run_pfs();
  run_fill_gaps();
  return Status::OK();
}

void SecretChatActor::on_send_message_ack(int64 random_id) {
  context_->on_send_message_ack(random_id);
}

Status SecretChatActor::on_delete_messages(const std::vector<int64> &random_ids) {
  for (auto random_id : random_ids) {
    auto it = random_id_to_outbound_message_state_token_.find(random_id);
    if (it == random_id_to_outbound_message_state_token_.end()) {
      continue;
    }
    auto state_id = it->second;
    TRY_STATUS(outbound_rewrite_with_empty(state_id));
  }
  return Status::OK();
}

Status SecretChatActor::on_flush_history(int32 last_message_id) {
  std::vector<uint64> to_rewrite;
  outbound_message_states_.for_each([&](auto state_id, auto &state) {
    if (state.message->message_id < last_message_id && state.message->is_rewritable) {
      to_rewrite.push_back(state_id);
    }
  });
  for (auto state_id : to_rewrite) {
    TRY_STATUS(outbound_rewrite_with_empty(state_id));
  }
  return Status::OK();
}

Status SecretChatActor::run_auth() {
  switch (auth_state_.state) {
    case State::Empty:
      return Status::OK();
    case State::SendRequest: {
      if (!auth_state_.handshake.has_config()) {
        return Status::OK();
      }
      // messages.requestEncryption#f64daf43 user_id:InputUser random_id:int g_a:bytes = EncryptedChat;
      auto query = create_net_query(QueryType::EncryptedChat, telegram_api::messages_requestEncryption(
                                                                  get_input_user(), auth_state_.random_id,
                                                                  BufferSlice(auth_state_.handshake.get_g_b())));
      context_->send_net_query(std::move(query), actor_shared(this), false);
      auth_state_.state = State::WaitRequestResponse;
      return Status::OK();
    }
    case State::SendAccept: {
      if (!auth_state_.handshake.has_config()) {
        return Status::OK();
      }
      TRY_STATUS(auth_state_.handshake.run_checks(true, context_->dh_callback()));
      auto id_and_key = auth_state_.handshake.gen_key();
      pfs_state_.auth_key = mtproto::AuthKey(id_and_key.first, std::move(id_and_key.second));
      calc_key_hash();
      // messages.acceptEncryption#3dbc0415 peer:InputEncryptedChat g_b:bytes key_fingerprint:long = EncryptedChat;
      auto query = create_net_query(
          QueryType::EncryptedChat,
          telegram_api::messages_acceptEncryption(get_input_chat(), BufferSlice(auth_state_.handshake.get_g_b()),
                                                  pfs_state_.auth_key.id()));
      context_->send_net_query(std::move(query), actor_shared(this), false);
      auth_state_.state = State::WaitAcceptResponse;
      return Status::OK();
    }
    default:
      break;
  }
  return Status::OK();
}

void SecretChatActor::run_fill_gaps() {
  // replay messages
  while (true) {
    if (pending_inbound_messages_.empty()) {
      break;
    }
    auto begin = pending_inbound_messages_.begin();
    auto next_seq_no = begin->first;
    if (next_seq_no <= seq_no_state_.my_in_seq_no) {
      LOG(INFO) << "Replay pending event: " << tag("seq_no", next_seq_no);
      auto message = std::move(begin->second);
      pending_inbound_messages_.erase(begin);
      check_status(do_inbound_message_decrypted_unchecked(std::move(message), -1));
      CHECK(pending_inbound_messages_.count(next_seq_no) == 0);
    } else {
      break;
    }
  }

  if (pending_inbound_messages_.empty()) {
    return;
  }

  auto start_seq_no = seq_no_state_.my_in_seq_no;
  auto finish_seq_no = pending_inbound_messages_.begin()->first - 1;
  LOG(INFO) << tag("start_seq_no", start_seq_no) << tag("finish_seq_no", finish_seq_no)
            << tag("resend_end_seq_no", seq_no_state_.resend_end_seq_no);
  CHECK(start_seq_no <= finish_seq_no);
  if (seq_no_state_.resend_end_seq_no >= finish_seq_no) {
    return;
  }
  CHECK(seq_no_state_.resend_end_seq_no < start_seq_no);

  start_seq_no = start_seq_no * 2 + auth_state_.x;
  finish_seq_no = finish_seq_no * 2 + auth_state_.x;

  send_action(secret_api::make_object<secret_api::decryptedMessageActionResend>(start_seq_no, finish_seq_no),
              SendFlag::None, Promise<>());
}

void SecretChatActor::run_pfs() {
  while (true) {
    LOG(INFO) << "Run PFS loop: " << pfs_state_;
    if (pfs_state_.state == PfsState::Empty &&
        (pfs_state_.last_message_id + 100 < seq_no_state_.message_id ||
         pfs_state_.last_timestamp + 60 * 60 * 24 * 7 < Time::now()) &&
        pfs_state_.other_auth_key.empty()) {
      LOG(INFO) << "Request new key";
      request_new_key();
    }
    switch (pfs_state_.state) {
      case PfsState::SendRequest: {
        // shouldn't wait, pfs_state is already saved explicitly
        pfs_state_.state = PfsState::WaitSendRequest;  // don't save it!
        send_action(secret_api::make_object<secret_api::decryptedMessageActionRequestKey>(
                        pfs_state_.exchange_id, BufferSlice(pfs_state_.handshake.get_g_b())),
                    SendFlag::None, Promise<>());
        break;
      }
      case PfsState::SendCommit: {
        // must wait till pfs_state is saved to binlog. Otherwise, we may save ActionCommit to binlog without pfs_state,
        // which has the new auth_key.
        if (saved_pfs_state_message_id_ < pfs_state_.wait_message_id) {
          return;
        }

        // TODO: wait till gaps are filled???
        pfs_state_.state = PfsState::WaitSendCommit;  // don't save it
        send_action(secret_api::make_object<secret_api::decryptedMessageActionCommitKey>(
                        pfs_state_.exchange_id, static_cast<int64>(pfs_state_.other_auth_key.id())),
                    SendFlag::None, Promise<>());

        break;
      }
      case PfsState::SendAccept: {
        if (saved_pfs_state_message_id_ < pfs_state_.wait_message_id) {
          return;
        }

        pfs_state_.state = PfsState::WaitSendAccept;  // don't save it
        send_action(secret_api::make_object<secret_api::decryptedMessageActionAcceptKey>(
                        pfs_state_.exchange_id, BufferSlice(pfs_state_.handshake.get_g_b()),
                        static_cast<int64>(pfs_state_.other_auth_key.id())),
                    SendFlag::None, Promise<>());

        break;
      }
      default:
        return;
    }
  }
}

void SecretChatActor::check_status(Status status) {
  if (status.is_error()) {
    if (status.code() == 1) {
      LOG(WARNING) << "Non-fatal error: " << status;
    } else {
      on_fatal_error(std::move(status), false);
    }
  }
}

void SecretChatActor::on_fatal_error(Status status, bool is_expected) {
  if (!is_expected) {
    LOG(ERROR) << "Fatal error: " << status;
  }
  cancel_chat(false, false, Promise<>());
}

void SecretChatActor::cancel_chat(bool delete_history, bool is_already_discarded, Promise<> promise) {
  if (close_flag_) {
    promise.set_value(Unit());
    return;
  }
  close_flag_ = true;

  std::vector<log_event::LogEvent::Id> to_delete;
  outbound_message_states_.for_each(
      [&](auto state_id, auto &state) { to_delete.push_back(state.message->log_event_id()); });
  inbound_message_states_.for_each([&](auto state_id, auto &state) { to_delete.push_back(state.log_event_id); });

  // TODO: It must be a transaction
  for (auto id : to_delete) {
    binlog_erase(context_->binlog(), id);
  }
  if (create_log_event_id_ != 0) {
    binlog_erase(context_->binlog(), create_log_event_id_);
    create_log_event_id_ = 0;
  }

  auto event = make_unique<log_event::CloseSecretChat>();
  event->chat_id = auth_state_.id;
  auto log_event_id = binlog_add(context_->binlog(), LogEvent::HandlerType::SecretChats, create_storer(*event));

  auto on_sync = PromiseCreator::lambda([actor_id = actor_id(this), delete_history, is_already_discarded, log_event_id,
                                         promise = std::move(promise)](Result<Unit> result) mutable {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::do_close_chat_impl, delete_history, is_already_discarded, log_event_id,
                   std::move(promise));
    } else {
      promise.set_error(result.error().clone());
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(), "cancel_chat");
    }
  });

  context_->binlog()->force_sync(std::move(on_sync), "cancel_chat");
  yield();
}

void SecretChatActor::do_close_chat_impl(bool delete_history, bool is_already_discarded, uint64 log_event_id,
                                         Promise<Unit> &&promise) {
  close_flag_ = true;
  auth_state_.state = State::Closed;
  context_->secret_chat_db()->set_value(auth_state_);
  context_->secret_chat_db()->erase_value(config_state_);
  context_->secret_chat_db()->erase_value(pfs_state_);
  context_->secret_chat_db()->erase_value(seq_no_state_);

  MultiPromiseActorSafe mpas{"CloseSecretChatMultiPromiseActor"};
  mpas.add_promise(
      PromiseCreator::lambda([actor_id = actor_id(this), log_event_id, promise = std::move(promise)](Unit) mutable {
        send_closure(actor_id, &SecretChatActor::on_closed, log_event_id, std::move(promise));
      }));

  auto lock = mpas.get_promise();

  if (delete_history) {
    context_->on_flush_history(true, MessageId::max(), mpas.get_promise());
  }

  send_update_secret_chat();

  if (!is_already_discarded) {
    int32 flags = 0;
    if (delete_history) {
      flags |= telegram_api::messages_discardEncryption::DELETE_HISTORY_MASK;
    }
    auto query = create_net_query(QueryType::DiscardEncryption,
                                  telegram_api::messages_discardEncryption(flags, false /*ignored*/, auth_state_.id));
    query->total_timeout_limit_ = 60 * 60 * 24 * 365;
    context_->send_net_query(std::move(query), actor_shared(this), true);
    discard_encryption_promise_ = mpas.get_promise();
  }

  lock.set_value(Unit());
}

void SecretChatActor::on_closed(uint64 log_event_id, Promise<Unit> &&promise) {
  CHECK(close_flag_);
  if (context_->close_flag()) {
    return;
  }

  LOG(INFO) << "Finish closing";
  context_->secret_chat_db()->erase_value(auth_state_);
  binlog_erase(context_->binlog(), log_event_id);
  promise.set_value(Unit());
  // skip flush
  stop();
}

void SecretChatActor::do_create_chat_impl(unique_ptr<log_event::CreateSecretChat> event) {
  LOG(INFO) << *event;
  CHECK(event->random_id == auth_state_.id);
  create_log_event_id_ = event->log_event_id();

  if (auth_state_.state == State::Empty) {
    auth_state_.user_id = event->user_id;
    auth_state_.user_access_hash = event->user_access_hash;
    auth_state_.random_id = event->random_id;
    auth_state_.state = State::SendRequest;
    auth_state_.x = 0;
    auth_state_.date = context_->unix_time();
    send_update_secret_chat();
  } else if (auth_state_.state == State::SendRequest) {
  } else if (auth_state_.state == State::WaitRequestResponse) {
  } else {
    binlog_erase(context_->binlog(), create_log_event_id_);
    create_log_event_id_ = 0;
  }
}

telegram_api::object_ptr<telegram_api::inputUser> SecretChatActor::get_input_user() {
  return telegram_api::make_object<telegram_api::inputUser>(auth_state_.user_id.get(), auth_state_.user_access_hash);
}
telegram_api::object_ptr<telegram_api::inputEncryptedChat> SecretChatActor::get_input_chat() {
  return telegram_api::make_object<telegram_api::inputEncryptedChat>(auth_state_.id, auth_state_.access_hash);
}
void SecretChatActor::tear_down() {
  LOG(INFO) << "SecretChatActor: tear_down";
  // TODO notify send update that we are dead
}

Result<std::tuple<uint64, BufferSlice, int32>> SecretChatActor::decrypt(BufferSlice &encrypted_message) {
  MutableSlice data = encrypted_message.as_mutable_slice();
  CHECK(is_aligned_pointer<4>(data.data()));
  TRY_RESULT(auth_key_id, mtproto::Transport::read_auth_key_id(data));
  mtproto::AuthKey *auth_key = nullptr;
  if (auth_key_id == pfs_state_.auth_key.id()) {
    auth_key = &pfs_state_.auth_key;
  } else if (auth_key_id == pfs_state_.other_auth_key.id()) {
    auth_key = &pfs_state_.other_auth_key;
  } else {
    return Status::Error(1, PSLICE() << "Unknown " << tag("auth_key_id", format::as_hex(auth_key_id))
                                     << tag("crc", crc64(encrypted_message.as_slice())));
  }

  std::array<int, 2> versions{{2, 1}};
  BufferSlice encrypted_message_copy;
  int32 mtproto_version = -1;
  Result<mtproto::Transport::ReadResult> r_read_result;
  for (size_t i = 0; i < versions.size(); i++) {
    encrypted_message_copy = encrypted_message.copy();
    data = encrypted_message_copy.as_mutable_slice();
    CHECK(is_aligned_pointer<4>(data.data()));

    mtproto::PacketInfo packet_info;
    packet_info.type = mtproto::PacketInfo::EndToEnd;
    mtproto_version = versions[i];
    packet_info.version = mtproto_version;
    packet_info.is_creator = auth_state_.x == 0;
    r_read_result = mtproto::Transport::read(data, *auth_key, &packet_info);
    if (i + 1 != versions.size() && r_read_result.is_error()) {
      if (config_state_.his_layer >= static_cast<int32>(SecretChatLayer::Mtproto2)) {
        LOG(WARNING) << tag("mtproto", mtproto_version) << " decryption failed " << r_read_result.error();
      }
      continue;
    }
    break;
  }
  TRY_RESULT(read_result, std::move(r_read_result));
  switch (read_result.type()) {
    case mtproto::Transport::ReadResult::Quickack:
      return Status::Error("Receive quickack instead of a message");
    case mtproto::Transport::ReadResult::Error:
      return Status::Error(PSLICE() << "Receive MTProto error code instead of a message: " << read_result.error());
    case mtproto::Transport::ReadResult::Nop:
      return Status::Error("Receive nop instead of a message");
    case mtproto::Transport::ReadResult::Packet:
      data = read_result.packet();
      break;
    default:
      UNREACHABLE();
  }

  int32 len = as<int32>(data.begin());
  data = data.substr(4, len);
  if (!is_aligned_pointer<4>(data.data())) {
    return std::make_tuple(auth_key_id, BufferSlice(data), mtproto_version);
  } else {
    return std::make_tuple(auth_key_id, encrypted_message_copy.from_slice(data), mtproto_version);
  }
}

Status SecretChatActor::do_inbound_message_encrypted(unique_ptr<log_event::InboundSecretMessage> message) {
  SCOPE_EXIT {
    if (message) {
      message->promise.set_value(Unit());
    }
  };
  TRY_RESULT(decrypted, decrypt(message->encrypted_message));
  auto auth_key_id = std::get<0>(decrypted);
  auto data_buffer = std::move(std::get<1>(decrypted));
  auto mtproto_version = std::get<2>(decrypted);
  message->auth_key_id = auth_key_id;

  TlBufferParser parser(&data_buffer);
  auto id = parser.fetch_int();
  Status status;
  if (id == secret_api::decryptedMessageLayer::ID) {
    auto message_with_layer = secret_api::decryptedMessageLayer::fetch(parser);
    parser.fetch_end();
    if (!parser.get_error()) {
      auto layer = message_with_layer->layer_;
      if (layer < static_cast<int32>(SecretChatLayer::Default) &&
          false /* old Android app could send such messages */) {
        LOG(ERROR) << "Layer " << layer << " is not supported, drop message " << to_string(message_with_layer);
        return Status::OK();
      }
      if (config_state_.his_layer < layer) {
        config_state_.his_layer = layer;
        context_->secret_chat_db()->set_value(config_state_);
        send_update_secret_chat();
      }
      if (layer >= static_cast<int32>(SecretChatLayer::Mtproto2) && mtproto_version < 2) {
        return Status::Error("MTProto 1.0 encryption is forbidden for this layer");
      }
      if (message_with_layer->in_seq_no_ < 0) {
        return Status::Error(PSLICE() << "Invalid seq_no: " << to_string(message_with_layer));
      }
      message->decrypted_message_layer = std::move(message_with_layer);
      return do_inbound_message_decrypted_unchecked(std::move(message), mtproto_version);
    } else {
      status = Status::Error(PSLICE() << parser.get_error() << format::as_hex_dump<4>(data_buffer.as_slice()));
    }
  } else {
    status = Status::Error(PSLICE() << "Unknown constructor " << format::as_hex(id));
  }

  // support for older layer
  LOG(WARNING) << "Failed to fetch update: " << status;
  send_action(secret_api::make_object<secret_api::decryptedMessageActionNotifyLayer>(
                  static_cast<int32>(SecretChatLayer::Current)),
              SendFlag::None, Promise<>());

  if (config_state_.his_layer == 8) {
    TlBufferParser new_parser(&data_buffer);
    auto message_without_layer = secret_api::DecryptedMessage::fetch(new_parser);
    parser.fetch_end();
    if (!new_parser.get_error()) {
      message->decrypted_message_layer = secret_api::make_object<secret_api::decryptedMessageLayer>(
          BufferSlice(), config_state_.his_layer, -1, -1, std::move(message_without_layer));
      return do_inbound_message_decrypted_unchecked(std::move(message), mtproto_version);
    }
    LOG(ERROR) << "Failed to fetch update (DecryptedMessage): " << new_parser.get_error()
               << format::as_hex_dump<4>(data_buffer.as_slice());
  }

  return status;
}

Status SecretChatActor::check_seq_no(int in_seq_no, int out_seq_no, int32 his_layer) {
  if (in_seq_no < 0) {
    return Status::OK();
  }
  if (in_seq_no % 2 != (1 - auth_state_.x) || out_seq_no % 2 != auth_state_.x) {
    return Status::Error("Bad seq_no parity");
  }
  in_seq_no /= 2;
  out_seq_no /= 2;
  if (out_seq_no < seq_no_state_.my_in_seq_no) {
    return Status::Error(1, "Old seq_no");
  }
  if (out_seq_no > seq_no_state_.my_in_seq_no) {
    return Status::Error(2, "Gap found!");
  }
  if (in_seq_no < seq_no_state_.his_in_seq_no) {
    return Status::Error("in_seq_no is not monotonic");
  }
  if (seq_no_state_.my_out_seq_no < in_seq_no) {
    return Status::Error("in_seq_no is bigger than seq_no_state_.my_out_seq_no");
  }
  if (his_layer < seq_no_state_.his_layer) {
    return Status::Error("his_layer is not monotonic");
  }

  return Status::OK();
}

Status SecretChatActor::do_inbound_message_decrypted_unchecked(unique_ptr<log_event::InboundSecretMessage> message,
                                                               int32 mtproto_version) {
  SCOPE_EXIT {
    CHECK(message == nullptr || !message->promise);
  };
  auto in_seq_no = message->decrypted_message_layer->in_seq_no_;
  auto out_seq_no = message->decrypted_message_layer->out_seq_no_;
  auto status = check_seq_no(in_seq_no, out_seq_no, message->his_layer());
  if (status.is_error() && status.code() != 2 /* not gap found */) {
    message->promise.set_value(Unit());
    if (message->log_event_id()) {
      LOG(INFO) << "Erase binlog event: " << tag("log_event_id", message->log_event_id());
      binlog_erase(context_->binlog(), message->log_event_id());
    }
    auto warning_message = PSTRING() << status << tag("seq_no_state_.my_in_seq_no", seq_no_state_.my_in_seq_no)
                                     << tag("seq_no_state_.my_out_seq_no", seq_no_state_.my_out_seq_no)
                                     << tag("seq_no_state_.his_in_seq_no", seq_no_state_.his_in_seq_no)
                                     << tag("in_seq_no", in_seq_no) << tag("out_seq_no", out_seq_no)
                                     << to_string(message->decrypted_message_layer);
    if (status.code()) {
      LOG(WARNING) << warning_message;
    } else {
      LOG(ERROR) << warning_message;
    }
    return status;
  }

  LOG(INFO) << "Receive message encrypted with MTProto " << mtproto_version << ": "
            << to_string(message->decrypted_message_layer);

  if (message->decrypted_message_layer->message_->get_id() == secret_api::decryptedMessageService8::ID) {
    auto old = move_tl_object_as<secret_api::decryptedMessageService8>(message->decrypted_message_layer->message_);
    message->decrypted_message_layer->message_ =
        secret_api::make_object<secret_api::decryptedMessageService>(old->random_id_, std::move(old->action_));
  }

  // Process ActionResend.
  if (message->decrypted_message_layer->message_->get_id() == secret_api::decryptedMessageService::ID) {
    auto *decrypted_message_service =
        static_cast<secret_api::decryptedMessageService *>(message->decrypted_message_layer->message_.get());
    if (decrypted_message_service->action_->get_id() == secret_api::decryptedMessageActionResend::ID) {
      auto *action_resend =
          static_cast<secret_api::decryptedMessageActionResend *>(decrypted_message_service->action_.get());

      auto start_seq_no = static_cast<uint32>(action_resend->start_seq_no_ / 2);
      auto finish_seq_no = static_cast<uint32>(action_resend->end_seq_no_ / 2);
      if (start_seq_no + MAX_RESEND_COUNT < finish_seq_no) {
        message->promise.set_value(Unit());
        return Status::Error("Can't resend too many messages");
      }
      LOG(INFO) << "ActionResend: " << tag("start", start_seq_no) << tag("finish_seq_no", finish_seq_no);
      for (auto seq_no = start_seq_no; seq_no <= finish_seq_no; seq_no++) {
        auto it = out_seq_no_to_outbound_message_state_token_.find(seq_no);
        if (it == out_seq_no_to_outbound_message_state_token_.end()) {
          message->promise.set_value(Unit());
          return Status::Error(PSLICE() << "Can't resend query " << tag("seq_no", seq_no));
        }
        auto state_id = it->second;
        outbound_resend(state_id);
      }
      // It is ok to replace action with Noop, because it won't be written to binlog before message is marked unsent
      decrypted_message_service->action_ = secret_api::make_object<secret_api::decryptedMessageActionNoop>();
    }
  }

  if (status.is_error()) {
    CHECK(status.code() == 2);  // gap found
    do_inbound_message_decrypted_pending(std::move(message));
    return Status::OK();
  }

  message->message_id = seq_no_state_.message_id + 1;
  if (in_seq_no != -1) {
    message->my_in_seq_no = out_seq_no / 2 + 1;
    message->my_out_seq_no = seq_no_state_.my_out_seq_no;
    message->his_in_seq_no = in_seq_no / 2;
  }

  return do_inbound_message_decrypted(std::move(message));
}

void SecretChatActor::do_outbound_message_impl(unique_ptr<log_event::OutboundSecretMessage> binlog_event,
                                               Promise<> promise) {
  binlog_event->crc = crc64(binlog_event->encrypted_message.as_slice());
  LOG(INFO) << "Do outbound message: " << *binlog_event << tag("crc", binlog_event->crc);
  auto &state_id_ref = random_id_to_outbound_message_state_token_[binlog_event->random_id];
  LOG_CHECK(state_id_ref == 0) << "Random ID collision";
  state_id_ref = outbound_message_states_.create();
  const uint64 state_id = state_id_ref;
  auto *state = outbound_message_states_.get(state_id);
  LOG(INFO) << tag("state_id", state_id);
  CHECK(state);
  state->message = std::move(binlog_event);

  // OutboundSecretMessage
  //
  // 1. [] => Save log_event. [save_log_event]
  // 2. [save_log_event] => Save SeqNoState [save_changes]
  // 3. [save_log_event] => Send NetQuery [send_message]
  //   Note: we have to force binlog to flush
  // 4.0 [send_message]:Fail => rewrite
  // 4. [save_changes; send_message] => Mark log event as sent [rewrite_log_event]
  // 5. [save_changes; send_message; ack] => [remove_log_event]

  auto message = state->message.get();

  // send_message
  auto send_message_start = PromiseCreator::lambda([actor_id = actor_id(this), state_id](Result<> result) {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::on_outbound_send_message_start, state_id);
    } else {
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(),
                   "on_outbound_send_message_start");
    }
  });

  // update seq_no
  update_seq_no_state(*message);

  // process action
  if (message->action) {
    on_outbound_action(*message->action, message->message_id);
  }

  // save_changes
  auto save_changes_finish = PromiseCreator::lambda([actor_id = actor_id(this), state_id](Result<> result) {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::on_outbound_save_changes_finish, state_id);
    } else {
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(),
                   "on_outbound_save_chages_finish");
    }
  });

  auto save_changes_start = add_changes(std::move(save_changes_finish));

  // wait for ack
  auto out_seq_no = state->message->my_out_seq_no - 1;
  if (out_seq_no < seq_no_state_.his_in_seq_no) {
    state->ack_flag = true;
  } else {
    out_seq_no_to_outbound_message_state_token_[out_seq_no] = state_id;
  }

  // save_log_event => [send_message; save_changes]
  auto save_log_event_finish = PromiseCreator::join(std::move(send_message_start), std::move(save_changes_start));

  auto log_event_id = state->message->log_event_id();
  if (log_event_id == 0) {
    log_event_id = binlog_add(context_->binlog(), LogEvent::HandlerType::SecretChats, create_storer(*state->message));
    LOG(INFO) << "Outbound secret message [save_log_event] start " << tag("log_event_id", log_event_id);
    context_->binlog()->force_sync(std::move(save_log_event_finish), "do_outbound_message_impl");
    state->message->set_log_event_id(log_event_id);
  } else {
    LOG(INFO) << "Outbound secret message [save_log_event] skip " << tag("log_event_id", log_event_id);
    save_log_event_finish.set_value(Unit());
  }
  promise.set_value(Unit());  // log event was sent to binlog
}

void SecretChatActor::on_his_in_seq_no_updated() {
  auto it = out_seq_no_to_outbound_message_state_token_.begin();
  while (it != out_seq_no_to_outbound_message_state_token_.end() && it->first < seq_no_state_.his_in_seq_no) {
    auto token = it->second;
    it = out_seq_no_to_outbound_message_state_token_.erase(it);
    on_outbound_ack(token);
  }
}
void SecretChatActor::on_seq_no_state_changed() {
  seq_no_state_changed_ = true;
}

void SecretChatActor::on_pfs_state_changed() {
  LOG(INFO) << "In on_pfs_state_changed: " << pfs_state_;
  pfs_state_changed_ = true;
}

Promise<> SecretChatActor::add_changes(Promise<> save_changes_finish) {
  StateChange change;
  if (seq_no_state_changed_) {
    change.seq_no_state_change = SeqNoStateChange(seq_no_state_);
    seq_no_state_changed_ = false;
  }
  if (pfs_state_changed_) {
    change.pfs_state_change = PfsStateChange(pfs_state_);
    pfs_state_changed_ = false;
  }

  change.save_changes_finish = std::move(save_changes_finish);
  auto save_changes_start_token = changes_processor_.add(std::move(change));

  return PromiseCreator::lambda([actor_id = actor_id(this), save_changes_start_token](Result<> result) {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::on_save_changes_start, save_changes_start_token);
    } else {
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(), "on_save_changes_start");
    }
  });
}

template <class T>
void SecretChatActor::update_seq_no_state(const T &new_seq_no_state) {
  // Some old updates may arrive. Just ignore them
  if (seq_no_state_.message_id >= new_seq_no_state.message_id &&
      seq_no_state_.my_in_seq_no >= new_seq_no_state.my_in_seq_no &&
      seq_no_state_.my_out_seq_no >= new_seq_no_state.my_out_seq_no &&
      seq_no_state_.his_in_seq_no >= new_seq_no_state.his_in_seq_no) {
    return;
  }
  seq_no_state_.message_id = new_seq_no_state.message_id;
  if (new_seq_no_state.my_in_seq_no != -1) {
    LOG(INFO) << "Have my_in_seq_no: " << seq_no_state_.my_in_seq_no << "--->" << new_seq_no_state.my_in_seq_no;
    seq_no_state_.my_in_seq_no = new_seq_no_state.my_in_seq_no;
    seq_no_state_.my_out_seq_no = new_seq_no_state.my_out_seq_no;

    auto new_his_layer = new_seq_no_state.his_layer();
    if (new_his_layer != -1) {
      seq_no_state_.his_layer = new_his_layer;
    }

    if (seq_no_state_.his_in_seq_no != new_seq_no_state.his_in_seq_no) {
      seq_no_state_.his_in_seq_no = new_seq_no_state.his_in_seq_no;
      on_his_in_seq_no_updated();
    }
  }

  return on_seq_no_state_changed();
}

void SecretChatActor::do_inbound_message_decrypted_pending(unique_ptr<log_event::InboundSecretMessage> message) {
  // Just save log event if necessary
  auto log_event_id = message->log_event_id();

  // QTS
  auto qts_promise = std::move(message->promise);

  if (log_event_id == 0) {
    message->is_pending = true;
    message->set_log_event_id(binlog_add(context_->binlog(), LogEvent::HandlerType::SecretChats,
                                         create_storer(*message), std::move(qts_promise)));
    LOG(INFO) << "Inbound PENDING secret message [save_log_event] start (do not expect finish) "
              << tag("log_event_id", message->log_event_id());
  } else {
    LOG(INFO) << "Inbound PENDING secret message [save_log_event] skip " << tag("log_event_id", log_event_id);
    CHECK(!qts_promise);
  }
  LOG(INFO) << "Inbound PENDING secret message start " << tag("log_event_id", log_event_id) << tag("message", *message);

  auto seq_no = message->decrypted_message_layer->out_seq_no_ / 2;
  pending_inbound_messages_[seq_no] = std::move(message);
}

Status SecretChatActor::do_inbound_message_decrypted(unique_ptr<log_event::InboundSecretMessage> message) {
  // InboundSecretMessage
  //
  // 1. [] => Add log event. [save_log_event]
  // 2. [save_log_event] => Save SeqNoState [save_changes]
  // 3. [save_log_event] => Add message to MessageManager [save_message]
  //    Note: if we are able to add message by random_id, we may not wait for (log event). Otherwise, we should force
  //    binlog flush.
  // 4. [save_log_event] => Update QTS [qts]
  // 5. [save_changes; save_message; ?qts) => Remove log event [remove_log_event]
  //    Note: It is easier not to wait for QTS. In the worst case old update will be handled again after restart.

  auto state_id = inbound_message_states_.create();
  InboundMessageState &state = *inbound_message_states_.get(state_id);

  // save log event
  auto log_event_id = message->log_event_id();
  bool need_sync = false;
  if (log_event_id == 0) {
    log_event_id = binlog_add(context_->binlog(), LogEvent::HandlerType::SecretChats, create_storer(*message));
    LOG(INFO) << "Inbound secret message [save_log_event] start " << tag("log_event_id", log_event_id);
    need_sync = true;
  } else {
    if (message->is_pending) {
      message->is_pending = false;
      auto old_log_event_id = log_event_id;
      log_event_id = binlog_add(context_->binlog(), LogEvent::HandlerType::SecretChats, create_storer(*message));
      binlog_erase(context_->binlog(), old_log_event_id);
      LOG(INFO) << "Inbound secret message [save_log_event] rewrite (after pending state) "
                << tag("log_event_id", log_event_id) << tag("old_log_event_id", old_log_event_id);
      need_sync = true;
    } else {
      LOG(INFO) << "Inbound secret message [save_log_event] skip " << tag("log_event_id", log_event_id);
    }
  }
  LOG(INFO) << "Inbound secret message start " << tag("log_event_id", log_event_id) << tag("message", *message);
  state.log_event_id = log_event_id;

  // save_message
  auto save_message_finish = PromiseCreator::lambda([actor_id = actor_id(this), state_id](Result<> result) {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::on_inbound_save_message_finish, state_id);
    } else {
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(),
                   "on_inbound_save_message_finish");
    }
  });

  // update seq_no
  update_seq_no_state(*message);

  // drop old key
  if (!pfs_state_.other_auth_key.empty() && message->auth_key_id == pfs_state_.auth_key.id() &&
      pfs_state_.can_forget_other_key) {
    LOG(INFO) << "Drop old auth key " << tag("auth_key_id", format::as_hex(pfs_state_.other_auth_key.id()));
    pfs_state_.other_auth_key = mtproto::AuthKey();
    on_pfs_state_changed();
  }

  // QTS
  auto qts_promise = std::move(message->promise);

  // process message
  if (message->decrypted_message_layer->message_->get_id() == secret_api::decryptedMessage46::ID) {
    auto old = move_tl_object_as<secret_api::decryptedMessage46>(message->decrypted_message_layer->message_);
    old->flags_ &= ~secret_api::decryptedMessage::GROUPED_ID_MASK;  // just in case
    message->decrypted_message_layer->message_ = secret_api::make_object<secret_api::decryptedMessage>(
        old->flags_, false /*ignored*/, old->random_id_, old->ttl_, std::move(old->message_), std::move(old->media_),
        std::move(old->entities_), std::move(old->via_bot_name_), old->reply_to_random_id_, 0);
  }
  if (message->decrypted_message_layer->message_->get_id() == secret_api::decryptedMessageService8::ID) {
    auto old = move_tl_object_as<secret_api::decryptedMessageService8>(message->decrypted_message_layer->message_);
    message->decrypted_message_layer->message_ =
        secret_api::make_object<secret_api::decryptedMessageService>(old->random_id_, std::move(old->action_));
  }

  // NB: message is invalid after this 'move_as'
  // Send update through context_
  // Note, that update may be sent multiple times and should be somehow protected from replay.
  // Luckily all updates seems to be idempotent.
  // We could use ChangesProcessor to mark log event as sent to context_, but I don't see any advantages of this
  // approach.
  if (message->decrypted_message_layer->message_->get_id() == secret_api::decryptedMessage::ID) {
    auto decrypted_message =
        move_tl_object_as<secret_api::decryptedMessage>(message->decrypted_message_layer->message_);
    context_->on_inbound_message(get_user_id(), MessageId(ServerMessageId(message->message_id)), message->date,
                                 std::move(message->file), std::move(decrypted_message),
                                 std::move(save_message_finish));
  } else if (message->decrypted_message_layer->message_->get_id() == secret_api::decryptedMessageService::ID) {
    auto decrypted_message_service =
        move_tl_object_as<secret_api::decryptedMessageService>(message->decrypted_message_layer->message_);

    auto action = std::move(decrypted_message_service->action_);
    switch (action->get_id()) {
      case secret_api::decryptedMessageActionDeleteMessages::ID:
        // Corresponding log event won't be deleted before promise returned by add_changes is set.
        context_->on_delete_messages(
            static_cast<const secret_api::decryptedMessageActionDeleteMessages &>(*action).random_ids_,
            std::move(save_message_finish));
        break;
      case secret_api::decryptedMessageActionFlushHistory::ID:
        context_->on_flush_history(false, MessageId(ServerMessageId(message->message_id)),
                                   std::move(save_message_finish));
        break;
      case secret_api::decryptedMessageActionReadMessages::ID: {
        const auto &random_ids =
            static_cast<const secret_api::decryptedMessageActionReadMessages &>(*action).random_ids_;
        if (random_ids.size() == 1) {
          context_->on_read_message(random_ids[0], std::move(save_message_finish));
        } else {  // probably never happens
          MultiPromiseActorSafe mpas{"ReadSecretMessagesMultiPromiseActor"};
          mpas.add_promise(std::move(save_message_finish));
          auto lock = mpas.get_promise();
          for (auto random_id : random_ids) {
            context_->on_read_message(random_id, mpas.get_promise());
          }
          lock.set_value(Unit());
        }
        break;
      }
      case secret_api::decryptedMessageActionScreenshotMessages::ID:
        context_->on_screenshot_taken(get_user_id(), MessageId(ServerMessageId(message->message_id)), message->date,
                                      decrypted_message_service->random_id_, std::move(save_message_finish));
        break;
      case secret_api::decryptedMessageActionSetMessageTTL::ID:
        context_->on_set_ttl(get_user_id(), MessageId(ServerMessageId(message->message_id)), message->date,
                             static_cast<const secret_api::decryptedMessageActionSetMessageTTL &>(*action).ttl_seconds_,
                             decrypted_message_service->random_id_, std::move(save_message_finish));
        break;
      default:
        save_message_finish.set_value(Unit());
        break;
    }

    state.message_id = message->message_id;
    TRY_STATUS(on_inbound_action(*action, message->message_id));
  } else {
    LOG(ERROR) << "IGNORE MESSAGE: " << to_string(message->decrypted_message_layer);
    save_message_finish.set_value(Unit());
  }

  // save_changes
  auto save_changes_finish = PromiseCreator::lambda([actor_id = actor_id(this), state_id](Result<> result) {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::on_inbound_save_changes_finish, state_id);
    } else {
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(),
                   "on_inbound_save_changes_finish");
    }
  });
  auto save_changes_start = add_changes(std::move(save_changes_finish));

  // save_log_event
  auto save_log_event_finish = PromiseCreator::join(std::move(save_changes_start), std::move(qts_promise));
  if (need_sync) {
    // TODO: lazy sync is enough
    context_->binlog()->force_sync(std::move(save_log_event_finish), "do_inbound_message_decrypted");
  } else {
    save_log_event_finish.set_value(Unit());
  }
  return Status::OK();
}

void SecretChatActor::on_save_changes_start(ChangesProcessor<StateChange>::Id save_changes_token) {
  if (close_flag_) {
    return;
  }
  SeqNoStateChange seq_no_state_change;
  PfsStateChange pfs_state_change;
  std::vector<Promise<Unit>> save_changes_finish_promises;
  changes_processor_.finish(save_changes_token, [&](StateChange &&change) {
    save_changes_finish_promises.emplace_back(std::move(change.save_changes_finish));
    if (change.seq_no_state_change) {
      seq_no_state_change = std::move(change.seq_no_state_change);
    }
    if (change.pfs_state_change) {
      pfs_state_change = std::move(change.pfs_state_change);
    }
  });
  if (seq_no_state_change) {
    LOG(INFO) << "SAVE SeqNoState " << seq_no_state_change;
    context_->secret_chat_db()->set_value(seq_no_state_change);
  }
  if (pfs_state_change) {
    LOG(INFO) << "SAVE PfsState " << pfs_state_change;
    saved_pfs_state_message_id_ = pfs_state_change.message_id;
    context_->secret_chat_db()->set_value(pfs_state_change);
  }
  // NB: we may not wait till database is flushed, because every other change will be in the same binlog
  for (auto &save_changes_finish : save_changes_finish_promises) {
    save_changes_finish.set_value(Unit());
  }
}

void SecretChatActor::on_inbound_save_message_finish(uint64 state_id) {
  if (close_flag_ || context_->close_flag()) {
    return;
  }
  auto *state = inbound_message_states_.get(state_id);
  CHECK(state);
  LOG(INFO) << "Inbound message [save_message] finish " << tag("log_event_id", state->log_event_id);
  state->save_message_finish = true;
  inbound_loop(state, state_id);
}

void SecretChatActor::on_inbound_save_changes_finish(uint64 state_id) {
  if (close_flag_) {
    return;
  }
  auto *state = inbound_message_states_.get(state_id);
  CHECK(state);
  LOG(INFO) << "Inbound message [save_changes] finish " << tag("log_event_id", state->log_event_id);
  state->save_changes_finish = true;
  inbound_loop(state, state_id);
}

void SecretChatActor::inbound_loop(InboundMessageState *state, uint64 state_id) {
  if (close_flag_) {
    return;
  }
  if (!state->save_changes_finish || !state->save_message_finish) {
    return;
  }
  LOG(INFO) << "Inbound message [remove_log_event] start " << tag("log_event_id", state->log_event_id);
  binlog_erase(context_->binlog(), state->log_event_id);

  inbound_message_states_.erase(state_id);
}

NetQueryPtr SecretChatActor::create_net_query(const log_event::OutboundSecretMessage &message) {
  NetQueryPtr query;
  if (message.need_notify_user) {
    CHECK(message.file.empty());
    query = create_net_query(QueryType::Message,
                             telegram_api::messages_sendEncryptedService(get_input_chat(), message.random_id,
                                                                         message.encrypted_message.clone()));
  } else if (message.file.empty()) {
    int32 flags = 0;
    if (message.is_silent) {
      flags |= telegram_api::messages_sendEncrypted::SILENT_MASK;
    }
    query = create_net_query(
        QueryType::Message, telegram_api::messages_sendEncrypted(flags, false /*ignored*/, get_input_chat(),
                                                                 message.random_id, message.encrypted_message.clone()));
  } else {
    int32 flags = 0;
    if (message.is_silent) {
      flags |= telegram_api::messages_sendEncryptedFile::SILENT_MASK;
    }
    query = create_net_query(QueryType::Message,
                             telegram_api::messages_sendEncryptedFile(
                                 flags, false /*ignored*/, get_input_chat(), message.random_id,
                                 message.encrypted_message.clone(), message.file.as_input_encrypted_file()));
  }
  if (!message.is_rewritable) {
    query->total_timeout_limit_ = 1000000000;  // inf. We will re-sent it immediately anyway
  }
  if (message.is_external && context_->get_config_option_boolean("use_quick_ack")) {
    query->quick_ack_promise_ =
        PromiseCreator::lambda([actor_id = actor_id(this), random_id = message.random_id](Result<Unit> result) {
          if (result.is_ok()) {
            send_closure(actor_id, &SecretChatActor::on_send_message_ack, random_id);
          }
        });
  }

  return query;
}

void SecretChatActor::on_outbound_send_message_start(uint64 state_id) {
  auto *state = outbound_message_states_.get(state_id);
  if (state == nullptr) {
    LOG(INFO) << "Outbound message [send_message] start ignored (unknown state_id) " << tag("state_id", state_id);
    return;
  }

  auto *message = state->message.get();

  if (!message->is_sent) {
    LOG(INFO) << "Outbound message [send_message] start " << tag("log_event_id", state->message->log_event_id());
    auto query = create_net_query(*message);
    state->net_query_id = query->id();
    state->net_query_ref = query.get_weak();
    state->net_query_may_fail = state->message->is_rewritable;
    context_->send_net_query(std::move(query), actor_shared(this, state_id), true);
  } else {
    LOG(INFO) << "Outbound message [send_message] start dummy " << tag("log_event_id", state->message->log_event_id());
    on_outbound_send_message_finish(state_id);
  }
}

void SecretChatActor::outbound_resend(uint64 state_id) {
  if (close_flag_) {
    return;
  }
  auto *state = outbound_message_states_.get(state_id);
  CHECK(state);

  state->message->is_sent = false;
  state->net_query_id = 0;
  state->net_query_ref = NetQueryRef();
  LOG(INFO) << "Outbound message [resend] " << tag("log_event_id", state->message->log_event_id())
            << tag("state_id", state_id);

  binlog_rewrite(context_->binlog(), state->message->log_event_id(), LogEvent::HandlerType::SecretChats,
                 create_storer(*state->message));
  auto send_message_start = PromiseCreator::lambda([actor_id = actor_id(this), state_id](Result<> result) {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::on_outbound_send_message_start, state_id);
    } else {
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(),
                   "on_outbound_send_message_start");
    }
  });
  context_->binlog()->force_sync(std::move(send_message_start), "outbound_resend");
}

Status SecretChatActor::outbound_rewrite_with_empty(uint64 state_id) {
  if (close_flag_) {
    return Status::OK();
  }
  auto *state = outbound_message_states_.get(state_id);
  if (state == nullptr || !state->message->is_rewritable) {
    return Status::OK();
  }
  cancel_query(state->net_query_ref);

  Slice data = state->message->encrypted_message.as_slice();
  CHECK(is_aligned_pointer<4>(data.data()));

  // Rewrite with delete itself
  tl_object_ptr<secret_api::DecryptedMessage> message = secret_api::make_object<secret_api::decryptedMessageService>(
      state->message->random_id, secret_api::make_object<secret_api::decryptedMessageActionDeleteMessages>(
                                     std::vector<int64>{static_cast<int64>(state->message->random_id)}));

  TRY_RESULT(encrypted_message,
             create_encrypted_message(state->message->my_in_seq_no, state->message->my_out_seq_no, message));
  state->message->encrypted_message = std::move(encrypted_message);
  LOG(INFO) << tag("crc", crc64(state->message->encrypted_message.as_slice()));
  state->message->is_rewritable = false;
  state->message->is_external = false;
  state->message->need_notify_user = false;
  state->message->is_silent = true;
  state->message->file = log_event::EncryptedInputFile();
  binlog_rewrite(context_->binlog(), state->message->log_event_id(), LogEvent::HandlerType::SecretChats,
                 create_storer(*state->message));
  return Status::OK();
}

void SecretChatActor::on_outbound_send_message_result(NetQueryPtr query, Promise<NetQueryPtr> resend_promise) {
  if (close_flag_) {
    return;
  }
  auto state_id = get_link_token();
  auto *state = outbound_message_states_.get(state_id);
  if (!state) {
    LOG(INFO) << "Ignore old net query result " << tag("state_id", state_id);
    query->clear();
    return;
  }
  CHECK(state);
  if (state->net_query_id != query->id()) {
    LOG(INFO) << "Ignore old net query result " << tag("log_event_id", state->message->log_event_id())
              << tag("query_id", query->id()) << tag("state_query_id", state->net_query_id) << query;
    query->clear();
    return;
  }

  state->net_query_id = 0;
  state->net_query_ref = NetQueryRef();

  auto r_result = fetch_result<telegram_api::messages_sendEncrypted>(std::move(query));
  if (r_result.is_error()) {
    auto error = r_result.move_as_error();

    auto send_message_error_promise =
        PromiseCreator::lambda([actor_id = actor_id(this), state_id, error = error.clone(),
                                resend_promise = std::move(resend_promise)](Result<> result) mutable {
          if (result.is_ok()) {
            send_closure(actor_id, &SecretChatActor::on_outbound_send_message_error, state_id, std::move(error),
                         std::move(resend_promise));
          } else {
            send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(),
                         "on_outbound_send_message_error");
          }
        });

    if (state->message->is_external) {
      LOG(INFO) << "Outbound secret message [send_message] failed, rewrite it with dummy "
                << tag("log_event_id", state->message->log_event_id()) << tag("error", error);
      state->send_result_ = [this, random_id = state->message->random_id, error_code = error.code(),
                             error_message = error.message().str()](Promise<> promise) {
        context_->on_send_message_error(random_id, Status::Error(error_code, error_message), std::move(promise));
      };
      state->send_result_(std::move(send_message_error_promise));
    } else {
      // Just resend.
      LOG(INFO) << "Outbound secret message [send_message] failed, resend it "
                << tag("log_event_id", state->message->log_event_id()) << tag("error", error);
      send_message_error_promise.set_value(Unit());
    }
    return;
  }

  auto result = r_result.move_as_ok();
  LOG(INFO) << "Receive messages_sendEncrypted result: " << tag("message_id", state->message->message_id)
            << tag("random_id", state->message->random_id) << to_string(*result);

  auto send_message_finish_promise = PromiseCreator::lambda([actor_id = actor_id(this), state_id](Result<> result) {
    if (result.is_ok()) {
      send_closure(actor_id, &SecretChatActor::on_outbound_send_message_finish, state_id);
    } else {
      send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(),
                   "on_outbound_send_message_finish");
    }
  });

  if (state->message->is_external) {
    switch (result->get_id()) {
      case telegram_api::messages_sentEncryptedMessage::ID: {
        auto sent = move_tl_object_as<telegram_api::messages_sentEncryptedMessage>(result);
        state->send_result_ = [this, random_id = state->message->random_id,
                               message_id = MessageId(ServerMessageId(state->message->message_id)),
                               date = sent->date_](Promise<> promise) {
          context_->on_send_message_ok(random_id, message_id, date, nullptr, std::move(promise));
        };
        state->send_result_(std::move(send_message_finish_promise));
        return;
      }
      case telegram_api::messages_sentEncryptedFile::ID: {
        auto sent = move_tl_object_as<telegram_api::messages_sentEncryptedFile>(result);
        auto file = EncryptedFile::get_encrypted_file(std::move(sent->file_));
        if (file == nullptr) {
          state->message->file = log_event::EncryptedInputFile();
          state->send_result_ = [this, random_id = state->message->random_id,
                                 message_id = MessageId(ServerMessageId(state->message->message_id)),
                                 date = sent->date_](Promise<> promise) {
            context_->on_send_message_ok(random_id, message_id, date, nullptr, std::move(promise));
          };
        } else {
          state->message->file = {log_event::EncryptedInputFile::Location, file->id_, file->access_hash_, 0, 0};
          state->send_result_ = [this, random_id = state->message->random_id,
                                 message_id = MessageId(ServerMessageId(state->message->message_id)),
                                 date = sent->date_, file = *file](Promise<> promise) {
            context_->on_send_message_ok(random_id, message_id, date, make_unique<EncryptedFile>(file),
                                         std::move(promise));
          };
        }
        state->send_result_(std::move(send_message_finish_promise));
        return;
      }
    }
  }
  send_message_finish_promise.set_value(Unit());
}

void SecretChatActor::on_outbound_send_message_error(uint64 state_id, Status error,
                                                     Promise<NetQueryPtr> resend_promise) {
  if (close_flag_) {
    return;
  }
  if (context_->close_flag()) {
    return;
  }
  auto *state = outbound_message_states_.get(state_id);
  if (!state) {
    return;
  }
  bool need_sync = false;
  if (state->net_query_may_fail) {
    // message could be already non-rewritable, if it was deleted during NetQuery execution.
    if (state->message->is_rewritable) {
      delete_message(state->message->random_id, Promise<>());
      // state pointer may be invalidated
      state = outbound_message_states_.get(state_id);
      need_sync = true;
    }
  } else if (error.code() != 429) {
    return on_fatal_error(std::move(error),
                          (error.code() == 400 && error.message() == "ENCRYPTION_DECLINED") || error.code() == 403);
  }
  auto query = create_net_query(*state->message);
  state->net_query_id = query->id();

  CHECK(resend_promise);
  auto send_message_start =
      PromiseCreator::lambda([actor_id = actor_id(this), resend_promise = std::move(resend_promise),
                              query = std::move(query)](Result<> result) mutable {
        if (result.is_ok()) {
          resend_promise.set_value(std::move(query));
        } else {
          send_closure(actor_id, &SecretChatActor::on_promise_error, result.move_as_error(), "resend_query");
        }
      });
  if (need_sync) {
    context_->binlog()->force_sync(std::move(send_message_start), "on_outbound_send_message_error");
  } else {
    send_message_start.set_value(Unit());
  }
}

void SecretChatActor::on_outbound_send_message_finish(uint64 state_id) {
  if (close_flag_) {
    return;
  }
  auto *state = outbound_message_states_.get(state_id);
  if (!state) {
    return;
  }
  LOG(INFO) << "Outbound secret message [send_message] finish " << tag("log_event_id", state->message->log_event_id());
  state->send_message_finish_flag = true;
  state->outer_send_message_finish.set_value(Unit());

  outbound_loop(state, state_id);
}

void SecretChatActor::on_outbound_save_changes_finish(uint64 state_id) {
  if (close_flag_) {
    return;
  }
  auto *state = outbound_message_states_.get(state_id);
  CHECK(state);
  LOG(INFO) << "Outbound secret message [save_changes] finish " << tag("log_event_id", state->message->log_event_id());
  state->save_changes_finish_flag = true;
  outbound_loop(state, state_id);
}

void SecretChatActor::on_outbound_ack(uint64 state_id) {
  if (close_flag_) {
    return;
  }
  auto *state = outbound_message_states_.get(state_id);
  CHECK(state);
  LOG(INFO) << "Outbound secret message [ack] finish " << tag("log_event_id", state->message->log_event_id());
  state->ack_flag = true;
  outbound_loop(state, state_id);
}

void SecretChatActor::on_outbound_outer_send_message_promise(uint64 state_id, Promise<> promise) {
  if (close_flag_) {
    promise.set_error(Status::Error(400, "Chat is closed"));
    return;
  }
  auto *state = outbound_message_states_.get(state_id);
  CHECK(state);
  LOG(INFO) << "Outbound secret message " << tag("log_event_id", state->message->log_event_id());
  promise.set_value(Unit());  // Seems like this message is at least stored to binlog already
  if (state->send_result_) {
    state->send_result_({});
  } else if (state->message->is_sent) {
    context_->on_send_message_error(state->message->random_id, Status::Error(400, "Message has already been sent"),
                                    Auto());
  }
}

void SecretChatActor::outbound_loop(OutboundMessageState *state, uint64 state_id) {
  if (close_flag_) {
    return;
  }
  if (state->save_changes_finish_flag /*&& state->send_message_finish_flag*/ && state->ack_flag) {
    LOG(INFO) << "Outbound message [remove_log_event] start " << tag("log_event_id", state->message->log_event_id());
    binlog_erase(context_->binlog(), state->message->log_event_id());

    random_id_to_outbound_message_state_token_.erase(state->message->random_id);
    LOG(INFO) << "Outbound message finish (lazy) " << tag("log_event_id", state->message->log_event_id());
    outbound_message_states_.erase(state_id);
    return;
  }

  if (state->save_changes_finish_flag && state->send_message_finish_flag &&
      !state->message->is_sent) {  // [rewrite_log_event]
    LOG(INFO) << "Outbound message [rewrite_log_event] start " << tag("log_event_id", state->message->log_event_id());
    state->message->is_sent = true;
    binlog_rewrite(context_->binlog(), state->message->log_event_id(), LogEvent::HandlerType::SecretChats,
                   create_storer(*state->message));
  }
}

template <class T>
Status SecretChatActor::save_common_info(T &update) {
  if (auth_state_.id != update.id_) {
    return Status::Error(PSLICE() << "chat_id mismatch: " << tag("mine", auth_state_.id) << tag("outer", update.id_));
  }
  auth_state_.id = update.id_;
  auth_state_.access_hash = update.access_hash_;
  return Status::OK();
}

Status SecretChatActor::on_update_chat(telegram_api::encryptedChatRequested &update) {
  if (auth_state_.state != State::Empty) {
    LOG(INFO) << "Unexpected encryptedChatRequested ignored: " << to_string(update);
    return Status::OK();
  }
  auth_state_.state = State::SendAccept;
  auth_state_.x = 1;
  auth_state_.user_id = UserId(update.admin_id_);
  auth_state_.date = context_->unix_time();
  TRY_STATUS(save_common_info(update));
  auth_state_.handshake.set_g_a(update.g_a_.as_slice());
  auth_state_.initial_folder_id = FolderId(update.folder_id_);

  send_update_secret_chat();
  return Status::OK();
}
Status SecretChatActor::on_update_chat(telegram_api::encryptedChatEmpty &update) {
  return Status::OK();
}
Status SecretChatActor::on_update_chat(telegram_api::encryptedChatWaiting &update) {
  if (auth_state_.state != State::WaitRequestResponse && auth_state_.state != State::WaitAcceptResponse) {
    LOG(INFO) << "Unexpected encryptedChatWaiting ignored";
    return Status::OK();
  }
  TRY_STATUS(save_common_info(update));
  send_update_secret_chat();
  return Status::OK();
}
Status SecretChatActor::on_update_chat(telegram_api::encryptedChat &update) {
  if (auth_state_.state != State::WaitRequestResponse && auth_state_.state != State::WaitAcceptResponse) {
    LOG(INFO) << "Unexpected encryptedChat ignored";
    return Status::OK();
  }
  TRY_STATUS(save_common_info(update));
  if (auth_state_.state == State::WaitRequestResponse) {
    auth_state_.handshake.set_g_a(update.g_a_or_b_.as_slice());
    TRY_STATUS(auth_state_.handshake.run_checks(true, context_->dh_callback()));
    auto id_and_key = auth_state_.handshake.gen_key();
    pfs_state_.auth_key = mtproto::AuthKey(id_and_key.first, std::move(id_and_key.second));
    calc_key_hash();
  }
  if (static_cast<int64>(pfs_state_.auth_key.id()) != update.key_fingerprint_) {
    return Status::Error("Key fingerprint mismatch");
  }
  auth_state_.state = State::Ready;
  if (create_log_event_id_ != 0) {
    binlog_erase(context_->binlog(), create_log_event_id_);
    create_log_event_id_ = 0;
  }

  // NB: order is important
  context_->secret_chat_db()->set_value(pfs_state_);
  context_->secret_chat_db()->set_value(auth_state_);
  send_update_secret_chat();
  send_action(secret_api::make_object<secret_api::decryptedMessageActionNotifyLayer>(
                  static_cast<int32>(SecretChatLayer::Current)),
              SendFlag::None, Promise<>());
  return Status::OK();
}
Status SecretChatActor::on_update_chat(telegram_api::encryptedChatDiscarded &update) {
  cancel_chat(update.history_deleted_, true, Promise<Unit>());
  return Status::OK();
}

Status SecretChatActor::on_update_chat(NetQueryPtr query) {
  static_assert(std::is_same<telegram_api::messages_requestEncryption::ReturnType,
                             telegram_api::messages_acceptEncryption::ReturnType>::value,
                "");
  TRY_RESULT(config, fetch_result<telegram_api::messages_requestEncryption>(std::move(query)));
  TRY_STATUS(on_update_chat(std::move(config)));
  if (auth_state_.state == State::WaitRequestResponse) {
    context_->secret_chat_db()->set_value(auth_state_);
    context_->binlog()->force_sync(Promise<>(), "on_update_chat");
  }
  return Status::OK();
}

Status SecretChatActor::on_update_chat(telegram_api::object_ptr<telegram_api::EncryptedChat> chat) {
  Status res;
  downcast_call(*chat, [&](auto &obj) { res = this->on_update_chat(obj); });
  return res;
}

Status SecretChatActor::on_read_history(NetQueryPtr query) {
  if (query.generation() == read_history_query_.generation()) {
    read_history_query_ = NetQueryRef();
    read_history_promise_.set_value(Unit());
  }
  return Status::OK();
}

void SecretChatActor::start_up() {
  LOG(INFO) << "SecretChatActor: start_up";
  // auto start = Time::now();
  auto r_auth_state = context_->secret_chat_db()->get_value<AuthState>();
  if (r_auth_state.is_ok()) {
    auth_state_ = r_auth_state.move_as_ok();
  }
  if (!can_be_empty_ && auth_state_.state == State::Empty) {
    LOG(INFO) << "Skip creation of empty secret chat " << auth_state_.id;
    return stop();
  }
  if (auth_state_.state == State::Closed) {
    close_flag_ = true;
  }
  auto r_seq_no_state = context_->secret_chat_db()->get_value<SeqNoState>();
  if (r_seq_no_state.is_ok()) {
    seq_no_state_ = r_seq_no_state.move_as_ok();
  }
  auto r_config_state = context_->secret_chat_db()->get_value<ConfigState>();
  if (r_config_state.is_ok()) {
    config_state_ = r_config_state.move_as_ok();
  }
  auto r_pfs_state = context_->secret_chat_db()->get_value<PfsState>();
  if (r_pfs_state.is_ok()) {
    pfs_state_ = r_pfs_state.move_as_ok();
  }
  saved_pfs_state_message_id_ = pfs_state_.message_id;
  pfs_state_.last_timestamp = Time::now();

  send_update_secret_chat();
  get_dh_config();

  // auto end = Time::now();
  // CHECK(end - start < 0.2);
  LOG(INFO) << "In start_up with SeqNoState " << seq_no_state_;
  LOG(INFO) << "In start_up with PfsState " << pfs_state_;
}

void SecretChatActor::get_dh_config() {
  if (auth_state_.state != State::Empty) {
    return;
  }

  auto dh_config = context_->dh_config();
  if (dh_config) {
    auth_state_.dh_config = *dh_config;
  }

  auto version = auth_state_.dh_config.version;
  int32 random_length = 256;  // ignored server-side, always returns 256 random bytes
  auto query = create_net_query(QueryType::DhConfig, telegram_api::messages_getDhConfig(version, random_length));
  context_->send_net_query(std::move(query), actor_shared(this), false);
}

Status SecretChatActor::on_dh_config(NetQueryPtr query) {
  LOG(INFO) << "Receive DH config";
  TRY_RESULT(config, fetch_result<telegram_api::messages_getDhConfig>(std::move(query)));
  downcast_call(*config, [&](auto &obj) { this->on_dh_config(obj); });
  TRY_STATUS(mtproto::DhHandshake::check_config(auth_state_.dh_config.g, auth_state_.dh_config.prime,
                                                context_->dh_callback()));
  auth_state_.handshake.set_config(auth_state_.dh_config.g, auth_state_.dh_config.prime);
  return Status::OK();
}

void SecretChatActor::on_dh_config(telegram_api::messages_dhConfigNotModified &dh_not_modified) {
  Random::add_seed(dh_not_modified.random_.as_slice());
}

void SecretChatActor::on_dh_config(telegram_api::messages_dhConfig &dh) {
  auto dh_config = std::make_shared<DhConfig>();
  dh_config->version = dh.version_;
  dh_config->prime = dh.p_.as_slice().str();
  dh_config->g = dh.g_;
  Random::add_seed(dh.random_.as_slice());
  auth_state_.dh_config = *dh_config;
  context_->set_dh_config(dh_config);
}

void SecretChatActor::calc_key_hash() {
  unsigned char sha1_buf[20];
  auto sha1_slice = Slice(sha1_buf, 20);
  sha1(pfs_state_.auth_key.key(), sha1_buf);

  unsigned char sha256_buf[32];
  auto sha256_slice = MutableSlice(sha256_buf, 32);
  sha256(pfs_state_.auth_key.key(), sha256_slice);

  auth_state_.key_hash = PSTRING() << sha1_slice.substr(0, 16) << sha256_slice.substr(0, 20);
}

void SecretChatActor::send_update_secret_chat() {
  if (auth_state_.state == State::Empty) {
    return;
  }
  SecretChatState state;
  if (auth_state_.state == State::Ready) {
    state = SecretChatState::Active;
  } else if (auth_state_.state == State::Closed) {
    state = SecretChatState::Closed;
  } else {
    state = SecretChatState::Waiting;
  }
  context_->on_update_secret_chat(auth_state_.access_hash, get_user_id(), state, auth_state_.x == 0, config_state_.ttl,
                                  auth_state_.date, auth_state_.key_hash, current_layer(),
                                  auth_state_.initial_folder_id);
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionSetMessageTTL &set_ttl) {
  config_state_.ttl = set_ttl.ttl_seconds_;
  context_->secret_chat_db()->set_value(config_state_);
  send_update_secret_chat();
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionReadMessages &read_messages) {
  // TODO
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionDeleteMessages &delete_messages) {
  // Corresponding log event won't be deleted before promise returned by add_changes is set.
  on_delete_messages(delete_messages.random_ids_).ensure();
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionScreenshotMessages &screenshot) {
  // nothing to do
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionFlushHistory &flush_history) {
  on_flush_history(pfs_state_.message_id).ensure();
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionResend &resend) {
  if (seq_no_state_.resend_end_seq_no < resend.end_seq_no_ / 2) {  // replay protection
    seq_no_state_.resend_end_seq_no = resend.end_seq_no_ / 2;
    on_seq_no_state_changed();
  }
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionNotifyLayer &notify_layer) {
  config_state_.my_layer = notify_layer.layer_;
  context_->secret_chat_db()->set_value(config_state_);
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionTyping &typing) {
  // noop
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionSetMessageTTL &set_ttl) {
  config_state_.ttl = set_ttl.ttl_seconds_;
  context_->secret_chat_db()->set_value(config_state_);
  send_update_secret_chat();
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionReadMessages &read_messages) {
  // TODO
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionDeleteMessages &delete_messages) {
  return on_delete_messages(delete_messages.random_ids_);
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionScreenshotMessages &screenshot) {
  // TODO
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionFlushHistory &screenshot) {
  return on_flush_history(pfs_state_.message_id);
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionResend &resend) {
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionNotifyLayer &notify_layer) {
  if (notify_layer.layer_ > config_state_.his_layer) {
    config_state_.his_layer = notify_layer.layer_;
    context_->secret_chat_db()->set_value(config_state_);
    send_update_secret_chat();
  }
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionTyping &typing) {
  // noop
  return Status::OK();
}

// Perfect Forward Secrecy
void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionRequestKey &request_key) {
  LOG_CHECK(pfs_state_.state == PfsState::WaitSendRequest || pfs_state_.state == PfsState::SendRequest) << pfs_state_;
  pfs_state_.state = PfsState::WaitRequestResponse;
  on_pfs_state_changed();
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionAcceptKey &accept_key) {
  CHECK(pfs_state_.state == PfsState::WaitSendAccept || pfs_state_.state == PfsState::SendAccept);
  pfs_state_.state = PfsState::WaitAcceptResponse;
  pfs_state_.handshake = mtproto::DhHandshake();
  on_pfs_state_changed();
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionAbortKey &abort_key) {
  // TODO
  LOG(FATAL) << "TODO";
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionCommitKey &commit_key) {
  CHECK(pfs_state_.state == PfsState::WaitSendCommit || pfs_state_.state == PfsState::SendCommit);

  CHECK(static_cast<int64>(pfs_state_.other_auth_key.id()) == commit_key.key_fingerprint_);
  std::swap(pfs_state_.auth_key, pfs_state_.other_auth_key);
  pfs_state_.can_forget_other_key = true;

  pfs_state_.state = PfsState::Empty;
  pfs_state_.last_message_id = pfs_state_.message_id;
  pfs_state_.last_timestamp = Time::now();
  pfs_state_.last_out_seq_no = seq_no_state_.my_out_seq_no;

  on_pfs_state_changed();
}

void SecretChatActor::on_outbound_action(secret_api::decryptedMessageActionNoop &noop) {
  // noop
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionRequestKey &request_key) {
  if (pfs_state_.state == PfsState::WaitRequestResponse || pfs_state_.state == PfsState::SendRequest) {
    if (pfs_state_.exchange_id > request_key.exchange_id_) {
      LOG(INFO) << "RequestKey: silently abort their request";
      return Status::OK();
    } else {
      pfs_state_.state = PfsState::Empty;
      if (pfs_state_.exchange_id == request_key.exchange_id_) {
        context_->secret_chat_db()->set_value(pfs_state_);
        LOG(WARNING) << "RequestKey: silently abort both requests (almost impossible)";
        return Status::OK();
      }
    }
  }

  if (pfs_state_.state != PfsState::Empty) {
    return Status::Error("Unexpected RequestKey");
  }
  if (!pfs_state_.other_auth_key.empty()) {
    LOG_CHECK(pfs_state_.can_forget_other_key) << "TODO: receive requestKey, before old key is dropped";
    return Status::Error("Unexpected RequestKey (old key is used)");
  }
  pfs_state_.state = PfsState::SendAccept;
  pfs_state_.handshake = mtproto::DhHandshake();
  pfs_state_.exchange_id = request_key.exchange_id_;
  pfs_state_.handshake.set_config(auth_state_.dh_config.g, auth_state_.dh_config.prime);
  pfs_state_.handshake.set_g_a(request_key.g_a_.as_slice());
  TRY_STATUS(pfs_state_.handshake.run_checks(true, context_->dh_callback()));
  auto id_and_key = pfs_state_.handshake.gen_key();

  pfs_state_.other_auth_key = mtproto::AuthKey(id_and_key.first, std::move(id_and_key.second));
  pfs_state_.can_forget_other_key = false;
  pfs_state_.wait_message_id = pfs_state_.message_id;

  on_pfs_state_changed();
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionAcceptKey &accept_key) {
  if (pfs_state_.state != PfsState::WaitRequestResponse) {
    return Status::Error("AcceptKey: unexpected");
  }
  if (pfs_state_.exchange_id != accept_key.exchange_id_) {
    return Status::Error("AcceptKey: exchange_id mismatch");
  }
  pfs_state_.handshake.set_g_a(accept_key.g_b_.as_slice());
  TRY_STATUS(pfs_state_.handshake.run_checks(true, context_->dh_callback()));
  auto id_and_key = pfs_state_.handshake.gen_key();
  if (static_cast<int64>(id_and_key.first) != accept_key.key_fingerprint_) {
    return Status::Error("AcceptKey: key_fingerprint mismatch");
  }
  pfs_state_.state = PfsState::SendCommit;
  pfs_state_.handshake = mtproto::DhHandshake();
  CHECK(pfs_state_.can_forget_other_key || static_cast<int64>(pfs_state_.other_auth_key.id()) == id_and_key.first);
  pfs_state_.other_auth_key = mtproto::AuthKey(id_and_key.first, std::move(id_and_key.second));
  pfs_state_.can_forget_other_key = false;
  pfs_state_.wait_message_id = pfs_state_.message_id;

  on_pfs_state_changed();
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionAbortKey &abort_key) {
  if (pfs_state_.exchange_id != abort_key.exchange_id_) {
    LOG(INFO) << "AbortKey: exchange_id mismatch: " << tag("my exchange_id", pfs_state_.exchange_id)
              << to_string(abort_key);
    return Status::OK();
  }
  if (pfs_state_.state != PfsState::WaitRequestResponse) {
    return Status::Error("AbortKey: unexpected");
  }
  pfs_state_.state = PfsState::Empty;
  pfs_state_.handshake = mtproto::DhHandshake();

  on_pfs_state_changed();
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionCommitKey &commit_key) {
  if (pfs_state_.state != PfsState::WaitAcceptResponse) {
    return Status::Error("CommitKey: unexpected");
  }
  if (pfs_state_.exchange_id != commit_key.exchange_id_) {
    return Status::Error("CommitKey: exchange_id mismatch ");
  }

  CHECK(!pfs_state_.can_forget_other_key);
  if (static_cast<int64>(pfs_state_.other_auth_key.id()) != commit_key.key_fingerprint_) {
    return Status::Error("CommitKey: fingerprint mismatch");
  }
  std::swap(pfs_state_.auth_key, pfs_state_.other_auth_key);
  pfs_state_.can_forget_other_key = true;

  pfs_state_.state = PfsState::Empty;
  pfs_state_.last_message_id = pfs_state_.message_id;
  pfs_state_.last_timestamp = Time::now();
  pfs_state_.last_out_seq_no = seq_no_state_.my_out_seq_no;

  on_pfs_state_changed();
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::decryptedMessageActionNoop &noop) {
  // noop
  return Status::OK();
}

Status SecretChatActor::on_inbound_action(secret_api::DecryptedMessageAction &action, int32 message_id) {
  // Action may be not about PFS, but we still can use pfs_state_.message_id
  if (message_id <= pfs_state_.message_id) {  // replay protection
    LOG(INFO) << "Drop old inbound DecryptedMessageAction: " << to_string(action) << tag("message_id", message_id)
              << tag("known_message_id", pfs_state_.message_id);
    return Status::OK();
  }

  // if message_id < seq_no_state_.message_id, then SeqNoState with message_id bigger than current message_id is already saved.
  // And event corresponding to message_id is saved too.
  //
  // Also, if SeqNoState with message_id greater than current message_id is not saved, then corresponding action will be
  // replayed.
  //
  // This works only for TTL, not for PFS. Same TTL action may be processed twice.
  if (message_id < seq_no_state_.message_id) {
    LOG(INFO) << "Drop old inbound DecryptedMessageAction (non-PFS action): " << to_string(action);
    return Status::OK();
  }
  pfs_state_.message_id = message_id;  // replay protection

  LOG(INFO) << "In on_inbound_action: " << to_string(action);
  Status res;
  downcast_call(action, [&](auto &obj) { res = this->on_inbound_action(obj); });
  return res;
}

void SecretChatActor::on_outbound_action(secret_api::DecryptedMessageAction &action, int32 message_id) {
  // Action may be not about PFS, but we still can use pfs_state_.message_id
  if (message_id <= pfs_state_.message_id) {  // replay protection
    LOG(INFO) << "Drop old outbound DecryptedMessageAction: " << to_string(action);
    return;
  }

  // see comment in on_inbound_action
  if (message_id < seq_no_state_.message_id) {
    LOG(INFO) << "Drop old outbound DecryptedMessageAction (non-PFS action): " << to_string(action);
    return;
  }
  pfs_state_.message_id = message_id;  // replay protection

  LOG(INFO) << "In on_outbound_action: " << to_string(action);
  downcast_call(action, [&](auto &obj) { this->on_outbound_action(obj); });
}

void SecretChatActor::request_new_key() {
  CHECK(!auth_state_.dh_config.empty());

  pfs_state_.state = PfsState::SendRequest;
  pfs_state_.handshake = mtproto::DhHandshake();
  pfs_state_.handshake.set_config(auth_state_.dh_config.g, auth_state_.dh_config.prime);
  pfs_state_.exchange_id = Random::secure_int64();

  // NB: must save explicitly
  LOG(INFO) << "SAVE PfsState " << pfs_state_;
  context_->secret_chat_db()->set_value(pfs_state_);
}

void SecretChatActor::on_promise_error(Status error, string desc) {
  if (context_->close_flag()) {
    LOG(DEBUG) << "Ignore " << tag("promise", desc) << error;
    return;
  }
  LOG(FATAL) << "Failed: " << tag("promise", desc) << error;
}

}  // namespace td
