/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "wasm_native.h"
#include "wasm_runtime_common.h"
#include "bh_log.h"
#if WASM_ENABLE_INTERP != 0
#include "../interpreter/wasm_runtime.h"
#endif
#if WASM_ENABLE_AOT != 0
#include "../aot/aot_runtime.h"
#endif
#if WASM_ENABLE_THREAD_MGR != 0
#include "../libraries/thread-mgr/thread_manager.h"
#endif
#if WASM_ENABLE_WASI_NN != 0 || WASM_ENABLE_WASI_EPHEMERAL_NN != 0
#include "wasi_nn_host.h"
#endif

static NativeSymbolsList g_native_symbols_list = NULL;

#if WASM_ENABLE_LIBC_WASI != 0
static void *g_wasi_context_key;
#endif /* WASM_ENABLE_LIBC_WASI */

uint32
get_libc_builtin_export_apis(NativeSymbol **p_libc_builtin_apis);

#if WASM_ENABLE_SPEC_TEST != 0
uint32
get_spectest_export_apis(NativeSymbol **p_libc_builtin_apis);
#endif

#if WASM_ENABLE_SHARED_HEAP != 0
uint32
get_lib_shared_heap_export_apis(NativeSymbol **p_shared_heap_apis);
#endif

uint32
get_libc_wasi_export_apis(NativeSymbol **p_libc_wasi_apis);

uint32
get_base_lib_export_apis(NativeSymbol **p_base_lib_apis);

uint32
get_ext_lib_export_apis(NativeSymbol **p_ext_lib_apis);

#if WASM_ENABLE_LIB_PTHREAD != 0
bool
lib_pthread_init();

void
lib_pthread_destroy();

uint32
get_lib_pthread_export_apis(NativeSymbol **p_lib_pthread_apis);
#endif

#if WASM_ENABLE_LIB_WASI_THREADS != 0
bool
lib_wasi_threads_init(void);

void
lib_wasi_threads_destroy(void);

uint32
get_lib_wasi_threads_export_apis(NativeSymbol **p_lib_wasi_threads_apis);
#endif

uint32
get_libc_emcc_export_apis(NativeSymbol **p_libc_emcc_apis);

uint32
get_lib_rats_export_apis(NativeSymbol **p_lib_rats_apis);

static bool
compare_type_with_signature(uint8 type, const char signature)
{
    const char num_sig_map[] = { 'F', 'f', 'I', 'i' };

    if (VALUE_TYPE_F64 <= type && type <= VALUE_TYPE_I32
        && signature == num_sig_map[type - VALUE_TYPE_F64]) {
        return true;
    }

#if WASM_ENABLE_REF_TYPES != 0
    if ('r' == signature
#if WASM_ENABLE_GC != 0
#if WASM_ENABLE_STRINGREF != 0
        && (type >= REF_TYPE_STRINGVIEWITER && type <= REF_TYPE_NULLFUNCREF)
#else
        && (type >= REF_TYPE_HT_NULLABLE && type <= REF_TYPE_NULLFUNCREF)
#endif
#else
        && type == VALUE_TYPE_EXTERNREF
#endif
    )
        return true;
#endif

    /* TODO: a v128 parameter */
    return false;
}

static bool
check_symbol_signature(const WASMFuncType *type, const char *signature)
{
    const char *p = signature, *p_end;
    char sig;
    uint32 i = 0;

    if (!p || strlen(p) < 2)
        return false;

    p_end = p + strlen(signature);

    if (*p++ != '(')
        return false;

    if ((uint32)(p_end - p) < (uint32)(type->param_count + 1))
        /* signatures of parameters, and ')' */
        return false;

    for (i = 0; i < type->param_count; i++) {
        sig = *p++;

        /* a f64/f32/i64/i32/externref parameter */
        if (compare_type_with_signature(type->types[i], sig))
            continue;

        /* a pointer/string parameter */
        if (type->types[i] != VALUE_TYPE_I32)
            /* pointer and string must be i32 type */
            return false;

        if (sig == '*') {
            /* it is a pointer */
            if (i + 1 < type->param_count
                && type->types[i + 1] == VALUE_TYPE_I32 && *p == '~') {
                /* pointer length followed */
                i++;
                p++;
            }
        }
        else if (sig == '$') {
            /* it is a string */
        }
        else {
            /* invalid signature */
            return false;
        }
    }

    if (*p++ != ')')
        return false;

    if (type->result_count) {
        if (p >= p_end)
            return false;

        /* result types includes: f64,f32,i64,i32,externref */
        if (!compare_type_with_signature(type->types[i], *p))
            return false;

        p++;
    }

    if (*p != '\0')
        return false;

    return true;
}

static int
native_symbol_cmp(const void *native_symbol1, const void *native_symbol2)
{
    return strcmp(((const NativeSymbol *)native_symbol1)->symbol,
                  ((const NativeSymbol *)native_symbol2)->symbol);
}

static void *
lookup_symbol(NativeSymbol *native_symbols, uint32 n_native_symbols,
              const char *symbol, const char **p_signature, void **p_attachment)
{
    NativeSymbol *native_symbol, key = { 0 };

    key.symbol = symbol;

    if ((native_symbol = bsearch(&key, native_symbols, n_native_symbols,
                                 sizeof(NativeSymbol), native_symbol_cmp))) {
        *p_signature = native_symbol->signature;
        *p_attachment = native_symbol->attachment;
        return native_symbol->func_ptr;
    }

    return NULL;
}

