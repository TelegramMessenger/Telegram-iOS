/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "wasm_runtime_common.h"
#include "../interpreter/wasm_runtime.h"
#include "../aot/aot_runtime.h"
#include "mem_alloc.h"
#include "wasm_memory.h"

#if WASM_ENABLE_SHARED_MEMORY != 0
#include "../common/wasm_shared_memory.h"
#endif

#if WASM_ENABLE_THREAD_MGR != 0
#include "../libraries/thread-mgr/thread_manager.h"
#endif

typedef enum Memory_Mode {
    MEMORY_MODE_UNKNOWN = 0,
    MEMORY_MODE_POOL,
    MEMORY_MODE_ALLOCATOR,
    MEMORY_MODE_SYSTEM_ALLOCATOR
} Memory_Mode;

static Memory_Mode memory_mode = MEMORY_MODE_UNKNOWN;

static mem_allocator_t pool_allocator = NULL;

#if WASM_ENABLE_SHARED_HEAP != 0
static WASMSharedHeap *shared_heap_list = NULL;
static korp_mutex shared_heap_list_lock;
#endif

static enlarge_memory_error_callback_t enlarge_memory_error_cb;
static void *enlarge_memory_error_user_data;

#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
static void *allocator_user_data = NULL;
#endif

static void *(*malloc_func)(
#if WASM_MEM_ALLOC_WITH_USAGE != 0
    mem_alloc_usage_t usage,
#endif
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
    void *user_data,
#endif
    unsigned int size) = NULL;

static void *(*realloc_func)(
#if WASM_MEM_ALLOC_WITH_USAGE != 0
    mem_alloc_usage_t usage, bool full_size_mmaped,
#endif
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
    void *user_data,
#endif
    void *ptr, unsigned int size) = NULL;

static void (*free_func)(
#if WASM_MEM_ALLOC_WITH_USAGE != 0
    mem_alloc_usage_t usage,
#endif
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
    void *user_data,
#endif
    void *ptr) = NULL;

static unsigned int global_pool_size;

static uint64
align_as_and_cast(uint64 size, uint64 alignment)
{
    uint64 aligned_size = (size + alignment - 1) & ~(alignment - 1);

    return aligned_size;
}

static bool
wasm_memory_init_with_pool(void *mem, unsigned int bytes)
{
    mem_allocator_t allocator = mem_allocator_create(mem, bytes);

    if (allocator) {
        memory_mode = MEMORY_MODE_POOL;
        pool_allocator = allocator;
        global_pool_size = bytes;
        return true;
    }
    LOG_ERROR("Init memory with pool (%p, %u) failed.\n", mem, bytes);
    return false;
}

#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
static bool
wasm_memory_init_with_allocator(void *_user_data, void *_malloc_func,
                                void *_realloc_func, void *_free_func)
{
    if (_malloc_func && _free_func && _malloc_func != _free_func) {
        memory_mode = MEMORY_MODE_ALLOCATOR;
        allocator_user_data = _user_data;
        malloc_func = _malloc_func;
        realloc_func = _realloc_func;
        free_func = _free_func;
        return true;
    }
    LOG_ERROR("Init memory with allocator (%p, %p, %p, %p) failed.\n",
              _user_data, _malloc_func, _realloc_func, _free_func);
    return false;
}
#else
static bool
wasm_memory_init_with_allocator(void *malloc_func_ptr, void *realloc_func_ptr,
                                void *free_func_ptr)
{
    if (malloc_func_ptr && free_func_ptr && malloc_func_ptr != free_func_ptr) {
        memory_mode = MEMORY_MODE_ALLOCATOR;
        malloc_func = malloc_func_ptr;
        realloc_func = realloc_func_ptr;
        free_func = free_func_ptr;
        return true;
    }
    LOG_ERROR("Init memory with allocator (%p, %p, %p) failed.\n",
              malloc_func_ptr, realloc_func_ptr, free_func_ptr);
    return false;
}
#endif

static inline bool
is_bounds_checks_enabled(WASMModuleInstanceCommon *module_inst)
{
#if WASM_CONFIGURABLE_BOUNDS_CHECKS != 0
    if (!module_inst) {
        return true;
    }

    return wasm_runtime_is_bounds_checks_enabled(module_inst);
#else
    return true;
#endif
}

#if WASM_ENABLE_SHARED_HEAP != 0
static void *
wasm_mmap_linear_memory(uint64 map_size, uint64 commit_size);
static void
wasm_munmap_linear_memory(void *mapped_mem, uint64 commit_size,
                          uint64 map_size);

static void *
runtime_malloc(uint64 size)
{
    void *mem;

    if (size >= UINT32_MAX || !(mem = wasm_runtime_malloc((uint32)size))) {
        LOG_WARNING("Allocate memory failed");
        return NULL;
    }

    memset(mem, 0, (uint32)size);
    return mem;
}

WASMSharedHeap *
wasm_runtime_create_shared_heap(SharedHeapInitArgs *init_args)
{
    uint64 heap_struct_size = sizeof(WASMSharedHeap), map_size;
    uint32 size = init_args->size;
    WASMSharedHeap *heap;

    if (size == 0) {
        goto fail1;
    }

    if (!(heap = runtime_malloc(heap_struct_size))) {
        goto fail1;
    }

    size = align_uint(size, os_getpagesize());
    if (size > APP_HEAP_SIZE_MAX || size < APP_HEAP_SIZE_MIN) {
        LOG_WARNING("Invalid size of shared heap");
        goto fail2;
    }

    heap->size = size;
    heap->start_off_mem64 = UINT64_MAX - heap->size + 1;
    heap->start_off_mem32 = UINT32_MAX - heap->size + 1;
    heap->attached_count = 0;

    if (init_args->pre_allocated_addr != NULL) {
        /* Create shared heap from a pre allocated buffer, its size need to
         * align with system page */
        if (size != init_args->size) {
            LOG_WARNING("Pre allocated size need to be aligned with system "
                        "page size to create shared heap");
            goto fail2;
        }

        heap->heap_handle = NULL;
        heap->base_addr = init_args->pre_allocated_addr;
    }
    else {
        if (!(heap->heap_handle =
                  runtime_malloc(mem_allocator_get_heap_struct_size()))) {
            goto fail2;
        }

#ifndef OS_ENABLE_HW_BOUND_CHECK
        map_size = size;
#else
        /* Totally 8G is mapped, the opcode load/store address range is 0 to 8G:
         *   ea = i + memarg.offset
         * both i and memarg.offset are u32 in range 0 to 4G
         * so the range of ea is 0 to 8G
         */
        map_size = 8 * (uint64)BH_GB;
#endif

        if (!(heap->base_addr = wasm_mmap_linear_memory(map_size, size))) {
            goto fail3;
        }
        if (!mem_allocator_create_with_struct_and_pool(
                heap->heap_handle, heap_struct_size, heap->base_addr, size)) {
            LOG_WARNING("init share heap failed");
            goto fail4;
        }
    }

    os_mutex_lock(&shared_heap_list_lock);
    if (shared_heap_list == NULL) {
        shared_heap_list = heap;
    }
    else {
        heap->next = shared_heap_list;
        shared_heap_list = heap;
    }
    os_mutex_unlock(&shared_heap_list_lock);
    return heap;

fail4:
    wasm_munmap_linear_memory(heap->base_addr, size, map_size);
fail3:
    wasm_runtime_free(heap->heap_handle);
fail2:
    wasm_runtime_free(heap);
fail1:
    return NULL;
}

