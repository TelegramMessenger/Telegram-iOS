//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/GetHostByNameActor.h"

#include "td/net/HttpQuery.h"
#include "td/net/SslCtx.h"
#include "td/net/Wget.h"

#include "td/utils/common.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

namespace td {
namespace detail {

class GoogleDnsResolver final : public Actor {
 public:
  GoogleDnsResolver(std::string host, bool prefer_ipv6, Promise<IPAddress> promise)
      : host_(std::move(host)), prefer_ipv6_(prefer_ipv6), promise_(std::move(promise)) {
  }

 private:
  std::string host_;
  bool prefer_ipv6_;
  Promise<IPAddress> promise_;
  ActorOwn<Wget> wget_;
  double begin_time_ = 0;

  void start_up() final {
    auto r_address = IPAddress::get_ip_address(host_);
    if (r_address.is_ok()) {
      promise_.set_value(r_address.move_as_ok());
      return stop();
    }

    const int timeout = 10;
    const int ttl = 3;
    begin_time_ = Time::now();
    auto wget_promise = PromiseCreator::lambda([actor_id = actor_id(this)](Result<unique_ptr<HttpQuery>> r_http_query) {
      send_closure(actor_id, &GoogleDnsResolver::on_result, std::move(r_http_query));
    });
    wget_ = create_actor<Wget>(
        "GoogleDnsResolver", std::move(wget_promise),
        PSTRING() << "https://dns.google/resolve?name=" << url_encode(host_) << "&type=" << (prefer_ipv6_ ? 28 : 1),
        std::vector<std::pair<string, string>>({{"Host", "dns.google"}}), timeout, ttl, prefer_ipv6_,
        SslCtx::VerifyPeer::Off);
  }

  static Result<IPAddress> get_ip_address(Result<unique_ptr<HttpQuery>> r_http_query) {
    TRY_RESULT(http_query, std::move(r_http_query));

    auto get_ip_address = [](JsonValue &answer) -> Result<IPAddress> {
      auto &array = answer.get_array();
      if (array.empty()) {
        return Status::Error("Failed to parse DNS result: Answer is an empty array");
      }
      if (array[0].type() != JsonValue::Type::Object) {
        return Status::Error("Failed to parse DNS result: Answer[0] is not an object");
      }
      auto &answer_0 = array[0].get_object();
      TRY_RESULT(ip_str, answer_0.get_required_string_field("data"));
      IPAddress ip;
      TRY_STATUS(ip.init_host_port(ip_str, 0));
      return ip;
    };
    if (!http_query->get_arg("Answer").empty()) {
      TRY_RESULT(answer, json_decode(http_query->get_arg("Answer")));
      if (answer.type() != JsonValue::Type::Array) {
        return Status::Error("Expected JSON array");
      }
      return get_ip_address(answer);
    } else {
      TRY_RESULT(json_value, json_decode(http_query->content_));
      if (json_value.type() != JsonValue::Type::Object) {
        return Status::Error("Failed to parse DNS result: not an object");
      }
      auto &object = json_value.get_object();
      TRY_RESULT(answer, object.extract_required_field("Answer", JsonValue::Type::Array));
      return get_ip_address(answer);
    }
  }

  void on_result(Result<unique_ptr<HttpQuery>> r_http_query) {
    auto end_time = Time::now();
    auto result = get_ip_address(std::move(r_http_query));
    VLOG(dns_resolver) << "Init IPv" << (prefer_ipv6_ ? "6" : "4") << " host = " << host_ << " in "
                       << end_time - begin_time_ << " seconds to "
                       << (result.is_ok() ? (PSLICE() << result.ok()) : CSlice("[invalid]"));
    promise_.set_result(std::move(result));
    stop();
  }
};

class NativeDnsResolver final : public Actor {
 public:
  NativeDnsResolver(std::string host, bool prefer_ipv6, Promise<IPAddress> promise)
      : host_(std::move(host)), prefer_ipv6_(prefer_ipv6), promise_(std::move(promise)) {
  }

 private:
  std::string host_;
  bool prefer_ipv6_;
  Promise<IPAddress> promise_;

