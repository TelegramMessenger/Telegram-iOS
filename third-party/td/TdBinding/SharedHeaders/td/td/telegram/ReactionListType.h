//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

enum class ReactionListType : int32 { Recent, Top, DefaultTag };

static constexpr int32 MAX_REACTION_LIST_TYPE = 3;

string get_reaction_list_type_database_key(ReactionListType reaction_list_type);

StringBuilder &operator<<(StringBuilder &string_builder, ReactionListType reaction_list_type);

}  // namespace td
