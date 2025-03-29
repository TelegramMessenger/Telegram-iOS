//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/SliceBuilder.h"

#if TD_MSVC
#pragma comment(linker, "/STACK:16777216")
#endif

struct TestActor final : public td::Actor {
  static td::int32 actor_count_;

  void start_up() final {
    actor_count_++;
    stop();
  }

  void tear_down() final {
    if (--actor_count_ == 0) {
      td::Scheduler::instance()->finish();
    }
  }
};

td::int32 TestActor::actor_count_;

namespace td {
template <>
class ActorTraits<TestActor> {
 public:
  static constexpr bool need_context = false;
  static constexpr bool need_start_up = true;
};
}  // namespace td

class CreateActorBench final : public td::Benchmark {
  td::unique_ptr<td::ConcurrentScheduler> scheduler_;

  void start_up() final {
    scheduler_ = td::make_unique<td::ConcurrentScheduler>(0, 0);
    scheduler_->start();
  }

  void tear_down() final {
    scheduler_->finish();
    scheduler_.reset();
  }

 public:
  td::string get_description() const final {
    return "CreateActor";
  }

  void run(int n) final {
    for (int i = 0; i < n; i++) {
      scheduler_->create_actor_unsafe<TestActor>(0, "TestActor").release();
    }
    while (scheduler_->run_main(10)) {
      // empty
    }
  }
};

template <int type>
class RingBench final : public td::Benchmark {
 public:
  struct PassActor;

 private:
  int actor_n_ = -1;
  int thread_n_ = -1;
  td::vector<td::ActorId<PassActor>> actor_array_;
  td::unique_ptr<td::ConcurrentScheduler> scheduler_;

 public:
  td::string get_description() const final {
    static const char *types[] = {"later", "immediate", "raw", "tail", "lambda"};
    static_assert(0 <= type && type < 5, "");
    return PSTRING() << "Ring (send_" << types[type] << ") (threads_n = " << thread_n_ << ")";
  }

  struct PassActor final : public td::Actor {
    int id = -1;
    td::ActorId<PassActor> next_actor;
    int start_n = 0;

    void pass(int n) {
      // LOG(INFO) << "Pass: " << n;
      if (n == 0) {
        td::Scheduler::instance()->finish();
      } else {
        if (type == 0) {
          send_closure_later(next_actor, &PassActor::pass, n - 1);
        } else if (type == 1) {
          send_closure(next_actor, &PassActor::pass, n - 1);
        } else if (type == 2) {
          send_event(next_actor, td::Event::raw(static_cast<td::uint32>(n - 1)));
        } else if (type == 3) {
          if (n % 5000 == 0) {
            send_closure_later(next_actor, &PassActor::pass, n - 1);
          } else {
            // TODO: it is three times faster than send_event
            // maybe send event could be further optimized?
            next_actor.get_actor_unsafe()->raw_event(td::Event::raw(static_cast<td::uint32>(n - 1)).data);
          }
        } else if (type == 4) {
          send_lambda(next_actor, [n, ptr = next_actor.get_actor_unsafe()] { ptr->pass(n - 1); });
        }
      }
    }

    void raw_event(const td::Event::Raw &raw) final {
      pass(static_cast<int>(raw.u32));
    }

    void start_up() final {
      yield();
    }
    void wakeup() final {
      if (start_n != 0) {
        int n = start_n;
        start_n = 0;
        pass(n);
      }
    }
  };

  RingBench(int actor_n, int thread_n) : actor_n_(actor_n), thread_n_(thread_n) {
  }

  void start_up() final {
    scheduler_ = td::make_unique<td::ConcurrentScheduler>(thread_n_, 0);

    actor_array_ = td::vector<td::ActorId<PassActor>>(actor_n_);
    for (int i = 0; i < actor_n_; i++) {
      actor_array_[i] =
          scheduler_->create_actor_unsafe<PassActor>(thread_n_ ? i % thread_n_ : 0, "PassActor").release();
      actor_array_[i].get_actor_unsafe()->id = i;
    }
    for (int i = 0; i < actor_n_; i++) {
      actor_array_[i].get_actor_unsafe()->next_actor = actor_array_[(i + 1) % actor_n_];
    }
    scheduler_->start();
  }

  void run(int n) final {
    // first actor is on main_thread
    actor_array_[0].get_actor_unsafe()->start_n = td::max(n, 100);
    while (scheduler_->run_main(10)) {
      // empty
    }
  }

  void tear_down() final {
    scheduler_->finish();
    scheduler_.reset();
  }
};

template <int type>
class QueryBench final : public td::Benchmark {
 public:
  td::string get_description() const final {
    static const char *types[] = {"callback", "immediate future", "delayed future", "dummy", "lambda", "lambda_future"};
    static_assert(0 <= type && type < 6, "");
    return PSTRING() << "QueryBench: " << types[type];
  }

