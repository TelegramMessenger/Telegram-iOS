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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/actor/actor.h"
#include "td/actor/PromiseFuture.h"
#include "td/actor/MultiPromise.h"
#include "td/utils/MovableValue.h"
#include "td/utils/tests.h"

template <class T>
class X {
 public:
  X() = default;
  X(X &&) = default;
  template <class S>
  X(S s) : t(s) {
  }
  T t;
};

TEST(Actor, promise) {
  using Int = td::MovableValue<int>;
  using td::Promise;
  using td::Result;

  auto set_int = [](td::Result<Int> &destination) {
    return [&destination](Int value) { destination = std::move(value); };
  };
  auto set_result_int = [](Result<Int> &destination) {
    return [&destination](Result<Int> value) { destination = std::move(value); };
  };

  {
    Result<Int> result{2};
    {
      Promise<Int> promise = set_int(result);
      promise.set_value(Int{3});
    }
    ASSERT_TRUE(result.is_ok());
    ASSERT_EQ(result.ok().get(), 3);
  }

  {
    Result<Int> result{2};
    {
      Promise<Int> promise = set_int(result);
      (void)promise;
      // will set Int{} on destruction
    }
    ASSERT_TRUE(result.is_ok());
    ASSERT_EQ(result.ok().get(), 0);
  }

  {
    Result<Int> result{2};
    {
      Promise<Int> promise = set_result_int(result);
      promise.set_value(Int{3});
    }
    ASSERT_TRUE(result.is_ok());
    ASSERT_EQ(result.ok().get(), 3);
  }

  {
    Result<Int> result{2};
    {
      Promise<Int> promise = set_result_int(result);
      (void)promise;
      // will set Status::Error() on destruction
    }
    ASSERT_TRUE(result.is_error());
  }

  {
    std::unique_ptr<int> res;
    Promise<td::Unit> x = [a = std::make_unique<int>(5), &res](td::Unit) mutable { res = std::move(a); };
    x(td::Unit());
    CHECK(*res == 5);
  }

  {//{
   //Promise<Int> promise;
   //std::tuple<Promise<Int> &&> f(std::move(promise));
   //std::tuple<Promise<Int>> x = std::move(f);
   //}

   {
       //using T = Result<int>;
       //using T = std::unique_ptr<int>;
       //using T = std::function<int()>;
       //using T = std::vector<int>;
       //using T = X<int>;
       ////using T = Promise<Int>;
       //T f;
       //std::tuple<T &&> g(std::move(f));
       //std::tuple<T> h = std::move(g);
   }}

  {
    int result = 0;
    auto promise = td::lambda_promise<int>([&](auto x) { result = x.move_as_ok(); });
    promise.set_value(5);
    ASSERT_EQ(5, result);

    Promise<int> promise2 = [&](auto x) { result = x.move_as_ok(); };
    promise2.set_value(6);
    ASSERT_EQ(6, result);
  }
}

TEST(Actor, safe_promise) {
  int res = 0;
  {
    td::Promise<int> promise = td::PromiseCreator::lambda([&](int x) { res = x; });
    auto safe_promise = td::SafePromise<int>(std::move(promise), 2);
    promise = std::move(safe_promise);
    ASSERT_EQ(res, 0);
    auto safe_promise2 = td::SafePromise<int>(std::move(promise), 3);
  }
  ASSERT_EQ(res, 3);
}

TEST(Actor2, actor_lost_promise) {
  using namespace td::actor;
  using namespace td;
  Scheduler scheduler({1}, Scheduler::Paused);

  auto watcher = td::create_shared_destructor([] {
    LOG(ERROR) << "STOP";
    SchedulerContext::get()->stop();
  });
  scheduler.run_in_context([watcher = std::move(watcher)] {
    class B : public Actor {
     public:
      void start_up() override {
        stop();
      }
      uint32 query(uint32 x) {
        return x * x;
      }
    };
    class A : public Actor {
     public:
      A(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
      }
      void start_up() {
        b_ = create_actor<B>(ActorOptions().with_name("B"));
        //send_closure(b_, &B::query, 2, [self = actor_id(this)](uint32 y) { send_closure(self, &A::on_result, 2, y); });
        send_closure_later(b_, &B::query, 2,
                           [self = actor_id(this), a = std::make_unique<int>()](Result<uint32> y) mutable {
                             LOG(ERROR) << "!";
                             CHECK(y.is_error());
                             send_closure(self, &A::finish);
                           });
        send_closure(b_, &B::query, 2, [self = actor_id(this), a = std::make_unique<int>()](Result<uint32> y) mutable {
          LOG(ERROR) << "!";
          CHECK(y.is_error());
          send_closure(self, &A::finish);
        });
      }
      void finish() {
        LOG(ERROR) << "FINISH";
        stop();
      }

     private:
      std::shared_ptr<td::Destructor> watcher_;
      td::actor::ActorOwn<B> b_;
    };
    create_actor<A>(ActorOptions().with_name("A").with_poll(), watcher).release();
  });
  scheduler.run();
}

