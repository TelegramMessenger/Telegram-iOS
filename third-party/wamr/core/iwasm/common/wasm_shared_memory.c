/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_log.h"
#include "wasm_shared_memory.h"
#if WASM_ENABLE_THREAD_MGR != 0
#include "../libraries/thread-mgr/thread_manager.h"
#endif
#if WASM_ENABLE_AOT != 0
#include "../aot/aot_runtime.h"
#endif

/*
 * Note: this lock can be per memory.
 *
 * For now, just use a global because:
 * - it's a bit cumbersome to extend WASMMemoryInstance w/o breaking
 *   the AOT ABI.
 * - If you care performance, it's better to make the interpreters
 *   use atomic ops.
 */
korp_mutex g_shared_memory_lock;

/* clang-format off */
enum {
    S_WAITING,
    S_NOTIFIED
};
/* clang-format on */

typedef struct AtomicWaitInfo {
    bh_list wait_list_head;
    bh_list *wait_list;
    /* WARNING: insert to the list allowed only in acquire_wait_info
       otherwise there will be data race as described in PR #2016 */
} AtomicWaitInfo;

typedef struct AtomicWaitNode {
    bh_list_link l;
    uint8 status;
    korp_cond wait_cond;
} AtomicWaitNode;

/* Atomic wait map */
static HashMap *wait_map;

static uint32
wait_address_hash(const void *address);

static bool
wait_address_equal(void *h1, void *h2);

static void
destroy_wait_info(void *wait_info);

bool
wasm_shared_memory_init()
{
    if (os_mutex_init(&g_shared_memory_lock) != 0)
        return false;
    /* wait map not exists, create new map */
    if (!(wait_map = bh_hash_map_create(32, true, (HashFunc)wait_address_hash,
                                        (KeyEqualFunc)wait_address_equal, NULL,
                                        destroy_wait_info))) {
        os_mutex_destroy(&g_shared_memory_lock);
        return false;
    }
    return true;
}

void
wasm_shared_memory_destroy()
{
    bh_hash_map_destroy(wait_map);
    os_mutex_destroy(&g_shared_memory_lock);
}

uint16
shared_memory_inc_reference(WASMMemoryInstance *memory)
{
    bh_assert(shared_memory_is_shared(memory));
    uint16 old;
#if BH_ATOMIC_16_IS_ATOMIC == 0
    os_mutex_lock(&g_shared_memory_lock);
#endif
    old = BH_ATOMIC_16_FETCH_ADD(memory->ref_count, 1);
#if BH_ATOMIC_16_IS_ATOMIC == 0
    os_mutex_unlock(&g_shared_memory_lock);
#endif
    bh_assert(old >= 1);
    bh_assert(old < UINT16_MAX);
    return old + 1;
}

uint16
shared_memory_dec_reference(WASMMemoryInstance *memory)
{
    bh_assert(shared_memory_is_shared(memory));
    uint16 old;
#if BH_ATOMIC_16_IS_ATOMIC == 0
    os_mutex_lock(&g_shared_memory_lock);
#endif
    old = BH_ATOMIC_16_FETCH_SUB(memory->ref_count, 1);
#if BH_ATOMIC_16_IS_ATOMIC == 0
    os_mutex_unlock(&g_shared_memory_lock);
#endif
    bh_assert(old > 0);
    return old - 1;
}

static korp_mutex *
shared_memory_get_lock_pointer(WASMMemoryInstance *memory)
{
    bh_assert(memory != NULL);
    return &g_shared_memory_lock;
}

/* Atomics wait && notify APIs */
static uint32
wait_address_hash(const void *address)
{
    return (uint32)(uintptr_t)address;
}

static bool
wait_address_equal(void *h1, void *h2)
{
    return h1 == h2 ? true : false;
}

static bool
is_wait_node_exists(bh_list *wait_list, AtomicWaitNode *node)
{
    AtomicWaitNode *curr;
    curr = bh_list_first_elem(wait_list);

    while (curr) {
        if (curr == node) {
            return true;
        }
        curr = bh_list_elem_next(curr);
    }

    return false;
}

static uint32
notify_wait_list(bh_list *wait_list, uint32 count)
{
    AtomicWaitNode *node, *next;
    uint32 i, notify_count = count;

    if (count > wait_list->len)
        notify_count = wait_list->len;

    node = bh_list_first_elem(wait_list);
    if (!node)
        return 0;

    for (i = 0; i < notify_count; i++) {
        bh_assert(node);
        next = bh_list_elem_next(node);

        node->status = S_NOTIFIED;
        /* wakeup */
        os_cond_signal(&node->wait_cond);

        node = next;
    }

    return notify_count;
}

