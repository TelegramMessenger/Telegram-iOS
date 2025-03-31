//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageExtendedMedia.h"
#include "td/telegram/Photo.hpp"
#include "td/telegram/Td.h"
#include "td/telegram/VideosManager.h"

#include "td/utils/logging.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MessageExtendedMedia::store(StorerT &storer) const {
  bool has_unsupported_version = unsupported_version_ != 0;
  bool has_duration = duration_ != 0;
  bool has_dimensions = dimensions_.width != 0 || dimensions_.height != 0;
  bool has_minithumbnail = !minithumbnail_.empty();
  bool has_photo = !photo_.is_empty();
  bool has_video = video_file_id_.is_valid();
  bool has_start_timestamp = start_timestamp_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(false);  // has_caption
  STORE_FLAG(has_unsupported_version);
  STORE_FLAG(has_duration);
  STORE_FLAG(has_dimensions);
  STORE_FLAG(has_minithumbnail);
  STORE_FLAG(has_photo);
  STORE_FLAG(has_video);
  STORE_FLAG(has_start_timestamp);
  END_STORE_FLAGS();
  td::store(type_, storer);
  if (has_unsupported_version) {
    td::store(unsupported_version_, storer);
  }
  if (has_duration) {
    td::store(duration_, storer);
  }
  if (has_dimensions) {
    td::store(dimensions_, storer);
  }
  if (has_minithumbnail) {
    td::store(minithumbnail_, storer);
  }
  if (has_photo) {
    td::store(photo_, storer);
  }
  if (has_video) {
    Td *td = storer.context()->td().get_actor_unsafe();
    td->videos_manager_->store_video(video_file_id_, storer);
  }
  if (has_start_timestamp) {
    td::store(start_timestamp_, storer);
  }
}

template <class ParserT>
void MessageExtendedMedia::parse(ParserT &parser) {
  bool has_caption;
  bool has_unsupported_version;
  bool has_duration;
  bool has_dimensions;
  bool has_minithumbnail;
  bool has_photo;
  bool has_video;
  bool has_start_timestamp;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_caption);
  PARSE_FLAG(has_unsupported_version);
  PARSE_FLAG(has_duration);
  PARSE_FLAG(has_dimensions);
  PARSE_FLAG(has_minithumbnail);
  PARSE_FLAG(has_photo);
  PARSE_FLAG(has_video);
  PARSE_FLAG(has_start_timestamp);
  END_PARSE_FLAGS();
  td::parse(type_, parser);
  if (has_caption) {
    FormattedText caption;
    td::parse(caption, parser);
  }
  if (has_unsupported_version) {
    td::parse(unsupported_version_, parser);
  }
  if (has_duration) {
    td::parse(duration_, parser);
  }
  if (has_dimensions) {
    td::parse(dimensions_, parser);
  }
  if (has_minithumbnail) {
    td::parse(minithumbnail_, parser);
  }
  bool is_bad = false;
  if (has_photo) {
    td::parse(photo_, parser);
    is_bad = photo_.is_bad();
  } else if (type_ == Type::Photo) {
    is_bad = true;
  }
  if (has_video) {
    Td *td = parser.context()->td().get_actor_unsafe();
    video_file_id_ = td->videos_manager_->parse_video(parser);
    is_bad = !video_file_id_.is_valid();
    if (type_ != Type::Video) {
      is_bad = true;
    }
  } else if (type_ == Type::Video) {
    is_bad = true;
  }
  if (has_start_timestamp) {
    td::parse(start_timestamp_, parser);
  }

  if (is_bad || has_caption) {
    if (is_bad) {
      LOG(ERROR) << "Failed to parse MessageExtendedMedia";
    }
    photo_ = Photo();
    video_file_id_ = FileId();
    type_ = Type::Unsupported;
    unsupported_version_ = 0;
  }
}

}  // namespace td
