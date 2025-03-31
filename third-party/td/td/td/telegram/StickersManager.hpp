//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StickersManager.h"

#include "td/telegram/files/FileId.hpp"
#include "td/telegram/misc.h"
#include "td/telegram/PhotoSize.hpp"
#include "td/telegram/PhotoSizeType.h"
#include "td/telegram/StickerFormat.h"
#include "td/telegram/StickerMaskPosition.hpp"

#include "td/utils/emoji.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/utf8.h"

namespace td {

template <class StorerT>
void StickersManager::store_sticker(FileId file_id, bool in_sticker_set, StorerT &storer, const char *source) const {
  const Sticker *sticker = get_sticker(file_id);
  LOG_CHECK(sticker != nullptr) << file_id << ' ' << in_sticker_set << ' ' << source;
  bool has_sticker_set_access_hash = sticker->set_id_.is_valid() && !in_sticker_set;
  bool has_minithumbnail = !sticker->minithumbnail_.empty();
  bool is_tgs = sticker->format_ == StickerFormat::Tgs;
  bool is_webm = sticker->format_ == StickerFormat::Webm;
  bool has_premium_animation = sticker->premium_animation_file_id_.is_valid();
  bool is_mask = sticker->type_ == StickerType::Mask;
  bool is_emoji = sticker->type_ == StickerType::CustomEmoji;
  bool has_emoji_receive_date = is_emoji && sticker->emoji_receive_date_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_mask);
  STORE_FLAG(has_sticker_set_access_hash);
  STORE_FLAG(in_sticker_set);
  STORE_FLAG(is_tgs);
  STORE_FLAG(has_minithumbnail);
  STORE_FLAG(is_webm);
  STORE_FLAG(has_premium_animation);
  STORE_FLAG(is_emoji);
  STORE_FLAG(sticker->is_premium_);
  STORE_FLAG(has_emoji_receive_date);
  STORE_FLAG(sticker->has_text_color_);
  END_STORE_FLAGS();
  if (!in_sticker_set) {
    store(sticker->set_id_.get(), storer);
    if (has_sticker_set_access_hash) {
      auto sticker_set = get_sticker_set(sticker->set_id_);
      CHECK(sticker_set != nullptr);
      store(sticker_set->access_hash_, storer);
    }
  }
  store(sticker->alt_, storer);
  store(sticker->dimensions_, storer);
  store(sticker->s_thumbnail_, storer);
  store(sticker->m_thumbnail_, storer);
  store(file_id, storer);
  if (is_mask) {
    store(sticker->mask_position_, storer);
  }
  if (has_minithumbnail) {
    store(sticker->minithumbnail_, storer);
  }
  if (has_premium_animation) {
    store(sticker->premium_animation_file_id_, storer);
  }
  if (has_emoji_receive_date) {
    store(sticker->emoji_receive_date_, storer);
  }
}

