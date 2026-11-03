//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DhConfig.h"
#include "td/telegram/EncryptedFile.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/logevent/SecretChatEvent.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/SecretChatDb.h"
#include "td/telegram/SecretChatId.h"
#include "td/telegram/SecretChatLayer.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/mtproto/AuthKey.h"
#include "td/mtproto/DhCallback.h"
#include "td/mtproto/DhHandshake.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/ChangesProcessor.h"
#include "td/utils/common.h"
#include "td/utils/Container.h"
#include "td/utils/format.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

#include <functional>
#include <map>
#include <memory>
#include <tuple>
#include <utility>

namespace td {

class BinlogInterface;
class NetQueryCreator;

class SecretChatActor final : public NetQueryCallback {
 public:
  class Context {
   public:
    Context() = default;
    Context(const Context &) = delete;
    Context &operator=(const Context &) = delete;
    virtual ~Context() = default;
    virtual mtproto::DhCallback *dh_callback() = 0;
    virtual BinlogInterface *binlog() = 0;
    virtual SecretChatDb *secret_chat_db() = 0;

    virtual NetQueryCreator &net_query_creator() = 0;
    virtual std::shared_ptr<DhConfig> dh_config() = 0;
    virtual void set_dh_config(std::shared_ptr<DhConfig> dh_config) = 0;

    virtual bool get_config_option_boolean(const string &name) const = 0;

    virtual int32 unix_time() = 0;

    virtual bool close_flag() = 0;

    // We don't want to expose the whole NetQueryDispatcher, MessagesManager and UserManager.
    // So it is more clear which parts of MessagesManager are really used. And it is much easier to create tests.
    virtual void send_net_query(NetQueryPtr query, ActorShared<NetQueryCallback> callback, bool ordered) = 0;

    virtual void on_update_secret_chat(int64 access_hash, UserId user_id, SecretChatState state, bool is_outbound,
                                       int32 ttl, int32 date, string key_hash, int32 layer,
                                       FolderId initial_folder_id) = 0;

    // Promise must be set only after the update is processed.
    //
    // For example, one may set promise, after update was sent to binlog. It is ok, because SecretChatsActor will delete
    // this update through binlog too. So it wouldn't be deleted before update is saved.

    // inbound messages
    virtual void on_inbound_message(UserId user_id, MessageId message_id, int32 date, unique_ptr<EncryptedFile> file,
                                    tl_object_ptr<secret_api::decryptedMessage> message, Promise<> promise) = 0;
    virtual void on_delete_messages(std::vector<int64> random_id, Promise<> promise) = 0;
    virtual void on_flush_history(bool remove_from_dialog_list, MessageId message_id, Promise<> promise) = 0;
    virtual void on_read_message(int64 random_id, Promise<> promise) = 0;
    virtual void on_screenshot_taken(UserId user_id, MessageId message_id, int32 date, int64 random_id,
                                     Promise<> promise) = 0;
    virtual void on_set_ttl(UserId user_id, MessageId message_id, int32 date, int32 ttl, int64 random_id,
                            Promise<> promise) = 0;

    // outbound messages
    virtual void on_send_message_ack(int64 random_id) = 0;
    virtual void on_send_message_ok(int64 random_id, MessageId message_id, int32 date, unique_ptr<EncryptedFile> file,
                                    Promise<> promise) = 0;
    virtual void on_send_message_error(int64 random_id, Status error, Promise<> promise) = 0;
  };

  SecretChatActor(int32 id, unique_ptr<Context> context, bool can_be_empty);

  // First query to new chat must be one of these two
  void update_chat(telegram_api::object_ptr<telegram_api::EncryptedChat> chat);
  void create_chat(UserId user_id, int64 user_access_hash, int32 random_id, Promise<SecretChatId> promise);

  void cancel_chat(bool delete_history, bool is_already_discarded, Promise<> promise);

