//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/CancellationToken.h"
#include "td/utils/common.h"
#include "td/utils/invoke.h"
#include "td/utils/MovableValue.h"
#include "td/utils/Status.h"

#include <tuple>
#include <type_traits>
#include <utility>

namespace td {

template <class T = Unit>
class PromiseInterface {
 public:
  PromiseInterface() = default;
  PromiseInterface(const PromiseInterface &) = delete;
  PromiseInterface &operator=(const PromiseInterface &) = delete;
  PromiseInterface(PromiseInterface &&) = default;
  PromiseInterface &operator=(PromiseInterface &&) = default;
  virtual ~PromiseInterface() = default;

  virtual void set_value(T &&value) {
    set_result(std::move(value));
  }
  virtual void set_error(Status &&error) {
    set_result(std::move(error));
  }
  virtual void set_result(Result<T> &&result) {
    if (result.is_ok()) {
      set_value(result.move_as_ok());
    } else {
      set_error(result.move_as_error());
    }
  }

  virtual bool is_cancellable() const {
    return false;
  }
  virtual bool is_canceled() const {
    return false;
  }
};

template <class T>
class SafePromise;

template <class T = Unit>
class Promise;

namespace detail {

template <typename T>
struct GetArg final : public GetArg<decltype(&T::operator())> {};

template <class C, class R, class Arg>
class GetArg<R (C::*)(Arg)> {
 public:
  using type = Arg;
};
template <class C, class R, class Arg>
class GetArg<R (C::*)(Arg) const> {
 public:
  using type = Arg;
};

template <class T>
using get_arg_t = std::decay_t<typename GetArg<T>::type>;

template <class T>
struct DropResult {
  using type = T;
};

template <class T>
struct DropResult<Result<T>> {
  using type = T;
};

template <class T>
using drop_result_t = typename DropResult<T>::type;

template <class ValueT, class FunctionT>
class LambdaPromise : public PromiseInterface<ValueT> {
  enum class State : int32 { Empty, Ready, Complete };

 public:
  void set_value(ValueT &&value) override {
    CHECK(state_.get() == State::Ready);
    do_ok(std::move(value));
    state_ = State::Complete;
  }

  void set_error(Status &&error) override {
    if (state_.get() == State::Ready) {
      do_error(std::move(error));
      state_ = State::Complete;
    }
  }
  LambdaPromise(const LambdaPromise &) = delete;
  LambdaPromise &operator=(const LambdaPromise &) = delete;
  LambdaPromise(LambdaPromise &&) = default;
  LambdaPromise &operator=(LambdaPromise &&) = default;
  ~LambdaPromise() override {
    if (state_.get() == State::Ready) {
      do_error(Status::Error("Lost promise"));
    }
  }

  template <class FromT>
  LambdaPromise(FromT &&func) : func_(std::forward<FromT>(func)), state_(State::Ready) {
  }

 private:
  FunctionT func_;
  MovableValue<State> state_{State::Empty};

  template <class F = FunctionT>
  std::enable_if_t<is_callable<F, Result<ValueT>>::value, void> do_error(Status &&status) {
    func_(Result<ValueT>(std::move(status)));
  }
  template <class Y, class F = FunctionT>
  std::enable_if_t<!is_callable<F, Result<ValueT>>::value, void> do_error(Y &&status) {
    func_(Auto());
  }
  template <class F = FunctionT>
  std::enable_if_t<is_callable<F, Result<ValueT>>::value, void> do_ok(ValueT &&value) {
    func_(Result<ValueT>(std::move(value)));
  }
  template <class F = FunctionT>
  std::enable_if_t<!is_callable<F, Result<ValueT>>::value, void> do_ok(ValueT &&value) {
    func_(std::move(value));
  }
};

template <class T>
struct is_promise_interface : std::false_type {};

template <class U>
struct is_promise_interface<PromiseInterface<U>> : std::true_type {};

template <class U>
struct is_promise_interface<Promise<U>> : std::true_type {};

template <class T>
struct is_promise_interface_ptr : std::false_type {};

template <class U>
struct is_promise_interface_ptr<unique_ptr<U>> : std::true_type {};

template <class T = void, class F = void, std::enable_if_t<std::is_same<T, void>::value, bool> has_t = false>
auto lambda_promise(F &&f) {
  return LambdaPromise<drop_result_t<get_arg_t<std::decay_t<F>>>, std::decay_t<F>>(std::forward<F>(f));
}
template <class T = void, class F = void, std::enable_if_t<!std::is_same<T, void>::value, bool> has_t = true>
auto lambda_promise(F &&f) {
  return LambdaPromise<T, std::decay_t<F>>(std::forward<F>(f));
}

template <class T, class F,
          std::enable_if_t<is_promise_interface<std::decay_t<F>>::value, bool> from_promise_interface = true>
auto &&promise_interface(F &&f) {
  return std::forward<F>(f);
}

template <class T, class F,
          std::enable_if_t<!is_promise_interface<std::decay_t<F>>::value, bool> from_promise_interface = false>
auto promise_interface(F &&f) {
  return lambda_promise<T>(std::forward<F>(f));
}

template <class T, class F,
          std::enable_if_t<is_promise_interface_ptr<std::decay_t<F>>::value, bool> from_promise_interface = true>
auto promise_interface_ptr(F &&f) {
  return std::forward<F>(f);
}

template <class T, class F,
          std::enable_if_t<!is_promise_interface_ptr<std::decay_t<F>>::value, bool> from_promise_interface = false>
auto promise_interface_ptr(F &&f) {
  return td::make_unique<std::decay_t<decltype(promise_interface<T>(std::forward<F>(f)))>>(
      promise_interface<T>(std::forward<F>(f)));
}
}  // namespace detail

template <class T>
class Promise {
 public:
  void set_value(T &&value) {
    if (!promise_) {
      return;
    }
    promise_->set_value(std::move(value));
    promise_.reset();
  }
  void set_error(Status &&error) {
    if (!promise_) {
      return;
    }
    promise_->set_error(std::move(error));
    promise_.reset();
  }
  void set_result(Result<T> &&result) {
    if (!promise_) {
      return;
    }
    promise_->set_result(std::move(result));
    promise_.reset();
  }
  void reset() {
    promise_.reset();
  }
  bool is_cancellable() const {
    if (!promise_) {
      return false;
    }
    return promise_->is_cancellable();
  }
  bool is_canceled() const {
    if (!promise_) {
      return false;
    }
    return promise_->is_canceled();
  }
  unique_ptr<PromiseInterface<T>> release() {
    return std::move(promise_);
  }

