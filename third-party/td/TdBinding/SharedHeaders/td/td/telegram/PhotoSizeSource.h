//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/PhotoSizeType.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Variant.h"

namespace td {

struct PhotoSizeSource {
  enum class Type : int32 {
    Legacy,
    Thumbnail,
    DialogPhotoSmall,
    DialogPhotoBig,
    StickerSetThumbnail,
    FullLegacy,
    DialogPhotoSmallLegacy,
    DialogPhotoBigLegacy,
    StickerSetThumbnailLegacy,
    StickerSetThumbnailVersion
  };

  // for legacy photos with secret
  struct Legacy {
    Legacy() = default;
    explicit Legacy(int64 secret) : secret(secret) {
    }

    int64 secret = 0;
  };

  // for photos, document thumbnails, encrypted thumbnails
  struct Thumbnail {
    Thumbnail() = default;
    Thumbnail(FileType file_type, int32 thumbnail_type) : file_type(file_type), thumbnail_type(thumbnail_type) {
    }

    FileType file_type = FileType::None;
    PhotoSizeType thumbnail_type;
  };

  // for dialog photos
  struct DialogPhoto {
    DialogPhoto() = default;
    DialogPhoto(DialogId dialog_id, int64 dialog_access_hash)
        : dialog_id(dialog_id), dialog_access_hash(dialog_access_hash) {
    }

    tl_object_ptr<telegram_api::InputPeer> get_input_peer() const;

    DialogId dialog_id;
    int64 dialog_access_hash = 0;
  };

  struct DialogPhotoSmall final : public DialogPhoto {
    using DialogPhoto::DialogPhoto;
  };

  struct DialogPhotoBig final : public DialogPhoto {
    using DialogPhoto::DialogPhoto;
  };

  // for sticker set thumbnails
  struct StickerSetThumbnail {
    int64 sticker_set_id = 0;
    int64 sticker_set_access_hash = 0;

    StickerSetThumbnail() = default;
    StickerSetThumbnail(int64 sticker_set_id, int64 sticker_set_access_hash)
        : sticker_set_id(sticker_set_id), sticker_set_access_hash(sticker_set_access_hash) {
    }

    tl_object_ptr<telegram_api::InputStickerSet> get_input_sticker_set() const {
      return make_tl_object<telegram_api::inputStickerSetID>(sticker_set_id, sticker_set_access_hash);
    }
  };

  // for legacy photos with volume_id, local_id, secret
  struct FullLegacy {
    FullLegacy() = default;
    FullLegacy(int64 volume_id, int32 local_id, int64 secret)
        : volume_id(volume_id), local_id(local_id), secret(secret) {
    }

    int64 volume_id = 0;
    int32 local_id = 0;
    int64 secret = 0;
  };

  // for legacy dialog photos
  struct DialogPhotoLegacy : public DialogPhoto {
    DialogPhotoLegacy() = default;
    DialogPhotoLegacy(DialogId dialog_id, int64 dialog_access_hash, int64 volume_id, int32 local_id)
        : DialogPhoto(dialog_id, dialog_access_hash), volume_id(volume_id), local_id(local_id) {
    }

    int64 volume_id = 0;
    int32 local_id = 0;
  };

  struct DialogPhotoSmallLegacy final : public DialogPhotoLegacy {
    using DialogPhotoLegacy::DialogPhotoLegacy;
  };

  struct DialogPhotoBigLegacy final : public DialogPhotoLegacy {
    using DialogPhotoLegacy::DialogPhotoLegacy;
  };

  // for legacy sticker set thumbnails
  struct StickerSetThumbnailLegacy final : public StickerSetThumbnail {
    StickerSetThumbnailLegacy() = default;
    StickerSetThumbnailLegacy(int64 sticker_set_id, int64 sticker_set_access_hash, int64 volume_id, int32 local_id)
        : StickerSetThumbnail(sticker_set_id, sticker_set_access_hash), volume_id(volume_id), local_id(local_id) {
    }

    int64 volume_id = 0;
    int32 local_id = 0;
  };

  // for sticker set thumbnails identified by version
  struct StickerSetThumbnailVersion final : public StickerSetThumbnail {
    StickerSetThumbnailVersion() = default;
    StickerSetThumbnailVersion(int64 sticker_set_id, int64 sticker_set_access_hash, int32 version)
        : StickerSetThumbnail(sticker_set_id, sticker_set_access_hash), version(version) {
    }

    int32 version = 0;
  };

  PhotoSizeSource() = default;

  static PhotoSizeSource thumbnail(FileType file_type, int32 thumbnail_type) {
    return PhotoSizeSource(Thumbnail(file_type, thumbnail_type));
  }

