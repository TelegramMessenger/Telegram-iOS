//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/SeqKeyValue.h"

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/port/RwMutex.h"
#include "td/utils/Slice.h"

#include <utility>

namespace td {

class TsSeqKeyValue {
 public:
  using SeqNo = SeqKeyValue::SeqNo;
  TsSeqKeyValue() = default;
  explicit TsSeqKeyValue(SeqKeyValue kv) : kv_(std::move(kv)) {
  }

  TsSeqKeyValue(TsSeqKeyValue &&) = default;
  TsSeqKeyValue &operator=(TsSeqKeyValue &&) = default;
  TsSeqKeyValue(const TsSeqKeyValue &) = delete;
  TsSeqKeyValue &operator=(const TsSeqKeyValue &) = delete;
  ~TsSeqKeyValue() = default;

  SeqNo set(Slice key, Slice value) {
    auto lock = rw_mutex_.lock_write();
    return kv_.set(key, value);
  }

  std::pair<SeqNo, RwMutex::WriteLock> set_and_lock(Slice key, Slice value) {
    auto lock = rw_mutex_.lock_write();
    return std::make_pair(kv_.set(key, value), std::move(lock));
  }

  SeqNo erase(const string &key) {
    auto lock = rw_mutex_.lock_write();
    return kv_.erase(key);
  }

  SeqNo erase_batch(vector<string> keys) {
    auto lock = rw_mutex_.lock_write();
    return kv_.erase_batch(std::move(keys));
  }

  std::pair<SeqNo, RwMutex::WriteLock> erase_and_lock(const string &key) {
    auto lock = rw_mutex_.lock_write();
    return std::make_pair(kv_.erase(key), std::move(lock));
  }

  string get(const string &key) const {
    auto lock = rw_mutex_.lock_read();
    return kv_.get(key);
  }

  bool isset(const string &key) const {
    auto lock = rw_mutex_.lock_read();
    return kv_.isset(key);
  }

  size_t size() const {
    return kv_.size();
  }

  FlatHashMap<string, string> get_all() const {
    auto lock = rw_mutex_.lock_write();
    return kv_.get_all();
  }

  // non-thread-safe method
  SeqKeyValue &inner() {
    return kv_;
  }

  auto lock() {
    return rw_mutex_.lock_write();
  }

 private:
  mutable RwMutex rw_mutex_;
  SeqKeyValue kv_;
};

}  // namespace td
