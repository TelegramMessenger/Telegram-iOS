//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AutosaveManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/tl_helpers.h"

namespace td {

class GetAutoSaveSettingsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::account_autoSaveSettings>> promise_;

 public:
  explicit GetAutoSaveSettingsQuery(Promise<telegram_api::object_ptr<telegram_api::account_autoSaveSettings>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getAutoSaveSettings(), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getAutoSaveSettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetAutoSaveSettingsQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SaveAutoSaveSettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SaveAutoSaveSettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool users, bool chats, bool broadcasts, DialogId dialog_id,
            telegram_api::object_ptr<telegram_api::autoSaveSettings> settings) {
    int32 flags = 0;
    telegram_api::object_ptr<telegram_api::InputPeer> input_peer;
    if (users) {
      flags |= telegram_api::account_saveAutoSaveSettings::USERS_MASK;
    } else if (chats) {
      flags |= telegram_api::account_saveAutoSaveSettings::CHATS_MASK;
    } else if (broadcasts) {
      flags |= telegram_api::account_saveAutoSaveSettings::BROADCASTS_MASK;
    } else {
      flags |= telegram_api::account_saveAutoSaveSettings::PEER_MASK;
      input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
      CHECK(input_peer != nullptr);
    }
    send_query(G()->net_query_creator().create(
        telegram_api::account_saveAutoSaveSettings(flags, false /*ignored*/, false /*ignored*/, false /*ignored*/,
                                                   std::move(input_peer), std::move(settings)),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_saveAutoSaveSettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
    td_->autosave_manager_->reload_autosave_settings();
  }
};

class DeleteAutoSaveExceptionsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteAutoSaveExceptionsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_deleteAutoSaveExceptions(), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_deleteAutoSaveExceptions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
    td_->autosave_manager_->reload_autosave_settings();
  }
};

AutosaveManager::AutosaveManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

void AutosaveManager::tear_down() {
  parent_.reset();
}

AutosaveManager::DialogAutosaveSettings::DialogAutosaveSettings(const telegram_api::autoSaveSettings *settings) {
  CHECK(settings != nullptr);
  are_inited_ = true;
  autosave_photos_ = settings->photos_;
  autosave_videos_ = settings->videos_;
  max_video_file_size_ = clamp(settings->video_max_size_, MIN_MAX_VIDEO_FILE_SIZE, MAX_MAX_VIDEO_FILE_SIZE);
}

AutosaveManager::DialogAutosaveSettings::DialogAutosaveSettings(const td_api::scopeAutosaveSettings *settings) {
  if (settings == nullptr) {
    return;
  }
  are_inited_ = true;
  autosave_photos_ = settings->autosave_photos_;
  autosave_videos_ = settings->autosave_videos_;
  max_video_file_size_ = clamp(settings->max_video_file_size_, MIN_MAX_VIDEO_FILE_SIZE, MAX_MAX_VIDEO_FILE_SIZE);
}

telegram_api::object_ptr<telegram_api::autoSaveSettings>
AutosaveManager::DialogAutosaveSettings::get_input_auto_save_settings() const {
  int32 flags = 0;
  if (autosave_photos_) {
    flags |= telegram_api::autoSaveSettings::PHOTOS_MASK;
  }
  if (autosave_videos_) {
    flags |= telegram_api::autoSaveSettings::VIDEOS_MASK;
  }
  if (are_inited_) {
    flags |= telegram_api::autoSaveSettings::VIDEO_MAX_SIZE_MASK;
  }
  return telegram_api::make_object<telegram_api::autoSaveSettings>(flags, false /*ignored*/, false /*ignored*/,
                                                                   max_video_file_size_);
}

td_api::object_ptr<td_api::scopeAutosaveSettings>
AutosaveManager::DialogAutosaveSettings::get_scope_autosave_settings_object() const {
  if (!are_inited_) {
    return nullptr;
  }
  return td_api::make_object<td_api::scopeAutosaveSettings>(autosave_photos_, autosave_videos_, max_video_file_size_);
}

td_api::object_ptr<td_api::autosaveSettingsException>
AutosaveManager::DialogAutosaveSettings::get_autosave_settings_exception_object(const Td *td,
                                                                                DialogId dialog_id) const {
  return td_api::make_object<td_api::autosaveSettingsException>(
      td->dialog_manager_->get_chat_id_object(dialog_id, "autosaveSettingsException"),
      get_scope_autosave_settings_object());
}

bool AutosaveManager::DialogAutosaveSettings::operator==(const DialogAutosaveSettings &other) const {
  return are_inited_ == other.are_inited_ && autosave_photos_ == other.autosave_photos_ &&
         autosave_videos_ == other.autosave_videos_ && max_video_file_size_ == other.max_video_file_size_;
}

