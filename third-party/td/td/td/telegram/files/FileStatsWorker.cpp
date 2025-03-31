//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileStatsWorker.h"

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileData.h"
#include "td/telegram/files/FileDb.h"
#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/TdDb.h"

#include "td/db/SqliteKeyValue.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_parsers.h"

#include <unordered_map>
#include <unordered_set>

namespace td {
namespace {
// Performance ideas:
// - use slice instead of string
// - use arena memory allocator
// - store FileType or dir, no both
// - store dir relative to G()->files_dir()

struct DbFileInfo {
  FileType file_type;
  string path;
  DialogId owner_dialog_id;
  int64 size;
};

template <class CallbackT>
void scan_db(CancellationToken &token, CallbackT &&callback) {
  G()->td_db()->get_file_db_shared()->pmc().get_by_range("file0", "file:", [&](Slice key, Slice value) {
    if (token) {
      return false;
    }
    // skip reference to other data
    if (value.substr(0, 2) == "@@") {
      return true;
    }
    log_event::WithVersion<TlParser> parser(value);
    FileData data;
    data.parse(parser, false);
    if (parser.get_status().is_error()) {
      LOG(ERROR) << "Invalid FileData in the database " << tag("value", format::escaped(value));
      return true;
    }
    DbFileInfo info;
    if (data.local_.type() == LocalFileLocation::Type::Full) {
      info.file_type = data.local_.full().file_type_;
      info.path = data.local_.full().path_;
    } else if (data.local_.type() == LocalFileLocation::Type::Partial) {
      info.file_type = data.local_.partial().file_type_;
      info.path = data.local_.partial().path_;
    } else {
      return true;
    }
    PathView path_view(info.path);
    if (path_view.is_relative()) {
      info.path = PSTRING() << get_files_base_dir(info.file_type) << info.path;
    }
    // LOG(INFO) << "Found file in the database: " << data << " " << info.path;
    info.owner_dialog_id = data.owner_dialog_id_;
    info.size = data.size_;
    if (info.size == 0 && data.local_.type() == LocalFileLocation::Type::Full) {
      LOG(ERROR) << "Unknown size in the database";
      return true;
    }
    callback(info);
    return true;
  });
}

struct FsFileInfo {
  FileType file_type;
  string path;
  int64 size;
  uint64 atime_nsec;
  uint64 mtime_nsec;
};

template <class CallbackT>
void scan_fs(CancellationToken &token, CallbackT &&callback) {
  std::unordered_set<string, Hash<string>> scanned_file_dirs;
  auto scan_dir = [&](FileType file_type, const string &file_dir) {
    if (!scanned_file_dirs.insert(file_dir).second) {
      return;
    }
    LOG(INFO) << "Scanning directory " << file_dir;
    walk_path(file_dir, [&](CSlice path, WalkPath::Type type) {
      if (token) {
        return WalkPath::Action::Abort;
      }
      if (type != WalkPath::Type::RegularFile) {
        return WalkPath::Action::Continue;
      }
      auto r_stat = stat(path);
      if (r_stat.is_error()) {
        LOG(WARNING) << "Stat in files gc failed: " << r_stat.error();
        return WalkPath::Action::Continue;
      }
      auto stat = r_stat.move_as_ok();
      if (stat.size_ == 0 && ends_with(path, "/.nomedia")) {
        // skip .nomedia file
        return WalkPath::Action::Continue;
      }

      FsFileInfo info;
      info.path = path.str();
      info.size = stat.real_size_;
      info.file_type = guess_file_type_by_path(path, file_type);
      info.atime_nsec = stat.atime_nsec_;
      info.mtime_nsec = stat.mtime_nsec_;
      callback(info);
      return WalkPath::Action::Continue;
    }).ignore();
  };
  for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
    auto file_type = static_cast<FileType>(i);
    scan_dir(get_main_file_type(file_type), get_files_dir(file_type));
  }
  scan_dir(get_main_file_type(FileType::Temp), get_files_temp_dir(FileType::SecureDecrypted));
  scan_dir(get_main_file_type(FileType::Temp), get_files_temp_dir(FileType::Video));
}
}  // namespace

void FileStatsWorker::get_stats(bool need_all_files, bool split_by_owner_dialog_id, Promise<FileStats> promise) {
  if (!G()->use_file_database()) {
    FileStats file_stats(need_all_files, false);
    auto start = Time::now();
    scan_fs(token_, [&](FsFileInfo &fs_info) {
      FullFileInfo info;
      info.file_type = fs_info.file_type;
      info.path = std::move(fs_info.path);
      info.size = fs_info.size;
      info.atime_nsec = fs_info.atime_nsec;
      info.mtime_nsec = fs_info.mtime_nsec;
      file_stats.add(std::move(info));
    });
    auto passed = Time::now() - start;
    LOG_IF(INFO, passed > 0.5) << "Get file stats took: " << format::as_time(passed);
    if (token_) {
      return promise.set_error(Global::request_aborted_error());
    }
    promise.set_value(std::move(file_stats));
  } else {
    auto start = Time::now();

    vector<FullFileInfo> full_infos;
    scan_fs(token_, [&](FsFileInfo &fs_info) {
      FullFileInfo info;
      info.file_type = fs_info.file_type;
      info.path = std::move(fs_info.path);
      info.size = fs_info.size;
      info.atime_nsec = fs_info.atime_nsec;
      info.mtime_nsec = fs_info.mtime_nsec;

      // LOG(INFO) << "Found file of size " << info.size << " at " << info.path;

      full_infos.push_back(std::move(info));
    });

    if (token_) {
      return promise.set_error(Global::request_aborted_error());
    }

    std::unordered_map<int64, size_t, Hash<int64>> hash_to_pos;
    size_t pos = 0;
    for (auto &full_info : full_infos) {
      hash_to_pos[Hash<string>()(full_info.path)] = pos;
      pos++;
      if (token_) {
        return promise.set_error(Global::request_aborted_error());
      }
    }
    scan_db(token_, [&](DbFileInfo &db_info) {
      auto it = hash_to_pos.find(Hash<string>()(db_info.path));
      if (it == hash_to_pos.end()) {
        return;
      }
      // LOG(INFO) << "Match! " << db_info.path << " from " << db_info.owner_dialog_id;
      CHECK(it->second < full_infos.size());
      auto &full_info = full_infos[it->second];
      full_info.owner_dialog_id = db_info.owner_dialog_id;
      full_info.file_type = db_info.file_type;  // database file_type is the correct one
    });
    if (token_) {
      return promise.set_error(Global::request_aborted_error());
    }

    FileStats file_stats(need_all_files, split_by_owner_dialog_id);
    for (auto &full_info : full_infos) {
      file_stats.add(std::move(full_info));
      if (token_) {
        return promise.set_error(Global::request_aborted_error());
      }
    }
    auto passed = Time::now() - start;
    LOG_IF(INFO, passed > 0.5) << "Get file stats took: " << format::as_time(passed);
    promise.set_value(std::move(file_stats));
  }
}

}  // namespace td
