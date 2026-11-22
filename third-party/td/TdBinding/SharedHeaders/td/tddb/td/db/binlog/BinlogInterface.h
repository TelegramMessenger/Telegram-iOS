//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/binlog/BinlogEvent.h"
#include "td/db/DbKey.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/StorerBase.h"

namespace td {

class BinlogInterface {
 public:
  BinlogInterface() = default;
  BinlogInterface(const BinlogInterface &) = delete;
  BinlogInterface &operator=(const BinlogInterface &) = delete;
  BinlogInterface(BinlogInterface &&) = delete;
  BinlogInterface &operator=(BinlogInterface &&) = delete;
  virtual ~BinlogInterface() = default;

  void close(Promise<> promise = {}) {
    close_impl(std::move(promise));
  }
  void close_and_destroy(Promise<> promise = {}) {
    close_and_destroy_impl(std::move(promise));
  }
  void add_raw_event(BinlogDebugInfo info, uint64 event_id, BufferSlice &&raw_event, Promise<> promise = Promise<>()) {
    add_raw_event_impl(event_id, std::move(raw_event), std::move(promise), info);
  }
  void add_raw_event(uint64 event_id, BufferSlice &&raw_event, Promise<> promise = Promise<>()) {
    add_raw_event_impl(event_id, std::move(raw_event), std::move(promise), {});
  }
  void lazy_sync(Promise<> promise = Promise<>()) {
    add_raw_event_impl(next_event_id(), BufferSlice(), std::move(promise), {});
  }

  uint64 add(int32 type, const Storer &storer, Promise<> promise = Promise<>()) {
    auto event_id = next_event_id();
    add_raw_event_impl(event_id, BinlogEvent::create_raw(event_id, type, 0, storer), std::move(promise), {});
    return event_id;
  }

  uint64 rewrite(uint64 event_id, int32 type, const Storer &storer, Promise<> promise = Promise<>()) {
    auto seq_no = next_event_id();
    add_raw_event_impl(seq_no, BinlogEvent::create_raw(event_id, type, BinlogEvent::Flags::Rewrite, storer),
                       std::move(promise), {});
    return seq_no;
  }

  uint64 erase(uint64 event_id, Promise<> promise = Promise<>()) {
    auto seq_no = next_event_id();
    add_raw_event_impl(
        seq_no,
        BinlogEvent::create_raw(event_id, BinlogEvent::ServiceTypes::Empty, BinlogEvent::Flags::Rewrite, EmptyStorer()),
        std::move(promise), {});
    return seq_no;
  }

  virtual uint64 erase_batch(vector<uint64> event_ids) {
    if (event_ids.empty()) {
      return 0;
    }
    uint64 seq_no = next_event_id(0);
    for (auto event_id : event_ids) {
      erase(event_id);
    }
    return seq_no;
  }

  virtual void force_sync(Promise<> promise, const char *source) = 0;
  virtual void force_flush() = 0;
  virtual void change_key(DbKey db_key, Promise<> promise) = 0;

  virtual uint64 next_event_id() = 0;
  virtual uint64 next_event_id(int32 shift) = 0;

 protected:
  virtual void close_impl(Promise<> promise) = 0;
  virtual void close_and_destroy_impl(Promise<> promise) = 0;
  virtual void add_raw_event_impl(uint64 seq_no, BufferSlice &&raw_event, Promise<> promise, BinlogDebugInfo info) = 0;
};

}  // namespace td
