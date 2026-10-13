/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_log.h"
#include "wasm_c_api_internal.h"

#include "bh_assert.h"
#include "wasm_export.h"
#include "wasm_memory.h"
#if WASM_ENABLE_INTERP != 0
#include "wasm_runtime.h"
#endif
#if WASM_ENABLE_AOT != 0
#include "aot_runtime.h"
#if WASM_ENABLE_JIT != 0 && WASM_ENABLE_LAZY_JIT == 0
#include "aot.h"
#include "aot_llvm.h"
#endif /*WASM_ENABLE_JIT != 0 && WASM_ENABLE_LAZY_JIT == 0*/
#endif /*WASM_ENABLE_AOT != 0*/

#if WASM_ENABLE_WASM_CACHE != 0
#include <openssl/sha.h>
#endif
#if WASM_ENABLE_THREAD_MGR != 0
#include "thread_manager.h"
#endif

/*
 * Thread Model:
 * - Only one wasm_engine_t in one process
 * - One wasm_store_t is only accessed by one thread. wasm_store_t can't be
 * shared in threads
 * - wasm_module_t can be shared in threads
 * - wasm_instance_t can not be shared in threads
 */

#define ASSERT_NOT_IMPLEMENTED() bh_assert(!"not implemented")
#define UNREACHABLE() bh_assert(!"unreachable")

typedef struct wasm_module_ex_t {
    struct WASMModuleCommon *module_comm_rt;
    wasm_byte_vec_t *binary;
    /* If true, binary in wasm_module_ex_t contains a copy of the WASM binary */
    bool is_binary_cloned;
    korp_mutex lock;
    uint32 ref_count;
#if WASM_ENABLE_WASM_CACHE != 0
    char hash[SHA256_DIGEST_LENGTH];
#endif
} wasm_module_ex_t;

#ifndef os_thread_local_attribute
typedef struct thread_local_stores {
    korp_tid tid;
    unsigned stores_num;
} thread_local_stores;
#endif

static void
wasm_module_delete_internal(wasm_module_t *);

static void
wasm_instance_delete_internal(wasm_instance_t *);

/* temporarily put stubs here */
static wasm_store_t *
wasm_store_copy(const wasm_store_t *src)
{
    (void)src;
    LOG_WARNING("in the stub of %s", __FUNCTION__);
    return NULL;
}

wasm_module_t *
wasm_module_copy(const wasm_module_t *src)
{
    (void)src;
    LOG_WARNING("in the stub of %s", __FUNCTION__);
    return NULL;
}

wasm_instance_t *
wasm_instance_copy(const wasm_instance_t *src)
{
    (void)src;
    LOG_WARNING("in the stub of %s", __FUNCTION__);
    return NULL;
}

/* ---------------------------------------------------------------------- */
static inline void *
malloc_internal(uint64 size)
{
    void *mem = NULL;

    if (size < UINT32_MAX && (mem = wasm_runtime_malloc((uint32)size))) {
        memset(mem, 0, size);
    }

    return mem;
}

/* clang-format off */
#define RETURN_OBJ(obj, obj_del_func) \
    return obj;                       \
failed:                               \
    obj_del_func(obj);                \
    return NULL;

#define RETURN_VOID(obj, obj_del_func) \
    return;                            \
failed:                                \
    obj_del_func(obj);                 \
    return;
/* clang-format on */

