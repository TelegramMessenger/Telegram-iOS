//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/Slice.h"

#if TD_PORT_POSIX
#include <sys/uio.h>
#endif

namespace td {

#if TD_PORT_POSIX

using IoSlice = struct iovec;

inline IoSlice as_io_slice(Slice slice) {
  IoSlice res;
  res.iov_len = slice.size();
  res.iov_base = const_cast<char *>(slice.data());
  return res;
}

inline Slice as_slice(const IoSlice &io_slice) {
  return Slice(static_cast<const char *>(io_slice.iov_base), io_slice.iov_len);
}

#else

using IoSlice = Slice;

inline IoSlice as_io_slice(Slice slice) {
  return slice;
}

#endif

}  // namespace td
