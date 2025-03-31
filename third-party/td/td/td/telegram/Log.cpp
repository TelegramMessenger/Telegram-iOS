//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Log.h"

#include "td/telegram/Client.h"
#include "td/telegram/Logging.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"

#include <mutex>

namespace td {

static std::mutex log_mutex;
static string log_file_path;
static int64 max_log_file_size = 10 << 20;
static Log::FatalErrorCallbackPtr fatal_error_callback;

static void fatal_error_callback_wrapper(int verbosity_level, const char *message) {
  if (verbosity_level == 0) {
    auto callback = fatal_error_callback;
    if (callback != nullptr) {
      callback(message);
    }
  }
}

bool Log::set_file_path(string file_path) {
  std::lock_guard<std::mutex> lock(log_mutex);
  if (file_path.empty()) {
    log_file_path.clear();
    return Logging::set_current_stream(td_api::make_object<td_api::logStreamDefault>()).is_ok();
  }

  if (Logging::set_current_stream(td_api::make_object<td_api::logStreamFile>(file_path, max_log_file_size, true))
          .is_ok()) {
    log_file_path = std::move(file_path);
    return true;
  }

  return false;
}

void Log::set_max_file_size(int64 max_file_size) {
  std::lock_guard<std::mutex> lock(log_mutex);
  max_log_file_size = max(max_file_size, static_cast<int64>(1));
  Logging::set_current_stream(td_api::make_object<td_api::logStreamFile>(log_file_path, max_log_file_size, true))
      .ignore();
}

void Log::set_verbosity_level(int new_verbosity_level) {
  std::lock_guard<std::mutex> lock(log_mutex);
  Logging::set_verbosity_level(new_verbosity_level).ignore();
}

void Log::set_fatal_error_callback(FatalErrorCallbackPtr callback) {
  std::lock_guard<std::mutex> lock(log_mutex);
  if (callback == nullptr) {
    ClientManager::set_log_message_callback(0, nullptr);
    fatal_error_callback = nullptr;
  } else {
    fatal_error_callback = callback;
    ClientManager::set_log_message_callback(0, fatal_error_callback_wrapper);
  }
}

}  // namespace td
