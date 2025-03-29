//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AlarmManager.h"

#include "td/telegram/Global.h"

#include "td/utils/Status.h"

namespace td {

AlarmManager::AlarmManager(ActorShared<> parent) : parent_(std::move(parent)) {
  alarm_timeout_.set_callback(on_alarm_timeout_callback);
  alarm_timeout_.set_callback_data(static_cast<void *>(this));
}

void AlarmManager::tear_down() {
  while (!pending_alarms_.empty()) {
    auto it = pending_alarms_.begin();
    auto alarm_id = it->first;
    auto promise = std::move(it->second);
    pending_alarms_.erase(it);
    promise.set_error(G()->request_aborted_error());
    alarm_timeout_.cancel_timeout(alarm_id);
  }
  parent_.reset();
}

void AlarmManager::on_alarm_timeout_callback(void *alarm_manager_ptr, int64 alarm_id) {
  auto alarm_manager = static_cast<AlarmManager *>(alarm_manager_ptr);
  auto alarm_manager_id = alarm_manager->actor_id(alarm_manager);
  send_closure_later(alarm_manager_id, &AlarmManager::on_alarm_timeout, alarm_id);
}

void AlarmManager::on_alarm_timeout(int64 alarm_id) {
  auto it = pending_alarms_.find(alarm_id);
  if (it == pending_alarms_.end()) {
    return;
  }
  auto promise = std::move(it->second);
  pending_alarms_.erase(alarm_id);
  promise.set_value(Unit());
}

void AlarmManager::set_alarm(double seconds, Promise<Unit> &&promise) {
  if (seconds < 0 || seconds > 3e9) {
    return promise.set_error(Status::Error(400, "Wrong parameter seconds specified"));
  }

  auto alarm_id = alarm_id_++;
  pending_alarms_.emplace(alarm_id, std::move(promise));
  alarm_timeout_.set_timeout_in(alarm_id, seconds);
}

}  // namespace td
