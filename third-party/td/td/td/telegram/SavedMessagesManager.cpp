//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SavedMessagesManager.h"

#include "td/telegram/AffectedHistory.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageQueryManager.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"

#include <algorithm>

namespace td {

class GetPinnedSavedDialogsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  int32 limit_;

 public:
  explicit GetPinnedSavedDialogsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int32 limit) {
    limit_ = limit;
    send_query(G()->net_query_creator().create(telegram_api::messages_getPinnedSavedDialogs()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getPinnedSavedDialogs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPinnedSavedDialogsQuery: " << to_string(result);
    td_->saved_messages_manager_->on_get_saved_messages_topics(true, limit_, std::move(result), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetSavedDialogsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  int32 limit_;

 public:
  explicit GetSavedDialogsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(int32 offset_date, MessageId offset_message_id, DialogId offset_dialog_id, int32 limit) {
    limit_ = limit;
    auto input_peer = DialogManager::get_input_peer_force(offset_dialog_id);
    CHECK(input_peer != nullptr);

    int32 flags = telegram_api::messages_getSavedDialogs::EXCLUDE_PINNED_MASK;
    send_query(G()->net_query_creator().create(telegram_api::messages_getSavedDialogs(
        flags, false /*ignored*/, offset_date, offset_message_id.get_server_message_id().get(), std::move(input_peer),
        limit, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getSavedDialogs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetSavedDialogsQuery: " << to_string(result);
    td_->saved_messages_manager_->on_get_saved_messages_topics(false, limit_, std::move(result), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetSavedHistoryQuery final : public Td::ResultHandler {
  Promise<MessagesInfo> promise_;

 public:
  explicit GetSavedHistoryQuery(Promise<MessagesInfo> &&promise) : promise_(std::move(promise)) {
  }

  void send(SavedMessagesTopicId saved_messages_topic_id, MessageId from_message_id, int32 offset, int32 limit) {
    auto saved_input_peer = saved_messages_topic_id.get_input_peer(td_);
    CHECK(saved_input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::messages_getSavedHistory(
        std::move(saved_input_peer), from_message_id.get_server_message_id().get(), 0, offset, limit, 0, 0, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getSavedHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto my_dialog_id = td_->dialog_manager_->get_my_dialog_id();
    auto info = get_messages_info(td_, my_dialog_id, result_ptr.move_as_ok(), "GetSavedHistoryQuery");
    LOG_IF(ERROR, info.is_channel_messages) << "Receive channel messages in GetSavedHistoryQuery";
    promise_.set_value(std::move(info));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetSavedMessageByDateQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::message>> promise_;
  int32 date_ = 0;

 public:
  explicit GetSavedMessageByDateQuery(Promise<td_api::object_ptr<td_api::message>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(SavedMessagesTopicId saved_messages_topic_id, int32 date) {
    date_ = date;
    auto saved_input_peer = saved_messages_topic_id.get_input_peer(td_);
    CHECK(saved_input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::messages_getSavedHistory(std::move(saved_input_peer), 0, date, -3, 5, 0, 0, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getSavedHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto my_dialog_id = td_->dialog_manager_->get_my_dialog_id();
    auto info = get_messages_info(td_, my_dialog_id, result_ptr.move_as_ok(), "GetSavedMessageByDateQuery");
    LOG_IF(ERROR, info.is_channel_messages) << "Receive channel messages in GetSavedMessageByDateQuery";
    for (auto &message : info.messages) {
      auto message_date = MessagesManager::get_message_date(message);
      auto message_dialog_id = DialogId::get_message_dialog_id(message);
      if (message_dialog_id != my_dialog_id) {
        LOG(ERROR) << "Receive message in wrong " << message_dialog_id << " instead of " << my_dialog_id;
        continue;
      }
      if (message_date != 0 && message_date <= date_) {
        auto message_full_id = td_->messages_manager_->on_get_message(std::move(message), false, false, false,
                                                                      "GetSavedMessageByDateQuery");
        if (message_full_id != MessageFullId()) {
          return promise_.set_value(
              td_->messages_manager_->get_message_object(message_full_id, "GetSavedMessageByDateQuery"));
        }
      }
    }
    promise_.set_value(nullptr);
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteSavedHistoryQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;

 public:
  explicit DeleteSavedHistoryQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(SavedMessagesTopicId saved_messages_topic_id) {
    auto saved_input_peer = saved_messages_topic_id.get_input_peer(td_);
    CHECK(saved_input_peer != nullptr);

    int32 flags = 0;
    send_query(G()->net_query_creator().create(telegram_api::messages_deleteSavedHistory(
        flags, std::move(saved_input_peer), std::numeric_limits<int32>::max(), 0, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteSavedHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteSavedMessagesByDateQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;

 public:
  explicit DeleteSavedMessagesByDateQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(SavedMessagesTopicId saved_messages_topic_id, int32 min_date, int32 max_date) {
    auto saved_input_peer = saved_messages_topic_id.get_input_peer(td_);
    CHECK(saved_input_peer != nullptr);

    int32 flags =
        telegram_api::messages_deleteHistory::MIN_DATE_MASK | telegram_api::messages_deleteHistory::MAX_DATE_MASK;

    send_query(G()->net_query_creator().create(
        telegram_api::messages_deleteSavedHistory(flags, std::move(saved_input_peer), 0, min_date, max_date)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteSavedHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ToggleSavedDialogPinQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ToggleSavedDialogPinQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(SavedMessagesTopicId saved_messages_topic_id, bool is_pinned) {
    auto saved_input_peer = saved_messages_topic_id.get_input_dialog_peer(td_);
    CHECK(saved_input_peer != nullptr);

    int32 flags = 0;
    if (is_pinned) {
      flags |= telegram_api::messages_toggleSavedDialogPin::PINNED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_toggleSavedDialogPin(flags, false /*ignored*/, std::move(saved_input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_toggleSavedDialogPin>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->saved_messages_manager_->reload_pinned_saved_messages_topics();
    promise_.set_error(std::move(status));
  }
};

class ReorderPinnedSavedDialogsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ReorderPinnedSavedDialogsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const vector<SavedMessagesTopicId> &saved_messages_topic_ids) {
    auto order = transform(saved_messages_topic_ids, [td = td_](SavedMessagesTopicId saved_messages_topic_id) {
      auto saved_input_peer = saved_messages_topic_id.get_input_dialog_peer(td);
      CHECK(saved_input_peer != nullptr);
      return saved_input_peer;
    });
    int32 flags = telegram_api::messages_reorderPinnedSavedDialogs::FORCE_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_reorderPinnedSavedDialogs(flags, true /*ignored*/, std::move(order))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reorderPinnedSavedDialogs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    if (!result) {
      return on_error(Status::Error(400, "Result is false"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->saved_messages_manager_->reload_pinned_saved_messages_topics();
    promise_.set_error(std::move(status));
  }
};

SavedMessagesManager::SavedMessagesManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void SavedMessagesManager::tear_down() {
  parent_.reset();
}

SavedMessagesTopicId SavedMessagesManager::get_topic_id(int64 topic_id) const {
  if (topic_id == 0) {
    return SavedMessagesTopicId();
  }
  auto saved_messages_topic_id = SavedMessagesTopicId(DialogId(topic_id));
  if (saved_messages_topics_.count(saved_messages_topic_id) == 0) {
    return SavedMessagesTopicId(DialogId(std::numeric_limits<int64>::max()));  // an invalid topic identifier
  }
  return saved_messages_topic_id;
}

vector<SavedMessagesTopicId> SavedMessagesManager::get_topic_ids(const vector<int64> &topic_ids) const {
  return transform(topic_ids, [this](int64 topic_id) { return get_topic_id(topic_id); });
}

int64 SavedMessagesManager::get_saved_messages_topic_id_object(SavedMessagesTopicId saved_messages_topic_id) {
  if (saved_messages_topic_id == SavedMessagesTopicId()) {
    return 0;
  }

  add_topic(saved_messages_topic_id);

  return saved_messages_topic_id.get_unique_id();
}

SavedMessagesManager::SavedMessagesTopic *SavedMessagesManager::get_topic(
    SavedMessagesTopicId saved_messages_topic_id) {
  CHECK(saved_messages_topic_id.is_valid());
  auto it = saved_messages_topics_.find(saved_messages_topic_id);
  if (it == saved_messages_topics_.end()) {
    return nullptr;
  }
  return it->second.get();
}

SavedMessagesManager::SavedMessagesTopic *SavedMessagesManager::add_topic(
    SavedMessagesTopicId saved_messages_topic_id) {
  CHECK(saved_messages_topic_id.is_valid());
  auto &result = saved_messages_topics_[saved_messages_topic_id];
  if (result == nullptr) {
    result = make_unique<SavedMessagesTopic>();
    result->saved_messages_topic_id_ = saved_messages_topic_id;
    if (saved_messages_topic_id == SavedMessagesTopicId(td_->dialog_manager_->get_my_dialog_id())) {
      auto draft_message_object = td_->messages_manager_->get_my_dialog_draft_message_object();
      if (draft_message_object != nullptr) {
        result->draft_message_date_ = draft_message_object->date_;
      }
    }
    send_update_saved_messages_topic(result.get(), "add_topic");
  }
  return result.get();
}

void SavedMessagesManager::set_topic_last_message_id(SavedMessagesTopicId saved_messages_topic_id,
                                                     MessageId last_message_id, int32 last_message_date) {
  auto *topic = add_topic(saved_messages_topic_id);
  do_set_topic_last_message_id(topic, last_message_id, last_message_date);
  on_topic_changed(topic, "set_topic_last_message_id");
}

void SavedMessagesManager::do_set_topic_last_message_id(SavedMessagesTopic *topic, MessageId last_message_id,
                                                        int32 last_message_date) {
  if (topic->last_message_id_ == last_message_id) {
    return;
  }

  CHECK(last_message_id == MessageId() || last_message_id.is_valid());
  LOG(INFO) << "Set last message in " << topic->saved_messages_topic_id_ << " to " << last_message_id;
  topic->last_message_id_ = last_message_id;
  topic->last_message_date_ = last_message_date;
  topic->is_changed_ = true;
}

void SavedMessagesManager::on_topic_message_updated(SavedMessagesTopicId saved_messages_topic_id,
                                                    MessageId message_id) {
  auto *topic = get_topic(saved_messages_topic_id);
  if (topic == nullptr || topic->last_message_id_ != message_id) {
    return;
  }

  send_update_saved_messages_topic(topic, "on_topic_message_updated");
}

void SavedMessagesManager::on_topic_message_deleted(SavedMessagesTopicId saved_messages_topic_id,
                                                    MessageId message_id) {
  auto *topic = get_topic(saved_messages_topic_id);
  if (topic == nullptr || topic->last_message_id_ != message_id) {
    return;
  }

  do_set_topic_last_message_id(topic, MessageId(), 0);

  on_topic_changed(topic, "on_topic_message_deleted");

  get_saved_messages_topic_history(saved_messages_topic_id, MessageId(), 0, 1, Auto());
}

void SavedMessagesManager::on_topic_draft_message_updated(SavedMessagesTopicId saved_messages_topic_id,
                                                          int32 draft_message_date) {
  auto *topic = get_topic(saved_messages_topic_id);
  if (topic == nullptr) {
    LOG(INFO) << "Updated draft in unknown " << saved_messages_topic_id;
    return;
  }

  LOG(INFO) << "Set draft message date in " << topic->saved_messages_topic_id_ << " to " << draft_message_date;
  topic->draft_message_date_ = draft_message_date;
  topic->is_changed_ = true;

  on_topic_changed(topic, "on_topic_draft_message_updated");
}

int64 SavedMessagesManager::get_topic_order(int32 message_date, MessageId message_id) {
  return (static_cast<int64>(message_date) << 31) +
         message_id.get_prev_server_message_id().get_server_message_id().get();
}

int64 SavedMessagesManager::get_topic_public_order(const SavedMessagesTopic *topic) const {
  if (TopicDate(topic->private_order_, topic->saved_messages_topic_id_) <= topic_list_.last_topic_date_) {
    return topic->private_order_;
  }
  return 0;
}

void SavedMessagesManager::on_topic_changed(SavedMessagesTopic *topic, const char *source) {
  CHECK(topic != nullptr);
  if (!topic->is_changed_) {
    return;
  }
  topic->is_changed_ = false;

  int64 new_private_order;
  if (topic->pinned_order_ != 0) {
    new_private_order = topic->pinned_order_;
  } else if (topic->last_message_id_ != MessageId()) {
    new_private_order = get_topic_order(topic->last_message_date_, topic->last_message_id_);
  } else {
    new_private_order = 0;
  }
  if (topic->draft_message_date_ != 0) {
    int64 draft_order = get_topic_order(topic->draft_message_date_, MessageId());
    if (new_private_order < draft_order) {
      new_private_order = draft_order;
    }
  }
  if (topic->private_order_ != new_private_order) {
    if (topic->private_order_ != 0) {
      bool is_deleted = topic_list_.ordered_topics_.erase({topic->private_order_, topic->saved_messages_topic_id_}) > 0;
      CHECK(is_deleted);
      if (topic_list_.server_total_count_ > 0) {
        topic_list_.server_total_count_--;
      }
    }
    topic->private_order_ = new_private_order;
    if (topic->private_order_ != 0) {
      bool is_inserted =
          topic_list_.ordered_topics_.insert({topic->private_order_, topic->saved_messages_topic_id_}).second;
      CHECK(is_inserted);
      if (topic_list_.server_total_count_ >= 0) {
        topic_list_.server_total_count_++;
      }
    }
  }
  LOG(INFO) << "Update order of " << topic->saved_messages_topic_id_ << " to " << topic->private_order_ << " from "
            << source;

  send_update_saved_messages_topic(topic, source);

  update_saved_messages_topic_sent_total_count(source);
}

void SavedMessagesManager::load_saved_messages_topics(int32 limit, Promise<Unit> &&promise) {
  if (limit < 0) {
    return promise.set_error(Status::Error(400, "Limit must be non-negative"));
  }
  if (limit == 0) {
    return promise.set_value(Unit());
  }
  if (topic_list_.last_topic_date_ == MAX_TOPIC_DATE) {
    return promise.set_error(Status::Error(404, "Not Found"));
  }
  if (!topic_list_.are_pinned_saved_messages_topics_inited_) {
    return get_pinned_saved_dialogs(limit, std::move(promise));
  }
  get_saved_dialogs(limit, std::move(promise));
}

void SavedMessagesManager::get_pinned_saved_dialogs(int32 limit, Promise<Unit> &&promise) {
  topic_list_.load_pinned_queries_.push_back(std::move(promise));
  if (topic_list_.load_pinned_queries_.size() == 1) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this)](Result<Unit> &&result) {
      send_closure(actor_id, &SavedMessagesManager::on_get_pinned_saved_dialogs, std::move(result));
    });
    td_->create_handler<GetPinnedSavedDialogsQuery>(std::move(query_promise))->send(limit);
  }
}

void SavedMessagesManager::on_get_pinned_saved_dialogs(Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);
  if (result.is_error()) {
    fail_promises(topic_list_.load_pinned_queries_, result.move_as_error());
  } else {
    set_promises(topic_list_.load_pinned_queries_);
  }
}

void SavedMessagesManager::get_saved_dialogs(int32 limit, Promise<Unit> &&promise) {
  topic_list_.load_queries_.push_back(std::move(promise));
  if (topic_list_.load_queries_.size() == 1) {
    auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this)](Result<Unit> &&result) {
      send_closure(actor_id, &SavedMessagesManager::on_get_saved_dialogs, std::move(result));
    });
    td_->create_handler<GetSavedDialogsQuery>(std::move(query_promise))
        ->send(topic_list_.offset_date_, topic_list_.offset_message_id_, topic_list_.offset_dialog_id_, limit);
  }
}

void SavedMessagesManager::on_get_saved_dialogs(Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);
  if (result.is_error()) {
    fail_promises(topic_list_.load_queries_, result.move_as_error());
  } else {
    set_promises(topic_list_.load_queries_);
  }
}

void SavedMessagesManager::on_get_saved_messages_topics(
    bool is_pinned, int32 limit, telegram_api::object_ptr<telegram_api::messages_SavedDialogs> &&saved_dialogs_ptr,
    Promise<Unit> &&promise) {
  CHECK(saved_dialogs_ptr != nullptr);
  int32 total_count = -1;
  vector<telegram_api::object_ptr<telegram_api::savedDialog>> dialogs;
  vector<telegram_api::object_ptr<telegram_api::Message>> messages;
  vector<telegram_api::object_ptr<telegram_api::Chat>> chats;
  vector<telegram_api::object_ptr<telegram_api::User>> users;
  bool is_last = false;
  switch (saved_dialogs_ptr->get_id()) {
    case telegram_api::messages_savedDialogsNotModified::ID:
      LOG(ERROR) << "Receive messages.savedDialogsNotModified";
      return promise.set_error(Status::Error(500, "Receive messages.savedDialogsNotModified"));
    case telegram_api::messages_savedDialogs::ID: {
      auto saved_dialogs = telegram_api::move_object_as<telegram_api::messages_savedDialogs>(saved_dialogs_ptr);
      total_count = static_cast<int32>(saved_dialogs->dialogs_.size());
      dialogs = std::move(saved_dialogs->dialogs_);
      messages = std::move(saved_dialogs->messages_);
      chats = std::move(saved_dialogs->chats_);
      users = std::move(saved_dialogs->users_);
      is_last = true;
      break;
    }
    case telegram_api::messages_savedDialogsSlice::ID: {
      auto saved_dialogs = telegram_api::move_object_as<telegram_api::messages_savedDialogsSlice>(saved_dialogs_ptr);
      total_count = saved_dialogs->count_;
      if (total_count < static_cast<int32>(saved_dialogs->dialogs_.size())) {
        LOG(ERROR) << "Receive total_count = " << total_count << ", but " << saved_dialogs->dialogs_.size()
                   << " Saved Messages topics";
        total_count = static_cast<int32>(saved_dialogs->dialogs_.size());
      }
      dialogs = std::move(saved_dialogs->dialogs_);
      messages = std::move(saved_dialogs->messages_);
      chats = std::move(saved_dialogs->chats_);
      users = std::move(saved_dialogs->users_);
      is_last = dialogs.empty();
      break;
    }
    default:
      UNREACHABLE();
  }
  td_->user_manager_->on_get_users(std::move(users), "on_get_saved_messages_topics");
  td_->chat_manager_->on_get_chats(std::move(chats), "on_get_saved_messages_topics");

  FlatHashMap<MessageId, telegram_api::object_ptr<telegram_api::Message>, MessageIdHash> message_id_to_message;
  for (auto &message : messages) {
    auto message_id = MessageId::get_message_id(message, false);
    if (!message_id.is_valid()) {
      continue;
    }
    message_id_to_message[message_id] = std::move(message);
  }

  int32 last_message_date = 0;
  MessageId last_message_id;
  DialogId last_dialog_id;
  vector<SavedMessagesTopicId> added_saved_messages_topic_ids;
  for (auto &dialog : dialogs) {
    auto peer_dialog_id = DialogId(dialog->peer_);
    if (!peer_dialog_id.is_valid()) {
      LOG(ERROR) << "Receive " << peer_dialog_id << " in result of getSavedMessagesTopics";
      total_count--;
      continue;
    }
    SavedMessagesTopicId saved_messages_topic_id(peer_dialog_id);
    if (td::contains(added_saved_messages_topic_ids, saved_messages_topic_id)) {
      LOG(ERROR) << "Receive " << saved_messages_topic_id
                 << " twice in result of getSavedMessagesTopics with total_count = " << total_count;
      total_count--;
      continue;
    }
    added_saved_messages_topic_ids.push_back(saved_messages_topic_id);

    MessageId last_topic_message_id(ServerMessageId(dialog->top_message_));
    if (!last_topic_message_id.is_valid()) {
      // skip topics without messages
      LOG(ERROR) << "Receive " << saved_messages_topic_id << " without last message";
      total_count--;
      continue;
    }

    auto it = message_id_to_message.find(last_topic_message_id);
    if (it == message_id_to_message.end()) {
      LOG(ERROR) << "Can't find last " << last_topic_message_id << " in " << saved_messages_topic_id;
      total_count--;
      continue;
    }
    auto message_date = MessagesManager::get_message_date(it->second);
    if (!is_pinned && message_date > 0) {
      if (last_message_date != 0 && (last_message_date < message_date || last_message_id < last_topic_message_id)) {
        LOG(ERROR) << "Receive " << last_topic_message_id << " at " << message_date << " after " << last_message_id
                   << " at " << last_message_date;
      }
      last_message_date = message_date;
      last_message_id = last_topic_message_id;
      last_dialog_id = peer_dialog_id;
    }
    auto full_message_id = td_->messages_manager_->on_get_message(std::move(it->second), false, false, false,
                                                                  "on_get_saved_messages_topics");
    message_id_to_message.erase(it);

    if (full_message_id.get_dialog_id() != td_->dialog_manager_->get_my_dialog_id()) {
      if (full_message_id.get_dialog_id() != DialogId()) {
        LOG(ERROR) << "Can't add last " << last_topic_message_id << " to " << saved_messages_topic_id;
      }
      total_count--;
      continue;
    }
    CHECK(full_message_id.get_message_id() == last_topic_message_id);

    auto *topic = add_topic(saved_messages_topic_id);
    if (topic->last_message_id_ == MessageId()) {
      do_set_topic_last_message_id(topic, last_topic_message_id, message_date);
    }
    on_topic_changed(topic, "on_get_saved_messages_topics");
  }

  if (!is_pinned) {
    topic_list_.server_total_count_ = total_count;

    topic_list_.offset_date_ = last_message_date;
    topic_list_.offset_dialog_id_ = last_dialog_id;
    topic_list_.offset_message_id_ = last_message_id;
  } else if (topic_list_.server_total_count_ <= total_count) {
    topic_list_.server_total_count_ = total_count + 1;
  }
  update_saved_messages_topic_sent_total_count("on_get_saved_messages_topics");

  if (is_pinned) {
    if (!topic_list_.are_pinned_saved_messages_topics_inited_ && total_count < limit) {
      get_saved_dialogs(limit - total_count, std::move(promise));
      promise = Promise<Unit>();
    }
    topic_list_.are_pinned_saved_messages_topics_inited_ = true;
    set_pinned_saved_messages_topics(std::move(added_saved_messages_topic_ids));
    set_last_topic_date({MIN_PINNED_TOPIC_ORDER - 1, SavedMessagesTopicId()});
  } else if (is_last) {
    set_last_topic_date(MAX_TOPIC_DATE);

    if (dialogs.empty()) {
      return promise.set_error(Status::Error(404, "Not Found"));
    }
  } else if (last_message_date > 0) {
    set_last_topic_date({get_topic_order(last_message_date, last_message_id), SavedMessagesTopicId(last_dialog_id)});
  } else {
    LOG(ERROR) << "Receive no suitable topics";
    set_last_topic_date(MAX_TOPIC_DATE);
    return promise.set_error(Status::Error(404, "Not Found"));
  }

  promise.set_value(Unit());
}

td_api::object_ptr<td_api::savedMessagesTopic> SavedMessagesManager::get_saved_messages_topic_object(
    const SavedMessagesTopic *topic) const {
  CHECK(topic != nullptr);
  td_api::object_ptr<td_api::message> last_message_object;
  if (topic->last_message_id_ != MessageId()) {
    last_message_object = td_->messages_manager_->get_message_object(
        {td_->dialog_manager_->get_my_dialog_id(), topic->last_message_id_}, "get_saved_messages_topic_object");
  }
  td_api::object_ptr<td_api::draftMessage> draft_message_object;
  if (topic->draft_message_date_ != 0) {
    draft_message_object = td_->messages_manager_->get_my_dialog_draft_message_object();
  }
  return td_api::make_object<td_api::savedMessagesTopic>(
      topic->saved_messages_topic_id_.get_unique_id(),
      topic->saved_messages_topic_id_.get_saved_messages_topic_type_object(td_), topic->pinned_order_ != 0,
      get_topic_public_order(topic), std::move(last_message_object), std::move(draft_message_object));
}

td_api::object_ptr<td_api::updateSavedMessagesTopic> SavedMessagesManager::get_update_saved_messages_topic_object(
    const SavedMessagesTopic *topic) const {
  return td_api::make_object<td_api::updateSavedMessagesTopic>(get_saved_messages_topic_object(topic));
}

void SavedMessagesManager::send_update_saved_messages_topic(const SavedMessagesTopic *topic, const char *source) const {
  CHECK(topic != nullptr);
  LOG(INFO) << "Send update about " << topic->saved_messages_topic_id_ << " with order "
            << get_topic_public_order(topic) << " and last " << topic->last_message_id_ << " sent at "
            << topic->last_message_date_ << " with draft at " << topic->draft_message_date_ << " from " << source;
  send_closure(G()->td(), &Td::send_update, get_update_saved_messages_topic_object(topic));
}

int64 SavedMessagesManager::get_next_pinned_saved_messages_topic_order() {
  current_pinned_saved_messages_topic_order_++;
  LOG(INFO) << "Assign pinned_order = " << current_pinned_saved_messages_topic_order_;
  return current_pinned_saved_messages_topic_order_;
}

td_api::object_ptr<td_api::updateSavedMessagesTopicCount>
SavedMessagesManager::get_update_saved_messages_topic_count_object() const {
  CHECK(topic_list_.sent_total_count_ != -1);
  return td_api::make_object<td_api::updateSavedMessagesTopicCount>(topic_list_.sent_total_count_);
}

void SavedMessagesManager::update_saved_messages_topic_sent_total_count(const char *source) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  if (topic_list_.server_total_count_ == -1) {
    return;
  }
  LOG(INFO) << "Update Saved Messages topic sent total count from " << source;
  auto new_total_count = static_cast<int32>(topic_list_.ordered_topics_.size());
  if (topic_list_.last_topic_date_ != MAX_TOPIC_DATE) {
    new_total_count = max(new_total_count, topic_list_.server_total_count_);
  } else if (topic_list_.server_total_count_ != new_total_count) {
    topic_list_.server_total_count_ = new_total_count;
  }
  if (topic_list_.sent_total_count_ != new_total_count) {
    topic_list_.sent_total_count_ = new_total_count;
    send_closure(G()->td(), &Td::send_update, get_update_saved_messages_topic_count_object());
  }
}

bool SavedMessagesManager::set_pinned_saved_messages_topics(vector<SavedMessagesTopicId> saved_messages_topic_ids) {
  if (topic_list_.pinned_saved_messages_topic_ids_ == saved_messages_topic_ids) {
    return false;
  }
  LOG(INFO) << "Update pinned Saved Messages topics from " << topic_list_.pinned_saved_messages_topic_ids_ << " to "
            << saved_messages_topic_ids;
  FlatHashSet<SavedMessagesTopicId, SavedMessagesTopicIdHash> old_pinned_saved_messages_topic_ids;
  for (auto pinned_saved_messages_topic_id : topic_list_.pinned_saved_messages_topic_ids_) {
    CHECK(pinned_saved_messages_topic_id.is_valid());
    old_pinned_saved_messages_topic_ids.insert(pinned_saved_messages_topic_id);
  }

  auto pinned_saved_messages_topic_ids = topic_list_.pinned_saved_messages_topic_ids_;
  std::reverse(pinned_saved_messages_topic_ids.begin(), pinned_saved_messages_topic_ids.end());
  std::reverse(saved_messages_topic_ids.begin(), saved_messages_topic_ids.end());
  auto old_it = pinned_saved_messages_topic_ids.begin();
  for (auto saved_messages_topic_id : saved_messages_topic_ids) {
    old_pinned_saved_messages_topic_ids.erase(saved_messages_topic_id);
    while (old_it < pinned_saved_messages_topic_ids.end()) {
      if (*old_it == saved_messages_topic_id) {
        break;
      }
      ++old_it;
    }
    if (old_it < pinned_saved_messages_topic_ids.end()) {
      // leave saved_messages_topic where it is
      ++old_it;
      continue;
    }
    set_saved_messages_topic_is_pinned(saved_messages_topic_id, true, "set_pinned_saved_messages_topics 1");
  }
  for (auto saved_messages_topic_id : old_pinned_saved_messages_topic_ids) {
    set_saved_messages_topic_is_pinned(saved_messages_topic_id, false, "set_pinned_saved_messages_topics 2");
  }
  return true;
}

bool SavedMessagesManager::set_saved_messages_topic_is_pinned(SavedMessagesTopicId saved_messages_topic_id,
                                                              bool is_pinned, const char *source) {
  return set_saved_messages_topic_is_pinned(get_topic(saved_messages_topic_id), is_pinned, source);
}

bool SavedMessagesManager::set_saved_messages_topic_is_pinned(SavedMessagesTopic *topic, bool is_pinned,
                                                              const char *source) {
  CHECK(!td_->auth_manager_->is_bot());
  LOG_CHECK(topic != nullptr) << source;
  if (!topic_list_.are_pinned_saved_messages_topics_inited_) {
    return false;
  }
  auto saved_messages_topic_id = topic->saved_messages_topic_id_;
  if (is_pinned) {
    if (!topic_list_.pinned_saved_messages_topic_ids_.empty() &&
        topic_list_.pinned_saved_messages_topic_ids_[0] == saved_messages_topic_id) {
      return false;
    }
    topic->pinned_order_ = get_next_pinned_saved_messages_topic_order();
    add_to_top(topic_list_.pinned_saved_messages_topic_ids_, topic_list_.pinned_saved_messages_topic_ids_.size() + 1,
               saved_messages_topic_id);
  } else {
    if (topic->pinned_order_ == 0 ||
        !td::remove(topic_list_.pinned_saved_messages_topic_ids_, saved_messages_topic_id)) {
      return false;
    }
    topic->pinned_order_ = 0;
  }

  LOG(INFO) << "Set " << saved_messages_topic_id << " pinned order to " << topic->pinned_order_ << " from " << source;
  topic->is_changed_ = true;
  on_topic_changed(topic, source);
  return true;
}

void SavedMessagesManager::set_last_topic_date(TopicDate topic_date) {
  if (topic_date <= topic_list_.last_topic_date_) {
    return;
  }
  auto min_topic_date = topic_list_.last_topic_date_;
  topic_list_.last_topic_date_ = topic_date;
  for (auto it = topic_list_.ordered_topics_.upper_bound(min_topic_date);
       it != topic_list_.ordered_topics_.end() && *it <= topic_date; ++it) {
    auto topic = get_topic(it->get_topic_id());
    CHECK(topic != nullptr);
    send_update_saved_messages_topic(topic, "set_last_topic_date");
  }
}

void SavedMessagesManager::get_saved_messages_topic_history(SavedMessagesTopicId saved_messages_topic_id,
                                                            MessageId from_message_id, int32 offset, int32 limit,
                                                            Promise<td_api::object_ptr<td_api::messages>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_GET_HISTORY) {
    limit = MAX_GET_HISTORY;
  }
  if (offset > 0) {
    return promise.set_error(Status::Error(400, "Parameter offset must be non-positive"));
  }
  if (offset <= -MAX_GET_HISTORY) {
    return promise.set_error(Status::Error(400, "Parameter offset must be greater than -100"));
  }
  if (offset < -limit) {
    return promise.set_error(Status::Error(400, "Parameter offset must be greater than or equal to -limit"));
  }

  TRY_STATUS_PROMISE(promise, saved_messages_topic_id.is_valid_status(td_));

  if (from_message_id == MessageId() || from_message_id.get() > MessageId::max().get()) {
    from_message_id = MessageId::max();
    limit += offset;
    offset = 0;
  }
  if (!from_message_id.is_valid() || !from_message_id.is_server()) {
    return promise.set_error(Status::Error(400, "Invalid value of parameter from_message_id specified"));
  }

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), saved_messages_topic_id, from_message_id,
                                               promise = std::move(promise)](Result<MessagesInfo> &&r_info) mutable {
    send_closure(actor_id, &SavedMessagesManager::on_get_saved_messages_topic_history, saved_messages_topic_id,
                 from_message_id, std::move(r_info), std::move(promise));
  });
  td_->create_handler<GetSavedHistoryQuery>(std::move(query_promise))
      ->send(saved_messages_topic_id, from_message_id, offset, limit);
}

void SavedMessagesManager::on_get_saved_messages_topic_history(
    SavedMessagesTopicId saved_messages_topic_id, MessageId from_message_id, Result<MessagesInfo> &&r_info,
    Promise<td_api::object_ptr<td_api::messages>> &&promise) {
  G()->ignore_result_if_closing(r_info);
  if (r_info.is_error()) {
    return promise.set_error(r_info.move_as_error());
  }
  auto info = r_info.move_as_ok();

  auto my_dialog_id = td_->dialog_manager_->get_my_dialog_id();
  vector<td_api::object_ptr<td_api::message>> messages;
  MessageId last_message_id;
  int32 last_message_date = 0;
  for (auto &message : info.messages) {
    auto message_date = MessagesManager::get_message_date(message);
    auto full_message_id = td_->messages_manager_->on_get_message(std::move(message), false, false, false,
                                                                  "on_get_saved_messages_topic_history");
    auto dialog_id = full_message_id.get_dialog_id();
    if (dialog_id == DialogId()) {
      continue;
    }
    if (dialog_id != my_dialog_id) {
      LOG(ERROR) << "Receive " << full_message_id << " in history of " << saved_messages_topic_id;
      continue;
    }
    if (!last_message_id.is_valid()) {
      last_message_id = full_message_id.get_message_id();
      last_message_date = message_date;
    }
    messages.push_back(
        td_->messages_manager_->get_message_object(full_message_id, "on_get_saved_messages_topic_history"));
  }
  if (from_message_id == MessageId::max()) {
    auto *topic = add_topic(saved_messages_topic_id);
    if (info.messages.empty()) {
      do_set_topic_last_message_id(topic, MessageId(), 0);
    } else {
      if (last_message_id.is_valid() && topic->last_message_id_ == MessageId()) {
        do_set_topic_last_message_id(topic, last_message_id, last_message_date);
      }
    }
    on_topic_changed(topic, "on_get_saved_messages_topic_history");
  }
  promise.set_value(td_api::make_object<td_api::messages>(info.total_count, std::move(messages)));
}

void SavedMessagesManager::delete_saved_messages_topic_history(SavedMessagesTopicId saved_messages_topic_id,
                                                               Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, saved_messages_topic_id.is_valid_status(td_));

  MessageQueryManager::AffectedHistoryQuery query = [td = td_, saved_messages_topic_id](
                                                        DialogId, Promise<AffectedHistory> &&query_promise) {
    td->create_handler<DeleteSavedHistoryQuery>(std::move(query_promise))->send(saved_messages_topic_id);
  };
  auto my_dialog_id = td_->dialog_manager_->get_my_dialog_id();
  td_->message_query_manager_->run_affected_history_query_until_complete(my_dialog_id, std::move(query), true,
                                                                         std::move(promise));
}

void SavedMessagesManager::get_saved_messages_topic_message_by_date(
    SavedMessagesTopicId saved_messages_topic_id, int32 date, Promise<td_api::object_ptr<td_api::message>> &&promise) {
  TRY_STATUS_PROMISE(promise, saved_messages_topic_id.is_valid_status(td_));

  if (date <= 0) {
    date = 1;
  }

  td_->create_handler<GetSavedMessageByDateQuery>(std::move(promise))->send(saved_messages_topic_id, date);
}

void SavedMessagesManager::delete_saved_messages_topic_messages_by_date(SavedMessagesTopicId saved_messages_topic_id,
                                                                        int32 min_date, int32 max_date,
                                                                        Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, saved_messages_topic_id.is_valid_status(td_));

  TRY_STATUS_PROMISE(promise, MessagesManager::fix_delete_message_min_max_dates(min_date, max_date));
  if (max_date == 0) {
    return promise.set_value(Unit());
  }

  MessageQueryManager::AffectedHistoryQuery query = [td = td_, saved_messages_topic_id, min_date, max_date](
                                                        DialogId, Promise<AffectedHistory> &&query_promise) {
    td->create_handler<DeleteSavedMessagesByDateQuery>(std::move(query_promise))
        ->send(saved_messages_topic_id, min_date, max_date);
  };
  auto my_dialog_id = td_->dialog_manager_->get_my_dialog_id();
  td_->message_query_manager_->run_affected_history_query_until_complete(my_dialog_id, std::move(query), true,
                                                                         std::move(promise));
}

int32 SavedMessagesManager::get_pinned_saved_messages_topic_limit() const {
  return clamp(narrow_cast<int32>(td_->option_manager_->get_option_integer("pinned_saved_messages_topic_count_max")), 0,
               1000);
}

void SavedMessagesManager::toggle_saved_messages_topic_is_pinned(SavedMessagesTopicId saved_messages_topic_id,
                                                                 bool is_pinned, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, saved_messages_topic_id.is_valid_status(td_));
  if (!topic_list_.are_pinned_saved_messages_topics_inited_) {
    return promise.set_error(Status::Error(400, "Pinned Saved Messages topics must be loaded first"));
  }
  auto *topic = get_topic(saved_messages_topic_id);
  if (topic == nullptr) {
    return promise.set_error(Status::Error(400, "Can't find Saved Messages topic"));
  }
  if (is_pinned && !td::contains(topic_list_.pinned_saved_messages_topic_ids_, saved_messages_topic_id) &&
      static_cast<size_t>(get_pinned_saved_messages_topic_limit()) <=
          topic_list_.pinned_saved_messages_topic_ids_.size()) {
    return promise.set_error(Status::Error(400, "The maximum number of pinned chats exceeded"));
  }
  if (!set_saved_messages_topic_is_pinned(topic, is_pinned, "toggle_saved_messages_topic_is_pinned")) {
    return promise.set_value(Unit());
  }
  td_->create_handler<ToggleSavedDialogPinQuery>(std::move(promise))->send(saved_messages_topic_id, is_pinned);
}

void SavedMessagesManager::set_pinned_saved_messages_topics(vector<SavedMessagesTopicId> saved_messages_topic_ids,
                                                            Promise<Unit> &&promise) {
  for (const auto &saved_messages_topic_id : saved_messages_topic_ids) {
    TRY_STATUS_PROMISE(promise, saved_messages_topic_id.is_valid_status(td_));
    if (get_topic(saved_messages_topic_id) == nullptr) {
      return promise.set_error(Status::Error(400, "Can't find Saved Messages topic"));
    }
  }
  if (!topic_list_.are_pinned_saved_messages_topics_inited_) {
    return promise.set_error(Status::Error(400, "Pinned Saved Messages topics must be loaded first"));
  }
  if (static_cast<size_t>(get_pinned_saved_messages_topic_limit()) < saved_messages_topic_ids.size()) {
    return promise.set_error(Status::Error(400, "The maximum number of pinned chats exceeded"));
  }
  if (!set_pinned_saved_messages_topics(saved_messages_topic_ids)) {
    return promise.set_value(Unit());
  }
  td_->create_handler<ReorderPinnedSavedDialogsQuery>(std::move(promise))->send(std::move(saved_messages_topic_ids));
}

void SavedMessagesManager::reload_pinned_saved_messages_topics() {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return;
  }
  if (!topic_list_.are_pinned_saved_messages_topics_inited_) {
    return;
  }

  get_pinned_saved_dialogs(0, Auto());
}

void SavedMessagesManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (topic_list_.sent_total_count_ != -1) {
    updates.push_back(get_update_saved_messages_topic_count_object());
  }

  for (const auto &it : saved_messages_topics_) {
    const auto *topic = it.second.get();
    updates.push_back(get_update_saved_messages_topic_object(topic));
  }
}

const SavedMessagesManager::TopicDate SavedMessagesManager::MIN_TOPIC_DATE{std::numeric_limits<int64>::max(),
                                                                           SavedMessagesTopicId()};
const SavedMessagesManager::TopicDate SavedMessagesManager::MAX_TOPIC_DATE{0, SavedMessagesTopicId()};

}  // namespace td
