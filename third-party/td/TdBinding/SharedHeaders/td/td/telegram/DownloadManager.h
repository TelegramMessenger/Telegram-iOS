//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileSourceId.h"
#include "td/telegram/td_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class DownloadManager : public Actor {
 public:
  struct Counters {
    int64 total_size{};
    int32 total_count{};
    int64 downloaded_size{};

    bool operator==(const Counters &other) const {
      return total_size == other.total_size && total_count == other.total_count &&
             downloaded_size == other.downloaded_size;
    }

    td_api::object_ptr<td_api::updateFileDownloads> get_update_file_downloads_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct FileCounters {
    int32 active_count{};
    int32 paused_count{};
    int32 completed_count{};

    bool operator==(const FileCounters &other) const {
      return active_count == other.active_count && paused_count == other.paused_count &&
             completed_count == other.completed_count;
    }

    td_api::object_ptr<td_api::downloadedFileCounts> get_downloaded_file_counts_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  // Callback is needed to make DownloadManager testable
  class Callback {
   public:
    virtual ~Callback() = default;
    virtual void update_counters(Counters counters) = 0;
    virtual void update_file_added(FileId file_id, FileSourceId file_source_id, int32 add_date, int32 complete_date,
                                   bool is_paused, FileCounters counters) = 0;
    virtual void update_file_changed(FileId file_id, int32 complete_date, bool is_paused, FileCounters counters) = 0;
    virtual void update_file_removed(FileId file_id, FileCounters counters) = 0;
    virtual int64 get_internal_download_id() = 0;
    virtual void start_file(FileId file_id, int64 internal_download_id, int8 priority,
                            ActorShared<DownloadManager> download_manager) = 0;
    virtual void pause_file(FileId file_id, int64 internal_download_id) = 0;
    virtual void delete_file(FileId file_id) = 0;

    virtual void get_file_search_text(FileId file_id, FileSourceId file_source_id, Promise<string> &&promise) = 0;

    virtual FileView get_sync_file_view(FileId file_id) = 0;
    virtual td_api::object_ptr<td_api::file> get_file_object(FileId file_id) = 0;
    virtual td_api::object_ptr<td_api::fileDownload> get_file_download_object(FileId file_id,
                                                                              FileSourceId file_source_id,
                                                                              int32 add_date, int32 complete_date,
                                                                              bool is_paused) = 0;
  };

  static unique_ptr<DownloadManager> create(unique_ptr<Callback> callback);

  //
  // public interface for user
  //
  virtual void add_file(FileId file_id, FileSourceId file_source_id, string search_text, int8 priority,
                        Promise<td_api::object_ptr<td_api::file>> promise) = 0;
  virtual void toggle_is_paused(FileId file_id, bool is_paused, Promise<Unit> promise) = 0;
  virtual void toggle_all_is_paused(bool is_paused, Promise<Unit> promise) = 0;
  virtual void search(string query, bool only_active, bool only_completed, string offset, int32 limit,
                      Promise<td_api::object_ptr<td_api::foundFileDownloads>> promise) = 0;
  virtual void remove_file(FileId file_id, FileSourceId file_source_id, bool delete_from_cache,
                           Promise<Unit> promise) = 0;
  virtual void remove_all_files(bool only_active, bool only_completed, bool delete_from_cache,
                                Promise<Unit> promise) = 0;

  //
  // private interface to handle all kinds of updates
  //
  virtual void after_get_difference() = 0;
  virtual void change_search_text(FileId file_id, FileSourceId file_source_id, string search_text) = 0;
  virtual void remove_file_if_finished(FileId file_id) = 0;
  virtual void update_file_download_state(FileId file_id, int64 downloaded_size, int64 size, int64 expected_size,
                                          bool is_paused) = 0;
  virtual void update_file_viewed(FileId file_id, FileSourceId file_source_id) = 0;
};

}  // namespace td
