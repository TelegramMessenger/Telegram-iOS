//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/logging.h"
#include "td/utils/Time.h"

class Worker final : public td::Actor {
 public:
  void ping(int x) {
    LOG(ERROR) << "Receive ping " << x;
  }
};

class MainActor final : public td::Actor {
 public:
  void start_up() final {
    LOG(ERROR) << "Start up";
    set_timeout_in(10);
    worker_ = td::create_actor_on_scheduler<Worker>("Worker", 1);
    send_closure(worker_, &Worker::ping, 123);
  }

  void timeout_expired() final {
    LOG(ERROR) << "Timeout expired";
    td::Scheduler::instance()->finish();
  }

 private:
  td::ActorOwn<Worker> worker_;
};

int main() {
  td::ConcurrentScheduler scheduler(4 /*thread_count*/, 0);
  scheduler.start();
  {
    auto guard = scheduler.get_main_guard();
    td::create_actor_on_scheduler<MainActor>("Main actor", 0).release();
  }
  while (!scheduler.is_finished()) {
    scheduler.run_main(td::Timestamp::in(10));
  }
  scheduler.finish();
}
