//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/ConnectionCreator.h"

#include "td/telegram/ConfigManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/net/MtprotoHeader.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/NetType.h"
#include "td/telegram/net/PublicRsaKeySharedMain.h"
#include "td/telegram/PromoDataManager.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/TdDb.h"

#include "td/mtproto/DhCallback.h"
#include "td/mtproto/HandshakeActor.h"
#include "td/mtproto/Ping.h"
#include "td/mtproto/ProxySecret.h"
#include "td/mtproto/RSA.h"
#include "td/mtproto/TlsInit.h"

#include "td/net/GetHostByNameActor.h"
#include "td/net/HttpProxy.h"
#include "td/net/Socks5.h"
#include "td/net/TransparentProxy.h"

#include "td/actor/SleepActor.h"

#include "td/utils/algorithm.h"
#include "td/utils/base64.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

#include <utility>

namespace td {

int VERBOSITY_NAME(connections) = VERBOSITY_NAME(INFO);

namespace detail {

class StatsCallback final : public mtproto::RawConnection::StatsCallback {
 public:
  StatsCallback(std::shared_ptr<NetStatsCallback> net_stats_callback, ActorId<ConnectionCreator> connection_creator,
                uint32 hash, DcOptionsSet::Stat *option_stat)
      : net_stats_callback_(std::move(net_stats_callback))
      , connection_creator_(std::move(connection_creator))
      , hash_(hash)
      , option_stat_(option_stat) {
  }

  void on_read(uint64 bytes) final {
    if (net_stats_callback_ != nullptr) {
      net_stats_callback_->on_read(bytes);
    }
  }
  void on_write(uint64 bytes) final {
    if (net_stats_callback_ != nullptr) {
      net_stats_callback_->on_write(bytes);
    }
  }

  void on_pong() final {
    if (option_stat_) {
      send_lambda(connection_creator_, [stat = option_stat_] { stat->on_ok(); });
    }
    send_closure(connection_creator_, &ConnectionCreator::on_pong, hash_);
  }

  void on_error() final {
    if (option_stat_) {
      send_lambda(connection_creator_, [stat = option_stat_] { stat->on_error(); });
    }
  }

  void on_mtproto_error() final {
    send_closure(connection_creator_, &ConnectionCreator::on_mtproto_error, hash_);
  }

 private:
  std::shared_ptr<NetStatsCallback> net_stats_callback_;
  ActorId<ConnectionCreator> connection_creator_;
  uint32 hash_;
  DcOptionsSet::Stat *option_stat_;
};

}  // namespace detail

ConnectionCreator::ClientInfo::ClientInfo() {
  sanity_flood_control.add_limit(5, 10);

  flood_control.add_limit(1, 1);
  flood_control.add_limit(4, 2);
  flood_control.add_limit(8, 3);

  flood_control_online.add_limit(1, 4);
  flood_control_online.add_limit(5, 5);

  mtproto_error_flood_control.add_limit(1, 1);
  mtproto_error_flood_control.add_limit(4, 2);
  mtproto_error_flood_control.add_limit(8, 3);
}

uint64 ConnectionCreator::ClientInfo::extract_session_id() {
  if (!session_ids_.empty()) {
    auto res = *session_ids_.begin();
    session_ids_.erase(session_ids_.begin());
    return res;
  }
  uint64 res = 0;
  while (res == 0) {
    res = Random::secure_uint64();
  }
  return res;
}

void ConnectionCreator::ClientInfo::add_session_id(uint64 session_id) {
  if (session_id != 0) {
    session_ids_.insert(session_id);
  }
}

ConnectionCreator::ConnectionCreator(ActorShared<> parent) : parent_(std::move(parent)) {
}

ConnectionCreator::ConnectionCreator(ConnectionCreator &&) = default;

ConnectionCreator &ConnectionCreator::operator=(ConnectionCreator &&) = default;

ConnectionCreator::~ConnectionCreator() = default;

void ConnectionCreator::set_net_stats_callback(std::shared_ptr<NetStatsCallback> common_callback,
                                               std::shared_ptr<NetStatsCallback> media_callback) {
  common_net_stats_callback_ = std::move(common_callback);
  media_net_stats_callback_ = std::move(media_callback);
}

void ConnectionCreator::add_proxy(int32 old_proxy_id, string server, int32 port, bool enable,
                                  td_api::object_ptr<td_api::ProxyType> proxy_type,
                                  Promise<td_api::object_ptr<td_api::proxy>> promise) {
  TRY_RESULT_PROMISE(promise, new_proxy, Proxy::create_proxy(std::move(server), port, proxy_type.get()));
  if (old_proxy_id >= 0) {
    if (proxies_.count(old_proxy_id) == 0) {
      return promise.set_error(Status::Error(400, "Proxy not found"));
    }
    auto &old_proxy = proxies_[old_proxy_id];
    if (old_proxy == new_proxy) {
      if (enable) {
        enable_proxy_impl(old_proxy_id);
      }
      return promise.set_value(get_proxy_object(old_proxy_id));
    }
    if (old_proxy_id == active_proxy_id_) {
      enable = true;
      disable_proxy_impl();
    }

    proxies_.erase(old_proxy_id);
    G()->td_db()->get_binlog_pmc()->erase(get_proxy_used_database_key(old_proxy_id));
    proxy_last_used_date_.erase(old_proxy_id);
    proxy_last_used_saved_date_.erase(old_proxy_id);
  } else {
#if TD_EMSCRIPTEN || TD_DARWIN_WATCH_OS
    return promise.set_error(Status::Error(400, "The method is unsupported for the platform"));
#endif
  }

  auto proxy_id = [&] {
    for (auto &proxy : proxies_) {
      if (proxy.second == new_proxy) {
        return proxy.first;
      }
    }

    int32 proxy_id = old_proxy_id;
    if (proxy_id < 0) {
      CHECK(max_proxy_id_ >= 2);
      proxy_id = max_proxy_id_++;
      G()->td_db()->get_binlog_pmc()->set("proxy_max_id", to_string(max_proxy_id_));
    }
    bool is_inserted = proxies_.emplace(proxy_id, std::move(new_proxy)).second;
    CHECK(is_inserted);
    G()->td_db()->get_binlog_pmc()->set(get_proxy_database_key(proxy_id),
                                        log_event_store(proxies_[proxy_id]).as_slice().str());
    return proxy_id;
  }();
  if (enable) {
    enable_proxy_impl(proxy_id);
  }
  promise.set_value(get_proxy_object(proxy_id));
}

void ConnectionCreator::enable_proxy(int32 proxy_id, Promise<Unit> promise) {
  if (proxies_.count(proxy_id) == 0) {
    return promise.set_error(Status::Error(400, "Unknown proxy identifier"));
  }

  enable_proxy_impl(proxy_id);
  promise.set_value(Unit());
}

void ConnectionCreator::disable_proxy(Promise<Unit> promise) {
  save_proxy_last_used_date(0);
  disable_proxy_impl();
  promise.set_value(Unit());
}

void ConnectionCreator::remove_proxy(int32 proxy_id, Promise<Unit> promise) {
  if (proxies_.count(proxy_id) == 0) {
    return promise.set_error(Status::Error(400, "Unknown proxy identifier"));
  }

  if (proxy_id == active_proxy_id_) {
    disable_proxy_impl();
  }

  proxies_.erase(proxy_id);

  G()->td_db()->get_binlog_pmc()->erase(get_proxy_database_key(proxy_id));
  G()->td_db()->get_binlog_pmc()->erase(get_proxy_used_database_key(proxy_id));
  promise.set_value(Unit());
}

void ConnectionCreator::get_proxies(Promise<td_api::object_ptr<td_api::proxies>> promise) {
  promise.set_value(td_api::make_object<td_api::proxies>(
      transform(proxies_, [this](const std::pair<int32, Proxy> &proxy) { return get_proxy_object(proxy.first); })));
}

void ConnectionCreator::get_proxy_link(int32 proxy_id, Promise<string> promise) {
  auto it = proxies_.find(proxy_id);
  if (it == proxies_.end()) {
    return promise.set_error(Status::Error(400, "Unknown proxy identifier"));
  }

  promise.set_result(LinkManager::get_proxy_link(it->second, false));
}

ActorId<GetHostByNameActor> ConnectionCreator::get_dns_resolver() {
  if (G()->get_option_boolean("expect_blocking", true)) {
    if (block_get_host_by_name_actor_.empty()) {
      VLOG(connections) << "Init block bypass DNS resolver";
      GetHostByNameActor::Options options;
      options.scheduler_id = G()->get_gc_scheduler_id();
      options.resolver_types = {GetHostByNameActor::ResolverType::Google, GetHostByNameActor::ResolverType::Native};
      options.ok_timeout = 60;
      options.error_timeout = 0;
      block_get_host_by_name_actor_ = create_actor<GetHostByNameActor>("BlockDnsResolverActor", std::move(options));
    }
    return block_get_host_by_name_actor_.get();
  } else {
    if (get_host_by_name_actor_.empty()) {
      VLOG(connections) << "Init DNS resolver";
      GetHostByNameActor::Options options;
      options.scheduler_id = G()->get_gc_scheduler_id();
      options.ok_timeout = 5 * 60 - 1;
      options.error_timeout = 0;
      get_host_by_name_actor_ = create_actor<GetHostByNameActor>("DnsResolverActor", std::move(options));
    }
    return get_host_by_name_actor_.get();
  }
}

void ConnectionCreator::ping_proxy(int32 proxy_id, Promise<double> promise) {
  CHECK(!close_flag_);
  if (proxy_id == 0) {
    auto main_dc_id = G()->net_query_dispatcher().get_main_dc_id();
    bool prefer_ipv6 = G()->get_option_boolean("prefer_ipv6");
    auto infos = dc_options_set_.find_all_connections(main_dc_id, false, false, prefer_ipv6, false);
    if (infos.empty()) {
      return promise.set_error(Status::Error(400, "Can't find valid DC address"));
    }
    const size_t MAX_CONNECTIONS = 10;
    if (infos.size() > MAX_CONNECTIONS) {
      infos.resize(MAX_CONNECTIONS);
    }

    auto token = next_token();
    auto &request = ping_main_dc_requests_[token];
    request.promise = std::move(promise);
    request.left_queries = infos.size();
    request.result = Status::Error(400, "Failed to ping");

    for (auto &info : infos) {
      auto r_transport_type = get_transport_type(Proxy(), info);
      if (r_transport_type.is_error()) {
        LOG(ERROR) << r_transport_type.error();
        on_ping_main_dc_result(token, r_transport_type.move_as_error());
        continue;
      }

      auto ip_address = info.option->get_ip_address();
      auto r_socket_fd = SocketFd::open(ip_address);
      if (r_socket_fd.is_error()) {
        LOG(DEBUG) << "Failed to open socket: " << r_socket_fd.error();
        on_ping_main_dc_result(token, r_socket_fd.move_as_error());
        continue;
      }

      ping_proxy_buffered_socket_fd(std::move(ip_address), BufferedFd<SocketFd>(r_socket_fd.move_as_ok()),
                                    r_transport_type.move_as_ok(), PSTRING() << info.option->get_ip_address(),
                                    PromiseCreator::lambda([actor_id = actor_id(this), token](Result<double> result) {
                                      send_closure(actor_id, &ConnectionCreator::on_ping_main_dc_result, token,
                                                   std::move(result));
                                    }));
    }
    return;
  }

  auto it = proxies_.find(proxy_id);
  if (it == proxies_.end()) {
    return promise.set_error(Status::Error(400, "Unknown proxy identifier"));
  }
  const Proxy &proxy = it->second;
  bool prefer_ipv6 = G()->get_option_boolean("prefer_ipv6");
  send_closure(get_dns_resolver(), &GetHostByNameActor::run, proxy.server().str(), proxy.port(), prefer_ipv6,
               PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise),
                                       proxy_id](Result<IPAddress> result) mutable {
                 if (result.is_error()) {
                   return promise.set_error(Status::Error(400, result.error().public_message()));
                 }
                 send_closure(actor_id, &ConnectionCreator::ping_proxy_resolved, proxy_id, result.move_as_ok(),
                              std::move(promise));
               }));
}

