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
#include "Logging.h"

#include "auto/tl/tonlib_api.h"

#include "td/utils/FileLog.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/misc.h"

#include <atomic>
#include <map>
#include <mutex>

namespace tonlib {

static std::mutex logging_mutex;
static td::FileLog file_log;
static td::TsLog ts_log(&file_log);
static td::NullLog null_log;

td::int32 VERBOSITY_NAME(abc) = VERBOSITY_NAME(DEBUG);
td::int32 VERBOSITY_NAME(bcd) = VERBOSITY_NAME(DEBUG);
#define ADD_TAG(tag) \
  { #tag, &VERBOSITY_NAME(tag) }
static const std::map<td::Slice, int *> log_tags{ADD_TAG(abc), ADD_TAG(bcd)};
#undef ADD_TAG

td::Status Logging::set_current_stream(tonlib_api::object_ptr<tonlib_api::LogStream> stream) {
  if (stream == nullptr) {
    return td::Status::Error("Log stream must not be empty");
  }

  std::lock_guard<std::mutex> lock(logging_mutex);
  switch (stream->get_id()) {
    case tonlib_api::logStreamDefault::ID:
      td::log_interface = td::default_log_interface;
      return td::Status::OK();
    case tonlib_api::logStreamFile::ID: {
      auto file_stream = tonlib_api::move_object_as<tonlib_api::logStreamFile>(stream);
      auto max_log_file_size = file_stream->max_file_size_;
      if (max_log_file_size <= 0) {
        return td::Status::Error("Max log file size should be positive");
      }

      TRY_STATUS(file_log.init(file_stream->path_, max_log_file_size));
      std::atomic_thread_fence(std::memory_order_release);  // better than nothing
      td::log_interface = &ts_log;
      return td::Status::OK();
    }
    case tonlib_api::logStreamEmpty::ID:
      td::log_interface = &null_log;
      return td::Status::OK();
    default:
      UNREACHABLE();
      return td::Status::OK();
  }
}

td::Result<tonlib_api::object_ptr<tonlib_api::LogStream>> Logging::get_current_stream() {
  std::lock_guard<std::mutex> lock(logging_mutex);
  if (td::log_interface == td::default_log_interface) {
    return tonlib_api::make_object<tonlib_api::logStreamDefault>();
  }
  if (td::log_interface == &null_log) {
    return tonlib_api::make_object<tonlib_api::logStreamEmpty>();
  }
  if (td::log_interface == &ts_log) {
    return tonlib_api::make_object<tonlib_api::logStreamFile>(file_log.get_path().str(),
                                                              file_log.get_rotate_threshold());
  }
  return td::Status::Error("Log stream is unrecognized");
}

td::Status Logging::set_verbosity_level(int new_verbosity_level) {
  std::lock_guard<std::mutex> lock(logging_mutex);
  if (0 <= new_verbosity_level && new_verbosity_level <= VERBOSITY_NAME(NEVER)) {
    SET_VERBOSITY_LEVEL(VERBOSITY_NAME(FATAL) + new_verbosity_level);
    return td::Status::OK();
  }

  return td::Status::Error("Wrong new verbosity level specified");
}

int Logging::get_verbosity_level() {
  std::lock_guard<std::mutex> lock(logging_mutex);
  return GET_VERBOSITY_LEVEL();
}

td::vector<td::string> Logging::get_tags() {
  return transform(log_tags, [](auto &tag) { return tag.first.str(); });
}

td::Status Logging::set_tag_verbosity_level(td::Slice tag, int new_verbosity_level) {
  auto it = log_tags.find(tag);
  if (it == log_tags.end()) {
    return td::Status::Error("Log tag is not found");
  }

  std::lock_guard<std::mutex> lock(logging_mutex);
  *it->second = td::clamp(new_verbosity_level, 1, VERBOSITY_NAME(NEVER));
  return td::Status::OK();
}

td::Result<int> Logging::get_tag_verbosity_level(td::Slice tag) {
  auto it = log_tags.find(tag);
  if (it == log_tags.end()) {
    return td::Status::Error("Log tag is not found");
  }

  std::lock_guard<std::mutex> lock(logging_mutex);
  return *it->second;
}

void Logging::add_message(int log_verbosity_level, td::Slice message) {
  int VERBOSITY_NAME(client) = td::clamp(log_verbosity_level, 0, VERBOSITY_NAME(NEVER));
  VLOG(client) << message;
}

}  // namespace tonlib
