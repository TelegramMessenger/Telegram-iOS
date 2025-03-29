//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_writer_c.h"

#include "td/tl/tl_config.h"
#include "td/tl/tl_generate.h"

int main() {
  td::tl::tl_config config_td = td::tl::read_tl_config_from_file("tlo/td_api.tlo");
  td::tl::write_tl_to_file(config_td, "td/telegram/td_tdc_api.h", td::TlWriterCCommon("TdApi", 1));
  td::tl::write_tl_to_file(config_td, "td/telegram/td_tdc_api_inner.h", td::TlWriterCCommon("TdApi", -1));
  td::tl::write_tl_to_file(config_td, "td/telegram/td_tdc_api.cpp", td::TlWriterCCommon("TdApi", 0));
}
