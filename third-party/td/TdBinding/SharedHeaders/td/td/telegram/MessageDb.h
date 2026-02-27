//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageSearchFilter.h"
#include "td/telegram/NotificationId.h"
#include "td/telegram/ServerMessageId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <memory>
#include <utility>

namespace td {

class SqliteConnectionSafe;
class SqliteDb;

struct MessageDbMessagesQuery {
  DialogId dialog_id;
  MessageSearchFilter filter{MessageSearchFilter::Empty};
  MessageId from_message_id;
  int32 offset{0};
  int32 limit{100};
};

struct MessageDbDialogMessage {
  MessageId message_id;
  BufferSlice data;
};

struct MessageDbMessage {
  DialogId dialog_id;
  MessageId message_id;
  BufferSlice data;
};

struct MessageDbDialogCalendarQuery {
  DialogId dialog_id;
  MessageSearchFilter filter{MessageSearchFilter::Empty};
  MessageId from_message_id;
  int32 tz_offset{0};
};

struct MessageDbCalendar {
  vector<MessageDbDialogMessage> messages;
  vector<int32> total_counts;
};

struct MessageDbGetDialogSparseMessagePositionsQuery {
  DialogId dialog_id;
  MessageSearchFilter filter{MessageSearchFilter::Empty};
  MessageId from_message_id;
  int32 limit{0};
};

struct MessageDbMessagePosition {
  int32 position;
  int32 date;
  MessageId message_id;
};

struct MessageDbMessagePositions {
  int32 total_count{0};
  vector<MessageDbMessagePosition> positions;
};

struct MessageDbFtsQuery {
  string query;
  DialogId dialog_id;
  MessageSearchFilter filter{MessageSearchFilter::Empty};
  int64 from_search_id{0};
  int32 limit{100};
};
struct MessageDbFtsResult {
  vector<MessageDbMessage> messages;
  int64 next_search_id{1};
};

struct MessageDbCallsQuery {
  MessageSearchFilter filter{MessageSearchFilter::Empty};
  int32 from_unique_message_id{0};
  int32 limit{100};
};

struct MessageDbCallsResult {
  vector<MessageDbMessage> messages;
};

class MessageDbSyncInterface {
 public:
  MessageDbSyncInterface() = default;
  MessageDbSyncInterface(const MessageDbSyncInterface &) = delete;
  MessageDbSyncInterface &operator=(const MessageDbSyncInterface &) = delete;
  virtual ~MessageDbSyncInterface() = default;

  virtual void add_message(MessageFullId message_full_id, ServerMessageId unique_message_id, DialogId sender_dialog_id,
                           int64 random_id, int32 ttl_expires_at, int32 index_mask, int64 search_id, string text,
                           NotificationId notification_id, MessageId top_thread_message_id, BufferSlice data) = 0;
  virtual void add_scheduled_message(MessageFullId message_full_id, BufferSlice data) = 0;

  virtual void delete_message(MessageFullId message_full_id) = 0;
  virtual void delete_all_dialog_messages(DialogId dialog_id, MessageId from_message_id) = 0;
  virtual void delete_dialog_messages_by_sender(DialogId dialog_id, DialogId sender_dialog_id) = 0;

  virtual Result<MessageDbDialogMessage> get_message(MessageFullId message_full_id) = 0;
  virtual Result<MessageDbMessage> get_message_by_unique_message_id(ServerMessageId unique_message_id) = 0;
  virtual Result<MessageDbDialogMessage> get_message_by_random_id(DialogId dialog_id, int64 random_id) = 0;
  virtual Result<MessageDbDialogMessage> get_dialog_message_by_date(DialogId dialog_id, MessageId first_message_id,
                                                                    MessageId last_message_id, int32 date) = 0;

  virtual MessageDbCalendar get_dialog_message_calendar(MessageDbDialogCalendarQuery query) = 0;

  virtual Result<MessageDbMessagePositions> get_dialog_sparse_message_positions(
      MessageDbGetDialogSparseMessagePositionsQuery query) = 0;

  virtual vector<MessageDbDialogMessage> get_messages(MessageDbMessagesQuery query) = 0;
  virtual vector<MessageDbDialogMessage> get_scheduled_messages(DialogId dialog_id, int32 limit) = 0;
  virtual vector<MessageDbDialogMessage> get_messages_from_notification_id(DialogId dialog_id,
                                                                           NotificationId from_notification_id,
                                                                           int32 limit) = 0;

