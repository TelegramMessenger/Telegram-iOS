//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/DcId.h"
#include "td/telegram/net/DcOptions.h"
#include "td/telegram/net/DcOptionsSet.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/Proxy.h"
#include "td/telegram/td_api.h"

#include "td/mtproto/AuthData.h"
#include "td/mtproto/ConnectionManager.h"
#include "td/mtproto/Handshake.h"
#include "td/mtproto/RawConnection.h"
#include "td/mtproto/TransportType.h"

#include "td/net/NetStats.h"

#include "td/actor/actor.h"
#include "td/actor/SignalSlot.h"

#include "td/utils/BufferedFd.h"
#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/FloodControlStrict.h"
#include "td/utils/logging.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/Time.h"

#include <map>
#include <memory>
#include <set>
#include <utility>

namespace td {

namespace detail {
class StatsCallback;
}  // namespace detail

class GetHostByNameActor;

extern int VERBOSITY_NAME(connections);

class ConnectionCreator final : public NetQueryCallback {
 public:
  explicit ConnectionCreator(ActorShared<> parent);
  ConnectionCreator(ConnectionCreator &&other);
  ConnectionCreator &operator=(ConnectionCreator &&other);
  ~ConnectionCreator() final;

  void on_dc_options(DcOptions new_dc_options);
  void on_dc_update(DcId dc_id, string ip_port, Promise<> promise);
  void on_pong(uint32 hash);
  void on_mtproto_error(uint32 hash);
  void request_raw_connection(DcId dc_id, bool allow_media_only, bool is_media,
                              Promise<unique_ptr<mtproto::RawConnection>> promise, uint32 hash = 0,
                              unique_ptr<mtproto::AuthData> auth_data = {});
  void request_raw_connection_by_ip(IPAddress ip_address, mtproto::TransportType transport_type,
                                    Promise<unique_ptr<mtproto::RawConnection>> promise);

  void set_net_stats_callback(std::shared_ptr<NetStatsCallback> common_callback,
                              std::shared_ptr<NetStatsCallback> media_callback);

  void add_proxy(int32 old_proxy_id, string server, int32 port, bool enable,
                 td_api::object_ptr<td_api::ProxyType> proxy_type, Promise<td_api::object_ptr<td_api::proxy>> promise);
  void enable_proxy(int32 proxy_id, Promise<Unit> promise);
  void disable_proxy(Promise<Unit> promise);
  void remove_proxy(int32 proxy_id, Promise<Unit> promise);
  void get_proxies(Promise<td_api::object_ptr<td_api::proxies>> promise);
  void get_proxy_link(int32 proxy_id, Promise<string> promise);
  void ping_proxy(int32 proxy_id, Promise<double> promise);

  void test_proxy(Proxy &&proxy, int32 dc_id, double timeout, Promise<Unit> &&promise);

 private:
  ActorShared<> parent_;
  DcOptionsSet dc_options_set_;
  bool network_flag_ = false;
  uint32 network_generation_ = 0;
  bool online_flag_ = false;
  bool is_logging_out_ = false;
  bool is_inited_ = false;

  static constexpr int32 MAX_PROXY_LAST_USED_SAVE_DELAY = 60;
  std::map<int32, Proxy> proxies_;
  FlatHashMap<int32, int32> proxy_last_used_date_;
  FlatHashMap<int32, int32> proxy_last_used_saved_date_;
  int32 max_proxy_id_ = 0;
  int32 active_proxy_id_ = 0;
  ActorOwn<GetHostByNameActor> get_host_by_name_actor_;
  ActorOwn<GetHostByNameActor> block_get_host_by_name_actor_;
  IPAddress proxy_ip_address_;
  Timestamp resolve_proxy_timestamp_;
  uint64 resolve_proxy_query_token_{0};

  struct ClientInfo {
    class Backoff {
#if TD_ANDROID || TD_DARWIN_IOS || TD_DARWIN_VISION_OS || TD_DARWIN_WATCH_OS || TD_TIZEN
      static constexpr int32 MAX_BACKOFF = 300;
#else
      static constexpr int32 MAX_BACKOFF = 16;
#endif

     public:
      void add_event(int32 now) {
        wakeup_at_ = now + next_delay_;
        next_delay_ = min(MAX_BACKOFF, next_delay_ * 2);
      }
      int32 get_wakeup_at() const {
        return wakeup_at_;
      }
      void clear() {
        *this = {};
      }

     private:
      int32 wakeup_at_{0};
      int32 next_delay_ = 1;
    };
    ClientInfo();
    uint64 extract_session_id();
    void add_session_id(uint64 session_id);

    Backoff backoff;
    FloodControlStrict sanity_flood_control;
    FloodControlStrict flood_control;
    FloodControlStrict flood_control_online;
    FloodControlStrict mtproto_error_flood_control;
    Slot slot;
    size_t pending_connections{0};
    size_t checking_connections{0};
    std::vector<std::pair<unique_ptr<mtproto::RawConnection>, double>> ready_connections;
    std::vector<Promise<unique_ptr<mtproto::RawConnection>>> queries;

    static constexpr double READY_CONNECTIONS_TIMEOUT = 10;

    bool inited{false};
    uint32 hash{0};
    DcId dc_id;
    bool allow_media_only{false};
    bool is_media{false};
    std::set<uint64> session_ids_;
    unique_ptr<mtproto::AuthData> auth_data;
    uint64 auth_data_generation{0};
  };
  std::map<uint32, ClientInfo> clients_;

