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
#include "td/utils/Context.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/thread.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <atomic>
#include <utility>

#define REGISTER_TESTS(x)                \
  void TD_CONCAT(register_tests_, x)() { \
  }
#define DESC_TESTS(x) void TD_CONCAT(register_tests_, x)()
#define LOAD_TESTS(x) TD_CONCAT(register_tests_, x)()

namespace td {

class RandomSteps {
 public:
  struct Step {
    std::function<void()> func;
    td::uint32 weight;
  };
  RandomSteps(std::vector<Step> steps) : steps_(std::move(steps)) {
    for (auto &step : steps_) {
      steps_sum_ += step.weight;
    }
  }
  template <class Random>
  void step(Random &rnd) {
    auto w = rnd() % steps_sum_;
    for (auto &step : steps_) {
      if (w < step.weight) {
        step.func();
        break;
      }
      w -= step.weight;
    }
  }

 private:
  std::vector<Step> steps_;
  td::int32 steps_sum_ = 0;
};

class RegressionTester {
 public:
  virtual ~RegressionTester() = default;
  static void destroy(CSlice db_path);
  static unique_ptr<RegressionTester> create(string db_path, string db_cache_dir = "");

  virtual Status verify_test(Slice name, Slice result) = 0;
  virtual void save_db() = 0;
};

class Test {
 public:
  virtual ~Test() = default;
  virtual void run() {
    while (step()) {
    }
  }
  virtual bool step() {
    run();
    return false;
  }
  Test() = default;
  Test(const Test &) = delete;
  Test &operator=(const Test &) = delete;
  Test(Test &&) = delete;
  Test &operator=(Test &&) = delete;
};

class TestContext : public Context<TestContext> {
 public:
  virtual ~TestContext() = default;
  virtual Slice name() = 0;
  virtual Status verify(Slice data) = 0;
};

class TestsRunner : public TestContext {
 public:
  static TestsRunner &get_default();

  void add_test(string name, unique_ptr<Test> test);
  void add_substr_filter(string str);
  void set_stress_flag(bool flag);
  void run_all();
  bool run_all_step();
  void set_regression_tester(unique_ptr<RegressionTester> regression_tester);

 private:
  struct State {
    size_t it{0};
    bool is_running = false;
    double start{0};
    size_t end{0};
  };
  bool stress_flag_{false};
  vector<string> substr_filters_;
  vector<std::pair<string, unique_ptr<Test>>> tests_;
  State state_;
  unique_ptr<RegressionTester> regression_tester_;

  Slice name() override;
  Status verify(Slice data) override;
};

template <class T>
class RegisterTest {
 public:
  RegisterTest(string name, TestsRunner &runner = TestsRunner::get_default()) {
    runner.add_test(name, make_unique<T>());
  }
};

class Stage {
 public:
  void wait(uint64 need) {
    value_.fetch_add(1, std::memory_order_release);
    while (value_.load(std::memory_order_acquire) < need) {
      td::this_thread::yield();
    }
  };

 private:
  std::atomic<uint64> value_{0};
};

inline string rand_string(char from, char to, int len) {
  string res(len, 0);
  for (auto &c : res) {
    c = static_cast<char>(Random::fast(from, to));
  }
  return res;
}

inline vector<string> rand_split(Slice str) {
  vector<string> res;
  size_t pos = 0;
  while (pos < str.size()) {
    size_t len;
    if (Random::fast(0, 1) == 1) {
      len = Random::fast(1, 10);
    } else {
      len = Random::fast(100, 200);
    }
    res.push_back(str.substr(pos, len).str());
    pos += len;
  }
  return res;
}

template <class T1, class T2>
void assert_eq_impl(const T1 &expected, const T2 &got, const char *file, int line) {
  LOG_CHECK(expected == got) << tag("expected", expected) << tag("got", got) << " in " << file << " at line " << line;
}

template <class T>
void assert_true_impl(const T &got, const char *file, int line) {
  LOG_CHECK(got) << "Expected true in " << file << " at line " << line;
}

}  // namespace td

#define ASSERT_EQ(expected, got) ::td::assert_eq_impl((expected), (got), __FILE__, __LINE__)

#define ASSERT_TRUE(got) ::td::assert_true_impl((got), __FILE__, __LINE__)

#define ASSERT_STREQ(expected, got) \
  ::td::assert_eq_impl(::td::Slice((expected)), ::td::Slice((got)), __FILE__, __LINE__)

#define REGRESSION_VERIFY(data) ::td::TestContext::get()->verify(data).ensure()

#define TEST_NAME(test_case_name, test_name) \
  TD_CONCAT(Test, TD_CONCAT(_, TD_CONCAT(test_case_name, TD_CONCAT(_, test_name))))

#define TEST(test_case_name, test_name) TEST_IMPL(TEST_NAME(test_case_name, test_name))

#define TEST_IMPL(test_name)                                                                                         \
  class test_name : public ::td::Test {                                                                              \
   public:                                                                                                           \
    using Test::Test;                                                                                                \
    void run() final;                                                                                                \
  };                                                                                                                 \
  ::td::RegisterTest<test_name> TD_CONCAT(test_instance_, TD_CONCAT(test_name, __LINE__))(TD_DEFINE_STR(test_name)); \
  void test_name::run()
