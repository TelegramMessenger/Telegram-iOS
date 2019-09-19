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

#include <cstring>
#include <type_traits>

namespace td {

namespace detail {

template <class T>
class As {
 public:
  explicit As(void *ptr) : ptr_(ptr) {
  }

  As(const As &new_value) = delete;
  As &operator=(const As &) = delete;
  As(As &&) = default;
  As &operator=(As &&new_value) && {
    std::memcpy(ptr_, new_value.ptr_, sizeof(T));
    return *this;
  }
  ~As() = default;

  As &operator=(T new_value) && {
    std::memcpy(ptr_, &new_value, sizeof(T));
    return *this;
  }

  operator T() const {
    T res;
    std::memcpy(&res, ptr_, sizeof(T));
    return res;
  }
  bool operator==(const As &other) const {
    return this->operator T() == other.operator T();
  }

 private:
  void *ptr_;
};

template <class T>
class ConstAs {
 public:
  explicit ConstAs(const void *ptr) : ptr_(ptr) {
  }

  operator T() const {
    T res;
    std::memcpy(&res, ptr_, sizeof(T));
    return res;
  }

 private:
  const void *ptr_;
};

}  // namespace detail

// no std::is_trivially_copyable in libstdc++ before 5.0
#if __GLIBCXX__
#define TD_IS_TRIVIALLY_COPYABLE(T) __has_trivial_copy(T)
#else
#define TD_IS_TRIVIALLY_COPYABLE(T) std::is_trivially_copyable<T>::value
#endif

template <class ToT, class FromT,
          std::enable_if_t<TD_IS_TRIVIALLY_COPYABLE(ToT) && TD_IS_TRIVIALLY_COPYABLE(FromT), int> = 0>
detail::As<ToT> as(FromT *from) {
  return detail::As<ToT>(from);
}

template <class ToT, class FromT,
          std::enable_if_t<TD_IS_TRIVIALLY_COPYABLE(ToT) && TD_IS_TRIVIALLY_COPYABLE(FromT), int> = 0>
const detail::ConstAs<ToT> as(const FromT *from) {
  return detail::ConstAs<ToT>(from);
}

}  // namespace td
