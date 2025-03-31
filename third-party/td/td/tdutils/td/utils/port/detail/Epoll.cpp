//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/Epoll.h"

char disable_linker_warning_about_empty_file_epoll_cpp TD_UNUSED;

#ifdef TD_POLL_EPOLL

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

#include <cerrno>

#include <unistd.h>

namespace td {
namespace detail {
void Epoll::init() {
  CHECK(!epoll_fd_);
  epoll_fd_ = NativeFd(epoll_create(1));
  auto epoll_create_errno = errno;
  LOG_IF(FATAL, !epoll_fd_) << Status::PosixError(epoll_create_errno, "epoll_create failed");

  events_.resize(1000);
}

void Epoll::clear() {
  if (!epoll_fd_) {
    return;
  }
  events_.clear();

  epoll_fd_.close();

  for (auto *list_node = list_root_.next; list_node != &list_root_;) {
    auto pollable_fd = PollableFd::from_list_node(list_node);
    list_node = list_node->next;
  }
}

void Epoll::subscribe(PollableFd fd, PollFlags flags) {
  epoll_event event;
  event.events = EPOLLHUP | EPOLLERR | EPOLLET;
#ifdef EPOLLRDHUP
  event.events |= EPOLLRDHUP;
#endif
  if (flags.can_read()) {
    event.events |= EPOLLIN;
  }
  if (flags.can_write()) {
    event.events |= EPOLLOUT;
  }
  auto native_fd = fd.native_fd().fd();
  auto *list_node = fd.release_as_list_node();
  list_root_.put(list_node);
  event.data.ptr = list_node;

  int err = epoll_ctl(epoll_fd_.fd(), EPOLL_CTL_ADD, native_fd, &event);
  auto epoll_ctl_errno = errno;
  LOG_IF(FATAL, err == -1) << Status::PosixError(epoll_ctl_errno, "epoll_ctl ADD failed")
                           << ", epoll_fd = " << epoll_fd_.fd() << ", fd = " << native_fd;
}

void Epoll::unsubscribe(PollableFdRef fd_ref) {
  auto fd = fd_ref.lock();
  auto native_fd = fd.native_fd().fd();
  int err = epoll_ctl(epoll_fd_.fd(), EPOLL_CTL_DEL, native_fd, nullptr);
  auto epoll_ctl_errno = errno;
  LOG_IF(FATAL, err == -1) << Status::PosixError(epoll_ctl_errno, "epoll_ctl DEL failed")
                           << ", epoll_fd = " << epoll_fd_.fd() << ", fd = " << native_fd
                           << ", status = " << fd.native_fd().validate();
}

void Epoll::unsubscribe_before_close(PollableFdRef fd) {
  unsubscribe(fd);
}

void Epoll::run(int timeout_ms) {
  int ready_n = epoll_wait(epoll_fd_.fd(), &events_[0], static_cast<int>(events_.size()), timeout_ms);
  auto epoll_wait_errno = errno;
  LOG_IF(FATAL, ready_n == -1 && epoll_wait_errno != EINTR)
      << Status::PosixError(epoll_wait_errno, "epoll_wait failed");

  for (int i = 0; i < ready_n; i++) {
    PollFlags flags;
    epoll_event *event = &events_[i];
    if (event->events & EPOLLIN) {
      event->events &= ~EPOLLIN;
      flags = flags | PollFlags::Read();
    }
    if (event->events & EPOLLOUT) {
      event->events &= ~EPOLLOUT;
      flags = flags | PollFlags::Write();
    }
#ifdef EPOLLRDHUP
    if (event->events & EPOLLRDHUP) {
      event->events &= ~EPOLLRDHUP;
      flags = flags | PollFlags::Close();
    }
#endif
    if (event->events & EPOLLHUP) {
      event->events &= ~EPOLLHUP;
      flags = flags | PollFlags::Close();
    }
    if (event->events & EPOLLERR) {
      event->events &= ~EPOLLERR;
      flags = flags | PollFlags::Error();
    }
    if (event->events) {
      LOG(FATAL) << "Unsupported epoll events: " << static_cast<int32>(event->events);
    }
    //LOG(DEBUG) << "Epoll event " << tag("fd", event->data.fd) << tag("flags", format::as_binary(flags));
    auto pollable_fd = PollableFd::from_list_node(static_cast<ListNode *>(event->data.ptr));
    pollable_fd.add_flags(flags);
    pollable_fd.release_as_list_node();
  }
}
}  // namespace detail
}  // namespace td

#endif
