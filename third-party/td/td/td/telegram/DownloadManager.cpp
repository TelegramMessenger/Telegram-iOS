//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DownloadManager.h"

#include "td/telegram/files/FileId.hpp"
#include "td/telegram/files/FileSourceId.hpp"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/TdDb.h"

#include "td/actor/MultiPromise.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/algorithm.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Hints.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

#include <algorithm>
#include <functional>
#include <limits>
#include <set>

namespace td {

struct FileDownloadInDatabase {
  int64 download_id{};
  FileId file_id;
  FileSourceId file_source_id;
  int32 priority{};
  int32 created_at{};
  int32 completed_at{};
  bool is_paused{};

  template <class StorerT>
  void store(StorerT &storer) const {
    BEGIN_STORE_FLAGS();
    STORE_FLAG(is_paused);
    END_STORE_FLAGS();
    td::store(download_id, storer);
    td::store(file_id, storer);
    td::store(file_source_id, storer);
    td::store(priority, storer);
    td::store(created_at, storer);
    td::store(completed_at, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(is_paused);
    END_PARSE_FLAGS();
    td::parse(download_id, parser);
    td::parse(file_id, parser);
    td::parse(file_source_id, parser);
    td::parse(priority, parser);
    td::parse(created_at, parser);
    td::parse(completed_at, parser);
  }
};

class DownloadManagerImpl final : public DownloadManager {
 public:
  explicit DownloadManagerImpl(unique_ptr<Callback> callback) : callback_(std::move(callback)) {
  }

  void start_up() final {
    init();
  }

  void after_get_difference() final {
    load_database_files("after_get_difference");
  }

  void toggle_is_paused(FileId file_id, bool is_paused, Promise<Unit> promise) final {
    TRY_STATUS_PROMISE(promise, check_is_active("toggle_is_paused"));
    TRY_RESULT_PROMISE(promise, file_info_ptr, get_file_info_ptr(file_id));
    toggle_is_paused(*file_info_ptr, is_paused);
    promise.set_value(Unit());
  }

  void toggle_all_is_paused(bool is_paused, Promise<Unit> promise) final {
    TRY_STATUS_PROMISE(promise, check_is_active("toggle_all_is_paused"));

    vector<FileId> to_toggle;
    for (const auto &it : files_) {
      const FileInfo &file_info = *it.second;
      if (!is_completed(file_info) && is_paused != file_info.is_paused) {
        to_toggle.push_back(file_info.file_id);
      }
    }
    for (auto file_id : to_toggle) {
      auto r_file_info_ptr = get_file_info_ptr(file_id);
      if (r_file_info_ptr.is_ok()) {
        toggle_is_paused(*r_file_info_ptr.ok(), is_paused);
      }
    }

    promise.set_value(Unit());
  }

  void remove_file(FileId file_id, FileSourceId file_source_id, bool delete_from_cache, Promise<Unit> promise) final {
    TRY_STATUS_PROMISE(promise, check_is_active("remove_file"));
    TRY_RESULT_PROMISE(promise, file_info_ptr, get_file_info_ptr(file_id, file_source_id));
    remove_file_impl(*file_info_ptr, delete_from_cache, "remove_file");
    promise.set_value(Unit());
  }

  void remove_file_if_finished(FileId file_id) final {
    remove_file_if_finished_impl(file_id).ignore();
  }

  void remove_all_files(bool only_active, bool only_completed, bool delete_from_cache, Promise<Unit> promise) final {
    TRY_STATUS_PROMISE(promise, check_is_active("remove_all_files"));
    vector<const FileInfo *> to_remove;
    for (const auto &it : files_) {
      const FileInfo &file_info = *it.second;
      if (only_active && is_completed(file_info)) {
        continue;
      }
      if (only_completed && !is_completed(file_info)) {
        continue;
      }
      to_remove.push_back(&file_info);
    }
    for (auto file_info_ptr : to_remove) {
      remove_file_impl(*file_info_ptr, delete_from_cache, "remove_all_files");
    }
    promise.set_value(Unit());
  }

