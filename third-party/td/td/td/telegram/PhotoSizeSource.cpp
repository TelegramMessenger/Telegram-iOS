//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/PhotoSizeSource.h"

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_storers.h"

namespace td {

tl_object_ptr<telegram_api::InputPeer> PhotoSizeSource::DialogPhoto::get_input_peer() const {
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      UserId user_id = dialog_id.get_user_id();
      return make_tl_object<telegram_api::inputPeerUser>(user_id.get(), dialog_access_hash);
    }
    case DialogType::Chat: {
      ChatId chat_id = dialog_id.get_chat_id();
      return make_tl_object<telegram_api::inputPeerChat>(chat_id.get());
    }
    case DialogType::Channel: {
      ChannelId channel_id = dialog_id.get_channel_id();
      return make_tl_object<telegram_api::inputPeerChannel>(channel_id.get(), dialog_access_hash);
    }
    case DialogType::SecretChat:
      return nullptr;
    case DialogType::None:
      return make_tl_object<telegram_api::inputPeerEmpty>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

FileType PhotoSizeSource::get_file_type(const char *source) const {
  switch (get_type(source)) {
    case Type::Thumbnail:
      return thumbnail().file_type;
    case Type::DialogPhotoSmall:
    case Type::DialogPhotoBig:
    case Type::DialogPhotoSmallLegacy:
    case Type::DialogPhotoBigLegacy:
      return FileType::ProfilePhoto;
    case Type::StickerSetThumbnail:
    case Type::StickerSetThumbnailLegacy:
    case Type::StickerSetThumbnailVersion:
      return FileType::Thumbnail;
    case Type::Legacy:
    case Type::FullLegacy:
    default:
      UNREACHABLE();
      return FileType::Thumbnail;
  }
}

string PhotoSizeSource::get_unique(const char *source) const {
  auto compare_type = get_compare_type(source);
  if (compare_type != 2 && compare_type != 3) {
    return string(1, static_cast<char>(compare_type));
  }

  auto ptr = StackAllocator::alloc(16);
  MutableSlice data = ptr.as_slice();
  TlStorerUnsafe storer(data.ubegin());
  if (compare_type == 2) {
    storer.store_slice(Slice("\x02"));
  }
  td::store(get_compare_volume_id(), storer);
  td::store(get_compare_local_id(), storer);
  auto size = storer.get_buf() - data.ubegin();
  CHECK(size <= 13);
  return string(data.begin(), size);
}

int32 PhotoSizeSource::get_compare_type(const char *source) const {
  switch (get_type(source)) {
    case Type::Legacy:
      break;
    case Type::Thumbnail: {
      auto type = thumbnail().thumbnail_type.type;
      CHECK(0 <= type && type <= 127);
      if (type == 'a') {
        return 0;
      }
      if (type == 'c') {
        return 1;
      }
      return type + 5;
    }
    case Type::DialogPhotoSmall:
      return 0;
    case Type::DialogPhotoBig:
      return 1;
    case Type::StickerSetThumbnail:
      break;
    case Type::FullLegacy:
    case Type::DialogPhotoSmallLegacy:
    case Type::DialogPhotoBigLegacy:
    case Type::StickerSetThumbnailLegacy:
      return 3;
    case Type::StickerSetThumbnailVersion:
      return 2;
    default:
      break;
  }
  UNREACHABLE();
  return -1;
}

int64 PhotoSizeSource::get_compare_volume_id() const {
  switch (get_type("get_compare_volume_id")) {
    case Type::FullLegacy:
      return full_legacy().volume_id;
    case Type::DialogPhotoSmallLegacy:
    case Type::DialogPhotoBigLegacy:
      return dialog_photo_legacy().volume_id;
    case Type::StickerSetThumbnailLegacy:
      return sticker_set_thumbnail_legacy().volume_id;
    case Type::StickerSetThumbnailVersion:
      return sticker_set_thumbnail_version().sticker_set_id;
    default:
      UNREACHABLE();
      return 0;
  }
}

int32 PhotoSizeSource::get_compare_local_id() const {
  switch (get_type("get_compare_volume_id")) {
    case Type::FullLegacy:
      return full_legacy().local_id;
    case Type::DialogPhotoSmallLegacy:
    case Type::DialogPhotoBigLegacy:
      return dialog_photo_legacy().local_id;
    case Type::StickerSetThumbnailLegacy:
      return sticker_set_thumbnail_legacy().local_id;
    case Type::StickerSetThumbnailVersion:
      return sticker_set_thumbnail_version().version;
    default:
      UNREACHABLE();
      return 0;
  }
}

bool PhotoSizeSource::unique_less(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs) {
  auto lhs_compare_type = lhs.get_compare_type("unique_less");
  auto rhs_compare_type = rhs.get_compare_type("unique_less");
  if (lhs_compare_type != rhs_compare_type) {
    return lhs_compare_type < rhs_compare_type;
  }
  if (lhs_compare_type != 2 && lhs_compare_type != 3) {
    return false;
  }
  auto lhs_volume_id = lhs.get_compare_volume_id();
  auto rhs_volume_id = rhs.get_compare_volume_id();
  if (lhs_volume_id != rhs_volume_id) {
    return lhs_volume_id < rhs_volume_id;
  }
  return lhs.get_compare_local_id() < rhs.get_compare_local_id();
}

bool PhotoSizeSource::unique_equal(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs) {
  auto lhs_compare_type = lhs.get_compare_type("unique_equal");
  auto rhs_compare_type = rhs.get_compare_type("unique_equal");
  if (lhs_compare_type != rhs_compare_type) {
    return false;
  }
  if (lhs_compare_type != 2 && lhs_compare_type != 3) {
    return true;
  }
  return lhs.get_compare_volume_id() == rhs.get_compare_volume_id() &&
         lhs.get_compare_local_id() == rhs.get_compare_local_id();
}

string PhotoSizeSource::get_unique_name(int64 photo_id, const char *source) const {
  switch (get_type(source)) {
    case Type::Thumbnail: {
      int32 type = thumbnail().thumbnail_type.type;
      CHECK(0 <= type && type <= 127);
      return PSTRING() << photo_id << '_' << type;
    }
    case Type::DialogPhotoSmall:
      return to_string(photo_id);
    case Type::DialogPhotoBig:
      return PSTRING() << photo_id << '_' << 1;
    case Type::StickerSetThumbnailVersion:
      return PSTRING() << sticker_set_thumbnail_version().sticker_set_id << '_'
                       << static_cast<uint32>(sticker_set_thumbnail_version().version);
    case Type::Legacy:
    case Type::StickerSetThumbnail:
    case Type::FullLegacy:
    case Type::DialogPhotoSmallLegacy:
    case Type::DialogPhotoBigLegacy:
    case Type::StickerSetThumbnailLegacy:
    default:
      UNREACHABLE();
      break;
  }
  return string();
}

static bool operator==(const PhotoSizeSource::Legacy &lhs, const PhotoSizeSource::Legacy &rhs) {
  UNREACHABLE();
  return false;
}

static bool operator==(const PhotoSizeSource::Thumbnail &lhs, const PhotoSizeSource::Thumbnail &rhs) {
  return lhs.file_type == rhs.file_type && lhs.thumbnail_type == rhs.thumbnail_type;
}

static bool operator==(const PhotoSizeSource::DialogPhoto &lhs, const PhotoSizeSource::DialogPhoto &rhs) {
  return lhs.dialog_id == rhs.dialog_id && lhs.dialog_access_hash == rhs.dialog_access_hash;
}

static bool operator==(const PhotoSizeSource::DialogPhotoSmall &lhs, const PhotoSizeSource::DialogPhotoSmall &rhs) {
  return static_cast<const PhotoSizeSource::DialogPhoto &>(lhs) ==
         static_cast<const PhotoSizeSource::DialogPhoto &>(rhs);
}

static bool operator==(const PhotoSizeSource::DialogPhotoBig &lhs, const PhotoSizeSource::DialogPhotoBig &rhs) {
  return static_cast<const PhotoSizeSource::DialogPhoto &>(lhs) ==
         static_cast<const PhotoSizeSource::DialogPhoto &>(rhs);
}

static bool operator==(const PhotoSizeSource::StickerSetThumbnail &lhs,
                       const PhotoSizeSource::StickerSetThumbnail &rhs) {
  return lhs.sticker_set_id == rhs.sticker_set_id && lhs.sticker_set_access_hash == rhs.sticker_set_access_hash;
}

static bool operator==(const PhotoSizeSource::FullLegacy &lhs, const PhotoSizeSource::FullLegacy &rhs) {
  return lhs.volume_id == rhs.volume_id && lhs.local_id == rhs.local_id && lhs.secret == rhs.secret;
}

static bool operator==(const PhotoSizeSource::DialogPhotoLegacy &lhs, const PhotoSizeSource::DialogPhotoLegacy &rhs) {
  return static_cast<const PhotoSizeSource::DialogPhoto &>(lhs) ==
             static_cast<const PhotoSizeSource::DialogPhoto &>(rhs) &&
         lhs.volume_id == rhs.volume_id && lhs.local_id == rhs.local_id;
}

static bool operator==(const PhotoSizeSource::DialogPhotoSmallLegacy &lhs,
                       const PhotoSizeSource::DialogPhotoSmallLegacy &rhs) {
  return static_cast<const PhotoSizeSource::DialogPhotoLegacy &>(lhs) ==
         static_cast<const PhotoSizeSource::DialogPhotoLegacy &>(rhs);
}

static bool operator==(const PhotoSizeSource::DialogPhotoBigLegacy &lhs,
                       const PhotoSizeSource::DialogPhotoBigLegacy &rhs) {
  return static_cast<const PhotoSizeSource::DialogPhotoLegacy &>(lhs) ==
         static_cast<const PhotoSizeSource::DialogPhotoLegacy &>(rhs);
}

static bool operator==(const PhotoSizeSource::StickerSetThumbnailLegacy &lhs,
                       const PhotoSizeSource::StickerSetThumbnailLegacy &rhs) {
  return static_cast<const PhotoSizeSource::StickerSetThumbnail &>(lhs) ==
             static_cast<const PhotoSizeSource::StickerSetThumbnail &>(rhs) &&
         lhs.volume_id == rhs.volume_id && lhs.local_id == rhs.local_id;
}

static bool operator==(const PhotoSizeSource::StickerSetThumbnailVersion &lhs,
                       const PhotoSizeSource::StickerSetThumbnailVersion &rhs) {
  return static_cast<const PhotoSizeSource::StickerSetThumbnail &>(lhs) ==
             static_cast<const PhotoSizeSource::StickerSetThumbnail &>(rhs) &&
         lhs.version == rhs.version;
}

bool operator==(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs) {
  return lhs.variant_ == rhs.variant_;
}

bool operator!=(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const PhotoSizeSource &source) {
  switch (source.get_type("operator<<")) {
    case PhotoSizeSource::Type::Legacy:
      return string_builder << "PhotoSizeSourceLegacy[]";
    case PhotoSizeSource::Type::Thumbnail:
      return string_builder << "PhotoSizeSourceThumbnail[" << source.thumbnail().file_type
                            << ", type = " << source.thumbnail().thumbnail_type << ']';
    case PhotoSizeSource::Type::DialogPhotoSmall:
      return string_builder << "PhotoSizeSourceChatPhotoSmall[]";
    case PhotoSizeSource::Type::DialogPhotoBig:
      return string_builder << "PhotoSizeSourceChatPhotoBig[]";
    case PhotoSizeSource::Type::StickerSetThumbnail:
      return string_builder << "PhotoSizeSourceStickerSetThumbnail[" << source.sticker_set_thumbnail().sticker_set_id
                            << ']';
    case PhotoSizeSource::Type::FullLegacy:
      return string_builder << "PhotoSizeSourceFullLegacy[]";
    case PhotoSizeSource::Type::DialogPhotoSmallLegacy:
      return string_builder << "PhotoSizeSourceChatPhotoSmallLegacy[]";
    case PhotoSizeSource::Type::DialogPhotoBigLegacy:
      return string_builder << "PhotoSizeSourceChatPhotoBigLegacy[]";
    case PhotoSizeSource::Type::StickerSetThumbnailLegacy:
      return string_builder << "PhotoSizeSourceStickerSetThumbnailLegacy["
                            << source.sticker_set_thumbnail().sticker_set_id << ']';
    case PhotoSizeSource::Type::StickerSetThumbnailVersion:
      return string_builder << "PhotoSizeSourceStickerSetThumbnailVersion["
                            << source.sticker_set_thumbnail().sticker_set_id << '_'
                            << source.sticker_set_thumbnail_version().version << ']';
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
