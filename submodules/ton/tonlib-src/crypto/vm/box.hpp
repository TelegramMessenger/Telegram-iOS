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
#include "vm/stack.hpp"

namespace vm {
using td::Ref;

class Box : public td::CntObject {
  mutable StackEntry data_;

 public:
  Box() = default;
  Box(const Box&) = default;
  Box(Box&&) = default;
  template <typename... Args>
  Box(Args... args) : data_{std::move(args...)} {
  }
  ~Box() override = default;
  Box(const StackEntry& data) : data_(data) {
  }
  Box(StackEntry&& data) : data_(std::move(data)) {
  }
  void operator=(const StackEntry& data) const {
    data_ = data;
  }
  void operator=(StackEntry&& data) const {
    data_ = data;
  }
  void set(const StackEntry& data) const {
    data_ = data;
  }
  void set(StackEntry&& data) const {
    data_ = data;
  }
  const StackEntry& get() const {
    return data_;
  }
  void clear() const {
    data_.clear();
  }
  bool empty() const {
    return data_.empty();
  }
};

}  // namespace vm
