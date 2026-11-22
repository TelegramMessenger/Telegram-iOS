/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_platform.h"
#include "bh_common.h"
#include "bh_assert.h"
#include "bh_log.h"
#include "wasm_native.h"
#include "wasm_runtime_common.h"
#include "wasm_memory.h"
#if WASM_ENABLE_INTERP != 0
#include "../interpreter/wasm_runtime.h"
#endif
#if WASM_ENABLE_AOT != 0
#include "../aot/aot_runtime.h"
#if WASM_ENABLE_DEBUG_AOT != 0
#include "../aot/debug/jit_debug.h"
#endif
#endif
#if WASM_ENABLE_GC != 0
#include "gc/gc_object.h"
#endif
#if WASM_ENABLE_THREAD_MGR != 0
#include "../libraries/thread-mgr/thread_manager.h"
#if WASM_ENABLE_DEBUG_INTERP != 0
#include "../libraries/debug-engine/debug_engine.h"
#endif
#endif
#if WASM_ENABLE_SHARED_MEMORY != 0
#include "wasm_shared_memory.h"
#endif
#if WASM_ENABLE_FAST_JIT != 0
#include "../fast-jit/jit_compiler.h"
#endif
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
#include "../compilation/aot_llvm.h"
#endif
#include "../common/wasm_c_api_internal.h"
#include "../../version.h"

/**
 * For runtime build, BH_MALLOC/BH_FREE should be defined as
 * wasm_runtime_malloc/wasm_runtime_free.
 */
#define CHECK(a) CHECK1(a)
#define CHECK1(a) SHOULD_BE_##a

#define SHOULD_BE_wasm_runtime_malloc 1
#if !CHECK(BH_MALLOC)
#error unexpected BH_MALLOC
#endif
#undef SHOULD_BE_wasm_runtime_malloc

#define SHOULD_BE_wasm_runtime_free 1
#if !CHECK(BH_FREE)
#error unexpected BH_FREE
#endif
#undef SHOULD_BE_wasm_runtime_free

#undef CHECK
#undef CHECK1

#if WASM_ENABLE_MULTI_MODULE != 0
/**
 * A safety insurance to prevent
 * circular dependencies which leads stack overflow
 * try to break early
 */
typedef struct LoadingModule {
    bh_list_link l;
    /* point to a string pool */
    const char *module_name;
} LoadingModule;

static bh_list loading_module_list_head;
static bh_list *const loading_module_list = &loading_module_list_head;
static korp_mutex loading_module_list_lock;

/**
 * A list to store all exported functions/globals/memories/tables
 * of every fully loaded module
 */
static bh_list registered_module_list_head;
static bh_list *const registered_module_list = &registered_module_list_head;
static korp_mutex registered_module_list_lock;
static void
wasm_runtime_destroy_registered_module_list(void);
#endif /* WASM_ENABLE_MULTI_MODULE */

#define E_TYPE_XIP 4

static uint8
val_type_to_val_kind(uint8 value_type);

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
/* Initialize externref hashmap */
static bool
wasm_externref_map_init(void);

/* Destroy externref hashmap */
static void
wasm_externref_map_destroy(void);
#endif /* end of WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0 */

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

#if WASM_ENABLE_MULTI_MODULE != 0
/* TODO: Let loader_malloc be a general API both for AOT and WASM. */

#define loader_malloc(size, error_buf, error_buf_size) \
    runtime_malloc(size, NULL, error_buf, error_buf_size)

static void
set_error_buf_v(const WASMModuleCommon *module, char *error_buf,
                uint32 error_buf_size, const char *format, ...)
{
    va_list args;
    char buf[128];
    if (error_buf != NULL) {
        va_start(args, format);
        vsnprintf(buf, sizeof(buf), format, args);
        va_end(args);
        if (module->module_type == Wasm_Module_AoT) {
            snprintf(error_buf, error_buf_size, "AOT module load failed: %s",
                     buf);
        }
        else if (module->module_type == Wasm_Module_Bytecode) {
            snprintf(error_buf, error_buf_size, "WASM module load failed: %s",
                     buf);
        }
    }
}
#endif

#if WASM_ENABLE_FAST_JIT != 0
static JitCompOptions jit_options = { 0 };
#endif

#if WASM_ENABLE_JIT != 0
/* opt_level: 3, size_level: 3, segue-flags: 0,
   quick_invoke_c_api_import: false */
static LLVMJITOptions llvm_jit_options = { 3, 3, 0, false };
#endif

#if WASM_ENABLE_GC != 0
static uint32 gc_heap_size_default = GC_HEAP_SIZE_DEFAULT;
#endif

static RunningMode runtime_running_mode = Mode_Default;

#ifdef OS_ENABLE_HW_BOUND_CHECK
/* The exec_env of thread local storage, set before calling function
   and used in signal handler, as we cannot get it from the argument
   of signal handler */
static os_thread_local_attribute WASMExecEnv *exec_env_tls = NULL;

static bool
is_sig_addr_in_guard_pages(void *sig_addr, WASMModuleInstance *module_inst)
{
    WASMMemoryInstance *memory_inst;
#if WASM_ENABLE_SHARED_HEAP != 0
    WASMSharedHeap *shared_heap;
#endif
    uint8 *mapped_mem_start_addr = NULL;
    uint8 *mapped_mem_end_addr = NULL;
    uint32 i;

    for (i = 0; i < module_inst->memory_count; ++i) {
        /* To be compatible with multi memory, get the ith memory instance */
        memory_inst = wasm_get_memory_with_idx(module_inst, i);
        mapped_mem_start_addr = memory_inst->memory_data;
        mapped_mem_end_addr = memory_inst->memory_data + 8 * (uint64)BH_GB;
        if (mapped_mem_start_addr <= (uint8 *)sig_addr
            && (uint8 *)sig_addr < mapped_mem_end_addr) {
            /* The address which causes segmentation fault is inside
               the memory instance's guard regions */
            return true;
        }
    }

#if WASM_ENABLE_SHARED_HEAP != 0
    shared_heap =
        wasm_runtime_get_shared_heap((WASMModuleInstanceCommon *)module_inst);
    if (shared_heap) {
        mapped_mem_start_addr = shared_heap->base_addr;
        mapped_mem_end_addr = shared_heap->base_addr + 8 * (uint64)BH_GB;
        if (mapped_mem_start_addr <= (uint8 *)sig_addr
            && (uint8 *)sig_addr < mapped_mem_end_addr) {
            /* The address which causes segmentation fault is inside
               the shared heap's guard regions */
            return true;
        }
    }
#endif

    return false;
}

#ifndef BH_PLATFORM_WINDOWS
static void
runtime_signal_handler(void *sig_addr)
{
    WASMModuleInstance *module_inst;
    WASMJmpBuf *jmpbuf_node;
    uint32 page_size = os_getpagesize();
#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    uint8 *stack_min_addr;
    uint32 guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
#endif

    /* Check whether current thread is running wasm function */
    if (exec_env_tls && exec_env_tls->handle == os_self_thread()
        && (jmpbuf_node = exec_env_tls->jmpbuf_stack_top)) {
        /* Get mapped mem info of current instance */
        module_inst = (WASMModuleInstance *)exec_env_tls->module_inst;

#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
        /* Get stack info of current thread */
        stack_min_addr = os_thread_get_stack_boundary();
#endif

        if (is_sig_addr_in_guard_pages(sig_addr, module_inst)) {
            wasm_set_exception(module_inst, "out of bounds memory access");
            os_longjmp(jmpbuf_node->jmpbuf, 1);
        }
#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
        else if (stack_min_addr <= (uint8 *)sig_addr
                 && (uint8 *)sig_addr
                        < stack_min_addr + page_size * guard_page_count) {
            /* The address which causes segmentation fault is inside
               native thread's guard page */
            wasm_set_exception(module_inst, "native stack overflow");
            os_longjmp(jmpbuf_node->jmpbuf, 1);
        }
#endif
        else if (exec_env_tls->exce_check_guard_page <= (uint8 *)sig_addr
                 && (uint8 *)sig_addr
                        < exec_env_tls->exce_check_guard_page + page_size) {
            bh_assert(wasm_copy_exception(module_inst, NULL));
            os_longjmp(jmpbuf_node->jmpbuf, 1);
        }
    }
}
#else /* else of BH_PLATFORM_WINDOWS */

#if WASM_ENABLE_AOT != 0
#include <Zydis/Zydis.h>

static uint32
decode_insn(uint8 *insn)
{
    uint8 *data = (uint8 *)insn;
    uint32 length = 32; /* reserve enough size */

    /* Initialize decoder context */
    ZydisDecoder decoder;
    ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64,
                     ZYDIS_STACK_WIDTH_64);

    /* Initialize formatter */
    ZydisFormatter formatter;
    ZydisFormatterInit(&formatter, ZYDIS_FORMATTER_STYLE_INTEL);

    /* Loop over the instructions in our buffer */
    ZyanU64 runtime_address = (ZyanU64)(uintptr_t)data;
    ZyanUSize offset = 0;
    ZydisDecodedInstruction instruction;
    ZydisDecodedOperand operands[ZYDIS_MAX_OPERAND_COUNT_VISIBLE];
    char buffer[256];

    if (ZYAN_SUCCESS(ZydisDecoderDecodeFull(
            &decoder, data + offset, length - offset, &instruction, operands,
            ZYDIS_MAX_OPERAND_COUNT_VISIBLE,
            ZYDIS_DFLAG_VISIBLE_OPERANDS_ONLY))) {

        /* Format & print the binary instruction structure to
           human readable format */
        ZydisFormatterFormatInstruction(&formatter, &instruction, operands,
                                        instruction.operand_count_visible,
                                        buffer, sizeof(buffer),
                                        runtime_address);

#if 0
        /* Print current instruction */
        os_printf("%012" PRIX64 "  ", runtime_address);
        puts(buffer);
#endif

        return instruction.length;
    }

    /* Decode failed */
    return 0;
}
#endif /* end of WASM_ENABLE_AOT != 0 */

static LONG
next_action(WASMModuleInstance *module_inst, EXCEPTION_POINTERS *exce_info)
{
#if WASM_ENABLE_AOT != 0
    uint32 insn_size;
#endif

    if (module_inst->module_type == Wasm_Module_Bytecode
        && module_inst->e->running_mode == Mode_Interp) {
        /* Continue to search next exception handler for
           interpreter mode as it can be caught by
           `__try { .. } __except { .. }` sentences in
           wasm_runtime.c */
        return EXCEPTION_CONTINUE_SEARCH;
    }

#if WASM_ENABLE_AOT != 0
    /* Skip current instruction and continue to run for AOT/JIT mode.
       TODO: implement unwind support for AOT/JIT code in Windows platform */
    insn_size = decode_insn((uint8 *)exce_info->ContextRecord->Rip);
    if (insn_size > 0) {
        exce_info->ContextRecord->Rip += insn_size;
        return EXCEPTION_CONTINUE_EXECUTION;
    }
#endif

    /* return different value from EXCEPTION_CONTINUE_SEARCH (= 0)
       and EXCEPTION_CONTINUE_EXECUTION (= -1) */
    return -2;
}

static LONG
runtime_exception_handler(EXCEPTION_POINTERS *exce_info)
{
    PEXCEPTION_RECORD ExceptionRecord = exce_info->ExceptionRecord;
    uint8 *sig_addr = (uint8 *)ExceptionRecord->ExceptionInformation[1];
    WASMModuleInstance *module_inst;
    WASMJmpBuf *jmpbuf_node;
    uint8 *mapped_mem_start_addr = NULL;
    uint8 *mapped_mem_end_addr = NULL;
    uint32 page_size = os_getpagesize();
    LONG ret;

    if (exec_env_tls && exec_env_tls->handle == os_self_thread()
        && (jmpbuf_node = exec_env_tls->jmpbuf_stack_top)) {
        module_inst = (WASMModuleInstance *)exec_env_tls->module_inst;
        if (ExceptionRecord->ExceptionCode == EXCEPTION_ACCESS_VIOLATION) {
            if (is_sig_addr_in_guard_pages(sig_addr, module_inst)) {
                /* The address which causes segmentation fault is inside
                   the memory instance's guard regions.
                   Set exception and let the wasm func continue to run, when
                   the wasm func returns, the caller will check whether the
                   exception is thrown and return to runtime. */
                wasm_set_exception(module_inst, "out of bounds memory access");
                ret = next_action(module_inst, exce_info);
                if (ret == EXCEPTION_CONTINUE_SEARCH
                    || ret == EXCEPTION_CONTINUE_EXECUTION)
                    return ret;
            }
            else if (exec_env_tls->exce_check_guard_page <= (uint8 *)sig_addr
                     && (uint8 *)sig_addr
                            < exec_env_tls->exce_check_guard_page + page_size) {
                bh_assert(wasm_copy_exception(module_inst, NULL));
                ret = next_action(module_inst, exce_info);
                if (ret == EXCEPTION_CONTINUE_SEARCH
                    || ret == EXCEPTION_CONTINUE_EXECUTION)
                    return ret;
            }
        }
#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
        else if (ExceptionRecord->ExceptionCode == EXCEPTION_STACK_OVERFLOW) {
            /* Set stack overflow exception and let the wasm func continue
               to run, when the wasm func returns, the caller will check
               whether the exception is thrown and return to runtime, and
               the damaged stack will be recovered by _resetstkoflw(). */
            wasm_set_exception(module_inst, "native stack overflow");
            ret = next_action(module_inst, exce_info);
            if (ret == EXCEPTION_CONTINUE_SEARCH
                || ret == EXCEPTION_CONTINUE_EXECUTION)
                return ret;
        }
#endif
        else {
            LOG_WARNING("Unhandled exception thrown:  exception code: 0x%lx, "
                        "exception address: %p, exception information: %p\n",
                        ExceptionRecord->ExceptionCode,
                        ExceptionRecord->ExceptionAddress, sig_addr);
        }
    }

    return EXCEPTION_CONTINUE_SEARCH;
}
#endif /* end of BH_PLATFORM_WINDOWS */

static bool
runtime_signal_init()
{
#ifndef BH_PLATFORM_WINDOWS
    return os_thread_signal_init(runtime_signal_handler) == 0 ? true : false;
#else
    if (os_thread_signal_init() != 0)
        return false;

    if (!AddVectoredExceptionHandler(1, runtime_exception_handler)) {
        os_thread_signal_destroy();
        return false;
    }
#endif
    return true;
}

static void
runtime_signal_destroy()
{
#ifdef BH_PLATFORM_WINDOWS
    RemoveVectoredExceptionHandler(runtime_exception_handler);
#endif
    os_thread_signal_destroy();
}

void
wasm_runtime_set_exec_env_tls(WASMExecEnv *exec_env)
{
    exec_env_tls = exec_env;
}

WASMExecEnv *
wasm_runtime_get_exec_env_tls()
{
    return exec_env_tls;
}
#endif /* end of OS_ENABLE_HW_BOUND_CHECK */

static bool
wasm_runtime_env_init(void)
{
    if (bh_platform_init() != 0)
        return false;

    if (wasm_native_init() == false) {
        goto fail1;
    }

#if WASM_ENABLE_MULTI_MODULE
    if (BHT_OK != os_mutex_init(&registered_module_list_lock)) {
        goto fail2;
    }

    if (BHT_OK != os_mutex_init(&loading_module_list_lock)) {
        goto fail3;
    }
#endif

#if WASM_ENABLE_SHARED_MEMORY
    if (!wasm_shared_memory_init()) {
        goto fail4;
    }
#endif

#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_THREAD_MGR != 0)
    if (!thread_manager_init()) {
        goto fail5;
    }
#endif

#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (!runtime_signal_init()) {
        goto fail6;
    }
#endif

#if WASM_ENABLE_AOT != 0
#if WASM_ENABLE_DEBUG_AOT != 0
    if (!jit_debug_engine_init()) {
        goto fail7;
    }
#endif
#endif

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    if (!wasm_externref_map_init()) {
        goto fail8;
    }
#endif

#if WASM_ENABLE_FAST_JIT != 0
    if (!jit_compiler_init(&jit_options)) {
        goto fail9;
    }
#endif

#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
    if (!aot_compiler_init()) {
        goto fail10;
    }
#endif

#if WASM_ENABLE_THREAD_MGR != 0 && defined(OS_ENABLE_WAKEUP_BLOCKING_OP)
    if (os_blocking_op_init() != BHT_OK) {
        goto fail11;
    }
    os_end_blocking_op();
#endif

    return true;

#if WASM_ENABLE_THREAD_MGR != 0 && defined(OS_ENABLE_WAKEUP_BLOCKING_OP)
fail11:
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
    aot_compiler_destroy();
#endif
#endif
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
fail10:
#if WASM_ENABLE_FAST_JIT != 0
    jit_compiler_destroy();
#endif
#endif
#if WASM_ENABLE_FAST_JIT != 0
fail9:
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    wasm_externref_map_destroy();
#endif
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
fail8:
#endif
#if WASM_ENABLE_AOT != 0
#if WASM_ENABLE_DEBUG_AOT != 0
    jit_debug_engine_destroy();
fail7:
#endif
#endif
#ifdef OS_ENABLE_HW_BOUND_CHECK
    runtime_signal_destroy();
fail6:
#endif
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_THREAD_MGR != 0)
    thread_manager_destroy();
fail5:
#endif
#if WASM_ENABLE_SHARED_MEMORY
    wasm_shared_memory_destroy();
fail4:
#endif
#if WASM_ENABLE_MULTI_MODULE
    os_mutex_destroy(&loading_module_list_lock);
fail3:
    os_mutex_destroy(&registered_module_list_lock);
fail2:
#endif
    wasm_native_destroy();
fail1:
    bh_platform_destroy();

    return false;
}

static bool
wasm_runtime_exec_env_check(WASMExecEnv *exec_env)
{
    return exec_env && exec_env->module_inst && exec_env->wasm_stack_size > 0
           && exec_env->wasm_stack.top_boundary
                  == exec_env->wasm_stack.bottom + exec_env->wasm_stack_size
           && exec_env->wasm_stack.top <= exec_env->wasm_stack.top_boundary;
}

#if defined(OS_THREAD_MUTEX_INITIALIZER)
/**
 * lock for wasm_runtime_init/wasm_runtime_full_init and runtime_ref_count
 * Note: if the platform has mutex initializer, we use a global lock to
 * lock the operations of runtime init/full_init, otherwise when there are
 * operations happening simultaneously in multiple threads, developer
 * must create the lock by himself, and use it to lock the operations
 */
static korp_mutex runtime_lock = OS_THREAD_MUTEX_INITIALIZER;
#endif
static int32 runtime_ref_count = 0;

static bool
wasm_runtime_init_internal(void)
{
    if (!wasm_runtime_memory_init(Alloc_With_System_Allocator, NULL))
        return false;

    if (!wasm_runtime_env_init()) {
        wasm_runtime_memory_destroy();
        return false;
    }

    return true;
}

bool
wasm_runtime_init()
{
    bool ret = true;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&runtime_lock);
#endif

    bh_assert(runtime_ref_count >= 0);
    if (runtime_ref_count == 0) {
        ret = wasm_runtime_init_internal();
    }
    if (ret) {
        runtime_ref_count++;
    }

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&runtime_lock);
#endif

    return ret;
}

static void
wasm_runtime_destroy_internal(void)
{
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    wasm_externref_map_destroy();
#endif

#if WASM_ENABLE_AOT != 0
#if WASM_ENABLE_DEBUG_AOT != 0
    jit_debug_engine_destroy();
#endif
#endif

#ifdef OS_ENABLE_HW_BOUND_CHECK
    runtime_signal_destroy();
#endif

    /* runtime env destroy */
#if WASM_ENABLE_MULTI_MODULE
    wasm_runtime_destroy_loading_module_list();
    os_mutex_destroy(&loading_module_list_lock);

    wasm_runtime_destroy_registered_module_list();
    os_mutex_destroy(&registered_module_list_lock);
#endif

#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
    /* Destroy LLVM-JIT compiler after destroying the modules
     * loaded by multi-module feature, since these modules may
     * create backend threads to compile the wasm functions,
     * which may access the LLVM resources. We wait until they
     * finish the compilation to avoid accessing the destroyed
     * resources in the compilation threads.
     */
    aot_compiler_destroy();
#endif

#if WASM_ENABLE_FAST_JIT != 0
    /* Destroy Fast-JIT compiler after destroying the modules
     * loaded by multi-module feature, since the Fast JIT's
     * code cache allocator may be used by these modules.
     */
    jit_compiler_destroy();
#endif

#if WASM_ENABLE_SHARED_MEMORY
    wasm_shared_memory_destroy();
#endif

#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_THREAD_MGR != 0)
#if WASM_ENABLE_DEBUG_INTERP != 0
    wasm_debug_engine_destroy();
#endif
    thread_manager_destroy();
#endif

    wasm_native_destroy();
    bh_platform_destroy();

    wasm_runtime_memory_destroy();
}

void
wasm_runtime_destroy()
{
#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&runtime_lock);
#endif

    bh_assert(runtime_ref_count > 0);
    runtime_ref_count--;
    if (runtime_ref_count == 0) {
        wasm_runtime_destroy_internal();
    }

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&runtime_lock);
#endif
}

RunningMode
wasm_runtime_get_default_running_mode(void)
{
    return runtime_running_mode;
}

#if WASM_ENABLE_JIT != 0
LLVMJITOptions *
wasm_runtime_get_llvm_jit_options(void)
{
    return &llvm_jit_options;
}
#endif

#if WASM_ENABLE_GC != 0
uint32
wasm_runtime_get_gc_heap_size_default(void)
{
    return gc_heap_size_default;
}
#endif

static bool
wasm_runtime_full_init_internal(RuntimeInitArgs *init_args)
{
    if (!wasm_runtime_memory_init(init_args->mem_alloc_type,
                                  &init_args->mem_alloc_option))
        return false;

    if (!wasm_runtime_set_default_running_mode(init_args->running_mode)) {
        wasm_runtime_memory_destroy();
        return false;
    }

#if WASM_ENABLE_FAST_JIT != 0
    jit_options.code_cache_size = init_args->fast_jit_code_cache_size;
#endif

#if WASM_ENABLE_GC != 0
    uint32 gc_heap_size = init_args->gc_heap_size;
    if (gc_heap_size > 0) {
        gc_heap_size_default = gc_heap_size;
    }
#endif

#if WASM_ENABLE_JIT != 0
    llvm_jit_options.size_level = init_args->llvm_jit_size_level;
    llvm_jit_options.opt_level = init_args->llvm_jit_opt_level;
    llvm_jit_options.segue_flags = init_args->segue_flags;
#endif

#if WASM_ENABLE_LINUX_PERF != 0
    wasm_runtime_set_linux_perf(init_args->enable_linux_perf);
#else
    if (init_args->enable_linux_perf)
        LOG_WARNING("warning: to enable linux perf support, please recompile "
                    "with -DWAMR_BUILD_LINUX_PERF=1");
#endif

    if (!wasm_runtime_env_init()) {
        wasm_runtime_memory_destroy();
        return false;
    }

#if WASM_ENABLE_DEBUG_INTERP != 0
    if (strlen(init_args->ip_addr))
        if (!wasm_debug_engine_init(init_args->ip_addr,
                                    init_args->instance_port)) {
            wasm_runtime_destroy();
            return false;
        }
#endif

    if (init_args->n_native_symbols > 0
        && !wasm_runtime_register_natives(init_args->native_module_name,
                                          init_args->native_symbols,
                                          init_args->n_native_symbols)) {
        wasm_runtime_destroy();
        return false;
    }

#if WASM_ENABLE_THREAD_MGR != 0
    wasm_cluster_set_max_thread_num(init_args->max_thread_num);
#endif

    return true;
}

bool
wasm_runtime_full_init(RuntimeInitArgs *init_args)
{
    bool ret = true;

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_lock(&runtime_lock);
#endif

    bh_assert(runtime_ref_count >= 0);
    if (runtime_ref_count == 0) {
        ret = wasm_runtime_full_init_internal(init_args);
    }
    if (ret) {
        runtime_ref_count++;
    }

#if defined(OS_THREAD_MUTEX_INITIALIZER)
    os_mutex_unlock(&runtime_lock);
#endif

    return ret;
}

void
wasm_runtime_set_log_level(log_level_t level)
{
    bh_log_set_verbose_level(level);
}

bool
wasm_runtime_is_running_mode_supported(RunningMode running_mode)
{
    if (running_mode == Mode_Default) {
        return true;
    }
    else if (running_mode == Mode_Interp) {
#if WASM_ENABLE_INTERP != 0
        return true;
#endif
    }
    else if (running_mode == Mode_Fast_JIT) {
#if WASM_ENABLE_FAST_JIT != 0
        return true;
#endif
    }
    else if (running_mode == Mode_LLVM_JIT) {
#if WASM_ENABLE_JIT != 0
        return true;
#endif
    }
    else if (running_mode == Mode_Multi_Tier_JIT) {
#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
        return true;
#endif
    }

    return false;
}

bool
wasm_runtime_set_default_running_mode(RunningMode running_mode)
{
    if (wasm_runtime_is_running_mode_supported(running_mode)) {
        runtime_running_mode = running_mode;
        return true;
    }
    return false;
}

PackageType
get_package_type(const uint8 *buf, uint32 size)
{
    if (buf && size >= 4) {
#if (WASM_ENABLE_WORD_ALIGN_READ != 0)
        uint32 buf32 = *(uint32 *)buf;
        buf = (const uint8 *)&buf32;
#endif
        if (buf[0] == '\0' && buf[1] == 'a' && buf[2] == 's' && buf[3] == 'm')
            return Wasm_Module_Bytecode;
        if (buf[0] == '\0' && buf[1] == 'a' && buf[2] == 'o' && buf[3] == 't')
            return Wasm_Module_AoT;
    }
    return Package_Type_Unknown;
}

PackageType
wasm_runtime_get_file_package_type(const uint8 *buf, uint32 size)
{
    return get_package_type(buf, size);
}

PackageType
wasm_runtime_get_module_package_type(WASMModuleCommon *const module)
{
    if (!module) {
        return Package_Type_Unknown;
    }

    return module->module_type;
}

uint32
wasm_runtime_get_file_package_version(const uint8 *buf, uint32 size)
{
    if (buf && size >= 8) {
        uint32 version;
#if (WASM_ENABLE_WORD_ALIGN_READ != 0)
        uint32 buf32 = *(uint32 *)(buf + sizeof(uint32));
        buf = (const uint8 *)&buf32;
        version = buf[0] | buf[1] << 8 | buf[2] << 16 | buf[3] << 24;
#else
        version = buf[4] | buf[5] << 8 | buf[6] << 16 | buf[7] << 24;
#endif
        return version;
    }

    return 0;
}

uint32
wasm_runtime_get_module_package_version(WASMModuleCommon *const module)
{
    if (!module) {
        return 0;
    }

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;
        return wasm_module->package_version;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;
        return aot_module->package_version;
    }
#endif

    return 0;
}

uint32
wasm_runtime_get_current_package_version(package_type_t package_type)
{
    switch (package_type) {
        case Wasm_Module_Bytecode:
            return WASM_CURRENT_VERSION;
        case Wasm_Module_AoT:
            return AOT_CURRENT_VERSION;
        case Package_Type_Unknown:
        default:
            return 0;
    }
}

#if WASM_ENABLE_AOT != 0
static uint8 *
align_ptr(const uint8 *p, uint32 b)
{
    uintptr_t v = (uintptr_t)p;
    uintptr_t m = b - 1;
    return (uint8 *)((v + m) & ~m);
}

#define CHECK_BUF(buf, buf_end, length)                      \
    do {                                                     \
        if ((uintptr_t)buf + length < (uintptr_t)buf         \
            || (uintptr_t)buf + length > (uintptr_t)buf_end) \
            return false;                                    \
    } while (0)

/* NOLINTNEXTLINE */
#define read_uint16(p, p_end, res)                 \
    do {                                           \
        p = (uint8 *)align_ptr(p, sizeof(uint16)); \
        CHECK_BUF(p, p_end, sizeof(uint16));       \
        res = *(uint16 *)p;                        \
        p += sizeof(uint16);                       \
    } while (0)

/* NOLINTNEXTLINE */
#define read_uint32(p, p_end, res)                 \
    do {                                           \
        p = (uint8 *)align_ptr(p, sizeof(uint32)); \
        CHECK_BUF(p, p_end, sizeof(uint32));       \
        res = *(uint32 *)p;                        \
        p += sizeof(uint32);                       \
    } while (0)

