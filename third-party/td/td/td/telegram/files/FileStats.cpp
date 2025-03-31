//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileStats.h"

#include "td/telegram/td_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"

#include <algorithm>
#include <utility>

namespace td {

tl_object_ptr<td_api::storageStatisticsFast> FileStatsFast::get_storage_statistics_fast_object() const {
  return make_tl_object<td_api::storageStatisticsFast>(size, count, database_size, language_pack_database_size,
                                                       log_size);
}

void FileStats::add(StatByType &by_type, FileType file_type, int64 size) {
  auto pos = static_cast<size_t>(file_type);
  CHECK(pos < stat_by_type_.size());
  by_type[pos].size += size;
  by_type[pos].cnt++;
}

void FileStats::add_impl(const FullFileInfo &info) {
  if (split_by_owner_dialog_id_) {
    add(stat_by_owner_dialog_id_[info.owner_dialog_id], info.file_type, info.size);
  } else {
    add(stat_by_type_, info.file_type, info.size);
  }
}

void FileStats::add_copy(const FullFileInfo &info) {
  add_impl(info);
  if (need_all_files_) {
    all_files_.push_back(info);
  }
}

void FileStats::add(FullFileInfo &&info) {
  add_impl(info);
  if (need_all_files_) {
    all_files_.push_back(std::move(info));
  }
}

FileTypeStat FileStats::get_nontemp_stat(const FileStats::StatByType &by_type) {
  FileTypeStat stat;
  for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
    if (FileType(i) != FileType::Temp) {
      stat.size += by_type[i].size;
      stat.cnt += by_type[i].cnt;
    }
  }
  return stat;
}

FileTypeStat FileStats::get_total_nontemp_stat() const {
  if (!split_by_owner_dialog_id_) {
    return get_nontemp_stat(stat_by_type_);
  }
  FileTypeStat stat;
  for (auto &dialog : stat_by_owner_dialog_id_) {
    auto tmp = get_nontemp_stat(dialog.second);
    stat.size += tmp.size;
    stat.cnt += tmp.cnt;
  }
  return stat;
}

void FileStats::apply_dialog_limit(int32 limit) {
  if (limit == -1) {
    return;
  }
  if (!split_by_owner_dialog_id_) {
    return;
  }

  std::vector<std::pair<int64, DialogId>> dialogs;
  for (auto &dialog : stat_by_owner_dialog_id_) {
    if (!dialog.first.is_valid()) {
      continue;
    }
    int64 size = 0;
    for (auto &it : dialog.second) {
      size += it.size;
    }
    dialogs.emplace_back(size, dialog.first);
  }
  size_t prefix = dialogs.size();
  if (prefix > static_cast<size_t>(limit)) {
    prefix = static_cast<size_t>(limit);
  }
  std::partial_sort(dialogs.begin(), dialogs.begin() + prefix, dialogs.end(),
                    [](const auto &x, const auto &y) { return x.first > y.first; });
  dialogs.resize(prefix);

  apply_dialog_ids(transform(dialogs, [](const auto &dialog) { return dialog.second; }));
}

void FileStats::apply_dialog_ids(const vector<DialogId> &dialog_ids) {
  FlatHashSet<DialogId, DialogIdHash> all_dialog_ids;
  for (auto &dialog_id : dialog_ids) {
    CHECK(dialog_id.is_valid());
    all_dialog_ids.insert(dialog_id);
  }
  StatByType other_stats;
  bool other_flag = false;
  table_remove_if(stat_by_owner_dialog_id_, [&](const auto &it) {
    if (!all_dialog_ids.count(it.first)) {
      for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
        other_stats[i].size += it.second[i].size;
        other_stats[i].cnt += it.second[i].cnt;
      }
      other_flag = true;
      return true;
    }
    return false;
  });

  if (other_flag) {
    DialogId other_dialog_id;  // prevents MSVC warning C4709: comma operator within array index expression
    stat_by_owner_dialog_id_[other_dialog_id] = other_stats;
  }
}

