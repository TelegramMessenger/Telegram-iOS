//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"
#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TranscriptionInfo.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/WaitFreeHashMap.h"

namespace td {

class Td;

class VoiceNotesManager final : public Actor {
 public:
  VoiceNotesManager(Td *td, ActorShared<> parent);
  VoiceNotesManager(const VoiceNotesManager &) = delete;
  VoiceNotesManager &operator=(const VoiceNotesManager &) = delete;
  VoiceNotesManager(VoiceNotesManager &&) = delete;
  VoiceNotesManager &operator=(VoiceNotesManager &&) = delete;
  ~VoiceNotesManager() final;

  int32 get_voice_note_duration(FileId file_id) const;

  TranscriptionInfo *get_voice_note_transcription_info(FileId file_id, bool allow_creation);

  tl_object_ptr<td_api::voiceNote> get_voice_note_object(FileId file_id) const;

  void create_voice_note(FileId file_id, string mime_type, int32 duration, string waveform, bool replace);

  tl_object_ptr<telegram_api::InputMedia> get_input_media(FileId file_id,
                                                          telegram_api::object_ptr<telegram_api::InputFile> input_file,
                                                          int32 ttl) const;

  SecretInputMedia get_secret_input_media(FileId voice_note_file_id,
                                          telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
                                          const string &caption, int32 layer) const;

  FileId dup_voice_note(FileId new_id, FileId old_id);

  void merge_voice_notes(FileId new_id, FileId old_id);

  template <class StorerT>
  void store_voice_note(FileId file_id, StorerT &storer) const;

  template <class ParserT>
  FileId parse_voice_note(ParserT &parser);

 private:
  class VoiceNote {
   public:
    string mime_type;
    int32 duration = 0;
    string waveform;
    unique_ptr<TranscriptionInfo> transcription_info;

    FileId file_id;
  };

  VoiceNote *get_voice_note(FileId file_id);

  const VoiceNote *get_voice_note(FileId file_id) const;

  FileId on_get_voice_note(unique_ptr<VoiceNote> new_voice_note, bool replace);

  void tear_down() final;

  Td *td_;
  ActorShared<> parent_;

  WaitFreeHashMap<FileId, unique_ptr<VoiceNote>, FileIdHash> voice_notes_;
};

}  // namespace td
