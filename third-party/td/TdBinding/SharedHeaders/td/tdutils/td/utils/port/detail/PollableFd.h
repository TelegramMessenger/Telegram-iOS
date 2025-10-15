//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/List.h"
#include "td/utils/logging.h"
#include "td/utils/Observer.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/Mutex.h"
#include "td/utils/port/PollFlags.h"

#include <atomic>
#include <memory>

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

class PollableFdInfo final : private ListNode {
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
  PollFlags sync_with_poll() const {
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
  Mutex observer_lock_;
#endif
  ObserverBase *observer_{nullptr};

  friend class PollableFd;
  friend class PollableFdInfoUnlock;

  void set_observer(ObserverBase *observer) {
#if TD_PORT_WINDOWS
    auto lock = observer_lock_.lock();
#endif
    CHECK(observer_ == nullptr);
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
    if (observer_ != nullptr) {
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

template <class FdT>
void sync_with_poll(const FdT &fd) {
  fd.get_poll_info().sync_with_poll();
}

template <class FdT>
bool can_read_local(const FdT &fd) {
  return fd.get_poll_info().get_flags_local().can_read() || fd.get_poll_info().get_flags_local().has_pending_error();
}

template <class FdT>
bool can_write_local(const FdT &fd) {
  return fd.get_poll_info().get_flags_local().can_write();
}

template <class FdT>
bool can_close_local(const FdT &fd) {
  return fd.get_poll_info().get_flags_local().can_close();
}

}  // namespace td
