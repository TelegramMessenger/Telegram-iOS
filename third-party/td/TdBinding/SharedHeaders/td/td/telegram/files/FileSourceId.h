//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class FileSourceId {
  int32 id = 0;

 public:
  FileSourceId() = default;

  explicit constexpr FileSourceId(int32 file_source_id) : id(file_source_id) {
  }
  template <class T1, typename = std::enable_if_t<std::is_convertible<T1, int32>::value>>
  FileSourceId(T1 file_source_id) = delete;

  bool is_valid() const {
    return id > 0;
  }

  int32 get() const {
    return id;
  }

  bool operator<(const FileSourceId &other) const {
    return id < other.id;
  }

  bool operator==(const FileSourceId &other) const {
    return id == other.id;
  }

  bool operator!=(const FileSourceId &other) const {
    return id != other.id;
  }
};

struct FileSourceIdHash {
  uint32 operator()(FileSourceId file_source_id) const {
    return Hash<int32>()(file_source_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, FileSourceId file_source_id) {
  return string_builder << "FileSourceId(" << file_source_id.get() << ")";
}

}  // namespace td
