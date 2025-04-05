//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/Closure.h"
#include "td/utils/common.h"
#include "td/utils/invoke.h"
#include "td/utils/Promise.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Status.h"

#include <tuple>
#include <utility>

namespace td {
namespace detail {
class EventPromise final : public PromiseInterface<Unit> {
 public:
  void set_value(Unit &&) final {
    ok_.try_emit();
    fail_.clear();
  }
  void set_error(Status &&) final {
    do_set_error();
  }

  EventPromise(const EventPromise &) = delete;
  EventPromise &operator=(const EventPromise &) = delete;
  EventPromise(EventPromise &&) = delete;
  EventPromise &operator=(EventPromise &&) = delete;
  ~EventPromise() final {
    do_set_error();
  }

  EventPromise() = default;
  explicit EventPromise(EventFull ok) : ok_(std::move(ok)), use_ok_as_fail_(true) {
  }
  EventPromise(EventFull ok, EventFull fail) : ok_(std::move(ok)), fail_(std::move(fail)), use_ok_as_fail_(false) {
  }

 private:
  EventFull ok_;
  EventFull fail_;
  bool use_ok_as_fail_ = false;
  void do_set_error() {
    if (use_ok_as_fail_) {
      ok_.try_emit();
    } else {
      ok_.clear();
      fail_.try_emit();
    }
  }
};

class SendClosure {
 public:
  template <class... ArgsT>
  void operator()(ArgsT &&...args) const {
    send_closure(std::forward<ArgsT>(args)...);
  }
};
}  // namespace detail

inline Promise<Unit> create_event_promise(EventFull &&ok) {
  return Promise<Unit>(td::make_unique<detail::EventPromise>(std::move(ok)));
}

inline Promise<Unit> create_event_promise(EventFull ok, EventFull fail) {
  return Promise<Unit>(td::make_unique<detail::EventPromise>(std::move(ok), std::move(fail)));
}

template <class T>
class FutureActor;

template <class T>
class PromiseActor;

template <class T>
class ActorTraits<FutureActor<T>> {
 public:
  static constexpr bool need_context = false;
  static constexpr bool need_start_up = false;
};

template <class T>
class PromiseActor final : public PromiseInterface<T> {
  friend class FutureActor<T>;
  enum State { Waiting, Hangup };

 public:
  PromiseActor() = default;
  PromiseActor(const PromiseActor &) = delete;
  PromiseActor &operator=(const PromiseActor &) = delete;
  PromiseActor(PromiseActor &&) = default;
  PromiseActor &operator=(PromiseActor &&) = default;
  ~PromiseActor() final {
    close();
  }

  void set_value(T &&value) final;
  void set_error(Status &&error) final;

  void close() {
    future_id_.reset();
  }

  // NB: if true is returned no further events will be sent
  bool is_hangup() {
    if (state_ == State::Hangup) {
      return true;
    }
    if (!future_id_.is_alive()) {
      state_ = State::Hangup;
      future_id_.release();
      event_.clear();
      return true;
    }
    return false;
  }

  template <class S>
  friend void init_promise_future(PromiseActor<S> *promise, FutureActor<S> *future);

  bool empty_promise() {
    return future_id_.empty();
  }
  bool empty() {
    return future_id_.empty();
  }

 private:
  ActorOwn<FutureActor<T>> future_id_;
  EventFull event_;
  State state_ = State::Hangup;

  void init() {
    state_ = State::Waiting;
    event_.clear();
  }
};

template <class T>
class FutureActor final : public Actor {
  friend class PromiseActor<T>;

 public:
  enum State { Waiting, Ready };

  static constexpr int HANGUP_ERROR_CODE = 426487;

  FutureActor() = default;

  FutureActor(const FutureActor &) = delete;
  FutureActor &operator=(const FutureActor &) = delete;

  FutureActor(FutureActor &&) = default;
  FutureActor &operator=(FutureActor &&) = default;

  ~FutureActor() final = default;

  bool is_ok() const {
    return is_ready() && result_.is_ok();
  }
  bool is_error() const {
    CHECK(is_ready());
    return is_ready() && result_.is_error();
  }
  T move_as_ok() {
    return move_as_result().move_as_ok();
  }
  Status move_as_error() TD_WARN_UNUSED_RESULT {
    return move_as_result().move_as_error();
  }
  Result<T> move_as_result() TD_WARN_UNUSED_RESULT {
    CHECK(is_ready());
    SCOPE_EXIT {
      do_stop();
    };
    return std::move(result_);
  }
  bool is_ready() const {
    return !empty() && state_ == State::Ready;
  }

