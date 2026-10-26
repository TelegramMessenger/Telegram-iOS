/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/**
 * @file   wasm_export.h
 *
 * @brief  This file defines the exported common runtime APIs
 */

#ifndef _WASM_EXPORT_H
#define _WASM_EXPORT_H

#include <stdint.h>
#include <stdbool.h>
#include "lib_export.h"

#ifndef WASM_RUNTIME_API_EXTERN
#if defined(_MSC_BUILD)
#if defined(COMPILING_WASM_RUNTIME_API)
#define WASM_RUNTIME_API_EXTERN __declspec(dllexport)
#else
#define WASM_RUNTIME_API_EXTERN __declspec(dllimport)
#endif
#elif defined(__GNUC__) || defined(__clang__)
#define WASM_RUNTIME_API_EXTERN __attribute__((visibility("default")))
#else
#define WASM_RUNTIME_API_EXTERN
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define get_module_inst(exec_env) wasm_runtime_get_module_inst(exec_env)

#define validate_app_addr(offset, size) \
    wasm_runtime_validate_app_addr(module_inst, offset, size)

#define validate_app_str_addr(offset) \
    wasm_runtime_validate_app_str_addr(module_inst, offset)

#define addr_app_to_native(offset) \
    wasm_runtime_addr_app_to_native(module_inst, offset)

#define addr_native_to_app(ptr) \
    wasm_runtime_addr_native_to_app(module_inst, ptr)

#define module_malloc(size, p_native_addr) \
    wasm_runtime_module_malloc(module_inst, size, p_native_addr)

#define module_free(offset) wasm_runtime_module_free(module_inst, offset)

#define native_raw_return_type(type, args) type *raw_ret = (type *)(args)

#define native_raw_get_arg(type, name, args) type name = *((type *)(args++))

#define native_raw_set_return(val) *raw_ret = (val)

#ifndef WASM_MODULE_T_DEFINED
#define WASM_MODULE_T_DEFINED
/* Uninstantiated WASM module loaded from WASM binary file
   or AoT binary file*/
struct WASMModuleCommon;
typedef struct WASMModuleCommon *wasm_module_t;
#endif

typedef enum {
    WASM_IMPORT_EXPORT_KIND_FUNC,
    WASM_IMPORT_EXPORT_KIND_TABLE,
    WASM_IMPORT_EXPORT_KIND_MEMORY,
    WASM_IMPORT_EXPORT_KIND_GLOBAL
} wasm_import_export_kind_t;

struct WASMFuncType;
typedef struct WASMFuncType *wasm_func_type_t;

struct WASMTableType;
typedef struct WASMTableType *wasm_table_type_t;

struct WASMGlobalType;
typedef struct WASMGlobalType *wasm_global_type_t;

#ifndef WASM_MEMORY_T_DEFINED
#define WASM_MEMORY_T_DEFINED
struct WASMMemory;
typedef struct WASMMemory WASMMemoryType;
#endif
typedef WASMMemoryType *wasm_memory_type_t;

typedef struct wasm_import_t {
    const char *module_name;
    const char *name;
    wasm_import_export_kind_t kind;
    bool linked;
    union {
        wasm_func_type_t func_type;
        wasm_table_type_t table_type;
        wasm_global_type_t global_type;
        wasm_memory_type_t memory_type;
    } u;
} wasm_import_t;

typedef struct wasm_export_t {
    const char *name;
    wasm_import_export_kind_t kind;
    union {
        wasm_func_type_t func_type;
        wasm_table_type_t table_type;
        wasm_global_type_t global_type;
        wasm_memory_type_t memory_type;
    } u;
} wasm_export_t;

/* Instantiated WASM module */
struct WASMModuleInstanceCommon;
typedef struct WASMModuleInstanceCommon *wasm_module_inst_t;

/* Function instance */
typedef void WASMFunctionInstanceCommon;
typedef WASMFunctionInstanceCommon *wasm_function_inst_t;

/* Memory instance */
struct WASMMemoryInstance;
typedef struct WASMMemoryInstance *wasm_memory_inst_t;

typedef struct wasm_frame_t {
    /*  wasm_instance_t */
    void *instance;
    uint32_t module_offset;
    uint32_t func_index;
    uint32_t func_offset;
    const char *func_name_wp;

    uint32_t *sp;
    uint8_t *frame_ref;
    uint32_t *lp;
} WASMCApiFrame;

/* WASM section */
typedef struct wasm_section_t {
    struct wasm_section_t *next;
    /* section type */
    int section_type;
    /* section body, not include type and size */
    uint8_t *section_body;
    /* section body size */
    uint32_t section_body_size;
} wasm_section_t, aot_section_t, *wasm_section_list_t, *aot_section_list_t;

/* Execution environment, e.g. stack info */
struct WASMExecEnv;
typedef struct WASMExecEnv *wasm_exec_env_t;

struct WASMSharedHeap;
typedef struct WASMSharedHeap *wasm_shared_heap_t;

/* Package Type */
typedef enum {
    Wasm_Module_Bytecode = 0,
    Wasm_Module_AoT,
    Package_Type_Unknown = 0xFFFF
} package_type_t;

#ifndef MEM_ALLOC_OPTION_DEFINED
#define MEM_ALLOC_OPTION_DEFINED
/* Memory allocator type */
typedef enum {
    /* pool mode, allocate memory from user defined heap buffer */
    Alloc_With_Pool = 0,
    /* user allocator mode, allocate memory from user defined
       malloc function */
    Alloc_With_Allocator,
    /* system allocator mode, allocate memory from system allocator,
       or, platform's os_malloc function */
    Alloc_With_System_Allocator,
} mem_alloc_type_t;

typedef enum { Alloc_For_Runtime, Alloc_For_LinearMemory } mem_alloc_usage_t;

/* Memory allocator option */
typedef union MemAllocOption {
    struct {
        void *heap_buf;
        uint32_t heap_size;
    } pool;
    struct {
        /* the function signature is varied when
        WASM_MEM_ALLOC_WITH_USER_DATA and
        WASM_MEM_ALLOC_WITH_USAGE are defined */
        void *malloc_func;
        void *realloc_func;
        void *free_func;
        /* allocator user data, only used when
           WASM_MEM_ALLOC_WITH_USER_DATA is defined */
        void *user_data;
    } allocator;
} MemAllocOption;
#endif

/* Memory pool info  */
typedef struct mem_alloc_info_t {
    uint32_t total_size;
    uint32_t total_free_size;
    uint32_t highmark_size;
} mem_alloc_info_t;

/* Running mode of runtime and module instance*/
typedef enum RunningMode {
    Mode_Interp = 1,
    Mode_Fast_JIT,
    Mode_LLVM_JIT,
    Mode_Multi_Tier_JIT,
} RunningMode;

/* WASM runtime initialize arguments */
typedef struct RuntimeInitArgs {
    mem_alloc_type_t mem_alloc_type;
    MemAllocOption mem_alloc_option;

    const char *native_module_name;
    NativeSymbol *native_symbols;
    uint32_t n_native_symbols;

    /* maximum thread number, only used when
       WASM_ENABLE_THREAD_MGR is defined */
    uint32_t max_thread_num;

    /* Debug settings, only used when
       WASM_ENABLE_DEBUG_INTERP != 0 */
    char ip_addr[128];
    int unused; /* was platform_port */
    int instance_port;

    /* Fast JIT code cache size */
    uint32_t fast_jit_code_cache_size;

    /* Default GC heap size */
    uint32_t gc_heap_size;

    /* Default running mode of the runtime */
    RunningMode running_mode;

    /* LLVM JIT opt and size level */
    uint32_t llvm_jit_opt_level;
    uint32_t llvm_jit_size_level;
    /* Segue optimization flags for LLVM JIT */
    uint32_t segue_flags;
    /**
     * If enabled
     * - llvm-jit will output a jitdump file for `perf inject`
     * - aot will output a perf-${pid}.map for `perf record`
     * - fast-jit. TBD
     * - multi-tier-jit. TBD
     * - interpreter. TBD
     */
    bool enable_linux_perf;
} RuntimeInitArgs;

#ifndef LOAD_ARGS_OPTION_DEFINED
#define LOAD_ARGS_OPTION_DEFINED
typedef struct LoadArgs {
    char *name;
    /* This option is only used by the Wasm C API (see wasm_c_api.h) */
    bool clone_wasm_binary;
    /* False by default, used by AOT/wasm loader only.
    If true, the AOT/wasm loader creates a copy of some module fields (e.g.
    const strings), making it possible to free the wasm binary buffer after
    loading. */
    bool wasm_binary_freeable;

    /* false by default, if true, don't resolve the symbols yet. The
       wasm_runtime_load_ex has to be followed by a wasm_runtime_resolve_symbols
       call */
    bool no_resolve;
    /* TODO: more fields? */
} LoadArgs;
#endif /* LOAD_ARGS_OPTION_DEFINED */

