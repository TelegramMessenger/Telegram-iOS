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

struct PhotoSizeType {
  int32 type = 0;

  PhotoSizeType() = default;

  explicit PhotoSizeType(int32 type) : type(type) {
  }
};

inline bool operator==(const PhotoSizeType &lhs, char c) {
  return lhs.type == c;
}

inline bool operator==(const PhotoSizeType &lhs, int32 type) {
  return lhs.type == type;
}

inline bool operator==(const PhotoSizeType &lhs, const PhotoSizeType &rhs) {
  return lhs.type == rhs.type;
}

inline bool operator!=(const PhotoSizeType &lhs, char c) {
  return !(lhs == c);
}

inline bool operator!=(const PhotoSizeType &lhs, int32 type) {
  return !(lhs == type);
}

inline bool operator!=(const PhotoSizeType &lhs, const PhotoSizeType &rhs) {
  return !(lhs == rhs);
}

inline StringBuilder &operator<<(StringBuilder &string_builder, const PhotoSizeType &photo_size_type) {
  auto type = photo_size_type.type;
  if ('a' <= type && type <= 'z') {
    return string_builder << static_cast<char>(type);
  }
  return string_builder << type;
}

}  // namespace td
