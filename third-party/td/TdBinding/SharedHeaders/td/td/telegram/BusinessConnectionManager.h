//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/MessageEffectId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageInputReplyTo.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/WaitFreeHashMap.h"

#include <memory>

namespace td {

struct InputMessageContent;
struct ReplyMarkup;
class Td;

class BusinessConnectionManager final : public Actor {
 public:
  BusinessConnectionManager(Td *td, ActorShared<> parent);
  BusinessConnectionManager(const BusinessConnectionManager &) = delete;
  BusinessConnectionManager &operator=(const BusinessConnectionManager &) = delete;
  BusinessConnectionManager(BusinessConnectionManager &&) = delete;
  BusinessConnectionManager &operator=(BusinessConnectionManager &&) = delete;
  ~BusinessConnectionManager() final;

  Status check_business_connection(const BusinessConnectionId &connection_id, DialogId dialog_id) const;

  DcId get_business_connection_dc_id(const BusinessConnectionId &connection_id) const;

  void on_update_bot_business_connect(telegram_api::object_ptr<telegram_api::botBusinessConnection> &&connection);

  void on_update_bot_new_business_message(const BusinessConnectionId &connection_id,
                                          telegram_api::object_ptr<telegram_api::Message> &&message,
                                          telegram_api::object_ptr<telegram_api::Message> &&reply_to_message);

  void on_update_bot_edit_business_message(const BusinessConnectionId &connection_id,
                                           telegram_api::object_ptr<telegram_api::Message> &&message,
                                           telegram_api::object_ptr<telegram_api::Message> &&reply_to_message);

  void on_update_bot_delete_business_messages(const BusinessConnectionId &connection_id, DialogId dialog_id,
                                              vector<int32> &&messages);

  void get_business_connection(const BusinessConnectionId &connection_id,
                               Promise<td_api::object_ptr<td_api::businessConnection>> &&promise);

