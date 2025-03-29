//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileGcParameters.h"

#include "td/telegram/Global.h"

#include "td/utils/format.h"
#include "td/utils/misc.h"

namespace td {

FileGcParameters::FileGcParameters(int64 size, int32 ttl, int32 count, int32 immunity_delay,
                                   vector<FileType> file_types, vector<DialogId> owner_dialog_ids,
                                   vector<DialogId> exclude_owner_dialog_ids, int32 dialog_limit)
    : file_types_(std::move(file_types))
    , owner_dialog_ids_(std::move(owner_dialog_ids))
    , exclude_owner_dialog_ids_(std::move(exclude_owner_dialog_ids))
    , dialog_limit_(dialog_limit) {
  max_files_size_ = size >= 0 ? size : G()->get_option_integer("storage_max_files_size", 100 << 10) << 10;

  max_time_from_last_access_ =
      ttl >= 0 ? ttl : narrow_cast<int32>(G()->get_option_integer("storage_max_time_from_last_access", 60 * 60 * 23));

  max_file_count_ = count >= 0 ? count : narrow_cast<int32>(G()->get_option_integer("storage_max_file_count", 40000));

  immunity_delay_ = immunity_delay >= 0
                        ? immunity_delay
                        : narrow_cast<int32>(G()->get_option_integer("storage_immunity_delay", 60 * 60));
}

StringBuilder &operator<<(StringBuilder &string_builder, const FileGcParameters &parameters) {
  return string_builder << "FileGcParameters[" << tag("max_files_size", parameters.max_files_size_)
                        << tag("max_time_from_last_access", parameters.max_time_from_last_access_)
                        << tag("max_file_count", parameters.max_file_count_)
                        << tag("immunity_delay", parameters.immunity_delay_)
                        << tag("file_types", parameters.file_types_)
                        << tag("owner_dialog_ids", parameters.owner_dialog_ids_)
                        << tag("exclude_owner_dialog_ids", parameters.exclude_owner_dialog_ids_)
                        << tag("dialog_limit", parameters.dialog_limit_) << ']';
}

}  // namespace td
