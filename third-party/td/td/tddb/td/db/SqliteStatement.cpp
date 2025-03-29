//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/SqliteStatement.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/StringBuilder.h"

#include "sqlite/sqlite3.h"

namespace td {

int VERBOSITY_NAME(sqlite) = VERBOSITY_NAME(DEBUG) + 10;

namespace {
int printExplainQueryPlan(StringBuilder &sb, tdsqlite3_stmt *pStmt) {
  const char *zSql = tdsqlite3_sql(pStmt);
  if (zSql == nullptr) {
    return SQLITE_ERROR;
  }

  sb << "Explain query " << zSql;
  char *zExplain = tdsqlite3_mprintf("EXPLAIN QUERY PLAN %s", zSql);
  if (zExplain == nullptr) {
    return SQLITE_NOMEM;
  }

  tdsqlite3_stmt *pExplain; /* Compiled EXPLAIN QUERY PLAN command */
  int rc = tdsqlite3_prepare_v2(tdsqlite3_db_handle(pStmt), zExplain, -1, &pExplain, nullptr);
  tdsqlite3_free(zExplain);
  if (rc != SQLITE_OK) {
    return rc;
  }

  while (SQLITE_ROW == tdsqlite3_step(pExplain)) {
    int iSelectid = tdsqlite3_column_int(pExplain, 0);
    int iOrder = tdsqlite3_column_int(pExplain, 1);
    int iFrom = tdsqlite3_column_int(pExplain, 2);
    const char *zDetail = reinterpret_cast<const char *>(tdsqlite3_column_text(pExplain, 3));

    sb << '\n' << iSelectid << ' ' << iOrder << ' ' << iFrom << ' ' << zDetail;
  }

  return tdsqlite3_finalize(pExplain);
}
}  // namespace

SqliteStatement::SqliteStatement(tdsqlite3_stmt *stmt, std::shared_ptr<detail::RawSqliteDb> db)
    : stmt_(stmt), db_(std::move(db)) {
  CHECK(stmt != nullptr);
}
SqliteStatement::~SqliteStatement() = default;

Result<string> SqliteStatement::explain() {
  if (empty()) {
    return Status::Error("No statement");
  }
  auto tmp = StackAllocator::alloc(10000);
  StringBuilder sb(tmp.as_slice());
  auto code = printExplainQueryPlan(sb, stmt_.get());
  if (code != SQLITE_OK) {
    return last_error();
  }
  if (sb.is_error()) {
    return Status::Error("StringBuilder buffer overflow");
  }
  return sb.as_cslice().str();
}
Status SqliteStatement::bind_blob(int id, Slice blob) {
  auto rc = tdsqlite3_bind_blob(stmt_.get(), id, blob.data(), static_cast<int>(blob.size()), nullptr);
  if (rc != SQLITE_OK) {
    return last_error();
  }
  return Status::OK();
}
Status SqliteStatement::bind_string(int id, Slice str) {
  auto rc = tdsqlite3_bind_text(stmt_.get(), id, str.data(), static_cast<int>(str.size()), nullptr);
  if (rc != SQLITE_OK) {
    return last_error();
  }
  return Status::OK();
}

Status SqliteStatement::bind_int32(int id, int32 value) {
  auto rc = tdsqlite3_bind_int(stmt_.get(), id, value);
  if (rc != SQLITE_OK) {
    return last_error();
  }
  return Status::OK();
}
Status SqliteStatement::bind_int64(int id, int64 value) {
  auto rc = tdsqlite3_bind_int64(stmt_.get(), id, value);
  if (rc != SQLITE_OK) {
    return last_error();
  }
  return Status::OK();
}
Status SqliteStatement::bind_null(int id) {
  auto rc = tdsqlite3_bind_null(stmt_.get(), id);
  if (rc != SQLITE_OK) {
    return last_error();
  }
  return Status::OK();
}

StringBuilder &operator<<(StringBuilder &sb, SqliteStatement::Datatype type) {
  using Datatype = SqliteStatement::Datatype;
  switch (type) {
    case Datatype::Integer:
      return sb << "Integer";
    case Datatype::Float:
      return sb << "Float";
    case Datatype::Blob:
      return sb << "Blob";
    case Datatype::Null:
      return sb << "Null";
    case Datatype::Text:
      return sb << "Text";
  }
  UNREACHABLE();
  return sb;
}
Slice SqliteStatement::view_blob(int id) {
  LOG_IF(ERROR, view_datatype(id) != Datatype::Blob) << view_datatype(id);
  auto *data = tdsqlite3_column_blob(stmt_.get(), id);
  auto size = tdsqlite3_column_bytes(stmt_.get(), id);
  if (data == nullptr) {
    return Slice();
  }
  return Slice(static_cast<const char *>(data), size);
}
Slice SqliteStatement::view_string(int id) {
  LOG_IF(ERROR, view_datatype(id) != Datatype::Text) << view_datatype(id);
  auto *data = tdsqlite3_column_text(stmt_.get(), id);
  auto size = tdsqlite3_column_bytes(stmt_.get(), id);
  if (data == nullptr) {
    return Slice();
  }
  return Slice(data, size);
}
int32 SqliteStatement::view_int32(int id) {
  LOG_IF(ERROR, view_datatype(id) != Datatype::Integer) << view_datatype(id);
  return tdsqlite3_column_int(stmt_.get(), id);
}
int64 SqliteStatement::view_int64(int id) {
  LOG_IF(ERROR, view_datatype(id) != Datatype::Integer) << view_datatype(id);
  return tdsqlite3_column_int64(stmt_.get(), id);
}
SqliteStatement::Datatype SqliteStatement::view_datatype(int id) {
  auto type = tdsqlite3_column_type(stmt_.get(), id);
  switch (type) {
    case SQLITE_INTEGER:
      return Datatype::Integer;
    case SQLITE_FLOAT:
      return Datatype::Float;
    case SQLITE_BLOB:
      return Datatype::Blob;
    case SQLITE_NULL:
      return Datatype::Null;
    case SQLITE3_TEXT:
      return Datatype::Text;
    default:
      UNREACHABLE();
  }
}

void SqliteStatement::reset() {
  tdsqlite3_reset(stmt_.get());
  state_ = State::Start;
}

Status SqliteStatement::step() {
  if (state_ == State::Finish) {
    return Status::Error("One has to reset statement");
  }
  VLOG(sqlite) << "Start step " << tag("query", tdsqlite3_sql(stmt_.get())) << tag("statement", stmt_.get())
               << tag("database", db_.get());
  auto rc = tdsqlite3_step(stmt_.get());
  VLOG(sqlite) << "Finish step with response " << (rc == SQLITE_ROW ? "ROW" : (rc == SQLITE_DONE ? "DONE" : "ERROR"));
  if (rc == SQLITE_ROW) {
    state_ = State::HaveRow;
    return Status::OK();
  }

  state_ = State::Finish;
  if (rc == SQLITE_DONE) {
    return Status::OK();
  }
  return last_error();
}

void SqliteStatement::StmtDeleter::operator()(tdsqlite3_stmt *stmt) {
  tdsqlite3_finalize(stmt);
}

Status SqliteStatement::last_error() {
  return db_->last_error();
}

}  // namespace td
