//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/logevent/LogEventHelper.h"
#include "td/telegram/SendCodeHelper.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void SendCodeHelper::AuthenticationCodeInfo::store(StorerT &storer) const {
  using td::store;
  store(type, storer);
  store(length, storer);
  store(push_timeout, storer);
  store(cloud_project_number, storer);
  store(pattern, storer);
}

template <class ParserT>
void SendCodeHelper::AuthenticationCodeInfo::parse(ParserT &parser) {
  using td::parse;
  parse(type, parser);
  parse(length, parser);
  parse(push_timeout, parser);
  parse(cloud_project_number, parser);
  parse(pattern, parser);
}

template <class StorerT>
void SendCodeHelper::store(StorerT &storer) const {
  using td::store;
  store(phone_number_, storer);
  store(true, storer);
  store(phone_code_hash_, storer);
  store(sent_code_info_, storer);
  store(next_code_info_, storer);
  store_time(next_code_timestamp_, storer);
}

template <class ParserT>
void SendCodeHelper::parse(ParserT &parser) {
  using td::parse;
  parse(phone_number_, parser);
  bool legacy_is_registered;
  parse(legacy_is_registered, parser);
  parse(phone_code_hash_, parser);
  parse(sent_code_info_, parser);
  parse(next_code_info_, parser);
  parse_time(next_code_timestamp_, parser);
}

}  // namespace td
