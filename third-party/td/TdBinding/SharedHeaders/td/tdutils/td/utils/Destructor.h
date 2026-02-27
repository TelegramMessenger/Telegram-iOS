//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <memory>
#include <utility>

namespace td {

class Destructor {
 public:
  Destructor() = default;
  Destructor(const Destructor &) = delete;
  Destructor &operator=(const Destructor &) = delete;
  Destructor(Destructor &&) = default;
  Destructor &operator=(Destructor &&) = default;
  virtual ~Destructor() = default;
};

template <class F>
class LambdaDestructor final : public Destructor {
 public:
  explicit LambdaDestructor(F &&f) : f_(std::move(f)) {
  }
  LambdaDestructor(const LambdaDestructor &) = delete;
  LambdaDestructor &operator=(const LambdaDestructor &) = delete;
  LambdaDestructor(LambdaDestructor &&) = default;
  LambdaDestructor &operator=(LambdaDestructor &&) = default;
  ~LambdaDestructor() final {
    f_();
  }

 private:
  F f_;
};

template <class F>
auto create_destructor(F &&f) {
  return make_unique<LambdaDestructor<F>>(std::forward<F>(f));
}
template <class F>
auto create_shared_destructor(F &&f) {
  return std::make_shared<LambdaDestructor<F>>(std::forward<F>(f));
}

}  // namespace td