/**
 * allow func_type and all outputs, like p_signature, p_attachment and
 * p_call_conv_raw to be NULL
 */
void *
wasm_native_resolve_symbol(const char *module_name, const char *field_name,
                           const WASMFuncType *func_type,
                           const char **p_signature, void **p_attachment,
                           bool *p_call_conv_raw)
{
    NativeSymbolsNode *node, *node_next;
    const char *signature = NULL;
    void *func_ptr = NULL, *attachment = NULL;

    node = g_native_symbols_list;
    while (node) {
        node_next = node->next;
        if (!strcmp(node->module_name, module_name)) {
            if ((func_ptr =
                     lookup_symbol(node->native_symbols, node->n_native_symbols,
                                   field_name, &signature, &attachment))
                || (field_name[0] == '_'
                    && (func_ptr = lookup_symbol(
                            node->native_symbols, node->n_native_symbols,
                            field_name + 1, &signature, &attachment))))
                break;
        }
        node = node_next;
    }

    if (!p_signature || !p_attachment || !p_call_conv_raw)
        return func_ptr;

    if (func_ptr) {
        if (signature && signature[0] != '\0') {
            /* signature is not empty, check its format */
            if (!func_type || !check_symbol_signature(func_type, signature)) {
#if WASM_ENABLE_WAMR_COMPILER == 0
                /* Output warning except running aot compiler */
                LOG_WARNING("failed to check signature '%s' and resolve "
                            "pointer params for import function (%s, %s)\n",
                            signature, module_name, field_name);
#endif
                return NULL;
            }
            else
                /* Save signature for runtime to do pointer check and
                   address conversion */
                *p_signature = signature;
        }
        else
            /* signature is empty */
            *p_signature = NULL;

        *p_attachment = attachment;
        *p_call_conv_raw = node->call_conv_raw;
    }

    return func_ptr;
}

static bool
register_natives(const char *module_name, NativeSymbol *native_symbols,
                 uint32 n_native_symbols, bool call_conv_raw)
{
    NativeSymbolsNode *node;

    if (!(node = wasm_runtime_malloc(sizeof(NativeSymbolsNode))))
        return false;
#if WASM_ENABLE_MEMORY_TRACING != 0
    os_printf("Register native, size: %u\n", sizeof(NativeSymbolsNode));
#endif

    node->module_name = module_name;
    node->native_symbols = native_symbols;
    node->n_native_symbols = n_native_symbols;
    node->call_conv_raw = call_conv_raw;

    /* Add to list head */
    node->next = g_native_symbols_list;
    g_native_symbols_list = node;

    qsort(native_symbols, n_native_symbols, sizeof(NativeSymbol),
          native_symbol_cmp);

    return true;
}

bool
wasm_native_register_natives(const char *module_name,
                             NativeSymbol *native_symbols,
                             uint32 n_native_symbols)
{
    return register_natives(module_name, native_symbols, n_native_symbols,
                            false);
}

bool
wasm_native_register_natives_raw(const char *module_name,
                                 NativeSymbol *native_symbols,
                                 uint32 n_native_symbols)
{
    return register_natives(module_name, native_symbols, n_native_symbols,
                            true);
}

bool
wasm_native_unregister_natives(const char *module_name,
                               NativeSymbol *native_symbols)
{
    NativeSymbolsNode **prevp;
    NativeSymbolsNode *node;

    prevp = &g_native_symbols_list;
    while ((node = *prevp) != NULL) {
        if (node->native_symbols == native_symbols
            && !strcmp(node->module_name, module_name)) {
            *prevp = node->next;
            wasm_runtime_free(node);
            return true;
        }
        prevp = &node->next;
    }
    return false;
}

#if WASM_ENABLE_MODULE_INST_CONTEXT != 0
static uint32
context_key_to_idx(void *key)
{
    bh_assert(key != NULL);
    uint32 idx = (uint32)(uintptr_t)key;
    bh_assert(idx > 0);
    bh_assert(idx <= WASM_MAX_INSTANCE_CONTEXTS);
    return idx - 1;
}

static void *
context_idx_to_key(uint32 idx)
{
    bh_assert(idx < WASM_MAX_INSTANCE_CONTEXTS);
    return (void *)(uintptr_t)(idx + 1);
}

typedef void (*dtor_t)(WASMModuleInstanceCommon *, void *);
static dtor_t g_context_dtors[WASM_MAX_INSTANCE_CONTEXTS];

static void
dtor_noop(WASMModuleInstanceCommon *inst, void *ctx)
{}

void *
wasm_native_create_context_key(void (*dtor)(WASMModuleInstanceCommon *inst,
                                            void *ctx))
{
    uint32 i;
    for (i = 0; i < WASM_MAX_INSTANCE_CONTEXTS; i++) {
        if (g_context_dtors[i] == NULL) {
            if (dtor == NULL) {
                dtor = dtor_noop;
            }
            g_context_dtors[i] = dtor;
            return context_idx_to_key(i);
        }
    }
    LOG_ERROR("failed to allocate instance context key");
    return NULL;
}

