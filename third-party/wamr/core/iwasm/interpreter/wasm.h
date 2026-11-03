/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_H_
#define _WASM_H_

#include "bh_platform.h"
#include "bh_hashmap.h"
#include "bh_assert.h"
#if WASM_ENABLE_GC != 0
#include "gc_export.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Value Type */
#define VALUE_TYPE_I32 0x7F
#define VALUE_TYPE_I64 0X7E
#define VALUE_TYPE_F32 0x7D
#define VALUE_TYPE_F64 0x7C
#define VALUE_TYPE_V128 0x7B
#define VALUE_TYPE_FUNCREF 0x70
#define VALUE_TYPE_EXTERNREF 0x6F
#define VALUE_TYPE_VOID 0x40

/* Packed Types */
#define PACKED_TYPE_I8 0x78
#define PACKED_TYPE_I16 0x77

/* Reference Types */
#define REF_TYPE_NULLFUNCREF 0x73
#define REF_TYPE_NULLEXTERNREF 0x72
#define REF_TYPE_NULLREF 0x71
#define REF_TYPE_FUNCREF VALUE_TYPE_FUNCREF     /* 0x70 */
#define REF_TYPE_EXTERNREF VALUE_TYPE_EXTERNREF /* 0x6F */
#define REF_TYPE_ANYREF 0x6E
#define REF_TYPE_EQREF 0x6D
#define REF_TYPE_I31REF 0x6C
#define REF_TYPE_STRUCTREF 0x6B
#define REF_TYPE_ARRAYREF 0x6A
#define REF_TYPE_HT_NON_NULLABLE 0x64
#define REF_TYPE_HT_NULLABLE 0x63
#define REF_TYPE_STRINGREF VALUE_TYPE_STRINGREF             /* 0x67 */
#define REF_TYPE_STRINGVIEWWTF8 VALUE_TYPE_STRINGVIEWWTF8   /* 0x66 */
#define REF_TYPE_STRINGVIEWWTF16 VALUE_TYPE_STRINGVIEWWTF16 /* 0x62 */
#define REF_TYPE_STRINGVIEWITER VALUE_TYPE_STRINGVIEWITER   /* 0x61 */

/* Heap Types */
#define HEAP_TYPE_NOFUNC (-0x0D)
#define HEAP_TYPE_NOEXTERN (-0x0E)
#define HEAP_TYPE_NONE (-0x0F)
#define HEAP_TYPE_FUNC (-0x10)
#define HEAP_TYPE_EXTERN (-0x11)
#define HEAP_TYPE_ANY (-0x12)
#define HEAP_TYPE_EQ (-0x13)
#define HEAP_TYPE_I31 (-0x14)
#define HEAP_TYPE_STRUCT (-0x15)
#define HEAP_TYPE_ARRAY (-0x16)
#define HEAP_TYPE_STRINGREF (-0x19)
#define HEAP_TYPE_STRINGVIEWWTF8 (-0x1A)
#define HEAP_TYPE_STRINGVIEWWTF16 (-0x1E)
#define HEAP_TYPE_STRINGVIEWITER (-0x1F)

/* Defined Types */
#define DEFINED_TYPE_FUNC 0x60
#define DEFINED_TYPE_STRUCT 0x5F
#define DEFINED_TYPE_ARRAY 0x5E
#define DEFINED_TYPE_SUB 0x50
#define DEFINED_TYPE_SUB_FINAL 0x4F
#define DEFINED_TYPE_REC 0x4E

/* Used by AOT */
#define VALUE_TYPE_I1 0x41
/**
 * Used by loader to represent any type of i32/i64/f32/f64/v128
 * and ref types, including funcref, externref, anyref, eqref,
 * (ref null $ht), (ref $ht), i31ref, structref, arrayref,
 * nullfuncref, nullexternref, nullref and stringref
 */
#define VALUE_TYPE_ANY 0x42
/**
 * Used by wamr compiler to represent object ref types,
 * including func object ref, externref object ref,
 * internal object ref, eq object ref, i31 object ref,
 * struct object ref, array object ref
 */
#define VALUE_TYPE_GC_REF 0x43

#define MAX_PAGE_COUNT_FLAG 0x01
#define SHARED_MEMORY_FLAG 0x02
#define MEMORY64_FLAG 0x04
#define MAX_TABLE_SIZE_FLAG 0x01
/* the shared flag for table is not actual used now */
#define SHARED_TABLE_FLAG 0x02
#define TABLE64_FLAG 0x04

/**
 * In the multi-memory proposal, the memarg in loads and stores are
 * reinterpreted as a bitfield, bit 6 serves as a flag indicating the presence
 * of the optional memory index, if it is set, then an i32 memory index follows
 * after the alignment bitfield
 */
#define OPT_MEMIDX_FLAG 0x40

#define DEFAULT_NUM_BYTES_PER_PAGE 65536
#define DEFAULT_MAX_PAGES 65536
#define DEFAULT_MEM64_MAX_PAGES UINT32_MAX

/* Max size of linear memory */
#define MAX_LINEAR_MEMORY_SIZE (4 * (uint64)BH_GB)
/* Roughly 274 TB */
#define MAX_LINEAR_MEM64_MEMORY_SIZE \
    (DEFAULT_MEM64_MAX_PAGES * (uint64)64 * (uint64)BH_KB)
/* Macro to check memory flag and return appropriate memory size */
#define GET_MAX_LINEAR_MEMORY_SIZE(is_memory64) \
    (is_memory64 ? MAX_LINEAR_MEM64_MEMORY_SIZE : MAX_LINEAR_MEMORY_SIZE)

#if WASM_ENABLE_GC == 0
typedef uintptr_t table_elem_type_t;
#define NULL_REF (0xFFFFFFFF)
#else
typedef void *table_elem_type_t;
#define NULL_REF (NULL)
#define REF_CELL_NUM ((uint32)sizeof(uintptr_t) / sizeof(uint32))
#endif