template <class ParserT>
FileId StickersManager::parse_sticker(bool in_sticker_set, ParserT &parser) {
  if (parser.get_error() != nullptr) {
    return FileId();
  }

  auto sticker = make_unique<Sticker>();
  bool has_sticker_set_access_hash;
  bool in_sticker_set_stored;
  bool has_minithumbnail;
  bool is_tgs;
  bool is_webm;
  bool has_premium_animation;
  bool is_mask;
  bool is_emoji;
  bool has_emoji_receive_date;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_mask);
  PARSE_FLAG(has_sticker_set_access_hash);
  PARSE_FLAG(in_sticker_set_stored);
  PARSE_FLAG(is_tgs);
  PARSE_FLAG(has_minithumbnail);
  PARSE_FLAG(is_webm);
  PARSE_FLAG(has_premium_animation);
  PARSE_FLAG(is_emoji);
  PARSE_FLAG(sticker->is_premium_);
  PARSE_FLAG(has_emoji_receive_date);
  PARSE_FLAG(sticker->has_text_color_);
  END_PARSE_FLAGS();
  if (is_webm) {
    sticker->format_ = StickerFormat::Webm;
  } else if (is_tgs) {
    sticker->format_ = StickerFormat::Tgs;
  } else {
    sticker->format_ = StickerFormat::Webp;
  }
  sticker->type_ = ::td::get_sticker_type(is_mask, is_emoji);
  if (in_sticker_set_stored != in_sticker_set) {
    Slice data = parser.template fetch_string_raw<Slice>(parser.get_left_len());
    for (auto c : data) {
      if (c != '\0') {
        parser.set_error("Invalid sticker set is stored in the database");
        break;
      }
    }
    parser.set_error("Zero sticker set is stored in the database");
    return FileId();
  }
  if (!in_sticker_set) {
    int64 set_id;
    parse(set_id, parser);
    sticker->set_id_ = StickerSetId(set_id);
    if (has_sticker_set_access_hash) {
      int64 sticker_set_access_hash;
      parse(sticker_set_access_hash, parser);
      add_sticker_set(sticker->set_id_, sticker_set_access_hash);
    } else {
      // backward compatibility
      sticker->set_id_ = StickerSetId();
    }
  }
  parse(sticker->alt_, parser);
  parse(sticker->dimensions_, parser);
  PhotoSize thumbnail;
  parse(thumbnail, parser);
  add_sticker_thumbnail(sticker.get(), thumbnail);
  parse(thumbnail, parser);
  add_sticker_thumbnail(sticker.get(), thumbnail);
  parse(sticker->file_id_, parser);
  if (is_mask) {
    parse(sticker->mask_position_, parser);
  }
  if (has_minithumbnail) {
    parse(sticker->minithumbnail_, parser);
  }
  if (has_premium_animation) {
    sticker->is_premium_ = true;
    parse(sticker->premium_animation_file_id_, parser);
  }
  if (has_emoji_receive_date) {
    parse(sticker->emoji_receive_date_, parser);
  }

  if (parser.get_error() != nullptr || !sticker->file_id_.is_valid()) {
    return FileId();
  }
  sticker->is_from_database_ = true;
  return on_get_sticker(std::move(sticker), false);  // data in the database is always outdated
}

