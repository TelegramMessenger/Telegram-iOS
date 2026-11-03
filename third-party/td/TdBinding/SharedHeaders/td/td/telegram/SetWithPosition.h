//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/algorithm.h"
#include "td/utils/common.h"

#include <algorithm>
#include <set>
#include <utility>

namespace td {

template <class T>
class FastSetWithPosition {
 public:
  std::vector<T> get_some_elements() const {
    std::vector<T> res;
    res.reserve(4);
    if (!checked_.empty()) {
      res.push_back(*checked_.begin());
      res.push_back(*checked_.rbegin());
    }
    if (!not_checked_.empty()) {
      res.push_back(*not_checked_.begin());
      res.push_back(*not_checked_.rbegin());
    }
    td::unique(res);
    if (res.size() > 2) {
      res.erase(res.begin() + 1, res.end() - 1);
    }
    return res;
  }

  bool add(T x) {
    if (checked_.count(x) != 0) {
      return false;
    }
    return not_checked_.insert(x).second;
  }

  bool remove(T x) {
    return checked_.erase(x) != 0 || not_checked_.erase(x) != 0;
  }

  bool has_next() const {
    return !not_checked_.empty();
  }

  void reset_position() {
    if (not_checked_.empty()) {
      not_checked_ = std::move(checked_);
    } else {
      not_checked_.insert(checked_.begin(), checked_.end());
    }
    reset_to_empty(checked_);
  }

  T next() {
    CHECK(has_next());
    auto it = not_checked_.begin();
    auto res = *it;
    not_checked_.erase(it);
    checked_.insert(res);
    return res;
  }

  void merge(FastSetWithPosition &&other) {
    if (this == &other) {
      return;
    }

    if (size() < other.size()) {
      std::swap(*this, other);
    }
    for (auto x : other.checked_) {
      not_checked_.erase(x);
      checked_.insert(x);
    }

    for (auto x : other.not_checked_) {
      if (checked_.count(x) != 0) {
        continue;
      }
      not_checked_.insert(x);
    }
  }

  size_t size() const {
    return checked_.size() + not_checked_.size();
  }

  bool empty() const {
    return size() == 0;
  }

 private:
  std::set<T> checked_;
  std::set<T> not_checked_;
};

template <class T>
class SetWithPosition {
 public:
  std::vector<T> get_some_elements() const {
    if (fast_) {
      return fast_->get_some_elements();
    }
    if (has_value_) {
      return {value_};
    }
    return {};
  }

  bool add(T x) {
    if (fast_) {
      return fast_->add(x);
    }
    if (!has_value_) {
      value_ = x;
      has_value_ = true;
      is_checked_ = false;
      return true;
    }
    if (value_ == x) {
      return false;
    }
    make_fast();
    return fast_->add(x);
  }

  bool remove(T x) {
    if (fast_) {
      return fast_->remove(x);
    }
    if (has_value_ && value_ == x) {
      has_value_ = false;
      is_checked_ = false;
      return true;
    }
    return false;
  }

  bool has_next() const {
    if (fast_) {
      return fast_->has_next();
    }
    return has_value_ && !is_checked_;
  }

  void reset_position() {
    if (fast_) {
      fast_->reset_position();
      return;
    }
    is_checked_ = false;
  }

  T next() {
    CHECK(has_next());
    if (fast_) {
      return fast_->next();
    }
    is_checked_ = true;
    return value_;
  }

  void merge(SetWithPosition &&other) {
    if (this == &other) {
      return;
    }
    if (size() < other.size()) {
      std::swap(*this, other);
    }
    if (other.size() == 0) {
      return;
    }
    if (other.fast_ == nullptr && fast_ == nullptr && value_ == other.value_) {
      is_checked_ |= other.is_checked_;
      other.value_ = T();
      other.has_value_ = false;
      other.is_checked_ = false;
      return;
    }
    make_fast();
    other.make_fast();
    fast_->merge(std::move(*other.fast_));
    reset_to_empty(other);
  }

  size_t size() const {
    if (fast_) {
      return fast_->size();
    }
    return static_cast<size_t>(has_value_);
  }

  bool empty() const {
    if (fast_) {
      return false;
    }
    return !has_value_;
  }

 private:
  T value_{};
  bool has_value_{false};
  bool is_checked_{false};
  unique_ptr<FastSetWithPosition<T>> fast_;

  void make_fast() {
    if (fast_) {
      return;
    }
    fast_ = make_unique<FastSetWithPosition<T>>();
    CHECK(has_value_);
    fast_->add(value_);
    if (is_checked_) {
      fast_->next();
    }
  }
};

}  // namespace td
