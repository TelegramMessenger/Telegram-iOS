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

#ifndef SSP_CONFIG_H
#define SSP_CONFIG_H

#include "bh_platform.h"
#include "gnuc.h"

#if defined(__FreeBSD__) || defined(__APPLE__) \
    || ((defined(ANDROID) || defined(__ANDROID__)) && (__ANDROID_API__ < 28))
#define CONFIG_HAS_ARC4RANDOM_BUF 1
#else
#define CONFIG_HAS_ARC4RANDOM_BUF 0
#endif

// On Linux, prefer to use getrandom, though it isn't available in
// GLIBC before 2.25.
//
// NuttX has arc4random_buf, getrandom, and /dev/urandom.
// We prefer getrandom here because it has the best chance to be usable.
// - Our /dev/urandom usage (keep the open descriptor in a global variable)
//   is not compatible with NuttX flat memory model.
// - arc4random_buf is only available with CONFIG_CRYPTO_RANDOM_POOL=y.
#if defined(__NuttX__)                               \
    || ((defined(__linux__) || defined(ESP_PLATFORM) \
         || defined(__COSMOPOLITAN__))               \
        && (!defined(__GLIBC__) || __GLIBC__ > 2     \
            || (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 25)))
#define CONFIG_HAS_GETRANDOM 1
#else
#define CONFIG_HAS_GETRANDOM 0
#endif

#if defined(__CloudABI__) || defined(BH_PLATFORM_FREERTOS)
#define CONFIG_HAS_CAP_ENTER 1
#else
#define CONFIG_HAS_CAP_ENTER 0
#endif

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(__EMSCRIPTEN__) \
    && !defined(ESP_PLATFORM) && !defined(DISABLE_CLOCK_NANOSLEEP)           \
    && !defined(BH_PLATFORM_FREERTOS)
#define CONFIG_HAS_CLOCK_NANOSLEEP 1
#else
#define CONFIG_HAS_CLOCK_NANOSLEEP 0
#endif

#if defined(__APPLE__) || defined(__CloudABI__)
#define CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP 1
#else
#define CONFIG_HAS_PTHREAD_COND_TIMEDWAIT_RELATIVE_NP 0
#endif

#if !defined(__APPLE__) && !defined(BH_PLATFORM_LINUX_SGX) && !defined(_WIN32) \
    && !defined(__COSMOPOLITAN__) && !defined(BH_PLATFORM_FREERTOS)
#define CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK 1
#else
#define CONFIG_HAS_PTHREAD_CONDATTR_SETCLOCK 0
#endif

#if !defined(BH_PLATFORM_LINUX_SGX)

/* Clang's __GNUC_PREREQ macro has a different meaning than GCC one,
so we have to handle this case specially */
#if defined(__clang__)

/* Clang provides stdatomic.h since 3.6.0
See https://releases.llvm.org/3.6.0/tools/clang/docs/ReleaseNotes.html */
#if __clang_major__ > 3 || (__clang_major__ == 3 && __clang_minor__ >= 6)
#define CONFIG_HAS_STD_ATOMIC 1
#else
#define CONFIG_HAS_STD_ATOMIC 0
#endif

#elif defined(__GNUC_PREREQ)

/* Even though older versions of GCC support C11, atomics were
not implemented until 4.9. See
https://gcc.gnu.org/bugzilla/show_bug.cgi?id=58016 */
#if __GNUC_PREREQ(4, 9)
#define CONFIG_HAS_STD_ATOMIC 1
#else /* else of __GNUC_PREREQ(4, 9) */
#define CONFIG_HAS_STD_ATOMIC 0
#endif /* end of __GNUC_PREREQ(4, 9) */

#elif defined(_MSC_VER)

#define CONFIG_HAS_STD_ATOMIC 0

#else

#define CONFIG_HAS_STD_ATOMIC 1

#endif /* end of defined(__clang__) */

#else /* else of !defined(BH_PLATFORM_LINUX_SGX) */

#define CONFIG_HAS_STD_ATOMIC 0

#endif /* end of !defined(BH_PLATFORM_LINUX_SGX) */

#endif /* end of SSP_CONFIG_H */