template <class StorerT>
void StickersManager::store_sticker_set(const StickerSet *sticker_set, bool with_stickers, StorerT &storer,
                                        const char *source) const {
  size_t stickers_limit =
      with_stickers ? sticker_set->sticker_ids_.size() : get_max_featured_sticker_count(sticker_set->sticker_type_);
  bool is_full = sticker_set->sticker_ids_.size() <= stickers_limit;
  bool was_loaded = sticker_set->was_loaded_ && is_full;
  bool is_loaded = sticker_set->is_loaded_ && is_full;
  bool has_expires_at = !sticker_set->is_installed_ && sticker_set->expires_at_ != 0;
  bool has_thumbnail = sticker_set->thumbnail_.file_id.is_valid();
  bool has_minithumbnail = !sticker_set->minithumbnail_.empty();
  bool is_masks = sticker_set->sticker_type_ == StickerType::Mask;
  bool is_emojis = sticker_set->sticker_type_ == StickerType::CustomEmoji;
  bool has_thumbnail_document_id = sticker_set->thumbnail_document_id_ != 0;
  bool is_mixed_format = true;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(sticker_set->is_inited_);
  STORE_FLAG(was_loaded);
  STORE_FLAG(is_loaded);
  STORE_FLAG(sticker_set->is_installed_);
  STORE_FLAG(sticker_set->is_archived_);
  STORE_FLAG(sticker_set->is_official_);  // 5
  STORE_FLAG(is_masks);
  STORE_FLAG(sticker_set->is_viewed_);
  STORE_FLAG(has_expires_at);
  STORE_FLAG(has_thumbnail);
  STORE_FLAG(sticker_set->is_thumbnail_reloaded_);  // 10
  STORE_FLAG(false);
  STORE_FLAG(sticker_set->are_legacy_sticker_thumbnails_reloaded_);
  STORE_FLAG(has_minithumbnail);
  STORE_FLAG(false);
  STORE_FLAG(is_emojis);  // 15
  STORE_FLAG(has_thumbnail_document_id);
  STORE_FLAG(sticker_set->are_keywords_loaded_);
  STORE_FLAG(sticker_set->is_sticker_has_text_color_loaded_);
  STORE_FLAG(sticker_set->has_text_color_);
  STORE_FLAG(sticker_set->is_sticker_channel_emoji_status_loaded_);  // 20
  STORE_FLAG(sticker_set->channel_emoji_status_);
  STORE_FLAG(is_mixed_format);
  STORE_FLAG(sticker_set->is_created_);
  STORE_FLAG(sticker_set->is_created_loaded_);
  END_STORE_FLAGS();
  store(sticker_set->id_.get(), storer);
  store(sticker_set->access_hash_, storer);
  if (sticker_set->is_inited_) {
    store(sticker_set->title_, storer);
    store(sticker_set->short_name_, storer);
    store(sticker_set->sticker_count_, storer);
    store(sticker_set->hash_, storer);
    if (has_expires_at) {
      store(sticker_set->expires_at_, storer);
    }
    if (has_thumbnail) {
      store(sticker_set->thumbnail_, storer);
    }
    if (has_minithumbnail) {
      store(sticker_set->minithumbnail_, storer);
    }
    if (has_thumbnail_document_id) {
      store(sticker_set->thumbnail_document_id_, storer);
    }

    auto stored_sticker_count = narrow_cast<uint32>(is_full ? sticker_set->sticker_ids_.size() : stickers_limit);
    store(stored_sticker_count, storer);
    for (uint32 i = 0; i < stored_sticker_count; i++) {
      auto sticker_id = sticker_set->sticker_ids_[i];
      store_sticker(sticker_id, true, storer, source);

      if (was_loaded) {
        auto it = sticker_set->sticker_emojis_map_.find(sticker_id);
        if (it != sticker_set->sticker_emojis_map_.end()) {
          store(it->second, storer);
        } else {
          store(vector<string>(), storer);
        }
      }
      if (sticker_set->are_keywords_loaded_) {
        auto it = sticker_set->sticker_keywords_map_.find(sticker_id);
        if (it != sticker_set->sticker_keywords_map_.end()) {
          store(it->second, storer);
        } else {
          store(vector<string>(), storer);
        }
      }
    }
  }
}