#ifndef INSTANTIATION_ARGS_OPTION_DEFINED
#define INSTANTIATION_ARGS_OPTION_DEFINED
/* WASM module instantiation arguments */
typedef struct InstantiationArgs {
    uint32_t default_stack_size;
    uint32_t host_managed_heap_size;
    uint32_t max_memory_pages;
} InstantiationArgs;
#endif /* INSTANTIATION_ARGS_OPTION_DEFINED */

struct InstantiationArgs2;

#ifndef WASM_VALKIND_T_DEFINED
#define WASM_VALKIND_T_DEFINED
typedef uint8_t wasm_valkind_t;
enum wasm_valkind_enum {
    WASM_I32,
    WASM_I64,
    WASM_F32,
    WASM_F64,
    WASM_V128,
    WASM_EXTERNREF = 128,
    WASM_FUNCREF,
};
#endif

#ifndef WASM_VAL_T_DEFINED
#define WASM_VAL_T_DEFINED
struct wasm_ref_t;

typedef struct wasm_val_t {
    wasm_valkind_t kind;
    uint8_t _paddings[7];
    union {
        /* also represent a function index */
        int32_t i32;
        int64_t i64;
        float f32;
        double f64;
        /* represent a foreign object, aka externref in .wat */
        uintptr_t foreign;
        struct wasm_ref_t *ref;
    } of;
} wasm_val_t;
#endif

/* Global instance*/
typedef struct wasm_global_inst_t {
    wasm_valkind_t kind;
    bool is_mutable;
    void *global_data;
} wasm_global_inst_t;

/* Table instance*/
typedef struct wasm_table_inst_t {
    wasm_valkind_t elem_kind;
    uint32_t cur_size;
    uint32_t max_size;
    /* represents the elements of the table, for internal use only */
    void *elems;
} wasm_table_inst_t;

typedef enum {
    WASM_LOG_LEVEL_FATAL = 0,
    WASM_LOG_LEVEL_ERROR = 1,
    WASM_LOG_LEVEL_WARNING = 2,
    WASM_LOG_LEVEL_DEBUG = 3,
    WASM_LOG_LEVEL_VERBOSE = 4
} log_level_t;

typedef struct SharedHeapInitArgs {
    uint32_t size;
    void *pre_allocated_addr;
} SharedHeapInitArgs;

/**
 * Initialize the WASM runtime environment, and also initialize
 * the memory allocator with system allocator, which calls os_malloc
 * to allocate memory
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_init(void);

/**
 * Initialize the WASM runtime environment, WASM running mode,
 * and also initialize the memory allocator and register native symbols,
 * which are specified with init arguments
 *
 * @param init_args specifies the init arguments
 *
 * @return return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_full_init(RuntimeInitArgs *init_args);

/**
 * Set the log level. To be called after the runtime is initialized.
 *
 * @param level the log level to set
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_log_level(log_level_t level);

/**
 * Query whether a certain running mode is supported for the runtime
 *
 * @param running_mode the running mode to query
 *
 * @return true if this running mode is supported, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_running_mode_supported(RunningMode running_mode);

/**
 * Set the default running mode for the runtime. It is inherited
 * to set the running mode of a module instance when it is instantiated,
 * and can be changed by calling wasm_runtime_set_running_mode
 *
 * @param running_mode the running mode to set
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_set_default_running_mode(RunningMode running_mode);

/**
 * Destroy the WASM runtime environment.
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy(void);

/**
 * Allocate memory from runtime memory environment.
 *
 * @param size bytes need to allocate
 *
 * @return the pointer to memory allocated
 */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_malloc(unsigned int size);

/**
 * Reallocate memory from runtime memory environment
 *
 * @param ptr the original memory
 * @param size bytes need to reallocate
 *
 * @return the pointer to memory reallocated
 */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_realloc(void *ptr, unsigned int size);

/*
 * Free memory to runtime memory environment.
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_free(void *ptr);

/*
 * Get memory info, only pool mode is supported now.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_get_mem_alloc_info(mem_alloc_info_t *mem_alloc_info);

/**
 * Get the package type of a buffer.
 *
 * @param buf the package buffer
 * @param size the package buffer size
 *
 * @return the package type, return Package_Type_Unknown if the type is unknown
 */
WASM_RUNTIME_API_EXTERN package_type_t
get_package_type(const uint8_t *buf, uint32_t size);

/**
 * Get the package type of a buffer (same as get_package_type).
 *
 * @param buf the package buffer
 * @param size the package buffer size
 *
 * @return the package type, return Package_Type_Unknown if the type is unknown
 */
WASM_RUNTIME_API_EXTERN package_type_t
wasm_runtime_get_file_package_type(const uint8_t *buf, uint32_t size);

/**
 * Get the package type of a module.
 *
 * @param module the module
 *
 * @return the package type, return Package_Type_Unknown if the type is
 * unknown
 */
WASM_RUNTIME_API_EXTERN package_type_t
wasm_runtime_get_module_package_type(const wasm_module_t module);

/**
 * Get the package version of a buffer.
 *
 * @param buf the package buffer
 * @param size the package buffer size
 *
 * @return the package version, return zero if the version is unknown
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_get_file_package_version(const uint8_t *buf, uint32_t size);

/**
 * Get the package version of a module
 *
 * @param module the module
 *
 * @return the package version, or zero if version is unknown
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_get_module_package_version(const wasm_module_t module);

/**
 * Get the currently supported version of the package type
 *
 * @param package_type the package type
 *
 * @return the currently supported version, or zero if package type is unknown
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_get_current_package_version(package_type_t package_type);

/**
 * Check whether a file is an AOT XIP (Execution In Place) file
 *
 * @param buf the package buffer
 * @param size the package buffer size
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_xip_file(const uint8_t *buf, uint32_t size);

/**
 * Callback to load a module file into a buffer in multi-module feature
 */
typedef bool (*module_reader)(package_type_t module_type,
                              const char *module_name, uint8_t **p_buffer,
                              uint32_t *p_size);

/**
 * Callback to release the buffer loaded by module_reader callback
 */
typedef void (*module_destroyer)(uint8_t *buffer, uint32_t size);

/**
 * Setup callbacks for reading and releasing a buffer about a module file
 *
 * @param reader a callback to read a module file into a buffer
 * @param destroyer a callback to release above buffer
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_module_reader(const module_reader reader,
                               const module_destroyer destroyer);
/**
 * Give the "module" a name "module_name".
 * Can not assign a new name to a module if it already has a name
 *
 * @param module_name indicate a name
 * @param module the target module
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return true means success, false means failed
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_register_module(const char *module_name, wasm_module_t module,
                             char *error_buf, uint32_t error_buf_size);

/**
 * Check if there is already a loaded module named module_name in the
 * runtime. Repeatedly loading a module with the same name is not allowed.
 *
 * @param module_name indicate a name
 *
 * @return return WASM module loaded, NULL if failed
 */
WASM_RUNTIME_API_EXTERN wasm_module_t
wasm_runtime_find_module_registered(const char *module_name);

/**
 * Load a WASM module from a specified byte buffer. The byte buffer can be
 * WASM binary data when interpreter or JIT is enabled, or AOT binary data
 * when AOT is enabled. If it is AOT binary data, it must be 4-byte aligned.
 *
 * Note: In case of AOT XIP modules, the runtime doesn't make modifications
 * to the buffer. (Except the "Known issues" mentioned in doc/xip.md.)
 * Otherwise, the runtime can make modifications to the buffer for its
 * internal purposes. Thus, in general, it isn't safe to create multiple
 * modules from a single buffer.
 *
 * @param buf the byte buffer which contains the WASM/AOT binary data,
 *        note that the byte buffer must be writable since runtime may
 *        change its content for footprint and performance purpose, and
 *        it must be referenceable until wasm_runtime_unload is called
 * @param size the size of the buffer
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return WASM module loaded, NULL if failed
 */
WASM_RUNTIME_API_EXTERN wasm_module_t
wasm_runtime_load(uint8_t *buf, uint32_t size, char *error_buf,
                  uint32_t error_buf_size);

/**
 * Load a WASM module with specified load argument.
 */
WASM_RUNTIME_API_EXTERN wasm_module_t
wasm_runtime_load_ex(uint8_t *buf, uint32_t size, const LoadArgs *args,
                     char *error_buf, uint32_t error_buf_size);

/**
 * Resolve symbols for a previously loaded WASM module. Only useful when the
 * module was loaded with LoadArgs::no_resolve set to true
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_resolve_symbols(wasm_module_t module);
/**
 * Load a WASM module from a specified WASM or AOT section list.
 *
 * @param section_list the section list which contains each section data
 * @param is_aot whether the section list is AOT section list
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return WASM module loaded, NULL if failed
 */
WASM_RUNTIME_API_EXTERN wasm_module_t
wasm_runtime_load_from_sections(wasm_section_list_t section_list, bool is_aot,
                                char *error_buf, uint32_t error_buf_size);

