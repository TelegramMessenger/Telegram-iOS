//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileLocation.h"

#include "td/telegram/files/FileType.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/PhotoSizeSource.hpp"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/Variant.h"

namespace td {

template <class StorerT>
void PartialRemoteFileLocation::store(StorerT &storer) const {
  using td::store;
  store(file_id_, storer);
  store(part_count_, storer);
  store(part_size_, storer);
  store(ready_part_count_, storer);
  store(is_big_, storer);
}

template <class ParserT>
void PartialRemoteFileLocation::parse(ParserT &parser) {
  using td::parse;
  parse(file_id_, parser);
  parse(part_count_, parser);
  parse(part_size_, parser);
  parse(ready_part_count_, parser);
  parse(is_big_, parser);
}

template <class StorerT>
void PhotoRemoteFileLocation::store(StorerT &storer) const {
  using td::store;
  store(id_, storer);
  store(access_hash_, storer);
  store(source_, storer);
}

template <class ParserT>
void PhotoRemoteFileLocation::parse(ParserT &parser) {
  using td::parse;
  parse(id_, parser);
  parse(access_hash_, parser);
  if (parser.version() >= static_cast<int32>(Version::RemovePhotoVolumeAndLocalId)) {
    parse(source_, parser);
  } else {
    int64 volume_id;
    PhotoSizeSource source;
    int32 local_id;
    parse(volume_id, parser);
    if (parser.version() >= static_cast<int32>(Version::AddPhotoSizeSource)) {
      parse(source, parser);
      parse(local_id, parser);
    } else {
      int64 secret;
      parse(secret, parser);
      parse(local_id, parser);
      source = PhotoSizeSource::full_legacy(volume_id, local_id, secret);
    }

    if (parser.get_error() != nullptr) {
      return;
    }

    switch (source.get_type("PhotoRemoteFileLocation::parse")) {
      case PhotoSizeSource::Type::Legacy:
        source_ = PhotoSizeSource::full_legacy(volume_id, local_id, source.legacy().secret);
        break;
      case PhotoSizeSource::Type::FullLegacy:
      case PhotoSizeSource::Type::Thumbnail:
        source_ = source;
        break;
      case PhotoSizeSource::Type::DialogPhotoSmall:
      case PhotoSizeSource::Type::DialogPhotoBig: {
        auto &dialog_photo = source.dialog_photo();
        bool is_big = source.get_type("PhotoRemoteFileLocation::parse") == PhotoSizeSource::Type::DialogPhotoBig;
        source_ = PhotoSizeSource::dialog_photo_legacy(dialog_photo.dialog_id, dialog_photo.dialog_access_hash, is_big,
                                                       volume_id, local_id);
        break;
      }
      case PhotoSizeSource::Type::StickerSetThumbnail: {
        auto &sticker_set_thumbnail = source.sticker_set_thumbnail();
        source_ = PhotoSizeSource::sticker_set_thumbnail_legacy(
            sticker_set_thumbnail.sticker_set_id, sticker_set_thumbnail.sticker_set_access_hash, volume_id, local_id);
        break;
      }
      default:
        parser.set_error("Invalid PhotoSizeSource in legacy PhotoRemoteFileLocation");
        break;
    }
  }
}

template <class StorerT>
void PhotoRemoteFileLocation::AsKey::store(StorerT &storer) const {
  using td::store;
  auto unique = key.source_.get_unique("PhotoRemoteFileLocation::AsKey::store");
  switch (key.source_.get_type("PhotoRemoteFileLocation::AsKey::store")) {
    case PhotoSizeSource::Type::Legacy:
    case PhotoSizeSource::Type::StickerSetThumbnail:
      UNREACHABLE();
      break;
    case PhotoSizeSource::Type::FullLegacy:
    case PhotoSizeSource::Type::DialogPhotoSmallLegacy:
    case PhotoSizeSource::Type::DialogPhotoBigLegacy:
    case PhotoSizeSource::Type::StickerSetThumbnailLegacy:  // 12/20 bytes
      if (!is_unique) {
        store(key.id_, storer);
      }
      storer.store_slice(unique);  // volume_id + local_id
      break;
    case PhotoSizeSource::Type::DialogPhotoSmall:
    case PhotoSizeSource::Type::DialogPhotoBig:
    case PhotoSizeSource::Type::Thumbnail:  // 8 + 1 bytes
      store(key.id_, storer);               // photo_id or document_id
      storer.store_slice(unique);
      break;
    case PhotoSizeSource::Type::StickerSetThumbnailVersion:  // 13 bytes
      // sticker set thumbnails have no photo_id or document_id
      storer.store_slice(unique);
      break;
    default:
      UNREACHABLE();
      break;
  }
}

template <class StorerT>
void WebRemoteFileLocation::store(StorerT &storer) const {
  using td::store;
  store(url_, storer);
  store(access_hash_, storer);
}

template <class ParserT>
void WebRemoteFileLocation::parse(ParserT &parser) {
  using td::parse;
  parse(url_, parser);
  parse(access_hash_, parser);
}

template <class StorerT>
void WebRemoteFileLocation::AsKey::store(StorerT &storer) const {
  td::store(key.url_, storer);
}

template <class StorerT>
void CommonRemoteFileLocation::store(StorerT &storer) const {
  using td::store;
  store(id_, storer);
  store(access_hash_, storer);
}

template <class ParserT>
void CommonRemoteFileLocation::parse(ParserT &parser) {
  using td::parse;
  parse(id_, parser);
  parse(access_hash_, parser);
}

template <class StorerT>
void CommonRemoteFileLocation::AsKey::store(StorerT &storer) const {
  td::store(key.id_, storer);
}

template <class StorerT>
void FullRemoteFileLocation::store(StorerT &storer) const {
  using ::td::store;
  bool has_file_reference = !file_reference_.empty();
  auto type = key_type();
  if (has_file_reference) {
    type |= FILE_REFERENCE_FLAG;
  }
  store(type, storer);
  store(dc_id_.get_value(), storer);
  if (has_file_reference) {
    store(file_reference_, storer);
  }
  variant_.visit([&](auto &&value) {
    using td::store;
    store(value, storer);
  });
}

template <class ParserT>
void FullRemoteFileLocation::parse(ParserT &parser) {
  using ::td::parse;
  int32 raw_type;
  parse(raw_type, parser);
  bool is_web = (raw_type & WEB_LOCATION_FLAG) != 0;
  raw_type &= ~WEB_LOCATION_FLAG;
  bool has_file_reference = (raw_type & FILE_REFERENCE_FLAG) != 0;
  raw_type &= ~FILE_REFERENCE_FLAG;
  if (raw_type < 0 || raw_type >= static_cast<int32>(FileType::Size)) {
    return parser.set_error("Invalid FileType in FullRemoteFileLocation");
  }
  file_type_ = static_cast<FileType>(raw_type);
  int32 dc_id_value;
  parse(dc_id_value, parser);
  dc_id_ = DcId::from_value(dc_id_value);

  if (has_file_reference) {
    parse(file_reference_, parser);
    if (file_reference_ == FileReferenceView::invalid_file_reference()) {
      file_reference_.clear();
    }
  }
  if (is_web) {
    variant_ = WebRemoteFileLocation();
    return web().parse(parser);
  }

  switch (location_type()) {
    case LocationType::Web:
      UNREACHABLE();
      break;
    case LocationType::Photo:
      variant_ = PhotoRemoteFileLocation();
      photo().parse(parser);
      if (parser.get_error() != nullptr) {
        return;
      }
      switch (photo().source_.get_type("FullRemoteFileLocation::parse")) {
        case PhotoSizeSource::Type::Legacy:
        case PhotoSizeSource::Type::FullLegacy:
          break;
        case PhotoSizeSource::Type::Thumbnail:
          if (photo().source_.get_file_type("FullRemoteFileLocation::parse") != file_type_ ||
              (file_type_ != FileType::Photo && file_type_ != FileType::PhotoStory &&
               file_type_ != FileType::SelfDestructingPhoto && file_type_ != FileType::Thumbnail &&
               file_type_ != FileType::EncryptedThumbnail)) {
            parser.set_error("Invalid FileType in PhotoRemoteFileLocation Thumbnail");
          }
          break;
        case PhotoSizeSource::Type::DialogPhotoSmall:
        case PhotoSizeSource::Type::DialogPhotoBig:
        case PhotoSizeSource::Type::DialogPhotoSmallLegacy:
        case PhotoSizeSource::Type::DialogPhotoBigLegacy:
          if (file_type_ != FileType::ProfilePhoto) {
            parser.set_error("Invalid FileType in PhotoRemoteFileLocation DialogPhoto");
          }
          break;
        case PhotoSizeSource::Type::StickerSetThumbnail:
        case PhotoSizeSource::Type::StickerSetThumbnailLegacy:
        case PhotoSizeSource::Type::StickerSetThumbnailVersion:
          if (file_type_ != FileType::Thumbnail) {
            parser.set_error("Invalid FileType in PhotoRemoteFileLocation StickerSetThumbnail");
          }
          break;
        default:
          UNREACHABLE();
          break;
      }
      return;
    case LocationType::Common:
      variant_ = CommonRemoteFileLocation();
      return common().parse(parser);
    case LocationType::None:
      break;
  }
  parser.set_error("Invalid FileType in FullRemoteFileLocation");
}

template <class StorerT>
void FullRemoteFileLocation::AsKey::store(StorerT &storer) const {
  using td::store;
  store(key.key_type(), storer);
  key.variant_.visit([&](auto &&value) {
    using td::store;
    store(value.as_key(false), storer);
  });
}

template <class StorerT>
void FullRemoteFileLocation::AsUnique::store(StorerT &storer) const {
  using td::store;

  int32 type = [key = &key] {
    if (key->is_web()) {
      return 0;
    }
    return static_cast<int32>(get_file_type_class(key->file_type_)) + 1;
  }();
  store(type, storer);
  key.variant_.visit([&](auto &&value) {
    using td::store;
    store(value.as_key(true), storer);
  });
}

template <class StorerT>
void RemoteFileLocation::store(StorerT &storer) const {
  td::store(variant_, storer);
}

template <class ParserT>
void RemoteFileLocation::parse(ParserT &parser) {
  td::parse(variant_, parser);
}

template <class StorerT>
void PartialLocalFileLocation::store(StorerT &storer) const {
  using td::store;
  store(file_type_, storer);
  store(path_, storer);
  store(static_cast<int32>(part_size_ & 0x7FFFFFFF), storer);
  int32 deprecated_ready_part_count = part_size_ > 0x7FFFFFFF ? -2 : -1;
  store(deprecated_ready_part_count, storer);
  store(iv_, storer);
  store(ready_bitmask_, storer);
  if (deprecated_ready_part_count == -2) {
    CHECK(part_size_ < (static_cast<int64>(1) << 62));
    store(static_cast<int32>(part_size_ >> 31), storer);
  }
}

template <class ParserT>
void PartialLocalFileLocation::parse(ParserT &parser) {
  using td::parse;
  parse(file_type_, parser);
  if (file_type_ < FileType::Thumbnail || file_type_ >= FileType::Size) {
    return parser.set_error("Invalid type in PartialLocalFileLocation");
  }
  parse(path_, parser);
  int32 part_size_low;
  parse(part_size_low, parser);
  part_size_ = part_size_low;
  int32 deprecated_ready_part_count;
  parse(deprecated_ready_part_count, parser);
  parse(iv_, parser);
  if (deprecated_ready_part_count == -1 || deprecated_ready_part_count == -2) {
    parse(ready_bitmask_, parser);
    if (deprecated_ready_part_count == -2) {
      int32 part_size_high;
      parse(part_size_high, parser);
      part_size_ += static_cast<int64>(part_size_high) << 31;
    }
  } else {
    CHECK(0 <= deprecated_ready_part_count);
    CHECK(deprecated_ready_part_count <= (1 << 22));
    ready_bitmask_ = Bitmask(Bitmask::Ones{}, deprecated_ready_part_count).encode();
  }
}

template <class StorerT>
void FullLocalFileLocation::store(StorerT &storer) const {
  using td::store;
  store(file_type_, storer);
  store(mtime_nsec_, storer);
  store(path_, storer);
}

template <class ParserT>
void FullLocalFileLocation::parse(ParserT &parser) {
  using td::parse;
  parse(file_type_, parser);
  if (file_type_ < FileType::Thumbnail || file_type_ >= FileType::Size) {
    return parser.set_error("Invalid type in FullLocalFileLocation");
  }
  parse(mtime_nsec_, parser);
  parse(path_, parser);
}

template <class StorerT>
void PartialLocalFileLocationPtr::store(StorerT &storer) const {
  td::store(*location_, storer);
}

template <class ParserT>
void PartialLocalFileLocationPtr::parse(ParserT &parser) {
  td::parse(*location_, parser);
}

template <class StorerT>
void LocalFileLocation::store(StorerT &storer) const {
  td::store(variant_, storer);
}

template <class ParserT>
void LocalFileLocation::parse(ParserT &parser) {
  td::parse(variant_, parser);
}

template <class StorerT>
void FullGenerateFileLocation::store(StorerT &storer) const {
  using td::store;
  store(file_type_, storer);
  store(original_path_, storer);
  store(conversion_, storer);
}

template <class ParserT>
void FullGenerateFileLocation::parse(ParserT &parser) {
  using td::parse;
  parse(file_type_, parser);
  parse(original_path_, parser);
  parse(conversion_, parser);
}

template <class StorerT>
void GenerateFileLocation::store(StorerT &storer) const {
  td::store(type_, storer);
  switch (type_) {
    case Type::Empty:
      return;
    case Type::Full:
      return td::store(full_, storer);
  }
}

template <class ParserT>
void GenerateFileLocation::parse(ParserT &parser) {
  td::parse(type_, parser);
  switch (type_) {
    case Type::Empty:
      return;
    case Type::Full:
      return td::parse(full_, parser);
  }
  return parser.set_error("Invalid type in GenerateFileLocation");
}

}  // namespace td
