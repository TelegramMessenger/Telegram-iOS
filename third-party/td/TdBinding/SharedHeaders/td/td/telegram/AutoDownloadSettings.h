//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetType.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class AutoDownloadSettings {
 public:
  int32 max_photo_file_size = 0;
  int64 max_video_file_size = 0;
  int64 max_other_file_size = 0;
  int32 video_upload_bitrate = 0;
  bool is_enabled = false;
  bool preload_large_videos = false;
  bool preload_next_audio = false;
  bool preload_stories = false;
  bool use_less_data_for_calls = false;
};

AutoDownloadSettings get_auto_download_settings(const td_api::object_ptr<td_api::autoDownloadSettings> &settings);

void get_auto_download_settings_presets(Td *td,
                                        Promise<td_api::object_ptr<td_api::autoDownloadSettingsPresets>> &&promise);

void set_auto_download_settings(Td *td, NetType type, AutoDownloadSettings settings, Promise<Unit> &&promise);

}  // namespace td