bool
wasm_runtime_is_xip_file(const uint8 *buf, uint32 size)
{
    const uint8 *p = buf, *p_end = buf + size;
    uint32 section_type, section_size;
    uint16 e_type;

    if (get_package_type(buf, size) != Wasm_Module_AoT)
        return false;

    CHECK_BUF(p, p_end, 8);
    p += 8;
    while (p < p_end) {
        read_uint32(p, p_end, section_type);
        read_uint32(p, p_end, section_size);
        CHECK_BUF(p, p_end, section_size);

        if (section_type == AOT_SECTION_TYPE_TARGET_INFO) {
            p += 4;
            read_uint16(p, p_end, e_type);
            return (e_type == E_TYPE_XIP) ? true : false;
        }
        else if (section_type >= AOT_SECTION_TYPE_SIGNATURE) {
            return false;
        }
        p += section_size;
    }

    return false;
}
#endif /* end of WASM_ENABLE_AOT */

#if (WASM_ENABLE_THREAD_MGR != 0) && (WASM_ENABLE_DEBUG_INTERP != 0)
uint32
wasm_runtime_start_debug_instance_with_port(WASMExecEnv *exec_env, int32_t port)
{
    WASMModuleInstanceCommon *module_inst =
        wasm_runtime_get_module_inst(exec_env);
    WASMCluster *cluster = wasm_exec_env_get_cluster(exec_env);
    bh_assert(module_inst);
    bh_assert(cluster);

    if (module_inst->module_type != Wasm_Module_Bytecode) {
        LOG_WARNING("Attempt to create a debug instance for an AOT module");
        return 0;
    }

    if (cluster->debug_inst) {
        LOG_WARNING("Cluster already bind to a debug instance");
        return cluster->debug_inst->control_thread->port;
    }

    if (wasm_debug_instance_create(cluster, port)) {
        return cluster->debug_inst->control_thread->port;
    }

    return 0;
}

uint32
wasm_runtime_start_debug_instance(WASMExecEnv *exec_env)
{
    return wasm_runtime_start_debug_instance_with_port(exec_env, -1);
}
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
static module_reader reader;
static module_destroyer destroyer;
void
wasm_runtime_set_module_reader(const module_reader reader_cb,
                               const module_destroyer destroyer_cb)
{
    reader = reader_cb;
    destroyer = destroyer_cb;
}

module_reader
wasm_runtime_get_module_reader()
{
    return reader;
}

module_destroyer
wasm_runtime_get_module_destroyer()
{
    return destroyer;
}

static WASMRegisteredModule *
wasm_runtime_find_module_registered_by_reference(WASMModuleCommon *module)
{
    WASMRegisteredModule *reg_module = NULL;

    os_mutex_lock(&registered_module_list_lock);
    reg_module = bh_list_first_elem(registered_module_list);
    while (reg_module && module != reg_module->module) {
        reg_module = bh_list_elem_next(reg_module);
    }
    os_mutex_unlock(&registered_module_list_lock);

    return reg_module;
}

bool
wasm_runtime_register_module_internal(const char *module_name,
                                      WASMModuleCommon *module,
                                      uint8 *orig_file_buf,
                                      uint32 orig_file_buf_size,
                                      char *error_buf, uint32 error_buf_size)
{
    WASMRegisteredModule *node = NULL;

    node = wasm_runtime_find_module_registered_by_reference(module);
    if (node) {                  /* module has been registered */
        if (node->module_name) { /* module has name */
            if (!module_name || strcmp(node->module_name, module_name)) {
                /* module has different name */
                LOG_DEBUG("module(%p) has been registered with name %s", module,
                          node->module_name);
                set_error_buf(error_buf, error_buf_size,
                              "Register module failed: "
                              "failed to rename the module");
                return false;
            }
            else {
                /* module has the same name */
                LOG_DEBUG(
                    "module(%p) has been registered with the same name %s",
                    module, node->module_name);
                return true;
            }
        }
        else {
            /* module has empty name, reset it */
            node->module_name = module_name;
            return true;
        }
    }

    /* module hasn't been registered */
    node = runtime_malloc(sizeof(WASMRegisteredModule), NULL, NULL, 0);
    if (!node) {
        LOG_DEBUG("malloc WASMRegisteredModule failed. SZ=%zu",
                  sizeof(WASMRegisteredModule));
        return false;
    }

    /* share the string and the module */
    node->module_name = module_name;
    node->module = module;
    node->orig_file_buf = orig_file_buf;
    node->orig_file_buf_size = orig_file_buf_size;

    os_mutex_lock(&registered_module_list_lock);
    bh_list_status ret = bh_list_insert(registered_module_list, node);
    bh_assert(BH_LIST_SUCCESS == ret);
    (void)ret;
    os_mutex_unlock(&registered_module_list_lock);
    return true;
}

bool
wasm_runtime_register_module(const char *module_name, WASMModuleCommon *module,
                             char *error_buf, uint32 error_buf_size)
{
    if (!error_buf || !error_buf_size) {
        LOG_ERROR("error buffer is required");
        return false;
    }

    if (!module_name || !module) {
        LOG_DEBUG("module_name and module are required");
        set_error_buf(error_buf, error_buf_size,
                      "Register module failed: "
                      "module_name and module are required");
        return false;
    }

    if (wasm_runtime_is_built_in_module(module_name)) {
        LOG_DEBUG("%s is a built-in module name", module_name);
        set_error_buf(error_buf, error_buf_size,
                      "Register module failed: "
                      "can not register as a built-in module");
        return false;
    }

    return wasm_runtime_register_module_internal(module_name, module, NULL, 0,
                                                 error_buf, error_buf_size);
}

void
wasm_runtime_unregister_module(const WASMModuleCommon *module)
{
    WASMRegisteredModule *registered_module = NULL;

    os_mutex_lock(&registered_module_list_lock);
    registered_module = bh_list_first_elem(registered_module_list);
    while (registered_module && module != registered_module->module) {
        registered_module = bh_list_elem_next(registered_module);
    }

    /* it does not matter if it is not exist. after all, it is gone */
    if (registered_module) {
        bh_list_remove(registered_module_list, registered_module);
        wasm_runtime_free(registered_module);
    }
    os_mutex_unlock(&registered_module_list_lock);
}

WASMModuleCommon *
wasm_runtime_find_module_registered(const char *module_name)
{
    WASMRegisteredModule *module = NULL, *module_next;

    os_mutex_lock(&registered_module_list_lock);
    module = bh_list_first_elem(registered_module_list);
    while (module) {
        module_next = bh_list_elem_next(module);
        if (module->module_name && !strcmp(module_name, module->module_name)) {
            break;
        }
        module = module_next;
    }
    os_mutex_unlock(&registered_module_list_lock);

    return module ? module->module : NULL;
}

/*
 * simply destroy all
 */
static void
wasm_runtime_destroy_registered_module_list()
{
    WASMRegisteredModule *reg_module = NULL;

    os_mutex_lock(&registered_module_list_lock);
    reg_module = bh_list_first_elem(registered_module_list);
    while (reg_module) {
        WASMRegisteredModule *next_reg_module = bh_list_elem_next(reg_module);

        bh_list_remove(registered_module_list, reg_module);

        /* now, it is time to release every module in the runtime */
        if (reg_module->module->module_type == Wasm_Module_Bytecode) {
#if WASM_ENABLE_INTERP != 0
            wasm_unload((WASMModule *)reg_module->module);
#endif
        }
        else {
#if WASM_ENABLE_AOT != 0
            aot_unload((AOTModule *)reg_module->module);
#endif
        }

        /* destroy the file buffer */
        if (destroyer && reg_module->orig_file_buf) {
            destroyer(reg_module->orig_file_buf,
                      reg_module->orig_file_buf_size);
            reg_module->orig_file_buf = NULL;
            reg_module->orig_file_buf_size = 0;
        }

        wasm_runtime_free(reg_module);
        reg_module = next_reg_module;
    }
    os_mutex_unlock(&registered_module_list_lock);
}

bool
wasm_runtime_add_loading_module(const char *module_name, char *error_buf,
                                uint32 error_buf_size)
{
    LOG_DEBUG("add %s into a loading list", module_name);
    LoadingModule *loadingModule =
        runtime_malloc(sizeof(LoadingModule), NULL, error_buf, error_buf_size);

    if (!loadingModule) {
        return false;
    }

    /* share the incoming string */
    loadingModule->module_name = module_name;

    os_mutex_lock(&loading_module_list_lock);
    bh_list_status ret = bh_list_insert(loading_module_list, loadingModule);
    bh_assert(BH_LIST_SUCCESS == ret);
    (void)ret;
    os_mutex_unlock(&loading_module_list_lock);
    return true;
}

void
wasm_runtime_delete_loading_module(const char *module_name)
{
    LOG_DEBUG("delete %s from a loading list", module_name);

    LoadingModule *module = NULL;

    os_mutex_lock(&loading_module_list_lock);
    module = bh_list_first_elem(loading_module_list);
    while (module && strcmp(module->module_name, module_name)) {
        module = bh_list_elem_next(module);
    }

    /* it does not matter if it is not exist. after all, it is gone */
    if (module) {
        bh_list_remove(loading_module_list, module);
        wasm_runtime_free(module);
    }
    os_mutex_unlock(&loading_module_list_lock);
}

bool
wasm_runtime_is_loading_module(const char *module_name)
{
    LOG_DEBUG("find %s in a loading list", module_name);

    LoadingModule *module = NULL;

    os_mutex_lock(&loading_module_list_lock);
    module = bh_list_first_elem(loading_module_list);
    while (module && strcmp(module_name, module->module_name)) {
        module = bh_list_elem_next(module);
    }
    os_mutex_unlock(&loading_module_list_lock);

    return module != NULL;
}

void
wasm_runtime_destroy_loading_module_list()
{
    LoadingModule *module = NULL;

    os_mutex_lock(&loading_module_list_lock);
    module = bh_list_first_elem(loading_module_list);
    while (module) {
        LoadingModule *next_module = bh_list_elem_next(module);

        bh_list_remove(loading_module_list, module);
        /*
         * will not free the module_name since it is
         * shared one of the const string pool
         */
        wasm_runtime_free(module);

        module = next_module;
    }

    os_mutex_unlock(&loading_module_list_lock);
}
#endif /* WASM_ENABLE_MULTI_MODULE */

bool
wasm_runtime_is_built_in_module(const char *module_name)
{
    return (!strcmp("env", module_name) || !strcmp("wasi_unstable", module_name)
            || !strcmp("wasi_snapshot_preview1", module_name)
#if WASM_ENABLE_SPEC_TEST != 0
            || !strcmp("spectest", module_name)
#endif
#if WASM_ENABLE_WASI_TEST != 0
            || !strcmp("foo", module_name)
#endif
            || !strcmp("", module_name));
}

#if WASM_ENABLE_THREAD_MGR != 0
bool
wasm_exec_env_set_aux_stack(WASMExecEnv *exec_env, uint64 start_offset,
                            uint32 size)
{
    WASMModuleInstanceCommon *module_inst =
        wasm_exec_env_get_module_inst(exec_env);
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_set_aux_stack(exec_env, start_offset, size);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return aot_set_aux_stack(exec_env, start_offset, size);
    }
#endif
    return false;
}

bool
wasm_exec_env_get_aux_stack(WASMExecEnv *exec_env, uint64 *start_offset,
                            uint32 *size)
{
    WASMModuleInstanceCommon *module_inst =
        wasm_exec_env_get_module_inst(exec_env);
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_get_aux_stack(exec_env, start_offset, size);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return aot_get_aux_stack(exec_env, start_offset, size);
    }
#endif
    return false;
}

void
wasm_runtime_set_max_thread_num(uint32 num)
{
    wasm_cluster_set_max_thread_num(num);
}
#endif /* end of WASM_ENABLE_THREAD_MGR */

static WASMModuleCommon *
register_module_with_null_name(WASMModuleCommon *module_common, char *error_buf,
                               uint32 error_buf_size)
{
#if WASM_ENABLE_MULTI_MODULE != 0
    if (module_common) {
        if (!wasm_runtime_register_module_internal(NULL, module_common, NULL, 0,
                                                   error_buf, error_buf_size)) {
            wasm_runtime_unload(module_common);
            return NULL;
        }
        return module_common;
    }
    else
        return NULL;
#else
    return module_common;
#endif
}

WASMModuleCommon *
wasm_runtime_load_ex(uint8 *buf, uint32 size, const LoadArgs *args,
                     char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon *module_common = NULL;
    uint32 package_type;
    bool magic_header_detected = false;

    if (!args) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: null load arguments");
        return NULL;
    }

    if (size < 4) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: unexpected end");
        return NULL;
    }

    package_type = get_package_type(buf, size);
    if (package_type == Wasm_Module_Bytecode) {
#if WASM_ENABLE_INTERP != 0
        magic_header_detected = true;
#endif
    }
    else if (package_type == Wasm_Module_AoT) {
#if WASM_ENABLE_AOT != 0
        magic_header_detected = true;
#endif
    }
    if (!magic_header_detected) {
        set_error_buf(error_buf, error_buf_size,
                      "WASM module load failed: magic header not detected");
        return NULL;
    }

    if (package_type == Wasm_Module_Bytecode) {
#if WASM_ENABLE_INTERP != 0
        module_common =
            (WASMModuleCommon *)wasm_load(buf, size,
#if WASM_ENABLE_MULTI_MODULE != 0
                                          true,
#endif
                                          args, error_buf, error_buf_size);
        if (module_common)
            ((WASMModule *)module_common)->is_binary_freeable =
                args->wasm_binary_freeable;
#endif
    }
    else if (package_type == Wasm_Module_AoT) {
#if WASM_ENABLE_AOT != 0
        module_common = (WASMModuleCommon *)aot_load_from_aot_file(
            buf, size, args, error_buf, error_buf_size);
        if (module_common)
            ((AOTModule *)module_common)->is_binary_freeable =
                args->wasm_binary_freeable;
#endif
    }

    if (!module_common) {
        LOG_DEBUG("WASM module load failed");
        return NULL;
    }

    /*TODO: use file name as name and register with name? */
    return register_module_with_null_name(module_common, error_buf,
                                          error_buf_size);
}

bool
wasm_runtime_resolve_symbols(WASMModuleCommon *module)
{
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        return wasm_resolve_symbols((WASMModule *)module);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        return aot_resolve_symbols((AOTModule *)module);
    }
#endif
    return false;
}

WASMModuleCommon *
wasm_runtime_load(uint8 *buf, uint32 size, char *error_buf,
                  uint32 error_buf_size)
{
    LoadArgs args = { 0 };
    args.name = "";
    args.wasm_binary_freeable = false;
    return wasm_runtime_load_ex(buf, size, &args, error_buf, error_buf_size);
}

WASMModuleCommon *
wasm_runtime_load_from_sections(WASMSection *section_list, bool is_aot,
                                char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon *module_common;

    if (!is_aot) {
#if WASM_ENABLE_INTERP != 0
        module_common = (WASMModuleCommon *)wasm_load_from_sections(
            section_list, error_buf, error_buf_size);
        if (!module_common) {
            LOG_DEBUG("WASM module load failed from sections");
            return NULL;
        }
        ((WASMModule *)module_common)->is_binary_freeable = true;
        return register_module_with_null_name(module_common, error_buf,
                                              error_buf_size);
#endif
    }
    else {
#if WASM_ENABLE_AOT != 0
        module_common = (WASMModuleCommon *)aot_load_from_sections(
            section_list, error_buf, error_buf_size);
        if (!module_common) {
            LOG_DEBUG("WASM module load failed from sections");
            return NULL;
        }
        ((AOTModule *)module_common)->is_binary_freeable = true;
        return register_module_with_null_name(module_common, error_buf,
                                              error_buf_size);
#endif
    }

#if WASM_ENABLE_INTERP == 0 || WASM_ENABLE_AOT == 0
    set_error_buf(error_buf, error_buf_size,
                  "WASM module load failed: invalid section list type");
    return NULL;
#endif
}

void
wasm_runtime_unload(WASMModuleCommon *module)
{
#if WASM_ENABLE_MULTI_MODULE != 0
    /**
     * since we will unload and free all module when runtime_destroy()
     * we don't want users to unwillingly disrupt it
     */
    return;
#endif

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        wasm_unload((WASMModule *)module);
        return;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        aot_unload((AOTModule *)module);
        return;
    }
#endif
}

uint32
wasm_runtime_get_max_mem(uint32 max_memory_pages, uint32 module_init_page_count,
                         uint32 module_max_page_count)
{
    if (max_memory_pages == 0) {
        /* Max memory not overwritten by runtime, use value from wasm module */
        return module_max_page_count;
    }

    if (max_memory_pages < module_init_page_count) {
        LOG_WARNING("Cannot override max memory with value lower than module "
                    "initial memory");
        return module_init_page_count;
    }

    if (max_memory_pages > module_max_page_count) {
        LOG_WARNING("Cannot override max memory with value greater than module "
                    "max memory");
        return module_max_page_count;
    }

    return max_memory_pages;
}

WASMModuleInstanceCommon *
wasm_runtime_instantiate_internal(WASMModuleCommon *module,
                                  WASMModuleInstanceCommon *parent,
                                  WASMExecEnv *exec_env_main, uint32 stack_size,
                                  uint32 heap_size, uint32 max_memory_pages,
                                  char *error_buf, uint32 error_buf_size)
{
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode)
        return (WASMModuleInstanceCommon *)wasm_instantiate(
            (WASMModule *)module, (WASMModuleInstance *)parent, exec_env_main,
            stack_size, heap_size, max_memory_pages, error_buf, error_buf_size);
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT)
        return (WASMModuleInstanceCommon *)aot_instantiate(
            (AOTModule *)module, (AOTModuleInstance *)parent, exec_env_main,
            stack_size, heap_size, max_memory_pages, error_buf, error_buf_size);
#endif
    set_error_buf(error_buf, error_buf_size,
                  "Instantiate module failed, invalid module type");
    return NULL;
}

WASMModuleInstanceCommon *
wasm_runtime_instantiate(WASMModuleCommon *module, uint32 stack_size,
                         uint32 heap_size, char *error_buf,
                         uint32 error_buf_size)
{
    return wasm_runtime_instantiate_internal(module, NULL, NULL, stack_size,
                                             heap_size, 0, error_buf,
                                             error_buf_size);
}

static void
instantiation_args_set_defaults(struct InstantiationArgs2 *args)
{
    memset(args, 0, sizeof(*args));
}

WASMModuleInstanceCommon *
wasm_runtime_instantiate_ex(WASMModuleCommon *module,
                            const InstantiationArgs *args, char *error_buf,
                            uint32 error_buf_size)
{
    struct InstantiationArgs2 v2;
    instantiation_args_set_defaults(&v2);
    v2.v1 = *args;
    return wasm_runtime_instantiate_ex2(module, &v2, error_buf, error_buf_size);
}

bool
wasm_runtime_instantiation_args_create(struct InstantiationArgs2 **p)
{
    struct InstantiationArgs2 *args = wasm_runtime_malloc(sizeof(*args));
    if (args == NULL) {
        return false;
    }
    instantiation_args_set_defaults(args);
    *p = args;
    return true;
}

void
wasm_runtime_instantiation_args_destroy(struct InstantiationArgs2 *p)
{
    wasm_runtime_free(p);
}

void
wasm_runtime_instantiation_args_set_default_stack_size(
    struct InstantiationArgs2 *p, uint32 v)
{
    p->v1.default_stack_size = v;
}

void
wasm_runtime_instantiation_args_set_host_managed_heap_size(
    struct InstantiationArgs2 *p, uint32 v)
{
    p->v1.host_managed_heap_size = v;
}

void
wasm_runtime_instantiation_args_set_max_memory_pages(
    struct InstantiationArgs2 *p, uint32 v)
{
    p->v1.max_memory_pages = v;
}

WASMModuleInstanceCommon *
wasm_runtime_instantiate_ex2(WASMModuleCommon *module,
                             const struct InstantiationArgs2 *args,
                             char *error_buf, uint32 error_buf_size)
{
    return wasm_runtime_instantiate_internal(
        module, NULL, NULL, args->v1.default_stack_size,
        args->v1.host_managed_heap_size, args->v1.max_memory_pages, error_buf,
        error_buf_size);
}

void
wasm_runtime_deinstantiate_internal(WASMModuleInstanceCommon *module_inst,
                                    bool is_sub_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        wasm_deinstantiate((WASMModuleInstance *)module_inst, is_sub_inst);
        return;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        aot_deinstantiate((AOTModuleInstance *)module_inst, is_sub_inst);
        return;
    }
#endif
}

bool
wasm_runtime_set_running_mode(wasm_module_inst_t module_inst,
                              RunningMode running_mode)
{
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return true;
#endif

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *module_inst_interp =
            (WASMModuleInstance *)module_inst;

        return wasm_set_running_mode(module_inst_interp, running_mode);
    }
#endif

    return false;
}

RunningMode
wasm_runtime_get_running_mode(wasm_module_inst_t module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *module_inst_interp =
            (WASMModuleInstance *)module_inst;
        return module_inst_interp->e->running_mode;
    }
#endif

    return Mode_Default;
}

void
wasm_runtime_deinstantiate(WASMModuleInstanceCommon *module_inst)
{
    wasm_runtime_deinstantiate_internal(module_inst, false);
}

WASMModuleCommon *
wasm_runtime_get_module(WASMModuleInstanceCommon *module_inst)
{
    return (WASMModuleCommon *)((WASMModuleInstance *)module_inst)->module;
}

WASMExecEnv *
wasm_runtime_create_exec_env(WASMModuleInstanceCommon *module_inst,
                             uint32 stack_size)
{
    return wasm_exec_env_create(module_inst, stack_size);
}

void
wasm_runtime_destroy_exec_env(WASMExecEnv *exec_env)
{
    wasm_exec_env_destroy(exec_env);
}

#if WASM_ENABLE_COPY_CALL_STACK != 0
uint32
wasm_copy_callstack(const wasm_exec_env_t exec_env, WASMCApiFrame *buffer,
                    const uint32 length, const uint32 skip_n, char *error_buf,
                    uint32_t error_buf_size)
{
    /*
     * Note for devs: please refrain from such modifications inside of
     * wasm_copy_callstack to preserve async-signal-safety
     * - any allocations/freeing memory
     * - dereferencing any pointers other than: exec_env, exec_env->module_inst,
     * exec_env->module_inst->module, pointers between stack's bottom and
     * top_boundary For more details check wasm_copy_callstack in
     * wasm_export.h
     */
#if WASM_ENABLE_DUMP_CALL_STACK
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)get_module_inst(exec_env);

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_interp_copy_callstack(exec_env, buffer, length, skip_n,
                                          error_buf, error_buf_size);
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return aot_copy_callstack(exec_env, buffer, length, skip_n, error_buf,
                                  error_buf_size);
    }
#endif
#endif
    char *err_msg = "No copy_callstack API was actually executed";
    strncpy(error_buf, err_msg, error_buf_size);
    return 0;
}
#endif // WASM_ENABLE_COPY_CALL_STACK

bool
wasm_runtime_init_thread_env(void)
{
#ifdef BH_PLATFORM_WINDOWS
    if (os_thread_env_init() != 0)
        return false;
#endif

#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (!runtime_signal_init()) {
#ifdef BH_PLATFORM_WINDOWS
        os_thread_env_destroy();
#endif
        return false;
    }
#endif

#if WASM_ENABLE_THREAD_MGR != 0 && defined(OS_ENABLE_WAKEUP_BLOCKING_OP)
    os_end_blocking_op();
#endif

    return true;
}

void
wasm_runtime_destroy_thread_env(void)
{
#ifdef OS_ENABLE_HW_BOUND_CHECK
    runtime_signal_destroy();
#endif

#ifdef BH_PLATFORM_WINDOWS
    os_thread_env_destroy();
#endif
}

bool
wasm_runtime_thread_env_inited(void)
{
#ifdef BH_PLATFORM_WINDOWS
    if (!os_thread_env_inited())
        return false;
#endif

#if WASM_ENABLE_AOT != 0
#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (!os_thread_signal_inited())
        return false;
#endif
#endif
    return true;
}

#if (WASM_ENABLE_MEMORY_PROFILING != 0) || (WASM_ENABLE_MEMORY_TRACING != 0)
void
wasm_runtime_dump_module_mem_consumption(const WASMModuleCommon *module)
{
    WASMModuleMemConsumption mem_conspn = { 0 };

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        wasm_get_module_mem_consumption((WASMModule *)module, &mem_conspn);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        aot_get_module_mem_consumption((AOTModule *)module, &mem_conspn);
    }
#endif

    os_printf("WASM module memory consumption, total size: %u\n",
              mem_conspn.total_size);
    os_printf("    module struct size: %u\n", mem_conspn.module_struct_size);
    os_printf("    types size: %u\n", mem_conspn.types_size);
    os_printf("    imports size: %u\n", mem_conspn.imports_size);
    os_printf("    funcs size: %u\n", mem_conspn.functions_size);
    os_printf("    tables size: %u\n", mem_conspn.tables_size);
    os_printf("    memories size: %u\n", mem_conspn.memories_size);
    os_printf("    globals size: %u\n", mem_conspn.globals_size);
    os_printf("    exports size: %u\n", mem_conspn.exports_size);
    os_printf("    table segs size: %u\n", mem_conspn.table_segs_size);
    os_printf("    data segs size: %u\n", mem_conspn.data_segs_size);
    os_printf("    const strings size: %u\n", mem_conspn.const_strs_size);
#if WASM_ENABLE_AOT != 0
    os_printf("    aot code size: %u\n", mem_conspn.aot_code_size);
#endif
}

void
wasm_runtime_dump_module_inst_mem_consumption(
    const WASMModuleInstanceCommon *module_inst)
{
    WASMModuleInstMemConsumption mem_conspn = { 0 };

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        wasm_get_module_inst_mem_consumption((WASMModuleInstance *)module_inst,
                                             &mem_conspn);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        aot_get_module_inst_mem_consumption((AOTModuleInstance *)module_inst,
                                            &mem_conspn);
    }
#endif

    os_printf("WASM module inst memory consumption, total size: %lu\n",
              mem_conspn.total_size);
    os_printf("    module inst struct size: %u\n",
              mem_conspn.module_inst_struct_size);
    os_printf("    memories size: %lu\n", mem_conspn.memories_size);
    os_printf("        app heap size: %u\n", mem_conspn.app_heap_size);
    os_printf("    tables size: %u\n", mem_conspn.tables_size);
    os_printf("    functions size: %u\n", mem_conspn.functions_size);
    os_printf("    globals size: %u\n", mem_conspn.globals_size);
    os_printf("    exports size: %u\n", mem_conspn.exports_size);
}

void
wasm_runtime_dump_exec_env_mem_consumption(const WASMExecEnv *exec_env)
{
    uint32 total_size =
        offsetof(WASMExecEnv, wasm_stack_u.bottom) + exec_env->wasm_stack_size;

    os_printf("Exec env memory consumption, total size: %u\n", total_size);
    os_printf("    exec env struct size: %u\n",
              offsetof(WASMExecEnv, wasm_stack_u.bottom));
#if WASM_ENABLE_INTERP != 0 && WASM_ENABLE_FAST_INTERP == 0
    os_printf("        block addr cache size: %u\n",
              sizeof(exec_env->block_addr_cache));
#endif
    os_printf("    stack size: %u\n", exec_env->wasm_stack_size);
}

uint32
gc_get_heap_highmark_size(void *heap);

