//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogInterface.h"
#include "td/db/DbKey.h"
#include "td/db/KeyValueSyncInterface.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <functional>
#include <memory>

namespace td {

class Binlog;
template <class BinlogT>
class BinlogKeyValue;
class ConcurrentBinlog;
class DialogDbSyncInterface;
class DialogDbSyncSafeInterface;
class DialogDbAsyncInterface;
class FileDbInterface;
class MessageDbSyncInterface;
class MessageDbSyncSafeInterface;
class MessageDbAsyncInterface;
class MessageThreadDbSyncInterface;
class MessageThreadDbSyncSafeInterface;
class MessageThreadDbAsyncInterface;
class SqliteConnectionSafe;
class SqliteKeyValueSafe;
class SqliteKeyValueAsyncInterface;
class SqliteKeyValue;
class StoryDbSyncInterface;
class StoryDbSyncSafeInterface;
class StoryDbAsyncInterface;

class TdDb {
 public:
  TdDb();
  TdDb(const TdDb &) = delete;
  TdDb &operator=(const TdDb &) = delete;
  TdDb(TdDb &&) = delete;
  TdDb &operator=(TdDb &&) = delete;
  ~TdDb();

  struct Parameters {
    DbKey encryption_key_;
    string database_directory_;
    string files_directory_;
    bool is_test_dc_ = false;
    bool use_file_database_ = false;
    bool use_chat_info_database_ = false;
    bool use_message_database_ = false;
  };

  struct OpenedDatabase {
    unique_ptr<TdDb> database;

    vector<BinlogEvent> to_secret_chats_manager;
    vector<BinlogEvent> user_events;
    vector<BinlogEvent> chat_events;
    vector<BinlogEvent> channel_events;
    vector<BinlogEvent> secret_chat_events;
    vector<BinlogEvent> web_page_events;
    vector<BinlogEvent> save_app_log_events;
    vector<BinlogEvent> to_account_manager;
    vector<BinlogEvent> to_dialog_manager;
    vector<BinlogEvent> to_message_query_manager;
    vector<BinlogEvent> to_messages_manager;
    vector<BinlogEvent> to_notification_manager;
    vector<BinlogEvent> to_notification_settings_manager;
    vector<BinlogEvent> to_poll_manager;
    vector<BinlogEvent> to_story_manager;

    int64 since_last_open = 0;
  };
  static void open(int32 scheduler_id, Parameters parameters, Promise<OpenedDatabase> &&promise);

  static Status destroy(const Parameters &parameters);

  Slice get_database_directory() const {
    return parameters_.database_directory_;
  }

  Slice get_files_directory() const {
    return parameters_.files_directory_;
  }

  bool is_test_dc() const {
    return parameters_.is_test_dc_;
  }

  bool use_file_database() const {
    return parameters_.use_file_database_;
  }

  bool use_sqlite_pmc() const {
    return parameters_.use_file_database_;
  }

  bool use_chat_info_database() const {
    return parameters_.use_chat_info_database_;
  }

  bool use_message_database() const {
    return parameters_.use_message_database_;
  }

  bool was_dialog_db_created() const {
    return was_dialog_db_created_;
  }

  std::shared_ptr<FileDbInterface> get_file_db_shared();
  std::shared_ptr<SqliteConnectionSafe> &get_sqlite_connection_safe();
#define get_binlog() get_binlog_impl(__FILE__, __LINE__)
  BinlogInterface *get_binlog_impl(const char *file, int line);

  std::shared_ptr<KeyValueSyncInterface> get_binlog_pmc_shared();
  std::shared_ptr<KeyValueSyncInterface> get_config_pmc_shared();

#define get_binlog_pmc() get_binlog_pmc_impl(__FILE__, __LINE__)
  KeyValueSyncInterface *get_binlog_pmc_impl(const char *file, int line);
  KeyValueSyncInterface *get_config_pmc();

  SqliteKeyValue *get_sqlite_sync_pmc();
  SqliteKeyValueAsyncInterface *get_sqlite_pmc();

  void flush_all();

  void close(int32 scheduler_id, bool destroy_flag, Promise<Unit> on_finished);

  MessageDbSyncInterface *get_message_db_sync();
  MessageDbAsyncInterface *get_message_db_async();

  MessageThreadDbSyncInterface *get_message_thread_db_sync();
  MessageThreadDbAsyncInterface *get_message_thread_db_async();

  DialogDbSyncInterface *get_dialog_db_sync();
  DialogDbAsyncInterface *get_dialog_db_async();

  StoryDbSyncInterface *get_story_db_sync();
  StoryDbAsyncInterface *get_story_db_async();

  static DbKey as_db_key(string key);

  void change_key(DbKey key, Promise<> promise);

  void with_db_path(const std::function<void(CSlice)> &callback);

  Result<string> get_stats();

 private:
  Parameters parameters_;

  bool was_dialog_db_created_ = false;

  std::shared_ptr<SqliteConnectionSafe> sql_connection_;

  std::shared_ptr<FileDbInterface> file_db_;

  std::shared_ptr<SqliteKeyValueSafe> common_kv_safe_;
  unique_ptr<SqliteKeyValueAsyncInterface> common_kv_async_;

  std::shared_ptr<MessageDbSyncSafeInterface> message_db_sync_safe_;
  std::shared_ptr<MessageDbAsyncInterface> message_db_async_;

  std::shared_ptr<MessageThreadDbSyncSafeInterface> message_thread_db_sync_safe_;
  std::shared_ptr<MessageThreadDbAsyncInterface> message_thread_db_async_;

  std::shared_ptr<DialogDbSyncSafeInterface> dialog_db_sync_safe_;
  std::shared_ptr<DialogDbAsyncInterface> dialog_db_async_;

  std::shared_ptr<StoryDbSyncSafeInterface> story_db_sync_safe_;
  std::shared_ptr<StoryDbAsyncInterface> story_db_async_;

  std::shared_ptr<BinlogKeyValue<ConcurrentBinlog>> binlog_pmc_;
  std::shared_ptr<BinlogKeyValue<ConcurrentBinlog>> config_pmc_;
  std::shared_ptr<ConcurrentBinlog> binlog_;

  static void open_impl(Parameters parameters, Promise<OpenedDatabase> &&promise);

  static Status check_parameters(Parameters &parameters);

  Status init_sqlite(const Parameters &parameters, const DbKey &key, const DbKey &old_key,
                     BinlogKeyValue<Binlog> &binlog_pmc);

  void do_close(bool destroy_flag, Promise<Unit> on_finished);
};

}  // namespace td
