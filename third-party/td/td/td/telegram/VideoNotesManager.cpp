//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/VideoNotesManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/PhotoFormat.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/TranscriptionManager.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Status.h"

namespace td {

VideoNotesManager::VideoNotesManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

VideoNotesManager::~VideoNotesManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), video_notes_);
}

void VideoNotesManager::tear_down() {
  parent_.reset();
}

int32 VideoNotesManager::get_video_note_duration(FileId file_id) const {
  auto video_note = get_video_note(file_id);
  CHECK(video_note != nullptr);
  return video_note->duration;
}

TranscriptionInfo *VideoNotesManager::get_video_note_transcription_info(FileId file_id, bool allow_creation) {
  auto video_note = get_video_note(file_id);
  CHECK(video_note != nullptr);
  if (video_note->transcription_info == nullptr && allow_creation) {
    video_note->transcription_info = make_unique<TranscriptionInfo>();
  }
  return video_note->transcription_info.get();
}

tl_object_ptr<td_api::videoNote> VideoNotesManager::get_video_note_object(FileId file_id) const {
  if (!file_id.is_valid()) {
    return nullptr;
  }

  auto video_note = get_video_note(file_id);
  auto speech_recognition_result = video_note->transcription_info == nullptr
                                       ? nullptr
                                       : video_note->transcription_info->get_speech_recognition_result_object();
  return make_tl_object<td_api::videoNote>(
      video_note->duration, video_note->waveform, video_note->dimensions.width,
      get_minithumbnail_object(video_note->minithumbnail),
      get_thumbnail_object(td_->file_manager_.get(), video_note->thumbnail, PhotoFormat::Jpeg),
      std::move(speech_recognition_result), td_->file_manager_->get_file_object(file_id));
}

FileId VideoNotesManager::on_get_video_note(unique_ptr<VideoNote> new_video_note, bool replace) {
  auto file_id = new_video_note->file_id;
  CHECK(file_id.is_valid());
  LOG(INFO) << "Receive video note " << file_id;
  auto &v = video_notes_[file_id];
  if (v == nullptr) {
    v = std::move(new_video_note);
  } else if (replace) {
    CHECK(v->file_id == new_video_note->file_id);
    if (v->duration != new_video_note->duration || v->dimensions != new_video_note->dimensions ||
        v->waveform != new_video_note->waveform || v->minithumbnail != new_video_note->minithumbnail ||
        v->thumbnail != new_video_note->thumbnail) {
      LOG(DEBUG) << "Video note " << file_id << " info has changed";
      v->duration = new_video_note->duration;
      v->dimensions = new_video_note->dimensions;
      v->waveform = std::move(new_video_note->waveform);
      v->minithumbnail = std::move(new_video_note->minithumbnail);
      v->thumbnail = std::move(new_video_note->thumbnail);
    }
    if (TranscriptionInfo::update_from(v->transcription_info, std::move(new_video_note->transcription_info))) {
      td_->transcription_manager_->on_transcription_completed(file_id);
    }
  }
  return file_id;
}

VideoNotesManager::VideoNote *VideoNotesManager::get_video_note(FileId file_id) {
  return video_notes_.get_pointer(file_id);
}

const VideoNotesManager::VideoNote *VideoNotesManager::get_video_note(FileId file_id) const {
  return video_notes_.get_pointer(file_id);
}

FileId VideoNotesManager::get_video_note_thumbnail_file_id(FileId file_id) const {
  auto video_note = get_video_note(file_id);
  CHECK(video_note != nullptr);
  return video_note->thumbnail.file_id;
}

void VideoNotesManager::delete_video_note_thumbnail(FileId file_id) {
  auto &video_note = video_notes_[file_id];
  CHECK(video_note != nullptr);
  video_note->thumbnail = PhotoSize();
}

FileId VideoNotesManager::dup_video_note(FileId new_id, FileId old_id) {
  const VideoNote *old_video_note = get_video_note(old_id);
  CHECK(old_video_note != nullptr);
  auto &new_video_note = video_notes_[new_id];
  if (new_video_note != nullptr) {
    return new_id;
  }
  new_video_note = make_unique<VideoNote>();
  new_video_note->file_id = new_id;
  new_video_note->duration = old_video_note->duration;
  new_video_note->dimensions = old_video_note->dimensions;
  new_video_note->waveform = old_video_note->waveform;
  new_video_note->minithumbnail = old_video_note->minithumbnail;
  new_video_note->thumbnail = old_video_note->thumbnail;
  new_video_note->transcription_info = TranscriptionInfo::copy_if_transcribed(old_video_note->transcription_info);
  return new_id;
}

