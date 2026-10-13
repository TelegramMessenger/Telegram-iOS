/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "platform_api_vmcore.h"

#if defined(__APPLE__) || defined(__MACH__)
#include <libkern/OSCacheControl.h>
#include <TargetConditionals.h>
#endif

#ifndef BH_ENABLE_TRACE_MMAP
#define BH_ENABLE_TRACE_MMAP 0
#endif

#if BH_ENABLE_TRACE_MMAP != 0
static size_t total_size_mmapped = 0;
static size_t total_size_munmapped = 0;
#endif

#define HUGE_PAGE_SIZE (2 * 1024 * 1024)

#if !defined(__APPLE__) && !defined(__NuttX__) && defined(MADV_HUGEPAGE)
static inline uintptr_t
round_up(uintptr_t v, uintptr_t b)
{
    uintptr_t m = b - 1;
    return (v + m) & ~m;
}

static inline uintptr_t
round_down(uintptr_t v, uintptr_t b)
{
    uintptr_t m = b - 1;
    return v & ~m;
}
#endif

void *
os_mmap(void *hint, size_t size, int prot, int flags, os_file_handle file)
{
    int map_prot = PROT_NONE;
#if (defined(__APPLE__) || defined(__MACH__)) && defined(__arm64__) \
    && defined(TARGET_OS_OSX) && TARGET_OS_OSX != 0
    int map_flags = MAP_ANONYMOUS | MAP_PRIVATE | MAP_JIT;
#else
    int map_flags = MAP_ANONYMOUS | MAP_PRIVATE;
#endif
    uint64 request_size, page_size;
    uint8 *addr = MAP_FAILED;
    uint32 i;

    page_size = (uint64)getpagesize();
    request_size = (size + page_size - 1) & ~(page_size - 1);

#if !defined(__APPLE__) && !defined(__NuttX__) && defined(MADV_HUGEPAGE)
    /* huge page isn't supported on MacOS and NuttX */
    if (request_size >= HUGE_PAGE_SIZE)
        /* apply one extra huge page */
        request_size += HUGE_PAGE_SIZE;
#endif

    if ((size_t)request_size < size) {
        os_printf("mmap failed: request size overflow due to paging\n");
        return NULL;
    }

#if WASM_ENABLE_MEMORY64 == 0
    if (request_size > 16 * (uint64)UINT32_MAX) {
        os_printf("mmap failed: for memory64 at most 64G is allowed\n");
        return NULL;
    }
#endif

    if (prot & MMAP_PROT_READ)
        map_prot |= PROT_READ;

    if (prot & MMAP_PROT_WRITE)
        map_prot |= PROT_WRITE;

    if (prot & MMAP_PROT_EXEC)
        map_prot |= PROT_EXEC;

#if defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64)
#ifndef __APPLE__
    if (flags & MMAP_MAP_32BIT)
        map_flags |= MAP_32BIT;
#endif
#endif

    if (flags & MMAP_MAP_FIXED)
        map_flags |= MAP_FIXED;

#if defined(BUILD_TARGET_RISCV64_LP64D) || defined(BUILD_TARGET_RISCV64_LP64)
    /* As AOT relocation in RISCV64 may require that the code/data mapped
     * is in range 0 to 2GB, we try to map the memory with hint address
     * (mmap's first argument) to meet the requirement.
     */
    if (!hint && !(flags & MMAP_MAP_FIXED) && (flags & MMAP_MAP_32BIT)) {
        uint8 *stack_addr = (uint8 *)&map_prot;
        uint8 *text_addr = (uint8 *)os_mmap;
        /* hint address begins with 1MB */
        static uint8 *hint_addr = (uint8 *)(uintptr_t)BH_MB;

        if ((hint_addr - text_addr >= 0 && hint_addr - text_addr < 100 * BH_MB)
            || (text_addr - hint_addr >= 0
                && text_addr - hint_addr < 100 * BH_MB)) {
            /* hint address is possibly in text section, skip it */
            hint_addr += 100 * BH_MB;
        }

        if ((hint_addr - stack_addr >= 0 && hint_addr - stack_addr < 8 * BH_MB)
            || (stack_addr - hint_addr >= 0
                && stack_addr - hint_addr < 8 * BH_MB)) {
            /* hint address is possibly in native stack area, skip it */
            hint_addr += 8 * BH_MB;
        }

        /* try 10 times, step with 1MB each time */
        for (i = 0; i < 10 && hint_addr < (uint8 *)(uintptr_t)(2ULL * BH_GB);
             i++) {
            addr = mmap(hint_addr, request_size, map_prot, map_flags, file, 0);
            if (addr != MAP_FAILED) {
                if (addr > (uint8 *)(uintptr_t)(2ULL * BH_GB)) {
                    /* unmap and try again if the mapped address doesn't
                     * meet the requirement */
                    os_munmap(addr, request_size);
                }
                else {
                    /* success, reset next hint address */
                    hint_addr += request_size;
                    break;
                }
            }
            hint_addr += BH_MB;
        }
    }
#endif /* end of BUILD_TARGET_RISCV64_LP64D || BUILD_TARGET_RISCV64_LP64 */

    /* memory hasn't been mapped or was mapped failed previously */
    if (addr == MAP_FAILED) {
        /* try 5 times on EAGAIN or ENOMEM, and keep retrying on EINTR */
        i = 0;
        while (i < 5) {
            addr = mmap(hint, request_size, map_prot, map_flags, file, 0);
            if (addr != MAP_FAILED)
                break;
            if (errno == EINTR)
                continue;
            if (errno != EAGAIN && errno != ENOMEM) {
                break;
            }
            i++;
        }
    }

    if (addr == MAP_FAILED) {
        os_printf("mmap failed with errno: %d, hint: %p, size: %" PRIu64
                  ", prot: %d, flags: %d\n",
                  errno, hint, request_size, map_prot, map_flags);
        return NULL;
    }

#if BH_ENABLE_TRACE_MMAP != 0
    total_size_mmapped += request_size;
    os_printf("mmap return: %p with size: %zu, total_size_mmapped: %zu, "
              "total_size_munmapped: %zu\n",
              addr, request_size, total_size_mmapped, total_size_munmapped);
#endif

#if !defined(__APPLE__) && !defined(__NuttX__) && defined(MADV_HUGEPAGE)
    /* huge page isn't supported on MacOS and NuttX */
    if (request_size > HUGE_PAGE_SIZE) {
        uintptr_t huge_start, huge_end;
        size_t prefix_size = 0, suffix_size = HUGE_PAGE_SIZE;

        huge_start = round_up((uintptr_t)addr, HUGE_PAGE_SIZE);

        if (huge_start > (uintptr_t)addr) {
            prefix_size += huge_start - (uintptr_t)addr;
            suffix_size -= huge_start - (uintptr_t)addr;
        }

        /* unmap one extra huge page */

        if (prefix_size > 0) {
            munmap(addr, prefix_size);
#if BH_ENABLE_TRACE_MMAP != 0
            total_size_munmapped += prefix_size;
            os_printf("munmap %p with size: %zu, total_size_mmapped: %zu, "
                      "total_size_munmapped: %zu\n",
                      addr, prefix_size, total_size_mmapped,
                      total_size_munmapped);
#endif
        }
        if (suffix_size > 0) {
            munmap(addr + request_size - suffix_size, suffix_size);
#if BH_ENABLE_TRACE_MMAP != 0
            total_size_munmapped += suffix_size;
            os_printf("munmap %p with size: %zu, total_size_mmapped: %zu, "
                      "total_size_munmapped: %zu\n",
                      addr + request_size - suffix_size, suffix_size,
                      total_size_mmapped, total_size_munmapped);
#endif
        }

        addr = (uint8 *)huge_start;
        request_size -= HUGE_PAGE_SIZE;

        huge_end = round_down(huge_start + request_size, HUGE_PAGE_SIZE);
        if (huge_end > huge_start) {
            int ret = madvise((void *)huge_start, huge_end - huge_start,
                              MADV_HUGEPAGE);
            if (ret) {
#if BH_ENABLE_TRACE_MMAP != 0
                os_printf(
                    "warning: madvise(%p, %lu) huge page failed, return %d\n",
                    (void *)huge_start, huge_end - huge_start, ret);
#endif
            }
        }
    }
#endif /* end of __APPLE__ || __NuttX__ || !MADV_HUGEPAGE */

    return addr;
}