#define INIT_EXPR_NONE 0x00
#define INIT_EXPR_TYPE_I32_CONST 0x41
#define INIT_EXPR_TYPE_I64_CONST 0x42
#define INIT_EXPR_TYPE_F32_CONST 0x43
#define INIT_EXPR_TYPE_F64_CONST 0x44
#define INIT_EXPR_TYPE_V128_CONST 0xFD
#define INIT_EXPR_TYPE_GET_GLOBAL 0x23
#define INIT_EXPR_TYPE_I32_ADD 0x6A
#define INIT_EXPR_TYPE_I32_SUB 0x6B
#define INIT_EXPR_TYPE_I32_MUL 0x6C
#define INIT_EXPR_TYPE_I64_ADD 0x7C
#define INIT_EXPR_TYPE_I64_SUB 0x7D
#define INIT_EXPR_TYPE_I64_MUL 0x7E
#define INIT_EXPR_TYPE_REFNULL_CONST 0xD0
#define INIT_EXPR_TYPE_FUNCREF_CONST 0xD2
#define INIT_EXPR_TYPE_STRUCT_NEW 0xD3
#define INIT_EXPR_TYPE_STRUCT_NEW_DEFAULT 0xD4
#define INIT_EXPR_TYPE_ARRAY_NEW 0xD5
#define INIT_EXPR_TYPE_ARRAY_NEW_DEFAULT 0xD6
#define INIT_EXPR_TYPE_ARRAY_NEW_FIXED 0xD7
#define INIT_EXPR_TYPE_I31_NEW 0xD8
#define INIT_EXPR_TYPE_ANY_CONVERT_EXTERN 0xD9
#define INIT_EXPR_TYPE_EXTERN_CONVERT_ANY 0xDA

#define WASM_MAGIC_NUMBER 0x6d736100
#define WASM_CURRENT_VERSION 1

#define SECTION_TYPE_USER 0
#define SECTION_TYPE_TYPE 1
#define SECTION_TYPE_IMPORT 2
#define SECTION_TYPE_FUNC 3
#define SECTION_TYPE_TABLE 4
#define SECTION_TYPE_MEMORY 5
#define SECTION_TYPE_GLOBAL 6
#define SECTION_TYPE_EXPORT 7
#define SECTION_TYPE_START 8
#define SECTION_TYPE_ELEM 9
#define SECTION_TYPE_CODE 10
#define SECTION_TYPE_DATA 11
#if WASM_ENABLE_BULK_MEMORY != 0
#define SECTION_TYPE_DATACOUNT 12
#endif
#if WASM_ENABLE_TAGS != 0
#define SECTION_TYPE_TAG 13
#endif
#if WASM_ENABLE_STRINGREF != 0
#define SECTION_TYPE_STRINGREF 14
#endif

#define SUB_SECTION_TYPE_MODULE 0
#define SUB_SECTION_TYPE_FUNC 1
#define SUB_SECTION_TYPE_LOCAL 2

#define IMPORT_KIND_FUNC 0
#define IMPORT_KIND_TABLE 1
#define IMPORT_KIND_MEMORY 2
#define IMPORT_KIND_GLOBAL 3
#if WASM_ENABLE_TAGS != 0
#define IMPORT_KIND_TAG 4
#endif

#define EXPORT_KIND_FUNC 0
#define EXPORT_KIND_TABLE 1
#define EXPORT_KIND_MEMORY 2
#define EXPORT_KIND_GLOBAL 3
#if WASM_ENABLE_TAGS != 0
#define EXPORT_KIND_TAG 4
#endif

#define LABEL_TYPE_BLOCK 0
#define LABEL_TYPE_LOOP 1
#define LABEL_TYPE_IF 2
#define LABEL_TYPE_FUNCTION 3
#if WASM_ENABLE_EXCE_HANDLING != 0
#define LABEL_TYPE_TRY 4
#define LABEL_TYPE_CATCH 5
#define LABEL_TYPE_CATCH_ALL 6
#endif

#define WASM_TYPE_FUNC 0
#define WASM_TYPE_STRUCT 1
#define WASM_TYPE_ARRAY 2

#if WASM_ENABLE_STRINGREF != 0
#define WASM_TYPE_STRINGREF 3
#define WASM_TYPE_STRINGVIEWWTF8 4
#define WASM_TYPE_STRINGVIEWWTF16 5
#define WASM_TYPE_STRINGVIEWITER 6
#endif

/* In WasmGC, a table can start with [0x40 0x00] to indicate it has an
 * initializer */
#define TABLE_INIT_EXPR_FLAG 0x40

typedef struct WASMModule WASMModule;
typedef struct WASMFunction WASMFunction;
typedef struct WASMGlobal WASMGlobal;
#if WASM_ENABLE_TAGS != 0
typedef struct WASMTag WASMTag;
#endif

#ifndef WASM_VALUE_DEFINED
#define WASM_VALUE_DEFINED

typedef union V128 {
    int8 i8x16[16];
    int16 i16x8[8];
    int32 i32x4[4];
    int64 i64x2[2];
    float32 f32x4[4];
    float64 f64x2[2];
} V128;

typedef union WASMValue {
    int32 i32;
    uint32 u32;
    uint32 global_index;
    uint32 ref_index;
    int64 i64;
    uint64 u64;
    float32 f32;
    float64 f64;
    V128 v128;
#if WASM_ENABLE_GC != 0
    wasm_obj_t gc_obj;
    uint32 type_index;
    struct {
        uint32 type_index;
        uint32 length;
    } array_new_default;
    /* pointer to a memory space holding more data, current usage:
     *  struct.new init value: WASMStructNewInitValues *
     *  array.new init value: WASMArrayNewInitValues *
     */
    void *data;
#endif
} WASMValue;
#endif /* end of WASM_VALUE_DEFINED */

typedef struct WASMStructNewInitValues {
    uint32 type_idx;
    uint32 count;
    WASMValue fields[1];
} WASMStructNewInitValues;

