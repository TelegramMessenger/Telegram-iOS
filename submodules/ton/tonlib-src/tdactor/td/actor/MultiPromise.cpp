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
#include "td/actor/MultiPromise.h"

#include <mutex>

namespace td {
namespace detail {
class MultiPromiseImpl {
 public:
  explicit MultiPromiseImpl(MultiPromise::Options options) : options_(options) {
  }
  ~MultiPromiseImpl() {
    for (auto &promise : pending_) {
      promise.set_value(Unit());
    }
  }

  void on_status(Status status) {
    if (status.is_ok() || options_.ignore_errors) {
      return;
    }
    std::vector<Promise<>> promises;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      if (pending_error_.is_ok()) {
        pending_error_ = status.clone();
        std::swap(promises, pending_);
      } else {
        CHECK(pending_.empty());
      }
    }
    for (auto &promise : promises) {
      promise.set_error(status.clone());
    }
  }
  void add_promise(Promise<> promise) {
    if (options_.ignore_errors) {
      pending_.push_back(std::move(promise));
    }
    Status status;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      if (pending_error_.is_error()) {
        status = pending_error_.clone();
      } else {
        pending_.push_back(std::move(promise));
      }
    }
    if (status.is_error()) {
      promise.set_error(std::move(status));
    }
  }

 private:
  std::mutex mutex_;
  std::vector<Promise<>> pending_;
  MultiPromise::Options options_;
  Status pending_error_;
};
}  // namespace detail
void MultiPromise::InitGuard::add_promise(Promise<> promise) {
  impl_->add_promise(std::move(promise));
}
Promise<> MultiPromise::InitGuard::get_promise() {
  return [impl = impl_](Result<Unit> result) {
    if (result.is_ok()) {
      impl->on_status(Status::OK());
    } else {
      impl->on_status(result.move_as_error());
    }
  };
}
bool MultiPromise::InitGuard::empty() const {
  return !impl_;
}
MultiPromise::InitGuard::operator bool() const {
  return !empty();
}
MultiPromise::InitGuard MultiPromise::init_guard() {
  CHECK(!impl_.lock());
  auto impl = std::make_shared<Impl>(options_);
  impl_ = impl;
  return InitGuard(std::move(impl));
}
MultiPromise::InitGuard MultiPromise::add_promise_or_init(Promise<> promise) {
  auto impl = impl_.lock();
  if (!impl) {
    auto guard = init_guard();
    guard.add_promise(std::move(promise));
    return guard;
  }
  impl->add_promise(std::move(promise));
  return {};
}
}  // namespace td
