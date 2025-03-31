//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/EventFd.h"
#include "td/utils/port/sleep.h"

#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED

#include <atomic>
#include <type_traits>
#include <utility>

namespace td {

namespace detail {
class Backoff {
  int cnt = 0;

 public:
  bool next() {
    // TODO: find out better strategy
    // TODO: try adaptive backoff
    // TODO: different strategy one core cpu
    // return false;

    cnt++;
    if (cnt < 1) {  // 50
      return true;
    } else {
      usleep_for(1);
      return cnt < 3;  // 500
    }
  }
};

class InfBackoff {
  int cnt = 0;

 public:
  bool next() {
    cnt++;
    if (cnt < 50) {
      return true;
    } else {
      usleep_for(1);
      return true;
    }
  }
};

}  // namespace detail

template <class T, int P = 10>
class SPSCBlockQueue {
 public:
  using ValueType = T;

 private:
  static constexpr int buffer_size() {
    static_assert(P >= 1 && P <= 20, "Bad size of BlockQueue");
    return 1 << P;
  }

  struct Position {
    std::atomic<uint32> i{0};
    char pad[64 - sizeof(std::atomic<uint32>)];
    uint32 local_writer_i;
    char pad2[64 - sizeof(uint32)];
    uint32 local_reader_i;
    char pad3[64 - sizeof(uint32)];

    void init() {
      i = 0;
      local_reader_i = 0;
      local_writer_i = 0;
    }
  };

  typename std::aligned_storage<sizeof(ValueType)>::type data_[buffer_size()];
  Position writer_;
  Position reader_;

  static int fix_i(int i) {
    return i & (buffer_size() - 1);
  }

  ValueType *at_ptr(int i) {
    return reinterpret_cast<ValueType *>(&data_[fix_i(i)]);
  }

  ValueType &at(int i) {
    return *at_ptr(i);
  }

 public:
  void init() {
    writer_.init();
    reader_.init();
  }

  void destroy() {
  }

  int writer_size() {
    return static_cast<int>(writer_.local_reader_i + buffer_size() - writer_.local_writer_i);
  }

  bool writer_empty() {
    return writer_.local_reader_i + buffer_size() == writer_.local_writer_i;
  }

  template <class PutValueType>
  void writer_put_unsafe(PutValueType &&value) {
    at(writer_.local_writer_i++) = std::forward<PutValueType>(value);
  }

  int writer_update() {
    writer_.local_reader_i = reader_.i.load(std::memory_order_acquire);
    return writer_size();
  }

  void writer_flush() {
    writer_.i.store(writer_.local_writer_i, std::memory_order_release);
  }

  int reader_size() {
    return static_cast<int>(reader_.local_writer_i - reader_.local_reader_i);
  }

  int reader_empty() {
    return reader_.local_writer_i == reader_.local_reader_i;
  }

  ValueType reader_get_unsafe() {
    return std::move(at(reader_.local_reader_i++));
  }

  int reader_update() {
    reader_.local_writer_i = writer_.i.load(std::memory_order_acquire);
    return reader_size();
  }

  void reader_flush() {
    reader_.i.store(reader_.local_reader_i, std::memory_order_release);
  }
};

template <class T, class BlockQueueT = SPSCBlockQueue<T>>
class SPSCChainQueue {
 public:
  using ValueType = T;

  void init() {
    head_ = tail_ = create_node();
  }

  SPSCChainQueue() = default;
  SPSCChainQueue(const SPSCChainQueue &) = delete;
  SPSCChainQueue &operator=(const SPSCChainQueue &) = delete;
  SPSCChainQueue(SPSCChainQueue &&) = delete;
  SPSCChainQueue &operator=(SPSCChainQueue &&) = delete;
  ~SPSCChainQueue() {
    destroy();
  }

  void destroy() {
    while (head_ != nullptr) {
      Node *to_delete = head_;
      head_ = head_->next_;
      delete_node(to_delete);
    }
    tail_ = nullptr;
  }

  int writer_size() {
    return tail_->q_.writer_size();
  }

  bool writer_empty() {
    return tail_->q_.writer_empty();
  }

  template <class PutValueType>
  void writer_put_unsafe(PutValueType &&value) {
    tail_->q_.writer_put_unsafe(std::forward<PutValueType>(value));
  }

  int writer_update() {
    int res = tail_->q_.writer_update();
    if (res != 0) {
      return res;
    }

    writer_flush();

    Node *new_tail = create_node();
    tail_->next_ = new_tail;
    tail_->is_closed_.store(true, std::memory_order_release);
    tail_ = new_tail;
    return tail_->q_.writer_update();
  }

  void writer_flush() {
    tail_->q_.writer_flush();
  }

  int reader_size() {
    return head_->q_.reader_size();
  }

  int reader_empty() {
    return head_->q_.reader_empty();
  }

  ValueType reader_get_unsafe() {
    return std::move(head_->q_.reader_get_unsafe());
  }