  // Inbound messages
  // Logevent is created by SecretChatsManager, because it must contain QTS
  void add_inbound_message(unique_ptr<log_event::InboundSecretMessage> message);

  // Outbound messages
  // Promise will be set just after corresponding log event is SENT to binlog.
  void send_message(tl_object_ptr<secret_api::DecryptedMessage> message,
                    telegram_api::object_ptr<telegram_api::InputEncryptedFile> file, Promise<> promise);
  void send_message_action(tl_object_ptr<secret_api::SendMessageAction> action);
  void send_read_history(int32 date,
                         Promise<>);  // no binlog event. TODO: Promise will be set after the net query is sent
  void send_open_message(int64 random_id, Promise<>);
  void delete_message(int64 random_id, Promise<> promise);
  void delete_messages(std::vector<int64> random_ids, Promise<> promise);
  void delete_all_messages(Promise<> promise);
  void notify_screenshot_taken(Promise<> promise);
  void send_set_ttl_message(int32 ttl, int64 random_id, Promise<> promise);

  // Binlog replay interface
  void replay_inbound_message(unique_ptr<log_event::InboundSecretMessage> message);
  void replay_outbound_message(unique_ptr<log_event::OutboundSecretMessage> message);
  void replay_close_chat(unique_ptr<log_event::CloseSecretChat> event);
  void replay_create_chat(unique_ptr<log_event::CreateSecretChat> event);
  void binlog_replay_finish();

 private:
  enum class State : int32 { Empty, SendRequest, SendAccept, WaitRequestResponse, WaitAcceptResponse, Ready, Closed };
  static constexpr int32 MAX_RESEND_COUNT = 1000;

  // We have git state that should be synchronized with the database.
  // It is split into several parts because:
  // 1. Some parts are BIG (auth_key, for example) and are rarely updated.
  // 2. Other are frequently updated, so probably should be as small as possible.
  // 3. Some parts must be updated atomically.
  struct SeqNoState {
    int32 message_id = 0;
    int32 my_in_seq_no = 0;
    int32 my_out_seq_no = 0;
    int32 his_in_seq_no = 0;
    int32 his_layer = 0;

    int32 resend_end_seq_no = -1;

    static Slice key() {
      return Slice("state");
    }
    template <class StorerT>
    void store(StorerT &storer) const {
      storer.store_int(message_id | HAS_LAYER);
      storer.store_int(my_in_seq_no);
      storer.store_int(my_out_seq_no);
      storer.store_int(his_in_seq_no);
      storer.store_int(resend_end_seq_no);
      storer.store_int(his_layer);
    }

    template <class ParserT>
    void parse(ParserT &parser) {
      message_id = parser.fetch_int();
      my_in_seq_no = parser.fetch_int();
      my_out_seq_no = parser.fetch_int();
      his_in_seq_no = parser.fetch_int();
      resend_end_seq_no = parser.fetch_int();

      bool has_layer = (message_id & HAS_LAYER) != 0;
      if (has_layer) {
        message_id &= static_cast<int32>(~HAS_LAYER);
        his_layer = parser.fetch_int();
      }
    }
    static constexpr uint32 HAS_LAYER = 1u << 31;
  };

  struct ConfigState {
    int32 his_layer = 8;
    int32 my_layer = 8;
    int32 ttl = 0;

    static Slice key() {
      return Slice("config");
    }
    template <class StorerT>
    void store(StorerT &storer) const {
      storer.store_int(his_layer | HAS_FLAGS);
      storer.store_int(ttl);
      storer.store_int(my_layer);
      //for future usage
      BEGIN_STORE_FLAGS();
      END_STORE_FLAGS();
    }

    template <class ParserT>
    void parse(ParserT &parser) {
      his_layer = parser.fetch_int();
      ttl = parser.fetch_int();
      bool has_flags = (his_layer & HAS_FLAGS) != 0;
      if (has_flags) {
        his_layer &= static_cast<int32>(~HAS_FLAGS);
        my_layer = parser.fetch_int();
        // for future usage
        BEGIN_PARSE_FLAGS();
        END_PARSE_FLAGS();
      }
    }

