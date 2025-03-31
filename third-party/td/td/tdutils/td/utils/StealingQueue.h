//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/misc.h"

#include <array>
#include <atomic>

namespace td {

template <class T, size_t N = 256>
class StealingQueue {
 public:
  static_assert(N > 0 && (N & (N - 1)) == 0, "");

  // tries to put a value
  // returns if succeeded
  // only owner is allowed to to do this
  template <class F>
  void local_push(T value, F &&overflow_f) {
    while (true) {
      auto tail = tail_.load(std::memory_order_relaxed);
      auto head = head_.load();  // TODO: memory order

      if (static_cast<size_t>(tail - head) < N) {
        buf_[tail & MASK].store(value, std::memory_order_relaxed);
        tail_.store(tail + 1, std::memory_order_release);
        return;
      }

      // queue is full
      // TODO: batch insert into global queue?
      auto n = N / 2 + 1;
      auto new_head = head + n;
      if (!head_.compare_exchange_strong(head, new_head)) {
        continue;
      }

      for (size_t i = 0; i < n; i++) {
        overflow_f(buf_[(i + head) & MASK].load(std::memory_order_relaxed));
      }
      overflow_f(value);

      return;
    }
  }

  // tries to pop a value
  // returns if succeeded
  // only owner is allowed to do this
  bool local_pop(T &value) {
    auto tail = tail_.load(std::memory_order_relaxed);
    auto head = head_.load();

    if (head == tail) {
      return false;
    }

    value = buf_[head & MASK].load(std::memory_order_relaxed);
    return head_.compare_exchange_strong(head, head + 1);
  }

  bool steal(T &value, StealingQueue<T, N> &other) {
    while (true) {
      auto tail = tail_.load(std::memory_order_relaxed);
      auto head = head_.load();  // TODO: memory order

      auto other_head = other.head_.load();
      auto other_tail = other.tail_.load(std::memory_order_acquire);

      if (other_tail < other_head) {
        continue;
      }
      auto n = narrow_cast<size_t>(other_tail - other_head);
      if (n > N) {
        continue;
      }
      n -= n / 2;
      n = td::min(n, static_cast<size_t>(head + N - tail));
      if (n == 0) {
        return false;
      }

      for (size_t i = 0; i < n; i++) {
        buf_[(i + tail) & MASK].store(other.buf_[(i + other_head) & MASK].load(std::memory_order_relaxed),
                                      std::memory_order_relaxed);
      }

      if (!other.head_.compare_exchange_strong(other_head, other_head + n)) {
        continue;
      }

      n--;
      value = buf_[(tail + n) & MASK].load(std::memory_order_relaxed);
      tail_.store(tail + n, std::memory_order_release);
      return true;
    }
  }

  StealingQueue() {
    for (auto &x : buf_) {
// workaround for https://gcc.gnu.org/bugzilla/show_bug.cgi?id=64658
#if TD_GCC && GCC_VERSION <= 40902
      x = T();
#else
      std::atomic_init(&x, T());
#endif
    }
    std::atomic_thread_fence(std::memory_order_seq_cst);
  }

 private:
  std::atomic<int64> head_{0};
  std::atomic<int64> tail_{0};
  static constexpr size_t MASK{N - 1};
  std::array<std::atomic<T>, N> buf_;
};

}  // namespace td