bool AutosaveManager::DialogAutosaveSettings::operator!=(const DialogAutosaveSettings &other) const {
  return !operator==(other);
}

template <class StorerT>
void AutosaveManager::DialogAutosaveSettings::store(StorerT &storer) const {
  CHECK(are_inited_);
  BEGIN_STORE_FLAGS();
  STORE_FLAG(autosave_photos_);
  STORE_FLAG(autosave_videos_);
  END_STORE_FLAGS();
  td::store(max_video_file_size_, storer);
}

template <class ParserT>
void AutosaveManager::DialogAutosaveSettings::parse(ParserT &parser) {
  are_inited_ = true;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(autosave_photos_);
  PARSE_FLAG(autosave_videos_);
  END_PARSE_FLAGS();
  td::parse(max_video_file_size_, parser);
}

td_api::object_ptr<td_api::autosaveSettings> AutosaveManager::AutosaveSettings::get_autosave_settings_object(
    const Td *td) const {
  CHECK(are_inited_);
  auto exceptions = transform(exceptions_, [td](const auto &exception) {
    return exception.second.get_autosave_settings_exception_object(td, exception.first);
  });
  return td_api::make_object<td_api::autosaveSettings>(
      user_settings_.get_scope_autosave_settings_object(), chat_settings_.get_scope_autosave_settings_object(),
      broadcast_settings_.get_scope_autosave_settings_object(), std::move(exceptions));
}

template <class StorerT>
void AutosaveManager::AutosaveSettings::store(StorerT &storer) const {
  CHECK(are_inited_);
  bool has_exceptions = !exceptions_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_exceptions);
  END_STORE_FLAGS();
  td::store(user_settings_, storer);
  td::store(chat_settings_, storer);
  td::store(broadcast_settings_, storer);
  if (has_exceptions) {
    td::store(narrow_cast<uint32>(exceptions_.size()), storer);
    for (auto &exception : exceptions_) {
      td::store(exception.first, storer);
      td::store(exception.second, storer);
    }
  }
}

template <class ParserT>
void AutosaveManager::AutosaveSettings::parse(ParserT &parser) {
  are_inited_ = true;
  bool has_exceptions;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_exceptions);
  END_PARSE_FLAGS();
  td::parse(user_settings_, parser);
  td::parse(chat_settings_, parser);
  td::parse(broadcast_settings_, parser);
  if (has_exceptions) {
    uint32 size;
    td::parse(size, parser);
    for (size_t i = 0; i < size; i++) {
      DialogId dialog_id;
      DialogAutosaveSettings settings;
      td::parse(dialog_id, parser);
      td::parse(settings, parser);
      if (dialog_id.is_valid()) {
        exceptions_.emplace(dialog_id, std::move(settings));
      }
    }
  }
}

void AutosaveManager::get_autosave_settings(Promise<td_api::object_ptr<td_api::autosaveSettings>> &&promise) {
  if (settings_.are_inited_) {
    return promise.set_value(settings_.get_autosave_settings_object(td_));
  }

  load_autosave_settings(std::move(promise));
}

string AutosaveManager::get_autosave_settings_database_key() {
  return "autosave_settings";
}

void AutosaveManager::load_autosave_settings(Promise<td_api::object_ptr<td_api::autosaveSettings>> &&promise) {
  load_settings_queries_.push_back(std::move(promise));
  if (load_settings_queries_.size() != 1) {
    return;
  }

  if (G()->use_message_database()) {
    G()->td_db()->get_sqlite_pmc()->get(
        get_autosave_settings_database_key(), PromiseCreator::lambda([actor_id = actor_id(this)](string value) mutable {
          send_closure(actor_id, &AutosaveManager::on_load_autosave_settings_from_database, std::move(value));
        }));
    return;
  }

  reload_autosave_settings();
}

void AutosaveManager::on_load_autosave_settings_from_database(string value) {
  if (G()->close_flag()) {
    return fail_promises(load_settings_queries_, Global::request_aborted_error());
  }
  if (settings_.are_inited_) {
    CHECK(load_settings_queries_.empty());
    return;
  }
  if (value.empty()) {
    LOG(INFO) << "Autosave settings aren't found in database";
    return reload_autosave_settings();
  }

  LOG(INFO) << "Successfully loaded autosave settings from database";

  auto status = log_event_parse(settings_, value);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load autosave settings: " << status;
    settings_ = {};
    return reload_autosave_settings();
  }

  Dependencies dependencies;
  for (auto &exception : settings_.exceptions_) {
    dependencies.add_dialog_and_dependencies(exception.first);
  }
  if (!dependencies.resolve_force(td_, "on_load_autosave_settings_from_database")) {
    G()->td_db()->get_binlog_pmc()->erase(get_autosave_settings_database_key());
    settings_ = {};
    return reload_autosave_settings();
  }

  settings_.are_inited_ = true;
  send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopePrivateChats>(),
                                settings_.user_settings_);
  send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeGroupChats>(),
                                settings_.chat_settings_);
  send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeChannelChats>(),
                                settings_.broadcast_settings_);
  for (auto &exception : settings_.exceptions_) {
    send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeChat>(exception.first.get()),
                                  exception.second);
  }

  auto promises = std::move(load_settings_queries_);
  for (auto &promise : promises) {
    promise.set_value(settings_.get_autosave_settings_object(td_));
  }
}

