/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _PLATFORM_API_VMCORE_H
#define _PLATFORM_API_VMCORE_H

#include "platform_common.h"
#include "platform_internal.h"

#ifdef __cplusplus
extern "C" {
#endif

/****************************************************
 *                     Section 1                    *
 *        Interfaces required by the runtime        *
 ****************************************************/

/**
 * Initialize the platform internal resources if needed,
 * this function is called by wasm_runtime_init() and
 * wasm_runtime_full_init()
 *
 * @return 0 if success
 */
int
bh_platform_init(void);

/**
 * Destroy the platform internal resources if needed,
 * this function is called by wasm_runtime_destroy()
 */
void
bh_platform_destroy(void);

/**
 ******** memory allocator APIs **********
 */

void *
os_malloc(unsigned size);

void *
os_realloc(void *ptr, unsigned size);

void
os_free(void *ptr);

/**
 * Note: the above APIs can simply return NULL if wasm runtime
 *       isn't initialized with Alloc_With_System_Allocator.
 *       Refer to wasm_runtime_full_init().
 */

int
os_printf(const char *format, ...);

int
os_vprintf(const char *format, va_list ap);

/**
 * Get microseconds after boot.
 */
uint64
os_time_get_boot_us(void);

/**
 * Get thread-specific CPU-time clock in microseconds
 */
uint64
os_time_thread_cputime_us(void);

/**
 * Get current thread id.
 * Implementation optional: Used by runtime for logging only.
 */
korp_tid
os_self_thread(void);

/**
 * Get current thread's stack boundary address, used for runtime
 * to check the native stack overflow. Return NULL if it is not
 * easy to implement, but may have potential issue.
 */
uint8 *
os_thread_get_stack_boundary(void);

/**
 * Set whether the MAP_JIT region write protection is enabled for this thread.
 * Pass true to make the region executable, false to make it writable.
 */
void
os_thread_jit_write_protect_np(bool enabled);

/**
 ************** mutext APIs ***********
 *  vmcore:  Not required until pthread is supported by runtime
 *  app-mgr: Must be implemented
 */

int
os_mutex_init(korp_mutex *mutex);

int
os_mutex_destroy(korp_mutex *mutex);

int
os_mutex_lock(korp_mutex *mutex);

int
os_mutex_unlock(korp_mutex *mutex);

/**************************************************
 *                    Section 2                   *
 *            APIs required by WAMR AOT           *
 **************************************************/

/* Memory map modes */
enum {
    MMAP_PROT_NONE = 0,
    MMAP_PROT_READ = 1,
    MMAP_PROT_WRITE = 2,
    MMAP_PROT_EXEC = 4
};

/* Memory map flags */
enum {
    MMAP_MAP_NONE = 0,
    /* Put the mapping into 0 to 2 G, supported only on x86_64 */
    MMAP_MAP_32BIT = 1,
    /* Don't interpret addr as a hint: place the mapping at exactly
       that address. */
    MMAP_MAP_FIXED = 2,
};

void *
os_mmap(void *hint, size_t size, int prot, int flags, os_file_handle file);
void
os_munmap(void *addr, size_t size);
int
os_mprotect(void *addr, size_t size, int prot);

static inline void *
os_mremap_slow(void *old_addr, size_t old_size, size_t new_size)
{
    void *new_memory = os_mmap(NULL, new_size, MMAP_PROT_WRITE | MMAP_PROT_READ,
                               0, os_get_invalid_handle());
    if (!new_memory) {
        return NULL;
    }
    /*
     * bh_memcpy_s can't be used as it doesn't support values bigger than
     * UINT32_MAX
     */
    memcpy(new_memory, old_addr, new_size < old_size ? new_size : old_size);
    os_munmap(old_addr, old_size);

    return new_memory;
}

/* Doesn't guarantee that protection flags will be preserved.
   os_mprotect() must be called after remapping. */
void *
os_mremap(void *old_addr, size_t old_size, size_t new_size);

#if (WASM_MEM_DUAL_BUS_MIRROR != 0)
void *
os_get_dbus_mirror(void *ibus);
#endif

/**
 * Flush cpu data cache, in some CPUs, after applying relocation to the
 * AOT code, the code may haven't been written back to the cpu data cache,
 * which may cause unexpected behaviour when executing the AOT code.
 * Implement this function if required, or just leave it empty.
 */
void
os_dcache_flush(void);

/**
 * Flush instruction cache.
 */
void
os_icache_flush(void *start, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* #ifndef _PLATFORM_API_VMCORE_H */
