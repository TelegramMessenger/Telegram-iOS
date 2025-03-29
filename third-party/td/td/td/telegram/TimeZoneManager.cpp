//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TimeZoneManager.h"

#include "td/telegram/Global.h"
#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/Td.h"
#include "td/telegram/TdDb.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/algorithm.h"
#include "td/utils/buffer.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/tl_helpers.h"

namespace td {

class GetTimezonesListQuery final : public Td::ResultHandler {
  Promise<telegram_api::object_ptr<telegram_api::help_TimezonesList>> promise_;

 public:
  explicit GetTimezonesListQuery(Promise<telegram_api::object_ptr<telegram_api::help_TimezonesList>> &&promise)
      : promise_(std::move(promise)) {
  }

  void send(int32 hash) {
    send_query(G()->net_query_creator().create(telegram_api::help_getTimezonesList(hash)));
  }

  void on_result(BufferSlice packet) final {
    auto result_ptr = fetch_result<telegram_api::help_getTimezonesList>(packet);
    if (result_ptr.is_error()) {
      return on_error(result_ptr.move_as_error());
    }

    promise_.set_value(result_ptr.move_as_ok());
  }

  void on_error(Status status) final {
    if (!G()->is_expected_error(status)) {
      LOG(ERROR) << "GetTimezonesListQuery returned " << status;
    }
    promise_.set_error(std::move(status));
  }
};

TimeZoneManager::TimeZone::TimeZone(string &&id, string &&name, int32 utc_offset)
    : id_(std::move(id)), name_(std::move(name)), utc_offset_(utc_offset) {
}

td_api::object_ptr<td_api::timeZone> TimeZoneManager::TimeZone::get_time_zone_object() const {
  return td_api::make_object<td_api::timeZone>(id_, name_, utc_offset_);
}

bool operator==(const TimeZoneManager::TimeZone &lhs, const TimeZoneManager::TimeZone &rhs) {
  return lhs.id_ == rhs.id_ && lhs.name_ == rhs.name_ && lhs.utc_offset_ == rhs.utc_offset_;
}

bool operator!=(const TimeZoneManager::TimeZone &lhs, const TimeZoneManager::TimeZone &rhs) {
  return !(lhs == rhs);
}

template <class StorerT>
void TimeZoneManager::TimeZone::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  END_STORE_FLAGS();
  td::store(id_, storer);
  td::store(name_, storer);
  td::store(utc_offset_, storer);
}

template <class ParserT>
void TimeZoneManager::TimeZone::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  END_PARSE_FLAGS();
  td::parse(id_, parser);
  td::parse(name_, parser);
  td::parse(utc_offset_, parser);
}

td_api::object_ptr<td_api::timeZones> TimeZoneManager::TimeZoneList::get_time_zones_object() const {
  return td_api::make_object<td_api::timeZones>(
      transform(time_zones_, [](const TimeZone &time_zone) { return time_zone.get_time_zone_object(); }));
}

template <class StorerT>
void TimeZoneManager::TimeZoneList::store(StorerT &storer) const {
  td::store(time_zones_, storer);
  td::store(hash_, storer);
}

template <class ParserT>
void TimeZoneManager::TimeZoneList::parse(ParserT &parser) {
  td::parse(time_zones_, parser);
  td::parse(hash_, parser);
  is_loaded_ = true;
}

TimeZoneManager::TimeZoneManager(Td *td, ActorShared<> parent) : td_(td), parent_(std::move(parent)) {
}

TimeZoneManager::~TimeZoneManager() = default;

void TimeZoneManager::tear_down() {
  parent_.reset();
}

int32 TimeZoneManager::get_time_zone_offset(const string &time_zone_id) {
  load_time_zones();
  for (auto &time_zone : time_zones_.time_zones_) {
    if (time_zone.id_ == time_zone_id) {
      return time_zone.utc_offset_;
    }
  }
  return narrow_cast<int32>(G()->get_option_integer("utc_time_offset"));
}

void TimeZoneManager::get_time_zones(Promise<td_api::object_ptr<td_api::timeZones>> &&promise) {
  load_time_zones();
  if (time_zones_.hash_ != 0) {
    return promise.set_value(time_zones_.get_time_zones_object());
  }
  reload_time_zones(std::move(promise));
}

void TimeZoneManager::reload_time_zones(Promise<td_api::object_ptr<td_api::timeZones>> &&promise) {
  load_time_zones();
  get_time_zones_queries_.push_back(std::move(promise));
  if (get_time_zones_queries_.size() == 1) {
    auto query_promise = PromiseCreator::lambda(
        [actor_id = actor_id(this)](Result<telegram_api::object_ptr<telegram_api::help_TimezonesList>> &&r_time_zones) {
          send_closure(actor_id, &TimeZoneManager::on_get_time_zones, std::move(r_time_zones));
        });
    td_->create_handler<GetTimezonesListQuery>(std::move(query_promise))->send(time_zones_.hash_);
  }
}

void TimeZoneManager::on_get_time_zones(
    Result<telegram_api::object_ptr<telegram_api::help_TimezonesList>> &&r_time_zones) {
  G()->ignore_result_if_closing(r_time_zones);
  if (r_time_zones.is_error()) {
    return fail_promises(get_time_zones_queries_, r_time_zones.move_as_error());
  }

  auto time_zones_ptr = r_time_zones.move_as_ok();
  switch (time_zones_ptr->get_id()) {
    case telegram_api::help_timezonesListNotModified::ID:
      break;
    case telegram_api::help_timezonesList::ID: {
      auto zone_list = telegram_api::move_object_as<telegram_api::help_timezonesList>(time_zones_ptr);
      vector<TimeZone> time_zones;
      for (auto &time_zone : zone_list->timezones_) {
        time_zones.emplace_back(std::move(time_zone->id_), std::move(time_zone->name_), time_zone->utc_offset_);
      }
      if (time_zones_.time_zones_ != time_zones || time_zones_.hash_ != zone_list->hash_) {
        time_zones_.time_zones_ = std::move(time_zones);
        time_zones_.hash_ = zone_list->hash_;
        save_time_zones();
      }
      break;
    }
    default:
      UNREACHABLE();
  }
  time_zones_.is_loaded_ = true;

  auto promises = std::move(get_time_zones_queries_);
  reset_to_empty(get_time_zones_queries_);
  for (auto &promise : promises) {
    if (promise) {
      promise.set_value(time_zones_.get_time_zones_object());
    }
  }
}

string TimeZoneManager::get_time_zones_database_key() {
  return "time_zones";
}

void TimeZoneManager::load_time_zones() {
  if (time_zones_.is_loaded_) {
    return;
  }
  time_zones_.is_loaded_ = true;

  auto log_event_string = G()->td_db()->get_binlog_pmc()->get(get_time_zones_database_key());
  if (log_event_string.empty()) {
    return;
  }
  auto status = log_event_parse(time_zones_, log_event_string);
  if (status.is_error()) {
    LOG(ERROR) << "Failed to parse time zones from binlog: " << status;
    time_zones_ = TimeZoneList();
  }
}

void TimeZoneManager::save_time_zones() {
  G()->td_db()->get_binlog_pmc()->set(get_time_zones_database_key(), log_event_store(time_zones_).as_slice().str());
}

}  // namespace td
