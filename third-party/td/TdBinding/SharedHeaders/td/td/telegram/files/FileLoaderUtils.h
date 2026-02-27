//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileLocation.h"
#include "td/telegram/files/FileType.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

extern int VERBOSITY_NAME(file_loader);

Result<std::pair<FileFd, string>> open_temp_file(FileType file_type) TD_WARN_UNUSED_RESULT;

Result<string> create_from_temp(FileType file_type, CSlice temp_path, CSlice name) TD_WARN_UNUSED_RESULT;

Result<string> search_file(FileType type, CSlice name, int64 expected_size) TD_WARN_UNUSED_RESULT;

Result<string> get_suggested_file_name(CSlice dir, Slice file_name) TD_WARN_UNUSED_RESULT;

Result<FullLocalFileLocation> save_file_bytes(FileType file_type, BufferSlice bytes, CSlice file_name);

Slice get_files_base_dir(FileType file_type);

string get_files_temp_dir(FileType file_type);

string get_files_dir(FileType file_type);

bool are_modification_times_equal(int64 old_mtime, int64 new_mtime);

struct FullLocalLocationInfo {
  FullLocalFileLocation location_;
  int64 size_ = 0;

  FullLocalLocationInfo(const FullLocalFileLocation &location, int64 size) : location_(location), size_(size) {
  }
};

Result<FullLocalLocationInfo> check_full_local_location(FullLocalLocationInfo local_info, bool skip_file_size_checks);

Status check_partial_local_location(const PartialLocalFileLocation &location);

}  // namespace td
