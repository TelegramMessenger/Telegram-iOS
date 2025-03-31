//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileGcWorker.h"

#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"

#include "td/utils/algorithm.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/path.h"
#include "td/utils/Time.h"

#include <algorithm>
#include <array>

namespace td {

int VERBOSITY_NAME(file_gc) = VERBOSITY_NAME(INFO);

void FileGcWorker::run_gc(const FileGcParameters &parameters, vector<FullFileInfo> files, bool send_updates,
                          Promise<FileGcResult> promise) {
  auto begin_time = Time::now();
  VLOG(file_gc) << "Start files GC with " << parameters;
  // quite stupid implementations
  // needs a lot of memory
  // may write something more clever, but i will need at least 2 passes over the files
  // TODO update atime for all files in android (?)

  std::array<bool, MAX_FILE_TYPE> immune_types{{false}};

  if (G()->use_file_database()) {
    // immune by default
    immune_types[narrow_cast<size_t>(FileType::Sticker)] = true;
    immune_types[narrow_cast<size_t>(FileType::ProfilePhoto)] = true;
    immune_types[narrow_cast<size_t>(FileType::Thumbnail)] = true;
    immune_types[narrow_cast<size_t>(FileType::Wallpaper)] = true;
    immune_types[narrow_cast<size_t>(FileType::Background)] = true;
    immune_types[narrow_cast<size_t>(FileType::Ringtone)] = true;
  }

  if (!parameters.file_types_.empty()) {
    std::fill(immune_types.begin(), immune_types.end(), true);
    for (auto file_type : parameters.file_types_) {
      immune_types[narrow_cast<size_t>(file_type)] = false;
    }
    for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
      auto main_file_type = narrow_cast<size_t>(get_main_file_type(static_cast<FileType>(i)));
      if (!immune_types[main_file_type]) {
        immune_types[i] = false;
      }
    }
  }

  if (G()->use_file_database()) {
    immune_types[narrow_cast<size_t>(FileType::EncryptedThumbnail)] = true;
  }

  auto file_cnt = files.size();
  int32 type_immunity_ignored_cnt = 0;
  int32 time_immunity_ignored_cnt = 0;
  int32 exclude_owner_dialog_id_ignored_cnt = 0;
  int32 owner_dialog_id_ignored_cnt = 0;
  int32 remove_by_atime_cnt = 0;
  int32 remove_by_count_cnt = 0;
  int32 remove_by_size_cnt = 0;
  int64 total_removed_size = 0;
  int64 total_size = 0;
  for (auto &info : files) {
    if (info.atime_nsec < info.mtime_nsec) {
      info.atime_nsec = info.mtime_nsec;
    }
    total_size += info.size;
  }

  FileStats new_stats(false, parameters.dialog_limit_ != 0);
  FileStats removed_stats(false, parameters.dialog_limit_ != 0);

  auto do_remove_file = [&removed_stats, send_updates](const FullFileInfo &info) {
    removed_stats.add_copy(info);
    auto status = unlink(info.path);
    LOG_IF(WARNING, status.is_error()) << "Failed to unlink file \"" << info.path << "\" during files GC: " << status;
    if (send_updates) {
      send_closure(G()->file_manager(), &FileManager::on_file_unlink,
                   FullLocalFileLocation(info.file_type, info.path, info.mtime_nsec));
    }
  };

  double now = Clocks::system();

  // Remove all suitable files with (atime > now - max_time_from_last_access)
  td::remove_if(files, [&](const FullFileInfo &info) {
    if (token_) {
      return false;
    }
    if (immune_types[narrow_cast<size_t>(info.file_type)]) {
      type_immunity_ignored_cnt++;
      new_stats.add_copy(info);
      return true;
    }
    if (td::contains(parameters.exclude_owner_dialog_ids_, info.owner_dialog_id)) {
      exclude_owner_dialog_id_ignored_cnt++;
      new_stats.add_copy(info);
      return true;
    }
    if (!parameters.owner_dialog_ids_.empty() && !td::contains(parameters.owner_dialog_ids_, info.owner_dialog_id)) {
      owner_dialog_id_ignored_cnt++;
      new_stats.add_copy(info);
      return true;
    }
    if (static_cast<double>(info.mtime_nsec) * 1e-9 > now - parameters.immunity_delay_) {
      // new files are immune to GC
      time_immunity_ignored_cnt++;
      new_stats.add_copy(info);
      return true;
    }

    if (static_cast<double>(info.atime_nsec) * 1e-9 < now - parameters.max_time_from_last_access_) {
      do_remove_file(info);
      total_removed_size += info.size;
      remove_by_atime_cnt++;
      return true;
    }
    return false;
  });
  if (token_) {
    return promise.set_error(Global::request_aborted_error());
  }

  // sort by max(atime, mtime)
  std::sort(files.begin(), files.end(), [](const auto &a, const auto &b) { return a.atime_nsec < b.atime_nsec; });

  // 1. Total size must be less than parameters.max_files_size_
  // 2. Total file count must be less than parameters.max_file_count_
  size_t remove_count = 0;
  if (files.size() > parameters.max_file_count_) {
    remove_count = files.size() - parameters.max_file_count_;
  }
  int64 remove_size = -parameters.max_files_size_;
  for (auto &file : files) {
    remove_size += file.size;
  }

  size_t pos = 0;
  while (pos < files.size() && (remove_count > 0 || remove_size > 0)) {
    if (token_) {
      return promise.set_error(Global::request_aborted_error());
    }
    if (remove_count > 0) {
      remove_by_count_cnt++;
    } else {
      remove_by_size_cnt++;
    }

    if (remove_count > 0) {
      remove_count--;
    }
    remove_size -= files[pos].size;

    total_removed_size += files[pos].size;
    do_remove_file(files[pos]);
    pos++;
  }

  while (pos < files.size()) {
    new_stats.add_copy(files[pos]);
    pos++;
  }

  auto end_time = Time::now();

  VLOG(file_gc) << "Finish files GC: " << tag("time", end_time - begin_time) << tag("total", file_cnt)
                << tag("removed", remove_by_atime_cnt + remove_by_count_cnt + remove_by_size_cnt)
                << tag("total_size", format::as_size(total_size))
                << tag("total_removed_size", format::as_size(total_removed_size))
                << tag("by_atime", remove_by_atime_cnt) << tag("by_count", remove_by_count_cnt)
                << tag("by_size", remove_by_size_cnt) << tag("type_immunity", type_immunity_ignored_cnt)
                << tag("time_immunity", time_immunity_ignored_cnt)
                << tag("owner_dialog_id_immunity", owner_dialog_id_ignored_cnt)
                << tag("exclude_owner_dialog_id_immunity", exclude_owner_dialog_id_ignored_cnt);
  if (end_time - begin_time > 1.0) {
    LOG(WARNING) << "Finish file GC: " << tag("time", end_time - begin_time) << tag("total", file_cnt)
                 << tag("removed", remove_by_atime_cnt + remove_by_count_cnt + remove_by_size_cnt)
                 << tag("total_size", format::as_size(total_size))
                 << tag("total_removed_size", format::as_size(total_removed_size));
  }

  promise.set_value({std::move(new_stats), std::move(removed_stats)});
}

}  // namespace td
