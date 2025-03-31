//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/SqliteConnectionSafe.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"

namespace td {

SqliteConnectionSafe::SqliteConnectionSafe(string path, DbKey key, optional<int32> cipher_version)
    : path_(std::move(path))
    , lsls_connection_([path = path_, close_state_ptr = &close_state_, key = std::move(key),
                        cipher_version = std::move(cipher_version)] {
      auto r_db = SqliteDb::open_with_key(path, false, key, cipher_version.copy());
      if (r_db.is_error()) {
        LOG(FATAL) << "Can't open database in state " << close_state_ptr->load() << ": " << r_db.error().message();
      }
      auto db = r_db.move_as_ok();
      db.exec("PRAGMA journal_mode=WAL").ensure();
      db.exec("PRAGMA secure_delete=1").ensure();
      return db;
    }) {
}

void SqliteConnectionSafe::set(SqliteDb &&db) {
  lsls_connection_.set(std::move(db));
}

SqliteDb &SqliteConnectionSafe::get() {
  return lsls_connection_.get();
}

void SqliteConnectionSafe::close() {
  LOG(INFO) << "Close SQLite database " << tag("path", path_);
  close_state_++;
  lsls_connection_.clear_values();
}

void SqliteConnectionSafe::close_and_destroy() {
  close();
  LOG(INFO) << "Destroy SQLite database " << tag("path", path_);
  close_state_ += 65536;
  SqliteDb::destroy(path_).ignore();
}

}  // namespace td
