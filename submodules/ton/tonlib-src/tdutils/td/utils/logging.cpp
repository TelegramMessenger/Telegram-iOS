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
#include "td/utils/logging.h"

#include "td/utils/port/Clocks.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"
#include "td/utils/Time.h"

#include <atomic>
#include <cstdlib>

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

int VERBOSITY_NAME(net_query) = VERBOSITY_NAME(INFO);
int VERBOSITY_NAME(td_requests) = VERBOSITY_NAME(INFO);
int VERBOSITY_NAME(dc) = VERBOSITY_NAME(DEBUG) + 2;
int VERBOSITY_NAME(files) = VERBOSITY_NAME(DEBUG) + 2;
int VERBOSITY_NAME(mtproto) = VERBOSITY_NAME(DEBUG) + 7;
int VERBOSITY_NAME(raw_mtproto) = VERBOSITY_NAME(DEBUG) + 10;
int VERBOSITY_NAME(fd) = VERBOSITY_NAME(DEBUG) + 9;
int VERBOSITY_NAME(actor) = VERBOSITY_NAME(DEBUG) + 10;
int VERBOSITY_NAME(sqlite) = VERBOSITY_NAME(DEBUG) + 10;

LogOptions log_options;

TD_THREAD_LOCAL const char *Logger::tag_ = nullptr;
TD_THREAD_LOCAL const char *Logger::tag2_ = nullptr;

Logger::Logger(LogInterface &log, const LogOptions &options, int log_level, Slice file_name, int line_num,
               Slice comment)
    : Logger(log, options, log_level) {
  if (!options_.add_info) {
    return;
  }

  // log level
  sb_ << '[';
  if (log_level < 10) {
    sb_ << ' ';
  }
  sb_ << log_level << ']';

  // thread id
  auto thread_id = get_thread_id();
  sb_ << "[t";
  if (thread_id < 10) {
    sb_ << ' ';
  }
  sb_ << thread_id << ']';

  // timestamp
  sb_ << '[' << StringBuilder::FixedDouble(Clocks::system(), 9) << ']';

  // file : line
  if (!file_name.empty()) {
    auto last_slash_ = static_cast<int32>(file_name.size()) - 1;
    while (last_slash_ >= 0 && file_name[last_slash_] != '/' && file_name[last_slash_] != '\\') {
      last_slash_--;
    }
    file_name = file_name.substr(last_slash_ + 1);
    sb_ << "[" << file_name << ':' << line_num << ']';
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
    log_.append(slice, log_level_);
  } else {
    log_.append(as_cslice(), log_level_);
  }
}

TsCerr::TsCerr() {
  enterCritical();
}
TsCerr::~TsCerr() {
  exitCritical();
}
TsCerr &TsCerr::operator<<(Slice slice) {
  auto &fd = Stderr();
  if (fd.empty()) {
    return *this;
  }
  double end_time = 0;
  while (!slice.empty()) {
    auto res = fd.write(slice);
    if (res.is_error()) {
      if (res.error().code() == EPIPE) {
        break;
      }
      // Resource temporary unavailable
      if (end_time == 0) {
        end_time = Time::now() + 0.01;
      } else if (Time::now() > end_time) {
        break;
      }
      continue;
    }
    slice.remove_prefix(res.ok());
  }
  return *this;
}

void TsCerr::enterCritical() {
  while (lock_.test_and_set(std::memory_order_acquire)) {
    // spin
  }
}

void TsCerr::exitCritical() {
  lock_.clear(std::memory_order_release);
}
TsCerr::Lock TsCerr::lock_ = ATOMIC_FLAG_INIT;

class DefaultLog : public LogInterface {
 public:
  void append(CSlice slice, int log_level) override {
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
        dlog_print(DLOG_ERROR, DLOG_TAG, slice.c_str());
        break;
      case VERBOSITY_NAME(ERROR):
        dlog_print(DLOG_ERROR, DLOG_TAG, slice.c_str());
        break;
      case VERBOSITY_NAME(WARNING):
        dlog_print(DLOG_WARN, DLOG_TAG, slice.c_str());
        break;
      case VERBOSITY_NAME(INFO):
        dlog_print(DLOG_INFO, DLOG_TAG, slice.c_str());
        break;
      default:
        dlog_print(DLOG_DEBUG, DLOG_TAG, slice.c_str());
        break;
    }
#elif TD_EMSCRIPTEN
    switch (log_level) {
      case VERBOSITY_NAME(FATAL):
        emscripten_log(
            EM_LOG_ERROR | EM_LOG_CONSOLE | EM_LOG_C_STACK | EM_LOG_JS_STACK | EM_LOG_DEMANGLE | EM_LOG_FUNC_PARAMS,
            "%s", slice.c_str());
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
    switch (log_level) {
      case VERBOSITY_NAME(FATAL):
      case VERBOSITY_NAME(ERROR):
        color = Slice(TC_RED);
        break;
      case VERBOSITY_NAME(WARNING):
        color = Slice(TC_YELLOW);
        break;
      case VERBOSITY_NAME(INFO):
        color = Slice(TC_CYAN);
        break;
    }
    if (!slice.empty() && slice.back() == '\n') {
      TsCerr() << color << slice.substr(0, slice.size() - 1) << TC_EMPTY "\n";
    } else {
      TsCerr() << color << slice << TC_EMPTY;
    }
#else
    // TODO: color
    TsCerr() << slice;
#endif
    if (log_level == VERBOSITY_NAME(FATAL)) {
      process_fatal_error(slice);
    }
  }
  void rotate() override {
  }
};
static DefaultLog default_log;

LogInterface *const default_log_interface = &default_log;
LogInterface *log_interface = default_log_interface;

static OnFatalErrorCallback on_fatal_error_callback = nullptr;

void set_log_fatal_error_callback(OnFatalErrorCallback callback) {
  on_fatal_error_callback = callback;
}

void process_fatal_error(CSlice message) {
  auto callback = on_fatal_error_callback;
  if (callback) {
    callback(message);
  }
  std::abort();
}

}  // namespace td
