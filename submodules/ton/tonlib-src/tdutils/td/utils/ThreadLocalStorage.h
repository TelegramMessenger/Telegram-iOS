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

#include "td/utils/port/thread.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/int_types.h"

#include <atomic>
#include <array>

namespace td {
template <class T>
class ThreadLocalStorage {
 public:
  T& get() {
    return thread_local_node().value;
  }

  template <class F>
  void for_each(F&& f) {
    int n = max_thread_id_.load();
    for (int i = 0; i < n; i++) {
      f(nodes_[i].value);
    }
  }
  template <class F>
  void for_each(F&& f) const {
    int n = max_thread_id_.load();
    for (int i = 0; i < n; i++) {
      f(nodes_[i].value);
    }
  }

 private:
  struct Node {
    T value{};
    char padding[128];
  };
  static constexpr int MAX_THREAD_ID = 128;
  std::atomic<int> max_thread_id_{MAX_THREAD_ID};
  std::array<Node, MAX_THREAD_ID> nodes_;

  Node& thread_local_node() {
    auto thread_id = get_thread_id();
    CHECK(0 <= thread_id && static_cast<size_t>(thread_id) < nodes_.size());
    return nodes_[thread_id];
  }
};
}  // namespace td
