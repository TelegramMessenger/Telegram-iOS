//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BackgroundManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/BackgroundType.hpp"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/DocumentsManager.hpp"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/PhotoFormat.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/db/SqliteKeyValueAsync.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"

#include <algorithm>

namespace td {

class GetBackgroundQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  BackgroundId background_id_;
  string background_name_;

 public:
  explicit GetBackgroundQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(BackgroundId background_id, const string &background_name,
            telegram_api::object_ptr<telegram_api::InputWallPaper> &&input_wallpaper) {
    background_id_ = background_id;
    background_name_ = background_name;
    send_query(G()->net_query_creator().create(telegram_api::account_getWallPaper(std::move(input_wallpaper))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getWallPaper>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->background_manager_->on_get_background(background_id_, background_name_, result_ptr.move_as_ok(), true, false);

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for GetBackgroundQuery for " << background_id_ << "/" << background_name_ << ": "
              << status;
    promise_.set_error(std::move(status));
  }
};

class GetBackgroundsQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::account_WallPapers>> promise_;

 public:
  explicit GetBackgroundsQuery(Promise<telegram_api::object_ptr<telegram_api::account_WallPapers>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getWallPapers(0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getWallPapers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetChatWallPaperQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  bool is_remove_ = false;
  bool is_revert_ = false;

 public:
  explicit SetChatWallPaperQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, telegram_api::object_ptr<telegram_api::InputWallPaper> input_wallpaper,
            telegram_api::object_ptr<telegram_api::wallPaperSettings> settings, MessageId old_message_id, bool for_both,
            bool revert) {
    dialog_id_ = dialog_id;
    is_revert_ = revert;
    is_remove_ = input_wallpaper == nullptr && settings == nullptr && !revert;
    if (is_remove_) {
      td_->messages_manager_->on_update_dialog_background(dialog_id_, nullptr);
    }

    int32 flags = 0;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    if (input_wallpaper != nullptr) {
      flags |= telegram_api::messages_setChatWallPaper::WALLPAPER_MASK;
    }
    if (settings != nullptr) {
      flags |= telegram_api::messages_setChatWallPaper::SETTINGS_MASK;
    }
    if (old_message_id.is_valid()) {
      flags |= telegram_api::messages_setChatWallPaper::ID_MASK;
    }
    if (for_both) {
      flags |= telegram_api::messages_setChatWallPaper::FOR_BOTH_MASK;
    }
    if (revert) {
      flags |= telegram_api::messages_setChatWallPaper::REVERT_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_setChatWallPaper(
        flags, false /*ignored*/, false /*ignored*/, std::move(input_peer), std::move(input_wallpaper),
        std::move(settings), old_message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setChatWallPaper>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SetChatWallPaperQuery: " << to_string(ptr);
    if (is_remove_) {
      td_->messages_manager_->on_update_dialog_background(dialog_id_, nullptr);
    }
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (is_remove_) {
      td_->dialog_manager_->reload_dialog_info_full(dialog_id_, "SetChatWallPaperQuery");
    } else if (is_revert_ && status.message() == "WALLPAPER_NOT_FOUND") {
      return td_->background_manager_->delete_dialog_background(dialog_id_, false, std::move(promise_));
    }
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SetChatWallPaperQuery");
    promise_.set_error(std::move(status));
  }
};

class InstallBackgroundQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit InstallBackgroundQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputWallPaper> input_wallpaper, const BackgroundType &type) {
    send_query(G()->net_query_creator().create(
        telegram_api::account_installWallPaper(std::move(input_wallpaper), type.get_input_wallpaper_settings())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_installWallPaper>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG_IF(INFO, !result_ptr.ok()) << "Receive false from account.installWallPaper";
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class UploadBackgroundQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::background>> promise_;
  FileUploadId file_upload_id_;
  BackgroundType type_;
  DialogId dialog_id_;
  bool for_dark_theme_;

 public:
  explicit UploadBackgroundQuery(Promise<td_api::object_ptr<td_api::background>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
            const BackgroundType &type, DialogId dialog_id, bool for_dark_theme) {
    CHECK(input_file != nullptr);
    file_upload_id_ = file_upload_id;
    type_ = type;
    dialog_id_ = dialog_id;
    for_dark_theme_ = for_dark_theme;
    int32 flags = 0;
    if (dialog_id.is_valid()) {
      flags |= telegram_api::account_uploadWallPaper::FOR_CHAT_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::account_uploadWallPaper(
        flags, false /*ignored*/, std::move(input_file), type_.get_mime_type(), type_.get_input_wallpaper_settings())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_uploadWallPaper>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->background_manager_->on_uploaded_background_file(file_upload_id_, type_, dialog_id_, for_dark_theme_,
                                                          result_ptr.move_as_ok(), std::move(promise_));
  }

  void on_error(Status status) final {
    CHECK(file_upload_id_.is_valid());
    auto bad_parts = FileManager::get_missing_file_parts(status);
    if (!bad_parts.empty()) {
      // TODO td_->background_manager_->on_upload_background_file_parts_missing(file_upload_id_, std::move(bad_parts));
      // return;
    } else {
      td_->file_manager_->delete_partial_remote_location_if_needed(file_upload_id_, status);
    }
    td_->file_manager_->cancel_upload(file_upload_id_);
    promise_.set_error(std::move(status));
  }
};

class UnsaveBackgroundQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit UnsaveBackgroundQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputWallPaper> input_wallpaper) {
    send_query(G()->net_query_creator().create(telegram_api::account_saveWallPaper(
        std::move(input_wallpaper), true, telegram_api::make_object<telegram_api::wallPaperSettings>())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_saveWallPaper>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for save background: " << result;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for save background: " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class ResetBackgroundsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ResetBackgroundsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_resetWallPapers()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_resetWallPapers>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for reset backgrounds: " << result;
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for reset backgrounds: " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class BackgroundManager::UploadBackgroundFileCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->background_manager(), &BackgroundManager::on_upload_background_file, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->background_manager(), &BackgroundManager::on_upload_background_file_error, file_upload_id,
                       std::move(error));
  }
};

BackgroundManager::BackgroundManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_background_file_callback_ = std::make_shared<UploadBackgroundFileCallback>();
}

template <class StorerT>
void BackgroundManager::Background::store(StorerT &storer) const {
  bool has_file_id = file_id.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_creator);
  STORE_FLAG(is_default);
  STORE_FLAG(is_dark);
  STORE_FLAG(has_file_id);
  STORE_FLAG(has_new_local_id);
  END_STORE_FLAGS();
  td::store(id, storer);
  td::store(access_hash, storer);
  td::store(name, storer);
  if (has_file_id) {
    storer.context()->td().get_actor_unsafe()->documents_manager_->store_document(file_id, storer);
  }
  td::store(type, storer);
}

template <class ParserT>
void BackgroundManager::Background::parse(ParserT &parser) {
  bool has_file_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_creator);
  PARSE_FLAG(is_default);
  PARSE_FLAG(is_dark);
  PARSE_FLAG(has_file_id);
  PARSE_FLAG(has_new_local_id);
  END_PARSE_FLAGS();
  td::parse(id, parser);
  td::parse(access_hash, parser);
  td::parse(name, parser);
  if (has_file_id) {
    file_id = parser.context()->td().get_actor_unsafe()->documents_manager_->parse_document(parser);
  } else {
    file_id = FileId();
  }
  td::parse(type, parser);
}

class BackgroundManager::BackgroundLogEvent {
 public:
  Background background_;
  BackgroundType set_type_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(background_, storer);
    td::store(set_type_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(background_, parser);
    td::parse(set_type_, parser);
  }
};

class BackgroundManager::BackgroundsLogEvent {
 public:
  vector<Background> backgrounds_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(backgrounds_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(backgrounds_, parser);
  }
};

void BackgroundManager::start_up() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  max_local_background_id_ = BackgroundId(to_integer<int64>(G()->td_db()->get_binlog_pmc()->get("max_bg_id")));

  // first parse all log events and fix max_local_background_id_ value
  bool has_selected_background[2] = {false, false};
  BackgroundLogEvent selected_background_log_event[2];
  for (int i = 0; i < 2; i++) {
    bool for_dark_theme = i != 0;
    auto log_event_string = G()->td_db()->get_binlog_pmc()->get(get_background_database_key(for_dark_theme));
    if (!log_event_string.empty()) {
      has_selected_background[i] = true;
      log_event_parse(selected_background_log_event[i], log_event_string).ensure();
      const Background &background = selected_background_log_event[i].background_;
      if (background.has_new_local_id && background.id.is_local() && !background.type.has_file() &&
          background.id.get() > max_local_background_id_.get()) {
        set_max_local_background_id(background.id);
      }
      add_local_background_to_cache(background);
    }
  }

  for (int i = 0; i < 2; i++) {
    bool for_dark_theme = i != 0;
    auto log_event_string = G()->td_db()->get_binlog_pmc()->get(get_local_backgrounds_database_key(for_dark_theme));
    if (!log_event_string.empty()) {
      BackgroundsLogEvent log_event;
      log_event_parse(log_event, log_event_string).ensure();
      for (const auto &background : log_event.backgrounds_) {
        CHECK(background.has_new_local_id);
        CHECK(background.id.is_valid());
        CHECK(background.id.is_local());
        CHECK(!background.type.has_file());
        CHECK(!background.file_id.is_valid());
        if (background.id.get() > max_local_background_id_.get()) {
          set_max_local_background_id(background.id);
        }
        add_local_background_to_cache(background);
        add_background(background, true);
        local_background_ids_[for_dark_theme].push_back(background.id);
      }
    }
  }

  // then add selected backgrounds fixing their identifiers
  for (int i = 0; i < 2; i++) {
    bool for_dark_theme = i != 0;
    if (has_selected_background[i]) {
      Background &background = selected_background_log_event[i].background_;

      bool need_resave = false;
      if (!background.has_new_local_id && !background.type.has_file()) {
        background.has_new_local_id = true;
        set_local_background_id(background);
        need_resave = true;
      }

      CHECK(background.id.is_valid());
      if (background.file_id.is_valid() != background.type.has_file()) {
        LOG(ERROR) << "Failed to load " << background.id << " of " << background.type;
        need_resave = true;
      } else {
        set_background_id_[for_dark_theme] = background.id;
        set_background_type_[for_dark_theme] = selected_background_log_event[i].set_type_;

        add_background(background, false);
      }

      if (need_resave) {
        save_background_id(for_dark_theme);
      }
    }

    send_update_default_background(for_dark_theme);
  }
}

void BackgroundManager::tear_down() {
  parent_.reset();
}

void BackgroundManager::store_background(BackgroundId background_id, LogEventStorerCalcLength &storer) {
  const auto *background = get_background(background_id);
  CHECK(background != nullptr);
  store(*background, storer);
}

void BackgroundManager::store_background(BackgroundId background_id, LogEventStorerUnsafe &storer) {
  const auto *background = get_background(background_id);
  CHECK(background != nullptr);
  store(*background, storer);
}

void BackgroundManager::parse_background(BackgroundId &background_id, LogEventParser &parser) {
  Background background;
  parse(background, parser);
  if (!background.has_new_local_id || background.file_id.is_valid() != background.type.has_file() ||
      !background.id.is_valid()) {
    parser.set_error(PSTRING() << "Failed to load " << background.id);
    background_id = BackgroundId();
    return;
  }
  if (background.id.is_local() && !background.type.has_file() && background.id.get() > max_local_background_id_.get()) {
    set_max_local_background_id(background.id);
  }
  background_id = background.id;
  add_local_background_to_cache(background);
  add_background(background, false);
}

void BackgroundManager::get_backgrounds(bool for_dark_theme,
                                        Promise<td_api::object_ptr<td_api::backgrounds>> &&promise) {
  pending_get_backgrounds_queries_.emplace_back(for_dark_theme, std::move(promise));
  if (pending_get_backgrounds_queries_.size() == 1) {
    auto request_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::account_WallPapers>> result) {
          send_closure(actor_id, &BackgroundManager::on_get_backgrounds, std::move(result));
        });

