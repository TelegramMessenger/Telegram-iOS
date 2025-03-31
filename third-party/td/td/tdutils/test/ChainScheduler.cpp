//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/algorithm.h"
#include "td/utils/ChainScheduler.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Span.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"

#include <memory>
#include <numeric>

TEST(ChainScheduler, CreateAfterActive) {
  td::ChainScheduler<int> scheduler;
  td::vector<td::ChainScheduler<int>::ChainId> chains{1};

  auto first_task_id = scheduler.create_task(chains, 1);
  ASSERT_EQ(first_task_id, scheduler.start_next_task().unwrap().task_id);
  auto second_task_id = scheduler.create_task(chains, 2);
  ASSERT_EQ(second_task_id, scheduler.start_next_task().unwrap().task_id);
}

TEST(ChainScheduler, RestartAfterActive) {
  td::ChainScheduler<int> scheduler;
  std::vector<td::ChainScheduler<int>::ChainId> chains{1};

  auto first_task_id = scheduler.create_task(chains, 1);
  auto second_task_id = scheduler.create_task(chains, 2);
  ASSERT_EQ(first_task_id, scheduler.start_next_task().unwrap().task_id);
  ASSERT_EQ(second_task_id, scheduler.start_next_task().unwrap().task_id);

  scheduler.reset_task(first_task_id);
  ASSERT_EQ(first_task_id, scheduler.start_next_task().unwrap().task_id);

  scheduler.reset_task(second_task_id);
  ASSERT_EQ(second_task_id, scheduler.start_next_task().unwrap().task_id);
}

TEST(ChainScheduler, SendAfterRestart) {
  td::ChainScheduler<int> scheduler;
  std::vector<td::ChainScheduler<int>::ChainId> chains{1};

  auto first_task_id = scheduler.create_task(chains, 1);
  auto second_task_id = scheduler.create_task(chains, 2);
  ASSERT_EQ(first_task_id, scheduler.start_next_task().unwrap().task_id);
  ASSERT_EQ(second_task_id, scheduler.start_next_task().unwrap().task_id);

  scheduler.reset_task(first_task_id);

  scheduler.create_task(chains, 3);

  ASSERT_EQ(first_task_id, scheduler.start_next_task().unwrap().task_id);
  ASSERT_TRUE(!scheduler.start_next_task());
}

TEST(ChainScheduler, Basic) {
  td::ChainScheduler<int> scheduler;
  for (int i = 0; i < 100; i++) {
    scheduler.create_task({td::ChainScheduler<int>::ChainId{1}}, i);
  }
  int j = 0;
  while (j != 100) {
    td::vector<td::ChainScheduler<int>::TaskId> tasks;
    while (true) {
      auto o_task_id = scheduler.start_next_task();
      if (!o_task_id) {
        break;
      }
      auto task_id = o_task_id.value().task_id;
      auto extra = *scheduler.get_task_extra(task_id);
      auto parents =
          td::transform(o_task_id.value().parents, [&](auto parent) { return *scheduler.get_task_extra(parent); });
      LOG(INFO) << "Start " << extra << parents;
      CHECK(extra == j);
      j++;
      tasks.push_back(task_id);
    }
    for (auto &task_id : tasks) {
      auto extra = *scheduler.get_task_extra(task_id);
      LOG(INFO) << "Finish " << extra;
      scheduler.finish_task(task_id);
    }
  }
}

struct ChainSchedulerQuery;
using QueryPtr = std::shared_ptr<ChainSchedulerQuery>;
using ChainId = td::ChainScheduler<QueryPtr>::ChainId;
using TaskId = td::ChainScheduler<QueryPtr>::TaskId;

struct ChainSchedulerQuery {
  int id{};
  TaskId task_id{};
  bool is_ok{};
  bool skipped{};
};

