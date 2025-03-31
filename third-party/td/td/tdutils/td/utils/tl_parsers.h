//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <array>
#include <cstring>
#include <limits>
#include <memory>
#include <string>

namespace td {

class TlParser {
  const unsigned char *data = nullptr;
  size_t data_len = 0;
  size_t left_len = 0;
  size_t error_pos = std::numeric_limits<size_t>::max();
  std::string error;

  std::unique_ptr<int32[]> data_buf;
  static constexpr size_t SMALL_DATA_ARRAY_SIZE = 6;
  std::array<int32, SMALL_DATA_ARRAY_SIZE> small_data_array;

  alignas(4) static const unsigned char empty_data[sizeof(UInt512)];

 public:
  explicit TlParser(Slice slice);

  TlParser(const TlParser &) = delete;
  TlParser &operator=(const TlParser &) = delete;

  void set_error(const string &error_message);

  const char *get_error() const {
    if (error.empty()) {
      return nullptr;
    }
    return error.c_str();
  }

  size_t get_error_pos() const {
    return error_pos;
  }

  Status get_status() const {
    if (error.empty()) {
      return Status::OK();
    }
    return Status::Error(PSLICE() << error << " at " << error_pos);
  }

  void check_len(const size_t len) {
    if (unlikely(left_len < len)) {
      set_error("Not enough data to read");
    } else {
      left_len -= len;
    }
  }

  bool can_prefetch_int() const {
    return get_left_len() >= sizeof(int32);
  }

  int32 prefetch_int_unsafe() const {
    int32 result;
    std::memcpy(&result, data, sizeof(int32));
    return result;
  }

  int32 fetch_int_unsafe() {
    int32 result;
    std::memcpy(&result, data, sizeof(int32));
    data += sizeof(int32);
    return result;
  }

  int32 fetch_int() {
    check_len(sizeof(int32));
    return fetch_int_unsafe();
  }

  int64 fetch_long_unsafe() {
    int64 result;
    std::memcpy(&result, data, sizeof(int64));
    data += sizeof(int64);
    return result;
  }

  int64 fetch_long() {
    check_len(sizeof(int64));
    return fetch_long_unsafe();
  }

  double fetch_double_unsafe() {
    double result;
    std::memcpy(&result, data, sizeof(double));
    data += sizeof(double);
    return result;
  }

  double fetch_double() {
    check_len(sizeof(double));
    return fetch_double_unsafe();
  }

  template <class T>
  T fetch_binary_unsafe() {
    T result;
    std::memcpy(&result, data, sizeof(T));
    data += sizeof(T);
    return result;
  }

  template <class T>
  T fetch_binary() {
    static_assert(sizeof(T) <= sizeof(empty_data), "too big fetch_binary");
    //static_assert(sizeof(T) % sizeof(int32) == 0, "wrong call to fetch_binary");
    check_len(sizeof(T));
    return fetch_binary_unsafe<T>();
  }

  template <class T>
  T fetch_string() {
    check_len(sizeof(int32));
    size_t result_len = *data;
    const unsigned char *result_begin;
    size_t result_aligned_len;
    if (result_len < 254) {
      result_begin = data + 1;
      result_aligned_len = (result_len >> 2) << 2;
      data += sizeof(int32);
    } else if (result_len == 254) {
      result_len = data[1] + (data[2] << 8) + (data[3] << 16);
      result_begin = data + 4;
      result_aligned_len = ((result_len + 3) >> 2) << 2;
      data += sizeof(int32);
    } else {
      check_len(sizeof(int32));
      auto result_len_uint64 = static_cast<uint64>(data[1]) + (static_cast<uint64>(data[2]) << 8) +
                               (static_cast<uint64>(data[3]) << 16) + (static_cast<uint64>(data[4]) << 24) +
                               (static_cast<uint64>(data[5]) << 32) + (static_cast<uint64>(data[6]) << 40) +
                               (static_cast<uint64>(data[7]) << 48);
      if (result_len_uint64 > std::numeric_limits<size_t>::max() - 3) {
        set_error("Too big string found");
        return T();
      }
      result_len = static_cast<size_t>(result_len_uint64);
      result_begin = data + 8;
      result_aligned_len = ((result_len + 3) >> 2) << 2;
      data += sizeof(int64);
    }
    check_len(result_aligned_len);
    if (!error.empty()) {
      return T();
    }
    data += result_aligned_len;
    return T(reinterpret_cast<const char *>(result_begin), result_len);
  }

  template <class T>
  T fetch_string_raw(const size_t size) {
    //CHECK(size % sizeof(int32) == 0);
    check_len(size);
    if (!error.empty()) {
      return T();
    }
    auto result = reinterpret_cast<const char *>(data);
    data += size;
    return T(result, size);
  }

  void fetch_end() {
    if (left_len) {
      set_error("Too much data to fetch");
    }
  }

  size_t get_left_len() const {
    return left_len;
  }
};

class TlBufferParser : public TlParser {
 public:
  explicit TlBufferParser(const BufferSlice *buffer_slice) : TlParser(buffer_slice->as_slice()), parent_(buffer_slice) {
  }

  template <class T>
  T fetch_string() {
    auto result = TlParser::fetch_string<T>();
    for (auto &c : result) {
      if (c == '\0') {
        c = ' ';
      }
    }
    if (is_valid_utf8(result)) {
      return result;
    }
    result.resize(last_utf8_character_position(result));
    if (is_valid_utf8(result)) {
      return result;
    }

    return T();
  }

  template <class T>
  T fetch_string_raw(const size_t size) {
    return TlParser::fetch_string_raw<T>(size);
  }

 private:
  const BufferSlice *parent_;

  BufferSlice as_buffer_slice(Slice slice);

  bool is_valid_utf8(CSlice str) const;

  static size_t last_utf8_character_position(Slice str);
};

template <>
inline BufferSlice TlBufferParser::fetch_string<BufferSlice>() {
  return as_buffer_slice(TlParser::fetch_string<Slice>());
}

template <>
inline BufferSlice TlBufferParser::fetch_string_raw<BufferSlice>(const size_t size) {
  return as_buffer_slice(TlParser::fetch_string_raw<Slice>(size));
}

}  // namespace td
