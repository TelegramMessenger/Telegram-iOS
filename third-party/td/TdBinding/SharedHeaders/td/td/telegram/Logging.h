//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class Logging {
 public:
  static Status set_current_stream(td_api::object_ptr<td_api::LogStream> stream);

  static Result<td_api::object_ptr<td_api::LogStream>> get_current_stream();

  static Status set_verbosity_level(int new_verbosity_level);

  static int get_verbosity_level();

  static vector<string> get_tags();

  static Status set_tag_verbosity_level(Slice tag, int new_verbosity_level);

  static Result<int> get_tag_verbosity_level(Slice tag);

  static void add_message(int log_verbosity_level, Slice message);
};

}  // namespace td
