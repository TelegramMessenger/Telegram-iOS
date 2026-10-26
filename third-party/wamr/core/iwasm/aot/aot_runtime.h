/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _AOT_RUNTIME_H_
#define _AOT_RUNTIME_H_

#include "bh_platform.h"
#include "../common/wasm_runtime_common.h"
#include "../interpreter/wasm_runtime.h"
#include "../compilation/aot.h"
#if WASM_ENABLE_GC != 0
#include "gc_export.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Wasm feature supported, mainly used by AOTTargetInfo now */
#define WASM_FEATURE_SIMD_128BIT (1 << 0)
#define WASM_FEATURE_BULK_MEMORY (1 << 1)
#define WASM_FEATURE_MULTI_THREAD (1 << 2)
#define WASM_FEATURE_REF_TYPES (1 << 3)
#define WASM_FEATURE_GARBAGE_COLLECTION (1 << 4)
#define WASM_FEATURE_EXCEPTION_HANDLING (1 << 5)
#define WASM_FEATURE_TINY_STACK_FRAME (1 << 6)
#define WASM_FEATURE_MULTI_MEMORY (1 << 7)
#define WASM_FEATURE_DYNAMIC_LINKING (1 << 8)
#define WASM_FEATURE_COMPONENT_MODEL (1 << 9)
#define WASM_FEATURE_RELAXED_SIMD (1 << 10)
#define WASM_FEATURE_FLEXIBLE_VECTORS (1 << 11)
/* Stack frame is created at the beginning of the function,
 * and not at the beginning of each function call */
#define WASM_FEATURE_FRAME_PER_FUNCTION (1 << 12)
#define WASM_FEATURE_FRAME_NO_FUNC_IDX (1 << 13)

typedef enum AOTSectionType {
    AOT_SECTION_TYPE_TARGET_INFO = 0,
    AOT_SECTION_TYPE_INIT_DATA = 1,
    AOT_SECTION_TYPE_TEXT = 2,
    AOT_SECTION_TYPE_FUNCTION = 3,
    AOT_SECTION_TYPE_EXPORT = 4,
    AOT_SECTION_TYPE_RELOCATION = 5,
    /*
     * Note: We haven't had anything to use AOT_SECTION_TYPE_SIGNATURE.
     * It's just reserved for possible module signing features.
     */
    AOT_SECTION_TYPE_SIGNATURE = 6,
    AOT_SECTION_TYPE_CUSTOM = 100,
} AOTSectionType;

typedef enum AOTCustomSectionType {
    AOT_CUSTOM_SECTION_RAW = 0,
    AOT_CUSTOM_SECTION_NATIVE_SYMBOL = 1,
    AOT_CUSTOM_SECTION_ACCESS_CONTROL = 2,
    AOT_CUSTOM_SECTION_NAME = 3,
    AOT_CUSTOM_SECTION_STRING_LITERAL = 4,
} AOTCustomSectionType;

typedef struct AOTObjectDataSection {
    char *name;
    uint8 *data;
    uint32 size;
#if WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0
    bool is_name_allocated;
    bool is_data_allocated;
#endif
} AOTObjectDataSection;

/* Relocation info */
typedef struct AOTRelocation {
    uint64 relocation_offset;
    int64 relocation_addend;
    uint32 relocation_type;
    char *symbol_name;
    /* index in the symbol offset field */
    uint32 symbol_index;
#if WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0
    bool is_symbol_name_allocated;
#endif
} AOTRelocation;

/* Relocation Group */
typedef struct AOTRelocationGroup {
    char *section_name;
    /* index in the symbol offset field */
    uint32 name_index;
    uint32 relocation_count;
    AOTRelocation *relocations;
#if WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0
    bool is_section_name_allocated;
#endif
} AOTRelocationGroup;

/* AOT function instance */
typedef struct AOTFunctionInstance {
    char *func_name;
    uint32 func_index;
    bool is_import_func;
    union {
        struct {
            AOTFuncType *func_type;
            /* function pointer linked */
            void *func_ptr;
        } func;
        AOTImportFunc *func_import;
    } u;
} AOTFunctionInstance;