    td_->create_handler<GetBackgroundsQuery>(std::move(request_promise))->send();
  }
}

void BackgroundManager::reload_background_from_server(
    BackgroundId background_id, const string &background_name,
    telegram_api::object_ptr<telegram_api::InputWallPaper> &&input_wallpaper, Promise<Unit> &&promise) const {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  td_->create_handler<GetBackgroundQuery>(std::move(promise))
      ->send(background_id, background_name, std::move(input_wallpaper));
}

void BackgroundManager::reload_background(BackgroundId background_id, int64 access_hash, Promise<Unit> &&promise) {
  reload_background_from_server(
      background_id, string(),
      telegram_api::make_object<telegram_api::inputWallPaper>(background_id.get(), access_hash), std::move(promise));
}

std::pair<BackgroundId, BackgroundType> BackgroundManager::search_background(const string &name,
                                                                             Promise<Unit> &&promise) {
  auto params_pos = name.find('?');
  string slug = params_pos >= name.size() ? name : name.substr(0, params_pos);
  auto it = name_to_background_id_.find(slug);
  if (it != name_to_background_id_.end()) {
    CHECK(!BackgroundType::is_background_name_local(slug));

    const auto *background = get_background(it->second);
    CHECK(background != nullptr);
    promise.set_value(Unit());
    BackgroundType type = background->type;
    type.apply_parameters_from_link(name);
    return {it->second, std::move(type)};
  }

  if (slug.empty()) {
    promise.set_error(Status::Error(400, "Background name must be non-empty"));
    return {};
  }

  if (BackgroundType::is_background_name_local(slug)) {
    auto r_type = BackgroundType::get_local_background_type(name);
    if (r_type.is_error()) {
      promise.set_error(r_type.move_as_error());
      return {};
    }
    auto background_id = add_local_background(r_type.ok());
    promise.set_value(Unit());
    return {background_id, r_type.ok()};
  }

  if (G()->use_sqlite_pmc() && loaded_from_database_backgrounds_.count(slug) == 0) {
    auto &queries = being_loaded_from_database_backgrounds_[slug];
    queries.push_back(std::move(promise));
    if (queries.size() == 1) {
      LOG(INFO) << "Trying to load background " << slug << " from database";
      G()->td_db()->get_sqlite_pmc()->get(
          get_background_name_database_key(slug), PromiseCreator::lambda([slug](string value) mutable {
            send_closure(G()->background_manager(), &BackgroundManager::on_load_background_from_database,
                         std::move(slug), std::move(value));
          }));
    }
    return {};
  }

  reload_background_from_server(BackgroundId(), slug, telegram_api::make_object<telegram_api::inputWallPaperSlug>(slug),
                                std::move(promise));
  return {};
}

