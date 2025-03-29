//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/NotificationSettingsManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AudiosManager.h"
#include "td/telegram/AudiosManager.hpp"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/ForumTopicManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/NotificationSound.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/ReactionNotificationSettings.hpp"
#include "td/telegram/ScopeNotificationSettings.hpp"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/VoiceNotesManager.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/MimeType.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/Random.h"
#include "td/utils/tl_helpers.h"

#include <algorithm>

namespace td {

class UploadRingtoneQuery final : public Td::ResultHandler {
  FileUploadId file_upload_id_;
  Promise<telegram_api::object_ptr<telegram_api::Document>> promise_;

 public:
  explicit UploadRingtoneQuery(Promise<telegram_api::object_ptr<telegram_api::Document>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
            const string &file_name, const string &mime_type) {
    CHECK(input_file != nullptr);
    file_upload_id_ = file_upload_id;

    send_query(G()->net_query_creator().create(
        telegram_api::account_uploadRingtone(std::move(input_file), file_name, mime_type), {{"ringtone"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_uploadRingtone>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for UploadRingtoneQuery: " << to_string(result);
    promise_.set_value(std::move(result));

    td_->file_manager_->delete_partial_remote_location(file_upload_id_);
  }

  void on_error(Status status) final {
    if (FileReferenceManager::is_file_reference_error(status)) {
      LOG(ERROR) << "Receive file reference error " << status;
    }
    auto bad_parts = FileManager::get_missing_file_parts(status);
    if (!bad_parts.empty()) {
      // TODO reupload the file
    }

    td_->file_manager_->delete_partial_remote_location(file_upload_id_);
    td_->notification_settings_manager_->reload_saved_ringtones(Auto());
    promise_.set_error(std::move(status));
  }
};

class SaveRingtoneQuery final : public Td::ResultHandler {
  FileId file_id_;
  string file_reference_;
  bool unsave_ = false;

  Promise<telegram_api::object_ptr<telegram_api::account_SavedRingtone>> promise_;

 public:
  explicit SaveRingtoneQuery(Promise<telegram_api::object_ptr<telegram_api::account_SavedRingtone>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(FileId file_id, tl_object_ptr<telegram_api::inputDocument> &&input_document, bool unsave) {
    CHECK(input_document != nullptr);
    CHECK(file_id.is_valid());
    file_id_ = file_id;
    file_reference_ = input_document->file_reference_.as_slice().str();
    unsave_ = unsave;

    send_query(G()->net_query_creator().create(telegram_api::account_saveRingtone(std::move(input_document), unsave),
                                               {{"ringtone"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_saveRingtone>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SaveRingtoneQuery: " << to_string(result);
    promise_.set_value(std::move(result));
  }

  void on_error(Status status) final {
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      VLOG(file_references) << "Receive " << status << " for " << file_id_;
      td_->file_manager_->delete_file_reference(file_id_, file_reference_);
      td_->file_reference_manager_->repair_file_reference(
          file_id_, PromiseCreator::lambda([ringtone_id = file_id_, unsave = unsave_,
                                            promise = std::move(promise_)](Result<Unit> result) mutable {
            if (result.is_error()) {
              return promise.set_error(Status::Error(400, "Failed to find the ringtone"));
            }

            send_closure(G()->notification_settings_manager(), &NotificationSettingsManager::send_save_ringtone_query,
                         ringtone_id, unsave, std::move(promise));
          }));
      return;
    }

    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for SaveRingtoneQuery: " << status;
    }
    td_->notification_settings_manager_->reload_saved_ringtones(Auto());
    promise_.set_error(std::move(status));
  }
};

class GetSavedRingtonesQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::account_SavedRingtones>> promise_;

 public:
  explicit GetSavedRingtonesQuery(Promise<telegram_api::object_ptr<telegram_api::account_SavedRingtones>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int64 hash) {
    send_query(G()->net_query_creator().create(telegram_api::account_getSavedRingtones(hash), {{"ringtone"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getSavedRingtones>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetSavedRingtonesQuery: " << to_string(ptr);

    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetDialogNotifySettingsQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  MessageId top_thread_message_id_;

 public:
  void send(DialogId dialog_id, MessageId top_thread_message_id) {
    dialog_id_ = dialog_id;
    top_thread_message_id_ = top_thread_message_id;
    auto input_notify_peer =
        td_->notification_settings_manager_->get_input_notify_peer(dialog_id, top_thread_message_id);
    CHECK(input_notify_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::account_getNotifySettings(std::move(input_notify_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getNotifySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    if (top_thread_message_id_.is_valid()) {
      td_->forum_topic_manager_->on_update_forum_topic_notify_settings(dialog_id_, top_thread_message_id_,
                                                                       std::move(ptr), "GetDialogNotifySettingsQuery");
    } else {
      td_->messages_manager_->on_update_dialog_notify_settings(dialog_id_, std::move(ptr),
                                                               "GetDialogNotifySettingsQuery");
    }
    td_->notification_settings_manager_->on_get_dialog_notification_settings_query_finished(
        dialog_id_, top_thread_message_id_, Status::OK());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetDialogNotifySettingsQuery");
    td_->notification_settings_manager_->on_get_dialog_notification_settings_query_finished(
        dialog_id_, top_thread_message_id_, std::move(status));
  }
};

class GetNotifySettingsExceptionsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetNotifySettingsExceptionsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(NotificationSettingsScope scope, bool filter_scope, bool compare_sound) {
    int32 flags = 0;
    tl_object_ptr<telegram_api::InputNotifyPeer> input_notify_peer;
    if (filter_scope) {
      flags |= telegram_api::account_getNotifyExceptions::PEER_MASK;
      input_notify_peer = get_input_notify_peer(scope);
    }
    if (compare_sound) {
      flags |= telegram_api::account_getNotifyExceptions::COMPARE_SOUND_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::account_getNotifyExceptions(
        flags, false /*ignored*/, false /*ignored*/, std::move(input_notify_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getNotifyExceptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto updates_ptr = result_ptr.move_as_ok();
    auto dialog_ids = UpdatesManager::get_update_notify_settings_dialog_ids(updates_ptr.get());
    vector<tl_object_ptr<telegram_api::User>> users;
    vector<tl_object_ptr<telegram_api::Chat>> chats;
    switch (updates_ptr->get_id()) {
      case telegram_api::updatesCombined::ID: {
        auto updates = static_cast<telegram_api::updatesCombined *>(updates_ptr.get());
        users = std::move(updates->users_);
        chats = std::move(updates->chats_);
        reset_to_empty(updates->users_);
        reset_to_empty(updates->chats_);
        break;
      }
      case telegram_api::updates::ID: {
        auto updates = static_cast<telegram_api::updates *>(updates_ptr.get());
        users = std::move(updates->users_);
        chats = std::move(updates->chats_);
        reset_to_empty(updates->users_);
        reset_to_empty(updates->chats_);
        break;
      }
    }
    td_->user_manager_->on_get_users(std::move(users), "GetNotifySettingsExceptionsQuery");
    td_->chat_manager_->on_get_chats(std::move(chats), "GetNotifySettingsExceptionsQuery");
    for (auto &dialog_id : dialog_ids) {
      td_->dialog_manager_->force_create_dialog(dialog_id, "GetNotifySettingsExceptionsQuery");
    }
    td_->updates_manager_->on_get_updates(std::move(updates_ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetStoryNotifySettingsExceptionsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::chats>> promise_;

 public:
  explicit GetStoryNotifySettingsExceptionsQuery(Promise<td_api::object_ptr<td_api::chats>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    int32 flags = telegram_api::account_getNotifyExceptions::COMPARE_STORIES_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::account_getNotifyExceptions(flags, false /*ignored*/, false /*ignored*/, nullptr)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getNotifyExceptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto updates_ptr = result_ptr.move_as_ok();
    auto dialog_ids = UpdatesManager::get_update_notify_settings_dialog_ids(updates_ptr.get());
    vector<tl_object_ptr<telegram_api::User>> users;
    vector<tl_object_ptr<telegram_api::Chat>> chats;
    switch (updates_ptr->get_id()) {
      case telegram_api::updatesCombined::ID: {
        auto updates = static_cast<telegram_api::updatesCombined *>(updates_ptr.get());
        users = std::move(updates->users_);
        chats = std::move(updates->chats_);
        reset_to_empty(updates->users_);
        reset_to_empty(updates->chats_);
        break;
      }
      case telegram_api::updates::ID: {
        auto updates = static_cast<telegram_api::updates *>(updates_ptr.get());
        users = std::move(updates->users_);
        chats = std::move(updates->chats_);
        reset_to_empty(updates->users_);
        reset_to_empty(updates->chats_);
        break;
      }
    }
    td_->user_manager_->on_get_users(std::move(users), "GetStoryNotifySettingsExceptionsQuery");
    td_->chat_manager_->on_get_chats(std::move(chats), "GetStoryNotifySettingsExceptionsQuery");
    for (auto &dialog_id : dialog_ids) {
      td_->dialog_manager_->force_create_dialog(dialog_id, "GetStoryNotifySettingsExceptionsQuery");
    }
    auto chat_ids = td_->dialog_manager_->get_chats_object(-1, dialog_ids, "GetStoryNotifySettingsExceptionsQuery");
    auto promise = PromiseCreator::lambda([promise = std::move(promise_), chat_ids = std::move(chat_ids)](
                                              Result<Unit>) mutable { promise.set_value(std::move(chat_ids)); });
    td_->updates_manager_->on_get_updates(std::move(updates_ptr), std::move(promise));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetScopeNotifySettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  NotificationSettingsScope scope_;

 public:
  explicit GetScopeNotifySettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(NotificationSettingsScope scope) {
    scope_ = scope;
    auto input_notify_peer = get_input_notify_peer(scope);
    CHECK(input_notify_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::account_getNotifySettings(std::move(input_notify_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getNotifySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    td_->notification_settings_manager_->on_update_scope_notify_settings(scope_, std::move(ptr));

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetReactionsNotifySettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit GetReactionsNotifySettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getReactionsNotifySettings()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getReactionsNotifySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    td_->notification_settings_manager_->on_update_reaction_notification_settings(
        ReactionNotificationSettings(std::move(ptr)));
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UpdateDialogNotifySettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  MessageId top_thread_message_id_;

 public:
  explicit UpdateDialogNotifySettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId top_thread_message_id, const DialogNotificationSettings &new_settings) {
    dialog_id_ = dialog_id;
    top_thread_message_id_ = top_thread_message_id;

    auto input_notify_peer =
        td_->notification_settings_manager_->get_input_notify_peer(dialog_id, top_thread_message_id);
    if (input_notify_peer == nullptr) {
      return on_error(Status::Error(500, "Can't update chat notification settings"));
    }

    send_query(G()->net_query_creator().create(telegram_api::account_updateNotifySettings(
        std::move(input_notify_peer), new_settings.get_input_peer_notify_settings())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateNotifySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Receive false as result"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "UpdateDialogNotifySettingsQuery")) {
      LOG(INFO) << "Receive error for set chat notification settings: " << status;
    }

    if (!td_->auth_manager_->is_bot() &&
        td_->notification_settings_manager_->get_input_notify_peer(dialog_id_, top_thread_message_id_) != nullptr) {
      // trying to repair notification settings for this dialog
      td_->notification_settings_manager_->send_get_dialog_notification_settings_query(
          dialog_id_, top_thread_message_id_, Promise<>());
    }

    promise_.set_error(std::move(status));
  }
};

class UpdateScopeNotifySettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  NotificationSettingsScope scope_;

 public:
  explicit UpdateScopeNotifySettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(NotificationSettingsScope scope, const ScopeNotificationSettings &new_settings) {
    auto input_notify_peer = get_input_notify_peer(scope);
    CHECK(input_notify_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::account_updateNotifySettings(
        std::move(input_notify_peer), new_settings.get_input_peer_notify_settings())));
    scope_ = scope;
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_updateNotifySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Receive false as result"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for set notification settings: " << status;

    if (!td_->auth_manager_->is_bot()) {
      // trying to repair notification settings for this scope
      td_->notification_settings_manager_->send_get_scope_notification_settings_query(scope_, Promise<>());
    }

    promise_.set_error(std::move(status));
  }
};

class SetReactionsNotifySettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetReactionsNotifySettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(const ReactionNotificationSettings &settings) {
    send_query(G()->net_query_creator().create(
        telegram_api::account_setReactionsNotifySettings(settings.get_input_reactions_notify_settings())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_setReactionsNotifySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SetReactionsNotifySettingsQuery: " << to_string(ptr);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for set reaction notification settings: " << status;

    if (!td_->auth_manager_->is_bot()) {
      // trying to repair notification settings
      td_->notification_settings_manager_->send_get_reaction_notification_settings_query(Promise<>());
    }

    promise_.set_error(std::move(status));
  }
};

class ResetNotifySettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ResetNotifySettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_resetNotifySettings()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_resetNotifySettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Receive false as result"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for reset notification settings: " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class NotificationSettingsManager::UploadRingtoneCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->notification_settings_manager(), &NotificationSettingsManager::on_upload_ringtone,
                       file_upload_id, std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->notification_settings_manager(), &NotificationSettingsManager::on_upload_ringtone_error,
                       file_upload_id, std::move(error));
  }
};

class NotificationSettingsManager::RingtoneListLogEvent {
 public:
  int64 hash_;
  vector<FileId> ringtone_file_ids_;

  RingtoneListLogEvent() = default;

  RingtoneListLogEvent(int64 hash, vector<FileId> ringtone_file_ids)
      : hash_(hash), ringtone_file_ids_(std::move(ringtone_file_ids)) {
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(hash_, storer);
    AudiosManager *audios_manager = storer.context()->td().get_actor_unsafe()->audios_manager_.get();
    td::store(narrow_cast<int32>(ringtone_file_ids_.size()), storer);
    for (auto ringtone_file_id : ringtone_file_ids_) {
      audios_manager->store_audio(ringtone_file_id, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(hash_, parser);
    AudiosManager *audios_manager = parser.context()->td().get_actor_unsafe()->audios_manager_.get();
    int32 size = parser.fetch_int();
    ringtone_file_ids_.resize(size);
    for (auto &ringtone_file_id : ringtone_file_ids_) {
      ringtone_file_id = audios_manager->parse_audio(parser);
    }
  }
};

NotificationSettingsManager::NotificationSettingsManager(Td *td, ActorShared<> parent)
    : td_(td), parent_(std::move(parent)) {
  upload_ringtone_callback_ = std::make_shared<UploadRingtoneCallback>();

  scope_unmute_timeout_.set_callback(on_scope_unmute_timeout_callback);
  scope_unmute_timeout_.set_callback_data(static_cast<void *>(this));
}

NotificationSettingsManager::~NotificationSettingsManager() = default;

void NotificationSettingsManager::tear_down() {
  parent_.reset();
}

void NotificationSettingsManager::start_up() {
  init();
}

void NotificationSettingsManager::init() {
  if (is_inited_) {
    return;
  }
  is_inited_ = true;

  bool was_authorized_user = td_->auth_manager_->was_authorized() && !td_->auth_manager_->is_bot();
  if (was_authorized_user) {
    for (auto scope :
         {NotificationSettingsScope::Private, NotificationSettingsScope::Group, NotificationSettingsScope::Channel}) {
      auto notification_settings_string =
          G()->td_db()->get_binlog_pmc()->get(get_notification_settings_scope_database_key(scope));
      if (!notification_settings_string.empty()) {
        auto current_settings = get_scope_notification_settings(scope);
        CHECK(current_settings != nullptr);
        log_event_parse(*current_settings, notification_settings_string).ensure();

        VLOG(notifications) << "Loaded notification settings in " << scope << ": " << *current_settings;

        schedule_scope_unmute(scope, current_settings->mute_until, G()->unix_time());

        send_closure(G()->td(), &Td::send_update, get_update_scope_notification_settings_object(scope));
      }
    }
    auto reaction_notification_settings_string =
        G()->td_db()->get_binlog_pmc()->get(get_reaction_notification_settings_database_key());
    if (!reaction_notification_settings_string.empty()) {
      log_event_parse(reaction_notification_settings_, reaction_notification_settings_string).ensure();
      have_reaction_notification_settings_ = true;

      VLOG(notifications) << "Loaded reaction notification settings: " << reaction_notification_settings_;
    } else {
      send_get_reaction_notification_settings_query(Promise<Unit>());
    }
    send_closure(G()->td(), &Td::send_update, get_update_reaction_notification_settings_object());
  }
  G()->td_db()->get_binlog_pmc()->erase("nsfac");
}

void NotificationSettingsManager::on_scope_unmute_timeout_callback(void *notification_settings_manager_ptr,
                                                                   int64 scope_int) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(1 <= scope_int && scope_int <= 3);
  auto notification_settings_manager = static_cast<NotificationSettingsManager *>(notification_settings_manager_ptr);
  send_closure_later(notification_settings_manager->actor_id(notification_settings_manager),
                     &NotificationSettingsManager::on_scope_unmute,
                     static_cast<NotificationSettingsScope>(scope_int - 1));
}

void NotificationSettingsManager::timeout_expired() {
  reload_saved_ringtones(Promise<Unit>());
}

int32 NotificationSettingsManager::get_scope_mute_until(NotificationSettingsScope scope) const {
  return get_scope_notification_settings(scope)->mute_until;
}

std::pair<bool, bool> NotificationSettingsManager::get_scope_mute_stories(NotificationSettingsScope scope) const {
  auto *settings = get_scope_notification_settings(scope);
  return {settings->use_default_mute_stories, settings->mute_stories};
}

const unique_ptr<NotificationSound> &NotificationSettingsManager::get_scope_notification_sound(
    NotificationSettingsScope scope) const {
  return get_scope_notification_settings(scope)->sound;
}

const unique_ptr<NotificationSound> &NotificationSettingsManager::get_scope_story_notification_sound(
    NotificationSettingsScope scope) const {
  return get_scope_notification_settings(scope)->story_sound;
}

bool NotificationSettingsManager::get_scope_show_preview(NotificationSettingsScope scope) const {
  return get_scope_notification_settings(scope)->show_preview;
}

bool NotificationSettingsManager::get_scope_hide_story_sender(NotificationSettingsScope scope) const {
  return get_scope_notification_settings(scope)->hide_story_sender;
}

bool NotificationSettingsManager::get_scope_disable_pinned_message_notifications(
    NotificationSettingsScope scope) const {
  return get_scope_notification_settings(scope)->disable_pinned_message_notifications;
}

bool NotificationSettingsManager::get_scope_disable_mention_notifications(NotificationSettingsScope scope) const {
  return get_scope_notification_settings(scope)->disable_mention_notifications;
}

tl_object_ptr<telegram_api::InputNotifyPeer> NotificationSettingsManager::get_input_notify_peer(
    DialogId dialog_id, MessageId top_thread_message_id) const {
  if (!td_->messages_manager_->have_dialog(dialog_id)) {
    return nullptr;
  }
  auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
  if (input_peer == nullptr) {
    return nullptr;
  }
  if (top_thread_message_id.is_valid()) {
    CHECK(top_thread_message_id.is_server());
    return telegram_api::make_object<telegram_api::inputNotifyForumTopic>(
        std::move(input_peer), top_thread_message_id.get_server_message_id().get());
  }
  return make_tl_object<telegram_api::inputNotifyPeer>(std::move(input_peer));
}

ScopeNotificationSettings *NotificationSettingsManager::get_scope_notification_settings(
    NotificationSettingsScope scope) {
  switch (scope) {
    case NotificationSettingsScope::Private:
      return &users_notification_settings_;
    case NotificationSettingsScope::Group:
      return &chats_notification_settings_;
    case NotificationSettingsScope::Channel:
      return &channels_notification_settings_;
    default:
      UNREACHABLE();
      return nullptr;
  }
}

const ScopeNotificationSettings *NotificationSettingsManager::get_scope_notification_settings(
    NotificationSettingsScope scope) const {
  switch (scope) {
    case NotificationSettingsScope::Private:
      return &users_notification_settings_;
    case NotificationSettingsScope::Group:
      return &chats_notification_settings_;
    case NotificationSettingsScope::Channel:
      return &channels_notification_settings_;
    default:
      UNREACHABLE();
      return nullptr;
  }
}

td_api::object_ptr<td_api::updateScopeNotificationSettings>
NotificationSettingsManager::get_update_scope_notification_settings_object(NotificationSettingsScope scope) const {
  auto notification_settings = get_scope_notification_settings(scope);
  CHECK(notification_settings != nullptr);
  return td_api::make_object<td_api::updateScopeNotificationSettings>(
      get_notification_settings_scope_object(scope), get_scope_notification_settings_object(notification_settings));
}

td_api::object_ptr<td_api::updateReactionNotificationSettings>
NotificationSettingsManager::get_update_reaction_notification_settings_object() const {
  return td_api::make_object<td_api::updateReactionNotificationSettings>(
      reaction_notification_settings_.get_reaction_notification_settings_object());
}

void NotificationSettingsManager::on_scope_unmute(NotificationSettingsScope scope) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return;
  }

  auto notification_settings = get_scope_notification_settings(scope);
  CHECK(notification_settings != nullptr);

  if (notification_settings->mute_until == 0) {
    return;
  }

  auto unix_time = G()->unix_time();
  if (notification_settings->mute_until > unix_time) {
    LOG(INFO) << "Failed to unmute " << scope << " in " << unix_time << ", will be unmuted in "
              << notification_settings->mute_until;
    schedule_scope_unmute(scope, notification_settings->mute_until, unix_time);
    return;
  }

  LOG(INFO) << "Unmute " << scope;
  update_scope_unmute_timeout(scope, notification_settings->mute_until, 0);
  send_closure(G()->td(), &Td::send_update, get_update_scope_notification_settings_object(scope));
  save_scope_notification_settings(scope, *notification_settings);
}

string NotificationSettingsManager::get_notification_settings_scope_database_key(NotificationSettingsScope scope) {
  switch (scope) {
    case NotificationSettingsScope::Private:
      return "nsfpc";
    case NotificationSettingsScope::Group:
      return "nsfgc";
    case NotificationSettingsScope::Channel:
      return "nsfcc";
    default:
      UNREACHABLE();
      return "";
  }
}

void NotificationSettingsManager::save_scope_notification_settings(NotificationSettingsScope scope,
                                                                   const ScopeNotificationSettings &new_settings) {
  string key = get_notification_settings_scope_database_key(scope);
  G()->td_db()->get_binlog_pmc()->set(key, log_event_store(new_settings).as_slice().str());
}

void NotificationSettingsManager::on_update_scope_notify_settings(
    NotificationSettingsScope scope, tl_object_ptr<telegram_api::peerNotifySettings> &&peer_notify_settings) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  auto old_notification_settings = get_scope_notification_settings(scope);
  CHECK(old_notification_settings != nullptr);

  ScopeNotificationSettings notification_settings = ::td::get_scope_notification_settings(
      std::move(peer_notify_settings), old_notification_settings->disable_pinned_message_notifications,
      old_notification_settings->disable_mention_notifications);
  if (!notification_settings.is_synchronized) {
    return;
  }

  update_scope_notification_settings(scope, old_notification_settings, std::move(notification_settings));
}

bool NotificationSettingsManager::update_scope_notification_settings(NotificationSettingsScope scope,
                                                                     ScopeNotificationSettings *current_settings,
                                                                     ScopeNotificationSettings &&new_settings) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return false;
  }

  bool need_update_server = current_settings->mute_until != new_settings.mute_until ||
                            !are_equivalent_notification_sounds(current_settings->sound, new_settings.sound) ||
                            current_settings->show_preview != new_settings.show_preview;
  bool need_update_local =
      current_settings->disable_pinned_message_notifications != new_settings.disable_pinned_message_notifications ||
      current_settings->disable_mention_notifications != new_settings.disable_mention_notifications;
  bool was_inited = current_settings->is_synchronized;
  bool is_inited = new_settings.is_synchronized;
  if (was_inited && !is_inited) {
    return false;  // just in case
  }
  bool is_changed = need_update_server || need_update_local || was_inited != is_inited ||
                    are_different_equivalent_notification_sounds(current_settings->sound, new_settings.sound);
  if (is_changed) {
    save_scope_notification_settings(scope, new_settings);

    VLOG(notifications) << "Update notification settings in " << scope << " from " << *current_settings << " to "
                        << new_settings;

    update_scope_unmute_timeout(scope, current_settings->mute_until, new_settings.mute_until);

    if (!current_settings->disable_pinned_message_notifications && new_settings.disable_pinned_message_notifications) {
      td_->messages_manager_->remove_scope_pinned_message_notifications(scope);
    }
    if (current_settings->disable_mention_notifications != new_settings.disable_mention_notifications) {
      td_->messages_manager_->on_update_scope_mention_notifications(scope, new_settings.disable_mention_notifications);
    }

    *current_settings = std::move(new_settings);

    send_closure(G()->td(), &Td::send_update, get_update_scope_notification_settings_object(scope));
  }
  return need_update_server;
}

void NotificationSettingsManager::send_get_reaction_notification_settings_query(Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    LOG(ERROR) << "Can't get reaction notification settings";
    return promise.set_error(Status::Error(500, "Wrong getReactionNotificationSettings query"));
  }

  td_->create_handler<GetReactionsNotifySettingsQuery>(std::move(promise))->send();
}

void NotificationSettingsManager::on_update_reaction_notification_settings(
    ReactionNotificationSettings reaction_notification_settings) {
  CHECK(!td_->auth_manager_->is_bot());
  if (reaction_notification_settings == reaction_notification_settings_) {
    if (!have_reaction_notification_settings_) {
      have_reaction_notification_settings_ = true;
      save_reaction_notification_settings();
    }
    return;
  }

  VLOG(notifications) << "Update reaction notification settings from " << reaction_notification_settings_ << " to "
                      << reaction_notification_settings;

  reaction_notification_settings_ = std::move(reaction_notification_settings);
  have_reaction_notification_settings_ = true;

  save_reaction_notification_settings();

  send_closure(G()->td(), &Td::send_update, get_update_reaction_notification_settings_object());
}

string NotificationSettingsManager::get_reaction_notification_settings_database_key() {
  return "rns";
}

void NotificationSettingsManager::save_reaction_notification_settings() const {
  string key = get_reaction_notification_settings_database_key();
  G()->td_db()->get_binlog_pmc()->set(key, log_event_store(reaction_notification_settings_).as_slice().str());
}

void NotificationSettingsManager::schedule_scope_unmute(NotificationSettingsScope scope, int32 mute_until,
                                                        int32 unix_time) {
  if (mute_until >= unix_time && mute_until < unix_time + 366 * 86400) {
    scope_unmute_timeout_.set_timeout_in(static_cast<int64>(scope) + 1, mute_until - unix_time + 1);
  } else {
    scope_unmute_timeout_.cancel_timeout(static_cast<int64>(scope) + 1);
  }
}

void NotificationSettingsManager::update_scope_unmute_timeout(NotificationSettingsScope scope, int32 &old_mute_until,
                                                              int32 new_mute_until) {
  if (td_->auth_manager_->is_bot()) {
    // just in case
    return;
  }

  LOG(INFO) << "Update " << scope << " unmute timeout from " << old_mute_until << " to " << new_mute_until;
  if (old_mute_until == new_mute_until) {
    return;
  }
  CHECK(old_mute_until >= 0);

  schedule_scope_unmute(scope, new_mute_until, G()->unix_time());

  auto was_muted = old_mute_until != 0;
  auto is_muted = new_mute_until != 0;

  old_mute_until = new_mute_until;

  if (was_muted != is_muted) {
    td_->messages_manager_->on_update_notification_scope_is_muted(scope, is_muted);
  }
}

void NotificationSettingsManager::reset_scope_notification_settings() {
  CHECK(!td_->auth_manager_->is_bot());

  for (auto scope :
       {NotificationSettingsScope::Private, NotificationSettingsScope::Group, NotificationSettingsScope::Channel}) {
    auto current_settings = get_scope_notification_settings(scope);
    CHECK(current_settings != nullptr);
    ScopeNotificationSettings new_scope_settings;
    new_scope_settings.is_synchronized = true;
    update_scope_notification_settings(scope, current_settings, std::move(new_scope_settings));
  }
}

bool NotificationSettingsManager::is_active() const {
  return !G()->close_flag() && td_->auth_manager_->is_authorized() && !td_->auth_manager_->is_bot();
}

FileId NotificationSettingsManager::get_saved_ringtone(int64 ringtone_id, Promise<Unit> &&promise) {
  if (!are_saved_ringtones_loaded_) {
    load_saved_ringtones(std::move(promise));
    return {};
  }

  promise.set_value(Unit());
  for (auto &file_id : saved_ringtone_file_ids_) {
    auto file_view = td_->file_manager_->get_file_view(file_id);
    CHECK(!file_view.empty());
    CHECK(file_view.get_type() == FileType::Ringtone);
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);
    if (full_remote_location->get_id() == ringtone_id) {
      return file_view.get_main_file_id();
    }
  }
  return {};
}

vector<FileId> NotificationSettingsManager::get_saved_ringtones(Promise<Unit> &&promise) {
  if (!are_saved_ringtones_loaded_) {
    load_saved_ringtones(std::move(promise));
    return {};
  }

  promise.set_value(Unit());
  return saved_ringtone_file_ids_;
}

void NotificationSettingsManager::send_save_ringtone_query(
    FileId ringtone_file_id, bool unsave,
    Promise<telegram_api::object_ptr<telegram_api::account_SavedRingtone>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  // TODO log event
  auto file_view = td_->file_manager_->get_file_view(ringtone_file_id);
  CHECK(!file_view.empty());
  const auto *full_remote_location = file_view.get_full_remote_location();
  CHECK(full_remote_location != nullptr);
  CHECK(full_remote_location->is_document());
  CHECK(!full_remote_location->is_web());
  td_->create_handler<SaveRingtoneQuery>(std::move(promise))
      ->send(ringtone_file_id, full_remote_location->as_input_document(), unsave);
}

void NotificationSettingsManager::add_saved_ringtone(td_api::object_ptr<td_api::InputFile> &&input_file,
                                                     Promise<td_api::object_ptr<td_api::notificationSound>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (!are_saved_ringtones_loaded_) {
    load_saved_ringtones(PromiseCreator::lambda([actor_id = actor_id(this), input_file = std::move(input_file),
                                                 promise = std::move(promise)](Result<Unit> &&result) mutable {
      if (result.is_error()) {
        return promise.set_error(result.move_as_error());
      }

      send_closure(actor_id, &NotificationSettingsManager::add_saved_ringtone, std::move(input_file),
                   std::move(promise));
    }));
    return;
  }

  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(FileType::Ringtone, input_file, DialogId(), false, false));
  auto file_view = td_->file_manager_->get_file_view(file_id);
  CHECK(!file_view.empty());
  if (file_view.size() > td_->option_manager_->get_option_integer("notification_sound_size_max")) {
    return promise.set_error(Status::Error(400, "Notification sound file is too big"));
  }
  auto file_type = file_view.get_type();
  int32 duration = 0;
  switch (file_type) {
    case FileType::Audio:
      duration = td_->audios_manager_->get_audio_duration(file_id);
      break;
    case FileType::VoiceNote:
      duration = td_->voice_notes_manager_->get_voice_note_duration(file_id);
      break;
    default:
      break;
  }
  if (duration > td_->option_manager_->get_option_integer("notification_sound_duration_max")) {
    return promise.set_error(Status::Error(400, "Notification sound is too long"));
  }
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location != nullptr && !file_view.is_encrypted()) {
    CHECK(main_remote_location->is_document());
    if (main_remote_location->is_web()) {
      return promise.set_error(Status::Error(400, "Can't use web document as notification sound"));
    }

    FileId ringtone_file_id = file_view.get_main_file_id();
    if (file_type != FileType::Ringtone) {
      if (file_type != FileType::Audio && file_type != FileType::VoiceNote) {
        return promise.set_error(Status::Error(400, "Unsupported file specified"));
      }
      auto &remote = *main_remote_location;
      ringtone_file_id = td_->file_manager_->register_remote(
          FullRemoteFileLocation(FileType::Ringtone, remote.get_id(), remote.get_access_hash(), remote.get_dc_id(),
                                 remote.get_file_reference().str()),
          FileLocationSource::FromServer, DialogId(), file_view.size(), file_view.expected_size(),
          file_view.suggested_path());
    }

    if (file_type != FileType::VoiceNote) {
      for (auto &saved_ringtone_file_id : saved_ringtone_file_ids_) {
        if (ringtone_file_id == saved_ringtone_file_id) {
          return promise.set_value(td_->audios_manager_->get_notification_sound_object(ringtone_file_id));
        }
      }
    }

    send_save_ringtone_query(
        file_view.get_main_file_id(), false,
        PromiseCreator::lambda(
            [actor_id = actor_id(this), file_id = ringtone_file_id, promise = std::move(promise)](
                Result<telegram_api::object_ptr<telegram_api::account_SavedRingtone>> &&result) mutable {
              if (result.is_error()) {
                promise.set_error(result.move_as_error());
              } else {
                send_closure(actor_id, &NotificationSettingsManager::on_add_saved_ringtone, file_id,
                             result.move_as_ok(), std::move(promise));
              }
            }));
    return;
  }

  file_id = td_->file_manager_->copy_file_id(file_id, FileType::Ringtone, DialogId(), "add_saved_ringtone");

  upload_ringtone({file_id, FileManager::get_internal_upload_id()}, false, std::move(promise));
}

void NotificationSettingsManager::upload_ringtone(FileUploadId file_upload_id, bool is_reupload,
                                                  Promise<td_api::object_ptr<td_api::notificationSound>> &&promise,
                                                  vector<int> bad_parts) {
  CHECK(file_upload_id.is_valid());
  LOG(INFO) << "Ask to upload ringtone " << file_upload_id;
  bool is_inserted =
      being_uploaded_ringtones_.emplace(file_upload_id, UploadedRingtone{is_reupload, std::move(promise)}).second;
  CHECK(is_inserted);
  // TODO use force_reupload if is_reupload
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_ringtone_callback_, 32, 0);
}

void NotificationSettingsManager::on_upload_ringtone(FileUploadId file_upload_id,
                                                     telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Ringtone " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_ringtones_.find(file_upload_id);
  CHECK(it != being_uploaded_ringtones_.end());
  bool is_reupload = it->second.is_reupload;
  auto promise = std::move(it->second.promise);
  being_uploaded_ringtones_.erase(it);

  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  CHECK(!file_view.is_encrypted());
  CHECK(file_view.get_type() == FileType::Ringtone);
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (input_file == nullptr && main_remote_location != nullptr) {
    if (main_remote_location->is_web()) {
      return promise.set_error(Status::Error(400, "Can't use web document as notification sound"));
    }
    if (is_reupload) {
      return promise.set_error(Status::Error(400, "Failed to reupload the file"));
    }

    auto main_file_id = file_view.get_main_file_id();
    send_save_ringtone_query(
        main_file_id, false,
        PromiseCreator::lambda(
            [actor_id = actor_id(this), main_file_id, promise = std::move(promise)](
                Result<telegram_api::object_ptr<telegram_api::account_SavedRingtone>> &&result) mutable {
              if (result.is_error()) {
                promise.set_error(result.move_as_error());
              } else {
                send_closure(actor_id, &NotificationSettingsManager::on_add_saved_ringtone, main_file_id,
                             result.move_as_ok(), std::move(promise));
              }
            }));
    return;
  }
  CHECK(input_file != nullptr);
  CHECK(input_file->get_id() == telegram_api::inputFile::ID);
  const PathView path_view(static_cast<const telegram_api::inputFile *>(input_file.get())->name_);
  auto file_name = path_view.file_name().str();
  auto mime_type = MimeType::from_extension(path_view.extension());
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::Document>> &&result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          send_closure(actor_id, &NotificationSettingsManager::on_upload_saved_ringtone, result.move_as_ok(),
                       std::move(promise));
        }
      });

  td_->create_handler<UploadRingtoneQuery>(std::move(query_promise))
      ->send(file_upload_id, std::move(input_file), file_name, mime_type);
}

void NotificationSettingsManager::on_upload_ringtone_error(FileUploadId file_upload_id, Status status) {
  LOG(INFO) << "Ringtone " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_ringtones_.find(file_upload_id);
  CHECK(it != being_uploaded_ringtones_.end());
  auto promise = std::move(it->second.promise);
  being_uploaded_ringtones_.erase(it);

  promise.set_error(std::move(status));
}

void NotificationSettingsManager::on_upload_saved_ringtone(
    telegram_api::object_ptr<telegram_api::Document> &&saved_ringtone,
    Promise<td_api::object_ptr<td_api::notificationSound>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  TRY_RESULT_PROMISE(promise, file_id, get_ringtone(std::move(saved_ringtone)));

  reload_saved_ringtones(PromiseCreator::lambda([actor_id = actor_id(this), file_id,
                                                 promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      send_closure(actor_id, &NotificationSettingsManager::on_add_saved_ringtone, file_id, nullptr, std::move(promise));
    }
  }));
}

void NotificationSettingsManager::on_add_saved_ringtone(
    FileId file_id, telegram_api::object_ptr<telegram_api::account_SavedRingtone> &&saved_ringtone,
    Promise<td_api::object_ptr<td_api::notificationSound>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (saved_ringtone != nullptr && saved_ringtone->get_id() == telegram_api::account_savedRingtoneConverted::ID) {
    auto ringtone = move_tl_object_as<telegram_api::account_savedRingtoneConverted>(saved_ringtone);
    TRY_RESULT_PROMISE_ASSIGN(promise, file_id, get_ringtone(std::move(ringtone->document_)));
  } else {
    for (auto &saved_ringtone_file_id : saved_ringtone_file_ids_) {
      if (file_id == saved_ringtone_file_id) {
        return promise.set_value(td_->audios_manager_->get_notification_sound_object(file_id));
      }
    }
    if (saved_ringtone == nullptr) {
      return promise.set_error(Status::Error(500, "Failed to find saved notification sound"));
    }
  }

  reload_saved_ringtones(PromiseCreator::lambda([actor_id = actor_id(this), file_id,
                                                 promise = std::move(promise)](Result<Unit> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      send_closure(actor_id, &NotificationSettingsManager::on_add_saved_ringtone, file_id, nullptr, std::move(promise));
    }
  }));
}

void NotificationSettingsManager::remove_saved_ringtone(int64 ringtone_id, Promise<Unit> &&promise) {
  if (!are_saved_ringtones_loaded_) {
    load_saved_ringtones(std::move(promise));
    return;
  }

  for (auto &file_id : saved_ringtone_file_ids_) {
    auto file_view = td_->file_manager_->get_file_view(file_id);
    CHECK(!file_view.empty());
    CHECK(file_view.get_type() == FileType::Ringtone);
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);
    if (full_remote_location->get_id() == ringtone_id) {
      send_save_ringtone_query(
          file_view.get_main_file_id(), true,
          PromiseCreator::lambda(
              [actor_id = actor_id(this), ringtone_id, promise = std::move(promise)](
                  Result<telegram_api::object_ptr<telegram_api::account_SavedRingtone>> &&result) mutable {
                if (result.is_error()) {
                  promise.set_error(result.move_as_error());
                } else {
                  send_closure(actor_id, &NotificationSettingsManager::on_remove_saved_ringtone, ringtone_id,
                               std::move(promise));
                }
              }));
      return;
    }
  }

  promise.set_value(Unit());
}

void NotificationSettingsManager::on_remove_saved_ringtone(int64 ringtone_id, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  CHECK(are_saved_ringtones_loaded_);

  auto max_count = td_->option_manager_->get_option_integer("notification_sound_count_max");
  if (saved_ringtone_file_ids_.size() >= static_cast<uint64>(max_count)) {
    // reload all saved ringtones to get ringtones besides the limit
    return reload_saved_ringtones(PromiseCreator::lambda([promise = std::move(promise)](Result<Unit> &&result) mutable {
      // ignore errors
      promise.set_value(Unit());
    }));
  }

  for (auto it = saved_ringtone_file_ids_.begin(); it != saved_ringtone_file_ids_.end(); ++it) {
    auto file_view = td_->file_manager_->get_file_view(*it);
    CHECK(!file_view.empty());
    CHECK(file_view.get_type() == FileType::Ringtone);
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);
    if (full_remote_location->get_id() == ringtone_id) {
      saved_ringtone_file_ids_.erase(it);
      saved_ringtone_hash_ = 0;
      on_saved_ringtones_updated(false);
      break;
    }
  }

  promise.set_value(Unit());
}

Result<FileId> NotificationSettingsManager::get_ringtone(
    telegram_api::object_ptr<telegram_api::Document> &&ringtone) const {
  int32 document_id = ringtone->get_id();
  if (document_id == telegram_api::documentEmpty::ID) {
    return Status::Error("Receive an empty ringtone");
  }
  CHECK(document_id == telegram_api::document::ID);

  auto parsed_document =
      td_->documents_manager_->on_get_document(move_tl_object_as<telegram_api::document>(ringtone), DialogId(), false,
                                               nullptr, Document::Type::Audio, DocumentsManager::Subtype::Ringtone);
  if (parsed_document.type != Document::Type::Audio) {
    return Status::Error("Receive ringtone of a wrong type");
  }
  return parsed_document.file_id;
}

void NotificationSettingsManager::load_saved_ringtones(Promise<Unit> &&promise) {
  CHECK(!are_saved_ringtones_loaded_);
  auto saved_ringtones_string = G()->td_db()->get_binlog_pmc()->get(get_saved_ringtones_database_key());
  if (saved_ringtones_string.empty()) {
    return reload_saved_ringtones(std::move(promise));
  }

  RingtoneListLogEvent saved_ringtones_log_event;
  bool is_valid = log_event_parse(saved_ringtones_log_event, saved_ringtones_string).is_ok();

  for (auto &ringtone_file_id : saved_ringtones_log_event.ringtone_file_ids_) {
    if (!ringtone_file_id.is_valid()) {
      is_valid = false;
      break;
    }
  }
  if (is_valid) {
    saved_ringtone_hash_ = saved_ringtones_log_event.hash_;
    saved_ringtone_file_ids_ = std::move(saved_ringtones_log_event.ringtone_file_ids_);
    are_saved_ringtones_loaded_ = true;

    if (!saved_ringtone_file_ids_.empty()) {
      on_saved_ringtones_updated(true);
    }

    // the promise must not be set synchronously
    send_closure_later(actor_id(this), &NotificationSettingsManager::on_load_saved_ringtones, std::move(promise));
    reload_saved_ringtones(Auto());
  } else {
    LOG(ERROR) << "Ignore invalid saved notification sounds log event";
    reload_saved_ringtones(std::move(promise));
  }
}

void NotificationSettingsManager::on_load_saved_ringtones(Promise<Unit> &&promise) {
  promise.set_value(Unit());
}

void NotificationSettingsManager::reload_saved_ringtones(Promise<Unit> &&promise) {
  if (!is_active()) {
    return promise.set_error(Status::Error(400, "Don't need to reload saved notification sounds"));
  }
  reload_saved_ringtones_queries_.push_back(std::move(promise));
  if (reload_saved_ringtones_queries_.size() == 1) {
    are_saved_ringtones_reloaded_ = true;
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::account_SavedRingtones>> &&result) {
          send_closure(actor_id, &NotificationSettingsManager::on_reload_saved_ringtones, false, std::move(result));
        });
    td_->create_handler<GetSavedRingtonesQuery>(std::move(query_promise))->send(saved_ringtone_hash_);
  }
}

void NotificationSettingsManager::repair_saved_ringtones(Promise<Unit> &&promise) {
  if (!is_active()) {
    return promise.set_error(Status::Error(400, "Don't need to repair saved notification sounds"));
  }

  repair_saved_ringtones_queries_.push_back(std::move(promise));
  if (repair_saved_ringtones_queries_.size() == 1u) {
    are_saved_ringtones_reloaded_ = true;
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::account_SavedRingtones>> &&result) {
          send_closure(actor_id, &NotificationSettingsManager::on_reload_saved_ringtones, true, std::move(result));
        });
    td_->create_handler<GetSavedRingtonesQuery>(std::move(query_promise))->send(0);
  }
}

void NotificationSettingsManager::on_reload_saved_ringtones(
    bool is_repair, Result<telegram_api::object_ptr<telegram_api::account_SavedRingtones>> &&result) {
  if (!is_active()) {
    are_saved_ringtones_loaded_ = true;
    set_promises(reload_saved_ringtones_queries_);
    set_promises(repair_saved_ringtones_queries_);
    return;
  }
  if (result.is_error()) {
    if (is_repair) {
      fail_promises(repair_saved_ringtones_queries_, result.move_as_error());
    } else {
      fail_promises(reload_saved_ringtones_queries_, result.move_as_error());
      set_timeout_in(Random::fast(60, 120));
    }
    return;
  }

  if (!is_repair) {
    set_timeout_in(Random::fast(3600, 4800));
  }

  auto saved_ringtones_ptr = result.move_as_ok();
  auto constructor_id = saved_ringtones_ptr->get_id();
  if (constructor_id == telegram_api::account_savedRingtonesNotModified::ID) {
    if (is_repair) {
      fail_promises(repair_saved_ringtones_queries_, Status::Error(500, "Failed to repair saved animations"));
    } else {
      are_saved_ringtones_loaded_ = true;
      set_promises(reload_saved_ringtones_queries_);
    }
    return;
  }
  CHECK(constructor_id == telegram_api::account_savedRingtones::ID);
  auto saved_ringtones = move_tl_object_as<telegram_api::account_savedRingtones>(saved_ringtones_ptr);

  auto new_hash = saved_ringtones->hash_;
  vector<FileId> new_saved_ringtone_file_ids;

  for (auto &ringtone : saved_ringtones->ringtones_) {
    auto r_ringtone = get_ringtone(std::move(ringtone));
    if (r_ringtone.is_error()) {
      LOG(ERROR) << r_ringtone.error().message();
      new_hash = 0;
      continue;
    }

    new_saved_ringtone_file_ids.push_back(r_ringtone.move_as_ok());
  }

  bool need_update = new_saved_ringtone_file_ids != saved_ringtone_file_ids_;
  are_saved_ringtones_loaded_ = true;
  if (need_update || saved_ringtone_hash_ != new_hash) {
    saved_ringtone_hash_ = new_hash;
    saved_ringtone_file_ids_ = std::move(new_saved_ringtone_file_ids);

    if (need_update) {
      on_saved_ringtones_updated(false);
    }
  }
  if (is_repair) {
    set_promises(repair_saved_ringtones_queries_);
  } else {
    set_promises(reload_saved_ringtones_queries_);
  }
}

td_api::object_ptr<td_api::updateSavedNotificationSounds>
NotificationSettingsManager::get_update_saved_notification_sounds_object() const {
  auto ringtone_ids = transform(saved_ringtone_file_ids_, [file_manager = td_->file_manager_.get()](FileId file_id) {
    auto file_view = file_manager->get_file_view(file_id);
    CHECK(!file_view.empty());
    CHECK(file_view.get_type() == FileType::Ringtone);
    const auto *full_remote_location = file_view.get_full_remote_location();
    CHECK(full_remote_location != nullptr);
    return full_remote_location->get_id();
  });
  return td_api::make_object<td_api::updateSavedNotificationSounds>(std::move(ringtone_ids));
}

string NotificationSettingsManager::get_saved_ringtones_database_key() {
  return "ringtones";
}

void NotificationSettingsManager::save_saved_ringtones_to_database() const {
  RingtoneListLogEvent ringtone_list_log_event{saved_ringtone_hash_, saved_ringtone_file_ids_};
  G()->td_db()->get_binlog_pmc()->set(get_saved_ringtones_database_key(),
                                      log_event_store(ringtone_list_log_event).as_slice().str());
}

void NotificationSettingsManager::on_saved_ringtones_updated(bool from_database) {
  CHECK(are_saved_ringtones_loaded_);
  vector<FileId> new_sorted_saved_ringtone_file_ids = saved_ringtone_file_ids_;
  std::sort(new_sorted_saved_ringtone_file_ids.begin(), new_sorted_saved_ringtone_file_ids.end());
  if (new_sorted_saved_ringtone_file_ids != sorted_saved_ringtone_file_ids_) {
    td_->file_manager_->change_files_source(get_saved_ringtones_file_source_id(), sorted_saved_ringtone_file_ids_,
                                            new_sorted_saved_ringtone_file_ids, "on_saved_ringtones_updated");
    sorted_saved_ringtone_file_ids_ = std::move(new_sorted_saved_ringtone_file_ids);
  }

  if (!from_database) {
    save_saved_ringtones_to_database();
  }

  send_closure(G()->td(), &Td::send_update, get_update_saved_notification_sounds_object());
}

FileSourceId NotificationSettingsManager::get_saved_ringtones_file_source_id() {
  if (!saved_ringtones_file_source_id_.is_valid()) {
    saved_ringtones_file_source_id_ = td_->file_reference_manager_->create_saved_ringtones_file_source();
  }
  return saved_ringtones_file_source_id_;
}

void NotificationSettingsManager::send_get_dialog_notification_settings_query(DialogId dialog_id,
                                                                              MessageId top_thread_message_id,
                                                                              Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    LOG(ERROR) << "Can't get notification settings for " << dialog_id;
    return promise.set_error(Status::Error(500, "Wrong getDialogNotificationSettings query"));
  }
  TRY_STATUS_PROMISE(promise,
                     td_->dialog_manager_->check_dialog_access_in_memory(dialog_id, false, AccessRights::Read));

