//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/ThreadLocalStorage.h"

#include <array>
#include <atomic>
#include <mutex>

namespace td {

template <size_t N>
class ThreadSafeMultiCounter {
 public:
  void add(size_t index, int64 diff) {
    CHECK(index < N);
    tls_.get()[index].fetch_add(diff, std::memory_order_relaxed);
  }

  int64 sum(size_t index) const {
    CHECK(index < N);
    int64 res = 0;
    tls_.for_each([&res, &index](auto &value) { res += value[index].load(std::memory_order_relaxed); });
    return res;
  }
  void clear() {
    tls_.for_each([](auto &value) {
      for (auto &x : value) {
        x = 0;
      }
    });
  }

 private:
  ThreadLocalStorage<std::array<std::atomic<int64>, N>> tls_;
};

class ThreadSafeCounter {
 public:
  void add(int64 diff) {
    counter_.add(0, diff);
  }

  int64 sum() const {
    return counter_.sum(0);
  }

  void clear() {
    counter_.clear();
  }

 private:
  ThreadSafeMultiCounter<1> counter_;
};

class NamedThreadSafeCounter {
  static constexpr size_t N = 128;
  using Counter = ThreadSafeMultiCounter<N>;

 public:
  class CounterRef {
   public:
    CounterRef() = default;
    CounterRef(size_t index, Counter *counter) : index_(index), counter_(counter) {
    }
    void add(int64 diff) {
      counter_->add(index_, diff);
    }
    int64 sum() const {
      return counter_->sum(index_);
    }

   private:
    size_t index_{0};
    Counter *counter_{nullptr};
  };

  CounterRef get_counter(Slice name) {
    std::unique_lock<std::mutex> guard(mutex_);
    for (size_t i = 0; i < names_.size(); i++) {
      if (names_[i] == name) {
        return get_counter_ref(i);
      }
    }
    CHECK(names_.size() < N);
    names_.emplace_back(name.begin(), name.size());
    return get_counter_ref(names_.size() - 1);
  }

  CounterRef get_counter_ref(size_t index) {
    return CounterRef(index, &counter_);
  }

  static NamedThreadSafeCounter &get_default() {
    static NamedThreadSafeCounter res;
    return res;
  }

  template <class F>
  void for_each(F &&f) const {
    std::unique_lock<std::mutex> guard(mutex_);
    for (size_t i = 0; i < names_.size(); i++) {
      f(names_[i], counter_.sum(i));
    }
  }

  void clear() {
    std::unique_lock<std::mutex> guard(mutex_);
    counter_.clear();
  }

  friend StringBuilder &operator<<(StringBuilder &sb, const NamedThreadSafeCounter &counter) {
    counter.for_each([&sb](Slice name, int64 cnt) { sb << name << ": " << cnt << "\n"; });
    return sb;
  }

 private:
  mutable std::mutex mutex_;
  std::vector<std::string> names_;

  Counter counter_;
};

}  // namespace td
