/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _AOT_H_
#define _AOT_H_

#include "bh_platform.h"
#include "bh_assert.h"
#include "../common/wasm_runtime_common.h"
#include "../interpreter/wasm.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef AOT_FUNC_PREFIX
#define AOT_FUNC_PREFIX "aot_func#"
#endif

#ifndef AOT_FUNC_INTERNAL_PREFIX
#define AOT_FUNC_INTERNAL_PREFIX "aot_func_internal#"
#endif

#ifndef AOT_STACK_SIZES_NAME
#define AOT_STACK_SIZES_NAME "aot_stack_sizes"
#endif
extern const char *aot_stack_sizes_name;

#ifndef AOT_STACK_SIZES_ALIAS_NAME
#define AOT_STACK_SIZES_ALIAS_NAME "aot_stack_sizes_alias"
#endif
extern const char *aot_stack_sizes_alias_name;

#ifndef AOT_STACK_SIZES_SECTION_NAME
#define AOT_STACK_SIZES_SECTION_NAME ".aot_stack_sizes"
#endif
extern const char *aot_stack_sizes_section_name;

typedef InitializerExpression AOTInitExpr;
typedef WASMType AOTType;
typedef WASMFuncType AOTFuncType;
#if WASM_ENABLE_GC != 0
typedef WASMStructType AOTStructType;
typedef WASMArrayType AOTArrayType;
#endif
typedef WASMExport AOTExport;
typedef WASMMemory AOTMemory;
typedef WASMMemoryType AOTMemoryType;
typedef WASMTableType AOTTableType;
typedef WASMTable AOTTable;

#if WASM_ENABLE_DEBUG_AOT != 0
typedef void *dwarf_extractor_handle_t;
#endif

typedef enum AOTIntCond {
    INT_EQZ = 0,
    INT_EQ,
    INT_NE,
    INT_LT_S,
    INT_LT_U,
    INT_GT_S,
    INT_GT_U,
    INT_LE_S,
    INT_LE_U,
    INT_GE_S,
    INT_GE_U
} AOTIntCond;

typedef enum AOTFloatCond {
    FLOAT_EQ = 0,
    FLOAT_NE,
    FLOAT_LT,
    FLOAT_GT,
    FLOAT_LE,
    FLOAT_GE,
    FLOAT_UNO
} AOTFloatCond;

/**
 * Import memory
 */
typedef struct AOTImportMemory {
    char *module_name;
    char *memory_name;
    AOTMemoryType mem_type;
} AOTImportMemory;

/**
 * A segment of memory init data
 */
typedef struct AOTMemInitData {
#if WASM_ENABLE_BULK_MEMORY != 0
    /* Passive flag */
    bool is_passive;
    /* memory index */
    uint32 memory_index;
#endif
    /* Start address of init data */
    AOTInitExpr offset;
    /* Byte count */
    uint32 byte_count;
    /* Byte array */
    uint8 *bytes;
} AOTMemInitData;

/**
 * Import table
 */
typedef struct AOTImportTable {
    char *module_name;
    char *table_name;
    AOTTableType table_type;
} AOTImportTable;

/**
 * A segment of table init data
 */
typedef struct AOTTableInitData {
    /* 0 to 7 */
    uint32 mode;
    /* funcref or externref, elemkind will be considered as funcref */
    uint32 elem_type;
#if WASM_ENABLE_GC != 0
    WASMRefType *elem_ref_type;
#endif
    /* optional, only for active */
    uint32 table_index;
    /* Start address of init data */
    AOTInitExpr offset;
    /* Function index count */
    uint32 value_count;
    /* Function index array */
    InitializerExpression init_values[1];
} AOTTableInitData;

/**
 * Import global variable
 */
typedef struct AOTImportGlobal {
    char *module_name;
    char *global_name;
    WASMGlobalType type;
    uint32 size;
    /* The data offset of current global in global data */
    uint32 data_offset;
#if WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0
    /*
     * The data size and data offset of a wasm global may vary
     * in 32-bit target and 64-bit target, e.g., the size of a
     * GC obj is 4 bytes in the former and 8 bytes in the
     * latter, the AOT compiler needs to use the correct data
     * offset according to the target info.
     */
    uint32 size_64bit;
    uint32 size_32bit;
    uint32 data_offset_64bit;
    uint32 data_offset_32bit;
#endif
    /* global data after linked */
    WASMValue global_data_linked;
    bool is_linked;
} AOTImportGlobal;

/**
 * Global variable
 */
typedef struct AOTGlobal {
    WASMGlobalType type;
    uint32 size;
    /* The data offset of current global in global data */
    uint32 data_offset;
#if WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0
    /* See comments in AOTImportGlobal */
    uint32 size_64bit;
    uint32 size_32bit;
    uint32 data_offset_64bit;
    uint32 data_offset_32bit;
#endif
    AOTInitExpr init_expr;
} AOTGlobal;

