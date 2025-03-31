//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class MultiPromiseInterface {
 public:
  virtual void add_promise(Promise<> &&promise) = 0;
  virtual Promise<> get_promise() = 0;

  virtual size_t promise_count() const = 0;
  virtual void set_ignore_errors(bool ignore_errors) = 0;

  MultiPromiseInterface() = default;
  MultiPromiseInterface(const MultiPromiseInterface &) = delete;
  MultiPromiseInterface &operator=(const MultiPromiseInterface &) = delete;
  MultiPromiseInterface(MultiPromiseInterface &&) = default;
  MultiPromiseInterface &operator=(MultiPromiseInterface &&) = default;
  virtual ~MultiPromiseInterface() = default;
};

class MultiPromise final : public MultiPromiseInterface {
 public:
  void add_promise(Promise<> &&promise) final {
    impl_->add_promise(std::move(promise));
  }
  Promise<> get_promise() final {
    return impl_->get_promise();
  }

  size_t promise_count() const final {
    return impl_->promise_count();
  }
  void set_ignore_errors(bool ignore_errors) final {
    impl_->set_ignore_errors(ignore_errors);
  }

  MultiPromise() = default;
  explicit MultiPromise(unique_ptr<MultiPromiseInterface> impl) : impl_(std::move(impl)) {
  }

 private:
  unique_ptr<MultiPromiseInterface> impl_;
};

class MultiPromiseActor final
    : public Actor
    , public MultiPromiseInterface {
 public:
  explicit MultiPromiseActor(string name) : name_(std::move(name)) {
  }

  void add_promise(Promise<Unit> &&promise) final;

  Promise<Unit> get_promise() final;

  void set_ignore_errors(bool ignore_errors) final;

  size_t promise_count() const final;

 private:
  void set_result(Result<Unit> &&result);

  string name_;
  vector<Promise<Unit>> promises_;     // promises waiting for result
  vector<FutureActor<Unit>> futures_;  // futures waiting for result of the queries
  size_t received_results_ = 0;
  bool ignore_errors_ = false;
  Result<Unit> result_;

  void raw_event(const Event::Raw &event) final;

  void tear_down() final;

  void on_start_migrate(int32) final {
    UNREACHABLE();
  }
  void on_finish_migrate() final {
    UNREACHABLE();
  }
};

template <>
class ActorTraits<MultiPromiseActor> {
 public:
  static constexpr bool need_context = false;
  static constexpr bool need_start_up = true;
};

class MultiPromiseActorSafe final : public MultiPromiseInterface {
 public:
  void add_promise(Promise<Unit> &&promise) final;
  Promise<Unit> get_promise() final;
  void set_ignore_errors(bool ignore_errors) final;
  size_t promise_count() const final;
  explicit MultiPromiseActorSafe(string name) : multi_promise_(td::make_unique<MultiPromiseActor>(std::move(name))) {
  }
  MultiPromiseActorSafe(const MultiPromiseActorSafe &) = delete;
  MultiPromiseActorSafe &operator=(const MultiPromiseActorSafe &) = delete;
  MultiPromiseActorSafe(MultiPromiseActorSafe &&) = delete;
  MultiPromiseActorSafe &operator=(MultiPromiseActorSafe &&) = delete;
  ~MultiPromiseActorSafe() final;

 private:
  unique_ptr<MultiPromiseActor> multi_promise_;
};

}  // namespace td