typedef struct WASMArrayNewInitValues {
    uint32 type_idx;
    uint32 length;
    WASMValue elem_data[1];
} WASMArrayNewInitValues;

typedef struct InitializerExpression {
    /* type of INIT_EXPR_TYPE_XXX, which is an instruction of
       constant expression */
    uint8 init_expr_type;
    union {
        struct {
            WASMValue v;
        } unary;
        struct {
            struct InitializerExpression *l_expr;
            struct InitializerExpression *r_expr;
        } binary;
    } u;
} InitializerExpression;

static inline bool
is_expr_binary_op(uint8 flag)
{
    return flag == INIT_EXPR_TYPE_I32_ADD || flag == INIT_EXPR_TYPE_I32_SUB
           || flag == INIT_EXPR_TYPE_I32_MUL || flag == INIT_EXPR_TYPE_I64_ADD
           || flag == INIT_EXPR_TYPE_I64_SUB || flag == INIT_EXPR_TYPE_I64_MUL;
}

/* check if table or data offset is valid for i32 offset */
static inline bool
is_valid_i32_offset(uint8 flag)
{
    return flag == INIT_EXPR_TYPE_I32_CONST || flag == INIT_EXPR_TYPE_I32_ADD
           || flag == INIT_EXPR_TYPE_I32_SUB || flag == INIT_EXPR_TYPE_I32_MUL;
}

/* check if table or data offset is valid for i64 offset */
static inline bool
is_valid_i64_offset(uint8 flag)
{
    return flag == INIT_EXPR_TYPE_I64_CONST || flag == INIT_EXPR_TYPE_I64_ADD
           || flag == INIT_EXPR_TYPE_I64_SUB || flag == INIT_EXPR_TYPE_I64_MUL;
}

#if WASM_ENABLE_GC != 0
/**
 * Reference type of (ref null ht) or (ref ht),
 * and heap type is defined type (type i), i >= 0
 */
typedef struct RefHeapType_TypeIdx {
    /* ref_type is REF_TYPE_HT_NULLABLE or
       REF_TYPE_HT_NON_NULLABLE, (0x63 or 0x64) */
    uint8 ref_type;
    /* true if ref_type is REF_TYPE_HT_NULLABLE */
    bool nullable;
    /* heap type is defined type: type_index >= 0 */
    int32 type_idx;
} RefHeapType_TypeIdx;

/**
 * Reference type of (ref null ht) or (ref ht),
 * and heap type is non-defined type
 */
typedef struct RefHeapType_Common {
    /* ref_type is REF_TYPE_HT_NULLABLE or
       REF_TYPE_HT_NON_NULLABLE (0x63 or 0x64) */
    uint8 ref_type;
    /* true if ref_type is REF_TYPE_HT_NULLABLE */
    bool nullable;
    /* Common heap type (not defined type):
       -0x10 (func), -0x11 (extern), -0x12 (any), -0x13 (eq),
       -0x16 (i31), -0x17 (nofunc), -0x18 (noextern),
       -0x19 (struct), -0x20 (array), -0x21 (none) */
    int32 heap_type;
} RefHeapType_Common;

/**
 * Reference type
 */
typedef union WASMRefType {
    uint8 ref_type;
    RefHeapType_TypeIdx ref_ht_typeidx;
    RefHeapType_Common ref_ht_common;
} WASMRefType;

typedef struct WASMRefTypeMap {
    /**
     * The type index of a type array, which only stores
     * the first byte of the type, e.g. WASMFuncType.types,
     * WASMStructType.fields
     */
    uint16 index;
    /* The full type info if the type cannot be described
       with one byte */
    WASMRefType *ref_type;
} WASMRefTypeMap;
#endif /* end of WASM_ENABLE_GC */

#if WASM_ENABLE_GC == 0
typedef struct WASMFuncType WASMType;
typedef WASMType *WASMTypePtr;
#else
/**
 * Common type, store the same fields of
 * WASMFuncType, WASMStructType and WASMArrayType
 */
typedef struct WASMType {
    /**
     * type_flag must be WASM_TYPE_FUNC/STRUCT/ARRAY to
     * denote that it is a WASMFuncType, WASMStructType or
     * WASMArrayType
     */
    uint16 type_flag;

    bool is_sub_final;
    /* How many types are referring to this type */
    uint16 ref_count;
    /* The inheritance depth */
    uint16 inherit_depth;
    /* The root type */
    struct WASMType *root_type;
    /* The parent type */
    struct WASMType *parent_type;
    uint32 parent_type_idx;

    /* The number of internal types in the current rec group, and if
       the type is not in a recursive group, rec_count is 1 since a
       single type definition is reinterpreted as a short-hand for a
       recursive group containing just one type */
    uint16 rec_count;
    uint16 rec_idx;
    /* The index of the begin type of this group */
    uint32 rec_begin_type_idx;
} WASMType, *WASMTypePtr;
#endif /* end of WASM_ENABLE_GC */

/* Function type */
typedef struct WASMFuncType {
#if WASM_ENABLE_GC != 0
    WASMType base_type;
#endif

    uint16 param_count;
    uint16 result_count;
    uint16 param_cell_num;
    uint16 ret_cell_num;

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    /* Code block to call llvm jit functions of this
       kind of function type from fast jit jitted code */
    void *call_to_llvm_jit_from_fast_jit;
#endif

#if WASM_ENABLE_GC != 0
    uint16 ref_type_map_count;
    WASMRefTypeMap *ref_type_maps;
    WASMRefTypeMap *result_ref_type_maps;
#else
    uint16 ref_count;
#endif

#if WASM_ENABLE_QUICK_AOT_ENTRY != 0
    /* Quick AOT/JIT entry of this func type */
    void *quick_aot_entry;
#endif

    /* types of params and results, only store the first byte
     * of the type, if it cannot be described with one byte,
     * then the full type info is stored in ref_type_maps */
    uint8 types[1];
} WASMFuncType;

