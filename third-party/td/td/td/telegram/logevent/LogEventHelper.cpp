//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/logevent/LogEventHelper.h"

#include "td/telegram/Global.h"
#include "td/telegram/TdDb.h"

#include "td/db/binlog/BinlogHelper.h"

#include "td/utils/logging.h"
#include "td/utils/Status.h"

namespace td {

void add_log_event(LogEventIdWithGeneration &log_event_id, const Storer &storer, uint32 type, Slice name) {
  LOG(INFO) << "Save " << name << " to binlog";
  if (log_event_id.log_event_id == 0) {
    log_event_id.log_event_id = binlog_add(G()->td_db()->get_binlog(), type, storer);
    LOG(INFO) << "Add " << name << " log event " << log_event_id.log_event_id;
  } else {
    auto new_log_event_id = binlog_rewrite(G()->td_db()->get_binlog(), log_event_id.log_event_id, type, storer);
    LOG(INFO) << "Rewrite " << name << " log event " << log_event_id.log_event_id << " with " << new_log_event_id;
  }
  log_event_id.generation++;
}

void delete_log_event(LogEventIdWithGeneration &log_event_id, uint64 generation, Slice name) {
  LOG(INFO) << "Finish to process " << name << " log event " << log_event_id.log_event_id << " with generation "
            << generation;
  if (log_event_id.generation == generation) {
    CHECK(log_event_id.log_event_id != 0);
    LOG(INFO) << "Delete " << name << " log event " << log_event_id.log_event_id;
    binlog_erase(G()->td_db()->get_binlog(), log_event_id.log_event_id);
    log_event_id.log_event_id = 0;
  }
}

Promise<Unit> get_erase_log_event_promise(uint64 log_event_id, Promise<Unit> promise) {
  if (log_event_id == 0) {
    return promise;
  }

  return PromiseCreator::lambda([log_event_id, promise = std::move(promise)](Result<Unit> result) mutable {
    if (!G()->close_flag()) {
      binlog_erase(G()->td_db()->get_binlog(), log_event_id);
    }

    promise.set_result(std::move(result));
  });
}

}  // namespace td
