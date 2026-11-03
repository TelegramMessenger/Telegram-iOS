//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class FileDbId {
  uint64 id = 0;

 public:
  FileDbId() = default;

  explicit constexpr FileDbId(uint64 file_db_id) : id(file_db_id) {
  }
  template <class T1, typename = std::enable_if_t<std::is_convertible<T1, uint64>::value>>
  FileDbId(T1 file_db_id) = delete;

  bool empty() const {
    return id == 0;
  }
  bool is_valid() const {
    return id > 0;
  }

  uint64 get() const {
    return id;
  }

  bool operator<(const FileDbId &other) const {
    return id < other.id;
  }
  bool operator>(const FileDbId &other) const {
    return id > other.id;
  }

  bool operator==(const FileDbId &other) const {
    return id == other.id;
  }

  bool operator!=(const FileDbId &other) const {
    return id != other.id;
  }
};

inline StringBuilder &operator<<(StringBuilder &sb, const FileDbId &file_db_id) {
  return sb << "FileDbId{" << file_db_id.get() << "}";
}

}  // namespace td
