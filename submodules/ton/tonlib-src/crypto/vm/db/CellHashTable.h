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

#include "td/utils/Slice.h"

#include <set>

namespace vm {
template <class InfoT>
class CellHashTable {
 public:
  template <class F>
  InfoT &apply(td::Slice hash, F &&f) {
    auto it = set_.find(hash);
    if (it != set_.end()) {
      auto &res = const_cast<InfoT &>(*it);
      f(res);
      return res;
    }
    InfoT info;
    f(info);
    auto &res = const_cast<InfoT &>(*(set_.insert(std::move(info)).first));
    return res;
  }

  template <class F>
  void for_each(F &&f) {
    for (auto &info : set_) {
      f(info);
    }
  }
  template <class F>
  void filter(F &&f) {
    for (auto it = set_.begin(); it != set_.end();) {
      if (f(*it)) {
        it++;
      } else {
        it = set_.erase(it);
      }
    }
  }
  void erase(td::Slice hash) {
    auto it = set_.find(hash);
    CHECK(it != set_.end());
    set_.erase(it);
  }
  size_t size() const {
    return set_.size();
  }

 private:
  std::set<InfoT, std::less<>> set_;
};
}  // namespace vm