  static PhotoSizeSource dialog_photo(DialogId dialog_id, int64 dialog_access_hash, bool is_big) {
    if (is_big) {
      return PhotoSizeSource(DialogPhotoBig(dialog_id, dialog_access_hash));
    } else {
      return PhotoSizeSource(DialogPhotoSmall(dialog_id, dialog_access_hash));
    }
  }

  static PhotoSizeSource full_legacy(int64 volume_id, int32 local_id, int64 secret) {
    return PhotoSizeSource(FullLegacy(volume_id, local_id, secret));
  }

  static PhotoSizeSource dialog_photo_legacy(DialogId dialog_id, int64 dialog_access_hash, bool is_big, int64 volume_id,
                                             int32 local_id) {
    if (is_big) {
      return PhotoSizeSource(DialogPhotoBigLegacy(dialog_id, dialog_access_hash, volume_id, local_id));
    } else {
      return PhotoSizeSource(DialogPhotoSmallLegacy(dialog_id, dialog_access_hash, volume_id, local_id));
    }
  }

  static PhotoSizeSource sticker_set_thumbnail_legacy(int64 sticker_set_id, int64 sticker_set_access_hash,
                                                      int64 volume_id, int32 local_id) {
    return PhotoSizeSource(StickerSetThumbnailLegacy(sticker_set_id, sticker_set_access_hash, volume_id, local_id));
  }

  static PhotoSizeSource sticker_set_thumbnail(int64 sticker_set_id, int64 sticker_set_access_hash, int32 version) {
    return PhotoSizeSource(StickerSetThumbnailVersion(sticker_set_id, sticker_set_access_hash, version));
  }

  static bool unique_less(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs);

  static bool unique_equal(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs);

  Type get_type(const char *source) const {
    auto offset = variant_.get_offset();
    LOG_CHECK(offset >= 0) << offset << ' ' << source;
    return static_cast<Type>(offset);
  }

  FileType get_file_type(const char *source) const;

  Thumbnail &thumbnail() {
    return variant_.get<Thumbnail>();
  }

  const Legacy &legacy() const {
    return variant_.get<Legacy>();
  }
  const Thumbnail &thumbnail() const {
    return variant_.get<Thumbnail>();
  }
  const DialogPhoto &dialog_photo() const {
    switch (variant_.get_offset()) {
      case 2:
        return variant_.get<DialogPhotoSmall>();
      case 3:
        return variant_.get<DialogPhotoBig>();
      case 6:
        return variant_.get<DialogPhotoSmallLegacy>();
      case 7:
        return variant_.get<DialogPhotoBigLegacy>();
      default:
        UNREACHABLE();
        return variant_.get<DialogPhotoSmall>();
    }
  }
  const StickerSetThumbnail &sticker_set_thumbnail() const {
    switch (variant_.get_offset()) {
      case 4:
        return variant_.get<StickerSetThumbnail>();
      case 8:
        return variant_.get<StickerSetThumbnailLegacy>();
      case 9:
        return variant_.get<StickerSetThumbnailVersion>();
      default:
        UNREACHABLE();
        return variant_.get<StickerSetThumbnail>();
    }
  }
  const FullLegacy &full_legacy() const {
    return variant_.get<FullLegacy>();
  }
  const DialogPhotoLegacy &dialog_photo_legacy() const {
    if (variant_.get_offset() == 6) {
      return variant_.get<DialogPhotoSmallLegacy>();
    } else {
      return variant_.get<DialogPhotoBigLegacy>();
    }
  }
  const StickerSetThumbnailLegacy &sticker_set_thumbnail_legacy() const {
    return variant_.get<StickerSetThumbnailLegacy>();
  }
  const StickerSetThumbnailVersion &sticker_set_thumbnail_version() const {
    return variant_.get<StickerSetThumbnailVersion>();
  }

  // returns unique representation of the source
  string get_unique(const char *source) const;

  // can't be called for Legacy sources
  string get_unique_name(int64 photo_id, const char *source) const;

  template <class StorerT>
  void store(StorerT &storer) const;
  template <class ParserT>
  void parse(ParserT &parser);

  friend bool operator==(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs);

 private:
  Variant<Legacy, Thumbnail, DialogPhotoSmall, DialogPhotoBig, StickerSetThumbnail, FullLegacy, DialogPhotoSmallLegacy,
          DialogPhotoBigLegacy, StickerSetThumbnailLegacy, StickerSetThumbnailVersion>
      variant_;

  template <class T>
  explicit PhotoSizeSource(const T &variant) : variant_(variant) {
  }

  int32 get_compare_type(const char *source) const;

  int64 get_compare_volume_id() const;

  int32 get_compare_local_id() const;
};

bool operator==(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs);
bool operator!=(const PhotoSizeSource &lhs, const PhotoSizeSource &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const PhotoSizeSource &source);

}  // namespace td
