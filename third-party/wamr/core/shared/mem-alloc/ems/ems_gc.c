/*
 * Copyright (C) 2022 Tencent Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "ems_gc.h"
#include "ems_gc_internal.h"

#define GB (1 << 30UL)

#define MARK_NODE_OBJ_CNT 256

#if WASM_ENABLE_GC != 0

/* mark node is used for gc marker*/
typedef struct mark_node_struct {
    /* number of to-expand objects can be saved in this node */
    gc_size_t cnt;

    /* the first unused index */
    uint32 idx;

    /* next node on the node list */
    struct mark_node_struct *next;

    /* the actual to-expand objects list */
    gc_object_t set[MARK_NODE_OBJ_CNT];
} mark_node_t;

/**
 * Alloc a mark node from the native heap
 *
 * @return a valid mark node if success, NULL otherwise
 */
static mark_node_t *
alloc_mark_node(void)
{
    mark_node_t *ret = (mark_node_t *)BH_MALLOC(sizeof(mark_node_t));

    if (!ret) {
        LOG_ERROR("alloc a new mark node failed");
        return NULL;
    }
    ret->cnt = sizeof(ret->set) / sizeof(ret->set[0]);
    ret->idx = 0;
    ret->next = NULL;
    return ret;
}

/* Free a mark node to the native heap
 *
 * @param node the mark node to free, should not be NULL
 */
static void
free_mark_node(mark_node_t *node)
{
    bh_assert(node);
    BH_FREE((gc_object_t)node);
}

/**
 * Sweep phase of mark_sweep algorithm
 * @param heap the heap to sweep, should be a valid instance heap
 *        which has already been marked
 */
static void
sweep_instance_heap(gc_heap_t *heap)
{
    hmu_t *cur = NULL, *end = NULL, *last = NULL;
    hmu_type_t ut;
    gc_size_t size;
    int i, lsize;
    gc_size_t tot_free = 0;

    bh_assert(gci_is_heap_valid(heap));

    cur = (hmu_t *)heap->base_addr;
    last = NULL;
    end = (hmu_t *)((char *)heap->base_addr + heap->current_size);

    /* reset KFC */
    lsize =
        (int)(sizeof(heap->kfc_normal_list) / sizeof(heap->kfc_normal_list[0]));
    for (i = 0; i < lsize; i++) {
        heap->kfc_normal_list[i].next = NULL;
    }
    heap->kfc_tree_root->right = NULL;
    heap->root_set = NULL;

    while (cur < end) {
        ut = hmu_get_ut(cur);
        size = hmu_get_size(cur);
        bh_assert(size > 0);

        if (ut == HMU_FC || ut == HMU_FM
            || (ut == HMU_VO && hmu_is_vo_freed(cur))
            || (ut == HMU_WO && !hmu_is_wo_marked(cur))) {
            /* merge previous free areas with current one */
            if (!last)
                last = cur;

            if (ut == HMU_WO) {
                /* Invoke registered finalizer */
                gc_object_t cur_obj = hmu_to_obj(cur);
                if (gct_vm_get_extra_info_flag(cur_obj)) {
                    extra_info_node_t *node = gc_search_extra_info_node(
                        (gc_handle_t)heap, cur_obj, NULL);
                    bh_assert(node);
                    node->finalizer(node->obj, node->data);
                    gc_unset_finalizer((gc_handle_t)heap, cur_obj);
                }
            }
        }
        else {
            /* current block is still live */
            if (last) {
                tot_free += (gc_size_t)((char *)cur - (char *)last);
                gci_add_fc(heap, last, (gc_size_t)((char *)cur - (char *)last));
                hmu_mark_pinuse(last);
                last = NULL;
            }

            if (ut == HMU_WO) {
                /* unmark it */
                hmu_unmark_wo(cur);
            }
        }

        cur = (hmu_t *)((char *)cur + size);
    }

    bh_assert(cur == end);

    if (last) {
        tot_free += (gc_size_t)((char *)cur - (char *)last);
        gci_add_fc(heap, last, (gc_size_t)((char *)cur - (char *)last));
        hmu_mark_pinuse(last);
    }

    heap->total_free_size = tot_free;

#if GC_STAT_DATA != 0
    heap->total_gc_count++;
    if ((heap->current_size - tot_free) > heap->highmark_size)
        heap->highmark_size = heap->current_size - tot_free;

#endif
    gc_update_threshold(heap);
}

/**
 * Add a to-expand node to the to-expand list
 *
 * @param heap should be a valid instance heap
 * @param obj should be a valid wo inside @heap
 *
 * @return GC_ERROR if there is no more resource for marking,
 *         GC_SUCCESS if success
 */
