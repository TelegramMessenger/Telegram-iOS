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
#include "td/utils/port/sleep.h"

#include "td/utils/port/config.h"

#if TD_PORT_POSIX
#if _POSIX_C_SOURCE >= 199309L
#include <time.h>
#else
#include <unistd.h>
#endif
#endif

namespace td {

void usleep_for(int32 microseconds) {
#if TD_PORT_WINDOWS
  int32 milliseconds = microseconds / 1000 + (microseconds % 1000 ? 1 : 0);
  Sleep(milliseconds);
#else
#if _POSIX_C_SOURCE >= 199309L
  timespec ts;
  ts.tv_sec = microseconds / 1000000;
  ts.tv_nsec = (microseconds % 1000000) * 1000;
  nanosleep(&ts, nullptr);
#else
  usleep(microseconds);
#endif
#endif
}

}  // namespace td
