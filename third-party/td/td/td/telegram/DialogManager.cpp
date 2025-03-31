//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/BlockListId.h"
#include "td/telegram/BotCommand.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/ChatReactions.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/misc.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/ReportReason.h"
#include "td/telegram/SecretChatId.h"
#include "td/telegram/SecretChatsManager.h"
#include "td/telegram/StickerPhotoSize.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Usernames.h"
#include "td/telegram/Version.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/Hints.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/utf8.h"

#include <type_traits>

namespace td {

class CheckUsernameQuery final : public Td::ResultHandler {
  Promise<bool> promise_;

 public:
  explicit CheckUsernameQuery(Promise<bool> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &username) {
    send_query(G()->net_query_creator().create(telegram_api::account_checkUsername(username), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_checkUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class CheckChannelUsernameQuery final : public Td::ResultHandler {
  Promise<bool> promise_;
  ChannelId channel_id_;
  string username_;

 public:
  explicit CheckChannelUsernameQuery(Promise<bool> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, const string &username) {
    channel_id_ = channel_id;
    telegram_api::object_ptr<telegram_api::InputChannel> input_channel;
    if (channel_id.is_valid()) {
      input_channel = td_->chat_manager_->get_input_channel(channel_id);
    } else {
      input_channel = telegram_api::make_object<telegram_api::inputChannelEmpty>();
    }
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::channels_checkUsername(std::move(input_channel), username),
                                               {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_checkUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    if (channel_id_.is_valid()) {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "CheckChannelUsernameQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ResolveUsernameQuery final : public Td::ResultHandler {
  Promise<DialogId> promise_;

 public:
  explicit ResolveUsernameQuery(Promise<DialogId> &&promise) : promise_(std::move(promise)) {
  }

  void send(const string &username) {
    send_query(G()->net_query_creator().create(telegram_api::contacts_resolveUsername(0, username, string())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_resolveUsername>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for ResolveUsernameQuery: " << to_string(ptr);
    td_->user_manager_->on_get_users(std::move(ptr->users_), "ResolveUsernameQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "ResolveUsernameQuery");

    promise_.set_value(DialogId(ptr->peer_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SearchPublicDialogsQuery final : public Td::ResultHandler {
  string query_;

 public:
  void send(const string &query) {
    query_ = query;
    send_query(
        G()->net_query_creator().create(telegram_api::contacts_search(query, 20 /* mostly ignored server-side */)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_search>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto dialogs = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SearchPublicDialogsQuery: " << to_string(dialogs);
    td_->user_manager_->on_get_users(std::move(dialogs->users_), "SearchPublicDialogsQuery");
    td_->chat_manager_->on_get_chats(std::move(dialogs->chats_), "SearchPublicDialogsQuery");
    td_->dialog_manager_->on_get_public_dialogs_search_result(query_, std::move(dialogs->my_results_),
                                                              std::move(dialogs->results_));
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      if (status.message() == "QUERY_TOO_SHORT") {
        return td_->dialog_manager_->on_get_public_dialogs_search_result(query_, {}, {});
      }
      LOG(ERROR) << "Receive error for SearchPublicDialogsQuery: " << status;
    }
    td_->dialog_manager_->on_failed_public_dialogs_search(query_, std::move(status));
  }
};

class MigrateChatQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit MigrateChatQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChatId chat_id) {
    send_query(G()->net_query_creator().create(telegram_api::messages_migrateChat(chat_id.get()), {{chat_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_migrateChat>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for MigrateChatQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class EditDialogTitleQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit EditDialogTitleQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &title) {
    dialog_id_ = dialog_id;
    switch (dialog_id.get_type()) {
      case DialogType::Chat:
        send_query(G()->net_query_creator().create(
            telegram_api::messages_editChatTitle(dialog_id.get_chat_id().get(), title), {{dialog_id_}}));
        break;
      case DialogType::Channel: {
        auto channel_id = dialog_id.get_channel_id();
        auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
        CHECK(input_channel != nullptr);
        send_query(G()->net_query_creator().create(telegram_api::channels_editTitle(std::move(input_channel), title),
                                                   {{dialog_id_}}));
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_editChatTitle::ReturnType,
                               telegram_api::channels_editTitle::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_editChatTitle>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditDialogTitleQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditDialogTitleQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class EditDialogPhotoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  FileUploadId file_upload_id_;
  bool was_uploaded_ = false;
  string file_reference_;
  DialogId dialog_id_;

 public:
  explicit EditDialogPhotoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, FileUploadId file_upload_id,
            telegram_api::object_ptr<telegram_api::InputChatPhoto> &&input_chat_photo) {
    CHECK(input_chat_photo != nullptr);
    file_upload_id_ = file_upload_id;
    was_uploaded_ = FileManager::extract_was_uploaded(input_chat_photo);
    file_reference_ = FileManager::extract_file_reference(input_chat_photo);
    dialog_id_ = dialog_id;

    switch (dialog_id.get_type()) {
      case DialogType::Chat:
        send_query(G()->net_query_creator().create(
            telegram_api::messages_editChatPhoto(dialog_id.get_chat_id().get(), std::move(input_chat_photo)),
            {{dialog_id_}}));
        break;
      case DialogType::Channel: {
        auto channel_id = dialog_id.get_channel_id();
        auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
        CHECK(input_channel != nullptr);
        send_query(G()->net_query_creator().create(
            telegram_api::channels_editPhoto(std::move(input_channel), std::move(input_chat_photo)), {{dialog_id_}}));
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_editChatPhoto::ReturnType,
                               telegram_api::channels_editPhoto::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_editChatPhoto>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditDialogPhotoQuery: " << to_string(ptr);

    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));

    if (file_upload_id_.is_valid() && was_uploaded_) {
      td_->file_manager_->delete_partial_remote_location(file_upload_id_);
    }
  }

  void on_error(Status status) final {
    if (file_upload_id_.is_valid() && was_uploaded_) {
      td_->file_manager_->delete_partial_remote_location(file_upload_id_);
    }
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      if (file_upload_id_.is_valid() && !was_uploaded_) {
        VLOG(file_references) << "Receive " << status << " for " << file_upload_id_;
        td_->file_manager_->delete_file_reference(file_upload_id_.get_file_id(), file_reference_);
        td_->dialog_manager_->upload_dialog_photo(dialog_id_, file_upload_id_, false, 0.0, false, std::move(promise_),
                                                  {-1});
        return;
      } else {
        LOG(ERROR) << "Receive file reference error, but file is " << file_upload_id_
                   << ", was_uploaded = " << was_uploaded_;
      }
    }

    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditDialogPhotoQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class EditChatDefaultBannedRightsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit EditChatDefaultBannedRightsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, RestrictedRights permissions) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::messages_editChatDefaultBannedRights(std::move(input_peer), permissions.get_chat_banned_rights()),
        {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editChatDefaultBannedRights>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditChatDefaultBannedRightsQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditChatDefaultBannedRightsQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleNoForwardsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit ToggleNoForwardsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool has_protected_content) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::messages_toggleNoForwards(std::move(input_peer), has_protected_content), {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_toggleNoForwards>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleNoForwardsQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      promise_.set_value(Unit());
      return;
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleNoForwardsQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class GetDialogUnreadMarksQuery final : public Td::ResultHandler {
 public:
  void send() {
    send_query(G()->net_query_creator().create(telegram_api::messages_getDialogUnreadMarks()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getDialogUnreadMarks>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto results = result_ptr.move_as_ok();
    for (auto &result : results) {
      td_->messages_manager_->on_update_dialog_is_marked_as_unread(DialogId(result), true);
    }

    G()->td_db()->get_binlog_pmc()->set("fetched_marks_as_unread", "1");
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for GetDialogUnreadMarksQuery: " << status;
    }
    status.ignore();
  }
};

class ReportPeerQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::ReportChatResult>> promise_;
  DialogId dialog_id_;

 public:
  explicit ReportPeerQuery(Promise<td_api::object_ptr<td_api::ReportChatResult>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &option_id, const vector<MessageId> &message_ids, const string &text) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::messages_report(std::move(input_peer), MessageId::get_server_message_ids(message_ids),
                                      BufferSlice(option_id), text),
        {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_report>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ReportPeerQuery: " << to_string(ptr);
    switch (ptr->get_id()) {
      case telegram_api::reportResultReported::ID:
        return promise_.set_value(td_api::make_object<td_api::reportChatResultOk>());
      case telegram_api::reportResultChooseOption::ID: {
        auto options = telegram_api::move_object_as<telegram_api::reportResultChooseOption>(ptr);
        if (options->options_.empty()) {
          return promise_.set_value(td_api::make_object<td_api::reportChatResultOk>());
        }
        vector<td_api::object_ptr<td_api::reportOption>> report_options;
        for (auto &option : options->options_) {
          report_options.push_back(
              td_api::make_object<td_api::reportOption>(option->option_.as_slice().str(), option->text_));
        }
        return promise_.set_value(
            td_api::make_object<td_api::reportChatResultOptionRequired>(options->title_, std::move(report_options)));
      }
      case telegram_api::reportResultAddComment::ID: {
        auto option = telegram_api::move_object_as<telegram_api::reportResultAddComment>(ptr);
        return promise_.set_value(td_api::make_object<td_api::reportChatResultTextRequired>(
            option->option_.as_slice().str(), option->optional_));
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    if (status.message() == "MESSAGE_ID_REQUIRED") {
      return promise_.set_value(td_api::make_object<td_api::reportChatResultMessagesRequired>());
    }
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReportPeerQuery");
    td_->messages_manager_->reget_dialog_action_bar(dialog_id_, "ReportPeerQuery");
    promise_.set_error(std::move(status));
  }
};

class ReportProfilePhotoQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  FileId file_id_;
  string file_reference_;
  ReportReason report_reason_;

 public:
  explicit ReportProfilePhotoQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, FileId file_id, tl_object_ptr<telegram_api::InputPhoto> &&input_photo,
            ReportReason &&report_reason) {
    dialog_id_ = dialog_id;
    file_id_ = file_id;
    file_reference_ = FileManager::extract_file_reference(input_photo);
    report_reason_ = std::move(report_reason);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::account_reportProfilePhoto(std::move(input_peer), std::move(input_photo),
                                                 report_reason_.get_input_report_reason(),
                                                 report_reason_.get_message()),
        {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_reportProfilePhoto>(packet);
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
    LOG(INFO) << "Receive error for report chat photo: " << status;
    if (!td_->auth_manager_->is_bot() && FileReferenceManager::is_file_reference_error(status)) {
      VLOG(file_references) << "Receive " << status << " for " << file_id_;
      td_->file_manager_->delete_file_reference(file_id_, file_reference_);
      td_->file_reference_manager_->repair_file_reference(
          file_id_,
          PromiseCreator::lambda([dialog_id = dialog_id_, file_id = file_id_, report_reason = std::move(report_reason_),
                                  promise = std::move(promise_)](Result<Unit> result) mutable {
            if (result.is_error()) {
              LOG(INFO) << "Reported photo " << file_id << " is likely to be deleted";
              return promise.set_value(Unit());
            }
            send_closure(G()->dialog_manager(), &DialogManager::report_dialog_photo, dialog_id, file_id,
                         std::move(report_reason), std::move(promise));
          }));
      return;
    }

    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReportProfilePhotoQuery");
    promise_.set_error(std::move(status));
  }
};

class GetPeerSettingsQuery final : public Td::ResultHandler {
  DialogId dialog_id_;

 public:
  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(
        G()->net_query_creator().create(telegram_api::messages_getPeerSettings(std::move(input_peer)), {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getPeerSettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    td_->user_manager_->on_get_users(std::move(ptr->users_), "GetPeerSettingsQuery");
    td_->chat_manager_->on_get_chats(std::move(ptr->chats_), "GetPeerSettingsQuery");
    td_->messages_manager_->on_get_peer_settings(dialog_id_, std::move(ptr->settings_));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for get peer settings: " << status;
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetPeerSettingsQuery");
  }
};

class UpdatePeerSettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit UpdatePeerSettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool is_spam_dialog) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return promise_.set_value(Unit());
    }

    if (is_spam_dialog) {
      send_query(
          G()->net_query_creator().create(telegram_api::messages_reportSpam(std::move(input_peer)), {{dialog_id_}}));
    } else {
      send_query(G()->net_query_creator().create(telegram_api::messages_hidePeerSettingsBar(std::move(input_peer)),
                                                 {{dialog_id_}}));
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_reportSpam::ReturnType,
                               telegram_api::messages_hidePeerSettingsBar::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_reportSpam>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->messages_manager_->on_get_peer_settings(dialog_id_, telegram_api::make_object<telegram_api::peerSettings>(),
                                                 true);

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for update peer settings: " << status;
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "UpdatePeerSettingsQuery");
    td_->messages_manager_->reget_dialog_action_bar(dialog_id_, "UpdatePeerSettingsQuery");
    promise_.set_error(std::move(status));
  }
};

class ReportEncryptedSpamQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit ReportEncryptedSpamQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_encrypted_chat(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(telegram_api::messages_reportEncryptedSpam(std::move(input_peer)),
                                               {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reportEncryptedSpam>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->messages_manager_->on_get_peer_settings(dialog_id_, telegram_api::make_object<telegram_api::peerSettings>(),
                                                 true);

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for report encrypted spam: " << status;
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReportEncryptedSpamQuery");
    td_->messages_manager_->reget_dialog_action_bar(
        DialogId(td_->user_manager_->get_secret_chat_user_id(dialog_id_.get_secret_chat_id())),
        "ReportEncryptedSpamQuery");
    promise_.set_error(std::move(status));
  }
};

class GetBlockedDialogsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::messageSenders>> promise_;
  int32 offset_;
  int32 limit_;

 public:
  explicit GetBlockedDialogsQuery(Promise<td_api::object_ptr<td_api::messageSenders>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(BlockListId block_list_id, int32 offset, int32 limit) {
    offset_ = offset;
    limit_ = limit;

    int32 flags = 0;
    if (block_list_id == BlockListId::stories()) {
      flags |= telegram_api::contacts_getBlocked::MY_STORIES_FROM_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::contacts_getBlocked(flags, false /*ignored*/, offset, limit), {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_getBlocked>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetBlockedDialogsQuery: " << to_string(ptr);

    switch (ptr->get_id()) {
      case telegram_api::contacts_blocked::ID: {
        auto blocked_peers = move_tl_object_as<telegram_api::contacts_blocked>(ptr);

        td_->user_manager_->on_get_users(std::move(blocked_peers->users_), "GetBlockedDialogsQuery");
        td_->chat_manager_->on_get_chats(std::move(blocked_peers->chats_), "GetBlockedDialogsQuery");
        td_->dialog_manager_->on_get_blocked_dialogs(offset_, limit_,
                                                     narrow_cast<int32>(blocked_peers->blocked_.size()),
                                                     std::move(blocked_peers->blocked_), std::move(promise_));
        break;
      }
      case telegram_api::contacts_blockedSlice::ID: {
        auto blocked_peers = move_tl_object_as<telegram_api::contacts_blockedSlice>(ptr);

        td_->user_manager_->on_get_users(std::move(blocked_peers->users_), "GetBlockedDialogsQuery slice");
        td_->chat_manager_->on_get_chats(std::move(blocked_peers->chats_), "GetBlockedDialogsQuery slice");
        td_->dialog_manager_->on_get_blocked_dialogs(offset_, limit_, blocked_peers->count_,
                                                     std::move(blocked_peers->blocked_), std::move(promise_));
        break;
      }
      default:
        UNREACHABLE();
    }
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class ReorderPinnedDialogsQuery final : public Td::ResultHandler {
  FolderId folder_id_;
  Promise<Unit> promise_;

 public:
  explicit ReorderPinnedDialogsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(FolderId folder_id, const vector<DialogId> &dialog_ids) {
    folder_id_ = folder_id;
    int32 flags = telegram_api::messages_reorderPinnedDialogs::FORCE_MASK;
    send_query(G()->net_query_creator().create(
        telegram_api::messages_reorderPinnedDialogs(
            flags, true /*ignored*/, folder_id.get(),
            td_->dialog_manager_->get_input_dialog_peers(dialog_ids, AccessRights::Read)),
        {{folder_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reorderPinnedDialogs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.move_as_ok();
    if (!result) {
      return on_error(Status::Error(400, "Result is false"));
    }
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for ReorderPinnedDialogsQuery: " << status;
    }
    td_->messages_manager_->on_update_pinned_dialogs(folder_id_);
    promise_.set_error(std::move(status));
  }
};

class SetChatAvailableReactionsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit SetChatAvailableReactionsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const ChatReactions &available_reactions) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    int32 flags = telegram_api::messages_setChatAvailableReactions::PAID_ENABLED_MASK;
    if (available_reactions.reactions_limit_ != 0) {
      flags |= telegram_api::messages_setChatAvailableReactions::REACTIONS_LIMIT_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_setChatAvailableReactions(
            flags, std::move(input_peer), available_reactions.get_input_chat_reactions(),
            available_reactions.reactions_limit_, available_reactions.paid_reactions_available_),
        {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setChatAvailableReactions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SetChatAvailableReactionsQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SetChatAvailableReactionsQuery");
      td_->dialog_manager_->reload_dialog_info_full(dialog_id_, "SetChatAvailableReactionsQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class SaveDefaultSendAsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SaveDefaultSendAsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, DialogId send_as_dialog_id) {
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    auto send_as_input_peer = td_->dialog_manager_->get_input_peer(send_as_dialog_id, AccessRights::Read);
    CHECK(send_as_input_peer != nullptr);

    send_query(G()->net_query_creator().create(
        telegram_api::messages_saveDefaultSendAs(std::move(input_peer), std::move(send_as_input_peer)),
        {{dialog_id, MessageContentType::Photo}, {dialog_id, MessageContentType::Text}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_saveDefaultSendAs>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto success = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SaveDefaultSendAsQuery: " << success;

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    // td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SaveDefaultSendAsQuery");
    promise_.set_error(std::move(status));
  }
};

class EditPeerFoldersQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit EditPeerFoldersQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, FolderId folder_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    vector<telegram_api::object_ptr<telegram_api::inputFolderPeer>> input_folder_peers;
    input_folder_peers.push_back(
        telegram_api::make_object<telegram_api::inputFolderPeer>(std::move(input_peer), folder_id.get()));
    send_query(G()->net_query_creator().create(telegram_api::folders_editPeerFolders(std::move(input_folder_peers)),
                                               {{dialog_id_}, {folder_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::folders_editPeerFolders>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditPeerFoldersQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditPeerFoldersQuery")) {
      LOG(INFO) << "Receive error for EditPeerFoldersQuery: " << status;
    }

    // trying to repair folder ID for this dialog
    td_->dialog_manager_->get_dialog_info_full(dialog_id_, Auto(), "EditPeerFoldersQuery");

    promise_.set_error(std::move(status));
  }
};

class SetHistoryTtlQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit SetHistoryTtlQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, int32 period) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(telegram_api::messages_setHistoryTTL(std::move(input_peer), period),
                                               {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setHistoryTTL>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SetHistoryTtlQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SetHistoryTtlQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class SetChatThemeQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit SetChatThemeQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const string &theme_name) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Write);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::messages_setChatTheme(std::move(input_peer), theme_name),
                                               {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_setChatTheme>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SetChatThemeQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (status.message() == "CHAT_NOT_MODIFIED") {
      if (!td_->auth_manager_->is_bot()) {
        promise_.set_value(Unit());
        return;
      }
    } else {
      td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "SetChatThemeQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleDialogIsBlockedQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit ToggleDialogIsBlockedQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool is_blocked, bool is_blocked_for_stories) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Know);
    CHECK(input_peer != nullptr && input_peer->get_id() != telegram_api::inputPeerEmpty::ID);

    int32 flags = 0;
    if (is_blocked_for_stories) {
      flags |= telegram_api::contacts_block::MY_STORIES_FROM_MASK;
    }
    vector<ChainId> chain_ids{{dialog_id, MessageContentType::Photo}, {dialog_id, MessageContentType::Text}, {"me"}};
    auto query =
        is_blocked || is_blocked_for_stories
            ? G()->net_query_creator().create(
                  telegram_api::contacts_block(flags, false /*ignored*/, std::move(input_peer)), std::move(chain_ids))
            : G()->net_query_creator().create(
                  telegram_api::contacts_unblock(flags, false /*ignored*/, std::move(input_peer)),
                  std::move(chain_ids));
    send_query(std::move(query));
  }

  void on_result(BufferSlice packet) final {
    static_assert(
        std::is_same<telegram_api::contacts_block::ReturnType, telegram_api::contacts_unblock::ReturnType>::value, "");
    auto result_ptr = fetch_result<telegram_api::contacts_block>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG_IF(WARNING, !result) << "Block/Unblock " << dialog_id_ << " has failed";

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleDialogIsBlockedQuery")) {
      LOG(ERROR) << "Receive error for ToggleDialogIsBlockedQuery: " << status;
    }
    if (!G()->close_flag()) {
      td_->dialog_manager_->get_dialog_info_full(dialog_id_, Auto(), "ToggleDialogIsBlockedQuery");
      td_->messages_manager_->reget_dialog_action_bar(dialog_id_, "ToggleDialogIsBlockedQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleDialogUnreadMarkQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  bool is_marked_as_unread_;

 public:
  explicit ToggleDialogUnreadMarkQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool is_marked_as_unread) {
    dialog_id_ = dialog_id;
    is_marked_as_unread_ = is_marked_as_unread;

    auto input_peer = td_->dialog_manager_->get_input_dialog_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (is_marked_as_unread) {
      flags |= telegram_api::messages_markDialogUnread::UNREAD_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_markDialogUnread(flags, false /*ignored*/, std::move(input_peer)), {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_markDialogUnread>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Toggle dialog mark failed"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleDialogUnreadMarkQuery")) {
      LOG(ERROR) << "Receive error for ToggleDialogUnreadMarkQuery: " << status;
    }
    if (!G()->close_flag()) {
      td_->messages_manager_->on_update_dialog_is_marked_as_unread(dialog_id_, !is_marked_as_unread_);
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleDialogPinQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  bool is_pinned_;

 public:
  explicit ToggleDialogPinQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool is_pinned) {
    dialog_id_ = dialog_id;
    is_pinned_ = is_pinned;

    auto input_peer = td_->dialog_manager_->get_input_dialog_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (is_pinned) {
      flags |= telegram_api::messages_toggleDialogPin::PINNED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_toggleDialogPin(flags, false /*ignored*/, std::move(input_peer)), {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_toggleDialogPin>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Toggle dialog pin failed"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleDialogPinQuery")) {
      LOG(ERROR) << "Receive error for ToggleDialogPinQuery: " << status;
    }
    td_->messages_manager_->on_update_pinned_dialogs(FolderId::main());
    td_->messages_manager_->on_update_pinned_dialogs(FolderId::archive());
    promise_.set_error(std::move(status));
  }
};

class ToggleDialogTranslationsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  bool is_translatable_;

 public:
  explicit ToggleDialogTranslationsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool is_translatable) {
    dialog_id_ = dialog_id;
    is_translatable_ = is_translatable;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (!is_translatable) {
      flags |= telegram_api::messages_togglePeerTranslations::DISABLED_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_togglePeerTranslations(flags, false /*ignored*/, std::move(input_peer)), {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_togglePeerTranslations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    if (!result) {
      return on_error(Status::Error(400, "Toggle dialog translations failed"));
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleDialogTranslationsQuery")) {
      LOG(ERROR) << "Receive error for ToggleDialogTranslationsQuery: " << status;
    }
    if (!G()->close_flag()) {
      td_->messages_manager_->on_update_dialog_is_translatable(dialog_id_, !is_translatable_);
    }
    promise_.set_error(std::move(status));
  }
};

class ToggleViewForumAsMessagesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  bool view_as_messages_;

 public:
  explicit ToggleViewForumAsMessagesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, bool view_as_messages) {
    dialog_id_ = dialog_id;
    view_as_messages_ = view_as_messages;

    CHECK(dialog_id.get_type() == DialogType::Channel);
    auto input_channel = td_->chat_manager_->get_input_channel(dialog_id.get_channel_id());
    CHECK(input_channel != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::channels_toggleViewForumAsMessages(std::move(input_channel), view_as_messages), {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_toggleViewForumAsMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ToggleViewForumAsMessagesQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ToggleViewForumAsMessagesQuery")) {
      LOG(ERROR) << "Receive error for ToggleViewForumAsMessagesQuery: " << status;
    }
    if (!G()->close_flag()) {
      td_->messages_manager_->on_update_dialog_view_as_messages(dialog_id_, !view_as_messages_);
    }
    promise_.set_error(std::move(status));
  }
};

class DialogManager::UploadDialogPhotoCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->dialog_manager(), &DialogManager::on_upload_dialog_photo, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->dialog_manager(), &DialogManager::on_upload_dialog_photo_error, file_upload_id,
                       std::move(error));
  }
};

DialogManager::DialogManager(Td *td, ActorShared<> parent)
    : recently_found_dialogs_{td, "recently_found", MAX_RECENT_DIALOGS}
    , recently_opened_dialogs_{td, "recently_opened", MAX_RECENT_DIALOGS}
    , td_(td)
    , parent_(std::move(parent)) {
  upload_dialog_photo_callback_ = std::make_shared<UploadDialogPhotoCallback>();
}

DialogManager::~DialogManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), resolved_usernames_,
                                              inaccessible_resolved_usernames_, found_public_dialogs_,
                                              found_on_server_dialogs_);
}

void DialogManager::hangup() {
  fail_promise_map(search_public_dialogs_queries_, Global::request_aborted_error());

  stop();
}

void DialogManager::tear_down() {
  parent_.reset();
}

DialogId DialogManager::get_my_dialog_id() const {
  return DialogId(td_->user_manager_->get_my_id());
}

InputDialogId DialogManager::get_input_dialog_id(DialogId dialog_id) const {
  auto input_peer = get_input_peer(dialog_id, AccessRights::Read);
  if (input_peer == nullptr || input_peer->get_id() == telegram_api::inputPeerSelf::ID ||
      input_peer->get_id() == telegram_api::inputPeerEmpty::ID) {
    return InputDialogId(dialog_id);
  } else {
    return InputDialogId(input_peer);
  }
}

Status DialogManager::check_dialog_access(DialogId dialog_id, bool allow_secret_chats, AccessRights access_rights,
                                          const char *source) const {
  if (!have_dialog_force(dialog_id, source)) {
    if (!dialog_id.is_valid()) {
      return Status::Error(400, "Invalid chat identifier specified");
    }
    return Status::Error(400, "Chat not found");
  }
  return check_dialog_access_in_memory(dialog_id, allow_secret_chats, access_rights);
}

Status DialogManager::check_dialog_access_in_memory(DialogId dialog_id, bool allow_secret_chats,
                                                    AccessRights access_rights) const {
  if (!have_input_peer(dialog_id, allow_secret_chats, access_rights)) {
    if (dialog_id.get_type() == DialogType::SecretChat && !allow_secret_chats) {
      return Status::Error(400, "Not supported in secret chats");
    }
    if (access_rights == AccessRights::Write || access_rights == AccessRights::Edit) {
      return Status::Error(400, "Have no write access to the chat");
    }
    return Status::Error(400, "Can't access the chat");
  }
  return Status::OK();
}

tl_object_ptr<telegram_api::InputPeer> DialogManager::get_input_peer(DialogId dialog_id,
                                                                     AccessRights access_rights) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_input_peer_user(dialog_id.get_user_id(), access_rights);
    case DialogType::Chat:
      return td_->chat_manager_->get_input_peer_chat(dialog_id.get_chat_id(), access_rights);
    case DialogType::Channel:
      return td_->chat_manager_->get_input_peer_channel(dialog_id.get_channel_id(), access_rights);
    case DialogType::SecretChat:
      return nullptr;
    case DialogType::None:
      return make_tl_object<telegram_api::inputPeerEmpty>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

tl_object_ptr<telegram_api::InputPeer> DialogManager::get_input_peer_force(DialogId dialog_id) {
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      UserId user_id = dialog_id.get_user_id();
      return make_tl_object<telegram_api::inputPeerUser>(user_id.get(), 0);
    }
    case DialogType::Chat: {
      ChatId chat_id = dialog_id.get_chat_id();
      return make_tl_object<telegram_api::inputPeerChat>(chat_id.get());
    }
    case DialogType::Channel: {
      ChannelId channel_id = dialog_id.get_channel_id();
      return make_tl_object<telegram_api::inputPeerChannel>(channel_id.get(), 0);
    }
    case DialogType::SecretChat:
    case DialogType::None:
      return make_tl_object<telegram_api::inputPeerEmpty>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

vector<tl_object_ptr<telegram_api::InputPeer>> DialogManager::get_input_peers(const vector<DialogId> &dialog_ids,
                                                                              AccessRights access_rights) const {
  vector<tl_object_ptr<telegram_api::InputPeer>> input_peers;
  input_peers.reserve(dialog_ids.size());
  for (auto &dialog_id : dialog_ids) {
    auto input_peer = get_input_peer(dialog_id, access_rights);
    if (input_peer == nullptr) {
      LOG(ERROR) << "Have no access to " << dialog_id;
      continue;
    }
    input_peers.push_back(std::move(input_peer));
  }
  return input_peers;
}

tl_object_ptr<telegram_api::InputDialogPeer> DialogManager::get_input_dialog_peer(DialogId dialog_id,
                                                                                  AccessRights access_rights) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::Channel:
    case DialogType::None:
      return make_tl_object<telegram_api::inputDialogPeer>(get_input_peer(dialog_id, access_rights));
    case DialogType::SecretChat:
      return nullptr;
    default:
      UNREACHABLE();
      return nullptr;
  }
}

vector<tl_object_ptr<telegram_api::InputDialogPeer>> DialogManager::get_input_dialog_peers(
    const vector<DialogId> &dialog_ids, AccessRights access_rights) const {
  vector<tl_object_ptr<telegram_api::InputDialogPeer>> input_dialog_peers;
  input_dialog_peers.reserve(dialog_ids.size());
  for (auto &dialog_id : dialog_ids) {
    auto input_dialog_peer = get_input_dialog_peer(dialog_id, access_rights);
    if (input_dialog_peer == nullptr) {
      LOG(ERROR) << "Have no access to " << dialog_id;
      continue;
    }
    input_dialog_peers.push_back(std::move(input_dialog_peer));
  }
  return input_dialog_peers;
}

tl_object_ptr<telegram_api::inputEncryptedChat> DialogManager::get_input_encrypted_chat(
    DialogId dialog_id, AccessRights access_rights) const {
  switch (dialog_id.get_type()) {
    case DialogType::SecretChat: {
      SecretChatId secret_chat_id = dialog_id.get_secret_chat_id();
      return td_->user_manager_->get_input_encrypted_chat(secret_chat_id, access_rights);
    }
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::Channel:
    case DialogType::None:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

bool DialogManager::have_input_peer(DialogId dialog_id, bool allow_secret_chats, AccessRights access_rights) const {
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      UserId user_id = dialog_id.get_user_id();
      return td_->user_manager_->have_input_peer_user(user_id, access_rights);
    }
    case DialogType::Chat: {
      ChatId chat_id = dialog_id.get_chat_id();
      return td_->chat_manager_->have_input_peer_chat(chat_id, access_rights);
    }
    case DialogType::Channel: {
      ChannelId channel_id = dialog_id.get_channel_id();
      return td_->chat_manager_->have_input_peer_channel(channel_id, access_rights);
    }
    case DialogType::SecretChat: {
      if (!allow_secret_chats) {
        return false;
      }
      SecretChatId secret_chat_id = dialog_id.get_secret_chat_id();
      return td_->user_manager_->have_input_encrypted_peer(secret_chat_id, access_rights);
    }
    case DialogType::None:
      return false;
    default:
      UNREACHABLE();
      return false;
  }
}

bool DialogManager::have_dialog_force(DialogId dialog_id, const char *source) const {
  return td_->messages_manager_->have_dialog_force(dialog_id, source);
}

void DialogManager::force_create_dialog(DialogId dialog_id, const char *source, bool expect_no_access,
                                        bool force_update_dialog_pos) {
  td_->messages_manager_->force_create_dialog(dialog_id, source, expect_no_access, force_update_dialog_pos);
}

vector<DialogId> DialogManager::get_peers_dialog_ids(vector<telegram_api::object_ptr<telegram_api::Peer>> &&peers,
                                                     bool expect_no_access) {
  vector<DialogId> result;
  result.reserve(peers.size());
  for (auto &peer : peers) {
    DialogId dialog_id(peer);
    if (dialog_id.is_valid()) {
      force_create_dialog(dialog_id, "get_peers_dialog_ids", expect_no_access);
      result.push_back(dialog_id);
    }
  }
  return result;
}

bool DialogManager::have_dialog_info(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      UserId user_id = dialog_id.get_user_id();
      return td_->user_manager_->have_user(user_id);
    }
    case DialogType::Chat: {
      ChatId chat_id = dialog_id.get_chat_id();
      return td_->chat_manager_->have_chat(chat_id);
    }
    case DialogType::Channel: {
      ChannelId channel_id = dialog_id.get_channel_id();
      return td_->chat_manager_->have_channel(channel_id);
    }
    case DialogType::SecretChat: {
      SecretChatId secret_chat_id = dialog_id.get_secret_chat_id();
      return td_->user_manager_->have_secret_chat(secret_chat_id);
    }
    case DialogType::None:
    default:
      return false;
  }
}

bool DialogManager::is_dialog_info_received_from_server(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->is_user_received_from_server(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->is_chat_received_from_server(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->is_channel_received_from_server(dialog_id.get_channel_id());
    default:
      return false;
  }
}

bool DialogManager::have_dialog_info_force(DialogId dialog_id, const char *source) const {
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      UserId user_id = dialog_id.get_user_id();
      return td_->user_manager_->have_user_force(user_id, source);
    }
    case DialogType::Chat: {
      ChatId chat_id = dialog_id.get_chat_id();
      return td_->chat_manager_->have_chat_force(chat_id, source);
    }
    case DialogType::Channel: {
      ChannelId channel_id = dialog_id.get_channel_id();
      return td_->chat_manager_->have_channel_force(channel_id, source);
    }
    case DialogType::SecretChat: {
      SecretChatId secret_chat_id = dialog_id.get_secret_chat_id();
      return td_->user_manager_->have_secret_chat_force(secret_chat_id, source);
    }
    case DialogType::None:
    default:
      return false;
  }
}

void DialogManager::reload_dialog_info(DialogId dialog_id, Promise<Unit> &&promise) {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->reload_user(dialog_id.get_user_id(), std::move(promise), "reload_dialog_info");
    case DialogType::Chat:
      return td_->chat_manager_->reload_chat(dialog_id.get_chat_id(), std::move(promise), "reload_dialog_info");
    case DialogType::Channel:
      return td_->chat_manager_->reload_channel(dialog_id.get_channel_id(), std::move(promise), "reload_dialog_info");
    default:
      return promise.set_error(Status::Error("Invalid chat identifier to reload"));
  }
}

void DialogManager::get_dialog_info_full(DialogId dialog_id, Promise<Unit> &&promise, const char *source) {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      send_closure_later(td_->user_manager_actor_, &UserManager::load_user_full, dialog_id.get_user_id(), false,
                         std::move(promise), source);
      return;
    case DialogType::Chat:
      send_closure_later(td_->chat_manager_actor_, &ChatManager::load_chat_full, dialog_id.get_chat_id(), false,
                         std::move(promise), source);
      return;
    case DialogType::Channel:
      send_closure_later(td_->chat_manager_actor_, &ChatManager::load_channel_full, dialog_id.get_channel_id(), false,
                         std::move(promise), source);
      return;
    case DialogType::SecretChat:
      return promise.set_value(Unit());
    case DialogType::None:
    default:
      UNREACHABLE();
      return promise.set_error(Status::Error(500, "Wrong chat type"));
  }
}

void DialogManager::reload_dialog_info_full(DialogId dialog_id, const char *source) {
  if (G()->close_flag()) {
    return;
  }

  LOG(INFO) << "Reload full info about " << dialog_id << " from " << source;
  switch (dialog_id.get_type()) {
    case DialogType::User:
      send_closure_later(td_->user_manager_actor_, &UserManager::reload_user_full, dialog_id.get_user_id(),
                         Promise<Unit>(), source);
      return;
    case DialogType::Chat:
      send_closure_later(td_->chat_manager_actor_, &ChatManager::reload_chat_full, dialog_id.get_chat_id(),
                         Promise<Unit>(), source);
      return;
    case DialogType::Channel:
      send_closure_later(td_->chat_manager_actor_, &ChatManager::reload_channel_full, dialog_id.get_channel_id(),
                         Promise<Unit>(), source);
      return;
    case DialogType::SecretChat:
      return;
    case DialogType::None:
    default:
      UNREACHABLE();
      return;
  }
}

void DialogManager::on_dialog_info_full_invalidated(DialogId dialog_id) {
  if (td_->messages_manager_->is_dialog_opened(dialog_id)) {
    reload_dialog_info_full(dialog_id, "on_dialog_info_full_invalidated");
  }
}

int64 DialogManager::get_chat_id_object(DialogId dialog_id, const char *source) const {
  return td_->messages_manager_->get_chat_id_object(dialog_id, source);
}

vector<int64> DialogManager::get_chat_ids_object(const vector<DialogId> &dialog_ids, const char *source) const {
  return transform(dialog_ids, [this, source](DialogId dialog_id) { return get_chat_id_object(dialog_id, source); });
}

td_api::object_ptr<td_api::chats> DialogManager::get_chats_object(int32 total_count, const vector<DialogId> &dialog_ids,
                                                                  const char *source) const {
  if (total_count == -1) {
    total_count = narrow_cast<int32>(dialog_ids.size());
  }
  return td_api::make_object<td_api::chats>(total_count, get_chat_ids_object(dialog_ids, source));
}

td_api::object_ptr<td_api::chats> DialogManager::get_chats_object(const std::pair<int32, vector<DialogId>> &dialog_ids,
                                                                  const char *source) const {
  return get_chats_object(dialog_ids.first, dialog_ids.second, source);
}

td_api::object_ptr<td_api::ChatType> DialogManager::get_chat_type_object(DialogId dialog_id, const char *source) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_api::make_object<td_api::chatTypePrivate>(
          td_->user_manager_->get_user_id_object(dialog_id.get_user_id(), source));
    case DialogType::Chat:
      return td_api::make_object<td_api::chatTypeBasicGroup>(
          td_->chat_manager_->get_basic_group_id_object(dialog_id.get_chat_id(), source));
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      return td_api::make_object<td_api::chatTypeSupergroup>(
          td_->chat_manager_->get_supergroup_id_object(channel_id, source),
          !td_->chat_manager_->is_megagroup_channel(channel_id));
    }
    case DialogType::SecretChat: {
      auto secret_chat_id = dialog_id.get_secret_chat_id();
      auto user_id = td_->user_manager_->get_secret_chat_user_id(secret_chat_id);
      return td_api::make_object<td_api::chatTypeSecret>(
          td_->user_manager_->get_secret_chat_id_object(secret_chat_id, source),
          td_->user_manager_->get_user_id_object(user_id, source));
    }
    case DialogType::None:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

NotificationSettingsScope DialogManager::get_dialog_notification_setting_scope(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::SecretChat:
      return NotificationSettingsScope::Private;
    case DialogType::Chat:
      return NotificationSettingsScope::Group;
    case DialogType::Channel:
      return is_broadcast_channel(dialog_id) ? NotificationSettingsScope::Channel : NotificationSettingsScope::Group;
    case DialogType::None:
    default:
      UNREACHABLE();
      return NotificationSettingsScope::Private;
  }
}

void DialogManager::migrate_dialog_to_megagroup(DialogId dialog_id,
                                                Promise<td_api::object_ptr<td_api::chat>> &&promise) {
  if (!have_dialog_force(dialog_id, "migrate_dialog_to_megagroup")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }
  if (dialog_id.get_type() != DialogType::Chat) {
    return promise.set_error(Status::Error(400, "Only basic group chats can be converted to supergroup"));
  }

  auto chat_id = dialog_id.get_chat_id();
  if (!td_->chat_manager_->get_chat_status(chat_id).is_creator()) {
    return promise.set_error(Status::Error(400, "Need creator rights in the chat"));
  }
  if (td_->chat_manager_->get_chat_migrated_to_channel_id(chat_id).is_valid()) {
    return on_migrate_chat_to_megagroup(chat_id, std::move(promise));
  }

  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), chat_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_error()) {
          return promise.set_error(result.move_as_error());
        }
        send_closure(actor_id, &DialogManager::on_migrate_chat_to_megagroup, chat_id, std::move(promise));
      });
  td_->create_handler<MigrateChatQuery>(std::move(query_promise))->send(chat_id);
}

void DialogManager::on_migrate_chat_to_megagroup(ChatId chat_id, Promise<td_api::object_ptr<td_api::chat>> &&promise) {
  auto channel_id = td_->chat_manager_->get_chat_migrated_to_channel_id(chat_id);
  if (!channel_id.is_valid()) {
    LOG(ERROR) << "Can't find the supergroup to which the basic group has migrated";
    return promise.set_error(Status::Error(500, "Supergroup not found"));
  }
  if (!td_->chat_manager_->have_channel(channel_id)) {
    LOG(ERROR) << "Can't find info about the supergroup to which the basic group has migrated";
    return promise.set_error(Status::Error(500, "Supergroup info is not found"));
  }

  auto dialog_id = DialogId(channel_id);
  force_create_dialog(dialog_id, "on_migrate_chat_to_megagroup");
  promise.set_value(td_->messages_manager_->get_chat_object(dialog_id, "on_migrate_chat_to_megagroup"));
}

void DialogManager::on_dialog_opened(DialogId dialog_id) {
  if (!td_->auth_manager_->is_bot()) {
    recently_opened_dialogs_.add_dialog(dialog_id);
  }
}

void DialogManager::on_dialog_deleted(DialogId dialog_id) {
  if (!td_->auth_manager_->is_bot()) {
    recently_found_dialogs_.remove_dialog(dialog_id);
    recently_opened_dialogs_.remove_dialog(dialog_id);
  }
}

std::pair<int32, vector<DialogId>> DialogManager::search_recently_found_dialogs(const string &query, int32 limit,
                                                                                Promise<Unit> &&promise) {
  auto result = recently_found_dialogs_.get_dialogs(query.empty() ? limit : 50, std::move(promise));
  if (result.first == 0 || query.empty()) {
    return result;
  }

  Hints hints;
  int rating = 1;
  for (auto dialog_id : result.second) {
    hints.add(dialog_id.get(), get_dialog_search_text(dialog_id));
    hints.set_rating(dialog_id.get(), ++rating);
  }

  auto hints_result = hints.search(query, limit, false);
  return {narrow_cast<int32>(hints_result.first),
          transform(hints_result.second, [](int64 key) { return DialogId(key); })};
}

Status DialogManager::add_recently_found_dialog(DialogId dialog_id) {
  if (!have_dialog_force(dialog_id, "add_recently_found_dialog")) {
    return Status::Error(400, "Chat not found");
  }
  recently_found_dialogs_.add_dialog(dialog_id);
  return Status::OK();
}

Status DialogManager::remove_recently_found_dialog(DialogId dialog_id) {
  if (!have_dialog_force(dialog_id, "remove_recently_found_dialog")) {
    return Status::Error(400, "Chat not found");
  }
  recently_found_dialogs_.remove_dialog(dialog_id);
  return Status::OK();
}

void DialogManager::clear_recently_found_dialogs() {
  recently_found_dialogs_.clear_dialogs();
}

std::pair<int32, vector<DialogId>> DialogManager::get_recently_opened_dialogs(int32 limit, Promise<Unit> &&promise) {
  CHECK(!td_->auth_manager_->is_bot());
  return recently_opened_dialogs_.get_dialogs(limit, std::move(promise));
}

bool DialogManager::is_anonymous_administrator(DialogId dialog_id, string *author_signature) const {
  CHECK(dialog_id.is_valid());

  if (is_broadcast_channel(dialog_id)) {
    return true;
  }

  if (td_->auth_manager_->is_bot()) {
    return false;
  }

  if (dialog_id.get_type() != DialogType::Channel) {
    return false;
  }

  auto status = td_->chat_manager_->get_channel_status(dialog_id.get_channel_id());
  if (!status.is_anonymous()) {
    return false;
  }

  if (author_signature != nullptr) {
    *author_signature = status.get_rank();
  }
  return true;
}

bool DialogManager::is_group_dialog(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::Chat:
      return true;
    case DialogType::Channel:
      return td_->chat_manager_->is_megagroup_channel(dialog_id.get_channel_id());
    default:
      return false;
  }
}

bool DialogManager::is_forum_channel(DialogId dialog_id) const {
  return dialog_id.get_type() == DialogType::Channel &&
         td_->chat_manager_->is_forum_channel(dialog_id.get_channel_id());
}

bool DialogManager::is_broadcast_channel(DialogId dialog_id) const {
  if (dialog_id.get_type() != DialogType::Channel) {
    return false;
  }

  return td_->chat_manager_->is_broadcast_channel(dialog_id.get_channel_id());
}

bool DialogManager::on_get_dialog_error(DialogId dialog_id, const Status &status, const char *source) {
  auto message = status.message();
  if (message == CSlice("BOT_METHOD_INVALID")) {
    LOG(ERROR) << "Receive BOT_METHOD_INVALID from " << source;
    return true;
  }
  if (G()->is_expected_error(status)) {
    return true;
  }
  if (message == CSlice("SEND_AS_PEER_INVALID")) {
    reload_dialog_info_full(dialog_id, "SEND_AS_PEER_INVALID");
    return true;
  }
  if (message == CSlice("QUOTE_TEXT_INVALID") || message == CSlice("REPLY_MESSAGE_ID_INVALID") ||
      begins_with(message, "ALLOW_PAYMENT_REQUIRED_")) {
    return true;
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::SecretChat:
      // to be implemented if necessary
      break;
    case DialogType::Channel:
      return td_->chat_manager_->on_get_channel_error(dialog_id.get_channel_id(), status, source);
    case DialogType::None:
      // to be implemented if necessary
      break;
    default:
      UNREACHABLE();
  }
  return false;
}

void DialogManager::delete_dialog(DialogId dialog_id, Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "delete_dialog")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->messages_manager_->delete_dialog_history(dialog_id, true, true, std::move(promise));
    case DialogType::Chat:
      return td_->chat_manager_->delete_chat(dialog_id.get_chat_id(), std::move(promise));
    case DialogType::Channel:
      return td_->chat_manager_->delete_channel(dialog_id.get_channel_id(), std::move(promise));
    case DialogType::SecretChat:
      send_closure(td_->secret_chats_manager_, &SecretChatsManager::cancel_chat, dialog_id.get_secret_chat_id(), true,
                   std::move(promise));
      return;
    default:
      UNREACHABLE();
  }
}

string DialogManager::get_dialog_title(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_title(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_title(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_title(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_title(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return string();
  }
}

const DialogPhoto *DialogManager::get_dialog_photo(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_dialog_photo(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_dialog_photo(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_dialog_photo(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_dialog_photo(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

int32 DialogManager::get_dialog_accent_color_id_object(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_accent_color_id_object(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_accent_color_id_object(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_accent_color_id_object(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_accent_color_id_object(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return 0;
  }
}

CustomEmojiId DialogManager::get_dialog_background_custom_emoji_id(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_background_custom_emoji_id(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_background_custom_emoji_id(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_background_custom_emoji_id(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_background_custom_emoji_id(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return CustomEmojiId();
  }
}

int32 DialogManager::get_dialog_profile_accent_color_id_object(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_profile_accent_color_id_object(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_profile_accent_color_id_object(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_profile_accent_color_id_object(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_profile_accent_color_id_object(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return 0;
  }
}

CustomEmojiId DialogManager::get_dialog_profile_background_custom_emoji_id(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_profile_background_custom_emoji_id(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_profile_background_custom_emoji_id(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_profile_background_custom_emoji_id(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_profile_background_custom_emoji_id(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return CustomEmojiId();
  }
}

RestrictedRights DialogManager::get_dialog_default_permissions(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_default_permissions(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_default_permissions(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_default_permissions(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_default_permissions(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return RestrictedRights(false, false, false, false, false, false, false, false, false, false, false, false, false,
                              false, false, false, false, ChannelType::Unknown);
  }
}

td_api::object_ptr<td_api::emojiStatus> DialogManager::get_dialog_emoji_status_object(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_emoji_status_object(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_emoji_status_object(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_emoji_status_object(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_emoji_status_object(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return 0;
  }
}

string DialogManager::get_dialog_about(DialogId dialog_id) {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_about(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_about(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_about(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_secret_chat_about(dialog_id.get_secret_chat_id());
    case DialogType::None:
    default:
      UNREACHABLE();
      return string();
  }
}

string DialogManager::get_dialog_search_text(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->get_user_search_text(dialog_id.get_user_id());
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_title(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_search_text(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return td_->user_manager_->get_user_search_text(
          td_->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id()));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  return string();
}

bool DialogManager::get_dialog_has_protected_content(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return false;
    case DialogType::Chat:
      return td_->chat_manager_->get_chat_has_protected_content(dialog_id.get_chat_id());
    case DialogType::Channel:
      return td_->chat_manager_->get_channel_has_protected_content(dialog_id.get_channel_id());
    case DialogType::SecretChat:
      return false;
    case DialogType::None:
    default:
      UNREACHABLE();
      return true;
  }
}

bool DialogManager::is_dialog_action_unneeded(DialogId dialog_id) const {
  if (is_anonymous_administrator(dialog_id, nullptr)) {
    return true;
  }

  auto dialog_type = dialog_id.get_type();
  if (dialog_type == DialogType::User || dialog_type == DialogType::SecretChat) {
    UserId user_id = dialog_type == DialogType::User
                         ? dialog_id.get_user_id()
                         : td_->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
    if (td_->user_manager_->is_user_deleted(user_id)) {
      return true;
    }
    if (td_->user_manager_->is_user_bot(user_id) && !td_->user_manager_->is_user_support(user_id)) {
      return true;
    }
    if (user_id == td_->user_manager_->get_my_id()) {
      return true;
    }

    if (!td_->auth_manager_->is_bot()) {
      if (td_->user_manager_->is_user_status_exact(user_id)) {
        if (!td_->user_manager_->is_user_online(user_id, 30)) {
          return true;
        }
      } else {
        // return true;
      }
    }
  }
  return false;
}

void DialogManager::set_dialog_title(DialogId dialog_id, const string &title, Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "set_dialog_title")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  auto new_title = clean_name(title, MAX_TITLE_LENGTH);
  if (new_title.empty()) {
    return promise.set_error(Status::Error(400, "Title must be non-empty"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't change private chat title"));
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      auto status = td_->chat_manager_->get_chat_permissions(chat_id);
      if (!status.can_change_info_and_settings() ||
          (td_->auth_manager_->is_bot() && !td_->chat_manager_->is_appointed_chat_administrator(chat_id))) {
        return promise.set_error(Status::Error(400, "Not enough rights to change chat title"));
      }
      break;
    }
    case DialogType::Channel: {
      auto status = td_->chat_manager_->get_channel_permissions(dialog_id.get_channel_id());
      if (!status.can_change_info_and_settings()) {
        return promise.set_error(Status::Error(400, "Not enough rights to change chat title"));
      }
      break;
    }
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't change secret chat title"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }

  // TODO this can be wrong if there were previous change title requests
  if (get_dialog_title(dialog_id) == new_title) {
    return promise.set_value(Unit());
  }

  td_->create_handler<EditDialogTitleQuery>(std::move(promise))->send(dialog_id, new_title);
}

void DialogManager::set_dialog_photo(DialogId dialog_id, const td_api::object_ptr<td_api::InputChatPhoto> &input_photo,
                                     Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "set_dialog_photo")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't change private chat photo"));
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      auto status = td_->chat_manager_->get_chat_permissions(chat_id);
      if (!status.can_change_info_and_settings() ||
          (td_->auth_manager_->is_bot() && !td_->chat_manager_->is_appointed_chat_administrator(chat_id))) {
        return promise.set_error(Status::Error(400, "Not enough rights to change chat photo"));
      }
      break;
    }
    case DialogType::Channel: {
      auto status = td_->chat_manager_->get_channel_permissions(dialog_id.get_channel_id());
      if (!status.can_change_info_and_settings()) {
        return promise.set_error(Status::Error(400, "Not enough rights to change chat photo"));
      }
      break;
    }
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't change secret chat photo"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }

  const td_api::object_ptr<td_api::InputFile> *input_file = nullptr;
  double main_frame_timestamp = 0.0;
  bool is_animation = false;
  if (input_photo != nullptr) {
    switch (input_photo->get_id()) {
      case td_api::inputChatPhotoPrevious::ID: {
        auto photo = static_cast<const td_api::inputChatPhotoPrevious *>(input_photo.get());
        auto file_id = td_->user_manager_->get_profile_photo_file_id(photo->chat_photo_id_);
        if (!file_id.is_valid()) {
          return promise.set_error(Status::Error(400, "Unknown profile photo identifier specified"));
        }

        auto file_view = td_->file_manager_->get_file_view(file_id);
        const auto *main_remote_location = file_view.get_main_remote_location();
        if (main_remote_location == nullptr) {
          return promise.set_error(Status::Error(400, "Invalid profile photo identifier specified"));
        }
        auto input_chat_photo =
            telegram_api::make_object<telegram_api::inputChatPhoto>(main_remote_location->as_input_photo());
        return send_edit_dialog_photo_query(dialog_id, {file_id, FileManager::get_internal_upload_id()},
                                            std::move(input_chat_photo), std::move(promise));
      }
      case td_api::inputChatPhotoStatic::ID: {
        auto photo = static_cast<const td_api::inputChatPhotoStatic *>(input_photo.get());
        input_file = &photo->photo_;
        break;
      }
      case td_api::inputChatPhotoAnimation::ID: {
        auto photo = static_cast<const td_api::inputChatPhotoAnimation *>(input_photo.get());
        input_file = &photo->animation_;
        main_frame_timestamp = photo->main_frame_timestamp_;
        is_animation = true;
        break;
      }
      case td_api::inputChatPhotoSticker::ID: {
        auto photo = static_cast<const td_api::inputChatPhotoSticker *>(input_photo.get());
        TRY_RESULT_PROMISE(promise, sticker_photo_size, StickerPhotoSize::get_sticker_photo_size(td_, photo->sticker_));

        int32 flags = telegram_api::inputChatUploadedPhoto::VIDEO_EMOJI_MARKUP_MASK;
        auto input_chat_photo = telegram_api::make_object<telegram_api::inputChatUploadedPhoto>(
            flags, nullptr, nullptr, 0.0, sticker_photo_size->get_input_video_size_object(td_));
        return send_edit_dialog_photo_query(dialog_id, FileUploadId(), std::move(input_chat_photo), std::move(promise));
      }
      default:
        UNREACHABLE();
        break;
    }
  }
  if (input_file == nullptr) {
    send_edit_dialog_photo_query(dialog_id, FileUploadId(),
                                 telegram_api::make_object<telegram_api::inputChatPhotoEmpty>(), std::move(promise));
    return;
  }

  const double MAX_ANIMATION_DURATION = 10.0;
  if (main_frame_timestamp < 0.0 || main_frame_timestamp > MAX_ANIMATION_DURATION) {
    return promise.set_error(Status::Error(400, "Wrong main frame timestamp specified"));
  }

  auto file_type = is_animation ? FileType::Animation : FileType::Photo;
  TRY_RESULT_PROMISE(promise, file_id,
                     td_->file_manager_->get_input_file_id(file_type, *input_file, dialog_id, true, false));
  if (!file_id.is_valid()) {
    send_edit_dialog_photo_query(dialog_id, FileUploadId(),
                                 telegram_api::make_object<telegram_api::inputChatPhotoEmpty>(), std::move(promise));
    return;
  }

  upload_dialog_photo(dialog_id, {file_id, FileManager::get_internal_upload_id()}, is_animation, main_frame_timestamp,
                      false, std::move(promise));
}

void DialogManager::send_edit_dialog_photo_query(
    DialogId dialog_id, FileUploadId file_upload_id,
    telegram_api::object_ptr<telegram_api::InputChatPhoto> &&input_chat_photo, Promise<Unit> &&promise) {
  td_->create_handler<EditDialogPhotoQuery>(std::move(promise))
      ->send(dialog_id, file_upload_id, std::move(input_chat_photo));
}

void DialogManager::upload_dialog_photo(DialogId dialog_id, FileUploadId file_upload_id, bool is_animation,
                                        double main_frame_timestamp, bool is_reupload, Promise<Unit> &&promise,
                                        vector<int> bad_parts) {
  CHECK(file_upload_id.is_valid());
  LOG(INFO) << "Ask to upload chat photo " << file_upload_id;
  bool is_inserted = being_uploaded_dialog_photos_
                         .emplace(file_upload_id, UploadedDialogPhotoInfo{dialog_id, main_frame_timestamp, is_animation,
                                                                          is_reupload, std::move(promise)})
                         .second;
  CHECK(is_inserted);
  // TODO use force_reupload if is_reupload
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_dialog_photo_callback_, 32, 0);
}

void DialogManager::on_upload_dialog_photo(FileUploadId file_upload_id,
                                           telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Chat photo " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_dialog_photos_.find(file_upload_id);
  CHECK(it != being_uploaded_dialog_photos_.end());
  DialogId dialog_id = it->second.dialog_id;
  double main_frame_timestamp = it->second.main_frame_timestamp;
  bool is_animation = it->second.is_animation;
  bool is_reupload = it->second.is_reupload;
  Promise<Unit> promise = std::move(it->second.promise);
  being_uploaded_dialog_photos_.erase(it);

  FileView file_view = td_->file_manager_->get_file_view(file_upload_id.get_file_id());
  CHECK(!file_view.is_encrypted());
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (input_file == nullptr && main_remote_location != nullptr) {
    if (main_remote_location->is_web()) {
      return promise.set_error(Status::Error(400, "Can't use web photo as profile photo"));
    }
    if (is_reupload) {
      return promise.set_error(Status::Error(400, "Failed to reupload the file"));
    }

    if (is_animation) {
      CHECK(file_view.get_type() == FileType::Animation);
      // delete file reference and forcely reupload the file
      auto file_reference = FileManager::extract_file_reference(main_remote_location->as_input_document());
      td_->file_manager_->delete_file_reference(file_upload_id.get_file_id(), file_reference);
      upload_dialog_photo(dialog_id, file_upload_id, is_animation, main_frame_timestamp, true, std::move(promise),
                          {-1});
    } else {
      CHECK(file_view.get_type() == FileType::Photo);
      auto input_photo = main_remote_location->as_input_photo();
      auto input_chat_photo = telegram_api::make_object<telegram_api::inputChatPhoto>(std::move(input_photo));
      send_edit_dialog_photo_query(dialog_id, file_upload_id, std::move(input_chat_photo), std::move(promise));
    }
    return;
  }
  CHECK(input_file != nullptr);

  int32 flags = 0;
  telegram_api::object_ptr<telegram_api::InputFile> photo_input_file;
  telegram_api::object_ptr<telegram_api::InputFile> video_input_file;
  if (is_animation) {
    flags |= telegram_api::inputChatUploadedPhoto::VIDEO_MASK;
    video_input_file = std::move(input_file);

    if (main_frame_timestamp != 0.0) {
      flags |= telegram_api::inputChatUploadedPhoto::VIDEO_START_TS_MASK;
    }
  } else {
    flags |= telegram_api::inputChatUploadedPhoto::FILE_MASK;
    photo_input_file = std::move(input_file);
  }

  auto input_chat_photo = telegram_api::make_object<telegram_api::inputChatUploadedPhoto>(
      flags, std::move(photo_input_file), std::move(video_input_file), main_frame_timestamp, nullptr);
  send_edit_dialog_photo_query(dialog_id, file_upload_id, std::move(input_chat_photo), std::move(promise));
}

void DialogManager::on_upload_dialog_photo_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(INFO) << "Chat photo " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_dialog_photos_.find(file_upload_id);
  CHECK(it != being_uploaded_dialog_photos_.end());
  Promise<Unit> promise = std::move(it->second.promise);
  being_uploaded_dialog_photos_.erase(it);

  promise.set_error(std::move(status));
}

void DialogManager::set_dialog_accent_color(DialogId dialog_id, AccentColorId accent_color_id,
                                            CustomEmojiId background_custom_emoji_id, Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "set_dialog_accent_color")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      if (dialog_id == get_my_dialog_id()) {
        return td_->user_manager_->set_accent_color(accent_color_id, background_custom_emoji_id, std::move(promise));
      }
      break;
    case DialogType::Chat:
      break;
    case DialogType::Channel:
      return td_->chat_manager_->set_channel_accent_color(dialog_id.get_channel_id(), accent_color_id,
                                                          background_custom_emoji_id, std::move(promise));
    case DialogType::SecretChat:
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  promise.set_error(Status::Error(400, "Can't change accent color in the chat"));
}

void DialogManager::set_dialog_profile_accent_color(DialogId dialog_id, AccentColorId profile_accent_color_id,
                                                    CustomEmojiId profile_background_custom_emoji_id,
                                                    Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "set_dialog_profile_accent_color")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      if (dialog_id == get_my_dialog_id()) {
        return td_->user_manager_->set_profile_accent_color(profile_accent_color_id, profile_background_custom_emoji_id,
                                                            std::move(promise));
      }
      break;
    case DialogType::Chat:
      break;
    case DialogType::Channel:
      return td_->chat_manager_->set_channel_profile_accent_color(
          dialog_id.get_channel_id(), profile_accent_color_id, profile_background_custom_emoji_id, std::move(promise));
    case DialogType::SecretChat:
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  promise.set_error(Status::Error(400, "Can't change profile accent color in the chat"));
}

void DialogManager::set_dialog_permissions(DialogId dialog_id,
                                           const td_api::object_ptr<td_api::chatPermissions> &permissions,
                                           Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, check_dialog_access(dialog_id, false, AccessRights::Write, "set_dialog_permissions"));

  if (permissions == nullptr) {
    return promise.set_error(Status::Error(400, "New permissions must be non-empty"));
  }

  ChannelType channel_type = ChannelType::Unknown;
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't change private chat permissions"));
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      auto status = td_->chat_manager_->get_chat_permissions(chat_id);
      if (!status.can_restrict_members()) {
        return promise.set_error(Status::Error(400, "Not enough rights to change chat permissions"));
      }
      break;
    }
    case DialogType::Channel: {
      if (is_broadcast_channel(dialog_id)) {
        return promise.set_error(Status::Error(400, "Can't change channel chat permissions"));
      }
      auto status = td_->chat_manager_->get_channel_permissions(dialog_id.get_channel_id());
      if (!status.can_restrict_members()) {
        return promise.set_error(Status::Error(400, "Not enough rights to change chat permissions"));
      }
      channel_type = ChannelType::Megagroup;
      break;
    }
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      UNREACHABLE();
  }

  RestrictedRights new_permissions(permissions, channel_type);

  // TODO this can be wrong if there were previous change permissions requests
  if (get_dialog_default_permissions(dialog_id) == new_permissions) {
    return promise.set_value(Unit());
  }

  td_->create_handler<EditChatDefaultBannedRightsQuery>(std::move(promise))->send(dialog_id, new_permissions);
}

void DialogManager::set_dialog_emoji_status(DialogId dialog_id, const unique_ptr<EmojiStatus> &emoji_status,
                                            Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "set_dialog_emoji_status")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      if (dialog_id == get_my_dialog_id()) {
        return td_->user_manager_->set_emoji_status(emoji_status, std::move(promise));
      }
      break;
    case DialogType::Chat:
      break;
    case DialogType::Channel:
      return td_->chat_manager_->set_channel_emoji_status(dialog_id.get_channel_id(), emoji_status, std::move(promise));
    case DialogType::SecretChat:
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  promise.set_error(Status::Error(400, "Can't change emoji status in the chat"));
}

void DialogManager::toggle_dialog_has_protected_content(DialogId dialog_id, bool has_protected_content,
                                                        Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise,
                     check_dialog_access(dialog_id, false, AccessRights::Read, "toggle_dialog_has_protected_content"));

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't restrict saving content in the chat"));
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      auto status = td_->chat_manager_->get_chat_status(chat_id);
      if (!status.is_creator()) {
        return promise.set_error(Status::Error(400, "Only owner can restrict saving content"));
      }
      break;
    }
    case DialogType::Channel: {
      auto status = td_->chat_manager_->get_channel_status(dialog_id.get_channel_id());
      if (!status.is_creator()) {
        return promise.set_error(Status::Error(400, "Only owner can restrict saving content"));
      }
      break;
    }
    case DialogType::SecretChat:
    case DialogType::None:
    default:
      UNREACHABLE();
  }

  // TODO this can be wrong if there were previous toggle_dialog_has_protected_content requests
  if (get_dialog_has_protected_content(dialog_id) == has_protected_content) {
    return promise.set_value(Unit());
  }

  td_->create_handler<ToggleNoForwardsQuery>(std::move(promise))->send(dialog_id, has_protected_content);
}

void DialogManager::set_dialog_description(DialogId dialog_id, const string &description, Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "set_dialog_description")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return promise.set_error(Status::Error(400, "Can't change private chat description"));
    case DialogType::Chat:
      return td_->chat_manager_->set_chat_description(dialog_id.get_chat_id(), description, std::move(promise));
    case DialogType::Channel:
      return td_->chat_manager_->set_channel_description(dialog_id.get_channel_id(), description, std::move(promise));
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "Can't change secret chat description"));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogManager::set_dialog_location(DialogId dialog_id, const DialogLocation &location, Promise<Unit> &&promise) {
  if (!have_dialog_force(dialog_id, "set_dialog_location")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::SecretChat:
      return promise.set_error(Status::Error(400, "The chat can't have location"));
    case DialogType::Channel:
      return td_->chat_manager_->set_channel_location(dialog_id.get_channel_id(), location, std::move(promise));
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

void DialogManager::load_dialog_marks_as_unread() {
  if (!G()->td_db()->get_binlog_pmc()->isset("fetched_marks_as_unread")) {
    td_->create_handler<GetDialogUnreadMarksQuery>()->send();
  }
}

bool DialogManager::can_report_dialog(DialogId dialog_id) const {
  // doesn't include possibility of report from action bar
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->user_manager_->can_report_user(dialog_id.get_user_id());
    case DialogType::Chat:
      return false;
    case DialogType::Channel:
      return !td_->chat_manager_->get_channel_status(dialog_id.get_channel_id()).is_creator();
    case DialogType::SecretChat:
      return false;
    case DialogType::None:
    default:
      UNREACHABLE();
      return false;
  }
}

void DialogManager::report_dialog(DialogId dialog_id, const string &option_id, const vector<MessageId> &message_ids,
                                  const string &text, Promise<td_api::object_ptr<td_api::ReportChatResult>> &&promise) {
  TRY_STATUS_PROMISE(promise, check_dialog_access(dialog_id, true, AccessRights::Read, "report_dialog"));

  MessagesManager::ReportDialogFromActionBar report_from_action_bar;
  if (option_id.empty() && message_ids.empty() && text.empty()) {
    // can be a report from action bar
    report_from_action_bar = td_->messages_manager_->report_dialog_from_action_bar(dialog_id, promise);
    if (report_from_action_bar.is_reported_) {
      return;
    }
  }

  if (!can_report_dialog(dialog_id)) {
    if (report_from_action_bar.know_action_bar_) {
      return promise.set_value(td_api::make_object<td_api::reportChatResultOk>());
    }

    return promise.set_error(Status::Error(400, "Chat can't be reported"));
  }

  for (auto message_id : message_ids) {
    TRY_STATUS_PROMISE(promise, MessagesManager::can_report_message(message_id));
  }

  td_->create_handler<ReportPeerQuery>(std::move(promise))->send(dialog_id, option_id, message_ids, text);
}

void DialogManager::report_dialog_photo(DialogId dialog_id, FileId file_id, ReportReason &&reason,
                                        Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, check_dialog_access(dialog_id, false, AccessRights::Read, "report_dialog_photo"));

  if (!can_report_dialog(dialog_id)) {
    return promise.set_error(Status::Error(400, "Chat photo can't be reported"));
  }

  auto file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.empty()) {
    return promise.set_error(Status::Error(400, "Unknown file identifier"));
  }
  if (get_main_file_type(file_view.get_type()) != FileType::Photo) {
    return promise.set_error(Status::Error(400, "Only full chat photos can be reported"));
  }
  const auto *full_remote_location = file_view.get_full_remote_location();
  if (full_remote_location == nullptr || !full_remote_location->is_photo()) {
    return promise.set_error(Status::Error(400, "Invalid photo identifier specified"));
  }

  td_->create_handler<ReportProfilePhotoQuery>(std::move(promise))
      ->send(dialog_id, file_id, full_remote_location->as_input_photo(), std::move(reason));
}

Status DialogManager::can_pin_messages(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      break;
    case DialogType::Chat: {
      auto chat_id = dialog_id.get_chat_id();
      auto status = td_->chat_manager_->get_chat_permissions(chat_id);
      if (!status.can_pin_messages() ||
          (td_->auth_manager_->is_bot() && !td_->chat_manager_->is_appointed_chat_administrator(chat_id))) {
        return Status::Error(400, "Not enough rights to manage pinned messages in the chat");
      }
      break;
    }
    case DialogType::Channel: {
      auto status = td_->chat_manager_->get_channel_permissions(dialog_id.get_channel_id());
      bool can_pin = is_broadcast_channel(dialog_id) ? status.can_edit_messages() : status.can_pin_messages();
      if (!can_pin) {
        return Status::Error(400, "Not enough rights to manage pinned messages in the chat");
      }
      break;
    }
    case DialogType::SecretChat:
      return Status::Error(400, "Secret chats can't have pinned messages");
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  if (!have_input_peer(dialog_id, false, AccessRights::Write)) {
    return Status::Error(400, "Not enough rights");
  }

  return Status::OK();
}

bool DialogManager::can_use_premium_custom_emoji_in_dialog(DialogId dialog_id) const {
  if (td_->auth_manager_->is_bot()) {
    return true;
  }
  if (dialog_id == get_my_dialog_id() || td_->option_manager_->get_option_boolean("is_premium")) {
    return true;
  }
  if (dialog_id.get_type() == DialogType::Channel &&
      td_->chat_manager_->can_use_premium_custom_emoji_in_channel(dialog_id.get_channel_id())) {
    return true;
  }
  return false;
}

bool DialogManager::is_dialog_removed_from_dialog_list(DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      break;
    case DialogType::Chat:
      return !td_->chat_manager_->get_chat_is_active(dialog_id.get_chat_id());
    case DialogType::Channel:
      return !td_->chat_manager_->get_channel_status(dialog_id.get_channel_id()).is_member();
    case DialogType::SecretChat:
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
      break;
  }
  return false;
}

void DialogManager::on_update_dialog_bot_commands(
    DialogId dialog_id, UserId bot_user_id, vector<telegram_api::object_ptr<telegram_api::botCommand>> &&bot_commands) {
  if (!bot_user_id.is_valid()) {
    LOG(ERROR) << "Receive updateBotCommands about invalid " << bot_user_id;
    return;
  }
  if (!td_->user_manager_->have_user_force(bot_user_id, "on_update_dialog_bot_commands") ||
      !td_->user_manager_->is_user_bot(bot_user_id)) {
    return;
  }
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  switch (dialog_id.get_type()) {
    case DialogType::User:
      if (DialogId(bot_user_id) != dialog_id) {
        LOG(ERROR) << "Receive commands of " << bot_user_id << " in " << dialog_id;
        return;
      }
      return td_->user_manager_->on_update_user_commands(bot_user_id, std::move(bot_commands));
    case DialogType::Chat:
      return td_->chat_manager_->on_update_chat_bot_commands(dialog_id.get_chat_id(),
                                                             BotCommands(bot_user_id, std::move(bot_commands)));
    case DialogType::Channel:
      return td_->chat_manager_->on_update_channel_bot_commands(dialog_id.get_channel_id(),
                                                                BotCommands(bot_user_id, std::move(bot_commands)));
    case DialogType::SecretChat:
    default:
      LOG(ERROR) << "Receive updateBotCommands in " << dialog_id;
      break;
  }
}

void DialogManager::on_dialog_usernames_updated(DialogId dialog_id, const Usernames &old_usernames,
                                                const Usernames &new_usernames) {
  LOG(INFO) << "Update usernames in " << dialog_id << " from " << old_usernames << " to " << new_usernames;

  for (auto &username : old_usernames.get_active_usernames()) {
    auto cleaned_username = clean_username(username);
    resolved_usernames_.erase(cleaned_username);
    inaccessible_resolved_usernames_.erase(cleaned_username);
  }

  on_dialog_usernames_received(dialog_id, new_usernames, false);
}

void DialogManager::on_dialog_usernames_received(DialogId dialog_id, const Usernames &usernames, bool from_database) {
  for (auto &username : usernames.get_active_usernames()) {
    auto cleaned_username = clean_username(username);
    if (!cleaned_username.empty()) {
      resolved_usernames_[cleaned_username] =
          ResolvedUsername{dialog_id, Time::now() + (from_database ? 0 : USERNAME_CACHE_EXPIRE_TIME)};
    }
  }
}

void DialogManager::check_dialog_username(DialogId dialog_id, const string &username,
                                          Promise<CheckDialogUsernameResult> &&promise) {
  if (dialog_id != DialogId() && dialog_id.get_type() != DialogType::User &&
      !have_dialog_force(dialog_id, "check_dialog_username")) {
    return promise.set_error(Status::Error(400, "Chat not found"));
  }

  switch (dialog_id.get_type()) {
    case DialogType::User: {
      if (dialog_id != get_my_dialog_id()) {
        return promise.set_error(Status::Error(400, "Can't check username for private chat with other user"));
      }
      break;
    }
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      if (!td_->chat_manager_->get_channel_status(channel_id).is_creator()) {
        return promise.set_error(Status::Error(400, "Not enough rights to change username"));
      }
      if (username == td_->chat_manager_->get_channel_editable_username(channel_id)) {
        return promise.set_value(CheckDialogUsernameResult::Ok);
      }
      break;
    }
    case DialogType::None:
      break;
    case DialogType::Chat:
    case DialogType::SecretChat:
      if (!username.empty()) {
        return promise.set_error(Status::Error(400, "The chat can't have a username"));
      }
      break;
    default:
      UNREACHABLE();
      return;
  }

  if (username.empty()) {
    return promise.set_value(CheckDialogUsernameResult::Ok);
  }

  if (!is_allowed_username(username) && username.size() != 4) {
    return promise.set_value(CheckDialogUsernameResult::Invalid);
  }

  auto request_promise = PromiseCreator::lambda([promise = std::move(promise)](Result<bool> result) mutable {
    if (result.is_error()) {
      auto error = result.move_as_error();
      if (error.message() == "CHANNEL_PUBLIC_GROUP_NA") {
        return promise.set_value(CheckDialogUsernameResult::PublicGroupsUnavailable);
      }
      if (error.message() == "CHANNELS_ADMIN_PUBLIC_TOO_MUCH") {
        return promise.set_value(CheckDialogUsernameResult::PublicDialogsTooMany);
      }
      if (error.message() == "USERNAME_INVALID") {
        return promise.set_value(CheckDialogUsernameResult::Invalid);
      }
      if (error.message() == "USERNAME_PURCHASE_AVAILABLE") {
        if (begins_with(G()->get_option_string("my_phone_number"), "1")) {
          return promise.set_value(CheckDialogUsernameResult::Invalid);
        }
        return promise.set_value(CheckDialogUsernameResult::Purchasable);
      }
      return promise.set_error(std::move(error));
    }

    promise.set_value(result.ok() ? CheckDialogUsernameResult::Ok : CheckDialogUsernameResult::Occupied);
  });

  switch (dialog_id.get_type()) {
    case DialogType::User:
      return td_->create_handler<CheckUsernameQuery>(std::move(request_promise))->send(username);
    case DialogType::Channel:
      return td_->create_handler<CheckChannelUsernameQuery>(std::move(request_promise))
          ->send(dialog_id.get_channel_id(), username);
    case DialogType::None:
      return td_->create_handler<CheckChannelUsernameQuery>(std::move(request_promise))->send(ChannelId(), username);
    case DialogType::Chat:
    case DialogType::SecretChat:
    default:
      UNREACHABLE();
  }
}

td_api::object_ptr<td_api::CheckChatUsernameResult> DialogManager::get_check_chat_username_result_object(
    CheckDialogUsernameResult result) {
  switch (result) {
    case CheckDialogUsernameResult::Ok:
      return td_api::make_object<td_api::checkChatUsernameResultOk>();
    case CheckDialogUsernameResult::Invalid:
      return td_api::make_object<td_api::checkChatUsernameResultUsernameInvalid>();
    case CheckDialogUsernameResult::Occupied:
      return td_api::make_object<td_api::checkChatUsernameResultUsernameOccupied>();
    case CheckDialogUsernameResult::Purchasable:
      return td_api::make_object<td_api::checkChatUsernameResultUsernamePurchasable>();
    case CheckDialogUsernameResult::PublicDialogsTooMany:
      return td_api::make_object<td_api::checkChatUsernameResultPublicChatsTooMany>();
    case CheckDialogUsernameResult::PublicGroupsUnavailable:
      return td_api::make_object<td_api::checkChatUsernameResultPublicGroupsUnavailable>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void DialogManager::send_resolve_dialog_username_query(const string &username, Promise<Unit> &&promise) {
  CHECK(!username.empty());
  auto &queries = resolve_dialog_username_queries_[username];
  queries.push_back(std::move(promise));
  if (queries.size() != 1u) {
    return;
  }
  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), username](Result<DialogId> r_dialog_id) {
    send_closure(actor_id, &DialogManager::on_resolved_username, username, std::move(r_dialog_id));
  });
  td_->create_handler<ResolveUsernameQuery>(std::move(query_promise))->send(username);
}

void DialogManager::on_resolved_username(const string &username, Result<DialogId> r_dialog_id) {
  G()->ignore_result_if_closing(r_dialog_id);
  auto it = resolve_dialog_username_queries_.find(username);
  CHECK(it != resolve_dialog_username_queries_.end());
  auto promises = std::move(it->second);
  CHECK(!promises.empty());
  resolve_dialog_username_queries_.erase(it);
  if (r_dialog_id.is_error()) {
    auto error_message = r_dialog_id.error().message();
    if (error_message == Slice("USERNAME_NOT_OCCUPIED") || error_message == Slice("USERNAME_INVALID")) {
      drop_username(username);
    }
    return fail_promises(promises, r_dialog_id.move_as_error());
  }

  auto dialog_id = r_dialog_id.ok();
  if (!dialog_id.is_valid()) {
    LOG(ERROR) << "Resolve username \"" << username << "\" to invalid " << dialog_id;
    return fail_promises(promises, Status::Error(500, "Chat not found"));
  }

  auto cleaned_username = clean_username(username);
  if (cleaned_username.empty()) {
    return fail_promises(promises, Status::Error(500, "Invalid username"));
  }

  auto resolved_username = resolved_usernames_.get(cleaned_username);
  if (resolved_username.dialog_id.is_valid()) {
    LOG_IF(ERROR, resolved_username.dialog_id != dialog_id)
        << "Resolve username \"" << username << "\" to " << dialog_id << ", but have it in "
        << resolved_username.dialog_id;
    return set_promises(promises);
  }

  inaccessible_resolved_usernames_[cleaned_username] = dialog_id;
  set_promises(promises);
}

void DialogManager::resolve_dialog(const string &username, ChannelId channel_id, Promise<DialogId> promise) {
  CHECK(username.empty() == channel_id.is_valid());

  bool have_dialog = username.empty() ? td_->chat_manager_->have_channel_force(channel_id, "resolve_dialog")
                                      : get_resolved_dialog_by_username(username).is_valid();
  if (!have_dialog) {
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this), username, channel_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            return promise.set_error(result.move_as_error());
          }
          send_closure(actor_id, &DialogManager::on_resolve_dialog, username, channel_id, std::move(promise));
        });
    if (username.empty()) {
      td_->chat_manager_->reload_channel(channel_id, std::move(query_promise), "resolve_dialog");
    } else {
      send_resolve_dialog_username_query(username, std::move(query_promise));
    }
    return;
  }

  return on_resolve_dialog(username, channel_id, std::move(promise));
}

void DialogManager::on_resolve_dialog(const string &username, ChannelId channel_id, Promise<DialogId> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  DialogId dialog_id;
  if (username.empty()) {
    if (!td_->chat_manager_->have_channel(channel_id)) {
      return promise.set_error(Status::Error(500, "Chat info not found"));
    }

    dialog_id = DialogId(channel_id);
    force_create_dialog(dialog_id, "on_resolve_dialog");
  } else {
    dialog_id = get_resolved_dialog_by_username(username);
    if (dialog_id.is_valid()) {
      force_create_dialog(dialog_id, "on_resolve_dialog", true);
    }
  }
  if (!have_dialog_force(dialog_id, "on_resolve_dialog")) {
    return promise.set_error(Status::Error(500, "Chat not found"));
  }
  promise.set_value(std::move(dialog_id));
}

DialogId DialogManager::get_resolved_dialog_by_username(const string &username) const {
  auto cleaned_username = clean_username(username);
  auto resolved_username = resolved_usernames_.get(cleaned_username);
  if (resolved_username.dialog_id.is_valid()) {
    return resolved_username.dialog_id;
  }

  return inaccessible_resolved_usernames_.get(cleaned_username);
}

DialogId DialogManager::resolve_dialog_username(const string &username, Promise<Unit> &promise) {
  auto resolved_username = resolved_usernames_.get(username);
  if (resolved_username.dialog_id.is_valid()) {
    if (resolved_username.expires_at < Time::now()) {
      send_resolve_dialog_username_query(username, Promise<Unit>());
    }
    return resolved_username.dialog_id;
  } else {
    auto dialog_id = inaccessible_resolved_usernames_.get(username);
    if (!dialog_id.is_valid()) {
      send_resolve_dialog_username_query(username, std::move(promise));
    }
    return dialog_id;
  }
}

DialogId DialogManager::search_public_dialog(const string &username_to_search, bool force, Promise<Unit> &&promise) {
  string username = clean_username(username_to_search);
  if (username[0] == '@') {
    username = username.substr(1);
  }
  if (username.empty()) {
    promise.set_error(Status::Error(200, "Username is invalid"));
    return DialogId();
  }

  auto dialog_id = resolve_dialog_username(username, promise);
  if (!dialog_id.is_valid()) {
    return DialogId();
  }

  if (have_input_peer(dialog_id, false, AccessRights::Read)) {
    if (!force && reload_voice_chat_on_search_usernames_.count(username)) {
      reload_voice_chat_on_search_usernames_.erase(username);
      if (dialog_id.get_type() == DialogType::Channel) {
        td_->chat_manager_->reload_channel_full(dialog_id.get_channel_id(), std::move(promise), "search_public_dialog");
        return DialogId();
      }
    }

    td_->messages_manager_->create_dialog(dialog_id, force, std::move(promise));
    return dialog_id;
  }

  if (force || dialog_id.get_type() != DialogType::User) {  // bot username may be known despite there is no access_hash
    force_create_dialog(dialog_id, "search_public_dialog", true);
    promise.set_value(Unit());
    return dialog_id;
  }

  send_resolve_dialog_username_query(username, std::move(promise));
  return DialogId();
}

void DialogManager::reload_voice_chat_on_search(const string &username) {
  if (!td_->auth_manager_->is_authorized()) {
    return;
  }

  auto cleaned_username = clean_username(username);
  if (!cleaned_username.empty()) {
    reload_voice_chat_on_search_usernames_.insert(cleaned_username);
  }
}

void DialogManager::drop_username(const string &username) {
  auto cleaned_username = clean_username(username);
  if (cleaned_username.empty()) {
    return;
  }

  inaccessible_resolved_usernames_.erase(cleaned_username);

  auto resolved_username = resolved_usernames_.get(cleaned_username);
  if (resolved_username.dialog_id.is_valid()) {
    auto dialog_id = resolved_username.dialog_id;
    if (have_input_peer(dialog_id, false, AccessRights::Read)) {
      reload_dialog_info_full(dialog_id, "drop_username");
    }

    resolved_usernames_.erase(cleaned_username);
  }
}

vector<DialogId> DialogManager::search_public_dialogs(const string &query, Promise<Unit> &&promise) {
  LOG(INFO) << "Search public chats with query = \"" << query << '"';

  auto query_length = utf8_length(query);
  if (query_length < MIN_SEARCH_PUBLIC_DIALOG_PREFIX_LEN ||
      (query_length == MIN_SEARCH_PUBLIC_DIALOG_PREFIX_LEN && query[0] == '@')) {
    string username = clean_username(query);
    if (username[0] == '@') {
      username = username.substr(1);
    }

    for (auto &short_username : get_valid_short_usernames()) {
      if (2 * username.size() > short_username.size() && begins_with(short_username, username)) {
        username = short_username.str();
        auto dialog_id = resolve_dialog_username(username, promise);
        if (!dialog_id.is_valid()) {
          return {};
        }

        force_create_dialog(dialog_id, "search_public_dialogs");

        if (td_->messages_manager_->can_add_dialog_to_filter(dialog_id).is_error() ||
            (dialog_id.get_type() == DialogType::User &&
             td_->user_manager_->is_user_contact(dialog_id.get_user_id()))) {
          continue;
        }

        promise.set_value(Unit());
        return {dialog_id};
      }
    }
    promise.set_value(Unit());
    return {};
  }

  auto it = found_public_dialogs_.find(query);
  if (it != found_public_dialogs_.end()) {
    promise.set_value(Unit());
    return it->second;
  }

  send_search_public_dialogs_query(query, std::move(promise));
  return {};
}

vector<DialogId> DialogManager::search_dialogs_on_server(const string &query, int32 limit, Promise<Unit> &&promise) {
  LOG(INFO) << "Search chats on server with query \"" << query << "\" and limit " << limit;

  if (limit < 0) {
    promise.set_error(Status::Error(400, "Limit must be non-negative"));
    return {};
  }
  if (limit > MAX_GET_DIALOGS) {
    limit = MAX_GET_DIALOGS;
  }

  if (query.empty()) {
    promise.set_value(Unit());
    return {};
  }

  auto it = found_on_server_dialogs_.find(query);
  if (it != found_on_server_dialogs_.end()) {
    promise.set_value(Unit());
    return td_->messages_manager_->sort_dialogs_by_order(it->second, limit);
  }

  send_search_public_dialogs_query(query, std::move(promise));
  return {};
}

void DialogManager::send_search_public_dialogs_query(const string &query, Promise<Unit> &&promise) {
  CHECK(!query.empty());
  auto &promises = search_public_dialogs_queries_[query];
  promises.push_back(std::move(promise));
  if (promises.size() != 1) {
    // query has already been sent, just wait for the result
    return;
  }

  td_->create_handler<SearchPublicDialogsQuery>()->send(query);
}

void DialogManager::on_get_public_dialogs_search_result(const string &query,
                                                        vector<tl_object_ptr<telegram_api::Peer>> &&my_peers,
                                                        vector<tl_object_ptr<telegram_api::Peer>> &&peers) {
  auto it = search_public_dialogs_queries_.find(query);
  CHECK(it != search_public_dialogs_queries_.end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  search_public_dialogs_queries_.erase(it);

  CHECK(!query.empty());
  found_public_dialogs_[query] = get_peers_dialog_ids(std::move(peers));
  found_on_server_dialogs_[query] = get_peers_dialog_ids(std::move(my_peers));

  set_promises(promises);
}

void DialogManager::on_failed_public_dialogs_search(const string &query, Status &&error) {
  auto it = search_public_dialogs_queries_.find(query);
  CHECK(it != search_public_dialogs_queries_.end());
  CHECK(!it->second.empty());
  auto promises = std::move(it->second);
  search_public_dialogs_queries_.erase(it);

  found_public_dialogs_[query];     // negative cache
  found_on_server_dialogs_[query];  // negative cache

  fail_promises(promises, std::move(error));
}

void DialogManager::reget_peer_settings(DialogId dialog_id) {
  if (!have_input_peer(dialog_id, false, AccessRights::Read)) {
    return;
  }

  td_->create_handler<GetPeerSettingsQuery>()->send(dialog_id);
}

class DialogManager::ReorderPinnedDialogsOnServerLogEvent {
 public:
  FolderId folder_id_;
  vector<DialogId> dialog_ids_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(folder_id_, storer);
    td::store(dialog_ids_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    if (parser.version() >= static_cast<int32>(Version::AddFolders)) {
      td::parse(folder_id_, parser);
    } else {
      folder_id_ = FolderId();
    }
    td::parse(dialog_ids_, parser);
  }
};

uint64 DialogManager::save_reorder_pinned_dialogs_on_server_log_event(FolderId folder_id,
                                                                      const vector<DialogId> &dialog_ids) {
  ReorderPinnedDialogsOnServerLogEvent log_event{folder_id, dialog_ids};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ReorderPinnedDialogsOnServer,
                    get_log_event_storer(log_event));
}

void DialogManager::reorder_pinned_dialogs_on_server(FolderId folder_id, const vector<DialogId> &dialog_ids,
                                                     uint64 log_event_id) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_reorder_pinned_dialogs_on_server_log_event(folder_id, dialog_ids);
  }

  td_->create_handler<ReorderPinnedDialogsQuery>(get_erase_log_event_promise(log_event_id))
      ->send(folder_id, dialog_ids);
}

class DialogManager::ToggleDialogReportSpamStateOnServerLogEvent {
 public:
  DialogId dialog_id_;
  bool is_spam_dialog_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
    td::store(is_spam_dialog_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
    td::parse(is_spam_dialog_, parser);
  }
};

uint64 DialogManager::save_toggle_dialog_report_spam_state_on_server_log_event(DialogId dialog_id,
                                                                               bool is_spam_dialog) {
  ToggleDialogReportSpamStateOnServerLogEvent log_event{dialog_id, is_spam_dialog};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ToggleDialogReportSpamStateOnServer,
                    get_log_event_storer(log_event));
}

void DialogManager::toggle_dialog_report_spam_state_on_server(DialogId dialog_id, bool is_spam_dialog,
                                                              uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_toggle_dialog_report_spam_state_on_server_log_event(dialog_id, is_spam_dialog);
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::Channel:
      return td_->create_handler<UpdatePeerSettingsQuery>(std::move(promise))->send(dialog_id, is_spam_dialog);
    case DialogType::SecretChat:
      if (is_spam_dialog) {
        return td_->create_handler<ReportEncryptedSpamQuery>(std::move(promise))->send(dialog_id);
      } else {
        auto user_id = td_->user_manager_->get_secret_chat_user_id(dialog_id.get_secret_chat_id());
        if (!user_id.is_valid()) {
          return promise.set_error(Status::Error(400, "Peer user not found"));
        }
        return td_->create_handler<UpdatePeerSettingsQuery>(std::move(promise))->send(DialogId(user_id), false);
      }
    case DialogType::None:
    default:
      UNREACHABLE();
      return;
  }
}

void DialogManager::get_blocked_dialogs(const td_api::object_ptr<td_api::BlockList> &block_list, int32 offset,
                                        int32 limit, Promise<td_api::object_ptr<td_api::messageSenders>> &&promise) {
  if (offset < 0) {
    return promise.set_error(Status::Error(400, "Parameter offset must be non-negative"));
  }

  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }

  auto block_list_id = BlockListId(block_list);
  if (!block_list_id.is_valid()) {
    return promise.set_error(Status::Error(400, "Block list must be non-empty"));
  }

  td_->create_handler<GetBlockedDialogsQuery>(std::move(promise))->send(block_list_id, offset, limit);
}

void DialogManager::on_get_blocked_dialogs(int32 offset, int32 limit, int32 total_count,
                                           vector<telegram_api::object_ptr<telegram_api::peerBlocked>> &&blocked_peers,
                                           Promise<td_api::object_ptr<td_api::messageSenders>> &&promise) {
  LOG(INFO) << "Receive " << blocked_peers.size() << " blocked chats from offset " << offset << " out of "
            << total_count;
  auto peers =
      transform(std::move(blocked_peers), [](telegram_api::object_ptr<telegram_api::peerBlocked> &&blocked_peer) {
        return std::move(blocked_peer->peer_id_);
      });
  auto dialog_ids = get_message_sender_dialog_ids(td_, std::move(peers));
  if (!dialog_ids.empty() && offset + dialog_ids.size() > static_cast<size_t>(total_count)) {
    LOG(ERROR) << "Fix total count of blocked chats from " << total_count << " to " << offset + dialog_ids.size();
    total_count = offset + narrow_cast<int32>(dialog_ids.size());
  }

  auto senders = transform(dialog_ids, [td = td_](DialogId dialog_id) {
    return get_message_sender_object(td, dialog_id, "on_get_blocked_dialogs");
  });
  promise.set_value(td_api::make_object<td_api::messageSenders>(total_count, std::move(senders)));
}

void DialogManager::set_dialog_available_reactions_on_server(DialogId dialog_id,
                                                             const ChatReactions &available_reactions,
                                                             Promise<Unit> &&promise) {
  td_->create_handler<SetChatAvailableReactionsQuery>(std::move(promise))
      ->send(dialog_id, std::move(available_reactions));
}

void DialogManager::set_dialog_default_send_as_on_server(DialogId dialog_id, DialogId send_as_dialog_id,
                                                         Promise<Unit> &&promise) {
  td_->create_handler<SaveDefaultSendAsQuery>(std::move(promise))->send(dialog_id, send_as_dialog_id);
}

void DialogManager::set_dialog_folder_id_on_server(DialogId dialog_id, FolderId folder_id, Promise<Unit> &&promise) {
  // TODO do not send two queries simultaneously or use InvokeAfter
  td_->create_handler<EditPeerFoldersQuery>(std::move(promise))->send(dialog_id, folder_id);
}

void DialogManager::set_dialog_message_ttl_on_server(DialogId dialog_id, int32 ttl, Promise<Unit> &&promise) {
  td_->create_handler<SetHistoryTtlQuery>(std::move(promise))->send(dialog_id, ttl);
}

void DialogManager::set_dialog_theme_on_server(DialogId dialog_id, const string &theme_name, Promise<Unit> &&promise) {
  td_->create_handler<SetChatThemeQuery>(std::move(promise))->send(dialog_id, theme_name);
}

class DialogManager::ToggleDialogIsBlockedOnServerLogEvent {
 public:
  DialogId dialog_id_;
  bool is_blocked_;
  bool is_blocked_for_stories_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(is_blocked_);
    STORE_FLAG(is_blocked_for_stories_);
    END_STORE_FLAGS();

    td::store(dialog_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(is_blocked_);
    PARSE_FLAG(is_blocked_for_stories_);
    END_PARSE_FLAGS();

    td::parse(dialog_id_, parser);
  }
};

uint64 DialogManager::save_toggle_dialog_is_blocked_on_server_log_event(DialogId dialog_id, bool is_blocked,
                                                                        bool is_blocked_for_stories) {
  ToggleDialogIsBlockedOnServerLogEvent log_event{dialog_id, is_blocked, is_blocked_for_stories};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ToggleDialogIsBlockedOnServer,
                    get_log_event_storer(log_event));
}

void DialogManager::toggle_dialog_is_blocked_on_server(DialogId dialog_id, bool is_blocked, bool is_blocked_for_stories,
                                                       uint64 log_event_id) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_toggle_dialog_is_blocked_on_server_log_event(dialog_id, is_blocked, is_blocked_for_stories);
  }

  td_->create_handler<ToggleDialogIsBlockedQuery>(get_erase_log_event_promise(log_event_id))
      ->send(dialog_id, is_blocked, is_blocked_for_stories);
}

class DialogManager::ToggleDialogPropertyOnServerLogEvent {
 public:
  DialogId dialog_id_;
  bool value_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(value_);
    END_STORE_FLAGS();

    td::store(dialog_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(value_);
    END_PARSE_FLAGS();

    td::parse(dialog_id_, parser);
  }
};

uint64 DialogManager::save_toggle_dialog_is_marked_as_unread_on_server_log_event(DialogId dialog_id,
                                                                                 bool is_marked_as_unread) {
  ToggleDialogPropertyOnServerLogEvent log_event{dialog_id, is_marked_as_unread};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ToggleDialogIsMarkedAsUnreadOnServer,
                    get_log_event_storer(log_event));
}

void DialogManager::toggle_dialog_is_marked_as_unread_on_server(DialogId dialog_id, bool is_marked_as_unread,
                                                                uint64 log_event_id) {
  if (log_event_id == 0 && dialog_id.get_type() == DialogType::SecretChat) {
    // don't even create new binlog events
    return;
  }

  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_toggle_dialog_is_marked_as_unread_on_server_log_event(dialog_id, is_marked_as_unread);
  }

  td_->create_handler<ToggleDialogUnreadMarkQuery>(get_erase_log_event_promise(log_event_id))
      ->send(dialog_id, is_marked_as_unread);
}

uint64 DialogManager::save_toggle_dialog_is_pinned_on_server_log_event(DialogId dialog_id, bool is_pinned) {
  ToggleDialogPropertyOnServerLogEvent log_event{dialog_id, is_pinned};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ToggleDialogIsPinnedOnServer,
                    get_log_event_storer(log_event));
}

void DialogManager::toggle_dialog_is_pinned_on_server(DialogId dialog_id, bool is_pinned, uint64 log_event_id) {
  CHECK(!td_->auth_manager_->is_bot());
  if (log_event_id == 0 && dialog_id.get_type() == DialogType::SecretChat) {
    // don't even create new binlog events
    return;
  }

  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_toggle_dialog_is_pinned_on_server_log_event(dialog_id, is_pinned);
  }

  td_->create_handler<ToggleDialogPinQuery>(get_erase_log_event_promise(log_event_id))->send(dialog_id, is_pinned);
}

uint64 DialogManager::save_toggle_dialog_is_translatable_on_server_log_event(DialogId dialog_id, bool is_translatable) {
  ToggleDialogPropertyOnServerLogEvent log_event{dialog_id, is_translatable};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ToggleDialogIsTranslatableOnServer,
                    get_log_event_storer(log_event));
}

void DialogManager::toggle_dialog_is_translatable_on_server(DialogId dialog_id, bool is_translatable,
                                                            uint64 log_event_id) {
  if (log_event_id == 0 && dialog_id.get_type() == DialogType::SecretChat) {
    // don't even create new binlog events
    return;
  }

  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_toggle_dialog_is_translatable_on_server_log_event(dialog_id, is_translatable);
  }

  td_->create_handler<ToggleDialogTranslationsQuery>(get_erase_log_event_promise(log_event_id))
      ->send(dialog_id, is_translatable);
}

uint64 DialogManager::save_toggle_dialog_view_as_messages_on_server_log_event(DialogId dialog_id,
                                                                              bool view_as_messages) {
  ToggleDialogPropertyOnServerLogEvent log_event{dialog_id, view_as_messages};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ToggleDialogViewAsMessagesOnServer,
                    get_log_event_storer(log_event));
}

void DialogManager::toggle_dialog_view_as_messages_on_server(DialogId dialog_id, bool view_as_messages,
                                                             uint64 log_event_id) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_toggle_dialog_view_as_messages_on_server_log_event(dialog_id, view_as_messages);
  }

  td_->create_handler<ToggleViewForumAsMessagesQuery>(get_erase_log_event_promise(log_event_id))
      ->send(dialog_id, view_as_messages);
}