/* Map of a function index to the element ith in
   the export functions array */
typedef struct ExportFuncMap {
    uint32 func_idx;
    uint32 export_idx;
} ExportFuncMap;

typedef struct AOTModuleInstanceExtra {
    DefPointer(const uint32 *, stack_sizes);
    /*
     * Adjusted shared heap based addr to simple the calculation
     * in the aot code. The value is:
     *   shared_heap->base_addr - shared_heap->start_off
     */
    DefPointer(uint8 *, shared_heap_base_addr_adj);
    MemBound shared_heap_start_off;
    MemBound shared_heap_end_off;
    DefPointer(WASMSharedHeap *, shared_heap);

    WASMModuleInstanceExtraCommon common;

    /**
     * maps of func indexes to export func indexes, which
     * is sorted by func index for a quick lookup and is
     * created only when first time used.
     */
    ExportFuncMap *export_func_maps;
    AOTFunctionInstance **functions;
    uint32 function_count;
#if WASM_ENABLE_MULTI_MODULE != 0
    bh_list sub_module_inst_list_head;
    bh_list *sub_module_inst_list;
    WASMModuleInstanceCommon **import_func_module_insts;
#endif

} AOTModuleInstanceExtra;

#if defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64)
typedef struct GOTItem {
    uint32 func_idx;
    struct GOTItem *next;
} GOTItem, *GOTItemList;
#endif

#if WASM_ENABLE_GC != 0
typedef struct LocalRefFlag {
    uint32 local_ref_flag_cell_num;
    uint8 *local_ref_flags;
} LocalRefFlag;
#endif

