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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "td/utils/Status.h"

#if TD_PORT_WINDOWS
#include "td/utils/port/wstring_convert.h"
#endif

#if TD_PORT_POSIX
#include "td/utils/port/thread_local.h"

#include <string.h>

#include <cstring>
#endif

namespace td {

#if TD_PORT_POSIX
CSlice strerror_safe(int code) {
  const size_t size = 1000;

  static TD_THREAD_LOCAL char *buf;
  init_thread_local<char[]>(buf, size);

#if !defined(__GLIBC__) || ((_POSIX_C_SOURCE >= 200112L || _XOPEN_SOURCE >= 600) && !_GNU_SOURCE)
  strerror_r(code, buf, size);
  return CSlice(buf, buf + std::strlen(buf));
#else
  return CSlice(strerror_r(code, buf, size));
#endif
}
#endif

#if TD_PORT_WINDOWS
string winerror_to_string(int code) {
  const size_t size = 1000;
  wchar_t wbuf[size];
  auto res_size = FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, nullptr, code, 0, wbuf, size - 1, nullptr);
  if (res_size == 0) {
    return "Unknown windows error";
  }
  while (res_size != 0 && (wbuf[res_size - 1] == '\n' || wbuf[res_size - 1] == '\r')) {
    res_size--;
  }
  return from_wstring(wbuf, res_size).ok();
}
#endif

}  // namespace td
