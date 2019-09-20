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
#include "td/actor/common.h"
#include "td/actor/ActorId.h"

namespace td {
namespace actor {

template <class ActorType>
class ActorShared {
 public:
  using ActorT = ActorType;
  ActorShared() = default;
  template <class OtherActorType>
  ActorShared(ActorId<OtherActorType> id, uint64 token) : id_(std::move(id)), token_(token) {
    CHECK(token_ != 0);
  }
  template <class OtherActorType>
  ActorShared(ActorShared<OtherActorType> &&other) : id_(other.release()), token_(other.token()) {
  }
  template <class OtherActorType>
  ActorShared(ActorOwn<OtherActorType> &&other) : id_(other.release()), token_(other.token()) {
  }
  template <class OtherActorType>
  ActorShared &operator=(ActorShared<OtherActorType> &&other) {
    reset(other.release(), other.token());
  }
  ActorShared(ActorShared &&other) : id_(other.release()), token_(other.token()) {
  }
  ActorShared &operator=(ActorShared &&other) {
    reset(other.release(), other.token());
    return *this;
  }
  ActorShared(const ActorShared &) = delete;
  ActorShared &operator=(const ActorShared &) = delete;
  ~ActorShared() {
    reset();
  }

  uint64 token() const {
    return token_;
  }
  bool empty() const {
    return id_.empty();
  }
  bool is_alive() const {
    return id_.is_alive();
  }
  ActorId<ActorType> get() const {
    return id_;
  }
  ActorId<ActorType> release() {
    return std::move(id_);
  }
  ActorType &get_actor_unsafe() const {
    return (*this)->get_actor_unsafe();
  }
  void reset(ActorId<ActorType> other = ActorId<ActorType>(), uint64 link_token = core::EmptyLinkToken) {
    static_assert(sizeof(ActorType) > 0, "Can't use ActorShared with incomplete type");
    hangup();
    id_ = other;
    token_ = link_token;
  }
  const ActorId<ActorType> *operator->() const {
    return &id_;
  }

  detail::ActorRef as_actor_ref() const {
    CHECK(!empty());
    return detail::ActorRef(*id_.actor_info_ptr(), token_);
  }

 private:
  ActorId<ActorType> id_;
  uint64 token_;

  void hangup() const {
    if (empty()) {
      return;
    }
    detail::send_message(as_actor_ref(), detail::ActorMessageCreator::hangup_shared());
  }
};

template <class ToActorType, class FromActorType>
ActorShared<ToActorType> actor_dynamic_cast(ActorShared<FromActorType> from) {
  return ActorShared<ToActorType>(td::actor::actor_dynamic_cast<ToActorType>(from.release()), from.token());
}

// common interface
namespace core {  // for ADL
template <class SelfT>
ActorShared<SelfT> actor_shared(SelfT *self, uint64 id = static_cast<uint64>(-1)) {
  return ActorShared<SelfT>(actor_id(self), id);
}

inline ActorShared<> actor_shared() {
  return actor_shared(&core::ActorExecuteContext::get()->actor());
}
}  // namespace core
using core::actor_shared;
}  // namespace actor
}  // namespace td