static AtomicWaitInfo *
acquire_wait_info(void *address, AtomicWaitNode *wait_node)
{
    AtomicWaitInfo *wait_info = NULL;
    bh_list_status ret;

    bh_assert(address != NULL);

    wait_info = (AtomicWaitInfo *)bh_hash_map_find(wait_map, address);

    if (!wait_node) {
        return wait_info;
    }

    /* No wait info on this address, create new info */
    if (!wait_info) {
        if (!(wait_info = (AtomicWaitInfo *)wasm_runtime_malloc(
                  sizeof(AtomicWaitInfo)))) {
            return NULL;
        }
        memset(wait_info, 0, sizeof(AtomicWaitInfo));

        /* init wait list */
        wait_info->wait_list = &wait_info->wait_list_head;
        ret = bh_list_init(wait_info->wait_list);
        bh_assert(ret == BH_LIST_SUCCESS);
        (void)ret;

        if (!bh_hash_map_insert(wait_map, address, (void *)wait_info)) {
            wasm_runtime_free(wait_info);
            return NULL;
        }
    }

    ret = bh_list_insert(wait_info->wait_list, wait_node);
    bh_assert(ret == BH_LIST_SUCCESS);
    (void)ret;

    return wait_info;
}

static void
destroy_wait_info(void *wait_info)
{
    AtomicWaitNode *node, *next;

    if (wait_info) {

        node = bh_list_first_elem(((AtomicWaitInfo *)wait_info)->wait_list);

        while (node) {
            next = bh_list_elem_next(node);
            os_cond_destroy(&node->wait_cond);
            wasm_runtime_free(node);
            node = next;
        }

        wasm_runtime_free(wait_info);
    }
}

static void
map_try_release_wait_info(HashMap *wait_hash_map, AtomicWaitInfo *wait_info,
                          void *address)
{
    if (wait_info->wait_list->len > 0) {
        return;
    }

    bh_hash_map_remove(wait_hash_map, address, NULL, NULL);
    destroy_wait_info(wait_info);
}

#if WASM_ENABLE_SHARED_HEAP != 0
static bool
is_native_addr_in_shared_heap(WASMModuleInstanceCommon *module_inst,
                              uint8 *addr, uint32 bytes)
{
    WASMSharedHeap *shared_heap = NULL;

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        shared_heap = ((WASMModuleInstance *)module_inst)->e->shared_heap;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
        shared_heap = e->shared_heap;
    }
#endif

    return shared_heap && addr >= shared_heap->base_addr
           && addr + bytes <= shared_heap->base_addr + shared_heap->size;
}
#endif

uint32
wasm_runtime_atomic_wait(WASMModuleInstanceCommon *module, void *address,
                         uint64 expect, int64 timeout, bool wait64)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module;
    AtomicWaitInfo *wait_info;
    AtomicWaitNode *wait_node;
    korp_mutex *lock;
#if WASM_ENABLE_THREAD_MGR != 0
    WASMExecEnv *exec_env;
#endif
    uint64 timeout_left, timeout_wait, timeout_1sec;
    bool check_ret, is_timeout, no_wait;

    bh_assert(module->module_type == Wasm_Module_Bytecode
              || module->module_type == Wasm_Module_AoT);

    if (wasm_copy_exception(module_inst, NULL)) {
        return -1;
    }

    /* Currently we have only one memory instance */
    if (!shared_memory_is_shared(module_inst->memories[0])) {
        wasm_runtime_set_exception(module, "expected shared memory");
        return -1;
    }

    shared_memory_lock(module_inst->memories[0]);
    if (
#if WASM_ENABLE_SHARED_HEAP != 0
        /* not in shared heap */
        !is_native_addr_in_shared_heap((WASMModuleInstanceCommon *)module_inst,
                                       address, wait64 ? 8 : 4)
        &&
#endif
        /* and not in linear memory */
        ((uint8 *)address < module_inst->memories[0]->memory_data
         || (uint8 *)address + (wait64 ? 8 : 4)
                > module_inst->memories[0]->memory_data_end)) {
        shared_memory_unlock(module_inst->memories[0]);
        wasm_runtime_set_exception(module, "out of bounds memory access");
        return -1;
    }
    shared_memory_unlock(module_inst->memories[0]);

#if WASM_ENABLE_THREAD_MGR != 0
    exec_env =
        wasm_clusters_search_exec_env((WASMModuleInstanceCommon *)module_inst);
    bh_assert(exec_env);
