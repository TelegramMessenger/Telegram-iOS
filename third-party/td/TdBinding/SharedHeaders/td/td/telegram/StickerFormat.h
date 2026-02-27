//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/PhotoFormat.h"
#include "td/telegram/StickerType.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"

namespace td {

// update store_sticker/store_sticker_set when this type changes
enum class StickerFormat : int32 { Unknown, Webp, Tgs, Webm };

StickerFormat get_sticker_format(const td_api::object_ptr<td_api::StickerFormat> &format);

StickerFormat get_sticker_format_by_mime_type(Slice mime_type);

StickerFormat get_sticker_format_by_extension(Slice extension);

td_api::object_ptr<td_api::StickerFormat> get_sticker_format_object(StickerFormat sticker_format);

string get_sticker_format_mime_type(StickerFormat sticker_format);

Slice get_sticker_format_extension(StickerFormat sticker_format);

PhotoFormat get_sticker_format_photo_format(StickerFormat sticker_format);

bool is_sticker_format_animated(StickerFormat sticker_format);

bool is_sticker_format_vector(StickerFormat sticker_format);

int64 get_max_sticker_file_size(StickerFormat sticker_format, StickerType sticker_type, bool for_thumbnail);

StringBuilder &operator<<(StringBuilder &string_builder, StickerFormat sticker_format);

}  // namespace td
