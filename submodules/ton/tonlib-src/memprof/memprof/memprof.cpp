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
#undef NDEBUG
#include "memprof/memprof.h"

#include "td/utils/port/platform.h"

#if (TD_DARWIN || TD_LINUX) && defined(USE_MEMPROF)
#include <algorithm>
#include <atomic>
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <new>
#include <utility>
#include <vector>

#include <dlfcn.h>
#include <execinfo.h>

bool is_memprof_on() {
  return true;
}

#if USE_MEMPROF_SAFE
double get_fast_backtrace_success_rate() {
  return 0;
}
#else

#if TD_LINUX
extern void *__libc_stack_end;
#endif

static void *get_bp() {
  void *bp;
#if defined(__i386__)
  __asm__ volatile("movl %%ebp, %[r]" : [r] "=r"(bp));
#elif defined(__x86_64__)
  __asm__ volatile("movq %%rbp, %[r]" : [r] "=r"(bp));
#endif
  return bp;
}

static int fast_backtrace(void **buffer, int size) {
  struct stack_frame {
    stack_frame *bp;
    void *ip;
  };

  stack_frame *bp = reinterpret_cast<stack_frame *>(get_bp());
  int i = 0;
  while (i < size &&
#if TD_LINUX
         static_cast<void *>(bp) <= __libc_stack_end &&
#endif
         !(reinterpret_cast<std::uintptr_t>(static_cast<void *>(bp)) & (sizeof(void *) - 1))) {
    void *ip = bp->ip;
    buffer[i++] = ip;
    stack_frame *p = bp->bp;
    if (p <= bp) {
      break;
    }
    bp = p;
  }
  return i;
}

static std::atomic<std::size_t> fast_backtrace_failed_cnt;
static std::atomic<std::size_t> backtrace_total_cnt;
double get_fast_backtrace_success_rate() {
  return 1 - static_cast<double>(fast_backtrace_failed_cnt.load(std::memory_order_relaxed)) /
                 static_cast<double>(std::max(std::size_t(1), backtrace_total_cnt.load(std::memory_order_relaxed)));
}

#endif

static Backtrace get_backtrace() {
  static __thread bool in_backtrace;  // static zero-initialized
  Backtrace res{{nullptr}};
  if (in_backtrace) {
    return res;
  }
  in_backtrace = true;
  std::array<void *, res.size() + BACKTRACE_SHIFT + 10> tmp{{nullptr}};
  std::size_t n;
#if USE_MEMPROF_SAFE
  n = backtrace(tmp.data(), static_cast<int>(tmp.size()));
#else
  n = fast_backtrace(tmp.data(), static_cast<int>(tmp.size()));
  auto from_shared = [](void *ptr) {
    return reinterpret_cast<std::uintptr_t>(ptr) > static_cast<std::uintptr_t>(0x700000000000ull);
  };

#if !USE_MEMPROF_FAST
  auto end = tmp.begin() + std::min(res.size() + BACKTRACE_SHIFT, n);
  if (std::find_if(tmp.begin(), end, from_shared) != end) {
    fast_backtrace_failed_cnt.fetch_add(1, std::memory_order_relaxed);
    n = backtrace(tmp.data(), static_cast<int>(tmp.size()));
  }
  backtrace_total_cnt.fetch_add(1, std::memory_order_relaxed);
#endif
  n = std::remove_if(tmp.begin(), tmp.begin() + n, from_shared) - tmp.begin();
#endif
  n = std::min(res.size() + BACKTRACE_SHIFT, n);

  for (std::size_t i = BACKTRACE_SHIFT; i < n; i++) {
    res[i - BACKTRACE_SHIFT] = tmp[i];
  }
  in_backtrace = false;
  return res;
}

static constexpr std::size_t reserved = 16;
static constexpr std::int32_t malloc_info_magic = 0x27138373;
struct malloc_info {
  std::int32_t magic;
  std::uint32_t size;
  std::int32_t offset;
  std::int32_t ht_pos;
};

static std::uint64_t get_hash(const Backtrace &bt) {
  std::uint64_t h = 7;
  for (std::size_t i = 0; i < bt.size() && i < BACKTRACE_HASHED_LENGTH; i++) {
    h = h * 0x4372897893428797lu + reinterpret_cast<std::uintptr_t>(bt[i]);
  }
  return h;
}

struct HashtableNode {
  std::atomic<std::uint64_t> hash;
  Backtrace backtrace;
  std::atomic<std::size_t> size;
};

static constexpr std::size_t ht_max_size = 1000000;
static std::atomic<std::size_t> ht_size{0};
static std::array<HashtableNode, ht_max_size> ht;

std::size_t get_ht_size() {
  return ht_size.load();
}

std::int32_t get_ht_pos(const Backtrace &bt, bool force = false) {
  auto hash = get_hash(bt);
  std::int32_t pos = static_cast<std::int32_t>(hash % ht.size());
  bool was_overflow = false;
  while (true) {
    auto pos_hash = ht[pos].hash.load();
    if (pos_hash == 0) {
      if (ht_size > ht_max_size / 2) {
        if (force) {
          assert(ht_size * 10 < ht_max_size * 7);
        } else {
          Backtrace unknown_bt{{nullptr}};
          unknown_bt[0] = reinterpret_cast<void *>(1);
          return get_ht_pos(unknown_bt, true);
        }
      }

      std::uint64_t expected = 0;
      if (ht[pos].hash.compare_exchange_strong(expected, hash)) {
        ht[pos].backtrace = bt;
        ++ht_size;
        return pos;
      }
    } else if (pos_hash == hash) {
      return pos;
    } else {
      pos++;
      if (pos == static_cast<std::int32_t>(ht.size())) {
        pos = 0;
        if (was_overflow) {
          // unreachable
          std::abort();
        }
        was_overflow = true;
      }
    }
  }
}

