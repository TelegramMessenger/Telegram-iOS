//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/AtomicRead.h"
#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/MpmcQueue.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StealingQueue.h"
#include "td/utils/tests.h"

#include <atomic>
#include <cstring>

TEST(StealingQueue, very_simple) {
  td::StealingQueue<int, 8> q;
  q.local_push(1, [](auto x) { UNREACHABLE(); });
  int x;
  CHECK(q.local_pop(x));
  ASSERT_EQ(1, x);
}

#if !TD_THREAD_UNSUPPORTED
TEST(AtomicRead, simple) {
  td::Stage run;
  td::Stage check;

  std::size_t threads_n = 10;
  td::vector<td::thread> threads;

  int x{0};
  std::atomic<int> version{0};

  td::int64 res = 0;
  for (std::size_t i = 0; i < threads_n; i++) {
    threads.emplace_back([&, id = static_cast<td::uint32>(i)] {
      for (td::uint64 round = 1; round < 10000; round++) {
        run.wait(round * threads_n);
        if (id == 0) {
          version++;
          x++;
          version++;
        } else {
          int y = 0;
          auto v1 = version.load();
          y = x;
          auto v2 = version.load();
          if (v1 == v2 && v1 % 2 == 0) {
            res += y;
          }
        }

        check.wait(round * threads_n);
      }
    });
  }
  td::do_not_optimize_away(res);
  for (auto &thread : threads) {
    thread.join();
  }
}

TEST(AtomicRead, simple2) {
  td::Stage run;
  td::Stage check;

  std::size_t threads_n = 10;
  td::vector<td::thread> threads;

  struct Value {
    td::uint64 value = 0;
    char str[50] = "0 0 0 0";
  };
  td::AtomicRead<Value> value;

  auto to_str = [](td::uint64 i) {
    return PSTRING() << i << " " << i << " " << i << " " << i;
  };
  for (std::size_t i = 0; i < threads_n; i++) {
    threads.emplace_back([&, id = static_cast<td::uint32>(i)] {
      for (td::uint64 round = 1; round < 10000; round++) {
        run.wait(round * threads_n);
        if (id == 0) {
          auto x = value.lock();
          x->value = round;
          auto str = to_str(round);
          std::memcpy(x->str, str.c_str(), str.size() + 1);
        } else {
          Value x;
          value.read(x);
          LOG_CHECK(x.value == round || x.value == round - 1) << x.value << " " << round;
          CHECK(x.str == to_str(x.value));
        }
        check.wait(round * threads_n);
      }
    });
  }
  for (auto &thread : threads) {
    thread.join();
  }
}

TEST(StealingQueue, simple) {
  td::uint64 sum = 0;
  std::atomic<td::uint64> check_sum{0};

  td::Stage run;
  td::Stage check;

  std::size_t threads_n = 10;
  td::vector<td::thread> threads;
  td::vector<td::StealingQueue<int, 8>> lq(threads_n);
  td::MpmcQueue<int> gq(threads_n);

  constexpr td::uint64 XN = 20;
  td::uint64 x_sum[XN];
  x_sum[0] = 0;
  x_sum[1] = 1;
  for (td::uint64 i = 2; i < XN; i++) {
    x_sum[i] = i + x_sum[i - 1] + x_sum[i - 2];
  }

  td::Random::Xorshift128plus rnd(123);
  for (std::size_t i = 0; i < threads_n; i++) {
    threads.emplace_back([&, id = static_cast<td::uint32>(i)] {
      for (td::uint64 round = 1; round < 1000; round++) {
        if (id == 0) {
          sum = 0;
          auto n = static_cast<int>(rnd() % 5);
          for (int j = 0; j < n; j++) {
            auto x = static_cast<int>(rnd() % XN);
            sum += x_sum[x];
            gq.push(x, id);
          }
          check_sum = 0;
        }
        run.wait(round * threads_n);
        while (check_sum.load() != sum) {
          auto x = [&] {
            int res;
            if (lq[id].local_pop(res)) {
              return res;
            }
            if (gq.try_pop(res, id)) {
              return res;
            }
            if (lq[id].steal(res, lq[static_cast<size_t>(rnd()) % threads_n])) {
              //LOG(ERROR) << "STEAL";
              return res;
            }
            return 0;
          }();
          if (x == 0) {
            continue;
          }
          //LOG(ERROR) << x << " " << check_sum.load() << " " << sum;
          check_sum.fetch_add(x, std::memory_order_relaxed);
          lq[id].local_push(x - 1, [&](auto y) {
            //LOG(ERROR) << "OVERFLOW";
            gq.push(y, id);
          });
          if (x > 1) {
            lq[id].local_push(x - 2, [&](auto y) { gq.push(y, id); });
          }
        }
        check.wait(round * threads_n);
      }
    });
  }
  for (auto &thread : threads) {
    thread.join();
  }
}
#endif
