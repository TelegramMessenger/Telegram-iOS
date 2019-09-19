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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/port/config.h"

#ifdef TD_THREAD_PTHREAD

#include "td/utils/common.h"
#include "td/utils/Destructor.h"
#include "td/utils/invoke.h"
#include "td/utils/MovableValue.h"
#include "td/utils/port/detail/ThreadIdGuard.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"

#include <tuple>
#include <type_traits>
#include <utility>

#include <pthread.h>
#include <sched.h>

namespace td {
namespace detail {
class ThreadPthread {
 public:
  ThreadPthread() = default;
  ThreadPthread(const ThreadPthread &other) = delete;
  ThreadPthread &operator=(const ThreadPthread &other) = delete;
  ThreadPthread(ThreadPthread &&) = default;
  ThreadPthread &operator=(ThreadPthread &&other) {
    join();
    is_inited_ = std::move(other.is_inited_);
    thread_ = other.thread_;
    return *this;
  }
  template <class Function, class... Args>
  explicit ThreadPthread(Function &&f, Args &&... args) {
    auto func = create_destructor([args = std::make_tuple(decay_copy(std::forward<Function>(f)),
                                                          decay_copy(std::forward<Args>(args))...)]() mutable {
      invoke_tuple(std::move(args));
      clear_thread_locals();
    });
    pthread_create(&thread_, nullptr, run_thread, func.release());
    is_inited_ = true;
  }
  void set_name(CSlice name) {
#if defined(_GNU_SOURCE) && defined(__GLIBC_PREREQ)
#if __GLIBC_PREREQ(2, 12)
    pthread_setname_np(thread_, name.c_str());
#endif
#endif
  }
  void join() {
    if (is_inited_.get()) {
      is_inited_ = false;
      pthread_join(thread_, nullptr);
    }
  }

  void detach() {
    if (is_inited_.get()) {
      is_inited_ = false;
      pthread_detach(thread_);
    }
  }
  ~ThreadPthread() {
    join();
  }

  static unsigned hardware_concurrency() {
    return 8;
  }

  using id = pthread_t;

 private:
  MovableValue<bool> is_inited_;
  pthread_t thread_;

  template <class T>
  std::decay_t<T> decay_copy(T &&v) {
    return std::forward<T>(v);
  }

  static void *run_thread(void *ptr) {
    ThreadIdGuard thread_id_guard;
    auto func = unique_ptr<Destructor>(static_cast<Destructor *>(ptr));
    return nullptr;
  }
};

namespace this_thread_pthread {
inline void yield() {
  sched_yield();
}
inline ThreadPthread::id get_id() {
  return pthread_self();
}
}  // namespace this_thread_pthread
}  // namespace detail
}  // namespace td

#endif
