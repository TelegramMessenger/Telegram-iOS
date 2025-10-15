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

enum class StickerListType : int32 { DialogPhoto, UserProfilePhoto, Background, DisallowedChannelEmojiStatus };

static constexpr int32 MAX_STICKER_LIST_TYPE = 4;

string get_sticker_list_type_database_key(StickerListType sticker_list_type);

StringBuilder &operator<<(StringBuilder &string_builder, StickerListType sticker_list_type);

}  // namespace td
