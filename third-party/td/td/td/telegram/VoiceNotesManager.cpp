//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/VoiceNotesManager.h"

#include "td/telegram/Dimensions.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TranscriptionManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

namespace td {

VoiceNotesManager::VoiceNotesManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

VoiceNotesManager::~VoiceNotesManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), voice_notes_);
}

void VoiceNotesManager::tear_down() {
  parent_.reset();
}

int32 VoiceNotesManager::get_voice_note_duration(FileId file_id) const {
  auto voice_note = get_voice_note(file_id);
  if (voice_note == nullptr) {
    return 0;
  }
  return voice_note->duration;
}

TranscriptionInfo *VoiceNotesManager::get_voice_note_transcription_info(FileId file_id, bool allow_creation) {
  auto voice_note = get_voice_note(file_id);
  CHECK(voice_note != nullptr);
  if (voice_note->transcription_info == nullptr && allow_creation) {
    voice_note->transcription_info = make_unique<TranscriptionInfo>();
  }
  return voice_note->transcription_info.get();
}

tl_object_ptr<td_api::voiceNote> VoiceNotesManager::get_voice_note_object(FileId file_id) const {
  if (!file_id.is_valid()) {
    return nullptr;
  }

  auto voice_note = get_voice_note(file_id);
  CHECK(voice_note != nullptr);
  auto speech_recognition_result = voice_note->transcription_info == nullptr
                                       ? nullptr
                                       : voice_note->transcription_info->get_speech_recognition_result_object();
  return make_tl_object<td_api::voiceNote>(voice_note->duration, voice_note->waveform, voice_note->mime_type,
                                           std::move(speech_recognition_result),
                                           td_->file_manager_->get_file_object(file_id));
}

FileId VoiceNotesManager::on_get_voice_note(unique_ptr<VoiceNote> new_voice_note, bool replace) {
  auto file_id = new_voice_note->file_id;
  CHECK(file_id.is_valid());
  LOG(INFO) << "Receive voice note " << file_id;
  auto &v = voice_notes_[file_id];
  if (v == nullptr) {
    v = std::move(new_voice_note);
  } else if (replace) {
    CHECK(v->file_id == new_voice_note->file_id);
    if (v->mime_type != new_voice_note->mime_type || v->duration != new_voice_note->duration ||
        v->waveform != new_voice_note->waveform) {
      LOG(DEBUG) << "Voice note " << file_id << " info has changed";
      v->mime_type = std::move(new_voice_note->mime_type);
      v->duration = new_voice_note->duration;
      v->waveform = std::move(new_voice_note->waveform);
    }
    if (TranscriptionInfo::update_from(v->transcription_info, std::move(new_voice_note->transcription_info))) {
      td_->transcription_manager_->on_transcription_completed(file_id);
    }
  }

  return file_id;
}

VoiceNotesManager::VoiceNote *VoiceNotesManager::get_voice_note(FileId file_id) {
  return voice_notes_.get_pointer(file_id);
}

const VoiceNotesManager::VoiceNote *VoiceNotesManager::get_voice_note(FileId file_id) const {
  return voice_notes_.get_pointer(file_id);
}

FileId VoiceNotesManager::dup_voice_note(FileId new_id, FileId old_id) {
  const VoiceNote *old_voice_note = get_voice_note(old_id);
  CHECK(old_voice_note != nullptr);
  auto &new_voice_note = voice_notes_[new_id];
  if (new_voice_note != nullptr) {
    return new_id;
  }
  new_voice_note = make_unique<VoiceNote>();
  new_voice_note->file_id = new_id;
  new_voice_note->mime_type = old_voice_note->mime_type;
  new_voice_note->duration = old_voice_note->duration;
  new_voice_note->waveform = old_voice_note->waveform;
  new_voice_note->transcription_info = TranscriptionInfo::copy_if_transcribed(old_voice_note->transcription_info);
  return new_id;
}

void VoiceNotesManager::merge_voice_notes(FileId new_id, FileId old_id) {
  CHECK(old_id.is_valid() && new_id.is_valid());
  CHECK(new_id != old_id);

  LOG(INFO) << "Merge voice notes " << new_id << " and " << old_id;
  const VoiceNote *old_ = get_voice_note(old_id);
  CHECK(old_ != nullptr);

  const auto *new_ = get_voice_note(new_id);
  if (new_ == nullptr) {
    dup_voice_note(new_id, old_id);
  } else if (!old_->mime_type.empty() && old_->mime_type != new_->mime_type) {
    LOG(INFO) << "Voice note has changed: mime_type = (" << old_->mime_type << ", " << new_->mime_type << ")";
  }
  LOG_STATUS(td_->file_manager_->merge(new_id, old_id));
}