  void start_up() final {
    IPAddress ip;
    auto begin_time = Time::now();
    auto status = ip.init_host_port(host_, 0, prefer_ipv6_);
    auto end_time = Time::now();
    VLOG(dns_resolver) << "Init host = " << host_ << " in " << end_time - begin_time << " seconds to " << ip;
    if (status.is_error()) {
      promise_.set_error(std::move(status));
    } else {
      promise_.set_value(std::move(ip));
    }
    stop();
  }
};

}  // namespace detail

int VERBOSITY_NAME(dns_resolver) = VERBOSITY_NAME(DEBUG);

GetHostByNameActor::GetHostByNameActor(Options options) : options_(std::move(options)) {
  CHECK(!options_.resolver_types.empty());
}

void GetHostByNameActor::run(string host, int port, bool prefer_ipv6, Promise<IPAddress> promise) {
  TRY_RESULT_PROMISE(promise, ascii_host, idn_to_ascii(host));
  if (ascii_host.empty()) {
    return promise.set_error(Status::Error("Host is empty"));
  }

  auto begin_time = Time::now();
  auto &value = cache_[prefer_ipv6].emplace(ascii_host, Value{{}, begin_time - 1.0}).first->second;
  if (value.expires_at > begin_time) {
    return promise.set_result(value.get_ip_port(port));
  }

  auto &query_ptr = active_queries_[prefer_ipv6][ascii_host];
  if (query_ptr == nullptr) {
    query_ptr = make_unique<Query>();
  }
  auto &query = *query_ptr;
  query.promises.emplace_back(port, std::move(promise));
  if (query.query.empty()) {
    CHECK(query.promises.size() == 1);
    query.real_host = std::move(host);
    query.begin_time = Time::now();
    run_query(std::move(ascii_host), prefer_ipv6, query);
  }
}

void GetHostByNameActor::run_query(std::string host, bool prefer_ipv6, Query &query) {
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), host, prefer_ipv6](Result<IPAddress> res) mutable {
    send_closure(actor_id, &GetHostByNameActor::on_query_result, std::move(host), prefer_ipv6, std::move(res));
  });

  CHECK(query.query.empty());
  CHECK(query.pos < options_.resolver_types.size());
  auto resolver_type = options_.resolver_types[query.pos++];
  query.query = [&] {
    switch (resolver_type) {
      case ResolverType::Native:
        return ActorOwn<>(create_actor_on_scheduler<detail::NativeDnsResolver>(
            "NativeDnsResolver", options_.scheduler_id, std::move(host), prefer_ipv6, std::move(promise)));
      case ResolverType::Google:
        return ActorOwn<>(create_actor_on_scheduler<detail::GoogleDnsResolver>(
            "GoogleDnsResolver", options_.scheduler_id, std::move(host), prefer_ipv6, std::move(promise)));
      default:
        UNREACHABLE();
        return ActorOwn<>();
    }
  }();
}

void GetHostByNameActor::on_query_result(std::string host, bool prefer_ipv6, Result<IPAddress> result) {
  auto query_it = active_queries_[prefer_ipv6].find(host);
  CHECK(query_it != active_queries_[prefer_ipv6].end());
  auto &query = *query_it->second;
  CHECK(!query.promises.empty());
  CHECK(!query.query.empty());

  if (result.is_error() && query.pos < options_.resolver_types.size()) {
    query.query.reset();
    return run_query(std::move(host), prefer_ipv6, query);
  }

  auto end_time = Time::now();
  VLOG(dns_resolver) << "Init host = " << query.real_host << " in total of " << end_time - query.begin_time
                     << " seconds to " << (result.is_ok() ? (PSLICE() << result.ok()) : CSlice("[invalid]"));

  auto promises = std::move(query.promises);
  auto value_it = cache_[prefer_ipv6].find(host);
  CHECK(value_it != cache_[prefer_ipv6].end());
  auto cache_timeout = result.is_ok() ? options_.ok_timeout : options_.error_timeout;
  value_it->second = Value{std::move(result), end_time + cache_timeout};
  active_queries_[prefer_ipv6].erase(query_it);

  for (auto &promise : promises) {
    promise.second.set_result(value_it->second.get_ip_port(promise.first));
  }
}

}  // namespace td
