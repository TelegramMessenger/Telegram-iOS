//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/DialogNotificationSettings.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/NotificationSettingsScope.h"
#include "td/telegram/ReactionNotificationSettings.h"
#include "td/telegram/ScopeNotificationSettings.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <memory>
#include <utility>

namespace td {

struct BinlogEvent;

class NotificationSound;

class Td;

class NotificationSettingsManager final : public Actor {
 public:
  NotificationSettingsManager(Td *td, ActorShared<> parent);
  NotificationSettingsManager(const NotificationSettingsManager &) = delete;
  NotificationSettingsManager &operator=(const NotificationSettingsManager &) = delete;
  NotificationSettingsManager(NotificationSettingsManager &&) = delete;
  NotificationSettingsManager &operator=(NotificationSettingsManager &&) = delete;
  ~NotificationSettingsManager() final;

  int32 get_scope_mute_until(NotificationSettingsScope scope) const;

  std::pair<bool, bool> get_scope_mute_stories(NotificationSettingsScope scope) const;

  const unique_ptr<NotificationSound> &get_scope_notification_sound(NotificationSettingsScope scope) const;

  const unique_ptr<NotificationSound> &get_scope_story_notification_sound(NotificationSettingsScope scope) const;

  bool get_scope_show_preview(NotificationSettingsScope scope) const;

  bool get_scope_hide_story_sender(NotificationSettingsScope scope) const;

  bool get_scope_disable_pinned_message_notifications(NotificationSettingsScope scope) const;

  bool get_scope_disable_mention_notifications(NotificationSettingsScope scope) const;

  tl_object_ptr<telegram_api::InputNotifyPeer> get_input_notify_peer(DialogId dialog_id,
                                                                     MessageId top_thread_message_id) const;

  void on_update_scope_notify_settings(NotificationSettingsScope scope,
                                       tl_object_ptr<telegram_api::peerNotifySettings> &&peer_notify_settings);

  void on_update_reaction_notification_settings(ReactionNotificationSettings reaction_notification_settings);

  void add_saved_ringtone(td_api::object_ptr<td_api::InputFile> &&input_file,
                          Promise<td_api::object_ptr<td_api::notificationSound>> &&promise);

  FileId get_saved_ringtone(int64 ringtone_id, Promise<Unit> &&promise);

  vector<FileId> get_saved_ringtones(Promise<Unit> &&promise);

  void remove_saved_ringtone(int64 ringtone_id, Promise<Unit> &&promise);

  void reload_saved_ringtones(Promise<Unit> &&promise);

  void repair_saved_ringtones(Promise<Unit> &&promise);

  FileSourceId get_saved_ringtones_file_source_id();

  void send_save_ringtone_query(FileId ringtone_file_id, bool unsave,
                                Promise<telegram_api::object_ptr<telegram_api::account_SavedRingtone>> &&promise);

  void send_get_dialog_notification_settings_query(DialogId dialog_id, MessageId top_thread_message_id,
                                                   Promise<Unit> &&promise);

  const ScopeNotificationSettings *get_scope_notification_settings(NotificationSettingsScope scope,
                                                                   Promise<Unit> &&promise);
  void send_get_scope_notification_settings_query(NotificationSettingsScope scope, Promise<Unit> &&promise);

  void send_get_reaction_notification_settings_query(Promise<Unit> &&promise);

  void on_get_dialog_notification_settings_query_finished(DialogId dialog_id, MessageId top_thread_message_id,
                                                          Status &&status);

  void update_dialog_notify_settings(DialogId dialog_id, MessageId top_thread_message_id,
                                     const DialogNotificationSettings &new_settings, Promise<Unit> &&promise);

  Status set_scope_notification_settings(NotificationSettingsScope scope,
                                         td_api::object_ptr<td_api::scopeNotificationSettings> &&notification_settings)
      TD_WARN_UNUSED_RESULT;

  Status set_reaction_notification_settings(ReactionNotificationSettings &&notification_settings) TD_WARN_UNUSED_RESULT;

  void reset_all_notification_settings();

  void get_notify_settings_exceptions(NotificationSettingsScope scope, bool filter_scope, bool compare_sound,
                                      Promise<Unit> &&promise);

  void get_story_notification_settings_exceptions(Promise<td_api::object_ptr<td_api::chats>> &&promise);

  void init();

  void on_binlog_events(vector<BinlogEvent> &&events);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  class ResetAllNotificationSettingsOnServerLogEvent;
  class UpdateScopeNotificationSettingsOnServerLogEvent;
  class UpdateReactionNotificationSettingsOnServerLogEvent;

  class RingtoneListLogEvent;

  class UploadRingtoneCallback;

  void start_up() final;

  void tear_down() final;

  void timeout_expired() final;

  bool is_active() const;

  static void on_scope_unmute_timeout_callback(void *notification_settings_manager_ptr, int64 scope_int);

