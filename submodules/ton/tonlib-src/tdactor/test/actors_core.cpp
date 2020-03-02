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
#include "td/actor/core/ActorLocker.h"
#include "td/actor/actor.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/Time.h"

#include <array>
#include <atomic>
#include <deque>
#include <memory>

TEST(Actor2, signals) {
  using td::actor::core::ActorSignals;
  ActorSignals signals;
  signals.add_signal(ActorSignals::Wakeup);
  signals.add_signal(ActorSignals::Cpu);
  signals.add_signal(ActorSignals::Kill);
  signals.clear_signal(ActorSignals::Cpu);

  bool was_kill = false;
  bool was_wakeup = false;
  while (!signals.empty()) {
    auto s = signals.first_signal();
    if (s == ActorSignals::Kill) {
      was_kill = true;
    } else if (s == ActorSignals::Wakeup) {
      was_wakeup = true;
    } else {
      UNREACHABLE();
    }
    signals.clear_signal(s);
  }
  CHECK(was_kill && was_wakeup);
}

TEST(Actors2, flags) {
  using namespace td::actor::core;
  ActorState::Flags flags;
  CHECK(!flags.is_locked());
  flags.set_locked(true);
  CHECK(flags.is_locked());
  flags.set_locked(false);
  CHECK(!flags.is_locked());

  flags.set_scheduler_id(SchedulerId{123});

  auto signals = flags.get_signals();
  CHECK(signals.empty());
  signals.add_signal(ActorSignals::Cpu);
  signals.add_signal(ActorSignals::Kill);
  CHECK(signals.has_signal(ActorSignals::Cpu));
  CHECK(signals.has_signal(ActorSignals::Kill));
  flags.set_signals(signals);
  LOG_CHECK(flags.get_signals().raw() == signals.raw()) << flags.get_signals().raw() << " " << signals.raw();

  auto wakeup = ActorSignals{};
  wakeup.add_signal(ActorSignals::Wakeup);

  flags.add_signals(wakeup);
  signals.add_signal(ActorSignals::Wakeup);
  CHECK(flags.get_signals().raw() == signals.raw());

  flags.clear_signals();
  CHECK(flags.get_signals().empty());

  flags.add_signals(ActorSignals::one(ActorSignals::Pause));
  CHECK(flags.get_scheduler_id().value() == 123);
  CHECK(flags.get_signals().has_signal(ActorSignals::Pause));
}

TEST(Actor2, locker) {
  using namespace td::actor::core;
  ActorState state;

  ActorSignals kill_signal;
  kill_signal.add_signal(ActorSignals::Kill);

  ActorSignals wakeup_signal;
  wakeup_signal.add_signal(ActorSignals::Wakeup);

  ActorSignals cpu_signal;
  cpu_signal.add_signal(ActorSignals::Cpu);

  {
    ActorLocker lockerA(&state);
    ActorLocker lockerB(&state);
    ActorLocker lockerC(&state);

    CHECK(lockerA.try_lock());
    CHECK(lockerA.own_lock());
    auto flagsA = lockerA.flags();
    CHECK(lockerA.try_unlock(flagsA));
    CHECK(!lockerA.own_lock());

    CHECK(lockerA.try_lock());
    CHECK(!lockerB.try_lock());
    CHECK(!lockerC.try_lock());

    CHECK(lockerB.try_add_signals(kill_signal));
    CHECK(!lockerC.try_add_signals(wakeup_signal));
    CHECK(lockerC.try_add_signals(wakeup_signal));
    CHECK(!lockerC.add_signals(cpu_signal));
    CHECK(!lockerA.flags().has_signals());
    CHECK(!lockerA.try_unlock(lockerA.flags()));
    {
      auto flags = lockerA.flags();
      auto signals = flags.get_signals();
      bool was_kill = false;
      bool was_wakeup = false;
      bool was_cpu = false;
      while (!signals.empty()) {
        auto s = signals.first_signal();
        if (s == ActorSignals::Kill) {
          was_kill = true;
        } else if (s == ActorSignals::Wakeup) {
          was_wakeup = true;
        } else if (s == ActorSignals::Cpu) {
          was_cpu = true;
        } else {
          UNREACHABLE();
        }
        signals.clear_signal(s);
      }
      CHECK(was_kill && was_wakeup && was_cpu);
      flags.clear_signals();
      CHECK(lockerA.try_unlock(flags));
    }
  }

  {
    ActorLocker lockerB(&state);
    CHECK(lockerB.try_lock());
    CHECK(lockerB.try_unlock(lockerB.flags()));
    CHECK(lockerB.add_signals(kill_signal));
    CHECK(lockerB.flags().get_signals().has_signal(ActorSignals::Kill));
    auto flags = lockerB.flags();
    flags.clear_signals();
    ActorLocker lockerA(&state);
    CHECK(!lockerA.add_signals(kill_signal));
    CHECK(!lockerB.try_unlock(flags));
    CHECK(!lockerA.add_signals(kill_signal));  // do not loose this signal!
    CHECK(!lockerB.try_unlock(flags));
    CHECK(lockerB.flags().get_signals().has_signal(ActorSignals::Kill));
    CHECK(lockerB.try_unlock(flags));
  }

  {
    ActorLocker lockerA(&state);
    CHECK(lockerA.try_lock());
    auto flags = lockerA.flags();
    flags.add_signals(ActorSignals::one(ActorSignals::Pause));
    CHECK(lockerA.try_unlock(flags));
    //We have to lock, though we can't execute.
    CHECK(lockerA.add_signals(wakeup_signal));
  }
}

