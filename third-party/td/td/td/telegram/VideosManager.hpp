//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/VideosManager.h"

#include "td/telegram/files/FileId.hpp"
#include "td/telegram/Photo.hpp"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void VideosManager::store_video(FileId file_id, StorerT &storer) const {
  const Video *video = get_video(file_id);
  CHECK(video != nullptr);
  bool has_animated_thumbnail = video->animated_thumbnail.file_id.is_valid();
  bool has_preload_prefix_size = video->preload_prefix_size != 0;
  bool has_precise_duration = video->precise_duration != 0 && video->precise_duration != video->duration;
  bool has_start_ts = video->start_ts != 0.0;
  bool has_codec = !video->codec.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(video->has_stickers);
  STORE_FLAG(video->supports_streaming);
  STORE_FLAG(has_animated_thumbnail);
  STORE_FLAG(has_preload_prefix_size);
  STORE_FLAG(has_precise_duration);
  STORE_FLAG(video->is_animation);
  STORE_FLAG(has_start_ts);
  STORE_FLAG(has_codec);
  END_STORE_FLAGS();
  store(video->file_name, storer);
  store(video->mime_type, storer);
  store(video->duration, storer);
  store(video->dimensions, storer);
  store(video->minithumbnail, storer);
  store(video->thumbnail, storer);
  store(file_id, storer);
  if (video->has_stickers) {
    store(video->sticker_file_ids, storer);
  }
  if (has_animated_thumbnail) {
    store(video->animated_thumbnail, storer);
  }
  if (has_preload_prefix_size) {
    store(video->preload_prefix_size, storer);
  }
  if (has_precise_duration) {
    store(video->precise_duration, storer);
  }
  if (has_start_ts) {
    store(video->start_ts, storer);
  }
  if (has_codec) {
    store(video->codec, storer);
  }
}

template <class ParserT>
FileId VideosManager::parse_video(ParserT &parser) {
  auto video = make_unique<Video>();
  bool has_animated_thumbnail;
  bool has_preload_prefix_size;
  bool has_precise_duration;
  bool has_start_ts;
  bool has_codec;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(video->has_stickers);
  PARSE_FLAG(video->supports_streaming);
  PARSE_FLAG(has_animated_thumbnail);
  PARSE_FLAG(has_preload_prefix_size);
  PARSE_FLAG(has_precise_duration);
  PARSE_FLAG(video->is_animation);
  PARSE_FLAG(has_start_ts);
  PARSE_FLAG(has_codec);
  END_PARSE_FLAGS();
  parse(video->file_name, parser);
  parse(video->mime_type, parser);
  parse(video->duration, parser);
  parse(video->dimensions, parser);
  if (parser.version() >= static_cast<int32>(Version::SupportMinithumbnails)) {
    parse(video->minithumbnail, parser);
  }
  parse(video->thumbnail, parser);
  parse(video->file_id, parser);
  if (video->has_stickers) {
    parse(video->sticker_file_ids, parser);
  }
  if (has_animated_thumbnail) {
    parse(video->animated_thumbnail, parser);
  }
  if (has_preload_prefix_size) {
    parse(video->preload_prefix_size, parser);
  }
  if (has_precise_duration) {
    parse(video->precise_duration, parser);
  } else {
    video->precise_duration = video->duration;
  }
  if (has_start_ts) {
    parse(video->start_ts, parser);
  }
  if (has_codec) {
    parse(video->codec, parser);
  }
  if (parser.get_error() != nullptr || !video->file_id.is_valid()) {
    return FileId();
  }
  return on_get_video(std::move(video), false);
}

}  // namespace td
