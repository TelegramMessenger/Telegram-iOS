//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"
#include "td/actor/PromiseFuture.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/tests.h"

#include <limits>
#include <map>
#include <memory>
#include <utility>

template <class ContainerT>
static typename ContainerT::value_type &rand_elem(ContainerT &cont) {
  CHECK(0 < cont.size() && cont.size() <= static_cast<size_t>(std::numeric_limits<int>::max()));
  return cont[td::Random::fast(0, static_cast<int>(cont.size()) - 1)];
}

static td::uint32 fast_pow_mod_uint32(td::uint32 x, td::uint32 p) {
  td::uint32 res = 1;
  while (p) {
    if (p & 1) {
      res *= x;
    }
    x *= x;
    p >>= 1;
  }
  return res;
}

static td::uint32 slow_pow_mod_uint32(td::uint32 x, td::uint32 p) {
  td::uint32 res = 1;
  for (td::uint32 i = 0; i < p; i++) {
    res *= x;
  }
  return res;
}

struct ActorQuery {
  td::uint32 query_id{};
  td::uint32 result{};
  td::vector<int> todo;
  ActorQuery() = default;
  ActorQuery(const ActorQuery &) = delete;
  ActorQuery &operator=(const ActorQuery &) = delete;
  ActorQuery(ActorQuery &&) = default;
  ActorQuery &operator=(ActorQuery &&) = default;
  ~ActorQuery() {
    LOG_CHECK(todo.empty()) << "ActorQuery lost";
  }
  int next_pow() {
    CHECK(!todo.empty());
    int res = todo.back();
    todo.pop_back();
    return res;
  }
  bool ready() {
    return todo.empty();
  }
};

static td::uint32 fast_calc(ActorQuery &q) {
  td::uint32 result = q.result;
  for (auto x : q.todo) {
    result = fast_pow_mod_uint32(result, x);
  }
  return result;
}

class Worker final : public td::Actor {
 public:
  explicit Worker(int threads_n) : threads_n_(threads_n) {
  }
  void query(td::PromiseActor<td::uint32> &&promise, td::uint32 x, td::uint32 p) {
    td::uint32 result = slow_pow_mod_uint32(x, p);
    promise.set_value(std::move(result));

    (void)threads_n_;
    // if (threads_n_ > 1 && td::Random::fast(0, 9) == 0) {
    // migrate(td::Random::fast(2, threads_n));
    //}
  }

 private:
  int threads_n_;
};

class QueryActor final : public td::Actor {
 public:
  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    Callback(Callback &&) = delete;
    Callback &operator=(Callback &&) = delete;
    virtual ~Callback() = default;
    virtual void on_result(ActorQuery &&query) = 0;
    virtual void on_closed() = 0;
  };

  explicit QueryActor(int threads_n) : threads_n_(threads_n) {
  }

  void set_callback(td::unique_ptr<Callback> callback) {
    callback_ = std::move(callback);
  }
  void set_workers(td::vector<td::ActorId<Worker>> workers) {
    workers_ = std::move(workers);
  }

  void query(ActorQuery &&query) {
    td::uint32 x = query.result;
    td::uint32 p = query.next_pow();
    if (td::Random::fast(0, 3) && (p <= 1000 || workers_.empty())) {
      query.result = slow_pow_mod_uint32(x, p);
      callback_->on_result(std::move(query));
    } else {
      auto future = td::Random::fast(0, 3) == 0
                        ? td::send_promise_immediately(rand_elem(workers_), &Worker::query, x, p)
                        : td::send_promise_later(rand_elem(workers_), &Worker::query, x, p);
      if (future.is_ready()) {
        query.result = future.move_as_ok();
        callback_->on_result(std::move(query));
      } else {
        future.set_event(td::EventCreator::raw(actor_id(), query.query_id));
        auto query_id = query.query_id;
        pending_.emplace(query_id, std::make_pair(std::move(future), std::move(query)));
      }
    }
    if (threads_n_ > 1 && td::Random::fast(0, 9) == 0) {
      migrate(td::Random::fast(2, threads_n_));
    }
  }

  void raw_event(const td::Event::Raw &event) final {
    td::uint32 id = event.u32;
    auto it = pending_.find(id);
    auto future = std::move(it->second.first);
    auto query = std::move(it->second.second);
    pending_.erase(it);
    CHECK(future.is_ready());
    query.result = future.move_as_ok();
    callback_->on_result(std::move(query));
  }

  void close() {
    callback_->on_closed();
    stop();
  }

  void on_start_migrate(td::int32 sched_id) final {
    for (auto &it : pending_) {
      start_migrate(it.second.first, sched_id);
    }
  }
  void on_finish_migrate() final {
    for (auto &it : pending_) {
      finish_migrate(it.second.first);
    }
  }

 private:
  td::unique_ptr<Callback> callback_;
  std::map<td::uint32, std::pair<td::FutureActor<td::uint32>, ActorQuery>> pending_;
  td::vector<td::ActorId<Worker>> workers_;
  int threads_n_;
};

