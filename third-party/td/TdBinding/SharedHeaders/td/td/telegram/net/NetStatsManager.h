//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/files/FileType.h"
#include "td/telegram/net/NetType.h"
#include "td/telegram/td_api.h"

#include "td/net/NetStats.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"

#include <array>
#include <memory>

namespace td {

struct NetworkStatsEntry {
  FileType file_type{FileType::None};

  NetType net_type{NetType::Other};
  int64 rx{0};
  int64 tx{0};

  bool is_call{false};
  int64 count{0};
  double duration{0};

  tl_object_ptr<td_api::NetworkStatisticsEntry> get_network_statistics_entry_object() const {
    if (is_call) {
      return make_tl_object<td_api::networkStatisticsEntryCall>(get_network_type_object(net_type), tx, rx, duration);
    } else {
      return make_tl_object<td_api::networkStatisticsEntryFile>(get_file_type_object(file_type),
                                                                get_network_type_object(net_type), tx, rx);
    }
  }
};

struct NetworkStats {
  int32 since = 0;
  std::vector<NetworkStatsEntry> entries;

  auto get_network_statistics_object() const {
    auto result = make_tl_object<td_api::networkStatistics>();
    result->since_date_ = since;
    result->entries_.reserve(entries.size());
    for (const auto &entry : entries) {
      if ((entry.rx != 0 || entry.tx != 0) && entry.file_type != FileType::SecureDecrypted) {
        result->entries_.push_back(entry.get_network_statistics_entry_object());
      }
    }
    return result;
  }
};

class NetStatsManager final : public Actor {
 public:
  explicit NetStatsManager(ActorShared<> parent) : parent_(std::move(parent)) {
  }
  // Call init just after actor is registered and before getting callbacks
  void init();
  std::shared_ptr<NetStatsCallback> get_common_stats_callback() const;
  std::shared_ptr<NetStatsCallback> get_media_stats_callback() const;
  std::vector<std::shared_ptr<NetStatsCallback>> get_file_stats_callbacks() const;

  void get_network_stats(bool current, Promise<NetworkStats> promise);

  void reset_network_stats();

  void add_network_stats(const NetworkStatsEntry &entry);

 private:
  ActorShared<> parent_;

  static constexpr size_t net_type_size() {
    return static_cast<size_t>(NetType::Size);
  }

  static CSlice net_type_string(NetType type) {
    switch (type) {
      case NetType::Other:
        return CSlice("other");
      case NetType::WiFi:
        return CSlice("wifi");
      case NetType::Mobile:
        return CSlice("mobile");
      case NetType::MobileRoaming:
        return CSlice("mobile_roaming");
      default:
        return CSlice("bug");
    }
  }

  struct NetStatsInfo {
    string key;
    NetStats stats;
    NetStatsData last_sync_stats;
    NetType net_type = NetType::None;

    struct TypeStats {
      uint64 dirty_size = 0;
      NetStatsData mem_stats;
      NetStatsData db_stats;
    };
    std::array<TypeStats, 5 /*NetStatsManager::net_type_size()*/> stats_by_type;
  };

  int32 since_total_{0};
  int32 since_current_{0};
  NetStatsInfo common_net_stats_;
  NetStatsInfo media_net_stats_;
  std::array<NetStatsInfo, MAX_FILE_TYPE> files_stats_;
  NetStatsInfo call_net_stats_;
  static constexpr int32 CALL_NET_STATS_ID{MAX_FILE_TYPE + 2};

  template <class F>
  void for_each_stat(F &&f) {
    f(common_net_stats_, 0, CSlice("common"), FileType::None);
    f(media_net_stats_, 1, CSlice("media"), FileType::None);
    for (int32 file_type_i = 0; file_type_i < MAX_FILE_TYPE; file_type_i++) {
      auto &stat = files_stats_[file_type_i];
      auto file_type = static_cast<FileType>(file_type_i);
      f(stat, file_type_i + 2, get_file_type_unique_name(file_type), file_type);
    }
    f(call_net_stats_, CALL_NET_STATS_ID, CSlice("calls"), FileType::None);
  }

  static void add_network_stats_impl(NetStatsInfo &info, const NetworkStatsEntry &entry);

  void start_up() final;

  static void update(NetStatsInfo &info, bool force_save);
  static void save_stats(NetStatsInfo &info, NetType net_type);
  static void info_loop(NetStatsInfo &info);

  void on_stats_updated(size_t id);
  void on_net_type_updated(NetType net_type);
};

}  // namespace td

/*

networkTypeBluetooth = NetworkType; ?
networkTypeEthernet = NetworkType;  ?

Android NetType.
TYPE_BLUETOOTH The Bluetooth data connection.
TYPE_DUMMY Dummy data connection.
TYPE_ETHERNET The Ethernet data connection.
TYPE_MOBILE The Mobile data connection.
TYPE_MOBILE_DUN A DUN-specific Mobile data connection.
TYPE_VPN A virtual network using one or more native bearers.
TYPE_WIFI The WIFI data connection.
TYPE_WIMAX The WiMAX data connection.

ios NetType
ReachableViaWiFi,
ReachableViaWWAN


Mobile subtype
2G
NETWORK_TYPE_IDEN  ~25 kbps
NETWORK_TYPE_CDMA  ~ 14-64 kbps
CTRadioAccessTechnologyCDMA1x
NETWORK_TYPE_1xRTT  ~ 50-100 kbps
NETWORK_TYPE_GPRS  ~ 100 kbps
CTRadioAccessTechnologyEdge
NETWORK_TYPE_EDGE  ~ 50-100 kbps
CTRadioAccessTechnologyGPRS

3G
NETWORK_TYPE_EVDO_0  ~ 400-1000 kbps
CTRadioAccessTechnologyCDMAEVDORev0
NETWORK_TYPE_EVDO_A  ~ 600-1400 kbps
CTRadioAccessTechnologyCDMAEVDORevA
NETWORK_TYPE_HSPA  ~ 700-1700 kbps
NETWORK_TYPE_UMTS  ~ 400-7000 kbps
NETWORK_TYPE_EHRPD  ~ 1-2 Mbps
NETWORK_TYPE_EVDO_B  ~ 5 Mbps
CTRadioAccessTechnologyCDMAEVDORevB
NETWORK_TYPE_HSDPA  ~ 2-14 Mbps
CTRadioAccessTechnologyHSDPA
NETWORK_TYPE_HSPAP  ~ 10-20 Mbps
NETWORK_TYPE_HSUPA  ~ 1-23 Mbps
CTRadioAccessTechnologyHSUPA

CTRadioAccessTechnologyWCDMA
CTRadioAccessTechnologyeHRPD

4G
NETWORK_TYPE_LTE  ~ 10+ Mbps
CTRadioAccessTechnologyLTE

NETWORK_TYPE_GSM
NETWORK_TYPE_IWLAN
NETWORK_TYPE_TD_SCDMA
NETWORK_TYPE_UNKNOWN

*/
