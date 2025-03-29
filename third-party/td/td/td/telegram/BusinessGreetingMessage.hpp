//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessGreetingMessage.h"
#include "td/telegram/BusinessRecipients.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessGreetingMessage::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  END_STORE_FLAGS();
  td::store(shortcut_id_, storer);
  td::store(recipients_, storer);
  td::store(inactivity_days_, storer);
}

template <class ParserT>
void BusinessGreetingMessage::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  END_PARSE_FLAGS();
  td::parse(shortcut_id_, parser);
  td::parse(recipients_, parser);
  td::parse(inactivity_days_, parser);
}

}  // namespace td
