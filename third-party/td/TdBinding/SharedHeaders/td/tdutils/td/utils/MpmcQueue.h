//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

// MPMC queue
// Simple semaphore protected implementation
// To close queue, one should send as much sentinel elements as there are readers.
// Once there are no readers and writers, one may easily destroy queue

#include "td/utils/format.h"
#include "td/utils/HazardPointers.h"
#include "td/utils/logging.h"
#include "td/utils/port/sleep.h"
#include "td/utils/ScopeGuard.h"

#include <array>
#include <atomic>

namespace td {

namespace detail {

struct MpmcStat {
  void alloc_ok(size_t thread_id) {
    s(thread_id).alloc_ok_cnt++;
  }
  void alloc_error(size_t thread_id) {
    s(thread_id).alloc_error_cnt++;
  }
  void push_loop_error(size_t thread_id) {
    s(thread_id).push_loop_error_cnt++;
  }
  void push_loop_ok(size_t thread_id) {
    s(thread_id).push_loop_ok_cnt++;
  }
  void dump() {
    int alloc_ok_cnt = 0;
    int alloc_error_cnt = 0;
    int push_loop_error_cnt = 0;
    int push_loop_ok_cnt = 0;
    for (auto &d : arr) {
      alloc_ok_cnt += d.alloc_ok_cnt;
      alloc_error_cnt += d.alloc_error_cnt;
      push_loop_error_cnt += d.push_loop_error_cnt;
      push_loop_ok_cnt += d.push_loop_ok_cnt;
    }
    LOG(ERROR) << tag("alloc_ok_cnt", alloc_ok_cnt) << tag("alloc_error_cnt", alloc_error_cnt)
               << tag("push_loop_error_cnt", push_loop_error_cnt) << tag("push_loop_ok_cnt", push_loop_ok_cnt);
  }

 private:
  struct ThreadStat {
    int alloc_ok_cnt{0};
    int alloc_error_cnt{0};
    int push_loop_ok_cnt{0};
    int push_loop_error_cnt{0};
    char pad[TD_CONCURRENCY_PAD - sizeof(int) * 4];
  };
  std::array<ThreadStat, 1024> arr;
  ThreadStat &s(size_t thread_id) {
    return arr[thread_id];
  }
};

extern MpmcStat stat_;

}  // namespace detail

template <class T>
class OneValue {
 public:
  bool set_value(T &value) {
    value_ = std::move(value);
    int state = Empty;
    if (state_.compare_exchange_strong(state, Value, std::memory_order_acq_rel)) {
      return true;
    }
    value = std::move(value_);
    return false;
  }
  bool get_value(T &value) {
    auto old_state = state_.exchange(Taken, std::memory_order_acq_rel);
    if (old_state == Value) {
      value = std::move(value_);
      return true;
    }
    return false;
  }
  void reset() {
    state_ = Empty;
    value_ = T();
  }

 private:
  enum Type : int { Empty = 0, Taken, Value };
  std::atomic<int> state_{Empty};
  T value_{};
};

template <class T>
class OneValue<T *> {
 public:
  bool set_value(T *value) {
    T *was = Empty();
    return state_.compare_exchange_strong(was, value, std::memory_order_acq_rel);
  }
  bool get_value(T *&value) {
    value = state_.exchange(Taken(), std::memory_order_acq_rel);
    return value != Empty();
  }
  void reset() {
    state_ = Empty();
  }
  OneValue() {
  }

 private:
  std::atomic<T *> state_{Empty()};
  static T *Empty() {
    static int64 xxx;
    return reinterpret_cast<T *>(&xxx);
  }
  static T *Taken() {
    static int64 xxx;
    return reinterpret_cast<T *>(&xxx);
  }
};

template <class T>
class MpmcQueueBlock {
 public:
  explicit MpmcQueueBlock(size_t size) : nodes_(size) {
  }
  enum class PopStatus { Ok, Empty, Closed };

  //blocking pop
  //returns Ok or Closed
  PopStatus pop(T &value) {
    while (true) {
      auto read_pos = read_pos_.fetch_add(1, std::memory_order_relaxed);
      if (read_pos >= nodes_.size()) {
        return PopStatus::Closed;
      }
      //TODO blocking get_value
      if (nodes_[static_cast<size_t>(read_pos)].one_value.get_value(value)) {
        return PopStatus::Ok;
      }
    }
  }

  //nonblocking pop
  //returns Ok, Empty or Closed
  PopStatus try_pop(T &value) {
    while (true) {
      // this check slows 1:1 case but prevents writer starvation in 1:N case
      if (write_pos_.load(std::memory_order_relaxed) <= read_pos_.load(std::memory_order_relaxed) &&
          read_pos_.load(std::memory_order_relaxed) < nodes_.size()) {
        return PopStatus::Empty;
      }
      auto read_pos = read_pos_.fetch_add(1, std::memory_order_relaxed);
      if (read_pos >= nodes_.size()) {
        return PopStatus::Closed;
      }
      if (nodes_[static_cast<size_t>(read_pos)].one_value.get_value(value)) {
        return PopStatus::Ok;
      }
      auto write_pos = write_pos_.load(std::memory_order_relaxed);
      if (write_pos <= read_pos + 1) {
        return PopStatus::Empty;
      }
    }
  }