  void add_file(FileId file_id, FileSourceId file_source_id, string search_text, int8 priority,
                Promise<td_api::object_ptr<td_api::file>> promise) final {
    TRY_STATUS_PROMISE(promise, check_is_active("add_file"));

    auto old_file_info_ptr = get_file_info_ptr(file_id);
    if (old_file_info_ptr.is_ok()) {
      remove_file_impl(*old_file_info_ptr.ok(), false, "add_file");
    }

    auto download_id = next_download_id();

    auto file_info = make_unique<FileInfo>();
    file_info->download_id = download_id;
    file_info->file_id = file_id;
    file_info->file_source_id = file_source_id;
    file_info->is_paused = false;
    file_info->priority = priority;
    file_info->created_at = G()->unix_time();
    file_info->need_save_to_database = true;

    add_file_info(std::move(file_info), search_text);

    promise.set_value(callback_->get_file_object(file_id));
  }

  void change_search_text(FileId file_id, FileSourceId file_source_id, string search_text) final {
    if (!is_search_inited_) {
      return;
    }

    if (check_is_active("change_search_text").is_error()) {
      return;
    }
    auto r_file_info_ptr = get_file_info_ptr(file_id, file_source_id);
    if (r_file_info_ptr.is_error()) {
      return;
    }
    auto &file_info = *r_file_info_ptr.ok();
    hints_.add(file_info.download_id, search_text.empty() ? string(" ") : search_text);
  }

  void hints_synchronized(Result<Unit>) {
    if (G()->close_flag()) {
      return;
    }

    LOG(INFO) << "DownloadManager: hints are synchronized";
    is_search_inited_ = true;
  }

  void search(string query, bool only_active, bool only_completed, string offset, int32 limit,
              Promise<td_api::object_ptr<td_api::foundFileDownloads>> promise) final {
    return do_search(std::move(query), only_active, only_completed, std::move(offset), limit, std::move(promise),
                     Unit{});
  }

  void do_search(string query, bool only_active, bool only_completed, string offset, int32 limit,
                 Promise<td_api::object_ptr<td_api::foundFileDownloads>> promise, Result<Unit>) {
    TRY_STATUS_PROMISE(promise, G()->close_status());
    TRY_STATUS_PROMISE(promise, check_is_active("do_search"));

    if (!is_search_inited_) {
      Promise<Unit> lock;
      if (load_search_text_multipromise_.promise_count() == 0) {
        load_search_text_multipromise_.add_promise(
            promise_send_closure(actor_id(this), &DownloadManagerImpl::hints_synchronized));
        load_search_text_multipromise_.set_ignore_errors(true);
        lock = load_search_text_multipromise_.get_promise();
        prepare_hints();
      }
      load_search_text_multipromise_.add_promise(promise_send_closure(actor_id(this), &DownloadManagerImpl::do_search,
                                                                      std::move(query), only_active, only_completed,
                                                                      std::move(offset), limit, std::move(promise)));
      lock.set_value(Unit());
      return;
    }

    if (limit <= 0) {
      return promise.set_error(Status::Error(400, "Limit must be positive"));
    }
    int64 offset_int64 = std::numeric_limits<int64>::max();
    if (!offset.empty()) {
      auto r_offset = to_integer_safe<int64>(offset);
      if (r_offset.is_error()) {
        return promise.set_error(Status::Error(400, "Invalid offset"));
      }
      offset_int64 = r_offset.move_as_ok();
    }
    auto download_ids = hints_.search(query, 10000, true).second;
    FileCounters counters;
    td::remove_if(download_ids, [&](int64 download_id) {
      auto r_file_info_ptr = get_file_info_ptr(download_id);
      CHECK(r_file_info_ptr.is_ok());
      auto &file_info = *r_file_info_ptr.ok();
      if (is_completed(file_info)) {
        counters.completed_count++;
        if (only_active) {
          return true;
        }
      } else {
        counters.active_count++;
        if (file_info.is_paused) {
          counters.paused_count++;
        }
        if (only_completed) {
          return true;
        }
      }
      if (download_id >= offset_int64) {
        return true;
      }
      return false;
    });
    std::sort(download_ids.begin(), download_ids.end(), std::greater<>());
    if (static_cast<int32>(download_ids.size()) > limit) {
      download_ids.resize(limit);
    }
    auto file_downloads = transform(download_ids, [&](int64 download_id) {
      on_file_viewed(download_id);

      auto it = files_.find(download_id);
      CHECK(it != files_.end());
      const FileInfo &file_info = *it->second;
      return callback_->get_file_download_object(file_info.file_id, file_info.file_source_id, file_info.created_at,
                                                 file_info.completed_at, file_info.is_paused);
    });
    td::remove_if(file_downloads, [](const auto &file_download) { return file_download->message_ == nullptr; });
    string next_offset;
    if (!download_ids.empty()) {
      next_offset = to_string(download_ids.back());
    }
    promise.set_value(td_api::make_object<td_api::foundFileDownloads>(counters.get_downloaded_file_counts_object(),
                                                                      std::move(file_downloads), next_offset));
  }

