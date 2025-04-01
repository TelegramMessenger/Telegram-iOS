//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

/*
 * Simple logging.
 *
 * Predefined log levels: FATAL, ERROR, WARNING, INFO, DEBUG
 *
 * LOG(WARNING) << "Hello world!";
 * LOG(INFO) << "Hello " << 1234 << " world!";
 * LOG_IF(INFO, condition) << "Hello world if condition!";
 *
 * Custom log levels may be defined and used using VLOG:
 * int VERBOSITY_NAME(custom) = VERBOSITY_NAME(WARNING);
 * VLOG(custom) << "Hello custom world!"
 *
 * LOG(FATAL) << "Power is off";
 * CHECK(condition) <===> LOG_IF(FATAL, !(condition))
 */

#include "td/utils/common.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"
#include "td/utils/StackAllocator.h"
#include "td/utils/StringBuilder.h"

#include <atomic>
#include <type_traits>

#define VERBOSITY_NAME(x) verbosity_##x

#define GET_VERBOSITY_LEVEL() (::td::get_verbosity_level())
#define SET_VERBOSITY_LEVEL(new_level) (::td::set_verbosity_level(new_level))

#ifndef STRIP_LOG
#define STRIP_LOG VERBOSITY_NAME(DEBUG)
#endif
#define LOG_IS_STRIPPED(strip_level) \
  (::std::integral_constant<int, VERBOSITY_NAME(strip_level)>() > ::std::integral_constant<int, STRIP_LOG>())

#define LOGGER(interface, options, level, comment) ::td::Logger(interface, options, level, __FILE__, __LINE__, comment)

#define LOG_IMPL_FULL(interface, options, strip_level, runtime_level, condition, comment) \
  LOG_IS_STRIPPED(strip_level) || runtime_level > options.get_level() || !(condition)     \
      ? (void)0                                                                           \
      : ::td::detail::Voidify() & LOGGER(interface, options, runtime_level, comment)

#define LOG_IMPL(strip_level, level, condition, comment) \
  LOG_IMPL_FULL(*::td::log_interface, ::td::log_options, strip_level, VERBOSITY_NAME(level), condition, comment)

#define LOG(level) LOG_IMPL(level, level, true, ::td::Slice())
#define LOG_IF(level, condition) LOG_IMPL(level, level, condition, #condition)

#define VLOG(level) LOG_IMPL(DEBUG, level, true, TD_DEFINE_STR(level))
#define VLOG_IF(level, condition) LOG_IMPL(DEBUG, level, condition, TD_DEFINE_STR(level) " " #condition)

#define LOG_TAG ::td::Logger::tag_
#define LOG_TAG2 ::td::Logger::tag2_

#if TD_CLANG
bool no_return_func() __attribute__((analyzer_noreturn));
#endif

inline bool no_return_func() {
  return true;
}

// clang-format off
#define DUMMY_LOG_CHECK(condition) LOG_IF(NEVER, !(condition))

