//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageImportManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/MessageContent.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/Random.h"

namespace td {

class CheckHistoryImportQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::MessageFileType>> promise_;

 public:
  explicit CheckHistoryImportQuery(Promise<td_api::object_ptr<td_api::MessageFileType>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &message_file_head) {
    send_query(G()->net_query_creator().create(telegram_api::messages_checkHistoryImport(message_file_head)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_checkHistoryImport>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CheckHistoryImportQuery: " << to_string(ptr);
    auto file_type = [&]() -> td_api::object_ptr<td_api::MessageFileType> {
      if (ptr->pm_) {
        return td_api::make_object<td_api::messageFileTypePrivate>(ptr->title_);
      } else if (ptr->group_) {
        return td_api::make_object<td_api::messageFileTypeGroup>(ptr->title_);
      } else {
        return td_api::make_object<td_api::messageFileTypeUnknown>();
      }
    }();
    promise_.set_value(std::move(file_type));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CheckHistoryImportPeerQuery final : public Td::ResultHandler {
  Promise<string> promise_;
  DialogId dialog_id_;

 public:
  explicit CheckHistoryImportPeerQuery(Promise<string> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::messages_checkHistoryImportPeer(std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_checkHistoryImportPeer>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for CheckHistoryImportPeerQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr->confirm_text_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "CheckHistoryImportPeerQuery");
    promise_.set_error(std::move(status));
  }
};

class InitHistoryImportQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  FileUploadId file_upload_id_;
  DialogId dialog_id_;
  vector<FileUploadId> attached_file_upload_ids_;

 public:
  explicit InitHistoryImportQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, FileUploadId file_upload_id,
            telegram_api::object_ptr<telegram_api::InputFile> &&input_file,
            vector<FileUploadId> attached_file_upload_ids) {
    CHECK(input_file != nullptr);
    file_upload_id_ = file_upload_id;
    dialog_id_ = dialog_id;
    attached_file_upload_ids_ = std::move(attached_file_upload_ids);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::messages_initHistoryImport(
        std::move(input_peer), std::move(input_file), narrow_cast<int32>(attached_file_upload_ids_.size()))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_initHistoryImport>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    td_->message_import_manager_->start_import_messages(dialog_id_, ptr->id_, std::move(attached_file_upload_ids_),
                                                        std::move(promise_));

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
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "InitHistoryImportQuery");
    promise_.set_error(std::move(status));
  }
};

class UploadImportedMediaQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  int64 import_id_;
  FileUploadId file_upload_id_;

 public:
  explicit UploadImportedMediaQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, int64 import_id, const string &file_name, FileUploadId file_upload_id,
            tl_object_ptr<telegram_api::InputMedia> &&input_media) {
    CHECK(input_media != nullptr);
    dialog_id_ = dialog_id;
    import_id_ = import_id;
    file_upload_id_ = file_upload_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_uploadImportedMedia(
        std::move(input_peer), import_id, file_name, std::move(input_media))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_uploadImportedMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    // ignore response

    promise_.set_value(Unit());

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
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "UploadImportedMediaQuery");
    promise_.set_error(std::move(status));
  }
};

class StartImportHistoryQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit StartImportHistoryQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, int64 import_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    send_query(
        G()->net_query_creator().create(telegram_api::messages_startHistoryImport(std::move(input_peer), import_id)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_startHistoryImport>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (!result_ptr.ok()) {
      return on_error(Status::Error(500, "Import history returned false"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "StartImportHistoryQuery");
    promise_.set_error(std::move(status));
  }
};

class MessageImportManager::UploadImportedMessagesCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->message_import_manager(), &MessageImportManager::on_upload_imported_messages,
                       file_upload_id, std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->message_import_manager(), &MessageImportManager::on_upload_imported_messages_error,
                       file_upload_id, std::move(error));
  }
};