#if !TD_THREAD_UNSUPPORTED
TEST(Actor2, locker_stress) {
  using namespace td::actor::core;
  ActorState state;

  constexpr size_t threads_n = 5;
  auto stage = [&](std::atomic<int> &value, int need) {
    value.fetch_add(1, std::memory_order_release);
    while (value.load(std::memory_order_acquire) < need) {
      td::this_thread::yield();
    }
  };

  struct Node {
    std::atomic<td::uint32> request{0};
    td::uint32 response = 0;
    char pad[64];
  };
  std::array<Node, threads_n> nodes;
  auto do_work = [&]() {
    for (auto &node : nodes) {
      auto query = node.request.load(std::memory_order_acquire);
      if (query) {
        node.response = query * query;
        node.request.store(0, std::memory_order_relaxed);
      }
    }
  };

  std::atomic<int> begin{0};
  std::atomic<int> ready{0};
  std::atomic<int> check{0};
  std::vector<td::thread> threads;
  for (size_t i = 0; i < threads_n; i++) {
    threads.push_back(td::thread([&, id = i] {
      for (size_t i = 1; i < 1000000; i++) {
        ActorLocker locker(&state);
        auto need = static_cast<int>(threads_n * i);
        auto query = static_cast<td::uint32>(id + need);
        stage(begin, need);
        nodes[id].request = 0;
        nodes[id].response = 0;
        stage(ready, need);
        if (locker.try_lock()) {
          nodes[id].response = query * query;
        } else {
          auto cpu = ActorSignals::one(ActorSignals::Cpu);
          nodes[id].request.store(query, std::memory_order_release);
          locker.add_signals(cpu);
        }
        while (locker.own_lock()) {
          auto flags = locker.flags();
          auto signals = flags.get_signals();
          if (!signals.empty()) {
            do_work();
          }
          flags.clear_signals();
          locker.try_unlock(flags);
        }

        stage(check, need);
        if (id == 0) {
          CHECK(locker.add_signals(ActorSignals{}));
          CHECK(!locker.flags().has_signals());
          CHECK(locker.try_unlock(locker.flags()));
          for (size_t thread_id = 0; thread_id < threads_n; thread_id++) {
            LOG_CHECK(nodes[thread_id].response ==
                      static_cast<td::uint32>(thread_id + need) * static_cast<td::uint32>(thread_id + need))
                << td::tag("thread", thread_id) << " " << nodes[thread_id].response << " "
                << nodes[thread_id].request.load();
          }
        }
      }
    }));
  }
  for (auto &thread : threads) {
    thread.join();
  }
}

namespace {
const size_t BUF_SIZE = 1024 * 1024;
char buf[BUF_SIZE];
td::StringBuilder sb(td::MutableSlice(buf, BUF_SIZE - 1));
}  // namespace

