//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/ChangesProcessor.h"
#include "td/utils/common.h"

namespace td {

// It is not about handling gaps.
// It is about finding mem processed PTS.
// All checks must be done before.

class PtsManager {
 public:
  using PtsId = ChangesProcessor<int32>::Id;
  void init(int32 pts) {
    db_pts_ = pts;
    mem_pts_ = pts;
    state_helper_.clear();
  }

  // 0 if not a checkpoint
  PtsId add_pts(int32 pts) {
    if (pts > 0) {
      mem_pts_ = pts;
    }
    return state_helper_.add(pts);
  }

  // return db_pts
  int32 finish(PtsId pts_id) {
    state_helper_.finish(pts_id, [&](int32 pts) {
      if (pts != 0) {
        db_pts_ = pts;
      }
    });
    return db_pts_;
  }

  int32 db_pts() const {
    return db_pts_;
  }
  int32 mem_pts() const {
    return mem_pts_;
  }

 private:
  int32 db_pts_ = -1;
  int32 mem_pts_ = -1;
  ChangesProcessor<int32> state_helper_;
};

}  // namespace td
