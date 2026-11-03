//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"

#include "td/utils/Time.h"

#include <queue>

namespace td {

class DelayDispatcher final : public Actor {
 public:
  DelayDispatcher(double default_delay, ActorShared<> parent)
      : default_delay_(default_delay), parent_(std::move(parent)) {
  }

  void send_with_callback(NetQueryPtr query, ActorShared<NetQueryCallback> callback);
  void send_with_callback_and_delay(NetQueryPtr query, ActorShared<NetQueryCallback> callback, double delay);

  void close_silent();

 private:
  struct Query {
    NetQueryPtr net_query;
    ActorShared<NetQueryCallback> callback;
    double delay;
  };
  std::queue<Query> queue_;
  Timestamp wakeup_at_;
  double default_delay_;
  ActorShared<> parent_;

  void loop() final;
  void tear_down() final;
};

}  // namespace td
