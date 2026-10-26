/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_VECTOR_H
#define _WASM_VECTOR_H

#include "bh_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

#define DEFAULT_VECTOR_INIT_SIZE 8

typedef struct Vector {
    /* max element number */
    size_t max_elems;
    /* vector data allocated */
    uint8 *data;
    /* current element num */
    size_t num_elems;
    /* size of each element */
    size_t size_elem;
    void *lock;
} Vector;

/**
 * Initialize vector
 *
 * @param vector the vector to init
 * @param init_length the initial length of the vector
 * @param size_elem size of each element
 *
 * @return true if success, false otherwise
 */
bool
bh_vector_init(Vector *vector, size_t init_length, size_t size_elem,
               bool use_lock);

/**
 * Set element of vector
 *
 * @param vector the vector to set
 * @param index the index of the element to set
 * @param elem_buf the element buffer which stores the element data
 *
 * @return true if success, false otherwise
 */
bool
bh_vector_set(Vector *vector, uint32 index, const void *elem_buf);

/**
 * Get element of vector
 *
 * @param vector the vector to get
 * @param index the index of the element to get
 * @param elem_buf the element buffer to store the element data,
 *                 whose length must be no less than element size
 *
 * @return true if success, false otherwise
 */
bool
bh_vector_get(Vector *vector, uint32 index, void *elem_buf);

/**
 * Insert element of vector
 *
 * @param vector the vector to insert
 * @param index the index of the element to insert
 * @param elem_buf the element buffer which stores the element data
 *
 * @return true if success, false otherwise
 */
bool
bh_vector_insert(Vector *vector, uint32 index, const void *elem_buf);

/**
 * Append element to the end of vector
 *
 * @param vector the vector to append
 * @param elem_buf the element buffer which stores the element data
 *
 * @return true if success, false otherwise
 */
bool
bh_vector_append(Vector *vector, const void *elem_buf);

/**
 * Remove element from vector
 *
 * @param vector the vector to remove element
 * @param index the index of the element to remove
 * @param old_elem_buf if not NULL, copies the element data to the buffer
 *
 * @return true if success, false otherwise
 */
bool
bh_vector_remove(Vector *vector, uint32 index, void *old_elem_buf);

/**
 * Return the size of the vector
 *
 * @param vector the vector to get size
 *
 * @return return the size of the vector
 */
size_t
bh_vector_size(const Vector *vector);

/**
 * Destroy the vector
 *
 * @param vector the vector to destroy
 *
 * @return true if success, false otherwise
 */
bool
bh_vector_destroy(Vector *vector);

#ifdef __cplusplus
}
#endif

#endif /* endof _WASM_VECTOR_H */