void ConnectionCreator::ping_proxy_resolved(int32 proxy_id, IPAddress ip_address, Promise<double> promise) {
  auto it = proxies_.find(proxy_id);
  if (it == proxies_.end()) {
    return promise.set_error(Status::Error(400, "Unknown proxy identifier"));
  }
  const Proxy &proxy = it->second;
  auto main_dc_id = G()->net_query_dispatcher().get_main_dc_id();
  FindConnectionExtra extra;
  auto r_socket_fd = find_connection(proxy, ip_address, main_dc_id, false, extra);
  if (r_socket_fd.is_error()) {
    return promise.set_error(Status::Error(400, r_socket_fd.error().public_message()));
  }
  auto socket_fd = r_socket_fd.move_as_ok();

  auto connection_promise = PromiseCreator::lambda(
      [actor_id = actor_id(this), ip_address, promise = std::move(promise), transport_type = extra.transport_type,
       debug_str = extra.debug_str](Result<ConnectionData> r_connection_data) mutable {
        if (r_connection_data.is_error()) {
          return promise.set_error(Status::Error(400, r_connection_data.error().public_message()));
        }
        auto connection_data = r_connection_data.move_as_ok();
        send_closure(actor_id, &ConnectionCreator::ping_proxy_buffered_socket_fd, ip_address,
                     std::move(connection_data.buffered_socket_fd), std::move(transport_type), std::move(debug_str),
                     std::move(promise));
      });
  CHECK(proxy.use_proxy());
  auto token = next_token();
  auto ref = prepare_connection(extra.ip_address, std::move(socket_fd), proxy, extra.mtproto_ip_address,
                                extra.transport_type, "Ping", extra.debug_str, nullptr, create_reference(token), false,
                                std::move(connection_promise));
  if (!ref.empty()) {
    children_[token] = {false, std::move(ref)};
  }
}

void ConnectionCreator::ping_proxy_buffered_socket_fd(IPAddress ip_address, BufferedFd<SocketFd> buffered_socket_fd,
                                                      mtproto::TransportType transport_type, string debug_str,
                                                      Promise<double> promise) {
  auto token = next_token();
  auto raw_connection =
      mtproto::RawConnection::create(ip_address, std::move(buffered_socket_fd), std::move(transport_type), nullptr);
  children_[token] = {
      false, create_ping_actor(debug_str, std::move(raw_connection), nullptr,
                               PromiseCreator::lambda([promise = std::move(promise)](
                                                          Result<unique_ptr<mtproto::RawConnection>> result) mutable {
                                 if (result.is_error()) {
                                   return promise.set_error(Status::Error(400, result.error().public_message()));
                                 }
                                 auto ping_time = result.ok()->extra().rtt;
                                 promise.set_value(std::move(ping_time));
                               }),
                               create_reference(token))};
}