TEST(ChainScheduler, Stress) {
  td::Random::Xorshift128plus rnd(123);
  int max_query_id = 100000;
  int MAX_INFLIGHT_QUERIES = 20;
  int ChainsN = 4;

  struct QueryWithParents {
    TaskId task_id;
    QueryPtr id;
    td::vector<QueryPtr> parents;
  };
  td::vector<QueryWithParents> active_queries;

  td::ChainScheduler<QueryPtr> scheduler;
  td::vector<td::vector<QueryPtr>> chains(ChainsN + 1);
  int inflight_queries{};
  int current_query_id{};
  int sent_cnt{};
  bool done = false;
  std::vector<TaskId> pending_queries;

  auto schedule_new_query = [&] {
    if (current_query_id > max_query_id) {
      if (inflight_queries == 0) {
        done = true;
      }
      return;
    }
    if (inflight_queries >= MAX_INFLIGHT_QUERIES) {
      return;
    }
    auto query_id = current_query_id++;
    auto query = std::make_shared<ChainSchedulerQuery>();
    query->id = query_id;
    int chain_n = rnd.fast(1, ChainsN);
    td::vector<ChainId> chain_ids(ChainsN);
    std::iota(chain_ids.begin(), chain_ids.end(), 1);
    td::rand_shuffle(td::as_mutable_span(chain_ids), rnd);
    chain_ids.resize(chain_n);
    for (auto chain_id : chain_ids) {
      chains[td::narrow_cast<size_t>(chain_id)].push_back(query);
    }
    auto task_id = scheduler.create_task(chain_ids, query);
    query->task_id = task_id;
    pending_queries.push_back(task_id);
    inflight_queries++;
  };

  auto check_parents_ok = [&](const QueryWithParents &query_with_parents) -> bool {
    return td::all_of(query_with_parents.parents, [](const auto &parent) { return parent->is_ok; });
  };

  auto to_query_ptr = [&](TaskId task_id) {
    return *scheduler.get_task_extra(task_id);
  };
  auto flush_pending_queries = [&] {
    while (true) {
      auto o_task_with_parents = scheduler.start_next_task();
      if (!o_task_with_parents) {
        break;
      }
      auto task_with_parents = o_task_with_parents.unwrap();
      QueryWithParents query_with_parents;
      query_with_parents.task_id = task_with_parents.task_id;
      query_with_parents.id = to_query_ptr(task_with_parents.task_id);
      query_with_parents.parents = td::transform(task_with_parents.parents, to_query_ptr);
      active_queries.push_back(query_with_parents);
      sent_cnt++;
    }
  };
  auto skip_one_query = [&] {
    if (pending_queries.empty()) {
      return;
    }
    auto it = pending_queries.begin() + rnd.fast(0, static_cast<int>(pending_queries.size()) - 1);
    auto task_id = *it;
    pending_queries.erase(it);
    td::remove_if(active_queries, [&](auto &q) { return q.task_id == task_id; });

    auto query = *scheduler.get_task_extra(task_id);
    query->skipped = true;
    scheduler.finish_task(task_id);
    inflight_queries--;
    LOG(INFO) << "Skip " << query->id;
  };
  auto execute_one_query = [&] {
    if (active_queries.empty()) {
      return;
    }
    auto it = active_queries.begin() + rnd.fast(0, static_cast<int>(active_queries.size()) - 1);
    auto query_with_parents = *it;
    active_queries.erase(it);

    auto query = query_with_parents.id;
    if (rnd.fast(0, 20) == 0) {
      scheduler.finish_task(query->task_id);
      td::remove(pending_queries, query->task_id);
      inflight_queries--;
      LOG(INFO) << "Fail " << query->id;
    } else if (check_parents_ok(query_with_parents)) {
      query->is_ok = true;
      scheduler.finish_task(query->task_id);
      td::remove(pending_queries, query->task_id);
      inflight_queries--;
      LOG(INFO) << "OK " << query->id;
    } else {
      scheduler.reset_task(query->task_id);
      LOG(INFO) << "Reset " << query->id;
    }
  };

  td::RandomSteps steps({{schedule_new_query, 100}, {execute_one_query, 100}, {skip_one_query, 10}});
  while (!done) {
    steps.step(rnd);
    flush_pending_queries();
    // LOG(INFO) << scheduler;
  }
  LOG(INFO) << "Sent queries count " << sent_cnt;
  LOG(INFO) << "Total queries " << current_query_id;
  for (auto &chain : chains) {
    int prev_ok = -1;
    int failed_cnt = 0;
    int ok_cnt = 0;
    int skipped_cnt = 0;
    for (auto &q : chain) {
      if (q->is_ok) {
        CHECK(prev_ok < q->id);
        prev_ok = q->id;
        ok_cnt++;
      } else {
        if (q->skipped) {
          skipped_cnt++;
        } else {
          failed_cnt++;
        }
      }
    }
    LOG(INFO) << "Chain ok " << ok_cnt << " failed " << failed_cnt << " skipped " << skipped_cnt;
  }
}