  void send_message(BusinessConnectionId business_connection_id, DialogId dialog_id,
                    td_api::object_ptr<td_api::InputMessageReplyTo> &&reply_to, bool disable_notification,
                    bool protect_content, MessageEffectId effect_id,
                    td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                    td_api::object_ptr<td_api::InputMessageContent> &&input_message_content,
                    Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void send_message_album(BusinessConnectionId business_connection_id, DialogId dialog_id,
                          td_api::object_ptr<td_api::InputMessageReplyTo> &&reply_to, bool disable_notification,
                          bool protect_content, MessageEffectId effect_id,
                          vector<td_api::object_ptr<td_api::InputMessageContent>> &&input_message_contents,
                          Promise<td_api::object_ptr<td_api::businessMessages>> &&promise);

  void edit_business_message_text(BusinessConnectionId business_connection_id, DialogId dialog_id, MessageId message_id,
                                  td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                  td_api::object_ptr<td_api::InputMessageContent> &&input_message_content,
                                  Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void edit_business_message_live_location(BusinessConnectionId business_connection_id, DialogId dialog_id,
                                           MessageId message_id, td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                           td_api::object_ptr<td_api::location> &&input_location, int32 live_period,
                                           int32 heading, int32 proximity_alert_radius,
                                           Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void edit_business_message_media(BusinessConnectionId business_connection_id, DialogId dialog_id,
                                   MessageId message_id, td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                   td_api::object_ptr<td_api::InputMessageContent> &&input_message_content,
                                   Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void edit_business_message_caption(BusinessConnectionId business_connection_id, DialogId dialog_id,
                                     MessageId message_id, td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                     td_api::object_ptr<td_api::formattedText> &&input_caption, bool invert_media,
                                     Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void edit_business_message_reply_markup(BusinessConnectionId business_connection_id, DialogId dialog_id,
                                          MessageId message_id, td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                                          Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void stop_poll(BusinessConnectionId business_connection_id, DialogId dialog_id, MessageId message_id,
                 td_api::object_ptr<td_api::ReplyMarkup> &&reply_markup,
                 Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void get_current_state(vector<td_api::object_ptr<td_api::Update>> &updates) const;

 private:
  struct BusinessConnection;
  struct PendingMessage;
  class SendBusinessMessageQuery;
  class SendBusinessMediaQuery;
  class SendBusinessMultiMediaQuery;
  class UploadBusinessMediaQuery;
  class UploadMediaCallback;
  class UploadThumbnailCallback;
  class EditBusinessMessageQuery;
  class StopBusinessPollQuery;

  struct UploadMediaResult {
    unique_ptr<PendingMessage> message_;
    telegram_api::object_ptr<telegram_api::InputMedia> input_media_;
  };

  struct BeingUploadedMedia {
    unique_ptr<PendingMessage> message_;
    telegram_api::object_ptr<telegram_api::InputFile> input_file_;
    Promise<UploadMediaResult> promise_;
  };

  struct MediaGroupSendRequest {
    size_t finished_count_ = 0;
    vector<Result<UploadMediaResult>> upload_results_;
    Promise<td_api::object_ptr<td_api::businessMessages>> promise_;
    unique_ptr<PendingMessage> paid_media_message_;
    Promise<td_api::object_ptr<td_api::businessMessage>> paid_media_promise_;
  };

  void tear_down() final;

  Status check_business_message_id(MessageId message_id) const;

  void on_get_business_connection(const BusinessConnectionId &connection_id,
                                  Result<telegram_api::object_ptr<telegram_api::Updates>> r_updates);

  MessageInputReplyTo create_business_message_input_reply_to(
      td_api::object_ptr<td_api::InputMessageReplyTo> &&reply_to);

  Result<InputMessageContent> process_input_message_content(
      td_api::object_ptr<td_api::InputMessageContent> &&input_message_content);

  unique_ptr<PendingMessage> create_business_message_to_send(BusinessConnectionId business_connection_id,
                                                             DialogId dialog_id, MessageInputReplyTo &&input_reply_to,
                                                             bool disable_notification, bool protect_content,
                                                             MessageEffectId effect_id,
                                                             unique_ptr<ReplyMarkup> &&reply_markup,
                                                             InputMessageContent &&input_content) const;

  void do_send_message(unique_ptr<PendingMessage> &&message,
                       Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void process_sent_business_message(telegram_api::object_ptr<telegram_api::Updates> &&updates_ptr,
                                     Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void upload_media(unique_ptr<PendingMessage> &&message, Promise<UploadMediaResult> &&promise,
                    vector<int> bad_parts = {});

  void complete_send_media(unique_ptr<PendingMessage> &&message,
                           telegram_api::object_ptr<telegram_api::InputMedia> &&input_media,
                           Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void on_upload_media(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_media_error(FileUploadId file_upload_id, Status status);

  void on_upload_thumbnail(FileUploadId thumbnail_file_upload_id,
                           telegram_api::object_ptr<telegram_api::InputFile> thumbnail_input_file);

  void do_upload_media(BeingUploadedMedia &&being_uploaded_media,
                       telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail);

  void complete_upload_media(unique_ptr<PendingMessage> &&message,
                             telegram_api::object_ptr<telegram_api::MessageMedia> &&media,
                             Promise<UploadMediaResult> &&promise);

  int64 generate_new_media_album_id();

  void do_send_message_album(int64 request_id, BusinessConnectionId business_connection_id, DialogId dialog_id,
                             MessageInputReplyTo &&input_reply_to, bool disable_notification, bool protect_content,
                             MessageEffectId effect_id, vector<InputMessageContent> &&message_contents,
                             Promise<td_api::object_ptr<td_api::businessMessages>> &&promise);

  void on_upload_message_album_media(int64 request_id, size_t media_pos, Result<UploadMediaResult> &&result);

  void process_sent_business_message_album(telegram_api::object_ptr<telegram_api::Updates> &&updates_ptr,
                                           Promise<td_api::object_ptr<td_api::businessMessages>> &&promise);

  void on_upload_message_paid_media(int64 request_id, size_t media_pos, Result<UploadMediaResult> &&result);

  void on_fail_send_message(unique_ptr<PendingMessage> &&message, const Status &error);

  void do_edit_message_media(unique_ptr<PendingMessage> &&message,
                             Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  void do_edit_business_message_media(Result<UploadMediaResult> &&result,
                                      Promise<td_api::object_ptr<td_api::businessMessage>> &&promise);

  td_api::object_ptr<td_api::updateBusinessConnection> get_update_business_connection(
      const BusinessConnection *connection) const;

  WaitFreeHashMap<BusinessConnectionId, unique_ptr<BusinessConnection>, BusinessConnectionIdHash> business_connections_;

  FlatHashMap<BusinessConnectionId, vector<Promise<td_api::object_ptr<td_api::businessConnection>>>,
              BusinessConnectionIdHash>
      get_business_connection_queries_;

  int64 current_media_group_send_request_id_ = 0;
  FlatHashMap<int64, MediaGroupSendRequest> media_group_send_requests_;

  std::shared_ptr<UploadMediaCallback> upload_media_callback_;
  std::shared_ptr<UploadThumbnailCallback> upload_thumbnail_callback_;

  FlatHashMap<FileUploadId, BeingUploadedMedia, FileUploadIdHash> being_uploaded_files_;
  FlatHashMap<FileUploadId, BeingUploadedMedia, FileUploadIdHash> being_uploaded_thumbnails_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
