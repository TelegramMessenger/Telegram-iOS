// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <atomic>

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

using jxl::test::ThreadPoolForTests;

namespace jpegxl {
namespace {

int PopulationCount(uint64_t bits) {
  int num_set = 0;
  while (bits != 0) {
    num_set += bits & 1;
    bits >>= 1;
  }
  return num_set;
}

// Ensures task parameter is in bounds, every parameter is reached,
// pool can be reused (multiple consecutive Run calls), pool can be destroyed
// (joining with its threads), num_threads=0 works (runs on current thread).
TEST(ThreadParallelRunnerTest, TestPool) {
  for (int num_threads = 0; num_threads <= 18; ++num_threads) {
    ThreadPoolForTests pool(num_threads);
    for (int num_tasks = 0; num_tasks < 32; ++num_tasks) {
      std::vector<int> mementos(num_tasks);
      for (int begin = 0; begin < 32; ++begin) {
        std::fill(mementos.begin(), mementos.end(), 0);
        EXPECT_TRUE(RunOnPool(
            &pool, begin, begin + num_tasks, jxl::ThreadPool::NoInit,
            [begin, num_tasks, &mementos](const int task, const int thread) {
              // Parameter is in the given range
              EXPECT_GE(task, begin);
              EXPECT_LT(task, begin + num_tasks);

              // Store mementos to be sure we visited each task.
              mementos.at(task - begin) = 1000 + task;
            },
            "TestPool"));
        for (int task = begin; task < begin + num_tasks; ++task) {
          EXPECT_EQ(1000 + task, mementos.at(task - begin));
        }
      }
    }
  }
}

// Verify "thread" parameter when processing few tasks.
TEST(ThreadParallelRunnerTest, TestSmallAssignments) {
  const int kMaxThreads = 8;
  for (int num_threads = 1; num_threads <= kMaxThreads; ++num_threads) {
    ThreadPoolForTests pool(num_threads);

    // (Avoid mutex because it may perturb the worker thread scheduling)
    std::atomic<uint64_t> id_bits{0};
    std::atomic<int> num_calls{0};

    EXPECT_TRUE(RunOnPool(
        &pool, 0, num_threads, jxl::ThreadPool::NoInit,
        [&num_calls, num_threads, &id_bits](const int task, const int thread) {
          num_calls.fetch_add(1, std::memory_order_relaxed);

          EXPECT_LT(thread, num_threads);
          uint64_t bits = id_bits.load(std::memory_order_relaxed);
          while (
              !id_bits.compare_exchange_weak(bits, bits | (1ULL << thread))) {
          }
        },
        "TestSmallAssignments"));

    // Correct number of tasks.
    EXPECT_EQ(num_threads, num_calls.load());

    const int num_participants = PopulationCount(id_bits.load());
    // Can't expect equality because other workers may have woken up too late.
    EXPECT_LE(num_participants, num_threads);
  }
}

struct Counter {
  Counter() {
    // Suppress "unused-field" warning.
    (void)padding;
  }
  void Assimilate(const Counter& victim) { counter += victim.counter; }
  int counter = 0;
  int padding[31];
};

TEST(ThreadParallelRunnerTest, TestCounter) {
  const int kNumThreads = 12;
  ThreadPoolForTests pool(kNumThreads);
  alignas(128) Counter counters[kNumThreads];

  const int kNumTasks = kNumThreads * 19;
  EXPECT_TRUE(RunOnPool(
      &pool, 0, kNumTasks, jxl::ThreadPool::NoInit,
      [&counters](const int task, const int thread) {
        counters[thread].counter += task;
      },
      "TestCounter"));

  int expected = 0;
  for (int i = 0; i < kNumTasks; ++i) {
    expected += i;
  }

  for (int i = 1; i < kNumThreads; ++i) {
    counters[0].Assimilate(counters[i]);
  }
  EXPECT_EQ(expected, counters[0].counter);
}

}  // namespace
}  // namespace jpegxl
