//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/DbKey.h"
#include "td/db/SqliteDb.h"

#include "td/actor/SchedulerLocalStorage.h"

#include "td/utils/common.h"
#include "td/utils/optional.h"

#include <atomic>

namespace td {

class SqliteConnectionSafe {
 public:
  SqliteConnectionSafe() = default;
  SqliteConnectionSafe(string path, DbKey key, optional<int32> cipher_version = {});

  SqliteDb &get();
  void set(SqliteDb &&db);

  void close();

  void close_and_destroy();

 private:
  string path_;
  std::atomic<uint32> close_state_{0};
  LazySchedulerLocalStorage<SqliteDb> lsls_connection_;
};

}  // namespace td
