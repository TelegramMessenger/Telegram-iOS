//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Heap.h"
#include "td/utils/Slice.h"
#include "td/utils/Time.h"

#include <set>

namespace td {

// TODO optimize
class MultiTimeout final : public Actor {
  struct Item final : public HeapNode {
    int64 key;

    explicit Item(int64 key) : key(key) {
    }

    bool operator<(const Item &other) const {
      return key < other.key;
    }
  };

 public:
  using Data = void *;
  using Callback = void (*)(Data, int64);
  explicit MultiTimeout(Slice name) {
    register_actor(name, this).release();
  }

  void set_callback(Callback callback) {
    callback_ = callback;
  }
  void set_callback_data(Data data) {
    data_ = data;
  }

  bool has_timeout(int64 key) const;

  void set_timeout_in(int64 key, double timeout) {
    set_timeout_at(key, Time::now() + timeout);
  }

  void add_timeout_in(int64 key, double timeout) {
    add_timeout_at(key, Time::now() + timeout);
  }

  void set_timeout_at(int64 key, double timeout);

  void add_timeout_at(int64 key, double timeout);  // memcache semantics, doesn't replace old timeout

  void cancel_timeout(int64 key, const char *source = "cancel_timeout");

  void run_all();

 private:
  friend class Scheduler;

  Callback callback_;
  Data data_;

  KHeap<double> timeout_queue_;
  std::set<Item> items_;

  void update_timeout(const char *source);

  void timeout_expired() final;

  vector<int64> get_expired_keys(double now);
};

}  // namespace td
