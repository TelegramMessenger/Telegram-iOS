//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/StackAllocator.h"

#include "td/utils/port/thread_local.h"

#include <array>
#include <cstdlib>

namespace td {
namespace {
class ArrayAllocator final : public StackAllocator::AllocatorImpl {
  static const size_t MEM_SIZE = 1024 * 1024;
  std::array<char, MEM_SIZE> mem;
  size_t pos{0};

  MutableSlice allocate(size_t size) final {
    if (size > MEM_SIZE) {
      std::abort();  // too much memory requested
    }
    char *res = mem.data() + pos;
    pos += (size + 7) & -8;
    if (pos > MEM_SIZE) {
      std::abort();  // memory is over
    }
    return {res, size};
  }

  void free_ptr(char *ptr, size_t size) final {
    size = (size + 7) & -8;
    if (size > pos || ptr != mem.data() + (pos - size)) {
      std::abort();  // shouldn't happen
    }
    pos -= size;
  }

 public:
  ~ArrayAllocator() final {
    if (pos != 0) {
      std::abort();  // shouldn't happen
    }
  }
};

class NewAllocator final : public StackAllocator::AllocatorImpl {
  MutableSlice allocate(size_t size) final {
    return {new char[size], size};
  }

  void free_ptr(char *ptr, size_t size) final {
    delete[] ptr;
  }

 public:
  ~NewAllocator() final = default;
};
}  // namespace

StackAllocator::Ptr::~Ptr() {
  if (!slice_.empty()) {
    allocator_->free_ptr(slice_.data(), slice_.size());
  }
}

StackAllocator::AllocatorImpl *StackAllocator::impl() {
  if (get_thread_id() != 0) {
    static TD_THREAD_LOCAL ArrayAllocator *array_allocator;  // static zero-initialized
    init_thread_local<ArrayAllocator>(array_allocator);
    return array_allocator;
  } else {
    static NewAllocator new_allocator;
    return &new_allocator;
  }
}

}  // namespace td
