//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileData.h"
#include "td/telegram/files/FileDbId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"
#include "td/utils/tl_storers.h"

#include <memory>

namespace td {

class SqliteDb;
class SqliteConnectionSafe;
class SqliteKeyValue;

Status drop_file_db(SqliteDb &db, int32 version) TD_WARN_UNUSED_RESULT;
Status init_file_db(SqliteDb &db, int32 version) TD_WARN_UNUSED_RESULT;

class FileDbInterface;
std::shared_ptr<FileDbInterface> create_file_db(std::shared_ptr<SqliteConnectionSafe> connection,
                                                int32 scheduler_id = -1) TD_WARN_UNUSED_RESULT;

class FileDbInterface {
 public:
  FileDbInterface() = default;
  FileDbInterface(const FileDbInterface &) = delete;
  FileDbInterface &operator=(const FileDbInterface &) = delete;
  virtual ~FileDbInterface() = default;

  // non-thread-safe
  virtual FileDbId get_next_file_db_id() = 0;

  // thread-safe
  virtual void close(Promise<> promise) = 0;

  template <class LocationT>
  static string as_key(const LocationT &object) {
    TlStorerCalcLength calc_length;
    calc_length.store_int(0);
    object.as_key().store(calc_length);

    BufferSlice key_buffer{calc_length.get_length()};
    auto key = key_buffer.as_mutable_slice();
    TlStorerUnsafe storer(key.ubegin());
    storer.store_int(LocationT::KEY_MAGIC);
    object.as_key().store(storer);
    CHECK(storer.get_buf() == key.uend());
    return key.str();
  }

  template <class LocationT>
  void get_file_data(const LocationT &location, Promise<FileData> promise) {
    get_file_data_impl(as_key(location), std::move(promise));
  }

  template <class LocationT>
  Result<FileData> get_file_data_sync(const LocationT &location) {
    auto res = get_file_data_sync_impl(as_key(location));
    if (res.is_ok()) {
      LOG(DEBUG) << "GET " << location << ": " << res.ok();
    } else {
      LOG(DEBUG) << "GET " << location << ": " << res.error();
    }
    return res;
  }

  virtual void clear_file_data(FileDbId file_db_id, const FileData &file_data) = 0;
  virtual void set_file_data(FileDbId file_db_id, const FileData &file_data, bool new_remote, bool new_local,
                             bool new_generate) = 0;
  virtual void set_file_data_ref(FileDbId file_db_id, FileDbId new_file_db_id) = 0;

  // For FileStatsWorker. TODO: remove it
  virtual SqliteKeyValue &pmc() = 0;

 private:
  virtual void get_file_data_impl(string key, Promise<FileData> promise) = 0;
  virtual Result<FileData> get_file_data_sync_impl(string key) = 0;
};

}  // namespace td
