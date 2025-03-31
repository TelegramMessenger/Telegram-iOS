//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/KQueue.h"

char disable_linker_warning_about_empty_file_kqueue_cpp TD_UNUSED;

#ifdef TD_POLL_KQUEUE

#include "td/utils/logging.h"
#include "td/utils/Status.h"

#include <cerrno>
#include <utility>

#include <sys/time.h>
#include <unistd.h>

namespace td {
namespace detail {

KQueue::~KQueue() {
  clear();
}
void KQueue::init() {
  kq_ = NativeFd(kqueue());
  auto kqueue_errno = errno;
  LOG_IF(FATAL, !kq_) << Status::PosixError(kqueue_errno, "kqueue creation failed");

  // TODO: const
  events_.resize(1000);
  changes_n_ = 0;
}

void KQueue::clear() {
  if (!kq_) {
    return;
  }
  events_.clear();
  kq_.close();
  for (auto *list_node = list_root_.next; list_node != &list_root_;) {
    auto pollable_fd = PollableFd::from_list_node(list_node);
    list_node = list_node->next;
  }
}

int KQueue::update(int nevents, const timespec *timeout, bool may_fail) {
  int err = kevent(kq_.fd(), &events_[0], changes_n_, &events_[0], nevents, timeout);
  auto kevent_errno = errno;

  bool is_fatal_error = [&] {
    if (err != -1) {
      return false;
    }
    if (may_fail && kevent_errno == ENOENT) {
      return false;
    }
    return kevent_errno != EINTR;
  }();
  if (is_fatal_error) {
    LOG(FATAL) << Status::PosixError(kevent_errno, "kevent failed");
  }

  changes_n_ = 0;
  if (err < 0) {
    return 0;
  }
  return err;
}

void KQueue::flush_changes(bool may_fail) {
  if (!changes_n_) {
    return;
  }
  int n = update(0, nullptr, may_fail);
  CHECK(n == 0);
}

void KQueue::add_change(std::uintptr_t ident, int16 filter, uint16 flags, uint32 fflags, std::intptr_t data,
                        void *udata) {
  if (changes_n_ == static_cast<int>(events_.size())) {
    flush_changes();
  }
#if TD_NETBSD
  auto set_udata = reinterpret_cast<std::intptr_t>(udata);
#else
  auto set_udata = udata;
#endif
  EV_SET(&events_[changes_n_], ident, filter, flags, fflags, data, set_udata);
  VLOG(fd) << "Subscribe [fd:" << ident << "] [filter:" << filter << "] [udata: " << udata << "]";
  changes_n_++;
}

void KQueue::subscribe(PollableFd fd, PollFlags flags) {
  auto native_fd = fd.native_fd().fd();
  auto list_node = fd.release_as_list_node();
  list_root_.put(list_node);
  if (flags.can_read()) {
    add_change(native_fd, EVFILT_READ, EV_ADD | EV_CLEAR, 0, 0, list_node);
  }
  if (flags.can_write()) {
    add_change(native_fd, EVFILT_WRITE, EV_ADD | EV_CLEAR, 0, 0, list_node);
  }
}

void KQueue::invalidate(int native_fd) {
  for (int i = 0; i < changes_n_; i++) {
    if (events_[i].ident == static_cast<std::uintptr_t>(native_fd)) {
      changes_n_--;
      std::swap(events_[i], events_[changes_n_]);
      i--;
    }
  }
}

void KQueue::unsubscribe(PollableFdRef fd_ref) {
  auto pollable_fd = fd_ref.lock();
  auto native_fd = pollable_fd.native_fd().fd();

  // invalidate(fd);
  flush_changes();
  add_change(native_fd, EVFILT_READ, EV_DELETE, 0, 0, nullptr);
  flush_changes(true);
  add_change(native_fd, EVFILT_WRITE, EV_DELETE, 0, 0, nullptr);
  flush_changes(true);
}

void KQueue::unsubscribe_before_close(PollableFdRef fd_ref) {
  auto pollable_fd = fd_ref.lock();
  invalidate(pollable_fd.native_fd().fd());

  // just to avoid O(changes_n ^ 2)
  if (changes_n_ != 0) {
    flush_changes();
  }
}

void KQueue::run(int timeout_ms) {
  timespec timeout_data;
  timespec *timeout_ptr;
  if (timeout_ms == -1) {
    timeout_ptr = nullptr;
  } else {
    timeout_data.tv_sec = timeout_ms / 1000;
    timeout_data.tv_nsec = timeout_ms % 1000 * 1000000;
    timeout_ptr = &timeout_data;
  }

  int n = update(static_cast<int>(events_.size()), timeout_ptr);
  for (int i = 0; i < n; i++) {
    struct kevent *event = &events_[i];
    PollFlags flags;
    if (event->filter == EVFILT_WRITE) {
      flags.add_flags(PollFlags::Write());
    }
    if (event->filter == EVFILT_READ) {
      flags.add_flags(PollFlags::Read());
    }
    if (event->flags & EV_EOF) {
      flags.add_flags(PollFlags::Close());
    }
    if (event->fflags & EV_ERROR) {
      LOG(FATAL) << "EV_ERROR in kqueue is not supported";
    }
#if TD_NETBSD
    auto udata = reinterpret_cast<void *>(event->udata);
#else
    auto udata = event->udata;
#endif
    VLOG(fd) << "Event [fd:" << event->ident << "] [filter:" << event->filter << "] [udata: " << udata << "]";
    // LOG(WARNING) << "Have event->ident = " << event->ident << "event->filter = " << event->filter;
    auto pollable_fd = PollableFd::from_list_node(static_cast<ListNode *>(udata));
    pollable_fd.add_flags(flags);
    pollable_fd.release_as_list_node();
  }
}
}  // namespace detail
}  // namespace td

#endif
