//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/QueryMerger.h"

#include "td/utils/logging.h"

namespace td {

QueryMerger::QueryMerger(Slice name, size_t max_concurrent_query_count, size_t max_merged_query_count)
    : max_concurrent_query_count_(max_concurrent_query_count), max_merged_query_count_(max_merged_query_count) {
  register_actor(name, this).release();
}

void QueryMerger::add_query(int64 query_id, Promise<Unit> &&promise, const char *source) {
  LOG(INFO) << "Add query " << query_id << " with" << (promise ? "" : "out") << " promise from " << source;
  CHECK(query_id != 0);
  auto &query = queries_[query_id];
  query.promises_.push_back(std::move(promise));
  if (query.promises_.size() != 1) {
    // duplicate query, just wait
    return;
  }
  pending_queries_.push(query_id);
  loop();
}

void QueryMerger::send_query(vector<int64> query_ids) {
  CHECK(merge_function_ != nullptr);
  LOG(INFO) << "Send queries " << query_ids;
  query_count_++;
  merge_function_(query_ids, PromiseCreator::lambda([actor_id = actor_id(this), query_ids](Result<Unit> &&result) {
                    send_closure(actor_id, &QueryMerger::on_get_query_result, std::move(query_ids), std::move(result));
                  }));
}

void QueryMerger::on_get_query_result(vector<int64> query_ids, Result<Unit> &&result) {
  LOG(INFO) << "Get result of queries " << query_ids << (result.is_error() ? " error" : " success");
  query_count_--;
  for (auto query_id : query_ids) {
    auto it = queries_.find(query_id);
    CHECK(it != queries_.end());
    auto promises = std::move(it->second.promises_);
    queries_.erase(it);

    if (result.is_ok()) {
      set_promises(promises);
    } else {
      fail_promises(promises, result.error().clone());
    }
  }
  loop();
}

void QueryMerger::loop() {
  if (query_count_ == max_concurrent_query_count_) {
    return;
  }

  vector<int64> query_ids;
  while (!pending_queries_.empty()) {
    auto query_id = pending_queries_.front();
    pending_queries_.pop();
    query_ids.push_back(query_id);
    if (query_ids.size() == max_merged_query_count_) {
      send_query(std::move(query_ids));
      query_ids.clear();
      if (query_count_ == max_concurrent_query_count_) {
        break;
      }
    }
  }
  if (!query_ids.empty()) {
    send_query(std::move(query_ids));
  }
}

}  // namespace td