  void update_file_download_state(FileId file_id, int64 downloaded_size, int64 size, int64 expected_size,
                                  bool is_paused) final {
    if (!callback_ || !is_database_loaded_) {
      return;
    }
    LOG(INFO) << "Update file download state for file " << file_id << " of size " << size << '/' << expected_size
              << " to downloaded_size = " << downloaded_size << " and is_paused = " << is_paused;
    auto r_file_info_ptr = get_file_info_ptr(file_id);
    if (r_file_info_ptr.is_error()) {
      return;
    }
    auto &file_info = *r_file_info_ptr.ok();
    if (file_info.link_token != get_link_token()) {
      LOG(INFO) << "Ignore update_file_download_state because of outdated link_token";
      return;
    }

    bool need_update = false;
    with_file_info(file_info, [&](FileInfo &file_info) {
      file_info.size = size;
      file_info.expected_size = expected_size;
      file_info.downloaded_size = downloaded_size;
      if (is_paused && file_info.is_paused != is_paused) {
        file_info.is_paused = true;
        file_info.need_save_to_database = true;
        need_update = true;

        // keep the state consistent
        callback_->pause_file(file_info.file_id, file_info.internal_download_id);
      }
    });
    if (is_search_inited_ && need_update) {
      callback_->update_file_changed(file_info.file_id, file_info.completed_at, file_info.is_paused, file_counters_);
    }
  }

  void update_file_viewed(FileId file_id, FileSourceId file_source_id) final {
    if (unviewed_completed_download_ids_.empty() || !callback_ || !is_database_loaded_) {
      return;
    }

    LOG(INFO) << "File " << file_id << " was viewed from " << file_source_id;
    auto r_file_info_ptr = get_file_info_ptr(file_id, file_source_id);
    if (r_file_info_ptr.is_error()) {
      return;
    }
    auto &file_info = *r_file_info_ptr.ok();
    on_file_viewed(file_info.download_id);
  }

 private:
  unique_ptr<Callback> callback_;
  struct FileInfo {
    int64 download_id{};
    FileId file_id;
    int64 internal_download_id{};
    FileSourceId file_source_id;
    int8 priority{};
    bool is_paused{};
    bool is_counted{};
    mutable bool is_registered{};
    mutable bool need_save_to_database{};
    int64 size{};
    int64 expected_size{};
    int64 downloaded_size{};
    int32 created_at{};
    int32 completed_at{};
    uint64 link_token{};
  };

  FlatHashMap<FileId, int64, FileIdHash> by_file_id_;
  FlatHashMap<int64, unique_ptr<FileInfo>> files_;
  std::set<int64> completed_download_ids_;
  FlatHashSet<int64> unviewed_completed_download_ids_;
  Hints hints_;

  Counters counters_;
  Counters sent_counters_;
  FileCounters file_counters_;
  const char *database_loading_source_ = nullptr;
  bool is_inited_{false};
  bool is_database_loaded_{false};
  bool is_search_inited_{false};
  int64 max_download_id_{0};
  uint64 last_link_token_{0};
  MultiPromiseActor load_search_text_multipromise_{"LoadFileSearchTextMultiPromiseActor"};

  int64 next_download_id() {
    return ++max_download_id_;
  }

  static bool is_completed(const FileInfo &file_info) {
    return file_info.completed_at != 0;
  }

  static int64 get_file_size(const FileInfo &file_info) {
    return file_info.size == 0 ? max(file_info.downloaded_size + 1, file_info.expected_size) : file_info.size;
  }