typedef struct AOTModule {
    uint32 module_type;

    /* the package version read from the AOT file */
    uint32 package_version;

    /* import memories */
    uint32 import_memory_count;
    AOTImportMemory *import_memories;

    /* memory info */
    uint32 memory_count;
    AOTMemory *memories;

    /* init data */
    uint32 mem_init_data_count;
    AOTMemInitData **mem_init_data_list;

    /* native symbol */
    void **native_symbol_list;

    /* import tables */
    uint32 import_table_count;
    AOTImportTable *import_tables;

    /* tables */
    uint32 table_count;
    AOTTable *tables;

    /* table init data info */
    uint32 table_init_data_count;
    AOTTableInitData **table_init_data_list;

    /* type info */
    uint32 type_count;
    AOTType **types;

    /* import global variable info */
    uint32 import_global_count;
    AOTImportGlobal *import_globals;

    /* global variable info */
    uint32 global_count;
    AOTGlobal *globals;

    /* total global variable size */
    uint32 global_data_size;

    /* import function info */
    uint32 import_func_count;
    AOTImportFunc *import_funcs;

    /* function info */
    uint32 func_count;
    /* func pointers of AOTed (un-imported) functions */
    void **func_ptrs;
    /* func type indexes of AOTed (un-imported) functions */
    uint32 *func_type_indexes;
#if WASM_ENABLE_AOT_STACK_FRAME != 0
    /* max local cell nums of AOTed (un-imported) functions */
    uint32 *max_local_cell_nums;
    /* max stack cell nums of AOTed (un-imported) functions */
    uint32 *max_stack_cell_nums;
#endif

#if WASM_ENABLE_GC != 0
    /* params + locals ref flags of (both import and AOTed) functions */
    LocalRefFlag *func_local_ref_flags;
#endif

    /* export info */
    uint32 export_count;
    AOTExport *exports;

    /* start function index, -1 denotes no start function */
    uint32 start_func_index;
    /* start function, point to AOTed function */
    void *start_function;

    uint32 malloc_func_index;
    uint32 free_func_index;
    uint32 retain_func_index;

    /* AOTed code */
    void *code;
    uint32 code_size;

    /* literal for AOTed code */
    uint8 *literal;
    uint32 literal_size;

#if defined(BH_PLATFORM_WINDOWS)
    /* extra plt data area for __ymm, __xmm and __real constants
       in Windows platform */
    uint8 *extra_plt_data;
    uint32 extra_plt_data_size;
    uint32 ymm_plt_count;
    uint32 xmm_plt_count;
    uint32 real_plt_count;
    uint32 float_plt_count;
#endif

#if defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64)
    uint32 got_item_count;
    GOTItemList got_item_list;
    GOTItemList got_item_list_end;
    void **got_func_ptrs;
#endif

    /* data sections in AOT object file, including .data, .rodata
       and .rodata.cstN. */
    AOTObjectDataSection *data_sections;
    uint32 data_section_count;

    /* constant string set */
    HashMap *const_str_set;

    /* the index of auxiliary __data_end global,
       -1 means unexported */
    uint32 aux_data_end_global_index;
    /* auxiliary __data_end exported by wasm app */
    uint64 aux_data_end;

    /* the index of auxiliary __heap_base global,
       -1 means unexported */
    uint32 aux_heap_base_global_index;
    /* auxiliary __heap_base exported by wasm app */
    uint64 aux_heap_base;

    /* the index of auxiliary stack top global,
       -1 means unexported */
    uint32 aux_stack_top_global_index;
    /* auxiliary stack bottom resolved */
    uint64 aux_stack_bottom;
    /* auxiliary stack size resolved */
    uint32 aux_stack_size;

    /* is indirect mode or not */
    bool is_indirect_mode;

#if WASM_ENABLE_LIBC_WASI != 0
    WASIArguments wasi_args;
    bool import_wasi_api;
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
    /* TODO: add mutex for mutli-thread? */
    bh_list import_module_list_head;
    bh_list *import_module_list;
#endif

#if WASM_ENABLE_GC != 0
    /* Ref types hash set */
    HashMap *ref_type_set;
    struct WASMRttType **rtt_types;
    korp_mutex rtt_type_lock;
#if WASM_ENABLE_STRINGREF != 0
    /* special rtts for stringref types
        - stringref
        - stringview_wtf8
        - stringview_wtf16
        - stringview_iter
     */
    struct WASMRttType *stringref_rtts[4];
    uint32 string_literal_count;
    uint32 *string_literal_lengths;
    const uint8 **string_literal_ptrs;
#endif
#endif

#if WASM_ENABLE_DEBUG_AOT != 0
    void *elf_hdr;
    uint32 elf_size;
#endif
#if WASM_ENABLE_CUSTOM_NAME_SECTION != 0
    const char **aux_func_names;
    uint32 *aux_func_indexes;
    uint32 aux_func_name_count;
#endif
#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
    WASMCustomSection *custom_section_list;
#endif

    /* user defined name */
    char *name;

    /* Whether the underlying wasm binary buffer can be freed */
    bool is_binary_freeable;

    /* `.data` sections merged into one mmaped to reduce the tlb cache miss */
    uint8 *merged_data_sections;
    uint32 merged_data_sections_size;
    /* `.data` and `.text` sections merged into one large mmaped section */
    uint8 *merged_data_text_sections;
    uint32 merged_data_text_sections_size;

#if WASM_ENABLE_AOT_STACK_FRAME != 0
    uint32 feature_flags;
#endif
} AOTModule;

#define AOTMemoryInstance WASMMemoryInstance
#define AOTTableInstance WASMTableInstance
#define AOTModuleInstance WASMModuleInstance

#if WASM_ENABLE_MULTI_MODULE != 0
#define AOTSubModInstNode WASMSubModInstNode
#endif

/* Target info, read from ELF header of object file */
typedef struct AOTTargetInfo {
    /* Binary type, elf32l/elf32b/elf64l/elf64b */
    uint16 bin_type;
    /* ABI type */
    uint16 abi_type;
    /* Object file type */
    uint16 e_type;
    /* Architecture */
    uint16 e_machine;
    /* Object file version */
    uint32 e_version;
    /* Processor-specific flags */
    uint32 e_flags;
    /* Specify wasm features supported */
    uint64 feature_flags;
    /* Reserved */
    uint64 reserved;
    /* Arch name */
    char arch[16];
} AOTTargetInfo;

