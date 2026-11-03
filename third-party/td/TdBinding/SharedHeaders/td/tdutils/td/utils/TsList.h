//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/List.h"

#include <mutex>

namespace td {

template <class DataT>
class TsList;

template <class DataT>
class TsListNode : protected ListNode {
 public:
  TsListNode() {
    clear();
  }
  explicit TsListNode(DataT &&data) : data_(std::move(data)) {
    clear();
  }

  ~TsListNode() {
    remove();
  }

  std::unique_lock<std::mutex> lock() TD_WARN_UNUSED_RESULT;

  TsListNode(const TsListNode &) = delete;
  TsListNode &operator=(const TsListNode &) = delete;

  TsListNode(TsListNode &&other) noexcept {
    other.validate();
    if (other.empty()) {
      data_ = std::move(other.data_);
      clear();
    } else {
      auto guard = other.lock();
      init_from(std::move(other));
    }
    validate();
    other.validate();
  }

  TsListNode &operator=(TsListNode &&other) noexcept {
    validate();
    if (this == &other) {
      return *this;
    }
    other.validate();
    remove();

    if (other.empty()) {
      data_ = std::move(other.data_);
    } else {
      auto guard = other.lock();
      init_from(std::move(other));
    }

    validate();
    other.validate();
    return *this;
  }

  void validate() {
    if (empty()) {
      CHECK(ListNode::empty());
    } else {
      auto guard = lock();
      CHECK(!ListNode::empty() || is_root);
    }
  }

  void remove() {
    validate();
    if (is_root) {
      CHECK(ListNode::empty());
      return;
    }
    if (empty()) {
      CHECK(ListNode::empty());
      return;
    }
    {
      auto guard = lock();
      ListNode::remove();
      if (!is_root) {
        parent = nullptr;
      }
    }
    validate();
  }

  void put(TsListNode *other) {
    validate();
    other->validate();
    DCHECK(other->empty());
    DCHECK(!empty());
    DCHECK(!other->is_root);
    {
      auto guard = lock();
      ListNode::put(other);
      other->parent = parent;
    }
    validate();
    other->validate();
  }

  void put_back(TsListNode *other) {
    DCHECK(other->empty());
    DCHECK(!empty());
    DCHECK(!other->is_root);
    auto guard = lock();
    ListNode::put_back(other);
    other->parent = parent;
  }

  bool empty() const {
    return parent == nullptr;
  }

  TsListNode *get_next() {
    return static_cast<TsListNode *>(next);
  }
  TsListNode *get_prev() {
    return static_cast<TsListNode *>(prev);
  }

  DataT &get_data_unsafe() {
    return data_;
  }

 private:
  TsList<DataT> *parent;
  bool is_root{false};
  DataT data_;

  friend class TsList<DataT>;

  void clear() {
    ListNode::clear();
    if (!is_root) {
      parent = nullptr;
    }
  }

  void init_from(TsListNode &&other) {
    ListNode::init_from(std::move(other));
    parent = other.parent;
    other.parent = nullptr;
    data_ = std::move(other.data_);
  }
};

template <class DataT>
class TsList final : public TsListNode<DataT> {
 public:
  TsList() {
    this->parent = this;
    this->is_root = true;
  }
  TsList(const TsList &) = delete;
  TsList &operator=(const TsList &) = delete;
  TsList(TsList &&) = delete;
  TsList &operator=(TsList &&) = delete;
  ~TsList() {
    auto guard = lock();
    while (true) {
      auto res = static_cast<TsListNode<DataT> *>(ListNode::get());
      if (!res) {
        break;
      }
      res->parent = nullptr;
    }
    this->parent = nullptr;
  }
  std::unique_lock<std::mutex> lock() TD_WARN_UNUSED_RESULT {
    return std::unique_lock<std::mutex>(mutex_);
  }
  TsListNode<DataT> *begin() {
    return this->get_next();
  }
  TsListNode<DataT> *end() {
    return this;
  }
  TsListNode<DataT> *get() {
    auto guard = lock();
    auto res = static_cast<TsListNode<DataT> *>(ListNode::get());
    if (res) {
      res->parent = nullptr;
    }
    return res;
  }

 private:
  std::mutex mutex_;
};

template <class DataT>
std::unique_lock<std::mutex> TsListNode<DataT>::lock() {
  if (parent == nullptr) {
    return {};
  }
  CHECK(parent != nullptr);
  return parent->lock();
}

}  // namespace td