  Result<FileId> get_ringtone(telegram_api::object_ptr<telegram_api::Document> &&ringtone) const;

  void upload_ringtone(FileUploadId file_upload_id, bool is_reupload,
                       Promise<td_api::object_ptr<td_api::notificationSound>> &&promise, vector<int> bad_parts = {});

  void on_upload_ringtone(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_ringtone_error(FileUploadId file_upload_id, Status status);

  void on_upload_saved_ringtone(telegram_api::object_ptr<telegram_api::Document> &&saved_ringtone,
                                Promise<td_api::object_ptr<td_api::notificationSound>> &&promise);

  void on_add_saved_ringtone(FileId file_id,
                             telegram_api::object_ptr<telegram_api::account_SavedRingtone> &&saved_ringtone,
                             Promise<td_api::object_ptr<td_api::notificationSound>> &&promise);

  void on_remove_saved_ringtone(int64 ringtone_id, Promise<Unit> &&promise);

  void on_reload_saved_ringtones(bool is_repair,
                                 Result<telegram_api::object_ptr<telegram_api::account_SavedRingtones>> &&result);

  static string get_saved_ringtones_database_key();

  void load_saved_ringtones(Promise<Unit> &&promise);

  void on_load_saved_ringtones(Promise<Unit> &&promise);

  void save_saved_ringtones_to_database() const;

  void on_saved_ringtones_updated(bool from_database);

  ScopeNotificationSettings *get_scope_notification_settings(NotificationSettingsScope scope);

  const ScopeNotificationSettings *get_scope_notification_settings(NotificationSettingsScope scope) const;

  td_api::object_ptr<td_api::updateScopeNotificationSettings> get_update_scope_notification_settings_object(
      NotificationSettingsScope scope) const;

  td_api::object_ptr<td_api::updateReactionNotificationSettings> get_update_reaction_notification_settings_object()
      const;

  td_api::object_ptr<td_api::updateSavedNotificationSounds> get_update_saved_notification_sounds_object() const;

  void on_scope_unmute(NotificationSettingsScope scope);

  static string get_notification_settings_scope_database_key(NotificationSettingsScope scope);

  static void save_scope_notification_settings(NotificationSettingsScope scope,
                                               const ScopeNotificationSettings &new_settings);

  bool update_scope_notification_settings(NotificationSettingsScope scope, ScopeNotificationSettings *current_settings,
                                          ScopeNotificationSettings &&new_settings);

  static uint64 save_update_scope_notification_settings_on_server_log_event(NotificationSettingsScope scope);

  void update_scope_notification_settings_on_server(NotificationSettingsScope scope, uint64 log_event_id);

  void schedule_scope_unmute(NotificationSettingsScope scope, int32 mute_until, int32 unix_time);

  void update_scope_unmute_timeout(NotificationSettingsScope scope, int32 &old_mute_until, int32 new_mute_until);

  static string get_reaction_notification_settings_database_key();

  void save_reaction_notification_settings() const;

  uint64 save_update_reaction_notification_settings_on_server_log_event();

  void update_reaction_notification_settings_on_server(uint64 log_event_id);

  void reset_scope_notification_settings();

  void reset_all_notification_settings_on_server(uint64 log_event_id);

  static uint64 save_reset_all_notification_settings_on_server_log_event();

  Td *td_;
  ActorShared<> parent_;

  bool is_inited_ = false;
  bool are_saved_ringtones_loaded_ = false;
  bool are_saved_ringtones_reloaded_ = false;

  ScopeNotificationSettings users_notification_settings_;
  ScopeNotificationSettings chats_notification_settings_;
  ScopeNotificationSettings channels_notification_settings_;

  ReactionNotificationSettings reaction_notification_settings_;
  bool have_reaction_notification_settings_ = false;

  MultiTimeout scope_unmute_timeout_{"ScopeUnmuteTimeout"};

  int64 saved_ringtone_hash_ = 0;
  vector<FileId> saved_ringtone_file_ids_;
  vector<FileId> sorted_saved_ringtone_file_ids_;
  FileSourceId saved_ringtones_file_source_id_;

  std::shared_ptr<UploadRingtoneCallback> upload_ringtone_callback_;

  struct UploadedRingtone {
    bool is_reupload;
    Promise<td_api::object_ptr<td_api::notificationSound>> promise;

    UploadedRingtone(bool is_reupload, Promise<td_api::object_ptr<td_api::notificationSound>> promise)
        : is_reupload(is_reupload), promise(std::move(promise)) {
    }
  };
  FlatHashMap<FileUploadId, UploadedRingtone, FileUploadIdHash> being_uploaded_ringtones_;

  vector<Promise<Unit>> reload_saved_ringtones_queries_;
  vector<Promise<Unit>> repair_saved_ringtones_queries_;

  FlatHashMap<MessageFullId, vector<Promise<Unit>>, MessageFullIdHash> get_dialog_notification_settings_queries_;
};

}  // namespace td