WASMSharedHeap *
wasm_runtime_chain_shared_heaps(WASMSharedHeap *head, WASMSharedHeap *body)
{
    WASMSharedHeap *cur;
    bool heap_handle_exist = false;

    if (!head || !body) {
        LOG_WARNING("Invalid shared heap to chain.");
        return NULL;
    }
    heap_handle_exist = head->heap_handle != NULL;

    os_mutex_lock(&shared_heap_list_lock);
    if (head->attached_count != 0 || body->attached_count != 0) {
        LOG_WARNING("To create shared heap chain, all shared heap need to be "
                    "detached first.");
        os_mutex_unlock(&shared_heap_list_lock);
        return NULL;
    }
    for (cur = shared_heap_list; cur; cur = cur->next) {
        if (cur->chain_next == body || cur->chain_next == head) {
            LOG_WARNING(
                "To create shared heap chain, both the 'head' and 'body' "
                "shared heap can't already be the 'body' in another a chain");
            os_mutex_unlock(&shared_heap_list_lock);
            return NULL;
        }
        if (cur == head && cur->chain_next) {
            LOG_WARNING(
                "To create shared heap chain, the 'head' shared heap can't "
                "already be the 'head' in another a chain");
            os_mutex_unlock(&shared_heap_list_lock);
            return NULL;
        }
    }
    for (cur = body; cur; cur = cur->chain_next) {
        if (cur->heap_handle && heap_handle_exist) {
            LOG_WARNING(
                "To create shared heap chain, only one of shared heap can "
                "dynamically shared_heap_malloc and shared_heap_free, the rest "
                "can only be pre-allocated shared heap");
            os_mutex_unlock(&shared_heap_list_lock);
            return NULL;
        }
        if (cur->heap_handle)
            heap_handle_exist = true;
    }

    head->start_off_mem64 = body->start_off_mem64 - head->size;
    head->start_off_mem32 = body->start_off_mem32 - head->size;
    head->chain_next = body;
    os_mutex_unlock(&shared_heap_list_lock);
    return head;
}

WASMSharedHeap *
wasm_runtime_unchain_shared_heaps(WASMSharedHeap *head, bool entire_chain)
{
    WASMSharedHeap *cur, *tmp;

    if (!head || !head->chain_next) {
        LOG_WARNING("Invalid shared heap chain to disconnect the head from.");
        return NULL;
    }

    os_mutex_lock(&shared_heap_list_lock);
    if (head->attached_count != 0) {
        LOG_WARNING("To disconnect the shared heap head from the shared heap "
                    "chain, the shared heap chain needs to be detached first.");
        os_mutex_unlock(&shared_heap_list_lock);
        return NULL;
    }

    cur = head;
    while (cur && cur->chain_next) {
        cur->start_off_mem64 = UINT64_MAX - cur->size + 1;
        cur->start_off_mem32 = UINT32_MAX - cur->size + 1;
        tmp = cur;
        cur = cur->chain_next;
        tmp->chain_next = NULL;
        if (!entire_chain)
            break;
    }
    os_mutex_unlock(&shared_heap_list_lock);
    return cur;
}

static uint8 *
get_last_used_shared_heap_base_addr_adj(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstanceExtra *e =
            (WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e;
        return e->shared_heap_base_addr_adj;
    }
#endif /* end of WASM_ENABLE_INTERP != 0 */
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
        return e->shared_heap_base_addr_adj;
    }
#endif /* end of WASM_ENABLE_AOT != 0 */
    return 0;
}

static uintptr_t
get_last_used_shared_heap_start_offset(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstanceExtra *e =
            (WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e;
#if UINTPTR_MAX == UINT64_MAX
        return e->shared_heap_start_off.u64;
#else
        return e->shared_heap_start_off.u32[0];
#endif
    }
#endif /* end of WASM_ENABLE_INTERP != 0 */
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
#if UINTPTR_MAX == UINT64_MAX
        return e->shared_heap_start_off.u64;
#else
        return e->shared_heap_start_off.u32[0];
#endif
    }
#endif /* end of WASM_ENABLE_AOT != 0 */
    return 0;
}

static uintptr_t
get_last_used_shared_heap_end_offset(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstanceExtra *e =
            (WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e;
#if UINTPTR_MAX == UINT64_MAX
        return e->shared_heap_end_off.u64;
#else
        return e->shared_heap_end_off.u32[0];
#endif
    }
#endif /* end of WASM_ENABLE_INTERP != 0 */
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
#if UINTPTR_MAX == UINT64_MAX
        return e->shared_heap_end_off.u64;
#else
        return e->shared_heap_end_off.u32[0];
#endif
    }
#endif /* end of WASM_ENABLE_AOT != 0 */
    return 0;
}

static void
update_last_used_shared_heap(WASMModuleInstanceCommon *module_inst,
                             WASMSharedHeap *shared_heap, bool is_memory64)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstanceExtra *e =
            (WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e;
#if UINTPTR_MAX == UINT64_MAX
        if (is_memory64)
            e->shared_heap_start_off.u64 = shared_heap->start_off_mem64;
        else
            e->shared_heap_start_off.u64 = shared_heap->start_off_mem32;
        e->shared_heap_end_off.u64 =
            e->shared_heap_start_off.u64 - 1 + shared_heap->size;
        e->shared_heap_base_addr_adj =
            shared_heap->base_addr - e->shared_heap_start_off.u64;
#else
        e->shared_heap_start_off.u32[0] = (uint32)shared_heap->start_off_mem32;
        e->shared_heap_end_off.u32[0] =
            e->shared_heap_start_off.u32[0] - 1 + shared_heap->size;
        e->shared_heap_base_addr_adj =
            shared_heap->base_addr - e->shared_heap_start_off.u32[0];
#endif
    }
#endif /* end of WASM_ENABLE_INTERP != 0 */
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
#if UINTPTR_MAX == UINT64_MAX
        if (is_memory64)
            e->shared_heap_start_off.u64 = shared_heap->start_off_mem64;
        else
            e->shared_heap_start_off.u64 = shared_heap->start_off_mem32;
        e->shared_heap_end_off.u64 =
            e->shared_heap_start_off.u64 - 1 + shared_heap->size;
        e->shared_heap_base_addr_adj =
            shared_heap->base_addr - e->shared_heap_start_off.u64;
#else
        e->shared_heap_start_off.u32[0] = (uint32)shared_heap->start_off_mem32;
        e->shared_heap_end_off.u32[0] =
            e->shared_heap_start_off.u32[0] - 1 + shared_heap->size;
        e->shared_heap_base_addr_adj =
            shared_heap->base_addr - e->shared_heap_start_off.u32[0];
#endif
    }
#endif /* end of WASM_ENABLE_AOT != 0 */
}

bool
wasm_runtime_attach_shared_heap_internal(WASMModuleInstanceCommon *module_inst,
                                         WASMSharedHeap *shared_heap)
{
    WASMMemoryInstance *memory =
        wasm_get_default_memory((WASMModuleInstance *)module_inst);
    uint64 linear_mem_size;

    if (!memory)
        return false;

    linear_mem_size = memory->memory_data_size;

    /* check if linear memory and shared heap are overlapped */
    if ((memory->is_memory64 && linear_mem_size > shared_heap->start_off_mem64)
        || (!memory->is_memory64
            && linear_mem_size > shared_heap->start_off_mem32)) {
        LOG_WARNING("Linear memory address is overlapped with shared heap");
        return false;
    }

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstanceExtra *e =
            (WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e;
        if (e->shared_heap) {
            LOG_WARNING("A shared heap is already attached");
            return false;
        }
        e->shared_heap = shared_heap;
    }
#endif /* end of WASM_ENABLE_INTERP != 0 */
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
        if (e->shared_heap) {
            LOG_WARNING("A shared heap is already attached");
            return false;
        }
        e->shared_heap = shared_heap;
    }
