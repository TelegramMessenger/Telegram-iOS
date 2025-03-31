//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class TimeZoneManager final : public Actor {
 public:
  TimeZoneManager(Td *td, ActorShared<> parent);
  TimeZoneManager(const TimeZoneManager &) = delete;
  TimeZoneManager &operator=(const TimeZoneManager &) = delete;
  TimeZoneManager(TimeZoneManager &&) = delete;
  TimeZoneManager &operator=(TimeZoneManager &&) = delete;
  ~TimeZoneManager() final;

  int32 get_time_zone_offset(const string &time_zone_id);

  void get_time_zones(Promise<td_api::object_ptr<td_api::timeZones>> &&promise);

  void reload_time_zones(Promise<td_api::object_ptr<td_api::timeZones>> &&promise);

 private:
  void tear_down() final;

  struct TimeZone {
    string id_;
    string name_;
    int32 utc_offset_ = 0;

    TimeZone() = default;
    TimeZone(string &&id, string &&name, int32 utc_offset);

    td_api::object_ptr<td_api::timeZone> get_time_zone_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  struct TimeZoneList {
    vector<TimeZone> time_zones_;
    int32 hash_ = 0;
    bool is_loaded_ = false;

    td_api::object_ptr<td_api::timeZones> get_time_zones_object() const;

    template <class StorerT>
    void store(StorerT &storer) const;

    template <class ParserT>
    void parse(ParserT &parser);
  };

  friend bool operator==(const TimeZone &lhs, const TimeZone &rhs);

  friend bool operator!=(const TimeZone &lhs, const TimeZone &rhs);

  void on_get_time_zones(Result<telegram_api::object_ptr<telegram_api::help_TimezonesList>> &&r_time_zones);

  static string get_time_zones_database_key();

  void load_time_zones();

  void save_time_zones();

  vector<Promise<td_api::object_ptr<td_api::timeZones>>> get_time_zones_queries_;

  TimeZoneList time_zones_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
