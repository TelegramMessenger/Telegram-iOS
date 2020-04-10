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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/common.h"

#include <memory>
#include <utility>

namespace td {

class Destructor {
 public:
  Destructor() = default;
  Destructor(const Destructor &other) = delete;
  Destructor &operator=(const Destructor &other) = delete;
  Destructor(Destructor &&other) = default;
  Destructor &operator=(Destructor &&other) = default;
  virtual ~Destructor() = default;
};

template <class F>
class LambdaDestructor : public Destructor {
 public:
  explicit LambdaDestructor(F &&f) : f_(std::move(f)) {
  }
  LambdaDestructor(const LambdaDestructor &other) = delete;
  LambdaDestructor &operator=(const LambdaDestructor &other) = delete;
  LambdaDestructor(LambdaDestructor &&other) = default;
  LambdaDestructor &operator=(LambdaDestructor &&other) = default;
  ~LambdaDestructor() override {
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
