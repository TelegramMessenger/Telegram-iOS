/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_platform.h"
#if WASM_ENABLE_INTERP != 0
#include "../interpreter/wasm_runtime.h"
#endif
#if WASM_ENABLE_AOT != 0
#include "../aot/aot_runtime.h"
#endif
#if WASM_ENABLE_THREAD_MGR != 0
#include "../libraries/thread-mgr/thread_manager.h"
#endif
#if WASM_ENABLE_GC != 0
#include "gc/gc_object.h"
#if WASM_ENABLE_STRINGREF != 0
#include "string_object.h"
#endif
#if WASM_ENABLE_GC_PERF_PROFILING != 0
#include "../../shared/mem-alloc/mem_alloc.h"
#endif
#endif

static void
set_error_buf(char *error_buf, uint32 error_buf_size, const char *string)
{
    if (error_buf != NULL)
        snprintf(error_buf, error_buf_size, "%s", string);
}

static void *
runtime_malloc(uint64 size, WASMModuleInstanceCommon *module_inst,
               char *error_buf, uint32 error_buf_size)
{
    void *mem;

    if (size >= UINT32_MAX || !(mem = wasm_runtime_malloc((uint32)size))) {
        if (module_inst != NULL) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
        }
        else if (error_buf != NULL) {
            set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        }
        return NULL;
    }

    memset(mem, 0, (uint32)size);
    return mem;
}

static union {
    int a;
    char b;
} __ue = { .a = 1 };

#define is_little_endian() (__ue.b == 1) /* NOLINT */

/**
 * Implementation of wasm_application_execute_main()
 */
static bool
check_main_func_type(const WASMFuncType *type, bool is_memory64)
{
    if (!(type->param_count == 0 || type->param_count == 2)
        || type->result_count > 1) {
        LOG_ERROR(
            "WASM execute application failed: invalid main function type.\n");
        return false;
    }

    if (type->param_count == 2
        && !(type->types[0] == VALUE_TYPE_I32
             && type->types[1]
                    == (is_memory64 ? VALUE_TYPE_I64 : VALUE_TYPE_I32))) {
        LOG_ERROR(
            "WASM execute application failed: invalid main function type.\n");
        return false;
    }

    if (type->result_count
        && type->types[type->param_count] != VALUE_TYPE_I32) {
        LOG_ERROR(
            "WASM execute application failed: invalid main function type.\n");
        return false;
    }

    return true;
}

static bool
execute_main(WASMModuleInstanceCommon *module_inst, int32 argc, char *argv[])
{
    WASMFunctionInstanceCommon *func;
    WASMFuncType *func_type = NULL;
    WASMExecEnv *exec_env = NULL;
    uint32 argc1 = 0, argv1[3] = { 0 };
    uint32 total_argv_size = 0;
    uint64 total_size;
    uint64 argv_buf_offset = 0;
    int32 i;
    char *argv_buf, *p, *p_end;
    uint32 *argv_offsets, module_type;
    bool ret, is_import_func = true, is_memory64 = false;
#if WASM_ENABLE_MEMORY64 != 0
    WASMModuleInstance *wasm_module_inst = (WASMModuleInstance *)module_inst;
    if (wasm_module_inst->memory_count > 0)
        is_memory64 = wasm_module_inst->memories[0]->is_memory64;
#endif

    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (!exec_env) {
        wasm_runtime_set_exception(module_inst,
                                   "create singleton exec_env failed");
        return false;
    }

#if WASM_ENABLE_LIBC_WASI != 0
    /* In wasi mode, we should call the function named "_start"
       which initializes the wasi environment and then calls
       the actual main function. Directly calling main function
       may cause exception thrown. */
    if ((func = wasm_runtime_lookup_wasi_start_function(module_inst))) {
        const char *wasi_proc_exit_exception = "wasi proc exit";

        ret = wasm_runtime_call_wasm(exec_env, func, 0, NULL);
#if WASM_ENABLE_THREAD_MGR != 0
        if (ret) {
            /* On a successful return from the `_start` function,
               we terminate other threads by mimicking wasi:proc_exit(0).

               Note:
               - A return from the `main` function is an equivalent of
                 exit(). (C standard)
               - When exit code is 0, wasi-libc's `_start` function just
                 returns w/o calling `proc_exit`.
               - A process termination should terminate threads in
                 the process. */

            wasm_runtime_set_exception(module_inst, wasi_proc_exit_exception);
            /* exit_code is zero-initialized */
            ret = false;
        }
#endif
        /* report wasm proc exit as a success */
        WASMModuleInstance *inst = (WASMModuleInstance *)module_inst;
        if (!ret && strstr(inst->cur_exception, wasi_proc_exit_exception)) {
            inst->cur_exception[0] = 0;
            ret = true;
        }
        return ret;
    }
#endif /* end of WASM_ENABLE_LIBC_WASI */

    if (!(func = wasm_runtime_lookup_function(module_inst, "main"))
        && !(func =
                 wasm_runtime_lookup_function(module_inst, "__main_argc_argv"))
        && !(func = wasm_runtime_lookup_function(module_inst, "_main"))) {
#if WASM_ENABLE_LIBC_WASI != 0
        wasm_runtime_set_exception(
            module_inst, "lookup the entry point symbol (like _start, main, "
                         "_main, __main_argc_argv) failed");
#else
        wasm_runtime_set_exception(module_inst,
                                   "lookup the entry point symbol (like main, "
                                   "_main, __main_argc_argv) failed");
#endif
        return false;
    }

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        is_import_func = ((WASMFunctionInstance *)func)->is_import_func;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        is_import_func = ((AOTFunctionInstance *)func)->is_import_func;
    }
