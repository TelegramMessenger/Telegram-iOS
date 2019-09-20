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

#include "td/utils/common.h"
#include "td/utils/Status.h"

#include <type_traits>
#include <utility>

namespace td {

template <class T, bool = std::is_copy_constructible<T>::value>
class optional {
 public:
  optional() = default;
  template <class T1,
            std::enable_if_t<!std::is_same<std::decay_t<T1>, optional>::value && std::is_constructible<T, T1>::value,
                             int> = 0>
  optional(T1 &&t) : impl_(std::forward<T1>(t)) {
  }

  optional(const optional &other) {
    if (other) {
      impl_ = Result<T>(other.value());
    }
  }

  optional &operator=(const optional &other) {
    if (other) {
      impl_ = Result<T>(other.value());
    } else {
      impl_ = Result<T>();
    }
    return *this;
  }

  optional(optional &&other) = default;
  optional &operator=(optional &&other) = default;
  ~optional() = default;

  explicit operator bool() const {
    return impl_.is_ok();
  }
  T &value() {
    return impl_.ok_ref();
  }
  const T &value() const {
    return impl_.ok_ref();
  }
  T &operator*() {
    return value();
  }
  T unwrap() {
    CHECK(*this);
    auto res = std::move(value());
    impl_ = {};
    return res;
  }

  template <class... ArgsT>
  void emplace(ArgsT &&... args) {
    impl_.emplace(std::forward<ArgsT>(args)...);
  }

 private:
  Result<T> impl_;
};

template <typename T>
struct optional<T, false> : optional<T, true> {
  optional() = default;

  using optional<T, true>::optional;

  optional(const optional &other) = delete;
  optional &operator=(const optional &other) = delete;
  optional(optional &&) = default;
  optional &operator=(optional &&) = default;
  ~optional() = default;
};

}  // namespace td
