//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"
#include "td/actor/MultiPromise.h"
#include "td/actor/PromiseFuture.h"
#include "td/actor/SleepActor.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/MpscPollableQueue.h"
#include "td/utils/Observer.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/thread.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/Time.h"

#include <memory>
#include <tuple>

static const size_t BUF_SIZE = 1024 * 1024;
static char buf[BUF_SIZE];
static char buf2[BUF_SIZE];
static td::StringBuilder sb(td::MutableSlice(buf, BUF_SIZE - 1));
static td::StringBuilder sb2(td::MutableSlice(buf2, BUF_SIZE - 1));

static td::vector<std::shared_ptr<td::MpscPollableQueue<td::EventFull>>> create_queues() {
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  return {};
#else
  auto res = std::make_shared<td::MpscPollableQueue<td::EventFull>>();
  res->init();
  return {res};
#endif
}

TEST(Actors, SendLater) {
  sb.clear();
  td::Scheduler scheduler;
  scheduler.init(0, create_queues(), nullptr);

  auto guard = scheduler.get_guard();
  class Worker final : public td::Actor {
   public:
    void f() {
      sb << "A";
    }
  };
  auto id = td::create_actor<Worker>("Worker");
  scheduler.run_no_guard(td::Timestamp::in(1));
  td::send_closure(id, &Worker::f);
  td::send_closure_later(id, &Worker::f);
  td::send_closure(id, &Worker::f);
  ASSERT_STREQ("A", sb.as_cslice().c_str());
  scheduler.run_no_guard(td::Timestamp::in(1));
  ASSERT_STREQ("AAA", sb.as_cslice().c_str());
}

class X {
 public:
  X() {
    sb << "[cnstr_default]";
  }
  X(const X &) {
    sb << "[cnstr_copy]";
  }
  X(X &&) noexcept {
    sb << "[cnstr_move]";
  }
  X &operator=(const X &) {
    sb << "[set_copy]";
    return *this;
  }
  X &operator=(X &&) noexcept {
    sb << "[set_move]";
    return *this;
  }
  ~X() = default;
};

class XReceiver final : public td::Actor {
 public:
  void by_const_ref(const X &) {
    sb << "[by_const_ref]";
  }
  void by_lvalue_ref(const X &) {
    sb << "[by_lvalue_ref]";
  }
  void by_value(X) {
    sb << "[by_value]";
  }
};

