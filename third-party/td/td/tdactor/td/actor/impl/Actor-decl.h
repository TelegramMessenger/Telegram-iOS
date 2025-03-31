//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/impl/ActorId-decl.h"
#include "td/actor/impl/ActorInfo-decl.h"
#include "td/actor/impl/Event.h"

#include "td/utils/common.h"
#include "td/utils/ObjectPool.h"
#include "td/utils/Observer.h"
#include "td/utils/Slice.h"

#include <memory>

namespace td {

class Actor : public ObserverBase {
 public:
  using Deleter = ActorInfo::Deleter;
  Actor() = default;
  Actor(const Actor &) = delete;
  Actor &operator=(const Actor &) = delete;
  Actor(Actor &&other) noexcept;
  Actor &operator=(Actor &&other) noexcept;
  ~Actor() override {
    if (!empty()) {
      do_stop();
    }
  }

  virtual void start_up() {
    yield();
  }
  virtual void tear_down() {
  }
  virtual void wakeup() {
    loop();
  }
  virtual void hangup() {
    stop();
  }
  virtual void hangup_shared() {
    // ignore
  }
  virtual void timeout_expired() {
    loop();
  }
  virtual void raw_event(const Event::Raw &event) {
  }
  virtual void loop() {
  }

  // TODO: not called in events. Can't use stop, or migrate inside of them
  virtual void on_start_migrate(int32 sched_id) {
  }
  virtual void on_finish_migrate() {
  }

  void notify() override;

  // proxy to scheduler
  void yield();
  void stop();
  void do_stop();
  bool has_timeout() const;
  double get_timeout() const;
  void set_timeout_in(double timeout_in);
  void set_timeout_at(double timeout_at);
  void cancel_timeout();
  void migrate(int32 sched_id);
  void do_migrate(int32 sched_id);

  uint64 get_link_token();
  std::weak_ptr<ActorContext> get_context_weak_ptr() const;
  std::shared_ptr<ActorContext> set_context(std::shared_ptr<ActorContext> context);
  string set_tag(string tag);

  // for ActorInfo mostly
  void set_info(ObjectPool<ActorInfo>::OwnerPtr &&info);
  ActorInfo *get_info();
  const ActorInfo *get_info() const;
  ObjectPool<ActorInfo>::OwnerPtr clear();

  bool empty() const;

  template <class FuncT, class... ArgsT>
  auto self_closure(FuncT &&func, ArgsT &&...args);

  template <class SelfT, class FuncT, class... ArgsT>
  auto self_closure(SelfT *self, FuncT &&func, ArgsT &&...args);

  template <class LambdaT>
  auto self_lambda(LambdaT &&func);

  // proxy to info_
  ActorId<> actor_id();
  template <class SelfT>
  ActorId<SelfT> actor_id(SelfT *self);

  template <class SelfT>
  ActorShared<SelfT> actor_shared(SelfT *self, uint64 id = static_cast<uint64>(-1));

  Slice get_name() const;

 private:
  ObjectPool<ActorInfo>::OwnerPtr info_;
};

template <class ActorT>
class ActorTraits {
 public:
  static constexpr bool need_context = true;
  static constexpr bool need_start_up = true;
};

}  // namespace td
