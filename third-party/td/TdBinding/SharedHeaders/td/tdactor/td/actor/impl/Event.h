//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/Closure.h"
#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>
#include <utility>

namespace td {

class Actor;

// Events
//
// Small structure (up to 16 bytes) used to send events between actors.
//
// There are some predefined types of events:
// NoType -- uninitialized event
// Start -- start actor
// Stop -- stop actor
// Yield -- wake up actor
// Timeout -- some timeout has expired
// Hangup -- hang up called
// Raw -- just pass 8 bytes (union Raw is used for convenience)
// Custom -- Send CustomEvent

template <class T>
std::enable_if_t<!std::is_base_of<Actor, T>::value> start_migrate(T &obj, int32 sched_id) {
}
template <class T>
std::enable_if_t<!std::is_base_of<Actor, T>::value> finish_migrate(T &obj) {
}

class CustomEvent {
 public:
  CustomEvent() = default;
  CustomEvent(const CustomEvent &) = delete;
  CustomEvent &operator=(const CustomEvent &) = delete;
  CustomEvent(CustomEvent &&) = delete;
  CustomEvent &operator=(CustomEvent &&) = delete;
  virtual ~CustomEvent() = default;

  virtual void run(Actor *actor) = 0;
  virtual void start_migrate(int32 sched_id) {
  }
  virtual void finish_migrate() {
  }
};

template <class ClosureT>
class ClosureEvent final : public CustomEvent {
 public:
  void run(Actor *actor) final {
    closure_.run(static_cast<typename ClosureT::ActorType *>(actor));
  }
  template <class... ArgsT>
  explicit ClosureEvent(ArgsT &&...args) : closure_(std::forward<ArgsT>(args)...) {
  }

  void start_migrate(int32 sched_id) final {
    closure_.for_each([sched_id](auto &obj) {
      using ::td::start_migrate;
      start_migrate(obj, sched_id);
    });
  }

  void finish_migrate() final {
    closure_.for_each([](auto &obj) {
      using ::td::finish_migrate;
      finish_migrate(obj);
    });
  }

 private:
  ClosureT closure_;
};

template <class LambdaT>
class LambdaEvent final : public CustomEvent {
 public:
  void run(Actor *actor) final {
    f_();
  }
  template <class FromLambdaT, std::enable_if_t<!std::is_same<std::decay_t<FromLambdaT>, LambdaEvent>::value, int> = 0>
  explicit LambdaEvent(FromLambdaT &&func) : f_(std::forward<FromLambdaT>(func)) {
  }

 private:
  LambdaT f_;
};

class Event {
 public:
  enum class Type { NoType, Start, Stop, Yield, Timeout, Hangup, Raw, Custom };
  Type type;
  uint64 link_token = 0;
  union Raw {
    void *ptr;
    CustomEvent *custom_event;
    uint32 u32;
    uint64 u64;
  } data{};

  // factory functions
  static Event start() {
    return Event(Type::Start);
  }
  static Event stop() {
    return Event(Type::Stop);
  }
  static Event yield() {
    return Event(Type::Yield);
  }
  static Event timeout() {
    return Event(Type::Timeout);
  }
  static Event hangup() {
    return Event(Type::Hangup);
  }
  static Event raw(void *ptr) {
    return Event(Type::Raw, ptr);
  }
  static Event raw(uint32 u32) {
    return Event(Type::Raw, u32);
  }
  static Event raw(uint64 u64) {
    return Event(Type::Raw, u64);
  }
  static Event custom(CustomEvent *custom_event) {
    return Event(Type::Custom, custom_event);
  }

  template <class FromImmediateClosureT>
  static Event immediate_closure(FromImmediateClosureT &&closure) {
    return custom(
        new ClosureEvent<typename FromImmediateClosureT::Delayed>(std::forward<FromImmediateClosureT>(closure)));
  }
  template <class... ArgsT>
  static Event delayed_closure(ArgsT &&...args) {
    using DelayedClosureT = decltype(create_delayed_closure(std::forward<ArgsT>(args)...));
    return custom(new ClosureEvent<DelayedClosureT>(std::forward<ArgsT>(args)...));
  }

  template <class FromLambdaT>
  static Event from_lambda(FromLambdaT &&func) {
    return custom(new LambdaEvent<std::decay_t<FromLambdaT>>(std::forward<FromLambdaT>(func)));
  }

  Event() : Event(Type::NoType) {
  }
  Event(const Event &) = delete;
  Event &operator=(const Event &) = delete;
  Event(Event &&other) noexcept : type(other.type), link_token(other.link_token), data(other.data) {
    other.type = Type::NoType;
  }
  Event &operator=(Event &&other) noexcept {
    destroy();
    type = other.type;
    link_token = other.link_token;
    data = other.data;
    other.type = Type::NoType;
    return *this;
  }
  ~Event() {
    destroy();
  }

  bool empty() const {
    return type == Type::NoType;
  }

  void clear() {
    destroy();
    type = Type::NoType;
  }

  Event &set_link_token(uint64 new_link_token) {
    link_token = new_link_token;
    return *this;
  }

  friend void start_migrate(Event &obj, int32 sched_id) {
    if (obj.type == Type::Custom) {
      obj.data.custom_event->start_migrate(sched_id);
    }
  }
  friend void finish_migrate(Event &obj) {
    if (obj.type == Type::Custom) {
      obj.data.custom_event->finish_migrate();
    }
  }

 private:
  explicit Event(Type type) : type(type) {
  }

  Event(Type type, void *ptr) : Event(type) {
    data.ptr = ptr;
  }
  Event(Type type, CustomEvent *custom_event) : Event(type) {
    data.custom_event = custom_event;
  }
  Event(Type type, uint32 u32) : Event(type) {
    data.u32 = u32;
  }
  Event(Type type, uint64 u64) : Event(type) {
    data.u64 = u64;
  }

  void destroy() {
    if (type == Type::Custom) {
      delete data.custom_event;
    }
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, const Event &e) {
  string_builder << "Event::";
  switch (e.type) {
    case Event::Type::Start:
      return string_builder << "Start";
    case Event::Type::Stop:
      return string_builder << "Stop";
    case Event::Type::Yield:
      return string_builder << "Yield";
    case Event::Type::Hangup:
      return string_builder << "Hangup";
    case Event::Type::Timeout:
      return string_builder << "Timeout";
    case Event::Type::Raw:
      return string_builder << "Raw";
    case Event::Type::Custom:
      return string_builder << "Custom";
    case Event::Type::NoType:
    default:
      return string_builder << "NoType";
  }
}

}  // namespace td
