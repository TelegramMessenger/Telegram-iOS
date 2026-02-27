//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CallId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/Document.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/Notification.h"
#include "td/telegram/NotificationGroupId.h"
#include "td/telegram/NotificationGroupKey.h"
#include "td/telegram/NotificationGroupType.h"
#include "td/telegram/NotificationId.h"
#include "td/telegram/NotificationObjectFullId.h"
#include "td/telegram/NotificationObjectId.h"
#include "td/telegram/NotificationType.h"
#include "td/telegram/Photo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"

#include <functional>
#include <map>

namespace td {

extern int VERBOSITY_NAME(notifications);

struct BinlogEvent;
class JsonObject;
class Td;

class NotificationManager final : public Actor {
 public:
  static constexpr int32 MIN_NOTIFICATION_GROUP_COUNT_MAX = 0;
  static constexpr int32 MAX_NOTIFICATION_GROUP_COUNT_MAX = 25;
  static constexpr int32 MIN_NOTIFICATION_GROUP_SIZE_MAX = 1;
  static constexpr int32 MAX_NOTIFICATION_GROUP_SIZE_MAX = 25;

  NotificationManager(Td *td, ActorShared<> parent);

  void init();

  size_t get_max_notification_group_size() const;

  NotificationId get_max_notification_id() const;

  NotificationId get_next_notification_id();

  NotificationGroupId get_next_notification_group_id();

  void try_reuse_notification_group_id(NotificationGroupId group_id);

  void load_group_force(NotificationGroupId group_id);

  bool have_group_force(NotificationGroupId group_id);

  void add_notification(NotificationGroupId group_id, NotificationGroupType group_type, DialogId dialog_id, int32 date,
                        DialogId notification_settings_dialog_id, bool disable_notification, int64 ringtone_id,
                        int32 min_delay_ms, NotificationId notification_id, unique_ptr<NotificationType> type,
                        const char *source);

  void edit_notification(NotificationGroupId group_id, NotificationId notification_id,
                         unique_ptr<NotificationType> type);

  void remove_notification(NotificationGroupId group_id, NotificationId notification_id, bool is_permanent,
                           bool force_update, Promise<Unit> &&promise, const char *source);

  void remove_temporary_notifications(NotificationGroupId group_id, const char *source);

  void remove_temporary_notification_by_object_id(NotificationGroupId group_id, NotificationObjectId object_id,
                                                  bool force_update, const char *source);

  void remove_notification_group(NotificationGroupId group_id, NotificationId max_notification_id,
                                 NotificationObjectId max_object_id, int32 new_total_count, bool force_update,
                                 Promise<Unit> &&promise);

  void set_notification_total_count(NotificationGroupId group_id, int32 new_total_count);

  vector<MessageId> get_notification_group_message_ids(NotificationGroupId group_id);

  void add_call_notification(DialogId dialog_id, CallId call_id);

  void remove_call_notification(DialogId dialog_id, CallId call_id);

  void get_disable_contact_registered_notifications(Promise<Unit> &&promise);

  void on_notification_group_count_max_changed(bool send_updates);

  void on_notification_group_size_max_changed();

  void on_online_cloud_timeout_changed();

  void on_notification_cloud_delay_changed();

  void on_notification_default_delay_changed();

  void on_disable_contact_registered_notifications_changed();

  void process_push_notification(string payload, Promise<Unit> &&user_promise);

  static Result<int64> get_push_receiver_id(string payload);

  static Result<string> decrypt_push(int64 encryption_key_id, string encryption_key, string push);  // public for tests

  void before_get_difference();

  void after_get_difference();

  void before_get_chat_difference(NotificationGroupId group_id);

  void after_get_chat_difference(NotificationGroupId group_id);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

  void flush_all_notifications();

  void destroy_all_notifications();

  void on_binlog_events(vector<BinlogEvent> &&events);

 private:
  static constexpr int32 DEFAULT_GROUP_COUNT_MAX = 0;
  static constexpr int32 DEFAULT_GROUP_SIZE_MAX = 10;
  static constexpr size_t EXTRA_GROUP_SIZE = 10;

