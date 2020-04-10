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

#include "td/utils/common.h"
#include "td/utils/MovableValue.h"
#include "td/utils/Slice.h"

#include <array>
#include <cstdlib>
#include <memory>

namespace td {

class StackAllocator {
  class Deleter {
   public:
    void operator()(char *ptr) {
      free_ptr(ptr);
    }
  };

  // TODO: alloc memory with mmap and unload unused pages
  // memory still can be corrupted, but it is better than explicit free function
  // TODO: use pointer that can't be even copied
  using PtrImpl = std::unique_ptr<char, Deleter>;
  class Ptr {
   public:
    Ptr(char *ptr, size_t size) : ptr_(ptr), size_(size) {
    }

    MutableSlice as_slice() const {
      return MutableSlice(ptr_.get(), size_.get());
    }

   private:
    PtrImpl ptr_;
    MovableValue<size_t> size_;
  };

  static void free_ptr(char *ptr) {
    impl().free_ptr(ptr);
  }

  struct Impl {
    static const size_t MEM_SIZE = 1024 * 1024;
    std::array<char, MEM_SIZE> mem;

    size_t pos{0};
    char *alloc(size_t size) {
      if (size == 0) {
        size = 1;
      }
      char *res = mem.data() + pos;
      size = (size + 7) & -8;
      pos += size;
      if (pos > MEM_SIZE) {
        std::abort();  // memory is over
      }
      return res;
    }
    void free_ptr(char *ptr) {
      size_t new_pos = ptr - mem.data();
      if (new_pos >= pos) {
        std::abort();  // shouldn't happen
      }
      pos = new_pos;
    }
  };

  static Impl &impl();

 public:
  static Ptr alloc(size_t size) {
    return Ptr(impl().alloc(size), size);
  }
};

}  // namespace td
