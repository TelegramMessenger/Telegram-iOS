//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"
#include "td/actor/MultiPromise.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <memory>

namespace td {

class Td;

class MessageImportManager final : public Actor {
 public:
  MessageImportManager(Td *td, ActorShared<> parent);

  void get_message_file_type(const string &message_file_head,
                             Promise<td_api::object_ptr<td_api::MessageFileType>> &&promise);

  void get_message_import_confirmation_text(DialogId dialog_id, Promise<string> &&promise);

  void import_messages(DialogId dialog_id, const td_api::object_ptr<td_api::InputFile> &message_file,
                       const vector<td_api::object_ptr<td_api::InputFile>> &attached_files, Promise<Unit> &&promise);

  void start_import_messages(DialogId dialog_id, int64 import_id, vector<FileUploadId> &&attached_file_upload_ids,
                             Promise<Unit> &&promise);

 private:
  void tear_down() final;

  Status can_import_messages(DialogId dialog_id);

  void upload_imported_messages(DialogId dialog_id, FileUploadId file_upload_id,
                                vector<FileUploadId> attached_file_upload_ids, bool is_reupload,
                                Promise<Unit> &&promise, vector<int> bad_parts = {});

  void on_upload_imported_messages(FileUploadId file_upload_id,
                                   telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_imported_messages_error(FileUploadId file_upload_id, Status status);

  void upload_imported_message_attachment(DialogId dialog_id, int64 import_id, FileUploadId file_upload_id,
                                          bool is_reupload, Promise<Unit> &&promise, vector<int> bad_parts = {});

  void on_upload_imported_message_attachment(FileUploadId file_upload_id,
                                             telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_imported_message_attachment_error(FileUploadId file_upload_id, Status status);

  void on_imported_message_attachments_uploaded(int64 random_id, Result<Unit> &&result);

  class UploadImportedMessagesCallback;
  class UploadImportedMessageAttachmentCallback;

  std::shared_ptr<UploadImportedMessagesCallback> upload_imported_messages_callback_;
  std::shared_ptr<UploadImportedMessageAttachmentCallback> upload_imported_message_attachment_callback_;

  struct UploadedImportedMessagesInfo {
    DialogId dialog_id;
    vector<FileUploadId> attached_file_upload_ids;
    bool is_reupload;
    Promise<Unit> promise;

    UploadedImportedMessagesInfo(DialogId dialog_id, vector<FileUploadId> &&attached_file_upload_ids, bool is_reupload,
                                 Promise<Unit> &&promise)
        : dialog_id(dialog_id)
        , attached_file_upload_ids(std::move(attached_file_upload_ids))
        , is_reupload(is_reupload)
        , promise(std::move(promise)) {
    }
  };
  FlatHashMap<FileUploadId, unique_ptr<UploadedImportedMessagesInfo>, FileUploadIdHash>
      being_uploaded_imported_messages_;

  struct UploadedImportedMessageAttachmentInfo {
    DialogId dialog_id;
    int64 import_id;
    bool is_reupload;
    Promise<Unit> promise;

    UploadedImportedMessageAttachmentInfo(DialogId dialog_id, int64 import_id, bool is_reupload,
                                          Promise<Unit> &&promise)
        : dialog_id(dialog_id), import_id(import_id), is_reupload(is_reupload), promise(std::move(promise)) {
    }
  };
  FlatHashMap<FileUploadId, unique_ptr<UploadedImportedMessageAttachmentInfo>, FileUploadIdHash>
      being_uploaded_imported_message_attachments_;

  struct PendingMessageImport {
    MultiPromiseActor upload_files_multipromise{"UploadAttachedFilesMultiPromiseActor"};
    DialogId dialog_id;
    int64 import_id = 0;
    Promise<Unit> promise;
  };
  FlatHashMap<int64, unique_ptr<PendingMessageImport>> pending_message_imports_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