#if WASM_ENABLE_GC != 0
typedef struct WASMStructFieldType {
    uint16 field_flags;
    uint8 field_type;
    uint8 field_size;
    uint32 field_offset;
#if WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0
    /*
     * The field size and field offset of a wasm struct may vary
     * in 32-bit target and 64-bit target, e.g., the size of a
     * GC reference is 4 bytes in the former and 8 bytes in the
     * latter, the AOT compiler needs to use the correct field
     * offset according to the target info.
     */
    uint8 field_size_64bit;
    uint8 field_size_32bit;
    uint32 field_offset_64bit;
    uint32 field_offset_32bit;
#endif
} WASMStructFieldType;

typedef struct WASMStructType {
    WASMType base_type;

    /* total size of this struct object */
    uint32 total_size;
    uint16 field_count;

    uint16 ref_type_map_count;
    WASMRefTypeMap *ref_type_maps;

    /* Offsets of reference fields that need to be traced during GC.
       The first element of the table is the number of such offsets. */
    uint16 *reference_table;

    /* Field info, note that fields[i]->field_type only stores
     * the first byte of the field type, if it cannot be described
     * with one byte, then the full field type info is stored in
     * ref_type_maps */
    WASMStructFieldType fields[1];
} WASMStructType;

typedef struct WASMArrayType {
    WASMType base_type;

    uint16 elem_flags;
    uint8 elem_type;
    /* The full elem type info if the elem type cannot be
       described with one byte */
    WASMRefType *elem_ref_type;
} WASMArrayType;

#if WASM_ENABLE_STRINGREF != 0
/* stringref representation, we define it as a void * pointer here, the
 * stringref implementation can use any structure */
/*
    WasmGC heap
    +-----------------------+
    |                       |
    |   stringref           |
    |   +----------+        |             external string representation
    |   | host_ptr |--------o------+----->+------------+
    |   +----------+        |      |      |            |
    |                       |      |      +------------+
    |   stringview_wtf8/16  |      |
    |   +----------+        |      |
    |   | host_ptr |--------o------+
    |   +----------+        |      |
    |                       |      |
    |   stringview_iter     |      |
    |   +----------+        |      |
    |   | host_ptr |--------o------+
    |   +----------+        |
    |   |   pos    |        |
    |   +----------+        |
    |                       |
    +-----------------------+
*/
typedef void *WASMString;

#endif /* end of WASM_ENABLE_STRINGREF != 0 */
#endif /* end of WASM_ENABLE_GC != 0 */

typedef struct WASMTableType {
    uint8 elem_type;
    /**
     * 0: no max size and not shared
     * 1: has max size
     * 2: shared
     * 4: table64
     */
    uint8 flags;
    bool possible_grow;
    uint32 init_size;
    /* specified if (flags & 1), else it is 0x10000 */
    uint32 max_size;
#if WASM_ENABLE_GC != 0
    WASMRefType *elem_ref_type;
#endif
} WASMTableType;

typedef struct WASMTable {
    WASMTableType table_type;
#if WASM_ENABLE_GC != 0
    /* init expr for the whole table */
    InitializerExpression init_expr;
#endif
} WASMTable;

#if WASM_ENABLE_MEMORY64 != 0
typedef uint64 mem_offset_t;
#define PR_MEM_OFFSET PRIu64
#else
typedef uint32 mem_offset_t;
#define PR_MEM_OFFSET PRIu32
#endif
typedef mem_offset_t tbl_elem_idx_t;

typedef struct WASMMemory {
    uint32 flags;
    uint32 num_bytes_per_page;
    uint32 init_page_count;
    uint32 max_page_count;
} WASMMemory;
#ifndef WASM_MEMORY_T_DEFINED
#define WASM_MEMORY_T_DEFINED
typedef struct WASMMemory WASMMemoryType;
#endif

typedef struct WASMTableImport {
    char *module_name;
    char *field_name;
    WASMTableType table_type;
#if WASM_ENABLE_MULTI_MODULE != 0
    WASMModule *import_module;
    WASMTable *import_table_linked;
#endif
} WASMTableImport;

typedef struct WASMMemoryImport {
    char *module_name;
    char *field_name;
    WASMMemoryType mem_type;
#if WASM_ENABLE_MULTI_MODULE != 0
    WASMModule *import_module;
    WASMMemory *import_memory_linked;
#endif
} WASMMemoryImport;

typedef struct WASMFunctionImport {
    char *module_name;
    char *field_name;
    /* function type */
    WASMFuncType *func_type;
    /* native function pointer after linked */
    void *func_ptr_linked;
    /* signature from registered native symbols */
    const char *signature;
    /* attachment */
    void *attachment;
#if WASM_ENABLE_GC != 0
    /* the type index of this function's func_type */
    uint32 type_idx;
#endif
    bool call_conv_raw;
    bool call_conv_wasm_c_api;
#if WASM_ENABLE_MULTI_MODULE != 0
    WASMModule *import_module;
    WASMFunction *import_func_linked;
#endif
} WASMFunctionImport;

#if WASM_ENABLE_TAGS != 0
typedef struct WASMTagImport {
    char *module_name;
    char *field_name;
    uint8 attribute; /* the type of the tag (numerical) */
    uint32 type;     /* the type of the catch function (numerical)*/
    WASMFuncType *tag_type;
    void *tag_ptr_linked;

#if WASM_ENABLE_MULTI_MODULE != 0
    /* imported tag  pointer after linked */
    WASMModule *import_module;
    WASMTag *import_tag_linked;
    uint32 import_tag_index_linked;
#endif
} WASMTagImport;
#endif

typedef struct WASMGlobalType {
    uint8 val_type;
    bool is_mutable;
} WASMGlobalType;

typedef struct WASMGlobalImport {
    char *module_name;
    char *field_name;
    WASMGlobalType type;
    bool is_linked;
    /* global data after linked */
    WASMValue global_data_linked;
#if WASM_ENABLE_GC != 0
    WASMRefType *ref_type;
#endif
#if WASM_ENABLE_MULTI_MODULE != 0
    /* imported function pointer after linked */
    /* TODO: remove if not needed */
    WASMModule *import_module;
    WASMGlobal *import_global_linked;
#endif
#if WASM_ENABLE_FAST_JIT != 0
    /* The data offset of current global in global data */
    uint32 data_offset;
#endif
} WASMGlobalImport;

