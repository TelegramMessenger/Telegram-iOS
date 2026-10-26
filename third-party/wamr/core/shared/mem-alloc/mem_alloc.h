/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef __MEM_ALLOC_H
#define __MEM_ALLOC_H

#include "bh_platform.h"
#if WASM_ENABLE_GC != 0
#include "../../common/gc/gc_object.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void *mem_allocator_t;

#ifndef GC_FINALIZER_T_DEFINED
#define GC_FINALIZER_T_DEFINED
typedef void (*gc_finalizer_t)(void *obj, void *data);
#endif

mem_allocator_t
mem_allocator_create(void *mem, uint32_t size);

mem_allocator_t
mem_allocator_create_with_struct_and_pool(void *struct_buf,
                                          uint32_t struct_buf_size,
                                          void *pool_buf,
                                          uint32_t pool_buf_size);

int
mem_allocator_destroy(mem_allocator_t allocator);

uint32
mem_allocator_get_heap_struct_size(void);

void *
mem_allocator_malloc(mem_allocator_t allocator, uint32_t size);

void *
mem_allocator_realloc(mem_allocator_t allocator, void *ptr, uint32_t size);

void
mem_allocator_free(mem_allocator_t allocator, void *ptr);

int
mem_allocator_migrate(mem_allocator_t allocator, char *pool_buf_new,
                      uint32 pool_buf_size);

bool
mem_allocator_is_heap_corrupted(mem_allocator_t allocator);

#if WASM_ENABLE_GC != 0
void *
mem_allocator_malloc_with_gc(mem_allocator_t allocator, uint32_t size);

#if WASM_GC_MANUALLY != 0
void
mem_allocator_free_with_gc(mem_allocator_t allocator, void *ptr);
#endif

#if WASM_ENABLE_THREAD_MGR == 0
void
mem_allocator_enable_gc_reclaim(mem_allocator_t allocator, void *exec_env);
#else
void
mem_allocator_enable_gc_reclaim(mem_allocator_t allocator, void *cluster);
#endif

int
mem_allocator_add_root(mem_allocator_t allocator, WASMObjectRef obj);

bool
mem_allocator_set_gc_finalizer(mem_allocator_t allocator, void *obj,
                               gc_finalizer_t cb, void *data);

void
mem_allocator_unset_gc_finalizer(mem_allocator_t allocator, void *obj);

#if WASM_ENABLE_GC_PERF_PROFILING != 0
void
mem_allocator_dump_perf_profiling(mem_allocator_t allocator);
#endif
#endif /* end of WASM_ENABLE_GC != 0 */

bool
mem_allocator_get_alloc_info(mem_allocator_t allocator, void *mem_alloc_info);

#ifdef __cplusplus
}
#endif

#endif /* #ifndef __MEM_ALLOC_H */
