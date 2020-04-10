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
#include "td/actor/common.h"

namespace td {
namespace actor {
template <class ActorType = core::Actor>
class ActorId;
template <class ActorType = core::Actor>
class ActorOwn;
template <class ActorType = core::Actor>
class ActorShared;
namespace core {
template <class SelfT>
ActorId<SelfT> actor_id(SelfT *self);
}

// Essentially ActorInfoWeakPtr with Type
template <class ActorType>
class ActorId {
 public:
  using ActorT = ActorType;
  ActorId() = default;
  ActorId(const ActorId &) = default;
  ActorId &operator=(const ActorId &) = default;
  ActorId(ActorId &&other) = default;
  ActorId &operator=(ActorId &&other) = default;

  // allow only conversion from child to parent
  template <class ToActorType, class = std::enable_if_t<std::is_base_of<ToActorType, ActorType>::value>>
  operator ActorId<ToActorType>() const {
    return ActorId<ToActorType>(ptr_);
  }

  template <class ToActorType, class FromActorType>
  friend ActorId<ToActorType> actor_dynamic_cast(ActorId<FromActorType> from);

  ActorType &get_actor_unsafe() const {
    return static_cast<ActorType &>(actor_info().actor());
  }
  bool empty() const {
    return !ptr_;
  }

  bool is_alive() const {
    return !empty() && actor_info().is_alive();
  }

  template <class... ArgsT>
  static ActorId<ActorType> create(ActorOptions &options, ArgsT &&... args) {
    return ActorId<ActorType>(detail::create_actor<ActorType>(options, std::forward<ArgsT>(args)...));
  }

  template <class OtherT>
  bool operator==(const ActorId<OtherT> &other) const {
    return ptr_ == other.ptr_;
  }

  detail::ActorRef as_actor_ref() const {
    CHECK(!empty());
    return detail::ActorRef(*actor_info_ptr());
  }

  const core::ActorInfoPtr &actor_info_ptr() const {
    return ptr_;
  }

  core::ActorInfo &actor_info() const {
    CHECK(ptr_);
    return *ptr_;
  }

 private:
  core::ActorInfoPtr ptr_;

  template <class OtherActorType>
  friend class ActorId;
  template <class OtherActorType>
  friend class ActorOwn;
  template <class OtherActorType>
  friend class ActorShared;

  explicit ActorId(core::ActorInfoPtr ptr) : ptr_(std::move(ptr)) {
  }

  template <class SelfT>
  friend ActorId<SelfT> core::actor_id(SelfT *self);
};
template <class ToActorType, class FromActorType>
ActorId<ToActorType> actor_dynamic_cast(ActorId<FromActorType> from) {
  static_assert(
      std::is_base_of<FromActorType, ToActorType>::value || std::is_base_of<ToActorType, FromActorType>::value,
      "Invalid actor dynamic conversion");
  auto res = ActorId<ToActorType>(std::move(from.ptr_));
  CHECK(dynamic_cast<ToActorType *>(&res.actor_info().actor()) == &res.get_actor_unsafe());
  return res;
}
namespace core {  // for ADL
template <class SelfT>
ActorId<SelfT> actor_id(SelfT *self) {
  CHECK(self);
  CHECK(static_cast<core::Actor *>(self) == &core::ActorExecuteContext::get()->actor());
  return ActorId<SelfT>(core::ActorExecuteContext::get()->actor().get_actor_info_ptr());
}

inline ActorId<> actor_id() {
  return actor_id(&core::ActorExecuteContext::get()->actor());
}
}  // namespace core
using core::actor_id;
}  // namespace actor
}  // namespace td
