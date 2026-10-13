/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_vector.h"

static uint8 *
alloc_vector_data(size_t length, size_t size_elem)
{
    uint64 total_size = ((uint64)size_elem) * length;
    uint8 *data;

    if (length > UINT32_MAX || size_elem > UINT32_MAX
        || total_size > UINT32_MAX) {
        return NULL;
    }

    if ((data = BH_MALLOC((uint32)total_size))) {
        memset(data, 0, (uint32)total_size);
    }

    return data;
}

/**
 * every caller of `extend_vector` must provide
 * a thread-safe environment.
 */
static bool
extend_vector(Vector *vector, size_t length)
{
    uint8 *data;

    if (length <= vector->max_elems)
        return true;

    if (length < vector->max_elems * 3 / 2)
        length = vector->max_elems * 3 / 2;

    if (!(data = alloc_vector_data(length, vector->size_elem))) {
        return false;
    }

    bh_memcpy_s(data, (uint32)(vector->size_elem * length), vector->data,
                (uint32)(vector->size_elem * vector->max_elems));
    BH_FREE(vector->data);

    vector->data = data;
    vector->max_elems = length;
    return true;
}

bool
bh_vector_init(Vector *vector, size_t init_length, size_t size_elem,
               bool use_lock)
{
    if (!vector) {
        LOG_ERROR("Init vector failed: vector is NULL.\n");
        return false;
    }

    if (init_length == 0) {
        init_length = 4;
    }

    if (!(vector->data = alloc_vector_data(init_length, size_elem))) {
        LOG_ERROR("Init vector failed: alloc memory failed.\n");
        return false;
    }

    vector->size_elem = size_elem;
    vector->max_elems = init_length;
    vector->num_elems = 0;
    vector->lock = NULL;

    if (use_lock) {
        if (!(vector->lock = BH_MALLOC(sizeof(korp_mutex)))) {
            LOG_ERROR("Init vector failed: alloc locker failed.\n");
            bh_vector_destroy(vector);
            return false;
        }

        if (BHT_OK != os_mutex_init(vector->lock)) {
            LOG_ERROR("Init vector failed: init locker failed.\n");

            BH_FREE(vector->lock);
            vector->lock = NULL;

            bh_vector_destroy(vector);
            return false;
        }
    }

    return true;
}

bool
bh_vector_set(Vector *vector, uint32 index, const void *elem_buf)
{
    if (!vector || !elem_buf) {
        LOG_ERROR("Set vector elem failed: vector or elem buf is NULL.\n");
        return false;
    }

    if (index >= vector->num_elems) {
        LOG_ERROR("Set vector elem failed: invalid elem index.\n");
        return false;
    }

    if (vector->lock)
        os_mutex_lock(vector->lock);
    bh_memcpy_s(vector->data + vector->size_elem * index,
                (uint32)vector->size_elem, elem_buf, (uint32)vector->size_elem);
    if (vector->lock)
        os_mutex_unlock(vector->lock);
    return true;
}

bool
bh_vector_get(Vector *vector, uint32 index, void *elem_buf)
{
    if (!vector || !elem_buf) {
        LOG_ERROR("Get vector elem failed: vector or elem buf is NULL.\n");
        return false;
    }

    if (index >= vector->num_elems) {
        LOG_ERROR("Get vector elem failed: invalid elem index.\n");
        return false;
    }

    if (vector->lock)
        os_mutex_lock(vector->lock);
    bh_memcpy_s(elem_buf, (uint32)vector->size_elem,
                vector->data + vector->size_elem * index,
                (uint32)vector->size_elem);
    if (vector->lock)
        os_mutex_unlock(vector->lock);
    return true;
}

bool
bh_vector_insert(Vector *vector, uint32 index, const void *elem_buf)
{
    size_t i;
    uint8 *p;
    bool ret = false;

    if (!vector || !elem_buf) {
        LOG_ERROR("Insert vector elem failed: vector or elem buf is NULL.\n");
        goto just_return;
    }

    if (index >= vector->num_elems) {
        LOG_ERROR("Insert vector elem failed: invalid elem index.\n");
        goto just_return;
    }

    if (vector->lock)
        os_mutex_lock(vector->lock);

    if (!extend_vector(vector, vector->num_elems + 1)) {
        LOG_ERROR("Insert vector elem failed: extend vector failed.\n");
        goto unlock_return;
    }

    p = vector->data + vector->size_elem * vector->num_elems;
    for (i = vector->num_elems - 1; i > index; i--) {
        bh_memcpy_s(p, (uint32)vector->size_elem, p - vector->size_elem,
                    (uint32)vector->size_elem);
        p -= vector->size_elem;
    }

    bh_memcpy_s(p, (uint32)vector->size_elem, elem_buf,
                (uint32)vector->size_elem);
    vector->num_elems++;
    ret = true;

unlock_return:
    if (vector->lock)
        os_mutex_unlock(vector->lock);
just_return:
    return ret;
}

bool
bh_vector_append(Vector *vector, const void *elem_buf)
{
    bool ret = false;

    if (!vector || !elem_buf) {
        LOG_ERROR("Append vector elem failed: vector or elem buf is NULL.\n");
        goto just_return;
    }

    /* make sure one more slot is used by the thread who allocates it */
    if (vector->lock)
        os_mutex_lock(vector->lock);

    if (!extend_vector(vector, vector->num_elems + 1)) {
        LOG_ERROR("Append vector elem failed: extend vector failed.\n");
        goto unlock_return;
    }

    bh_memcpy_s(vector->data + vector->size_elem * vector->num_elems,
                (uint32)vector->size_elem, elem_buf, (uint32)vector->size_elem);
    vector->num_elems++;
    ret = true;

unlock_return:
    if (vector->lock)
        os_mutex_unlock(vector->lock);
just_return:
    return ret;
}

bool
bh_vector_remove(Vector *vector, uint32 index, void *old_elem_buf)
{
    uint32 i;
    uint8 *p;

    if (!vector) {
        LOG_ERROR("Remove vector elem failed: vector is NULL.\n");
        return false;
    }

    if (index >= vector->num_elems) {
        LOG_ERROR("Remove vector elem failed: invalid elem index.\n");
        return false;
    }

    if (vector->lock)
        os_mutex_lock(vector->lock);
    p = vector->data + vector->size_elem * index;

    if (old_elem_buf) {
        bh_memcpy_s(old_elem_buf, (uint32)vector->size_elem, p,
                    (uint32)vector->size_elem);
    }

    for (i = index; i < vector->num_elems - 1; i++) {
        bh_memcpy_s(p, (uint32)vector->size_elem, p + vector->size_elem,
                    (uint32)vector->size_elem);
        p += vector->size_elem;
    }

    vector->num_elems--;
    if (vector->lock)
        os_mutex_unlock(vector->lock);
    return true;
}

size_t
bh_vector_size(const Vector *vector)
{
    return vector ? vector->num_elems : 0;
}

bool
bh_vector_destroy(Vector *vector)
{
    if (!vector) {
        LOG_ERROR("Destroy vector elem failed: vector is NULL.\n");
        return false;
    }

    if (vector->data)
        BH_FREE(vector->data);

    if (vector->lock) {
        os_mutex_destroy(vector->lock);
        BH_FREE(vector->lock);
    }

    memset(vector, 0, sizeof(Vector));
    return true;
}