void
wasm_native_destroy_context_key(void *key)
{
    uint32 idx = context_key_to_idx(key);
    bh_assert(g_context_dtors[idx] != NULL);
    g_context_dtors[idx] = NULL;
}

static WASMModuleInstanceExtraCommon *
wasm_module_inst_extra_common(WASMModuleInstanceCommon *inst)
{
#if WASM_ENABLE_INTERP != 0
    if (inst->module_type == Wasm_Module_Bytecode) {
        return &((WASMModuleInstance *)inst)->e->common;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (inst->module_type == Wasm_Module_AoT) {
        return &((AOTModuleInstanceExtra *)((AOTModuleInstance *)inst)->e)
                    ->common;
    }
#endif
    bh_assert(false);
    return NULL;
}

void
wasm_native_set_context(WASMModuleInstanceCommon *inst, void *key, void *ctx)
{
    uint32 idx = context_key_to_idx(key);
    WASMModuleInstanceExtraCommon *common = wasm_module_inst_extra_common(inst);
    common->contexts[idx] = ctx;
}

void
wasm_native_set_context_spread(WASMModuleInstanceCommon *inst, void *key,
                               void *ctx)
{
#if WASM_ENABLE_THREAD_MGR != 0
    wasm_cluster_set_context(inst, key, ctx);
#else
    wasm_native_set_context(inst, key, ctx);
#endif
}

void *
wasm_native_get_context(WASMModuleInstanceCommon *inst, void *key)
{
    uint32 idx = context_key_to_idx(key);
    WASMModuleInstanceExtraCommon *common = wasm_module_inst_extra_common(inst);
    return common->contexts[idx];
}

void
wasm_native_call_context_dtors(WASMModuleInstanceCommon *inst)
{
    WASMModuleInstanceExtraCommon *common = wasm_module_inst_extra_common(inst);
    uint32 i;
    for (i = 0; i < WASM_MAX_INSTANCE_CONTEXTS; i++) {
        dtor_t dtor = g_context_dtors[i];
        if (dtor != NULL) {
            dtor(inst, common->contexts[i]);
        }
    }
}

void
wasm_native_inherit_contexts(WASMModuleInstanceCommon *child,
                             WASMModuleInstanceCommon *parent)
{
    WASMModuleInstanceExtraCommon *parent_common =
        wasm_module_inst_extra_common(parent);
    WASMModuleInstanceExtraCommon *child_common =
        wasm_module_inst_extra_common(child);
    bh_memcpy_s(child_common->contexts,
                sizeof(*child_common->contexts) * WASM_MAX_INSTANCE_CONTEXTS,
                parent_common->contexts,
                sizeof(*parent_common->contexts) * WASM_MAX_INSTANCE_CONTEXTS);
}
#endif /* WASM_ENABLE_MODULE_INST_CONTEXT != 0 */

#if WASM_ENABLE_LIBC_WASI != 0
WASIContext *
wasm_runtime_get_wasi_ctx(WASMModuleInstanceCommon *module_inst_comm)
{
    return wasm_native_get_context(module_inst_comm, g_wasi_context_key);
}

void
wasm_runtime_set_wasi_ctx(WASMModuleInstanceCommon *module_inst_comm,
                          WASIContext *wasi_ctx)
{
    wasm_native_set_context(module_inst_comm, g_wasi_context_key, wasi_ctx);
}

static void
wasi_context_dtor(WASMModuleInstanceCommon *inst, void *ctx)
{
    if (ctx == NULL) {
        return;
    }
    wasm_runtime_destroy_wasi(inst);
}
#endif /* end of WASM_ENABLE_LIBC_WASI */

#if WASM_ENABLE_QUICK_AOT_ENTRY != 0
static bool
quick_aot_entry_init(void);
#endif

bool
wasm_native_init()
{
#if WASM_ENABLE_SPEC_TEST != 0 || WASM_ENABLE_LIBC_BUILTIN != 0          \
    || WASM_ENABLE_BASE_LIB != 0 || WASM_ENABLE_LIBC_EMCC != 0           \
    || WASM_ENABLE_LIB_RATS != 0 || WASM_ENABLE_WASI_NN != 0             \
    || WASM_ENABLE_APP_FRAMEWORK != 0 || WASM_ENABLE_LIBC_WASI != 0      \
    || WASM_ENABLE_LIB_PTHREAD != 0 || WASM_ENABLE_LIB_WASI_THREADS != 0 \
    || WASM_ENABLE_WASI_NN != 0 || WASM_ENABLE_WASI_EPHEMERAL_NN != 0
    NativeSymbol *native_symbols;
    uint32 n_native_symbols;
#endif

#if WASM_ENABLE_LIBC_BUILTIN != 0
    n_native_symbols = get_libc_builtin_export_apis(&native_symbols);
    if (!wasm_native_register_natives("env", native_symbols, n_native_symbols))
        goto fail;
#endif /* WASM_ENABLE_LIBC_BUILTIN */

#if WASM_ENABLE_SPEC_TEST
    n_native_symbols = get_spectest_export_apis(&native_symbols);
    if (!wasm_native_register_natives("spectest", native_symbols,
                                      n_native_symbols))
        goto fail;
#endif /* WASM_ENABLE_SPEC_TEST */

#if WASM_ENABLE_LIBC_WASI != 0
    g_wasi_context_key = wasm_native_create_context_key(wasi_context_dtor);
    if (g_wasi_context_key == NULL) {
        goto fail;
    }
    n_native_symbols = get_libc_wasi_export_apis(&native_symbols);
    if (!wasm_native_register_natives("wasi_unstable", native_symbols,
                                      n_native_symbols))
        goto fail;
    if (!wasm_native_register_natives("wasi_snapshot_preview1", native_symbols,
                                      n_native_symbols))
        goto fail;
#endif

#if WASM_ENABLE_SHARED_HEAP != 0
    n_native_symbols = get_lib_shared_heap_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
#endif

#if WASM_ENABLE_BASE_LIB != 0
    n_native_symbols = get_base_lib_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
#endif

#if WASM_ENABLE_APP_FRAMEWORK != 0
    n_native_symbols = get_ext_lib_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
#endif

#if WASM_ENABLE_LIB_PTHREAD != 0
    if (!lib_pthread_init())
        goto fail;

    n_native_symbols = get_lib_pthread_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
#endif

#if WASM_ENABLE_LIB_WASI_THREADS != 0
    if (!lib_wasi_threads_init())
        goto fail;

    n_native_symbols = get_lib_wasi_threads_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("wasi", native_symbols,
                                         n_native_symbols))
        goto fail;
#endif

#if WASM_ENABLE_LIBC_EMCC != 0
    n_native_symbols = get_libc_emcc_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
#endif /* WASM_ENABLE_LIBC_EMCC */

#if WASM_ENABLE_LIB_RATS != 0
    n_native_symbols = get_lib_rats_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives("env", native_symbols,
                                         n_native_symbols))
        goto fail;
