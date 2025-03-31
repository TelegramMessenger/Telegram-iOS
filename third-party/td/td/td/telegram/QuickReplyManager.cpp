//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/QuickReplyManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/InlineQueriesManager.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessageContent.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageCopyOptions.h"
#include "td/telegram/MessageInputReplyTo.h"
#include "td/telegram/MessageQueryManager.h"
#include "td/telegram/MessageQuote.h"
#include "td/telegram/MessageReplyHeader.h"
#include "td/telegram/MessageSelfDestructType.h"
#include "td/telegram/misc.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/ReplyMarkup.h"
#include "td/telegram/ReplyMarkup.hpp"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Version.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/format.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/unicode.h"
#include "td/utils/utf8.h"

#include <algorithm>
#include <limits>
#include <unordered_map>

namespace td {

class GetQuickRepliesQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_QuickReplies>> promise_;

 public:
  explicit GetQuickRepliesQuery(Promise<telegram_api::object_ptr<telegram_api::messages_QuickReplies>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int64 hash) {
    send_query(G()->net_query_creator().create(telegram_api::messages_getQuickReplies(hash), {{"quick_reply"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getQuickReplies>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetQuickRepliesQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class EditQuickReplyShortcutQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit EditQuickReplyShortcutQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(QuickReplyShortcutId shortcut_id, const string &name) {
    send_query(G()->net_query_creator().create(telegram_api::messages_editQuickReplyShortcut(shortcut_id.get(), name),
                                               {{"quick_reply"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editQuickReplyShortcut>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteQuickReplyShortcutQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit DeleteQuickReplyShortcutQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(QuickReplyShortcutId shortcut_id) {
    send_query(G()->net_query_creator().create(telegram_api::messages_deleteQuickReplyShortcut(shortcut_id.get()),
                                               {{"quick_reply"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteQuickReplyShortcut>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->quick_reply_manager_->reload_quick_reply_shortcuts();
    promise_.set_error(std::move(status));
  }
};

class ReorderQuickRepliesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ReorderQuickRepliesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<QuickReplyShortcutId> shortcut_ids) {
    send_query(
        G()->net_query_creator().create(telegram_api::messages_reorderQuickReplies(
                                            QuickReplyShortcutId::get_input_quick_reply_shortcut_ids(shortcut_ids)),
                                        {{"quick_reply"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reorderQuickReplies>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->quick_reply_manager_->reload_quick_reply_shortcuts();
    promise_.set_error(std::move(status));
  }
};

class GetQuickReplyMessagesQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::messages_Messages>> promise_;

 public:
  explicit GetQuickReplyMessagesQuery(Promise<telegram_api::object_ptr<telegram_api::messages_Messages>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(QuickReplyShortcutId shortcut_id, const vector<MessageId> &message_ids, int64 hash) {
    int32 flags = 0;
    if (!message_ids.empty()) {
      flags |= telegram_api::messages_getQuickReplyMessages::ID_MASK;
    }
    CHECK(shortcut_id.is_server());
    send_query(G()->net_query_creator().create(
        telegram_api::messages_getQuickReplyMessages(flags, shortcut_id.get(),
                                                     MessageId::get_server_message_ids(message_ids), hash),
        {{"quick_reply"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getQuickReplyMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(DEBUG) << "Receive result for GetQuickReplyMessagesQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteQuickReplyMessagesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  QuickReplyShortcutId shortcut_id_;

 public:
  explicit DeleteQuickReplyMessagesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(QuickReplyShortcutId shortcut_id, const vector<MessageId> &message_ids) {
    shortcut_id_ = shortcut_id;
    CHECK(shortcut_id.is_server());
    send_query(G()->net_query_creator().create(telegram_api::messages_deleteQuickReplyMessages(
                                                   shortcut_id.get(), MessageId::get_server_message_ids(message_ids)),
                                               {{"quick_reply"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteQuickReplyMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    td_->quick_reply_manager_->reload_quick_reply_messages(shortcut_id_, Promise<Unit>());
    promise_.set_error(std::move(status));
  }
};

class QuickReplyManager::SendQuickReplyMessageQuery final : public Td::ResultHandler {
  int64 random_id_;
  QuickReplyShortcutId shortcut_id_;

 public:
  void send(const QuickReplyMessage *m) {
    random_id_ = m->random_id;
    shortcut_id_ = m->shortcut_id;

    int32 flags = telegram_api::messages_sendMessage::QUICK_REPLY_SHORTCUT_MASK;
    if (m->disable_web_page_preview) {
      flags |= telegram_api::messages_sendMessage::NO_WEBPAGE_MASK;
    }
    if (m->invert_media) {
      flags |= telegram_api::messages_sendMessage::INVERT_MEDIA_MASK;
    }
    auto reply_to =
        MessageInputReplyTo(m->reply_to_message_id, DialogId(), MessageQuote()).get_input_reply_to(td_, MessageId());
    if (reply_to != nullptr) {
      flags |= telegram_api::messages_sendMessage::REPLY_TO_MASK;
    }
    CHECK(m->edited_content == nullptr);
    const FormattedText *message_text = get_message_content_text(m->content.get());
    CHECK(message_text != nullptr);
    auto entities = get_input_message_entities(td_->user_manager_.get(), message_text, "SendQuickReplyMessageQuery");
    if (!entities.empty()) {
      flags |= telegram_api::messages_sendMessage::ENTITIES_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_sendMessage(
            flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
            false /*ignored*/, false /*ignored*/, false /*ignored*/,
            telegram_api::make_object<telegram_api::inputPeerSelf>(), std::move(reply_to), message_text->text,
            m->random_id, nullptr, std::move(entities), 0, nullptr,
            td_->quick_reply_manager_->get_input_quick_reply_shortcut(m->shortcut_id), 0, 0),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_sendMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendQuickReplyMessageQuery for " << random_id_ << ": " << to_string(ptr);
    td_->quick_reply_manager_->process_send_quick_reply_updates(shortcut_id_, FileUploadId(), std::move(ptr),
                                                                {random_id_});
  }

  void on_error(Status status) final {
    if (G()->close_flag()) {
      // do not send error, message will be re-sent after restart
      return;
    }
    LOG(INFO) << "Receive error for SendQuickReplyMessageQuery: " << status;
    td_->quick_reply_manager_->on_failed_send_quick_reply_messages(shortcut_id_, {random_id_}, std::move(status));
  }
};

class QuickReplyManager::SendQuickReplyInlineMessageQuery final : public Td::ResultHandler {
  int64 random_id_;
  QuickReplyShortcutId shortcut_id_;

 public:
  void send(const QuickReplyMessage *m) {
    random_id_ = m->random_id;
    shortcut_id_ = m->shortcut_id;

    int32 flags = telegram_api::messages_sendInlineBotResult::QUICK_REPLY_SHORTCUT_MASK;
    if (m->hide_via_bot) {
      flags |= telegram_api::messages_sendInlineBotResult::HIDE_VIA_MASK;
    }
    auto reply_to =
        MessageInputReplyTo(m->reply_to_message_id, DialogId(), MessageQuote()).get_input_reply_to(td_, MessageId());
    if (reply_to != nullptr) {
      flags |= telegram_api::messages_sendInlineBotResult::REPLY_TO_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_sendInlineBotResult(
            flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
            telegram_api::make_object<telegram_api::inputPeerSelf>(), std::move(reply_to), m->random_id,
            m->inline_query_id, m->inline_result_id, 0, nullptr,
            td_->quick_reply_manager_->get_input_quick_reply_shortcut(m->shortcut_id), 0),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_sendInlineBotResult>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendQuickReplyInlineMessageQuery for " << random_id_ << ": " << to_string(ptr);
    td_->quick_reply_manager_->process_send_quick_reply_updates(shortcut_id_, FileUploadId(), std::move(ptr),
                                                                {random_id_});
  }

  void on_error(Status status) final {
    if (G()->close_flag()) {
      // do not send error, message will be re-sent after restart
      return;
    }
    LOG(INFO) << "Receive error for SendQuickReplyInlineMessageQuery: " << status;
    td_->quick_reply_manager_->on_failed_send_quick_reply_messages(shortcut_id_, {random_id_}, std::move(status));
  }
};

class QuickReplyManager::SendQuickReplyMediaQuery final : public Td::ResultHandler {
  int64 random_id_;
  QuickReplyShortcutId shortcut_id_;
  FileUploadId file_upload_id_;
  FileUploadId thumbnail_file_upload_id_;
  FileId cover_file_id_;
  string file_reference_;
  string cover_file_reference_;
  bool was_uploaded_ = false;
  bool was_thumbnail_uploaded_ = false;

 public:
  void send(const QuickReplyMessage *m, telegram_api::object_ptr<telegram_api::InputMedia> &&input_media) {
    random_id_ = m->random_id;
    shortcut_id_ = m->shortcut_id;
    file_upload_id_ = m->file_upload_id;
    thumbnail_file_upload_id_ = m->thumbnail_file_upload_id;
    cover_file_id_ = get_message_content_cover_any_file_id(m->content.get());
    file_reference_ = FileManager::extract_file_reference(input_media);
    cover_file_reference_ = FileManager::extract_cover_file_reference(input_media);
    was_uploaded_ = FileManager::extract_was_uploaded(input_media);
    was_thumbnail_uploaded_ = FileManager::extract_was_thumbnail_uploaded(input_media);

    int32 flags = telegram_api::messages_sendMedia::QUICK_REPLY_SHORTCUT_MASK;
    if (m->invert_media) {
      flags |= telegram_api::messages_sendMedia::INVERT_MEDIA_MASK;
    }
    auto reply_to =
        MessageInputReplyTo(m->reply_to_message_id, DialogId(), MessageQuote()).get_input_reply_to(td_, MessageId());
    if (reply_to != nullptr) {
      flags |= telegram_api::messages_sendMedia::REPLY_TO_MASK;
    }
    CHECK(m->edited_content == nullptr);
    vector<telegram_api::object_ptr<telegram_api::MessageEntity>> entities;
    const FormattedText *message_text = get_message_content_text(m->content.get());
    if (message_text != nullptr) {
      entities = get_input_message_entities(td_->user_manager_.get(), message_text, "SendQuickReplyMediaQuery");
      if (!entities.empty()) {
        flags |= telegram_api::messages_sendMedia::ENTITIES_MASK;
      }
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_sendMedia(
            flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
            false /*ignored*/, false /*ignored*/, telegram_api::make_object<telegram_api::inputPeerSelf>(),
            std::move(reply_to), std::move(input_media), message_text == nullptr ? string() : message_text->text,
            m->random_id, nullptr, std::move(entities), 0, nullptr,
            td_->quick_reply_manager_->get_input_quick_reply_shortcut(m->shortcut_id), 0, 0),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_sendMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (was_thumbnail_uploaded_) {
      CHECK(thumbnail_file_upload_id_.is_valid());
      // always delete partial remote location for the thumbnail, because it can't be reused anyway
      td_->file_manager_->delete_partial_remote_location(thumbnail_file_upload_id_);
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendQuickReplyMediaQuery for " << random_id_ << ": " << to_string(ptr);
    td_->quick_reply_manager_->process_send_quick_reply_updates(
        shortcut_id_, was_uploaded_ ? file_upload_id_ : FileUploadId(), std::move(ptr), {random_id_});
  }

  void on_error(Status status) final {
    if (G()->close_flag()) {
      // do not send error, message will be re-sent after restart
      return;
    }
    LOG(INFO) << "Receive error for SendQuickReplyMediaQuery: " << status;
    if (FileReferenceManager::is_file_reference_error(status)) {
      auto source = FileReferenceManager::get_file_reference_error_source(status);
      if (source.is_cover_) {
        if (cover_file_id_.is_valid() && source.pos_ <= 1) {
          VLOG(file_references) << "Receive " << status << " for cover " << cover_file_id_;
          td_->file_manager_->delete_file_reference(cover_file_id_, cover_file_reference_);
          td_->quick_reply_manager_->on_send_message_file_error(shortcut_id_, random_id_, {-1});
          return;
        } else {
          LOG(ERROR) << "Receive file reference error, but cover_file_id = " << cover_file_id_;
        }
      } else {
        if (file_upload_id_.is_valid() && !was_uploaded_) {
          VLOG(file_references) << "Receive " << status << " for " << file_upload_id_;
          td_->file_manager_->delete_file_reference(file_upload_id_.get_file_id(), file_reference_);
          td_->quick_reply_manager_->on_send_message_file_error(shortcut_id_, random_id_, {-1});
          return;
        } else {
          LOG(ERROR) << "Receive file reference error, but file_id = " << file_upload_id_
                     << ", was_uploaded = " << was_uploaded_;
        }
      }
    }
    if (was_uploaded_) {
      if (was_thumbnail_uploaded_) {
        CHECK(thumbnail_file_upload_id_.is_valid());
        // always delete partial remote location for the thumbnail, because it can't be reused anyway
        td_->file_manager_->delete_partial_remote_location(thumbnail_file_upload_id_);
      }

      CHECK(file_upload_id_.is_valid());
      auto bad_parts = FileManager::get_missing_file_parts(status);
      if (!bad_parts.empty()) {
        td_->quick_reply_manager_->on_send_message_file_error(shortcut_id_, random_id_, std::move(bad_parts));
        return;
      } else {
        td_->file_manager_->delete_partial_remote_location_if_needed(file_upload_id_, status);
      }
    }

    td_->quick_reply_manager_->on_failed_send_quick_reply_messages(shortcut_id_, {random_id_}, std::move(status));
  }
};

class QuickReplyManager::UploadQuickReplyMediaQuery final : public Td::ResultHandler {
  int64 random_id_;
  QuickReplyShortcutId shortcut_id_;
  MessageId message_id_;
  FileUploadId file_upload_id_;
  FileUploadId thumbnail_file_upload_id_;
  FileId cover_file_id_;
  string file_reference_;
  string cover_file_reference_;
  bool was_uploaded_ = false;
  bool was_thumbnail_uploaded_ = false;

 public:
  void send(const QuickReplyMessage *m, telegram_api::object_ptr<telegram_api::InputMedia> &&input_media) {
    random_id_ = m->random_id;
    shortcut_id_ = m->shortcut_id;
    message_id_ = m->message_id;
    file_upload_id_ = m->file_upload_id;
    thumbnail_file_upload_id_ = m->thumbnail_file_upload_id;
    cover_file_id_ = get_message_content_cover_any_file_id(m->content.get());
    file_reference_ = FileManager::extract_file_reference(input_media);
    cover_file_reference_ = FileManager::extract_cover_file_reference(input_media);
    was_uploaded_ = FileManager::extract_was_uploaded(input_media);
    was_thumbnail_uploaded_ = FileManager::extract_was_thumbnail_uploaded(input_media);

    int32 flags = 0;
    send_query(G()->net_query_creator().create(telegram_api::messages_uploadMedia(
        flags, string(), telegram_api::make_object<telegram_api::inputPeerSelf>(), std::move(input_media))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_uploadMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (was_thumbnail_uploaded_) {
      CHECK(thumbnail_file_upload_id_.is_valid());
      // always delete partial remote location for the thumbnail, because it can't be reused anyway
      td_->file_manager_->delete_partial_remote_location(thumbnail_file_upload_id_);
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for UploadQuickReplyMediaQuery: " << to_string(ptr);
    td_->quick_reply_manager_->on_upload_message_media_success(shortcut_id_, message_id_, file_upload_id_,
                                                               std::move(ptr));
  }

  void on_error(Status status) final {
    if (G()->close_flag()) {
      // do not send error, message will be re-sent after restart
      return;
    }
    LOG(INFO) << "Receive error for UploadQuickReplyMediaQuery: " << status;
    if (FileReferenceManager::is_file_reference_error(status)) {
      auto source = FileReferenceManager::get_file_reference_error_source(status);
      if (source.is_cover_ && source.pos_ <= 1 && cover_file_id_.is_valid()) {
        VLOG(file_references) << "Receive " << status << " for cover " << cover_file_id_;
        td_->file_manager_->delete_file_reference(cover_file_id_, cover_file_reference_);
        td_->quick_reply_manager_->on_send_message_file_error(shortcut_id_, random_id_, {-1});
        return;
      } else {
        LOG(ERROR) << "Receive file reference error for UploadMediaQuery";
      }
    }
    if (was_uploaded_) {
      if (was_thumbnail_uploaded_) {
        CHECK(thumbnail_file_upload_id_.is_valid());
        // always delete partial remote location for the thumbnail, because it can't be reused anyway
        td_->file_manager_->delete_partial_remote_location(thumbnail_file_upload_id_);
      }

      CHECK(file_upload_id_.is_valid());
      auto bad_parts = FileManager::get_missing_file_parts(status);
      if (!bad_parts.empty()) {
        td_->quick_reply_manager_->on_send_message_file_error(shortcut_id_, random_id_, std::move(bad_parts));
        return;
      } else {
        td_->file_manager_->delete_partial_remote_location_if_needed(file_upload_id_, status);
      }
    }

    td_->quick_reply_manager_->on_upload_message_media_fail(shortcut_id_, message_id_, std::move(status));
  }
};

class QuickReplyManager::SendQuickReplyMultiMediaQuery final : public Td::ResultHandler {
  vector<FileId> file_ids_;
  vector<FileId> cover_file_ids_;
  vector<string> file_references_;
  vector<string> cover_file_references_;
  vector<int64> random_ids_;
  QuickReplyShortcutId shortcut_id_;

 public:
  void send(QuickReplyShortcutId shortcut_id, MessageId reply_to_message_id, bool invert_media,
            vector<int64> &&random_ids, vector<FileId> &&file_ids, vector<FileId> &&cover_file_ids,
            vector<tl_object_ptr<telegram_api::inputSingleMedia>> &&input_single_media) {
    for (auto &single_media : input_single_media) {
      CHECK(!FileManager::extract_was_uploaded(single_media->media_));
      file_references_.push_back(FileManager::extract_file_reference(single_media->media_));
      cover_file_references_.push_back(FileManager::extract_cover_file_reference(single_media->media_));
    }
    shortcut_id_ = shortcut_id;
    file_ids_ = std::move(file_ids);
    cover_file_ids_ = std::move(cover_file_ids);
    random_ids_ = std::move(random_ids);
    CHECK(file_ids_.size() == random_ids_.size());

    int32 flags = telegram_api::messages_sendMultiMedia::QUICK_REPLY_SHORTCUT_MASK;
    auto reply_to =
        MessageInputReplyTo(reply_to_message_id, DialogId(), MessageQuote()).get_input_reply_to(td_, MessageId());
    if (reply_to != nullptr) {
      flags |= telegram_api::messages_sendMultiMedia::REPLY_TO_MASK;
    }
    if (invert_media) {
      flags |= telegram_api::messages_sendMultiMedia::INVERT_MEDIA_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_sendMultiMedia(
            flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
            false /*ignored*/, false /*ignored*/, telegram_api::make_object<telegram_api::inputPeerSelf>(),
            std::move(reply_to), std::move(input_single_media), 0, nullptr,
            td_->quick_reply_manager_->get_input_quick_reply_shortcut(shortcut_id_), 0, 0),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_sendMultiMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for SendMultiMedia for " << random_ids_ << ": " << to_string(ptr);
    td_->quick_reply_manager_->process_send_quick_reply_updates(shortcut_id_, FileUploadId(), std::move(ptr),
                                                                std::move(random_ids_));
  }

  void on_error(Status status) final {
    if (G()->close_flag()) {
      // do not send error, message will be re-sent after restart
      return;
    }
    LOG(INFO) << "Receive error for SendQuickReplyMultiMediaQuery: " << status;
    if (FileReferenceManager::is_file_reference_error(status)) {
      auto source = FileReferenceManager::get_file_reference_error_source(status);
      auto pos = source.pos_;
      if (source.is_cover_) {
        if (1 <= pos && pos <= cover_file_ids_.size() && cover_file_ids_[pos - 1].is_valid()) {
          VLOG(file_references) << "Receive " << status << " for cover " << cover_file_ids_[pos - 1];
          td_->file_manager_->delete_file_reference(cover_file_ids_[pos - 1], cover_file_references_[pos - 1]);
          td_->quick_reply_manager_->on_send_media_group_file_reference_error(shortcut_id_, std::move(random_ids_));
          return;
        } else {
          LOG(ERROR) << "Receive file reference error " << status << ", but cover_file_ids = " << cover_file_ids_
                     << ", message_count = " << cover_file_ids_.size();
        }
      } else {
        if (1 <= pos && pos <= file_ids_.size() && file_ids_[pos - 1].is_valid()) {
          VLOG(file_references) << "Receive " << status << " for " << file_ids_[pos - 1];
          td_->file_manager_->delete_file_reference(file_ids_[pos - 1], file_references_[pos - 1]);
          td_->quick_reply_manager_->on_send_media_group_file_reference_error(shortcut_id_, std::move(random_ids_));
          return;
        } else {
          LOG(ERROR) << "Receive file reference error " << status << ", but file_ids = " << file_ids_
                     << ", message_count = " << file_ids_.size();
        }
      }
    }
    td_->quick_reply_manager_->on_failed_send_quick_reply_messages(shortcut_id_, std::move(random_ids_),
                                                                   std::move(status));
  }
};

class QuickReplyManager::EditQuickReplyMessageQuery final : public Td::ResultHandler {
  QuickReplyShortcutId shortcut_id_;
  MessageId message_id_;
  int64 edit_generation_ = 0;
  FileUploadId file_upload_id_;
  FileUploadId thumbnail_file_upload_id_;
  FileId cover_file_id_;
  string file_reference_;
  string cover_file_reference_;
  bool was_uploaded_ = false;
  bool was_thumbnail_uploaded_ = false;

 public:
  void send(const QuickReplyMessage *m, telegram_api::object_ptr<telegram_api::InputMedia> &&input_media) {
    CHECK(m != nullptr);
    CHECK(m->edited_content != nullptr);
    CHECK(m->edit_generation > 0);
    shortcut_id_ = m->shortcut_id;
    message_id_ = m->message_id;
    edit_generation_ = m->edit_generation;
    file_upload_id_ = m->edited_file_upload_id;
    thumbnail_file_upload_id_ = m->edited_thumbnail_file_upload_id;
    cover_file_id_ = get_message_content_cover_any_file_id(m->edited_content.get());
    file_reference_ = FileManager::extract_file_reference(input_media);
    cover_file_reference_ = FileManager::extract_cover_file_reference(input_media);
    was_uploaded_ = FileManager::extract_was_uploaded(input_media);
    was_thumbnail_uploaded_ = FileManager::extract_was_thumbnail_uploaded(input_media);

    auto *content = m->edited_content.get();
    const auto *text = get_message_content_text(content);
    vector<telegram_api::object_ptr<telegram_api::MessageEntity>> entities;
    int32 flags = telegram_api::messages_editMessage::QUICK_REPLY_SHORTCUT_ID_MASK;
    if (text != nullptr) {
      entities = get_input_message_entities(td_->user_manager_.get(), text, "EditQuickReplyMessageQuery");
      if (!entities.empty()) {
        flags |= telegram_api::messages_editMessage::ENTITIES_MASK;
      }
      flags |= telegram_api::messages_editMessage::MESSAGE_MASK;
    }
    if (m->edited_invert_media) {
      flags |= telegram_api::messages_editMessage::INVERT_MEDIA_MASK;
    }
    if (m->edited_disable_web_page_preview) {
      flags |= telegram_api::messages_editMessage::NO_WEBPAGE_MASK;
    }
    if (input_media != nullptr) {
      flags |= telegram_api::messages_editMessage::MEDIA_MASK;
    }

    CHECK(m->shortcut_id.is_server());
    send_query(G()->net_query_creator().create(
        telegram_api::messages_editMessage(
            flags, false /*ignored*/, false /*ignored*/, telegram_api::make_object<telegram_api::inputPeerSelf>(),
            m->message_id.get_server_message_id().get(), text != nullptr ? text->text : string(),
            std::move(input_media), nullptr, std::move(entities), 0, m->shortcut_id.get()),
        {{"me"}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_editMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    if (was_thumbnail_uploaded_) {
      CHECK(thumbnail_file_upload_id_.is_valid());
      // always delete partial remote location for the thumbnail, because it can't be reused anyway
      td_->file_manager_->delete_partial_remote_location(thumbnail_file_upload_id_);
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditQuickReplyMessageQuery: " << to_string(ptr);
    td_->quick_reply_manager_->on_edit_quick_reply_message(shortcut_id_, message_id_, edit_generation_, file_upload_id_,
                                                           was_uploaded_, std::move(ptr));
  }

  void on_error(Status status) final {
    if (G()->close_flag()) {
      // do not send error, message will be re-edited after restart
      return;
    }
    if (status.message() == "MESSAGE_NOT_MODIFIED") {
      if (was_thumbnail_uploaded_) {
        CHECK(thumbnail_file_upload_id_.is_valid());
        // always delete partial remote location for the thumbnail, because it can't be reused anyway
        td_->file_manager_->delete_partial_remote_location(thumbnail_file_upload_id_);
      }

      return td_->quick_reply_manager_->on_edit_quick_reply_message(shortcut_id_, message_id_, edit_generation_,
                                                                    file_upload_id_, was_uploaded_, nullptr);
    }
    // checks for file reference and upload errors
    td_->quick_reply_manager_->fail_edit_quick_reply_message(
        shortcut_id_, message_id_, edit_generation_, file_upload_id_, thumbnail_file_upload_id_, cover_file_id_,
        file_reference_, cover_file_reference_, was_uploaded_, was_thumbnail_uploaded_, std::move(status));
  }
};

class QuickReplyManager::UploadMediaCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->quick_reply_manager(), &QuickReplyManager::on_upload_media, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->quick_reply_manager(), &QuickReplyManager::on_upload_media_error, file_upload_id,
                       std::move(error));
  }
};

class QuickReplyManager::UploadThumbnailCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->quick_reply_manager(), &QuickReplyManager::on_upload_thumbnail, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->quick_reply_manager(), &QuickReplyManager::on_upload_thumbnail, file_upload_id, nullptr);
  }
};

QuickReplyManager::QuickReplyMessage::~QuickReplyMessage() = default;

template <class StorerT>
void QuickReplyManager::QuickReplyMessage::store(StorerT &storer) const {
  bool is_server = message_id.is_server();
  bool has_edit_date = edit_date != 0;
  bool has_random_id = !is_server && random_id != 0;
  bool has_reply_to_message_id = reply_to_message_id != MessageId();
  bool has_send_emoji = !is_server && !send_emoji.empty();
  bool has_via_bot_user_id = via_bot_user_id != UserId();
  bool has_legacy_layer = legacy_layer != 0;
  bool has_send_error_code = !is_server && send_error_code != 0;
  bool has_send_error_message = !is_server && !send_error_message.empty();
  bool has_try_resend_at = !is_server && try_resend_at != 0;
  bool has_media_album_id = media_album_id != 0;
  bool has_reply_markup = reply_markup != nullptr;
  bool has_inline_query_id = inline_query_id != 0;
  bool has_inline_result_id = !inline_result_id.empty();
  bool has_edited_content = edited_content != nullptr;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_edit_date);
  STORE_FLAG(has_random_id);
  STORE_FLAG(has_reply_to_message_id);
  STORE_FLAG(has_send_emoji);
  STORE_FLAG(has_via_bot_user_id);
  STORE_FLAG(is_failed_to_send);
  STORE_FLAG(disable_notification);
  STORE_FLAG(invert_media);
  STORE_FLAG(from_background);
  STORE_FLAG(disable_web_page_preview);
  STORE_FLAG(hide_via_bot);
  STORE_FLAG(has_legacy_layer);
  STORE_FLAG(has_send_error_code);
  STORE_FLAG(has_send_error_message);
  STORE_FLAG(has_try_resend_at);
  STORE_FLAG(has_media_album_id);
  STORE_FLAG(has_reply_markup);
  STORE_FLAG(has_inline_query_id);
  STORE_FLAG(has_inline_result_id);
  STORE_FLAG(has_edited_content);
  STORE_FLAG(edited_invert_media);
  STORE_FLAG(edited_disable_web_page_preview);
  END_STORE_FLAGS();
  td::store(message_id, storer);
  td::store(shortcut_id, storer);
  if (has_edit_date) {
    td::store(edit_date, storer);
  }
  if (has_random_id) {
    td::store(random_id, storer);
  }
  if (has_reply_to_message_id) {
    td::store(reply_to_message_id, storer);
  }
  if (has_send_emoji) {
    td::store(send_emoji, storer);
  }
  if (has_via_bot_user_id) {
    td::store(via_bot_user_id, storer);
  }
  if (has_legacy_layer) {
    td::store(legacy_layer, storer);
  }
  if (has_send_error_code) {
    td::store(send_error_code, storer);
  }
  if (has_send_error_message) {
    td::store(send_error_message, storer);
  }
  if (has_try_resend_at) {
    td::store_time(try_resend_at, storer);
  }
  if (has_media_album_id) {
    td::store(media_album_id, storer);
  }
  store_message_content(content.get(), storer);
  if (has_reply_markup) {
    td::store(reply_markup, storer);
  }
  if (has_inline_query_id) {
    td::store(inline_query_id, storer);
  }
  if (has_inline_result_id) {
    td::store(inline_result_id, storer);
  }
  if (has_edited_content) {
    store_message_content(edited_content.get(), storer);
  }
}

template <class ParserT>
void QuickReplyManager::QuickReplyMessage::parse(ParserT &parser) {
  bool has_edit_date;
  bool has_random_id;
  bool has_reply_to_message_id;
  bool has_send_emoji;
  bool has_via_bot_user_id;
  bool has_legacy_layer;
  bool has_send_error_code;
  bool has_send_error_message;
  bool has_try_resend_at;
  bool has_media_album_id;
  bool has_reply_markup;
  bool has_inline_query_id;
  bool has_inline_result_id;
  bool has_edited_content;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_edit_date);
  PARSE_FLAG(has_random_id);
  PARSE_FLAG(has_reply_to_message_id);
  PARSE_FLAG(has_send_emoji);
  PARSE_FLAG(has_via_bot_user_id);
  PARSE_FLAG(is_failed_to_send);
  PARSE_FLAG(disable_notification);
  PARSE_FLAG(invert_media);
  PARSE_FLAG(from_background);
  PARSE_FLAG(disable_web_page_preview);
  PARSE_FLAG(hide_via_bot);
  PARSE_FLAG(has_legacy_layer);
  PARSE_FLAG(has_send_error_code);
  PARSE_FLAG(has_send_error_message);
  PARSE_FLAG(has_try_resend_at);
  PARSE_FLAG(has_media_album_id);
  PARSE_FLAG(has_reply_markup);
  PARSE_FLAG(has_inline_query_id);
  PARSE_FLAG(has_inline_result_id);
  PARSE_FLAG(has_edited_content);
  PARSE_FLAG(edited_invert_media);
  PARSE_FLAG(edited_disable_web_page_preview);
  END_PARSE_FLAGS();
  td::parse(message_id, parser);
  td::parse(shortcut_id, parser);
  if (has_edit_date) {
    td::parse(edit_date, parser);
  }
  if (has_random_id) {
    td::parse(random_id, parser);
  }
  if (has_reply_to_message_id) {
    td::parse(reply_to_message_id, parser);
  }
  if (has_send_emoji) {
    td::parse(send_emoji, parser);
  }
  if (has_via_bot_user_id) {
    td::parse(via_bot_user_id, parser);
  }
  if (has_legacy_layer) {
    td::parse(legacy_layer, parser);
  }
  if (has_send_error_code) {
    td::parse(send_error_code, parser);
  }
  if (has_send_error_message) {
    td::parse(send_error_message, parser);
  }
  if (has_try_resend_at) {
    td::parse_time(try_resend_at, parser);
  }
  if (has_media_album_id) {
    td::parse(media_album_id, parser);
  }
  parse_message_content(content, parser);
  if (has_reply_markup) {
    td::parse(reply_markup, parser);
  }
  if (has_inline_query_id) {
    td::parse(inline_query_id, parser);
  }
  if (has_inline_result_id) {
    td::parse(inline_result_id, parser);
  }
  if (has_edited_content) {
    parse_message_content(edited_content, parser);
  }
}

QuickReplyManager::Shortcut::~Shortcut() = default;

template <class StorerT>
void QuickReplyManager::Shortcut::store(StorerT &storer) const {
  int32 server_total_count = 0;
  int32 local_total_count = 0;
  for (const auto &message : messages_) {
    if (message->message_id.is_server()) {
      server_total_count++;
    } else {
      local_total_count++;
    }
  }
  CHECK(server_total_count <= server_total_count_);
  CHECK(local_total_count <= local_total_count_);

  bool has_server_total_count = server_total_count != 0;
  bool has_local_total_count = local_total_count != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_server_total_count);
  STORE_FLAG(has_local_total_count);
  END_STORE_FLAGS();
  td::store(name_, storer);
  td::store(shortcut_id_, storer);
  if (has_server_total_count) {
    td::store(server_total_count, storer);
  }
  if (has_local_total_count) {
    td::store(local_total_count, storer);
  }
  for (const auto &message : messages_) {
    td::store(message, storer);
  }
}

template <class ParserT>
void QuickReplyManager::Shortcut::parse(ParserT &parser) {
  bool has_server_total_count;
  bool has_local_total_count;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_server_total_count);
  PARSE_FLAG(has_local_total_count);
  END_PARSE_FLAGS();
  td::parse(name_, parser);
  td::parse(shortcut_id_, parser);
  if (has_server_total_count) {
    td::parse(server_total_count_, parser);
  }
  if (has_local_total_count) {
    td::parse(local_total_count_, parser);
  }
  if (server_total_count_ < 0 || local_total_count_ < 0) {
    return parser.set_error("Wrong message count");
  }
  auto size = static_cast<size_t>(server_total_count_) + static_cast<size_t>(local_total_count_);
  if (parser.get_left_len() < size) {
    return parser.set_error("Wrong message count");
  }
  messages_ = vector<unique_ptr<QuickReplyMessage>>(size);
  for (auto &message : messages_) {
    td::parse(message, parser);
  }
}

template <class StorerT>
void QuickReplyManager::Shortcuts::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  END_STORE_FLAGS();
  td::store(shortcuts_, storer);
}

template <class ParserT>
void QuickReplyManager::Shortcuts::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  END_PARSE_FLAGS();
  td::parse(shortcuts_, parser);
}

QuickReplyManager::QuickReplyManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_media_callback_ = std::make_shared<UploadMediaCallback>();
  upload_thumbnail_callback_ = std::make_shared<UploadThumbnailCallback>();
}

void QuickReplyManager::tear_down() {
  parent_.reset();
}

bool QuickReplyManager::is_shortcut_name_letter(uint32 code) {
  auto category = get_unicode_simple_category(code);
  if (code == '_' || code == 0x200c || code == 0xb7 || (0xd80 <= code && code <= 0xdff)) {
    return true;
  }
  switch (category) {
    case UnicodeSimpleCategory::DecimalNumber:
    case UnicodeSimpleCategory::Letter:
      return true;
    default:
      return false;
  }
}

Status QuickReplyManager::check_shortcut_name(CSlice name) {
  if (!check_utf8(name)) {
    return Status::Error("Strings must be encoded in UTF-8");
  }
  int32 length = 0;
  auto *ptr = name.ubegin();
  while (ptr != name.uend()) {
    uint32 code;
    ptr = next_utf8_unsafe(ptr, &code);
    if (!is_shortcut_name_letter(code)) {
      return Status::Error("A letter is not allowed");
    }
    length++;
  }
  if (length == 0) {
    return Status::Error("Name must be non-empty");
  }
  if (length > 32) {
    return Status::Error("Name is too long");
  }
  return Status::OK();
}

unique_ptr<QuickReplyManager::QuickReplyMessage> QuickReplyManager::create_message(
    telegram_api::object_ptr<telegram_api::Message> message_ptr, const char *source) const {
  LOG(DEBUG) << "Receive from " << source << " " << to_string(message_ptr);
  CHECK(message_ptr != nullptr);

  switch (message_ptr->get_id()) {
    case telegram_api::messageEmpty::ID:
      break;
    case telegram_api::message::ID: {
      auto message_id = MessageId::get_message_id(message_ptr, false);
      auto message = move_tl_object_as<telegram_api::message>(message_ptr);
      auto shortcut_id = QuickReplyShortcutId(message->quick_reply_shortcut_id_);
      if (!shortcut_id.is_server()) {
        LOG(ERROR) << "Receive invalid quick reply " << shortcut_id << " from " << source;
        break;
      }
      if (!message_id.is_valid() || !message_id.is_server()) {
        LOG(ERROR) << "Receive invalid " << message_id << " in quick reply " << shortcut_id << " from " << source;
        break;
      }
      if (deleted_message_full_ids_.count({shortcut_id, message_id})) {
        // a previously deleted message
        break;
      }

      auto my_dialog_id = td_->dialog_manager_->get_my_dialog_id();
      if (DialogId(message->peer_id_) != my_dialog_id || message->from_id_ != nullptr ||
          message->fwd_from_ != nullptr || message->views_ != 0 || message->forwards_ != 0 ||
          message->replies_ != nullptr || message->reactions_ != nullptr || message->ttl_period_ != 0 ||
          !message->out_ || message->post_ || message->from_scheduled_ || message->pinned_ || message->noforwards_ ||
          message->mentioned_ || !message->restriction_reason_.empty() || !message->post_author_.empty() ||
          message->from_boosts_applied_ != 0 || message->effect_ != 0) {
        LOG(ERROR) << "Receive an invalid quick reply from " << source << ": " << to_string(message);
      }
      if (message->saved_peer_id_ != nullptr) {
        LOG(DEBUG) << "Receive unneeded Saved Messages topic in quick reply " << message_id << " from " << source;
      }

      UserId via_bot_user_id = UserId(message->via_bot_id_);
      if (via_bot_user_id != UserId() && !via_bot_user_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << via_bot_user_id << " from " << source;
        via_bot_user_id = UserId();
      }
      auto media_album_id = message->grouped_id_;

      MessageSelfDestructType ttl;
      bool disable_web_page_preview = false;
      auto content = get_message_content(
          td_,
          get_message_text(td_->user_manager_.get(), std::move(message->message_), std::move(message->entities_), true,
                           td_->auth_manager_->is_bot(), 0, media_album_id != 0, source),
          std::move(message->media_), my_dialog_id, message->date_, true, via_bot_user_id, &ttl,
          &disable_web_page_preview, source);

      auto reply_header = MessageReplyHeader(td_, std::move(message->reply_to_), my_dialog_id, message_id, -1, false);
      if (reply_header.story_full_id_ != StoryFullId()) {
        LOG(ERROR) << "Receive reply to " << reply_header.story_full_id_;
        reply_header.story_full_id_ = {};
      }
      if (reply_header.replied_message_info_.is_external() ||
          reply_header.replied_message_info_.get_reply_message_full_id(DialogId(), true).get_dialog_id() !=
              DialogId()) {
        LOG(ERROR) << "Receive reply to " << reply_header.replied_message_info_;
        reply_header.replied_message_info_ = {};
      }
      auto reply_to_message_id = reply_header.replied_message_info_.get_same_chat_reply_to_message_id(true);

      if (!ttl.is_empty()) {
        LOG(ERROR) << "Wrong " << ttl << " received in " << message_id << " from " << source;
        break;
      }

      auto content_type = content->get_type();
      if (is_service_message_content(content_type) || content_type == MessageContentType::LiveLocation ||
          is_expired_message_content(content_type) || content_type == MessageContentType::Poll ||
          content_type == MessageContentType::PaidMedia) {
        LOG(ERROR) << "Receive " << content_type << " from " << source;
        break;
      }

      auto result = make_unique<QuickReplyMessage>();
      result->shortcut_id = shortcut_id;
      result->message_id = message_id;
      result->edit_date = max(message->edit_date_, 0);
      result->disable_web_page_preview = disable_web_page_preview;
      result->reply_to_message_id = reply_to_message_id;
      result->via_bot_user_id = via_bot_user_id;
      result->disable_notification = message->silent_;
      result->legacy_layer = (message->legacy_ ? MTPROTO_LAYER : 0);
      result->invert_media = message->invert_media_;
      result->content = std::move(content);
      result->reply_markup =
          get_reply_markup(std::move(message->reply_markup_), td_->auth_manager_->is_bot(), true, false);

      if (media_album_id != 0) {
        if (!is_allowed_media_group_content(content_type)) {
          if (content_type != MessageContentType::Unsupported) {
            LOG(ERROR) << "Receive media group identifier " << media_album_id << " in " << message_id
                       << " with content "
                       << oneline(to_string(get_quick_reply_message_message_content_object(result.get())));
          }
        } else {
          result->media_album_id = media_album_id;
        }
      }

      Dependencies dependencies;
      add_quick_reply_message_dependencies(dependencies, result.get());
      for (auto dependent_dialog_id : dependencies.get_dialog_ids()) {
        td_->dialog_manager_->force_create_dialog(dependent_dialog_id, source, true);
      }

      return result;
    }
    case telegram_api::messageService::ID:
      LOG(ERROR) << "Receive " << to_string(message_ptr);
      break;
    default:
      UNREACHABLE();
      break;
  }
  return nullptr;
}

void QuickReplyManager::add_quick_reply_message_dependencies(Dependencies &dependencies,
                                                             const QuickReplyMessage *m) const {
  auto is_bot = td_->auth_manager_->is_bot();
  dependencies.add(m->via_bot_user_id);
  add_message_content_dependencies(dependencies, m->content.get(), is_bot);
  if (m->edited_content != nullptr) {
    add_message_content_dependencies(dependencies, m->edited_content.get(), is_bot);
  }
  add_reply_markup_dependencies(dependencies, m->reply_markup.get());
}

bool QuickReplyManager::can_edit_quick_reply_message(const QuickReplyMessage *m) const {
  return m->message_id.is_server() && !m->via_bot_user_id.is_valid() &&
         is_editable_message_content(m->content->get_type()) && m->content->get_type() != MessageContentType::Game;
}

bool QuickReplyManager::can_resend_quick_reply_message(const QuickReplyMessage *m) const {
  if (m->send_error_code != 429) {
    return false;
  }
  return true;
}

td_api::object_ptr<td_api::MessageSendingState> QuickReplyManager::get_message_sending_state_object(
    const QuickReplyMessage *m) const {
  CHECK(m != nullptr);
  if (m->message_id.is_yet_unsent()) {
    return td_api::make_object<td_api::messageSendingStatePending>(0);
  }
  if (m->is_failed_to_send) {
    auto can_retry = can_resend_quick_reply_message(m);
    auto error_code = m->send_error_code > 0 ? m->send_error_code : 400;
    auto need_another_reply_quote =
        can_retry && error_code == 400 && m->send_error_message == CSlice("QUOTE_TEXT_INVALID");
    return td_api::make_object<td_api::messageSendingStateFailed>(
        td_api::make_object<td_api::error>(error_code, m->send_error_message), can_retry, false,
        need_another_reply_quote, false, 0, max(m->try_resend_at - Time::now(), 0.0));
  }
  return nullptr;
}

td_api::object_ptr<td_api::MessageContent> QuickReplyManager::get_quick_reply_message_message_content_object(
    const QuickReplyMessage *m) const {
  if (m->edited_content != nullptr) {
    return get_message_content_object(m->edited_content.get(), td_, DialogId(), MessageId(), false, 0, false, true, -1,
                                      m->edited_invert_media, m->edited_disable_web_page_preview);
  }
  return get_message_content_object(m->content.get(), td_, DialogId(), m->message_id, false, 0, false, true, -1,
                                    m->invert_media, m->disable_web_page_preview);
}

td_api::object_ptr<td_api::quickReplyMessage> QuickReplyManager::get_quick_reply_message_object(
    const QuickReplyMessage *m, const char *source) const {
  CHECK(m != nullptr);
  auto can_be_edited = can_edit_quick_reply_message(m);
  return td_api::make_object<td_api::quickReplyMessage>(
      m->message_id.get(), get_message_sending_state_object(m), can_be_edited, m->reply_to_message_id.get(),
      td_->user_manager_->get_user_id_object(m->via_bot_user_id, "via_bot_user_id"), m->media_album_id,
      get_quick_reply_message_message_content_object(m),
      get_reply_markup_object(td_->user_manager_.get(), m->reply_markup));
}

int32 QuickReplyManager::get_shortcut_message_count(const Shortcut *s) {
  return s->server_total_count_ + s->local_total_count_;
}

bool QuickReplyManager::have_all_shortcut_messages(const Shortcut *s) {
  return static_cast<int32>(s->messages_.size()) == get_shortcut_message_count(s);
}

td_api::object_ptr<td_api::quickReplyShortcut> QuickReplyManager::get_quick_reply_shortcut_object(
    const Shortcut *s, const char *source) const {
  CHECK(s != nullptr);
  CHECK(!s->messages_.empty());
  return td_api::make_object<td_api::quickReplyShortcut>(s->shortcut_id_.get(), s->name_,
                                                         get_quick_reply_message_object(s->messages_[0].get(), source),
                                                         get_shortcut_message_count(s));
}

void QuickReplyManager::get_quick_reply_shortcuts(Promise<Unit> &&promise) {
  load_quick_reply_shortcuts();
  if (shortcuts_.are_inited_) {
    return promise.set_value(Unit());
  }

  shortcuts_.load_queries_.push_back(std::move(promise));
  if (shortcuts_.load_queries_.size() != 1) {
    return;
  }
  reload_quick_reply_shortcuts();
}

void QuickReplyManager::reload_quick_reply_shortcuts() {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  load_quick_reply_shortcuts();
  auto promise = PromiseCreator::lambda(
      [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::messages_QuickReplies>> r_shortcuts) {
        send_closure(actor_id, &QuickReplyManager::on_reload_quick_reply_shortcuts, std::move(r_shortcuts));
      });
  td_->create_handler<GetQuickRepliesQuery>(std::move(promise))->send(get_shortcuts_hash());
}

void QuickReplyManager::on_reload_quick_reply_shortcuts(
    Result<telegram_api::object_ptr<telegram_api::messages_QuickReplies>> r_shortcuts) {
  G()->ignore_result_if_closing(r_shortcuts);
  if (r_shortcuts.is_error()) {
    return on_load_quick_reply_fail(r_shortcuts.move_as_error());
  }
  auto shortcuts_ptr = r_shortcuts.move_as_ok();
  switch (shortcuts_ptr->get_id()) {
    case telegram_api::messages_quickRepliesNotModified::ID:
      if (!shortcuts_.are_inited_) {
        shortcuts_.are_inited_ = true;
        save_quick_reply_shortcuts();
        send_update_quick_reply_shortcuts();
      }
      break;
    case telegram_api::messages_quickReplies::ID: {
      auto shortcuts = telegram_api::move_object_as<telegram_api::messages_quickReplies>(shortcuts_ptr);
      td_->user_manager_->on_get_users(std::move(shortcuts->users_), "messages.quickReplies");
      td_->chat_manager_->on_get_chats(std::move(shortcuts->chats_), "messages.quickReplies");

      FlatHashMap<MessageId, telegram_api::object_ptr<telegram_api::Message>, MessageIdHash> message_id_to_message;
      for (auto &message : shortcuts->messages_) {
        auto message_id = MessageId::get_message_id(message, false);
        if (!message_id.is_valid()) {
          continue;
        }
        message_id_to_message[message_id] = std::move(message);
      }

      FlatHashSet<QuickReplyShortcutId, QuickReplyShortcutIdHash> old_shortcut_ids;
      for (auto &shortcut : shortcuts_.shortcuts_) {
        CHECK(shortcut->shortcut_id_.is_valid());
        old_shortcut_ids.insert(shortcut->shortcut_id_);
      }
      FlatHashSet<QuickReplyShortcutId, QuickReplyShortcutIdHash> added_shortcut_ids;
      FlatHashSet<string> added_shortcut_names;
      vector<unique_ptr<Shortcut>> new_shortcuts;
      vector<QuickReplyShortcutId> changed_shortcut_ids;
      vector<QuickReplyShortcutId> changed_message_shortcut_ids;
      vector<QuickReplyShortcutId> deleted_shortcut_ids;
      for (auto &quick_reply : shortcuts->quick_replies_) {
        auto shortcut_id = QuickReplyShortcutId(quick_reply->shortcut_id_);
        if (!shortcut_id.is_server() || quick_reply->shortcut_.empty() || quick_reply->count_ <= 0 ||
            quick_reply->top_message_ <= 0) {
          LOG(ERROR) << "Receive " << to_string(quick_reply);
          continue;
        }
        if (added_shortcut_ids.count(shortcut_id) || added_shortcut_names.count(quick_reply->shortcut_)) {
          LOG(ERROR) << "Receive duplicate " << to_string(quick_reply);
          continue;
        }
        if (deleted_shortcut_ids_.count(shortcut_id)) {
          continue;
        }
        added_shortcut_ids.insert(shortcut_id);
        added_shortcut_names.insert(quick_reply->shortcut_);

        MessageId first_message_id(ServerMessageId(quick_reply->top_message_));
        auto it = message_id_to_message.find(first_message_id);
        if (it == message_id_to_message.end()) {
          LOG(ERROR) << "Can't find last " << first_message_id << " in " << shortcut_id;
          continue;
        }
        auto message = create_message(std::move(it->second), "on_reload_quick_reply_shortcuts");
        message_id_to_message.erase(it);
        if (message == nullptr) {
          continue;
        }
        if (message->shortcut_id != shortcut_id) {
          LOG(ERROR) << "Receive message from " << message->shortcut_id << " instead of " << shortcut_id;
          continue;
        }

        auto shortcut = td::make_unique<Shortcut>();
        shortcut->name_ = std::move(quick_reply->shortcut_);
        shortcut->shortcut_id_ = shortcut_id;
        shortcut->server_total_count_ = quick_reply->count_;
        shortcut->messages_.push_back(std::move(message));

        auto old_shortcut = get_shortcut(shortcut_id);
        if (old_shortcut == nullptr) {
          changed_shortcut_ids.push_back(shortcut_id);
          changed_message_shortcut_ids.push_back(shortcut_id);
          register_new_message(shortcut->messages_[0].get(), "on_reload_quick_reply_shortcuts 1");
        } else {
          bool is_shortcut_changed = false;
          bool are_messages_changed = false;
          update_shortcut_from(shortcut.get(), old_shortcut, true, &is_shortcut_changed, &are_messages_changed);
          if (are_messages_changed) {
            changed_message_shortcut_ids.push_back(shortcut_id);
          }
          if (is_shortcut_changed) {
            changed_shortcut_ids.push_back(shortcut_id);
          }
          old_shortcut_ids.erase(shortcut_id);
        }

        new_shortcuts.push_back(std::move(shortcut));
      }
      for (auto shortcut_id : old_shortcut_ids) {
        auto old_shortcut = get_shortcut(shortcut_id);
        CHECK(old_shortcut != nullptr);
        auto is_changed = td::remove_if(old_shortcut->messages_, [&](const unique_ptr<QuickReplyMessage> &message) {
          if (message->message_id.is_server()) {
            delete_message_files(message.get());
            return true;
          }
          return false;
        });
        if (old_shortcut->messages_.empty()) {
          CHECK(is_changed);
          send_update_quick_reply_shortcut_deleted(old_shortcut);
        } else {
          // some local messages left
          if (added_shortcut_names.count(old_shortcut->name_)) {
            LOG(INFO) << "Local shortcut " << old_shortcut->name_ << " has been created server-side";
            for (auto &shortcut : new_shortcuts) {
              if (shortcut->name_ == old_shortcut->name_) {
                LOG(INFO) << "Move local messages from " << old_shortcut->shortcut_id_ << " to "
                          << shortcut->shortcut_id_;
                CHECK(shortcut->local_total_count_ == 0);
                shortcut->local_total_count_ = static_cast<int32>(old_shortcut->messages_.size());
                for (auto &message : old_shortcut->messages_) {
                  CHECK(message->shortcut_id == shortcut_id);
                  unregister_message_content(message.get(), "on_reload_quick_reply_shortcuts 2");
                  message->shortcut_id = shortcut->shortcut_id_;
                  register_message_content(message.get(), "on_reload_quick_reply_shortcuts 3");
                }
                append(shortcut->messages_, std::move(old_shortcut->messages_));
                sort_quick_reply_messages(shortcut->messages_);
                send_update_quick_reply_shortcut_deleted(old_shortcut);
                changed_shortcut_ids.push_back(shortcut->shortcut_id_);
                changed_message_shortcut_ids.push_back(shortcut->shortcut_id_);
                persistent_shortcut_ids_[shortcut_id] = shortcut->shortcut_id_;
                break;
              }
            }
            continue;
          }

          LOG(INFO) << "Keep local shortcut " << old_shortcut->name_;
          auto shortcut = td::make_unique<Shortcut>();
          shortcut->name_ = std::move(old_shortcut->name_);
          shortcut->shortcut_id_ = old_shortcut->shortcut_id_;
          shortcut->server_total_count_ = 0;
          shortcut->local_total_count_ = static_cast<int32>(old_shortcut->messages_.size());
          shortcut->messages_ = std::move(old_shortcut->messages_);
          if (is_changed) {
            changed_shortcut_ids.push_back(shortcut->shortcut_id_);
            changed_message_shortcut_ids.push_back(shortcut->shortcut_id_);
          }
          new_shortcuts.push_back(std::move(shortcut));
        }
      }
      bool is_list_changed = is_shortcut_list_changed(new_shortcuts);
      shortcuts_.shortcuts_ = std::move(new_shortcuts);
      shortcuts_.are_inited_ = true;

      save_quick_reply_shortcuts();
      for (auto shortcut_id : changed_shortcut_ids) {
        send_update_quick_reply_shortcut(get_shortcut(shortcut_id), "on_reload_quick_reply_shortcuts");
      }
      for (auto shortcut_id : changed_message_shortcut_ids) {
        const auto *s = get_shortcut(shortcut_id);
        send_update_quick_reply_shortcut_messages(s, "on_reload_quick_reply_shortcuts");
      }
      if (is_list_changed) {
        send_update_quick_reply_shortcuts();
      }
      break;
    }
    default:
      UNREACHABLE();
  }
  on_load_quick_reply_success();
}

bool QuickReplyManager::is_shortcut_list_changed(const vector<unique_ptr<Shortcut>> &new_shortcuts) const {
  if (!shortcuts_.are_inited_ || shortcuts_.shortcuts_.size() != new_shortcuts.size()) {
    return true;
  }
  for (size_t i = 0; i < new_shortcuts.size(); i++) {
    if (shortcuts_.shortcuts_[i]->shortcut_id_ != new_shortcuts[i]->shortcut_id_) {
      return true;
    }
  }
  return false;
}

void QuickReplyManager::on_load_quick_reply_success() {
  for (auto &shortcut : shortcuts_.shortcuts_) {
    reload_quick_reply_messages(shortcut->shortcut_id_, Auto());
  }
  set_promises(shortcuts_.load_queries_);
}

void QuickReplyManager::on_load_quick_reply_fail(Status error) {
  fail_promises(shortcuts_.load_queries_, std::move(error));
}

int64 QuickReplyManager::get_shortcuts_hash() const {
  vector<uint64> numbers;
  for (auto &shortcut : shortcuts_.shortcuts_) {
    for (auto &message : shortcut->messages_) {
      if (message->message_id.is_server()) {
        CHECK(shortcut->shortcut_id_.is_server());
        numbers.push_back(shortcut->shortcut_id_.get());
        numbers.push_back(get_md5_string_hash(shortcut->name_));
        numbers.push_back(message->message_id.get_server_message_id().get());
        numbers.push_back(message->edit_date);
        break;
      }
    }
  }
  return get_vector_hash(numbers);
}

void QuickReplyManager::set_quick_reply_shortcut_name(QuickReplyShortcutId shortcut_id, const string &name,
                                                      Promise<Unit> &&promise) {
  load_quick_reply_shortcuts();
  const auto *shortcut = get_shortcut(shortcut_id);
  if (shortcut == nullptr) {
    return promise.set_error(Status::Error(400, "Shortcut not found"));
  }
  if (check_shortcut_name(name).is_error()) {
    return promise.set_error(Status::Error(400, "Shortcut name is invalid"));
  }
  if (!shortcut_id.is_server()) {
    return promise.set_error(Status::Error(400, "Shortcut isn't created yet"));
  }
  auto query_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), shortcut_id, name, promise = std::move(promise)](Result<Unit> &&result) mutable {
        if (result.is_ok()) {
          send_closure(actor_id, &QuickReplyManager::on_set_quick_reply_shortcut_name, shortcut_id, name,
                       std::move(promise));
        } else {
          promise.set_error(result.move_as_error());
        }
      });
  set_quick_reply_shortcut_name_on_server(shortcut_id, name, std::move(query_promise));
}

void QuickReplyManager::set_quick_reply_shortcut_name_on_server(QuickReplyShortcutId shortcut_id, const string &name,
                                                                Promise<Unit> &&promise) {
  CHECK(shortcut_id.is_server());
  td_->create_handler<EditQuickReplyShortcutQuery>(std::move(promise))->send(shortcut_id, name);
}

void QuickReplyManager::on_set_quick_reply_shortcut_name(QuickReplyShortcutId shortcut_id, const string &name,
                                                         Promise<Unit> &&promise) {
  auto *shortcut = get_shortcut(shortcut_id);
  if (shortcut == nullptr || shortcut->name_ == name) {
    return promise.set_value(Unit());
  }
  shortcut->name_ = name;
  send_update_quick_reply_shortcut(shortcut, "on_set_quick_reply_shortcut_name");
  save_quick_reply_shortcuts();
  promise.set_value(Unit());
}

void QuickReplyManager::delete_quick_reply_shortcut(QuickReplyShortcutId shortcut_id, Promise<Unit> &&promise) {
  load_quick_reply_shortcuts();
  auto it = get_shortcut_it(shortcut_id);
  if (it == shortcuts_.shortcuts_.end()) {
    return promise.set_error(Status::Error(400, "Shortcut not found"));
  }
  send_update_quick_reply_shortcut_deleted(it->get());
  shortcuts_.shortcuts_.erase(it);
  save_quick_reply_shortcuts();
  send_update_quick_reply_shortcuts();

  if (!shortcut_id.is_server()) {
    return promise.set_value(Unit());
  }

  delete_quick_reply_shortcut_from_server(shortcut_id, std::move(promise));
}

void QuickReplyManager::delete_quick_reply_shortcut_from_server(QuickReplyShortcutId shortcut_id,
                                                                Promise<Unit> &&promise) {
  CHECK(shortcut_id.is_server());

  deleted_shortcut_ids_.insert(shortcut_id);
  td_->create_handler<DeleteQuickReplyShortcutQuery>(std::move(promise))->send(shortcut_id);
}

void QuickReplyManager::reorder_quick_reply_shortcuts(const vector<QuickReplyShortcutId> &shortcut_ids,
                                                      Promise<Unit> &&promise) {
  load_quick_reply_shortcuts();
  FlatHashSet<QuickReplyShortcutId, QuickReplyShortcutIdHash> unique_shortcut_ids;
  for (const auto &shortcut_id : shortcut_ids) {
    if (get_shortcut(shortcut_id) == nullptr) {
      return promise.set_error(Status::Error(400, "Shortcut not found"));
    }
    CHECK(shortcut_id.is_valid());
    unique_shortcut_ids.insert(shortcut_id);
  }
  if (unique_shortcut_ids.size() != shortcut_ids.size()) {
    return promise.set_error(Status::Error(400, "Duplicate shortcut identifiers specified"));
  }
  if (!shortcuts_.are_inited_) {
    return promise.set_value(Unit());
  }
  auto old_shortcut_ids = get_shortcut_ids();
  auto old_server_shortcut_ids = get_server_shortcut_ids();
  vector<unique_ptr<Shortcut>> shortcuts;
  for (const auto &shortcut_id : shortcut_ids) {
    auto it = get_shortcut_it(shortcut_id);
    CHECK(it != shortcuts_.shortcuts_.end() && *it != nullptr);
    shortcuts.push_back(std::move(*it));
  }
  for (auto &shortcut : shortcuts_.shortcuts_) {
    if (shortcut != nullptr) {
      CHECK(unique_shortcut_ids.count(shortcut->shortcut_id_) == 0);
      shortcuts.push_back(std::move(shortcut));
    }
  }
  shortcuts_.shortcuts_ = std::move(shortcuts);
  if (old_shortcut_ids == get_shortcut_ids()) {
    return promise.set_value(Unit());
  }
  save_quick_reply_shortcuts();
  send_update_quick_reply_shortcuts();

  auto new_server_shortcut_ids = get_server_shortcut_ids();
  if (new_server_shortcut_ids == old_server_shortcut_ids) {
    return promise.set_value(Unit());
  }

  reorder_quick_reply_shortcuts_on_server(new_server_shortcut_ids, std::move(promise));
}

void QuickReplyManager::reorder_quick_reply_shortcuts_on_server(vector<QuickReplyShortcutId> shortcut_ids,
                                                                Promise<Unit> &&promise) {
  td_->create_handler<ReorderQuickRepliesQuery>(std::move(promise))->send(std::move(shortcut_ids));
}

void QuickReplyManager::update_quick_reply_message(telegram_api::object_ptr<telegram_api::Message> &&message_ptr) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  load_quick_reply_shortcuts();
  auto message = create_message(std::move(message_ptr), "update_quick_reply_message");
  if (message == nullptr) {
    return;
  }
  auto shortcut_id = message->shortcut_id;
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return reload_quick_reply_messages(shortcut_id, Promise<Unit>());
  }
  on_get_quick_reply_message(s, std::move(message));
}

void QuickReplyManager::on_get_quick_reply_message(Shortcut *s, unique_ptr<QuickReplyMessage> message) {
  CHECK(s->shortcut_id_ == message->shortcut_id);
  auto it = get_message_it(s, message->message_id);
  if (it == s->messages_.end()) {
    register_new_message(message.get(), "on_get_quick_reply_message");
    s->messages_.push_back(std::move(message));
    s->server_total_count_++;
    sort_quick_reply_messages(s->messages_);
    send_update_quick_reply_shortcut(s, "on_get_quick_reply_message 1");
  } else {
    if (get_quick_reply_unique_id(it->get()) == get_quick_reply_unique_id(message.get())) {
      return;
    }
    update_quick_reply_message(*it, std::move(message));
    if (it == s->messages_.begin()) {
      send_update_quick_reply_shortcut(s, "on_get_quick_reply_message 2");
    }
  }
  send_update_quick_reply_shortcut_messages(s, "on_get_quick_reply_message 2");
  save_quick_reply_shortcuts();
}

void QuickReplyManager::update_quick_reply_message(unique_ptr<QuickReplyMessage> &old_message,
                                                   unique_ptr<QuickReplyMessage> &&new_message) {
  CHECK(old_message != nullptr);
  CHECK(new_message != nullptr);
  CHECK(old_message->shortcut_id == new_message->shortcut_id);
  CHECK(old_message->message_id == new_message->message_id);
  CHECK(old_message->message_id.is_server());
  if (old_message->edit_date > new_message->edit_date) {
    LOG(INFO) << "Ignore update of " << old_message->message_id << " from " << old_message->shortcut_id
              << " to its old version";
    return;
  }
  auto old_file_ids = get_message_file_ids(old_message.get());
  new_message->edited_content = std::move(old_message->edited_content);
  new_message->edited_file_upload_id = old_message->edited_file_upload_id;
  new_message->edited_thumbnail_file_upload_id = old_message->edited_thumbnail_file_upload_id;
  new_message->edited_invert_media = old_message->edited_invert_media;
  new_message->edited_disable_web_page_preview = old_message->edited_disable_web_page_preview;
  new_message->edit_generation = old_message->edit_generation;
  unregister_message_content(old_message.get(), "update_quick_reply_message");
  old_message = std::move(new_message);
  register_message_content(old_message.get(), "update_quick_reply_message");
  change_message_files(old_message.get(), old_file_ids);
}

void QuickReplyManager::on_external_update_message_content(QuickReplyMessageFullId message_full_id, const char *source,
                                                           bool expect_no_message) {
  const auto *s = get_shortcut(message_full_id.get_quick_reply_shortcut_id());
  auto message_id = message_full_id.get_message_id();
  const auto *m = get_message(s, message_id);
  if (expect_no_message && m == nullptr) {
    return;
  }
  CHECK(m != nullptr);
  if (s->messages_[0]->message_id == message_id) {
    send_update_quick_reply_shortcut(s, "on_external_update_message_content");
  }
  send_update_quick_reply_shortcut_messages(s, "on_external_update_message_content");
  // must not call save_quick_reply_shortcuts, because the message itself wasn't changed
}

void QuickReplyManager::delete_pending_message_web_page(QuickReplyMessageFullId message_full_id) {
  auto *m = get_message_editable(message_full_id);
  CHECK(has_message_content_web_page(m->content.get()));
  unregister_message_content(m, "delete_pending_message_web_page");
  remove_message_content_web_page(m->content.get());
  register_message_content(m, "delete_pending_message_web_page");

  // don't need to send updates, because the web page was pending

  save_quick_reply_shortcuts();
}

void QuickReplyManager::delete_quick_reply_messages_from_updates(QuickReplyShortcutId shortcut_id,
                                                                 const vector<MessageId> &message_ids) {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  load_quick_reply_shortcuts();
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return;
  }
  for (auto message_id : message_ids) {
    if (!message_id.is_server()) {
      LOG(ERROR) << "Receive delete of " << message_ids;
      return;
    }
  }
  delete_quick_reply_messages(s, message_ids, "delete_quick_reply_messages_from_updates");
}

void QuickReplyManager::delete_quick_reply_messages(Shortcut *s, const vector<MessageId> &message_ids,
                                                    const char *source) {
  LOG(INFO) << "Delete " << message_ids << " from " << s->shortcut_id_ << " from " << source;
  bool is_changed = false;
  for (auto &message_id : message_ids) {
    auto it = get_message_it(s, message_id);
    if (it != s->messages_.end()) {
      const auto *m = it->get();
      delete_message_files(m);
      if (message_id.is_server()) {
        s->server_total_count_--;
      } else {
        if (m->media_album_id != 0 && m->message_id.is_yet_unsent()) {
          send_closure_later(actor_id(this), &QuickReplyManager::on_upload_message_media_finished, m->media_album_id,
                             m->shortcut_id, m->message_id, Status::OK());
        }
        s->local_total_count_--;
      }
      is_changed = true;
      s->messages_.erase(it);
    }
    if (message_id.is_server()) {
      deleted_message_full_ids_.insert({s->shortcut_id_, message_id});
    }
  }
  if (s->messages_.empty()) {
    send_update_quick_reply_shortcut_deleted(s);
    shortcuts_.shortcuts_.erase(get_shortcut_it(s->shortcut_id_));
    CHECK(is_changed);
    send_update_quick_reply_shortcuts();
    save_quick_reply_shortcuts();
  } else if (is_changed) {
    send_update_quick_reply_shortcut(s, source);
    send_update_quick_reply_shortcut_messages(s, source);
    save_quick_reply_shortcuts();
  }
}

void QuickReplyManager::delete_quick_reply_shortcut_messages(QuickReplyShortcutId shortcut_id,
                                                             const vector<MessageId> &message_ids,
                                                             Promise<Unit> &&promise) {
  load_quick_reply_shortcuts();
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return promise.set_error(Status::Error(400, "Shortcut not found"));
  }
  if (message_ids.empty()) {
    return promise.set_value(Unit());
  }

  vector<MessageId> deleted_server_message_ids;
  for (auto &message_id : message_ids) {
    if (!message_id.is_valid()) {
      return promise.set_error(Status::Error(400, "Invalid message identifier"));
    }

    // message_id = get_persistent_message_id(s, message_id);
    if (message_id.is_server()) {
      deleted_server_message_ids.push_back(message_id);
    }
  }

  delete_quick_reply_messages_on_server(shortcut_id, std::move(deleted_server_message_ids), std::move(promise));

  delete_quick_reply_messages(s, message_ids, "delete_quick_reply_shortcut_messages");
}

void QuickReplyManager::delete_quick_reply_messages_on_server(QuickReplyShortcutId shortcut_id,
                                                              const vector<MessageId> &message_ids,
                                                              Promise<Unit> &&promise) {
  if (message_ids.empty()) {
    return promise.set_value(Unit());
  }
  td_->create_handler<DeleteQuickReplyMessagesQuery>(std::move(promise))->send(shortcut_id, message_ids);
}

telegram_api::object_ptr<telegram_api::InputQuickReplyShortcut> QuickReplyManager::get_input_quick_reply_shortcut(
    QuickReplyShortcutId shortcut_id) const {
  if (shortcut_id.is_server()) {
    return telegram_api::make_object<telegram_api::inputQuickReplyShortcutId>(shortcut_id.get());
  }
  const auto *s = get_shortcut(shortcut_id);
  CHECK(s != nullptr);
  return telegram_api::make_object<telegram_api::inputQuickReplyShortcut>(s->name_);
}

Status QuickReplyManager::check_send_quick_reply_messages_response(
    QuickReplyShortcutId shortcut_id, const telegram_api::object_ptr<telegram_api::Updates> &updates_ptr,
    const vector<int64> &random_ids) {
  if (updates_ptr->get_id() != telegram_api::updates::ID) {
    return Status::Error("Receive unexpected updates class");
  }
  const auto &updates = static_cast<const telegram_api::updates *>(updates_ptr.get())->updates_;
  FlatHashSet<int64> sent_random_ids;
  for (auto &update : updates) {
    if (update->get_id() == telegram_api::updateMessageID::ID) {
      auto update_message_id = static_cast<const telegram_api::updateMessageID *>(update.get());
      int64 random_id = update_message_id->random_id_;
      if (random_id == 0) {
        return Status::Error("Receive zero random_id");
      }
      if (!sent_random_ids.insert(random_id).second) {
        return Status::Error("Receive duplicate random_id");
      }
    }
  }
  if (sent_random_ids.size() != random_ids.size()) {
    return Status::Error("Receive duplicate random_id");
  }
  for (auto random_id : random_ids) {
    if (sent_random_ids.count(random_id) != 1) {
      return Status::Error("Don't receive expected random_id");
    }
  }
  int32 new_shortcut_count = 0;
  for (auto &update : updates) {
    if (update->get_id() == telegram_api::updateNewQuickReply::ID) {
      if (!QuickReplyShortcutId(
               static_cast<const telegram_api::updateNewQuickReply *>(update.get())->quick_reply_->shortcut_id_)
               .is_server()) {
        return Status::Error("Receive unexpected new shortcut");
      }
      new_shortcut_count++;
    }
  }
  if (new_shortcut_count >= 2 || (new_shortcut_count >= 1 && shortcut_id.is_server())) {
    return Status::Error("Receive unexpected number of new shortcuts");
  }
  return Status::OK();
}

void QuickReplyManager::process_send_quick_reply_updates(QuickReplyShortcutId shortcut_id, FileUploadId file_upload_id,
                                                         telegram_api::object_ptr<telegram_api::Updates> updates_ptr,
                                                         vector<int64> random_ids) {
  auto check_status = check_send_quick_reply_messages_response(shortcut_id, updates_ptr, random_ids);
  if (check_status.is_error()) {
    LOG(ERROR) << check_status << " for sending messages " << random_ids << ": " << to_string(updates_ptr);
    if (file_upload_id.is_valid()) {
      send_closure_later(G()->file_manager(), &FileManager::delete_partial_remote_location, file_upload_id);
    }
    on_failed_send_quick_reply_messages(shortcut_id, std::move(random_ids),
                                        Status::Error(500, "Receive wrong response"));
    return;
  }

  auto updates = telegram_api::move_object_as<telegram_api::updates>(updates_ptr);
  td_->user_manager_->on_get_users(std::move(updates->users_), "process_send_quick_reply_updates");
  td_->chat_manager_->on_get_chats(std::move(updates->chats_), "process_send_quick_reply_updates");

  bool is_shortcut_new = false;
  if (shortcut_id.is_local()) {
    QuickReplyShortcutId new_shortcut_id;
    for (auto &update : updates->updates_) {
      if (update->get_id() == telegram_api::updateNewQuickReply::ID) {
        new_shortcut_id = QuickReplyShortcutId(
            static_cast<const telegram_api::updateNewQuickReply *>(update.get())->quick_reply_->shortcut_id_);
        update = nullptr;
      }
    }
    if (!new_shortcut_id.is_server()) {
      for (const auto &update : updates->updates_) {
        if (update != nullptr && update->get_id() == telegram_api::updateQuickReplyMessage::ID) {
          auto &message = static_cast<const telegram_api::updateQuickReplyMessage *>(update.get())->message_;
          if (message->get_id() == telegram_api::message::ID) {
            new_shortcut_id = QuickReplyShortcutId(
                static_cast<const telegram_api::message *>(message.get())->quick_reply_shortcut_id_);
            break;
          }
        }
      }
    }
    if (!new_shortcut_id.is_server()) {
      LOG(ERROR) << "Failed to find new shortcut identifier for " << shortcut_id;
      reload_quick_reply_shortcuts();
      on_failed_send_quick_reply_messages(shortcut_id, std::move(random_ids),
                                          Status::Error(500, "Receive wrong response"));
      return;
    }
    auto it = get_shortcut_it(shortcut_id);
    if (it != shortcuts_.shortcuts_.end() && (*it)->shortcut_id_ == shortcut_id) {
      send_update_quick_reply_shortcut_deleted(it->get());

      for (auto &message : (*it)->messages_) {
        CHECK(message->shortcut_id == shortcut_id);
        unregister_message_content(message.get(), "process_send_quick_reply_updates 1");
        message->shortcut_id = new_shortcut_id;
        register_message_content(message.get(), "process_send_quick_reply_updates 1");
      }

      auto *s = get_shortcut(new_shortcut_id);
      if (s == nullptr) {
        (*it)->shortcut_id_ = new_shortcut_id;
        is_shortcut_new = true;
      } else {
        if ((*it)->last_assigned_message_id_ > s->last_assigned_message_id_) {
          s->last_assigned_message_id_ = (*it)->last_assigned_message_id_;
        }
        for (auto &message : (*it)->messages_) {
          CHECK(!message->message_id.is_server());
          s->messages_.push_back(std::move(message));
          s->local_total_count_++;
        }
        shortcuts_.shortcuts_.erase(it);
      }
      persistent_shortcut_ids_[shortcut_id] = new_shortcut_id;
    } else if (get_shortcut(new_shortcut_id) == nullptr) {
      if (file_upload_id.is_valid()) {
        send_closure_later(G()->file_manager(), &FileManager::delete_partial_remote_location, file_upload_id);
      }
      return;
    }
    shortcut_id = new_shortcut_id;
  }
  auto *s = get_shortcut(shortcut_id);
  CHECK(s != nullptr);

  for (auto &random_id : random_ids) {
    for (auto it = s->messages_.begin(); it != s->messages_.end(); ++it) {
      if ((*it)->random_id == random_id && (*it)->message_id.is_yet_unsent()) {
        MessageId new_message_id;
        for (auto &update : updates->updates_) {
          if (update != nullptr && update->get_id() == telegram_api::updateMessageID::ID &&
              static_cast<const telegram_api::updateMessageID *>(update.get())->random_id_ == random_id) {
            new_message_id =
                MessageId(ServerMessageId(static_cast<const telegram_api::updateMessageID *>(update.get())->id_));
            update = nullptr;
          }
        }
        if (new_message_id.is_valid()) {
          for (auto &update : updates->updates_) {
            if (update != nullptr && update->get_id() == telegram_api::updateQuickReplyMessage::ID &&
                MessageId::get_message_id(
                    static_cast<const telegram_api::updateQuickReplyMessage *>(update.get())->message_, false) ==
                    new_message_id) {
              auto message = create_message(
                  std::move(static_cast<telegram_api::updateQuickReplyMessage *>(update.get())->message_),
                  "process_send_quick_reply_updates");
              if (message != nullptr && message->shortcut_id == shortcut_id) {
                update_sent_message_content_from_temporary_message(it->get(), message.get(), false);
                unregister_message_content(it->get(), "process_send_quick_reply_updates 2");
                auto old_message_it = get_message_it(s, message->message_id);
                if (old_message_it == s->messages_.end()) {
                  *it = std::move(message);
                  register_new_message(it->get(), "process_send_quick_reply_updates 2");
                  s->server_total_count_++;
                } else {
                  // the message has already been added
                  update_quick_reply_message(*old_message_it, std::move(message));
                  s->messages_.erase(it);
                }
                s->local_total_count_--;
              }
              update = nullptr;
              break;
            }
          }
        }

        break;
      }
    }
  }
  if (file_upload_id.is_valid()) {
    send_closure_later(G()->file_manager(), &FileManager::delete_partial_remote_location, file_upload_id);
  }

  sort_quick_reply_messages(s->messages_);
  send_update_quick_reply_shortcut(s, "process_send_quick_reply_updates");
  send_update_quick_reply_shortcut_messages(s, "process_send_quick_reply_updates");
  if (is_shortcut_new) {
    send_update_quick_reply_shortcuts();
  }
  save_quick_reply_shortcuts();
}

void QuickReplyManager::update_sent_message_content_from_temporary_message(const QuickReplyMessage *old_message,
                                                                           QuickReplyMessage *new_message,
                                                                           bool is_edit) {
  CHECK(is_edit ? old_message->message_id.is_server() : old_message->message_id.is_yet_unsent());
  CHECK(new_message->edited_content == nullptr);
  update_sent_message_content_from_temporary_message(
      is_edit ? old_message->edited_content : old_message->content,
      is_edit ? old_message->edited_file_upload_id : old_message->file_upload_id, new_message->content,
      is_edit || new_message->edit_date == 0);
}

void QuickReplyManager::update_sent_message_content_from_temporary_message(
    const unique_ptr<MessageContent> &old_content, FileUploadId old_file_upload_id,
    unique_ptr<MessageContent> &new_content, bool need_merge_files) {
  MessageContentType old_content_type = old_content->get_type();
  MessageContentType new_content_type = new_content->get_type();

  need_merge_files = need_merge_files && old_file_upload_id.is_valid();
  if (old_content_type != new_content_type) {
    if (need_merge_files) {
      td_->file_manager_->try_merge_documents(get_message_content_any_file_id(new_content.get()),
                                              old_file_upload_id.get_file_id());
    }
  } else {
    bool is_content_changed = false;
    bool need_update = false;
    merge_message_contents(td_, old_content.get(), new_content.get(), true, DialogId(), need_merge_files,
                           is_content_changed, need_update);
  }
  if (old_file_upload_id.is_valid()) {
    send_closure_later(G()->file_manager(), &FileManager::cancel_upload, old_file_upload_id);

    update_message_content_file_id_remote(new_content.get(), old_file_upload_id.get_file_id());
  }
}

void QuickReplyManager::on_failed_send_quick_reply_messages(QuickReplyShortcutId shortcut_id, vector<int64> random_ids,
                                                            Status error) {
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    // the shortcut was deleted
    return;
  }

  for (auto &random_id : random_ids) {
    for (auto it = s->messages_.begin(); it != s->messages_.end(); ++it) {
      if ((*it)->random_id == random_id && (*it)->message_id.is_yet_unsent()) {
        auto old_message_id = (*it)->message_id;
        auto new_message_id = old_message_id.get_next_message_id(MessageType::Local);
        if (get_message_it(s, new_message_id) != s->messages_.end() ||
            deleted_message_full_ids_.count({shortcut_id, new_message_id})) {
          new_message_id = get_next_local_message_id(s);
        } else if (new_message_id > s->last_assigned_message_id_) {
          s->last_assigned_message_id_ = new_message_id;
        }
        CHECK(new_message_id.is_valid());
        unregister_message_content(it->get(), "on_failed_send_quick_reply_messages");
        (*it)->message_id = new_message_id;
        (*it)->is_failed_to_send = true;
        (*it)->send_error_code = error.code();
        (*it)->send_error_message = error.message().str();
        (*it)->try_resend_at = 0.0;
        auto retry_after = Global::get_retry_after((*it)->send_error_code, (*it)->send_error_message);
        if (retry_after > 0) {
          (*it)->try_resend_at = Time::now() + retry_after;
        }
        CHECK((*it)->edited_content == nullptr);
        update_failed_to_send_message_content(td_, (*it)->content);
        (*it)->file_upload_id = {};
        (*it)->thumbnail_file_upload_id = {};
        register_message_content(it->get(), "on_failed_send_quick_reply_messages");

        break;
      }
    }
  }

  sort_quick_reply_messages(s->messages_);
  send_update_quick_reply_shortcut(s, "on_failed_send_quick_reply_messages");
  send_update_quick_reply_shortcut_messages(s, "on_failed_send_quick_reply_messages");
  save_quick_reply_shortcuts();
}

Result<td_api::object_ptr<td_api::quickReplyMessage>> QuickReplyManager::send_message(
    const string &shortcut_name, MessageId reply_to_message_id,
    td_api::object_ptr<td_api::InputMessageContent> &&input_message_content) {
  TRY_RESULT(message_content, process_input_message_content(std::move(input_message_content)));
  TRY_RESULT(s, create_new_local_shortcut(shortcut_name, 1));
  bool is_new = s->messages_.empty();
  reply_to_message_id = get_input_reply_to_message_id(s, reply_to_message_id);

  auto content = dup_message_content(td_, td_->dialog_manager_->get_my_dialog_id(), message_content.content.get(),
                                     MessageContentDupType::Send, MessageCopyOptions());
  auto *m = add_local_message(s, reply_to_message_id, std::move(content), message_content.invert_media,
                              message_content.via_bot_user_id, false, message_content.disable_web_page_preview,
                              std::move(message_content.emoji));

  send_update_quick_reply_shortcut(s, "send_message");
  send_update_quick_reply_shortcut_messages(s, "send_message");
  if (is_new) {
    send_update_quick_reply_shortcuts();
  }
  save_quick_reply_shortcuts();

  do_send_message(m);

  return get_quick_reply_message_object(m, "send_message");
}

Result<td_api::object_ptr<td_api::quickReplyMessage>> QuickReplyManager::send_inline_query_result_message(
    const string &shortcut_name, MessageId reply_to_message_id, int64 query_id, const string &result_id,
    bool hide_via_bot) {
  const InlineMessageContent *message_content =
      td_->inline_queries_manager_->get_inline_message_content(query_id, result_id);
  if (message_content == nullptr || query_id == 0) {
    return Status::Error(400, "Inline query result not found");
  }
  TRY_RESULT(s, create_new_local_shortcut(shortcut_name, 1));
  bool is_new = s->messages_.empty();
  reply_to_message_id = get_input_reply_to_message_id(s, reply_to_message_id);

  UserId via_bot_user_id;
  if (!hide_via_bot) {
    via_bot_user_id = td_->inline_queries_manager_->get_inline_bot_user_id(query_id);
  }
  auto content =
      dup_message_content(td_, td_->dialog_manager_->get_my_dialog_id(), message_content->message_content.get(),
                          MessageContentDupType::SendViaBot, MessageCopyOptions());
  auto *m = add_local_message(s, reply_to_message_id, std::move(content), message_content->invert_media,
                              via_bot_user_id, hide_via_bot, message_content->disable_web_page_preview, string());
  m->reply_markup = dup_reply_markup(message_content->message_reply_markup);
  m->inline_query_id = query_id;
  m->inline_result_id = result_id;

  send_update_quick_reply_shortcut(s, "send_inline_query_result_message");
  send_update_quick_reply_shortcut_messages(s, "send_inline_query_result_message");
  if (is_new) {
    send_update_quick_reply_shortcuts();
  }
  save_quick_reply_shortcuts();

  do_send_message(m);

  return get_quick_reply_message_object(m, "send_inline_query_result_message");
}

Result<td_api::object_ptr<td_api::quickReplyMessages>> QuickReplyManager::send_message_group(
    const string &shortcut_name, MessageId reply_to_message_id,
    vector<td_api::object_ptr<td_api::InputMessageContent>> &&input_message_contents) {
  vector<InputMessageContent> message_contents;
  for (auto &input_message_content : input_message_contents) {
    TRY_RESULT(message_content, process_input_message_content(std::move(input_message_content)));
    message_contents.push_back(std::move(message_content));
  }
  TRY_STATUS(check_message_group_message_contents(message_contents));

  TRY_RESULT(s, create_new_local_shortcut(shortcut_name, static_cast<int32>(message_contents.size())));
  bool is_new = s->messages_.empty();
  reply_to_message_id = get_input_reply_to_message_id(s, reply_to_message_id);

  int64 media_album_id = 0;
  if (message_contents.size() > 1) {
    media_album_id = generate_new_media_album_id();
  }

  vector<td_api::object_ptr<td_api::quickReplyMessage>> messages;
  for (auto &message_content : message_contents) {
    auto content = dup_message_content(td_, td_->dialog_manager_->get_my_dialog_id(), message_content.content.get(),
                                       MessageContentDupType::Send, MessageCopyOptions());
    auto *m = add_local_message(s, reply_to_message_id, std::move(content), message_content.invert_media,
                                message_content.via_bot_user_id, false, message_content.disable_web_page_preview,
                                std::move(message_content.emoji));
    m->media_album_id = media_album_id;

    do_send_message(m);

    messages.push_back(get_quick_reply_message_object(m, "send_message_group"));
  }

  send_update_quick_reply_shortcut(s, "send_message_group");
  send_update_quick_reply_shortcut_messages(s, "send_message_group");
  if (is_new) {
    send_update_quick_reply_shortcuts();
  }
  save_quick_reply_shortcuts();

  return td_api::make_object<td_api::quickReplyMessages>(std::move(messages));
}

void QuickReplyManager::on_cover_upload(QuickReplyMessageFullId message_full_id, int64 edit_generation,
                                        vector<int> bad_parts, Result<Unit> result) {
  if (G()->close_flag()) {
    return;
  }

  const QuickReplyMessage *m = get_message(message_full_id);
  if (m == nullptr) {
    // message has already been deleted by the user, do not need to send or edit it
    LOG(INFO) << "Quick reply message with a cover has already been deleted";
    return;
  }

  if (result.is_error()) {
    bool is_edit = m->message_id.is_any_server();
    if (is_edit) {
      if (edit_generation == m->edit_generation) {
        fail_edit_quick_reply_message(m->shortcut_id, m->message_id, edit_generation, FileUploadId(), FileUploadId(),
                                      FileId(), string(), string(), false, false, result.move_as_error());
      }
    } else {
      on_failed_send_quick_reply_messages(m->shortcut_id, {m->random_id}, result.move_as_error());
    }
  } else {
    do_send_message(m, std::move(bad_parts));
  }
}

void QuickReplyManager::do_send_message(const QuickReplyMessage *m, vector<int> bad_parts) {
  CHECK(m != nullptr);
  bool is_edit = m->message_id.is_server();
  auto message_full_id = QuickReplyMessageFullId(m->shortcut_id, m->message_id);
  LOG(INFO) << "Do " << (is_edit ? "edit" : "send") << ' ' << message_full_id;

  if (m->media_album_id != 0 && bad_parts.empty() && !is_edit) {
    auto &request = pending_message_group_sends_[m->media_album_id];
    if (!td::contains(request.message_ids, m->message_id)) {
      request.message_ids.push_back(m->message_id);
      request.is_finished.push_back(false);
      request.results.push_back(Status::OK());
    }
  }

  auto content = is_edit ? m->edited_content.get() : m->content.get();
  CHECK(content != nullptr);
  auto content_type = content->get_type();
  if (content_type == MessageContentType::Unsupported) {
    if (is_edit) {
      return fail_edit_quick_reply_message(m->shortcut_id, m->message_id, m->edit_generation, FileUploadId(),
                                           FileUploadId(), FileId(), string(), string(), false, false,
                                           Status::Error(400, "Failed to upload file"));
    }
    return on_failed_send_quick_reply_messages(m->shortcut_id, {m->random_id},
                                               Status::Error(400, "Failed to upload file"));
  }

  if (!is_edit && m->inline_query_id != 0) {
    td_->create_handler<SendQuickReplyInlineMessageQuery>()->send(m);
    return;
  }

  if (content_type == MessageContentType::Text) {
    if (is_edit) {
      td_->create_handler<EditQuickReplyMessageQuery>()->send(m, nullptr);
      return;
    }
    auto input_media = get_message_content_input_media_web_page(td_, content);
    if (input_media == nullptr) {
      td_->create_handler<SendQuickReplyMessageQuery>()->send(m);
    } else {
      td_->create_handler<SendQuickReplyMediaQuery>()->send(m, std::move(input_media));
    }
    return;
  }

  auto covers = get_message_content_need_to_upload_covers(td_, content);
  if (!covers.empty()) {
    return td_->message_query_manager_->upload_message_covers(
        BusinessConnectionId(), td_->dialog_manager_->get_my_dialog_id(), std::move(covers),
        PromiseCreator::lambda([actor_id = actor_id(this), message_full_id, edit_generation = m->edit_generation,
                                bad_parts = std::move(bad_parts)](Result<Unit> result) mutable {
          send_closure(actor_id, &QuickReplyManager::on_cover_upload, message_full_id, edit_generation,
                       std::move(bad_parts), std::move(result));
        }));
  }

  if (bad_parts.empty()) {
    auto file_id = get_message_content_any_file_id(content);
    if (file_id.is_valid()) {
      auto file_upload_id = FileUploadId{file_id, FileManager::get_internal_upload_id()};
      FileUploadId thumbnail_file_upload_id;
      auto thumbnail_file_id = get_message_content_thumbnail_file_id(content, td_);
      if (thumbnail_file_id.is_valid()) {
        FileView file_view = td_->file_manager_->get_file_view(file_id);
        if (get_file_type_class(file_view.get_type()) != FileTypeClass::Photo) {
          thumbnail_file_upload_id = FileUploadId{thumbnail_file_id, FileManager::get_internal_upload_id()};
        }
      }
      if (is_edit) {
        m->edited_file_upload_id = file_upload_id;
        m->edited_thumbnail_file_upload_id = thumbnail_file_upload_id;
      } else {
        m->file_upload_id = file_upload_id;
        m->thumbnail_file_upload_id = thumbnail_file_upload_id;
      }
    }
  }
  auto file_upload_id = is_edit ? m->edited_file_upload_id : m->file_upload_id;
  LOG(DEBUG) << "Need to send " << file_upload_id;
  auto input_media = get_message_content_input_media(content, td_, {}, m->send_emoji, false);
  if (input_media == nullptr) {
    if (content_type == MessageContentType::Game || content_type == MessageContentType::Story) {
      return;
    }
    CHECK(file_upload_id.is_valid());

    LOG(INFO) << "Ask to upload " << file_upload_id << " with bad parts " << bad_parts;
    bool is_inserted =
        being_uploaded_files_.emplace(file_upload_id, std::make_pair(message_full_id, m->edit_generation)).second;
    CHECK(is_inserted);
    td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_media_callback_, 1,
                                      m->message_id.get());
  } else {
    on_message_media_uploaded(m, std::move(input_media));
  }
}

void QuickReplyManager::on_send_message_file_error(QuickReplyShortcutId shortcut_id, int64 random_id,
                                                   vector<int> &&bad_parts) {
  auto *s = get_shortcut(shortcut_id);
  if (s != nullptr) {
    for (auto &message : s->messages_) {
      if (message->random_id == random_id && message->message_id.is_yet_unsent()) {
        do_send_message(message.get(), std::move(bad_parts));
        return;
      }
    }
  }
}

void QuickReplyManager::on_upload_media(FileUploadId file_upload_id,
                                        telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Quick reply " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());
  auto message_full_id = it->second.first;
  auto edit_generation = it->second.second;
  being_uploaded_files_.erase(it);

  const auto *m = get_message(message_full_id);
  if (m == nullptr || (m->message_id.is_server() && m->edit_generation != edit_generation)) {
    send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    return;
  }

  auto thumbnail_file_upload_id =
      m->message_id.is_server() ? m->edited_thumbnail_file_upload_id : m->thumbnail_file_upload_id;
  if (input_file != nullptr && thumbnail_file_upload_id.is_valid()) {
    // TODO: download thumbnail if needed (like in secret chats)
    LOG(INFO) << "Ask to upload thumbnail " << thumbnail_file_upload_id;
    bool is_inserted =
        being_uploaded_thumbnails_
            .emplace(thumbnail_file_upload_id,
                     UploadedThumbnailInfo{message_full_id, file_upload_id, std::move(input_file), edit_generation})
            .second;
    CHECK(is_inserted);
    td_->file_manager_->upload(thumbnail_file_upload_id, upload_thumbnail_callback_, 32, m->message_id.get());
  } else {
    do_send_media(m, std::move(input_file), nullptr);
  }
}

void QuickReplyManager::do_send_media(const QuickReplyMessage *m,
                                      telegram_api::object_ptr<telegram_api::InputFile> input_file,
                                      telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail) {
  CHECK(m != nullptr);

  bool have_input_file = input_file != nullptr;
  bool have_input_thumbnail = input_thumbnail != nullptr;
  bool is_edit = m->message_id.is_server();
  auto content = is_edit ? m->edited_content.get() : m->content.get();
  auto file_upload_id = is_edit ? m->edited_file_upload_id : m->file_upload_id;
  auto thumbnail_file_upload_id = is_edit ? m->edited_thumbnail_file_upload_id : m->thumbnail_file_upload_id;
  CHECK(content != nullptr);

  LOG(INFO) << "Do send media " << QuickReplyMessageFullId{m->shortcut_id, m->message_id} << ": " << file_upload_id
            << " with thumbnail " << thumbnail_file_upload_id << ", have_input_file = " << have_input_file
            << ", have_input_thumbnail = " << have_input_thumbnail;

  auto input_media =
      get_message_content_input_media(content, -1, td_, std::move(input_file), std::move(input_thumbnail),
                                      file_upload_id, thumbnail_file_upload_id, {}, m->send_emoji, true);
  CHECK(input_media != nullptr);

  on_message_media_uploaded(m, std::move(input_media));
}

void QuickReplyManager::on_upload_media_error(FileUploadId file_upload_id, Status status) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(WARNING) << "Quick reply " << file_upload_id << " has upload error " << status;
  CHECK(status.is_error());

  auto it = being_uploaded_files_.find(file_upload_id);
  CHECK(it != being_uploaded_files_.end());

  auto message_full_id = it->second.first;

  being_uploaded_files_.erase(it);

  const auto *m = get_message(message_full_id);
  if (m == nullptr) {
    return;
  }

  on_failed_send_quick_reply_messages(message_full_id.get_quick_reply_shortcut_id(), {m->random_id}, std::move(status));
}

void QuickReplyManager::on_upload_thumbnail(FileUploadId thumbnail_file_upload_id,
                                            telegram_api::object_ptr<telegram_api::InputFile> thumbnail_input_file) {
  if (G()->close_flag()) {
    // do not fail upload if closing
    return;
  }

  LOG(INFO) << "Thumbnail " << thumbnail_file_upload_id << " has been uploaded as " << to_string(thumbnail_input_file);

  auto it = being_uploaded_thumbnails_.find(thumbnail_file_upload_id);
  CHECK(it != being_uploaded_thumbnails_.end());
  auto message_full_id = it->second.quick_reply_message_full_id;
  auto file_upload_id = it->second.file_upload_id;
  auto input_file = std::move(it->second.input_file);
  auto edit_generation = it->second.edit_generation;
  being_uploaded_thumbnails_.erase(it);

  auto *m = get_message_editable(message_full_id);
  if (m == nullptr || (m->message_id.is_server() && m->edit_generation != edit_generation)) {
    send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    send_closure_later(G()->file_manager(), &FileManager::cancel_upload, thumbnail_file_upload_id);
    return;
  }

  if (thumbnail_input_file == nullptr) {
    if (m->message_id.is_server()) {
      delete_message_content_thumbnail(m->edited_content.get(), td_);
      m->edited_thumbnail_file_upload_id = {};
    } else {
      delete_message_content_thumbnail(m->content.get(), td_);
      m->thumbnail_file_upload_id = {};
    }
  }

  do_send_media(m, std::move(input_file), std::move(thumbnail_input_file));
}

void QuickReplyManager::on_message_media_uploaded(const QuickReplyMessage *m,
                                                  telegram_api::object_ptr<telegram_api::InputMedia> &&input_media) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(m != nullptr);
  CHECK(input_media != nullptr);
  auto message_id = m->message_id;
  if (message_id.is_any_server()) {
    CHECK(m->edited_content != nullptr);
    CHECK(m->edited_content->get_type() != MessageContentType::Text);
    td_->create_handler<EditQuickReplyMessageQuery>()->send(m, std::move(input_media));
    return;
  }

  if (m->media_album_id != 0) {
    if (!is_uploaded_input_media(input_media)) {
      td_->create_handler<UploadQuickReplyMediaQuery>()->send(m, std::move(input_media));
    } else {
      send_closure_later(actor_id(this), &QuickReplyManager::on_upload_message_media_finished, m->media_album_id,
                         m->shortcut_id, m->message_id, Status::OK());
    }
    return;
  }

  td_->create_handler<SendQuickReplyMediaQuery>()->send(m, std::move(input_media));
}

void QuickReplyManager::on_upload_message_media_success(QuickReplyShortcutId shortcut_id, MessageId message_id,
                                                        FileUploadId file_upload_id,
                                                        telegram_api::object_ptr<telegram_api::MessageMedia> &&media) {
  const auto *m = get_message({shortcut_id, message_id});
  if (m == nullptr) {
    send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    return;
  }

  CHECK(message_id.is_yet_unsent());
  CHECK(m->file_upload_id == file_upload_id);

  auto content =
      get_uploaded_message_content(td_, m->content.get(), -1, std::move(media),
                                   td_->dialog_manager_->get_my_dialog_id(), 0, "on_upload_message_media_success");
  update_sent_message_content_from_temporary_message(m->content, file_upload_id, content, true);

  save_quick_reply_shortcuts();

  auto input_media = get_message_content_input_media(content.get(), td_, {}, m->send_emoji, true);
  Status result;
  if (input_media == nullptr) {
    result = Status::Error(400, "Failed to upload file");
  }

  send_closure_later(actor_id(this), &QuickReplyManager::on_upload_message_media_finished, m->media_album_id,
                     shortcut_id, message_id, std::move(result));
}

void QuickReplyManager::on_upload_message_media_fail(QuickReplyShortcutId shortcut_id, MessageId message_id,
                                                     Status error) {
  const auto *m = get_message({shortcut_id, message_id});
  if (m == nullptr) {
    return;
  }

  send_closure_later(actor_id(this), &QuickReplyManager::on_upload_message_media_finished, m->media_album_id,
                     shortcut_id, m->message_id, std::move(error));
}

void QuickReplyManager::on_upload_message_media_finished(int64 media_album_id, QuickReplyShortcutId shortcut_id,
                                                         MessageId message_id, Status result) {
  CHECK(media_album_id < 0);
  auto it = pending_message_group_sends_.find(media_album_id);
  if (it == pending_message_group_sends_.end()) {
    CHECK(result.is_ok());
    // the message is being sent but was deleted
    return;
  }

  auto &request = it->second;
  auto message_it = std::find(request.message_ids.begin(), request.message_ids.end(), message_id);
  CHECK(message_it != request.message_ids.end());
  auto pos = static_cast<size_t>(message_it - request.message_ids.begin());

  if (request.is_finished[pos]) {
    LOG(INFO) << "Upload media of " << message_id << " in " << shortcut_id << " from group " << media_album_id
              << " at pos " << pos << " has already been finished";
    return;
  }
  LOG(INFO) << "Finish to upload media of " << message_id << " in " << shortcut_id << " from group " << media_album_id
            << " at pos " << pos << " with result " << result
            << " and previous finished_count = " << request.finished_count;

  request.results[pos] = std::move(result);
  request.is_finished[pos] = true;
  request.finished_count++;

  if (request.finished_count == request.message_ids.size()) {
    do_send_message_group(shortcut_id, media_album_id);
  }
}

void QuickReplyManager::do_send_message_group(QuickReplyShortcutId shortcut_id, int64 media_album_id) {
  if (G()->close_flag()) {
    return;
  }

  CHECK(media_album_id < 0);
  auto it = pending_message_group_sends_.find(media_album_id);
  CHECK(it != pending_message_group_sends_.end());

  auto &request = it->second;
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return;
  }

  vector<FileId> file_ids;
  vector<FileId> cover_file_ids;
  vector<int64> random_ids;
  MessageId reply_to_message_id;
  bool invert_media = false;
  vector<telegram_api::object_ptr<telegram_api::inputSingleMedia>> input_single_media;
  Status error = Status::OK();
  for (size_t i = 0; i < request.message_ids.size(); i++) {
    CHECK(request.is_finished[i]);
    const auto *m = get_message(s, request.message_ids[i]);
    if (m == nullptr) {
      // skip deleted messages
      continue;
    }
    if (request.results[i].is_error()) {
      if (error.is_ok()) {
        error = std::move(request.results[i]);
      }
      continue;
    }

    reply_to_message_id = m->reply_to_message_id;
    invert_media = m->invert_media;
    file_ids.push_back(m->file_upload_id.get_file_id());
    cover_file_ids.push_back(get_message_content_cover_any_file_id(m->content.get()));
    random_ids.push_back(m->random_id);

    LOG(INFO) << "Have file " << file_ids.back() << " in " << m->message_id << " with result " << request.results[i]
              << " and is_finished = " << static_cast<bool>(request.is_finished[i]);

    const FormattedText *caption = get_message_content_caption(m->content.get());
    auto input_media = get_message_content_input_media(m->content.get(), td_, {}, m->send_emoji, true);
    CHECK(input_media != nullptr);
    auto entities = get_input_message_entities(td_->user_manager_.get(), caption, "do_send_message_group");
    int32 input_single_media_flags = 0;
    if (!entities.empty()) {
      input_single_media_flags |= telegram_api::inputSingleMedia::ENTITIES_MASK;
    }
    input_single_media.push_back(telegram_api::make_object<telegram_api::inputSingleMedia>(
        input_single_media_flags, std::move(input_media), random_ids.back(), caption == nullptr ? "" : caption->text,
        std::move(entities)));
  }
  pending_message_group_sends_.erase(it);
  if (error.is_error()) {
    on_failed_send_quick_reply_messages(shortcut_id, std::move(random_ids), std::move(error));
    return;
  }

  LOG(INFO) << "Begin to send media group " << media_album_id << " to " << shortcut_id;

  if (input_single_media.empty()) {
    LOG(INFO) << "Media group " << media_album_id << " from " << shortcut_id << " is empty";
  }
  td_->create_handler<SendQuickReplyMultiMediaQuery>()->send(shortcut_id, reply_to_message_id, invert_media,
                                                             std::move(random_ids), std::move(file_ids),
                                                             std::move(cover_file_ids), std::move(input_single_media));
}

void QuickReplyManager::on_send_media_group_file_reference_error(QuickReplyShortcutId shortcut_id,
                                                                 vector<int64> random_ids) {
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return;
  }

  int64 media_album_id = 0;
  vector<MessageId> message_ids;
  for (auto &random_id : random_ids) {
    for (auto it = s->messages_.begin(); it != s->messages_.end(); ++it) {
      const auto *m = it->get();
      if (m->random_id == random_id && m->message_id.is_yet_unsent()) {
        CHECK(m->media_album_id != 0);
        CHECK(media_album_id == 0 || media_album_id == m->media_album_id);
        media_album_id = m->media_album_id;

        message_ids.push_back(m->message_id);
      }
    }
  }
  if (message_ids.empty()) {
    // all messages were deleted, nothing to do
    return;
  }

  auto &request = pending_message_group_sends_[media_album_id];
  CHECK(request.finished_count == 0);
  CHECK(request.is_finished.empty());
  CHECK(request.results.empty());
  request.message_ids = std::move(message_ids);
  request.is_finished.resize(request.message_ids.size());
  for (size_t i = 0; i < request.message_ids.size(); i++) {
    request.results.push_back(Status::OK());
  }

  for (auto message_id : request.message_ids) {
    do_send_message(get_message(s, message_id), {-1});
  }
}

int64 QuickReplyManager::generate_new_media_album_id() const {
  int64 media_album_id = 0;
  do {
    media_album_id = Random::secure_int64();
  } while (media_album_id >= 0 || pending_message_group_sends_.count(media_album_id) > 0);
  return media_album_id;
}

Result<td_api::object_ptr<td_api::quickReplyMessages>> QuickReplyManager::resend_messages(
    const string &shortcut_name, vector<MessageId> message_ids) {
  if (message_ids.empty()) {
    return Status::Error(400, "There are no messages to resend");
  }

  load_quick_reply_shortcuts();

  auto *s = get_shortcut(shortcut_name);
  if (s == nullptr) {
    return Status::Error(400, "Quick reply shortcut not found");
  }

  MessageId last_message_id;
  for (auto &message_id : message_ids) {
    const auto *m = get_message(s, message_id);
    if (m == nullptr) {
      return Status::Error(400, "Message not found");
    }
    if (!m->is_failed_to_send) {
      return Status::Error(400, "Message is not failed to send");
    }
    if (!can_resend_quick_reply_message(m)) {
      return Status::Error(400, "Message can't be re-sent");
    }
    if (m->try_resend_at > Time::now()) {
      return Status::Error(400, "Message can't be re-sent yet");
    }
    if (last_message_id != MessageId() && m->message_id <= last_message_id) {
      return Status::Error(400, "Message identifiers must be in a strictly increasing order");
    }
    last_message_id = m->message_id;
  }

  vector<unique_ptr<MessageContent>> new_contents(message_ids.size());
  std::unordered_map<int64, std::pair<int64, int32>, Hash<int64>> new_media_album_ids;
  for (size_t i = 0; i < message_ids.size(); i++) {
    MessageId message_id = message_ids[i];
    const auto *m = get_message(s, message_id);
    CHECK(m != nullptr);
    CHECK(m->edited_content == nullptr);

    unique_ptr<MessageContent> content =
        dup_message_content(td_, td_->dialog_manager_->get_my_dialog_id(), m->content.get(),
                            m->inline_query_id != 0 ? MessageContentDupType::SendViaBot : MessageContentDupType::Send,
                            MessageCopyOptions());
    if (content == nullptr) {
      LOG(INFO) << "Can't resend " << m->message_id;
      continue;
    }

    new_contents[i] = std::move(content);

    if (m->media_album_id != 0) {
      auto &new_media_album_id = new_media_album_ids[m->media_album_id];
      new_media_album_id.second++;
      if (new_media_album_id.second == 2) {  // have at least 2 messages in the new album
        CHECK(new_media_album_id.first == 0);
        new_media_album_id.first = generate_new_media_album_id();
      }
      if (new_media_album_id.second == MAX_GROUPED_MESSAGES + 1) {
        CHECK(new_media_album_id.first != 0);
        new_media_album_id.first = 0;  // just in case
      }
    }
  }

  bool is_changed = false;
  auto result = td_api::make_object<td_api::quickReplyMessages>();
  for (size_t i = 0; i < message_ids.size(); i++) {
    if (new_contents[i] == nullptr) {
      result->messages_.push_back(nullptr);
      continue;
    }

    auto *m = get_message_editable(s, message_ids[i]);
    CHECK(m != nullptr);
    unregister_message_content(m, "resend_message");
    m->message_id = get_next_yet_unsent_message_id(s);
    m->media_album_id = new_media_album_ids[m->media_album_id].first;
    m->is_failed_to_send = false;
    m->send_error_code = 0;
    m->send_error_message = string();
    m->try_resend_at = 0.0;
    register_message_content(m, "resend_message");

    do_send_message(m);

    result->messages_.push_back(get_quick_reply_message_object(m, "resend_message"));
    is_changed = true;
  }

  if (is_changed) {
    sort_quick_reply_messages(s->messages_);
    send_update_quick_reply_shortcut(s, "resend_message");
    send_update_quick_reply_shortcut_messages(s, "resend_message");
    save_quick_reply_shortcuts();
  }

  return std::move(result);
}

void QuickReplyManager::edit_quick_reply_message(
    QuickReplyShortcutId shortcut_id, MessageId message_id,
    td_api::object_ptr<td_api::InputMessageContent> &&input_message_content, Promise<Unit> &&promise) {
  load_quick_reply_shortcuts();
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return promise.set_error(Status::Error(400, "Shortcut not found"));
  }
  auto *m = get_message_editable(s, message_id);
  if (m == nullptr) {
    return promise.set_error(Status::Error(400, "Message not found"));
  }
  if (!can_edit_quick_reply_message(m)) {
    return promise.set_error(Status::Error(400, "Message can't be edited"));
  }

  TRY_RESULT_PROMISE(promise, message_content, process_input_message_content(std::move(input_message_content)));
  auto new_message_content_type = message_content.content->get_type();
  auto old_message_content_type = m->content->get_type();
  switch (old_message_content_type) {
    case MessageContentType::Text:
    case MessageContentType::Animation:
    case MessageContentType::Audio:
    case MessageContentType::Document:
    case MessageContentType::Photo:
    case MessageContentType::Video:
      if (new_message_content_type != MessageContentType::Animation &&
          new_message_content_type != MessageContentType::Audio &&
          new_message_content_type != MessageContentType::Document &&
          new_message_content_type != MessageContentType::Photo &&
          new_message_content_type != MessageContentType::Video &&
          (new_message_content_type != MessageContentType::Text ||
           old_message_content_type != MessageContentType::Text)) {
        return promise.set_error(Status::Error(400, "Message can't be edited to the specified message type"));
      }
      if (m->media_album_id != 0) {
        if (old_message_content_type != new_message_content_type) {
          if (!is_allowed_media_group_content(new_message_content_type)) {
            return promise.set_error(Status::Error(400, "Message content type can't be used in an album"));
          }
          if (is_homogenous_media_group_content(old_message_content_type) ||
              is_homogenous_media_group_content(new_message_content_type)) {
            return promise.set_error(Status::Error(400, "Can't change media type in the album"));
          }
        }
      }
      break;
    case MessageContentType::VoiceNote:
      if (new_message_content_type != MessageContentType::VoiceNote ||
          get_message_content_any_file_id(m->content.get()) !=
              get_message_content_any_file_id(message_content.content.get())) {
        return promise.set_error(Status::Error(400, "Only caption can be edited in voice note messages"));
      }
      break;
    default:
      UNREACHABLE();
  }

  auto old_file_ids = get_message_file_ids(m);
  m->edited_content = dup_message_content(td_, td_->dialog_manager_->get_my_dialog_id(), message_content.content.get(),
                                          MessageContentDupType::Send, MessageCopyOptions());
  CHECK(m->edited_content != nullptr);
  m->edited_invert_media = message_content.invert_media;
  m->edited_disable_web_page_preview = message_content.disable_web_page_preview;
  m->edit_generation = ++current_message_edit_generation_;

  change_message_files(m, old_file_ids);

  if (s->messages_[0]->message_id == message_id) {
    send_update_quick_reply_shortcut(s, "edit_quick_reply_message 1");
  }
  send_update_quick_reply_shortcut_messages(s, "edit_quick_reply_message 2");
  save_quick_reply_shortcuts();

  do_send_message(m);

  promise.set_value(Unit());
}

void QuickReplyManager::on_edit_quick_reply_message(QuickReplyShortcutId shortcut_id, MessageId message_id,
                                                    int64 edit_generation, FileUploadId file_upload_id,
                                                    bool was_uploaded,
                                                    telegram_api::object_ptr<telegram_api::Updates> updates_ptr) {
  auto *s = get_shortcut(shortcut_id);
  auto *m = get_message_editable(s, message_id);
  if (m == nullptr) {
    if (was_uploaded) {
      send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    }
    return;
  }
  if (m->edit_generation != edit_generation) {
    LOG(INFO) << "Ignore successful edit of " << QuickReplyMessageFullId(m->shortcut_id, m->message_id)
              << " with generation " << edit_generation << " instead of " << m->edit_generation;
    if (was_uploaded) {
      send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    }
    return;
  }
  CHECK(file_upload_id == m->edited_file_upload_id);
  LOG(INFO) << "Receive result for editing of " << QuickReplyMessageFullId(m->shortcut_id, m->message_id) << ": "
            << to_string(updates_ptr);

  bool was_updated = updates_ptr == nullptr;
  if (updates_ptr == nullptr || updates_ptr->get_id() != telegram_api::updates::ID) {
    if (was_uploaded) {
      send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    }
    reload_quick_reply_message(shortcut_id, message_id, Promise<Unit>());
  } else {
    auto updates = telegram_api::move_object_as<telegram_api::updates>(updates_ptr);
    td_->user_manager_->on_get_users(std::move(updates->users_), "on_edit_quick_reply_message");
    td_->chat_manager_->on_get_chats(std::move(updates->chats_), "on_edit_quick_reply_message");

    if (updates->updates_.size() != 1 || updates->updates_[0]->get_id() != telegram_api::updateQuickReplyMessage::ID) {
      LOG(ERROR) << "Receive " << to_string(updates);
      if (was_uploaded) {
        send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
      }
    } else {
      auto update_message = telegram_api::move_object_as<telegram_api::updateQuickReplyMessage>(updates->updates_[0]);
      auto message = create_message(std::move(update_message->message_), "on_edit_quick_reply_message");
      if (message == nullptr || message->shortcut_id != shortcut_id || message->message_id != message_id) {
        LOG(ERROR) << "Receive unexpected message";
        if (was_uploaded) {
          send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
        }
      } else {
        update_sent_message_content_from_temporary_message(m, message.get(), true);
        auto old_message_it = get_message_it(s, message_id);
        CHECK(old_message_it != s->messages_.end());
        update_quick_reply_message(*old_message_it, std::move(message));
        m = old_message_it->get();
        was_updated = true;
      }
    }
  }

  auto old_file_ids = get_message_file_ids(m);
  CHECK(m->edited_content != nullptr);
  if (!was_updated) {
    unregister_message_content(m, "on_edit_quick_reply_message");
    m->content = std::move(m->edited_content);
    m->invert_media = m->edited_invert_media;
    m->disable_web_page_preview = m->edited_disable_web_page_preview;
    register_message_content(m, "on_edit_quick_reply_message");
  }

  m->edit_generation = 0;
  m->edited_content = nullptr;
  m->edited_file_upload_id = {};
  m->edited_thumbnail_file_upload_id = {};
  m->edited_invert_media = false;
  m->edited_disable_web_page_preview = false;
  change_message_files(m, old_file_ids);

  if (s->messages_[0]->message_id == m->message_id) {
    send_update_quick_reply_shortcut(s, "on_edit_quick_reply_message 1");
  }
  send_update_quick_reply_shortcut_messages(s, "on_edit_quick_reply_message 2");
  save_quick_reply_shortcuts();
}

void QuickReplyManager::fail_edit_quick_reply_message(QuickReplyShortcutId shortcut_id, MessageId message_id,
                                                      int64 edit_generation, FileUploadId file_upload_id,
                                                      FileUploadId thumbnail_file_upload_id, FileId cover_file_id,
                                                      string file_reference, string cover_file_reference,
                                                      bool was_uploaded, bool was_thumbnail_uploaded, Status status) {
  auto *m = get_message_editable({shortcut_id, message_id});
  if (m == nullptr || m->edit_generation != edit_generation) {
    if (was_uploaded) {
      send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);
    }
    if (was_thumbnail_uploaded) {
      send_closure_later(G()->file_manager(), &FileManager::cancel_upload, thumbnail_file_upload_id);
    }
    return;
  }
  if (FileReferenceManager::is_file_reference_error(status)) {
    auto source = FileReferenceManager::get_file_reference_error_source(status);
    if (source.is_cover_) {
      if (cover_file_id.is_valid()) {
        VLOG(file_references) << "Receive " << status << " for cover " << cover_file_id;
        td_->file_manager_->delete_file_reference(cover_file_id, cover_file_reference);
        do_send_message(m, {-1});
        return;
      } else {
        LOG(ERROR) << "Receive file reference error, but cover_file_id = " << cover_file_id;
      }
    } else {
      if (file_upload_id.is_valid() && !was_uploaded) {
        VLOG(file_references) << "Receive " << status << " for " << file_upload_id;
        td_->file_manager_->delete_file_reference(file_upload_id.get_file_id(), file_reference);
        do_send_message(m, {-1});
        return;
      } else {
        LOG(ERROR) << "Receive file reference error, but file_id = " << file_upload_id
                   << ", was_uploaded = " << was_uploaded;
      }
    }
  }
  if (was_uploaded) {
    if (was_thumbnail_uploaded) {
      CHECK(thumbnail_file_upload_id.is_valid());
      // always delete partial remote location for the thumbnail, because it can't be reused anyway
      td_->file_manager_->delete_partial_remote_location(thumbnail_file_upload_id);
    }

    CHECK(file_upload_id.is_valid());
    auto bad_parts = FileManager::get_missing_file_parts(status);
    if (!bad_parts.empty()) {
      do_send_message(m, std::move(bad_parts));
      return;
    } else {
      td_->file_manager_->delete_partial_remote_location_if_needed(file_upload_id, status);
    }
  }

  auto old_file_ids = get_message_file_ids(m);
  m->edit_generation = 0;
  m->edited_content = nullptr;
  m->edited_file_upload_id = {};
  m->edited_thumbnail_file_upload_id = {};
  m->edited_invert_media = false;
  m->edited_disable_web_page_preview = false;
  change_message_files(m, old_file_ids);

  auto *s = get_shortcut(m->shortcut_id);
  CHECK(s != nullptr);
  if (s->messages_[0]->message_id == m->message_id) {
    send_update_quick_reply_shortcut(s, "fail_edit_quick_reply_message 1");
  }
  send_update_quick_reply_shortcut_messages(s, "fail_edit_quick_reply_message 2");
  save_quick_reply_shortcuts();
  reload_quick_reply_message(shortcut_id, message_id, Promise<Unit>());
}

void QuickReplyManager::get_quick_reply_shortcut_messages(QuickReplyShortcutId shortcut_id, Promise<Unit> &&promise) {
  load_quick_reply_shortcuts();
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return promise.set_error(Status::Error(400, "Shortcut not found"));
  }
  if (have_all_shortcut_messages(s)) {
    return promise.set_value(Unit());
  }

  CHECK(shortcut_id.is_server());
  reload_quick_reply_messages(shortcut_id, std::move(promise));
}

void QuickReplyManager::reload_quick_reply_messages(QuickReplyShortcutId shortcut_id, Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    return promise.set_error(Status::Error(400, "Not supported by bots"));
  }

  load_quick_reply_shortcuts();
  CHECK(shortcut_id.is_valid());
  if (!shortcut_id.is_server()) {
    return promise.set_value(Unit());
  }
  auto &queries = get_shortcut_messages_queries_[shortcut_id];
  queries.push_back(std::move(promise));
  if (queries.size() != 1) {
    return;
  }
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), shortcut_id](
                                 Result<telegram_api::object_ptr<telegram_api::messages_Messages>> r_messages) {
        send_closure(actor_id, &QuickReplyManager::on_reload_quick_reply_messages, shortcut_id, std::move(r_messages));
      });
  td_->create_handler<GetQuickReplyMessagesQuery>(std::move(query_promise))
      ->send(shortcut_id, vector<MessageId>(), get_quick_reply_messages_hash(get_shortcut(shortcut_id)));
}

void QuickReplyManager::on_reload_quick_reply_messages(
    QuickReplyShortcutId shortcut_id, Result<telegram_api::object_ptr<telegram_api::messages_Messages>> r_messages) {
  G()->ignore_result_if_closing(r_messages);
  auto queries_it = get_shortcut_messages_queries_.find(shortcut_id);
  CHECK(queries_it != get_shortcut_messages_queries_.end());
  CHECK(!queries_it->second.empty());
  auto promises = std::move(queries_it->second);
  get_shortcut_messages_queries_.erase(queries_it);
  if (r_messages.is_error()) {
    return fail_promises(promises, r_messages.move_as_error());
  }
  auto messages_ptr = r_messages.move_as_ok();
  switch (messages_ptr->get_id()) {
    case telegram_api::messages_messagesSlice::ID:
    case telegram_api::messages_channelMessages::ID:
      LOG(ERROR) << "Receive " << to_string(messages_ptr);
      break;
    case telegram_api::messages_messagesNotModified::ID:
      break;
    case telegram_api::messages_messages::ID: {
      auto messages = telegram_api::move_object_as<telegram_api::messages_messages>(messages_ptr);
      td_->user_manager_->on_get_users(std::move(messages->users_), "on_reload_quick_reply_messages");
      td_->chat_manager_->on_get_chats(std::move(messages->chats_), "on_reload_quick_reply_messages");

      vector<unique_ptr<QuickReplyMessage>> quick_reply_messages;
      for (auto &server_message : messages->messages_) {
        auto message = create_message(std::move(server_message), "on_reload_quick_reply_messages");
        if (message == nullptr) {
          continue;
        }
        if (message->shortcut_id != shortcut_id) {
          LOG(ERROR) << "Receive message from " << message->shortcut_id << " instead of " << shortcut_id;
          continue;
        }

        quick_reply_messages.push_back(std::move(message));
      }
      auto it = get_shortcut_it(shortcut_id);
      if (quick_reply_messages.empty()) {
        if (it != shortcuts_.shortcuts_.end()) {
          send_update_quick_reply_shortcut_deleted(it->get());
          shortcuts_.shortcuts_.erase(it);
          save_quick_reply_shortcuts();
          send_update_quick_reply_shortcuts();
        }
        break;
      }

      auto *old_shortcut = it != shortcuts_.shortcuts_.end() ? it->get() : nullptr;
      auto shortcut = td::make_unique<Shortcut>();
      shortcut->name_ = old_shortcut->name_;
      shortcut->shortcut_id_ = shortcut_id;
      shortcut->server_total_count_ = static_cast<int32>(quick_reply_messages.size());
      shortcut->messages_ = std::move(quick_reply_messages);

      if (old_shortcut == nullptr) {
        CHECK(have_all_shortcut_messages(shortcut.get()));
        send_update_quick_reply_shortcut(shortcut.get(), "on_reload_quick_reply_messages 1");
        send_update_quick_reply_shortcut_messages(shortcut.get(), "on_reload_quick_reply_messages 2");
        for (auto &message : shortcut->messages_) {
          register_new_message(message.get(), "on_reload_quick_reply_messages 5");
        }
        shortcuts_.shortcuts_.push_back(std::move(shortcut));
      } else {
        bool is_shortcut_changed = false;
        bool are_messages_changed = false;
        update_shortcut_from(shortcut.get(), old_shortcut, false, &is_shortcut_changed, &are_messages_changed);
        CHECK(have_all_shortcut_messages(shortcut.get()));
        if (is_shortcut_changed) {
          send_update_quick_reply_shortcut(shortcut.get(), "on_reload_quick_reply_messages 3");
        }
        if (are_messages_changed) {
          send_update_quick_reply_shortcut_messages(shortcut.get(), "on_reload_quick_reply_messages 4");
        }
        *it = std::move(shortcut);
      }

      save_quick_reply_shortcuts();
      break;
    }
    default:
      UNREACHABLE();
  }
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return fail_promises(promises, Status::Error(400, "Shortcut not found"));
  }
  set_promises(promises);
}

int64 QuickReplyManager::get_quick_reply_messages_hash(const Shortcut *s) {
  if (s == nullptr) {
    return 0;
  }
  vector<uint64> numbers;
  for (const auto &message : s->messages_) {
    if (message->message_id.is_server()) {
      numbers.push_back(message->message_id.get_server_message_id().get());
      numbers.push_back(message->edit_date);
    }
  }
  return get_vector_hash(numbers);
}

void QuickReplyManager::reload_quick_reply_message(QuickReplyShortcutId shortcut_id, MessageId message_id,
                                                   Promise<Unit> &&promise) {
  if (td_->auth_manager_->is_bot()) {
    return promise.set_error(Status::Error(400, "Not supported by bots"));
  }

  load_quick_reply_shortcuts();
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return promise.set_error(Status::Error(400, "Shortcut not found"));
  }
  if (!message_id.is_server()) {
    return promise.set_error(Status::Error(400, "Message can't be reloaded"));
  }
  auto query_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), shortcut_id, message_id, promise = std::move(promise)](
                                 Result<telegram_api::object_ptr<telegram_api::messages_Messages>> r_messages) mutable {
        send_closure(actor_id, &QuickReplyManager::on_reload_quick_reply_message, shortcut_id, message_id,
                     std::move(r_messages), std::move(promise));
      });
  td_->create_handler<GetQuickReplyMessagesQuery>(std::move(query_promise))
      ->send(shortcut_id, vector<MessageId>{message_id}, 0);
}