  auto &promises = get_dialog_notification_settings_queries_[{dialog_id, top_thread_message_id}];
  promises.push_back(std::move(promise));
  if (promises.size() != 1) {
    // query has already been sent, just wait for the result
    return;
  }

  td_->create_handler<GetDialogNotifySettingsQuery>()->send(dialog_id, top_thread_message_id);
}

const ScopeNotificationSettings *NotificationSettingsManager::get_scope_notification_settings(
    NotificationSettingsScope scope, Promise<Unit> &&promise) {
  const ScopeNotificationSettings *notification_settings = get_scope_notification_settings(scope);
  CHECK(notification_settings != nullptr);
  if (!notification_settings->is_synchronized && !td_->auth_manager_->is_bot()) {
    send_get_scope_notification_settings_query(scope, std::move(promise));
    return nullptr;
  }

  promise.set_value(Unit());
  return notification_settings;
}

void NotificationSettingsManager::send_get_scope_notification_settings_query(NotificationSettingsScope scope,
                                                                             Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    LOG(ERROR) << "Can't get notification settings for " << scope;
    return promise.set_error(Status::Error(500, "Wrong getScopeNotificationSettings query"));
  }

  td_->create_handler<GetScopeNotifySettingsQuery>(std::move(promise))->send(scope);
}

