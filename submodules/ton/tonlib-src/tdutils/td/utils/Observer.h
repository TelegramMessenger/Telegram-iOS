/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
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

class Observer : ObserverBase {
 public:
  Observer() = default;
  explicit Observer(unique_ptr<ObserverBase> &&ptr) : observer_ptr_(std::move(ptr)) {
  }

  void notify() override {
    if (observer_ptr_) {
      observer_ptr_->notify();
    }
  }

 private:
  unique_ptr<ObserverBase> observer_ptr_;
};

}  // namespace td
