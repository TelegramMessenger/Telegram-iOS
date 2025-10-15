//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
#include "td/utils/Status.h"

#include <tuple>
#include <type_traits>
#include <utility>

#if TD_OPENBSD || TD_SOLARIS
#include <pthread.h>
#endif
#include <sys/types.h>

#if TD_LINUX || TD_FREEBSD || TD_NETBSD
#define TD_HAVE_THREAD_AFFINITY 1
#endif

namespace td {
namespace detail {

class ThreadPthread {
 public:
  ThreadPthread() = default;
  ThreadPthread(const ThreadPthread &) = delete;
  ThreadPthread &operator=(const ThreadPthread &) = delete;
  ThreadPthread(ThreadPthread &&other) noexcept : is_inited_(std::move(other.is_inited_)), thread_(other.thread_) {
  }
  ThreadPthread &operator=(ThreadPthread &&other) noexcept {
    join();
    is_inited_ = std::move(other.is_inited_);
    thread_ = other.thread_;
    return *this;
  }
  template <class Function, class... Args>
  explicit ThreadPthread(Function &&f, Args &&...args) {
    auto func = create_destructor([args = std::make_tuple(decay_copy(std::forward<Function>(f)),
                                                          decay_copy(std::forward<Args>(args))...)]() mutable {
      invoke_tuple(std::move(args));
      clear_thread_locals();
    });
    do_pthread_create(&thread_, nullptr, run_thread, func.release());
    is_inited_ = true;
  }
  ~ThreadPthread() {
    join();
  }

  void set_name(CSlice name);

  void join();

  void detach();

  static unsigned hardware_concurrency();

  using id = pthread_t;

  id get_id() noexcept {
    return thread_;
  }

  static void send_real_time_signal(id thread_id, int real_time_signal_number);

#if TD_HAVE_THREAD_AFFINITY
  static Status set_affinity_mask(id thread_id, uint64 mask);

  static uint64 get_affinity_mask(id thread_id);
#endif

 private:
  MovableValue<bool> is_inited_;
  pthread_t thread_;

  template <class T>
  std::decay_t<T> decay_copy(T &&v) {
    return std::forward<T>(v);
  }

  static int do_pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void *),
                               void *arg);

  static void *run_thread(void *ptr) {
    ThreadIdGuard thread_id_guard;
    auto func = unique_ptr<Destructor>(static_cast<Destructor *>(ptr));
    return nullptr;
  }
};

namespace this_thread_pthread {
ThreadPthread::id get_id();
}  // namespace this_thread_pthread

}  // namespace detail
}  // namespace td

#endif