#endif /* WASM_ENABLE_LIB_RATS */

#if WASM_ENABLE_WASI_NN != 0 || WASM_ENABLE_WASI_EPHEMERAL_NN != 0
    if (!wasi_nn_initialize())
        goto fail;

    n_native_symbols = get_wasi_nn_export_apis(&native_symbols);
    if (n_native_symbols > 0
        && !wasm_native_register_natives(
#if WASM_ENABLE_WASI_EPHEMERAL_NN != 0
            "wasi_ephemeral_nn",
#else
            "wasi_nn",
#endif /* WASM_ENABLE_WASI_EPHEMERAL_NN != 0 */
            native_symbols, n_native_symbols))
        goto fail;
#endif /* WASM_ENABLE_WASI_NN != 0 || WASM_ENABLE_WASI_EPHEMERAL_NN != 0 */

#if WASM_ENABLE_QUICK_AOT_ENTRY != 0
    if (!quick_aot_entry_init()) {
#if WASM_ENABLE_SPEC_TEST != 0 || WASM_ENABLE_LIBC_BUILTIN != 0          \
    || WASM_ENABLE_BASE_LIB != 0 || WASM_ENABLE_LIBC_EMCC != 0           \
    || WASM_ENABLE_LIB_RATS != 0 || WASM_ENABLE_WASI_NN != 0             \
    || WASM_ENABLE_APP_FRAMEWORK != 0 || WASM_ENABLE_LIBC_WASI != 0      \
    || WASM_ENABLE_LIB_PTHREAD != 0 || WASM_ENABLE_LIB_WASI_THREADS != 0 \
    || WASM_ENABLE_WASI_NN != 0 || WASM_ENABLE_WASI_EPHEMERAL_NN != 0
        goto fail;
#else
        return false;
#endif
    }
#endif

    return true;
#if WASM_ENABLE_SPEC_TEST != 0 || WASM_ENABLE_LIBC_BUILTIN != 0          \
    || WASM_ENABLE_BASE_LIB != 0 || WASM_ENABLE_LIBC_EMCC != 0           \
    || WASM_ENABLE_LIB_RATS != 0 || WASM_ENABLE_WASI_NN != 0             \
    || WASM_ENABLE_APP_FRAMEWORK != 0 || WASM_ENABLE_LIBC_WASI != 0      \
    || WASM_ENABLE_LIB_PTHREAD != 0 || WASM_ENABLE_LIB_WASI_THREADS != 0 \
    || WASM_ENABLE_WASI_NN != 0 || WASM_ENABLE_WASI_EPHEMERAL_NN != 0
fail:
    wasm_native_destroy();
    return false;
#endif
}

void
wasm_native_destroy()
{
    NativeSymbolsNode *node, *node_next;

#if WASM_ENABLE_LIBC_WASI != 0
    if (g_wasi_context_key != NULL) {
        wasm_native_destroy_context_key(g_wasi_context_key);
        g_wasi_context_key = NULL;
    }
#endif

#if WASM_ENABLE_LIB_PTHREAD != 0
    lib_pthread_destroy();
#endif

#if WASM_ENABLE_LIB_WASI_THREADS != 0
    lib_wasi_threads_destroy();
#endif

#if WASM_ENABLE_WASI_NN != 0 || WASM_ENABLE_WASI_EPHEMERAL_NN != 0
    wasi_nn_destroy();
#endif

    node = g_native_symbols_list;
    while (node) {
        node_next = node->next;
        wasm_runtime_free(node);
        node = node_next;
    }

    g_native_symbols_list = NULL;
}

