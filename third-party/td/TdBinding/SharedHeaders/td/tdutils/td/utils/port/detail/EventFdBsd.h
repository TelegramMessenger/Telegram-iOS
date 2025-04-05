//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

#ifdef TD_EVENTFD_BSD

#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/EventFdBase.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Status.h"

namespace td {
namespace detail {

class EventFdBsd final : public EventFdBase {
  SocketFd in_;
  SocketFd out_;

 public:
  EventFdBsd() = default;

  void init() final;

  bool empty() final;

  void close() final;

  Status get_pending_error() final TD_WARN_UNUSED_RESULT;

  PollableFdInfo &get_poll_info() final;

  void release() final;

  void acquire() final;

  void wait(int timeout_ms) final;
};

}  // namespace detail
}  // namespace td

#endif
