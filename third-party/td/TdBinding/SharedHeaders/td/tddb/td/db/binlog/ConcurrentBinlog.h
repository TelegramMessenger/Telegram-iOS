//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/binlog/Binlog.h"
#include "td/db/binlog/BinlogInterface.h"
#include "td/db/DbKey.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <atomic>
#include <functional>

namespace td {

namespace detail {
class BinlogActor;
}  // namespace detail

class ConcurrentBinlog final : public BinlogInterface {
 public:
  using Callback = std::function<void(const BinlogEvent &)>;
  Result<BinlogInfo> init(string path, const Callback &callback, DbKey db_key = DbKey::empty(),
                          DbKey old_db_key = DbKey::empty(), int scheduler_id = -1) TD_WARN_UNUSED_RESULT;

  ConcurrentBinlog();
  explicit ConcurrentBinlog(unique_ptr<Binlog> binlog, int scheduler_id = -1);
  ConcurrentBinlog(const ConcurrentBinlog &) = delete;
  ConcurrentBinlog &operator=(const ConcurrentBinlog &) = delete;
  ConcurrentBinlog(ConcurrentBinlog &&) = delete;
  ConcurrentBinlog &operator=(ConcurrentBinlog &&) = delete;
  ~ConcurrentBinlog() final;

  void force_sync(Promise<> promise, const char *source) final;
  void force_flush() final;
  void change_key(DbKey db_key, Promise<> promise) final;

  uint64 next_event_id() final {
    return last_event_id_.fetch_add(1, std::memory_order_relaxed);
  }
  uint64 next_event_id(int32 shift) final {
    return last_event_id_.fetch_add(shift, std::memory_order_relaxed);
  }

  CSlice get_path() const {
    return path_;
  }

  uint64 erase_batch(vector<uint64> event_ids) final;

 private:
  void init_impl(unique_ptr<Binlog> binlog, int scheduler_id);
  void close_impl(Promise<> promise) final;
  void close_and_destroy_impl(Promise<> promise) final;
  void add_raw_event_impl(uint64 event_id, BufferSlice &&raw_event, Promise<> promise, BinlogDebugInfo info) final;

  ActorOwn<detail::BinlogActor> binlog_actor_;
  string path_;
  std::atomic<uint64> last_event_id_{0};
};

}  // namespace td