/**
 * Unload a WASM module.
 *
 * @param module the module to be unloaded
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_unload(wasm_module_t module);

/**
 * Get the module hash of a WASM module, currently only available on
 * linux-sgx platform when the remote attestation feature is enabled
 *
 * @param module the WASM module to retrieve
 *
 * @return the module hash of the WASM module
 */
char *
wasm_runtime_get_module_hash(wasm_module_t module);

/**
 * Set WASI parameters.
 *
 * While this API operates on a module, these parameters will be used
 * only when the module is instantiated. That is, you can consider these
 * as extra parameters for wasm_runtime_instantiate().
 *
 * @param module        The module to set WASI parameters.
 * @param dir_list      The list of directories to preopen. (real path)
 * @param dir_count     The number of elements in dir_list.
 * @param map_dir_list  The list of directories to preopen. (mapped path)
 *                      Format for each map entry: <guest-path>::<host-path>
 * @param map_dir_count The number of elements in map_dir_list.
 *                      If map_dir_count is smaller than dir_count,
 *                      mapped path is assumed to be same as the
 *                      corresponding real path for the rest of entries.
 * @param env           The list of environment variables.
 * @param env_count     The number of elements in env.
 * @param argv          The list of command line arguments.
 * @param argc          The number of elements in argv.
 * @param stdin_handle  The raw host handle to back WASI STDIN_FILENO.
 *                      If an invalid handle is specified (e.g. -1 on POSIX,
 *                      INVALID_HANDLE_VALUE on Windows), the platform default
 *                      for STDIN is used.
 * @param stdoutfd      The raw host handle to back WASI STDOUT_FILENO.
 *                      If an invalid handle is specified (e.g. -1 on POSIX,
 *                      INVALID_HANDLE_VALUE on Windows), the platform default
 *                      for STDOUT is used.
 * @param stderrfd      The raw host handle to back WASI STDERR_FILENO.
 *                      If an invalid handle is specified (e.g. -1 on POSIX,
 *                      INVALID_HANDLE_VALUE on Windows), the platform default
 *                      for STDERR is used.
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_args_ex(wasm_module_t module, const char *dir_list[],
                              uint32_t dir_count, const char *map_dir_list[],
                              uint32_t map_dir_count, const char *env[],
                              uint32_t env_count, char *argv[], int argc,
                              int64_t stdinfd, int64_t stdoutfd,
                              int64_t stderrfd);

/**
 * Set WASI parameters.
 *
 * Same as wasm_runtime_set_wasi_args_ex but with default stdio handles
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_args(wasm_module_t module, const char *dir_list[],
                           uint32_t dir_count, const char *map_dir_list[],
                           uint32_t map_dir_count, const char *env[],
                           uint32_t env_count, char *argv[], int argc);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_addr_pool(wasm_module_t module, const char *addr_pool[],
                                uint32_t addr_pool_size);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_ns_lookup_pool(wasm_module_t module,
                                     const char *ns_lookup_pool[],
                                     uint32_t ns_lookup_pool_size);

/**
 * Instantiate a WASM module.
 *
 * @param module the WASM module to instantiate
 * @param default_stack_size the default stack size of the module instance when
 *        the exec env's operation stack isn't created by user, e.g. API
 *        wasm_application_execute_main() and wasm_application_execute_func()
 *        create the operation stack internally with the stack size specified
 *        here. And API wasm_runtime_create_exec_env() creates the operation
 *        stack with stack size specified by its parameter, the stack size
 *        specified here is ignored.
 * @param host_managed_heap_size the default heap size of the module instance,
 *        a heap will be created besides the app memory space. Both wasm app
 *        and native function can allocate memory from the heap.
 * @param error_buf buffer to output the error info if failed
 * @param error_buf_size the size of the error buffer
 *
 * @return return the instantiated WASM module instance, NULL if failed
 */
WASM_RUNTIME_API_EXTERN wasm_module_inst_t
wasm_runtime_instantiate(const wasm_module_t module,
                         uint32_t default_stack_size,
                         uint32_t host_managed_heap_size, char *error_buf,
                         uint32_t error_buf_size);

/**
 * Instantiate a WASM module, with specified instantiation arguments
 *
 * Same as wasm_runtime_instantiate, but it also allows overwriting maximum
 * memory
 */
WASM_RUNTIME_API_EXTERN wasm_module_inst_t
wasm_runtime_instantiate_ex(const wasm_module_t module,
                            const InstantiationArgs *args, char *error_buf,
                            uint32_t error_buf_size);

/**
 * Create an InstantiationArgs2 object with default parameters.
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_instantiation_args_create(struct InstantiationArgs2 **p);

/**
 * Dispose an InstantiationArgs2 object.
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_instantiation_args_destroy(struct InstantiationArgs2 *p);

/**
 * Setter functions for the InstantiationArgs2 object.
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_instantiation_args_set_default_stack_size(
    struct InstantiationArgs2 *p, uint32_t v);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_instantiation_args_set_host_managed_heap_size(
    struct InstantiationArgs2 *p, uint32_t v);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_instantiation_args_set_max_memory_pages(
    struct InstantiationArgs2 *p, uint32_t v);

/**
 * Instantiate a WASM module, with specified instantiation arguments
 *
 * Same as wasm_runtime_instantiate_ex, but this version takes
 * InstantiationArgs2, which can be extended without breaking the ABI.
 */
WASM_RUNTIME_API_EXTERN wasm_module_inst_t
wasm_runtime_instantiate_ex2(const wasm_module_t module,
                             const struct InstantiationArgs2 *args,
                             char *error_buf, uint32_t error_buf_size);

/**
 * Set the running mode of a WASM module instance, override the
 * default running mode of the runtime. Note that it only makes sense when
 * the input is a wasm bytecode file: for the AOT file, runtime always runs
 * it with AOT engine, and this function always returns true.
 *
 * @param module_inst the WASM module instance to set running mode
 * @param running_mode the running mode to set
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_set_running_mode(wasm_module_inst_t module_inst,
                              RunningMode running_mode);

/**
 * Get the running mode of a WASM module instance, if no running mode
 * is explicitly set the default running mode of runtime will
 * be used and returned. Note that it only makes sense when the input is a
 * wasm bytecode file: for the AOT file, this function always returns 0.
 *
 * @param module_inst the WASM module instance to query for running mode
 *
 * @return the running mode this module instance currently use
 */
WASM_RUNTIME_API_EXTERN RunningMode
wasm_runtime_get_running_mode(wasm_module_inst_t module_inst);

/**
 * Deinstantiate a WASM module instance, destroy the resources.
 *
 * @param module_inst the WASM module instance to destroy
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_deinstantiate(wasm_module_inst_t module_inst);

/**
 * Get WASM module from WASM module instance
 *
 * @param module_inst the WASM module instance to retrieve
 *
 * @return the WASM module
 */
WASM_RUNTIME_API_EXTERN wasm_module_t
wasm_runtime_get_module(wasm_module_inst_t module_inst);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_wasi_mode(wasm_module_inst_t module_inst);

WASM_RUNTIME_API_EXTERN wasm_function_inst_t
wasm_runtime_lookup_wasi_start_function(wasm_module_inst_t module_inst);

/**
 * Get WASI exit code.
 *
 * After a WASI command completed its execution, an embedder can
 * call this function to get its exit code. (that is, the value given
 * to proc_exit.)
 *
 * @param module_inst the module instance
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_get_wasi_exit_code(wasm_module_inst_t module_inst);

/**
 * Lookup an exported function in the WASM module instance.
 *
 * @param module_inst the module instance
 * @param name the name of the function
 *
 * @return the function instance found, NULL if not found
 */
WASM_RUNTIME_API_EXTERN wasm_function_inst_t
wasm_runtime_lookup_function(const wasm_module_inst_t module_inst,
                             const char *name);

/**
 * Get parameter count of the function instance
 *
 * @param func_inst the function instance
 * @param module_inst the module instance the function instance belongs to
 *
 * @return the parameter count of the function instance
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_func_get_param_count(const wasm_function_inst_t func_inst,
                          const wasm_module_inst_t module_inst);

/**
 * Get result count of the function instance
 *
 * @param func_inst the function instance
 * @param module_inst the module instance the function instance belongs to
 *
 * @return the result count of the function instance
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_func_get_result_count(const wasm_function_inst_t func_inst,
                           const wasm_module_inst_t module_inst);

/**
 * Get parameter types of the function instance
 *
 * @param func_inst the function instance
 * @param module_inst the module instance the function instance belongs to
 * @param param_types the parameter types returned
 */
WASM_RUNTIME_API_EXTERN void
wasm_func_get_param_types(const wasm_function_inst_t func_inst,
                          const wasm_module_inst_t module_inst,
                          wasm_valkind_t *param_types);

/**
 * Get result types of the function instance
 *
 * @param func_inst the function instance
 * @param module_inst the module instance the function instance belongs to
 * @param result_types the result types returned
 */
WASM_RUNTIME_API_EXTERN void
wasm_func_get_result_types(const wasm_function_inst_t func_inst,
                           const wasm_module_inst_t module_inst,
                           wasm_valkind_t *result_types);