#endif

    if (is_import_func) {
        wasm_runtime_set_exception(module_inst, "lookup main function failed");
        return false;
    }

    module_type = module_inst->module_type;
    func_type = wasm_runtime_get_function_type(func, module_type);

    if (!func_type) {
        LOG_ERROR("invalid module instance type");
        return false;
    }

    if (!check_main_func_type(func_type, is_memory64)) {
        wasm_runtime_set_exception(module_inst,
                                   "invalid function type of main function");
        return false;
    }

    if (func_type->param_count) {
        for (i = 0; i < argc; i++)
            total_argv_size += (uint32)(strlen(argv[i]) + 1);
#if WASM_ENABLE_MEMORY64 != 0
        if (is_memory64)
            /* `char **argv` is an array of 64-bit elements in memory64 */
            total_argv_size = align_uint(total_argv_size, 8);
        else
#endif
            total_argv_size = align_uint(total_argv_size, 4);

#if WASM_ENABLE_MEMORY64 != 0
        if (is_memory64)
            /* `char **argv` is an array of 64-bit elements in memory64 */
            total_size =
                (uint64)total_argv_size + sizeof(uint64) * (uint64)argc;
        else
#endif
            total_size =
                (uint64)total_argv_size + sizeof(uint32) * (uint64)argc;

        if (total_size >= UINT32_MAX
            || !(argv_buf_offset = wasm_runtime_module_malloc(
                     module_inst, total_size, (void **)&argv_buf))) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
            return false;
        }

        p = argv_buf;
        argv_offsets = (uint32 *)(p + total_argv_size);
        p_end = p + total_size;

        for (i = 0; i < argc; i++) {
            bh_memcpy_s(p, (uint32)(p_end - p), argv[i],
                        (uint32)(strlen(argv[i]) + 1));
#if WASM_ENABLE_MEMORY64 != 0
            if (is_memory64)
                /* `char **argv` is an array of 64-bit elements in memory64 */
                ((uint64 *)argv_offsets)[i] =
                    (uint32)argv_buf_offset + (uint32)(p - argv_buf);
            else
#endif
                argv_offsets[i] =
                    (uint32)argv_buf_offset + (uint32)(p - argv_buf);
            p += strlen(argv[i]) + 1;
        }

        argv1[0] = (uint32)argc;
#if WASM_ENABLE_MEMORY64 != 0
        if (is_memory64) {
            argc1 = 3;
            uint64 app_addr =
                wasm_runtime_addr_native_to_app(module_inst, argv_offsets);
            PUT_I64_TO_ADDR(&argv[1], app_addr);
        }
        else
#endif
        {
            argc1 = 2;
            argv1[1] = (uint32)wasm_runtime_addr_native_to_app(module_inst,
                                                               argv_offsets);
        }
    }

    ret = wasm_runtime_call_wasm(exec_env, func, argc1, argv1);
    if (ret && func_type->result_count > 0 && argc > 0 && argv)
        /* copy the return value */
        *(int *)argv = (int)argv1[0];

    if (argv_buf_offset)
        wasm_runtime_module_free(module_inst, argv_buf_offset);

    return ret;
}

