//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/optional.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

struct tdsqlite3;

namespace td {
namespace detail {

class RawSqliteDb {
 public:
  RawSqliteDb(tdsqlite3 *db, std::string path) : db_(db), path_(std::move(path)) {
  }
  RawSqliteDb(const RawSqliteDb &) = delete;
  RawSqliteDb(RawSqliteDb &&) = delete;
  RawSqliteDb &operator=(const RawSqliteDb &) = delete;
  RawSqliteDb &operator=(RawSqliteDb &&) = delete;
  ~RawSqliteDb();

  template <class F>
  static void with_db_path(Slice main_path, F &&f) {
    f(PSLICE() << main_path);
    f(PSLICE() << main_path << "-journal");
    f(PSLICE() << main_path << "-wal");
    f(PSLICE() << main_path << "-shm");
  }
  static Status destroy(Slice path) TD_WARN_UNUSED_RESULT;

  tdsqlite3 *db() {
    return db_;
  }
  CSlice path() const {
    return path_;
  }

  Status last_error();
  static Status last_error(tdsqlite3 *db, CSlice path);

  static bool was_any_database_destroyed();

  bool on_begin() {
    begin_cnt_++;
    return begin_cnt_ == 1;
  }
  Result<bool> on_commit() {
    if (begin_cnt_ == 0) {
      return Status::Error("No matching begin for commit");
    }
    begin_cnt_--;
    return begin_cnt_ == 0;
  }

  void set_cipher_version(int32 cipher_version) {
    cipher_version_ = cipher_version;
  }

  optional<int32> get_cipher_version() const {
    return cipher_version_.copy();
  }

 private:
  tdsqlite3 *db_;
  std::string path_;
  size_t begin_cnt_{0};
  optional<int32> cipher_version_;
};

}  // namespace detail
}  // namespace td