void
wasm_runtime_dump_mem_consumption(WASMExecEnv *exec_env)
{
    WASMModuleInstMemConsumption module_inst_mem_consps;
    WASMModuleMemConsumption module_mem_consps;
    WASMModuleInstanceCommon *module_inst_common;
    WASMModuleCommon *module_common = NULL;
    void *heap_handle = NULL;
    uint32 app_heap_peak_size = 0;
    uint32 max_aux_stack_used = -1;
    uint64 total_size = 0;

    module_inst_common = exec_env->module_inst;
#if WASM_ENABLE_INTERP != 0
    if (module_inst_common->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *wasm_module_inst =
            (WASMModuleInstance *)module_inst_common;
        WASMModule *wasm_module = wasm_module_inst->module;
        module_common = (WASMModuleCommon *)wasm_module;
        if (wasm_module_inst->memories) {
            heap_handle = wasm_module_inst->memories[0]->heap_handle;
        }
        wasm_get_module_inst_mem_consumption(wasm_module_inst,
                                             &module_inst_mem_consps);
        wasm_get_module_mem_consumption(wasm_module, &module_mem_consps);
        if (wasm_module_inst->module->aux_stack_top_global_index != (uint32)-1)
            max_aux_stack_used = wasm_module_inst->e->max_aux_stack_used;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst_common->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *aot_module_inst =
            (AOTModuleInstance *)module_inst_common;
        AOTModule *aot_module = (AOTModule *)aot_module_inst->module;
        module_common = (WASMModuleCommon *)aot_module;
        if (aot_module_inst->memories) {
            AOTMemoryInstance **memories = aot_module_inst->memories;
            heap_handle = memories[0]->heap_handle;
        }
        aot_get_module_inst_mem_consumption(aot_module_inst,
                                            &module_inst_mem_consps);
        aot_get_module_mem_consumption(aot_module, &module_mem_consps);
    }
#endif

    bh_assert(module_common != NULL);

    if (heap_handle) {
        app_heap_peak_size = gc_get_heap_highmark_size(heap_handle);
    }

    total_size = offsetof(WASMExecEnv, wasm_stack_u.bottom)
                 + exec_env->wasm_stack_size + module_mem_consps.total_size
                 + module_inst_mem_consps.total_size;

    os_printf("\nMemory consumption summary (bytes):\n");
    wasm_runtime_dump_module_mem_consumption(module_common);
    wasm_runtime_dump_module_inst_mem_consumption(module_inst_common);
    wasm_runtime_dump_exec_env_mem_consumption(exec_env);
    os_printf("\nTotal memory consumption of module, module inst and "
              "exec env: %" PRIu64 "\n",
              total_size);
    os_printf("Total interpreter stack used: %u\n",
              exec_env->max_wasm_stack_used);

    if (max_aux_stack_used != (uint32)-1)
        os_printf("Total auxiliary stack used: %u\n", max_aux_stack_used);
    else
        os_printf("Total aux stack used: no enough info to profile\n");

    /*
     * Report the native stack usage estimation.
     *
     * Unlike the aux stack above, we report the amount unused
     * because we don't know the stack "bottom".
     *
     * Note that this is just about what the runtime itself observed.
     * It doesn't cover host func implementations, signal handlers, etc.
     */
    if (exec_env->native_stack_top_min != (void *)UINTPTR_MAX)
        os_printf("Native stack left: %zd\n",
                  exec_env->native_stack_top_min
                      - exec_env->native_stack_boundary);
    else
        os_printf("Native stack left: no enough info to profile\n");

    os_printf("Total app heap used: %u\n", app_heap_peak_size);
}
#endif /* end of (WASM_ENABLE_MEMORY_PROFILING != 0) \
                 || (WASM_ENABLE_MEMORY_TRACING != 0) */

#if WASM_ENABLE_PERF_PROFILING != 0
void
wasm_runtime_dump_perf_profiling(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        wasm_dump_perf_profiling((WASMModuleInstance *)module_inst);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        aot_dump_perf_profiling((AOTModuleInstance *)module_inst);
    }
#endif
}

double
wasm_runtime_sum_wasm_exec_time(WASMModuleInstanceCommon *inst)
{
#if WASM_ENABLE_INTERP != 0
    if (inst->module_type == Wasm_Module_Bytecode)
        return wasm_summarize_wasm_execute_time((WASMModuleInstance *)inst);
#endif

#if WASM_ENABLE_AOT != 0
    if (inst->module_type == Wasm_Module_AoT)
        return aot_summarize_wasm_execute_time((AOTModuleInstance *)inst);
#endif

    return 0.0;
}

double
wasm_runtime_get_wasm_func_exec_time(WASMModuleInstanceCommon *inst,
                                     const char *func_name)
{
#if WASM_ENABLE_INTERP != 0
    if (inst->module_type == Wasm_Module_Bytecode)
        return wasm_get_wasm_func_exec_time((WASMModuleInstance *)inst,
                                            func_name);
#endif

#if WASM_ENABLE_AOT != 0
    if (inst->module_type == Wasm_Module_AoT)
        return aot_get_wasm_func_exec_time((AOTModuleInstance *)inst,
                                           func_name);
#endif

    return 0.0;
}
#endif /* WASM_ENABLE_PERF_PROFILING != 0 */

WASMModuleInstanceCommon *
wasm_runtime_get_module_inst(WASMExecEnv *exec_env)
{
    return wasm_exec_env_get_module_inst(exec_env);
}

void
wasm_runtime_set_module_inst(WASMExecEnv *exec_env,
                             WASMModuleInstanceCommon *const module_inst)
{
    wasm_exec_env_set_module_inst(exec_env, module_inst);
}

bool
wasm_runtime_get_export_global_inst(WASMModuleInstanceCommon *const module_inst,
                                    char const *name,
                                    wasm_global_inst_t *global_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        const WASMModuleInstance *wasm_module_inst =
            (const WASMModuleInstance *)module_inst;
        const WASMModule *wasm_module = wasm_module_inst->module;
        uint32 i;
        for (i = 0; i < wasm_module->export_count; i++) {
            const WASMExport *wasm_export = &wasm_module->exports[i];
            if ((wasm_export->kind == WASM_IMPORT_EXPORT_KIND_GLOBAL)
                && !strcmp(wasm_export->name, name)) {
                const WASMModuleInstanceExtra *e =
                    (WASMModuleInstanceExtra *)wasm_module_inst->e;
                const WASMGlobalInstance *global =
                    &e->globals[wasm_export->index];
                global_inst->kind = val_type_to_val_kind(global->type);
                global_inst->is_mutable = global->is_mutable;
#if WASM_ENABLE_MULTI_MODULE == 0
                global_inst->global_data =
                    wasm_module_inst->global_data + global->data_offset;
#else
                global_inst->global_data =
                    global->import_global_inst
                        ? global->import_module_inst->global_data
                              + global->import_global_inst->data_offset
                        : wasm_module_inst->global_data + global->data_offset;
#endif
                return true;
            }
        }
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        const AOTModuleInstance *aot_module_inst =
            (AOTModuleInstance *)module_inst;
        const AOTModule *aot_module = (AOTModule *)aot_module_inst->module;
        uint32 i;
        for (i = 0; i < aot_module->export_count; i++) {
            const AOTExport *aot_export = &aot_module->exports[i];
            if ((aot_export->kind == WASM_IMPORT_EXPORT_KIND_GLOBAL)
                && !strcmp(aot_export->name, name)) {
                const AOTGlobal *global =
                    &aot_module->globals[aot_export->index];
                global_inst->kind = val_type_to_val_kind(global->type.val_type);
                global_inst->is_mutable = global->type.is_mutable;
                global_inst->global_data =
                    aot_module_inst->global_data + global->data_offset;
                return true;
            }
        }
    }
#endif

    return false;
}

bool
wasm_runtime_get_export_table_inst(WASMModuleInstanceCommon *const module_inst,
                                   char const *name,
                                   wasm_table_inst_t *table_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        const WASMModuleInstance *wasm_module_inst =
            (const WASMModuleInstance *)module_inst;
        const WASMModule *wasm_module = wasm_module_inst->module;
        uint32 i;
        for (i = 0; i < wasm_module->export_count; i++) {
            const WASMExport *wasm_export = &wasm_module->exports[i];
            if ((wasm_export->kind == WASM_IMPORT_EXPORT_KIND_TABLE)
                && !strcmp(wasm_export->name, name)) {
                const WASMTableInstance *wasm_table_inst =
                    wasm_module_inst->tables[wasm_export->index];
                table_inst->elem_kind =
                    val_type_to_val_kind(wasm_table_inst->elem_type);
                table_inst->cur_size = wasm_table_inst->cur_size;
                table_inst->max_size = wasm_table_inst->max_size;
                table_inst->elems = (void *)wasm_table_inst->elems;
                return true;
            }
        }
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        const AOTModuleInstance *aot_module_inst =
            (AOTModuleInstance *)module_inst;
        const AOTModule *aot_module = (AOTModule *)aot_module_inst->module;
        uint32 i;
        for (i = 0; i < aot_module->export_count; i++) {
            const AOTExport *aot_export = &aot_module->exports[i];
            if ((aot_export->kind == WASM_IMPORT_EXPORT_KIND_TABLE)
                && !strcmp(aot_export->name, name)) {
                const AOTTableInstance *aot_table_inst =
                    aot_module_inst->tables[aot_export->index];
                table_inst->elem_kind =
                    val_type_to_val_kind(aot_table_inst->elem_type);
                table_inst->cur_size = aot_table_inst->cur_size;
                table_inst->max_size = aot_table_inst->max_size;
                table_inst->elems = (void *)aot_table_inst->elems;
                return true;
            }
        }
    }
#endif

    return false;
}

WASMFunctionInstanceCommon *
wasm_table_get_func_inst(struct WASMModuleInstanceCommon *const module_inst,
                         const wasm_table_inst_t *table_inst, uint32_t idx)
{
    if (!table_inst) {
        bh_assert(0);
        return NULL;
    }

    if (idx >= table_inst->cur_size) {
        bh_assert(0);
        return NULL;
    }

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        const WASMModuleInstance *wasm_module_inst =
            (const WASMModuleInstance *)module_inst;
        table_elem_type_t tbl_elem_val =
            ((table_elem_type_t *)table_inst->elems)[idx];
        if (tbl_elem_val == NULL_REF) {
            return NULL;
        }

#if WASM_ENABLE_GC == 0
        uint32 func_idx = (uint32)tbl_elem_val;
#else
        uint32 func_idx =
            wasm_func_obj_get_func_idx_bound((WASMFuncObjectRef)tbl_elem_val);
#endif

        bh_assert(func_idx < wasm_module_inst->e->function_count);
        return wasm_module_inst->e->functions + func_idx;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *aot_module_inst = (AOTModuleInstance *)module_inst;
        uint32 func_idx;
        table_elem_type_t tbl_elem_val =
            ((table_elem_type_t *)table_inst->elems)[idx];
        if (tbl_elem_val == NULL_REF) {
            return NULL;
        }

#if WASM_ENABLE_GC == 0
        func_idx = (uint32)tbl_elem_val;
#else
        func_idx =
            wasm_func_obj_get_func_idx_bound((WASMFuncObjectRef)tbl_elem_val);
#endif

        return aot_get_function_instance(aot_module_inst, func_idx);
    }
#endif

    return NULL;
}

void *
wasm_runtime_get_function_attachment(WASMExecEnv *exec_env)
{
    return exec_env->attachment;
}

void
wasm_runtime_set_user_data(WASMExecEnv *exec_env, void *user_data)
{
    exec_env->user_data = user_data;
}

void *
wasm_runtime_get_user_data(WASMExecEnv *exec_env)
{
    return exec_env->user_data;
}

void
wasm_runtime_set_native_stack_boundary(WASMExecEnv *exec_env,
                                       uint8 *native_stack_boundary)
{
    exec_env->user_native_stack_boundary = native_stack_boundary;
}

#ifdef OS_ENABLE_HW_BOUND_CHECK
void
wasm_runtime_access_exce_check_guard_page()
{
    if (exec_env_tls && exec_env_tls->handle == os_self_thread()) {
        uint32 page_size = os_getpagesize();
        memset(exec_env_tls->exce_check_guard_page, 0, page_size);
    }
}
#endif

#if WASM_ENABLE_INSTRUCTION_METERING != 0
void
wasm_runtime_set_instruction_count_limit(WASMExecEnv *exec_env,
                                         int instructions_to_execute)
{
    exec_env->instructions_to_execute = instructions_to_execute;
}
#endif

WASMFuncType *
wasm_runtime_get_function_type(const WASMFunctionInstanceCommon *function,
                               uint32 module_type)
{
    WASMFuncType *type = NULL;

#if WASM_ENABLE_INTERP != 0
    if (module_type == Wasm_Module_Bytecode) {
        WASMFunctionInstance *wasm_func = (WASMFunctionInstance *)function;
        type = wasm_func->is_import_func ? wasm_func->u.func_import->func_type
                                         : wasm_func->u.func->func_type;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_type == Wasm_Module_AoT) {
        AOTFunctionInstance *aot_func = (AOTFunctionInstance *)function;
        type = aot_func->is_import_func ? aot_func->u.func_import->func_type
                                        : aot_func->u.func.func_type;
    }
#endif

    return type;
}

WASMFunctionInstanceCommon *
wasm_runtime_lookup_function(WASMModuleInstanceCommon *const module_inst,
                             const char *name)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return (WASMFunctionInstanceCommon *)wasm_lookup_function(
            (const WASMModuleInstance *)module_inst, name);
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return (WASMFunctionInstanceCommon *)aot_lookup_function(
            (const AOTModuleInstance *)module_inst, name);
#endif
    return NULL;
}

uint32
wasm_func_get_param_count(WASMFunctionInstanceCommon *const func_inst,
                          WASMModuleInstanceCommon *const module_inst)
{
    WASMFuncType *type =
        wasm_runtime_get_function_type(func_inst, module_inst->module_type);
    bh_assert(type);

    return type->param_count;
}

uint32
wasm_func_get_result_count(WASMFunctionInstanceCommon *const func_inst,
                           WASMModuleInstanceCommon *const module_inst)
{
    WASMFuncType *type =
        wasm_runtime_get_function_type(func_inst, module_inst->module_type);
    bh_assert(type);

    return type->result_count;
}

static uint8
val_type_to_val_kind(uint8 value_type)
{
    switch (value_type) {
        case VALUE_TYPE_I32:
            return WASM_I32;
        case VALUE_TYPE_I64:
            return WASM_I64;
        case VALUE_TYPE_F32:
            return WASM_F32;
        case VALUE_TYPE_F64:
            return WASM_F64;
        case VALUE_TYPE_V128:
            return WASM_V128;
        case VALUE_TYPE_FUNCREF:
            return WASM_FUNCREF;
        case VALUE_TYPE_EXTERNREF:
            return WASM_EXTERNREF;
        default:
            bh_assert(0);
            return 0;
    }
}

void
wasm_func_get_param_types(WASMFunctionInstanceCommon *const func_inst,
                          WASMModuleInstanceCommon *const module_inst,
                          wasm_valkind_t *param_types)
{
    WASMFuncType *type =
        wasm_runtime_get_function_type(func_inst, module_inst->module_type);
    uint32 i;

    bh_assert(type);

    for (i = 0; i < type->param_count; i++) {
        param_types[i] = val_type_to_val_kind(type->types[i]);
    }
}

void
wasm_func_get_result_types(WASMFunctionInstanceCommon *const func_inst,
                           WASMModuleInstanceCommon *const module_inst,
                           wasm_valkind_t *result_types)
{
    WASMFuncType *type =
        wasm_runtime_get_function_type(func_inst, module_inst->module_type);
    uint32 i;

    bh_assert(type);

    for (i = 0; i < type->result_count; i++) {
        result_types[i] =
            val_type_to_val_kind(type->types[type->param_count + i]);
    }
}

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
/* (uintptr_t)externref -> (uint32)index */
/*   argv               ->   *ret_argv */
static bool
wasm_runtime_prepare_call_function(WASMExecEnv *exec_env,
                                   WASMFunctionInstanceCommon *function,
                                   uint32 *argv, uint32 argc, uint32 **ret_argv,
                                   uint32 *ret_argc_param,
                                   uint32 *ret_argc_result)
{
    uint32 *new_argv = NULL, argv_i = 0, new_argv_i = 0, param_i = 0,
           result_i = 0;
    bool need_param_transform = false, need_result_transform = false;
    uint64 size = 0;
    WASMFuncType *func_type = wasm_runtime_get_function_type(
        function, exec_env->module_inst->module_type);

    bh_assert(func_type);

    *ret_argc_param = func_type->param_cell_num;
    *ret_argc_result = func_type->ret_cell_num;
    for (param_i = 0; param_i < func_type->param_count; param_i++) {
        if (VALUE_TYPE_EXTERNREF == func_type->types[param_i]) {
            need_param_transform = true;
        }
    }

    for (result_i = 0; result_i < func_type->result_count; result_i++) {
        if (VALUE_TYPE_EXTERNREF
            == func_type->types[func_type->param_count + result_i]) {
            need_result_transform = true;
        }
    }

    if (!need_param_transform && !need_result_transform) {
        *ret_argv = argv;
        return true;
    }

    if (func_type->param_cell_num >= func_type->ret_cell_num) {
        size = sizeof(uint32) * func_type->param_cell_num;
    }
    else {
        size = sizeof(uint32) * func_type->ret_cell_num;
    }

    if (!(new_argv = runtime_malloc(size, exec_env->module_inst, NULL, 0))) {
        return false;
    }

    if (!need_param_transform) {
        bh_memcpy_s(new_argv, (uint32)size, argv, (uint32)size);
    }
    else {
        for (param_i = 0; param_i < func_type->param_count && argv_i < argc
                          && new_argv_i < func_type->param_cell_num;
             param_i++) {
            uint8 param_type = func_type->types[param_i];
            if (VALUE_TYPE_EXTERNREF == param_type) {
                void *externref_obj;
                uint32 externref_index;

#if UINTPTR_MAX == UINT32_MAX
                externref_obj = (void *)argv[argv_i];
#else
                union {
                    uintptr_t val;
                    uint32 parts[2];
                } u;

                u.parts[0] = argv[argv_i];
                u.parts[1] = argv[argv_i + 1];
                externref_obj = (void *)u.val;
#endif
                if (!wasm_externref_obj2ref(exec_env->module_inst,
                                            externref_obj, &externref_index)) {
                    wasm_runtime_free(new_argv);
                    return false;
                }

                new_argv[new_argv_i] = externref_index;
                argv_i += sizeof(uintptr_t) / sizeof(uint32);
                new_argv_i++;
            }
            else {
                uint16 param_cell_num = wasm_value_type_cell_num(param_type);
                uint32 param_size = sizeof(uint32) * param_cell_num;
                bh_memcpy_s(new_argv + new_argv_i, param_size, argv + argv_i,
                            param_size);
                argv_i += param_cell_num;
                new_argv_i += param_cell_num;
            }
        }
    }

    *ret_argv = new_argv;
    return true;
}

/* (uintptr_t)externref <- (uint32)index */
/*   argv               <-   new_argv */
static bool
wasm_runtime_finalize_call_function(WASMExecEnv *exec_env,
                                    WASMFunctionInstanceCommon *function,
                                    uint32 *argv, uint32 argc, uint32 *ret_argv)
{
    uint32 argv_i = 0, result_i = 0, ret_argv_i = 0;
    WASMFuncType *func_type;

    bh_assert((argv && ret_argv) || (argc == 0));

    if (argv == ret_argv) {
        /* no need to transform externref results */
        return true;
    }

    func_type = wasm_runtime_get_function_type(
        function, exec_env->module_inst->module_type);
    bh_assert(func_type);

    for (result_i = 0; result_i < func_type->result_count && argv_i < argc;
         result_i++) {
        uint8 result_type = func_type->types[func_type->param_count + result_i];
        if (result_type == VALUE_TYPE_EXTERNREF) {
            void *externref_obj;
#if UINTPTR_MAX != UINT32_MAX
            union {
                uintptr_t val;
                uint32 parts[2];
            } u;
#endif

            if (!wasm_externref_ref2obj(argv[argv_i], &externref_obj)) {
                wasm_runtime_free(argv);
                return false;
            }

#if UINTPTR_MAX == UINT32_MAX
            ret_argv[ret_argv_i] = (uintptr_t)externref_obj;
#else
            u.val = (uintptr_t)externref_obj;
            ret_argv[ret_argv_i] = u.parts[0];
            ret_argv[ret_argv_i + 1] = u.parts[1];
#endif
            argv_i += 1;
            ret_argv_i += sizeof(uintptr_t) / sizeof(uint32);
        }
        else {
            uint16 result_cell_num = wasm_value_type_cell_num(result_type);
            uint32 result_size = sizeof(uint32) * result_cell_num;
            bh_memcpy_s(ret_argv + ret_argv_i, result_size, argv + argv_i,
                        result_size);
            argv_i += result_cell_num;
            ret_argv_i += result_cell_num;
        }
    }

    wasm_runtime_free(argv);
    return true;
}
#endif

bool
wasm_runtime_call_wasm(WASMExecEnv *exec_env,
                       WASMFunctionInstanceCommon *function, uint32 argc,
                       uint32 argv[])
{
    bool ret = false;
    uint32 *new_argv = NULL, param_argc;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    uint32 result_argc = 0;
#endif

    if (!wasm_runtime_exec_env_check(exec_env)) {
        LOG_ERROR("Invalid exec env stack info.");
        return false;
    }

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    if (!wasm_runtime_prepare_call_function(exec_env, function, argv, argc,
                                            &new_argv, &param_argc,
                                            &result_argc)) {
        wasm_runtime_set_exception(exec_env->module_inst,
                                   "the arguments conversion is failed");
        return false;
    }
#else
    new_argv = argv;
    param_argc = argc;
#endif

#if WASM_ENABLE_INTERP != 0
    if (exec_env->module_inst->module_type == Wasm_Module_Bytecode)
        ret = wasm_call_function(exec_env, (WASMFunctionInstance *)function,
                                 param_argc, new_argv);
#endif
#if WASM_ENABLE_AOT != 0
    if (exec_env->module_inst->module_type == Wasm_Module_AoT)
        ret = aot_call_function(exec_env, (AOTFunctionInstance *)function,
                                param_argc, new_argv);
#endif
    if (!ret) {
        if (new_argv != argv) {
            wasm_runtime_free(new_argv);
        }
        return false;
    }

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    if (!wasm_runtime_finalize_call_function(exec_env, function, new_argv,
                                             result_argc, argv)) {
        wasm_runtime_set_exception(exec_env->module_inst,
                                   "the result conversion is failed");
        return false;
    }
#endif

    return ret;
}

