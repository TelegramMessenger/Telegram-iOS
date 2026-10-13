/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _PLATFORM_COMMON_H
#define _PLATFORM_COMMON_H

#ifdef __cplusplus
extern "C" {
#endif

#include "platform_internal.h"
#include "../../../config.h"

#define BH_MAX_THREAD 32

#define BHT_ERROR (-1)
#define BHT_TIMED_OUT (1)
#define BHT_OK (0)

#define BHT_WAIT_FOREVER ((uint64)-1LL)

#define BH_KB (1024)
#define BH_MB ((BH_KB)*1024)
#define BH_GB ((BH_MB)*1024)

#ifndef BH_MALLOC
#define BH_MALLOC os_malloc
#endif

#ifndef BH_FREE
#define BH_FREE os_free
#endif

#ifndef BH_TIME_T_MAX
#define BH_TIME_T_MAX LONG_MAX
#endif

#if defined(_MSC_BUILD)
#if defined(COMPILING_WASM_RUNTIME_API)
__declspec(dllexport) void *BH_MALLOC(unsigned int size);
__declspec(dllexport) void BH_FREE(void *ptr);
#else
__declspec(dllimport) void *BH_MALLOC(unsigned int size);
__declspec(dllimport) void BH_FREE(void *ptr);
#endif
#else
void *
BH_MALLOC(unsigned int size);
void
BH_FREE(void *ptr);
#endif

#if defined(BH_VPRINTF)
#if defined(MSVC)
__declspec(dllimport) int BH_VPRINTF(const char *format, va_list ap);
#else
int
BH_VPRINTF(const char *format, va_list ap);
#endif
#endif

#ifndef NULL
#define NULL (void *)0
#endif

#if !defined(BH_HAS_DLFCN)
#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE)
#define BH_HAS_DLFCN 1
#else
#define BH_HAS_DLFCN 0
#endif
#endif

#ifndef __cplusplus

#ifndef true
#define true 1
#endif

#ifndef false
#define false 0
#endif

#ifndef inline
#define inline __inline
#endif

#endif

/* Return the offset of the given field in the given type */
#ifndef offsetof
/* GCC 4.0 and later has the builtin. */
#if defined(__GNUC__) && __GNUC__ >= 4
#define offsetof(Type, field) __builtin_offsetof(Type, field)
#else
#define offsetof(Type, field) ((size_t)(&((Type *)0)->field))
#endif
#endif

typedef uint8_t uint8;
typedef int8_t int8;
typedef uint16_t uint16;
typedef int16_t int16;
typedef uint32_t uint32;
typedef int32_t int32;
typedef float float32;
typedef double float64;
typedef uint64_t uint64;
typedef int64_t int64;

typedef void *(*thread_start_routine_t)(void *);

#ifndef bh_socket_t
/* If no socket defined on current platform,
    give a fake definition to make the compiler happy */
#define bh_socket_t int
#endif

/* Format specifiers macros in case
    they are not provided by compiler */
#ifndef __PRI64_PREFIX
#if UINTPTR_MAX == UINT64_MAX
#define __PRI64_PREFIX "l"
#define __PRIPTR_PREFIX "l"
#else
#define __PRI64_PREFIX "ll"
#define __PRIPTR_PREFIX
#endif
#endif /* #ifndef __PRI64_PREFIX */

/* Macros for printing format specifiers */
#ifndef PRId32
#define PRId32 "d"
#endif
#ifndef PRIi32
#define PRIi32 "i"
#endif
#ifndef PRIu32
#define PRIu32 "u"
#endif
#ifndef PRIx32
#define PRIx32 "x"
#endif
#ifndef PRIX32
#define PRIX32 "X"
#endif

#ifndef PRId64
#define PRId64 __PRI64_PREFIX "d"
#endif
#ifndef PRIu64
#define PRIu64 __PRI64_PREFIX "u"
#endif
#ifndef PRIx64
#define PRIx64 __PRI64_PREFIX "x"
#endif
#ifndef PRIX64
#define PRIX64 __PRI64_PREFIX "X"
#endif
#ifndef PRIxPTR
#define PRIxPTR __PRIPTR_PREFIX "x"
#endif
#ifndef PRIXPTR
#define PRIXPTR __PRIPTR_PREFIX "X"
#endif

/* Macros for scanning format specifiers */
#ifndef SCNd32
#define SCNd32 "d"
#endif
#ifndef SCNi32
#define SCNi32 "i"
#endif
#ifndef SCNu32
#define SCNu32 "u"
#endif
#ifndef SCNx32
#define SCNx32 "x"
#endif

#ifndef SCNd64
#define SCNd64 __PRI64_PREFIX "d"
#endif
#ifndef SCNu64
#define SCNu64 __PRI64_PREFIX "u"
#endif
#ifndef SCNx64
#define SCNx64 __PRI64_PREFIX "x"
#endif
#ifndef SCNxPTR
#define SCNxPTR __PRIPTR_PREFIX "x"
#endif

#ifndef NAN
#define NAN (0.0 / 0.0)
#endif

#ifdef __cplusplus
}
#endif

#endif /* #ifndef _PLATFORM_COMMON_H */
