//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/EventFdWindows.h"

char disable_linker_warning_about_empty_file_event_fd_windows_cpp TD_UNUSED;

#ifdef TD_EVENTFD_WINDOWS

#include "td/utils/logging.h"

namespace td {
namespace detail {

void EventFdWindows::init() {
  auto handle = CreateEventW(nullptr, true, false, nullptr);
  if (handle == nullptr) {
    auto error = OS_ERROR("CreateEventW failed");
    LOG(FATAL) << error;
  }
  event_ = NativeFd(handle);
}

bool EventFdWindows::empty() {
  return !event_;
}

void EventFdWindows::close() {
  event_.close();
}

Status EventFdWindows::get_pending_error() {
  return Status::OK();
}

PollableFdInfo &EventFdWindows::get_poll_info() {
  UNREACHABLE();
}

void EventFdWindows::release() {
  if (SetEvent(event_.fd()) == 0) {
    auto error = OS_ERROR("SetEvent failed");
    LOG(FATAL) << error;
  }
}

void EventFdWindows::acquire() {
  if (ResetEvent(event_.fd()) == 0) {
    auto error = OS_ERROR("ResetEvent failed");
    LOG(FATAL) << error;
  }
}

void EventFdWindows::wait(int timeout_ms) {
  WaitForSingleObject(event_.fd(), timeout_ms);
  if (ResetEvent(event_.fd()) == 0) {
    auto error = OS_ERROR("ResetEvent failed");
    LOG(FATAL) << error;
  }
}

}  // namespace detail
}  // namespace td

#endif
