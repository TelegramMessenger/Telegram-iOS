/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_SHARED_MEMORY_H
#define _WASM_SHARED_MEMORY_H

#include "bh_common.h"
#include "../interpreter/wasm_runtime.h"
#include "wasm_runtime_common.h"

#ifdef __cplusplus
extern "C" {
#endif

extern korp_mutex g_shared_memory_lock;

bool
wasm_shared_memory_init(void);

void
wasm_shared_memory_destroy(void);

uint16
shared_memory_inc_reference(WASMMemoryInstance *memory);

uint16
shared_memory_dec_reference(WASMMemoryInstance *memory);

#define shared_memory_is_shared(memory) memory->is_shared_memory

#define shared_memory_lock(memory)                                            \
    do {                                                                      \
        /*                                                                    \
         * Note: exception logic is currently abusing this lock.              \
         * cf.                                                                \
         * https://github.com/bytecodealliance/wasm-micro-runtime/issues/2407 \
         */                                                                   \
        bh_assert(memory != NULL);                                            \
        if (memory->is_shared_memory)                                         \
            os_mutex_lock(&g_shared_memory_lock);                             \
    } while (0)

#define shared_memory_unlock(memory)                \
    do {                                            \
        if (memory->is_shared_memory)               \
            os_mutex_unlock(&g_shared_memory_lock); \
    } while (0)

uint32
wasm_runtime_atomic_wait(WASMModuleInstanceCommon *module, void *address,
                         uint64 expect, int64 timeout, bool wait64);

uint32
wasm_runtime_atomic_notify(WASMModuleInstanceCommon *module, void *address,
                           uint32 count);

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_SHARED_MEMORY_H */