bool
wasm_application_execute_main(WASMModuleInstanceCommon *module_inst, int32 argc,
                              char *argv[])
{
    bool ret;
#if (WASM_ENABLE_MEMORY_PROFILING != 0)
    WASMExecEnv *exec_env;
#endif

    ret = execute_main(module_inst, argc, argv);

#if WASM_ENABLE_MEMORY_PROFILING != 0
    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (exec_env) {
        wasm_runtime_dump_mem_consumption(exec_env);
    }
#endif

#if WASM_ENABLE_GC_PERF_PROFILING != 0
    void *handle = wasm_runtime_get_gc_heap_handle(module_inst);
    mem_allocator_dump_perf_profiling(handle);
#endif

#if WASM_ENABLE_PERF_PROFILING != 0
    wasm_runtime_dump_perf_profiling(module_inst);
#endif

    if (ret)
        ret = wasm_runtime_get_exception(module_inst) == NULL;

    return ret;
}

/**
 * Implementation of wasm_application_execute_func()
 */

union ieee754_float {
    float f;

    /* This is the IEEE 754 single-precision format.  */
    union {
        struct {
            unsigned int negative : 1;
            unsigned int exponent : 8;
            unsigned int mantissa : 23;
        } ieee_big_endian;
        struct {
            unsigned int mantissa : 23;
            unsigned int exponent : 8;
            unsigned int negative : 1;
        } ieee_little_endian;
    } ieee;
};

union ieee754_double {
    double d;

    /* This is the IEEE 754 double-precision format.  */
    union {
        struct {
            unsigned int negative : 1;
            unsigned int exponent : 11;
            /* Together these comprise the mantissa.  */
            unsigned int mantissa0 : 20;
            unsigned int mantissa1 : 32;
        } ieee_big_endian;

        struct {
            /* Together these comprise the mantissa.  */
            unsigned int mantissa1 : 32;
            unsigned int mantissa0 : 20;
            unsigned int exponent : 11;
            unsigned int negative : 1;
        } ieee_little_endian;
    } ieee;
};