    static constexpr uint32 HAS_FLAGS = 1u << 31;
  };

  // PfsAction
  struct PfsState {
    enum State : int32 {
      Empty,
      WaitSendRequest,
      SendRequest,
      WaitRequestResponse,
      WaitSendAccept,
      SendAccept,
      WaitAcceptResponse,
      WaitSendCommit,
      SendCommit
    } state = Empty;

    enum Flags : int32 { CanForgetOtherKey = 1 };
    mtproto::AuthKey auth_key;
    mtproto::AuthKey other_auth_key;
    bool can_forget_other_key = true;

    int32 message_id = 0;  // to skip old actions
    int32 wait_message_id = 0;
    int64 exchange_id = 0;
    int32 last_message_id = 0;
    double last_timestamp = 0;
    int32 last_out_seq_no = 0;
    mtproto::DhHandshake handshake;

    static Slice key() {
      return Slice("pfs_state");
    }

    template <class StorerT>
    void store(StorerT &storer) const {
      int32 flags = 0;
      if (can_forget_other_key) {
        flags |= CanForgetOtherKey;
      }
      storer.store_int(flags);
      storer.store_int(state);
      auth_key.store(storer);
      other_auth_key.store(storer);
      storer.store_int(message_id);
      storer.store_long(exchange_id);
      storer.store_int(last_message_id);
      storer.store_long(static_cast<int64>((last_timestamp - Time::now() + Clocks::system()) * 1000000));
      storer.store_int(last_out_seq_no);
      handshake.store(storer);
    }
    template <class ParserT>
    void parse(ParserT &parser) {
      int32 flags = parser.fetch_int();
      can_forget_other_key = (flags & CanForgetOtherKey) != 0;
      state = static_cast<State>(parser.fetch_int());
      auth_key.parse(parser);
      other_auth_key.parse(parser);
      message_id = parser.fetch_int();
      exchange_id = parser.fetch_long();
      last_message_id = parser.fetch_int();
      last_timestamp = static_cast<double>(parser.fetch_long()) / 1000000 - Clocks::system() + Time::now();
      if (last_timestamp > Time::now_cached()) {
        last_timestamp = Time::now_cached();
      }
      last_out_seq_no = parser.fetch_int();
      handshake.parse(parser);
    }
  };
  friend StringBuilder &operator<<(StringBuilder &sb, const PfsState &state) {
    return sb << "PfsState["
              << tag("state",
                     [&] {
                       switch (state.state) {
                         case PfsState::Empty:
                           return "Empty";
                         case PfsState::WaitSendRequest:
                           return "WaitSendRequest";
                         case PfsState::SendRequest:
                           return "SendRequest";
                         case PfsState::WaitRequestResponse:
                           return "WaitRequestResponse";
                         case PfsState::WaitSendAccept:
                           return "WaitSendAccept";
                         case PfsState::SendAccept:
                           return "SendAccept";
                         case PfsState::WaitAcceptResponse:
                           return "WaitAcceptResponse";
                         case PfsState::WaitSendCommit:
                           return "WaitSendCommit";
                         case PfsState::SendCommit:
                           return "SendCommit";
                       }
                       return "UNKNOWN";
                     }())
              << tag("message_id", state.message_id) << tag("auth_key", format::as_hex(state.auth_key.id()))
              << tag("last_message_id", state.last_message_id)
              << tag("other_auth_key", format::as_hex(state.other_auth_key.id()))
              << tag("can_forget", state.can_forget_other_key) << "]";
  }

  PfsState pfs_state_;
  bool pfs_state_changed_ = false;

