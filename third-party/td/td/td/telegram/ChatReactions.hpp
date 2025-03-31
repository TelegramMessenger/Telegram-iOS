//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChatReactions.h"
#include "td/telegram/ReactionType.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ChatReactions::store(StorerT &storer) const {
  bool has_reactions = !reaction_types_.empty();
  bool has_reactions_limit = reactions_limit_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(allow_all_regular_);
  STORE_FLAG(allow_all_custom_);
  STORE_FLAG(has_reactions);
  STORE_FLAG(has_reactions_limit);
  STORE_FLAG(paid_reactions_available_);
  END_STORE_FLAGS();
  if (has_reactions) {
    td::store(reaction_types_, storer);
  }
  if (has_reactions_limit) {
    td::store(reactions_limit_, storer);
  }
}

template <class ParserT>
void ChatReactions::parse(ParserT &parser) {
  bool has_reactions;
  bool has_reactions_limit;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(allow_all_regular_);
  PARSE_FLAG(allow_all_custom_);
  PARSE_FLAG(has_reactions);
  PARSE_FLAG(has_reactions_limit);
  PARSE_FLAG(paid_reactions_available_);
  END_PARSE_FLAGS();
  if (has_reactions) {
    td::parse(reaction_types_, parser);
  }
  if (has_reactions_limit) {
    td::parse(reactions_limit_, parser);
  }
}

}  // namespace td