/**
 * Create execution environment for a WASM module instance.
 *
 * @param module_inst the module instance
 * @param stack_size the stack size to execute a WASM function
 *
 * @return the execution environment, NULL if failed, e.g. invalid
 *         stack size is passed
 */
WASM_RUNTIME_API_EXTERN wasm_exec_env_t
wasm_runtime_create_exec_env(wasm_module_inst_t module_inst,
                             uint32_t stack_size);

/**
 * Destroy the execution environment.
 *
 * @param exec_env the execution environment to destroy
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy_exec_env(wasm_exec_env_t exec_env);

/**
 * @brief Copy callstack frames.
 *
 * Caution: This is not a thread-safe function. Ensure the exec_env
 * is suspended before calling it from another thread.
 *
 * Usage: In the callback to read frames fields use APIs
 * for wasm_frame_t from wasm_c_api.h
 *
 * Note: The function is async-signal-safe if called with verified arguments.
 * Meaning it's safe to call it from a signal handler even on a signal
 * interruption from another thread if next variables hold valid pointers
 * - exec_env
 * - exec_env->module_inst
 * - exec_env->module_inst->module
 *
 * @param exec_env the execution environment that containes frames
 * @param buffer the buffer of size equal length * sizeof(wasm_frame_t) to copy
 * frames to
 * @param length the number of frames to copy
 * @param skip_n the number of frames to skip from the top of the stack
 *
 * @return number of copied frames
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_copy_callstack(const wasm_exec_env_t exec_env, WASMCApiFrame *buffer,
                    const uint32_t length, const uint32_t skip_n,
                    char *error_buf, uint32_t error_buf_size);

/**
 * Get the singleton execution environment for the instance.
 *
 * Note: The singleton execution environment is the execution
 * environment used internally by the runtime for the API functions
 * like wasm_application_execute_main, which don't take explicit
 * execution environment. It's associated to the corresponding
 * module instance and managed by the runtime. The API user should
 * not destroy it with wasm_runtime_destroy_exec_env.
 *
 * @param module_inst the module instance
 *
 * @return exec_env the execution environment to destroy
 */
WASM_RUNTIME_API_EXTERN wasm_exec_env_t
wasm_runtime_get_exec_env_singleton(wasm_module_inst_t module_inst);

/**
 * Start debug instance based on given execution environment.
 * Note:
 *   The debug instance will be destroyed during destroying the
 *   execution environment, developers don't need to destroy it
 *   manually.
 *   If the cluster of this execution environment has already
 *   been bound to a debug instance, this function will return true
 *   directly.
 *   If developer spawns some exec_env by wasm_runtime_spawn_exec_env,
 *   don't need to call this function for every spawned exec_env as
 *   they are sharing the same cluster with the main exec_env.
 *
 * @param exec_env the execution environment to start debug instance
 * @param port     the port for the debug server to listen on.
 *                 0 means automatic assignment.
 *                 -1 means to use the global setting in RuntimeInitArgs.
 *
 * @return debug port if success, 0 otherwise.
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_start_debug_instance_with_port(wasm_exec_env_t exec_env,
                                            int32_t port);

/**
 * Same as wasm_runtime_start_debug_instance_with_port(env, -1).
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_start_debug_instance(wasm_exec_env_t exec_env);

/**
 * Initialize the thread environment.
 * Note:
 *   If developer creates a child thread by himself to call the
 *   the wasm function in that thread, he should call this API
 *   firstly before calling the wasm function and then call
 *   wasm_runtime_destroy_thread_env() after calling the wasm
 *   function. If the thread is created from the runtime API,
 *   it is unnecessary to call these two APIs.
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_init_thread_env(void);

/**
 * Destroy the thread environment
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy_thread_env(void);

/**
 * Whether the thread environment is initialized
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_thread_env_inited(void);

/**
 * Get WASM module instance from execution environment
 *
 * @param exec_env the execution environment to retrieve
 *
 * @return the WASM module instance
 */
WASM_RUNTIME_API_EXTERN wasm_module_inst_t
wasm_runtime_get_module_inst(wasm_exec_env_t exec_env);

/**
 * Set WASM module instance of execution environment
 * Caution:
 *   normally the module instance is bound with the execution
 *   environment one by one, if multiple module instances want
 *   to share to the same execution environment, developer should
 *   be responsible for the backup and restore of module instance
 *
 * @param exec_env the execution environment
 * @param module_inst the WASM module instance to set
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_module_inst(wasm_exec_env_t exec_env,
                             const wasm_module_inst_t module_inst);

/**
 * @brief Lookup a memory instance by name
 *
 * @param module_inst The module instance
 * @param name The name of the memory instance
 *
 * @return The memory instance if found, NULL otherwise
 */
WASM_RUNTIME_API_EXTERN wasm_memory_inst_t
wasm_runtime_lookup_memory(const wasm_module_inst_t module_inst,
                           const char *name);

/**
 * @brief Get the default memory instance
 *
 * @param module_inst The module instance
 *
 * @return The memory instance if found, NULL otherwise
 */
WASM_RUNTIME_API_EXTERN wasm_memory_inst_t
wasm_runtime_get_default_memory(const wasm_module_inst_t module_inst);

/**
 * @brief Get a memory instance by index
 *
 * @param module_inst The module instance
 * @param index The index of the memory instance
 *
 * @return The memory instance if found, NULL otherwise
 */
WASM_RUNTIME_API_EXTERN wasm_memory_inst_t
wasm_runtime_get_memory(const wasm_module_inst_t module_inst, uint32_t index);

/**
 * @brief Get the current number of pages for a memory instance
 *
 * @param memory_inst The memory instance
 *
 * @return The current number of pages
 */
WASM_RUNTIME_API_EXTERN uint64_t
wasm_memory_get_cur_page_count(const wasm_memory_inst_t memory_inst);

/**
 * @brief Get the maximum number of pages for a memory instance
 *
 * @param memory_inst The memory instance
 *
 * @return The maximum number of pages
 */
WASM_RUNTIME_API_EXTERN uint64_t
wasm_memory_get_max_page_count(const wasm_memory_inst_t memory_inst);

/**
 * @brief Get the number of bytes per page for a memory instance
 *
 * @param memory_inst The memory instance
 *
 * @return The number of bytes per page
 */
WASM_RUNTIME_API_EXTERN uint64_t
wasm_memory_get_bytes_per_page(const wasm_memory_inst_t memory_inst);

/**
 * @brief Get the shared status for a memory instance
 *
 * @param memory_inst The memory instance
 *
 * @return True if shared, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_memory_get_shared(const wasm_memory_inst_t memory_inst);

/**
 * @brief Get the base address for a memory instance
 *
 * @param memory_inst The memory instance
 *
 * @return The base address on success, false otherwise
 */
WASM_RUNTIME_API_EXTERN void *
wasm_memory_get_base_address(const wasm_memory_inst_t memory_inst);