typedef struct AOTFuncPerfProfInfo {
    /* total execution time */
    uint64 total_exec_time;
    /* total execution count */
    uint32 total_exec_cnt;
    /* children execution time */
    uint64 children_exec_time;
} AOTFuncPerfProfInfo;

/* AOT auxiliary call stack */
typedef struct AOTFrame {
    /* The frame of the caller which is calling current function */
    struct AOTFrame *prev_frame;

    /* The non-imported function index of current function */
    uintptr_t func_index;

    /* Used when performance profiling is enabled */
    uintptr_t time_started;

    /* Used when performance profiling is enabled */
    AOTFuncPerfProfInfo *func_perf_prof_info;

    /* Instruction pointer: offset to the bytecode array */
    uintptr_t ip_offset;

    /* Operand stack top pointer of the current frame */
    uint32 *sp;

    /* Frame ref flags (GC only) */
    uint8 *frame_ref;

    /**
     * Frame data, the layout is:
     *  local area: parameters and local variables
     *  stack area: wasm operand stack
     *  frame ref flags (GC only):
     *      whether each cell in local and stack area is a GC obj
     *      currently local's ref flags are stored in AOTModule,
     *      here we only reserve the padding bytes
     */
    uint32 lp[1];
} AOTFrame;

#if WASM_ENABLE_STATIC_PGO != 0
/* The bitmaps fields in LLVMProfileRawHeader, LLVMProfileData,
 * LLVMProfileData_64 all dummy fields, it's used in MC/DC code coverage
 * instead of PGO. See https://llvm.org/docs/InstrProfileFormat.html#bitmap */
typedef struct LLVMProfileRawHeader {
    uint64 magic;
    uint64 version;
    uint64 binary_ids_size;
    uint64 num_prof_data;
    uint64 padding_bytes_before_counters;
    uint64 num_prof_counters;
    uint64 padding_bytes_after_counters;
    uint64 num_prof_bitmaps;
    uint64 padding_bytes_after_bitmaps;
    uint64 names_size;
    uint64 counters_delta;
    uint64 bitmap_delta;
    uint64 names_delta;
    uint64 value_kind_last;
} LLVMProfileRawHeader;

typedef struct ValueProfNode {
    uint64 value;
    uint64 count;
    struct ValueProfNode *next;
} ValueProfNode;

/* The profiling data of data sections created by aot compiler and
   used when profiling, the width of pointer can be 8 bytes (64-bit)
   or 4 bytes (32-bit) */
typedef struct LLVMProfileData {
    uint64 func_md5;
    uint64 func_hash;
    uint64 offset_counters;
    uint64 offset_bitmaps;
    uintptr_t func_ptr;
    ValueProfNode **values;
    uint32 num_counters;
    uint16 num_value_sites[2];
    uint32 num_bitmaps;
} LLVMProfileData;

/* The profiling data for writing to the output file, the width of
   pointer is 8 bytes suppose we always use wamrc and llvm-profdata
   with 64-bit mode */
typedef struct LLVMProfileData_64 {
    uint64 func_md5;
    uint64 func_hash;
    uint64 offset_counters;
    uint64 offset_bitmaps;
    uint64 func_ptr;
    uint64 values;
    uint32 num_counters;
    uint16 num_value_sites[2];
    uint32 num_bitmaps;
} LLVMProfileData_64;
#endif /* end of WASM_ENABLE_STATIC_PGO != 0 */

/**
 * Load a AOT module from aot file buffer
 * @param buf the byte buffer which contains the AOT file data
 * @param size the size of the buffer
 * @param error_buf output of the error info
 * @param error_buf_size the size of the error string
 *
 * @return return AOT module loaded, NULL if failed
 */
AOTModule *
aot_load_from_aot_file(const uint8 *buf, uint32 size, const LoadArgs *args,
                       char *error_buf, uint32 error_buf_size);

/**
 * Load a AOT module from a specified AOT section list.
 *
 * @param section_list the section list which contains each section data
 * @param error_buf output of the error info
 * @param error_buf_size the size of the error string
 *
 * @return return AOT module loaded, NULL if failed
 */