/**
 * Import function
 */
typedef struct AOTImportFunc {
    char *module_name;
    char *func_name;
    AOTFuncType *func_type;
    uint32 func_type_index;
    /* function pointer after linked */
    void *func_ptr_linked;
    /* signature from registered native symbols */
    const char *signature;
    /* attachment */
    void *attachment;
    bool call_conv_raw;
    bool call_conv_wasm_c_api;
    bool wasm_c_api_with_env;
} AOTImportFunc;

/**
 * Function
 */
typedef struct AOTFunc {
    AOTFuncType *func_type;
    uint32 func_type_index;
    uint32 local_count;
    uint8 *local_types_wp;
    uint16 param_cell_num;
    uint16 local_cell_num;
    uint32 max_stack_cell_num;
    uint32 code_size;
    uint8 *code;
    /* offset of each local, including function parameters
       and local variables */
    uint16 *local_offsets;
} AOTFunc;

typedef struct AOTCompData {
    /* Import memories */
    uint32 import_memory_count;
    AOTImportMemory *import_memories;

    /* Memories */
    uint32 memory_count;
    AOTMemory *memories;

    /* Memory init data info */
    uint32 mem_init_data_count;
    AOTMemInitData **mem_init_data_list;

    /* Import tables */
    uint32 import_table_count;
    AOTImportTable *import_tables;

    /* Tables */
    uint32 table_count;
    AOTTable *tables;

    /* Table init data info */
    uint32 table_init_data_count;
    AOTTableInitData **table_init_data_list;

    /* Import globals */
    uint32 import_global_count;
    AOTImportGlobal *import_globals;

    /* Globals */
    uint32 global_count;
    AOTGlobal *globals;

    /* Function types */
    uint32 type_count;
    AOTType **types;

    /* Import functions */
    uint32 import_func_count;
    AOTImportFunc *import_funcs;

    /* Functions */
    uint32 func_count;
    AOTFunc **funcs;

    /* Custom name sections */
    const uint8 *name_section_buf;
    const uint8 *name_section_buf_end;
    uint8 *aot_name_section_buf;
    uint32 aot_name_section_size;

    uint32 global_data_size_64bit;
    uint32 global_data_size_32bit;

    uint32 start_func_index;
    uint32 malloc_func_index;
    uint32 free_func_index;
    uint32 retain_func_index;

    uint32 aux_data_end_global_index;
    uint64 aux_data_end;
    uint32 aux_heap_base_global_index;
    uint64 aux_heap_base;
    uint32 aux_stack_top_global_index;
    uint64 aux_stack_bottom;
    uint32 aux_stack_size;

#if WASM_ENABLE_STRINGREF != 0
    uint32 string_literal_count;
    uint32 *string_literal_lengths_wp;
    const uint8 **string_literal_ptrs_wp;
#endif

    WASMModule *wasm_module;
#if WASM_ENABLE_DEBUG_AOT != 0
    dwarf_extractor_handle_t extractor;
#endif
} AOTCompData;

typedef struct AOTNativeSymbol {
    bh_list_link link;
    char symbol[48];
    int32 index;
} AOTNativeSymbol;

AOTCompData *
aot_create_comp_data(WASMModule *module, const char *target_arch,
                     bool gc_enabled);

void
aot_destroy_comp_data(AOTCompData *comp_data);

char *
aot_get_last_error(void);

void
aot_set_last_error(const char *error);

void
aot_set_last_error_v(const char *format, ...);

#if BH_DEBUG != 0
#define HANDLE_FAILURE(callee)                                    \
    do {                                                          \
        aot_set_last_error_v("call %s failed in %s:%d", (callee), \
                             __FUNCTION__, __LINE__);             \
    } while (0)
#else
#define HANDLE_FAILURE(callee)                            \
    do {                                                  \
        aot_set_last_error_v("call %s failed", (callee)); \
    } while (0)
#endif

static inline uint32
aot_get_imp_tbl_data_slots(const AOTImportTable *tbl, bool is_jit_mode)
{
#if WASM_ENABLE_MULTI_MODULE != 0
    if (is_jit_mode)
        return tbl->table_type.max_size;
#else
    (void)is_jit_mode;
#endif
    return tbl->table_type.possible_grow ? tbl->table_type.max_size
                                         : tbl->table_type.init_size;
}

static inline uint32
aot_get_tbl_data_slots(const AOTTable *tbl, bool is_jit_mode)
{
#if WASM_ENABLE_MULTI_MODULE != 0
    if (is_jit_mode)
        return tbl->table_type.max_size;
#else
    (void)is_jit_mode;
#endif
    return tbl->table_type.possible_grow ? tbl->table_type.max_size
                                         : tbl->table_type.init_size;
}

#ifdef __cplusplus
} /* end of extern "C" */
#endif

#endif /* end of _AOT_H_ */
