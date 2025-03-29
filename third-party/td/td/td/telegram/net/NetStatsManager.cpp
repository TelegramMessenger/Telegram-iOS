//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/NetStatsManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/Version.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
static void store(const NetStatsData &net_stats, StorerT &storer) {
  using ::td::store;
  store(net_stats.read_size, storer);
  store(net_stats.write_size, storer);
  store(net_stats.count, storer);
  store(net_stats.duration, storer);
}

template <class ParserT>
static void parse(NetStatsData &net_stats, ParserT &parser) {
  using ::td::parse;
  parse(net_stats.read_size, parser);
  parse(net_stats.write_size, parser);

  if (parser.version() >= static_cast<int32>(Version::NetStatsCountDuration)) {
    parse(net_stats.count, parser);
    parse(net_stats.duration, parser);
  }
}

void NetStatsManager::init() {
  LOG_CHECK(!empty()) << G()->close_flag();
  class NetStatsInternalCallback final : public NetStats::Callback {
   public:
    NetStatsInternalCallback(ActorId<NetStatsManager> parent, size_t id) : parent_(std::move(parent)), id_(id) {
    }

   private:
    ActorId<NetStatsManager> parent_;
    size_t id_;
    void on_stats_updated() final {
      send_closure(parent_, &NetStatsManager::on_stats_updated, id_);
    }
  };

  for_each_stat([&](NetStatsInfo &stat, size_t id, CSlice name, FileType file_type) {
    auto main_file_type = get_main_file_type(file_type);
    id += static_cast<size_t>(main_file_type) - static_cast<size_t>(file_type);

    stat.key = "net_stats_" + name.str();
    stat.stats.set_callback(make_unique<NetStatsInternalCallback>(actor_id(this), id));
  });
}

void NetStatsManager::get_network_stats(bool current, Promise<NetworkStats> promise) {
  NetworkStats result;

  result.since = current ? since_current_ : since_total_;

  for_each_stat([&](NetStatsInfo &info, size_t id, CSlice name, FileType file_type) { update(info, false); });

  for (size_t net_type_i = 0; net_type_i < net_type_size(); net_type_i++) {
    auto net_type = NetType(net_type_i);
    NetStatsData total;
    NetStatsData total_files;

    for_each_stat([&](NetStatsInfo &info, size_t id, CSlice name, FileType file_type) {
      const auto &type_stats = info.stats_by_type[net_type_i];
      auto stats = current ? type_stats.mem_stats : type_stats.mem_stats + type_stats.db_stats;
      if (id == 0) {
      } else if (id == 1) {
        total = stats;
      } else if (id == CALL_NET_STATS_ID) {
      } else if (file_type != FileType::None) {
        total_files = total_files + stats;
      }
    });

    NetStatsData check;
    for_each_stat([&](NetStatsInfo &info, size_t id, CSlice name, FileType file_type) {
      if (id == 1) {
        return;
      }
      const auto &type_stats = info.stats_by_type[net_type_i];
      auto stats = current ? type_stats.mem_stats : type_stats.mem_stats + type_stats.db_stats;

      NetworkStatsEntry entry;
      entry.file_type = file_type;
      entry.net_type = net_type;
      entry.rx = stats.read_size;
      entry.tx = stats.write_size;
      entry.count = stats.count;
      entry.duration = stats.duration;
      if (id == 0) {
        result.entries.push_back(std::move(entry));
      } else if (id == CALL_NET_STATS_ID) {
        entry.is_call = true;
        result.entries.push_back(std::move(entry));
      } else if (file_type != FileType::None) {
        if (get_main_file_type(file_type) != file_type) {
          return;
        }

        if (total_files.read_size != 0) {
          entry.rx = static_cast<int64>(static_cast<double>(total.read_size) *
                                        (static_cast<double>(entry.rx) / static_cast<double>(total_files.read_size)));
        } else {
          // entry.rx += total.read_size / MAX_FILE_TYPE;
        }

        if (total_files.write_size != 0) {
          entry.tx = static_cast<int64>(static_cast<double>(total.write_size) *
                                        (static_cast<double>(entry.tx) / static_cast<double>(total_files.write_size)));
        } else {
          // entry.tx += total.write_size / MAX_FILE_TYPE;
        }
        check.read_size += entry.rx;
        check.write_size += entry.tx;
        result.entries.push_back(std::move(entry));
      }
    });
    // LOG(ERROR) << total.read_size << " " << check.read_size;
    // LOG(ERROR) << total.write_size << " " << check.write_size;
  }

  promise.set_value(std::move(result));
}

