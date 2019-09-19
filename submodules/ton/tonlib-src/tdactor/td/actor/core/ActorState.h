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

#include "td/actor/core/ActorSignals.h"
#include "td/actor/core/SchedulerId.h"

#include "td/utils/common.h"
#include "td/utils/format.h"

#include <atomic>

namespace td {
namespace actor {
namespace core {
class ActorState {
 public:
  class Flags {
   public:
    Flags() = default;
    uint32 raw() const {
      return raw_;
    }
    uint32 &raw_ref() {
      return raw_;
    }
    SchedulerId get_scheduler_id() const {
      return SchedulerId{static_cast<uint8>(raw_ & SchedulerMask)};
    }
    void set_scheduler_id(SchedulerId id) {
      raw_ = (raw_ & ~SchedulerMask) | id.value();
    }

    bool is_shared() const {
      return check_flag(SharedFlag);
    }
    void set_shared(bool shared) {
      set_flag(SharedFlag, shared);
    }

    bool is_locked() const {
      return check_flag(LockFlag);
    }
    void set_locked(bool locked) {
      set_flag(LockFlag, locked);
    }

    bool is_migrate() const {
      return check_flag(MigrateFlag);
    }
    void set_migrate(bool migrate) {
      set_flag(MigrateFlag, migrate);
    }

    bool is_closed() const {
      return check_flag(ClosedFlag);
    }
    void set_closed(bool closed) {
      set_flag(ClosedFlag, closed);
    }

    bool is_in_queue() const {
      return check_flag(InQueueFlag);
    }
    void set_in_queue(bool in_queue) {
      set_flag(InQueueFlag, in_queue);
    }

    bool has_signals() const {
      return check_flag(SignalMask);
    }
    void clear_signals() {
      set_flag(SignalMask, false);
    }
    void set_signals(ActorSignals signals) {
      raw_ = (raw_ & ~SignalMask) | (signals.raw() << SignalOffset);
    }
    void add_signals(ActorSignals signals) {
      raw_ = raw_ | (signals.raw() << SignalOffset);
    }
    ActorSignals get_signals() const {
      return ActorSignals{(raw_ & SignalMask) >> SignalOffset};
    }
    friend StringBuilder &operator<<(StringBuilder &sb, Flags flags) {
      sb << "ActorFlags{" << flags.get_scheduler_id().value() << ", " << (flags.is_shared() ? "cpu " : "io ")
         << (flags.is_migrate() ? "migrate " : "") << (flags.is_closed() ? "closed " : "")
         << (flags.is_in_queue() ? "in_queue " : "") << flags.get_signals() << "}";

      return sb;
    }

   private:
    uint32 raw_{0};

    friend class ActorState;
    Flags(uint32 raw) : raw_(raw) {
    }

    bool check_flag(uint32 mask) const {
      return (raw_ & mask) != 0;
    }
    void set_flag(uint32 mask, bool flag) {
      raw_ = (raw_ & ~mask) | (flag * mask);
    }
  };

  Flags get_flags_unsafe() const {
    return Flags(state_.load(std::memory_order_relaxed));
  }
  void set_flags_unsafe(Flags flags) {
    state_.store(flags.raw(), std::memory_order_relaxed);
  }

 private:
  friend class ActorLocker;
  std::atomic<uint32> state_{0};
  enum : uint32 {
    SchedulerMask = 255,

    // Actors can be shared or not.
    // If actor is shared, than any thread may try to lock it
    // If actor is not shared, than it is owned by its scheduler, and only
    // its scheduler is allowed to access it
    // This flag may NOT change during the lifetime of an actor
    SharedFlag = 1 << 9,

    // Only shared actors need lock
    // Lock if somebody is going to unlock it eventually.
    // For example actor is locked, when some scheduler is executing its mailbox
    // Or it is locked when it is in Mpmc queue, so someone will pop it eventually.
    LockFlag = 1 << 10,

    // While actor is migrating from one scheduler to another no one is allowed to change it
    // Could not be set for shared actors.
    MigrateFlag = 1 << 11,

    // While set all messages are delayed
    // Dropped from flush_maibox
    // PauseFlag => InQueueFlag
    PauseFlag = 1 << 12,

    ClosedFlag = 1 << 13,

    InQueueFlag = 1 << 14,

    // Signals
    SignalOffset = 15,
    Signal = 1 << SignalOffset,
    WakeupSignalFlag = Signal << ActorSignals::Wakeup,
    AlarmSignalFlag = Signal << ActorSignals::Alarm,
    KillSignalFlag = Signal << ActorSignals::Kill,  // immediate kill
    IoSignalFlag = Signal << ActorSignals::Io,      // move to io thread
    CpuSignalFlag = Signal << ActorSignals::Cpu,    // move to cpu thread
    StartUpSignalFlag = Signal << ActorSignals::StartUp,
    MessageSignalFlag = Signal << ActorSignals::Message,
    PopSignalFlag = Signal << ActorSignals::Pop,
    PauseSignalFlag = Signal << ActorSignals::Pause,

    SignalMask = WakeupSignalFlag | AlarmSignalFlag | KillSignalFlag | IoSignalFlag | CpuSignalFlag |
                 StartUpSignalFlag | MessageSignalFlag | PopSignalFlag | PauseSignalFlag
  };
};
}  // namespace core
}  // namespace actor
}  // namespace td
