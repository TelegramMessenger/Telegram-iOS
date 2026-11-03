//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/WaitFreeVector.h"

#include <limits>
#include <map>
#include <tuple>

namespace td {

template <class ValueT>
class Enumerator {
 public:
  using Key = int32;

  Key add(ValueT v) {
    CHECK(arr_.size() < static_cast<size_t>(std::numeric_limits<int32>::max() - 1));
    auto next_id = static_cast<int32>(arr_.size() + 1);
    bool was_inserted;
    decltype(map_.begin()) it;
    std::tie(it, was_inserted) = map_.emplace(std::move(v), next_id);
    if (was_inserted) {
      arr_.push_back(&it->first);
    }
    return it->second;
  }

  const ValueT &get(Key key) const {
    auto pos = static_cast<size_t>(key - 1);
    CHECK(pos < arr_.size());
    return *arr_[pos];
  }

  size_t size() const {
    CHECK(map_.size() == arr_.size());
    return arr_.size();
  }

  bool empty() const {
    return size() == 0;
  }

 private:
  std::map<ValueT, int32> map_;
  WaitFreeVector<const ValueT *> arr_;
};

}  // namespace td
