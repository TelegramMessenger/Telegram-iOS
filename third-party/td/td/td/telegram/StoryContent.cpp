//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StoryContent.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/Dimensions.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Photo.h"
#include "td/telegram/Photo.hpp"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/VideosManager.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/tl_helpers.h"

#include <cmath>

namespace td {

class StoryContentPhoto final : public StoryContent {
 public:
  Photo photo_;

  StoryContentPhoto() = default;
  explicit StoryContentPhoto(Photo &&photo) : photo_(std::move(photo)) {
  }

  StoryContentType get_type() const final {
    return StoryContentType::Photo;
  }
};

class StoryContentVideo final : public StoryContent {
 public:
  FileId file_id_;
  FileId alt_file_id_;

  StoryContentVideo() = default;
  StoryContentVideo(FileId file_id, FileId alt_file_id) : file_id_(file_id), alt_file_id_(alt_file_id) {
  }

  StoryContentType get_type() const final {
    return StoryContentType::Video;
  }
};

class StoryContentUnsupported final : public StoryContent {
 public:
  static constexpr int32 CURRENT_VERSION = 1;
  int32 version_ = CURRENT_VERSION;

  StoryContentUnsupported() = default;
  explicit StoryContentUnsupported(int32 version) : version_(version) {
  }

  StoryContentType get_type() const final {
    return StoryContentType::Unsupported;
  }
};

template <class StorerT>
static void store(const StoryContent *content, StorerT &storer) {
  CHECK(content != nullptr);

  Td *td = storer.context()->td().get_actor_unsafe();
  CHECK(td != nullptr);

  auto content_type = content->get_type();
  store(content_type, storer);

  switch (content_type) {
    case StoryContentType::Photo: {
      const auto *story_content = static_cast<const StoryContentPhoto *>(content);
      BEGIN_STORE_FLAGS();
      END_STORE_FLAGS();
      store(story_content->photo_, storer);
      break;
    }
    case StoryContentType::Video: {
      const auto *story_content = static_cast<const StoryContentVideo *>(content);
      bool has_alt_file_id = story_content->alt_file_id_.is_valid();
      BEGIN_STORE_FLAGS();
      STORE_FLAG(has_alt_file_id);
      END_STORE_FLAGS();
      td->videos_manager_->store_video(story_content->file_id_, storer);
      if (has_alt_file_id) {
        td->videos_manager_->store_video(story_content->alt_file_id_, storer);
      }
      break;
    }
    case StoryContentType::Unsupported: {
      const auto *story_content = static_cast<const StoryContentUnsupported *>(content);
      store(story_content->version_, storer);
      break;
    }
    default:
      UNREACHABLE();
  }
}

template <class ParserT>
static void parse(unique_ptr<StoryContent> &content, ParserT &parser) {
  Td *td = parser.context()->td().get_actor_unsafe();
  CHECK(td != nullptr);

  StoryContentType content_type;
  parse(content_type, parser);

  bool is_bad = false;
  switch (content_type) {
    case StoryContentType::Photo: {
      auto story_content = make_unique<StoryContentPhoto>();
      BEGIN_PARSE_FLAGS();
      END_PARSE_FLAGS();
      parse(story_content->photo_, parser);
      is_bad |= story_content->photo_.is_bad();
      content = std::move(story_content);
      break;
    }
    case StoryContentType::Video: {
      auto story_content = make_unique<StoryContentVideo>();
      bool has_alt_file_id;
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_alt_file_id);
      END_PARSE_FLAGS();
      story_content->file_id_ = td->videos_manager_->parse_video(parser);
      if (has_alt_file_id) {
        story_content->alt_file_id_ = td->videos_manager_->parse_video(parser);
        if (!story_content->alt_file_id_.is_valid()) {
          LOG(ERROR) << "Failed to parse alternative video";
        }
      }
      content = std::move(story_content);
      break;
    }
    case StoryContentType::Unsupported: {
      auto story_content = make_unique<StoryContentUnsupported>();
      parse(story_content->version_, parser);
      content = std::move(story_content);
      break;
    }
    default:
      is_bad = true;
  }
  if (is_bad) {
    LOG(ERROR) << "Load a story with an invalid content of type " << content_type;
    content = make_unique<StoryContentUnsupported>(0);
  }
}

void store_story_content(const StoryContent *content, LogEventStorerCalcLength &storer) {
  store(content, storer);
}

void store_story_content(const StoryContent *content, LogEventStorerUnsafe &storer) {
  store(content, storer);
}

