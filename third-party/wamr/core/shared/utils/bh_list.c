/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_list.h"

#if BH_DEBUG != 0
/**
 * Test whether a pointer value has exist in given list.
 *
 * @param list    pointer to list.
 * @param elem    pointer to elem that will be inserted into list.
 * @return        <code>true</code> if the pointer has been in the list;
 *                <code>false</code> otherwise.
 */
static bool
bh_list_is_elem_exist(bh_list *list, void *elem);
#endif

bh_list_status
bh_list_init(bh_list *list)
{
    if (!list)
        return BH_LIST_ERROR;

    (list->head).next = NULL;
    list->len = 0;
    return BH_LIST_SUCCESS;
}

bh_list_status
bh_list_insert(bh_list *list, void *elem)
{
    bh_list_link *p = NULL;

    if (!list || !elem)
        return BH_LIST_ERROR;
#if BH_DEBUG != 0
    bh_assert(!bh_list_is_elem_exist(list, elem));
#endif
    p = (bh_list_link *)elem;
    p->next = (list->head).next;
    (list->head).next = p;
    list->len++;
    return BH_LIST_SUCCESS;
}

bh_list_status
bh_list_remove(bh_list *list, void *elem)
{
    bh_list_link *cur = NULL;
    bh_list_link *prev = NULL;

    if (!list || !elem)
        return BH_LIST_ERROR;

    cur = (list->head).next;

    while (cur) {
        if (cur == elem) {
            if (prev)
                prev->next = cur->next;
            else
                (list->head).next = cur->next;

            list->len--;
            return BH_LIST_SUCCESS;
        }

        prev = cur;
        cur = cur->next;
    }

    return BH_LIST_ERROR;
}

uint32
bh_list_length(bh_list *list)
{
    return (list ? list->len : 0);
}

void *
bh_list_first_elem(bh_list *list)
{
    return (list ? (list->head).next : NULL);
}

void *
bh_list_elem_next(void *node)
{
    return (node ? ((bh_list_link *)node)->next : NULL);
}

#if BH_DEBUG != 0
static bool
bh_list_is_elem_exist(bh_list *list, void *elem)
{
    bh_list_link *p = NULL;

    if (!list || !elem)
        return false;

    p = (list->head).next;
    while (p && p != elem)
        p = p->next;

    return (p != NULL);
}
#endif
