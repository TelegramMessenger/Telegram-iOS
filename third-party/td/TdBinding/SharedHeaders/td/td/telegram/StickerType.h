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

// update store_sticker/store_sticker_set when this type changes
enum class StickerType : int32 { Regular, Mask, CustomEmoji };

static constexpr int32 MAX_STICKER_TYPE = 3;

StickerType get_sticker_type(bool is_mask, bool is_custom_emoji);

StickerType get_sticker_type(const td_api::object_ptr<td_api::StickerType> &type);

td_api::object_ptr<td_api::StickerType> get_sticker_type_object(StickerType sticker_type);

StringBuilder &operator<<(StringBuilder &string_builder, StickerType sticker_type);

}  // namespace td