void parse_story_content(unique_ptr<StoryContent> &content, LogEventParser &parser) {
  parse(content, parser);
}

void add_story_content_dependencies(Dependencies &dependencies, const StoryContent *story_content) {
  switch (story_content->get_type()) {
    case StoryContentType::Photo:
      break;
    case StoryContentType::Video:
      break;
    case StoryContentType::Unsupported:
      break;
    default:
      UNREACHABLE();
      break;
  }
}

unique_ptr<StoryContent> get_story_content(Td *td, tl_object_ptr<telegram_api::MessageMedia> &&media_ptr,
                                           DialogId owner_dialog_id) {
  CHECK(media_ptr != nullptr);
  switch (media_ptr->get_id()) {
    case telegram_api::messageMediaPhoto::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaPhoto>(media_ptr);
      if (media->photo_ == nullptr || (media->flags_ & telegram_api::messageMediaPhoto::TTL_SECONDS_MASK) != 0 ||
          media->spoiler_) {
        LOG(ERROR) << "Receive a story with content " << to_string(media);
        break;
      }

      auto photo = get_photo(td, std::move(media->photo_), owner_dialog_id, FileType::PhotoStory);
      if (photo.is_empty()) {
        LOG(ERROR) << "Receive a story with empty photo";
        break;
      }
      return make_unique<StoryContentPhoto>(std::move(photo));
    }
    case telegram_api::messageMediaDocument::ID: {
      auto media = telegram_api::move_object_as<telegram_api::messageMediaDocument>(media_ptr);
      if (media->document_ == nullptr || (media->flags_ & telegram_api::messageMediaDocument::TTL_SECONDS_MASK) != 0 ||
          media->spoiler_) {
        LOG(ERROR) << "Receive a story with content " << to_string(media);
        break;
      }

      auto document_ptr = std::move(media->document_);
      int32 document_id = document_ptr->get_id();
      if (document_id == telegram_api::documentEmpty::ID) {
        LOG(ERROR) << "Receive a story with empty document";
        break;
      }
      CHECK(document_id == telegram_api::document::ID);
      auto parsed_document = td->documents_manager_->on_get_document(
          telegram_api::move_object_as<telegram_api::document>(document_ptr), owner_dialog_id, false, nullptr,
          Document::Type::Video, DocumentsManager::Subtype::Story);
      if (parsed_document.empty() || parsed_document.type != Document::Type::Video) {
        LOG(ERROR) << "Receive a story with " << parsed_document;
        break;
      }
      CHECK(parsed_document.file_id.is_valid());

      FileId alt_file_id;
      if (media->alt_documents_.size() == 1u) {
        auto alt_document_ptr = std::move(media->alt_documents_[0]);
        int32 alt_document_id = alt_document_ptr->get_id();
        if (alt_document_id == telegram_api::documentEmpty::ID) {
          LOG(ERROR) << "Receive alternative " << to_string(alt_document_ptr);
        } else {
          CHECK(alt_document_id == telegram_api::document::ID);
          auto parsed_alt_document = td->documents_manager_->on_get_document(
              telegram_api::move_object_as<telegram_api::document>(alt_document_ptr), owner_dialog_id, false, nullptr,
              Document::Type::Video, DocumentsManager::Subtype::Story);
          if (parsed_alt_document.empty() || parsed_alt_document.type != Document::Type::Video) {
            LOG(ERROR) << "Receive invalid alternative document " << parsed_alt_document;
          } else {
            alt_file_id = parsed_alt_document.file_id;
          }
        }
      }

      return make_unique<StoryContentVideo>(parsed_document.file_id, alt_file_id);
    }
    case telegram_api::messageMediaUnsupported::ID:
      return make_unique<StoryContentUnsupported>();
    default:
      break;
  }
  return nullptr;
}

