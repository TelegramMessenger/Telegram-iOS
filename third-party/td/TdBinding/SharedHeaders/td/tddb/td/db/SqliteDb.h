//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/DbKey.h"
#include "td/db/SqliteStatement.h"

#include "td/db/detail/RawSqliteDb.h"

#include "td/utils/common.h"
#include "td/utils/optional.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <memory>

struct tdsqlite3;

namespace td {

class SqliteDb {
 public:
  SqliteDb() = default;
  SqliteDb(SqliteDb &&) = default;
  SqliteDb &operator=(SqliteDb &&) = default;
  SqliteDb(const SqliteDb &) = delete;
  SqliteDb &operator=(const SqliteDb &) = delete;
  ~SqliteDb();

  // dangerous
  SqliteDb clone() const {
    return SqliteDb(raw_, enable_logging_);
  }

  bool empty() const {
    return !raw_;
  }
  void close() {
    *this = SqliteDb();
  }

  Status exec(CSlice cmd) TD_WARN_UNUSED_RESULT;
  Result<bool> has_table(Slice table);
  Result<string> get_pragma(Slice name);
  Result<string> get_pragma_string(Slice name);

  Status begin_read_transaction() TD_WARN_UNUSED_RESULT;
  Status begin_write_transaction() TD_WARN_UNUSED_RESULT;
  Status commit_transaction() TD_WARN_UNUSED_RESULT;

  Result<int32> user_version();
  Status set_user_version(int32 version) TD_WARN_UNUSED_RESULT;
  void trace(bool flag);

  static Status destroy(Slice path) TD_WARN_UNUSED_RESULT;

  // we can't change the key on the fly, so static functions are more than enough
  static Result<SqliteDb> open_with_key(CSlice path, bool allow_creation, const DbKey &db_key,
                                        optional<int32> cipher_version = {});
  static Result<SqliteDb> change_key(CSlice path, bool allow_creation, const DbKey &new_db_key,
                                     const DbKey &old_db_key);

  tdsqlite3 *get_native() const {
    return raw_->db();
  }

  Result<SqliteStatement> get_statement(CSlice statement) TD_WARN_UNUSED_RESULT;

  template <class F>
  static void with_db_path(Slice main_path, F &&f) {
    detail::RawSqliteDb::with_db_path(main_path, f);
  }

  optional<int32> get_cipher_version() const;

 private:
  SqliteDb(std::shared_ptr<detail::RawSqliteDb> raw, bool enable_logging)
      : raw_(std::move(raw)), enable_logging_(enable_logging) {
  }
  std::shared_ptr<detail::RawSqliteDb> raw_;
  bool enable_logging_ = false;

  Status init(CSlice path, bool allow_creation) TD_WARN_UNUSED_RESULT;

  Status check_encryption();
  static Result<SqliteDb> do_open_with_key(CSlice path, bool allow_creation, const DbKey &db_key, int32 cipher_version);
  void set_cipher_version(int32 cipher_version);
};

}  // namespace td