static bool
execute_func(WASMModuleInstanceCommon *module_inst, const char *name,
             int32 argc, char *argv[])
{
    WASMFunctionInstanceCommon *target_func;
    WASMFuncType *type = NULL;
    WASMExecEnv *exec_env = NULL;
#if WASM_ENABLE_GC != 0
    WASMRefTypeMap *ref_type_map;
    WASMLocalObjectRef *local_ref;
    uint32 num_local_ref_pushed = 0;
#endif
    uint32 argc1, *argv1 = NULL, cell_num = 0, j, k = 0;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    uint32 param_size_in_double_world = 0, result_size_in_double_world = 0;
#endif
    int32 i, p, module_type;
    uint64 total_size;
    char buf[128];

    bh_assert(argc >= 0);
    LOG_DEBUG("call a function \"%s\" with %d arguments", name, argc);

    if (!(target_func = wasm_runtime_lookup_function(module_inst, name))) {
        snprintf(buf, sizeof(buf), "lookup function %s failed", name);
        wasm_runtime_set_exception(module_inst, buf);
        goto fail;
    }

    module_type = module_inst->module_type;
    type = wasm_runtime_get_function_type(target_func, module_type);

    if (!type) {
        LOG_ERROR("invalid module instance type");
        return false;
    }

    if (type->param_count != (uint32)argc) {
        wasm_runtime_set_exception(module_inst, "invalid input argument count");
        goto fail;
    }

    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (!exec_env) {
        wasm_runtime_set_exception(module_inst,
                                   "create singleton exec_env failed");
        goto fail;
    }

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    for (i = 0; i < type->param_count; i++) {
        param_size_in_double_world +=
            wasm_value_type_cell_num_outside(type->types[i]);
    }
    for (i = 0; i < type->result_count; i++) {
        result_size_in_double_world += wasm_value_type_cell_num_outside(
            type->types[type->param_count + i]);
    }
    argc1 = param_size_in_double_world;
    cell_num = (param_size_in_double_world >= result_size_in_double_world)
                   ? param_size_in_double_world
                   : result_size_in_double_world;
#else
    argc1 = type->param_cell_num;
    cell_num = (argc1 > type->ret_cell_num) ? argc1 : type->ret_cell_num;
#endif

    total_size = sizeof(uint32) * (uint64)(cell_num > 2 ? cell_num : 2);
    if ((!(argv1 = runtime_malloc((uint32)total_size, module_inst, NULL, 0)))) {
        goto fail;
    }

#if WASM_ENABLE_GC != 0
    ref_type_map = type->ref_type_maps;
#endif
    /* Parse arguments */
    for (i = 0, p = 0; i < argc; i++) {
        char *endptr = NULL;
        bh_assert(argv[i] != NULL);
        if (argv[i][0] == '\0') {
            snprintf(buf, sizeof(buf), "invalid input argument %" PRId32, i);
            wasm_runtime_set_exception(module_inst, buf);
            goto fail;
        }
        switch (type->types[i]) {
            case VALUE_TYPE_I32:
                argv1[p++] = (uint32)strtoul(argv[i], &endptr, 0);
                break;
            case VALUE_TYPE_I64:
            {
                union {
                    uint64 val;
                    uint32 parts[2];
                } u;
                u.val = strtoull(argv[i], &endptr, 0);
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
                break;
            }
            case VALUE_TYPE_F32:
            {
                float32 f32 = strtof(argv[i], &endptr);
                if (isnan(f32)) {
#ifdef _MSC_VER
                    /*
                     * Spec tests require the binary representation of NaN to be
                     * 0x7fc00000 for float and 0x7ff8000000000000 for float;
                     * however, in MSVC compiler, strtof doesn't return this
                     * exact value, causing some of the spec test failures. We
                     * use the value returned by nan/nanf as it is the one
                     * expected by spec tests.
                     *
                     */
                    f32 = nanf("");
#endif
                    if (argv[i][0] == '-') {
                        union ieee754_float u;
                        u.f = f32;
                        if (is_little_endian())
                            u.ieee.ieee_little_endian.negative = 1;
                        else
                            u.ieee.ieee_big_endian.negative = 1;
                        bh_memcpy_s(&f32, sizeof(float), &u.f, sizeof(float));
                    }
                    if (endptr[0] == ':') {
                        uint32 sig;
                        union ieee754_float u;
                        sig = (uint32)strtoul(endptr + 1, &endptr, 0);
                        u.f = f32;
                        if (is_little_endian())
                            u.ieee.ieee_little_endian.mantissa = sig;
                        else
                            u.ieee.ieee_big_endian.mantissa = sig;
                        bh_memcpy_s(&f32, sizeof(float), &u.f, sizeof(float));
                    }
                }
                bh_memcpy_s(&argv1[p], (uint32)total_size - p, &f32,
                            (uint32)sizeof(float));
                p++;
                break;
            }
            case VALUE_TYPE_F64:
            {
                union {
                    float64 val;
                    uint32 parts[2];
                } u;
                u.val = strtod(argv[i], &endptr);
                if (isnan(u.val)) {
#ifdef _MSC_VER
                    u.val = nan("");
#endif
                    if (argv[i][0] == '-') {
                        union ieee754_double ud;
                        ud.d = u.val;
                        if (is_little_endian())
                            ud.ieee.ieee_little_endian.negative = 1;
                        else
                            ud.ieee.ieee_big_endian.negative = 1;
                        bh_memcpy_s(&u.val, sizeof(double), &ud.d,
                                    sizeof(double));
                    }
                    if (endptr && endptr[0] == ':') {
                        uint64 sig;
                        union ieee754_double ud;
                        sig = strtoull(endptr + 1, &endptr, 0);
                        ud.d = u.val;
                        if (is_little_endian()) {
                            ud.ieee.ieee_little_endian.mantissa0 = sig >> 32;
                            ud.ieee.ieee_little_endian.mantissa1 = (uint32)sig;
                        }
                        else {
                            ud.ieee.ieee_big_endian.mantissa0 = sig >> 32;
                            ud.ieee.ieee_big_endian.mantissa1 = (uint32)sig;
                        }
                        bh_memcpy_s(&u.val, sizeof(double), &ud.d,
                                    sizeof(double));
                    }
                }
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
                break;
            }
#if WASM_ENABLE_SIMD != 0
            case VALUE_TYPE_V128:
            {
                /* it likes 0x123\0x234 or 123\234 */
                /* retrieve first i64 */
                *(uint64 *)(argv1 + p) = strtoull(argv[i], &endptr, 0);
                /* skip \ */
                endptr++;
                /* retrieve second i64 */
                *(uint64 *)(argv1 + p + 2) = strtoull(endptr, &endptr, 0);
                p += 4;
                break;
            }
#endif /* WASM_ENABLE_SIMD != 0 */
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#if UINTPTR_MAX == UINT32_MAX
            case VALUE_TYPE_EXTERNREF:
#endif
            {
                if (strncasecmp(argv[i], "null", 4) == 0) {
                    argv1[p++] = (uint32)-1;
                }
                else {
                    argv1[p++] = (uint32)strtoul(argv[i], &endptr, 0);
                }
                break;
            }
#if UINTPTR_MAX == UINT64_MAX
            case VALUE_TYPE_EXTERNREF:
            {
                union {
                    uintptr_t val;
                    uint32 parts[2];
                } u;
                if (strncasecmp(argv[i], "null", 4) == 0) {
                    u.val = (uintptr_t)-1LL;
                }
                else {
                    u.val = strtoull(argv[i], &endptr, 0);
                }
                argv1[p++] = u.parts[0];
                argv1[p++] = u.parts[1];
                break;
            }
#endif
#endif /* WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0 */
            default:
            {
#if WASM_ENABLE_GC != 0
                bool is_extern_ref = false;
                bool is_anyref = false;

                if (wasm_is_type_reftype(type->types[i])) {
                    if (strncasecmp(argv[i], "null", 4) == 0) {
                        PUT_REF_TO_ADDR(argv1 + p, NULL_REF);
                        p += REF_CELL_NUM;
                        break;
                    }
                    else if (type->types[i] == VALUE_TYPE_EXTERNREF) {
                        is_extern_ref = true;
                    }
                    else if (type->types[i] == VALUE_TYPE_ANYREF) {
                        is_anyref = true;
                    }

                    if (wasm_is_type_multi_byte_type(type->types[i])) {
                        WASMRefType *ref_type = ref_type_map->ref_type;
                        if (wasm_is_refheaptype_common(
                                &ref_type->ref_ht_common)) {
                            int32 heap_type = ref_type->ref_ht_common.heap_type;
                            if (heap_type == HEAP_TYPE_EXTERN) {
                                is_extern_ref = true;
                            }
                            else if (heap_type == HEAP_TYPE_ANY) {
                                is_anyref = true;
                            }
                        }

                        ref_type_map++;
                    }

                    if (is_extern_ref) {
                        WASMExternrefObjectRef gc_obj;
                        void *extern_obj =
                            (void *)(uintptr_t)strtoull(argv[i], &endptr, 0);
                        gc_obj = wasm_externref_obj_new(exec_env, extern_obj);
                        if (!gc_obj) {
                            wasm_runtime_set_exception(
                                module_inst, "create extern object failed");
                            goto fail;
                        }
                        if (!(local_ref =
                                  runtime_malloc(sizeof(WASMLocalObjectRef),
                                                 module_inst, NULL, 0))) {
                            goto fail;
                        }
                        wasm_runtime_push_local_obj_ref(exec_env, local_ref);
                        local_ref->val = (WASMObjectRef)gc_obj;
                        num_local_ref_pushed++;
                        PUT_REF_TO_ADDR(argv1 + p, gc_obj);
                        p += REF_CELL_NUM;
                    }
                    else if (is_anyref) {
                        /* If a parameter type is (ref null? any) and its value
                         * is not null, then we treat the value as host ptr */
                        WASMAnyrefObjectRef gc_obj;
                        void *host_obj =
                            (void *)(uintptr_t)strtoull(argv[i], &endptr, 0);
                        gc_obj = wasm_anyref_obj_new(exec_env, host_obj);
                        if (!gc_obj) {
                            wasm_runtime_set_exception(
                                module_inst, "create anyref object failed");
                            goto fail;
                        }
                        if (!(local_ref =
                                  runtime_malloc(sizeof(WASMLocalObjectRef),
                                                 module_inst, NULL, 0))) {
                            goto fail;
                        }
                        wasm_runtime_push_local_obj_ref(exec_env, local_ref);
                        local_ref->val = (WASMObjectRef)gc_obj;
                        num_local_ref_pushed++;
                        PUT_REF_TO_ADDR(argv1 + p, gc_obj);
                        p += REF_CELL_NUM;
                    }

                    break;
                }
#endif /* end of WASM_ENABLE_GC != 0 */
                bh_assert(0);
                break;
            }
        }
        if (endptr && *endptr != '\0' && *endptr != '_') {
            snprintf(buf, sizeof(buf), "invalid input argument %" PRId32 ": %s",
                     i, argv[i]);
            wasm_runtime_set_exception(module_inst, buf);
            goto fail;
        }
    }

    wasm_runtime_set_exception(module_inst, NULL);
#if WASM_ENABLE_REF_TYPES == 0 && WASM_ENABLE_GC == 0
    bh_assert(p == (int32)argc1);
#endif

    if (!wasm_runtime_call_wasm(exec_env, target_func, argc1, argv1)) {
        goto fail;
    }

#if WASM_ENABLE_GC != 0
    ref_type_map = type->result_ref_type_maps;
#endif
    /* print return value */
    for (j = 0; j < type->result_count; j++) {
        switch (type->types[type->param_count + j]) {
            case VALUE_TYPE_I32:
            {
                os_printf("0x%" PRIx32 ":i32", argv1[k]);
                k++;
                break;
            }
            case VALUE_TYPE_I64:
            {
                union {
                    uint64 val;
                    uint32 parts[2];
                } u;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                os_printf("0x%" PRIx64 ":i64", u.val);
                break;
            }
            case VALUE_TYPE_F32:
            {
                os_printf("%.7g:f32", *(float32 *)(argv1 + k));
                k++;
                break;
            }
            case VALUE_TYPE_F64:
            {
                union {
                    float64 val;
                    uint32 parts[2];
                } u;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                os_printf("%.7g:f64", u.val);
                break;
            }
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
            {
                if (argv1[k] != NULL_REF)
                    os_printf("%" PRIu32 ":ref.func", argv1[k]);
                else
                    os_printf("func:ref.null");
                k++;
                break;
            }
            case VALUE_TYPE_EXTERNREF:
            {
#if UINTPTR_MAX == UINT32_MAX
                if (argv1[k] != 0 && argv1[k] != (uint32)-1)
                    os_printf("0x%" PRIxPTR ":ref.extern", (uintptr_t)argv1[k]);
                else
                    os_printf("extern:ref.null");
                k++;
#else
                union {
                    uintptr_t val;
                    uint32 parts[2];
                } u;
                u.parts[0] = argv1[k];
                u.parts[1] = argv1[k + 1];
                k += 2;
                if (u.val && u.val != (uintptr_t)-1LL)
                    os_printf("0x%" PRIxPTR ":ref.extern", u.val);
                else
                    os_printf("extern:ref.null");
#endif
                break;
            }
#endif /* end of WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0 */
#if WASM_ENABLE_SIMD != 0
            case VALUE_TYPE_V128:
            {
                uint64 *v = (uint64 *)(argv1 + k);
                os_printf("<0x%016" PRIx64 " 0x%016" PRIx64 ">:v128", *v,
                          *(v + 1));
                k += 4;
                break;
            }
#endif /*  WASM_ENABLE_SIMD != 0 */
            default:
            {
#if WASM_ENABLE_GC != 0
                if (wasm_is_type_reftype(type->types[type->param_count + j])) {
                    void *gc_obj = GET_REF_FROM_ADDR(argv1 + k);
                    k += REF_CELL_NUM;
                    if (!gc_obj) {
                        uint8 type1 = type->types[type->param_count + j];
                        WASMRefType *ref_type1 = NULL;
                        WASMType **types = NULL;
                        uint32 type_count = 0;

                        if (wasm_is_type_multi_byte_type(
                                type->types[type->param_count + j]))
                            ref_type1 = ref_type_map->ref_type;

#if WASM_ENABLE_INTERP != 0
                        if (module_inst->module_type == Wasm_Module_Bytecode) {
                            WASMModule *module =
                                ((WASMModuleInstance *)module_inst)->module;
                            types = module->types;
                            type_count = module->type_count;
                        }
#endif
#if WASM_ENABLE_AOT != 0
                        if (module_inst->module_type == Wasm_Module_AoT) {
                            AOTModule *module =
                                (AOTModule *)((AOTModuleInstance *)module_inst)
                                    ->module;
                            types = module->types;
                            type_count = module->type_count;
                        }
#endif
                        bh_assert(type);
                        if (wasm_reftype_is_subtype_of(type1, ref_type1,
                                                       REF_TYPE_ANYREF, NULL,
                                                       types, type_count))
                            os_printf("any:");
                        else if (wasm_reftype_is_subtype_of(
                                     type1, ref_type1, REF_TYPE_FUNCREF, NULL,
                                     types, type_count))
                            os_printf("func:");
                        if (wasm_reftype_is_subtype_of(type1, ref_type1,
                                                       REF_TYPE_EXTERNREF, NULL,
                                                       types, type_count))
                            os_printf("extern:");
                        os_printf("ref.null");
                    }
                    else if (wasm_obj_is_func_obj(gc_obj))
                        os_printf("ref.func");
#if WASM_ENABLE_STRINGREF != 0
                    else if (wasm_obj_is_stringref_obj(gc_obj)
                             || wasm_obj_is_stringview_wtf8_obj(gc_obj)) {
                        wasm_string_dump(
                            (WASMString)wasm_stringref_obj_get_value(gc_obj));
                    }
                    else if (wasm_obj_is_stringview_wtf16_obj(gc_obj)) {
                        wasm_string_dump(
                            (WASMString)wasm_stringview_wtf16_obj_get_value(
                                gc_obj));
                    }
#endif
                    else if (wasm_obj_is_externref_obj(gc_obj)) {
#if WASM_ENABLE_SPEC_TEST != 0
                        WASMObjectRef obj = wasm_externref_obj_to_internal_obj(
                            (WASMExternrefObjectRef)gc_obj);
                        if (wasm_obj_is_anyref_obj(obj))
                            os_printf("0x%" PRIxPTR ":ref.extern",
                                      (uintptr_t)wasm_anyref_obj_get_value(
                                          (WASMAnyrefObjectRef)obj));
                        else
#endif
                            os_printf("ref.extern");
                    }
                    else if (wasm_obj_is_i31_obj(gc_obj))
                        os_printf("ref.i31");
                    else if (wasm_obj_is_array_obj(gc_obj))
                        os_printf("ref.array");
                    else if (wasm_obj_is_struct_obj(gc_obj))
                        os_printf("ref.struct");
                    else if (wasm_obj_is_eq_obj(gc_obj))
                        os_printf("ref.eq");
                    else if (wasm_obj_is_anyref_obj(gc_obj))
                        os_printf("0x%" PRIxPTR ":ref.host",
                                  (uintptr_t)wasm_anyref_obj_get_value(
                                      (WASMAnyrefObjectRef)gc_obj));
                    else if (wasm_obj_is_internal_obj(gc_obj))
                        os_printf("ref.any");

                    if (wasm_is_type_multi_byte_type(
                            type->types[type->param_count + j]))
                        ref_type_map++;

                    break;
                }
#endif /* endof WASM_ENABLE_GC != 0 */
                bh_assert(0);
                break;
            }
        }
        if (j < (uint32)(type->result_count - 1))
            os_printf(",");
    }
    os_printf("\n");

#if WASM_ENABLE_GC != 0
    for (j = 0; j < num_local_ref_pushed; j++) {
        local_ref = wasm_runtime_pop_local_obj_ref(exec_env);
        wasm_runtime_free(local_ref);
    }
#endif

    wasm_runtime_free(argv1);
    return true;

fail:
    if (argv1)
        wasm_runtime_free(argv1);

#if WASM_ENABLE_GC != 0
    for (j = 0; j < num_local_ref_pushed; j++) {
        local_ref = wasm_runtime_pop_local_obj_ref(exec_env);
        wasm_runtime_free(local_ref);
    }
#endif

    bh_assert(wasm_runtime_get_exception(module_inst));
    return false;
}

bool
wasm_application_execute_func(WASMModuleInstanceCommon *module_inst,
                              const char *name, int32 argc, char *argv[])
{
    bool ret;
#if WASM_ENABLE_MEMORY_PROFILING != 0
    WASMExecEnv *exec_env;
#endif

    ret = execute_func(module_inst, name, argc, argv);

#if WASM_ENABLE_MEMORY_PROFILING != 0
    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (exec_env) {
        wasm_runtime_dump_mem_consumption(exec_env);
    }
#endif

#if WASM_ENABLE_GC_PERF_PROFILING != 0
    void *handle = wasm_runtime_get_gc_heap_handle(module_inst);
    mem_allocator_dump_perf_profiling(handle);
#endif

#if WASM_ENABLE_PERF_PROFILING != 0
    wasm_runtime_dump_perf_profiling(module_inst);
#endif

    return (ret && !wasm_runtime_get_exception(module_inst)) ? true : false;
}
