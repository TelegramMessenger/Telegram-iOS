// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/cache_aligned.h"

#include <stdio.h>
#include <stdlib.h>

// Disabled: slower than malloc + alignment.
#define JXL_USE_MMAP 0

#if JXL_USE_MMAP
#include <sys/mman.h>
#endif

#include <algorithm>  // std::max
#include <atomic>
#include <hwy/base.h>  // kMaxVectorSize
#include <limits>

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace {

#pragma pack(push, 1)
struct AllocationHeader {
  void* allocated;
  size_t allocated_size;
  uint8_t left_padding[hwy::kMaxVectorSize];
};
#pragma pack(pop)

std::atomic<uint64_t> num_allocations{0};
std::atomic<uint64_t> bytes_in_use{0};
std::atomic<uint64_t> max_bytes_in_use{0};

}  // namespace

// Avoids linker errors in pre-C++17 builds.
constexpr size_t CacheAligned::kPointerSize;
constexpr size_t CacheAligned::kCacheLineSize;
constexpr size_t CacheAligned::kAlignment;
constexpr size_t CacheAligned::kAlias;

void CacheAligned::PrintStats() {
  fprintf(
      stderr, "Allocations: %" PRIuS " (max bytes in use: %E)\n",
      static_cast<size_t>(num_allocations.load(std::memory_order_relaxed)),
      static_cast<double>(max_bytes_in_use.load(std::memory_order_relaxed)));
}

size_t CacheAligned::NextOffset() {
  static std::atomic<uint32_t> next{0};
  constexpr uint32_t kGroups = CacheAligned::kAlias / CacheAligned::kAlignment;
  const uint32_t group = next.fetch_add(1, std::memory_order_relaxed) % kGroups;
  return CacheAligned::kAlignment * group;
}

void* CacheAligned::Allocate(const size_t payload_size, size_t offset) {
  JXL_ASSERT(payload_size <= std::numeric_limits<size_t>::max() / 2);
  JXL_ASSERT((offset % kAlignment == 0) && offset <= kAlias);

  // What: | misalign | unused | AllocationHeader |payload
  // Size: |<= kAlias | offset |                  |payload_size
  //       ^allocated.^aligned.^header............^payload
  // The header must immediately precede payload, which must remain aligned.
  // To avoid wasting space, the header resides at the end of `unused`,
  // which therefore cannot be empty (offset == 0).
  if (offset == 0) {
    // SVE/RVV vectors can be large, so we cannot rely on them (including the
    // padding at the end of AllocationHeader) to fit in kAlignment.
    offset = hwy::RoundUpTo(sizeof(AllocationHeader), kAlignment);
  }

#if JXL_USE_MMAP
  const size_t allocated_size = offset + payload_size;
  const int flags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE;
  void* allocated =
      mmap(nullptr, allocated_size, PROT_READ | PROT_WRITE, flags, -1, 0);
  if (allocated == MAP_FAILED) return nullptr;
  const uintptr_t aligned = reinterpret_cast<uintptr_t>(allocated);
#else
  const size_t allocated_size = kAlias + offset + payload_size;
  void* allocated = malloc(allocated_size);
  if (allocated == nullptr) return nullptr;
  // Always round up even if already aligned - we already asked for kAlias
  // extra bytes and there's no way to give them back.
  uintptr_t aligned = reinterpret_cast<uintptr_t>(allocated) + kAlias;
  static_assert((kAlias & (kAlias - 1)) == 0, "kAlias must be a power of 2");
  static_assert(kAlias >= kAlignment, "Cannot align to more than kAlias");
  aligned &= ~(kAlias - 1);
#endif

#if 0
  // No effect.
  uintptr_t page_aligned = reinterpret_cast<uintptr_t>(allocated);
  page_aligned &= ~(4096 - 1);
  if (madvise(reinterpret_cast<void*>(page_aligned), allocated_size,
              MADV_WILLNEED) != 0) {
    JXL_NOTIFY_ERROR("madvise failed");
  }
#elif 0
  // INCREASES both first and subsequent decode times.
  if (mlock(allocated, allocated_size) != 0) {
    JXL_NOTIFY_ERROR("mlock failed");
  }
#endif

  // Update statistics (#allocations and max bytes in use)
  num_allocations.fetch_add(1, std::memory_order_relaxed);
  const uint64_t prev_bytes =
      bytes_in_use.fetch_add(allocated_size, std::memory_order_acq_rel);
  uint64_t expected_max = max_bytes_in_use.load(std::memory_order_acquire);
  for (;;) {
    const uint64_t desired =
        std::max(expected_max, prev_bytes + allocated_size);
    if (max_bytes_in_use.compare_exchange_strong(expected_max, desired,
                                                 std::memory_order_acq_rel)) {
      break;
    }
  }

  const uintptr_t payload = aligned + offset;  // still aligned

  // Stash `allocated` and payload_size inside header for use by Free().
  AllocationHeader* header = reinterpret_cast<AllocationHeader*>(payload) - 1;
  header->allocated = allocated;
  header->allocated_size = allocated_size;

  return JXL_ASSUME_ALIGNED(reinterpret_cast<void*>(payload), 64);
}

void CacheAligned::Free(const void* aligned_pointer) {
  if (aligned_pointer == nullptr) {
    return;
  }
  const uintptr_t payload = reinterpret_cast<uintptr_t>(aligned_pointer);
  JXL_ASSERT(payload % kAlignment == 0);
  const AllocationHeader* header =
      reinterpret_cast<const AllocationHeader*>(payload) - 1;

  // Subtract (2's complement negation).
  bytes_in_use.fetch_add(~header->allocated_size + 1,
                         std::memory_order_acq_rel);

#if JXL_USE_MMAP
  munmap(header->allocated, header->allocated_size);
#else
  free(header->allocated);
#endif
}

}  // namespace jxl
