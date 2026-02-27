//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AffectedHistory.h"
#include "td/telegram/BusinessConnectionId.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogListId.h"
#include "td/telegram/files/FileUploadId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSearchFilter.h"
#include "td/telegram/MessageThreadInfo.h"
#include "td/telegram/MessageViewer.h"
#include "td/telegram/Photo.h"
#include "td/telegram/SavedMessagesTopicId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <functional>
#include <memory>

namespace td {

struct BinlogEvent;
struct FormattedText;
struct MessageSearchOffset;
class Td;

class MessageQueryManager final : public Actor {
 public:
  MessageQueryManager(Td *td, ActorShared<> parent);

  using AffectedHistoryQuery = std::function<void(DialogId, Promise<AffectedHistory>)>;

  void run_affected_history_query_until_complete(DialogId dialog_id, AffectedHistoryQuery query,
                                                 bool get_affected_messages, Promise<Unit> &&promise);

  void upload_message_covers(BusinessConnectionId business_connection_id, DialogId dialog_id,
                             vector<const Photo *> covers, Promise<Unit> &&promise);

  void upload_message_cover(BusinessConnectionId business_connection_id, DialogId dialog_id, Photo photo,
                            FileUploadId file_upload_id, Promise<Unit> &&promise, vector<int> bad_parts = {});

  void complete_upload_message_cover(BusinessConnectionId business_connection_id, DialogId dialog_id, Photo photo,
                                     FileUploadId file_upload_id,
                                     telegram_api::object_ptr<telegram_api::MessageMedia> &&media_ptr,
                                     Promise<Unit> &&promise);

  void report_message_delivery(MessageFullId message_full_id, int32 until_date, bool from_push);

  void reload_message_extended_media(DialogId dialog_id, vector<MessageId> message_ids);

  void finish_get_message_extended_media(DialogId dialog_id, const vector<MessageId> &message_ids);

  void reload_message_fact_checks(DialogId dialog_id, vector<MessageId> message_ids);

  void set_message_fact_check(MessageFullId message_full_id, const FormattedText &fact_check_text,
                              Promise<Unit> &&promise);

  void search_messages(DialogListId dialog_list_id, bool ignore_folder_id, const string &query,
                       const string &offset_str, int32 limit, MessageSearchFilter filter,
                       td_api::object_ptr<td_api::SearchMessagesChatTypeFilter> &&dialog_type_filter, int32 min_date,
                       int32 max_date, Promise<td_api::object_ptr<td_api::foundMessages>> &&promise);

  void on_get_messages_search_result(const string &query, int32 offset_date, DialogId offset_dialog_id,
                                     MessageId offset_message_id, int32 limit, MessageSearchFilter filter,
                                     int32 min_date, int32 max_date, int32 total_count,
                                     vector<telegram_api::object_ptr<telegram_api::Message>> &&messages,
                                     int32 next_rate, Promise<td_api::object_ptr<td_api::foundMessages>> &&promise);

  void search_outgoing_document_messages(const string &query, int32 limit,
                                         Promise<td_api::object_ptr<td_api::foundMessages>> &&promise);

  void on_get_outgoing_document_messages(vector<telegram_api::object_ptr<telegram_api::Message>> &&messages,
                                         Promise<td_api::object_ptr<td_api::foundMessages>> &&promise);

  void search_hashtag_posts(string hashtag, string offset_str, int32 limit,
                            Promise<td_api::object_ptr<td_api::foundMessages>> &&promise);

  void on_get_hashtag_search_result(const string &hashtag, const MessageSearchOffset &old_offset, int32 limit,
                                    int32 total_count,
                                    vector<telegram_api::object_ptr<telegram_api::Message>> &&messages, int32 next_rate,
                                    Promise<td_api::object_ptr<td_api::foundMessages>> &&promise);

  void search_dialog_recent_location_messages(DialogId dialog_id, int32 limit,
                                              Promise<td_api::object_ptr<td_api::messages>> &&promise);

  void on_get_recent_locations(DialogId dialog_id, int32 limit, int32 total_count,
                               vector<telegram_api::object_ptr<telegram_api::Message>> &&messages,
                               Promise<td_api::object_ptr<td_api::messages>> &&promise);

  void get_dialog_message_position_from_server(DialogId dialog_id, MessageId message_id, MessageSearchFilter filter,
                                               MessageId top_thread_message_id,
                                               SavedMessagesTopicId saved_messages_topic_id, Promise<int32> &&promise);

  void get_message_read_date_from_server(MessageFullId message_full_id,
                                         Promise<td_api::object_ptr<td_api::MessageReadDate>> &&promise);