TEST(Actors, simple_pass_event_arguments) {
  td::Scheduler scheduler;
  scheduler.init(0, create_queues(), nullptr);

  auto guard = scheduler.get_guard();
  auto id = td::create_actor<XReceiver>("XR").release();
  scheduler.run_no_guard(td::Timestamp::in(1));

  X x;

  // check tuple
  // std::tuple<X> tx;
  // sb.clear();
  // std::tuple<X> ty(std::move(tx));
  // tx = std::move(ty);
  // ASSERT_STREQ("[cnstr_move]", sb.as_cslice().c_str());

  // Send temporary object

  // Tmp-->ConstRef
  sb.clear();
  td::send_closure(id, &XReceiver::by_const_ref, X());
  ASSERT_STREQ("[cnstr_default][by_const_ref]", sb.as_cslice().c_str());

  // Tmp-->ConstRef (Delayed)
  sb.clear();
  td::send_closure_later(id, &XReceiver::by_const_ref, X());
  scheduler.run_no_guard(td::Timestamp::in(1));
  // LOG(ERROR) << sb.as_cslice();
  ASSERT_STREQ("[cnstr_default][cnstr_move][by_const_ref]", sb.as_cslice().c_str());

  // Tmp-->LvalueRef
  sb.clear();
  td::send_closure(id, &XReceiver::by_lvalue_ref, X());
  ASSERT_STREQ("[cnstr_default][by_lvalue_ref]", sb.as_cslice().c_str());

  // Tmp-->LvalueRef (Delayed)
  sb.clear();
  td::send_closure_later(id, &XReceiver::by_lvalue_ref, X());
  scheduler.run_no_guard(td::Timestamp::in(1));
  ASSERT_STREQ("[cnstr_default][cnstr_move][by_lvalue_ref]", sb.as_cslice().c_str());

  // Tmp-->Value
  sb.clear();
  td::send_closure(id, &XReceiver::by_value, X());
  ASSERT_STREQ("[cnstr_default][cnstr_move][by_value]", sb.as_cslice().c_str());

  // Tmp-->Value (Delayed)
  sb.clear();
  td::send_closure_later(id, &XReceiver::by_value, X());
  scheduler.run_no_guard(td::Timestamp::in(1));
  ASSERT_STREQ("[cnstr_default][cnstr_move][cnstr_move][by_value]", sb.as_cslice().c_str());

  // Var-->ConstRef
  sb.clear();
  td::send_closure(id, &XReceiver::by_const_ref, x);
  ASSERT_STREQ("[by_const_ref]", sb.as_cslice().c_str());

  // Var-->ConstRef (Delayed)
  sb.clear();
  td::send_closure_later(id, &XReceiver::by_const_ref, x);
  scheduler.run_no_guard(td::Timestamp::in(1));
  ASSERT_STREQ("[cnstr_copy][by_const_ref]", sb.as_cslice().c_str());

  // Var-->LvalueRef
  // Var-->LvalueRef (Delayed)
  // CE or strange behaviour

  // Var-->Value
  sb.clear();
  td::send_closure(id, &XReceiver::by_value, x);
  ASSERT_STREQ("[cnstr_copy][by_value]", sb.as_cslice().c_str());

  // Var-->Value (Delayed)
  sb.clear();
  td::send_closure_later(id, &XReceiver::by_value, x);
  scheduler.run_no_guard(td::Timestamp::in(1));
  ASSERT_STREQ("[cnstr_copy][cnstr_move][by_value]", sb.as_cslice().c_str());
}

class PrintChar final : public td::Actor {
 public:
  PrintChar(char c, int cnt) : char_(c), cnt_(cnt) {
  }
  void start_up() final {
    yield();
  }
  void wakeup() final {
    if (cnt_ == 0) {
      stop();
    } else {
      sb << char_;
      cnt_--;
      yield();
    }
  }

 private:
  char char_;
  int cnt_;
};

//
// Yield must add actor to the end of queue
//
TEST(Actors, simple_hand_yield) {
  td::Scheduler scheduler;
  scheduler.init(0, create_queues(), nullptr);
  sb.clear();
  int cnt = 1000;
  {
    auto guard = scheduler.get_guard();
    td::create_actor<PrintChar>("PrintA", 'A', cnt).release();
    td::create_actor<PrintChar>("PrintB", 'B', cnt).release();
    td::create_actor<PrintChar>("PrintC", 'C', cnt).release();
  }
  scheduler.run(td::Timestamp::in(1));
  td::string expected;
  for (int i = 0; i < cnt; i++) {
    expected += "ABC";
  }
  ASSERT_STREQ(expected.c_str(), sb.as_cslice().c_str());
}

class Ball {
 public:
  friend void start_migrate(Ball &ball, td::int32 sched_id) {
    sb << "start";
  }
  friend void finish_migrate(Ball &ball) {
    sb2 << "finish";
  }
};

class Pong final : public td::Actor {
 public:
  void pong(Ball ball) {
    td::Scheduler::instance()->finish();
  }
};

class Ping final : public td::Actor {
 public:
  explicit Ping(td::ActorId<Pong> pong) : pong_(pong) {
  }
  void start_up() final {
    td::send_closure(pong_, &Pong::pong, Ball());
  }

 private:
  td::ActorId<Pong> pong_;
};

TEST(Actors, simple_migrate) {
  sb.clear();
  sb2.clear();

  td::ConcurrentScheduler scheduler(2, 0);
  auto pong = scheduler.create_actor_unsafe<Pong>(2, "Pong").release();
  scheduler.create_actor_unsafe<Ping>(1, "Ping", pong).release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  ASSERT_STREQ("", sb.as_cslice().c_str());
  ASSERT_STREQ("", sb2.as_cslice().c_str());
#else
  ASSERT_STREQ("start", sb.as_cslice().c_str());
  ASSERT_STREQ("finish", sb2.as_cslice().c_str());
#endif
}

