//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/SqliteConnectionSafe.h"
#include "td/db/SqliteKeyValue.h"

#include "td/actor/SchedulerLocalStorage.h"

#include "td/utils/common.h"

#include <memory>

namespace td {

class SqliteKeyValueSafe {
 public:
  SqliteKeyValueSafe(string name, std::shared_ptr<SqliteConnectionSafe> safe_connection)
      : lsls_kv_([name = std::move(name), safe_connection = std::move(safe_connection)] {
        SqliteKeyValue kv;
        kv.init_with_connection(safe_connection->get().clone(), name).ensure();
        return kv;
      }) {
  }
  SqliteKeyValue &get() {
    return lsls_kv_.get();
  }
  void close() {
    lsls_kv_.clear_values();
  }

 private:
  LazySchedulerLocalStorage<SqliteKeyValue> lsls_kv_;
};

}  // namespace td