  class ClientActor final : public td::Actor {
   public:
    class Callback {
     public:
      Callback() = default;
      Callback(const Callback &) = delete;
      Callback &operator=(const Callback &) = delete;
      Callback(Callback &&) = delete;
      Callback &operator=(Callback &&) = delete;
      virtual ~Callback() = default;
      virtual void on_result(int x) = 0;
    };
    explicit ClientActor(td::unique_ptr<Callback> callback) : callback_(std::move(callback)) {
    }
    void f(int x) {
      callback_->on_result(x * x);
    }
    void dummy(int x, int *y) {
      *y = x * x;
    }
    void f_immediate_promise(int x, td::PromiseActor<int> &&promise) {
      promise.set_value(x * x);
    }
    void f_promise(td::Promise<> promise) {
      promise.set_value(td::Unit());
    }

   private:
    td::unique_ptr<Callback> callback_;
  };

  class ServerActor final : public td::Actor {
   public:
    class ClientCallback final : public ClientActor::Callback {
     public:
      explicit ClientCallback(td::ActorId<ServerActor> server) : server_(server) {
      }
      void on_result(int x) final {
        send_closure(server_, &ServerActor::on_result, x);
      }

     private:
      td::ActorId<ServerActor> server_;
    };
    void start_up() final {
      client_ = td::create_actor<ClientActor>("Client", td::make_unique<ClientCallback>(actor_id(this))).release();
    }

    void on_result(int x) {
      CHECK(x == n_ * n_);
      wakeup();
    }

    void wakeup() final {
      while (true) {
        if (n_ < 0) {
          td::Scheduler::instance()->finish();
          return;
        }
        n_--;
        if (type == 0) {
          send_closure(client_, &ClientActor::f, n_);
          return;
        } else if (type == 1) {
          td::PromiseActor<int> promise;
          td::FutureActor<int> future;
          init_promise_future(&promise, &future);
          send_closure(client_, &ClientActor::f_immediate_promise, n_, std::move(promise));
          CHECK(!future.is_ready());
          CHECK(!future.empty());
          CHECK(future.get_state() == td::FutureActor<int>::State::Waiting);
          // int val = future.move_as_ok();
          // CHECK(val == n_ * n_);
        } else if (type == 2) {
          td::PromiseActor<int> promise;
          init_promise_future(&promise, &future_);
          future_.set_event(td::EventCreator::raw(actor_id(), static_cast<td::uint64>(1)));
          send_closure(client_, &ClientActor::f_immediate_promise, n_, std::move(promise));
          return;
        } else if (type == 3) {
          int res;
          send_closure(client_, &ClientActor::dummy, n_, &res);
        } else if (type == 4) {
          int val = 0;
          send_lambda(client_, [&] { val = n_ * n_; });
          CHECK(val == 0 || val == n_ * n_);
        } else if (type == 5) {
          send_closure(client_, &ClientActor::f_promise,
                       td::PromiseCreator::lambda([actor_id = actor_id(this), n = n_](td::Unit) {
                         send_closure(actor_id, &ServerActor::result, n * n);
                       }));
          return;
        }
      }
    }

    void run(int n) {
      n_ = n;
      wakeup();
    }

    void raw_event(const td::Event::Raw &event) final {
      int val = future_.move_as_ok();
      CHECK(val == n_ * n_);
      wakeup();
    }
    void result(int val) {
      CHECK(val == n_ * n_);
      wakeup();
    }

   private:
    td::ActorId<ClientActor> client_;
    int n_ = 0;
    td::FutureActor<int> future_;
  };

  void start_up() final {
    scheduler_ = td::make_unique<td::ConcurrentScheduler>(0, 0);

    server_ = scheduler_->create_actor_unsafe<ServerActor>(0, "Server");
    scheduler_->start();
  }

  void run(int n) final {
    // first actor is on main_thread
    {
      auto guard = scheduler_->get_main_guard();
      send_closure(server_, &ServerActor::run, n);
    }
    while (scheduler_->run_main(10)) {
      // empty
    }
  }

  void tear_down() final {
    server_.release();
    scheduler_->finish();
    scheduler_.reset();
  }

 private:
  td::unique_ptr<td::ConcurrentScheduler> scheduler_;
  td::ActorOwn<ServerActor> server_;
};

int main() {
  td::init_openssl_threads();

  bench(CreateActorBench());
  bench(RingBench<4>(504, 0));
  bench(RingBench<3>(504, 0));
  bench(RingBench<0>(504, 0));
  bench(RingBench<1>(504, 0));
  bench(RingBench<2>(504, 0));
  bench(QueryBench<5>());
  bench(QueryBench<4>());
  bench(QueryBench<3>());
  bench(QueryBench<2>());
  bench(QueryBench<1>());
  bench(QueryBench<0>());
  bench(RingBench<3>(504, 0));
  bench(RingBench<0>(504, 10));
  bench(RingBench<1>(504, 10));
  bench(RingBench<2>(504, 10));
  bench(RingBench<0>(504, 2));
  bench(RingBench<1>(504, 2));
  bench(RingBench<2>(504, 2));
}
