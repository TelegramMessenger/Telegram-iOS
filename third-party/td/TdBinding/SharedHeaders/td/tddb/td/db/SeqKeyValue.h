//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Slice.h"

namespace td {

class SeqKeyValue {
 public:
  using SeqNo = uint64;
  SeqKeyValue() = default;
  SeqKeyValue(SeqKeyValue &&) = default;
  SeqKeyValue &operator=(SeqKeyValue &&) = default;
  SeqKeyValue(const SeqKeyValue &) = delete;
  SeqKeyValue &operator=(const SeqKeyValue &) = delete;
  ~SeqKeyValue() = default;

  SeqNo set(Slice key, Slice value) {
    CHECK(!key.empty());
    auto it_ok = map_.emplace(key.str(), value.str());
    if (!it_ok.second) {
      if (it_ok.first->second == value) {
        return 0;
      }
      it_ok.first->second = value.str();
    }
    return next_seq_no();
  }

  SeqNo erase(const string &key) {
    auto it = map_.find(key);
    if (it == map_.end()) {
      return 0;
    }
    map_.erase(it);
    return next_seq_no();
  }

  SeqNo erase_batch(vector<string> keys) {
    size_t count = 0;
    for (auto &key : keys) {
      auto it = map_.find(key);
      if (it != map_.end()) {
        map_.erase(it);
        count++;
      }
    }
    if (count == 0) {
      return 0;
    }
    SeqNo result = current_id_ + 1;
    current_id_ += count;
    return result;
  }

  SeqNo seq_no() const {
    return current_id_ + 1;
  }

  string get(const string &key) const {
    auto it = map_.find(key);
    if (it == map_.end()) {
      return string();
    }
    return it->second;
  }

  bool isset(const string &key) const {
    auto it = map_.find(key);
    if (it == map_.end()) {
      return false;
    }
    return true;
  }

  size_t size() const {
    return map_.size();
  }

  FlatHashMap<string, string> get_all() const {
    FlatHashMap<string, string> result;
    result.reserve(map_.size());
    for (auto &it : map_) {
      result.emplace(it.first, it.second);
    }
    return result;
  }

 private:
  FlatHashMap<string, string> map_;
  SeqNo current_id_ = 0;

  SeqNo next_seq_no() {
    return ++current_id_;
  }
};

}  // namespace td