  void get_message_viewers(MessageFullId message_full_id,
                           Promise<td_api::object_ptr<td_api::messageViewers>> &&promise);

  void view_messages(DialogId dialog_id, const vector<MessageId> &message_ids, bool increment_view_counter);

  void finish_get_message_views(DialogId dialog_id, const vector<MessageId> &message_ids);

  void queue_message_reactions_reload(MessageFullId message_full_id);

  void queue_message_reactions_reload(DialogId dialog_id, const vector<MessageId> &message_ids);

  void try_reload_message_reactions(DialogId dialog_id, bool is_finished);

  bool has_message_pending_read_reactions(MessageFullId message_full_id) const;

  void get_paid_message_reaction_senders(DialogId dialog_id,
                                         Promise<td_api::object_ptr<td_api::messageSenders>> &&promise,
                                         bool is_recursive = false);

  void get_discussion_message(DialogId dialog_id, MessageId message_id, DialogId expected_dialog_id,
                              MessageId expected_message_id, Promise<MessageThreadInfo> &&promise);

  void process_discussion_message(telegram_api::object_ptr<telegram_api::messages_discussionMessage> &&result,
                                  DialogId dialog_id, MessageId message_id, DialogId expected_dialog_id,
                                  MessageId expected_message_id, Promise<MessageThreadInfo> promise);

  void block_message_sender_from_replies_on_server(MessageId message_id, bool need_delete_message,
                                                   bool need_delete_all_messages, bool report_spam, uint64 log_event_id,
                                                   Promise<Unit> &&promise);

  void delete_all_call_messages_on_server(bool revoke, uint64 log_event_id, Promise<Unit> &&promise);

  void delete_all_channel_messages_by_sender_on_server(ChannelId channel_id, DialogId sender_dialog_id,
                                                       uint64 log_event_id, Promise<Unit> &&promise);

  void delete_dialog_history_on_server(DialogId dialog_id, MessageId max_message_id, bool remove_from_dialog_list,
                                       bool revoke, bool allow_error, uint64 log_event_id, Promise<Unit> &&promise);

  void delete_dialog_messages_by_date_on_server(DialogId dialog_id, int32 min_date, int32 max_date, bool revoke,
                                                uint64 log_event_id, Promise<Unit> &&promise);

  void delete_messages_on_server(DialogId dialog_id, vector<MessageId> message_ids, bool revoke, uint64 log_event_id,
                                 Promise<Unit> &&promise);

  void delete_scheduled_messages_on_server(DialogId dialog_id, vector<MessageId> message_ids, uint64 log_event_id,
                                           Promise<Unit> &&promise);

  void delete_topic_history_on_server(DialogId dialog_id, MessageId top_thread_message_id, uint64 log_event_id,
                                      Promise<Unit> &&promise);

  void read_all_dialog_mentions_on_server(DialogId dialog_id, uint64 log_event_id, Promise<Unit> &&promise);

  void read_all_dialog_reactions_on_server(DialogId dialog_id, uint64 log_event_id, Promise<Unit> &&promise);

  void read_all_topic_mentions_on_server(DialogId dialog_id, MessageId top_thread_message_id, uint64 log_event_id,
                                         Promise<Unit> &&promise);

  void read_all_topic_reactions_on_server(DialogId dialog_id, MessageId top_thread_message_id, uint64 log_event_id,
                                          Promise<Unit> &&promise);

  void read_message_contents_on_server(DialogId dialog_id, vector<MessageId> message_ids, uint64 log_event_id,
                                       Promise<Unit> &&promise, bool skip_log_event = false);

  void read_message_reactions_on_server(DialogId dialog_id, vector<MessageId> message_ids);

  void unpin_all_dialog_messages_on_server(DialogId dialog_id, uint64 log_event_id, Promise<Unit> &&promise);

  void unpin_all_topic_messages_on_server(DialogId dialog_id, MessageId top_thread_message_id, uint64 log_event_id,
                                          Promise<Unit> &&promise);

  void on_binlog_events(vector<BinlogEvent> &&events);

 private:
  class BlockMessageSenderFromRepliesOnServerLogEvent;
  class DeleteAllCallMessagesOnServerLogEvent;
  class DeleteAllChannelMessagesFromSenderOnServerLogEvent;
  class DeleteDialogHistoryOnServerLogEvent;
  class DeleteDialogMessagesByDateOnServerLogEvent;
  class DeleteMessagesOnServerLogEvent;
  class DeleteScheduledMessagesOnServerLogEvent;
  class DeleteTopicHistoryOnServerLogEvent;
  class ReadAllDialogMentionsOnServerLogEvent;
  class ReadAllDialogReactionsOnServerLogEvent;
  class ReadMessageContentsOnServerLogEvent;
  class UnpinAllDialogMessagesOnServerLogEvent;

