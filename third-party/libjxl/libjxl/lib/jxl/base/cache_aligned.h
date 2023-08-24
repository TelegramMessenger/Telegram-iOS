// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_BASE_CACHE_ALIGNED_H_
#define LIB_JXL_BASE_CACHE_ALIGNED_H_

// Memory allocator with support for alignment + misalignment.

#include <stddef.h>
#include <stdint.h>

#include <memory>

#include "lib/jxl/base/compiler_specific.h"

namespace jxl {

// Functions that depend on the cache line size.
class CacheAligned {
 public:
  static void PrintStats();

  static constexpr size_t kPointerSize = sizeof(void*);
  static constexpr size_t kCacheLineSize = 64;
  // To avoid RFOs, match L2 fill size (pairs of lines).
  static constexpr size_t kAlignment = 2 * kCacheLineSize;
  // Minimum multiple for which cache set conflicts and/or loads blocked by
  // preceding stores can occur.
  static constexpr size_t kAlias = 2048;

  // Returns a 'random' (cyclical) offset suitable for Allocate.
  static size_t NextOffset();

  // Returns null or memory whose address is congruent to `offset` (mod kAlias).
  // This reduces cache conflicts and load/store stalls, especially with large
  // allocations that would otherwise have similar alignments. At least
  // `payload_size` (which can be zero) bytes will be accessible.
  static void* Allocate(size_t payload_size, size_t offset);

  static void* Allocate(const size_t payload_size) {
    return Allocate(payload_size, NextOffset());
  }

  static void Free(const void* aligned_pointer);
};

// Avoids the need for a function pointer (deleter) in CacheAlignedUniquePtr.
struct CacheAlignedDeleter {
  void operator()(uint8_t* aligned_pointer) const {
    return CacheAligned::Free(aligned_pointer);
  }
};

using CacheAlignedUniquePtr = std::unique_ptr<uint8_t[], CacheAlignedDeleter>;

// Does not invoke constructors.
static inline CacheAlignedUniquePtr AllocateArray(const size_t bytes) {
  return CacheAlignedUniquePtr(
      static_cast<uint8_t*>(CacheAligned::Allocate(bytes)),
      CacheAlignedDeleter());
}

static inline CacheAlignedUniquePtr AllocateArray(const size_t bytes,
                                                  const size_t offset) {
  return CacheAlignedUniquePtr(
      static_cast<uint8_t*>(CacheAligned::Allocate(bytes, offset)),
      CacheAlignedDeleter());
}

}  // namespace jxl

#endif  // LIB_JXL_BASE_CACHE_ALIGNED_H_
