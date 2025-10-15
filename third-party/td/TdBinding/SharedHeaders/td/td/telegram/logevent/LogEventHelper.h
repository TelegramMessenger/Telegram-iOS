//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Global.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/StorerBase.h"
#include "td/utils/Time.h"
#include "td/utils/tl_helpers.h"

namespace td {

struct LogEventIdWithGeneration {
  uint64 log_event_id = 0;
  uint64 generation = 0;
};

void add_log_event(LogEventIdWithGeneration &log_event_id, const Storer &storer, uint32 type, Slice name);

void delete_log_event(LogEventIdWithGeneration &log_event_id, uint64 generation, Slice name);

Promise<Unit> get_erase_log_event_promise(uint64 log_event_id, Promise<Unit> promise = Promise<Unit>());

template <class StorerT>
void store_time(double time_at, StorerT &storer) {
  if (time_at == 0) {
    store(-1.0, storer);
  } else {
    double time_left = max(time_at - Time::now(), 0.0);
    store(time_left, storer);
    store(get_global_server_time(), storer);
  }
}

template <class ParserT>
void parse_time(double &time_at, ParserT &parser) {
  double time_left;
  parse(time_left, parser);
  if (time_left < -0.1) {
    time_at = 0;
  } else {
    double old_server_time;
    parse(old_server_time, parser);
    double passed_server_time = max(parser.context()->server_time() - old_server_time, 0.0);
    time_left = max(time_left - passed_server_time, 0.0);
    time_at = Time::now_cached() + time_left;
  }
}

}  // namespace td
