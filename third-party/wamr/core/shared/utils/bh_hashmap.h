/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef WASM_HASHMAP_H
#define WASM_HASHMAP_H

#include "bh_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Minimum initial size of hash map */
#define HASH_MAP_MIN_SIZE 4

/* Maximum initial size of hash map */
#define HASH_MAP_MAX_SIZE 65536

struct HashMap;
typedef struct HashMap HashMap;

/* Hash function: to get the hash value of key. */
typedef uint32 (*HashFunc)(const void *key);

/* Key equal function: to check whether two keys are equal. */
typedef bool (*KeyEqualFunc)(void *key1, void *key2);

/* Key destroy function: to destroy the key, auto called
   for each key when the hash map is destroyed. */
typedef void (*KeyDestroyFunc)(void *key);

/* Value destroy function: to destroy the value, auto called
   for each value when the hash map is destroyed. */
typedef void (*ValueDestroyFunc)(void *value);

/* traverse callback function:
   auto called when traverse every hash element */
typedef void (*TraverseCallbackFunc)(void *key, void *value, void *user_data);

/**
 * Create a hash map.
 *
 * @param size: the initial size of the hash map
 * @param use_lock whether to lock the hash map when operating on it
 * @param hash_func hash function of the key, must be specified
 * @param key_equal_func key equal function, check whether two keys
 *                       are equal, must be specified
 * @param key_destroy_func key destroy function, called for each key if not NULL
 *                         when the hash map is destroyed
 * @param value_destroy_func value destroy function, called for each value if
 *                           not NULL when the hash map is destroyed
 *
 * @return the hash map created, NULL if failed
 */
HashMap *
bh_hash_map_create(uint32 size, bool use_lock, HashFunc hash_func,
                   KeyEqualFunc key_equal_func, KeyDestroyFunc key_destroy_func,
                   ValueDestroyFunc value_destroy_func);

/**
 * Insert an element to the hash map
 *
 * @param map the hash map to insert element
 * @key the key of the element
 * @value the value of the element
 *
 * @return true if success, false otherwise
 * Note: fail if key is NULL or duplicated key exists in the hash map,
 */
bool
bh_hash_map_insert(HashMap *map, void *key, void *value);

/**
 * Find an element in the hash map
 *
 * @param map the hash map to find element
 * @key the key of the element
 *
 * @return the value of the found element if success, NULL otherwise
 */
void *
bh_hash_map_find(HashMap *map, void *key);

/**
 * Update an element in the hash map with new value
 *
 * @param map the hash map to update element
 * @key the key of the element
 * @value the new value of the element
 * @p_old_value if not NULL, copies the old value to it
 *
 * @return true if success, false otherwise
 * Note: the old value won't be destroyed by value destroy function,
 *       it will be copied to p_old_value for user to process.
 */
bool
bh_hash_map_update(HashMap *map, void *key, void *value, void **p_old_value);

/**
 * Remove an element from the hash map
 *
 * @param map the hash map to remove element
 * @key the key of the element
 * @p_old_key if not NULL, copies the old key to it
 * @p_old_value if not NULL, copies the old value to it
 *
 * @return true if success, false otherwise
 * Note: the old key and old value won't be destroyed by key destroy
 *       function and value destroy function, they will be copied to
 *       p_old_key and p_old_value for user to process.
 */
bool
bh_hash_map_remove(HashMap *map, void *key, void **p_old_key,
                   void **p_old_value);

/**
 * Destroy the hashmap
 *
 * @param map the hash map to destroy
 *
 * @return true if success, false otherwise
 * Note: the key destroy function and value destroy function will be
 *       called to destroy each element's key and value if they are
 *       not NULL.
 */
bool
bh_hash_map_destroy(HashMap *map);

/**
 * Get the structure size of HashMap
 *
 * @param map the hash map to calculate
 *
 * @return the memory space occupied by HashMap structure
 */
uint32
bh_hash_map_get_struct_size(HashMap *hashmap);

/**
 * Get the structure size of HashMap Element
 *
 * @return the memory space occupied by HashMapElem structure
 */
uint32
bh_hash_map_get_elem_struct_size(void);

/**
 * Traverse the hash map and call the callback function
 *
 * @param map the hash map to traverse
 * @param callback the function to be called for every element
 * @param user_data the argument to be passed to the callback function
 *
 * @return true if success, false otherwise
 * Note: if the hash map has lock, the map will be locked during traverse,
 *       keep the callback function as simple as possible.
 */
bool
bh_hash_map_traverse(HashMap *map, TraverseCallbackFunc callback,
                     void *user_data);

#ifdef __cplusplus
}
#endif

#endif /* endof WASM_HASHMAP_H */
