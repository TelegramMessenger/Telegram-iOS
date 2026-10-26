/*
 * Copyright (C) 2023 Amazon.com, Inc. or its affiliates. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#if !defined(__GNUC_PREREQ) && (defined(__GNUC__) || defined(__GNUG__)) \
    && !defined(__clang__) && defined(__GNUC_MINOR__)
/* Depending on the platform the macro is defined in sys/features.h or
   features.h Given the macro is simple, we re-implement it here instead of
   dealing with two different paths.
 */
#define __GNUC_PREREQ(maj, min) \
    ((__GNUC__ << 16) + __GNUC_MINOR__ >= ((maj) << 16) + (min))
#endif
