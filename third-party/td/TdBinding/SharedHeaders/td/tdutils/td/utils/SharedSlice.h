//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

#include <atomic>
#include <memory>
#include <new>
#include <type_traits>

namespace td {

namespace detail {
struct SharedSliceHeader {
  explicit SharedSliceHeader(size_t size) : size_{size} {
  }

  void inc() {
    refcnt_.fetch_add(1, std::memory_order_relaxed);
  }

  bool dec() {
    return refcnt_.fetch_sub(1, std::memory_order_acq_rel) == 1;
  }

  bool is_unique() const {
    // NB: race if std::memory_order_relaxed is used
    // reader may see a change by a new writer
    return refcnt_.load(std::memory_order_acquire) == 1;
  }

  size_t size() const {
    return size_;
  }

 private:
  std::atomic<uint64> refcnt_{1};
  size_t size_;
};

struct UniqueSliceHeader {
  explicit UniqueSliceHeader(size_t size) : size_{size} {
  }

  void inc() {
  }

  bool dec() {
    return true;
  }

  bool is_unique() const {
    return true;
  }

  size_t size() const {
    return size_;
  }

 private:
  size_t size_;
};

template <class HeaderT, bool zero_on_destruct = false>
class UnsafeSharedSlice {
 public:
  UnsafeSharedSlice() = default;
  UnsafeSharedSlice clone() const {
    if (is_null()) {
      return UnsafeSharedSlice();
    }
    header()->inc();
    return UnsafeSharedSlice(ptr_.get());
  }

  bool is_null() const {
    return !ptr_;
  }

  bool is_unique() const {
    if (is_null()) {
      return true;
    }
    return header()->is_unique();
  }

  MutableSlice as_mutable_slice() {
    if (is_null()) {
      return MutableSlice();
    }
    return MutableSlice(ptr_.get() + sizeof(HeaderT), header()->size());
  }

  Slice as_slice() const {
    if (is_null()) {
      return Slice();
    }
    return Slice(ptr_.get() + sizeof(HeaderT), header()->size());
  }

  size_t size() const {
    if (is_null()) {
      return 0;
    }
    return header()->size();
  }

  static UnsafeSharedSlice create(size_t size) {
    static_assert(std::is_standard_layout<HeaderT>::value, "HeaderT must have statdard layout");
    auto ptr = std::make_unique<char[]>(sizeof(HeaderT) + size);
    auto header_ptr = new (ptr.get()) HeaderT(size);
    CHECK(header_ptr == reinterpret_cast<HeaderT *>(ptr.get()));

    return UnsafeSharedSlice(std::move(ptr));
  }

  static UnsafeSharedSlice create(Slice slice) {
    auto res = create(slice.size());
    res.as_mutable_slice().copy_from(slice);
    return res;
  }

  void clear() {
    ptr_.reset();
  }

 private:
  explicit UnsafeSharedSlice(char *ptr) : ptr_(ptr) {
  }
  explicit UnsafeSharedSlice(std::unique_ptr<char[]> from) : ptr_(from.release()) {
  }

  HeaderT *header() const {
    return reinterpret_cast<HeaderT *>(ptr_.get());
  }

  struct SharedSliceDestructor {
    void operator()(char *ptr) {
      auto header = reinterpret_cast<HeaderT *>(ptr);
      if (header->dec()) {
        if (zero_on_destruct) {
          MutableSlice(ptr, sizeof(HeaderT) + header->size()).fill_zero_secure();
        }
        std::default_delete<char[]>()(ptr);
      }
    }
  };

  std::unique_ptr<char[], SharedSliceDestructor> ptr_;
};
}  // namespace detail

class BufferSlice;

class UniqueSharedSlice;

class SharedSlice {
  using Impl = detail::UnsafeSharedSlice<detail::SharedSliceHeader>;

 public:
  SharedSlice() = default;

  explicit SharedSlice(Slice slice) : impl_(Impl::create(slice)) {
  }

  explicit SharedSlice(UniqueSharedSlice from);

  SharedSlice(const char *ptr, size_t size) : SharedSlice(Slice(ptr, size)) {
  }

  SharedSlice clone() const {
    return SharedSlice(impl_.clone());
  }

  Slice as_slice() const {
    return impl_.as_slice();
  }

  BufferSlice clone_as_buffer_slice() const;

  operator Slice() const {
    return as_slice();
  }

