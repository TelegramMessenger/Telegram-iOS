/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_OPCODE_H
#define _WASM_OPCODE_H

#include "wasm.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum WASMOpcode {
    /* control instructions */
    WASM_OP_UNREACHABLE = 0x00, /* unreachable */
    WASM_OP_NOP = 0x01,         /* nop */
    WASM_OP_BLOCK = 0x02,       /* block */
    WASM_OP_LOOP = 0x03,        /* loop */
    WASM_OP_IF = 0x04,          /* if */
    WASM_OP_ELSE = 0x05,        /* else */
    WASM_OP_TRY = 0x06,         /* try */
    WASM_OP_CATCH = 0x07,       /* catch* */
    WASM_OP_THROW = 0x08,       /* throw of a try catch */
    WASM_OP_RETHROW = 0x09,     /* rethrow of a try catch */
    WASM_OP_UNUSED_0x0a = 0x0a,

    WASM_OP_END = 0x0b,                  /* end */
    WASM_OP_BR = 0x0c,                   /* br */
    WASM_OP_BR_IF = 0x0d,                /* br if */
    WASM_OP_BR_TABLE = 0x0e,             /* br table */
    WASM_OP_RETURN = 0x0f,               /* return */
    WASM_OP_CALL = 0x10,                 /* call */
    WASM_OP_CALL_INDIRECT = 0x11,        /* call_indirect */
    WASM_OP_RETURN_CALL = 0x12,          /* return_call */
    WASM_OP_RETURN_CALL_INDIRECT = 0x13, /* return_call_indirect */
    WASM_OP_CALL_REF = 0x14,             /* call_ref */
    WASM_OP_RETURN_CALL_REF = 0x15,      /* return_call_ref */

    WASM_OP_UNUSED_0x16 = 0x16,
    WASM_OP_UNUSED_0x17 = 0x17,

    WASM_OP_DELEGATE = 0x18,  /* delegate block of the try catch*/
    WASM_OP_CATCH_ALL = 0x19, /* a catch_all handler in a try block */

    /* parametric instructions */
    WASM_OP_DROP = 0x1a,     /* drop */
    WASM_OP_SELECT = 0x1b,   /* select */
    WASM_OP_SELECT_T = 0x1c, /* select t */

    WASM_OP_GET_GLOBAL_64 = 0x1d,
    WASM_OP_SET_GLOBAL_64 = 0x1e,
    WASM_OP_SET_GLOBAL_AUX_STACK = 0x1f,

    /* variable instructions */
    WASM_OP_GET_LOCAL = 0x20,  /* get_local */
    WASM_OP_SET_LOCAL = 0x21,  /* set_local */
    WASM_OP_TEE_LOCAL = 0x22,  /* tee_local */
    WASM_OP_GET_GLOBAL = 0x23, /* get_global */
    WASM_OP_SET_GLOBAL = 0x24, /* set_global */

    WASM_OP_TABLE_GET = 0x25, /* table.get */
    WASM_OP_TABLE_SET = 0x26, /* table.set */
    WASM_OP_UNUSED_0x27 = 0x27,

    /* memory instructions */
    WASM_OP_I32_LOAD = 0x28,     /* i32.load */
    WASM_OP_I64_LOAD = 0x29,     /* i64.load */
    WASM_OP_F32_LOAD = 0x2a,     /* f32.load */
    WASM_OP_F64_LOAD = 0x2b,     /* f64.load */
    WASM_OP_I32_LOAD8_S = 0x2c,  /* i32.load8_s */
    WASM_OP_I32_LOAD8_U = 0x2d,  /* i32.load8_u */
    WASM_OP_I32_LOAD16_S = 0x2e, /* i32.load16_s */
    WASM_OP_I32_LOAD16_U = 0x2f, /* i32.load16_u */
    WASM_OP_I64_LOAD8_S = 0x30,  /* i64.load8_s */
    WASM_OP_I64_LOAD8_U = 0x31,  /* i64.load8_u */
    WASM_OP_I64_LOAD16_S = 0x32, /* i64.load16_s */
    WASM_OP_I64_LOAD16_U = 0x33, /* i64.load16_u */
    WASM_OP_I64_LOAD32_S = 0x34, /* i32.load32_s */
    WASM_OP_I64_LOAD32_U = 0x35, /* i32.load32_u */
    WASM_OP_I32_STORE = 0x36,    /* i32.store */
    WASM_OP_I64_STORE = 0x37,    /* i64.store */
    WASM_OP_F32_STORE = 0x38,    /* f32.store */
    WASM_OP_F64_STORE = 0x39,    /* f64.store */
    WASM_OP_I32_STORE8 = 0x3a,   /* i32.store8 */
    WASM_OP_I32_STORE16 = 0x3b,  /* i32.store16 */
    WASM_OP_I64_STORE8 = 0x3c,   /* i64.store8 */
    WASM_OP_I64_STORE16 = 0x3d,  /* i64.store16 */
    WASM_OP_I64_STORE32 = 0x3e,  /* i64.store32 */
    WASM_OP_MEMORY_SIZE = 0x3f,  /* memory.size */
    WASM_OP_MEMORY_GROW = 0x40,  /* memory.grow */

    /* constant instructions */
    WASM_OP_I32_CONST = 0x41, /* i32.const */
    WASM_OP_I64_CONST = 0x42, /* i64.const */
    WASM_OP_F32_CONST = 0x43, /* f32.const */
    WASM_OP_F64_CONST = 0x44, /* f64.const */

    /* comparison instructions */
    WASM_OP_I32_EQZ = 0x45,  /* i32.eqz */
    WASM_OP_I32_EQ = 0x46,   /* i32.eq */
    WASM_OP_I32_NE = 0x47,   /* i32.ne */
    WASM_OP_I32_LT_S = 0x48, /* i32.lt_s */
    WASM_OP_I32_LT_U = 0x49, /* i32.lt_u */
    WASM_OP_I32_GT_S = 0x4a, /* i32.gt_s */
    WASM_OP_I32_GT_U = 0x4b, /* i32.gt_u */
    WASM_OP_I32_LE_S = 0x4c, /* i32.le_s */
    WASM_OP_I32_LE_U = 0x4d, /* i32.le_u */
    WASM_OP_I32_GE_S = 0x4e, /* i32.ge_s */
    WASM_OP_I32_GE_U = 0x4f, /* i32.ge_u */

    WASM_OP_I64_EQZ = 0x50,  /* i64.eqz */
    WASM_OP_I64_EQ = 0x51,   /* i64.eq */
    WASM_OP_I64_NE = 0x52,   /* i64.ne */
    WASM_OP_I64_LT_S = 0x53, /* i64.lt_s */
    WASM_OP_I64_LT_U = 0x54, /* i64.lt_u */
    WASM_OP_I64_GT_S = 0x55, /* i64.gt_s */
    WASM_OP_I64_GT_U = 0x56, /* i64.gt_u */
    WASM_OP_I64_LE_S = 0x57, /* i64.le_s */
    WASM_OP_I64_LE_U = 0x58, /* i64.le_u */
    WASM_OP_I64_GE_S = 0x59, /* i64.ge_s */
    WASM_OP_I64_GE_U = 0x5a, /* i64.ge_u */

    WASM_OP_F32_EQ = 0x5b, /* f32.eq */
    WASM_OP_F32_NE = 0x5c, /* f32.ne */
    WASM_OP_F32_LT = 0x5d, /* f32.lt */
    WASM_OP_F32_GT = 0x5e, /* f32.gt */
    WASM_OP_F32_LE = 0x5f, /* f32.le */
    WASM_OP_F32_GE = 0x60, /* f32.ge */

    WASM_OP_F64_EQ = 0x61, /* f64.eq */
    WASM_OP_F64_NE = 0x62, /* f64.ne */
    WASM_OP_F64_LT = 0x63, /* f64.lt */
    WASM_OP_F64_GT = 0x64, /* f64.gt */
    WASM_OP_F64_LE = 0x65, /* f64.le */
    WASM_OP_F64_GE = 0x66, /* f64.ge */

    /* numeric operators */
    WASM_OP_I32_CLZ = 0x67,    /* i32.clz */
    WASM_OP_I32_CTZ = 0x68,    /* i32.ctz */
    WASM_OP_I32_POPCNT = 0x69, /* i32.popcnt */
    WASM_OP_I32_ADD = 0x6a,    /* i32.add */
    WASM_OP_I32_SUB = 0x6b,    /* i32.sub */
    WASM_OP_I32_MUL = 0x6c,    /* i32.mul */
    WASM_OP_I32_DIV_S = 0x6d,  /* i32.div_s */
    WASM_OP_I32_DIV_U = 0x6e,  /* i32.div_u */
    WASM_OP_I32_REM_S = 0x6f,  /* i32.rem_s */
    WASM_OP_I32_REM_U = 0x70,  /* i32.rem_u */
    WASM_OP_I32_AND = 0x71,    /* i32.and */
    WASM_OP_I32_OR = 0x72,     /* i32.or */
    WASM_OP_I32_XOR = 0x73,    /* i32.xor */
    WASM_OP_I32_SHL = 0x74,    /* i32.shl */
    WASM_OP_I32_SHR_S = 0x75,  /* i32.shr_s */
    WASM_OP_I32_SHR_U = 0x76,  /* i32.shr_u */
    WASM_OP_I32_ROTL = 0x77,   /* i32.rotl */
    WASM_OP_I32_ROTR = 0x78,   /* i32.rotr */

    WASM_OP_I64_CLZ = 0x79,    /* i64.clz */
    WASM_OP_I64_CTZ = 0x7a,    /* i64.ctz */
    WASM_OP_I64_POPCNT = 0x7b, /* i64.popcnt */
    WASM_OP_I64_ADD = 0x7c,    /* i64.add */
    WASM_OP_I64_SUB = 0x7d,    /* i64.sub */
    WASM_OP_I64_MUL = 0x7e,    /* i64.mul */
    WASM_OP_I64_DIV_S = 0x7f,  /* i64.div_s */
    WASM_OP_I64_DIV_U = 0x80,  /* i64.div_u */
    WASM_OP_I64_REM_S = 0x81,  /* i64.rem_s */
    WASM_OP_I64_REM_U = 0x82,  /* i64.rem_u */
    WASM_OP_I64_AND = 0x83,    /* i64.and */
    WASM_OP_I64_OR = 0x84,     /* i64.or */
    WASM_OP_I64_XOR = 0x85,    /* i64.xor */
    WASM_OP_I64_SHL = 0x86,    /* i64.shl */
    WASM_OP_I64_SHR_S = 0x87,  /* i64.shr_s */
    WASM_OP_I64_SHR_U = 0x88,  /* i64.shr_u */
    WASM_OP_I64_ROTL = 0x89,   /* i64.rotl */
    WASM_OP_I64_ROTR = 0x8a,   /* i64.rotr */

    WASM_OP_F32_ABS = 0x8b,      /* f32.abs */
    WASM_OP_F32_NEG = 0x8c,      /* f32.neg */
    WASM_OP_F32_CEIL = 0x8d,     /* f32.ceil */
    WASM_OP_F32_FLOOR = 0x8e,    /* f32.floor */
    WASM_OP_F32_TRUNC = 0x8f,    /* f32.trunc */
    WASM_OP_F32_NEAREST = 0x90,  /* f32.nearest */
    WASM_OP_F32_SQRT = 0x91,     /* f32.sqrt */
    WASM_OP_F32_ADD = 0x92,      /* f32.add */
    WASM_OP_F32_SUB = 0x93,      /* f32.sub */
    WASM_OP_F32_MUL = 0x94,      /* f32.mul */
    WASM_OP_F32_DIV = 0x95,      /* f32.div */
    WASM_OP_F32_MIN = 0x96,      /* f32.min */
    WASM_OP_F32_MAX = 0x97,      /* f32.max */
    WASM_OP_F32_COPYSIGN = 0x98, /* f32.copysign */

    WASM_OP_F64_ABS = 0x99,      /* f64.abs */
    WASM_OP_F64_NEG = 0x9a,      /* f64.neg */
    WASM_OP_F64_CEIL = 0x9b,     /* f64.ceil */
    WASM_OP_F64_FLOOR = 0x9c,    /* f64.floor */
    WASM_OP_F64_TRUNC = 0x9d,    /* f64.trunc */
    WASM_OP_F64_NEAREST = 0x9e,  /* f64.nearest */
    WASM_OP_F64_SQRT = 0x9f,     /* f64.sqrt */
    WASM_OP_F64_ADD = 0xa0,      /* f64.add */
    WASM_OP_F64_SUB = 0xa1,      /* f64.sub */
    WASM_OP_F64_MUL = 0xa2,      /* f64.mul */
    WASM_OP_F64_DIV = 0xa3,      /* f64.div */
    WASM_OP_F64_MIN = 0xa4,      /* f64.min */
    WASM_OP_F64_MAX = 0xa5,      /* f64.max */
    WASM_OP_F64_COPYSIGN = 0xa6, /* f64.copysign */

    /* conversions */
    WASM_OP_I32_WRAP_I64 = 0xa7,    /* i32.wrap/i64 */
    WASM_OP_I32_TRUNC_S_F32 = 0xa8, /* i32.trunc_s/f32 */
    WASM_OP_I32_TRUNC_U_F32 = 0xa9, /* i32.trunc_u/f32 */
    WASM_OP_I32_TRUNC_S_F64 = 0xaa, /* i32.trunc_s/f64 */
    WASM_OP_I32_TRUNC_U_F64 = 0xab, /* i32.trunc_u/f64 */

    WASM_OP_I64_EXTEND_S_I32 = 0xac, /* i64.extend_s/i32 */
    WASM_OP_I64_EXTEND_U_I32 = 0xad, /* i64.extend_u/i32 */
    WASM_OP_I64_TRUNC_S_F32 = 0xae,  /* i64.trunc_s/f32 */
    WASM_OP_I64_TRUNC_U_F32 = 0xaf,  /* i64.trunc_u/f32 */
    WASM_OP_I64_TRUNC_S_F64 = 0xb0,  /* i64.trunc_s/f64 */
    WASM_OP_I64_TRUNC_U_F64 = 0xb1,  /* i64.trunc_u/f64 */

    WASM_OP_F32_CONVERT_S_I32 = 0xb2, /* f32.convert_s/i32 */
    WASM_OP_F32_CONVERT_U_I32 = 0xb3, /* f32.convert_u/i32 */
    WASM_OP_F32_CONVERT_S_I64 = 0xb4, /* f32.convert_s/i64 */
    WASM_OP_F32_CONVERT_U_I64 = 0xb5, /* f32.convert_u/i64 */
    WASM_OP_F32_DEMOTE_F64 = 0xb6,    /* f32.demote/f64 */

    WASM_OP_F64_CONVERT_S_I32 = 0xb7, /* f64.convert_s/i32 */
    WASM_OP_F64_CONVERT_U_I32 = 0xb8, /* f64.convert_u/i32 */
    WASM_OP_F64_CONVERT_S_I64 = 0xb9, /* f64.convert_s/i64 */
    WASM_OP_F64_CONVERT_U_I64 = 0xba, /* f64.convert_u/i64 */
    WASM_OP_F64_PROMOTE_F32 = 0xbb,   /* f64.promote/f32 */

    /* reinterpretations */
    WASM_OP_I32_REINTERPRET_F32 = 0xbc, /* i32.reinterpret/f32 */
    WASM_OP_I64_REINTERPRET_F64 = 0xbd, /* i64.reinterpret/f64 */
    WASM_OP_F32_REINTERPRET_I32 = 0xbe, /* f32.reinterpret/i32 */
    WASM_OP_F64_REINTERPRET_I64 = 0xbf, /* f64.reinterpret/i64 */

    WASM_OP_I32_EXTEND8_S = 0xc0,  /* i32.extend8_s */
    WASM_OP_I32_EXTEND16_S = 0xc1, /* i32.extend16_s */
    WASM_OP_I64_EXTEND8_S = 0xc2,  /* i64.extend8_s */
    WASM_OP_I64_EXTEND16_S = 0xc3, /* i64.extend16_s */
    WASM_OP_I64_EXTEND32_S = 0xc4, /* i64.extend32_s */

    /* drop/select specified types*/
    WASM_OP_DROP_64 = 0xc5,
    WASM_OP_SELECT_64 = 0xc6,

    /* extend op code */
    EXT_OP_GET_LOCAL_FAST = 0xc7,
    EXT_OP_SET_LOCAL_FAST_I64 = 0xc8,
    EXT_OP_SET_LOCAL_FAST = 0xc9,
    EXT_OP_TEE_LOCAL_FAST = 0xca,
    EXT_OP_TEE_LOCAL_FAST_I64 = 0xcb,
    EXT_OP_COPY_STACK_TOP = 0xcc,
    EXT_OP_COPY_STACK_TOP_I64 = 0xcd,
    EXT_OP_COPY_STACK_VALUES = 0xce,

    WASM_OP_IMPDEP = 0xcf,

    WASM_OP_REF_NULL = 0xd0,        /* ref.null */
    WASM_OP_REF_IS_NULL = 0xd1,     /* ref.is_null */
    WASM_OP_REF_FUNC = 0xd2,        /* ref.func */
    WASM_OP_REF_EQ = 0xd3,          /* ref.eq */
    WASM_OP_REF_AS_NON_NULL = 0xd4, /* ref.as_non_null */
    WASM_OP_BR_ON_NULL = 0xd5,      /* br_on_null */
    WASM_OP_BR_ON_NON_NULL = 0xd6,  /* br_on_non_null */

    EXT_OP_BLOCK = 0xd7,          /* block with blocktype */
    EXT_OP_LOOP = 0xd8,           /* loop with blocktype */
    EXT_OP_IF = 0xd9,             /* if with blocktype */
    EXT_OP_BR_TABLE_CACHE = 0xda, /* br_table from cache */

    EXT_OP_TRY = 0xdb, /* try block with blocktype */