/**
 * @brief Enlarge a memory instance by a number of pages
 *
 * @param memory_inst The memory instance
 * @param inc_page_count The number of pages to add
 *
 * @return True if successful, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_memory_enlarge(wasm_memory_inst_t memory_inst, uint64_t inc_page_count);

/**
 * Call the given WASM function of a WASM module instance with
 * arguments (bytecode and AoT).
 *
 * @param exec_env the execution environment to call the function,
 *   which must be created from wasm_create_exec_env()
 * @param function the function to call
 * @param argc total cell number that the function parameters occupy,
 *   a cell is a slot of the uint32 array argv[], e.g. i32/f32 argument
 *   occupies one cell, i64/f64 argument occupies two cells, note that
 *   it might be different from the parameter number of the function
 * @param argv the arguments. If the function has return value,
 *   the first (or first two in case 64-bit return value) element of
 *   argv stores the return value of the called WASM function after this
 *   function returns.
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call wasm_runtime_get_exception to get the exception
 *   info.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_wasm(wasm_exec_env_t exec_env, wasm_function_inst_t function,
                       uint32_t argc, uint32_t argv[]);

/**
 * Call the given WASM function of a WASM module instance with
 * provided results space and arguments (bytecode and AoT).
 *
 * @param exec_env the execution environment to call the function,
 *   which must be created from wasm_create_exec_env()
 * @param function the function to call
 * @param num_results the number of results
 * @param results the pre-alloced pointer to get the results
 * @param num_args the number of arguments
 * @param args the arguments
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call wasm_runtime_get_exception to get the exception
 *   info.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_wasm_a(wasm_exec_env_t exec_env,
                         wasm_function_inst_t function, uint32_t num_results,
                         wasm_val_t results[], uint32_t num_args,
                         wasm_val_t *args);

/**
 * Call the given WASM function of a WASM module instance with
 * provided results space and variant arguments (bytecode and AoT).
 *
 * @param exec_env the execution environment to call the function,
 *   which must be created from wasm_create_exec_env()
 * @param function the function to call
 * @param num_results the number of results
 * @param results the pre-alloced pointer to get the results
 * @param num_args the number of arguments
 * @param ... the variant arguments
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call wasm_runtime_get_exception to get the exception
 *   info.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_wasm_v(wasm_exec_env_t exec_env,
                         wasm_function_inst_t function, uint32_t num_results,
                         wasm_val_t results[], uint32_t num_args, ...);

/**
 * Call a function reference of a given WASM runtime instance with
 * arguments.
 *
 * Note: this can be used to call a function which is not exported
 * by the module explicitly. You might consider it as an abstraction
 * violation.
 *
 * @param exec_env the execution environment to call the function
 *   which must be created from wasm_create_exec_env()
 * @param element_index the function reference index, usually
 *   provided by the caller of a registered native function
 * @param argc the number of arguments
 * @param argv the arguments.  If the function method has return value,
 *   the first (or first two in case 64-bit return value) element of
 *   argv stores the return value of the called WASM function after this
 *   function returns.
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call wasm_runtime_get_exception to get exception info.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_indirect(wasm_exec_env_t exec_env, uint32_t element_index,
                           uint32_t argc, uint32_t argv[]);

/**
 * Find the unique main function from a WASM module instance
 * and execute that function.
 *
 * @param module_inst the WASM module instance
 * @param argc the number of arguments
 * @param argv the arguments array, if the main function has return value,
 *   *(int*)argv stores the return value of the called main function after
 *   this function returns.
 *
 * @return true if the main function is called, false otherwise and exception
 *   will be thrown, the caller can call wasm_runtime_get_exception to get
 *   the exception info.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_application_execute_main(wasm_module_inst_t module_inst, int32_t argc,
                              char *argv[]);

/**
 * Find the specified function from a WASM module instance and execute
 * that function.
 *
 * @param module_inst the WASM module instance
 * @param name the name of the function to execute.
 *  to indicate the module name via: $module_name$function_name
 *  or just a function name: function_name
 * @param argc the number of arguments
 * @param argv the arguments array
 *
 * @return true if the specified function is called, false otherwise and
 *   exception will be thrown, the caller can call wasm_runtime_get_exception
 *   to get the exception info.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_application_execute_func(wasm_module_inst_t module_inst, const char *name,
                              int32_t argc, char *argv[]);

/**
 * Get exception info of the WASM module instance.
 *
 * @param module_inst the WASM module instance
 *
 * @return the exception string
 */
WASM_RUNTIME_API_EXTERN const char *
wasm_runtime_get_exception(wasm_module_inst_t module_inst);

/**
 * Set exception info of the WASM module instance.
 *
 * @param module_inst the WASM module instance
 *
 * @param exception the exception string
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_exception(wasm_module_inst_t module_inst,
                           const char *exception);

/**
 * Clear exception info of the WASM module instance.
 *
 * @param module_inst the WASM module instance
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_clear_exception(wasm_module_inst_t module_inst);

/**
 * Terminate the WASM module instance.
 *
 * This function causes the module instance fail as if it raised a trap.
 *
 * This is intended to be used in situations like:
 *
 *  - A thread is executing the WASM module instance
 *    (eg. it's in the middle of `wasm_application_execute_main`)
 *
 *  - Another thread has a copy of `wasm_module_inst_t` of
 *    the module instance and wants to terminate it asynchronously.
 *
 * @param module_inst the WASM module instance
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_terminate(wasm_module_inst_t module_inst);

/**
 * Set custom data to WASM module instance.
 * Note:
 *  If WAMR_BUILD_LIB_PTHREAD is enabled, this API
 *  will spread the custom data to all threads
 *
 * @param module_inst the WASM module instance
 * @param custom_data the custom data to be set
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_custom_data(wasm_module_inst_t module_inst, void *custom_data);

/**
 * Get the custom data within a WASM module instance.
 *
 * @param module_inst the WASM module instance
 *
 * @return the custom data (NULL if not set yet)
 */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_custom_data(wasm_module_inst_t module_inst);

/**
 * Set the memory bounds checks flag of a WASM module instance.
 *
 * @param module_inst the WASM module instance
 * @param enable the flag to enable/disable the memory bounds checks
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_bounds_checks(wasm_module_inst_t module_inst, bool enable);

/**
 * Check if the memory bounds checks flag is enabled for a WASM module instance.
 *
 * @param module_inst the WASM module instance
 * @return true if the memory bounds checks flag is enabled, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_bounds_checks_enabled(wasm_module_inst_t module_inst);

/**
 * Allocate memory from the heap of WASM module instance
 *
 * Note: wasm_runtime_module_malloc can call heap functions inside
 * the module instance and thus cause a memory growth.
 * This API needs to be used very carefully when you have a native
 * pointers to the module instance memory obtained with
 * wasm_runtime_addr_app_to_native or similar APIs.
 *
 * @param module_inst the WASM module instance which contains heap
 * @param size the size bytes to allocate
 * @param p_native_addr return native address of the allocated memory
 *        if it is not NULL, and return NULL if memory malloc failed
 *
 * @return the allocated memory address, which is a relative offset to the
 *         base address of the module instance's memory space. Note that
 *         it is not an absolute address.
 *         Return non-zero if success, zero if failed.
 */
WASM_RUNTIME_API_EXTERN uint64_t
wasm_runtime_module_malloc(wasm_module_inst_t module_inst, uint64_t size,
                           void **p_native_addr);

/**
 * Free memory to the heap of WASM module instance
 *
 * @param module_inst the WASM module instance which contains heap
 * @param ptr the pointer to free
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_module_free(wasm_module_inst_t module_inst, uint64_t ptr);

/**
 * Allocate memory from the heap of WASM module instance and initialize
 * the memory with src
 *
 * @param module_inst the WASM module instance which contains heap
 * @param src the source data to copy
 * @param size the size of the source data
 *
 * @return the allocated memory address, which is a relative offset to the
 *         base address of the module instance's memory space. Note that
 *         it is not an absolute address.
 *         Return non-zero if success, zero if failed.
 */
WASM_RUNTIME_API_EXTERN uint64_t
wasm_runtime_module_dup_data(wasm_module_inst_t module_inst, const char *src,
                             uint64_t size);

/**
 * Validate the app address, check whether it belongs to WASM module
 * instance's address space, or in its heap space or memory space.
 *
 * @param module_inst the WASM module instance
 * @param app_offset the app address to validate, which is a relative address
 * @param size the size bytes of the app address
 *
 * @return true if success, false otherwise. If failed, an exception will
 *         be thrown.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_validate_app_addr(wasm_module_inst_t module_inst,
                               uint64_t app_offset, uint64_t size);

/**
 * Similar to wasm_runtime_validate_app_addr(), except that the size parameter
 * is not provided. This function validates the app string address, check
 * whether it belongs to WASM module instance's address space, or in its heap
 * space or memory space. Moreover, it checks whether it is the offset of a
 * string that is end with '\0'.
 *
 * Note: The validation result, especially the NUL termination check,
 * is not reliable for a module instance with multiple threads because
 * other threads can modify the heap behind us.
 *
 * @param module_inst the WASM module instance
 * @param app_str_offset the app address of the string to validate, which is a
 *        relative address
 *
 * @return true if success, false otherwise. If failed, an exception will
 *         be thrown.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_validate_app_str_addr(wasm_module_inst_t module_inst,
                                   uint64_t app_str_offset);

/**
 * Validate the native address, check whether it belongs to WASM module
 * instance's address space, or in its heap space or memory space.
 *
 * @param module_inst the WASM module instance
 * @param native_ptr the native address to validate, which is an absolute
 *        address
 * @param size the size bytes of the app address
 *
 * @return true if success, false otherwise. If failed, an exception will
 *         be thrown.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_validate_native_addr(wasm_module_inst_t module_inst,
                                  void *native_ptr, uint64_t size);

/**
 * Convert app address (relative address) to native address (absolute address)
 *
 * Note that native addresses to module instance memory can be invalidated
 * on a memory growth. (Except shared memory, whose native addresses are
 * stable.)
 *
 * @param module_inst the WASM module instance
 * @param app_offset the app address
 *
 * @return the native address converted
 */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_addr_app_to_native(wasm_module_inst_t module_inst,
                                uint64_t app_offset);

/**
 * Convert native address (absolute address) to app address (relative address)
 *
 * @param module_inst the WASM module instance
 * @param native_ptr the native address
 *
 * @return the app address converted
 */
WASM_RUNTIME_API_EXTERN uint64_t
wasm_runtime_addr_native_to_app(wasm_module_inst_t module_inst,
                                void *native_ptr);