void BackgroundManager::on_load_background_from_database(string name, string value) {
  if (G()->close_flag()) {
    return;
  }

  auto promises_it = being_loaded_from_database_backgrounds_.find(name);
  CHECK(promises_it != being_loaded_from_database_backgrounds_.end());
  auto promises = std::move(promises_it->second);
  CHECK(!promises.empty());
  being_loaded_from_database_backgrounds_.erase(promises_it);

  loaded_from_database_backgrounds_.insert(name);

  CHECK(!BackgroundType::is_background_name_local(name));
  if (name_to_background_id_.count(name) == 0 && !value.empty()) {
    LOG(INFO) << "Successfully loaded background " << name << " of size " << value.size() << " from database";
    Background background;
    auto status = log_event_parse(background, value);
    if (status.is_error() || !background.type.has_file() || !background.file_id.is_valid() ||
        !background.id.is_valid()) {
      LOG(ERROR) << "Can't load background " << name << ": " << status << ' ' << format::as_hex_dump<4>(Slice(value));
    } else {
      if (background.name != name) {
        LOG(ERROR) << "Expected background " << name << ", but received " << background.name;
        name_to_background_id_.emplace(std::move(name), background.id);
      }
      add_local_background_to_cache(background);
      add_background(background, false);
    }
  }

  set_promises(promises);
}

td_api::object_ptr<td_api::updateDefaultBackground> BackgroundManager::get_update_default_background_object(
    bool for_dark_theme) const {
  return td_api::make_object<td_api::updateDefaultBackground>(
      for_dark_theme,
      get_background_object(set_background_id_[for_dark_theme], for_dark_theme, &set_background_type_[for_dark_theme]));
}

void BackgroundManager::send_update_default_background(bool for_dark_theme) const {
  send_closure(G()->td(), &Td::send_update, get_update_default_background_object(for_dark_theme));
}

Result<FileId> BackgroundManager::prepare_input_file(const tl_object_ptr<td_api::InputFile> &input_file) {
  TRY_RESULT(file_id, td_->file_manager_->get_input_file_id(FileType::Background, input_file, {}, false, false));

  FileView file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.is_encrypted()) {
    return Status::Error(400, "Can't use encrypted file");
  }
  if (!file_view.has_full_local_location() && !file_view.has_generate_location()) {
    return Status::Error(400, "Need local or generate location to upload background");
  }
  return std::move(file_id);
}

void BackgroundManager::set_max_local_background_id(BackgroundId background_id) {
  CHECK(background_id.is_local());
  CHECK(background_id.get() > max_local_background_id_.get());
  max_local_background_id_ = background_id;
  G()->td_db()->get_binlog_pmc()->set("max_bg_id", to_string(max_local_background_id_.get()));
}

BackgroundId BackgroundManager::get_next_local_background_id() {
  set_max_local_background_id(BackgroundId(max_local_background_id_.get() + 1));
  return max_local_background_id_;
}

void BackgroundManager::set_local_background_id(Background &background) {
  CHECK(!background.name.empty() || background.type != BackgroundType());
  CHECK(background.has_new_local_id);
  auto &background_id = local_backgrounds_[background];
  if (!background_id.is_valid()) {
    background_id = get_next_local_background_id();
  }
  background.id = background_id;
}

void BackgroundManager::add_local_background_to_cache(const Background &background) {
  if (!background.has_new_local_id || !background.id.is_local()) {
    return;
  }
  auto &background_id = local_backgrounds_[background];
  if (!background_id.is_valid()) {
    background_id = background.id;
  }
}

BackgroundId BackgroundManager::add_local_background(const BackgroundType &type) {
  Background background;
  background.is_creator = true;
  background.is_default = false;
  background.is_dark = type.is_dark();
  background.type = type;
  background.name = type.get_link();
  set_local_background_id(background);
  add_background(background, true);

  return background.id;
}

