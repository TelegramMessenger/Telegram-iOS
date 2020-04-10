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

#include "td/utils/common.h"
#include "td/utils/bits.h"
#include "td/utils/format.h"

namespace td {
namespace actor {
namespace core {
class ActorSignals {
 public:
  ActorSignals() = default;
  uint32 raw() const {
    return raw_;
  }
  static ActorSignals create_raw(uint32 raw) {
    return ActorSignals(raw);
  }
  bool empty() const {
    return raw_ == 0;
  }
  bool has_signal(uint32 signal) const {
    return (raw_ & (1u << signal)) != 0;
  }
  void add_signal(uint32 signal) {
    raw_ |= (1u << signal);
  }
  void add_signals(ActorSignals signals) {
    raw_ |= signals.raw();
  }
  void clear_signal(uint32 signal) {
    raw_ &= ~(1u << signal);
  }
  uint32 first_signal() {
    if (!raw_) {
      return 0;
    }
    return td::count_trailing_zeroes_non_zero32(raw_);
  }
  friend StringBuilder &operator<<(StringBuilder &sb, ActorSignals signals) {
    sb << "S{";
    bool was = false;
    auto add_signal = [&](int signal, auto name) {
      if (signals.has_signal(signal)) {
        if (was) {
          sb << ",";
        } else {
          was = true;
        }
        sb << name;
      }
    };
    add_signal(Wakeup, "Wakeup");
    add_signal(Alarm, "Alarm");
    add_signal(Kill, "Kill");
    add_signal(Io, "Io");
    add_signal(Cpu, "Cpu");
    add_signal(StartUp, "StartUp");
    add_signal(Pop, "Pop");
    add_signal(Message, "Message");
    add_signal(Pause, "Pause");
    sb << "}";
    return sb;
  }
  enum Signal : uint32 {
    // Signals in order of priority
    Pause = 1,
    Kill = 2,  // immediate kill
    StartUp = 3,
    Wakeup = 4,
    Alarm = 5,
    Io = 6,   // move to io thread
    Cpu = 7,  // move to cpu thread
    // Two signals for mpmc queue logic
    //
    // PopSignal is set after actor is popped from queue
    // When processed it should set InQueue and Pause flags to false.
    //
    // MessagesSignal is set after new messages was added to actor
    // If owner of actor wish to delay message handling, she should set InQueue flag to true and
    // add actor into mpmc queue.
    Pop = 8,      // got popped from queue
    Message = 9,  // got new message
  };

  static ActorSignals one(uint32 signal) {
    ActorSignals res;
    res.add_signal(signal);
    return res;
  }

 private:
  uint32 raw_{0};
  friend class ActorState;
  explicit ActorSignals(uint32 raw) : raw_(raw) {
  }
};
}  // namespace core
}  // namespace actor
}  // namespace td
