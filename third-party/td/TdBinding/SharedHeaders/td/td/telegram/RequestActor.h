//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Global.h"
#include "td/telegram/Td.h"
#include "td/telegram/td_api.h"

#include "td/actor/actor.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <type_traits>

namespace td {

template <class T = Unit>
class RequestActor : public Actor {
 public:
  RequestActor(ActorShared<Td> td_id, uint64 request_id)
      : td_id_(std::move(td_id)), td_(td_id_.get().get_actor_unsafe()), request_id_(request_id) {
  }

  void loop() override {
    if (G()->close_flag()) {
      return do_send_error(Global::request_aborted_error());
    }

    PromiseActor<T> promise_actor;
    FutureActor<T> future;
    init_promise_future(&promise_actor, &future);

    auto promise = create_promise_from_promise_actor(std::move(promise_actor));
    do_run(std::move(promise));

    if (future.is_ready()) {
      CHECK(!promise);
      if (future.is_error()) {
        do_send_error(future.move_as_error());
      } else {
        do_set_result(future.move_as_ok());
        do_send_result();
      }
      stop();
    } else {
      CHECK(!future.empty());
      CHECK(future.get_state() == FutureActor<T>::State::Waiting);
      if (--tries_left_ == 0) {
        future.close();
        do_send_error(Status::Error(500, "Requested data is inaccessible"));
        return stop();
      }

      future.set_event(EventCreator::raw(actor_id(), nullptr));
      future_ = std::move(future);
    }
  }

  void raw_event(const Event::Raw &event) final {
    if (future_.is_error()) {
      auto error = future_.move_as_error();
      if (error.is_static() && error.code() == FutureActor<T>::HANGUP_ERROR_CODE) {
        // dropping query due to closing or lost promise
        if (G()->close_flag()) {
          do_send_error(Global::request_aborted_error());
        } else {
          LOG(ERROR) << "Promise was lost";
          do_send_error(Status::Error(500, "Query can't be answered due to a bug in TDLib"));
        }
        return stop();
      }

      do_send_error(std::move(error));
      stop();
    } else {
      do_set_result(future_.move_as_ok());
      loop();
    }
  }

  void on_start_migrate(int32 /*sched_id*/) final {
    UNREACHABLE();
  }
  void on_finish_migrate() final {
    UNREACHABLE();
  }

  int get_tries() const {
    return tries_left_;
  }

  void set_tries(int32 tries) {
    tries_left_ = tries;
  }

 protected:
  ActorShared<Td> td_id_;
  Td *td_;

  void send_result(tl_object_ptr<td_api::Object> &&result) {
    send_closure(td_id_, &Td::send_result, request_id_, std::move(result));
  }

  void send_error(Status &&status) {
    LOG(INFO) << "Receive error for query: " << status;
    send_closure(td_id_, &Td::send_error, request_id_, std::move(status));
  }

 private:
  virtual void do_run(Promise<T> &&promise) = 0;

  virtual void do_send_result() {
    send_result(make_tl_object<td_api::ok>());
  }

  virtual void do_send_error(Status &&status) {
    send_error(std::move(status));
  }

  virtual void do_set_result(T &&result) {
    CHECK((std::is_same<T, Unit>::value));  // all other results should be implicitly handled by overriding this method
  }

  void hangup() final {
    do_send_error(Global::request_aborted_error());
    stop();
  }

  friend class RequestOnceActor;

  uint64 request_id_;
  int tries_left_ = 2;
  FutureActor<T> future_;
};

class RequestOnceActor : public RequestActor<> {
 public:
  RequestOnceActor(ActorShared<Td> td_id, uint64 request_id) : RequestActor(std::move(td_id), request_id) {
  }

  void loop() final {
    if (get_tries() < 2) {
      do_send_result();
      stop();
      return;
    }

    RequestActor::loop();
  }
};

}  // namespace td
