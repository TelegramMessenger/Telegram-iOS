//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Logging.h"

#include "td/telegram/ConfigManager.h"
#include "td/telegram/FileReferenceManager.h"
#include "td/telegram/files/FileGcWorker.h"
#include "td/telegram/files/FileLoaderUtils.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/net/ConnectionCreator.h"
#include "td/telegram/net/DcAuthManager.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/NotificationManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UpdatesManager.h"

#include "td/mtproto/SessionConnection.h"
#include "td/mtproto/Transport.h"

#include "td/db/binlog/Binlog.h"
#include "td/db/SqliteStatement.h"

#include "td/net/GetHostByNameActor.h"
#include "td/net/TransparentProxy.h"

#include "td/actor/actor.h"

#include "td/utils/algorithm.h"
#include "td/utils/ExitGuard.h"
#include "td/utils/FileLog.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/NullLog.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/TsLog.h"

#include <atomic>
#include <map>
#include <mutex>

namespace td {

static std::mutex logging_mutex;
static FileLog file_log;
static TsLog ts_log(&file_log);
static NullLog null_log;
static ExitGuard exit_guard;

#define ADD_TAG(tag) \
  { #tag, &VERBOSITY_NAME(tag) }
static const std::map<Slice, int *> log_tags{
    ADD_TAG(td_init),     ADD_TAG(update_file),      ADD_TAG(connections),   ADD_TAG(binlog),
    ADD_TAG(proxy),       ADD_TAG(net_query),        ADD_TAG(td_requests),   ADD_TAG(dc),
    ADD_TAG(file_loader), ADD_TAG(mtproto),          ADD_TAG(raw_mtproto),   ADD_TAG(fd),
    ADD_TAG(actor),       ADD_TAG(sqlite),           ADD_TAG(notifications), ADD_TAG(get_difference),
    ADD_TAG(file_gc),     ADD_TAG(config_recoverer), ADD_TAG(dns_resolver),  ADD_TAG(file_references)};
#undef ADD_TAG

Status Logging::set_current_stream(td_api::object_ptr<td_api::LogStream> stream) {
  if (stream == nullptr) {
    return Status::Error("Log stream must be non-empty");
  }

  std::lock_guard<std::mutex> lock(logging_mutex);
  switch (stream->get_id()) {
    case td_api::logStreamDefault::ID:
      log_interface = default_log_interface;
      return Status::OK();
    case td_api::logStreamFile::ID: {
      auto file_stream = td_api::move_object_as<td_api::logStreamFile>(stream);
      auto max_log_file_size = file_stream->max_file_size_;
      if (max_log_file_size <= 0) {
        return Status::Error("Max log file size must be positive");
      }
      auto redirect_stderr = file_stream->redirect_stderr_;

      TRY_STATUS(file_log.init(file_stream->path_, max_log_file_size, redirect_stderr));
      std::atomic_thread_fence(std::memory_order_release);  // better than nothing
      log_interface = &ts_log;
      return Status::OK();
    }
    case td_api::logStreamEmpty::ID:
      log_interface = &null_log;
      return Status::OK();
    default:
      UNREACHABLE();
      return Status::OK();
  }
}

Result<td_api::object_ptr<td_api::LogStream>> Logging::get_current_stream() {
  std::lock_guard<std::mutex> lock(logging_mutex);
  if (log_interface == default_log_interface) {
    return td_api::make_object<td_api::logStreamDefault>();
  }
  if (log_interface == &null_log) {
    return td_api::make_object<td_api::logStreamEmpty>();
  }
  if (log_interface == &ts_log) {
    return td_api::make_object<td_api::logStreamFile>(file_log.get_path().str(), file_log.get_rotate_threshold(),
                                                      file_log.get_redirect_stderr());
  }
  return Status::Error("Log stream is unrecognized");
}

Status Logging::set_verbosity_level(int new_verbosity_level) {
  std::lock_guard<std::mutex> lock(logging_mutex);
  if (0 <= new_verbosity_level && new_verbosity_level <= VERBOSITY_NAME(NEVER)) {
    SET_VERBOSITY_LEVEL(VERBOSITY_NAME(FATAL) + new_verbosity_level);
    return Status::OK();
  }

  return Status::Error("Wrong new verbosity level specified");
}

int Logging::get_verbosity_level() {
  std::lock_guard<std::mutex> lock(logging_mutex);
  return GET_VERBOSITY_LEVEL();
}

vector<string> Logging::get_tags() {
  return transform(log_tags, [](auto &tag) { return tag.first.str(); });
}

Status Logging::set_tag_verbosity_level(Slice tag, int new_verbosity_level) {
  if (tag.empty()) {
    return Status::Error("Log tag must be non-empty");
  }

  auto it = log_tags.find(tag);
  if (it == log_tags.end()) {
    return Status::Error("Log tag is not found");
  }

  std::lock_guard<std::mutex> lock(logging_mutex);
  *it->second = clamp(new_verbosity_level, 1, VERBOSITY_NAME(NEVER));
  return Status::OK();
}

Result<int> Logging::get_tag_verbosity_level(Slice tag) {
  if (tag.empty()) {
    return Status::Error("Log tag must be non-empty");
  }

  auto it = log_tags.find(tag);
  if (it == log_tags.end()) {
    return Status::Error("Log tag is not found");
  }

  std::lock_guard<std::mutex> lock(logging_mutex);
  return *it->second;
}

void Logging::add_message(int log_verbosity_level, Slice message) {
  int VERBOSITY_NAME(client) = clamp(log_verbosity_level, 0, VERBOSITY_NAME(NEVER));
  VLOG(client) << message;
}

}  // namespace td