TEST(Actor2, executor_simple) {
  using namespace td::actor::core;
  using namespace td::actor;
  using td::actor::detail::ActorMessageCreator;
  struct Dispatcher : public SchedulerDispatcher {
    void add_to_queue(ActorInfoPtr ptr, SchedulerId scheduler_id, bool need_poll) override {
      queue.push_back(std::move(ptr));
    }
    void set_alarm_timestamp(const ActorInfoPtr &actor_info_ptr) override {
      UNREACHABLE();
    }
    SchedulerId get_scheduler_id() const override {
      return SchedulerId{0};
    }
    std::deque<ActorInfoPtr> queue;
  };
  Dispatcher dispatcher;

  class TestActor : public Actor {
   public:
    void close() {
      stop();
    }

   private:
    void start_up() override {
      sb << "StartUp";
    }
    void tear_down() override {
      sb << "TearDown";
    }
  };
  {
    ActorInfoCreator actor_info_creator;
    auto actor = actor_info_creator.create(
        std::make_unique<TestActor>(), ActorInfoCreator::Options().on_scheduler(SchedulerId{0}).with_name("TestActor"));
    dispatcher.add_to_queue(actor, SchedulerId{0}, false);

    {
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options());
      CHECK(!executor.is_closed());
      CHECK(executor.can_send_immediate());
      LOG_CHECK(sb.as_cslice() == "StartUp") << sb.as_cslice();
      sb.clear();
      executor.send(ActorMessageCreator::lambda([&] { sb << "A"; }));
      LOG_CHECK(sb.as_cslice() == "A") << sb.as_cslice();
      sb.clear();
      auto big_message = ActorMessageCreator::lambda([&] { sb << "big"; });
      big_message.set_big();
      executor.send(std::move(big_message));
      LOG_CHECK(sb.as_cslice() == "") << sb.as_cslice();
      executor.send(ActorMessageCreator::lambda([&] { sb << "B"; }));
      LOG_CHECK(sb.as_cslice() == "") << sb.as_cslice();
    }
    CHECK(dispatcher.queue.size() == 1);
    { ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options().with_from_queue()); }
    CHECK(dispatcher.queue.size() == 1);
    dispatcher.queue.clear();
    LOG_CHECK(sb.as_cslice() == "bigB") << sb.as_cslice();
    sb.clear();
    {
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options());
      executor.send(
          ActorMessageCreator::lambda([&] { static_cast<TestActor &>(ActorExecuteContext::get()->actor()).close(); }));
    }
    LOG_CHECK(sb.as_cslice() == "TearDown") << sb.as_cslice();
    sb.clear();
    CHECK(!actor->has_actor());
    {
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options());
      executor.send(
          ActorMessageCreator::lambda([&] { static_cast<TestActor &>(ActorExecuteContext::get()->actor()).close(); }));
    }
    CHECK(dispatcher.queue.empty());
    CHECK(sb.as_cslice() == "");
  }

  {
    ActorInfoCreator actor_info_creator;
    auto actor = actor_info_creator.create(
        std::make_unique<TestActor>(), ActorInfoCreator::Options().on_scheduler(SchedulerId{0}).with_name("TestActor"));
    dispatcher.add_to_queue(actor, SchedulerId{0}, false);
    {
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options());
      CHECK(!executor.is_closed());
      CHECK(executor.can_send_immediate());
      LOG_CHECK(sb.as_cslice() == "StartUp") << sb.as_cslice();
      sb.clear();
      auto a_msg = ActorMessageCreator::lambda([&] {
        sb << "big pause";
        ActorExecuteContext::get()->set_pause();
      });
      a_msg.set_big();
      executor.send(std::move(a_msg));
      executor.send(ActorMessageCreator::lambda([&] { sb << "A"; }));
      LOG_CHECK(sb.as_cslice() == "") << sb.as_cslice();
    }
    {
      CHECK(dispatcher.queue.size() == 1);
      dispatcher.queue.clear();
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options().with_from_queue());
      CHECK(!executor.is_closed());
      CHECK(!executor.can_send_immediate());
      LOG_CHECK(sb.as_cslice() == "big pause") << sb.as_cslice();
      sb.clear();
    }
    {
      CHECK(dispatcher.queue.size() == 1);
      dispatcher.queue.clear();
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options().with_from_queue());
      CHECK(!executor.is_closed());
      CHECK(executor.can_send_immediate());
      LOG_CHECK(sb.as_cslice() == "A") << sb.as_cslice();
      sb.clear();
    }
    {
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options());
      executor.send(
          ActorMessageCreator::lambda([&] { static_cast<TestActor &>(ActorExecuteContext::get()->actor()).close(); }));
    }
    LOG_CHECK(sb.as_cslice() == "TearDown") << sb.as_cslice();
    sb.clear();
    dispatcher.queue.clear();
  }
}

using namespace td::actor;
using td::uint32;
static std::atomic<int> global_cnt;
class Worker : public Actor {
 public:
  void query(uint32 x, core::ActorInfoPtr master);
  void close() {
    stop();
  }
};
class Master : public Actor {
 public:
  void on_result(uint32 x, uint32 y) {
    loop();
  }