#if WASM_ENABLE_QUICK_AOT_ENTRY != 0
static void
invoke_no_args_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *) = func_ptr;
    native_code(exec_env);
}
static void
invoke_no_args_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *) = func_ptr;
    argv_ret[0] = native_code(exec_env);
}
static void
invoke_no_args_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *) = func_ptr;
    int64 ret = native_code(exec_env);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_i_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32) = func_ptr;
    native_code(exec_env, argv[0]);
}
static void
invoke_i_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0]);
}
static void
invoke_i_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32) = func_ptr;
    int64 ret = native_code(exec_env, argv[0]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_I_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv));
}
static void
invoke_I_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv));
}
static void
invoke_I_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_ii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32) = func_ptr;
    native_code(exec_env, argv[0], argv[1]);
}
static void
invoke_ii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0], argv[1]);
}
static void
invoke_ii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32) = func_ptr;
    int64 ret = native_code(exec_env, argv[0], argv[1]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iI_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int64) = func_ptr;
    native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1));
}
static void
invoke_iI_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int64) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1));
}
static void
invoke_iI_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int64) = func_ptr;
    int64 ret =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_Ii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int32) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2]);
}
static void
invoke_Ii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int32) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2]);
}
static void
invoke_Ii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int32) = func_ptr;
    int64 ret =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_II_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                GET_I64_FROM_ADDR((uint32 *)argv + 2));
}
static void
invoke_II_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              GET_I64_FROM_ADDR((uint32 *)argv + 2));
}
static void
invoke_II_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int64) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            GET_I64_FROM_ADDR((uint32 *)argv + 2));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32, int32) = func_ptr;
    native_code(exec_env, argv[0], argv[1], argv[2]);
}
static void
invoke_iii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0], argv[1], argv[2]);
}
static void
invoke_iii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32, int32) = func_ptr;
    int64 ret = native_code(exec_env, argv[0], argv[1], argv[2]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iiI_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32, int64) = func_ptr;
    native_code(exec_env, argv[0], argv[1],
                GET_I64_FROM_ADDR((uint32 *)argv + 2));
}
static void
invoke_iiI_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0], argv[1],
                              GET_I64_FROM_ADDR((uint32 *)argv + 2));
}
static void
invoke_iiI_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32, int64) = func_ptr;
    int64 ret = native_code(exec_env, argv[0], argv[1],
                            GET_I64_FROM_ADDR((uint32 *)argv + 2));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iIi_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int64, int32) = func_ptr;
    native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                argv[3]);
}
static void
invoke_iIi_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int64, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0],
                              GET_I64_FROM_ADDR((uint32 *)argv + 1), argv[3]);
}
static void
invoke_iIi_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int64, int32) = func_ptr;
    int64 ret = native_code(exec_env, argv[0],
                            GET_I64_FROM_ADDR((uint32 *)argv + 1), argv[3]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iII_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int64, int64) = func_ptr;
    native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                GET_I64_FROM_ADDR((uint32 *)argv + 3));
}
static void
invoke_iII_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int64, int64) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    GET_I64_FROM_ADDR((uint32 *)argv + 3));
}
static void
invoke_iII_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int64, int64) = func_ptr;
    int64 ret =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    GET_I64_FROM_ADDR((uint32 *)argv + 3));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_Iii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int32, int32) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2], argv[3]);
}
static void
invoke_Iii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int32, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              argv[2], argv[3]);
}
static void
invoke_Iii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int32, int32) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            argv[2], argv[3]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IiI_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int32, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2],
                GET_I64_FROM_ADDR((uint32 *)argv + 3));
}
static void
invoke_IiI_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int32, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              argv[2], GET_I64_FROM_ADDR((uint32 *)argv + 3));
}
static void
invoke_IiI_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int32, int64) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            argv[2], GET_I64_FROM_ADDR((uint32 *)argv + 3));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IIi_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int64, int32) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4]);
}
static void
invoke_IIi_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int64, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4]);
}
static void
invoke_IIi_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int64, int32) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_III_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int64, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                GET_I64_FROM_ADDR((uint32 *)argv + 2),
                GET_I64_FROM_ADDR((uint32 *)argv + 4));
}
static void
invoke_III_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int64, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              GET_I64_FROM_ADDR((uint32 *)argv + 2),
                              GET_I64_FROM_ADDR((uint32 *)argv + 4));
}
static void
invoke_III_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int64, int64) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            GET_I64_FROM_ADDR((uint32 *)argv + 2),
                            GET_I64_FROM_ADDR((uint32 *)argv + 4));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iiii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32, int32, int32) = func_ptr;
    native_code(exec_env, argv[0], argv[1], argv[2], argv[3]);
}
static void
invoke_iiii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32, int32, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0], argv[1], argv[2], argv[3]);
}
static void
invoke_iiii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32, int32, int32) = func_ptr;
    int64 ret = native_code(exec_env, argv[0], argv[1], argv[2], argv[3]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iiiI_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32, int32, int64) = func_ptr;
    native_code(exec_env, argv[0], argv[1], argv[2],
                GET_I64_FROM_ADDR((uint32 *)argv + 3));
}
static void
invoke_iiiI_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32, int32, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0], argv[1], argv[2],
                              GET_I64_FROM_ADDR((uint32 *)argv + 3));
}
static void
invoke_iiiI_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32, int32, int64) = func_ptr;
    int64 ret = native_code(exec_env, argv[0], argv[1], argv[2],
                            GET_I64_FROM_ADDR((uint32 *)argv + 3));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iiIi_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32, int64, int32) = func_ptr;
    native_code(exec_env, argv[0], argv[1],
                GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4]);
}
static void
invoke_iiIi_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32, int64, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0], argv[1],
                              GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4]);
}
static void
invoke_iiIi_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32, int64, int32) = func_ptr;
    int64 ret = native_code(exec_env, argv[0], argv[1],
                            GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iiII_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32, int64, int64) = func_ptr;
    native_code(exec_env, argv[0], argv[1],
                GET_I64_FROM_ADDR((uint32 *)argv + 2),
                GET_I64_FROM_ADDR((uint32 *)argv + 4));
}
static void
invoke_iiII_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32, int64, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, argv[0], argv[1],
                              GET_I64_FROM_ADDR((uint32 *)argv + 2),
                              GET_I64_FROM_ADDR((uint32 *)argv + 4));
}
static void
invoke_iiII_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32, int64, int64) = func_ptr;
    int64 ret = native_code(exec_env, argv[0], argv[1],
                            GET_I64_FROM_ADDR((uint32 *)argv + 2),
                            GET_I64_FROM_ADDR((uint32 *)argv + 4));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iIii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int64, int32, int32) = func_ptr;
    native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                argv[3], argv[4]);
}
static void
invoke_iIii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int64, int32, int32) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    argv[3], argv[4]);
}
static void
invoke_iIii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int64, int32, int32) = func_ptr;
    int64 ret =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    argv[3], argv[4]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iIiI_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int64, int32, int64) = func_ptr;
    native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                argv[3], GET_I64_FROM_ADDR((uint32 *)argv + 4));
}
static void
invoke_iIiI_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int64, int32, int64) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    argv[3], GET_I64_FROM_ADDR((uint32 *)argv + 4));
}
static void
invoke_iIiI_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int64, int32, int64) = func_ptr;
    int64 ret =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    argv[3], GET_I64_FROM_ADDR((uint32 *)argv + 4));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iIIi_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int64, int64, int32) = func_ptr;
    native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                GET_I64_FROM_ADDR((uint32 *)argv + 3), argv[5]);
}
static void
invoke_iIIi_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int64, int64, int32) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    GET_I64_FROM_ADDR((uint32 *)argv + 3), argv[5]);
}
static void
invoke_iIIi_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int64, int64, int32) = func_ptr;
    int64 ret =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    GET_I64_FROM_ADDR((uint32 *)argv + 3), argv[5]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iIII_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int64, int64, int64) = func_ptr;
    native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                GET_I64_FROM_ADDR((uint32 *)argv + 3),
                GET_I64_FROM_ADDR((uint32 *)argv + 5));
}
static void
invoke_iIII_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int64, int64, int64) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    GET_I64_FROM_ADDR((uint32 *)argv + 3),
                    GET_I64_FROM_ADDR((uint32 *)argv + 5));
}
static void
invoke_iIII_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int64, int64, int64) = func_ptr;
    int64 ret =
        native_code(exec_env, argv[0], GET_I64_FROM_ADDR((uint32 *)argv + 1),
                    GET_I64_FROM_ADDR((uint32 *)argv + 3),
                    GET_I64_FROM_ADDR((uint32 *)argv + 5));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_Iiii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int32, int32, int32) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2], argv[3],
                argv[4]);
}
static void
invoke_Iiii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int32, int32, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              argv[2], argv[3], argv[4]);
}
static void
invoke_Iiii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int32, int32, int32) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            argv[2], argv[3], argv[4]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IiiI_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int32, int32, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2], argv[3],
                GET_I64_FROM_ADDR((uint32 *)argv + 4));
}

