//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Dimensions.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/WaitFreeHashMap.h"

namespace td {

class Td;

class VideosManager {
 public:
  explicit VideosManager(Td *td);
  VideosManager(const VideosManager &) = delete;
  VideosManager &operator=(const VideosManager &) = delete;
  VideosManager(VideosManager &&) = delete;
  VideosManager &operator=(VideosManager &&) = delete;
  ~VideosManager();

  int32 get_video_duration(FileId file_id) const;

  td_api::object_ptr<td_api::video> get_video_object(FileId file_id) const;

  td_api::object_ptr<td_api::storyVideo> get_story_video_object(FileId file_id) const;

  td_api::object_ptr<td_api::alternativeVideo> get_alternative_video_object(FileId file_id,
                                                                            const vector<FileId> &hls_file_ids) const;

  void create_video(FileId file_id, string minithumbnail, PhotoSize thumbnail, AnimationSize animated_thumbnail,
                    bool has_stickers, vector<FileId> &&sticker_file_ids, string file_name, string mime_type,
                    int32 duration, double precise_duration, Dimensions dimensions, bool supports_streaming,
                    bool is_animation, int32 preload_prefix_size, double start_ts, string &&codec, bool replace);

  tl_object_ptr<telegram_api::InputMedia> get_input_media(
      FileId file_id, telegram_api::object_ptr<telegram_api::InputFile> input_file,
      telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail, const Photo &cover, int32 start_timestamp,
      int32 ttl, bool has_spoiler) const;

  telegram_api::object_ptr<telegram_api::InputMedia> get_story_document_input_media(FileId file_id,
                                                                                    double main_frame_timestamp) const;

  SecretInputMedia get_secret_input_media(FileId video_file_id,
                                          telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
                                          const string &caption, BufferSlice thumbnail, int32 layer) const;

  FileId get_video_thumbnail_file_id(FileId file_id) const;

  FileId get_video_animated_thumbnail_file_id(FileId file_id) const;

  void delete_video_thumbnail(FileId file_id);

  FileId dup_video(FileId new_id, FileId old_id);

  void merge_videos(FileId new_id, FileId old_id);

  template <class StorerT>
  void store_video(FileId file_id, StorerT &storer) const;

  template <class ParserT>
  FileId parse_video(ParserT &parser);

  string get_video_search_text(FileId file_id) const;

 private:
  class Video {
   public:
    string file_name;
    string mime_type;
    int32 duration = 0;
    double precise_duration = 0;
    Dimensions dimensions;
    string minithumbnail;
    PhotoSize thumbnail;
    AnimationSize animated_thumbnail;
    int32 preload_prefix_size = 0;
    double start_ts = 0.0;
    string codec;

    bool supports_streaming = false;
    bool is_animation = false;

    bool has_stickers = false;
    vector<FileId> sticker_file_ids;

    FileId file_id;
  };

  const Video *get_video(FileId file_id) const;

  FileId on_get_video(unique_ptr<Video> new_video, bool replace);

  Td *td_;
  WaitFreeHashMap<FileId, unique_ptr<Video>, FileIdHash> videos_;
};

}  // namespace td