TEST(Actor2, MultiPromise) {
  using namespace td;
  MultiPromise::Options fail_on_error;
  fail_on_error.ignore_errors = false;
  MultiPromise::Options ignore_errors;
  ignore_errors.ignore_errors = true;

  std::string str;
  auto log = [&](Result<Unit> res) {
    if (res.is_ok()) {
      str += "OK;";
    } else {
      str += PSTRING() << "E" << res.error().code() << ";";
    }
  };
  auto clear = [&] { str = ""; };

  {
    clear();
    MultiPromise mp(ignore_errors);
    {
      auto mp_init = mp.init_guard();
      mp_init.add_promise(log);
      ASSERT_EQ("", str);
    }
    ASSERT_EQ("OK;", str);
  }

  {
    clear();
    MultiPromise mp(ignore_errors);
    {
      auto mp_init = mp.init_guard();
      mp_init.add_promise(log);
      mp_init.get_promise().set_error(Status::Error(1));
      ASSERT_EQ("", str);
    }
    ASSERT_EQ("OK;", str);
  }

  {
    clear();
    MultiPromise mp(ignore_errors);
    Promise<> promise;
    {
      auto mp_init = mp.init_guard();
      mp_init.add_promise(log);
      promise = mp_init.get_promise();
    }
    ASSERT_EQ("", str);
    {
      auto mp_init = mp.add_promise_or_init(log);
      ASSERT_TRUE(!mp_init);
    }
    promise.set_error(Status::Error(2));
    ASSERT_EQ("OK;OK;", str);
    clear();
    {
      auto mp_init = mp.add_promise_or_init(log);
      ASSERT_TRUE(mp_init);
      ASSERT_EQ("", str);
    }
    ASSERT_EQ("OK;", str);
  }

  {
    clear();
    MultiPromise mp(fail_on_error);
    {
      auto mp_init = mp.init_guard();
      mp_init.get_promise().set_value(Unit());
      mp_init.add_promise(log);
      ASSERT_EQ("", str);
    }
    ASSERT_EQ("OK;", str);
  }

  {
    clear();
    MultiPromise mp(fail_on_error);
    {
      auto mp_init = mp.init_guard();
      mp_init.get_promise().set_value(Unit());
      mp_init.add_promise(log);
      mp_init.get_promise().set_error(Status::Error(1));
      ASSERT_EQ("E1;", str);
      clear();
      mp_init.get_promise().set_error(Status::Error(2));
      ASSERT_EQ("", str);
      mp_init.add_promise(log);
      ASSERT_EQ("E1;", str);
    }
    ASSERT_EQ("E1;", str);
  }

  {
    clear();
    MultiPromise mp(fail_on_error);
    Promise<> promise;
    {
      auto mp_init = mp.init_guard();
      mp_init.get_promise().set_value(Unit());
      mp_init.add_promise(log);
      promise = mp_init.get_promise();
    }
    ASSERT_EQ("", str);
    {
      auto mp_init = mp.add_promise_or_init(log);
      ASSERT_TRUE(mp_init.empty());
    }
    promise.set_error(Status::Error(2));
    ASSERT_EQ("E2;E2;", str);
    clear();

    {
      auto mp_init = mp.add_promise_or_init(log);
      ASSERT_TRUE(!mp_init.empty());
    }
    ASSERT_EQ("OK;", str);
  }
}

