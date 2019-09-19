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
