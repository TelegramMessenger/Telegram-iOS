//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"

#include <atomic>
#include <memory>
#include <utility>

namespace td {
// It is draft object pool implementation
//
// Compared with std::shared_ptr:
// + WeakPtr are much faster. Just pointer copy. No barriers, no atomics.
// - We can't destroy object, because we don't know if it is pointed to by some weak pointer
//
template <class DataT>
class ObjectPool {
  struct Storage;

 public:
  class WeakPtr {
   public:
    WeakPtr() : generation_(-1), storage_(nullptr) {
    }
    WeakPtr(int32 generation, Storage *storage) : generation_(generation), storage_(storage) {
    }

    DataT &operator*() const {
      return storage_->data;
    }

    DataT *operator->() const {
      return &**this;
    }

    // Pattern of usage: 1. Read an object 2. Check if read was valid via is_alive
    //
    // It is not very usual case of acquire/release use.
    // We publish new generation via destruction of the data instead of publishing the object via some flag.
    // In usual case if we see a flag, then we are able to use an object.
    // In our case if we have used an object and it is already invalid, then generation will mismatch.
    bool is_alive() const {
      if (!storage_) {
        return false;
      }
      std::atomic_thread_fence(std::memory_order_acquire);
      return generation_ == storage_->generation.load(std::memory_order_relaxed);
    }

    // Used for ActorId
    bool is_alive_unsafe() const {
      if (!storage_) {
        return false;
      }
      return generation_ == storage_->generation.load(std::memory_order_relaxed);
    }

    bool empty() const {
      return storage_ == nullptr;
    }
    void clear() {
      generation_ = -1;
      storage_ = nullptr;
    }
    int32 generation() {
      return generation_;
    }

   private:
    int32 generation_;
    Storage *storage_;
  };

  class OwnerPtr {
   public:
    OwnerPtr() = default;
    OwnerPtr(const OwnerPtr &) = delete;
    OwnerPtr &operator=(const OwnerPtr &) = delete;
    OwnerPtr(OwnerPtr &&other) noexcept : storage_(other.storage_), parent_(other.parent_) {
      other.storage_ = nullptr;
      other.parent_ = nullptr;
    }
    OwnerPtr &operator=(OwnerPtr &&other) noexcept {
      if (this != &other) {
        storage_ = other.storage_;
        parent_ = other.parent_;
        other.storage_ = nullptr;
        other.parent_ = nullptr;
      }
      return *this;
    }
    ~OwnerPtr() {
      reset();
    }

    DataT *get() {
      return &storage_->data;
    }
    DataT &operator*() {
      return *get();
    }
    DataT *operator->() {
      return get();
    }

    const DataT *get() const {
      return &storage_->data;
    }
    const DataT &operator*() const {
      return *get();
    }
    const DataT *operator->() const {
      return get();
    }

    WeakPtr get_weak() {
      return WeakPtr(storage_->generation.load(std::memory_order_relaxed), storage_);
    }
    int32 generation() {
      return storage_->generation.load(std::memory_order_relaxed);
    }

    Storage *release() {
      auto result = storage_;
      storage_ = nullptr;
      return result;
    }

    bool empty() const {
      return storage_ == nullptr;
    }

    void reset() {
      if (storage_ != nullptr) {
        // for crazy cases when data owns owner pointer to itself.
        auto tmp = storage_;
        storage_ = nullptr;
        parent_->release(OwnerPtr(tmp, parent_));
      }
    }

   private:
    friend class ObjectPool;
    OwnerPtr(Storage *storage, ObjectPool<DataT> *parent) : storage_(storage), parent_(parent) {
    }
    Storage *storage_ = nullptr;
    ObjectPool<DataT> *parent_ = nullptr;
  };

  template <class... ArgsT>
  OwnerPtr create(ArgsT &&...args) {
    Storage *storage = get_storage();
    storage->init_data(std::forward<ArgsT>(args)...);
    return OwnerPtr(storage, this);
  }

  OwnerPtr create_empty() {
    Storage *storage = get_storage();
    return OwnerPtr(storage, this);
  }

  void set_check_empty(bool flag) {
    check_empty_flag_ = flag;
  }

  void release(OwnerPtr &&owner_ptr) {
    Storage *storage = owner_ptr.release();
    storage->destroy_data();
    release_storage(storage);
  }

  ObjectPool() = default;
  ObjectPool(const ObjectPool &) = delete;
  ObjectPool &operator=(const ObjectPool &) = delete;
  ObjectPool(ObjectPool &&) = delete;
  ObjectPool &operator=(ObjectPool &&) = delete;
  ~ObjectPool() {
    while (head_.load()) {
      auto to_delete = head_.load();
      head_ = to_delete->next;
      delete to_delete;
      storage_count_--;
    }
    LOG_CHECK(storage_count_.load() == 0) << storage_count_.load();
  }

 private:
  struct Storage {
    // union {
    DataT data;
    //};
    Storage *next = nullptr;
    std::atomic<int32> generation{1};

    template <class... ArgsT>
    void init_data(ArgsT &&...args) {
      // new  (&data) DataT(std::forward<ArgsT>(args)...);
      data = DataT(std::forward<ArgsT>(args)...);
    }
    void destroy_data() {
      generation.fetch_add(1, std::memory_order_relaxed);
      std::atomic_thread_fence(std::memory_order_release);
      data.clear();
    }
  };

  std::atomic<int32> storage_count_{0};
  std::atomic<Storage *> head_{static_cast<Storage *>(nullptr)};
  bool check_empty_flag_ = false;

  // TODO(perf): allocation Storages in chunks? Anyway, we won't be able to release them.
  // TODO(perf): memory order
  // TODO(perf): use another non lockfree list for release on the same thread
  // only one thread, so no aba problem
  Storage *get_storage() {
    if (head_.load() == nullptr) {
      storage_count_++;
      return new Storage();
    }
    Storage *res;
    while (true) {
      res = head_.load();
      auto *next = res->next;
      if (head_.compare_exchange_weak(res, next)) {
        break;
      }
    }
    return res;
  }
  // release can be called from other thread
  void release_storage(Storage *storage) {
    while (true) {
      auto *save_head = head_.load();
      storage->next = save_head;
      if (head_.compare_exchange_weak(save_head, storage)) {
        break;
      }
    }
  }
};
}  // namespace td
