//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

namespace td {

class Stacktrace {
 public:
  struct PrintOptions {
    bool use_gdb = false;
    PrintOptions() {
    }
  };
  static void print_to_stderr(const PrintOptions &options = PrintOptions());

  static void init();
};

}  // namespace td
