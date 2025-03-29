//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/QueryMerger.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"
#include "td/actor/SleepActor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/logging.h"
#include "td/utils/Promise.h"
#include "td/utils/Random.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"

#include <queue>

class TestQueryMerger final : public td::Actor {
  void start_up() final {
    query_merger_.set_merge_function([this](td::vector<td::int64> query_ids, td::Promise<td::Unit> &&promise) {
      ASSERT_TRUE(!query_ids.empty());
      ASSERT_EQ(query_ids.size(), td::min(next_query_ids_.size(), MAX_MERGED_QUERY_COUNT));
      for (auto query_id : query_ids) {
        auto next_query_id = next_query_ids_.front();
        next_query_ids_.pop();
        ASSERT_EQ(query_id, next_query_id);
      }
      current_query_count_++;
      ASSERT_TRUE(current_query_count_ <= MAX_CONCURRENT_QUERY_COUNT);
      if (!next_query_ids_.empty()) {
        ASSERT_EQ(current_query_count_, MAX_CONCURRENT_QUERY_COUNT);
      }
      td::create_actor<td::SleepActor>("CompleteMergeQuery", 0.02,
                                       td::PromiseCreator::lambda([this, query_ids, promise = std::move(promise)](
                                                                      td::Result<td::Unit> result) mutable {
                                         for (auto query_id : query_ids) {
                                           LOG(INFO) << "Complete " << query_id;
                                           bool is_erased = pending_query_ids_.erase(query_id) > 0;
                                           ASSERT_TRUE(is_erased);
                                         }
                                         current_query_count_--;
                                         promise.set_result(std::move(result));
                                       }))
          .release();
      yield();
    });
    loop();
  }

  void loop() final {
    std::size_t query_count = 0;
    std::size_t added_queries = td::Random::fast(1, 3);
    while (query_count++ < added_queries && total_query_count_++ < MAX_QUERY_COUNT) {
      td::int64 query_id = td::Random::fast(1, 20);
      if (pending_query_ids_.insert(query_id).second) {
        next_query_ids_.push(query_id);
      }
      query_merger_.add_query(query_id, td::PromiseCreator::lambda([this](td::Result<td::Unit> result) mutable {
                                completed_query_count_++;
                                if (completed_query_count_ == MAX_QUERY_COUNT) {
                                  ASSERT_EQ(current_query_count_, 0u);
                                  ASSERT_TRUE(next_query_ids_.empty());
                                  ASSERT_TRUE(pending_query_ids_.empty());
                                  td::Scheduler::instance()->finish();
                                } else {
                                  yield();
                                }
                              }),
                              "TestQueryMerger::loop");
    }
  }

  static constexpr std::size_t MAX_CONCURRENT_QUERY_COUNT = 5;
  static constexpr std::size_t MAX_MERGED_QUERY_COUNT = 3;
  static constexpr std::size_t MAX_QUERY_COUNT = 1000;

  td::QueryMerger query_merger_{"QueryMerger", MAX_CONCURRENT_QUERY_COUNT, MAX_MERGED_QUERY_COUNT};
  std::size_t current_query_count_ = 0;
  std::size_t total_query_count_ = 0;
  std::size_t completed_query_count_ = 0;

  std::queue<td::int64> next_query_ids_;
  td::FlatHashSet<td::int64> pending_query_ids_;
};

TEST(QueryMerger, stress) {
  td::ConcurrentScheduler sched(0, 0);
  sched.create_actor_unsafe<TestQueryMerger>(0, "TestQueryMerger").release();
  sched.start();
  while (sched.run_main(10)) {
    // empty
  }
  sched.finish();
}