 private:
  uint32 l = 0;
  uint32 r = 1000;
  core::ActorInfoPtr worker;
  void start_up() override {
    worker = detail::create_actor<Worker>(ActorOptions().with_name("Master"));
    loop();
  }
  void loop() override {
    l++;
    if (l == r) {
      if (!--global_cnt) {
        SchedulerContext::get()->stop();
      }
      detail::send_closure(*worker, &Worker::close);
      stop();
      return;
    }
    detail::send_lambda(*worker,
                        [x = l, self = get_actor_info_ptr()] { detail::current_actor<Worker>().query(x, self); });
  }
};

void Worker::query(uint32 x, core::ActorInfoPtr master) {
  auto y = x;
  for (int i = 0; i < 100; i++) {
    y = y * y;
  }
  detail::send_lambda(*master, [result = y, x] { detail::current_actor<Master>().on_result(x, result); });
}

TEST(Actor2, scheduler_simple) {
  auto group_info = std::make_shared<core::SchedulerGroupInfo>(1);
  core::Scheduler scheduler{group_info, SchedulerId{0}, 2};
  scheduler.start();
  scheduler.run_in_context([] {
    global_cnt = 1000;
    for (int i = 0; i < global_cnt; i++) {
      detail::create_actor<Master>(ActorOptions().with_name("Master"));
    }
  });
  while (scheduler.run(1000)) {
  }
  core::Scheduler::close_scheduler_group(*group_info);
}

TEST(Actor2, actor_id_simple) {
  auto group_info = std::make_shared<core::SchedulerGroupInfo>(1);
  core::Scheduler scheduler{group_info, SchedulerId{0}, 2};
  sb.clear();
  scheduler.start();

  scheduler.run_in_context([] {
    class A : public Actor {
     public:
      A(int value) : value_(value) {
        sb << "A" << value_;
      }
      void hello() {
        sb << "hello";
      }
      ~A() {
        sb << "~A";
        if (--global_cnt <= 0) {
          SchedulerContext::get()->stop();
        }
      }

     private:
      int value_;
    };
    global_cnt = 1;
    auto id = create_actor<A>("A", 123);
    CHECK(sb.as_cslice() == "A123");
    sb.clear();
    send_closure(id, &A::hello);
  });
  while (scheduler.run(1000)) {
  }
  CHECK(sb.as_cslice() == "hello~A");
  core::Scheduler::close_scheduler_group(*group_info);
  sb.clear();
}

TEST(Actor2, actor_creation) {
  auto group_info = std::make_shared<core::SchedulerGroupInfo>(1);
  core::Scheduler scheduler{group_info, SchedulerId{0}, 1};
  scheduler.start();

  scheduler.run_in_context([] {
    class B;
    class A : public Actor {
     public:
      void f() {
        check();
        stop();
      }

     private:
      void start_up() override {
        check();
        create_actor<B>("Simple", actor_id(this)).release();
      }

      void check() {
        auto &context = *SchedulerContext::get();
        CHECK(context.has_poll());
        context.get_poll();
      }

      void tear_down() override {
        if (--global_cnt <= 0) {
          SchedulerContext::get()->stop();
        }
      }
    };

    class B : public Actor {
     public:
      B(ActorId<A> a) : a_(a) {
      }

     private:
      void start_up() override {
        auto &context = *SchedulerContext::get();
        CHECK(!context.has_poll());
        send_closure(a_, &A::f);
        stop();
      }
      void tear_down() override {
        if (--global_cnt <= 0) {
          SchedulerContext::get()->stop();
        }
      }
      ActorId<A> a_;
    };
    global_cnt = 2;
    create_actor<A>(ActorOptions().with_name("Poll").with_poll()).release();
  });
  while (scheduler.run(1000)) {
  }
  scheduler.stop();
  core::Scheduler::close_scheduler_group(*group_info);
}

