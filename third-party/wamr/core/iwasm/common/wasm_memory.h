/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_MEMORY_H
#define _WASM_MEMORY_H

#include "bh_common.h"
#include "../include/wasm_export.h"
#include "../interpreter/wasm_runtime.h"
#include "../common/wasm_shared_memory.h"

#ifdef __cplusplus
extern "C" {
#endif

#if WASM_ENABLE_SHARED_MEMORY != 0 && BH_ATOMIC_64_IS_ATOMIC != 0
#define GET_LINEAR_MEMORY_SIZE(memory) \
    BH_ATOMIC_64_LOAD(memory->memory_data_size)
#define SET_LINEAR_MEMORY_SIZE(memory, size) \
    BH_ATOMIC_64_STORE(memory->memory_data_size, size)
#elif WASM_ENABLE_SHARED_MEMORY != 0
static inline uint64
GET_LINEAR_MEMORY_SIZE(const WASMMemoryInstance *memory)
{
    SHARED_MEMORY_LOCK(memory);
    uint64 memory_data_size = BH_ATOMIC_64_LOAD(memory->memory_data_size);
    SHARED_MEMORY_UNLOCK(memory);
    return memory_data_size;
}
static inline void
SET_LINEAR_MEMORY_SIZE(WASMMemoryInstance *memory, uint64 size)
{
    SHARED_MEMORY_LOCK(memory);
    BH_ATOMIC_64_STORE(memory->memory_data_size, size);
    SHARED_MEMORY_UNLOCK(memory);
}
#else
#define GET_LINEAR_MEMORY_SIZE(memory) memory->memory_data_size
#define SET_LINEAR_MEMORY_SIZE(memory, size) memory->memory_data_size = size
#endif

#if WASM_ENABLE_INTERP != 0
#if WASM_ENABLE_SHARED_HEAP != 0

#if WASM_ENABLE_MULTI_MEMORY != 0
/* Only enable shared heap for the default memory */
#define is_default_memory (memidx == 0)
#else
#define is_default_memory true
#endif

#if UINTPTR_MAX == UINT64_MAX
#define get_shared_heap_end_off() module->e->shared_heap_end_off.u64
#else
#define get_shared_heap_end_off() \
    (uint64)(module->e->shared_heap_end_off.u32[0])
#endif

#if WASM_ENABLE_MEMORY64 != 0
#define shared_heap_is_memory64 is_memory64
#else
#define shared_heap_is_memory64 false
#endif

#define app_addr_in_shared_heap(app_addr, bytes)                              \
    (is_default_memory                                                        \
     && is_app_addr_in_shared_heap((WASMModuleInstanceCommon *)module,        \
                                   shared_heap_is_memory64, (uint64)app_addr, \
                                   bytes))
#define shared_heap_addr_app_to_native(app_addr, native_addr) \
    native_addr = module->e->shared_heap_base_addr_adj + app_addr
#define CHECK_SHARED_HEAP_OVERFLOW(app_addr, bytes, native_addr) \
    if (app_addr_in_shared_heap(app_addr, bytes))                \
        shared_heap_addr_app_to_native(app_addr, native_addr);   \
    else

#else /* else of WASM_ENABLE_SHARED_HEAP != 0 */
#define CHECK_SHARED_HEAP_OVERFLOW(app_addr, bytes, native_addr)
#endif /* end of WASM_ENABLE_SHARED_HEAP != 0 */
#endif /* end of WASM_ENABLE_INTERP != 0 */

#if WASM_ENABLE_SHARED_HEAP != 0
bool
is_app_addr_in_shared_heap(WASMModuleInstanceCommon *module_inst,
                           bool is_memory64, uint64 app_offset, uint32 bytes);

WASMSharedHeap *
wasm_runtime_create_shared_heap(SharedHeapInitArgs *init_args);

WASMSharedHeap *
wasm_runtime_chain_shared_heaps(WASMSharedHeap *head, WASMSharedHeap *body);

WASMSharedHeap *
wasm_runtime_unchain_shared_heaps(WASMSharedHeap *head, bool entire_chain);

bool
wasm_runtime_attach_shared_heap(WASMModuleInstanceCommon *module_inst,
                                WASMSharedHeap *shared_heap);
bool
wasm_runtime_attach_shared_heap_internal(WASMModuleInstanceCommon *module_inst,
                                         WASMSharedHeap *shared_heap);

void
wasm_runtime_detach_shared_heap(WASMModuleInstanceCommon *module_inst);

void
wasm_runtime_detach_shared_heap_internal(WASMModuleInstanceCommon *module_inst);

WASMSharedHeap *
wasm_runtime_get_shared_heap(WASMModuleInstanceCommon *module_inst_comm);

uint64
wasm_runtime_shared_heap_malloc(WASMModuleInstanceCommon *module_inst,
                                uint64 size, void **p_native_addr);

void
wasm_runtime_shared_heap_free(WASMModuleInstanceCommon *module_inst,
                              uint64 ptr);
#endif /* end of WASM_ENABLE_SHARED_HEAP != 0 */

bool
wasm_runtime_memory_init(mem_alloc_type_t mem_alloc_type,
                         const MemAllocOption *alloc_option);

void
wasm_runtime_memory_destroy(void);

unsigned
wasm_runtime_memory_pool_size(void);

void
wasm_runtime_set_mem_bound_check_bytes(WASMMemoryInstance *memory,
                                       uint64 memory_data_size);

void
wasm_runtime_set_enlarge_mem_error_callback(
    const enlarge_memory_error_callback_t callback, void *user_data);

void
wasm_deallocate_linear_memory(WASMMemoryInstance *memory_inst);

int
wasm_allocate_linear_memory(uint8 **data, bool is_shared_memory,
                            bool is_memory64, uint64 num_bytes_per_page,
                            uint64 init_page_count, uint64 max_page_count,
                            uint64 *memory_data_size);

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_MEMORY_H */
