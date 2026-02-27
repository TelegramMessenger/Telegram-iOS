//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/MpscLinkQueue.h"

#include <atomic>
#include <memory>
#include <new>
#include <utility>

namespace td {

namespace detail {
class AtomicRefCnt {
 public:
  explicit AtomicRefCnt(uint64 cnt) : cnt_(cnt) {
  }
  void inc() {
    cnt_.fetch_add(1, std::memory_order_relaxed);
  }
  bool dec() {
    return cnt_.fetch_sub(1, std::memory_order_acq_rel) == 1;
  }
  uint64 value() const {
    return cnt_.load(std::memory_order_relaxed);
  }

 private:
  std::atomic<uint64> cnt_{0};
};

template <class DataT, class DeleterT>
class SharedPtrRaw
    : public DeleterT
    , private MpscLinkQueueImpl::Node {
 public:
  explicit SharedPtrRaw(DeleterT deleter) : DeleterT(std::move(deleter)), ref_cnt_{0}, option_magic_(Magic) {
  }

  ~SharedPtrRaw() {
    CHECK(use_cnt() == 0);
    CHECK(option_magic_ == Magic);
  }
  template <class... ArgsT>
  void init_data(ArgsT &&...args) {
    new (&option_data_) DataT(std::forward<ArgsT>(args)...);
  }
  void destroy_data() {
    option_data_.~DataT();
    option_magic_ = Magic;
  }
  uint64 use_cnt() const {
    return ref_cnt_.value();
  }
  void inc() {
    ref_cnt_.inc();
  }
  bool dec() {
    return ref_cnt_.dec();
  }
  DataT &data() {
    return option_data_;
  }
  static SharedPtrRaw *from_mpsc_link_queue_node(MpscLinkQueueImpl::Node *node) {
    return static_cast<SharedPtrRaw<DataT, DeleterT> *>(node);
  }
  MpscLinkQueueImpl::Node *to_mpsc_link_queue_node() {
    return static_cast<MpscLinkQueueImpl::Node *>(this);
  }

 private:
  AtomicRefCnt ref_cnt_;
  enum { Magic = 0x732817a2 };
  union {
    DataT option_data_;
    uint32 option_magic_;
  };
};

template <class T, class DeleterT = std::default_delete<T>>
class SharedPtr {
 public:
  using Raw = detail::SharedPtrRaw<T, DeleterT>;
  struct acquire_t {};
  SharedPtr() = default;
  ~SharedPtr() {
    if (!raw_) {
      return;
    }
    reset();
  }
  explicit SharedPtr(Raw *raw) : raw_(raw) {
    if (raw_) {
      raw_->inc();
    }
  }
  SharedPtr(acquire_t, Raw *raw) : raw_(raw) {
  }
  SharedPtr(const SharedPtr &other) : SharedPtr(other.raw_) {
  }
  SharedPtr &operator=(const SharedPtr &other) {
    if (this == &other) {
      return *this;
    }
    if (other.raw_) {
      other.raw_->inc();
    }
    reset(other.raw_);
    return *this;
  }
  SharedPtr(SharedPtr &&other) noexcept : raw_(other.raw_) {
    other.raw_ = nullptr;
  }
  SharedPtr &operator=(SharedPtr &&other) noexcept {
    reset(other.raw_);
    other.raw_ = nullptr;
    return *this;
  }
  bool empty() const noexcept {
    return raw_ == nullptr;
  }
  explicit operator bool() const noexcept {
    return !empty();
  }
  uint64 use_cnt() const {
    if (!raw_) {
      return 0;
    }
    return raw_->use_cnt();
  }
  T &operator*() const {
    return raw_->data();
  }
  T *operator->() const {
    return &raw_->data();
  }

  Raw *release() {
    auto res = raw_;
    raw_ = nullptr;
    return res;
  }

  void reset(Raw *new_raw = nullptr) {
    if (raw_ && raw_->dec()) {
      raw_->destroy_data();
      auto deleter = std::move(static_cast<DeleterT &>(*raw_));
      deleter(raw_);
    }
    raw_ = new_raw;
  }