static void
invoke_IiiI_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int32, int32, int64) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2],
                    argv[3], GET_I64_FROM_ADDR((uint32 *)argv + 4));
}

static void
invoke_IiiI_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int32, int32, int64) = func_ptr;
    int64 ret =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2],
                    argv[3], GET_I64_FROM_ADDR((uint32 *)argv + 4));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IiIi_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int32, int64, int32) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2],
                GET_I64_FROM_ADDR((uint32 *)argv + 3), argv[5]);
}
static void
invoke_IiIi_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int32, int64, int32) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2],
                    GET_I64_FROM_ADDR((uint32 *)argv + 3), argv[5]);
}
static void
invoke_IiIi_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int32, int64, int32) = func_ptr;
    int64 ret =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2],
                    GET_I64_FROM_ADDR((uint32 *)argv + 3), argv[5]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IiII_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int32, int64, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv), argv[2],
                GET_I64_FROM_ADDR((uint32 *)argv + 3),
                GET_I64_FROM_ADDR((uint32 *)argv + 5));
}
static void
invoke_IiII_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int32, int64, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              argv[2], GET_I64_FROM_ADDR((uint32 *)argv + 3),
                              GET_I64_FROM_ADDR((uint32 *)argv + 5));
}
static void
invoke_IiII_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int32, int64, int64) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            argv[2], GET_I64_FROM_ADDR((uint32 *)argv + 3),
                            GET_I64_FROM_ADDR((uint32 *)argv + 5));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IIii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int64, int32, int32) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4], argv[5]);
}
static void
invoke_IIii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int64, int32, int32) = func_ptr;
    argv_ret[0] =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                    GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4], argv[5]);
}
static void
invoke_IIii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int64, int32, int32) = func_ptr;
    int64 ret =
        native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                    GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4], argv[5]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IIiI_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int64, int32, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4],
                GET_I64_FROM_ADDR((uint32 *)argv + 5));
}
static void
invoke_IIiI_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int64, int32, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4],
                              GET_I64_FROM_ADDR((uint32 *)argv + 5));
}
static void
invoke_IIiI_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int64, int32, int64) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            GET_I64_FROM_ADDR((uint32 *)argv + 2), argv[4],
                            GET_I64_FROM_ADDR((uint32 *)argv + 5));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IIIi_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int64, int64, int32) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                GET_I64_FROM_ADDR((uint32 *)argv + 2),
                GET_I64_FROM_ADDR((uint32 *)argv + 4), argv[6]);
}
static void
invoke_IIIi_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int64, int64, int32) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              GET_I64_FROM_ADDR((uint32 *)argv + 2),
                              GET_I64_FROM_ADDR((uint32 *)argv + 4), argv[6]);
}
static void
invoke_IIIi_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int64, int64, int32) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            GET_I64_FROM_ADDR((uint32 *)argv + 2),
                            GET_I64_FROM_ADDR((uint32 *)argv + 4), argv[6]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_IIII_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int64, int64, int64, int64) = func_ptr;
    native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                GET_I64_FROM_ADDR((uint32 *)argv + 2),
                GET_I64_FROM_ADDR((uint32 *)argv + 4),
                GET_I64_FROM_ADDR((uint32 *)argv + 6));
}
static void
invoke_IIII_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int64, int64, int64, int64) = func_ptr;
    argv_ret[0] = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                              GET_I64_FROM_ADDR((uint32 *)argv + 2),
                              GET_I64_FROM_ADDR((uint32 *)argv + 4),
                              GET_I64_FROM_ADDR((uint32 *)argv + 6));
}
static void
invoke_IIII_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int64, int64, int64, int64) = func_ptr;
    int64 ret = native_code(exec_env, GET_I64_FROM_ADDR((uint32 *)argv),
                            GET_I64_FROM_ADDR((uint32 *)argv + 2),
                            GET_I64_FROM_ADDR((uint32 *)argv + 4),
                            GET_I64_FROM_ADDR((uint32 *)argv + 6));
    PUT_I64_TO_ADDR(argv_ret, ret);
}

