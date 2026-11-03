/*
 * Copyright (C) 2023 Midokura Japan KK.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include <time.h>

#include "platform_api_extension.h"

int
os_usleep(uint32 usec)
{
    struct timespec ts;
    int ret;

    ts.tv_sec = usec / 1000000;
    ts.tv_nsec = (usec % 1000000) * 1000;
    ret = nanosleep(&ts, NULL);
    return ret == 0 ? 0 : -1;
}