td_api::object_ptr<td_api::storageStatisticsByChat> FileStats::get_storage_statistics_by_chat_object(
    DialogId dialog_id, const FileStats::StatByType &stat_by_type) {
  auto stats = make_tl_object<td_api::storageStatisticsByChat>(dialog_id.get(), 0, 0, Auto());
  FileStats::StatByType aggregated_stats;
  for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
    auto file_type = narrow_cast<size_t>(get_main_file_type(static_cast<FileType>(i)));
    aggregated_stats[file_type].size += stat_by_type[i].size;
    aggregated_stats[file_type].cnt += stat_by_type[i].cnt;
  }

  for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
    auto size = aggregated_stats[i].size;
    auto cnt = aggregated_stats[i].cnt;

    if (size == 0) {
      continue;
    }

    auto file_type = static_cast<FileType>(i);
    stats->size_ += size;
    stats->count_ += cnt;
    stats->by_file_type_.push_back(
        make_tl_object<td_api::storageStatisticsByFileType>(get_file_type_object(file_type), size, cnt));
  }
  return stats;
}

tl_object_ptr<td_api::storageStatistics> FileStats::get_storage_statistics_object() const {
  auto stats = make_tl_object<td_api::storageStatistics>(0, 0, Auto());
  if (!split_by_owner_dialog_id_) {
    stats->by_chat_.reserve(1);
    stats->by_chat_.push_back(get_storage_statistics_by_chat_object(DialogId(), stat_by_type_));
  } else {
    stats->by_chat_.reserve(stat_by_owner_dialog_id_.size());
    for (auto &by_dialog : stat_by_owner_dialog_id_) {
      stats->by_chat_.push_back(get_storage_statistics_by_chat_object(by_dialog.first, by_dialog.second));
    }
    std::sort(stats->by_chat_.begin(), stats->by_chat_.end(), [](const auto &x, const auto &y) {
      if (x->chat_id_ == 0 || y->chat_id_ == 0) {
        return (x->chat_id_ == 0) < (y->chat_id_ == 0);
      }
      return x->size_ > y->size_;
    });
  }
  for (const auto &by_dialog : stats->by_chat_) {
    stats->size_ += by_dialog->size_;
    stats->count_ += by_dialog->count_;
  }
  return stats;
}

vector<DialogId> FileStats::get_dialog_ids() const {
  vector<DialogId> res;
  if (!split_by_owner_dialog_id_) {
    return res;
  }
  res.reserve(stat_by_owner_dialog_id_.size());
  for (auto &by_dialog : stat_by_owner_dialog_id_) {
    if (by_dialog.first.is_valid()) {
      res.push_back(by_dialog.first);
    }
  }
  return res;
}

vector<FullFileInfo> FileStats::get_all_files() {
  return std::move(all_files_);
}

static StringBuilder &operator<<(StringBuilder &sb, const FileTypeStat &stat) {
  return sb << tag("size", format::as_size(stat.size)) << tag("count", stat.cnt);
}

StringBuilder &operator<<(StringBuilder &sb, const FileStats &file_stats) {
  if (!file_stats.split_by_owner_dialog_id_) {
    FileTypeStat total_stat;
    for (auto &type_stat : file_stats.stat_by_type_) {
      total_stat.size += type_stat.size;
      total_stat.cnt += type_stat.cnt;
    }

    sb << "[FileStat " << tag("total", total_stat);
    for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
      if (file_stats.stat_by_type_[i].size != 0) {
        sb << '[' << FileType(i) << ':' << file_stats.stat_by_type_[i] << ']';
      }
    }
    sb << ']';
  } else {
    {
      FileTypeStat total_stat;
      for (auto &by_type : file_stats.stat_by_owner_dialog_id_) {
        for (auto &type_stat : by_type.second) {
          total_stat.size += type_stat.size;
          total_stat.cnt += type_stat.cnt;
        }
      }
      sb << "[FileStat " << tag("total", total_stat);
    }
    for (auto &by_type : file_stats.stat_by_owner_dialog_id_) {
      FileTypeStat dialog_stat;
      for (auto &type_stat : by_type.second) {
        dialog_stat.size += type_stat.size;
        dialog_stat.cnt += type_stat.cnt;
      }

      sb << "[FileStat " << tag("owner_dialog_id", by_type.first) << tag("total", dialog_stat);
      for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
        if (by_type.second[i].size != 0) {
          sb << '[' << FileType(i) << ':' << by_type.second[i] << ']';
        }
      }
      sb << ']';
    }
    sb << ']';
  }

  return sb;
}

}  // namespace td