AOTModule *
aot_load_from_sections(AOTSection *section_list, char *error_buf,
                       uint32 error_buf_size);

/**
 * Unload a AOT module.
 *
 * @param module the module to be unloaded
 */
void
aot_unload(AOTModule *module);

/**
 * Resolve symbols for an AOT module
 */
bool
aot_resolve_symbols(AOTModule *module);

/**
 * Helper function to resolve a single function
 */
bool
aot_resolve_import_func(AOTModule *module, AOTImportFunc *import_func);

/**
 * Instantiate a AOT module.
 *
 * @param module the AOT module to instantiate
 * @param parent the parent module instance
 * @param heap_size the default heap size of the module instance, a heap will
 *        be created besides the app memory space. Both wasm app and native
 *        function can allocate memory from the heap. If heap_size is 0, the
 *        default heap size will be used.
 * @param error_buf buffer to output the error info if failed
 * @param error_buf_size the size of the error buffer
 *
 * @return return the instantiated AOT module instance, NULL if failed
 */
AOTModuleInstance *
aot_instantiate(AOTModule *module, AOTModuleInstance *parent,
                WASMExecEnv *exec_env_main, uint32 stack_size, uint32 heap_size,
                uint32 max_memory_pages, char *error_buf,
                uint32 error_buf_size);

/**
 * Deinstantiate a AOT module instance, destroy the resources.
 *
 * @param module_inst the AOT module instance to destroy
 * @param is_sub_inst the flag of sub instance
 */
void
aot_deinstantiate(AOTModuleInstance *module_inst, bool is_sub_inst);

/**
 * Lookup an exported function in the AOT module instance.
 *
 * @param module_inst the module instance
 * @param name the name of the function
 *
 * @return the function instance found
 */
AOTFunctionInstance *
aot_lookup_function(const AOTModuleInstance *module_inst, const char *name);

/**
 * Lookup an exported function in the AOT module instance with
 * the function index.
 */
AOTFunctionInstance *
aot_lookup_function_with_idx(AOTModuleInstance *module_inst, uint32 func_idx);

AOTMemoryInstance *
aot_lookup_memory(AOTModuleInstance *module_inst, char const *name);

AOTMemoryInstance *
aot_get_default_memory(AOTModuleInstance *module_inst);

AOTMemoryInstance *
aot_get_memory_with_idx(AOTModuleInstance *module_inst, uint32 mem_idx);

/**
 * Get a function in the AOT module instance.
 *
 * @param module_inst the module instance
 * @param func_idx the index of the function
 *
 * @return the function instance found
 */
AOTFunctionInstance *
aot_get_function_instance(AOTModuleInstance *module_inst, uint32 func_idx);

/**
 * Call the given AOT function of a AOT module instance with
 * arguments.
 *
 * @param exec_env the execution environment
 * @param function the function to be called
 * @param argc the number of arguments
 * @param argv the arguments.  If the function method has return value,
 *   the first (or first two in case 64-bit return value) element of
 *   argv stores the return value of the called AOT function after this
 *   function returns.
 *
 * @return true if success, false otherwise and exception will be thrown,
 *   the caller can call aot_get_exception to get exception info.
 */
bool
aot_call_function(WASMExecEnv *exec_env, AOTFunctionInstance *function,
                  unsigned argc, uint32 argv[]);

/**
 * Set AOT module instance exception with exception string
 *
 * @param module the AOT module instance
 *
 * @param exception current exception string
 */
void
aot_set_exception(AOTModuleInstance *module_inst, const char *exception);

void
aot_set_exception_with_id(AOTModuleInstance *module_inst, uint32 id);

/**
 * Get exception info of the AOT module instance.
 *
 * @param module_inst the AOT module instance
 *
 * @return the exception string
 */
const char *
aot_get_exception(AOTModuleInstance *module_inst);

/**
 * @brief Copy exception in buffer passed as parameter. Thread-safe version of
 * `aot_get_exception()`
 * @note Buffer size must be no smaller than EXCEPTION_BUF_LEN
 * @return true if exception found, false otherwise
 */