void QuickReplyManager::on_reload_quick_reply_message(
    QuickReplyShortcutId shortcut_id, MessageId message_id,
    Result<telegram_api::object_ptr<telegram_api::messages_Messages>> r_messages, Promise<Unit> &&promise) {
  G()->ignore_result_if_closing(r_messages);
  if (r_messages.is_error()) {
    return promise.set_error(r_messages.move_as_error());
  }
  auto *s = get_shortcut(shortcut_id);
  if (s == nullptr) {
    return promise.set_error(Status::Error(400, "Shortcut not found"));
  }
  auto messages_ptr = r_messages.move_as_ok();
  switch (messages_ptr->get_id()) {
    case telegram_api::messages_messagesSlice::ID:
    case telegram_api::messages_channelMessages::ID:
    case telegram_api::messages_messagesNotModified::ID:
      LOG(ERROR) << "Receive " << to_string(messages_ptr);
      return promise.set_error(Status::Error(400, "Receive wrong response"));
    case telegram_api::messages_messages::ID: {
      auto messages = telegram_api::move_object_as<telegram_api::messages_messages>(messages_ptr);
      td_->user_manager_->on_get_users(std::move(messages->users_), "on_reload_quick_reply_message");
      td_->chat_manager_->on_get_chats(std::move(messages->chats_), "on_reload_quick_reply_message");

      if (messages->messages_.size() > 1u) {
        LOG(ERROR) << "Receive " << to_string(messages_ptr);
        break;
      }
      unique_ptr<QuickReplyMessage> message;
      if (messages->messages_.size() == 1u) {
        message = create_message(std::move(messages->messages_[0]), "on_reload_quick_reply_message");
      }
      if (message == nullptr) {
        delete_quick_reply_messages(s, {message_id}, "on_reload_quick_reply_message");
        return promise.set_error(Status::Error(400, "Message not found"));
      }
      if (message->shortcut_id != shortcut_id) {
        LOG(ERROR) << "Receive message from " << message->shortcut_id << " instead of " << shortcut_id;
        return promise.set_error(Status::Error(400, "Message not found"));
      }
      on_get_quick_reply_message(s, std::move(message));
      break;
    }
    default:
      UNREACHABLE();
  }
  promise.set_value(Unit());
}

