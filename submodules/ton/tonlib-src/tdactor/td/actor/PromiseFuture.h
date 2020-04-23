/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once
#include "td/utils/Closure.h"
#include "td/utils/common.h"
#include "td/utils/invoke.h"  // for tuple_for_each
#include "td/utils/logging.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Status.h"

#include <tuple>
#include <type_traits>
#include <utility>

namespace td {
namespace detail {
template <typename T>
struct GetArg : public GetArg<decltype(&T::operator())> {};

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

template <typename T>
struct GetRet : public GetRet<decltype(&T::operator())> {};

template <class C, class R, class... Arg>
class GetRet<R (C::*)(Arg...)> {
 public:
  using type = R;
};
template <class C, class R, class... Arg>
class GetRet<R (C::*)(Arg...) const> {
 public:
  using type = R;
};

template <class T>
using get_arg_t = std::decay_t<typename GetArg<T>::type>;
template <class T>
using get_ret_t = std::decay_t<typename GetRet<T>::type>;

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
}  // namespace detail

template <class T = Unit>
class PromiseInterface {
 public:
  using ValueType = T;
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

  void operator()(T &&value) {
    set_value(std::move(value));
  }
  void operator()(Status &&error) {
    set_error(std::move(error));
  }
  void operator()(Result<T> &&result) {
    set_result(std::move(result));
  }
};
template <class T = Unit>
class Promise;

constexpr std::false_type is_promise_interface(...) {
  return {};
}
template <class T>
constexpr std::true_type is_promise_interface(const PromiseInterface<T> &promise) {
  return {};
}
template <class T>
constexpr std::true_type is_promise_interface(const Promise<T> &promise) {
  return {};
}

template <class F>
constexpr bool is_promise_interface() {
  return decltype(is_promise_interface(std::declval<F>()))::value;
}

constexpr std::false_type is_promise_interface_ptr(...) {
  return {};
}
template <class T>
constexpr std::true_type is_promise_interface_ptr(const unique_ptr<T> &promise) {
  return {};
}

template <class F>
constexpr bool is_promise_interface_ptr() {
  return decltype(is_promise_interface_ptr(std::declval<F>()))::value;
}
template <class ValueT, class FunctionT>
class LambdaPromise : public PromiseInterface<ValueT> {
 public:
  using ArgT = ValueT;
  void set_value(ValueT &&value) override {
    CHECK(has_lambda_.get());
    do_ok(std::move(value));
    has_lambda_ = false;
  }
  void set_error(Status &&error) override {
    CHECK(has_lambda_.get());
    do_error(std::move(error));
    has_lambda_ = false;
  }

  LambdaPromise(const LambdaPromise &other) = delete;
  LambdaPromise &operator=(const LambdaPromise &other) = delete;
  LambdaPromise(LambdaPromise &&other) = default;
  LambdaPromise &operator=(LambdaPromise &&other) = default;
  ~LambdaPromise() override {
    if (has_lambda_.get()) {
      do_error(Status::Error("Lost promise"));
    }
  }

  template <class FromOkT>
  explicit LambdaPromise(FromOkT &&ok) : ok_(std::forward<FromOkT>(ok)), has_lambda_(true) {
  }

 private:
  FunctionT ok_;
  MovableValue<bool> has_lambda_{false};

  template <class F = FunctionT>
  std::enable_if_t<is_callable<F, Result<ValueT>>::value, void> do_error(Status &&status) {
    ok_(Result<ValueT>(std::move(status)));
  }
  template <class Y, class F = FunctionT>
  std::enable_if_t<!is_callable<F, Result<ValueT>>::value, void> do_error(Y &&status) {
    ok_(Auto());
  }
  template <class F = FunctionT>
  std::enable_if_t<is_callable<F, Result<ValueT>>::value, void> do_ok(ValueT &&result) {
    ok_(Result<ValueT>(std::move(result)));
  }
  template <class F = FunctionT>
  std::enable_if_t<!is_callable<F, Result<ValueT>>::value, void> do_ok(ValueT &&result) {
    ok_(std::move(result));
  }
};

template <class T = void, class F = void, std::enable_if_t<std::is_same<T, void>::value, bool> has_t = false>
auto lambda_promise(F &&f) {
  return LambdaPromise<detail::drop_result_t<detail::get_arg_t<std::decay_t<F>>>, std::decay_t<F>>(std::forward<F>(f));
}
template <class T = void, class F = void, std::enable_if_t<!std::is_same<T, void>::value, bool> has_t = true>
auto lambda_promise(F &&f) {
  return LambdaPromise<T, std::decay_t<F>>(std::forward<F>(f));
}

template <class T, class F, std::enable_if_t<is_promise_interface<F>(), bool> from_promise_inerface = true>
auto &&promise_interface(F &&f) {
  return std::forward<F>(f);
}

template <class T, class F, std::enable_if_t<!is_promise_interface<F>(), bool> from_promise_inerface = false>
auto promise_interface(F &&f) {
  return lambda_promise<T>(std::forward<F>(f));
}

template <class T, class F, std::enable_if_t<is_promise_interface_ptr<F>(), bool> from_promise_inerface = true>
auto promise_interface_ptr(F &&f) {
  return std::forward<F>(f);
}
template <class T, class F, std::enable_if_t<!is_promise_interface_ptr<F>(), bool> from_promise_inerface = false>
auto promise_interface_ptr(F &&f) {
  return std::make_unique<std::decay_t<decltype(promise_interface<T>(std::forward<F>(f)))>>(
      promise_interface<T>(std::forward<F>(f)));
}

template <class T>
class Promise {
 public:
  using ArgT = T;
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
  template <class S>
  void operator()(S &&result) {
    if (!promise_) {
      return;
    }
    promise_->operator()(std::forward<S>(result));
    promise_.reset();
  }
  void reset() {
    promise_.reset();
  }
  std::unique_ptr<PromiseInterface<T>> release() {
    return std::move(promise_);
  }

