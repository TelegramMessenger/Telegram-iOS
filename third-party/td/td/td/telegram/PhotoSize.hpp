//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Dimensions.hpp"
#include "td/telegram/files/FileId.hpp"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/PhotoSizeType.hpp"
#include "td/telegram/Version.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void store(const PhotoSize &photo_size, StorerT &storer) {
  store(photo_size.type, storer);
  store(photo_size.dimensions, storer);
  store(photo_size.size, storer);
  store(photo_size.file_id, storer);
  store(photo_size.progressive_sizes, storer);
}

template <class ParserT>
void parse(PhotoSize &photo_size, ParserT &parser) {
  parse(photo_size.type, parser);
  parse(photo_size.dimensions, parser);
  parse(photo_size.size, parser);
  parse(photo_size.file_id, parser);
  if (parser.version() >= static_cast<int32>(Version::AddPhotoProgressiveSizes)) {
    parse(photo_size.progressive_sizes, parser);
  } else {
    photo_size.progressive_sizes.clear();
  }
}

template <class StorerT>
void store(const AnimationSize &animation_size, StorerT &storer) {
  store(static_cast<const PhotoSize &>(animation_size), storer);
  store(animation_size.main_frame_timestamp, storer);
}

template <class ParserT>
void parse(AnimationSize &animation_size, ParserT &parser) {
  parse(static_cast<PhotoSize &>(animation_size), parser);
  if (parser.version() >= static_cast<int32>(Version::AddDialogPhotoHasAnimation)) {
    parse(animation_size.main_frame_timestamp, parser);
  } else {
    animation_size.main_frame_timestamp = 0;
  }
}

}  // namespace td