Result<vector<QuickReplyManager::QuickReplyMessageContent>> QuickReplyManager::get_quick_reply_message_contents(
    DialogId dialog_id, QuickReplyShortcutId shortcut_id) const {
  const auto *shortcut = get_shortcut(shortcut_id);
  if (shortcut == nullptr) {
    return Status::Error(400, "Shortcut not found");
  }
  if (!shortcut_id.is_server()) {
    return Status::Error(400, "Shortcut isn't created yet");
  }
  if (!have_all_shortcut_messages(shortcut)) {
    return Status::Error(400, "Shortcut messages aren't loaded yet");
  }

  TRY_STATUS(td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write,
                                                       "get_quick_reply_message_contents"));
  if (dialog_id.get_type() != DialogType::User || td_->user_manager_->is_user_bot(dialog_id.get_user_id())) {
    return Status::Error(400, "Can't use quick replies in the chat");
  }

  vector<QuickReplyMessageContent> result;
  for (const auto &message : shortcut->messages_) {
    if (!message->message_id.is_server()) {
      continue;
    }
    auto content = dup_message_content(td_, dialog_id, message->content.get(), MessageContentDupType::ServerCopy,
                                       MessageCopyOptions(true, false));

    auto can_send_status = can_send_message_content(dialog_id, content.get(), false, true, td_);
    if (can_send_status.is_error()) {
      LOG(INFO) << "Can't send " << message->message_id << ": " << can_send_status.message();
      // if we skip the message, the sending will fail anyway with MESSAGE_IDS_MISMATCH
      // continue;
    }

    auto disable_web_page_preview = message->disable_web_page_preview &&
                                    content->get_type() == MessageContentType::Text &&
                                    !has_message_content_web_page(content.get());
    result.push_back({std::move(content), message->message_id, message->reply_to_message_id,
                      dup_reply_markup(message->reply_markup),
                      message->hide_via_bot ? UserId() : message->via_bot_user_id, message->media_album_id,
                      message->invert_media, disable_web_page_preview});
  }

  return std::move(result);
}