void ConnectionCreator::test_proxy(Proxy &&proxy, int32 dc_id, double timeout, Promise<Unit> &&promise) {
  auto start_time = Time::now();

  IPAddress ip_address;
  auto status = ip_address.init_host_port(proxy.server(), proxy.port());
  if (status.is_error()) {
    return promise.set_error(Status::Error(400, status.public_message()));
  }
  auto r_socket_fd = SocketFd::open(ip_address);
  if (r_socket_fd.is_error()) {
    return promise.set_error(Status::Error(400, r_socket_fd.error().public_message()));
  }

  auto dc_options = get_default_dc_options(false);
  IPAddress mtproto_ip_address;
  for (auto &dc_option : dc_options.dc_options) {
    if (dc_option.get_dc_id().get_raw_id() == dc_id) {
      mtproto_ip_address = dc_option.get_ip_address();
      break;
    }
  }
  if (!mtproto_ip_address.is_valid()) {
    return promise.set_error(Status::Error(400, "Invalid datacenter identifier specified"));
  }

  auto request_id = ++test_proxy_request_id_;
  auto request = make_unique<TestProxyRequest>();
  request->proxy_ = std::move(proxy);
  request->dc_id_ = static_cast<int16>(dc_id);
  request->promise_ = std::move(promise);

  auto connection_promise =
      PromiseCreator::lambda([actor_id = actor_id(this), request_id](Result<ConnectionData> r_data) {
        send_closure(actor_id, &ConnectionCreator::on_test_proxy_connection_data, request_id, std::move(r_data));
      });
  request->child_ = prepare_connection(ip_address, r_socket_fd.move_as_ok(), request->proxy_, mtproto_ip_address,
                                       request->get_transport(), "Test", "TestPingDC2", nullptr, {}, false,
                                       std::move(connection_promise));

  test_proxy_requests_.emplace(request_id, std::move(request));

  create_actor<SleepActor>("TestProxyTimeoutActor", timeout + start_time - Time::now(),
                           PromiseCreator::lambda([actor_id = actor_id(this), request_id](Unit) {
                             send_closure(actor_id, &ConnectionCreator::on_test_proxy_timeout, request_id);
                           }))
      .release();
}

void ConnectionCreator::on_test_proxy_connection_data(uint64 request_id, Result<ConnectionData> r_data) {
  auto it = test_proxy_requests_.find(request_id);
  if (it == test_proxy_requests_.end()) {
    return;
  }
  auto *request = it->second.get();
  if (r_data.is_error()) {
    auto promise = std::move(request->promise_);
    test_proxy_requests_.erase(it);
    return promise.set_error(r_data.move_as_error());
  }

  class HandshakeContext final : public mtproto::AuthKeyHandshakeContext {
   public:
    mtproto::DhCallback *get_dh_callback() final {
      return nullptr;
    }
    mtproto::PublicRsaKeyInterface *get_public_rsa_key_interface() final {
      return public_rsa_key_.get();
    }

   private:
    std::shared_ptr<mtproto::PublicRsaKeyInterface> public_rsa_key_ = PublicRsaKeySharedMain::create(false);
  };
  auto handshake = make_unique<mtproto::AuthKeyHandshake>(request->dc_id_, 3600);
  auto data = r_data.move_as_ok();
  auto raw_connection = mtproto::RawConnection::create(data.ip_address, std::move(data.buffered_socket_fd),
                                                       request->get_transport(), nullptr);
  request->child_ = create_actor<mtproto::HandshakeActor>(
      "HandshakeActor", std::move(handshake), std::move(raw_connection), make_unique<HandshakeContext>(), 10.0,
      PromiseCreator::lambda(
          [actor_id = actor_id(this), request_id](Result<unique_ptr<mtproto::RawConnection>> raw_connection) {
            send_closure(actor_id, &ConnectionCreator::on_test_proxy_handshake_connection, request_id,
                         std::move(raw_connection));
          }),
      PromiseCreator::lambda(
          [actor_id = actor_id(this), request_id](Result<unique_ptr<mtproto::AuthKeyHandshake>> handshake) {
            send_closure(actor_id, &ConnectionCreator::on_test_proxy_handshake, request_id, std::move(handshake));
          }));
}

void ConnectionCreator::on_test_proxy_handshake_connection(
    uint64 request_id, Result<unique_ptr<mtproto::RawConnection>> r_raw_connection) {
  if (r_raw_connection.is_error()) {
    auto it = test_proxy_requests_.find(request_id);
    if (it == test_proxy_requests_.end()) {
      return;
    }
    auto promise = std::move(it->second->promise_);
    test_proxy_requests_.erase(it);
    return promise.set_error(Status::Error(400, r_raw_connection.move_as_error().public_message()));
  }
}

void ConnectionCreator::on_test_proxy_handshake(uint64 request_id,
                                                Result<unique_ptr<mtproto::AuthKeyHandshake>> r_handshake) {
  auto it = test_proxy_requests_.find(request_id);
  if (it == test_proxy_requests_.end()) {
    return;
  }
  auto promise = std::move(it->second->promise_);
  test_proxy_requests_.erase(it);

  if (r_handshake.is_error()) {
    return promise.set_error(Status::Error(400, r_handshake.move_as_error().public_message()));
  }
  auto handshake = r_handshake.move_as_ok();
  if (!handshake->is_ready_for_finish()) {
    return promise.set_error(Status::Error(400, "Handshake is not ready"));
  }
  promise.set_value(Unit());
}

void ConnectionCreator::on_test_proxy_timeout(uint64 request_id) {
  auto it = test_proxy_requests_.find(request_id);
  if (it == test_proxy_requests_.end()) {
    return;
  }
  auto promise = std::move(it->second->promise_);
  test_proxy_requests_.erase(it);

  promise.set_error(Status::Error(400, "Timeout expired"));
}

void ConnectionCreator::set_active_proxy_id(int32 proxy_id, bool from_binlog) {
  active_proxy_id_ = proxy_id;
  if (proxy_id == 0) {
    G()->set_option_empty("enabled_proxy_id");
  } else {
    G()->set_option_integer("enabled_proxy_id", proxy_id);
  }
  if (!from_binlog) {
    if (proxy_id == 0) {
      G()->td_db()->get_binlog_pmc()->erase("proxy_active_id");
      send_closure(G()->config_manager(), &ConfigManager::request_config, false);
    } else {
      G()->td_db()->get_binlog_pmc()->set("proxy_active_id", to_string(proxy_id));
    }
  }
}

void ConnectionCreator::enable_proxy_impl(int32 proxy_id) {
  CHECK(proxies_.count(proxy_id) == 1);
  if (proxy_id == active_proxy_id_) {
    return;
  }

  if ((active_proxy_id_ != 0 && proxies_[active_proxy_id_].type() == Proxy::Type::Mtproto) ||
      proxies_[proxy_id].type() == Proxy::Type::Mtproto) {
    update_mtproto_header(proxies_[proxy_id]);
  }
  save_proxy_last_used_date(0);

  set_active_proxy_id(proxy_id);

  on_proxy_changed(false);
}

void ConnectionCreator::disable_proxy_impl() {
  if (active_proxy_id_ == 0) {
    send_closure(G()->promo_data_manager(), &PromoDataManager::remove_sponsored_dialog);
    send_closure(G()->promo_data_manager(), &PromoDataManager::reload_promo_data);
    return;
  }
  CHECK(proxies_.count(active_proxy_id_) == 1);

  if (proxies_[active_proxy_id_].type() == Proxy::Type::Mtproto) {
    update_mtproto_header(Proxy());
  }

  set_active_proxy_id(0);

  on_proxy_changed(false);
}