  template <class... ArgsT>
  static SharedPtr<T, DeleterT> create(ArgsT &&...args) {
    auto raw = make_unique<Raw>(DeleterT());
    raw->init_data(std::forward<ArgsT>(args)...);
    return SharedPtr<T, DeleterT>(raw.release());
  }
  template <class D, class... ArgsT>
  static SharedPtr<T, DeleterT> create_with_deleter(D &&d, ArgsT &&...args) {
    auto raw = make_unique<Raw>(std::forward<D>(d));
    raw->init_data(std::forward<ArgsT>(args)...);
    return SharedPtr<T, DeleterT>(raw.release());
  }
  bool operator==(const SharedPtr<T, DeleterT> &other) const {
    return raw_ == other.raw_;
  }

 private:
  Raw *raw_{nullptr};
};

}  // namespace detail

template <class DataT>
class SharedObjectPool {
  class Deleter;

 public:
  using Ptr = detail::SharedPtr<DataT, Deleter>;

  SharedObjectPool() = default;
  SharedObjectPool(const SharedObjectPool &) = delete;
  SharedObjectPool &operator=(const SharedObjectPool &) = delete;
  SharedObjectPool(SharedObjectPool &&) = delete;
  SharedObjectPool &operator=(SharedObjectPool &&) = delete;
  ~SharedObjectPool() {
    free_queue_.pop_all(free_queue_reader_);
    size_t free_cnt = 0;
    while (free_queue_reader_.read()) {
      free_cnt++;
    }
    LOG_CHECK(free_cnt == allocated_.size()) << free_cnt << " " << allocated_.size();
  }

  template <class... ArgsT>
  Ptr alloc(ArgsT &&...args) {
    auto *raw = alloc_raw();
    raw->init_data(std::forward<ArgsT>(args)...);
    return Ptr(raw);
  }
  size_t total_size() const {
    return allocated_.size();
  }
  uint64 calc_free_size() {
    free_queue_.pop_all(free_queue_reader_);
    return free_queue_reader_.calc_size();
  }

  // non-thread-safe
  template <class F>
  void for_each(F &&f) {
    for (auto &raw : allocated_) {
      if (raw->use_cnt() > 0) {
        f(raw->data());
      }
    }
  }

 private:
  using Raw = typename Ptr::Raw;
  Raw *alloc_raw() {
    free_queue_.pop_all(free_queue_reader_);
    auto *raw = free_queue_reader_.read().get();
    if (raw) {
      return raw;
    }
    allocated_.push_back(make_unique<Raw>(deleter()));
    return allocated_.back().get();
  }

  void free_raw(Raw *raw) {
    free_queue_.push(Node{raw});
  }

  class Node {
   public:
    Node() = default;
    explicit Node(Raw *raw) : raw_(raw) {
    }

    MpscLinkQueueImpl::Node *to_mpsc_link_queue_node() {
      return raw_->to_mpsc_link_queue_node();
    }
    static Node from_mpsc_link_queue_node(MpscLinkQueueImpl::Node *node) {
      return Node{Raw::from_mpsc_link_queue_node(node)};
    }
    Raw *get() const {
      return raw_;
    }
    explicit operator bool() const noexcept {
      return raw_ != nullptr;
    }

   private:
    Raw *raw_{nullptr};
  };

  class Deleter {
   public:
    explicit Deleter(SharedObjectPool<DataT> *pool) : pool_(pool) {
    }
    void operator()(Raw *raw) {
      pool_->free_raw(raw);
    };

   private:
    SharedObjectPool<DataT> *pool_;
  };
  friend class Deleter;

  Deleter deleter() {
    return Deleter(this);
  }

  std::vector<unique_ptr<Raw>> allocated_;
  MpscLinkQueue<Node> free_queue_;
  typename MpscLinkQueue<Node>::Reader free_queue_reader_;
};

}  // namespace td