void DialogManager::on_binlog_events(vector<BinlogEvent> &&events) {
  if (G()->close_flag()) {
    return;
  }
  bool have_old_message_database = G()->use_message_database() && !G()->td_db()->was_dialog_db_created();
  for (auto &event : events) {
    CHECK(event.id_ != 0);
    switch (event.type_) {
      case LogEvent::HandlerType::ReorderPinnedDialogsOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ReorderPinnedDialogsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        vector<DialogId> dialog_ids;
        for (auto &dialog_id : log_event.dialog_ids_) {
          if (have_dialog_force(dialog_id, "ReorderPinnedDialogsOnServerLogEvent") &&
              have_input_peer(dialog_id, true, AccessRights::Read)) {
            dialog_ids.push_back(dialog_id);
          }
        }
        if (dialog_ids.empty()) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        reorder_pinned_dialogs_on_server(log_event.folder_id_, dialog_ids, event.id_);
        break;
      }
      case LogEvent::HandlerType::ToggleDialogIsBlockedOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ToggleDialogIsBlockedOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (dialog_id.get_type() == DialogType::SecretChat ||
            !have_dialog_info_force(dialog_id, "ToggleDialogIsBlockedOnServer") ||
            !have_input_peer(dialog_id, true, AccessRights::Know)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        toggle_dialog_is_blocked_on_server(dialog_id, log_event.is_blocked_, log_event.is_blocked_for_stories_,
                                           event.id_);
        break;
      }
      case LogEvent::HandlerType::ToggleDialogIsMarkedAsUnreadOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ToggleDialogPropertyOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!have_dialog_force(dialog_id, "ToggleDialogIsMarkedAsUnreadOnServer") ||
            !have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        toggle_dialog_is_marked_as_unread_on_server(dialog_id, log_event.value_, event.id_);
        break;
      }
      case LogEvent::HandlerType::ToggleDialogIsPinnedOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ToggleDialogPropertyOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!have_dialog_force(dialog_id, "ToggleDialogIsPinnedOnServer") ||
            !have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        toggle_dialog_is_pinned_on_server(dialog_id, log_event.value_, event.id_);
        break;
      }
      case LogEvent::HandlerType::ToggleDialogIsTranslatableOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ToggleDialogPropertyOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!have_dialog_force(dialog_id, "ToggleDialogIsTranslatableOnServer") ||
            !have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        toggle_dialog_is_translatable_on_server(dialog_id, log_event.value_, event.id_);
        break;
      }
      case LogEvent::HandlerType::ToggleDialogReportSpamStateOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ToggleDialogReportSpamStateOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!have_dialog_force(dialog_id, "ToggleDialogReportSpamStateOnServer") ||
            !have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        toggle_dialog_report_spam_state_on_server(dialog_id, log_event.is_spam_dialog_, event.id_, Promise<Unit>());
        break;
      }
      case LogEvent::HandlerType::ToggleDialogViewAsMessagesOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ToggleDialogPropertyOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!have_dialog_force(dialog_id, "ToggleDialogViewAsMessagesOnServer") ||
            !have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        toggle_dialog_view_as_messages_on_server(dialog_id, log_event.value_, event.id_);
        break;
      }
      default:
        LOG(FATAL) << "Unsupported log event type " << event.type_;
    }
  }
}

}  // namespace td