#if WASM_ENABLE_DEBUG_INTERP != 0
    DEBUG_OP_BREAK = 0xdc, /* debug break point */
#endif

#if WASM_ENABLE_SIMDE != 0
    EXT_OP_SET_LOCAL_FAST_V128 = 0xdd,
    EXT_OP_TEE_LOCAL_FAST_V128 = 0xde,
    EXT_OP_COPY_STACK_TOP_V128 = 0xdf,
    WASM_OP_GET_GLOBAL_V128 = 0xe0,
    WASM_OP_SET_GLOBAL_V128 = 0xe1,
    WASM_OP_SELECT_128 = 0xe2,
#endif

    /* Post-MVP extend op prefix */
    WASM_OP_GC_PREFIX = 0xfb,
    WASM_OP_MISC_PREFIX = 0xfc,
    WASM_OP_SIMD_PREFIX = 0xfd,
    WASM_OP_ATOMIC_PREFIX = 0xfe,
} WASMOpcode;

typedef enum WASMGCEXTOpcode {
    WASM_OP_STRUCT_NEW = 0x00,         /* struct.new */
    WASM_OP_STRUCT_NEW_DEFAULT = 0x01, /* struct.new_default */
    WASM_OP_STRUCT_GET = 0x02,         /* struct.get */
    WASM_OP_STRUCT_GET_S = 0x03,       /* struct.get_s */
    WASM_OP_STRUCT_GET_U = 0x04,       /* struct.get_u */
    WASM_OP_STRUCT_SET = 0x05,         /* struct.set */

    WASM_OP_ARRAY_NEW = 0x06,         /* array.new */
    WASM_OP_ARRAY_NEW_DEFAULT = 0x07, /* array.new_default */
    WASM_OP_ARRAY_NEW_FIXED = 0x08,   /* array.new_fixed */
    WASM_OP_ARRAY_NEW_DATA = 0x09,    /* array.new_data */
    WASM_OP_ARRAY_NEW_ELEM = 0x0A,    /* array.new_elem */
    WASM_OP_ARRAY_GET = 0x0B,         /* array.get */
    WASM_OP_ARRAY_GET_S = 0x0C,       /* array.get_s */
    WASM_OP_ARRAY_GET_U = 0x0D,       /* array.get_u */
    WASM_OP_ARRAY_SET = 0x0E,         /* array.set */
    WASM_OP_ARRAY_LEN = 0x0F,         /* array.len */
    WASM_OP_ARRAY_FILL = 0x10,        /* array.fill */
    WASM_OP_ARRAY_COPY = 0x11,        /* array.copy */
    WASM_OP_ARRAY_INIT_DATA = 0x12,
    /* array.init_data */ /* TODO */
    WASM_OP_ARRAY_INIT_ELEM = 0x13,
    /* array.init_elem */ /* TODO */

    WASM_OP_REF_TEST = 0x14,          /* ref.test */
    WASM_OP_REF_TEST_NULLABLE = 0x15, /* ref.test_nullable */
    WASM_OP_REF_CAST = 0x16,          /* ref.cast */
    WASM_OP_REF_CAST_NULLABLE = 0x17, /* ref.cast_nullable */

    WASM_OP_BR_ON_CAST = 0x18,      /* br_on_cast */
    WASM_OP_BR_ON_CAST_FAIL = 0x19, /* br_on_cast_fail */

    WASM_OP_ANY_CONVERT_EXTERN = 0x1A, /* any.convert_extern */
    WASM_OP_EXTERN_CONVERT_ANY = 0x1B, /* extern.covert_any */

    WASM_OP_REF_I31 = 0x1C,   /* ref.i31 */
    WASM_OP_I31_GET_S = 0x1D, /* i31.get_s */
    WASM_OP_I31_GET_U = 0x1E, /* i31.get_u */

    /* stringref related opcodes */
    WASM_OP_STRING_NEW_UTF8 = 0x80,          /* string.new_utf8 */
    WASM_OP_STRING_NEW_WTF16 = 0x81,         /* string.new_wtf16 */
    WASM_OP_STRING_CONST = 0x82,             /* string.const */
    WASM_OP_STRING_MEASURE_UTF8 = 0x83,      /* string.measure_utf8 */
    WASM_OP_STRING_MEASURE_WTF8 = 0x84,      /* string.measure_wtf8 */
    WASM_OP_STRING_MEASURE_WTF16 = 0x85,     /* string.measure_wtf16 */
    WASM_OP_STRING_ENCODE_UTF8 = 0x86,       /* string.encode_utf8 */
    WASM_OP_STRING_ENCODE_WTF16 = 0x87,      /* string.encode_wtf16 */
    WASM_OP_STRING_CONCAT = 0x88,            /* string.concat */
    WASM_OP_STRING_EQ = 0x89,                /* string.eq */
    WASM_OP_STRING_IS_USV_SEQUENCE = 0x8a,   /* string.is_usv_sequence */
    WASM_OP_STRING_NEW_LOSSY_UTF8 = 0x8b,    /* string.new_lossy_utf8 */
    WASM_OP_STRING_NEW_WTF8 = 0x8c,          /* string.new_wtf8 */
    WASM_OP_STRING_ENCODE_LOSSY_UTF8 = 0x8d, /* string.encode_lossy_utf8 */
    WASM_OP_STRING_ENCODE_WTF8 = 0x8e,       /* string.encode_wtf8 */

    WASM_OP_STRING_AS_WTF8 = 0x90,          /* string.as_wtf8 */
    WASM_OP_STRINGVIEW_WTF8_ADVANCE = 0x91, /* stringview_wtf8.advance */
    WASM_OP_STRINGVIEW_WTF8_ENCODE_UTF8 =
        0x92,                             /* stringview_wtf8.encode_utf8 */
    WASM_OP_STRINGVIEW_WTF8_SLICE = 0x93, /* stringview_wtf8.slice */
    WASM_OP_STRINGVIEW_WTF8_ENCODE_LOSSY_UTF8 =
        0x94, /* stringview_wtf8.encode_lossy_utf8 */
    WASM_OP_STRINGVIEW_WTF8_ENCODE_WTF8 =
        0x95, /* stringview_wtf8.encode_wtf8 */

    WASM_OP_STRING_AS_WTF16 = 0x98,         /* string.as_wtf16 */
    WASM_OP_STRINGVIEW_WTF16_LENGTH = 0x99, /* stringview_wtf16.length */
    WASM_OP_STRINGVIEW_WTF16_GET_CODEUNIT =
        0x9a,                               /* stringview_wtf16.get_codeunit */
    WASM_OP_STRINGVIEW_WTF16_ENCODE = 0x9b, /* stringview_wtf16.encode */
    WASM_OP_STRINGVIEW_WTF16_SLICE = 0x9c,  /* stringview_wtf16.slice */

    WASM_OP_STRING_AS_ITER = 0xa0,          /* string.as_iter */
    WASM_OP_STRINGVIEW_ITER_NEXT = 0xa1,    /* stringview_iter.next */
    WASM_OP_STRINGVIEW_ITER_ADVANCE = 0xa2, /* stringview_iter.advance */
    WASM_OP_STRINGVIEW_ITER_REWIND = 0xa3,  /* stringview_iter.rewind */
    WASM_OP_STRINGVIEW_ITER_SLICE = 0xa4,   /* stringview_iter.slice */

    WASM_OP_STRING_NEW_UTF8_ARRAY = 0xb0,     /* string.new_utf8_array */
    WASM_OP_STRING_NEW_WTF16_ARRAY = 0xb1,    /* string.new_wtf16_array */
    WASM_OP_STRING_ENCODE_UTF8_ARRAY = 0xb2,  /* string.encode_utf8_array */
    WASM_OP_STRING_ENCODE_WTF16_ARRAY = 0xb3, /* string.encode_wtf16_array */
    WASM_OP_STRING_NEW_LOSSY_UTF8_ARRAY =
        0xb4,                             /* string.new_lossy_utf8_array */
    WASM_OP_STRING_NEW_WTF8_ARRAY = 0xb5, /* string.new_wtf8_array */
    WASM_OP_STRING_ENCODE_LOSSY_UTF8_ARRAY =
        0xb6, /* string.encode_lossy_utf8_array */
    WASM_OP_STRING_ENCODE_WTF8_ARRAY = 0xb7, /* string.encode_wtf8_array */
} WASMGCEXTOpcode;