class MessageImportManager::UploadImportedMessageAttachmentCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->message_import_manager(), &MessageImportManager::on_upload_imported_message_attachment,
                       file_upload_id, std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->message_import_manager(),
                       &MessageImportManager::on_upload_imported_message_attachment_error, file_upload_id,
                       std::move(error));
  }
};

MessageImportManager::MessageImportManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_imported_messages_callback_ = std::make_shared<UploadImportedMessagesCallback>();
  upload_imported_message_attachment_callback_ = std::make_shared<UploadImportedMessageAttachmentCallback>();
}

void MessageImportManager::tear_down() {
  parent_.reset();
}

void MessageImportManager::get_message_file_type(const string &message_file_head,
                                                 Promise<td_api::object_ptr<td_api::MessageFileType>> &&promise) {
  td_->create_handler<CheckHistoryImportQuery>(std::move(promise))->send(message_file_head);
}

Status MessageImportManager::can_import_messages(DialogId dialog_id) {
  TRY_STATUS(td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write, "can_import_messages"));

  switch (dialog_id.get_type()) {
    case DialogType::User:
      if (!td_->user_manager_->is_user_contact(dialog_id.get_user_id(), true)) {
        return Status::Error(400, "User must be a mutual contact");
      }
      break;
    case DialogType::Chat:
      return Status::Error(400, "Basic groups must be upgraded to supergroups first");
    case DialogType::Channel:
      if (td_->dialog_manager_->is_broadcast_channel(dialog_id)) {
        return Status::Error(400, "Can't import messages to channels");
      }
      if (!td_->chat_manager_->get_channel_permissions(dialog_id.get_channel_id()).can_change_info_and_settings()) {
        return Status::Error(400, "Not enough rights to import messages");
      }
      break;
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      UNREACHABLE();
  }

  return Status::OK();
}

void MessageImportManager::get_message_import_confirmation_text(DialogId dialog_id, Promise<string> &&promise) {
  TRY_STATUS_PROMISE(promise, can_import_messages(dialog_id));

  td_->create_handler<CheckHistoryImportPeerQuery>(std::move(promise))->send(dialog_id);
}

void MessageImportManager::import_messages(DialogId dialog_id,
                                           const td_api::object_ptr<td_api::InputFile> &message_file,
                                           const vector<td_api::object_ptr<td_api::InputFile>> &attached_files,
                                           Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, can_import_messages(dialog_id));

  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(FileType::Document, message_file, dialog_id, false, false));

  vector<FileUploadId> attached_file_upload_ids;
  attached_file_upload_ids.reserve(attached_files.size());
  for (auto &attached_file : attached_files) {
    auto file_type = td_->file_manager_->guess_file_type(attached_file);
    if (file_type != FileType::Animation && file_type != FileType::Audio && file_type != FileType::Document &&
        file_type != FileType::Photo && file_type != FileType::Sticker && file_type != FileType::Video &&
        file_type != FileType::VoiceNote) {
      LOG(INFO) << "Skip attached file of type " << file_type;
      continue;
    }
    TRY_RESULT_PROMISE(promise, attached_file_id,
                       td_->file_manager_->get_input_file_id(file_type, attached_file, dialog_id, false, false));
    attached_file_upload_ids.emplace_back(attached_file_id, FileManager::get_internal_upload_id());
  }

  upload_imported_messages(dialog_id, {file_id, FileManager::get_internal_upload_id()},
                           std::move(attached_file_upload_ids), false, std::move(promise));
}

void MessageImportManager::upload_imported_messages(DialogId dialog_id, FileUploadId file_upload_id,
                                                    vector<FileUploadId> attached_file_upload_ids, bool is_reupload,
                                                    Promise<Unit> &&promise, vector<int> bad_parts) {
  CHECK(file_upload_id.is_valid());
  LOG(INFO) << "Ask to upload imported messages " << file_upload_id;
  auto info = td::make_unique<UploadedImportedMessagesInfo>(dialog_id, std::move(attached_file_upload_ids), is_reupload,
                                                            std::move(promise));
  bool is_inserted = being_uploaded_imported_messages_.emplace(file_upload_id, std::move(info)).second;
  CHECK(is_inserted);
  // TODO use force_reupload if is_reupload
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_imported_messages_callback_, 1, 0,
                                    false, true);
}