void ConnectionCreator::on_proxy_changed(bool from_db) {
  send_closure(G()->state_manager(), &StateManager::on_proxy,
               active_proxy_id_ != 0 && proxies_[active_proxy_id_].type() != Proxy::Type::Mtproto &&
                   proxies_[active_proxy_id_].type() != Proxy::Type::HttpCaching);

  if (!from_db) {
    for (auto &child : children_) {
      if (child.second.first) {
        child.second.second.reset();
      }
    }
  }

  VLOG(connections) << "Drop proxy IP address " << proxy_ip_address_;
  resolve_proxy_query_token_ = 0;
  resolve_proxy_timestamp_ = Timestamp();
  proxy_ip_address_ = IPAddress();

  if (active_proxy_id_ == 0 || !from_db) {
    send_closure(G()->promo_data_manager(), &PromoDataManager::remove_sponsored_dialog);
  }
  send_closure(G()->promo_data_manager(), &PromoDataManager::reload_promo_data);

  loop();
}

string ConnectionCreator::get_proxy_database_key(int32 proxy_id) {
  CHECK(proxy_id > 0);
  if (proxy_id == 1) {
    return "proxy";
  }
  return PSTRING() << "proxy" << proxy_id;
}

string ConnectionCreator::get_proxy_used_database_key(int32 proxy_id) {
  CHECK(proxy_id > 0);
  return PSTRING() << "proxy_used" << proxy_id;
}

void ConnectionCreator::save_proxy_last_used_date(int32 delay) {
  if (active_proxy_id_ == 0) {
    return;
  }

  CHECK(delay >= 0);
  int32 date = proxy_last_used_date_[active_proxy_id_];
  int32 &saved_date = proxy_last_used_saved_date_[active_proxy_id_];
  if (date <= saved_date + delay) {
    return;
  }
  LOG(DEBUG) << "Save proxy last used date " << date;

  saved_date = date;
  G()->td_db()->get_binlog_pmc()->set(get_proxy_used_database_key(active_proxy_id_), to_string(date));
}

td_api::object_ptr<td_api::proxy> ConnectionCreator::get_proxy_object(int32 proxy_id) const {
  auto it = proxies_.find(proxy_id);
  CHECK(it != proxies_.end());
  const Proxy &proxy = it->second;
  td_api::object_ptr<td_api::ProxyType> type;
  switch (proxy.type()) {
    case Proxy::Type::Socks5:
      type = make_tl_object<td_api::proxyTypeSocks5>(proxy.user().str(), proxy.password().str());
      break;
    case Proxy::Type::HttpTcp:
      type = make_tl_object<td_api::proxyTypeHttp>(proxy.user().str(), proxy.password().str(), false);
      break;
    case Proxy::Type::HttpCaching:
      type = make_tl_object<td_api::proxyTypeHttp>(proxy.user().str(), proxy.password().str(), true);
      break;
    case Proxy::Type::Mtproto:
      type = make_tl_object<td_api::proxyTypeMtproto>(proxy.secret().get_encoded_secret());
      break;
    default:
      UNREACHABLE();
  }
  auto last_used_date_it = proxy_last_used_date_.find(proxy_id);
  auto last_used_date = last_used_date_it == proxy_last_used_date_.end() ? 0 : last_used_date_it->second;
  return make_tl_object<td_api::proxy>(proxy_id, proxy.server().str(), proxy.port(), last_used_date,
                                       proxy_id == active_proxy_id_, std::move(type));
}

void ConnectionCreator::on_network(bool network_flag, uint32 network_generation) {
  VLOG(connections) << "Receive network flag " << network_flag << " with generation " << network_generation;
  network_flag_ = network_flag;
  auto old_generation = network_generation_;
  network_generation_ = network_generation;
  if (network_flag_) {
    VLOG(connections) << "Set proxy query token to 0: " << old_generation << " " << network_generation_;
    resolve_proxy_query_token_ = 0;
    resolve_proxy_timestamp_ = Timestamp();

    for (auto &client : clients_) {
      client.second.backoff.clear();
      client.second.sanity_flood_control.clear_events();
      client.second.flood_control.clear_events();
      client.second.flood_control_online.clear_events();
      client_loop(client.second);
    }

    if (old_generation != network_generation_) {
      loop();
    }
  }
}

void ConnectionCreator::on_online(bool online_flag) {
  VLOG(connections) << "Receive online flag " << online_flag;
  bool need_drop_flood_control = online_flag || !online_flag_;
  online_flag_ = online_flag;
  if (need_drop_flood_control) {
    for (auto &client : clients_) {
      client.second.backoff.clear();
      client.second.sanity_flood_control.clear_events();
      client.second.flood_control_online.clear_events();
      client_loop(client.second);
    }
  }
}
void ConnectionCreator::on_logging_out(bool is_logging_out) {
  if (is_logging_out_ == is_logging_out) {
    return;
  }

  VLOG(connections) << "Receive logging out flag " << is_logging_out;
  is_logging_out_ = is_logging_out;
  for (auto &client : clients_) {
    client.second.backoff.clear();
    client.second.sanity_flood_control.clear_events();
    client.second.flood_control_online.clear_events();
    client_loop(client.second);
  }
}

void ConnectionCreator::on_pong(uint32 hash) {
  G()->save_server_time();
  if (active_proxy_id_ != 0) {
    auto now = G()->unix_time();
    int32 &last_used = proxy_last_used_date_[active_proxy_id_];
    if (now > last_used) {
      last_used = now;
      save_proxy_last_used_date(MAX_PROXY_LAST_USED_SAVE_DELAY);
    }
  }
}

void ConnectionCreator::on_mtproto_error(uint32 hash) {
  auto &client = clients_[hash];
  client.hash = hash;
  client.mtproto_error_flood_control.add_event(Time::now_cached());
}

void ConnectionCreator::request_raw_connection(DcId dc_id, bool allow_media_only, bool is_media,
                                               Promise<unique_ptr<mtproto::RawConnection>> promise, uint32 hash,
                                               unique_ptr<mtproto::AuthData> auth_data) {
  auto &client = clients_[hash];
  if (!client.inited) {
    client.inited = true;
    client.hash = hash;
    client.dc_id = dc_id;
    client.allow_media_only = allow_media_only;
    client.is_media = is_media;
  } else {
    CHECK(client.hash == hash);
    CHECK(client.dc_id == dc_id);
    CHECK(client.allow_media_only == allow_media_only);
    CHECK(client.is_media == is_media);
  }
  client.auth_data = std::move(auth_data);
  client.auth_data_generation++;
  VLOG(connections) << "Request connection for " << tag("client", format::as_hex(client.hash)) << " to " << dc_id << " "
                    << tag("allow_media_only", allow_media_only);
  client.queries.push_back(std::move(promise));

  client_loop(client);
}

void ConnectionCreator::request_raw_connection_by_ip(IPAddress ip_address, mtproto::TransportType transport_type,
                                                     Promise<unique_ptr<mtproto::RawConnection>> promise) {
  TRY_RESULT_PROMISE(promise, socket_fd, SocketFd::open(ip_address));

  auto connection_promise = PromiseCreator::lambda([actor_id = actor_id(this), promise = std::move(promise),
                                                    transport_type, network_generation = network_generation_,
                                                    ip_address](Result<ConnectionData> r_connection_data) mutable {
    if (r_connection_data.is_error()) {
      return promise.set_error(Status::Error(400, r_connection_data.error().public_message()));
    }
    auto connection_data = r_connection_data.move_as_ok();
    auto raw_connection = mtproto::RawConnection::create(ip_address, std::move(connection_data.buffered_socket_fd),
                                                         transport_type, nullptr);
    raw_connection->extra().extra = network_generation;
    promise.set_value(std::move(raw_connection));
  });

  auto token = next_token();
  auto ref = prepare_connection(ip_address, std::move(socket_fd), Proxy(), IPAddress(), transport_type, "Raw",
                                PSTRING() << "to IP address " << ip_address, nullptr, create_reference(token), false,
                                std::move(connection_promise));
  if (!ref.empty()) {
    children_[token] = {false, std::move(ref)};
  }
}

