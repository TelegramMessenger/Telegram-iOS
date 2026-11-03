//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetQueryCounter.h"

#include "td/utils/common.h"
#include "td/utils/TsList.h"

#include <atomic>

namespace td {

struct NetQueryDebug {
  double start_timestamp_ = 0;
  int64 my_id_ = 0;
  int32 resend_count_ = 0;
  string state_ = "empty";
  double state_timestamp_ = 0;
  int32 state_change_count_ = 0;
  int32 send_failed_count_ = 0;
  int32 ack_state_ = 0;
  bool unknown_state_ = false;
};

class NetQueryStats {
 public:
  NetQueryCounter register_query(TsListNode<NetQueryDebug> *query) {
    if (use_list_.load(std::memory_order_relaxed)) {
      list_.put(query);
    }
    return NetQueryCounter(&count_);
  }

  uint64 get_count() const;

  void dump_pending_network_queries();

 private:
  NetQueryCounter::Counter count_{0};
  std::atomic<bool> use_list_{true};
  TsList<NetQueryDebug> list_;
};

}  // namespace td