/**
 * Get the app address range (relative address) that a app address belongs to
 *
 * @param module_inst the WASM module instance
 * @param app_offset the app address to retrieve
 * @param p_app_start_offset buffer to output the app start offset if not NULL
 * @param p_app_end_offset buffer to output the app end offset if not NULL
 *
 * @return true if success, false otherwise.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_get_app_addr_range(wasm_module_inst_t module_inst,
                                uint64_t app_offset,
                                uint64_t *p_app_start_offset,
                                uint64_t *p_app_end_offset);

/**
 * Get the native address range (absolute address) that a native address
 * belongs to
 *
 * @param module_inst the WASM module instance
 * @param native_ptr the native address to retrieve
 * @param p_native_start_addr buffer to output the native start address
 *        if not NULL
 * @param p_native_end_addr buffer to output the native end address
 *        if not NULL
 *
 * @return true if success, false otherwise.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_get_native_addr_range(wasm_module_inst_t module_inst,
                                   uint8_t *native_ptr,
                                   uint8_t **p_native_start_addr,
                                   uint8_t **p_native_end_addr);

/**
 * Get the number of import items for a WASM module
 *
 * @param module the WASM module
 *
 * @return the number of imports (zero for none), or -1 for failure
 */
WASM_RUNTIME_API_EXTERN int32_t
wasm_runtime_get_import_count(const wasm_module_t module);

/**
 * Get information about a specific WASM module import
 *
 * @param module the WASM module
 * @param import_index the desired import index
 * @param import_type the location to store information about the import
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_get_import_type(const wasm_module_t module, int32_t import_index,
                             wasm_import_t *import_type);

/**
 * Get the number of export items for a WASM module
 *
 * @param module the WASM module
 *
 * @return the number of exports (zero for none), or -1 for failure
 */
WASM_RUNTIME_API_EXTERN int32_t
wasm_runtime_get_export_count(const wasm_module_t module);

/**
 * Get information about a specific WASM module export
 *
 * @param module the WASM module
 * @param export_index the desired export index
 * @param export_type the location to store information about the export
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_get_export_type(const wasm_module_t module, int32_t export_index,
                             wasm_export_t *export_type);

/**
 * Get the number of parameters for a function type
 *
 * @param func_type the function type
 *
 * @return the number of parameters for the function type
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_func_type_get_param_count(const wasm_func_type_t func_type);

/**
 * Get the kind of a parameter for a function type
 *
 * @param func_type the function type
 * @param param_index the index of the parameter to get
 *
 * @return the kind of the parameter if successful, -1 otherwise
 */
WASM_RUNTIME_API_EXTERN wasm_valkind_t
wasm_func_type_get_param_valkind(const wasm_func_type_t func_type,
                                 uint32_t param_index);

/**
 * Get the number of results for a function type
 *
 * @param func_type the function type
 *
 * @return the number of results for the function type
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_func_type_get_result_count(const wasm_func_type_t func_type);

/**
 * Get the kind of a result for a function type
 *
 * @param func_type the function type
 * @param result_index the index of the result to get
 *
 * @return the kind of the result if successful, -1 otherwise
 */
WASM_RUNTIME_API_EXTERN wasm_valkind_t
wasm_func_type_get_result_valkind(const wasm_func_type_t func_type,
                                  uint32_t result_index);

/**
 * Get the kind for a global type
 *
 * @param global_type the global type
 *
 * @return the kind of the global
 */
WASM_RUNTIME_API_EXTERN wasm_valkind_t
wasm_global_type_get_valkind(const wasm_global_type_t global_type);

/**
 * Get the mutability for a global type
 *
 * @param global_type the global type
 *
 * @return true if mutable, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_global_type_get_mutable(const wasm_global_type_t global_type);

/**
 * Get the shared setting for a memory type
 *
 * @param memory_type the memory type
 *
 * @return true if shared, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_memory_type_get_shared(const wasm_memory_type_t memory_type);

/**
 * Get the initial page count for a memory type
 *
 * @param memory_type the memory type
 *
 * @return the initial memory page count
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_memory_type_get_init_page_count(const wasm_memory_type_t memory_type);

/**
 * Get the maximum page count for a memory type
 *
 * @param memory_type the memory type
 *
 * @return the maximum memory page count
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_memory_type_get_max_page_count(const wasm_memory_type_t memory_type);

/**
 * Get the element kind for a table type
 *
 * @param table_type the table type
 *
 * @return the element kind
 */
WASM_RUNTIME_API_EXTERN wasm_valkind_t
wasm_table_type_get_elem_kind(const wasm_table_type_t table_type);

/**
 * Get the sharing setting for a table type
 *
 * @param table_type the table type
 *
 * @return true if shared, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_table_type_get_shared(const wasm_table_type_t table_type);

/**
 * Get the initial size for a table type
 *
 * @param table_type the table type
 *
 * @return the initial table size
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_table_type_get_init_size(const wasm_table_type_t table_type);

/**
 * Get the maximum size for a table type
 *
 * @param table_type the table type
 *
 * @return the maximum table size
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_table_type_get_max_size(const wasm_table_type_t table_type);

/**
 * Register native functions with same module name
 *
 * Note: The array `native_symbols` should not be read-only because the
 * library can modify it in-place.
 *
 * Note: After successful call of this function, the array `native_symbols`
 * is owned by the library.
 *
 * @param module_name the module name of the native functions
 * @param native_symbols specifies an array of NativeSymbol structures which
 *        contain the names, function pointers and signatures
 *        Note: WASM runtime will not allocate memory to clone the data, so
 *              user must ensure the array can be used forever
 *        Meanings of letters in function signature:
 *          'i': the parameter is i32 type
 *          'I': the parameter is i64 type
 *          'f': the parameter is f32 type
 *          'F': the parameter is f64 type
 *          'r': the parameter is externref type, it should be a uintptr_t
 *               in host
 *          '*': the parameter is a pointer (i32 in WASM), and runtime will
 *               auto check its boundary before calling the native function.
 *               If it is followed by '~', the checked length of the pointer
 *               is gotten from the following parameter, if not, the checked
 *               length of the pointer is 1.
 *          '~': the parameter is the pointer's length with i32 type, and must
 *               follow after '*'
 *          '$': the parameter is a string (i32 in WASM), and runtime will
 *               auto check its boundary before calling the native function
 * @param n_native_symbols specifies the number of native symbols in the array
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_register_natives(const char *module_name,
                              NativeSymbol *native_symbols,
                              uint32_t n_native_symbols);

/**
 * Register native functions with same module name, similar to
 *   wasm_runtime_register_natives, the difference is that runtime passes raw
 * arguments to native API, which means that the native API should be defined as
 *   void foo(wasm_exec_env_t exec_env, uint64 *args);
 * and native API should extract arguments one by one from args array with macro
 *   native_raw_get_arg
 * and write the return value back to args[0] with macro
 *   native_raw_return_type and native_raw_set_return
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_register_natives_raw(const char *module_name,
                                  NativeSymbol *native_symbols,
                                  uint32_t n_native_symbols);

/**
 * Undo wasm_runtime_register_natives or wasm_runtime_register_natives_raw
 *
 * @param module_name    Should be the same as the corresponding
 *                       wasm_runtime_register_natives.
 *                       (Same in term of strcmp.)
 *
 * @param native_symbols Should be the same as the corresponding
 *                       wasm_runtime_register_natives.
 *                       (Same in term of pointer comparison.)
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_unregister_natives(const char *module_name,
                                NativeSymbol *native_symbols);

/**
 * Get an export global instance
 *
 * @param module_inst the module instance
 * @param name the export global name
 * @param global_inst location to store the global instance
 *
 * @return true if success, false otherwise
 *
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_get_export_global_inst(const wasm_module_inst_t module_inst,
                                    const char *name,
                                    wasm_global_inst_t *global_inst);

/**
 * Get an export table instance
 *
 * @param module_inst the module instance
 * @param name the export table name
 * @param table_inst location to store the table instance
 *
 * @return true if success, false otherwise
 *
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_get_export_table_inst(const wasm_module_inst_t module_inst,
                                   const char *name,
                                   wasm_table_inst_t *table_inst);

/**
 * Get a function instance from a table.
 *
 * @param module_inst the module instance
 * @param table_inst the table instance
 * @param idx the index in the table
 *
 * @return the function instance if successful, NULL otherwise
 */
WASM_RUNTIME_API_EXTERN wasm_function_inst_t
wasm_table_get_func_inst(const wasm_module_inst_t module_inst,
                         const wasm_table_inst_t *table_inst, uint32_t idx);

/**
 * Get attachment of native function from execution environment
 *
 * @param exec_env the execution environment to retrieve
 *
 * @return the attachment of native function
 */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_function_attachment(wasm_exec_env_t exec_env);

/**
 * Set user data to execution environment.
 *
 * @param exec_env the execution environment
 * @param user_data the user data to be set
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_user_data(wasm_exec_env_t exec_env, void *user_data);

/**
 * Get the user data within execution environment.
 *
 * @param exec_env the execution environment
 *
 * @return the user data (NULL if not set yet)
 */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_user_data(wasm_exec_env_t exec_env);