void BackgroundManager::set_background(const td_api::InputBackground *input_background,
                                       const td_api::BackgroundType *background_type, bool for_dark_theme,
                                       Promise<td_api::object_ptr<td_api::background>> &&promise) {
  TRY_RESULT_PROMISE(promise, type, BackgroundType::get_background_type(background_type, 0));

  if (input_background == nullptr) {
    if (type.has_file() || background_type == nullptr) {
      return promise.set_error(Status::Error(400, "Input background must be non-empty for the background type"));
    }
    if (background_type->get_id() == td_api::backgroundTypeChatTheme::ID) {
      return promise.set_error(Status::Error(400, "Background type isn't supported"));
    }

    auto background_id = add_local_background(type);
    set_background_id(background_id, type, for_dark_theme);

    local_background_ids_[for_dark_theme].insert(local_background_ids_[for_dark_theme].begin(), background_id);
    save_local_backgrounds(for_dark_theme);

    return promise.set_value(get_background_object(background_id, for_dark_theme, nullptr));
  }

  switch (input_background->get_id()) {
    case td_api::inputBackgroundLocal::ID: {
      if (!type.has_file()) {
        return promise.set_error(Status::Error(400, "Can't specify local file for the background type"));
      }
      CHECK(background_type != nullptr);

      auto background_local = static_cast<const td_api::inputBackgroundLocal *>(input_background);
      TRY_RESULT_PROMISE(promise, file_id, prepare_input_file(background_local->background_));
      LOG(INFO) << "Receive file " << file_id << " for input background";
      CHECK(file_id.is_valid());

      auto it = file_id_to_background_id_.find(file_id);
      if (it != file_id_to_background_id_.end()) {
        return set_background(it->second, type, for_dark_theme, std::move(promise));
      }

      upload_background_file(file_id, type, DialogId(), for_dark_theme, std::move(promise));
      break;
    }
    case td_api::inputBackgroundRemote::ID: {
      auto background_remote = static_cast<const td_api::inputBackgroundRemote *>(input_background);
      return set_background(BackgroundId(background_remote->background_id_), std::move(type), for_dark_theme,
                            std::move(promise));
    }
    case td_api::inputBackgroundPrevious::ID:
      return promise.set_error(Status::Error(400, "Can't use a previous background"));
    default:
      UNREACHABLE();
  }
}

void BackgroundManager::delete_background(bool for_dark_theme, Promise<Unit> &&promise) {
  set_background_id(BackgroundId(), BackgroundType(), for_dark_theme);
  promise.set_value(Unit());
}

Result<DialogId> BackgroundManager::get_background_dialog(DialogId dialog_id) {
  TRY_STATUS(td_->dialog_manager_->check_dialog_access(dialog_id, true, AccessRights::Write, "get_background_dialog"));

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return dialog_id;
    case DialogType::Chat:
      return Status::Error(400, "Can't change background in the chat");
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      if (!td_->chat_manager_->get_channel_permissions(channel_id).can_change_info_and_settings_as_administrator()) {
        return Status::Error(400, "Not enough rights in the chat");
      }
      return dialog_id;
    }
    case DialogType::SecretChat: {
      auto user_id = td_->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
      if (!user_id.is_valid()) {
        return Status::Error(400, "Can't access the user");
      }
      return DialogId(user_id);
    }
    case DialogType::None:
    default:
      UNREACHABLE();
      return DialogId();
  }
}

void BackgroundManager::set_dialog_background(DialogId dialog_id, const td_api::InputBackground *input_background,
                                              const td_api::BackgroundType *background_type, int32 dark_theme_dimming,
                                              bool for_both, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE_ASSIGN(promise, dialog_id, get_background_dialog(dialog_id));

  TRY_RESULT_PROMISE(promise, type, BackgroundType::get_background_type(background_type, dark_theme_dimming));

  if (input_background == nullptr) {
    if (type.has_file() || background_type == nullptr) {
      return promise.set_error(Status::Error(400, "Input background must be non-empty for the background type"));
    }
    return send_set_dialog_background_query(dialog_id, telegram_api::make_object<telegram_api::inputWallPaperNoFile>(0),
                                            type.get_input_wallpaper_settings(), MessageId(), for_both,
                                            std::move(promise));
  }

  switch (input_background->get_id()) {
    case td_api::inputBackgroundLocal::ID: {
      if (!type.has_file()) {
        return promise.set_error(Status::Error(400, "Can't specify local file for the background type"));
      }
      CHECK(background_type != nullptr);

      auto background_local = static_cast<const td_api::inputBackgroundLocal *>(input_background);
      TRY_RESULT_PROMISE(promise, file_id, prepare_input_file(background_local->background_));
      LOG(INFO) << "Receive file " << file_id << " for input background";
      CHECK(file_id.is_valid());

      auto it = file_id_to_background_id_.find(file_id);
      if (it != file_id_to_background_id_.end()) {
        return do_set_dialog_background(dialog_id, it->second, type, for_both, std::move(promise));
      }

      auto upload_promise =
          PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, type, for_both, promise = std::move(promise)](
                                     Result<td_api::object_ptr<td_api::background>> &&result) mutable {
            if (result.is_error()) {
              return promise.set_error(result.move_as_error());
            }
            send_closure(actor_id, &BackgroundManager::do_set_dialog_background, dialog_id,
                         BackgroundId(result.ok()->id_), std::move(type), for_both, std::move(promise));
          });
      upload_background_file(file_id, type, dialog_id, false, std::move(upload_promise));
      break;
    }
    case td_api::inputBackgroundRemote::ID: {
      auto background_remote = static_cast<const td_api::inputBackgroundRemote *>(input_background);
      return do_set_dialog_background(dialog_id, BackgroundId(background_remote->background_id_), std::move(type),
                                      for_both, std::move(promise));
    }
    case td_api::inputBackgroundPrevious::ID: {
      auto background_previous = static_cast<const td_api::inputBackgroundPrevious *>(input_background);
      MessageId message_id(background_previous->message_id_);
      if (!message_id.is_valid() || !message_id.is_server()) {
        return promise.set_error(Status::Error(400, "Invalid message identifier specified"));
      }
      return send_set_dialog_background_query(
          dialog_id, nullptr, background_type == nullptr ? nullptr : type.get_input_wallpaper_settings(), message_id,
          for_both, std::move(promise));
    }
    default:
      UNREACHABLE();
  }
}

