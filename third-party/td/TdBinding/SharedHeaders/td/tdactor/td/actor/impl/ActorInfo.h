//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/impl/Actor-decl.h"
#include "td/actor/impl/ActorInfo-decl.h"
#include "td/actor/impl/Scheduler-decl.h"

#include "td/utils/common.h"
#include "td/utils/Heap.h"
#include "td/utils/List.h"
#include "td/utils/logging.h"
#include "td/utils/ObjectPool.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"

#include <atomic>
#include <memory>
#include <utility>

namespace td {

inline StringBuilder &operator<<(StringBuilder &sb, const ActorInfo &info) {
  sb << info.get_name() << ":" << const_cast<void *>(static_cast<const void *>(&info)) << ":"
     << const_cast<void *>(static_cast<const void *>(info.get_context()));
  return sb;
}

inline void ActorInfo::init(int32 sched_id, Slice name, ObjectPool<ActorInfo>::OwnerPtr &&this_ptr, Actor *actor_ptr,
                            Deleter deleter, bool need_context, bool need_start_up) {
  CHECK(!is_running());
  CHECK(!is_migrating());
  sched_id_.store(sched_id, std::memory_order_relaxed);
  actor_ = actor_ptr;

  if (need_context) {
    context_ = Scheduler::context()->this_ptr_.lock();
    VLOG(actor) << "Set context " << context_.get() << " for " << name;
  }
#ifdef TD_DEBUG
  name_.assign(name.data(), name.size());
#endif

  actor_->set_info(std::move(this_ptr));
  deleter_ = deleter;
  need_context_ = need_context;
  need_start_up_ = need_start_up;
  is_running_ = false;
}

inline bool ActorInfo::need_context() const {
  return need_context_;
}

inline bool ActorInfo::need_start_up() const {
  return need_start_up_;
}

inline void ActorInfo::on_actor_moved(Actor *actor_new_ptr) {
  actor_ = actor_new_ptr;
}

inline void ActorInfo::clear() {
  CHECK(mailbox_.empty());
  CHECK(!actor_);
  CHECK(!is_running());
  CHECK(!is_migrating());
  // NB: must be in non-migrating state
  // store invalid scheduler identifier
  sched_id_.store((1 << 30) - 1, std::memory_order_relaxed);
  VLOG(actor) << "Clear context " << context_.get() << " for " << get_name();
  context_.reset();
}

inline void ActorInfo::destroy_actor() {
  if (!actor_) {
    return;
  }
  switch (deleter_) {
    case Deleter::Destroy:
      std::default_delete<Actor>()(actor_);
      break;
    case Deleter::None:
      break;
  }
  actor_ = nullptr;
  mailbox_.clear();
}

template <class ActorT>
ActorOwn<ActorT> ActorInfo::transfer_ownership_to_scheduler(unique_ptr<ActorT> actor) {
  CHECK(!empty());
  CHECK(deleter_ == Deleter::None);
  ActorT *actor_ptr = actor.release();
  CHECK(actor_ == static_cast<Actor *>(actor_ptr));
  actor_ = static_cast<Actor *>(actor_ptr);
  deleter_ = Deleter::Destroy;
  return ActorOwn<ActorT>(actor_id(actor_ptr));
}

inline bool ActorInfo::empty() const {
  return actor_ == nullptr;
}

inline void ActorInfo::start_migrate(int32 to_sched_id) {
  sched_id_.store(to_sched_id | (1 << 30), std::memory_order_relaxed);
}
inline std::pair<int32, bool> ActorInfo::migrate_dest_flag_atomic() const {
  int32 sched_id = sched_id_.load(std::memory_order_relaxed);
  return std::make_pair(sched_id & ~(1 << 30), (sched_id & (1 << 30)) != 0);
}
inline void ActorInfo::finish_migrate() {
  sched_id_.store(migrate_dest(), std::memory_order_relaxed);
}
inline bool ActorInfo::is_migrating() const {
  return migrate_dest_flag_atomic().second;
}
inline int32 ActorInfo::migrate_dest() const {
  return migrate_dest_flag_atomic().first;
}

inline ActorId<> ActorInfo::actor_id() {
  return actor_id(actor_);
}

template <class SelfT>
ActorId<SelfT> ActorInfo::actor_id(SelfT *self) {
  return actor_->actor_id(self);
}

inline Actor *ActorInfo::get_actor_unsafe() {
  return actor_;
}
inline const Actor *ActorInfo::get_actor_unsafe() const {
  return actor_;
}

inline std::shared_ptr<ActorContext> ActorInfo::set_context(std::shared_ptr<ActorContext> context) {
  CHECK(is_running());
  context->this_ptr_ = context;
  if (Scheduler::context()->tag_) {
    context->set_tag(Scheduler::context()->tag_);
  }
  std::swap(context_, context);
  Scheduler::context() = context_.get();
  Scheduler::on_context_updated();
  return context;
}

inline std::weak_ptr<ActorContext> ActorInfo::get_context_weak_ptr() const {
  return context_;
}

inline const ActorContext *ActorInfo::get_context() const {
  return context_.get();
}

inline ActorContext *ActorInfo::get_context() {
  return context_.get();
}

inline CSlice ActorInfo::get_name() const {
#ifdef TD_DEBUG
  return name_;
#else
  return "";
#endif
}

inline void ActorInfo::start_run() {
  VLOG(actor) << "Start run actor: " << *this;
  LOG_CHECK(!is_running_) << "Recursive call of actor " << get_name();
  is_running_ = true;
}
inline void ActorInfo::finish_run() {
  is_running_ = false;
  if (!empty()) {
    VLOG(actor) << "Stop run actor: " << *this;
  }
}

inline bool ActorInfo::is_running() const {
  return is_running_;
}

inline HeapNode *ActorInfo::get_heap_node() {
  return this;
}
inline const HeapNode *ActorInfo::get_heap_node() const {
  return this;
}
inline ActorInfo *ActorInfo::from_heap_node(HeapNode *node) {
  return static_cast<ActorInfo *>(node);
}
inline ListNode *ActorInfo::get_list_node() {
  return this;
}
inline const ListNode *ActorInfo::get_list_node() const {
  return this;
}
inline ActorInfo *ActorInfo::from_list_node(ListNode *node) {
  return static_cast<ActorInfo *>(node);
}

}  // namespace td