  void on_outbound_action(secret_api::decryptedMessageActionSetMessageTTL &set_ttl);
  void on_outbound_action(secret_api::decryptedMessageActionReadMessages &read_messages);
  void on_outbound_action(secret_api::decryptedMessageActionDeleteMessages &delete_messages);
  void on_outbound_action(secret_api::decryptedMessageActionScreenshotMessages &screenshot);
  void on_outbound_action(secret_api::decryptedMessageActionFlushHistory &flush_history);
  void on_outbound_action(secret_api::decryptedMessageActionResend &resend);
  void on_outbound_action(secret_api::decryptedMessageActionNotifyLayer &notify_layer);
  void on_outbound_action(secret_api::decryptedMessageActionTyping &typing);

  Status on_inbound_action(secret_api::decryptedMessageActionSetMessageTTL &set_ttl);
  Status on_inbound_action(secret_api::decryptedMessageActionReadMessages &read_messages);
  Status on_inbound_action(secret_api::decryptedMessageActionDeleteMessages &delete_messages);
  Status on_inbound_action(secret_api::decryptedMessageActionScreenshotMessages &screenshot);
  Status on_inbound_action(secret_api::decryptedMessageActionFlushHistory &screenshot);

  Status on_inbound_action(secret_api::decryptedMessageActionResend &resend);
  Status on_inbound_action(secret_api::decryptedMessageActionNotifyLayer &notify_layer);
  Status on_inbound_action(secret_api::decryptedMessageActionTyping &typing);

  // Perfect Forward Secrecy
  void on_outbound_action(secret_api::decryptedMessageActionRequestKey &request_key);
  void on_outbound_action(secret_api::decryptedMessageActionAcceptKey &accept_key);
  void on_outbound_action(secret_api::decryptedMessageActionAbortKey &abort_key);
  void on_outbound_action(secret_api::decryptedMessageActionCommitKey &commit_key);
  void on_outbound_action(secret_api::decryptedMessageActionNoop &noop);

  Status on_inbound_action(secret_api::decryptedMessageActionRequestKey &request_key);
  Status on_inbound_action(secret_api::decryptedMessageActionAcceptKey &accept_key);
  Status on_inbound_action(secret_api::decryptedMessageActionAbortKey &abort_key);
  Status on_inbound_action(secret_api::decryptedMessageActionCommitKey &commit_key);
  Status on_inbound_action(secret_api::decryptedMessageActionNoop &noop);

  Status on_inbound_action(secret_api::DecryptedMessageAction &action, int32 message_id);

  void on_outbound_action(secret_api::DecryptedMessageAction &action, int32 message_id);

  void request_new_key();

  struct AuthState {
    State state = State::Empty;
    int x = -1;
    string key_hash;

    int32 id = 0;
    int64 access_hash = 0;

    UserId user_id;
    int64 user_access_hash = 0;
    int32 random_id = 0;

    int32 date = 0;

    FolderId initial_folder_id;

    DhConfig dh_config;
    mtproto::DhHandshake handshake;

    static Slice key() {
      return Slice("auth_state");
    }
    template <class StorerT>
    void store(StorerT &storer) const {
      uint32 flags = 8;
      bool has_date = date != 0;
      bool has_key_hash = true;
      bool has_initial_folder_id = initial_folder_id != FolderId();
      if (has_date) {
        flags |= 1;
      }
      if (has_key_hash) {
        flags |= 2;
      }
      if (has_initial_folder_id) {
        flags |= 4;
      }
      storer.store_int((flags << 8) | static_cast<int32>(state));
      storer.store_int(x);

      storer.store_int(id);
      storer.store_long(access_hash);
      storer.store_long(user_id.get());
      storer.store_long(user_access_hash);
      storer.store_int(random_id);
      if (has_date) {
        storer.store_int(date);
      }
      if (has_key_hash) {
        storer.store_string(key_hash);
      }
      dh_config.store(storer);
      if (state == State::SendRequest || state == State::WaitRequestResponse) {
        handshake.store(storer);
      }
      if (has_initial_folder_id) {
        initial_folder_id.store(storer);
      }
    }