void NotificationSettingsManager::on_get_dialog_notification_settings_query_finished(DialogId dialog_id,
                                                                                     MessageId top_thread_message_id,
                                                                                     Status &&status) {
  CHECK(!td_->auth_manager_->is_bot());
  auto it = get_dialog_notification_settings_queries_.find({dialog_id, top_thread_message_id});
  CHECK(it != get_dialog_notification_settings_queries_.end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  get_dialog_notification_settings_queries_.erase(it);

  if (status.is_ok()) {
    set_promises(promises);
  } else {
    fail_promises(promises, std::move(status));
  }
}

void NotificationSettingsManager::update_dialog_notify_settings(DialogId dialog_id, MessageId top_thread_message_id,
                                                                const DialogNotificationSettings &new_settings,
                                                                Promise<Unit> &&promise) {
  td_->create_handler<UpdateDialogNotifySettingsQuery>(std::move(promise))
      ->send(dialog_id, top_thread_message_id, new_settings);
}

Status NotificationSettingsManager::set_scope_notification_settings(
    NotificationSettingsScope scope, td_api::object_ptr<td_api::scopeNotificationSettings> &&notification_settings) {
  CHECK(!td_->auth_manager_->is_bot());
  auto *current_settings = get_scope_notification_settings(scope);
  CHECK(current_settings != nullptr);
  TRY_RESULT(new_settings, ::td::get_scope_notification_settings(std::move(notification_settings)));
  if (is_notification_sound_default(current_settings->sound) && is_notification_sound_default(new_settings.sound)) {
    new_settings.sound = dup_notification_sound(current_settings->sound);
  }
  if (update_scope_notification_settings(scope, current_settings, std::move(new_settings))) {
    update_scope_notification_settings_on_server(scope, 0);
  }
  return Status::OK();
}

class NotificationSettingsManager::UpdateScopeNotificationSettingsOnServerLogEvent {
 public:
  NotificationSettingsScope scope_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(scope_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(scope_, parser);
  }
};

uint64 NotificationSettingsManager::save_update_scope_notification_settings_on_server_log_event(
    NotificationSettingsScope scope) {
  UpdateScopeNotificationSettingsOnServerLogEvent log_event{scope};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::UpdateScopeNotificationSettingsOnServer,
                    get_log_event_storer(log_event));
}