void BackgroundManager::delete_dialog_background(DialogId dialog_id, bool restore_previous, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE_ASSIGN(promise, dialog_id, get_background_dialog(dialog_id));
  td_->create_handler<SetChatWallPaperQuery>(std::move(promise))
      ->send(dialog_id, nullptr, nullptr, MessageId(), false, restore_previous);
}

void BackgroundManager::do_set_dialog_background(DialogId dialog_id, BackgroundId background_id, BackgroundType type,
                                                 bool for_both, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  const auto *background = get_background(background_id);
  if (background == nullptr) {
    return promise.set_error(Status::Error(400, "Background to set not found"));
  }
  if (!type.has_file()) {
    type = background->type;
  } else if (!background->type.has_equal_type(type)) {
    return promise.set_error(Status::Error(400, "Background type mismatch"));
  }

  send_set_dialog_background_query(
      dialog_id, telegram_api::make_object<telegram_api::inputWallPaper>(background_id.get(), background->access_hash),
      type.get_input_wallpaper_settings(), MessageId(), for_both, std::move(promise));
}

void BackgroundManager::send_set_dialog_background_query(
    DialogId dialog_id, telegram_api::object_ptr<telegram_api::InputWallPaper> input_wallpaper,
    telegram_api::object_ptr<telegram_api::wallPaperSettings> settings, MessageId old_message_id, bool for_both,
    Promise<Unit> &&promise) {
  td_->create_handler<SetChatWallPaperQuery>(std::move(promise))
      ->send(dialog_id, std::move(input_wallpaper), std::move(settings), old_message_id, for_both, false);
}

void BackgroundManager::set_background(BackgroundId background_id, BackgroundType type, bool for_dark_theme,
                                       Promise<td_api::object_ptr<td_api::background>> &&promise) {
  LOG(INFO) << "Set " << background_id << " with " << type;
  const auto *background = get_background(background_id);
  if (background == nullptr) {
    return promise.set_error(Status::Error(400, "Background to set not found"));
  }
  if (!type.has_file()) {
    type = background->type;
  } else if (!background->type.has_equal_type(type)) {
    return promise.set_error(Status::Error(400, "Background type mismatch"));
  }
  if (set_background_id_[for_dark_theme] == background_id && set_background_type_[for_dark_theme] == type) {
    return promise.set_value(get_background_object(background_id, for_dark_theme, nullptr));
  }

  LOG(INFO) << "Install " << background_id << " with " << type;

  if (!type.has_file()) {
    set_background_id(background_id, type, for_dark_theme);
    return promise.set_value(get_background_object(background_id, for_dark_theme, nullptr));
  }

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), background_id, type, for_dark_theme,
                                               promise = std::move(promise)](Result<Unit> &&result) mutable {
    send_closure(actor_id, &BackgroundManager::on_installed_background, background_id, type, for_dark_theme,
                 std::move(result), std::move(promise));
  });
  td_->create_handler<InstallBackgroundQuery>(std::move(query_promise))
      ->send(telegram_api::make_object<telegram_api::inputWallPaper>(background_id.get(), background->access_hash),
             type);
}

void BackgroundManager::on_installed_background(BackgroundId background_id, BackgroundType type, bool for_dark_theme,
                                                Result<Unit> &&result,
                                                Promise<td_api::object_ptr<td_api::background>> &&promise) {
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }

  size_t i;
  for (i = 0; i < installed_backgrounds_.size(); i++) {
    if (installed_backgrounds_[i].first == background_id) {
      installed_backgrounds_[i].second = type;
      break;
    }
  }
  if (i == installed_backgrounds_.size()) {
    installed_backgrounds_.insert(installed_backgrounds_.begin(), {background_id, type});
  }
  set_background_id(background_id, type, for_dark_theme);
  promise.set_value(get_background_object(background_id, for_dark_theme, nullptr));
}

string BackgroundManager::get_background_database_key(bool for_dark_theme) {
  return for_dark_theme ? "bgd" : "bg";
}

string BackgroundManager::get_local_backgrounds_database_key(bool for_dark_theme) {
  return for_dark_theme ? "bgsd" : "bgs";
}

void BackgroundManager::save_background_id(bool for_dark_theme) {
  string key = get_background_database_key(for_dark_theme);
  auto background_id = set_background_id_[for_dark_theme];
  if (background_id.is_valid()) {
    const Background *background = get_background(background_id);
    CHECK(background != nullptr);
    BackgroundLogEvent log_event{*background, set_background_type_[for_dark_theme]};
    G()->td_db()->get_binlog_pmc()->set(key, log_event_store(log_event).as_slice().str());
  } else {
    G()->td_db()->get_binlog_pmc()->erase(key);
  }
}

void BackgroundManager::set_background_id(BackgroundId background_id, const BackgroundType &type, bool for_dark_theme) {
  if (background_id == set_background_id_[for_dark_theme] && set_background_type_[for_dark_theme] == type) {
    return;
  }

  set_background_id_[for_dark_theme] = background_id;
  set_background_type_[for_dark_theme] = type;

  save_background_id(for_dark_theme);
  send_update_default_background(for_dark_theme);
}

void BackgroundManager::save_local_backgrounds(bool for_dark_theme) {
  string key = get_local_backgrounds_database_key(for_dark_theme);
  auto &background_ids = local_background_ids_[for_dark_theme];
  const size_t MAX_LOCAL_BACKGROUNDS = 100;
  while (background_ids.size() > MAX_LOCAL_BACKGROUNDS) {
    background_ids.pop_back();
  }
  if (!background_ids.empty()) {
    BackgroundsLogEvent log_event;
    log_event.backgrounds_ = transform(background_ids, [&](BackgroundId background_id) {
      const Background *background = get_background(background_id);
      CHECK(background != nullptr);
      return *background;
    });
    G()->td_db()->get_binlog_pmc()->set(key, log_event_store(log_event).as_slice().str());
  } else {
    G()->td_db()->get_binlog_pmc()->erase(key);
  }
}

