/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_log.h"

/**
 * The verbose level of the log system.  Only those verbose logs whose
 * levels are less than or equal to this value are output.
 */
static uint32 log_verbose_level = BH_LOG_LEVEL_WARNING;

void
bh_log_set_verbose_level(uint32 level)
{
    log_verbose_level = level;
}

#ifndef BH_LOG
void
bh_log(LogLevel log_level, const char *file, int line, const char *fmt, ...)
{
    va_list ap;
    korp_tid self;
    char buf[32] = { 0 };
    uint64 usec;
    uint32 t, h, m, s, mills;

    if ((uint32)log_level > log_verbose_level)
        return;

    self = os_self_thread();

    usec = os_time_get_boot_us();
    t = (uint32)(usec / 1000000) % (24 * 60 * 60);
    h = t / (60 * 60);
    t = t % (60 * 60);
    m = t / 60;
    s = t % 60;
    mills = (uint32)((usec % 1000000) / 1000);

    snprintf(buf, sizeof(buf),
             "%02" PRIu32 ":%02" PRIu32 ":%02" PRIu32 ":%03" PRIu32, h, m, s,
             mills);

#ifndef BH_VPRINTF
    os_printf("[%s - %" PRIXPTR "]: ", buf, (uintptr_t)self);
#endif

    if (file)
        os_printf("%s, line %d, ", file, line);

    va_start(ap, fmt);
    os_vprintf(fmt, ap);
    va_end(ap);

    os_printf("\n");
}
#endif

static uint32 last_time_ms = 0;
static uint32 total_time_ms = 0;

void
bh_print_time(const char *prompt)
{
    uint32 curr_time_ms;

    if (log_verbose_level < 3)
        return;

    curr_time_ms = (uint32)bh_get_tick_ms();

    if (last_time_ms == 0)
        last_time_ms = curr_time_ms;

    total_time_ms += curr_time_ms - last_time_ms;

    os_printf("%-48s time of last stage: %" PRIu32 " ms, total time: %" PRIu32
              " ms\n",
              prompt, curr_time_ms - last_time_ms, total_time_ms);

    last_time_ms = curr_time_ms;
}

void
bh_print_proc_mem(const char *prompt)
{
    char buf[1024] = { 0 };

    if (log_verbose_level < BH_LOG_LEVEL_DEBUG)
        return;

    if (os_dumps_proc_mem_info(buf, sizeof(buf)) != 0)
        return;

    os_printf("%s\n", prompt);
    os_printf("===== memory usage =====\n");
    os_printf("%s", buf);
    os_printf("==========\n");
    return;
}

void
bh_log_proc_mem(const char *function, uint32 line)
{
    char prompt[128] = { 0 };
    snprintf(prompt, sizeof(prompt), "[MEM] %s(...) L%" PRIu32, function, line);
    bh_print_proc_mem(prompt);
}
