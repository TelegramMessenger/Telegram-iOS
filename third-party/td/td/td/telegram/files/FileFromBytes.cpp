//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/files/FileFromBytes.h"

#include "td/telegram/files/FileLoaderUtils.h"

#include "td/utils/common.h"
#include "td/utils/misc.h"

namespace td {

FileFromBytes::FileFromBytes(FileType type, BufferSlice bytes, string name, unique_ptr<Callback> callback)
    : type_(type), bytes_(std::move(bytes)), name_(std::move(name)), callback_(std::move(callback)) {
}

void FileFromBytes::wakeup() {
  auto size = narrow_cast<int64>(bytes_.size());
  auto r_result = save_file_bytes(type_, std::move(bytes_), name_);
  if (r_result.is_error()) {
    callback_->on_error(r_result.move_as_error());
  } else {
    callback_->on_ok(r_result.ok(), size);
  }
}

}  // namespace td