static void
parse_args_to_uint32_array(WASMFuncType *type, wasm_val_t *args,
                           uint32 *out_argv)
{
    uint32 i, p;

    for (i = 0, p = 0; i < type->param_count; i++) {
        switch (args[i].kind) {
            case WASM_I32:
                out_argv[p++] = args[i].of.i32;
                break;
            case WASM_I64:
            {
                union {
                    uint64 val;
                    uint32 parts[2];
                } u;
                u.val = args[i].of.i64;
                out_argv[p++] = u.parts[0];
                out_argv[p++] = u.parts[1];
                break;
            }
            case WASM_F32:
            {
                union {
                    float32 val;
                    uint32 part;
                } u;
                u.val = args[i].of.f32;
                out_argv[p++] = u.part;
                break;
            }
            case WASM_F64:
            {
                union {
                    float64 val;
                    uint32 parts[2];
                } u;
                u.val = args[i].of.f64;
                out_argv[p++] = u.parts[0];
                out_argv[p++] = u.parts[1];
                break;
            }
            case WASM_V128:
            {
                bh_assert(0);
                break;
            }
#if WASM_ENABLE_REF_TYPES != 0
#if WASM_ENABLE_GC == 0
            case WASM_FUNCREF:
            {
                out_argv[p++] = args[i].of.i32;
                break;
            }
#else
            case WASM_FUNCREF:
#endif
            case WASM_EXTERNREF:
            {
#if UINTPTR_MAX == UINT32_MAX
                out_argv[p++] = args[i].of.foreign;
#else
                union {
                    uintptr_t val;
                    uint32 parts[2];
                } u;

                u.val = (uintptr_t)args[i].of.foreign;
                out_argv[p++] = u.parts[0];
                out_argv[p++] = u.parts[1];
#endif
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }
}

static void
parse_uint32_array_to_results(WASMFuncType *type, uint32 *argv,
                              wasm_val_t *out_results)
{
    uint32 i, p;

    for (i = 0, p = 0; i < type->result_count; i++) {
        switch (type->types[type->param_count + i]) {
            case VALUE_TYPE_I32:
                out_results[i].kind = WASM_I32;
                out_results[i].of.i32 = (int32)argv[p++];
                break;
            case VALUE_TYPE_I64:
            {
                union {
                    uint64 val;
                    uint32 parts[2];
                } u;
                u.parts[0] = argv[p++];
                u.parts[1] = argv[p++];
                out_results[i].kind = WASM_I64;
                out_results[i].of.i64 = u.val;
                break;
            }
            case VALUE_TYPE_F32:
            {
                union {
                    float32 val;
                    uint32 part;
                } u;
                u.part = argv[p++];
                out_results[i].kind = WASM_F32;
                out_results[i].of.f32 = u.val;
                break;
            }
            case VALUE_TYPE_F64:
            {
                union {
                    float64 val;
                    uint32 parts[2];
                } u;
                u.parts[0] = argv[p++];
                u.parts[1] = argv[p++];
                out_results[i].kind = WASM_F64;
                out_results[i].of.f64 = u.val;
                break;
            }
            case VALUE_TYPE_V128:
            {
                bh_assert(0);
                break;
            }
#if WASM_ENABLE_REF_TYPES != 0
#if WASM_ENABLE_GC == 0
            case VALUE_TYPE_FUNCREF:
            {
                out_results[i].kind = WASM_I32;
                out_results[i].of.i32 = (int32)argv[p++];
                break;
            }
            case VALUE_TYPE_EXTERNREF:
#else
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#endif /* end of WASM_ENABLE_GC == 0 */
            {
#if UINTPTR_MAX == UINT32_MAX
                out_results[i].kind = WASM_EXTERNREF;
                out_results[i].of.foreign = (uintptr_t)argv[p++];
#else
                union {
                    uintptr_t val;
                    uint32 parts[2];
                } u;
                u.parts[0] = argv[p++];
                u.parts[1] = argv[p++];
                out_results[i].kind = WASM_EXTERNREF;
                out_results[i].of.foreign = u.val;
#endif
                break;
            }
#endif /* end of WASM_ENABLE_REF_TYPES != 0 */
            default:
                bh_assert(0);
                break;
        }
    }
}

bool
wasm_runtime_call_wasm_a(WASMExecEnv *exec_env,
                         WASMFunctionInstanceCommon *function,
                         uint32 num_results, wasm_val_t results[],
                         uint32 num_args, wasm_val_t args[])
{
    uint32 argc, argv_buf[16] = { 0 }, *argv = argv_buf, cell_num, module_type;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    uint32 i, param_size_in_double_world = 0, result_size_in_double_world = 0;
#endif
    uint64 total_size;
    WASMFuncType *type;
    bool ret = false;

    module_type = exec_env->module_inst->module_type;
    type = wasm_runtime_get_function_type(function, module_type);

    if (!type) {
        LOG_ERROR("Function type get failed, WAMR Interpreter and AOT must be "
                  "enabled at least one.");
        goto fail1;
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
    argc = param_size_in_double_world;
    cell_num = (argc >= result_size_in_double_world)
                   ? argc
                   : result_size_in_double_world;
#else
    argc = type->param_cell_num;
    cell_num = (argc > type->ret_cell_num) ? argc : type->ret_cell_num;
#endif

    if (num_results != type->result_count) {
        LOG_ERROR(
            "The result value number does not match the function declaration.");
        goto fail1;
    }

    if (num_args != type->param_count) {
        LOG_ERROR("The argument value number does not match the function "
                  "declaration.");
        goto fail1;
    }

    total_size = sizeof(uint32) * (uint64)(cell_num > 2 ? cell_num : 2);
    if (total_size > sizeof(argv_buf)) {
        if (!(argv =
                  runtime_malloc(total_size, exec_env->module_inst, NULL, 0))) {
            goto fail1;
        }
    }

    parse_args_to_uint32_array(type, args, argv);
    if (!(ret = wasm_runtime_call_wasm(exec_env, function, argc, argv)))
        goto fail2;

    parse_uint32_array_to_results(type, argv, results);

fail2:
    if (argv != argv_buf)
        wasm_runtime_free(argv);
fail1:
    return ret;
}

bool
wasm_runtime_call_wasm_v(WASMExecEnv *exec_env,
                         WASMFunctionInstanceCommon *function,
                         uint32 num_results, wasm_val_t results[],
                         uint32 num_args, ...)
{
    wasm_val_t args_buf[8] = { 0 }, *args = args_buf;
    WASMFuncType *type = NULL;
    bool ret = false;
    uint64 total_size;
    uint32 i = 0, module_type;
    va_list vargs;

    module_type = exec_env->module_inst->module_type;
    type = wasm_runtime_get_function_type(function, module_type);

    if (!type) {
        LOG_ERROR("Function type get failed, WAMR Interpreter and AOT "
                  "must be enabled at least one.");
        goto fail1;
    }

    if (num_args != type->param_count) {
        LOG_ERROR("The argument value number does not match the "
                  "function declaration.");
        goto fail1;
    }

    total_size = sizeof(wasm_val_t) * (uint64)num_args;
    if (total_size > sizeof(args_buf)) {
        if (!(args =
                  runtime_malloc(total_size, exec_env->module_inst, NULL, 0))) {
            goto fail1;
        }
    }

    va_start(vargs, num_args);
    for (i = 0; i < num_args; i++) {
        switch (type->types[i]) {
            case VALUE_TYPE_I32:
                args[i].kind = WASM_I32;
                args[i].of.i32 = va_arg(vargs, uint32);
                break;
            case VALUE_TYPE_I64:
                args[i].kind = WASM_I64;
                args[i].of.i64 = va_arg(vargs, uint64);
                break;
            case VALUE_TYPE_F32:
                args[i].kind = WASM_F32;
                args[i].of.f32 = (float32)va_arg(vargs, float64);
                break;
            case VALUE_TYPE_F64:
                args[i].kind = WASM_F64;
                args[i].of.f64 = va_arg(vargs, float64);
                break;
            case VALUE_TYPE_V128:
                bh_assert(0);
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
            {
                args[i].kind = WASM_FUNCREF;
                args[i].of.i32 = va_arg(vargs, uint32);
                break;
            }
            case VALUE_TYPE_EXTERNREF:
            {
                args[i].kind = WASM_EXTERNREF;
                args[i].of.foreign = va_arg(vargs, uintptr_t);
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }
    va_end(vargs);

    ret = wasm_runtime_call_wasm_a(exec_env, function, num_results, results,
                                   num_args, args);
    if (args != args_buf)
        wasm_runtime_free(args);

fail1:
    return ret;
}

bool
wasm_runtime_create_exec_env_singleton(
    WASMModuleInstanceCommon *module_inst_comm)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;
    WASMExecEnv *exec_env = NULL;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    if (module_inst->exec_env_singleton) {
        return true;
    }

    exec_env = wasm_exec_env_create(module_inst_comm,
                                    module_inst->default_wasm_stack_size);
    if (exec_env)
        module_inst->exec_env_singleton = exec_env;

    return exec_env ? true : false;
}

WASMExecEnv *
wasm_runtime_get_exec_env_singleton(WASMModuleInstanceCommon *module_inst_comm)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    if (!module_inst->exec_env_singleton) {
        wasm_runtime_create_exec_env_singleton(module_inst_comm);
    }
    return module_inst->exec_env_singleton;
}

static void
wasm_set_exception_local(WASMModuleInstance *module_inst, const char *exception)
{
    exception_lock(module_inst);
    if (exception) {
        snprintf(module_inst->cur_exception, sizeof(module_inst->cur_exception),
                 "Exception: %s", exception);
    }
    else {
        module_inst->cur_exception[0] = '\0';
    }
    exception_unlock(module_inst);
}

void
wasm_set_exception(WASMModuleInstance *module_inst, const char *exception)
{
#if WASM_ENABLE_THREAD_MGR != 0
    WASMExecEnv *exec_env =
        wasm_clusters_search_exec_env((WASMModuleInstanceCommon *)module_inst);
    if (exec_env) {
        wasm_cluster_set_exception(exec_env, exception);
    }
    else {
        wasm_set_exception_local(module_inst, exception);
    }
#else
    wasm_set_exception_local(module_inst, exception);
#endif
}

/* clang-format off */
static const char *exception_msgs[] = {
    "unreachable",                    /* EXCE_UNREACHABLE */
    "allocate memory failed",         /* EXCE_OUT_OF_MEMORY */
    "out of bounds memory access",    /* EXCE_OUT_OF_BOUNDS_MEMORY_ACCESS */
    "integer overflow",               /* EXCE_INTEGER_OVERFLOW */
    "integer divide by zero",         /* EXCE_INTEGER_DIVIDE_BY_ZERO */
    "invalid conversion to integer",  /* EXCE_INVALID_CONVERSION_TO_INTEGER */
    "indirect call type mismatch",    /* EXCE_INVALID_FUNCTION_TYPE_INDEX */
    "invalid function index",         /* EXCE_INVALID_FUNCTION_INDEX */
    "undefined element",              /* EXCE_UNDEFINED_ELEMENT */
    "uninitialized element",          /* EXCE_UNINITIALIZED_ELEMENT */
    "failed to call unlinked import function", /* EXCE_CALL_UNLINKED_IMPORT_FUNC */
    "native stack overflow",          /* EXCE_NATIVE_STACK_OVERFLOW */
    "unaligned atomic",               /* EXCE_UNALIGNED_ATOMIC */
    "wasm auxiliary stack overflow",  /* EXCE_AUX_STACK_OVERFLOW */
    "wasm auxiliary stack underflow", /* EXCE_AUX_STACK_UNDERFLOW */
    "out of bounds table access",     /* EXCE_OUT_OF_BOUNDS_TABLE_ACCESS */
    "wasm operand stack overflow",    /* EXCE_OPERAND_STACK_OVERFLOW */
    "failed to compile fast jit function", /* EXCE_FAILED_TO_COMPILE_FAST_JIT_FUNC */
    /* GC related exceptions */
    "null function reference",        /* EXCE_NULL_FUNC_OBJ */
    "null structure reference",       /* EXCE_NULL_STRUCT_OBJ */
    "null array reference",           /* EXCE_NULL_ARRAY_OBJ */
    "null i31 reference",             /* EXCE_NULL_I31_OBJ */
    "null reference",                 /* EXCE_NULL_REFERENCE */
    "create rtt type failed",         /* EXCE_FAILED_TO_CREATE_RTT_TYPE */
    "create struct object failed",    /* EXCE_FAILED_TO_CREATE_STRUCT_OBJ */
    "create array object failed",     /* EXCE_FAILED_TO_CREATE_ARRAY_OBJ */
    "create externref object failed", /* EXCE_FAILED_TO_CREATE_EXTERNREF_OBJ */
    "cast failure",                   /* EXCE_CAST_FAILURE */
    "out of bounds array access",     /* EXCE_ARRAY_IDX_OOB */
    /* stringref related exceptions */
    "create string object failed",    /* EXCE_FAILED_TO_CREATE_STRING */
    "create stringref failed",        /* EXCE_FAILED_TO_CREATE_STRINGREF */
    "create stringview failed",       /* EXCE_FAILED_TO_CREATE_STRINGVIEW */
    "encode failed",                  /* EXCE_FAILED_TO_ENCODE_STRING */
    "",                               /* EXCE_ALREADY_THROWN */
};
/* clang-format on */

void
wasm_set_exception_with_id(WASMModuleInstance *module_inst, uint32 id)
{
    if (id < EXCE_NUM)
        wasm_set_exception(module_inst, exception_msgs[id]);
    else
        wasm_set_exception(module_inst, "unknown exception");
}

const char *
wasm_get_exception(WASMModuleInstance *module_inst)
{
    if (module_inst->cur_exception[0] == '\0')
        return NULL;
    else
        return module_inst->cur_exception;
}

bool
wasm_copy_exception(WASMModuleInstance *module_inst, char *exception_buf)
{
    bool has_exception = false;

    exception_lock(module_inst);
    if (module_inst->cur_exception[0] != '\0') {
        /* NULL is passed if the caller is not interested in getting the
         * exception content, but only in knowing if an exception has been
         * raised
         */
        if (exception_buf != NULL)
            bh_memcpy_s(exception_buf, sizeof(module_inst->cur_exception),
                        module_inst->cur_exception,
                        sizeof(module_inst->cur_exception));
        has_exception = true;
    }
    exception_unlock(module_inst);

    return has_exception;
}

void
wasm_runtime_set_exception(WASMModuleInstanceCommon *module_inst_comm,
                           const char *exception)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    wasm_set_exception(module_inst, exception);
}

const char *
wasm_runtime_get_exception(WASMModuleInstanceCommon *module_inst_comm)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    return wasm_get_exception(module_inst);
}

bool
wasm_runtime_copy_exception(WASMModuleInstanceCommon *module_inst_comm,
                            char *exception_buf)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    return wasm_copy_exception(module_inst, exception_buf);
}

void
wasm_runtime_clear_exception(WASMModuleInstanceCommon *module_inst_comm)
{
    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    wasm_runtime_set_exception(module_inst_comm, NULL);
}

void
wasm_runtime_terminate(WASMModuleInstanceCommon *module_inst_comm)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    wasm_set_exception(module_inst, "terminated by user");
}

void
wasm_runtime_set_custom_data_internal(
    WASMModuleInstanceCommon *module_inst_comm, void *custom_data)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    module_inst->custom_data = custom_data;
}

void
wasm_runtime_set_custom_data(WASMModuleInstanceCommon *module_inst,
                             void *custom_data)
{
#if WASM_ENABLE_THREAD_MGR != 0
    wasm_cluster_spread_custom_data(module_inst, custom_data);
#else
    wasm_runtime_set_custom_data_internal(module_inst, custom_data);
#endif
}

void *
wasm_runtime_get_custom_data(WASMModuleInstanceCommon *module_inst_comm)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    return module_inst->custom_data;
}

#if WASM_CONFIGURABLE_BOUNDS_CHECKS != 0
void
wasm_runtime_set_bounds_checks(WASMModuleInstanceCommon *module_inst,
                               bool enable)
{
    /* Always disable bounds checks if hw bounds checks is enabled */
#ifdef OS_ENABLE_HW_BOUND_CHECK
    enable = false;
#endif
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        ((WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e)
            ->common.disable_bounds_checks = enable ? false : true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        ((AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e)
            ->common.disable_bounds_checks = enable ? false : true;
    }
#endif
}

bool
wasm_runtime_is_bounds_checks_enabled(WASMModuleInstanceCommon *module_inst)
{

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return !((WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)
                     ->e)
                    ->common.disable_bounds_checks;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return !((AOTModuleInstanceExtra *)((WASMModuleInstance *)module_inst)
                     ->e)
                    ->common.disable_bounds_checks;
    }
#endif

    return true;
}
#endif

uint64
wasm_runtime_module_malloc_internal(WASMModuleInstanceCommon *module_inst,
                                    WASMExecEnv *exec_env, uint64 size,
                                    void **p_native_addr)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return wasm_module_malloc_internal((WASMModuleInstance *)module_inst,
                                           exec_env, size, p_native_addr);
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return aot_module_malloc_internal((AOTModuleInstance *)module_inst,
                                          exec_env, size, p_native_addr);
#endif
    return 0;
}

uint64
wasm_runtime_module_realloc_internal(WASMModuleInstanceCommon *module_inst,
                                     WASMExecEnv *exec_env, uint64 ptr,
                                     uint64 size, void **p_native_addr)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return wasm_module_realloc_internal((WASMModuleInstance *)module_inst,
                                            exec_env, ptr, size, p_native_addr);
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return aot_module_realloc_internal((AOTModuleInstance *)module_inst,
                                           exec_env, ptr, size, p_native_addr);
#endif
    return 0;
}

void
wasm_runtime_module_free_internal(WASMModuleInstanceCommon *module_inst,
                                  WASMExecEnv *exec_env, uint64 ptr)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        wasm_module_free_internal((WASMModuleInstance *)module_inst, exec_env,
                                  ptr);
        return;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        aot_module_free_internal((AOTModuleInstance *)module_inst, exec_env,
                                 ptr);
        return;
    }
#endif
}

uint64
wasm_runtime_module_malloc(WASMModuleInstanceCommon *module_inst, uint64 size,
                           void **p_native_addr)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return wasm_module_malloc((WASMModuleInstance *)module_inst, size,
                                  p_native_addr);
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return aot_module_malloc((AOTModuleInstance *)module_inst, size,
                                 p_native_addr);
#endif
    return 0;
}

uint64
wasm_runtime_module_realloc(WASMModuleInstanceCommon *module_inst, uint64 ptr,
                            uint64 size, void **p_native_addr)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return wasm_module_realloc((WASMModuleInstance *)module_inst, ptr, size,
                                   p_native_addr);
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        return aot_module_realloc((AOTModuleInstance *)module_inst, ptr, size,
                                  p_native_addr);
#endif
    return 0;
}

void
wasm_runtime_module_free(WASMModuleInstanceCommon *module_inst, uint64 ptr)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        wasm_module_free((WASMModuleInstance *)module_inst, ptr);
        return;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        aot_module_free((AOTModuleInstance *)module_inst, ptr);
        return;
    }
#endif
}

uint64
wasm_runtime_module_dup_data(WASMModuleInstanceCommon *module_inst,
                             const char *src, uint64 size)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_module_dup_data((WASMModuleInstance *)module_inst, src,
                                    size);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return aot_module_dup_data((AOTModuleInstance *)module_inst, src, size);
    }
#endif
    return 0;
}

#if WASM_ENABLE_LIBC_WASI != 0

static WASIArguments *
get_wasi_args_from_module(wasm_module_t module)
{
    WASIArguments *wasi_args = NULL;

#if WASM_ENABLE_INTERP != 0 || WASM_ENABLE_JIT != 0
    if (module->module_type == Wasm_Module_Bytecode)
        wasi_args = &((WASMModule *)module)->wasi_args;
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT)
        wasi_args = &((AOTModule *)module)->wasi_args;
#endif

    return wasi_args;
}

void
wasm_runtime_set_wasi_args_ex(WASMModuleCommon *module, const char *dir_list[],
                              uint32 dir_count, const char *map_dir_list[],
                              uint32 map_dir_count, const char *env_list[],
                              uint32 env_count, char *argv[], int argc,
                              int64 stdinfd, int64 stdoutfd, int64 stderrfd)
{
    WASIArguments *wasi_args = get_wasi_args_from_module(module);

    bh_assert(wasi_args);

    wasi_args->dir_list = dir_list;
    wasi_args->dir_count = dir_count;
    wasi_args->map_dir_list = map_dir_list;
    wasi_args->map_dir_count = map_dir_count;
    wasi_args->env = env_list;
    wasi_args->env_count = env_count;
    wasi_args->argv = argv;
    wasi_args->argc = (uint32)argc;
    wasi_args->stdio[0] = (os_raw_file_handle)stdinfd;
    wasi_args->stdio[1] = (os_raw_file_handle)stdoutfd;
    wasi_args->stdio[2] = (os_raw_file_handle)stderrfd;

#if WASM_ENABLE_MULTI_MODULE != 0
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        wasm_propagate_wasi_args((WASMModule *)module);
    }
#endif
#endif
}

void
wasm_runtime_set_wasi_args(WASMModuleCommon *module, const char *dir_list[],
                           uint32 dir_count, const char *map_dir_list[],
                           uint32 map_dir_count, const char *env_list[],
                           uint32 env_count, char *argv[], int argc)
{
    wasm_runtime_set_wasi_args_ex(module, dir_list, dir_count, map_dir_list,
                                  map_dir_count, env_list, env_count, argv,
                                  argc, -1, -1, -1);
}

void
wasm_runtime_set_wasi_addr_pool(wasm_module_t module, const char *addr_pool[],
                                uint32 addr_pool_size)
{
    WASIArguments *wasi_args = get_wasi_args_from_module(module);

    if (wasi_args) {
        wasi_args->addr_pool = addr_pool;
        wasi_args->addr_count = addr_pool_size;
    }
}

void
wasm_runtime_set_wasi_ns_lookup_pool(wasm_module_t module,
                                     const char *ns_lookup_pool[],
                                     uint32 ns_lookup_pool_size)
{
    WASIArguments *wasi_args = get_wasi_args_from_module(module);

    if (wasi_args) {
        wasi_args->ns_lookup_pool = ns_lookup_pool;
        wasi_args->ns_lookup_count = ns_lookup_pool_size;
    }
}

#if WASM_ENABLE_UVWASI == 0
static bool
copy_string_array(const char *array[], uint32 array_size, char **buf_ptr,
                  char ***list_ptr, uint64 *out_buf_size)
{
    uint64 buf_size = 0, total_size;
    uint32 buf_offset = 0, i;
    char *buf = NULL, **list = NULL;

    for (i = 0; i < array_size; i++)
        buf_size += strlen(array[i]) + 1;

    /* We add +1 to generate null-terminated array of strings */
    total_size = sizeof(char *) * ((uint64)array_size + 1);
    if (total_size >= UINT32_MAX
        /* total_size must be larger than 0, don' check it again */
        || !(list = wasm_runtime_malloc((uint32)total_size))
        || buf_size >= UINT32_MAX
        || (buf_size > 0 && !(buf = wasm_runtime_malloc((uint32)buf_size)))) {

        if (buf)
            wasm_runtime_free(buf);
        if (list)
            wasm_runtime_free(list);
        return false;
    }

    for (i = 0; i < array_size; i++) {
        list[i] = buf + buf_offset;
        bh_strcpy_s(buf + buf_offset, (uint32)buf_size - buf_offset, array[i]);
        buf_offset += (uint32)(strlen(array[i]) + 1);
    }
    list[array_size] = NULL;

    *list_ptr = list;
    *buf_ptr = buf;
    if (out_buf_size)
        *out_buf_size = buf_size;

    return true;
}

bool
wasm_runtime_init_wasi(WASMModuleInstanceCommon *module_inst,
                       const char *dir_list[], uint32 dir_count,
                       const char *map_dir_list[], uint32 map_dir_count,
                       const char *env[], uint32 env_count,
                       const char *addr_pool[], uint32 addr_pool_size,
                       const char *ns_lookup_pool[], uint32 ns_lookup_pool_size,
                       char *argv[], uint32 argc, os_raw_file_handle stdinfd,
                       os_raw_file_handle stdoutfd, os_raw_file_handle stderrfd,
                       char *error_buf, uint32 error_buf_size)
{
    WASIContext *wasi_ctx;
    char *argv_buf = NULL;
    char **argv_list = NULL;
    char *env_buf = NULL;
    char **env_list = NULL;
    char *ns_lookup_buf = NULL;
    char **ns_lookup_list = NULL;
    uint64 argv_buf_size = 0, env_buf_size = 0;
    struct fd_table *curfds = NULL;
    struct fd_prestats *prestats = NULL;
    struct argv_environ_values *argv_environ = NULL;
    struct addr_pool *apool = NULL;
    bool fd_table_inited = false, fd_prestats_inited = false;
    bool argv_environ_inited = false;
    bool addr_pool_inited = false;
    __wasi_fd_t wasm_fd = 3;
    os_file_handle file_handle;
    char *path, resolved_path[PATH_MAX];
    uint32 i;

    if (!(wasi_ctx = runtime_malloc(sizeof(WASIContext), NULL, error_buf,
                                    error_buf_size))) {
        return false;
    }

    wasm_runtime_set_wasi_ctx(module_inst, wasi_ctx);

    /* process argv[0], trip the path and suffix, only keep the program name
     */
    if (!copy_string_array((const char **)argv, argc, &argv_buf, &argv_list,
                           &argv_buf_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    if (!copy_string_array(env, env_count, &env_buf, &env_list,
                           &env_buf_size)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    if (!(curfds = wasm_runtime_malloc(sizeof(struct fd_table)))
        || !(prestats = wasm_runtime_malloc(sizeof(struct fd_prestats)))
        || !(argv_environ =
                 wasm_runtime_malloc(sizeof(struct argv_environ_values)))
        || !(apool = wasm_runtime_malloc(sizeof(struct addr_pool)))) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    if (!fd_table_init(curfds)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      "init fd table failed");
        goto fail;
    }
    fd_table_inited = true;

    if (!fd_prestats_init(prestats)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      "init fd prestats failed");
        goto fail;
    }
    fd_prestats_inited = true;

    if (!argv_environ_init(argv_environ, argv_buf, argv_buf_size, argv_list,
                           argc, env_buf, env_buf_size, env_list, env_count)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      "init argument environment failed");
        goto fail;
    }
    argv_environ_inited = true;

    if (!addr_pool_init(apool)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: "
                      "init the address pool failed");
        goto fail;
    }
    addr_pool_inited = true;

    os_file_handle stdin_file_handle = os_convert_stdin_handle(stdinfd);
    os_file_handle stdout_file_handle = os_convert_stdout_handle(stdoutfd);
    os_file_handle stderr_file_handle = os_convert_stderr_handle(stderrfd);

    if (!os_is_handle_valid(&stdin_file_handle)
        || !os_is_handle_valid(&stdout_file_handle)
        || !os_is_handle_valid(&stderr_file_handle))
        goto fail;

    /* Prepopulate curfds with stdin, stdout, and stderr file descriptors. */
    if (!fd_table_insert_existing(curfds, 0, stdin_file_handle, true)
        || !fd_table_insert_existing(curfds, 1, stdout_file_handle, true)
        || !fd_table_insert_existing(curfds, 2, stderr_file_handle, true)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: init fd table failed");
        goto fail;
    }

    wasm_fd = 3;
    for (i = 0; i < dir_count; i++, wasm_fd++) {
        path = os_realpath(dir_list[i], resolved_path);
        if (!path) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening directory %s: %d\n",
                         dir_list[i], errno);
            goto fail;
        }

        __wasi_errno_t error = os_open_preopendir(path, &file_handle);

        if (error != __WASI_ESUCCESS) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening directory %s: %d\n",
                         dir_list[i], error);
            goto fail;
        }

        if (!fd_table_insert_existing(curfds, wasm_fd, file_handle, false)) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error inserting preopen fd %u (directory %s) into fd "
                         "table",
                         (unsigned int)wasm_fd, dir_list[i]);
            goto fail;
        }

        if (!fd_prestats_insert(prestats, dir_list[i], wasm_fd)) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error inserting preopen fd %u (directory %s) into "
                         "prestats table",
                         (unsigned int)wasm_fd, dir_list[i]);
            goto fail;
        }
    }

    for (i = 0; i < map_dir_count; i++, wasm_fd++) {
        char mapping_copy_buf[256];
        char *mapping_copy = mapping_copy_buf;
        char *map_mapped = NULL, *map_host = NULL;
        const unsigned long max_len =
            (unsigned long)strlen(map_dir_list[i]) * 2 + 3;

        /* Allocation limit for runtime environments with reduced stack size */
        if (max_len > 256) {
            if (!(mapping_copy = wasm_runtime_malloc(max_len))) {
                snprintf(error_buf, error_buf_size,
                         "error while allocating for directory mapping\n");
                goto fail;
            }
        }

        bh_memcpy_s(mapping_copy, max_len, map_dir_list[i],
                    (uint32)(strlen(map_dir_list[i]) + 1));

        const char *delim = "::";
        char *delim_pos = strstr(mapping_copy, delim);
        if (delim_pos) {
            *delim_pos = '\0';
            map_mapped = mapping_copy;
            map_host = delim_pos + strlen(delim);
        }

        if (!map_mapped || !map_host) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening mapped directory: "
                         "invalid map\n");
            if (mapping_copy != mapping_copy_buf)
                wasm_runtime_free(mapping_copy);
            goto fail;
        }

        path = os_realpath(map_host, resolved_path);
        if (!path) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening mapped directory %s: %d\n",
                         map_host, errno);
            if (mapping_copy != mapping_copy_buf)
                wasm_runtime_free(mapping_copy);
            goto fail;
        }

        __wasi_errno_t error = os_open_preopendir(path, &file_handle);
        if (error != __WASI_ESUCCESS) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening mapped directory %s: %d\n",
                         map_host, errno);
            if (mapping_copy != mapping_copy_buf)
                wasm_runtime_free(mapping_copy);
            goto fail;
        }

        if (!fd_table_insert_existing(curfds, wasm_fd, file_handle, false)
            || !fd_prestats_insert(prestats, map_mapped, wasm_fd)) {
            if (error_buf)
                snprintf(error_buf, error_buf_size,
                         "error while pre-opening mapped directory %s: "
                         "insertion failed\n",
                         dir_list[i]);
            if (mapping_copy != mapping_copy_buf)
                wasm_runtime_free(mapping_copy);
            goto fail;
        }

        if (mapping_copy != mapping_copy_buf)
            wasm_runtime_free(mapping_copy);
    }

    /* addr_pool(textual) -> apool */
    for (i = 0; i < addr_pool_size; i++) {
        char *cp, *address, *mask;
        bool ret = false;

        cp = bh_strdup(addr_pool[i]);
        if (!cp) {
            set_error_buf(error_buf, error_buf_size,
                          "Init wasi environment failed: copy address failed");
            goto fail;
        }

        address = strtok(cp, "/");
        mask = strtok(NULL, "/");

        if (!mask) {
            snprintf(error_buf, error_buf_size,
                     "Invalid address pool entry: %s, must be in the format of "
                     "ADDRESS/MASK",
                     addr_pool[i]);
            goto fail;
        }

        ret = addr_pool_insert(apool, address, (uint8)atoi(mask));
        wasm_runtime_free(cp);
        if (!ret) {
            set_error_buf(error_buf, error_buf_size,
                          "Init wasi environment failed: store address failed");
            goto fail;
        }
    }

    if (!copy_string_array(ns_lookup_pool, ns_lookup_pool_size, &ns_lookup_buf,
                           &ns_lookup_list, NULL)) {
        set_error_buf(error_buf, error_buf_size,
                      "Init wasi environment failed: allocate memory failed");
        goto fail;
    }

    wasi_ctx->curfds = curfds;
    wasi_ctx->prestats = prestats;
    wasi_ctx->argv_environ = argv_environ;
    wasi_ctx->addr_pool = apool;
    wasi_ctx->argv_buf = argv_buf;
    wasi_ctx->argv_list = argv_list;
    wasi_ctx->env_buf = env_buf;
    wasi_ctx->env_list = env_list;
    wasi_ctx->ns_lookup_buf = ns_lookup_buf;
    wasi_ctx->ns_lookup_list = ns_lookup_list;

    return true;

fail:
    if (argv_environ_inited)
        argv_environ_destroy(argv_environ);
    if (fd_prestats_inited)
        fd_prestats_destroy(prestats);
    if (fd_table_inited)
        fd_table_destroy(curfds);
    if (addr_pool_inited)
        addr_pool_destroy(apool);
    if (curfds)
        wasm_runtime_free(curfds);
    if (prestats)
        wasm_runtime_free(prestats);
    if (argv_environ)
        wasm_runtime_free(argv_environ);
    if (apool)
        wasm_runtime_free(apool);
    if (argv_buf)
        wasm_runtime_free(argv_buf);
    if (argv_list)
        wasm_runtime_free(argv_list);
    if (env_buf)
        wasm_runtime_free(env_buf);
    if (env_list)
        wasm_runtime_free(env_list);
    if (ns_lookup_buf)
        wasm_runtime_free(ns_lookup_buf);
    if (ns_lookup_list)
        wasm_runtime_free(ns_lookup_list);
    return false;
}
#else  /* else of WASM_ENABLE_UVWASI == 0 */
static void *
wasm_uvwasi_malloc(size_t size, void *mem_user_data)
{
    return runtime_malloc(size, NULL, NULL, 0);
    (void)mem_user_data;
}

static void
wasm_uvwasi_free(void *ptr, void *mem_user_data)
{
    if (ptr)
        wasm_runtime_free(ptr);
    (void)mem_user_data;
}

static void *
wasm_uvwasi_calloc(size_t nmemb, size_t size, void *mem_user_data)
{
    uint64 total_size = (uint64)nmemb * size;
    return runtime_malloc(total_size, NULL, NULL, 0);
    (void)mem_user_data;
}

static void *
wasm_uvwasi_realloc(void *ptr, size_t size, void *mem_user_data)
{
    if (size >= UINT32_MAX) {
        return NULL;
    }
    return wasm_runtime_realloc(ptr, (uint32)size);
}

/* clang-format off */
static uvwasi_mem_t uvwasi_allocator = {
    .mem_user_data = 0,
    .malloc = wasm_uvwasi_malloc,
    .free = wasm_uvwasi_free,
    .calloc = wasm_uvwasi_calloc,
    .realloc = wasm_uvwasi_realloc
};
/* clang-format on */