QuickReplyManager::Shortcut *QuickReplyManager::get_shortcut(QuickReplyShortcutId shortcut_id) {
  if (!shortcuts_.are_inited_) {
    return nullptr;
  }
  for (auto &shortcut : shortcuts_.shortcuts_) {
    if (shortcut->shortcut_id_ == shortcut_id) {
      return shortcut.get();
    }
  }
  if (shortcut_id.is_local()) {
    auto it = persistent_shortcut_ids_.find(shortcut_id);
    if (it != persistent_shortcut_ids_.end()) {
      return get_shortcut(it->second);
    }
  }
  return nullptr;
}

const QuickReplyManager::Shortcut *QuickReplyManager::get_shortcut(QuickReplyShortcutId shortcut_id) const {
  if (!shortcuts_.are_inited_) {
    return nullptr;
  }
  for (auto &shortcut : shortcuts_.shortcuts_) {
    if (shortcut->shortcut_id_ == shortcut_id) {
      return shortcut.get();
    }
  }
  if (shortcut_id.is_local()) {
    auto it = persistent_shortcut_ids_.find(shortcut_id);
    if (it != persistent_shortcut_ids_.end()) {
      return get_shortcut(it->second);
    }
  }
  return nullptr;
}

QuickReplyManager::Shortcut *QuickReplyManager::get_shortcut(const string &name) {
  if (!shortcuts_.are_inited_) {
    return nullptr;
  }
  for (auto &shortcut : shortcuts_.shortcuts_) {
    if (shortcut->name_ == name) {
      return shortcut.get();
    }
  }
  return nullptr;
}