bool
aot_copy_exception(AOTModuleInstance *module_inst, char *exception_buf);

uint64
aot_module_malloc_internal(AOTModuleInstance *module_inst, WASMExecEnv *env,
                           uint64 size, void **p_native_addr);

uint64
aot_module_realloc_internal(AOTModuleInstance *module_inst, WASMExecEnv *env,
                            uint64 ptr, uint64 size, void **p_native_addr);

void
aot_module_free_internal(AOTModuleInstance *module_inst, WASMExecEnv *env,
                         uint64 ptr);

uint64
aot_module_malloc(AOTModuleInstance *module_inst, uint64 size,
                  void **p_native_addr);

uint64
aot_module_realloc(AOTModuleInstance *module_inst, uint64 ptr, uint64 size,
                   void **p_native_addr);

void
aot_module_free(AOTModuleInstance *module_inst, uint64 ptr);

uint64
aot_module_dup_data(AOTModuleInstance *module_inst, const char *src,
                    uint64 size);

bool
aot_enlarge_memory(AOTModuleInstance *module_inst, uint32 inc_page_count);

bool
aot_enlarge_memory_with_idx(AOTModuleInstance *module_inst,
                            uint32 inc_page_count, uint32 memidx);

/**
 * Invoke native function from aot code
 */
bool
aot_invoke_native(WASMExecEnv *exec_env, uint32 func_idx, uint32 argc,
                  uint32 *argv);

bool
aot_call_indirect(WASMExecEnv *exec_env, uint32 tbl_idx, uint32 table_elem_idx,
                  uint32 argc, uint32 *argv);

/**
 * Check whether the app address and the buf is inside the linear memory,
 * and convert the app address into native address
 */
bool
aot_check_app_addr_and_convert(AOTModuleInstance *module_inst, bool is_str,
                               uint64 app_buf_addr, uint64 app_buf_size,
                               void **p_native_addr);

uint32
aot_get_plt_table_size(void);

void *
aot_memmove(void *dest, const void *src, size_t n);

void *
aot_memset(void *s, int c, size_t n);

double
aot_sqrt(double x);

float
aot_sqrtf(float x);

#if WASM_ENABLE_BULK_MEMORY != 0
bool
aot_memory_init(AOTModuleInstance *module_inst, uint32 seg_index, uint32 offset,
                uint32 len, size_t dst);

bool
aot_data_drop(AOTModuleInstance *module_inst, uint32 seg_index);
#endif

#if WASM_ENABLE_THREAD_MGR != 0
bool
aot_set_aux_stack(WASMExecEnv *exec_env, uint64 start_offset, uint32 size);

bool
aot_get_aux_stack(WASMExecEnv *exec_env, uint64 *start_offset, uint32 *size);
#endif

void
aot_get_module_mem_consumption(const AOTModule *module,
                               WASMModuleMemConsumption *mem_conspn);

void
aot_get_module_inst_mem_consumption(const AOTModuleInstance *module_inst,
                                    WASMModuleInstMemConsumption *mem_conspn);

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
void
aot_drop_table_seg(AOTModuleInstance *module_inst, uint32 tbl_seg_idx);

void
aot_table_init(AOTModuleInstance *module_inst, uint32 tbl_idx,
               uint32 tbl_seg_idx, uint32 length, uint32 src_offset,
               uint32 dst_offset);

void
aot_table_copy(AOTModuleInstance *module_inst, uint32 src_tbl_idx,
               uint32 dst_tbl_idx, uint32 length, uint32 src_offset,
               uint32 dst_offset);

void
aot_table_fill(AOTModuleInstance *module_inst, uint32 tbl_idx, uint32 length,
               table_elem_type_t val, uint32 data_offset);

uint32
aot_table_grow(AOTModuleInstance *module_inst, uint32 tbl_idx,
               uint32 inc_entries, table_elem_type_t init_val);
#endif

bool
aot_alloc_frame(WASMExecEnv *exec_env, uint32 func_index);