typedef enum WASMMiscEXTOpcode {
    WASM_OP_I32_TRUNC_SAT_S_F32 = 0x00,
    WASM_OP_I32_TRUNC_SAT_U_F32 = 0x01,
    WASM_OP_I32_TRUNC_SAT_S_F64 = 0x02,
    WASM_OP_I32_TRUNC_SAT_U_F64 = 0x03,
    WASM_OP_I64_TRUNC_SAT_S_F32 = 0x04,
    WASM_OP_I64_TRUNC_SAT_U_F32 = 0x05,
    WASM_OP_I64_TRUNC_SAT_S_F64 = 0x06,
    WASM_OP_I64_TRUNC_SAT_U_F64 = 0x07,
    WASM_OP_MEMORY_INIT = 0x08,
    WASM_OP_DATA_DROP = 0x09,
    WASM_OP_MEMORY_COPY = 0x0a,
    WASM_OP_MEMORY_FILL = 0x0b,
    WASM_OP_TABLE_INIT = 0x0c,
    WASM_OP_ELEM_DROP = 0x0d,
    WASM_OP_TABLE_COPY = 0x0e,
    WASM_OP_TABLE_GROW = 0x0f,
    WASM_OP_TABLE_SIZE = 0x10,
    WASM_OP_TABLE_FILL = 0x11,
} WASMMiscEXTOpcode;