typedef struct WASMImport {
    uint8 kind;
    union {
        WASMFunctionImport function;
        WASMTableImport table;
        WASMMemoryImport memory;
#if WASM_ENABLE_TAGS != 0
        WASMTagImport tag;
#endif
        WASMGlobalImport global;
        struct {
            char *module_name;
            char *field_name;
        } names;
    } u;
} WASMImport;

struct WASMFunction {
#if WASM_ENABLE_CUSTOM_NAME_SECTION != 0
    char *field_name;
#endif
    /* the type of function */
    WASMFuncType *func_type;
    uint32 local_count;
    uint8 *local_types;
#if WASM_ENABLE_GC != 0
    uint16 local_ref_type_map_count;
    WASMRefTypeMap *local_ref_type_maps;
#endif

    /* cell num of parameters */
    uint16 param_cell_num;
    /* cell num of return type */
    uint16 ret_cell_num;
    /* cell num of local variables */
    uint16 local_cell_num;
    /* offset of each local, including function parameters
       and local variables */
    uint16 *local_offsets;

    uint32 max_stack_cell_num;
    uint32 max_block_num;
    uint32 code_size;
    uint8 *code;
#if WASM_ENABLE_FAST_INTERP != 0
    uint32 code_compiled_size;
    uint8 *code_compiled;
    uint8 *consts;
    uint32 const_cell_num;
#endif

#if WASM_ENABLE_GC != 0
    /* the type index of this function's func_type */
    uint32 type_idx;
#endif

#if WASM_ENABLE_EXCE_HANDLING != 0
    uint32 exception_handler_count;
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0
    /* Whether function has opcode memory.grow */
    bool has_op_memory_grow;
    /* Whether function has opcode call or call_indirect */
    bool has_op_func_call;
#endif
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
    /* Whether function has memory operation opcodes */
    bool has_memory_operations;
    /* Whether function has opcode call_indirect */
    bool has_op_call_indirect;
    /* Whether function has opcode set_global_aux_stack */
    bool has_op_set_global_aux_stack;
#endif

#if WASM_ENABLE_FAST_JIT != 0
    /* The compiled fast jit jitted code block of this function */
    void *fast_jit_jitted_code;
#if WASM_ENABLE_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0
    /* The compiled llvm jit func ptr of this function */
    void *llvm_jit_func_ptr;
    /* Code block to call fast jit jitted code of this function
       from the llvm jit jitted code */
    void *call_to_fast_jit_from_llvm_jit;
#endif
#endif
};

#if WASM_ENABLE_TAGS != 0
struct WASMTag {
    uint8 attribute; /* the attribute property of the tag (expected to be 0) */
    uint32 type; /* the type of the tag (expected valid inden in type table) */
    WASMFuncType *tag_type;
};
#endif

struct WASMGlobal {
    WASMGlobalType type;
#if WASM_ENABLE_GC != 0
    WASMRefType *ref_type;
#endif
    InitializerExpression init_expr;
#if WASM_ENABLE_FAST_JIT != 0
    /* The data offset of current global in global data */
    uint32 data_offset;
#endif
};

typedef struct WASMExport {
    char *name;
    uint8 kind;
    uint32 index;
} WASMExport;

typedef struct WASMTableSeg {
    /* 0 to 7 */
    uint32 mode;
    /* funcref or externref, elemkind will be considered as funcref */
    uint32 elem_type;
#if WASM_ENABLE_GC != 0
    WASMRefType *elem_ref_type;
#endif
    /* optional, only for active */
    uint32 table_index;
    InitializerExpression base_offset;
    uint32 value_count;
    InitializerExpression *init_values;
} WASMTableSeg;

typedef struct WASMDataSeg {
    uint32 memory_index;
    InitializerExpression base_offset;
    uint32 data_length;
#if WASM_ENABLE_BULK_MEMORY != 0
    bool is_passive;
#endif
    uint8 *data;
    bool is_data_cloned;
} WASMDataSeg;

typedef struct BlockAddr {
    const uint8 *start_addr;
    uint8 *else_addr;
    uint8 *end_addr;
} BlockAddr;

#if WASM_ENABLE_LIBC_WASI != 0
typedef struct WASIArguments {
    const char **dir_list;
    uint32 dir_count;
    const char **map_dir_list;
    uint32 map_dir_count;
    const char **env;
    uint32 env_count;
    /* in CIDR notation */
    const char **addr_pool;
    uint32 addr_count;
    const char **ns_lookup_pool;
    uint32 ns_lookup_count;
    char **argv;
    uint32 argc;
    os_raw_file_handle stdio[3];
} WASIArguments;
#endif

typedef struct StringNode {
    struct StringNode *next;
    char *str;
} StringNode, *StringList;

typedef struct BrTableCache {
    struct BrTableCache *next;
    /* Address of br_table opcode */
    uint8 *br_table_op_addr;
    uint32 br_count;
    uint32 br_depths[1];
} BrTableCache;

#if WASM_ENABLE_DEBUG_INTERP != 0
typedef struct WASMFastOPCodeNode {
    struct WASMFastOPCodeNode *next;
    uint64 offset;
    uint8 orig_op;
} WASMFastOPCodeNode;
#endif

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
typedef struct WASMCustomSection {
    struct WASMCustomSection *next;
    /* Start address of the section name */
    char *name_addr;
    /* Length of the section name decoded from leb */
    uint32 name_len;
    /* Start address of the content (name len and name skipped) */
    uint8 *content_addr;
    uint32 content_len;
} WASMCustomSection;
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
struct AOTCompData;
struct AOTCompContext;

/* Orc JIT thread arguments */
typedef struct OrcJitThreadArg {
#if WASM_ENABLE_JIT != 0
    struct AOTCompContext *comp_ctx;
#endif
    struct WASMModule *module;
    uint32 group_idx;
} OrcJitThreadArg;
#endif

