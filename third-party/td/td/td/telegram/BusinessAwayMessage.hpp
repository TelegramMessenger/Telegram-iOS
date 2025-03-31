//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessAwayMessage.h"
#include "td/telegram/BusinessAwayMessageSchedule.hpp"
#include "td/telegram/BusinessRecipients.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessAwayMessage::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  STORE_FLAG(offline_only_);
  END_STORE_FLAGS();
  td::store(shortcut_id_, storer);
  td::store(recipients_, storer);
  td::store(schedule_, storer);
}

template <class ParserT>
void BusinessAwayMessage::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(offline_only_);
  END_PARSE_FLAGS();
  td::parse(shortcut_id_, parser);
  td::parse(recipients_, parser);
  td::parse(schedule_, parser);
}

}  // namespace td
