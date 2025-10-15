//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"

#include <new>
#include <type_traits>
#include <utility>

namespace td {
namespace detail {

template <size_t... Args>
class MaxSizeImpl {};

template <class T>
constexpr const T &constexpr_max(const T &a, const T &b) {
  return a < b ? b : a;
}

template <size_t Res, size_t X, size_t... Args>
class MaxSizeImpl<Res, X, Args...> {
 public:
  static constexpr size_t value = MaxSizeImpl<constexpr_max(Res, X), Args...>::value;
};

template <size_t Res>
class MaxSizeImpl<Res> {
 public:
  static constexpr size_t value = Res;
};

template <class... Args>
class MaxSize {
 public:
  static constexpr size_t value = MaxSizeImpl<0, sizeof(Args)...>::value;
};

template <size_t to_skip, class... Args>
class IthTypeImpl {};
template <class Res, class... Args>
class IthTypeImpl<0, Res, Args...> {
 public:
  using type = Res;
};
template <size_t pos, class Skip, class... Args>
class IthTypeImpl<pos, Skip, Args...> : public IthTypeImpl<pos - 1, Args...> {};

class Dummy {};

template <size_t pos, class... Args>
class IthType final : public IthTypeImpl<pos, Args..., Dummy> {};

template <bool ok, int offset, class... Types>
class FindTypeOffsetImpl {};

template <int offset, class... Types>
class FindTypeOffsetImpl<true, offset, Types...> {
 public:
  static constexpr int value = offset;
};
template <int offset, class T, class S, class... Types>
class FindTypeOffsetImpl<false, offset, T, S, Types...>
    : public FindTypeOffsetImpl<std::is_same<T, S>::value, offset + 1, T, Types...> {};
template <class T, class... Types>
class FindTypeOffset final : public FindTypeOffsetImpl<false, -1, T, Types...> {};

template <int offset, class... Types>
class ForEachTypeImpl {};

template <int offset>
class ForEachTypeImpl<offset, Dummy> {
 public:
  template <class F>
  static void visit(F &&f) {
  }
};

template <int offset, class T, class... Types>
class ForEachTypeImpl<offset, T, Types...> {
 public:
  template <class F>
  static void visit(F &&f) {
    f(offset, static_cast<T *>(nullptr));
    ForEachTypeImpl<offset + 1, Types...>::visit(f);
  }
};

template <class... Types>
class ForEachType {
 public:
  template <class F>
  static void visit(F &&f) {
    ForEachTypeImpl<0, Types..., Dummy>::visit(f);
  }
};

}  // namespace detail

template <class... Types>
class Variant {
 public:
  static constexpr int npos = -1;
  Variant() {
  }
  Variant(Variant &&other) noexcept {
    other.visit([&](auto &&value) { this->init_empty(std::forward<decltype(value)>(value)); });
  }
  Variant(const Variant &other) {
    other.visit([&](auto &&value) { this->init_empty(std::forward<decltype(value)>(value)); });
  }
  Variant &operator=(Variant &&other) noexcept {
    clear();
    other.visit([&](auto &&value) { this->init_empty(std::forward<decltype(value)>(value)); });
    return *this;
  }
  Variant &operator=(const Variant &other) {
    if (this == &other) {
      return *this;
    }
    clear();
    other.visit([&](auto &&value) { this->init_empty(std::forward<decltype(value)>(value)); });
    return *this;
  }

  bool operator==(const Variant &other) const {
    if (offset_ != other.offset_) {
      return false;
    }
    bool res = false;
    for_each([&](int offset, auto *ptr) {
      using T = std::decay_t<decltype(*ptr)>;
      if (offset == offset_) {
        res = this->get<T>() == other.template get<T>();
      }
    });
    return res;
  }
  bool operator<(const Variant &other) const {
    if (offset_ != other.offset_) {
      return offset_ < other.offset_;
    }
    bool res = false;
    for_each([&](int offset, auto *ptr) {
      using T = std::decay_t<decltype(*ptr)>;
      if (offset == offset_) {
        res = this->get<T>() < other.template get<T>();
      }
    });
    return res;
  }

  template <class T, std::enable_if_t<!std::is_same<std::decay_t<T>, Variant>::value, int> = 0>
  Variant(T &&t) {
    init_empty(std::forward<T>(t));
  }
  template <class T, std::enable_if_t<!std::is_same<std::decay_t<T>, Variant>::value, int> = 0>
  Variant &operator=(T &&t) {
    clear();
    init_empty(std::forward<T>(t));
    return *this;
  }
  template <class T>
  static constexpr int offset() {
    return detail::FindTypeOffset<std::decay_t<T>, Types...>::value;
  }

  template <class T>
  void init_empty(T &&t) {
    LOG_CHECK(offset_ == npos) << offset_
#if TD_CLANG || TD_GCC
                               << ' ' << __PRETTY_FUNCTION__
#endif
        ;
    offset_ = offset<T>();
    new (&get<T>()) std::decay_t<T>(std::forward<T>(t));
  }
  ~Variant() {
    clear();
  }

  template <class F>
  void visit(F &&f) {
    for_each([&](int offset, auto *ptr) {
      using T = std::decay_t<decltype(*ptr)>;
      if (offset == offset_) {
        f(std::move(*this->get_unsafe<T>()));
      }
    });
  }
  template <class F>
  void for_each(F &&f) {
    detail::ForEachType<Types...>::visit(f);
  }
  template <class F>
  void visit(F &&f) const {
    for_each([&](int offset, auto *ptr) {
      using T = std::decay_t<decltype(*ptr)>;
      if (offset == offset_) {
        f(std::move(*this->get_unsafe<T>()));
      }
    });
  }
  template <class F>
  void for_each(F &&f) const {
    detail::ForEachType<Types...>::visit(f);
  }

  void clear() {
    visit([](auto &&value) {
      using T = std::decay_t<decltype(value)>;
      value.~T();
    });
    offset_ = npos;
  }

  template <int offset>
  auto &get() {
    CHECK(offset == offset_);
    return *get_unsafe<offset>();
  }
  template <class T>
  auto &get() {
    return get<offset<T>()>();
  }

  template <int offset>
  const auto &get() const {
    CHECK(offset == offset_);
    return *get_unsafe<offset>();
  }
  template <class T>
  const auto &get() const {
    return get<offset<T>()>();
  }

  int32 get_offset() const {
    return offset_;
  }

  bool empty() const {
    return offset_ == npos;
  }

 private:
  union {
    int64 align_;
    char data_[detail::MaxSize<Types...>::value];
  };
  int offset_{npos};

  template <class T>
  auto *get_unsafe() {
    return reinterpret_cast<T *>(data_);
  }

  template <int offset>
  auto *get_unsafe() {
    using T = typename detail::IthType<offset, Types...>::type;
    return get_unsafe<T>();
  }

  template <class T>
  const auto *get_unsafe() const {
    return reinterpret_cast<const T *>(data_);
  }

  template <int offset>
  const auto *get_unsafe() const {
    using T = typename detail::IthType<offset, Types...>::type;
    return get_unsafe<T>();
  }
};

template <class T, class... Types>
auto &get(Variant<Types...> &v) {
  return v.template get<T>();
}
template <class T, class... Types>
auto &get(const Variant<Types...> &v) {
  return v.template get<T>();
}
template <int T, class... Types>
auto &get(Variant<Types...> &v) {
  return v.template get<T>();
}
template <int T, class... Types>
auto &get(const Variant<Types...> &v) {
  return v.template get<T>();
}

}  // namespace td