static int
add_wo_to_expand(gc_heap_t *heap, gc_object_t obj)
{
    mark_node_t *mark_node = NULL, *new_node = NULL;
    hmu_t *hmu = NULL;

    bh_assert(obj);

    hmu = obj_to_hmu(obj);

    bh_assert(gci_is_heap_valid(heap));
    bh_assert((gc_uint8 *)hmu >= heap->base_addr
              && (gc_uint8 *)hmu < heap->base_addr + heap->current_size);
    bh_assert(hmu_get_ut(hmu) == HMU_WO);

    if (hmu_is_wo_marked(hmu))
        return GC_SUCCESS; /* already marked*/

    mark_node = (mark_node_t *)heap->root_set;
    if (!mark_node || mark_node->idx == mark_node->cnt) {
        new_node = alloc_mark_node();
        if (!new_node) {
            LOG_ERROR("can not add obj to mark node because of mark node "
                      "allocation failed");
            return GC_ERROR;
        }
        new_node->next = mark_node;
        heap->root_set = new_node;
        mark_node = new_node;
    }

    mark_node->set[mark_node->idx++] = obj;
    hmu_mark_wo(hmu);
    return GC_SUCCESS;
}

/* Check ems_gc.h for description*/
int
gc_add_root(void *heap_p, gc_object_t obj)
{
    gc_heap_t *heap = (gc_heap_t *)heap_p;
    hmu_t *hmu = NULL;

    if (!obj) {
        LOG_ERROR("gc_add_root with NULL obj");
        return GC_ERROR;
    }

    hmu = obj_to_hmu(obj);

    if (!gci_is_heap_valid(heap)) {
        LOG_ERROR("vm_get_gc_handle_for_current_instance returns invalid heap");
        return GC_ERROR;
    }

    if (!((gc_uint8 *)hmu >= heap->base_addr
          && (gc_uint8 *)hmu < heap->base_addr + heap->current_size)) {
        LOG_ERROR("Obj is not a object in current instance heap");
        return GC_ERROR;
    }

    if (hmu_get_ut(hmu) != HMU_WO) {
        LOG_ERROR("Given object is not wo");
        return GC_ERROR;
    }

    if (add_wo_to_expand(heap, obj) != GC_SUCCESS) {
        heap->is_fast_marking_failed = 1;
        return GC_ERROR;
    }

    return GC_SUCCESS;
}

/**
 * Unmark all marked objects to do rollback
 *
 * @param heap the heap to do rollback, should be a valid instance heap
 */
static void
rollback_mark(gc_heap_t *heap)
{
    mark_node_t *mark_node = NULL, *next_mark_node = NULL;
    hmu_t *cur = NULL, *end = NULL;
    hmu_type_t ut;
    gc_size_t size;

    bh_assert(gci_is_heap_valid(heap));

    /* roll back*/
    mark_node = (mark_node_t *)heap->root_set;
    while (mark_node) {
        next_mark_node = mark_node->next;
        free_mark_node(mark_node);
        mark_node = next_mark_node;
    }

    heap->root_set = NULL;

    /* then traverse the heap to unmark all marked wos*/

    cur = (hmu_t *)heap->base_addr;
    end = (hmu_t *)((char *)heap->base_addr + heap->current_size);

    while (cur < end) {
        ut = hmu_get_ut(cur);
        size = hmu_get_size(cur);

        if (ut == HMU_WO && hmu_is_wo_marked(cur)) {
            hmu_unmark_wo(cur);
        }

        cur = (hmu_t *)((char *)cur + size);
    }

    bh_assert(cur == end);
}

/**
 * Reclaim GC instance heap
 *
 * @param heap the heap to reclaim, should be a valid instance heap
 *
 * @return GC_SUCCESS if success, GC_ERROR otherwise
 */