  void close() {
    event_.clear();
    result_.clear();
    do_stop();
  }

  void set_event(EventFull &&event) {
    CHECK(!empty());
    event_ = std::move(event);
    if (state_ != State::Waiting) {
      event_.try_emit_later();
    }
  }

  State get_state() const {
    return state_;
  }

  template <class S>
  friend void init_promise_future(PromiseActor<S> *promise, FutureActor<S> *future);

 private:
  EventFull event_;
  Result<T> result_ = Status::Error(500, "Empty FutureActor");
  State state_ = State::Waiting;

  void set_value(T &&value) {
    set_result(std::move(value));
  }

  void set_error(Status &&error) {
    set_result(std::move(error));
  }

  void set_result(Result<T> &&result) {
    CHECK(state_ == State::Waiting);
    result_ = std::move(result);
    state_ = State::Ready;

    event_.try_emit_later();
  }

  void hangup() final {
    set_error(Status::Error<HANGUP_ERROR_CODE>());
  }

  void start_up() final {
    // empty
  }

  void init() {
    CHECK(empty());
    state_ = State::Waiting;
    event_.clear();
  }
};

template <class T>
void PromiseActor<T>::set_value(T &&value) {
  if (state_ == State::Waiting && !future_id_.empty()) {
    send_closure(std::move(future_id_), &FutureActor<T>::set_value, std::move(value));
  }
}
template <class T>
void PromiseActor<T>::set_error(Status &&error) {
  if (state_ == State::Waiting && !future_id_.empty()) {
    send_closure(std::move(future_id_), &FutureActor<T>::set_error, std::move(error));
  }
}

template <class S>
void init_promise_future(PromiseActor<S> *promise, FutureActor<S> *future) {
  promise->init();
  future->init();
  promise->future_id_ = register_actor("FutureActor", future);

  CHECK(future->get_info() != nullptr);
}

template <class T>
class PromiseFuture {
 public:
  PromiseFuture() {
    init_promise_future(&promise_, &future_);
  }
  PromiseActor<T> &promise() {
    return promise_;
  }
  FutureActor<T> &future() {
    return future_;
  }
  PromiseActor<T> &&move_promise() {
    return std::move(promise_);
  }
  FutureActor<T> &&move_future() {
    return std::move(future_);
  }

 private:
  PromiseActor<T> promise_;
  FutureActor<T> future_;
};

template <class T, class ActorAT, class ActorBT, class ResultT, class... DestArgsT, class... ArgsT>
FutureActor<T> send_promise_immediately(ActorId<ActorAT> actor_id,
                                        ResultT (ActorBT::*func)(PromiseActor<T> &&, DestArgsT...), ArgsT &&...args) {
  PromiseFuture<T> pf;
  Scheduler::instance()->send_closure_immediately(
      std::move(actor_id), create_immediate_closure(func, pf.move_promise(), std::forward<ArgsT>(args)...));
  return pf.move_future();
}

template <class T, class ActorAT, class ActorBT, class ResultT, class... DestArgsT, class... ArgsT>
FutureActor<T> send_promise_later(ActorId<ActorAT> actor_id, ResultT (ActorBT::*func)(PromiseActor<T> &&, DestArgsT...),
                                  ArgsT &&...args) {
  PromiseFuture<T> pf;
  Scheduler::instance()->send_closure_later(
      std::move(actor_id), create_immediate_closure(func, pf.move_promise(), std::forward<ArgsT>(args)...));
  return pf.move_future();
}

template <class... ArgsT>
auto promise_send_closure(ArgsT &&...args) {
  return [t = std::make_tuple(std::forward<ArgsT>(args)...)](auto &&res) mutable {
    call_tuple(detail::SendClosure(), std::tuple_cat(std::move(t), std::make_tuple(std::forward<decltype(res)>(res))));
  };
}

template <class T>
Promise<T> create_promise_from_promise_actor(PromiseActor<T> &&from) {
  return Promise<T>(td::make_unique<PromiseActor<T>>(std::move(from)));
}

}  // namespace td
