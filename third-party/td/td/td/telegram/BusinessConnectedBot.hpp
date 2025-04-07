//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessBotRights.h"
#include "td/telegram/BusinessBotRights.hpp"
#include "td/telegram/BusinessConnectedBot.h"
#include "td/telegram/BusinessRecipients.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessConnectedBot::store(StorerT &storer) const {
  bool can_reply = false;
  bool has_rights = true;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(can_reply_);
  STORE_FLAG(has_rights);
  END_STORE_FLAGS();
  td::store(user_id_, storer);
  td::store(recipients_, storer);
  td::store(rights_, storer);
}

template <class ParserT>
void BusinessConnectedBot::parse(ParserT &parser) {
  bool can_reply;
  bool has_rights;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(can_reply);
  PARSE_FLAG(has_rights);
  END_PARSE_FLAGS();
  td::parse(user_id_, parser);
  td::parse(recipients_, parser);
  if (has_rights) {
    td::parse(rights_, parser);
  } else {
    rights_ = BusinessBotRights::legacy(can_reply);
  }
}

}  // namespace td