  static bool is_database_enabled() {
    return G()->use_message_database();
  }

  static string pmc_key(const FileInfo &file_info) {
    return PSTRING() << "dlds#" << file_info.download_id;
  }

  void sync_with_database(const FileInfo &file_info) {
    if (!file_info.need_save_to_database) {
      return;
    }
    file_info.need_save_to_database = false;

    if (!is_database_enabled()) {
      return;
    }

    LOG(INFO) << "Saving to download database file " << file_info.file_id
              << " with is_paused = " << file_info.is_paused;
    FileDownloadInDatabase to_save;
    to_save.download_id = file_info.download_id;
    to_save.file_source_id = file_info.file_source_id;
    to_save.is_paused = file_info.is_paused;
    to_save.priority = file_info.priority;
    to_save.created_at = file_info.created_at;
    to_save.completed_at = file_info.completed_at;
    to_save.file_id = file_info.file_id;
    G()->td_db()->get_binlog_pmc()->set(pmc_key(file_info), log_event_store(to_save).as_slice().str());
  }

  static void remove_from_database(const FileInfo &file_info) {
    if (!is_database_enabled()) {
      return;
    }

    G()->td_db()->get_binlog_pmc()->erase(pmc_key(file_info));
  }

  void init() {
    if (is_inited_) {
      return;
    }

    if (is_database_enabled()) {
      auto serialized_counter = G()->td_db()->get_binlog_pmc()->get("dlds_counter");
      if (!serialized_counter.empty()) {
        log_event_parse(sent_counters_, serialized_counter).ensure();
        if (sent_counters_.downloaded_size == sent_counters_.total_size || sent_counters_.total_size == 0) {
          G()->td_db()->get_binlog_pmc()->erase("dlds_counter");
          sent_counters_ = Counters();
        }
      }
    } else if (!G()->td_db()->get_binlog_pmc()->get("dlds_counter").empty()) {
      G()->td_db()->get_binlog_pmc()->erase("dlds_counter");
      G()->td_db()->get_binlog_pmc()->erase_by_prefix("dlds#");
    }

    callback_->update_counters(sent_counters_);
    is_inited_ = true;
  }

  void add_file_from_database(FileDownloadInDatabase in_db) {
    if (!in_db.file_id.is_valid() || !in_db.file_source_id.is_valid()) {
      LOG(INFO) << "Skip adding file " << in_db.file_id << " from " << in_db.file_source_id;
      return;
    }
    if (by_file_id_.count(in_db.file_id) != 0) {
      // file has already been added
      return;
    }
    if (FileManager::check_priority(in_db.priority).is_error()) {
      LOG(ERROR) << "Receive invalid download priority from database";
      return;
    }

    auto file_info = make_unique<FileInfo>();
    file_info->download_id = in_db.download_id;
    file_info->file_id = in_db.file_id;
    file_info->file_source_id = in_db.file_source_id;
    file_info->is_paused = in_db.is_paused;
    file_info->priority = narrow_cast<int8>(in_db.priority);
    file_info->completed_at = in_db.completed_at;
    file_info->created_at = in_db.created_at;

    add_file_info(std::move(file_info), "");
  }

  void load_database_files(const char *source) {
    if (is_database_loaded_) {
      return;
    }

    if (!is_database_enabled()) {
      is_database_loaded_ = true;
      return;
    }
    CHECK(is_inited_);
    LOG_CHECK(database_loading_source_ == nullptr) << database_loading_source_ << ' ' << source;
    database_loading_source_ = source;

    LOG(INFO) << "Start Download Manager database loading";

    auto downloads_in_kv = G()->td_db()->get_binlog_pmc()->prefix_get("dlds#");
    for (auto &it : downloads_in_kv) {
      Slice key = it.first;
      Slice value = it.second;
      FileDownloadInDatabase in_db;
      log_event_parse(in_db, value).ensure();
      CHECK(in_db.download_id == to_integer_safe<int64>(key).ok());
      max_download_id_ = max(in_db.download_id, max_download_id_);
      add_file_from_database(in_db);
    }

    is_database_loaded_ = true;
    database_loading_source_ = nullptr;
    update_counters();
    check_completed_downloads_size();

    LOG(INFO) << "Finish Download Manager database loading";
  }