#endif /* end of WASM_ENABLE_AOT != 0 */
    update_last_used_shared_heap(module_inst, shared_heap, memory->is_memory64);

    os_mutex_lock(&shared_heap_list_lock);
    shared_heap->attached_count++;
    os_mutex_unlock(&shared_heap_list_lock);
    return true;
}

bool
wasm_runtime_attach_shared_heap(WASMModuleInstanceCommon *module_inst,
                                WASMSharedHeap *shared_heap)
{
#if WASM_ENABLE_THREAD_MGR != 0
    return wasm_cluster_attach_shared_heap(module_inst, shared_heap);
#else
    return wasm_runtime_attach_shared_heap_internal(module_inst, shared_heap);
#endif
}

void
wasm_runtime_detach_shared_heap_internal(WASMModuleInstanceCommon *module_inst)
{
    /* Reset shared_heap_end_off = UINT64/32_MAX - 1 to handling a corner case,
      app_offset >= shared_heap_start && app_offset <= shared_heap_end-bytes+1
      when bytes=1 and both e->shared_heap_start_off and e->shared_heap_end_off
      is 0xffffffff */
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstanceExtra *e =
            (WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e;
        if (e->shared_heap != NULL) {
            os_mutex_lock(&shared_heap_list_lock);
            e->shared_heap->attached_count--;
            os_mutex_unlock(&shared_heap_list_lock);
        }
        e->shared_heap = NULL;
#if UINTPTR_MAX == UINT64_MAX
        e->shared_heap_start_off.u64 = UINT64_MAX;
        e->shared_heap_end_off.u64 = UINT64_MAX - 1;
#else
        e->shared_heap_start_off.u32[0] = UINT32_MAX;
        e->shared_heap_end_off.u32[0] = UINT32_MAX - 1;
#endif
        e->shared_heap_base_addr_adj = NULL;
    }
#endif /* end of WASM_ENABLE_INTERP != 0 */
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
        if (e->shared_heap != NULL) {
            os_mutex_lock(&shared_heap_list_lock);
            e->shared_heap->attached_count--;
            os_mutex_unlock(&shared_heap_list_lock);
        }
        e->shared_heap = NULL;
#if UINTPTR_MAX == UINT64_MAX
        e->shared_heap_start_off.u64 = UINT64_MAX;
        e->shared_heap_end_off.u64 = UINT64_MAX - 1;
#else
        e->shared_heap_start_off.u32[0] = UINT32_MAX;
        e->shared_heap_end_off.u32[0] = UINT32_MAX - 1;
#endif
        e->shared_heap_base_addr_adj = NULL;
    }
#endif /* end of WASM_ENABLE_AOT != 0 */
}

void
wasm_runtime_detach_shared_heap(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_THREAD_MGR != 0
    wasm_cluster_detach_shared_heap(module_inst);
#else
    wasm_runtime_detach_shared_heap_internal(module_inst);
#endif
}

static WASMSharedHeap *
get_shared_heap(WASMModuleInstanceCommon *module_inst_comm)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst_comm->module_type == Wasm_Module_Bytecode) {
        return ((WASMModuleInstance *)module_inst_comm)->e->shared_heap;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst_comm->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst_comm)
                ->e;
        return e->shared_heap;
    }
#endif
    return NULL;
}

WASMSharedHeap *
wasm_runtime_get_shared_heap(WASMModuleInstanceCommon *module_inst_comm)
{
    return get_shared_heap(module_inst_comm);
}

bool
is_app_addr_in_shared_heap(WASMModuleInstanceCommon *module_inst,
                           bool is_memory64, uint64 app_offset, uint32 bytes)
{
    WASMSharedHeap *heap = get_shared_heap(module_inst), *cur;
    uint64 shared_heap_start, shared_heap_end;

    if (!heap) {
        goto fail;
    }

    if (bytes == 0) {
        bytes = 1;
    }

    shared_heap_start =
        (uint64)get_last_used_shared_heap_start_offset(module_inst);
    shared_heap_end = (uint64)get_last_used_shared_heap_end_offset(module_inst);
    if (bytes - 1 <= shared_heap_end && app_offset >= shared_heap_start
        && app_offset <= shared_heap_end - bytes + 1) {
        return true;
    }

    /* Early stop for app start address not in the shared heap(chain) at all */
    shared_heap_start =
        is_memory64 ? heap->start_off_mem64 : heap->start_off_mem32;
    shared_heap_end = is_memory64 ? UINT64_MAX : UINT32_MAX;
    if (bytes - 1 > shared_heap_end || app_offset < shared_heap_start
        || app_offset > shared_heap_end - bytes + 1) {
        goto fail;
    }

    /* Find the exact shared heap that app addr is in, and update last used
     * shared heap info in module inst extra */
    for (cur = heap; cur; cur = cur->chain_next) {
        shared_heap_start =
            is_memory64 ? cur->start_off_mem64 : cur->start_off_mem32;
        shared_heap_end = shared_heap_start - 1 + cur->size;
        if (bytes - 1 <= shared_heap_end && app_offset >= shared_heap_start
            && app_offset <= shared_heap_end - bytes + 1) {
            update_last_used_shared_heap(module_inst, cur, is_memory64);
            return true;
        }
    }

fail:
    return false;
}

static bool
is_native_addr_in_shared_heap(WASMModuleInstanceCommon *module_inst,
                              bool is_memory64, uint8 *addr, uint32 bytes)
{
    WASMSharedHeap *cur, *heap = get_shared_heap(module_inst);
    uintptr_t base_addr, addr_int, end_addr;

    if (!heap) {
        goto fail;
    }

    /* Iterate through shared heap chain to find whether native addr in one of
     * shared heap */
    for (cur = heap; cur != NULL; cur = cur->chain_next) {
        base_addr = (uintptr_t)cur->base_addr;
        addr_int = (uintptr_t)addr;
        if (addr_int < base_addr)
            continue;

        end_addr = addr_int + bytes;
        /* Check for overflow */
        if (end_addr <= addr_int)
            continue;

        if (end_addr > base_addr + cur->size)
            continue;

        update_last_used_shared_heap(module_inst, cur, is_memory64);
        return true;
    }

fail:
    return false;
}

uint64
wasm_runtime_shared_heap_malloc(WASMModuleInstanceCommon *module_inst,
                                uint64 size, void **p_native_addr)
{
    WASMMemoryInstance *memory =
        wasm_get_default_memory((WASMModuleInstance *)module_inst);
    WASMSharedHeap *shared_heap = get_shared_heap(module_inst);
    void *native_addr = NULL;

    if (!memory || !shared_heap)
        return 0;

    while (shared_heap && !shared_heap->heap_handle) {
        shared_heap = shared_heap->chain_next;
    }
    if (!shared_heap) {
        LOG_WARNING("Can't allocate from pre allocated shared heap");
        return 0;
    }

    native_addr = mem_allocator_malloc(shared_heap->heap_handle, size);
    if (!native_addr)
        return 0;

    if (p_native_addr) {
        *p_native_addr = native_addr;
    }

    return memory->is_memory64
               ? shared_heap->start_off_mem64
               : shared_heap->start_off_mem32
                     + ((uint8 *)native_addr - shared_heap->base_addr);
}