  std::shared_ptr<NetStatsCallback> media_net_stats_callback_;
  std::shared_ptr<NetStatsCallback> common_net_stats_callback_;

  ActorShared<ConnectionCreator> ref_cnt_guard_;
  int ref_cnt_{0};
  bool close_flag_{false};
  uint64 current_token_ = 0;
  std::map<uint64, std::pair<bool, ActorShared<>>> children_;

  struct PingMainDcRequest {
    Promise<double> promise;
    size_t left_queries = 0;
    Result<double> result;
  };
  std::map<uint64, PingMainDcRequest> ping_main_dc_requests_;

  struct ConnectionData {
    IPAddress ip_address;
    BufferedFd<SocketFd> buffered_socket_fd;
    mtproto::ConnectionManager::ConnectionToken connection_token;
    unique_ptr<mtproto::RawConnection::StatsCallback> stats_callback;
  };

  struct TestProxyRequest {
    Proxy proxy_;
    int16 dc_id_;
    ActorOwn<> child_;
    Promise<Unit> promise_;

    mtproto::TransportType get_transport() const {
      return mtproto::TransportType{mtproto::TransportType::ObfuscatedTcp, dc_id_, proxy_.secret()};
    }
  };
  uint64 test_proxy_request_id_ = 0;
  FlatHashMap<uint64, unique_ptr<TestProxyRequest>> test_proxy_requests_;

  uint64 next_token() {
    return ++current_token_;
  }

  ActorShared<ConnectionCreator> create_reference(int64 token);

  void set_active_proxy_id(int32 proxy_id, bool from_binlog = false);
  void enable_proxy_impl(int32 proxy_id);
  void disable_proxy_impl();
  void on_proxy_changed(bool from_db);
  static string get_proxy_database_key(int32 proxy_id);
  static string get_proxy_used_database_key(int32 proxy_id);
  void save_proxy_last_used_date(int32 delay);
  td_api::object_ptr<td_api::proxy> get_proxy_object(int32 proxy_id) const;

  void start_up() final;
  void hangup_shared() final;
  void hangup() final;
  void loop() final;

  void init_proxies();
  void add_dc_options(DcOptions &&new_dc_options);
  Result<SocketFd> do_request_connection(DcId dc_id, bool allow_media_only);
  Result<std::pair<unique_ptr<mtproto::RawConnection>, bool>> do_request_raw_connection(DcId dc_id,
                                                                                        bool allow_media_only,
                                                                                        bool is_media, uint32 hash);

  void on_network(bool network_flag, uint32 network_generation);
  void on_online(bool online_flag);
  void on_logging_out(bool is_logging_out);

  static void update_mtproto_header(const Proxy &proxy);

  void client_wakeup(uint32 hash);
  void client_loop(ClientInfo &client);
  void client_create_raw_connection(Result<ConnectionData> r_connection_data, bool check_mode,
                                    mtproto::TransportType transport_type, uint32 hash, string debug_str,
                                    uint32 network_generation);
  void client_add_connection(uint32 hash, Result<unique_ptr<mtproto::RawConnection>> r_raw_connection, bool check_flag,
                             uint64 auth_data_generation, uint64 session_id);
  void client_set_timeout_at(ClientInfo &client, double wakeup_at);

  void on_proxy_resolved(Result<IPAddress> ip_address, bool dummy);

  struct FindConnectionExtra {
    DcOptionsSet::Stat *stat{nullptr};
    mtproto::TransportType transport_type;
    string debug_str;
    IPAddress ip_address;
    IPAddress mtproto_ip_address;
    bool check_mode{false};
  };
  Result<SocketFd> find_connection(const Proxy &proxy, const IPAddress &proxy_ip_address, DcId dc_id,
                                   bool allow_media_only, FindConnectionExtra &extra);

  static DcOptions get_default_dc_options(bool is_test);

  static Result<mtproto::TransportType> get_transport_type(const Proxy &proxy,
                                                           const DcOptionsSet::ConnectionInfo &info);

  static ActorOwn<> prepare_connection(IPAddress ip_address, SocketFd socket_fd, const Proxy &proxy,
                                       const IPAddress &mtproto_ip_address,
                                       const mtproto::TransportType &transport_type, Slice actor_name_prefix,
                                       Slice debug_str,
                                       unique_ptr<mtproto::RawConnection::StatsCallback> stats_callback,
                                       ActorShared<> parent, bool use_connection_token,
                                       Promise<ConnectionData> promise);

  ActorId<GetHostByNameActor> get_dns_resolver();

  void ping_proxy_resolved(int32 proxy_id, IPAddress ip_address, Promise<double> promise);

  void ping_proxy_buffered_socket_fd(IPAddress ip_address, BufferedFd<SocketFd> buffered_socket_fd,
                                     mtproto::TransportType transport_type, string debug_str, Promise<double> promise);

  void on_ping_main_dc_result(uint64 token, Result<double> result);

  void on_test_proxy_connection_data(uint64 request_id, Result<ConnectionData> r_data);

  void on_test_proxy_handshake_connection(uint64 request_id,
                                          Result<unique_ptr<mtproto::RawConnection>> r_raw_connection);

  void on_test_proxy_handshake(uint64 request_id, Result<unique_ptr<mtproto::AuthKeyHandshake>> r_handshake);

  void on_test_proxy_timeout(uint64 request_id);
};

}  // namespace td
