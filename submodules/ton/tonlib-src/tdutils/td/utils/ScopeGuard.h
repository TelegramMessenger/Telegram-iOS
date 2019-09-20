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

#include <cstdlib>
#include <memory>
#include <type_traits>
#include <utility>

namespace td {

class Guard {
 public:
  Guard() = default;
  Guard(const Guard &other) = delete;
  Guard &operator=(const Guard &other) = delete;
  Guard(Guard &&other) = default;
  Guard &operator=(Guard &&other) = default;
  virtual ~Guard() = default;
  virtual void dismiss() {
    std::abort();
  }
};

template <class FunctionT>
class LambdaGuard : public Guard {
 public:
  explicit LambdaGuard(const FunctionT &func) : func_(func) {
  }
  explicit LambdaGuard(FunctionT &&func) : func_(std::move(func)) {
  }
  LambdaGuard(const LambdaGuard &other) = delete;
  LambdaGuard &operator=(const LambdaGuard &other) = delete;
  LambdaGuard(LambdaGuard &&other) : func_(std::move(other.func_)), dismissed_(other.dismissed_) {
    other.dismissed_ = true;
  }
  LambdaGuard &operator=(LambdaGuard &&other) = delete;

  void dismiss() {
    dismissed_ = true;
  }

  ~LambdaGuard() {
    if (!dismissed_) {
      func_();
    }
  }

 private:
  FunctionT func_;
  bool dismissed_ = false;
};

template <class F>
unique_ptr<Guard> create_lambda_guard(F &&f) {
  return make_unique<LambdaGuard<F>>(std::forward<F>(f));
}
template <class F>
std::shared_ptr<Guard> create_shared_lambda_guard(F &&f) {
  return std::make_shared<LambdaGuard<F>>(std::forward<F>(f));
}

enum class ScopeExit {};
template <class FunctionT>
auto operator+(ScopeExit, FunctionT &&func) {
  return LambdaGuard<std::decay_t<FunctionT>>(std::forward<FunctionT>(func));
}

}  // namespace td

#define SCOPE_EXIT auto TD_CONCAT(SCOPE_EXIT_VAR_, __LINE__) = ::td::ScopeExit() + [&]()
