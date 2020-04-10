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
#include "td/utils/port/detail/EventFdLinux.h"

char disable_linker_warning_about_empty_file_event_fd_linux_cpp TD_UNUSED;

#ifdef TD_EVENTFD_LINUX

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"

#include <poll.h>
#include <sys/eventfd.h>
#include <unistd.h>

namespace td {
namespace detail {
class EventFdLinuxImpl {
 public:
  PollableFdInfo info;
};

EventFdLinux::EventFdLinux() = default;
EventFdLinux::EventFdLinux(EventFdLinux &&) = default;
EventFdLinux &EventFdLinux::operator=(EventFdLinux &&) = default;
EventFdLinux::~EventFdLinux() = default;

void EventFdLinux::init() {
  auto fd = NativeFd(eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC));
  auto eventfd_errno = errno;
  LOG_IF(FATAL, !fd) << Status::PosixError(eventfd_errno, "eventfd call failed");
  impl_ = make_unique<EventFdLinuxImpl>();
  impl_->info.set_native_fd(std::move(fd));
}

bool EventFdLinux::empty() {
  return !impl_;
}

void EventFdLinux::close() {
  impl_.reset();
}

Status EventFdLinux::get_pending_error() {
  return Status::OK();
}

PollableFdInfo &EventFdLinux::get_poll_info() {
  return impl_->info;
}

// NB: will be called from multiple threads
void EventFdLinux::release() {
  const uint64 value = 1;
  auto slice = Slice(reinterpret_cast<const char *>(&value), sizeof(value));
  auto native_fd = impl_->info.native_fd().fd();

  auto result = [&]() -> Result<size_t> {
    auto write_res = detail::skip_eintr([&] { return ::write(native_fd, slice.begin(), slice.size()); });
    auto write_errno = errno;
    if (write_res >= 0) {
      return narrow_cast<size_t>(write_res);
    }
    return Status::PosixError(write_errno, PSLICE() << "Write to fd " << native_fd << " has failed");
  }();

  if (result.is_error()) {
    LOG(FATAL) << "EventFdLinux write failed: " << result.error();
  }
  size_t size = result.ok();
  if (size != sizeof(value)) {
    LOG(FATAL) << "EventFdLinux write returned " << value << " instead of " << sizeof(value);
  }
}

void EventFdLinux::acquire() {
  impl_->info.get_flags();
  SCOPE_EXIT {
    // Clear flags without EAGAIN and EWOULDBLOCK
    // Looks like it is safe thing to do with eventfd
    get_poll_info().clear_flags(PollFlags::Read());
  };
  uint64 res;
  auto slice = MutableSlice(reinterpret_cast<char *>(&res), sizeof(res));
  auto native_fd = impl_->info.native_fd().fd();
  auto result = [&]() -> Result<size_t> {
    CHECK(slice.size() > 0);
    auto read_res = detail::skip_eintr([&] { return ::read(native_fd, slice.begin(), slice.size()); });
    auto read_errno = errno;
    if (read_res >= 0) {
      CHECK(read_res != 0);
      return narrow_cast<size_t>(read_res);
    }
    if (read_errno == EAGAIN
#if EAGAIN != EWOULDBLOCK
        || read_errno == EWOULDBLOCK
#endif
    ) {
      return 0;
    }
    return Status::PosixError(read_errno, PSLICE() << "Read from fd " << native_fd << " has failed");
  }();
  if (result.is_error()) {
    LOG(FATAL) << "EventFdLinux read failed: " << result.error();
  }
}

void EventFdLinux::wait(int timeout_ms) {
  pollfd fd;
  fd.fd = get_poll_info().native_fd().fd();
  fd.events = POLLIN;
  poll(&fd, 1, timeout_ms);
}

}  // namespace detail
}  // namespace td

#endif
