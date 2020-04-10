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

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"
#include "td/utils/utf8.h"

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

  alignas(4) static const unsigned char empty_data[sizeof(UInt256)];

 public:
  explicit TlParser(Slice slice) {
    data_len = left_len = slice.size();
    if (is_aligned_pointer<4>(slice.begin())) {
      data = slice.ubegin();
    } else {
      int32 *buf;
      if (data_len <= small_data_array.size() * sizeof(int32)) {
        buf = &small_data_array[0];
      } else {
        LOG(ERROR) << "Unexpected big unaligned data pointer of length " << slice.size() << " at " << slice.begin();
        data_buf = std::make_unique<int32[]>(1 + data_len / sizeof(int32));
        buf = data_buf.get();
      }
      std::memcpy(buf, slice.begin(), slice.size());
      data = reinterpret_cast<unsigned char *>(buf);
    }
  }

  TlParser(const TlParser &other) = delete;
  TlParser &operator=(const TlParser &other) = delete;

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
    const char *result_begin;
    size_t result_aligned_len;
    if (result_len < 254) {
      result_begin = reinterpret_cast<const char *>(data + 1);
      result_aligned_len = (result_len >> 2) << 2;
      data += sizeof(int32);
    } else if (result_len == 254) {
      result_len = data[1] + (data[2] << 8) + (data[3] << 16);
      result_begin = reinterpret_cast<const char *>(data + 4);
      result_aligned_len = ((result_len + 3) >> 2) << 2;
      data += sizeof(int32);
    } else {
      check_len(sizeof(int32));
      result_len = narrow_cast<size_t>(data[1] + (data[2] << 8) + (data[3] << 16) + (data[4] << 24) +
                                       (static_cast<uint64>(data[5]) << 32) + (static_cast<uint64>(data[6]) << 40) +
                                       (static_cast<uint64>(data[7]) << 48));
      if (result_len > std::numeric_limits<size_t>::max() - 3) {
        set_error("Too big string found");
        return T();
      }
      result_begin = reinterpret_cast<const char *>(data + 8);
      result_aligned_len = ((result_len + 3) >> 2) << 2;
      data += sizeof(int64);
    }
    check_len(result_aligned_len);
    if (!error.empty()) {
      return T();
    }
    data += result_aligned_len;
    return T(result_begin, result_len);
  }

  template <class T>
  T fetch_string_raw(const size_t size) {
    //CHECK(size % sizeof(int32) == 0);
    check_len(size);
    if (!error.empty()) {
      return T();
    }
    const char *result = reinterpret_cast<const char *>(data);
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
    if (check_utf8(result)) {
      return result;
    }
    CHECK(!result.empty());
    LOG(WARNING) << "Wrong UTF-8 string [[" << result << "]] in " << format::as_hex_dump<4>(parent_->as_slice());

    // trying to remove last character
    size_t new_size = result.size() - 1;
    while (new_size != 0 && !is_utf8_character_first_code_unit(static_cast<unsigned char>(result[new_size]))) {
      new_size--;
    }
    result.resize(new_size);
    if (check_utf8(result)) {
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

  BufferSlice as_buffer_slice(Slice slice) {
    if (is_aligned_pointer<4>(slice.data())) {
      return parent_->from_slice(slice);
    }
    return BufferSlice(slice);
  }
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