typedef enum WASMSimdEXTOpcode {
    /* memory instruction */
    SIMD_v128_load = 0x00,
    SIMD_v128_load8x8_s = 0x01,
    SIMD_v128_load8x8_u = 0x02,
    SIMD_v128_load16x4_s = 0x03,
    SIMD_v128_load16x4_u = 0x04,
    SIMD_v128_load32x2_s = 0x05,
    SIMD_v128_load32x2_u = 0x06,
    SIMD_v128_load8_splat = 0x07,
    SIMD_v128_load16_splat = 0x08,
    SIMD_v128_load32_splat = 0x09,
    SIMD_v128_load64_splat = 0x0a,
    SIMD_v128_store = 0x0b,

    /* basic operation */
    SIMD_v128_const = 0x0c,
    SIMD_v8x16_shuffle = 0x0d,
    SIMD_v8x16_swizzle = 0x0e,

    /* splat operation */
    SIMD_i8x16_splat = 0x0f,
    SIMD_i16x8_splat = 0x10,
    SIMD_i32x4_splat = 0x11,
    SIMD_i64x2_splat = 0x12,
    SIMD_f32x4_splat = 0x13,
    SIMD_f64x2_splat = 0x14,

    /* lane operation */
    SIMD_i8x16_extract_lane_s = 0x15,
    SIMD_i8x16_extract_lane_u = 0x16,
    SIMD_i8x16_replace_lane = 0x17,
    SIMD_i16x8_extract_lane_s = 0x18,
    SIMD_i16x8_extract_lane_u = 0x19,
    SIMD_i16x8_replace_lane = 0x1a,
    SIMD_i32x4_extract_lane = 0x1b,
    SIMD_i32x4_replace_lane = 0x1c,
    SIMD_i64x2_extract_lane = 0x1d,
    SIMD_i64x2_replace_lane = 0x1e,
    SIMD_f32x4_extract_lane = 0x1f,
    SIMD_f32x4_replace_lane = 0x20,
    SIMD_f64x2_extract_lane = 0x21,
    SIMD_f64x2_replace_lane = 0x22,

    /* i8x16 compare operation */
    SIMD_i8x16_eq = 0x23,
    SIMD_i8x16_ne = 0x24,
    SIMD_i8x16_lt_s = 0x25,
    SIMD_i8x16_lt_u = 0x26,
    SIMD_i8x16_gt_s = 0x27,
    SIMD_i8x16_gt_u = 0x28,
    SIMD_i8x16_le_s = 0x29,
    SIMD_i8x16_le_u = 0x2a,
    SIMD_i8x16_ge_s = 0x2b,
    SIMD_i8x16_ge_u = 0x2c,

    /* i16x8 compare operation */
    SIMD_i16x8_eq = 0x2d,
    SIMD_i16x8_ne = 0x2e,
    SIMD_i16x8_lt_s = 0x2f,
    SIMD_i16x8_lt_u = 0x30,
    SIMD_i16x8_gt_s = 0x31,
    SIMD_i16x8_gt_u = 0x32,
    SIMD_i16x8_le_s = 0x33,
    SIMD_i16x8_le_u = 0x34,
    SIMD_i16x8_ge_s = 0x35,
    SIMD_i16x8_ge_u = 0x36,

    /* i32x4 compare operation */
    SIMD_i32x4_eq = 0x37,
    SIMD_i32x4_ne = 0x38,
    SIMD_i32x4_lt_s = 0x39,
    SIMD_i32x4_lt_u = 0x3a,
    SIMD_i32x4_gt_s = 0x3b,
    SIMD_i32x4_gt_u = 0x3c,
    SIMD_i32x4_le_s = 0x3d,
    SIMD_i32x4_le_u = 0x3e,
    SIMD_i32x4_ge_s = 0x3f,
    SIMD_i32x4_ge_u = 0x40,

    /* f32x4 compare operation */
    SIMD_f32x4_eq = 0x41,
    SIMD_f32x4_ne = 0x42,
    SIMD_f32x4_lt = 0x43,
    SIMD_f32x4_gt = 0x44,
    SIMD_f32x4_le = 0x45,
    SIMD_f32x4_ge = 0x46,

    /* f64x2 compare operation */
    SIMD_f64x2_eq = 0x47,
    SIMD_f64x2_ne = 0x48,
    SIMD_f64x2_lt = 0x49,
    SIMD_f64x2_gt = 0x4a,
    SIMD_f64x2_le = 0x4b,
    SIMD_f64x2_ge = 0x4c,

    /* v128 operation */
    SIMD_v128_not = 0x4d,
    SIMD_v128_and = 0x4e,
    SIMD_v128_andnot = 0x4f,
    SIMD_v128_or = 0x50,
    SIMD_v128_xor = 0x51,
    SIMD_v128_bitselect = 0x52,
    SIMD_v128_any_true = 0x53,

    /* Load Lane Operation */
    SIMD_v128_load8_lane = 0x54,
    SIMD_v128_load16_lane = 0x55,
    SIMD_v128_load32_lane = 0x56,
    SIMD_v128_load64_lane = 0x57,
    SIMD_v128_store8_lane = 0x58,
    SIMD_v128_store16_lane = 0x59,
    SIMD_v128_store32_lane = 0x5a,
    SIMD_v128_store64_lane = 0x5b,
    SIMD_v128_load32_zero = 0x5c,
    SIMD_v128_load64_zero = 0x5d,

    /* Float conversion */
    SIMD_f32x4_demote_f64x2_zero = 0x5e,
    SIMD_f64x2_promote_low_f32x4_zero = 0x5f,

    /* i8x16 Operation */
    SIMD_i8x16_abs = 0x60,
    SIMD_i8x16_neg = 0x61,
    SIMD_i8x16_popcnt = 0x62,
    SIMD_i8x16_all_true = 0x63,
    SIMD_i8x16_bitmask = 0x64,
    SIMD_i8x16_narrow_i16x8_s = 0x65,
    SIMD_i8x16_narrow_i16x8_u = 0x66,
    SIMD_f32x4_ceil = 0x67,
    SIMD_f32x4_floor = 0x68,
    SIMD_f32x4_trunc = 0x69,
    SIMD_f32x4_nearest = 0x6a,
    SIMD_i8x16_shl = 0x6b,
    SIMD_i8x16_shr_s = 0x6c,
    SIMD_i8x16_shr_u = 0x6d,
    SIMD_i8x16_add = 0x6e,
    SIMD_i8x16_add_sat_s = 0x6f,
    SIMD_i8x16_add_sat_u = 0x70,
    SIMD_i8x16_sub = 0x71,
    SIMD_i8x16_sub_sat_s = 0x72,
    SIMD_i8x16_sub_sat_u = 0x73,
    SIMD_f64x2_ceil = 0x74,
    SIMD_f64x2_floor = 0x75,
    SIMD_i8x16_min_s = 0x76,
    SIMD_i8x16_min_u = 0x77,
    SIMD_i8x16_max_s = 0x78,
    SIMD_i8x16_max_u = 0x79,
    SIMD_f64x2_trunc = 0x7a,
    SIMD_i8x16_avgr_u = 0x7b,
    SIMD_i16x8_extadd_pairwise_i8x16_s = 0x7c,
    SIMD_i16x8_extadd_pairwise_i8x16_u = 0x7d,
    SIMD_i32x4_extadd_pairwise_i16x8_s = 0x7e,
    SIMD_i32x4_extadd_pairwise_i16x8_u = 0x7f,

    /* i16x8 operation */
    SIMD_i16x8_abs = 0x80,
    SIMD_i16x8_neg = 0x81,
    SIMD_i16x8_q15mulr_sat_s = 0x82,
    SIMD_i16x8_all_true = 0x83,
    SIMD_i16x8_bitmask = 0x84,
    SIMD_i16x8_narrow_i32x4_s = 0x85,
    SIMD_i16x8_narrow_i32x4_u = 0x86,
    SIMD_i16x8_extend_low_i8x16_s = 0x87,
    SIMD_i16x8_extend_high_i8x16_s = 0x88,
    SIMD_i16x8_extend_low_i8x16_u = 0x89,
    SIMD_i16x8_extend_high_i8x16_u = 0x8a,
    SIMD_i16x8_shl = 0x8b,
    SIMD_i16x8_shr_s = 0x8c,
    SIMD_i16x8_shr_u = 0x8d,
    SIMD_i16x8_add = 0x8e,
    SIMD_i16x8_add_sat_s = 0x8f,
    SIMD_i16x8_add_sat_u = 0x90,
    SIMD_i16x8_sub = 0x91,
    SIMD_i16x8_sub_sat_s = 0x92,
    SIMD_i16x8_sub_sat_u = 0x93,
    SIMD_f64x2_nearest = 0x94,
    SIMD_i16x8_mul = 0x95,
    SIMD_i16x8_min_s = 0x96,
    SIMD_i16x8_min_u = 0x97,
    SIMD_i16x8_max_s = 0x98,
    SIMD_i16x8_max_u = 0x99,
    /* placeholder            = 0x9a */
    SIMD_i16x8_avgr_u = 0x9b,
    SIMD_i16x8_extmul_low_i8x16_s = 0x9c,
    SIMD_i16x8_extmul_high_i8x16_s = 0x9d,
    SIMD_i16x8_extmul_low_i8x16_u = 0x9e,
    SIMD_i16x8_extmul_high_i8x16_u = 0x9f,

    /* i32x4 operation */
    SIMD_i32x4_abs = 0xa0,
    SIMD_i32x4_neg = 0xa1,
    /* placeholder            = 0xa2 */
    SIMD_i32x4_all_true = 0xa3,
    SIMD_i32x4_bitmask = 0xa4,
    /* placeholder     = 0xa5 */
    /* placeholder     = 0xa6 */
    SIMD_i32x4_extend_low_i16x8_s = 0xa7,
    SIMD_i32x4_extend_high_i16x8_s = 0xa8,
    SIMD_i32x4_extend_low_i16x8_u = 0xa9,
    SIMD_i32x4_extend_high_i16x8_u = 0xaa,
    SIMD_i32x4_shl = 0xab,
    SIMD_i32x4_shr_s = 0xac,
    SIMD_i32x4_shr_u = 0xad,
    SIMD_i32x4_add = 0xae,
    /* placeholder = 0xaf */
    /* placeholder = 0xb0 */
    SIMD_i32x4_sub = 0xb1,
    /* placeholder = 0xb2 */
    /* placeholder = 0xb3 */
    /* placeholder = 0xb4 */
    SIMD_i32x4_mul = 0xb5,
    SIMD_i32x4_min_s = 0xb6,
    SIMD_i32x4_min_u = 0xb7,
    SIMD_i32x4_max_s = 0xb8,
    SIMD_i32x4_max_u = 0xb9,
    SIMD_i32x4_dot_i16x8_s = 0xba,
    /* placeholder         = 0xbb */
    SIMD_i32x4_extmul_low_i16x8_s = 0xbc,
    SIMD_i32x4_extmul_high_i16x8_s = 0xbd,
    SIMD_i32x4_extmul_low_i16x8_u = 0xbe,
    SIMD_i32x4_extmul_high_i16x8_u = 0xbf,

    /* i64x2 operation */
    SIMD_i64x2_abs = 0xc0,
    SIMD_i64x2_neg = 0xc1,
    /* placeholder       = 0xc2 */
    SIMD_i64x2_all_true = 0xc3,
    SIMD_i64x2_bitmask = 0xc4,
    /* placeholder       = 0xc5 */
    /* placeholder       = 0xc6 */
    SIMD_i64x2_extend_low_i32x4_s = 0xc7,
    SIMD_i64x2_extend_high_i32x4_s = 0xc8,
    SIMD_i64x2_extend_low_i32x4_u = 0xc9,
    SIMD_i64x2_extend_high_i32x4_u = 0xca,
    SIMD_i64x2_shl = 0xcb,
    SIMD_i64x2_shr_s = 0xcc,
    SIMD_i64x2_shr_u = 0xcd,
    SIMD_i64x2_add = 0xce,
    /* placeholder       = 0xcf */
    /* placeholder       = 0xd0 */
    SIMD_i64x2_sub = 0xd1,
    /* placeholder       = 0xd2 */
    /* placeholder       = 0xd3 */
    /* placeholder       = 0xd4 */
    SIMD_i64x2_mul = 0xd5,
    SIMD_i64x2_eq = 0xd6,
    SIMD_i64x2_ne = 0xd7,
    SIMD_i64x2_lt_s = 0xd8,
    SIMD_i64x2_gt_s = 0xd9,
    SIMD_i64x2_le_s = 0xda,
    SIMD_i64x2_ge_s = 0xdb,
    SIMD_i64x2_extmul_low_i32x4_s = 0xdc,
    SIMD_i64x2_extmul_high_i32x4_s = 0xdd,
    SIMD_i64x2_extmul_low_i32x4_u = 0xde,
    SIMD_i64x2_extmul_high_i32x4_u = 0xdf,

    /* f32x4 operation */
    SIMD_f32x4_abs = 0xe0,
    SIMD_f32x4_neg = 0xe1,
    /* placeholder = 0xe2 */
    SIMD_f32x4_sqrt = 0xe3,
    SIMD_f32x4_add = 0xe4,
    SIMD_f32x4_sub = 0xe5,
    SIMD_f32x4_mul = 0xe6,
    SIMD_f32x4_div = 0xe7,
    SIMD_f32x4_min = 0xe8,
    SIMD_f32x4_max = 0xe9,
    SIMD_f32x4_pmin = 0xea,
    SIMD_f32x4_pmax = 0xeb,

    /* f64x2 operation */
    SIMD_f64x2_abs = 0xec,
    SIMD_f64x2_neg = 0xed,
    /* placeholder = 0xee */
    SIMD_f64x2_sqrt = 0xef,
    SIMD_f64x2_add = 0xf0,
    SIMD_f64x2_sub = 0xf1,
    SIMD_f64x2_mul = 0xf2,
    SIMD_f64x2_div = 0xf3,
    SIMD_f64x2_min = 0xf4,
    SIMD_f64x2_max = 0xf5,
    SIMD_f64x2_pmin = 0xf6,
    SIMD_f64x2_pmax = 0xf7,

    /* conversion operation */
    SIMD_i32x4_trunc_sat_f32x4_s = 0xf8,
    SIMD_i32x4_trunc_sat_f32x4_u = 0xf9,
    SIMD_f32x4_convert_i32x4_s = 0xfa,
    SIMD_f32x4_convert_i32x4_u = 0xfb,
    SIMD_i32x4_trunc_sat_f64x2_s_zero = 0xfc,
    SIMD_i32x4_trunc_sat_f64x2_u_zero = 0xfd,
    SIMD_f64x2_convert_low_i32x4_s = 0xfe,
    SIMD_f64x2_convert_low_i32x4_u = 0xff,
} WASMSimdEXTOpcode;

