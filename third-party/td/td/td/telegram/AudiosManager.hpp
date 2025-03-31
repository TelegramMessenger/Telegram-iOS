//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/AudiosManager.h"

#include "td/telegram/files/FileId.hpp"
#include "td/telegram/PhotoSize.hpp"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void AudiosManager::store_audio(FileId file_id, StorerT &storer) const {
  const Audio *audio = get_audio(file_id);
  CHECK(audio != nullptr);
  bool has_file_name = !audio->file_name.empty();
  bool has_mime_type = !audio->mime_type.empty();
  bool has_duration = audio->duration != 0;
  bool has_title = !audio->title.empty();
  bool has_performer = !audio->performer.empty();
  bool has_minithumbnail = !audio->minithumbnail.empty();
  bool has_thumbnail = audio->thumbnail.file_id.is_valid();
  bool has_date = audio->date != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_file_name);
  STORE_FLAG(has_mime_type);
  STORE_FLAG(has_duration);
  STORE_FLAG(has_title);
  STORE_FLAG(has_performer);
  STORE_FLAG(has_minithumbnail);
  STORE_FLAG(has_thumbnail);
  STORE_FLAG(has_date);
  END_STORE_FLAGS();
  if (has_file_name) {
    store(audio->file_name, storer);
  }
  if (has_mime_type) {
    store(audio->mime_type, storer);
  }
  if (has_duration) {
    store(audio->duration, storer);
  }
  if (has_title) {
    store(audio->title, storer);
  }
  if (has_performer) {
    store(audio->performer, storer);
  }
  if (has_minithumbnail) {
    store(audio->minithumbnail, storer);
  }
  if (has_thumbnail) {
    store(audio->thumbnail, storer);
  }
  if (has_date) {
    store(audio->date, storer);
  }
  store(file_id, storer);
}

template <class ParserT>
FileId AudiosManager::parse_audio(ParserT &parser) {
  auto audio = make_unique<Audio>();
  bool has_file_name;
  bool has_mime_type;
  bool has_duration;
  bool has_title;
  bool has_performer;
  bool has_minithumbnail;
  bool has_thumbnail;
  bool has_date;
  if (parser.version() >= static_cast<int32>(Version::AddAudioFlags)) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_file_name);
    PARSE_FLAG(has_mime_type);
    PARSE_FLAG(has_duration);
    PARSE_FLAG(has_title);
    PARSE_FLAG(has_performer);
    PARSE_FLAG(has_minithumbnail);
    PARSE_FLAG(has_thumbnail);
    PARSE_FLAG(has_date);
    END_PARSE_FLAGS();
  } else {
    has_file_name = true;
    has_mime_type = true;
    has_duration = true;
    has_title = true;
    has_performer = true;
    has_minithumbnail = parser.version() >= static_cast<int32>(Version::SupportMinithumbnails);
    has_thumbnail = true;
    has_date = false;
  }
  if (has_file_name) {
    parse(audio->file_name, parser);
  }
  if (has_mime_type) {
    parse(audio->mime_type, parser);
  }
  if (has_duration) {
    parse(audio->duration, parser);
  }
  if (has_title) {
    parse(audio->title, parser);
  }
  if (has_performer) {
    parse(audio->performer, parser);
  }
  if (has_minithumbnail) {
    parse(audio->minithumbnail, parser);
  }
  if (has_thumbnail) {
    parse(audio->thumbnail, parser);
  }
  if (has_date) {
    parse(audio->date, parser);
  }
  parse(audio->file_id, parser);
  if (parser.get_error() != nullptr || !audio->file_id.is_valid()) {
    return FileId();
  }
  return on_get_audio(std::move(audio), false);
}

}  // namespace td