class OpenClose final : public td::Actor {
 public:
  explicit OpenClose(int cnt) : cnt_(cnt) {
  }
  void start_up() final {
    yield();
  }
  void wakeup() final {
    auto observer = reinterpret_cast<td::ObserverBase *>(123);
    td::CSlice file_name = "server";
    if (cnt_ > 0) {
      auto r_file_fd = td::FileFd::open(file_name, td::FileFd::Read | td::FileFd::Create);
      LOG_CHECK(r_file_fd.is_ok()) << r_file_fd.error();
      auto file_fd = r_file_fd.move_as_ok();
      { auto pollable_fd = file_fd.get_poll_info().extract_pollable_fd(observer); }
      file_fd.close();
      cnt_--;
      yield();
    } else {
      td::Scheduler::instance()->finish();
    }
  }

 private:
  int cnt_;
};

TEST(Actors, open_close) {
  td::ConcurrentScheduler scheduler(2, 0);
  int cnt = 10000;  // TODO(perf) optimize
  scheduler.create_actor_unsafe<OpenClose>(1, "A", cnt).release();
  scheduler.create_actor_unsafe<OpenClose>(2, "B", cnt).release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
  td::unlink("server").ignore();
}

class MsgActor : public td::Actor {
 public:
  virtual void msg() = 0;
};

class Slave final : public td::Actor {
 public:
  td::ActorId<MsgActor> msg;
  explicit Slave(td::ActorId<MsgActor> msg) : msg(msg) {
  }
  void hangup() final {
    td::send_closure(msg, &MsgActor::msg);
  }
};

class MasterActor final : public MsgActor {
 public:
  void loop() final {
    alive_ = true;
    slave = td::create_actor<Slave>("Slave", static_cast<td::ActorId<MsgActor>>(actor_id(this)));
    stop();
  }
  td::ActorOwn<Slave> slave;

  MasterActor() = default;
  MasterActor(const MasterActor &) = delete;
  MasterActor &operator=(const MasterActor &) = delete;
  MasterActor(MasterActor &&) = delete;
  MasterActor &operator=(MasterActor &&) = delete;
  ~MasterActor() final {
    alive_ = 987654321;
  }
  void msg() final {
    CHECK(alive_ == 123456789);
  }
  td::uint64 alive_ = 123456789;
};

TEST(Actors, call_after_destruct) {
  td::Scheduler scheduler;
  scheduler.init(0, create_queues(), nullptr);
  {
    auto guard = scheduler.get_guard();
    td::create_actor<MasterActor>("Master").release();
  }
  scheduler.run(td::Timestamp::in(1));
}

class LinkTokenSlave final : public td::Actor {
 public:
  explicit LinkTokenSlave(td::ActorShared<> parent) : parent_(std::move(parent)) {
  }
  void add(td::uint64 link_token) {
    CHECK(link_token == get_link_token());
  }
  void close() {
    stop();
  }

 private:
  td::ActorShared<> parent_;
};

class LinkTokenMasterActor final : public td::Actor {
 public:
  explicit LinkTokenMasterActor(int cnt) : cnt_(cnt) {
  }
  void start_up() final {
    child_ = td::create_actor<LinkTokenSlave>("Slave", actor_shared(this, 123)).release();
    yield();
  }
  void loop() final {
    for (int i = 0; i < 100 && cnt_ > 0; cnt_--, i++) {
      auto token = static_cast<td::uint64>(cnt_) + 1;
      switch (i % 4) {
        case 0: {
          td::send_closure(td::ActorShared<LinkTokenSlave>(child_, token), &LinkTokenSlave::add, token);
          break;
        }
        case 1: {
          td::send_closure_later(td::ActorShared<LinkTokenSlave>(child_, token), &LinkTokenSlave::add, token);
          break;
        }
        case 2: {
          td::EventCreator::closure(td::ActorShared<LinkTokenSlave>(child_, token), &LinkTokenSlave::add, token)
              .try_emit();
          break;
        }
        case 3: {
          td::EventCreator::closure(td::ActorShared<LinkTokenSlave>(child_, token), &LinkTokenSlave::add, token)
              .try_emit_later();
          break;
        }
      }
    }
    if (cnt_ == 0) {
      td::send_closure(child_, &LinkTokenSlave::close);
    } else {
      yield();
    }
  }