void AutosaveManager::reload_autosave_settings() {
  if (G()->close_flag()) {
    return fail_promises(load_settings_queries_, Global::request_aborted_error());
  }
  if (settings_.are_being_reloaded_) {
    settings_.need_reload_ = true;
    return;
  }
  settings_.are_being_reloaded_ = true;

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::account_autoSaveSettings>> r_settings) {
        send_closure(actor_id, &AutosaveManager::on_get_autosave_settings, std::move(r_settings));
      });
  td_->create_handler<GetAutoSaveSettingsQuery>(std::move(query_promise))->send();
}

void AutosaveManager::on_get_autosave_settings(
    Result<telegram_api::object_ptr<telegram_api::account_autoSaveSettings>> r_settings) {
  G()->ignore_result_if_closing(r_settings);

  CHECK(settings_.are_being_reloaded_);
  settings_.are_being_reloaded_ = false;
  SCOPE_EXIT {
    if (settings_.need_reload_) {
      settings_.need_reload_ = false;
      reload_autosave_settings();
    }
  };
  if (r_settings.is_error()) {
    return fail_promises(load_settings_queries_, r_settings.move_as_error());
  }

  auto settings = r_settings.move_as_ok();
  td_->user_manager_->on_get_users(std::move(settings->users_), "on_get_autosave_settings");
  td_->chat_manager_->on_get_chats(std::move(settings->chats_), "on_get_autosave_settings");

  DialogAutosaveSettings new_user_settings(settings->users_settings_.get());
  DialogAutosaveSettings new_chat_settings(settings->chats_settings_.get());
  DialogAutosaveSettings new_broadcast_settings(settings->broadcasts_settings_.get());

  settings_.are_inited_ = true;
  if (settings_.user_settings_ != new_user_settings) {
    settings_.user_settings_ = std::move(new_user_settings);
    send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopePrivateChats>(),
                                  settings_.user_settings_);
  }
  if (settings_.chat_settings_ != new_chat_settings) {
    settings_.chat_settings_ = std::move(new_chat_settings);
    send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeGroupChats>(),
                                  settings_.chat_settings_);
  }
  if (settings_.broadcast_settings_ != new_broadcast_settings) {
    settings_.broadcast_settings_ = std::move(new_broadcast_settings);
    send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeChannelChats>(),
                                  settings_.broadcast_settings_);
  }
  FlatHashSet<DialogId, DialogIdHash> exception_dialog_ids;
  for (auto &exception : settings_.exceptions_) {
    exception_dialog_ids.insert(exception.first);
  }
  for (auto &exception : settings->exceptions_) {
    DialogId dialog_id(exception->peer_);
    if (!dialog_id.is_valid()) {
      continue;
    }
    td_->dialog_manager_->force_create_dialog(dialog_id, "on_get_autosave_settings");
    DialogAutosaveSettings new_settings(exception->settings_.get());
    auto &current_settings = settings_.exceptions_[dialog_id];
    if (current_settings != new_settings) {
      current_settings = std::move(new_settings);
      send_update_autosave_settings(
          td_api::make_object<td_api::autosaveSettingsScopeChat>(
              td_->dialog_manager_->get_chat_id_object(dialog_id, "autosaveSettingsScopeChat")),
          current_settings);
    }
    exception_dialog_ids.erase(dialog_id);
  }
  for (auto dialog_id : exception_dialog_ids) {
    settings_.exceptions_.erase(dialog_id);
    send_update_autosave_settings(
        td_api::make_object<td_api::autosaveSettingsScopeChat>(
            td_->dialog_manager_->get_chat_id_object(dialog_id, "autosaveSettingsScopeChat 2")),
        DialogAutosaveSettings());
  }

  save_autosave_settings();

  auto promises = std::move(load_settings_queries_);
  for (auto &promise : promises) {
    promise.set_value(settings_.get_autosave_settings_object(td_));
  }
}