vector<unique_ptr<QuickReplyManager::Shortcut>>::iterator QuickReplyManager::get_shortcut_it(
    QuickReplyShortcutId shortcut_id) {
  for (auto it = shortcuts_.shortcuts_.begin(); it != shortcuts_.shortcuts_.end(); ++it) {
    if (*it != nullptr && (*it)->shortcut_id_ == shortcut_id) {
      return it;
    }
  }
  if (shortcut_id.is_local()) {
    auto it = persistent_shortcut_ids_.find(shortcut_id);
    if (it != persistent_shortcut_ids_.end()) {
      return get_shortcut_it(it->second);
    }
  }
  return shortcuts_.shortcuts_.end();
}

vector<unique_ptr<QuickReplyManager::QuickReplyMessage>>::iterator QuickReplyManager::get_message_it(
    Shortcut *s, MessageId message_id) {
  CHECK(s != nullptr);
  for (auto it = s->messages_.begin(); it != s->messages_.end(); ++it) {
    if ((*it)->message_id == message_id) {
      return it;
    }
  }
  return s->messages_.end();
}

const QuickReplyManager::QuickReplyMessage *QuickReplyManager::get_message(
    QuickReplyMessageFullId message_full_id) const {
  const auto *s = get_shortcut(message_full_id.get_quick_reply_shortcut_id());
  return get_message(s, message_full_id.get_message_id());
}