  void prepare_hints() {
    for (const auto &it : files_) {
      const auto &file_info = *it.second;
      auto promise =
          PromiseCreator::lambda([actor_id = actor_id(this), promise = load_search_text_multipromise_.get_promise(),
                                  download_id = it.first](Result<string> r_search_text) mutable {
            send_closure(actor_id, &DownloadManagerImpl::add_download_to_hints, download_id, std::move(r_search_text),
                         std::move(promise));
          });
      callback_->get_file_search_text(file_info.file_id, file_info.file_source_id, std::move(promise));
    }
  }

  void add_download_to_hints(int64 download_id, Result<string> r_search_text, Promise<Unit> promise) {
    auto it = files_.find(download_id);
    if (it == files_.end()) {
      return promise.set_value(Unit());
    }

    if (r_search_text.is_error()) {
      if (!G()->close_flag() && check_is_active("add_download_to_hints").is_ok()) {
        remove_file_impl(*it->second, false, "add_download_to_hints");
      }
    } else {
      auto search_text = r_search_text.move_as_ok();
      // TODO: This is a race. Synchronous call would be better.
      hints_.add(download_id, search_text.empty() ? string(" ") : search_text);
    }
    promise.set_value(Unit());
  }

  void add_file_info(unique_ptr<FileInfo> &&file_info, const string &search_text) {
    CHECK(file_info != nullptr);
    auto download_id = file_info->download_id;
    file_info->internal_download_id = callback_->get_internal_download_id();
    auto file_view = callback_->get_sync_file_view(file_info->file_id);
    CHECK(!file_view.empty());
    file_info->size = file_view.size();
    file_info->expected_size = file_view.expected_size();
    file_info->downloaded_size = file_view.local_total_size();
    file_info->is_counted = !is_completed(*file_info);

    if (file_info->completed_at > 0 && (file_info->size == 0 || file_info->downloaded_size != file_info->size)) {
      LOG(INFO) << "Skip adding file " << file_info->file_id << " to recently downloaded files, because local size is "
                << file_info->downloaded_size << " instead of expected " << file_info->size;
      remove_from_database(*file_info);
      return;
    }

    by_file_id_[file_info->file_id] = download_id;
    hints_.add(download_id, search_text.empty() ? string(" ") : search_text);
    file_info->link_token = ++last_link_token_;

    LOG(INFO) << "Adding to downloads file " << file_info->file_id << " of size " << file_info->size << '/'
              << file_info->expected_size << " with downloaded_size = " << file_info->downloaded_size
              << " and is_paused = " << file_info->is_paused;
    auto it = files_.emplace(download_id, std::move(file_info)).first;
    bool was_completed = is_completed(*it->second);
    register_file_info(*it->second);  // must be called before start_file, which can call update_file_download_state
    if (is_completed(*it->second)) {
      bool is_inserted = completed_download_ids_.insert(it->second->download_id).second;
      CHECK(is_inserted == was_completed);
    } else {
      if (!it->second->is_paused) {
        callback_->start_file(it->second->file_id, it->second->internal_download_id, it->second->priority,
                              actor_shared(this, it->second->link_token));
      }
    }
    if (is_search_inited_) {
      callback_->update_file_added(it->second->file_id, it->second->file_source_id, it->second->created_at,
                                   it->second->completed_at, it->second->is_paused, file_counters_);
    }
  }

  void remove_file_impl(const FileInfo &file_info, bool delete_from_cache, const char *source) {
    auto file_id = file_info.file_id;
    LOG(INFO) << "Remove from downloads file " << file_id << " from " << source;
    auto download_id = file_info.download_id;
    if (!is_completed(file_info) && !file_info.is_paused) {
      callback_->pause_file(file_info.file_id, file_info.internal_download_id);
    }
    unregister_file_info(file_info);
    if (delete_from_cache) {
      callback_->delete_file(file_info.file_id);
    }
    by_file_id_.erase(file_id);
    hints_.remove(download_id);
    completed_download_ids_.erase(download_id);

    remove_from_database(file_info);
    files_.erase(download_id);
    if (is_search_inited_) {
      callback_->update_file_removed(file_id, file_counters_);
    }

    update_counters();
    on_file_viewed(download_id);
  }