static int
reclaim_instance_heap(gc_heap_t *heap)
{
    mark_node_t *mark_node = NULL;
    int idx = 0, j = 0;
    bool ret, is_compact_mode = false;
    gc_object_t obj = NULL, ref = NULL;
    hmu_t *hmu = NULL;
    gc_uint32 ref_num = 0, ref_start_offset = 0, size = 0, offset = 0;
    gc_uint16 *ref_list = NULL;

    bh_assert(gci_is_heap_valid(heap));

    heap->root_set = NULL;

#if WASM_ENABLE_THREAD_MGR == 0
    if (!heap->exec_env)
        return GC_SUCCESS;
    ret = gct_vm_begin_rootset_enumeration(heap->exec_env, heap);
#else
    if (!heap->cluster)
        return GC_SUCCESS;
    ret = gct_vm_begin_rootset_enumeration(heap->cluster, heap);
#endif
    if (!ret)
        return GC_ERROR;

#if BH_ENABLE_GC_VERIFY != 0
    /* no matter whether the enumeration is successful or not, the data
       collected should be checked at first */
    mark_node = (mark_node_t *)heap->root_set;
    while (mark_node) {
        /* all nodes except first should be full filled */
        bh_assert(mark_node == (mark_node_t *)heap->root_set
                  || mark_node->idx == mark_node->cnt);

        /* all nodes should be non-empty */
        bh_assert(mark_node->idx > 0);

        for (idx = 0; idx < (int)mark_node->idx; idx++) {
            obj = mark_node->set[idx];
            hmu = obj_to_hmu(obj);
            bh_assert(hmu_is_wo_marked(hmu));
            bh_assert((gc_uint8 *)hmu >= heap->base_addr
                      && (gc_uint8 *)hmu
                             < heap->base_addr + heap->current_size);
        }

        mark_node = mark_node->next;
    }
#endif

    /* TODO: when fast marking failed, we can still do slow
       marking, currently just simply roll it back.  */
    if (heap->is_fast_marking_failed) {
        LOG_ERROR("enumerate rootset failed");
        LOG_ERROR("all marked wos will be unmarked to keep heap consistency");

        rollback_mark(heap);
        heap->is_fast_marking_failed = 0;
        return GC_ERROR;
    }

    /* the algorithm we use to mark all objects */
    /* 1. mark rootset and organize them into a mark_node list (last marked
     * roots at list header, i.e. stack top) */
    /* 2. in every iteration, we use the top node to expand*/
    /* 3. execute step 2 till no expanding */
    /* this is a BFS & DFS mixed algorithm, but more like DFS */
    mark_node = (mark_node_t *)heap->root_set;
    while (mark_node) {
        heap->root_set = mark_node->next;

        /* note that mark_node->idx may change in each loop */
        for (idx = 0; idx < (int)mark_node->idx; idx++) {
            obj = mark_node->set[idx];
            hmu = obj_to_hmu(obj);
            size = hmu_get_size(hmu);

            if (!gct_vm_get_wasm_object_ref_list(obj, &is_compact_mode,
                                                 &ref_num, &ref_list,
                                                 &ref_start_offset)) {
                LOG_ERROR("mark process failed because failed "
                          "vm_get_wasm_object_ref_list");
                break;
            }

            if (ref_num >= 2U * GB) {
                LOG_ERROR("Invalid ref_num returned");
                break;
            }

            if (is_compact_mode) {
                for (j = 0; j < (int)ref_num; j++) {
                    offset = ref_start_offset + j * sizeof(void *);
                    bh_assert(offset + sizeof(void *) < size);
                    ref = *(gc_object_t *)(((gc_uint8 *)obj) + offset);
                    if (ref == NULL_REF || ((uintptr_t)ref & 1))
                        continue; /* null object or i31 object */
                    if (add_wo_to_expand(heap, ref) == GC_ERROR) {
                        LOG_ERROR("add_wo_to_expand failed");
                        break;
                    }
                }
                if (j < (int)ref_num)
                    break;
            }
            else {
                for (j = 0; j < (int)ref_num; j++) {
                    offset = ref_list[j];
                    bh_assert(offset + sizeof(void *) < size);

                    ref = *(gc_object_t *)(((gc_uint8 *)obj) + offset);
                    if (ref == NULL_REF || ((uintptr_t)ref & 1))
                        continue; /* null object or i31 object */
                    if (add_wo_to_expand(heap, ref) == GC_ERROR) {
                        LOG_ERROR("mark process failed");
                        break;
                    }
                }
                if (j < (int)ref_num)
                    break;
            }
        }
        if (idx < (int)mark_node->idx)
            break; /* not yet done */

        /* obj's in mark_node are all expanded */
        free_mark_node(mark_node);
        mark_node = heap->root_set;
    }

    if (mark_node) {
        LOG_ERROR("mark process is not successfully finished");

        free_mark_node(mark_node);
        /* roll back is required */
        rollback_mark(heap);

        return GC_ERROR;
    }

    /* now sweep */
    sweep_instance_heap(heap);

    (void)size;

    return GC_SUCCESS;
}

/**
 * Do GC on given heap
 *
 * @param the heap to do GC, should be a valid heap
 *
 * @return GC_SUCCESS if success, GC_ERROR otherwise
 */
int
gci_gc_heap(void *h)
{
    int ret = GC_ERROR;
    gc_heap_t *heap = (gc_heap_t *)h;

    bh_assert(gci_is_heap_valid(heap));

    LOG_VERBOSE("#reclaim instance heap %p", heap);

    /* TODO: get exec_env of current thread when GC multi-threading
       is enabled, and pass it to runtime */
    gct_vm_gc_prepare(NULL);

    gct_vm_mutex_lock(&heap->lock);
    heap->is_doing_reclaim = 1;

    ret = reclaim_instance_heap(heap);

    heap->is_doing_reclaim = 0;
    gct_vm_mutex_unlock(&heap->lock);

    /* TODO: get exec_env of current thread when GC multi-threading
       is enabled, and pass it to runtime */
    gct_vm_gc_finished(NULL);

    LOG_VERBOSE("#reclaim instance heap %p done", heap);

#if BH_ENABLE_GC_VERIFY != 0
    gci_verify_heap(heap);
#endif

#if GC_STAT_SHOW != 0
    gc_show_stat(heap);
    gc_show_fragment(heap);
#endif

    return ret;
}

int
gc_is_dead_object(void *obj)
{
    return !hmu_is_wo_marked(obj_to_hmu(obj));
}

#else

int
gci_gc_heap(void *h)
{
    (void)h;
    return GC_ERROR;
}

#endif /* end of WASM_ENABLE_GC != 0 */
