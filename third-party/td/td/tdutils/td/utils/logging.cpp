//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/logging.h"

#include "td/utils/ExitGuard.h"
#include "td/utils/port/Clocks.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"
#include "td/utils/TsCerr.h"

#include <atomic>
#include <cstdlib>
#include <limits>
#include <mutex>

#if TD_ANDROID
#include <android/log.h>
#define ALOG_TAG "DLTD"
#elif TD_TIZEN
#include <dlog.h>
#define DLOG_TAG "DLTD"
#elif TD_EMSCRIPTEN
#include <emscripten.h>
#endif

namespace td {

LogOptions log_options;

static std::atomic<int> max_callback_verbosity_level{-2};
static std::atomic<OnLogMessageCallback> on_log_message_callback{nullptr};

void set_log_message_callback(int max_verbosity_level, OnLogMessageCallback callback) {
  if (callback == nullptr) {
    max_verbosity_level = -2;
  }

  max_callback_verbosity_level = max_verbosity_level;
  on_log_message_callback = callback;
}

void LogInterface::append(int log_level, CSlice slice) {
  do_append(log_level, slice);
  if (log_level == VERBOSITY_NAME(FATAL)) {
    process_fatal_error(slice);
  } else if (log_level <= max_callback_verbosity_level.load(std::memory_order_relaxed)) {
    auto callback = on_log_message_callback.load(std::memory_order_relaxed);
    if (callback != nullptr) {
      callback(log_level, slice);
    }
  }
}

TD_THREAD_LOCAL const char *Logger::tag_ = nullptr;
TD_THREAD_LOCAL const char *Logger::tag2_ = nullptr;

Logger::Logger(LogInterface &log, const LogOptions &options, int log_level, Slice file_name, int line_num,
               Slice comment)
    : Logger(log, options, log_level) {
  if (log_level == VERBOSITY_NAME(PLAIN) && &options == &log_options) {
    return;
  }
  if (!options_.add_info) {
    return;
  }
  if (ExitGuard::is_exited()) {
    return;
  }

  // log level
  sb_ << '[';
  if (static_cast<uint32>(log_level) < 10) {
    sb_ << ' ' << static_cast<char>('0' + log_level);
  } else {
    sb_ << log_level;
  }
  sb_ << ']';

  // thread identifier
  auto thread_id = get_thread_id();
  sb_ << "[t";
  if (static_cast<uint32>(thread_id) < 10) {
    sb_ << ' ' << static_cast<char>('0' + thread_id);
  } else {
    sb_ << thread_id;
  }
  sb_ << ']';

  // timestamp
  auto time = Clocks::system();
  auto unix_time = static_cast<uint32>(time);
  auto nanoseconds = static_cast<uint32>((time - unix_time) * 1e9);
  sb_ << '[' << unix_time << '.';
  uint32 limit = 100000000;
  while (nanoseconds < limit && limit > 1) {
    sb_ << '0';
    limit /= 10;
  }
  sb_ << nanoseconds << ']';

  // file : line
  if (!file_name.empty()) {
    auto last_slash_ = static_cast<int32>(file_name.size()) - 1;
    while (last_slash_ >= 0 && file_name[last_slash_] != '/' && file_name[last_slash_] != '\\') {
      last_slash_--;
    }
    file_name = file_name.substr(last_slash_ + 1);
    sb_ << '[' << file_name << ':' << static_cast<uint32>(line_num) << ']';
  }

  // context from tag_
  if (tag_ != nullptr && *tag_) {
    sb_ << "[#" << Slice(tag_) << ']';
  }

  // context from tag2_
  if (tag2_ != nullptr && *tag2_) {
    sb_ << "[!" << Slice(tag2_) << ']';
  }

  // comment (e.g. condition in LOG_IF)
  if (!comment.empty()) {
    sb_ << "[&" << comment << ']';
  }

  sb_ << '\t';
}

Logger::~Logger() {
  if (ExitGuard::is_exited()) {
    return;
  }
  if (options_.fix_newlines) {
    sb_ << '\n';
    auto slice = as_cslice();
    if (slice.back() != '\n') {
      slice.back() = '\n';
    }
    while (slice.size() > 1 && slice[slice.size() - 2] == '\n') {
      slice.back() = '\0';
      slice = MutableCSlice(slice.begin(), slice.begin() + slice.size() - 1);
    }
    log_.append(log_level_, slice);
  } else {
    log_.append(log_level_, as_cslice());
  }
}

class DefaultLog final : public LogInterface {
  void do_append(int log_level, CSlice slice) final {
#if TD_ANDROID
    switch (log_level) {
      case VERBOSITY_NAME(FATAL):
        __android_log_write(ANDROID_LOG_FATAL, ALOG_TAG, slice.c_str());
        break;
      case VERBOSITY_NAME(ERROR):
        __android_log_write(ANDROID_LOG_ERROR, ALOG_TAG, slice.c_str());
        break;
      case VERBOSITY_NAME(WARNING):
        __android_log_write(ANDROID_LOG_WARN, ALOG_TAG, slice.c_str());
        break;
      case VERBOSITY_NAME(INFO):
        __android_log_write(ANDROID_LOG_INFO, ALOG_TAG, slice.c_str());
        break;
      default:
        __android_log_write(ANDROID_LOG_DEBUG, ALOG_TAG, slice.c_str());
        break;
    }
#elif TD_TIZEN
    switch (log_level) {
      case VERBOSITY_NAME(FATAL):
        dlog_print(DLOG_ERROR, DLOG_TAG, "%s", slice.c_str());
        break;
      case VERBOSITY_NAME(ERROR):
        dlog_print(DLOG_ERROR, DLOG_TAG, "%s", slice.c_str());
        break;
      case VERBOSITY_NAME(WARNING):
        dlog_print(DLOG_WARN, DLOG_TAG, "%s", slice.c_str());
        break;
      case VERBOSITY_NAME(INFO):
        dlog_print(DLOG_INFO, DLOG_TAG, "%s", slice.c_str());
        break;
      default:
        dlog_print(DLOG_DEBUG, DLOG_TAG, "%s", slice.c_str());
        break;
    }
#elif TD_EMSCRIPTEN
    switch (log_level) {
      case VERBOSITY_NAME(FATAL):
        emscripten_log(EM_LOG_ERROR | EM_LOG_CONSOLE | EM_LOG_C_STACK | EM_LOG_JS_STACK, "%s", slice.c_str());
        EM_ASM(throw(UTF8ToString($0)), slice.c_str());
        break;
      case VERBOSITY_NAME(ERROR):
        emscripten_log(EM_LOG_ERROR | EM_LOG_CONSOLE, "%s", slice.c_str());
        break;
      case VERBOSITY_NAME(WARNING):
        emscripten_log(EM_LOG_WARN | EM_LOG_CONSOLE, "%s", slice.c_str());
        break;
      default:
        emscripten_log(EM_LOG_CONSOLE, "%s", slice.c_str());
        break;
    }
#elif !TD_WINDOWS
    Slice color;
    Slice no_color("\x1b[0m");
    switch (log_level) {
      case VERBOSITY_NAME(FATAL):
      case VERBOSITY_NAME(ERROR):
        color = Slice("\x1b[1;31m");  // red
        break;
      case VERBOSITY_NAME(WARNING):
        color = Slice("\x1b[1;33m");  // yellow
        break;
      case VERBOSITY_NAME(INFO):
        color = Slice("\x1b[1;36m");  // cyan
        break;
      default:
        no_color = Slice();
        break;
    }
    if (!slice.empty() && slice.back() == '\n') {
      TsCerr() << color << slice.substr(0, slice.size() - 1) << no_color << "\n";
    } else {
      TsCerr() << color << slice << no_color;
    }
#else
    // TODO: color
    TsCerr() << slice;
#endif
  }
};
static DefaultLog default_log;

LogInterface *const default_log_interface = &default_log;
LogInterface *log_interface = default_log_interface;

void process_fatal_error(CSlice message) {
  if (0 <= max_callback_verbosity_level.load(std::memory_order_relaxed)) {
    auto callback = on_log_message_callback.load(std::memory_order_relaxed);
    if (callback != nullptr) {
      callback(0, message);
    }
  }

  std::abort();
}

static std::atomic<uint32> log_guard;

LogGuard::LogGuard() {
  uint32 expected = 0;
  while (!log_guard.compare_exchange_strong(expected, 1, std::memory_order_relaxed, std::memory_order_relaxed)) {
    // spin
    CHECK(expected == 1);
    expected = 0;
  }
}

LogGuard::~LogGuard() {
  CHECK(log_guard.load(std::memory_order_relaxed) == 1);
  log_guard.store(0, std::memory_order_relaxed);
}

bool has_log_guard() {
  return log_guard.load(std::memory_order_relaxed) == 1;
}

namespace {
std::mutex sdl_mutex;
int sdl_cnt = 0;
int sdl_verbosity = 0;
}  // namespace

ScopedDisableLog::ScopedDisableLog() {
  std::unique_lock<std::mutex> guard(sdl_mutex);
  if (sdl_cnt == 0) {
    sdl_verbosity = set_verbosity_level(std::numeric_limits<int>::min());
  }
  sdl_cnt++;
}

ScopedDisableLog::~ScopedDisableLog() {
  std::unique_lock<std::mutex> guard(sdl_mutex);
  sdl_cnt--;
  if (sdl_cnt == 0) {
    set_verbosity_level(sdl_verbosity);
  }
}

static ExitGuard exit_guard;

}  // namespace td
