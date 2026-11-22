//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ReactionType.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

struct ChatReactions {
  vector<ReactionType> reaction_types_;
  bool allow_all_regular_ = false;  // implies empty reaction_types_
  bool allow_all_custom_ = false;   // implies allow_all_regular_
  int32 reactions_limit_ = 0;
  bool paid_reactions_available_ = false;

  ChatReactions() = default;

  static ChatReactions legacy(vector<ReactionType> &&reactions) {
    ChatReactions result;
    result.reaction_types_ = std::move(reactions);
    return result;
  }

  ChatReactions(telegram_api::object_ptr<telegram_api::ChatReactions> &&chat_reactions_ptr, int32 reactions_limit,
                bool paid_reactions_available);

  ChatReactions(td_api::object_ptr<td_api::ChatAvailableReactions> &&chat_reactions_ptr, bool allow_all_custom);

  ChatReactions(bool allow_all_regular, bool allow_all_custom)
      : allow_all_regular_(allow_all_regular), allow_all_custom_(allow_all_custom) {
  }

  ChatReactions get_active_reactions(
      const FlatHashMap<ReactionType, size_t, ReactionTypeHash> &active_reaction_pos) const;

  void fix_broadcast_reactions(const vector<ReactionType> &active_reaction_types);

  bool is_allowed_reaction_type(const ReactionType &reaction) const;

  telegram_api::object_ptr<telegram_api::ChatReactions> get_input_chat_reactions() const;

  td_api::object_ptr<td_api::ChatAvailableReactions> get_chat_available_reactions_object(Td *td) const;

  bool empty() const {
    return reaction_types_.empty() && !allow_all_regular_ && !paid_reactions_available_;
  }

  void ignore_non_paid_reaction_types();

  bool remove_paid_reactions();

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const ChatReactions &lhs, const ChatReactions &rhs);

inline bool operator!=(const ChatReactions &lhs, const ChatReactions &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const ChatReactions &reactions);

}  // namespace td