  void hangup_shared() final {
    CHECK(get_link_token() == 123);
    td::Scheduler::instance()->finish();
    stop();
  }

 private:
  int cnt_;
  td::ActorId<LinkTokenSlave> child_;
};

TEST(Actors, link_token) {
  td::ConcurrentScheduler scheduler(0, 0);
  auto cnt = 100000;
  scheduler.create_actor_unsafe<LinkTokenMasterActor>(0, "A", cnt).release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
}

TEST(Actors, promise) {
  int value = -1;
  td::Promise<int> p1 = td::PromiseCreator::lambda([&](int x) { value = x; });
  p1.set_error(td::Status::Error("Test error"));
  ASSERT_EQ(0, value);
  td::Promise<td::int32> p2 = td::PromiseCreator::lambda([&](td::Result<td::int32> x) { value = 1; });
  p2.set_error(td::Status::Error("Test error"));
  ASSERT_EQ(1, value);
}

class LaterSlave final : public td::Actor {
 public:
  explicit LaterSlave(td::ActorShared<> parent) : parent_(std::move(parent)) {
  }

 private:
  td::ActorShared<> parent_;

  void hangup() final {
    sb << "A";
    td::send_closure(actor_id(this), &LaterSlave::finish);
  }
  void finish() {
    sb << "B";
    stop();
  }
};

class LaterMasterActor final : public td::Actor {
  int cnt_ = 3;
  td::vector<td::ActorOwn<LaterSlave>> children_;
  void start_up() final {
    for (int i = 0; i < cnt_; i++) {
      children_.push_back(td::create_actor<LaterSlave>("B", actor_shared(this)));
    }
    yield();
  }
  void loop() final {
    children_.clear();
  }
  void hangup_shared() final {
    if (!--cnt_) {
      td::Scheduler::instance()->finish();
      stop();
    }
  }
};

TEST(Actors, later) {
  sb.clear();
  td::ConcurrentScheduler scheduler(0, 0);
  scheduler.create_actor_unsafe<LaterMasterActor>(0, "A").release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
  ASSERT_STREQ(sb.as_cslice().c_str(), "AAABBB");
}

class MultiPromise2 final : public td::Actor {
 public:
  void start_up() final {
    auto promise = td::PromiseCreator::lambda([](td::Result<td::Unit> result) {
      result.ensure();
      td::Scheduler::instance()->finish();
    });

    td::MultiPromiseActorSafe multi_promise{"MultiPromiseActor2"};
    multi_promise.add_promise(std::move(promise));
    for (int i = 0; i < 10; i++) {
      td::create_actor<td::SleepActor>("Sleep", 0.1, multi_promise.get_promise()).release();
    }
  }
};

class MultiPromise1 final : public td::Actor {
 public:
  void start_up() final {
    auto promise = td::PromiseCreator::lambda([](td::Result<td::Unit> result) {
      CHECK(result.is_error());
      td::create_actor<MultiPromise2>("B").release();
    });
    td::MultiPromiseActorSafe multi_promise{"MultiPromiseActor1"};
    multi_promise.add_promise(std::move(promise));
  }
};

TEST(Actors, MultiPromise) {
  td::ConcurrentScheduler scheduler(0, 0);
  scheduler.create_actor_unsafe<MultiPromise1>(0, "A").release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
}

class FastPromise final : public td::Actor {
 public:
  void start_up() final {
    td::PromiseFuture<int> pf;
    auto promise = pf.move_promise();
    auto future = pf.move_future();
    promise.set_value(123);
    CHECK(future.move_as_ok() == 123);
    td::Scheduler::instance()->finish();
  }
};