/**
 * Set native stack boundary to execution environment, if it is set,
 * it will be used instead of getting the boundary with the platform
 * layer API when calling wasm functions. This is useful for some
 * fiber cases.
 *
 * Note: unlike setting the boundary by runtime, this API doesn't add
 * the WASM_STACK_GUARD_SIZE(see comments in core/config.h) to the
 * exec_env's native_stack_boundary to reserve bytes to the native
 * thread stack boundary, which is used to throw native stack overflow
 * exception if the guard boundary is reached. Developer should ensure
 * that enough guard bytes are kept.
 *
 * @param exec_env the execution environment
 * @param native_stack_boundary the user data to be set
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_native_stack_boundary(wasm_exec_env_t exec_env,
                                       uint8_t *native_stack_boundary);

/**
 * Set the instruction count limit to the execution environment.
 * By default the instruction count limit is -1, which means no limit.
 * However, if the instruction count limit is set to a positive value,
 * the execution will be terminated when the instruction count reaches
 * the limit.
 *
 * @param exec_env the execution environment
 * @param instruction_count the instruction count limit
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_instruction_count_limit(wasm_exec_env_t exec_env,
                                         int instruction_count);

/**
 * Dump runtime memory consumption, including:
 *     Exec env memory consumption
 *     WASM module memory consumption
 *     WASM module instance memory consumption
 *     stack and app heap used info
 *
 * @param exec_env the execution environment
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_dump_mem_consumption(wasm_exec_env_t exec_env);

/**
 * Dump runtime performance profiler data of each function
 *
 * @param module_inst the WASM module instance to profile
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_dump_perf_profiling(wasm_module_inst_t module_inst);

/**
 * Return total wasm functions' execution time in ms
 *
 * @param module_inst the WASM module instance to profile
 */
WASM_RUNTIME_API_EXTERN double
wasm_runtime_sum_wasm_exec_time(wasm_module_inst_t module_inst);

/**
 * Return execution time in ms of a given wasm function with
 * func_name. If the function is not found, return 0.
 *
 * @param module_inst the WASM module instance to profile
 * @param func_name could be an export name or a name in the
 *                  name section
 */
WASM_RUNTIME_API_EXTERN double
wasm_runtime_get_wasm_func_exec_time(wasm_module_inst_t inst,
                                     const char *func_name);

/* wasm thread callback function type */
typedef void *(*wasm_thread_callback_t)(wasm_exec_env_t, void *);
/* wasm thread type */
typedef uintptr_t wasm_thread_t;

/**
 * Set the max thread num per cluster.
 *
 * @param num maximum thread num
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_max_thread_num(uint32_t num);

/**
 * Spawn a new exec_env, the spawned exec_env
 *   can be used in other threads
 *
 * @param num the original exec_env
 *
 * @return the spawned exec_env if success, NULL otherwise
 */
WASM_RUNTIME_API_EXTERN wasm_exec_env_t
wasm_runtime_spawn_exec_env(wasm_exec_env_t exec_env);

/**
 * Destroy the spawned exec_env
 *
 * @param exec_env the spawned exec_env
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy_spawned_exec_env(wasm_exec_env_t exec_env);

/**
 * Spawn a thread from the given exec_env
 *
 * @param exec_env the original exec_env
 * @param tid thread id to be returned to the caller
 * @param callback the callback function provided by the user
 * @param arg the arguments passed to the callback
 *
 * @return 0 if success, -1 otherwise
 */
WASM_RUNTIME_API_EXTERN int32_t
wasm_runtime_spawn_thread(wasm_exec_env_t exec_env, wasm_thread_t *tid,
                          wasm_thread_callback_t callback, void *arg);

/**
 * Wait a spawned thread to terminate
 *
 * @param tid thread id
 * @param retval if not NULL, output the return value of the thread
 *
 * @return 0 if success, error number otherwise
 */
WASM_RUNTIME_API_EXTERN int32_t
wasm_runtime_join_thread(wasm_thread_t tid, void **retval);

/**
 * Map external object to an internal externref index: if the index
 *   has been created, return it, otherwise create the index.
 *
 * @param module_inst the WASM module instance that the extern object
 *        belongs to
 * @param extern_obj the external object to be mapped
 * @param p_externref_idx return externref index of the external object
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_obj2ref(wasm_module_inst_t module_inst, void *extern_obj,
                       uint32_t *p_externref_idx);

/**
 * Delete external object registered by `wasm_externref_obj2ref`.
 *
 * @param module_inst the WASM module instance that the extern object
 *        belongs to
 * @param extern_obj the external object to be deleted
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_objdel(wasm_module_inst_t module_inst, void *extern_obj);

/**
 * Set cleanup callback to release external object.
 *
 * @param module_inst the WASM module instance that the extern object
 *        belongs to
 * @param extern_obj the external object to which to set the
 *        `extern_obj_cleanup` cleanup callback.
 * @param extern_obj_cleanup a callback to release `extern_obj`
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_set_cleanup(wasm_module_inst_t module_inst, void *extern_obj,
                           void (*extern_obj_cleanup)(void *));

/**
 * Retrieve the external object from an internal externref index
 *
 * @param externref_idx the externref index to retrieve
 * @param p_extern_obj return the mapped external object of
 *        the externref index
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_ref2obj(uint32_t externref_idx, void **p_extern_obj);

/**
 * Retain an extern object which is mapped to the internal externref
 *   so that the object won't be cleaned during extern object reclaim
 *   if it isn't used.
 *
 * @param externref_idx the externref index of an external object
 *        to retain
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_retain(uint32_t externref_idx);

/**
 * Dump the call stack to stdout
 *
 * @param exec_env the execution environment
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_dump_call_stack(wasm_exec_env_t exec_env);

/**
 * Get the size required to store the call stack contents, including
 * the space for terminating null byte ('\0')
 *
 * @param exec_env the execution environment
 *
 * @return size required to store the contents, 0 means error
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_get_call_stack_buf_size(wasm_exec_env_t exec_env);

/**
 * Dump the call stack to buffer.
 *
 * @note this function is not thread-safe, please only use this API
 *       when the exec_env is not executing
 *
 * @param exec_env the execution environment
 * @param buf buffer to store the dumped content
 * @param len length of the buffer
 *
 * @return bytes dumped to the buffer, including the terminating null
 *         byte ('\0'), 0 means error and data in buf may be invalid
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_dump_call_stack_to_buf(wasm_exec_env_t exec_env, char *buf,
                                    uint32_t len);

/**
 * Get the size required to store the LLVM PGO profile data
 *
 * @param module_inst the WASM module instance
 *
 * @return size required to store the contents, 0 means error
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_get_pgo_prof_data_size(wasm_module_inst_t module_inst);

/**
 * Dump the LLVM PGO profile data to buffer
 *
 * @param module_inst the WASM module instance
 * @param buf buffer to store the dumped content
 * @param len length of the buffer
 *
 * @return bytes dumped to the buffer, 0 means error and data in buf
 *         may be invalid
 */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_dump_pgo_prof_data_to_buf(wasm_module_inst_t module_inst,
                                       char *buf, uint32_t len);

/**
 * Get a custom section by name
 *
 * @param module_comm the module to find
 * @param name name of the custom section
 * @param len return the length of the content if found
 *
 * @return Custom section content (not including the name length
 *         and name string) if found, NULL otherwise
 */
WASM_RUNTIME_API_EXTERN const uint8_t *
wasm_runtime_get_custom_section(const wasm_module_t module_comm,
                                const char *name, uint32_t *len);

/**
 * Get WAMR semantic version
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_get_version(uint32_t *major, uint32_t *minor, uint32_t *patch);

/**
 * Check whether an import func `(import <module_name> <func_name> (func ...))`
 * is linked or not with runtime registered native functions
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_import_func_linked(const char *module_name,
                                   const char *func_name);

/**
 * Check whether an import global `(import <module_name> <global_name>
 * (global ...))` is linked or not with runtime registered native globals
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_import_global_linked(const char *module_name,
                                     const char *global_name);

/**
 * Enlarge the memory region for a module instance
 *
 * @param module_inst the module instance
 * @param inc_page_count the number of pages to add
 *
 * @return true if success, false otherwise
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_enlarge_memory(wasm_module_inst_t module_inst,
                            uint64_t inc_page_count);

typedef enum {
    INTERNAL_ERROR,
    MAX_SIZE_REACHED,
} enlarge_memory_error_reason_t;

typedef void (*enlarge_memory_error_callback_t)(
    uint32_t inc_page_count, uint64_t current_memory_size,
    uint32_t memory_index, enlarge_memory_error_reason_t failure_reason,
    wasm_module_inst_t instance, wasm_exec_env_t exec_env, void *user_data);

/**
 * Setup callback invoked when memory.grow fails
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_enlarge_mem_error_callback(
    const enlarge_memory_error_callback_t callback, void *user_data);

/*
 * module instance context APIs
 *   wasm_runtime_create_context_key
 *   wasm_runtime_destroy_context_key
 *   wasm_runtime_set_context
 *   wasm_runtime_set_context_spread
 *   wasm_runtime_get_context
 *
 * This set of APIs is intended to be used by an embedder which provides
 * extra sets of native functions, which need per module instance state
 * and are maintained outside of the WAMR tree.
 *
 * It's modelled after the pthread specific API.
 *
 * wasm_runtime_set_context_spread is similar to
 * wasm_runtime_set_context, except that
 * wasm_runtime_set_context_spread applies the change
 * to all threads in the cluster.
 * It's an undefined behavior if multiple threads in a cluster call
 * wasm_runtime_set_context_spread on the same key
 * simultaneously. It's a caller's responsibility to perform necessary
 * serialization if necessary. For example:
 *
 * if (wasm_runtime_get_context(inst, key) == NULL) {
 *     newctx = alloc_and_init(...);
 *     lock(some_lock);
 *     if (wasm_runtime_get_context(inst, key) == NULL) {
 *         // this thread won the race
 *         wasm_runtime_set_context_spread(inst, key, newctx);
 *         newctx = NULL;
 *     }
 *     unlock(some_lock);
 *     if (newctx != NULL) {
 *         // this thread lost the race, free it
 *         cleanup_and_free(newctx);
 *     }
 * }
 *
 * Note: dynamic key create/destroy while instances are live is not
 * implemented as of writing this.
 * it's caller's responsibility to ensure destroying all module instances
 * before calling wasm_runtime_create_context_key or
 * wasm_runtime_destroy_context_key.
 * otherwise, it's an undefined behavior.
 *
 * Note about threads:
 * - When spawning a thread, the contexts (the pointers given to
 *   wasm_runtime_set_context) are copied from the parent
 *   instance.
 * - The destructor is called only on the main instance.
 */

