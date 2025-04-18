// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_MEMORY_MANAGER_INTERNAL_H_
#define LIB_JXL_MEMORY_MANAGER_INTERNAL_H_

// Memory allocator with support for alignment + misalignment.

#include <jxl/memory_manager.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>  // memcpy

#include <atomic>
#include <memory>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"

namespace jxl {

// Default alloc and free functions.
void* MemoryManagerDefaultAlloc(void* opaque, size_t size);
void MemoryManagerDefaultFree(void* opaque, void* address);

// Initializes the memory manager instance with the passed one. The
// MemoryManager passed in |memory_manager| may be NULL or contain NULL
// functions which will be initialized with the default ones. If either alloc
// or free are NULL, then both must be NULL, otherwise this function returns an
// error.
static JXL_INLINE Status MemoryManagerInit(
    JxlMemoryManager* self, const JxlMemoryManager* memory_manager) {
  if (memory_manager) {
    *self = *memory_manager;
  } else {
    memset(self, 0, sizeof(*self));
  }
  if (!self->alloc != !self->free) {
    return false;
  }
  if (!self->alloc) self->alloc = jxl::MemoryManagerDefaultAlloc;
  if (!self->free) self->free = jxl::MemoryManagerDefaultFree;

  return true;
}

static JXL_INLINE void* MemoryManagerAlloc(
    const JxlMemoryManager* memory_manager, size_t size) {
  return memory_manager->alloc(memory_manager->opaque, size);
}

static JXL_INLINE void MemoryManagerFree(const JxlMemoryManager* memory_manager,
                                         void* address) {
  return memory_manager->free(memory_manager->opaque, address);
}

// Helper class to be used as a deleter in a unique_ptr<T> call.
class MemoryManagerDeleteHelper {
 public:
  explicit MemoryManagerDeleteHelper(const JxlMemoryManager* memory_manager)
      : memory_manager_(memory_manager) {}

  // Delete and free the passed pointer using the memory_manager.
  template <typename T>
  void operator()(T* address) const {
    if (!address) {
      return;
    }
    address->~T();
    return memory_manager_->free(memory_manager_->opaque, address);
  }

 private:
  const JxlMemoryManager* memory_manager_;
};

template <typename T>
using MemoryManagerUniquePtr = std::unique_ptr<T, MemoryManagerDeleteHelper>;

// Creates a new object T allocating it with the memory allocator into a
// unique_ptr.
template <typename T, typename... Args>
JXL_INLINE MemoryManagerUniquePtr<T> MemoryManagerMakeUnique(
    const JxlMemoryManager* memory_manager, Args&&... args) {
  T* mem =
      static_cast<T*>(memory_manager->alloc(memory_manager->opaque, sizeof(T)));
  if (!mem) {
    // Allocation error case.
    return MemoryManagerUniquePtr<T>(nullptr,
                                     MemoryManagerDeleteHelper(memory_manager));
  }
  return MemoryManagerUniquePtr<T>(new (mem) T(std::forward<Args>(args)...),
                                   MemoryManagerDeleteHelper(memory_manager));
}

}  // namespace jxl

#endif  // LIB_JXL_MEMORY_MANAGER_INTERNAL_H_
