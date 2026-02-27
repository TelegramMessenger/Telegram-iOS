//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/binlog/BinlogInterface.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/StorerBase.h"

namespace td {

inline uint64 binlog_add(BinlogInterface *binlog_ptr, int32 type, const Storer &storer,
                         Promise<> promise = Promise<>()) {
  return binlog_ptr->add(type, storer, std::move(promise));
}

inline uint64 binlog_rewrite(BinlogInterface *binlog_ptr, uint64 log_event_id, int32 type, const Storer &storer,
                             Promise<> promise = Promise<>()) {
  return binlog_ptr->rewrite(log_event_id, type, storer, std::move(promise));
}

inline uint64 binlog_erase(BinlogInterface *binlog_ptr, uint64 log_event_id, Promise<> promise = Promise<>()) {
  return binlog_ptr->erase(log_event_id, std::move(promise));
}

}  // namespace td
