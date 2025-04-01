//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

namespace td {

class StackAllocator {
 public:
  class AllocatorImpl {
   public:
    AllocatorImpl() = default;
    AllocatorImpl(const AllocatorImpl &) = delete;
    AllocatorImpl &operator=(const AllocatorImpl &) = delete;
    AllocatorImpl(AllocatorImpl &&) = delete;
    AllocatorImpl &operator=(AllocatorImpl &&) = delete;
    virtual ~AllocatorImpl() = default;

    virtual MutableSlice allocate(size_t size) = 0;

    virtual void free_ptr(char *ptr, size_t size) = 0;
  };

 private:
  class Ptr {
   public:
    Ptr(AllocatorImpl *allocator, size_t size) : allocator_(allocator), slice_(allocator_->allocate(size)) {
    }
    Ptr(const Ptr &) = delete;
    Ptr &operator=(const Ptr &) = delete;
    Ptr(Ptr &&other) noexcept : allocator_(other.allocator_), slice_(other.slice_) {
      other.allocator_ = nullptr;
      other.slice_ = MutableSlice();
    }
    Ptr &operator=(Ptr &&) = delete;
    ~Ptr();

    MutableSlice as_slice() const {
      return slice_;
    }

   private:
    AllocatorImpl *allocator_;
    MutableSlice slice_;
  };

  static AllocatorImpl *impl();

 public:
  static Ptr alloc(size_t size) {
    return Ptr(impl(), size);
  }
};

}  // namespace td
