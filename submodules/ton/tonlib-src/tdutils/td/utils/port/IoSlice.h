/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
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

inline Slice as_slice(const IoSlice io_slice) {
  return Slice(static_cast<const char *>(io_slice.iov_base), io_slice.iov_len);
}

#else

using IoSlice = Slice;

inline IoSlice as_io_slice(Slice slice) {
  return slice;
}

#endif

}  // namespace td