struct WASMModuleInstance;

struct WASMModule {
    /* Module type, for module loaded from WASM bytecode binary,
       this field is Wasm_Module_Bytecode;
       for module loaded from AOT file, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModule structure. */
    uint32 module_type;

    /* the package version read from the WASM file */
    uint32 package_version;

    uint32 type_count;
    uint32 import_count;
    uint32 function_count;
    uint32 table_count;
    uint32 memory_count;
#if WASM_ENABLE_TAGS != 0
    uint32 tag_count;
#endif
    uint32 global_count;
    uint32 export_count;
    uint32 table_seg_count;
    /* data seg count read from data segment section */
    uint32 data_seg_count;
#if WASM_ENABLE_BULK_MEMORY != 0
    /* data count read from datacount section */
    uint32 data_seg_count1;
#endif
#if WASM_ENABLE_GC != 0
#if WASM_ENABLE_STRINGREF != 0
    uint32 string_literal_count;
    uint32 *string_literal_lengths;
    const uint8 **string_literal_ptrs;
#endif
#endif

    uint32 import_function_count;
    uint32 import_table_count;
    uint32 import_memory_count;
#if WASM_ENABLE_TAGS != 0
    uint32 import_tag_count;
#endif
    uint32 import_global_count;

    WASMImport *import_functions;
    WASMImport *import_tables;
    WASMImport *import_memories;
#if WASM_ENABLE_TAGS != 0
    WASMImport *import_tags;
#endif
    WASMImport *import_globals;

    WASMType **types;
    WASMImport *imports;
    WASMFunction **functions;
    WASMTable *tables;
    WASMMemory *memories;
#if WASM_ENABLE_TAGS != 0
    WASMTag **tags;
#endif
    WASMGlobal *globals;
    WASMExport *exports;
    WASMTableSeg *table_segments;
    WASMDataSeg **data_segments;
    uint32 start_function;

    /* total global variable size */
    uint32 global_data_size;

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

    /* the index of malloc/free function,
       -1 means unexported */
    uint32 malloc_function;
    uint32 free_function;

    /* the index of __retain function,
       -1 means unexported */
    uint32 retain_function;

    /* Whether there is possible memory grow, e.g. memory.grow opcode */
    bool possible_memory_grow;

    StringList const_str_list;
#if WASM_ENABLE_FAST_INTERP == 0
    bh_list br_table_cache_list_head;
    bh_list *br_table_cache_list;
#endif

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
#endif
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0 || WASM_ENABLE_DEBUG_AOT != 0
    bh_list fast_opcode_list;
    uint8 *buf_code;
    uint64 buf_code_size;
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0 || WASM_ENABLE_FAST_JIT != 0  \
    || WASM_ENABLE_DUMP_CALL_STACK != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0
    uint8 *load_addr;
    uint64 load_size;
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0                         \
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
        && WASM_ENABLE_LAZY_JIT != 0)
    /**
     * List of instances referred to this module. When source debugging
     * feature is enabled, the debugger may modify the code section of
     * the module, so we need to report a warning if user create several
     * instances based on the same module.
     *
     * Also add the instance to the list for Fast JIT to LLVM JIT
     * tier-up, since we need to lazily update the LLVM func pointers
     * in the instance.
     */
    struct WASMModuleInstance *instance_list;
    korp_mutex instance_list_lock;
#endif

#if WASM_ENABLE_CUSTOM_NAME_SECTION != 0
    const uint8 *name_section_buf;
    const uint8 *name_section_buf_end;
#endif

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
    WASMCustomSection *custom_section_list;
#endif

#if WASM_ENABLE_FAST_JIT != 0
    /**
     * func pointers of Fast JITed (un-imported) functions
     * for non Multi-Tier JIT mode:
     *   (1) when lazy jit is disabled, each pointer is set to the compiled
     *       fast jit jitted code
     *   (2) when lazy jit is enabled, each pointer is firstly inited as
     *       jit_global->compile_fast_jit_and_then_call, and then set to the
     *       compiled fast jit jitted code when it is called (the stub will
     *       compile the jit function and then update itself)
     * for Multi-Tier JIT mode:
     *   each pointer is firstly inited as compile_fast_jit_and_then_call,
     *   and then set to the compiled fast jit jitted code when it is called,
     *   and when the llvm jit func ptr of the same function is compiled, it
     *   will be set to call_to_llvm_jit_from_fast_jit of this function type
     *   (tier-up from fast-jit to llvm-jit)
     */
    void **fast_jit_func_ptrs;
    /* locks for Fast JIT lazy compilation */
    korp_mutex fast_jit_thread_locks[WASM_ORC_JIT_BACKEND_THREAD_NUM];
    bool fast_jit_thread_locks_inited[WASM_ORC_JIT_BACKEND_THREAD_NUM];
#endif

#if WASM_ENABLE_JIT != 0
    struct AOTCompData *comp_data;
    struct AOTCompContext *comp_ctx;
    /**
     * func pointers of LLVM JITed (un-imported) functions
     * for non Multi-Tier JIT mode:
     *   each pointer is set to the looked up llvm jit func ptr, note that it
     *   is a stub and will trigger the actual compilation when it is called
     * for Multi-Tier JIT mode:
     *   each pointer is inited as call_to_fast_jit code block, when the llvm
     *   jit func ptr is actually compiled, it is set to the compiled llvm jit
     *   func ptr
     */
    void **func_ptrs;
    /* whether the func pointers are compiled */
    bool *func_ptrs_compiled;
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
    /* backend compilation threads */
    korp_tid orcjit_threads[WASM_ORC_JIT_BACKEND_THREAD_NUM];
    /* backend thread arguments */
    OrcJitThreadArg orcjit_thread_args[WASM_ORC_JIT_BACKEND_THREAD_NUM];
    /* whether to stop the compilation of backend threads */
    bool orcjit_stop_compiling;
