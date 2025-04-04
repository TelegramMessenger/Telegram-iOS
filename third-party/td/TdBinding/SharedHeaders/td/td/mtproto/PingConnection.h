//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/AuthData.h"
#include "td/mtproto/RawConnection.h"

#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {

class PingConnection {
 public:
  virtual ~PingConnection() = default;
  virtual PollableFdInfo &get_poll_info() = 0;
  virtual unique_ptr<RawConnection> move_as_raw_connection() = 0;
  virtual Status flush() = 0;
  virtual bool was_pong() const = 0;
  virtual double rtt() const = 0;

  static unique_ptr<PingConnection> create_req_pq(unique_ptr<RawConnection> raw_connection, size_t ping_count);
  static unique_ptr<PingConnection> create_ping_pong(unique_ptr<RawConnection> raw_connection,
                                                     unique_ptr<AuthData> auth_data);
};

}  // namespace mtproto
}  // namespace td
