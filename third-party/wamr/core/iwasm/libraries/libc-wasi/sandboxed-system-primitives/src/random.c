// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016 Nuxi, https://nuxi.nl/

#include "ssp_config.h"
#include "bh_platform.h"
#include "libc_errno.h"
#include "random.h"

#if CONFIG_HAS_ARC4RANDOM_BUF

__wasi_errno_t
random_buf(void *buf, size_t len)
{
    arc4random_buf(buf, len);
    return __WASI_ESUCCESS;
}

#elif CONFIG_HAS_GETRANDOM

#ifndef BH_PLATFORM_LINUX_SGX
#include <sys/random.h>
#endif

__wasi_errno_t
random_buf(void *buf, size_t len)
{
    for (;;) {
        ssize_t x = getrandom(buf, len, 0);
        if (x < 0) {
            if (errno == EINTR)
                continue;
            return convert_errno(errno);
        }
        if ((size_t)x == len)
            break;
        buf = (void *)((unsigned char *)buf + x);
        len -= (size_t)x;
    }
    return __WASI_ESUCCESS;
}

#elif defined(BH_PLATFORM_WINDOWS)

#include <bcrypt.h>
#pragma comment(lib, "Bcrypt.lib")

__wasi_errno_t
random_buf(void *buf, size_t len)
{
    NTSTATUS ret =
        BCryptGenRandom(NULL, buf, (ULONG)len, BCRYPT_USE_SYSTEM_PREFERRED_RNG);

    // Since we pass NULL for the algorithm handle, the only way BCryptGenRandom
    // can fail is if one of the parameters is invalid
    // (STATUS_INVALID_PARAMETER).
    return ret ? __WASI_EINVAL : __WASI_ESUCCESS;
}

#else

static int urandom = -1;
static __wasi_errno_t urandom_error = __WASI_ESUCCESS;

static void
open_urandom(void)
{
    urandom = open("/dev/urandom", O_RDONLY);
    if (urandom < 0)
        urandom_error = convert_errno(errno);
}

__wasi_errno_t
random_buf(void *buf, size_t len)
{
    static pthread_once_t open_once = PTHREAD_ONCE_INIT;
    int pthread_ret = pthread_once(&open_once, open_urandom);

    if (pthread_ret != 0)
        return convert_errno(pthread_ret);

    if (urandom < 0)
        return urandom_error;

    size_t bytes_read = 0;

    while (bytes_read < len) {
        ssize_t bytes_read_now =
            read(urandom, buf + bytes_read, len - bytes_read);

        if (bytes_read_now < 0)
            return convert_errno(errno);

        bytes_read += (size_t)bytes_read_now;
    }

    return __WASI_ESUCCESS;
}

#endif

// Calculates a random number within the range [0, upper - 1] without
// any modulo bias.
//
// The function below repeatedly obtains a random number from
// arc4random() until it lies within the range [2^k % upper, 2^k). As
// this range has length k * upper, we can safely obtain a number
// without any modulo bias.
__wasi_errno_t
random_uniform(uintmax_t upper, uintmax_t *out)
{
    // Compute 2^k % upper
    //      == (2^k - upper) % upper
    //      == -upper % upper.
    uintmax_t lower = -upper % upper;
    for (;;) {
        uintmax_t value;
        __wasi_errno_t error = random_buf(&value, sizeof(value));

        if (error != __WASI_ESUCCESS)
            return error;

        if (value >= lower) {
            *out = value % upper;
            return error;
        }
    }
}