#endif

    lock = shared_memory_get_lock_pointer(module_inst->memories[0]);

    /* Lock the shared_mem_lock for the whole atomic wait process,
       and use it to os_cond_reltimedwait */
    os_mutex_lock(lock);

    no_wait = (!wait64 && *(uint32 *)address != (uint32)expect)
              || (wait64 && *(uint64 *)address != expect);

    if (no_wait) {
        os_mutex_unlock(lock);
        return 1;
    }

    if (!(wait_node = wasm_runtime_malloc(sizeof(AtomicWaitNode)))) {
        os_mutex_unlock(lock);
        wasm_runtime_set_exception(module, "failed to create wait node");
        return -1;
    }
    memset(wait_node, 0, sizeof(AtomicWaitNode));

    if (0 != os_cond_init(&wait_node->wait_cond)) {
        os_mutex_unlock(lock);
        wasm_runtime_free(wait_node);
        wasm_runtime_set_exception(module, "failed to init wait cond");
        return -1;
    }

    wait_node->status = S_WAITING;

    /* Acquire the wait info, create new one if not exists */
    wait_info = acquire_wait_info(address, wait_node);

    if (!wait_info) {
        os_mutex_unlock(lock);
        os_cond_destroy(&wait_node->wait_cond);
        wasm_runtime_free(wait_node);
        wasm_runtime_set_exception(module, "failed to acquire wait_info");
        return -1;
    }

    /* unit of timeout is nsec, convert it to usec */
    timeout_left = (uint64)timeout / 1000;
    timeout_1sec = (uint64)1e6;

    while (1) {
        if (timeout < 0) {
            /* wait forever until it is notified or terminated
               here we keep waiting and checking every second */
            os_cond_reltimedwait(&wait_node->wait_cond, lock,
                                 (uint64)timeout_1sec);
            if (wait_node->status == S_NOTIFIED /* notified by atomic.notify */
#if WASM_ENABLE_THREAD_MGR != 0
                /* terminated by other thread */
                || wasm_cluster_is_thread_terminated(exec_env)
#endif
            ) {
                break;
            }
        }
        else {
            timeout_wait =
                timeout_left < timeout_1sec ? timeout_left : timeout_1sec;
            os_cond_reltimedwait(&wait_node->wait_cond, lock, timeout_wait);
            if (wait_node->status == S_NOTIFIED /* notified by atomic.notify */
                || timeout_left <= timeout_wait /* time out */
#if WASM_ENABLE_THREAD_MGR != 0
                /* terminated by other thread */
                || wasm_cluster_is_thread_terminated(exec_env)
#endif
            ) {
                break;
            }
            timeout_left -= timeout_wait;
        }
    }

    is_timeout = wait_node->status == S_WAITING ? true : false;

    check_ret = is_wait_node_exists(wait_info->wait_list, wait_node);
    bh_assert(check_ret);
    (void)check_ret;

    /* Remove wait node from wait list */
    bh_list_remove(wait_info->wait_list, wait_node);
    os_cond_destroy(&wait_node->wait_cond);
    wasm_runtime_free(wait_node);

    /* Release wait info if no wait nodes are attached */
    map_try_release_wait_info(wait_map, wait_info, address);

    os_mutex_unlock(lock);

    return is_timeout ? 2 : 0;
}

uint32
wasm_runtime_atomic_notify(WASMModuleInstanceCommon *module, void *address,
                           uint32 count)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module;
    uint32 notify_result;
    AtomicWaitInfo *wait_info;
    korp_mutex *lock;
    bool out_of_bounds;

    bh_assert(module->module_type == Wasm_Module_Bytecode
              || module->module_type == Wasm_Module_AoT);

    shared_memory_lock(module_inst->memories[0]);
    out_of_bounds =
#if WASM_ENABLE_SHARED_HEAP != 0
        /* not in shared heap */
        !is_native_addr_in_shared_heap(module, address, 4) &&
#endif
        /* and not in linear memory */
        ((uint8 *)address < module_inst->memories[0]->memory_data
         || (uint8 *)address + 4 > module_inst->memories[0]->memory_data_end);
    shared_memory_unlock(module_inst->memories[0]);

    if (out_of_bounds) {
        wasm_runtime_set_exception(module, "out of bounds memory access");
        return -1;
    }

    /* Currently we have only one memory instance */
    if (!shared_memory_is_shared(module_inst->memories[0])) {
        /* Always return 0 for ushared linear memory since there is
           no way to create a waiter on it */
        return 0;
    }

    lock = shared_memory_get_lock_pointer(module_inst->memories[0]);

    /* Lock the shared_mem_lock for the whole atomic notify process,
       and use it to os_cond_signal */
    os_mutex_lock(lock);

    wait_info = acquire_wait_info(address, NULL);

    /* Nobody wait on this address */
    if (!wait_info) {
        os_mutex_unlock(lock);
        return 0;
    }

    /* Notify each wait node in the wait list */
    notify_result = notify_wait_list(wait_info->wait_list, count);

    os_mutex_unlock(lock);

    return notify_result;
}