#ifdef TD_DEBUG
  #if TD_MSVC
    #define LOG_CHECK(condition)        \
      __analysis_assume(!!(condition)); \
      LOG_IMPL(FATAL, FATAL, !(condition), #condition)
  #else
    #define LOG_CHECK(condition) LOG_IMPL(FATAL, FATAL, !(condition) && no_return_func(), #condition)
  #endif
#else
  #define LOG_CHECK DUMMY_LOG_CHECK
#endif

#if NDEBUG
  #define LOG_DCHECK DUMMY_LOG_CHECK
#else
  #define LOG_DCHECK LOG_CHECK
#endif
// clang-format on

constexpr int VERBOSITY_NAME(PLAIN) = -1;
constexpr int VERBOSITY_NAME(FATAL) = 0;
constexpr int VERBOSITY_NAME(ERROR) = 1;
constexpr int VERBOSITY_NAME(WARNING) = 2;
constexpr int VERBOSITY_NAME(INFO) = 3;
constexpr int VERBOSITY_NAME(DEBUG) = 4;
constexpr int VERBOSITY_NAME(NEVER) = 1024;

namespace td {

struct LogOptions {
  std::atomic<int> level{VERBOSITY_NAME(DEBUG) + 1};
  bool fix_newlines{true};
  bool add_info{true};

  int get_level() const {
    return level.load(std::memory_order_relaxed);
  }
  int set_level(int new_level) {
    return level.exchange(new_level);
  }

  static const LogOptions &plain() {
    static LogOptions plain_options{0, false, false};
    return plain_options;
  }

  constexpr LogOptions() = default;
  constexpr LogOptions(int level, bool fix_newlines, bool add_info)
      : level(level), fix_newlines(fix_newlines), add_info(add_info) {
  }

  LogOptions(const LogOptions &other) : LogOptions(other.level.load(), other.fix_newlines, other.add_info) {
  }

  LogOptions &operator=(const LogOptions &other) {
    if (this == &other) {
      return *this;
    }
    level = other.level.load();
    fix_newlines = other.fix_newlines;
    add_info = other.add_info;
    return *this;
  }
  LogOptions(LogOptions &&) = delete;
  LogOptions &operator=(LogOptions &&) = delete;
  ~LogOptions() = default;
};

extern LogOptions log_options;
inline int set_verbosity_level(int level) {
  return log_options.set_level(level);
}
inline int get_verbosity_level() {
  return log_options.get_level();
}

class LogInterface {
 public:
  LogInterface() = default;
  LogInterface(const LogInterface &) = delete;
  LogInterface &operator=(const LogInterface &) = delete;
  LogInterface(LogInterface &&) = delete;
  LogInterface &operator=(LogInterface &&) = delete;
  virtual ~LogInterface() = default;

  void append(int log_level, CSlice slice);

  virtual void after_rotation() {
  }

  virtual vector<string> get_file_paths() {
    return {};
  }

  virtual void do_append(int log_level, CSlice slice) = 0;
};

extern LogInterface *const default_log_interface;
extern LogInterface *log_interface;

[[noreturn]] void process_fatal_error(CSlice message);

using OnLogMessageCallback = void (*)(int verbosity_level, CSlice message);
void set_log_message_callback(int max_verbosity_level, OnLogMessageCallback callback);

class Logger {
  static const size_t BUFFER_SIZE = 128 * 1024;

 public:
  Logger(LogInterface &log, const LogOptions &options, int log_level)
      : buffer_(StackAllocator::alloc(BUFFER_SIZE))
      , log_(log)
      , sb_(buffer_.as_slice())
      , options_(options)
      , log_level_(log_level) {
  }

  Logger(LogInterface &log, const LogOptions &options, int log_level, Slice file_name, int line_num, Slice comment);

  template <class T>
  Logger &operator<<(T &&other) {
    sb_ << other;
    return *this;
  }

  MutableCSlice as_cslice() {
    return sb_.as_cslice();
  }
  bool is_error() const {
    return sb_.is_error();
  }
  Logger(const Logger &) = delete;
  Logger &operator=(const Logger &) = delete;
  Logger(Logger &&) = delete;
  Logger &operator=(Logger &&) = delete;
  ~Logger();

  static TD_THREAD_LOCAL const char *tag_;
  static TD_THREAD_LOCAL const char *tag2_;

 private:
  decltype(StackAllocator::alloc(0)) buffer_;
  LogInterface &log_;
  StringBuilder sb_;
  const LogOptions &options_;
  int log_level_;
};

class LogGuard {
 public:
  LogGuard();
  LogGuard(const LogGuard &) = delete;
  LogGuard &operator=(const LogGuard &) = delete;
  LogGuard(LogGuard &&) = delete;
  LogGuard &operator=(LogGuard &&) = delete;
  ~LogGuard();
};

bool has_log_guard();

class ScopedDisableLog {
 public:
  ScopedDisableLog();
  ScopedDisableLog(const ScopedDisableLog &) = delete;
  ScopedDisableLog &operator=(const ScopedDisableLog &) = delete;
  ScopedDisableLog(ScopedDisableLog &&) = delete;
  ScopedDisableLog &operator=(ScopedDisableLog &&) = delete;
  ~ScopedDisableLog();
};

namespace detail {
class Voidify {
 public:
  template <class T>
  void operator&(const T &) {
  }
};
}  // namespace detail

}  // namespace td