  static constexpr size_t MAX_CALL_NOTIFICATION_GROUPS = 10;
  static constexpr size_t MAX_CALL_NOTIFICATIONS = 10;

  static constexpr int32 DEFAULT_ONLINE_CLOUD_TIMEOUT_MS = 300000;
  static constexpr int32 DEFAULT_ONLINE_CLOUD_DELAY_MS = 30000;
  static constexpr int32 DEFAULT_DEFAULT_DELAY_MS = 1500;

  static constexpr int32 MIN_NOTIFICATION_DELAY_MS = 1;

  static constexpr int32 MIN_UPDATE_DELAY_MS = 50;
  static constexpr int32 MAX_UPDATE_DELAY_MS = 60000;

  static constexpr int32 ANNOUNCEMENT_ID_CACHE_TIME = 7 * 86400;

  class AddMessagePushNotificationLogEvent;
  class EditMessagePushNotificationLogEvent;

  struct PendingNotification {
    int32 date = 0;
    DialogId settings_dialog_id;
    bool disable_notification = false;
    int64 ringtone_id = -1;
    NotificationId notification_id;
    unique_ptr<NotificationType> type;

    friend StringBuilder &operator<<(StringBuilder &string_builder, const PendingNotification &pending_notification) {
      return string_builder << "PendingNotification[" << pending_notification.notification_id << " of type "
                            << pending_notification.type << " sent at " << pending_notification.date
                            << " with settings from " << pending_notification.settings_dialog_id
                            << ", ringtone_id = " << pending_notification.ringtone_id << "]";
    }
  };

  struct NotificationGroup {
    int32 total_count = 0;
    NotificationGroupType type = NotificationGroupType::Calls;
    bool is_loaded_from_database = false;
    bool is_being_loaded_from_database = false;

    vector<Notification> notifications;

    double pending_notifications_flush_time = 0;
    vector<PendingNotification> pending_notifications;

    friend StringBuilder &operator<<(StringBuilder &string_builder, const NotificationGroup &notification_group) {
      return string_builder << "NotificationGroup[" << notification_group.type << " with total "
                            << notification_group.total_count << " notifications " << notification_group.notifications
                            << " + " << notification_group.pending_notifications
                            << ", is_loaded_from_database = " << notification_group.is_loaded_from_database
                            << ", is_being_loaded_from_database = " << notification_group.is_being_loaded_from_database
                            << ", pending_notifications_flush_time = "
                            << notification_group.pending_notifications_flush_time << ", now = " << Time::now() << "]";
    }
  };

  struct ActiveNotificationsUpdate {
    const td_api::updateActiveNotifications *update;
  };

  struct NotificationUpdate {
    const td_api::Update *update;
  };

  enum class SyncState : int32 { NotSynced, Pending, Completed };

  using NotificationGroups = std::map<NotificationGroupKey, NotificationGroup>;

  static void on_flush_pending_notifications_timeout_callback(void *notification_manager_ptr, int64 group_id_int);

  static void on_flush_pending_updates_timeout_callback(void *notification_manager_ptr, int64 group_id_int);

  bool is_disabled() const;

  void start_up() final;
  void tear_down() final;

  void add_update(int32 group_id, td_api::object_ptr<td_api::Update> update);

  void add_update_notification_group(td_api::object_ptr<td_api::updateNotificationGroup> update);

  void add_update_notification(NotificationGroupId notification_group_id, DialogId dialog_id,
                               const Notification &notification);

  NotificationGroups::iterator add_group(NotificationGroupKey &&group_key, NotificationGroup &&group,
                                         const char *source);

  NotificationGroups::iterator get_group(NotificationGroupId group_id);

  NotificationGroups::iterator get_group_force(NotificationGroupId group_id, bool send_update = true);

  void delete_group(NotificationGroups::iterator &&group_it);

  static NotificationId get_first_notification_id(const NotificationGroup &group);

  static NotificationId get_last_notification_id(const NotificationGroup &group);

