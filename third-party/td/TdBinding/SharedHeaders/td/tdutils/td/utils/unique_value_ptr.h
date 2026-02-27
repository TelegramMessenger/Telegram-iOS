//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/unique_ptr.h"

#include <cstddef>
#include <utility>

namespace td {

// copyable by value td::unique_ptr
template <class T>
class unique_value_ptr final {
 public:
  unique_value_ptr() noexcept = default;
  unique_value_ptr(const unique_value_ptr &other) {
    if (other != nullptr) {
      ptr_ = make_unique<T>(*other);
    }
  }
  unique_value_ptr &operator=(const unique_value_ptr &other) {
    if (other == nullptr) {
      ptr_ = nullptr;
    } else {
      ptr_ = make_unique<T>(*other);
    }
    return *this;
  }
  unique_value_ptr(unique_value_ptr &&) noexcept = default;
  unique_value_ptr &operator=(unique_value_ptr &&) = default;
  unique_value_ptr(std::nullptr_t) noexcept {
  }
  unique_value_ptr(unique_ptr<T> &&ptr) noexcept : ptr_(std::move(ptr)) {
  }
  T *get() noexcept {
    return ptr_.get();
  }
  const T *get() const noexcept {
    return ptr_.get();
  }
  T *operator->() noexcept {
    return ptr_.get();
  }
  const T *operator->() const noexcept {
    return ptr_.get();
  }
  T &operator*() noexcept {
    return *ptr_;
  }
  const T &operator*() const noexcept {
    return *ptr_;
  }
  explicit operator bool() const noexcept {
    return ptr_ != nullptr;
  }

 private:
  unique_ptr<T> ptr_;
};

template <class T>
bool operator==(const unique_value_ptr<T> &p, std::nullptr_t) {
  return !p;
}
template <class T>
bool operator!=(const unique_value_ptr<T> &p, std::nullptr_t) {
  return static_cast<bool>(p);
}

template <class T>
bool operator==(const unique_value_ptr<T> &lhs, const unique_value_ptr<T> &rhs) {
  if (lhs == nullptr) {
    return rhs == nullptr;
  }
  return rhs != nullptr && *lhs == *rhs;
}

template <class T>
bool operator!=(const unique_value_ptr<T> &lhs, const unique_value_ptr<T> &rhs) {
  return !(lhs == rhs);
}

template <class Type, class... Args>
unique_value_ptr<Type> make_unique_value(Args &&...args) {
  return unique_value_ptr<Type>(make_unique<Type>(std::forward<Args>(args)...));
}

}  // namespace td
