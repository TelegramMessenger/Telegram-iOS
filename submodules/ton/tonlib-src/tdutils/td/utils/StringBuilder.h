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

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StackAllocator.h"

#include <cstdlib>
#include <memory>
#include <type_traits>

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

  MutableCSlice as_cslice() {
    if (current_ptr_ >= end_ptr_ + reserved_size) {
      std::abort();  // shouldn't happen
    }
    *current_ptr_ = 0;
    return MutableCSlice(begin_ptr_, current_ptr_);
  }

  bool is_error() const {
    return error_flag_;
  }

  StringBuilder &operator<<(const char *str) {
    return *this << Slice(str);
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

  template <class T>
  StringBuilder &operator<<(const T *ptr) {
    return *this << static_cast<const void *>(ptr);
  }

 private:
  char *begin_ptr_;
  char *current_ptr_;
  char *end_ptr_;
  bool error_flag_ = false;
  bool use_buffer_ = false;
  std::unique_ptr<char[]> buffer_;
  static constexpr size_t reserved_size = 30;

  StringBuilder &on_error() {
    error_flag_ = true;
    return *this;
  }

  bool reserve() {
    if (end_ptr_ > current_ptr_) {
      return true;
    }
    return reserve_inner(reserved_size);
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
std::enable_if_t<std::is_arithmetic<T>::value, string> to_string(const T &x) {
  const size_t buf_size = 1000;
  auto buf = StackAllocator::alloc(buf_size);
  StringBuilder sb(buf.as_slice());
  sb << x;
  return sb.as_cslice().str();
}

}  // namespace td
