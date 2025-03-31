//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileLoadManager.h"

#include "td/utils/filesystem.h"
#include "td/utils/port/path.h"

namespace td {

void FileLoadManager::get_content(string file_path, Promise<BufferSlice> promise) {
  promise.set_result(read_file(file_path));
}

void FileLoadManager::read_file_part(string file_path, int64 offset, int64 count, Promise<string> promise) {
  promise.set_result(read_file_str(file_path, count, offset));
}

void FileLoadManager::unlink_file(string file_path, Promise<Unit> promise) {
  unlink(file_path).ignore();
  promise.set_value(Unit());
}

void FileLoadManager::check_full_local_location(FullLocalLocationInfo local_info, bool skip_file_size_checks,
                                                Promise<FullLocalLocationInfo> promise) {
  promise.set_result(::td::check_full_local_location(std::move(local_info), skip_file_size_checks));
}

void FileLoadManager::check_partial_local_location(PartialLocalFileLocation partial, Promise<Unit> promise) {
  auto status = ::td::check_partial_local_location(partial);
  if (status.is_error()) {
    promise.set_error(std::move(status));
  } else {
    promise.set_value(Unit());
  }
}

}  // namespace td