Result<mtproto::TransportType> ConnectionCreator::get_transport_type(const Proxy &proxy,
                                                                     const DcOptionsSet::ConnectionInfo &info) {
  int32 int_dc_id = info.option->get_dc_id().get_raw_id();
  if (G()->is_test_dc()) {
    int_dc_id += 10000;
  }
  auto raw_dc_id = narrow_cast<int16>(info.option->is_media_only() ? -int_dc_id : int_dc_id);

  if (proxy.use_mtproto_proxy()) {
    return mtproto::TransportType{mtproto::TransportType::ObfuscatedTcp, raw_dc_id, proxy.secret()};
  }
  if (proxy.use_http_caching_proxy()) {
    CHECK(info.option != nullptr);
    string proxy_authorization;
    if (!proxy.user().empty() || !proxy.password().empty()) {
      proxy_authorization = "|basic " + base64_encode(PSLICE() << proxy.user() << ':' << proxy.password());
    }
    return mtproto::TransportType{mtproto::TransportType::Http, 0,
                                  mtproto::ProxySecret::from_raw(
                                      PSTRING() << info.option->get_ip_address().get_ip_host() << proxy_authorization)};
  }

  if (info.use_http) {
    return mtproto::TransportType{mtproto::TransportType::Http, 0, mtproto::ProxySecret()};
  } else {
    return mtproto::TransportType{mtproto::TransportType::ObfuscatedTcp, raw_dc_id, info.option->get_secret()};
  }
}

Result<SocketFd> ConnectionCreator::find_connection(const Proxy &proxy, const IPAddress &proxy_ip_address, DcId dc_id,
                                                    bool allow_media_only, FindConnectionExtra &extra) {
  extra.debug_str = PSTRING() << "Failed to find valid IP address for " << dc_id;
  bool prefer_ipv6 = G()->get_option_boolean("prefer_ipv6") || (proxy.use_proxy() && proxy_ip_address.is_ipv6());
  bool only_http = proxy.use_http_caching_proxy();
#if TD_DARWIN_WATCH_OS
  only_http = true;
#endif
  TRY_RESULT(info, dc_options_set_.find_connection(
                       dc_id, allow_media_only, proxy.use_proxy() && proxy.use_socks5_proxy(), prefer_ipv6, only_http));
  extra.stat = info.stat;
  TRY_RESULT_ASSIGN(extra.transport_type, get_transport_type(proxy, info));

  extra.debug_str = PSTRING() << " to " << (info.option->is_media_only() ? "MEDIA " : "") << dc_id
                              << (info.use_http ? " over HTTP" : "");

  if (proxy.use_mtproto_proxy()) {
    extra.debug_str = PSTRING() << "MTProto " << proxy_ip_address << extra.debug_str;

    VLOG(connections) << "Create: " << extra.debug_str;
    return SocketFd::open(proxy_ip_address);
  }

  extra.check_mode |= info.should_check;

  if (proxy.use_proxy()) {
    extra.mtproto_ip_address = info.option->get_ip_address();
    extra.ip_address = proxy_ip_address;
    extra.debug_str = PSTRING() << (proxy.use_socks5_proxy() ? "Socks5" : (only_http ? "HTTP_ONLY" : "HTTP_TCP")) << ' '
                                << proxy_ip_address << " --> " << extra.mtproto_ip_address << extra.debug_str;
  } else {
    extra.ip_address = info.option->get_ip_address();
    extra.debug_str = PSTRING() << info.option->get_ip_address() << extra.debug_str;
  }
  VLOG(connections) << "Create: " << extra.debug_str;
  return SocketFd::open(extra.ip_address);
}

ActorOwn<> ConnectionCreator::prepare_connection(IPAddress ip_address, SocketFd socket_fd, const Proxy &proxy,
                                                 const IPAddress &mtproto_ip_address,
                                                 const mtproto::TransportType &transport_type, Slice actor_name_prefix,
                                                 Slice debug_str,
                                                 unique_ptr<mtproto::RawConnection::StatsCallback> stats_callback,
                                                 ActorShared<> parent, bool use_connection_token,
                                                 Promise<ConnectionData> promise) {
  if (proxy.use_socks5_proxy() || proxy.use_http_tcp_proxy() || transport_type.secret.emulate_tls()) {
    VLOG(connections) << "Create new transparent proxy connection " << debug_str;
    class Callback final : public TransparentProxy::Callback {
     public:
      Callback(Promise<ConnectionData> promise, IPAddress ip_address,
               unique_ptr<mtproto::RawConnection::StatsCallback> stats_callback, bool use_connection_token,
               bool was_connected)
          : promise_(std::move(promise))
          , ip_address_(std::move(ip_address))
          , stats_callback_(std::move(stats_callback))
          , use_connection_token_(use_connection_token)
          , was_connected_(was_connected) {
      }
      void set_result(Result<BufferedFd<SocketFd>> r_buffered_socket_fd) final {
        if (r_buffered_socket_fd.is_error()) {
          if (use_connection_token_) {
            connection_token_ = mtproto::ConnectionManager::ConnectionToken();
          }
          if (was_connected_ && stats_callback_) {
            stats_callback_->on_error();
          }
          promise_.set_error(Status::Error(400, r_buffered_socket_fd.error().public_message()));
        } else {
          ConnectionData data;
          data.ip_address = ip_address_;
          data.buffered_socket_fd = r_buffered_socket_fd.move_as_ok();
          data.connection_token = std::move(connection_token_);
          data.stats_callback = std::move(stats_callback_);
          promise_.set_value(std::move(data));
        }
      }
      void on_connected() final {
        if (use_connection_token_) {
          connection_token_ = mtproto::ConnectionManager::connection_proxy(
              static_cast<ActorId<mtproto::ConnectionManager>>(G()->state_manager()));
        }
        was_connected_ = true;
      }

     private:
      Promise<ConnectionData> promise_;
      mtproto::ConnectionManager::ConnectionToken connection_token_;
      IPAddress ip_address_;
      unique_ptr<mtproto::RawConnection::StatsCallback> stats_callback_;
      bool use_connection_token_{false};
      bool was_connected_{false};
    };
    VLOG(connections) << "Start "
                      << (proxy.use_socks5_proxy() ? "Socks5" : (proxy.use_http_tcp_proxy() ? "HTTP" : "TLS")) << ": "
                      << debug_str;
    auto callback = make_unique<Callback>(std::move(promise), ip_address, std::move(stats_callback),
                                          use_connection_token, !proxy.use_socks5_proxy());
    if (proxy.use_socks5_proxy()) {
      return ActorOwn<>(create_actor<Socks5>(PSLICE() << actor_name_prefix << "Socks5", std::move(socket_fd),
                                             mtproto_ip_address, proxy.user().str(), proxy.password().str(),
                                             std::move(callback), std::move(parent)));
    } else if (proxy.use_http_tcp_proxy()) {
      return ActorOwn<>(create_actor<HttpProxy>(PSLICE() << actor_name_prefix << "HttpProxy", std::move(socket_fd),
                                                mtproto_ip_address, proxy.user().str(), proxy.password().str(),
                                                std::move(callback), std::move(parent)));
    } else if (transport_type.secret.emulate_tls()) {
      return ActorOwn<>(create_actor<mtproto::TlsInit>(
          PSLICE() << actor_name_prefix << "TlsInit", std::move(socket_fd), transport_type.secret.get_domain(),
          transport_type.secret.get_proxy_secret().str(), std::move(callback), std::move(parent),
          G()->get_dns_time_difference()));
    } else {
      UNREACHABLE();
    }
  } else {
    VLOG(connections) << "Create new direct connection " << debug_str;

    ConnectionData data;
    data.ip_address = ip_address;
    data.buffered_socket_fd = BufferedFd<SocketFd>(std::move(socket_fd));
    data.stats_callback = std::move(stats_callback);
    promise.set_result(std::move(data));
    return {};
  }
}