#endif

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    /* wait lock/cond for the synchronization of
       the llvm jit initialization */
    korp_mutex tierup_wait_lock;
    korp_cond tierup_wait_cond;
    bool tierup_wait_lock_inited;
    korp_tid llvm_jit_init_thread;
    /* whether the llvm jit is initialized */
    bool llvm_jit_inited;
    /* Whether to enable llvm jit compilation:
       it is set to true only when there is a module instance starts to
       run with running mode Mode_LLVM_JIT or Mode_Multi_Tier_JIT,
       since no need to enable llvm jit compilation for Mode_Interp and
       Mode_Fast_JIT, so as to improve performance for them */
    bool enable_llvm_jit_compilation;
    /* The count of groups which finish compiling the fast jit
       functions in that group */
    uint32 fast_jit_ready_groups;
#endif

#if WASM_ENABLE_WAMR_COMPILER != 0
    bool is_simd_used;
    bool is_ref_types_used;
    bool is_bulk_memory_used;
#endif

    /* user defined name */
    char *name;

    /* Whether the underlying wasm binary buffer can be freed */
    bool is_binary_freeable;
};

typedef struct BlockType {
    /* Block type may be expressed in one of two forms:
     * either by the type of the single return value or
     * by a type index of module.
     */
    union {
        struct {
            uint8 type;
#if WASM_ENABLE_GC != 0
            WASMRefTypeMap ref_type_map;
#endif
        } value_type;
        WASMFuncType *type;
    } u;
    bool is_value_type;
} BlockType;

typedef struct WASMBranchBlock {
    uint8 *begin_addr;
    uint8 *target_addr;
    uint32 *frame_sp;
    uint32 cell_num;
#if WASM_ENABLE_EXCE_HANDLING != 0
    /* in exception handling, label_type needs to be stored to lookup exception
     * handlers */
    uint8 label_type;
#endif
} WASMBranchBlock;

/**
 * Align an unsigned value on a alignment boundary.
 *
 * @param v the value to be aligned
 * @param b the alignment boundary (2, 4, 8, ...)
 *
 * @return the aligned value
 */
inline static unsigned
align_uint(unsigned v, unsigned b)
{
    unsigned m = b - 1;
    return (v + m) & ~m;
}

/**
 * Align an 64 bit unsigned value on a alignment boundary.
 *
 * @param v the value to be aligned
 * @param b the alignment boundary (2, 4, 8, ...)
 *
 * @return the aligned value
 */
inline static uint64
align_uint64(uint64 v, uint64 b)
{
    uint64 m = b - 1;
    return (v + m) & ~m;
}

/**
 * Check whether a piece of data is out of range
 *
 * @param offset the offset that the data starts
 * @param len the length of the data
 * @param max_size the maximum size of the data range
 *
 * @return true if out of range, false otherwise
 */
inline static bool
offset_len_out_of_bounds(uint32 offset, uint32 len, uint32 max_size)
{
    if (offset + len < offset /* integer overflow */
        || offset + len > max_size)
        return true;
    return false;
}

/**
 * Return the hash value of c string.
 */
inline static uint32
wasm_string_hash(const char *str)
{
    unsigned h = (unsigned)strlen(str);
    const uint8 *p = (uint8 *)str;
    const uint8 *end = p + h;

    while (p != end)
        h = ((h << 5) - h) + *p++;
    return h;
}

/**
 * Whether two c strings are equal.
 */
inline static bool
wasm_string_equal(const char *s1, const char *s2)
{
    return strcmp(s1, s2) == 0 ? true : false;
}

/**
 * Return the byte size of value type with specific pointer size.
 *
 * Note: Please use wasm_value_type_size for interpreter, only aot compiler
 * can use this API directly to calculate type size for different target
 */
inline static uint32
wasm_value_type_size_internal(uint8 value_type, uint8 pointer_size)
{
    if (value_type == VALUE_TYPE_VOID)
        return 0;
    else if (value_type == VALUE_TYPE_I32 || value_type == VALUE_TYPE_F32
             || value_type == VALUE_TYPE_ANY)
        return sizeof(int32);
    else if (value_type == VALUE_TYPE_I64 || value_type == VALUE_TYPE_F64)
        return sizeof(int64);
#if WASM_ENABLE_SIMD != 0
    else if (value_type == VALUE_TYPE_V128)
        return sizeof(int64) * 2;
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    else if (value_type == VALUE_TYPE_FUNCREF
             || value_type == VALUE_TYPE_EXTERNREF)
        return sizeof(uint32);
#elif WASM_ENABLE_GC != 0
    else if ((value_type >= (uint8)REF_TYPE_ARRAYREF               /* 0x6A */
              && value_type <= (uint8)REF_TYPE_NULLFUNCREF)        /* 0x73 */
             || (value_type >= (uint8)REF_TYPE_HT_NULLABLE         /* 0x63 */
                 && value_type <= (uint8)REF_TYPE_HT_NON_NULLABLE) /* 0x64 */
#if WASM_ENABLE_STRINGREF != 0
             || (value_type >= (uint8)REF_TYPE_STRINGVIEWWTF8      /* 0x66 */
                 && value_type <= (uint8)REF_TYPE_STRINGREF)       /* 0x67 */
             || (value_type >= (uint8)REF_TYPE_STRINGVIEWITER      /* 0x61 */
                 && value_type <= (uint8)REF_TYPE_STRINGVIEWWTF16) /* 0x62 */
#endif
    )
        return pointer_size;
    else if (value_type == PACKED_TYPE_I8)
        return sizeof(int8);
    else if (value_type == PACKED_TYPE_I16)
        return sizeof(int16);
#endif
    else {
        bh_assert(0 && "Unknown value type. It should be handled ahead.");
    }
#if WASM_ENABLE_GC == 0
    (void)pointer_size;
#endif
    return 0;
}

/**
 * Return the cell num of value type with specific pointer size.
 *
 * Note: Please use wasm_value_type_cell_num for interpreter, only aot compiler
 * can use this API directly to calculate type cell num for different target
 */
