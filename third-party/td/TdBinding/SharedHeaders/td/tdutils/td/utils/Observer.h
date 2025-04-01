//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

class ObserverBase {
 public:
  ObserverBase() = default;
  ObserverBase(const ObserverBase &) = delete;
  ObserverBase &operator=(const ObserverBase &) = delete;
  ObserverBase(ObserverBase &&) = delete;
  ObserverBase &operator=(ObserverBase &&) = delete;
  virtual ~ObserverBase() = default;

  virtual void notify() = 0;
};

class Observer final : private ObserverBase {
 public:
  Observer() = default;
  explicit Observer(unique_ptr<ObserverBase> &&ptr) : observer_ptr_(std::move(ptr)) {
  }

  void notify() final {
    if (observer_ptr_) {
      observer_ptr_->notify();
    }
  }

 private:
  unique_ptr<ObserverBase> observer_ptr_;
};

}  // namespace td