template <class ParserT>
void StickersManager::parse_sticker_set(StickerSet *sticker_set, ParserT &parser) {
  CHECK(sticker_set != nullptr);
  CHECK(!sticker_set->was_loaded_);
  bool was_inited = sticker_set->is_inited_;
  bool is_installed;
  bool is_archived;
  bool is_official;
  bool is_masks;
  bool has_expires_at;
  bool has_thumbnail;
  bool legacy_is_tgs;
  bool has_minithumbnail;
  bool legacy_is_webm;
  bool is_emojis;
  bool has_thumbnail_document_id;
  bool has_text_color;
  bool channel_emoji_status;
  bool is_mixed_format;
  bool is_created;
  bool is_created_loaded;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(sticker_set->is_inited_);
  PARSE_FLAG(sticker_set->was_loaded_);
  PARSE_FLAG(sticker_set->is_loaded_);
  PARSE_FLAG(is_installed);
  PARSE_FLAG(is_archived);
  PARSE_FLAG(is_official);
  PARSE_FLAG(is_masks);
  PARSE_FLAG(sticker_set->is_viewed_);
  PARSE_FLAG(has_expires_at);
  PARSE_FLAG(has_thumbnail);
  PARSE_FLAG(sticker_set->is_thumbnail_reloaded_);
  PARSE_FLAG(legacy_is_tgs);
  PARSE_FLAG(sticker_set->are_legacy_sticker_thumbnails_reloaded_);
  PARSE_FLAG(has_minithumbnail);
  PARSE_FLAG(legacy_is_webm);
  PARSE_FLAG(is_emojis);
  PARSE_FLAG(has_thumbnail_document_id);
  PARSE_FLAG(sticker_set->are_keywords_loaded_);
  PARSE_FLAG(sticker_set->is_sticker_has_text_color_loaded_);
  PARSE_FLAG(has_text_color);
  PARSE_FLAG(sticker_set->is_sticker_channel_emoji_status_loaded_);
  PARSE_FLAG(channel_emoji_status);
  PARSE_FLAG(is_mixed_format);
  PARSE_FLAG(is_created);
  PARSE_FLAG(is_created_loaded);
  END_PARSE_FLAGS();
  int64 sticker_set_id;
  int64 access_hash;
  parse(sticker_set_id, parser);
  parse(access_hash, parser);
  if (sticker_set->id_.get() != sticker_set_id) {
    return parser.set_error("Invalid sticker set data stored in the database");
  }
  (void)access_hash;  // unused, because only known sticker sets with access hash can be loaded from database

  auto sticker_type = ::td::get_sticker_type(is_masks, is_emojis);
  if (!is_emojis) {
    sticker_set->is_sticker_has_text_color_loaded_ = true;
    sticker_set->is_sticker_channel_emoji_status_loaded_ = true;
  }

  if (sticker_set->is_inited_) {
    string title;
    string short_name;
    string minithumbnail;
    PhotoSize thumbnail;
    int64 thumbnail_document_id = 0;
    int32 sticker_count;
    int32 hash;
    int32 expires_at = 0;
    parse(title, parser);
    parse(short_name, parser);
    parse(sticker_count, parser);
    parse(hash, parser);
    if (has_expires_at) {
      parse(expires_at, parser);
    }
    if (has_thumbnail) {
      parse(thumbnail, parser);
    }
    if (has_minithumbnail) {
      parse(minithumbnail, parser);
    }
    if (has_thumbnail_document_id) {
      parse(thumbnail_document_id, parser);
    }
    if (!is_mixed_format && thumbnail.file_id.is_valid()) {
      if (legacy_is_webm) {
        thumbnail.type = PhotoSizeType('v');
      } else if (legacy_is_tgs) {
        thumbnail.type = PhotoSizeType('a');
      } else {
        thumbnail.type = PhotoSizeType('s');
      }
    }
    if (!was_inited) {
      sticker_set->title_ = std::move(title);
      sticker_set->short_name_ = std::move(short_name);
      sticker_set->minithumbnail_ = std::move(minithumbnail);
      sticker_set->thumbnail_ = std::move(thumbnail);
      sticker_set->thumbnail_document_id_ = thumbnail_document_id;
      sticker_set->sticker_count_ = sticker_count;
      sticker_set->hash_ = hash;
      sticker_set->expires_at_ = expires_at;
      sticker_set->is_official_ = is_official;
      sticker_set->sticker_type_ = sticker_type;
      sticker_set->has_text_color_ = has_text_color;
      sticker_set->channel_emoji_status_ = channel_emoji_status;
      sticker_set->is_created_ = is_created;
      sticker_set->is_created_loaded_ = is_created_loaded;

      auto cleaned_username = clean_username(sticker_set->short_name_);
      if (!cleaned_username.empty()) {
        short_name_to_sticker_set_id_.set(cleaned_username, sticker_set->id_);
      }
      on_update_sticker_set(sticker_set, is_installed, is_archived, false, true);
    } else {
      if (sticker_set->title_ != title || sticker_set->minithumbnail_ != minithumbnail ||
          sticker_set->thumbnail_ != thumbnail || sticker_set->thumbnail_document_id_ != thumbnail_document_id ||
          sticker_set->is_official_ != is_official || sticker_set->has_text_color_ != has_text_color ||
          sticker_set->channel_emoji_status_ != channel_emoji_status || sticker_set->is_created_ != is_created ||
          sticker_set->is_created_loaded_ != is_created_loaded) {
        sticker_set->is_changed_ = true;
      }
      if (sticker_set->short_name_ != short_name) {
        LOG(INFO) << "Short name of " << sticker_set->id_ << " has changed from \"" << short_name << "\" to \""
                  << sticker_set->short_name_ << "\"";
        sticker_set->is_changed_ = true;
      }
      if (sticker_set->is_loaded_ && (sticker_set->sticker_count_ != sticker_count || sticker_set->hash_ != hash)) {
        sticker_set->is_loaded_ = false;
        sticker_set->is_changed_ = true;
      }
      if (sticker_set->sticker_type_ != sticker_type) {
        LOG(ERROR) << "Type of " << sticker_set->id_ << " has changed from \"" << sticker_type << "\" to \""
                   << sticker_set->sticker_type_ << "\"";
      }
    }

    uint32 stored_sticker_count;
    parse(stored_sticker_count, parser);
    sticker_set->sticker_ids_.clear();
    sticker_set->premium_sticker_positions_.clear();
    if (sticker_set->was_loaded_) {
      sticker_set->emoji_stickers_map_.clear();
      sticker_set->sticker_emojis_map_.clear();
      sticker_set->keyword_stickers_map_.clear();
      sticker_set->sticker_keywords_map_.clear();
    }
    for (uint32 i = 0; i < stored_sticker_count; i++) {
      auto sticker_id = parse_sticker(true, parser);
      if (parser.get_error() != nullptr) {
        return;
      }
      if (!sticker_id.is_valid()) {
        return parser.set_error("Receive invalid sticker in a sticker set");
      }
      sticker_set->sticker_ids_.push_back(sticker_id);

      Sticker *sticker = get_sticker(sticker_id);
      CHECK(sticker != nullptr);
      if (sticker->set_id_ != sticker_set->id_) {
        LOG_IF(ERROR, sticker->set_id_.is_valid()) << "Sticker " << sticker_id << " set_id has changed";
        sticker->set_id_ = sticker_set->id_;
        if (sticker->has_text_color_) {
          sticker_set->has_text_color_ = true;
        }
      }
      if (sticker->is_premium_) {
        sticker_set->premium_sticker_positions_.push_back(static_cast<int32>(sticker_set->sticker_ids_.size() - 1));
      }

      if (sticker_set->was_loaded_) {
        vector<string> emojis;
        parse(emojis, parser);
        for (auto &emoji : emojis) {
          auto cleaned_emoji = remove_emoji_modifiers(emoji);
          if (!cleaned_emoji.empty()) {
            auto &sticker_ids = sticker_set->emoji_stickers_map_[cleaned_emoji];
            if (sticker_ids.empty() || sticker_ids.back() != sticker_id) {
              sticker_ids.push_back(sticker_id);
            }
          } else {
            LOG(INFO) << "Sticker " << sticker_id << " in " << sticker_set_id << '/' << sticker_set->short_name_
                      << " has an empty emoji";
          }
        }
        sticker_set->sticker_emojis_map_[sticker_id] = std::move(emojis);
      }
      if (sticker_set->are_keywords_loaded_) {
        vector<string> keywords;
        parse(keywords, parser);
        if (!keywords.empty()) {
          sticker_set->sticker_keywords_map_.emplace(sticker_id, std::move(keywords));
        }
      }
    }
    if (expires_at > sticker_set->expires_at_) {
      sticker_set->expires_at_ = expires_at;
    }

    if (!check_utf8(sticker_set->title_)) {
      return parser.set_error("Have invalid sticker set title");
    }
    if (!check_utf8(sticker_set->short_name_)) {
      return parser.set_error("Have invalid sticker set name");
    }
  }
}

template <class StorerT>
void StickersManager::store_sticker_set_id(StickerSetId sticker_set_id, StorerT &storer) const {
  CHECK(sticker_set_id.is_valid());
  const StickerSet *sticker_set = get_sticker_set(sticker_set_id);
  CHECK(sticker_set != nullptr);
  store(sticker_set_id.get(), storer);
  store(sticker_set->access_hash_, storer);
}

template <class ParserT>
void StickersManager::parse_sticker_set_id(StickerSetId &sticker_set_id, ParserT &parser) {
  int64 set_id;
  parse(set_id, parser);
  sticker_set_id = StickerSetId(set_id);
  int64 sticker_set_access_hash;
  parse(sticker_set_access_hash, parser);
  add_sticker_set(sticker_set_id, sticker_set_access_hash);
}

}  // namespace td
