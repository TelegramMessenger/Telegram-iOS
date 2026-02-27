//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class HttpFile {
 public:
  string field_name;
  string name;
  string content_type;
  int64 size;
  string temp_file_name;

  HttpFile(string field_name, string name, string content_type, int64 size, string temp_file_name)
      : field_name(std::move(field_name))
      , name(std::move(name))
      , content_type(std::move(content_type))
      , size(size)
      , temp_file_name(std::move(temp_file_name)) {
  }

  HttpFile(const HttpFile &) = delete;
  HttpFile &operator=(const HttpFile &) = delete;

  HttpFile(HttpFile &&other) noexcept
      : field_name(std::move(other.field_name))
      , name(std::move(other.name))
      , content_type(std::move(other.content_type))
      , size(other.size)
      , temp_file_name(std::move(other.temp_file_name)) {
    other.temp_file_name.clear();
  }

  HttpFile &operator=(HttpFile &&) = delete;

  ~HttpFile();
};

StringBuilder &operator<<(StringBuilder &sb, const HttpFile &file);

}  // namespace td
