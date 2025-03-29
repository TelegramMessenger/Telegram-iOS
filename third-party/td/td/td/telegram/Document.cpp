//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Document.h"

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AudiosManager.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/VideoNotesManager.h"
#include "td/telegram/VideosManager.h"

#include "td/utils/algorithm.h"

namespace td {

vector<FileId> Document::get_file_ids(const Td *td) const {
  vector<FileId> result;
  append_file_ids(td, result);
  return result;
}

void Document::append_file_ids(const Td *td, vector<FileId> &file_ids) const {
  if (!file_id.is_valid() || empty()) {
    return;
  }

  if (type == Type::Sticker) {
    append(file_ids, td->stickers_manager_->get_sticker_file_ids(file_id));
    return;
  }

  file_ids.push_back(file_id);

  FileId thumbnail_file_id = [&] {
    switch (type) {
      case Type::Animation:
        return td->animations_manager_->get_animation_thumbnail_file_id(file_id);
      case Type::Audio:
        return td->audios_manager_->get_audio_thumbnail_file_id(file_id);
      case Type::General:
        return td->documents_manager_->get_document_thumbnail_file_id(file_id);
      case Type::Video:
        return td->videos_manager_->get_video_thumbnail_file_id(file_id);
      case Type::VideoNote:
        return td->video_notes_manager_->get_video_note_thumbnail_file_id(file_id);
      default:
        return FileId();
    }
  }();
  if (thumbnail_file_id.is_valid()) {
    file_ids.push_back(thumbnail_file_id);
  }

  FileId animated_thumbnail_file_id = [&] {
    switch (type) {
      case Type::Animation:
        return td->animations_manager_->get_animation_animated_thumbnail_file_id(file_id);
      case Type::Video:
        return td->videos_manager_->get_video_animated_thumbnail_file_id(file_id);
      default:
        return FileId();
    }
  }();
  if (animated_thumbnail_file_id.is_valid()) {
    file_ids.push_back(animated_thumbnail_file_id);
  }

  if (type == Type::Audio) {
    td->audios_manager_->append_audio_album_cover_file_ids(file_id, file_ids);
  }
}

bool operator==(const Document &lhs, const Document &rhs) {
  return lhs.type == rhs.type && lhs.file_id == rhs.file_id;
}

bool operator!=(const Document &lhs, const Document &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const Document::Type &document_type) {
  switch (document_type) {
    case Document::Type::Unknown:
      return string_builder << "Unknown";
    case Document::Type::Animation:
      return string_builder << "Animation";
    case Document::Type::Audio:
      return string_builder << "Audio";
    case Document::Type::General:
      return string_builder << "Document";
    case Document::Type::Sticker:
      return string_builder << "Sticker";
    case Document::Type::Video:
      return string_builder << "Video";
    case Document::Type::VideoNote:
      return string_builder << "VideoNote";
    case Document::Type::VoiceNote:
      return string_builder << "VoiceNote";
    default:
      return string_builder << "Unreachable";
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, const Document &document) {
  return string_builder << '[' << document.type << ' ' << document.file_id << ']';
}

}  // namespace td
