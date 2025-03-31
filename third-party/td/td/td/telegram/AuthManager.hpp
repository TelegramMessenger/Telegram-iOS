//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AuthManager.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void AuthManager::WaitPasswordState::store(StorerT &storer) const {
  using td::store;
  store(current_client_salt_, storer);
  store(current_server_salt_, storer);
  store(srp_g_, storer);
  store(srp_p_, storer);
  store(srp_B_, storer);
  store(srp_id_, storer);
  store(hint_, storer);
  store(has_recovery_, storer);
  store(email_address_pattern_, storer);
  store(has_secure_values_, storer);
}

template <class ParserT>
void AuthManager::WaitPasswordState::parse(ParserT &parser) {
  using td::parse;
  parse(current_client_salt_, parser);
  parse(current_server_salt_, parser);
  parse(srp_g_, parser);
  parse(srp_p_, parser);
  parse(srp_B_, parser);
  parse(srp_id_, parser);
  parse(hint_, parser);
  parse(has_recovery_, parser);
  parse(email_address_pattern_, parser);
  parse(has_secure_values_, parser);
}

}  // namespace td
