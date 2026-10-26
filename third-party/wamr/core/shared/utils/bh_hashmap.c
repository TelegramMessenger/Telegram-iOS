/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_hashmap.h"

typedef struct HashMapElem {
    void *key;
    void *value;
    struct HashMapElem *next;
} HashMapElem;

struct HashMap {
    /* size of element array */
    uint32 size;
    /* lock for elements */
    korp_mutex *lock;
    /* hash function of key */
    HashFunc hash_func;
    /* key equal function */
    KeyEqualFunc key_equal_func;
    KeyDestroyFunc key_destroy_func;
    ValueDestroyFunc value_destroy_func;
    HashMapElem *elements[1];
};

HashMap *
bh_hash_map_create(uint32 size, bool use_lock, HashFunc hash_func,
                   KeyEqualFunc key_equal_func, KeyDestroyFunc key_destroy_func,
                   ValueDestroyFunc value_destroy_func)
{
    HashMap *map;
    uint64 total_size;

    if (size < HASH_MAP_MIN_SIZE)
        size = HASH_MAP_MIN_SIZE;

    if (size > HASH_MAP_MAX_SIZE) {
        LOG_ERROR("HashMap create failed: size is too large.\n");
        return NULL;
    }

    if (!hash_func || !key_equal_func) {
        LOG_ERROR("HashMap create failed: hash function or key equal function "
                  " is NULL.\n");
        return NULL;
    }

    total_size = offsetof(HashMap, elements)
                 + sizeof(HashMapElem *) * (uint64)size
                 + (use_lock ? sizeof(korp_mutex) : 0);

    /* size <= HASH_MAP_MAX_SIZE, so total_size won't be larger than
       UINT32_MAX, no need to check integer overflow */
    if (!(map = BH_MALLOC((uint32)total_size))) {
        LOG_ERROR("HashMap create failed: alloc memory failed.\n");
        return NULL;
    }

    memset(map, 0, (uint32)total_size);

    if (use_lock) {
        map->lock = (korp_mutex *)((uint8 *)map + offsetof(HashMap, elements)
                                   + sizeof(HashMapElem *) * size);
        if (os_mutex_init(map->lock)) {
            LOG_ERROR("HashMap create failed: init map lock failed.\n");
            BH_FREE(map);
            return NULL;
        }
    }

    map->size = size;
    map->hash_func = hash_func;
    map->key_equal_func = key_equal_func;
    map->key_destroy_func = key_destroy_func;
    map->value_destroy_func = value_destroy_func;
    return map;
}

bool
bh_hash_map_insert(HashMap *map, void *key, void *value)
{
    uint32 index;
    HashMapElem *elem;

    if (!map || !key) {
        LOG_ERROR("HashMap insert elem failed: map or key is NULL.\n");
        return false;
    }

    if (map->lock) {
        os_mutex_lock(map->lock);
    }

    index = map->hash_func(key) % map->size;
    elem = map->elements[index];
    while (elem) {
        if (map->key_equal_func(elem->key, key)) {
            LOG_ERROR("HashMap insert elem failed: duplicated key found.\n");
            goto fail;
        }
        elem = elem->next;
    }

    if (!(elem = BH_MALLOC(sizeof(HashMapElem)))) {
        LOG_ERROR("HashMap insert elem failed: alloc memory failed.\n");
        goto fail;
    }

    elem->key = key;
    elem->value = value;
    elem->next = map->elements[index];
    map->elements[index] = elem;

    if (map->lock) {
        os_mutex_unlock(map->lock);
    }
    return true;

fail:
    if (map->lock) {
        os_mutex_unlock(map->lock);
    }
    return false;
}

void *
bh_hash_map_find(HashMap *map, void *key)
{
    uint32 index;
    HashMapElem *elem;
    void *value;

    if (!map || !key) {
        LOG_ERROR("HashMap find elem failed: map or key is NULL.\n");
        return NULL;
    }

    if (map->lock) {
        os_mutex_lock(map->lock);
    }

    index = map->hash_func(key) % map->size;
    elem = map->elements[index];

    while (elem) {
        if (map->key_equal_func(elem->key, key)) {
            value = elem->value;
            if (map->lock) {
                os_mutex_unlock(map->lock);
            }
            return value;
        }
        elem = elem->next;
    }

    if (map->lock) {
        os_mutex_unlock(map->lock);
    }
    return NULL;
}

