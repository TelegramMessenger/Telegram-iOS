/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_BITMAP_H
#define _BH_BITMAP_H

#include "bh_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * A simple fixed size bitmap.
 */
typedef struct bh_bitmap {
    /* The first valid bit index.  */
    uintptr_t begin_index;

    /* The last valid bit index plus one.  */
    uintptr_t end_index;

    /* The bitmap.  */
    uint8 map[1];
} bh_bitmap;

/**
 * Create a new bitmap.
 *
 * @param begin_index the first valid bit index
 * @param bitnum maximal bit number of the bitmap.
 *
 * @return the new bitmap if succeeds, NULL otherwise.
 */
bh_bitmap *
bh_bitmap_new(uintptr_t begin_index, unsigned bitnum);

/**
 * Delete a bitmap.
 *
 * @param bitmap the bitmap to be deleted
 */
static inline void
bh_bitmap_delete(bh_bitmap *bitmap)
{
    if (bitmap != NULL)
        BH_FREE(bitmap);
}

/**
 * Check whether the given index is in the range of the bitmap.
 *
 * @param bitmap the bitmap
 * @param n the bit index
 *
 * @return true if the index is in range, false otherwise
 */
static inline bool
bh_bitmap_is_in_range(bh_bitmap *bitmap, uintptr_t n)
{
    return n >= bitmap->begin_index && n < bitmap->end_index;
}

/**
 * Get a bit in the bitmap
 *
 * @param bitmap the bitmap
 * @param n the n-th bit to be get
 *
 * @return value of the bit
 */
static inline int
bh_bitmap_get_bit(bh_bitmap *bitmap, uintptr_t n)
{
    uintptr_t idx = n - bitmap->begin_index;
    bh_assert(n >= bitmap->begin_index && n < bitmap->end_index);
    return (bitmap->map[idx / 8] >> (idx % 8)) & 1;
}

/**
 * Set a bit in the bitmap.
 *
 * @param bitmap the bitmap
 * @param n the n-th bit to be set
 */
static inline void
bh_bitmap_set_bit(bh_bitmap *bitmap, uintptr_t n)
{
    uintptr_t idx = n - bitmap->begin_index;
    bh_assert(n >= bitmap->begin_index && n < bitmap->end_index);
    bitmap->map[idx / 8] |= 1 << (idx % 8);
}

/**
 * Clear a bit in the bitmap.
 *
 * @param bitmap the bitmap
 * @param n the n-th bit to be cleared
 */
static inline void
bh_bitmap_clear_bit(bh_bitmap *bitmap, uintptr_t n)
{
    uintptr_t idx = n - bitmap->begin_index;
    bh_assert(n >= bitmap->begin_index && n < bitmap->end_index);
    bitmap->map[idx / 8] &= ~(1 << (idx % 8));
}

#ifdef __cplusplus
}
#endif

#endif