void NetStatsManager::reset_network_stats() {
  auto do_reset_network_stats = [&](auto &info) {
    info.last_sync_stats = info.stats.get_stats();
    for (size_t net_type_i = 0; net_type_i < net_type_size(); net_type_i++) {
      auto net_type = NetType(net_type_i);
      info.stats_by_type[net_type_i] = NetStatsInfo::TypeStats{};
      auto key = PSTRING() << info.key << '#' << net_type_string(net_type);
      G()->td_db()->get_binlog_pmc()->erase(key);
    }
  };

  for_each_stat([&](NetStatsInfo &info, size_t id, CSlice name, FileType) { do_reset_network_stats(info); });

  auto unix_time = G()->unix_time();
  since_total_ = unix_time;
  since_current_ = unix_time;
  G()->td_db()->get_binlog_pmc()->set("net_stats_since", to_string(unix_time));
}

void NetStatsManager::add_network_stats(const NetworkStatsEntry &entry) {
  if (entry.is_call) {
    return add_network_stats_impl(call_net_stats_, entry);
  }
  if (entry.file_type == FileType::None) {
    return add_network_stats_impl(common_net_stats_, entry);
  }
  add_network_stats_impl(media_net_stats_, entry);
  auto file_type_n = static_cast<size_t>(entry.file_type);
  CHECK(file_type_n < static_cast<size_t>(MAX_FILE_TYPE));
  add_network_stats_impl(files_stats_[file_type_n], entry);
}

void NetStatsManager::add_network_stats_impl(NetStatsInfo &info, const NetworkStatsEntry &entry) {
  auto net_type_i = static_cast<size_t>(entry.net_type);
  auto &data = info.stats_by_type[net_type_i].mem_stats;

  if (data.read_size + entry.rx < data.read_size || data.write_size + entry.tx < data.write_size ||
      data.count + entry.count < data.count) {
    LOG(ERROR) << "Network stats overflow";
    return;
  }

  data.read_size += entry.rx;
  data.write_size += entry.tx;
  data.count += entry.count;
  data.duration += entry.duration;
  save_stats(info, entry.net_type);
}

void NetStatsManager::start_up() {
  for_each_stat([&](NetStatsInfo &info, size_t id, CSlice name, FileType file_type) {
    if (get_main_file_type(file_type) != file_type) {
      return;
    }

    for (size_t net_type_i = 0; net_type_i < net_type_size(); net_type_i++) {
      auto net_type = NetType(net_type_i);
      auto key = PSTRING() << info.key << '#' << net_type_string(net_type);

      auto value = G()->td_db()->get_binlog_pmc()->get(key);
      if (value.empty()) {
        continue;
      }
      log_event_parse(info.stats_by_type[net_type_i].db_stats, value).ensure();
    }
  });
  auto unix_time = G()->unix_time();
  since_total_ = 0;
  since_current_ = unix_time;
  auto since_str = G()->td_db()->get_binlog_pmc()->get("net_stats_since");
  if (!since_str.empty()) {
    auto since = to_integer<int32>(since_str);
    auto authorization_date = G()->get_option_integer("authorization_date");
    if (unix_time < since) {
      since_total_ = unix_time;
      G()->td_db()->get_binlog_pmc()->set("net_stats_since", to_string(since_total_));
    } else if (since < authorization_date - 3600) {
      since_total_ = narrow_cast<int32>(authorization_date);
      G()->td_db()->get_binlog_pmc()->set("net_stats_since", to_string(since_total_));
    } else {
      since_total_ = since;
    }
  } else {
    // approximate since_total by first run date for new users
    since_total_ = unix_time;
    G()->td_db()->get_binlog_pmc()->set("net_stats_since", to_string(since_total_));
  }

  class NetCallback final : public StateManager::Callback {
   public:
    explicit NetCallback(ActorId<NetStatsManager> net_stats_manager)
        : net_stats_manager_(std::move(net_stats_manager)) {
    }
    bool on_network(NetType network_type, uint32 network_generation) final {
      send_closure(net_stats_manager_, &NetStatsManager::on_net_type_updated, network_type);
      return net_stats_manager_.is_alive();
    }

   private:
    ActorId<NetStatsManager> net_stats_manager_;
  };
  send_closure(G()->state_manager(), &StateManager::add_callback, make_unique<NetCallback>(actor_id(this)));
}

