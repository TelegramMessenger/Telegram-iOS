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
#include "td/utils/Slice-decl.h"

#include <cstring>
#include <type_traits>

namespace td {

inline MutableSlice::MutableSlice() : s_(const_cast<char *>("")), len_(0) {
}

inline MutableSlice::MutableSlice(char *s, size_t len) : s_(s), len_(len) {
  CHECK(s_ != nullptr);
}

inline MutableSlice::MutableSlice(unsigned char *s, size_t len) : s_(reinterpret_cast<char *>(s)), len_(len) {
  CHECK(s_ != nullptr);
}

inline MutableSlice::MutableSlice(string &s) : s_(&s[0]), len_(s.size()) {
}

template <class T>
MutableSlice::MutableSlice(T s, std::enable_if_t<std::is_same<char *, T>::value, private_tag>) : s_(s) {
  CHECK(s_ != nullptr);
  len_ = std::strlen(s_);
}

inline MutableSlice::MutableSlice(char *s, char *t) : MutableSlice(s, t - s) {
}

inline MutableSlice::MutableSlice(unsigned char *s, unsigned char *t) : MutableSlice(s, t - s) {
}

inline size_t MutableSlice::size() const {
  return len_;
}

inline MutableSlice &MutableSlice::remove_prefix(size_t prefix_len) {
  CHECK(prefix_len <= len_);
  s_ += prefix_len;
  len_ -= prefix_len;
  return *this;
}
inline MutableSlice &MutableSlice::remove_suffix(size_t suffix_len) {
  CHECK(suffix_len <= len_);
  len_ -= suffix_len;
  return *this;
}

inline MutableSlice &MutableSlice::truncate(size_t size) {
  if (len_ > size) {
    len_ = size;
  }
  return *this;
}

inline MutableSlice MutableSlice::copy() const {
  return *this;
}

inline bool MutableSlice::empty() const {
  return len_ == 0;
}

inline char *MutableSlice::data() const {
  return s_;
}

inline char *MutableSlice::begin() const {
  return s_;
}

inline unsigned char *MutableSlice::ubegin() const {
  return reinterpret_cast<unsigned char *>(s_);
}

inline char *MutableSlice::end() const {
  return s_ + len_;
}

inline unsigned char *MutableSlice::uend() const {
  return reinterpret_cast<unsigned char *>(s_) + len_;
}

inline string MutableSlice::str() const {
  return string(begin(), size());
}

inline MutableSlice MutableSlice::substr(size_t from) const {
  CHECK(from <= len_);
  return MutableSlice(s_ + from, len_ - from);
}
inline MutableSlice MutableSlice::substr(size_t from, size_t size) const {
  CHECK(from <= len_);
  return MutableSlice(s_ + from, min(size, len_ - from));
}

inline size_t MutableSlice::find(char c) const {
  for (size_t pos = 0; pos < len_; pos++) {
    if (s_[pos] == c) {
      return pos;
    }
  }
  return npos;
}

inline size_t MutableSlice::rfind(char c) const {
  for (size_t pos = len_; pos-- > 0;) {
    if (s_[pos] == c) {
      return pos;
    }
  }
  return npos;
}

inline void MutableSlice::copy_from(Slice from) {
  CHECK(size() >= from.size());
  std::memcpy(ubegin(), from.ubegin(), from.size());
}

inline char &MutableSlice::back() {
  CHECK(1 <= len_);
  return s_[len_ - 1];
}

inline char &MutableSlice::operator[](size_t i) {
  return s_[i];
}

inline Slice::Slice() : s_(""), len_(0) {
}

inline Slice::Slice(const MutableSlice &other) : s_(other.begin()), len_(other.size()) {
}

inline Slice::Slice(const char *s, size_t len) : s_(s), len_(len) {
  CHECK(s_ != nullptr);
}

inline Slice::Slice(const unsigned char *s, size_t len) : s_(reinterpret_cast<const char *>(s)), len_(len) {
  CHECK(s_ != nullptr);
}

inline Slice::Slice(const string &s) : s_(s.c_str()), len_(s.size()) {
}

template <class T>
Slice::Slice(T s, std::enable_if_t<std::is_same<char *, std::remove_const_t<T>>::value, private_tag>) : s_(s) {
  CHECK(s_ != nullptr);
  len_ = std::strlen(s_);
}

template <class T>
Slice::Slice(T s, std::enable_if_t<std::is_same<const char *, std::remove_const_t<T>>::value, private_tag>) : s_(s) {
  CHECK(s_ != nullptr);
  len_ = std::strlen(s_);
}

inline Slice::Slice(const char *s, const char *t) : s_(s), len_(t - s) {
  CHECK(s_ != nullptr);
}

inline Slice::Slice(const unsigned char *s, const unsigned char *t)
    : s_(reinterpret_cast<const char *>(s)), len_(t - s) {
  CHECK(s_ != nullptr);
}

inline size_t Slice::size() const {
  return len_;
}

inline Slice &Slice::remove_prefix(size_t prefix_len) {
  CHECK(prefix_len <= len_);
  s_ += prefix_len;
  len_ -= prefix_len;
  return *this;
}

inline Slice &Slice::remove_suffix(size_t suffix_len) {
  CHECK(suffix_len <= len_);
  len_ -= suffix_len;
  return *this;
}

inline Slice &Slice::truncate(size_t size) {
  if (len_ > size) {
    len_ = size;
  }
  return *this;
}

inline Slice Slice::copy() const {
  return *this;
}

inline bool Slice::empty() const {
  return len_ == 0;
}

inline const char *Slice::data() const {
  return s_;
}

inline const char *Slice::begin() const {
  return s_;
}

inline const unsigned char *Slice::ubegin() const {
  return reinterpret_cast<const unsigned char *>(s_);
}

inline const char *Slice::end() const {
  return s_ + len_;
}

inline const unsigned char *Slice::uend() const {
  return reinterpret_cast<const unsigned char *>(s_) + len_;
}

inline string Slice::str() const {
  return string(begin(), size());
}

inline Slice Slice::substr(size_t from) const {
  CHECK(from <= len_);
  return Slice(s_ + from, len_ - from);
}
inline Slice Slice::substr(size_t from, size_t size) const {
  CHECK(from <= len_);
  return Slice(s_ + from, min(size, len_ - from));
}

inline size_t Slice::find(char c) const {
  for (size_t pos = 0; pos < len_; pos++) {
    if (s_[pos] == c) {
      return pos;
    }
  }
  return npos;
}

inline size_t Slice::rfind(char c) const {
  for (size_t pos = len_; pos-- > 0;) {
    if (s_[pos] == c) {
      return pos;
    }
  }
  return npos;
}

inline char Slice::back() const {
  CHECK(1 <= len_);
  return s_[len_ - 1];
}

inline char Slice::operator[](size_t i) const {
  return s_[i];
}

inline bool operator==(const Slice &a, const Slice &b) {
  return a.size() == b.size() && std::memcmp(a.data(), b.data(), a.size()) == 0;
}

inline bool operator!=(const Slice &a, const Slice &b) {
  return !(a == b);
}

inline bool operator<(const Slice &a, const Slice &b) {
  auto x = std::memcmp(a.data(), b.data(), td::min(a.size(), b.size()));
  if (x == 0) {
    return a.size() < b.size();
  }
  return x < 0;
}

inline MutableCSlice::MutableCSlice(char *s, char *t) : MutableSlice(s, t) {
  CHECK(*t == '\0');
}

inline CSlice::CSlice(const char *s, const char *t) : Slice(s, t) {
  CHECK(*t == '\0');
}

inline std::size_t SliceHash::operator()(Slice slice) const {
  // simple string hash
  std::size_t result = 0;
  constexpr std::size_t MUL = 123456789;
  for (auto c : slice) {
    result = result * MUL + c;
  }
  return result;
}

inline Slice as_slice(Slice slice) {
  return slice;
}

inline MutableSlice as_slice(MutableSlice slice) {
  return slice;
}

inline Slice as_slice(const string &str) {
  return str;
}

inline MutableSlice as_slice(string &str) {
  return str;
}

inline MutableSlice as_mutable_slice(MutableSlice slice) {
  return slice;
}

inline MutableSlice as_mutable_slice(string &str) {
  return str;
}

}  // namespace td