const QuickReplyManager::QuickReplyMessage *QuickReplyManager::get_message(const Shortcut *s,
                                                                           MessageId message_id) const {
  if (s != nullptr) {
    for (auto it = s->messages_.begin(); it != s->messages_.end(); ++it) {
      if ((*it)->message_id == message_id) {
        return it->get();
      }
    }
  }
  return nullptr;
}

QuickReplyManager::QuickReplyMessage *QuickReplyManager::get_message_editable(QuickReplyMessageFullId message_full_id) {
  auto *s = get_shortcut(message_full_id.get_quick_reply_shortcut_id());
  return get_message_editable(s, message_full_id.get_message_id());
}

QuickReplyManager::QuickReplyMessage *QuickReplyManager::get_message_editable(Shortcut *s, MessageId message_id) {
  if (s != nullptr) {
    for (auto it = s->messages_.begin(); it != s->messages_.end(); ++it) {
      if ((*it)->message_id == message_id) {
        return it->get();
      }
    }
  }
  return nullptr;
}

Result<QuickReplyManager::Shortcut *> QuickReplyManager::create_new_local_shortcut(const string &name,
                                                                                   int32 new_message_count) {
  TRY_STATUS(check_shortcut_name(name));

  load_quick_reply_shortcuts();
  if (!shortcuts_.are_inited_) {
    return Status::Error(400, "Quick reply shortcuts must be loaded first");
  }

  auto *s = get_shortcut(name);
  auto max_message_count = td_->option_manager_->get_option_integer("quick_reply_shortcut_message_count_max");
  if (s != nullptr) {
    if (!have_all_shortcut_messages(s)) {
      return Status::Error(400, "The quick reply shortcut must be loaded first");
    }
    max_message_count -= s->server_total_count_ + s->local_total_count_;
  } else {
    auto max_shortcut_count = td_->option_manager_->get_option_integer("quick_reply_shortcut_count_max");
    if (static_cast<int64>(shortcuts_.shortcuts_.size()) >= max_shortcut_count) {
      return Status::Error(400, "Quick reply shortcut count exceeded");
    }
  }
  if (new_message_count > max_message_count) {
    return Status::Error(400, "Quick reply message count exceeded");
  }
  if (s != nullptr) {
    return s;
  }
  if (next_local_shortcut_id_ >= std::numeric_limits<int32>::max() - 10) {
    return Status::Error(400, "Too many local shortcuts created");
  }

  auto shortcut = td::make_unique<Shortcut>();
  shortcut->name_ = name;
  shortcut->shortcut_id_ = QuickReplyShortcutId(next_local_shortcut_id_++);
  s = shortcut.get();

  shortcuts_.shortcuts_.push_back(std::move(shortcut));

  return s;
}

