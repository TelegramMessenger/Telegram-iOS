/*
 * Copyright (C) 2023 Midokura Japan KK.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "wasm_runtime_common.h"

#include "bh_platform.h"
#include "bh_common.h"
#include "bh_assert.h"

#if WASM_ENABLE_THREAD_MGR != 0 && defined(OS_ENABLE_WAKEUP_BLOCKING_OP)

#define LOCK(env) WASM_SUSPEND_FLAGS_LOCK((env)->wait_lock)
#define UNLOCK(env) WASM_SUSPEND_FLAGS_UNLOCK((env)->wait_lock)

#define ISSET(env, bit)                                                       \
    ((WASM_SUSPEND_FLAGS_GET((env)->suspend_flags) & WASM_SUSPEND_FLAG_##bit) \
     != 0)
#define SET(env, bit) \
    WASM_SUSPEND_FLAGS_FETCH_OR((env)->suspend_flags, WASM_SUSPEND_FLAG_##bit)
#define CLR(env, bit) \
    WASM_SUSPEND_FLAGS_FETCH_AND((env)->suspend_flags, ~WASM_SUSPEND_FLAG_##bit)

bool
wasm_runtime_begin_blocking_op(wasm_exec_env_t env)
{
    LOCK(env);
    bh_assert(!ISSET(env, BLOCKING));
    SET(env, BLOCKING);
    if (ISSET(env, TERMINATE)) {
        CLR(env, BLOCKING);
        UNLOCK(env);
        return false;
    }
    UNLOCK(env);
    os_begin_blocking_op();
    return true;
}

void
wasm_runtime_end_blocking_op(wasm_exec_env_t env)
{
    int saved_errno = errno;
    LOCK(env);
    bh_assert(ISSET(env, BLOCKING));
    CLR(env, BLOCKING);
    UNLOCK(env);
    os_end_blocking_op();
    errno = saved_errno;
}

void
wasm_runtime_interrupt_blocking_op(wasm_exec_env_t env)
{
    /*
     * ISSET(BLOCKING) here means that the target thread
     * is in somewhere between wasm_begin_blocking_op and
     * wasm_end_blocking_op.
     * keep waking it up until it reaches wasm_end_blocking_op,
     * which clears the BLOCKING bit.
     *
     * this dumb loop is necessary because posix doesn't provide
     * a way to unmask signal and block atomically.
     */

    LOCK(env);
    SET(env, TERMINATE);
    while (ISSET(env, BLOCKING)) {
        UNLOCK(env);
        os_wakeup_blocking_op(env->handle);

        /* relax a bit */
        os_usleep(50 * 1000);
        LOCK(env);
    }
    UNLOCK(env);
}

#else /* WASM_ENABLE_THREAD_MGR && OS_ENABLE_WAKEUP_BLOCKING_OP */

bool
wasm_runtime_begin_blocking_op(wasm_exec_env_t env)
{
    return true;
}

void
wasm_runtime_end_blocking_op(wasm_exec_env_t env)
{}

#endif /* WASM_ENABLE_THREAD_MGR && OS_ENABLE_WAKEUP_BLOCKING_OP */
