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
#include "td/actor/core/ActorInfo.h"
#include "td/actor/core/Actor.h"

namespace td {
namespace actor {
namespace core {
class ActorInfoCreator {
 public:
  class Options {
   public:
    Options() = default;

    Options &with_name(Slice new_name) {
      name = new_name;
      return *this;
    }

    Options &on_scheduler(SchedulerId new_scheduler_id) {
      scheduler_id = new_scheduler_id;
      return *this;
    }
    bool has_scheduler() const {
      return scheduler_id.is_valid();
    }
    Options &with_poll(bool has_poll = true) {
      is_shared = !has_poll;
      return *this;
    }

   private:
    friend class ActorInfoCreator;
    Slice name;
    SchedulerId scheduler_id;
    bool is_shared{true};
    bool in_queue{true};
    //TODO: rename
  };

  //Create unlocked actor. One must send StartUp signal immediately.
  ActorInfoPtr create(std::unique_ptr<Actor> actor, const Options &args) {
    ActorState::Flags flags;
    flags.set_scheduler_id(args.scheduler_id);
    if (allow_shared_) {
      flags.set_shared(args.is_shared);
    }
    flags.set_in_queue(args.in_queue);
    flags.set_signals(ActorSignals::one(ActorSignals::StartUp));

    auto actor_info_ptr = pool_.alloc(std::move(actor), flags, args.name);
    actor_info_ptr->actor().set_actor_info_ptr(actor_info_ptr);
    return actor_info_ptr;
  }

  ActorInfoCreator() = default;
  explicit ActorInfoCreator(bool allow_shared) : allow_shared_(allow_shared) {
  }
  ActorInfoCreator(const ActorInfoCreator &) = delete;
  ActorInfoCreator &operator=(const ActorInfoCreator &) = delete;
  ActorInfoCreator(ActorInfoCreator &&other) = delete;
  ActorInfoCreator &operator=(ActorInfoCreator &&other) = delete;
  void clear() {
    pool_.for_each([](auto &actor_info) { actor_info.destroy_actor(); });
  }
  ~ActorInfoCreator() {
    clear();
  }
  void ensure_empty() {
    pool_.for_each([](auto &actor_info) { LOG(ERROR) << actor_info.get_name(); });
  }

 private:
  SharedObjectPool<ActorInfo> pool_;
  bool allow_shared_{true};
};

using ActorOptions = ActorInfoCreator::Options;
}  // namespace core
}  // namespace actor
}  // namespace td
