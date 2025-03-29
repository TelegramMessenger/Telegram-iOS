//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/VideoNotesManager.h"

#include "td/telegram/files/FileId.hpp"
#include "td/telegram/PhotoSize.hpp"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void VideoNotesManager::store_video_note(FileId file_id, StorerT &storer) const {
  const VideoNote *video_note = get_video_note(file_id);
  CHECK(video_note != nullptr);
  bool has_duration = video_note->duration != 0;
  bool has_minithumbnail = !video_note->minithumbnail.empty();
  bool has_thumbnail = video_note->thumbnail.file_id.is_valid();
  bool is_transcribed = video_note->transcription_info != nullptr && video_note->transcription_info->is_transcribed();
  bool has_waveform = !video_note->waveform.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_duration);
  STORE_FLAG(has_minithumbnail);
  STORE_FLAG(has_thumbnail);
  STORE_FLAG(is_transcribed);
  STORE_FLAG(has_waveform);
  END_STORE_FLAGS();
  if (has_duration) {
    store(video_note->duration, storer);
  }
  store(video_note->dimensions, storer);
  if (has_minithumbnail) {
    store(video_note->minithumbnail, storer);
  }
  if (has_thumbnail) {
    store(video_note->thumbnail, storer);
  }
  if (is_transcribed) {
    store(video_note->transcription_info, storer);
  }
  if (has_waveform) {
    store(video_note->waveform, storer);
  }
  store(file_id, storer);
}

template <class ParserT>
FileId VideoNotesManager::parse_video_note(ParserT &parser) {
  auto video_note = make_unique<VideoNote>();
  bool has_duration;
  bool has_minithumbnail;
  bool has_thumbnail;
  bool is_transcribed;
  bool has_waveform;
  if (parser.version() >= static_cast<int32>(Version::AddVideoNoteFlags)) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(has_duration);
    PARSE_FLAG(has_minithumbnail);
    PARSE_FLAG(has_thumbnail);
    PARSE_FLAG(is_transcribed);
    PARSE_FLAG(has_waveform);
    END_PARSE_FLAGS();
  } else {
    has_duration = true;
    has_minithumbnail = parser.version() >= static_cast<int32>(Version::SupportMinithumbnails);
    has_thumbnail = true;
    is_transcribed = false;
    has_waveform = false;
  }
  if (has_duration) {
    parse(video_note->duration, parser);
  }
  parse(video_note->dimensions, parser);
  if (has_minithumbnail) {
    parse(video_note->minithumbnail, parser);
  }
  if (has_thumbnail) {
    parse(video_note->thumbnail, parser);
  }
  if (is_transcribed) {
    parse(video_note->transcription_info, parser);
  }
  if (has_waveform) {
    parse(video_note->waveform, parser);
  }
  parse(video_note->file_id, parser);
  if (parser.get_error() != nullptr || !video_note->file_id.is_valid()) {
    return FileId();
  }
  return on_get_video_note(std::move(video_note), false);
}

}  // namespace td