void MessageImportManager::on_upload_imported_messages(FileUploadId file_upload_id,
                                                       telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Imported messages " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_imported_messages_.find(file_upload_id);
  CHECK(it != being_uploaded_imported_messages_.end());
  CHECK(it->second != nullptr);
  DialogId dialog_id = it->second->dialog_id;
  auto attached_file_upload_ids = std::move(it->second->attached_file_upload_ids);
  bool is_reupload = it->second->is_reupload;
  Promise<Unit> promise = std::move(it->second->promise);
  being_uploaded_imported_messages_.erase(it);

  auto status = td_->dialog_manager_->check_dialog_access_in_memory(dialog_id, false, AccessRights::Write);
  if (status.is_error()) {
    td_->file_manager_->cancel_upload(file_upload_id);
    return promise.set_error(std::move(status));
  }

  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  CHECK(!file_view.is_encrypted());
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (input_file == nullptr && main_remote_location != nullptr) {
    if (main_remote_location->is_web()) {
      return promise.set_error(Status::Error(400, "Can't use web file"));
    }
    if (is_reupload) {
      return promise.set_error(Status::Error(400, "Failed to reupload the file"));
    }

    CHECK(file_view.get_type() == FileType::Document);
    // delete file reference and forcely reupload the file
    auto file_reference = FileManager::extract_file_reference(main_remote_location->as_input_document());
    td_->file_manager_->delete_file_reference(file_upload_id.get_file_id(), file_reference);
    upload_imported_messages(dialog_id, file_upload_id, std::move(attached_file_upload_ids), true, std::move(promise),
                             {-1});
    return;
  }
  CHECK(input_file != nullptr);

  td_->create_handler<InitHistoryImportQuery>(std::move(promise))
      ->send(dialog_id, file_upload_id, std::move(input_file), std::move(attached_file_upload_ids));
}

void MessageImportManager::on_upload_imported_messages_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(INFO) << "Imported messages " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_imported_messages_.find(file_upload_id);
  CHECK(it != being_uploaded_imported_messages_.end());
  Promise<Unit> promise = std::move(it->second->promise);
  being_uploaded_imported_messages_.erase(it);

  promise.set_error(std::move(status));
}

void MessageImportManager::start_import_messages(DialogId dialog_id, int64 import_id,
                                                 vector<FileUploadId> &&attached_file_upload_ids,
                                                 Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_STATUS_PROMISE(promise,
                     td_->dialog_manager_->check_dialog_access_in_memory(dialog_id, false, AccessRights::Write));

  auto pending_message_import = make_unique<PendingMessageImport>();
  pending_message_import->dialog_id = dialog_id;
  pending_message_import->import_id = import_id;
  pending_message_import->promise = std::move(promise);

  auto &multipromise = pending_message_import->upload_files_multipromise;

  int64 random_id;
  do {
    random_id = Random::secure_int64();
  } while (random_id == 0 || pending_message_imports_.count(random_id) > 0);
  pending_message_imports_[random_id] = std::move(pending_message_import);

  multipromise.add_promise(PromiseCreator::lambda([actor_id = actor_id(this), random_id](Result<Unit> result) {
    send_closure_later(actor_id, &MessageImportManager::on_imported_message_attachments_uploaded, random_id,
                       std::move(result));
  }));
  auto lock_promise = multipromise.get_promise();

  for (auto attached_file_upload_id : attached_file_upload_ids) {
    upload_imported_message_attachment(dialog_id, import_id, attached_file_upload_id, false,
                                       multipromise.get_promise());
  }

  lock_promise.set_value(Unit());
}

