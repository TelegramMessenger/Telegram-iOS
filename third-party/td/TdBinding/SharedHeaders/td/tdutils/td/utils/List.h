//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

struct ListNode {
  ListNode *next;
  ListNode *prev;
  ListNode() {
    clear();
  }

  ~ListNode() {
    remove();
  }

  ListNode(const ListNode &) = delete;
  ListNode &operator=(const ListNode &) = delete;

  ListNode(ListNode &&other) noexcept {
    if (other.empty()) {
      clear();
    } else {
      init_from(std::move(other));
    }
  }

  ListNode &operator=(ListNode &&other) noexcept {
    if (this == &other) {
      return *this;
    }

    this->remove();

    if (!other.empty()) {
      init_from(std::move(other));
    }

    return *this;
  }

  void connect(ListNode *to) {
    CHECK(to != nullptr);
    next = to;
    to->prev = this;
  }

  void remove() {
    prev->connect(next);
    clear();
  }

  void put(ListNode *other) {
    DCHECK(other->empty());
    put_unsafe(other);
  }

  void put_back(ListNode *other) {
    DCHECK(other->empty());
    prev->connect(other);
    other->connect(this);
  }

  ListNode *get() {
    ListNode *result = prev;
    if (result == this) {
      return nullptr;
    }
    result->prev->connect(this);
    result->clear();
    // this->connect(result->next);
    return result;
  }

  bool empty() const {
    return next == this;
  }

  ListNode *begin() {
    return next;
  }
  ListNode *end() {
    return this;
  }
  const ListNode *begin() const {
    return next;
  }
  const ListNode *end() const {
    return this;
  }
  ListNode *get_next() {
    return next;
  }
  ListNode *get_prev() {
    return prev;
  }
  const ListNode *get_next() const {
    return next;
  }
  const ListNode *get_prev() const {
    return prev;
  }

 protected:
  void clear() {
    next = this;
    prev = this;
  }

  void init_from(ListNode &&other) {
    ListNode *head = other.prev;
    other.remove();
    head->put_unsafe(this);
  }

  void put_unsafe(ListNode *other) {
    other->connect(next);
    this->connect(other);
  }
};

}  // namespace td