Result<unique_ptr<StoryContent>> get_input_story_content(
    Td *td, td_api::object_ptr<td_api::InputStoryContent> &&input_story_content, DialogId owner_dialog_id) {
  LOG(INFO) << "Get input story content from " << to_string(input_story_content);
  if (input_story_content == nullptr) {
    return Status::Error(400, "Input story content must be non-empty");
  }

  switch (input_story_content->get_id()) {
    case td_api::inputStoryContentPhoto::ID: {
      auto input_story = static_cast<const td_api::inputStoryContentPhoto *>(input_story_content.get());
      TRY_RESULT(file_id, td->file_manager_->get_input_file_id(FileType::Photo, input_story->photo_, owner_dialog_id,
                                                               false, false));
      file_id =
          td->file_manager_->copy_file_id(file_id, FileType::PhotoStory, owner_dialog_id, "get_input_story_content");
      auto sticker_file_ids =
          td->stickers_manager_->get_attached_sticker_file_ids(input_story->added_sticker_file_ids_);
      TRY_RESULT(photo,
                 create_photo(td->file_manager_.get(), file_id, PhotoSize(), 720, 1280, std::move(sticker_file_ids)));
      return make_unique<StoryContentPhoto>(std::move(photo));
    }
    case td_api::inputStoryContentVideo::ID: {
      auto input_story = static_cast<const td_api::inputStoryContentVideo *>(input_story_content.get());
      TRY_RESULT(file_id, td->file_manager_->get_input_file_id(FileType::Video, input_story->video_, owner_dialog_id,
                                                               false, false));
      if (input_story->duration_ < 0 || input_story->duration_ > 60.0) {
        return Status::Error(400, "Invalid video duration specified");
      }
      if (input_story->cover_frame_timestamp_ < 0.0) {
        return Status::Error(400, "Wrong cover timestamp specified");
      }
      file_id =
          td->file_manager_->copy_file_id(file_id, FileType::VideoStory, owner_dialog_id, "get_input_story_content");
      auto sticker_file_ids =
          td->stickers_manager_->get_attached_sticker_file_ids(input_story->added_sticker_file_ids_);
      bool has_stickers = !sticker_file_ids.empty();
      td->videos_manager_->create_video(file_id, string(), PhotoSize(), AnimationSize(), has_stickers,
                                        std::move(sticker_file_ids), "story.mp4", "video/mp4",
                                        static_cast<int32>(std::ceil(input_story->duration_)), input_story->duration_,
                                        get_dimensions(720, 1280, nullptr), true, input_story->is_animation_, 0,
                                        input_story->cover_frame_timestamp_, string(), false);

      return make_unique<StoryContentVideo>(file_id, FileId());
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::InputMedia> get_story_content_input_media(
    Td *td, const StoryContent *content, telegram_api::object_ptr<telegram_api::InputFile> input_file) {
  switch (content->get_type()) {
    case StoryContentType::Photo: {
      const auto *story_content = static_cast<const StoryContentPhoto *>(content);
      return photo_get_input_media(td->file_manager_.get(), story_content->photo_, std::move(input_file), 0, false);
    }
    case StoryContentType::Video: {
      const auto *story_content = static_cast<const StoryContentVideo *>(content);
      return td->videos_manager_->get_input_media(story_content->file_id_, std::move(input_file), nullptr, Photo(), 0,
                                                  0, false);
    }
    case StoryContentType::Unsupported:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::InputMedia> get_story_content_document_input_media(Td *td,
                                                                                          const StoryContent *content,
                                                                                          double main_frame_timestamp) {
  switch (content->get_type()) {
    case StoryContentType::Video: {
      const auto *story_content = static_cast<const StoryContentVideo *>(content);
      return td->videos_manager_->get_story_document_input_media(story_content->file_id_, main_frame_timestamp);
    }
    case StoryContentType::Photo:
    case StoryContentType::Unsupported:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void compare_story_contents(const StoryContent *old_content, const StoryContent *new_content, bool &is_content_changed,
                            bool &need_update) {
  StoryContentType content_type = new_content->get_type();
  if (old_content->get_type() != content_type) {
    need_update = true;
    return;
  }

  switch (content_type) {
    case StoryContentType::Photo: {
      const auto *old_ = static_cast<const StoryContentPhoto *>(old_content);
      const auto *new_ = static_cast<const StoryContentPhoto *>(new_content);
      if (old_->photo_ != new_->photo_) {
        need_update = true;
      }
      break;
    }
    case StoryContentType::Video: {
      const auto *old_ = static_cast<const StoryContentVideo *>(old_content);
      const auto *new_ = static_cast<const StoryContentVideo *>(new_content);
      if (old_->file_id_ != new_->file_id_ || old_->alt_file_id_ != new_->alt_file_id_) {
        need_update = true;
      }
      break;
    }
    case StoryContentType::Unsupported: {
      const auto *old_ = static_cast<const StoryContentUnsupported *>(old_content);
      const auto *new_ = static_cast<const StoryContentUnsupported *>(new_content);
      if (old_->version_ != new_->version_) {
        is_content_changed = true;
      }
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

void merge_story_contents(Td *td, const StoryContent *old_content, StoryContent *new_content, DialogId dialog_id,
                          bool &is_content_changed, bool &need_update) {
  StoryContentType content_type = new_content->get_type();
  CHECK(old_content->get_type() == content_type);

  switch (content_type) {
    case StoryContentType::Photo: {
      const auto *old_ = static_cast<const StoryContentPhoto *>(old_content);
      auto *new_ = static_cast<StoryContentPhoto *>(new_content);
      merge_photos(td, &old_->photo_, &new_->photo_, dialog_id, false, is_content_changed, need_update);
      break;
    }
    case StoryContentType::Video: {
      const auto *old_ = static_cast<const StoryContentVideo *>(old_content);
      const auto *new_ = static_cast<const StoryContentVideo *>(new_content);
      if (old_->file_id_ != new_->file_id_ || old_->alt_file_id_ != new_->alt_file_id_) {
        need_update = true;
      }
      break;
    }
    case StoryContentType::Unsupported: {
      const auto *old_ = static_cast<const StoryContentUnsupported *>(old_content);
      const auto *new_ = static_cast<const StoryContentUnsupported *>(new_content);
      if (old_->version_ != new_->version_) {
        is_content_changed = true;
      }
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

unique_ptr<StoryContent> copy_story_content(const StoryContent *content) {
  if (content == nullptr) {
    return nullptr;
  }
  switch (content->get_type()) {
    case StoryContentType::Photo: {
      const auto *story_content = static_cast<const StoryContentPhoto *>(content);
      return make_unique<StoryContentPhoto>(Photo(story_content->photo_));
    }
    case StoryContentType::Video: {
      const auto *story_content = static_cast<const StoryContentVideo *>(content);
      return make_unique<StoryContentVideo>(story_content->file_id_, story_content->alt_file_id_);
    }
    case StoryContentType::Unsupported: {
      const auto *story_content = static_cast<const StoryContentUnsupported *>(content);
      return make_unique<StoryContentUnsupported>(story_content->version_);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

td_api::object_ptr<td_api::StoryContent> get_story_content_object(Td *td, const StoryContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case StoryContentType::Photo: {
      const auto *s = static_cast<const StoryContentPhoto *>(content);
      auto photo = get_photo_object(td->file_manager_.get(), s->photo_);
      if (photo == nullptr) {
        return td_api::make_object<td_api::storyContentUnsupported>();
      }
      return td_api::make_object<td_api::storyContentPhoto>(std::move(photo));
    }
    case StoryContentType::Video: {
      const auto *s = static_cast<const StoryContentVideo *>(content);
      return td_api::make_object<td_api::storyContentVideo>(
          td->videos_manager_->get_story_video_object(s->file_id_),
          td->videos_manager_->get_story_video_object(s->alt_file_id_));
    }
    case StoryContentType::Unsupported:
      return td_api::make_object<td_api::storyContentUnsupported>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

FileId get_story_content_any_file_id(const StoryContent *content) {
  switch (content->get_type()) {
    case StoryContentType::Photo:
      return get_photo_any_file_id(static_cast<const StoryContentPhoto *>(content)->photo_);
    case StoryContentType::Video:
      return static_cast<const StoryContentVideo *>(content)->file_id_;
    case StoryContentType::Unsupported:
    default:
      return {};
  }
}

vector<FileId> get_story_content_file_ids(const Td *td, const StoryContent *content) {
  switch (content->get_type()) {
    case StoryContentType::Photo:
      return photo_get_file_ids(static_cast<const StoryContentPhoto *>(content)->photo_);
    case StoryContentType::Video: {
      vector<FileId> result;
      const auto *s = static_cast<const StoryContentVideo *>(content);
      Document(Document::Type::Video, s->file_id_).append_file_ids(td, result);
      Document(Document::Type::Video, s->alt_file_id_).append_file_ids(td, result);
      return result;
    }
    case StoryContentType::Unsupported:
    default:
      return {};
  }
}

int32 get_story_content_duration(const Td *td, const StoryContent *content) {
  CHECK(content != nullptr);
  switch (content->get_type()) {
    case StoryContentType::Video: {
      auto file_id = static_cast<const StoryContentVideo *>(content)->file_id_;
      return td->videos_manager_->get_video_duration(file_id);
    }
    default:
      return -1;
  }
}

}  // namespace td