bool
wasm_runtime_init_wasi(WASMModuleInstanceCommon *module_inst,
                       const char *dir_list[], uint32 dir_count,
                       const char *map_dir_list[], uint32 map_dir_count,
                       const char *env[], uint32 env_count,
                       const char *addr_pool[], uint32 addr_pool_size,
                       const char *ns_lookup_pool[], uint32 ns_lookup_pool_size,
                       char *argv[], uint32 argc, os_raw_file_handle stdinfd,
                       os_raw_file_handle stdoutfd, os_raw_file_handle stderrfd,
                       char *error_buf, uint32 error_buf_size)
{
    WASIContext *ctx;
    uvwasi_t *uvwasi;
    uvwasi_options_t init_options;
    const char **envp = NULL;
    uint64 total_size;
    uint32 i;
    bool ret = false;

    ctx = runtime_malloc(sizeof(*ctx), module_inst, error_buf, error_buf_size);
    if (!ctx)
        return false;
    uvwasi = &ctx->uvwasi;

    /* Setup the initialization options */
    uvwasi_options_init(&init_options);
    init_options.allocator = &uvwasi_allocator;
    init_options.argc = argc;
    init_options.argv = (const char **)argv;
    init_options.in = (stdinfd != os_get_invalid_handle())
                          ? (uvwasi_fd_t)stdinfd
                          : init_options.in;
    init_options.out = (stdoutfd != os_get_invalid_handle())
                           ? (uvwasi_fd_t)stdoutfd
                           : init_options.out;
    init_options.err = (stderrfd != os_get_invalid_handle())
                           ? (uvwasi_fd_t)stderrfd
                           : init_options.err;

    if (dir_count > 0) {
        init_options.preopenc = dir_count;

        total_size = sizeof(uvwasi_preopen_t) * (uint64)init_options.preopenc;
        init_options.preopens = (uvwasi_preopen_t *)runtime_malloc(
            total_size, module_inst, error_buf, error_buf_size);
        if (init_options.preopens == NULL)
            goto fail;

        for (i = 0; i < init_options.preopenc; i++) {
            init_options.preopens[i].real_path = dir_list[i];
            init_options.preopens[i].mapped_path =
                (i < map_dir_count) ? map_dir_list[i] : dir_list[i];
        }
    }

    if (env_count > 0) {
        total_size = sizeof(char *) * (uint64)(env_count + 1);
        envp =
            runtime_malloc(total_size, module_inst, error_buf, error_buf_size);
        if (envp == NULL)
            goto fail;

        for (i = 0; i < env_count; i++) {
            envp[i] = env[i];
        }
        envp[env_count] = NULL;
        init_options.envp = envp;
    }

    if (UVWASI_ESUCCESS != uvwasi_init(uvwasi, &init_options)) {
        set_error_buf(error_buf, error_buf_size, "uvwasi init failed");
        goto fail;
    }

    wasm_runtime_set_wasi_ctx(module_inst, ctx);

    ret = true;

fail:
    if (envp)
        wasm_runtime_free((void *)envp);

    if (init_options.preopens)
        wasm_runtime_free(init_options.preopens);

    if (!ret && uvwasi)
        wasm_runtime_free(uvwasi);

    return ret;
}
#endif /* end of WASM_ENABLE_UVWASI */

bool
wasm_runtime_is_wasi_mode(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode
        && ((WASMModuleInstance *)module_inst)->module->import_wasi_api)
        return true;
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT
        && ((AOTModule *)((AOTModuleInstance *)module_inst)->module)
               ->import_wasi_api)
        return true;
#endif
    return false;
}

WASMFunctionInstanceCommon *
wasm_runtime_lookup_wasi_start_function(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModuleInstance *wasm_inst = (WASMModuleInstance *)module_inst;
        WASMFunctionInstance *func = wasm_lookup_function(wasm_inst, "_start");
        if (func) {
            if (func->u.func->func_type->param_count != 0
                || func->u.func->func_type->result_count != 0) {
                LOG_ERROR("Lookup wasi _start function failed: "
                          "invalid function type.\n");
                return NULL;
            }
            return (WASMFunctionInstanceCommon *)func;
        }
        return NULL;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *aot_inst = (AOTModuleInstance *)module_inst;
        AOTFunctionInstance *func = aot_lookup_function(aot_inst, "_start");
        if (func) {
            AOTFuncType *func_type = func->u.func.func_type;
            if (func_type->param_count != 0 || func_type->result_count != 0) {
                LOG_ERROR("Lookup wasi _start function failed: "
                          "invalid function type.\n");
                return NULL;
            }
            return func;
        }
        return NULL;
    }
#endif /* end of WASM_ENABLE_AOT */

    return NULL;
}

#if WASM_ENABLE_UVWASI == 0
void
wasm_runtime_destroy_wasi(WASMModuleInstanceCommon *module_inst)
{
    WASIContext *wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);

    if (wasi_ctx) {
        if (wasi_ctx->argv_environ) {
            argv_environ_destroy(wasi_ctx->argv_environ);
            wasm_runtime_free(wasi_ctx->argv_environ);
        }
        if (wasi_ctx->curfds) {
            fd_table_destroy(wasi_ctx->curfds);
            wasm_runtime_free(wasi_ctx->curfds);
        }
        if (wasi_ctx->prestats) {
            fd_prestats_destroy(wasi_ctx->prestats);
            wasm_runtime_free(wasi_ctx->prestats);
        }
        if (wasi_ctx->addr_pool) {
            addr_pool_destroy(wasi_ctx->addr_pool);
            wasm_runtime_free(wasi_ctx->addr_pool);
        }
        if (wasi_ctx->argv_buf)
            wasm_runtime_free(wasi_ctx->argv_buf);
        if (wasi_ctx->argv_list)
            wasm_runtime_free(wasi_ctx->argv_list);
        if (wasi_ctx->env_buf)
            wasm_runtime_free(wasi_ctx->env_buf);
        if (wasi_ctx->env_list)
            wasm_runtime_free(wasi_ctx->env_list);
        if (wasi_ctx->ns_lookup_buf)
            wasm_runtime_free(wasi_ctx->ns_lookup_buf);
        if (wasi_ctx->ns_lookup_list)
            wasm_runtime_free(wasi_ctx->ns_lookup_list);

        wasm_runtime_free(wasi_ctx);
    }
}
#else
void
wasm_runtime_destroy_wasi(WASMModuleInstanceCommon *module_inst)
{
    WASIContext *wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);

    if (wasi_ctx) {
        uvwasi_destroy(&wasi_ctx->uvwasi);
        wasm_runtime_free(wasi_ctx);
    }
}
#endif

uint32_t
wasm_runtime_get_wasi_exit_code(WASMModuleInstanceCommon *module_inst)
{
    WASIContext *wasi_ctx = wasm_runtime_get_wasi_ctx(module_inst);
#if WASM_ENABLE_THREAD_MGR != 0
    WASMCluster *cluster;
    WASMExecEnv *exec_env;

    exec_env = wasm_runtime_get_exec_env_singleton(module_inst);
    if (exec_env && (cluster = wasm_exec_env_get_cluster(exec_env))) {
        /**
         * The main thread may exit earlier than other threads, and
         * the exit_code of wasi_ctx may be changed by other thread
         * when it runs into wasi_proc_exit, here we wait until all
         * other threads exit to avoid getting invalid exit_code.
         */
        wasm_cluster_wait_for_all_except_self(cluster, exec_env);
    }
#endif
    return wasi_ctx->exit_code;
}
#endif /* end of WASM_ENABLE_LIBC_WASI */

WASMModuleCommon *
wasm_exec_env_get_module(WASMExecEnv *exec_env)
{
    WASMModuleInstanceCommon *module_inst_comm =
        wasm_runtime_get_module_inst(exec_env);
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);
    return (WASMModuleCommon *)module_inst->module;
}

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
const uint8 *
wasm_runtime_get_custom_section(WASMModuleCommon *const module_comm,
                                const char *name, uint32 *len)
{
#if WASM_ENABLE_INTERP != 0
    if (module_comm->module_type == Wasm_Module_Bytecode)
        return wasm_loader_get_custom_section((WASMModule *)module_comm, name,
                                              len);
#endif
#if WASM_ENABLE_AOT != 0
    if (module_comm->module_type == Wasm_Module_AoT)
        return aot_get_custom_section((AOTModule *)module_comm, name, len);
#endif
    return NULL;
}
#endif /* end of WASM_ENABLE_LOAD_CUSTOM_SECTION != 0 */

static union {
    int a;
    char b;
} __ue = { .a = 1 };

#define is_little_endian() (__ue.b == 1) /* NOLINT */

int32
wasm_runtime_get_import_count(WASMModuleCommon *const module)
{
    if (!module) {
        bh_assert(0);
        return -1;
    }

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        const AOTModule *aot_module = (const AOTModule *)module;
        return (int32)(aot_module->import_func_count
                       + aot_module->import_global_count
                       + aot_module->import_table_count
                       + aot_module->import_memory_count);
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        const WASMModule *wasm_module = (const WASMModule *)module;
        return (int32)wasm_module->import_count;
    }
#endif

    return -1;
}

void
wasm_runtime_get_import_type(WASMModuleCommon *const module, int32 import_index,
                             wasm_import_t *import_type)
{
    if (!import_type) {
        bh_assert(0);
        return;
    }

    memset(import_type, 0, sizeof(wasm_import_t));

    if (!module) {
        bh_assert(0);
        return;
    }

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        const AOTModule *aot_module = (const AOTModule *)module;

        uint32 func_index = (uint32)import_index;
        if (func_index < aot_module->import_func_count) {
            const AOTImportFunc *aot_import_func =
                &aot_module->import_funcs[func_index];
            import_type->module_name = aot_import_func->module_name;
            import_type->name = aot_import_func->func_name;
            import_type->kind = WASM_IMPORT_EXPORT_KIND_FUNC;
            import_type->linked =
                aot_import_func->func_ptr_linked ? true : false;
            import_type->u.func_type =
                (WASMFuncType *)aot_import_func->func_type;
            return;
        }

        uint32 global_index = func_index - aot_module->import_func_count;
        if (global_index < aot_module->import_global_count) {
            const AOTImportGlobal *aot_import_global =
                &aot_module->import_globals[global_index];
            import_type->module_name = aot_import_global->module_name;
            import_type->name = aot_import_global->global_name;
            import_type->kind = WASM_IMPORT_EXPORT_KIND_GLOBAL;
            import_type->linked = aot_import_global->is_linked;
            import_type->u.global_type =
                (WASMGlobalType *)&aot_import_global->type;
            return;
        }

        uint32 table_index = global_index - aot_module->import_global_count;
        if (table_index < aot_module->import_table_count) {
            const AOTImportTable *aot_import_table =
                &aot_module->import_tables[table_index];
            import_type->module_name = aot_import_table->module_name;
            import_type->name = aot_import_table->table_name;
            import_type->kind = WASM_IMPORT_EXPORT_KIND_TABLE;
            import_type->linked = false; /* not supported */
            import_type->u.table_type =
                (WASMTableType *)&aot_import_table->table_type;
            return;
        }

        uint32 memory_index = table_index - aot_module->import_table_count;
        if (memory_index < aot_module->import_memory_count) {
            const AOTImportMemory *aot_import_memory =
                &aot_module->import_memories[memory_index];
            import_type->module_name = aot_import_memory->module_name;
            import_type->name = aot_import_memory->memory_name;
            import_type->kind = WASM_IMPORT_EXPORT_KIND_MEMORY;
            import_type->linked = false; /* not supported */
            import_type->u.memory_type =
                (WASMMemoryType *)&aot_import_memory->mem_type;
            return;
        }

        bh_assert(0);
        return;
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        const WASMModule *wasm_module = (const WASMModule *)module;

        if ((uint32)import_index >= wasm_module->import_count) {
            bh_assert(0);
            return;
        }

        const WASMImport *wasm_import = &wasm_module->imports[import_index];

        import_type->module_name = wasm_import->u.names.module_name;
        import_type->name = wasm_import->u.names.field_name;
        import_type->kind = wasm_import->kind;
        switch (import_type->kind) {
            case WASM_IMPORT_EXPORT_KIND_FUNC:
                import_type->linked = wasm_import->u.function.func_ptr_linked;
                import_type->u.func_type =
                    (WASMFuncType *)wasm_import->u.function.func_type;
                break;
            case WASM_IMPORT_EXPORT_KIND_GLOBAL:
                import_type->linked = wasm_import->u.global.is_linked;
                import_type->u.global_type =
                    (WASMGlobalType *)&wasm_import->u.global.type;
                break;
            case WASM_IMPORT_EXPORT_KIND_TABLE:
                import_type->linked = false; /* not supported */
                import_type->u.table_type =
                    (WASMTableType *)&wasm_import->u.table.table_type;
                break;
            case WASM_IMPORT_EXPORT_KIND_MEMORY:
                import_type->linked = false; /* not supported */
                import_type->u.memory_type =
                    (WASMMemoryType *)&wasm_import->u.memory.mem_type;
                break;
            default:
                bh_assert(0);
                break;
        }

        return;
    }
#endif
}

int32
wasm_runtime_get_export_count(WASMModuleCommon *const module)
{
    if (!module) {
        bh_assert(0);
        return -1;
    }

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        const AOTModule *aot_module = (const AOTModule *)module;
        return (int32)aot_module->export_count;
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        const WASMModule *wasm_module = (const WASMModule *)module;
        return (int32)wasm_module->export_count;
    }
#endif

    return -1;
}

void
wasm_runtime_get_export_type(WASMModuleCommon *const module, int32 export_index,
                             wasm_export_t *export_type)
{
    if (!export_type) {
        bh_assert(0);
        return;
    }

    memset(export_type, 0, sizeof(wasm_export_t));

    if (!module) {
        bh_assert(0);
        return;
    }

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        const AOTModule *aot_module = (const AOTModule *)module;

        if ((uint32)export_index >= aot_module->export_count) {
            bh_assert(0);
            return;
        }

        const AOTExport *aot_export = &aot_module->exports[export_index];
        export_type->name = aot_export->name;
        export_type->kind = aot_export->kind;
        switch (export_type->kind) {
            case WASM_IMPORT_EXPORT_KIND_FUNC:
            {
                if (aot_export->index < aot_module->import_func_count) {
                    export_type->u.func_type =
                        (AOTFuncType *)aot_module
                            ->import_funcs[aot_export->index]
                            .func_type;
                }
                else {
                    export_type->u.func_type =
                        (AOTFuncType *)aot_module
                            ->types[aot_module->func_type_indexes
                                        [aot_export->index
                                         - aot_module->import_func_count]];
                }
                break;
            }
            case WASM_IMPORT_EXPORT_KIND_GLOBAL:
            {
                if (aot_export->index < aot_module->import_global_count) {
                    export_type->u.global_type =
                        &aot_module->import_globals[aot_export->index].type;
                }
                else {
                    export_type->u.global_type =
                        &aot_module
                             ->globals[aot_export->index
                                       - aot_module->import_global_count]
                             .type;
                }
                break;
            }
            case WASM_IMPORT_EXPORT_KIND_TABLE:
            {
                if (aot_export->index < aot_module->import_table_count) {
                    export_type->u.table_type =
                        &aot_module->import_tables[aot_export->index]
                             .table_type;
                }
                else {
                    export_type->u.table_type =
                        &aot_module
                             ->tables[aot_export->index
                                      - aot_module->import_table_count]
                             .table_type;
                }
                break;
            }
            case WASM_IMPORT_EXPORT_KIND_MEMORY:
            {
                if (aot_export->index < aot_module->import_memory_count) {
                    export_type->u.memory_type =
                        &aot_module->import_memories[aot_export->index]
                             .mem_type;
                }
                else {
                    export_type->u.memory_type =
                        &aot_module
                             ->memories[aot_export->index
                                        - aot_module->import_memory_count];
                }
                break;
            }
            default:
                bh_assert(0);
                break;
        }
        return;
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        const WASMModule *wasm_module = (const WASMModule *)module;

        if ((uint32)export_index >= wasm_module->export_count) {
            bh_assert(0);
            return;
        }

        const WASMExport *wasm_export = &wasm_module->exports[export_index];
        export_type->name = wasm_export->name;
        export_type->kind = wasm_export->kind;
        switch (export_type->kind) {
            case WASM_IMPORT_EXPORT_KIND_FUNC:
            {
                if (wasm_export->index < wasm_module->import_function_count) {
                    export_type->u.func_type =
                        (WASMFuncType *)wasm_module
                            ->import_functions[wasm_export->index]
                            .u.function.func_type;
                }
                else {
                    export_type->u.func_type =
                        wasm_module
                            ->functions[wasm_export->index
                                        - wasm_module->import_function_count]
                            ->func_type;
                }

                break;
            }
            case WASM_IMPORT_EXPORT_KIND_GLOBAL:
            {
                if (wasm_export->index < wasm_module->import_global_count) {
                    export_type->u.global_type =
                        (WASMGlobalType *)&wasm_module
                            ->import_globals[wasm_export->index]
                            .u.global.type;
                }
                else {
                    export_type->u.global_type =
                        &wasm_module
                             ->globals[wasm_export->index
                                       - wasm_module->import_global_count]
                             .type;
                }

                break;
            }
            case WASM_IMPORT_EXPORT_KIND_TABLE:
            {
                if (wasm_export->index < wasm_module->import_table_count) {
                    export_type->u.table_type =
                        (WASMTableType *)&wasm_module
                            ->import_tables[wasm_export->index]
                            .u.table.table_type;
                }
                else {
                    export_type->u.table_type =
                        &wasm_module
                             ->tables[wasm_export->index
                                      - wasm_module->import_table_count]
                             .table_type;
                }

                break;
            }
            case WASM_IMPORT_EXPORT_KIND_MEMORY:
            {
                if (wasm_export->index < wasm_module->import_memory_count) {
                    export_type->u.memory_type =
                        (WASMMemoryType *)&wasm_module
                            ->import_memories[wasm_export->index]
                            .u.memory.mem_type;
                }
                else {
                    export_type->u.memory_type =
                        &wasm_module
                             ->memories[wasm_export->index
                                        - wasm_module->import_memory_count];
                }

                break;
            }
            default:
                bh_assert(0);
                break;
        }
        return;
    }
#endif
}

uint32
wasm_func_type_get_param_count(WASMFuncType *const func_type)
{
    bh_assert(func_type);

    return func_type->param_count;
}

wasm_valkind_t
wasm_func_type_get_param_valkind(WASMFuncType *const func_type,
                                 uint32 param_index)
{
    if (!func_type || (param_index >= func_type->param_count)) {
        bh_assert(0);
        return (wasm_valkind_t)-1;
    }

    switch (func_type->types[param_index]) {
        case VALUE_TYPE_I32:
            return WASM_I32;
        case VALUE_TYPE_I64:
            return WASM_I64;
        case VALUE_TYPE_F32:
            return WASM_F32;
        case VALUE_TYPE_F64:
            return WASM_F64;
        case VALUE_TYPE_V128:
            return WASM_V128;
        case VALUE_TYPE_FUNCREF:
            return WASM_FUNCREF;
        case VALUE_TYPE_EXTERNREF:
            return WASM_EXTERNREF;

        case VALUE_TYPE_VOID:
        default:
        {
            bh_assert(0);
            return (wasm_valkind_t)-1;
        }
    }
}

uint32
wasm_func_type_get_result_count(WASMFuncType *const func_type)
{
    bh_assert(func_type);

    return func_type->result_count;
}

wasm_valkind_t
wasm_func_type_get_result_valkind(WASMFuncType *const func_type,
                                  uint32 result_index)
{
    if (!func_type || (result_index >= func_type->result_count)) {
        bh_assert(0);
        return (wasm_valkind_t)-1;
    }

    switch (func_type->types[func_type->param_count + result_index]) {
        case VALUE_TYPE_I32:
            return WASM_I32;
        case VALUE_TYPE_I64:
            return WASM_I64;
        case VALUE_TYPE_F32:
            return WASM_F32;
        case VALUE_TYPE_F64:
            return WASM_F64;
        case VALUE_TYPE_FUNCREF:
            return WASM_FUNCREF;

#if WASM_ENABLE_SIMD != 0
        case VALUE_TYPE_V128:
            return WASM_V128;
#endif
#if WASM_ENABLE_REF_TYPES != 0
        case VALUE_TYPE_EXTERNREF:
#endif
        case VALUE_TYPE_VOID:
        default:
        {
            bh_assert(0);
            return (wasm_valkind_t)-1;
        }
    }
}

wasm_valkind_t
wasm_global_type_get_valkind(WASMGlobalType *const global_type)
{
    bh_assert(global_type);

    return val_type_to_val_kind(global_type->val_type);
}

bool
wasm_global_type_get_mutable(WASMGlobalType *const global_type)
{
    bh_assert(global_type);

    return global_type->is_mutable;
}

bool
wasm_memory_type_get_shared(WASMMemoryType *const memory_type)
{
    bh_assert(memory_type);

    return (memory_type->flags & SHARED_MEMORY_FLAG) ? true : false;
}

uint32
wasm_memory_type_get_init_page_count(WASMMemoryType *const memory_type)
{
    bh_assert(memory_type);

    return memory_type->init_page_count;
}

uint32
wasm_memory_type_get_max_page_count(WASMMemoryType *const memory_type)
{
    bh_assert(memory_type);

    return memory_type->max_page_count;
}

wasm_valkind_t
wasm_table_type_get_elem_kind(WASMTableType *const table_type)
{
    bh_assert(table_type);

    return val_type_to_val_kind(table_type->elem_type);
}

bool
wasm_table_type_get_shared(WASMTableType *const table_type)
{
    bh_assert(table_type);

    return (table_type->flags & 2) ? true : false;
}

uint32
wasm_table_type_get_init_size(WASMTableType *const table_type)
{
    bh_assert(table_type);

    return table_type->init_size;
}

uint32
wasm_table_type_get_max_size(WASMTableType *const table_type)
{
    bh_assert(table_type);

    return table_type->max_size;
}

bool
wasm_runtime_register_natives(const char *module_name,
                              NativeSymbol *native_symbols,
                              uint32 n_native_symbols)
{
    return wasm_native_register_natives(module_name, native_symbols,
                                        n_native_symbols);
}

bool
wasm_runtime_register_natives_raw(const char *module_name,
                                  NativeSymbol *native_symbols,
                                  uint32 n_native_symbols)
{
    return wasm_native_register_natives_raw(module_name, native_symbols,
                                            n_native_symbols);
}

bool
wasm_runtime_unregister_natives(const char *module_name,
                                NativeSymbol *native_symbols)
{
    return wasm_native_unregister_natives(module_name, native_symbols);
}

bool
wasm_runtime_invoke_native_raw(WASMExecEnv *exec_env, void *func_ptr,
                               const WASMFuncType *func_type,
                               const char *signature, void *attachment,
                               uint32 *argv, uint32 argc, uint32 *argv_ret)
{
    WASMModuleInstanceCommon *module = wasm_runtime_get_module_inst(exec_env);
#if WASM_ENABLE_MEMORY64 != 0
    WASMMemoryInstance *memory =
        wasm_get_default_memory((WASMModuleInstance *)module);
    bool is_memory64 = memory ? memory->is_memory64 : false;
#endif
    typedef void (*NativeRawFuncPtr)(WASMExecEnv *, uint64 *);
    NativeRawFuncPtr invoke_native_raw = (NativeRawFuncPtr)func_ptr;
    uint64 argv_buf[16] = { 0 }, *argv1 = argv_buf, *argv_dst, size;
    uint32 *argv_src = argv, i, argc1, ptr_len;
    uint32 arg_i32;
    bool ret = false;

    argc1 = func_type->param_count;
    if (argc1 > sizeof(argv_buf) / sizeof(uint64)) {
        size = sizeof(uint64) * (uint64)argc1;
        if (!(argv1 = runtime_malloc((uint32)size, exec_env->module_inst, NULL,
                                     0))) {
            return false;
        }
    }

    argv_dst = argv1;

    /* Traverse secondly to fill in each argument */
    for (i = 0; i < func_type->param_count; i++, argv_dst++) {
        switch (func_type->types[i]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
            {
                *(uint32 *)argv_dst = arg_i32 = *argv_src++;
                if (signature
#if WASM_ENABLE_MEMORY64 != 0
                    && !is_memory64
#endif
                ) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(
                                module, (uint64)arg_i32, (uint64)ptr_len))
                            goto fail;

                        *(uintptr_t *)argv_dst =
                            (uintptr_t)wasm_runtime_addr_app_to_native(
                                module, (uint64)arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(
                                module, (uint64)arg_i32))
                            goto fail;

                        *(uintptr_t *)argv_dst =
                            (uintptr_t)wasm_runtime_addr_app_to_native(
                                module, (uint64)arg_i32);
                    }
                }
                break;
            }
            case VALUE_TYPE_I64:
#if WASM_ENABLE_MEMORY64 != 0
            {
                uint64 arg_i64;

                PUT_I64_TO_ADDR((uint32 *)argv_dst,
                                GET_I64_FROM_ADDR(argv_src));
                argv_src += 2;
                arg_i64 = *argv_dst;
                if (signature && is_memory64) {
                    /* TODO: memory64 pointer with length need a new symbol
                     * to represent type i64, with '~' still represent i32
                     * length */
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(module, arg_i64,
                                                            (uint64)ptr_len))
                            goto fail;

                        *argv_dst = (uint64)wasm_runtime_addr_app_to_native(
                            module, arg_i64);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(module,
                                                                arg_i64))
                            goto fail;

                        *argv_dst = (uint64)wasm_runtime_addr_app_to_native(
                            module, arg_i64);
                    }
                }
                break;
            }
#endif
            case VALUE_TYPE_F64:
                bh_memcpy_s(argv_dst, sizeof(uint64), argv_src,
                            sizeof(uint32) * 2);
                argv_src += 2;
                break;
            case VALUE_TYPE_F32:
                *(float32 *)argv_dst = *(float32 *)argv_src++;
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                uint32 externref_idx = *argv_src++;

                void *externref_obj;

                if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                    goto fail;

                bh_memcpy_s(argv_dst, sizeof(uintptr_t), argv_src,
                            sizeof(uintptr_t));
                break;
            }
#endif
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
            {
                bh_memcpy_s(argv_dst, sizeof(uintptr_t), argv_src,
                            sizeof(uintptr_t));
                argv_src += sizeof(uintptr_t) / sizeof(uint32);
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }

    exec_env->attachment = attachment;
    invoke_native_raw(exec_env, argv1);
    exec_env->attachment = NULL;

    if (func_type->result_count > 0) {
        switch (func_type->types[func_type->param_count]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
                argv_ret[0] = *(uint32 *)argv1;
                break;
            case VALUE_TYPE_F32:
                *(float32 *)argv_ret = *(float32 *)argv1;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                bh_memcpy_s(argv_ret, sizeof(uint32) * 2, argv1,
                            sizeof(uint64));
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                uint32 externref_idx;
                uint64 externref_obj;

                bh_memcpy_s(&externref_obj, sizeof(uint64), argv1,
                            sizeof(uint64));

                if (!wasm_externref_obj2ref(exec_env->module_inst,
                                            (void *)(uintptr_t)externref_obj,
                                            &externref_idx))
                    goto fail;
                argv_ret[0] = externref_idx;
                break;
            }
#endif
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
            {
                bh_memcpy_s(argv_ret, sizeof(uintptr_t), argv1,
                            sizeof(uintptr_t));
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }

    ret = !wasm_runtime_copy_exception(module, NULL);

fail:
    if (argv1 != argv_buf)
        wasm_runtime_free(argv1);
    return ret;
}

/**
 * Implementation of wasm_runtime_invoke_native()
 */

/**
 * The invoke native implementation on ARM platform with VFP co-processor,
 * RISCV32 platform with/without FPU/DPFPU and ARC platform.
 */
#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP) \
    || defined(BUILD_TARGET_RISCV32_ILP32D)                          \
    || defined(BUILD_TARGET_RISCV32_ILP32F)                          \
    || defined(BUILD_TARGET_RISCV32_ILP32) || defined(BUILD_TARGET_ARC)
typedef void (*GenericFunctionPointer)(void);
void
invokeNative(GenericFunctionPointer f, uint32 *args, uint32 n_stacks);

typedef float64 (*Float64FuncPtr)(GenericFunctionPointer, uint32 *, uint32);
typedef float32 (*Float32FuncPtr)(GenericFunctionPointer, uint32 *, uint32);
typedef int64 (*Int64FuncPtr)(GenericFunctionPointer, uint32 *, uint32);
typedef int32 (*Int32FuncPtr)(GenericFunctionPointer, uint32 *, uint32);
typedef void (*VoidFuncPtr)(GenericFunctionPointer, uint32 *, uint32);

static volatile Float64FuncPtr invokeNative_Float64 =
    (Float64FuncPtr)(uintptr_t)invokeNative;
static volatile Float32FuncPtr invokeNative_Float32 =
    (Float32FuncPtr)(uintptr_t)invokeNative;
static volatile Int64FuncPtr invokeNative_Int64 =
    (Int64FuncPtr)(uintptr_t)invokeNative;
static volatile Int32FuncPtr invokeNative_Int32 =
    (Int32FuncPtr)(uintptr_t)invokeNative;
static volatile VoidFuncPtr invokeNative_Void =
    (VoidFuncPtr)(uintptr_t)invokeNative;

#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP)
#define MAX_REG_INTS 4
#define MAX_REG_FLOATS 16
#else
#define MAX_REG_INTS 8
#define MAX_REG_FLOATS 8
#endif

