//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileLoaderUtils.h"

#include "td/telegram/Global.h"
#include "td/telegram/TdDb.h"

#include "td/utils/common.h"
#include "td/utils/filesystem.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/PathView.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/path.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/utf8.h"

#include <tuple>

namespace td {

int VERBOSITY_NAME(file_loader) = VERBOSITY_NAME(DEBUG);

namespace {

Result<std::pair<FileFd, string>> try_create_new_file(CSlice path, CSlice file_name) {
  LOG(DEBUG) << "Trying to create new file \"" << file_name << "\" in the directory \"" << path << '"';
  auto name = PSTRING() << path << file_name;
  auto r_fd = FileFd::open(name, FileFd::Read | FileFd::Write | FileFd::CreateNew, 0640);
  if (r_fd.is_error()) {
    auto status = mkdir(path, 0750);
    if (status.is_error()) {
      auto r_stat = stat(path);
      if (r_stat.is_ok() && r_stat.ok().is_dir_) {
        LOG(ERROR) << "Creation of directory \"" << path << "\" failed with " << status << ", but directory exists";
      } else {
        LOG(ERROR) << "Creation of directory \"" << path << "\" failed with " << status;
      }
      return r_fd.move_as_error();
    }
#if TD_ANDROID
    FileFd::open(PSLICE() << path << ".nomedia", FileFd::Create | FileFd::Read).ignore();
#endif
    r_fd = FileFd::open(name, FileFd::Read | FileFd::Write | FileFd::CreateNew, 0640);
    if (r_fd.is_error()) {
      return r_fd.move_as_error();
    }
  }
  return std::make_pair(r_fd.move_as_ok(), std::move(name));
}

Result<std::pair<FileFd, string>> try_open_file(CSlice name) {
  LOG(DEBUG) << "Trying to open file " << name;
  TRY_RESULT(fd, FileFd::open(name, FileFd::Read, 0640));
  return std::make_pair(std::move(fd), name.str());
}

struct RandSuff {
  int len;
};
StringBuilder &operator<<(StringBuilder &sb, const RandSuff &) {
  for (int i = 0; i < 6; i++) {
    sb << format::hex_digit(Random::fast(0, 15));
  }
  return sb;
}

struct Ext {
  Slice ext;
};
StringBuilder &operator<<(StringBuilder &sb, const Ext &ext) {
  if (ext.ext.empty()) {
    return sb;
  }
  return sb << "." << ext.ext;
}
}  // namespace

Result<std::pair<FileFd, string>> open_temp_file(FileType file_type) {
  auto pmc = G()->td_db()->get_binlog_pmc();
  // TODO: CAS?
  auto file_id = pmc->get("tmp_file_id");
  pmc->set("tmp_file_id", to_string(to_integer<int32>(file_id) + 1));

  auto temp_dir = get_files_temp_dir(file_type);
  auto res = try_create_new_file(temp_dir, file_id);
  if (res.is_error()) {
    res = try_create_new_file(temp_dir, PSLICE() << file_id << '_' << RandSuff{6});
  }
  return res;
}

template <class F>
bool for_suggested_file_name(CSlice name, bool use_pmc, bool use_random, F &&callback) {
  auto cleaned_name = clean_filename(name);
  PathView path_view(cleaned_name);
  auto stem = path_view.file_stem();
  auto ext = path_view.extension();
  bool active = true;
  if (!stem.empty() && !G()->get_option_boolean("ignore_file_names")) {
    active = callback(PSLICE() << stem << Ext{ext});
    for (int i = 0; active && i < 10; i++) {
      active = callback(PSLICE() << stem << "_(" << i << ")" << Ext{ext});
    }
    for (int i = 2; active && i < 12 && use_random; i++) {
      active = callback(PSLICE() << stem << "_(" << RandSuff{i} << ")" << Ext{ext});
    }
  } else if (use_pmc) {
    auto pmc = G()->td_db()->get_binlog_pmc();
    auto file_id = to_integer<int32>(pmc->get("perm_file_id"));
    pmc->set("perm_file_id", to_string(file_id + 1));
    active = callback(PSLICE() << "file_" << file_id << Ext{ext});
    if (active) {
      active = callback(PSLICE() << "file_" << file_id << "_" << RandSuff{6} << Ext{ext});
    }
  }
  return active;
}

Result<string> create_from_temp(FileType file_type, CSlice temp_path, CSlice name) {
  auto dir = get_files_dir(file_type);
  LOG(INFO) << "Create file of type " << file_type << " in directory " << dir << " with suggested name " << name
            << " from temporary file " << temp_path;
  Result<std::pair<FileFd, string>> res = Status::Error(500, "Can't find suitable file name");
  for_suggested_file_name(name, true, true, [&](CSlice suggested_name) {
    res = try_create_new_file(dir, suggested_name);
    return res.is_error();
  });
  TRY_RESULT(tmp, std::move(res));
  tmp.first.close();
  auto perm_path = std::move(tmp.second);
  TRY_STATUS(rename(temp_path, perm_path));
  return perm_path;
}

Result<string> search_file(FileType file_type, CSlice name, int64 expected_size) {
  Result<string> res = Status::Error(500, "Can't find suitable file name");
  auto dir = get_files_dir(file_type);
  for_suggested_file_name(name, false, false, [&](CSlice suggested_name) {
    auto r_pair = try_open_file(PSLICE() << dir << suggested_name);
    if (r_pair.is_error()) {
      return false;
    }
    FileFd fd;
    string path;
    std::tie(fd, path) = r_pair.move_as_ok();
    auto r_size = fd.get_size();
    if (r_size.is_error() || r_size.ok() != expected_size) {
      return true;
    }
    fd.close();
    res = std::move(path);
    return false;
  });
  return res;
}

Result<string> get_suggested_file_name(CSlice directory, Slice file_name) {
  string cleaned_name = clean_filename(file_name.str());
  file_name = cleaned_name;

  if (directory.empty()) {
    directory = CSlice("./");
  }

  auto dir_stat = stat(directory);
  if (dir_stat.is_error() || !dir_stat.ok().is_dir_) {
    return cleaned_name;
  }

  PathView path_view(file_name);
  auto stem = path_view.file_stem();
  auto ext = path_view.extension();

  if (stem.empty()) {
    return cleaned_name;
  }

  Slice directory_slice = directory;
  while (directory_slice.size() > 1 && (directory_slice.back() == '/' || directory_slice.back() == '\\')) {
    directory_slice.remove_suffix(1);
  }

  auto check_file_name = [directory_slice](Slice name) {
    return stat(PSLICE() << directory_slice << TD_DIR_SLASH << name).is_error();  // in case of success, the name is bad
  };

  string checked_name = PSTRING() << stem << Ext{ext};
  if (check_file_name(checked_name)) {
    return checked_name;
  }

  for (int i = 1; i < 100; i++) {
    checked_name = PSTRING() << stem << " (" << i << ")" << Ext{ext};
    if (check_file_name(checked_name)) {
      return checked_name;
    }
  }

  return PSTRING() << stem << " - " << StringBuilder::FixedDouble(Clocks::system(), 3) << Ext{ext};
}

Result<FullLocalFileLocation> save_file_bytes(FileType file_type, BufferSlice bytes, CSlice file_name) {
  auto r_old_path = search_file(file_type, file_name, bytes.size());
  if (r_old_path.is_ok()) {
    auto r_old_bytes = read_file(r_old_path.ok());
    if (r_old_bytes.is_ok() && r_old_bytes.ok().as_slice() == bytes.as_slice()) {
      LOG(INFO) << "Found previous file with the same name " << r_old_path.ok();
      return FullLocalFileLocation(file_type, r_old_path.ok(), 0);
    }
  }

  TRY_RESULT(fd_path, open_temp_file(file_type));
  FileFd fd = std::move(fd_path.first);
  string path = std::move(fd_path.second);

  TRY_RESULT(size, fd.write(bytes.as_slice()));
  fd.close();

  if (size != bytes.size()) {
    return Status::Error("Failed to write bytes to the file");
  }

  TRY_RESULT(perm_path, create_from_temp(file_type, path, file_name));

  return FullLocalFileLocation(file_type, std::move(perm_path), 0);
}

static Slice get_file_base_dir(const FileDirType &file_dir_type) {
  switch (file_dir_type) {
    case FileDirType::Secure:
      return G()->get_secure_files_dir();
    case FileDirType::Common:
      return G()->get_files_dir();
    default:
      UNREACHABLE();
      return Slice();
  }
}

Slice get_files_base_dir(FileType file_type) {
  return get_file_base_dir(get_file_dir_type(file_type));
}

string get_files_temp_dir(FileType file_type) {
  return PSTRING() << get_files_base_dir(file_type) << "temp" << TD_DIR_SLASH;
}

string get_files_dir(FileType file_type) {
  return PSTRING() << get_files_base_dir(file_type) << get_file_type_name(file_type) << TD_DIR_SLASH;
}

bool are_modification_times_equal(int64 old_mtime, int64 new_mtime) {
  if (old_mtime == new_mtime) {
    return true;
  }
  if (old_mtime < new_mtime) {
    return false;
  }
  if (old_mtime - new_mtime == 1000000000 && old_mtime % 1000000000 == 0 && new_mtime % 2000000000 == 0) {
    // FAT32 has 2 seconds mtime resolution, but file system sometimes reports odd modification time
    return true;
  }
  return false;
}

Result<FullLocalLocationInfo> check_full_local_location(FullLocalLocationInfo local_info, bool skip_file_size_checks) {
  constexpr int64 MAX_FILE_SIZE = static_cast<int64>(4000) << 20 /* 4000 MB */;
  constexpr int64 MAX_THUMBNAIL_SIZE = 200 * (1 << 10) - 1 /* 200 KB - 1 B */;
  constexpr int64 MAX_PHOTO_SIZE = 10 * (1 << 20) /* 10 MB */;
  constexpr int64 DEFAULT_VIDEO_NOTE_SIZE_MAX = 12 * (1 << 20) /* 12 MB */;
  constexpr int64 MAX_VIDEO_STORY_SIZE = 30 * (1 << 20) /* 30 MB */;

  FullLocalFileLocation &location = local_info.location_;
  int64 &size = local_info.size_;
  if (location.path_.empty()) {
    return Status::Error(400, "File must have non-empty path");
  }
  auto r_path = realpath(location.path_, true);
  if (r_path.is_error()) {
    return Status::Error(400, "Can't find real file path");
  }
  location.path_ = r_path.move_as_ok();

  auto r_stat = stat(location.path_);
  if (r_stat.is_error()) {
    return Status::Error(400, "Can't get stat about the file");
  }
  auto stat = r_stat.move_as_ok();
  if (!stat.is_reg_) {
    return Status::Error(400, "File must be a regular file");
  }
  if (stat.size_ < 0) {
    // TODO is it possible?
    return Status::Error(400, "File is too big");
  }
  if (stat.size_ == 0) {
    return Status::Error(400, "File must be non-empty");
  }

  if (size <= 0) {
    size = stat.size_;
  } else if (size != stat.size_) {
    VLOG(file_loader) << "File \"" << location.path_ << "\" was modified: old size = " << size
                      << ", new size = " << stat.size_;
    return Status::Error(400, "File size has changed");
  }
  if (location.mtime_nsec_ == 0) {
    VLOG(file_loader) << "Set file \"" << location.path_ << "\" modification time to " << stat.mtime_nsec_;
    location.mtime_nsec_ = stat.mtime_nsec_;
  } else if (!are_modification_times_equal(location.mtime_nsec_, stat.mtime_nsec_)) {
    VLOG(file_loader) << "File \"" << location.path_ << "\" was modified: old mtime = " << location.mtime_nsec_
                      << ", new mtime = " << stat.mtime_nsec_;
    return Status::Error(400, PSLICE() << "File \"" << utf8_encode(location.path_) << "\" was modified");
  }
  if (skip_file_size_checks) {
    return std::move(local_info);
  }

  auto get_file_size_error = [&](Slice reason) {
    return Status::Error(400, PSLICE() << "File \"" << utf8_encode(location.path_) << "\" of size " << size
                                       << " bytes is too big" << reason);
  };
  if ((location.file_type_ == FileType::Thumbnail || location.file_type_ == FileType::EncryptedThumbnail) &&
      size > MAX_THUMBNAIL_SIZE && !begins_with(PathView(location.path_).file_name(), "map") &&
      !begins_with(PathView(location.path_).file_name(), "Album cover for ")) {
    return get_file_size_error(" for a thumbnail");
  }
  if (size > MAX_FILE_SIZE) {
    return get_file_size_error("");
  }
  if (get_file_type_class(location.file_type_) == FileTypeClass::Photo && size > MAX_PHOTO_SIZE) {
    return get_file_size_error(" for a photo");
  }
  if ((location.file_type_ == FileType::VideoNote || location.file_type_ == FileType::SelfDestructingVideoNote) &&
      size > G()->get_option_integer("video_note_size_max", DEFAULT_VIDEO_NOTE_SIZE_MAX)) {
    return get_file_size_error(" for a video note");
  }
  if (location.file_type_ == FileType::VideoStory && size > MAX_VIDEO_STORY_SIZE) {
    return get_file_size_error(" for a video story");
  }
  return std::move(local_info);
}

Status check_partial_local_location(const PartialLocalFileLocation &location) {
  TRY_RESULT(stat, stat(location.path_));
  if (!stat.is_reg_) {
    if (stat.is_dir_) {
      return Status::Error(PSLICE() << "Can't use directory \"" << location.path_ << "\" as a file path");
    }
    return Status::Error("File must be a regular file");
  }
  // can't check mtime. Hope nobody will mess with the file in our temporary directory
  return Status::OK();
}

}  // namespace td