void dump_alloc(const std::function<void(const AllocInfo &)> &func) {
  for (auto &node : ht) {
    if (node.size == 0) {
      continue;
    }
    func(AllocInfo{node.backtrace, node.size.load()});
  }
}

void register_xalloc(malloc_info *info, std::int32_t diff) {
  if (diff > 0) {
    ht[info->ht_pos].size += info->size;
  } else {
    assert(ht[info->ht_pos].size >= info->size);
    ht[info->ht_pos].size -= info->size;
  }
  assert(info->magic == malloc_info_magic);
  assert(info->size < 1000000000000ull);
  assert(ht[info->ht_pos].size < 1000000000000ull);
}

extern "C" {

static void *malloc_with_frame(std::size_t size, const Backtrace &frame, std::size_t aligment = 0) {
  static_assert(reserved % alignof(std::max_align_t) == 0, "fail");
  static_assert(reserved >= sizeof(malloc_info), "fail");
#if TD_DARWIN
  static void *malloc_void = dlsym(RTLD_NEXT, "malloc");
  static auto malloc_old = *reinterpret_cast<decltype(malloc) **>(&malloc_void);
#else
  extern decltype(malloc) __libc_malloc;
  static auto malloc_old = __libc_malloc;
#endif
  if (aligment < alignof(std::max_align_t)) {
    aligment = 0;
  }
  assert(aligment % alignof(std::max_align_t) == 0);
  std::size_t extra = aligment == 0 ? 0 : aligment - alignof(std::max_align_t);
  auto *ptr = malloc_old(size + reserved + extra);
  std::int32_t offset = 0;
  if (aligment != 0) {
    // (ptr + reserved + offset) % aligment == 0
    offset =
        static_cast<std::int32_t>((aligment - (reinterpret_cast<std::size_t>(ptr) + reserved) % aligment) % aligment);
    assert(offset % alignof(std::max_align_t) == 0);
    assert(static_cast<std::size_t>(offset) <= extra);
    ptr = static_cast<void *>(static_cast<char *>(ptr) + offset);
  }
  auto *info = static_cast<malloc_info *>(ptr);
  auto *buf = reinterpret_cast<char *>(info);

  info->magic = malloc_info_magic;
  info->size = static_cast<std::uint32_t>(size);
  assert(info->size == size);
  info->offset = offset;
  info->ht_pos = get_ht_pos(frame);

  register_xalloc(info, +1);

  void *data = buf + reserved;

  if (aligment != 0) {
    assert(reinterpret_cast<std::size_t>(data) % aligment == 0);
  }

  return data;
}

static malloc_info *get_info(void *data_void) {
  char *data = static_cast<char *>(data_void);
  auto *buf = data - reserved;

  auto *info = reinterpret_cast<malloc_info *>(buf);
  assert(info->magic == malloc_info_magic);
  return info;
}

void *malloc(std::size_t size) {
  return malloc_with_frame(size, get_backtrace());
}

void free(void *data_void) {
  if (data_void == nullptr) {
    return;
  }
  auto *info = get_info(data_void);
  register_xalloc(info, -1);
  auto ptr = static_cast<char *>(static_cast<void *>(info));
  info->magic = 0;
  ptr -= info->offset;

#if TD_DARWIN
  static void *free_void = dlsym(RTLD_NEXT, "free");
  static auto free_old = *reinterpret_cast<decltype(free) **>(&free_void);
#else
  extern decltype(free) __libc_free;
  static auto free_old = __libc_free;
#endif
  return free_old(ptr);
}
void *calloc(std::size_t size_a, std::size_t size_b) {
  auto size = size_a * size_b;
  void *res = malloc_with_frame(size, get_backtrace());
  std::memset(res, 0, size);
  return res;
}
void *realloc(void *ptr, std::size_t size) {
  if (ptr == nullptr) {
    return malloc_with_frame(size, get_backtrace());
  }
  auto *info = get_info(ptr);
  auto *new_ptr = malloc_with_frame(size, get_backtrace());
  auto to_copy = std::min(static_cast<std::uint32_t>(size), info->size);
  std::memcpy(new_ptr, ptr, to_copy);
  free(ptr);
  return new_ptr;
}
int posix_memalign(void **res, std::size_t aligment, std::size_t size) {
  *res = malloc_with_frame(size, get_backtrace(), aligment);
  return 0;
}
void *memalign(std::size_t aligment, std::size_t size) {
  return malloc_with_frame(size, get_backtrace(), aligment);
}
std::size_t malloc_usable_size(void *ptr) {
  if (ptr == nullptr) {
    return 0;
  }
  auto *info = get_info(ptr);
  return info->size + info->offset + reserved;
}
}

// c++14 guarantees that it is enough to override these two operators.
void *operator new(std::size_t count) {
  return malloc_with_frame(count, get_backtrace());
}
void operator delete(void *ptr) noexcept(true) {
  free(ptr);
}
// because of gcc warning: the program should also define 'void operator delete(void*, std::size_t)'
void operator delete(void *ptr, std::size_t) noexcept(true) {
  free(ptr);
}

// c++17
// void *operator new(std::size_t count, std::align_val_t al);
// void operator delete(void *ptr, std::align_val_t al);

#else
bool is_memprof_on() {
  return false;
}
void dump_alloc(const std::function<void(const AllocInfo &)> &func) {
}
double get_fast_backtrace_success_rate() {
  return 0;
}
std::size_t get_ht_size() {
  return 0;
}
#endif

std::size_t get_used_memory_size() {
  std::size_t res = 0;
  dump_alloc([&](const auto info) { res += info.size; });
  return res;
}
