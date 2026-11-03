//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

enum class EmojiGroupType : int32 { Default, EmojiStatus, ProfilePhoto, RegularStickers };

static constexpr int32 MAX_EMOJI_GROUP_TYPE = 4;

EmojiGroupType get_emoji_group_type(const td_api::object_ptr<td_api::EmojiCategoryType> &type);

StringBuilder &operator<<(StringBuilder &string_builder, EmojiGroupType emoji_group_type);

}  // namespace td
