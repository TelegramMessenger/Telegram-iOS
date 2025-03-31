//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/NetQueryStats.h"

#include "td/telegram/net/NetQuery.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

namespace td {

uint64 NetQueryStats::get_count() const {
  return count_.load(std::memory_order_relaxed);
}

void NetQueryStats::dump_pending_network_queries() {
  auto n = get_count();
  LOG(WARNING) << tag("pending net queries", n);

  if (!use_list_) {
    return;
  }
  decltype(n) i = 0;
  bool was_gap = false;
  auto &net_query_list = list_;
  auto guard = net_query_list.lock();
  for (auto begin = net_query_list.begin(), cur = net_query_list.end(); cur != begin; i++) {
    cur = cur->get_prev();
    if (i < 20 || i + 20 > n || i % (n / 20 + 1) == 0) {
      if (was_gap) {
        LOG(WARNING) << "...";
        was_gap = false;
      }
      const NetQueryDebug &debug = cur->get_data_unsafe();
      const NetQuery &nq = *static_cast<const NetQuery *>(cur);
      LOG(WARNING) << tag("user", lpad(PSTRING() << debug.my_id_, 10, ' ')) << nq
                   << tag("total flood", format::as_time(nq.total_timeout_))
                   << tag("since start", format::as_time(Time::now_cached() - debug.start_timestamp_))
                   << tag("state", debug.state_)
                   << tag("in this state", format::as_time(Time::now_cached() - debug.state_timestamp_))
                   << tag("state changed", debug.state_change_count_) << tag("resend count", debug.resend_count_)
                   << tag("fail count", debug.send_failed_count_) << tag("ack state", debug.ack_state_)
                   << tag("unknown", debug.unknown_state_);
    } else {
      was_gap = true;
    }
  }
}
}  // namespace td
