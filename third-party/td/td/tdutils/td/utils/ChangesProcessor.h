//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <utility>

namespace td {

// Process changes after they are finished in order of addition
template <class DataT>
class ChangesProcessor {
 public:
  using Id = uint64;

  void clear() {
    offset_ += data_array_.size();
    ready_i_ = 0;
    data_array_.clear();
  }

  template <class FromDataT>
  Id add(FromDataT &&data) {
    auto res = offset_ + data_array_.size();
    data_array_.emplace_back(std::forward<DataT>(data), false);
    return static_cast<Id>(res);
  }

  template <class F>
  void finish(Id token, F &&func) {
    size_t pos = static_cast<size_t>(token) - offset_;
    if (pos >= data_array_.size()) {
      return;
    }
    data_array_[pos].second = true;
    while (ready_i_ < data_array_.size() && data_array_[ready_i_].second) {
      func(std::move(data_array_[ready_i_].first));
      ready_i_++;
    }
    try_compactify();
  }

 private:
  size_t offset_ = 1;
  size_t ready_i_ = 0;
  std::vector<std::pair<DataT, bool>> data_array_;
  void try_compactify() {
    if (ready_i_ > 5 && ready_i_ * 2 > data_array_.size()) {
      data_array_.erase(data_array_.begin(), data_array_.begin() + ready_i_);
      offset_ += ready_i_;
      ready_i_ = 0;
    }
  }
};

}  // namespace td