  static NotificationObjectId get_first_object_id(const NotificationGroup &group);

  static NotificationObjectId get_last_object_id(const NotificationGroup &group);

  static NotificationObjectId get_last_object_id_by_notification_id(const NotificationGroup &group,
                                                                    NotificationId max_notification_id);

  static int32 get_temporary_notification_total_count(const NotificationGroup &group);

  int32 load_message_notification_groups_from_database(int32 limit, bool send_update);

  void load_notifications_from_database(const NotificationGroupKey &group_key, NotificationGroup &group,
                                        size_t desired_size);

  void on_get_notifications_from_database(NotificationGroupId group_id, size_t limit,
                                          Result<vector<Notification>> r_notifications);

  void add_notifications_to_group_begin(NotificationGroups::iterator group_it, vector<Notification> notifications);

  NotificationGroupKey get_last_updated_group_key() const;

  void try_send_update_active_notifications();

  void send_update_have_pending_notifications() const;

  td_api::object_ptr<td_api::updateHavePendingNotifications> get_update_have_pending_notifications() const;

  td_api::object_ptr<td_api::updateActiveNotifications> get_update_active_notifications() const;

  td_api::object_ptr<td_api::updateNotificationGroup> get_remove_group_update(
      const NotificationGroupKey &group_key, const NotificationGroup &group,
      vector<int32> &&removed_notification_ids) const;

  void send_remove_group_update(const NotificationGroupKey &group_key, const NotificationGroup &group,
                                vector<int32> &&removed_notification_ids);

  void send_add_group_update(const NotificationGroupKey &group_key, const NotificationGroup &group, const char *source);

  int32 get_notification_delay_ms(DialogId dialog_id, const PendingNotification &notification,
                                  int32 min_delay_ms) const;

  bool do_flush_pending_notifications(NotificationGroupKey &group_key, NotificationGroup &group,
                                      vector<PendingNotification> &pending_notifications) TD_WARN_UNUSED_RESULT;

  void flush_pending_notifications(NotificationGroupId group_id);

  void flush_all_pending_notifications();

  void on_notification_processed(NotificationId notification_id);

  void on_notification_removed(NotificationId notification_id);

  void on_notifications_removed(NotificationGroups::iterator &&group_it,
                                vector<td_api::object_ptr<td_api::notification>> &&added_notifications,
                                vector<int32> &&removed_notification_ids, bool force_update);

  void remove_added_notifications_from_pending_updates(
      NotificationGroupId group_id,
      const std::function<bool(const td_api::object_ptr<td_api::notification> &notification)> &is_removed);

  void flush_pending_updates(int32 group_id, const char *source);

  void force_flush_pending_updates(NotificationGroupId group_id, const char *source);

  void flush_all_pending_updates(bool include_delayed_chats, const char *source);

  NotificationGroupId get_call_notification_group_id(DialogId dialog_id);

  static Result<string> decrypt_push_payload(int64 encryption_key_id, string encryption_key, string payload);

  static string convert_loc_key(const string &loc_key);

  void add_push_notification_user(UserId sender_user_id, int64 sender_access_hash, const string &sender_name,
                                  telegram_api::object_ptr<telegram_api::UserProfilePhoto> &&sender_photo);

  Status parse_push_notification_attach(DialogId dialog_id, string &loc_key, JsonObject &custom, Photo &attached_photo,
                                        Document &attached_document);

  Status process_push_notification_payload(string payload, bool was_encrypted, Promise<Unit> &promise);

  void add_message_push_notification(DialogId dialog_id, MessageId message_id, int64 random_id, UserId sender_user_id,
                                     DialogId sender_dialog_id, string sender_name, int32 date, bool is_from_scheduled,
                                     bool contains_mention, bool disable_notification, int64 ringtone_id,
                                     string loc_key, string arg, Photo photo, Document document,
                                     NotificationId notification_id, uint64 log_event_id, Promise<Unit> promise);

  void edit_message_push_notification(DialogId dialog_id, MessageId message_id, int32 edit_date, string loc_key,
                                      string arg, Photo photo, Document document, uint64 log_event_id,
                                      Promise<Unit> promise);

