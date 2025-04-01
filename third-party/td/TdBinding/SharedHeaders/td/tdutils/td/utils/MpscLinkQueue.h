//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <atomic>

namespace td {
//NB: holder of the queue holds all responsibility of freeing its nodes
class MpscLinkQueueImpl {
 public:
  class Node;
  class Reader;

  void push(Node *node) {
    node->next_ = head_.load(std::memory_order_relaxed);
    while (!head_.compare_exchange_strong(node->next_, node, std::memory_order_release, std::memory_order_relaxed)) {
    }
  }

  void push_unsafe(Node *node) {
    node->next_ = head_.load(std::memory_order_relaxed);
    head_.store(node, std::memory_order_relaxed);
  }

  void pop_all(Reader &reader) {
    return reader.add(head_.exchange(nullptr, std::memory_order_acquire));
  }

  void pop_all_unsafe(Reader &reader) {
    return reader.add(head_.exchange(nullptr, std::memory_order_relaxed));
  }

  class Node {
    friend class MpscLinkQueueImpl;
    Node *next_{nullptr};
  };

  class Reader {
   public:
    Node *read() {
      auto old_head = head_;
      if (head_) {
        head_ = head_->next_;
      }
      return old_head;
    }
    void delay(Node *node) {
      node->next_ = head_;
      if (!head_) {
        tail_ = node;
      }
      head_ = node;
    }
    size_t calc_size() const {
      size_t res = 0;
      for (auto it = head_; it != nullptr; it = it->next_, res++) {
      }
      return res;
    }

   private:
    friend class MpscLinkQueueImpl;
    void add(Node *node) {
      if (node == nullptr) {
        return;
      }
      // Reverse list
      Node *tail = node;
      Node *head = nullptr;
      while (node) {
        auto next = node->next_;
        node->next_ = head;
        head = node;
        node = next;
      }
      if (head_ == nullptr) {
        head_ = head;
      } else {
        tail_->next_ = head;
      }
      tail_ = tail;
    }
    Node *head_{nullptr};
    Node *tail_{nullptr};
  };

 private:
  std::atomic<Node *> head_{nullptr};
};

// Uses MpscLinkQueueImpl.
// Node should have to_mpsc_link_queue_node and from_mpsc_link_queue_node functions
template <class Node>
class MpscLinkQueue {
 public:
  void push(Node node) {
    impl_.push(node.to_mpsc_link_queue_node());
  }
  void push_unsafe(Node node) {
    impl_.push_unsafe(node.to_mpsc_link_queue_node());
  }
  class Reader {
   public:
    ~Reader() {
      CHECK(!read());
    }
    Node read() {
      auto node = impl_.read();
      if (!node) {
        return {};
      }
      return Node::from_mpsc_link_queue_node(node);
    }
    void delay(Node node) {
      impl_.delay(node.to_mpsc_link_queue_node());
    }
    size_t calc_size() const {
      return impl_.calc_size();
    }

   private:
    friend class MpscLinkQueue;

    MpscLinkQueueImpl::Reader impl_;
    MpscLinkQueueImpl::Reader &impl() {
      return impl_;
    }
  };

  void pop_all(Reader &reader) {
    return impl_.pop_all(reader.impl());
  }
  void pop_all_unsafe(Reader &reader) {
    return impl_.pop_all_unsafe(reader.impl());
  }

 private:
  MpscLinkQueueImpl impl_;
};

template <class Value>
class MpscLinkQueueUniquePtrNode {
 public:
  MpscLinkQueueUniquePtrNode() = default;
  explicit MpscLinkQueueUniquePtrNode(unique_ptr<Value> ptr) : ptr_(std::move(ptr)) {
  }

  MpscLinkQueueImpl::Node *to_mpsc_link_queue_node() {
    return ptr_.release()->to_mpsc_link_queue_node();
  }
  static MpscLinkQueueUniquePtrNode<Value> from_mpsc_link_queue_node(MpscLinkQueueImpl::Node *node) {
    return MpscLinkQueueUniquePtrNode<Value>(unique_ptr<Value>(Value::from_mpsc_link_queue_node(node)));
  }

  explicit operator bool() const noexcept {
    return ptr_ != nullptr;
  }

  Value &value() {
    return *ptr_;
  }

 private:
  unique_ptr<Value> ptr_;
};

}  // namespace td
