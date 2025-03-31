//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Global.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/net/ConnectionCreator.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/NetQueryStats.h"
#include "td/telegram/net/TempAuthKeyWatchdog.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/StateManager.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/UpdatesManager.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/tl_helpers.h"

#include <cmath>

namespace td {

Global::Global() {
  auto current_scheduler_id = Scheduler::instance()->sched_id();
  auto max_scheduler_id = Scheduler::instance()->sched_count() - 1;
  database_scheduler_id_ = min(current_scheduler_id + 1, max_scheduler_id);
  gc_scheduler_id_ = min(current_scheduler_id + 2, max_scheduler_id);
  slow_net_scheduler_id_ = min(current_scheduler_id + 3, max_scheduler_id);
}

Global::~Global() = default;

void Global::log_out(Slice reason) {
  send_closure(auth_manager_, &AuthManager::on_authorization_lost, reason.str());
}

void Global::close_all(bool destroy_flag, Promise<Unit> on_finished) {
  td_db_->close(use_sqlite_pmc() ? get_database_scheduler_id() : get_slow_net_scheduler_id(), destroy_flag,
                std::move(on_finished));
  state_manager_.clear();
}

ActorId<ConnectionCreator> Global::connection_creator() const {
  return connection_creator_.get();
}
void Global::set_connection_creator(ActorOwn<ConnectionCreator> connection_creator) {
  connection_creator_ = std::move(connection_creator);
}

ActorId<TempAuthKeyWatchdog> Global::temp_auth_key_watchdog() const {
  return temp_auth_key_watchdog_.get();
}
void Global::set_temp_auth_key_watchdog(ActorOwn<TempAuthKeyWatchdog> actor) {
  temp_auth_key_watchdog_ = std::move(actor);
}

MtprotoHeader &Global::mtproto_header() {
  return *mtproto_header_;
}
void Global::set_mtproto_header(unique_ptr<MtprotoHeader> mtproto_header) {
  mtproto_header_ = std::move(mtproto_header);
}

struct ServerTimeDiff {
  double diff;
  double system_time;

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    store(diff, storer);
    store(system_time, storer);
  }
  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    parse(diff, parser);
    if (parser.get_left_len() != 0) {
      parse(system_time, parser);
    } else {
      system_time = 0;
    }
  }
};

Status Global::init(ActorId<Td> td, unique_ptr<TdDb> td_db_ptr) {
  td_ = td;
  td_db_ = std::move(td_db_ptr);

  string saved_diff_str = td_db()->get_binlog_pmc()->get("server_time_difference");
  auto system_time = Clocks::system();
  auto default_time_difference = system_time - Time::now();
  if (saved_diff_str.empty()) {
    server_time_difference_ = default_time_difference;
  } else {
    ServerTimeDiff saved_diff;
    unserialize(saved_diff, saved_diff_str).ensure();

    saved_diff_ = saved_diff.diff;
    saved_system_time_ = saved_diff.system_time;

    double diff = saved_diff.diff + default_time_difference;
    if (saved_diff.system_time > system_time) {
      double time_backwards_fix = saved_diff.system_time - system_time;
      if (time_backwards_fix > 60) {
        LOG(WARNING) << "Fix system time which went backwards: " << format::as_time(time_backwards_fix) << " "
                     << tag("saved_system_time", saved_diff.system_time) << tag("system_time", system_time);
      }
      diff += time_backwards_fix;
    } else if (saved_diff.system_time != 0) {
      const double MAX_TIME_FORWARD = 367 * 86400;  // if more than 1 year has passed, the session is logged out anyway
      if (saved_diff.system_time + MAX_TIME_FORWARD < system_time) {
        double time_forward_fix = system_time - (saved_diff.system_time + MAX_TIME_FORWARD);
        LOG(WARNING) << "Fix system time which went forward: " << format::as_time(time_forward_fix) << " "
                     << tag("saved_system_time", saved_diff.system_time) << tag("system_time", system_time);
        diff -= time_forward_fix;
      }
    } else if (saved_diff.diff >= 1500000000 && system_time >= 1500000000) {  // only for saved_diff.system_time == 0
      diff = default_time_difference;
    }
    LOG(DEBUG) << "LOAD: " << tag("server_time_difference", diff);
    server_time_difference_ = diff;
  }
  server_time_difference_was_updated_ = false;
  dns_time_difference_ = default_time_difference;
  dns_time_difference_was_updated_ = false;

  return Status::OK();
}

Slice Global::get_dir() const {
  return td_db_->get_database_directory();
}

Slice Global::get_files_dir() const {
  return td_db_->get_files_directory();
}

bool Global::is_test_dc() const {
  return td_db_->is_test_dc();
}

bool Global::use_file_database() const {
  return td_db_->use_file_database();
}

bool Global::use_sqlite_pmc() const {
  return td_db_->use_sqlite_pmc();
}

bool Global::use_chat_info_database() const {
  return td_db_->use_chat_info_database();
}

bool Global::use_message_database() const {
  return td_db_->use_message_database();
}

int32 Global::get_retry_after(int32 error_code, Slice error_message) {
  if (error_code != 429) {
    return 0;
  }

  Slice retry_after_prefix("Too Many Requests: retry after ");
  if (!begins_with(error_message, retry_after_prefix)) {
    return 0;
  }

  auto r_retry_after = to_integer_safe<int32>(error_message.substr(retry_after_prefix.size()));
  if (r_retry_after.is_ok() && r_retry_after.ok() > 0) {
    return r_retry_after.ok();
  }
  return 0;
}

