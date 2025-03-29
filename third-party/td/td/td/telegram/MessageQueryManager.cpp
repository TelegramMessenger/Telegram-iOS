//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageQueryManager.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/AuthManager.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/DialogParticipantManager.h"
#include "td/telegram/FactCheck.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/Global.h"
#include "td/telegram/HashtagHints.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/MessageContent.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageReaction.h"
#include "td/telegram/MessageSearchOffset.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/MessagesInfo.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/PublicDialogType.h"
#include "td/telegram/SecretChatsManager.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UpdatesManager.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"
#include "td/telegram/Version.h"

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogHelper.h"

#include "td/actor/MultiPromise.h"
#include "td/actor/SleepActor.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

#include <limits>
#include <map>
#include <type_traits>

namespace td {

class UploadCoverQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  BusinessConnectionId business_connection_id_;
  DialogId dialog_id_;
  Photo photo_;
  FileUploadId file_upload_id_;
  bool was_uploaded_ = false;

 public:
  explicit UploadCoverQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(BusinessConnectionId business_connection_id, DialogId dialog_id, Photo &&photo, FileUploadId file_upload_id,
            telegram_api::object_ptr<telegram_api::InputMedia> &&input_media) {
    CHECK(input_media != nullptr);
    business_connection_id_ = business_connection_id;
    dialog_id_ = dialog_id;
    photo_ = std::move(photo);
    file_upload_id_ = file_upload_id;
    was_uploaded_ = FileManager::extract_was_uploaded(input_media);

    if (was_uploaded_ && false) {
      return on_error(Status::Error(400, "FILE_PART_1_MISSING"));
    }

    auto input_peer = td_->dialog_manager_->get_input_peer(
        dialog_id, business_connection_id_.is_valid() ? AccessRights::Know : AccessRights::Write);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Have no access to the chat"));
    }

    int32 flags = 0;
    if (business_connection_id_.is_valid()) {
      flags |= telegram_api::messages_uploadMedia::BUSINESS_CONNECTION_ID_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_uploadMedia(
        flags, business_connection_id_.get(), std::move(input_peer), std::move(input_media))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_uploadMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for UploadCoverQuery: " << to_string(ptr);
    td_->message_query_manager_->complete_upload_message_cover(business_connection_id_, dialog_id_, std::move(photo_),
                                                               file_upload_id_, std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    LOG(INFO) << "Receive error for UploadCoverQuery: " << status;

    if (was_uploaded_) {
      auto bad_parts = FileManager::get_missing_file_parts(status);
      if (!bad_parts.empty()) {
        td_->message_query_manager_->upload_message_cover(business_connection_id_, dialog_id_, std::move(photo_),
                                                          file_upload_id_, std::move(promise_), std::move(bad_parts));
        return;
      } else {
        td_->file_manager_->delete_partial_remote_location_if_needed(file_upload_id_, status);
      }
    }
    promise_.set_error(std::move(status));
  }
};

class ReportMessageDeliveryQuery final : public Td::ResultHandler {
  DialogId dialog_id_;

 public:
  void send(MessageFullId message_full_id, bool from_push) {
    dialog_id_ = message_full_id.get_dialog_id();
    auto input_peer = td_->dialog_manager_->get_input_peer(message_full_id.get_dialog_id(), AccessRights::Read);
    if (input_peer == nullptr) {
      return;
    }
    int32 flags = 0;
    if (from_push) {
      flags |= telegram_api::messages_reportMessagesDelivery::PUSH_MASK;
    }
    auto message_id = message_full_id.get_message_id();
    CHECK(message_id.is_valid());
    CHECK(message_id.is_server());
    send_query(G()->net_query_creator().create(telegram_api::messages_reportMessagesDelivery(
        flags, false /*ignored*/, std::move(input_peer), {message_id.get_server_message_id().get()})));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_reportMessagesDelivery>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    // ok
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReportMessageDeliveryQuery");
  }
};

class GetExtendedMediaQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  vector<MessageId> message_ids_;

 public:
  void send(DialogId dialog_id, vector<MessageId> &&message_ids) {
    dialog_id_ = dialog_id;
    message_ids_ = std::move(message_ids);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_getExtendedMedia(
        std::move(input_peer), MessageId::get_server_message_ids(message_ids_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getExtendedMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetExtendedMediaQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), Promise<Unit>());
    td_->message_query_manager_->finish_get_message_extended_media(dialog_id_, message_ids_);
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetExtendedMediaQuery");
    td_->message_query_manager_->finish_get_message_extended_media(dialog_id_, message_ids_);
  }
};

class GetFactCheckQuery final : public Td::ResultHandler {
  Promise<vector<telegram_api::object_ptr<telegram_api::factCheck>>> promise_;
  DialogId dialog_id_;

 public:
  explicit GetFactCheckQuery(Promise<vector<telegram_api::object_ptr<telegram_api::factCheck>>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, const vector<MessageId> &message_ids) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return promise_.set_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_getFactCheck(std::move(input_peer), MessageId::get_server_message_ids(message_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getFactCheck>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetFactCheckQuery: " << to_string(ptr);
    promise_.set_value(std::move(ptr));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetFactCheckQuery");
    promise_.set_error(std::move(status));
  }
};

class EditMessageFactCheckQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;

 public:
  explicit EditMessageFactCheckQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId message_id, const FormattedText &text) {
    dialog_id_ = dialog_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    CHECK(message_id.is_valid());
    CHECK(message_id.is_server());
    auto server_message_id = message_id.get_server_message_id().get();
    if (text.text.empty()) {
      send_query(G()->net_query_creator().create(
          telegram_api::messages_deleteFactCheck(std::move(input_peer), server_message_id)));
    } else {
      send_query(G()->net_query_creator().create(telegram_api::messages_editFactCheck(
          std::move(input_peer), server_message_id,
          get_input_text_with_entities(td_->user_manager_.get(), text, "messages_editFactCheck"))));
    }
  }

  void on_result(BufferSlice packet) final {
    static_assert(std::is_same<telegram_api::messages_deleteFactCheck::ReturnType,
                               telegram_api::messages_editFactCheck::ReturnType>::value,
                  "");
    auto result_ptr = fetch_result<telegram_api::messages_editFactCheck>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for EditMessageFactCheckQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "EditMessageFactCheckQuery");
    promise_.set_error(std::move(status));
  }
};

class SearchMessagesGlobalQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::foundMessages>> promise_;
  string query_;
  int32 offset_date_;
  DialogId offset_dialog_id_;
  MessageId offset_message_id_;
  int32 limit_;
  MessageSearchFilter filter_;
  int32 min_date_;
  int32 max_date_;

 public:
  explicit SearchMessagesGlobalQuery(Promise<td_api::object_ptr<td_api::foundMessages>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(FolderId folder_id, bool ignore_folder_id, const string &query, int32 offset_date,
            DialogId offset_dialog_id, MessageId offset_message_id, int32 limit, MessageSearchFilter filter,
            const td_api::object_ptr<td_api::SearchMessagesChatTypeFilter> &dialog_type_filter, int32 min_date,
            int32 max_date) {
    query_ = query;
    offset_date_ = offset_date;
    offset_dialog_id_ = offset_dialog_id;
    offset_message_id_ = offset_message_id;
    limit_ = limit;
    filter_ = filter;
    min_date_ = min_date;
    max_date_ = max_date;

    auto input_peer = DialogManager::get_input_peer_force(offset_dialog_id);
    CHECK(input_peer != nullptr);

    int32 flags = 0;
    if (!ignore_folder_id) {
      flags |= telegram_api::messages_searchGlobal::FOLDER_ID_MASK;
    }
    if (dialog_type_filter != nullptr) {
      switch (dialog_type_filter->get_id()) {
        case td_api::searchMessagesChatTypeFilterPrivate::ID:
          flags |= telegram_api::messages_searchGlobal::USERS_ONLY_MASK;
          break;
        case td_api::searchMessagesChatTypeFilterGroup::ID:
          flags |= telegram_api::messages_searchGlobal::GROUPS_ONLY_MASK;
          break;
        case td_api::searchMessagesChatTypeFilterChannel::ID:
          flags |= telegram_api::messages_searchGlobal::BROADCASTS_ONLY_MASK;
          break;
        default:
          UNREACHABLE();
      }
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_searchGlobal(
        flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, folder_id.get(), query,
        get_input_messages_filter(filter), min_date_, max_date_, offset_date_, std::move(input_peer),
        offset_message_id.get_server_message_id().get(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_searchGlobal>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto info = get_messages_info(td_, DialogId(), result_ptr.move_as_ok(), "SearchMessagesGlobalQuery");
    td_->messages_manager_->get_channel_differences_if_needed(
        std::move(info),
        PromiseCreator::lambda([actor_id = td_->message_query_manager_actor_.get(), query = std::move(query_),
                                offset_date = offset_date_, offset_dialog_id = offset_dialog_id_,
                                offset_message_id = offset_message_id_, limit = limit_, filter = std::move(filter_),
                                min_date = min_date_, max_date = max_date_,
                                promise = std::move(promise_)](Result<MessagesInfo> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            auto info = result.move_as_ok();
            send_closure(actor_id, &MessageQueryManager::on_get_messages_search_result, query, offset_date,
                         offset_dialog_id, offset_message_id, limit, filter, min_date, max_date, info.total_count,
                         std::move(info.messages), info.next_rate, std::move(promise));
          }
        }),
        "SearchMessagesGlobalQuery");
  }

  void on_error(Status status) final {
    if (status.message() == "SEARCH_QUERY_EMPTY") {
      return promise_.set_value(td_->messages_manager_->get_found_messages_object({}, "SearchMessagesGlobalQuery"));
    }
    promise_.set_error(std::move(status));
  }
};

class SearchSentMediaQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::foundMessages>> promise_;

 public:
  explicit SearchSentMediaQuery(Promise<td_api::object_ptr<td_api::foundMessages>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &query, int32 limit) {
    send_query(G()->net_query_creator().create(telegram_api::messages_searchSentMedia(
        query, telegram_api::make_object<telegram_api::inputMessagesFilterDocument>(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_searchSentMedia>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto info = get_messages_info(td_, DialogId(), result_ptr.move_as_ok(), "SearchSentMediaQuery");
    td_->messages_manager_->get_channel_differences_if_needed(
        std::move(info),
        PromiseCreator::lambda([actor_id = td_->message_query_manager_actor_.get(),
                                promise = std::move(promise_)](Result<MessagesInfo> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            auto info = result.move_as_ok();
            send_closure(actor_id, &MessageQueryManager::on_get_outgoing_document_messages, std::move(info.messages),
                         std::move(promise));
          }
        }),
        "SearchSentMediaQuery");
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class SearchPostsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::foundMessages>> promise_;
  string hashtag_;
  MessageSearchOffset offset_;
  int32 limit_;

 public:
  explicit SearchPostsQuery(Promise<td_api::object_ptr<td_api::foundMessages>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(const string &hashtag, MessageSearchOffset offset, int32 limit) {
    hashtag_ = hashtag;
    offset_ = offset;
    limit_ = limit;

    auto input_peer = DialogManager::get_input_peer_force(offset.dialog_id_);
    CHECK(input_peer != nullptr);

    send_query(G()->net_query_creator().create(telegram_api::channels_searchPosts(
        hashtag, offset.date_, std::move(input_peer), offset.message_id_.get_server_message_id().get(), limit)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_searchPosts>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto info = get_messages_info(td_, DialogId(), result_ptr.move_as_ok(), "SearchPostsQuery");
    td_->messages_manager_->get_channel_differences_if_needed(
        std::move(info),
        PromiseCreator::lambda([actor_id = td_->message_query_manager_actor_.get(), hashtag = std::move(hashtag_),
                                offset = offset_, limit = limit_,
                                promise = std::move(promise_)](Result<MessagesInfo> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            auto info = result.move_as_ok();
            send_closure(actor_id, &MessageQueryManager::on_get_hashtag_search_result, hashtag, offset, limit,
                         info.total_count, std::move(info.messages), info.next_rate, std::move(promise));
          }
        }),
        "SearchPostsQuery");
  }

  void on_error(Status status) final {
    if (status.message() == "SEARCH_QUERY_EMPTY") {
      return promise_.set_value(td_->messages_manager_->get_found_messages_object({}, "SearchPostsQuery"));
    }
    promise_.set_error(std::move(status));
  }
};

class GetRecentLocationsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::messages>> promise_;
  DialogId dialog_id_;
  int32 limit_;

 public:
  explicit GetRecentLocationsQuery(Promise<td_api::object_ptr<td_api::messages>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, int32 limit) {
    dialog_id_ = dialog_id;
    limit_ = limit;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(
        G()->net_query_creator().create(telegram_api::messages_getRecentLocations(std::move(input_peer), limit, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getRecentLocations>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto info = get_messages_info(td_, dialog_id_, result_ptr.move_as_ok(), "GetRecentLocationsQuery");
    td_->messages_manager_->get_channel_difference_if_needed(
        dialog_id_, std::move(info),
        PromiseCreator::lambda([actor_id = td_->message_query_manager_actor_.get(), dialog_id = dialog_id_,
                                limit = limit_, promise = std::move(promise_)](Result<MessagesInfo> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            auto info = result.move_as_ok();
            send_closure(actor_id, &MessageQueryManager::on_get_recent_locations, dialog_id, limit, info.total_count,
                         std::move(info.messages), std::move(promise));
          }
        }),
        "GetRecentLocationsQuery");
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetRecentLocationsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetMessagePositionQuery final : public Td::ResultHandler {
  Promise<int32> promise_;
  DialogId dialog_id_;
  MessageId message_id_;
  MessageId top_thread_message_id_;
  SavedMessagesTopicId saved_messages_topic_id_;
  MessageSearchFilter filter_;

 public:
  explicit GetMessagePositionQuery(Promise<int32> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId message_id, MessageSearchFilter filter, MessageId top_thread_message_id,
            SavedMessagesTopicId saved_messages_topic_id) {
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);

    dialog_id_ = dialog_id;
    message_id_ = message_id;
    top_thread_message_id_ = top_thread_message_id;
    saved_messages_topic_id_ = saved_messages_topic_id;
    filter_ = filter;

    if (filter == MessageSearchFilter::Empty && !top_thread_message_id.is_valid()) {
      if (saved_messages_topic_id.is_valid()) {
        send_query(G()->net_query_creator().create(telegram_api::messages_getSavedHistory(
            saved_messages_topic_id.get_input_peer(td_), message_id.get_server_message_id().get(), 0, -1, 1, 0, 0, 0)));
      } else {
        send_query(G()->net_query_creator().create(telegram_api::messages_getHistory(
            std::move(input_peer), message_id.get_server_message_id().get(), 0, -1, 1, 0, 0, 0)));
      }
    } else {
      int32 flags = 0;
      tl_object_ptr<telegram_api::InputPeer> saved_input_peer;
      if (saved_messages_topic_id.is_valid()) {
        flags |= telegram_api::messages_search::SAVED_PEER_ID_MASK;
        saved_input_peer = saved_messages_topic_id.get_input_peer(td_);
        CHECK(saved_input_peer != nullptr);
      }
      if (top_thread_message_id.is_valid()) {
        flags |= telegram_api::messages_search::TOP_MSG_ID_MASK;
      }
      send_query(G()->net_query_creator().create(telegram_api::messages_search(
          flags, std::move(input_peer), string(), nullptr, std::move(saved_input_peer), Auto(),
          top_thread_message_id.get_server_message_id().get(), get_input_messages_filter(filter), 0,
          std::numeric_limits<int32>::max(), message_id.get_server_message_id().get(), -1, 1,
          std::numeric_limits<int32>::max(), 0, 0)));
    }
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_search>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto messages_ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetMessagePositionQuery: " << to_string(messages_ptr);
    switch (messages_ptr->get_id()) {
      case telegram_api::messages_messages::ID: {
        auto messages = telegram_api::move_object_as<telegram_api::messages_messages>(messages_ptr);
        if (messages->messages_.size() != 1 ||
            MessageId::get_message_id(messages->messages_[0], false) != message_id_) {
          return promise_.set_error(Status::Error(400, "Message not found by the filter"));
        }
        return promise_.set_value(narrow_cast<int32>(messages->messages_.size()));
      }
      case telegram_api::messages_messagesSlice::ID: {
        auto messages = telegram_api::move_object_as<telegram_api::messages_messagesSlice>(messages_ptr);
        if (messages->messages_.size() != 1 ||
            MessageId::get_message_id(messages->messages_[0], false) != message_id_) {
          return promise_.set_error(Status::Error(400, "Message not found by the filter"));
        }
        if (messages->offset_id_offset_ <= 0) {
          LOG(ERROR) << "Failed to receive position for " << message_id_ << " in thread of " << top_thread_message_id_
                     << " and in " << saved_messages_topic_id_ << " in " << dialog_id_ << " by " << filter_;
          return promise_.set_error(Status::Error(400, "Message position is unknown"));
        }
        return promise_.set_value(std::move(messages->offset_id_offset_));
      }
      case telegram_api::messages_channelMessages::ID: {
        auto messages = telegram_api::move_object_as<telegram_api::messages_channelMessages>(messages_ptr);
        if (messages->messages_.size() != 1 ||
            MessageId::get_message_id(messages->messages_[0], false) != message_id_) {
          return promise_.set_error(Status::Error(400, "Message not found by the filter"));
        }
        if (messages->offset_id_offset_ <= 0) {
          LOG(ERROR) << "Failed to receive position for " << message_id_ << " in " << dialog_id_ << " by " << filter_;
          return promise_.set_error(Status::Error(500, "Message position is unknown"));
        }
        return promise_.set_value(std::move(messages->offset_id_offset_));
      }
      case telegram_api::messages_messagesNotModified::ID:
        LOG(ERROR) << "Server returned messagesNotModified in response to GetMessagePositionQuery";
        return promise_.set_error(Status::Error(500, "Receive invalid response"));
      default:
        UNREACHABLE();
        break;
    }
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetMessagePositionQuery");
    promise_.set_error(std::move(status));
  }
};

class GetOutboxReadDateQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::MessageReadDate>> promise_;
  DialogId dialog_id_;
  MessageId message_id_;

 public:
  explicit GetOutboxReadDateQuery(Promise<td_api::object_ptr<td_api::MessageReadDate>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId message_id) {
    dialog_id_ = dialog_id;
    message_id_ = message_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::messages_getOutboxReadDate(std::move(input_peer), message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getOutboxReadDate>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    promise_.set_value(td_api::make_object<td_api::messageReadDateRead>(ptr->date_));
  }

  void on_error(Status status) final {
    if (status.message() == "USER_PRIVACY_RESTRICTED") {
      return promise_.set_value(td_api::make_object<td_api::messageReadDateUserPrivacyRestricted>());
    }
    if (status.message() == "YOUR_PRIVACY_RESTRICTED") {
      return promise_.set_value(td_api::make_object<td_api::messageReadDateMyPrivacyRestricted>());
    }
    if (status.message() == "MESSAGE_TOO_OLD") {
      return promise_.set_value(td_api::make_object<td_api::messageReadDateTooOld>());
    }

    td_->messages_manager_->on_get_message_error(dialog_id_, message_id_, status, "GetOutboxReadDateQuery");
    promise_.set_error(std::move(status));
  }
};

class GetMessageReadParticipantsQuery final : public Td::ResultHandler {
  Promise<MessageViewers> promise_;
  DialogId dialog_id_;
  MessageId message_id_;

 public:
  explicit GetMessageReadParticipantsQuery(Promise<MessageViewers> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId message_id) {
    dialog_id_ = dialog_id;
    message_id_ = message_id;
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(telegram_api::messages_getMessageReadParticipants(
        std::move(input_peer), message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getMessageReadParticipants>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(MessageViewers(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    td_->messages_manager_->on_get_message_error(dialog_id_, message_id_, status, "GetMessageReadParticipantsQuery");
    promise_.set_error(std::move(status));
  }
};

class GetMessagesViewsQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  vector<MessageId> message_ids_;

 public:
  void send(DialogId dialog_id, vector<MessageId> &&message_ids, bool increment_view_counter) {
    dialog_id_ = dialog_id;
    message_ids_ = std::move(message_ids);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_getMessagesViews(
        std::move(input_peer), MessageId::get_server_message_ids(message_ids_), increment_view_counter)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getMessagesViews>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto result = result_ptr.move_as_ok();
    auto interaction_infos = std::move(result->views_);
    if (message_ids_.size() != interaction_infos.size()) {
      return on_error(Status::Error(500, "Wrong number of message views returned"));
    }
    td_->user_manager_->on_get_users(std::move(result->users_), "GetMessagesViewsQuery");
    td_->chat_manager_->on_get_chats(std::move(result->chats_), "GetMessagesViewsQuery");
    for (size_t i = 0; i < message_ids_.size(); i++) {
      MessageFullId message_full_id{dialog_id_, message_ids_[i]};
      auto *info = interaction_infos[i].get();
      td_->messages_manager_->on_update_message_interaction_info(message_full_id, info->views_, info->forwards_, true,
                                                                 std::move(info->replies_));
    }
    td_->message_query_manager_->finish_get_message_views(dialog_id_, message_ids_);
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetMessagesViewsQuery")) {
      LOG(ERROR) << "Receive error for GetMessagesViewsQuery: " << status;
    }
    td_->message_query_manager_->finish_get_message_views(dialog_id_, message_ids_);
  }
};

class GetMessagesReactionsQuery final : public Td::ResultHandler {
  DialogId dialog_id_;
  vector<MessageId> message_ids_;

 public:
  void send(DialogId dialog_id, vector<MessageId> &&message_ids) {
    dialog_id_ = dialog_id;
    message_ids_ = std::move(message_ids);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    CHECK(input_peer != nullptr);

    send_query(
        G()->net_query_creator().create(telegram_api::messages_getMessagesReactions(
                                            std::move(input_peer), MessageId::get_server_message_ids(message_ids_)),
                                        {{dialog_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getMessagesReactions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for GetMessagesReactionsQuery: " << to_string(ptr);
    if (ptr->get_id() == telegram_api::updates::ID) {
      auto &updates = static_cast<telegram_api::updates *>(ptr.get())->updates_;
      FlatHashSet<MessageId, MessageIdHash> skipped_message_ids;
      for (auto message_id : message_ids_) {
        skipped_message_ids.insert(message_id);
      }
      for (const auto &update : updates) {
        if (update->get_id() == telegram_api::updateMessageReactions::ID) {
          auto update_message_reactions = static_cast<const telegram_api::updateMessageReactions *>(update.get());
          if (DialogId(update_message_reactions->peer_) == dialog_id_) {
            skipped_message_ids.erase(MessageId(ServerMessageId(update_message_reactions->msg_id_)));
          }
        }
      }
      for (auto message_id : skipped_message_ids) {
        td_->messages_manager_->update_message_reactions({dialog_id_, message_id}, nullptr);
      }
    }
    td_->updates_manager_->on_get_updates(std::move(ptr), Promise<Unit>());
    td_->message_query_manager_->try_reload_message_reactions(dialog_id_, true);
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "GetMessagesReactionsQuery");
    td_->message_query_manager_->try_reload_message_reactions(dialog_id_, true);
  }
};

class GetDiscussionMessageQuery final : public Td::ResultHandler {
  Promise<MessageThreadInfo> promise_;
  DialogId dialog_id_;
  MessageId message_id_;
  DialogId expected_dialog_id_;
  MessageId expected_message_id_;

 public:
  explicit GetDiscussionMessageQuery(Promise<MessageThreadInfo> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId message_id, DialogId expected_dialog_id, MessageId expected_message_id) {
    dialog_id_ = dialog_id;
    message_id_ = message_id;
    expected_dialog_id_ = expected_dialog_id;
    expected_message_id_ = expected_message_id;
    CHECK(expected_dialog_id_.is_valid());
    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    CHECK(input_peer != nullptr);
    send_query(G()->net_query_creator().create(
        telegram_api::messages_getDiscussionMessage(std::move(input_peer), message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_getDiscussionMessage>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    td_->message_query_manager_->process_discussion_message(result_ptr.move_as_ok(), dialog_id_, message_id_,
                                                            expected_dialog_id_, expected_message_id_,
                                                            std::move(promise_));
  }

  void on_error(Status status) final {
    td_->messages_manager_->on_get_message_error(dialog_id_, message_id_, status, "GetDiscussionMessageQuery");
    promise_.set_error(std::move(status));
  }
};

class BlockFromRepliesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit BlockFromRepliesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(MessageId message_id, bool need_delete_message, bool need_delete_all_messages, bool report_spam) {
    int32 flags = 0;
    if (need_delete_message) {
      flags |= telegram_api::contacts_blockFromReplies::DELETE_MESSAGE_MASK;
    }
    if (need_delete_all_messages) {
      flags |= telegram_api::contacts_blockFromReplies::DELETE_HISTORY_MASK;
    }
    if (report_spam) {
      flags |= telegram_api::contacts_blockFromReplies::REPORT_SPAM_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::contacts_blockFromReplies(
        flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::contacts_blockFromReplies>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for BlockFromRepliesQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeletePhoneCallHistoryQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;

 public:
  explicit DeletePhoneCallHistoryQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(bool revoke) {
    int32 flags = 0;
    if (revoke) {
      flags |= telegram_api::messages_deletePhoneCallHistory::REVOKE_MASK;
    }
    send_query(
        G()->net_query_creator().create(telegram_api::messages_deletePhoneCallHistory(flags, false /*ignored*/)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deletePhoneCallHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto affected_messages = result_ptr.move_as_ok();
    if (!affected_messages->messages_.empty()) {
      td_->messages_manager_->process_pts_update(
          make_tl_object<telegram_api::updateDeleteMessages>(std::move(affected_messages->messages_), 0, 0));
    }
    promise_.set_value(AffectedHistory(std::move(affected_messages)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

class DeleteParticipantHistoryQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;
  ChannelId channel_id_;
  DialogId sender_dialog_id_;

 public:
  explicit DeleteParticipantHistoryQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, DialogId sender_dialog_id) {
    channel_id_ = channel_id;
    sender_dialog_id_ = sender_dialog_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      return promise_.set_error(Status::Error(400, "Chat is not accessible"));
    }
    auto input_peer = td_->dialog_manager_->get_input_peer(sender_dialog_id, AccessRights::Know);
    if (input_peer == nullptr) {
      return promise_.set_error(Status::Error(400, "Message sender is not accessible"));
    }

    send_query(G()->net_query_creator().create(
        telegram_api::channels_deleteParticipantHistory(std::move(input_channel), std::move(input_peer))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_deleteParticipantHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    if (sender_dialog_id_.get_type() != DialogType::Channel) {
      td_->chat_manager_->on_get_channel_error(channel_id_, status, "DeleteParticipantHistoryQuery");
    }
    promise_.set_error(std::move(status));
  }
};

class DeleteHistoryQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;
  DialogId dialog_id_;

 public:
  explicit DeleteHistoryQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId max_message_id, bool remove_from_dialog_list, bool revoke) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return promise_.set_error(Status::Error(400, "Chat is not accessible"));
    }

    int32 flags = 0;
    if (!remove_from_dialog_list) {
      flags |= telegram_api::messages_deleteHistory::JUST_CLEAR_MASK;
    }
    if (revoke) {
      flags |= telegram_api::messages_deleteHistory::REVOKE_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_deleteHistory(flags, false /*ignored*/, false /*ignored*/, std::move(input_peer),
                                             max_message_id.get_server_message_id().get(), 0, 0)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DeleteHistoryQuery");
    promise_.set_error(std::move(status));
  }
};

class DeleteChannelHistoryQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  MessageId max_message_id_;
  bool allow_error_;

 public:
  explicit DeleteChannelHistoryQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, MessageId max_message_id, bool allow_error, bool revoke) {
    channel_id_ = channel_id;
    max_message_id_ = max_message_id;
    allow_error_ = allow_error;
    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    int32 flags = 0;
    if (revoke) {
      flags |= telegram_api::channels_deleteHistory::FOR_EVERYONE_MASK;
    }

    send_query(G()->net_query_creator().create(telegram_api::channels_deleteHistory(
        flags, false /*ignored*/, std::move(input_channel), max_message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_deleteHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteChannelHistoryQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (!td_->chat_manager_->on_get_channel_error(channel_id_, status, "DeleteChannelHistoryQuery")) {
      LOG(ERROR) << "Receive error for DeleteChannelHistoryQuery: " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class DeleteMessagesByDateQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;
  DialogId dialog_id_;

 public:
  explicit DeleteMessagesByDateQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, int32 min_date, int32 max_date, bool revoke) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return promise_.set_error(Status::Error(400, "Chat is not accessible"));
    }

    int32 flags = telegram_api::messages_deleteHistory::JUST_CLEAR_MASK |
                  telegram_api::messages_deleteHistory::MIN_DATE_MASK |
                  telegram_api::messages_deleteHistory::MAX_DATE_MASK;
    if (revoke) {
      flags |= telegram_api::messages_deleteHistory::REVOKE_MASK;
    }

    send_query(G()->net_query_creator().create(telegram_api::messages_deleteHistory(
        flags, false /*ignored*/, false /*ignored*/, std::move(input_peer), 0, min_date, max_date)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DeleteMessagesByDateQuery");
    promise_.set_error(std::move(status));
  }
};

class DeleteMessagesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  vector<int32> server_message_ids_;

 public:
  explicit DeleteMessagesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, vector<int32> &&server_message_ids, bool revoke) {
    dialog_id_ = dialog_id;
    server_message_ids_ = server_message_ids;

    int32 flags = 0;
    if (revoke) {
      flags |= telegram_api::messages_deleteMessages::REVOKE_MASK;
    }

    send_query(G()->net_query_creator().create(
        telegram_api::messages_deleteMessages(flags, false /*ignored*/, std::move(server_message_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto affected_messages = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteMessagesQuery: " << to_string(affected_messages);
    td_->updates_manager_->add_pending_pts_update(make_tl_object<dummyUpdate>(), affected_messages->pts_,
                                                  affected_messages->pts_count_, Time::now(), std::move(promise_),
                                                  "delete messages query");
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      // MESSAGE_DELETE_FORBIDDEN can be returned in group chats when administrator rights were removed
      // MESSAGE_DELETE_FORBIDDEN can be returned in private chats for bots when revoke time limit exceeded
      if (status.message() != "MESSAGE_DELETE_FORBIDDEN" ||
          (dialog_id_.get_type() == DialogType::User && !td_->auth_manager_->is_bot())) {
        LOG(ERROR) << "Receive error for delete messages: " << status;
      }
    }
    td_->messages_manager_->on_failed_message_deletion(dialog_id_, server_message_ids_);
    promise_.set_error(std::move(status));
  }
};

class DeleteChannelMessagesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;
  vector<int32> server_message_ids_;

 public:
  explicit DeleteChannelMessagesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, vector<int32> &&server_message_ids) {
    channel_id_ = channel_id;
    server_message_ids_ = server_message_ids;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(
        telegram_api::channels_deleteMessages(std::move(input_channel), std::move(server_message_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_deleteMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto affected_messages = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteChannelMessagesQuery: " << to_string(affected_messages);
    td_->messages_manager_->add_pending_channel_update(DialogId(channel_id_), make_tl_object<dummyUpdate>(),
                                                       affected_messages->pts_, affected_messages->pts_count_,
                                                       std::move(promise_), "DeleteChannelMessagesQuery");
  }

  void on_error(Status status) final {
    if (!td_->chat_manager_->on_get_channel_error(channel_id_, status, "DeleteChannelMessagesQuery")) {
      if (status.message() != "MESSAGE_DELETE_FORBIDDEN") {
        LOG(ERROR) << "Receive error for delete channel messages: " << status;
      }
    }
    td_->messages_manager_->on_failed_message_deletion(DialogId(channel_id_), server_message_ids_);
    promise_.set_error(std::move(status));
  }
};

class DeleteScheduledMessagesQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  DialogId dialog_id_;
  vector<MessageId> message_ids_;

 public:
  explicit DeleteScheduledMessagesQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, vector<MessageId> &&message_ids) {
    dialog_id_ = dialog_id;
    message_ids_ = std::move(message_ids);

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_deleteScheduledMessages(
        std::move(input_peer), MessageId::get_scheduled_server_message_ids(message_ids_))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_deleteScheduledMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto ptr = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for DeleteScheduledMessagesQuery: " << to_string(ptr);
    td_->updates_manager_->on_get_updates(std::move(ptr), std::move(promise_));
  }

  void on_error(Status status) final {
    if (!td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "DeleteScheduledMessagesQuery")) {
      LOG(ERROR) << "Receive error for delete scheduled messages: " << status;
    }
    td_->messages_manager_->on_failed_scheduled_message_deletion(dialog_id_, message_ids_);
    promise_.set_error(std::move(status));
  }
};

class DeleteTopicHistoryQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;
  ChannelId channel_id_;
  MessageId top_thread_message_id_;

 public:
  explicit DeleteTopicHistoryQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId top_thread_message_id) {
    CHECK(dialog_id.get_type() == DialogType::Channel);
    channel_id_ = dialog_id.get_channel_id();
    top_thread_message_id_ = top_thread_message_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id_);
    if (input_channel == nullptr) {
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(G()->net_query_creator().create(telegram_api::channels_deleteTopicHistory(
        std::move(input_channel), top_thread_message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_deleteTopicHistory>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    td_->messages_manager_->on_get_message_error(DialogId(channel_id_), top_thread_message_id_, status,
                                                 "DeleteTopicHistoryQuery");
    promise_.set_error(std::move(status));
  }
};

class ReadMentionsQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;
  DialogId dialog_id_;

 public:
  explicit ReadMentionsQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId top_thread_message_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return promise_.set_error(Status::Error(400, "Chat is not accessible"));
    }

    int32 flags = 0;
    if (top_thread_message_id.is_valid()) {
      flags |= telegram_api::messages_readMentions::TOP_MSG_ID_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_readMentions(flags, std::move(input_peer),
                                            top_thread_message_id.get_server_message_id().get()),
        {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_readMentions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReadMentionsQuery");
    promise_.set_error(std::move(status));
  }
};

class ReadReactionsQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;
  DialogId dialog_id_;

 public:
  explicit ReadReactionsQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId top_thread_message_id) {
    dialog_id_ = dialog_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      return promise_.set_error(Status::Error(400, "Chat is not accessible"));
    }

    int32 flags = 0;
    if (top_thread_message_id.is_valid()) {
      flags |= telegram_api::messages_readReactions::TOP_MSG_ID_MASK;
    }
    send_query(G()->net_query_creator().create(
        telegram_api::messages_readReactions(flags, std::move(input_peer),
                                             top_thread_message_id.get_server_message_id().get()),
        {{dialog_id}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_readReactions>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    td_->dialog_manager_->on_get_dialog_error(dialog_id_, status, "ReadReactionsQuery");
    promise_.set_error(std::move(status));
  }
};

class ReadMessagesContentsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit ReadMessagesContentsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(vector<MessageId> &&message_ids) {
    send_query(G()->net_query_creator().create(
        telegram_api::messages_readMessageContents(MessageId::get_server_message_ids(message_ids))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_readMessageContents>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto affected_messages = result_ptr.move_as_ok();
    LOG(INFO) << "Receive result for ReadMessagesContentsQuery: " << to_string(affected_messages);

    if (affected_messages->pts_count_ > 0) {
      td_->updates_manager_->add_pending_pts_update(make_tl_object<dummyUpdate>(), affected_messages->pts_,
                                                    affected_messages->pts_count_, Time::now(), Promise<Unit>(),
                                                    "read messages content query");
    }

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "Receive error for read message contents: " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class ReadChannelMessagesContentsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;
  ChannelId channel_id_;

 public:
  explicit ReadChannelMessagesContentsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(ChannelId channel_id, vector<MessageId> &&message_ids) {
    channel_id_ = channel_id;

    auto input_channel = td_->chat_manager_->get_input_channel(channel_id);
    if (input_channel == nullptr) {
      LOG(ERROR) << "Have no input channel for " << channel_id;
      return on_error(Status::Error(400, "Can't access the chat"));
    }

    send_query(
        G()->net_query_creator().create(telegram_api::channels_readMessageContents(
                                            std::move(input_channel), MessageId::get_server_message_ids(message_ids)),
                                        {{channel_id_}}));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::channels_readMessageContents>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    bool result = result_ptr.ok();
    LOG_IF(ERROR, !result) << "Read channel messages contents failed";

    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    if (!td_->chat_manager_->on_get_channel_error(channel_id_, status, "ReadChannelMessagesContentsQuery")) {
      LOG(ERROR) << "Receive error for read messages contents in " << channel_id_ << ": " << status;
    }
    promise_.set_error(std::move(status));
  }
};

class UnpinAllMessagesQuery final : public Td::ResultHandler {
  Promise<AffectedHistory> promise_;
  DialogId dialog_id_;
  MessageId top_thread_message_id_;

 public:
  explicit UnpinAllMessagesQuery(Promise<AffectedHistory> &&promise) : promise_(std::move(promise)) {
  }

  void send(DialogId dialog_id, MessageId top_thread_message_id) {
    dialog_id_ = dialog_id;
    top_thread_message_id_ = top_thread_message_id;

    auto input_peer = td_->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
    if (input_peer == nullptr) {
      LOG(INFO) << "Can't unpin all messages in " << dialog_id_;
      return on_error(Status::Error(400, "Can't unpin all messages"));
    }

    int32 flags = 0;
    if (top_thread_message_id.is_valid()) {
      flags |= telegram_api::messages_unpinAllMessages::TOP_MSG_ID_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::messages_unpinAllMessages(
        flags, std::move(input_peer), top_thread_message_id.get_server_message_id().get())));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::messages_unpinAllMessages>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(AffectedHistory(result_ptr.move_as_ok()));
  }

  void on_error(Status status) final {
    td_->messages_manager_->on_get_message_error(dialog_id_, top_thread_message_id_, status, "UnpinAllMessagesQuery");
    promise_.set_error(std::move(status));
  }
};

class MessageQueryManager::UploadCoverCallback final : public FileManager::UploadCallback {
 public:
  void on_upload_ok(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file) final {
    send_closure_later(G()->message_query_manager(), &MessageQueryManager::on_upload_cover, file_upload_id,
                       std::move(input_file));
  }

  void on_upload_error(FileUploadId file_upload_id, Status error) final {
    send_closure_later(G()->message_query_manager(), &MessageQueryManager::on_upload_cover_error, file_upload_id,
                       std::move(error));
  }
};

MessageQueryManager::MessageQueryManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
  upload_cover_callback_ = std::make_shared<UploadCoverCallback>();
}

void MessageQueryManager::tear_down() {
  parent_.reset();
}

void MessageQueryManager::run_affected_history_query_until_complete(DialogId dialog_id, AffectedHistoryQuery query,
                                                                    bool get_affected_messages,
                                                                    Promise<Unit> &&promise) {
  CHECK(!G()->close_flag());
  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, query, get_affected_messages,
                                               promise = std::move(promise)](Result<AffectedHistory> &&result) mutable {
    if (result.is_error()) {
      return promise.set_error(result.move_as_error());
    }

    send_closure(actor_id, &MessageQueryManager::on_get_affected_history, dialog_id, query, get_affected_messages,
                 result.move_as_ok(), std::move(promise));
  });
  query(dialog_id, std::move(query_promise));
}

void MessageQueryManager::on_get_affected_history(DialogId dialog_id, AffectedHistoryQuery query,
                                                  bool get_affected_messages, AffectedHistory affected_history,
                                                  Promise<Unit> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  LOG(INFO) << "Receive " << (affected_history.is_final_ ? "final " : "partial ")
            << "affected history with PTS = " << affected_history.pts_
            << " and pts_count = " << affected_history.pts_count_;

  if (affected_history.pts_count_ > 0) {
    if (get_affected_messages) {
      affected_history.pts_count_ = 0;
    }
    auto update_promise = affected_history.is_final_ ? std::move(promise) : Promise<Unit>();
    if (dialog_id.get_type() == DialogType::Channel) {
      td_->messages_manager_->add_pending_channel_update(dialog_id, telegram_api::make_object<dummyUpdate>(),
                                                         affected_history.pts_, affected_history.pts_count_,
                                                         std::move(update_promise), "on_get_affected_history");
    } else {
      td_->updates_manager_->add_pending_pts_update(
          telegram_api::make_object<dummyUpdate>(), affected_history.pts_, affected_history.pts_count_,
          Time::now() - (get_affected_messages ? 10.0 : 0.0), std::move(update_promise), "on_get_affected_history");
    }
  } else if (affected_history.is_final_) {
    promise.set_value(Unit());
  }

  if (!affected_history.is_final_) {
    run_affected_history_query_until_complete(dialog_id, std::move(query), get_affected_messages, std::move(promise));
  }
}

void MessageQueryManager::upload_message_covers(BusinessConnectionId business_connection_id, DialogId dialog_id,
                                                vector<const Photo *> covers, Promise<Unit> &&promise) {
  CHECK(!covers.empty());
  MultiPromiseActorSafe mpas{"UploadMessageCoversMultiPromiseActor"};
  mpas.add_promise(std::move(promise));
  auto lock = mpas.get_promise();
  for (const Photo *cover : covers) {
    CHECK(cover != nullptr);
    auto file_upload_id = FileUploadId(get_photo_any_file_id(*cover), FileManager::get_internal_upload_id());
    upload_message_cover(business_connection_id, dialog_id, *cover, file_upload_id, mpas.get_promise());
  }
  lock.set_value(Unit());
}

void MessageQueryManager::upload_message_cover(BusinessConnectionId business_connection_id, DialogId dialog_id,
                                               Photo photo, FileUploadId file_upload_id, Promise<Unit> &&promise,
                                               vector<int> bad_parts) {
  BeingUploadedCover cover;
  cover.business_connection_id_ = business_connection_id;
  cover.dialog_id_ = dialog_id;
  cover.photo_ = std::move(photo);
  cover.promise_ = std::move(promise);

  auto input_media = photo_get_cover_input_media(td_->file_manager_.get(), cover.photo_,
                                                 td_->auth_manager_->is_bot() && bad_parts.empty(), true);
  if (input_media != nullptr && bad_parts.empty()) {
    return do_upload_cover(file_upload_id, std::move(cover));
  }

  LOG(INFO) << "Ask to upload cover " << file_upload_id << " with bad parts " << bad_parts;
  CHECK(file_upload_id.is_valid());
  bool is_inserted = being_uploaded_covers_.emplace(file_upload_id, std::move(cover)).second;
  CHECK(is_inserted);
  // need to call resume_upload synchronously to make upload process consistent with being_uploaded_covers_
  td_->file_manager_->resume_upload(file_upload_id, std::move(bad_parts), upload_cover_callback_, 1, 0);
}

void MessageQueryManager::on_upload_cover(FileUploadId file_upload_id,
                                          telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  LOG(INFO) << "Cover " << file_upload_id << " has been uploaded";

  auto it = being_uploaded_covers_.find(file_upload_id);
  CHECK(it != being_uploaded_covers_.end());
  auto cover = std::move(it->second);
  being_uploaded_covers_.erase(it);

  cover.input_file_ = std::move(input_file);
  do_upload_cover(file_upload_id, std::move(cover));
}

void MessageQueryManager::on_upload_cover_error(FileUploadId file_upload_id, Status status) {
  CHECK(status.is_error());

  auto it = being_uploaded_covers_.find(file_upload_id);
  CHECK(it != being_uploaded_covers_.end());
  auto cover = std::move(it->second);
  being_uploaded_covers_.erase(it);

  cover.promise_.set_error(std::move(status));
}

void MessageQueryManager::do_upload_cover(FileUploadId file_upload_id, BeingUploadedCover &&being_uploaded_cover) {
  auto input_file = std::move(being_uploaded_cover.input_file_);
  bool have_input_file = input_file != nullptr;
  LOG(INFO) << "Do upload cover " << file_upload_id << ", have_input_file = " << have_input_file;

  auto input_media =
      photo_get_input_media(td_->file_manager_.get(), being_uploaded_cover.photo_, std::move(input_file), 0, false);
  CHECK(input_media != nullptr);
  if (is_uploaded_input_media(input_media)) {
    return being_uploaded_cover.promise_.set_value(Unit());
  } else {
    td_->create_handler<UploadCoverQuery>(std::move(being_uploaded_cover.promise_))
        ->send(being_uploaded_cover.business_connection_id_, being_uploaded_cover.dialog_id_,
               std::move(being_uploaded_cover.photo_), file_upload_id, std::move(input_media));
  }
}

void MessageQueryManager::complete_upload_message_cover(
    BusinessConnectionId business_connection_id, DialogId dialog_id, Photo photo, FileUploadId file_upload_id,
    telegram_api::object_ptr<telegram_api::MessageMedia> &&media_ptr, Promise<Unit> &&promise) {
  send_closure_later(G()->file_manager(), &FileManager::cancel_upload, file_upload_id);

  if (media_ptr->get_id() != telegram_api::messageMediaPhoto::ID) {
    return promise.set_error(Status::Error(500, "Receive invalid response"));
  }
  auto media = telegram_api::move_object_as<telegram_api::messageMediaPhoto>(media_ptr);
  if (media->photo_ == nullptr || (media->flags_ & telegram_api::messageMediaPhoto::TTL_SECONDS_MASK) != 0) {
    return promise.set_error(Status::Error(500, "Receive invalid response without photo"));
  }
  auto new_photo = get_photo(td_, std::move(media->photo_), dialog_id, FileType::Photo);
  if (new_photo.is_empty()) {
    return promise.set_error(Status::Error(500, "Receive invalid photo in response"));
  }
  bool is_content_changed = false;
  bool need_update = false;
  merge_photos(td_, &photo, &new_photo, dialog_id, true, is_content_changed, need_update);

  auto input_media = photo_get_cover_input_media(td_->file_manager_.get(), photo, true, true);
  if (input_media == nullptr) {
    return promise.set_error(Status::Error(500, "Failed to upload file"));
  }
  promise.set_value(Unit());
}

void MessageQueryManager::report_message_delivery(MessageFullId message_full_id, int32 until_date, bool from_push) {
  if (G()->unix_time() > until_date) {
    return;
  }
  td_->create_handler<ReportMessageDeliveryQuery>()->send(message_full_id, from_push);
}

void MessageQueryManager::reload_message_extended_media(DialogId dialog_id, vector<MessageId> message_ids) {
  CHECK(dialog_id.get_type() != DialogType::SecretChat);
  td::remove_if(message_ids, [&](MessageId message_id) {
    return !being_reloaded_fact_checks_.insert({dialog_id, message_id}).second;
  });
  if (message_ids.empty()) {
    return;
  }
  td_->create_handler<GetExtendedMediaQuery>()->send(dialog_id, std::move(message_ids));
}

void MessageQueryManager::finish_get_message_extended_media(DialogId dialog_id, const vector<MessageId> &message_ids) {
  for (auto message_id : message_ids) {
    being_reloaded_extended_media_message_full_ids_.erase({dialog_id, message_id});
  }
}

void MessageQueryManager::reload_message_fact_checks(DialogId dialog_id, vector<MessageId> message_ids) {
  CHECK(dialog_id.get_type() != DialogType::SecretChat);
  td::remove_if(message_ids, [&](MessageId message_id) {
    return !being_reloaded_fact_checks_.insert({dialog_id, message_id}).second;
  });
  if (message_ids.empty()) {
    return;
  }

  auto promise =
      PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, message_ids](
                                 Result<vector<telegram_api::object_ptr<telegram_api::factCheck>>> r_fact_checks) {
        send_closure(actor_id, &MessageQueryManager::on_reload_message_fact_checks, dialog_id, message_ids,
                     std::move(r_fact_checks));
      });
  td_->create_handler<GetFactCheckQuery>(std::move(promise))->send(dialog_id, message_ids);
}

void MessageQueryManager::on_reload_message_fact_checks(
    DialogId dialog_id, const vector<MessageId> &message_ids,
    Result<vector<telegram_api::object_ptr<telegram_api::factCheck>>> r_fact_checks) {
  G()->ignore_result_if_closing(r_fact_checks);
  for (auto message_id : message_ids) {
    auto erased_count = being_reloaded_fact_checks_.erase({dialog_id, message_id});
    CHECK(erased_count > 0);
  }
  if (r_fact_checks.is_error() || !td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
    return;
  }
  auto fact_checks = r_fact_checks.move_as_ok();
  if (fact_checks.size() != message_ids.size()) {
    LOG(ERROR) << "Receive " << fact_checks.size() << " fact checks instead of " << message_ids.size();
    return;
  }
  for (size_t i = 0; i < message_ids.size(); i++) {
    td_->messages_manager_->on_update_message_fact_check(
        {dialog_id, message_ids[i]},
        FactCheck::get_fact_check(td_->user_manager_.get(), std::move(fact_checks[i]), false));
  }
}

void MessageQueryManager::set_message_fact_check(MessageFullId message_full_id, const FormattedText &fact_check_text,
                                                 Promise<Unit> &&promise) {
  td_->create_handler<EditMessageFactCheckQuery>(std::move(promise))
      ->send(message_full_id.get_dialog_id(), message_full_id.get_message_id(), fact_check_text);
}

void MessageQueryManager::search_messages(DialogListId dialog_list_id, bool ignore_folder_id, const string &query,
                                          const string &offset_str, int32 limit, MessageSearchFilter filter,
                                          td_api::object_ptr<td_api::SearchMessagesChatTypeFilter> &&dialog_type_filter,
                                          int32 min_date, int32 max_date,
                                          Promise<td_api::object_ptr<td_api::foundMessages>> &&promise) {
  if (!dialog_list_id.is_folder()) {
    return promise.set_error(Status::Error(400, "Wrong chat list specified"));
  }
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_SEARCH_MESSAGES) {
    limit = MAX_SEARCH_MESSAGES;
  }

  TRY_RESULT_PROMISE(promise, offset, MessageSearchOffset::from_string(offset_str));

  CHECK(filter != MessageSearchFilter::Call && filter != MessageSearchFilter::MissedCall);
  if (filter == MessageSearchFilter::Mention || filter == MessageSearchFilter::UnreadMention ||
      filter == MessageSearchFilter::UnreadReaction || filter == MessageSearchFilter::FailedToSend ||
      filter == MessageSearchFilter::Pinned) {
    return promise.set_error(Status::Error(400, "The filter is not supported"));
  }

  if (query.empty() && filter == MessageSearchFilter::Empty) {
    return promise.set_value(td_->messages_manager_->get_found_messages_object({}, "search_messages"));
  }

  td_->create_handler<SearchMessagesGlobalQuery>(std::move(promise))
      ->send(dialog_list_id.get_folder_id(), ignore_folder_id, query, offset.date_, offset.dialog_id_,
             offset.message_id_, limit, filter, dialog_type_filter, min_date, max_date);
}

void MessageQueryManager::on_get_messages_search_result(
    const string &query, int32 offset_date, DialogId offset_dialog_id, MessageId offset_message_id, int32 limit,
    MessageSearchFilter filter, int32 min_date, int32 max_date, int32 total_count,
    vector<telegram_api::object_ptr<telegram_api::Message>> &&messages, int32 next_rate,
    Promise<td_api::object_ptr<td_api::foundMessages>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  LOG(INFO) << "Receive " << messages.size() << " found messages";

  MessagesManager::FoundMessages found_messages;
  auto &result = found_messages.message_full_ids;
  MessageSearchOffset next_offset;
  for (auto &message : messages) {
    next_offset.update_from_message(message);

    bool is_channel_message = DialogId::get_message_dialog_id(message).get_type() == DialogType::Channel;
    auto new_message_full_id =
        td_->messages_manager_->on_get_message(std::move(message), false, is_channel_message, false, "search messages");
    if (new_message_full_id != MessageFullId()) {
      result.push_back(new_message_full_id);
    } else {
      total_count--;
    }
  }
  if (total_count < static_cast<int32>(result.size())) {
    LOG(ERROR) << "Receive " << result.size() << " valid messages out of " << total_count << " in " << messages.size()
               << " messages";
    total_count = static_cast<int32>(result.size());
  }
  found_messages.total_count = total_count;
  if (!result.empty()) {
    if (next_rate > 0) {
      next_offset.date_ = next_rate;
    }
    found_messages.next_offset = next_offset.to_string();
  }
  promise.set_value(td_->messages_manager_->get_found_messages_object(found_messages, "on_get_messages_search_result"));
}

void MessageQueryManager::search_outgoing_document_messages(
    const string &query, int32 limit, Promise<td_api::object_ptr<td_api::foundMessages>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_SEARCH_MESSAGES) {
    limit = MAX_SEARCH_MESSAGES;
  }

  td_->create_handler<SearchSentMediaQuery>(std::move(promise))->send(query, limit);
}

void MessageQueryManager::on_get_outgoing_document_messages(
    vector<telegram_api::object_ptr<telegram_api::Message>> &&messages,
    Promise<td_api::object_ptr<td_api::foundMessages>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  MessagesManager::FoundMessages found_messages;
  for (auto &message : messages) {
    auto dialog_id = DialogId::get_message_dialog_id(message);
    auto message_full_id =
        td_->messages_manager_->on_get_message(std::move(message), false, dialog_id.get_type() == DialogType::Channel,
                                               false, "on_get_outgoing_document_messages");
    if (message_full_id != MessageFullId()) {
      CHECK(dialog_id == message_full_id.get_dialog_id());
      found_messages.message_full_ids.push_back(message_full_id);
    }
  }
  auto result = td_->messages_manager_->get_found_messages_object(found_messages, "on_get_outgoing_document_messages");
  td::remove_if(result->messages_,
                [](const auto &message) { return message->content_->get_id() != td_api::messageDocument::ID; });
  result->total_count_ = narrow_cast<int32>(result->messages_.size());
  promise.set_value(std::move(result));
}

void MessageQueryManager::search_hashtag_posts(string hashtag, string offset_str, int32 limit,
                                               Promise<td_api::object_ptr<td_api::foundMessages>> &&promise) {
  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_SEARCH_MESSAGES) {
    limit = MAX_SEARCH_MESSAGES;
  }

  TRY_RESULT_PROMISE(promise, offset, MessageSearchOffset::from_string(offset_str));

  bool is_cashtag = false;
  if (hashtag[0] == '#' || hashtag[0] == '$') {
    is_cashtag = (hashtag[0] == '$');
    hashtag = hashtag.substr(1);
  }
  if (hashtag.empty()) {
    return promise.set_value(td_->messages_manager_->get_found_messages_object({}, "search_hashtag_posts"));
  }
  send_closure(is_cashtag ? td_->cashtag_search_hints_ : td_->hashtag_search_hints_, &HashtagHints::hashtag_used,
               hashtag);

  td_->create_handler<SearchPostsQuery>(std::move(promise))
      ->send(PSTRING() << (is_cashtag ? '$' : '#') << hashtag, offset, limit);
}

void MessageQueryManager::on_get_hashtag_search_result(
    const string &hashtag, const MessageSearchOffset &old_offset, int32 limit, int32 total_count,
    vector<telegram_api::object_ptr<telegram_api::Message>> &&messages, int32 next_rate,
    Promise<td_api::object_ptr<td_api::foundMessages>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  MessagesManager::FoundMessages found_messages;
  auto &result = found_messages.message_full_ids;
  MessageSearchOffset next_offset;
  for (auto &message : messages) {
    next_offset.update_from_message(message);

    auto new_message_full_id =
        td_->messages_manager_->on_get_message(std::move(message), false, true, false, "search hashtag");
    if (new_message_full_id != MessageFullId()) {
      result.push_back(new_message_full_id);
    } else {
      total_count--;
    }
  }
  if (total_count < static_cast<int32>(result.size())) {
    LOG(ERROR) << "Receive " << result.size() << " valid messages out of " << total_count << " in " << messages.size()
               << " messages";
    total_count = static_cast<int32>(result.size());
  }
  found_messages.total_count = total_count;
  if (!result.empty()) {
    if (next_rate > 0) {
      next_offset.date_ = next_rate;
    }
    found_messages.next_offset = next_offset.to_string();
  }
  promise.set_value(td_->messages_manager_->get_found_messages_object(found_messages, "on_get_hashtag_search_result"));
}

void MessageQueryManager::search_dialog_recent_location_messages(
    DialogId dialog_id, int32 limit, Promise<td_api::object_ptr<td_api::messages>> &&promise) {
  LOG(INFO) << "Search recent location messages in " << dialog_id << " with limit " << limit;

  if (limit <= 0) {
    return promise.set_error(Status::Error(400, "Parameter limit must be positive"));
  }
  if (limit > MAX_SEARCH_MESSAGES) {
    limit = MAX_SEARCH_MESSAGES;
  }

  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, true, AccessRights::Read,
                                                                        "search_dialog_recent_location_messages"));

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::Channel:
      return td_->create_handler<GetRecentLocationsQuery>(std::move(promise))->send(dialog_id, limit);
    case DialogType::SecretChat:
      return promise.set_value(td_->messages_manager_->get_messages_object(0, dialog_id, {}, false,
                                                                           "search_dialog_recent_location_messages"));
    default:
      UNREACHABLE();
      promise.set_error(Status::Error(500, "Message search is not supported"));
  }
}

void MessageQueryManager::on_get_recent_locations(DialogId dialog_id, int32 limit, int32 total_count,
                                                  vector<telegram_api::object_ptr<telegram_api::Message>> &&messages,
                                                  Promise<td_api::object_ptr<td_api::messages>> &&promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  LOG(INFO) << "Receive " << messages.size() << " recent locations in " << dialog_id;
  vector<MessageId> message_ids;
  for (auto &message : messages) {
    auto new_message_full_id = td_->messages_manager_->on_get_message(
        std::move(message), false, dialog_id.get_type() == DialogType::Channel, false, "on_get_recent_locations");
    if (new_message_full_id != MessageFullId()) {
      if (new_message_full_id.get_dialog_id() != dialog_id) {
        LOG(ERROR) << "Receive " << new_message_full_id << " instead of a message in " << dialog_id;
        total_count--;
        continue;
      }

      message_ids.push_back(new_message_full_id.get_message_id());
    } else {
      total_count--;
    }
  }
  if (total_count < static_cast<int32>(message_ids.size())) {
    LOG(ERROR) << "Receive " << message_ids.size() << " valid messages out of " << total_count << " in "
               << messages.size() << " messages";
    total_count = static_cast<int32>(message_ids.size());
  }
  auto result =
      td_->messages_manager_->get_messages_object(total_count, dialog_id, message_ids, true, "on_get_recent_locations");
  td::remove_if(result->messages_, [&](const auto &message) {
    if (message->content_->get_id() != td_api::messageLocation::ID ||
        static_cast<const td_api::messageLocation *>(message->content_.get())->live_period_ <= 0) {
      result->total_count_--;
      return true;
    }
    return false;
  });

  promise.set_value(std::move(result));
}

void MessageQueryManager::get_dialog_message_position_from_server(DialogId dialog_id, MessageId message_id,
                                                                  MessageSearchFilter filter,
                                                                  MessageId top_thread_message_id,
                                                                  SavedMessagesTopicId saved_messages_topic_id,
                                                                  Promise<int32> &&promise) {
  if (filter == MessageSearchFilter::UnreadMention || filter == MessageSearchFilter::UnreadReaction ||
      filter == MessageSearchFilter::FailedToSend) {
    return promise.set_error(Status::Error(400, "The filter is not supported"));
  }

  td_->create_handler<GetMessagePositionQuery>(std::move(promise))
      ->send(dialog_id, message_id, filter, top_thread_message_id, saved_messages_topic_id);
}

void MessageQueryManager::get_message_read_date_from_server(
    MessageFullId message_full_id, Promise<td_api::object_ptr<td_api::MessageReadDate>> &&promise) {
  td_->create_handler<GetOutboxReadDateQuery>(std::move(promise))
      ->send(message_full_id.get_dialog_id(), message_full_id.get_message_id());
}

void MessageQueryManager::get_message_viewers(MessageFullId message_full_id,
                                              Promise<td_api::object_ptr<td_api::messageViewers>> &&promise) {
  TRY_STATUS_PROMISE(promise, td_->messages_manager_->can_get_message_viewers(message_full_id));

  auto query_promise = PromiseCreator::lambda([actor_id = actor_id(this), dialog_id = message_full_id.get_dialog_id(),
                                               promise = std::move(promise)](Result<MessageViewers> result) mutable {
    if (result.is_error()) {
      return promise.set_error(result.move_as_error());
    }
    send_closure(actor_id, &MessageQueryManager::on_get_message_viewers, dialog_id, result.move_as_ok(), false,
                 std::move(promise));
  });

  td_->create_handler<GetMessageReadParticipantsQuery>(std::move(query_promise))
      ->send(message_full_id.get_dialog_id(), message_full_id.get_message_id());
}

void MessageQueryManager::on_get_message_viewers(DialogId dialog_id, MessageViewers message_viewers, bool is_recursive,
                                                 Promise<td_api::object_ptr<td_api::messageViewers>> &&promise) {
  if (!is_recursive) {
    bool need_participant_list = false;
    for (auto user_id : message_viewers.get_user_ids()) {
      if (!td_->user_manager_->have_user_force(user_id, "on_get_message_viewers")) {
        need_participant_list = true;
      }
    }
    if (need_participant_list) {
      auto query_promise =
          PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, message_viewers = std::move(message_viewers),
                                  promise = std::move(promise)](Unit result) mutable {
            send_closure(actor_id, &MessageQueryManager::on_get_message_viewers, dialog_id, std::move(message_viewers),
                         true, std::move(promise));
          });

      switch (dialog_id.get_type()) {
        case DialogType::Chat:
          return td_->chat_manager_->reload_chat_full(dialog_id.get_chat_id(), std::move(query_promise),
                                                      "on_get_message_viewers");
        case DialogType::Channel:
          return td_->dialog_participant_manager_->get_channel_participants(
              dialog_id.get_channel_id(), td_api::make_object<td_api::supergroupMembersFilterRecent>(), string(), 0,
              200, 200, PromiseCreator::lambda([query_promise = std::move(query_promise)](DialogParticipants) mutable {
                query_promise.set_value(Unit());
              }));
        default:
          UNREACHABLE();
          return;
      }
    }
  }
  promise.set_value(message_viewers.get_message_viewers_object(td_->user_manager_.get()));
}

void MessageQueryManager::view_messages(DialogId dialog_id, const vector<MessageId> &message_ids,
                                        bool increment_view_counter) {
  const size_t MAX_MESSAGE_VIEWS = 100;  // server-side limit
  vector<MessageId> viewed_message_ids;
  viewed_message_ids.reserve(min(message_ids.size(), MAX_MESSAGE_VIEWS));
  for (auto message_id : message_ids) {
    MessageFullId message_full_id{dialog_id, message_id};
    if (!being_reloaded_views_message_full_ids_.insert(message_full_id).second) {
      if (!increment_view_counter || !need_view_counter_increment_message_full_ids_.insert(message_full_id).second) {
        continue;
      }
    } else if (increment_view_counter) {
      need_view_counter_increment_message_full_ids_.insert(message_full_id);
    }
    viewed_message_ids.push_back(message_id);
    if (viewed_message_ids.size() >= MAX_MESSAGE_VIEWS) {
      td_->create_handler<GetMessagesViewsQuery>()->send(dialog_id, std::move(viewed_message_ids),
                                                         increment_view_counter);
      viewed_message_ids.clear();
    }
  }
  if (!viewed_message_ids.empty()) {
    td_->create_handler<GetMessagesViewsQuery>()->send(dialog_id, std::move(viewed_message_ids),
                                                       increment_view_counter);
  }
}

void MessageQueryManager::finish_get_message_views(DialogId dialog_id, const vector<MessageId> &message_ids) {
  for (auto message_id : message_ids) {
    MessageFullId message_full_id{dialog_id, message_id};
    being_reloaded_views_message_full_ids_.erase(message_full_id);
    need_view_counter_increment_message_full_ids_.erase(message_full_id);
  }
}

void MessageQueryManager::queue_message_reactions_reload(MessageFullId message_full_id) {
  auto dialog_id = message_full_id.get_dialog_id();
  CHECK(dialog_id.is_valid());
  auto message_id = message_full_id.get_message_id();
  CHECK(message_id.is_valid());
  being_reloaded_reactions_[dialog_id].message_ids.insert(message_id);
  try_reload_message_reactions(dialog_id, false);
}

void MessageQueryManager::queue_message_reactions_reload(DialogId dialog_id, const vector<MessageId> &message_ids) {
  LOG(INFO) << "Queue reload of reactions in " << message_ids << " in " << dialog_id;
  auto &message_ids_to_reload = being_reloaded_reactions_[dialog_id].message_ids;
  for (auto &message_id : message_ids) {
    CHECK(message_id.is_valid());
    message_ids_to_reload.insert(message_id);
  }
  try_reload_message_reactions(dialog_id, false);
}

void MessageQueryManager::try_reload_message_reactions(DialogId dialog_id, bool is_finished) {
  if (G()->close_flag()) {
    return;
  }

  auto it = being_reloaded_reactions_.find(dialog_id);
  if (it == being_reloaded_reactions_.end()) {
    return;
  }
  if (is_finished) {
    CHECK(it->second.is_request_sent);
    it->second.is_request_sent = false;

    if (it->second.message_ids.empty()) {
      being_reloaded_reactions_.erase(it);
      return;
    }
  } else if (it->second.is_request_sent) {
    return;
  }

  CHECK(!it->second.message_ids.empty());
  CHECK(!it->second.is_request_sent);

  it->second.is_request_sent = true;

  static constexpr size_t MAX_MESSAGE_IDS = 100;  // server-side limit
  vector<MessageId> message_ids;
  for (auto message_id_it = it->second.message_ids.begin();
       message_id_it != it->second.message_ids.end() && message_ids.size() < MAX_MESSAGE_IDS; ++message_id_it) {
    auto message_id = *message_id_it;
    if (!has_message_pending_read_reactions({dialog_id, message_id})) {
      message_ids.push_back(message_id);
    }
  }
  for (auto message_id : message_ids) {
    it->second.message_ids.erase(message_id);
  }

  if (!td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read) || message_ids.empty()) {
    create_actor<SleepActor>("RetryReloadMessageReactionsActor", 0.2,
                             PromiseCreator::lambda([actor_id = actor_id(this), dialog_id](Unit) mutable {
                               send_closure(actor_id, &MessageQueryManager::try_reload_message_reactions, dialog_id,
                                            true);
                             }))
        .release();
    return;
  }

  for (const auto &message_id : message_ids) {
    CHECK(message_id.is_valid());
    CHECK(message_id.is_server());
  }

  td_->create_handler<GetMessagesReactionsQuery>()->send(dialog_id, std::move(message_ids));
}

void MessageQueryManager::get_paid_message_reaction_senders(
    DialogId dialog_id, Promise<td_api::object_ptr<td_api::messageSenders>> &&promise, bool is_recursive) {
  TRY_STATUS_PROMISE(promise, G()->close_status());
  TRY_STATUS_PROMISE(promise, td_->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read,
                                                                        "get_paid_message_reaction_senders"));
  if (!td_->dialog_manager_->is_broadcast_channel(dialog_id)) {
    return promise.set_value(td_api::make_object<td_api::messageSenders>());
  }
  if (!td_->user_manager_->have_user(td_->user_manager_->get_my_id())) {
    auto new_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this), dialog_id, promise = std::move(promise)](Result<Unit> &&result) mutable {
          if (result.is_error()) {
            promise.set_error(result.move_as_error());
          } else {
            send_closure_later(actor_id, &MessageQueryManager::get_paid_message_reaction_senders, dialog_id,
                               std::move(promise), false);
          }
        });
    td_->user_manager_->get_me(std::move(new_promise));
    return;
  }
  if (td_->chat_manager_->are_created_public_broadcasts_inited()) {
    auto senders = td_api::make_object<td_api::messageSenders>();
    const auto &created_public_broadcasts = td_->chat_manager_->get_created_public_broadcasts();
    auto add_sender = [&senders, td = td_](DialogId dialog_id) {
      senders->senders_.push_back(get_message_sender_object(td, dialog_id, "add_sender"));
      senders->total_count_++;
    };
    add_sender(td_->dialog_manager_->get_my_dialog_id());

    std::multimap<int64, ChannelId> sorted_channel_ids;
    for (auto channel_id : created_public_broadcasts) {
      int64 score = td_->chat_manager_->get_channel_participant_count(channel_id);
      sorted_channel_ids.emplace(-score, channel_id);
    };
    for (auto &channel_id : sorted_channel_ids) {
      add_sender(DialogId(channel_id.second));
    }
    return promise.set_value(std::move(senders));
  }

  CHECK(!is_recursive);
  auto new_promise = PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, promise = std::move(promise)](
                                                Result<td_api::object_ptr<td_api::chats>> &&result) mutable {
    if (result.is_error()) {
      promise.set_error(result.move_as_error());
    } else {
      send_closure_later(actor_id, &MessageQueryManager::get_paid_message_reaction_senders, dialog_id,
                         std::move(promise), true);
    }
  });
  td_->chat_manager_->get_created_public_dialogs(PublicDialogType::ForPersonalDialog, std::move(new_promise), true);
}

void MessageQueryManager::get_discussion_message(DialogId dialog_id, MessageId message_id, DialogId expected_dialog_id,
                                                 MessageId expected_message_id, Promise<MessageThreadInfo> &&promise) {
  td_->create_handler<GetDiscussionMessageQuery>(std::move(promise))
      ->send(dialog_id, message_id, expected_dialog_id, expected_message_id);
}

void MessageQueryManager::process_discussion_message(
    telegram_api::object_ptr<telegram_api::messages_discussionMessage> &&result, DialogId dialog_id,
    MessageId message_id, DialogId expected_dialog_id, MessageId expected_message_id,
    Promise<MessageThreadInfo> promise) {
  LOG(INFO) << "Receive discussion message for " << message_id << " in " << dialog_id << " with expected "
            << expected_message_id << " in " << expected_dialog_id << ": " << to_string(result);
  td_->user_manager_->on_get_users(std::move(result->users_), "process_discussion_message");
  td_->chat_manager_->on_get_chats(std::move(result->chats_), "process_discussion_message");

  for (auto &message : result->messages_) {
    auto message_dialog_id = DialogId::get_message_dialog_id(message);
    if (message_dialog_id != expected_dialog_id) {
      return promise.set_error(Status::Error(500, "Expected messages in a different chat"));
    }
  }

  for (auto &message : result->messages_) {
    if (td_->messages_manager_->need_channel_difference_to_add_message(expected_dialog_id, message)) {
      auto max_message_id = MessageId::get_max_message_id(result->messages_);
      return td_->messages_manager_->run_after_channel_difference(
          expected_dialog_id, max_message_id,
          PromiseCreator::lambda([actor_id = actor_id(this), result = std::move(result), dialog_id, message_id,
                                  expected_dialog_id, expected_message_id,
                                  promise = std::move(promise)](Unit ignored) mutable {
            send_closure(actor_id, &MessageQueryManager::process_discussion_message_impl, std::move(result), dialog_id,
                         message_id, expected_dialog_id, expected_message_id, std::move(promise));
          }),
          "process_discussion_message");
    }
  }

  process_discussion_message_impl(std::move(result), dialog_id, message_id, expected_dialog_id, expected_message_id,
                                  std::move(promise));
}

void MessageQueryManager::process_discussion_message_impl(
    telegram_api::object_ptr<telegram_api::messages_discussionMessage> &&result, DialogId dialog_id,
    MessageId message_id, DialogId expected_dialog_id, MessageId expected_message_id,
    Promise<MessageThreadInfo> promise) {
  TRY_STATUS_PROMISE(promise, G()->close_status());

  MessageThreadInfo message_thread_info;
  message_thread_info.dialog_id = expected_dialog_id;
  message_thread_info.unread_message_count = max(0, result->unread_count_);
  MessageId top_message_id;
  for (auto &message : result->messages_) {
    auto message_full_id = td_->messages_manager_->on_get_message(std::move(message), false, true, false,
                                                                  "process_discussion_message_impl");
    if (message_full_id.get_message_id().is_valid()) {
      CHECK(message_full_id.get_dialog_id() == expected_dialog_id);
      message_thread_info.message_ids.push_back(message_full_id.get_message_id());
      if (message_full_id.get_message_id() == expected_message_id) {
        top_message_id = expected_message_id;
      }
    }
  }
  if (!message_thread_info.message_ids.empty() && !top_message_id.is_valid()) {
    top_message_id = message_thread_info.message_ids.back();
  }
  auto max_message_id = MessageId(ServerMessageId(result->max_id_));
  auto last_read_inbox_message_id = MessageId(ServerMessageId(result->read_inbox_max_id_));
  auto last_read_outbox_message_id = MessageId(ServerMessageId(result->read_outbox_max_id_));
  if (top_message_id.is_valid()) {
    td_->messages_manager_->on_update_read_message_comments(expected_dialog_id, top_message_id, max_message_id,
                                                            last_read_inbox_message_id, last_read_outbox_message_id,
                                                            message_thread_info.unread_message_count);
  }
  if (expected_dialog_id != dialog_id) {
    td_->messages_manager_->on_update_read_message_comments(dialog_id, message_id, max_message_id,
                                                            last_read_inbox_message_id, last_read_outbox_message_id,
                                                            message_thread_info.unread_message_count);
  }
  promise.set_value(std::move(message_thread_info));
}

class MessageQueryManager::BlockMessageSenderFromRepliesOnServerLogEvent {
 public:
  MessageId message_id_;
  bool delete_message_;
  bool delete_all_messages_;
  bool report_spam_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(delete_message_);
    STORE_FLAG(delete_all_messages_);
    STORE_FLAG(report_spam_);
    END_STORE_FLAGS();

    td::store(message_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(delete_message_);
    PARSE_FLAG(delete_all_messages_);
    PARSE_FLAG(report_spam_);
    END_PARSE_FLAGS();

    td::parse(message_id_, parser);
  }
};

uint64 MessageQueryManager::save_block_message_sender_from_replies_on_server_log_event(MessageId message_id,
                                                                                       bool need_delete_message,
                                                                                       bool need_delete_all_messages,
                                                                                       bool report_spam) {
  BlockMessageSenderFromRepliesOnServerLogEvent log_event{message_id, need_delete_message, need_delete_all_messages,
                                                          report_spam};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::BlockMessageSenderFromRepliesOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::block_message_sender_from_replies_on_server(MessageId message_id, bool need_delete_message,
                                                                      bool need_delete_all_messages, bool report_spam,
                                                                      uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    log_event_id = save_block_message_sender_from_replies_on_server_log_event(message_id, need_delete_message,
                                                                              need_delete_all_messages, report_spam);
  }

  td_->create_handler<BlockFromRepliesQuery>(get_erase_log_event_promise(log_event_id, std::move(promise)))
      ->send(message_id, need_delete_message, need_delete_all_messages, report_spam);
}

class MessageQueryManager::DeleteAllCallMessagesOnServerLogEvent {
 public:
  bool revoke_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(revoke_);
    END_STORE_FLAGS();
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(revoke_);
    END_PARSE_FLAGS();
  }
};

uint64 MessageQueryManager::save_delete_all_call_messages_on_server_log_event(bool revoke) {
  DeleteAllCallMessagesOnServerLogEvent log_event{revoke};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteAllCallMessagesOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::delete_all_call_messages_on_server(bool revoke, uint64 log_event_id,
                                                             Promise<Unit> &&promise) {
  if (log_event_id == 0) {
    log_event_id = save_delete_all_call_messages_on_server_log_event(revoke);
  }

  AffectedHistoryQuery query = [td = td_, revoke](DialogId /*dialog_id*/, Promise<AffectedHistory> &&query_promise) {
    td->create_handler<DeletePhoneCallHistoryQuery>(std::move(query_promise))->send(revoke);
  };
  run_affected_history_query_until_complete(DialogId(), std::move(query), false,
                                            get_erase_log_event_promise(log_event_id, std::move(promise)));
}

class MessageQueryManager::DeleteAllChannelMessagesFromSenderOnServerLogEvent {
 public:
  ChannelId channel_id_;
  DialogId sender_dialog_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(channel_id_, storer);
    td::store(sender_dialog_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(channel_id_, parser);
    if (parser.version() >= static_cast<int32>(Version::AddKeyboardButtonFlags)) {
      td::parse(sender_dialog_id_, parser);
    } else {
      UserId user_id;
      td::parse(user_id, parser);
      sender_dialog_id_ = DialogId(user_id);
    }
  }
};

uint64 MessageQueryManager::save_delete_all_channel_messages_by_sender_on_server_log_event(ChannelId channel_id,
                                                                                           DialogId sender_dialog_id) {
  DeleteAllChannelMessagesFromSenderOnServerLogEvent log_event{channel_id, sender_dialog_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteAllChannelMessagesFromSenderOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::delete_all_channel_messages_by_sender_on_server(ChannelId channel_id,
                                                                          DialogId sender_dialog_id,
                                                                          uint64 log_event_id,
                                                                          Promise<Unit> &&promise) {
  if (log_event_id == 0 && G()->use_chat_info_database()) {
    log_event_id = save_delete_all_channel_messages_by_sender_on_server_log_event(channel_id, sender_dialog_id);
  }

  AffectedHistoryQuery query = [td = td_, sender_dialog_id](DialogId dialog_id,
                                                            Promise<AffectedHistory> &&query_promise) {
    td->create_handler<DeleteParticipantHistoryQuery>(std::move(query_promise))
        ->send(dialog_id.get_channel_id(), sender_dialog_id);
  };
  run_affected_history_query_until_complete(DialogId(channel_id), std::move(query),
                                            sender_dialog_id.get_type() != DialogType::User,
                                            get_erase_log_event_promise(log_event_id, std::move(promise)));
}

class MessageQueryManager::DeleteDialogHistoryOnServerLogEvent {
 public:
  DialogId dialog_id_;
  MessageId max_message_id_;
  bool remove_from_dialog_list_;
  bool revoke_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(remove_from_dialog_list_);
    STORE_FLAG(revoke_);
    END_STORE_FLAGS();

    td::store(dialog_id_, storer);
    td::store(max_message_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(remove_from_dialog_list_);
    PARSE_FLAG(revoke_);
    END_PARSE_FLAGS();

    td::parse(dialog_id_, parser);
    td::parse(max_message_id_, parser);
  }
};

uint64 MessageQueryManager::save_delete_dialog_history_on_server_log_event(DialogId dialog_id, MessageId max_message_id,
                                                                           bool remove_from_dialog_list, bool revoke) {
  DeleteDialogHistoryOnServerLogEvent log_event{dialog_id, max_message_id, remove_from_dialog_list, revoke};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteDialogHistoryOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::delete_dialog_history_on_server(DialogId dialog_id, MessageId max_message_id,
                                                          bool remove_from_dialog_list, bool revoke, bool allow_error,
                                                          uint64 log_event_id, Promise<Unit> &&promise) {
  LOG(INFO) << "Delete history in " << dialog_id << " up to " << max_message_id << " from server";

  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id =
        save_delete_dialog_history_on_server_log_event(dialog_id, max_message_id, remove_from_dialog_list, revoke);
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat: {
      AffectedHistoryQuery query = [td = td_, max_message_id, remove_from_dialog_list, revoke](
                                       DialogId dialog_id, Promise<AffectedHistory> &&query_promise) {
        td->create_handler<DeleteHistoryQuery>(std::move(query_promise))
            ->send(dialog_id, max_message_id, remove_from_dialog_list, revoke);
      };
      run_affected_history_query_until_complete(dialog_id, std::move(query), false, std::move(promise));
      break;
    }
    case DialogType::Channel:
      td_->create_handler<DeleteChannelHistoryQuery>(std::move(promise))
          ->send(dialog_id.get_channel_id(), max_message_id, allow_error, revoke);
      break;
    case DialogType::SecretChat:
      send_closure(G()->secret_chats_manager(), &SecretChatsManager::delete_all_messages,
                   dialog_id.get_secret_chat_id(), std::move(promise));
      break;
    case DialogType::None:
    default:
      UNREACHABLE();
      break;
  }
}

class MessageQueryManager::DeleteDialogMessagesByDateOnServerLogEvent {
 public:
  DialogId dialog_id_;
  int32 min_date_;
  int32 max_date_;
  bool revoke_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(revoke_);
    END_STORE_FLAGS();
    td::store(dialog_id_, storer);
    td::store(min_date_, storer);
    td::store(max_date_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(revoke_);
    END_PARSE_FLAGS();
    td::parse(dialog_id_, parser);
    td::parse(min_date_, parser);
    td::parse(max_date_, parser);
  }
};

uint64 MessageQueryManager::save_delete_dialog_messages_by_date_on_server_log_event(DialogId dialog_id, int32 min_date,
                                                                                    int32 max_date, bool revoke) {
  DeleteDialogMessagesByDateOnServerLogEvent log_event{dialog_id, min_date, max_date, revoke};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteDialogMessagesByDateOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::delete_dialog_messages_by_date_on_server(DialogId dialog_id, int32 min_date, int32 max_date,
                                                                   bool revoke, uint64 log_event_id,
                                                                   Promise<Unit> &&promise) {
  if (log_event_id == 0 && G()->use_chat_info_database()) {
    log_event_id = save_delete_dialog_messages_by_date_on_server_log_event(dialog_id, min_date, max_date, revoke);
  }

  AffectedHistoryQuery query = [td = td_, min_date, max_date, revoke](DialogId dialog_id,
                                                                      Promise<AffectedHistory> &&query_promise) {
    td->create_handler<DeleteMessagesByDateQuery>(std::move(query_promise))
        ->send(dialog_id, min_date, max_date, revoke);
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), true,
                                            get_erase_log_event_promise(log_event_id, std::move(promise)));
}

class MessageQueryManager::DeleteMessagesOnServerLogEvent {
 public:
  DialogId dialog_id_;
  vector<MessageId> message_ids_;
  bool revoke_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(revoke_);
    END_STORE_FLAGS();

    td::store(dialog_id_, storer);
    td::store(message_ids_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(revoke_);
    END_PARSE_FLAGS();

    td::parse(dialog_id_, parser);
    td::parse(message_ids_, parser);
  }
};

uint64 MessageQueryManager::save_delete_messages_on_server_log_event(DialogId dialog_id,
                                                                     const vector<MessageId> &message_ids,
                                                                     bool revoke) {
  DeleteMessagesOnServerLogEvent log_event{dialog_id, message_ids, revoke};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteMessagesOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::erase_delete_messages_log_event(uint64 log_event_id) {
  if (!G()->close_flag()) {
    binlog_erase(G()->td_db()->get_binlog(), log_event_id);
  }
}

void MessageQueryManager::delete_messages_on_server(DialogId dialog_id, vector<MessageId> message_ids, bool revoke,
                                                    uint64 log_event_id, Promise<Unit> &&promise) {
  if (message_ids.empty()) {
    return promise.set_value(Unit());
  }
  LOG(INFO) << (revoke ? "Revoke " : "Delete ") << message_ids << " in " << dialog_id << " from server";

  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_delete_messages_on_server_log_event(dialog_id, message_ids, revoke);
  }

  MultiPromiseActorSafe mpas{"DeleteMessagesOnServerMultiPromiseActor"};
  mpas.add_promise(std::move(promise));
  if (log_event_id != 0) {
    mpas.add_promise(PromiseCreator::lambda([actor_id = actor_id(this), log_event_id](Unit) {
      send_closure(actor_id, &MessageQueryManager::erase_delete_messages_log_event, log_event_id);
    }));
  }
  auto lock = mpas.get_promise();
  auto dialog_type = dialog_id.get_type();
  switch (dialog_type) {
    case DialogType::User:
    case DialogType::Chat:
    case DialogType::Channel: {
      auto server_message_ids = MessageId::get_server_message_ids(message_ids);
      const size_t MAX_SLICE_SIZE = 100;  // server-side limit
      for (auto &slice_server_message_ids : vector_split(std::move(server_message_ids), MAX_SLICE_SIZE)) {
        if (dialog_type != DialogType::Channel) {
          td_->create_handler<DeleteMessagesQuery>(mpas.get_promise())
              ->send(dialog_id, std::move(slice_server_message_ids), revoke);
        } else {
          td_->create_handler<DeleteChannelMessagesQuery>(mpas.get_promise())
              ->send(dialog_id.get_channel_id(), std::move(slice_server_message_ids));
        }
      }
      break;
    }
    case DialogType::SecretChat: {
      vector<int64> random_ids;
      for (auto &message_id : message_ids) {
        auto random_id = td_->messages_manager_->get_message_random_id({dialog_id, message_id});
        if (random_id != 0) {
          random_ids.push_back(random_id);
        }
      }
      if (!random_ids.empty()) {
        send_closure(G()->secret_chats_manager(), &SecretChatsManager::delete_messages, dialog_id.get_secret_chat_id(),
                     std::move(random_ids), mpas.get_promise());
      }
      break;
    }
    case DialogType::None:
    default:
      UNREACHABLE();
  }
  lock.set_value(Unit());
}

class MessageQueryManager::DeleteScheduledMessagesOnServerLogEvent {
 public:
  DialogId dialog_id_;
  vector<MessageId> message_ids_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
    td::store(message_ids_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
    td::parse(message_ids_, parser);
  }
};

uint64 MessageQueryManager::save_delete_scheduled_messages_on_server_log_event(DialogId dialog_id,
                                                                               const vector<MessageId> &message_ids) {
  DeleteScheduledMessagesOnServerLogEvent log_event{dialog_id, message_ids};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteScheduledMessagesOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::delete_scheduled_messages_on_server(DialogId dialog_id, vector<MessageId> message_ids,
                                                              uint64 log_event_id, Promise<Unit> &&promise) {
  if (message_ids.empty()) {
    return promise.set_value(Unit());
  }
  LOG(INFO) << "Delete " << message_ids << " in " << dialog_id << " from server";

  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_delete_scheduled_messages_on_server_log_event(dialog_id, message_ids);
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  td_->create_handler<DeleteScheduledMessagesQuery>(std::move(promise))->send(dialog_id, std::move(message_ids));
}

class MessageQueryManager::DeleteTopicHistoryOnServerLogEvent {
 public:
  DialogId dialog_id_;
  MessageId top_thread_message_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    END_STORE_FLAGS();
    td::store(dialog_id_, storer);
    td::store(top_thread_message_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    END_PARSE_FLAGS();
    td::parse(dialog_id_, parser);
    td::parse(top_thread_message_id_, parser);
  }
};

uint64 MessageQueryManager::save_delete_topic_history_on_server_log_event(DialogId dialog_id,
                                                                          MessageId top_thread_message_id) {
  DeleteTopicHistoryOnServerLogEvent log_event{dialog_id, top_thread_message_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::DeleteTopicHistoryOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::delete_topic_history_on_server(DialogId dialog_id, MessageId top_thread_message_id,
                                                         uint64 log_event_id, Promise<Unit> &&promise) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_delete_topic_history_on_server_log_event(dialog_id, top_thread_message_id);
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  AffectedHistoryQuery query = [td = td_, top_thread_message_id](DialogId dialog_id,
                                                                 Promise<AffectedHistory> &&query_promise) {
    td->create_handler<DeleteTopicHistoryQuery>(std::move(query_promise))->send(dialog_id, top_thread_message_id);
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), true, std::move(promise));
}

void MessageQueryManager::read_all_topic_mentions_on_server(DialogId dialog_id, MessageId top_thread_message_id,
                                                            uint64 log_event_id, Promise<Unit> &&promise) {
  AffectedHistoryQuery query = [td = td_, top_thread_message_id](DialogId dialog_id,
                                                                 Promise<AffectedHistory> &&query_promise) {
    td->create_handler<ReadMentionsQuery>(std::move(query_promise))->send(dialog_id, top_thread_message_id);
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), true, std::move(promise));
}

class MessageQueryManager::ReadAllDialogMentionsOnServerLogEvent {
 public:
  DialogId dialog_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
  }
};

uint64 MessageQueryManager::save_read_all_dialog_mentions_on_server_log_event(DialogId dialog_id) {
  ReadAllDialogMentionsOnServerLogEvent log_event{dialog_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ReadAllDialogMentionsOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::read_all_dialog_mentions_on_server(DialogId dialog_id, uint64 log_event_id,
                                                             Promise<Unit> &&promise) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_read_all_dialog_mentions_on_server_log_event(dialog_id);
  }

  AffectedHistoryQuery query = [td = td_](DialogId dialog_id, Promise<AffectedHistory> &&query_promise) {
    td->create_handler<ReadMentionsQuery>(std::move(query_promise))->send(dialog_id, MessageId());
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), false,
                                            get_erase_log_event_promise(log_event_id, std::move(promise)));
}

void MessageQueryManager::read_all_topic_reactions_on_server(DialogId dialog_id, MessageId top_thread_message_id,
                                                             uint64 log_event_id, Promise<Unit> &&promise) {
  AffectedHistoryQuery query = [td = td_, top_thread_message_id](DialogId dialog_id,
                                                                 Promise<AffectedHistory> &&query_promise) {
    td->create_handler<ReadReactionsQuery>(std::move(query_promise))->send(dialog_id, top_thread_message_id);
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), true, std::move(promise));
}

class MessageQueryManager::ReadAllDialogReactionsOnServerLogEvent {
 public:
  DialogId dialog_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
  }
};

uint64 MessageQueryManager::save_read_all_dialog_reactions_on_server_log_event(DialogId dialog_id) {
  ReadAllDialogReactionsOnServerLogEvent log_event{dialog_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ReadAllDialogReactionsOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::read_all_dialog_reactions_on_server(DialogId dialog_id, uint64 log_event_id,
                                                              Promise<Unit> &&promise) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_read_all_dialog_reactions_on_server_log_event(dialog_id);
  }

  AffectedHistoryQuery query = [td = td_](DialogId dialog_id, Promise<AffectedHistory> &&query_promise) {
    td->create_handler<ReadReactionsQuery>(std::move(query_promise))->send(dialog_id, MessageId());
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), false,
                                            get_erase_log_event_promise(log_event_id, std::move(promise)));
}

