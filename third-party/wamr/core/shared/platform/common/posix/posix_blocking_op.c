/*
 * Copyright (C) 2023 Midokura Japan KK.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "platform_api_extension.h"

#ifdef OS_ENABLE_WAKEUP_BLOCKING_OP

static bool g_blocking_op_inited = false;
static int g_blocking_op_signo = SIGUSR1;
static sigset_t g_blocking_op_sigmask;

static void
blocking_op_sighandler(int signo)
{
    /* nothing */
    (void)signo;
}

void
os_set_signal_number_for_blocking_op(int signo)
{
    g_blocking_op_signo = signo;
}

int
os_blocking_op_init()
{
    if (g_blocking_op_inited) {
        return BHT_OK;
    }

    sigemptyset(&g_blocking_op_sigmask);
    sigaddset(&g_blocking_op_sigmask, g_blocking_op_signo);

    struct sigaction sa;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sa.sa_handler = blocking_op_sighandler;
    if (sigaction(g_blocking_op_signo, &sa, NULL)) {
        return BHT_ERROR;
    }
    g_blocking_op_inited = true;
    return BHT_OK;
}

void
os_begin_blocking_op()
{
    pthread_sigmask(SIG_UNBLOCK, &g_blocking_op_sigmask, NULL);
}

void
os_end_blocking_op()
{
    pthread_sigmask(SIG_BLOCK, &g_blocking_op_sigmask, NULL);
}

int
os_wakeup_blocking_op(korp_tid tid)
{
    int ret = pthread_kill(tid, g_blocking_op_signo);
    if (ret != 0) {
        return BHT_ERROR;
    }
    return BHT_OK;
}

#endif /* OS_ENABLE_WAKEUP_BLOCKING_OP */
