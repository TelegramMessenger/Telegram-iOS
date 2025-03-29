//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/files/FileLocation.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class FileLoadManager final : public Actor {
 public:
  void get_content(string file_path, Promise<BufferSlice> promise);

  void read_file_part(string file_path, int64 offset, int64 count, Promise<string> promise);

  void unlink_file(string file_path, Promise<Unit> promise);

  void check_full_local_location(FullLocalLocationInfo local_info, bool skip_file_size_checks,
                                 Promise<FullLocalLocationInfo> promise);

  void check_partial_local_location(PartialLocalFileLocation partial, Promise<Unit> promise);
};

}  // namespace td