class MainQueryActor final : public td::Actor {
  class QueryActorCallback final : public QueryActor::Callback {
   public:
    void on_result(ActorQuery &&query) final {
      if (query.ready()) {
        send_closure(parent_id_, &MainQueryActor::on_result, std::move(query));
      } else {
        send_closure(next_solver_, &QueryActor::query, std::move(query));
      }
    }
    void on_closed() final {
      send_closure(parent_id_, &MainQueryActor::on_closed);
    }
    QueryActorCallback(td::ActorId<MainQueryActor> parent_id, td::ActorId<QueryActor> next_solver)
        : parent_id_(parent_id), next_solver_(next_solver) {
    }

   private:
    td::ActorId<MainQueryActor> parent_id_;
    td::ActorId<QueryActor> next_solver_;
  };

  const int ACTORS_CNT = 10;
  const int WORKERS_CNT = 4;

 public:
  explicit MainQueryActor(int threads_n) : threads_n_(threads_n) {
  }

  void start_up() final {
    actors_.resize(ACTORS_CNT);
    for (auto &actor : actors_) {
      auto actor_ptr = td::make_unique<QueryActor>(threads_n_);
      actor = register_actor("QueryActor", std::move(actor_ptr), threads_n_ > 1 ? td::Random::fast(2, threads_n_) : 0)
                  .release();
    }

    workers_.resize(WORKERS_CNT);
    for (auto &worker : workers_) {
      auto actor_ptr = td::make_unique<Worker>(threads_n_);
      worker = register_actor("Worker", std::move(actor_ptr), threads_n_ > 1 ? td::Random::fast(2, threads_n_) : 0)
                   .release();
    }

    for (int i = 0; i < ACTORS_CNT; i++) {
      ref_cnt_++;
      send_closure(actors_[i], &QueryActor::set_callback,
                   td::make_unique<QueryActorCallback>(actor_id(this), actors_[(i + 1) % ACTORS_CNT]));
      send_closure(actors_[i], &QueryActor::set_workers, workers_);
    }
    yield();
  }

  void on_result(ActorQuery &&query) {
    CHECK(query.ready());
    CHECK(query.result == expected_[query.query_id]);
    in_cnt_++;
    wakeup();
  }

  ActorQuery create_query() {
    ActorQuery q;
    q.query_id = (query_id_ += 2);
    q.result = q.query_id;
    q.todo = {1, 1, 1, 1, 1, 1, 1, 1, 10000};
    expected_[q.query_id] = fast_calc(q);
    return q;
  }

  void on_closed() {
    ref_cnt_--;
    if (ref_cnt_ == 0) {
      td::Scheduler::instance()->finish();
    }
  }

  void wakeup() final {
    int cnt = 10000;
    while (out_cnt_ < in_cnt_ + 100 && out_cnt_ < cnt) {
      if (td::Random::fast_bool()) {
        send_closure(rand_elem(actors_), &QueryActor::query, create_query());
      } else {
        send_closure_later(rand_elem(actors_), &QueryActor::query, create_query());
      }
      out_cnt_++;
    }
    if (in_cnt_ == cnt) {
      in_cnt_++;
      ref_cnt_--;
      for (auto &actor : actors_) {
        send_closure(actor, &QueryActor::close);
      }
    }
  }

 private:
  std::map<td::uint32, td::uint32> expected_;
  td::vector<td::ActorId<QueryActor>> actors_;
  td::vector<td::ActorId<Worker>> workers_;
  int out_cnt_ = 0;
  int in_cnt_ = 0;
  int query_id_ = 1;
  int ref_cnt_ = 1;
  int threads_n_;
};

class SimpleActor final : public td::Actor {
 public:
  explicit SimpleActor(td::int32 threads_n) : threads_n_(threads_n) {
  }
  void start_up() final {
    auto actor_ptr = td::make_unique<Worker>(threads_n_);
    worker_ =
        register_actor("Worker", std::move(actor_ptr), threads_n_ > 1 ? td::Random::fast(2, threads_n_) : 0).release();
    yield();
  }

  void wakeup() final {
    if (q_ == 10000) {
      td::Scheduler::instance()->finish();
      stop();
      return;
    }
    q_++;
    p_ = td::Random::fast_bool() ? 1 : 10000;
    auto future = td::Random::fast(0, 3) == 0 ? td::send_promise_immediately(worker_, &Worker::query, q_, p_)
                                              : td::send_promise_later(worker_, &Worker::query, q_, p_);
    if (future.is_ready()) {
      auto result = future.move_as_ok();
      CHECK(result == fast_pow_mod_uint32(q_, p_));
      yield();
    } else {
      future.set_event(td::EventCreator::raw(actor_id(), nullptr));
      future_ = std::move(future);
    }
    // if (threads_n_ > 1 && td::Random::fast(0, 2) == 0) {
    // migrate(td::Random::fast(1, threads_n));
    //}
  }
  void raw_event(const td::Event::Raw &event) final {
    auto result = future_.move_as_ok();
    CHECK(result == fast_pow_mod_uint32(q_, p_));
    yield();
  }

