//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BotInfoManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/misc.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/StoryContent.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

#include <algorithm>
#include <type_traits>

namespace td {

class GetAdminedBotsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::users>> promise_;
  UserId bot_user_id_;

 public:
  explicit GetAdminedBotsQuery(Promise<td_api::object_ptr<td_api::users>> &&promise) : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::bots_getAdminedBots()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_getAdminedBots>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto users = result_ptr.move_as_ok();
    auto user_ids = td_->user_manager_->get_user_ids(std::move(users), "GetAdminedBotsQuery");
    promise_.set_value(td_->user_manager_->get_users_object(-1, user_ids));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SetBotGroupDefaultAdminRightsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetBotGroupDefaultAdminRightsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(AdministratorRights administrator_rights) {
    send_query(G()->net_query_creator().create(
        telegram_api::bots_setBotGroupDefaultAdminRights(administrator_rights.get_chat_admin_rights()), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_setBotGroupDefaultAdminRights>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to set group default administrator rights";
    td_->user_manager_->invalidate_user_full(td_->user_manager_->get_my_id());
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "RIGHTS_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    td_->user_manager_->invalidate_user_full(td_->user_manager_->get_my_id());
    promise_.set_error(std::move(status));
  }
};

class SetBotBroadcastDefaultAdminRightsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SetBotBroadcastDefaultAdminRightsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(AdministratorRights administrator_rights) {
    send_query(G()->net_query_creator().create(
        telegram_api::bots_setBotBroadcastDefaultAdminRights(administrator_rights.get_chat_admin_rights()), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_setBotBroadcastDefaultAdminRights>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to set channel default administrator rights";
    td_->user_manager_->invalidate_user_full(td_->user_manager_->get_my_id());
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (status.message() == "RIGHTS_NOT_MODIFIED") {
      return promise_.set_value(Unit());
    }
    td_->user_manager_->invalidate_user_full(td_->user_manager_->get_my_id());
    promise_.set_error(std::move(status));
  }
};

static td_api::object_ptr<td_api::botMediaPreview> convert_bot_media_preview(
    Td *td, telegram_api::object_ptr<telegram_api::botPreviewMedia> media, UserId bot_user_id,
    vector<FileId> &file_ids) {
  auto content = get_story_content(td, std::move(media->media_), DialogId(bot_user_id));
  if (content == nullptr) {
    LOG(ERROR) << "Receive invalid media preview for " << bot_user_id;
    return nullptr;
  }
  append(file_ids, get_story_content_file_ids(td, content.get()));
  return td_api::make_object<td_api::botMediaPreview>(max(media->date_, 0),
                                                      get_story_content_object(td, content.get()));
}

class GetPreviewMediasQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::botMediaPreviews>> promise_;
  UserId bot_user_id_;

 public:
  explicit GetPreviewMediasQuery(Promise<td_api::object_ptr<td_api::botMediaPreviews>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, telegram_api::object_ptr<telegram_api::InputUser> input_user) {
    bot_user_id_ = bot_user_id;
    send_query(
        G()->net_query_creator().create(telegram_api::bots_getPreviewMedias(std::move(input_user)), {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_getPreviewMedias>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPreviewMediasQuery: " << to_string(ptr);
    vector<td_api::object_ptr<td_api::botMediaPreview>> previews;
    vector<FileId> file_ids;
    for (auto &media : ptr) {
      auto preview = convert_bot_media_preview(td_, std::move(media), bot_user_id_, file_ids);
      if (preview != nullptr) {
        previews.push_back(std::move(preview));
      }
    }
    if (!file_ids.empty()) {
      auto file_source_id = td_->bot_info_manager_->get_bot_media_preview_file_source_id(bot_user_id_);
      for (auto file_id : file_ids) {
        td_->file_manager_->add_file_source(file_id, file_source_id, "GetPreviewMediasQuery");
      }
    }
    td_->user_manager_->on_update_bot_has_preview_medias(bot_user_id_, !previews.empty());
    promise_.set_value(td_api::make_object<td_api::botMediaPreviews>(std::move(previews)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class GetPreviewInfoQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::botMediaPreviewInfo>> promise_;
  UserId bot_user_id_;
  string language_code_;

 public:
  explicit GetPreviewInfoQuery(Promise<td_api::object_ptr<td_api::botMediaPreviewInfo>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, telegram_api::object_ptr<telegram_api::InputUser> input_user,
            const string &language_code) {
    bot_user_id_ = bot_user_id;
    language_code_ = language_code;
    send_query(G()->net_query_creator().create(telegram_api::bots_getPreviewInfo(std::move(input_user), language_code),
                                               {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_getPreviewInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetPreviewInfoQuery: " << to_string(ptr);
    vector<td_api::object_ptr<td_api::botMediaPreview>> previews;
    vector<FileId> file_ids;
    for (auto &media : ptr->media_) {
      auto preview = convert_bot_media_preview(td_, std::move(media), bot_user_id_, file_ids);
      if (preview != nullptr) {
        previews.push_back(std::move(preview));
      }
    }
    if (!file_ids.empty()) {
      auto file_source_id =
          td_->bot_info_manager_->get_bot_media_preview_info_file_source_id(bot_user_id_, language_code_);
      for (auto file_id : file_ids) {
        td_->file_manager_->add_file_source(file_id, file_source_id, "GetPreviewInfoQuery");
      }
    }
    promise_.set_value(
        td_api::make_object<td_api::botMediaPreviewInfo>(std::move(previews), std::move(ptr->lang_codes_)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class BotInfoManager::AddPreviewMediaQuery final : public Td::ResultHandler {
  unique_ptr<PendingBotMediaPreview> pending_preview_;

 public:
  void send(telegram_api::object_ptr<telegram_api::InputUser> input_user,
            unique_ptr<PendingBotMediaPreview> pending_preview,
            telegram_api::object_ptr<telegram_api::InputFile> input_file) {
    pending_preview_ = std::move(pending_preview);
    CHECK(pending_preview_ != nullptr);
    CHECK(pending_preview_->file_upload_id_.is_valid());

    const StoryContent *content = pending_preview_->content_.get();
    CHECK(input_file != nullptr);
    auto input_media = get_story_content_input_media(td_, content, std::move(input_file));
    CHECK(input_media != nullptr);
    if (pending_preview_->edited_file_id_.is_valid()) {
      auto edited_input_media = td_->bot_info_manager_->get_fake_input_media(pending_preview_->edited_file_id_);
      if (edited_input_media == nullptr) {
        return on_error(Status::Error(400, "Wrong media to edit specified"));
      }
      send_query(G()->net_query_creator().create(
          telegram_api::bots_editPreviewMedia(std::move(input_user), pending_preview_->language_code_,
                                              std::move(edited_input_media), std::move(input_media)),
          {{pending_preview_->bot_user_id_}}));
    } else {
      send_query(G()->net_query_creator().create(
          telegram_api::bots_addPreviewMedia(std::move(input_user), pending_preview_->language_code_,
                                             std::move(input_media)),
          {{pending_preview_->bot_user_id_}}));
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::bots_addPreviewMedia::ReturnType,
                               telegram_api::bots_editPreviewMedia::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::bots_addPreviewMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->file_manager_->delete_partial_remote_location(pending_preview_->file_upload_id_);

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for AddPreviewMediaQuery: " << to_string(ptr);
    auto bot_user_id = pending_preview_->bot_user_id_;
    vector<FileId> file_ids;
    auto preview = convert_bot_media_preview(td_, std::move(ptr), bot_user_id, file_ids);
    if (preview == nullptr) {
      LOG(ERROR) << "Receive invalid sent media preview";
      return pending_preview_->promise_.set_error(Status::Error(500, "Receive invalid preview"));
    }
    if (!file_ids.empty()) {
      auto file_source_id = td_->bot_info_manager_->get_bot_media_preview_info_file_source_id(
          bot_user_id, pending_preview_->language_code_);
      for (auto file_id : file_ids) {
        td_->file_manager_->add_file_source(file_id, file_source_id, "AddPreviewMediaQuery");
      }
    }
    if (pending_preview_->language_code_.empty()) {
      td_->user_manager_->on_update_bot_has_preview_medias(bot_user_id, true);
    }
    pending_preview_->promise_.set_value(std::move(preview));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for AddPreviewMediaQuery: " << status;
    auto bad_parts = FileManager::get_missing_file_parts(status);
    if (!bad_parts.empty()) {
      td_->bot_info_manager_->on_add_bot_media_preview_file_parts_missing(std::move(pending_preview_),
                                                                          std::move(bad_parts));
      return;
    }
    td_->file_manager_->delete_partial_remote_location(pending_preview_->file_upload_id_);
    pending_preview_->promise_.set_error(std::move(status));
  }
};

class ReorderPreviewMediasQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId bot_user_id_;

 public:
  explicit ReorderPreviewMediasQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, telegram_api::object_ptr<telegram_api::InputUser> input_user,
            const string &language_code, vector<telegram_api::object_ptr<telegram_api::InputMedia>> input_media) {
    bot_user_id_ = bot_user_id;
    send_query(G()->net_query_creator().create(
        telegram_api::bots_reorderPreviewMedias(std::move(input_user), language_code, std::move(input_media)),
        {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_reorderPreviewMedias>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->on_update_bot_has_preview_medias(bot_user_id_, true);
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeletePreviewMediaQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId bot_user_id_;

 public:
  explicit DeletePreviewMediaQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, telegram_api::object_ptr<telegram_api::InputUser> input_user,
            const string &language_code, vector<telegram_api::object_ptr<telegram_api::InputMedia>> input_media) {
    bot_user_id_ = bot_user_id;
    send_query(G()->net_query_creator().create(
        telegram_api::bots_deletePreviewMedia(std::move(input_user), language_code, std::move(input_media)),
        {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_deletePreviewMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->user_manager_->reload_user_full(bot_user_id_, std::move(promise_), "DeletePreviewMediaQuery");
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CanBotSendMessageQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit CanBotSendMessageQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id) {
    auto r_input_user = td_->user_manager_->get_input_user(bot_user_id);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }
    send_query(
        G()->net_query_creator().create(telegram_api::bots_canSendMessage(r_input_user.move_as_ok()), {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_canSendMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (result_ptr.ok()) {
      promise_.set_value(Unit());
    } else {
      promise_.set_error(Status::Error(404, "Not Found"));
    }
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class AllowBotSendMessageQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit AllowBotSendMessageQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id) {
    auto r_input_user = td_->user_manager_->get_input_user(bot_user_id);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }
    send_query(G()->net_query_creator().create(telegram_api::bots_allowSendMessage(r_input_user.move_as_ok()),
                                               {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_allowSendMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for AllowBotSendMessageQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

static Result<telegram_api::object_ptr<telegram_api::InputUser>> get_bot_input_user(const Td *td, UserId bot_user_id) {
  if (td->auth_manager_->is_bot()) {
    if (bot_user_id != UserId() && bot_user_id != td->user_manager_->get_my_id()) {
      return Status::Error(400, "Invalid bot user identifier specified");
    }
  } else {
    TRY_RESULT(bot_data, td->user_manager_->get_bot_data(bot_user_id));
    if (!bot_data.can_be_edited) {
      return Status::Error(400, "The bot can't be edited");
    }
    return td->user_manager_->get_input_user(bot_user_id);
  }
  return nullptr;
}

class SetBotInfoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  UserId bot_user_id_;
  bool set_name_ = false;
  bool set_info_ = false;

  void invalidate_bot_info() {
    if (set_info_) {
      td_->user_manager_->invalidate_user_full(bot_user_id_);
    }
  }

 public:
  explicit SetBotInfoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(UserId bot_user_id, const string &language_code, bool set_name, const string &name, bool set_description,
            const string &description, bool set_about, const string &about) {
    int32 flags = 0;
    if (set_name) {
      flags |= telegram_api::bots_setBotInfo::NAME_MASK;
    }
    if (set_about) {
      flags |= telegram_api::bots_setBotInfo::ABOUT_MASK;
    }
    if (set_description) {
      flags |= telegram_api::bots_setBotInfo::DESCRIPTION_MASK;
    }
    auto r_input_user = get_bot_input_user(td_, bot_user_id);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }
    if (r_input_user.ok() != nullptr) {
      flags |= telegram_api::bots_setBotInfo::BOT_MASK;
      bot_user_id_ = bot_user_id;
    } else {
      bot_user_id_ = td_->user_manager_->get_my_id();
    }
    set_name_ = set_name;
    set_info_ = set_about || set_description;
    invalidate_bot_info();
    send_query(G()->net_query_creator().create(
        telegram_api::bots_setBotInfo(flags, r_input_user.move_as_ok(), language_code, name, about, description),
        {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_setBotInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    LOG_IF(WARNING, !result) << "Failed to set bot info";
    if (set_info_) {
      invalidate_bot_info();
      if (!td_->auth_manager_->is_bot()) {
        return td_->user_manager_->reload_user_full(bot_user_id_, std::move(promise_), "SetBotInfoQuery");
      }
    }
    if (set_name_) {
      return td_->user_manager_->reload_user(bot_user_id_, std::move(promise_), "SetBotInfoQuery");
    }
    // invalidation is enough for bots if name wasn't changed
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    invalidate_bot_info();
    promise_.set_error(std::move(status));
  }
};

class GetBotInfoQuery final : public Td::ResultHandler {
  vector<Promise<string>> name_promises_;
  vector<Promise<string>> description_promises_;
  vector<Promise<string>> about_promises_;

 public:
  GetBotInfoQuery(vector<Promise<string>> name_promises, vector<Promise<string>> description_promises,
                  vector<Promise<string>> about_promises)
      : name_promises_(std::move(name_promises))
      , description_promises_(std::move(description_promises))
      , about_promises_(std::move(about_promises)) {
  }

  void send(UserId bot_user_id, const string &language_code) {
    int32 flags = 0;
    auto r_input_user = get_bot_input_user(td_, bot_user_id);
    if (r_input_user.is_error()) {
      return on_error(r_input_user.move_as_error());
    }
    if (r_input_user.ok() != nullptr) {
      flags |= telegram_api::bots_getBotInfo::BOT_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::bots_getBotInfo(flags, r_input_user.move_as_ok(), language_code), {{bot_user_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_getBotInfo>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetBotInfoQuery: " << to_string(result);
    for (auto &promise : name_promises_) {
      promise.set_value(string(result->name_));
    }
    for (auto &promise : description_promises_) {
      promise.set_value(string(result->description_));
    }
    for (auto &promise : about_promises_) {
      promise.set_value(string(result->about_));
    }
  }

  void on_error(Status status) final {
    fail_promises(name_promises_, status.clone());
    fail_promises(description_promises_, status.clone());
    fail_promises(about_promises_, status.clone());
  }
};

class SetCustomVerificationQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit SetCustomVerificationQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(telegram_api::object_ptr<telegram_api::InputUser> input_user, DialogId dialog_id, bool is_verified,
            const string &custom_description) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    int32 flags = 0;
    if (input_user != nullptr) {
      flags |= telegram_api::bots_setCustomVerification::BOT_MASK;
    }
    if (!custom_description.empty()) {
      flags |= telegram_api::bots_setCustomVerification::CUSTOM_DESCRIPTION_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::bots_setCustomVerification(flags, is_verified, std::move(input_user), std::move(input_peer),
                                                 custom_description),
        {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::bots_setCustomVerification>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SetCustomVerificationQuery");
    promise_.set_error(std::move(status));
  }
};

class BotInfoManager::UploadMediaCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->bot_info_manager(), &BotInfoManager::on_upload_bot_media_preview, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->bot_info_manager(), &BotInfoManager::on_upload_bot_media_preview_error, file_upload_id,
                       std::move(error));
  }
};

BotInfoManager::BotInfoManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_media_callback_ = std::make_shared<UploadMediaCallback>();
}

BotInfoManager::~BotInfoManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), bot_media_preview_file_source_ids_,
                                              bot_media_preview_info_file_source_ids_);
}

void BotInfoManager::tear_down() {
  parent_.reset();
}

void BotInfoManager::hangup() {
  auto set_queries = std::move(pending_set_bot_info_queries_);
  auto get_queries = std::move(pending_get_bot_info_queries_);

  for (auto &query : set_queries) {
    query.promise_.set_error(Global::request_aborted_error());
  }
  for (auto &query : get_queries) {
    query.promise_.set_error(Global::request_aborted_error());
  }

  stop();
}

void BotInfoManager::timeout_expired() {
  auto set_queries = std::move(pending_set_bot_info_queries_);
  reset_to_empty(pending_set_bot_info_queries_);
  auto get_queries = std::move(pending_get_bot_info_queries_);
  reset_to_empty(pending_get_bot_info_queries_);

  std::stable_sort(set_queries.begin(), set_queries.end(),
                   [](const PendingSetBotInfoQuery &lhs, const PendingSetBotInfoQuery &rhs) {
                     return lhs.bot_user_id_.get() < rhs.bot_user_id_.get() ||
                            (lhs.bot_user_id_ == rhs.bot_user_id_ && lhs.language_code_ < rhs.language_code_);
                   });
  for (size_t i = 0; i < set_queries.size();) {
    bool has_value[3] = {false, false, false};
    string values[3];
    vector<Promise<Unit>> promises;
    size_t j = i;
    while (j < set_queries.size() && set_queries[i].bot_user_id_ == set_queries[j].bot_user_id_ &&
           set_queries[i].language_code_ == set_queries[j].language_code_) {
      has_value[set_queries[j].type_] = true;
      values[set_queries[j].type_] = std::move(set_queries[j].value_);
      promises.push_back(std::move(set_queries[j].promise_));
      j++;
    }
    auto promise = PromiseCreator::lambda([promises = std::move(promises)](Result<Unit> &&result) mutable {
      if (result.is_error()) {
        fail_promises(promises, result.move_as_error());
      } else {
        set_promises(promises);
      }
    });
    td_->create_handler<SetBotInfoQuery>(std::move(promise))
        ->send(set_queries[i].bot_user_id_, set_queries[i].language_code_, has_value[0], values[0], has_value[1],
               values[1], has_value[2], values[2]);
    i = j;
  }

  std::stable_sort(get_queries.begin(), get_queries.end(),
                   [](const PendingGetBotInfoQuery &lhs, const PendingGetBotInfoQuery &rhs) {
                     return lhs.bot_user_id_.get() < rhs.bot_user_id_.get() ||
                            (lhs.bot_user_id_ == rhs.bot_user_id_ && lhs.language_code_ < rhs.language_code_);
                   });
  for (size_t i = 0; i < get_queries.size();) {
    vector<Promise<string>> promises[3];
    size_t j = i;
    while (j < get_queries.size() && get_queries[i].bot_user_id_ == get_queries[j].bot_user_id_ &&
           get_queries[i].language_code_ == get_queries[j].language_code_) {
      promises[get_queries[j].type_].push_back(std::move(get_queries[j].promise_));
      j++;
    }
    td_->create_handler<GetBotInfoQuery>(std::move(promises[0]), std::move(promises[1]), std::move(promises[2]))
        ->send(get_queries[i].bot_user_id_, get_queries[i].language_code_);
    i = j;
  }
}

void BotInfoManager::get_owned_bots(Promise<td_api::object_ptr<td_api::users>> &&promise) {
  td_->create_handler<GetAdminedBotsQuery>(std::move(promise))->send();
}

void BotInfoManager::set_default_group_administrator_rights(AdministratorRights administrator_rights,
                                                            Promise<Unit> &&promise) {
  td_->user_manager_->invalidate_user_full(td_->user_manager_->get_my_id());
  td_->create_handler<SetBotGroupDefaultAdminRightsQuery>(std::move(promise))->send(administrator_rights);
}

void BotInfoManager::set_default_channel_administrator_rights(AdministratorRights administrator_rights,
                                                              Promise<Unit> &&promise) {
  td_->user_manager_->invalidate_user_full(td_->user_manager_->get_my_id());
  td_->create_handler<SetBotBroadcastDefaultAdminRightsQuery>(std::move(promise))->send(administrator_rights);
}

void BotInfoManager::can_bot_send_messages(UserId bot_user_id, Promise<Unit> &&promise) {
  td_->create_handler<CanBotSendMessageQuery>(std::move(promise))->send(bot_user_id);
}

void BotInfoManager::allow_bot_to_send_messages(UserId bot_user_id, Promise<Unit> &&promise) {
  td_->create_handler<AllowBotSendMessageQuery>(std::move(promise))->send(bot_user_id);
}

FileSourceId BotInfoManager::get_bot_media_preview_file_source_id(UserId bot_user_id) {
  if (!bot_user_id.is_valid()) {
    return FileSourceId();
  }

  auto &source_id = bot_media_preview_file_source_ids_[bot_user_id];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_bot_media_preview_file_source(bot_user_id);
  }
  VLOG(file_references) << "Return " << source_id << " for media previews of " << bot_user_id;
  return source_id;
}

FileSourceId BotInfoManager::get_bot_media_preview_info_file_source_id(UserId bot_user_id,
                                                                       const string &language_code) {
  if (!bot_user_id.is_valid()) {
    return FileSourceId();
  }

  auto &source_id = bot_media_preview_info_file_source_ids_[{bot_user_id, language_code}];
  if (!source_id.is_valid()) {
    source_id = td_->file_reference_manager_->create_bot_media_preview_info_file_source(bot_user_id, language_code);
  }
  VLOG(file_references) << "Return " << source_id << " for media preview info of " << bot_user_id << " for "
                        << language_code;
  return source_id;
}

Result<telegram_api::object_ptr<telegram_api::InputUser>> BotInfoManager::get_media_preview_bot_input_user(
    UserId user_id, bool can_be_edited) {
  TRY_RESULT(bot_data, td_->user_manager_->get_bot_data(user_id));
  if (can_be_edited && !bot_data.can_be_edited) {
    return Status::Error(400, "Bot must be owned");
  }
  if (!bot_data.has_main_app) {
    return Status::Error(400, "Bot must have the main Mini App");
  }
  return td_->user_manager_->get_input_user(user_id);
}

Status BotInfoManager::validate_bot_media_preview_language_code(const string &language_code) {
  if (language_code.empty()) {
    return Status::OK();
  }
  if (language_code.size() < 2 || language_code[0] == '-' || language_code[1] == '-') {
    return Status::Error(400, "Invalid language code specified");
  }
  for (auto c : language_code) {
    if ((c < 'a' || c > 'z') && c != '-') {
      return Status::Error(400, "Invalid language code specified");
    }
  }
  return Status::OK();
}

void BotInfoManager::get_bot_media_previews(UserId bot_user_id,
                                            Promise<td_api::object_ptr<td_api::botMediaPreviews>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_media_preview_bot_input_user(bot_user_id));
  td_->create_handler<GetPreviewMediasQuery>(std::move(promise))->send(bot_user_id, std::move(input_user));
}

void BotInfoManager::get_bot_media_preview_info(UserId bot_user_id, const string &language_code,
                                                Promise<td_api::object_ptr<td_api::botMediaPreviewInfo>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_media_preview_bot_input_user(bot_user_id, true));
  TRY_STATUS_PROMISE(promise, validate_bot_media_preview_language_code(language_code));
  td_->create_handler<GetPreviewInfoQuery>(std::move(promise))->send(bot_user_id, std::move(input_user), language_code);
}

void BotInfoManager::reload_bot_media_previews(UserId bot_user_id, Promise<Unit> &&promise) {
  get_bot_media_previews(
      bot_user_id, PromiseCreator::lambda([promise = std::move(promise)](
                                              Result<td_api::object_ptr<td_api::botMediaPreviews>> result) mutable {
        if (result.is_error()) {
          promise.set_error(result.move_as_error());
        } else {
          promise.set_value(Unit());
        }
      }));
}

void BotInfoManager::reload_bot_media_preview_info(UserId bot_user_id, const string &language_code,
                                                   Promise<Unit> &&promise) {
  get_bot_media_preview_info(
      bot_user_id, language_code,
      PromiseCreator::lambda(
          [promise = std::move(promise)](Result<td_api::object_ptr<td_api::botMediaPreviewInfo>> result) mutable {
            if (result.is_error()) {
              promise.set_error(result.move_as_error());
            } else {
              promise.set_value(Unit());
            }
          }));
}

void BotInfoManager::add_bot_media_preview(UserId bot_user_id, const string &language_code,
                                           td_api::object_ptr<td_api::InputStoryContent> &&input_content,
                                           Promise<td_api::object_ptr<td_api::botMediaPreview>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_media_preview_bot_input_user(bot_user_id, true));
  TRY_STATUS_PROMISE(promise, validate_bot_media_preview_language_code(language_code));
  TRY_RESULT_PROMISE(promise, content, get_input_story_content(td_, std::move(input_content), DialogId(bot_user_id)));
  auto pending_preview = make_unique<PendingBotMediaPreview>();
  pending_preview->bot_user_id_ = bot_user_id;
  pending_preview->language_code_ = language_code;
  pending_preview->content_ = std::move(content);
  pending_preview->file_upload_id_ = FileUploadId{get_story_content_any_file_id(pending_preview->content_.get()),
                                                  FileManager::get_internal_upload_id()};
  pending_preview->upload_order_ = ++bot_media_preview_upload_order_;
  pending_preview->promise_ = std::move(promise);

  do_add_bot_media_preview(std::move(pending_preview), {});
}

void BotInfoManager::edit_bot_media_preview(UserId bot_user_id, const string &language_code, FileId file_id,
                                            td_api::object_ptr<td_api::InputStoryContent> &&input_content,
                                            Promise<td_api::object_ptr<td_api::botMediaPreview>> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_media_preview_bot_input_user(bot_user_id, true));
  TRY_STATUS_PROMISE(promise, validate_bot_media_preview_language_code(language_code));
  TRY_RESULT_PROMISE(promise, content, get_input_story_content(td_, std::move(input_content), DialogId(bot_user_id)));
  auto input_media = get_fake_input_media(file_id);
  if (input_media == nullptr) {
    return promise.set_error(Status::Error(400, "Wrong media to edit specified"));
  }
  auto pending_preview = make_unique<PendingBotMediaPreview>();
  pending_preview->edited_file_id_ = file_id;
  pending_preview->bot_user_id_ = bot_user_id;
  pending_preview->language_code_ = language_code;
  pending_preview->content_ = std::move(content);
  pending_preview->file_upload_id_ = FileUploadId{get_story_content_any_file_id(pending_preview->content_.get()),
                                                  FileManager::get_internal_upload_id()};
  pending_preview->upload_order_ = ++bot_media_preview_upload_order_;
  pending_preview->promise_ = std::move(promise);

  do_add_bot_media_preview(std::move(pending_preview), {});
}

void BotInfoManager::do_add_bot_media_preview(unique_ptr<PendingBotMediaPreview> &&pending_preview,
                                              vector<int> bad_parts) {
  auto file_upload_id = pending_preview->file_upload_id_;
  auto upload_order = pending_preview->upload_order_;
  CHECK(file_upload_id.is_valid());

  LOG(INFO) << "Ask to upload " << file_upload_id << " with bad parts " << bad_parts;
  bool is_inserted = being_uploaded_files_.emplace(file_upload_id, std::move(pending_preview)).second;
  CHECK(is_inserted);
  // need to call resume_upload synchronously to make upload process consistent with being_uploaded_files_
  // and to send is_uploading_active == true in response
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_media_callback_, 1, upload_order);
}

void BotInfoManager::on_add_bot_media_preview_file_parts_missing(unique_ptr<PendingBotMediaPreview> &&pending_preview,
                                                                 vector<int> &&bad_parts) {
  do_add_bot_media_preview(std::move(pending_preview), std::move(bad_parts));
}

void BotInfoManager::on_upload_bot_media_preview(FileUploadId file_upload_id,
                                                 telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Bot media preview " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());
  auto pending_preview = std::move(it->second);
  being_uploaded_files_.erase(it);
  CHECK(file_upload_id == pending_preview->file_upload_id_);

  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  CHECK(!file_view.is_encrypted());
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (input_file == nullptr && main_remote_location != nullptr) {
    if (main_remote_location->is_web()) {
      return pending_preview->promise_.set_error(Status::Error(400, "Can't use web photo as a preview"));
    }
    if (pending_preview->was_reuploaded_) {
      return pending_preview->promise_.set_error(Status::Error(500, "Failed to reupload preview"));
    }
    pending_preview->was_reuploaded_ = true;

    // delete file reference and forcely reupload the file
    td_->file_manager_->delete_file_reference(file_upload_id.get_file_id(), main_remote_location->get_file_reference());
    return do_add_bot_media_preview(std::move(pending_preview), {-1});
  }
  CHECK(input_file != nullptr);
  auto r_input_user = get_media_preview_bot_input_user(pending_preview->bot_user_id_, true);
  if (r_input_user.is_error()) {
    td_->file_manager_->cancel_upload(file_upload_id);
    pending_preview->promise_.set_error(r_input_user.move_as_error());
    return;
  }

  td_->create_handler<AddPreviewMediaQuery>()->send(r_input_user.move_as_ok(), std::move(pending_preview),
                                                    std::move(input_file));
}

void BotInfoManager::on_upload_bot_media_preview_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Bot media preview " << file_upload_id << " has upload error " << status;

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());
  auto pending_preview = std::move(it->second);
  being_uploaded_files_.erase(it);
  CHECK(file_upload_id == pending_preview->file_upload_id_);

  pending_preview->promise_.set_error(std::move(status));
}

telegram_api::object_ptr<telegram_api::InputMedia> BotInfoManager::get_fake_input_media(FileId file_id) const {
  FileView file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.empty()) {
    return nullptr;
  }
  auto full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location == nullptr || full_remote_location->is_web()) {
    return nullptr;
  }

  switch (file_view.get_type()) {
    case FileType::VideoStory:
      return telegram_api::make_object<telegram_api::inputMediaDocument>(
          0, false, full_remote_location->as_input_document(), nullptr, 0, 0, string());
    case FileType::PhotoStory:
      return telegram_api::make_object<telegram_api::inputMediaPhoto>(0, false, full_remote_location->as_input_photo(),
                                                                      0);
    default:
      return nullptr;
  }
}

void BotInfoManager::reorder_bot_media_previews(UserId bot_user_id, const string &language_code,
                                                const vector<int32> &file_ids, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_media_preview_bot_input_user(bot_user_id, true));
  TRY_STATUS_PROMISE(promise, validate_bot_media_preview_language_code(language_code));
  vector<telegram_api::object_ptr<telegram_api::InputMedia>> input_medias;
  for (auto file_id : file_ids) {
    auto input_media = get_fake_input_media(FileId(file_id, 0));
    if (input_media == nullptr) {
      return promise.set_error(Status::Error(400, "Wrong media to delete specified"));
    }
    input_medias.push_back(std::move(input_media));
  }
  if (input_medias.empty()) {
    return promise.set_value(Unit());
  }
  td_->create_handler<ReorderPreviewMediasQuery>(std::move(promise))
      ->send(bot_user_id, std::move(input_user), language_code, std::move(input_medias));
}

void BotInfoManager::delete_bot_media_previews(UserId bot_user_id, const string &language_code,
                                               const vector<int32> &file_ids, Promise<Unit> &&promise) {
  TRY_RESULT_PROMISE(promise, input_user, get_media_preview_bot_input_user(bot_user_id, true));
  TRY_STATUS_PROMISE(promise, validate_bot_media_preview_language_code(language_code));
  vector<telegram_api::object_ptr<telegram_api::InputMedia>> input_medias;
  for (auto file_id : file_ids) {
    auto input_media = get_fake_input_media(FileId(file_id, 0));
    if (input_media == nullptr) {
      return promise.set_error(Status::Error(400, "Wrong media to delete specified"));
    }
    input_medias.push_back(std::move(input_media));
  }
  td_->create_handler<DeletePreviewMediaQuery>(std::move(promise))
      ->send(bot_user_id, std::move(input_user), language_code, std::move(input_medias));
}

void BotInfoManager::add_pending_set_query(UserId bot_user_id, const string &language_code, int type,
                                           const string &value, Promise<Unit> &&promise) {
  pending_set_bot_info_queries_.emplace_back(bot_user_id, language_code, type, value, std::move(promise));
  if (!has_timeout()) {
    set_timeout_in(MAX_QUERY_DELAY);
  }
}

void BotInfoManager::add_pending_get_query(UserId bot_user_id, const string &language_code, int type,
                                           Promise<string> &&promise) {
  pending_get_bot_info_queries_.emplace_back(bot_user_id, language_code, type, std::move(promise));
  if (!has_timeout()) {
    set_timeout_in(MAX_QUERY_DELAY);
  }
}

void BotInfoManager::set_bot_name(UserId bot_user_id, const string &language_code, const string &name,
                                  Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, validate_bot_language_code(language_code));
  add_pending_set_query(bot_user_id, language_code, 0, name, std::move(promise));
}

void BotInfoManager::get_bot_name(UserId bot_user_id, const string &language_code, Promise<string> &&promise) {
  TRY_STATUS_PROMISE(promise, validate_bot_language_code(language_code));
  add_pending_get_query(bot_user_id, language_code, 0, std::move(promise));
}

void BotInfoManager::set_bot_info_description(UserId bot_user_id, const string &language_code,
                                              const string &description, Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, validate_bot_language_code(language_code));
  add_pending_set_query(bot_user_id, language_code, 1, description, std::move(promise));
}

void BotInfoManager::get_bot_info_description(UserId bot_user_id, const string &language_code,
                                              Promise<string> &&promise) {
  TRY_STATUS_PROMISE(promise, validate_bot_language_code(language_code));
  add_pending_get_query(bot_user_id, language_code, 1, std::move(promise));
}

void BotInfoManager::set_bot_info_about(UserId bot_user_id, const string &language_code, const string &about,
                                        Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, validate_bot_language_code(language_code));
  add_pending_set_query(bot_user_id, language_code, 2, about, std::move(promise));
}

void BotInfoManager::get_bot_info_about(UserId bot_user_id, const string &language_code, Promise<string> &&promise) {
  TRY_STATUS_PROMISE(promise, validate_bot_language_code(language_code));
  add_pending_get_query(bot_user_id, language_code, 2, std::move(promise));
}

void BotInfoManager::set_custom_bot_verification(UserId bot_user_id, DialogId dialog_id, bool is_verified,
                                                 const string &custom_description, Promise<Unit> &&promise) {
  telegram_api::object_ptr<telegram_api::InputUser> bot_input_user;
  if (bot_user_id != UserId()) {
    TRY_RESULT_PROMISE_ASSIGN(promise, bot_input_user, td_->user_manager_->get_input_user(bot_user_id));
  }
  if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
    return promise.set_error(Status::Error(400, "Can't access the verified entity"));
  }
  td_->create_handler<SetCustomVerificationQuery>(std::move(promise))
      ->send(std::move(bot_input_user), dialog_id, is_verified, custom_description);
}

}  // namespace td