#if TD_HAVE_COROUTINES
#include <experimental/coroutine>
namespace td {
template <class T = Unit>
struct task {
  struct final_awaiter {
    bool await_ready() const noexcept {
      return false;
    }
    template <class P>
    std::experimental::coroutine_handle<> await_suspend(std::experimental::coroutine_handle<P> continuation) noexcept {
      return continuation.promise().continuation_;
    }
    void await_resume() noexcept {
    }
  };
  struct promise_type {
    task get_return_object() {
      return task{*this};
    }
    std::experimental::suspend_always initial_suspend() {
      return {};
    }
    final_awaiter final_suspend() {
      return final_awaiter{};
    }
    void return_value(T v) {
      value_ = v;
    }
    T move_value() {
      return std::move(value_.value());
    }
    void unhandled_exception() {
    }

    optional<T> value_;
    std::experimental::coroutine_handle<> continuation_;
  };

  // awaiter
  std::experimental::coroutine_handle<promise_type> coroutine_handle_;
  task(task &&other) = default;
  task(promise_type &promise)
      : coroutine_handle_(std::experimental::coroutine_handle<promise_type>::from_promise(promise)) {
  }

  bool await_ready() const noexcept {
    return !coroutine_handle_ || coroutine_handle_.done();
  }
  std::experimental::coroutine_handle<> await_suspend(std::experimental::coroutine_handle<> continuation) noexcept {
    coroutine_handle_.promise().continuation_ = continuation;
    return coroutine_handle_;
  }
  T await_resume() noexcept {
    return coroutine_handle_.promise().move_value();
  }
};

task<int> f() {
  co_return 1;
}
task<int> g() {
  co_return 2;
}
task<int> h() {
  auto a = co_await f();
  auto b = co_await g();
  co_return a + b;
}

struct immediate_task {
  struct promise_type {
    immediate_task get_return_object() {
      return {};
    }
    std::experimental::suspend_never initial_suspend() {
      return {};
    }
    std::experimental::suspend_never final_suspend() {
      return {};
    }
    void return_void() {
    }
    void unhandled_exception() {
    }
  };
};

struct OnActor {
 public:
  template <class T>
  OnActor(T &&actor_id) : actor_id_(actor_id.as_actor_ref()) {
  }
  bool await_ready() const noexcept {
    return false;
  }
  void await_suspend(std::experimental::coroutine_handle<> continuation) noexcept {
    //TODO: destroy if lambda is lost
    send_lambda(actor_id_, [continuation]() mutable { continuation.resume(); });
  }
  void await_resume() noexcept {
  }

 private:
  actor::detail::ActorRef actor_id_;
};

immediate_task check_h() {
  LOG(ERROR) << "check_h: call h";
  auto c = co_await h();
  LOG(ERROR) << "check_h: after call h";
  ASSERT_EQ(3, c);
}

TEST(ActorCoro, Task) {
  check_h();
}
namespace actor {
class AsyncQuery {};

class Printer : public Actor {
 public:
  void f();
  void print_a() {
    LOG(ERROR) << "a";
  }
  void print_b() {
    LOG(ERROR) << "b";
  }
};

class SampleActor : public Actor {
 public:
  SampleActor(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
  }

 private:
  std::shared_ptr<Destructor> watcher_;
  ActorOwn<Printer> printer_;
  void start_up() override {
    printer_ = create_actor<Printer>("Printer");
    run_coroutine();
  }
  task<Unit> print_a() {
    auto self = actor_id(this);
    LOG(ERROR) << "enter print_a";
    co_await OnActor(printer_);
    detail::current_actor<Printer>().print_a();
    co_await OnActor(self);
    LOG(ERROR) << "exit print_a";
    co_return{};
  }
  task<Unit> print_b() {
    auto self = actor_id(this);
    LOG(ERROR) << "enter print_b";
    co_await OnActor(printer_);
    detail::current_actor<Printer>().print_b();
    co_await OnActor(self);
    LOG(ERROR) << "exit print_b";
    co_return{};
  }

  immediate_task run_coroutine() {
    co_await print_a();
    co_await print_b();
    stop();
  }
};
}  // namespace actor

TEST(ActorCoro, Simple) {
  using namespace td::actor;
  using namespace td;
  Scheduler scheduler({1});

  auto watcher = td::create_shared_destructor([] {
    LOG(ERROR) << "STOP";
    SchedulerContext::get()->stop();
  });
  scheduler.run_in_context([watcher = std::move(watcher)] {
    create_actor<actor::SampleActor>(ActorOptions().with_name("SampleActor").with_poll(), watcher).release();
  });
  scheduler.run();
}

}  // namespace td
#endif