TEST(Actor2, actor_timeout_simple) {
  auto group_info = std::make_shared<core::SchedulerGroupInfo>(1);
  core::Scheduler scheduler{group_info, SchedulerId{0}, 2};
  sb.clear();
  scheduler.start();

  auto watcher = td::create_shared_destructor([] { SchedulerContext::get()->stop(); });
  scheduler.run_in_context([watcher = std::move(watcher)] {
    class A : public Actor {
     public:
      A(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
      }
      void start_up() override {
        set_timeout();
      }
      void alarm() override {
        double diff = td::Time::now() - expected_timeout_;
        LOG_CHECK(-0.001 < diff && diff < 0.1) << diff;
        if (cnt_-- > 0) {
          set_timeout();
        } else {
          stop();
        }
      }

     private:
      std::shared_ptr<td::Destructor> watcher_;
      double expected_timeout_;
      int cnt_ = 5;
      void set_timeout() {
        auto wakeup_timestamp = td::Timestamp::in(0.1);
        expected_timeout_ = wakeup_timestamp.at();
        alarm_timestamp() = wakeup_timestamp;
      }
    };
    create_actor<A>(core::ActorInfoCreator::Options().with_name("A").with_poll(), watcher).release();
    create_actor<A>(core::ActorInfoCreator::Options().with_name("B"), watcher).release();
  });
  watcher.reset();
  while (scheduler.run(1000)) {
  }
  core::Scheduler::close_scheduler_group(*group_info);
  sb.clear();
}

TEST(Actor2, actor_timeout_simple2) {
  auto group_info = std::make_shared<core::SchedulerGroupInfo>(1);
  core::Scheduler scheduler{group_info, SchedulerId{0}, 2};
  sb.clear();
  scheduler.start();

  auto watcher = td::create_shared_destructor([] { SchedulerContext::get()->stop(); });
  scheduler.run_in_context([watcher = std::move(watcher)] {
    class A : public Actor {
     public:
      A(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
      }
      void start_up() override {
        set_timeout();
      }
      void alarm() override {
        set_timeout();
      }

     private:
      std::shared_ptr<td::Destructor> watcher_;
      void set_timeout() {
        auto wakeup_timestamp = td::Timestamp::in(0.001);
        alarm_timestamp() = wakeup_timestamp;
      }
    };
    class B : public Actor {
     public:
      B(std::shared_ptr<td::Destructor> watcher, ActorOwn<> actor_own)
          : watcher_(std::move(watcher)), actor_own_(std::move(actor_own)) {
      }
      void start_up() override {
        set_timeout();
      }
      void alarm() override {
        stop();
      }

     private:
      std::shared_ptr<td::Destructor> watcher_;
      ActorOwn<> actor_own_;
      void set_timeout() {
        auto wakeup_timestamp = td::Timestamp::in(0.005);
        alarm_timestamp() = wakeup_timestamp;
      }
    };
    auto actor_own = create_actor<A>(core::ActorInfoCreator::Options().with_name("A").with_poll(), watcher);
    create_actor<B>(core::ActorInfoCreator::Options().with_name("B"), watcher, std::move(actor_own)).release();
  });
  watcher.reset();
  while (scheduler.run(1000)) {
  }
  core::Scheduler::close_scheduler_group(*group_info);
  sb.clear();
}

TEST(Actor2, actor_function_result) {
  auto group_info = std::make_shared<core::SchedulerGroupInfo>(1);
  core::Scheduler scheduler{group_info, SchedulerId{0}, 2};
  sb.clear();
  scheduler.start();

  auto watcher = td::create_shared_destructor([] { SchedulerContext::get()->stop(); });
  scheduler.run_in_context([watcher = std::move(watcher)] {
    class B : public Actor {
     public:
      uint32 query(uint32 x) {
        return x * x;
      }
      void query_async(uint32 x, td::Promise<uint32> promise) {
        promise(x * x);
      }
    };
    class A : public Actor {
     public:
      A(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
      }
      void on_result(uint32 x, uint32 y) {
        LOG_CHECK(x * x == y) << x << " " << y;
        if (--cnt_ == 0) {
          stop();
        }
      }
      void start_up() {
        b_ = create_actor<B>(ActorOptions().with_name("B"));
        cnt_ = 3;
        send_closure(b_, &B::query, 3, [a = std::make_unique<int>(), self = actor_id(this)](td::Result<uint32> y) {
          LOG_IF(ERROR, y.is_error()) << y.error();
          send_closure(self, &A::on_result, 3, y.ok());
        });
        send_closure(b_, &B::query_async, 2, [self = actor_id(this)](uint32 y) {
          CHECK(!self.empty());
          send_closure(self, &A::on_result, 2, y);
        });
        send_closure_later(b_, &B::query_async, 5, [self = actor_id(this)](uint32 y) {
          CHECK(!self.empty());
          send_closure(self, &A::on_result, 5, y);
        });
      }

     private:
      int cnt_{0};
      std::shared_ptr<td::Destructor> watcher_;
      td::actor::ActorOwn<B> b_;
    };
    create_actor<A>(core::ActorInfoCreator::Options().with_name("A").with_poll(), watcher).release();
    create_actor<A>(core::ActorInfoCreator::Options().with_name("B"), watcher).release();
  });
  watcher.reset();
  while (scheduler.run(1000)) {
  }
  core::Scheduler::close_scheduler_group(*group_info);
  sb.clear();
}