    template <class ParserT>
    void parse(ParserT &parser) {
      uint32 tmp = parser.fetch_int();
      state = static_cast<State>(tmp & 255);
      uint32 flags = tmp >> 8;
      bool has_date = (flags & 1) != 0;
      bool has_key_hash = (flags & 2) != 0;
      bool has_initial_folder_id = (flags & 4) != 0;
      bool has_64bit_user_id = (flags & 8) != 0;

      x = parser.fetch_int();

      id = parser.fetch_int();
      access_hash = parser.fetch_long();
      if (has_64bit_user_id) {
        user_id = UserId(parser.fetch_long());
      } else {
        user_id = UserId(static_cast<int64>(parser.fetch_int()));
      }
      user_access_hash = parser.fetch_long();
      random_id = parser.fetch_int();
      if (has_date) {
        date = parser.fetch_int();
      }
      if (has_key_hash) {
        key_hash = parser.template fetch_string<std::string>();
      }
      dh_config.parse(parser);
      if (state == State::SendRequest || state == State::WaitRequestResponse) {
        handshake.parse(parser);
      }
      if (has_initial_folder_id) {
        initial_folder_id.parse(parser);
      }
    }
  };

  std::shared_ptr<SecretChatDb> db_;
  unique_ptr<Context> context_;

  bool binlog_replay_finish_flag_ = false;
  bool close_flag_ = false;
  Promise<Unit> discard_encryption_promise_;

  LogEvent::Id create_log_event_id_ = 0;

  enum class QueryType : uint8 { DhConfig, EncryptedChat, Message, Ignore, DiscardEncryption, ReadHistory };

  bool can_be_empty_;
  AuthState auth_state_;
  ConfigState config_state_;

  // Turns out, that all changes should be made through StateChange.
  //
  // The problem is the time between the moment we made decision about change and
  // the moment we actually apply the change to memory.
  // We may accept some other change during that time, and there goes our problem
  // The reason for the change may already be invalid. So we should somehow recheck change, that
  // is already written to binlog, and apply it only if necessary.
  // This is completely flawed.
  // (A-start_save_to_binlog ----> B-start_save_to_binlog+change_memory ----> A-finish_save_to_binlog+surprise)
  //
  // Instead, I suggest general solution that is already used with SeqNoState and QTS
  // 1. We APPLY CHANGE to memory immediately AFTER corresponding EVENT is SENT to the binlog.
  // 2. We SEND CHANGE to database only after corresponding EVENT is SAVED to the binlog.
  // 3. Then, we are able to ERASE EVENT just AFTER the CHANGE is SAVED to the binlog.
  //
  // Actually the change will be saved to binlog too.
  // So we can do it immediately after EVENT is SENT to the binlog, because SEND CHANGE and ERASE EVENT will be
  // ordered automatically.
  //
  // We will use common ChangesProcessor for all changes (inside one SecretChatActor).
  // So all changes will be saved in exactly the same order as they are applied.

  template <class StateT>
  class Change {
   public:
    Change() : message_id() {
    }
    explicit operator bool() const noexcept {
      return !data.empty();
    }
    explicit Change(const StateT &state) {
      data = serialize(state);
      message_id = state.message_id;
    }
    template <class StorerT>
    void store(StorerT &storer) const {
      // NB: rely that storer will the same as in serialize
      storer.store_slice(data);
    }
    static Slice key() {
      return StateT::key();
    }

    friend StringBuilder &operator<<(StringBuilder &sb, const Change<StateT> &change) {
      if (change) {
        StateT state;
        unserialize(state, change.data).ensure();
        return sb << state;
      }
      return sb;
    }

    int32 message_id;

   private:
    std::string data;
  };

  // SeqNoState
  using SeqNoStateChange = Change<SeqNoState>;
  using PfsStateChange = Change<PfsState>;
  struct StateChange {
    // TODO(perf): Less allocations, please? May be BufferSlice instead of std::string?
    SeqNoStateChange seq_no_state_change;
    PfsStateChange pfs_state_change;
    Promise<Unit> save_changes_finish;
  };

