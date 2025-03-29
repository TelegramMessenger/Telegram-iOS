//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/tl/tl_file_utils.h"

#include <cstdio>
#include <cstdlib>
#include <string>

int main(int argc, char *argv[]) {
  for (int i = 1; i < argc; i++) {
    std::string file_name = argv[i];
    std::string old_contents = td::tl::get_file_contents(file_name);
    std::string new_contents = td::tl::remove_documentation(old_contents);
    if (!td::tl::put_file_contents(file_name, new_contents, true)) {
      std::fprintf(stderr, "Can't write file %s\n", file_name.c_str());
      std::abort();
    }
  }
}