  Promise() = default;
  explicit Promise(std::unique_ptr<PromiseInterface<T>> promise) : promise_(std::move(promise)) {
  }

  Promise &operator=(Promise &&) = default;
  Promise(Promise &&) = default;
  template <class F>
  Promise(F &&f) : promise_(promise_interface_ptr<T>(std::forward<F>(f))) {
  }

  explicit operator bool() {
    return static_cast<bool>(promise_);
  }
  template <class V, class F>
  auto do_wrap(V &&value, F &&func) {
    if (value.is_ok()) {
      set_result(func(value.move_as_ok()));
    } else {
      set_error(value.move_as_error());
    }
  }

  template <class F>
  auto do_wrap(td::Status status, F &&func) {
    set_error(std::move(status));
  }

  template <class F>
  auto wrap(F &&func) {
    return [promise = std::move(*this), func = std::move(func)](auto &&res) mutable {
      promise.do_wrap(std::move(res), std::move(func));
    };
  }
  template <class... ArgsT>
  auto send_closure(ArgsT &&... args);

 private:
  std::unique_ptr<PromiseInterface<T>> promise_;
};

namespace detail {
template <class... ArgsT>
class JoinPromise : public PromiseInterface<Unit> {
 public:
  explicit JoinPromise(ArgsT &&... arg) : promises_(std::forward<ArgsT>(arg)...) {
  }
  void set_value(Unit &&) override {
    tuple_for_each(promises_, [](auto &promise) { promise.set_value(Unit()); });
  }
  void set_error(Status &&error) override {
    tuple_for_each(promises_, [&error](auto &promise) { promise.set_error(error.clone()); });
  }

 private:
  std::tuple<std::decay_t<ArgsT>...> promises_;
};
}  // namespace detail

class PromiseCreator {
 public:
  struct Ignore {
    void operator()(Status &&error) {
      error.ignore();
    }
  };

  template <class OkT>
  static auto lambda(OkT &&ok) {
    return lambda_promise(std::forward<OkT>(ok));
  }

  template <class... ArgsT>
  static Promise<> join(ArgsT &&... args) {
    return Promise<>(std::make_unique<detail::JoinPromise<ArgsT...>>(std::forward<ArgsT>(args)...));
  }
};

template <class F>
auto make_promise(F &&f) {
  using ValueT = typename decltype(PromiseCreator::lambda(std::move(f)))::ArgT;
  return Promise<ValueT>(PromiseCreator::lambda(std::move(f)));
}
template <class T>
auto make_promise(Promise<T> &&f) {
  return std::move(f);
}

template <class T = Unit>
class SafePromise {
 public:
  SafePromise(Promise<T> promise, Result<T> result) : promise_(std::move(promise)), result_(std::move(result)) {
  }
  SafePromise(const SafePromise &other) = delete;
  SafePromise &operator=(const SafePromise &other) = delete;
  SafePromise(SafePromise &&other) = default;
  SafePromise &operator=(SafePromise &&other) = default;
  ~SafePromise() {
    if (promise_) {
      promise_.set_result(std::move(result_));
    }
  }
  Promise<T> release() {
    return std::move(promise_);
  }
  operator Promise<T>() && {
    return release();
  }

