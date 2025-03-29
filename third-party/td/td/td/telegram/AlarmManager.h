//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"
#include "td/actor/MultiTimeout.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"

namespace td {

class AlarmManager final : public Actor {
 public:
  explicit AlarmManager(ActorShared<> parent);

  void set_alarm(double seconds, Promise<Unit> &&promise);

 private:
  void tear_down() final;

  static void on_alarm_timeout_callback(void *alarm_manager_ptr, int64 alarm_id);

  void on_alarm_timeout(int64 alarm_id);

  ActorShared<> parent_;

  int64 alarm_id_ = 1;
  FlatHashMap<int64, Promise<Unit>> pending_alarms_;
  MultiTimeout alarm_timeout_{"AlarmTimeout"};
};

}  // namespace td
