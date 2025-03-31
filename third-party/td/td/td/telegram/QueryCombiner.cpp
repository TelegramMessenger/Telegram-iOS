//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/QueryCombiner.h"

#include "td/telegram/Global.h"

#include "td/utils/logging.h"
#include "td/utils/Time.h"

namespace td {

QueryCombiner::QueryCombiner(Slice name, double min_delay) : next_query_time_(Time::now()), min_delay_(min_delay) {
  register_actor(name, this).release();
}

void QueryCombiner::add_query(int64 query_id, Promise<Promise<Unit>> &&send_query, Promise<Unit> &&promise) {
  LOG(INFO) << "Add query " << query_id << " with" << (promise ? "" : "out") << " promise";
  CHECK(query_id != 0);
  auto &query = queries_[query_id];
  if (promise) {
    query.promises.push_back(std::move(promise));
  } else if (min_delay_ > 0 && !query.is_sent) {
    // if there is no promise, then noone waits for response
    // we can delay query to not exceed any flood limit
    if (query.send_query) {
      // the query is already delayed
      return;
    }
    query.send_query = std::move(send_query);
    delayed_queries_.push(query_id);
    loop();
    return;
  }
  if (query.is_sent) {
    // just wait for the result
    return;
  }

  if (!query.send_query) {
    query.send_query = std::move(send_query);
  }
  do_send_query(query_id, query);
}

void QueryCombiner::do_send_query(int64 query_id, QueryInfo &query) {
  LOG(INFO) << "Send query " << query_id;
  CHECK(query.send_query);
  query.is_sent = true;
  auto send_query = std::move(query.send_query);
  CHECK(!query.send_query);
  next_query_time_ = Time::now() + min_delay_;
  query_count_++;
  send_query.set_value(PromiseCreator::lambda([actor_id = actor_id(this), query_id](Result<Unit> &&result) {
    send_closure(actor_id, &QueryCombiner::on_get_query_result, query_id, std::move(result));
  }));
}

void QueryCombiner::on_get_query_result(int64 query_id, Result<Unit> &&result) {
  LOG(INFO) << "Get result of query " << query_id << (result.is_error() ? " error" : " success");
  query_count_--;
  auto it = queries_.find(query_id);
  CHECK(it != queries_.end());
  CHECK(it->second.is_sent);
  auto promises = std::move(it->second.promises);
  queries_.erase(it);

  if (result.is_ok()) {
    set_promises(promises);
  } else {
    fail_promises(promises, result.move_as_error());
  }
  loop();
}

void QueryCombiner::loop() {
  if (G()->close_flag()) {
    return;
  }

  auto now = Time::now();
  if (now < next_query_time_) {
    set_timeout_in(next_query_time_ - now + 0.001);
    return;
  }
  if (query_count_ != 0) {
    return;
  }

  while (!delayed_queries_.empty()) {
    auto query_id = delayed_queries_.front();
    delayed_queries_.pop();
    auto it = queries_.find(query_id);
    if (it == queries_.end()) {
      continue;
    }
    auto &query = it->second;
    if (query.is_sent) {
      continue;
    }
    do_send_query(query_id, query);
    break;
  }
}

}  // namespace td
