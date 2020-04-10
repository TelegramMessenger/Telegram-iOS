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
#include "refcnt.hpp"

#include "td/utils/ScopeGuard.h"

namespace td {
namespace detail {
struct SafeDeleter {
 public:
  void retire(const CntObject *ptr) {
    if (is_active_) {
      to_delete_.push_back(ptr);
      return;
    }
    is_active_ = true;
    SCOPE_EXIT {
      is_active_ = false;
    };
    delete ptr;
    while (!to_delete_.empty()) {
      auto *ptr = to_delete_.back();
      to_delete_.pop_back();
      delete ptr;
    }
  }

 private:
  std::vector<const CntObject *> to_delete_;
  bool is_active_{false};
};

TD_THREAD_LOCAL SafeDeleter *deleter;
void safe_delete(const CntObject *ptr) {
  init_thread_local<SafeDeleter>(deleter);
  deleter->retire(ptr);
}
}  // namespace detail
}  // namespace td
