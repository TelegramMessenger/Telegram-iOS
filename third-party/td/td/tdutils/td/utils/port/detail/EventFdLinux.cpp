//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/EventFdLinux.h"

char disable_linker_warning_about_empty_file_event_fd_linux_cpp TD_UNUSED;

#ifdef TD_EVENTFD_LINUX

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/detail/skip_eintr.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

#include <cerrno>

#include <poll.h>
#include <sys/eventfd.h>
#include <unistd.h>

namespace td {
namespace detail {
class EventFdLinuxImpl {
 public:
  PollableFdInfo info_;
};

EventFdLinux::EventFdLinux() = default;
EventFdLinux::EventFdLinux(EventFdLinux &&) noexcept = default;
EventFdLinux &EventFdLinux::operator=(EventFdLinux &&) noexcept = default;
EventFdLinux::~EventFdLinux() = default;

void EventFdLinux::init() {
  auto fd = NativeFd(eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC));
  auto eventfd_errno = errno;
  LOG_IF(FATAL, !fd) << Status::PosixError(eventfd_errno, "eventfd call failed");
  impl_ = make_unique<EventFdLinuxImpl>();
  impl_->info_.set_native_fd(std::move(fd));
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
  return impl_->info_;
}

// NB: will be called from multiple threads
void EventFdLinux::release() {
  const uint64 value = 1;
  auto slice = Slice(reinterpret_cast<const char *>(&value), sizeof(value));
  auto native_fd = impl_->info_.native_fd().fd();

  auto result = [&]() -> Result<size_t> {
    auto write_res = detail::skip_eintr([&] { return write(native_fd, slice.begin(), slice.size()); });
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
  impl_->info_.sync_with_poll();
  SCOPE_EXIT {
    // Clear flags without EAGAIN and EWOULDBLOCK
    // Looks like it is safe thing to do with eventfd
    get_poll_info().clear_flags(PollFlags::Read());
  };
  uint64 res;
  auto slice = MutableSlice(reinterpret_cast<char *>(&res), sizeof(res));
  auto native_fd = impl_->info_.native_fd().fd();
  auto result = [&]() -> Result<size_t> {
    CHECK(!slice.empty());
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
  detail::skip_eintr_timeout(
      [this](int timeout_ms) {
        pollfd fd;
        fd.fd = get_poll_info().native_fd().fd();
        fd.events = POLLIN;
        return poll(&fd, 1, timeout_ms);
      },
      timeout_ms);
}

}  // namespace detail
}  // namespace td

#endif