  enum class PushStatus { Ok, Closed };
  PushStatus push(T &value) {
    while (true) {
      auto write_pos = write_pos_.fetch_add(1, std::memory_order_relaxed);
      if (write_pos >= nodes_.size()) {
        return PushStatus::Closed;
      }
      if (nodes_[static_cast<size_t>(write_pos)].one_value.set_value(value)) {
        //stat_.push_loop_ok(0);
        return PushStatus::Ok;
      }
      //stat_.push_loop_error(0);
    }
  }

 private:
  struct Node {
    OneValue<T> one_value;
  };
  std::atomic<uint64> write_pos_{0};
  char pad[TD_CONCURRENCY_PAD - sizeof(std::atomic<uint64>)];
  std::atomic<uint64> read_pos_{0};
  char pad2[TD_CONCURRENCY_PAD - sizeof(std::atomic<uint64>)];
  std::vector<Node> nodes_;
  char pad3[TD_CONCURRENCY_PAD - sizeof(std::vector<Node>)];
};

template <class T>
class MpmcQueueOld {
 public:
  explicit MpmcQueueOld(size_t threads_n) : MpmcQueueOld(1024, threads_n) {
  }
  static std::string get_description() {
    return "Mpmc queue (fetch and add array queue)";
  }
  MpmcQueueOld(size_t block_size, size_t threads_n) : block_size_{block_size}, hazard_pointers_{threads_n} {
    auto node = make_unique<Node>(block_size_);
    write_pos_ = node.get();
    read_pos_ = node.get();
    node.release();
  }

  MpmcQueueOld(const MpmcQueueOld &) = delete;
  MpmcQueueOld &operator=(const MpmcQueueOld &) = delete;
  MpmcQueueOld(MpmcQueueOld &&) = delete;
  MpmcQueueOld &operator=(MpmcQueueOld &&) = delete;
  ~MpmcQueueOld() {
    auto *ptr = read_pos_.load(std::memory_order_relaxed);
    while (ptr) {
      auto *to_delete = ptr;
      ptr = ptr->next_.load(std::memory_order_relaxed);
      delete to_delete;
    }
    //stat_.dump();
    //stat_ = detail::MpmcStat();
  }

  size_t hazard_pointers_to_delele_size_unsafe() const {
    return hazard_pointers_.to_delete_size_unsafe();
  }
  void gc(size_t thread_id) {
    hazard_pointers_.retire(thread_id);
  }

  using PushStatus = typename MpmcQueueBlock<T>::PushStatus;
  using PopStatus = typename MpmcQueueBlock<T>::PopStatus;

  void push(T value, size_t thread_id) {
    typename decltype(hazard_pointers_)::Holder hazard_ptr_holder(hazard_pointers_, thread_id, 0);
    while (true) {
      auto node = hazard_ptr_holder.protect(write_pos_);
      auto status = node->block.push(value);
      switch (status) {
        case PushStatus::Ok:
          return;
        case PushStatus::Closed: {
          auto next = node->next_.load(std::memory_order_acquire);
          if (next == nullptr) {
            auto new_node = new Node(block_size_);
            new_node->block.push(value);
            if (node->next_.compare_exchange_strong(next, new_node, std::memory_order_acq_rel)) {
              //stat_.alloc_ok(thread_id);
              write_pos_.compare_exchange_strong(node, new_node, std::memory_order_acq_rel);
              return;
            } else {
              //stat_.alloc_error(thread_id);
              new_node->block.pop(value);
              //CHECK(status == PopStatus::Ok);
              delete new_node;
            }
          }
          //CHECK(next != nullptr);
          write_pos_.compare_exchange_strong(node, next, std::memory_order_acq_rel);
          break;
        }
      }
    }
  }

  bool try_pop(T &value, size_t thread_id) {
    typename decltype(hazard_pointers_)::Holder hazard_ptr_holder(hazard_pointers_, thread_id, 0);
    while (true) {
      auto node = hazard_ptr_holder.protect(read_pos_);
      auto status = node->block.try_pop(value);
      switch (status) {
        case PopStatus::Ok:
          return true;
        case PopStatus::Empty:
          return false;
        case PopStatus::Closed: {
          auto next = node->next_.load(std::memory_order_acquire);
          if (!next) {
            return false;
          }
          if (read_pos_.compare_exchange_strong(node, next, std::memory_order_acq_rel)) {
            hazard_ptr_holder.clear();
            hazard_pointers_.retire(thread_id, node);
          }
          break;
        }
      }
    }
  }

  T pop(size_t thread_id) {
    T value;
    while (true) {
      if (try_pop(value, thread_id)) {
        return value;
      }
      usleep_for(1);
    }
  }

