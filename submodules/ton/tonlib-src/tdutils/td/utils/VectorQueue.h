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

#include "td/utils/Span.h"

#include <utility>
#include <vector>

namespace td {

template <class T>
class VectorQueue {
 public:
  template <class S>
  void push(S &&s) {
    vector_.push_back(std::forward<S>(s));
  }
  template <class... Args>
  void emplace(Args &&... args) {
    vector_.emplace_back(std::forward<Args>(args)...);
  }
  T pop() {
    try_shrink();
    return std::move(vector_[read_pos_++]);
  }
  void pop_n(size_t n) {
    read_pos_ += n;
    try_shrink();
  }
  T &front() {
    return vector_[read_pos_];
  }
  T &back() {
    return vector_.back();
  }
  bool empty() const {
    return size() == 0;
  }
  size_t size() const {
    return vector_.size() - read_pos_;
  }
  T *data() {
    return vector_.data() + read_pos_;
  }
  const T *data() const {
    return vector_.data() + read_pos_;
  }
  Span<T> as_span() const {
    return {data(), size()};
  }
  MutableSpan<T> as_mutable_span() {
    return {data(), size()};
  }

 private:
  std::vector<T> vector_;
  size_t read_pos_{0};

  void try_shrink() {
    if (read_pos_ * 2 > vector_.size() && read_pos_ > 4) {
      vector_.erase(vector_.begin(), vector_.begin() + read_pos_);
      read_pos_ = 0;
    }
  }
};

}  // namespace td