void
os_munmap(void *addr, size_t size)
{
    uint64 page_size = (uint64)getpagesize();
    uint64 request_size = (size + page_size - 1) & ~(page_size - 1);

    if (addr) {
        if (munmap(addr, request_size)) {
            os_printf("os_munmap error addr:%p, size:0x%" PRIx64 ", errno:%d\n",
                      addr, request_size, errno);
            return;
        }
#if BH_ENABLE_TRACE_MMAP != 0
        total_size_munmapped += request_size;
        os_printf("munmap %p with size: %zu, total_size_mmapped: %zu, "
                  "total_size_munmapped: %zu\n",
                  addr, request_size, total_size_mmapped, total_size_munmapped);
#endif
    }
}

#if WASM_HAVE_MREMAP != 0
void *
os_mremap(void *old_addr, size_t old_size, size_t new_size)
{
    void *ptr = mremap(old_addr, old_size, new_size, MREMAP_MAYMOVE);

    if (ptr == MAP_FAILED) {
#if BH_ENABLE_TRACE_MMAP != 0
        os_printf("mremap failed: %d\n", errno);
#endif
        return os_mremap_slow(old_addr, old_size, new_size);
    }

    return ptr;
}
#endif

int
os_mprotect(void *addr, size_t size, int prot)
{
    int map_prot = PROT_NONE;
    uint64 page_size = (uint64)getpagesize();
    uint64 request_size = (size + page_size - 1) & ~(page_size - 1);

    if (!addr)
        return 0;

    if (prot & MMAP_PROT_READ)
        map_prot |= PROT_READ;

    if (prot & MMAP_PROT_WRITE)
        map_prot |= PROT_WRITE;

    if (prot & MMAP_PROT_EXEC)
        map_prot |= PROT_EXEC;

    return mprotect(addr, request_size, map_prot);
}

void
os_dcache_flush(void)
{}

void
os_icache_flush(void *start, size_t len)
{
#if defined(__APPLE__) || defined(__MACH__)
    sys_icache_invalidate(start, len);
#else
    (void)start;
    (void)len;
#endif
}
