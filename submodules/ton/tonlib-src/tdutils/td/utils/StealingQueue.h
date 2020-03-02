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

    Copyright 2019-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/Status.h"
#include "td/utils/Span.h"
namespace td {
template <class T, size_t N = 256 /*must be a power of two*/>
class StealingQueue {
 public:
  // tries to put a value
  // returns if succeeded
  // only owner is alowed to to do this
  template <class F>
  void local_push(T value, F&& overflow_f) {
    while (true) {
      auto tail = tail_.load(std::memory_order_relaxed);
      auto head = head_.load();  //TODO: memory order

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
  // only owner is alowed to to do this
  bool local_pop(T& value) {
    auto tail = tail_.load(std::memory_order_relaxed);
    auto head = head_.load();

    if (head == tail) {
      return false;
    }

    value = buf_[head & MASK].load(std::memory_order_relaxed);
    return head_.compare_exchange_strong(head, head + 1);
  }

  bool steal(T& value, StealingQueue<T, N>& other) {
    while (true) {
      auto tail = tail_.load(std::memory_order_relaxed);
      auto head = head_.load();  //TODO: memory order

      auto other_head = other.head_.load();
      auto other_tail = other.tail_.load(std::memory_order_acquire);

      if (other_tail < other_head) {
        continue;
      }
      size_t n = other_tail - other_head;
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
    for (auto& x : buf_) {
      x.store(T{}, std::memory_order_relaxed);
    }
    std::atomic_thread_fence(std::memory_order_seq_cst);
  }

 private:
  std::atomic<td::int64> head_{0};
  std::atomic<td::int64> tail_{0};
  static constexpr size_t MASK{N - 1};
  std::array<std::atomic<T>, N> buf_;
};
};  // namespace td