bool
wasm_runtime_invoke_native(WASMExecEnv *exec_env, void *func_ptr,
                           const WASMFuncType *func_type, const char *signature,
                           void *attachment, uint32 *argv, uint32 argc,
                           uint32 *argv_ret)
{
    WASMModuleInstanceCommon *module = wasm_runtime_get_module_inst(exec_env);
    /* argv buf layout: int args(fix cnt) + float args(fix cnt) + stack args
     */
    uint32 argv_buf[32], *argv1 = argv_buf, *ints, *stacks, size;
    uint32 *argv_src = argv, i, argc1, n_ints = 0, n_stacks = 0;
    uint32 arg_i32, ptr_len;
    uint32 result_count = func_type->result_count;
    uint32 ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    bool ret = false;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    bool is_aot_func = (NULL == signature);
#endif
#if !defined(BUILD_TARGET_RISCV32_ILP32) && !defined(BUILD_TARGET_ARC)
    uint32 *fps;
    int n_fps = 0;
#else
#define fps ints
#define n_fps n_ints
#endif

    n_ints++; /* exec env */

    /* Traverse firstly to calculate stack args count */
    for (i = 0; i < func_type->param_count; i++) {
        switch (func_type->types[i]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
#endif
                if (n_ints < MAX_REG_INTS)
                    n_ints++;
                else
                    n_stacks++;
                break;
            case VALUE_TYPE_I64:
                if (n_ints < MAX_REG_INTS - 1) {
#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP)
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_ints & 1)
                        n_ints++;
#endif
                    n_ints += 2;
                }
#if defined(BUILD_TARGET_RISCV32_ILP32)     \
    || defined(BUILD_TARGET_RISCV32_ILP32F) \
    || defined(BUILD_TARGET_RISCV32_ILP32D) || defined(BUILD_TARGET_ARC)
                /* part in register, part in stack */
                else if (n_ints == MAX_REG_INTS - 1) {
                    n_ints++;
                    n_stacks++;
                }
#endif
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
#if !defined(BUILD_TARGET_ARC)
                    if (n_stacks & 1)
                        n_stacks++;
#endif
                    n_stacks += 2;
                }
                break;
#if !defined(BUILD_TARGET_RISCV32_ILP32D)
            case VALUE_TYPE_F32:
                if (n_fps < MAX_REG_FLOATS)
                    n_fps++;
#if defined(BUILD_TARGET_RISCV32_ILP32F)
                else if (n_ints < MAX_REG_INTS) {
                    n_ints++;
                }
#endif
                else
                    n_stacks++;
                break;
            case VALUE_TYPE_F64:
#if defined(BUILD_TARGET_RISCV32_ILP32) \
    || defined(BUILD_TARGET_RISCV32_ILP32F) || defined(BUILD_TARGET_ARC)
                if (n_ints < MAX_REG_INTS - 1) {
                    n_ints += 2;
                }
                else if (n_ints == MAX_REG_INTS - 1) {
                    n_ints++;
                    n_stacks++;
                }
#endif
#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP)
                if (n_fps < MAX_REG_FLOATS - 1) {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_fps & 1)
                        n_fps++;
                    n_fps += 2;
                }
                else if (n_fps == MAX_REG_FLOATS - 1) {
                    n_fps++;
                    n_stacks++;
                }
#endif
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
#if !defined(BUILD_TARGET_ARC)
                    if (n_stacks & 1)
                        n_stacks++;
#endif
                    n_stacks += 2;
                }
                break;
#else  /* BUILD_TARGET_RISCV32_ILP32D */
            case VALUE_TYPE_F32:
            case VALUE_TYPE_F64:
                if (n_fps < MAX_REG_FLOATS) {
                    n_fps++;
                }
                else if (func_type->types[i] == VALUE_TYPE_F32
                         && n_ints < MAX_REG_INTS) {
                    /* use int reg firstly if available */
                    n_ints++;
                }
                else if (func_type->types[i] == VALUE_TYPE_F64
                         && n_ints < MAX_REG_INTS - 1) {
                    /* use int regs firstly if available */
                    if (n_ints & 1)
                        n_ints++;
                    n_ints += 2;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned in riscv32
                     */
                    if (n_stacks & 1)
                        n_stacks++;
                    n_stacks += 2;
                }
                break;
#endif /* BUILD_TARGET_RISCV32_ILP32D */
            default:
                bh_assert(0);
                break;
        }
    }

    for (i = 0; i < ext_ret_count; i++) {
        if (n_ints < MAX_REG_INTS)
            n_ints++;
        else
            n_stacks++;
    }

#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP) \
    || defined(BUILD_TARGET_RISCV32_ILP32F)
    argc1 = MAX_REG_INTS + MAX_REG_FLOATS + n_stacks;
#elif defined(BUILD_TARGET_RISCV32_ILP32) || defined(BUILD_TARGET_ARC)
    argc1 = MAX_REG_INTS + n_stacks;
#else /* for BUILD_TARGET_RISCV32_ILP32D */
    argc1 = MAX_REG_INTS + MAX_REG_FLOATS * 2 + n_stacks;
#endif

    if (argc1 > sizeof(argv_buf) / sizeof(uint32)) {
        size = sizeof(uint32) * (uint32)argc1;
        if (!(argv1 = runtime_malloc((uint32)size, exec_env->module_inst, NULL,
                                     0))) {
            return false;
        }
    }

    ints = argv1;
#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP) \
    || defined(BUILD_TARGET_RISCV32_ILP32F)
    fps = ints + MAX_REG_INTS;
    stacks = fps + MAX_REG_FLOATS;
#elif defined(BUILD_TARGET_RISCV32_ILP32) || defined(BUILD_TARGET_ARC)
    stacks = ints + MAX_REG_INTS;
#else /* for BUILD_TARGET_RISCV32_ILP32D */
    fps = ints + MAX_REG_INTS;
    stacks = fps + MAX_REG_FLOATS * 2;
#endif

    n_ints = 0;
    n_fps = 0;
    n_stacks = 0;
    ints[n_ints++] = (uint32)(uintptr_t)exec_env;

    /* Traverse secondly to fill in each argument */
    for (i = 0; i < func_type->param_count; i++) {
        switch (func_type->types[i]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
            {
                arg_i32 = *argv_src++;

                if (signature) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(
                                module, (uint64)arg_i32, (uint64)ptr_len))
                            goto fail;

                        arg_i32 = (uintptr_t)wasm_runtime_addr_app_to_native(
                            module, (uint64)arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(
                                module, (uint64)arg_i32))
                            goto fail;

                        arg_i32 = (uintptr_t)wasm_runtime_addr_app_to_native(
                            module, (uint64)arg_i32);
                    }
                }

                if (n_ints < MAX_REG_INTS)
                    ints[n_ints++] = arg_i32;
                else
                    stacks[n_stacks++] = arg_i32;
                break;
            }
            case VALUE_TYPE_I64:
            {
                if (n_ints < MAX_REG_INTS - 1) {
#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP)
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_ints & 1)
                        n_ints++;
#endif
                    ints[n_ints++] = *argv_src++;
                    ints[n_ints++] = *argv_src++;
                }
#if defined(BUILD_TARGET_RISCV32_ILP32)     \
    || defined(BUILD_TARGET_RISCV32_ILP32F) \
    || defined(BUILD_TARGET_RISCV32_ILP32D) || defined(BUILD_TARGET_ARC)
                else if (n_ints == MAX_REG_INTS - 1) {
                    ints[n_ints++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
#endif
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
#if !defined(BUILD_TARGET_ARC)
                    if (n_stacks & 1)
                        n_stacks++;
#endif
                    stacks[n_stacks++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
                break;
            }
#if !defined(BUILD_TARGET_RISCV32_ILP32D)
            case VALUE_TYPE_F32:
            {
                if (n_fps < MAX_REG_FLOATS)
                    *(float32 *)&fps[n_fps++] = *(float32 *)argv_src++;
#if defined(BUILD_TARGET_RISCV32_ILP32F)
                else if (n_ints < MAX_REG_INTS) {
                    ints[n_ints++] = *argv_src++;
                }
#endif
                else
                    *(float32 *)&stacks[n_stacks++] = *(float32 *)argv_src++;
                break;
            }
            case VALUE_TYPE_F64:
            {
#if defined(BUILD_TARGET_RISCV32_ILP32) \
    || defined(BUILD_TARGET_RISCV32_ILP32F) || defined(BUILD_TARGET_ARC)
                if (n_ints < MAX_REG_INTS - 1) {
                    ints[n_ints++] = *argv_src++;
                    ints[n_ints++] = *argv_src++;
                }
                else if (n_ints == MAX_REG_INTS - 1) {
                    ints[n_ints++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
#endif
#if defined(BUILD_TARGET_ARM_VFP) || defined(BUILD_TARGET_THUMB_VFP)
                if (n_fps < MAX_REG_FLOATS - 1) {
                    /* 64-bit data must be 8 bytes aligned in arm */
                    if (n_fps & 1)
                        n_fps++;
                    fps[n_fps++] = *argv_src++;
                    fps[n_fps++] = *argv_src++;
                }
                else if (n_fps == MAX_REG_FLOATS - 1) {
                    fps[n_fps++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
#endif
                else {
                    /* 64-bit data in stack must be 8 bytes aligned
                       in arm and riscv32 */
#if !defined(BUILD_TARGET_ARC)
                    if (n_stacks & 1)
                        n_stacks++;
#endif
                    stacks[n_stacks++] = *argv_src++;
                    stacks[n_stacks++] = *argv_src++;
                }
                break;
            }
#else  /* BUILD_TARGET_RISCV32_ILP32D */
            case VALUE_TYPE_F32:
            case VALUE_TYPE_F64:
            {
                if (n_fps < MAX_REG_FLOATS) {
                    if (func_type->types[i] == VALUE_TYPE_F32) {
                        *(float32 *)&fps[n_fps * 2] = *(float32 *)argv_src++;
                        /* NaN boxing, the upper bits of a valid NaN-boxed
                          value must be all 1s. */
                        fps[n_fps * 2 + 1] = 0xFFFFFFFF;
                    }
                    else {
                        *(float64 *)&fps[n_fps * 2] = *(float64 *)argv_src;
                        argv_src += 2;
                    }
                    n_fps++;
                }
                else if (func_type->types[i] == VALUE_TYPE_F32
                         && n_ints < MAX_REG_INTS) {
                    /* use int reg firstly if available */
                    *(float32 *)&ints[n_ints++] = *(float32 *)argv_src++;
                }
                else if (func_type->types[i] == VALUE_TYPE_F64
                         && n_ints < MAX_REG_INTS - 1) {
                    /* use int regs firstly if available */
                    if (n_ints & 1)
                        n_ints++;
                    *(float64 *)&ints[n_ints] = *(float64 *)argv_src;
                    n_ints += 2;
                    argv_src += 2;
                }
                else {
                    /* 64-bit data in stack must be 8 bytes aligned in riscv32
                     */
                    if (n_stacks & 1)
                        n_stacks++;
                    if (func_type->types[i] == VALUE_TYPE_F32) {
                        *(float32 *)&stacks[n_stacks++] =
                            *(float32 *)argv_src++;
                    }
                    else {
                        *(float64 *)&stacks[n_stacks] = *(float64 *)argv_src;
                        argv_src += 2;
                        n_stacks += 2;
                    }
                }
                break;
            }
#endif /* BUILD_TARGET_RISCV32_ILP32D */
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                uint32 externref_idx = *argv_src++;

                if (is_aot_func) {
                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = externref_idx;
                    else
                        stacks[n_stacks++] = externref_idx;
                }
                else {
                    void *externref_obj;

                    if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                        goto fail;

                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = (uintptr_t)externref_obj;
                    else
                        stacks[n_stacks++] = (uintptr_t)externref_obj;
                }
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }

    /* Save extra result values' address to argv1 */
    for (i = 0; i < ext_ret_count; i++) {
        if (n_ints < MAX_REG_INTS)
            ints[n_ints++] = *(uint32 *)argv_src++;
        else
            stacks[n_stacks++] = *(uint32 *)argv_src++;
    }

    exec_env->attachment = attachment;
    if (func_type->result_count == 0) {
        invokeNative_Void(func_ptr, argv1, n_stacks);
    }
    else {
        switch (func_type->types[func_type->param_count]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
                argv_ret[0] =
                    (uint32)invokeNative_Int32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_I64:
                PUT_I64_TO_ADDR(argv_ret,
                                invokeNative_Int64(func_ptr, argv1, n_stacks));
                break;
            case VALUE_TYPE_F32:
                *(float32 *)argv_ret =
                    invokeNative_Float32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_F64:
                PUT_F64_TO_ADDR(
                    argv_ret, invokeNative_Float64(func_ptr, argv1, n_stacks));
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                if (is_aot_func) {
                    uint32 externref_idx =
                        (uint32)invokeNative_Int32(func_ptr, argv1, argc1);
                    argv_ret[0] = externref_idx;
                }
                else {
                    uint32 externref_idx;
                    void *externref_obj;

                    externref_obj = (void *)(uintptr_t)invokeNative_Int32(
                        func_ptr, argv1, argc1);

                    if (!wasm_externref_obj2ref(exec_env->module_inst,
                                                externref_obj, &externref_idx))
                        goto fail;

                    argv_ret[0] = externref_idx;
                }
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }
    exec_env->attachment = NULL;

    ret = !wasm_runtime_copy_exception(module, NULL);

fail:
    if (argv1 != argv_buf)
        wasm_runtime_free(argv1);
    return ret;
}
#endif /* end of defined(BUILD_TARGET_ARM_VFP)    \
          || defined(BUILD_TARGET_THUMB_VFP)      \
          || defined(BUILD_TARGET_RISCV32_ILP32D) \
          || defined(BUILD_TARGET_RISCV32_ILP32F) \
          || defined(BUILD_TARGET_RISCV32_ILP32)  \
          || defined(BUILD_TARGET_ARC) */

#if defined(BUILD_TARGET_X86_32) || defined(BUILD_TARGET_ARM)    \
    || defined(BUILD_TARGET_THUMB) || defined(BUILD_TARGET_MIPS) \
    || defined(BUILD_TARGET_XTENSA)
typedef void (*GenericFunctionPointer)(void);
void
invokeNative(GenericFunctionPointer f, uint32 *args, uint32 sz);

typedef float64 (*Float64FuncPtr)(GenericFunctionPointer f, uint32 *, uint32);
typedef float32 (*Float32FuncPtr)(GenericFunctionPointer f, uint32 *, uint32);
typedef int64 (*Int64FuncPtr)(GenericFunctionPointer f, uint32 *, uint32);
typedef int32 (*Int32FuncPtr)(GenericFunctionPointer f, uint32 *, uint32);
typedef void (*VoidFuncPtr)(GenericFunctionPointer f, uint32 *, uint32);

static volatile Int64FuncPtr invokeNative_Int64 =
    (Int64FuncPtr)(uintptr_t)invokeNative;
static volatile Int32FuncPtr invokeNative_Int32 =
    (Int32FuncPtr)(uintptr_t)invokeNative;
static volatile Float64FuncPtr invokeNative_Float64 =
    (Float64FuncPtr)(uintptr_t)invokeNative;
static volatile Float32FuncPtr invokeNative_Float32 =
    (Float32FuncPtr)(uintptr_t)invokeNative;
static volatile VoidFuncPtr invokeNative_Void =
    (VoidFuncPtr)(uintptr_t)invokeNative;

static inline void
word_copy(uint32 *dest, uint32 *src, unsigned num)
{
    for (; num > 0; num--)
        *dest++ = *src++;
}

bool
wasm_runtime_invoke_native(WASMExecEnv *exec_env, void *func_ptr,
                           const WASMFuncType *func_type, const char *signature,
                           void *attachment, uint32 *argv, uint32 argc,
                           uint32 *argv_ret)
{
    WASMModuleInstanceCommon *module = wasm_runtime_get_module_inst(exec_env);
    uint32 argv_buf[32], *argv1 = argv_buf, argc1, i, j = 0;
    uint32 arg_i32, ptr_len;
    uint32 result_count = func_type->result_count;
    uint32 ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    uint64 size;
    bool ret = false;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    bool is_aot_func = (NULL == signature);
#endif

#if defined(BUILD_TARGET_X86_32)
    argc1 = argc + ext_ret_count + 2;
#else
    /* arm/thumb/mips/xtensa, 64-bit data must be 8 bytes aligned,
       so we need to allocate more memory. */
    argc1 = func_type->param_count * 2 + ext_ret_count + 2;
#endif

    if (argc1 > sizeof(argv_buf) / sizeof(uint32)) {
        size = sizeof(uint32) * (uint64)argc1;
        if (!(argv1 = runtime_malloc((uint32)size, exec_env->module_inst, NULL,
                                     0))) {
            return false;
        }
    }

    for (i = 0; i < sizeof(WASMExecEnv *) / sizeof(uint32); i++)
        argv1[j++] = ((uint32 *)&exec_env)[i];

    for (i = 0; i < func_type->param_count; i++) {
        switch (func_type->types[i]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
            {
                arg_i32 = *argv++;

                if (signature) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(
                                module, (uint64)arg_i32, (uint64)ptr_len))
                            goto fail;

                        arg_i32 = (uintptr_t)wasm_runtime_addr_app_to_native(
                            module, (uint64)arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(
                                module, (uint64)arg_i32))
                            goto fail;

                        arg_i32 = (uintptr_t)wasm_runtime_addr_app_to_native(
                            module, (uint64)arg_i32);
                    }
                }

                argv1[j++] = arg_i32;
                break;
            }
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
#if !defined(BUILD_TARGET_X86_32)
                /* 64-bit data must be 8 bytes aligned in arm, thumb, mips
                   and xtensa */
                if (j & 1)
                    j++;
#endif
                argv1[j++] = *argv++;
                argv1[j++] = *argv++;
                break;
            case VALUE_TYPE_F32:
                argv1[j++] = *argv++;
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                uint32 externref_idx = *argv++;
                if (is_aot_func) {
                    argv1[j++] = externref_idx;
                }
                else {
                    void *externref_obj;

                    if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                        goto fail;

                    argv1[j++] = (uintptr_t)externref_obj;
                }
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }

    /* Save extra result values' address to argv1 */
    word_copy(argv1 + j, argv, ext_ret_count);

    argc1 = j + ext_ret_count;
    exec_env->attachment = attachment;
    if (func_type->result_count == 0) {
        invokeNative_Void(func_ptr, argv1, argc1);
    }
    else {
        switch (func_type->types[func_type->param_count]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
                argv_ret[0] =
                    (uint32)invokeNative_Int32(func_ptr, argv1, argc1);
                break;
            case VALUE_TYPE_I64:
                PUT_I64_TO_ADDR(argv_ret,
                                invokeNative_Int64(func_ptr, argv1, argc1));
                break;
            case VALUE_TYPE_F32:
                *(float32 *)argv_ret =
                    invokeNative_Float32(func_ptr, argv1, argc1);
                break;
            case VALUE_TYPE_F64:
                PUT_F64_TO_ADDR(argv_ret,
                                invokeNative_Float64(func_ptr, argv1, argc1));
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                if (is_aot_func) {
                    uint32 externref_idx =
                        (uint32)invokeNative_Int32(func_ptr, argv1, argc1);
                    argv_ret[0] = externref_idx;
                }
                else {
                    void *externref_obj = (void *)(uintptr_t)invokeNative_Int32(
                        func_ptr, argv1, argc1);
                    uint32 externref_idx;
                    if (!wasm_externref_obj2ref(exec_env->module_inst,
                                                externref_obj, &externref_idx))
                        goto fail;
                    argv_ret[0] = externref_idx;
                }
                break;
            }
#endif
            default:
                bh_assert(0);
                break;
        }
    }
    exec_env->attachment = NULL;

    ret = !wasm_runtime_copy_exception(module, NULL);

fail:
    if (argv1 != argv_buf)
        wasm_runtime_free(argv1);
    return ret;
}

#endif /* end of defined(BUILD_TARGET_X86_32)   \
                 || defined(BUILD_TARGET_ARM)   \
                 || defined(BUILD_TARGET_THUMB) \
                 || defined(BUILD_TARGET_MIPS)  \
                 || defined(BUILD_TARGET_XTENSA) */

#if defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64)            \
    || defined(BUILD_TARGET_AARCH64) || defined(BUILD_TARGET_RISCV64_LP64D) \
    || defined(BUILD_TARGET_RISCV64_LP64)

#if WASM_ENABLE_SIMD != 0
#ifdef v128
#undef v128
#endif

#if defined(_WIN32) || defined(_WIN32_)
typedef union __declspec(intrin_type) __declspec(align(8)) v128 {
    __int8 m128i_i8[16];
    __int16 m128i_i16[8];
    __int32 m128i_i32[4];
    __int64 m128i_i64[2];
    unsigned __int8 m128i_u8[16];
    unsigned __int16 m128i_u16[8];
    unsigned __int32 m128i_u32[4];
    unsigned __int64 m128i_u64[2];
} v128;
#elif defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64) \
    || defined(BUILD_TARGET_RISCV64_LP64D)                         \
    || defined(BUILD_TARGET_RISCV64_LP64)
typedef long long v128
    __attribute__((__vector_size__(16), __may_alias__, __aligned__(1)));
#elif defined(BUILD_TARGET_AARCH64)
#include <arm_neon.h>
typedef uint32x4_t __m128i;
#define v128 __m128i
#endif

#endif /* end of WASM_ENABLE_SIMD != 0 */

typedef void (*GenericFunctionPointer)(void);
void
invokeNative(GenericFunctionPointer f, uint64 *args, uint64 n_stacks);

typedef float64 (*Float64FuncPtr)(GenericFunctionPointer, uint64 *, uint64);
typedef float32 (*Float32FuncPtr)(GenericFunctionPointer, uint64 *, uint64);
typedef int64 (*Int64FuncPtr)(GenericFunctionPointer, uint64 *, uint64);
typedef int32 (*Int32FuncPtr)(GenericFunctionPointer, uint64 *, uint64);
typedef void (*VoidFuncPtr)(GenericFunctionPointer, uint64 *, uint64);

/* NOLINTBEGIN */
static volatile Float64FuncPtr invokeNative_Float64 =
    (Float64FuncPtr)(uintptr_t)invokeNative;
static volatile Float32FuncPtr invokeNative_Float32 =
    (Float32FuncPtr)(uintptr_t)invokeNative;
static volatile Int64FuncPtr invokeNative_Int64 =
    (Int64FuncPtr)(uintptr_t)invokeNative;
static volatile Int32FuncPtr invokeNative_Int32 =
    (Int32FuncPtr)(uintptr_t)invokeNative;
static volatile VoidFuncPtr invokeNative_Void =
    (VoidFuncPtr)(uintptr_t)invokeNative;

#if WASM_ENABLE_SIMD != 0
typedef v128 (*V128FuncPtr)(GenericFunctionPointer, uint64 *, uint64);
static V128FuncPtr invokeNative_V128 = (V128FuncPtr)(uintptr_t)invokeNative;
#endif
/* NOLINTEND */

#if defined(_WIN32) || defined(_WIN32_)
#define MAX_REG_FLOATS 4
#define MAX_REG_INTS 4
#else /* else of defined(_WIN32) || defined(_WIN32_) */
#define MAX_REG_FLOATS 8
#if defined(BUILD_TARGET_AARCH64) || defined(BUILD_TARGET_RISCV64_LP64D) \
    || defined(BUILD_TARGET_RISCV64_LP64)
#define MAX_REG_INTS 8
#else
#define MAX_REG_INTS 6
#endif /* end of defined(BUILD_TARGET_AARCH64)   \
          || defined(BUILD_TARGET_RISCV64_LP64D) \
          || defined(BUILD_TARGET_RISCV64_LP64) */
#endif /* end of defined(_WIN32) || defined(_WIN32_) */

/*
 * ASAN is not designed to work with custom stack unwind or other low-level
 * things. Ignore a function that does some low-level magic. (e.g. walking
 * through the thread's stack bypassing the frame boundaries)
 */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((no_sanitize_address))
#endif
bool
wasm_runtime_invoke_native(WASMExecEnv *exec_env, void *func_ptr,
                           const WASMFuncType *func_type, const char *signature,
                           void *attachment, uint32 *argv, uint32 argc,
                           uint32 *argv_ret)
{
    WASMModuleInstanceCommon *module = wasm_runtime_get_module_inst(exec_env);
#if WASM_ENABLE_MEMORY64 != 0
    WASMMemoryInstance *memory =
        wasm_get_default_memory((WASMModuleInstance *)module);
    bool is_memory64 = memory ? memory->is_memory64 : false;
#endif
    uint64 argv_buf[32] = { 0 }, *argv1 = argv_buf, *ints, *stacks, size,
           arg_i64;
    uint32 *argv_src = argv, i, argc1, n_ints = 0, n_stacks = 0;
    uint32 arg_i32, ptr_len;
    uint32 result_count = func_type->result_count;
    uint32 ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    bool ret = false;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    bool is_aot_func = (NULL == signature);
#endif
#ifndef BUILD_TARGET_RISCV64_LP64
#if WASM_ENABLE_SIMD == 0
    uint64 *fps;
#else
    v128 *fps;
#endif
#else /* else of BUILD_TARGET_RISCV64_LP64 */
#define fps ints
#endif /* end of BUILD_TARGET_RISCV64_LP64 */

#if defined(_WIN32) || defined(_WIN32_) || defined(BUILD_TARGET_RISCV64_LP64)
    /* important difference in calling conventions */
#define n_fps n_ints
#else
    int n_fps = 0;
#endif

#if WASM_ENABLE_SIMD == 0
    argc1 = 1 + MAX_REG_FLOATS + (uint32)func_type->param_count + ext_ret_count;
#else
    argc1 = 1 + MAX_REG_FLOATS * 2 + (uint32)func_type->param_count * 2
            + ext_ret_count;
#endif
    if (argc1 > sizeof(argv_buf) / sizeof(uint64)) {
        size = sizeof(uint64) * (uint64)argc1;
        if (!(argv1 = runtime_malloc((uint32)size, exec_env->module_inst, NULL,
                                     0))) {
            return false;
        }
    }

#ifndef BUILD_TARGET_RISCV64_LP64
#if WASM_ENABLE_SIMD == 0
    fps = argv1;
    ints = fps + MAX_REG_FLOATS;
#else
    fps = (v128 *)argv1;
    ints = (uint64 *)(fps + MAX_REG_FLOATS);
#endif
#else  /* else of BUILD_TARGET_RISCV64_LP64 */
    ints = argv1;
#endif /* end of BUILD_TARGET_RISCV64_LP64 */
    stacks = ints + MAX_REG_INTS;

    ints[n_ints++] = (uint64)(uintptr_t)exec_env;

    for (i = 0; i < func_type->param_count; i++) {
        switch (func_type->types[i]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
            {
                arg_i32 = *argv_src++;
                arg_i64 = arg_i32;
                if (signature
#if WASM_ENABLE_MEMORY64 != 0
                    && !is_memory64
#endif
                ) {
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(
                                module, (uint64)arg_i32, (uint64)ptr_len))
                            goto fail;

                        arg_i64 = (uintptr_t)wasm_runtime_addr_app_to_native(
                            module, (uint64)arg_i32);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(
                                module, (uint64)arg_i32))
                            goto fail;

                        arg_i64 = (uintptr_t)wasm_runtime_addr_app_to_native(
                            module, (uint64)arg_i32);
                    }
                }
                if (n_ints < MAX_REG_INTS)
                    ints[n_ints++] = arg_i64;
                else
                    stacks[n_stacks++] = arg_i64;
                break;
            }
            case VALUE_TYPE_I64:
#if WASM_ENABLE_MEMORY64 != 0
            {
                arg_i64 = GET_I64_FROM_ADDR(argv_src);
                argv_src += 2;
                if (signature && is_memory64) {
                    /* TODO: memory64 pointer with length need a new symbol
                     * to represent type i64, with '~' still represent i32
                     * length */
                    if (signature[i + 1] == '*') {
                        /* param is a pointer */
                        if (signature[i + 2] == '~')
                            /* pointer with length followed */
                            ptr_len = *argv_src;
                        else
                            /* pointer without length followed */
                            ptr_len = 1;

                        if (!wasm_runtime_validate_app_addr(module, arg_i64,
                                                            (uint64)ptr_len))
                            goto fail;

                        arg_i64 = (uint64)wasm_runtime_addr_app_to_native(
                            module, arg_i64);
                    }
                    else if (signature[i + 1] == '$') {
                        /* param is a string */
                        if (!wasm_runtime_validate_app_str_addr(module,
                                                                arg_i64))
                            goto fail;

                        arg_i64 = (uint64)wasm_runtime_addr_app_to_native(
                            module, arg_i64);
                    }
                }
                if (n_ints < MAX_REG_INTS)
                    ints[n_ints++] = arg_i64;
                else
                    stacks[n_stacks++] = arg_i64;
                break;
            }
#endif
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
#endif
                if (n_ints < MAX_REG_INTS)
                    ints[n_ints++] = *(uint64 *)argv_src;
                else
                    stacks[n_stacks++] = *(uint64 *)argv_src;
                argv_src += 2;
                break;
            case VALUE_TYPE_F32:
                if (n_fps < MAX_REG_FLOATS) {
                    *(float32 *)&fps[n_fps++] = *(float32 *)argv_src++;
                }
                else {
                    *(float32 *)&stacks[n_stacks++] = *(float32 *)argv_src++;
                }
                break;
            case VALUE_TYPE_F64:
                if (n_fps < MAX_REG_FLOATS) {
                    *(float64 *)&fps[n_fps++] = *(float64 *)argv_src;
                }
                else {
                    *(float64 *)&stacks[n_stacks++] = *(float64 *)argv_src;
                }
                argv_src += 2;
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                uint32 externref_idx = *argv_src++;
                if (is_aot_func) {
                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = externref_idx;
                    else
                        stacks[n_stacks++] = externref_idx;
                }
                else {
                    void *externref_obj;

                    if (!wasm_externref_ref2obj(externref_idx, &externref_obj))
                        goto fail;

                    if (n_ints < MAX_REG_INTS)
                        ints[n_ints++] = (uintptr_t)externref_obj;
                    else
                        stacks[n_stacks++] = (uintptr_t)externref_obj;
                }
                break;
            }
#endif
#if WASM_ENABLE_SIMD != 0
            case VALUE_TYPE_V128:
                if (n_fps < MAX_REG_FLOATS) {
                    *(v128 *)&fps[n_fps++] = *(v128 *)argv_src;
                }
                else {
                    *(v128 *)&stacks[n_stacks++] = *(v128 *)argv_src;
                    n_stacks++;
                }
                argv_src += 4;
                break;
#endif
            default:
                bh_assert(0);
                break;
        }
    }

    /* Save extra result values' address to argv1 */
    for (i = 0; i < ext_ret_count; i++) {
        if (n_ints < MAX_REG_INTS)
            ints[n_ints++] = *(uint64 *)argv_src;
        else
            stacks[n_stacks++] = *(uint64 *)argv_src;
        argv_src += 2;
    }

    exec_env->attachment = attachment;
    if (result_count == 0) {
        invokeNative_Void(func_ptr, argv1, n_stacks);
    }
    else {
        /* Invoke the native function and get the first result value */
        switch (func_type->types[func_type->param_count]) {
            case VALUE_TYPE_I32:
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
#endif
                argv_ret[0] =
                    (uint32)invokeNative_Int32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_I64:
#if WASM_ENABLE_GC != 0
            case REF_TYPE_FUNCREF:
            case REF_TYPE_EXTERNREF:
            case REF_TYPE_ANYREF:
            case REF_TYPE_EQREF:
            case REF_TYPE_HT_NULLABLE:
            case REF_TYPE_HT_NON_NULLABLE:
            case REF_TYPE_I31REF:
            case REF_TYPE_NULLFUNCREF:
            case REF_TYPE_NULLEXTERNREF:
            case REF_TYPE_STRUCTREF:
            case REF_TYPE_ARRAYREF:
            case REF_TYPE_NULLREF:
#if WASM_ENABLE_STRINGREF != 0
            case REF_TYPE_STRINGREF:
            case REF_TYPE_STRINGVIEWWTF8:
            case REF_TYPE_STRINGVIEWWTF16:
            case REF_TYPE_STRINGVIEWITER:
#endif
#endif
                PUT_I64_TO_ADDR(argv_ret,
                                invokeNative_Int64(func_ptr, argv1, n_stacks));
                break;
            case VALUE_TYPE_F32:
                *(float32 *)argv_ret =
                    invokeNative_Float32(func_ptr, argv1, n_stacks);
                break;
            case VALUE_TYPE_F64:
                PUT_F64_TO_ADDR(
                    argv_ret, invokeNative_Float64(func_ptr, argv1, n_stacks));
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
            {
                if (is_aot_func) {
                    argv_ret[0] = invokeNative_Int32(func_ptr, argv1, n_stacks);
                }
                else {
                    uint32 externref_idx;
                    void *externref_obj = (void *)(uintptr_t)invokeNative_Int64(
                        func_ptr, argv1, n_stacks);

                    if (!wasm_externref_obj2ref(exec_env->module_inst,
                                                externref_obj, &externref_idx))
                        goto fail;

                    argv_ret[0] = externref_idx;
                }
                break;
            }
#endif
#if WASM_ENABLE_SIMD != 0
            case VALUE_TYPE_V128:
                *(v128 *)argv_ret =
                    invokeNative_V128(func_ptr, argv1, n_stacks);
                break;
#endif
            default:
                bh_assert(0);
                break;
        }
    }
    exec_env->attachment = NULL;

    ret = !wasm_runtime_copy_exception(module, NULL);