MessageId QuickReplyManager::get_input_reply_to_message_id(const Shortcut *s, MessageId reply_to_message_id) {
  if (s == nullptr || !reply_to_message_id.is_valid() || !reply_to_message_id.is_server()) {
    return MessageId();
  }
  for (const auto &message : s->messages_) {
    CHECK(message != nullptr);
    if (message->message_id == reply_to_message_id) {
      return reply_to_message_id;
    }
  }
  return MessageId();
}

Result<InputMessageContent> QuickReplyManager::process_input_message_content(
    td_api::object_ptr<td_api::InputMessageContent> &&input_message_content) {
  if (input_message_content == nullptr) {
    return Status::Error(400, "Can't add quick reply without content");
  }
  auto message_content_id = input_message_content->get_id();
  if (message_content_id == td_api::inputMessageForwarded::ID) {
    return Status::Error(400, "Can't forward messages to quick replies");
  }
  if (message_content_id == td_api::inputMessagePoll::ID) {
    return Status::Error(400, "Can't add poll as a quick reply");
  }
  if (message_content_id == td_api::inputMessagePaidMedia::ID) {
    return Status::Error(400, "Can't add paid media as a quick reply");
  }
  if (message_content_id == td_api::inputMessageLocation::ID &&
      static_cast<const td_api::inputMessageLocation *>(input_message_content.get())->live_period_ != 0) {
    return Status::Error(400, "Can't add live location as a quick reply");
  }
  return get_input_message_content(DialogId(), std::move(input_message_content), td_, true);
}

