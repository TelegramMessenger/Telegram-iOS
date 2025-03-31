//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/net/DcOptionsSet.h"

#include "td/telegram/ConfigManager.h"
#include "td/telegram/Global.h"

#include "td/actor/actor.h"

#include "td/utils/algorithm.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"

#include <algorithm>
#include <set>
#include <utility>

namespace td {

void DcOptionsSet::add_dc_options(DcOptions dc_options) {
  vector<DcOptionId> new_ordered_options;
  for (auto &option : dc_options.dc_options) {
    auto *info = register_dc_option(std::move(option));
    new_ordered_options.push_back(DcOptionId{info->pos});
  }

  std::set<DcOptionId> new_ordered_options_set(new_ordered_options.begin(), new_ordered_options.end());
  for (auto option_id : ordered_options_) {
    if (!new_ordered_options_set.count(option_id)) {
      new_ordered_options.push_back(option_id);
    }
  }

  ordered_options_ = std::move(new_ordered_options);
  for (size_t i = 0; i < ordered_options_.size(); i++) {
    options_[ordered_options_[i].pos]->order = i;
  }
}

DcOptions DcOptionsSet::get_dc_options() const {
  DcOptions result;
  for (auto id : ordered_options_) {
    result.dc_options.push_back(options_[id.pos]->option);
  }
  return result;
}

vector<DcOptionsSet::ConnectionInfo> DcOptionsSet::find_all_connections(DcId dc_id, bool allow_media_only,
                                                                        bool use_static, bool prefer_ipv6,
                                                                        bool only_http) {
  LOG(DEBUG) << "Find all " << (allow_media_only ? "media " : "") << "connections in " << dc_id
             << ". use_static = " << use_static << ", prefer_ipv6 = " << prefer_ipv6 << ", only_http = " << only_http;
  vector<ConnectionInfo> options;
  vector<ConnectionInfo> static_options;

  if (prefer_ipv6) {
    use_static = false;
  }

  for (auto &option_info : options_) {
    auto &option = option_info->option;
    if (option.get_dc_id() != dc_id) {
      continue;
    }
    if (!option.is_valid()) {
      LOG(INFO) << "Skip invalid DC option";
      continue;
    }
    if (!allow_media_only && option.is_media_only()) {
      LOG(DEBUG) << "Skip media only option";
      continue;
    }

    ConnectionInfo info;
    info.option = &option;
    info.order = option_info->order;

    OptionStat *option_stat = get_option_stat(option_info.get());

    if (!only_http) {
      info.use_http = false;
      info.stat = &option_stat->tcp_stat;
      if (option.is_static()) {
        static_options.push_back(info);
      } else {
        options.push_back(info);
      }
    }

    if (only_http) {
#if TD_DARWIN_WATCH_OS
      bool allow_ipv6 = true;
#else
      bool allow_ipv6 = prefer_ipv6;
#endif
      if (!option.is_obfuscated_tcp_only() && !option.is_static() && (allow_ipv6 || !option.is_ipv6())) {
        info.use_http = true;
        info.stat = &option_stat->http_stat;
        options.push_back(info);
      }
    }
  }

  if (use_static) {
    if (!static_options.empty()) {
      options = std::move(static_options);
    } else {
      bool have_ipv4 = any_of(options, [](const auto &v) { return !v.option->is_ipv6(); });
      if (have_ipv4) {
        td::remove_if(options, [](auto &v) { return v.option->is_ipv6(); });
      }
    }
  } else {
    if (options.empty()) {
      options = std::move(static_options);
    }
  }

  if (prefer_ipv6) {
    bool have_ipv6 = any_of(options, [](const auto &v) { return v.option->is_ipv6(); });
    if (have_ipv6) {
      td::remove_if(options, [](auto &v) { return !v.option->is_ipv6(); });
    }
  }

  bool have_media_only = any_of(options, [](const auto &v) { return v.option->is_media_only(); });
  if (have_media_only) {
    td::remove_if(options, [](auto &v) { return !v.option->is_media_only(); });
  }

  return options;
}

Result<DcOptionsSet::ConnectionInfo> DcOptionsSet::find_connection(DcId dc_id, bool allow_media_only, bool use_static,
                                                                   bool prefer_ipv6, bool only_http) {
  auto options = find_all_connections(dc_id, allow_media_only, use_static, prefer_ipv6, only_http);

  if (options.empty()) {
    send_closure(G()->config_manager(), &ConfigManager::lazy_request_config);
    return Status::Error(PSLICE() << "No such connection: " << tag("dc_id", dc_id)
                                  << tag("allow_media_only", allow_media_only) << tag("use_static", use_static)
                                  << tag("prefer_ipv6", prefer_ipv6));
  }

  auto last_error_at = std::min_element(options.begin(), options.end(), [](const auto &a_option, const auto &b_option) {
                         return a_option.stat->error_at > b_option.stat->error_at;
                       })->stat->error_at;

  auto result = *std::min_element(options.begin(), options.end(), [](const auto &a_option, const auto &b_option) {
    auto &a = *a_option.stat;
    auto &b = *b_option.stat;
    auto a_state = a.state();
    auto b_state = b.state();
    if (a_state != b_state) {
      return a_state < b_state;
    }
    if (a_state == Stat::State::Ok) {
      if (a_option.order == b_option.order) {
        return a_option.use_http < b_option.use_http;
      }
      return a_option.order < b_option.order;
    } else if (a_state == Stat::State::Error) {
      return a.error_at < b.error_at;
    }
    return a_option.order < b_option.order;
  });
  result.should_check = !result.stat->is_ok() || result.use_http || last_error_at > Time::now_cached() - 10;
  return result;
}

void DcOptionsSet::reset() {
  options_.clear();
  ordered_options_.clear();
}

DcOptionsSet::DcOptionInfo *DcOptionsSet::register_dc_option(DcOption &&option) {
  auto info = make_unique<DcOptionInfo>(std::move(option), options_.size());
  init_option_stat(info.get());
  auto result = info.get();
  options_.push_back(std::move(info));
  return result;
}

void DcOptionsSet::init_option_stat(DcOptionInfo *option_info) {
  const auto &ip_address = option_info->option.get_ip_address();
  for (size_t i = 0; i < option_stats_.size(); i++) {
    if (option_stats_[i].first == ip_address) {
      option_info->stat_id = i;
      return;
    }
  }
  option_stats_.emplace_back(ip_address, make_unique<OptionStat>());
  option_info->stat_id = option_stats_.size() - 1;
}

DcOptionsSet::OptionStat *DcOptionsSet::get_option_stat(const DcOptionInfo *option_info) {
  CHECK(option_info->stat_id < option_stats_.size());
  return option_stats_[option_info->stat_id].second.get();
}

}  // namespace td
