//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <memory>
#include <utility>

namespace td {

class SqliteConnectionSafe;
class SqliteDb;

struct MessageThreadDbMessageThreads {
  vector<BufferSlice> message_threads;
  int64 next_order = 0;
};

class MessageThreadDbSyncInterface {
 public:
  MessageThreadDbSyncInterface() = default;
  MessageThreadDbSyncInterface(const MessageThreadDbSyncInterface &) = delete;
  MessageThreadDbSyncInterface &operator=(const MessageThreadDbSyncInterface &) = delete;
  virtual ~MessageThreadDbSyncInterface() = default;

  virtual void add_message_thread(DialogId dialog_id, MessageId top_thread_message_id, int64 order,
                                  BufferSlice data) = 0;

  virtual void delete_message_thread(DialogId dialog_id, MessageId top_thread_message_id) = 0;

  virtual void delete_all_dialog_message_threads(DialogId dialog_id) = 0;

  virtual BufferSlice get_message_thread(DialogId dialog_id, MessageId top_thread_message_id) = 0;

  virtual MessageThreadDbMessageThreads get_message_threads(DialogId dialog_id, int64 offset_order, int32 limit) = 0;

  virtual Status begin_write_transaction() = 0;

  virtual Status commit_transaction() = 0;
};

class MessageThreadDbSyncSafeInterface {
 public:
  MessageThreadDbSyncSafeInterface() = default;
  MessageThreadDbSyncSafeInterface(const MessageThreadDbSyncSafeInterface &) = delete;
  MessageThreadDbSyncSafeInterface &operator=(const MessageThreadDbSyncSafeInterface &) = delete;
  virtual ~MessageThreadDbSyncSafeInterface() = default;

  virtual MessageThreadDbSyncInterface &get() = 0;
};

class MessageThreadDbAsyncInterface {
 public:
  MessageThreadDbAsyncInterface() = default;
  MessageThreadDbAsyncInterface(const MessageThreadDbAsyncInterface &) = delete;
  MessageThreadDbAsyncInterface &operator=(const MessageThreadDbAsyncInterface &) = delete;
  virtual ~MessageThreadDbAsyncInterface() = default;

  virtual void add_message_thread(DialogId dialog_id, MessageId top_thread_message_id, int64 order, BufferSlice data,
                                  Promise<Unit> promise) = 0;

  virtual void delete_message_thread(DialogId dialog_id, MessageId top_thread_message_id, Promise<Unit> promise) = 0;

  virtual void delete_all_dialog_message_threads(DialogId dialog_id, Promise<Unit> promise) = 0;

  virtual void get_message_thread(DialogId dialog_id, MessageId top_thread_message_id,
                                  Promise<BufferSlice> promise) = 0;

  virtual void get_message_threads(DialogId dialog_id, int64 offset_order, int32 limit,
                                   Promise<MessageThreadDbMessageThreads> promise) = 0;

  virtual void close(Promise<Unit> promise) = 0;

  virtual void force_flush() = 0;
};

Status init_message_thread_db(SqliteDb &db, int version) TD_WARN_UNUSED_RESULT;

Status drop_message_thread_db(SqliteDb &db, int version) TD_WARN_UNUSED_RESULT;

std::shared_ptr<MessageThreadDbSyncSafeInterface> create_message_thread_db_sync(
    std::shared_ptr<SqliteConnectionSafe> sqlite_connection);

std::shared_ptr<MessageThreadDbAsyncInterface> create_message_thread_db_async(
    std::shared_ptr<MessageThreadDbSyncSafeInterface> sync_db, int32 scheduler_id = -1);

}  // namespace td
