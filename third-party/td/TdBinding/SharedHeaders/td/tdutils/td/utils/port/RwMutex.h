//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

#include "td/utils/common.h"

#if TD_PORT_POSIX
#include <pthread.h>
#endif

#include <memory>

namespace td {

class RwMutex {
 public:
  RwMutex() {
    init();
  }
  RwMutex(const RwMutex &) = delete;
  RwMutex &operator=(const RwMutex &) = delete;
  RwMutex(RwMutex &&other) noexcept {
    init();
    other.clear();
  }
  RwMutex &operator=(RwMutex &&other) noexcept {
    other.clear();
    return *this;
  }
  ~RwMutex() {
    clear();
  }

  bool empty() const {
    return !is_valid_;
  }

  void init();

  void clear();

  struct ReadUnlock {
    void operator()(RwMutex *ptr) {
      ptr->unlock_read_unsafe();
    }
  };
  struct WriteUnlock {
    void operator()(RwMutex *ptr) {
      ptr->unlock_write_unsafe();
    }
  };

  using ReadLock = std::unique_ptr<RwMutex, ReadUnlock>;
  using WriteLock = std::unique_ptr<RwMutex, WriteUnlock>;

  ReadLock lock_read() TD_WARN_UNUSED_RESULT {
    lock_read_unsafe();
    return ReadLock(this);
  }

  WriteLock lock_write() TD_WARN_UNUSED_RESULT {
    lock_write_unsafe();
    return WriteLock(this);
  }

  void lock_read_unsafe();

  void lock_write_unsafe();

  void unlock_read_unsafe();

  void unlock_write_unsafe();

 private:
  bool is_valid_ = false;
#if TD_PORT_POSIX
  pthread_rwlock_t mutex_;
#elif TD_PORT_WINDOWS
  unique_ptr<SRWLOCK> mutex_;
#endif
};

inline void RwMutex::init() {
  CHECK(empty());
  is_valid_ = true;
#if TD_PORT_POSIX
  pthread_rwlock_init(&mutex_, nullptr);
#elif TD_PORT_WINDOWS
  mutex_ = make_unique<SRWLOCK>();
  InitializeSRWLock(mutex_.get());
#endif
}

inline void RwMutex::clear() {
  if (is_valid_) {
#if TD_PORT_POSIX
    pthread_rwlock_destroy(&mutex_);
#elif TD_PORT_WINDOWS
    mutex_.release();
#endif
    is_valid_ = false;
  }
}

inline void RwMutex::lock_read_unsafe() {
  CHECK(!empty());
// TODO error handling
#if TD_PORT_POSIX
  pthread_rwlock_rdlock(&mutex_);
#elif TD_PORT_WINDOWS
  AcquireSRWLockShared(mutex_.get());
#endif
}

inline void RwMutex::lock_write_unsafe() {
  CHECK(!empty());
#if TD_PORT_POSIX
  pthread_rwlock_wrlock(&mutex_);
#elif TD_PORT_WINDOWS
  AcquireSRWLockExclusive(mutex_.get());
#endif
}

inline void RwMutex::unlock_read_unsafe() {
  CHECK(!empty());
#if TD_PORT_POSIX
  pthread_rwlock_unlock(&mutex_);
#elif TD_PORT_WINDOWS
  ReleaseSRWLockShared(mutex_.get());
#endif
}

inline void RwMutex::unlock_write_unsafe() {
  CHECK(!empty());
#if TD_PORT_POSIX
  pthread_rwlock_unlock(&mutex_);
#elif TD_PORT_WINDOWS
  ReleaseSRWLockExclusive(mutex_.get());
#endif
}

}  // namespace td
