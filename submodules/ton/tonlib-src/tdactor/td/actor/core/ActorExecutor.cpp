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
#include "td/actor/core/ActorExecutor.h"

#include "td/utils/ScopeGuard.h"

namespace td {
namespace actor {
namespace core {
void ActorExecutor::send_immediate(ActorMessage message) {
  CHECK(can_send_immediate());
  if (is_closed()) {
    return;
  }
  if (message.is_big()) {
    actor_info_.mailbox().reader().delay(std::move(message));
    pending_signals_.add_signal(ActorSignals::Message);
    actor_execute_context_.set_pause();
    return;
  }
  actor_execute_context_.set_link_token(message.get_link_token());
  message.run();
}

void ActorExecutor::send_immediate(ActorSignals signals) {
  CHECK(can_send_immediate());
  if (is_closed()) {
    return;
  }
  SCOPE_EXIT {
    pending_signals_.add_signals(signals);
  };
  while (flush_one_signal(signals) && !actor_execute_context_.has_immediate_flags()) {
  }
}

void ActorExecutor::send(ActorMessage message) {
  if (is_closed()) {
    return;
  }
  if (can_send_immediate()) {
    //LOG(ERROR) << "AE::send immediate";
    return send_immediate(std::move(message));
  }
  //LOG(ERROR) << "AE::send delayed";
  actor_info_.mailbox().push(std::move(message));
  pending_signals_.add_signal(ActorSignals::Message);
}

void ActorExecutor::send(ActorSignals signals) {
  if (is_closed()) {
    return;
  }

  if (can_send_immediate()) {
    return send_immediate(signals);
  }

  pending_signals_.add_signals(signals);
}

void ActorExecutor::start() noexcept {
  //LOG(ERROR) << "START " << actor_info_.get_name() << " " << tag("from_queue", options.from_queue);
  if (is_closed()) {
    return;
  }

  ActorSignals signals;
  SCOPE_EXIT {
    pending_signals_.add_signals(signals);
  };

  if (options_.from_queue) {
    signals.add_signal(ActorSignals::Pop);
  }

  actor_locker_.try_lock();
  flags_ = actor_locker_.flags();

  if (!actor_locker_.own_lock()) {
    return;
  }

  if (!actor_locker_.can_execute()) {
    CHECK(!options_.from_queue);
    return;
  }

  signals.add_signals(flags().get_signals());
  if (options_.from_queue) {
    signals.clear_signal(ActorSignals::Pause);
  }
  flags().clear_signals();

  if (flags_.is_closed()) {
    return;
  }

  actor_execute_context_.set_actor(&actor_info_.actor());

  while (flush_one_signal(signals)) {
    if (actor_execute_context_.has_immediate_flags()) {
      return;
    }
  }
  while (flush_one_message()) {
    if (actor_execute_context_.has_immediate_flags()) {
      return;
    }
  }
}

void ActorExecutor::finish() noexcept {
  //LOG(ERROR) << "FINISH " << actor_info_.get_name() << " " << tag("own_lock", actor_locker_.own_lock());
  if (!actor_locker_.own_lock()) {
    if (!pending_signals_.empty() && actor_locker_.add_signals(pending_signals_)) {
      flags_ = actor_locker_.flags();
      //LOG(ERROR) << "Own after finish " << actor_info_.get_name() << " " << format::as_binary(flags().raw());
    } else {
      //LOG(ERROR) << "DO FINISH " << actor_info_.get_name() << " " << flags();
      return;
    }
  } else {
    flags_.add_signals(pending_signals_);
  }

  CHECK(actor_locker_.own_lock());

  if (td::unlikely(actor_execute_context_.has_flags())) {
    flush_context_flags();
  }

  bool add_to_queue = false;
  while (true) {
    // Drop InQueue flag if has pop signal
    // Can't delay or ignore this signal
    auto signals = flags().get_signals();
    if (signals.has_signal(ActorSignals::Pop)) {
      signals.clear_signal(ActorSignals::Pop);
      flags().set_signals(signals);
      flags().set_in_queue(false);
      //LOG(ERROR) << "clear in_queue " << format::as_binary(flags().raw());
    }

    //LOG(ERROR) << tag("in_queue", flags().is_in_queue()) << tag("has_signals", flags().has_signals());
    if (flags_.is_closed()) {
      // Writing to mailbox and closing actor may happen concurrently
      // We must ensure that all messages in mailbox will be deleted
      // Note that an ActorExecute may have to delete messages that was added by itself.
      actor_info_.mailbox().clear();
    } else {
      // No need to add closed actor into queue.
      if (flags().has_signals() && !flags().is_in_queue()) {
        add_to_queue = true;
        flags().set_in_queue(true);
      }
    }
    ActorInfoPtr actor_info_ptr;
    if (add_to_queue) {
      actor_info_ptr = actor_info_.actor().get_actor_info_ptr();
    }
    if (actor_locker_.try_unlock(flags())) {
      if (add_to_queue) {
        dispatcher_.add_to_queue(std::move(actor_info_ptr), flags().get_scheduler_id(), !flags().is_shared());
      }
      break;
    }
    flags_ = actor_locker_.flags();
  }
  //LOG(ERROR) << "DO FINISH " << actor_info_.get_name() << " " << flags();
}

bool ActorExecutor::flush_one_signal(ActorSignals &signals) {
  auto signal = signals.first_signal();
  if (!signal) {
    return false;
  }
  switch (signal) {
    //NB: Signals will be handled in order of their value.
    // For clarity it conincides with order in this switch
    case ActorSignals::Pause:
      actor_execute_context_.set_pause();
      break;
    case ActorSignals::Kill:
      actor_execute_context_.set_stop();
      break;
    case ActorSignals::StartUp:
      actor_info_.actor().start_up();
      break;
    case ActorSignals::Wakeup:
      actor_info_.actor().wake_up();
      break;
    case ActorSignals::Alarm:
      if (actor_execute_context_.get_alarm_timestamp() && actor_execute_context_.get_alarm_timestamp().is_in_past()) {
        actor_execute_context_.alarm_timestamp() = Timestamp::never();
        actor_info_.actor().alarm();
      }
      break;
    case ActorSignals::Io:
    case ActorSignals::Cpu:
      LOG(FATAL) << "TODO";
      break;
    case ActorSignals::Message:
      pending_signals_.add_signal(ActorSignals::Message);
      actor_info_.mailbox().pop_all();
      break;
    case ActorSignals::Pop:
      flags().set_in_queue(false);
      break;
    default:
      UNREACHABLE();
  }
  signals.clear_signal(signal);
  return true;
}

bool ActorExecutor::flush_one_message() {
  auto message = actor_info_.mailbox().reader().read();
  //LOG(ERROR) << "flush one message " << !!message << " " << actor_info_.get_name();
  if (!message) {
    pending_signals_.clear_signal(ActorSignals::Message);
    return false;
  }
  if (message.is_big() && !options_.from_queue) {
    actor_info_.mailbox().reader().delay(std::move(message));
    actor_execute_context_.set_pause();
    return false;
  }

  actor_execute_context_.set_link_token(message.get_link_token());
  message.run();
  return true;
}

void ActorExecutor::flush_context_flags() {
  if (actor_execute_context_.get_stop()) {
    if (actor_info_.get_alarm_timestamp()) {
      actor_info_.set_alarm_timestamp(Timestamp::never());
      dispatcher_.set_alarm_timestamp(actor_info_.actor().get_actor_info_ptr());
    }
    flags_.set_closed(true);
    if (!flags_.get_signals().has_signal(ActorSignals::Signal::StartUp)) {
      actor_info_.actor().tear_down();
    }
    actor_info_.destroy_actor();
  } else {
    if (actor_execute_context_.get_pause()) {
      flags_.add_signals(ActorSignals::one(ActorSignals::Pause));
    }
    if (actor_execute_context_.get_yield()) {
      flags_.add_signals(ActorSignals::one(ActorSignals::Wakeup));
    }
    if (actor_execute_context_.get_alarm_flag()) {
      auto old_timestamp = actor_info_.get_alarm_timestamp();
      auto new_timestamp = actor_execute_context_.get_alarm_timestamp();
      if (!(old_timestamp == new_timestamp)) {
        actor_info_.set_alarm_timestamp(new_timestamp);
        dispatcher_.set_alarm_timestamp(actor_info_.actor().get_actor_info_ptr());
      }
    }
  }
}
}  // namespace core
}  // namespace actor
}  // namespace td
