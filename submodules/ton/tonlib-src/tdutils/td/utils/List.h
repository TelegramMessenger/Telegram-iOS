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

  ListNode(ListNode &&other) {
    if (other.empty()) {
      clear();
    } else {
      ListNode *head = other.prev;
      other.remove();
      head->put(this);
    }
  }

  ListNode &operator=(ListNode &&other) {
    this->remove();

    if (!other.empty()) {
      ListNode *head = other.prev;
      other.remove();
      head->put(this);
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
    other->connect(next);
    this->connect(other);
  }

  void put_back(ListNode *other) {
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

 private:
  void clear() {
    next = this;
    prev = this;
  }
};

}  // namespace td