int32 Global::to_unix_time(double server_time) const {
  LOG_CHECK(1.0 <= server_time && server_time <= 2140000000.0)
      << server_time << ' ' << Clocks::system() << ' ' << is_server_time_reliable() << ' '
      << get_server_time_difference() << ' ' << Time::now() << ' ' << saved_diff_ << ' ' << saved_system_time_;
  return static_cast<int32>(server_time);
}

void Global::update_server_time_difference(double diff, bool force) {
  if (force || !server_time_difference_was_updated_ || server_time_difference_ < diff) {
    server_time_difference_ = diff;
    server_time_difference_was_updated_ = true;
    do_save_server_time_difference();

    get_option_manager()->on_update_server_time_difference();
  }
}

void Global::save_server_time() {
  auto t = Time::now();
  if (server_time_difference_was_updated_ && system_time_saved_at_.load(std::memory_order_relaxed) + 10 < t) {
    system_time_saved_at_ = t;
    do_save_server_time_difference();
  }
}

void Global::do_save_server_time_difference() {
  if (get_option_boolean("disable_time_adjustment_protection")) {
    td_db()->get_binlog_pmc()->erase("server_time_difference");
    return;
  }

  // diff = server_time - Time::now
  // fixed_diff = server_time - Clocks::system
  double system_time = Clocks::system();
  double fixed_diff = server_time_difference_ + Time::now() - system_time;

  ServerTimeDiff diff;
  diff.diff = fixed_diff;
  diff.system_time = system_time;
  td_db()->get_binlog_pmc()->set("server_time_difference", serialize(diff));
}

void Global::update_dns_time_difference(double diff) {
  dns_time_difference_ = diff;
  dns_time_difference_was_updated_ = true;
}

double Global::get_dns_time_difference() const {
  bool dns_flag = dns_time_difference_was_updated_;
  double dns_diff = dns_time_difference_;
  bool server_flag = server_time_difference_was_updated_;
  double server_diff = server_time_difference_;
  if (dns_flag != server_flag) {
    return dns_flag ? dns_diff : server_diff;
  }
  if (dns_flag) {
    return max(dns_diff, server_diff);
  }
  if (td_db_) {
    return server_diff;
  }
  return Clocks::system() - Time::now();
}

DcId Global::get_webfile_dc_id() const {
  auto dc_id = narrow_cast<int32>(get_option_integer("webfile_dc_id"));
  if (!DcId::is_valid(dc_id)) {
    if (is_test_dc()) {
      dc_id = 2;
    } else {
      dc_id = 4;
    }

    CHECK(DcId::is_valid(dc_id));
  }

  return DcId::internal(dc_id);
}

void Global::set_net_query_stats(std::shared_ptr<NetQueryStats> net_query_stats) {
  net_query_creator_.set_create_func(
      [net_query_stats = std::move(net_query_stats)] { return td::make_unique<NetQueryCreator>(net_query_stats); });
}

void Global::set_net_query_dispatcher(unique_ptr<NetQueryDispatcher> net_query_dispatcher) {
  net_query_dispatcher_ = std::move(net_query_dispatcher);
}

const OptionManager *Global::get_option_manager() const {
  CHECK(option_manager_ != nullptr);
  return option_manager_;
}

OptionManager *Global::get_option_manager() {
  CHECK(option_manager_ != nullptr);
  return option_manager_;
}

void Global::set_option_empty(Slice name) {
  get_option_manager()->set_option_empty(name);
}

void Global::set_option_boolean(Slice name, bool value) {
  get_option_manager()->set_option_boolean(name, value);
}

void Global::set_option_integer(Slice name, int64 value) {
  get_option_manager()->set_option_integer(name, value);
}

void Global::set_option_string(Slice name, Slice value) {
  get_option_manager()->set_option_string(name, value);
}

bool Global::have_option(Slice name) const {
  return get_option_manager()->have_option(name);
}

bool Global::get_option_boolean(Slice name, bool default_value) const {
  return get_option_manager()->get_option_boolean(name, default_value);
}

int64 Global::get_option_integer(Slice name, int64 default_value) const {
  return get_option_manager()->get_option_integer(name, default_value);
}

string Global::get_option_string(Slice name, string default_value) const {
  return get_option_manager()->get_option_string(name, std::move(default_value));
}

int64 Global::get_location_key(double latitude, double longitude) {
  const double PI = 3.14159265358979323846;
  latitude *= PI / 180;
  longitude *= PI / 180;

  int64 key = 0;
  if (latitude < 0) {
    latitude = -latitude;
    key = 65536;
  }

  double f = std::tan(PI / 4 - latitude / 2);
  key += static_cast<int64>(f * std::cos(longitude) * 128) * 256;
  key += static_cast<int64>(f * std::sin(longitude) * 128);
  if (key == 0) {
    key = 1;
  }
  return key;
}

int64 Global::get_location_access_hash(double latitude, double longitude) {
  auto it = location_access_hashes_.find(get_location_key(latitude, longitude));
  if (it == location_access_hashes_.end()) {
    return 0;
  }
  return it->second;
}

void Global::add_location_access_hash(double latitude, double longitude, int64 access_hash) {
  if (access_hash == 0) {
    return;
  }

  location_access_hashes_[get_location_key(latitude, longitude)] = access_hash;
}

void Global::notify_speed_limited(bool is_upload) {
  send_closure(updates_manager_, &UpdatesManager::notify_speed_limited, is_upload);
}

double get_global_server_time() {
  return G()->server_time();
}

}  // namespace td
