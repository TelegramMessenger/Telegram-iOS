//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Dimensions.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

static uint16 get_dimension(int32 size, const char *source) {
  if (size < 0 || size > 65535) {
    if (source != nullptr) {
      LOG(ERROR) << "Wrong image dimension = " << size << " from " << source;
    }
    return 0;
  }
  return narrow_cast<uint16>(size);
}

Dimensions get_dimensions(int32 width, int32 height, const char *source) {
  Dimensions result;
  result.width = get_dimension(width, source);
  result.height = get_dimension(height, source);
  if (result.width == 0 || result.height == 0) {
    result.width = 0;
    result.height = 0;
  }
  return result;
}

uint32 get_dimensions_pixel_count(const Dimensions &dimensions) {
  return static_cast<uint32>(dimensions.width) * static_cast<uint32>(dimensions.height);
}

bool operator==(const Dimensions &lhs, const Dimensions &rhs) {
  return lhs.width == rhs.width && lhs.height == rhs.height;
}

bool operator!=(const Dimensions &lhs, const Dimensions &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const Dimensions &dimensions) {
  return string_builder << "(" << dimensions.width << ", " << dimensions.height << ")";
}

}  // namespace td