void NotificationSettingsManager::update_scope_notification_settings_on_server(NotificationSettingsScope scope,
                                                                               uint64 log_event_id) {
  CHECK(!td_->auth_manager_->is_bot());
  if (log_event_id == 0) {
    log_event_id = save_update_scope_notification_settings_on_server_log_event(scope);
  }

  LOG(INFO) << "Update " << scope << " notification settings on server with log_event " << log_event_id;
  td_->create_handler<UpdateScopeNotifySettingsQuery>(get_erase_log_event_promise(log_event_id))
      ->send(scope, *get_scope_notification_settings(scope));
}

Status NotificationSettingsManager::set_reaction_notification_settings(
    ReactionNotificationSettings &&notification_settings) {
  CHECK(!td_->auth_manager_->is_bot());
  notification_settings.update_default_notification_sound(reaction_notification_settings_);
  if (notification_settings == reaction_notification_settings_) {
    have_reaction_notification_settings_ = true;
    return Status::OK();
  }

  VLOG(notifications) << "Update reaction notification settings from " << reaction_notification_settings_ << " to "
                      << notification_settings;

  reaction_notification_settings_ = std::move(notification_settings);
  have_reaction_notification_settings_ = true;

  save_reaction_notification_settings();

  send_closure(G()->td(), &Td::send_update, get_update_reaction_notification_settings_object());

  update_reaction_notification_settings_on_server(0);
  return Status::OK();
}

