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
  constexpr int32 MAX_PHOTO_SIZE = 10 * (1 << 20) /* 10 MB */;
  constexpr int64 MAX_DOCUMENT_SIZE = (static_cast<int64>(1) << 52);
  return td_api::make_object<td_api::autoDownloadSettings>(
      !settings->disabled_, clamp(settings->photo_size_max_, static_cast<int32>(0), MAX_PHOTO_SIZE),
      clamp(settings->video_size_max_, static_cast<int64>(0), MAX_DOCUMENT_SIZE),
      clamp(settings->file_size_max_, static_cast<int64>(0), MAX_DOCUMENT_SIZE), settings->video_upload_maxbitrate_,
      settings->video_preload_large_, settings->audio_preload_next_, settings->stories_preload_,
      settings->phonecalls_less_data_);
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
  return telegram_api::make_object<telegram_api::autoDownloadSettings>(
      0, !settings.is_enabled, settings.preload_large_videos, settings.preload_next_audio,
      settings.use_less_data_for_calls, settings.preload_stories, settings.max_photo_file_size,
      settings.max_video_file_size, settings.max_other_file_size, settings.video_upload_bitrate, 0, 0);
}

class SaveAutoDownloadSettingsQuery final : public Td::ResultHandler {
  Promise<Unit> promise_;

 public:
  explicit SaveAutoDownloadSettingsQuery(Promise<Unit> &&promise) : promise_(std::move(promise)) {
  }

  void send(NetType type, const AutoDownloadSettings &settings) {
    send_query(G()->net_query_creator().create(telegram_api::account_saveAutoDownloadSettings(
        0, type == NetType::MobileRoaming, type == NetType::WiFi, get_input_auto_download_settings(settings))));
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
