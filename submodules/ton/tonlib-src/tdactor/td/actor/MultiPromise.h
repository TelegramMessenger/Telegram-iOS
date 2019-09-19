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
#include "td/actor/PromiseFuture.h"

namespace td {
namespace detail {
class MultiPromiseImpl;
}

class MultiPromise {
  using Impl = detail::MultiPromiseImpl;

 public:
  struct Options {
    Options() {
    }
    bool ignore_errors{false};
  };
  explicit MultiPromise(Options options = Options{}) : options_(options) {
  }

  struct InitGuard {
   public:
    InitGuard() = default;
    InitGuard(std::shared_ptr<Impl> impl) : impl_(std::move(impl)) {
    }
    InitGuard(InitGuard &&other) = default;
    InitGuard &operator=(InitGuard &&other) = default;
    InitGuard(const InitGuard &other) = delete;
    InitGuard &operator=(const InitGuard &other) = delete;

    void add_promise(Promise<> promise);
    Promise<> get_promise();
    bool empty() const;
    explicit operator bool() const;

   private:
    std::shared_ptr<Impl> impl_;
  };

  TD_WARN_UNUSED_RESULT InitGuard init_guard();
  TD_WARN_UNUSED_RESULT InitGuard add_promise_or_init(Promise<> promise);

 private:
  Options options_;
  std::weak_ptr<Impl> impl_;
};
}  // namespace td