void BackgroundManager::upload_background_file(FileId file_id, const BackgroundType &type, DialogId dialog_id,
                                               bool for_dark_theme,
                                               Promise<td_api::object_ptr<td_api::background>> &&promise) {
  auto file_upload_id = FileUploadId{file_id, FileManager::get_internal_upload_id()};
  CHECK(file_upload_id.is_valid());
  bool is_inserted = being_uploaded_files_
                         .emplace(file_upload_id, UploadedFileInfo(type, dialog_id, for_dark_theme, std::move(promise)))
                         .second;
  CHECK(is_inserted);
  LOG(INFO) << "Ask to upload background " << file_upload_id;
  td_->file_manager_->upload(file_upload_id, upload_background_file_callback_, 1, 0);
}

void BackgroundManager::on_upload_background_file(FileUploadId file_upload_id,
                                                  telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Background " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());

  auto type = it->second.type_;
  auto dialog_id = it->second.dialog_id_;
  auto for_dark_theme = it->second.for_dark_theme_;
  auto promise = std::move(it->second.promise_);

  being_uploaded_files_.erase(it);

  do_upload_background_file(file_upload_id, type, dialog_id, for_dark_theme, std::move(input_file), std::move(promise));
}

void BackgroundManager::on_upload_background_file_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(WARNING) << "Background " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());

  auto promise = std::move(it->second.promise_);

  being_uploaded_files_.erase(it);

  promise.set_error(Status::Error(status.code() > 0 ? status.code() : 500,
                                  status.message()));  // TODO CHECK that status has always a code
}

void BackgroundManager::do_upload_background_file(FileUploadId file_upload_id, const BackgroundType &type,
                                                  DialogId dialog_id, bool for_dark_theme,
                                                  telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
                                                  Promise<td_api::object_ptr<td_api::background>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  if (input_file == nullptr) {
    FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
    auto it = file_id_to_background_id_.find(file_view.get_main_file_id());
    if (it != file_id_to_background_id_.end()) {
      if (dialog_id.is_valid()) {
        return promise.set_value(get_background_object(it->second, for_dark_theme, nullptr));
      }
      return set_background(it->second, type, for_dark_theme, std::move(promise));
    }
    return promise.set_error(Status::Error(500, "Failed to reupload background"));
  }

  td_->create_handler<UploadBackgroundQuery>(std::move(promise))
      ->send(file_upload_id, std::move(input_file), type, dialog_id, for_dark_theme);
}

void BackgroundManager::on_uploaded_background_file(FileUploadId file_upload_id, const BackgroundType &type,
                                                    DialogId dialog_id, bool for_dark_theme,
                                                    telegram_api::object_ptr<telegram_api::WallPaper> wallpaper,
                                                    Promise<td_api::object_ptr<td_api::background>> &&promise) {
  CHECK(wallpaper != nullptr);

  auto added_background = on_get_background(BackgroundId(), string(), std::move(wallpaper), true, false);
  auto background_id = added_background.first;
  if (!background_id.is_valid()) {
    td_->file_manager_->cancel_upload(file_upload_id);
    return promise.set_error(Status::Error(500, "Receive wrong uploaded background"));
  }
  LOG_IF(ERROR, added_background.second != type)
      << "Type of uploaded background has changed from " << type << " to " << added_background.second;

  const auto *background = get_background(background_id);
  CHECK(background != nullptr);
  if (!background->file_id.is_valid()) {
    td_->file_manager_->cancel_upload(file_upload_id);
    return promise.set_error(Status::Error(500, "Receive wrong uploaded background without file"));
  }
  LOG_STATUS(td_->file_manager_->merge(background->file_id, file_upload_id.get_file_id()));
  td_->file_manager_->cancel_upload(file_upload_id);
  if (!dialog_id.is_valid()) {
    set_background_id(background_id, type, for_dark_theme);
  }
  promise.set_value(get_background_object(background_id, for_dark_theme, nullptr));
}

void BackgroundManager::remove_background(BackgroundId background_id, Promise<Unit> &&promise) {
  const auto *background = get_background(background_id);
  if (background == nullptr) {
    return promise.set_error(Status::Error(400, "Background not found"));
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), background_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        send_closure(actor_id, &BackgroundManager::on_removed_background, background_id, std::move(result),
                     std::move(promise));
      });

  if (!background->type.has_file()) {
    if (!background->id.is_local()) {
      return td_->create_handler<UnsaveBackgroundQuery>(std::move(query_promise))
          ->send(telegram_api::make_object<telegram_api::inputWallPaperNoFile>(background_id.get()));
    } else {
      return query_promise.set_value(Unit());
    }
  }

  td_->create_handler<UnsaveBackgroundQuery>(std::move(query_promise))
      ->send(telegram_api::make_object<telegram_api::inputWallPaper>(background_id.get(), background->access_hash));
}

void BackgroundManager::on_removed_background(BackgroundId background_id, Result<Unit> &&result,
                                              Promise<Unit> &&promise) {
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }
  td::remove_if(installed_backgrounds_,
                [background_id](const auto &background) { return background.first == background_id; });
  if (background_id == set_background_id_[0]) {
    set_background_id(BackgroundId(), BackgroundType(), false);
  }
  if (background_id == set_background_id_[1]) {
    set_background_id(BackgroundId(), BackgroundType(), true);
  }
  if (background_id.is_local()) {
    if (td::remove(local_background_ids_[0], background_id)) {
      save_local_backgrounds(false);
    }
    if (td::remove(local_background_ids_[1], background_id)) {
      save_local_backgrounds(true);
    }
  }
  promise.set_value(Unit());
}

void BackgroundManager::reset_backgrounds(Promise<Unit> &&promise) {
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise)](Result<Unit> &&result) mutable {
        send_closure(actor_id, &BackgroundManager::on_reset_background, std::move(result), std::move(promise));
      });

  td_->create_handler<ResetBackgroundsQuery>(std::move(query_promise))->send();
}

void BackgroundManager::on_reset_background(Result<Unit> &&result, Promise<Unit> &&promise) {
  if (result.is_error()) {
    return promise.set_error(result.move_as_error());
  }
  installed_backgrounds_.clear();
  set_background_id(BackgroundId(), BackgroundType(), false);
  set_background_id(BackgroundId(), BackgroundType(), true);
  if (!local_background_ids_[0].empty()) {
    local_background_ids_[0].clear();
    save_local_backgrounds(false);
  }
  if (!local_background_ids_[1].empty()) {
    local_background_ids_[1].clear();
    save_local_backgrounds(true);
  }

  promise.set_value(Unit());
}

