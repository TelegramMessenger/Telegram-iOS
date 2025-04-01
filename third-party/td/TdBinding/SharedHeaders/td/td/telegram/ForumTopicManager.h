//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogNotificationSettings.h"
#include "td/telegram/ForumTopic.h"
#include "td/telegram/ForumTopicEditedData.h"
#include "td/telegram/ForumTopicInfo.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessagesInfo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/WaitFreeHashMap.h"
#include "td/utils/WaitFreeHashSet.h"

namespace td {

class Td;

class ForumTopicManager final : public Actor {
 public:
  ForumTopicManager(Td *td, ActorShared<> parent);
  ForumTopicManager(const ForumTopicManager &) = delete;
  ForumTopicManager &operator=(const ForumTopicManager &) = delete;
  ForumTopicManager(ForumTopicManager &&) = delete;
  ForumTopicManager &operator=(ForumTopicManager &&) = delete;
  ~ForumTopicManager() final;

  void create_forum_topic(DialogId dialog_id, string &&title, td_api::object_ptr<td_api::forumTopicIcon> &&icon,
                          Promise<td_api::object_ptr<td_api::forumTopicInfo>> &&promise);

  void on_forum_topic_created(DialogId dialog_id, unique_ptr<ForumTopicInfo> &&forum_topic_info,
                              Promise<td_api::object_ptr<td_api::forumTopicInfo>> &&promise);

  void edit_forum_topic(DialogId dialog_id, MessageId top_thread_message_id, string &&title,
                        bool edit_icon_custom_emoji, CustomEmojiId icon_custom_emoji_id, Promise<Unit> &&promise);

  void get_forum_topic(DialogId dialog_id, MessageId top_thread_message_id,
                       Promise<td_api::object_ptr<td_api::forumTopic>> &&promise);

  void on_get_forum_topic(ChannelId channel_id, MessageId expected_top_thread_message_id, MessagesInfo &&info,
                          telegram_api::object_ptr<telegram_api::ForumTopic> &&topic,
                          Promise<td_api::object_ptr<td_api::forumTopic>> &&promise);

  void on_get_forum_topics(ChannelId channel_id, bool order_by_creation_date, MessagesInfo &&info,
                           vector<telegram_api::object_ptr<telegram_api::ForumTopic>> &&topics,
                           Promise<td_api::object_ptr<td_api::forumTopics>> &&promise);

  void get_forum_topic_link(DialogId dialog_id, MessageId top_thread_message_id,
                            Promise<td_api::object_ptr<td_api::messageLink>> &&promise);

  void get_forum_topics(DialogId dialog_id, string query, int32 offset_date, MessageId offset_message_id,
                        MessageId offset_top_thread_message_id, int32 limit,
                        Promise<td_api::object_ptr<td_api::forumTopics>> promise);

  void toggle_forum_topic_is_closed(DialogId dialog_id, MessageId top_thread_message_id, bool is_closed,
                                    Promise<Unit> &&promise);

  const DialogNotificationSettings *get_forum_topic_notification_settings(DialogId dialog_id,
                                                                          MessageId top_thread_message_id) const;

  Status set_forum_topic_notification_settings(DialogId dialog_id, MessageId top_thread_message_id,
                                               tl_object_ptr<td_api::chatNotificationSettings> &&notification_settings)
      TD_WARN_UNUSED_RESULT;

  void toggle_forum_topic_is_hidden(DialogId dialog_id, bool is_hidden, Promise<Unit> &&promise);

  void toggle_forum_topic_is_pinned(DialogId dialog_id, MessageId top_thread_message_id, bool is_pinned,
                                    Promise<Unit> &&promise);

  void set_pinned_forum_topics(DialogId dialog_id, vector<MessageId> top_thread_message_ids, Promise<Unit> &&promise);

  void delete_forum_topic(DialogId dialog_id, MessageId top_thread_message_id, Promise<Unit> &&promise);

  void delete_all_dialog_topics(DialogId dialog_id);

  void read_forum_topic_messages(DialogId dialog_id, MessageId top_thread_message_id,
                                 MessageId last_read_inbox_message_id);

  void on_update_forum_topic_unread(DialogId dialog_id, MessageId top_thread_message_id, MessageId last_message_id,
                                    MessageId last_read_inbox_message_id, MessageId last_read_outbox_message_id,
                                    int32 unread_count);

