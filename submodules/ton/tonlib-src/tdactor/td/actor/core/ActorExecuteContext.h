/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/actor/core/Context.h"

#include "td/utils/logging.h"
#include "td/utils/Time.h"

#include <limits>

namespace td {
namespace actor {
namespace core {
class Actor;

enum : uint64 { EmptyLinkToken = std::numeric_limits<uint64>::max() };

class ActorExecuteContext : public Context<ActorExecuteContext> {
 public:
  explicit ActorExecuteContext(Actor *actor, Timestamp alarm_timestamp = Timestamp::never())
      : actor_(actor), alarm_timestamp_(alarm_timestamp) {
  }
  void set_actor(Actor *actor) {
    actor_ = actor;
  }
  Actor &actor() const {
    CHECK(actor_);
    return *actor_;
  }
  bool has_flags() const {
    return flags_ != 0;
  }
  bool has_immediate_flags() const {
    return (flags_ & ~(1 << Alarm)) != 0;
  }
  void set_stop() {
    flags_ |= 1 << Stop;
  }
  bool get_stop() const {
    return (flags_ & (1 << Stop)) != 0;
  }
  void set_pause() {
    flags_ |= 1 << Pause;
  }
  bool get_pause() const {
    return (flags_ & (1 << Pause)) != 0;
  }
  void clear_actor() {
    actor_ = nullptr;
  }
  void set_link_token(uint64 link_token) {
    link_token_ = link_token;
  }
  uint64 get_link_token() const {
    return link_token_;
  }
  Timestamp &alarm_timestamp() {
    flags_ |= 1 << Alarm;
    return alarm_timestamp_;
  }
  bool get_alarm_flag() const {
    return (flags_ & (1 << Alarm)) != 0;
  }
  Timestamp get_alarm_timestamp() const {
    return alarm_timestamp_;
  }
  void set_yield() {
    flags_ |= 1 << Yield;
  }
  bool get_yield() {
    return (flags_ & (1 << Yield)) != 0;
  }

 private:
  Actor *actor_;
  uint32 flags_{0};
  uint64 link_token_{EmptyLinkToken};
  Timestamp alarm_timestamp_;
  enum { Stop, Pause, Alarm, Yield };
};

}  // namespace core
}  // namespace actor
}  // namespace td