  void after_get_difference_impl();

  void after_get_chat_difference_impl(NotificationGroupId group_id);

  void on_delayed_notification_update_count_changed(int32 diff, int32 notification_group_id, const char *source);

  void on_unreceived_notification_update_count_changed(int32 diff, int32 notification_group_id, const char *source);

  static string get_is_contact_registered_notifications_synchronized_key();

  void set_contact_registered_notifications_sync_state(SyncState new_state);

  void run_contact_registered_notifications_sync();

  void on_contact_registered_notifications_sync(bool is_disabled, Result<Unit> result);

  void on_get_disable_contact_registered_notifications(bool is_disabled, Promise<Unit> &&promise);

  void save_announcement_ids();

  static ActiveNotificationsUpdate as_active_notifications_update(const td_api::updateActiveNotifications *update);

  static NotificationUpdate as_notification_update(const td_api::Update *update);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ActiveNotificationsUpdate &update);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const NotificationUpdate &update);

  NotificationId current_notification_id_;
  NotificationGroupId current_notification_group_id_;

  size_t max_notification_group_count_ = 0;
  size_t max_notification_group_size_ = 0;
  size_t keep_notification_group_size_ = 0;

  int32 online_cloud_timeout_ms_ = DEFAULT_ONLINE_CLOUD_TIMEOUT_MS;
  int32 notification_cloud_delay_ms_ = DEFAULT_ONLINE_CLOUD_DELAY_MS;
  int32 notification_default_delay_ms_ = DEFAULT_DEFAULT_DELAY_MS;

  int32 delayed_notification_update_count_ = 0;
  int32 unreceived_notification_update_count_ = 0;

  NotificationGroupKey last_loaded_notification_group_key_;

  SyncState contact_registered_notifications_sync_state_ = SyncState::NotSynced;
  bool disable_contact_registered_notifications_ = false;

  bool is_being_destroyed_ = false;
  bool is_destroyed_ = false;

  bool is_inited_ = false;
  bool is_binlog_processed_ = false;

  bool running_get_difference_ = false;
  FlatHashSet<int32> running_get_chat_difference_;

  NotificationGroups groups_;
  FlatHashMap<NotificationGroupId, NotificationGroupKey, NotificationGroupIdHash> group_keys_;

  FlatHashMap<int32, vector<td_api::object_ptr<td_api::Update>>> pending_updates_;

  MultiTimeout flush_pending_notifications_timeout_{"FlushPendingNotificationsTimeout"};
  MultiTimeout flush_pending_updates_timeout_{"FlushPendingUpdatesTimeout"};

  vector<NotificationGroupId> call_notification_group_ids_;
  FlatHashSet<NotificationGroupId, NotificationGroupIdHash> available_call_notification_group_ids_;
  FlatHashMap<DialogId, NotificationGroupId, DialogIdHash> dialog_id_to_call_notification_group_id_;

  FlatHashMap<NotificationId, uint64, NotificationIdHash> temporary_notification_log_event_ids_;
  FlatHashMap<NotificationId, uint64, NotificationIdHash> temporary_edit_notification_log_event_ids_;
  struct TemporaryNotification {
    NotificationGroupId group_id;
    NotificationId notification_id;
    UserId sender_user_id;
    DialogId sender_dialog_id;
    string sender_name;
    bool is_outgoing;
  };
  FlatHashMap<NotificationObjectFullId, TemporaryNotification, NotificationObjectFullIdHash> temporary_notifications_;
  FlatHashMap<NotificationId, NotificationObjectFullId, NotificationIdHash> temporary_notification_object_ids_;
  FlatHashMap<NotificationId, vector<Promise<Unit>>, NotificationIdHash> push_notification_promises_;

  struct ActiveCallNotification {
    CallId call_id;
    NotificationId notification_id;
  };
  FlatHashMap<DialogId, vector<ActiveCallNotification>, DialogIdHash> active_call_notifications_;

  FlatHashMap<int32, int32> announcement_id_date_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
