//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/impl/ActorInfo-decl.h"
#include "td/actor/impl/Scheduler-decl.h"

#include "td/utils/common.h"
#include "td/utils/Heap.h"
#include "td/utils/logging.h"
#include "td/utils/ObjectPool.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Time.h"

#include <atomic>
#include <tuple>
#include <utility>

namespace td {

/*** EventGuard ***/
class EventGuard {
 public:
  EventGuard(Scheduler *scheduler, ActorInfo *actor_info);

  bool can_run() const {
    return event_context_.flags == 0;
  }

  EventGuard(const EventGuard &) = delete;
  EventGuard &operator=(const EventGuard &) = delete;
  EventGuard(EventGuard &&) = delete;
  EventGuard &operator=(EventGuard &&) = delete;
  ~EventGuard();

 private:
  Scheduler::EventContext event_context_;
  Scheduler::EventContext *event_context_ptr_;
  Scheduler *scheduler_;
  ActorContext *save_context_;
  const char *save_log_tag2_;

  void swap_context(ActorInfo *info);
};

/*** Scheduler ***/
inline SchedulerGuard Scheduler::get_guard() {
  return SchedulerGuard(this);
}

inline SchedulerGuard Scheduler::get_const_guard() {
  return SchedulerGuard(this, false);
}

inline int32 Scheduler::sched_id() const {
  return sched_id_;
}

inline int32 Scheduler::sched_count() const {
  return sched_n_;
}

template <class ActorT, class... Args>
ActorOwn<ActorT> Scheduler::create_actor(Slice name, Args &&...args) {
  return register_actor_impl(name, new ActorT(std::forward<Args>(args)...), Actor::Deleter::Destroy, sched_id_);
}

template <class ActorT, class... Args>
ActorOwn<ActorT> Scheduler::create_actor_on_scheduler(Slice name, int32 sched_id, Args &&...args) {
  return register_actor_impl(name, new ActorT(std::forward<Args>(args)...), Actor::Deleter::Destroy, sched_id);
}

template <class ActorT>
ActorOwn<ActorT> Scheduler::register_actor(Slice name, ActorT *actor_ptr, int32 sched_id) {
  return register_actor_impl(name, actor_ptr, Actor::Deleter::None, sched_id);
}

template <class ActorT>
ActorOwn<ActorT> Scheduler::register_actor(Slice name, unique_ptr<ActorT> actor_ptr, int32 sched_id) {
  return register_actor_impl(name, actor_ptr.release(), Actor::Deleter::Destroy, sched_id);
}

template <class ActorT>
ActorOwn<ActorT> Scheduler::register_actor_impl(Slice name, ActorT *actor_ptr, Actor::Deleter deleter, int32 sched_id) {
  CHECK(has_guard_);
  if (sched_id == -1) {
    sched_id = sched_id_;
  }
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  sched_id = 0;
#endif
  LOG_CHECK(sched_id == sched_id_ || (0 <= sched_id && sched_id < static_cast<int32>(outbound_queues_.size())))
      << sched_id;
  auto info = actor_info_pool_->create_empty();
  actor_count_++;
  auto weak_info = info.get_weak();
  auto actor_info = info.get();
  actor_info->init(sched_id_, name, std::move(info), static_cast<Actor *>(actor_ptr), deleter,
                   ActorTraits<ActorT>::need_context, ActorTraits<ActorT>::need_start_up);
  VLOG(actor) << "Create actor " << *actor_info << " (actor_count = " << actor_count_ << ')';

  ActorId<ActorT> actor_id = weak_info->actor_id(actor_ptr);
  if (sched_id != sched_id_) {
    send_later(actor_id, Event::start());
    do_migrate_actor(actor_info, sched_id);
  } else {
    pending_actors_list_.put(weak_info->get_list_node());
    if (ActorTraits<ActorT>::need_start_up) {
      send_later(actor_id, Event::start());
    }
  }

  return ActorOwn<ActorT>(actor_id);
}

template <class ActorT>
ActorOwn<ActorT> Scheduler::register_existing_actor(unique_ptr<ActorT> actor_ptr) {
  CHECK(!actor_ptr->empty());
  auto actor_info = actor_ptr->get_info();
  CHECK(actor_info->migrate_dest_flag_atomic().first == sched_id_);
  return actor_info->transfer_ownership_to_scheduler(std::move(actor_ptr));
}

inline void Scheduler::destroy_actor(ActorInfo *actor_info) {
  VLOG(actor) << "Destroy actor " << *actor_info << " (actor_count = " << actor_count_ << ')';

  LOG_CHECK(actor_info->migrate_dest() == sched_id_) << actor_info->migrate_dest() << " " << sched_id_;
  cancel_actor_timeout(actor_info);
  actor_info->get_list_node()->remove();
  // called by ObjectPool
  // actor_info->clear();
  actor_count_--;
  CHECK(actor_count_ >= 0);
}

inline void Scheduler::send_to_scheduler(int32 sched_id, const ActorId<Actor> &actor_id, Event &&event) {
  if (sched_id == sched_id_) {
    ActorInfo *actor_info = actor_id.get_actor_info();
    pending_events_[actor_info].push_back(std::move(event));
  } else {
    send_to_other_scheduler(sched_id, actor_id, std::move(event));
  }
}

template <class T>
void Scheduler::destroy_on_scheduler(int32 sched_id, T &value) {
  if (!value.empty()) {
    destroy_on_scheduler_impl(sched_id, PromiseCreator::lambda([value = std::move(value)](Unit) {
                                // destroy value
                              }));
  }
}

template <class T>
void Scheduler::destroy_on_scheduler_unique_ptr(int32 sched_id, T &value) {
  if (value != nullptr) {
    destroy_on_scheduler_impl(sched_id, PromiseCreator::lambda([value = std::move(value)](Unit) {
                                // destroy value
                              }));
  }
}

template <class... ArgsT>
void Scheduler::destroy_on_scheduler(int32 sched_id, ArgsT &...values) {
  destroy_on_scheduler_impl(sched_id, PromiseCreator::lambda([values = std::make_tuple(std::move(values)...)](Unit) {
                              // destroy values
                            }));
}

inline void Scheduler::before_tail_send(const ActorId<> &actor_id) {
  // TODO
}

template <class RunFuncT, class EventFuncT>
void Scheduler::send_immediately_impl(const ActorId<> &actor_id, const RunFuncT &run_func,
                                      const EventFuncT &event_func) {
  ActorInfo *actor_info = actor_id.get_actor_info();
  if (unlikely(actor_info == nullptr || close_flag_)) {
    return;
  }

  int32 actor_sched_id;
  bool on_current_sched;
  bool can_send_immediately;
  get_actor_sched_id_to_send_immediately(actor_info, actor_sched_id, on_current_sched, can_send_immediately);

  if (likely(can_send_immediately)) {  // run immediately
    EventGuard guard(this, actor_info);
    run_func(actor_info);
  } else {
    if (on_current_sched) {
      add_to_mailbox(actor_info, event_func());
    } else {
      send_to_scheduler(actor_sched_id, actor_id, event_func());
    }
  }
}

template <class EventT>
void Scheduler::send_lambda_immediately(ActorRef actor_ref, EventT &&func) {
  return send_immediately_impl(
      actor_ref.get(),
      [&](ActorInfo *actor_info) {
        event_context_ptr_->link_token = actor_ref.token();
        func();
      },
      [&] {
        auto event = Event::from_lambda(std::forward<EventT>(func));
        event.set_link_token(actor_ref.token());
        return event;
      });
}

template <class EventT>
void Scheduler::send_lambda_later(ActorRef actor_ref, EventT &&func) {
  auto event = Event::from_lambda(std::forward<EventT>(func));
  event.set_link_token(actor_ref.token());
  return send_later_impl(actor_ref.get(), std::move(event));
}

template <class EventT>
void Scheduler::send_closure_immediately(ActorRef actor_ref, EventT &&closure) {
  return send_immediately_impl(
      actor_ref.get(),
      [&](ActorInfo *actor_info) {
        event_context_ptr_->link_token = actor_ref.token();
        closure.run(static_cast<typename EventT::ActorType *>(actor_info->get_actor_unsafe()));
      },
      [&] {
        auto event = Event::immediate_closure(std::forward<EventT>(closure));
        event.set_link_token(actor_ref.token());
        return event;
      });
}

template <class EventT>
void Scheduler::send_closure_later(ActorRef actor_ref, EventT &&closure) {
  auto event = Event::immediate_closure(std::forward<EventT>(closure));
  event.set_link_token(actor_ref.token());
  return send_later_impl(actor_ref.get(), std::move(event));
}

inline void Scheduler::send_immediately(ActorRef actor_ref, Event &&event) {
  event.set_link_token(actor_ref.token());
  return send_immediately_impl(
      actor_ref.get(), [&](ActorInfo *actor_info) { do_event(actor_info, std::move(event)); },
      [&] { return std::move(event); });
}

inline void Scheduler::send_later(ActorRef actor_ref, Event &&event) {
  event.set_link_token(actor_ref.token());
  return send_later_impl(actor_ref.get(), std::move(event));
}

inline void Scheduler::subscribe(PollableFd fd, PollFlags flags) {
  instance()->poll_.subscribe(std::move(fd), flags);
}

inline void Scheduler::unsubscribe(PollableFdRef fd) {
  instance()->poll_.unsubscribe(std::move(fd));
}

inline void Scheduler::unsubscribe_before_close(PollableFdRef fd) {
  instance()->poll_.unsubscribe_before_close(std::move(fd));
}

inline void Scheduler::yield_actor(Actor *actor) {
  yield_actor(actor->get_info());
}
inline void Scheduler::yield_actor(ActorInfo *actor_info) {
  send_later(actor_info->actor_id(), Event::yield());
}

inline void Scheduler::stop_actor(Actor *actor) {
  stop_actor(actor->get_info());
}
inline void Scheduler::stop_actor(ActorInfo *actor_info) {
  CHECK(event_context_ptr_->actor_info == actor_info);
  event_context_ptr_->flags |= EventContext::Stop;
}

inline uint64 Scheduler::get_link_token(Actor *actor) {
  return get_link_token(actor->get_info());
}
inline uint64 Scheduler::get_link_token(ActorInfo *actor_info) {
  LOG_CHECK(event_context_ptr_->actor_info == actor_info) << actor_info->get_name();
  return event_context_ptr_->link_token;
}

inline void Scheduler::finish_migrate_actor(Actor *actor) {
  register_migrated_actor(actor->get_info());
}

inline double Scheduler::get_actor_timeout(const Actor *actor) const {
  return get_actor_timeout(actor->get_info());
}
inline void Scheduler::set_actor_timeout_in(Actor *actor, double timeout) {
  set_actor_timeout_in(actor->get_info(), timeout);
}
inline void Scheduler::set_actor_timeout_at(Actor *actor, double timeout_at) {
  set_actor_timeout_at(actor->get_info(), timeout_at);
}
inline void Scheduler::cancel_actor_timeout(Actor *actor) {
  cancel_actor_timeout(actor->get_info());
}

inline void Scheduler::cancel_actor_timeout(ActorInfo *actor_info) {
  HeapNode *heap_node = actor_info->get_heap_node();
  if (heap_node->in_heap()) {
    timeout_queue_.erase(heap_node);
  }
}

inline void Scheduler::finish() {
  if (callback_) {
    callback_->on_finish();
  }
  yield();
}

inline void Scheduler::yield() {
  yield_flag_ = true;
}

inline void Scheduler::wakeup() {
  std::atomic_thread_fence(std::memory_order_release);
#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  inbound_queue_->writer_put({});
#endif
}

inline void Scheduler::run(Timestamp timeout) {
  auto guard = get_guard();
  run_no_guard(timeout);
}

/*** Interface to current scheduler ***/
template <class ActorT, class... Args>
ActorOwn<ActorT> create_actor(Slice name, Args &&...args) {
  return Scheduler::instance()->create_actor<ActorT>(name, std::forward<Args>(args)...);
}

template <class ActorT, class... Args>
ActorOwn<ActorT> create_actor_on_scheduler(Slice name, int32 sched_id, Args &&...args) {
  return Scheduler::instance()->create_actor_on_scheduler<ActorT>(name, sched_id, std::forward<Args>(args)...);
}

template <class ActorT>
ActorOwn<ActorT> register_actor(Slice name, ActorT *actor_ptr, int32 sched_id) {
  return Scheduler::instance()->register_actor<ActorT>(name, actor_ptr, sched_id);
}

template <class ActorT>
ActorOwn<ActorT> register_actor(Slice name, unique_ptr<ActorT> actor_ptr, int32 sched_id) {
  return Scheduler::instance()->register_actor<ActorT>(name, std::move(actor_ptr), sched_id);
}

template <class ActorT>
ActorOwn<ActorT> register_existing_actor(unique_ptr<ActorT> actor_ptr) {
  return Scheduler::instance()->register_existing_actor(std::move(actor_ptr));
}

}  // namespace td