  void on_start_migrate(td::int32 sched_id) final {
    start_migrate(future_, sched_id);
  }
  void on_finish_migrate() final {
    finish_migrate(future_);
  }

 private:
  td::int32 threads_n_;
  td::ActorId<Worker> worker_;
  td::FutureActor<td::uint32> future_;
  td::uint32 q_ = 1;
  td::uint32 p_ = 0;
};

class SendToDead final : public td::Actor {
 public:
  class Parent final : public td::Actor {
   public:
    explicit Parent(td::ActorShared<> parent, int ttl = 3) : parent_(std::move(parent)), ttl_(ttl) {
    }
    void start_up() final {
      set_timeout_in(td::Random::fast_uint32() % 3 * 0.001);
      if (ttl_ != 0) {
        child_ = td::create_actor_on_scheduler<Parent>(
            "Child", td::Random::fast_uint32() % td::Scheduler::instance()->sched_count(), actor_shared(this),
            ttl_ - 1);
      }
    }
    void timeout_expired() final {
      stop();
    }

   private:
    td::ActorOwn<Parent> child_;
    td::ActorShared<> parent_;
    int ttl_;
  };

  void start_up() final {
    for (int i = 0; i < 2000; i++) {
      td::create_actor_on_scheduler<Parent>(
          "Parent", td::Random::fast_uint32() % td::Scheduler::instance()->sched_count(), create_reference(), 4)
          .release();
    }
  }

  td::ActorShared<> create_reference() {
    ref_cnt_++;
    return actor_shared(this);
  }

  void hangup_shared() final {
    ref_cnt_--;
    if (ref_cnt_ == 0) {
      ttl_--;
      if (ttl_ <= 0) {
        td::Scheduler::instance()->finish();
        stop();
      } else {
        start_up();
      }
    }
  }

  td::uint32 ttl_{50};
  td::uint32 ref_cnt_{0};
};

TEST(Actors, send_to_dead) {
  //TODO: fix CHECK(storage_count_.load() == 0)
  return;
  int threads_n = 5;
  td::ConcurrentScheduler sched(threads_n, 0);

  sched.create_actor_unsafe<SendToDead>(0, "SendToDead").release();
  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}

TEST(Actors, main_simple) {
  int threads_n = 3;
  td::ConcurrentScheduler sched(threads_n, 0);

  sched.create_actor_unsafe<SimpleActor>(threads_n > 1 ? 1 : 0, "simple", threads_n).release();
  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}

TEST(Actors, main) {
  int threads_n = 9;
  td::ConcurrentScheduler sched(threads_n, 0);

  sched.create_actor_unsafe<MainQueryActor>(threads_n > 1 ? 1 : 0, "MainQuery", threads_n).release();
  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}

class DoAfterStop final : public td::Actor {
 public:
  void loop() final {
    ptr = td::make_unique<int>(10);
    stop();
    CHECK(*ptr == 10);
    td::Scheduler::instance()->finish();
  }

 private:
  td::unique_ptr<int> ptr;
};

TEST(Actors, do_after_stop) {
  int threads_n = 0;
  td::ConcurrentScheduler sched(threads_n, 0);

  sched.create_actor_unsafe<DoAfterStop>(0, "DoAfterStop").release();
  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}

class XContext final : public td::ActorContext {
 public:
  td::int32 get_id() const final {
    return 123456789;
  }

  void validate() {
    CHECK(x == 1234);
  }
  ~XContext() final {
    x = 0;
  }
  int x = 1234;
};

class WithXContext final : public td::Actor {
 public:
  void start_up() final {
    auto old_context = set_context(std::make_shared<XContext>());
  }
  void f(td::unique_ptr<td::Guard> guard) {
  }
  void close() {
    stop();
  }
};

static void check_context() {
  auto ptr = static_cast<XContext *>(td::Scheduler::context());
  CHECK(ptr != nullptr);
  ptr->validate();
}

TEST(Actors, context_during_destruction) {
  int threads_n = 0;
  td::ConcurrentScheduler sched(threads_n, 0);

  {
    auto guard = sched.get_main_guard();
    auto with_context = td::create_actor<WithXContext>("WithXContext").release();
    send_closure(with_context, &WithXContext::f, td::create_lambda_guard([] { check_context(); }));
    send_closure_later(with_context, &WithXContext::close);
    send_closure(with_context, &WithXContext::f, td::create_lambda_guard([] { check_context(); }));
    send_closure(with_context, &WithXContext::f, td::create_lambda_guard([] { td::Scheduler::instance()->finish(); }));
  }
  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}
