//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <cassert>
#include <cstdint>
#include <cstring>
#include <string>

namespace td {
namespace tl {

class tl_simple_parser {
  const char *data;
  const char *data_begin;
  std::size_t data_len;
  const char *error;
  std::size_t error_pos;

  void set_error(const char *error_message) {
    if (error == NULL) {
      assert(error_message != NULL);
      error = error_message;
      error_pos = static_cast<std::size_t>(data - data_begin);
      data = "\x00\x00\x00\x00\x00\x00\x00\x00";
      data_len = 0;
    } else {
      data = "\x00\x00\x00\x00\x00\x00\x00\x00";
      assert(data_len == 0);
    }
  }

  void check_len(const std::size_t len) {
    if (data_len < len) {
      set_error("Not enough data to read");
    } else {
      data_len -= len;
    }
  }

  tl_simple_parser(const tl_simple_parser &other);
  tl_simple_parser &operator=(const tl_simple_parser &other);

 public:
  tl_simple_parser(const char *data, std::size_t data_len)
      : data(data), data_begin(data), data_len(data_len), error(), error_pos() {
  }

  const char *get_error() const {
    return error;
  }

  std::size_t get_error_pos() const {
    return error_pos;
  }

  std::int32_t fetch_int() {
    check_len(sizeof(std::int32_t));
    std::int32_t result = *reinterpret_cast<const std::int32_t *>(data);
    data += sizeof(std::int32_t);
    return result;
  }

  std::int64_t fetch_long() {
    check_len(sizeof(std::int64_t));
    std::int64_t result;
    std::memcpy(&result, data, sizeof(std::int64_t));
    data += sizeof(std::int64_t);
    return result;
  }

  std::string fetch_string() {
    check_len(4);
    int result_len = static_cast<unsigned char>(data[0]);
    if (result_len < 254) {
      check_len((result_len >> 2) * 4);
      std::string result(data + 1, result_len);
      data += ((result_len >> 2) + 1) * 4;
      return result;
    }

    if (result_len == 254) {
      result_len = static_cast<unsigned char>(data[1]) + (static_cast<unsigned char>(data[2]) << 8) +
                   (static_cast<unsigned char>(data[3]) << 16);
      check_len(((result_len + 3) >> 2) * 4);
      std::string result(data + 4, result_len);
      data += ((result_len + 7) >> 2) * 4;
      return result;
    }

    set_error("Can't fetch string, 255 found");
    return std::string();
  }

  void fetch_end() {
    if (data_len) {
      set_error("Too much data to fetch");
    }
  }
};

}  // namespace tl
}  // namespace td
