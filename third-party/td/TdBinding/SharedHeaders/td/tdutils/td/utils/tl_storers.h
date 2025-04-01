//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/StorerBase.h"

#include <cstring>

namespace td {

class TlStorerUnsafe {
  unsigned char *buf_;

 public:
  explicit TlStorerUnsafe(unsigned char *buf) : buf_(buf) {
  }

  TlStorerUnsafe(const TlStorerUnsafe &) = delete;
  TlStorerUnsafe &operator=(const TlStorerUnsafe &) = delete;

  template <class T>
  void store_binary(const T &x) {
    std::memcpy(buf_, &x, sizeof(T));
    buf_ += sizeof(T);
  }

  void store_int(int32 x) {
    store_binary<int32>(x);
  }

  void store_long(int64 x) {
    store_binary<int64>(x);
  }

  void store_slice(Slice slice) {
    std::memcpy(buf_, slice.begin(), slice.size());
    buf_ += slice.size();
  }

  void store_storer(const Storer &storer) {
    size_t size = storer.store(buf_);
    buf_ += size;
  }

  template <class T>
  void store_string(const T &str) {
    size_t len = str.size();
    if (len < 254) {
      *buf_++ = static_cast<unsigned char>(len);
      len++;
    } else if (len < (1 << 24)) {
      *buf_++ = static_cast<unsigned char>(254);
      *buf_++ = static_cast<unsigned char>(len & 255);
      *buf_++ = static_cast<unsigned char>((len >> 8) & 255);
      *buf_++ = static_cast<unsigned char>(len >> 16);
    } else if (static_cast<uint64>(len) < (static_cast<uint64>(1) << 32)) {
      *buf_++ = static_cast<unsigned char>(255);
      *buf_++ = static_cast<unsigned char>(len & 255);
      *buf_++ = static_cast<unsigned char>((len >> 8) & 255);
      *buf_++ = static_cast<unsigned char>((len >> 16) & 255);
      *buf_++ = static_cast<unsigned char>((len >> 24) & 255);
      *buf_++ = static_cast<unsigned char>(0);
      *buf_++ = static_cast<unsigned char>(0);
      *buf_++ = static_cast<unsigned char>(0);
    } else {
      LOG(FATAL) << "String size " << len << " is too big to be stored";
    }
    std::memcpy(buf_, str.data(), str.size());
    buf_ += str.size();

    switch (len & 3) {
      case 1:
        *buf_++ = 0;
        // fallthrough
      case 2:
        *buf_++ = 0;
        // fallthrough
      case 3:
        *buf_++ = 0;
    }
  }

  unsigned char *get_buf() const {
    return buf_;
  }
};

class TlStorerCalcLength {
  size_t length = 0;

 public:
  TlStorerCalcLength() = default;
  TlStorerCalcLength(const TlStorerCalcLength &) = delete;
  TlStorerCalcLength &operator=(const TlStorerCalcLength &) = delete;

  template <class T>
  void store_binary(const T &x) {
    length += sizeof(T);
  }

  void store_int(int32 x) {
    store_binary<int32>(x);
  }

  void store_long(int64 x) {
    store_binary<int64>(x);
  }

  void store_slice(Slice slice) {
    length += slice.size();
  }

  void store_storer(const Storer &storer) {
    length += storer.size();
  }

  template <class T>
  void store_string(const T &str) {
    size_t add = str.size();
    if (add < 254) {
      add += 1;
    } else if (add < (1 << 24)) {
      add += 4;
    } else {
      add += 8;
    }
    add = (add + 3) & -4;
    length += add;
  }

  size_t get_length() const {
    return length;
  }
};

template <class T>
size_t tl_calc_length(const T &data) {
  TlStorerCalcLength storer_calc_length;
  data.store(storer_calc_length);
  return storer_calc_length.get_length();
}

template <class T>
size_t tl_store_unsafe(const T &data, unsigned char *dst) TD_WARN_UNUSED_RESULT;

template <class T>
size_t tl_store_unsafe(const T &data, unsigned char *dst) {
  TlStorerUnsafe storer_unsafe(dst);
  data.store(storer_unsafe);
  return static_cast<size_t>(storer_unsafe.get_buf() - dst);
}

}  // namespace td
