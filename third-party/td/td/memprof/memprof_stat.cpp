//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "memprof/memprof_stat.h"

#include "td/utils/port/platform.h"

#if (TD_DARWIN || TD_LINUX)
#include <algorithm>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <new>
#include <utility>
#include <vector>

#include <dlfcn.h>
#include <execinfo.h>

bool is_memprof_on() {
  return true;
}

#define my_assert(f) \
  if (!(f)) {        \
    std::abort();    \
  }

struct malloc_info {
  std::int32_t magic;
  std::int32_t size;
};

static std::atomic<std::size_t> total_memory_used;

void register_xalloc(malloc_info *info, std::int32_t diff) {
  my_assert(info->size >= 0);
  // TODO: this is very slow in case of several threads.
  // Currently, the statistics are intended only for memory benchmarks.
  total_memory_used.fetch_add(diff * info->size, std::memory_order_relaxed);
}

std::size_t get_used_memory_size() {
  return total_memory_used.load();
}

extern "C" {

static constexpr std::size_t RESERVED_SIZE = 16;
static constexpr std::int32_t MALLOC_INFO_MAGIC = 0x27138373;

static void *do_malloc(std::size_t size) {
  static_assert(RESERVED_SIZE % alignof(std::max_align_t) == 0, "fail");
  static_assert(RESERVED_SIZE >= sizeof(malloc_info), "fail");
#if TD_DARWIN
  static void *malloc_void = dlsym(RTLD_NEXT, "malloc");
  static auto malloc_old = *reinterpret_cast<decltype(malloc) **>(&malloc_void);
#else
  extern decltype(malloc) __libc_malloc;
  static auto malloc_old = __libc_malloc;
#endif
  auto *info = static_cast<malloc_info *>(malloc_old(size + RESERVED_SIZE));
  auto *buf = reinterpret_cast<char *>(info);

  info->magic = MALLOC_INFO_MAGIC;
  info->size = static_cast<std::int32_t>(size);

  register_xalloc(info, +1);

  void *data = buf + RESERVED_SIZE;

  return data;
}

static malloc_info *get_info(void *data_void) {
  auto *data = static_cast<char *>(data_void);
  auto *buf = data - RESERVED_SIZE;

  auto *info = reinterpret_cast<malloc_info *>(buf);
  my_assert(info->magic == MALLOC_INFO_MAGIC);
  return info;
}

void *malloc(std::size_t size) {
  return do_malloc(size);
}

void free(void *data_void) {
  if (data_void == nullptr) {
    return;
  }
  auto *info = get_info(data_void);
  register_xalloc(info, -1);

#if TD_DARWIN
  static void *free_void = dlsym(RTLD_NEXT, "free");
  static auto free_old = *reinterpret_cast<decltype(free) **>(&free_void);
#else
  extern decltype(free) __libc_free;
  static auto free_old = __libc_free;
#endif
  return free_old(info);
}

void *calloc(std::size_t size_a, std::size_t size_b) {
  auto size = size_a * size_b;
  void *res = do_malloc(size);
  std::memset(res, 0, size);
  return res;
}

void *realloc(void *ptr, std::size_t size) {
  if (ptr == nullptr) {
    return do_malloc(size);
  }
  auto *info = get_info(ptr);
  auto *new_ptr = do_malloc(size);
  auto to_copy = std::min(static_cast<std::int32_t>(size), info->size);
  std::memcpy(new_ptr, ptr, to_copy);
  free(ptr);
  return new_ptr;
}

void *memalign(std::size_t alignment, std::size_t size) {
  auto res = malloc(size);
  my_assert(reinterpret_cast<std::uintptr_t>(res) % alignment == 0);
  return res;
}

int posix_memalign(void **memptr, size_t alignment, size_t size) {
  auto res = malloc(size);
  my_assert(reinterpret_cast<std::uintptr_t>(res) % alignment == 0);
  *memptr = res;
  return 0;
}
}

// C++17 guarantees that it is enough to override these 4 operators
void *operator new(std::size_t count) {
  return malloc_with_frame(count, get_backtrace());
}
void operator delete(void *ptr) noexcept(true) {
  free(ptr);
}
void *operator new(std::size_t count, std::align_val_t al) {
  return memalign(static_cast<std::size_t>(al), count);
}
void operator delete(void *ptr, std::align_val_t al) noexcept {
  free(ptr);
}

// because of GCC warning: the program should also define 'void operator delete(void*, std::size_t)'
void operator delete(void *ptr, std::size_t) noexcept(true) {
  free(ptr);
}

#else
bool is_memprof_on() {
  return false;
}
std::size_t get_used_memory_size() {
  return 0;
}
#endif
