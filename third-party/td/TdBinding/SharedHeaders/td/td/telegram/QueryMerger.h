//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <functional>
#include <queue>

namespace td {

// merges queries into a single request
class QueryMerger final : public Actor {
 public:
  QueryMerger(Slice name, size_t max_concurrent_query_count, size_t max_merged_query_count);

  using MergeFunction = std::function<void(vector<int64> query_ids, Promise<Unit> &&promise)>;
  void set_merge_function(MergeFunction merge_function) {
    merge_function_ = std::move(merge_function);
  }

  void add_query(int64 query_id, Promise<Unit> &&promise, const char *source);

 private:
  struct QueryInfo {
    vector<Promise<Unit>> promises_;
  };

  size_t query_count_ = 0;
  size_t max_concurrent_query_count_;
  size_t max_merged_query_count_;

  MergeFunction merge_function_;
  std::queue<int64> pending_queries_;
  FlatHashMap<int64, QueryInfo> queries_;

  void send_query(vector<int64> query_ids);

  void on_get_query_result(vector<int64> query_ids, Result<Unit> &&result);

  void loop() final;
};

}  // namespace td