void VideoNotesManager::merge_video_notes(FileId new_id, FileId old_id) {
  CHECK(old_id.is_valid() && new_id.is_valid());
  CHECK(new_id != old_id);

  LOG(INFO) << "Merge video notes " << new_id << " and " << old_id;
  const VideoNote *old_ = get_video_note(old_id);
  CHECK(old_ != nullptr);

  const auto *new_ = get_video_note(new_id);
  if (new_ == nullptr) {
    dup_video_note(new_id, old_id);
  }
  LOG_STATUS(td_->file_manager_->merge(new_id, old_id));
}

void VideoNotesManager::create_video_note(FileId file_id, string minithumbnail, PhotoSize thumbnail, int32 duration,
                                          Dimensions dimensions, string waveform, bool replace) {
  auto v = make_unique<VideoNote>();
  v->file_id = file_id;
  v->duration = max(duration, 0);
  if (dimensions.width == dimensions.height && dimensions.width <= 640) {
    v->dimensions = dimensions;
  } else {
    LOG(INFO) << "Receive wrong video note dimensions " << dimensions;
  }
  v->waveform = std::move(waveform);
  if (!td_->auth_manager_->is_bot()) {
    v->minithumbnail = std::move(minithumbnail);
  }
  v->thumbnail = std::move(thumbnail);
  on_get_video_note(std::move(v), replace);
}

SecretInputMedia VideoNotesManager::get_secret_input_media(
    FileId video_note_file_id, telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
    BufferSlice thumbnail, int32 layer) const {
  const VideoNote *video_note = get_video_note(video_note_file_id);
  CHECK(video_note != nullptr);
  auto file_view = td_->file_manager_->get_file_view(video_note_file_id);
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
  if (video_note->thumbnail.file_id.is_valid() && thumbnail.empty()) {
    return SecretInputMedia{};
  }
  vector<secret_api::object_ptr<secret_api::DocumentAttribute>> attributes;
  attributes.push_back(secret_api::make_object<secret_api::documentAttributeVideo>(
      0, true, video_note->duration, video_note->dimensions.width, video_note->dimensions.height));

  return {std::move(input_file),
          std::move(thumbnail),
          video_note->thumbnail.dimensions,
          "video/mp4",
          file_view,
          std::move(attributes),
          string(),
          layer};
}

tl_object_ptr<telegram_api::InputMedia> VideoNotesManager::get_input_media(
    FileId file_id, telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail, int32 ttl) const {
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
    const VideoNote *video_note = get_video_note(file_id);
    CHECK(video_note != nullptr);

    vector<telegram_api::object_ptr<telegram_api::DocumentAttribute>> attributes;
    auto suggested_video_note_length =
        narrow_cast<int32>(td_->option_manager_->get_option_integer("suggested_video_note_length", 384));
    attributes.push_back(telegram_api::make_object<telegram_api::documentAttributeVideo>(
        0, true, false, false, video_note->duration,
        video_note->dimensions.width ? video_note->dimensions.width : suggested_video_note_length,
        video_note->dimensions.height ? video_note->dimensions.height : suggested_video_note_length, 0, 0.0, string()));
    int32 flags = 0;
    if (ttl != 0) {
      flags |= telegram_api::inputMediaUploadedDocument::TTL_SECONDS_MASK;
    }
    if (input_thumbnail != nullptr) {
      flags |= telegram_api::inputMediaUploadedDocument::THUMB_MASK;
    }
    return telegram_api::make_object<telegram_api::inputMediaUploadedDocument>(
        flags, true, false, false, std::move(input_file), std::move(input_thumbnail), "video/mp4",
        std::move(attributes), vector<telegram_api::object_ptr<telegram_api::InputDocument>>(), nullptr, 0, ttl);
  } else {
    CHECK(main_remote_location == nullptr);
  }

  return nullptr;
}

}  // namespace td