void
wasm_runtime_shared_heap_free(WASMModuleInstanceCommon *module_inst, uint64 ptr)
{
    WASMMemoryInstance *memory =
        wasm_get_default_memory((WASMModuleInstance *)module_inst);
    WASMSharedHeap *shared_heap = get_shared_heap(module_inst);
    uint8 *addr = NULL;

    if (!memory || !shared_heap) {
        return;
    }

    while (shared_heap && !shared_heap->heap_handle) {
        shared_heap = shared_heap->chain_next;
    }
    if (!shared_heap) {
        LOG_WARNING("The address to free is from pre allocated shared heap");
        return;
    }

    if (memory->is_memory64) {
        if (ptr < shared_heap->start_off_mem64) { /* ptr can not > UINT64_MAX */
            LOG_WARNING("The address to free isn't in shared heap");
            return;
        }
        addr = shared_heap->base_addr + (ptr - shared_heap->start_off_mem64);
    }
    else {
        if (ptr < shared_heap->start_off_mem32 || ptr > UINT32_MAX) {
            LOG_WARNING("The address to free isn't in shared heap");
            return;
        }
        addr = shared_heap->base_addr + (ptr - shared_heap->start_off_mem32);
    }

    mem_allocator_free(shared_heap->heap_handle, addr);
}
#endif /* end of WASM_ENABLE_SHARED_HEAP != 0 */

bool
wasm_runtime_memory_init(mem_alloc_type_t mem_alloc_type,
                         const MemAllocOption *alloc_option)
{
    bool ret = false;

#if WASM_ENABLE_SHARED_HEAP != 0
    if (os_mutex_init(&shared_heap_list_lock)) {
        return false;
    }
#endif

    if (mem_alloc_type == Alloc_With_Pool) {
        ret = wasm_memory_init_with_pool(alloc_option->pool.heap_buf,
                                         alloc_option->pool.heap_size);
    }
    else if (mem_alloc_type == Alloc_With_Allocator) {
        ret = wasm_memory_init_with_allocator(
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
            alloc_option->allocator.user_data,
#endif
            alloc_option->allocator.malloc_func,
            alloc_option->allocator.realloc_func,
            alloc_option->allocator.free_func);
    }
    else if (mem_alloc_type == Alloc_With_System_Allocator) {
        memory_mode = MEMORY_MODE_SYSTEM_ALLOCATOR;
        ret = true;
    }
    else {
        ret = false;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    if (!ret) {
        os_mutex_destroy(&shared_heap_list_lock);
    }
#endif

    return ret;
}

#if WASM_ENABLE_SHARED_HEAP != 0
static void
destroy_shared_heaps()
{
    WASMSharedHeap *heap;
    WASMSharedHeap *cur;
    uint64 map_size;

    os_mutex_lock(&shared_heap_list_lock);
    heap = shared_heap_list;
    shared_heap_list = NULL;
    os_mutex_unlock(&shared_heap_list_lock);

    while (heap) {
        cur = heap;
        heap = heap->next;
        if (cur->heap_handle) {
            mem_allocator_destroy(cur->heap_handle);
            wasm_runtime_free(cur->heap_handle);
#ifndef OS_ENABLE_HW_BOUND_CHECK
            map_size = cur->size;
#else
            map_size = 8 * (uint64)BH_GB;
#endif
            wasm_munmap_linear_memory(cur->base_addr, cur->size, map_size);
        }
        wasm_runtime_free(cur);
    }
    os_mutex_destroy(&shared_heap_list_lock);
}
#endif

void
wasm_runtime_memory_destroy(void)
{
#if WASM_ENABLE_SHARED_HEAP != 0
    destroy_shared_heaps();
#endif

    if (memory_mode == MEMORY_MODE_POOL) {
#if BH_ENABLE_GC_VERIFY == 0
        (void)mem_allocator_destroy(pool_allocator);
#else
        int ret = mem_allocator_destroy(pool_allocator);
        if (ret != 0) {
            /* Memory leak detected */
            exit(-1);
        }
#endif
    }
    memory_mode = MEMORY_MODE_UNKNOWN;
}

unsigned
wasm_runtime_memory_pool_size(void)
{
    if (memory_mode == MEMORY_MODE_POOL)
        return global_pool_size;
    else
        return UINT32_MAX;
}

static inline void *
wasm_runtime_malloc_internal(unsigned int size)
{
    if (memory_mode == MEMORY_MODE_UNKNOWN) {
        LOG_WARNING(
            "wasm_runtime_malloc failed: memory hasn't been initialized.\n");
        return NULL;
    }
    else if (memory_mode == MEMORY_MODE_POOL) {
        return mem_allocator_malloc(pool_allocator, size);
    }
    else if (memory_mode == MEMORY_MODE_ALLOCATOR) {
        return malloc_func(
#if WASM_MEM_ALLOC_WITH_USAGE != 0
            Alloc_For_Runtime,
#endif
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
            allocator_user_data,
#endif
            size);
    }
    else {
        return os_malloc(size);
    }
}

static inline void *
wasm_runtime_realloc_internal(void *ptr, unsigned int size)
{
    if (memory_mode == MEMORY_MODE_UNKNOWN) {
        LOG_WARNING(
            "wasm_runtime_realloc failed: memory hasn't been initialized.\n");
        return NULL;
    }
    else if (memory_mode == MEMORY_MODE_POOL) {
        return mem_allocator_realloc(pool_allocator, ptr, size);
    }
    else if (memory_mode == MEMORY_MODE_ALLOCATOR) {
        if (realloc_func)
            return realloc_func(
#if WASM_MEM_ALLOC_WITH_USAGE != 0
                Alloc_For_Runtime, false,
#endif
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
                allocator_user_data,
#endif
                ptr, size);
        else
            return NULL;
    }
    else {
        return os_realloc(ptr, size);
    }
}

static inline void
wasm_runtime_free_internal(void *ptr)
{
    if (!ptr) {
        LOG_WARNING("warning: wasm_runtime_free with NULL pointer\n");
#if BH_ENABLE_GC_VERIFY != 0
        exit(-1);
#endif
        return;
    }

    if (memory_mode == MEMORY_MODE_UNKNOWN) {
        LOG_WARNING("warning: wasm_runtime_free failed: "
                    "memory hasn't been initialize.\n");
    }
    else if (memory_mode == MEMORY_MODE_POOL) {
        mem_allocator_free(pool_allocator, ptr);
    }
    else if (memory_mode == MEMORY_MODE_ALLOCATOR) {
        free_func(
#if WASM_MEM_ALLOC_WITH_USAGE != 0
            Alloc_For_Runtime,
#endif
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
            allocator_user_data,
#endif
            ptr);
    }
    else {
        os_free(ptr);
    }
}

void *
wasm_runtime_malloc(unsigned int size)
{
    if (size == 0) {
        LOG_WARNING("warning: wasm_runtime_malloc with size zero\n");
        /* At lease alloc 1 byte to avoid malloc failed */
        size = 1;
#if BH_ENABLE_GC_VERIFY != 0
        exit(-1);
#endif
    }

#if WASM_ENABLE_FUZZ_TEST != 0
    if (size >= WASM_MEM_ALLOC_MAX_SIZE) {
        LOG_WARNING("warning: wasm_runtime_malloc with too large size\n");
        return NULL;
    }
#endif

    return wasm_runtime_malloc_internal(size);
}

void *
wasm_runtime_realloc(void *ptr, unsigned int size)
{
    return wasm_runtime_realloc_internal(ptr, size);
}

void
wasm_runtime_free(void *ptr)
{
    wasm_runtime_free_internal(ptr);
}

bool
wasm_runtime_get_mem_alloc_info(mem_alloc_info_t *mem_alloc_info)
{
    if (memory_mode == MEMORY_MODE_POOL) {
        return mem_allocator_get_alloc_info(pool_allocator, mem_alloc_info);
    }
    return false;
}

bool
wasm_runtime_validate_app_addr(WASMModuleInstanceCommon *module_inst_comm,
                               uint64 app_offset, uint64 size)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMMemoryInstance *memory_inst;
    uint64 max_linear_memory_size = MAX_LINEAR_MEMORY_SIZE;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    if (!is_bounds_checks_enabled(module_inst_comm)) {
        return true;
    }

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        goto fail;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    if (is_app_addr_in_shared_heap(module_inst_comm, memory_inst->is_memory64,
                                   app_offset, size)) {
        return true;
    }
#endif

#if WASM_ENABLE_MEMORY64 != 0
    if (memory_inst->is_memory64)
        max_linear_memory_size = MAX_LINEAR_MEM64_MEMORY_SIZE;
#endif
    /* boundary overflow check */
    if (size > max_linear_memory_size
        || app_offset > max_linear_memory_size - size) {
        goto fail;
    }

    SHARED_MEMORY_LOCK(memory_inst);

    if (app_offset + size <= memory_inst->memory_data_size) {
        SHARED_MEMORY_UNLOCK(memory_inst);
        return true;
    }

    SHARED_MEMORY_UNLOCK(memory_inst);

fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

bool
wasm_runtime_validate_app_str_addr(WASMModuleInstanceCommon *module_inst_comm,
                                   uint64 app_str_offset)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMMemoryInstance *memory_inst;
    uint64 app_end_offset, max_linear_memory_size = MAX_LINEAR_MEMORY_SIZE;
    char *str, *str_end;
#if WASM_ENABLE_SHARED_HEAP != 0
    uintptr_t shared_heap_end_off;
    char *shared_heap_base_addr_adj;
#endif

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    if (!is_bounds_checks_enabled(module_inst_comm)) {
        return true;
    }

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        goto fail;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    if (is_app_addr_in_shared_heap(module_inst_comm, memory_inst->is_memory64,
                                   app_str_offset, 1)) {
        shared_heap_end_off =
            get_last_used_shared_heap_end_offset(module_inst_comm);
        shared_heap_base_addr_adj =
            (char *)get_last_used_shared_heap_base_addr_adj(module_inst_comm);
        str = shared_heap_base_addr_adj + app_str_offset;
        str_end = shared_heap_base_addr_adj + shared_heap_end_off + 1;
    }
    else
#endif
    {
        if (!wasm_runtime_get_app_addr_range(module_inst_comm, app_str_offset,
                                             NULL, &app_end_offset))
            goto fail;

#if WASM_ENABLE_MEMORY64 != 0
        if (memory_inst->is_memory64)
            max_linear_memory_size = MAX_LINEAR_MEM64_MEMORY_SIZE;
#endif
        /* boundary overflow check, max start offset can be size - 1, while end
           offset can be size */
        if (app_str_offset >= max_linear_memory_size
            || app_end_offset > max_linear_memory_size)
            goto fail;

        str = wasm_runtime_addr_app_to_native(module_inst_comm, app_str_offset);
        str_end = str + (app_end_offset - app_str_offset);
    }

    while (str < str_end && *str != '\0')
        str++;
    if (str == str_end)
        goto fail;

    return true;
fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

bool
wasm_runtime_validate_native_addr(WASMModuleInstanceCommon *module_inst_comm,
                                  void *native_ptr, uint64 size)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMMemoryInstance *memory_inst;
    uint8 *addr = (uint8 *)native_ptr;
    uint64 max_linear_memory_size = MAX_LINEAR_MEMORY_SIZE;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    if (!is_bounds_checks_enabled(module_inst_comm)) {
        return true;
    }

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        goto fail;
    }

