//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/sleep.h"

#include "td/utils/port/config.h"

#if TD_PORT_WINDOWS
#include "td/utils/port/Clocks.h"
#endif

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
  if (microseconds < 2000) {
    auto end_time = Clocks::monotonic() + microseconds * 1e-6;
    do {
      SwitchToThread();
    } while (Clocks::monotonic() < end_time);
  } else {
    int32 milliseconds = microseconds / 1000 + (microseconds % 1000 ? 1 : 0);
    Sleep(milliseconds);
  }
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