bool
bh_hash_map_update(HashMap *map, void *key, void *value, void **p_old_value)
{
    uint32 index;
    HashMapElem *elem;

    if (!map || !key) {
        LOG_ERROR("HashMap update elem failed: map or key is NULL.\n");
        return false;
    }

    if (map->lock) {
        os_mutex_lock(map->lock);
    }

    index = map->hash_func(key) % map->size;
    elem = map->elements[index];

    while (elem) {
        if (map->key_equal_func(elem->key, key)) {
            if (p_old_value)
                *p_old_value = elem->value;
            elem->value = value;
            if (map->lock) {
                os_mutex_unlock(map->lock);
            }
            return true;
        }
        elem = elem->next;
    }

    if (map->lock) {
        os_mutex_unlock(map->lock);
    }
    return false;
}

bool
bh_hash_map_remove(HashMap *map, void *key, void **p_old_key,
                   void **p_old_value)
{
    uint32 index;
    HashMapElem *elem, *prev;

    if (!map || !key) {
        LOG_ERROR("HashMap remove elem failed: map or key is NULL.\n");
        return false;
    }

    if (map->lock) {
        os_mutex_lock(map->lock);
    }

    index = map->hash_func(key) % map->size;
    prev = elem = map->elements[index];

    while (elem) {
        if (map->key_equal_func(elem->key, key)) {
            if (p_old_key)
                *p_old_key = elem->key;
            if (p_old_value)
                *p_old_value = elem->value;

            if (elem == map->elements[index])
                map->elements[index] = elem->next;
            else
                prev->next = elem->next;

            BH_FREE(elem);

            if (map->lock) {
                os_mutex_unlock(map->lock);
            }
            return true;
        }

        prev = elem;
        elem = elem->next;
    }

    if (map->lock) {
        os_mutex_unlock(map->lock);
    }
    return false;
}

bool
bh_hash_map_destroy(HashMap *map)
{
    uint32 index;
    HashMapElem *elem, *next;

    if (!map) {
        LOG_ERROR("HashMap destroy failed: map is NULL.\n");
        return false;
    }

    if (map->lock) {
        os_mutex_lock(map->lock);
    }

    for (index = 0; index < map->size; index++) {
        elem = map->elements[index];
        while (elem) {
            next = elem->next;

            if (map->key_destroy_func) {
                map->key_destroy_func(elem->key);
            }
            if (map->value_destroy_func) {
                map->value_destroy_func(elem->value);
            }
            BH_FREE(elem);

            elem = next;
        }
    }

    if (map->lock) {
        os_mutex_unlock(map->lock);
        os_mutex_destroy(map->lock);
    }
    BH_FREE(map);
    return true;
}

uint32
bh_hash_map_get_struct_size(HashMap *hashmap)
{
    uint32 size = (uint32)(uintptr_t)offsetof(HashMap, elements)
                  + (uint32)sizeof(HashMapElem *) * hashmap->size;

    if (hashmap->lock) {
        size += (uint32)sizeof(korp_mutex);
    }

    return size;
}

uint32
bh_hash_map_get_elem_struct_size()
{
    return (uint32)sizeof(HashMapElem);
}

bool
bh_hash_map_traverse(HashMap *map, TraverseCallbackFunc callback,
                     void *user_data)
{
    uint32 index;
    HashMapElem *elem, *next;

    if (!map || !callback) {
        LOG_ERROR("HashMap traverse failed: map or callback is NULL.\n");
        return false;
    }

    if (map->lock) {
        os_mutex_lock(map->lock);
    }

    for (index = 0; index < map->size; index++) {
        elem = map->elements[index];
        while (elem) {
            next = elem->next;
            callback(elem->key, elem->value, user_data);
            elem = next;
        }
    }

    if (map->lock) {
        os_mutex_unlock(map->lock);
    }

    return true;
}
