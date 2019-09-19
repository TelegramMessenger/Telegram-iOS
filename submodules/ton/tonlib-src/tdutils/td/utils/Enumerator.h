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
#include "td/utils/misc.h"

#include <map>
#include <tuple>

namespace td {

template <class ValueT>
class Enumerator {
 public:
  using Key = int32;

  Key add(ValueT v) {
    int32 next_id = narrow_cast<int32>(arr_.size() + 1);
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

 private:
  std::map<ValueT, int32> map_;
  std::vector<const ValueT *> arr_;
};

}  // namespace td