fail:
    if (argv1 != argv_buf)
        wasm_runtime_free(argv1);

    return ret;
}

#endif /* end of defined(BUILD_TARGET_X86_64)           \
                 || defined(BUILD_TARGET_AMD_64)        \
                 || defined(BUILD_TARGET_AARCH64)       \
                 || defined(BUILD_TARGET_RISCV64_LP64D) \
                 || defined(BUILD_TARGET_RISCV64_LP64) */

bool
wasm_runtime_call_indirect(WASMExecEnv *exec_env, uint32 element_index,
                           uint32 argc, uint32 argv[])
{
    bool ret = false;

    if (!wasm_runtime_exec_env_check(exec_env)) {
        LOG_ERROR("Invalid exec env stack info.");
        return false;
    }

    /* this function is called from native code, so exec_env->handle and
       exec_env->native_stack_boundary must have been set, we don't set
       it again */

#if WASM_ENABLE_INTERP != 0
    if (exec_env->module_inst->module_type == Wasm_Module_Bytecode)
        ret = wasm_call_indirect(exec_env, 0, element_index, argc, argv);
#endif
#if WASM_ENABLE_AOT != 0
    if (exec_env->module_inst->module_type == Wasm_Module_AoT)
        ret = aot_call_indirect(exec_env, 0, element_index, argc, argv);
#endif

    return ret;
}

static void
exchange_uint32(uint8 *p_data)
{
    uint8 value = *p_data;
    *p_data = *(p_data + 3);
    *(p_data + 3) = value;

    value = *(p_data + 1);
    *(p_data + 1) = *(p_data + 2);
    *(p_data + 2) = value;
}

static void
exchange_uint64(uint8 *p_data)
{
    uint32 value;

    value = *(uint32 *)p_data;
    *(uint32 *)p_data = *(uint32 *)(p_data + 4);
    *(uint32 *)(p_data + 4) = value;
    exchange_uint32(p_data);
    exchange_uint32(p_data + 4);
}

void
wasm_runtime_read_v128(const uint8 *bytes, uint64 *ret1, uint64 *ret2)
{
    uint64 u1, u2;

    bh_memcpy_s(&u1, 8, bytes, 8);
    bh_memcpy_s(&u2, 8, bytes + 8, 8);

    if (!is_little_endian()) {
        exchange_uint64((uint8 *)&u1);
        exchange_uint64((uint8 *)&u2);
        *ret1 = u2;
        *ret2 = u1;
    }
    else {
        *ret1 = u1;
        *ret2 = u2;
    }
}

#if WASM_ENABLE_THREAD_MGR != 0
typedef struct WASMThreadArg {
    WASMExecEnv *new_exec_env;
    wasm_thread_callback_t callback;
    void *arg;
} WASMThreadArg;

WASMExecEnv *
wasm_runtime_spawn_exec_env(WASMExecEnv *exec_env)
{
    return wasm_cluster_spawn_exec_env(exec_env);
}

void
wasm_runtime_destroy_spawned_exec_env(WASMExecEnv *exec_env)
{
    wasm_cluster_destroy_spawned_exec_env(exec_env);
}

static void *
wasm_runtime_thread_routine(void *arg)
{
    WASMThreadArg *thread_arg = (WASMThreadArg *)arg;
    void *ret;

    bh_assert(thread_arg->new_exec_env);
    ret = thread_arg->callback(thread_arg->new_exec_env, thread_arg->arg);

    wasm_runtime_destroy_spawned_exec_env(thread_arg->new_exec_env);
    wasm_runtime_free(thread_arg);

    os_thread_exit(ret);
    return ret;
}

int32
wasm_runtime_spawn_thread(WASMExecEnv *exec_env, wasm_thread_t *tid,
                          wasm_thread_callback_t callback, void *arg)
{
    WASMExecEnv *new_exec_env = wasm_runtime_spawn_exec_env(exec_env);
    WASMThreadArg *thread_arg;
    int32 ret;

    if (!new_exec_env)
        return -1;

    if (!(thread_arg = wasm_runtime_malloc(sizeof(WASMThreadArg)))) {
        wasm_runtime_destroy_spawned_exec_env(new_exec_env);
        return -1;
    }

    thread_arg->new_exec_env = new_exec_env;
    thread_arg->callback = callback;
    thread_arg->arg = arg;

    ret = os_thread_create((korp_tid *)tid, wasm_runtime_thread_routine,
                           thread_arg, APP_THREAD_STACK_SIZE_DEFAULT);

    if (ret != 0) {
        wasm_runtime_destroy_spawned_exec_env(new_exec_env);
        wasm_runtime_free(thread_arg);
    }

    return ret;
}

int32
wasm_runtime_join_thread(wasm_thread_t tid, void **retval)
{
    return os_thread_join((korp_tid)tid, retval);
}

#endif /* end of WASM_ENABLE_THREAD_MGR */

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0

static korp_mutex externref_lock;
static uint32 externref_global_id = 1;
static HashMap *externref_map;

typedef struct ExternRefMapNode {
    /* The extern object from runtime embedder */
    void *extern_obj;
    /* The module instance it belongs to */
    WASMModuleInstanceCommon *module_inst;
    /* Whether it is retained */
    bool retained;
    /* Whether it is marked by runtime */
    bool marked;
    /* cleanup function called when the externref is freed */
    void (*cleanup)(void *);
} ExternRefMapNode;

static uint32
wasm_externref_hash(const void *key)
{
    uint32 externref_idx = (uint32)(uintptr_t)key;
    return externref_idx;
}

static bool
wasm_externref_equal(void *key1, void *key2)
{
    uint32 externref_idx1 = (uint32)(uintptr_t)key1;
    uint32 externref_idx2 = (uint32)(uintptr_t)key2;
    return externref_idx1 == externref_idx2 ? true : false;
}

static bool
wasm_externref_map_init()
{
    if (os_mutex_init(&externref_lock) != 0)
        return false;

    if (!(externref_map = bh_hash_map_create(32, false, wasm_externref_hash,
                                             wasm_externref_equal, NULL,
                                             wasm_runtime_free))) {
        os_mutex_destroy(&externref_lock);
        return false;
    }

    externref_global_id = 1;
    return true;
}

static void
wasm_externref_map_destroy()
{
    bh_hash_map_destroy(externref_map);
    os_mutex_destroy(&externref_lock);
}

typedef struct LookupExtObj_UserData {
    ExternRefMapNode node;
    bool found;
    uint32 externref_idx;
} LookupExtObj_UserData;

static void
lookup_extobj_callback(void *key, void *value, void *user_data)
{
    uint32 externref_idx = (uint32)(uintptr_t)key;
    ExternRefMapNode *node = (ExternRefMapNode *)value;
    LookupExtObj_UserData *user_data_lookup =
        (LookupExtObj_UserData *)user_data;

    if (node->extern_obj == user_data_lookup->node.extern_obj
        && node->module_inst == user_data_lookup->node.module_inst) {
        user_data_lookup->found = true;
        user_data_lookup->externref_idx = externref_idx;
    }
}

static void
delete_externref(void *key, ExternRefMapNode *node)
{
    bh_hash_map_remove(externref_map, key, NULL, NULL);
    if (node->cleanup) {
        (*node->cleanup)(node->extern_obj);
    }
    wasm_runtime_free(node);
}

static void
delete_extobj_callback(void *key, void *value, void *user_data)
{
    ExternRefMapNode *node = (ExternRefMapNode *)value;
    LookupExtObj_UserData *lookup_user_data =
        (LookupExtObj_UserData *)user_data;

    if (node->extern_obj == lookup_user_data->node.extern_obj
        && node->module_inst == lookup_user_data->node.module_inst) {
        lookup_user_data->found = true;
        delete_externref(key, node);
    }
}

bool
wasm_externref_objdel(WASMModuleInstanceCommon *module_inst, void *extern_obj)
{
    LookupExtObj_UserData lookup_user_data = { 0 };
    bool ok = false;

    /* in a wrapper, extern_obj could be any value */
    lookup_user_data.node.extern_obj = extern_obj;
    lookup_user_data.node.module_inst = module_inst;
    lookup_user_data.found = false;

    os_mutex_lock(&externref_lock);
    /* Lookup hashmap firstly */
    bh_hash_map_traverse(externref_map, delete_extobj_callback,
                         (void *)&lookup_user_data);
    if (lookup_user_data.found) {
        ok = true;
    }
    os_mutex_unlock(&externref_lock);

    return ok;
}

bool
wasm_externref_set_cleanup(WASMModuleInstanceCommon *module_inst,
                           void *extern_obj, void (*extern_obj_cleanup)(void *))
{

    LookupExtObj_UserData lookup_user_data = { 0 };
    bool ok = false;

    /* in a wrapper, extern_obj could be any value */
    lookup_user_data.node.extern_obj = extern_obj;
    lookup_user_data.node.module_inst = module_inst;
    lookup_user_data.found = false;

    os_mutex_lock(&externref_lock);
    /* Lookup hashmap firstly */
    bh_hash_map_traverse(externref_map, lookup_extobj_callback,
                         (void *)&lookup_user_data);
    if (lookup_user_data.found) {
        void *key = (void *)(uintptr_t)lookup_user_data.externref_idx;
        ExternRefMapNode *node = bh_hash_map_find(externref_map, key);
        bh_assert(node);
        node->cleanup = extern_obj_cleanup;
        ok = true;
    }
    os_mutex_unlock(&externref_lock);

    return ok;
}

bool
wasm_externref_obj2ref(WASMModuleInstanceCommon *module_inst, void *extern_obj,
                       uint32 *p_externref_idx)
{
    LookupExtObj_UserData lookup_user_data = { 0 };
    ExternRefMapNode *node;
    uint32 externref_idx;

    /*
     * to catch a parameter from `wasm_application_execute_func`,
     * which represents a string 'null'
     */
#if UINTPTR_MAX == UINT32_MAX
    if ((uint32)-1 == (uintptr_t)extern_obj) {
#else
    if ((uint64)-1LL == (uintptr_t)extern_obj) {
#endif
        *p_externref_idx = NULL_REF;
        return true;
    }

    /* in a wrapper, extern_obj could be any value */
    lookup_user_data.node.extern_obj = extern_obj;
    lookup_user_data.node.module_inst = module_inst;
    lookup_user_data.found = false;

    os_mutex_lock(&externref_lock);

    /* Lookup hashmap firstly */
    bh_hash_map_traverse(externref_map, lookup_extobj_callback,
                         (void *)&lookup_user_data);
    if (lookup_user_data.found) {
        *p_externref_idx = lookup_user_data.externref_idx;
        os_mutex_unlock(&externref_lock);
        return true;
    }

    /* Not found in hashmap */
    if (externref_global_id == NULL_REF || externref_global_id == 0) {
        goto fail1;
    }

    if (!(node = wasm_runtime_malloc(sizeof(ExternRefMapNode)))) {
        goto fail1;
    }

    memset(node, 0, sizeof(ExternRefMapNode));
    node->extern_obj = extern_obj;
    node->module_inst = module_inst;
    node->cleanup = NULL;

    externref_idx = externref_global_id;

    if (!bh_hash_map_insert(externref_map, (void *)(uintptr_t)externref_idx,
                            (void *)node)) {
        goto fail2;
    }

    externref_global_id++;
    *p_externref_idx = externref_idx;
    os_mutex_unlock(&externref_lock);
    return true;
fail2:
    wasm_runtime_free(node);
fail1:
    os_mutex_unlock(&externref_lock);
    return false;
}

bool
wasm_externref_ref2obj(uint32 externref_idx, void **p_extern_obj)
{
    ExternRefMapNode *node;

    /* catch a `ref.null` variable */
    if (externref_idx == NULL_REF) {
        *p_extern_obj = NULL;
        return true;
    }

    os_mutex_lock(&externref_lock);
    node = bh_hash_map_find(externref_map, (void *)(uintptr_t)externref_idx);
    os_mutex_unlock(&externref_lock);

    if (!node)
        return false;

    *p_extern_obj = node->extern_obj;
    return true;
}

static void
reclaim_extobj_callback(void *key, void *value, void *user_data)
{
    ExternRefMapNode *node = (ExternRefMapNode *)value;
    WASMModuleInstanceCommon *module_inst =
        (WASMModuleInstanceCommon *)user_data;

    if (node->module_inst == module_inst) {
        if (!node->marked && !node->retained) {
            delete_externref(key, node);
        }
        else {
            node->marked = false;
        }
    }
}

static void
mark_externref(uint32 externref_idx)
{
    ExternRefMapNode *node;

    if (externref_idx != NULL_REF) {
        node =
            bh_hash_map_find(externref_map, (void *)(uintptr_t)externref_idx);
        if (node) {
            node->marked = true;
        }
    }
}

#if WASM_ENABLE_INTERP != 0
static void
interp_mark_all_externrefs(WASMModuleInstance *module_inst)
{
    uint32 i, j, externref_idx;
    table_elem_type_t *table_data;
    uint8 *global_data = module_inst->global_data;
    WASMGlobalInstance *global;
    WASMTableInstance *table;

    global = module_inst->e->globals;
    for (i = 0; i < module_inst->e->global_count; i++, global++) {
        if (global->type == VALUE_TYPE_EXTERNREF) {
            externref_idx = *(uint32 *)(global_data + global->data_offset);
            mark_externref(externref_idx);
        }
    }

    for (i = 0; i < module_inst->table_count; i++) {
        uint8 elem_type = 0;
        uint32 init_size, max_size;

        table = wasm_get_table_inst(module_inst, i);
        (void)wasm_runtime_get_table_inst_elem_type(
            (WASMModuleInstanceCommon *)module_inst, i, &elem_type, &init_size,
            &max_size);

        if (elem_type == VALUE_TYPE_EXTERNREF) {
            table_data = table->elems;
            for (j = 0; j < table->cur_size; j++) {
                externref_idx = table_data[j];
                mark_externref(externref_idx);
            }
        }
        (void)init_size;
        (void)max_size;
    }
}
#endif

#if WASM_ENABLE_AOT != 0
static void
aot_mark_all_externrefs(AOTModuleInstance *module_inst)
{
    uint32 i = 0, j = 0;
    const AOTModule *module = (AOTModule *)module_inst->module;
    const AOTTable *table = module->tables;
    const AOTGlobal *global = module->globals;
    const AOTTableInstance *table_inst;

    for (i = 0; i < module->global_count; i++, global++) {
        if (global->type.val_type == VALUE_TYPE_EXTERNREF) {
            mark_externref(
                *(uint32 *)(module_inst->global_data + global->data_offset));
        }
    }

    for (i = 0; i < module->table_count; i++) {
        table_inst = module_inst->tables[i];
        if ((table + i)->table_type.elem_type == VALUE_TYPE_EXTERNREF) {
            while (j < table_inst->cur_size) {
                mark_externref(table_inst->elems[j++]);
            }
        }
    }
}
#endif

void
wasm_externref_reclaim(WASMModuleInstanceCommon *module_inst)
{
    os_mutex_lock(&externref_lock);
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        interp_mark_all_externrefs((WASMModuleInstance *)module_inst);
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT)
        aot_mark_all_externrefs((AOTModuleInstance *)module_inst);
#endif

    bh_hash_map_traverse(externref_map, reclaim_extobj_callback,
                         (void *)module_inst);
    os_mutex_unlock(&externref_lock);
}

static void
cleanup_extobj_callback(void *key, void *value, void *user_data)
{
    ExternRefMapNode *node = (ExternRefMapNode *)value;
    WASMModuleInstanceCommon *module_inst =
        (WASMModuleInstanceCommon *)user_data;

    if (node->module_inst == module_inst) {
        delete_externref(key, node);
    }
}

void
wasm_externref_cleanup(WASMModuleInstanceCommon *module_inst)
{
    os_mutex_lock(&externref_lock);
    bh_hash_map_traverse(externref_map, cleanup_extobj_callback,
                         (void *)module_inst);
    os_mutex_unlock(&externref_lock);
}

bool
wasm_externref_retain(uint32 externref_idx)
{
    ExternRefMapNode *node;

    os_mutex_lock(&externref_lock);

    if (externref_idx != NULL_REF) {
        node =
            bh_hash_map_find(externref_map, (void *)(uintptr_t)externref_idx);
        if (node) {
            node->retained = true;
            os_mutex_unlock(&externref_lock);
            return true;
        }
    }

    os_mutex_unlock(&externref_lock);
    return false;
}
#endif /* end of WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0 */

#if WASM_ENABLE_DUMP_CALL_STACK != 0
uint32
wasm_runtime_dump_line_buf_impl(const char *line_buf, bool dump_or_print,
                                char **buf, uint32 *len)
{
    if (dump_or_print) {
        return (uint32)os_printf("%s", line_buf);
    }
    else if (*buf) {
        uint32 dump_len;

        dump_len = snprintf(*buf, *len, "%s", line_buf);
        if (dump_len >= *len) {
            dump_len = *len;
        }

        *len = *len - dump_len;
        *buf = *buf + dump_len;
        return dump_len;
    }
    else {
        return (uint32)strlen(line_buf);
    }
}

void
wasm_runtime_dump_call_stack(WASMExecEnv *exec_env)
{
    WASMModuleInstanceCommon *module_inst =
        wasm_exec_env_get_module_inst(exec_env);
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        wasm_interp_dump_call_stack(exec_env, true, NULL, 0);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        aot_dump_call_stack(exec_env, true, NULL, 0);
    }
#endif
}

uint32
wasm_runtime_get_call_stack_buf_size(wasm_exec_env_t exec_env)
{
    WASMModuleInstanceCommon *module_inst =
        wasm_exec_env_get_module_inst(exec_env);

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_interp_dump_call_stack(exec_env, false, NULL, 0);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return aot_dump_call_stack(exec_env, false, NULL, 0);
    }
#endif

    return 0;
}

uint32
wasm_runtime_dump_call_stack_to_buf(wasm_exec_env_t exec_env, char *buf,
                                    uint32 len)
{
    WASMModuleInstanceCommon *module_inst =
        wasm_exec_env_get_module_inst(exec_env);

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_interp_dump_call_stack(exec_env, false, buf, len);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        return aot_dump_call_stack(exec_env, false, buf, len);
    }
#endif

    return 0;
}
#endif /* end of WASM_ENABLE_DUMP_CALL_STACK */

#if WASM_ENABLE_STATIC_PGO != 0
uint32
wasm_runtime_get_pgo_prof_data_size(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *aot_inst = (AOTModuleInstance *)module_inst;
        return aot_get_pgo_prof_data_size(aot_inst);
    }
#endif
    return 0;
}

uint32
wasm_runtime_dump_pgo_prof_data_to_buf(WASMModuleInstanceCommon *module_inst,
                                       char *buf, uint32 len)
{
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstance *aot_inst = (AOTModuleInstance *)module_inst;
        return aot_dump_pgo_prof_data_to_buf(aot_inst, buf, len);
    }
#endif
    return 0;
}
#endif /* end of WASM_ENABLE_STATIC_PGO != 0 */

bool
wasm_runtime_get_table_elem_type(const WASMModuleCommon *module_comm,
                                 uint32 table_idx, uint8 *out_elem_type,
#if WASM_ENABLE_GC != 0
                                 WASMRefType **out_ref_type,
#endif
                                 uint32 *out_min_size, uint32 *out_max_size)
{
#if WASM_ENABLE_INTERP != 0
    if (module_comm->module_type == Wasm_Module_Bytecode) {
        WASMModule *module = (WASMModule *)module_comm;

        if (table_idx < module->import_table_count) {
            WASMTableImport *import_table =
                &((module->import_tables + table_idx)->u.table);
            *out_elem_type = import_table->table_type.elem_type;
#if WASM_ENABLE_GC != 0
            *out_ref_type = import_table->table_type.elem_ref_type;
#endif
            *out_min_size = import_table->table_type.init_size;
            *out_max_size = import_table->table_type.max_size;
        }
        else {
            WASMTable *table =
                module->tables + (table_idx - module->import_table_count);
            *out_elem_type = table->table_type.elem_type;
#if WASM_ENABLE_GC != 0
            *out_ref_type = table->table_type.elem_ref_type;
#endif
            *out_min_size = table->table_type.init_size;
            *out_max_size = table->table_type.max_size;
        }
        return true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_comm->module_type == Wasm_Module_AoT) {
        AOTModule *module = (AOTModule *)module_comm;

        if (table_idx < module->import_table_count) {
            AOTImportTable *import_table = module->import_tables + table_idx;
            *out_elem_type = import_table->table_type.elem_type;
#if WASM_ENABLE_GC != 0
            *out_ref_type = NULL; /* TODO */
#endif
            *out_min_size = import_table->table_type.init_size;
            *out_max_size = import_table->table_type.max_size;
        }
        else {
            AOTTable *table =
                module->tables + (table_idx - module->import_table_count);
            *out_elem_type = table->table_type.elem_type;
#if WASM_ENABLE_GC != 0
            *out_ref_type = NULL; /* TODO */
#endif
            *out_min_size = table->table_type.init_size;
            *out_max_size = table->table_type.max_size;
        }
        return true;
    }
#endif

    return false;
}

bool
wasm_runtime_get_table_inst_elem_type(
    const WASMModuleInstanceCommon *module_inst_comm, uint32 table_idx,
    uint8 *out_elem_type,
#if WASM_ENABLE_GC != 0
    WASMRefType **out_ref_type,
#endif
    uint32 *out_min_size, uint32 *out_max_size)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)module_inst_comm;

    bh_assert(module_inst_comm->module_type == Wasm_Module_Bytecode
              || module_inst_comm->module_type == Wasm_Module_AoT);

    return wasm_runtime_get_table_elem_type(
        (WASMModuleCommon *)module_inst->module, table_idx, out_elem_type,
#if WASM_ENABLE_GC != 0
        out_ref_type,
#endif
        out_min_size, out_max_size);
}

bool
wasm_runtime_get_export_func_type(const WASMModuleCommon *module_comm,
                                  const WASMExport *export, WASMFuncType **out)
{
#if WASM_ENABLE_INTERP != 0
    if (module_comm->module_type == Wasm_Module_Bytecode) {
        WASMModule *module = (WASMModule *)module_comm;

        if (export->index < module->import_function_count) {
            *out = module->import_functions[export->index].u.function.func_type;
        }
        else {
            *out =
                module->functions[export->index - module->import_function_count]
                    ->func_type;
        }
        return true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_comm->module_type == Wasm_Module_AoT) {
        AOTModule *module = (AOTModule *)module_comm;

        if (export->index < module->import_func_count) {
            *out = (WASMFuncType *)
                       module->types[module->import_funcs[export->index]
                                         .func_type_index];
        }
        else {
            *out = (WASMFuncType *)module
                       ->types[module->func_type_indexes
                                   [export->index - module->import_func_count]];
        }
        return true;
    }
#endif
    return false;
}

bool
wasm_runtime_get_export_global_type(const WASMModuleCommon *module_comm,
                                    const WASMExport *export,
                                    uint8 *out_val_type, bool *out_mutability)
{
#if WASM_ENABLE_INTERP != 0
    if (module_comm->module_type == Wasm_Module_Bytecode) {
        WASMModule *module = (WASMModule *)module_comm;

        if (export->index < module->import_global_count) {
            WASMGlobalImport *import_global =
                &((module->import_globals + export->index)->u.global);
            *out_val_type = import_global->type.val_type;
            *out_mutability = import_global->type.is_mutable;
        }
        else {
            WASMGlobal *global =
                module->globals + (export->index - module->import_global_count);
            *out_val_type = global->type.val_type;
            *out_mutability = global->type.is_mutable;
        }
        return true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_comm->module_type == Wasm_Module_AoT) {
        AOTModule *module = (AOTModule *)module_comm;

        if (export->index < module->import_global_count) {
            AOTImportGlobal *import_global =
                module->import_globals + export->index;
            *out_val_type = import_global->type.val_type;
            *out_mutability = import_global->type.is_mutable;
        }
        else {
            AOTGlobal *global =
                module->globals + (export->index - module->import_global_count);
            *out_val_type = global->type.val_type;
            *out_mutability = global->type.is_mutable;
        }
        return true;
    }
#endif
    return false;
}