std::shared_ptr<NetStatsCallback> NetStatsManager::get_common_stats_callback() const {
  return common_net_stats_.stats.get_callback();
}

std::shared_ptr<NetStatsCallback> NetStatsManager::get_media_stats_callback() const {
  return media_net_stats_.stats.get_callback();
}

std::vector<std::shared_ptr<NetStatsCallback>> NetStatsManager::get_file_stats_callbacks() const {
  auto result = transform(files_stats_, [](auto &stat) { return stat.stats.get_callback(); });
  for (int32 i = 0; i < MAX_FILE_TYPE; i++) {
    auto main_file_type = static_cast<int32>(get_main_file_type(static_cast<FileType>(i)));
    if (main_file_type != i) {
      result[i] = result[main_file_type];
    }
  }
  return result;
}

void NetStatsManager::update(NetStatsInfo &info, bool force_save) {
  if (info.net_type == NetType::None) {
    return;
  }
  auto current_stats = info.stats.get_stats();
  auto diff = current_stats - info.last_sync_stats;

  auto net_type_i = static_cast<size_t>(info.net_type);
  auto &type_stats = info.stats_by_type[net_type_i];

  info.last_sync_stats = current_stats;

  auto mem_stats = type_stats.mem_stats + diff;
  type_stats.mem_stats = mem_stats;
  type_stats.dirty_size += diff.read_size + diff.write_size;

  if (type_stats.dirty_size < 1000 && !force_save) {
    return;
  }

  type_stats.dirty_size = 0;

  save_stats(info, info.net_type);
}

void NetStatsManager::save_stats(NetStatsInfo &info, NetType net_type) {
  if (G()->get_option_boolean("disable_persistent_network_statistics")) {
    return;
  }

  auto net_type_i = static_cast<size_t>(net_type);
  auto &type_stats = info.stats_by_type[net_type_i];

  auto key = PSTRING() << info.key << '#' << net_type_string(info.net_type);
  auto stats = type_stats.mem_stats + type_stats.db_stats;
  // LOG(ERROR) << "SAVE " << key << ' ' << stats;

  G()->td_db()->get_binlog_pmc()->set(key, log_event_store(stats).as_slice().str());
}

void NetStatsManager::info_loop(NetStatsInfo &info) {
  if (info.net_type == NetType::None) {
    return;
  }
  auto mem_stats = info.stats.get_stats();
  auto diff = mem_stats - info.last_sync_stats;
  auto size = diff.read_size + diff.write_size;
  if (size < 1000) {
    return;
  }
  update(info, false);
}

void NetStatsManager::on_stats_updated(size_t id) {
  for_each_stat([&](NetStatsInfo &stat, size_t stat_id, CSlice name, FileType) {
    if (stat_id == id) {
      info_loop(stat);
    }
  });
}

void NetStatsManager::on_net_type_updated(NetType net_type) {
  if (net_type == NetType::Unknown) {
    net_type = NetType::None;
  }
  auto do_on_net_type_updated = [&](NetStatsInfo &info) {  // g++ 4.9-6.2 crashes if (auto &info) is used
    if (info.net_type == net_type) {
      return;
    }
    if (info.net_type != NetType::None) {
      update(info, true);
    }
    info.net_type = net_type;
  };

  for_each_stat([&](NetStatsInfo &stat, size_t stat_id, CSlice name, FileType) { do_on_net_type_updated(stat); });
}

}  // namespace td
