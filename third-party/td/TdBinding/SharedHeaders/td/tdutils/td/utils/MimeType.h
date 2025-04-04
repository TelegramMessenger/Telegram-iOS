//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

namespace td {

class MimeType {
 public:
  static string to_extension(Slice mime_type, Slice default_value = Slice());
  static string from_extension(Slice extension, Slice default_value = Slice());
};

}  // namespace td
