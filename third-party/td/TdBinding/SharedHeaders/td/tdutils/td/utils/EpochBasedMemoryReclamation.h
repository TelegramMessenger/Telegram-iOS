//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/sleep.h"

#include <atomic>
#include <memory>

namespace td {

template <class T>
class EpochBasedMemoryReclamation {
 public:
  EpochBasedMemoryReclamation(const EpochBasedMemoryReclamation &) = delete;
  EpochBasedMemoryReclamation &operator=(const EpochBasedMemoryReclamation &) = delete;
  EpochBasedMemoryReclamation(EpochBasedMemoryReclamation &&) = delete;
  EpochBasedMemoryReclamation &operator=(EpochBasedMemoryReclamation &&) = delete;
  ~EpochBasedMemoryReclamation() = default;

  class Locker {
   public:
    Locker(size_t thread_id, EpochBasedMemoryReclamation *ebmr) : thread_id_(thread_id), ebmr_(ebmr) {
    }
    Locker(const Locker &) = delete;
    Locker &operator=(const Locker &) = delete;
    Locker(Locker &&) = default;
    Locker &operator=(Locker &&) = delete;

    ~Locker() {
      if (ebmr_) {
        retire_sync();
        unlock();
        (void)ebmr_.release();
      }
    }
    void lock() {
      DCHECK(ebmr_);
      ebmr_->lock(thread_id_);
    }
    void unlock() {
      DCHECK(ebmr_);
      ebmr_->unlock(thread_id_);
    }

    void retire_sync() {
      ebmr_->retire_sync(thread_id_);
    }

    void retire() {
      ebmr_->retire(thread_id_);
    }

    void retire(T *ptr) {
      ebmr_->retire(thread_id_, ptr);
    }

   private:
    size_t thread_id_;
    struct Never {
      template <class S>
      void operator()(S *) const {
        UNREACHABLE();
      }
    };
    std::unique_ptr<EpochBasedMemoryReclamation, Never> ebmr_;
  };

  explicit EpochBasedMemoryReclamation(size_t threads_n) : threads_(threads_n) {
  }

  Locker get_locker(size_t thread_id) {
    return Locker{thread_id, this};
  }

  size_t to_delete_size_unsafe() const {
    size_t res = 0;
    for (auto &thread_data : threads_) {
      // LOG(ERROR) << "---" << thread_data.epoch.load() / 2;
      for (size_t i = 0; i < MAX_BAGS; i++) {
        res += thread_data.to_delete[i].size();
        // LOG(ERROR) << thread_data.to_delete[i].size();
      }
    }
    return res;
  }

 private:
  static constexpr size_t MAX_BAGS = 3;
  struct ThreadData {
    std::atomic<int64> epoch{1};
    char pad[TD_CONCURRENCY_PAD - sizeof(std::atomic<int64>)];

    size_t to_skip{0};
    size_t checked_thread_i{0};
    size_t bag_i{0};
    std::vector<unique_ptr<T>> to_delete[MAX_BAGS];
    char pad2[TD_CONCURRENCY_PAD - sizeof(std::vector<unique_ptr<T>>) * MAX_BAGS];

    void rotate_bags() {
      bag_i = (bag_i + 1) % MAX_BAGS;
      to_delete[bag_i].clear();
    }

    void set_epoch(int64 new_epoch) {
      //LOG(ERROR) << new_epoch;
      if (epoch.load(std::memory_order_relaxed) / 2 != new_epoch) {
        checked_thread_i = 0;
        to_skip = 0;
        rotate_bags();
      }
      epoch = new_epoch * 2;
    }

    void idle() {
      epoch.store(epoch.load(std::memory_order_relaxed) | 1);
    }

    size_t undeleted() const {
      size_t res = 0;
      for (size_t i = 0; i < MAX_BAGS; i++) {
        res += to_delete[i].size();
      }
      return res;
    }
  };
  std::vector<ThreadData> threads_;
  char pad[TD_CONCURRENCY_PAD - sizeof(std::vector<ThreadData>)];

  std::atomic<int64> epoch_{1};
  char pad2[TD_CONCURRENCY_PAD - sizeof(std::atomic<int64>)];

  void lock(size_t thread_id) {
    auto &data = threads_[thread_id];
    auto epoch = epoch_.load();
    data.set_epoch(epoch);

    if (data.to_skip == 0) {
      data.to_skip = 30;
      step_check(data);
    } else {
      data.to_skip--;
    }
  }

  void unlock(size_t thread_id) {
    //LOG(ERROR) << "UNLOCK";
    auto &data = threads_[thread_id];
    data.idle();
  }

  bool step_check(ThreadData &data) {
    auto epoch = data.epoch.load(std::memory_order_relaxed) / 2;
    auto checked_thread_epoch = threads_[data.checked_thread_i].epoch.load();
    if (checked_thread_epoch % 2 == 1 || checked_thread_epoch / 2 == epoch) {
      data.checked_thread_i++;
      if (data.checked_thread_i == threads_.size()) {
        if (epoch_.compare_exchange_strong(epoch, epoch + 1)) {
          data.set_epoch(epoch + 1);
        } else {
          data.set_epoch(epoch);
        }
      }
      return true;
    }
    return false;
  }

  void retire_sync(size_t thread_id) {
    auto &data = threads_[thread_id];

    while (true) {
      retire(thread_id);
      data.idle();
      if (data.undeleted() == 0) {
        break;
      }
      usleep_for(1000);
    }
  }

  void retire(size_t thread_id) {
    auto &data = threads_[thread_id];
    data.set_epoch(epoch_.load());
    while (step_check(data) && data.undeleted() != 0) {
    }
  }

  void retire(size_t thread_id, T *ptr) {
    auto &data = threads_[thread_id];
    data.to_delete[data.bag_i].push_back(unique_ptr<T>{ptr});
  }
};

}  // namespace td