typedef enum WASMAtomicEXTOpcode {
    /* atomic wait and notify */
    WASM_OP_ATOMIC_NOTIFY = 0x00,
    WASM_OP_ATOMIC_WAIT32 = 0x01,
    WASM_OP_ATOMIC_WAIT64 = 0x02,
    WASM_OP_ATOMIC_FENCE = 0x03,
    /* atomic load and store */
    WASM_OP_ATOMIC_I32_LOAD = 0x10,
    WASM_OP_ATOMIC_I64_LOAD = 0x11,
    WASM_OP_ATOMIC_I32_LOAD8_U = 0x12,
    WASM_OP_ATOMIC_I32_LOAD16_U = 0x13,
    WASM_OP_ATOMIC_I64_LOAD8_U = 0x14,
    WASM_OP_ATOMIC_I64_LOAD16_U = 0x15,
    WASM_OP_ATOMIC_I64_LOAD32_U = 0x16,
    WASM_OP_ATOMIC_I32_STORE = 0x17,
    WASM_OP_ATOMIC_I64_STORE = 0x18,
    WASM_OP_ATOMIC_I32_STORE8 = 0x19,
    WASM_OP_ATOMIC_I32_STORE16 = 0x1a,
    WASM_OP_ATOMIC_I64_STORE8 = 0x1b,
    WASM_OP_ATOMIC_I64_STORE16 = 0x1c,
    WASM_OP_ATOMIC_I64_STORE32 = 0x1d,
    /* atomic add */
    WASM_OP_ATOMIC_RMW_I32_ADD = 0x1e,
    WASM_OP_ATOMIC_RMW_I64_ADD = 0x1f,
    WASM_OP_ATOMIC_RMW_I32_ADD8_U = 0x20,
    WASM_OP_ATOMIC_RMW_I32_ADD16_U = 0x21,
    WASM_OP_ATOMIC_RMW_I64_ADD8_U = 0x22,
    WASM_OP_ATOMIC_RMW_I64_ADD16_U = 0x23,
    WASM_OP_ATOMIC_RMW_I64_ADD32_U = 0x24,
    /* atomic sub */
    WASM_OP_ATOMIC_RMW_I32_SUB = 0x25,
    WASM_OP_ATOMIC_RMW_I64_SUB = 0x26,
    WASM_OP_ATOMIC_RMW_I32_SUB8_U = 0x27,
    WASM_OP_ATOMIC_RMW_I32_SUB16_U = 0x28,
    WASM_OP_ATOMIC_RMW_I64_SUB8_U = 0x29,
    WASM_OP_ATOMIC_RMW_I64_SUB16_U = 0x2a,
    WASM_OP_ATOMIC_RMW_I64_SUB32_U = 0x2b,
    /* atomic and */
    WASM_OP_ATOMIC_RMW_I32_AND = 0x2c,
    WASM_OP_ATOMIC_RMW_I64_AND = 0x2d,
    WASM_OP_ATOMIC_RMW_I32_AND8_U = 0x2e,
    WASM_OP_ATOMIC_RMW_I32_AND16_U = 0x2f,
    WASM_OP_ATOMIC_RMW_I64_AND8_U = 0x30,
    WASM_OP_ATOMIC_RMW_I64_AND16_U = 0x31,
    WASM_OP_ATOMIC_RMW_I64_AND32_U = 0x32,
    /* atomic or */
    WASM_OP_ATOMIC_RMW_I32_OR = 0x33,
    WASM_OP_ATOMIC_RMW_I64_OR = 0x34,
    WASM_OP_ATOMIC_RMW_I32_OR8_U = 0x35,
    WASM_OP_ATOMIC_RMW_I32_OR16_U = 0x36,
    WASM_OP_ATOMIC_RMW_I64_OR8_U = 0x37,
    WASM_OP_ATOMIC_RMW_I64_OR16_U = 0x38,
    WASM_OP_ATOMIC_RMW_I64_OR32_U = 0x39,
    /* atomic xor */
    WASM_OP_ATOMIC_RMW_I32_XOR = 0x3a,
    WASM_OP_ATOMIC_RMW_I64_XOR = 0x3b,
    WASM_OP_ATOMIC_RMW_I32_XOR8_U = 0x3c,
    WASM_OP_ATOMIC_RMW_I32_XOR16_U = 0x3d,
    WASM_OP_ATOMIC_RMW_I64_XOR8_U = 0x3e,
    WASM_OP_ATOMIC_RMW_I64_XOR16_U = 0x3f,
    WASM_OP_ATOMIC_RMW_I64_XOR32_U = 0x40,
    /* atomic xchg */
    WASM_OP_ATOMIC_RMW_I32_XCHG = 0x41,
    WASM_OP_ATOMIC_RMW_I64_XCHG = 0x42,
    WASM_OP_ATOMIC_RMW_I32_XCHG8_U = 0x43,
    WASM_OP_ATOMIC_RMW_I32_XCHG16_U = 0x44,
    WASM_OP_ATOMIC_RMW_I64_XCHG8_U = 0x45,
    WASM_OP_ATOMIC_RMW_I64_XCHG16_U = 0x46,
    WASM_OP_ATOMIC_RMW_I64_XCHG32_U = 0x47,
    /* atomic cmpxchg */
    WASM_OP_ATOMIC_RMW_I32_CMPXCHG = 0x48,
    WASM_OP_ATOMIC_RMW_I64_CMPXCHG = 0x49,
    WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U = 0x4a,
    WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U = 0x4b,
    WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U = 0x4c,
    WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U = 0x4d,
    WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U = 0x4e,
} WASMAtomicEXTOpcode;

