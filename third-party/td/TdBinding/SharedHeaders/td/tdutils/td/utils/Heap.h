//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
  int32 pos_ = -1;
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

  KeyT get_key(const HeapNode *node) const {
    auto pos = static_cast<size_t>(node->pos_);
    CHECK(pos < array_.size());
    return array_[pos].key_;
  }

  const HeapNode *top() const {
    return array_[0].node_;
  }

  HeapNode *pop() {
    CHECK(!empty());
    HeapNode *result = array_[0].node_;
    result->remove();
    erase(static_cast<size_t>(0));
    return result;
  }

  void insert(KeyT key, HeapNode *node) {
    CHECK(!node->in_heap());
    array_.push_back({key, node});
    fix_up(array_.size() - 1);
  }

  void fix(KeyT key, HeapNode *node) {
    auto pos = static_cast<size_t>(node->pos_);
    CHECK(pos < array_.size());
    KeyT old_key = array_[pos].key_;
    array_[pos].key_ = key;
    if (key < old_key) {
      fix_up(pos);
    } else {
      fix_down(pos);
    }
  }

  void erase(HeapNode *node) {
    auto pos = static_cast<size_t>(node->pos_);
    node->remove();
    CHECK(pos < array_.size());
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

  void fix_up(size_t pos) {
    auto item = array_[pos];

    while (pos) {
      auto parent_pos = (pos - 1) / K;
      auto parent_item = array_[parent_pos];

      if (parent_item.key_ < item.key_) {
        break;
      }

      parent_item.node_->pos_ = static_cast<int32>(pos);
      array_[pos] = parent_item;
      pos = parent_pos;
    }

    item.node_->pos_ = static_cast<int32>(pos);
    array_[pos] = item;
  }

  void fix_down(size_t pos) {
    auto item = array_[pos];
    while (true) {
      auto left_pos = pos * K + 1;
      auto right_pos = min(left_pos + K, array_.size());
      auto next_pos = pos;
      KeyT next_key = item.key_;
      for (auto i = left_pos; i < right_pos; i++) {
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
      array_[pos].node_->pos_ = static_cast<int32>(pos);
      pos = next_pos;
    }

    item.node_->pos_ = static_cast<int32>(pos);
    array_[pos] = item;
  }

  void erase(size_t pos) {
    array_[pos] = array_.back();
    array_.pop_back();
    if (pos < array_.size()) {
      fix_down(pos);
      fix_up(pos);
    }
    if (array_.capacity() > 50 && array_.size() < array_.capacity() / 4) {
      array_.shrink_to_fit();
    }
  }
};

}  // namespace td