void VoiceNotesManager::create_voice_note(FileId file_id, string mime_type, int32 duration, string waveform,
                                          bool replace) {
  auto v = make_unique<VoiceNote>();
  v->file_id = file_id;
  v->mime_type = std::move(mime_type);
  v->duration = max(duration, 0);
  v->waveform = std::move(waveform);
  on_get_voice_note(std::move(v), replace);
}

SecretInputMedia VoiceNotesManager::get_secret_input_media(
    FileId voice_note_file_id, telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
    const string &caption, int32 layer) const {
  auto file_view = td_->file_manager_->get_file_view(voice_note_file_id);
  if (!file_view.is_encrypted_secret() || file_view.encryption_key().empty()) {
    return SecretInputMedia{};
  }
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location != nullptr) {
    input_file = main_remote_location->as_input_encrypted_file();
  }
  if (!input_file) {
    return SecretInputMedia{};
  }

  auto *voice_note = get_voice_note(voice_note_file_id);
  CHECK(voice_note != nullptr);
  vector<secret_api::object_ptr<secret_api::DocumentAttribute>> attributes;
  attributes.push_back(secret_api::make_object<secret_api::documentAttributeAudio>(
      secret_api::documentAttributeAudio::WAVEFORM_MASK, true, voice_note->duration, "", "",
      BufferSlice(voice_note->waveform)));

  return {std::move(input_file), BufferSlice(), Dimensions(), voice_note->mime_type, file_view,
          std::move(attributes), caption,       layer};
}

tl_object_ptr<telegram_api::InputMedia> VoiceNotesManager::get_input_media(
    FileId file_id, telegram_api::object_ptr<telegram_api::InputFile> input_file, int32 ttl) const {
  auto file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.is_encrypted()) {
    return nullptr;
  }
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location != nullptr && !main_remote_location->is_web() && input_file == nullptr) {
    int32 flags = 0;
    if (ttl != 0) {
      flags |= telegram_api::inputMediaDocument::TTL_SECONDS_MASK;
    }
    return telegram_api::make_object<telegram_api::inputMediaDocument>(
        flags, false, main_remote_location->as_input_document(), nullptr, 0, ttl, string());
  }
  const auto *url = file_view.get_url();
  if (url != nullptr) {
    int32 flags = 0;
    if (ttl != 0) {
      flags |= telegram_api::inputMediaDocumentExternal::TTL_SECONDS_MASK;
    }
    return telegram_api::make_object<telegram_api::inputMediaDocumentExternal>(flags, false, *url, ttl, nullptr, 0);
  }

  if (input_file != nullptr) {
    const VoiceNote *voice_note = get_voice_note(file_id);
    CHECK(voice_note != nullptr);

    vector<telegram_api::object_ptr<telegram_api::DocumentAttribute>> attributes;
    {
      int32 flags = 0;
      if (!voice_note->waveform.empty()) {
        flags |= telegram_api::documentAttributeAudio::WAVEFORM_MASK;
      }
      attributes.push_back(telegram_api::make_object<telegram_api::documentAttributeAudio>(
          flags, true, voice_note->duration, "", "", BufferSlice(voice_note->waveform)));
    }
    string mime_type = voice_note->mime_type;
    if (mime_type != "audio/ogg" && mime_type != "audio/mpeg" && mime_type != "audio/mp4") {
      mime_type = "audio/ogg";
    }
    int32 flags = 0;
    if (ttl != 0) {
      flags |= telegram_api::inputMediaUploadedDocument::TTL_SECONDS_MASK;
    }
    return telegram_api::make_object<telegram_api::inputMediaUploadedDocument>(
        flags, false, false, false, std::move(input_file), nullptr, mime_type, std::move(attributes),
        vector<telegram_api::object_ptr<telegram_api::InputDocument>>(), nullptr, 0, ttl);
  } else {
    CHECK(main_remote_location == nullptr);
  }

  return nullptr;
}

}  // namespace td
