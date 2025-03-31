//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/ThreadIdGuard.h"

#include "td/utils/common.h"
#include "td/utils/ExitGuard.h"
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
static ExitGuard exit_guard;

ThreadIdGuard::ThreadIdGuard() {
  thread_id_ = thread_id_manager.register_thread();
  set_thread_id(thread_id_);
}
ThreadIdGuard::~ThreadIdGuard() {
  if (!ExitGuard::is_exited()) {
    thread_id_manager.unregister_thread(thread_id_);
  }
  set_thread_id(0);
}
}  // namespace detail
}  // namespace td