  Promise() = default;
  explicit Promise(unique_ptr<PromiseInterface<T>> promise) : promise_(std::move(promise)) {
  }
  Promise(Auto) {
  }
  Promise(SafePromise<T> &&other);
  Promise &operator=(SafePromise<T> &&other);
  template <class F, std::enable_if_t<!std::is_same<std::decay_t<F>, Promise>::value, int> = 0>
  Promise(F &&f) : promise_(detail::promise_interface_ptr<T>(std::forward<F>(f))) {
  }

  explicit operator bool() const noexcept {
    return static_cast<bool>(promise_);
  }

 private:
  unique_ptr<PromiseInterface<T>> promise_;
};

template <class T = Unit>
class SafePromise {
 public:
  SafePromise(Promise<T> promise, Result<T> result) : promise_(std::move(promise)), result_(std::move(result)) {
  }
  SafePromise(const SafePromise &) = delete;
  SafePromise &operator=(const SafePromise &) = delete;
  SafePromise(SafePromise &&) = default;
  SafePromise &operator=(SafePromise &&) = default;
  ~SafePromise() {
    if (promise_) {
      promise_.set_result(std::move(result_));
    }
  }
  Promise<T> release() {
    return std::move(promise_);
  }

 private:
  Promise<T> promise_;
  Result<T> result_;
};

template <class T>
Promise<T>::Promise(SafePromise<T> &&other) : Promise(other.release()) {
}

template <class T>
Promise<T> &Promise<T>::operator=(SafePromise<T> &&other) {
  *this = other.release();
  return *this;
}

namespace detail {
template <class PromiseT>
class CancellablePromise final : public PromiseT {
 public:
  template <class... ArgsT>
  CancellablePromise(CancellationToken cancellation_token, ArgsT &&...args)
      : PromiseT(std::forward<ArgsT>(args)...), cancellation_token_(std::move(cancellation_token)) {
  }
  bool is_cancellable() const final {
    return true;
  }
  bool is_canceled() const final {
    return static_cast<bool>(cancellation_token_);
  }

 private:
  CancellationToken cancellation_token_;
};

template <class... ArgsT>
class JoinPromise final : public PromiseInterface<Unit> {
 public:
  explicit JoinPromise(ArgsT &&...arg) : promises_(std::forward<ArgsT>(arg)...) {
  }
  void set_value(Unit &&) final {
    tuple_for_each(promises_, [](auto &promise) { promise.set_value(Unit()); });
  }
  void set_error(Status &&error) final {
    tuple_for_each(promises_, [&error](auto &promise) { promise.set_error(error.clone()); });
  }

 private:
  std::tuple<std::decay_t<ArgsT>...> promises_;
};
}  // namespace detail

class PromiseCreator {
 public:
  template <class OkT, class ArgT = detail::drop_result_t<detail::get_arg_t<OkT>>>
  static Promise<ArgT> lambda(OkT &&ok) {
    return Promise<ArgT>(td::make_unique<detail::LambdaPromise<ArgT, std::decay_t<OkT>>>(std::forward<OkT>(ok)));
  }

  template <class OkT, class ArgT = detail::drop_result_t<detail::get_arg_t<OkT>>>
  static auto cancellable_lambda(CancellationToken cancellation_token, OkT &&ok) {
    return Promise<ArgT>(td::make_unique<detail::CancellablePromise<detail::LambdaPromise<ArgT, std::decay_t<OkT>>>>(
        std::move(cancellation_token), std::forward<OkT>(ok)));
  }

  template <class... ArgsT>
  static Promise<> join(ArgsT &&...args) {
    return Promise<>(td::make_unique<detail::JoinPromise<ArgsT...>>(std::forward<ArgsT>(args)...));
  }
};

inline void set_promises(vector<Promise<Unit>> &promises) {
  auto moved_promises = std::move(promises);
  promises.clear();

  for (auto &promise : moved_promises) {
    promise.set_value(Unit());
  }
}

template <class T>
void fail_promises(vector<Promise<T>> &promises, Status &&error) {
  CHECK(error.is_error());
  auto moved_promises = std::move(promises);
  promises.clear();

  auto size = moved_promises.size();
  if (size == 0) {
    return;
  }
  size--;
  for (size_t i = 0; i < size; i++) {
    auto &promise = moved_promises[i];
    if (promise) {
      promise.set_error(error.clone());
    }
  }
  moved_promises[size].set_error(std::move(error));
}

template <class T>
void fail_promise_map(T &promise_map, Status &&error) {
  while (!promise_map.empty()) {
    auto it = promise_map.begin();
    auto promises = std::move(it->second);
    promise_map.erase(it);
    fail_promises(promises, error.clone());
  }
}

}  // namespace td