TEST(Actor2, actor_ping_pong) {
  auto group_info = std::make_shared<core::SchedulerGroupInfo>(1);
  core::Scheduler scheduler{group_info, SchedulerId{0}, 3};
  sb.clear();
  scheduler.start();

  auto watcher = td::create_shared_destructor([] { SchedulerContext::get()->stop(); });
  for (int i = 0; i < 2000; i++) {
    scheduler.run_in_context([watcher] {
      class PingPong : public Actor {
       public:
        PingPong(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
        }
        void query(td::int32 left, ActorOwn<> data) {
          if (td::Random::fast(0, 4) == 0) {
            alarm_timestamp() = td::Timestamp::in(0.01 * td::Random::fast(0, 10));
          }
          if (left <= 0) {
            return;
          }
          auto dest = td::Random::fast(0, (int)next_.size() - 1);
          if (td::Random::fast(0, 1) == 0) {
            send_closure(next_[dest], &PingPong::query, left - 1, std::move(data));
          } else {
            send_closure_later(next_[dest], &PingPong::query, left - 1, std::move(data));
          }
        }
        void add_next(ActorId<PingPong> p) {
          next_.push_back(std::move(p));
        }
        void start_up() override {
        }
        void store_data(ActorOwn<> data) {
          data_.push_back(std::move(data));
        }

       private:
        std::vector<ActorId<PingPong>> next_;
        std::vector<ActorOwn<>> data_;
        std::shared_ptr<td::Destructor> watcher_;
      };

      int N = td::Random::fast(2, 100);
      //N = 2;
      std::vector<ActorOwn<PingPong>> actors;
      for (int i = 0; i < N; i++) {
        actors.push_back(
            create_actor<PingPong>(core::ActorInfoCreator::Options().with_name(PSLICE() << "Worker#" << i), watcher));
      }
      for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
          send_closure(actors[i], &PingPong::add_next, actors[j].get());
        }
      }
      int nn = td::Random::fast(1, N);
      //nn = 2;
      auto first = actors[0].get();
      for (int i = 0; i < N; i++) {
        auto to = actors[i].get();
        if (i < nn) {
          send_closure(to, &PingPong::query, td::Random::fast(10, 1000), std::move(actors[i]));
        } else {
          send_closure(first, &PingPong::store_data, std::move(actors[i]));
        }
      }
    });
  }
  watcher.reset();
  while (scheduler.run(1000)) {
  }
  core::Scheduler::close_scheduler_group(*group_info);
  sb.clear();
}