void
aot_free_frame(WASMExecEnv *exec_env);

void
aot_frame_update_profile_info(WASMExecEnv *exec_env, bool alloc_frame);

bool
aot_create_call_stack(struct WASMExecEnv *exec_env);

#if WASM_ENABLE_COPY_CALL_STACK != 0
uint32
aot_copy_callstack(WASMExecEnv *exec_env, WASMCApiFrame *buffer,
                   const uint32 length, const uint32 skip_n, char *error_buf,
                   uint32_t error_buf_size);
#endif // WASM_ENABLE_COPY_CALL_STACK

/**
 * @brief Dump wasm call stack or get the size
 *
 * @param exec_env the execution environment
 * @param print whether to print to stdout or not
 * @param buf buffer to store the dumped content
 * @param len length of the buffer
 *
 * @return when print is true, return the bytes printed out to stdout; when
 * print is false and buf is NULL, return the size required to store the
 * callstack content; when print is false and buf is not NULL, return the size
 * dumped to the buffer, 0 means error and data in buf may be invalid
 */
uint32
aot_dump_call_stack(WASMExecEnv *exec_env, bool print, char *buf, uint32 len);

void
aot_dump_perf_profiling(const AOTModuleInstance *module_inst);

double
aot_summarize_wasm_execute_time(const AOTModuleInstance *inst);

double
aot_get_wasm_func_exec_time(const AOTModuleInstance *inst,
                            const char *func_name);

const uint8 *
aot_get_custom_section(const AOTModule *module, const char *name, uint32 *len);

const void *
aot_get_data_section_addr(AOTModule *module, const char *section_name,
                          uint32 *p_data_size);

#if WASM_ENABLE_STATIC_PGO != 0
void
llvm_profile_instrument_target(uint64 target_value, void *data,
                               uint32 counter_idx);

void
llvm_profile_instrument_memop(uint64 target_value, void *data,
                              uint32 counter_idx);

uint32
aot_get_pgo_prof_data_size(AOTModuleInstance *module_inst);

uint32
aot_dump_pgo_prof_data_to_buf(AOTModuleInstance *module_inst, char *buf,
                              uint32 len);

void
aot_exchange_uint16(uint8 *p_data);

void
aot_exchange_uint32(uint8 *p_data);

void
aot_exchange_uint64(uint8 *p_data);
#endif /* end of WASM_ENABLE_STATIC_PGO != 0 */

#if WASM_ENABLE_GC != 0
void *
aot_create_func_obj(AOTModuleInstance *module_inst, uint32 func_idx,
                    bool throw_exce, char *error_buf, uint32 error_buf_size);

bool
aot_obj_is_instance_of(AOTModuleInstance *module_inst, WASMObjectRef gc_obj,
                       uint32 type_index);

/* Whether func type1 is one of super types of func type2 */
bool
aot_func_type_is_super_of(AOTModuleInstance *module_inst, uint32 type_idx1,
                          uint32 type_idx2);

WASMRttTypeRef
aot_rtt_type_new(AOTModuleInstance *module_inst, uint32 type_index);

bool
aot_array_init_with_data(AOTModuleInstance *module_inst, uint32 seg_index,
                         uint32 data_seg_offset, WASMArrayObjectRef array_obj,
                         uint32 elem_size, uint32 array_len);

bool
aot_traverse_gc_rootset(WASMExecEnv *exec_env, void *heap);
#endif /* end of WASM_ENABLE_GC != 0 */

char *
aot_const_str_set_insert(const uint8 *str, int32 len, AOTModule *module,
#if (WASM_ENABLE_WORD_ALIGN_READ != 0)
                         bool is_vram_word_align,
#endif
                         char *error_buf, uint32 error_buf_size);

bool
aot_set_module_name(AOTModule *module, const char *name, char *error_buf,
                    uint32_t error_buf_size);

const char *
aot_get_module_name(AOTModule *module);

#ifdef __cplusplus
} /* end of extern "C" */
#endif

#endif /* end of _AOT_RUNTIME_H_ */
