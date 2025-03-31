//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessagesInfo.h"
#include "td/telegram/SavedMessagesTopicId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <limits>
#include <set>

namespace td {

class Td;

class SavedMessagesManager final : public Actor {
 public:
  SavedMessagesManager(Td *td, ActorShared<> parent);

  SavedMessagesTopicId get_topic_id(int64 topic_id) const;

  vector<SavedMessagesTopicId> get_topic_ids(const vector<int64> &topic_ids) const;

  int64 get_saved_messages_topic_id_object(SavedMessagesTopicId saved_messages_topic_id);

  void set_topic_last_message_id(SavedMessagesTopicId saved_messages_topic_id, MessageId last_message_id,
                                 int32 last_message_date);

  void on_topic_message_updated(SavedMessagesTopicId saved_messages_topic_id, MessageId message_id);

  void on_topic_message_deleted(SavedMessagesTopicId saved_messages_topic_id, MessageId message_id);

  void on_topic_draft_message_updated(SavedMessagesTopicId saved_messages_topic_id, int32 draft_message_date);

  void load_saved_messages_topics(int32 limit, Promise<Unit> &&promsie);

  void on_get_saved_messages_topics(bool is_pinned, int32 limit,
                                    telegram_api::object_ptr<telegram_api::messages_SavedDialogs> &&saved_dialogs_ptr,
                                    Promise<Unit> &&promise);

  void get_saved_messages_topic_history(SavedMessagesTopicId saved_messages_topic_id, MessageId from_message_id,
                                        int32 offset, int32 limit,
                                        Promise<td_api::object_ptr<td_api::messages>> &&promise);

  void delete_saved_messages_topic_history(SavedMessagesTopicId saved_messages_topic_id, Promise<Unit> &&promise);

  void get_saved_messages_topic_message_by_date(SavedMessagesTopicId saved_messages_topic_id, int32 date,
                                                Promise<td_api::object_ptr<td_api::message>> &&promise);

  void delete_saved_messages_topic_messages_by_date(SavedMessagesTopicId saved_messages_topic_id, int32 min_date,
                                                    int32 max_date, Promise<Unit> &&promise);

  void toggle_saved_messages_topic_is_pinned(SavedMessagesTopicId saved_messages_topic_id, bool is_pinned,
                                             Promise<Unit> &&promise);

  void set_pinned_saved_messages_topics(vector<SavedMessagesTopicId> saved_messages_topic_ids, Promise<Unit> &&promise);

  void reload_pinned_saved_messages_topics();

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  static constexpr int32 MAX_GET_HISTORY = 100;  // server side limit

  static constexpr int64 MIN_PINNED_TOPIC_ORDER = static_cast<int64>(2147000000) << 32;

  struct SavedMessagesTopic {
    SavedMessagesTopicId saved_messages_topic_id_;
    MessageId last_message_id_;
    int32 last_message_date_ = 0;
    int32 draft_message_date_ = 0;
    int64 pinned_order_ = 0;
    int64 private_order_ = 0;
    bool is_changed_ = false;
  };

  class TopicDate {
    int64 order_;
    SavedMessagesTopicId topic_id_;

   public:
    TopicDate(int64 order, SavedMessagesTopicId topic_id) : order_(order), topic_id_(topic_id) {
    }

    bool operator<(const TopicDate &other) const {
      return order_ > other.order_ ||
             (order_ == other.order_ && topic_id_.get_unique_id() > other.topic_id_.get_unique_id());
    }

    bool operator<=(const TopicDate &other) const {
      return order_ > other.order_ ||
             (order_ == other.order_ && topic_id_.get_unique_id() >= other.topic_id_.get_unique_id());
    }

    bool operator==(const TopicDate &other) const {
      return order_ == other.order_ && topic_id_ == other.topic_id_;
    }

    bool operator!=(const TopicDate &other) const {
      return !(*this == other);
    }

    SavedMessagesTopicId get_topic_id() const {
      return topic_id_;
    }
  };

  static const TopicDate MIN_TOPIC_DATE;
  static const TopicDate MAX_TOPIC_DATE;

  struct TopicList {
    int32 server_total_count_ = -1;
    int32 sent_total_count_ = -1;

    vector<SavedMessagesTopicId> pinned_saved_messages_topic_ids_;
    bool are_pinned_saved_messages_topics_inited_ = false;

    std::set<TopicDate> ordered_topics_;

    TopicDate last_topic_date_ = MIN_TOPIC_DATE;  // in memory

    vector<Promise<Unit>> load_pinned_queries_;
    vector<Promise<Unit>> load_queries_;

    int32 offset_date_ = std::numeric_limits<int32>::max();
    DialogId offset_dialog_id_;
    MessageId offset_message_id_;
  };

  void tear_down() final;

  SavedMessagesTopic *get_topic(SavedMessagesTopicId saved_messages_topic_id);

  SavedMessagesTopic *add_topic(SavedMessagesTopicId saved_messages_topic_id);

  void get_pinned_saved_dialogs(int32 limit, Promise<Unit> &&promise);

  void on_get_pinned_saved_dialogs(Result<Unit> &&result);

  void get_saved_dialogs(int32 limit, Promise<Unit> &&promise);

  void on_get_saved_dialogs(Result<Unit> &&result);

  void on_get_saved_messages_topic_history(SavedMessagesTopicId saved_messages_topic_id, MessageId from_message_id,
                                           Result<MessagesInfo> &&r_info,
                                           Promise<td_api::object_ptr<td_api::messages>> &&promise);

  void do_set_topic_last_message_id(SavedMessagesTopic *topic, MessageId last_message_id, int32 last_message_date);

  int64 get_next_pinned_saved_messages_topic_order();

  bool set_pinned_saved_messages_topics(vector<SavedMessagesTopicId> added_saved_messages_topic_ids);

  bool set_saved_messages_topic_is_pinned(SavedMessagesTopicId saved_messages_topic_id, bool is_pinned,
                                          const char *source);

  bool set_saved_messages_topic_is_pinned(SavedMessagesTopic *topic, bool is_pinned, const char *source);

  int32 get_pinned_saved_messages_topic_limit() const;

  int64 get_topic_order(int32 message_date, MessageId message_id);

  int64 get_topic_public_order(const SavedMessagesTopic *topic) const;

  void set_last_topic_date(TopicDate topic_date);

  void on_topic_changed(SavedMessagesTopic *topic, const char *source);

  td_api::object_ptr<td_api::savedMessagesTopic> get_saved_messages_topic_object(const SavedMessagesTopic *topic) const;

  td_api::object_ptr<td_api::updateSavedMessagesTopic> get_update_saved_messages_topic_object(
      const SavedMessagesTopic *topic) const;

  void send_update_saved_messages_topic(const SavedMessagesTopic *topic, const char *source) const;

  td_api::object_ptr<td_api::updateSavedMessagesTopicCount> get_update_saved_messages_topic_count_object() const;

  void update_saved_messages_topic_sent_total_count(const char *source);

  Td *td_;
  ActorShared<> parent_;

  FlatHashMap<SavedMessagesTopicId, unique_ptr<SavedMessagesTopic>, SavedMessagesTopicIdHash> saved_messages_topics_;

  int64 current_pinned_saved_messages_topic_order_ = MIN_PINNED_TOPIC_ORDER;

  TopicList topic_list_;
};

}  // namespace td