TEST(Actor2, Schedulers) {
  for (auto mode : {Scheduler::Running, Scheduler::Paused}) {
    for (auto start_count : {0, 1, 2}) {
      for (auto run_count : {0, 1, 2}) {
        for (auto stop_count : {0, 1, 2}) {
          for (size_t threads : {0, 1}) {
            Scheduler scheduler({threads}, mode);
            for (int i = 0; i < start_count; i++) {
              scheduler.start();
            }
            for (int i = 0; i < run_count; i++) {
              scheduler.run(0);
            }
            for (int i = 0; i < stop_count; i++) {
              scheduler.stop();
            }
          }
        }
      }
    }
  }
}
TEST(Actor2, SchedulerZeroCpuThreads) {
  Scheduler scheduler({0});
  scheduler.run_in_context([] {
    class A : public Actor {
      void start_up() override {
        SchedulerContext::get()->stop();
      }
    };
    create_actor<A>(ActorOptions().with_name("A").with_poll(false)).release();
  });
  scheduler.run();
}
TEST(Actor2, SchedulerTwo) {
  Scheduler scheduler({0, 0});
  scheduler.run_in_context([] {
    class B : public Actor {
     public:
      void start_up() override {
        CHECK(SchedulerContext::get()->get_scheduler_id() == SchedulerId{1});
      }
      void close() {
        CHECK(SchedulerContext::get()->get_scheduler_id() == SchedulerId{1});
        SchedulerContext::get()->stop();
      }
    };
    class A : public Actor {
      void start_up() override {
        CHECK(SchedulerContext::get()->get_scheduler_id() == SchedulerId{0});
        auto id =
            create_actor<B>(ActorOptions().with_name("B").with_poll(false).on_scheduler(SchedulerId{1})).release();
        send_closure(id, &B::close);
      }
    };
    create_actor<A>(ActorOptions().with_name("A").with_poll(false).on_scheduler(SchedulerId{0})).release();
  });
  scheduler.run();
}
TEST(Actor2, ActorIdDynamicCast) {
  Scheduler scheduler({0});
  scheduler.run_in_context([] {
    class A : public Actor {
     public:
      void close() {
        CHECK(actor_id().actor_info_ptr() == get_actor_info_ptr());
        SchedulerContext::get()->stop();
      }
    };
    auto actor_own_a = create_actor<A>(ActorOptions().with_name("A").with_poll(false));
    auto actor = &actor_own_a.get_actor_unsafe();
    ActorOwn<> actor_own = actor_dynamic_cast<Actor>(std::move(actor_own_a));
    CHECK(actor_own_a.empty());
    actor_own_a = actor_dynamic_cast<A>(std::move(actor_own));
    CHECK(actor_own.empty());
    CHECK(&actor_own_a.get_actor_unsafe() == actor);

    auto actor_id_a = actor_own_a.release();
    ActorId<> actor_id = actor_dynamic_cast<Actor>(actor_id_a);
    actor_id_a = actor_dynamic_cast<A>(actor_id);
    CHECK(&actor_id_a.get_actor_unsafe() == actor);

    auto actor_shared_a = ActorShared<A>(actor_id_a, 123);
    ActorShared<> actor_shared = actor_dynamic_cast<Actor>(std::move(actor_shared_a));
    CHECK(actor_shared_a.empty());
    CHECK(actor_shared.token() == 123);
    actor_shared_a = actor_dynamic_cast<A>(std::move(actor_shared));
    CHECK(actor_shared.empty());
    CHECK(&actor_shared_a.get_actor_unsafe() == actor);
    CHECK(actor_shared_a.token() == 123);

    send_closure(actor_shared_a, &A::close);
  });
  scheduler.run();
}

