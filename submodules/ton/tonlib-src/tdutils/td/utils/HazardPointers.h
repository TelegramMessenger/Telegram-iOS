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
  HazardPointers(const HazardPointers &other) = delete;
  HazardPointers &operator=(const HazardPointers &other) = delete;
  HazardPointers(HazardPointers &&other) = delete;
  HazardPointers &operator=(HazardPointers &&other) = delete;

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
    Holder(const Holder &other) = delete;
    Holder &operator=(const Holder &other) = delete;
    Holder(Holder &&other) = delete;
    Holder &operator=(Holder &&other) = delete;
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

  // old inteface
  T *protect(size_t thread_id, size_t pos, std::atomic<T *> &ptr) {
    return do_protect(get_hazard_ptr(thread_id, pos), ptr);
  }
  void clear(size_t thread_id, size_t pos) {
    do_clear(get_hazard_ptr(thread_id, pos));
  }

  size_t to_delete_size_unsafe() const {
    size_t res = 0;
    for (auto &thread : threads_) {
      res += thread.to_delete_.size();
    }
    return res;
  }

 private:
  struct ThreadData {
    std::array<std::atomic<T *>, MaxPointersN> hazard_;
    char pad[TD_CONCURRENCY_PAD - sizeof(hazard_)];

    // stupid gc
    std::vector<std::unique_ptr<T, Deleter>> to_delete_;
    char pad2[TD_CONCURRENCY_PAD - sizeof(to_delete_)];
  };
  std::vector<ThreadData> threads_;
  char pad2[TD_CONCURRENCY_PAD - sizeof(threads_)];

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
    for (auto &thread : threads_) {
      for (auto &hazard_ptr : thread.hazard_) {
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
