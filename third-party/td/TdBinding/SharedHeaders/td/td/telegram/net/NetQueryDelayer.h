//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetQuery.h"

#include "td/actor/actor.h"
#include "td/actor/SignalSlot.h"

#include "td/utils/Container.h"

namespace td {

class NetQueryDelayer final : public Actor {
 public:
  explicit NetQueryDelayer(ActorShared<> parent) : parent_(std::move(parent)) {
  }
  void delay(NetQueryPtr query);

 private:
  struct QuerySlot {
    NetQueryPtr query_;
    Slot timeout_;
  };
  Container<QuerySlot> container_;
  ActorShared<> parent_;
  void wakeup() final;

  void on_slot_event(uint64 id);

  void tear_down() final;
};

}  // namespace td