TEST(Actor2, send_vs_close) {
  for (int it = 0; it < 100; it++) {
    Scheduler scheduler({8});

    auto watcher = td::create_shared_destructor([] { SchedulerContext::get()->stop(); });
    scheduler.run_in_context([watcher = std::move(watcher)] {
      class To : public Actor {
       public:
        class Callback {
         public:
          virtual ~Callback() {
          }
          virtual void on_closed(ActorId<To> to) = 0;
        };
        To(int cnt, std::shared_ptr<td::Destructor> watcher) : cnt_(cnt), watcher_(std::move(watcher)) {
        }
        void on_event() {
          if (--cnt_ <= 0) {
            stop();
          }
        }
        void add_callback(std::unique_ptr<Callback> callback) {
          callbacks_.push_back(std::move(callback));
        }
        void start_up() override {
          alarm_timestamp() = td::Timestamp::in(td::Random::fast(0, 4) * 0.001);
        }
        void tear_down() override {
          if (td::Random::fast(0, 4) == 0) {
            send_closure(actor_id(this), &To::self_ref, actor_id(this));
          }
          for (auto &callback : callbacks_) {
            callback->on_closed(actor_id(this));
          }
        }
        void self_ref(ActorId<To>) {
        }
        void alarm() override {
          stop();
        }

       private:
        int cnt_;
        std::shared_ptr<td::Destructor> watcher_;
        std::vector<std::unique_ptr<Callback>> callbacks_;
      };
      class From : public Actor {
       public:
        From(std::vector<ActorId<To>> to, std::shared_ptr<td::Destructor> watcher)
            : to_(std::move(to)), watcher_(std::move(watcher)) {
        }
        void start_up() override {
          yield();
        }
        void on_closed(ActorId<To>) {
        }
        void loop() override {
          while (!to_.empty()) {
            if (td::Random::fast(0, 3) == 0) {
              break;
            }
            auto id = to_.back();
            to_.pop_back();
            if (td::Random::fast(0, 4) == 0) {
              class Callback : public To::Callback {
               public:
                Callback(ActorId<From> from) : from_(std::move(from)) {
                }
                void on_closed(ActorId<To> id) override {
                  send_closure(from_, &From::on_closed, std::move(id));
                }

               private:
                ActorId<From> from_;
              };
              send_closure(id, &To::add_callback, std::make_unique<Callback>(actor_id(this)));
            }
            send_closure(id, &To::on_event);
          }
          if (to_.empty()) {
            stop();
          } else {
            yield();
          }
        }

       private:
        std::vector<ActorId<To>> to_;
        std::shared_ptr<td::Destructor> watcher_;
      };

      class Master : public Actor {
       public:
        Master(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
        }

       private:
        std::shared_ptr<td::Destructor> watcher_;
        int cnt_ = 10;
        void loop() override {
          if (cnt_-- < 0) {
            return stop();
          }
          int from_n = 5;
          int to_n = 5;
          std::vector<std::vector<ActorId<To>>> from(from_n);
          for (int i = 0; i < to_n; i++) {
            int cnt = td::Random::fast(1, 10);
            int to_cnt = td::Random::fast(1, cnt);
            auto to =
                td::actor::create_actor<To>(
                    td::actor::ActorOptions().with_name(PSLICE() << "To#" << i).with_poll(td::Random::fast(0, 4) == 0),
                    to_cnt, watcher_)
                    .release();
            for (int j = 0; j < cnt; j++) {
              auto from_i = td::Random::fast(0, from_n - 1);
              from[from_i].push_back(to);
            }
          }
          for (int i = 0; i < from_n; i++) {
            td::actor::create_actor<From>(
                td::actor::ActorOptions().with_name(PSLICE() << "From#" << i).with_poll(td::Random::fast(0, 4) == 0),
                std::move(from[i]), watcher_)
                .release();
          }
          alarm_timestamp() = td::Timestamp::in(td::Random::fast(0, 10) * 0.01 / 30);
        }
      };
      td::actor::create_actor<Master>("Master", watcher).release();
    });

    scheduler.run();
  }
}
TEST(Actor2, send_vs_close2) {
  for (int it = 0; it < 100; it++) {
    Scheduler scheduler({8});

    auto watcher = td::create_shared_destructor([] { SchedulerContext::get()->stop(); });
    //std::shared_ptr<td::Destructor> watcher;
    scheduler.run_in_context([watcher = std::move(watcher)] {
      class To : public Actor {
       public:
        To(int cnt, std::shared_ptr<td::Destructor> watcher) : cnt_(cnt), watcher_(std::move(watcher)) {
        }
        void start_up() override {
          alarm_timestamp() = td::Timestamp::in(td::Random::fast(0, 4) * 0.001 / 30);
        }
        void alarm() override {
          stop();
        }

       private:
        int cnt_;
        std::shared_ptr<td::Destructor> watcher_;
      };
      class From : public Actor {
       public:
        From(std::vector<ActorId<To>> to, std::shared_ptr<td::Destructor> watcher)
            : to_(std::move(to)), watcher_(std::move(watcher)) {
        }
        void start_up() override {
          stop();
        }

       private:
        std::vector<ActorId<To>> to_;
        std::shared_ptr<td::Destructor> watcher_;
      };

      class Master : public Actor {
       public:
        Master(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
        }

       private:
        std::shared_ptr<td::Destructor> watcher_;
        int cnt_ = 5;
        void loop() override {
          if (cnt_-- < 0) {
            return stop();
          }
          int from_n = 2;
          int to_n = 2;
          std::vector<std::vector<ActorId<To>>> from(from_n);
          for (int i = 0; i < to_n; i++) {
            int cnt = td::Random::fast(1, 2);
            int to_cnt = td::Random::fast(1, cnt);
            auto to =
                td::actor::create_actor<To>(
                    td::actor::ActorOptions().with_name(PSLICE() << "To#" << i).with_poll(td::Random::fast(0, 4) == 0),
                    to_cnt, watcher_)
                    .release();
            for (int j = 0; j < cnt; j++) {
              auto from_i = td::Random::fast(0, from_n - 1);
              from[from_i].push_back(to);
            }
          }
          for (int i = 0; i < from_n; i++) {
            td::actor::create_actor<From>(
                td::actor::ActorOptions().with_name(PSLICE() << "From#" << i).with_poll(td::Random::fast(0, 4) == 0),
                std::move(from[i]), watcher_)
                .release();
          }
          alarm_timestamp() = td::Timestamp::in(td::Random::fast(0, 10) * 0.01 / 30);
        }
      };
      td::actor::create_actor<Master>("Master", watcher).release();
    });

    scheduler.run();
  }
}
#endif  //!TD_THREAD_UNSUPPORTED
