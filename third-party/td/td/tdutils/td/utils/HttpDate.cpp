//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/HttpDate.h"

#include "td/utils/misc.h"
#include "td/utils/Parser.h"
#include "td/utils/Slice.h"

namespace td {

Result<int32> HttpDate::to_unix_time(int32 year, int32 month, int32 day, int32 hour, int32 minute, int32 second) {
  if (year < 1970 || year > 2037) {
    return Status::Error("Invalid year");
  }
  if (month < 1 || month > 12) {
    return Status::Error("Invalid month");
  }
  if (day < 1 || day > days_in_month(year, month)) {
    return Status::Error("Invalid day");
  }
  if (hour < 0 || hour >= 24) {
    return Status::Error("Invalid hour");
  }
  if (minute < 0 || minute >= 60) {
    return Status::Error("Invalid minute");
  }
  if (second < 0 || second > 60) {
    return Status::Error("Invalid second");
  }

  int32 res = 0;
  for (int32 y = 1970; y < year; y++) {
    res += (is_leap(y) + 365) * seconds_in_day();
  }
  for (int32 m = 1; m < month; m++) {
    res += days_in_month(year, m) * seconds_in_day();
  }
  res += (day - 1) * seconds_in_day();
  res += hour * 60 * 60;
  res += minute * 60;
  res += second;
  return res;
}

Result<int32> HttpDate::parse_http_date(string slice) {
  Parser p(slice);
  p.read_till(',');  // ignore week day
  p.skip(',');
  p.skip_whitespaces();
  p.skip_nofail('0');
  TRY_RESULT(day, to_integer_safe<int32>(p.read_word()));
  auto month_name = p.read_word();
  to_lower_inplace(month_name);
  TRY_RESULT(year, to_integer_safe<int32>(p.read_word()));
  p.skip_whitespaces();
  p.skip_nofail('0');
  TRY_RESULT(hour, to_integer_safe<int32>(p.read_till(':')));
  p.skip(':');
  p.skip_nofail('0');
  TRY_RESULT(minute, to_integer_safe<int32>(p.read_till(':')));
  p.skip(':');
  p.skip_nofail('0');
  TRY_RESULT(second, to_integer_safe<int32>(p.read_word()));
  auto gmt = p.read_word();
  TRY_STATUS(std::move(p.status()));
  if (gmt != "GMT") {
    return Status::Error("Timezone must be GMT");
  }

  static Slice month_names[12] = {"jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"};

  int month = 0;

  for (int m = 1; m <= 12; m++) {
    if (month_names[m - 1] == month_name) {
      month = m;
      break;
    }
  }

  if (month == 0) {
    return Status::Error("Unknown month name");
  }

  return to_unix_time(year, month, day, hour, minute, second);
}

}  // namespace td