bool
wasm_runtime_get_export_memory_type(const WASMModuleCommon *module_comm,
                                    const WASMExport *export,
                                    uint32 *out_min_page, uint32 *out_max_page)
{
#if WASM_ENABLE_INTERP != 0
    if (module_comm->module_type == Wasm_Module_Bytecode) {
        WASMModule *module = (WASMModule *)module_comm;

        if (export->index < module->import_memory_count) {
            WASMMemoryImport *import_memory =
                &((module->import_memories + export->index)->u.memory);
            *out_min_page = import_memory->mem_type.init_page_count;
            *out_max_page = import_memory->mem_type.max_page_count;
        }
        else {
            WASMMemory *memory =
                module->memories
                + (export->index - module->import_memory_count);
            *out_min_page = memory->init_page_count;
            *out_max_page = memory->max_page_count;
        }
        return true;
    }
#endif

#if WASM_ENABLE_AOT != 0
    if (module_comm->module_type == Wasm_Module_AoT) {
        AOTModule *module = (AOTModule *)module_comm;

        if (export->index < module->import_memory_count) {
            AOTImportMemory *import_memory =
                module->import_memories + export->index;
            *out_min_page = import_memory->mem_type.init_page_count;
            *out_max_page = import_memory->mem_type.max_page_count;
        }
        else {
            AOTMemory *memory = module->memories
                                + (export->index - module->import_memory_count);
            *out_min_page = memory->init_page_count;
            *out_max_page = memory->max_page_count;
        }
        return true;
    }
#endif
    return false;
}

bool
wasm_runtime_get_export_table_type(const WASMModuleCommon *module_comm,
                                   const WASMExport *export,
                                   uint8 *out_elem_type,
#if WASM_ENABLE_GC != 0
                                   WASMRefType **out_ref_type,
#endif
                                   uint32 *out_min_size, uint32 *out_max_size)
{
    return wasm_runtime_get_table_elem_type(module_comm, export->index,
                                            out_elem_type,
#if WASM_ENABLE_GC != 0
                                            out_ref_type,
#endif
                                            out_min_size, out_max_size);
}

static inline bool
argv_to_params(wasm_val_t *out_params, const uint32 *argv,
               WASMFuncType *func_type)
{
    wasm_val_t *param = out_params;
    uint32 i = 0, *u32;

    for (i = 0; i < func_type->param_count; i++, param++) {
        switch (func_type->types[i]) {
            case VALUE_TYPE_I32:
                param->kind = WASM_I32;
                param->of.i32 = *argv++;
                break;
            case VALUE_TYPE_I64:
                param->kind = WASM_I64;
                u32 = (uint32 *)&param->of.i64;
                u32[0] = *argv++;
                u32[1] = *argv++;
                break;
            case VALUE_TYPE_F32:
                param->kind = WASM_F32;
                param->of.f32 = *(float32 *)argv++;
                break;
            case VALUE_TYPE_F64:
                param->kind = WASM_F64;
                u32 = (uint32 *)&param->of.i64;
                u32[0] = *argv++;
                u32[1] = *argv++;
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
                param->kind = WASM_EXTERNREF;

                if (!wasm_externref_ref2obj(*argv,
                                            (void **)&param->of.foreign)) {
                    return false;
                }

                argv++;
                break;
#endif
            default:
                return false;
        }
    }

    return true;
}

static inline bool
results_to_argv(WASMModuleInstanceCommon *module_inst, uint32 *out_argv,
                const wasm_val_t *results, WASMFuncType *func_type)
{
    const wasm_val_t *result = results;
    uint32 *argv = out_argv, *u32, i;
    uint8 *result_types = func_type->types + func_type->param_count;

    for (i = 0; i < func_type->result_count; i++, result++) {
        switch (result_types[i]) {
            case VALUE_TYPE_I32:
            case VALUE_TYPE_F32:
                *(int32 *)argv++ = result->of.i32;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                u32 = (uint32 *)&result->of.i64;
                *argv++ = u32[0];
                *argv++ = u32[1];
                break;
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_EXTERNREF:
                if (!wasm_externref_obj2ref(module_inst,
                                            (void *)result->of.foreign,
                                            (uint32 *)argv)) {
                    return false;
                }
                argv++;
                break;
#endif
            default:
                return false;
        }
    }

    return true;
}

bool
wasm_runtime_invoke_c_api_native(WASMModuleInstanceCommon *module_inst,
                                 void *func_ptr, WASMFuncType *func_type,
                                 uint32 argc, uint32 *argv, bool with_env,
                                 void *wasm_c_api_env)
{
    wasm_val_t params_buf[16] = { 0 }, results_buf[4] = { 0 };
    wasm_val_t *params = params_buf, *results = results_buf;
    wasm_trap_t *trap = NULL;
    bool ret = false;
    wasm_val_vec_t params_vec = { 0 }, results_vec = { 0 };

    if (func_type->param_count > 16) {
        if (!(params =
                  runtime_malloc(sizeof(wasm_val_t) * func_type->param_count,
                                 module_inst, NULL, 0))) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
            return false;
        }
    }

    if (!argv_to_params(params, argv, func_type)) {
        wasm_runtime_set_exception(module_inst, "unsupported param type");
        goto fail;
    }

    if (func_type->result_count > 4) {
        if (!(results =
                  runtime_malloc(sizeof(wasm_val_t) * func_type->result_count,
                                 module_inst, NULL, 0))) {
            wasm_runtime_set_exception(module_inst, "allocate memory failed");
            goto fail;
        }
    }

    params_vec.data = params;
    params_vec.num_elems = func_type->param_count;
    params_vec.size = func_type->param_count;

    results_vec.data = results;
    results_vec.num_elems = 0;
    results_vec.size = func_type->result_count;

    if (!with_env) {
        wasm_func_callback_t callback = (wasm_func_callback_t)func_ptr;
        trap = callback(&params_vec, &results_vec);
    }
    else {
        wasm_func_callback_with_env_t callback =
            (wasm_func_callback_with_env_t)func_ptr;
        trap = callback(wasm_c_api_env, &params_vec, &results_vec);
    }

    if (trap) {
        if (trap->message->data) {
            /* since trap->message->data does not end with '\0' */
            char trap_message[108] = { 0 };
            uint32 max_size_to_copy = (uint32)sizeof(trap_message) - 1;
            uint32 size_to_copy = (trap->message->size < max_size_to_copy)
                                      ? (uint32)trap->message->size
                                      : max_size_to_copy;
            bh_memcpy_s(trap_message, (uint32)sizeof(trap_message),
                        trap->message->data, size_to_copy);
            wasm_runtime_set_exception(module_inst, trap_message);
        }
        else {
            wasm_runtime_set_exception(
                module_inst, "native function throw unknown exception");
        }
        wasm_trap_delete(trap);
        goto fail;
    }

    if (!results_to_argv(module_inst, argv, results, func_type)) {
        wasm_runtime_set_exception(module_inst, "unsupported result type");
        goto fail;
    }
    ret = true;

fail:
    if (params != params_buf)
        wasm_runtime_free(params);
    if (results != results_buf)
        wasm_runtime_free(results);
    return ret;
}

bool
wasm_runtime_quick_invoke_c_api_native(WASMModuleInstanceCommon *inst_comm,
                                       CApiFuncImport *c_api_import,
                                       wasm_val_t *params, uint32 param_count,
                                       wasm_val_t *results, uint32 result_count)
{
    WASMModuleInstance *module_inst = (WASMModuleInstance *)inst_comm;
    void *func_ptr = c_api_import->func_ptr_linked;
    bool with_env_arg = c_api_import->with_env_arg, ret = true;
    wasm_val_vec_t params_vec = { 0 }, results_vec = { 0 };
    wasm_trap_t *trap = NULL;

    params_vec.data = params;
    params_vec.num_elems = param_count;
    params_vec.size = param_count;

    results_vec.data = results;
    results_vec.num_elems = 0;
    results_vec.size = result_count;

    if (!func_ptr) {
        wasm_set_exception_with_id(module_inst, EXCE_CALL_UNLINKED_IMPORT_FUNC);
        ret = false;
        goto fail;
    }

    if (!with_env_arg) {
        wasm_func_callback_t callback = (wasm_func_callback_t)func_ptr;
        trap = callback(&params_vec, &results_vec);
    }
    else {
        void *wasm_c_api_env = c_api_import->env_arg;
        wasm_func_callback_with_env_t callback =
            (wasm_func_callback_with_env_t)func_ptr;
        trap = callback(wasm_c_api_env, &params_vec, &results_vec);
    }

    if (trap) {
        if (trap->message->data) {
            /* since trap->message->data does not end with '\0' */
            char trap_message[108] = { 0 };
            uint32 max_size_to_copy = (uint32)sizeof(trap_message) - 1;
            uint32 size_to_copy = (trap->message->size < max_size_to_copy)
                                      ? (uint32)trap->message->size
                                      : max_size_to_copy;
            bh_memcpy_s(trap_message, (uint32)sizeof(trap_message),
                        trap->message->data, size_to_copy);
            wasm_set_exception(module_inst, trap_message);
        }
        else {
            wasm_set_exception(module_inst,
                               "native function throw unknown exception");
        }
        wasm_trap_delete(trap);
        ret = false;
    }

fail:
#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
#endif
    return ret;
}

void
wasm_runtime_show_app_heap_corrupted_prompt()
{
    LOG_ERROR("Error: app heap is corrupted, if the wasm file "
              "is compiled by wasi-sdk-12.0 or higher version, "
              "please add -Wl,--export=malloc -Wl,--export=free "
              "to export malloc and free functions. If it is "
              "compiled by asc, please add --exportRuntime to "
              "export the runtime helpers.");
}

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
void
wasm_runtime_destroy_custom_sections(WASMCustomSection *section_list)
{
    WASMCustomSection *section = section_list, *next;
    while (section) {
        next = section->next;
        wasm_runtime_free(section);
        section = next;
    }
}
#endif /* end of WASM_ENABLE_LOAD_CUSTOM_SECTION */

void
wasm_runtime_get_version(uint32_t *major, uint32_t *minor, uint32_t *patch)
{
    *major = WAMR_VERSION_MAJOR;
    *minor = WAMR_VERSION_MINOR;
    *patch = WAMR_VERSION_PATCH;
}

bool
wasm_runtime_is_import_func_linked(const char *module_name,
                                   const char *func_name)
{
    return wasm_native_resolve_symbol(module_name, func_name, NULL, NULL, NULL,
                                      NULL);
}

bool
wasm_runtime_is_import_global_linked(const char *module_name,
                                     const char *global_name)
{
#if WASM_ENABLE_LIBC_BUILTIN != 0
    WASMGlobalImport global = { 0 };
    return wasm_native_lookup_libc_builtin_global(module_name, global_name,
                                                  &global);
#else
    return false;
#endif
}

#if WASM_ENABLE_LIBC_WASI != 0 || WASM_ENABLE_MULTI_MODULE != 0
WASMExport *
loader_find_export(const WASMModuleCommon *module, const char *module_name,
                   const char *field_name, uint8 export_kind, char *error_buf,
                   uint32 error_buf_size)
{
    WASMExport *exports = NULL, *result = NULL, *export;
    uint32 export_count = 0, i;
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;
        exports = (WASMExport *)aot_module->exports;
        export_count = aot_module->export_count;
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;
        exports = wasm_module->exports;
        export_count = wasm_module->export_count;
    }
#endif
    for (i = 0, export = exports; i < export_count; ++i, ++export) {
        if (export->kind == export_kind && !strcmp(field_name, export->name)) {
            result = export;
            goto exit;
        }
    }
    if (i == export_count) {
        LOG_DEBUG("can not find an export %d named %s in the module %s",
                  export_kind, field_name, module_name);
        set_error_buf(error_buf, error_buf_size,
                      "unknown import or incompatible import type");
    }
exit:
    return result;
}
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
WASMModuleCommon *
wasm_runtime_search_sub_module(const WASMModuleCommon *parent_module,
                               const char *sub_module_name)
{
    WASMRegisteredModule *node = NULL;
#if WASM_ENABLE_AOT != 0
    if (parent_module->module_type == Wasm_Module_AoT) {
        node = bh_list_first_elem(
            ((AOTModule *)parent_module)->import_module_list);
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (parent_module->module_type == Wasm_Module_Bytecode) {
        node = bh_list_first_elem(
            ((WASMModule *)parent_module)->import_module_list);
    }
#endif
    while (node && strcmp(sub_module_name, node->module_name)) {
        node = bh_list_elem_next(node);
    }
    return node ? node->module : NULL;
}

bool
wasm_runtime_register_sub_module(const WASMModuleCommon *parent_module,
                                 const char *sub_module_name,
                                 WASMModuleCommon *sub_module)
{
    /* register sub_module into its parent sub module list */
    WASMRegisteredModule *node = NULL;
    bh_list_status ret = BH_LIST_ERROR;

    if (wasm_runtime_search_sub_module(parent_module, sub_module_name)) {
        LOG_DEBUG("%s has been registered in its parent", sub_module_name);
        return true;
    }

    node = loader_malloc(sizeof(WASMRegisteredModule), NULL, 0);
    if (!node) {
        return false;
    }

    node->module_name = sub_module_name;
    node->module = sub_module;
#if WASM_ENABLE_AOT != 0
    if (parent_module->module_type == Wasm_Module_AoT) {
        ret = bh_list_insert(((AOTModule *)parent_module)->import_module_list,
                             node);
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (parent_module->module_type == Wasm_Module_Bytecode) {
        ret = bh_list_insert(((WASMModule *)parent_module)->import_module_list,
                             node);
    }
#endif
    bh_assert(BH_LIST_SUCCESS == ret);
    (void)ret;
    return true;
}

WASMModuleCommon *
wasm_runtime_load_depended_module(const WASMModuleCommon *parent_module,
                                  const char *sub_module_name, char *error_buf,
                                  uint32 error_buf_size)
{
    WASMModuleCommon *sub_module = NULL;
    bool ret = false;
    uint8 *buffer = NULL;
    uint32 buffer_size = 0;
    LoadArgs args = { 0 };

    /* check the registered module list of the parent */
    sub_module = wasm_runtime_search_sub_module(parent_module, sub_module_name);
    if (sub_module) {
        LOG_DEBUG("%s has been loaded before", sub_module_name);
        return sub_module;
    }

    /* check the global registered module list */
    sub_module = wasm_runtime_find_module_registered(sub_module_name);
    if (sub_module) {
        LOG_DEBUG("%s has been loaded", sub_module_name);
        goto wasm_runtime_register_sub_module;
    }
    LOG_VERBOSE("loading %s", sub_module_name);
    if (!reader) {
        set_error_buf_v(parent_module, error_buf, error_buf_size,
                        "no sub module reader to load %s", sub_module_name);
        return NULL;
    }
    /* start to maintain a loading module list */
    ret = wasm_runtime_is_loading_module(sub_module_name);
    if (ret) {
        set_error_buf_v(parent_module, error_buf, error_buf_size,
                        "found circular dependency on %s", sub_module_name);
        return NULL;
    }
    ret = wasm_runtime_add_loading_module(sub_module_name, error_buf,
                                          error_buf_size);
    if (!ret) {
        LOG_DEBUG("can not add %s into loading module list\n", sub_module_name);
        return NULL;
    }

    ret = reader(parent_module->module_type, sub_module_name, &buffer,
                 &buffer_size);
    if (!ret) {
        LOG_DEBUG("read the file of %s failed", sub_module_name);
        set_error_buf_v(parent_module, error_buf, error_buf_size,
                        "unknown import %s", sub_module_name);
        goto delete_loading_module;
    }
    if (get_package_type(buffer, buffer_size) != parent_module->module_type) {
        LOG_DEBUG("module %s type error", sub_module_name);
        goto destroy_file_buffer;
    }

    args.name = (char *)sub_module_name;
    if (get_package_type(buffer, buffer_size) == Wasm_Module_Bytecode) {
#if WASM_ENABLE_INTERP != 0
        sub_module = (WASMModuleCommon *)wasm_load(
            buffer, buffer_size, false, &args, error_buf, error_buf_size);
#endif
    }
    else if (get_package_type(buffer, buffer_size) == Wasm_Module_AoT) {
#if WASM_ENABLE_AOT != 0
        sub_module = (WASMModuleCommon *)aot_load_from_aot_file(
            buffer, buffer_size, &args, error_buf, error_buf_size);
#endif
    }
    if (!sub_module) {
        LOG_DEBUG("error: can not load the sub_module %s", sub_module_name);
        /* others will be destroyed in runtime_destroy() */
        goto destroy_file_buffer;
    }
    wasm_runtime_delete_loading_module(sub_module_name);
    /* register on a global list */
    ret = wasm_runtime_register_module_internal(
        sub_module_name, (WASMModuleCommon *)sub_module, buffer, buffer_size,
        error_buf, error_buf_size);
    if (!ret) {
        LOG_DEBUG("error: can not register module %s globally\n",
                  sub_module_name);
        /* others will be unloaded in runtime_destroy() */
        goto unload_module;
    }

    /* register into its parent list */
wasm_runtime_register_sub_module:
    ret = wasm_runtime_register_sub_module(parent_module, sub_module_name,
                                           sub_module);
    if (!ret) {
        set_error_buf_v(parent_module, error_buf, error_buf_size,
                        "failed to register sub module %s", sub_module_name);
        /* since it is in the global module list, no need to
         * unload the module. the runtime_destroy() will do it
         */
        return NULL;
    }

    return sub_module;

unload_module:
    wasm_runtime_unload(sub_module);

destroy_file_buffer:
    if (destroyer) {
        destroyer(buffer, buffer_size);
    }
    else {
        LOG_WARNING("need to release the reading buffer of %s manually",
                    sub_module_name);
    }

delete_loading_module:
    wasm_runtime_delete_loading_module(sub_module_name);
    return NULL;
}

bool
wasm_runtime_sub_module_instantiate(WASMModuleCommon *module,
                                    WASMModuleInstanceCommon *module_inst,
                                    uint32 stack_size, uint32 heap_size,
                                    uint32 max_memory_pages, char *error_buf,
                                    uint32 error_buf_size)
{
    bh_list *sub_module_inst_list = NULL;
    WASMRegisteredModule *sub_module_list_node = NULL;

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        sub_module_inst_list =
            ((AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e)
                ->sub_module_inst_list;
        sub_module_list_node =
            bh_list_first_elem(((AOTModule *)module)->import_module_list);
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        sub_module_inst_list =
            ((WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e)
                ->sub_module_inst_list;
        sub_module_list_node =
            bh_list_first_elem(((WASMModule *)module)->import_module_list);
    }
#endif
    while (sub_module_list_node) {
        WASMSubModInstNode *sub_module_inst_list_node = NULL;
        WASMModuleCommon *sub_module = sub_module_list_node->module;
        WASMModuleInstanceCommon *sub_module_inst = NULL;
        sub_module_inst = wasm_runtime_instantiate_internal(
            sub_module, NULL, NULL, stack_size, heap_size, max_memory_pages,
            error_buf, error_buf_size);
        if (!sub_module_inst) {
            LOG_DEBUG("instantiate %s failed",
                      sub_module_list_node->module_name);
            return false;
        }
        sub_module_inst_list_node = loader_malloc(sizeof(WASMSubModInstNode),
                                                  error_buf, error_buf_size);
        if (!sub_module_inst_list_node) {
            LOG_DEBUG("Malloc WASMSubModInstNode failed, SZ: %zu",
                      sizeof(WASMSubModInstNode));
            if (sub_module_inst)
                wasm_runtime_deinstantiate_internal(sub_module_inst, false);
            return false;
        }
        sub_module_inst_list_node->module_inst =
            (WASMModuleInstance *)sub_module_inst;
        sub_module_inst_list_node->module_name =
            sub_module_list_node->module_name;

#if WASM_ENABLE_AOT != 0
        if (module_inst->module_type == Wasm_Module_AoT) {
            AOTModuleInstance *aot_module_inst =
                (AOTModuleInstance *)module_inst;
            AOTModule *aot_module = (AOTModule *)module;
            AOTModuleInstanceExtra *aot_extra =
                (AOTModuleInstanceExtra *)aot_module_inst->e;
            uint32 i;
            AOTImportFunc *import_func;
            for (i = 0; i < aot_module->import_func_count; i++) {
                if (aot_extra->import_func_module_insts[i])
                    continue;

                import_func = &aot_module->import_funcs[i];
                if (strcmp(sub_module_inst_list_node->module_name,
                           import_func->module_name)
                    == 0) {
                    aot_extra->import_func_module_insts[i] =
                        (WASMModuleInstanceCommon *)
                            sub_module_inst_list_node->module_inst;
                }
            }
        }
#endif

        bh_list_status ret =
            bh_list_insert(sub_module_inst_list, sub_module_inst_list_node);
        bh_assert(BH_LIST_SUCCESS == ret);
        (void)ret;
        sub_module_list_node = bh_list_elem_next(sub_module_list_node);
    }

    return true;
}

void
wasm_runtime_sub_module_deinstantiate(WASMModuleInstanceCommon *module_inst)
{
    bh_list *list = NULL;
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        list = ((AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e)
                   ->sub_module_inst_list;
    }
#endif
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        list =
            ((WASMModuleInstanceExtra *)((WASMModuleInstance *)module_inst)->e)
                ->sub_module_inst_list;
    }
#endif

    WASMSubModInstNode *node = bh_list_first_elem(list);
    while (node) {
        WASMSubModInstNode *next_node = bh_list_elem_next(node);
        bh_list_remove(list, node);
        wasm_runtime_deinstantiate_internal(
            (WASMModuleInstanceCommon *)node->module_inst, false);
        wasm_runtime_free(node);
        node = next_node;
    }
}
#endif /* end of WASM_ENABLE_MULTI_MODULE */
#if WASM_ENABLE_MODULE_INST_CONTEXT != 0
void *
wasm_runtime_create_context_key(void (*dtor)(WASMModuleInstanceCommon *inst,
                                             void *ctx))
{
    return wasm_native_create_context_key(dtor);
}

void
wasm_runtime_destroy_context_key(void *key)
{
    wasm_native_destroy_context_key(key);
}

void
wasm_runtime_set_context(WASMModuleInstanceCommon *inst, void *key, void *ctx)
{
    wasm_native_set_context(inst, key, ctx);
}

void
wasm_runtime_set_context_spread(WASMModuleInstanceCommon *inst, void *key,
                                void *ctx)
{
    wasm_native_set_context_spread(inst, key, ctx);
}

void *
wasm_runtime_get_context(WASMModuleInstanceCommon *inst, void *key)
{
    return wasm_native_get_context(inst, key);
}
#endif /* WASM_ENABLE_MODULE_INST_CONTEXT != 0 */

#if WASM_ENABLE_LINUX_PERF != 0
static bool enable_linux_perf = false;

bool
wasm_runtime_get_linux_perf(void)
{
    return enable_linux_perf;
}

void
wasm_runtime_set_linux_perf(bool flag)
{
    enable_linux_perf = flag;
}
#endif

bool
wasm_runtime_set_module_name(wasm_module_t module, const char *name,
                             char *error_buf, uint32_t error_buf_size)
{
    if (!module)
        return false;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode)
        return wasm_set_module_name((WASMModule *)module, name, error_buf,
                                    error_buf_size);
#endif

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT)
        return aot_set_module_name((AOTModule *)module, name, error_buf,
                                   error_buf_size);
#endif

    return false;
}

const char *
wasm_runtime_get_module_name(wasm_module_t module)
{
    if (!module)
        return "";

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode)
        return wasm_get_module_name((WASMModule *)module);
#endif

#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT)
        return aot_get_module_name((AOTModule *)module);
#endif

    return "";
}

/*
 * wasm_runtime_detect_native_stack_overflow
 *
 * - raise "native stack overflow" exception if available native stack
 *   at this point is less than WASM_STACK_GUARD_SIZE. in that case,
 *   return false.
 *
 * - update native_stack_top_min.
 */
bool
wasm_runtime_detect_native_stack_overflow(WASMExecEnv *exec_env)
{
    uint8 *boundary = exec_env->native_stack_boundary;
    RECORD_STACK_USAGE(exec_env, (uint8 *)&boundary);
    if (boundary == NULL) {
        /* the platform doesn't support os_thread_get_stack_boundary */
        return true;
    }
#if defined(OS_ENABLE_HW_BOUND_CHECK) && WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    uint32 page_size = os_getpagesize();
    uint32 guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    boundary = boundary + page_size * guard_page_count;
#endif
    if ((uint8 *)&boundary < boundary) {
        wasm_runtime_set_exception(wasm_runtime_get_module_inst(exec_env),
                                   "native stack overflow");
        return false;
    }
    return true;
}

bool
wasm_runtime_detect_native_stack_overflow_size(WASMExecEnv *exec_env,
                                               uint32 requested_size)
{
    uint8 *boundary = exec_env->native_stack_boundary;
    RECORD_STACK_USAGE(exec_env, (uint8 *)&boundary);
    if (boundary == NULL) {
        /* the platform doesn't support os_thread_get_stack_boundary */
        return true;
    }
#if defined(OS_ENABLE_HW_BOUND_CHECK) && WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    uint32 page_size = os_getpagesize();
    uint32 guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    boundary = boundary + page_size * guard_page_count;
#endif
    /* adjust the boundary for the requested size */
    boundary = boundary - WASM_STACK_GUARD_SIZE + requested_size;
    if ((uint8 *)&boundary < boundary) {
        wasm_runtime_set_exception(wasm_runtime_get_module_inst(exec_env),
                                   "native stack overflow");
        return false;
    }
    return true;
}

bool
wasm_runtime_is_underlying_binary_freeable(WASMModuleCommon *const module)
{
#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
#if (WASM_ENABLE_JIT != 0 || WASM_ENABLE_FAST_JIT != 0) \
    && (WASM_ENABLE_LAZY_JIT != 0)
        return false;
#elif WASM_ENABLE_FAST_INTERP == 0
        return false;
#else
        /* Fast interpreter mode */
        if (!((WASMModule *)module)->is_binary_freeable)
            return false;
#if WASM_ENABLE_GC != 0 && WASM_ENABLE_STRINGREF != 0
        if (((WASMModule *)module)->string_literal_ptrs)
            return false;
#endif
#endif
    }
#endif /* WASM_ENABLE_INTERP != 0 */
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        if (!((AOTModule *)module)->is_binary_freeable)
            return false;
#if WASM_ENABLE_GC != 0 && WASM_ENABLE_STRINGREF != 0
        if (((AOTModule *)module)->string_literal_ptrs)
            return false;
#endif
    }
#endif /* WASM_ENABLE_AOT != 0 */

    return true;
}

#if WASM_ENABLE_SHARED_HEAP != 0
bool
wasm_runtime_check_and_update_last_used_shared_heap(
    WASMModuleInstanceCommon *module_inst, uintptr_t app_offset, size_t bytes,
    uintptr_t *shared_heap_start_off_p, uintptr_t *shared_heap_end_off_p,
    uint8 **shared_heap_base_addr_adj_p, bool is_memory64)
{
    WASMSharedHeap *heap = wasm_runtime_get_shared_heap(module_inst), *cur;
    uint64 shared_heap_start, shared_heap_end;

    if (bytes == 0) {
        bytes = 1;
    }

    /* Find the exact shared heap that app addr is in, and update last used
     * shared heap info in func context */
    for (cur = heap; cur; cur = cur->chain_next) {
        shared_heap_start =
            is_memory64 ? cur->start_off_mem64 : cur->start_off_mem32;
        shared_heap_end = shared_heap_start - 1 + cur->size;
        if (bytes - 1 <= shared_heap_end && app_offset >= shared_heap_start
            && app_offset <= shared_heap_end - bytes + 1) {
            *shared_heap_start_off_p = (uintptr_t)shared_heap_start;
            *shared_heap_end_off_p = (uintptr_t)shared_heap_end;
            *shared_heap_base_addr_adj_p =
                cur->base_addr - (uintptr_t)shared_heap_start;
            return true;
        }
    }

    return false;
}
#endif