void ConnectionCreator::client_loop(ClientInfo &client) {
  CHECK(client.hash != 0);
  if (!network_flag_) {
    VLOG(connections) << "Exit client_loop, because there is no network";
    return;
  }
  if (close_flag_) {
    VLOG(connections) << "Exit client_loop, because of closing";
    return;
  }

  Proxy proxy = active_proxy_id_ == 0 ? Proxy() : proxies_[active_proxy_id_];

  if (proxy.use_proxy() && !proxy_ip_address_.is_valid()) {
    VLOG(connections) << "Exit client_loop, because there is no valid IP address for proxy: " << proxy_ip_address_;
    return;
  }

  VLOG(connections) << "In client_loop: " << tag("client", format::as_hex(client.hash));

  // Remove expired ready connections
  td::remove_if(client.ready_connections,
                [&, expires_at = Time::now_cached() - ClientInfo::READY_CONNECTIONS_TIMEOUT](auto &v) {
                  bool drop = v.second < expires_at;
                  VLOG_IF(connections, drop) << "Drop expired " << tag("connection", v.first.get());
                  return drop;
                });

  // Send ready connections into promises
  {
    auto begin = client.queries.begin();
    auto it = begin;
    while (it != client.queries.end() && !client.ready_connections.empty()) {
      if (!it->is_canceled()) {
        VLOG(connections) << "Send to promise " << tag("connection", client.ready_connections.back().first.get());
        it->set_value(std::move(client.ready_connections.back().first));
        client.ready_connections.pop_back();
      }
      ++it;
    }
    client.queries.erase(begin, it);
  }

  // Main loop. Create new connections till needed
  bool check_mode = client.checking_connections != 0 && !proxy.use_proxy();
  while (true) {
    // Check if we need new connections
    if (client.queries.empty()) {
      if (!client.ready_connections.empty()) {
        client_set_timeout_at(client, Time::now() + ClientInfo::READY_CONNECTIONS_TIMEOUT);
      }
      return;
    }
    if (check_mode) {
      if (client.checking_connections >= 3) {
        return;
      }
    } else {
      if (client.pending_connections >= client.queries.size()) {
        return;
      }
    }

    bool act_as_if_online = online_flag_ || is_logging_out_;
    // Check flood
    auto &flood_control = act_as_if_online ? client.flood_control_online : client.flood_control;
    auto wakeup_at = max(flood_control.get_wakeup_at(), client.mtproto_error_flood_control.get_wakeup_at());
    wakeup_at = max(client.sanity_flood_control.get_wakeup_at(), wakeup_at);

    if (!act_as_if_online) {
      wakeup_at = max(wakeup_at, static_cast<double>(client.backoff.get_wakeup_at()));
    }
    if (wakeup_at > Time::now()) {
      return client_set_timeout_at(client, wakeup_at);
    }
    client.sanity_flood_control.add_event(Time::now());
    if (!act_as_if_online) {
      client.backoff.add_event(static_cast<int32>(Time::now()));
    }

    // Create new RawConnection
    // sync part
    FindConnectionExtra extra;
    auto r_socket_fd = find_connection(proxy, proxy_ip_address_, client.dc_id, client.allow_media_only, extra);
    check_mode |= extra.check_mode;
    if (r_socket_fd.is_error()) {
      LOG(WARNING) << extra.debug_str << ": " << r_socket_fd.error();
      if (extra.stat) {
        extra.stat->on_error();  // TODO: different kind of error
      }
      return client_set_timeout_at(client, Time::now() + 0.1);
    }

    // Events with failed socket creation are ignored
    flood_control.add_event(Time::now());

    auto socket_fd = r_socket_fd.move_as_ok();
#if !TD_DARWIN_WATCH_OS
    IPAddress debug_ip;
    auto debug_ip_status = debug_ip.init_socket_address(socket_fd);
    if (debug_ip_status.is_ok()) {
      extra.debug_str = PSTRING() << extra.debug_str << " from " << debug_ip;
    } else {
      LOG(ERROR) << debug_ip_status;
    }
#endif

    client.pending_connections++;
    if (check_mode) {
      if (extra.stat) {
        extra.stat->on_check();
      }
      client.checking_connections++;
    }

    auto promise = PromiseCreator::lambda(
        [actor_id = actor_id(this), check_mode, transport_type = extra.transport_type, hash = client.hash,
         debug_str = extra.debug_str,
         network_generation = network_generation_](Result<ConnectionData> r_connection_data) mutable {
          send_closure(actor_id, &ConnectionCreator::client_create_raw_connection, std::move(r_connection_data),
                       check_mode, std::move(transport_type), hash, std::move(debug_str), network_generation);
        });

    auto stats_callback =
        td::make_unique<detail::StatsCallback>(client.is_media ? media_net_stats_callback_ : common_net_stats_callback_,
                                               actor_id(this), client.hash, extra.stat);
    auto token = next_token();
    auto ref = prepare_connection(extra.ip_address, std::move(socket_fd), proxy, extra.mtproto_ip_address,
                                  extra.transport_type, Slice(), extra.debug_str, std::move(stats_callback),
                                  create_reference(token), true, std::move(promise));
    if (!ref.empty()) {
      children_[token] = {true, std::move(ref)};
    }
  }
}

void ConnectionCreator::client_create_raw_connection(Result<ConnectionData> r_connection_data, bool check_mode,
                                                     mtproto::TransportType transport_type, uint32 hash,
                                                     string debug_str, uint32 network_generation) {
  unique_ptr<mtproto::AuthData> auth_data;
  uint64 auth_data_generation{0};
  uint64 session_id{0};
  if (check_mode) {
    auto it = clients_.find(hash);
    CHECK(it != clients_.end());
    const auto &auth_data_ptr = it->second.auth_data;
    if (auth_data_ptr && auth_data_ptr->use_pfs() && auth_data_ptr->has_auth_key(Time::now_cached())) {
      auth_data = make_unique<mtproto::AuthData>(*auth_data_ptr);
      auth_data_generation = it->second.auth_data_generation;
      session_id = it->second.extract_session_id();
      auth_data->set_session_id(session_id);
    }
  }
  auto promise = PromiseCreator::lambda([actor_id = actor_id(this), hash, check_mode, auth_data_generation, session_id,
                                         debug_str](Result<unique_ptr<mtproto::RawConnection>> result) mutable {
    if (result.is_ok()) {
      VLOG(connections) << "Ready connection (" << (check_mode ? "" : "un") << "checked) " << result.ok().get() << ' '
                        << tag("rtt", format::as_time(result.ok()->extra().rtt)) << ' ' << debug_str;
    } else {
      VLOG(connections) << "Failed connection (" << (check_mode ? "" : "un") << "checked) " << result.error() << ' '
                        << debug_str;
    }
    send_closure(actor_id, &ConnectionCreator::client_add_connection, hash, std::move(result), check_mode,
                 auth_data_generation, session_id);
  });

  if (r_connection_data.is_error()) {
    return promise.set_error(r_connection_data.move_as_error());
  }

  auto connection_data = r_connection_data.move_as_ok();
  auto raw_connection =
      mtproto::RawConnection::create(connection_data.ip_address, std::move(connection_data.buffered_socket_fd),
                                     std::move(transport_type), std::move(connection_data.stats_callback));
  raw_connection->set_connection_token(std::move(connection_data.connection_token));

  raw_connection->extra().extra = network_generation;
  raw_connection->extra().debug_str = debug_str;

  if (check_mode) {
    VLOG(connections) << "Start check: " << debug_str << " " << (auth_data ? "with" : "without") << " auth data";
    auto token = next_token();
    children_[token] = {true, create_ping_actor(debug_str, std::move(raw_connection), std::move(auth_data),
                                                std::move(promise), create_reference(token))};
  } else {
    promise.set_value(std::move(raw_connection));
  }
}

