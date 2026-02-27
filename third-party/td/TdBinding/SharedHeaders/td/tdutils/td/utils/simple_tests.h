// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/PathView.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"

#include <utility>

namespace td {
namespace simple_test {

class DebugContext {
 public:
  static DebugContext &instance() {
    static TD_THREAD_LOCAL DebugContext *instance{};
    init_thread_local<DebugContext>(instance);
    return *instance;
  }
  template <typename T>
  void add(Slice name, const T &value, CSlice file = {}, int line = 0) {
    StringBuilder sb;
    sb << name << "=" << value;

    if (file.empty()) {
      sb << " (at " << PathView(file).file_name() << ":" << line << ")";
    }

    values_.emplace_back(name.str(), sb.as_cslice().str());
  }

  void pop_back() {
    if (!values_.empty()) {
      values_.pop_back();
    }
  }

  friend StringBuilder &operator<<(StringBuilder &sb, const DebugContext &ctx) {
    if (ctx.values_.empty()) {
      return sb;
    }

    sb << "\nDebug context:";
    for (const auto &pair : ctx.values_) {
      sb << "\n  " << pair.second;
    }
    return sb;
  }

 private:
  vector<std::pair<string, string>> values_;
};

template <typename T>
class ScopedDebugValue {
 public:
  ScopedDebugValue(Slice name, const T &value, CSlice file = {}, int line = 0) : name_(name.str()) {
    DebugContext::instance().add(name_, value, file, line);
  }

  ~ScopedDebugValue() {
    DebugContext::instance().pop_back();
  }

 private:
  string name_;
};

inline Status format_error(StringBuilder &sb, const char *file, int line) {
  sb << "\n\tat " << PathView(Slice(file)).file_name() << ":" << line << DebugContext::instance();
  return Status::Error(sb.as_cslice());
}

}  // namespace simple_test

class StatusTest : public Test {
 public:
  ~StatusTest() override = default;

  virtual Status run_test() = 0;
  virtual string get_test_name() const = 0;

  void run() override {
    auto status = run_test();
    if (status.is_ok()) {
      LOG(INFO) << "Test " << get_test_name() << " PASSED";
    } else {
      // Include debug context in error message if available
      LOG(FATAL) << "Test " << get_test_name() << " FAILED: " << status.message()
                 << simple_test::DebugContext::instance();
    }
  }
};

// Macro for defining status-based tests
#define S_TEST(test_case_name, test_name)                                                                            \
  class TD_CONCAT(StatusTest_, TD_CONCAT(test_case_name, TD_CONCAT(_, test_name))) final : public ::td::StatusTest { \
   public:                                                                                                           \
    ::td::Status run_test() override;                                                                                \
    ::td::string get_test_name() const override {                                                                    \
      return #test_case_name "." #test_name;                                                                         \
    }                                                                                                                \
  };                                                                                                                 \
  ::td::RegisterTest<TD_CONCAT(StatusTest_, TD_CONCAT(test_case_name, TD_CONCAT(_, test_name)))> TD_CONCAT(          \
      status_test_instance_,                                                                                         \
      TD_CONCAT(TD_CONCAT(test_case_name, TD_CONCAT(_, test_name)), __LINE__))(#test_case_name "." #test_name);      \
  ::td::Status TD_CONCAT(StatusTest_, TD_CONCAT(test_case_name, TD_CONCAT(_, test_name)))::run_test()

// Add a debug value within current scope with file/line info
#define TEST_DEBUG_VALUE(name, value)                                                                            \
  ::td::simple_test::ScopedDebugValue<decltype(value)> TD_CONCAT(debug_value_, __LINE__)(#name, value, __FILE__, \
                                                                                         __LINE__)

#define TEST_TRY_RESULT(name, expr)                                      \
  auto TD_CONCAT(r_, __LINE__) = (expr);                                 \
  if (TD_CONCAT(r_, __LINE__).is_error()) {                              \
    auto error = TD_CONCAT(r_, __LINE__).move_as_error();                \
    ::td::StringBuilder sb;                                              \
    sb << "\nFailed to execute " << #expr << ":\n\t" << error.message(); \
    return ::td::simple_test::format_error(sb, __FILE__, __LINE__);      \
  }                                                                      \
  auto name = TD_CONCAT(r_, __LINE__).move_as_ok();                      \
  TEST_DEBUG_VALUE(name, name)

#define TEST_TRY_STATUS(expr)                                                       \
  {                                                                                 \
    auto result = (expr);                                                           \
    if (result.is_error()) {                                                        \
      ::td::StringBuilder sb;                                                       \
      sb << "\nFailed to execute " << #expr << ":\n\t" << result.error().message(); \
      return ::td::simple_test::format_error(sb, __FILE__, __LINE__);               \
    }                                                                               \
  }

#define TEST_ASSERT(condition, message)                                \
  if (!(condition)) {                                                  \
    ::td::StringBuilder sb;                                            \
    sb << "\nAssertion failed: " << #condition << " -\n\t" << message; \
    return ::td::simple_test::format_error(sb, __FILE__, __LINE__);    \
  }

#define TEST_ASSERT_EQ(expected_, received_, message)                                              \
  {                                                                                                \
    const auto &expected = (expected_);                                                            \
    const auto &received = (received_);                                                            \
    if (!(expected == received)) {                                                                 \
      ::td::StringBuilder sb;                                                                      \
      sb << "\n"                                                                                   \
         << #received_ << " != " << #expected_ << " - " << message << "\n\texpected: " << expected \
         << "\n\treceived:" << received;                                                           \
      return ::td::simple_test::format_error(sb, __FILE__, __LINE__);                              \
    }                                                                                              \
  }

}  // namespace td
