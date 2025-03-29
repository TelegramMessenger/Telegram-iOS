//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/SqliteKeyValue.h"

#include "td/utils/base64.h"
#include "td/utils/logging.h"
#include "td/utils/ScopeGuard.h"

namespace td {

Status SqliteKeyValue::init_with_connection(SqliteDb connection, string table_name) {
  auto init_guard = ScopeExit() + [&] {
    close();
  };
  db_ = std::move(connection);
  table_name_ = std::move(table_name);
  TRY_STATUS(init(db_, table_name_));

  TRY_RESULT_ASSIGN(set_stmt_,
                    db_.get_statement(PSLICE() << "REPLACE INTO " << table_name_ << " (k, v) VALUES (?1, ?2)"));
  TRY_RESULT_ASSIGN(get_stmt_, db_.get_statement(PSLICE() << "SELECT v FROM " << table_name_ << " WHERE k = ?1"));
  TRY_RESULT_ASSIGN(erase_stmt_, db_.get_statement(PSLICE() << "DELETE FROM " << table_name_ << " WHERE k = ?1"));
  TRY_RESULT_ASSIGN(get_all_stmt_, db_.get_statement(PSLICE() << "SELECT k, v FROM " << table_name_));

  TRY_RESULT_ASSIGN(erase_by_prefix_stmt_,
                    db_.get_statement(PSLICE() << "DELETE FROM " << table_name_ << " WHERE ?1 <= k AND k < ?2"));
  TRY_RESULT_ASSIGN(erase_by_prefix_rare_stmt_,
                    db_.get_statement(PSLICE() << "DELETE FROM " << table_name_ << " WHERE ?1 <= k"));

  TRY_RESULT_ASSIGN(get_by_prefix_stmt_,
                    db_.get_statement(PSLICE() << "SELECT k, v FROM " << table_name_ << " WHERE ?1 <= k AND k < ?2"));
  TRY_RESULT_ASSIGN(get_by_prefix_rare_stmt_,
                    db_.get_statement(PSLICE() << "SELECT k, v FROM " << table_name_ << " WHERE ?1 <= k"));

  init_guard.dismiss();
  return Status::OK();
}

Status SqliteKeyValue::drop() {
  if (empty()) {
    return Status::OK();
  }

  auto result = drop(db_, table_name_);
  close();
  return result;
}

void SqliteKeyValue::set(Slice key, Slice value) {
  set_stmt_.bind_blob(1, key).ensure();
  set_stmt_.bind_blob(2, value).ensure();
  auto status = set_stmt_.step();
  if (status.is_error()) {
    LOG(FATAL) << "Failed to set \"" << base64_encode(key) << "\": " << status;
  }
  set_stmt_.reset();
}

void SqliteKeyValue::set_all(const FlatHashMap<string, string> &key_values) {
  begin_write_transaction().ensure();
  for (auto &key_value : key_values) {
    set(key_value.first, key_value.second);
  }
  commit_transaction().ensure();
}

string SqliteKeyValue::get(Slice key) {
  SCOPE_EXIT {
    get_stmt_.reset();
  };
  get_stmt_.bind_blob(1, key).ensure();
  get_stmt_.step().ensure();
  if (!get_stmt_.has_row()) {
    return string();
  }
  auto data = get_stmt_.view_blob(0).str();
  get_stmt_.step().ignore();
  return data;
}

void SqliteKeyValue::erase(Slice key) {
  erase_stmt_.bind_blob(1, key).ensure();
  erase_stmt_.step().ensure();
  erase_stmt_.reset();
}

void SqliteKeyValue::erase_batch(vector<string> keys) {
  for (auto &key : keys) {
    erase(key);
  }
}

void SqliteKeyValue::erase_by_prefix(Slice prefix) {
  auto next = next_prefix(prefix);
  if (next.empty()) {
    SCOPE_EXIT {
      erase_by_prefix_rare_stmt_.reset();
    };
    erase_by_prefix_rare_stmt_.bind_blob(1, prefix).ensure();
    erase_by_prefix_rare_stmt_.step().ensure();
  } else {
    SCOPE_EXIT {
      erase_by_prefix_stmt_.reset();
    };
    erase_by_prefix_stmt_.bind_blob(1, prefix).ensure();
    erase_by_prefix_stmt_.bind_blob(2, next).ensure();
    erase_by_prefix_stmt_.step().ensure();
  }
}

string SqliteKeyValue::next_prefix(Slice prefix) {
  string next = prefix.str();
  size_t pos = next.size();
  while (pos) {
    pos--;
    auto value = static_cast<uint8>(next[pos]);
    value++;
    next[pos] = static_cast<char>(value);
    if (value != 0) {
      return next;
    }
  }
  return string{};
}

}  // namespace td
