//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class HttpDate {
  static bool is_leap(int32 year) {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  }

  static int32 seconds_in_day() {
    return 24 * 60 * 60;
  }

 public:
  static int32 days_in_month(int32 year, int32 month) {
    static int cnt[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    return cnt[month - 1] + (month == 2 && is_leap(year));
  }

  static Result<int32> to_unix_time(int32 year, int32 month, int32 day, int32 hour, int32 minute, int32 second);

  static Result<int32> parse_http_date(string slice);
};

}  // namespace td