void BackgroundManager::add_background(const Background &background, bool replace_type) {
  LOG(INFO) << "Add " << background.id << " of " << background.type;

  CHECK(background.id.is_valid());
  auto &result_ptr = backgrounds_[background.id];
  if (result_ptr == nullptr) {
    result_ptr = make_unique<Background>();
  }
  auto *result = result_ptr.get();

  FileSourceId file_source_id;
  auto it = background_id_to_file_source_id_.find(background.id);
  if (it != background_id_to_file_source_id_.end()) {
    CHECK(!result->id.is_valid());
    file_source_id = it->second.second;
    background_id_to_file_source_id_.erase(it);
  }

  if (!result->id.is_valid()) {
    result->id = background.id;
    result->type = background.type;
  } else {
    CHECK(result->id == background.id);
    if (replace_type) {
      result->type = background.type;
    }
  }
  result->access_hash = background.access_hash;
  result->is_creator = background.is_creator;
  result->is_default = background.is_default;
  result->is_dark = background.is_dark;

  if (result->name != background.name) {
    if (!result->name.empty()) {
      LOG(ERROR) << "Background name has changed from " << result->name << " to " << background.name;
      // keep correspondence from previous name to background ID
      // it will not harm, because background names can't be reassigned
      // name_to_background_id_.erase(result->name);
    }

    result->name = background.name;

    if (!BackgroundType::is_background_name_local(result->name)) {
      name_to_background_id_.emplace(result->name, result->id);
      loaded_from_database_backgrounds_.erase(result->name);  // don't needed anymore
    }
  }

  if (result->file_id != background.file_id) {
    if (result->file_id.is_valid()) {
      if (!background.file_id.is_valid() ||
          td_->file_manager_->get_file_view(result->file_id).get_main_file_id() !=
              td_->file_manager_->get_file_view(background.file_id).get_main_file_id()) {
        LOG(ERROR) << "Background file has changed from " << result->file_id << " to " << background.file_id;
        file_id_to_background_id_.erase(result->file_id);
        result->file_source_id = FileSourceId();
      }
      CHECK(!file_source_id.is_valid());
    }
    if (file_source_id.is_valid()) {
      result->file_source_id = file_source_id;
    }

    result->file_id = background.file_id;

    if (result->file_id.is_valid()) {
      if (!result->file_source_id.is_valid()) {
        result->file_source_id =
            td_->file_reference_manager_->create_background_file_source(result->id, result->access_hash);
      }
      for (auto file_id : Document(Document::Type::General, result->file_id).get_file_ids(td_)) {
        td_->file_manager_->add_file_source(file_id, result->file_source_id, "add_background");
      }

      file_id_to_background_id_.emplace(result->file_id, result->id);
    }
  } else {
    // if file_source_id is valid, then this is a new background with result->file_id == FileId()
    // then background.file_id == FileId(), then this is a fill background, which can't have file_source_id
    CHECK(!file_source_id.is_valid());
  }
}

BackgroundManager::Background *BackgroundManager::get_background_ref(BackgroundId background_id) {
  auto p = backgrounds_.find(background_id);
  if (p == backgrounds_.end()) {
    return nullptr;
  } else {
    return p->second.get();
  }
}

const BackgroundManager::Background *BackgroundManager::get_background(BackgroundId background_id) const {
  auto p = backgrounds_.find(background_id);
  if (p == backgrounds_.end()) {
    return nullptr;
  } else {
    return p->second.get();
  }
}

string BackgroundManager::get_background_name_database_key(const string &name) {
  return PSTRING() << "bgn" << name;
}

std::pair<BackgroundId, BackgroundType> BackgroundManager::on_get_background(
    BackgroundId expected_background_id, const string &expected_background_name,
    telegram_api::object_ptr<telegram_api::WallPaper> wallpaper_ptr, bool replace_type, bool allow_empty) {
  if (wallpaper_ptr == nullptr) {
    if (!allow_empty) {
      LOG(ERROR) << "Receive unexpected empty background";
    }
    return {};
  }

  if (wallpaper_ptr->get_id() == telegram_api::wallPaperNoFile::ID) {
    auto wallpaper = move_tl_object_as<telegram_api::wallPaperNoFile>(wallpaper_ptr);

    if (wallpaper->settings_ == nullptr) {
      if (!allow_empty) {
        LOG(ERROR) << "Receive wallPaperNoFile without settings: " << to_string(wallpaper);
      }
      return {};
    }

    auto background_id = BackgroundId(wallpaper->id_);
    if (background_id.is_local()) {
      LOG(ERROR) << "Receive " << to_string(wallpaper);
      return {};
    }

    Background background;
    background.id = background_id;
    background.is_creator = false;
    background.is_default = wallpaper->default_;
    background.is_dark = wallpaper->dark_;
    background.type = BackgroundType(true, false, std::move(wallpaper->settings_));
    background.name = background.type.get_link();
    if (!background.id.is_valid()) {
      set_local_background_id(background);
    }
    add_background(background, replace_type);

    return {background.id, background.type};
  }

  auto wallpaper = move_tl_object_as<telegram_api::wallPaper>(wallpaper_ptr);
  auto background_id = BackgroundId(wallpaper->id_);
  if (!background_id.is_valid() || background_id.is_local() ||
      BackgroundType::is_background_name_local(wallpaper->slug_)) {
    LOG(ERROR) << "Receive " << to_string(wallpaper);
    return {};
  }
  if (expected_background_id.is_valid() && background_id != expected_background_id) {
    LOG(ERROR) << "Expected " << expected_background_id << ", but receive " << to_string(wallpaper);
  }

  int32 document_id = wallpaper->document_->get_id();
  if (document_id == telegram_api::documentEmpty::ID) {
    if (!allow_empty) {
      LOG(ERROR) << "Receive " << to_string(wallpaper);
    }
    return {};
  }
  CHECK(document_id == telegram_api::document::ID);

  bool is_pattern = wallpaper->pattern_;

  Document document = td_->documents_manager_->on_get_document(
      telegram_api::move_object_as<telegram_api::document>(wallpaper->document_), DialogId(), false, nullptr,
      Document::Type::General, is_pattern ? DocumentsManager::Subtype::Pattern : DocumentsManager::Subtype::Background);
  if (!document.file_id.is_valid()) {
    LOG(ERROR) << "Receive wrong document in " << to_string(wallpaper);
    return {};
  }
  CHECK(document.type == Document::Type::General);  // guaranteed by is_background parameter to on_get_document

  Background background;
  background.id = background_id;
  background.access_hash = wallpaper->access_hash_;
  background.is_creator = wallpaper->creator_;
  background.is_default = wallpaper->default_;
  background.is_dark = wallpaper->dark_;
  background.type = BackgroundType(false, is_pattern, std::move(wallpaper->settings_));
  background.name = std::move(wallpaper->slug_);
  background.file_id = document.file_id;
  add_background(background, replace_type);

  if (!expected_background_name.empty() && background.name != expected_background_name) {
    LOG(ERROR) << "Expected background " << expected_background_name << ", but receive " << background.name;
    name_to_background_id_.emplace(expected_background_name, background_id);
  }

  if (G()->use_sqlite_pmc()) {
    LOG(INFO) << "Save " << background_id << " to database with name " << background.name;
    CHECK(!BackgroundType::is_background_name_local(background.name));
    G()->td_db()->get_sqlite_pmc()->set(get_background_name_database_key(background.name),
                                        log_event_store(background).as_slice().str(), Auto());
  }

  return {background_id, background.type};
}