 private:
  struct Node {
    explicit Node(size_t block_size) : block{block_size} {
    }
    std::atomic<Node *> next_{nullptr};
    char pad[TD_CONCURRENCY_PAD - sizeof(std::atomic<Node *>)];
    MpmcQueueBlock<T> block;
    // MpmcQueueBlock is already padded
  };
  std::atomic<Node *> write_pos_{nullptr};
  char pad[TD_CONCURRENCY_PAD - sizeof(std::atomic<Node *>)];
  std::atomic<Node *> read_pos_{nullptr};
  char pad2[TD_CONCURRENCY_PAD - sizeof(std::atomic<Node *>)];
  size_t block_size_;
  HazardPointers<Node, 1> hazard_pointers_;
  // HazardPointers class is already padded
};

template <class T>
class MpmcQueue {
 public:
  explicit MpmcQueue(size_t threads_n) : MpmcQueue(1024, threads_n) {
  }
  static std::string get_description() {
    return "NEW Mpmc queue (fetch and add array queue)";
  }
  MpmcQueue(size_t block_size, size_t threads_n) : hazard_pointers_{threads_n} {
    auto node = make_unique<Node>();
    write_pos_ = node.get();
    read_pos_ = node.get();
    node.release();
  }

  MpmcQueue(const MpmcQueue &) = delete;
  MpmcQueue &operator=(const MpmcQueue &) = delete;
  MpmcQueue(MpmcQueue &&) = delete;
  MpmcQueue &operator=(MpmcQueue &&) = delete;
  ~MpmcQueue() {
    auto *ptr = read_pos_.load(std::memory_order_relaxed);
    while (ptr) {
      auto *to_delete = ptr;
      ptr = ptr->next.load(std::memory_order_relaxed);
      delete to_delete;
    }
  }

  size_t hazard_pointers_to_delele_size_unsafe() const {
    return hazard_pointers_.to_delete_size_unsafe();
  }
  void gc(size_t thread_id) {
    hazard_pointers_.retire(thread_id);
  }

  void push(T value, size_t thread_id) {
    SCOPE_EXIT {
      hazard_pointers_.clear(thread_id, 0);
    };
    while (true) {
      auto node = hazard_pointers_.protect(thread_id, 0, write_pos_);
      auto &block = node->block;
      auto pos = block.write_pos++;
      if (pos >= block.data.size()) {
        auto next = node->next.load();
        if (next == nullptr) {
          auto new_node = new Node{};
          new_node->block.write_pos++;
          new_node->block.data[0].set_value(value);
          Node *null = nullptr;
          if (node->next.compare_exchange_strong(null, new_node)) {
            write_pos_.compare_exchange_strong(node, new_node);
            return;
          } else {
            new_node->block.data[0].get_value(value);
            delete new_node;
          }
        } else {
          write_pos_.compare_exchange_strong(node, next);
        }
      } else {
        if (block.data[static_cast<size_t>(pos)].set_value(value)) {
          return;
        }
      }
    }
  }

  bool try_pop(T &value, size_t thread_id) {
    SCOPE_EXIT {
      hazard_pointers_.clear(thread_id, 0);
    };
    while (true) {
      auto node = hazard_pointers_.protect(thread_id, 0, read_pos_);
      auto &block = node->block;
      if (block.write_pos <= block.read_pos && node->next.load(std::memory_order_relaxed) == nullptr) {
        return false;
      }
      auto pos = block.read_pos++;
      if (pos >= block.data.size()) {
        auto next = node->next.load();
        if (!next) {
          return false;
        }
        if (read_pos_.compare_exchange_strong(node, next)) {
          hazard_pointers_.clear(thread_id, 0);
          hazard_pointers_.retire(thread_id, node);
        }
      } else {
        if (block.data[static_cast<size_t>(pos)].get_value(value)) {
          return true;
        }
      }
    }
  }

  T pop(size_t thread_id) {
    T value;
    while (true) {
      if (try_pop(value, thread_id)) {
        return value;
      }
      usleep_for(1);
    }
  }

 private:
  struct Block {
    std::atomic<uint64> write_pos{0};
    char pad[TD_CONCURRENCY_PAD - sizeof(std::atomic<uint64>)];
    std::atomic<uint64> read_pos{0};
    char pad2[TD_CONCURRENCY_PAD - sizeof(std::atomic<uint64>)];
    std::array<OneValue<T>, 1024> data;
    char pad3[TD_CONCURRENCY_PAD];
  };
  struct Node {
    Node() = default;

    Block block;
    std::atomic<Node *> next{nullptr};
    char pad[TD_CONCURRENCY_PAD - sizeof(std::atomic<Node *>)];
  };
  std::atomic<Node *> write_pos_{nullptr};
  char pad[TD_CONCURRENCY_PAD - sizeof(std::atomic<Node *>)];
  std::atomic<Node *> read_pos_{nullptr};
  char pad2[TD_CONCURRENCY_PAD - sizeof(std::atomic<Node *>)];
  HazardPointers<Node, 1> hazard_pointers_;
  // HazardPointers class is already padded
};

}  // namespace td