class NotificationSettingsManager::UpdateReactionNotificationSettingsOnServerLogEvent {
 public:
  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    END_STORE_FLAGS();
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    END_PARSE_FLAGS();
  }
};

uint64 NotificationSettingsManager::save_update_reaction_notification_settings_on_server_log_event() {
  UpdateReactionNotificationSettingsOnServerLogEvent log_event;
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::UpdateReactionNotificationSettingsOnServer,
                    get_log_event_storer(log_event));
}

void NotificationSettingsManager::update_reaction_notification_settings_on_server(uint64 log_event_id) {
  CHECK(!td_->auth_manager_->is_bot());
  if (log_event_id == 0) {
    log_event_id = save_update_reaction_notification_settings_on_server_log_event();
  }

  LOG(INFO) << "Update reaction notification settings on server with log_event " << log_event_id;
  td_->create_handler<SetReactionsNotifySettingsQuery>(get_erase_log_event_promise(log_event_id))
      ->send(reaction_notification_settings_);
}

void NotificationSettingsManager::get_notify_settings_exceptions(NotificationSettingsScope scope, bool filter_scope,
                                                                 bool compare_sound, Promise<Unit> &&promise) {
  td_->create_handler<GetNotifySettingsExceptionsQuery>(std::move(promise))->send(scope, filter_scope, compare_sound);
}

