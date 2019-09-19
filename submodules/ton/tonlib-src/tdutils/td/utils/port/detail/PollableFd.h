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
#pragma once

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/List.h"
#include "td/utils/logging.h"
#include "td/utils/Observer.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/SpinLock.h"

#include <atomic>
#include <memory>
#include <type_traits>

namespace td {

class PollableFdInfo;
class PollableFdInfoUnlock {
 public:
  void operator()(PollableFdInfo *ptr);
};

class PollableFd;
class PollableFdRef {
 public:
  explicit PollableFdRef(ListNode *list_node) : list_node_(list_node) {
  }
  PollableFd lock();

 private:
  ListNode *list_node_;
};

class PollableFd {
 public:
  // Interface for kqueue, epoll and e.t.c.
  const NativeFd &native_fd() const;

  ListNode *release_as_list_node();
  PollableFdRef ref();
  static PollableFd from_list_node(ListNode *node);
  void add_flags(PollFlags flags);
  PollFlags get_flags_unsafe() const;

 private:
  std::unique_ptr<PollableFdInfo, PollableFdInfoUnlock> fd_info_;
  friend class PollableFdInfo;

  explicit PollableFd(std::unique_ptr<PollableFdInfo, PollableFdInfoUnlock> fd_info) : fd_info_(std::move(fd_info)) {
  }
};

inline PollableFd PollableFdRef::lock() {
  return PollableFd::from_list_node(list_node_);
}

class PollableFdInfo : private ListNode {
 public:
  PollableFdInfo() = default;
  PollableFdInfo(const PollableFdInfo &) = delete;
  PollableFdInfo &operator=(const PollableFdInfo &) = delete;
  PollableFdInfo(PollableFdInfo &&) = delete;
  PollableFdInfo &operator=(PollableFdInfo &&) = delete;

  PollableFd extract_pollable_fd(ObserverBase *observer) {
    VLOG(fd) << native_fd() << " extract pollable fd " << tag("observer", observer);
    CHECK(!empty());
    bool was_locked = lock_.test_and_set(std::memory_order_acquire);
    CHECK(!was_locked);
    set_observer(observer);
    return PollableFd{std::unique_ptr<PollableFdInfo, PollableFdInfoUnlock>{this}};
  }
  PollableFdRef get_pollable_fd_ref() {
    CHECK(!empty());
    bool was_locked = lock_.test_and_set(std::memory_order_acquire);
    CHECK(was_locked);
    return PollableFdRef{as_list_node()};
  }

  void add_flags(PollFlags flags) {
    flags_.write_flags_local(flags);
  }

  void clear_flags(PollFlags flags) {
    flags_.clear_flags(flags);
  }
  PollFlags get_flags() const {
    return flags_.read_flags();
  }
  PollFlags get_flags_local() const {
    return flags_.read_flags_local();
  }

  bool empty() const {
    return !fd_;
  }

  void set_native_fd(NativeFd new_native_fd) {
    if (fd_) {
      CHECK(!new_native_fd);
      bool was_locked = lock_.test_and_set(std::memory_order_acquire);
      CHECK(!was_locked);
      lock_.clear(std::memory_order_release);
    }

    fd_ = std::move(new_native_fd);
  }
  explicit PollableFdInfo(NativeFd native_fd) {
    set_native_fd(std::move(native_fd));
  }
  const NativeFd &native_fd() const {
    //CHECK(!empty());
    return fd_;
  }
  NativeFd move_as_native_fd() {
    return std::move(fd_);
  }

  ~PollableFdInfo() {
    VLOG(fd) << native_fd() << " destroy PollableFdInfo";
    bool was_locked = lock_.test_and_set(std::memory_order_acquire);
    CHECK(!was_locked);
  }

  void add_flags_from_poll(PollFlags flags) {
    VLOG(fd) << native_fd() << " add flags from poll " << flags;
    if (flags_.write_flags(flags)) {
      notify_observer();
    }
  }

 private:
  NativeFd fd_{};
  std::atomic_flag lock_ = ATOMIC_FLAG_INIT;
  PollFlagsSet flags_;
#if TD_PORT_WINDOWS
  SpinLock observer_lock_;
#endif
  ObserverBase *observer_{nullptr};

  friend class PollableFd;
  friend class PollableFdInfoUnlock;

  void set_observer(ObserverBase *observer) {
#if TD_PORT_WINDOWS
    auto lock = observer_lock_.lock();
#endif
    CHECK(!observer_);
    observer_ = observer;
  }
  void clear_observer() {
#if TD_PORT_WINDOWS
    auto lock = observer_lock_.lock();
#endif
    observer_ = nullptr;
  }
  void notify_observer() {
#if TD_PORT_WINDOWS
    auto lock = observer_lock_.lock();
#endif
    VLOG(fd) << native_fd() << " notify " << tag("observer", observer_);
    if (observer_) {
      observer_->notify();
    }
  }

  void unlock() {
    clear_observer();
    lock_.clear(std::memory_order_release);
    as_list_node()->remove();
  }

  ListNode *as_list_node() {
    return static_cast<ListNode *>(this);
  }
  static PollableFdInfo *from_list_node(ListNode *list_node) {
    return static_cast<PollableFdInfo *>(list_node);
  }
};
inline void PollableFdInfoUnlock::operator()(PollableFdInfo *ptr) {
  ptr->unlock();
}

inline ListNode *PollableFd::release_as_list_node() {
  return fd_info_.release()->as_list_node();
}
inline PollableFdRef PollableFd::ref() {
  return PollableFdRef{fd_info_->as_list_node()};
}
inline PollableFd PollableFd::from_list_node(ListNode *node) {
  return PollableFd(std::unique_ptr<PollableFdInfo, PollableFdInfoUnlock>(PollableFdInfo::from_list_node(node)));
}

inline void PollableFd::add_flags(PollFlags flags) {
  fd_info_->add_flags_from_poll(flags);
}
inline PollFlags PollableFd::get_flags_unsafe() const {
  return fd_info_->get_flags_local();
}
inline const NativeFd &PollableFd::native_fd() const {
  return fd_info_->native_fd();
}

#if TD_PORT_POSIX
namespace detail {
template <class F>
auto skip_eintr(F &&f) {
  decltype(f()) res;
  static_assert(std::is_integral<decltype(res)>::value, "integral type expected");
  do {
    errno = 0;  // just in case
    res = f();
  } while (res < 0 && errno == EINTR);
  return res;
}
template <class F>
auto skip_eintr_cstr(F &&f) {
  char *res;
  do {
    errno = 0;  // just in case
    res = f();
  } while (res == nullptr && errno == EINTR);
  return res;
}
}  // namespace detail
#endif

template <class FdT>
bool can_read(const FdT &fd) {
  return fd.get_poll_info().get_flags().can_read() || fd.get_poll_info().get_flags().has_pending_error();
}

template <class FdT>
bool can_write(const FdT &fd) {
  return fd.get_poll_info().get_flags().can_write();
}

template <class FdT>
bool can_close(const FdT &fd) {
  return fd.get_poll_info().get_flags().can_close();
}

}  // namespace td
