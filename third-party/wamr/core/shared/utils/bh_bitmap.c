/*
 * Copyright (C) 2021 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_bitmap.h"

bh_bitmap *
bh_bitmap_new(uintptr_t begin_index, unsigned bitnum)
{
    bh_bitmap *bitmap;
    uint32 bitmap_size = (bitnum + 7) / 8;
    uint32 total_size = offsetof(bh_bitmap, map) + bitmap_size;

    if (bitnum > UINT32_MAX - 7 || total_size < offsetof(bh_bitmap, map)
        || (total_size - offsetof(bh_bitmap, map)) != bitmap_size) {
        return NULL; /* integer overflow */
    }

    if ((bitmap = BH_MALLOC(total_size)) != NULL) {
        memset(bitmap, 0, total_size);
        bitmap->begin_index = begin_index;
        bitmap->end_index = begin_index + bitnum;
    }

    return bitmap;
}