void MessageQueryManager::unpin_all_topic_messages_on_server(DialogId dialog_id, MessageId top_thread_message_id,
                                                             uint64 log_event_id, Promise<Unit> &&promise) {
  AffectedHistoryQuery query = [td = td_, top_thread_message_id](DialogId dialog_id,
                                                                 Promise<AffectedHistory> &&query_promise) {
    td->create_handler<UnpinAllMessagesQuery>(std::move(query_promise))->send(dialog_id, top_thread_message_id);
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), true, std::move(promise));
}

class MessageQueryManager::ReadMessageContentsOnServerLogEvent {
 public:
  DialogId dialog_id_;
  vector<MessageId> message_ids_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
    td::store(message_ids_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
    td::parse(message_ids_, parser);
  }
};

uint64 MessageQueryManager::save_read_message_contents_on_server_log_event(DialogId dialog_id,
                                                                           const vector<MessageId> &message_ids) {
  ReadMessageContentsOnServerLogEvent log_event{dialog_id, message_ids};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::ReadMessageContentsOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::read_message_contents_on_server(DialogId dialog_id, vector<MessageId> message_ids,
                                                          uint64 log_event_id, Promise<Unit> &&promise,
                                                          bool skip_log_event) {
  CHECK(!message_ids.empty());

  LOG(INFO) << "Read contents of " << message_ids << " in " << dialog_id << " on server";

  if (log_event_id == 0 && G()->use_message_database() && !skip_log_event) {
    log_event_id = save_read_message_contents_on_server_log_event(dialog_id, message_ids);
  }

  auto new_promise = get_erase_log_event_promise(log_event_id, std::move(promise));
  promise = std::move(new_promise);  // to prevent self-move

  switch (dialog_id.get_type()) {
    case DialogType::User:
    case DialogType::Chat:
      td_->create_handler<ReadMessagesContentsQuery>(std::move(promise))->send(std::move(message_ids));
      break;
    case DialogType::Channel:
      td_->create_handler<ReadChannelMessagesContentsQuery>(std::move(promise))
          ->send(dialog_id.get_channel_id(), std::move(message_ids));
      break;
    case DialogType::SecretChat: {
      CHECK(message_ids.size() == 1);
      auto random_id = td_->messages_manager_->get_message_random_id({dialog_id, message_ids[0]});
      if (random_id != 0) {
        send_closure(G()->secret_chats_manager(), &SecretChatsManager::send_open_message,
                     dialog_id.get_secret_chat_id(), random_id, std::move(promise));
      } else {
        promise.set_error(Status::Error(400, "Message not found"));
      }
      break;
    }
    case DialogType::None:
    default:
      UNREACHABLE();
  }
}

bool MessageQueryManager::has_message_pending_read_reactions(MessageFullId message_full_id) const {
  return pending_read_reactions_.count(message_full_id) > 0;
}

void MessageQueryManager::read_message_reactions_on_server(DialogId dialog_id, vector<MessageId> message_ids) {
  for (auto message_id : message_ids) {
    pending_read_reactions_[{dialog_id, message_id}]++;
  }
  auto promise =
      PromiseCreator::lambda([actor_id = actor_id(this), dialog_id, message_ids](Result<Unit> &&result) mutable {
        send_closure(actor_id, &MessageQueryManager::on_read_message_reactions, dialog_id, std::move(message_ids),
                     std::move(result));
      });
  read_message_contents_on_server(dialog_id, std::move(message_ids), 0, std::move(promise));
}

void MessageQueryManager::on_read_message_reactions(DialogId dialog_id, vector<MessageId> &&message_ids,
                                                    Result<Unit> &&result) {
  for (auto message_id : message_ids) {
    MessageFullId message_full_id{dialog_id, message_id};
    auto it = pending_read_reactions_.find(message_full_id);
    CHECK(it != pending_read_reactions_.end());
    if (--it->second == 0) {
      pending_read_reactions_.erase(it);
    }

    if (!td_->messages_manager_->have_message_force(message_full_id, "on_read_message_reactions")) {
      continue;
    }

    if (result.is_error()) {
      queue_message_reactions_reload(message_full_id);
    }
  }
}

class MessageQueryManager::UnpinAllDialogMessagesOnServerLogEvent {
 public:
  DialogId dialog_id_;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(dialog_id_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(dialog_id_, parser);
  }
};

uint64 MessageQueryManager::save_unpin_all_dialog_messages_on_server_log_event(DialogId dialog_id) {
  UnpinAllDialogMessagesOnServerLogEvent log_event{dialog_id};
  return binlog_add(G()->td_db()->get_binlog(), LogEvent::HandlerType::UnpinAllDialogMessagesOnServer,
                    get_log_event_storer(log_event));
}

void MessageQueryManager::unpin_all_dialog_messages_on_server(DialogId dialog_id, uint64 log_event_id,
                                                              Promise<Unit> &&promise) {
  if (log_event_id == 0 && G()->use_message_database()) {
    log_event_id = save_unpin_all_dialog_messages_on_server_log_event(dialog_id);
  }

  AffectedHistoryQuery query = [td = td_](DialogId dialog_id, Promise<AffectedHistory> &&query_promise) {
    td->create_handler<UnpinAllMessagesQuery>(std::move(query_promise))->send(dialog_id, MessageId());
  };
  run_affected_history_query_until_complete(dialog_id, std::move(query), true,
                                            get_erase_log_event_promise(log_event_id, std::move(promise)));
}

void MessageQueryManager::on_binlog_events(vector<BinlogEvent> &&events) {
  if (G()->close_flag()) {
    return;
  }
  bool have_old_message_database = G()->use_message_database() && !G()->td_db()->was_dialog_db_created();
  for (auto &event : events) {
    CHECK(event.id_ != 0);
    switch (event.type_) {
      case LogEvent::HandlerType::BlockMessageSenderFromRepliesOnServer: {
        BlockMessageSenderFromRepliesOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        block_message_sender_from_replies_on_server(log_event.message_id_, log_event.delete_message_,
                                                    log_event.delete_all_messages_, log_event.report_spam_, event.id_,
                                                    Auto());
        break;
      }
      case LogEvent::HandlerType::DeleteAllCallMessagesOnServer: {
        DeleteAllCallMessagesOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        delete_all_call_messages_on_server(log_event.revoke_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::DeleteAllChannelMessagesFromSenderOnServer: {
        if (!G()->use_chat_info_database()) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        DeleteAllChannelMessagesFromSenderOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto channel_id = log_event.channel_id_;
        auto sender_dialog_id = log_event.sender_dialog_id_;
        Dependencies dependencies;
        dependencies.add(channel_id);
        dependencies.add_dialog_dependencies(sender_dialog_id);
        if (!dependencies.resolve_force(td_, "DeleteAllChannelMessagesFromSenderOnServer") ||
            !td_->dialog_manager_->have_input_peer(sender_dialog_id, false, AccessRights::Know)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          continue;
        }

        delete_all_channel_messages_by_sender_on_server(channel_id, sender_dialog_id, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::DeleteDialogHistoryOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        DeleteDialogHistoryOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "DeleteDialogHistoryOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        delete_dialog_history_on_server(dialog_id, log_event.max_message_id_, log_event.remove_from_dialog_list_,
                                        log_event.revoke_, true, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::DeleteDialogMessagesByDateOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        DeleteDialogMessagesByDateOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "DeleteDialogMessagesByDateOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        delete_dialog_messages_by_date_on_server(dialog_id, log_event.min_date_, log_event.max_date_, log_event.revoke_,
                                                 event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::DeleteMessagesOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        DeleteMessagesOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "DeleteMessagesOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        td_->messages_manager_->on_messages_deleted(dialog_id, log_event.message_ids_);

        delete_messages_on_server(dialog_id, std::move(log_event.message_ids_), log_event.revoke_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::DeleteScheduledMessagesOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        DeleteScheduledMessagesOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "DeleteScheduledMessagesOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        td_->messages_manager_->on_scheduled_messages_deleted(dialog_id, log_event.message_ids_);

        delete_scheduled_messages_on_server(dialog_id, std::move(log_event.message_ids_), event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::DeleteTopicHistoryOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        DeleteTopicHistoryOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "DeleteTopicHistoryOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        delete_topic_history_on_server(dialog_id, log_event.top_thread_message_id_, event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::ReadAllDialogMentionsOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ReadAllDialogMentionsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "ReadAllDialogMentionsOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        read_all_dialog_mentions_on_server(dialog_id, event.id_, Promise<Unit>());
        break;
      }
      case LogEvent::HandlerType::ReadAllDialogReactionsOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ReadAllDialogReactionsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "ReadAllDialogReactionsOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        read_all_dialog_reactions_on_server(dialog_id, event.id_, Promise<Unit>());
        break;
      }
      case LogEvent::HandlerType::ReadMessageContentsOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        ReadMessageContentsOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        auto dialog_id = log_event.dialog_id_;
        if (!td_->dialog_manager_->have_dialog_force(dialog_id, "ReadMessageContentsOnServerLogEvent") ||
            !td_->dialog_manager_->have_input_peer(dialog_id, true, AccessRights::Read)) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        read_message_contents_on_server(dialog_id, std::move(log_event.message_ids_), event.id_, Auto());
        break;
      }
      case LogEvent::HandlerType::UnpinAllDialogMessagesOnServer: {
        if (!have_old_message_database) {
          binlog_erase(G()->td_db()->get_binlog(), event.id_);
          break;
        }

        UnpinAllDialogMessagesOnServerLogEvent log_event;
        log_event_parse(log_event, event.get_data()).ensure();

        unpin_all_dialog_messages_on_server(log_event.dialog_id_, event.id_, Auto());
        break;
      }
      default:
        LOG(FATAL) << "Unsupported log event type " << event.type_;
    }
  }
}

}  // namespace td
