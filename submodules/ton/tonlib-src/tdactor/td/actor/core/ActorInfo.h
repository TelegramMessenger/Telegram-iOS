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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/actor/core/ActorState.h"
#include "td/actor/core/ActorMailbox.h"

#include "td/utils/Heap.h"
#include "td/utils/List.h"
#include "td/utils/Time.h"
#include "td/utils/SharedObjectPool.h"

namespace td {
namespace actor {
namespace core {
class Actor;
class ActorInfo;
using ActorInfoPtr = SharedObjectPool<ActorInfo>::Ptr;
class ActorInfo : private HeapNode, private ListNode {
 public:
  ActorInfo(std::unique_ptr<Actor> actor, ActorState::Flags state_flags, Slice name)
      : actor_(std::move(actor)), name_(name.begin(), name.size()) {
    state_.set_flags_unsafe(state_flags);
    VLOG(actor) << "Create actor [" << name_ << "]";
  }
  ~ActorInfo() {
    VLOG(actor) << "Destroy actor [" << name_ << "]";
    CHECK(!actor_);
  }

  bool is_alive() const {
    return !state_.get_flags_unsafe().is_closed();
  }

  bool has_actor() const {
    return bool(actor_);
  }
  Actor &actor() {
    CHECK(has_actor());
    return *actor_;
  }
  Actor *actor_ptr() const {
    return actor_.get();
  }
  void destroy_actor() {
    actor_.reset();
  }
  ActorState &state() {
    return state_;
  }
  ActorMailbox &mailbox() {
    return mailbox_;
  }
  CSlice get_name() const {
    return name_;
  }

  HeapNode *as_heap_node() {
    return this;
  }
  static ActorInfo *from_heap_node(HeapNode *node) {
    return static_cast<ActorInfo *>(node);
  }

  Timestamp get_alarm_timestamp() const {
    return Timestamp::at(alarm_timestamp_at_.load(std::memory_order_relaxed));
  }
  void set_alarm_timestamp(Timestamp timestamp) {
    alarm_timestamp_at_.store(timestamp.at(), std::memory_order_relaxed);
  }

  void pin(ActorInfoPtr ptr) {
    CHECK(pin_.empty());
    CHECK(&*ptr == this);
    pin_ = std::move(ptr);
  }
  ActorInfoPtr unpin() {
    CHECK(!pin_.empty());
    return std::move(pin_);
  }

 private:
  std::unique_ptr<Actor> actor_;
  ActorState state_;
  ActorMailbox mailbox_;
  std::string name_;
  std::atomic<double> alarm_timestamp_at_{0};

  ActorInfoPtr pin_;
};

}  // namespace core
}  // namespace actor
}  // namespace td