  Status remove_file_if_finished_impl(FileId file_id) {
    TRY_STATUS(check_is_active("remove_file_if_finished_impl"));
    TRY_RESULT(file_info_ptr, get_file_info_ptr(file_id));
    if (!is_completed(*file_info_ptr)) {
      return Status::Error("File is active");
    }
    remove_file_impl(*file_info_ptr, false, "remove_file_if_finished_impl");
    return Status::OK();
  }

  void timeout_expired() final {
    clear_counters();
  }

  void clear_counters() {
    if (!is_database_loaded_) {
      return;
    }
    CHECK(counters_ == sent_counters_);
    if (counters_.downloaded_size != counters_.total_size || counters_.total_size == 0) {
      return;
    }

    for (auto &it : files_) {
      if (is_completed(*it.second) || !it.second->is_paused) {
        it.second->is_counted = false;
      }
    }
    counters_ = Counters();
    update_counters();
  }

  void tear_down() final {
    callback_.reset();
  }

  void toggle_is_paused(const FileInfo &file_info, bool is_paused) {
    if (is_completed(file_info) || is_paused == file_info.is_paused) {
      return;
    }
    LOG(INFO) << "Change is_paused state of file " << file_info.file_id << " to " << is_paused;

    with_file_info(file_info, [&](FileInfo &file_info) {
      file_info.is_paused = is_paused;
      file_info.need_save_to_database = true;
      file_info.link_token = ++last_link_token_;
    });
    if (is_paused) {
      callback_->pause_file(file_info.file_id, file_info.internal_download_id);
    } else {
      callback_->start_file(file_info.file_id, file_info.internal_download_id, file_info.priority,
                            actor_shared(this, file_info.link_token));
    }
    if (is_search_inited_) {
      callback_->update_file_changed(file_info.file_id, file_info.completed_at, file_info.is_paused, file_counters_);
    }
  }

  void update_counters() {
    if (!is_database_loaded_) {
      return;
    }
    if (counters_ == sent_counters_) {
      return;
    }
    CHECK(counters_.total_size >= 0);
    CHECK(counters_.total_count >= 0);
    CHECK(counters_.downloaded_size >= 0);
    if ((counters_.downloaded_size == counters_.total_size && counters_.total_size != 0) || counters_ == Counters()) {
      if (counters_.total_size != 0) {
        constexpr double EMPTY_UPDATE_DELAY = 60.0;
        set_timeout_in(EMPTY_UPDATE_DELAY);
      } else {
        cancel_timeout();
      }
      G()->td_db()->get_binlog_pmc()->erase("dlds_counter");
    } else {
      cancel_timeout();
      G()->td_db()->get_binlog_pmc()->set("dlds_counter", log_event_store(counters_).as_slice().str());
    }
    sent_counters_ = counters_;
    callback_->update_counters(counters_);
  }

  Result<const FileInfo *> get_file_info_ptr(FileId file_id, FileSourceId file_source_id = {}) {
    auto it = by_file_id_.find(file_id);
    if (it == by_file_id_.end()) {
      return Status::Error(400, "Can't find file");
    }
    return get_file_info_ptr(it->second, file_source_id);
  }

  Result<const FileInfo *> get_file_info_ptr(int64 download_id, FileSourceId file_source_id = {}) {
    auto it = files_.find(download_id);
    if (it == files_.end()) {
      return Status::Error(400, "Can't find file");
    }
    if (file_source_id.is_valid() && file_source_id != it->second->file_source_id) {
      return Status::Error(400, "Can't find file with such source");
    }
    return it->second.get();
  }

  void unregister_file_info(const FileInfo &file_info) {
    CHECK(file_info.is_registered);
    file_info.is_registered = false;
    if (file_info.is_counted && (is_completed(file_info) || !file_info.is_paused)) {
      LOG(INFO) << "Unregister file " << file_info.file_id;
      counters_.downloaded_size -= file_info.downloaded_size;
      counters_.total_size -= get_file_size(file_info);
      counters_.total_count--;
    }
    if (is_completed(file_info)) {
      file_counters_.completed_count--;
      CHECK(file_counters_.completed_count >= 0);
    } else {
      if (file_info.is_paused) {
        file_counters_.paused_count--;
        CHECK(file_counters_.paused_count >= 0);
      }
      file_counters_.active_count--;
      CHECK(file_counters_.active_count >= file_counters_.paused_count);
    }
  }