static void
invoke_iiiii_v(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    void (*native_code)(WASMExecEnv *, int32, int32, int32, int32, int32) =
        func_ptr;
    native_code(exec_env, argv[0], argv[1], argv[2], argv[3], argv[4]);
}
static void
invoke_iiiii_i(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int32 (*native_code)(WASMExecEnv *, int32, int32, int32, int32, int32) =
        func_ptr;
    argv_ret[0] =
        native_code(exec_env, argv[0], argv[1], argv[2], argv[3], argv[4]);
}
static void
invoke_iiiii_I(void *func_ptr, void *exec_env, int32 *argv, int32 *argv_ret)
{
    int64 (*native_code)(WASMExecEnv *, int32, int32, int32, int32, int32) =
        func_ptr;
    int64 ret =
        native_code(exec_env, argv[0], argv[1], argv[2], argv[3], argv[4]);
    PUT_I64_TO_ADDR(argv_ret, ret);
}

typedef struct QuickAOTEntry {
    const char *signature;
    void *func_ptr;
} QuickAOTEntry;

/* clang-format off */
static QuickAOTEntry quick_aot_entries[] = {
    { "()v", invoke_no_args_v },
    { "()i", invoke_no_args_i },
    { "()I", invoke_no_args_I },

    { "(i)v", invoke_i_v }, { "(i)i", invoke_i_i }, { "(i)I", invoke_i_I },
    { "(I)v", invoke_I_v }, { "(I)i", invoke_I_i }, { "(I)I", invoke_I_I },

    { "(ii)v", invoke_ii_v }, { "(ii)i", invoke_ii_i }, { "(ii)I", invoke_ii_I },
    { "(iI)v", invoke_iI_v }, { "(iI)i", invoke_iI_i }, { "(iI)I", invoke_iI_I },
    { "(Ii)v", invoke_Ii_v }, { "(Ii)i", invoke_Ii_i }, { "(Ii)I", invoke_Ii_I },
    { "(II)v", invoke_II_v }, { "(II)i", invoke_II_i }, { "(II)I", invoke_II_I },

    { "(iii)v", invoke_iii_v }, { "(iii)i", invoke_iii_i }, { "(iii)I", invoke_iii_I },
    { "(iiI)v", invoke_iiI_v }, { "(iiI)i", invoke_iiI_i }, { "(iiI)I", invoke_iiI_I },
    { "(iIi)v", invoke_iIi_v }, { "(iIi)i", invoke_iIi_i }, { "(iIi)I", invoke_iIi_I },
    { "(iII)v", invoke_iII_v }, { "(iII)i", invoke_iII_i }, { "(iII)I", invoke_iII_I },
    { "(Iii)v", invoke_Iii_v }, { "(Iii)i", invoke_Iii_i }, { "(Iii)I", invoke_Iii_I },
    { "(IiI)v", invoke_IiI_v }, { "(IiI)i", invoke_IiI_i }, { "(IiI)I", invoke_IiI_I },
    { "(IIi)v", invoke_IIi_v }, { "(IIi)i", invoke_IIi_i }, { "(IIi)I", invoke_IIi_I },
    { "(III)v", invoke_III_v }, { "(III)i", invoke_III_i }, { "(III)I", invoke_III_I },

    { "(iiii)v", invoke_iiii_v }, { "(iiii)i", invoke_iiii_i }, { "(iiii)I", invoke_iiii_I },
    { "(iiiI)v", invoke_iiiI_v }, { "(iiiI)i", invoke_iiiI_i }, { "(iiiI)I", invoke_iiiI_I },
    { "(iiIi)v", invoke_iiIi_v }, { "(iiIi)i", invoke_iiIi_i }, { "(iiIi)I", invoke_iiIi_I },
    { "(iiII)v", invoke_iiII_v }, { "(iiII)i", invoke_iiII_i }, { "(iiII)I", invoke_iiII_I },
    { "(iIii)v", invoke_iIii_v }, { "(iIii)i", invoke_iIii_i }, { "(iIii)I", invoke_iIii_I },
    { "(iIiI)v", invoke_iIiI_v }, { "(iIiI)i", invoke_iIiI_i }, { "(iIiI)I", invoke_iIiI_I },
    { "(iIIi)v", invoke_iIIi_v }, { "(iIIi)i", invoke_iIIi_i }, { "(iIIi)I", invoke_iIIi_I },
    { "(iIII)v", invoke_iIII_v }, { "(iIII)i", invoke_iIII_i }, { "(iIII)I", invoke_iIII_I },
    { "(Iiii)v", invoke_Iiii_v }, { "(Iiii)i", invoke_Iiii_i }, { "(Iiii)I", invoke_Iiii_I },
    { "(IiiI)v", invoke_IiiI_v }, { "(IiiI)i", invoke_IiiI_i }, { "(IiiI)I", invoke_IiiI_I },
    { "(IiIi)v", invoke_IiIi_v }, { "(IiIi)i", invoke_IiIi_i }, { "(IiIi)I", invoke_IiIi_I },
    { "(IiII)v", invoke_IiII_v }, { "(IiII)i", invoke_IiII_i }, { "(IiII)I", invoke_IiII_I },
    { "(IIii)v", invoke_IIii_v }, { "(IIii)i", invoke_IIii_i }, { "(IIii)I", invoke_IIii_I },
    { "(IIiI)v", invoke_IIiI_v }, { "(IIiI)i", invoke_IIiI_i }, { "(IIiI)I", invoke_IIiI_I },
    { "(IIIi)v", invoke_IIIi_v }, { "(IIIi)i", invoke_IIIi_i }, { "(IIIi)I", invoke_IIIi_I },
    { "(IIII)v", invoke_IIII_v }, { "(IIII)i", invoke_IIII_i }, { "(IIII)I", invoke_IIII_I },

    { "(iiiii)v", invoke_iiiii_v }, { "(iiiii)i", invoke_iiiii_i }, { "(iiiii)I", invoke_iiiii_I },
};
/* clang-format on */

