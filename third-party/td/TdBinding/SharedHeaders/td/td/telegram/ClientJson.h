//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Client.h"

#include "td/utils/FlatHashMap.h"
#include "td/utils/Slice.h"

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

namespace td {

// TODO can be removed in TDLib 2.0
class ClientJson final {
 public:
  void send(Slice request);

  const char *receive(double timeout);

  static const char *execute(Slice request);

 private:
  Client client_;
  std::mutex mutex_;  // for extra_
  FlatHashMap<std::int64_t, std::string> extra_;
  std::atomic<std::uint64_t> extra_id_{1};
};

int json_create_client_id();

void json_send(int client_id, Slice request);

const char *json_receive(double timeout);

const char *json_execute(Slice request);

}  // namespace td