void MessageImportManager::upload_imported_message_attachment(DialogId dialog_id, int64 import_id,
                                                              FileUploadId file_upload_id, bool is_reupload,
                                                              Promise<Unit> &&promise, vector<int> bad_parts) {
  CHECK(file_upload_id.is_valid());
  LOG(INFO) << "Ask to upload imported message attached " << file_upload_id;
  auto info =
      td::make_unique<UploadedImportedMessageAttachmentInfo>(dialog_id, import_id, is_reupload, std::move(promise));
  bool is_inserted = being_uploaded_imported_message_attachments_.emplace(file_upload_id, std::move(info)).second;
  CHECK(is_inserted);
  // TODO use force_reupload if is_reupload
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_imported_message_attachment_callback_,
                                    1, 0, false, true);
}

void MessageImportManager::on_upload_imported_message_attachment(
    FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Imported message attachment " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_imported_message_attachments_.find(file_upload_id);
  CHECK(it != being_uploaded_imported_message_attachments_.end());
  CHECK(it->second != nullptr);
  DialogId dialog_id = it->second->dialog_id;
  int64 import_id = it->second->import_id;
  bool is_reupload = it->second->is_reupload;
  Promise<Unit> promise = std::move(it->second->promise);
  being_uploaded_imported_message_attachments_.erase(it);

  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  CHECK(!file_view.is_encrypted());
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (input_file == nullptr && main_remote_location != nullptr) {
    if (main_remote_location->is_web()) {
      return promise.set_error(Status::Error(400, "Can't use web file"));
    }
    if (is_reupload) {
      return promise.set_error(Status::Error(400, "Failed to reupload the file"));
    }

    // delete file reference and forcely reupload the file
    auto file_reference = file_view.get_type() == FileType::Photo
                              ? FileManager::extract_file_reference(main_remote_location->as_input_photo())
                              : FileManager::extract_file_reference(main_remote_location->as_input_document());
    td_->file_manager_->delete_file_reference(file_upload_id.get_file_id(), file_reference);
    upload_imported_message_attachment(dialog_id, import_id, file_upload_id, true, std::move(promise), {-1});
    return;
  }
  CHECK(input_file != nullptr);

  auto suggested_path = file_view.suggested_path();
  const PathView path_view(suggested_path);
  td_->create_handler<UploadImportedMediaQuery>(std::move(promise))
      ->send(dialog_id, import_id, path_view.file_name().str(), file_upload_id,
             get_message_content_fake_input_media(td_, std::move(input_file), file_upload_id.get_file_id()));
}

void MessageImportManager::on_upload_imported_message_attachment_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(INFO) << "Imported message attachment " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_imported_message_attachments_.find(file_upload_id);
  CHECK(it != being_uploaded_imported_message_attachments_.end());
  Promise<Unit> promise = std::move(it->second->promise);
  being_uploaded_imported_message_attachments_.erase(it);

  promise.set_error(std::move(status));
}

void MessageImportManager::on_imported_message_attachments_uploaded(int64 random_id, Result<Unit> &&result) {
  G()->ignore_result_if_closing(result);

  auto it = pending_message_imports_.find(random_id);
  CHECK(it != pending_message_imports_.end());

  auto pending_message_import = std::move(it->second);
  CHECK(pending_message_import != nullptr);

  pending_message_imports_.erase(it);

  if (result.is_error()) {
    pending_message_import->promise.set_error(result.move_as_error());
    return;
  }

  CHECK(pending_message_import->upload_files_multipromise.promise_count() == 0);

  auto promise = std::move(pending_message_import->promise);
  auto dialog_id = pending_message_import->dialog_id;

  TRY_STATUS_PROMISE(promise,
                     td_->dialog_manager_->check_dialog_access_in_memory(dialog_id, false, AccessRights::Write));

  td_->create_handler<StartImportHistoryQuery>(std::move(promise))->send(dialog_id, pending_message_import->import_id);
}

}  // namespace td
