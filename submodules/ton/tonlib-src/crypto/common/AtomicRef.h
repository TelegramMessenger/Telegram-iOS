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
#pragma once

#include "td/utils/SpinLock.h"
#include "common/refcnt.hpp"

#include <type_traits>

namespace td {
template <class T>
class AtomicRefSpinlock {
 public:
  AtomicRefSpinlock() = default;
  AtomicRefSpinlock(Ref<T>&& ref) : ref_(ref.release()) {
  }
  ~AtomicRefSpinlock() {
    Ref<T>(ref_.load(std::memory_order_relaxed), typename Ref<T>::acquire_t{});
  }
  AtomicRefSpinlock(AtomicRefSpinlock&&) = delete;
  AtomicRefSpinlock& operator=(AtomicRefSpinlock&&) = delete;
  AtomicRefSpinlock(const AtomicRefSpinlock&) = delete;
  AtomicRefSpinlock& operator=(const AtomicRefSpinlock&) = delete;

  Ref<T> load() const {
    auto guard = spin_lock_.lock();
    return Ref<T>(ref_.load(std::memory_order_relaxed));
  }
  Ref<T> extract() const {
    auto guard = spin_lock_.lock();
    return Ref<T>(ref_.exchange(nullptr, std::memory_order_release), typename Ref<T>::acquire_t{});
  }

  Ref<T> load_unsafe() const {
    return Ref<T>(get_unsafe());
  }
  const T* get_unsafe() const {
    return ref_.load(std::memory_order_acquire);
  }
  bool store_if_empty(Ref<T>& desired) {
    auto guard = spin_lock_.lock();
    if (ref_.load(std::memory_order_relaxed) == nullptr) {
      ref_.store(desired.release(), std::memory_order_release);
      return true;
    }
    return false;
  }

  void store(Ref<T>&& ref) {
    auto guard = spin_lock_.lock();
    Ref<T>(ref_.exchange(ref.release(), std::memory_order_acq_rel), typename Ref<T>::acquire_t{});
  }

 private:
  mutable SpinLock spin_lock_;
  std::atomic<T*> ref_{nullptr};
};

template <class T>
class AtomicRefLockfree {
 public:
  AtomicRefLockfree() = default;
  static constexpr int BATCH_SIZE = 100;
  AtomicRefLockfree(Ref<T>&& ref) : ptr_(Ptr(ref.release(), BATCH_SIZE)) {
    Ref<T>::acquire_shared(ptr_.load(std::memory_order_relaxed).ptr(), BATCH_SIZE);
  }
  ~AtomicRefLockfree() {
    auto ptr = ptr_.load(std::memory_order_relaxed);
    if (ptr.ptr()) {
      Ref<T>::release_shared(ptr.ptr(), ptr.ref_cnt() + 1);
    }
  }
  AtomicRefLockfree(AtomicRefLockfree&&) = delete;
  AtomicRefLockfree& operator=(AtomicRefLockfree&&) = delete;
  AtomicRefLockfree(const AtomicRefLockfree&) = delete;
  AtomicRefLockfree& operator=(const AtomicRefLockfree&) = delete;

  Ref<T> load() const {
    auto ptr = ptr_.load();
    while (ptr.ptr()) {
      if (ptr.ref_cnt() == 0) {
        td::this_thread::yield();
        ptr = ptr_.load();
        continue;
      }
      auto new_ptr = Ptr(ptr.ptr(), ptr.ref_cnt() - 1);
      if (ptr_.compare_exchange_weak(ptr, new_ptr)) {
        if (new_ptr.ref_cnt() < BATCH_SIZE / 2) {
          try_reserve(ptr.ptr());
        }
        return Ref<T>(ptr.ptr(), typename Ref<T>::acquire_t{});
      }
    }
    return {};
  }
  void try_reserve(T* raw_ptr) const {
    int reserve_cnt = BATCH_SIZE;
    Ref<T>::acquire_shared(raw_ptr, reserve_cnt);
    auto ptr = ptr_.load();
    while (ptr.ptr() == raw_ptr && ptr.ref_cnt() < BATCH_SIZE / 2) {
      auto new_ptr = Ptr(ptr.ptr(), ptr.ref_cnt() + reserve_cnt);
      if (ptr_.compare_exchange_weak(ptr, new_ptr)) {
        return;
      }
    }
    Ref<T>::release_shared(raw_ptr, reserve_cnt);
  }
  Ref<T> extract() {
    auto ptr = ptr_.exchange({});
    if (ptr.ref_cnt() != 0) {
      Ref<T>::release_shared(ptr.ptr(), ptr.ref_cnt());
    }

    return Ref<T>(ptr.ptr(), typename Ref<T>::acquire_t{});
  }

  Ref<T> load_unsafe() const {
    return load();
  }
  T* get_unsafe() const {
    return ptr_.load().ptr();
  }
  bool store_if_empty(Ref<T>& desired) {
    auto raw_ptr = desired.get();
    Ref<T>::acquire_shared(raw_ptr, BATCH_SIZE + 1);

    Ptr new_ptr{const_cast<T*>(raw_ptr), BATCH_SIZE};
    auto ptr = ptr_.load();
    while (ptr.ptr() == nullptr) {
      if (ptr_.compare_exchange_weak(ptr, new_ptr)) {
        return true;
      }
    }
    Ref<T>::release_shared(raw_ptr, BATCH_SIZE + 1);
    return false;
  }

  void store(Ref<T>&& ref) {
    Ptr new_ptr = [&]() -> Ptr {
      if (ref.is_null()) {
        return {};
      }
      auto raw_ptr = ref.release();
      Ref<T>::acquire_shared(raw_ptr, BATCH_SIZE);
      return {raw_ptr, BATCH_SIZE};
    }();

    auto ptr = ptr_.load();
    while (!ptr_.compare_exchange_weak(ptr, new_ptr)) {
    }

    if (ptr.ptr()) {
      Ref<T>::release_shared(ptr.ptr(), ptr.ref_cnt() + 1);
    }
  }

 private:
  struct Ptr {
   public:
    Ptr() = default;
    Ptr(T* ptr, int ref_cnt) {
      data_ = reinterpret_cast<td::uint64>(ptr);
      CHECK((data_ >> 48) == 0);
      data_ |= static_cast<td::uint64>(ref_cnt) << 48;
    }
    T* ptr() const {
      return reinterpret_cast<T*>(data_ & (std::numeric_limits<uint64>::max() >> 16));
    }
    int ref_cnt() const {
      return static_cast<int>(data_ >> 48);
    }

   private:
    td::uint64 data_{0};
  };
  static_assert(sizeof(Ptr) == 8, "sizeof(Ptr) must be 8 for atomic to work fine");
  static_assert(std::is_trivially_copyable<Ptr>::value, "Ptr must be tribially copyable");

  mutable std::atomic<Ptr> ptr_{Ptr()};
};

template <class T>
using AtomicRef = AtomicRefLockfree<T>;
}  // namespace td