void ConnectionCreator::client_set_timeout_at(ClientInfo &client, double wakeup_at) {
  if (!client.slot.has_event()) {
    client.slot.set_event(self_closure(this, &ConnectionCreator::client_wakeup, client.hash));
  }
  client.slot.set_timeout_at(wakeup_at);
  VLOG(connections) << tag("client", format::as_hex(client.hash)) << " set timeout in "
                    << wakeup_at - Time::now_cached();
}

void ConnectionCreator::client_add_connection(uint32 hash, Result<unique_ptr<mtproto::RawConnection>> r_raw_connection,
                                              bool check_flag, uint64 auth_data_generation, uint64 session_id) {
  auto &client = clients_[hash];
  client.add_session_id(session_id);
  CHECK(client.pending_connections > 0);
  client.pending_connections--;
  if (check_flag) {
    CHECK(client.checking_connections > 0);
    client.checking_connections--;
  }
  if (r_raw_connection.is_ok()) {
    VLOG(connections) << "Add ready connection " << r_raw_connection.ok().get() << " for "
                      << tag("client", format::as_hex(hash));
    client.backoff.clear();
    client.ready_connections.emplace_back(r_raw_connection.move_as_ok(), Time::now_cached());
  } else {
    if (r_raw_connection.error().code() == -404 && client.auth_data &&
        client.auth_data_generation == auth_data_generation) {
      VLOG(connections) << "Drop auth data from " << tag("client", format::as_hex(hash));
      client.auth_data = nullptr;
      client.auth_data_generation++;
    }
  }
  client_loop(client);
}

void ConnectionCreator::client_wakeup(uint32 hash) {
  VLOG(connections) << tag("hash", format::as_hex(hash)) << " wakeup";
  G()->save_server_time();
  client_loop(clients_[hash]);
}

void ConnectionCreator::on_dc_options(DcOptions new_dc_options) {
  VLOG(connections) << "SAVE " << new_dc_options;
  G()->td_db()->get_binlog_pmc()->set("dc_options", serialize(new_dc_options));
  dc_options_set_.reset();
  add_dc_options(std::move(new_dc_options));
}

void ConnectionCreator::add_dc_options(DcOptions &&new_dc_options) {
  dc_options_set_.add_dc_options(get_default_dc_options(G()->is_test_dc()));
#if !TD_EMSCRIPTEN  // FIXME
  dc_options_set_.add_dc_options(std::move(new_dc_options));
#endif
}

void ConnectionCreator::on_dc_update(DcId dc_id, string ip_port, Promise<> promise) {
  if (!dc_id.is_exact()) {
    return promise.set_error(Status::Error("Invalid dc_id"));
  }

  IPAddress ip_address;
  TRY_STATUS_PROMISE(promise, ip_address.init_host_port(ip_port));
  DcOptions options;
  options.dc_options.emplace_back(dc_id, ip_address);
  send_closure(G()->config_manager(), &ConfigManager::on_dc_options_update, std::move(options));
  promise.set_value(Unit());
}

void ConnectionCreator::update_mtproto_header(const Proxy &proxy) {
  if (G()->have_mtproto_header()) {
    G()->mtproto_header().set_proxy(proxy);
  }
  if (G()->have_net_query_dispatcher()) {
    G()->net_query_dispatcher().update_mtproto_header();
  }
}

void ConnectionCreator::start_up() {
  class StateCallback final : public StateManager::Callback {
   public:
    explicit StateCallback(ActorId<ConnectionCreator> connection_creator)
        : connection_creator_(std::move(connection_creator)) {
    }
    bool on_network(NetType network_type, uint32 generation) final {
      send_closure(connection_creator_, &ConnectionCreator::on_network, network_type != NetType::None, generation);
      return connection_creator_.is_alive();
    }
    bool on_online(bool online_flag) final {
      send_closure(connection_creator_, &ConnectionCreator::on_online, online_flag);
      return connection_creator_.is_alive();
    }
    bool on_logging_out(bool is_logging_out) final {
      send_closure(connection_creator_, &ConnectionCreator::on_logging_out, is_logging_out);
      return connection_creator_.is_alive();
    }

   private:
    ActorId<ConnectionCreator> connection_creator_;
  };
  send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<StateCallback>(actor_id(this)));

  auto serialized_dc_options = G()->td_db()->get_binlog_pmc()->get("dc_options");
  DcOptions dc_options;
  auto status = unserialize(dc_options, serialized_dc_options);
  if (status.is_error()) {
    on_dc_options(DcOptions());
  } else {
    add_dc_options(std::move(dc_options));
  }

  if (G()->td_db()->get_binlog_pmc()->get("proxy_max_id") != "2" ||
      !G()->td_db()->get_binlog_pmc()->get(get_proxy_database_key(1)).empty()) {
    // don't need to init proxies if they have never been added
    init_proxies();
  } else {
    max_proxy_id_ = 2;
  }

  ref_cnt_guard_ = create_reference(-1);

  is_inited_ = true;
  loop();
}

void ConnectionCreator::init_proxies() {
  auto proxy_info = G()->td_db()->get_binlog_pmc()->prefix_get("proxy");
  auto it = proxy_info.find("_max_id");
  if (it != proxy_info.end()) {
    max_proxy_id_ = to_integer<int32>(it->second);
    proxy_info.erase(it);
  }
  it = proxy_info.find("_active_id");
  if (it != proxy_info.end()) {
    set_active_proxy_id(to_integer<int32>(it->second), true);
    proxy_info.erase(it);
  }

  for (auto &info : proxy_info) {
    if (begins_with(info.first, "_used")) {
      auto proxy_id = to_integer_safe<int32>(Slice(info.first).substr(5)).move_as_ok();
      auto last_used = to_integer_safe<int32>(info.second).move_as_ok();
      CHECK(proxy_id > 0);
      proxy_last_used_date_[proxy_id] = last_used;
      proxy_last_used_saved_date_[proxy_id] = last_used;
    } else {
      LOG_CHECK(!ends_with(info.first, "_max_id")) << info.first;
      auto proxy_id = info.first.empty() ? static_cast<int32>(1) : to_integer_safe<int32>(info.first).move_as_ok();
      CHECK(proxy_id > 0);
      CHECK(proxies_.count(proxy_id) == 0);
      log_event_parse(proxies_[proxy_id], info.second).ensure();
      if (proxies_[proxy_id].type() == Proxy::Type::None) {
        LOG_IF(ERROR, proxy_id != 1) << "Have empty proxy " << proxy_id;
        G()->td_db()->get_binlog_pmc()->erase(get_proxy_database_key(proxy_id));
        G()->td_db()->get_binlog_pmc()->erase(get_proxy_used_database_key(proxy_id));
        proxies_.erase(proxy_id);
        if (active_proxy_id_ == proxy_id) {
          set_active_proxy_id(0);
        }
      }
    }
  }

  if (max_proxy_id_ == 0) {
    // legacy one-proxy version
    max_proxy_id_ = 2;
    if (!proxies_.empty()) {
      CHECK(proxies_.begin()->first == 1);
      set_active_proxy_id(1);
    }
    G()->td_db()->get_binlog_pmc()->set("proxy_max_id", "2");
  } else if (max_proxy_id_ < 2) {
    LOG(ERROR) << "Found wrong max_proxy_id = " << max_proxy_id_;
    max_proxy_id_ = 2;
  }

  if (active_proxy_id_ != 0) {
    if (proxies_[active_proxy_id_].type() == Proxy::Type::Mtproto) {
      update_mtproto_header(proxies_[active_proxy_id_]);
    }

    on_proxy_changed(true);
  }
}