/* Vectors */
#define INIT_VEC(vector_p, init_func, ...)                        \
    do {                                                          \
        if (!(vector_p = malloc_internal(sizeof(*(vector_p))))) { \
            goto failed;                                          \
        }                                                         \
                                                                  \
        init_func(vector_p, ##__VA_ARGS__);                       \
        if (vector_p->size && !vector_p->data) {                  \
            LOG_DEBUG("%s failed", #init_func);                   \
            goto failed;                                          \
        }                                                         \
    } while (false)

#define DEINIT_VEC(vector_p, deinit_func) \
    if ((vector_p)) {                     \
        deinit_func(vector_p);            \
        wasm_runtime_free(vector_p);      \
        vector_p = NULL;                  \
    }

#define WASM_DEFINE_VEC(name)                                              \
    void wasm_##name##_vec_new_empty(own wasm_##name##_vec_t *out)         \
    {                                                                      \
        wasm_##name##_vec_new_uninitialized(out, 0);                       \
    }                                                                      \
    void wasm_##name##_vec_new_uninitialized(own wasm_##name##_vec_t *out, \
                                             size_t size)                  \
    {                                                                      \
        wasm_##name##_vec_new(out, size, NULL);                            \
    }

/* vectors with no ownership management of elements */
#define WASM_DEFINE_VEC_PLAIN(name)                                       \
    WASM_DEFINE_VEC(name)                                                 \
    void wasm_##name##_vec_new(own wasm_##name##_vec_t *out, size_t size, \
                               own wasm_##name##_t const data[])          \
    {                                                                     \
        if (!out) {                                                       \
            return;                                                       \
        }                                                                 \
                                                                          \
        memset(out, 0, sizeof(wasm_##name##_vec_t));                      \
                                                                          \
        if (!size) {                                                      \
            return;                                                       \
        }                                                                 \
                                                                          \
        if (!bh_vector_init((Vector *)out, size, sizeof(wasm_##name##_t), \
                            true)) {                                      \
            LOG_DEBUG("bh_vector_init failed");                           \
            goto failed;                                                  \
        }                                                                 \
                                                                          \
        if (data) {                                                       \
            uint32 size_in_bytes = 0;                                     \
            size_in_bytes = (uint32)(size * sizeof(wasm_##name##_t));     \
            bh_memcpy_s(out->data, size_in_bytes, data, size_in_bytes);   \
            out->num_elems = size;                                        \
        }                                                                 \
                                                                          \
        RETURN_VOID(out, wasm_##name##_vec_delete)                        \
    }                                                                     \
    void wasm_##name##_vec_copy(wasm_##name##_vec_t *out,                 \
                                const wasm_##name##_vec_t *src)           \
    {                                                                     \
        if (!src) {                                                       \
            return;                                                       \
        }                                                                 \
        wasm_##name##_vec_new(out, src->size, src->data);                 \
    }                                                                     \
    void wasm_##name##_vec_delete(wasm_##name##_vec_t *v)                 \
    {                                                                     \
        if (v) {                                                          \
            bh_vector_destroy((Vector *)v);                               \
        }                                                                 \
    }

/* vectors that own their elements */
#define WASM_DEFINE_VEC_OWN(name, elem_destroy_func)                        \
    WASM_DEFINE_VEC(name)                                                   \
    void wasm_##name##_vec_new(own wasm_##name##_vec_t *out, size_t size,   \
                               own wasm_##name##_t *const data[])           \
    {                                                                       \
        if (!out) {                                                         \
            return;                                                         \
        }                                                                   \
                                                                            \
        memset(out, 0, sizeof(wasm_##name##_vec_t));                        \
                                                                            \
        if (!size) {                                                        \
            return;                                                         \
        }                                                                   \
                                                                            \
        if (!bh_vector_init((Vector *)out, size, sizeof(wasm_##name##_t *), \
                            true)) {                                        \
            LOG_DEBUG("bh_vector_init failed");                             \
            goto failed;                                                    \
        }                                                                   \
                                                                            \
        if (data) {                                                         \
            uint32 size_in_bytes = 0;                                       \
            size_in_bytes = (uint32)(size * sizeof(wasm_##name##_t *));     \
            bh_memcpy_s(out->data, size_in_bytes, data, size_in_bytes);     \
            out->num_elems = size;                                          \
        }                                                                   \
                                                                            \
        RETURN_VOID(out, wasm_##name##_vec_delete)                          \
    }                                                                       \
    void wasm_##name##_vec_copy(own wasm_##name##_vec_t *out,               \
                                const wasm_##name##_vec_t *src)             \
    {                                                                       \
        size_t i = 0;                                                       \
                                                                            \
        if (!out) {                                                         \
            return;                                                         \
        }                                                                   \
        memset(out, 0, sizeof(Vector));                                     \
                                                                            \
        if (!src || !src->size) {                                           \
            return;                                                         \
        }                                                                   \
                                                                            \
        if (!bh_vector_init((Vector *)out, src->size,                       \
                            sizeof(wasm_##name##_t *), true)) {             \
            LOG_DEBUG("bh_vector_init failed");                             \
            goto failed;                                                    \
        }                                                                   \
                                                                            \
        for (i = 0; i != src->num_elems; ++i) {                             \
            if (!(out->data[i] = wasm_##name##_copy(src->data[i]))) {       \
                LOG_DEBUG("wasm_%s_copy failed", #name);                    \
                goto failed;                                                \
            }                                                               \
        }                                                                   \
        out->num_elems = src->num_elems;                                    \
                                                                            \
        RETURN_VOID(out, wasm_##name##_vec_delete)                          \
    }                                                                       \
    void wasm_##name##_vec_delete(wasm_##name##_vec_t *v)                   \
    {                                                                       \
        size_t i = 0;                                                       \
        if (!v) {                                                           \
            return;                                                         \
        }                                                                   \
        for (i = 0; i != v->num_elems && v->data; ++i) {                    \
            elem_destroy_func(*(v->data + i));                              \
        }                                                                   \
        bh_vector_destroy((Vector *)v);                                     \
    }

WASM_DEFINE_VEC_PLAIN(byte)
WASM_DEFINE_VEC_PLAIN(val)

WASM_DEFINE_VEC_OWN(exporttype, wasm_exporttype_delete)
WASM_DEFINE_VEC_OWN(extern, wasm_extern_delete)
WASM_DEFINE_VEC_OWN(frame, wasm_frame_delete)
WASM_DEFINE_VEC_OWN(functype, wasm_functype_delete)
WASM_DEFINE_VEC_OWN(importtype, wasm_importtype_delete)
WASM_DEFINE_VEC_OWN(instance, wasm_instance_delete_internal)
WASM_DEFINE_VEC_OWN(module, wasm_module_delete_internal)
WASM_DEFINE_VEC_OWN(store, wasm_store_delete)
WASM_DEFINE_VEC_OWN(valtype, wasm_valtype_delete)

#ifndef NDEBUG
#if WASM_ENABLE_MEMORY_PROFILING != 0
#define WASM_C_DUMP_PROC_MEM() LOG_PROC_MEM()
#else
#define WASM_C_DUMP_PROC_MEM() (void)0
#endif
#else
#define WASM_C_DUMP_PROC_MEM() (void)0
#endif

/* Runtime Environment */
own wasm_config_t *
wasm_config_new(void)
{
    /* since wasm_runtime_malloc is not ready */
    wasm_config_t *config = os_malloc(sizeof(wasm_config_t));
    if (!config)
        return NULL;

    memset(config, 0, sizeof(wasm_config_t));
    config->mem_alloc_type = Alloc_With_System_Allocator;

    return config;
}

void
wasm_config_delete(own wasm_config_t *config)
{
    if (config)
        os_free(config);
}

wasm_config_t *
wasm_config_set_mem_alloc_opt(wasm_config_t *config,
                              mem_alloc_type_t mem_alloc_type,
                              MemAllocOption *mem_alloc_option)
{
    if (!config)
        return NULL;

    config->mem_alloc_type = mem_alloc_type;
    if (mem_alloc_option)
        memcpy(&config->mem_alloc_option, mem_alloc_option,
               sizeof(MemAllocOption));
    return config;
}

wasm_config_t *
wasm_config_set_linux_perf_opt(wasm_config_t *config, bool enable)
{
    if (!config)
        return NULL;

    config->enable_linux_perf = enable;
    return config;
}

wasm_config_t *
wasm_config_set_segue_flags(wasm_config_t *config, uint32 segue_flags)
{
    if (!config)
        return NULL;

    config->segue_flags = segue_flags;
    return config;
}

static void
wasm_engine_delete_internal(wasm_engine_t *engine)
{
    if (engine) {
        /* clean all created wasm_module_t and their locks */
        unsigned i;

        for (i = 0; i < engine->modules.num_elems; i++) {
            wasm_module_ex_t *module;
            if (bh_vector_get(&engine->modules, i, &module)) {
                os_mutex_destroy(&module->lock);
                wasm_runtime_free(module);
            }
        }

        bh_vector_destroy(&engine->modules);

#ifndef os_thread_local_attribute
        bh_vector_destroy(&engine->stores_by_tid);
#endif

        wasm_runtime_free(engine);
    }

    wasm_runtime_destroy();
}

static wasm_engine_t *
wasm_engine_new_internal(wasm_config_t *config)
{
    wasm_engine_t *engine = NULL;
    /* init runtime */
    RuntimeInitArgs init_args = { 0 };
#if WASM_ENABLE_JIT != 0
    LLVMJITOptions *jit_options = wasm_runtime_get_llvm_jit_options();
#endif

#ifndef NDEBUG
    bh_log_set_verbose_level(BH_LOG_LEVEL_VERBOSE);
#else
    bh_log_set_verbose_level(BH_LOG_LEVEL_WARNING);
#endif

    WASM_C_DUMP_PROC_MEM();

    /* wasm_config_t->MemAllocOption -> RuntimeInitArgs->MemAllocOption */
    init_args.mem_alloc_type = config->mem_alloc_type;
    memcpy(&init_args.mem_alloc_option, &config->mem_alloc_option,
           sizeof(MemAllocOption));
    init_args.enable_linux_perf = config->enable_linux_perf;
    init_args.segue_flags = config->segue_flags;

#if WASM_ENABLE_JIT != 0
    jit_options->quick_invoke_c_api_import = true;
#endif

    if (!wasm_runtime_full_init(&init_args)) {
        LOG_DEBUG("wasm_runtime_full_init failed");
        goto failed;
    }

    /* create wasm_engine_t */
    if (!(engine = malloc_internal(sizeof(wasm_engine_t)))) {
        goto failed;
    }

    if (!bh_vector_init(&engine->modules, DEFAULT_VECTOR_INIT_SIZE,
                        sizeof(wasm_module_ex_t *), true))
        goto failed;

#ifndef os_thread_local_attribute
    if (!bh_vector_init(&engine->stores_by_tid, DEFAULT_VECTOR_INIT_SIZE,
                        sizeof(thread_local_stores), true))
        goto failed;
#endif

    engine->ref_count = 1;

    WASM_C_DUMP_PROC_MEM();

    RETURN_OBJ(engine, wasm_engine_delete_internal)
}

/* global engine instance */
static wasm_engine_t *singleton_engine;
#ifdef os_thread_local_attribute
/* categorize wasm_store_t as threads*/
static os_thread_local_attribute unsigned thread_local_stores_num = 0;
#endif
#if defined(OS_THREAD_MUTEX_INITIALIZER)
/**
 * lock for the singleton_engine
 * Note: if the platform has mutex initializer, we use a global lock to
 * lock the operations of the singleton_engine, otherwise when there are
 * operations happening simultaneously in multiple threads, developer
 * must create the lock by himself, and use it to lock the operations
 */
static korp_mutex engine_lock = OS_THREAD_MUTEX_INITIALIZER;
#endif

own wasm_engine_t *
wasm_engine_new()
{
    wasm_config_t config = { 0 };
    wasm_config_set_mem_alloc_opt(&config, Alloc_With_System_Allocator, NULL);
    wasm_engine_t *engine = wasm_engine_new_with_config(&config);
    return engine;
}

own wasm_engine_t *
wasm_engine_new_with_config(wasm_config_t *config)
{
#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&engine_lock);
#endif

    if (!singleton_engine)
        singleton_engine = wasm_engine_new_internal(config);
    else
        singleton_engine->ref_count++;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&engine_lock);
#endif

    return singleton_engine;
}

own wasm_engine_t *
wasm_engine_new_with_args(mem_alloc_type_t type, const MemAllocOption *opts)
{
    wasm_config_t config = { 0 };
    config.mem_alloc_type = type;
    memcpy(&config.mem_alloc_option, opts, sizeof(MemAllocOption));
    return wasm_engine_new_with_config(&config);
}

void
wasm_engine_delete(wasm_engine_t *engine)
{
    if (!engine)
        return;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&engine_lock);
#endif

    if (!singleton_engine) {
#if defined(OS_THREAD_MUTEX_INITIALIZER)
        os_mutex_unlock(&engine_lock);
#endif
        return;
    }

    bh_assert(engine == singleton_engine);
    bh_assert(singleton_engine->ref_count > 0);

    singleton_engine->ref_count--;
    if (singleton_engine->ref_count == 0) {
        wasm_engine_delete_internal(engine);
        singleton_engine = NULL;
    }

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&engine_lock);
#endif
}

#ifndef os_thread_local_attribute
static bool
search_thread_local_store_num(Vector *stores_by_tid, korp_tid tid,
                              thread_local_stores *out_ts, unsigned *out_i)
{
    unsigned i;

    for (i = 0; i < stores_by_tid->num_elems; i++) {
        bool ret = bh_vector_get(stores_by_tid, i, out_ts);
        bh_assert(ret);
        (void)ret;

        if (out_ts->tid == tid) {
            *out_i = i;
            return true;
        }
    }

    return false;
}
#endif

static unsigned
retrieve_thread_local_store_num(Vector *stores_by_tid, korp_tid tid)
{
#ifndef os_thread_local_attribute
    unsigned i = 0;
    thread_local_stores ts = { 0 };
    unsigned ret = 0;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&engine_lock);
#endif

    if (search_thread_local_store_num(stores_by_tid, tid, &ts, &i))
        ret = ts.stores_num;
    else
        ret = 0;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&engine_lock);
#endif

    return ret;
#else
    (void)stores_by_tid;
    (void)tid;

    return thread_local_stores_num;
#endif
}

static bool
increase_thread_local_store_num(Vector *stores_by_tid, korp_tid tid)
{
#ifndef os_thread_local_attribute
    unsigned i = 0;
    thread_local_stores ts = { 0 };
    bool ret = false;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&engine_lock);
#endif

    if (search_thread_local_store_num(stores_by_tid, tid, &ts, &i)) {
        /* just in case if integer overflow */
        if (ts.stores_num + 1 < ts.stores_num) {
            ret = false;
        }
        else {
            ts.stores_num++;
            ret = bh_vector_set(stores_by_tid, i, &ts);
            bh_assert(ret);
        }
    }
    else {
        ts.tid = tid;
        ts.stores_num = 1;
        ret = bh_vector_append(stores_by_tid, &ts);
    }

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&engine_lock);
#endif
    return ret;
#else
    (void)stores_by_tid;
    (void)tid;

    /* just in case if integer overflow */
    if (thread_local_stores_num + 1 < thread_local_stores_num)
        return false;

    thread_local_stores_num++;
    return true;
#endif
}

static bool
decrease_thread_local_store_num(Vector *stores_by_tid, korp_tid tid)
{
#ifndef os_thread_local_attribute
    unsigned i = 0;
    thread_local_stores ts = { 0 };
    bool ret = false;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&engine_lock);
#endif

    ret = search_thread_local_store_num(stores_by_tid, tid, &ts, &i);
    bh_assert(ret);

    /* just in case if integer overflow */
    if (ts.stores_num - 1 > ts.stores_num) {
        ret = false;
    }
    else {
        ts.stores_num--;
        ret = bh_vector_set(stores_by_tid, i, &ts);
        bh_assert(ret);
    }

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&engine_lock);
#endif

    return ret;
#else
    (void)stores_by_tid;
    (void)tid;

    /* just in case if integer overflow */
    if (thread_local_stores_num - 1 > thread_local_stores_num)
        return false;

    thread_local_stores_num--;
    return true;
#endif
}

wasm_store_t *
wasm_store_new(wasm_engine_t *engine)
{
    wasm_store_t *store = NULL;

    WASM_C_DUMP_PROC_MEM();

    if (!engine || singleton_engine != engine)
        return NULL;

    if (!retrieve_thread_local_store_num(&engine->stores_by_tid,
                                         os_self_thread())) {
        if (!wasm_runtime_init_thread_env()) {
            LOG_ERROR("init thread environment failed");
            return NULL;
        }

        if (!increase_thread_local_store_num(&engine->stores_by_tid,
                                             os_self_thread())) {
            wasm_runtime_destroy_thread_env();
            return NULL;
        }

        if (!(store = malloc_internal(sizeof(wasm_store_t)))) {
            decrease_thread_local_store_num(&singleton_engine->stores_by_tid,
                                            os_self_thread());
            wasm_runtime_destroy_thread_env();
            return NULL;
        }
    }
    else {
        if (!increase_thread_local_store_num(&engine->stores_by_tid,
                                             os_self_thread()))
            return NULL;

        if (!(store = malloc_internal(sizeof(wasm_store_t)))) {
            decrease_thread_local_store_num(&singleton_engine->stores_by_tid,
                                            os_self_thread());
            return NULL;
        }
    }

    /* new a vector, and new its data */
    INIT_VEC(store->modules, wasm_module_vec_new_uninitialized,
             DEFAULT_VECTOR_INIT_LENGTH);
    INIT_VEC(store->instances, wasm_instance_vec_new_uninitialized,
             DEFAULT_VECTOR_INIT_LENGTH);

    if (!(store->foreigns = malloc_internal(sizeof(Vector)))
        || !(bh_vector_init(store->foreigns, 24, sizeof(wasm_foreign_t *),
                            true))) {
        goto failed;
    }

    WASM_C_DUMP_PROC_MEM();

    return store;
failed:
    wasm_store_delete(store);
    return NULL;
}

void
wasm_store_delete(wasm_store_t *store)
{
    if (!store) {
        return;
    }

    DEINIT_VEC(store->instances, wasm_instance_vec_delete);
    DEINIT_VEC(store->modules, wasm_module_vec_delete);
    if (store->foreigns) {
        bh_vector_destroy(store->foreigns);
        wasm_runtime_free(store->foreigns);
    }

    wasm_runtime_free(store);

    if (decrease_thread_local_store_num(&singleton_engine->stores_by_tid,
                                        os_self_thread())) {
        if (!retrieve_thread_local_store_num(&singleton_engine->stores_by_tid,
                                             os_self_thread())) {
            wasm_runtime_destroy_thread_env();
        }
    }
}

/* Type Representations */
static inline wasm_valkind_t
val_type_rt_2_valkind(uint8 val_type_rt)
{
    switch (val_type_rt) {
#define WAMR_VAL_TYPE_2_WASM_VAL_KIND(name) \
    case VALUE_TYPE_##name:                 \
        return WASM_##name;

        WAMR_VAL_TYPE_2_WASM_VAL_KIND(I32)
        WAMR_VAL_TYPE_2_WASM_VAL_KIND(I64)
        WAMR_VAL_TYPE_2_WASM_VAL_KIND(F32)
        WAMR_VAL_TYPE_2_WASM_VAL_KIND(F64)
        WAMR_VAL_TYPE_2_WASM_VAL_KIND(V128)
        WAMR_VAL_TYPE_2_WASM_VAL_KIND(FUNCREF)
#undef WAMR_VAL_TYPE_2_WASM_VAL_KIND

        default:
            return WASM_EXTERNREF;
    }
}

static wasm_valtype_t *
wasm_valtype_new_internal(uint8 val_type_rt)
{
    return wasm_valtype_new(val_type_rt_2_valkind(val_type_rt));
}

wasm_valtype_t *
wasm_valtype_new(wasm_valkind_t kind)
{
    wasm_valtype_t *val_type;

    if (kind > WASM_V128 && WASM_FUNCREF != kind
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
        && WASM_EXTERNREF != kind
#endif
    ) {
        return NULL;
    }

    if (!(val_type = malloc_internal(sizeof(wasm_valtype_t)))) {
        return NULL;
    }

    val_type->kind = kind;

    return val_type;
}

void
wasm_valtype_delete(wasm_valtype_t *val_type)
{
    if (val_type) {
        wasm_runtime_free(val_type);
    }
}

wasm_valtype_t *
wasm_valtype_copy(const wasm_valtype_t *src)
{
    return src ? wasm_valtype_new(src->kind) : NULL;
}

wasm_valkind_t
wasm_valtype_kind(const wasm_valtype_t *val_type)
{
    return val_type ? val_type->kind : WASM_EXTERNREF;
}

static wasm_functype_t *
wasm_functype_new_internal(WASMFuncType *type_rt)
{
    wasm_functype_t *type = NULL;
    wasm_valtype_t *param_type = NULL, *result_type = NULL;
    uint32 i = 0;

    if (!type_rt) {
        return NULL;
    }

    if (!(type = malloc_internal(sizeof(wasm_functype_t)))) {
        return NULL;
    }

    type->extern_kind = WASM_EXTERN_FUNC;

    /* WASMFuncType->types[0 : type_rt->param_count) -> type->params */
    INIT_VEC(type->params, wasm_valtype_vec_new_uninitialized,
             type_rt->param_count);
    for (i = 0; i < type_rt->param_count; ++i) {
        if (!(param_type = wasm_valtype_new_internal(*(type_rt->types + i)))) {
            goto failed;
        }

        if (!bh_vector_append((Vector *)type->params, &param_type)) {
            LOG_DEBUG("bh_vector_append failed");
            goto failed;
        }
    }

    /* WASMFuncType->types[type_rt->param_count : type_rt->result_count) ->
     * type->results */
    INIT_VEC(type->results, wasm_valtype_vec_new_uninitialized,
             type_rt->result_count);
    for (i = 0; i < type_rt->result_count; ++i) {
        if (!(result_type = wasm_valtype_new_internal(
                  *(type_rt->types + type_rt->param_count + i)))) {
            goto failed;
        }

        if (!bh_vector_append((Vector *)type->results, &result_type)) {
            LOG_DEBUG("bh_vector_append failed");
            goto failed;
        }
    }

    return type;

failed:
    wasm_valtype_delete(param_type);
    wasm_valtype_delete(result_type);
    wasm_functype_delete(type);
    return NULL;
}

wasm_functype_t *
wasm_functype_new(own wasm_valtype_vec_t *params,
                  own wasm_valtype_vec_t *results)
{
    wasm_functype_t *type = NULL;

    if (!(type = malloc_internal(sizeof(wasm_functype_t)))) {
        goto failed;
    }

    type->extern_kind = WASM_EXTERN_FUNC;

    /* take ownership */
    if (!(type->params = malloc_internal(sizeof(wasm_valtype_vec_t)))) {
        goto failed;
    }
    if (params) {
        bh_memcpy_s(type->params, sizeof(wasm_valtype_vec_t), params,
                    sizeof(wasm_valtype_vec_t));
    }

    if (!(type->results = malloc_internal(sizeof(wasm_valtype_vec_t)))) {
        goto failed;
    }
    if (results) {
        bh_memcpy_s(type->results, sizeof(wasm_valtype_vec_t), results,
                    sizeof(wasm_valtype_vec_t));
    }

    return type;

failed:
    wasm_functype_delete(type);
    return NULL;
}

wasm_functype_t *
wasm_functype_copy(const wasm_functype_t *src)
{
    wasm_functype_t *functype;
    wasm_valtype_vec_t params = { 0 }, results = { 0 };

    if (!src) {
        return NULL;
    }

    wasm_valtype_vec_copy(&params, src->params);
    if (src->params->size && !params.data) {
        goto failed;
    }

    wasm_valtype_vec_copy(&results, src->results);
    if (src->results->size && !results.data) {
        goto failed;
    }

    if (!(functype = wasm_functype_new(&params, &results))) {
        goto failed;
    }

    return functype;

failed:
    wasm_valtype_vec_delete(&params);
    wasm_valtype_vec_delete(&results);
    return NULL;
}

void
wasm_functype_delete(wasm_functype_t *func_type)
{
    if (!func_type) {
        return;
    }

    DEINIT_VEC(func_type->params, wasm_valtype_vec_delete);
    DEINIT_VEC(func_type->results, wasm_valtype_vec_delete);

    wasm_runtime_free(func_type);
}

const wasm_valtype_vec_t *
wasm_functype_params(const wasm_functype_t *func_type)
{
    if (!func_type) {
        return NULL;
    }

    return func_type->params;
}

const wasm_valtype_vec_t *
wasm_functype_results(const wasm_functype_t *func_type)
{
    if (!func_type) {
        return NULL;
    }

    return func_type->results;
}

static bool
cmp_val_kind_with_val_type(wasm_valkind_t v_k, uint8 v_t)
{
    return (v_k == WASM_I32 && v_t == VALUE_TYPE_I32)
           || (v_k == WASM_I64 && v_t == VALUE_TYPE_I64)
           || (v_k == WASM_F32 && v_t == VALUE_TYPE_F32)
           || (v_k == WASM_F64 && v_t == VALUE_TYPE_F64)
           || (v_k == WASM_V128 && v_t == VALUE_TYPE_V128)
           || (v_k == WASM_EXTERNREF && v_t == VALUE_TYPE_EXTERNREF)
           || (v_k == WASM_FUNCREF && v_t == VALUE_TYPE_FUNCREF);
}

/*
 *to compare a function type of wasm-c-api with a function type of wasm_runtime
 */
static bool
wasm_functype_same_internal(const wasm_functype_t *type,
                            const WASMFuncType *type_intl)
{
    uint32 i = 0;

    if (!type || !type_intl || type->params->num_elems != type_intl->param_count
        || type->results->num_elems != type_intl->result_count)
        return false;

    for (i = 0; i < type->params->num_elems; i++) {
        wasm_valtype_t *v_t = type->params->data[i];
        if (!cmp_val_kind_with_val_type(wasm_valtype_kind(v_t),
                                        type_intl->types[i]))
            return false;
    }

    for (i = 0; i < type->results->num_elems; i++) {
        wasm_valtype_t *v_t = type->results->data[i];
        if (!cmp_val_kind_with_val_type(
                wasm_valtype_kind(v_t),
                type_intl->types[i + type->params->num_elems]))
            return false;
    }

    return true;
}

wasm_globaltype_t *
wasm_globaltype_new(own wasm_valtype_t *val_type, wasm_mutability_t mut)
{
    wasm_globaltype_t *global_type = NULL;

    if (!val_type) {
        return NULL;
    }

    if (!(global_type = malloc_internal(sizeof(wasm_globaltype_t)))) {
        return NULL;
    }

    global_type->extern_kind = WASM_EXTERN_GLOBAL;
    global_type->val_type = val_type;
    global_type->mutability = mut;

    return global_type;
}

wasm_globaltype_t *
wasm_globaltype_new_internal(uint8 val_type_rt, bool is_mutable)
{
    wasm_globaltype_t *globaltype;
    wasm_valtype_t *val_type;

    if (!(val_type = wasm_valtype_new(val_type_rt_2_valkind(val_type_rt)))) {
        return NULL;
    }

    if (!(globaltype = wasm_globaltype_new(
              val_type, is_mutable ? WASM_VAR : WASM_CONST))) {
        wasm_valtype_delete(val_type);
    }

    return globaltype;
}

void
wasm_globaltype_delete(wasm_globaltype_t *global_type)
{
    if (!global_type) {
        return;
    }

    if (global_type->val_type) {
        wasm_valtype_delete(global_type->val_type);
        global_type->val_type = NULL;
    }

    wasm_runtime_free(global_type);
}

wasm_globaltype_t *
wasm_globaltype_copy(const wasm_globaltype_t *src)
{
    wasm_globaltype_t *global_type;
    wasm_valtype_t *val_type;

    if (!src) {
        return NULL;
    }

    if (!(val_type = wasm_valtype_copy(src->val_type))) {
        return NULL;
    }

    if (!(global_type = wasm_globaltype_new(val_type, src->mutability))) {
        wasm_valtype_delete(val_type);
    }

    return global_type;
}

const wasm_valtype_t *
wasm_globaltype_content(const wasm_globaltype_t *global_type)
{
    if (!global_type) {
        return NULL;
    }

    return global_type->val_type;
}

wasm_mutability_t
wasm_globaltype_mutability(const wasm_globaltype_t *global_type)
{
    if (!global_type) {
        return false;
    }

    return global_type->mutability;
}

static wasm_tabletype_t *
wasm_tabletype_new_internal(uint8 val_type_rt, uint32 init_size,
                            uint32 max_size)
{
    wasm_tabletype_t *table_type;
    wasm_limits_t limits = { init_size, max_size };
    wasm_valtype_t *val_type;

    if (!(val_type = wasm_valtype_new_internal(val_type_rt))) {
        return NULL;
    }

    if (!(table_type = wasm_tabletype_new(val_type, &limits))) {
        wasm_valtype_delete(val_type);
    }

    return table_type;
}

wasm_tabletype_t *
wasm_tabletype_new(own wasm_valtype_t *val_type, const wasm_limits_t *limits)
{
    wasm_tabletype_t *table_type = NULL;

    if (!val_type || !limits) {
        return NULL;
    }

    if (wasm_valtype_kind(val_type) != WASM_FUNCREF
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
        && wasm_valtype_kind(val_type) != WASM_EXTERNREF
#endif
    ) {
        return NULL;
    }

    if (!(table_type = malloc_internal(sizeof(wasm_tabletype_t)))) {
        return NULL;
    }

    table_type->extern_kind = WASM_EXTERN_TABLE;
    table_type->val_type = val_type;
    table_type->limits.min = limits->min;
    table_type->limits.max = limits->max;

    return table_type;
}

wasm_tabletype_t *
wasm_tabletype_copy(const wasm_tabletype_t *src)
{
    wasm_tabletype_t *table_type;
    wasm_valtype_t *val_type;

    if (!src) {
        return NULL;
    }

    if (!(val_type = wasm_valtype_copy(src->val_type))) {
        return NULL;
    }

    if (!(table_type = wasm_tabletype_new(val_type, &src->limits))) {
        wasm_valtype_delete(val_type);
    }

    return table_type;
}

void
wasm_tabletype_delete(wasm_tabletype_t *table_type)
{
    if (!table_type) {
        return;
    }

    if (table_type->val_type) {
        wasm_valtype_delete(table_type->val_type);
        table_type->val_type = NULL;
    }

    wasm_runtime_free(table_type);
}

const wasm_valtype_t *
wasm_tabletype_element(const wasm_tabletype_t *table_type)
{
    if (!table_type) {
        return NULL;
    }

    return table_type->val_type;
}

const wasm_limits_t *
wasm_tabletype_limits(const wasm_tabletype_t *table_type)
{
    if (!table_type) {
        return NULL;
    }

    return &(table_type->limits);
}

static wasm_memorytype_t *
wasm_memorytype_new_internal(uint32 min_pages, uint32 max_pages)
{
    wasm_limits_t limits = { min_pages, max_pages };
    return wasm_memorytype_new(&limits);
}

wasm_memorytype_t *
wasm_memorytype_new(const wasm_limits_t *limits)
{
    wasm_memorytype_t *memory_type = NULL;

    if (!limits) {
        return NULL;
    }

    if (!(memory_type = malloc_internal(sizeof(wasm_memorytype_t)))) {
        return NULL;
    }

    memory_type->extern_kind = WASM_EXTERN_MEMORY;
    memory_type->limits.min = limits->min;
    memory_type->limits.max = limits->max;

    return memory_type;
}

wasm_memorytype_t *
wasm_memorytype_copy(const wasm_memorytype_t *src)
{
    if (!src) {
        return NULL;
    }

    return wasm_memorytype_new(&src->limits);
}

void
wasm_memorytype_delete(wasm_memorytype_t *memory_type)
{
    if (memory_type) {
        wasm_runtime_free(memory_type);
    }
}

const wasm_limits_t *
wasm_memorytype_limits(const wasm_memorytype_t *memory_type)
{
    if (!memory_type) {
        return NULL;
    }

    return &(memory_type->limits);
}

wasm_externkind_t
wasm_externtype_kind(const wasm_externtype_t *extern_type)
{
    if (!extern_type) {
        return WASM_EXTERN_FUNC;
    }

    return extern_type->extern_kind;
}

#define BASIC_FOUR_TYPE_LIST(V) \
    V(functype)                 \
    V(globaltype)               \
    V(memorytype)               \
    V(tabletype)

#define WASM_EXTERNTYPE_AS_OTHERTYPE(name)                                     \
    wasm_##name##_t *wasm_externtype_as_##name(wasm_externtype_t *extern_type) \
    {                                                                          \
        return (wasm_##name##_t *)extern_type;                                 \
    }

BASIC_FOUR_TYPE_LIST(WASM_EXTERNTYPE_AS_OTHERTYPE)
#undef WASM_EXTERNTYPE_AS_OTHERTYPE

#define WASM_OTHERTYPE_AS_EXTERNTYPE(name)                                 \
    wasm_externtype_t *wasm_##name##_as_externtype(wasm_##name##_t *other) \
    {                                                                      \
        return (wasm_externtype_t *)other;                                 \
    }

BASIC_FOUR_TYPE_LIST(WASM_OTHERTYPE_AS_EXTERNTYPE)
#undef WASM_OTHERTYPE_AS_EXTERNTYPE

#define WASM_EXTERNTYPE_AS_OTHERTYPE_CONST(name)              \
    const wasm_##name##_t *wasm_externtype_as_##name##_const( \
        const wasm_externtype_t *extern_type)                 \
    {                                                         \
        return (const wasm_##name##_t *)extern_type;          \
    }

BASIC_FOUR_TYPE_LIST(WASM_EXTERNTYPE_AS_OTHERTYPE_CONST)
#undef WASM_EXTERNTYPE_AS_OTHERTYPE_CONST

#define WASM_OTHERTYPE_AS_EXTERNTYPE_CONST(name)                \
    const wasm_externtype_t *wasm_##name##_as_externtype_const( \
        const wasm_##name##_t *other)                           \
    {                                                           \
        return (const wasm_externtype_t *)other;                \
    }

BASIC_FOUR_TYPE_LIST(WASM_OTHERTYPE_AS_EXTERNTYPE_CONST)
#undef WASM_OTHERTYPE_AS_EXTERNTYPE_CONST

wasm_externtype_t *
wasm_externtype_copy(const wasm_externtype_t *src)
{
    wasm_externtype_t *extern_type = NULL;

    if (!src) {
        return NULL;
    }

    switch (src->extern_kind) {
#define COPY_EXTERNTYPE(NAME, name)                                      \
    case WASM_EXTERN_##NAME:                                             \
    {                                                                    \
        extern_type = wasm_##name##_as_externtype(                       \
            wasm_##name##_copy(wasm_externtype_as_##name##_const(src))); \
        break;                                                           \
    }
        COPY_EXTERNTYPE(FUNC, functype)
        COPY_EXTERNTYPE(GLOBAL, globaltype)
        COPY_EXTERNTYPE(MEMORY, memorytype)
        COPY_EXTERNTYPE(TABLE, tabletype)
#undef COPY_EXTERNTYPE
        default:
            LOG_WARNING("%s meets unsupported kind %u", __FUNCTION__,
                        src->extern_kind);
            break;
    }
    return extern_type;
}

void
wasm_externtype_delete(wasm_externtype_t *extern_type)
{
    if (!extern_type) {
        return;
    }

    switch (wasm_externtype_kind(extern_type)) {
        case WASM_EXTERN_FUNC:
            wasm_functype_delete(wasm_externtype_as_functype(extern_type));
            break;
        case WASM_EXTERN_GLOBAL:
            wasm_globaltype_delete(wasm_externtype_as_globaltype(extern_type));
            break;
        case WASM_EXTERN_MEMORY:
            wasm_memorytype_delete(wasm_externtype_as_memorytype(extern_type));
            break;
        case WASM_EXTERN_TABLE:
            wasm_tabletype_delete(wasm_externtype_as_tabletype(extern_type));
            break;
        default:
            LOG_WARNING("%s meets unsupported type %u", __FUNCTION__,
                        wasm_externtype_kind(extern_type));
            break;
    }
}

own wasm_importtype_t *
wasm_importtype_new(own wasm_byte_vec_t *module_name,
                    own wasm_byte_vec_t *field_name,
                    own wasm_externtype_t *extern_type)
{
    wasm_importtype_t *import_type = NULL;

    if (!module_name || !field_name || !extern_type) {
        return NULL;
    }

    if (!(import_type = malloc_internal(sizeof(wasm_importtype_t)))) {
        return NULL;
    }

    /* take ownership */
    if (!(import_type->module_name =
              malloc_internal(sizeof(wasm_byte_vec_t)))) {
        goto failed;
    }
    bh_memcpy_s(import_type->module_name, sizeof(wasm_byte_vec_t), module_name,
                sizeof(wasm_byte_vec_t));

    if (!(import_type->name = malloc_internal(sizeof(wasm_byte_vec_t)))) {
        goto failed;
    }
    bh_memcpy_s(import_type->name, sizeof(wasm_byte_vec_t), field_name,
                sizeof(wasm_byte_vec_t));

    import_type->extern_type = extern_type;

    return import_type;
failed:
    wasm_importtype_delete(import_type);
    return NULL;
}

void
wasm_importtype_delete(own wasm_importtype_t *import_type)
{
    if (!import_type) {
        return;
    }

    DEINIT_VEC(import_type->module_name, wasm_byte_vec_delete);
    DEINIT_VEC(import_type->name, wasm_byte_vec_delete);
    wasm_externtype_delete(import_type->extern_type);
    import_type->extern_type = NULL;
    wasm_runtime_free(import_type);
}

own wasm_importtype_t *
wasm_importtype_copy(const wasm_importtype_t *src)
{
    wasm_byte_vec_t module_name = { 0 }, name = { 0 };
    wasm_externtype_t *extern_type = NULL;
    wasm_importtype_t *import_type = NULL;

    if (!src) {
        return NULL;
    }

    wasm_byte_vec_copy(&module_name, src->module_name);
    if (src->module_name->size && !module_name.data) {
        goto failed;
    }

    wasm_byte_vec_copy(&name, src->name);
    if (src->name->size && !name.data) {
        goto failed;
    }

    if (!(extern_type = wasm_externtype_copy(src->extern_type))) {
        goto failed;
    }

    if (!(import_type =
              wasm_importtype_new(&module_name, &name, extern_type))) {
        goto failed;
    }

    return import_type;

failed:
    wasm_byte_vec_delete(&module_name);
    wasm_byte_vec_delete(&name);
    wasm_externtype_delete(extern_type);
    wasm_importtype_delete(import_type);
    return NULL;
}

const wasm_byte_vec_t *
wasm_importtype_module(const wasm_importtype_t *import_type)
{
    if (!import_type) {
        return NULL;
    }

    return import_type->module_name;
}

const wasm_byte_vec_t *
wasm_importtype_name(const wasm_importtype_t *import_type)
{
    if (!import_type) {
        return NULL;
    }

    return import_type->name;
}

const wasm_externtype_t *
wasm_importtype_type(const wasm_importtype_t *import_type)
{
    if (!import_type) {
        return NULL;
    }

    return import_type->extern_type;
}

bool
wasm_importtype_is_linked(const wasm_importtype_t *import_type)
{
    if (!import_type)
        return false;

    const wasm_name_t *module_name = wasm_importtype_module(import_type);
    const wasm_name_t *field_name = wasm_importtype_name(import_type);

    switch (wasm_externtype_kind(wasm_importtype_type(import_type))) {
        case WASM_EXTERN_FUNC:
            return wasm_runtime_is_import_func_linked(module_name->data,
                                                      field_name->data);
        case WASM_EXTERN_GLOBAL:
            return wasm_runtime_is_import_global_linked(module_name->data,
                                                        field_name->data);
        case WASM_EXTERN_MEMORY:
        case WASM_EXTERN_TABLE:
        default:
            break;
    }
    return false;
}

own wasm_exporttype_t *
wasm_exporttype_new(own wasm_byte_vec_t *name,
                    own wasm_externtype_t *extern_type)
{
    wasm_exporttype_t *export_type = NULL;

    if (!name || !extern_type) {
        return NULL;
    }

    if (!(export_type = malloc_internal(sizeof(wasm_exporttype_t)))) {
        return NULL;
    }

    if (!(export_type->name = malloc_internal(sizeof(wasm_byte_vec_t)))) {
        wasm_exporttype_delete(export_type);
        return NULL;
    }
    bh_memcpy_s(export_type->name, sizeof(wasm_byte_vec_t), name,
                sizeof(wasm_byte_vec_t));

    export_type->extern_type = extern_type;

    return export_type;
}

wasm_exporttype_t *
wasm_exporttype_copy(const wasm_exporttype_t *src)
{
    wasm_exporttype_t *export_type;
    wasm_byte_vec_t name = { 0 };
    wasm_externtype_t *extern_type = NULL;

    if (!src) {
        return NULL;
    }

    wasm_byte_vec_copy(&name, src->name);
    if (src->name->size && !name.data) {
        goto failed;
    }

    if (!(extern_type = wasm_externtype_copy(src->extern_type))) {
        goto failed;
    }

    if (!(export_type = wasm_exporttype_new(&name, extern_type))) {
        goto failed;
    }

    return export_type;
failed:
    wasm_byte_vec_delete(&name);
    wasm_externtype_delete(extern_type);
    return NULL;
}

void
wasm_exporttype_delete(wasm_exporttype_t *export_type)
{
    if (!export_type) {
        return;
    }

    DEINIT_VEC(export_type->name, wasm_byte_vec_delete);

    wasm_externtype_delete(export_type->extern_type);

    wasm_runtime_free(export_type);
}

const wasm_byte_vec_t *
wasm_exporttype_name(const wasm_exporttype_t *export_type)
{
    if (!export_type) {
        return NULL;
    }
    return export_type->name;
}

const wasm_externtype_t *
wasm_exporttype_type(const wasm_exporttype_t *export_type)
{
    if (!export_type) {
        return NULL;
    }
    return export_type->extern_type;
}

/* Runtime Objects */
void
wasm_val_delete(wasm_val_t *v)
{
    if (v)
        wasm_runtime_free(v);
}

void
wasm_val_copy(wasm_val_t *out, const wasm_val_t *src)
{
    if (!out || !src) {
        return;
    }

    bh_memcpy_s(out, sizeof(wasm_val_t), src, sizeof(wasm_val_t));
}

bool
rt_val_to_wasm_val(const uint8 *data, uint8 val_type_rt, wasm_val_t *out)
{
    bool ret = true;
    switch (val_type_rt) {
        case VALUE_TYPE_I32:
            out->kind = WASM_I32;
            out->of.i32 = *((int32 *)data);
            break;
        case VALUE_TYPE_F32:
            out->kind = WASM_F32;
            out->of.f32 = *((float32 *)data);
            break;
        case VALUE_TYPE_I64:
            out->kind = WASM_I64;
            out->of.i64 = *((int64 *)data);
            break;
        case VALUE_TYPE_F64:
            out->kind = WASM_F64;
            out->of.f64 = *((float64 *)data);
            break;
        case VALUE_TYPE_V128:
            bh_assert(0);
            break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
        case VALUE_TYPE_EXTERNREF:
            out->kind = WASM_EXTERNREF;
            if (NULL_REF == *(uint32 *)data) {
                out->of.ref = NULL;
            }
            else {
                ret = wasm_externref_ref2obj(*(uint32 *)data,
                                             (void **)&out->of.ref);
            }
            break;
#endif
        default:
            LOG_WARNING("unexpected value type %d", val_type_rt);
            ret = false;
    }
    return ret;
}

bool
wasm_val_to_rt_val(WASMModuleInstanceCommon *inst_comm_rt, uint8 val_type_rt,
                   const wasm_val_t *v, uint8 *data)
{
    bool ret = true;
    switch (val_type_rt) {
        case VALUE_TYPE_I32:
            bh_assert(WASM_I32 == v->kind);
            *((int32 *)data) = v->of.i32;
            break;
        case VALUE_TYPE_F32:
            bh_assert(WASM_F32 == v->kind);
            *((float32 *)data) = v->of.f32;
            break;
        case VALUE_TYPE_I64:
            bh_assert(WASM_I64 == v->kind);
            *((int64 *)data) = v->of.i64;
            break;
        case VALUE_TYPE_F64:
            bh_assert(WASM_F64 == v->kind);
            *((float64 *)data) = v->of.f64;
            break;
        case VALUE_TYPE_V128:
            bh_assert(0);
            break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
        case VALUE_TYPE_EXTERNREF:
            bh_assert(WASM_EXTERNREF == v->kind);
            ret =
                wasm_externref_obj2ref(inst_comm_rt, v->of.ref, (uint32 *)data);
            break;
#endif
        default:
            LOG_WARNING("unexpected value type %d", val_type_rt);
            ret = false;
            break;
    }

    (void)inst_comm_rt;
    return ret;
}

wasm_ref_t *
wasm_ref_new_internal(wasm_store_t *store, enum wasm_reference_kind kind,
                      uint32 ref_idx_rt, WASMModuleInstanceCommon *inst_comm_rt)
{
    wasm_ref_t *ref;

    if (!store) {
        return NULL;
    }

    if (!(ref = malloc_internal(sizeof(wasm_ref_t)))) {
        return NULL;
    }

    ref->store = store;
    ref->kind = kind;
    ref->ref_idx_rt = ref_idx_rt;
    ref->inst_comm_rt = inst_comm_rt;

    /* workaround */
    if (WASM_REF_foreign == kind) {
        wasm_foreign_t *foreign;

        if (!(bh_vector_get(ref->store->foreigns, ref->ref_idx_rt, &foreign))
            || !foreign) {
            wasm_runtime_free(ref);
            return NULL;
        }

        foreign->ref_cnt++;
    }
    /* others doesn't include ref counters */

    return ref;
}

own wasm_ref_t *
wasm_ref_copy(const wasm_ref_t *src)
{
    if (!src)
        return NULL;

    /* host_info are different in wasm_ref_t(s) */
    return wasm_ref_new_internal(src->store, src->kind, src->ref_idx_rt,
                                 src->inst_comm_rt);
}

#define DELETE_HOST_INFO(obj)                              \
    if (obj->host_info.info) {                             \
        if (obj->host_info.finalizer) {                    \
            obj->host_info.finalizer(obj->host_info.info); \
        }                                                  \
    }

void
wasm_ref_delete(own wasm_ref_t *ref)
{
    if (!ref || !ref->store)
        return;

    DELETE_HOST_INFO(ref);

    if (WASM_REF_foreign == ref->kind) {
        wasm_foreign_t *foreign = NULL;

        if (bh_vector_get(ref->store->foreigns, ref->ref_idx_rt, &foreign)
            && foreign) {
            wasm_foreign_delete(foreign);
        }
    }

    wasm_runtime_free(ref);
}

#define WASM_DEFINE_REF_BASE(name)                                          \
    bool wasm_##name##_same(const wasm_##name##_t *o1,                      \
                            const wasm_##name##_t *o2)                      \
    {                                                                       \
        return (!o1 && !o2)   ? true                                        \
               : (!o1 || !o2) ? false                                       \
               : (o1->kind != o2->kind)                                     \
                   ? false                                                  \
                   : o1->name##_idx_rt == o2->name##_idx_rt;                \
    }                                                                       \
                                                                            \
    void *wasm_##name##_get_host_info(const wasm_##name##_t *obj)           \
    {                                                                       \
        return obj ? obj->host_info.info : NULL;                            \
    }                                                                       \
                                                                            \
    void wasm_##name##_set_host_info(wasm_##name##_t *obj, void *host_info) \
    {                                                                       \
        if (obj) {                                                          \
            obj->host_info.info = host_info;                                \
            obj->host_info.finalizer = NULL;                                \
        }                                                                   \
    }                                                                       \
                                                                            \
    void wasm_##name##_set_host_info_with_finalizer(                        \
        wasm_##name##_t *obj, void *host_info, void (*finalizer)(void *))   \
    {                                                                       \
        if (obj) {                                                          \
            obj->host_info.info = host_info;                                \
            obj->host_info.finalizer = finalizer;                           \
        }                                                                   \
    }

#define WASM_DEFINE_REF(name)                                                  \
    WASM_DEFINE_REF_BASE(name)                                                 \
                                                                               \
    wasm_ref_t *wasm_##name##_as_ref(wasm_##name##_t *name)                    \
    {                                                                          \
        if (!name) {                                                           \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_ref_new_internal(name->store, WASM_REF_##name,             \
                                     name->name##_idx_rt, name->inst_comm_rt); \
    }                                                                          \
                                                                               \
    const wasm_ref_t *wasm_##name##_as_ref_const(const wasm_##name##_t *name)  \
    {                                                                          \
        if (!name) {                                                           \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_ref_new_internal(name->store, WASM_REF_##name,             \
                                     name->name##_idx_rt, name->inst_comm_rt); \
    }                                                                          \
                                                                               \
    wasm_##name##_t *wasm_ref_as_##name(wasm_ref_t *ref)                       \
    {                                                                          \
        if (!ref || WASM_REF_##name != ref->kind) {                            \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_##name##_new_internal(ref->store, ref->ref_idx_rt,         \
                                          ref->inst_comm_rt);                  \
    }                                                                          \
                                                                               \
    const wasm_##name##_t *wasm_ref_as_##name##_const(const wasm_ref_t *ref)   \
    {                                                                          \
        if (!ref || WASM_REF_##name != ref->kind) {                            \
            return NULL;                                                       \
        }                                                                      \
                                                                               \
        return wasm_##name##_new_internal(ref->store, ref->ref_idx_rt,         \
                                          ref->inst_comm_rt);                  \
    }

WASM_DEFINE_REF_BASE(ref)
WASM_DEFINE_REF(foreign)
WASM_DEFINE_REF(func)
WASM_DEFINE_REF(global)
WASM_DEFINE_REF(memory)
WASM_DEFINE_REF(table)

static wasm_frame_t *
wasm_frame_new(wasm_instance_t *instance, size_t module_offset,
               uint32 func_index, size_t func_offset)
{
    wasm_frame_t *frame;

    if (!(frame = malloc_internal(sizeof(wasm_frame_t)))) {
        return NULL;
    }

    frame->instance = instance;
    frame->module_offset = (uint32)module_offset;
    frame->func_index = func_index;
    frame->func_offset = (uint32)func_offset;
    return frame;
}

own wasm_frame_t *
wasm_frame_copy(const wasm_frame_t *src)
{
    if (!src) {
        return NULL;
    }

    return wasm_frame_new(src->instance, src->module_offset, src->func_index,
                          src->func_offset);
}

void
wasm_frame_delete(own wasm_frame_t *frame)
{
    if (frame) {
        wasm_runtime_free(frame);
    }
}

struct wasm_instance_t *
wasm_frame_instance(const wasm_frame_t *frame)
{
    return frame ? frame->instance : NULL;
}

size_t
wasm_frame_module_offset(const wasm_frame_t *frame)
{
    return frame ? frame->module_offset : 0;
}

uint32_t
wasm_frame_func_index(const wasm_frame_t *frame)
{
    return frame ? frame->func_index : 0;
}

size_t
wasm_frame_func_offset(const wasm_frame_t *frame)
{
    return frame ? frame->func_offset : 0;
}

void
wasm_frame_vec_clone_internal(Vector *src, Vector *out)
{
    if (src->num_elems == 0) {
        bh_vector_destroy(out);
        return;
    }

    if (!bh_vector_destroy(out)
        || !bh_vector_init(out, src->num_elems, sizeof(WASMCApiFrame), false)) {
        return;
    }

    bh_memcpy_s(out->data, (uint32)(src->num_elems * sizeof(WASMCApiFrame)),
                src->data, (uint32)(src->num_elems * sizeof(WASMCApiFrame)));
    out->num_elems = src->num_elems;
}

static wasm_trap_t *
wasm_trap_new_internal(wasm_store_t *store,
                       WASMModuleInstanceCommon *inst_comm_rt,
                       const char *error_info, Vector *cluster_frames)
{
    wasm_trap_t *trap;
#if WASM_ENABLE_DUMP_CALL_STACK != 0
    wasm_instance_vec_t *instances;
    wasm_instance_t *frame_instance = NULL;
    uint32 i;
#endif

    if (!singleton_engine)
        return NULL;

    if (!(trap = malloc_internal(sizeof(wasm_trap_t)))) {
        return NULL;
    }

    /* fill in message */
    if (error_info && strlen(error_info) > 0) {
        if (!(trap->message = malloc_internal(sizeof(wasm_byte_vec_t)))) {
            goto failed;
        }

        wasm_name_new_from_string_nt(trap->message, error_info);
        if (!trap->message->data) {
            goto failed;
        }
    }

    /* fill in frames */
#if WASM_ENABLE_DUMP_CALL_STACK != 0
    trap->frames = cluster_frames
                       ? cluster_frames
                       : ((WASMModuleInstance *)inst_comm_rt)->frames;

    if (trap->frames) {
        /* fill in instances */
        instances = store->instances;
        bh_assert(instances != NULL);

        for (i = 0; i < instances->num_elems; i++) {
            if (instances->data[i]->inst_comm_rt == inst_comm_rt) {
                frame_instance = instances->data[i];
                break;
            }
        }

        for (i = 0; i < trap->frames->num_elems; i++) {
            (((wasm_frame_t *)trap->frames->data) + i)->instance =
                frame_instance;
        }
    }
#else
    (void)store;
    (void)inst_comm_rt;
#endif /* WASM_ENABLE_DUMP_CALL_STACK != 0 */

    return trap;
failed:
    wasm_trap_delete(trap);
    return NULL;
}

wasm_trap_t *
wasm_trap_new(wasm_store_t *store, const wasm_message_t *message)
{
    wasm_trap_t *trap;

    if (!store) {
        return NULL;
    }

    if (!(trap = malloc_internal(sizeof(wasm_trap_t)))) {
        return NULL;
    }

    if (message) {
        INIT_VEC(trap->message, wasm_byte_vec_new, message->size,
                 message->data);
    }

    return trap;
failed:
    wasm_trap_delete(trap);
    return NULL;
}

void
wasm_trap_delete(wasm_trap_t *trap)
{
    if (!trap) {
        return;
    }

    DEINIT_VEC(trap->message, wasm_byte_vec_delete);
    /* reuse frames of WASMModuleInstance, do not free it here */

    wasm_runtime_free(trap);
}

void
wasm_trap_message(const wasm_trap_t *trap, own wasm_message_t *out)
{
    if (!trap || !out) {
        return;
    }

    wasm_byte_vec_copy(out, trap->message);
}

own wasm_frame_t *
wasm_trap_origin(const wasm_trap_t *trap)
{
    wasm_frame_t *latest_frame;

    if (!trap || !trap->frames || !trap->frames->num_elems) {
        return NULL;
    }

    /* first frame is the latest frame */
    latest_frame = (wasm_frame_t *)trap->frames->data;
    return wasm_frame_copy(latest_frame);
}

void
wasm_trap_trace(const wasm_trap_t *trap, own wasm_frame_vec_t *out)
{
    uint32 i;

    if (!trap || !out) {
        return;
    }

    if (!trap->frames || !trap->frames->num_elems) {
        wasm_frame_vec_new_empty(out);
        return;
    }

    wasm_frame_vec_new_uninitialized(out, trap->frames->num_elems);
    if (out->size == 0 || !out->data) {
        return;
    }

    for (i = 0; i < trap->frames->num_elems; i++) {
        wasm_frame_t *frame = ((wasm_frame_t *)trap->frames->data) + i;
        if (!(out->data[i] =
                  wasm_frame_new(frame->instance, frame->module_offset,
                                 frame->func_index, frame->func_offset))) {
            goto failed;
        }
        out->num_elems++;
    }

    return;
failed:
    for (i = 0; i < out->num_elems; i++) {
        if (out->data[i]) {
            wasm_runtime_free(out->data[i]);
        }
    }

    wasm_runtime_free(out->data);
}

wasm_foreign_t *
wasm_foreign_new_internal(wasm_store_t *store, uint32 foreign_idx_rt,
                          WASMModuleInstanceCommon *inst_comm_rt)
{
    wasm_foreign_t *foreign = NULL;

    if (!store || !store->foreigns)
        return NULL;

    if (!(bh_vector_get(store->foreigns, foreign_idx_rt, &foreign))
        || !foreign) {
        return NULL;
    }

    foreign->ref_cnt++;
    (void)inst_comm_rt;
    return foreign;
}

own wasm_foreign_t *
wasm_foreign_new(wasm_store_t *store)
{
    wasm_foreign_t *foreign;

    if (!store)
        return NULL;

    if (!(foreign = malloc_internal(sizeof(wasm_foreign_t))))
        return NULL;

    foreign->store = store;
    foreign->kind = WASM_REF_foreign;
    foreign->foreign_idx_rt = (uint32)bh_vector_size(store->foreigns);
    if (!(bh_vector_append(store->foreigns, &foreign))) {
        wasm_runtime_free(foreign);
        return NULL;
    }

    return foreign;
}

void
wasm_foreign_delete(wasm_foreign_t *foreign)
{
    if (!foreign)
        return;

    if (foreign->ref_cnt < 1) {
        return;
    }

    foreign->ref_cnt--;
    if (!foreign->ref_cnt) {
        wasm_runtime_free(foreign);
    }
}

static inline wasm_module_t *
module_ext_to_module(wasm_module_ex_t *module_ex)
{
    return (wasm_module_t *)module_ex;
}

static inline wasm_module_ex_t *
module_to_module_ext(wasm_module_t *module)
{
    return (wasm_module_ex_t *)module;
}

#if WASM_ENABLE_INTERP != 0
#define MODULE_INTERP(module_comm) ((WASMModule *)(*module_comm))
#endif

#if WASM_ENABLE_AOT != 0
#define MODULE_AOT(module_comm) ((AOTModule *)(*module_comm))
#endif

#if WASM_ENABLE_WASM_CACHE != 0
static wasm_module_ex_t *
check_loaded_module(Vector *modules, char *binary_hash)
{
    unsigned i;
    wasm_module_ex_t *module = NULL;

    for (i = 0; i < modules->num_elems; i++) {
        bh_vector_get(modules, i, &module);
        if (!module) {
            LOG_ERROR("Unexpected failure at %d\n", __LINE__);
            return NULL;
        }

        if (!module->ref_count)
            /* deleted */
            continue;

        if (memcmp(module->hash, binary_hash, SHA256_DIGEST_LENGTH) == 0)
            return module;
    }
    return NULL;
}

static wasm_module_ex_t *
try_reuse_loaded_module(wasm_store_t *store, char *binary_hash)
{
    wasm_module_ex_t *cached = NULL;
    wasm_module_ex_t *ret = NULL;

    cached = check_loaded_module(&singleton_engine->modules, binary_hash);
    if (!cached)
        goto quit;

    os_mutex_lock(&cached->lock);
    if (!cached->ref_count)
        goto unlock;

    if (!bh_vector_append((Vector *)store->modules, &cached))
        goto unlock;

    cached->ref_count += 1;
    ret = cached;

unlock:
    os_mutex_unlock(&cached->lock);
quit:
    return ret;
}
#endif /* WASM_ENABLE_WASM_CACHE != 0 */

wasm_module_t *
wasm_module_new_ex(wasm_store_t *store, wasm_byte_vec_t *binary, LoadArgs *args)
{
    char error_buf[128] = { 0 };
    wasm_module_ex_t *module_ex = NULL;
#if WASM_ENABLE_WASM_CACHE != 0
    char binary_hash[SHA256_DIGEST_LENGTH] = { 0 };
#endif

    bh_assert(singleton_engine);

    if (!store || !binary || binary->size == 0 || binary->size > UINT32_MAX)
        goto quit;

    /* whether the combination of compilation flags are compatible with the
     * package type */
    {
        PackageType pkg_type;
        pkg_type =
            get_package_type((uint8 *)binary->data, (uint32)binary->size);
        bool result = false;
#if WASM_ENABLE_INTERP != 0
        result = (pkg_type == Wasm_Module_Bytecode);
#endif

#if WASM_ENABLE_AOT != 0
        result = result || (pkg_type == Wasm_Module_AoT);
#endif
        if (!result) {
            LOG_VERBOSE("current building isn't compatible with the module,"
                        "may need recompile");
            goto quit;
        }
    }

#if WASM_ENABLE_WASM_CACHE != 0
    /* if cached */
    SHA256((void *)binary->data, binary->num_elems, (uint8_t *)binary_hash);
    module_ex = try_reuse_loaded_module(store, binary_hash);
    if (module_ex)
        return module_ext_to_module(module_ex);
#endif

    WASM_C_DUMP_PROC_MEM();

    module_ex = malloc_internal(sizeof(wasm_module_ex_t));
    if (!module_ex)
        goto quit;

    module_ex->is_binary_cloned = args->clone_wasm_binary;
    if (args->clone_wasm_binary) {
        module_ex->binary = malloc_internal(sizeof(wasm_byte_vec_t));
        if (!module_ex->binary)
            goto free_module;

        wasm_byte_vec_copy(module_ex->binary, binary);
        if (!module_ex->binary->data)
            goto free_binary;
    }
    else {
        module_ex->binary = binary;
    }

    args->wasm_binary_freeable = !args->clone_wasm_binary;
    module_ex->module_comm_rt = wasm_runtime_load_ex(
        (uint8 *)module_ex->binary->data, (uint32)module_ex->binary->size, args,
        error_buf, (uint32)sizeof(error_buf));
    if (!(module_ex->module_comm_rt)) {
        LOG_ERROR("%s", error_buf);
        goto free_vec;
    }

    /* append it to a watching list in store */
    if (!bh_vector_append((Vector *)store->modules, &module_ex))
        goto unload;

    if (os_mutex_init(&module_ex->lock) != BHT_OK)
        goto remove_last;

    if (!bh_vector_append(&singleton_engine->modules, &module_ex))
        goto destroy_lock;

#if WASM_ENABLE_WASM_CACHE != 0
    bh_memcpy_s(module_ex->hash, sizeof(module_ex->hash), binary_hash,
                sizeof(binary_hash));
#endif

    module_ex->ref_count = 1;

    WASM_C_DUMP_PROC_MEM();

    return module_ext_to_module(module_ex);

destroy_lock:
    os_mutex_destroy(&module_ex->lock);
remove_last:
    bh_vector_remove((Vector *)store->modules,
                     (uint32)(store->modules->num_elems - 1), NULL);
unload:
    wasm_runtime_unload(module_ex->module_comm_rt);
free_vec:
    if (args->clone_wasm_binary)
        wasm_byte_vec_delete(module_ex->binary);
free_binary:
    if (args->clone_wasm_binary)
        wasm_runtime_free(module_ex->binary);
free_module:
    wasm_runtime_free(module_ex);
quit:
    LOG_ERROR("%s failed", __FUNCTION__);
    return NULL;
}

wasm_module_t *
wasm_module_new(wasm_store_t *store, const wasm_byte_vec_t *binary)
{
    LoadArgs args = { 0 };
    args.name = "";
    args.clone_wasm_binary = true;
    return wasm_module_new_ex(store, (wasm_byte_vec_t *)binary, &args);
}

bool
wasm_module_validate(wasm_store_t *store, const wasm_byte_vec_t *binary)
{
    wasm_byte_vec_t local_binary = { 0 };
    struct WASMModuleCommon *module_rt;
    char error_buf[128] = { 0 };
    bool ret;

    bh_assert(singleton_engine);

    if (!store || !binary || binary->size > UINT32_MAX) {
        LOG_ERROR("%s failed", __FUNCTION__);
        return false;
    }

    /* make a copy of binary */
    wasm_byte_vec_copy(&local_binary, binary);

    if (binary->size && !local_binary.data)
        return false;

    module_rt = wasm_runtime_load((uint8 *)local_binary.data,
                                  (uint32)local_binary.size, error_buf, 128);
    wasm_byte_vec_delete(&local_binary);
    if (module_rt) {
        wasm_runtime_unload(module_rt);
        ret = true;
    }
    else {
        ret = false;
        LOG_VERBOSE("%s", error_buf);
    }

    return ret;
}

static void
wasm_module_delete_internal(wasm_module_t *module)
{
    wasm_module_ex_t *module_ex;

    if (!module) {
        return;
    }

    module_ex = module_to_module_ext(module);

    os_mutex_lock(&module_ex->lock);

    /* N -> N-1 -> 0 -> UINT32_MAX */
    module_ex->ref_count--;
    if (module_ex->ref_count > 0) {
        os_mutex_unlock(&module_ex->lock);
        return;
    }

    if (module_ex->is_binary_cloned)
        DEINIT_VEC(module_ex->binary, wasm_byte_vec_delete);

    if (module_ex->module_comm_rt) {
        wasm_runtime_unload(module_ex->module_comm_rt);
        module_ex->module_comm_rt = NULL;
    }

#if WASM_ENABLE_WASM_CACHE != 0
    memset(module_ex->hash, 0, sizeof(module_ex->hash));
#endif

    os_mutex_unlock(&module_ex->lock);
}

void
wasm_module_delete(wasm_module_t *module)
{
    /* the module will be released when releasing the store */
    (void)module;
}

void
wasm_module_imports(const wasm_module_t *module, own wasm_importtype_vec_t *out)
{
    uint32 i, import_func_count = 0, import_memory_count = 0,
              import_global_count = 0, import_table_count = 0, import_count = 0;
    wasm_byte_vec_t module_name = { 0 }, name = { 0 };
    wasm_externtype_t *extern_type = NULL;
    wasm_importtype_t *import_type = NULL;

    if (!module || !out) {
        return;
    }

    if (((const wasm_module_ex_t *)(module))->ref_count == 0)
        return;

#if WASM_ENABLE_INTERP != 0
    if ((*module)->module_type == Wasm_Module_Bytecode) {
        import_func_count = MODULE_INTERP(module)->import_function_count;
        import_global_count = MODULE_INTERP(module)->import_global_count;
        import_memory_count = MODULE_INTERP(module)->import_memory_count;
        import_table_count = MODULE_INTERP(module)->import_table_count;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if ((*module)->module_type == Wasm_Module_AoT) {
        import_func_count = MODULE_AOT(module)->import_func_count;
        import_global_count = MODULE_AOT(module)->import_global_count;
        import_memory_count = MODULE_AOT(module)->import_memory_count;
        import_table_count = MODULE_AOT(module)->import_table_count;
    }
#endif

    import_count = import_func_count + import_global_count + import_table_count
                   + import_memory_count;

    wasm_importtype_vec_new_uninitialized(out, import_count);
    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!out->data) {
        return;
    }

    for (i = 0; i != import_count; ++i) {
        char *module_name_rt = NULL, *field_name_rt = NULL;

        memset(&module_name, 0, sizeof(wasm_val_vec_t));
        memset(&name, 0, sizeof(wasm_val_vec_t));
        extern_type = NULL;
        import_type = NULL;

        if (i < import_func_count) {
            wasm_functype_t *type = NULL;
            WASMFuncType *type_rt = NULL;

#if WASM_ENABLE_INTERP != 0
            if ((*module)->module_type == Wasm_Module_Bytecode) {
                WASMImport *import =
                    MODULE_INTERP(module)->import_functions + i;
                module_name_rt = import->u.names.module_name;
                field_name_rt = import->u.names.field_name;
                type_rt = import->u.function.func_type;
            }
#endif

#if WASM_ENABLE_AOT != 0
            if ((*module)->module_type == Wasm_Module_AoT) {
                AOTImportFunc *import = MODULE_AOT(module)->import_funcs + i;
                module_name_rt = import->module_name;
                field_name_rt = import->func_name;
                type_rt = import->func_type;
            }
#endif

            if (!module_name_rt || !field_name_rt || !type_rt) {
                continue;
            }

            if (!(type = wasm_functype_new_internal(type_rt))) {
                goto failed;
            }

            extern_type = wasm_functype_as_externtype(type);
        }
        else if (i < import_func_count + import_global_count) {
            wasm_globaltype_t *type = NULL;
            uint8 val_type_rt = 0;
            bool mutability_rt = 0;

#if WASM_ENABLE_INTERP != 0
            if ((*module)->module_type == Wasm_Module_Bytecode) {
                WASMImport *import = MODULE_INTERP(module)->import_globals
                                     + (i - import_func_count);
                module_name_rt = import->u.names.module_name;
                field_name_rt = import->u.names.field_name;
                val_type_rt = import->u.global.type.val_type;
                mutability_rt = import->u.global.type.is_mutable;
            }
#endif

#if WASM_ENABLE_AOT != 0
            if ((*module)->module_type == Wasm_Module_AoT) {
                AOTImportGlobal *import = MODULE_AOT(module)->import_globals
                                          + (i - import_func_count);
                module_name_rt = import->module_name;
                field_name_rt = import->global_name;
                val_type_rt = import->type.val_type;
                mutability_rt = import->type.is_mutable;
            }
#endif

            if (!module_name_rt || !field_name_rt) {
                continue;
            }

            if (!(type = wasm_globaltype_new_internal(val_type_rt,
                                                      mutability_rt))) {
                goto failed;
            }

            extern_type = wasm_globaltype_as_externtype(type);
        }
        else if (i < import_func_count + import_global_count
                         + import_memory_count) {
            wasm_memorytype_t *type = NULL;
            uint32 min_page = 0, max_page = 0;

#if WASM_ENABLE_INTERP != 0
            if ((*module)->module_type == Wasm_Module_Bytecode) {
                WASMImport *import =
                    MODULE_INTERP(module)->import_memories
                    + (i - import_func_count - import_global_count);
                module_name_rt = import->u.names.module_name;
                field_name_rt = import->u.names.field_name;
                min_page = import->u.memory.mem_type.init_page_count;
                max_page = import->u.memory.mem_type.max_page_count;
            }
#endif

#if WASM_ENABLE_AOT != 0
            if ((*module)->module_type == Wasm_Module_AoT) {
                AOTImportMemory *import =
                    MODULE_AOT(module)->import_memories
                    + (i - import_func_count - import_global_count);
                module_name_rt = import->module_name;
                field_name_rt = import->memory_name;
                min_page = import->mem_type.init_page_count;
                max_page = import->mem_type.max_page_count;
            }
#endif

            if (!module_name_rt || !field_name_rt) {
                continue;
            }

            if (!(type = wasm_memorytype_new_internal(min_page, max_page))) {
                goto failed;
            }

            extern_type = wasm_memorytype_as_externtype(type);
        }
        else {
            wasm_tabletype_t *type = NULL;
            uint8 elem_type_rt = 0;
            uint32 min_size = 0, max_size = 0;

#if WASM_ENABLE_INTERP != 0
            if ((*module)->module_type == Wasm_Module_Bytecode) {
                WASMImport *import =
                    MODULE_INTERP(module)->import_tables
                    + (i - import_func_count - import_global_count
                       - import_memory_count);
                module_name_rt = import->u.names.module_name;
                field_name_rt = import->u.names.field_name;
                elem_type_rt = import->u.table.table_type.elem_type;
                min_size = import->u.table.table_type.init_size;
                max_size = import->u.table.table_type.max_size;
            }
#endif

#if WASM_ENABLE_AOT != 0
            if ((*module)->module_type == Wasm_Module_AoT) {
                AOTImportTable *import =
                    MODULE_AOT(module)->import_tables
                    + (i - import_func_count - import_global_count
                       - import_memory_count);
                module_name_rt = import->module_name;
                field_name_rt = import->table_name;
                elem_type_rt = import->table_type.elem_type;
                min_size = import->table_type.init_size;
                max_size = import->table_type.max_size;
            }
#endif

            if (!module_name_rt || !field_name_rt) {
                continue;
            }

            if (!(type = wasm_tabletype_new_internal(elem_type_rt, min_size,
                                                     max_size))) {
                goto failed;
            }

            extern_type = wasm_tabletype_as_externtype(type);
        }

        bh_assert(extern_type);

        wasm_name_new_from_string_nt(&module_name, module_name_rt);
        if (strlen(module_name_rt) && !module_name.data) {
            goto failed;
        }

        wasm_name_new_from_string_nt(&name, field_name_rt);
        if (strlen(field_name_rt) && !name.data) {
            goto failed;
        }

        if (!(import_type =
                  wasm_importtype_new(&module_name, &name, extern_type))) {
            goto failed;
        }

        if (!bh_vector_append((Vector *)out, &import_type)) {
            goto failed_importtype_new;
        }

        continue;

    failed:
        wasm_byte_vec_delete(&module_name);
        wasm_byte_vec_delete(&name);
        wasm_externtype_delete(extern_type);
    failed_importtype_new:
        wasm_importtype_delete(import_type);
    }
}

void
wasm_module_exports(const wasm_module_t *module, wasm_exporttype_vec_t *out)
{
    uint32 i, export_count = 0;
    wasm_byte_vec_t name = { 0 };
    wasm_externtype_t *extern_type = NULL;
    wasm_exporttype_t *export_type = NULL;

    if (!module || !out) {
        return;
    }

    if (((const wasm_module_ex_t *)(module))->ref_count == 0)
        return;

#if WASM_ENABLE_INTERP != 0
    if ((*module)->module_type == Wasm_Module_Bytecode) {
        export_count = MODULE_INTERP(module)->export_count;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if ((*module)->module_type == Wasm_Module_AoT) {
        export_count = MODULE_AOT(module)->export_count;
    }
#endif

    wasm_exporttype_vec_new_uninitialized(out, export_count);
    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!out->data) {
        return;
    }

    for (i = 0; i != export_count; i++) {
        WASMExport *export = NULL;
#if WASM_ENABLE_INTERP != 0
        if ((*module)->module_type == Wasm_Module_Bytecode) {
            export = MODULE_INTERP(module)->exports + i;
        }
#endif

#if WASM_ENABLE_AOT != 0
        if ((*module)->module_type == Wasm_Module_AoT) {
            export = MODULE_AOT(module)->exports + i;
        }
#endif

        if (!export) {
            continue;
        }

        /* byte* -> wasm_byte_vec_t */
        wasm_name_new_from_string_nt(&name, export->name);
        if (strlen(export->name) && !name.data) {
            goto failed;
        }

        /* WASMExport -> (WASMFuncType, (uint8, bool)) -> (wasm_functype_t,
         * wasm_globaltype_t) -> wasm_externtype_t*/
        switch (export->kind) {
            case EXPORT_KIND_FUNC:
            {
                wasm_functype_t *type = NULL;
                WASMFuncType *type_rt;

                if (!wasm_runtime_get_export_func_type(*module, export,
                                                       &type_rt)) {
                    goto failed;
                }

                if (!(type = wasm_functype_new_internal(type_rt))) {
                    goto failed;
                }

                extern_type = wasm_functype_as_externtype(type);
                break;
            }
            case EXPORT_KIND_GLOBAL:
            {
                wasm_globaltype_t *type = NULL;
                uint8 val_type_rt = 0;
                bool mutability_rt = 0;

                if (!wasm_runtime_get_export_global_type(
                        *module, export, &val_type_rt, &mutability_rt)) {
                    goto failed;
                }

                if (!(type = wasm_globaltype_new_internal(val_type_rt,
                                                          mutability_rt))) {
                    goto failed;
                }

                extern_type = wasm_globaltype_as_externtype(type);
                break;
            }
            case EXPORT_KIND_MEMORY:
            {
                wasm_memorytype_t *type = NULL;
                uint32 min_page = 0, max_page = 0;

                if (!wasm_runtime_get_export_memory_type(
                        *module, export, &min_page, &max_page)) {
                    goto failed;
                }

                if (!(type =
                          wasm_memorytype_new_internal(min_page, max_page))) {
                    goto failed;
                }

                extern_type = wasm_memorytype_as_externtype(type);
                break;
            }
            case EXPORT_KIND_TABLE:
            {
                wasm_tabletype_t *type = NULL;
                uint8 elem_type_rt = 0;
#if WASM_ENABLE_GC != 0
                WASMRefType *elem_ref_type_rt;
#endif
                uint32 min_size = 0, max_size = 0;

                if (!wasm_runtime_get_export_table_type(*module, export,
                                                        &elem_type_rt,
#if WASM_ENABLE_GC != 0
                                                        &elem_ref_type_rt,
#endif
                                                        &min_size, &max_size)) {
                    goto failed;
                }
#if WASM_ENABLE_GC != 0
                (void)elem_ref_type_rt; /* TODO */
#endif

                if (!(type = wasm_tabletype_new_internal(elem_type_rt, min_size,
                                                         max_size))) {
                    goto failed;
                }

                extern_type = wasm_tabletype_as_externtype(type);
                break;
            }
            default:
            {
                LOG_WARNING("%s meets unsupported type %u", __FUNCTION__,
                            export->kind);
                break;
            }
        }

        if (!(export_type = wasm_exporttype_new(&name, extern_type))) {
            goto failed;
        }

        if (!(bh_vector_append((Vector *)out, &export_type))) {
            goto failed_exporttype_new;
        }
    }

    return;

failed:
    wasm_byte_vec_delete(&name);
    wasm_externtype_delete(extern_type);
failed_exporttype_new:
    wasm_exporttype_delete(export_type);
    wasm_exporttype_vec_delete(out);
}

#if WASM_ENABLE_JIT == 0 || WASM_ENABLE_LAZY_JIT != 0
void
wasm_module_serialize(wasm_module_t *module, own wasm_byte_vec_t *out)
{
    (void)module;
    (void)out;
    LOG_ERROR("only supported serialization in JIT with eager compilation");
}

own wasm_module_t *
wasm_module_deserialize(wasm_store_t *module, const wasm_byte_vec_t *binary)
{
    (void)module;
    (void)binary;
    LOG_ERROR("only supported deserialization in JIT with eager compilation");
    return NULL;
}
#else

extern uint8 *
aot_emit_aot_file_buf(AOTCompContext *comp_ctx, AOTCompData *comp_data,
                      uint32 *p_aot_file_size);
void
wasm_module_serialize(wasm_module_t *module, own wasm_byte_vec_t *out)
{
    wasm_module_ex_t *module_ex;
    AOTCompContext *comp_ctx;
    AOTCompData *comp_data;
    uint8 *aot_file_buf = NULL;
    uint32 aot_file_size = 0;

    if (!module || !out)
        return;

    if (((const wasm_module_ex_t *)(module))->ref_count == 0)
        return;

    module_ex = module_to_module_ext(module);
    comp_ctx = ((WASMModule *)(module_ex->module_comm_rt))->comp_ctx;
    comp_data = ((WASMModule *)(module_ex->module_comm_rt))->comp_data;
    bh_assert(comp_ctx != NULL && comp_data != NULL);

    aot_file_buf = aot_emit_aot_file_buf(comp_ctx, comp_data, &aot_file_size);
    if (!aot_file_buf)
        return;

    wasm_byte_vec_new(out, aot_file_size, (wasm_byte_t *)aot_file_buf);
    wasm_runtime_free(aot_file_buf);
    return;
}

own wasm_module_t *
wasm_module_deserialize(wasm_store_t *store, const wasm_byte_vec_t *binary)
{
    return wasm_module_new(store, binary);
}
#endif

wasm_module_t *
wasm_module_obtain(wasm_store_t *store, wasm_shared_module_t *shared_module)
{
    wasm_module_ex_t *module_ex = NULL;

    if (!store || !shared_module)
        return NULL;

    module_ex = (wasm_module_ex_t *)shared_module;

    os_mutex_lock(&module_ex->lock);

    /* deleting the module... */
    if (module_ex->ref_count == 0) {
        LOG_WARNING("wasm_module_obtain re-enter a module under deleting.");
        os_mutex_unlock(&module_ex->lock);
        return NULL;
    }

    /* add it to a watching list in store */
    if (!bh_vector_append((Vector *)store->modules, &module_ex)) {
        os_mutex_unlock(&module_ex->lock);
        return NULL;
    }

    module_ex->ref_count++;
    os_mutex_unlock(&module_ex->lock);

    return (wasm_module_t *)shared_module;
}

wasm_shared_module_t *
wasm_module_share(wasm_module_t *module)
{
    wasm_module_ex_t *module_ex = NULL;

    if (!module)
        return NULL;

    module_ex = (wasm_module_ex_t *)module;

    os_mutex_lock(&module_ex->lock);

    /* deleting the module... */
    if (module_ex->ref_count == 0) {
        LOG_WARNING("wasm_module_share re-enter a module under deleting.");
        os_mutex_unlock(&module_ex->lock);
        return NULL;
    }

    module_ex->ref_count++;

    os_mutex_unlock(&module_ex->lock);

    return (wasm_shared_module_t *)module;
}

void
wasm_shared_module_delete(own wasm_shared_module_t *shared_module)
{
    wasm_module_delete_internal((wasm_module_t *)shared_module);
}

bool
wasm_module_set_name(wasm_module_t *module, const char *name)
{
    char error_buf[256] = { 0 };
    wasm_module_ex_t *module_ex = NULL;

    if (!module)
        return false;

    module_ex = module_to_module_ext(module);
    bool ret = wasm_runtime_set_module_name(module_ex->module_comm_rt, name,
                                            error_buf, sizeof(error_buf) - 1);
    if (!ret)
        LOG_WARNING("set module name failed: %s", error_buf);
    return ret;
}

const char *
wasm_module_get_name(wasm_module_t *module)
{
    wasm_module_ex_t *module_ex = NULL;
    if (!module)
        return "";

    module_ex = module_to_module_ext(module);
    return wasm_runtime_get_module_name(module_ex->module_comm_rt);
}

bool
wasm_module_is_underlying_binary_freeable(const wasm_module_t *module)
{
    if (((wasm_module_ex_t *)module)->is_binary_cloned)
        return true;

    return wasm_runtime_is_underlying_binary_freeable(*module);
}

static wasm_func_t *
wasm_func_new_basic(wasm_store_t *store, const wasm_functype_t *type,
                    wasm_func_callback_t func_callback)
{
    wasm_func_t *func = NULL;

    if (!type) {
        goto failed;
    }

    if (!(func = malloc_internal(sizeof(wasm_func_t)))) {
        goto failed;
    }

    func->store = store;
    func->kind = WASM_EXTERN_FUNC;
    func->func_idx_rt = (uint16)-1;
    func->with_env = false;
    func->u.cb = func_callback;

    if (!(func->type = wasm_functype_copy(type))) {
        goto failed;
    }
    /* func type's param_count and result_count were checked in
       loader and are no larger than UINT16_MAX */
    func->param_count = (uint16)func->type->params->num_elems;
    func->result_count = (uint16)func->type->results->num_elems;

    RETURN_OBJ(func, wasm_func_delete)
}

static wasm_func_t *
wasm_func_new_with_env_basic(wasm_store_t *store, const wasm_functype_t *type,
                             wasm_func_callback_with_env_t callback, void *env,
                             void (*finalizer)(void *))
{
    wasm_func_t *func = NULL;

    if (!type) {
        goto failed;
    }

    if (!(func = malloc_internal(sizeof(wasm_func_t)))) {
        goto failed;
    }

    func->store = store;
    func->kind = WASM_EXTERN_FUNC;
    func->func_idx_rt = (uint16)-1;
    func->with_env = true;
    func->u.cb_env.cb = callback;
    func->u.cb_env.env = env;
    func->u.cb_env.finalizer = finalizer;

    if (!(func->type = wasm_functype_copy(type))) {
        goto failed;
    }
    /* func type's param_count and result_count were checked in
       loader and are no larger than UINT16_MAX */
    func->param_count = (uint16)func->type->params->num_elems;
    func->result_count = (uint16)func->type->results->num_elems;

    RETURN_OBJ(func, wasm_func_delete)
}

wasm_func_t *
wasm_func_new(wasm_store_t *store, const wasm_functype_t *type,
              wasm_func_callback_t callback)
{
    bh_assert(singleton_engine);
    if (!callback) {
        return NULL;
    }
    return wasm_func_new_basic(store, type, callback);
}

wasm_func_t *
wasm_func_new_with_env(wasm_store_t *store, const wasm_functype_t *type,
                       wasm_func_callback_with_env_t callback, void *env,
                       void (*finalizer)(void *))
{
    bh_assert(singleton_engine);
    if (!callback) {
        return NULL;
    }
    return wasm_func_new_with_env_basic(store, type, callback, env, finalizer);
}

wasm_func_t *
wasm_func_new_internal(wasm_store_t *store, uint16 func_idx_rt,
                       WASMModuleInstanceCommon *inst_comm_rt)
{
    wasm_func_t *func = NULL;
    WASMFuncType *type_rt = NULL;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return NULL;
    }

    func = malloc_internal(sizeof(wasm_func_t));
    if (!func) {
        goto failed;
    }

    func->kind = WASM_EXTERN_FUNC;

#if WASM_ENABLE_INTERP != 0
    if (inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        bh_assert(func_idx_rt
                  < ((WASMModuleInstance *)inst_comm_rt)->e->function_count);
        WASMFunctionInstance *func_interp =
            ((WASMModuleInstance *)inst_comm_rt)->e->functions + func_idx_rt;
        type_rt = func_interp->is_import_func
                      ? func_interp->u.func_import->func_type
                      : func_interp->u.func->func_type;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (inst_comm_rt->module_type == Wasm_Module_AoT) {
        /* use same index to trace the function type in AOTFuncType **func_types
         */
        AOTModule *module_aot =
            (AOTModule *)((AOTModuleInstance *)inst_comm_rt)->module;
        if (func_idx_rt < module_aot->import_func_count) {
            type_rt = (module_aot->import_funcs + func_idx_rt)->func_type;
        }
        else {
            type_rt =
                (AOTFuncType *)module_aot
                    ->types[module_aot->func_type_indexes
                                [func_idx_rt - module_aot->import_func_count]];
        }
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!type_rt) {
        goto failed;
    }

    func->type = wasm_functype_new_internal(type_rt);
    if (!func->type) {
        goto failed;
    }
    /* func type's param_count and result_count were checked in
       loader and are no larger than UINT16_MAX */
    func->param_count = (uint16)func->type->params->num_elems;
    func->result_count = (uint16)func->type->results->num_elems;

    /* will add name information when processing "exports" */
    func->store = store;
    func->module_name = NULL;
    func->name = NULL;
    func->func_idx_rt = func_idx_rt;
    func->inst_comm_rt = inst_comm_rt;
    return func;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_func_delete(func);
    return NULL;
}

static wasm_func_t *
wasm_func_new_empty(wasm_store_t *store)
{
    wasm_func_t *func = NULL;

    if (!(func = malloc_internal(sizeof(wasm_func_t))))
        goto failed;

    func->store = store;
    func->kind = WASM_EXTERN_FUNC;

    RETURN_OBJ(func, wasm_func_delete)
}

void
wasm_func_delete(wasm_func_t *func)
{
    if (!func) {
        return;
    }

    if (func->type) {
        wasm_functype_delete(func->type);
        func->type = NULL;
    }

    if (func->with_env) {
        if (func->u.cb_env.finalizer) {
            func->u.cb_env.finalizer(func->u.cb_env.env);
            func->u.cb_env.finalizer = NULL;
            func->u.cb_env.env = NULL;
        }
    }

    DELETE_HOST_INFO(func)

    wasm_runtime_free(func);
}

own wasm_func_t *
wasm_func_copy(const wasm_func_t *func)
{
    wasm_func_t *cloned = NULL;

    if (!func) {
        return NULL;
    }

    if (!(cloned = func->with_env ? wasm_func_new_with_env_basic(
                       func->store, func->type, func->u.cb_env.cb,
                       func->u.cb_env.env, func->u.cb_env.finalizer)
                                  : wasm_func_new_basic(func->store, func->type,
                                                        func->u.cb))) {
        goto failed;
    }

    cloned->func_idx_rt = func->func_idx_rt;
    cloned->inst_comm_rt = func->inst_comm_rt;

    RETURN_OBJ(cloned, wasm_func_delete)
}

own wasm_functype_t *
wasm_func_type(const wasm_func_t *func)
{
    if (!func) {
        return NULL;
    }
    return wasm_functype_copy(func->type);
}

static bool
params_to_argv(const wasm_val_vec_t *params,
               const wasm_valtype_vec_t *param_defs, uint32 *argv,
               uint32 *ptr_argc)
{
    uint32 *argv_org = argv;
    const wasm_val_t *param, *param_end;

    bh_assert(params && params->num_elems && params->size && params->data);

    param = params->data;
    param_end = param + param_defs->num_elems;

    for (; param < param_end; param++) {
        switch (param->kind) {
            case WASM_I32:
            case WASM_F32:
                *(int32 *)argv = param->of.i32;
                argv += 1;
                break;
            case WASM_I64:
            case WASM_F64:
                *(int64 *)argv = param->of.i64;
                argv += 2;
                break;
            case WASM_V128:
                bh_assert(0);
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case WASM_EXTERNREF:
                *(uintptr_t *)argv = (uintptr_t)param->of.ref;
                argv += sizeof(uintptr_t) / sizeof(uint32);
                break;
#endif
            default:
                LOG_WARNING("unexpected parameter val type %d", param->kind);
                return false;
        }
    }

    *ptr_argc = (uint32)(argv - argv_org);
    return true;
}

static bool
argv_to_results(const uint32 *argv, const wasm_valtype_vec_t *result_defs,
                wasm_val_vec_t *results)
{
    wasm_valtype_t **result_def, **result_def_end;
    wasm_val_t *result;

    bh_assert(results && results->size && results->data);

    result_def = result_defs->data;
    result_def_end = result_def + result_defs->num_elems;
    result = results->data;

    for (; result_def < result_def_end; result_def++, result++) {
        result->kind = result_def[0]->kind;
        switch (result->kind) {
            case WASM_I32:
            case WASM_F32:
                result->of.i32 = *(int32 *)argv;
                argv += 1;
                break;
            case WASM_I64:
            case WASM_F64:
                result->of.i64 = *(int64 *)argv;
                argv += 2;
                break;
            case WASM_V128:
                bh_assert(0);
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case WASM_EXTERNREF:
            case WASM_FUNCREF:
                result->of.ref = (struct wasm_ref_t *)(*(uintptr_t *)argv);
                argv += sizeof(uintptr_t) / sizeof(uint32);
                break;
#endif
            default:
                LOG_WARNING("%s meets unsupported type: %d", __FUNCTION__,
                            result->kind);
                return false;
        }
    }

    return true;
}

wasm_trap_t *
wasm_func_call(const wasm_func_t *func, const wasm_val_vec_t *params,
               wasm_val_vec_t *results)
{
    /* parameters count as if all are uint32 */
    /* a int64 or float64 parameter means 2 */
    uint32 argc = 0;
    /* a parameter list and a return value list */
    uint32 argv_buf[32] = { 0 }, *argv = argv_buf;
    WASMFunctionInstanceCommon *func_comm_rt = NULL;
    WASMExecEnv *exec_env = NULL;
    size_t param_count, result_count, alloc_count;
    Vector *cluster_frames = NULL;

    bh_assert(func && func->type);

    if (!func->inst_comm_rt) {
        wasm_name_t message = { 0 };
        wasm_trap_t *trap;

        wasm_name_new_from_string_nt(&message,
                                     "failed to call unlinked function");
        trap = wasm_trap_new(func->store, &message);
        wasm_byte_vec_delete(&message);

        return trap;
    }

    if (func->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
#if WASM_ENABLE_INTERP != 0
        func_comm_rt = ((WASMModuleInstance *)func->inst_comm_rt)->e->functions
                       + func->func_idx_rt;
#endif
    }
    else if (func->inst_comm_rt->module_type == Wasm_Module_AoT) {
#if WASM_ENABLE_AOT != 0
        if (!(func_comm_rt = func->func_comm_rt)) {
            AOTModuleInstance *inst_aot =
                (AOTModuleInstance *)func->inst_comm_rt;
            func_comm_rt = ((wasm_func_t *)func)->func_comm_rt =
                aot_lookup_function_with_idx(inst_aot, func->func_idx_rt);
        }
#endif
    }

    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (!func_comm_rt) {
        goto failed;
    }

    param_count = wasm_func_param_arity(func);
    result_count = wasm_func_result_arity(func);

    alloc_count = (param_count > result_count) ? param_count : result_count;
    if (alloc_count > (size_t)sizeof(argv_buf) / sizeof(uint64)) {
        if (!(argv = malloc_internal(sizeof(uint64) * alloc_count))) {
            goto failed;
        }
    }

    /* copy parameters */
    if (param_count
        && !params_to_argv(params, wasm_functype_params(func->type), argv,
                           &argc)) {
        goto failed;
    }

#ifdef OS_ENABLE_HW_BOUND_CHECK
    exec_env = wasm_runtime_get_exec_env_tls();
#endif
#if WASM_ENABLE_THREAD_MGR != 0
    if (!exec_env) {
        exec_env = wasm_clusters_search_exec_env(func->inst_comm_rt);
    }
#endif
    if (!exec_env) {
        exec_env = wasm_runtime_get_exec_env_singleton(func->inst_comm_rt);
    }
    if (!exec_env) {
        goto failed;
    }

    wasm_runtime_set_exception(func->inst_comm_rt, NULL);
    if (!wasm_runtime_call_wasm(exec_env, func_comm_rt, argc, argv)) {
        if (wasm_runtime_get_exception(func->inst_comm_rt)) {
            LOG_DEBUG("%s", wasm_runtime_get_exception(func->inst_comm_rt));
            goto failed;
        }
    }

    /* copy results */
    if (result_count) {
        if (!argv_to_results(argv, wasm_functype_results(func->type),
                             results)) {
            wasm_runtime_set_exception(func->inst_comm_rt,
                                       "argv_to_results failed");
            goto failed;
        }
        results->num_elems = result_count;
        results->size = result_count;
    }

    if (argv != argv_buf)
        wasm_runtime_free(argv);
    return NULL;

failed:
    if (argv != argv_buf)
        wasm_runtime_free(argv);

#if WASM_ENABLE_DUMP_CALL_STACK != 0 && WASM_ENABLE_THREAD_MGR != 0
    WASMCluster *cluster = wasm_exec_env_get_cluster(exec_env);
    cluster_frames = &cluster->exception_frames;
    wasm_cluster_traverse_lock(exec_env);
#endif

    wasm_trap_t *trap = wasm_trap_new_internal(
        func->store, func->inst_comm_rt,
        wasm_runtime_get_exception(func->inst_comm_rt), cluster_frames);

#if WASM_ENABLE_DUMP_CALL_STACK != 0 && WASM_ENABLE_THREAD_MGR != 0
    wasm_cluster_traverse_unlock(exec_env);
#endif
    return trap;
}

size_t
wasm_func_param_arity(const wasm_func_t *func)
{
    return func->param_count;
}

size_t
wasm_func_result_arity(const wasm_func_t *func)
{
    return func->result_count;
}

wasm_global_t *
wasm_global_new(wasm_store_t *store, const wasm_globaltype_t *global_type,
                const wasm_val_t *init)
{
    wasm_global_t *global = NULL;

    bh_assert(singleton_engine);

    if (!global_type || !init) {
        goto failed;
    }

    global = malloc_internal(sizeof(wasm_global_t));
    if (!global) {
        goto failed;
    }

    global->store = store;
    global->kind = WASM_EXTERN_GLOBAL;
    global->type = wasm_globaltype_copy(global_type);
    if (!global->type) {
        goto failed;
    }

    global->init = malloc_internal(sizeof(wasm_val_t));
    if (!global->init) {
        goto failed;
    }

    wasm_val_copy(global->init, init);
    /* TODO: how to check if above is failed */

    return global;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_global_delete(global);
    return NULL;
}

static wasm_global_t *
wasm_global_new_empty(wasm_store_t *store)
{
    wasm_global_t *global = NULL;

    global = malloc_internal(sizeof(wasm_global_t));
    if (!global)
        goto failed;

    global->store = store;
    global->kind = WASM_EXTERN_GLOBAL;

    return global;
failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_global_delete(global);
    return NULL;
}

/* almost same with wasm_global_new */
wasm_global_t *
wasm_global_copy(const wasm_global_t *src)
{
    wasm_global_t *global = NULL;

    if (!src) {
        return NULL;
    }

    global = malloc_internal(sizeof(wasm_global_t));
    if (!global) {
        goto failed;
    }

    global->kind = WASM_EXTERN_GLOBAL;
    global->type = wasm_globaltype_copy(src->type);
    if (!global->type) {
        goto failed;
    }

    global->init = malloc_internal(sizeof(wasm_val_t));
    if (!global->init) {
        goto failed;
    }

    wasm_val_copy(global->init, src->init);

    global->global_idx_rt = src->global_idx_rt;
    global->inst_comm_rt = src->inst_comm_rt;

    return global;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_global_delete(global);
    return NULL;
}

void
wasm_global_delete(wasm_global_t *global)
{
    if (!global) {
        return;
    }

    if (global->init) {
        wasm_val_delete(global->init);
        global->init = NULL;
    }

    if (global->type) {
        wasm_globaltype_delete(global->type);
        global->type = NULL;
    }

    DELETE_HOST_INFO(global)

    wasm_runtime_free(global);
}

#if WASM_ENABLE_INTERP != 0
static bool
interp_global_set(const WASMModuleInstance *inst_interp, uint16 global_idx_rt,
                  const wasm_val_t *v)
{
    const WASMGlobalInstance *global_interp =
        inst_interp->e->globals + global_idx_rt;
    uint8 val_type_rt = global_interp->type;
#if WASM_ENABLE_MULTI_MODULE != 0
    uint8 *data = global_interp->import_global_inst
                      ? global_interp->import_module_inst->global_data
                            + global_interp->import_global_inst->data_offset
                      : inst_interp->global_data + global_interp->data_offset;
#else
    uint8 *data = inst_interp->global_data + global_interp->data_offset;
#endif

    return wasm_val_to_rt_val((WASMModuleInstanceCommon *)inst_interp,
                              val_type_rt, v, data);
}

static bool
interp_global_get(const WASMModuleInstance *inst_interp, uint16 global_idx_rt,
                  wasm_val_t *out)
{
    WASMGlobalInstance *global_interp = inst_interp->e->globals + global_idx_rt;
    uint8 val_type_rt = global_interp->type;
#if WASM_ENABLE_MULTI_MODULE != 0
    uint8 *data = global_interp->import_global_inst
                      ? global_interp->import_module_inst->global_data
                            + global_interp->import_global_inst->data_offset
                      : inst_interp->global_data + global_interp->data_offset;
#else
    uint8 *data = inst_interp->global_data + global_interp->data_offset;
#endif

    return rt_val_to_wasm_val(data, val_type_rt, out);
}
#endif

#if WASM_ENABLE_AOT != 0
static bool
aot_global_set(const AOTModuleInstance *inst_aot, uint16 global_idx_rt,
               const wasm_val_t *v)
{
    AOTModule *module_aot = (AOTModule *)inst_aot->module;
    uint8 val_type_rt = 0;
    uint32 data_offset = 0;
    void *data = NULL;

    if (global_idx_rt < module_aot->import_global_count) {
        data_offset = module_aot->import_globals[global_idx_rt].data_offset;
        val_type_rt = module_aot->import_globals[global_idx_rt].type.val_type;
    }
    else {
        data_offset =
            module_aot->globals[global_idx_rt - module_aot->import_global_count]
                .data_offset;
        val_type_rt =
            module_aot->globals[global_idx_rt - module_aot->import_global_count]
                .type.val_type;
    }

    data = (void *)(inst_aot->global_data + data_offset);
    return wasm_val_to_rt_val((WASMModuleInstanceCommon *)inst_aot, val_type_rt,
                              v, data);
}

static bool
aot_global_get(const AOTModuleInstance *inst_aot, uint16 global_idx_rt,
               wasm_val_t *out)
{
    AOTModule *module_aot = (AOTModule *)inst_aot->module;
    uint8 val_type_rt = 0;
    uint32 data_offset = 0;
    uint8 *data = NULL;

    if (global_idx_rt < module_aot->import_global_count) {
        data_offset = module_aot->import_globals[global_idx_rt].data_offset;
        val_type_rt = module_aot->import_globals[global_idx_rt].type.val_type;
    }
    else {
        data_offset =
            module_aot->globals[global_idx_rt - module_aot->import_global_count]
                .data_offset;
        val_type_rt =
            module_aot->globals[global_idx_rt - module_aot->import_global_count]
                .type.val_type;
    }

    data = inst_aot->global_data + data_offset;
    return rt_val_to_wasm_val(data, val_type_rt, out);
}
#endif

void
wasm_global_set(wasm_global_t *global, const wasm_val_t *v)
{
    if (!global || !v || !global->inst_comm_rt) {
        return;
    }

#if WASM_ENABLE_INTERP != 0
    if (global->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        (void)interp_global_set((WASMModuleInstance *)global->inst_comm_rt,
                                global->global_idx_rt, v);
        return;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (global->inst_comm_rt->module_type == Wasm_Module_AoT) {
        (void)aot_global_set((AOTModuleInstance *)global->inst_comm_rt,
                             global->global_idx_rt, v);
        return;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    UNREACHABLE();
}

void
wasm_global_get(const wasm_global_t *global, wasm_val_t *out)
{
    if (!global || !out) {
        return;
    }

    if (!global->inst_comm_rt) {
        return;
    }

    memset(out, 0, sizeof(wasm_val_t));

#if WASM_ENABLE_INTERP != 0
    if (global->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        (void)interp_global_get((WASMModuleInstance *)global->inst_comm_rt,
                                global->global_idx_rt, out);
        return;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (global->inst_comm_rt->module_type == Wasm_Module_AoT) {
        (void)aot_global_get((AOTModuleInstance *)global->inst_comm_rt,
                             global->global_idx_rt, out);
        return;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    UNREACHABLE();
}

wasm_global_t *
wasm_global_new_internal(wasm_store_t *store, uint16 global_idx_rt,
                         WASMModuleInstanceCommon *inst_comm_rt)
{
    wasm_global_t *global = NULL;
    uint8 val_type_rt = 0;
    bool is_mutable = 0;
    bool init = false;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return NULL;
    }

    global = malloc_internal(sizeof(wasm_global_t));
    if (!global) {
        goto failed;
    }

    global->store = store;
    global->kind = WASM_EXTERN_GLOBAL;

#if WASM_ENABLE_INTERP != 0
    if (inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        WASMGlobalInstance *global_interp =
            ((WASMModuleInstance *)inst_comm_rt)->e->globals + global_idx_rt;
        val_type_rt = global_interp->type;
        is_mutable = global_interp->is_mutable;
        init = true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (inst_comm_rt->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *inst_aot = (AOTModuleInstance *)inst_comm_rt;
        AOTModule *module_aot = (AOTModule *)inst_aot->module;

        init = true;

        if (global_idx_rt < module_aot->import_global_count) {
            AOTImportGlobal *global_import_aot =
                module_aot->import_globals + global_idx_rt;
            val_type_rt = global_import_aot->type.val_type;
            is_mutable = global_import_aot->type.is_mutable;
        }
        else {
            AOTGlobal *global_aot =
                module_aot->globals
                + (global_idx_rt - module_aot->import_global_count);
            val_type_rt = global_aot->type.val_type;
            is_mutable = global_aot->type.is_mutable;
        }
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!init) {
        goto failed;
    }

    global->type = wasm_globaltype_new_internal(val_type_rt, is_mutable);
    if (!global->type) {
        goto failed;
    }

    global->init = malloc_internal(sizeof(wasm_val_t));
    if (!global->init) {
        goto failed;
    }

#if WASM_ENABLE_INTERP != 0
    if (inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        interp_global_get((WASMModuleInstance *)inst_comm_rt, global_idx_rt,
                          global->init);
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (inst_comm_rt->module_type == Wasm_Module_AoT) {
        aot_global_get((AOTModuleInstance *)inst_comm_rt, global_idx_rt,
                       global->init);
    }
#endif

    global->inst_comm_rt = inst_comm_rt;
    global->global_idx_rt = global_idx_rt;

    return global;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_global_delete(global);
    return NULL;
}

wasm_globaltype_t *
wasm_global_type(const wasm_global_t *global)
{
    if (!global) {
        return NULL;
    }
    return wasm_globaltype_copy(global->type);
}

static wasm_table_t *
wasm_table_new_basic(wasm_store_t *store, const wasm_tabletype_t *type)
{
    wasm_table_t *table = NULL;

    if (!(table = malloc_internal(sizeof(wasm_table_t)))) {
        goto failed;
    }

    table->store = store;
    table->kind = WASM_EXTERN_TABLE;

    if (!(table->type = wasm_tabletype_copy(type))) {
        goto failed;
    }

    RETURN_OBJ(table, wasm_table_delete);
}

wasm_table_t *
wasm_table_new_internal(wasm_store_t *store, uint16 table_idx_rt,
                        WASMModuleInstanceCommon *inst_comm_rt)
{
    wasm_table_t *table = NULL;
    uint8 val_type_rt = 0;
#if WASM_ENABLE_GC != 0
    WASMRefType *val_ref_type_rt;
#endif
    uint32 init_size = 0, max_size = 0;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return NULL;
    }

    if (!(table = malloc_internal(sizeof(wasm_table_t)))) {
        goto failed;
    }

    table->store = store;
    table->kind = WASM_EXTERN_TABLE;

    if (!wasm_runtime_get_table_inst_elem_type(inst_comm_rt, table_idx_rt,
                                               &val_type_rt,
#if WASM_ENABLE_GC != 0
                                               &val_ref_type_rt,
#endif
                                               &init_size, &max_size)) {
        /*
         * a wrong combination of module filetype and compilation flags
         * leads to below branch
         */
        goto failed;
    }
#if WASM_ENABLE_GC != 0
    (void)val_ref_type_rt; /* TODO */
#endif

    if (!(table->type =
              wasm_tabletype_new_internal(val_type_rt, init_size, max_size))) {
        goto failed;
    }

    table->inst_comm_rt = inst_comm_rt;
    table->table_idx_rt = table_idx_rt;

    RETURN_OBJ(table, wasm_table_delete);
}

/* will not actually apply this new table into the runtime */
wasm_table_t *
wasm_table_new(wasm_store_t *store, const wasm_tabletype_t *table_type,
               wasm_ref_t *init)
{
    wasm_table_t *table;
    (void)init;

    bh_assert(singleton_engine);

    if ((table = wasm_table_new_basic(store, table_type))) {
        table->store = store;
    }

    return table;
}

wasm_table_t *
wasm_table_copy(const wasm_table_t *src)
{
    wasm_table_t *table;

    if (!(table = wasm_table_new_basic(src->store, src->type))) {
        return NULL;
    }

    table->table_idx_rt = src->table_idx_rt;
    table->inst_comm_rt = src->inst_comm_rt;
    return table;
}

void
wasm_table_delete(wasm_table_t *table)
{
    if (!table) {
        return;
    }

    if (table->type) {
        wasm_tabletype_delete(table->type);
        table->type = NULL;
    }

    DELETE_HOST_INFO(table)

    wasm_runtime_free(table);
}

wasm_tabletype_t *
wasm_table_type(const wasm_table_t *table)
{
    if (!table) {
        return NULL;
    }
    return wasm_tabletype_copy(table->type);
}

#if WASM_ENABLE_GC == 0
own wasm_ref_t *
wasm_table_get(const wasm_table_t *table, wasm_table_size_t index)
{
    uint32 ref_idx = NULL_REF;

    if (!table || !table->inst_comm_rt) {
        return NULL;
    }

#if WASM_ENABLE_INTERP != 0
    if (table->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        WASMTableInstance *table_interp =
            ((WASMModuleInstance *)table->inst_comm_rt)
                ->tables[table->table_idx_rt];
        if (index >= table_interp->cur_size) {
            return NULL;
        }
        ref_idx = (uint32)table_interp->elems[index];
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (table->inst_comm_rt->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *inst_aot = (AOTModuleInstance *)table->inst_comm_rt;
        AOTTableInstance *table_aot = inst_aot->tables[table->table_idx_rt];
        if (index >= table_aot->cur_size) {
            return NULL;
        }
        ref_idx = (uint32)table_aot->elems[index];
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * also leads to below branch
     */
    if (ref_idx == NULL_REF) {
        return NULL;
    }

#if WASM_ENABLE_REF_TYPES != 0
    if (table->type->val_type->kind == WASM_EXTERNREF) {
        void *externref_obj;
        if (!wasm_externref_ref2obj(ref_idx, &externref_obj)) {
            return NULL;
        }

        return externref_obj;
    }
    else
#endif
    {
        return wasm_ref_new_internal(table->store, WASM_REF_func, ref_idx,
                                     table->inst_comm_rt);
    }
}

bool
wasm_table_set(wasm_table_t *table, wasm_table_size_t index,
               own wasm_ref_t *ref)
{
    uint32 *p_ref_idx = NULL;
    uint32 function_count = 0;

    if (!table || !table->inst_comm_rt) {
        return false;
    }

    if (ref
#if WASM_ENABLE_REF_TYPES != 0
        && !(WASM_REF_foreign == ref->kind
             && WASM_EXTERNREF == table->type->val_type->kind)
#endif
        && !(WASM_REF_func == ref->kind
             && WASM_FUNCREF == table->type->val_type->kind)) {
        return false;
    }

#if WASM_ENABLE_INTERP != 0
    if (table->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        WASMTableInstance *table_interp =
            ((WASMModuleInstance *)table->inst_comm_rt)
                ->tables[table->table_idx_rt];

        if (index >= table_interp->cur_size) {
            return false;
        }

        p_ref_idx = (uint32 *)(table_interp->elems + index);
        function_count =
            ((WASMModuleInstance *)table->inst_comm_rt)->e->function_count;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (table->inst_comm_rt->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *inst_aot = (AOTModuleInstance *)table->inst_comm_rt;
        AOTModule *module_aot = (AOTModule *)inst_aot->module;
        AOTTableInstance *table_aot = inst_aot->tables[table->table_idx_rt];

        if (index >= table_aot->cur_size) {
            return false;
        }

        p_ref_idx = (uint32 *)(table_aot->elems + index);
        function_count = module_aot->func_count;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!p_ref_idx) {
        return false;
    }

#if WASM_ENABLE_REF_TYPES != 0
    if (table->type->val_type->kind == WASM_EXTERNREF) {
        return wasm_externref_obj2ref(table->inst_comm_rt, ref, p_ref_idx);
    }
    else
#endif
    {
        if (ref) {
            if (NULL_REF != ref->ref_idx_rt) {
                if (ref->ref_idx_rt >= function_count) {
                    return false;
                }
            }
            *p_ref_idx = ref->ref_idx_rt;
            wasm_ref_delete(ref);
        }
        else {
            *p_ref_idx = NULL_REF;
        }
    }

    return true;
}
#else  /* else of WASM_ENABLE_GC == 0 */
own wasm_ref_t *
wasm_table_get(const wasm_table_t *table, wasm_table_size_t index)
{
    /* TODO */
    return NULL;
}

bool
wasm_table_set(wasm_table_t *table, wasm_table_size_t index,
               own wasm_ref_t *ref)
{
    /* TODO */
    return false;
}
#endif /* end of WASM_ENABLE_GC == 0 */

wasm_table_size_t
wasm_table_size(const wasm_table_t *table)
{
    if (!table || !table->inst_comm_rt) {
        return 0;
    }

#if WASM_ENABLE_INTERP != 0
    if (table->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        WASMTableInstance *table_interp =
            ((WASMModuleInstance *)table->inst_comm_rt)
                ->tables[table->table_idx_rt];
        return table_interp->cur_size;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (table->inst_comm_rt->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *inst_aot = (AOTModuleInstance *)table->inst_comm_rt;
        AOTModule *module_aot = (AOTModule *)inst_aot->module;

        if (table->table_idx_rt < module_aot->import_table_count) {
            AOTImportTable *table_aot =
                module_aot->import_tables + table->table_idx_rt;
            return table_aot->table_type.init_size;
        }
        else {
            AOTTable *table_aot =
                module_aot->tables
                + (table->table_idx_rt - module_aot->import_table_count);
            return table_aot->table_type.init_size;
        }
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return 0;
}

bool
wasm_table_grow(wasm_table_t *table, wasm_table_size_t delta,
                own wasm_ref_t *init)
{
    (void)table;
    (void)delta;
    (void)init;
    LOG_WARNING("Calling wasm_table_grow() by host is not supported."
                "Only allow growing a table via the opcode table.grow");
    return false;
}

static wasm_memory_t *
wasm_memory_new_basic(wasm_store_t *store, const wasm_memorytype_t *type)
{
    wasm_memory_t *memory = NULL;

    if (!type) {
        goto failed;
    }

    if (!(memory = malloc_internal(sizeof(wasm_memory_t)))) {
        goto failed;
    }

    memory->store = store;
    memory->kind = WASM_EXTERN_MEMORY;
    memory->type = wasm_memorytype_copy(type);

    RETURN_OBJ(memory, wasm_memory_delete)
}

wasm_memory_t *
wasm_memory_new(wasm_store_t *store, const wasm_memorytype_t *type)
{
    bh_assert(singleton_engine);
    return wasm_memory_new_basic(store, type);
}

wasm_memory_t *
wasm_memory_copy(const wasm_memory_t *src)
{
    wasm_memory_t *dst = NULL;

    if (!src) {
        return NULL;
    }

    if (!(dst = wasm_memory_new_basic(src->store, src->type))) {
        goto failed;
    }

    dst->memory_idx_rt = src->memory_idx_rt;
    dst->inst_comm_rt = src->inst_comm_rt;

    RETURN_OBJ(dst, wasm_memory_delete)
}

wasm_memory_t *
wasm_memory_new_internal(wasm_store_t *store, uint16 memory_idx_rt,
                         WASMModuleInstanceCommon *inst_comm_rt)
{
    wasm_memory_t *memory = NULL;
    uint32 min_pages = 0, max_pages = 0;
    bool init_flag = false;

    bh_assert(singleton_engine);

    if (!inst_comm_rt) {
        return NULL;
    }

    if (!(memory = malloc_internal(sizeof(wasm_memory_t)))) {
        goto failed;
    }

    memory->store = store;
    memory->kind = WASM_EXTERN_MEMORY;

#if WASM_ENABLE_INTERP != 0
    if (inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        WASMMemoryInstance *memory_interp =
            ((WASMModuleInstance *)inst_comm_rt)->memories[memory_idx_rt];
        min_pages = memory_interp->cur_page_count;
        max_pages = memory_interp->max_page_count;
        init_flag = true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (inst_comm_rt->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *inst_aot = (AOTModuleInstance *)inst_comm_rt;
        AOTModule *module_aot = (AOTModule *)inst_aot->module;

        if (memory_idx_rt < module_aot->import_memory_count) {
            min_pages = module_aot->import_memories->mem_type.init_page_count;
            max_pages = module_aot->import_memories->mem_type.max_page_count;
        }
        else {
            min_pages = module_aot->memories->init_page_count;
            max_pages = module_aot->memories->max_page_count;
        }
        init_flag = true;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!init_flag) {
        goto failed;
    }

    if (!(memory->type = wasm_memorytype_new_internal(min_pages, max_pages))) {
        goto failed;
    }

    memory->inst_comm_rt = inst_comm_rt;
    memory->memory_idx_rt = memory_idx_rt;

    RETURN_OBJ(memory, wasm_memory_delete);
}

void
wasm_memory_delete(wasm_memory_t *memory)
{
    if (!memory) {
        return;
    }

    if (memory->type) {
        wasm_memorytype_delete(memory->type);
        memory->type = NULL;
    }

    DELETE_HOST_INFO(memory)

    wasm_runtime_free(memory);
}

wasm_memorytype_t *
wasm_memory_type(const wasm_memory_t *memory)
{
    if (!memory) {
        return NULL;
    }

    return wasm_memorytype_copy(memory->type);
}

byte_t *
wasm_memory_data(wasm_memory_t *memory)
{
    WASMModuleInstanceCommon *module_inst_comm;

    if (!memory || !memory->inst_comm_rt) {
        return NULL;
    }

    module_inst_comm = memory->inst_comm_rt;
#if WASM_ENABLE_INTERP != 0
    if (module_inst_comm->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *module_inst =
            (WASMModuleInstance *)module_inst_comm;
        WASMMemoryInstance *memory_inst =
            module_inst->memories[memory->memory_idx_rt];
        return (byte_t *)memory_inst->memory_data;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst_comm->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *module_inst = (AOTModuleInstance *)module_inst_comm;
        AOTMemoryInstance *memory_inst =
            ((AOTMemoryInstance **)
                 module_inst->memories)[memory->memory_idx_rt];
        return (byte_t *)memory_inst->memory_data;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return NULL;
}

size_t
wasm_memory_data_size(const wasm_memory_t *memory)
{
    WASMModuleInstanceCommon *module_inst_comm;

    if (!memory || !memory->inst_comm_rt) {
        return 0;
    }

    module_inst_comm = memory->inst_comm_rt;
#if WASM_ENABLE_INTERP != 0
    if (module_inst_comm->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *module_inst =
            (WASMModuleInstance *)module_inst_comm;
        WASMMemoryInstance *memory_inst =
            module_inst->memories[memory->memory_idx_rt];
        return (size_t)memory_inst->cur_page_count
               * memory_inst->num_bytes_per_page;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst_comm->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *module_inst = (AOTModuleInstance *)module_inst_comm;
        AOTMemoryInstance *memory_inst =
            ((AOTMemoryInstance **)
                 module_inst->memories)[memory->memory_idx_rt];
        return (size_t)memory_inst->cur_page_count
               * memory_inst->num_bytes_per_page;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return 0;
}

wasm_memory_pages_t
wasm_memory_size(const wasm_memory_t *memory)
{
    WASMModuleInstanceCommon *module_inst_comm;

    if (!memory || !memory->inst_comm_rt) {
        return 0;
    }

    module_inst_comm = memory->inst_comm_rt;
#if WASM_ENABLE_INTERP != 0
    if (module_inst_comm->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *module_inst =
            (WASMModuleInstance *)module_inst_comm;
        WASMMemoryInstance *memory_inst =
            module_inst->memories[memory->memory_idx_rt];
        return memory_inst->cur_page_count;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst_comm->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *module_inst = (AOTModuleInstance *)module_inst_comm;
        AOTMemoryInstance *memory_inst =
            ((AOTMemoryInstance **)
                 module_inst->memories)[memory->memory_idx_rt];
        return memory_inst->cur_page_count;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    return 0;
}

bool
wasm_memory_grow(wasm_memory_t *memory, wasm_memory_pages_t delta)
{
    (void)memory;
    (void)delta;
    LOG_WARNING("Calling wasm_memory_grow() by host is not supported."
                "Only allow growing a memory via the opcode memory.grow");
    return false;
}

#if WASM_ENABLE_INTERP != 0
static bool
interp_link_func(const wasm_instance_t *inst, const WASMModule *module_interp,
                 uint16 func_idx_rt, wasm_func_t *import)
{
    WASMImport *imported_func_interp = NULL;

    bh_assert(inst && module_interp && import);
    bh_assert(func_idx_rt < module_interp->import_function_count);
    bh_assert(WASM_EXTERN_FUNC == import->kind);

    imported_func_interp = module_interp->import_functions + func_idx_rt;
    bh_assert(imported_func_interp);
    bh_assert(imported_func_interp->kind == IMPORT_KIND_FUNC);

    /* it is a placeholder and let's skip it*/
    if (!import->type)
        return true;

    /* type comparison */
    if (!wasm_functype_same_internal(
            import->type, imported_func_interp->u.function.func_type))
        return false;

    imported_func_interp->u.function.call_conv_wasm_c_api = true;
    /* only set func_ptr_linked to avoid unlink warning during instantiation,
       func_ptr_linked, with_env and env will be stored in module instance's
       c_api_func_imports later and used when calling import function */
    if (import->with_env)
        imported_func_interp->u.function.func_ptr_linked = import->u.cb_env.cb;
    else
        imported_func_interp->u.function.func_ptr_linked = import->u.cb;
    bh_assert(imported_func_interp->u.function.func_ptr_linked);

    import->func_idx_rt = func_idx_rt;

    (void)inst;
    return true;
}

static bool
interp_link_global(const WASMModule *module_interp, uint16 global_idx_rt,
                   wasm_global_t *import)
{
    WASMImport *imported_global_interp = NULL;

    bh_assert(module_interp && import);
    bh_assert(global_idx_rt < module_interp->import_global_count);
    bh_assert(WASM_EXTERN_GLOBAL == import->kind);

    imported_global_interp = module_interp->import_globals + global_idx_rt;
    bh_assert(imported_global_interp);
    bh_assert(imported_global_interp->kind == IMPORT_KIND_GLOBAL);

    /* it is a placeholder and let's skip it*/
    if (!import->type)
        return true;

    /* type comparison */
    if (!cmp_val_kind_with_val_type(
            wasm_valtype_kind(import->type->val_type),
            imported_global_interp->u.global.type.val_type))
        return false;

    /* set init value */
    bh_assert(import->init);
    switch (wasm_valtype_kind(import->type->val_type)) {
        case WASM_I32:
            imported_global_interp->u.global.global_data_linked.i32 =
                import->init->of.i32;
            break;
        case WASM_I64:
            imported_global_interp->u.global.global_data_linked.i64 =
                import->init->of.i64;
            break;
        case WASM_F32:
            imported_global_interp->u.global.global_data_linked.f32 =
                import->init->of.f32;
            break;
        case WASM_F64:
            imported_global_interp->u.global.global_data_linked.f64 =
                import->init->of.f64;
            break;
        default:
            return false;
    }

    import->global_idx_rt = global_idx_rt;
    imported_global_interp->u.global.is_linked = true;
    return true;
}

static bool
interp_process_export(wasm_store_t *store,
                      const WASMModuleInstance *inst_interp,
                      wasm_extern_vec_t *externals)
{
    WASMExport *exports = NULL;
    WASMExport *export = NULL;
    wasm_extern_t *external = NULL;
    uint32 export_cnt = 0;
    uint32 i = 0;

    bh_assert(store && inst_interp && inst_interp->module && externals);

    exports = inst_interp->module->exports;
    export_cnt = inst_interp->module->export_count;

    for (i = 0; i < export_cnt; ++i) {
        export = exports + i;

        switch (export->kind) {
            case EXPORT_KIND_FUNC:
            {
                wasm_func_t *func;
                if (!(func = wasm_func_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_interp))) {
                    goto failed;
                }

                external = wasm_func_as_extern(func);
                break;
            }
            case EXPORT_KIND_GLOBAL:
            {
                wasm_global_t *global;
                if (!(global = wasm_global_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_interp))) {
                    goto failed;
                }

                external = wasm_global_as_extern(global);
                break;
            }
            case EXPORT_KIND_TABLE:
            {
                wasm_table_t *table;
                if (!(table = wasm_table_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_interp))) {
                    goto failed;
                }

                external = wasm_table_as_extern(table);
                break;
            }
            case EXPORT_KIND_MEMORY:
            {
                wasm_memory_t *memory;
                if (!(memory = wasm_memory_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_interp))) {
                    goto failed;
                }

                external = wasm_memory_as_extern(memory);
                break;
            }
            default:
                LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                            export->kind);
                goto failed;
        }

        if (!bh_vector_append((Vector *)externals, &external)) {
            goto failed;
        }
    }

    return true;

failed:
    wasm_extern_delete(external);
    return false;
}
#endif /* WASM_ENABLE_INTERP */

#if WASM_ENABLE_AOT != 0
static bool
aot_link_func(const wasm_instance_t *inst, const AOTModule *module_aot,
              uint32 import_func_idx_rt, wasm_func_t *import)
{
    AOTImportFunc *import_aot_func = NULL;

    bh_assert(inst && module_aot && import);

    import_aot_func = module_aot->import_funcs + import_func_idx_rt;
    bh_assert(import_aot_func);

    /* it is a placeholder and let's skip it*/
    if (!import->type)
        return true;

    /* type comparison */
    if (!wasm_functype_same_internal(import->type, import_aot_func->func_type))
        return false;

    import_aot_func->call_conv_wasm_c_api = true;
    /* only set func_ptr_linked to avoid unlink warning during instantiation,
       func_ptr_linked, with_env and env will be stored in module instance's
       c_api_func_imports later and used when calling import function */
    if (import->with_env)
        import_aot_func->func_ptr_linked = import->u.cb_env.cb;
    else
        import_aot_func->func_ptr_linked = import->u.cb;
    bh_assert(import_aot_func->func_ptr_linked);

    import->func_idx_rt = import_func_idx_rt;

    return true;
}

static bool
aot_link_global(const AOTModule *module_aot, uint16 global_idx_rt,
                wasm_global_t *import)
{
    AOTImportGlobal *import_aot_global = NULL;
    const wasm_valtype_t *val_type = NULL;

    bh_assert(module_aot && import);

    import_aot_global = module_aot->import_globals + global_idx_rt;
    bh_assert(import_aot_global);

    /* it is a placeholder and let's skip it*/
    if (!import->type)
        return true;

    val_type = wasm_globaltype_content(import->type);
    bh_assert(val_type);

    if (!cmp_val_kind_with_val_type(wasm_valtype_kind(val_type),
                                    import_aot_global->type.val_type))
        return false;

    bh_assert(import->init);
    switch (wasm_valtype_kind(val_type)) {
        case WASM_I32:
            import_aot_global->global_data_linked.i32 = import->init->of.i32;
            break;
        case WASM_I64:
            import_aot_global->global_data_linked.i64 = import->init->of.i64;
            break;
        case WASM_F32:
            import_aot_global->global_data_linked.f32 = import->init->of.f32;
            break;
        case WASM_F64:
            import_aot_global->global_data_linked.f64 = import->init->of.f64;
            break;
        default:
            goto failed;
    }

    import->global_idx_rt = global_idx_rt;
    import_aot_global->is_linked = true;
    return true;
failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    return false;
}

static bool
aot_process_export(wasm_store_t *store, const AOTModuleInstance *inst_aot,
                   wasm_extern_vec_t *externals)
{
    uint32 i;
    wasm_extern_t *external = NULL;
    AOTModule *module_aot = NULL;

    bh_assert(store && inst_aot && externals);

    module_aot = (AOTModule *)inst_aot->module;
    bh_assert(module_aot);

    for (i = 0; i < module_aot->export_count; ++i) {
        AOTExport *export = module_aot->exports + i;

        switch (export->kind) {
            case EXPORT_KIND_FUNC:
            {
                wasm_func_t *func = NULL;
                if (!(func = wasm_func_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_aot))) {
                    goto failed;
                }

                external = wasm_func_as_extern(func);
                break;
            }
            case EXPORT_KIND_GLOBAL:
            {
                wasm_global_t *global = NULL;
                if (!(global = wasm_global_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_aot))) {
                    goto failed;
                }

                external = wasm_global_as_extern(global);
                break;
            }
            case EXPORT_KIND_TABLE:
            {
                wasm_table_t *table;
                if (!(table = wasm_table_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_aot))) {
                    goto failed;
                }

                external = wasm_table_as_extern(table);
                break;
            }
            case EXPORT_KIND_MEMORY:
            {
                wasm_memory_t *memory;
                if (!(memory = wasm_memory_new_internal(
                          store, export->index,
                          (WASMModuleInstanceCommon *)inst_aot))) {
                    goto failed;
                }

                external = wasm_memory_as_extern(memory);
                break;
            }
            default:
                LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                            export->kind);
                goto failed;
        }

        if (!(external->name = malloc_internal(sizeof(wasm_byte_vec_t)))) {
            goto failed;
        }

        wasm_name_new_from_string_nt(external->name, export->name);
        if (strlen(export->name) && !external->name->data) {
            goto failed;
        }

        if (!bh_vector_append((Vector *)externals, &external)) {
            goto failed;
        }
    }

    return true;

failed:
    wasm_extern_delete(external);
    return false;
}
#endif /* WASM_ENABLE_AOT */

static bool
do_link(const wasm_instance_t *inst, const wasm_module_t *module,
        const wasm_extern_vec_t *imports)
{
    uint32 i, import_func_i, import_global_i;

    bh_assert(inst && module);

    /* we have run a module_type check before. */

    for (i = 0, import_func_i = 0, import_global_i = 0; i < imports->num_elems;
         i++) {
        wasm_extern_t *import = imports->data[i];

        if (!import) {
            LOG_ERROR("imports[%d] is NULL and it is fatal\n", i);
            goto failed;
        }

        switch (wasm_extern_kind(import)) {
            case WASM_EXTERN_FUNC:
            {
                bool ret = false;
#if WASM_ENABLE_INTERP != 0
                if ((*module)->module_type == Wasm_Module_Bytecode) {
                    ret = interp_link_func(inst, MODULE_INTERP(module),
                                           import_func_i,
                                           wasm_extern_as_func(import));
                }
#endif
#if WASM_ENABLE_AOT != 0
                if ((*module)->module_type == Wasm_Module_AoT) {
                    ret = aot_link_func(inst, MODULE_AOT(module), import_func_i,
                                        wasm_extern_as_func(import));
                }
#endif
                if (!ret) {
                    LOG_WARNING("link function  #%d failed", import_func_i);
                    goto failed;
                }

                import_func_i++;
                break;
            }
            case WASM_EXTERN_GLOBAL:
            {
                bool ret = false;
#if WASM_ENABLE_INTERP != 0
                if ((*module)->module_type == Wasm_Module_Bytecode) {
                    ret = interp_link_global(MODULE_INTERP(module),
                                             import_global_i,
                                             wasm_extern_as_global(import));
                }
#endif
#if WASM_ENABLE_AOT != 0
                if ((*module)->module_type == Wasm_Module_AoT) {
                    ret = aot_link_global(MODULE_AOT(module), import_global_i,
                                          wasm_extern_as_global(import));
                }
#endif
                if (!ret) {
                    LOG_WARNING("link global #%d failed", import_global_i);
                    goto failed;
                }

                import_global_i++;
                break;
            }
            case WASM_EXTERN_MEMORY:
            case WASM_EXTERN_TABLE:
            {
                LOG_WARNING("doesn't support import memories and tables for "
                            "now, ignore them");
                break;
            }
            default:
            {
                UNREACHABLE();
                break;
            }
        }
    }

    return true;
failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    return false;
}

wasm_instance_t *
wasm_instance_new(wasm_store_t *store, const wasm_module_t *module,
                  const wasm_extern_vec_t *imports, own wasm_trap_t **trap)
{
    return wasm_instance_new_with_args(store, module, imports, trap,
                                       KILOBYTE(32), KILOBYTE(32));
}

wasm_instance_t *
wasm_instance_new_with_args(wasm_store_t *store, const wasm_module_t *module,
                            const wasm_extern_vec_t *imports,
                            own wasm_trap_t **trap, const uint32 stack_size,
                            const uint32 heap_size)
{
    InstantiationArgs inst_args = { 0 };
    inst_args.default_stack_size = stack_size;
    inst_args.host_managed_heap_size = heap_size;
    return wasm_instance_new_with_args_ex(store, module, imports, trap,
                                          &inst_args);
}

wasm_instance_t *
wasm_instance_new_with_args_ex(wasm_store_t *store, const wasm_module_t *module,
                               const wasm_extern_vec_t *imports,
                               own wasm_trap_t **trap,
                               const InstantiationArgs *inst_args)
{
    char sub_error_buf[128] = { 0 };
    char error_buf[256] = { 0 };
    wasm_instance_t *instance = NULL;
    CApiFuncImport *func_import = NULL, **p_func_imports = NULL;
    uint32 i = 0, import_func_count = 0;
    uint64 total_size;
    bool build_exported = false;

    bh_assert(singleton_engine);

    if (!module)
        return NULL;

    /*
     * will do the check at the end of wasm_runtime_instantiate
     */

    WASM_C_DUMP_PROC_MEM();

    instance = malloc_internal(sizeof(wasm_instance_t));
    if (!instance) {
        snprintf(sub_error_buf, sizeof(sub_error_buf),
                 "Failed to malloc instance");
        goto failed;
    }

    /* executes the instantiate-time linking if provided */
    if (imports) {
        if (!do_link(instance, module, imports)) {
            snprintf(sub_error_buf, sizeof(sub_error_buf),
                     "Failed to validate imports");
            goto failed;
        }
    }
    /*
     * will do the linking result check at the end of wasm_runtime_instantiate
     */

    instance->inst_comm_rt = wasm_runtime_instantiate_ex(
        *module, inst_args, sub_error_buf, sizeof(sub_error_buf));
    if (!instance->inst_comm_rt) {
        goto failed;
    }

    if (!wasm_runtime_create_exec_env_singleton(instance->inst_comm_rt)) {
        snprintf(sub_error_buf, sizeof(sub_error_buf),
                 "Failed to create exec env singleton");
        goto failed;
    }

    /* create the c-api func import list */
#if WASM_ENABLE_INTERP != 0
    if (instance->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *wasm_module_inst =
            (WASMModuleInstance *)instance->inst_comm_rt;
        p_func_imports = &(wasm_module_inst->c_api_func_imports);
        import_func_count = MODULE_INTERP(module)->import_function_count;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (instance->inst_comm_rt->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *aot_module_inst =
            (AOTModuleInstance *)instance->inst_comm_rt;
        p_func_imports = &(aot_module_inst->c_api_func_imports);
        import_func_count = MODULE_AOT(module)->import_func_count;
    }
#endif
    bh_assert(p_func_imports);

    total_size = (uint64)sizeof(CApiFuncImport) * import_func_count;
    if (total_size > 0
        && !(*p_func_imports = func_import = malloc_internal(total_size))) {
        snprintf(sub_error_buf, sizeof(sub_error_buf),
                 "Failed to create wasm-c-api func imports");
        goto failed;
    }

    /* fill in module_inst->c_api_func_imports */
    for (i = 0; imports && i < imports->num_elems; i++) {
        wasm_func_t *func_host = NULL;
        wasm_extern_t *in = imports->data[i];
        bh_assert(in);

        if (wasm_extern_kind(in) != WASM_EXTERN_FUNC)
            continue;

        func_host = wasm_extern_as_func(in);
        /* it is a placeholder and let's skip it*/
        if (!func_host->type) {
            func_import++;
            continue;
        }

        func_import->with_env_arg = func_host->with_env;
        if (func_host->with_env) {
            func_import->func_ptr_linked = func_host->u.cb_env.cb;
            func_import->env_arg = func_host->u.cb_env.env;
        }
        else {
            func_import->func_ptr_linked = func_host->u.cb;
            func_import->env_arg = NULL;
        }
        bh_assert(func_import->func_ptr_linked);

        func_import++;
    }

    /* fill with inst */
    for (i = 0; imports && imports->data && i < imports->num_elems; ++i) {
        wasm_extern_t *import = imports->data[i];
        bh_assert(import);

        switch (import->kind) {
            case WASM_EXTERN_FUNC:
                wasm_extern_as_func(import)->inst_comm_rt =
                    instance->inst_comm_rt;
                break;
            case WASM_EXTERN_GLOBAL:
                wasm_extern_as_global(import)->inst_comm_rt =
                    instance->inst_comm_rt;
                break;
            case WASM_EXTERN_MEMORY:
                wasm_extern_as_memory(import)->inst_comm_rt =
                    instance->inst_comm_rt;
                break;
            case WASM_EXTERN_TABLE:
                wasm_extern_as_table(import)->inst_comm_rt =
                    instance->inst_comm_rt;
                break;
            default:
                snprintf(sub_error_buf, sizeof(sub_error_buf),
                         "Unknown import kind");
                goto failed;
        }
    }

    /* build the exports list */
#if WASM_ENABLE_INTERP != 0
    if (instance->inst_comm_rt->module_type == Wasm_Module_Bytecode) {
        uint32 export_cnt = ((WASMModuleInstance *)instance->inst_comm_rt)
                                ->module->export_count;

        INIT_VEC(instance->exports, wasm_extern_vec_new_uninitialized,
                 export_cnt);

        if (!interp_process_export(store,
                                   (WASMModuleInstance *)instance->inst_comm_rt,
                                   instance->exports)) {
            snprintf(sub_error_buf, sizeof(sub_error_buf),
                     "Interpreter failed to process exports");
            goto failed;
        }

        build_exported = true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (instance->inst_comm_rt->module_type == Wasm_Module_AoT) {
        uint32 export_cnt =
            ((AOTModuleInstance *)instance->inst_comm_rt)->export_func_count
            + ((AOTModuleInstance *)instance->inst_comm_rt)->export_global_count
            + ((AOTModuleInstance *)instance->inst_comm_rt)->export_table_count
            + ((AOTModuleInstance *)instance->inst_comm_rt)
                  ->export_memory_count;

        INIT_VEC(instance->exports, wasm_extern_vec_new_uninitialized,
                 export_cnt);

        if (!aot_process_export(store,
                                (AOTModuleInstance *)instance->inst_comm_rt,
                                instance->exports)) {
            snprintf(sub_error_buf, sizeof(sub_error_buf),
                     "AOT failed to process exports");
            goto failed;
        }

        build_exported = true;
    }
#endif

    /*
     * a wrong combination of module filetype and compilation flags
     * leads to below branch
     */
    if (!build_exported) {
        snprintf(sub_error_buf, sizeof(sub_error_buf),
                 "Incorrect filetype and compilation flags");
        goto failed;
    }

    /* add it to a watching list in store */
    if (!bh_vector_append((Vector *)store->instances, &instance)) {
        snprintf(sub_error_buf, sizeof(sub_error_buf),
                 "Failed to add to store instances");
        goto failed;
    }

    WASM_C_DUMP_PROC_MEM();

    return instance;

failed:
    snprintf(error_buf, sizeof(error_buf), "%s failed: %s", __FUNCTION__,
             sub_error_buf);
    if (trap != NULL) {
        wasm_message_t message = { 0 };
        wasm_name_new_from_string_nt(&message, error_buf);
        *trap = wasm_trap_new(store, &message);
        wasm_byte_vec_delete(&message);
    }
    LOG_DEBUG("%s", error_buf);
    wasm_instance_delete_internal(instance);
    return NULL;
}

static void
wasm_instance_delete_internal(wasm_instance_t *instance)
{
    if (!instance) {
        return;
    }

    DEINIT_VEC(instance->exports, wasm_extern_vec_delete);

    if (instance->inst_comm_rt) {
        wasm_runtime_deinstantiate(instance->inst_comm_rt);
        instance->inst_comm_rt = NULL;
    }
    wasm_runtime_free(instance);
}

void
wasm_instance_delete(wasm_instance_t *inst)
{
    DELETE_HOST_INFO(inst)
    /* will release instance when releasing the store */
}

void
wasm_instance_exports(const wasm_instance_t *instance,
                      own wasm_extern_vec_t *out)
{
    if (!instance || !out) {
        return;
    }
    wasm_extern_vec_copy(out, instance->exports);
}

wasm_extern_t *
wasm_extern_copy(const wasm_extern_t *src)
{
    wasm_extern_t *dst = NULL;

    if (!src) {
        return NULL;
    }

    switch (wasm_extern_kind(src)) {
        case WASM_EXTERN_FUNC:
            dst = wasm_func_as_extern(
                wasm_func_copy(wasm_extern_as_func_const(src)));
            break;
        case WASM_EXTERN_GLOBAL:
            dst = wasm_global_as_extern(
                wasm_global_copy(wasm_extern_as_global_const(src)));
            break;
        case WASM_EXTERN_MEMORY:
            dst = wasm_memory_as_extern(
                wasm_memory_copy(wasm_extern_as_memory_const(src)));
            break;
        case WASM_EXTERN_TABLE:
            dst = wasm_table_as_extern(
                wasm_table_copy(wasm_extern_as_table_const(src)));
            break;
        default:
            LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                        src->kind);
            break;
    }

    if (!dst) {
        goto failed;
    }

    return dst;

failed:
    LOG_DEBUG("%s failed", __FUNCTION__);
    wasm_extern_delete(dst);
    return NULL;
}

void
wasm_extern_delete(wasm_extern_t *external)
{
    if (!external) {
        return;
    }

    if (external->name) {
        wasm_byte_vec_delete(external->name);
        wasm_runtime_free(external->name);
        external->name = NULL;
    }

    switch (wasm_extern_kind(external)) {
        case WASM_EXTERN_FUNC:
            wasm_func_delete(wasm_extern_as_func(external));
            break;
        case WASM_EXTERN_GLOBAL:
            wasm_global_delete(wasm_extern_as_global(external));
            break;
        case WASM_EXTERN_MEMORY:
            wasm_memory_delete(wasm_extern_as_memory(external));
            break;
        case WASM_EXTERN_TABLE:
            wasm_table_delete(wasm_extern_as_table(external));
            break;
        default:
            LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                        external->kind);
            break;
    }
}

wasm_externkind_t
wasm_extern_kind(const wasm_extern_t *external)
{
    if (!external) {
        return WASM_EXTERNREF;
    }

    return external->kind;
}

own wasm_externtype_t *
wasm_extern_type(const wasm_extern_t *external)
{
    if (!external) {
        return NULL;
    }

    switch (wasm_extern_kind(external)) {
        case WASM_EXTERN_FUNC:
            return wasm_functype_as_externtype(
                wasm_func_type(wasm_extern_as_func_const(external)));
        case WASM_EXTERN_GLOBAL:
            return wasm_globaltype_as_externtype(
                wasm_global_type(wasm_extern_as_global_const(external)));
        case WASM_EXTERN_MEMORY:
            return wasm_memorytype_as_externtype(
                wasm_memory_type(wasm_extern_as_memory_const(external)));
        case WASM_EXTERN_TABLE:
            return wasm_tabletype_as_externtype(
                wasm_table_type(wasm_extern_as_table_const(external)));
        default:
            LOG_WARNING("%s meets unsupported kind: %d", __FUNCTION__,
                        external->kind);
            break;
    }
    return NULL;
}

#define BASIC_FOUR_LIST(V) \
    V(func)                \
    V(global)              \
    V(memory)              \
    V(table)

#define WASM_EXTERN_AS_OTHER(name)                                  \
    wasm_##name##_t *wasm_extern_as_##name(wasm_extern_t *external) \
    {                                                               \
        return (wasm_##name##_t *)external;                         \
    }

BASIC_FOUR_LIST(WASM_EXTERN_AS_OTHER)
#undef WASM_EXTERN_AS_OTHER

#define WASM_OTHER_AS_EXTERN(name)                                 \
    wasm_extern_t *wasm_##name##_as_extern(wasm_##name##_t *other) \
    {                                                              \
        return (wasm_extern_t *)other;                             \
    }

BASIC_FOUR_LIST(WASM_OTHER_AS_EXTERN)
#undef WASM_OTHER_AS_EXTERN

#define WASM_EXTERN_AS_OTHER_CONST(name)                  \
    const wasm_##name##_t *wasm_extern_as_##name##_const( \
        const wasm_extern_t *external)                    \
    {                                                     \
        return (const wasm_##name##_t *)external;         \
    }

BASIC_FOUR_LIST(WASM_EXTERN_AS_OTHER_CONST)
#undef WASM_EXTERN_AS_OTHER_CONST

#define WASM_OTHER_AS_EXTERN_CONST(name)                \
    const wasm_extern_t *wasm_##name##_as_extern_const( \
        const wasm_##name##_t *other)                   \
    {                                                   \
        return (const wasm_extern_t *)other;            \
    }

BASIC_FOUR_LIST(WASM_OTHER_AS_EXTERN_CONST)
#undef WASM_OTHER_AS_EXTERN_CONST

wasm_extern_t *
wasm_extern_new_empty(wasm_store_t *store, wasm_externkind_t extern_kind)
{
    if (extern_kind == WASM_EXTERN_FUNC)
        return wasm_func_as_extern(wasm_func_new_empty(store));

    if (extern_kind == WASM_EXTERN_GLOBAL)
        return wasm_global_as_extern(wasm_global_new_empty(store));

    LOG_ERROR("Don't support linking table and memory for now");
    return NULL;
}

double
wasm_instance_sum_wasm_exec_time(const wasm_instance_t *instance)
{
#if WASM_ENABLE_PERF_PROFILING != 0
    return wasm_runtime_sum_wasm_exec_time(instance->inst_comm_rt);
#else
    return -1.0;
#endif
}

double
wasm_instance_get_wasm_func_exec_time(const wasm_instance_t *instance,
                                      const char *name)
{
#if WASM_ENABLE_PERF_PROFILING != 0
    return wasm_runtime_get_wasm_func_exec_time(instance->inst_comm_rt, name);
#else
    return -1.0;
#endif
}