  ChangesProcessor<StateChange> changes_processor_;
  int32 saved_pfs_state_message_id_ = 0;

  SeqNoState seq_no_state_;
  bool seq_no_state_changed_ = false;
  int32 last_binlog_message_id_ = -1;

  Status check_seq_no(int in_seq_no, int out_seq_no, int32 his_layer) TD_WARN_UNUSED_RESULT;
  void on_his_in_seq_no_updated();

  void on_seq_no_state_changed();
  template <class T>
  void update_seq_no_state(const T &new_seq_no_state);
  void on_pfs_state_changed();
  Promise<> add_changes(Promise<> save_changes_finish = Promise<>());
  // called only via Promise
  void on_save_changes_start(ChangesProcessor<StateChange>::Id save_changes_token);

  // InboundMessage
  struct InboundMessageState {
    bool save_changes_finish = false;
    bool save_message_finish = false;
    LogEvent::Id log_event_id = 0;
    int32 message_id = 0;
  };
  Container<InboundMessageState> inbound_message_states_;

  std::map<int32, unique_ptr<log_event::InboundSecretMessage>> pending_inbound_messages_;

  Result<std::tuple<uint64, BufferSlice, int32>> decrypt(BufferSlice &encrypted_message);

  Status do_inbound_message_encrypted(unique_ptr<log_event::InboundSecretMessage> message);
  Status do_inbound_message_decrypted_unchecked(unique_ptr<log_event::InboundSecretMessage> message,
                                                int32 mtproto_version);
  Status do_inbound_message_decrypted(unique_ptr<log_event::InboundSecretMessage> message);
  void do_inbound_message_decrypted_pending(unique_ptr<log_event::InboundSecretMessage> message);

  void on_inbound_save_message_finish(uint64 state_id);
  void on_inbound_save_changes_finish(uint64 state_id);
  void inbound_loop(InboundMessageState *state, uint64 state_id);

  // OutboundMessage
  struct OutboundMessageState {
    unique_ptr<log_event::OutboundSecretMessage> message;

    Promise<> outer_send_message_finish;
    Promise<> send_message_finish;

    bool save_changes_finish_flag = false;
    bool send_message_finish_flag = false;
    bool ack_flag = false;

    uint64 net_query_id = 0;
    NetQueryRef net_query_ref;
    bool net_query_may_fail = false;

    std::function<void(Promise<>)> send_result_;
  };
  std::map<uint64, uint64> random_id_to_outbound_message_state_token_;
  std::map<int32, uint64> out_seq_no_to_outbound_message_state_token_;

  Container<OutboundMessageState> outbound_message_states_;

  NetQueryRef set_typing_query_;
  NetQueryRef read_history_query_;
  int32 last_read_history_date_ = -1;
  Promise<Unit> read_history_promise_;

  template <class T>
  NetQueryPtr create_net_query(QueryType type, const T &function);

  enum SendFlag : int32 {
    None = 0,
    External = 1,
    Push = 2,
  };
  void send_action(tl_object_ptr<secret_api::DecryptedMessageAction> action, int32 flags, Promise<> promise);

  void send_message_impl(tl_object_ptr<secret_api::DecryptedMessage> message,
                         telegram_api::object_ptr<telegram_api::InputEncryptedFile> file, int32 flags,
                         Promise<> promise);

  void do_outbound_message_impl(unique_ptr<log_event::OutboundSecretMessage>, Promise<> promise);

  Result<BufferSlice> create_encrypted_message(int32 my_in_seq_no, int32 my_out_seq_no,
                                               tl_object_ptr<secret_api::DecryptedMessage> &message);

  NetQueryPtr create_net_query(const log_event::OutboundSecretMessage &message);

