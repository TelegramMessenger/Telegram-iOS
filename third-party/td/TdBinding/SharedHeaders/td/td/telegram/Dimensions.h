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

struct Dimensions {
  uint16 width = 0;
  uint16 height = 0;
};

Dimensions get_dimensions(int32 width, int32 height, const char *source);

uint32 get_dimensions_pixel_count(const Dimensions &dimensions);

bool operator==(const Dimensions &lhs, const Dimensions &rhs);
bool operator!=(const Dimensions &lhs, const Dimensions &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Dimensions &dimensions);

}  // namespace td