  void on_update_forum_topic_notify_settings(DialogId dialog_id, MessageId top_thread_message_id,
                                             tl_object_ptr<telegram_api::peerNotifySettings> &&peer_notify_settings,
                                             const char *source);

  void on_update_forum_topic_is_pinned(DialogId dialog_id, MessageId top_thread_message_id, bool is_pinned);

  void on_update_pinned_forum_topics(DialogId dialog_id, vector<MessageId> top_thread_message_ids);

  void on_forum_topic_edited(DialogId dialog_id, MessageId top_thread_message_id,
                             const ForumTopicEditedData &edited_data);

  void on_get_forum_topic_info(DialogId dialog_id, const ForumTopicInfo &topic_info, const char *source);

  void on_get_forum_topic_infos(DialogId dialog_id, vector<tl_object_ptr<telegram_api::ForumTopic>> &&forum_topics,
                                const char *source);

  td_api::object_ptr<td_api::forumTopic> get_forum_topic_object(DialogId dialog_id,
                                                                MessageId top_thread_message_id) const;

  void on_topic_message_count_changed(DialogId dialog_id, MessageId top_thread_message_id, int diff);

 private:
  static constexpr size_t MAX_FORUM_TOPIC_TITLE_LENGTH = 128;  // server side limit for forum topic title

  struct Topic {
    unique_ptr<ForumTopicInfo> info_;
    unique_ptr<ForumTopic> topic_;
    int32 message_count_ = 0;
    mutable bool need_save_to_database_ = true;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);

    int32 MAGIC = 0x1fac3901;
  };

  struct DialogTopics {
    WaitFreeHashMap<MessageId, unique_ptr<Topic>, MessageIdHash> topics_;
    WaitFreeHashSet<MessageId, MessageIdHash> deleted_topic_ids_;
  };

  void tear_down() final;

  Status is_forum(DialogId dialog_id);

  bool can_be_forum(DialogId dialog_id) const;

  static Status can_be_message_thread_id(MessageId top_thread_message_id);

  DialogTopics *add_dialog_topics(DialogId dialog_id);

  DialogTopics *get_dialog_topics(DialogId dialog_id);

  static Topic *add_topic(DialogTopics *dialog_topics, MessageId top_thread_message_id);

  static Topic *get_topic(DialogTopics *dialog_topics, MessageId top_thread_message_id);

  Topic *add_topic(DialogId dialog_id, MessageId top_thread_message_id);

  Topic *get_topic(DialogId dialog_id, MessageId top_thread_message_id);

  const Topic *get_topic(DialogId dialog_id, MessageId top_thread_message_id) const;

  ForumTopicInfo *get_topic_info(DialogId dialog_id, MessageId top_thread_message_id);

  const ForumTopicInfo *get_topic_info(DialogId dialog_id, MessageId top_thread_message_id) const;

  void set_topic_info(DialogId dialog_id, Topic *topic, unique_ptr<ForumTopicInfo> forum_topic_info);

  MessageId on_get_forum_topic_impl(DialogId dialog_id, tl_object_ptr<telegram_api::ForumTopic> &&forum_topic);

  DialogNotificationSettings *get_forum_topic_notification_settings(DialogId dialog_id,
                                                                    MessageId top_thread_message_id);

  bool update_forum_topic_notification_settings(DialogId dialog_id, MessageId top_thread_message_id,
                                                DialogNotificationSettings *current_settings,
                                                DialogNotificationSettings &&new_settings);

  void on_delete_forum_topic(DialogId dialog_id, MessageId top_thread_message_id, Promise<Unit> &&promise);

  td_api::object_ptr<td_api::updateForumTopicInfo> get_update_forum_topic_info(DialogId dialog_id,
                                                                               const ForumTopicInfo *topic_info) const;

  void send_update_forum_topic_info(DialogId dialog_id, const ForumTopicInfo *topic_info) const;

  void save_topic_to_database(DialogId dialog_id, const Topic *topic);

  void delete_topic_from_database(DialogId dialog_id, MessageId top_thread_message_id, Promise<Unit> &&promise);

  Td *td_;
  ActorShared<> parent_;

  WaitFreeHashMap<DialogId, unique_ptr<DialogTopics>, DialogIdHash> dialog_topics_;
};

}  // namespace td
