//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/NotificationGroupId.h"
#include "td/telegram/NotificationGroupKey.h"

#include "td/db/KeyValueSyncInterface.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <memory>
#include <utility>

namespace td {

class SqliteConnectionSafe;
class SqliteDb;

struct DialogDbGetDialogsResult {
  vector<BufferSlice> dialogs;
  int64 next_order = 0;
  DialogId next_dialog_id;
};

class DialogDbSyncInterface {
 public:
  DialogDbSyncInterface() = default;
  DialogDbSyncInterface(const DialogDbSyncInterface &) = delete;
  DialogDbSyncInterface &operator=(const DialogDbSyncInterface &) = delete;
  virtual ~DialogDbSyncInterface() = default;

  virtual void add_dialog(DialogId dialog_id, FolderId folder_id, int64 order, BufferSlice data,
                          vector<NotificationGroupKey> notification_groups) = 0;

  virtual Result<BufferSlice> get_dialog(DialogId dialog_id) = 0;

  virtual DialogDbGetDialogsResult get_dialogs(FolderId folder_id, int64 order, DialogId dialog_id, int32 limit) = 0;

  virtual vector<NotificationGroupKey> get_notification_groups_by_last_notification_date(
      NotificationGroupKey notification_group_key, int32 limit) = 0;

  virtual Result<NotificationGroupKey> get_notification_group(NotificationGroupId notification_group_id) = 0;

  virtual int32 get_secret_chat_count(FolderId folder_id) = 0;

  virtual Status begin_read_transaction() = 0;
  virtual Status begin_write_transaction() = 0;
  virtual Status commit_transaction() = 0;
};

class DialogDbSyncSafeInterface {
 public:
  DialogDbSyncSafeInterface() = default;
  DialogDbSyncSafeInterface(const DialogDbSyncSafeInterface &) = delete;
  DialogDbSyncSafeInterface &operator=(const DialogDbSyncSafeInterface &) = delete;
  virtual ~DialogDbSyncSafeInterface() = default;

  virtual DialogDbSyncInterface &get() = 0;
};

class DialogDbAsyncInterface {
 public:
  DialogDbAsyncInterface() = default;
  DialogDbAsyncInterface(const DialogDbAsyncInterface &) = delete;
  DialogDbAsyncInterface &operator=(const DialogDbAsyncInterface &) = delete;
  virtual ~DialogDbAsyncInterface() = default;

  virtual void add_dialog(DialogId dialog_id, FolderId folder_id, int64 order, BufferSlice data,
                          vector<NotificationGroupKey> notification_groups, Promise<Unit> promise) = 0;

  virtual void get_dialog(DialogId dialog_id, Promise<BufferSlice> promise) = 0;

  virtual void get_dialogs(FolderId folder_id, int64 order, DialogId dialog_id, int32 limit,
                           Promise<DialogDbGetDialogsResult> promise) = 0;

  virtual void get_notification_groups_by_last_notification_date(NotificationGroupKey notification_group_key,
                                                                 int32 limit,
                                                                 Promise<vector<NotificationGroupKey>> promise) = 0;

  virtual void get_notification_group(NotificationGroupId notification_group_id,
                                      Promise<NotificationGroupKey> promise) = 0;

  virtual void get_secret_chat_count(FolderId folder_id, Promise<int32> promise) = 0;

  virtual void close(Promise<Unit> promise) = 0;

  virtual void force_flush() = 0;
};

Status init_dialog_db(SqliteDb &db, int version, KeyValueSyncInterface &binlog_pmc,
                      bool &was_created) TD_WARN_UNUSED_RESULT;
Status drop_dialog_db(SqliteDb &db, int version) TD_WARN_UNUSED_RESULT;

std::shared_ptr<DialogDbSyncSafeInterface> create_dialog_db_sync(
    std::shared_ptr<SqliteConnectionSafe> sqlite_connection);

std::shared_ptr<DialogDbAsyncInterface> create_dialog_db_async(std::shared_ptr<DialogDbSyncSafeInterface> sync_db,
                                                               int32 scheduler_id = -1);

}  // namespace td
