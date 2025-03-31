//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/ExitGuard.h"
#include "td/utils/logging.h"
#include "td/utils/OptionParser.h"
#include "td/utils/port/detail/ThreadIdGuard.h"
#include "td/utils/port/stacktrace.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"

#if TD_EMSCRIPTEN
#include <emscripten.h>
#endif

int main(int argc, char **argv) {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(FATAL));
  td::ExitGuard exit_guard;
  td::detail::ThreadIdGuard thread_id_guard;
  td::Stacktrace::init();
  td::init_openssl_threads();

  td::TestsRunner &runner = td::TestsRunner::get_default();

  int default_verbosity_level = 1;
  td::OptionParser options;
  options.add_option('f', "filter", "run only specified tests",
                     [&](td::Slice filter) { runner.add_substr_filter(filter.str()); });
  options.add_option('o', "offset", "run tests from the specified test",
                     [&](td::Slice offset) { runner.set_offset(offset.str()); });
  options.add_option('s', "stress", "run tests infinitely", [&] { runner.set_stress_flag(true); });
  options.add_checked_option('v', "verbosity", "log verbosity level",
                             td::OptionParser::parse_integer(default_verbosity_level));
  options.add_check([&] {
    if (default_verbosity_level < 0) {
      return td::Status::Error("Wrong verbosity level specified");
    }
    return td::Status::OK();
  });
  auto r_non_options = options.run(argc, argv, 0);
  if (r_non_options.is_error()) {
    LOG(PLAIN) << argv[0] << ": " << r_non_options.error().message();
    LOG(PLAIN) << options;
    return 1;
  }
  SET_VERBOSITY_LEVEL(default_verbosity_level);

#if TD_EMSCRIPTEN
  emscripten_set_main_loop(
      [] {
        td::TestsRunner &default_runner = td::TestsRunner::get_default();
        if (!default_runner.run_all_step()) {
          emscripten_cancel_main_loop();
        }
      },
      10, 0);
#else
  runner.run_all();
#endif
}
