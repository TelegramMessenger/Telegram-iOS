//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AudiosManager.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/PhotoFormat.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

namespace td {

AudiosManager::AudiosManager(Td *td) : td_(td) {
}

AudiosManager::~AudiosManager() {
  Scheduler::instance()->destroy_on_scheduler(G()->get_gc_scheduler_id(), audios_);
}

int32 AudiosManager::get_audio_duration(FileId file_id) const {
  const auto *audio = get_audio(file_id);
  if (audio == nullptr) {
    return 0;
  }
  return audio->duration;
}

tl_object_ptr<td_api::audio> AudiosManager::get_audio_object(FileId file_id) const {
  if (!file_id.is_valid()) {
    return nullptr;
  }

  auto audio = get_audio(file_id);
  CHECK(audio != nullptr);

  vector<td_api::object_ptr<td_api::thumbnail>> album_covers;
  if (!td_->auth_manager_->is_bot()) {
    auto add_album_cover = [&](bool is_small, int32 width, int32 height) {
      auto r_file_id =
          td_->file_manager_->get_audio_thumbnail_file_id(audio->title, audio->performer, is_small, DialogId());
      if (r_file_id.is_ok()) {
        album_covers.emplace_back(
            td_api::make_object<td_api::thumbnail>(td_api::make_object<td_api::thumbnailFormatJpeg>(), width, height,
                                                   td_->file_manager_->get_file_object(r_file_id.move_as_ok())));
      }
    };

    add_album_cover(true, 100, 100);
    add_album_cover(false, 600, 600);
  }
  return make_tl_object<td_api::audio>(
      audio->duration, audio->title, audio->performer, audio->file_name, audio->mime_type,
      get_minithumbnail_object(audio->minithumbnail),
      get_thumbnail_object(td_->file_manager_.get(), audio->thumbnail, PhotoFormat::Jpeg), std::move(album_covers),
      td_->file_manager_->get_file_object(file_id));
}

td_api::object_ptr<td_api::notificationSound> AudiosManager::get_notification_sound_object(FileId file_id) const {
  if (!file_id.is_valid()) {
    return nullptr;
  }

  auto audio = get_audio(file_id);
  CHECK(audio != nullptr);
  auto file_view = td_->file_manager_->get_file_view(file_id);
  CHECK(!file_view.empty());
  CHECK(file_view.get_type() == FileType::Ringtone);
  auto full_remote_location = file_view.get_full_remote_location();
  CHECK(full_remote_location != nullptr);
  auto document_id = full_remote_location->get_id();
  auto title = audio->title;
  if (title.empty() && !audio->file_name.empty()) {
    title = PathView(audio->file_name).file_name_without_extension().str();
  }
  return td_api::make_object<td_api::notificationSound>(document_id, audio->duration, audio->date, title,
                                                        audio->performer, td_->file_manager_->get_file_object(file_id));
}

FileId AudiosManager::on_get_audio(unique_ptr<Audio> new_audio, bool replace) {
  auto file_id = new_audio->file_id;
  CHECK(file_id.is_valid());
  LOG(INFO) << "Receive audio " << file_id;
  auto &a = audios_[file_id];
  if (a == nullptr) {
    a = std::move(new_audio);
  } else if (replace) {
    CHECK(a->file_id == new_audio->file_id);
    if (a->mime_type != new_audio->mime_type || a->duration != new_audio->duration || a->title != new_audio->title ||
        a->performer != new_audio->performer || a->file_name != new_audio->file_name || a->date != new_audio->date ||
        a->minithumbnail != new_audio->minithumbnail || a->thumbnail != new_audio->thumbnail) {
      LOG(DEBUG) << "Audio " << file_id << " info has changed";
      a->mime_type = std::move(new_audio->mime_type);
      a->duration = new_audio->duration;
      a->title = std::move(new_audio->title);
      a->performer = std::move(new_audio->performer);
      a->file_name = std::move(new_audio->file_name);
      a->date = new_audio->date;
      a->minithumbnail = std::move(new_audio->minithumbnail);
      a->thumbnail = std::move(new_audio->thumbnail);
    }
  }

  return file_id;
}

const AudiosManager::Audio *AudiosManager::get_audio(FileId file_id) const {
  return audios_.get_pointer(file_id);
}

FileId AudiosManager::dup_audio(FileId new_id, FileId old_id) {
  const Audio *old_audio = get_audio(old_id);
  CHECK(old_audio != nullptr);
  auto &new_audio = audios_[new_id];
  if (new_audio != nullptr) {
    return new_id;
  }
  new_audio = make_unique<Audio>(*old_audio);
  new_audio->file_id = new_id;
  return new_id;
}

void AudiosManager::merge_audios(FileId new_id, FileId old_id) {
  CHECK(old_id.is_valid() && new_id.is_valid());
  CHECK(new_id != old_id);

  LOG(INFO) << "Merge audios " << new_id << " and " << old_id;
  const Audio *old_ = get_audio(old_id);
  CHECK(old_ != nullptr);

  const auto *new_ = get_audio(new_id);
  if (new_ == nullptr) {
    dup_audio(new_id, old_id);
  } else {
    if (!old_->mime_type.empty() && old_->mime_type != new_->mime_type) {
      LOG(INFO) << "Audio has changed: mime_type = (" << old_->mime_type << ", " << new_->mime_type << ")";
    }
  }
  LOG_STATUS(td_->file_manager_->merge(new_id, old_id));
}

string AudiosManager::get_audio_search_text(FileId file_id) const {
  auto audio = get_audio(file_id);
  CHECK(audio != nullptr);
  return PSTRING() << audio->file_name << " " << audio->title << " " << audio->performer;
}

FileId AudiosManager::get_audio_thumbnail_file_id(FileId file_id) const {
  auto audio = get_audio(file_id);
  CHECK(audio != nullptr);
  return audio->thumbnail.file_id;
}

void AudiosManager::append_audio_album_cover_file_ids(FileId file_id, vector<FileId> &file_ids) const {
  if (td_->auth_manager_->is_bot()) {
    return;
  }
  auto audio = get_audio(file_id);
  CHECK(audio != nullptr);

  auto append_album_cover = [&](bool is_small) {
    auto r_file_id =
        td_->file_manager_->get_audio_thumbnail_file_id(audio->title, audio->performer, is_small, DialogId());
    if (r_file_id.is_ok()) {
      file_ids.push_back(r_file_id.ok());
    }
  };

  append_album_cover(true);
  append_album_cover(false);
}

void AudiosManager::delete_audio_thumbnail(FileId file_id) {
  auto &audio = audios_[file_id];
  CHECK(audio != nullptr);
  audio->thumbnail = PhotoSize();
}

void AudiosManager::create_audio(FileId file_id, string minithumbnail, PhotoSize thumbnail, string file_name,
                                 string mime_type, int32 duration, string title, string performer, int32 date,
                                 bool replace) {
  auto a = make_unique<Audio>();
  a->file_id = file_id;
  a->file_name = std::move(file_name);
  a->mime_type = std::move(mime_type);
  a->duration = max(duration, 0);
  a->title = std::move(title);
  a->performer = std::move(performer);
  a->date = date;
  if (!td_->auth_manager_->is_bot()) {
    a->minithumbnail = std::move(minithumbnail);
  }
  a->thumbnail = std::move(thumbnail);
  on_get_audio(std::move(a), replace);
}

SecretInputMedia AudiosManager::get_secret_input_media(
    FileId audio_file_id, telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file, const string &caption,
    BufferSlice thumbnail, int32 layer) const {
  auto *audio = get_audio(audio_file_id);
  CHECK(audio != nullptr);
  auto file_view = td_->file_manager_->get_file_view(audio_file_id);
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
  if (audio->thumbnail.file_id.is_valid() && thumbnail.empty()) {
    return SecretInputMedia{};
  }
  vector<secret_api::object_ptr<secret_api::DocumentAttribute>> attributes;
  if (!audio->file_name.empty()) {
    attributes.push_back(secret_api::make_object<secret_api::documentAttributeFilename>(audio->file_name));
  }
  attributes.push_back(secret_api::make_object<secret_api::documentAttributeAudio>(
      secret_api::documentAttributeAudio::TITLE_MASK | secret_api::documentAttributeAudio::PERFORMER_MASK, false,
      audio->duration, audio->title, audio->performer, BufferSlice()));

  return {std::move(input_file),
          std::move(thumbnail),
          audio->thumbnail.dimensions,
          audio->mime_type,
          file_view,
          std::move(attributes),
          caption,
          layer};
}

tl_object_ptr<telegram_api::InputMedia> AudiosManager::get_input_media(
    FileId file_id, telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail) const {
  auto file_view = td_->file_manager_->get_file_view(file_id);
  if (file_view.is_encrypted()) {
    return nullptr;
  }
  const auto *main_remote_location = file_view.get_main_remote_location();
  if (main_remote_location != nullptr && !main_remote_location->is_web() && input_file == nullptr) {
    return telegram_api::make_object<telegram_api::inputMediaDocument>(
        0, false, main_remote_location->as_input_document(), nullptr, 0, 0, string());
  }
  const auto *url = file_view.get_url();
  if (url != nullptr) {
    return telegram_api::make_object<telegram_api::inputMediaDocumentExternal>(0, false, *url, 0, nullptr, 0);
  }

  if (input_file != nullptr) {
    const Audio *audio = get_audio(file_id);
    CHECK(audio != nullptr);

    vector<telegram_api::object_ptr<telegram_api::DocumentAttribute>> attributes;
    attributes.push_back(telegram_api::make_object<telegram_api::documentAttributeAudio>(
        telegram_api::documentAttributeAudio::TITLE_MASK | telegram_api::documentAttributeAudio::PERFORMER_MASK, false,
        audio->duration, audio->title, audio->performer, BufferSlice()));
    if (!audio->file_name.empty()) {
      attributes.push_back(telegram_api::make_object<telegram_api::documentAttributeFilename>(audio->file_name));
    }
    string mime_type = audio->mime_type;
    if (!begins_with(mime_type, "audio/")) {
      mime_type = "audio/mpeg";
    }
    int32 flags = 0;
    if (input_thumbnail != nullptr) {
      flags |= telegram_api::inputMediaUploadedDocument::THUMB_MASK;
    }
    return telegram_api::make_object<telegram_api::inputMediaUploadedDocument>(
        flags, false, false, false, std::move(input_file), std::move(input_thumbnail), mime_type, std::move(attributes),
        vector<telegram_api::object_ptr<telegram_api::InputDocument>>(), nullptr, 0, 0);
  } else {
    CHECK(main_remote_location == nullptr);
  }

  return nullptr;
}

}  // namespace td
