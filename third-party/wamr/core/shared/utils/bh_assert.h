/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_ASSERT_H
#define _BH_ASSERT_H

#include "bh_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

#if BH_DEBUG != 0
void
bh_assert_internal(int64 v, const char *file_name, int line_number,
                   const char *expr_string);
#define bh_assert(expr) \
    bh_assert_internal((int64)(uintptr_t)(expr), __FILE__, __LINE__, #expr)
#else
#define bh_assert(expr) (void)0
#endif /* end of BH_DEBUG */

#if !defined(__has_extension)
#define __has_extension(a) 0
#endif

#if (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L)           \
    || (defined(__GNUC__) && __GNUC__ * 0x100 + __GNUC_MINOR__ >= 0x406) \
    || __has_extension(c_static_assert)

#define bh_static_assert(expr) _Static_assert(expr, #expr)
#else
#define bh_static_assert(expr) /* nothing */
#endif

#ifdef __cplusplus
}
#endif

#endif /* end of _BH_ASSERT_H */
