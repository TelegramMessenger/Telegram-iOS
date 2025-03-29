//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Document.h"

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/AnimationsManager.hpp"
#include "td/telegram/AudiosManager.h"
#include "td/telegram/AudiosManager.hpp"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/DocumentsManager.hpp"
#include "td/telegram/files/FileId.hpp"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickersManager.hpp"
#include "td/telegram/Td.h"
#include "td/telegram/VideoNotesManager.h"
#include "td/telegram/VideoNotesManager.hpp"
#include "td/telegram/VideosManager.h"
#include "td/telegram/VideosManager.hpp"
#include "td/telegram/VoiceNotesManager.h"
#include "td/telegram/VoiceNotesManager.hpp"

#include "td/utils/logging.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void store(const Document &document, StorerT &storer) {
  Td *td = storer.context()->td().get_actor_unsafe();
  CHECK(td != nullptr);

  store(document.type, storer);
  switch (document.type) {
    case Document::Type::Animation:
      td->animations_manager_->store_animation(document.file_id, storer);
      break;
    case Document::Type::Audio:
      td->audios_manager_->store_audio(document.file_id, storer);
      break;
    case Document::Type::General:
      td->documents_manager_->store_document(document.file_id, storer);
      break;
    case Document::Type::Sticker:
      td->stickers_manager_->store_sticker(document.file_id, false, storer, "Document");
      break;
    case Document::Type::Video:
      td->videos_manager_->store_video(document.file_id, storer);
      break;
    case Document::Type::VideoNote:
      td->video_notes_manager_->store_video_note(document.file_id, storer);
      break;
    case Document::Type::VoiceNote:
      td->voice_notes_manager_->store_voice_note(document.file_id, storer);
      break;
    case Document::Type::Unknown:
    default:
      UNREACHABLE();
  }
}

template <class ParserT>
void parse(Document &document, ParserT &parser) {
  Td *td = parser.context()->td().get_actor_unsafe();
  CHECK(td != nullptr);

  parse(document.type, parser);
  switch (document.type) {
    case Document::Type::Animation:
      document.file_id = td->animations_manager_->parse_animation(parser);
      break;
    case Document::Type::Audio:
      document.file_id = td->audios_manager_->parse_audio(parser);
      break;
    case Document::Type::General:
      document.file_id = td->documents_manager_->parse_document(parser);
      break;
    case Document::Type::Sticker:
      document.file_id = td->stickers_manager_->parse_sticker(false, parser);
      break;
    case Document::Type::Video:
      document.file_id = td->videos_manager_->parse_video(parser);
      break;
    case Document::Type::VideoNote:
      document.file_id = td->video_notes_manager_->parse_video_note(parser);
      break;
    case Document::Type::VoiceNote:
      document.file_id = td->voice_notes_manager_->parse_voice_note(parser);
      break;
    case Document::Type::Unknown:
    default:
      LOG(ERROR) << "Have invalid Document type " << static_cast<int32>(document.type);
      document = Document();
      return;
  }
  if (!document.file_id.is_valid()) {
    LOG(ERROR) << "Parse invalid document.file_id";
    document = Document();
  }
}

}  // namespace td
