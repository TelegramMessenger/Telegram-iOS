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
#include "td/utils/common.h"
#include "td/utils/HazardPointers.h"
#include "td/utils/logging.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/tests.h"

#include <atomic>

#if !TD_THREAD_UNSUPPORTED
TEST(HazardPointers, stress) {
  struct Node {
    std::atomic<std::string *> name_{nullptr};
    char pad[64];
  };
  int threads_n = 10;
  std::vector<Node> nodes(threads_n);
  td::HazardPointers<std::string> hazard_pointers(threads_n);
  std::vector<td::thread> threads(threads_n);
  int thread_id = 0;
  for (auto &thread : threads) {
    thread = td::thread([&, thread_id] {
      std::remove_reference_t<decltype(hazard_pointers)>::Holder holder(hazard_pointers, thread_id, 0);
      for (int i = 0; i < 1000000; i++) {
        auto &node = nodes[td::Random::fast(0, threads_n - 1)];
        auto *str = holder.protect(node.name_);
        if (str) {
          CHECK(*str == td::Slice("one") || *str == td::Slice("twotwo"));
        }
        holder.clear();
        if (td::Random::fast(0, 5) == 0) {
          std::string *new_str = new std::string(td::Random::fast(0, 1) == 0 ? "one" : "twotwo");
          if (node.name_.compare_exchange_strong(str, new_str, std::memory_order_acq_rel)) {
            hazard_pointers.retire(thread_id, str);
          } else {
            delete new_str;
          }
        }
      }
    });
    thread_id++;
  }
  for (auto &thread : threads) {
    thread.join();
  }
  LOG(ERROR) << "Undeleted pointers: " << hazard_pointers.to_delete_size_unsafe();
  CHECK(static_cast<int>(hazard_pointers.to_delete_size_unsafe()) <= threads_n * threads_n);
  for (int i = 0; i < threads_n; i++) {
    hazard_pointers.retire(i);
  }
  CHECK(hazard_pointers.to_delete_size_unsafe() == 0);
}
#endif  //!TD_THREAD_UNSUPPORTED
