//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileStats.h"

#include "td/actor/actor.h"

#include "td/utils/CancellationToken.h"
#include "td/utils/Promise.h"

namespace td {

class FileStatsWorker final : public Actor {
 public:
  FileStatsWorker(ActorShared<> parent, CancellationToken token)
      : parent_(std::move(parent)), token_(std::move(token)) {
  }
  void get_stats(bool need_all_files, bool split_by_owner_dialog_id, Promise<FileStats> promise);

 private:
  ActorShared<> parent_;
  CancellationToken token_;
};

}  // namespace td