void BackgroundManager::on_get_backgrounds(Result<telegram_api::object_ptr<telegram_api::account_WallPapers>> result) {
  auto promises = std::move(pending_get_backgrounds_queries_);
  CHECK(!promises.empty());
  reset_to_empty(pending_get_backgrounds_queries_);

  if (result.is_error()) {
    // do not clear installed_backgrounds_

    auto error = result.move_as_error();
    for (auto &promise : promises) {
      promise.second.set_error(error.clone());
    }
    return;
  }

  auto wallpapers_ptr = result.move_as_ok();
  LOG(INFO) << "Receive " << to_string(wallpapers_ptr);
  if (wallpapers_ptr->get_id() == telegram_api::account_wallPapersNotModified::ID) {
    for (auto &promise : promises) {
      promise.second.set_value(get_backgrounds_object(promise.first));
    }
    return;
  }

  installed_backgrounds_.clear();
  auto wallpapers = telegram_api::move_object_as<telegram_api::account_wallPapers>(wallpapers_ptr);
  for (auto &wallpaper : wallpapers->wallpapers_) {
    auto background = on_get_background(BackgroundId(), string(), std::move(wallpaper), false, false);
    if (background.first.is_valid()) {
      installed_backgrounds_.push_back(std::move(background));
    }
  }

  for (auto &promise : promises) {
    promise.second.set_value(get_backgrounds_object(promise.first));
  }
}

td_api::object_ptr<td_api::background> BackgroundManager::get_background_object(BackgroundId background_id,
                                                                                bool for_dark_theme,
                                                                                const BackgroundType *type) const {
  const auto *background = get_background(background_id);
  if (background == nullptr) {
    return nullptr;
  }
  if (type == nullptr) {
    type = &background->type;
    // first check another set_background_id to get correct type if both backgrounds are the same
    if (background_id == set_background_id_[1 - static_cast<int>(for_dark_theme)]) {
      type = &set_background_type_[1 - static_cast<int>(for_dark_theme)];
    }
    if (background_id == set_background_id_[for_dark_theme]) {
      type = &set_background_type_[for_dark_theme];
    }
  }
  return td_api::make_object<td_api::background>(
      background->id.get(), background->is_default, background->is_dark, background->name,
      td_->documents_manager_->get_document_object(background->file_id, PhotoFormat::Png),
      type->get_background_type_object());
}

td_api::object_ptr<td_api::backgrounds> BackgroundManager::get_backgrounds_object(bool for_dark_theme) const {
  auto backgrounds = transform(installed_backgrounds_,
                               [this, for_dark_theme](const std::pair<BackgroundId, BackgroundType> &background) {
                                 return get_background_object(background.first, for_dark_theme, &background.second);
                               });
  auto background_id = set_background_id_[for_dark_theme];
  bool have_background = false;
  for (const auto &background : installed_backgrounds_) {
    if (background_id == background.first) {
      have_background = true;
      break;
    }
  }
  if (background_id.is_valid() && !have_background) {
    backgrounds.push_back(get_background_object(background_id, for_dark_theme, nullptr));
  }
  for (auto local_background_id : local_background_ids_[for_dark_theme]) {
    if (local_background_id != background_id) {
      backgrounds.push_back(get_background_object(local_background_id, for_dark_theme, nullptr));
    }
  }
  std::stable_sort(backgrounds.begin(), backgrounds.end(),
                   [background_id, for_dark_theme](const td_api::object_ptr<td_api::background> &lhs,
                                                   const td_api::object_ptr<td_api::background> &rhs) {
                     auto get_order = [background_id,
                                       for_dark_theme](const td_api::object_ptr<td_api::background> &background) {
                       if (background->id_ == background_id.get()) {
                         return 0;
                       }
                       int theme_score = background->is_dark_ == for_dark_theme ? 0 : 1;
                       int local_score = BackgroundId(background->id_).is_local() ? 0 : 2;
                       return 1 + local_score + theme_score;
                     };
                     return get_order(lhs) < get_order(rhs);
                   });
  return td_api::make_object<td_api::backgrounds>(std::move(backgrounds));
}

FileSourceId BackgroundManager::get_background_file_source_id(BackgroundId background_id, int64 access_hash) {
  if (!background_id.is_valid()) {
    return FileSourceId();
  }

  Background *background = get_background_ref(background_id);
  if (background != nullptr) {
    if (!background->file_source_id.is_valid()) {
      background->file_source_id =
          td_->file_reference_manager_->create_background_file_source(background_id, background->access_hash);
    }
    return background->file_source_id;
  }

  auto &result = background_id_to_file_source_id_[background_id];
  if (result.first == 0) {
    result.first = access_hash;
  }
  if (!result.second.is_valid()) {
    result.second = td_->file_reference_manager_->create_background_file_source(background_id, result.first);
  }
  return result.second;
}

void BackgroundManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  updates.push_back(get_update_default_background_object(false));
  updates.push_back(get_update_default_background_object(true));
}

}  // namespace td