  void register_file_info(FileInfo &file_info) {
    CHECK(!file_info.is_registered);
    file_info.is_registered = true;
    bool need_update = false;
    if (!is_completed(file_info) && file_info.size != 0 && file_info.downloaded_size == file_info.size) {
      LOG(INFO) << "Register file " << file_info.file_id;
      file_info.is_paused = false;
      file_info.completed_at = G()->unix_time();
      file_info.need_save_to_database = true;

      bool is_inserted = completed_download_ids_.insert(file_info.download_id).second;
      CHECK(is_inserted);
      if (file_info.is_counted) {
        unviewed_completed_download_ids_.insert(file_info.download_id);
      }

      need_update = true;
    }
    if (file_info.is_counted && (is_completed(file_info) || !file_info.is_paused)) {
      counters_.downloaded_size += file_info.downloaded_size;
      counters_.total_size += get_file_size(file_info);
      counters_.total_count++;
    }
    if (is_completed(file_info)) {
      file_counters_.completed_count++;
    } else {
      if (file_info.is_paused) {
        file_counters_.paused_count++;
      }
      file_counters_.active_count++;
    }
    if (is_search_inited_ && need_update) {
      callback_->update_file_changed(file_info.file_id, file_info.completed_at, file_info.is_paused, file_counters_);
    }
    sync_with_database(file_info);
    update_counters();
    CHECK(file_info.is_registered);

    check_completed_downloads_size();
  }

  void check_completed_downloads_size() {
    if (!is_database_loaded_ || check_is_active("check_completed_downloads_size").is_error()) {
      return;
    }

    constexpr size_t MAX_COMPLETED_DOWNLOADS = 200;
    while (completed_download_ids_.size() > MAX_COMPLETED_DOWNLOADS) {
      auto download_id = *completed_download_ids_.begin();
      auto file_info_ptr = get_file_info_ptr(download_id).move_as_ok();
      remove_file_impl(*file_info_ptr, false, "check_completed_downloads_size");
    }
  }

  void on_file_viewed(int64 download_id) {
    if (unviewed_completed_download_ids_.empty()) {
      return;
    }

    LOG(INFO) << "Mark download " << download_id << " as viewed";
    unviewed_completed_download_ids_.erase(download_id);
    if (unviewed_completed_download_ids_.empty()) {
      clear_counters();
    }
  }

  template <class F>
  void with_file_info(const FileInfo &const_file_info, F &&f) {
    unregister_file_info(const_file_info);
    auto &file_info = const_cast<FileInfo &>(const_file_info);
    f(file_info);
    register_file_info(file_info);
  }

  Status check_is_active(const char *source) {
    if (!callback_) {
      LOG(ERROR) << "DownloadManager is closed in " << source;
      return Status::Error(500, "DownloadManager is closed");
    }
    CHECK(is_inited_);
    load_database_files(source);
    return Status::OK();
  }
};

unique_ptr<DownloadManager> DownloadManager::create(unique_ptr<Callback> callback) {
  return make_unique<DownloadManagerImpl>(std::move(callback));
}

td_api::object_ptr<td_api::updateFileDownloads> DownloadManager::Counters::get_update_file_downloads_object() const {
  return td_api::make_object<td_api::updateFileDownloads>(total_size, total_count, downloaded_size);
}

td_api::object_ptr<td_api::downloadedFileCounts> DownloadManager::FileCounters::get_downloaded_file_counts_object()
    const {
  return td_api::make_object<td_api::downloadedFileCounts>(active_count, paused_count, completed_count);
}

template <class StorerT>
void DownloadManager::Counters::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  END_STORE_FLAGS();
  td::store(total_size, storer);
  td::store(total_count, storer);
  td::store(downloaded_size, storer);
}

template <class ParserT>
void DownloadManager::Counters::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  END_PARSE_FLAGS();
  td::parse(total_size, parser);
  td::parse(total_count, parser);
  td::parse(downloaded_size, parser);
}

}  // namespace td