inline static uint16
wasm_value_type_cell_num_internal(uint8 value_type, uint8 pointer_size)
{
    return wasm_value_type_size_internal(value_type, pointer_size) / 4;
}

/**
 * Return the byte size of value type.
 */
inline static uint32
wasm_value_type_size(uint8 value_type)
{
    return wasm_value_type_size_internal(value_type, sizeof(uintptr_t));
}

inline static uint16
wasm_value_type_cell_num(uint8 value_type)
{
    return wasm_value_type_size(value_type) / 4;
}

inline static uint32
wasm_get_cell_num(const uint8 *types, uint32 type_count)
{
    uint32 cell_num = 0;
    uint32 i;
    for (i = 0; i < type_count; i++)
        cell_num += wasm_value_type_cell_num(types[i]);
    return cell_num;
}

#if WASM_ENABLE_REF_TYPES != 0
inline static uint16
wasm_value_type_cell_num_outside(uint8 value_type)
{
    if (VALUE_TYPE_EXTERNREF == value_type) {
        return sizeof(uintptr_t) / sizeof(uint32);
    }
    else {
        return wasm_value_type_cell_num(value_type);
    }
}
#endif

#if WASM_ENABLE_GC == 0
inline static bool
wasm_type_equal(const WASMType *type1, const WASMType *type2,
                const WASMTypePtr *types, uint32 type_count)
{
    const WASMFuncType *func_type1 = (const WASMFuncType *)type1;
    const WASMFuncType *func_type2 = (const WASMFuncType *)type2;

    if (type1 == type2) {
        return true;
    }

    return (func_type1->param_count == func_type2->param_count
            && func_type1->result_count == func_type2->result_count
            && memcmp(
                   func_type1->types, func_type2->types,
                   (uint32)(func_type1->param_count + func_type1->result_count))
                   == 0)
               ? true
               : false;
    (void)types;
    (void)type_count;
}
#else
/* implemented in gc_type.c */
bool
wasm_type_equal(const WASMType *type1, const WASMType *type2,
                const WASMTypePtr *types, uint32 type_count);
#endif

inline static uint32
wasm_get_smallest_type_idx(const WASMTypePtr *types, uint32 type_count,
                           uint32 cur_type_idx)
{
    uint32 i;

    for (i = 0; i < cur_type_idx; i++) {
        if (wasm_type_equal(types[cur_type_idx], types[i], types, type_count))
            return i;
    }
    return cur_type_idx;
}

#if WASM_ENABLE_GC == 0
static inline uint32
block_type_get_param_types(BlockType *block_type, uint8 **p_param_types)
#else
static inline uint32
block_type_get_param_types(BlockType *block_type, uint8 **p_param_types,
                           WASMRefTypeMap **p_param_reftype_maps,
                           uint32 *p_param_reftype_map_count)
#endif
{
    uint32 param_count = 0;
    if (!block_type->is_value_type) {
        WASMFuncType *func_type = block_type->u.type;
        *p_param_types = func_type->types;
        param_count = func_type->param_count;
#if WASM_ENABLE_GC != 0
        *p_param_reftype_maps = func_type->ref_type_maps;
        *p_param_reftype_map_count = (uint32)(func_type->result_ref_type_maps
                                              - func_type->ref_type_maps);
#endif
    }
    else {
        *p_param_types = NULL;
        param_count = 0;
#if WASM_ENABLE_GC != 0
        *p_param_reftype_maps = NULL;
        *p_param_reftype_map_count = 0;
#endif
    }

    return param_count;
}

#if WASM_ENABLE_GC == 0
static inline uint32
block_type_get_result_types(BlockType *block_type, uint8 **p_result_types)
#else
static inline uint32
block_type_get_result_types(BlockType *block_type, uint8 **p_result_types,
                            WASMRefTypeMap **p_result_reftype_maps,
                            uint32 *p_result_reftype_map_count)
#endif
{
    uint32 result_count = 0;
    uint8 *result_types = NULL;
#if WASM_ENABLE_GC != 0
    uint8 type;
    uint32 result_reftype_map_count = 0;
    WASMRefTypeMap *result_reftype_maps = NULL;
#endif

    if (block_type->is_value_type) {
        if (block_type->u.value_type.type != VALUE_TYPE_VOID) {
            result_types = &block_type->u.value_type.type;
            result_count = 1;
#if WASM_ENABLE_GC != 0
            type = block_type->u.value_type.type;
            if (type == (uint8)REF_TYPE_HT_NULLABLE
                || type == (uint8)REF_TYPE_HT_NON_NULLABLE) {
                result_reftype_maps = &block_type->u.value_type.ref_type_map;
                result_reftype_map_count = 1;
            }
#endif
        }
    }
    else {
        WASMFuncType *func_type = block_type->u.type;
        result_types = func_type->types + func_type->param_count;
        result_count = func_type->result_count;
#if WASM_ENABLE_GC != 0
        result_reftype_maps = func_type->result_ref_type_maps;
        result_reftype_map_count = (uint32)(func_type->ref_type_map_count
                                            - (func_type->result_ref_type_maps
                                               - func_type->ref_type_maps));
#endif
    }
    *p_result_types = result_types;
#if WASM_ENABLE_GC != 0
    *p_result_reftype_maps = result_reftype_maps;
    *p_result_reftype_map_count = result_reftype_map_count;
#endif
    return result_count;
}

static inline uint32
block_type_get_arity(const BlockType *block_type, uint8 label_type)
{
    if (label_type == LABEL_TYPE_LOOP) {
        if (block_type->is_value_type)
            return 0;
        else
            return block_type->u.type->param_count;
    }
    else {
        if (block_type->is_value_type) {
            return block_type->u.value_type.type != VALUE_TYPE_VOID ? 1 : 0;
        }
        else
            return block_type->u.type->result_count;
    }
    return 0;
}

#ifdef __cplusplus
} /* end of extern "C" */
#endif

#endif /* end of _WASM_H_ */
