//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/files/FileType.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct FileGcParameters {
  FileGcParameters() : FileGcParameters(-1, -1, -1, -1, {}, {}, {}, 0) {
  }
  FileGcParameters(int64 size, int32 ttl, int32 count, int32 immunity_delay, vector<FileType> file_types,
                   vector<DialogId> owner_dialog_ids, vector<DialogId> exclude_owner_dialog_ids, int32 dialog_limit);

  int64 max_files_size_;
  uint32 max_time_from_last_access_;
  uint32 max_file_count_;
  uint32 immunity_delay_;

  vector<FileType> file_types_;
  vector<DialogId> owner_dialog_ids_;
  vector<DialogId> exclude_owner_dialog_ids_;

  int32 dialog_limit_;
};

StringBuilder &operator<<(StringBuilder &string_builder, const FileGcParameters &parameters);

}  // namespace td
