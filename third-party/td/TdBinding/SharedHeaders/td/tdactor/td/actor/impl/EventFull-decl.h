//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/impl/ActorId-decl.h"
#include "td/actor/impl/Event.h"

#include "td/utils/type_traits.h"

#include <type_traits>
#include <utility>

namespace td {

class EventFull {
 public:
  EventFull() = default;

  bool empty() const {
    return data_.empty();
  }

  void clear() {
    data_.clear();
  }

  ActorId<> actor_id() const {
    return actor_id_;
  }
  Event &data() {
    return data_;
  }

  void try_emit_later();
  void try_emit();

 private:
  friend class EventCreator;

  EventFull(ActorRef actor_ref, Event &&data) : actor_id_(actor_ref.get()), data_(std::move(data)) {
    data_.link_token = actor_ref.token();
  }
  template <class T>
  EventFull(ActorId<T> actor_id, Event &&data) : actor_id_(std::move(actor_id)), data_(std::move(data)) {
  }

  ActorId<> actor_id_;

  Event data_;
};

class EventCreator {
 public:
  template <class ActorIdT, class FunctionT, class... ArgsT>
  static EventFull closure(ActorIdT &&actor_id, FunctionT function, ArgsT &&...args) {
    using ActorT = typename std::decay_t<ActorIdT>::ActorT;
    using FunctionClassT = member_function_class_t<FunctionT>;
    static_assert(std::is_base_of<FunctionClassT, ActorT>::value, "unsafe send_closure");

    return EventFull(std::forward<ActorIdT>(actor_id), Event::delayed_closure(function, std::forward<ArgsT>(args)...));
  }

  template <class LambdaT>
  static EventFull from_lambda(ActorRef actor_ref, LambdaT &&func) {
    return EventFull(actor_ref, Event::from_lambda(std::forward<LambdaT>(func)));
  }

  static EventFull yield(ActorRef actor_ref) {
    return EventFull(actor_ref, Event::yield());
  }
  static EventFull raw(ActorRef actor_ref, uint64 data) {
    return EventFull(actor_ref, Event::raw(data));
  }
  static EventFull raw(ActorRef actor_ref, void *ptr) {
    return EventFull(actor_ref, Event::raw(ptr));
  }

  static EventFull event_unsafe(ActorId<> actor_id, Event &&event) {
    return EventFull(actor_id, std::move(event));
  }
};

}  // namespace td
