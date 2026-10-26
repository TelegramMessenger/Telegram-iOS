/*
 * Copyright (C) 2023 Amazon Inc.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "libc_errno.h"
#include "platform_api_extension.h"

#define NANOSECONDS_PER_SECOND 1000000000ULL

static __wasi_errno_t
wasi_clockid_to_clockid(__wasi_clockid_t in, clockid_t *out)
{
    switch (in) {
        case __WASI_CLOCK_MONOTONIC:
            *out = CLOCK_MONOTONIC;
            return __WASI_ESUCCESS;
        case __WASI_CLOCK_REALTIME:
            *out = CLOCK_REALTIME;
            return __WASI_ESUCCESS;
        case __WASI_CLOCK_PROCESS_CPUTIME_ID:
#if defined(CLOCK_PROCESS_CPUTIME_ID)
            *out = CLOCK_PROCESS_CPUTIME_ID;
            return __WASI_ESUCCESS;
#else
            return __WASI_ENOTSUP;
#endif
        case __WASI_CLOCK_THREAD_CPUTIME_ID:
#if defined(CLOCK_THREAD_CPUTIME_ID)
            *out = CLOCK_THREAD_CPUTIME_ID;
            return __WASI_ESUCCESS;
#else
            return __WASI_ENOTSUP;
#endif
        default:
            return __WASI_EINVAL;
    }
}

static __wasi_timestamp_t
timespec_to_nanoseconds(const struct timespec *ts)
{
    if (ts->tv_sec < 0)
        return 0;
    if ((__wasi_timestamp_t)ts->tv_sec >= UINT64_MAX / NANOSECONDS_PER_SECOND)
        return UINT64_MAX;
    return (__wasi_timestamp_t)ts->tv_sec * NANOSECONDS_PER_SECOND
           + (__wasi_timestamp_t)ts->tv_nsec;
}

__wasi_errno_t
os_clock_res_get(__wasi_clockid_t clock_id, __wasi_timestamp_t *resolution)
{
    clockid_t nclock_id;
    __wasi_errno_t error = wasi_clockid_to_clockid(clock_id, &nclock_id);

    if (error != __WASI_ESUCCESS)
        return error;

    struct timespec ts;
    if (clock_getres(nclock_id, &ts) < 0)
        return convert_errno(errno);

    *resolution = timespec_to_nanoseconds(&ts);

    return error;
}

__wasi_errno_t
os_clock_time_get(__wasi_clockid_t clock_id, __wasi_timestamp_t precision,
                  __wasi_timestamp_t *time)
{
    clockid_t nclock_id;
    __wasi_errno_t error = wasi_clockid_to_clockid(clock_id, &nclock_id);

    (void)precision;

    if (error != __WASI_ESUCCESS)
        return error;

    struct timespec ts;
    if (clock_gettime(nclock_id, &ts) < 0)
        return convert_errno(errno);

    *time = timespec_to_nanoseconds(&ts);

    return error;
}