#if WASM_ENABLE_MEMORY64 != 0
    if (memory_inst->is_memory64)
        max_linear_memory_size = MAX_LINEAR_MEM64_MEMORY_SIZE;
#endif
    /* boundary overflow check */
    if (size > max_linear_memory_size || (uintptr_t)addr > UINTPTR_MAX - size) {
        goto fail;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    if (is_native_addr_in_shared_heap(
            module_inst_comm, memory_inst->is_memory64, native_ptr, size)) {
        return true;
    }
#endif

    SHARED_MEMORY_LOCK(memory_inst);

    if (memory_inst->memory_data <= addr
        && addr + size <= memory_inst->memory_data_end) {
        SHARED_MEMORY_UNLOCK(memory_inst);
        return true;
    }

    SHARED_MEMORY_UNLOCK(memory_inst);

fail:
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
}

void *
wasm_runtime_addr_app_to_native(WASMModuleInstanceCommon *module_inst_comm,
                                uint64 app_offset)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMMemoryInstance *memory_inst;
    uint8 *addr;
    bool bounds_checks;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    bounds_checks = is_bounds_checks_enabled(module_inst_comm);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return NULL;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    if (is_app_addr_in_shared_heap(module_inst_comm, memory_inst->is_memory64,
                                   app_offset, 1)) {
        return get_last_used_shared_heap_base_addr_adj(module_inst_comm)
               + app_offset;
    }
#endif

    SHARED_MEMORY_LOCK(memory_inst);

    addr = memory_inst->memory_data + (uintptr_t)app_offset;

    if (bounds_checks) {
        if (memory_inst->memory_data <= addr
            && addr < memory_inst->memory_data_end) {
            SHARED_MEMORY_UNLOCK(memory_inst);
            return addr;
        }
        SHARED_MEMORY_UNLOCK(memory_inst);
        return NULL;
    }

    /* If bounds checks is disabled, return the address directly */
    SHARED_MEMORY_UNLOCK(memory_inst);
    return addr;
}

uint64
wasm_runtime_addr_native_to_app(WASMModuleInstanceCommon *module_inst_comm,
                                void *native_ptr)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMMemoryInstance *memory_inst;
    uint8 *addr = (uint8 *)native_ptr;
    bool bounds_checks;
    uint64 ret;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    bounds_checks = is_bounds_checks_enabled(module_inst_comm);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return 0;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    if (is_native_addr_in_shared_heap(module_inst_comm,
                                      memory_inst->is_memory64, addr, 1)) {
        return (uint64)(uintptr_t)(addr
                                   - get_last_used_shared_heap_base_addr_adj(
                                       module_inst_comm));
    }
#endif

    SHARED_MEMORY_LOCK(memory_inst);

    if (bounds_checks) {
        if (memory_inst->memory_data <= addr
            && addr < memory_inst->memory_data_end) {
            ret = (uint64)(addr - memory_inst->memory_data);
            SHARED_MEMORY_UNLOCK(memory_inst);
            return ret;
        }
    }
    /* If bounds checks is disabled, return the offset directly */
    else if (addr != NULL) {
        ret = (uint64)(addr - memory_inst->memory_data);
        SHARED_MEMORY_UNLOCK(memory_inst);
        return ret;
    }

    SHARED_MEMORY_UNLOCK(memory_inst);
    return 0;
}

