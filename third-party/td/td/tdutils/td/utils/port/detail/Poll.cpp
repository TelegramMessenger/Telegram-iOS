//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/Poll.h"

char disable_linker_warning_about_empty_file_poll_cpp TD_UNUSED;

#ifdef TD_POLL_POLL

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Status.h"

#include <cerrno>

namespace td {
namespace detail {

void Poll::init() {
}

void Poll::clear() {
  pollfds_.clear();
}

void Poll::subscribe(PollableFd fd, PollFlags flags) {
  unsubscribe(fd.ref());
  struct pollfd pollfd;
  pollfd.fd = fd.native_fd().fd();
  pollfd.events = 0;
  if (flags.can_read()) {
    pollfd.events |= POLLIN;
  }
  if (flags.can_write()) {
    pollfd.events |= POLLOUT;
  }
  pollfd.revents = 0;
  pollfds_.push_back(pollfd);
  fds_.push_back(std::move(fd));
}

void Poll::unsubscribe(PollableFdRef fd_ref) {
  auto fd = fd_ref.lock();
  SCOPE_EXIT {
    fd.release_as_list_node();
  };
  for (auto it = pollfds_.begin(); it != pollfds_.end(); ++it) {
    if (it->fd == fd.native_fd().fd()) {
      pollfds_.erase(it);
      fds_.erase(fds_.begin() + (it - pollfds_.begin()));
      return;
    }
  }
}

void Poll::unsubscribe_before_close(PollableFdRef fd) {
  unsubscribe(fd);
}

void Poll::run(int timeout_ms) {
  int err = poll(pollfds_.data(), narrow_cast<int>(pollfds_.size()), timeout_ms);
  auto poll_errno = errno;
  LOG_IF(FATAL, err == -1 && poll_errno != EINTR) << Status::PosixError(poll_errno, "poll failed");

  for (size_t i = 0; i < pollfds_.size(); i++) {
    auto &pollfd = pollfds_[i];
    auto &fd = fds_[i];

    PollFlags flags;
    if (pollfd.revents & POLLIN) {
      pollfd.revents &= ~POLLIN;
      flags = flags | PollFlags::Read();
    }
    if (pollfd.revents & POLLOUT) {
      pollfd.revents &= ~POLLOUT;
      flags = flags | PollFlags::Write();
    }
    if (pollfd.revents & POLLHUP) {
      pollfd.revents &= ~POLLHUP;
      flags = flags | PollFlags::Close();
    }
    if (pollfd.revents & POLLERR) {
      pollfd.revents &= ~POLLERR;
      flags = flags | PollFlags::Error();
    }
    if (pollfd.revents & POLLNVAL) {
      LOG(FATAL) << "Unexpected POLLNVAL " << tag("fd", pollfd.fd);
    }
    if (pollfd.revents) {
      LOG(FATAL) << "Unsupported poll events: " << pollfd.revents;
    }
    fd.add_flags(flags);
  }
}

}  // namespace detail
}  // namespace td

#endif
