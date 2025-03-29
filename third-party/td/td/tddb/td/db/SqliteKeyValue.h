//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/SqliteDb.h"
#include "td/db/SqliteStatement.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

namespace td {

class SqliteKeyValue {
 public:
  static Status drop(SqliteDb &connection, Slice table_name) TD_WARN_UNUSED_RESULT {
    return connection.exec(PSLICE() << "DROP TABLE IF EXISTS " << table_name);
  }

  static Status init(SqliteDb &connection, Slice table_name) TD_WARN_UNUSED_RESULT {
    return connection.exec(PSLICE() << "CREATE TABLE IF NOT EXISTS " << table_name << " (k BLOB PRIMARY KEY, v BLOB)");
  }

  bool empty() const {
    return db_.empty();
  }

  Status init_with_connection(SqliteDb connection, string table_name) TD_WARN_UNUSED_RESULT;

  void close() {
    *this = SqliteKeyValue();
  }

  Status drop();

  void set(Slice key, Slice value);

  void set_all(const FlatHashMap<string, string> &key_values);

  string get(Slice key);

  void erase(Slice key);

  void erase_batch(vector<string> keys);

  Status begin_read_transaction() TD_WARN_UNUSED_RESULT {
    return db_.begin_read_transaction();
  }

  Status begin_write_transaction() TD_WARN_UNUSED_RESULT {
    return db_.begin_write_transaction();
  }

  Status commit_transaction() TD_WARN_UNUSED_RESULT {
    return db_.commit_transaction();
  }

  void erase_by_prefix(Slice prefix);

  FlatHashMap<string, string> get_all() {
    FlatHashMap<string, string> res;
    get_by_prefix("", [&](Slice key, Slice value) {
      CHECK(!key.empty());
      res.emplace(key.str(), value.str());
      return true;
    });
    return res;
  }

  template <class CallbackT>
  void get_by_prefix(Slice prefix, CallbackT &&callback) {
    string next;
    if (!prefix.empty()) {
      next = next_prefix(prefix);
    }
    get_by_range_impl(prefix, next, true, callback);
  }

  template <class CallbackT>
  void get_by_range(Slice from, Slice till, CallbackT &&callback) {
    get_by_range_impl(from, till, false, std::move(callback));
  }

 private:
  template <class CallbackT>
  void get_by_range_impl(Slice from, Slice till, bool strip_key_prefix, CallbackT &&callback) {
    SqliteStatement *stmt = nullptr;
    if (from.empty()) {
      stmt = &get_all_stmt_;
    } else {
      if (till.empty()) {
        stmt = &get_by_prefix_rare_stmt_;
        stmt->bind_blob(1, till).ensure();
      } else {
        stmt = &get_by_prefix_stmt_;
        stmt->bind_blob(1, from).ensure();
        stmt->bind_blob(2, till).ensure();
      }
    }
    auto guard = stmt->guard();
    stmt->step().ensure();
    while (stmt->has_row()) {
      auto key = stmt->view_blob(0);
      if (strip_key_prefix) {
        key.remove_prefix(from.size());
      }
      if (!callback(key, stmt->view_blob(1))) {
        return;
      }
      stmt->step().ensure();
    }
  }

  string table_name_;
  SqliteDb db_;
  SqliteStatement get_stmt_;
  SqliteStatement set_stmt_;
  SqliteStatement erase_stmt_;
  SqliteStatement get_all_stmt_;
  SqliteStatement erase_by_prefix_stmt_;
  SqliteStatement erase_by_prefix_rare_stmt_;
  SqliteStatement get_by_prefix_stmt_;
  SqliteStatement get_by_prefix_rare_stmt_;

  static string next_prefix(Slice prefix);
};

}  // namespace td