  // like in std::string
  const char *data() const {
    return as_slice().data();
  }

  char operator[](size_t at) const {
    return as_slice()[at];
  }

  bool empty() const {
    return size() == 0;
  }

  size_t size() const {
    return impl_.size();
  }

  // like in std::string
  size_t length() const {
    return size();
  }

  void clear() {
    impl_.clear();
  }

 private:
  friend class UniqueSharedSlice;
  explicit SharedSlice(Impl impl) : impl_(std::move(impl)) {
  }
  Impl impl_;
};

class UniqueSharedSlice {
  using Impl = detail::UnsafeSharedSlice<detail::SharedSliceHeader>;

 public:
  UniqueSharedSlice() = default;

  explicit UniqueSharedSlice(size_t size) : impl_(Impl::create(size)) {
  }
  explicit UniqueSharedSlice(Slice slice) : impl_(Impl::create(slice)) {
  }

  UniqueSharedSlice(const char *ptr, size_t size) : UniqueSharedSlice(Slice(ptr, size)) {
  }
  explicit UniqueSharedSlice(SharedSlice from) : impl_() {
    if (from.impl_.is_unique()) {
      impl_ = std::move(from.impl_);
    } else {
      impl_ = Impl::create(from.as_slice());
    }
  }

  UniqueSharedSlice copy() const {
    return UniqueSharedSlice(as_slice());
  }

  Slice as_slice() const {
    return impl_.as_slice();
  }

  MutableSlice as_mutable_slice() {
    return impl_.as_mutable_slice();
  }

  operator Slice() const {
    return as_slice();
  }

  // like in std::string
  char *data() {
    return as_mutable_slice().data();
  }
  const char *data() const {
    return as_slice().data();
  }
  char operator[](size_t at) const {
    return as_slice()[at];
  }

  bool empty() const {
    return size() == 0;
  }

  size_t size() const {
    return impl_.size();
  }

  // like in std::string
  size_t length() const {
    return size();
  }

  void clear() {
    impl_.clear();
  }

 private:
  friend class SharedSlice;
  explicit UniqueSharedSlice(Impl impl) : impl_(std::move(impl)) {
  }
  Impl impl_;
};

inline SharedSlice::SharedSlice(UniqueSharedSlice from) : impl_(std::move(from.impl_)) {
}

template <bool zero_on_destruct>
class UniqueSliceImpl {
  using Impl = detail::UnsafeSharedSlice<detail::UniqueSliceHeader, zero_on_destruct>;

 public:
  UniqueSliceImpl() = default;

  explicit UniqueSliceImpl(size_t size) : impl_(Impl::create(size)) {
  }
  UniqueSliceImpl(size_t size, char c) : impl_(Impl::create(size)) {
    as_mutable_slice().fill(c);
  }
  explicit UniqueSliceImpl(Slice slice) : impl_(Impl::create(slice)) {
  }

  UniqueSliceImpl(const char *ptr, size_t size) : UniqueSliceImpl(Slice(ptr, size)) {
  }

  UniqueSliceImpl copy() const {
    return UniqueSliceImpl(as_slice());
  }

  Slice as_slice() const {
    return impl_.as_slice();
  }

  MutableSlice as_mutable_slice() {
    return impl_.as_mutable_slice();
  }

  operator Slice() const {
    return as_slice();
  }

  // like in std::string
  char *data() {
    return as_mutable_slice().data();
  }
  const char *data() const {
    return as_slice().data();
  }
  char operator[](size_t at) const {
    return as_slice()[at];
  }

  bool empty() const {
    return size() == 0;
  }

  size_t size() const {
    return impl_.size();
  }

  // like in std::string
  size_t length() const {
    return size();
  }

  void clear() {
    impl_.clear();
  }

 private:
  explicit UniqueSliceImpl(Impl impl) : impl_(std::move(impl)) {
  }
  Impl impl_;
};

using UniqueSlice = UniqueSliceImpl<false>;
using SecureString = UniqueSliceImpl<true>;

inline MutableSlice as_mutable_slice(UniqueSharedSlice &unique_shared_slice) {
  return unique_shared_slice.as_mutable_slice();
}

inline MutableSlice as_mutable_slice(UniqueSlice &unique_slice) {
  return unique_slice.as_mutable_slice();
}

inline MutableSlice as_mutable_slice(SecureString &secure_string) {
  return secure_string.as_mutable_slice();
}

}  // namespace td