  class UploadCoverCallback;

  static constexpr int32 MAX_SEARCH_MESSAGES = 100;  // server-side limit

  struct BeingUploadedCover {
    BusinessConnectionId business_connection_id_;
    DialogId dialog_id_;
    Photo photo_;
    telegram_api::object_ptr<telegram_api::InputFile> input_file_;
    Promise<Unit> promise_;
  };

  void tear_down() final;

  void on_get_affected_history(DialogId dialog_id, AffectedHistoryQuery query, bool get_affected_messages,
                               AffectedHistory affected_history, Promise<Unit> &&promise);

  void on_upload_cover(FileUploadId file_upload_id, telegram_api::object_ptr<telegram_api::InputFile> input_file);

  void on_upload_cover_error(FileUploadId file_upload_id, Status status);

  void do_upload_cover(FileUploadId file_upload_id, BeingUploadedCover &&being_uploaded_cover);

  void on_reload_message_fact_checks(DialogId dialog_id, const vector<MessageId> &message_ids,
                                     Result<vector<telegram_api::object_ptr<telegram_api::factCheck>>> r_fact_checks);

  void on_get_message_viewers(DialogId dialog_id, MessageViewers message_viewers, bool is_recursive,
                              Promise<td_api::object_ptr<td_api::messageViewers>> &&promise);

  void on_read_message_reactions(DialogId dialog_id, vector<MessageId> &&message_ids, Result<Unit> &&result);

  void process_discussion_message_impl(telegram_api::object_ptr<telegram_api::messages_discussionMessage> &&result,
                                       DialogId dialog_id, MessageId message_id, DialogId expected_dialog_id,
                                       MessageId expected_message_id, Promise<MessageThreadInfo> promise);

  void erase_delete_messages_log_event(uint64 log_event_id);

  static uint64 save_block_message_sender_from_replies_on_server_log_event(MessageId message_id,
                                                                           bool need_delete_message,
                                                                           bool need_delete_all_messages,
                                                                           bool report_spam);

  static uint64 save_delete_all_call_messages_on_server_log_event(bool revoke);

  static uint64 save_delete_all_channel_messages_by_sender_on_server_log_event(ChannelId channel_id,
                                                                               DialogId sender_dialog_id);

  static uint64 save_delete_dialog_history_on_server_log_event(DialogId dialog_id, MessageId max_message_id,
                                                               bool remove_from_dialog_list, bool revoke);

  static uint64 save_delete_dialog_messages_by_date_on_server_log_event(DialogId dialog_id, int32 min_date,
                                                                        int32 max_date, bool revoke);

  static uint64 save_delete_messages_on_server_log_event(DialogId dialog_id, const vector<MessageId> &message_ids,
                                                         bool revoke);

  static uint64 save_delete_scheduled_messages_on_server_log_event(DialogId dialog_id,
                                                                   const vector<MessageId> &message_ids);

  static uint64 save_delete_topic_history_on_server_log_event(DialogId dialog_id, MessageId top_thread_message_id);

  static uint64 save_read_all_dialog_mentions_on_server_log_event(DialogId dialog_id);

  static uint64 save_read_all_dialog_reactions_on_server_log_event(DialogId dialog_id);

  static uint64 save_read_message_contents_on_server_log_event(DialogId dialog_id,
                                                               const vector<MessageId> &message_ids);

  static uint64 save_unpin_all_dialog_messages_on_server_log_event(DialogId dialog_id);

  FlatHashMap<FileUploadId, BeingUploadedCover, FileUploadIdHash> being_uploaded_covers_;

  FlatHashSet<MessageFullId, MessageFullIdHash> being_reloaded_extended_media_message_full_ids_;

  FlatHashSet<MessageFullId, MessageFullIdHash> being_reloaded_fact_checks_;

  FlatHashSet<MessageFullId, MessageFullIdHash> need_view_counter_increment_message_full_ids_;
  FlatHashSet<MessageFullId, MessageFullIdHash> being_reloaded_views_message_full_ids_;

  struct ReactionsToReload {
    FlatHashSet<MessageId, MessageIdHash> message_ids;
    bool is_request_sent = false;
  };
  FlatHashMap<DialogId, ReactionsToReload, DialogIdHash> being_reloaded_reactions_;

  FlatHashMap<MessageFullId, int32, MessageFullIdHash> pending_read_reactions_;

  std::shared_ptr<UploadCoverCallback> upload_cover_callback_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