void ConnectionCreator::hangup_shared() {
  ref_cnt_--;
  children_.erase(get_link_token());
  if (ref_cnt_ == 0) {
    stop();
  }
}

ActorShared<ConnectionCreator> ConnectionCreator::create_reference(int64 token) {
  CHECK(token != 0);
  ref_cnt_++;
  return actor_shared(this, token);
}

void ConnectionCreator::hangup() {
  close_flag_ = true;
  save_proxy_last_used_date(0);
  ref_cnt_guard_.reset();
  for (auto &child : children_) {
    child.second.second.reset();
  }
}

DcOptions ConnectionCreator::get_default_dc_options(bool is_test) {
  DcOptions res;
  enum class HostType : int32 { IPv4, IPv6, Url };
  auto add_ip_ports = [&res](int32 dc_id, vector<string> ip_address_strings, const vector<int> &ports,
                             HostType type = HostType::IPv4) {
    IPAddress ip_address;
    Random::shuffle(ip_address_strings);
    for (auto port : ports) {
      for (auto &ip_address_string : ip_address_strings) {
        switch (type) {
          case HostType::IPv4:
            ip_address.init_ipv4_port(ip_address_string, port).ensure();
            break;
          case HostType::IPv6:
            ip_address.init_ipv6_port(ip_address_string, port).ensure();
            break;
          case HostType::Url:
            ip_address.init_host_port(ip_address_string, port).ensure();
            break;
        }
        res.dc_options.emplace_back(DcId::internal(dc_id), ip_address);
      }
    }
  };
  vector<int> ports = {443, 80, 5222};
#if TD_EMSCRIPTEN
  if (is_test) {
    add_ip_ports(1, {"pluto.web.telegram.org/apiws_test"}, {443}, HostType::Url);
    add_ip_ports(2, {"venus.web.telegram.org/apiws_test"}, {443}, HostType::Url);
    add_ip_ports(3, {"aurora.web.telegram.org/apiws_test"}, {443}, HostType::Url);
  } else {
    add_ip_ports(1, {"pluto.web.telegram.org/apiws"}, {443}, HostType::Url);
    add_ip_ports(2, {"venus.web.telegram.org/apiws"}, {443}, HostType::Url);
    add_ip_ports(3, {"aurora.web.telegram.org/apiws"}, {443}, HostType::Url);
    add_ip_ports(4, {"vesta.web.telegram.org/apiws"}, {443}, HostType::Url);
    add_ip_ports(5, {"flora.web.telegram.org/apiws"}, {443}, HostType::Url);
  }
#else
  if (is_test) {
    add_ip_ports(1, {"149.154.175.10"}, ports);
    add_ip_ports(2, {"149.154.167.40"}, ports);
    add_ip_ports(3, {"149.154.175.117"}, ports);

    add_ip_ports(1, {"2001:b28:f23d:f001::e"}, ports, HostType::IPv6);
    add_ip_ports(2, {"2001:67c:4e8:f002::e"}, ports, HostType::IPv6);
    add_ip_ports(3, {"2001:b28:f23d:f003::e"}, ports, HostType::IPv6);
  } else {
    add_ip_ports(1, {"149.154.175.50"}, ports);
    add_ip_ports(2, {"149.154.167.51", "95.161.76.100"}, ports);
    add_ip_ports(3, {"149.154.175.100"}, ports);
    add_ip_ports(4, {"149.154.167.91"}, ports);
    add_ip_ports(5, {"149.154.171.5"}, ports);

    add_ip_ports(1, {"2001:b28:f23d:f001::a"}, ports, HostType::IPv6);
    add_ip_ports(2, {"2001:67c:4e8:f002::a"}, ports, HostType::IPv6);
    add_ip_ports(3, {"2001:b28:f23d:f003::a"}, ports, HostType::IPv6);
    add_ip_ports(4, {"2001:67c:4e8:f004::a"}, ports, HostType::IPv6);
    add_ip_ports(5, {"2001:b28:f23f:f005::a"}, ports, HostType::IPv6);
  }
#endif
  return res;
}

void ConnectionCreator::loop() {
  if (G()->close_flag()) {
    return;
  }
  if (!is_inited_) {
    return;
  }
  if (!network_flag_) {
    return;
  }

  Timestamp timeout;
  if (active_proxy_id_ != 0) {
    if (resolve_proxy_timestamp_.is_in_past()) {
      if (resolve_proxy_query_token_ == 0) {
        resolve_proxy_query_token_ = next_token();
        const Proxy &proxy = proxies_[active_proxy_id_];
        bool prefer_ipv6 = G()->get_option_boolean("prefer_ipv6");
        VLOG(connections) << "Resolve IP address " << resolve_proxy_query_token_ << " of " << proxy.server();
        send_closure(
            get_dns_resolver(), &GetHostByNameActor::run, proxy.server().str(), proxy.port(), prefer_ipv6,
            PromiseCreator::lambda([actor_id = create_reference(resolve_proxy_query_token_)](Result<IPAddress> result) {
              send_closure(actor_id, &ConnectionCreator::on_proxy_resolved, std::move(result), false);
            }));
      }
    } else {
      CHECK(resolve_proxy_query_token_ == 0);
      timeout.relax(resolve_proxy_timestamp_);
    }
  }

  if (timeout) {
    set_timeout_at(timeout.at());
  }
}

void ConnectionCreator::on_proxy_resolved(Result<IPAddress> r_ip_address, bool dummy) {
  SCOPE_EXIT {
    loop();
  };

  if (get_link_token() != resolve_proxy_query_token_) {
    VLOG(connections) << "Ignore unneeded proxy IP address " << get_link_token() << ", expected "
                      << resolve_proxy_query_token_;
    return;
  }

  resolve_proxy_query_token_ = 0;
  if (r_ip_address.is_error()) {
    VLOG(connections) << "Receive error for resolving proxy IP address: " << r_ip_address.error();
    resolve_proxy_timestamp_ = Timestamp::in(1 * 60);
    return;
  }
  proxy_ip_address_ = r_ip_address.move_as_ok();
  VLOG(connections) << "Set proxy IP address to " << proxy_ip_address_;
  resolve_proxy_timestamp_ = Timestamp::in(5 * 60);
  for (auto &client : clients_) {
    client_loop(client.second);
  }
}

void ConnectionCreator::on_ping_main_dc_result(uint64 token, Result<double> result) {
  auto &request = ping_main_dc_requests_[token];
  CHECK(request.left_queries > 0);
  if (result.is_error()) {
    LOG(DEBUG) << "Receive ping error " << result.error();
    if (request.result.is_error()) {
      request.result = std::move(result);
    }
  } else {
    LOG(DEBUG) << "Receive ping result " << result.ok();
    if (request.result.is_error() || request.result.ok() > result.ok()) {
      request.result = result.ok();
    }
  }

  if (--request.left_queries == 0) {
    if (request.result.is_error()) {
      request.promise.set_error(Status::Error(400, request.result.error().public_message()));
    } else {
      request.promise.set_value(request.result.move_as_ok());
    }
    ping_main_dc_requests_.erase(token);
  }
}

}  // namespace td