  void outbound_resend(uint64 state_id);
  Status outbound_rewrite_with_empty(uint64 state_id);
  void on_outbound_send_message_start(uint64 state_id);
  void on_outbound_send_message_result(NetQueryPtr query, Promise<NetQueryPtr> resend_promise);
  void on_outbound_send_message_error(uint64 state_id, Status error, Promise<NetQueryPtr> resend_promise);
  void on_outbound_send_message_finish(uint64 state_id);
  void on_outbound_save_changes_finish(uint64 state_id);
  void on_outbound_ack(uint64 state_id);
  void on_outbound_outer_send_message_promise(uint64 state_id, Promise<> promise);
  void outbound_loop(OutboundMessageState *state, uint64 state_id);

  // DiscardEncryption
  void on_fatal_error(Status status, bool is_expected);
  void do_close_chat_impl(bool delete_history, bool is_already_discarded, uint64 log_event_id, Promise<Unit> &&promise);
  void on_closed(uint64 log_event_id, Promise<Unit> &&promise);

  // Other
  template <class T>
  Status save_common_info(T &update);

  int32 current_layer() const {
    auto layer = static_cast<int32>(SecretChatLayer::Current);
    if (config_state_.his_layer < layer) {
      layer = config_state_.his_layer;
    }
    if (layer < static_cast<int32>(SecretChatLayer::Default)) {
      layer = static_cast<int32>(SecretChatLayer::Default);
    }
    return layer;
  }

  void ask_on_binlog_replay_finish();

  void check_status(Status status);
  void start_up() final;
  void loop() final;
  Status do_loop();
  void tear_down() final;

  void on_result_resendable(NetQueryPtr net_query, Promise<NetQueryPtr> promise) final;

  Status run_auth();
  void run_pfs();
  void run_fill_gaps();
  void on_send_message_ack(int64 random_id);
  Status on_delete_messages(const vector<int64> &random_ids);
  Status on_flush_history(int32 last_message_id);

  telegram_api::object_ptr<telegram_api::inputUser> get_input_user();
  telegram_api::object_ptr<telegram_api::inputEncryptedChat> get_input_chat();

  Status on_update_chat(telegram_api::encryptedChatRequested &update) TD_WARN_UNUSED_RESULT;
  Status on_update_chat(telegram_api::encryptedChatEmpty &update) TD_WARN_UNUSED_RESULT;
  Status on_update_chat(telegram_api::encryptedChatWaiting &update) TD_WARN_UNUSED_RESULT;
  Status on_update_chat(telegram_api::encryptedChat &update) TD_WARN_UNUSED_RESULT;
  Status on_update_chat(telegram_api::encryptedChatDiscarded &update) TD_WARN_UNUSED_RESULT;

  Status on_update_chat(NetQueryPtr query) TD_WARN_UNUSED_RESULT;
  Status on_update_chat(telegram_api::object_ptr<telegram_api::EncryptedChat> chat) TD_WARN_UNUSED_RESULT;

  Status on_read_history(NetQueryPtr query) TD_WARN_UNUSED_RESULT;

  void on_promise_error(Status error, string desc);

  void get_dh_config();
  Status on_dh_config(NetQueryPtr query) TD_WARN_UNUSED_RESULT;
  void on_dh_config(telegram_api::messages_dhConfigNotModified &dh_not_modified);
  void on_dh_config(telegram_api::messages_dhConfig &dh);

  void do_create_chat_impl(unique_ptr<log_event::CreateSecretChat> event);

  SecretChatId get_secret_chat_id() {
    return SecretChatId(auth_state_.id);
  }
  UserId get_user_id() {
    return auth_state_.user_id;
  }
  void send_update_ttl(int32 ttl);
  void send_update_secret_chat();
  void calc_key_hash();

  friend inline StringBuilder &operator<<(StringBuilder &sb, const SecretChatActor::SeqNoState &state) {
    return sb << "[" << tag("my_in_seq_no", state.my_in_seq_no) << tag("my_out_seq_no", state.my_out_seq_no)
              << tag("his_in_seq_no", state.his_in_seq_no) << "]";
  }
};

}  // namespace td
