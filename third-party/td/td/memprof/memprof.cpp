//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "memprof/memprof.h"

#include "td/utils/port/platform.h"

#if (TD_DARWIN || TD_LINUX) && defined(USE_MEMPROF)
#include <algorithm>
#include <atomic>
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

#define my_assert(f) \
  if (!(f)) {        \
    std::abort();    \
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

  auto *bp = reinterpret_cast<stack_frame *>(get_bp());
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

static constexpr std::size_t RESERVED_SIZE = 16;
static constexpr std::int32_t MALLOC_INFO_MAGIC = 0x27138373;
struct malloc_info {
  std::int32_t magic;
  std::int32_t size;
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

static constexpr std::size_t HT_MAX_SIZE = 10000000;
static std::atomic<std::size_t> ht_size{0};
static std::array<HashtableNode, HT_MAX_SIZE> ht;

std::size_t get_ht_size() {
  return ht_size.load();
}

std::int32_t get_ht_pos(const Backtrace &bt, bool force = false) {
  auto hash = get_hash(bt);
  auto pos = static_cast<std::int32_t>(hash % ht.size());
  bool was_overflow = false;
  while (true) {
    auto pos_hash = ht[pos].hash.load();
    if (pos_hash == 0) {
      if (ht_size > HT_MAX_SIZE / 2) {
        if (force) {
          my_assert(ht_size * 10 < HT_MAX_SIZE * 7);
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
    auto size = node.size.load(std::memory_order_relaxed);
    if (size == 0) {
      continue;
    }
    func(AllocInfo{node.backtrace, size});
  }
}

void register_xalloc(malloc_info *info, std::int32_t diff) {
  my_assert(info->size >= 0);
  if (diff > 0) {
    ht[info->ht_pos].size.fetch_add(info->size, std::memory_order_relaxed);
  } else {
    auto old_value = ht[info->ht_pos].size.fetch_sub(info->size, std::memory_order_relaxed);
    my_assert(old_value >= static_cast<std::size_t>(info->size));
  }
}

extern "C" {

static void *malloc_with_frame(std::size_t size, const Backtrace &frame) {
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
  info->ht_pos = get_ht_pos(frame);

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
  return malloc_with_frame(size, get_backtrace());
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
  auto to_copy = std::min(static_cast<std::int32_t>(size), info->size);
  std::memcpy(new_ptr, ptr, to_copy);
  free(ptr);
  return new_ptr;
}

void *memalign(std::size_t alignment, std::size_t size) {
  my_assert(false && "Memalign is unsupported");
  return nullptr;
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