  virtual vector<MessageDbMessage> get_expiring_messages(int32 expires_till, int32 limit) = 0;
  virtual MessageDbCallsResult get_calls(MessageDbCallsQuery query) = 0;
  virtual MessageDbFtsResult get_messages_fts(MessageDbFtsQuery query) = 0;

  virtual Status begin_write_transaction() = 0;
  virtual Status commit_transaction() = 0;
};

class MessageDbSyncSafeInterface {
 public:
  MessageDbSyncSafeInterface() = default;
  MessageDbSyncSafeInterface(const MessageDbSyncSafeInterface &) = delete;
  MessageDbSyncSafeInterface &operator=(const MessageDbSyncSafeInterface &) = delete;
  virtual ~MessageDbSyncSafeInterface() = default;

  virtual MessageDbSyncInterface &get() = 0;
};

class MessageDbAsyncInterface {
 public:
  MessageDbAsyncInterface() = default;
  MessageDbAsyncInterface(const MessageDbAsyncInterface &) = delete;
  MessageDbAsyncInterface &operator=(const MessageDbAsyncInterface &) = delete;
  virtual ~MessageDbAsyncInterface() = default;

  virtual void add_message(MessageFullId message_full_id, ServerMessageId unique_message_id, DialogId sender_dialog_id,
                           int64 random_id, int32 ttl_expires_at, int32 index_mask, int64 search_id, string text,
                           NotificationId notification_id, MessageId top_thread_message_id, BufferSlice data,
                           Promise<> promise) = 0;
  virtual void add_scheduled_message(MessageFullId message_full_id, BufferSlice data, Promise<> promise) = 0;

  virtual void delete_message(MessageFullId message_full_id, Promise<> promise) = 0;
  virtual void delete_all_dialog_messages(DialogId dialog_id, MessageId from_message_id, Promise<> promise) = 0;
  virtual void delete_dialog_messages_by_sender(DialogId dialog_id, DialogId sender_dialog_id, Promise<> promise) = 0;

  virtual void get_message(MessageFullId message_full_id, Promise<MessageDbDialogMessage> promise) = 0;
  virtual void get_message_by_unique_message_id(ServerMessageId unique_message_id,
                                                Promise<MessageDbMessage> promise) = 0;
  virtual void get_message_by_random_id(DialogId dialog_id, int64 random_id,
                                        Promise<MessageDbDialogMessage> promise) = 0;
  virtual void get_dialog_message_by_date(DialogId dialog_id, MessageId first_message_id, MessageId last_message_id,
                                          int32 date, Promise<MessageDbDialogMessage> promise) = 0;

  virtual void get_dialog_message_calendar(MessageDbDialogCalendarQuery query, Promise<MessageDbCalendar> promise) = 0;

  virtual void get_dialog_sparse_message_positions(MessageDbGetDialogSparseMessagePositionsQuery query,
                                                   Promise<MessageDbMessagePositions> promise) = 0;

  virtual void get_messages(MessageDbMessagesQuery query, Promise<vector<MessageDbDialogMessage>> promise) = 0;
  virtual void get_scheduled_messages(DialogId dialog_id, int32 limit,
                                      Promise<vector<MessageDbDialogMessage>> promise) = 0;
  virtual void get_messages_from_notification_id(DialogId dialog_id, NotificationId from_notification_id, int32 limit,
                                                 Promise<vector<MessageDbDialogMessage>> promise) = 0;

  virtual void get_calls(MessageDbCallsQuery, Promise<MessageDbCallsResult> promise) = 0;
  virtual void get_messages_fts(MessageDbFtsQuery query, Promise<MessageDbFtsResult> promise) = 0;

  virtual void get_expiring_messages(int32 expires_till, int32 limit, Promise<vector<MessageDbMessage>> promise) = 0;

  virtual void close(Promise<> promise) = 0;
  virtual void force_flush() = 0;
};

Status init_message_db(SqliteDb &db, int version) TD_WARN_UNUSED_RESULT;
Status drop_message_db(SqliteDb &db, int version) TD_WARN_UNUSED_RESULT;

std::shared_ptr<MessageDbSyncSafeInterface> create_message_db_sync(
    std::shared_ptr<SqliteConnectionSafe> sqlite_connection);

std::shared_ptr<MessageDbAsyncInterface> create_message_db_async(std::shared_ptr<MessageDbSyncSafeInterface> sync_db,
                                                                 int32 scheduler_id = -1);

}  // namespace td
