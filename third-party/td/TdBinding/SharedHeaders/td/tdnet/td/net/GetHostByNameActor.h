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
#include "td/utils/logging.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

extern int VERBOSITY_NAME(dns_resolver);

class GetHostByNameActor final : public Actor {
 public:
  enum class ResolverType { Native, Google };

  struct Options {
    static constexpr int32 DEFAULT_CACHE_TIME = 60 * 29;       // 29 minutes
    static constexpr int32 DEFAULT_ERROR_CACHE_TIME = 60 * 5;  // 5 minutes

    vector<ResolverType> resolver_types{ResolverType::Native};
    int32 scheduler_id{-1};
    int32 ok_timeout{DEFAULT_CACHE_TIME};
    int32 error_timeout{DEFAULT_ERROR_CACHE_TIME};
  };

  explicit GetHostByNameActor(Options options);

  void run(std::string host, int port, bool prefer_ipv6, Promise<IPAddress> promise);

 private:
  void on_query_result(std::string host, bool prefer_ipv6, Result<IPAddress> result);

  struct Value {
    Result<IPAddress> ip;
    double expires_at;

    Value(Result<IPAddress> ip, double expires_at) : ip(std::move(ip)), expires_at(expires_at) {
    }

    Result<IPAddress> get_ip_port(int port) const {
      auto result = ip.clone();
      if (result.is_ok()) {
        result.ok_ref().set_port(port);
      }
      return result;
    }
  };
  FlatHashMap<string, Value> cache_[2];

  struct Query {
    ActorOwn<> query;
    size_t pos = 0;
    string real_host;
    double begin_time = 0.0;
    std::vector<std::pair<int, Promise<IPAddress>>> promises;
  };
  FlatHashMap<string, unique_ptr<Query>> active_queries_[2];

  Options options_;

  void run_query(std::string host, bool prefer_ipv6, Query &query);
};

}  // namespace td