bool
wasm_runtime_get_app_addr_range(WASMModuleInstanceCommon *module_inst_comm,
                                uint64 app_offset, uint64 *p_app_start_offset,
                                uint64 *p_app_end_offset)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMMemoryInstance *memory_inst;
    uint64 memory_data_size;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return false;
    }

    SHARED_MEMORY_LOCK(memory_inst);

    memory_data_size = memory_inst->memory_data_size;

    if (app_offset < memory_data_size) {
        if (p_app_start_offset)
            *p_app_start_offset = 0;
        if (p_app_end_offset)
            *p_app_end_offset = memory_data_size;
        SHARED_MEMORY_UNLOCK(memory_inst);
        return true;
    }

    SHARED_MEMORY_UNLOCK(memory_inst);
    return false;
}

bool
wasm_runtime_get_native_addr_range(WASMModuleInstanceCommon *module_inst_comm,
                                   uint8 *native_ptr,
                                   uint8 **p_native_start_addr,
                                   uint8 **p_native_end_addr)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMMemoryInstance *memory_inst;
    uint8 *addr = (uint8 *)native_ptr;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    memory_inst = wasm_get_default_memory(module_inst);
    if (!memory_inst) {
        return false;
    }

    SHARED_MEMORY_LOCK(memory_inst);

    if (memory_inst->memory_data <= addr
        && addr < memory_inst->memory_data_end) {
        if (p_native_start_addr)
            *p_native_start_addr = memory_inst->memory_data;
        if (p_native_end_addr)
            *p_native_end_addr = memory_inst->memory_data_end;
        SHARED_MEMORY_UNLOCK(memory_inst);
        return true;
    }

    SHARED_MEMORY_UNLOCK(memory_inst);
    return false;
}