void NotificationSettingsManager::get_story_notification_settings_exceptions(
    Promise<td_api::object_ptr<td_api::chats>> &&promise) {
  td_->create_handler<GetStoryNotifySettingsExceptionsQuery>(std::move(promise))->send();
}

void NotificationSettingsManager::reset_all_notification_settings() {
  CHECK(!td_->auth_manager_->is_bot());

  td_->messages_manager_->reset_all_dialog_notification_settings();

  reset_scope_notification_settings();

  reset_all_notification_settings_on_server(0);
}

class NotificationSettingsManager::ResetAllNotificationSettingsOnServerLogEvent {
 public:
  template <class StorerT>
  void store(StorerT &storer) const {
  }

  template <class ParserT>
  void parse(ParserT &parser) {
  }
};

uint64 NotificationSettingsManager::save_reset_all_notification_settings_on_server_log_event() {
  ResetAllNotificationSettingsOnServerLogEvent log_event;
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ResetAllNotificationSettingsOnServer,
                    get_log_event_storer(log_event));
}

void NotificationSettingsManager::reset_all_notification_settings_on_server(uint64 log_event_id) {
  CHECK(!td_->auth_manager_->is_bot());
  if (log_event_id == 0) {
    log_event_id = save_reset_all_notification_settings_on_server_log_event();
  }

  LOG(INFO) << "Reset all notification settings";
  td_->create_handler<ResetNotifySettingsQuery>(get_erase_log_event_promise(log_event_id))->send();
}