static int
quick_aot_entry_cmp(const void *quick_aot_entry1, const void *quick_aot_entry2)
{
    return strcmp(((const QuickAOTEntry *)quick_aot_entry1)->signature,
                  ((const QuickAOTEntry *)quick_aot_entry2)->signature);
}

static bool
quick_aot_entry_init(void)
{
    qsort(quick_aot_entries, sizeof(quick_aot_entries) / sizeof(QuickAOTEntry),
          sizeof(QuickAOTEntry), quick_aot_entry_cmp);

    return true;
}

void *
wasm_native_lookup_quick_aot_entry(const WASMFuncType *func_type)
{
    char signature[16] = { 0 };
    uint32 param_count = func_type->param_count;
    uint32 result_count = func_type->result_count, i, j = 0;
    const uint8 *types = func_type->types;
    QuickAOTEntry *quick_aot_entry, key = { 0 };

    if (param_count > 5 || result_count > 1)
        return NULL;

    signature[j++] = '(';

    for (i = 0; i < param_count; i++) {
        if (types[i] == VALUE_TYPE_I32)
            signature[j++] = 'i';
        else if (types[i] == VALUE_TYPE_I64)
            signature[j++] = 'I';
        else
            return NULL;
    }

    signature[j++] = ')';

    if (result_count == 0) {
        signature[j++] = 'v';
    }
    else {
        if (types[i] == VALUE_TYPE_I32)
            signature[j++] = 'i';
        else if (types[i] == VALUE_TYPE_I64)
            signature[j++] = 'I';
        else
            return NULL;
    }

    key.signature = signature;
    if ((quick_aot_entry =
             bsearch(&key, quick_aot_entries,
                     sizeof(quick_aot_entries) / sizeof(QuickAOTEntry),
                     sizeof(QuickAOTEntry), quick_aot_entry_cmp))) {
        return quick_aot_entry->func_ptr;
    }

    return NULL;
}
#endif /* end of WASM_ENABLE_QUICK_AOT_ENTRY != 0 */