TEST(Actors, FastPromise) {
  td::ConcurrentScheduler scheduler(0, 0);
  scheduler.create_actor_unsafe<FastPromise>(0, "A").release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
}

class StopInTeardown final : public td::Actor {
  void loop() final {
    stop();
  }
  void tear_down() final {
    stop();
    td::Scheduler::instance()->finish();
  }
};

TEST(Actors, stop_in_teardown) {
  td::ConcurrentScheduler scheduler(0, 0);
  scheduler.create_actor_unsafe<StopInTeardown>(0, "A").release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
}

class AlwaysWaitForMailbox final : public td::Actor {
 public:
  void start_up() final {
    td::create_actor<td::SleepActor>("Sleep", 0.1,
                                     td::PromiseCreator::lambda([actor_id = actor_id(this), ptr = this](td::Unit) {
                                       td::send_closure(actor_id, &AlwaysWaitForMailbox::g);
                                       td::send_closure(actor_id, &AlwaysWaitForMailbox::g);
                                       CHECK(!ptr->was_f_);
                                     }))
        .release();
  }

  void f() {
    was_f_ = true;
    td::Scheduler::instance()->finish();
  }
  void g() {
    td::send_closure(actor_id(this), &AlwaysWaitForMailbox::f);
  }

 private:
  bool was_f_{false};
};

TEST(Actors, always_wait_for_mailbox) {
  td::ConcurrentScheduler scheduler(0, 0);
  scheduler.create_actor_unsafe<AlwaysWaitForMailbox>(0, "A").release();
  scheduler.start();
  while (scheduler.run_main(10)) {
  }
  scheduler.finish();
}

#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
TEST(Actors, send_from_other_threads) {
  td::ConcurrentScheduler scheduler(1, 0);
  int thread_n = 10;
  class Listener final : public td::Actor {
   public:
    explicit Listener(int cnt) : cnt_(cnt) {
    }
    void dec() {
      if (--cnt_ == 0) {
        td::Scheduler::instance()->finish();
      }
    }

   private:
    int cnt_;
  };

  auto A = scheduler.create_actor_unsafe<Listener>(1, "A", thread_n).release();
  scheduler.start();
  td::vector<td::thread> threads(thread_n);
  for (auto &thread : threads) {
    thread = td::thread([&A, &scheduler] {
      auto guard = scheduler.get_send_guard();
      td::send_closure(A, &Listener::dec);
    });
  }
  while (scheduler.run_main(10)) {
  }
  for (auto &thread : threads) {
    thread.join();
  }
  scheduler.finish();
}
#endif

class DelayedCall final : public td::Actor {
 public:
  void on_called(int *step) {
    CHECK(*step == 0);
    *step = 1;
  }
};

class MultiPromiseSendClosureLaterTest final : public td::Actor {
 public:
  void start_up() final {
    delayed_call_ = td::create_actor<DelayedCall>("DelayedCall").release();
    mpa_.add_promise(td::PromiseCreator::lambda([this](td::Unit) {
      CHECK(step_ == 1);
      step_++;
      td::Scheduler::instance()->finish();
    }));
    auto lock = mpa_.get_promise();
    td::send_closure_later(delayed_call_, &DelayedCall::on_called, &step_);
    lock.set_value(td::Unit());
  }

  void tear_down() final {
    CHECK(step_ == 2);
  }

 private:
  int step_ = 0;
  td::MultiPromiseActor mpa_{"MultiPromiseActor"};
  td::ActorId<DelayedCall> delayed_call_;
};

TEST(Actors, MultiPromiseSendClosureLater) {
  td::ConcurrentScheduler scheduler(0, 0);
  scheduler.create_actor_unsafe<MultiPromiseSendClosureLaterTest>(0, "MultiPromiseSendClosureLaterTest").release();
  scheduler.start();
  while (scheduler.run_main(1)) {
  }
  scheduler.finish();
}
