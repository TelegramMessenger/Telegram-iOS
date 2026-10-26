/*
 * Copyright (C) 2023 Amazon Inc.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_SUSPEND_FLAGS_H
#define _WASM_SUSPEND_FLAGS_H

#include "bh_atomic.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Need to terminate */
#define WASM_SUSPEND_FLAG_TERMINATE 0x1
/* Need to suspend */
#define WASM_SUSPEND_FLAG_SUSPEND 0x2
/* Need to go into breakpoint */
#define WASM_SUSPEND_FLAG_BREAKPOINT 0x4
/* Return from pthread_exit */
#define WASM_SUSPEND_FLAG_EXIT 0x8
/* The thread might be blocking */
#define WASM_SUSPEND_FLAG_BLOCKING 0x10

typedef union WASMSuspendFlags {
    bh_atomic_32_t flags;
    uintptr_t __padding__;
} WASMSuspendFlags;

#define WASM_SUSPEND_FLAGS_IS_ATOMIC BH_ATOMIC_32_IS_ATOMIC
#define WASM_SUSPEND_FLAGS_GET(s_flags) BH_ATOMIC_32_LOAD(s_flags.flags)
#define WASM_SUSPEND_FLAGS_FETCH_OR(s_flags, val) \
    BH_ATOMIC_32_FETCH_OR(s_flags.flags, val)
#define WASM_SUSPEND_FLAGS_FETCH_AND(s_flags, val) \
    BH_ATOMIC_32_FETCH_AND(s_flags.flags, val)

#define WASM_SUSPEND_FLAG_INHERIT_MASK (~WASM_SUSPEND_FLAG_BLOCKING)

#if WASM_SUSPEND_FLAGS_IS_ATOMIC != 0
#define WASM_SUSPEND_FLAGS_LOCK(lock) (void)0
#define WASM_SUSPEND_FLAGS_UNLOCK(lock) (void)0
#else /* else of WASM_SUSPEND_FLAGS_IS_ATOMIC */
#define WASM_SUSPEND_FLAGS_LOCK(lock) os_mutex_lock(&lock)
#define WASM_SUSPEND_FLAGS_UNLOCK(lock) os_mutex_unlock(&lock);
#endif /* WASM_SUSPEND_FLAGS_IS_ATOMIC */

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_SUSPEND_FLAGS_H */
