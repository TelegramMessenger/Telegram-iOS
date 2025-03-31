//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AnimationsManager.h"

#include "td/telegram/files/FileId.hpp"
#include "td/telegram/PhotoSize.hpp"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void AnimationsManager::store_animation(FileId file_id, StorerT &storer) const {
  const Animation *animation = get_animation(file_id);
  CHECK(animation != nullptr);
  bool has_animated_thumbnail = animation->animated_thumbnail.file_id.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(animation->has_stickers);
  STORE_FLAG(has_animated_thumbnail);
  END_STORE_FLAGS();
  store(animation->duration, storer);
  store(animation->dimensions, storer);
  store(animation->file_name, storer);
  store(animation->mime_type, storer);
  store(animation->minithumbnail, storer);
  store(animation->thumbnail, storer);
  store(file_id, storer);
  if (animation->has_stickers) {
    store(animation->sticker_file_ids, storer);
  }
  if (has_animated_thumbnail) {
    store(animation->animated_thumbnail, storer);
  }
}

template <class ParserT>
FileId AnimationsManager::parse_animation(ParserT &parser) {
  auto animation = make_unique<Animation>();
  bool has_animated_thumbnail = false;
  if (parser.version() >= static_cast<int32>(Version::AddAnimationStickers)) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(animation->has_stickers);
    PARSE_FLAG(has_animated_thumbnail);
    END_PARSE_FLAGS();
  }
  if (parser.version() >= static_cast<int32>(Version::AddDurationToAnimation)) {
    parse(animation->duration, parser);
  }
  parse(animation->dimensions, parser);
  parse(animation->file_name, parser);
  parse(animation->mime_type, parser);
  if (parser.version() >= static_cast<int32>(Version::SupportMinithumbnails)) {
    parse(animation->minithumbnail, parser);
  }
  parse(animation->thumbnail, parser);
  parse(animation->file_id, parser);
  if (animation->has_stickers) {
    parse(animation->sticker_file_ids, parser);
  }
  if (has_animated_thumbnail) {
    parse(animation->animated_thumbnail, parser);
  }
  if (parser.get_error() != nullptr || !animation->file_id.is_valid()) {
    return FileId();
  }
  return on_get_animation(std::move(animation), false);
}

}  // namespace td
