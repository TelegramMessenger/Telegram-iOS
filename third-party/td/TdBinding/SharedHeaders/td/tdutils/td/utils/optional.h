//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

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
    if (this == &other) {
      return *this;
    }
    if (other) {
      impl_ = Result<T>(other.value());
    } else {
      impl_ = Result<T>();
    }
    return *this;
  }

  optional(optional &&) = default;
  optional &operator=(optional &&) = default;
  ~optional() = default;

  explicit operator bool() const noexcept {
    return impl_.is_ok();
  }
  T &value() {
    DCHECK(*this);
    return impl_.ok_ref();
  }
  const T &value() const {
    DCHECK(*this);
    return impl_.ok_ref();
  }
  T &operator*() {
    return value();
  }
  const T &operator*() const {
    return value();
  }
  T unwrap() {
    CHECK(*this);
    auto res = std::move(value());
    impl_ = {};
    return res;
  }

  optional<T> copy() const {
    if (*this) {
      return value();
    }
    return {};
  }

  template <class... ArgsT>
  void emplace(ArgsT &&...args) {
    impl_.emplace(std::forward<ArgsT>(args)...);
  }

 private:
  Result<T> impl_;
};

template <typename T>
struct optional<T, false> : optional<T, true> {
  optional() = default;

  using optional<T, true>::optional;

  optional(const optional &) = delete;
  optional &operator=(const optional &) = delete;
  optional(optional &&) = default;
  optional &operator=(optional &&) = default;
  ~optional() = default;
};

template <class T, class S>
bool operator==(const optional<T> &a, const optional<S> &b) {
  if (a) {
    return static_cast<bool>(b) && a.value() == b.value();
  }
  return !static_cast<bool>(b);
}

template <class T>
bool operator==(const T &a, const optional<T> &b) {
  return static_cast<bool>(b) && a == b.value();
}

template <class T>
bool operator==(const optional<T> &a, const T &b) {
  return static_cast<bool>(a) && a.value() == b;
}

template <class T>
StringBuilder &operator<<(StringBuilder &sb, const optional<T> &v) {
  if (v) {
    return sb << "Some{" << v.value() << "}";
  }
  return sb << "None";
}

}  // namespace td
