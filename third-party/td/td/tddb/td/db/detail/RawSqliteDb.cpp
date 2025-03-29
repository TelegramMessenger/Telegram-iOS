//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/detail/RawSqliteDb.h"

#include "sqlite/sqlite3.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"

#include <atomic>

namespace td {
namespace detail {

static std::atomic<bool> was_database_destroyed{false};

Status RawSqliteDb::last_error(tdsqlite3 *db, CSlice path) {
  return Status::Error(PSLICE() << Slice(tdsqlite3_errmsg(db)) << " for database \"" << path << '"');
}

Status RawSqliteDb::destroy(Slice path) {
  Status error;
  with_db_path(path, [&](auto path) {
    unlink(path).ignore();
    if (!ends_with(path, "-shm") && !stat(path).is_error()) {
      error = Status::Error(PSLICE() << "Failed to delete file \"" << path << '"');
    }
  });
  return error;
}

Status RawSqliteDb::last_error() {
  //If database was corrupted, try to delete it.
  auto code = tdsqlite3_errcode(db_);
  if (code == SQLITE_CORRUPT) {
    was_database_destroyed.store(true, std::memory_order_relaxed);
    destroy(path_).ignore();
  }

  return last_error(db_, path());
}

bool RawSqliteDb::was_any_database_destroyed() {
  return was_database_destroyed.load(std::memory_order_relaxed);
}

RawSqliteDb::~RawSqliteDb() {
  auto rc = tdsqlite3_close(db_);
  LOG_IF(FATAL, rc != SQLITE_OK) << last_error(db_, path());
}

}  // namespace detail
}  // namespace td