bool
wasm_check_app_addr_and_convert(WASMModuleInstance *module_inst, bool is_str,
                                uint64 app_buf_addr, uint64 app_buf_size,
                                void **p_native_addr)
{
    WASMMemoryInstance *memory_inst = wasm_get_default_memory(module_inst);
    uint8 *native_addr;
    bool bounds_checks;
#if WASM_ENABLE_SHARED_HEAP != 0
    uint8 *shared_heap_base_addr_adj = NULL;
    uintptr_t shared_heap_end_off = 0;
#endif

    bh_assert(app_buf_addr <= UINTPTR_MAX && app_buf_size <= UINTPTR_MAX);

    if (!memory_inst) {
        wasm_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    if (is_app_addr_in_shared_heap((WASMModuleInstanceCommon *)module_inst,
                                   memory_inst->is_memory64, app_buf_addr,
                                   app_buf_size)) {
        const char *str, *str_end;
        shared_heap_base_addr_adj = get_last_used_shared_heap_base_addr_adj(
            (WASMModuleInstanceCommon *)module_inst);
        shared_heap_end_off = get_last_used_shared_heap_end_offset(
            (WASMModuleInstanceCommon *)module_inst);
        native_addr = shared_heap_base_addr_adj + (uintptr_t)app_buf_addr;

        /* The whole string must be in the shared heap */
        str = (const char *)native_addr;
        str_end =
            (const char *)shared_heap_base_addr_adj + shared_heap_end_off + 1;
        while (str < str_end && *str != '\0')
            str++;
        if (str == str_end) {
            wasm_set_exception(module_inst, "out of bounds memory access");
            return false;
        }
        else
            goto success;
    }
#endif

    native_addr = memory_inst->memory_data + (uintptr_t)app_buf_addr;
    bounds_checks =
        is_bounds_checks_enabled((WASMModuleInstanceCommon *)module_inst);

    if (!bounds_checks) {
        if (app_buf_addr == 0) {
            native_addr = NULL;
        }
        goto success;
    }

    /* No need to check the app_offset and buf_size if memory access
       boundary check with hardware trap is enabled */
#ifndef OS_ENABLE_HW_BOUND_CHECK
    SHARED_MEMORY_LOCK(memory_inst);

    if (app_buf_addr >= memory_inst->memory_data_size) {
        goto fail;
    }

    if (!is_str) {
        if (app_buf_size > memory_inst->memory_data_size - app_buf_addr) {
            goto fail;
        }
    }
    else {
        const char *str, *str_end;

        /* The whole string must be in the linear memory */
        str = (const char *)native_addr;
        str_end = (const char *)memory_inst->memory_data_end;
        while (str < str_end && *str != '\0')
            str++;
        if (str == str_end)
            goto fail;
    }

    SHARED_MEMORY_UNLOCK(memory_inst);
#endif

success:
    *p_native_addr = (void *)native_addr;
    return true;

#ifndef OS_ENABLE_HW_BOUND_CHECK
fail:
    SHARED_MEMORY_UNLOCK(memory_inst);
    wasm_set_exception(module_inst, "out of bounds memory access");
    return false;
#endif
}

WASMMemoryInstance *
wasm_get_default_memory(WASMModuleInstance *module_inst)
{
    if (module_inst->memories)
        return module_inst->memories[0];
    else
        return NULL;
}

WASMMemoryInstance *
wasm_get_memory_with_idx(WASMModuleInstance *module_inst, uint32 index)
{
    if ((index >= module_inst->memory_count) || !module_inst->memories)
        return NULL;
    return module_inst->memories[index];
}

void
wasm_runtime_set_mem_bound_check_bytes(WASMMemoryInstance *memory,
                                       uint64 memory_data_size)
{
#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 || WASM_ENABLE_AOT != 0
#if UINTPTR_MAX == UINT64_MAX
    memory->mem_bound_check_1byte.u64 = memory_data_size - 1;
    memory->mem_bound_check_2bytes.u64 = memory_data_size - 2;
    memory->mem_bound_check_4bytes.u64 = memory_data_size - 4;
    memory->mem_bound_check_8bytes.u64 = memory_data_size - 8;
    memory->mem_bound_check_16bytes.u64 = memory_data_size - 16;
#else
    memory->mem_bound_check_1byte.u32[0] = (uint32)memory_data_size - 1;
    memory->mem_bound_check_2bytes.u32[0] = (uint32)memory_data_size - 2;
    memory->mem_bound_check_4bytes.u32[0] = (uint32)memory_data_size - 4;
    memory->mem_bound_check_8bytes.u32[0] = (uint32)memory_data_size - 8;
    memory->mem_bound_check_16bytes.u32[0] = (uint32)memory_data_size - 16;
#endif
#endif
}

static void
wasm_munmap_linear_memory(void *mapped_mem, uint64 commit_size, uint64 map_size)
{
#ifdef BH_PLATFORM_WINDOWS
    os_mem_decommit(mapped_mem, commit_size);
#else
    (void)commit_size;
#endif
    os_munmap(mapped_mem, map_size);
}

static void *
wasm_mremap_linear_memory(void *mapped_mem, uint64 old_size, uint64 new_size,
                          uint64 commit_size)
{
    void *new_mem;

    bh_assert(new_size > 0);
    bh_assert(new_size > old_size);

#if UINTPTR_MAX == UINT32_MAX
    if (new_size == 4 * (uint64)BH_GB) {
        LOG_WARNING("On 32 bit platform, linear memory can't reach maximum "
                    "size of 4GB\n");
        return NULL;
    }
#endif

    if (mapped_mem) {
        new_mem = os_mremap(mapped_mem, old_size, new_size);
    }
    else {
        new_mem = os_mmap(NULL, new_size, MMAP_PROT_NONE, MMAP_MAP_NONE,
                          os_get_invalid_handle());
    }
    if (!new_mem) {
        return NULL;
    }

#ifdef BH_PLATFORM_WINDOWS
    if (commit_size > 0
        && !os_mem_commit(new_mem, commit_size,
                          MMAP_PROT_READ | MMAP_PROT_WRITE)) {
        os_munmap(new_mem, new_size);
        return NULL;
    }
#endif

    if (os_mprotect(new_mem, commit_size, MMAP_PROT_READ | MMAP_PROT_WRITE)
        != 0) {
        wasm_munmap_linear_memory(new_mem, new_size, new_size);
        return NULL;
    }

    return new_mem;
}

static void *
wasm_mmap_linear_memory(uint64 map_size, uint64 commit_size)
{
    return wasm_mremap_linear_memory(NULL, 0, map_size, commit_size);
}

static bool
wasm_enlarge_memory_internal(WASMModuleInstanceCommon *module,
                             WASMMemoryInstance *memory, uint32 inc_page_count)
{
#if WASM_ENABLE_SHARED_HEAP != 0
    WASMSharedHeap *shared_heap;
#endif
    uint8 *memory_data_old, *memory_data_new, *heap_data_old;
    uint32 num_bytes_per_page, heap_size;
    uint32 cur_page_count, max_page_count, total_page_count;
    uint64 total_size_old = 0, total_size_new;
    bool ret = true, full_size_mmaped;
    enlarge_memory_error_reason_t failure_reason = INTERNAL_ERROR;

    if (!memory) {
        ret = false;
        goto return_func;
    }

#ifdef OS_ENABLE_HW_BOUND_CHECK
    full_size_mmaped = true;
#elif WASM_ENABLE_SHARED_MEMORY != 0
    full_size_mmaped = shared_memory_is_shared(memory);
#else
    full_size_mmaped = false;
#endif

    memory_data_old = memory->memory_data;
    total_size_old = memory->memory_data_size;

    heap_data_old = memory->heap_data;
    heap_size = (uint32)(memory->heap_data_end - memory->heap_data);

    num_bytes_per_page = memory->num_bytes_per_page;
    cur_page_count = memory->cur_page_count;
    max_page_count = memory->max_page_count;
    total_page_count = inc_page_count + cur_page_count;
    total_size_new = num_bytes_per_page * (uint64)total_page_count;

    if (inc_page_count <= 0)
        /* No need to enlarge memory */
        return true;

    if (total_page_count < cur_page_count) { /* integer overflow */
        ret = false;
        goto return_func;
    }

    if (total_page_count > max_page_count) {
        failure_reason = MAX_SIZE_REACHED;
        ret = false;
        goto return_func;
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    shared_heap = get_shared_heap(module);
    if (shared_heap) {
        if (memory->is_memory64
            && total_size_new > shared_heap->start_off_mem64) {
            LOG_WARNING("Linear memory address is overlapped with shared heap");
            ret = false;
            goto return_func;
        }
        else if (!memory->is_memory64
                 && total_size_new > shared_heap->start_off_mem32) {
            LOG_WARNING("Linear memory address is overlapped with shared heap");
            ret = false;
            goto return_func;
        }
    }
#endif

    bh_assert(total_size_new
              <= GET_MAX_LINEAR_MEMORY_SIZE(memory->is_memory64));

#if WASM_MEM_ALLOC_WITH_USAGE != 0
    if (!(memory_data_new =
              realloc_func(Alloc_For_LinearMemory, full_size_mmaped,
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
                           allocator_user_data,
#endif
                           memory_data_old, total_size_new))) {
        ret = false;
        goto return_func;
    }
    if (heap_size > 0) {
        if (mem_allocator_migrate(memory->heap_handle,
                                  (char *)heap_data_old
                                      + (memory_data_new - memory_data_old),
                                  heap_size)
            != 0) {
            ret = false;
        }
    }
    memory->heap_data = memory_data_new + (heap_data_old - memory_data_old);
    memory->heap_data_end = memory->heap_data + heap_size;
    memory->memory_data = memory_data_new;
#else
    if (full_size_mmaped) {
#ifdef BH_PLATFORM_WINDOWS
        if (!os_mem_commit(memory->memory_data_end,
                           total_size_new - total_size_old,
                           MMAP_PROT_READ | MMAP_PROT_WRITE)) {
            ret = false;
            goto return_func;
        }
#endif

        if (os_mprotect(memory->memory_data_end,
                        total_size_new - total_size_old,
                        MMAP_PROT_READ | MMAP_PROT_WRITE)
            != 0) {
#ifdef BH_PLATFORM_WINDOWS
            os_mem_decommit(memory->memory_data_end,
                            total_size_new - total_size_old);
#endif
            ret = false;
            goto return_func;
        }
    }
    else {
        if (heap_size > 0) {
            if (mem_allocator_is_heap_corrupted(memory->heap_handle)) {
                wasm_runtime_show_app_heap_corrupted_prompt();
                ret = false;
                goto return_func;
            }
        }

        if (!(memory_data_new =
                  wasm_mremap_linear_memory(memory_data_old, total_size_old,
                                            total_size_new, total_size_new))) {
            ret = false;
            goto return_func;
        }

        if (heap_size > 0) {
            if (mem_allocator_migrate(memory->heap_handle,
                                      (char *)heap_data_old
                                          + (memory_data_new - memory_data_old),
                                      heap_size)
                != 0) {
                /* Don't return here as memory->memory_data is obsolete and
                must be updated to be correctly used later. */
                ret = false;
            }
        }

        memory->heap_data = memory_data_new + (heap_data_old - memory_data_old);
        memory->heap_data_end = memory->heap_data + heap_size;
        memory->memory_data = memory_data_new;
#if defined(os_writegsbase)
        /* write base addr of linear memory to GS segment register */
        os_writegsbase(memory_data_new);
#endif
    }
#endif /* end of WASM_MEM_ALLOC_WITH_USAGE */

    /*
     * AOT compiler assumes at least 8 byte alignment.
     * see aot_check_memory_overflow.
     */
    bh_assert(((uintptr_t)memory->memory_data & 0x7) == 0);

    memory->num_bytes_per_page = num_bytes_per_page;
    memory->cur_page_count = total_page_count;
    memory->max_page_count = max_page_count;
    SET_LINEAR_MEMORY_SIZE(memory, total_size_new);
    memory->memory_data_end = memory->memory_data + total_size_new;

    wasm_runtime_set_mem_bound_check_bytes(memory, total_size_new);

return_func:
    if (!ret && module && enlarge_memory_error_cb) {
        WASMExecEnv *exec_env = NULL;

#if WASM_ENABLE_INTERP != 0
        if (module->module_type == Wasm_Module_Bytecode)
            exec_env = ((WASMModuleInstance *)module)->cur_exec_env;
#endif
#if WASM_ENABLE_AOT != 0
        if (module->module_type == Wasm_Module_AoT)
            exec_env = ((AOTModuleInstance *)module)->cur_exec_env;
#endif

        enlarge_memory_error_cb(inc_page_count, total_size_old, 0,
                                failure_reason, module, exec_env,
                                enlarge_memory_error_user_data);
    }

    return ret;
}

bool
wasm_runtime_enlarge_memory(WASMModuleInstanceCommon *module_inst,
                            uint64 inc_page_count)
{
    if (inc_page_count > UINT32_MAX) {
        return false;
    }

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return aot_enlarge_memory((AOTModuleInstance *)module_inst,
                                  (uint32)inc_page_count);
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_enlarge_memory((WASMModuleInstance *)module_inst,
                                   (uint32)inc_page_count);
    }
#endif

    return false;
}

void
wasm_runtime_set_enlarge_mem_error_callback(
    const enlarge_memory_error_callback_t callback, void *user_data)
{
    enlarge_memory_error_cb = callback;
    enlarge_memory_error_user_data = user_data;
}

bool
wasm_enlarge_memory(WASMModuleInstance *module, uint32 inc_page_count)
{
    bool ret = false;

    if (module->memory_count > 0) {
#if WASM_ENABLE_SHARED_MEMORY != 0
        shared_memory_lock(module->memories[0]);
#endif
        ret = wasm_enlarge_memory_internal((WASMModuleInstanceCommon *)module,
                                           module->memories[0], inc_page_count);
#if WASM_ENABLE_SHARED_MEMORY != 0
        shared_memory_unlock(module->memories[0]);
#endif
    }

    return ret;
}

bool
wasm_enlarge_memory_with_idx(WASMModuleInstance *module, uint32 inc_page_count,
                             uint32 memidx)
{
    bool ret = false;

    if (memidx < module->memory_count) {
#if WASM_ENABLE_SHARED_MEMORY != 0
        shared_memory_lock(module->memories[memidx]);
#endif
        ret = wasm_enlarge_memory_internal((WASMModuleInstanceCommon *)module,
                                           module->memories[memidx],
                                           inc_page_count);
#if WASM_ENABLE_SHARED_MEMORY != 0
        shared_memory_unlock(module->memories[memidx]);
#endif
    }

    return ret;
}

WASMMemoryInstance *
wasm_runtime_lookup_memory(WASMModuleInstanceCommon *module_inst,
                           const char *name)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return wasm_lookup_memory((WASMModuleInstance *)module_inst, name);
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return aot_lookup_memory((WASMModuleInstance *)module_inst, name);
#endif

    return NULL;
}

