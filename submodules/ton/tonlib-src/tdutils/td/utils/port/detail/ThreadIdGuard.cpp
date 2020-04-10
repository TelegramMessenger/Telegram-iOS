/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "td/utils/port/detail/ThreadIdGuard.h"

#include "td/utils/common.h"
#include "td/utils/port/thread_local.h"

#include <mutex>
#include <set>

namespace td {
namespace detail {
class ThreadIdManager {
 public:
  int32 register_thread() {
    std::lock_guard<std::mutex> guard(mutex_);
    if (unused_thread_ids_.empty()) {
      return ++max_thread_id_;
    }
    auto it = unused_thread_ids_.begin();
    auto result = *it;
    unused_thread_ids_.erase(it);
    return result;
  }
  void unregister_thread(int32 thread_id) {
    std::lock_guard<std::mutex> guard(mutex_);
    CHECK(0 < thread_id && thread_id <= max_thread_id_);
    bool is_inserted = unused_thread_ids_.insert(thread_id).second;
    CHECK(is_inserted);
  }

 private:
  std::mutex mutex_;
  std::set<int32> unused_thread_ids_;
  int32 max_thread_id_ = 0;
};
static ThreadIdManager thread_id_manager;

ThreadIdGuard::ThreadIdGuard() {
  thread_id_ = thread_id_manager.register_thread();
  set_thread_id(thread_id_);
}
ThreadIdGuard::~ThreadIdGuard() {
  thread_id_manager.unregister_thread(thread_id_);
  set_thread_id(0);
}
}  // namespace detail
}  // namespace td
