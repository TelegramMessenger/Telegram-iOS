//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <type_traits>

namespace td {

class Slice;

class MutableSlice {
  char *s_;
  size_t len_;

  struct private_tag {};

 public:
  MutableSlice();
  MutableSlice(char *s, size_t len);
  MutableSlice(unsigned char *s, size_t len);
  MutableSlice(string &s);
  template <class T>
  explicit MutableSlice(T s, std::enable_if_t<std::is_same<char *, T>::value, private_tag> = {});
  MutableSlice(char *s, char *t);
  MutableSlice(unsigned char *s, unsigned char *t);
  template <size_t N>
  constexpr MutableSlice(char (&)[N]) = delete;

  bool empty() const;
  size_t size() const;

  MutableSlice &remove_prefix(size_t prefix_len);
  MutableSlice &remove_suffix(size_t suffix_len);
  MutableSlice &truncate(size_t size);

  MutableSlice copy() const;

  char *data() const;
  char *begin() const;
  unsigned char *ubegin() const;
  char *end() const;
  unsigned char *uend() const;

  string str() const;
  MutableSlice substr(size_t from) const;
  MutableSlice substr(size_t from, size_t size) const;
  size_t find(char c) const;
  size_t rfind(char c) const;
  void fill(char c);
  void fill_zero();
  void fill_zero_secure();

  void copy_from(Slice from);

  char &back();
  char &operator[](size_t i);

  static const size_t npos = static_cast<size_t>(-1);
};

class Slice {
  const char *s_;
  size_t len_;

  struct private_tag {};

 public:
  Slice();
  Slice(const MutableSlice &other);
  Slice(const char *s, size_t len);
  Slice(const unsigned char *s, size_t len);
  Slice(const string &s);
  template <class T>
  explicit Slice(T s, std::enable_if_t<std::is_same<char *, std::remove_const_t<T>>::value, private_tag> = {});
  template <class T>
  explicit Slice(T s, std::enable_if_t<std::is_same<const char *, std::remove_const_t<T>>::value, private_tag> = {});
  Slice(const char *s, const char *t);
  Slice(const unsigned char *s, const unsigned char *t);

  template <size_t N>
  constexpr Slice(char (&)[N]) = delete;

  template <size_t N>
  constexpr Slice(const char (&a)[N]) : s_(a), len_(N - 1) {
  }

  Slice &operator=(string &&) = delete;

  template <size_t N>
  constexpr Slice &operator=(char (&)[N]) = delete;

  template <size_t N>
  constexpr Slice &operator=(const char (&a)[N]) {
    s_ = a;
    len_ = N - 1;
    return *this;
  }

  bool empty() const;
  size_t size() const;

  Slice &remove_prefix(size_t prefix_len);
  Slice &remove_suffix(size_t suffix_len);
  Slice &truncate(size_t size);

  Slice copy() const;

  const char *data() const;
  const char *begin() const;
  const unsigned char *ubegin() const;
  const char *end() const;
  const unsigned char *uend() const;

  string str() const;
  Slice substr(size_t from) const;
  Slice substr(size_t from, size_t size) const;
  size_t find(char c) const;
  size_t rfind(char c) const;

  char back() const;
  char operator[](size_t i) const;

  static const size_t npos = static_cast<size_t>(-1);
};

bool operator==(const Slice &a, const Slice &b);
bool operator!=(const Slice &a, const Slice &b);
bool operator<(const Slice &a, const Slice &b);

class MutableCSlice : public MutableSlice {
  struct private_tag {};

  MutableSlice &remove_suffix(size_t suffix_len) = delete;
  MutableSlice &truncate(size_t size) = delete;

 public:
  MutableCSlice() = delete;
  MutableCSlice(string &s) : MutableSlice(s) {
  }
  template <class T>
  explicit MutableCSlice(T s, std::enable_if_t<std::is_same<char *, T>::value, private_tag> = {}) : MutableSlice(s) {
  }
  MutableCSlice(char *s, char *t);

  template <size_t N>
  constexpr MutableCSlice(char (&)[N]) = delete;

  const char *c_str() const {
    return begin();
  }
};

class CSlice : public Slice {
  struct private_tag {};

  Slice &remove_suffix(size_t suffix_len) = delete;
  Slice &truncate(size_t size) = delete;

 public:
  explicit CSlice(const MutableSlice &other) : Slice(other) {
  }
  CSlice(const MutableCSlice &other) : Slice(other.begin(), other.size()) {
  }
  CSlice(const string &s) : Slice(s) {
  }
  template <class T>
  explicit CSlice(T s, std::enable_if_t<std::is_same<char *, std::remove_const_t<T>>::value, private_tag> = {})
      : Slice(s) {
  }
  template <class T>
  explicit CSlice(T s, std::enable_if_t<std::is_same<const char *, std::remove_const_t<T>>::value, private_tag> = {})
      : Slice(s) {
  }
  CSlice(const char *s, const char *t);

  template <size_t N>
  constexpr CSlice(char (&)[N]) = delete;

  template <size_t N>
  constexpr CSlice(const char (&a)[N]) : Slice(a) {
  }

  CSlice() : CSlice("") {
  }

  CSlice &operator=(string &&) = delete;

  template <size_t N>
  constexpr CSlice &operator=(char (&)[N]) = delete;

  template <size_t N>
  constexpr CSlice &operator=(const char (&a)[N]) {
    this->Slice::operator=(a);
    return *this;
  }

  const char *c_str() const {
    return begin();
  }
};

struct SliceHash {
  uint32 operator()(Slice slice) const;
};

}  // namespace td
