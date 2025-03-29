//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DownloadManagerCallback.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/Td.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

void DownloadManagerCallback::update_counters(DownloadManager::Counters counters) {
  if (!td_->auth_manager_->is_bot()) {
    send_closure(td_->actor_id(td_), &Td::send_update, counters.get_update_file_downloads_object());
  }
}

void DownloadManagerCallback::update_file_added(FileId file_id, FileSourceId file_source_id, int32 add_date,
                                                int32 complete_date, bool is_paused,
                                                DownloadManager::FileCounters counters) {
  send_closure(td_->actor_id(td_), &Td::send_update,
               td_api::make_object<td_api::updateFileAddedToDownloads>(
                   get_file_download_object(file_id, file_source_id, add_date, complete_date, is_paused),
                   counters.get_downloaded_file_counts_object()));
}

void DownloadManagerCallback::update_file_changed(FileId file_id, int32 complete_date, bool is_paused,
                                                  DownloadManager::FileCounters counters) {
  send_closure(td_->actor_id(td_), &Td::send_update,
               td_api::make_object<td_api::updateFileDownload>(file_id.get(), complete_date, is_paused,
                                                               counters.get_downloaded_file_counts_object()));
}

void DownloadManagerCallback::update_file_removed(FileId file_id, DownloadManager::FileCounters counters) {
  send_closure(td_->actor_id(td_), &Td::send_update,
               td_api::make_object<td_api::updateFileRemovedFromDownloads>(
                   file_id.get(), counters.get_downloaded_file_counts_object()));
}

int64 DownloadManagerCallback::get_internal_download_id() {
  return FileManager::get_internal_download_id();
}

void DownloadManagerCallback::start_file(FileId file_id, int64 internal_download_id, int8 priority,
                                         ActorShared<DownloadManager> download_manager) {
  send_closure_later(td_->file_manager_actor_, &FileManager::download, file_id, internal_download_id,
                     make_download_file_callback(td_, std::move(download_manager)), priority, -1, -1,
                     Promise<td_api::object_ptr<td_api::file>>());
}

void DownloadManagerCallback::pause_file(FileId file_id, int64 internal_download_id) {
  send_closure_later(td_->file_manager_actor_, &FileManager::cancel_download, file_id, internal_download_id, false);
}

void DownloadManagerCallback::delete_file(FileId file_id) {
  send_closure_later(td_->file_manager_actor_, &FileManager::delete_file, file_id, Promise<Unit>(),
                     "download manager callback");
}

void DownloadManagerCallback::get_file_search_text(FileId file_id, FileSourceId file_source_id,
                                                   Promise<string> &&promise) {
  send_closure(td_->file_reference_manager_actor_, &FileReferenceManager::get_file_search_text, file_source_id,
               get_file_view(file_id).get_unique_file_id(), std::move(promise));
}

FileView DownloadManagerCallback::get_file_view(FileId file_id) {
  return td_->file_manager_->get_file_view(file_id);
}

FileView DownloadManagerCallback::get_sync_file_view(FileId file_id) {
  td_->file_manager_->check_local_location(file_id, true);
  return get_file_view(file_id);
}

td_api::object_ptr<td_api::file> DownloadManagerCallback::get_file_object(FileId file_id) {
  return td_->file_manager_->get_file_object(file_id);
}

td_api::object_ptr<td_api::fileDownload> DownloadManagerCallback::get_file_download_object(
    FileId file_id, FileSourceId file_source_id, int32 add_date, int32 complete_date, bool is_paused) {
  return td_api::make_object<td_api::fileDownload>(td_->file_manager_->get_file_view(file_id).get_main_file_id().get(),
                                                   td_->file_reference_manager_->get_message_object(file_source_id),
                                                   add_date, complete_date, is_paused);
}

std::shared_ptr<FileManager::DownloadCallback> DownloadManagerCallback::make_download_file_callback(
    Td *td, ActorShared<DownloadManager> download_manager) {
  class Impl final : public FileManager::DownloadCallback {
   public:
    Impl(Td *td, ActorShared<DownloadManager> download_manager)
        : td_(td), download_manager_(std::move(download_manager)) {
    }
    void on_progress(FileId file_id) final {
      send_update(file_id, false);
    }
    void on_download_ok(FileId file_id) final {
      send_update(file_id, false);
    }
    void on_download_error(FileId file_id, Status error) final {
      send_update(file_id, true);
    }

   private:
    Td *td_;
    ActorShared<DownloadManager> download_manager_;

    void send_update(FileId file_id, bool is_paused) const {
      auto file_view = td_->file_manager_->get_file_view(file_id);
      send_closure_later(download_manager_, &DownloadManager::update_file_download_state, file_id,
                         file_view.local_total_size(), file_view.size(), file_view.expected_size(), is_paused);
    }
  };
  return std::make_shared<Impl>(td, std::move(download_manager));
}

}  // namespace td
