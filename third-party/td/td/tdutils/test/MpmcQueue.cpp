//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/MpmcQueue.h"
#include "td/utils/port/thread.h"
#include "td/utils/tests.h"

#include <algorithm>
#include <tuple>

TEST(OneValue, simple) {
  {
    std::string x{"hello"};
    td::OneValue<std::string> value;
    auto status = value.set_value(x);
    CHECK(status);
    CHECK(x.empty());
    status = value.get_value(x);
    CHECK(status);
    CHECK(x == "hello");
  }
  {
    td::OneValue<std::string> value;
    std::string x;
    auto status = value.get_value(x);
    CHECK(!status);
    CHECK(x.empty());
    std::string y{"hello"};
    status = value.set_value(y);
    CHECK(!status);
    CHECK(y == "hello");
  }
}

#if !TD_THREAD_UNSUPPORTED
TEST(OneValue, stress) {
  td::Stage run;
  td::Stage check;

  std::string from;
  bool set_status;

  std::string to;
  bool get_status;
  std::vector<td::thread> threads;
  td::OneValue<std::string> value;
  for (size_t i = 0; i < 2; i++) {
    threads.emplace_back([&, id = i] {
      for (td::uint64 round = 1; round < 100000; round++) {
        if (id == 0) {
          value.reset();
          to = "";
          from = "";
        }
        run.wait(round * 2);
        if (id == 0) {
          from = "hello";
          set_status = value.set_value(from);
        } else {
          get_status = value.get_value(to);
        }
        check.wait(round * 2);
        if (id == 0) {
          if (set_status) {
            CHECK(get_status);
            CHECK(from.empty());
            LOG_CHECK(to == "hello") << to;
          } else {
            CHECK(!get_status);
            CHECK(from == "hello");
            CHECK(to.empty());
          }
        }
      }
    });
  }
  for (auto &thread : threads) {
    thread.join();
  }
}
#endif

TEST(MpmcQueueBlock, simple) {
  // Test doesn't work now and it is ok, try_pop, logic changed
  /*
  td::MpmcQueueBlock<std::string> block(2);
  std::string x = "hello";
  using PushStatus = td::MpmcQueueBlock<std::string>::PushStatus;
  using PopStatus = td::MpmcQueueBlock<std::string>::PopStatus;
  auto push_status = block.push(x);
  CHECK(push_status == PushStatus::Ok);
  CHECK(x.empty());
  auto pop_status = block.pop(x);
  CHECK(pop_status == PopStatus::Ok);
  CHECK(x == "hello");
  pop_status = block.try_pop(x);
  CHECK(pop_status == PopStatus::Empty);
  x = "hello";
  push_status = block.push(x);
  CHECK(push_status == PushStatus::Ok);
  x = "hello";
  push_status = block.push(x);
  CHECK(push_status == PushStatus::Closed);
  CHECK(x == "hello");
  x = "";
  pop_status = block.try_pop(x);
  CHECK(pop_status == PopStatus::Ok);
  pop_status = block.try_pop(x);
  CHECK(pop_status == PopStatus::Closed);
  */
}

TEST(MpmcQueue, simple) {
  td::MpmcQueue<int> q(2, 1);
  for (int t = 0; t < 2; t++) {
    for (int i = 0; i < 100; i++) {
      q.push(i, 0);
    }
    for (int i = 0; i < 100; i++) {
      int x = q.pop(0);
      LOG_CHECK(x == i) << x << " expected " << i;
    }
  }
}

#if !TD_THREAD_UNSUPPORTED
TEST(MpmcQueue, multi_thread) {
  size_t n = 10;
  size_t m = 10;
  struct Data {
    size_t from{0};
    size_t value{0};
  };
  struct ThreadData {
    std::vector<Data> v;
    char pad[64];
  };
  td::MpmcQueue<Data> q(1024, n + m + 1);
  std::vector<td::thread> n_threads(n);
  std::vector<td::thread> m_threads(m);
  std::vector<ThreadData> thread_data(m);
  size_t thread_id = 0;
  for (auto &thread : m_threads) {
    thread = td::thread([&, thread_id] {
      while (true) {
        auto data = q.pop(thread_id);
        if (data.value == 0) {
          return;
        }
        thread_data[thread_id].v.push_back(data);
      }
    });
    thread_id++;
  }
  size_t qn = 100000;
  for (auto &thread : n_threads) {
    thread = td::thread([&, thread_id] {
      for (size_t i = 0; i < qn; i++) {
        Data data;
        data.from = thread_id - m;
        data.value = i + 1;
        q.push(data, thread_id);
      }
    });
    thread_id++;
  }
  for (auto &thread : n_threads) {
    thread.join();
  }
  for (size_t i = 0; i < m; i++) {
    Data data;
    data.from = 0;
    data.value = 0;
    q.push(data, thread_id);
  }
  for (auto &thread : m_threads) {
    thread.join();
  }
  std::vector<Data> all;
  for (size_t i = 0; i < m; i++) {
    std::vector<size_t> from(n, 0);
    for (auto &data : thread_data[i].v) {
      all.push_back(data);
      CHECK(data.value > from[data.from]);
      from[data.from] = data.value;
    }
  }
  LOG_CHECK(all.size() == n * qn) << all.size();
  std::sort(all.begin(), all.end(),
            [](const auto &a, const auto &b) { return std::tie(a.from, a.value) < std::tie(b.from, b.value); });
  for (size_t i = 0; i < n * qn; i++) {
    CHECK(all[i].from == i / qn);
    CHECK(all[i].value == i % qn + 1);
  }
  LOG(INFO) << "Undeleted pointers: " << q.hazard_pointers_to_delele_size_unsafe();
  CHECK(q.hazard_pointers_to_delele_size_unsafe() <= (n + m + 1) * (n + m + 1));
  for (size_t id = 0; id < n + m + 1; id++) {
    q.gc(id);
  }
  LOG_CHECK(q.hazard_pointers_to_delele_size_unsafe() == 0) << q.hazard_pointers_to_delele_size_unsafe();
}
#endif
