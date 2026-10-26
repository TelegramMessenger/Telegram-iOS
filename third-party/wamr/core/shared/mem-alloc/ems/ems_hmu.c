/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "ems_gc_internal.h"

#if BH_ENABLE_GC_VERIFY != 0

/**
 * Set default value to prefix and suffix
 * @param hmu should not be NULL and should have been correctly initialized
 *        (except prefix and suffix part)
 * @param tot_size is offered here because hmu_get_size can not be used
 *        till now. tot_size should not be smaller than OBJ_EXTRA_SIZE.
 *        For VO, tot_size should be equal to object total size.
 */
void
hmu_init_prefix_and_suffix(hmu_t *hmu, gc_size_t tot_size,
                           const char *file_name, int line_no)
{
    gc_object_prefix_t *prefix = NULL;
    gc_object_suffix_t *suffix = NULL;
    gc_uint32 i = 0;

    bh_assert(hmu);
    bh_assert(hmu_get_ut(hmu) == HMU_WO || hmu_get_ut(hmu) == HMU_VO);
    bh_assert(tot_size >= OBJ_EXTRA_SIZE);
    bh_assert(!(tot_size & 7));
    bh_assert(hmu_get_ut(hmu) != HMU_VO || hmu_get_size(hmu) >= tot_size);

    prefix = (gc_object_prefix_t *)(hmu + 1);
    suffix =
        (gc_object_suffix_t *)((gc_uint8 *)hmu + tot_size - OBJ_SUFFIX_SIZE);
    prefix->file_name = file_name;
    prefix->line_no = line_no;
    prefix->size = tot_size;

    for (i = 0; i < GC_OBJECT_PREFIX_PADDING_CNT; i++) {
        prefix->padding[i] = GC_OBJECT_PADDING_VALUE;
    }

    for (i = 0; i < GC_OBJECT_SUFFIX_PADDING_CNT; i++) {
        suffix->padding[i] = GC_OBJECT_PADDING_VALUE;
    }
}

void
hmu_verify(void *vheap, hmu_t *hmu)
{
#if BH_ENABLE_GC_CORRUPTION_CHECK != 0
    gc_heap_t *heap = (gc_heap_t *)vheap;
#endif
    gc_object_prefix_t *prefix = NULL;
    gc_object_suffix_t *suffix = NULL;
    gc_uint32 i = 0;
    hmu_type_t ut;
    gc_size_t size = 0;
    int is_padding_ok = 1;

    bh_assert(hmu);
    ut = hmu_get_ut(hmu);
    bh_assert(hmu_is_ut_valid(ut));

    prefix = (gc_object_prefix_t *)(hmu + 1);
    size = prefix->size;
    suffix = (gc_object_suffix_t *)((gc_uint8 *)hmu + size - OBJ_SUFFIX_SIZE);

    if (ut == HMU_VO || ut == HMU_WO) {
        /* check padding*/
        for (i = 0; i < GC_OBJECT_PREFIX_PADDING_CNT; i++) {
            if (prefix->padding[i] != GC_OBJECT_PADDING_VALUE) {
                is_padding_ok = 0;
                break;
            }
        }
        for (i = 0; i < GC_OBJECT_SUFFIX_PADDING_CNT; i++) {
            if (suffix->padding[i] != GC_OBJECT_PADDING_VALUE) {
                is_padding_ok = 0;
                break;
            }
        }

        if (!is_padding_ok) {
            LOG_ERROR("Invalid padding for object created at %s:%d\n",
                      (prefix->file_name ? prefix->file_name : ""),
                      prefix->line_no);
#if BH_ENABLE_GC_CORRUPTION_CHECK != 0
            heap->is_heap_corrupted = true;
#endif
        }
    }
}

#endif /* end of BH_ENABLE_GC_VERIFY */
