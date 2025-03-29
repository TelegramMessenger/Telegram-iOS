//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReactionListType.h"

namespace td {

string get_reaction_list_type_database_key(ReactionListType reaction_list_type) {
  switch (reaction_list_type) {
    case ReactionListType::Recent:
      return "recent_reactions";
    case ReactionListType::Top:
      return "top_reactions";
    case ReactionListType::DefaultTag:
      return "default_tag_reactions";
    default:
      UNREACHABLE();
      return string();
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, ReactionListType reaction_list_type) {
  switch (reaction_list_type) {
    case ReactionListType::Recent:
      return string_builder << "recent reactions";
    case ReactionListType::Top:
      return string_builder << "top reactions";
    case ReactionListType::DefaultTag:
      return string_builder << "default tag reactions";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
