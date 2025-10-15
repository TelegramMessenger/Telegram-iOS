//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <array>
#include <atomic>
#include <memory>

namespace td {

template <class T, int MaxPointersN = 1, class Deleter = std::default_delete<T>>
class HazardPointers {
 public:
  explicit HazardPointers(size_t threads_n) : threads_(threads_n) {
    for (auto &data : threads_) {
      for (auto &ptr : data.hazard_) {
// workaround for https://gcc.gnu.org/bugzilla/show_bug.cgi?id=64658
#if TD_GCC && GCC_VERSION <= 40902
        ptr = nullptr;
#else
        std::atomic_init(&ptr, static_cast<T *>(nullptr));
#endif
      }
    }
  }
  HazardPointers(const HazardPointers &) = delete;
  HazardPointers &operator=(const HazardPointers &) = delete;
  HazardPointers(HazardPointers &&) = delete;
  HazardPointers &operator=(HazardPointers &&) = delete;

  class Holder {
   public:
    template <class S>
    S *protect(std::atomic<S *> &to_protect) {
      return do_protect(hazard_ptr_, to_protect);
    }
    Holder(HazardPointers &hp, size_t thread_id, size_t pos) : Holder(hp.get_hazard_ptr(thread_id, pos)) {
      CHECK(hazard_ptr_.load() == 0);
      hazard_ptr_.store(reinterpret_cast<T *>(1));
    }
    Holder(const Holder &) = delete;
    Holder &operator=(const Holder &) = delete;
    Holder(Holder &&) = delete;
    Holder &operator=(Holder &&) = delete;
    ~Holder() {
      clear();
    }
    void clear() {
      hazard_ptr_.store(nullptr, std::memory_order_release);
    }

   private:
    friend class HazardPointers;
    explicit Holder(std::atomic<T *> &ptr) : hazard_ptr_(ptr) {
    }
    std::atomic<T *> &hazard_ptr_;
  };

  void retire(size_t thread_id, T *ptr = nullptr) {
    CHECK(thread_id < threads_.size());
    auto &data = threads_[thread_id];
    if (ptr) {
      data.to_delete_.push_back(std::unique_ptr<T, Deleter>(ptr));
    }
    for (auto it = data.to_delete_.begin(); it != data.to_delete_.end();) {
      if (!is_protected(it->get())) {
        it->reset();
        it = data.to_delete_.erase(it);
      } else {
        ++it;
      }
    }
  }

  // old interface
  T *protect(size_t thread_id, size_t pos, std::atomic<T *> &ptr) {
    return do_protect(get_hazard_ptr(thread_id, pos), ptr);
  }
  void clear(size_t thread_id, size_t pos) {
    do_clear(get_hazard_ptr(thread_id, pos));
  }

  size_t to_delete_size_unsafe() const {
    size_t res = 0;
    for (auto &thread_data : threads_) {
      res += thread_data.to_delete_.size();
    }
    return res;
  }

 private:
  struct ThreadData {
    std::array<std::atomic<T *>, MaxPointersN> hazard_;
    char pad[TD_CONCURRENCY_PAD - sizeof(std::array<std::atomic<T *>, MaxPointersN>)];

    // stupid gc
    std::vector<std::unique_ptr<T, Deleter>> to_delete_;
    char pad2[TD_CONCURRENCY_PAD - sizeof(std::vector<std::unique_ptr<T, Deleter>>)];
  };
  std::vector<ThreadData> threads_;
  char pad2[TD_CONCURRENCY_PAD - sizeof(std::vector<ThreadData>)];

  template <class S>
  static S *do_protect(std::atomic<T *> &hazard_ptr, std::atomic<S *> &to_protect) {
    T *saved = nullptr;
    T *to_save;
    while ((to_save = to_protect.load()) != saved) {
      hazard_ptr.store(to_save);
      saved = to_save;
    }
    return static_cast<S *>(saved);
  }

  static void do_clear(std::atomic<T *> &hazard_ptr) {
    hazard_ptr.store(nullptr, std::memory_order_release);
  }

  bool is_protected(T *ptr) {
    for (auto &thread_data : threads_) {
      for (auto &hazard_ptr : thread_data.hazard_) {
        if (hazard_ptr.load() == ptr) {
          return true;
        }
      }
    }
    return false;
  }

  std::atomic<T *> &get_hazard_ptr(size_t thread_id, size_t pos) {
    CHECK(thread_id < threads_.size());
    return threads_[thread_id].hazard_[pos];
  }
};

}  // namespace td
