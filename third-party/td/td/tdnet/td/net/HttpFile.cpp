//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpFile.h"

#include "td/net/HttpReader.h"

#include "td/utils/format.h"

namespace td {

HttpFile::~HttpFile() {
  if (!temp_file_name.empty()) {
    HttpReader::delete_temp_file(temp_file_name);
  }
}

StringBuilder &operator<<(StringBuilder &sb, const HttpFile &file) {
  return sb << tag("name", file.name) << tag("size", file.size);
}

}  // namespace td
