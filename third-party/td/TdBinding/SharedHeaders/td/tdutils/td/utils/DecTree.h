//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Random.h"

#include <functional>
#include <utility>

namespace td {

template <typename KeyType, typename ValueType, typename Compare = std::less<KeyType>>
class DecTree {
  struct Node {
    unique_ptr<Node> left_;
    unique_ptr<Node> right_;
    size_t size_;
    KeyType key_;
    ValueType value_;
    uint32 y_;

    void relax() {
      size_ = 1;
      if (left_ != nullptr) {
        size_ += left_->size_;
      }
      if (right_ != nullptr) {
        size_ += right_->size_;
      }
    }

    Node(KeyType key, ValueType value, uint32 y) : size_(1), key_(std::move(key)), value_(std::move(value)), y_(y) {
    }
  };
  unique_ptr<Node> root_;

  static unique_ptr<Node> create_node(KeyType key, ValueType value, uint32 y) {
    return make_unique<Node>(std::move(key), std::move(value), y);
  }

  static unique_ptr<Node> insert_node(unique_ptr<Node> Tree, KeyType key, ValueType value, uint32 y) {
    if (Tree == nullptr) {
      return create_node(std::move(key), std::move(value), y);
    }
    if (Tree->y_ < y) {
      auto P = split_node(std::move(Tree), key);
      auto T = create_node(std::move(key), std::move(value), y);
      T->left_ = std::move(P.first);
      T->right_ = std::move(P.second);
      T->relax();
      return T;
    }
    if (Compare()(key, Tree->key_)) {
      Tree->left_ = insert_node(std::move(Tree->left_), std::move(key), std::move(value), y);
    } else if (Compare()(Tree->key_, key)) {
      Tree->right_ = insert_node(std::move(Tree->right_), std::move(key), std::move(value), y);
    } else {
      // ?? assert
    }
    Tree->relax();
    return Tree;
  }

  static unique_ptr<Node> remove_node(unique_ptr<Node> Tree, const KeyType &key) {
    if (Tree == nullptr) {
      // ?? assert
      return nullptr;
    }
    if (Compare()(key, Tree->key_)) {
      Tree->left_ = remove_node(std::move(Tree->left_), key);
    } else if (Compare()(Tree->key_, key)) {
      Tree->right_ = remove_node(std::move(Tree->right_), key);
    } else {
      Tree = merge_node(std::move(Tree->left_), std::move(Tree->right_));
    }
    if (Tree != nullptr) {
      Tree->relax();
    }
    return Tree;
  }

  static ValueType *get_node(unique_ptr<Node> &Tree, const KeyType &key) {
    if (Tree == nullptr) {
      return nullptr;
    }
    if (Compare()(key, Tree->key_)) {
      return get_node(Tree->left_, key);
    } else if (Compare()(Tree->key_, key)) {
      return get_node(Tree->right_, key);
    } else {
      return &Tree->value_;
    }
  }

  static ValueType *get_node_by_idx(unique_ptr<Node> &Tree, size_t idx) {
    CHECK(Tree != nullptr);
    auto s = (Tree->left_ != nullptr) ? Tree->left_->size_ : 0;
    if (idx < s) {
      return get_node_by_idx(Tree->left_, idx);
    } else if (idx == s) {
      return &Tree->value_;
    } else {
      return get_node_by_idx(Tree->right_, idx - s - 1);
    }
  }

  static const ValueType *get_node(const unique_ptr<Node> &Tree, const KeyType &key) {
    if (Tree == nullptr) {
      return nullptr;
    }
    if (Compare()(key, Tree->key_)) {
      return get_node(Tree->left_, key);
    } else if (Compare()(Tree->key_, key)) {
      return get_node(Tree->right_, key);
    } else {
      return &Tree->value_;
    }
  }

  static const ValueType *get_node_by_idx(const unique_ptr<Node> &Tree, size_t idx) {
    CHECK(Tree != nullptr);
    auto s = (Tree->left_ != nullptr) ? Tree->left_->size_ : 0;
    if (idx < s) {
      return get_node_by_idx(Tree->left_, idx);
    } else if (idx == s) {
      return &Tree->value_;
    } else {
      return get_node_by_idx(Tree->right_, idx - s - 1);
    }
  }

  static std::pair<unique_ptr<Node>, unique_ptr<Node>> split_node(unique_ptr<Node> Tree, const KeyType &key) {
    if (Tree == nullptr) {
      return {nullptr, nullptr};
    }
    if (Compare()(key, Tree->key_)) {
      auto P = split_node(std::move(Tree->left_), key);
      Tree->left_ = std::move(P.second);
      Tree->relax();
      P.second = std::move(Tree);
      return P;
    } else {
      auto P = split_node(std::move(Tree->right_), key);
      Tree->right_ = std::move(P.first);
      Tree->relax();
      P.first = std::move(Tree);
      return P;
    }
  }

  static unique_ptr<Node> merge_node(unique_ptr<Node> left, unique_ptr<Node> right) {
    if (left == nullptr) {
      return right;
    }
    if (right == nullptr) {
      return left;
    }
    if (left->y_ < right->y_) {
      right->left_ = merge_node(std::move(left), std::move(right->left_));
      right->relax();
      return right;
    } else {
      left->right_ = merge_node(std::move(left->right_), std::move(right));
      left->relax();
      return left;
    }
  }

 public:
  size_t size() const {
    if (root_ == nullptr) {
      return 0;
    } else {
      return root_->size_;
    }
  }
  void insert(KeyType key, ValueType value) {
    root_ = insert_node(std::move(root_), std::move(key), std::move(value), Random::fast_uint32());
  }
  void remove(const KeyType &key) {
    root_ = remove_node(std::move(root_), key);
  }
  void reset() {
    root_ = nullptr;
  }
  ValueType *get(const KeyType &key) {
    return get_node(root_, key);
  }
  ValueType *get_random() {
    if (size() == 0) {
      return nullptr;
    } else {
      return get_node_by_idx(root_, Random::fast_uint32() % size());
    }
  }
  const ValueType *get(const KeyType &key) const {
    return get_node(root_, key);
  }
  const ValueType *get_random() const {
    if (size() == 0) {
      return nullptr;
    } else {
      return get_node_by_idx(root_, Random::fast_uint32() % size());
    }
  }
  bool exists(const KeyType &key) const {
    return get_node(root_, key) != nullptr;
  }
};

}  // namespace td