WASMMemoryInstance *
wasm_runtime_get_default_memory(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return wasm_get_default_memory((WASMModuleInstance *)module_inst);
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return aot_get_default_memory((AOTModuleInstance *)module_inst);
#endif

    return NULL;
}

WASMMemoryInstance *
wasm_runtime_get_memory(WASMModuleInstanceCommon *module_inst, uint32 index)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return wasm_get_memory_with_idx((WASMModuleInstance *)module_inst,
                                        index);
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return aot_get_memory_with_idx((AOTModuleInstance *)module_inst, index);
#endif

    return NULL;
}

uint64
wasm_memory_get_cur_page_count(WASMMemoryInstance *memory)
{
    return memory->cur_page_count;
}

uint64
wasm_memory_get_max_page_count(WASMMemoryInstance *memory)
{
    return memory->max_page_count;
}

uint64
wasm_memory_get_bytes_per_page(WASMMemoryInstance *memory)
{
    return memory->num_bytes_per_page;
}

bool
wasm_memory_get_shared(WASMMemoryInstance *memory)
{
    return memory->is_shared_memory;
}

void *
wasm_memory_get_base_address(WASMMemoryInstance *memory)
{
    return memory->memory_data;
}

bool
wasm_memory_enlarge(WASMMemoryInstance *memory, uint64 inc_page_count)
{
    bool ret = false;

    if (memory) {
#if WASM_ENABLE_SHARED_MEMORY != 0
        shared_memory_lock(memory);
#endif
        ret =
            wasm_enlarge_memory_internal(NULL, memory, (uint32)inc_page_count);
#if WASM_ENABLE_SHARED_MEMORY != 0
        shared_memory_unlock(memory);
#endif
    }

    return ret;
}

void
wasm_deallocate_linear_memory(WASMMemoryInstance *memory_inst)
{
    uint64 map_size;

    bh_assert(memory_inst);
    bh_assert(memory_inst->memory_data);

#ifndef OS_ENABLE_HW_BOUND_CHECK
#if WASM_ENABLE_SHARED_MEMORY != 0
    if (shared_memory_is_shared(memory_inst)) {
        map_size = (uint64)memory_inst->num_bytes_per_page
                   * memory_inst->max_page_count;
    }
    else
#endif
    {
        map_size = (uint64)memory_inst->num_bytes_per_page
                   * memory_inst->cur_page_count;
    }
#else
    map_size = 8 * (uint64)BH_GB;
#endif

#if WASM_MEM_ALLOC_WITH_USAGE != 0
    (void)map_size;
    free_func(Alloc_For_LinearMemory,
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
              allocator_user_data,
#endif
              memory_inst->memory_data);
#else
    wasm_munmap_linear_memory(memory_inst->memory_data,
                              memory_inst->memory_data_size, map_size);
#endif

    memory_inst->memory_data = NULL;
}

int
wasm_allocate_linear_memory(uint8 **data, bool is_shared_memory,
                            bool is_memory64, uint64 num_bytes_per_page,
                            uint64 init_page_count, uint64 max_page_count,
                            uint64 *memory_data_size)
{
    uint64 map_size, page_size;

    bh_assert(data);
    bh_assert(memory_data_size);

#ifndef OS_ENABLE_HW_BOUND_CHECK
#if WASM_ENABLE_SHARED_MEMORY != 0
    if (is_shared_memory) {
        /* Allocate maximum memory size when memory is shared */
        map_size = max_page_count * num_bytes_per_page;
    }
    else
#endif
    {
        map_size = init_page_count * num_bytes_per_page;
    }
#else  /* else of OS_ENABLE_HW_BOUND_CHECK */
    /* Totally 8G is mapped, the opcode load/store address range is 0 to 8G:
     *   ea = i + memarg.offset
     * both i and memarg.offset are u32 in range 0 to 4G
     * so the range of ea is 0 to 8G
     */
    map_size = 8 * (uint64)BH_GB;
#endif /* end of OS_ENABLE_HW_BOUND_CHECK */

    page_size = os_getpagesize();
    *memory_data_size = init_page_count * num_bytes_per_page;

    bh_assert(*memory_data_size <= GET_MAX_LINEAR_MEMORY_SIZE(is_memory64));
    *memory_data_size = align_as_and_cast(*memory_data_size, page_size);

    if (map_size > 0) {
#if WASM_MEM_ALLOC_WITH_USAGE != 0
        (void)wasm_mmap_linear_memory;
        if (!(*data = malloc_func(Alloc_For_LinearMemory,
#if WASM_MEM_ALLOC_WITH_USER_DATA != 0
                                  allocator_user_data,
#endif
                                  *memory_data_size))) {
            return BHT_ERROR;
        }
#else
        if (!(*data = wasm_mmap_linear_memory(map_size, *memory_data_size))) {
            return BHT_ERROR;
        }
#endif
    }

    /*
     * AOT compiler assumes at least 8 byte alignment.
     * see aot_check_memory_overflow.
     */
    bh_assert(((uintptr_t)*data & 0x7) == 0);

    return BHT_OK;
}
