//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageEntity.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"

#include <cstddef>
#include <cstdint>

static td::string get_utf_string(td::Slice from) {
  td::string res;
  td::string alph = " ab@./01#";
  for (auto c : from) {
    res += alph[static_cast<td::uint8>(c) % alph.size()];
  }
  LOG(ERROR) << res;
  return res;
}

extern "C" int LLVMFuzzerTestOneInput(std::uint8_t *data, std::size_t data_size) {
  td::find_urls(get_utf_string(td::Slice(data, data_size)));
  //td::find_hashtags(get_utf_string(td::Slice(data, data_size)));
  //td::find_bot_commands(get_utf_string(td::Slice(data, data_size)));
  //td::is_email_address(get_utf_string(td::Slice(data, data_size)));
  //td::find_mentions(get_utf_string(td::Slice(data, data_size)));
  return 0;
}
