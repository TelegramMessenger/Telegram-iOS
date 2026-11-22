//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/impl/Actor-decl.h"
#include "td/actor/impl/EventFull-decl.h"
#include "td/actor/impl/Scheduler-decl.h"

#include "td/utils/common.h"
#include "td/utils/ObjectPool.h"
#include "td/utils/Slice.h"

#include <memory>
#include <type_traits>
#include <utility>

namespace td {

inline Actor::Actor(Actor &&other) noexcept {
  CHECK(info_.empty());
  info_ = std::move(other.info_);
  if (!empty()) {
    info_->on_actor_moved(this);
  }
}
inline Actor &Actor::operator=(Actor &&other) noexcept {
  CHECK(info_.empty());
  info_ = std::move(other.info_);
  if (!empty()) {
    info_->on_actor_moved(this);
  }
  return *this;
}

inline void Actor::notify() {
  yield();
}

// proxy to scheduler
inline void Actor::yield() {
  Scheduler::instance()->yield_actor(this);
}
inline void Actor::stop() {
  Scheduler::instance()->stop_actor(this);
}
inline void Actor::do_stop() {
  Scheduler::instance()->do_stop_actor(this);
  CHECK(empty());
}
inline bool Actor::has_timeout() const {
  return get_info()->get_heap_node()->in_heap();
}
inline double Actor::get_timeout() const {
  return Scheduler::instance()->get_actor_timeout(this);
}
inline void Actor::set_timeout_in(double timeout_in) {
  Scheduler::instance()->set_actor_timeout_in(this, timeout_in);
}
inline void Actor::set_timeout_at(double timeout_at) {
  Scheduler::instance()->set_actor_timeout_at(this, timeout_at);
}
inline void Actor::cancel_timeout() {
  Scheduler::instance()->cancel_actor_timeout(this);
}
inline void Actor::migrate(int32 sched_id) {
  Scheduler::instance()->migrate_actor(this, sched_id);
}
inline void Actor::do_migrate(int32 sched_id) {
  Scheduler::instance()->do_migrate_actor(this, sched_id);
}

template <class ActorType>
std::enable_if_t<std::is_base_of<Actor, ActorType>::value> start_migrate(ActorType &obj, int32 sched_id) {
  if (!obj.empty()) {
    Scheduler::instance()->start_migrate_actor(&obj, sched_id);
  }
}

template <class ActorType>
std::enable_if_t<std::is_base_of<Actor, ActorType>::value> finish_migrate(ActorType &obj) {
  if (!obj.empty()) {
    Scheduler::instance()->finish_migrate_actor(&obj);
  }
}

inline uint64 Actor::get_link_token() {
  return Scheduler::instance()->get_link_token(this);
}

inline std::weak_ptr<ActorContext> Actor::get_context_weak_ptr() const {
  return info_->get_context_weak_ptr();
}

inline std::shared_ptr<ActorContext> Actor::set_context(std::shared_ptr<ActorContext> context) {
  return info_->set_context(std::move(context));
}

inline string Actor::set_tag(string tag) {
  auto *ctx = info_->get_context();
  string old_tag;
  if (ctx->tag_) {
    old_tag = ctx->tag_;
  }
  ctx->set_tag(std::move(tag));
  Scheduler::on_context_updated();
  return old_tag;
}

inline void Actor::set_info(ObjectPool<ActorInfo>::OwnerPtr &&info) {
  info_ = std::move(info);
}

inline ActorInfo *Actor::get_info() {
  return &*info_;
}
inline const ActorInfo *Actor::get_info() const {
  return &*info_;
}

inline ObjectPool<ActorInfo>::OwnerPtr Actor::clear() {
  return std::move(info_);
}

inline bool Actor::empty() const {
  return info_.empty();
}

inline ActorId<> Actor::actor_id() {
  return actor_id(this);
}
template <class SelfT>
ActorId<SelfT> Actor::actor_id(SelfT *self) {
  CHECK(static_cast<Actor *>(self) == this);
  return ActorId<SelfT>(info_.get_weak());
}

template <class SelfT>
ActorShared<SelfT> Actor::actor_shared(SelfT *self, uint64 id) {
  CHECK(static_cast<Actor *>(self) == this);
  CHECK(id != 0);
  return ActorShared<SelfT>(actor_id(self), id);
}

template <class FuncT, class... ArgsT>
auto Actor::self_closure(FuncT &&func, ArgsT &&...args) {
  return self_closure(this, std::forward<FuncT>(func), std::forward<ArgsT>(args)...);
}

template <class SelfT, class FuncT, class... ArgsT>
auto Actor::self_closure(SelfT *self, FuncT &&func, ArgsT &&...args) {
  return EventCreator::closure(actor_id(self), std::forward<FuncT>(func), std::forward<ArgsT>(args)...);
}

template <class LambdaT>
auto Actor::self_lambda(LambdaT &&func) {
  return EventCreator::from_lambda(actor_id(), std::forward<LambdaT>(func));
}

inline Slice Actor::get_name() const {
  return info_->get_name();
}

}  // namespace td
