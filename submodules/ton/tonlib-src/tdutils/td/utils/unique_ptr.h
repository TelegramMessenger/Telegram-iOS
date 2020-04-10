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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include <cstddef>
#include <type_traits>
#include <utility>

namespace td {

// const-correct and compiler-friendly (g++ RAM and CPU usage 10 times less than for std::unique_ptr)
// replacement for std::unique_ptr
template <class T>
class unique_ptr final {
 public:
  using pointer = T *;
  using element_type = T;

  unique_ptr() noexcept = default;
  unique_ptr(const unique_ptr &other) = delete;
  unique_ptr &operator=(const unique_ptr &other) = delete;
  unique_ptr(unique_ptr &&other) noexcept : ptr_(other.release()) {
  }
  unique_ptr &operator=(unique_ptr &&other) noexcept {
    reset(other.release());
    return *this;
  }
  ~unique_ptr() {
    reset();
  }

  unique_ptr(std::nullptr_t) noexcept {
  }
  explicit unique_ptr(T *ptr) noexcept : ptr_(ptr) {
  }
  template <class S, class = std::enable_if_t<std::is_base_of<T, S>::value>>
  unique_ptr(unique_ptr<S> &&other) noexcept : ptr_(static_cast<S *>(other.release())) {
  }
  template <class S, class = std::enable_if_t<std::is_base_of<T, S>::value>>
  unique_ptr &operator=(unique_ptr<S> &&other) noexcept {
    reset(static_cast<T *>(other.release()));
    return *this;
  }
  void reset(T *new_ptr = nullptr) noexcept {
    delete ptr_;
    ptr_ = new_ptr;
  }
  T *release() noexcept {
    auto res = ptr_;
    ptr_ = nullptr;
    return res;
  }
  T *get() noexcept {
    return ptr_;
  }
  const T *get() const noexcept {
    return ptr_;
  }
  T *operator->() noexcept {
    return ptr_;
  }
  const T *operator->() const noexcept {
    return ptr_;
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
  T *ptr_{nullptr};
};

template <class T>
bool operator==(std::nullptr_t, const unique_ptr<T> &p) {
  return !p;
}
template <class T>
bool operator==(const unique_ptr<T> &p, std::nullptr_t) {
  return !p;
}
template <class T>
bool operator!=(std::nullptr_t, const unique_ptr<T> &p) {
  return static_cast<bool>(p);
}
template <class T>
bool operator!=(const unique_ptr<T> &p, std::nullptr_t) {
  return static_cast<bool>(p);
}

template <class Type, class... Args>
unique_ptr<Type> make_unique(Args &&... args) {
  return unique_ptr<Type>(new Type(std::forward<Args>(args)...));
}

}  // namespace td
