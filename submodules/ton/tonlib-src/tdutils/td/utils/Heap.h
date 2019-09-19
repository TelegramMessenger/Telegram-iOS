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

struct HeapNode {
  bool in_heap() const {
    return pos_ != -1;
  }
  bool is_top() const {
    return pos_ == 0;
  }
  void remove() {
    pos_ = -1;
  }
  int pos_ = -1;
};

template <class KeyT, int K = 4>
class KHeap {
 public:
  bool empty() const {
    return array_.empty();
  }
  size_t size() const {
    return array_.size();
  }

  KeyT top_key() const {
    return array_[0].key_;
  }

  HeapNode *pop() {
    CHECK(!empty());
    HeapNode *result = array_[0].node_;
    result->remove();
    erase(0);
    return result;
  }

  void insert(KeyT key, HeapNode *node) {
    CHECK(!node->in_heap());
    array_.push_back({key, node});
    fix_up(static_cast<int>(array_.size()) - 1);
  }

  void fix(KeyT key, HeapNode *node) {
    CHECK(node->in_heap());
    int pos = node->pos_;
    KeyT old_key = array_[pos].key_;
    array_[pos].key_ = key;
    if (key < old_key) {
      fix_up(pos);
    } else {
      fix_down(pos);
    }
  }

  void erase(HeapNode *node) {
    CHECK(node->in_heap());
    int pos = node->pos_;
    node->remove();
    erase(pos);
  }

  template <class F>
  void for_each(F &&f) const {
    for (auto &it : array_) {
      f(it.key_, it.node_);
    }
  }

  template <class F>
  void for_each(F &&f) {
    for (auto &it : array_) {
      f(it.key_, it.node_);
    }
  }

  void check() const {
    for (size_t i = 0; i < array_.size(); i++) {
      for (size_t j = i * K + 1; j < i * K + 1 + K && j < array_.size(); j++) {
        CHECK(array_[i].key_ <= array_[j].key_);
      }
    }
  }

 private:
  struct Item {
    KeyT key_;
    HeapNode *node_;
  };
  vector<Item> array_;

  void fix_up(int pos) {
    auto item = array_[pos];

    while (pos) {
      int parent_pos = (pos - 1) / K;
      auto parent_item = array_[parent_pos];

      if (parent_item.key_ < item.key_) {
        break;
      }

      parent_item.node_->pos_ = pos;
      array_[pos] = parent_item;
      pos = parent_pos;
    }

    item.node_->pos_ = pos;
    array_[pos] = item;
  }

  void fix_down(int pos) {
    auto item = array_[pos];
    while (true) {
      int left_pos = pos * K + 1;
      int right_pos = min(left_pos + K, static_cast<int>(array_.size()));
      int next_pos = pos;
      KeyT next_key = item.key_;
      for (int i = left_pos; i < right_pos; i++) {
        KeyT i_key = array_[i].key_;
        if (i_key < next_key) {
          next_key = i_key;
          next_pos = i;
        }
      }
      if (next_pos == pos) {
        break;
      }
      array_[pos] = array_[next_pos];
      array_[pos].node_->pos_ = pos;
      pos = next_pos;
    }

    item.node_->pos_ = pos;
    array_[pos] = item;
  }

  void erase(int pos) {
    array_[pos] = array_.back();
    array_.pop_back();
    if (pos < static_cast<int>(array_.size())) {
      fix_down(pos);
      fix_up(pos);
    }
  }
};

}  // namespace td