WASM_RUNTIME_API_EXTERN void *
wasm_runtime_create_context_key(void (*dtor)(wasm_module_inst_t inst,
                                             void *ctx));

WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy_context_key(void *key);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_context(wasm_module_inst_t inst, void *key, void *ctx);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_context_spread(wasm_module_inst_t inst, void *key, void *ctx);

WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_context(wasm_module_inst_t inst, void *key);

/*
 * wasm_runtime_begin_blocking_op/wasm_runtime_end_blocking_op
 *
 * These APIs are intended to be used by the implementations of
 * host functions. It wraps an operation which possibly blocks for long
 * to prepare for async termination.
 *
 * For simplicity, we recommend to wrap only the very minimum piece of
 * the code with this. Ideally, just a single system call.
 *
 * eg.
 *
 *   if (!wasm_runtime_begin_blocking_op(exec_env)) {
 *       return EINTR;
 *   }
 *   ret = possibly_blocking_op();
 *   wasm_runtime_end_blocking_op(exec_env);
 *   return ret;
 *
 * If threading support (WASM_ENABLE_THREAD_MGR) is not enabled,
 * these functions are no-op.
 *
 * If the underlying platform support (OS_ENABLE_WAKEUP_BLOCKING_OP) is
 * not available, these functions are no-op. In that case, the runtime
 * might not terminate a blocking thread in a timely manner.
 *
 * If the underlying platform support is available, it's used to wake up
 * the thread for async termination. The expectation here is that a
 * `os_wakeup_blocking_op` call makes the blocking operation
 * (`possibly_blocking_op` in the above example) return in a timely manner.
 *
 * The actual wake up mechanism used by `os_wakeup_blocking_op` is
 * platform-dependent. It might impose some platform-dependent restrictions
 * on the implementation of the blocking operation.
 *
 * For example, on POSIX-like platforms, a signal (by default SIGUSR1) is
 * used. The signal delivery configurations (eg. signal handler, signal mask,
 * etc) for the signal are set up by the runtime. You can change the signal
 * to use for this purpose by calling os_set_signal_number_for_blocking_op
 * before the runtime initialization.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_begin_blocking_op(wasm_exec_env_t exec_env);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_end_blocking_op(wasm_exec_env_t exec_env);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_set_module_name(wasm_module_t module, const char *name,
                             char *error_buf, uint32_t error_buf_size);

/* return the most recently set module name or "" if never set before */
WASM_RUNTIME_API_EXTERN const char *
wasm_runtime_get_module_name(wasm_module_t module);

/*
 * wasm_runtime_detect_native_stack_overflow
 *
 * Detect native stack shortage.
 * Ensure that the calling thread still has a reasonable amount of
 * native stack (WASM_STACK_GUARD_SIZE bytes) available.
 *
 * If enough stack is left, this function returns true.
 * Otherwise, this function raises a "native stack overflow" trap and
 * returns false.
 *
 * Note: please do not expect a very strict detection. it's a good idea
 * to give some margins. wasm_runtime_detect_native_stack_overflow itself
 * requires a small amount of stack to run.
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_detect_native_stack_overflow(wasm_exec_env_t exec_env);

/*
 * wasm_runtime_detect_native_stack_overflow_size
 *
 * Similar to wasm_runtime_detect_native_stack_overflow,
 * but use the caller-specified size instead of WASM_STACK_GUARD_SIZE.
 *
 * An expected usage:
 * ```c
 * __attribute__((noinline))  // inlining can break the stack check
 * void stack_hog(void)
 * {
 *     // consume a lot of stack here
 * }
 *
 * void
 * stack_hog_wrapper(exec_env) {
 *     // the amount of stack stack_hog would consume,
 *     // plus a small margin
 *     uint32_t size = 10000000;
 *
 *     if (!wasm_runtime_detect_native_stack_overflow_size(exec_env, size)) {
 *         // wasm_runtime_detect_native_stack_overflow_size has raised
 *         // a trap.
 *         return;
 *     }
 *     stack_hog();
 * }
 * ```
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_detect_native_stack_overflow_size(wasm_exec_env_t exec_env,
                                               uint32_t required_size);

/**
 * Query whether the wasm binary buffer used to create the module can be freed
 *
 * @param module the target module
 * @return true if the wasm binary buffer can be freed
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_underlying_binary_freeable(const wasm_module_t module);

/**
 * Create a shared heap
 *
 * @param init_args the initialization arguments
 * @return the shared heap created
 */
WASM_RUNTIME_API_EXTERN wasm_shared_heap_t
wasm_runtime_create_shared_heap(SharedHeapInitArgs *init_args);

/**
 * This function links two shared heap(lists), `head` and `body` in to a single
 * shared heap list, where `head` becomes the new shared heap list head. The
 * shared heap list remains one continuous shared heap in wasm app's point of
 * view.  At most one shared heap in shared heap list can be dynamically
 * allocated, the rest have to be the pre-allocated shared heap. *
 *
 * @param head The head of the shared heap chain.
 * @param body The body of the shared heap chain to be appended.
 * @return The new head of the shared heap chain. NULL if failed.
 */
WASM_RUNTIME_API_EXTERN wasm_shared_heap_t
wasm_runtime_chain_shared_heaps(wasm_shared_heap_t head,
                                wasm_shared_heap_t body);

/**
 * This function unchains the shared heaps from the given head. If
 * `entire_chain` is true, it will unchain the entire chain of shared heaps.
 * Otherwise, it will unchain only the first shared heap in the chain.
 *
 * @param head The head of the shared heap chain.
 * @param entire_chain A boolean flag indicating whether to unchain the entire
 * chain.
 * @return The new head of the shared heap chain. Or the last shared heap in the
 * chain if `entire_chain` is true.
 */
wasm_shared_heap_t
wasm_runtime_unchain_shared_heaps(wasm_shared_heap_t head, bool entire_chain);

/**
 * Attach a shared heap, it can be the head of shared heap chain, in that case,
 * attach the shared heap chain, to a module instance
 *
 * @param module_inst the module instance
 * @param shared_heap the shared heap
 * @return true if success, false if failed
 */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_attach_shared_heap(wasm_module_inst_t module_inst,
                                wasm_shared_heap_t shared_heap);

/**
 * Detach a shared heap from a module instance
 *
 * @param module_inst the module instance
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_detach_shared_heap(wasm_module_inst_t module_inst);

/**
 * Allocate memory from a shared heap, or the non-preallocated shared heap from
 * the shared heap chain
 *
 * @param module_inst the module instance
 * @param size required memory size
 * @param p_native_addr native address of allocated memory
 *
 * @return return the allocated memory address, which reuses part of the wasm
 * address space and is in the range of [UINT32 - shared_heap_size + 1, UINT32]
 * (when the wasm memory is 32-bit) or [UINT64 - shared_heap_size + 1, UINT64]
 * (when the wasm memory is 64-bit). Note that it is not an absolute address.
 *         Return non-zero if success, zero if failed.
 */
WASM_RUNTIME_API_EXTERN uint64_t
wasm_runtime_shared_heap_malloc(wasm_module_inst_t module_inst, uint64_t size,
                                void **p_native_addr);

/**
 * Free the memory allocated from shared heap, or the non-preallocated shared
 * heap from the shared heap chain
 *
 * @param module_inst the module instance
 * @param ptr the offset in wasm app
 */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_shared_heap_free(wasm_module_inst_t module_inst, uint64_t ptr);

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_EXPORT_H */
