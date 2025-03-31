//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/SharedSlice.h"

#include "td/utils/buffer.h"

namespace td {

BufferSlice SharedSlice::clone_as_buffer_slice() const {
  return BufferSlice{as_slice()};
}

}  // namespace td
