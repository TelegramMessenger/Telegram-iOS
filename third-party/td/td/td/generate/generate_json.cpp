//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_json_converter.h"

#include "td/tl/tl_config.h"
#include "td/tl/tl_generate.h"

int main() {
  td::gen_json_converter(td::tl::read_tl_config_from_file("tlo/td_api.tlo"), "td/telegram/td_api_json",
                         td::tl::TL_writer::Server);
}