#if WASM_ENABLE_DEBUG_INTERP != 0
#define DEF_DEBUG_BREAK_HANDLE() \
    [DEBUG_OP_BREAK] = HANDLE_OPCODE(DEBUG_OP_BREAK), /* 0xdb */
#else
#define DEF_DEBUG_BREAK_HANDLE()
#endif
#define SET_GOTO_TABLE_ELEM(opcode) [opcode] = HANDLE_OPCODE(opcode)

#if WASM_ENABLE_SIMDE != 0
#define DEF_EXT_V128_HANDLE()                                       \
    SET_GOTO_TABLE_ELEM(EXT_OP_SET_LOCAL_FAST_V128),     /* 0xdd */ \
        SET_GOTO_TABLE_ELEM(EXT_OP_TEE_LOCAL_FAST_V128), /* 0xde */ \
        SET_GOTO_TABLE_ELEM(EXT_OP_COPY_STACK_TOP_V128), /* 0xdf */ \
        SET_GOTO_TABLE_ELEM(WASM_OP_GET_GLOBAL_V128),    /* 0xe0 */ \
        SET_GOTO_TABLE_ELEM(WASM_OP_SET_GLOBAL_V128),    /* 0xe1 */ \
        SET_GOTO_TABLE_ELEM(WASM_OP_SELECT_128),         /* 0xe2 */

#else
#define DEF_EXT_V128_HANDLE()
#endif
/*
 * Macro used to generate computed goto tables for the C interpreter.
 */
#define WASM_INSTRUCTION_NUM 256