 private:
  Promise<T> promise_;
  Result<T> result_;
};

template <class PromiseT, typename... ArgsT>
class PromiseMerger;

template <class F>
struct SplitPromise {
  using PromiseT = decltype(make_promise(std::declval<F>()));
  using ArgT = typename PromiseT::ArgT;

  template <class S, class T>
  static std::pair<Promise<S>, Promise<T>> split(std::pair<S, T>);
  template <class... ArgsT>
  static std::tuple<Promise<ArgsT>...> split(std::tuple<ArgsT...>);
  using SplittedT = decltype(split(std::declval<ArgT>()));

  template <class S, class T>
  static PromiseMerger<PromiseT, S, T> merger(std::pair<S, T>);
  template <class... ArgsT>
  static PromiseMerger<PromiseT, ArgsT...> merger(std::tuple<ArgsT...>);
  using MergerT = decltype(merger(std::declval<ArgT>()));
};

template <class PromiseT, typename... ArgsT>
class PromiseMerger : public std::enable_shared_from_this<PromiseMerger<PromiseT, ArgsT...>> {
 public:
  std::tuple<Result<ArgsT>...> args_;
  PromiseT promise_;

  PromiseMerger(PromiseT promise) : promise_(std::move(promise)) {
  }
  ~PromiseMerger() {
    td::Status status;
    tuple_for_each(args_, [&status](auto &&arg) {
      if (status.is_error()) {
        return;
      }
      if (arg.is_error()) {
        status = arg.move_as_error();
      }
    });
    if (status.is_error()) {
      promise_.set_error(std::move(status));
      return;
    }
    call_tuple([this](auto &&... args) { promise_.set_value({args.move_as_ok()...}); }, std::move(args_));
  }

  template <class T>
  Promise<typename T::ValueT> make_promise(T &arg) {
    return [&arg, self = this->shared_from_this()](auto res) { arg = std::move(res); };
  }

  template <class R>
  auto split() {
    return call_tuple([this](auto &&... arg) { return R{this->make_promise(arg)...}; }, std::move(args_));
  }
};

template <class F>
auto split_promise(F &&f) {
  auto merger = std::make_shared<typename SplitPromise<F>::MergerT>(std::move(f));
  return merger->template split<typename SplitPromise<F>::SplittedT>();
}

template <class T>
struct PromiseFuture {
  Result<Promise<T>> promise_;
  Result<T> result_;
  ~PromiseFuture() {
    if (promise_.is_ok()) {
      promise_.move_as_ok().set_result(std::move(result_));
    } else {
      LOG(ERROR) << "Lost PromiseFuture";
    }
  }
};
template <class T>
struct Future;

template <class T>
std::pair<Promise<T>, Future<T>> make_promise_future();

template <class T>
struct Future {
  Promise<Promise<T>> promise_;
  Future(Promise<Promise<T>> promise) : promise_(std::move(promise)) {
  }

  void finish(Promise<T> promise) {
    promise_.set_value(std::move(promise));
  }

  template <class F>
  auto map(F &&f) {
    using R = detail::drop_result_t<decltype(f(std::declval<T>()))>;
    auto pf = make_promise_future<R>();
    promise_.set_value([p = std::move(pf.first), f = std::move(f)](Result<T> res) mutable {
      TRY_RESULT_PROMISE(p, x, std::move(res));
      p.set_result(f(std::move(x)));
    });

    return std::move(pf.second);
  }

  template <class F>
  auto fmap(F &&f) {
    return flatten(map(std::move(f)));
  }

  template <class X>
  static Future<X> flatten(Future<Future<X>> ff) {
    auto pf = make_promise_future<X>();
    ff.promise_.set_value([p = std::move(pf.first)](Result<Future<X>> r_f) mutable {
      TRY_RESULT_PROMISE(p, f, std::move(r_f));
      // Promise<X> p
      // Future<X> f
      f.promise_.set_value(std::move(p));
    });
    return std::move(pf.second);
  }
};

template <class T>
Future<T> make_future(T &&value) {
  return Future<T>([value = std::move(value)](Result<Promise<T>> r_promise) mutable {
    if (r_promise.is_ok()) {
      r_promise.move_as_ok().set_value(std::move(value));
    } else {
      LOG(ERROR) << "Lost future";
    }
  });
}

template <class T>
std::pair<Promise<T>, Future<T>> make_promise_future() {
  auto pf = std::make_shared<PromiseFuture<T>>();
  Future<T> future([pf](Result<Promise<T>> res) mutable { pf->promise_ = std::move(res); });
  Promise<T> promise = [pf = std::move(pf)](Result<T> res) mutable { pf->result_ = std::move(res); };
  return std::make_pair(std::move(promise), std::move(future));
}

}  // namespace td
