//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/actor/impl/Scheduler.h"

#include "td/actor/impl/Actor.h"
#include "td/actor/impl/ActorId.h"
#include "td/actor/impl/ActorInfo.h"
#include "td/actor/impl/Event.h"
#include "td/actor/impl/EventFull.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/ExitGuard.h"
#include "td/utils/format.h"
#include "td/utils/List.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/MpscPollableQueue.h"
#include "td/utils/ObjectPool.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Promise.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

#include <functional>
#include <memory>
#include <utility>

namespace td {

int VERBOSITY_NAME(actor) = VERBOSITY_NAME(DEBUG) + 10;

TD_THREAD_LOCAL Scheduler *Scheduler::scheduler_;   // static zero-initialized
TD_THREAD_LOCAL ActorContext *Scheduler::context_;  // static zero-initialized

Scheduler::~Scheduler() {
  clear();
}

Scheduler *Scheduler::instance() {
  return scheduler_;
}

ActorContext *&Scheduler::context() {
  return context_;
}

void Scheduler::on_context_updated() {
  LOG_TAG = context_->tag_;
}

void Scheduler::set_scheduler(Scheduler *scheduler) {
  scheduler_ = scheduler;
}

void Scheduler::ServiceActor::set_queue(std::shared_ptr<MpscPollableQueue<EventFull>> queues) {
  inbound_ = std::move(queues);
}

void Scheduler::ServiceActor::start_up() {
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  CHECK(!inbound_);
#else
  if (!inbound_) {
    return;
  }
#if !TD_PORT_WINDOWS
  auto &fd = inbound_->reader_get_event_fd();
  Scheduler::subscribe(fd.get_poll_info().extract_pollable_fd(this), PollFlags::Read());
  subscribed_ = true;
#endif
  yield();
#endif
}

void Scheduler::ServiceActor::loop() {
  auto &queue = inbound_;
  int ready_n = queue->reader_wait_nonblock();
  VLOG(actor) << "Have " << ready_n << " pending events";
  if (ready_n == 0) {
    return;
  }
  while (ready_n-- > 0) {
    EventFull event = queue->reader_get_unsafe();
    if (event.actor_id().empty()) {
      if (event.data().empty()) {
        Scheduler::instance()->yield();
      } else {
        Scheduler::instance()->register_migrated_actor(static_cast<ActorInfo *>(event.data().data.ptr));
      }
    } else {
      VLOG(actor) << "Receive " << event.data();
      finish_migrate(event.data());
      event.try_emit();
    }
  }
  queue->reader_flush();
  yield();
}

void Scheduler::ServiceActor::tear_down() {
  if (!subscribed_) {
    return;
  }
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  CHECK(!inbound_);
#else
  if (!inbound_) {
    return;
  }
  auto &fd = inbound_->reader_get_event_fd();
  Scheduler::unsubscribe(fd.get_poll_info().get_pollable_fd_ref());
  subscribed_ = false;
#endif
}

/*** SchedlerGuard ***/
SchedulerGuard::SchedulerGuard(Scheduler *scheduler, bool lock) : scheduler_(scheduler) {
  if (lock) {
    // the next check can fail if OS killed the scheduler's thread without releasing the guard
    CHECK(!scheduler_->has_guard_);
    scheduler_->has_guard_ = true;
  }
  is_locked_ = lock;
  save_scheduler_ = Scheduler::instance();
  Scheduler::set_scheduler(scheduler_);

  // Scheduler::context() must be not null
  save_context_ = scheduler_->save_context_.get();
  save_tag_ = LOG_TAG;
  LOG_TAG = save_context_->tag_;
  std::swap(save_context_, Scheduler::context());
}

SchedulerGuard::~SchedulerGuard() {
  if (is_valid_.get()) {
    std::swap(save_context_, scheduler_->context());
    Scheduler::set_scheduler(save_scheduler_);
    if (is_locked_) {
      CHECK(scheduler_->has_guard_);
      scheduler_->has_guard_ = false;
    }
    LOG_TAG = save_tag_;
  }
}

/*** EventGuard ***/
EventGuard::EventGuard(Scheduler *scheduler, ActorInfo *actor_info) : scheduler_(scheduler) {
  actor_info->start_run();
  event_context_.actor_info = actor_info;
  event_context_ptr_ = &event_context_;

  save_context_ = actor_info->get_context();
#ifdef TD_DEBUG
  save_log_tag2_ = actor_info->get_name().c_str();
#endif
  swap_context(actor_info);
}

EventGuard::~EventGuard() {
  auto info = event_context_.actor_info;
  auto node = info->get_list_node();
  node->remove();
  if (info->mailbox_.empty()) {
    scheduler_->pending_actors_list_.put(node);
  } else {
    scheduler_->ready_actors_list_.put(node);
  }
  info->finish_run();
  swap_context(info);
  CHECK(!info->need_context() || save_context_ == info->get_context());
#ifdef TD_DEBUG
  LOG_CHECK(!info->need_context() || save_log_tag2_ == info->get_name().c_str())
      << info->need_context() << " " << info->empty() << " " << info->is_migrating() << " " << save_log_tag2_ << " "
      << info->get_name() << " " << scheduler_->close_flag_;
#endif
  if (event_context_.flags & Scheduler::EventContext::Stop) {
    scheduler_->do_stop_actor(info);
    return;
  }
  if (event_context_.flags & Scheduler::EventContext::Migrate) {
    scheduler_->do_migrate_actor(info, event_context_.dest_sched_id);
  }
}

void EventGuard::swap_context(ActorInfo *info) {
  std::swap(scheduler_->event_context_ptr_, event_context_ptr_);

  if (!info->need_context()) {
    return;
  }

#ifdef TD_DEBUG
  std::swap(LOG_TAG2, save_log_tag2_);
#endif

  auto *current_context_ptr = &Scheduler::context();
  if (save_context_ != *current_context_ptr) {
    std::swap(save_context_, *current_context_ptr);
    Scheduler::on_context_updated();
  }
}

void Scheduler::init(int32 id, std::vector<std::shared_ptr<MpscPollableQueue<EventFull>>> outbound,
                     Callback *callback) {
  save_context_ = std::make_shared<ActorContext>();
  save_context_->this_ptr_ = save_context_;
  save_context_->tag_ = LOG_TAG;

  auto guard = get_guard();

  callback_ = callback;
  actor_info_pool_ = make_unique<ObjectPool<ActorInfo>>();

  yield_flag_ = false;
  actor_count_ = 0;
  sched_id_ = 0;

  poll_.init();

  if (!outbound.empty()) {
    inbound_queue_ = std::move(outbound[id]);
  }
  outbound_queues_ = std::move(outbound);
  sched_id_ = id;
  sched_n_ = static_cast<int32>(outbound_queues_.size());
  service_actor_.set_queue(inbound_queue_);
  register_actor(PSLICE() << "ServiceActor" << id, &service_actor_).release();
}

void Scheduler::clear() {
  if (service_actor_.empty()) {
    return;
  }
  close_flag_ = true;
  auto guard = get_guard();

  // Stop all actors
  if (!service_actor_.empty()) {
    service_actor_.do_stop();
  }
  while (!pending_actors_list_.empty()) {
    auto actor_info = ActorInfo::from_list_node(pending_actors_list_.get());
    do_stop_actor(actor_info);
  }
  while (!ready_actors_list_.empty()) {
    auto actor_info = ActorInfo::from_list_node(ready_actors_list_.get());
    do_stop_actor(actor_info);
  }
  poll_.clear();

  if (callback_ && !ExitGuard::is_exited()) {
    // can't move lambda with unique_ptr inside into std::function
    auto ptr = actor_info_pool_.release();
    callback_->register_at_finish([ptr] { delete ptr; });
  } else {
    actor_info_pool_.reset();
  }
}

void Scheduler::do_event(ActorInfo *actor_info, Event &&event) {
  event_context_ptr_->link_token = event.link_token;
  auto actor = actor_info->get_actor_unsafe();
  VLOG(actor) << *actor_info << ' ' << event;
  switch (event.type) {
    case Event::Type::Start:
      actor->start_up();
      break;
    case Event::Type::Stop:
      actor->tear_down();
      break;
    case Event::Type::Yield:
      actor->wakeup();
      break;
    case Event::Type::Hangup:
      if (get_link_token(actor) != 0) {
        actor->hangup_shared();
      } else {
        actor->hangup();
      }
      break;
    case Event::Type::Timeout:
      actor->timeout_expired();
      break;
    case Event::Type::Raw:
      actor->raw_event(event.data);
      break;
    case Event::Type::Custom:
      event.data.custom_event->run(actor);
      break;
    case Event::Type::NoType:
    default:
      UNREACHABLE();
      break;
  }
  // can't clear event here. It may be already destroyed during destroy_actor
}

void Scheduler::get_actor_sched_id_to_send_immediately(const ActorInfo *actor_info, int32 &actor_sched_id,
                                                       bool &on_current_sched, bool &can_send_immediately) {
  bool is_migrating;
  std::tie(actor_sched_id, is_migrating) = actor_info->migrate_dest_flag_atomic();
  on_current_sched = !is_migrating && sched_id_ == actor_sched_id;
  CHECK(has_guard_ || !on_current_sched);
  can_send_immediately = on_current_sched && !actor_info->is_running() && actor_info->mailbox_.empty();
}

void Scheduler::send_later_impl(const ActorId<> &actor_id, Event &&event) {
  ActorInfo *actor_info = actor_id.get_actor_info();
  if (unlikely(actor_info == nullptr || close_flag_)) {
    return;
  }

  int32 actor_sched_id;
  bool is_migrating;
  std::tie(actor_sched_id, is_migrating) = actor_info->migrate_dest_flag_atomic();
  bool on_current_sched = !is_migrating && sched_id_ == actor_sched_id;
  CHECK(has_guard_ || !on_current_sched);

  if (on_current_sched) {
    add_to_mailbox(actor_info, std::move(event));
  } else {
    send_to_scheduler(actor_sched_id, actor_id, std::move(event));
  }
}

void Scheduler::register_migrated_actor(ActorInfo *actor_info) {
  VLOG(actor) << "Register migrated actor " << *actor_info << ", " << tag("actor_count", actor_count_);
  actor_count_++;
  LOG_CHECK(actor_info->is_migrating()) << *actor_info << ' ' << actor_count_ << ' ' << sched_id_ << ' '
                                        << actor_info->migrate_dest() << ' ' << actor_info->is_running() << ' '
                                        << close_flag_;
  CHECK(sched_id_ == actor_info->migrate_dest());
  // CHECK(!actor_info->is_running());
  actor_info->finish_migrate();
  for (auto &event : actor_info->mailbox_) {
    finish_migrate(event);
  }
  auto it = pending_events_.find(actor_info);
  if (it != pending_events_.end()) {
    append(actor_info->mailbox_, std::move(it->second));
    pending_events_.erase(it);
  }
  if (actor_info->mailbox_.empty()) {
    pending_actors_list_.put(actor_info->get_list_node());
  } else {
    ready_actors_list_.put(actor_info->get_list_node());
  }
  actor_info->get_actor_unsafe()->on_finish_migrate();
}

void Scheduler::send_to_other_scheduler(int32 sched_id, const ActorId<> &actor_id, Event &&event) {
  if (sched_id < sched_count()) {
    auto actor_info = actor_id.get_actor_info();
    if (actor_info) {
      VLOG(actor) << "Send to " << *actor_info << " on scheduler " << sched_id << ": " << event;
    } else {
      VLOG(actor) << "Send to scheduler " << sched_id << ": " << event;
    }
    start_migrate(event, sched_id);
    outbound_queues_[sched_id]->writer_put(EventCreator::event_unsafe(actor_id, std::move(event)));
    outbound_queues_[sched_id]->writer_flush();
  }
}

void Scheduler::run_on_scheduler(int32 sched_id, Promise<Unit> action) {
  if (sched_id >= 0 && sched_id_ != sched_id) {
    class Worker final : public Actor {
     public:
      explicit Worker(Promise<Unit> action) : action_(std::move(action)) {
      }

     private:
      Promise<Unit> action_;

      void start_up() final {
        action_.set_value(Unit());
        stop();
      }
    };
    create_actor_on_scheduler<Worker>("RunOnSchedulerWorker", sched_id, std::move(action)).release();
    return;
  }

  action.set_value(Unit());
}

void Scheduler::destroy_on_scheduler_impl(int32 sched_id, Promise<Unit> action) {
  auto empty_context = std::make_shared<ActorContext>();
  empty_context->this_ptr_ = empty_context;
  ActorContext *current_context = context_;
  context_ = empty_context.get();

  const char *current_tag = LOG_TAG;
  LOG_TAG = nullptr;

  run_on_scheduler(sched_id, std::move(action));

  context_ = current_context;
  LOG_TAG = current_tag;
}

void Scheduler::add_to_mailbox(ActorInfo *actor_info, Event &&event) {
  if (!actor_info->is_running()) {
    auto node = actor_info->get_list_node();
    node->remove();
    ready_actors_list_.put(node);
  }
  VLOG(actor) << "Add to mailbox: " << *actor_info << " " << event;
  actor_info->mailbox_.push_back(std::move(event));
}

void Scheduler::do_stop_actor(Actor *actor) {
  return do_stop_actor(actor->get_info());
}

void Scheduler::do_stop_actor(ActorInfo *actor_info) {
  CHECK(!actor_info->is_migrating());
  LOG_CHECK(actor_info->migrate_dest() == sched_id_) << actor_info->migrate_dest() << " " << sched_id_;
  ObjectPool<ActorInfo>::OwnerPtr owner_ptr;
  if (actor_info->need_start_up()) {
    EventGuard guard(this, actor_info);
    do_event(actor_info, Event::stop());
    owner_ptr = actor_info->get_actor_unsafe()->clear();
    // Actor context is visible in destructor
    actor_info->destroy_actor();
    event_context_ptr_->flags = 0;
  } else {
    owner_ptr = actor_info->get_actor_unsafe()->clear();
    actor_info->destroy_actor();
  }
  destroy_actor(actor_info);
}

void Scheduler::migrate_actor(Actor *actor, int32 dest_sched_id) {
  migrate_actor(actor->get_info(), dest_sched_id);
}

void Scheduler::migrate_actor(ActorInfo *actor_info, int32 dest_sched_id) {
  CHECK(event_context_ptr_->actor_info == actor_info);
  if (sched_id_ == dest_sched_id) {
    return;
  }
  event_context_ptr_->flags |= EventContext::Migrate;
  event_context_ptr_->dest_sched_id = dest_sched_id;
}

void Scheduler::do_migrate_actor(Actor *actor, int32 dest_sched_id) {
  do_migrate_actor(actor->get_info(), dest_sched_id);
}

void Scheduler::do_migrate_actor(ActorInfo *actor_info, int32 dest_sched_id) {
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  dest_sched_id = 0;
#endif
  if (sched_id_ == dest_sched_id) {
    return;
  }
  start_migrate_actor(actor_info, dest_sched_id);
  send_to_other_scheduler(dest_sched_id, ActorId<>(), Event::raw(actor_info));
}

void Scheduler::start_migrate_actor(Actor *actor, int32 dest_sched_id) {
  start_migrate_actor(actor->get_info(), dest_sched_id);
}

void Scheduler::start_migrate_actor(ActorInfo *actor_info, int32 dest_sched_id) {
  VLOG(actor) << "Start migrate actor " << *actor_info << " to scheduler " << dest_sched_id << ", "
              << tag("actor_count", actor_count_);
  actor_count_--;
  CHECK(actor_count_ >= 0);
  actor_info->get_actor_unsafe()->on_start_migrate(dest_sched_id);
  for (auto &event : actor_info->mailbox_) {
    start_migrate(event, dest_sched_id);
  }
  actor_info->start_migrate(dest_sched_id);
  actor_info->get_list_node()->remove();
  cancel_actor_timeout(actor_info);
}

double Scheduler::get_actor_timeout(const ActorInfo *actor_info) const {
  const HeapNode *heap_node = actor_info->get_heap_node();
  return heap_node->in_heap() ? timeout_queue_.get_key(heap_node) - Time::now() : 0.0;
}

void Scheduler::set_actor_timeout_in(ActorInfo *actor_info, double timeout) {
  if (timeout > 1e10) {
    timeout = 1e10;
  }
  if (timeout < 0) {
    timeout = 0;
  }
  double expires_at = Time::now() + timeout;
  set_actor_timeout_at(actor_info, expires_at);
}

void Scheduler::set_actor_timeout_at(ActorInfo *actor_info, double timeout_at) {
  HeapNode *heap_node = actor_info->get_heap_node();
  VLOG(actor) << "Set actor " << *actor_info << " timeout in " << timeout_at - Time::now_cached();
  if (heap_node->in_heap()) {
    timeout_queue_.fix(timeout_at, heap_node);
  } else {
    timeout_queue_.insert(timeout_at, heap_node);
  }
}

void Scheduler::run_poll(Timestamp timeout) {
  // we can't wait for less than 1ms
  auto timeout_ms = static_cast<int>(clamp(timeout.in(), 0.0, 1000000.0) * 1000 + 1);
#if TD_PORT_WINDOWS
  CHECK(inbound_queue_);
  inbound_queue_->reader_get_event_fd().wait(timeout_ms);
  service_actor_.notify();
#elif TD_PORT_POSIX
  poll_.run(timeout_ms);
#endif
}

void Scheduler::flush_mailbox(ActorInfo *actor_info) {
  auto &mailbox = actor_info->mailbox_;
  size_t mailbox_size = mailbox.size();
  CHECK(mailbox_size != 0);
  EventGuard guard(this, actor_info);
  size_t i = 0;
  for (; i < mailbox_size && guard.can_run(); i++) {
    do_event(actor_info, std::move(mailbox[i]));
  }
  mailbox.erase(mailbox.begin(), mailbox.begin() + i);
}

void Scheduler::run_mailbox() {
  VLOG(actor) << "Run mailbox : begin";
  ListNode actors_list = std::move(ready_actors_list_);
  while (!actors_list.empty()) {
    ListNode *node = actors_list.get();
    CHECK(node);
    auto actor_info = ActorInfo::from_list_node(node);
    flush_mailbox(actor_info);
  }
  VLOG(actor) << "Run mailbox : finish " << actor_count_;

  //Useful for debug, but O(ActorsCount) check

  //int cnt = 0;
  //for (ListNode *end = &pending_actors_list_, *it = pending_actors_list_.next; it != end; it = it->next) {
  //cnt++;
  //auto actor_info = ActorInfo::from_list_node(it);
  //LOG(ERROR) << *actor_info;
  //CHECK(actor_info->mailbox_.empty());
  //CHECK(!actor_info->is_running());
  //}
  //for (ListNode *end = &ready_actors_list_, *it = ready_actors_list_.next; it != end; it = it->next) {
  //auto actor_info = ActorInfo::from_list_node(it);
  //LOG(ERROR) << *actor_info;
  //cnt++;
  //}
  //LOG_CHECK(cnt == actor_count_) << cnt << " vs " << actor_count_;
}

Timestamp Scheduler::run_timeout() {
  double now = Time::now();
  //TODO: use Timestamp().is_in_past()
  while (!timeout_queue_.empty() && timeout_queue_.top_key() < now) {
    HeapNode *node = timeout_queue_.pop();
    ActorInfo *actor_info = ActorInfo::from_heap_node(node);
    send_immediately(actor_info->actor_id(), Event::timeout());
  }
  return get_timeout();
}

Timestamp Scheduler::run_events(Timestamp timeout) {
  Timestamp res;
  VLOG(actor) << "Run events " << sched_id_ << " " << tag("pending", pending_events_.size())
              << tag("actors", actor_count_);
  do {
    run_mailbox();
    res = run_timeout();
  } while (!ready_actors_list_.empty() && !timeout.is_in_past());
  return res;
}

void Scheduler::run_no_guard(Timestamp timeout) {
  CHECK(has_guard_);
  SCOPE_EXIT {
    yield_flag_ = false;
  };

  timeout.relax(run_events(timeout));
  if (yield_flag_) {
    return;
  }
  run_poll(timeout);
  run_events(timeout);
}

Timestamp Scheduler::get_timeout() {
  if (!ready_actors_list_.empty()) {
    return Timestamp::in(0);
  }
  if (timeout_queue_.empty()) {
    return Timestamp::in(10000);
  }
  return Timestamp::at(timeout_queue_.top_key());
}

}  // namespace td