MessageId QuickReplyManager::get_next_message_id(Shortcut *s, MessageType type) const {
  CHECK(s != nullptr);
  MessageId last_message_id = s->last_assigned_message_id_;
  if (!s->messages_.empty() && s->messages_.back() != nullptr && s->messages_.back()->message_id > last_message_id) {
    last_message_id = s->messages_.back()->message_id;
  }
  s->last_assigned_message_id_ = last_message_id.get_next_message_id(type);
  CHECK(s->last_assigned_message_id_.is_valid());
  return s->last_assigned_message_id_;
}

MessageId QuickReplyManager::get_next_yet_unsent_message_id(Shortcut *s) const {
  return get_next_message_id(s, MessageType::YetUnsent);
}

MessageId QuickReplyManager::get_next_local_message_id(Shortcut *s) const {
  return get_next_message_id(s, MessageType::Local);
}

QuickReplyManager::QuickReplyMessage *QuickReplyManager::add_local_message(
    Shortcut *s, MessageId reply_to_message_id, unique_ptr<MessageContent> &&content, bool invert_media,
    UserId via_bot_user_id, bool hide_via_bot, bool disable_web_page_preview, string &&send_emoji) {
  CHECK(s != nullptr);
  auto message = make_unique<QuickReplyMessage>();
  auto *m = message.get();
  m->shortcut_id = s->shortcut_id_;
  m->message_id = get_next_yet_unsent_message_id(s);
  m->reply_to_message_id = reply_to_message_id;
  m->send_emoji = std::move(send_emoji);
  m->via_bot_user_id = via_bot_user_id;
  m->hide_via_bot = hide_via_bot;
  m->invert_media = invert_media;
  m->disable_web_page_preview = disable_web_page_preview;
  m->content = std::move(content);
  do {
    m->random_id = Random::secure_int64();
  } while (m->random_id == 0);

  register_new_message(m, "add_local_quick_reply_message");

  s->messages_.push_back(std::move(message));
  s->local_total_count_++;

  return m;
}

vector<QuickReplyShortcutId> QuickReplyManager::get_shortcut_ids() const {
  return transform(shortcuts_.shortcuts_, [](const unique_ptr<Shortcut> &shortcut) { return shortcut->shortcut_id_; });
}

vector<QuickReplyShortcutId> QuickReplyManager::get_server_shortcut_ids() const {
  vector<QuickReplyShortcutId> shortcut_ids;
  for (auto &shortcut : shortcuts_.shortcuts_) {
    if (shortcut->shortcut_id_.is_server()) {
      shortcut_ids.push_back(shortcut->shortcut_id_);
    }
  }
  return shortcut_ids;
}

void QuickReplyManager::sort_quick_reply_messages(vector<unique_ptr<QuickReplyMessage>> &messages) {
  std::sort(messages.begin(), messages.end(),
            [](const unique_ptr<QuickReplyMessage> &lhs, const unique_ptr<QuickReplyMessage> &rhs) {
              return lhs->message_id < rhs->message_id;
            });
}

QuickReplyManager::QuickReplyMessageUniqueId QuickReplyManager::get_quick_reply_unique_id(const QuickReplyMessage *m) {
  return QuickReplyMessageUniqueId(m->message_id, m->edit_date);
}

vector<QuickReplyManager::QuickReplyMessageUniqueId> QuickReplyManager::get_quick_reply_unique_ids(
    const vector<unique_ptr<QuickReplyMessage>> &messages) {
  return transform(
      messages, [](const unique_ptr<QuickReplyMessage> &message) { return get_quick_reply_unique_id(message.get()); });
}

vector<QuickReplyManager::QuickReplyMessageUniqueId> QuickReplyManager::get_server_quick_reply_unique_ids(
    const vector<unique_ptr<QuickReplyMessage>> &messages) {
  auto message_ids = get_quick_reply_unique_ids(messages);
  td::remove_if(message_ids, [](const QuickReplyMessageUniqueId &message_id) { return !message_id.first.is_server(); });
  return message_ids;
}

void QuickReplyManager::update_shortcut_from(Shortcut *new_shortcut, Shortcut *old_shortcut, bool is_partial,
                                             bool *is_shortcut_changed, bool *are_messages_changed) {
  CHECK(old_shortcut != nullptr);
  CHECK(new_shortcut != nullptr);
  CHECK(old_shortcut->shortcut_id_.is_server());
  CHECK(old_shortcut->shortcut_id_ == new_shortcut->shortcut_id_);
  CHECK(!old_shortcut->messages_.empty());
  CHECK(!new_shortcut->messages_.empty());
  auto old_unique_id = get_quick_reply_unique_id(old_shortcut->messages_[0].get());
  auto old_message_count = get_shortcut_message_count(old_shortcut);
  if (is_partial) {
    // only the first server message is known
    // delete all definitely deleted server messages and insert the new message in the correct place
    auto old_message_ids = get_quick_reply_unique_ids(old_shortcut->messages_);
    auto new_first_message_id = new_shortcut->messages_[0]->message_id;
    auto it = old_shortcut->messages_.begin();
    while (it != old_shortcut->messages_.end() && (*it)->message_id < new_first_message_id) {
      if ((*it)->message_id.is_server()) {
        delete_message_files(it->get());
        it = old_shortcut->messages_.erase(it);
      } else {
        ++it;
      }
    }
    if (it == old_shortcut->messages_.end() || (*it)->message_id != new_first_message_id) {
      register_new_message(new_shortcut->messages_[0].get(), "update_shortcut_from");
      old_shortcut->messages_.insert(it, std::move(new_shortcut->messages_[0]));
    } else {
      update_quick_reply_message(*it, std::move(new_shortcut->messages_[0]));
    }
    new_shortcut->messages_ = std::move(old_shortcut->messages_);
    *are_messages_changed = (old_message_ids != get_quick_reply_unique_ids(new_shortcut->messages_));

    int32 server_total_count = 0;
    for (const auto &message : new_shortcut->messages_) {
      if (message->message_id.is_server()) {
        server_total_count++;
      }
    }
    if (server_total_count > new_shortcut->server_total_count_) {
      new_shortcut->server_total_count_ = server_total_count;
    }
  } else {
    auto old_server_message_ids = get_server_quick_reply_unique_ids(old_shortcut->messages_);
    auto new_server_message_ids = get_server_quick_reply_unique_ids(new_shortcut->messages_);
    CHECK(static_cast<size_t>(new_shortcut->server_total_count_) == new_server_message_ids.size());
    if (old_server_message_ids == new_server_message_ids) {
      *are_messages_changed = false;
      new_shortcut->messages_ = std::move(old_shortcut->messages_);
    } else {
      *are_messages_changed = true;
      for (auto &old_message : old_shortcut->messages_) {
        CHECK(old_message != nullptr);
        if (!old_message->message_id.is_server()) {
          new_shortcut->messages_.push_back(std::move(old_message));
        } else {
          bool is_deleted = true;
          for (auto &new_message : new_shortcut->messages_) {
            if (new_message->message_id == old_message->message_id) {
              update_quick_reply_message(old_message, std::move(new_message));
              new_message = std::move(old_message);
              is_deleted = false;
              break;
            }
          }
          if (is_deleted) {
            delete_message_files(old_message.get());
          }
        }
      }
      sort_quick_reply_messages(new_shortcut->messages_);
    }
  }
  new_shortcut->local_total_count_ = old_shortcut->local_total_count_;
  *is_shortcut_changed = old_unique_id != get_quick_reply_unique_id(new_shortcut->messages_[0].get()) ||
                         new_shortcut->name_ != old_shortcut->name_ ||
                         old_message_count != get_shortcut_message_count(new_shortcut);
}

string QuickReplyManager::get_quick_reply_shortcuts_database_key() {
  return "quick_reply_shortcuts";
}

void QuickReplyManager::save_quick_reply_shortcuts() {
  CHECK(shortcuts_.are_inited_);
  LOG(INFO) << "Save quick reply shortcuts";
  G()->td_db()->get_binlog_pmc()->set(get_quick_reply_shortcuts_database_key(),
                                      log_event_store(shortcuts_).as_slice().str());
}

void QuickReplyManager::load_quick_reply_shortcuts() {
  CHECK(!td_->auth_manager_->is_bot());
  if (shortcuts_.are_loaded_from_database_) {
    return;
  }
  shortcuts_.are_loaded_from_database_ = true;
  CHECK(shortcuts_.load_queries_.empty());

  auto shortcuts_str = G()->td_db()->get_binlog_pmc()->get(get_quick_reply_shortcuts_database_key());
  if (shortcuts_str.empty()) {
    return reload_quick_reply_shortcuts();
  }
  auto status = log_event_parse(shortcuts_, shortcuts_str);
  if (status.is_error()) {
    LOG(ERROR) << "Can't load quick replies: " << status;
    G()->td_db()->get_binlog_pmc()->erase(get_quick_reply_shortcuts_database_key());
    shortcuts_.shortcuts_.clear();
    return reload_quick_reply_shortcuts();
  }

  Dependencies dependencies;
  for (const auto &shortcut : shortcuts_.shortcuts_) {
    for (const auto &message : shortcut->messages_) {
      add_quick_reply_message_dependencies(dependencies, message.get());
    }
  }
  if (!dependencies.resolve_force(td_, "load_quick_reply_shortcuts")) {
    shortcuts_.shortcuts_.clear();
    return reload_quick_reply_shortcuts();
  }

  shortcuts_.are_inited_ = true;
  for (auto &shortcut : shortcuts_.shortcuts_) {
    if (shortcut->shortcut_id_.get() >= next_local_shortcut_id_) {
      next_local_shortcut_id_ = shortcut->shortcut_id_.get() + 1;
    }
    for (auto &message : shortcut->messages_) {
      if (message->shortcut_id != shortcut->shortcut_id_) {
        LOG(ERROR) << "Receive quick reply " << message->message_id << " in " << message->shortcut_id << " instead of "
                   << shortcut->shortcut_id_;
        message->shortcut_id = shortcut->shortcut_id_;
      }
      register_new_message(message.get(), "load_quick_reply_shortcuts");

      if (message->message_id.is_server()) {
        if (need_reget_message_content(message->content.get()) ||
            (message->legacy_layer != 0 && message->legacy_layer < MTPROTO_LAYER)) {
          reload_quick_reply_message(shortcut->shortcut_id_, message->message_id, Promise<Unit>());
        }
        if (message->edited_content != nullptr) {
          message->edit_generation = ++current_message_edit_generation_;
          do_send_message(message.get());
        }
      } else if (message->message_id.is_yet_unsent()) {
        do_send_message(message.get());
      }
    }
    send_update_quick_reply_shortcut(shortcut.get(), "load_quick_reply_shortcuts");
    send_update_quick_reply_shortcut_messages(shortcut.get(), "load_quick_reply_shortcuts");
  }

  send_update_quick_reply_shortcuts();

  reload_quick_reply_shortcuts();
}

td_api::object_ptr<td_api::updateQuickReplyShortcut> QuickReplyManager::get_update_quick_reply_shortcut_object(
    const Shortcut *s, const char *source) const {
  return td_api::make_object<td_api::updateQuickReplyShortcut>(get_quick_reply_shortcut_object(s, source));
}

void QuickReplyManager::send_update_quick_reply_shortcut(const Shortcut *s, const char *source) {
  send_closure(G()->td(), &Td::send_update, get_update_quick_reply_shortcut_object(s, source));
}

td_api::object_ptr<td_api::updateQuickReplyShortcutDeleted>
QuickReplyManager::get_update_quick_reply_shortcut_deleted_object(const Shortcut *s) const {
  CHECK(s != nullptr);
  return td_api::make_object<td_api::updateQuickReplyShortcutDeleted>(s->shortcut_id_.get());
}

void QuickReplyManager::send_update_quick_reply_shortcut_deleted(const Shortcut *s) {
  send_closure(G()->td(), &Td::send_update, get_update_quick_reply_shortcut_deleted_object(s));
}

td_api::object_ptr<td_api::updateQuickReplyShortcuts> QuickReplyManager::get_update_quick_reply_shortcuts_object()
    const {
  CHECK(shortcuts_.are_inited_);
  return td_api::make_object<td_api::updateQuickReplyShortcuts>(transform(
      shortcuts_.shortcuts_, [](const unique_ptr<Shortcut> &shortcut) { return shortcut->shortcut_id_.get(); }));
}

void QuickReplyManager::send_update_quick_reply_shortcuts() {
  send_closure(G()->td(), &Td::send_update, get_update_quick_reply_shortcuts_object());
}

td_api::object_ptr<td_api::updateQuickReplyShortcutMessages>
QuickReplyManager::get_update_quick_reply_shortcut_messages_object(const Shortcut *s, const char *source) const {
  CHECK(s != nullptr);
  auto messages = transform(s->messages_, [this, source](const unique_ptr<QuickReplyMessage> &message) {
    return get_quick_reply_message_object(message.get(), source);
  });
  return td_api::make_object<td_api::updateQuickReplyShortcutMessages>(s->shortcut_id_.get(), std::move(messages));
}

void QuickReplyManager::send_update_quick_reply_shortcut_messages(const Shortcut *s, const char *source) {
  if (have_all_shortcut_messages(s)) {
    send_closure(G()->td(), &Td::send_update, get_update_quick_reply_shortcut_messages_object(s, source));
  }
}

vector<FileId> QuickReplyManager::get_message_file_ids(const QuickReplyMessage *m) const {
  if (m == nullptr) {
    return {};
  }
  if (m->edited_content != nullptr) {
    auto file_ids = get_message_content_file_ids(m->edited_content.get(), td_);
    if (!file_ids.empty()) {
      for (auto file_id : get_message_content_file_ids(m->content.get(), td_)) {
        if (!td::contains(file_ids, file_id)) {
          file_ids.push_back(file_id);
        }
      }
    }
    return file_ids;
  }
  return get_message_content_file_ids(m->content.get(), td_);
}

void QuickReplyManager::delete_message_files(const QuickReplyMessage *m) const {
  CHECK(m != nullptr);
  unregister_message_content(m, "delete_message_files");
  auto file_ids = get_message_file_ids(m);
  if (file_ids.empty()) {
    return;
  }
  for (auto file_id : file_ids) {
    send_closure(G()->file_manager(), &FileManager::delete_file, file_id, Promise<Unit>(), "delete_message_files");
  }
  auto it = message_full_id_to_file_source_id_.find({m->shortcut_id, m->message_id});
  if (it != message_full_id_to_file_source_id_.end()) {
    td_->file_manager_->change_files_source(it->second, file_ids, {}, "delete_message_files");
  }
}

void QuickReplyManager::change_message_files(const QuickReplyMessage *m, const vector<FileId> &old_file_ids) {
  CHECK(m != nullptr);
  auto new_file_ids = get_message_file_ids(m);
  if (new_file_ids == old_file_ids) {
    return;
  }

  QuickReplyMessageFullId message_full_id(m->shortcut_id, m->message_id);
  LOG(INFO) << "Change files of " << message_full_id << " from " << old_file_ids << " to " << new_file_ids;
  for (auto file_id : old_file_ids) {
    if (!td::contains(new_file_ids, file_id)) {
      send_closure(G()->file_manager(), &FileManager::delete_file, file_id, Promise<Unit>(), "change_message_files");
    }
  }

  auto file_source_id = get_quick_reply_message_file_source_id(message_full_id);
  if (file_source_id.is_valid()) {
    td_->file_manager_->change_files_source(file_source_id, old_file_ids, new_file_ids, "change_message_files");
  }
}

void QuickReplyManager::register_new_message(const QuickReplyMessage *m, const char *source) {
  change_message_files(m, {});
  register_message_content(m, source);
}

void QuickReplyManager::register_message_content(const QuickReplyMessage *m, const char *source) const {
  register_quick_reply_message_content(td_, m->content.get(), {m->shortcut_id, m->message_id}, source);
}

void QuickReplyManager::unregister_message_content(const QuickReplyMessage *m, const char *source) const {
  unregister_quick_reply_message_content(td_, m->content.get(), {m->shortcut_id, m->message_id}, source);
}

FileSourceId QuickReplyManager::get_quick_reply_message_file_source_id(QuickReplyMessageFullId message_full_id) {
  if (td_->auth_manager_->is_bot()) {
    return FileSourceId();
  }
  if (!message_full_id.is_server()) {
    return FileSourceId();
  }

  auto &file_source_id = message_full_id_to_file_source_id_[message_full_id];
  if (!file_source_id.is_valid()) {
    file_source_id = td_->file_reference_manager_->create_quick_reply_message_file_source(message_full_id);
  }
  return file_source_id;
}

void QuickReplyManager::get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }

  if (shortcuts_.are_inited_) {
    for (auto &shortcut : shortcuts_.shortcuts_) {
      updates.push_back(get_update_quick_reply_shortcut_object(shortcut.get(), "get_current_state"));
      if (have_all_shortcut_messages(shortcut.get())) {
        updates.push_back(get_update_quick_reply_shortcut_messages_object(shortcut.get(), "get_current_state"));
      }
    }

    updates.push_back(get_update_quick_reply_shortcuts_object());
  }
}

}  // namespace td