  int reader_update() {
    int res = head_->q_.reader_update();
    if (res != 0) {
      return res;
    }

    if (!head_->is_closed_.load(std::memory_order_acquire)) {
      return 0;
    }

    res = head_->q_.reader_update();
    if (res != 0) {
      return res;
    }

    // reader_flush();

    Node *old_head = head_;
    head_ = head_->next_;
    delete_node(old_head);

    return head_->q_.reader_update();
  }

  void reader_flush() {
    head_->q_.reader_flush();
  }

 private:
  struct Node {
    BlockQueueT q_;
    std::atomic<bool> is_closed_{false};
    Node *next_;

    void init() {
      q_.init();
      is_closed_ = false;
      next_ = nullptr;
    }

    void destroy() {
      q_.destroy();
      next_ = nullptr;
    }
  };

  Node *head_;
  char pad[64 - sizeof(Node *)];
  Node *tail_;
  char pad2[64 - sizeof(Node *)];

  Node *create_node() {
    Node *res = new Node();
    res->init();
    return res;
  }

  void delete_node(Node *node) {
    node->destroy();
    delete node;
  }
};

template <class T, class QueueT = SPSCChainQueue<T>, class BackoffT = detail::Backoff>
class BackoffQueue : public QueueT {
 public:
  using ValueType = T;

  template <class PutValueType>
  void writer_put(PutValueType &&value) {
    if (this->writer_empty()) {
      int sz = this->writer_update();
      CHECK(sz != 0);
    }
    this->writer_put_unsafe(std::forward<PutValueType>(value));
  }

  int reader_wait() {
    BackoffT backoff;
    int res = 0;
    do {
      res = this->reader_update();
    } while (res == 0 && backoff.next());
    return res;
  }
};

template <class T, class QueueT = SPSCChainQueue<T>>
using InfBackoffQueue = BackoffQueue<T, QueueT, detail::InfBackoff>;

template <class T, class QueueT = BackoffQueue<T>>
class PollQueue final : public QueueT {
 public:
  using ValueType = T;
  using QueueType = QueueT;

  void init() {
    QueueType::init();
    event_fd_.init();
    wait_state_ = 0;
    writer_wait_state_ = 0;
  }

  PollQueue() = default;
  PollQueue(const PollQueue &) = delete;
  PollQueue &operator=(const PollQueue &) = delete;
  PollQueue(PollQueue &&) = delete;
  PollQueue &operator=(PollQueue &&) = delete;
  ~PollQueue() {
    destroy_impl();
  }
  void destroy() {
    destroy_impl();
    QueueType::destroy();
  }

  void writer_flush() {
    int old_wait_state = get_wait_state();

    std::atomic_thread_fence(std::memory_order_seq_cst);

    QueueType::writer_flush();

    std::atomic_thread_fence(std::memory_order_seq_cst);

    int wait_state = get_wait_state();
    if ((wait_state & 1) && wait_state != writer_wait_state_) {
      event_fd_.release();
      writer_wait_state_ = old_wait_state;
    }
  }

  EventFd &reader_get_event_fd() {
    return event_fd_;
  }

  // if 0 is returned than it is useless to rerun it before fd is
  // ready to read.
  int reader_wait_nonblock() {
    int res;

    if ((get_wait_state() & 1) == 0) {
      res = this->QueueType::reader_wait();
      if (res != 0) {
        return res;
      }

      inc_wait_state();

      std::atomic_thread_fence(std::memory_order_seq_cst);

      res = this->reader_update();
      if (res != 0) {
        inc_wait_state();
        return res;
      }
    }

    event_fd_.acquire();
    std::atomic_thread_fence(std::memory_order_seq_cst);
    res = this->reader_update();
    if (res != 0) {
      inc_wait_state();
    }
    return res;
  }

  // Just an example of usage
  int reader_wait() {
    int res;
    while ((res = reader_wait_nonblock()) == 0) {
      reader_get_event_fd().wait(1000);
    }
    return res;
  }

 private:
  EventFd event_fd_;
  std::atomic<int> wait_state_{0};
  int writer_wait_state_;

  int get_wait_state() {
    return wait_state_.load(std::memory_order_relaxed);
  }

  void inc_wait_state() {
    wait_state_.store(get_wait_state() + 1, std::memory_order_relaxed);
  }

  void destroy_impl() {
    if (!event_fd_.empty()) {
      event_fd_.close();
    }
  }
};

}  // namespace td

#else

#include "td/utils/common.h"

namespace td {

// dummy implementation which shouldn't be used

template <class T>
class PollQueue {
 public:
  using ValueType = T;

  void init() {
    UNREACHABLE();
  }

  template <class PutValueType>
  void writer_put(PutValueType &&value) {
    UNREACHABLE();
  }

  void writer_flush() {
    UNREACHABLE();
  }

  int reader_wait_nonblock() {
    UNREACHABLE();
    return 0;
  }

  ValueType reader_get_unsafe() {
    UNREACHABLE();
    return ValueType();
  }

  void reader_flush() {
    UNREACHABLE();
  }

  PollQueue() = default;
  PollQueue(const PollQueue &) = delete;
  PollQueue &operator=(const PollQueue &) = delete;
  PollQueue(PollQueue &&) = delete;
  PollQueue &operator=(PollQueue &&) = delete;
  ~PollQueue() = default;
};

}  // namespace td

#endif