void AutosaveManager::save_autosave_settings() {
  if (G()->use_message_database()) {
    LOG(INFO) << "Save autosave settings to database";
    G()->td_db()->get_sqlite_pmc()->set(get_autosave_settings_database_key(),
                                        log_event_store(settings_).as_slice().str(), Auto());
  }
}

void AutosaveManager::set_autosave_settings(td_api::object_ptr<td_api::AutosaveSettingsScope> &&scope,
                                            td_api::object_ptr<td_api::scopeAutosaveSettings> &&settings,
                                            Promise<Unit> &&promise) {
  if (scope == nullptr) {
    return promise.set_error(Status::Error(400, "Scope must be non-empty"));
  }
  if (!settings_.are_inited_) {
    return promise.set_error(Status::Error(400, "Autosave settings must be loaded first"));
  }
  auto new_settings = DialogAutosaveSettings(settings.get());
  DialogAutosaveSettings *old_settings = nullptr;
  bool users = false;
  bool chats = false;
  bool broadcasts = false;
  DialogId dialog_id;
  switch (scope->get_id()) {
    case td_api::autosaveSettingsScopePrivateChats::ID:
      users = true;
      old_settings = &settings_.user_settings_;
      break;
    case td_api::autosaveSettingsScopeGroupChats::ID:
      chats = true;
      old_settings = &settings_.chat_settings_;
      break;
    case td_api::autosaveSettingsScopeChannelChats::ID:
      broadcasts = true;
      old_settings = &settings_.broadcast_settings_;
      break;
    case td_api::autosaveSettingsScopeChat::ID:
      dialog_id = DialogId(static_cast<const td_api::autosaveSettingsScopeChat *>(scope.get())->chat_id_);
      TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                            "set_autosave_settings"));
      old_settings = &settings_.exceptions_[dialog_id];
      break;
    default:
      UNREACHABLE();
  }
  if (!dialog_id.is_valid() && !new_settings.are_inited_) {
    new_settings.are_inited_ = true;
    new_settings.max_video_file_size_ = DialogAutosaveSettings::DEFAULT_MAX_VIDEO_FILE_SIZE;
  }
  if (*old_settings == new_settings) {
    return promise.set_value(Unit());
  }
  if (new_settings.are_inited_) {
    *old_settings = std::move(new_settings);
    send_update_autosave_settings(std::move(scope), *old_settings);
  } else {
    CHECK(dialog_id.is_valid());
    settings_.exceptions_.erase(dialog_id);
    send_update_autosave_settings(std::move(scope), DialogAutosaveSettings());
  }

  save_autosave_settings();

  td_->create_handler<SaveAutoSaveSettingsQuery>(std::move(promise))
      ->send(users, chats, broadcasts, dialog_id, new_settings.get_input_auto_save_settings());
}

void AutosaveManager::clear_autosave_settings_exceptions(Promise<Unit> &&promise) {
  if (!settings_.are_inited_) {
    return promise.set_error(Status::Error(400, "Autosave settings must be loaded first"));
  }
  for (const auto &exception : settings_.exceptions_) {
    send_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeChat>(exception.first.get()),
                                  DialogAutosaveSettings());
  }
  settings_.exceptions_.clear();
  save_autosave_settings();
  td_->create_handler<DeleteAutoSaveExceptionsQuery>(std::move(promise))->send();
}

td_api::object_ptr<td_api::updateAutosaveSettings> AutosaveManager::get_update_autosave_settings(
    td_api::object_ptr<td_api::AutosaveSettingsScope> &&scope, const DialogAutosaveSettings &settings) {
  return td_api::make_object<td_api::updateAutosaveSettings>(std::move(scope),
                                                             settings.get_scope_autosave_settings_object());
}

void AutosaveManager::send_update_autosave_settings(td_api::object_ptr<td_api::AutosaveSettingsScope> &&scope,
                                                    const DialogAutosaveSettings &settings) {
  send_closure(G()->td(), &Td::send_update, get_update_autosave_settings(std::move(scope), settings));
}

void AutosaveManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (!settings_.are_inited_) {
    return;
  }
  updates.push_back(get_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopePrivateChats>(),
                                                 settings_.user_settings_));
  updates.push_back(get_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeGroupChats>(),
                                                 settings_.chat_settings_));
  updates.push_back(get_update_autosave_settings(td_api::make_object<td_api::autosaveSettingsScopeChannelChats>(),
                                                 settings_.broadcast_settings_));
  for (const auto &exception : settings_.exceptions_) {
    updates.push_back(get_update_autosave_settings(
        td_api::make_object<td_api::autosaveSettingsScopeChat>(exception.first.get()), exception.second));
  }
}

}  // namespace td
