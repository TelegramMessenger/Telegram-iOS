//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
  Guard(const Guard &) = delete;
  Guard &operator=(const Guard &) = delete;
  Guard(Guard &&) = default;
  Guard &operator=(Guard &&) = default;
  virtual ~Guard() = default;
  virtual void dismiss() {
    std::abort();
  }
};

template <class FunctionT>
class LambdaGuard final : public Guard {
 public:
  explicit LambdaGuard(const FunctionT &func) : func_(func) {
  }
  explicit LambdaGuard(FunctionT &&func) : func_(std::move(func)) {
  }
  LambdaGuard(const LambdaGuard &) = delete;
  LambdaGuard &operator=(const LambdaGuard &) = delete;
  LambdaGuard(LambdaGuard &&other) : func_(std::move(other.func_)), dismissed_(other.dismissed_) {
    other.dismissed_ = true;
  }
  LambdaGuard &operator=(LambdaGuard &&) = delete;

  void dismiss() final {
    dismissed_ = true;
  }

  ~LambdaGuard() final {
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

#define SCOPE_EXIT auto TD_CONCAT(SCOPE_EXIT_VAR_, __LINE__) = ::td::ScopeExit() + [&]
