//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/SqliteDb.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Timer.h"

#include "sqlite/sqlite3.h"

namespace td {

namespace {
string quote_string(Slice str) {
  size_t cnt = 0;
  for (auto &c : str) {
    if (c == '\'') {
      cnt++;
    }
  }
  if (cnt == 0) {
    return str.str();
  }

  string result;
  result.reserve(str.size() + cnt);
  for (auto &c : str) {
    if (c == '\'') {
      result += '\'';
    }
    result += c;
  }
  return result;
}

string db_key_to_sqlcipher_key(const DbKey &db_key) {
  if (db_key.is_empty()) {
    return "''";
  }
  if (db_key.is_password()) {
    return PSTRING() << "'" << quote_string(db_key.data()) << "'";
  }
  CHECK(db_key.is_raw_key());
  Slice raw_key = db_key.data();
  CHECK(raw_key.size() == 32);
  size_t expected_size = 64 + 5;
  string res(expected_size + 50, ' ');
  StringBuilder sb(res);
  sb << '"';
  sb << 'x';
  sb << '\'';
  sb << format::as_hex_dump<0>(raw_key);
  sb << '\'';
  sb << '"';
  CHECK(!sb.is_error());
  CHECK(sb.as_cslice().size() == expected_size);
  res.resize(expected_size);
  return res;
}
}  // namespace

SqliteDb::~SqliteDb() = default;

Status SqliteDb::init(CSlice path, bool allow_creation) {
  // if database does not exist, delete all other files which could have been left from the old database
  auto database_stat = stat(path);
  if (database_stat.is_error()) {
    if (!allow_creation) {
      bool was_destroyed = detail::RawSqliteDb::was_any_database_destroyed();
      auto reason = was_destroyed ? Slice("was corrupted and deleted") : Slice("disappeared");
      return Status::Error(PSLICE() << "Database " << reason
                                    << " during execution and can't be recreated: " << database_stat.error());
    }
    TRY_STATUS(destroy(path));
  }

  tdsqlite3 *db;
  CHECK(tdsqlite3_threadsafe() != 0);
  int rc =
      tdsqlite3_open_v2(path.c_str(), &db, SQLITE_OPEN_READWRITE | (allow_creation ? SQLITE_OPEN_CREATE : 0), nullptr);
  if (rc != SQLITE_OK) {
    auto res = detail::RawSqliteDb::last_error(db, path);
    tdsqlite3_close(db);
    return res;
  }
  tdsqlite3_busy_timeout(db, 1000 * 5 /* 5 seconds */);
  raw_ = std::make_shared<detail::RawSqliteDb>(db, path.str());
  return Status::OK();
}

static void trace_callback(void *ptr, const char *query) {
  LOG(ERROR) << query;
}

static int trace_v2_callback(unsigned code, void *ctx, void *p_raw, void *x_raw) {
  CHECK(code == SQLITE_TRACE_STMT);
  auto x = static_cast<const char *>(x_raw);
  if (x[0] == '-' && x[1] == '-') {
    trace_callback(ctx, x);
  } else {
    trace_callback(ctx, tdsqlite3_expanded_sql(static_cast<tdsqlite3_stmt *>(p_raw)));
  }

  return 0;
}

void SqliteDb::trace(bool flag) {
  tdsqlite3_trace_v2(raw_->db(), SQLITE_TRACE_STMT, flag ? trace_v2_callback : nullptr, nullptr);
}

Status SqliteDb::exec(CSlice cmd) {
  CHECK(!empty());
  char *msg;
  if (enable_logging_) {
    VLOG(sqlite) << "Start exec " << tag("query", cmd) << tag("database", raw_->db());
  }
  auto rc = tdsqlite3_exec(raw_->db(), cmd.c_str(), nullptr, nullptr, &msg);
  if (rc != SQLITE_OK) {
    CHECK(msg != nullptr);
    if (enable_logging_) {
      VLOG(sqlite) << "Finish exec with error " << msg;
    }
    return Status::Error(PSLICE() << tag("query", cmd) << " to database \"" << raw_->path() << "\" failed: " << msg);
  }
  CHECK(msg == nullptr);
  if (enable_logging_) {
    VLOG(sqlite) << "Finish exec";
  }
  return Status::OK();
}

Result<bool> SqliteDb::has_table(Slice table) {
  TRY_RESULT(stmt, get_statement(PSLICE() << "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='" << table
                                          << "'"));
  TRY_STATUS(stmt.step());
  CHECK(stmt.has_row());
  auto cnt = stmt.view_int32(0);
  return cnt == 1;
}

Result<string> SqliteDb::get_pragma(Slice name) {
  TRY_RESULT(stmt, get_statement(PSLICE() << "PRAGMA " << name));
  TRY_STATUS(stmt.step());
  CHECK(stmt.has_row());
  auto res = stmt.view_blob(0).str();
  TRY_STATUS(stmt.step());
  CHECK(!stmt.can_step());
  return std::move(res);
}

Result<string> SqliteDb::get_pragma_string(Slice name) {
  TRY_RESULT(stmt, get_statement(PSLICE() << "PRAGMA " << name));
  TRY_STATUS(stmt.step());
  CHECK(stmt.has_row());
  auto res = stmt.view_string(0).str();
  TRY_STATUS(stmt.step());
  CHECK(!stmt.can_step());
  return std::move(res);
}

Result<int32> SqliteDb::user_version() {
  TRY_RESULT(get_version_stmt, get_statement("PRAGMA user_version"));
  TRY_STATUS(get_version_stmt.step());
  if (!get_version_stmt.has_row()) {
    return Status::Error(PSLICE() << "PRAGMA user_version failed for database \"" << raw_->path() << '"');
  }
  return get_version_stmt.view_int32(0);
}

Status SqliteDb::set_user_version(int32 version) {
  return exec(PSLICE() << "PRAGMA user_version = " << version);
}

Status SqliteDb::begin_read_transaction() {
  if (raw_->on_begin()) {
    return exec("BEGIN");
  }
  return Status::OK();
}

Status SqliteDb::begin_write_transaction() {
  if (raw_->on_begin()) {
    return exec("BEGIN IMMEDIATE");
  }
  return Status::OK();
}

Status SqliteDb::commit_transaction() {
  TRY_RESULT(need_commit, raw_->on_commit());
  if (need_commit) {
    return exec("COMMIT");
  }
  return Status::OK();
}

Status SqliteDb::check_encryption() {
  auto status = exec("SELECT count(*) FROM sqlite_master");
  if (status.is_ok()) {
    enable_logging_ = true;
  }
  return status;
}

Result<SqliteDb> SqliteDb::open_with_key(CSlice path, bool allow_creation, const DbKey &db_key,
                                         optional<int32> cipher_version) {
  auto res = do_open_with_key(path, allow_creation, db_key, cipher_version ? cipher_version.value() : 0);
  if (res.is_error() && !cipher_version && !db_key.is_empty()) {
    return do_open_with_key(path, false, db_key, 3);
  }
  return res;
}

Result<SqliteDb> SqliteDb::do_open_with_key(CSlice path, bool allow_creation, const DbKey &db_key,
                                            int32 cipher_version) {
  SqliteDb db;
  TRY_STATUS(db.init(path, allow_creation));
  if (!db_key.is_empty()) {
    if (db.check_encryption().is_ok()) {
      return Status::Error(PSLICE() << "No key is needed for database \"" << path << '"');
    }
    auto key = db_key_to_sqlcipher_key(db_key);
    TRY_STATUS(db.exec(PSLICE() << "PRAGMA key = " << key));
    if (cipher_version != 0) {
      LOG(INFO) << "Trying SQLCipher compatibility mode with version = " << cipher_version;
      TRY_STATUS(db.exec(PSLICE() << "PRAGMA cipher_compatibility = " << cipher_version));
    }
    db.set_cipher_version(cipher_version);
  }
  TRY_STATUS_PREFIX(db.check_encryption(), "Can't check database: ");
  return std::move(db);
}

void SqliteDb::set_cipher_version(int32 cipher_version) {
  raw_->set_cipher_version(cipher_version);
}

optional<int32> SqliteDb::get_cipher_version() const {
  return raw_->get_cipher_version();
}

Result<SqliteDb> SqliteDb::change_key(CSlice path, bool allow_creation, const DbKey &new_db_key,
                                      const DbKey &old_db_key) {
  // fast path
  {
    PerfWarningTimer perf("open database", 0.05);
    auto r_db = open_with_key(path, allow_creation, new_db_key);
    if (r_db.is_ok()) {
      return r_db;
    }
  }

  PerfWarningTimer perf("change database key", 0.5);
  auto create_database = [](CSlice tmp_path) -> Status {
    TRY_STATUS(destroy(tmp_path));
    SqliteDb db;
    return db.init(tmp_path, true);
  };

  TRY_RESULT(db, open_with_key(path, false, old_db_key));
  TRY_RESULT(user_version, db.user_version());
  auto new_key = db_key_to_sqlcipher_key(new_db_key);
  if (old_db_key.is_empty() && !new_db_key.is_empty()) {
    LOG(DEBUG) << "ENCRYPT";
    PerfWarningTimer timer("Encrypt SQLite database", 0.1);
    auto tmp_path = path.str() + ".encrypted";
    TRY_STATUS(create_database(tmp_path));

    // make sure that database is not empty
    TRY_STATUS(db.exec("CREATE TABLE IF NOT EXISTS encryption_dummy_table(id INT PRIMARY KEY)"));
    TRY_STATUS(db.exec(PSLICE() << "ATTACH DATABASE '" << quote_string(tmp_path) << "' AS encrypted KEY " << new_key));
    TRY_STATUS(db.exec("SELECT sqlcipher_export('encrypted')"));
    TRY_STATUS(db.exec(PSLICE() << "PRAGMA encrypted.user_version = " << user_version));
    TRY_STATUS(db.exec("DETACH DATABASE encrypted"));
    db.close();
    TRY_STATUS(rename(tmp_path, path));
  } else if (!old_db_key.is_empty() && new_db_key.is_empty()) {
    LOG(DEBUG) << "DECRYPT";
    PerfWarningTimer timer("Decrypt SQLite database", 0.1);
    auto tmp_path = path.str() + ".encrypted";
    TRY_STATUS(create_database(tmp_path));

    TRY_STATUS(db.exec(PSLICE() << "ATTACH DATABASE '" << quote_string(tmp_path) << "' AS decrypted KEY ''"));
    TRY_STATUS(db.exec("SELECT sqlcipher_export('decrypted')"));
    TRY_STATUS(db.exec(PSLICE() << "PRAGMA decrypted.user_version = " << user_version));
    TRY_STATUS(db.exec("DETACH DATABASE decrypted"));
    db.close();
    TRY_STATUS(rename(tmp_path, path));
  } else {
    LOG(DEBUG) << "REKEY";
    PerfWarningTimer timer("Rekey SQLite database", 0.1);
    TRY_STATUS(db.exec(PSLICE() << "PRAGMA rekey = " << new_key));
  }

  TRY_RESULT(new_db, open_with_key(path, false, new_db_key));
  CHECK(new_db.user_version().ok() == user_version);
  return std::move(new_db);
}
Status SqliteDb::destroy(Slice path) {
  return detail::RawSqliteDb::destroy(path);
}

Result<SqliteStatement> SqliteDb::get_statement(CSlice statement) {
  tdsqlite3_stmt *stmt = nullptr;
  auto rc =
      tdsqlite3_prepare_v2(get_native(), statement.c_str(), static_cast<int>(statement.size()) + 1, &stmt, nullptr);
  if (rc != SQLITE_OK) {
    return Status::Error(PSLICE() << "Failed to prepare SQLite " << tag("statement", statement) << raw_->last_error());
  }
  LOG_CHECK(stmt != nullptr) << statement;
  return SqliteStatement(stmt, raw_);
}

}  // namespace td
