//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/buffer.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"

namespace td {

class DarwinHttp {
 public:
  static void get(CSlice url, Promise<BufferSlice> promise);
  static void post(CSlice url, Slice data, Promise<BufferSlice> promise);
};

}  // namespace td
