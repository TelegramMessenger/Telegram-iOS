//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StackAllocator.h"

#include <cstdlib>
#include <memory>
#include <type_traits>
#include <utility>

namespace td {

class StringBuilder {
 public:
  explicit StringBuilder(MutableSlice slice, bool use_buffer = false);

  StringBuilder() : StringBuilder({}, true) {
  }

  void clear() {
    current_ptr_ = begin_ptr_;
    error_flag_ = false;
  }

  void pop_back() {
    CHECK(current_ptr_ > begin_ptr_);
    current_ptr_--;
  }

  void push_back(char c) {
    if (unlikely(end_ptr_ <= current_ptr_)) {
      if (!reserve_inner(RESERVED_SIZE)) {
        error_flag_ = true;
        return;
      }
    }
    *current_ptr_++ = c;
  }

  void append_char(size_t count, char c);

  MutableCSlice as_cslice() {
    if (current_ptr_ >= end_ptr_ + RESERVED_SIZE) {
      std::abort();  // shouldn't happen
    }
    *current_ptr_ = 0;
    return MutableCSlice(begin_ptr_, current_ptr_);
  }

  size_t size() {
    return static_cast<size_t>(current_ptr_ - begin_ptr_);
  }

  bool is_error() const {
    return error_flag_;
  }

  template <class T>
  std::enable_if_t<std::is_same<char *, std::remove_const_t<T>>::value, StringBuilder> &operator<<(T str) {
    return *this << Slice(str);
  }
  template <class T>
  std::enable_if_t<std::is_same<const char *, std::remove_const_t<T>>::value, StringBuilder> &operator<<(T str) {
    return *this << Slice(str);
  }

  template <size_t N>
  StringBuilder &operator<<(char (&str)[N]) = delete;

  template <size_t N>
  StringBuilder &operator<<(const char (&str)[N]) {
    return *this << Slice(str, N - 1);
  }

  StringBuilder &operator<<(const wchar_t *str) = delete;

  StringBuilder &operator<<(Slice slice);

  StringBuilder &operator<<(bool b) {
    return *this << (b ? Slice("true") : Slice("false"));
  }

  StringBuilder &operator<<(char c) {
    if (unlikely(!reserve())) {
      return on_error();
    }
    *current_ptr_++ = c;
    return *this;
  }

  StringBuilder &operator<<(unsigned char c) {
    return *this << static_cast<unsigned int>(c);
  }

  StringBuilder &operator<<(signed char c) {
    return *this << static_cast<int>(c);
  }

  StringBuilder &operator<<(int x);

  StringBuilder &operator<<(unsigned int x);

  StringBuilder &operator<<(long int x);

  StringBuilder &operator<<(long unsigned int x);

  StringBuilder &operator<<(long long int x);

  StringBuilder &operator<<(long long unsigned int x);

  struct FixedDouble {
    double d;
    int precision;

    FixedDouble(double d, int precision) : d(d), precision(precision) {
    }
  };
  StringBuilder &operator<<(FixedDouble x);

  StringBuilder &operator<<(double x) {
    return *this << FixedDouble(x, 6);
  }

  StringBuilder &operator<<(const void *ptr);

  template <class A, class B>
  StringBuilder &operator<<(const std::pair<A, B> &p) {
    return *this << '[' << p.first << ';' << p.second << ']';
  }

  template <class T>
  StringBuilder &operator<<(const vector<T> &v) {
    *this << '{';
    if (!v.empty()) {
      *this << v[0];
      size_t len = v.size();
      for (size_t i = 1; i < len; i++) {
        *this << ", " << v[i];
      }
    }
    return *this << '}';
  }

  StringBuilder &operator<<(const vector<bool> &v) {
    *this << '{';
    if (!v.empty()) {
      *this << v[0];
      size_t len = v.size();
      for (size_t i = 1; i < len; i++) {
        *this << ", " << static_cast<bool>(v[i]);
      }
    }
    return *this << '}';
  }

 private:
  char *begin_ptr_;
  char *current_ptr_;
  char *end_ptr_;
  bool error_flag_ = false;
  bool use_buffer_ = false;
  std::unique_ptr<char[]> buffer_;
  static constexpr size_t RESERVED_SIZE = 30;

  StringBuilder &on_error() {
    error_flag_ = true;
    return *this;
  }

  bool reserve() {
    if (end_ptr_ > current_ptr_) {
      return true;
    }
    return reserve_inner(RESERVED_SIZE);
  }

  bool reserve(size_t size) {
    if (end_ptr_ > current_ptr_ && static_cast<size_t>(end_ptr_ - current_ptr_) >= size) {
      return true;
    }
    return reserve_inner(size);
  }
  bool reserve_inner(size_t size);
};

template <class T>
std::enable_if_t<std::is_arithmetic<T>::value && !std::is_same<std::decay_t<T>, bool>::value, string> to_string(
    const T &x) {
  const size_t buf_size = 1000;
  auto buf = StackAllocator::alloc(buf_size);
  StringBuilder sb(buf.as_slice());
  sb << x;
  return sb.as_cslice().str();
}

}  // namespace td
