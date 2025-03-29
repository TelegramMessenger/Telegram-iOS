//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/PollId.h"

#include "td/telegram/PollManager.h"
#include "td/telegram/PollManager.hpp"
#include "td/telegram/Td.h"

namespace td {

template <class StorerT>
void store(const PollId &poll_id, StorerT &storer) {
  storer.context()->td().get_actor_unsafe()->poll_manager_->store_poll(poll_id, storer);
}

template <class ParserT>
void parse(PollId &poll_id, ParserT &parser) {
  poll_id = parser.context()->td().get_actor_unsafe()->poll_manager_->parse_poll(parser);
}

}  // namespace td