#define DEFINE_GOTO_TABLE(type, _name)                          \
    static type _name[WASM_INSTRUCTION_NUM] = {                 \
        HANDLE_OPCODE(WASM_OP_UNREACHABLE),          /* 0x00 */ \
        HANDLE_OPCODE(WASM_OP_NOP),                  /* 0x01 */ \
        HANDLE_OPCODE(WASM_OP_BLOCK),                /* 0x02 */ \
        HANDLE_OPCODE(WASM_OP_LOOP),                 /* 0x03 */ \
        HANDLE_OPCODE(WASM_OP_IF),                   /* 0x04 */ \
        HANDLE_OPCODE(WASM_OP_ELSE),                 /* 0x05 */ \
        HANDLE_OPCODE(WASM_OP_TRY),                  /* 0x06 */ \
        HANDLE_OPCODE(WASM_OP_CATCH),                /* 0x07 */ \
        HANDLE_OPCODE(WASM_OP_THROW),                /* 0x08 */ \
        HANDLE_OPCODE(WASM_OP_RETHROW),              /* 0x09 */ \
        HANDLE_OPCODE(WASM_OP_UNUSED_0x0a),          /* 0x0a */ \
        HANDLE_OPCODE(WASM_OP_END),                  /* 0x0b */ \
        HANDLE_OPCODE(WASM_OP_BR),                   /* 0x0c */ \
        HANDLE_OPCODE(WASM_OP_BR_IF),                /* 0x0d */ \
        HANDLE_OPCODE(WASM_OP_BR_TABLE),             /* 0x0e */ \
        HANDLE_OPCODE(WASM_OP_RETURN),               /* 0x0f */ \
        HANDLE_OPCODE(WASM_OP_CALL),                 /* 0x10 */ \
        HANDLE_OPCODE(WASM_OP_CALL_INDIRECT),        /* 0x11 */ \
        HANDLE_OPCODE(WASM_OP_RETURN_CALL),          /* 0x12 */ \
        HANDLE_OPCODE(WASM_OP_RETURN_CALL_INDIRECT), /* 0x13 */ \
        HANDLE_OPCODE(WASM_OP_CALL_REF),             /* 0x14 */ \
        HANDLE_OPCODE(WASM_OP_RETURN_CALL_REF),      /* 0x15 */ \
        HANDLE_OPCODE(WASM_OP_UNUSED_0x16),          /* 0x16 */ \
        HANDLE_OPCODE(WASM_OP_UNUSED_0x17),          /* 0x17 */ \
        HANDLE_OPCODE(WASM_OP_DELEGATE),             /* 0x18 */ \
        HANDLE_OPCODE(WASM_OP_CATCH_ALL),            /* 0x19 */ \
        HANDLE_OPCODE(WASM_OP_DROP),                 /* 0x1a */ \
        HANDLE_OPCODE(WASM_OP_SELECT),               /* 0x1b */ \
        HANDLE_OPCODE(WASM_OP_SELECT_T),             /* 0x1c */ \
        HANDLE_OPCODE(WASM_OP_GET_GLOBAL_64),        /* 0x1d */ \
        HANDLE_OPCODE(WASM_OP_SET_GLOBAL_64),        /* 0x1e */ \
        HANDLE_OPCODE(WASM_OP_SET_GLOBAL_AUX_STACK), /* 0x1f */ \
        HANDLE_OPCODE(WASM_OP_GET_LOCAL),            /* 0x20 */ \
        HANDLE_OPCODE(WASM_OP_SET_LOCAL),            /* 0x21 */ \
        HANDLE_OPCODE(WASM_OP_TEE_LOCAL),            /* 0x22 */ \
        HANDLE_OPCODE(WASM_OP_GET_GLOBAL),           /* 0x23 */ \
        HANDLE_OPCODE(WASM_OP_SET_GLOBAL),           /* 0x24 */ \
        HANDLE_OPCODE(WASM_OP_TABLE_GET),            /* 0x25 */ \
        HANDLE_OPCODE(WASM_OP_TABLE_SET),            /* 0x26 */ \
        HANDLE_OPCODE(WASM_OP_UNUSED_0x27),          /* 0x27 */ \
        HANDLE_OPCODE(WASM_OP_I32_LOAD),             /* 0x28 */ \
        HANDLE_OPCODE(WASM_OP_I64_LOAD),             /* 0x29 */ \
        HANDLE_OPCODE(WASM_OP_F32_LOAD),             /* 0x2a */ \
        HANDLE_OPCODE(WASM_OP_F64_LOAD),             /* 0x2b */ \
        HANDLE_OPCODE(WASM_OP_I32_LOAD8_S),          /* 0x2c */ \
        HANDLE_OPCODE(WASM_OP_I32_LOAD8_U),          /* 0x2d */ \
        HANDLE_OPCODE(WASM_OP_I32_LOAD16_S),         /* 0x2e */ \
        HANDLE_OPCODE(WASM_OP_I32_LOAD16_U),         /* 0x2f */ \
        HANDLE_OPCODE(WASM_OP_I64_LOAD8_S),          /* 0x30 */ \
        HANDLE_OPCODE(WASM_OP_I64_LOAD8_U),          /* 0x31 */ \
        HANDLE_OPCODE(WASM_OP_I64_LOAD16_S),         /* 0x32 */ \
        HANDLE_OPCODE(WASM_OP_I64_LOAD16_U),         /* 0x33 */ \
        HANDLE_OPCODE(WASM_OP_I64_LOAD32_S),         /* 0x34 */ \
        HANDLE_OPCODE(WASM_OP_I64_LOAD32_U),         /* 0x35 */ \
        HANDLE_OPCODE(WASM_OP_I32_STORE),            /* 0x36 */ \
        HANDLE_OPCODE(WASM_OP_I64_STORE),            /* 0x37 */ \
        HANDLE_OPCODE(WASM_OP_F32_STORE),            /* 0x38 */ \
        HANDLE_OPCODE(WASM_OP_F64_STORE),            /* 0x39 */ \
        HANDLE_OPCODE(WASM_OP_I32_STORE8),           /* 0x3a */ \
        HANDLE_OPCODE(WASM_OP_I32_STORE16),          /* 0x3b */ \
        HANDLE_OPCODE(WASM_OP_I64_STORE8),           /* 0x3c */ \
        HANDLE_OPCODE(WASM_OP_I64_STORE16),          /* 0x3d */ \
        HANDLE_OPCODE(WASM_OP_I64_STORE32),          /* 0x3e */ \
        HANDLE_OPCODE(WASM_OP_MEMORY_SIZE),          /* 0x3f */ \
        HANDLE_OPCODE(WASM_OP_MEMORY_GROW),          /* 0x40 */ \
        HANDLE_OPCODE(WASM_OP_I32_CONST),            /* 0x41 */ \
        HANDLE_OPCODE(WASM_OP_I64_CONST),            /* 0x42 */ \
        HANDLE_OPCODE(WASM_OP_F32_CONST),            /* 0x43 */ \
        HANDLE_OPCODE(WASM_OP_F64_CONST),            /* 0x44 */ \
        HANDLE_OPCODE(WASM_OP_I32_EQZ),              /* 0x45 */ \
        HANDLE_OPCODE(WASM_OP_I32_EQ),               /* 0x46 */ \
        HANDLE_OPCODE(WASM_OP_I32_NE),               /* 0x47 */ \
        HANDLE_OPCODE(WASM_OP_I32_LT_S),             /* 0x48 */ \
        HANDLE_OPCODE(WASM_OP_I32_LT_U),             /* 0x49 */ \
        HANDLE_OPCODE(WASM_OP_I32_GT_S),             /* 0x4a */ \
        HANDLE_OPCODE(WASM_OP_I32_GT_U),             /* 0x4b */ \
        HANDLE_OPCODE(WASM_OP_I32_LE_S),             /* 0x4c */ \
        HANDLE_OPCODE(WASM_OP_I32_LE_U),             /* 0x4d */ \
        HANDLE_OPCODE(WASM_OP_I32_GE_S),             /* 0x4e */ \
        HANDLE_OPCODE(WASM_OP_I32_GE_U),             /* 0x4f */ \
        HANDLE_OPCODE(WASM_OP_I64_EQZ),              /* 0x50 */ \
        HANDLE_OPCODE(WASM_OP_I64_EQ),               /* 0x51 */ \
        HANDLE_OPCODE(WASM_OP_I64_NE),               /* 0x52 */ \
        HANDLE_OPCODE(WASM_OP_I64_LT_S),             /* 0x53 */ \
        HANDLE_OPCODE(WASM_OP_I64_LT_U),             /* 0x54 */ \
        HANDLE_OPCODE(WASM_OP_I64_GT_S),             /* 0x55 */ \
        HANDLE_OPCODE(WASM_OP_I64_GT_U),             /* 0x56 */ \
        HANDLE_OPCODE(WASM_OP_I64_LE_S),             /* 0x57 */ \
        HANDLE_OPCODE(WASM_OP_I64_LE_U),             /* 0x58 */ \
        HANDLE_OPCODE(WASM_OP_I64_GE_S),             /* 0x59 */ \
        HANDLE_OPCODE(WASM_OP_I64_GE_U),             /* 0x5a */ \
        HANDLE_OPCODE(WASM_OP_F32_EQ),               /* 0x5b */ \
        HANDLE_OPCODE(WASM_OP_F32_NE),               /* 0x5c */ \
        HANDLE_OPCODE(WASM_OP_F32_LT),               /* 0x5d */ \
        HANDLE_OPCODE(WASM_OP_F32_GT),               /* 0x5e */ \
        HANDLE_OPCODE(WASM_OP_F32_LE),               /* 0x5f */ \
        HANDLE_OPCODE(WASM_OP_F32_GE),               /* 0x60 */ \
        HANDLE_OPCODE(WASM_OP_F64_EQ),               /* 0x61 */ \
        HANDLE_OPCODE(WASM_OP_F64_NE),               /* 0x62 */ \
        HANDLE_OPCODE(WASM_OP_F64_LT),               /* 0x63 */ \
        HANDLE_OPCODE(WASM_OP_F64_GT),               /* 0x64 */ \
        HANDLE_OPCODE(WASM_OP_F64_LE),               /* 0x65 */ \
        HANDLE_OPCODE(WASM_OP_F64_GE),               /* 0x66 */ \
        HANDLE_OPCODE(WASM_OP_I32_CLZ),              /* 0x67 */ \
        HANDLE_OPCODE(WASM_OP_I32_CTZ),              /* 0x68 */ \
        HANDLE_OPCODE(WASM_OP_I32_POPCNT),           /* 0x69 */ \
        HANDLE_OPCODE(WASM_OP_I32_ADD),              /* 0x6a */ \
        HANDLE_OPCODE(WASM_OP_I32_SUB),              /* 0x6b */ \
        HANDLE_OPCODE(WASM_OP_I32_MUL),              /* 0x6c */ \
        HANDLE_OPCODE(WASM_OP_I32_DIV_S),            /* 0x6d */ \
        HANDLE_OPCODE(WASM_OP_I32_DIV_U),            /* 0x6e */ \
        HANDLE_OPCODE(WASM_OP_I32_REM_S),            /* 0x6f */ \
        HANDLE_OPCODE(WASM_OP_I32_REM_U),            /* 0x70 */ \
        HANDLE_OPCODE(WASM_OP_I32_AND),              /* 0x71 */ \
        HANDLE_OPCODE(WASM_OP_I32_OR),               /* 0x72 */ \
        HANDLE_OPCODE(WASM_OP_I32_XOR),              /* 0x73 */ \
        HANDLE_OPCODE(WASM_OP_I32_SHL),              /* 0x74 */ \
        HANDLE_OPCODE(WASM_OP_I32_SHR_S),            /* 0x75 */ \
        HANDLE_OPCODE(WASM_OP_I32_SHR_U),            /* 0x76 */ \
        HANDLE_OPCODE(WASM_OP_I32_ROTL),             /* 0x77 */ \
        HANDLE_OPCODE(WASM_OP_I32_ROTR),             /* 0x78 */ \
        HANDLE_OPCODE(WASM_OP_I64_CLZ),              /* 0x79 */ \
        HANDLE_OPCODE(WASM_OP_I64_CTZ),              /* 0x7a */ \
        HANDLE_OPCODE(WASM_OP_I64_POPCNT),           /* 0x7b */ \
        HANDLE_OPCODE(WASM_OP_I64_ADD),              /* 0x7c */ \
        HANDLE_OPCODE(WASM_OP_I64_SUB),              /* 0x7d */ \
        HANDLE_OPCODE(WASM_OP_I64_MUL),              /* 0x7e */ \
        HANDLE_OPCODE(WASM_OP_I64_DIV_S),            /* 0x7f */ \
        HANDLE_OPCODE(WASM_OP_I64_DIV_U),            /* 0x80 */ \
        HANDLE_OPCODE(WASM_OP_I64_REM_S),            /* 0x81 */ \
        HANDLE_OPCODE(WASM_OP_I64_REM_U),            /* 0x82 */ \
        HANDLE_OPCODE(WASM_OP_I64_AND),              /* 0x83 */ \
        HANDLE_OPCODE(WASM_OP_I64_OR),               /* 0x84 */ \
        HANDLE_OPCODE(WASM_OP_I64_XOR),              /* 0x85 */ \
        HANDLE_OPCODE(WASM_OP_I64_SHL),              /* 0x86 */ \
        HANDLE_OPCODE(WASM_OP_I64_SHR_S),            /* 0x87 */ \
        HANDLE_OPCODE(WASM_OP_I64_SHR_U),            /* 0x88 */ \
        HANDLE_OPCODE(WASM_OP_I64_ROTL),             /* 0x89 */ \
        HANDLE_OPCODE(WASM_OP_I64_ROTR),             /* 0x8a */ \
        HANDLE_OPCODE(WASM_OP_F32_ABS),              /* 0x8b */ \
        HANDLE_OPCODE(WASM_OP_F32_NEG),              /* 0x8c */ \
        HANDLE_OPCODE(WASM_OP_F32_CEIL),             /* 0x8d */ \
        HANDLE_OPCODE(WASM_OP_F32_FLOOR),            /* 0x8e */ \
        HANDLE_OPCODE(WASM_OP_F32_TRUNC),            /* 0x8f */ \
        HANDLE_OPCODE(WASM_OP_F32_NEAREST),          /* 0x90 */ \
        HANDLE_OPCODE(WASM_OP_F32_SQRT),             /* 0x91 */ \
        HANDLE_OPCODE(WASM_OP_F32_ADD),              /* 0x92 */ \
        HANDLE_OPCODE(WASM_OP_F32_SUB),              /* 0x93 */ \
        HANDLE_OPCODE(WASM_OP_F32_MUL),              /* 0x94 */ \
        HANDLE_OPCODE(WASM_OP_F32_DIV),              /* 0x95 */ \
        HANDLE_OPCODE(WASM_OP_F32_MIN),              /* 0x96 */ \
        HANDLE_OPCODE(WASM_OP_F32_MAX),              /* 0x97 */ \
        HANDLE_OPCODE(WASM_OP_F32_COPYSIGN),         /* 0x98 */ \
        HANDLE_OPCODE(WASM_OP_F64_ABS),              /* 0x99 */ \
        HANDLE_OPCODE(WASM_OP_F64_NEG),              /* 0x9a */ \
        HANDLE_OPCODE(WASM_OP_F64_CEIL),             /* 0x9b */ \
        HANDLE_OPCODE(WASM_OP_F64_FLOOR),            /* 0x9c */ \
        HANDLE_OPCODE(WASM_OP_F64_TRUNC),            /* 0x9d */ \
        HANDLE_OPCODE(WASM_OP_F64_NEAREST),          /* 0x9e */ \
        HANDLE_OPCODE(WASM_OP_F64_SQRT),             /* 0x9f */ \
        HANDLE_OPCODE(WASM_OP_F64_ADD),              /* 0xa0 */ \
        HANDLE_OPCODE(WASM_OP_F64_SUB),              /* 0xa1 */ \
        HANDLE_OPCODE(WASM_OP_F64_MUL),              /* 0xa2 */ \
        HANDLE_OPCODE(WASM_OP_F64_DIV),              /* 0xa3 */ \
        HANDLE_OPCODE(WASM_OP_F64_MIN),              /* 0xa4 */ \
        HANDLE_OPCODE(WASM_OP_F64_MAX),              /* 0xa5 */ \
        HANDLE_OPCODE(WASM_OP_F64_COPYSIGN),         /* 0xa6 */ \
        HANDLE_OPCODE(WASM_OP_I32_WRAP_I64),         /* 0xa7 */ \
        HANDLE_OPCODE(WASM_OP_I32_TRUNC_S_F32),      /* 0xa8 */ \
        HANDLE_OPCODE(WASM_OP_I32_TRUNC_U_F32),      /* 0xa9 */ \
        HANDLE_OPCODE(WASM_OP_I32_TRUNC_S_F64),      /* 0xaa */ \
        HANDLE_OPCODE(WASM_OP_I32_TRUNC_U_F64),      /* 0xab */ \
        HANDLE_OPCODE(WASM_OP_I64_EXTEND_S_I32),     /* 0xac */ \
        HANDLE_OPCODE(WASM_OP_I64_EXTEND_U_I32),     /* 0xad */ \
        HANDLE_OPCODE(WASM_OP_I64_TRUNC_S_F32),      /* 0xae */ \
        HANDLE_OPCODE(WASM_OP_I64_TRUNC_U_F32),      /* 0xaf */ \
        HANDLE_OPCODE(WASM_OP_I64_TRUNC_S_F64),      /* 0xb0 */ \
        HANDLE_OPCODE(WASM_OP_I64_TRUNC_U_F64),      /* 0xb1 */ \
        HANDLE_OPCODE(WASM_OP_F32_CONVERT_S_I32),    /* 0xb2 */ \
        HANDLE_OPCODE(WASM_OP_F32_CONVERT_U_I32),    /* 0xb3 */ \
        HANDLE_OPCODE(WASM_OP_F32_CONVERT_S_I64),    /* 0xb4 */ \
        HANDLE_OPCODE(WASM_OP_F32_CONVERT_U_I64),    /* 0xb5 */ \
        HANDLE_OPCODE(WASM_OP_F32_DEMOTE_F64),       /* 0xb6 */ \
        HANDLE_OPCODE(WASM_OP_F64_CONVERT_S_I32),    /* 0xb7 */ \
        HANDLE_OPCODE(WASM_OP_F64_CONVERT_U_I32),    /* 0xb8 */ \
        HANDLE_OPCODE(WASM_OP_F64_CONVERT_S_I64),    /* 0xb9 */ \
        HANDLE_OPCODE(WASM_OP_F64_CONVERT_U_I64),    /* 0xba */ \
        HANDLE_OPCODE(WASM_OP_F64_PROMOTE_F32),      /* 0xbb */ \
        HANDLE_OPCODE(WASM_OP_I32_REINTERPRET_F32),  /* 0xbc */ \
        HANDLE_OPCODE(WASM_OP_I64_REINTERPRET_F64),  /* 0xbd */ \
        HANDLE_OPCODE(WASM_OP_F32_REINTERPRET_I32),  /* 0xbe */ \
        HANDLE_OPCODE(WASM_OP_F64_REINTERPRET_I64),  /* 0xbf */ \
        HANDLE_OPCODE(WASM_OP_I32_EXTEND8_S),        /* 0xc0 */ \
        HANDLE_OPCODE(WASM_OP_I32_EXTEND16_S),       /* 0xc1 */ \
        HANDLE_OPCODE(WASM_OP_I64_EXTEND8_S),        /* 0xc2 */ \
        HANDLE_OPCODE(WASM_OP_I64_EXTEND16_S),       /* 0xc3 */ \
        HANDLE_OPCODE(WASM_OP_I64_EXTEND32_S),       /* 0xc4 */ \
        HANDLE_OPCODE(WASM_OP_DROP_64),              /* 0xc5 */ \
        HANDLE_OPCODE(WASM_OP_SELECT_64),            /* 0xc6 */ \
        HANDLE_OPCODE(EXT_OP_GET_LOCAL_FAST),        /* 0xc7 */ \
        HANDLE_OPCODE(EXT_OP_SET_LOCAL_FAST_I64),    /* 0xc8 */ \
        HANDLE_OPCODE(EXT_OP_SET_LOCAL_FAST),        /* 0xc9 */ \
        HANDLE_OPCODE(EXT_OP_TEE_LOCAL_FAST),        /* 0xca */ \
        HANDLE_OPCODE(EXT_OP_TEE_LOCAL_FAST_I64),    /* 0xcb */ \
        HANDLE_OPCODE(EXT_OP_COPY_STACK_TOP),        /* 0xcc */ \
        HANDLE_OPCODE(EXT_OP_COPY_STACK_TOP_I64),    /* 0xcd */ \
        HANDLE_OPCODE(EXT_OP_COPY_STACK_VALUES),     /* 0xce */ \
        HANDLE_OPCODE(WASM_OP_IMPDEP),               /* 0xcf */ \
        HANDLE_OPCODE(WASM_OP_REF_NULL),             /* 0xd0 */ \
        HANDLE_OPCODE(WASM_OP_REF_IS_NULL),          /* 0xd1 */ \
        HANDLE_OPCODE(WASM_OP_REF_FUNC),             /* 0xd2 */ \
        HANDLE_OPCODE(WASM_OP_REF_EQ),               /* 0xd3 */ \
        HANDLE_OPCODE(WASM_OP_REF_AS_NON_NULL),      /* 0xd4 */ \
        HANDLE_OPCODE(WASM_OP_BR_ON_NULL),           /* 0xd5 */ \
        HANDLE_OPCODE(WASM_OP_BR_ON_NON_NULL),       /* 0xd6 */ \
        HANDLE_OPCODE(EXT_OP_BLOCK),                 /* 0xd7 */ \
        HANDLE_OPCODE(EXT_OP_LOOP),                  /* 0xd8 */ \
        HANDLE_OPCODE(EXT_OP_IF),                    /* 0xd9 */ \
        HANDLE_OPCODE(EXT_OP_BR_TABLE_CACHE),        /* 0xda */ \
        HANDLE_OPCODE(EXT_OP_TRY),                   /* 0xdb */ \
        SET_GOTO_TABLE_ELEM(WASM_OP_GC_PREFIX),      /* 0xfb */ \
        SET_GOTO_TABLE_ELEM(WASM_OP_MISC_PREFIX),    /* 0xfc */ \
        SET_GOTO_TABLE_ELEM(WASM_OP_SIMD_PREFIX),    /* 0xfd */ \
        SET_GOTO_TABLE_ELEM(WASM_OP_ATOMIC_PREFIX),  /* 0xfe */ \
        DEF_DEBUG_BREAK_HANDLE() DEF_EXT_V128_HANDLE()          \
    };

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_OPCODE_H */
