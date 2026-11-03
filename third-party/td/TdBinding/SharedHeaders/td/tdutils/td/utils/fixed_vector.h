//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <utility>

namespace td {

template <class T>
class fixed_vector {
 public:
  fixed_vector() = default;
  explicit fixed_vector(size_t size) : ptr_(new T[size]), size_(size) {
  }
  fixed_vector(fixed_vector &&other) noexcept {
    swap(other);
  }
  fixed_vector &operator=(fixed_vector &&other) noexcept {
    swap(other);
    return *this;
  }
  fixed_vector(const fixed_vector &) = delete;
  fixed_vector &operator=(const fixed_vector &) = delete;
  ~fixed_vector() {
    delete[] ptr_;
  }

  using iterator = T *;
  using const_iterator = const T *;

  T &operator[](size_t i) {
    return ptr_[i];
  }
  const T &operator[](size_t i) const {
    return ptr_[i];
  }

  T *begin() {
    return ptr_;
  }
  const T *begin() const {
    return ptr_;
  }
  T *end() {
    return ptr_ + size_;
  }
  const T *end() const {
    return ptr_ + size_;
  }

  bool empty() const {
    return size() == 0;
  }
  size_t size() const {
    return size_;
  }

  void swap(fixed_vector<T> &other) {
    std::swap(ptr_, other.ptr_);
    std::swap(size_, other.size_);
  }

 private:
  T *ptr_{};
  size_t size_{0};
};

template <class T>
void swap(fixed_vector<T> &lhs, fixed_vector<T> &rhs) {
  lhs.swap(rhs);
}

}  // namespace td
