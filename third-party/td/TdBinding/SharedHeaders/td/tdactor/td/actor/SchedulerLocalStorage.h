//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/optional.h"

#include <functional>

namespace td {

template <class T>
class SchedulerLocalStorage {
 public:
  SchedulerLocalStorage() : data_(Scheduler::instance()->sched_count()) {
  }
  T &get() {
    return data_[Scheduler::instance()->sched_id()];
  }
  template <class F>
  void for_each(F &&f) {
    for (auto &value : data_) {
      f(value);
    }
  }
  template <class F>
  void for_each(F &&f) const {
    for (const auto &value : data_) {
      f(value);
    }
  }

 private:
  std::vector<T> data_;
};

template <class T>
class LazySchedulerLocalStorage {
 public:
  LazySchedulerLocalStorage() = default;
  explicit LazySchedulerLocalStorage(std::function<T()> create_func) : create_func_(std::move(create_func)) {
  }
  void set_create_func(std::function<T()> create_func) {
    CHECK(!create_func_);
    create_func_ = create_func;
  }

  void set(T &&t) {
    auto &optional_value_ = sls_optional_value_.get();
    CHECK(!optional_value_);
    optional_value_ = std::move(t);
  }

  T &get() {
    auto &optional_value_ = sls_optional_value_.get();
    if (!optional_value_) {
      CHECK(create_func_);
      optional_value_ = create_func_();
    }
    return *optional_value_;
  }
  void clear_values() {
    sls_optional_value_.for_each([&](auto &optional_value) {
      if (optional_value) {
        optional_value = optional<T>();
      }
    });
  }

 private:
  std::function<T()> create_func_;
  SchedulerLocalStorage<optional<T>> sls_optional_value_;
};

}  // namespace td