void NotificationSettingsManager::on_binlog_events(vector<BinlogEvent> &&events) {
  if (G()->close_flag()) {
    return;
  }
  for (auto &event : events) {
    CHECK(event.id_ != 0);
    switch (event.type_) {
      case LogEvent::HandlerType::ResetAllNotificationSettingsOnServer: {
        ResetAllNotificationSettingsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        reset_all_notification_settings_on_server(event.id_);
        break;
      }
      case LogEvent::HandlerType::UpdateScopeNotificationSettingsOnServer: {
        UpdateScopeNotificationSettingsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        update_scope_notification_settings_on_server(log_event.scope_, event.id_);
        break;
      }
      case LogEvent::HandlerType::UpdateReactionNotificationSettingsOnServer: {
        UpdateReactionNotificationSettingsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        update_reaction_notification_settings_on_server(event.id_);
        break;
      }
      default:
        LOG(FATAL) << "Unsupported log event type " << event.type_;
    }
  }
}

void NotificationSettingsManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  for (auto scope :
       {NotificationSettingsScope::Private, NotificationSettingsScope::Group, NotificationSettingsScope::Channel}) {
    auto current_settings = get_scope_notification_settings(scope);
    CHECK(current_settings != nullptr);
    if (current_settings->is_synchronized) {
      updates.push_back(get_update_scope_notification_settings_object(scope));
    }
  }

  updates.push_back(get_update_reaction_notification_settings_object());

  if (are_saved_ringtones_loaded_) {
    updates.push_back(get_update_saved_notification_sounds_object());
  }
}

}  // namespace td
