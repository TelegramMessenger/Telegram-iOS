//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_writer_cpp.h"
#include "tl_writer_h.h"
#include "tl_writer_hpp.h"

#include "td/tl/tl_config.h"
#include "td/tl/tl_generate.h"

#include <string>

int main() {
  std::string tl_name = "mtproto_api";
  std::string path = "td/mtproto/" + tl_name;
  td::tl::tl_config config = td::tl::read_tl_config_from_file("tlo/" + tl_name + ".tlo");
  td::tl::write_tl_to_file(
      config, path + ".cpp",
      td::TD_TL_writer_cpp(tl_name, "Slice", "Slice", {"\"td/tl/tl_object_parse.h\"", "\"td/tl/tl_object_store.h\""}));
  td::tl::write_tl_to_file(
      config, path + ".h",
      td::TD_TL_writer_h(tl_name, "Slice", "Slice", {"\"td/utils/Slice.h\"", "\"td/utils/UInt.h\""}));
  td::tl::write_tl_to_file(config, path + ".hpp", td::TD_TL_writer_hpp(tl_name, "Slice", "Slice"));
}
