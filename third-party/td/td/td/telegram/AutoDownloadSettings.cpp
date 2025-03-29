//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AutoDownloadSettings.h"

#include "td/telegram/Global.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Status.h"

namespace td {

static td_api::object_ptr<td_api::autoDownloadSettings> convert_auto_download_settings(
    const telegram_api::object_ptr<telegram_api::autoDownloadSettings> &settings) {
  CHECK(settings != nullptr);
  auto flags = settings->flags_;
  auto disabled = (flags & telegram_api::autoDownloadSettings::DISABLED_MASK) != 0;
  auto video_preload_large = (flags & telegram_api::autoDownloadSettings::VIDEO_PRELOAD_LARGE_MASK) != 0;
  auto audio_preload_next = (flags & telegram_api::autoDownloadSettings::AUDIO_PRELOAD_NEXT_MASK) != 0;
  auto stories_preload = (flags & telegram_api::autoDownloadSettings::STORIES_PRELOAD_MASK) != 0;
  auto phonecalls_less_data = (flags & telegram_api::autoDownloadSettings::PHONECALLS_LESS_DATA_MASK) != 0;
  constexpr int32 MAX_PHOTO_SIZE = 10 * (1 << 20) /* 10 MB */;
  constexpr int64 MAX_DOCUMENT_SIZE = (static_cast<int64>(1) << 52);
  return td_api::make_object<td_api::autoDownloadSettings>(
      !disabled, clamp(settings->photo_size_max_, static_cast<int32>(0), MAX_PHOTO_SIZE),
      clamp(settings->video_size_max_, static_cast<int64>(0), MAX_DOCUMENT_SIZE),
      clamp(settings->file_size_max_, static_cast<int64>(0), MAX_DOCUMENT_SIZE), settings->video_upload_maxbitrate_,
      video_preload_large, audio_preload_next, stories_preload, phonecalls_less_data);
}

class GetAutoDownloadSettingsQuery final : public Td::ResultHandler {
  Promise<td_api::object_ptr<td_api::autoDownloadSettingsPresets>> promise_;

 public:
  explicit GetAutoDownloadSettingsQuery(Promise<td_api::object_ptr<td_api::autoDownloadSettingsPresets>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send() {
    send_query(G()->net_query_creator().create(telegram_api::account_getAutoDownloadSettings()));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_getAutoDownloadSettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    auto settings = result_ptr.move_as_ok();
    promise_.set_value(td_api::make_object<td_api::autoDownloadSettingsPresets>(
        convert_auto_download_settings(settings->low_), convert_auto_download_settings(settings->medium_),
        convert_auto_download_settings(settings->high_)));
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

static telegram_api::object_ptr<telegram_api::autoDownloadSettings> get_input_auto_download_settings(
    const AutoDownloadSettings &settings) {
  int32 flags = 0;
  if (!settings.is_enabled) {
    flags |= telegram_api::autoDownloadSettings::DISABLED_MASK;
  }
  if (settings.preload_large_videos) {
    flags |= telegram_api::autoDownloadSettings::VIDEO_PRELOAD_LARGE_MASK;
  }
  if (settings.preload_next_audio) {
    flags |= telegram_api::autoDownloadSettings::AUDIO_PRELOAD_NEXT_MASK;
  }
  if (settings.preload_stories) {
    flags |= telegram_api::autoDownloadSettings::STORIES_PRELOAD_MASK;
  }
  if (settings.use_less_data_for_calls) {
    flags |= telegram_api::autoDownloadSettings::PHONECALLS_LESS_DATA_MASK;
  }
  return telegram_api::make_object<telegram_api::autoDownloadSettings>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      settings.max_photo_file_size, settings.max_video_file_size, settings.max_other_file_size,
      settings.video_upload_bitrate, 0, 0);
}

class SaveAutoDownloadSettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SaveAutoDownloadSettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(NetType type, const AutoDownloadSettings &settings) {
    int32 flags = 0;
    if (type == NetType::MobileRoaming) {
      flags |= telegram_api::account_saveAutoDownloadSettings::LOW_MASK;
    }
    if (type == NetType::WiFi) {
      flags |= telegram_api::account_saveAutoDownloadSettings::HIGH_MASK;
    }
    send_query(G()->net_query_creator().create(telegram_api::account_saveAutoDownloadSettings(
        flags, false /*ignored*/, false /*ignored*/, get_input_auto_download_settings(settings))));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::account_saveAutoDownloadSettings>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    LOG(INFO) << "Receive result for SaveAutoDownloadSettingsQuery: " << result_ptr.ok();
    promise_.set_value(Unit());
  }

  void on_error(Status status) final {
    promise_.set_error(std::move(status));
  }
};

AutoDownloadSettings get_auto_download_settings(const td_api::object_ptr<td_api::autoDownloadSettings> &settings) {
  CHECK(settings != nullptr);
  AutoDownloadSettings result;
  result.max_photo_file_size = settings->max_photo_file_size_;
  result.max_video_file_size = settings->max_video_file_size_;
  result.max_other_file_size = settings->max_other_file_size_;
  result.video_upload_bitrate = settings->video_upload_bitrate_;
  result.is_enabled = settings->is_auto_download_enabled_;
  result.preload_large_videos = settings->preload_large_videos_;
  result.preload_next_audio = settings->preload_next_audio_;
  result.preload_stories = settings->preload_stories_;
  result.use_less_data_for_calls = settings->use_less_data_for_calls_;
  return result;
}

void get_auto_download_settings_presets(Td *td,
                                        Promise<td_api::object_ptr<td_api::autoDownloadSettingsPresets>> &&promise) {
  td->create_handler<GetAutoDownloadSettingsQuery>(std::move(promise))->send();
}

void set_auto_download_settings(Td *td, NetType type, AutoDownloadSettings settings, Promise<Unit> &&promise) {
  td->create_handler<SaveAutoDownloadSettingsQuery>(std::move(promise))->send(type, settings);
}

}  // namespace td
