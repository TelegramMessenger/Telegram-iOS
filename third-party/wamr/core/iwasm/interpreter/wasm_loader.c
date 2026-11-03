/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "wasm_loader.h"
#include "bh_platform.h"
#include "wasm.h"
#include "wasm_opcode.h"
#include "wasm_runtime.h"
#include "wasm_loader_common.h"
#include "../common/wasm_native.h"
#include "../common/wasm_memory.h"
#if WASM_ENABLE_GC != 0
#include "../common/gc/gc_type.h"
#include "../common/gc/gc_object.h"
#endif
#if WASM_ENABLE_DEBUG_INTERP != 0
#include "../libraries/debug-engine/debug_engine.h"
#endif
#if WASM_ENABLE_FAST_JIT != 0
#include "../fast-jit/jit_compiler.h"
#include "../fast-jit/jit_codecache.h"
#endif
#if WASM_ENABLE_JIT != 0
#include "../compilation/aot_llvm.h"
#endif

#ifndef TRACE_WASM_LOADER
#define TRACE_WASM_LOADER 0
#endif

/* Read a value of given type from the address pointed to by the given
   pointer and increase the pointer to the position just after the
   value being read.  */
#define TEMPLATE_READ_VALUE(Type, p) \
    (p += sizeof(Type), *(Type *)(p - sizeof(Type)))

#if WASM_ENABLE_MEMORY64 != 0
static bool
has_module_memory64(WASMModule *module)
{
    /* TODO: multi-memories for now assuming the memory idx type is consistent
     * across multi-memories */
    if (module->import_memory_count > 0)
        return !!(module->import_memories[0].u.memory.mem_type.flags
                  & MEMORY64_FLAG);
    else if (module->memory_count > 0)
        return !!(module->memories[0].flags & MEMORY64_FLAG);

    return false;
}

static bool
is_table_64bit(WASMModule *module, uint32 table_idx)
{
    if (table_idx < module->import_table_count)
        return !!(module->import_tables[table_idx].u.table.table_type.flags
                  & TABLE64_FLAG);
    else
        return !!(module->tables[table_idx - module->import_table_count]
                      .table_type.flags
                  & TABLE64_FLAG);

    return false;
}
#endif

static void
set_error_buf(char *error_buf, uint32 error_buf_size, const char *string)
{
    wasm_loader_set_error_buf(error_buf, error_buf_size, string, false);
}

#if WASM_ENABLE_MEMORY64 != 0
static void
set_error_buf_mem_offset_out_of_range(char *error_buf, uint32 error_buf_size)
{
    if (error_buf != NULL) {
        snprintf(error_buf, error_buf_size, "offset out of range");
    }
}
#endif

static void
set_error_buf_v(char *error_buf, uint32 error_buf_size, const char *format, ...)
{
    va_list args;
    char buf[128];

    if (error_buf != NULL) {
        va_start(args, format);
        vsnprintf(buf, sizeof(buf), format, args);
        va_end(args);
        snprintf(error_buf, error_buf_size, "WASM module load failed: %s", buf);
    }
}

static bool
check_buf(const uint8 *buf, const uint8 *buf_end, uint32 length,
          char *error_buf, uint32 error_buf_size)
{
    if ((uintptr_t)buf + length < (uintptr_t)buf
        || (uintptr_t)buf + length > (uintptr_t)buf_end) {
        set_error_buf(error_buf, error_buf_size,
                      "unexpected end of section or function");
        return false;
    }
    return true;
}

static bool
check_buf1(const uint8 *buf, const uint8 *buf_end, uint32 length,
           char *error_buf, uint32 error_buf_size)
{
    if ((uintptr_t)buf + length < (uintptr_t)buf
        || (uintptr_t)buf + length > (uintptr_t)buf_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }
    return true;
}

#define CHECK_BUF(buf, buf_end, length)                                    \
    do {                                                                   \
        if (!check_buf(buf, buf_end, length, error_buf, error_buf_size)) { \
            goto fail;                                                     \
        }                                                                  \
    } while (0)

#define CHECK_BUF1(buf, buf_end, length)                                    \
    do {                                                                    \
        if (!check_buf1(buf, buf_end, length, error_buf, error_buf_size)) { \
            goto fail;                                                      \
        }                                                                   \
    } while (0)

#define skip_leb(p) while (*p++ & 0x80)
#define skip_leb_int64(p, p_end) skip_leb(p)
#define skip_leb_uint32(p, p_end) skip_leb(p)
#define skip_leb_int32(p, p_end) skip_leb(p)
#define skip_leb_mem_offset(p, p_end) skip_leb(p)
#define skip_leb_memidx(p, p_end) skip_leb(p)
#if WASM_ENABLE_MULTI_MEMORY == 0
#define skip_leb_align(p, p_end) skip_leb(p)
#else
/* Skip the following memidx if applicable */
#define skip_leb_align(p, p_end)       \
    do {                               \
        if (*p++ & OPT_MEMIDX_FLAG)    \
            skip_leb_uint32(p, p_end); \
    } while (0)
#endif

#define read_uint8(p) TEMPLATE_READ_VALUE(uint8, p)
#define read_uint32(p) TEMPLATE_READ_VALUE(uint32, p)

#define read_leb_int64(p, p_end, res)                                   \
    do {                                                                \
        uint64 res64;                                                   \
        if (!read_leb((uint8 **)&p, p_end, 64, true, &res64, error_buf, \
                      error_buf_size))                                  \
            goto fail;                                                  \
        res = (int64)res64;                                             \
    } while (0)

#if WASM_ENABLE_MEMORY64 != 0
#define read_leb_mem_offset(p, p_end, res)                                    \
    do {                                                                      \
        uint64 res64;                                                         \
        if (!read_leb((uint8 **)&p, p_end, is_memory64 ? 64 : 32, false,      \
                      &res64, error_buf, error_buf_size)) {                   \
            set_error_buf_mem_offset_out_of_range(error_buf, error_buf_size); \
            goto fail;                                                        \
        }                                                                     \
        res = (mem_offset_t)res64;                                            \
    } while (0)
#else
#define read_leb_mem_offset(p, p_end, res) read_leb_uint32(p, p_end, res)
#endif

#define read_leb_uint32(p, p_end, res)                                   \
    do {                                                                 \
        uint64 res64;                                                    \
        if (!read_leb((uint8 **)&p, p_end, 32, false, &res64, error_buf, \
                      error_buf_size))                                   \
            goto fail;                                                   \
        res = (uint32)res64;                                             \
    } while (0)

#define read_leb_int32(p, p_end, res)                                   \
    do {                                                                \
        uint64 res64;                                                   \
        if (!read_leb((uint8 **)&p, p_end, 32, true, &res64, error_buf, \
                      error_buf_size))                                  \
            goto fail;                                                  \
        res = (int32)res64;                                             \
    } while (0)

#if WASM_ENABLE_MULTI_MEMORY != 0
#define check_memidx(module, memidx)                                        \
    do {                                                                    \
        if (memidx >= module->import_memory_count + module->memory_count) { \
            set_error_buf_v(error_buf, error_buf_size, "unknown memory %d", \
                            memidx);                                        \
            goto fail;                                                      \
        }                                                                   \
    } while (0)
/* Bit 6(0x40) indicating the optional memidx, and reset bit 6 for
 * alignment check */
#define read_leb_memarg(p, p_end, res)                      \
    do {                                                    \
        read_leb_uint32(p, p_end, res);                     \
        if (res & OPT_MEMIDX_FLAG) {                        \
            res &= ~OPT_MEMIDX_FLAG;                        \
            read_leb_uint32(p, p_end, memidx); /* memidx */ \
            check_memidx(module, memidx);                   \
        }                                                   \
    } while (0)
#else
/* reserved byte 0x00 */
#define check_memidx(module, memidx)                                        \
    do {                                                                    \
        (void)module;                                                       \
        if (memidx != 0) {                                                  \
            set_error_buf(error_buf, error_buf_size, "zero byte expected"); \
            goto fail;                                                      \
        }                                                                   \
    } while (0)
#define read_leb_memarg(p, p_end, res) read_leb_uint32(p, p_end, res)
#endif

static char *
type2str(uint8 type)
{
    char *type_str[] = { "v128", "f64", "f32", "i64", "i32" };
#if WASM_ENABLE_GC != 0
    char *type_str_ref[] = { "stringview_iter",
                             "stringview_wtf16",
                             "(ref null ht)",
                             "(ref ht)",
                             "", /* reserved */
                             "stringview_wtf8",
                             "stringref",
                             "", /* reserved */
                             "", /* reserved */
                             "arrayref",
                             "structref",
                             "i31ref",
                             "eqref",
                             "anyref",
                             "externref",
                             "funcref",
                             "nullref",
                             "nullexternref",
                             "nullfuncref" };
#endif

    if (type >= VALUE_TYPE_V128 && type <= VALUE_TYPE_I32)
        return type_str[type - VALUE_TYPE_V128];
#if WASM_ENABLE_GC != 0
    else if (wasm_is_type_reftype(type))
        return type_str_ref[type - REF_TYPE_STRINGVIEWITER];
#endif
    else if (type == VALUE_TYPE_FUNCREF)
        return "funcref";
    else if (type == VALUE_TYPE_EXTERNREF)
        return "externref";
    else
        return "unknown type";
}

static bool
is_32bit_type(uint8 type)
{
    if (type == VALUE_TYPE_I32
        || type == VALUE_TYPE_F32
        /* the operand stack is in polymorphic state */
        || type == VALUE_TYPE_ANY
#if WASM_ENABLE_GC != 0
        || (sizeof(uintptr_t) == 4 && wasm_is_type_reftype(type))
#elif WASM_ENABLE_REF_TYPES != 0
        /* For reference types, we use uint32 index to represent
           the funcref and externref */
        || type == VALUE_TYPE_FUNCREF || type == VALUE_TYPE_EXTERNREF
#endif
    )
        return true;
    return false;
}

static bool
is_64bit_type(uint8 type)
{
    if (type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64
#if WASM_ENABLE_GC != 0
        || (sizeof(uintptr_t) == 8 && wasm_is_type_reftype(type))
#endif
    )
        return true;
    return false;
}

#if WASM_ENABLE_GC != 0
static bool
is_packed_type(uint8 type)
{
    return (type == PACKED_TYPE_I8 || type == PACKED_TYPE_I16) ? true : false;
}
#endif

static bool
is_byte_a_type(uint8 type)
{
    return (is_valid_value_type_for_interpreter(type)
            || (type == VALUE_TYPE_VOID))
               ? true
               : false;
}

#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
static V128
read_i8x16(uint8 *p_buf, char *error_buf, uint32 error_buf_size)
{
    V128 result;
    uint8 i;

    for (i = 0; i != 16; ++i) {
        result.i8x16[i] = read_uint8(p_buf);
    }

    return result;
}
#endif /* end of (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) || \
          (WASM_ENABLE_FAST_INTERP != 0) */
#endif /* end of WASM_ENABLE_SIMD */

static void *
loader_malloc(uint64 size, char *error_buf, uint32 error_buf_size)
{
    void *mem;

    if (size >= UINT32_MAX || !(mem = wasm_runtime_malloc((uint32)size))) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return NULL;
    }

    memset(mem, 0, (uint32)size);
    return mem;
}

static void *
memory_realloc(void *mem_old, uint32 size_old, uint32 size_new, char *error_buf,
               uint32 error_buf_size)
{
    uint8 *mem_new;
    bh_assert(size_new > size_old);

    if ((mem_new = wasm_runtime_realloc(mem_old, size_new))) {
        memset(mem_new + size_old, 0, size_new - size_old);
        return mem_new;
    }

    if ((mem_new = loader_malloc(size_new, error_buf, error_buf_size))) {
        bh_memcpy_s(mem_new, size_new, mem_old, size_old);
        wasm_runtime_free(mem_old);
    }
    return mem_new;
}

#define MEM_REALLOC(mem, size_old, size_new)                               \
    do {                                                                   \
        void *mem_new = memory_realloc(mem, size_old, size_new, error_buf, \
                                       error_buf_size);                    \
        if (!mem_new)                                                      \
            goto fail;                                                     \
        mem = mem_new;                                                     \
    } while (0)

static bool
check_type_index(const WASMModule *module, uint32 type_count, uint32 type_index,
                 char *error_buf, uint32 error_buf_size)
{
    if (type_index >= type_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown type %d",
                        type_index);
        return false;
    }
    return true;
}

#if WASM_ENABLE_GC != 0
static bool
check_array_type(const WASMModule *module, uint32 type_index, char *error_buf,
                 uint32 error_buf_size)
{
    if (!check_type_index(module, module->type_count, type_index, error_buf,
                          error_buf_size)) {
        return false;
    }
    if (module->types[type_index] == NULL
        || module->types[type_index]->type_flag != WASM_TYPE_ARRAY) {
        set_error_buf(error_buf, error_buf_size, "unknown array type");
        return false;
    }

    return true;
}
#endif

/*
 * if no GC is enabled, an valid type is always a function type.
 * but if GC is enabled, we need to check the type flag
 */
static bool
check_function_type(const WASMModule *module, uint32 type_index,
                    char *error_buf, uint32 error_buf_size)
{
    if (!check_type_index(module, module->type_count, type_index, error_buf,
                          error_buf_size)) {
        return false;
    }

#if WASM_ENABLE_GC != 0
    if (module->types[type_index] == NULL
        || module->types[type_index]->type_flag != WASM_TYPE_FUNC) {
        set_error_buf(error_buf, error_buf_size, "unknown function type");
        return false;
    }
#endif

    return true;
}

static bool
check_function_index(const WASMModule *module, uint32 function_index,
                     char *error_buf, uint32 error_buf_size)
{
    if (function_index
        >= module->import_function_count + module->function_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown function %u",
                        function_index);
        return false;
    }
    return true;
}

typedef struct InitValue {
    uint8 type;
    uint8 flag;
#if WASM_ENABLE_GC != 0
    uint8 gc_opcode;
    WASMRefType ref_type;
#endif
    WASMValue value;
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
    InitializerExpression *expr;
#endif
} InitValue;

typedef struct ConstExprContext {
    uint32 sp;
    uint32 size;
    WASMModule *module;
    InitValue *stack;
    InitValue data[WASM_CONST_EXPR_STACK_SIZE];
} ConstExprContext;

static void
init_const_expr_stack(ConstExprContext *ctx, WASMModule *module)
{
    ctx->sp = 0;
    ctx->module = module;
    ctx->stack = ctx->data;
    ctx->size = WASM_CONST_EXPR_STACK_SIZE;
}

static bool
push_const_expr_stack(ConstExprContext *ctx, uint8 flag, uint8 type,
#if WASM_ENABLE_GC != 0
                      WASMRefType *ref_type, uint8 gc_opcode,
#endif
                      WASMValue *value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                      InitializerExpression *expr,
#endif
                      char *error_buf, uint32 error_buf_size)
{
    InitValue *cur_value;

    if (ctx->sp >= ctx->size) {
        if (ctx->stack != ctx->data) {
            MEM_REALLOC(ctx->stack, ctx->size * sizeof(InitValue),
                        (ctx->size + 4) * sizeof(InitValue));
        }
        else {
            if (!(ctx->stack =
                      loader_malloc((ctx->size + 4) * (uint64)sizeof(InitValue),
                                    error_buf, error_buf_size))) {
                goto fail;
            }
            bh_memcpy_s(ctx->stack, (ctx->size + 4) * (uint32)sizeof(InitValue),
                        ctx->data, ctx->size * (uint32)sizeof(InitValue));
        }
        ctx->size += 4;
    }

    cur_value = &ctx->stack[ctx->sp++];
    cur_value->type = type;
    cur_value->flag = flag;
    cur_value->value = *value;

#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
    cur_value->expr = expr;
#endif

#if WASM_ENABLE_GC != 0
    cur_value->gc_opcode = gc_opcode;
    if (wasm_is_type_multi_byte_type(type)) {
        bh_memcpy_s(&cur_value->ref_type, wasm_reftype_struct_size(ref_type),
                    ref_type, wasm_reftype_struct_size(ref_type));
    }
#endif

    return true;
fail:
    return false;
}

#if WASM_ENABLE_GC != 0
static void
destroy_init_expr_data_recursive(WASMModule *module, void *data)
{
    WASMStructNewInitValues *struct_init_values =
        (WASMStructNewInitValues *)data;
    WASMArrayNewInitValues *array_init_values = (WASMArrayNewInitValues *)data;
    WASMType *wasm_type;
    uint32 i;

    if (!data)
        return;

    wasm_type = module->types[struct_init_values->type_idx];

    /* The data can only be type of `WASMStructNewInitValues *`
       or `WASMArrayNewInitValues *` */
    bh_assert(wasm_type->type_flag == WASM_TYPE_STRUCT
              || wasm_type->type_flag == WASM_TYPE_ARRAY);

    if (wasm_type->type_flag == WASM_TYPE_STRUCT) {
        WASMStructType *struct_type = (WASMStructType *)wasm_type;
        WASMRefType *ref_type;
        uint8 field_type;

        uint16 ref_type_map_index = 0;
        for (i = 0; i < struct_init_values->count; i++) {
            field_type = struct_type->fields[i].field_type;
            if (wasm_is_type_multi_byte_type(field_type))
                ref_type =
                    struct_type->ref_type_maps[ref_type_map_index++].ref_type;
            else
                ref_type = NULL;
            if (wasm_reftype_is_subtype_of(field_type, ref_type,
                                           REF_TYPE_STRUCTREF, NULL,
                                           module->types, module->type_count)
                || wasm_reftype_is_subtype_of(
                    field_type, ref_type, REF_TYPE_ARRAYREF, NULL,
                    module->types, module->type_count)) {
                destroy_init_expr_data_recursive(
                    module, struct_init_values->fields[i].data);
            }
        }
    }
    else if (wasm_type->type_flag == WASM_TYPE_ARRAY) {
        WASMArrayType *array_type = (WASMArrayType *)wasm_type;
        WASMRefType *elem_ref_type = array_type->elem_ref_type;
        uint8 elem_type = array_type->elem_type;

        for (i = 0; i < array_init_values->length; i++) {
            if (wasm_reftype_is_subtype_of(elem_type, elem_ref_type,
                                           REF_TYPE_STRUCTREF, NULL,
                                           module->types, module->type_count)
                || wasm_reftype_is_subtype_of(
                    elem_type, elem_ref_type, REF_TYPE_ARRAYREF, NULL,
                    module->types, module->type_count)) {
                destroy_init_expr_data_recursive(
                    module, array_init_values->elem_data[i].data);
            }
        }
    }

    wasm_runtime_free(data);
}
#endif

static bool
pop_const_expr_stack(ConstExprContext *ctx, uint8 *p_flag, uint8 type,
#if WASM_ENABLE_GC != 0
                     WASMRefType *ref_type, uint8 *p_gc_opcode,
#endif
                     WASMValue *p_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                     InitializerExpression **p_expr,
#endif
                     char *error_buf, uint32 error_buf_size)
{
    InitValue *cur_value;

    if (ctx->sp == 0) {
        set_error_buf(error_buf, error_buf_size,
                      "type mismatch: const expr stack underflow");
        return false;
    }

    cur_value = &ctx->stack[--ctx->sp];

#if WASM_ENABLE_GC == 0
    if (cur_value->type != type) {
        set_error_buf(error_buf, error_buf_size, "type mismatch");
        return false;
    }
#else
    if (!wasm_reftype_is_subtype_of(cur_value->type, &cur_value->ref_type, type,
                                    ref_type, ctx->module->types,
                                    ctx->module->type_count)) {
        set_error_buf_v(error_buf, error_buf_size, "%s%s%s",
                        "type mismatch: expect ", type2str(type),
                        " but got other");
        goto fail;
    }
#endif

    if (p_flag)
        *p_flag = cur_value->flag;
    if (p_value)
        *p_value = cur_value->value;
#if WASM_ENABLE_GC != 0
    if (p_gc_opcode)
        *p_gc_opcode = cur_value->gc_opcode;
#endif
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
    if (p_expr)
        *p_expr = cur_value->expr;
#endif
    return true;

#if WASM_ENABLE_GC != 0
fail:
    if ((cur_value->flag == WASM_OP_GC_PREFIX)
        && (cur_value->gc_opcode == WASM_OP_STRUCT_NEW
            || cur_value->gc_opcode == WASM_OP_ARRAY_NEW
            || cur_value->gc_opcode == WASM_OP_ARRAY_NEW_FIXED)) {
        destroy_init_expr_data_recursive(ctx->module, cur_value->value.data);
    }
    return false;
#endif
}

static void
destroy_const_expr_stack(ConstExprContext *ctx, bool free_exprs)
{
#if WASM_ENABLE_GC != 0
    uint32 i;

    for (i = 0; i < ctx->sp; i++) {
        if ((ctx->stack[i].flag == WASM_OP_GC_PREFIX)
            && (ctx->stack[i].gc_opcode == WASM_OP_STRUCT_NEW
                || ctx->stack[i].gc_opcode == WASM_OP_ARRAY_NEW
                || ctx->stack[i].gc_opcode == WASM_OP_ARRAY_NEW_FIXED)) {
            destroy_init_expr_data_recursive(ctx->module,
                                             ctx->stack[i].value.data);
        }
    }
#endif
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
    if (free_exprs) {
        for (uint32 j = 0; j < ctx->sp; j++) {
            if (is_expr_binary_op(ctx->stack[j].expr->init_expr_type)) {
                destroy_init_expr_recursive(ctx->stack[j].expr);
                ctx->stack[j].expr = NULL;
            }
        }
    }
#endif

    if (ctx->stack != ctx->data) {
        wasm_runtime_free(ctx->stack);
    }
}

#if WASM_ENABLE_GC != 0 || WASM_ENABLE_EXTENDED_CONST_EXPR != 0
static void
destroy_init_expr(WASMModule *module, InitializerExpression *expr)
{
#if WASM_ENABLE_GC != 0
    if (expr->init_expr_type == INIT_EXPR_TYPE_STRUCT_NEW
        || expr->init_expr_type == INIT_EXPR_TYPE_ARRAY_NEW
        || expr->init_expr_type == INIT_EXPR_TYPE_ARRAY_NEW_FIXED) {
        destroy_init_expr_data_recursive(module, expr->u.unary.v.data);
    }
#endif

#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
    // free left expr and right exprs for binary oprand
    if (!is_expr_binary_op(expr->init_expr_type)) {
        return;
    }
    if (expr->u.binary.l_expr) {
        destroy_init_expr_recursive(expr->u.binary.l_expr);
    }
    if (expr->u.binary.r_expr) {
        destroy_init_expr_recursive(expr->u.binary.r_expr);
    }
    expr->u.binary.l_expr = expr->u.binary.r_expr = NULL;
#endif
}
#endif

/* for init expr
 *    (data (i32.add (i32.const 0) (i32.sub (i32.const 1) (i32.const 2)))),
 *   the binary format is
 *       0x11: 41 00 ; i32.const 0
 *       0x13: 41 01 ; i32.const 1
 *       0x15: 41 02 ; i32.const 2
 *       0x17: 6b    ; i32.sub
 *       0x18: 6a    ; i32.add
 *   for traversal: read opcodes and push them onto the stack. When encountering
 *   a binary opcode, pop two values from the stack which become the left and
 *  right child nodes of this binary operation node.
 */
static bool
load_init_expr(WASMModule *module, const uint8 **p_buf, const uint8 *buf_end,
               InitializerExpression *init_expr, uint8 type, void *ref_type,
               char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint8 flag, *p_float;
    uint32 i;
    ConstExprContext const_expr_ctx = { 0 };
    WASMValue cur_value = { 0 };
#if WASM_ENABLE_GC != 0
    uint32 opcode1, type_idx;
    uint8 opcode;
    WASMRefType cur_ref_type = { 0 };
#endif
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
    InitializerExpression *cur_expr = NULL;
#endif

    init_const_expr_stack(&const_expr_ctx, module);

    CHECK_BUF(p, p_end, 1);
    flag = read_uint8(p);

    while (flag != WASM_OP_END) {
        switch (flag) {
            /* i32.const */
            case INIT_EXPR_TYPE_I32_CONST:
                read_leb_int32(p, p_end, cur_value.i32);

                if (!push_const_expr_stack(&const_expr_ctx, flag,
                                           VALUE_TYPE_I32,
#if WASM_ENABLE_GC != 0
                                           NULL, 0,
#endif
                                           &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
                break;
            /* i64.const */
            case INIT_EXPR_TYPE_I64_CONST:
                read_leb_int64(p, p_end, cur_value.i64);

                if (!push_const_expr_stack(&const_expr_ctx, flag,
                                           VALUE_TYPE_I64,
#if WASM_ENABLE_GC != 0
                                           NULL, 0,
#endif
                                           &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
                break;
            /* f32.const */
            case INIT_EXPR_TYPE_F32_CONST:
                CHECK_BUF(p, p_end, 4);
                p_float = (uint8 *)&cur_value.f32;
                for (i = 0; i < sizeof(float32); i++)
                    *p_float++ = *p++;

                if (!push_const_expr_stack(&const_expr_ctx, flag,
                                           VALUE_TYPE_F32,
#if WASM_ENABLE_GC != 0
                                           NULL, 0,
#endif
                                           &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
                break;
            /* f64.const */
            case INIT_EXPR_TYPE_F64_CONST:
                CHECK_BUF(p, p_end, 8);
                p_float = (uint8 *)&cur_value.f64;
                for (i = 0; i < sizeof(float64); i++)
                    *p_float++ = *p++;

                if (!push_const_expr_stack(&const_expr_ctx, flag,
                                           VALUE_TYPE_F64,
#if WASM_ENABLE_GC != 0
                                           NULL, 0,
#endif
                                           &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
                break;
#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
            /* v128.const */
            case INIT_EXPR_TYPE_V128_CONST:
            {
                uint64 high, low;

                CHECK_BUF(p, p_end, 1);
                (void)read_uint8(p);

                CHECK_BUF(p, p_end, 16);
                wasm_runtime_read_v128(p, &high, &low);
                p += 16;

                cur_value.v128.i64x2[0] = high;
                cur_value.v128.i64x2[1] = low;

                if (!push_const_expr_stack(&const_expr_ctx, flag,
                                           VALUE_TYPE_V128,
#if WASM_ENABLE_GC != 0
                                           NULL, 0,
#endif
                                           &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
#if WASM_ENABLE_WAMR_COMPILER != 0
                /* If any init_expr is v128.const, mark SIMD used */
                module->is_simd_used = true;
#endif
                break;
            }
#endif /* end of (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) || \
          (WASM_ENABLE_FAST_INTERP != 0) */
#endif /* end of WASM_ENABLE_SIMD */
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
            case INIT_EXPR_TYPE_I32_ADD:
            case INIT_EXPR_TYPE_I32_SUB:
            case INIT_EXPR_TYPE_I32_MUL:
            case INIT_EXPR_TYPE_I64_ADD:
            case INIT_EXPR_TYPE_I64_SUB:
            case INIT_EXPR_TYPE_I64_MUL:
            {

                InitializerExpression *l_expr, *r_expr;
                WASMValue l_value, r_value;
                uint8 l_flag, r_flag;
                uint8 value_type;

                if (flag == INIT_EXPR_TYPE_I32_ADD
                    || flag == INIT_EXPR_TYPE_I32_SUB
                    || flag == INIT_EXPR_TYPE_I32_MUL) {
                    value_type = VALUE_TYPE_I32;
                }
                else {
                    value_type = VALUE_TYPE_I64;
                }

                /* If right flag indicates a binary operation, right expr will
                 * be popped from stack. Otherwise, allocate a new expr for
                 * right expr. Same for left expr.
                 */
                if (!(pop_const_expr_stack(&const_expr_ctx, &r_flag, value_type,
#if WASM_ENABLE_GC != 0
                                           NULL, NULL,
#endif
                                           &r_value, &r_expr, error_buf,
                                           error_buf_size))) {
                    goto fail;
                }
                if (!is_expr_binary_op(r_flag)) {
                    if (!(r_expr = loader_malloc(sizeof(InitializerExpression),
                                                 error_buf, error_buf_size))) {
                        goto fail;
                    }
                    r_expr->init_expr_type = r_flag;
                    r_expr->u.unary.v = r_value;
                }

                if (!(pop_const_expr_stack(&const_expr_ctx, &l_flag, value_type,
#if WASM_ENABLE_GC != 0
                                           NULL, NULL,
#endif
                                           &l_value, &l_expr, error_buf,
                                           error_buf_size))) {
                    destroy_init_expr_recursive(r_expr);
                    goto fail;
                }
                if (!is_expr_binary_op(l_flag)) {
                    if (!(l_expr = loader_malloc(sizeof(InitializerExpression),
                                                 error_buf, error_buf_size))) {
                        destroy_init_expr_recursive(r_expr);
                        goto fail;
                    }
                    l_expr->init_expr_type = l_flag;
                    l_expr->u.unary.v = l_value;
                }

                if (!(cur_expr = loader_malloc(sizeof(InitializerExpression),
                                               error_buf, error_buf_size))) {
                    destroy_init_expr_recursive(l_expr);
                    destroy_init_expr_recursive(r_expr);
                    goto fail;
                }
                cur_expr->init_expr_type = flag;
                cur_expr->u.binary.l_expr = l_expr;
                cur_expr->u.binary.r_expr = r_expr;

                if (!push_const_expr_stack(&const_expr_ctx, flag, value_type,
#if WASM_ENABLE_GC != 0
                                           NULL, 0,
#endif
                                           &cur_value, cur_expr, error_buf,
                                           error_buf_size)) {
                    destroy_init_expr_recursive(cur_expr);
                    goto fail;
                }

                break;
            }
#endif /* end of WASM_ENABLE_EXTENDED_CONST_EXPR */
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            /* ref.func */
            case INIT_EXPR_TYPE_FUNCREF_CONST:
            {
                uint32 func_idx;
                read_leb_uint32(p, p_end, func_idx);
                cur_value.ref_index = func_idx;
                if (!check_function_index(module, func_idx, error_buf,
                                          error_buf_size)) {
                    goto fail;
                }

#if WASM_ENABLE_GC == 0
                if (!push_const_expr_stack(&const_expr_ctx, flag,
                                           VALUE_TYPE_FUNCREF, &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
#else
                if (func_idx < module->import_function_count) {
                    type_idx =
                        module->import_functions[func_idx].u.function.type_idx;
                }
                else {
                    type_idx = module
                                   ->functions[func_idx
                                               - module->import_function_count]
                                   ->type_idx;
                }
                wasm_set_refheaptype_typeidx(&cur_ref_type.ref_ht_typeidx,
                                             false, type_idx);
                if (!push_const_expr_stack(&const_expr_ctx, flag,
                                           cur_ref_type.ref_type, &cur_ref_type,
                                           0, &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
#endif
#if WASM_ENABLE_WAMR_COMPILER != 0
                module->is_ref_types_used = true;
#endif
                break;
            }

            /* ref.null */
            case INIT_EXPR_TYPE_REFNULL_CONST:
            {
#if WASM_ENABLE_GC == 0
                uint8 type1;
                CHECK_BUF(p, p_end, 1);
                type1 = read_uint8(p);
                if (type1 != VALUE_TYPE_FUNCREF
                    && type1 != VALUE_TYPE_EXTERNREF) {
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid reference type");
                    goto fail;
                }
                cur_value.ref_index = NULL_REF;
                if (!push_const_expr_stack(&const_expr_ctx, flag, type1,
                                           &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;
#else
                /*
                 * According to the current GC SPEC rules, the heap_type must be
                 * validated when ref.null is used. It can be an absheaptype,
                 * or the type C.types[type_idx] must be defined in the context.
                 */
                int32 heap_type;
                read_leb_int32(p, p_end, heap_type);
                cur_value.gc_obj = NULL_REF;

                /*
                 * The current check of heap_type can deterministically infer
                 * the result of the previous condition
                 * `(!is_byte_a_type(type1) ||
                 * wasm_is_type_multi_byte_type(type1))`. Therefore, the
                 * original condition is redundant and has been removed.
                 *
                 * This logic is consistent with the implementation of the
                 * `WASM_OP_REF_NULL` case in the `wasm_loader_prepare_bytecode`
                 * function.
                 */

                if (heap_type >= 0) {
                    if (!check_type_index(module, module->type_count, heap_type,
                                          error_buf, error_buf_size)) {
                        goto fail;
                    }
                    wasm_set_refheaptype_typeidx(&cur_ref_type.ref_ht_typeidx,
                                                 true, heap_type);
                    if (!push_const_expr_stack(&const_expr_ctx, flag,
                                               cur_ref_type.ref_type,
                                               &cur_ref_type, 0, &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                               NULL,
#endif
                                               error_buf, error_buf_size))
                        goto fail;
                }
                else {
                    if (!wasm_is_valid_heap_type(heap_type)) {
                        set_error_buf_v(error_buf, error_buf_size,
                                        "unknown type %d", heap_type);
                        goto fail;
                    }
                    cur_ref_type.ref_ht_common.ref_type =
                        (uint8)((int32)0x80 + heap_type);
                    if (!push_const_expr_stack(&const_expr_ctx, flag,
                                               cur_ref_type.ref_type, NULL, 0,
                                               &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                               NULL,
#endif
                                               error_buf, error_buf_size))
                        goto fail;
                }
#endif
#if WASM_ENABLE_WAMR_COMPILER != 0
                module->is_ref_types_used = true;
#endif
                break;
            }
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

            /* get_global */
            case INIT_EXPR_TYPE_GET_GLOBAL:
            {
                uint32 global_idx;
                uint8 global_type;

                read_leb_uint32(p, p_end, cur_value.global_index);
                global_idx = cur_value.global_index;

                /*
                 * Currently, constant expressions occurring as initializers
                 * of globals are further constrained in that contained
                 * global.get instructions are
                 * only allowed to refer to imported globals.
                 *
                 * https://webassembly.github.io/spec/core/valid/instructions.html#constant-expressions
                 */
                if (global_idx >= module->import_global_count
                /* make spec test happy */
#if WASM_ENABLE_GC != 0
                                      + module->global_count
#endif
                ) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "unknown global %u", global_idx);
                    goto fail;
                }
                if (
                /* make spec test happy */
#if WASM_ENABLE_GC != 0
                    global_idx < module->import_global_count &&
#endif
                    module->import_globals[global_idx]
                        .u.global.type.is_mutable) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "constant expression required");
                    goto fail;
                }

                if (global_idx < module->import_global_count) {
                    global_type = module->import_globals[global_idx]
                                      .u.global.type.val_type;
#if WASM_ENABLE_GC != 0
                    if (wasm_is_type_multi_byte_type(global_type)) {
                        WASMRefType *global_ref_type =
                            module->import_globals[global_idx]
                                .u.global.ref_type;
                        bh_memcpy_s(&cur_ref_type,
                                    wasm_reftype_struct_size(global_ref_type),
                                    global_ref_type,
                                    wasm_reftype_struct_size(global_ref_type));
                    }
#endif
                }
                else {
                    global_type =
                        module
                            ->globals[global_idx - module->import_global_count]
                            .type.val_type;
#if WASM_ENABLE_GC != 0
                    if (wasm_is_type_multi_byte_type(global_type)) {
                        WASMRefType *global_ref_type =
                            module
                                ->globals[global_idx
                                          - module->import_global_count]
                                .ref_type;
                        bh_memcpy_s(&cur_ref_type,
                                    wasm_reftype_struct_size(global_ref_type),
                                    global_ref_type,
                                    wasm_reftype_struct_size(global_ref_type));
                    }
#endif
                }

                if (!push_const_expr_stack(&const_expr_ctx, flag, global_type,
#if WASM_ENABLE_GC != 0
                                           &cur_ref_type, 0,
#endif
                                           &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                           NULL,
#endif
                                           error_buf, error_buf_size))
                    goto fail;

                break;
            }

#if WASM_ENABLE_GC != 0
            /* struct.new and array.new */
            case WASM_OP_GC_PREFIX:
            {
                read_leb_uint32(p, p_end, opcode1);

                switch (opcode1) {
                    case WASM_OP_STRUCT_NEW:
                    {
                        WASMStructType *struct_type;
                        WASMStructNewInitValues *struct_init_values = NULL;
                        uint32 field_count;
                        read_leb_uint32(p, p_end, type_idx);

                        if (!check_type_index(module, module->type_count,
                                              type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }

                        struct_type = (WASMStructType *)module->types[type_idx];
                        if (struct_type->base_type.type_flag
                            != WASM_TYPE_STRUCT) {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown struct type");
                            goto fail;
                        }
                        field_count = struct_type->field_count;

                        if (!(struct_init_values = loader_malloc(
                                  offsetof(WASMStructNewInitValues, fields)
                                      + (uint64)field_count * sizeof(WASMValue),
                                  error_buf, error_buf_size))) {
                            goto fail;
                        }
                        struct_init_values->type_idx = type_idx;
                        struct_init_values->count = field_count;

                        for (i = field_count; i > 0; i--) {
                            WASMRefType *field_ref_type = NULL;
                            uint32 field_idx = i - 1;
                            uint8 field_type =
                                struct_type->fields[field_idx].field_type;
                            if (wasm_is_type_multi_byte_type(field_type)) {
                                field_ref_type = wasm_reftype_map_find(
                                    struct_type->ref_type_maps,
                                    struct_type->ref_type_map_count, field_idx);
                            }

                            if (is_packed_type(field_type)) {
                                field_type = VALUE_TYPE_I32;
                            }

                            if (!pop_const_expr_stack(
                                    &const_expr_ctx, NULL, field_type,
                                    field_ref_type, NULL,
                                    &struct_init_values->fields[field_idx],
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                    NULL,
#endif
                                    error_buf, error_buf_size)) {
                                destroy_init_expr_data_recursive(
                                    module, struct_init_values);
                                goto fail;
                            }
                        }

                        cur_value.data = struct_init_values;
                        wasm_set_refheaptype_typeidx(
                            &cur_ref_type.ref_ht_typeidx, false, type_idx);
                        if (!push_const_expr_stack(
                                &const_expr_ctx, flag, cur_ref_type.ref_type,
                                &cur_ref_type, (uint8)opcode1, &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                NULL,
#endif
                                error_buf, error_buf_size)) {
                            destroy_init_expr_data_recursive(
                                module, struct_init_values);
                            goto fail;
                        }
                        break;
                    }
                    case WASM_OP_STRUCT_NEW_DEFAULT:
                    {
                        read_leb_uint32(p, p_end, cur_value.type_index);
                        type_idx = cur_value.type_index;

                        if (!check_type_index(module, module->type_count,
                                              type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }
                        if (module->types[type_idx] == NULL
                            || module->types[type_idx]->type_flag
                                   != WASM_TYPE_STRUCT) {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown struct type");
                            goto fail;
                        }

                        cur_value.type_index = type_idx;
                        cur_value.data = NULL;
                        wasm_set_refheaptype_typeidx(
                            &cur_ref_type.ref_ht_typeidx, false, type_idx);
                        if (!push_const_expr_stack(
                                &const_expr_ctx, flag, cur_ref_type.ref_type,
                                &cur_ref_type, (uint8)opcode1, &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                NULL,
#endif
                                error_buf, error_buf_size)) {
                            goto fail;
                        }
                        break;
                    }
                    case WASM_OP_ARRAY_NEW:
                    case WASM_OP_ARRAY_NEW_DEFAULT:
                    case WASM_OP_ARRAY_NEW_FIXED:
                    {
                        WASMArrayNewInitValues *array_init_values = NULL;
                        WASMArrayType *array_type = NULL;
                        WASMRefType *elem_ref_type = NULL;
                        uint64 total_size;
                        uint8 elem_type;

                        read_leb_uint32(p, p_end, cur_value.type_index);
                        type_idx = cur_value.type_index;

                        if (!check_type_index(module, module->type_count,
                                              type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }

                        array_type = (WASMArrayType *)module->types[type_idx];
                        if (array_type->base_type.type_flag
                            != WASM_TYPE_ARRAY) {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown array type");
                            goto fail;
                        }

                        if (opcode1 != WASM_OP_ARRAY_NEW_DEFAULT) {
                            elem_type = array_type->elem_type;
                            if (wasm_is_type_multi_byte_type(elem_type)) {
                                elem_ref_type = array_type->elem_ref_type;
                            }

                            if (is_packed_type(elem_type)) {
                                elem_type = VALUE_TYPE_I32;
                            }

                            if (opcode1 == WASM_OP_ARRAY_NEW) {
                                WASMValue len_val = { 0 };
                                uint64 size = 0;

                                if (!pop_const_expr_stack(
                                        &const_expr_ctx, NULL, VALUE_TYPE_I32,
                                        NULL, NULL, &len_val,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                        NULL,
#endif
                                        error_buf, error_buf_size)) {
                                    goto fail;
                                }

                                size =
                                    sizeof(WASMArrayNewInitValues)
                                    + sizeof(WASMValue) * (uint64)len_val.i32;
                                if (!(array_init_values = loader_malloc(
                                          size, error_buf, error_buf_size))) {
                                    goto fail;
                                }

                                array_init_values->type_idx = type_idx;
                                array_init_values->length = len_val.i32;

                                if (!pop_const_expr_stack(
                                        &const_expr_ctx, NULL, elem_type,
                                        elem_ref_type, NULL,
                                        &array_init_values->elem_data[0],
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                        NULL,
#endif
                                        error_buf, error_buf_size)) {
                                    destroy_init_expr_data_recursive(
                                        module, array_init_values);
                                    goto fail;
                                }

                                cur_value.data = array_init_values;
                            }
                            else {
                                /* WASM_OP_ARRAY_NEW_FIXED */
                                uint32 len;
                                read_leb_uint32(p, p_end, len);

                                total_size =
                                    (uint64)offsetof(WASMArrayNewInitValues,
                                                     elem_data)
                                    + (uint64)sizeof(WASMValue) * len;
                                if (!(array_init_values =
                                          loader_malloc(total_size, error_buf,
                                                        error_buf_size))) {
                                    goto fail;
                                }

                                array_init_values->type_idx = type_idx;
                                array_init_values->length = len;

                                for (i = len; i > 0; i--) {
                                    if (!pop_const_expr_stack(
                                            &const_expr_ctx, NULL, elem_type,
                                            elem_ref_type, NULL,
                                            &array_init_values
                                                 ->elem_data[i - 1],
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                            NULL,
#endif
                                            error_buf, error_buf_size)) {
                                        destroy_init_expr_data_recursive(
                                            module, array_init_values);
                                        goto fail;
                                    }
                                }

                                cur_value.data = array_init_values;
                            }
                        }
                        else {
                            /* WASM_OP_ARRAY_NEW_DEFAULT */
                            WASMValue len_val;
                            uint32 len;

                            /* POP(i32) */
                            if (!pop_const_expr_stack(
                                    &const_expr_ctx, NULL, VALUE_TYPE_I32, NULL,
                                    NULL, &len_val,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                    NULL,
#endif
                                    error_buf, error_buf_size)) {
                                goto fail;
                            }
                            len = len_val.i32;

                            cur_value.array_new_default.type_index = type_idx;
                            cur_value.array_new_default.length = len;
                        }

                        wasm_set_refheaptype_typeidx(
                            &cur_ref_type.ref_ht_typeidx, false, type_idx);
                        if (!push_const_expr_stack(
                                &const_expr_ctx, flag, cur_ref_type.ref_type,
                                &cur_ref_type, (uint8)opcode1, &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                NULL,
#endif
                                error_buf, error_buf_size)) {
                            if (array_init_values) {
                                destroy_init_expr_data_recursive(
                                    module, array_init_values);
                            }
                            goto fail;
                        }
                        break;
                    }
                    case WASM_OP_ANY_CONVERT_EXTERN:
                    {
                        set_error_buf(error_buf, error_buf_size,
                                      "unsupported constant expression of "
                                      "extern.internalize");
                        goto fail;
                    }
                    case WASM_OP_EXTERN_CONVERT_ANY:
                    {
                        set_error_buf(error_buf, error_buf_size,
                                      "unsupported constant expression of "
                                      "extern.externalize");
                        goto fail;
                    }
                    case WASM_OP_REF_I31:
                    {
                        /* POP(i32) */
                        if (!pop_const_expr_stack(&const_expr_ctx, NULL,
                                                  VALUE_TYPE_I32, NULL, NULL,
                                                  &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                                  NULL,
#endif
                                                  error_buf, error_buf_size)) {
                            goto fail;
                        }

                        wasm_set_refheaptype_common(&cur_ref_type.ref_ht_common,
                                                    false, HEAP_TYPE_I31);
                        if (!push_const_expr_stack(
                                &const_expr_ctx, flag, cur_ref_type.ref_type,
                                &cur_ref_type, (uint8)opcode1, &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                                NULL,
#endif
                                error_buf, error_buf_size)) {
                            goto fail;
                        }
                        break;
                    }
                    default:
                        set_error_buf(
                            error_buf, error_buf_size,
                            "type mismatch or constant expression required");
                        goto fail;
                }

                break;
            }
#endif /* end of WASM_ENABLE_GC != 0 */
            default:
            {
                set_error_buf(error_buf, error_buf_size,
                              "illegal opcode "
                              "or constant expression required "
                              "or type mismatch");
                goto fail;
            }
        }

        CHECK_BUF(p, p_end, 1);
        flag = read_uint8(p);
    }

    /* There should be only one value left on the init value stack */
    if (!pop_const_expr_stack(&const_expr_ctx, &flag, type,
#if WASM_ENABLE_GC != 0
                              ref_type, &opcode,
#endif
                              &cur_value,
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                              &cur_expr,
#endif
                              error_buf, error_buf_size)) {
        goto fail;
    }

    if (const_expr_ctx.sp != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "type mismatch: illegal constant opcode sequence");
        goto fail;
    }

#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
    if (cur_expr != NULL) {
        bh_memcpy_s(init_expr, sizeof(InitializerExpression), cur_expr,
                    sizeof(InitializerExpression));
        wasm_runtime_free(cur_expr);
    }
    else {
        init_expr->init_expr_type = flag;
        init_expr->u.unary.v = cur_value;
    }

#else
    init_expr->init_expr_type = flag;
    init_expr->u.unary.v = cur_value;
#endif /* end of WASM_ENABLE_EXTENDED_CONST_EXPR != 0 */

#if WASM_ENABLE_GC != 0
    if (init_expr->init_expr_type == WASM_OP_GC_PREFIX) {
        switch (opcode) {
            case WASM_OP_STRUCT_NEW:
                init_expr->init_expr_type = INIT_EXPR_TYPE_STRUCT_NEW;
                break;
            case WASM_OP_STRUCT_NEW_DEFAULT:
                init_expr->init_expr_type = INIT_EXPR_TYPE_STRUCT_NEW_DEFAULT;
                break;
            case WASM_OP_ARRAY_NEW:
                init_expr->init_expr_type = INIT_EXPR_TYPE_ARRAY_NEW;
                break;
            case WASM_OP_ARRAY_NEW_DEFAULT:
                init_expr->init_expr_type = INIT_EXPR_TYPE_ARRAY_NEW_DEFAULT;
                break;
            case WASM_OP_ARRAY_NEW_FIXED:
                init_expr->init_expr_type = INIT_EXPR_TYPE_ARRAY_NEW_FIXED;
                break;
            case WASM_OP_REF_I31:
                init_expr->init_expr_type = INIT_EXPR_TYPE_I31_NEW;
                break;
            default:
                bh_assert(0);
                break;
        }
    }
#endif /* end of WASM_ENABLE_GC != 0 */

    *p_buf = p;
    destroy_const_expr_stack(&const_expr_ctx, false);
    return true;

fail:
    destroy_const_expr_stack(&const_expr_ctx, true);
    return false;
}

static bool
check_mutability(uint8 mutable, char *error_buf, uint32 error_buf_size)
{
    if (mutable >= 2) {
        set_error_buf(error_buf, error_buf_size, "invalid mutability");
        return false;
    }
    return true;
}

#if WASM_ENABLE_GC != 0
static void
destroy_func_type(WASMFuncType *type)
{
    /* Destroy the reference type hash set */
    if (type->ref_type_maps)
        wasm_runtime_free(type->ref_type_maps);

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    if (type->call_to_llvm_jit_from_fast_jit)
        jit_code_cache_free(type->call_to_llvm_jit_from_fast_jit);
#endif
    /* Free the type */
    wasm_runtime_free(type);
}

static void
destroy_struct_type(WASMStructType *type)
{
    if (type->ref_type_maps)
        wasm_runtime_free(type->ref_type_maps);

    wasm_runtime_free(type);
}

static void
destroy_array_type(WASMArrayType *type)
{
    wasm_runtime_free(type);
}

static void
destroy_wasm_type(WASMType *type)
{
    if (type->ref_count > 1) {
        /* The type is referenced by other types
           of current wasm module */
        type->ref_count--;
        return;
    }

    if (type->type_flag == WASM_TYPE_FUNC)
        destroy_func_type((WASMFuncType *)type);
    else if (type->type_flag == WASM_TYPE_STRUCT)
        destroy_struct_type((WASMStructType *)type);
    else if (type->type_flag == WASM_TYPE_ARRAY)
        destroy_array_type((WASMArrayType *)type);
    else {
        bh_assert(0);
    }
}

/* Resolve (ref null ht) or (ref ht) */
static bool
resolve_reftype_htref(const uint8 **p_buf, const uint8 *buf_end,
                      WASMModule *module, uint32 type_count, bool nullable,
                      WASMRefType *ref_type, char *error_buf,
                      uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;

    ref_type->ref_type =
        nullable ? REF_TYPE_HT_NULLABLE : REF_TYPE_HT_NON_NULLABLE;
    ref_type->ref_ht_common.nullable = nullable;
    read_leb_int32(p, p_end, ref_type->ref_ht_common.heap_type);

    if (wasm_is_refheaptype_typeidx(&ref_type->ref_ht_common)) {
        /* heap type is (type i), i : typeidx, >= 0 */
        if (!check_type_index(module, type_count,
                              ref_type->ref_ht_typeidx.type_idx, error_buf,
                              error_buf_size)) {
            return false;
        }
    }
    else if (!wasm_is_refheaptype_common(&ref_type->ref_ht_common)) {
        /* heap type is func, extern, any, eq, i31 or data */
        set_error_buf(error_buf, error_buf_size, "unknown heap type");
        return false;
    }

    *p_buf = p;
    return true;
fail:
    return false;
}

static bool
resolve_value_type(const uint8 **p_buf, const uint8 *buf_end,
                   WASMModule *module, uint32 type_count,
                   bool *p_need_ref_type_map, WASMRefType *ref_type,
                   bool allow_packed_type, char *error_buf,
                   uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint8 type;

    memset(ref_type, 0, sizeof(WASMRefType));

    CHECK_BUF(p, p_end, 1);
    type = read_uint8(p);

    if (wasm_is_reftype_htref_nullable(type)) {
        /* (ref null ht) */
        if (!resolve_reftype_htref(&p, p_end, module, type_count, true,
                                   ref_type, error_buf, error_buf_size))
            return false;
        if (!wasm_is_refheaptype_common(&ref_type->ref_ht_common))
            *p_need_ref_type_map = true;
        else {
            /* For (ref null func/extern/any/eq/i31/data), they are same as
               funcref/externref/anyref/eqref/i31ref/dataref, we convert the
               multi-byte type to one-byte type to reduce the footprint and
               the complexity of type equal/subtype checking */
            ref_type->ref_type =
                (uint8)((int32)0x80 + ref_type->ref_ht_common.heap_type);
            *p_need_ref_type_map = false;
        }
    }
    else if (wasm_is_reftype_htref_non_nullable(type)) {
        /* (ref ht) */
        if (!resolve_reftype_htref(&p, p_end, module, type_count, false,
                                   ref_type, error_buf, error_buf_size))
            return false;
        *p_need_ref_type_map = true;
#if WASM_ENABLE_STRINGREF != 0
        /* covert (ref string) to stringref */
        if (wasm_is_refheaptype_stringrefs(&ref_type->ref_ht_common)) {
            ref_type->ref_type =
                (uint8)((int32)0x80 + ref_type->ref_ht_common.heap_type);
            *p_need_ref_type_map = false;
        }
#endif
    }
    else {
        /* type which can be represented by one byte */
        if (!is_valid_value_type_for_interpreter(type)
            && !(allow_packed_type && is_packed_type(type))) {
            set_error_buf(error_buf, error_buf_size, "type mismatch");
            return false;
        }
        ref_type->ref_type = type;
        *p_need_ref_type_map = false;
#if WASM_ENABLE_WAMR_COMPILER != 0
        /* If any value's type is v128, mark the module as SIMD used */
        if (type == VALUE_TYPE_V128)
            module->is_simd_used = true;
#endif
    }

    *p_buf = p;
    return true;
fail:
    return false;
}

static WASMRefType *
reftype_set_insert(HashMap *ref_type_set, const WASMRefType *ref_type,
                   char *error_buf, uint32 error_buf_size)
{
    WASMRefType *ret = wasm_reftype_set_insert(ref_type_set, ref_type);

    if (!ret) {
        set_error_buf(error_buf, error_buf_size,
                      "insert ref type to hash set failed");
    }
    return ret;
}

static bool
resolve_func_type(const uint8 **p_buf, const uint8 *buf_end, WASMModule *module,
                  uint32 type_count, uint32 type_idx, char *error_buf,
                  uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end, *p_org;
    uint32 param_count, result_count, i, j = 0;
    uint32 param_cell_num, ret_cell_num;
    uint32 ref_type_map_count = 0, result_ref_type_map_count = 0;
    uint64 total_size;
    bool need_ref_type_map;
    WASMRefType ref_type;
    WASMFuncType *type = NULL;

    /* Parse first time to resolve param count, result count and
       ref type map count */
    read_leb_uint32(p, p_end, param_count);
    p_org = p;
    for (i = 0; i < param_count; i++) {
        if (!resolve_value_type(&p, p_end, module, type_count,
                                &need_ref_type_map, &ref_type, false, error_buf,
                                error_buf_size)) {
            return false;
        }
        if (need_ref_type_map)
            ref_type_map_count++;
    }

    read_leb_uint32(p, p_end, result_count);
    for (i = 0; i < result_count; i++) {
        if (!resolve_value_type(&p, p_end, module, type_count,
                                &need_ref_type_map, &ref_type, false, error_buf,
                                error_buf_size)) {
            return false;
        }
        if (need_ref_type_map) {
            ref_type_map_count++;
            result_ref_type_map_count++;
        }
    }

    LOG_VERBOSE("type %u: func, param count: %d, result count: %d, "
                "ref type map count: %d",
                type_idx, param_count, result_count, ref_type_map_count);

    /* Parse second time to resolve param types, result types and
       ref type map info */
    p = p_org;

    total_size = offsetof(WASMFuncType, types)
                 + sizeof(uint8) * (uint64)(param_count + result_count);
    if (!(type = loader_malloc(total_size, error_buf, error_buf_size))) {
        return false;
    }
    if (ref_type_map_count > 0) {
        total_size = sizeof(WASMRefTypeMap) * (uint64)ref_type_map_count;
        if (!(type->ref_type_maps =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            goto fail;
        }
    }

    type->base_type.type_flag = WASM_TYPE_FUNC;
    type->param_count = param_count;
    type->result_count = result_count;
    type->ref_type_map_count = ref_type_map_count;
    if (ref_type_map_count > 0) {
        type->result_ref_type_maps = type->ref_type_maps + ref_type_map_count
                                     - result_ref_type_map_count;
    }

    for (i = 0; i < param_count; i++) {
        if (!resolve_value_type(&p, p_end, module, type_count,
                                &need_ref_type_map, &ref_type, false, error_buf,
                                error_buf_size)) {
            goto fail;
        }
        type->types[i] = ref_type.ref_type;
        if (need_ref_type_map) {
            type->ref_type_maps[j].index = i;
            if (!(type->ref_type_maps[j++].ref_type =
                      reftype_set_insert(module->ref_type_set, &ref_type,
                                         error_buf, error_buf_size))) {
                goto fail;
            }
        }
    }

    read_leb_uint32(p, p_end, result_count);
    for (i = 0; i < result_count; i++) {
        if (!resolve_value_type(&p, p_end, module, type_count,
                                &need_ref_type_map, &ref_type, false, error_buf,
                                error_buf_size)) {
            goto fail;
        }
        type->types[param_count + i] = ref_type.ref_type;
        if (need_ref_type_map) {
            type->ref_type_maps[j].index = param_count + i;
            if (!(type->ref_type_maps[j++].ref_type =
                      reftype_set_insert(module->ref_type_set, &ref_type,
                                         error_buf, error_buf_size))) {
                goto fail;
            }
        }
    }

    bh_assert(j == type->ref_type_map_count);
#if TRACE_WASM_LOADER != 0
    os_printf("type %d = ", type_idx);
    wasm_dump_func_type(type);
#endif

    param_cell_num = wasm_get_cell_num(type->types, param_count);
    ret_cell_num = wasm_get_cell_num(type->types + param_count, result_count);
    if (param_cell_num > UINT16_MAX || ret_cell_num > UINT16_MAX) {
        set_error_buf(error_buf, error_buf_size,
                      "param count or result count too large");
        goto fail;
    }
    type->param_cell_num = (uint16)param_cell_num;
    type->ret_cell_num = (uint16)ret_cell_num;

#if WASM_ENABLE_QUICK_AOT_ENTRY != 0
    type->quick_aot_entry = wasm_native_lookup_quick_aot_entry(type);
#endif

#if WASM_ENABLE_WAMR_COMPILER != 0
    for (i = 0; i < (uint32)(type->param_count + type->result_count); i++) {
        if (type->types[i] == VALUE_TYPE_V128)
            module->is_simd_used = true;
    }
#endif

    *p_buf = p;

    module->types[type_idx] = (WASMType *)type;
    return true;

fail:
    if (type)
        destroy_func_type(type);
    return false;
}

static bool
resolve_struct_type(const uint8 **p_buf, const uint8 *buf_end,
                    WASMModule *module, uint32 type_count, uint32 type_idx,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end, *p_org;
    uint32 field_count, ref_type_map_count = 0, ref_field_count = 0;
    uint32 i, j = 0, offset;
    uint16 *reference_table;
    uint64 total_size;
    uint8 mutable;
    bool need_ref_type_map;
    WASMRefType ref_type;
    WASMStructType *type = NULL;

    /* Parse first time to resolve field count and ref type map count */
    read_leb_uint32(p, p_end, field_count);
    p_org = p;
    for (i = 0; i < field_count; i++) {
        if (!resolve_value_type(&p, p_end, module, type_count,
                                &need_ref_type_map, &ref_type, true, error_buf,
                                error_buf_size)) {
            return false;
        }
        if (need_ref_type_map)
            ref_type_map_count++;

        if (wasm_is_type_reftype(ref_type.ref_type))
            ref_field_count++;

        CHECK_BUF(p, p_end, 1);
        mutable = read_uint8(p);
        if (!check_mutability(mutable, error_buf, error_buf_size)) {
            return false;
        }
    }

    LOG_VERBOSE("type %u: struct, field count: %d, ref type map count: %d",
                type_idx, field_count, ref_type_map_count);

    /* Parse second time to resolve field types and ref type map info */
    p = p_org;

    total_size = offsetof(WASMStructType, fields)
                 + sizeof(WASMStructFieldType) * (uint64)field_count
                 + sizeof(uint16) * (uint64)(ref_field_count + 1);
    if (!(type = loader_malloc(total_size, error_buf, error_buf_size))) {
        return false;
    }
    if (ref_type_map_count > 0) {
        total_size = sizeof(WASMRefTypeMap) * (uint64)ref_type_map_count;
        if (!(type->ref_type_maps =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            goto fail;
        }
    }

    type->reference_table = reference_table =
        (uint16 *)((uint8 *)type + offsetof(WASMStructType, fields)
                   + sizeof(WASMStructFieldType) * field_count);
    *reference_table++ = ref_field_count;

    type->base_type.type_flag = WASM_TYPE_STRUCT;
    type->field_count = field_count;
    type->ref_type_map_count = ref_type_map_count;

    offset = (uint32)offsetof(WASMStructObject, field_data);
    for (i = 0; i < field_count; i++) {
        if (!resolve_value_type(&p, p_end, module, type_count,
                                &need_ref_type_map, &ref_type, true, error_buf,
                                error_buf_size)) {
            goto fail;
        }
        type->fields[i].field_type = ref_type.ref_type;
        if (need_ref_type_map) {
            type->ref_type_maps[j].index = i;
            if (!(type->ref_type_maps[j++].ref_type =
                      reftype_set_insert(module->ref_type_set, &ref_type,
                                         error_buf, error_buf_size))) {
                goto fail;
            }
        }

        CHECK_BUF(p, p_end, 1);
        type->fields[i].field_flags = read_uint8(p);
        type->fields[i].field_size =
            (uint8)wasm_reftype_size(ref_type.ref_type);
#if !(defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64) \
      || defined(BUILD_TARGET_X86_32))
        if (type->fields[i].field_size == 2)
            offset = align_uint(offset, 2);
        else if (type->fields[i].field_size >= 4) /* field size is 4 or 8 */
            offset = align_uint(offset, 4);
#endif
        type->fields[i].field_offset = offset;
        if (wasm_is_type_reftype(ref_type.ref_type))
            *reference_table++ = offset;
        offset += type->fields[i].field_size;

        LOG_VERBOSE("                field: %d, flags: %d, type: %d", i,
                    type->fields[i].field_flags, type->fields[i].field_type);
    }
    type->total_size = offset;

    bh_assert(j == type->ref_type_map_count);
#if TRACE_WASM_LOADER != 0
    os_printf("type %d = ", type_idx);
    wasm_dump_struct_type(type);
#endif

    *p_buf = p;

    module->types[type_idx] = (WASMType *)type;
    return true;

fail:
    if (type)
        destroy_struct_type(type);
    return false;
}

static bool
resolve_array_type(const uint8 **p_buf, const uint8 *buf_end,
                   WASMModule *module, uint32 type_count, uint32 type_idx,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint8 mutable;
    bool need_ref_type_map;
    WASMRefType ref_type;
    WASMArrayType *type = NULL;

    if (!resolve_value_type(&p, p_end, module, type_count, &need_ref_type_map,
                            &ref_type, true, error_buf, error_buf_size)) {
        return false;
    }

    CHECK_BUF(p, p_end, 1);
    mutable = read_uint8(p);
    if (!check_mutability(mutable, error_buf, error_buf_size)) {
        return false;
    }

    LOG_VERBOSE("type %u: array", type_idx);

    if (!(type = loader_malloc(sizeof(WASMArrayType), error_buf,
                               error_buf_size))) {
        return false;
    }

    type->base_type.type_flag = WASM_TYPE_ARRAY;
    type->elem_flags = mutable;
    type->elem_type = ref_type.ref_type;
    if (need_ref_type_map) {
        if (!(type->elem_ref_type =
                  reftype_set_insert(module->ref_type_set, &ref_type, error_buf,
                                     error_buf_size))) {
            goto fail;
        }
    }

#if TRACE_WASM_LOADER != 0
    os_printf("type %d = ", type_idx);
    wasm_dump_array_type(type);
#endif

    *p_buf = p;

    module->types[type_idx] = (WASMType *)type;
    return true;

fail:
    if (type)
        destroy_array_type(type);
    return false;
}

static bool
init_ref_type(WASMModule *module, WASMRefType *ref_type, bool nullable,
              int32 heap_type, char *error_buf, uint32 error_buf_size)
{
    if (heap_type >= 0) {
        if (!check_type_index(module, module->type_count, heap_type, error_buf,
                              error_buf_size)) {
            return false;
        }
        wasm_set_refheaptype_typeidx(&ref_type->ref_ht_typeidx, nullable,
                                     heap_type);
    }
    else {
        if (!wasm_is_valid_heap_type(heap_type)) {
            set_error_buf(error_buf, error_buf_size, "unknown type");
            return false;
        }
        wasm_set_refheaptype_common(&ref_type->ref_ht_common, nullable,
                                    heap_type);
        if (nullable) {
            /* For (ref null func/extern/any/eq/i31/data),
               they are same as
                funcref/externref/anyref/eqref/i31ref/dataref,
               we convert the multi-byte type to one-byte
               type to reduce the footprint and the
               complexity of type equal/subtype checking */
            ref_type->ref_type =
                (uint8)((int32)0x80 + ref_type->ref_ht_common.heap_type);
        }
    }
    return true;
}

static void
calculate_reftype_diff(WASMRefType *ref_type_diff, WASMRefType *ref_type1,
                       WASMRefType *ref_type2)
{
    /**
     * The difference rt1 ∖ rt2 between two reference types is defined as
     * follows:
     *  (ref null?1 ht1) ∖ (ref null ht2) = (ref ht1) (ref null?1 ht1) ∖
     *  (ref ht2) = (ref null?1 ht1)
     */
    if (wasm_is_type_multi_byte_type(ref_type1->ref_type)) {
        bh_memcpy_s(ref_type_diff, wasm_reftype_struct_size(ref_type1),
                    ref_type1, wasm_reftype_struct_size(ref_type1));
    }
    else {
        ref_type_diff->ref_type = ref_type1->ref_type;
    }

    if (ref_type2->ref_ht_common.nullable) {
        if (wasm_is_type_reftype(ref_type_diff->ref_type)
            && !(wasm_is_type_multi_byte_type(ref_type_diff->ref_type))) {
            wasm_set_refheaptype_typeidx(&ref_type_diff->ref_ht_typeidx, false,
                                         (int32)ref_type_diff->ref_type - 0x80);
        }
        else {
            ref_type_diff->ref_ht_typeidx.nullable = false;
        }
    }
}
#else /* else of WASM_ENABLE_GC != 0 */
static void
destroy_wasm_type(WASMType *type)
{
    if (type->ref_count > 1) {
        /* The type is referenced by other types
           of current wasm module */
        type->ref_count--;
        return;
    }

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    if (type->call_to_llvm_jit_from_fast_jit)
        jit_code_cache_free(type->call_to_llvm_jit_from_fast_jit);
#endif

    wasm_runtime_free(type);
}
#endif /* end of WASM_ENABLE_GC != 0 */

static bool
load_type_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                  char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 type_count, i;
    uint64 total_size;
    uint8 flag;
#if WASM_ENABLE_GC != 0
    uint32 processed_type_count = 0;
#endif

    read_leb_uint32(p, p_end, type_count);

    if (type_count) {
        module->type_count = type_count;
        total_size = sizeof(WASMType *) * (uint64)type_count;
        if (!(module->types =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

#if WASM_ENABLE_GC == 0
        for (i = 0; i < type_count; i++) {
            WASMFuncType *type;
            const uint8 *p_org;
            uint32 param_count, result_count, j;
            uint32 param_cell_num, ret_cell_num;

            CHECK_BUF(p, p_end, 1);
            flag = read_uint8(p);
            if (flag != 0x60) {
                set_error_buf(error_buf, error_buf_size, "invalid type flag");
                return false;
            }

            read_leb_uint32(p, p_end, param_count);

            /* Resolve param count and result count firstly */
            p_org = p;
            CHECK_BUF(p, p_end, param_count);
            p += param_count;
            read_leb_uint32(p, p_end, result_count);
            CHECK_BUF(p, p_end, result_count);
            p = p_org;

            if (param_count > UINT16_MAX || result_count > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "param count or result count too large");
                return false;
            }

            total_size = offsetof(WASMFuncType, types)
                         + sizeof(uint8) * (uint64)(param_count + result_count);
            if (!(type = module->types[i] =
                      loader_malloc(total_size, error_buf, error_buf_size))) {
                return false;
            }

            /* Resolve param types and result types */
            type->ref_count = 1;
            type->param_count = (uint16)param_count;
            type->result_count = (uint16)result_count;
            for (j = 0; j < param_count; j++) {
                CHECK_BUF(p, p_end, 1);
                type->types[j] = read_uint8(p);
            }
            read_leb_uint32(p, p_end, result_count);
            for (j = 0; j < result_count; j++) {
                CHECK_BUF(p, p_end, 1);
                type->types[param_count + j] = read_uint8(p);
            }
            for (j = 0; j < param_count + result_count; j++) {
                if (!is_valid_value_type_for_interpreter(type->types[j])) {
                    set_error_buf(error_buf, error_buf_size,
                                  "unknown value type");
                    return false;
                }
            }

            param_cell_num = wasm_get_cell_num(type->types, param_count);
            ret_cell_num =
                wasm_get_cell_num(type->types + param_count, result_count);
            if (param_cell_num > UINT16_MAX || ret_cell_num > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "param count or result count too large");
                return false;
            }
            type->param_cell_num = (uint16)param_cell_num;
            type->ret_cell_num = (uint16)ret_cell_num;

#if WASM_ENABLE_QUICK_AOT_ENTRY != 0
            type->quick_aot_entry = wasm_native_lookup_quick_aot_entry(type);
#endif

#if WASM_ENABLE_WAMR_COMPILER != 0
            for (j = 0; j < type->param_count + type->result_count; j++) {
                if (type->types[j] == VALUE_TYPE_V128)
                    module->is_simd_used = true;
                else if (type->types[j] == VALUE_TYPE_FUNCREF
                         || type->types[j] == VALUE_TYPE_EXTERNREF)
                    module->is_ref_types_used = true;
            }
#endif

            /* If there is already a same type created, use it instead */
            for (j = 0; j < i; j++) {
                if (wasm_type_equal(type, module->types[j], module->types, i)) {
                    if (module->types[j]->ref_count == UINT16_MAX) {
                        set_error_buf(error_buf, error_buf_size,
                                      "wasm type's ref count too large");
                        return false;
                    }
                    destroy_wasm_type(type);
                    module->types[i] = module->types[j];
                    module->types[j]->ref_count++;
                    break;
                }
            }
        }
#else  /* else of WASM_ENABLE_GC == 0 */
        for (i = 0; i < type_count; i++) {
            uint32 super_type_count = 0, parent_type_idx = (uint32)-1;
            uint32 rec_count = 1, j;
            bool is_sub_final = true;

            CHECK_BUF(p, p_end, 1);
            flag = read_uint8(p);

            if (flag == DEFINED_TYPE_REC) {
                read_leb_uint32(p, p_end, rec_count);

                if (rec_count > 1) {
                    uint64 new_total_size;

                    /* integer overflow */
                    if (rec_count - 1 > UINT32_MAX - module->type_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "recursive type count too large");
                        return false;
                    }
                    new_total_size =
                        sizeof(WASMFuncType *)
                        * (uint64)(module->type_count + rec_count - 1);
                    if (new_total_size > UINT32_MAX) {
                        set_error_buf(error_buf, error_buf_size,
                                      "allocate memory failed");
                        return false;
                    }
                    MEM_REALLOC(module->types, (uint32)total_size,
                                (uint32)new_total_size);
                    module->type_count += rec_count - 1;
                    total_size = new_total_size;
                }

                if (rec_count < 1) {
                    LOG_VERBOSE("Processing 0-entry rec group");
                }
                else {
                    LOG_VERBOSE("Processing rec group [%d-%d]",
                                processed_type_count,
                                processed_type_count + rec_count - 1);
                }
            }
            else {
                p--;
            }

            for (j = 0; j < rec_count; j++) {
                WASMType *cur_type = NULL;

                CHECK_BUF(p, p_end, 1);
                flag = read_uint8(p);

                parent_type_idx = -1;

                if (flag == DEFINED_TYPE_SUB
                    || flag == DEFINED_TYPE_SUB_FINAL) {
                    read_leb_uint32(p, p_end, super_type_count);
                    if (super_type_count > 1) {
                        set_error_buf(error_buf, error_buf_size,
                                      "super type count too large");
                        return false;
                    }

                    if (super_type_count > 0) {
                        read_leb_uint32(p, p_end, parent_type_idx);
                        if (parent_type_idx >= processed_type_count + j) {
                            set_error_buf_v(error_buf, error_buf_size,
                                            "unknown type %d", parent_type_idx);
                            return false;
                        }
                        if (module->types[parent_type_idx]->is_sub_final) {
                            set_error_buf(error_buf, error_buf_size,
                                          "sub type can not inherit from "
                                          "a final super type");
                            return false;
                        }
                    }

                    if (flag == DEFINED_TYPE_SUB)
                        is_sub_final = false;

                    CHECK_BUF(p, p_end, 1);
                    flag = read_uint8(p);
                }

                if (flag == DEFINED_TYPE_FUNC) {
                    if (!resolve_func_type(&p, buf_end, module,
                                           processed_type_count + rec_count,
                                           processed_type_count + j, error_buf,
                                           error_buf_size)) {
                        return false;
                    }
                }
                else if (flag == DEFINED_TYPE_STRUCT) {
                    if (!resolve_struct_type(&p, buf_end, module,
                                             processed_type_count + rec_count,
                                             processed_type_count + j,
                                             error_buf, error_buf_size)) {
                        return false;
                    }
                }
                else if (flag == DEFINED_TYPE_ARRAY) {
                    if (!resolve_array_type(&p, buf_end, module,
                                            processed_type_count + rec_count,
                                            processed_type_count + j, error_buf,
                                            error_buf_size)) {
                        return false;
                    }
                }
                else {
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid type flag");
                    return false;
                }

                cur_type = module->types[processed_type_count + j];

                cur_type->ref_count = 1;
                cur_type->parent_type_idx = parent_type_idx;
                cur_type->is_sub_final = is_sub_final;

                cur_type->rec_count = rec_count;
                cur_type->rec_idx = j;
                cur_type->rec_begin_type_idx = processed_type_count;
            }

            /* resolve subtyping relationship in current rec group */
            for (j = 0; j < rec_count; j++) {
                WASMType *cur_type = module->types[processed_type_count + j];

                if (cur_type->parent_type_idx != (uint32)-1) { /* has parent */
                    WASMType *parent_type =
                        module->types[cur_type->parent_type_idx];
                    cur_type->parent_type = parent_type;
                    cur_type->root_type = parent_type->root_type;
                    if (parent_type->inherit_depth == UINT16_MAX) {
                        set_error_buf(error_buf, error_buf_size,
                                      "parent type's inherit depth too large");
                        return false;
                    }
                    cur_type->inherit_depth = parent_type->inherit_depth + 1;
                }
                else {
                    cur_type->parent_type = NULL;
                    cur_type->root_type = cur_type;
                    cur_type->inherit_depth = 0;
                }
            }

            for (j = 0; j < rec_count; j++) {
                WASMType *cur_type = module->types[processed_type_count + j];

                if (cur_type->parent_type_idx != (uint32)-1) { /* has parent */
                    WASMType *parent_type =
                        module->types[cur_type->parent_type_idx];
                    if (!wasm_type_is_subtype_of(cur_type, parent_type,
                                                 module->types,
                                                 module->type_count)) {
                        set_error_buf_v(error_buf, error_buf_size,
                                        "sub type %u does not match super type",
                                        processed_type_count + j);
                        return false;
                    }
                }
            }

            /* If there is already an equivalence type or a group of equivalence
               recursive types created, use it or them instead */
            for (j = 0; j < processed_type_count;) {
                WASMType *src_type = module->types[j];
                WASMType *cur_type = module->types[processed_type_count];
                uint32 k, src_rec_count;

                src_rec_count = src_type->rec_count;
                if (src_rec_count != rec_count) {
                    /* no type equivalence */
                    j += src_rec_count;
                    continue;
                }

                for (k = 0; k < rec_count; k++) {
                    src_type = module->types[j + k];
                    cur_type = module->types[processed_type_count + k];
                    if (!wasm_type_equal(src_type, cur_type, module->types,
                                         module->type_count)) {
                        break;
                    }
                }
                if (k < rec_count) {
                    /* no type equivalence */
                    j += src_rec_count;
                    continue;
                }

                /* type equivalence */
                for (k = 0; k < rec_count; k++) {
                    if (module->types[j + k]->ref_count == UINT16_MAX) {
                        set_error_buf(error_buf, error_buf_size,
                                      "wasm type's ref count too large");
                        return false;
                    }
                    destroy_wasm_type(module->types[processed_type_count + k]);
                    module->types[processed_type_count + k] =
                        module->types[j + k];
                    module->types[j + k]->ref_count++;
                }
                break;
            }

            if (rec_count > 1) {
                LOG_VERBOSE("Finished processing rec group [%d-%d]",
                            processed_type_count,
                            processed_type_count + rec_count - 1);
            }

            processed_type_count += rec_count;
        }

        if (!(module->rtt_types = loader_malloc((uint64)sizeof(WASMRttType *)
                                                    * module->type_count,
                                                error_buf, error_buf_size))) {
            return false;
        }
#endif /* end of WASM_ENABLE_GC == 0 */
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load type section success.\n");
    return true;
fail:
    return false;
}

static void
adjust_table_max_size(bool is_table64, uint32 init_size, uint32 max_size_flag,
                      uint32 *max_size)
{
    uint32 default_max_size;

    /* TODO: current still use UINT32_MAX as upper limit for table size to keep
     * ABI unchanged */
    (void)is_table64;
    if (UINT32_MAX / 2 > init_size)
        default_max_size = init_size * 2;
    else
        default_max_size = UINT32_MAX;

    if (default_max_size < WASM_TABLE_MAX_SIZE)
        default_max_size = WASM_TABLE_MAX_SIZE;

    if (max_size_flag) {
        /* module defines the table limitation */
        bh_assert(init_size <= *max_size);

        if (init_size < *max_size) {
            *max_size =
                *max_size < default_max_size ? *max_size : default_max_size;
        }
    }
    else {
        /* partial defined table limitation, gives a default value */
        *max_size = default_max_size;
    }
}

#if WASM_ENABLE_LIBC_WASI != 0 || WASM_ENABLE_MULTI_MODULE != 0
/**
 * Find export item of a module with export info:
 *  module name, field name and export kind
 */
static WASMExport *
wasm_loader_find_export(const WASMModule *module, const char *module_name,
                        const char *field_name, uint8 export_kind,
                        char *error_buf, uint32 error_buf_size)
{
    WASMExport *export =
        loader_find_export((WASMModuleCommon *)module, module_name, field_name,
                           export_kind, error_buf, error_buf_size);
    return export;
}
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
static WASMTable *
wasm_loader_resolve_table(const char *module_name, const char *table_name,
                          uint32 init_size, uint32 max_size, char *error_buf,
                          uint32 error_buf_size)
{
    WASMModuleCommon *module_reg;
    WASMTable *table = NULL;
    WASMExport *export = NULL;
    WASMModule *module = NULL;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg || module_reg->module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for table", module_name);
        set_error_buf(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    module = (WASMModule *)module_reg;
    export =
        wasm_loader_find_export(module, module_name, table_name,
                                EXPORT_KIND_TABLE, error_buf, error_buf_size);
    if (!export) {
        return NULL;
    }

    /* resolve table and check the init/max size */
    if (export->index < module->import_table_count) {
        table =
            module->import_tables[export->index].u.table.import_table_linked;
    }
    else {
        table = &(module->tables[export->index - module->import_table_count]);
    }
    if (table->table_type.init_size < init_size
        || table->table_type.max_size > max_size) {
        LOG_DEBUG("%s,%s failed type check(%d-%d), expected(%d-%d)",
                  module_name, table_name, table->table_type.init_size,
                  table->table_type.max_size, init_size, max_size);
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }

    return table;
}

static WASMMemory *
wasm_loader_resolve_memory(const char *module_name, const char *memory_name,
                           uint32 init_page_count, uint32 max_page_count,
                           char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon *module_reg;
    WASMMemory *memory = NULL;
    WASMExport *export = NULL;
    WASMModule *module = NULL;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg || module_reg->module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for memory", module_name);
        set_error_buf(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    module = (WASMModule *)module_reg;
    export =
        wasm_loader_find_export(module, module_name, memory_name,
                                EXPORT_KIND_MEMORY, error_buf, error_buf_size);
    if (!export) {
        return NULL;
    }

    /* resolve memory and check the init/max page count */
    if (export->index < module->import_memory_count) {
        memory = module->import_memories[export->index]
                     .u.memory.import_memory_linked;
    }
    else {
        memory =
            &(module->memories[export->index - module->import_memory_count]);
    }
    if (memory->init_page_count < init_page_count
        || memory->max_page_count > max_page_count) {
        LOG_DEBUG("%s,%s failed type check(%d-%d), expected(%d-%d)",
                  module_name, memory_name, memory->init_page_count,
                  memory->max_page_count, init_page_count, max_page_count);
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }
    return memory;
}

static WASMGlobal *
wasm_loader_resolve_global(const char *module_name, const char *global_name,
                           uint8 type, bool is_mutable, char *error_buf,
                           uint32 error_buf_size)
{
    WASMModuleCommon *module_reg;
    WASMGlobal *global = NULL;
    WASMExport *export = NULL;
    WASMModule *module = NULL;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg || module_reg->module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for global", module_name);
        set_error_buf(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    module = (WASMModule *)module_reg;
    export =
        wasm_loader_find_export(module, module_name, global_name,
                                EXPORT_KIND_GLOBAL, error_buf, error_buf_size);
    if (!export) {
        return NULL;
    }

    /* resolve and check the global */
    if (export->index < module->import_global_count) {
        global =
            module->import_globals[export->index].u.global.import_global_linked;
    }
    else {
        global =
            &(module->globals[export->index - module->import_global_count]);
    }
    if (global->type.val_type != type
        || global->type.is_mutable != is_mutable) {
        LOG_DEBUG("%s,%s failed type check(%d, %d), expected(%d, %d)",
                  module_name, global_name, global->type.val_type,
                  global->type.is_mutable, type, is_mutable);
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }
    return global;
}

#if WASM_ENABLE_TAGS != 0
static WASMTag *
wasm_loader_resolve_tag(const char *module_name, const char *tag_name,
                        const WASMType *expected_tag_type,
                        uint32 *linked_tag_index, char *error_buf,
                        uint32 error_buf_size)
{
    WASMModuleCommon *module_reg;
    WASMTag *tag = NULL;
    WASMExport *export = NULL;
    WASMModule *module = NULL;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg || module_reg->module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for tag %s", module_name,
                  tag_name);
        set_error_buf(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    module = (WASMModule *)module_reg;
    export =
        wasm_loader_find_export(module, module_name, tag_name, EXPORT_KIND_TAG,
                                error_buf, error_buf_size);
    if (!export) {
        return NULL;
    }

    /* resolve tag type and tag */
    if (export->index < module->import_tag_count) {
        /* importing an imported tag from the submodule */
        tag = module->import_tags[export->index].u.tag.import_tag_linked;
    }
    else {
        /* importing an section tag from the submodule */
        tag = module->tags[export->index - module->import_tag_count];
    }

    /* check function type */
    if (!wasm_type_equal(expected_tag_type, tag->tag_type, module->types,
                         module->type_count)) {
        LOG_DEBUG("%s.%s failed the type check", module_name, tag_name);
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }

    if (linked_tag_index != NULL) {
        *linked_tag_index = export->index;
    }

    return tag;
}
#endif /* end of WASM_ENABLE_TAGS != 0 */
#endif /* end of WASM_ENABLE_MULTI_MODULE */

static bool
load_function_import(const uint8 **p_buf, const uint8 *buf_end,
                     const WASMModule *parent_module,
                     const char *sub_module_name, const char *function_name,
                     WASMFunctionImport *function, bool no_resolve,
                     char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint32 declare_type_index = 0;

    read_leb_uint32(p, p_end, declare_type_index);
    *p_buf = p;

    if (!check_function_type(parent_module, declare_type_index, error_buf,
                             error_buf_size)) {
        return false;
    }

#if WASM_ENABLE_GC != 0
    function->type_idx = declare_type_index;
#endif

#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0)
    declare_type_index = wasm_get_smallest_type_idx(
        parent_module->types, parent_module->type_count, declare_type_index);
#endif

    function->func_type =
        (WASMFuncType *)parent_module->types[declare_type_index];

    function->module_name = (char *)sub_module_name;
    function->field_name = (char *)function_name;
    function->attachment = NULL;
    function->signature = NULL;
    function->call_conv_raw = false;

    /* lookup registered native symbols first */
    if (!no_resolve) {
        wasm_resolve_import_func(parent_module, function);
    }
    return true;
fail:
    return false;
}

static bool
check_table_max_size(uint32 init_size, uint32 max_size, char *error_buf,
                     uint32 error_buf_size)
{
    if (max_size < init_size) {
        set_error_buf(error_buf, error_buf_size,
                      "size minimum must not be greater than maximum");
        return false;
    }
    return true;
}

static bool
load_table_import(const uint8 **p_buf, const uint8 *buf_end,
                  WASMModule *parent_module, const char *sub_module_name,
                  const char *table_name, WASMTableImport *table,
                  char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end, *p_org;
    uint32 declare_elem_type = 0, table_flag = 0, declare_init_size = 0,
           declare_max_size = 0;
#if WASM_ENABLE_MULTI_MODULE != 0
    WASMModule *sub_module = NULL;
    WASMTable *linked_table = NULL;
#endif
#if WASM_ENABLE_GC != 0
    WASMRefType ref_type;
    bool need_ref_type_map;
#endif
    bool is_table64 = false;

#if WASM_ENABLE_GC == 0
    CHECK_BUF(p, p_end, 1);
    /* 0x70 or 0x6F */
    declare_elem_type = read_uint8(p);
    if (VALUE_TYPE_FUNCREF != declare_elem_type
#if WASM_ENABLE_REF_TYPES != 0
        && VALUE_TYPE_EXTERNREF != declare_elem_type
#endif
    ) {
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return false;
    }
#else /* else of WASM_ENABLE_GC == 0 */
    if (!resolve_value_type(&p, p_end, parent_module, parent_module->type_count,
                            &need_ref_type_map, &ref_type, false, error_buf,
                            error_buf_size)) {
        return false;
    }
    if (!wasm_is_type_reftype(ref_type.ref_type)
        || wasm_is_reftype_htref_non_nullable(ref_type.ref_type)) {
        set_error_buf(error_buf, error_buf_size, "type mismatch");
        return false;
    }
    declare_elem_type = ref_type.ref_type;
    if (need_ref_type_map) {
        if (!(table->table_type.elem_ref_type =
                  reftype_set_insert(parent_module->ref_type_set, &ref_type,
                                     error_buf, error_buf_size))) {
            return false;
        }
    }
#if TRACE_WASM_LOADER != 0
    os_printf("import table type: ");
    wasm_dump_value_type(declare_elem_type, table->table_type.elem_ref_type);
    os_printf("\n");
#endif
#endif /* end of WASM_ENABLE_GC == 0 */

    p_org = p;
    read_leb_uint32(p, p_end, table_flag);
    is_table64 = table_flag & TABLE64_FLAG;
    if (p - p_org > 1) {
        LOG_VERBOSE("integer representation too long(import table)");
        set_error_buf(error_buf, error_buf_size, "invalid limits flags");
        return false;
    }

    if (!wasm_table_check_flags(table_flag, error_buf, error_buf_size, false)) {
        return false;
    }

    read_leb_uint32(p, p_end, declare_init_size);
    if (table_flag & MAX_TABLE_SIZE_FLAG) {
        read_leb_uint32(p, p_end, declare_max_size);
        if (!check_table_max_size(declare_init_size, declare_max_size,
                                  error_buf, error_buf_size))
            return false;
    }

    adjust_table_max_size(is_table64, declare_init_size,
                          table_flag & MAX_TABLE_SIZE_FLAG, &declare_max_size);

    *p_buf = p;

#if WASM_ENABLE_MULTI_MODULE != 0
    if (!wasm_runtime_is_built_in_module(sub_module_name)) {
        sub_module = (WASMModule *)wasm_runtime_load_depended_module(
            (WASMModuleCommon *)parent_module, sub_module_name, error_buf,
            error_buf_size);
        if (sub_module) {
            linked_table = wasm_loader_resolve_table(
                sub_module_name, table_name, declare_init_size,
                declare_max_size, error_buf, error_buf_size);
            if (linked_table) {
                /* reset with linked table limit */
                declare_elem_type = linked_table->table_type.elem_type;
                declare_init_size = linked_table->table_type.init_size;
                declare_max_size = linked_table->table_type.max_size;
                table_flag = linked_table->table_type.flags;
                table->import_table_linked = linked_table;
                table->import_module = sub_module;
            }
        }
    }
#endif /* WASM_ENABLE_MULTI_MODULE != 0 */

    /* (table (export "table") 10 20 funcref) */
    /* (table (export "table64") 10 20 funcref) */
    /* we need this section working in wamrc */
    if (!strcmp("spectest", sub_module_name)) {
        const uint32 spectest_table_init_size = 10;
        const uint32 spectest_table_max_size = 20;

        if (strcmp("table", table_name)
#if WASM_ENABLE_MEMORY64 != 0
            && strcmp("table64", table_name)
#endif
        ) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type or unknown import");
            return false;
        }

        if (declare_init_size > spectest_table_init_size
            || declare_max_size < spectest_table_max_size) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }

        declare_init_size = spectest_table_init_size;
        declare_max_size = spectest_table_max_size;
    }

    /* now we believe all declaration are ok */
    table->table_type.elem_type = declare_elem_type;
    table->table_type.init_size = declare_init_size;
    table->table_type.flags = table_flag;
    table->table_type.max_size = declare_max_size;

#if WASM_ENABLE_WAMR_COMPILER != 0
    if (table->table_type.elem_type == VALUE_TYPE_EXTERNREF)
        parent_module->is_ref_types_used = true;
#endif
    (void)parent_module;
    return true;
fail:
    return false;
}

static bool
check_memory_init_size(bool is_memory64, uint32 init_size, char *error_buf,
                       uint32 error_buf_size)
{
    uint32 default_max_size =
        is_memory64 ? DEFAULT_MEM64_MAX_PAGES : DEFAULT_MAX_PAGES;

    if (!is_memory64 && init_size > default_max_size) {
        set_error_buf(error_buf, error_buf_size,
                      "memory size must be at most 65536 pages (4GiB)");
        return false;
    }
#if WASM_ENABLE_MEMORY64 != 0
    else if (is_memory64 && init_size > default_max_size) {
        set_error_buf(
            error_buf, error_buf_size,
            "memory size must be at most 4,294,967,295 pages (274 Terabyte)");
        return false;
    }
#endif
    return true;
}

static bool
check_memory_max_size(bool is_memory64, uint32 init_size, uint32 max_size,
                      char *error_buf, uint32 error_buf_size)
{
    uint32 default_max_size =
        is_memory64 ? DEFAULT_MEM64_MAX_PAGES : DEFAULT_MAX_PAGES;

    if (max_size < init_size) {
        set_error_buf(error_buf, error_buf_size,
                      "size minimum must not be greater than maximum");
        return false;
    }

    if (!is_memory64 && max_size > default_max_size) {
        set_error_buf(error_buf, error_buf_size,
                      "memory size must be at most 65536 pages (4GiB)");
        return false;
    }
#if WASM_ENABLE_MEMORY64 != 0
    else if (is_memory64 && max_size > default_max_size) {
        set_error_buf(
            error_buf, error_buf_size,
            "memory size must be at most 4,294,967,295 pages (274 Terabyte)");
        return false;
    }
#endif

    return true;
}

static bool
load_memory_import(const uint8 **p_buf, const uint8 *buf_end,
                   WASMModule *parent_module, const char *sub_module_name,
                   const char *memory_name, WASMMemoryImport *memory,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end, *p_org;
#if WASM_ENABLE_APP_FRAMEWORK != 0
    uint32 pool_size = wasm_runtime_memory_pool_size();
    uint32 max_page_count = pool_size * APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT
                            / DEFAULT_NUM_BYTES_PER_PAGE;
#else
    uint32 max_page_count;
#endif /* WASM_ENABLE_APP_FRAMEWORK */
    uint32 mem_flag = 0;
    bool is_memory64 = false;
    uint32 declare_init_page_count = 0;
    uint32 declare_max_page_count = 0;
#if WASM_ENABLE_MULTI_MODULE != 0
    WASMModule *sub_module = NULL;
    WASMMemory *linked_memory = NULL;
#endif

    p_org = p;
    read_leb_uint32(p, p_end, mem_flag);
    is_memory64 = mem_flag & MEMORY64_FLAG;
    if (p - p_org > 1) {
        LOG_VERBOSE("integer representation too long(import memory)");
        set_error_buf(error_buf, error_buf_size, "invalid limits flags");
        return false;
    }

    if (!wasm_memory_check_flags(mem_flag, error_buf, error_buf_size, false)) {
        return false;
    }

    read_leb_uint32(p, p_end, declare_init_page_count);
    if (!check_memory_init_size(is_memory64, declare_init_page_count, error_buf,
                                error_buf_size)) {
        return false;
    }

#if WASM_ENABLE_APP_FRAMEWORK == 0
    max_page_count = is_memory64 ? DEFAULT_MEM64_MAX_PAGES : DEFAULT_MAX_PAGES;
#endif
    if (mem_flag & MAX_PAGE_COUNT_FLAG) {
        read_leb_uint32(p, p_end, declare_max_page_count);
        if (!check_memory_max_size(is_memory64, declare_init_page_count,
                                   declare_max_page_count, error_buf,
                                   error_buf_size)) {
            return false;
        }
        if (declare_max_page_count > max_page_count) {
            declare_max_page_count = max_page_count;
        }
    }
    else {
        /* Limit the maximum memory size to max_page_count */
        declare_max_page_count = max_page_count;
    }

#if WASM_ENABLE_MULTI_MODULE != 0
    if (!wasm_runtime_is_built_in_module(sub_module_name)) {
        sub_module = (WASMModule *)wasm_runtime_load_depended_module(
            (WASMModuleCommon *)parent_module, sub_module_name, error_buf,
            error_buf_size);
        if (sub_module) {
            linked_memory = wasm_loader_resolve_memory(
                sub_module_name, memory_name, declare_init_page_count,
                declare_max_page_count, error_buf, error_buf_size);
            if (linked_memory) {
                /**
                 * reset with linked memory limit
                 */
                memory->import_module = sub_module;
                memory->import_memory_linked = linked_memory;
                declare_init_page_count = linked_memory->init_page_count;
                declare_max_page_count = linked_memory->max_page_count;
            }
        }
    }
#endif

    /* (memory (export "memory") 1 2) */
    if (!strcmp("spectest", sub_module_name)) {
        uint32 spectest_memory_init_page = 1;
        uint32 spectest_memory_max_page = 2;

        if (strcmp("memory", memory_name)) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type or unknown import");
            return false;
        }

        if (declare_init_page_count > spectest_memory_init_page
            || declare_max_page_count < spectest_memory_max_page) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }

        declare_init_page_count = spectest_memory_init_page;
        declare_max_page_count = spectest_memory_max_page;
    }
#if WASM_ENABLE_WASI_TEST != 0
    /* a case in wasi-testsuite which imports ("foo" "bar") */
    else if (!strcmp("foo", sub_module_name)) {
        uint32 spectest_memory_init_page = 1;
        uint32 spectest_memory_max_page = 1;

        if (strcmp("bar", memory_name)) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type or unknown import");
            return false;
        }

        if (declare_init_page_count > spectest_memory_init_page
            || declare_max_page_count < spectest_memory_max_page) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }

        declare_init_page_count = spectest_memory_init_page;
        declare_max_page_count = spectest_memory_max_page;
    }
#endif

    /* now we believe all declaration are ok */
    memory->mem_type.flags = mem_flag;
    memory->mem_type.init_page_count = declare_init_page_count;
    memory->mem_type.max_page_count = declare_max_page_count;
    memory->mem_type.num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;

    *p_buf = p;

    (void)parent_module;
    return true;
fail:
    return false;
}

#if WASM_ENABLE_TAGS != 0
static bool
load_tag_import(const uint8 **p_buf, const uint8 *buf_end,
                const WASMModule *parent_module, /* this module ! */
                const char *sub_module_name, const char *tag_name,
                WASMTagImport *tag, /* structure to fill */
                char *error_buf, uint32 error_buf_size)
{
    /* attribute and type of the import statement */
    uint8 declare_tag_attribute;
    uint32 declare_type_index;
    const uint8 *p = *p_buf, *p_end = buf_end;
#if WASM_ENABLE_MULTI_MODULE != 0
    WASMModule *sub_module = NULL;
#endif

    /* get the one byte attribute */
    CHECK_BUF(p, p_end, 1);
    declare_tag_attribute = read_uint8(p);
    if (declare_tag_attribute != 0) {
        set_error_buf(error_buf, error_buf_size, "unknown tag attribute");
        goto fail;
    }

    /* get type */
    read_leb_uint32(p, p_end, declare_type_index);
    /* compare against module->types */
    if (!check_function_type(parent_module, declare_type_index, error_buf,
                             error_buf_size)) {
        goto fail;
    }

    WASMFuncType *declare_tag_type =
        (WASMFuncType *)parent_module->types[declare_type_index];

    /* check, that the type of the declared tag returns void */
    if (declare_tag_type->result_count != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "tag type signature does not return void");

        goto fail;
    }

#if WASM_ENABLE_MULTI_MODULE != 0
    if (!wasm_runtime_is_built_in_module(sub_module_name)) {
        sub_module = (WASMModule *)wasm_runtime_load_depended_module(
            (WASMModuleCommon *)parent_module, sub_module_name, error_buf,
            error_buf_size);
        if (sub_module) {
            /* wasm_loader_resolve_tag checks, that the imported tag
             * and the declared tag have the same type
             */
            uint32 linked_tag_index = 0;
            WASMTag *linked_tag = wasm_loader_resolve_tag(
                sub_module_name, tag_name, declare_tag_type,
                &linked_tag_index /* out */, error_buf, error_buf_size);
            if (linked_tag) {
                tag->import_module = sub_module;
                tag->import_tag_linked = linked_tag;
                tag->import_tag_index_linked = linked_tag_index;
            }
        }
    }
#endif
    /* store to module tag declarations */
    tag->attribute = declare_tag_attribute;
    tag->type = declare_type_index;

    tag->module_name = (char *)sub_module_name;
    tag->field_name = (char *)tag_name;
    tag->tag_type = declare_tag_type;

    *p_buf = p;
    (void)parent_module;

    LOG_VERBOSE("Load tag import success\n");

    return true;
fail:
    return false;
}
#endif /* end of WASM_ENABLE_TAGS != 0 */

static bool
load_global_import(const uint8 **p_buf, const uint8 *buf_end,
                   WASMModule *parent_module, char *sub_module_name,
                   char *global_name, WASMGlobalImport *global, char *error_buf,
                   uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint8 declare_type = 0;
    uint8 declare_mutable = 0;
#if WASM_ENABLE_MULTI_MODULE != 0
    WASMModule *sub_module = NULL;
    WASMGlobal *linked_global = NULL;
#endif
#if WASM_ENABLE_GC != 0
    WASMRefType ref_type;
    bool need_ref_type_map;
#endif
    bool ret = false;

#if WASM_ENABLE_GC == 0
    CHECK_BUF(p, p_end, 2);
    /* global type */
    declare_type = read_uint8(p);
    if (!is_valid_value_type_for_interpreter(declare_type)) {
        set_error_buf(error_buf, error_buf_size, "type mismatch");
        return false;
    }
    declare_mutable = read_uint8(p);
#else
    if (!resolve_value_type(&p, p_end, parent_module, parent_module->type_count,
                            &need_ref_type_map, &ref_type, false, error_buf,
                            error_buf_size)) {
        return false;
    }
    declare_type = ref_type.ref_type;
    if (need_ref_type_map) {
        if (!(global->ref_type =
                  reftype_set_insert(parent_module->ref_type_set, &ref_type,
                                     error_buf, error_buf_size))) {
            return false;
        }
    }
#if TRACE_WASM_LOADER != 0
    os_printf("import global type: ");
    wasm_dump_value_type(declare_type, global->ref_type);
    os_printf("\n");
#endif
    CHECK_BUF(p, p_end, 1);
    declare_mutable = read_uint8(p);
#endif /* end of WASM_ENABLE_GC == 0 */

    *p_buf = p;

    if (!check_mutability(declare_mutable, error_buf, error_buf_size)) {
        return false;
    }

#if WASM_ENABLE_LIBC_BUILTIN != 0
    ret = wasm_native_lookup_libc_builtin_global(sub_module_name, global_name,
                                                 global);
    if (ret) {
        if (global->type.val_type != declare_type
            || global->type.is_mutable != declare_mutable) {
            set_error_buf(error_buf, error_buf_size,
                          "incompatible import type");
            return false;
        }
        global->is_linked = true;
    }
#endif
#if WASM_ENABLE_MULTI_MODULE != 0
    if (!global->is_linked
        && !wasm_runtime_is_built_in_module(sub_module_name)) {
        sub_module = (WASMModule *)wasm_runtime_load_depended_module(
            (WASMModuleCommon *)parent_module, sub_module_name, error_buf,
            error_buf_size);
        if (sub_module) {
            /* check sub modules */
            linked_global = wasm_loader_resolve_global(
                sub_module_name, global_name, declare_type, declare_mutable,
                error_buf, error_buf_size);
            if (linked_global) {
                global->import_module = sub_module;
                global->import_global_linked = linked_global;
                global->is_linked = true;
            }
        }
    }
#endif

    global->module_name = sub_module_name;
    global->field_name = global_name;
    global->type.val_type = declare_type;
    global->type.is_mutable = (declare_mutable == 1);

#if WASM_ENABLE_WAMR_COMPILER != 0
    if (global->type.val_type == VALUE_TYPE_V128)
        parent_module->is_simd_used = true;
    else if (global->type.val_type == VALUE_TYPE_EXTERNREF)
        parent_module->is_ref_types_used = true;
#endif
    (void)parent_module;
    (void)ret;
    return true;
fail:
    return false;
}

static bool
load_table(const uint8 **p_buf, const uint8 *buf_end, WASMModule *module,
           WASMTable *table, char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end, *p_org;
#if WASM_ENABLE_GC != 0
    WASMRefType ref_type;
    bool need_ref_type_map;
#endif
    bool is_table64 = false;

#if WASM_ENABLE_GC == 0
    CHECK_BUF(p, p_end, 1);
    /* 0x70 or 0x6F */
    table->table_type.elem_type = read_uint8(p);
    if (VALUE_TYPE_FUNCREF != table->table_type.elem_type
#if WASM_ENABLE_REF_TYPES != 0
        && VALUE_TYPE_EXTERNREF != table->table_type.elem_type
#endif
    ) {
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return false;
    }
#else /* else of WASM_ENABLE_GC == 0 */
    if (!resolve_value_type(&p, p_end, module, module->type_count,
                            &need_ref_type_map, &ref_type, false, error_buf,
                            error_buf_size)) {
        return false;
    }
    /*
     * TODO: add this validator
     *   `wasm_is_reftype_htref_non_nullable(ref_type.ref_type)`
     * after sync up with the latest GC spec
     */
    if (!wasm_is_type_reftype(ref_type.ref_type)) {
        set_error_buf(error_buf, error_buf_size, "type mismatch");
        return false;
    }
    table->table_type.elem_type = ref_type.ref_type;
    if (need_ref_type_map) {
        if (!(table->table_type.elem_ref_type =
                  reftype_set_insert(module->ref_type_set, &ref_type, error_buf,
                                     error_buf_size))) {
            return false;
        }
    }
#if TRACE_WASM_LOADER != 0
    os_printf("table type: ");
    wasm_dump_value_type(table->table_type.elem_type,
                         table->table_type.elem_ref_type);
    os_printf("\n");
#endif
#endif /* end of WASM_ENABLE_GC == 0 */

    p_org = p;
    read_leb_uint32(p, p_end, table->table_type.flags);
    is_table64 = table->table_type.flags & TABLE64_FLAG;
    if (p - p_org > 1) {
        LOG_VERBOSE("integer representation too long(table)");
        set_error_buf(error_buf, error_buf_size, "invalid limits flags");
        return false;
    }

    if (!wasm_table_check_flags(table->table_type.flags, error_buf,
                                error_buf_size, false)) {
        return false;
    }

    read_leb_uint32(p, p_end, table->table_type.init_size);
    if (table->table_type.flags & MAX_TABLE_SIZE_FLAG) {
        read_leb_uint32(p, p_end, table->table_type.max_size);
        if (!check_table_max_size(table->table_type.init_size,
                                  table->table_type.max_size, error_buf,
                                  error_buf_size))
            return false;
    }

    adjust_table_max_size(is_table64, table->table_type.init_size,
                          table->table_type.flags & MAX_TABLE_SIZE_FLAG,
                          &table->table_type.max_size);

#if WASM_ENABLE_WAMR_COMPILER != 0
    if (table->table_type.elem_type == VALUE_TYPE_EXTERNREF)
        module->is_ref_types_used = true;
#endif

    *p_buf = p;
    return true;
fail:
    return false;
}

static bool
load_memory(const uint8 **p_buf, const uint8 *buf_end, WASMMemory *memory,
            char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end, *p_org;
#if WASM_ENABLE_APP_FRAMEWORK != 0
    uint32 pool_size = wasm_runtime_memory_pool_size();
    uint32 max_page_count = pool_size * APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT
                            / DEFAULT_NUM_BYTES_PER_PAGE;
#else
    uint32 max_page_count;
#endif
    bool is_memory64 = false;

    p_org = p;
    read_leb_uint32(p, p_end, memory->flags);
    is_memory64 = memory->flags & MEMORY64_FLAG;
    if (p - p_org > 1) {
        LOG_VERBOSE("integer representation too long(memory)");
        set_error_buf(error_buf, error_buf_size, "invalid limits flags");
        return false;
    }

    if (!wasm_memory_check_flags(memory->flags, error_buf, error_buf_size,
                                 false)) {
        return false;
    }

    read_leb_uint32(p, p_end, memory->init_page_count);
    if (!check_memory_init_size(is_memory64, memory->init_page_count, error_buf,
                                error_buf_size))
        return false;

#if WASM_ENABLE_APP_FRAMEWORK == 0
    max_page_count = is_memory64 ? DEFAULT_MEM64_MAX_PAGES : DEFAULT_MAX_PAGES;
#endif
    if (memory->flags & 1) {
        read_leb_uint32(p, p_end, memory->max_page_count);
        if (!check_memory_max_size(is_memory64, memory->init_page_count,
                                   memory->max_page_count, error_buf,
                                   error_buf_size))
            return false;
        if (memory->max_page_count > max_page_count)
            memory->max_page_count = max_page_count;
    }
    else {
        /* Limit the maximum memory size to max_page_count */
        memory->max_page_count = max_page_count;
    }

    memory->num_bytes_per_page = DEFAULT_NUM_BYTES_PER_PAGE;

    *p_buf = p;
    return true;
fail:
    return false;
}

static int
cmp_export_name(const void *a, const void *b)
{
    return strcmp(*(char **)a, *(char **)b);
}

static bool
load_import_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                    bool is_load_from_file_buf, bool no_resolve,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end, *p_old;
    uint32 import_count, name_len, type_index, i, u32, flags;
    uint64 total_size;
    WASMImport *import;
    WASMImport *import_functions = NULL, *import_tables = NULL;
    WASMImport *import_memories = NULL, *import_globals = NULL;
#if WASM_ENABLE_TAGS != 0
    WASMImport *import_tags = NULL;
#endif
    char *sub_module_name, *field_name;
    uint8 u8, kind, global_type;

    read_leb_uint32(p, p_end, import_count);

    if (import_count) {
        module->import_count = import_count;
        total_size = sizeof(WASMImport) * (uint64)import_count;
        if (!(module->imports =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        p_old = p;

        /* Scan firstly to get import count of each type */
        for (i = 0; i < import_count; i++) {
            /* module name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            p += name_len;

            /* field name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            p += name_len;

            CHECK_BUF(p, p_end, 1);
            /* 0x00/0x01/0x02/0x03/0x04 */
            kind = read_uint8(p);

            switch (kind) {
                case IMPORT_KIND_FUNC: /* import function */
                    read_leb_uint32(p, p_end, type_index);
                    module->import_function_count++;
                    break;

                case IMPORT_KIND_TABLE: /* import table */
                    CHECK_BUF(p, p_end, 1);
                    /* 0x70 */
                    u8 = read_uint8(p);
#if WASM_ENABLE_GC != 0
                    if (wasm_is_reftype_htref_nullable(u8)) {
                        int32 heap_type;
                        read_leb_int32(p, p_end, heap_type);
                        (void)heap_type;
                    }
#endif
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    module->import_table_count++;

                    if (module->import_table_count > 1) {
#if WASM_ENABLE_REF_TYPES == 0 && WASM_ENABLE_GC == 0
                        set_error_buf(error_buf, error_buf_size,
                                      "multiple tables");
                        return false;
#elif WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_ref_types_used = true;
#endif
                    }
                    break;

                case IMPORT_KIND_MEMORY: /* import memory */
                    read_leb_uint32(p, p_end, flags);
                    read_leb_uint32(p, p_end, u32);
                    if (flags & 1)
                        read_leb_uint32(p, p_end, u32);
                    module->import_memory_count++;
#if WASM_ENABLE_MULTI_MEMORY == 0
                    if (module->import_memory_count > 1) {
                        set_error_buf(error_buf, error_buf_size,
                                      "multiple memories");
                        return false;
                    }
#endif
                    break;

#if WASM_ENABLE_TAGS != 0
                case IMPORT_KIND_TAG: /* import tags */
                    /* it only counts the number of tags to import */
                    module->import_tag_count++;
                    CHECK_BUF(p, p_end, 1);
                    u8 = read_uint8(p);
                    read_leb_uint32(p, p_end, type_index);
                    break;
#endif

                case IMPORT_KIND_GLOBAL: /* import global */
#if WASM_ENABLE_GC != 0
                    /* valtype */
                    CHECK_BUF(p, p_end, 1);
                    global_type = read_uint8(p);
                    if (wasm_is_reftype_htref_nullable(global_type)
                        || wasm_is_reftype_htref_non_nullable(global_type)) {
                        int32 heap_type;
                        read_leb_int32(p, p_end, heap_type);
                        (void)heap_type;
                    }

                    /* mutability */
                    CHECK_BUF(p, p_end, 1);
                    p += 1;
#else
                    CHECK_BUF(p, p_end, 2);
                    p += 2;
#endif

                    (void)global_type;
                    module->import_global_count++;
                    break;

                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid import kind");
                    return false;
            }
        }

        if (module->import_function_count)
            import_functions = module->import_functions = module->imports;
        if (module->import_table_count)
            import_tables = module->import_tables =
                module->imports + module->import_function_count;
        if (module->import_memory_count)
            import_memories = module->import_memories =
                module->imports + module->import_function_count
                + module->import_table_count;

#if WASM_ENABLE_TAGS != 0
        if (module->import_tag_count)
            import_tags = module->import_tags =
                module->imports + module->import_function_count
                + module->import_table_count + module->import_memory_count;
        if (module->import_global_count)
            import_globals = module->import_globals =
                module->imports + module->import_function_count
                + module->import_table_count + module->import_memory_count
                + module->import_tag_count;
#else
        if (module->import_global_count)
            import_globals = module->import_globals =
                module->imports + module->import_function_count
                + module->import_table_count + module->import_memory_count;
#endif

        p = p_old;

        /* Scan again to resolve the data */
        for (i = 0; i < import_count; i++) {
            /* load module name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            if (!(sub_module_name = wasm_const_str_list_insert(
                      p, name_len, module, is_load_from_file_buf, error_buf,
                      error_buf_size))) {
                return false;
            }
            p += name_len;

            /* load field name */
            read_leb_uint32(p, p_end, name_len);
            CHECK_BUF(p, p_end, name_len);
            if (!(field_name = wasm_const_str_list_insert(
                      p, name_len, module, is_load_from_file_buf, error_buf,
                      error_buf_size))) {
                return false;
            }
            p += name_len;

            CHECK_BUF(p, p_end, 1);
            /* 0x00/0x01/0x02/0x03/0x4 */
            kind = read_uint8(p);

            switch (kind) {
                case IMPORT_KIND_FUNC: /* import function */
                    bh_assert(import_functions);
                    import = import_functions++;
                    if (!load_function_import(&p, p_end, module,
                                              sub_module_name, field_name,
                                              &import->u.function, no_resolve,
                                              error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

                case IMPORT_KIND_TABLE: /* import table */
                    bh_assert(import_tables);
                    import = import_tables++;
                    if (!load_table_import(&p, p_end, module, sub_module_name,
                                           field_name, &import->u.table,
                                           error_buf, error_buf_size)) {
                        LOG_DEBUG("can not import such a table (%s,%s)",
                                  sub_module_name, field_name);
                        return false;
                    }
                    break;

                case IMPORT_KIND_MEMORY: /* import memory */
                    bh_assert(import_memories);
                    import = import_memories++;
                    if (!load_memory_import(&p, p_end, module, sub_module_name,
                                            field_name, &import->u.memory,
                                            error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

#if WASM_ENABLE_TAGS != 0
                case IMPORT_KIND_TAG:
                    bh_assert(import_tags);
                    import = import_tags++;
                    if (!load_tag_import(&p, p_end, module, sub_module_name,
                                         field_name, &import->u.tag, error_buf,
                                         error_buf_size)) {
                        return false;
                    }
                    break;
#endif

                case IMPORT_KIND_GLOBAL: /* import global */
                    bh_assert(import_globals);
                    import = import_globals++;
                    if (!load_global_import(&p, p_end, module, sub_module_name,
                                            field_name, &import->u.global,
                                            error_buf, error_buf_size)) {
                        return false;
                    }
                    break;

                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid import kind");
                    return false;
            }
            import->kind = kind;
            import->u.names.module_name = sub_module_name;
            import->u.names.field_name = field_name;
        }

#if WASM_ENABLE_LIBC_WASI != 0
        import = module->import_functions;
        for (i = 0; i < module->import_function_count; i++, import++) {
            if (!strcmp(import->u.names.module_name, "wasi_unstable")
                || !strcmp(import->u.names.module_name,
                           "wasi_snapshot_preview1")) {
                module->import_wasi_api = true;
                break;
            }
        }
#endif
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load import section success.\n");
    (void)u8;
    (void)u32;
    (void)type_index;
    return true;
fail:
    return false;
}

static bool
init_function_local_offsets(WASMFunction *func, char *error_buf,
                            uint32 error_buf_size)
{
    WASMFuncType *param_type = func->func_type;
    uint32 param_count = param_type->param_count;
    uint8 *param_types = param_type->types;
    uint32 local_count = func->local_count;
    uint8 *local_types = func->local_types;
    uint32 i, local_offset = 0;
    uint64 total_size = sizeof(uint16) * ((uint64)param_count + local_count);

    /*
     * Only allocate memory when total_size is not 0,
     * or the return value of malloc(0) might be NULL on some platforms,
     * which causes wasm loader return false.
     */
    if (total_size > 0
        && !(func->local_offsets =
                 loader_malloc(total_size, error_buf, error_buf_size))) {
        return false;
    }

    for (i = 0; i < param_count; i++) {
        func->local_offsets[i] = (uint16)local_offset;
        local_offset += wasm_value_type_cell_num(param_types[i]);
    }

    for (i = 0; i < local_count; i++) {
        func->local_offsets[param_count + i] = (uint16)local_offset;
        local_offset += wasm_value_type_cell_num(local_types[i]);
    }

    bh_assert(local_offset == func->param_cell_num + func->local_cell_num);
    return true;
}

static bool
load_function_section(const uint8 *buf, const uint8 *buf_end,
                      const uint8 *buf_code, const uint8 *buf_code_end,
                      WASMModule *module, char *error_buf,
                      uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    const uint8 *p_code = buf_code, *p_code_end, *p_code_save;
    uint32 func_count;
    uint64 total_size;
    uint32 code_count = 0, code_size, type_index, i, j, k, local_type_index;
    uint32 local_count, local_set_count, sub_local_count, local_cell_num;
    uint8 type;
    WASMFunction *func;
#if WASM_ENABLE_GC != 0
    bool need_ref_type_map;
    WASMRefType ref_type;
    uint32 ref_type_map_count = 0, t = 0, type_index_org;
#endif

    read_leb_uint32(p, p_end, func_count);

    if (buf_code)
        read_leb_uint32(p_code, buf_code_end, code_count);

    if (func_count != code_count) {
        set_error_buf(error_buf, error_buf_size,
                      "function and code section have inconsistent lengths or "
                      "unexpected end");
        return false;
    }

    if (is_indices_overflow(module->import_function_count, func_count,
                            error_buf, error_buf_size))
        return false;

    if (func_count) {
        module->function_count = func_count;
        total_size = sizeof(WASMFunction *) * (uint64)func_count;
        if (!(module->functions =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        for (i = 0; i < func_count; i++) {
            /* Resolve function type */
            read_leb_uint32(p, p_end, type_index);

            if (!check_function_type(module, type_index, error_buf,
                                     error_buf_size)) {
                return false;
            }

#if WASM_ENABLE_GC != 0
            type_index_org = type_index;
#endif

#if (WASM_ENABLE_WAMR_COMPILER != 0 || WASM_ENABLE_JIT != 0) \
    && WASM_ENABLE_GC == 0
            type_index = wasm_get_smallest_type_idx(
                module->types, module->type_count, type_index);
#endif

            read_leb_uint32(p_code, buf_code_end, code_size);
            if (code_size == 0 || p_code + code_size > buf_code_end) {
                set_error_buf(error_buf, error_buf_size,
                              "invalid function code size");
                return false;
            }

            /* Resolve local set count */
            p_code_end = p_code + code_size;
            local_count = 0;
            read_leb_uint32(p_code, buf_code_end, local_set_count);
            p_code_save = p_code;

#if WASM_ENABLE_GC != 0
            ref_type_map_count = 0;
#endif

            /* Calculate total local count */
            for (j = 0; j < local_set_count; j++) {
                read_leb_uint32(p_code, buf_code_end, sub_local_count);
                if (sub_local_count > UINT32_MAX - local_count) {
                    set_error_buf(error_buf, error_buf_size, "too many locals");
                    return false;
                }
#if WASM_ENABLE_GC == 0
                CHECK_BUF(p_code, buf_code_end, 1);
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                local_count += sub_local_count;
#if WASM_ENABLE_WAMR_COMPILER != 0
                /* If any value's type is v128, mark the module as SIMD used */
                if (type == VALUE_TYPE_V128)
                    module->is_simd_used = true;
#endif
#else
                if (!resolve_value_type(&p_code, buf_code_end, module,
                                        module->type_count, &need_ref_type_map,
                                        &ref_type, false, error_buf,
                                        error_buf_size)) {
                    return false;
                }
                local_count += sub_local_count;
                if (need_ref_type_map)
                    ref_type_map_count += sub_local_count;
#endif
            }

            /* Code size in code entry can't be smaller than size of vec(locals)
             * + expr(at least 1 for opcode end). And expressions are encoded by
             * their instruction sequence terminated with an explicit 0x0B
             * opcode for end. */
            if (p_code_end <= p_code || *(p_code_end - 1) != WASM_OP_END) {
                set_error_buf(
                    error_buf, error_buf_size,
                    "section size mismatch: function body END opcode expected");
                return false;
            }

            /* Alloc memory, layout: function structure + local types */
            code_size = (uint32)(p_code_end - p_code);

            total_size = sizeof(WASMFunction) + (uint64)local_count;
            if (!(func = module->functions[i] =
                      loader_malloc(total_size, error_buf, error_buf_size))) {
                return false;
            }
#if WASM_ENABLE_GC != 0
            if (ref_type_map_count > 0) {
                total_size =
                    sizeof(WASMRefTypeMap) * (uint64)ref_type_map_count;
                if (!(func->local_ref_type_maps = loader_malloc(
                          total_size, error_buf, error_buf_size))) {
                    return false;
                }
                func->local_ref_type_map_count = ref_type_map_count;
            }
#endif

            /* Set function type, local count, code size and code body */
            func->func_type = (WASMFuncType *)module->types[type_index];
            func->local_count = local_count;
            if (local_count > 0)
                func->local_types = (uint8 *)func + sizeof(WASMFunction);
            func->code_size = code_size;
            /*
             * we shall make a copy of code body [p_code, p_code + code_size]
             * when we are worrying about inappropriate releasing behaviour.
             * all code bodies are actually in a buffer which user allocates in
             * their embedding environment and we don't have power over them.
             * it will be like:
             * code_body_cp = malloc(code_size);
             * memcpy(code_body_cp, p_code, code_size);
             * func->code = code_body_cp;
             */
            func->code = (uint8 *)p_code;
#if WASM_ENABLE_GC != 0
            func->type_idx = type_index_org;
#endif

#if WASM_ENABLE_GC != 0
            t = 0;
#endif

            /* Load each local type */
            p_code = p_code_save;
            local_type_index = 0;
            for (j = 0; j < local_set_count; j++) {
                read_leb_uint32(p_code, buf_code_end, sub_local_count);
                /* Note: sub_local_count is allowed to be 0 */
                if (local_type_index > UINT32_MAX - sub_local_count
                    || local_type_index + sub_local_count > local_count) {
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid local count");
                    return false;
                }
#if WASM_ENABLE_GC == 0
                CHECK_BUF(p_code, buf_code_end, 1);
                /* 0x7F/0x7E/0x7D/0x7C */
                type = read_uint8(p_code);
                if (!is_valid_value_type_for_interpreter(type)) {
                    if (type == VALUE_TYPE_V128)
                        set_error_buf(error_buf, error_buf_size,
                                      "v128 value type requires simd feature");
                    else if (type == VALUE_TYPE_FUNCREF
                             || type == VALUE_TYPE_EXTERNREF)
                        set_error_buf(error_buf, error_buf_size,
                                      "ref value type requires "
                                      "reference types feature");
                    else
                        set_error_buf_v(error_buf, error_buf_size,
                                        "invalid local type 0x%02X", type);
                    return false;
                }
#else
                if (!resolve_value_type(&p_code, buf_code_end, module,
                                        module->type_count, &need_ref_type_map,
                                        &ref_type, false, error_buf,
                                        error_buf_size)) {
                    return false;
                }
                if (need_ref_type_map) {
                    WASMRefType *ref_type_tmp;
                    if (!(ref_type_tmp = reftype_set_insert(
                              module->ref_type_set, &ref_type, error_buf,
                              error_buf_size))) {
                        return false;
                    }
                    for (k = 0; k < sub_local_count; k++) {
                        func->local_ref_type_maps[t + k].ref_type =
                            ref_type_tmp;
                        func->local_ref_type_maps[t + k].index =
                            local_type_index + k;
                    }
                    t += sub_local_count;
                }
                type = ref_type.ref_type;
#endif
                for (k = 0; k < sub_local_count; k++) {
                    func->local_types[local_type_index++] = type;
                }
#if WASM_ENABLE_WAMR_COMPILER != 0
                if (type == VALUE_TYPE_V128)
                    module->is_simd_used = true;
                else if (type == VALUE_TYPE_FUNCREF
                         || type == VALUE_TYPE_EXTERNREF)
                    module->is_ref_types_used = true;
#endif
            }

            bh_assert(local_type_index == func->local_count);
#if WASM_ENABLE_GC != 0
            bh_assert(t == func->local_ref_type_map_count);
#if TRACE_WASM_LOADER != 0
            os_printf("func %u, local types: [", i);
            k = 0;
            for (j = 0; j < func->local_count; j++) {
                WASMRefType *ref_type_tmp = NULL;
                if (wasm_is_type_multi_byte_type(func->local_types[j])) {
                    bh_assert(j == func->local_ref_type_maps[k].index);
                    ref_type_tmp = func->local_ref_type_maps[k++].ref_type;
                }
                wasm_dump_value_type(func->local_types[j], ref_type_tmp);
                if (j < func->local_count - 1)
                    os_printf(" ");
            }
            os_printf("]\n");
#endif
#endif

            func->param_cell_num = func->func_type->param_cell_num;
            func->ret_cell_num = func->func_type->ret_cell_num;
            local_cell_num =
                wasm_get_cell_num(func->local_types, func->local_count);

            if (local_cell_num > UINT16_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "local count too large");
                return false;
            }

            func->local_cell_num = (uint16)local_cell_num;

            if (!init_function_local_offsets(func, error_buf, error_buf_size))
                return false;

            p_code = p_code_end;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load function section success.\n");
    return true;
fail:
    return false;
}

static bool
load_table_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 table_count, i;
    uint64 total_size;
    WASMTable *table;

    read_leb_uint32(p, p_end, table_count);
    if (module->import_table_count + table_count > 1) {
#if WASM_ENABLE_REF_TYPES == 0 && WASM_ENABLE_GC == 0
        /* a total of one table is allowed */
        set_error_buf(error_buf, error_buf_size, "multiple tables");
        return false;
#elif WASM_ENABLE_WAMR_COMPILER != 0
        module->is_ref_types_used = true;
#endif
    }

    if (table_count) {
        module->table_count = table_count;
        total_size = sizeof(WASMTable) * (uint64)table_count;
        if (!(module->tables =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        /* load each table */
        table = module->tables;
        for (i = 0; i < table_count; i++, table++) {
#if WASM_ENABLE_GC != 0
            uint8 flag;
            bool has_init = false;

            CHECK_BUF(p, p_end, 1);
            flag = read_uint8(p);

            if (flag == TABLE_INIT_EXPR_FLAG) {
                CHECK_BUF(p, p_end, 1);
                flag = read_uint8(p);

                if (flag != 0x00) {
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid leading bytes for table");
                    return false;
                }
                has_init = true;
            }
            else {
                p--;
            }
#endif /* end of WASM_ENABLE_GC != 0 */

            if (!load_table(&p, p_end, module, table, error_buf,
                            error_buf_size))
                return false;

#if WASM_ENABLE_GC != 0
            if (has_init) {
                if (!load_init_expr(module, &p, p_end, &table->init_expr,
                                    table->table_type.elem_type,
                                    table->table_type.elem_ref_type, error_buf,
                                    error_buf_size))
                    return false;
                if (table->init_expr.init_expr_type >= INIT_EXPR_TYPE_STRUCT_NEW
                    && table->init_expr.init_expr_type
                           <= INIT_EXPR_TYPE_ARRAY_NEW_FIXED) {
                    set_error_buf(
                        error_buf, error_buf_size,
                        "unsupported initializer expression for table");
                    return false;
                }
            }
            else {
                if (wasm_is_reftype_htref_non_nullable(
                        table->table_type.elem_type)) {
                    set_error_buf(
                        error_buf, error_buf_size,
                        "type mismatch: non-nullable table without init expr");
                    return false;
                }
            }
#endif /* end of WASM_ENABLE_GC != 0 */

#if WASM_ENABLE_WAMR_COMPILER != 0
            if (table->table_type.elem_type == VALUE_TYPE_EXTERNREF)
                module->is_ref_types_used = true;
#endif
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load table section success.\n");
    return true;
fail:
    return false;
}

static bool
load_memory_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 memory_count, i;
    uint64 total_size;
    WASMMemory *memory;

    read_leb_uint32(p, p_end, memory_count);

#if WASM_ENABLE_MULTI_MEMORY == 0
    /* a total of one memory is allowed */
    if (module->import_memory_count + memory_count > 1) {
        set_error_buf(error_buf, error_buf_size, "multiple memories");
        return false;
    }
#endif

    if (memory_count) {
        module->memory_count = memory_count;
        total_size = sizeof(WASMMemory) * (uint64)memory_count;
        if (!(module->memories =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        /* load each memory */
        memory = module->memories;
        for (i = 0; i < memory_count; i++, memory++)
            if (!load_memory(&p, p_end, memory, error_buf, error_buf_size))
                return false;
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load memory section success.\n");
    return true;
fail:
    return false;
}

static bool
load_global_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 global_count, i;
    uint64 total_size;
    WASMGlobal *global;
    uint8 mutable;
#if WASM_ENABLE_GC != 0
    bool need_ref_type_map;
    WASMRefType ref_type;
#endif

    read_leb_uint32(p, p_end, global_count);
    if (is_indices_overflow(module->import_global_count, global_count,
                            error_buf, error_buf_size))
        return false;

    module->global_count = 0;
    if (global_count) {
        total_size = sizeof(WASMGlobal) * (uint64)global_count;
        if (!(module->globals =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        global = module->globals;

        for (i = 0; i < global_count; i++, global++) {
#if WASM_ENABLE_GC == 0
            CHECK_BUF(p, p_end, 2);
            /* global type */
            global->type.val_type = read_uint8(p);
            if (!is_valid_value_type_for_interpreter(global->type.val_type)) {
                set_error_buf(error_buf, error_buf_size, "type mismatch");
                return false;
            }
            mutable = read_uint8(p);
#else
            if (!resolve_value_type(&p, p_end, module, module->type_count,
                                    &need_ref_type_map, &ref_type, false,
                                    error_buf, error_buf_size)) {
                return false;
            }
            global->type.val_type = ref_type.ref_type;
            CHECK_BUF(p, p_end, 1);
            mutable = read_uint8(p);
#endif /* end of WASM_ENABLE_GC */

#if WASM_ENABLE_WAMR_COMPILER != 0
            if (global->type.val_type == VALUE_TYPE_V128)
                module->is_simd_used = true;
            else if (global->type.val_type == VALUE_TYPE_FUNCREF
                     || global->type.val_type == VALUE_TYPE_EXTERNREF)
                module->is_ref_types_used = true;
#endif

            if (!check_mutability(mutable, error_buf, error_buf_size)) {
                return false;
            }
            global->type.is_mutable = mutable ? true : false;

            /* initialize expression */
            if (!load_init_expr(module, &p, p_end, &(global->init_expr),
                                global->type.val_type,
#if WASM_ENABLE_GC == 0
                                NULL,
#else
                                &ref_type,
#endif
                                error_buf, error_buf_size))
                return false;

#if WASM_ENABLE_GC != 0
            if (global->init_expr.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
                uint8 global_type;
                WASMRefType *global_ref_type;
                uint32 global_idx = global->init_expr.u.unary.v.global_index;

                if (global->init_expr.u.unary.v.global_index
                    >= module->import_global_count + i) {
                    set_error_buf(error_buf, error_buf_size, "unknown global");
                    return false;
                }

                if (global_idx < module->import_global_count) {
                    global_type = module->import_globals[global_idx]
                                      .u.global.type.val_type;
                    global_ref_type =
                        module->import_globals[global_idx].u.global.ref_type;
                }
                else {
                    global_type =
                        module
                            ->globals[global_idx - module->import_global_count]
                            .type.val_type;
                    global_ref_type =
                        module
                            ->globals[global_idx - module->import_global_count]
                            .ref_type;
                }
                if (!wasm_reftype_is_subtype_of(
                        global_type, global_ref_type, global->type.val_type,
                        global->ref_type, module->types, module->type_count)) {
                    set_error_buf(error_buf, error_buf_size, "type mismatch");
                    return false;
                }
            }

            if (need_ref_type_map) {
                if (!(global->ref_type =
                          reftype_set_insert(module->ref_type_set, &ref_type,
                                             error_buf, error_buf_size))) {
                    return false;
                }
            }
#if TRACE_WASM_LOADER != 0
            os_printf("global type: ");
            wasm_dump_value_type(global->type, global->ref_type);
            os_printf("\n");
#endif
#endif
            module->global_count++;
        }
        bh_assert(module->global_count == global_count);
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load global section success.\n");
    return true;
fail:
    return false;
}

static bool
check_duplicate_exports(WASMModule *module, char *error_buf,
                        uint32 error_buf_size)
{
    uint32 i;
    bool result = false;
    char *names_buf[32], **names = names_buf;

    if (module->export_count > 32) {
        names = loader_malloc(module->export_count * sizeof(char *), error_buf,
                              error_buf_size);
        if (!names) {
            return result;
        }
    }

    for (i = 0; i < module->export_count; i++) {
        names[i] = module->exports[i].name;
    }

    qsort(names, module->export_count, sizeof(char *), cmp_export_name);

    for (i = 1; i < module->export_count; i++) {
        if (!strcmp(names[i], names[i - 1])) {
            set_error_buf(error_buf, error_buf_size, "duplicate export name");
            goto cleanup;
        }
    }

    result = true;
cleanup:
    if (module->export_count > 32) {
        wasm_runtime_free(names);
    }
    return result;
}

static bool
load_export_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                    bool is_load_from_file_buf, char *error_buf,
                    uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 export_count, i, index;
    uint64 total_size;
    uint32 str_len;
    WASMExport *export;

    read_leb_uint32(p, p_end, export_count);

    if (export_count) {
        module->export_count = export_count;
        total_size = sizeof(WASMExport) * (uint64)export_count;
        if (!(module->exports =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        export = module->exports;
        for (i = 0; i < export_count; i++, export ++) {
#if WASM_ENABLE_THREAD_MGR == 0
            if (p == p_end) {
                /* export section with inconsistent count:
                   n export declared, but less than n given */
                set_error_buf(error_buf, error_buf_size,
                              "length out of bounds");
                return false;
            }
#endif
            read_leb_uint32(p, p_end, str_len);
            CHECK_BUF(p, p_end, str_len);

            if (!(export->name = wasm_const_str_list_insert(
                      p, str_len, module, is_load_from_file_buf, error_buf,
                      error_buf_size))) {
                return false;
            }

            p += str_len;
            CHECK_BUF(p, p_end, 1);
            export->kind = read_uint8(p);
            read_leb_uint32(p, p_end, index);
            export->index = index;

            switch (export->kind) {
                /* function index */
                case EXPORT_KIND_FUNC:
                    if (index >= module->function_count
                                     + module->import_function_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown function");
                        return false;
                    }
#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
                    /* TODO: check func type, if it has v128 param or result,
                             report error */
#endif
#endif
                    break;
                /* table index */
                case EXPORT_KIND_TABLE:
                    if (index
                        >= module->table_count + module->import_table_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown table");
                        return false;
                    }
                    break;
                /* memory index */
                case EXPORT_KIND_MEMORY:
                    if (index
                        >= module->memory_count + module->import_memory_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown memory");
                        return false;
                    }
                    break;
#if WASM_ENABLE_TAGS != 0
                /* export tag */
                case EXPORT_KIND_TAG:
                    if (index >= module->tag_count + module->import_tag_count) {
                        set_error_buf(error_buf, error_buf_size, "unknown tag");
                        return false;
                    }
                    break;
#endif

                /* global index */
                case EXPORT_KIND_GLOBAL:
                    if (index
                        >= module->global_count + module->import_global_count) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown global");
                        return false;
                    }
                    break;

                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid export kind");
                    return false;
            }
        }

        if (!check_duplicate_exports(module, error_buf, error_buf_size)) {
            return false;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load export section success.\n");
    return true;
fail:
    return false;
}

static bool
check_table_index(const WASMModule *module, uint32 table_index, char *error_buf,
                  uint32 error_buf_size)
{
#if WASM_ENABLE_REF_TYPES == 0 && WASM_ENABLE_GC == 0
    if (table_index != 0) {
        set_error_buf(
            error_buf, error_buf_size,
            "zero byte expected. The module uses reference types feature "
            "which is disabled in the runtime.");
        return false;
    }
#endif

    if (table_index >= module->import_table_count + module->table_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown table %d",
                        table_index);
        return false;
    }
    return true;
}

static bool
load_table_index(const uint8 **p_buf, const uint8 *buf_end, WASMModule *module,
                 uint32 *p_table_index, char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint32 table_index;

    read_leb_uint32(p, p_end, table_index);
    if (!check_table_index(module, table_index, error_buf, error_buf_size)) {
        return false;
    }

    *p_table_index = table_index;
    *p_buf = p;
    return true;
fail:
    return false;
}

/* Element segments must match element type of table */
static bool
check_table_elem_type(WASMModule *module, uint32 table_index,
                      uint32 type_from_elem_seg, char *error_buf,
                      uint32 error_buf_size)
{
    uint32 table_declared_elem_type;

    if (table_index < module->import_table_count)
        table_declared_elem_type =
            module->import_tables[table_index].u.table.table_type.elem_type;
    else
        table_declared_elem_type =
            module->tables[table_index - module->import_table_count]
                .table_type.elem_type;

    if (table_declared_elem_type == type_from_elem_seg)
        return true;

#if WASM_ENABLE_GC != 0
    /*
     * balance in: anyref, funcref, (ref.null func) and (ref.func)
     */
    if (table_declared_elem_type == REF_TYPE_ANYREF)
        return true;

    if (table_declared_elem_type == VALUE_TYPE_FUNCREF
        && type_from_elem_seg == REF_TYPE_HT_NON_NULLABLE)
        return true;

    if (table_declared_elem_type == REF_TYPE_HT_NULLABLE
        && type_from_elem_seg == REF_TYPE_HT_NON_NULLABLE)
        return true;
#endif

    set_error_buf(error_buf, error_buf_size, "type mismatch");
    return false;
}

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
static bool
load_elem_type(WASMModule *module, const uint8 **p_buf, const uint8 *buf_end,
               uint32 *p_elem_type,
#if WASM_ENABLE_GC != 0
               WASMRefType **p_elem_ref_type,
#endif
               bool elemkind_zero, char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint8 elem_type;
#if WASM_ENABLE_GC != 0
    WASMRefType elem_ref_type;
    bool need_ref_type_map;
#endif

    CHECK_BUF(p, p_end, 1);
    elem_type = read_uint8(p);
    if (elemkind_zero) {
        if (elem_type != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "invalid reference type or unknown type");
            return false;
        }
        else {
            *p_elem_type = VALUE_TYPE_FUNCREF;
            *p_buf = p;
            return true;
        }
    }

#if WASM_ENABLE_GC == 0
    if (elem_type != VALUE_TYPE_FUNCREF && elem_type != VALUE_TYPE_EXTERNREF) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid reference type or unknown type");
        return false;
    }
    *p_elem_type = elem_type;
#else
    p--;
    if (!resolve_value_type((const uint8 **)&p, p_end, module,
                            module->type_count, &need_ref_type_map,
                            &elem_ref_type, false, error_buf, error_buf_size)) {
        return false;
    }
    if (!wasm_is_type_reftype(elem_ref_type.ref_type)) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid reference type or unknown type");
        return false;
    }
    *p_elem_type = elem_ref_type.ref_type;
    if (need_ref_type_map) {
        if (!(*p_elem_ref_type =
                  reftype_set_insert(module->ref_type_set, &elem_ref_type,
                                     error_buf, error_buf_size))) {
            return false;
        }
    }
#endif

    *p_buf = p;
    return true;
fail:
    return false;
}
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

static bool
load_func_index_vec(const uint8 **p_buf, const uint8 *buf_end,
                    WASMModule *module, WASMTableSeg *table_segment,
                    char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint32 function_count, function_index = 0, i;
    uint64 total_size;

    read_leb_uint32(p, p_end, function_count);
    table_segment->value_count = function_count;
    total_size = sizeof(InitializerExpression) * (uint64)function_count;
    if (total_size > 0
        && !(table_segment->init_values =
                 (InitializerExpression *)loader_malloc(total_size, error_buf,
                                                        error_buf_size))) {
        return false;
    }

    for (i = 0; i < function_count; i++) {
        InitializerExpression *init_expr = &table_segment->init_values[i];

        read_leb_uint32(p, p_end, function_index);
        if (!check_function_index(module, function_index, error_buf,
                                  error_buf_size)) {
            return false;
        }

        init_expr->init_expr_type = INIT_EXPR_TYPE_FUNCREF_CONST;
        init_expr->u.unary.v.ref_index = function_index;
    }

    *p_buf = p;
    return true;
fail:
    return false;
}

#if (WASM_ENABLE_GC != 0) || (WASM_ENABLE_REF_TYPES != 0)
static bool
load_init_expr_vec(const uint8 **p_buf, const uint8 *buf_end,
                   WASMModule *module, WASMTableSeg *table_segment,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = *p_buf, *p_end = buf_end;
    uint32 ref_count, i;
    uint64 total_size;

    read_leb_uint32(p, p_end, ref_count);
    table_segment->value_count = ref_count;
    total_size = sizeof(InitializerExpression) * (uint64)ref_count;
    if (total_size > 0
        && !(table_segment->init_values =
                 (InitializerExpression *)loader_malloc(total_size, error_buf,
                                                        error_buf_size))) {
        return false;
    }

    for (i = 0; i < ref_count; i++) {
        InitializerExpression *init_expr = &table_segment->init_values[i];

        if (!load_init_expr(module, &p, p_end, init_expr,
                            table_segment->elem_type,
#if WASM_ENABLE_GC == 0
                            NULL,
#else
                            table_segment->elem_ref_type,
#endif
                            error_buf, error_buf_size))
            return false;

        bh_assert((init_expr->init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL)
                  || (init_expr->init_expr_type == INIT_EXPR_TYPE_REFNULL_CONST)
                  || (init_expr->init_expr_type >= INIT_EXPR_TYPE_FUNCREF_CONST
                      && init_expr->init_expr_type
                             <= INIT_EXPR_TYPE_ARRAY_NEW_FIXED));
    }

    *p_buf = p;
    return true;
fail:
    return false;
}
#endif /* end of (WASM_ENABLE_GC != 0) || (WASM_ENABLE_REF_TYPES != 0) */

static bool
load_table_segment_section(const uint8 *buf, const uint8 *buf_end,
                           WASMModule *module, char *error_buf,
                           uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint8 table_elem_idx_type;
    uint32 table_segment_count, i;
    uint64 total_size;
    WASMTableSeg *table_segment;

    read_leb_uint32(p, p_end, table_segment_count);

    if (table_segment_count) {
        module->table_seg_count = table_segment_count;
        total_size = sizeof(WASMTableSeg) * (uint64)table_segment_count;
        if (!(module->table_segments =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        table_segment = module->table_segments;
        for (i = 0; i < table_segment_count; i++, table_segment++) {
            if (p >= p_end) {
                set_error_buf(error_buf, error_buf_size,
                              "invalid value type or "
                              "invalid elements segment kind");
                return false;
            }
            table_elem_idx_type = VALUE_TYPE_I32;

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            read_leb_uint32(p, p_end, table_segment->mode);
            /* last three bits */
            table_segment->mode = table_segment->mode & 0x07;
            switch (table_segment->mode) {
                /* elemkind/elemtype + active */
                case 0:
                case 4:
                {
#if WASM_ENABLE_GC != 0
                    if (table_segment->mode == 0) {
                        /* vec(funcidx), set elem type to (ref func) */
                        WASMRefType elem_ref_type = { 0 };
                        table_segment->elem_type = REF_TYPE_HT_NON_NULLABLE;
                        wasm_set_refheaptype_common(
                            &elem_ref_type.ref_ht_common, false,
                            HEAP_TYPE_FUNC);
                        if (!(table_segment->elem_ref_type = reftype_set_insert(
                                  module->ref_type_set, &elem_ref_type,
                                  error_buf, error_buf_size)))
                            return false;
                    }
                    else {
                        /* vec(expr), set elem type to funcref */
                        table_segment->elem_type = VALUE_TYPE_FUNCREF;
                    }
#else
                    table_segment->elem_type = VALUE_TYPE_FUNCREF;
#endif
                    table_segment->table_index = 0;

                    if (!check_table_index(module, table_segment->table_index,
                                           error_buf, error_buf_size))
                        return false;

#if WASM_ENABLE_MEMORY64 != 0
                    table_elem_idx_type =
                        is_table_64bit(module, table_segment->table_index)
                            ? VALUE_TYPE_I64
                            : VALUE_TYPE_I32;
#endif
                    if (!load_init_expr(module, &p, p_end,
                                        &table_segment->base_offset,
                                        table_elem_idx_type, NULL, error_buf,
                                        error_buf_size))
                        return false;

                    if (table_segment->mode == 0) {
                        /* vec(funcidx) */
                        if (!load_func_index_vec(&p, p_end, module,
                                                 table_segment, error_buf,
                                                 error_buf_size))
                            return false;
                    }
                    else {
                        /* vec(expr) */
                        if (!load_init_expr_vec(&p, p_end, module,
                                                table_segment, error_buf,
                                                error_buf_size))
                            return false;
                    }

                    if (!check_table_elem_type(module,
                                               table_segment->table_index,
                                               table_segment->elem_type,
                                               error_buf, error_buf_size))
                        return false;

                    break;
                }
                /* elemkind + passive/declarative */
                case 1:
                case 3:
                    if (!load_elem_type(module, &p, p_end,
                                        &table_segment->elem_type,
#if WASM_ENABLE_GC != 0
                                        &table_segment->elem_ref_type,
#endif
                                        true, error_buf, error_buf_size))
                        return false;
                    /* vec(funcidx) */
                    if (!load_func_index_vec(&p, p_end, module, table_segment,
                                             error_buf, error_buf_size))
                        return false;
                    break;
                /* elemkind/elemtype + table_idx + active */
                case 2:
                case 6:
                    if (!load_table_index(&p, p_end, module,
                                          &table_segment->table_index,
                                          error_buf, error_buf_size))
                        return false;
#if WASM_ENABLE_MEMORY64 != 0
                    table_elem_idx_type =
                        is_table_64bit(module, table_segment->table_index)
                            ? VALUE_TYPE_I64
                            : VALUE_TYPE_I32;
#endif
                    if (!load_init_expr(module, &p, p_end,
                                        &table_segment->base_offset,
                                        table_elem_idx_type, NULL, error_buf,
                                        error_buf_size))
                        return false;
                    if (!load_elem_type(module, &p, p_end,
                                        &table_segment->elem_type,
#if WASM_ENABLE_GC != 0
                                        &table_segment->elem_ref_type,
#endif
                                        table_segment->mode == 2 ? true : false,
                                        error_buf, error_buf_size))
                        return false;

                    if (table_segment->mode == 2) {
                        /* vec(funcidx) */
                        if (!load_func_index_vec(&p, p_end, module,
                                                 table_segment, error_buf,
                                                 error_buf_size))
                            return false;
                    }
                    else {
                        /* vec(expr) */
                        if (!load_init_expr_vec(&p, p_end, module,
                                                table_segment, error_buf,
                                                error_buf_size))
                            return false;
                    }

                    if (!check_table_elem_type(module,
                                               table_segment->table_index,
                                               table_segment->elem_type,
                                               error_buf, error_buf_size))
                        return false;

                    break;
                case 5:
                case 7:
                    if (!load_elem_type(module, &p, p_end,
                                        &table_segment->elem_type,
#if WASM_ENABLE_GC != 0
                                        &table_segment->elem_ref_type,
#endif
                                        false, error_buf, error_buf_size))
                        return false;
                    /* vec(expr) */
                    if (!load_init_expr_vec(&p, p_end, module, table_segment,
                                            error_buf, error_buf_size))
                        return false;
                    break;
                default:
                    set_error_buf(error_buf, error_buf_size,
                                  "unknown element segment kind");
                    return false;
            }
#else /* else of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */
            /*
             * like:      00  41 05 0b               04 00 01 00 01
             * for: (elem 0   (offset (i32.const 5)) $f1 $f2 $f1 $f2)
             */
            if (!load_table_index(&p, p_end, module,
                                  &table_segment->table_index, error_buf,
                                  error_buf_size))
                return false;
#if WASM_ENABLE_MEMORY64 != 0
            table_elem_idx_type =
                is_table_64bit(module, table_segment->table_index)
                    ? VALUE_TYPE_I64
                    : VALUE_TYPE_I32;
#endif
            if (!load_init_expr(module, &p, p_end, &table_segment->base_offset,
                                table_elem_idx_type, NULL, error_buf,
                                error_buf_size))
                return false;
            if (!load_func_index_vec(&p, p_end, module, table_segment,
                                     error_buf, error_buf_size))
                return false;

            table_segment->elem_type = VALUE_TYPE_FUNCREF;

            if (!check_table_elem_type(module, table_segment->table_index,
                                       table_segment->elem_type, error_buf,
                                       error_buf_size))
                return false;
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

#if WASM_ENABLE_MEMORY64 != 0
            if (table_elem_idx_type == VALUE_TYPE_I64
                && table_segment->base_offset.u.unary.v.u64 > UINT32_MAX) {
                set_error_buf(error_buf, error_buf_size,
                              "In table64, table base offset can't be "
                              "larger than UINT32_MAX");
                return false;
            }
#endif

#if WASM_ENABLE_WAMR_COMPILER != 0
            if (table_segment->elem_type == VALUE_TYPE_EXTERNREF)
                module->is_ref_types_used = true;
#endif
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load table segment section success.\n");
    return true;
fail:
    return false;
}

#if WASM_ENABLE_BULK_MEMORY != 0
static bool
check_data_count_consistency(bool has_datacount_section, int datacount_len,
                             int data_seg_len, char *error_buf,
                             uint32 error_buf_size)
{
    if (has_datacount_section && datacount_len != data_seg_len) {
        set_error_buf(error_buf, error_buf_size,
                      "data count and data section have inconsistent lengths");
        return false;
    }
    return true;
}
#endif

static bool
load_data_segment_section(const uint8 *buf, const uint8 *buf_end,
                          WASMModule *module,
#if WASM_ENABLE_BULK_MEMORY != 0
                          bool has_datacount_section,
#endif
                          bool clone_data_seg, char *error_buf,
                          uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 data_seg_count, i, mem_index, data_seg_len;
    uint64 total_size;
    WASMDataSeg *dataseg;
    InitializerExpression init_expr;
#if WASM_ENABLE_BULK_MEMORY != 0
    bool is_passive = false;
    uint32 mem_flag;
#endif
    uint8 mem_offset_type = VALUE_TYPE_I32;

    read_leb_uint32(p, p_end, data_seg_count);

#if WASM_ENABLE_BULK_MEMORY != 0
    if (!check_data_count_consistency(has_datacount_section,
                                      module->data_seg_count1, data_seg_count,
                                      error_buf, error_buf_size)) {
        return false;
    }
#endif

    if (data_seg_count) {
        module->data_seg_count = data_seg_count;
        total_size = sizeof(WASMDataSeg *) * (uint64)data_seg_count;
        if (!(module->data_segments =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }

        for (i = 0; i < data_seg_count; i++) {
            read_leb_uint32(p, p_end, mem_index);
#if WASM_ENABLE_BULK_MEMORY != 0
            is_passive = false;
            mem_flag = mem_index & 0x03;
            switch (mem_flag) {
                case 0x01:
                    is_passive = true;
#if WASM_ENABLE_WAMR_COMPILER != 0
                    module->is_bulk_memory_used = true;
#endif
                    break;
                case 0x00:
                    /* no memory index, treat index as 0 */
                    mem_index = 0;
                    goto check_mem_index;
                case 0x02:
                    /* read following memory index */
                    read_leb_uint32(p, p_end, mem_index);
#if WASM_ENABLE_WAMR_COMPILER != 0
                    module->is_bulk_memory_used = true;
#endif
                check_mem_index:
                    if (mem_index
                        >= module->import_memory_count + module->memory_count) {
                        set_error_buf_v(error_buf, error_buf_size,
                                        "unknown memory %d", mem_index);
                        return false;
                    }
                    break;
                case 0x03:
                default:
                    set_error_buf(error_buf, error_buf_size, "unknown memory");
                    return false;
                    break;
            }
#else
            if (mem_index
                >= module->import_memory_count + module->memory_count) {
                set_error_buf_v(error_buf, error_buf_size, "unknown memory %d",
                                mem_index);
                return false;
            }
#endif /* WASM_ENABLE_BULK_MEMORY */

#if WASM_ENABLE_BULK_MEMORY != 0
            if (!is_passive)
#endif
            {
#if WASM_ENABLE_MEMORY64 != 0
                /* This memory_flag is from memory instead of data segment */
                uint8 memory_flag;
                if (module->import_memory_count > 0) {
                    memory_flag = module->import_memories[mem_index]
                                      .u.memory.mem_type.flags;
                }
                else {
                    memory_flag =
                        module
                            ->memories[mem_index - module->import_memory_count]
                            .flags;
                }
                mem_offset_type = memory_flag & MEMORY64_FLAG ? VALUE_TYPE_I64
                                                              : VALUE_TYPE_I32;
#else
                mem_offset_type = VALUE_TYPE_I32;
#endif
            }

#if WASM_ENABLE_BULK_MEMORY != 0
            if (!is_passive)
#endif
                if (!load_init_expr(module, &p, p_end, &init_expr,
                                    mem_offset_type, NULL, error_buf,
                                    error_buf_size))
                    return false;

            read_leb_uint32(p, p_end, data_seg_len);

            if (!(dataseg = module->data_segments[i] = loader_malloc(
                      sizeof(WASMDataSeg), error_buf, error_buf_size))) {
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                destroy_init_expr(module, &init_expr);
#endif
                return false;
            }

#if WASM_ENABLE_BULK_MEMORY != 0
            dataseg->is_passive = is_passive;
            if (!is_passive)
#endif
            {
                bh_memcpy_s(&dataseg->base_offset,
                            sizeof(InitializerExpression), &init_expr,
                            sizeof(InitializerExpression));

                dataseg->memory_index = mem_index;
            }

            dataseg->data_length = data_seg_len;
            CHECK_BUF(p, p_end, data_seg_len);
            if (clone_data_seg) {
                if (!(dataseg->data = loader_malloc(
                          dataseg->data_length, error_buf, error_buf_size))) {
                    return false;
                }

                bh_memcpy_s(dataseg->data, dataseg->data_length, p,
                            data_seg_len);
            }
            else {
                dataseg->data = (uint8 *)p;
            }
            dataseg->is_data_cloned = clone_data_seg;
            p += data_seg_len;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load data segment section success.\n");
    return true;
fail:
    return false;
}

#if WASM_ENABLE_BULK_MEMORY != 0
static bool
load_datacount_section(const uint8 *buf, const uint8 *buf_end,
                       WASMModule *module, char *error_buf,
                       uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 data_seg_count1 = 0;

    read_leb_uint32(p, p_end, data_seg_count1);
    module->data_seg_count1 = data_seg_count1;

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

#if WASM_ENABLE_WAMR_COMPILER != 0
    module->is_bulk_memory_used = true;
#endif
    LOG_VERBOSE("Load datacount section success.\n");
    return true;
fail:
    return false;
}
#endif

#if WASM_ENABLE_TAGS != 0
static bool
load_tag_section(const uint8 *buf, const uint8 *buf_end, const uint8 *buf_code,
                 const uint8 *buf_code_end, WASMModule *module, char *error_buf,
                 uint32 error_buf_size)
{
    (void)buf_code;
    (void)buf_code_end;

    const uint8 *p = buf, *p_end = buf_end;
    size_t total_size = 0;
    /* number of tags defined in the section */
    uint32 section_tag_count = 0;
    uint8 tag_attribute;
    uint32 tag_type;
    WASMTag *tag = NULL;

    /* get tag count */
    read_leb_uint32(p, p_end, section_tag_count);
    if (is_indices_overflow(module->import_tag_count, section_tag_count,
                            error_buf, error_buf_size))
        return false;

    module->tag_count = section_tag_count;

    if (section_tag_count) {
        total_size = sizeof(WASMTag *) * module->tag_count;
        if (!(module->tags =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            return false;
        }
        /* load each tag, imported tags precede the tags */
        uint32 tag_index;
        for (tag_index = 0; tag_index < section_tag_count; tag_index++) {

            /* get the one byte attribute */
            CHECK_BUF(p, p_end, 1);
            tag_attribute = read_uint8(p);

            /* get type */
            read_leb_uint32(p, p_end, tag_type);
            /* compare against module->types */
            if (!check_function_type(module, tag_type, error_buf,
                                     error_buf_size)) {
                return false;
            }

            /* get return type (must be 0) */
            /* check, that the type of the referred tag returns void */
            WASMFuncType *func_type = (WASMFuncType *)module->types[tag_type];
            if (func_type->result_count != 0) {
                set_error_buf(error_buf, error_buf_size,
                              "non-empty tag result type");

                goto fail;
            }

            if (!(tag = module->tags[tag_index] = loader_malloc(
                      sizeof(WASMTag), error_buf, error_buf_size))) {
                return false;
            }

            /* store to module tag declarations */
            tag->attribute = tag_attribute;
            tag->type = tag_type;
            tag->tag_type = func_type;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load tag section success.\n");
    return true;
fail:
    return false;
}
#endif /* end of WASM_ENABLE_TAGS != 0 */

static bool
load_code_section(const uint8 *buf, const uint8 *buf_end, const uint8 *buf_func,
                  const uint8 *buf_func_end, WASMModule *module,
                  char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    const uint8 *p_func = buf_func;
    uint32 func_count = 0, code_count;

    /* code has been loaded in function section, so pass it here, just check
     * whether function and code section have inconsistent lengths */
    read_leb_uint32(p, p_end, code_count);

    if (buf_func)
        read_leb_uint32(p_func, buf_func_end, func_count);

    if (func_count != code_count) {
        set_error_buf(error_buf, error_buf_size,
                      "function and code section have inconsistent lengths");
        return false;
    }

    LOG_VERBOSE("Load code segment section success.\n");
    (void)module;
    return true;
fail:
    return false;
}

static bool
load_start_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                   char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    WASMFuncType *type;
    uint32 start_function;

    read_leb_uint32(p, p_end, start_function);

    if (start_function
        >= module->function_count + module->import_function_count) {
        set_error_buf(error_buf, error_buf_size, "unknown function");
        return false;
    }

    if (start_function < module->import_function_count)
        type = module->import_functions[start_function].u.function.func_type;
    else
        type = module->functions[start_function - module->import_function_count]
                   ->func_type;
    if (type->param_count != 0 || type->result_count != 0) {
        set_error_buf(error_buf, error_buf_size, "invalid start function");
        return false;
    }

    module->start_function = start_function;

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        return false;
    }

    LOG_VERBOSE("Load start section success.\n");
    return true;
fail:
    return false;
}

#if WASM_ENABLE_STRINGREF != 0
static bool
load_stringref_section(const uint8 *buf, const uint8 *buf_end,
                       WASMModule *module, bool is_load_from_file_buf,
                       char *error_buf, uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    int32 deferred_count, immediate_count, string_length, i;
    uint64 total_size;

    read_leb_uint32(p, p_end, deferred_count);
    read_leb_uint32(p, p_end, immediate_count);

    /* proposal set deferred_count for future extension */
    if (deferred_count != 0) {
        goto fail;
    }

    if (immediate_count > 0) {
        total_size = sizeof(char *) * (uint64)immediate_count;
        if (!(module->string_literal_ptrs =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            goto fail;
        }
        module->string_literal_count = immediate_count;

        total_size = sizeof(uint32) * (uint64)immediate_count;
        if (!(module->string_literal_lengths =
                  loader_malloc(total_size, error_buf, error_buf_size))) {
            goto fail;
        }

        for (i = 0; i < immediate_count; i++) {
            read_leb_uint32(p, p_end, string_length);

            CHECK_BUF(p, p_end, string_length);
            module->string_literal_ptrs[i] = p;
            module->string_literal_lengths[i] = string_length;
            p += string_length;
        }
    }

    if (p != p_end) {
        set_error_buf(error_buf, error_buf_size, "section size mismatch");
        goto fail;
    }

    LOG_VERBOSE("Load stringref section success.\n");
    return true;

fail:
    return false;
}
#endif /* end of WASM_ENABLE_STRINGREF != 0 */

#if WASM_ENABLE_CUSTOM_NAME_SECTION != 0
static bool
handle_name_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                    bool is_load_from_file_buf, char *error_buf,
                    uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    uint32 name_type, subsection_size;
    uint32 previous_name_type = 0;
    uint32 num_func_name;
    uint32 func_index;
    uint32 previous_func_index = ~0U;
    uint32 func_name_len;
    uint32 name_index;
    int i = 0;

    if (p >= p_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }

    while (p < p_end) {
        read_leb_uint32(p, p_end, name_type);
        if (i != 0) {
            if (name_type == previous_name_type) {
                set_error_buf(error_buf, error_buf_size,
                              "duplicate sub-section");
                return false;
            }
            if (name_type < previous_name_type) {
                set_error_buf(error_buf, error_buf_size,
                              "out-of-order sub-section");
                return false;
            }
        }
        previous_name_type = name_type;
        read_leb_uint32(p, p_end, subsection_size);
        CHECK_BUF(p, p_end, subsection_size);
        switch (name_type) {
            case SUB_SECTION_TYPE_FUNC:
                if (subsection_size) {
                    read_leb_uint32(p, p_end, num_func_name);
                    for (name_index = 0; name_index < num_func_name;
                         name_index++) {
                        read_leb_uint32(p, p_end, func_index);
                        if (func_index == previous_func_index) {
                            set_error_buf(error_buf, error_buf_size,
                                          "duplicate function name");
                            return false;
                        }
                        if (func_index < previous_func_index
                            && previous_func_index != ~0U) {
                            set_error_buf(error_buf, error_buf_size,
                                          "out-of-order function index ");
                            return false;
                        }
                        previous_func_index = func_index;
                        read_leb_uint32(p, p_end, func_name_len);
                        CHECK_BUF(p, p_end, func_name_len);
                        /* Skip the import functions */
                        if (func_index >= module->import_function_count) {
                            func_index -= module->import_function_count;
                            if (func_index >= module->function_count) {
                                set_error_buf(error_buf, error_buf_size,
                                              "out-of-range function index");
                                return false;
                            }
                            if (!(module->functions[func_index]->field_name =
                                      wasm_const_str_list_insert(
                                          p, func_name_len, module,
#if WASM_ENABLE_WAMR_COMPILER != 0
                                          false,
#else
                                          is_load_from_file_buf,
#endif
                                          error_buf, error_buf_size))) {
                                return false;
                            }
                        }
                        p += func_name_len;
                    }
                }
                break;
            case SUB_SECTION_TYPE_MODULE: /* TODO: Parse for module subsection
                                           */
            case SUB_SECTION_TYPE_LOCAL:  /* TODO: Parse for local subsection */
            default:
                p = p + subsection_size;
                break;
        }
        i++;
    }

    return true;
fail:
    return false;
}
#endif

static bool
load_user_section(const uint8 *buf, const uint8 *buf_end, WASMModule *module,
                  bool is_load_from_file_buf, char *error_buf,
                  uint32 error_buf_size)
{
    const uint8 *p = buf, *p_end = buf_end;
    char section_name[32];
    uint32 name_len, buffer_len;

    if (p >= p_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }

    read_leb_uint32(p, p_end, name_len);

    if (p + name_len > p_end) {
        set_error_buf(error_buf, error_buf_size, "unexpected end");
        return false;
    }

    if (!wasm_check_utf8_str(p, name_len)) {
        set_error_buf(error_buf, error_buf_size, "invalid UTF-8 encoding");
        return false;
    }

    buffer_len = sizeof(section_name);
    memset(section_name, 0, buffer_len);
    if (name_len < buffer_len) {
        bh_memcpy_s(section_name, buffer_len, p, name_len);
    }
    else {
        bh_memcpy_s(section_name, buffer_len, p, buffer_len - 4);
        memset(section_name + buffer_len - 4, '.', 3);
    }

#if WASM_ENABLE_CUSTOM_NAME_SECTION != 0
    if (name_len == 4 && memcmp(p, "name", 4) == 0) {
        module->name_section_buf = buf;
        module->name_section_buf_end = buf_end;
        p += name_len;
        if (!handle_name_section(p, p_end, module, is_load_from_file_buf,
                                 error_buf, error_buf_size)) {
            return false;
        }
        LOG_VERBOSE("Load custom name section success.");
    }
#endif

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
    {
        WASMCustomSection *section =
            loader_malloc(sizeof(WASMCustomSection), error_buf, error_buf_size);

        if (!section) {
            return false;
        }

        section->name_addr = (char *)p;
        section->name_len = name_len;
        section->content_addr = (uint8 *)(p + name_len);
        section->content_len = (uint32)(p_end - p - name_len);

        section->next = module->custom_section_list;
        module->custom_section_list = section;
        LOG_VERBOSE("Load custom section [%s] success.", section_name);
        return true;
    }
#endif

    LOG_VERBOSE("Ignore custom section [%s].", section_name);

    (void)is_load_from_file_buf;
    (void)module;
    return true;
fail:
    return false;
}

static void
calculate_global_data_offset(WASMModule *module)
{
    uint32 i, data_offset;

    data_offset = 0;
    for (i = 0; i < module->import_global_count; i++) {
        WASMGlobalImport *import_global =
            &((module->import_globals + i)->u.global);
#if WASM_ENABLE_FAST_JIT != 0
        import_global->data_offset = data_offset;
#endif
        data_offset += wasm_value_type_size(import_global->type.val_type);
    }

    for (i = 0; i < module->global_count; i++) {
        WASMGlobal *global = module->globals + i;
#if WASM_ENABLE_FAST_JIT != 0
        global->data_offset = data_offset;
#endif
        data_offset += wasm_value_type_size(global->type.val_type);
    }

    module->global_data_size = data_offset;
}

#if WASM_ENABLE_FAST_JIT != 0
static bool
init_fast_jit_functions(WASMModule *module, char *error_buf,
                        uint32 error_buf_size)
{
#if WASM_ENABLE_LAZY_JIT != 0
    JitGlobals *jit_globals = jit_compiler_get_jit_globals();
#endif
    uint32 i;

    if (!module->function_count)
        return true;

    if (!(module->fast_jit_func_ptrs =
              loader_malloc(sizeof(void *) * module->function_count, error_buf,
                            error_buf_size))) {
        return false;
    }

#if WASM_ENABLE_LAZY_JIT != 0
    for (i = 0; i < module->function_count; i++) {
        module->fast_jit_func_ptrs[i] =
            jit_globals->compile_fast_jit_and_then_call;
    }
#endif

    for (i = 0; i < WASM_ORC_JIT_BACKEND_THREAD_NUM; i++) {
        if (os_mutex_init(&module->fast_jit_thread_locks[i]) != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "init fast jit thread lock failed");
            return false;
        }
        module->fast_jit_thread_locks_inited[i] = true;
    }

    return true;
}
#endif /* end of WASM_ENABLE_FAST_JIT != 0 */

#if WASM_ENABLE_JIT != 0
static bool
init_llvm_jit_functions_stage1(WASMModule *module, char *error_buf,
                               uint32 error_buf_size)
{
    LLVMJITOptions *llvm_jit_options = wasm_runtime_get_llvm_jit_options();
    AOTCompOption option = { 0 };
    char *aot_last_error;
    uint64 size;
#if WASM_ENABLE_GC != 0
    bool gc_enabled = true;
#else
    bool gc_enabled = false;
#endif

    if (module->function_count == 0)
        return true;

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0
    if (os_mutex_init(&module->tierup_wait_lock) != 0) {
        set_error_buf(error_buf, error_buf_size, "init jit tierup lock failed");
        return false;
    }
    if (os_cond_init(&module->tierup_wait_cond) != 0) {
        set_error_buf(error_buf, error_buf_size, "init jit tierup cond failed");
        os_mutex_destroy(&module->tierup_wait_lock);
        return false;
    }
    module->tierup_wait_lock_inited = true;
#endif

    size = sizeof(void *) * (uint64)module->function_count
           + sizeof(bool) * (uint64)module->function_count;
    if (!(module->func_ptrs = loader_malloc(size, error_buf, error_buf_size))) {
        return false;
    }
    module->func_ptrs_compiled =
        (bool *)((uint8 *)module->func_ptrs
                 + sizeof(void *) * module->function_count);

    module->comp_data = aot_create_comp_data(module, NULL, gc_enabled);
    if (!module->comp_data) {
        aot_last_error = aot_get_last_error();
        bh_assert(aot_last_error != NULL);
        set_error_buf(error_buf, error_buf_size, aot_last_error);
        return false;
    }

    option.is_jit_mode = true;

    option.opt_level = llvm_jit_options->opt_level;
    option.size_level = llvm_jit_options->size_level;
    option.segue_flags = llvm_jit_options->segue_flags;
    option.quick_invoke_c_api_import =
        llvm_jit_options->quick_invoke_c_api_import;

#if WASM_ENABLE_BULK_MEMORY != 0
    option.enable_bulk_memory = true;
#endif
#if WASM_ENABLE_THREAD_MGR != 0
    option.enable_thread_mgr = true;
#endif
#if WASM_ENABLE_TAIL_CALL != 0
    option.enable_tail_call = true;
#endif
#if WASM_ENABLE_SIMD != 0
    option.enable_simd = true;
#endif
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    option.enable_ref_types = true;
#elif WASM_ENABLE_GC != 0
    option.enable_gc = true;
#endif
    option.enable_aux_stack_check = true;
#if WASM_ENABLE_PERF_PROFILING != 0 || WASM_ENABLE_DUMP_CALL_STACK != 0 \
    || WASM_ENABLE_AOT_STACK_FRAME != 0
    option.aux_stack_frame_type = AOT_STACK_FRAME_TYPE_STANDARD;
    aot_call_stack_features_init_default(&option.call_stack_features);
#endif
#if WASM_ENABLE_PERF_PROFILING != 0
    option.enable_perf_profiling = true;
#endif
#if WASM_ENABLE_MEMORY_PROFILING != 0
    option.enable_memory_profiling = true;
    option.enable_stack_estimation = true;
#endif
#if WASM_ENABLE_SHARED_HEAP != 0
    option.enable_shared_heap = true;
#endif

    module->comp_ctx = aot_create_comp_context(module->comp_data, &option);
    if (!module->comp_ctx) {
        aot_last_error = aot_get_last_error();
        bh_assert(aot_last_error != NULL);
        set_error_buf(error_buf, error_buf_size, aot_last_error);
        return false;
    }

    return true;
}

static bool
init_llvm_jit_functions_stage2(WASMModule *module, char *error_buf,
                               uint32 error_buf_size)
{
    char *aot_last_error;
    uint32 i;

    if (module->function_count == 0)
        return true;

    if (!aot_compile_wasm(module->comp_ctx)) {
        aot_last_error = aot_get_last_error();
        bh_assert(aot_last_error != NULL);
        set_error_buf(error_buf, error_buf_size, aot_last_error);
        return false;
    }

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0
    if (module->orcjit_stop_compiling)
        return false;
#endif

    bh_print_time("Begin to lookup llvm jit functions");

    for (i = 0; i < module->function_count; i++) {
        LLVMOrcJITTargetAddress func_addr = 0;
        LLVMErrorRef error;
        char func_name[48];

        snprintf(func_name, sizeof(func_name), "%s%d", AOT_FUNC_PREFIX, i);
        error = LLVMOrcLLLazyJITLookup(module->comp_ctx->orc_jit, &func_addr,
                                       func_name);
        if (error != LLVMErrorSuccess) {
            char *err_msg = LLVMGetErrorMessage(error);
            set_error_buf_v(error_buf, error_buf_size,
                            "failed to compile llvm jit function: %s", err_msg);
            LLVMDisposeErrorMessage(err_msg);
            return false;
        }

        /**
         * No need to lock the func_ptr[func_idx] here as it is basic
         * data type, the load/store for it can be finished by one cpu
         * instruction, and there can be only one cpu instruction
         * loading/storing at the same time.
         */
        module->func_ptrs[i] = (void *)func_addr;

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0
        module->functions[i]->llvm_jit_func_ptr = (void *)func_addr;

        if (module->orcjit_stop_compiling)
            return false;
#endif
    }

    bh_print_time("End lookup llvm jit functions");

    return true;
}
#endif /* end of WASM_ENABLE_JIT != 0 */

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
static void *
init_llvm_jit_functions_stage2_callback(void *arg)
{
    WASMModule *module = (WASMModule *)arg;
    char error_buf[128];
    uint32 error_buf_size = (uint32)sizeof(error_buf);

    if (!init_llvm_jit_functions_stage2(module, error_buf, error_buf_size)) {
        module->orcjit_stop_compiling = true;
        return NULL;
    }

    os_mutex_lock(&module->tierup_wait_lock);
    module->llvm_jit_inited = true;
    os_cond_broadcast(&module->tierup_wait_cond);
    os_mutex_unlock(&module->tierup_wait_lock);

    return NULL;
}
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
/* The callback function to compile jit functions */
static void *
orcjit_thread_callback(void *arg)
{
    OrcJitThreadArg *thread_arg = (OrcJitThreadArg *)arg;
#if WASM_ENABLE_JIT != 0
    AOTCompContext *comp_ctx = thread_arg->comp_ctx;
#endif
    WASMModule *module = thread_arg->module;
    uint32 group_idx = thread_arg->group_idx;
    uint32 group_stride = WASM_ORC_JIT_BACKEND_THREAD_NUM;
    uint32 func_count = module->function_count;
    uint32 i;

#if WASM_ENABLE_FAST_JIT != 0
    /* Compile fast jit functions of this group */
    for (i = group_idx; i < func_count; i += group_stride) {
        if (!jit_compiler_compile(module, i + module->import_function_count)) {
            LOG_ERROR("failed to compile fast jit function %u\n", i);
            break;
        }

        if (module->orcjit_stop_compiling) {
            return NULL;
        }
    }
#if WASM_ENABLE_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0
    os_mutex_lock(&module->tierup_wait_lock);
    module->fast_jit_ready_groups++;
    os_mutex_unlock(&module->tierup_wait_lock);
#endif
#endif

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    /* For JIT tier-up, set each llvm jit func to call_to_fast_jit */
    for (i = group_idx; i < func_count;
         i += group_stride * WASM_ORC_JIT_COMPILE_THREAD_NUM) {
        uint32 j;

        for (j = 0; j < WASM_ORC_JIT_COMPILE_THREAD_NUM; j++) {
            if (i + j * group_stride < func_count) {
                if (!jit_compiler_set_call_to_fast_jit(
                        module,
                        i + j * group_stride + module->import_function_count)) {
                    LOG_ERROR(
                        "failed to compile call_to_fast_jit for func %u\n",
                        i + j * group_stride + module->import_function_count);
                    module->orcjit_stop_compiling = true;
                    return NULL;
                }
            }
            if (module->orcjit_stop_compiling) {
                return NULL;
            }
        }
    }

    /* Wait until init_llvm_jit_functions_stage2 finishes and all
       fast jit functions are compiled */
    os_mutex_lock(&module->tierup_wait_lock);
    while (!(module->llvm_jit_inited && module->enable_llvm_jit_compilation
             && module->fast_jit_ready_groups >= group_stride)) {
        os_cond_reltimedwait(&module->tierup_wait_cond,
                             &module->tierup_wait_lock, 10000);
        if (module->orcjit_stop_compiling) {
            /* init_llvm_jit_functions_stage2 failed */
            os_mutex_unlock(&module->tierup_wait_lock);
            return NULL;
        }
    }
    os_mutex_unlock(&module->tierup_wait_lock);
#endif

#if WASM_ENABLE_JIT != 0
    /* Compile llvm jit functions of this group */
    for (i = group_idx; i < func_count;
         i += group_stride * WASM_ORC_JIT_COMPILE_THREAD_NUM) {
        LLVMOrcJITTargetAddress func_addr = 0;
        LLVMErrorRef error;
        char func_name[48];
        typedef void (*F)(void);
        union {
            F f;
            void *v;
        } u;
        uint32 j;

        snprintf(func_name, sizeof(func_name), "%s%d%s", AOT_FUNC_PREFIX, i,
                 "_wrapper");
        LOG_DEBUG("compile llvm jit func %s", func_name);
        error =
            LLVMOrcLLLazyJITLookup(comp_ctx->orc_jit, &func_addr, func_name);
        if (error != LLVMErrorSuccess) {
            char *err_msg = LLVMGetErrorMessage(error);
            LOG_ERROR("failed to compile llvm jit function %u: %s", i, err_msg);
            LLVMDisposeErrorMessage(err_msg);
            break;
        }

        /* Call the jit wrapper function to trigger its compilation, so as
           to compile the actual jit functions, since we add the latter to
           function list in the PartitionFunction callback */
        u.v = (void *)func_addr;
        u.f();

        for (j = 0; j < WASM_ORC_JIT_COMPILE_THREAD_NUM; j++) {
            if (i + j * group_stride < func_count) {
                module->func_ptrs_compiled[i + j * group_stride] = true;
#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0
                snprintf(func_name, sizeof(func_name), "%s%d", AOT_FUNC_PREFIX,
                         i + j * group_stride);
                error = LLVMOrcLLLazyJITLookup(comp_ctx->orc_jit, &func_addr,
                                               func_name);
                if (error != LLVMErrorSuccess) {
                    char *err_msg = LLVMGetErrorMessage(error);
                    LOG_ERROR("failed to compile llvm jit function %u: %s", i,
                              err_msg);
                    LLVMDisposeErrorMessage(err_msg);
                    /* Ignore current llvm jit func, as its func ptr is
                       previous set to call_to_fast_jit, which also works */
                    continue;
                }

                jit_compiler_set_llvm_jit_func_ptr(
                    module,
                    i + j * group_stride + module->import_function_count,
                    (void *)func_addr);

                /* Try to switch to call this llvm jit function instead of
                   fast jit function from fast jit jitted code */
                jit_compiler_set_call_to_llvm_jit(
                    module,
                    i + j * group_stride + module->import_function_count);
#endif
            }
        }

        if (module->orcjit_stop_compiling) {
            break;
        }
    }
#endif

    return NULL;
}

static void
orcjit_stop_compile_threads(WASMModule *module)
{
#if WASM_ENABLE_LAZY_JIT != 0
    uint32 i, thread_num = (uint32)(sizeof(module->orcjit_thread_args)
                                    / sizeof(OrcJitThreadArg));

    module->orcjit_stop_compiling = true;
    for (i = 0; i < thread_num; i++) {
        if (module->orcjit_threads[i])
            os_thread_join(module->orcjit_threads[i], NULL);
    }
#endif
}

static bool
compile_jit_functions(WASMModule *module, char *error_buf,
                      uint32 error_buf_size)
{
    uint32 thread_num =
        (uint32)(sizeof(module->orcjit_thread_args) / sizeof(OrcJitThreadArg));
    uint32 i, j;

    bh_print_time("Begin to compile jit functions");

    /* Create threads to compile the jit functions */
    for (i = 0; i < thread_num && i < module->function_count; i++) {
#if WASM_ENABLE_JIT != 0
        module->orcjit_thread_args[i].comp_ctx = module->comp_ctx;
#endif
        module->orcjit_thread_args[i].module = module;
        module->orcjit_thread_args[i].group_idx = i;

        if (os_thread_create(&module->orcjit_threads[i], orcjit_thread_callback,
                             (void *)&module->orcjit_thread_args[i],
                             APP_THREAD_STACK_SIZE_DEFAULT)
            != 0) {
            set_error_buf(error_buf, error_buf_size,
                          "create orcjit compile thread failed");
            /* Terminate the threads created */
            module->orcjit_stop_compiling = true;
            for (j = 0; j < i; j++) {
                os_thread_join(module->orcjit_threads[j], NULL);
            }
            return false;
        }
    }

#if WASM_ENABLE_LAZY_JIT == 0
    /* Wait until all jit functions are compiled for eager mode */
    for (i = 0; i < thread_num; i++) {
        if (module->orcjit_threads[i])
            os_thread_join(module->orcjit_threads[i], NULL);
    }

#if WASM_ENABLE_FAST_JIT != 0
    /* Ensure all the fast-jit functions are compiled */
    for (i = 0; i < module->function_count; i++) {
        if (!jit_compiler_is_compiled(module,
                                      i + module->import_function_count)) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to compile fast jit function");
            return false;
        }
    }
#endif

#if WASM_ENABLE_JIT != 0
    /* Ensure all the llvm-jit functions are compiled */
    for (i = 0; i < module->function_count; i++) {
        if (!module->func_ptrs_compiled[i]) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to compile llvm jit function");
            return false;
        }
    }
#endif
#endif /* end of WASM_ENABLE_LAZY_JIT == 0 */

    bh_print_time("End compile jit functions");

    return true;
}
#endif /* end of WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 */

static bool
wasm_loader_prepare_bytecode(WASMModule *module, WASMFunction *func,
                             uint32 cur_func_idx, char *error_buf,
                             uint32 error_buf_size);

#if WASM_ENABLE_FAST_INTERP != 0 && WASM_ENABLE_LABELS_AS_VALUES != 0
void **
wasm_interp_get_handle_table(void);

static void **handle_table;
#endif

static bool
load_from_sections(WASMModule *module, WASMSection *sections,
                   bool is_load_from_file_buf, bool wasm_binary_freeable,
                   bool no_resolve, char *error_buf, uint32 error_buf_size)
{
    WASMExport *export;
    WASMSection *section = sections;
    const uint8 *buf, *buf_end, *buf_code = NULL, *buf_code_end = NULL,
                                *buf_func = NULL, *buf_func_end = NULL;
    WASMGlobal *aux_data_end_global = NULL, *aux_heap_base_global = NULL;
    WASMGlobal *aux_stack_top_global = NULL, *global;
    uint64 aux_data_end = (uint64)-1LL, aux_heap_base = (uint64)-1LL,
           aux_stack_top = (uint64)-1LL;
    uint32 global_index, func_index, i;
    uint32 aux_data_end_global_index = (uint32)-1;
    uint32 aux_heap_base_global_index = (uint32)-1;
    WASMFuncType *func_type;
    uint8 malloc_free_io_type = VALUE_TYPE_I32;
    bool reuse_const_strings = is_load_from_file_buf && !wasm_binary_freeable;
    bool clone_data_seg = is_load_from_file_buf && wasm_binary_freeable;
#if WASM_ENABLE_BULK_MEMORY != 0
    bool has_datacount_section = false;
#endif

    /* Find code and function sections if have */
    while (section) {
        if (section->section_type == SECTION_TYPE_CODE) {
            buf_code = section->section_body;
            buf_code_end = buf_code + section->section_body_size;
#if WASM_ENABLE_DEBUG_INTERP != 0 || WASM_ENABLE_DEBUG_AOT != 0
            module->buf_code = (uint8 *)buf_code;
            module->buf_code_size = section->section_body_size;
#endif
        }
        else if (section->section_type == SECTION_TYPE_FUNC) {
            buf_func = section->section_body;
            buf_func_end = buf_func + section->section_body_size;
        }
        section = section->next;
    }

    section = sections;
    while (section) {
        buf = section->section_body;
        buf_end = buf + section->section_body_size;
        switch (section->section_type) {
            case SECTION_TYPE_USER:
                /* unsupported user section, ignore it. */
                if (!load_user_section(buf, buf_end, module,
                                       reuse_const_strings, error_buf,
                                       error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_TYPE:
                if (!load_type_section(buf, buf_end, module, error_buf,
                                       error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_IMPORT:
                if (!load_import_section(buf, buf_end, module,
                                         reuse_const_strings, no_resolve,
                                         error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_FUNC:
                if (!load_function_section(buf, buf_end, buf_code, buf_code_end,
                                           module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_TABLE:
                if (!load_table_section(buf, buf_end, module, error_buf,
                                        error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_MEMORY:
                if (!load_memory_section(buf, buf_end, module, error_buf,
                                         error_buf_size))
                    return false;
                break;
#if WASM_ENABLE_TAGS != 0
            case SECTION_TYPE_TAG:
                /* load tag declaration section */
                if (!load_tag_section(buf, buf_end, buf_code, buf_code_end,
                                      module, error_buf, error_buf_size))
                    return false;
                break;
#endif
            case SECTION_TYPE_GLOBAL:
                if (!load_global_section(buf, buf_end, module, error_buf,
                                         error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_EXPORT:
                if (!load_export_section(buf, buf_end, module,
                                         reuse_const_strings, error_buf,
                                         error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_START:
                if (!load_start_section(buf, buf_end, module, error_buf,
                                        error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_ELEM:
                if (!load_table_segment_section(buf, buf_end, module, error_buf,
                                                error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_CODE:
                if (!load_code_section(buf, buf_end, buf_func, buf_func_end,
                                       module, error_buf, error_buf_size))
                    return false;
                break;
            case SECTION_TYPE_DATA:
                if (!load_data_segment_section(buf, buf_end, module,
#if WASM_ENABLE_BULK_MEMORY != 0
                                               has_datacount_section,
#endif
                                               clone_data_seg, error_buf,
                                               error_buf_size))
                    return false;
                break;
#if WASM_ENABLE_BULK_MEMORY != 0
            case SECTION_TYPE_DATACOUNT:
                if (!load_datacount_section(buf, buf_end, module, error_buf,
                                            error_buf_size))
                    return false;
                has_datacount_section = true;
                break;
#endif
#if WASM_ENABLE_STRINGREF != 0
            case SECTION_TYPE_STRINGREF:
                if (!load_stringref_section(buf, buf_end, module,
                                            reuse_const_strings, error_buf,
                                            error_buf_size))
                    return false;
                break;
#endif
            default:
                set_error_buf(error_buf, error_buf_size, "invalid section id");
                return false;
        }

        section = section->next;
    }

#if WASM_ENABLE_BULK_MEMORY != 0
    if (!check_data_count_consistency(
            has_datacount_section, module->data_seg_count1,
            module->data_seg_count, error_buf, error_buf_size)) {
        return false;
    }
#endif

    module->aux_data_end_global_index = (uint32)-1;
    module->aux_heap_base_global_index = (uint32)-1;
    module->aux_stack_top_global_index = (uint32)-1;

    /* Resolve auxiliary data/stack/heap info and reset memory info */
    export = module->exports;
    for (i = 0; i < module->export_count; i++, export ++) {
        if (export->kind == EXPORT_KIND_GLOBAL) {
            if (!strcmp(export->name, "__heap_base")) {
                if (export->index < module->import_global_count) {
                    LOG_DEBUG("Skip the process if __heap_base is imported "
                              "instead of being a local global");
                    continue;
                }

                /* only process linker-generated symbols */
                global_index = export->index - module->import_global_count;
                global = module->globals + global_index;
                if (global->type.val_type == VALUE_TYPE_I32
                    && !global->type.is_mutable
                    && global->init_expr.init_expr_type
                           == INIT_EXPR_TYPE_I32_CONST) {
                    aux_heap_base_global = global;
                    aux_heap_base =
                        (uint64)(uint32)global->init_expr.u.unary.v.i32;
                    aux_heap_base_global_index = export->index;
                    LOG_VERBOSE("Found aux __heap_base global, value: %" PRIu64,
                                aux_heap_base);
                }
            }
            else if (!strcmp(export->name, "__data_end")) {
                if (export->index < module->import_global_count) {
                    LOG_DEBUG("Skip the process if __data_end is imported "
                              "instead of being a local global");
                    continue;
                }

                /* only process linker-generated symbols */
                global_index = export->index - module->import_global_count;
                global = module->globals + global_index;
                if (global->type.val_type == VALUE_TYPE_I32
                    && !global->type.is_mutable
                    && global->init_expr.init_expr_type
                           == INIT_EXPR_TYPE_I32_CONST) {
                    aux_data_end_global = global;
                    aux_data_end =
                        (uint64)(uint32)global->init_expr.u.unary.v.i32;
                    aux_data_end_global_index = export->index;
                    LOG_VERBOSE("Found aux __data_end global, value: %" PRIu64,
                                aux_data_end);

                    aux_data_end = align_uint64(aux_data_end, 16);
                }
            }

            /* For module compiled with -pthread option, the global is:
                [0] stack_top       <-- 0
                [1] tls_pointer
                [2] tls_size
                [3] data_end        <-- 3
                [4] global_base
                [5] heap_base       <-- 5
                [6] dso_handle

                For module compiled without -pthread option:
                [0] stack_top       <-- 0
                [1] data_end        <-- 1
                [2] global_base
                [3] heap_base       <-- 3
                [4] dso_handle
            */
            if (aux_data_end_global && aux_heap_base_global
                && aux_data_end <= aux_heap_base) {
                module->aux_data_end_global_index = aux_data_end_global_index;
                module->aux_data_end = aux_data_end;
                module->aux_heap_base_global_index = aux_heap_base_global_index;
                module->aux_heap_base = aux_heap_base;

                /* Resolve aux stack top global */
                for (global_index = 0; global_index < module->global_count;
                     global_index++) {
                    global = module->globals + global_index;
                    if (global->type.is_mutable /* heap_base and data_end is
                                              not mutable */
                        && global->type.val_type == VALUE_TYPE_I32
                        && global->init_expr.init_expr_type
                               == INIT_EXPR_TYPE_I32_CONST
                        && (uint64)(uint32)global->init_expr.u.unary.v.i32
                               <= aux_heap_base) {
                        aux_stack_top_global = global;
                        aux_stack_top =
                            (uint64)(uint32)global->init_expr.u.unary.v.i32;
                        module->aux_stack_top_global_index =
                            module->import_global_count + global_index;
                        module->aux_stack_bottom = aux_stack_top;
                        module->aux_stack_size =
                            aux_stack_top > aux_data_end
                                ? (uint32)(aux_stack_top - aux_data_end)
                                : (uint32)aux_stack_top;
                        LOG_VERBOSE(
                            "Found aux stack top global, value: %" PRIu64 ", "
                            "global index: %d, stack size: %d",
                            aux_stack_top, global_index,
                            module->aux_stack_size);
                        break;
                    }
                }
                if (!aux_stack_top_global) {
                    /* Auxiliary stack global isn't found, it must be unused
                       in the wasm app, as if it is used, the global must be
                       defined. Here we set it to __heap_base global and set
                       its size to 0. */
                    aux_stack_top_global = aux_heap_base_global;
                    aux_stack_top = aux_heap_base;
                    module->aux_stack_top_global_index =
                        module->aux_heap_base_global_index;
                    module->aux_stack_bottom = aux_stack_top;
                    module->aux_stack_size = 0;
                }
                break;
            }
        }
    }

    module->malloc_function = (uint32)-1;
    module->free_function = (uint32)-1;
    module->retain_function = (uint32)-1;

    /* Resolve malloc/free function exported by wasm module */
#if WASM_ENABLE_MEMORY64 != 0
    if (has_module_memory64(module))
        malloc_free_io_type = VALUE_TYPE_I64;
#endif
    export = module->exports;
    for (i = 0; i < module->export_count; i++, export ++) {
        if (export->kind == EXPORT_KIND_FUNC) {
            if (!strcmp(export->name, "malloc")
                && export->index >= module->import_function_count) {
                func_index = export->index - module->import_function_count;
                func_type = module->functions[func_index]->func_type;
                if (func_type->param_count == 1 && func_type->result_count == 1
                    && func_type->types[0] == malloc_free_io_type
                    && func_type->types[1] == malloc_free_io_type) {
                    bh_assert(module->malloc_function == (uint32)-1);
                    module->malloc_function = export->index;
                    LOG_VERBOSE("Found malloc function, name: %s, index: %u",
                                export->name, export->index);
                }
            }
            else if (!strcmp(export->name, "__new")
                     && export->index >= module->import_function_count) {
                /* __new && __pin for AssemblyScript */
                func_index = export->index - module->import_function_count;
                func_type = module->functions[func_index]->func_type;
                if (func_type->param_count == 2 && func_type->result_count == 1
                    && func_type->types[0] == malloc_free_io_type
                    && func_type->types[1] == VALUE_TYPE_I32
                    && func_type->types[2] == malloc_free_io_type) {
                    uint32 j;
                    WASMExport *export_tmp;

                    bh_assert(module->malloc_function == (uint32)-1);
                    module->malloc_function = export->index;
                    LOG_VERBOSE("Found malloc function, name: %s, index: %u",
                                export->name, export->index);

                    /* resolve retain function.
                       If not found, reset malloc function index */
                    export_tmp = module->exports;
                    for (j = 0; j < module->export_count; j++, export_tmp++) {
                        if ((export_tmp->kind == EXPORT_KIND_FUNC)
                            && (!strcmp(export_tmp->name, "__retain")
                                || (!strcmp(export_tmp->name, "__pin")))
                            && (export_tmp->index
                                >= module->import_function_count)) {
                            func_index = export_tmp->index
                                         - module->import_function_count;
                            func_type =
                                module->functions[func_index]->func_type;
                            if (func_type->param_count == 1
                                && func_type->result_count == 1
                                && func_type->types[0] == malloc_free_io_type
                                && func_type->types[1] == malloc_free_io_type) {
                                bh_assert(module->retain_function
                                          == (uint32)-1);
                                module->retain_function = export_tmp->index;
                                LOG_VERBOSE("Found retain function, name: %s, "
                                            "index: %u",
                                            export_tmp->name,
                                            export_tmp->index);
                                break;
                            }
                        }
                    }
                    if (j == module->export_count) {
                        module->malloc_function = (uint32)-1;
                        LOG_VERBOSE("Can't find retain function,"
                                    "reset malloc function index to -1");
                    }
                }
            }
            else if (((!strcmp(export->name, "free"))
                      || (!strcmp(export->name, "__release"))
                      || (!strcmp(export->name, "__unpin")))
                     && export->index >= module->import_function_count) {
                func_index = export->index - module->import_function_count;
                func_type = module->functions[func_index]->func_type;
                if (func_type->param_count == 1 && func_type->result_count == 0
                    && func_type->types[0] == malloc_free_io_type) {
                    bh_assert(module->free_function == (uint32)-1);
                    module->free_function = export->index;
                    LOG_VERBOSE("Found free function, name: %s, index: %u",
                                export->name, export->index);
                }
            }
        }
    }

#if WASM_ENABLE_FAST_INTERP != 0 && WASM_ENABLE_LABELS_AS_VALUES != 0
    handle_table = wasm_interp_get_handle_table();
#endif

    for (i = 0; i < module->function_count; i++) {
        WASMFunction *func = module->functions[i];
        if (!wasm_loader_prepare_bytecode(module, func, i, error_buf,
                                          error_buf_size)) {
            return false;
        }

        if (i == module->function_count - 1
            && func->code + func->code_size != buf_code_end) {
            set_error_buf(error_buf, error_buf_size,
                          "code section size mismatch");
            return false;
        }
    }

    if (!module->possible_memory_grow) {
#if WASM_ENABLE_SHRUNK_MEMORY != 0
        if (aux_data_end_global && aux_heap_base_global
            && aux_stack_top_global) {
            uint64 init_memory_size;
            uint64 shrunk_memory_size = align_uint64(aux_heap_base, 8);

            /* Only resize(shrunk) the memory size if num_bytes_per_page is in
             * valid range of uint32 */
            if (shrunk_memory_size <= UINT32_MAX) {
                if (module->import_memory_count) {
                    WASMMemoryImport *memory_import =
                        &module->import_memories[0].u.memory;
                    init_memory_size =
                        (uint64)memory_import->mem_type.num_bytes_per_page
                        * memory_import->mem_type.init_page_count;
                    if (shrunk_memory_size <= init_memory_size) {
                        /* Reset memory info to decrease memory usage */
                        memory_import->mem_type.num_bytes_per_page =
                            (uint32)shrunk_memory_size;
                        memory_import->mem_type.init_page_count = 1;
                        LOG_VERBOSE("Shrink import memory size to %" PRIu64,
                                    shrunk_memory_size);
                    }
                }

                if (module->memory_count) {
                    WASMMemory *memory = &module->memories[0];
                    init_memory_size = (uint64)memory->num_bytes_per_page
                                       * memory->init_page_count;
                    if (shrunk_memory_size <= init_memory_size) {
                        /* Reset memory info to decrease memory usage */
                        memory->num_bytes_per_page = (uint32)shrunk_memory_size;
                        memory->init_page_count = 1;
                        LOG_VERBOSE("Shrink memory size to %" PRIu64,
                                    shrunk_memory_size);
                    }
                }
            }
        }
#endif /* WASM_ENABLE_SHRUNK_MEMORY != 0 */

#if WASM_ENABLE_MULTI_MODULE == 0
        if (module->import_memory_count) {
            WASMMemoryImport *memory_import =
                &module->import_memories[0].u.memory;
            /* Only resize the memory to one big page if num_bytes_per_page is
             * in valid range of uint32 */
            if (memory_import->mem_type.init_page_count < DEFAULT_MAX_PAGES) {
                memory_import->mem_type.num_bytes_per_page *=
                    memory_import->mem_type.init_page_count;

                if (memory_import->mem_type.init_page_count > 0)
                    memory_import->mem_type.init_page_count =
                        memory_import->mem_type.max_page_count = 1;
                else
                    memory_import->mem_type.init_page_count =
                        memory_import->mem_type.max_page_count = 0;
            }
        }
        if (module->memory_count) {
            WASMMemory *memory = &module->memories[0];
            /* Only resize(shrunk) the memory size if num_bytes_per_page is in
             * valid range of uint32 */
            if (memory->init_page_count < DEFAULT_MAX_PAGES) {
                memory->num_bytes_per_page *= memory->init_page_count;
                if (memory->init_page_count > 0)
                    memory->init_page_count = memory->max_page_count = 1;
                else
                    memory->init_page_count = memory->max_page_count = 0;
            }
        }
#endif
    }

#if WASM_ENABLE_MEMORY64 != 0
    if (!check_memory64_flags_consistency(module, error_buf, error_buf_size,
                                          false))
        return false;
#endif

    calculate_global_data_offset(module);

#if WASM_ENABLE_FAST_JIT != 0
    if (!init_fast_jit_functions(module, error_buf, error_buf_size)) {
        return false;
    }
#endif

#if WASM_ENABLE_JIT != 0
    if (!init_llvm_jit_functions_stage1(module, error_buf, error_buf_size)) {
        return false;
    }
#if !(WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0)
    if (!init_llvm_jit_functions_stage2(module, error_buf, error_buf_size)) {
        return false;
    }
#else
    /* Run aot_compile_wasm in a backend thread, so as not to block the main
       thread fast jit execution, since applying llvm optimizations in
       aot_compile_wasm may cost a lot of time.
       Create thread with enough native stack to apply llvm optimizations */
    if (os_thread_create(&module->llvm_jit_init_thread,
                         init_llvm_jit_functions_stage2_callback,
                         (void *)module, APP_THREAD_STACK_SIZE_DEFAULT * 8)
        != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "create orcjit compile thread failed");
        return false;
    }
#endif
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
    /* Create threads to compile the jit functions */
    if (!compile_jit_functions(module, error_buf, error_buf_size)) {
        return false;
    }
#endif

#if WASM_ENABLE_MEMORY_TRACING != 0
    wasm_runtime_dump_module_mem_consumption((WASMModuleCommon *)module);
#endif
    return true;
}

static WASMModule *
create_module(char *name, char *error_buf, uint32 error_buf_size)
{
    WASMModule *module =
        loader_malloc(sizeof(WASMModule), error_buf, error_buf_size);
    bh_list_status ret;

    if (!module) {
        return NULL;
    }

    module->module_type = Wasm_Module_Bytecode;

    /* Set start_function to -1, means no start function */
    module->start_function = (uint32)-1;

    module->name = name;
    module->is_binary_freeable = false;

#if WASM_ENABLE_FAST_INTERP == 0
    module->br_table_cache_list = &module->br_table_cache_list_head;
    ret = bh_list_init(module->br_table_cache_list);
    bh_assert(ret == BH_LIST_SUCCESS);
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
    module->import_module_list = &module->import_module_list_head;
    ret = bh_list_init(module->import_module_list);
    bh_assert(ret == BH_LIST_SUCCESS);
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0
    ret = bh_list_init(&module->fast_opcode_list);
    bh_assert(ret == BH_LIST_SUCCESS);
#endif

#if WASM_ENABLE_GC != 0
    if (!(module->ref_type_set =
              wasm_reftype_set_create(GC_REFTYPE_MAP_SIZE_DEFAULT))) {
        set_error_buf(error_buf, error_buf_size, "create reftype map failed");
        goto fail1;
    }

    if (os_mutex_init(&module->rtt_type_lock)) {
        set_error_buf(error_buf, error_buf_size, "init rtt type lock failed");
        goto fail2;
    }
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0                         \
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
        && WASM_ENABLE_LAZY_JIT != 0)
    if (os_mutex_init(&module->instance_list_lock) != 0) {
        set_error_buf(error_buf, error_buf_size,
                      "init instance list lock failed");
        goto fail3;
    }
#endif

#if WASM_ENABLE_LIBC_WASI != 0
#if WASM_ENABLE_UVWASI == 0
    module->wasi_args.stdio[0] = os_invalid_raw_handle();
    module->wasi_args.stdio[1] = os_invalid_raw_handle();
    module->wasi_args.stdio[2] = os_invalid_raw_handle();
#else
    module->wasi_args.stdio[0] = os_get_invalid_handle();
    module->wasi_args.stdio[1] = os_get_invalid_handle();
    module->wasi_args.stdio[2] = os_get_invalid_handle();
#endif /* WASM_ENABLE_UVWASI == 0 */
#endif /* WASM_ENABLE_LIBC_WASI != 0 */

    (void)ret;
    return module;

#if WASM_ENABLE_DEBUG_INTERP != 0                    \
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT \
        && WASM_ENABLE_LAZY_JIT != 0)
fail3:
#endif
#if WASM_ENABLE_GC != 0
    os_mutex_destroy(&module->rtt_type_lock);
fail2:
    bh_hash_map_destroy(module->ref_type_set);
fail1:
#endif
    wasm_runtime_free(module);
    return NULL;
}

#if WASM_ENABLE_DEBUG_INTERP != 0
static bool
record_fast_op(WASMModule *module, uint8 *pos, uint8 orig_op, char *error_buf,
               uint32 error_buf_size)
{
    WASMFastOPCodeNode *fast_op =
        loader_malloc(sizeof(WASMFastOPCodeNode), error_buf, error_buf_size);
    if (fast_op) {
        fast_op->offset = pos - module->load_addr;
        fast_op->orig_op = orig_op;
        bh_list_insert(&module->fast_opcode_list, fast_op);
    }
    return fast_op ? true : false;
}
#endif

WASMModule *
wasm_loader_load_from_sections(WASMSection *section_list, char *error_buf,
                               uint32 error_buf_size)
{
    WASMModule *module = create_module("", error_buf, error_buf_size);
    if (!module)
        return NULL;

    if (!load_from_sections(module, section_list, false, true, false, error_buf,
                            error_buf_size)) {
        wasm_loader_unload(module);
        return NULL;
    }

    LOG_VERBOSE("Load module from sections success.\n");
    return module;
}

static void
destroy_sections(WASMSection *section_list)
{
    WASMSection *section = section_list, *next;
    while (section) {
        next = section->next;
        wasm_runtime_free(section);
        section = next;
    }
}

/* clang-format off */
static uint8 section_ids[] = {
    SECTION_TYPE_USER,
    SECTION_TYPE_TYPE,
    SECTION_TYPE_IMPORT,
    SECTION_TYPE_FUNC,
    SECTION_TYPE_TABLE,
    SECTION_TYPE_MEMORY,
#if WASM_ENABLE_TAGS != 0
    SECTION_TYPE_TAG,
#endif
#if WASM_ENABLE_STRINGREF != 0
    /* must immediately precede the global section,
       or where the global section would be */
    SECTION_TYPE_STRINGREF,
#endif
    SECTION_TYPE_GLOBAL,
    SECTION_TYPE_EXPORT,
    SECTION_TYPE_START,
    SECTION_TYPE_ELEM,
#if WASM_ENABLE_BULK_MEMORY != 0
    SECTION_TYPE_DATACOUNT,
#endif
    SECTION_TYPE_CODE,
    SECTION_TYPE_DATA
};
/* clang-format on */

static uint8
get_section_index(uint8 section_type)
{
    uint8 max_id = sizeof(section_ids) / sizeof(uint8);

    for (uint8 i = 0; i < max_id; i++) {
        if (section_type == section_ids[i])
            return i;
    }

    return (uint8)-1;
}

static bool
create_sections(const uint8 *buf, uint32 size, WASMSection **p_section_list,
                char *error_buf, uint32 error_buf_size)
{
    WASMSection *section_list_end = NULL, *section;
    const uint8 *p = buf, *p_end = buf + size;
    uint8 section_type, section_index, last_section_index = (uint8)-1;
    uint32 section_size;

    bh_assert(!*p_section_list);

    p += 8;
    while (p < p_end) {
        CHECK_BUF(p, p_end, 1);
        section_type = read_uint8(p);
        section_index = get_section_index(section_type);
        if (section_index != (uint8)-1) {
            if (section_type != SECTION_TYPE_USER) {
                /* Custom sections may be inserted at any place,
                   while other sections must occur at most once
                   and in prescribed order. */
                if (last_section_index != (uint8)-1
                    && (section_index <= last_section_index)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "unexpected content after last section or "
                                  "junk after last section");
                    return false;
                }
                last_section_index = section_index;
            }
            read_leb_uint32(p, p_end, section_size);
            CHECK_BUF1(p, p_end, section_size);

            if (!(section = loader_malloc(sizeof(WASMSection), error_buf,
                                          error_buf_size))) {
                return false;
            }

            section->section_type = section_type;
            section->section_body = (uint8 *)p;
            section->section_body_size = section_size;

            if (!section_list_end)
                *p_section_list = section_list_end = section;
            else {
                section_list_end->next = section;
                section_list_end = section;
            }

            p += section_size;
        }
        else {
            set_error_buf(error_buf, error_buf_size, "invalid section id");
            return false;
        }
    }

    return true;
fail:
    return false;
}

static void
exchange32(uint8 *p_data)
{
    uint8 value = *p_data;
    *p_data = *(p_data + 3);
    *(p_data + 3) = value;

    value = *(p_data + 1);
    *(p_data + 1) = *(p_data + 2);
    *(p_data + 2) = value;
}

static union {
    int a;
    char b;
} __ue = { .a = 1 };

#define is_little_endian() (__ue.b == 1)

static bool
load(const uint8 *buf, uint32 size, WASMModule *module,
     bool wasm_binary_freeable, bool no_resolve, char *error_buf,
     uint32 error_buf_size)
{
    const uint8 *buf_end = buf + size;
    const uint8 *p = buf, *p_end = buf_end;
    uint32 magic_number, version;
    WASMSection *section_list = NULL;

    CHECK_BUF1(p, p_end, sizeof(uint32));
    magic_number = read_uint32(p);
    if (!is_little_endian())
        exchange32((uint8 *)&magic_number);

    if (magic_number != WASM_MAGIC_NUMBER) {
        set_error_buf(error_buf, error_buf_size, "magic header not detected");
        return false;
    }

    CHECK_BUF1(p, p_end, sizeof(uint32));
    version = read_uint32(p);
    if (!is_little_endian())
        exchange32((uint8 *)&version);

    if (version != WASM_CURRENT_VERSION) {
        set_error_buf(error_buf, error_buf_size, "unknown binary version");
        return false;
    }

    module->package_version = version;

    if (!create_sections(buf, size, &section_list, error_buf, error_buf_size)
        || !load_from_sections(module, section_list, true, wasm_binary_freeable,
                               no_resolve, error_buf, error_buf_size)) {
        destroy_sections(section_list);
        return false;
    }

    destroy_sections(section_list);
    return true;
fail:
    return false;
}

#if WASM_ENABLE_LIBC_WASI != 0
/**
 * refer to
 * https://github.com/WebAssembly/WASI/blob/main/design/application-abi.md
 */
static bool
check_wasi_abi_compatibility(const WASMModule *module,
#if WASM_ENABLE_MULTI_MODULE != 0
                             bool main_module,
#endif
                             char *error_buf, uint32 error_buf_size)
{
    /**
     * be careful with:
     * wasi compatible modules(command/reactor) which don't import any wasi
     * APIs. Usually, a command has to import a "prox_exit" at least, but a
     * reactor can depend on nothing. At the same time, each has its own entry
     * point.
     *
     * observations:
     * - clang always injects `_start` into a command
     * - clang always injects `_initialize` into a reactor
     * - `iwasm -f` allows to run a function in the reactor
     *
     * strong assumptions:
     * - no one will define either `_start` or `_initialize` on purpose
     * - `_start` should always be `void _start(void)`
     * - `_initialize` should always be `void _initialize(void)`
     *
     */

    /* clang-format off */
    /**
     *
     * |             | import_wasi_api True |                  | import_wasi_api False |                  |
     * | ----------- | -------------------- | ---------------- | --------------------- | ---------------- |
     * |             | \_initialize() Y     | \_initialize() N | \_initialize() Y      | \_initialize() N |
     * | \_start() Y | N                    | COMMANDER        | N                     | COMMANDER        |
     * | \_start() N | REACTOR              | N                | REACTOR               | OTHERS           |
     */
    /* clang-format on */

    WASMExport *initialize = NULL, *memory = NULL, *start = NULL;
    uint32 import_function_count = module->import_function_count;
    WASMFuncType *func_type;

    /* (func (export "_start") (...) */
    start = wasm_loader_find_export(module, "", "_start", EXPORT_KIND_FUNC,
                                    error_buf, error_buf_size);
    if (start) {
        if (start->index < import_function_count) {
            set_error_buf(
                error_buf, error_buf_size,
                "the builtin _start function can not be an import function");
            return false;
        }

        func_type =
            module->functions[start->index - import_function_count]->func_type;
        if (func_type->param_count || func_type->result_count) {
            set_error_buf(error_buf, error_buf_size,
                          "the signature of builtin _start function is wrong");
            return false;
        }
    }
    else {
        /* (func (export "_initialize") (...) */
        initialize =
            wasm_loader_find_export(module, "", "_initialize", EXPORT_KIND_FUNC,
                                    error_buf, error_buf_size);

        if (initialize) {
            if (initialize->index < import_function_count) {
                set_error_buf(error_buf, error_buf_size,
                              "the builtin _initialize function can not be an "
                              "import function");
                return false;
            }

            func_type =
                module->functions[initialize->index - import_function_count]
                    ->func_type;
            if (func_type->param_count || func_type->result_count) {
                set_error_buf(
                    error_buf, error_buf_size,
                    "the signature of builtin _initialize function is wrong");
                return false;
            }
        }
    }

    /* filter out non-wasi compatible modules */
    if (!module->import_wasi_api && !start && !initialize) {
        return true;
    }

    /* should have one at least */
    if (module->import_wasi_api && !start && !initialize) {
        LOG_WARNING("warning: a module with WASI apis should be either "
                    "a command or a reactor");
    }

    /*
     * there is at least one of `_start` and `_initialize` in below cases.
     * according to the assumption, they should be all wasi compatible
     */

#if WASM_ENABLE_MULTI_MODULE != 0
    /* filter out commands (with `_start`) cases */
    if (start && !main_module) {
        set_error_buf(
            error_buf, error_buf_size,
            "a command (with _start function) can not be a sub-module");
        return false;
    }
#endif

    /*
     * it is ok a reactor acts as a main module,
     * so skip the check about (with `_initialize`)
     */

    memory = wasm_loader_find_export(module, "", "memory", EXPORT_KIND_MEMORY,
                                     error_buf, error_buf_size);
    if (!memory
#if WASM_ENABLE_LIB_WASI_THREADS != 0
        /*
         * with wasi-threads, it's still an open question if a memory
         * should be exported.
         *
         * https://github.com/WebAssembly/wasi-threads/issues/22
         * https://github.com/WebAssembly/WASI/issues/502
         *
         * Note: this code assumes the number of memories is at most 1.
         */
        && module->import_memory_count == 0
#endif
    ) {
        set_error_buf(error_buf, error_buf_size,
                      "a module with WASI apis must export memory by default");
        return false;
    }

    return true;
}
#endif

WASMModule *
wasm_loader_load(uint8 *buf, uint32 size,
#if WASM_ENABLE_MULTI_MODULE != 0
                 bool main_module,
#endif
                 const LoadArgs *args, char *error_buf, uint32 error_buf_size)
{
    WASMModule *module = create_module(args->name, error_buf, error_buf_size);
    if (!module) {
        return NULL;
    }

#if WASM_ENABLE_DEBUG_INTERP != 0 || WASM_ENABLE_FAST_JIT != 0 \
    || WASM_ENABLE_DUMP_CALL_STACK != 0 || WASM_ENABLE_JIT != 0
    module->load_addr = (uint8 *)buf;
    module->load_size = size;
#endif

    if (!load(buf, size, module, args->wasm_binary_freeable, args->no_resolve,
              error_buf, error_buf_size)) {
        goto fail;
    }

#if WASM_ENABLE_LIBC_WASI != 0
    /* Check the WASI application ABI */
    if (!check_wasi_abi_compatibility(module,
#if WASM_ENABLE_MULTI_MODULE != 0
                                      main_module,
#endif
                                      error_buf, error_buf_size)) {
        goto fail;
    }
#endif

    LOG_VERBOSE("Load module success.\n");
    return module;

fail:
    wasm_loader_unload(module);
    return NULL;
}

void
wasm_loader_unload(WASMModule *module)
{
    uint32 i;

    if (!module)
        return;

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    module->orcjit_stop_compiling = true;
    if (module->llvm_jit_init_thread)
        os_thread_join(module->llvm_jit_init_thread, NULL);
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
    /* Stop Fast/LLVM JIT compilation firstly to avoid accessing
       module internal data after they were freed */
    orcjit_stop_compile_threads(module);
#endif

#if WASM_ENABLE_JIT != 0
    if (module->func_ptrs)
        wasm_runtime_free(module->func_ptrs);
    if (module->comp_ctx)
        aot_destroy_comp_context(module->comp_ctx);
    if (module->comp_data)
        aot_destroy_comp_data(module->comp_data);
#endif

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    if (module->tierup_wait_lock_inited) {
        os_mutex_destroy(&module->tierup_wait_lock);
        os_cond_destroy(&module->tierup_wait_cond);
    }
#endif

    if (module->imports)
        wasm_runtime_free(module->imports);

    if (module->functions) {
        for (i = 0; i < module->function_count; i++) {
            if (module->functions[i]) {
                if (module->functions[i]->local_offsets)
                    wasm_runtime_free(module->functions[i]->local_offsets);
#if WASM_ENABLE_FAST_INTERP != 0
                if (module->functions[i]->code_compiled)
                    wasm_runtime_free(module->functions[i]->code_compiled);
                if (module->functions[i]->consts)
                    wasm_runtime_free(module->functions[i]->consts);
#endif
#if WASM_ENABLE_FAST_JIT != 0
                if (module->functions[i]->fast_jit_jitted_code) {
                    jit_code_cache_free(
                        module->functions[i]->fast_jit_jitted_code);
                }
#if WASM_ENABLE_JIT != 0 && WASM_ENABLE_LAZY_JIT != 0
                if (module->functions[i]->call_to_fast_jit_from_llvm_jit) {
                    jit_code_cache_free(
                        module->functions[i]->call_to_fast_jit_from_llvm_jit);
                }
#endif
#endif
#if WASM_ENABLE_GC != 0
                if (module->functions[i]->local_ref_type_maps) {
                    wasm_runtime_free(
                        module->functions[i]->local_ref_type_maps);
                }
#endif
                wasm_runtime_free(module->functions[i]);
            }
        }
        wasm_runtime_free(module->functions);
    }

    if (module->tables) {
#if WASM_ENABLE_GC != 0
        for (i = 0; i < module->table_count; i++) {
            destroy_init_expr(module, &module->tables[i].init_expr);
        }
#endif
        wasm_runtime_free(module->tables);
    }

    if (module->memories)
        wasm_runtime_free(module->memories);

    if (module->globals) {
#if WASM_ENABLE_GC != 0 || WASM_ENABLE_EXTENDED_CONST_EXPR != 0
        for (i = 0; i < module->global_count; i++) {
            destroy_init_expr(module, &module->globals[i].init_expr);
        }
#endif
        wasm_runtime_free(module->globals);
    }

#if WASM_ENABLE_TAGS != 0
    if (module->tags) {
        for (i = 0; i < module->tag_count; i++) {
            if (module->tags[i])
                wasm_runtime_free(module->tags[i]);
        }
        wasm_runtime_free(module->tags);
    }
#endif

    if (module->exports)
        wasm_runtime_free(module->exports);

    if (module->table_segments) {
        for (i = 0; i < module->table_seg_count; i++) {
            if (module->table_segments[i].init_values) {
#if WASM_ENABLE_GC != 0
                uint32 j;
                for (j = 0; j < module->table_segments[i].value_count; j++) {
                    destroy_init_expr(
                        module, &module->table_segments[i].init_values[j]);
                }
#endif
                wasm_runtime_free(module->table_segments[i].init_values);
            }
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
            destroy_init_expr(module, &module->table_segments[i].base_offset);
#endif
        }
        wasm_runtime_free(module->table_segments);
    }

    if (module->data_segments) {
        for (i = 0; i < module->data_seg_count; i++) {
            if (module->data_segments[i]) {
                if (module->data_segments[i]->is_data_cloned)
                    wasm_runtime_free(module->data_segments[i]->data);
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
                destroy_init_expr(module,
                                  &(module->data_segments[i]->base_offset));
#endif
                wasm_runtime_free(module->data_segments[i]);
            }
        }
        wasm_runtime_free(module->data_segments);
    }

    if (module->types) {
        for (i = 0; i < module->type_count; i++) {
            if (module->types[i])
                destroy_wasm_type(module->types[i]);
        }
        wasm_runtime_free(module->types);
    }

    if (module->const_str_list) {
        StringNode *node = module->const_str_list, *node_next;
        while (node) {
            node_next = node->next;
            wasm_runtime_free(node);
            node = node_next;
        }
    }

#if WASM_ENABLE_STRINGREF != 0
    if (module->string_literal_ptrs) {
        wasm_runtime_free((void *)module->string_literal_ptrs);
    }
    if (module->string_literal_lengths) {
        wasm_runtime_free(module->string_literal_lengths);
    }
#endif

#if WASM_ENABLE_FAST_INTERP == 0
    if (module->br_table_cache_list) {
        BrTableCache *node = bh_list_first_elem(module->br_table_cache_list);
        BrTableCache *node_next;
        while (node) {
            node_next = bh_list_elem_next(node);
            wasm_runtime_free(node);
            node = node_next;
        }
    }
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
    /* just release the sub module list */
    if (module->import_module_list) {
        WASMRegisteredModule *node =
            bh_list_first_elem(module->import_module_list);
        while (node) {
            WASMRegisteredModule *next = bh_list_elem_next(node);
            bh_list_remove(module->import_module_list, node);
            /*
             * unload(sub_module) will be triggered during runtime_destroy().
             * every module in the global module list will be unloaded one by
             * one. so don't worry.
             */
            wasm_runtime_free(node);
            /*
             * the module file reading buffer will be released
             * in runtime_destroy()
             */
            node = next;
        }
    }
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0
    WASMFastOPCodeNode *fast_opcode =
        bh_list_first_elem(&module->fast_opcode_list);
    while (fast_opcode) {
        WASMFastOPCodeNode *next = bh_list_elem_next(fast_opcode);
        wasm_runtime_free(fast_opcode);
        fast_opcode = next;
    }
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0                         \
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
        && WASM_ENABLE_LAZY_JIT != 0)
    os_mutex_destroy(&module->instance_list_lock);
#endif

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
    wasm_runtime_destroy_custom_sections(module->custom_section_list);
#endif

#if WASM_ENABLE_FAST_JIT != 0
    if (module->fast_jit_func_ptrs) {
        wasm_runtime_free(module->fast_jit_func_ptrs);
    }

    for (i = 0; i < WASM_ORC_JIT_BACKEND_THREAD_NUM; i++) {
        if (module->fast_jit_thread_locks_inited[i]) {
            os_mutex_destroy(&module->fast_jit_thread_locks[i]);
        }
    }
#endif

#if WASM_ENABLE_GC != 0
    os_mutex_destroy(&module->rtt_type_lock);
    bh_hash_map_destroy(module->ref_type_set);
    if (module->rtt_types) {
        for (i = 0; i < module->type_count; i++) {
            if (module->rtt_types[i])
                wasm_runtime_free(module->rtt_types[i]);
        }
        wasm_runtime_free(module->rtt_types);
    }
#if WASM_ENABLE_STRINGREF != 0
    for (i = 0; i < WASM_TYPE_STRINGVIEWITER - WASM_TYPE_STRINGREF + 1; i++) {
        if (module->stringref_rtts[i])
            wasm_runtime_free(module->stringref_rtts[i]);
    }
#endif
#endif

    wasm_runtime_free(module);
}

bool
wasm_loader_find_block_addr(WASMExecEnv *exec_env, BlockAddr *block_addr_cache,
                            const uint8 *start_addr, const uint8 *code_end_addr,
                            uint8 label_type, uint8 **p_else_addr,
                            uint8 **p_end_addr)
{
    const uint8 *p = start_addr, *p_end = code_end_addr;
    uint8 *else_addr = NULL;
    char error_buf[128];
    uint32 block_nested_depth = 1, count, i, j, t;
    uint32 error_buf_size = sizeof(error_buf);
    uint8 opcode, u8;
    BlockAddr block_stack[16] = { { 0 } }, *block;

    i = ((uintptr_t)start_addr) & (uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
    block = block_addr_cache + BLOCK_ADDR_CONFLICT_SIZE * i;

    for (j = 0; j < BLOCK_ADDR_CONFLICT_SIZE; j++) {
        if (block[j].start_addr == start_addr) {
            /* Cache hit */
            *p_else_addr = block[j].else_addr;
            *p_end_addr = block[j].end_addr;
            return true;
        }
    }

    /* Cache unhit */
    block_stack[0].start_addr = start_addr;

    while (p < code_end_addr) {
        opcode = *p++;
#if WASM_ENABLE_DEBUG_INTERP != 0
    op_break_retry:
#endif
        switch (opcode) {
            case WASM_OP_UNREACHABLE:
            case WASM_OP_NOP:
                break;

#if WASM_ENABLE_EXCE_HANDLING != 0
            case WASM_OP_TRY:
                u8 = read_uint8(p);
                if (block_nested_depth
                    < sizeof(block_stack) / sizeof(BlockAddr)) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = NULL;
                }
                block_nested_depth++;
                break;
            case EXT_OP_TRY:
                skip_leb_uint32(p, p_end);
                if (block_nested_depth
                    < sizeof(block_stack) / sizeof(BlockAddr)) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = NULL;
                }
                block_nested_depth++;
                break;
            case WASM_OP_CATCH:
                if (block_nested_depth == 1) {
                    *p_end_addr = (uint8 *)(p - 1);
                    /* stop search and return the address of the catch block */
                    return true;
                }
                break;
            case WASM_OP_CATCH_ALL:
                if (block_nested_depth == 1) {
                    *p_end_addr = (uint8 *)(p - 1);
                    /* stop search and return the address of the catch_all block
                     */
                    return true;
                }
                break;
            case WASM_OP_THROW:
                /* skip tag_index */
                skip_leb(p);
                break;
            case WASM_OP_RETHROW:
                /* skip depth */
                skip_leb(p);
                break;
            case WASM_OP_DELEGATE:
                if (block_nested_depth == 1) {
                    *p_end_addr = (uint8 *)(p - 1);
                    return true;
                }
                else {
                    skip_leb(p);
                    /* the DELEGATE opcode ends the tryblock, */
                    block_nested_depth--;
                    if (block_nested_depth
                        < sizeof(block_stack) / sizeof(BlockAddr))
                        block_stack[block_nested_depth].end_addr =
                            (uint8 *)(p - 1);
                }
                break;
#endif /* end of WASM_ENABLE_EXCE_HANDLING != 0 */

            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
            case WASM_OP_IF:
            {
                /* block result type: 0x40/0x7F/0x7E/0x7D/0x7C */
                u8 = read_uint8(p);
                if (is_byte_a_type(u8)) {
#if WASM_ENABLE_GC != 0
                    if (wasm_is_type_multi_byte_type(u8)) {
                        /* the possible extra bytes of GC ref type have been
                           modified to OP_NOP, no need to resolve them again */
                    }
#endif
                }
                else {
                    p--;
                    /* block type */
                    skip_leb_int32(p, p_end);
                }
                if (block_nested_depth
                    < sizeof(block_stack) / sizeof(BlockAddr)) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = NULL;
                }
                block_nested_depth++;
                break;
            }

            case EXT_OP_BLOCK:
            case EXT_OP_LOOP:
            case EXT_OP_IF:
                /* block type */
                skip_leb_int32(p, p_end);
                if (block_nested_depth
                    < sizeof(block_stack) / sizeof(BlockAddr)) {
                    block_stack[block_nested_depth].start_addr = p;
                    block_stack[block_nested_depth].else_addr = NULL;
                }
                block_nested_depth++;
                break;

            case WASM_OP_ELSE:
                if (label_type == LABEL_TYPE_IF && block_nested_depth == 1)
                    else_addr = (uint8 *)(p - 1);
                if (block_nested_depth - 1
                    < sizeof(block_stack) / sizeof(BlockAddr))
                    block_stack[block_nested_depth - 1].else_addr =
                        (uint8 *)(p - 1);
                break;

            case WASM_OP_END:
                if (block_nested_depth == 1) {
                    if (label_type == LABEL_TYPE_IF)
                        *p_else_addr = else_addr;
                    *p_end_addr = (uint8 *)(p - 1);

                    block_stack[0].end_addr = (uint8 *)(p - 1);
                    for (t = 0; t < sizeof(block_stack) / sizeof(BlockAddr);
                         t++) {
                        start_addr = block_stack[t].start_addr;
                        if (start_addr) {
                            i = ((uintptr_t)start_addr)
                                & (uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
                            block =
                                block_addr_cache + BLOCK_ADDR_CONFLICT_SIZE * i;
                            for (j = 0; j < BLOCK_ADDR_CONFLICT_SIZE; j++)
                                if (!block[j].start_addr)
                                    break;

                            if (j == BLOCK_ADDR_CONFLICT_SIZE) {
                                memmove(block + 1, block,
                                        (BLOCK_ADDR_CONFLICT_SIZE - 1)
                                            * sizeof(BlockAddr));
                                j = 0;
                            }
                            block[j].start_addr = block_stack[t].start_addr;
                            block[j].else_addr = block_stack[t].else_addr;
                            block[j].end_addr = block_stack[t].end_addr;
                        }
                        else
                            break;
                    }
                    return true;
                }
                else {
                    block_nested_depth--;
                    if (block_nested_depth
                        < sizeof(block_stack) / sizeof(BlockAddr))
                        block_stack[block_nested_depth].end_addr =
                            (uint8 *)(p - 1);
                }
                break;

            case WASM_OP_BR:
            case WASM_OP_BR_IF:
                skip_leb_uint32(p, p_end); /* labelidx */
                break;

            case WASM_OP_BR_TABLE:
                read_leb_uint32(p, p_end, count); /* label num */
#if WASM_ENABLE_FAST_INTERP != 0
                for (i = 0; i <= count; i++) /* labelidxs */
                    skip_leb_uint32(p, p_end);
#else
                p += count + 1;
                while (*p == WASM_OP_NOP)
                    p++;
#endif
                break;

#if WASM_ENABLE_FAST_INTERP == 0
            case EXT_OP_BR_TABLE_CACHE:
                read_leb_uint32(p, p_end, count); /* label num */
                while (*p == WASM_OP_NOP)
                    p++;
                break;
#endif

            case WASM_OP_RETURN:
                break;

            case WASM_OP_CALL:
#if WASM_ENABLE_TAIL_CALL != 0
            case WASM_OP_RETURN_CALL:
#endif
                skip_leb_uint32(p, p_end); /* funcidx */
                break;

            case WASM_OP_CALL_INDIRECT:
#if WASM_ENABLE_TAIL_CALL != 0
            case WASM_OP_RETURN_CALL_INDIRECT:
#endif
                skip_leb_uint32(p, p_end); /* typeidx */
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
                skip_leb_uint32(p, p_end); /* tableidx */
#else
                u8 = read_uint8(p); /* 0x00 */
#endif
                break;

#if WASM_ENABLE_GC != 0
            case WASM_OP_CALL_REF:
            case WASM_OP_RETURN_CALL_REF:
                skip_leb_uint32(p, p_end); /* typeidx */
                break;
#endif

            case WASM_OP_DROP:
            case WASM_OP_SELECT:
            case WASM_OP_DROP_64:
            case WASM_OP_SELECT_64:
#if WASM_ENABLE_SIMDE != 0
            case WASM_OP_SELECT_128:
#endif
                break;

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            case WASM_OP_SELECT_T:
            {
                skip_leb_uint32(p, p_end); /* vec length */
                u8 = read_uint8(p);        /* typeidx */
                /* the possible extra bytes of GC ref type have been
                   modified to OP_NOP, no need to resolve them again */
                break;
            }

            case WASM_OP_TABLE_GET:
            case WASM_OP_TABLE_SET:
                skip_leb_uint32(p, p_end); /* table index */
                break;
            case WASM_OP_REF_NULL:
            {
                u8 = read_uint8(p); /* type */
                if (is_byte_a_type(u8)) {
#if WASM_ENABLE_GC != 0
                    if (wasm_is_type_multi_byte_type(u8)) {
                        /* the possible extra bytes of GC ref type have been
                           modified to OP_NOP, no need to resolve them again */
                    }
#endif
                }
                else {
                    p--;
                    skip_leb_uint32(p, p_end);
                }
                break;
            }
            case WASM_OP_REF_IS_NULL:
                break;
            case WASM_OP_REF_FUNC:
                skip_leb_uint32(p, p_end); /* func index */
                break;
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

#if WASM_ENABLE_GC != 0
            case WASM_OP_REF_AS_NON_NULL:
            case WASM_OP_REF_EQ:
                break;
            case WASM_OP_BR_ON_NULL:
            case WASM_OP_BR_ON_NON_NULL:
                skip_leb_uint32(p, p_end); /* label index */
                break;
#endif /* end of WASM_ENABLE_GC != 0 */

            case WASM_OP_GET_LOCAL:
            case WASM_OP_SET_LOCAL:
            case WASM_OP_TEE_LOCAL:
            case WASM_OP_GET_GLOBAL:
            case WASM_OP_SET_GLOBAL:
            case WASM_OP_GET_GLOBAL_64:
            case WASM_OP_SET_GLOBAL_64:
#if WASM_ENABLE_SIMDE != 0
            case WASM_OP_GET_GLOBAL_V128:
            case WASM_OP_SET_GLOBAL_V128:
#endif
            case WASM_OP_SET_GLOBAL_AUX_STACK:
                skip_leb_uint32(p, p_end); /* local index */
                break;

            case EXT_OP_GET_LOCAL_FAST:
            case EXT_OP_SET_LOCAL_FAST:
            case EXT_OP_TEE_LOCAL_FAST:
                CHECK_BUF(p, p_end, 1);
                p++;
                break;

            case WASM_OP_I32_LOAD:
            case WASM_OP_I64_LOAD:
            case WASM_OP_F32_LOAD:
            case WASM_OP_F64_LOAD:
            case WASM_OP_I32_LOAD8_S:
            case WASM_OP_I32_LOAD8_U:
            case WASM_OP_I32_LOAD16_S:
            case WASM_OP_I32_LOAD16_U:
            case WASM_OP_I64_LOAD8_S:
            case WASM_OP_I64_LOAD8_U:
            case WASM_OP_I64_LOAD16_S:
            case WASM_OP_I64_LOAD16_U:
            case WASM_OP_I64_LOAD32_S:
            case WASM_OP_I64_LOAD32_U:
            case WASM_OP_I32_STORE:
            case WASM_OP_I64_STORE:
            case WASM_OP_F32_STORE:
            case WASM_OP_F64_STORE:
            case WASM_OP_I32_STORE8:
            case WASM_OP_I32_STORE16:
            case WASM_OP_I64_STORE8:
            case WASM_OP_I64_STORE16:
            case WASM_OP_I64_STORE32:
                skip_leb_align(p, p_end);      /* align */
                skip_leb_mem_offset(p, p_end); /* offset */
                break;

            case WASM_OP_MEMORY_SIZE:
            case WASM_OP_MEMORY_GROW:
                skip_leb_memidx(p, p_end); /* memidx */
                break;

            case WASM_OP_I32_CONST:
                skip_leb_int32(p, p_end);
                break;
            case WASM_OP_I64_CONST:
                skip_leb_int64(p, p_end);
                break;
            case WASM_OP_F32_CONST:
                p += sizeof(float32);
                break;
            case WASM_OP_F64_CONST:
                p += sizeof(float64);
                break;

            case WASM_OP_I32_EQZ:
            case WASM_OP_I32_EQ:
            case WASM_OP_I32_NE:
            case WASM_OP_I32_LT_S:
            case WASM_OP_I32_LT_U:
            case WASM_OP_I32_GT_S:
            case WASM_OP_I32_GT_U:
            case WASM_OP_I32_LE_S:
            case WASM_OP_I32_LE_U:
            case WASM_OP_I32_GE_S:
            case WASM_OP_I32_GE_U:
            case WASM_OP_I64_EQZ:
            case WASM_OP_I64_EQ:
            case WASM_OP_I64_NE:
            case WASM_OP_I64_LT_S:
            case WASM_OP_I64_LT_U:
            case WASM_OP_I64_GT_S:
            case WASM_OP_I64_GT_U:
            case WASM_OP_I64_LE_S:
            case WASM_OP_I64_LE_U:
            case WASM_OP_I64_GE_S:
            case WASM_OP_I64_GE_U:
            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
            case WASM_OP_I32_CLZ:
            case WASM_OP_I32_CTZ:
            case WASM_OP_I32_POPCNT:
            case WASM_OP_I32_ADD:
            case WASM_OP_I32_SUB:
            case WASM_OP_I32_MUL:
            case WASM_OP_I32_DIV_S:
            case WASM_OP_I32_DIV_U:
            case WASM_OP_I32_REM_S:
            case WASM_OP_I32_REM_U:
            case WASM_OP_I32_AND:
            case WASM_OP_I32_OR:
            case WASM_OP_I32_XOR:
            case WASM_OP_I32_SHL:
            case WASM_OP_I32_SHR_S:
            case WASM_OP_I32_SHR_U:
            case WASM_OP_I32_ROTL:
            case WASM_OP_I32_ROTR:
            case WASM_OP_I64_CLZ:
            case WASM_OP_I64_CTZ:
            case WASM_OP_I64_POPCNT:
            case WASM_OP_I64_ADD:
            case WASM_OP_I64_SUB:
            case WASM_OP_I64_MUL:
            case WASM_OP_I64_DIV_S:
            case WASM_OP_I64_DIV_U:
            case WASM_OP_I64_REM_S:
            case WASM_OP_I64_REM_U:
            case WASM_OP_I64_AND:
            case WASM_OP_I64_OR:
            case WASM_OP_I64_XOR:
            case WASM_OP_I64_SHL:
            case WASM_OP_I64_SHR_S:
            case WASM_OP_I64_SHR_U:
            case WASM_OP_I64_ROTL:
            case WASM_OP_I64_ROTR:
            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
            case WASM_OP_F32_COPYSIGN:
            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
            case WASM_OP_F64_COPYSIGN:
            case WASM_OP_I32_WRAP_I64:
            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
            case WASM_OP_F32_DEMOTE_F64:
            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
            case WASM_OP_F64_PROMOTE_F32:
            case WASM_OP_I32_REINTERPRET_F32:
            case WASM_OP_I64_REINTERPRET_F64:
            case WASM_OP_F32_REINTERPRET_I32:
            case WASM_OP_F64_REINTERPRET_I64:
            case WASM_OP_I32_EXTEND8_S:
            case WASM_OP_I32_EXTEND16_S:
            case WASM_OP_I64_EXTEND8_S:
            case WASM_OP_I64_EXTEND16_S:
            case WASM_OP_I64_EXTEND32_S:
                break;

#if WASM_ENABLE_GC != 0
            case WASM_OP_GC_PREFIX:
            {
                uint32 opcode1;

                read_leb_uint32(p, p_end, opcode1);
                /* opcode1 was checked in wasm_loader_prepare_bytecode and
                   is no larger than UINT8_MAX */
                opcode = (uint8)opcode1;

                switch (opcode) {
                    case WASM_OP_STRUCT_NEW:
                    case WASM_OP_STRUCT_NEW_DEFAULT:
                        skip_leb_uint32(p, p_end); /* typeidx */
                        break;
                    case WASM_OP_STRUCT_GET:
                    case WASM_OP_STRUCT_GET_S:
                    case WASM_OP_STRUCT_GET_U:
                    case WASM_OP_STRUCT_SET:
                        skip_leb_uint32(p, p_end); /* typeidx */
                        skip_leb_uint32(p, p_end); /* fieldidx */
                        break;

                    case WASM_OP_ARRAY_NEW:
                    case WASM_OP_ARRAY_NEW_DEFAULT:
                    case WASM_OP_ARRAY_GET:
                    case WASM_OP_ARRAY_GET_S:
                    case WASM_OP_ARRAY_GET_U:
                    case WASM_OP_ARRAY_SET:
                    case WASM_OP_ARRAY_FILL:
                        skip_leb_uint32(p, p_end); /* typeidx */
                        break;
                    case WASM_OP_ARRAY_COPY:
                        skip_leb_uint32(p, p_end); /* typeidx1 */
                        skip_leb_uint32(p, p_end); /* typeidx2 */
                        break;
                    case WASM_OP_ARRAY_LEN:
                        break;
                    case WASM_OP_ARRAY_NEW_FIXED:
                    case WASM_OP_ARRAY_NEW_DATA:
                    case WASM_OP_ARRAY_NEW_ELEM:
                        skip_leb_uint32(p, p_end); /* typeidx */
                        skip_leb_uint32(p, p_end); /* N/dataidx/elemidx */
                        break;

                    case WASM_OP_REF_I31:
                    case WASM_OP_I31_GET_S:
                    case WASM_OP_I31_GET_U:
                        break;

                    case WASM_OP_REF_TEST:
                    case WASM_OP_REF_CAST:
                    case WASM_OP_REF_TEST_NULLABLE:
                    case WASM_OP_REF_CAST_NULLABLE:
                        skip_leb_int32(p, p_end); /* heaptype */
                        break;
                    case WASM_OP_BR_ON_CAST:
                    case WASM_OP_BR_ON_CAST_FAIL:
                        p += sizeof(uint8);        /* castflag */
                        skip_leb_uint32(p, p_end); /* labelidx */
                        skip_leb_int32(p, p_end);  /* heaptype */
                        skip_leb_int32(p, p_end);  /* heaptype2 */
                        break;

                    case WASM_OP_ANY_CONVERT_EXTERN:
                    case WASM_OP_EXTERN_CONVERT_ANY:
                        break;

#if WASM_ENABLE_STRINGREF != 0
                    case WASM_OP_STRING_NEW_UTF8:
                    case WASM_OP_STRING_NEW_WTF16:
                    case WASM_OP_STRING_NEW_LOSSY_UTF8:
                    case WASM_OP_STRING_NEW_WTF8:
                        skip_leb_uint32(p, p_end); /* memory index 0x00 */
                        break;
                    case WASM_OP_STRING_CONST:
                        skip_leb_int32(p, p_end); /* contents */
                        break;
                    case WASM_OP_STRING_MEASURE_UTF8:
                    case WASM_OP_STRING_MEASURE_WTF8:
                    case WASM_OP_STRING_MEASURE_WTF16:
                        break;
                    case WASM_OP_STRING_ENCODE_UTF8:
                    case WASM_OP_STRING_ENCODE_WTF16:
                    case WASM_OP_STRING_ENCODE_LOSSY_UTF8:
                    case WASM_OP_STRING_ENCODE_WTF8:
                        skip_leb_uint32(p, p_end); /* memory index 0x00 */
                        break;
                    case WASM_OP_STRING_CONCAT:
                    case WASM_OP_STRING_EQ:
                    case WASM_OP_STRING_IS_USV_SEQUENCE:
                    case WASM_OP_STRING_AS_WTF8:
                    case WASM_OP_STRINGVIEW_WTF8_ADVANCE:
                        break;
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_UTF8:
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_LOSSY_UTF8:
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_WTF8:
                        skip_leb_uint32(p, p_end); /* memory index 0x00 */
                        break;
                    case WASM_OP_STRINGVIEW_WTF8_SLICE:
                    case WASM_OP_STRING_AS_WTF16:
                    case WASM_OP_STRINGVIEW_WTF16_LENGTH:
                    case WASM_OP_STRINGVIEW_WTF16_GET_CODEUNIT:
                        break;
                    case WASM_OP_STRINGVIEW_WTF16_ENCODE:
                        skip_leb_uint32(p, p_end); /* memory index 0x00 */
                        break;
                    case WASM_OP_STRINGVIEW_WTF16_SLICE:
                    case WASM_OP_STRING_AS_ITER:
                    case WASM_OP_STRINGVIEW_ITER_NEXT:
                    case WASM_OP_STRINGVIEW_ITER_ADVANCE:
                    case WASM_OP_STRINGVIEW_ITER_REWIND:
                    case WASM_OP_STRINGVIEW_ITER_SLICE:
                    case WASM_OP_STRING_NEW_UTF8_ARRAY:
                    case WASM_OP_STRING_NEW_WTF16_ARRAY:
                    case WASM_OP_STRING_NEW_LOSSY_UTF8_ARRAY:
                    case WASM_OP_STRING_NEW_WTF8_ARRAY:
                    case WASM_OP_STRING_ENCODE_UTF8_ARRAY:
                    case WASM_OP_STRING_ENCODE_WTF16_ARRAY:
                    case WASM_OP_STRING_ENCODE_LOSSY_UTF8_ARRAY:
                    case WASM_OP_STRING_ENCODE_WTF8_ARRAY:
                        break;
#endif /* end of WASM_ENABLE_STRINGREF != 0 */
                    default:
                        return false;
                }
                break;
            }
#endif /* end of WASM_ENABLE_GC != 0 */

            case WASM_OP_MISC_PREFIX:
            {
                uint32 opcode1;

                read_leb_uint32(p, p_end, opcode1);
                /* opcode1 was checked in wasm_loader_prepare_bytecode and
                   is no larger than UINT8_MAX */
                opcode = (uint8)opcode1;

                switch (opcode) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        break;
#if WASM_ENABLE_BULK_MEMORY != 0
                    case WASM_OP_MEMORY_INIT:
                        skip_leb_uint32(p, p_end);
                        skip_leb_memidx(p, p_end);
                        break;
                    case WASM_OP_DATA_DROP:
                        skip_leb_uint32(p, p_end);
                        break;
                    case WASM_OP_MEMORY_COPY:
                        skip_leb_memidx(p, p_end);
                        skip_leb_memidx(p, p_end);
                        break;
                    case WASM_OP_MEMORY_FILL:
                        skip_leb_memidx(p, p_end);
                        break;
#endif /* WASM_ENABLE_BULK_MEMORY */
#if WASM_ENABLE_REF_TYPES != 0
                    case WASM_OP_TABLE_INIT:
                    case WASM_OP_TABLE_COPY:
                        /* tableidx */
                        skip_leb_uint32(p, p_end);
                        /* elemidx */
                        skip_leb_uint32(p, p_end);
                        break;
                    case WASM_OP_ELEM_DROP:
                        /* elemidx */
                        skip_leb_uint32(p, p_end);
                        break;
                    case WASM_OP_TABLE_SIZE:
                    case WASM_OP_TABLE_GROW:
                    case WASM_OP_TABLE_FILL:
                        skip_leb_uint32(p, p_end); /* table idx */
                        break;
#endif /* WASM_ENABLE_REF_TYPES */
                    default:
                        return false;
                }
                break;
            }

#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
            case WASM_OP_SIMD_PREFIX:
            {
                uint32 opcode1;

                read_leb_uint32(p, p_end, opcode1);
                /* opcode1 was checked in wasm_loader_prepare_bytecode and
                   is no larger than UINT8_MAX */
                opcode = (uint8)opcode1;

                /* follow the order of enum WASMSimdEXTOpcode in wasm_opcode.h
                 */
                switch (opcode) {
                    case SIMD_v128_load:
                    case SIMD_v128_load8x8_s:
                    case SIMD_v128_load8x8_u:
                    case SIMD_v128_load16x4_s:
                    case SIMD_v128_load16x4_u:
                    case SIMD_v128_load32x2_s:
                    case SIMD_v128_load32x2_u:
                    case SIMD_v128_load8_splat:
                    case SIMD_v128_load16_splat:
                    case SIMD_v128_load32_splat:
                    case SIMD_v128_load64_splat:
                    case SIMD_v128_store:
                        /* memarg align */
                        skip_leb_uint32(p, p_end);
                        /* memarg offset */
                        skip_leb_mem_offset(p, p_end);
                        break;

                    case SIMD_v128_const:
                    case SIMD_v8x16_shuffle:
                        /* immByte[16] immLaneId[16] */
                        CHECK_BUF1(p, p_end, 16);
                        p += 16;
                        break;

                    case SIMD_i8x16_extract_lane_s:
                    case SIMD_i8x16_extract_lane_u:
                    case SIMD_i8x16_replace_lane:
                    case SIMD_i16x8_extract_lane_s:
                    case SIMD_i16x8_extract_lane_u:
                    case SIMD_i16x8_replace_lane:
                    case SIMD_i32x4_extract_lane:
                    case SIMD_i32x4_replace_lane:
                    case SIMD_i64x2_extract_lane:
                    case SIMD_i64x2_replace_lane:
                    case SIMD_f32x4_extract_lane:
                    case SIMD_f32x4_replace_lane:
                    case SIMD_f64x2_extract_lane:
                    case SIMD_f64x2_replace_lane:
                        /* ImmLaneId */
                        CHECK_BUF(p, p_end, 1);
                        p++;
                        break;

                    case SIMD_v128_load8_lane:
                    case SIMD_v128_load16_lane:
                    case SIMD_v128_load32_lane:
                    case SIMD_v128_load64_lane:
                    case SIMD_v128_store8_lane:
                    case SIMD_v128_store16_lane:
                    case SIMD_v128_store32_lane:
                    case SIMD_v128_store64_lane:
                        /* memarg align */
                        skip_leb_uint32(p, p_end);
                        /* memarg offset */
                        skip_leb_mem_offset(p, p_end);
                        /* ImmLaneId */
                        CHECK_BUF(p, p_end, 1);
                        p++;
                        break;

                    case SIMD_v128_load32_zero:
                    case SIMD_v128_load64_zero:
                        /* memarg align */
                        skip_leb_uint32(p, p_end);
                        /* memarg offset */
                        skip_leb_mem_offset(p, p_end);
                        break;

                    default:
                        /*
                         * since latest SIMD specific used almost every value
                         * from 0x00 to 0xff, the default branch will present
                         * all opcodes without imm
                         * https://github.com/WebAssembly/simd/blob/main/proposals/simd/NewOpcodes.md
                         */
                        break;
                }
                break;
            }
#endif /* end of (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) || \
          (WASM_ENABLE_FAST_INTERP != 0) */
#endif /* end of WASM_ENABLE_SIMD */

#if WASM_ENABLE_SHARED_MEMORY != 0
            case WASM_OP_ATOMIC_PREFIX:
            {
                uint32 opcode1;

                /* atomic_op (u32_leb) + memarg (2 u32_leb) */
                read_leb_uint32(p, p_end, opcode1);
                /* opcode1 was checked in wasm_loader_prepare_bytecode and
                   is no larger than UINT8_MAX */
                opcode = (uint8)opcode1;

                if (opcode != WASM_OP_ATOMIC_FENCE) {
                    skip_leb_uint32(p, p_end);     /* align */
                    skip_leb_mem_offset(p, p_end); /* offset */
                }
                else {
                    /* atomic.fence doesn't have memarg */
                    p++;
                }
                break;
            }
#endif
#if WASM_ENABLE_DEBUG_INTERP != 0
            case DEBUG_OP_BREAK:
            {
                WASMDebugInstance *debug_instance =
                    wasm_exec_env_get_instance(exec_env);
                char original_opcode[1];
                uint64 size = 1;
                WASMModuleInstance *module_inst =
                    (WASMModuleInstance *)exec_env->module_inst;
                uint64 offset = (p - 1) >= module_inst->module->load_addr
                                    ? (p - 1) - module_inst->module->load_addr
                                    : ~0;
                if (debug_instance) {
                    if (wasm_debug_instance_get_obj_mem(debug_instance, offset,
                                                        original_opcode, &size)
                        && size == 1) {
                        LOG_VERBOSE("WASM loader find OP_BREAK , recover it "
                                    "with  %02x: ",
                                    original_opcode[0]);
                        opcode = original_opcode[0];
                        goto op_break_retry;
                    }
                }
                break;
            }
#endif

            default:
                return false;
        }
    }

    (void)u8;
    (void)exec_env;
    return false;
fail:
    return false;
}

#if WASM_ENABLE_FAST_INTERP != 0

#if WASM_DEBUG_PREPROCESSOR != 0
#define LOG_OP(...) os_printf(__VA_ARGS__)
#else
#define LOG_OP(...) (void)0
#endif

/* Maximum number of entries in the const table for which a full
 * scan is performed. This is to avoid an O(n^2) behavior for large 
 * tables. Entries beyond this limit are appended without scanning. 
 */
#define FAST_INTERP_CONST_DEDUP_SCAN_MAX 32

#define PATCH_ELSE 0
#define PATCH_END 1
typedef struct BranchBlockPatch {
    struct BranchBlockPatch *next;
    uint8 patch_type;
    uint8 *code_compiled;
} BranchBlockPatch;
#endif

typedef struct BranchBlock {
    uint8 label_type;
    BlockType block_type;
    uint8 *start_addr;
    uint8 *else_addr;
    uint8 *end_addr;
    uint32 stack_cell_num;
#if WASM_ENABLE_GC != 0
    uint32 reftype_map_num;
    /* Indicate which local is used inside current block, used to validate
     * local.get with non-nullable ref types */
    uint8 *local_use_mask;
    uint32 local_use_mask_size;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
    uint16 dynamic_offset;
    uint8 *code_compiled;
    BranchBlockPatch *patch_list;
    /* This is used to save params frame_offset of of if block */
    int16 *param_frame_offsets;
    /* This is used to recover the dynamic offset for else branch,
     * and also to remember the start offset of dynamic space which
     * stores the block arguments for loop block, so we can use it
     * to copy the stack operands to the loop block's arguments in
     * wasm_loader_emit_br_info for opcode br. */
    uint16 start_dynamic_offset;
#endif

    /* Indicate the operand stack is in polymorphic state.
     * If the opcode is one of unreachable/br/br_table/return, stack is marked
     * to polymorphic state until the block's 'end' opcode is processed.
     * If stack is in polymorphic state and stack is empty, instruction can
     * pop any type of value directly without decreasing stack top pointer
     * and stack cell num. */
    bool is_stack_polymorphic;
} BranchBlock;

typedef struct WASMLoaderContext {
    /* frame ref stack */
    uint8 *frame_ref;
    uint8 *frame_ref_bottom;
    uint8 *frame_ref_boundary;
    uint32 frame_ref_size;
    uint32 stack_cell_num;
    uint32 max_stack_cell_num;

#if WASM_ENABLE_GC != 0
    /* frame reftype map stack */
    WASMRefTypeMap *frame_reftype_map;
    WASMRefTypeMap *frame_reftype_map_bottom;
    WASMRefTypeMap *frame_reftype_map_boundary;
    uint32 frame_reftype_map_size;
    uint32 reftype_map_num;
    uint32 max_reftype_map_num;
    /* Current module */
    WASMModule *module;
    /* Current module's ref_type_set */
    HashMap *ref_type_set;
    /* Always point to local variable ref_type of
       wasm_loader_prepare_bytecode */
    WASMRefType *ref_type_tmp;
#endif

    /* frame csp stack */
    BranchBlock *frame_csp;
    BranchBlock *frame_csp_bottom;
    BranchBlock *frame_csp_boundary;
    uint32 frame_csp_size;
    uint32 csp_num;
    uint32 max_csp_num;

#if WASM_ENABLE_FAST_INTERP != 0
    /* frame offset stack */
    int16 *frame_offset;
    int16 *frame_offset_bottom;
    int16 *frame_offset_boundary;
    uint32 frame_offset_size;
    int16 dynamic_offset;
    int16 start_dynamic_offset;
    int16 max_dynamic_offset;

    /* preserved local offset */
    int16 preserved_local_offset;

    /* const buffer for i64 and f64 consts, note that the raw bytes
     * of i64 and f64 are the same, so we read an i64 value from an
     * f64 const with its raw bytes, something like `*(int64 *)&f64 */
    int64 *i64_consts;
    uint32 i64_const_max_num;
    uint32 i64_const_num;
    /* const buffer for i32 and f32 consts */
    int32 *i32_consts;
    uint32 i32_const_max_num;
    uint32 i32_const_num;
    /* const buffer for V128 */
    V128 *v128_consts;
    uint32 v128_const_max_num;
    uint32 v128_const_num;

    /* processed code */
    uint8 *p_code_compiled;
    uint8 *p_code_compiled_end;
    uint32 code_compiled_size;
    /* If the last opcode will be dropped, the peak memory usage will be larger
     * than the final code_compiled_size, we record the peak size to ensure
     * there will not be invalid memory access during second traverse */
    uint32 code_compiled_peak_size;
#endif
} WASMLoaderContext;

#define CHECK_CSP_PUSH()                                                  \
    do {                                                                  \
        if (ctx->frame_csp >= ctx->frame_csp_boundary) {                  \
            MEM_REALLOC(                                                  \
                ctx->frame_csp_bottom, ctx->frame_csp_size,               \
                (uint32)(ctx->frame_csp_size + 8 * sizeof(BranchBlock))); \
            ctx->frame_csp_size += (uint32)(8 * sizeof(BranchBlock));     \
            ctx->frame_csp_boundary =                                     \
                ctx->frame_csp_bottom                                     \
                + ctx->frame_csp_size / sizeof(BranchBlock);              \
            ctx->frame_csp = ctx->frame_csp_bottom + ctx->csp_num;        \
        }                                                                 \
    } while (0)

#define CHECK_CSP_POP()                                             \
    do {                                                            \
        if (ctx->csp_num < 1) {                                     \
            set_error_buf(error_buf, error_buf_size,                \
                          "type mismatch: "                         \
                          "expect data but block stack was empty"); \
            goto fail;                                              \
        }                                                           \
    } while (0)

#if WASM_ENABLE_FAST_INTERP != 0
static bool
check_offset_push(WASMLoaderContext *ctx, char *error_buf,
                  uint32 error_buf_size)
{
    uint32 cell_num = (uint32)(ctx->frame_offset - ctx->frame_offset_bottom);
    if (ctx->frame_offset >= ctx->frame_offset_boundary) {
        MEM_REALLOC(ctx->frame_offset_bottom, ctx->frame_offset_size,
                    ctx->frame_offset_size + 16);
        ctx->frame_offset_size += 16;
        ctx->frame_offset_boundary =
            ctx->frame_offset_bottom + ctx->frame_offset_size / sizeof(int16);
        ctx->frame_offset = ctx->frame_offset_bottom + cell_num;
    }
    return true;
fail:
    return false;
}

static bool
check_offset_pop(WASMLoaderContext *ctx, uint32 cells)
{
    if (ctx->frame_offset - cells < ctx->frame_offset_bottom)
        return false;
    return true;
}

static void
free_label_patch_list(BranchBlock *frame_csp)
{
    BranchBlockPatch *label_patch = frame_csp->patch_list;
    BranchBlockPatch *next;
    while (label_patch != NULL) {
        next = label_patch->next;
        wasm_runtime_free(label_patch);
        label_patch = next;
    }
    frame_csp->patch_list = NULL;
}

static void
free_all_label_patch_lists(BranchBlock *frame_csp, uint32 csp_num)
{
    BranchBlock *tmp_csp = frame_csp;
    uint32 i;

    for (i = 0; i < csp_num; i++) {
        free_label_patch_list(tmp_csp);
        tmp_csp++;
    }
}

static void
free_all_label_param_frame_offsets(BranchBlock *frame_csp, uint32 csp_num)
{
    BranchBlock *tmp_csp = frame_csp;
    uint32 i;

    for (i = 0; i < csp_num; i++) {
        if (tmp_csp->param_frame_offsets)
            wasm_runtime_free(tmp_csp->param_frame_offsets);
        tmp_csp++;
    }
}
#endif /* end of WASM_ENABLE_FAST_INTERP */

#if WASM_ENABLE_GC != 0
static bool
wasm_loader_init_local_use_masks(WASMLoaderContext *ctx, uint32 local_count,
                                 char *error_buf, uint32 error_buf_size)
{
    BranchBlock *current_csp = ctx->frame_csp - 1;
    uint32 local_mask_size;

    if (local_count == 0) {
        current_csp->local_use_mask_size = 0;
        return true;
    }

    /* if current_csp->local_use_mask is not NULL, then it is re-init masks for
     * else branch, we don't need to allocate memory again */
    if (!current_csp->local_use_mask) {
        local_mask_size = (local_count + 7) / sizeof(uint8);
        if (!(current_csp->local_use_mask =
                  loader_malloc(local_mask_size, error_buf, error_buf_size))) {
            return false;
        }
        current_csp->local_use_mask_size = local_mask_size;
    }
    else {
        local_mask_size = current_csp->local_use_mask_size;
        bh_assert(current_csp->label_type == LABEL_TYPE_IF);
    }

    if (current_csp->label_type != LABEL_TYPE_FUNCTION) {
        /* For non-function blocks, inherit the use status from parent block */
        BranchBlock *parent_csp = current_csp - 1;

        bh_assert(parent_csp >= ctx->frame_csp_bottom);
        bh_assert(parent_csp->local_use_mask);

        bh_memcpy_s(current_csp->local_use_mask, local_mask_size,
                    parent_csp->local_use_mask, local_mask_size);
    }

    return true;
}

static void
wasm_loader_destroy_curr_local_use_masks(WASMLoaderContext *ctx)
{
    BranchBlock *current_csp = ctx->frame_csp - 1;

    bh_assert(current_csp->local_use_mask
              || current_csp->local_use_mask_size == 0);

    if (current_csp->local_use_mask) {
        wasm_runtime_free(current_csp->local_use_mask);
    }

    current_csp->local_use_mask = NULL;
    current_csp->local_use_mask_size = 0;
}

static void
wasm_loader_clean_all_local_use_masks(WASMLoaderContext *ctx)
{
    BranchBlock *tmp_csp = ctx->frame_csp_bottom;
    uint32 i;

    for (i = 0; i < ctx->csp_num; i++) {
        if (tmp_csp->local_use_mask) {
            wasm_runtime_free(tmp_csp->local_use_mask);
            tmp_csp->local_use_mask = NULL;
            tmp_csp->local_use_mask_size = 0;
        }
        tmp_csp++;
    }
}

static void
wasm_loader_mask_local(WASMLoaderContext *ctx, uint32 index)
{
    BranchBlock *current_csp = ctx->frame_csp - 1;
    uint32 byte_offset = index / sizeof(uint8);
    uint32 bit_offset = index % sizeof(uint8);

    bh_assert(byte_offset < current_csp->local_use_mask_size);
    bh_assert(current_csp->local_use_mask);

    current_csp->local_use_mask[byte_offset] |= (1 << bit_offset);
}

static bool
wasm_loader_get_local_status(WASMLoaderContext *ctx, uint32 index)
{
    BranchBlock *current_csp = ctx->frame_csp - 1;
    uint32 byte_offset = index / sizeof(uint8);
    uint32 bit_offset = index % sizeof(uint8);

    bh_assert(byte_offset < current_csp->local_use_mask_size);
    bh_assert(current_csp->local_use_mask);

    return (current_csp->local_use_mask[byte_offset] & (1 << bit_offset))
               ? true
               : false;
}
#endif /* end of WASM_ENABLE_GC != 0 */

static void
wasm_loader_ctx_destroy(WASMLoaderContext *ctx)
{
    if (ctx) {
        if (ctx->frame_ref_bottom)
            wasm_runtime_free(ctx->frame_ref_bottom);
#if WASM_ENABLE_GC != 0
        if (ctx->frame_reftype_map_bottom)
            wasm_runtime_free(ctx->frame_reftype_map_bottom);
#endif
        if (ctx->frame_csp_bottom) {
#if WASM_ENABLE_FAST_INTERP != 0
            free_all_label_patch_lists(ctx->frame_csp_bottom, ctx->csp_num);
            free_all_label_param_frame_offsets(ctx->frame_csp_bottom,
                                               ctx->csp_num);
#endif
#if WASM_ENABLE_GC != 0
            wasm_loader_clean_all_local_use_masks(ctx);
#endif
            wasm_runtime_free(ctx->frame_csp_bottom);
        }
#if WASM_ENABLE_FAST_INTERP != 0
        if (ctx->frame_offset_bottom)
            wasm_runtime_free(ctx->frame_offset_bottom);
        if (ctx->i64_consts)
            wasm_runtime_free(ctx->i64_consts);
        if (ctx->i32_consts)
            wasm_runtime_free(ctx->i32_consts);
        if (ctx->v128_consts)
            wasm_runtime_free(ctx->v128_consts);
#endif
        wasm_runtime_free(ctx);
    }
}

static WASMLoaderContext *
wasm_loader_ctx_init(WASMFunction *func, char *error_buf, uint32 error_buf_size)
{
    WASMLoaderContext *loader_ctx =
        loader_malloc(sizeof(WASMLoaderContext), error_buf, error_buf_size);
    if (!loader_ctx)
        return NULL;

    loader_ctx->frame_ref_size = 32;
    if (!(loader_ctx->frame_ref_bottom = loader_ctx->frame_ref = loader_malloc(
              loader_ctx->frame_ref_size, error_buf, error_buf_size)))
        goto fail;
    loader_ctx->frame_ref_boundary = loader_ctx->frame_ref_bottom + 32;

#if WASM_ENABLE_GC != 0
    loader_ctx->frame_reftype_map_size = sizeof(WASMRefTypeMap) * 16;
    if (!(loader_ctx->frame_reftype_map_bottom = loader_ctx->frame_reftype_map =
              loader_malloc(loader_ctx->frame_reftype_map_size, error_buf,
                            error_buf_size)))
        goto fail;
    loader_ctx->frame_reftype_map_boundary =
        loader_ctx->frame_reftype_map_bottom + 16;
#endif

    loader_ctx->frame_csp_size = sizeof(BranchBlock) * 8;
    if (!(loader_ctx->frame_csp_bottom = loader_ctx->frame_csp = loader_malloc(
              loader_ctx->frame_csp_size, error_buf, error_buf_size)))
        goto fail;
    loader_ctx->frame_csp_boundary = loader_ctx->frame_csp_bottom + 8;

#if WASM_ENABLE_EXCE_HANDLING != 0
    func->exception_handler_count = 0;
#endif

#if WASM_ENABLE_FAST_INTERP != 0
    loader_ctx->frame_offset_size = sizeof(int16) * 32;
    if (!(loader_ctx->frame_offset_bottom = loader_ctx->frame_offset =
              loader_malloc(loader_ctx->frame_offset_size, error_buf,
                            error_buf_size)))
        goto fail;
    loader_ctx->frame_offset_boundary = loader_ctx->frame_offset_bottom + 32;

    loader_ctx->i64_const_max_num = 8;
    if (!(loader_ctx->i64_consts =
              loader_malloc(sizeof(int64) * loader_ctx->i64_const_max_num,
                            error_buf, error_buf_size)))
        goto fail;
    loader_ctx->i32_const_max_num = 8;
    if (!(loader_ctx->i32_consts =
              loader_malloc(sizeof(int32) * loader_ctx->i32_const_max_num,
                            error_buf, error_buf_size)))
        goto fail;
    loader_ctx->v128_const_max_num = 8;
    if (!(loader_ctx->v128_consts =
              loader_malloc(sizeof(V128) * loader_ctx->v128_const_max_num,
                            error_buf, error_buf_size)))
        goto fail;

    if (func->param_cell_num >= (int32)INT16_MAX - func->local_cell_num) {
        set_error_buf(error_buf, error_buf_size,
                      "fast interpreter offset overflow");
        goto fail;
    }

    loader_ctx->start_dynamic_offset = loader_ctx->dynamic_offset =
        loader_ctx->max_dynamic_offset =
            func->param_cell_num + func->local_cell_num;
#endif
    return loader_ctx;

fail:
    wasm_loader_ctx_destroy(loader_ctx);
    return NULL;
}

static bool
check_stack_push(WASMLoaderContext *ctx, uint8 type, char *error_buf,
                 uint32 error_buf_size)
{
    uint32 cell_num_needed = wasm_value_type_cell_num(type);

    if (ctx->frame_ref + cell_num_needed > ctx->frame_ref_boundary) {
        /* Increase the frame ref stack */
        MEM_REALLOC(ctx->frame_ref_bottom, ctx->frame_ref_size,
                    ctx->frame_ref_size + 16);
        ctx->frame_ref_size += 16;
        ctx->frame_ref_boundary = ctx->frame_ref_bottom + ctx->frame_ref_size;
        ctx->frame_ref = ctx->frame_ref_bottom + ctx->stack_cell_num;
    }

#if WASM_ENABLE_GC != 0
    if (wasm_is_type_multi_byte_type(type)
        && ctx->frame_reftype_map >= ctx->frame_reftype_map_boundary) {
        /* Increase the frame reftype map stack */
        bh_assert(
            (uint32)((ctx->frame_reftype_map - ctx->frame_reftype_map_bottom)
                     * sizeof(WASMRefTypeMap))
            == ctx->frame_reftype_map_size);
        MEM_REALLOC(ctx->frame_reftype_map_bottom, ctx->frame_reftype_map_size,
                    ctx->frame_reftype_map_size
                        + (uint32)sizeof(WASMRefTypeMap) * 8);
        ctx->frame_reftype_map =
            ctx->frame_reftype_map_bottom
            + ctx->frame_reftype_map_size / ((uint32)sizeof(WASMRefTypeMap));
        ctx->frame_reftype_map_size += (uint32)sizeof(WASMRefTypeMap) * 8;
        ctx->frame_reftype_map_boundary =
            ctx->frame_reftype_map_bottom
            + ctx->frame_reftype_map_size / ((uint32)sizeof(WASMRefTypeMap));
    }
#endif
    return true;
fail:
    return false;
}

static bool
wasm_loader_push_frame_ref(WASMLoaderContext *ctx, uint8 type, char *error_buf,
                           uint32 error_buf_size)
{
    uint32 type_cell_num = wasm_value_type_cell_num(type);
    uint32 i;

    if (!check_stack_push(ctx, type, error_buf, error_buf_size))
        return false;

#if WASM_ENABLE_GC != 0
    if (wasm_is_type_multi_byte_type(type)) {
        WASMRefType *ref_type;
        if (!(ref_type =
                  reftype_set_insert(ctx->ref_type_set, ctx->ref_type_tmp,
                                     error_buf, error_buf_size))) {
            return false;
        }

        if (ctx->frame_reftype_map >= ctx->frame_reftype_map_boundary) {
            /* Increase the frame reftype map stack */
            bh_assert((uint32)((ctx->frame_reftype_map
                                - ctx->frame_reftype_map_bottom)
                               * sizeof(WASMRefTypeMap))
                      == ctx->frame_reftype_map_size);
            MEM_REALLOC(ctx->frame_reftype_map_bottom,
                        ctx->frame_reftype_map_size,
                        ctx->frame_reftype_map_size
                            + (uint32)sizeof(WASMRefTypeMap) * 8);
            ctx->frame_reftype_map = ctx->frame_reftype_map_bottom
                                     + ctx->frame_reftype_map_size
                                           / ((uint32)sizeof(WASMRefTypeMap));
            ctx->frame_reftype_map_size += (uint32)sizeof(WASMRefTypeMap) * 8;
            ctx->frame_reftype_map_boundary =
                ctx->frame_reftype_map_bottom
                + ctx->frame_reftype_map_size
                      / ((uint32)sizeof(WASMRefTypeMap));
        }

        ctx->frame_reftype_map->index = ctx->stack_cell_num;
        ctx->frame_reftype_map->ref_type = ref_type;
        ctx->frame_reftype_map++;
        ctx->reftype_map_num++;
        if (ctx->reftype_map_num > ctx->max_reftype_map_num)
            ctx->max_reftype_map_num = ctx->reftype_map_num;
    }
#endif

    for (i = 0; i < type_cell_num; i++)
        *ctx->frame_ref++ = type;
    ctx->stack_cell_num += type_cell_num;

    if (ctx->stack_cell_num > ctx->max_stack_cell_num) {
        ctx->max_stack_cell_num = ctx->stack_cell_num;
        if (ctx->max_stack_cell_num > UINT16_MAX) {
            set_error_buf(error_buf, error_buf_size,
                          "operand stack depth limit exceeded");
            return false;
        }
    }
    return true;
#if WASM_ENABLE_GC != 0
fail:
    return false;
#endif
}

static bool
check_stack_top_values(WASMLoaderContext *ctx, uint8 *frame_ref,
                       int32 stack_cell_num,
#if WASM_ENABLE_GC != 0
                       WASMRefTypeMap *frame_reftype_map, int32 reftype_map_num,
#endif
                       uint8 type,
#if WASM_ENABLE_GC != 0
                       WASMRefType *ref_type,
#endif
                       char *error_buf, uint32 error_buf_size)
{
    int32 type_cell_num = (int32)wasm_value_type_cell_num(type), i;
#if WASM_ENABLE_GC != 0
    WASMRefType *frame_reftype = NULL;
#endif

    if (stack_cell_num < type_cell_num) {
        set_error_buf(error_buf, error_buf_size,
                      "type mismatch: expect data but stack was empty");
        return false;
    }

#if WASM_ENABLE_GC == 0
    for (i = 0; i < type_cell_num; i++) {
        if (*(frame_ref - 1 - i) != type) {
            set_error_buf_v(error_buf, error_buf_size, "%s%s%s",
                            "type mismatch: expect ", type2str(type),
                            " but got other");
            return false;
        }
    }
#else
    if (wasm_is_type_multi_byte_type(*(frame_ref - 1))) {
        bh_assert(reftype_map_num > 0);
        frame_reftype = (frame_reftype_map - 1)->ref_type;
    }
    if (!wasm_reftype_is_subtype_of(*(frame_ref - 1), frame_reftype, type,
                                    ref_type, ctx->module->types,
                                    ctx->module->type_count)) {
        set_error_buf_v(error_buf, error_buf_size, "%s%s%s",
                        "type mismatch: expect ", type2str(type),
                        " but got other");
        return false;
    }
    for (i = 0; i < type_cell_num - 1; i++) {
        if (*(frame_ref - 2 - i) != *(frame_ref - 1)) {
            set_error_buf_v(error_buf, error_buf_size, "%s%s%s",
                            "type mismatch: expect ", type2str(type),
                            " but got other");
            return false;
        }
    }
#endif

    return true;
}

static bool
check_stack_pop(WASMLoaderContext *ctx, uint8 type, char *error_buf,
                uint32 error_buf_size)
{
    int32 block_stack_cell_num =
        (int32)(ctx->stack_cell_num - (ctx->frame_csp - 1)->stack_cell_num);
#if WASM_ENABLE_GC != 0
    int32 reftype_map_num =
        (int32)(ctx->reftype_map_num - (ctx->frame_csp - 1)->reftype_map_num);
#endif

    if (block_stack_cell_num > 0) {
        if (*(ctx->frame_ref - 1) == VALUE_TYPE_ANY)
            /* the stack top is a value of any type, return success */
            return true;
    }

#if WASM_ENABLE_GC != 0
    if (wasm_is_type_reftype(type) && block_stack_cell_num > 0) {
        uint8 stack_top_type = *(ctx->frame_ref - 1);
        WASMRefType *stack_top_ref_type = NULL;

        if (wasm_is_type_multi_byte_type(stack_top_type)) {
            bh_assert(reftype_map_num > 0);
            stack_top_ref_type = (*(ctx->frame_reftype_map - 1)).ref_type;
        }

        if (wasm_reftype_is_subtype_of(stack_top_type, stack_top_ref_type, type,
                                       ctx->ref_type_tmp, ctx->module->types,
                                       ctx->module->type_count)) {
            if (wasm_is_type_multi_byte_type(stack_top_type)) {
                uint32 ref_type_struct_size =
                    wasm_reftype_struct_size(stack_top_ref_type);
                bh_memcpy_s(ctx->ref_type_tmp, (uint32)sizeof(WASMRefType),
                            stack_top_ref_type, ref_type_struct_size);
            }
            return true;
        }
    }
#endif

    if (!check_stack_top_values(ctx, ctx->frame_ref, block_stack_cell_num,
#if WASM_ENABLE_GC != 0
                                ctx->frame_reftype_map, reftype_map_num,
#endif
                                type,
#if WASM_ENABLE_GC != 0
                                ctx->ref_type_tmp,
#endif
                                error_buf, error_buf_size)) {
        return false;
    }

    return true;
}

static bool
wasm_loader_pop_frame_ref(WASMLoaderContext *ctx, uint8 type, char *error_buf,
                          uint32 error_buf_size)
{
    BranchBlock *cur_block = ctx->frame_csp - 1;
    int32 available_stack_cell =
        (int32)(ctx->stack_cell_num - cur_block->stack_cell_num);
    uint32 cell_num_to_pop = wasm_value_type_cell_num(type);

    /* Directly return success if current block is in stack
       polymorphic state while stack is empty. */
    if (available_stack_cell <= 0 && cur_block->is_stack_polymorphic)
        return true;

    if (type == VALUE_TYPE_VOID)
        return true;

    if (!check_stack_pop(ctx, type, error_buf, error_buf_size))
        return false;

    bh_assert(available_stack_cell > 0);
    if (*(ctx->frame_ref - 1) == VALUE_TYPE_ANY) {
        type = VALUE_TYPE_ANY;
        cell_num_to_pop = 1;
    }

    ctx->frame_ref -= cell_num_to_pop;
    ctx->stack_cell_num -= cell_num_to_pop;
#if WASM_ENABLE_GC != 0
    if (wasm_is_type_multi_byte_type(*ctx->frame_ref)) {
        ctx->frame_reftype_map--;
        ctx->reftype_map_num--;
    }
#endif

    return true;
}

#if WASM_ENABLE_GC != 0
/* Get the stack top element of current block */
static bool
wasm_loader_get_frame_ref_top(WASMLoaderContext *ctx, uint8 *p_type,
                              WASMRefType **p_ref_type, char *error_buf,
                              uint32 error_buf_size)
{
    BranchBlock *cur_block = ctx->frame_csp - 1;
    int32 available_stack_cell =
        (int32)(ctx->stack_cell_num - cur_block->stack_cell_num);

    if (available_stack_cell <= 0) {
        /* Directly return success if current block is in stack
           polymorphic state while stack is empty. */
        if (cur_block->is_stack_polymorphic) {
            *p_type = VALUE_TYPE_ANY;
            return true;
        }
        else {
            set_error_buf(
                error_buf, error_buf_size,
                "type mismatch: expect data but block stack was empty");
            return false;
        }
    }

    *p_type = *(ctx->frame_ref - 1);
    if (wasm_is_type_multi_byte_type(*p_type)) {
        int32 available_reftype_map =
            (int32)(ctx->reftype_map_num
                    - (ctx->frame_csp - 1)->reftype_map_num);
        bh_assert(available_reftype_map > 0);
        (void)available_reftype_map;
        *p_ref_type = (ctx->frame_reftype_map - 1)->ref_type;
    }

    return true;
}

#if WASM_ENABLE_FAST_INTERP != 0
static bool
wasm_loader_pop_frame_ref_offset(WASMLoaderContext *ctx, uint8 type,
                                 char *error_buf, uint32 error_buf_size);
#endif

/* Check whether the stack top elem is a heap object, and if yes,
   pop and return it */
static bool
wasm_loader_pop_heap_obj(WASMLoaderContext *ctx, uint8 *p_type,
                         WASMRefType *ref_ht_ret, char *error_buf,
                         uint32 error_buf_size)
{
    uint8 type = 0;
    WASMRefType *ref_type = NULL;

    /* Get stack top element */
    if (!wasm_loader_get_frame_ref_top(ctx, &type, &ref_type, error_buf,
                                       error_buf_size)) {
        return false;
    }

    if (type != VALUE_TYPE_ANY /* block isn't in stack polymorphic state */
        /* stack top isn't a ref type */
        && !wasm_is_type_reftype(type)) {
        set_error_buf(error_buf, error_buf_size,
                      "type mismatch: expect heap object but got others");
        return false;
    }

    /* POP stack top */
    if (wasm_is_type_multi_byte_type(type)) {
        bh_assert(ref_type);
        bh_memcpy_s(ctx->ref_type_tmp, sizeof(WASMRefType), ref_type,
                    wasm_reftype_struct_size(ref_type));
    }

#if WASM_ENABLE_FAST_INTERP != 0
    if (!wasm_loader_pop_frame_ref_offset(ctx, type, error_buf,
                                          error_buf_size)) {
        return false;
    }
#else
    if (!wasm_loader_pop_frame_ref(ctx, type, error_buf, error_buf_size)) {
        return false;
    }
#endif

    if (p_type)
        *p_type = type;
    if (wasm_is_type_multi_byte_type(type) && ref_ht_ret) {
        bh_memcpy_s(ref_ht_ret, sizeof(WASMRefType), ref_type,
                    wasm_reftype_struct_size(ref_type));
    }
    return true;
}

/* Check whether the stack top elem is subtype of (ref null ht),
   and if yes, pop it and return the converted (ref ht) */
static bool
wasm_loader_pop_nullable_ht(WASMLoaderContext *ctx, uint8 *p_type,
                            WASMRefType *ref_ht_ret, char *error_buf,
                            uint32 error_buf_size)
{
    uint8 type = 0;
    WASMRefType ref_type = { 0 };

    if (!wasm_loader_pop_heap_obj(ctx, &type, &ref_type, error_buf,
                                  error_buf_size)) {
        return false;
    }

    /* Convert to related (ref ht) and return */
    if (type >= REF_TYPE_ARRAYREF && type <= REF_TYPE_NULLFUNCREF) {
        /* Return (ref array/struct/i31/eq/any/extern/func/none/noextern/nofunc)
         */
        wasm_set_refheaptype_common(&ref_ht_ret->ref_ht_common, false,
                                    HEAP_TYPE_ARRAY
                                        + (type - REF_TYPE_ARRAYREF));
        type = ref_ht_ret->ref_type;
    }
    else if (wasm_is_reftype_htref_nullable(type)
             || wasm_is_reftype_htref_non_nullable(type)) {
        bh_memcpy_s(ref_ht_ret, (uint32)sizeof(WASMRefType), &ref_type,
                    wasm_reftype_struct_size(&ref_type));
        /* Convert to (ref ht) */
        ref_ht_ret->ref_ht_common.ref_type = REF_TYPE_HT_NON_NULLABLE;
        ref_ht_ret->ref_ht_common.nullable = false;
        type = ref_ht_ret->ref_type;
    }
    *p_type = type;

    return true;
}

/* Check whether the stack top elem is (ref null $t) or (ref $t),
   and if yes, pop it and return the type_idx */
static bool
wasm_loader_pop_nullable_typeidx(WASMLoaderContext *ctx, uint8 *p_type,
                                 uint32 *p_type_idx, char *error_buf,
                                 uint32 error_buf_size)
{
    uint8 type = 0;
    int32 type_idx = -1;
    WASMRefType *ref_type = NULL;

    /* Get stack top element */
    if (!wasm_loader_get_frame_ref_top(ctx, &type, &ref_type, error_buf,
                                       error_buf_size)) {
        return false;
    }

    if (type != VALUE_TYPE_ANY) {
        /* stack top isn't (ref null $t) */
        if (!((wasm_is_reftype_htref_nullable(type)
               || wasm_is_reftype_htref_non_nullable(type))
              && wasm_is_refheaptype_typeidx(&ref_type->ref_ht_common))) {
            set_error_buf(error_buf, error_buf_size,
                          "type mismatch: expect (ref null $t) but got others");
            return false;
        }
        type_idx = ref_type->ref_ht_typeidx.type_idx;

        bh_memcpy_s(ctx->ref_type_tmp, sizeof(WASMRefType), ref_type,
                    wasm_reftype_struct_size(ref_type));
    }

    /* POP stack top */
#if WASM_ENABLE_FAST_INTERP != 0
    if (!wasm_loader_pop_frame_ref_offset(ctx, type, error_buf,
                                          error_buf_size)) {
        return false;
    }
#else
    if (!wasm_loader_pop_frame_ref(ctx, type, error_buf, error_buf_size)) {
        return false;
    }
#endif

    /* Convert to type_idx and return */
    *p_type = type;
    if (type != VALUE_TYPE_ANY)
        *p_type_idx = (uint32)type_idx;
    return true;
}
#endif /* WASM_ENABLE_GC != 0 */

#if WASM_ENABLE_FAST_INTERP == 0
static bool
wasm_loader_push_pop_frame_ref(WASMLoaderContext *ctx, uint8 pop_cnt,
                               uint8 type_push, uint8 type_pop, char *error_buf,
                               uint32 error_buf_size)
{
    for (int i = 0; i < pop_cnt; i++) {
        if (!wasm_loader_pop_frame_ref(ctx, type_pop, error_buf,
                                       error_buf_size))
            return false;
    }
    if (!wasm_loader_push_frame_ref(ctx, type_push, error_buf, error_buf_size))
        return false;
    return true;
}
#endif

static bool
wasm_loader_push_frame_csp(WASMLoaderContext *ctx, uint8 label_type,
                           BlockType block_type, uint8 *start_addr,
                           char *error_buf, uint32 error_buf_size)
{
    CHECK_CSP_PUSH();
    memset(ctx->frame_csp, 0, sizeof(BranchBlock));
    ctx->frame_csp->label_type = label_type;
    ctx->frame_csp->block_type = block_type;
    ctx->frame_csp->start_addr = start_addr;
    ctx->frame_csp->stack_cell_num = ctx->stack_cell_num;
#if WASM_ENABLE_GC != 0
    ctx->frame_csp->reftype_map_num = ctx->reftype_map_num;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
    ctx->frame_csp->dynamic_offset = ctx->dynamic_offset;
    ctx->frame_csp->patch_list = NULL;
#endif
    ctx->frame_csp++;
    ctx->csp_num++;
    if (ctx->csp_num > ctx->max_csp_num) {
        ctx->max_csp_num = ctx->csp_num;
        if (ctx->max_csp_num > UINT16_MAX) {
            set_error_buf(error_buf, error_buf_size,
                          "label stack depth limit exceeded");
            return false;
        }
    }
    return true;
fail:
    return false;
}

static bool
wasm_loader_pop_frame_csp(WASMLoaderContext *ctx, char *error_buf,
                          uint32 error_buf_size)
{
    CHECK_CSP_POP();
#if WASM_ENABLE_FAST_INTERP != 0
    if ((ctx->frame_csp - 1)->param_frame_offsets)
        wasm_runtime_free((ctx->frame_csp - 1)->param_frame_offsets);
#endif
    ctx->frame_csp--;
    ctx->csp_num--;

    return true;
fail:
    return false;
}

#if WASM_ENABLE_FAST_INTERP != 0

#if WASM_ENABLE_LABELS_AS_VALUES != 0
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
#define emit_label(opcode)                                      \
    do {                                                        \
        wasm_loader_emit_ptr(loader_ctx, handle_table[opcode]); \
        LOG_OP("\nemit_op [%02x]\t", opcode);                   \
    } while (0)
#define skip_label()                                            \
    do {                                                        \
        wasm_loader_emit_backspace(loader_ctx, sizeof(void *)); \
        LOG_OP("\ndelete last op\n");                           \
    } while (0)
#else /* else of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#if UINTPTR_MAX == UINT64_MAX
#define emit_label(opcode)                                                     \
    do {                                                                       \
        int32 offset =                                                         \
            (int32)((uint8 *)handle_table[opcode] - (uint8 *)handle_table[0]); \
        /* emit int32 relative offset in 64-bit target */                      \
        wasm_loader_emit_uint32(loader_ctx, offset);                           \
        LOG_OP("\nemit_op [%02x]\t", opcode);                                  \
    } while (0)
#else
#define emit_label(opcode)                                           \
    do {                                                             \
        uint32 label_addr = (uint32)(uintptr_t)handle_table[opcode]; \
        /* emit uint32 label address in 32-bit target */             \
        wasm_loader_emit_uint32(loader_ctx, label_addr);             \
        LOG_OP("\nemit_op [%02x]\t", opcode);                        \
    } while (0)
#endif
#define skip_label()                                           \
    do {                                                       \
        wasm_loader_emit_backspace(loader_ctx, sizeof(int32)); \
        LOG_OP("\ndelete last op\n");                          \
    } while (0)
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#else  /* else of WASM_ENABLE_LABELS_AS_VALUES */
#define emit_label(opcode)                          \
    do {                                            \
        wasm_loader_emit_uint8(loader_ctx, opcode); \
        LOG_OP("\nemit_op [%02x]\t", opcode);       \
    } while (0)
#define skip_label()                                           \
    do {                                                       \
        wasm_loader_emit_backspace(loader_ctx, sizeof(uint8)); \
        LOG_OP("\ndelete last op\n");                          \
    } while (0)
#endif /* end of WASM_ENABLE_LABELS_AS_VALUES */

#define emit_empty_label_addr_and_frame_ip(type)                             \
    do {                                                                     \
        if (!add_label_patch_to_list(loader_ctx->frame_csp - 1, type,        \
                                     loader_ctx->p_code_compiled, error_buf, \
                                     error_buf_size))                        \
            goto fail;                                                       \
        /* label address, to be patched */                                   \
        wasm_loader_emit_ptr(loader_ctx, NULL);                              \
    } while (0)

#define emit_br_info(frame_csp, is_br)                                         \
    do {                                                                       \
        if (!wasm_loader_emit_br_info(loader_ctx, frame_csp, is_br, error_buf, \
                                      error_buf_size))                         \
            goto fail;                                                         \
    } while (0)

#define LAST_OP_OUTPUT_I32()                                                   \
    (last_op >= WASM_OP_I32_EQZ && last_op <= WASM_OP_I32_ROTR)                \
        || (last_op == WASM_OP_I32_LOAD || last_op == WASM_OP_F32_LOAD)        \
        || (last_op >= WASM_OP_I32_LOAD8_S && last_op <= WASM_OP_I32_LOAD16_U) \
        || (last_op >= WASM_OP_F32_ABS && last_op <= WASM_OP_F32_COPYSIGN)     \
        || (last_op >= WASM_OP_I32_WRAP_I64                                    \
            && last_op <= WASM_OP_I32_TRUNC_U_F64)                             \
        || (last_op >= WASM_OP_F32_CONVERT_S_I32                               \
            && last_op <= WASM_OP_F32_DEMOTE_F64)                              \
        || (last_op == WASM_OP_I32_REINTERPRET_F32)                            \
        || (last_op == WASM_OP_F32_REINTERPRET_I32)                            \
        || (last_op == EXT_OP_COPY_STACK_TOP)

#define LAST_OP_OUTPUT_I64()                                                   \
    (last_op >= WASM_OP_I64_CLZ && last_op <= WASM_OP_I64_ROTR)                \
        || (last_op >= WASM_OP_F64_ABS && last_op <= WASM_OP_F64_COPYSIGN)     \
        || (last_op == WASM_OP_I64_LOAD || last_op == WASM_OP_F64_LOAD)        \
        || (last_op >= WASM_OP_I64_LOAD8_S && last_op <= WASM_OP_I64_LOAD32_U) \
        || (last_op >= WASM_OP_I64_EXTEND_S_I32                                \
            && last_op <= WASM_OP_I64_TRUNC_U_F64)                             \
        || (last_op >= WASM_OP_F64_CONVERT_S_I32                               \
            && last_op <= WASM_OP_F64_PROMOTE_F32)                             \
        || (last_op == WASM_OP_I64_REINTERPRET_F64)                            \
        || (last_op == WASM_OP_F64_REINTERPRET_I64)                            \
        || (last_op == EXT_OP_COPY_STACK_TOP_I64)

#define GET_CONST_OFFSET(type, val)                                    \
    do {                                                               \
        if (!(wasm_loader_get_const_offset(loader_ctx, type, &val,     \
                                           &operand_offset, error_buf, \
                                           error_buf_size)))           \
            goto fail;                                                 \
    } while (0)

#define GET_CONST_F32_OFFSET(type, fval)                               \
    do {                                                               \
        if (!(wasm_loader_get_const_offset(loader_ctx, type, &fval,    \
                                           &operand_offset, error_buf, \
                                           error_buf_size)))           \
            goto fail;                                                 \
    } while (0)

#define GET_CONST_F64_OFFSET(type, fval)                               \
    do {                                                               \
        if (!(wasm_loader_get_const_offset(loader_ctx, type, &fval,    \
                                           &operand_offset, error_buf, \
                                           error_buf_size)))           \
            goto fail;                                                 \
    } while (0)

#define emit_operand(ctx, offset)            \
    do {                                     \
        wasm_loader_emit_int16(ctx, offset); \
        LOG_OP("%d\t", offset);              \
    } while (0)

#define emit_byte(ctx, byte)               \
    do {                                   \
        wasm_loader_emit_uint8(ctx, byte); \
        LOG_OP("%d\t", byte);              \
    } while (0)

#define emit_uint32(ctx, value)              \
    do {                                     \
        wasm_loader_emit_uint32(ctx, value); \
        LOG_OP("%d\t", value);               \
    } while (0)

#define emit_uint64(ctx, value)                     \
    do {                                            \
        wasm_loader_emit_const(ctx, &value, false); \
        LOG_OP("%lld\t", value);                    \
    } while (0)

#define emit_float32(ctx, value)                   \
    do {                                           \
        wasm_loader_emit_const(ctx, &value, true); \
        LOG_OP("%f\t", value);                     \
    } while (0)

#define emit_float64(ctx, value)                    \
    do {                                            \
        wasm_loader_emit_const(ctx, &value, false); \
        LOG_OP("%f\t", value);                      \
    } while (0)

static bool
wasm_loader_ctx_reinit(WASMLoaderContext *ctx)
{
    if (!(ctx->p_code_compiled =
              loader_malloc(ctx->code_compiled_peak_size, NULL, 0)))
        return false;
    ctx->p_code_compiled_end =
        ctx->p_code_compiled + ctx->code_compiled_peak_size;

    /* clean up frame ref */
    memset(ctx->frame_ref_bottom, 0, ctx->frame_ref_size);
    ctx->frame_ref = ctx->frame_ref_bottom;
    ctx->stack_cell_num = 0;

#if WASM_ENABLE_GC != 0
    /* clean up reftype map */
    memset(ctx->frame_reftype_map_bottom, 0, ctx->frame_reftype_map_size);
    ctx->frame_reftype_map = ctx->frame_reftype_map_bottom;
    ctx->reftype_map_num = 0;
#endif

    /* clean up frame csp */
    memset(ctx->frame_csp_bottom, 0, ctx->frame_csp_size);
    ctx->frame_csp = ctx->frame_csp_bottom;
    ctx->csp_num = 0;
    ctx->max_csp_num = 0;

    /* clean up frame offset */
    memset(ctx->frame_offset_bottom, 0, ctx->frame_offset_size);
    ctx->frame_offset = ctx->frame_offset_bottom;
    ctx->dynamic_offset = ctx->start_dynamic_offset;

    /* init preserved local offsets */
    ctx->preserved_local_offset = ctx->max_dynamic_offset;

    /* const buf is reserved */
    return true;
}

static void
increase_compiled_code_space(WASMLoaderContext *ctx, int32 size)
{
    ctx->code_compiled_size += size;
    if (ctx->code_compiled_size >= ctx->code_compiled_peak_size) {
        ctx->code_compiled_peak_size = ctx->code_compiled_size;
    }
}

static void
wasm_loader_emit_const(WASMLoaderContext *ctx, void *value, bool is_32_bit)
{
    uint32 size = is_32_bit ? sizeof(uint32) : sizeof(uint64);

    if (ctx->p_code_compiled) {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert(((uintptr_t)ctx->p_code_compiled & 1) == 0);
#endif
        bh_memcpy_s(ctx->p_code_compiled,
                    (uint32)(ctx->p_code_compiled_end - ctx->p_code_compiled),
                    value, size);
        ctx->p_code_compiled += size;
    }
    else {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert((ctx->code_compiled_size & 1) == 0);
#endif
        increase_compiled_code_space(ctx, size);
    }
}

static void
wasm_loader_emit_uint32(WASMLoaderContext *ctx, uint32 value)
{
    if (ctx->p_code_compiled) {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert(((uintptr_t)ctx->p_code_compiled & 1) == 0);
#endif
        STORE_U32(ctx->p_code_compiled, value);
        ctx->p_code_compiled += sizeof(uint32);
    }
    else {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert((ctx->code_compiled_size & 1) == 0);
#endif
        increase_compiled_code_space(ctx, sizeof(uint32));
    }
}

static void
wasm_loader_emit_int16(WASMLoaderContext *ctx, int16 value)
{
    if (ctx->p_code_compiled) {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert(((uintptr_t)ctx->p_code_compiled & 1) == 0);
#endif
        STORE_U16(ctx->p_code_compiled, (uint16)value);
        ctx->p_code_compiled += sizeof(int16);
    }
    else {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert((ctx->code_compiled_size & 1) == 0);
#endif
        increase_compiled_code_space(ctx, sizeof(uint16));
    }
}

static void
wasm_loader_emit_uint8(WASMLoaderContext *ctx, uint8 value)
{
    if (ctx->p_code_compiled) {
        *(ctx->p_code_compiled) = value;
        ctx->p_code_compiled += sizeof(uint8);
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        ctx->p_code_compiled++;
        bh_assert(((uintptr_t)ctx->p_code_compiled & 1) == 0);
#endif
    }
    else {
        increase_compiled_code_space(ctx, sizeof(uint8));
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        increase_compiled_code_space(ctx, sizeof(uint8));
        bh_assert((ctx->code_compiled_size & 1) == 0);
#endif
    }
}

static void
wasm_loader_emit_ptr(WASMLoaderContext *ctx, void *value)
{
    if (ctx->p_code_compiled) {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert(((uintptr_t)ctx->p_code_compiled & 1) == 0);
#endif
        STORE_PTR(ctx->p_code_compiled, value);
        ctx->p_code_compiled += sizeof(void *);
    }
    else {
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        bh_assert((ctx->code_compiled_size & 1) == 0);
#endif
        increase_compiled_code_space(ctx, sizeof(void *));
    }
}

static void
wasm_loader_emit_backspace(WASMLoaderContext *ctx, uint32 size)
{
    if (ctx->p_code_compiled) {
        ctx->p_code_compiled -= size;
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        if (size == sizeof(uint8)) {
            ctx->p_code_compiled--;
            bh_assert(((uintptr_t)ctx->p_code_compiled & 1) == 0);
        }
#endif
    }
    else {
        ctx->code_compiled_size -= size;
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        if (size == sizeof(uint8)) {
            ctx->code_compiled_size--;
            bh_assert((ctx->code_compiled_size & 1) == 0);
        }
#endif
    }
}

static bool
preserve_referenced_local(WASMLoaderContext *loader_ctx, uint8 opcode,
                          uint32 local_index, uint32 local_type,
                          bool *preserved, char *error_buf,
                          uint32 error_buf_size)
{

    uint32 i = 0;
    int16 preserved_offset = (int16)local_index;

    *preserved = false;
    while (i < loader_ctx->stack_cell_num) {
        uint8 cur_type = loader_ctx->frame_ref_bottom[i];

        /* move previous local into dynamic space before a set/tee_local opcode
         */
        if (loader_ctx->frame_offset_bottom[i] == (int16)local_index) {
            if (!(*preserved)) {
                *preserved = true;
                skip_label();
                preserved_offset = loader_ctx->preserved_local_offset;
                if (loader_ctx->p_code_compiled) {
                    bh_assert(preserved_offset != (int16)local_index);
                }
                if (is_32bit_type(local_type)) {
                    /* Only increase preserve offset in the second traversal */
                    if (loader_ctx->p_code_compiled)
                        loader_ctx->preserved_local_offset++;
                    emit_label(EXT_OP_COPY_STACK_TOP);
                }
#if WASM_ENABLE_SIMDE != 0
                else if (local_type == VALUE_TYPE_V128) {
                    if (loader_ctx->p_code_compiled)
                        loader_ctx->preserved_local_offset += 4;
                    emit_label(EXT_OP_COPY_STACK_TOP_V128);
                }
#endif
                else {
                    if (loader_ctx->p_code_compiled)
                        loader_ctx->preserved_local_offset += 2;
                    emit_label(EXT_OP_COPY_STACK_TOP_I64);
                }

                /* overflow */
                if (preserved_offset > loader_ctx->preserved_local_offset) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "too much local cells 0x%x",
                                    loader_ctx->preserved_local_offset);
                    return false;
                }

                emit_operand(loader_ctx, local_index);
                emit_operand(loader_ctx, preserved_offset);
                emit_label(opcode);
            }
            loader_ctx->frame_offset_bottom[i] = preserved_offset;
        }

        if (cur_type == VALUE_TYPE_V128) {
            i += 4;
        }
        else if (is_32bit_type(cur_type)) {
            i++;
        }
        else {
            i += 2;
        }
    }

    (void)error_buf;
    (void)error_buf_size;
    return true;
}

static bool
preserve_local_for_block(WASMLoaderContext *loader_ctx, uint8 opcode,
                         char *error_buf, uint32 error_buf_size)
{
    uint32 i = 0;
    bool preserve_local;

    /* preserve locals before blocks to ensure that "tee/set_local" inside
        blocks will not influence the value of these locals */
    uint32 frame_offset_cell =
        (uint32)(loader_ctx->frame_offset - loader_ctx->frame_offset_bottom);
    uint32 frame_ref_cell =
        (uint32)(loader_ctx->frame_ref - loader_ctx->frame_ref_bottom);
    if (frame_offset_cell < loader_ctx->stack_cell_num
        || frame_ref_cell < loader_ctx->stack_cell_num) {
        set_error_buf(error_buf, error_buf_size, "stack cell num error");
        return false;
    }

    while (i < loader_ctx->stack_cell_num) {
        int16 cur_offset = loader_ctx->frame_offset_bottom[i];
        uint8 cur_type = loader_ctx->frame_ref_bottom[i];

        if ((cur_offset < loader_ctx->start_dynamic_offset)
            && (cur_offset >= 0)) {
            if (!(preserve_referenced_local(loader_ctx, opcode, cur_offset,
                                            cur_type, &preserve_local,
                                            error_buf, error_buf_size)))
                return false;
        }

        if (cur_type == VALUE_TYPE_V128) {
            i += 4;
        }
        else if (is_32bit_type(cur_type)) {
            i++;
        }
        else {
            i += 2;
        }
    }

    return true;
}

static bool
add_label_patch_to_list(BranchBlock *frame_csp, uint8 patch_type,
                        uint8 *p_code_compiled, char *error_buf,
                        uint32 error_buf_size)
{
    BranchBlockPatch *patch =
        loader_malloc(sizeof(BranchBlockPatch), error_buf, error_buf_size);
    if (!patch) {
        return false;
    }
    patch->patch_type = patch_type;
    patch->code_compiled = p_code_compiled;
    if (!frame_csp->patch_list) {
        frame_csp->patch_list = patch;
        patch->next = NULL;
    }
    else {
        patch->next = frame_csp->patch_list;
        frame_csp->patch_list = patch;
    }
    return true;
}

static void
apply_label_patch(WASMLoaderContext *ctx, uint8 depth, uint8 patch_type)
{
    BranchBlock *frame_csp = ctx->frame_csp - depth;
    BranchBlockPatch *node = frame_csp->patch_list;
    BranchBlockPatch *node_prev = NULL, *node_next;

    if (!ctx->p_code_compiled)
        return;

    while (node) {
        node_next = node->next;
        if (node->patch_type == patch_type) {
            STORE_PTR(node->code_compiled, ctx->p_code_compiled);
            if (node_prev == NULL) {
                frame_csp->patch_list = node_next;
            }
            else {
                node_prev->next = node_next;
            }
            wasm_runtime_free(node);
        }
        else {
            node_prev = node;
        }
        node = node_next;
    }
}

static bool
wasm_loader_emit_br_info(WASMLoaderContext *ctx, BranchBlock *frame_csp,
                         bool is_br, char *error_buf, uint32 error_buf_size)
{
    /* br info layout:
     *  a) arity of target block
     *  b) total cell num of arity values
     *  c) each arity value's cell num
     *  d) each arity value's src frame offset
     *  e) each arity values's dst dynamic offset
     *  f) branch target address
     *
     *  Note: b-e are omitted when arity is 0 so that
     *  interpreter can recover the br info quickly.
     */
    BlockType *block_type = &frame_csp->block_type;
    uint8 *types = NULL, cell;
#if WASM_ENABLE_GC != 0
    WASMRefTypeMap *reftype_maps;
    uint32 reftype_map_count;
#endif
    uint32 arity = 0;
    int32 i;
    int16 *frame_offset = ctx->frame_offset;
    uint16 dynamic_offset;

    /* Note: loop's arity is different from if and block. loop's arity is
     * its parameter count while if and block arity is result count.
     */
#if WASM_ENABLE_GC == 0
    if (frame_csp->label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(block_type, &types);
    else
        arity = block_type_get_result_types(block_type, &types);
#else
    if (frame_csp->label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(block_type, &types, &reftype_maps,
                                           &reftype_map_count);
    else
        arity = block_type_get_result_types(block_type, &types, &reftype_maps,
                                            &reftype_map_count);
#endif

    /* Part a */
    emit_uint32(ctx, arity);

    if (arity) {
        /* Part b */
        emit_uint32(ctx, wasm_get_cell_num(types, arity));
        /* Part c */
        for (i = (int32)arity - 1; i >= 0; i--) {
            cell = (uint8)wasm_value_type_cell_num(types[i]);
            emit_byte(ctx, cell);
        }
        /* Part d */
        for (i = (int32)arity - 1; i >= 0; i--) {
            cell = (uint8)wasm_value_type_cell_num(types[i]);
            frame_offset -= cell;
            emit_operand(ctx, *(int16 *)(frame_offset));
        }
        /* Part e */
        if (frame_csp->label_type == LABEL_TYPE_LOOP)
            /* Use start_dynamic_offset which was set in
               copy_params_to_dynamic_space */
            dynamic_offset = frame_csp->start_dynamic_offset
                             + wasm_get_cell_num(types, arity);
        else
            dynamic_offset =
                frame_csp->dynamic_offset + wasm_get_cell_num(types, arity);
        if (is_br)
            ctx->dynamic_offset = dynamic_offset;
        for (i = (int32)arity - 1; i >= 0; i--) {
            cell = (uint8)wasm_value_type_cell_num(types[i]);
            dynamic_offset -= cell;
            emit_operand(ctx, dynamic_offset);
        }
    }

    /* Part f */
    if (frame_csp->label_type == LABEL_TYPE_LOOP) {
        wasm_loader_emit_ptr(ctx, frame_csp->code_compiled);
    }
    else {
        if (!add_label_patch_to_list(frame_csp, PATCH_END, ctx->p_code_compiled,
                                     error_buf, error_buf_size))
            return false;
        /* label address, to be patched */
        wasm_loader_emit_ptr(ctx, NULL);
    }

    return true;
}

static bool
wasm_loader_push_frame_offset(WASMLoaderContext *ctx, uint8 type,
                              bool disable_emit, int16 operand_offset,
                              char *error_buf, uint32 error_buf_size)
{
    uint32 cell_num_to_push, i;

    if (type == VALUE_TYPE_VOID)
        return true;

    /* only check memory overflow in first traverse */
    if (ctx->p_code_compiled == NULL) {
        if (!check_offset_push(ctx, error_buf, error_buf_size))
            return false;
    }

    if (disable_emit)
        *(ctx->frame_offset)++ = operand_offset;
    else {
        emit_operand(ctx, ctx->dynamic_offset);
        *(ctx->frame_offset)++ = ctx->dynamic_offset;
        ctx->dynamic_offset++;
        if (ctx->dynamic_offset > ctx->max_dynamic_offset) {
            ctx->max_dynamic_offset = ctx->dynamic_offset;
            if (ctx->max_dynamic_offset >= INT16_MAX) {
                goto fail;
            }
        }
    }

    if (is_32bit_type(type))
        return true;

    cell_num_to_push = wasm_value_type_cell_num(type) - 1;
    for (i = 0; i < cell_num_to_push; i++) {
        if (ctx->p_code_compiled == NULL) {
            if (!check_offset_push(ctx, error_buf, error_buf_size))
                return false;
        }

        ctx->frame_offset++;
        if (!disable_emit) {
            ctx->dynamic_offset++;
            if (ctx->dynamic_offset > ctx->max_dynamic_offset) {
                ctx->max_dynamic_offset = ctx->dynamic_offset;
                if (ctx->max_dynamic_offset >= INT16_MAX)
                    goto fail;
            }
        }
    }

    return true;

fail:
    set_error_buf(error_buf, error_buf_size,
                  "fast interpreter offset overflow");
    return false;
}

/* This function should be in front of wasm_loader_pop_frame_ref
    as they both use ctx->stack_cell_num, and ctx->stack_cell_num
    will be modified by wasm_loader_pop_frame_ref */
static bool
wasm_loader_pop_frame_offset(WASMLoaderContext *ctx, uint8 type,
                             char *error_buf, uint32 error_buf_size)
{
    /* if ctx->frame_csp equals ctx->frame_csp_bottom,
       then current block is the function block */
    uint32 depth = ctx->frame_csp > ctx->frame_csp_bottom ? 1 : 0;
    BranchBlock *cur_block = ctx->frame_csp - depth;
    int32 available_stack_cell =
        (int32)(ctx->stack_cell_num - cur_block->stack_cell_num);
    uint32 cell_num_to_pop;

    /* Directly return success if current block is in stack
       polymorphic state while stack is empty. */
    if (available_stack_cell <= 0 && cur_block->is_stack_polymorphic)
        return true;

    if (type == VALUE_TYPE_VOID)
        return true;

    /* Change type to ANY when the stack top is ANY, so as to avoid
       popping unneeded offsets, e.g. if type is I64/F64, we may pop
       two offsets */
    if (available_stack_cell > 0 && *(ctx->frame_ref - 1) == VALUE_TYPE_ANY)
        type = VALUE_TYPE_ANY;

    cell_num_to_pop = wasm_value_type_cell_num(type);

    /* Check the offset stack bottom to ensure the frame offset
       stack will not go underflow. But we don't thrown error
       and return true here, because the error msg should be
       given in wasm_loader_pop_frame_ref */
    if (!check_offset_pop(ctx, cell_num_to_pop))
        return true;

    ctx->frame_offset -= cell_num_to_pop;
    if ((*(ctx->frame_offset) > ctx->start_dynamic_offset)
        && (*(ctx->frame_offset) < ctx->max_dynamic_offset))
        ctx->dynamic_offset -= cell_num_to_pop;

    emit_operand(ctx, *(ctx->frame_offset));

    (void)error_buf;
    (void)error_buf_size;
    return true;
}

static bool
wasm_loader_push_frame_ref_offset(WASMLoaderContext *ctx, uint8 type,
                                  bool disable_emit, int16 operand_offset,
                                  char *error_buf, uint32 error_buf_size)
{
    if (!(wasm_loader_push_frame_offset(ctx, type, disable_emit, operand_offset,
                                        error_buf, error_buf_size)))
        return false;
    if (!(wasm_loader_push_frame_ref(ctx, type, error_buf, error_buf_size)))
        return false;

    return true;
}

static bool
wasm_loader_pop_frame_ref_offset(WASMLoaderContext *ctx, uint8 type,
                                 char *error_buf, uint32 error_buf_size)
{
    /* put wasm_loader_pop_frame_offset in front of wasm_loader_pop_frame_ref */
    if (!wasm_loader_pop_frame_offset(ctx, type, error_buf, error_buf_size))
        return false;
    if (!wasm_loader_pop_frame_ref(ctx, type, error_buf, error_buf_size))
        return false;

    return true;
}

static bool
wasm_loader_push_pop_frame_ref_offset(WASMLoaderContext *ctx, uint8 pop_cnt,
                                      uint8 type_push, uint8 type_pop,
                                      bool disable_emit, int16 operand_offset,
                                      char *error_buf, uint32 error_buf_size)
{
    uint8 i;

    for (i = 0; i < pop_cnt; i++) {
        if (!wasm_loader_pop_frame_offset(ctx, type_pop, error_buf,
                                          error_buf_size))
            return false;

        if (!wasm_loader_pop_frame_ref(ctx, type_pop, error_buf,
                                       error_buf_size))
            return false;
    }

    if (!wasm_loader_push_frame_offset(ctx, type_push, disable_emit,
                                       operand_offset, error_buf,
                                       error_buf_size))
        return false;

    if (!wasm_loader_push_frame_ref(ctx, type_push, error_buf, error_buf_size))
        return false;

    return true;
}

static int
cmp_i64_const(const void *p_i64_const1, const void *p_i64_const2)
{
    int64 i64_const1 = *(int64 *)p_i64_const1;
    int64 i64_const2 = *(int64 *)p_i64_const2;

    return (i64_const1 < i64_const2) ? -1 : (i64_const1 > i64_const2) ? 1 : 0;
}

static int
cmp_i32_const(const void *p_i32_const1, const void *p_i32_const2)
{
    int32 i32_const1 = *(int32 *)p_i32_const1;
    int32 i32_const2 = *(int32 *)p_i32_const2;

    return (i32_const1 < i32_const2) ? -1 : (i32_const1 > i32_const2) ? 1 : 0;
}

static int
cmp_v128_const(const void *p_v128_const1, const void *p_v128_const2)
{
    V128 v128_const1 = *(V128 *)p_v128_const1;
    V128 v128_const2 = *(V128 *)p_v128_const2;

    return memcmp(&v128_const1, &v128_const2, sizeof(V128));
}

/* This method is called from GET_CONST_OFFSET macro. 
 * There are two cases when this method is called:
 *   - p_code_compiled==NULL: adds the value to the const table.
 *   - p_code_compiled!=NULL: looks it up via bsearch.
 * 
 * Both cases must make the same decisions with regard to returning whether
 * the value is in the table or not. Otherwise, it can cause a divergence
 * and can allow `dynamic_offset` to get out of sync.  This results in 
 * `reserve_block_ret()` emitting copy instructions in Pass 2 that weren't 
 * measured in Pass 1, potentially overflowing the buffer.
 */
static bool
wasm_loader_get_const_offset(WASMLoaderContext *ctx, uint8 type, void *value,
                             int16 *offset, char *error_buf,
                             uint32 error_buf_size)
{
    if (!ctx->p_code_compiled) {
        /* Treat i64 and f64 as the same by reading i64 value from
           the raw bytes */
        if (type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64) {
            /* No slot left for a new entry. Check whether the value is
             * already in the table (it may have been added in an earlier
             * iteration before the threshold was reached). If it is, return
             * a table-ref so Pass 2's bsearch makes the same decision and
             * dynamic_offset advances identically in both passes. If it is
             * not in the table, return inline (0); Pass 2's bsearch will
             * also miss it and inline it, keeping the passes in sync. */
            if (ctx->i64_const_num * 2 + ctx->i32_const_num > INT16_MAX - 2) {
                for (uint32 i = 0; i < ctx->i64_const_num; i++) {
                    if (ctx->i64_consts[i] == *(int64 *)value) {
                        *offset = -1;
                        return true;
                    }
                }
                *offset = 0;
                return true;
            }

            /* Traverse the list if the const num is small */
            if (ctx->i64_const_num < FAST_INTERP_CONST_DEDUP_SCAN_MAX) {
                for (uint32 i = 0; i < ctx->i64_const_num; i++) {
                    if (ctx->i64_consts[i] == *(int64 *)value) {
                        *offset = -1;
                        return true;
                    }
                }
            }

            if (ctx->i64_const_num >= ctx->i64_const_max_num) {
                MEM_REALLOC(ctx->i64_consts,
                            sizeof(int64) * ctx->i64_const_max_num,
                            sizeof(int64) * (ctx->i64_const_max_num * 2));
                ctx->i64_const_max_num *= 2;
            }
            ctx->i64_consts[ctx->i64_const_num++] = *(int64 *)value;
        }
        else if (type == VALUE_TYPE_V128) {
            /* No slot left, emit const instead */
            if (ctx->v128_const_num * 4 > INT16_MAX - 2) {
                for (uint32 i = 0; i < ctx->v128_const_num; i++) {
                    if (memcmp(&ctx->v128_consts[i], value, sizeof(V128))
                        == 0) {
                        *offset = -1;
                        return true;
                    }
                }
                *offset = 0;
                return true;
            }

            /* Traverse the list if the const num is small */
            if (ctx->v128_const_num < FAST_INTERP_CONST_DEDUP_SCAN_MAX) {
                for (uint32 i = 0; i < ctx->v128_const_num; i++) {
                    if (memcmp(&ctx->v128_consts[i], value, sizeof(V128))
                        == 0) {
                        *offset = -1;
                        return true;
                    }
                }
            }

            if (ctx->v128_const_num >= ctx->v128_const_max_num) {
                MEM_REALLOC(ctx->v128_consts,
                            sizeof(V128) * ctx->v128_const_max_num,
                            sizeof(V128) * (ctx->v128_const_max_num * 2));
                ctx->v128_const_max_num *= 2;
            }
            ctx->v128_consts[ctx->v128_const_num++] = *(V128 *)value;
        }
        else {
            /* Treat i32 and f32 as the same by reading i32 value from
               the raw bytes */
            bh_assert(type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32);

            /* No slot left, emit const instead */
            if (ctx->i64_const_num * 2 + ctx->i32_const_num > INT16_MAX - 1) {
                for (uint32 i = 0; i < ctx->i32_const_num; i++) {
                    if (ctx->i32_consts[i] == *(int32 *)value) {
                        *offset = -1;
                        return true;
                    }
                }
                *offset = 0;
                return true;
            }

            /* Traverse the list if the const num is small */
            if (ctx->i32_const_num < FAST_INTERP_CONST_DEDUP_SCAN_MAX) {
                for (uint32 i = 0; i < ctx->i32_const_num; i++) {
                    if (ctx->i32_consts[i] == *(int32 *)value) {
                        *offset = -1;
                        return true;
                    }
                }
            }

            if (ctx->i32_const_num >= ctx->i32_const_max_num) {
                MEM_REALLOC(ctx->i32_consts,
                            sizeof(int32) * ctx->i32_const_max_num,
                            sizeof(int32) * (ctx->i32_const_max_num * 2));
                ctx->i32_const_max_num *= 2;
            }
            ctx->i32_consts[ctx->i32_const_num++] = *(int32 *)value;
        }

        *offset = -1;
        return true;
    }
    else {
        if (type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64) {
            int64 key = *(int64 *)value, *i64_const;
            i64_const = bsearch(&key, ctx->i64_consts, ctx->i64_const_num,
                                sizeof(int64), cmp_i64_const);
            if (!i64_const) { /* not found, emit const instead */
                *offset = 0;
                return true;
            }

            /* constant index is encoded as negative value */
            *offset = -(int32)(ctx->i64_const_num * 2 + ctx->i32_const_num)
                      + (int32)(i64_const - ctx->i64_consts) * 2;
        }
        else if (type == VALUE_TYPE_V128) {
            V128 key = *(V128 *)value, *v128_const;
            v128_const = bsearch(&key, ctx->v128_consts, ctx->v128_const_num,
                                 sizeof(V128), cmp_v128_const);
            if (!v128_const) { /* not found, emit const instead */
                *offset = 0;
                return true;
            }

            /* constant index is encoded as negative value */
            *offset = -(int32)(ctx->v128_const_num)
                      + (int32)(v128_const - ctx->v128_consts);
        }

        else {
            int32 key = *(int32 *)value, *i32_const;
            i32_const = bsearch(&key, ctx->i32_consts, ctx->i32_const_num,
                                sizeof(int32), cmp_i32_const);
            if (!i32_const) { /* not found, emit const instead */
                *offset = 0;
                return true;
            }

            /* constant index is encoded as negative value */
            *offset = -(int32)(ctx->i32_const_num)
                      + (int32)(i32_const - ctx->i32_consts);
        }

        return true;
    }
fail:
    return false;
}

/*
    PUSH(POP)_XXX = push(pop) frame_ref + push(pop) frame_offset
    -- Mostly used for the binary / compare operation
    PUSH(POP)_OFFSET_TYPE only push(pop) the frame_offset stack
    -- Mostly used in block / control instructions

    The POP will always emit the offset on the top of the frame_offset stack
    PUSH can be used in two ways:
    1. directly PUSH:
            PUSH_XXX();
        will allocate a dynamic space and emit
    2. silent PUSH:
            operand_offset = xxx; disable_emit = true;
            PUSH_XXX();
        only push the frame_offset stack, no emit
*/

#define TEMPLATE_PUSH(Type)                                                   \
    do {                                                                      \
        if (!wasm_loader_push_frame_ref_offset(loader_ctx, VALUE_TYPE_##Type, \
                                               disable_emit, operand_offset,  \
                                               error_buf, error_buf_size))    \
            goto fail;                                                        \
    } while (0)

#define TEMPLATE_PUSH_REF(Type)                                                \
    do {                                                                       \
        if (!wasm_loader_push_frame_ref_offset(loader_ctx, Type, disable_emit, \
                                               operand_offset, error_buf,      \
                                               error_buf_size))                \
            goto fail;                                                         \
    } while (0)

#define TEMPLATE_POP(Type)                                                   \
    do {                                                                     \
        if (!wasm_loader_pop_frame_ref_offset(loader_ctx, VALUE_TYPE_##Type, \
                                              error_buf, error_buf_size))    \
            goto fail;                                                       \
    } while (0)

#define TEMPLATE_POP_REF(Type)                                             \
    do {                                                                   \
        if (!wasm_loader_pop_frame_ref_offset(loader_ctx, Type, error_buf, \
                                              error_buf_size))             \
            goto fail;                                                     \
    } while (0)

#define PUSH_OFFSET_TYPE(type)                                              \
    do {                                                                    \
        if (!(wasm_loader_push_frame_offset(loader_ctx, type, disable_emit, \
                                            operand_offset, error_buf,      \
                                            error_buf_size)))               \
            goto fail;                                                      \
    } while (0)

#define POP_OFFSET_TYPE(type)                                           \
    do {                                                                \
        if (!(wasm_loader_pop_frame_offset(loader_ctx, type, error_buf, \
                                           error_buf_size)))            \
            goto fail;                                                  \
    } while (0)

#define POP_AND_PUSH(type_pop, type_push)                         \
    do {                                                          \
        if (!(wasm_loader_push_pop_frame_ref_offset(              \
                loader_ctx, 1, type_push, type_pop, disable_emit, \
                operand_offset, error_buf, error_buf_size)))      \
            goto fail;                                            \
    } while (0)

/* type of POPs should be the same */
#define POP2_AND_PUSH(type_pop, type_push)                        \
    do {                                                          \
        if (!(wasm_loader_push_pop_frame_ref_offset(              \
                loader_ctx, 2, type_push, type_pop, disable_emit, \
                operand_offset, error_buf, error_buf_size)))      \
            goto fail;                                            \
    } while (0)

#else /* WASM_ENABLE_FAST_INTERP */

#define TEMPLATE_PUSH(Type)                                             \
    do {                                                                \
        if (!(wasm_loader_push_frame_ref(loader_ctx, VALUE_TYPE_##Type, \
                                         error_buf, error_buf_size)))   \
            goto fail;                                                  \
    } while (0)

#define TEMPLATE_PUSH_REF(Type)                                       \
    do {                                                              \
        if (!(wasm_loader_push_frame_ref(loader_ctx, Type, error_buf, \
                                         error_buf_size)))            \
            goto fail;                                                \
    } while (0)

#define TEMPLATE_POP(Type)                                             \
    do {                                                               \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_##Type, \
                                        error_buf, error_buf_size)))   \
            goto fail;                                                 \
    } while (0)

#define TEMPLATE_POP_REF(Type)                                       \
    do {                                                             \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, Type, error_buf, \
                                        error_buf_size)))            \
            goto fail;                                               \
    } while (0)

#define POP_AND_PUSH(type_pop, type_push)                              \
    do {                                                               \
        if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 1, type_push, \
                                             type_pop, error_buf,      \
                                             error_buf_size)))         \
            goto fail;                                                 \
    } while (0)

/* type of POPs should be the same */
#define POP2_AND_PUSH(type_pop, type_push)                             \
    do {                                                               \
        if (!(wasm_loader_push_pop_frame_ref(loader_ctx, 2, type_push, \
                                             type_pop, error_buf,      \
                                             error_buf_size)))         \
            goto fail;                                                 \
    } while (0)
#endif /* WASM_ENABLE_FAST_INTERP */

#define PUSH_I32() TEMPLATE_PUSH(I32)
#define PUSH_F32() TEMPLATE_PUSH(F32)
#define PUSH_I64() TEMPLATE_PUSH(I64)
#define PUSH_F64() TEMPLATE_PUSH(F64)
#define PUSH_V128() TEMPLATE_PUSH(V128)
#define PUSH_FUNCREF() TEMPLATE_PUSH(FUNCREF)
#define PUSH_EXTERNREF() TEMPLATE_PUSH(EXTERNREF)
#define PUSH_REF(Type) TEMPLATE_PUSH_REF(Type)
#define POP_REF(Type) TEMPLATE_POP_REF(Type)
#define PUSH_MEM_OFFSET() TEMPLATE_PUSH_REF(mem_offset_type)
#define PUSH_PAGE_COUNT() PUSH_MEM_OFFSET()
#define PUSH_TBL_ELEM_IDX() TEMPLATE_PUSH_REF(table_elem_idx_type)

#define POP_I32() TEMPLATE_POP(I32)
#define POP_F32() TEMPLATE_POP(F32)
#define POP_I64() TEMPLATE_POP(I64)
#define POP_F64() TEMPLATE_POP(F64)
#define POP_V128() TEMPLATE_POP(V128)
#define POP_FUNCREF() TEMPLATE_POP(FUNCREF)
#define POP_EXTERNREF() TEMPLATE_POP(EXTERNREF)
#define POP_STRINGREF() TEMPLATE_POP(STRINGREF)
#define POP_MEM_OFFSET() TEMPLATE_POP_REF(mem_offset_type)
#define POP_TBL_ELEM_IDX() TEMPLATE_POP_REF(table_elem_idx_type)

#if WASM_ENABLE_FAST_INTERP != 0

static bool
reserve_block_ret(WASMLoaderContext *loader_ctx, uint8 opcode,
                  bool disable_emit, char *error_buf, uint32 error_buf_size)
{
    int16 operand_offset = 0;
    BranchBlock *block = (opcode == WASM_OP_ELSE) ? loader_ctx->frame_csp - 1
                                                  : loader_ctx->frame_csp;
    BlockType *block_type = &block->block_type;
    uint8 *return_types = NULL;
#if WASM_ENABLE_GC != 0
    WASMRefTypeMap *reftype_maps = NULL;
    uint32 reftype_map_count;
#endif
    uint32 return_count = 0, value_count = 0, total_cel_num = 0;
    int32 i = 0;
    int16 dynamic_offset, dynamic_offset_org, *frame_offset = NULL,
                                              *frame_offset_org = NULL;

#if WASM_ENABLE_GC == 0
    return_count = block_type_get_result_types(block_type, &return_types);
#else
    return_count = block_type_get_result_types(
        block_type, &return_types, &reftype_maps, &reftype_map_count);
#endif

    /* If there is only one return value, use EXT_OP_COPY_STACK_TOP/_I64/V128
     * instead of EXT_OP_COPY_STACK_VALUES for interpreter performance. */
    if (return_count == 1) {
        uint8 cell = (uint8)wasm_value_type_cell_num(return_types[0]);
        if (block->dynamic_offset != *(loader_ctx->frame_offset - cell)) {
            /* insert op_copy before else opcode */
            if (opcode == WASM_OP_ELSE)
                skip_label();
#if WASM_ENABLE_SIMDE != 0
            if (cell == 4) {
                emit_label(EXT_OP_COPY_STACK_TOP_V128);
            }
#endif
            if (cell <= 2) {
                emit_label(cell == 1 ? EXT_OP_COPY_STACK_TOP
                                     : EXT_OP_COPY_STACK_TOP_I64);
            }
            emit_operand(loader_ctx, *(loader_ctx->frame_offset - cell));
            emit_operand(loader_ctx, block->dynamic_offset);

            if (opcode == WASM_OP_ELSE) {
                *(loader_ctx->frame_offset - cell) = block->dynamic_offset;
            }
            else {
                loader_ctx->frame_offset -= cell;
                loader_ctx->dynamic_offset = block->dynamic_offset;
                PUSH_OFFSET_TYPE(return_types[0]);
                wasm_loader_emit_backspace(loader_ctx, sizeof(int16));
            }
            if (opcode == WASM_OP_ELSE)
                emit_label(opcode);
        }
        return true;
    }

    /* Copy stack top values to block's results which are in dynamic space.
     * The instruction format:
     *   Part a: values count
     *   Part b: all values total cell num
     *   Part c: each value's cell_num, src offset and dst offset
     *   Part d: each value's src offset and dst offset
     *   Part e: each value's dst offset
     */
    frame_offset = frame_offset_org = loader_ctx->frame_offset;
    dynamic_offset = dynamic_offset_org =
        block->dynamic_offset + wasm_get_cell_num(return_types, return_count);

    /* First traversal to get the count of values needed to be copied. */
    for (i = (int32)return_count - 1; i >= 0; i--) {
        uint8 cells = (uint8)wasm_value_type_cell_num(return_types[i]);

        if (frame_offset - cells < loader_ctx->frame_offset_bottom) {
            set_error_buf(error_buf, error_buf_size, "frame offset underflow");
            goto fail;
        }

        if (cells == 4) {
            bool needs_copy = false;
            int16 v128_dynamic = dynamic_offset - cells;

            for (int j = 0; j < 4; j++) {
                if (*(frame_offset - j - 1) != (v128_dynamic + j)) {
                    needs_copy = true;
                    break;
                }
            }

            if (needs_copy) {
                value_count++;
                total_cel_num += cells;
            }

            frame_offset -= cells;
            dynamic_offset = v128_dynamic;
        }
        else {
            frame_offset -= cells;
            dynamic_offset -= cells;
            if (dynamic_offset != *frame_offset) {
                value_count++;
                total_cel_num += cells;
            }
        }
    }

    if (value_count) {
        uint32 j = 0;
        uint8 *emit_data = NULL, *cells = NULL;
        int16 *src_offsets = NULL;
        uint16 *dst_offsets = NULL;
        uint64 size =
            (uint64)value_count
            * (sizeof(*cells) + sizeof(*src_offsets) + sizeof(*dst_offsets));

        /* Allocate memory for the emit data */
        if (!(emit_data = loader_malloc(size, error_buf, error_buf_size)))
            return false;

        cells = emit_data;
        src_offsets = (int16 *)(cells + value_count);
        dst_offsets = (uint16 *)(src_offsets + value_count);

        /* insert op_copy before else opcode */
        if (opcode == WASM_OP_ELSE)
            skip_label();
        emit_label(EXT_OP_COPY_STACK_VALUES);
        /* Part a) */
        emit_uint32(loader_ctx, value_count);
        /* Part b) */
        emit_uint32(loader_ctx, total_cel_num);

        /* Second traversal to get each value's cell num,  src offset and dst
         * offset. */
        frame_offset = frame_offset_org;
        dynamic_offset = dynamic_offset_org;
        for (i = (int32)return_count - 1, j = 0; i >= 0; i--) {
            uint8 cell = (uint8)wasm_value_type_cell_num(return_types[i]);

            if (cell == 4) {
                bool needs_copy = false;
                int16 v128_dynamic = dynamic_offset - cell;

                for (int k = 0; k < 4; k++) {
                    if (*(frame_offset - k - 1) != (v128_dynamic + k)) {
                        needs_copy = true;
                        break;
                    }
                }

                if (needs_copy) {
                    cells[j] = cell;
                    src_offsets[j] = *(frame_offset - cell);
                    dst_offsets[j] = v128_dynamic;
                    j++;
                }

                frame_offset -= cell;
                dynamic_offset = v128_dynamic;
            }
            else {
                frame_offset -= cell;
                dynamic_offset -= cell;
                if (dynamic_offset != *frame_offset) {
                    cells[j] = cell;
                    /* src offset */
                    src_offsets[j] = *frame_offset;
                    /* dst offset */
                    dst_offsets[j] = dynamic_offset;
                    j++;
                }
            }

            if (opcode == WASM_OP_ELSE) {
                if (cell == 4) {
                    for (int k = 0; k < cell; k++) {
                        *(frame_offset + k) = dynamic_offset + k;
                    }
                }
                else {
                    *frame_offset = dynamic_offset;
                }
            }
            else {
                loader_ctx->frame_offset = frame_offset;
                loader_ctx->dynamic_offset = dynamic_offset;
                if (!(wasm_loader_push_frame_offset(
                        loader_ctx, return_types[i], disable_emit,
                        operand_offset, error_buf, error_buf_size))) {
                    wasm_runtime_free(emit_data);
                    goto fail;
                }
                wasm_loader_emit_backspace(loader_ctx, sizeof(int16));
                loader_ctx->frame_offset = frame_offset_org;
                loader_ctx->dynamic_offset = dynamic_offset_org;
            }
        }

        bh_assert(j == value_count);

        /* Emit the cells, src_offsets and dst_offsets */
        for (j = 0; j < value_count; j++)
            emit_byte(loader_ctx, cells[j]);
        for (j = 0; j < value_count; j++)
            emit_operand(loader_ctx, src_offsets[j]);
        for (j = 0; j < value_count; j++)
            emit_operand(loader_ctx, dst_offsets[j]);

        if (opcode == WASM_OP_ELSE)
            emit_label(opcode);

        wasm_runtime_free(emit_data);
    }

    return true;

fail:
    return false;
}
#endif /* WASM_ENABLE_FAST_INTERP */

#define PUSH_TYPE(type)                                               \
    do {                                                              \
        if (!(wasm_loader_push_frame_ref(loader_ctx, type, error_buf, \
                                         error_buf_size)))            \
            goto fail;                                                \
    } while (0)

#define POP_TYPE(type)                                               \
    do {                                                             \
        if (!(wasm_loader_pop_frame_ref(loader_ctx, type, error_buf, \
                                        error_buf_size)))            \
            goto fail;                                               \
    } while (0)

#if WASM_ENABLE_GC == 0
#define PUSH_CSP(label_type, block_type, _start_addr)                       \
    do {                                                                    \
        if (!wasm_loader_push_frame_csp(loader_ctx, label_type, block_type, \
                                        _start_addr, error_buf,             \
                                        error_buf_size))                    \
            goto fail;                                                      \
    } while (0)

#define POP_CSP()                                                              \
    do {                                                                       \
        if (!wasm_loader_pop_frame_csp(loader_ctx, error_buf, error_buf_size)) \
            goto fail;                                                         \
    } while (0)
#else
#define PUSH_CSP(label_type, block_type, _start_addr)                       \
    do {                                                                    \
        if (!wasm_loader_push_frame_csp(loader_ctx, label_type, block_type, \
                                        _start_addr, error_buf,             \
                                        error_buf_size))                    \
            goto fail;                                                      \
        if (!wasm_loader_init_local_use_masks(loader_ctx, local_count,      \
                                              error_buf, error_buf_size)) { \
            goto fail;                                                      \
        }                                                                   \
    } while (0)

#define POP_CSP()                                                              \
    do {                                                                       \
        wasm_loader_destroy_curr_local_use_masks(loader_ctx);                  \
        if (!wasm_loader_pop_frame_csp(loader_ctx, error_buf, error_buf_size)) \
            goto fail;                                                         \
    } while (0)
#endif /* end of WASM_ENABLE_GC == 0 */

#if WASM_ENABLE_GC == 0
#define GET_LOCAL_REFTYPE() (void)0
#else
#define GET_LOCAL_REFTYPE()                                                  \
    do {                                                                     \
        if (wasm_is_type_multi_byte_type(local_type)) {                      \
            WASMRefType *_ref_type;                                          \
            if (local_idx < param_count)                                     \
                _ref_type = wasm_reftype_map_find(                           \
                    param_reftype_maps, param_reftype_map_count, local_idx); \
            else                                                             \
                _ref_type = wasm_reftype_map_find(local_reftype_maps,        \
                                                  local_reftype_map_count,   \
                                                  local_idx - param_count);  \
            bh_assert(_ref_type);                                            \
            bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType), _ref_type,      \
                        wasm_reftype_struct_size(_ref_type));                \
        }                                                                    \
    } while (0)
#endif /* end of WASM_ENABLE_GC == 0 */

#define GET_LOCAL_INDEX_TYPE_AND_OFFSET()                              \
    do {                                                               \
        read_leb_uint32(p, p_end, local_idx);                          \
        if (local_idx >= param_count + local_count) {                  \
            set_error_buf(error_buf, error_buf_size, "unknown local"); \
            goto fail;                                                 \
        }                                                              \
        local_type = local_idx < param_count                           \
                         ? param_types[local_idx]                      \
                         : local_types[local_idx - param_count];       \
        local_offset = local_offsets[local_idx];                       \
        GET_LOCAL_REFTYPE();                                           \
    } while (0)

static bool
check_memory(WASMModule *module, char *error_buf, uint32 error_buf_size)
{
    if (module->memory_count == 0 && module->import_memory_count == 0) {
        set_error_buf(error_buf, error_buf_size, "unknown memory");
        return false;
    }
    return true;
}

#define CHECK_MEMORY()                                        \
    do {                                                      \
        if (!check_memory(module, error_buf, error_buf_size)) \
            goto fail;                                        \
    } while (0)

static bool
check_memory_access_align(uint8 opcode, uint32 align, char *error_buf,
                          uint32 error_buf_size)
{
    uint8 mem_access_aligns[] = {
        2, 3, 2, 3, 0, 0, 1, 1, 0, 0, 1, 1, 2, 2, /* loads */
        2, 3, 2, 3, 0, 1, 0, 1, 2                 /* stores */
    };
    bh_assert(opcode >= WASM_OP_I32_LOAD && opcode <= WASM_OP_I64_STORE32);
    if (align > mem_access_aligns[opcode - WASM_OP_I32_LOAD]) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid memop flags: alignment must not be larger "
                      "than natural");
        return false;
    }
    return true;
}

#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
static bool
check_simd_memory_access_align(uint8 opcode, uint32 align, char *error_buf,
                               uint32 error_buf_size)
{
    uint8 mem_access_aligns[] = {
        4,                /* load */
        3, 3, 3, 3, 3, 3, /* load and extend */
        0, 1, 2, 3,       /* load and splat */
        4,                /* store */
    };

    uint8 mem_access_aligns_load_lane[] = {
        0, 1, 2, 3, /* load lane */
        0, 1, 2, 3, /* store lane */
        2, 3        /* store zero */
    };

    if (!((opcode <= SIMD_v128_store)
          || (SIMD_v128_load8_lane <= opcode
              && opcode <= SIMD_v128_load64_zero))) {
        set_error_buf(error_buf, error_buf_size,
                      "the opcode doesn't include memarg");
        return false;
    }

    if ((opcode <= SIMD_v128_store
         && align > mem_access_aligns[opcode - SIMD_v128_load])
        || (SIMD_v128_load8_lane <= opcode && opcode <= SIMD_v128_load64_zero
            && align > mem_access_aligns_load_lane[opcode
                                                   - SIMD_v128_load8_lane])) {
        set_error_buf(error_buf, error_buf_size,
                      "invalid memop flags: alignment must not be larger "
                      "than natural");
        return false;
    }

    return true;
}

static bool
check_simd_access_lane(uint8 opcode, uint8 lane, char *error_buf,
                       uint32 error_buf_size)
{
    switch (opcode) {
        case SIMD_i8x16_extract_lane_s:
        case SIMD_i8x16_extract_lane_u:
        case SIMD_i8x16_replace_lane:
            if (lane >= 16) {
                goto fail;
            }
            break;
        case SIMD_i16x8_extract_lane_s:
        case SIMD_i16x8_extract_lane_u:
        case SIMD_i16x8_replace_lane:
            if (lane >= 8) {
                goto fail;
            }
            break;
        case SIMD_i32x4_extract_lane:
        case SIMD_i32x4_replace_lane:
        case SIMD_f32x4_extract_lane:
        case SIMD_f32x4_replace_lane:
            if (lane >= 4) {
                goto fail;
            }
            break;
        case SIMD_i64x2_extract_lane:
        case SIMD_i64x2_replace_lane:
        case SIMD_f64x2_extract_lane:
        case SIMD_f64x2_replace_lane:
            if (lane >= 2) {
                goto fail;
            }
            break;

        case SIMD_v128_load8_lane:
        case SIMD_v128_load16_lane:
        case SIMD_v128_load32_lane:
        case SIMD_v128_load64_lane:
        case SIMD_v128_store8_lane:
        case SIMD_v128_store16_lane:
        case SIMD_v128_store32_lane:
        case SIMD_v128_store64_lane:
        case SIMD_v128_load32_zero:
        case SIMD_v128_load64_zero:
        {
            uint8 max_lanes[] = { 16, 8, 4, 2, 16, 8, 4, 2, 4, 2 };
            if (lane >= max_lanes[opcode - SIMD_v128_load8_lane]) {
                goto fail;
            }
            break;
        }
        default:
            goto fail;
    }

    return true;
fail:
    set_error_buf(error_buf, error_buf_size, "invalid lane index");
    return false;
}

static bool
check_simd_shuffle_mask(V128 mask, char *error_buf, uint32 error_buf_size)
{
    uint8 i;
    for (i = 0; i != 16; ++i) {
        if (mask.i8x16[i] < 0 || mask.i8x16[i] >= 32) {
            set_error_buf(error_buf, error_buf_size, "invalid lane index");
            return false;
        }
    }
    return true;
}
#endif /* end of (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) */
#endif /* end of WASM_ENABLE_SIMD */

#if WASM_ENABLE_SHARED_MEMORY != 0
static bool
check_memory_align_equal(uint8 opcode, uint32 align, char *error_buf,
                         uint32 error_buf_size)
{
    uint8 wait_notify_aligns[] = { 2, 2, 3 };
    uint8 mem_access_aligns[] = {
        2, 3, 0, 1, 0, 1, 2,
    };
    uint8 expect;

    bh_assert((opcode <= WASM_OP_ATOMIC_WAIT64)
              || (opcode >= WASM_OP_ATOMIC_I32_LOAD
                  && opcode <= WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U));
    if (opcode <= WASM_OP_ATOMIC_WAIT64) {
        expect = wait_notify_aligns[opcode - WASM_OP_ATOMIC_NOTIFY];
    }
    else {
        /* 7 opcodes in every group */
        expect = mem_access_aligns[(opcode - WASM_OP_ATOMIC_I32_LOAD) % 7];
    }
    if (align != expect) {
        set_error_buf(error_buf, error_buf_size,
                      "alignment isn't equal to natural");
        return false;
    }
    return true;
}
#endif /* end of WASM_ENABLE_SHARED_MEMORY */

static bool
wasm_loader_check_br(WASMLoaderContext *loader_ctx, uint32 depth, uint8 opcode,
                     char *error_buf, uint32 error_buf_size)
{
    BranchBlock *target_block, *cur_block;
    BlockType *target_block_type;
    uint8 type, *types = NULL, *frame_ref;
    uint32 arity = 0;
    int32 i, available_stack_cell;
    uint16 cell_num;
#if WASM_ENABLE_GC != 0
    WASMRefTypeMap *frame_reftype_map;
    WASMRefTypeMap *reftype_maps = NULL, *reftype_map = NULL;
    WASMRefType *ref_type;
    uint32 reftype_map_count = 0;
    int32 available_reftype_map;
    bool is_type_multi_byte;
#endif

    uint8 *frame_ref_old = loader_ctx->frame_ref;
    uint8 *frame_ref_after_popped = NULL;
    uint8 frame_ref_tmp[4] = { 0 };
    uint8 *frame_ref_buf = frame_ref_tmp;
    uint32 stack_cell_num_old = loader_ctx->stack_cell_num;
#if WASM_ENABLE_GC != 0
    WASMRefTypeMap *frame_reftype_map_old = loader_ctx->frame_reftype_map;
    WASMRefTypeMap *frame_reftype_map_after_popped = NULL;
    WASMRefTypeMap frame_reftype_map_tmp[4] = { 0 };
    WASMRefTypeMap *frame_reftype_map_buf = frame_reftype_map_tmp;
    uint32 reftype_map_num_old = loader_ctx->reftype_map_num;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
    int16 *frame_offset_old = loader_ctx->frame_offset;
    int16 *frame_offset_after_popped = NULL;
    int16 frame_offset_tmp[4] = { 0 };
    int16 *frame_offset_buf = frame_offset_tmp;
    uint16 dynamic_offset_old = (loader_ctx->frame_csp - 1)->dynamic_offset;
#endif
    bool ret = false;

    bh_assert(loader_ctx->csp_num > 0);
    if (loader_ctx->csp_num - 1 < depth) {
        set_error_buf(error_buf, error_buf_size,
                      "unknown label, "
                      "unexpected end of section or function");
        return false;
    }

    cur_block = loader_ctx->frame_csp - 1;
    target_block = loader_ctx->frame_csp - (depth + 1);
    target_block_type = &target_block->block_type;
    frame_ref = loader_ctx->frame_ref;
#if WASM_ENABLE_GC != 0
    frame_reftype_map = loader_ctx->frame_reftype_map;
#endif

    /* Note: loop's arity is different from if and block. loop's arity is
     * its parameter count while if and block arity is result count.
     */
#if WASM_ENABLE_GC == 0
    if (target_block->label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(target_block_type, &types);
    else
        arity = block_type_get_result_types(target_block_type, &types);
#else
    if (target_block->label_type == LABEL_TYPE_LOOP)
        arity = block_type_get_param_types(target_block_type, &types,
                                           &reftype_maps, &reftype_map_count);
    else
        arity = block_type_get_result_types(target_block_type, &types,
                                            &reftype_maps, &reftype_map_count);
#endif

    /* If the stack is in polymorphic state, just clear the stack
     * and then re-push the values to make the stack top values
     * match block type. */
    if (cur_block->is_stack_polymorphic) {
#if WASM_ENABLE_GC != 0
        int32 j = (int32)reftype_map_count - 1;
#endif
        for (i = (int32)arity - 1; i >= 0; i--) {
#if WASM_ENABLE_GC != 0
            if (wasm_is_type_multi_byte_type(types[i])) {
                bh_assert(reftype_maps[j].index == i);
                bh_memcpy_s(loader_ctx->ref_type_tmp, sizeof(WASMRefType),
                            reftype_maps[j].ref_type,
                            wasm_reftype_struct_size(reftype_maps[j].ref_type));
                j--;
            }
#endif
#if WASM_ENABLE_FAST_INTERP != 0
            POP_OFFSET_TYPE(types[i]);
#endif
            POP_TYPE(types[i]);
        }

        /* Backup stack data since it may be changed in the below
           push operations, and the stack data may be used when
           checking other target blocks of opcode br_table */
        if (opcode == WASM_OP_BR_TABLE) {
            uint64 total_size;

            frame_ref_after_popped = loader_ctx->frame_ref;
            total_size = (uint64)sizeof(uint8)
                         * (frame_ref_old - frame_ref_after_popped);
            if (total_size > sizeof(frame_ref_tmp)
                && !(frame_ref_buf = loader_malloc(total_size, error_buf,
                                                   error_buf_size))) {
                goto fail;
            }
            bh_memcpy_s(frame_ref_buf, (uint32)total_size,
                        frame_ref_after_popped, (uint32)total_size);

#if WASM_ENABLE_GC != 0
            frame_reftype_map_after_popped = loader_ctx->frame_reftype_map;
            total_size =
                (uint64)sizeof(WASMRefTypeMap)
                * (frame_reftype_map_old - frame_reftype_map_after_popped);
            if (total_size > sizeof(frame_reftype_map_tmp)
                && !(frame_reftype_map_buf = loader_malloc(
                         total_size, error_buf, error_buf_size))) {
                goto fail;
            }
            bh_memcpy_s(frame_reftype_map_buf, (uint32)total_size,
                        frame_reftype_map_after_popped, (uint32)total_size);
#endif

#if WASM_ENABLE_FAST_INTERP != 0
            frame_offset_after_popped = loader_ctx->frame_offset;
            total_size = (uint64)sizeof(int16)
                         * (frame_offset_old - frame_offset_after_popped);
            if (total_size > sizeof(frame_offset_tmp)
                && !(frame_offset_buf = loader_malloc(total_size, error_buf,
                                                      error_buf_size))) {
                goto fail;
            }
            bh_memcpy_s(frame_offset_buf, (uint32)total_size,
                        frame_offset_after_popped, (uint32)total_size);
#endif
        }

#if WASM_ENABLE_GC != 0
        j = 0;
#endif
        for (i = 0; i < (int32)arity; i++) {
#if WASM_ENABLE_GC != 0
            if (wasm_is_type_multi_byte_type(types[i])) {
                bh_assert(reftype_maps[j].index == i);
                bh_memcpy_s(loader_ctx->ref_type_tmp, sizeof(WASMRefType),
                            reftype_maps[j].ref_type,
                            wasm_reftype_struct_size(reftype_maps[j].ref_type));
                j++;
            }
#endif
#if WASM_ENABLE_FAST_INTERP != 0
            bool disable_emit = true;
            int16 operand_offset = 0;
            PUSH_OFFSET_TYPE(types[i]);
#endif
            PUSH_TYPE(types[i]);
        }

#if WASM_ENABLE_FAST_INTERP != 0
        emit_br_info(target_block, opcode == WASM_OP_BR);
#endif

        /* Restore the stack data, note that frame_ref_bottom,
           frame_reftype_map_bottom, frame_offset_bottom may be
           re-allocated in the above push operations */
        if (opcode == WASM_OP_BR_TABLE) {
            uint32 total_size;

            /* The stack operand num should not be smaller than before
               after pop and push operations */
            bh_assert(loader_ctx->stack_cell_num >= stack_cell_num_old);
            loader_ctx->stack_cell_num = stack_cell_num_old;
            loader_ctx->frame_ref =
                loader_ctx->frame_ref_bottom + stack_cell_num_old;
            total_size = (uint32)(sizeof(uint8)
                                  * (frame_ref_old - frame_ref_after_popped));
            bh_memcpy_s((uint8 *)loader_ctx->frame_ref - total_size, total_size,
                        frame_ref_buf, total_size);

#if WASM_ENABLE_GC != 0
            /* The stack operand num should not be smaller than before
               after pop and push operations */
            bh_assert(loader_ctx->reftype_map_num >= reftype_map_num_old);
            loader_ctx->reftype_map_num = reftype_map_num_old;
            loader_ctx->frame_reftype_map =
                loader_ctx->frame_reftype_map_bottom + reftype_map_num_old;
            total_size = (uint32)(sizeof(WASMRefTypeMap)
                                  * (frame_reftype_map_old
                                     - frame_reftype_map_after_popped));
            bh_memcpy_s((uint8 *)loader_ctx->frame_reftype_map - total_size,
                        total_size, frame_reftype_map_buf, total_size);
#endif

#if WASM_ENABLE_FAST_INTERP != 0
            loader_ctx->frame_offset =
                loader_ctx->frame_offset_bottom + stack_cell_num_old;
            total_size =
                (uint32)(sizeof(int16)
                         * (frame_offset_old - frame_offset_after_popped));
            bh_memcpy_s((uint8 *)loader_ctx->frame_offset - total_size,
                        total_size, frame_offset_buf, total_size);
            (loader_ctx->frame_csp - 1)->dynamic_offset = dynamic_offset_old;
#endif
        }

        ret = true;
        goto cleanup_and_return;
    }

    available_stack_cell =
        (int32)(loader_ctx->stack_cell_num - cur_block->stack_cell_num);
#if WASM_ENABLE_GC != 0
    available_reftype_map =
        (int32)(loader_ctx->reftype_map_num
                - (loader_ctx->frame_csp - 1)->reftype_map_num);
    reftype_map = reftype_maps ? reftype_maps + reftype_map_count - 1 : NULL;
#endif

    /* Check stack top values match target block type */
    for (i = (int32)arity - 1; i >= 0; i--) {
        type = types[i];
#if WASM_ENABLE_GC != 0
        ref_type = NULL;
        is_type_multi_byte = wasm_is_type_multi_byte_type(type);
        if (is_type_multi_byte) {
            bh_assert(reftype_map);
            ref_type = reftype_map->ref_type;
        }
#endif

        if (available_stack_cell <= 0 && cur_block->is_stack_polymorphic)
            break;

        if (!check_stack_top_values(loader_ctx, frame_ref, available_stack_cell,
#if WASM_ENABLE_GC != 0
                                    frame_reftype_map, available_reftype_map,
#endif
                                    type,
#if WASM_ENABLE_GC != 0
                                    ref_type,
#endif
                                    error_buf, error_buf_size)) {
            goto fail;
        }
        cell_num = wasm_value_type_cell_num(types[i]);
        frame_ref -= cell_num;
        available_stack_cell -= cell_num;
#if WASM_ENABLE_GC != 0
        if (is_type_multi_byte) {
            frame_reftype_map--;
            available_reftype_map--;
            reftype_map--;
        }
#endif
    }

#if WASM_ENABLE_FAST_INTERP != 0
    emit_br_info(target_block, opcode == WASM_OP_BR);
#endif

    ret = true;

cleanup_and_return:
fail:
    if (frame_ref_buf && frame_ref_buf != frame_ref_tmp)
        wasm_runtime_free(frame_ref_buf);
#if WASM_ENABLE_GC != 0
    if (frame_reftype_map_buf && frame_reftype_map_buf != frame_reftype_map_tmp)
        wasm_runtime_free(frame_reftype_map_buf);
#endif
#if WASM_ENABLE_FAST_INTERP != 0
    if (frame_offset_buf && frame_offset_buf != frame_offset_tmp)
        wasm_runtime_free(frame_offset_buf);
#endif

    return ret;
}

static BranchBlock *
check_branch_block(WASMLoaderContext *loader_ctx, uint8 **p_buf, uint8 *buf_end,
                   uint8 opcode, char *error_buf, uint32 error_buf_size)
{
    uint8 *p = *p_buf, *p_end = buf_end;
    BranchBlock *frame_csp_tmp;
    uint32 depth;

    read_leb_uint32(p, p_end, depth);
    if (!wasm_loader_check_br(loader_ctx, depth, opcode, error_buf,
                              error_buf_size)) {
        goto fail;
    }

    frame_csp_tmp = loader_ctx->frame_csp - depth - 1;

    *p_buf = p;
    return frame_csp_tmp;
fail:
    return NULL;
}

#if WASM_ENABLE_EXCE_HANDLING != 0
static BranchBlock *
check_branch_block_for_delegate(WASMLoaderContext *loader_ctx, uint8 **p_buf,
                                uint8 *buf_end, char *error_buf,
                                uint32 error_buf_size)
{
    uint8 *p = *p_buf, *p_end = buf_end;
    BranchBlock *frame_csp_tmp;
    uint32 depth;

    read_leb_uint32(p, p_end, depth);
    /*
     * Note: "delegate 0" means the surrounding block, not the
     * try-delegate block itself.
     *
     * Note: the caller hasn't popped the try-delegate frame yet.
     */
    bh_assert(loader_ctx->csp_num > 0);
    if (loader_ctx->csp_num - 1 <= depth) {
#if WASM_ENABLE_SPEC_TEST == 0
        set_error_buf(error_buf, error_buf_size, "unknown delegate label");
#else
        set_error_buf(error_buf, error_buf_size, "unknown label");
#endif
        goto fail;
    }
    frame_csp_tmp = loader_ctx->frame_csp - depth - 2;
#if WASM_ENABLE_FAST_INTERP != 0
    emit_br_info(frame_csp_tmp, false);
#endif

    *p_buf = p;
    return frame_csp_tmp;
fail:
    return NULL;
}
#endif /* end of WASM_ENABLE_EXCE_HANDLING != 0 */

static bool
check_block_stack(WASMLoaderContext *loader_ctx, BranchBlock *block,
                  char *error_buf, uint32 error_buf_size)
{
    BlockType *block_type = &block->block_type;
    uint8 *return_types = NULL;
    uint32 return_count = 0;
    int32 available_stack_cell, return_cell_num, i;
    uint8 *frame_ref = NULL;
#if WASM_ENABLE_GC != 0
    WASMRefTypeMap *frame_reftype_map;
    WASMRefTypeMap *return_reftype_maps = NULL, *return_reftype_map;
    WASMRefType *ref_type;
    uint32 param_count, return_reftype_map_count = 0;
    int32 available_reftype_map =
        (int32)(loader_ctx->reftype_map_num - block->reftype_map_num);
#endif

    available_stack_cell =
        (int32)(loader_ctx->stack_cell_num - block->stack_cell_num);

#if WASM_ENABLE_GC == 0
    return_count = block_type_get_result_types(block_type, &return_types);
#else
    return_count = block_type_get_result_types(block_type, &return_types,
                                               &return_reftype_maps,
                                               &return_reftype_map_count);
    param_count =
        block_type->is_value_type ? 0 : block_type->u.type->param_count;
    (void)param_count;
#endif
    return_cell_num =
        return_count > 0 ? wasm_get_cell_num(return_types, return_count) : 0;

    /* If the stack is in polymorphic state, just clear the stack
     * and then re-push the values to make the stack top values
     * match block type. */
    if (block->is_stack_polymorphic) {
#if WASM_ENABLE_GC != 0
        int32 j = (int32)return_reftype_map_count - 1;
#endif
        for (i = (int32)return_count - 1; i >= 0; i--) {
#if WASM_ENABLE_GC != 0
            if (wasm_is_type_multi_byte_type(return_types[i])) {
                bh_assert(return_reftype_maps[j].index == i + param_count);
                bh_memcpy_s(
                    loader_ctx->ref_type_tmp, sizeof(WASMRefType),
                    return_reftype_maps[j].ref_type,
                    wasm_reftype_struct_size(return_reftype_maps[j].ref_type));
                j--;
            }
#endif
#if WASM_ENABLE_FAST_INTERP != 0
            POP_OFFSET_TYPE(return_types[i]);
#endif
            POP_TYPE(return_types[i]);
        }

        /* Check stack is empty */
        if (loader_ctx->stack_cell_num != block->stack_cell_num) {
            set_error_buf(
                error_buf, error_buf_size,
                "type mismatch: stack size does not match block type");
            goto fail;
        }

#if WASM_ENABLE_GC != 0
        j = 0;
#endif
        for (i = 0; i < (int32)return_count; i++) {
#if WASM_ENABLE_GC != 0
            if (wasm_is_type_multi_byte_type(return_types[i])) {
                bh_assert(return_reftype_maps[j].index == i + param_count);
                bh_memcpy_s(
                    loader_ctx->ref_type_tmp, sizeof(WASMRefType),
                    return_reftype_maps[j].ref_type,
                    wasm_reftype_struct_size(return_reftype_maps[j].ref_type));
                j++;
            }
#endif
#if WASM_ENABLE_FAST_INTERP != 0
            bool disable_emit = true;
            int16 operand_offset = 0;
            PUSH_OFFSET_TYPE(return_types[i]);
#endif
            PUSH_TYPE(return_types[i]);
        }
        return true;
    }

    if (available_stack_cell != return_cell_num) {
#if WASM_ENABLE_EXCE_HANDLING != 0
        /* testspec: this error message format is expected by try_catch.wast */
        snprintf(
            error_buf, error_buf_size, "type mismatch: %s requires [%s]%s[%s]",
            block->label_type == LABEL_TYPE_TRY
                    || (block->label_type == LABEL_TYPE_CATCH
                        && return_cell_num > 0)
                ? "instruction"
                : "block",
            return_cell_num > 0 ? type2str(return_types[0]) : "",
            " but stack has ",
            available_stack_cell > 0 ? type2str(*(loader_ctx->frame_ref - 1))
                                     : "");
        goto fail;
#else
        set_error_buf(error_buf, error_buf_size,
                      "type mismatch: stack size does not match block type");
        goto fail;
#endif
    }

    /* Check stack values match return types */
    frame_ref = loader_ctx->frame_ref;
#if WASM_ENABLE_GC != 0
    frame_reftype_map = loader_ctx->frame_reftype_map;
    return_reftype_map =
        return_reftype_map_count
            ? return_reftype_maps + return_reftype_map_count - 1
            : NULL;
#endif
    for (i = (int32)return_count - 1; i >= 0; i--) {
        uint8 type = return_types[i];
#if WASM_ENABLE_GC != 0
        bool is_type_multi_byte = wasm_is_type_multi_byte_type(type);
        ref_type = NULL;
        if (is_type_multi_byte) {
            bh_assert(return_reftype_map);
            ref_type = return_reftype_map->ref_type;
        }
#endif
        if (!check_stack_top_values(loader_ctx, frame_ref, available_stack_cell,
#if WASM_ENABLE_GC != 0
                                    frame_reftype_map, available_reftype_map,
#endif
                                    type,
#if WASM_ENABLE_GC != 0
                                    ref_type,
#endif
                                    error_buf, error_buf_size))
            return false;
        frame_ref -= wasm_value_type_cell_num(return_types[i]);
        available_stack_cell -= wasm_value_type_cell_num(return_types[i]);
#if WASM_ENABLE_GC != 0
        if (is_type_multi_byte) {
            frame_reftype_map--;
            available_reftype_map--;
            return_reftype_map--;
        }
#endif
    }

    return true;

fail:
    return false;
}

#if WASM_ENABLE_FAST_INTERP != 0
/* Copy parameters to dynamic space.
 * 1) POP original parameter out;
 * 2) Push and copy original values to dynamic space.
 * The copy instruction format:
 *   Part a: param count
 *   Part b: all param total cell num
 *   Part c: each param's cell_num, src offset and dst offset
 *   Part d: each param's src offset
 *   Part e: each param's dst offset
 */
static bool
copy_params_to_dynamic_space(WASMLoaderContext *loader_ctx, char *error_buf,
                             uint32 error_buf_size)
{
    bool ret = false;
    int16 *frame_offset = NULL;
    uint8 *cells = NULL, cell;
    int16 *src_offsets = NULL;
    uint8 *emit_data = NULL;
    uint32 i;
    BranchBlock *block = loader_ctx->frame_csp - 1;
    BlockType *block_type = &block->block_type;
    WASMFuncType *wasm_type = block_type->u.type;
    uint32 param_count = block_type->u.type->param_count;
    int16 condition_offset = 0;
    bool disable_emit = false;
    bool is_if_block = (block->label_type == LABEL_TYPE_IF ? true : false);
    int16 operand_offset = 0;

    uint64 size = (uint64)param_count * (sizeof(*cells) + sizeof(*src_offsets));
    bh_assert(size > 0);

    /* For if block, we also need copy the condition operand offset. */
    if (is_if_block)
        size += sizeof(*cells) + sizeof(*src_offsets);

    /* Allocate memory for the emit data */
    if (!(emit_data = loader_malloc(size, error_buf, error_buf_size)))
        return false;

    cells = emit_data;
    src_offsets = (int16 *)(cells + param_count);

    if (is_if_block)
        condition_offset = *loader_ctx->frame_offset;

    /* POP original parameter out */
    for (i = 0; i < param_count; i++) {
        POP_OFFSET_TYPE(wasm_type->types[param_count - i - 1]);
        wasm_loader_emit_backspace(loader_ctx, sizeof(int16));
    }
    frame_offset = loader_ctx->frame_offset;

    /* Get each param's cell num and src offset */
    for (i = 0; i < param_count; i++) {
        cell = (uint8)wasm_value_type_cell_num(wasm_type->types[i]);
        cells[i] = cell;
        src_offsets[i] = *frame_offset;
        frame_offset += cell;
    }
    /* emit copy instruction */
    emit_label(EXT_OP_COPY_STACK_VALUES);
    /* Part a) */
    emit_uint32(loader_ctx, is_if_block ? param_count + 1 : param_count);
    /* Part b) */
    emit_uint32(loader_ctx, is_if_block ? wasm_type->param_cell_num + 1
                                        : wasm_type->param_cell_num);
    /* Part c) */
    for (i = 0; i < param_count; i++)
        emit_byte(loader_ctx, cells[i]);
    if (is_if_block)
        emit_byte(loader_ctx, 1);

    /* Part d) */
    for (i = 0; i < param_count; i++)
        emit_operand(loader_ctx, src_offsets[i]);
    if (is_if_block)
        emit_operand(loader_ctx, condition_offset);

    /* Since the start offset to save the block's params and
     * the start offset to save the block's results may be
     * different, we remember the dynamic offset for loop block
     * so that we can use it to copy the stack operands to the
     * loop block's params in wasm_loader_emit_br_info. */
    if (block->label_type == LABEL_TYPE_LOOP)
        block->start_dynamic_offset = loader_ctx->dynamic_offset;

    /* Part e) */
    /* Push to dynamic space. The push will emit the dst offset. */
    for (i = 0; i < param_count; i++)
        PUSH_OFFSET_TYPE(wasm_type->types[i]);
    if (is_if_block)
        PUSH_OFFSET_TYPE(VALUE_TYPE_I32);

    ret = true;

fail:
    /* Free the emit data */
    wasm_runtime_free(emit_data);

    return ret;
}
#endif

#if WASM_ENABLE_GC == 0
#define RESET_REFTYPE_MAP_STACK() (void)0
#else
#define RESET_REFTYPE_MAP_STACK()                                            \
    do {                                                                     \
        loader_ctx->reftype_map_num =                                        \
            (loader_ctx->frame_csp - 1)->reftype_map_num;                    \
        loader_ctx->frame_reftype_map = loader_ctx->frame_reftype_map_bottom \
                                        + loader_ctx->reftype_map_num;       \
    } while (0)
#endif

/* reset the stack to the state of before entering the last block */
#if WASM_ENABLE_FAST_INTERP != 0
#define RESET_STACK()                                                     \
    do {                                                                  \
        loader_ctx->stack_cell_num =                                      \
            (loader_ctx->frame_csp - 1)->stack_cell_num;                  \
        loader_ctx->frame_ref =                                           \
            loader_ctx->frame_ref_bottom + loader_ctx->stack_cell_num;    \
        loader_ctx->frame_offset =                                        \
            loader_ctx->frame_offset_bottom + loader_ctx->stack_cell_num; \
        RESET_REFTYPE_MAP_STACK();                                        \
    } while (0)
#else
#define RESET_STACK()                                                  \
    do {                                                               \
        loader_ctx->stack_cell_num =                                   \
            (loader_ctx->frame_csp - 1)->stack_cell_num;               \
        loader_ctx->frame_ref =                                        \
            loader_ctx->frame_ref_bottom + loader_ctx->stack_cell_num; \
        RESET_REFTYPE_MAP_STACK();                                     \
    } while (0)
#endif

/* set current block's stack polymorphic state */
#define SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(flag)          \
    do {                                                     \
        BranchBlock *_cur_block = loader_ctx->frame_csp - 1; \
        _cur_block->is_stack_polymorphic = flag;             \
    } while (0)

#define BLOCK_HAS_PARAM(block_type) \
    (!block_type.is_value_type && block_type.u.type->param_count > 0)

#define PRESERVE_LOCAL_FOR_BLOCK()                                    \
    do {                                                              \
        if (!(preserve_local_for_block(loader_ctx, opcode, error_buf, \
                                       error_buf_size))) {            \
            goto fail;                                                \
        }                                                             \
    } while (0)

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
static bool
get_table_elem_type(const WASMModule *module, uint32 table_idx,
                    uint8 *p_elem_type, void **p_ref_type, char *error_buf,
                    uint32 error_buf_size)
{
    if (!check_table_index(module, table_idx, error_buf, error_buf_size)) {
        return false;
    }

    if (table_idx < module->import_table_count) {
        if (p_elem_type)
            *p_elem_type =
                module->import_tables[table_idx].u.table.table_type.elem_type;
#if WASM_ENABLE_GC != 0
        if (p_ref_type)
            *((WASMRefType **)p_ref_type) =
                module->import_tables[table_idx]
                    .u.table.table_type.elem_ref_type;
#endif
    }
    else {
        if (p_elem_type)
            *p_elem_type =
                module->tables[table_idx - module->import_table_count]
                    .table_type.elem_type;
#if WASM_ENABLE_GC != 0
        if (p_ref_type)
            *((WASMRefType **)p_ref_type) =
                module->tables[table_idx - module->import_table_count]
                    .table_type.elem_ref_type;
#endif
    }
    return true;
}

static bool
get_table_seg_elem_type(const WASMModule *module, uint32 table_seg_idx,
                        uint8 *p_elem_type, void **p_elem_ref_type,
                        char *error_buf, uint32 error_buf_size)
{
    if (table_seg_idx >= module->table_seg_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown elem segment %u",
                        table_seg_idx);
        return false;
    }

    if (p_elem_type) {
        *p_elem_type = module->table_segments[table_seg_idx].elem_type;
    }
#if WASM_ENABLE_GC != 0
    if (p_elem_ref_type)
        *((WASMRefType **)p_elem_ref_type) =
            module->table_segments[table_seg_idx].elem_ref_type;
#endif
    return true;
}
#endif

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
const uint8 *
wasm_loader_get_custom_section(WASMModule *module, const char *name,
                               uint32 *len)
{
    WASMCustomSection *section = module->custom_section_list;

    while (section) {
        if ((section->name_len == strlen(name))
            && (memcmp(section->name_addr, name, section->name_len) == 0)) {
            if (len) {
                *len = section->content_len;
            }
            return section->content_addr;
        }

        section = section->next;
    }

    return NULL;
}
#endif

#if 0
#define HANDLE_OPCODE(opcode) #opcode
DEFINE_GOTO_TABLE(const char *, op_mnemonics);
#undef HANDLE_OPCODE
#endif

#if WASM_ENABLE_FAST_INTERP == 0

#define pb_read_leb_uint32 read_leb_uint32
#define pb_read_leb_int32 read_leb_int32
#define pb_read_leb_int64 read_leb_int64
#define pb_read_leb_memarg read_leb_memarg
#define pb_read_leb_mem_offset read_leb_mem_offset

#else

/* Read leb without malformed format check */
static uint64
read_leb_quick(uint8 **p_buf, uint32 maxbits, bool sign)
{
    uint8 *buf = *p_buf;
    uint64 result = 0, byte = 0;
    uint32 shift = 0;

    do {
        byte = *buf++;
        result |= ((byte & 0x7f) << shift);
        shift += 7;
    } while (byte & 0x80);

    if (sign && (shift < maxbits) && (byte & 0x40)) {
        /* Sign extend */
        result |= (~((uint64)0)) << shift;
    }

    *p_buf = buf;
    return result;
}

#define pb_read_leb_uint32(p, p_end, res)                 \
    do {                                                  \
        if (!loader_ctx->p_code_compiled)                 \
            /* Enable format check in the first scan */   \
            read_leb_uint32(p, p_end, res);               \
        else                                              \
            /* Disable format check in the second scan */ \
            res = (uint32)read_leb_quick(&p, 32, false);  \
    } while (0)

#define pb_read_leb_int32(p, p_end, res)                  \
    do {                                                  \
        if (!loader_ctx->p_code_compiled)                 \
            /* Enable format check in the first scan */   \
            read_leb_int32(p, p_end, res);                \
        else                                              \
            /* Disable format check in the second scan */ \
            res = (int32)read_leb_quick(&p, 32, true);    \
    } while (0)

#define pb_read_leb_int64(p, p_end, res)                  \
    do {                                                  \
        if (!loader_ctx->p_code_compiled)                 \
            /* Enable format check in the first scan */   \
            read_leb_int64(p, p_end, res);                \
        else                                              \
            /* Disable format check in the second scan */ \
            res = (int64)read_leb_quick(&p, 64, true);    \
    } while (0)

#if WASM_ENABLE_MULTI_MEMORY != 0
#define pb_read_leb_memarg read_leb_memarg
#else
#define pb_read_leb_memarg pb_read_leb_uint32
#endif

#if WASM_ENABLE_MEMORY64 != 0
#define pb_read_leb_mem_offset read_leb_mem_offset
#else
#define pb_read_leb_mem_offset pb_read_leb_uint32
#endif

#endif /* end of WASM_ENABLE_FAST_INTERP != 0 */

static bool
wasm_loader_prepare_bytecode(WASMModule *module, WASMFunction *func,
                             uint32 cur_func_idx, char *error_buf,
                             uint32 error_buf_size)
{
    uint8 *p = func->code, *p_end = func->code + func->code_size, *p_org;
    uint32 param_count, local_count, global_count;
    uint8 *param_types, *local_types, local_type, global_type, mem_offset_type,
        table_elem_idx_type;
    BlockType func_block_type;
    uint16 *local_offsets, local_offset;
    uint32 type_idx, func_idx, local_idx, global_idx, table_idx;
    uint32 table_seg_idx, data_seg_idx, count, align, i;
    mem_offset_t mem_offset;
    int32 i32_const = 0;
    int64 i64_const;
    uint8 opcode;
    bool return_value = false;
    WASMLoaderContext *loader_ctx;
    BranchBlock *frame_csp_tmp;
#if WASM_ENABLE_GC != 0
    WASMRefTypeMap *param_reftype_maps, *local_reftype_maps;
    uint32 param_reftype_map_count, local_reftype_map_count;
    int32 heap_type;
    WASMRefType wasm_ref_type = { 0 };
    bool need_ref_type_map;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
    int16 operand_offset = 0;
    uint8 last_op = 0;
    bool disable_emit, preserve_local = false, if_condition_available = true;
    float32 f32_const;
    float64 f64_const;
    /*
     * It means that the fast interpreter detected an exception while preparing,
     * typically near the block opcode, but it did not immediately trigger
     * the exception. The loader should be capable of identifying it near
     * the end opcode and then raising the exception.
     */
    bool pending_exception = false;

    LOG_OP("\nProcessing func | [%d] params | [%d] locals | [%d] return\n",
           func->param_cell_num, func->local_cell_num, func->ret_cell_num);
#endif
#if WASM_ENABLE_MEMORY64 != 0
    bool is_memory64 = has_module_memory64(module);
    mem_offset_type = is_memory64 ? VALUE_TYPE_I64 : VALUE_TYPE_I32;
#else
    mem_offset_type = VALUE_TYPE_I32;
    table_elem_idx_type = VALUE_TYPE_I32;
#endif
    uint32 memidx;

    global_count = module->import_global_count + module->global_count;

    param_count = func->func_type->param_count;
    param_types = func->func_type->types;

    func_block_type.is_value_type = false;
    func_block_type.u.type = func->func_type;

    local_count = func->local_count;
    local_types = func->local_types;
    local_offsets = func->local_offsets;

#if WASM_ENABLE_GC != 0
    param_reftype_maps = func->func_type->ref_type_maps;
    param_reftype_map_count = func->func_type->ref_type_map_count;
    local_reftype_maps = func->local_ref_type_maps;
    local_reftype_map_count = func->local_ref_type_map_count;
#endif

    if (!(loader_ctx = wasm_loader_ctx_init(func, error_buf, error_buf_size))) {
        goto fail;
    }
#if WASM_ENABLE_GC != 0
    loader_ctx->module = module;
    loader_ctx->ref_type_set = module->ref_type_set;
    loader_ctx->ref_type_tmp = &wasm_ref_type;
#endif

#if WASM_ENABLE_FAST_INTERP != 0
    /* For the first traverse, the initial value of preserved_local_offset has
     * not been determined, we use the INT16_MAX to represent that a slot has
     * been copied to preserve space. For second traverse, this field will be
     * set to the appropriate value in wasm_loader_ctx_reinit.
     * This is for Issue #1230,
     * https://github.com/bytecodealliance/wasm-micro-runtime/issues/1230, the
     * drop opcodes need to know which slots are preserved, so those slots will
     * not be treated as dynamically allocated slots */
    loader_ctx->preserved_local_offset = INT16_MAX;

re_scan:
    if (loader_ctx->code_compiled_size > 0) {
        if (!wasm_loader_ctx_reinit(loader_ctx)) {
            set_error_buf(error_buf, error_buf_size, "allocate memory failed");
            goto fail;
        }
        p = func->code;
        func->code_compiled = loader_ctx->p_code_compiled;
        func->code_compiled_size = loader_ctx->code_compiled_size;

        if (loader_ctx->i64_const_num > 0) {
            int64 *i64_consts_old = loader_ctx->i64_consts;

            /* Sort the i64 consts */
            qsort(i64_consts_old, loader_ctx->i64_const_num, sizeof(int64),
                  cmp_i64_const);

            /* Remove the duplicated i64 consts */
            uint32 k = 1;
            for (i = 1; i < loader_ctx->i64_const_num; i++) {
                if (i64_consts_old[i] != i64_consts_old[i - 1]) {
                    i64_consts_old[k++] = i64_consts_old[i];
                }
            }

            if (k < loader_ctx->i64_const_num) {
                int64 *i64_consts_new;
                /* Try to reallocate memory with a smaller size */
                if ((i64_consts_new =
                         wasm_runtime_malloc((uint32)sizeof(int64) * k))) {
                    bh_memcpy_s(i64_consts_new, (uint32)sizeof(int64) * k,
                                i64_consts_old, (uint32)sizeof(int64) * k);
                    /* Free the old memory */
                    wasm_runtime_free(i64_consts_old);
                    loader_ctx->i64_consts = i64_consts_new;
                    loader_ctx->i64_const_max_num = k;
                }
                loader_ctx->i64_const_num = k;
            }
        }

        if (loader_ctx->v128_const_num > 0) {
            V128 *v128_consts_old = loader_ctx->v128_consts;

            /* Sort the v128 consts */
            qsort(v128_consts_old, loader_ctx->v128_const_num, sizeof(V128),
                  cmp_v128_const);

            /* Remove the duplicated v128 consts */
            uint32 k = 1;
            for (i = 1; i < loader_ctx->v128_const_num; i++) {
                if (!(memcmp(&v128_consts_old[i], &v128_consts_old[i - 1],
                             sizeof(V128))
                      == 0)) {
                    v128_consts_old[k++] = v128_consts_old[i];
                }
            }

            if (k < loader_ctx->v128_const_num) {
                V128 *v128_consts_new;
                /* Try to reallocate memory with a smaller size */
                if ((v128_consts_new =
                         wasm_runtime_malloc((uint32)sizeof(V128) * k))) {
                    bh_memcpy_s(v128_consts_new, (uint32)sizeof(V128) * k,
                                v128_consts_old, (uint32)sizeof(V128) * k);
                    /* Free the old memory */
                    wasm_runtime_free(v128_consts_old);
                    loader_ctx->v128_consts = v128_consts_new;
                    loader_ctx->v128_const_max_num = k;
                }
                loader_ctx->v128_const_num = k;
            }
        }

        if (loader_ctx->i32_const_num > 0) {
            int32 *i32_consts_old = loader_ctx->i32_consts;

            /* Sort the i32 consts */
            qsort(i32_consts_old, loader_ctx->i32_const_num, sizeof(int32),
                  cmp_i32_const);

            /* Remove the duplicated i32 consts */
            uint32 k = 1;
            for (i = 1; i < loader_ctx->i32_const_num; i++) {
                if (i32_consts_old[i] != i32_consts_old[i - 1]) {
                    i32_consts_old[k++] = i32_consts_old[i];
                }
            }

            if (k < loader_ctx->i32_const_num) {
                int32 *i32_consts_new;
                /* Try to reallocate memory with a smaller size */
                if ((i32_consts_new =
                         wasm_runtime_malloc((uint32)sizeof(int32) * k))) {
                    bh_memcpy_s(i32_consts_new, (uint32)sizeof(int32) * k,
                                i32_consts_old, (uint32)sizeof(int32) * k);
                    /* Free the old memory */
                    wasm_runtime_free(i32_consts_old);
                    loader_ctx->i32_consts = i32_consts_new;
                    loader_ctx->i32_const_max_num = k;
                }
                loader_ctx->i32_const_num = k;
            }
        }
    }
#endif

    PUSH_CSP(LABEL_TYPE_FUNCTION, func_block_type, p);

    while (p < p_end) {
        opcode = *p++;
#if WASM_ENABLE_FAST_INTERP != 0
        p_org = p;
        disable_emit = false;
        emit_label(opcode);
#endif
        switch (opcode) {
            case WASM_OP_UNREACHABLE:
                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;

            case WASM_OP_NOP:
#if WASM_ENABLE_FAST_INTERP != 0
                skip_label();
#endif
                break;

            case WASM_OP_IF:
            {
#if WASM_ENABLE_FAST_INTERP != 0
                BranchBlock *parent_block = loader_ctx->frame_csp - 1;
                int32 available_stack_cell =
                    (int32)(loader_ctx->stack_cell_num
                            - parent_block->stack_cell_num);

                if (available_stack_cell <= 0
                    && parent_block->is_stack_polymorphic)
                    if_condition_available = false;
                else
                    if_condition_available = true;

                PRESERVE_LOCAL_FOR_BLOCK();
#endif
#if WASM_ENABLE_GC == 0
                POP_I32();
#endif
                goto handle_op_block_and_loop;
            }
            case WASM_OP_BLOCK:
            case WASM_OP_LOOP:
#if WASM_ENABLE_EXCE_HANDLING != 0
            case WASM_OP_TRY:
                if (opcode == WASM_OP_TRY) {
                    /*
                     * keep track of exception handlers to account for
                     * memory allocation
                     */
                    func->exception_handler_count++;

                    /*
                     * try is a block
                     * do nothing special, but execution continues to
                     * to handle_op_block_and_loop,
                     * and that be pushes the csp
                     */
                }

#endif
#if WASM_ENABLE_FAST_INTERP != 0
                PRESERVE_LOCAL_FOR_BLOCK();
#endif
            handle_op_block_and_loop:
            {
                uint8 value_type;
                BlockType block_type;
#if WASM_ENABLE_FAST_INTERP != 0
                uint32 available_params = 0;
#endif

                CHECK_BUF(p, p_end, 1);
                value_type = read_uint8(p);
                if (is_byte_a_type(value_type)) {
                    /* If the first byte is one of these special values:
                     * 0x40/0x7F/0x7E/0x7D/0x7C, take it as the type of
                     * the single return value. */
                    block_type.is_value_type = true;
                    block_type.u.value_type.type = value_type;
#if WASM_ENABLE_WAMR_COMPILER != 0
                    if (value_type == VALUE_TYPE_V128)
                        module->is_simd_used = true;
                    else if (value_type == VALUE_TYPE_FUNCREF
                             || value_type == VALUE_TYPE_EXTERNREF)
                        module->is_ref_types_used = true;
#endif
#if WASM_ENABLE_GC != 0
                    if (value_type != VALUE_TYPE_VOID) {
                        p_org = p;
                        p--;
                        if (!resolve_value_type((const uint8 **)&p, p_end,
                                                module, module->type_count,
                                                &need_ref_type_map,
                                                &wasm_ref_type, false,
                                                error_buf, error_buf_size)) {
                            goto fail;
                        }
                        if (need_ref_type_map) {
                            block_type.u.value_type.ref_type_map.index = 0;
                            if (!(block_type.u.value_type.ref_type_map
                                      .ref_type = reftype_set_insert(
                                      module->ref_type_set, &wasm_ref_type,
                                      error_buf, error_buf_size))) {
                                goto fail;
                            }
                        }
                        /* Set again as the type might be changed, e.g.
                           (ref null any) to anyref */
                        block_type.u.value_type.type = wasm_ref_type.ref_type;
#if WASM_ENABLE_FAST_INTERP == 0
                        while (p_org < p) {
#if WASM_ENABLE_DEBUG_INTERP != 0
                            if (!record_fast_op(module, p_org, *p_org,
                                                error_buf, error_buf_size)) {
                                goto fail;
                            }
#endif
                            /* Ignore extra bytes for interpreter */
                            *p_org++ = WASM_OP_NOP;
                        }
#endif
                    }
#endif /* end of WASM_ENABLE_GC != 0 */
                }
                else {
                    int32 type_index;

                    /* Resolve the leb128 encoded type index as block type */
                    p--;
                    p_org = p - 1;
                    pb_read_leb_int32(p, p_end, type_index);

                    if (!check_function_type(module, type_index, error_buf,
                                             error_buf_size)) {
                        goto fail;
                    }

                    block_type.is_value_type = false;
                    block_type.u.type =
                        (WASMFuncType *)module->types[type_index];
#if WASM_ENABLE_FAST_INTERP == 0
                    /* If block use type index as block type, change the opcode
                     * to new extended opcode so that interpreter can resolve
                     * the block quickly.
                     */
#if WASM_ENABLE_DEBUG_INTERP != 0
                    if (!record_fast_op(module, p_org, *p_org, error_buf,
                                        error_buf_size)) {
                        goto fail;
                    }
#endif
                    *p_org = EXT_OP_BLOCK + (opcode - WASM_OP_BLOCK);
#endif
                }

#if WASM_ENABLE_GC != 0
                if (opcode == WASM_OP_IF) {
                    POP_I32();
                }
#endif

                /* Pop block parameters from stack */
                if (BLOCK_HAS_PARAM(block_type)) {
                    WASMFuncType *wasm_type = block_type.u.type;

                    BranchBlock *cur_block = loader_ctx->frame_csp - 1;
#if WASM_ENABLE_FAST_INTERP != 0
                    uint32 cell_num;
                    available_params = block_type.u.type->param_count;
#endif
                    for (i = 0; i < block_type.u.type->param_count; i++) {

                        int32 available_stack_cell =
                            (int32)(loader_ctx->stack_cell_num
                                    - cur_block->stack_cell_num);
                        if (available_stack_cell <= 0
                            && cur_block->is_stack_polymorphic) {
#if WASM_ENABLE_FAST_INTERP != 0
                            available_params = i;
#endif
                            break;
                        }

                        uint8 *frame_ref_before_pop = loader_ctx->frame_ref;
                        POP_TYPE(
                            wasm_type->types[wasm_type->param_count - i - 1]);
#if WASM_ENABLE_FAST_INTERP != 0
                        /* decrease the frame_offset pointer accordingly to keep
                         * consistent with frame_ref stack. Use the actual
                         * popped cell count instead of
                         * wasm_value_type_cell_num() because when the stack top
                         * is VALUE_TYPE_ANY, wasm_loader_pop_frame_ref always
                         * pops exactly 1 cell regardless of the expected type
                         */
                        cell_num = (uint32)(frame_ref_before_pop
                                            - loader_ctx->frame_ref);
                        loader_ctx->frame_offset -= cell_num;

                        if (loader_ctx->frame_offset
                            < loader_ctx->frame_offset_bottom) {
                            LOG_DEBUG(
                                "frame_offset underflow, roll back and "
                                "let following stack checker report it\n");
                            loader_ctx->frame_offset += cell_num;
                            pending_exception = true;
                            break;
                        }
#endif
                    }
                }
                PUSH_CSP(LABEL_TYPE_BLOCK + (opcode - WASM_OP_BLOCK),
                         block_type, p);

                /* Pass parameters to block */
                if (BLOCK_HAS_PARAM(block_type)) {
                    WASMFuncType *func_type = block_type.u.type;
#if WASM_ENABLE_GC != 0
                    WASMRefType *ref_type;
                    uint32 j = 0;
#endif
                    for (i = 0; i < func_type->param_count; i++) {
#if WASM_ENABLE_FAST_INTERP != 0
                        uint32 cell_num =
                            wasm_value_type_cell_num(func_type->types[i]);
                        if (i >= available_params) {
                            /* make sure enough space */
                            if (loader_ctx->p_code_compiled == NULL) {
                                loader_ctx->frame_offset += cell_num;
                                if (!check_offset_push(loader_ctx, error_buf,
                                                       error_buf_size))
                                    goto fail;
                                /* for following dummy value assignment */
                                loader_ctx->frame_offset -= cell_num;
                            }

                            /* If there isn't enough data on stack, push a dummy
                             * offset to keep the stack consistent with
                             * frame_ref.
                             * Since the stack is already in polymorphic state,
                             * the opcode will not be executed, so the dummy
                             * offset won't cause any error */
                            for (uint32 n = 0; n < cell_num; n++) {
                                *loader_ctx->frame_offset++ = 0;
                            }
                        }
                        else {
                            loader_ctx->frame_offset += cell_num;
                        }
#endif
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_multi_byte_type(func_type->types[i])) {
                            bh_assert(func_type->ref_type_maps[j].index == i);
                            ref_type = func_type->ref_type_maps[j].ref_type;
                            bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                        ref_type,
                                        wasm_reftype_struct_size(ref_type));
                            j++;
                        }
#endif
                        PUSH_TYPE(func_type->types[i]);
                    }
                }

#if WASM_ENABLE_FAST_INTERP != 0
                if (opcode == WASM_OP_BLOCK || opcode == WASM_OP_LOOP) {
                    skip_label();

                    if (BLOCK_HAS_PARAM(block_type)) {
                        /* Make sure params are in dynamic space */
                        if (!copy_params_to_dynamic_space(loader_ctx, error_buf,
                                                          error_buf_size))
                            goto fail;
                    }

                    if (opcode == WASM_OP_LOOP) {
                        (loader_ctx->frame_csp - 1)->code_compiled =
                            loader_ctx->p_code_compiled;
                    }
                }
#if WASM_ENABLE_EXCE_HANDLING != 0
                else if (opcode == WASM_OP_TRY) {
                    skip_label();
                }
#endif
                else if (opcode == WASM_OP_IF) {
                    BranchBlock *block = loader_ctx->frame_csp - 1;
                    /* If block has parameters, we should make sure they are in
                     * dynamic space. Otherwise, when else branch is missing,
                     * the later opcode may consume incorrect operand offset.
                     * Spec case:
                     *   (func (export "params-id") (param i32) (result i32)
                     *       (i32.const 1)
                     *       (i32.const 2)
                     *       (if (param i32 i32) (result i32 i32) (local.get 0)
                     *       (then)) (i32.add)
                     *   )
                     *
                     * So we should emit a copy instruction before the if.
                     *
                     * And we also need to save the parameter offsets and
                     * recover them before entering else branch.
                     *
                     */
                    if (BLOCK_HAS_PARAM(block_type)) {
                        uint64 size;

                        /* In polymorphic state, there may be no if condition on
                         * the stack, so the offset may not emitted */
                        if (if_condition_available) {
                            /* skip the if condition operand offset */
                            wasm_loader_emit_backspace(loader_ctx,
                                                       sizeof(int16));
                        }
                        /* skip the if label */
                        skip_label();
                        /* Emit a copy instruction */
                        if (!copy_params_to_dynamic_space(loader_ctx, error_buf,
                                                          error_buf_size))
                            goto fail;

                        /* Emit the if instruction */
                        emit_label(opcode);
                        /* Emit the new condition operand offset */
                        POP_OFFSET_TYPE(VALUE_TYPE_I32);

                        /* Save top param_count values of frame_offset stack, so
                         * that we can recover it before executing else branch
                         */
                        size = sizeof(int16)
                               * (uint64)block_type.u.type->param_cell_num;
                        if (!(block->param_frame_offsets = loader_malloc(
                                  size, error_buf, error_buf_size)))
                            goto fail;
                        bh_memcpy_s(block->param_frame_offsets, (uint32)size,
                                    loader_ctx->frame_offset
                                        - size / sizeof(int16),
                                    (uint32)size);
                    }

                    block->start_dynamic_offset = loader_ctx->dynamic_offset;

                    emit_empty_label_addr_and_frame_ip(PATCH_ELSE);
                    emit_empty_label_addr_and_frame_ip(PATCH_END);
                }
#endif
                break;
            }
#if WASM_ENABLE_EXCE_HANDLING != 0
            case WASM_OP_THROW:
            {
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);

                BranchBlock *cur_block = loader_ctx->frame_csp - 1;

                uint8 label_type = cur_block->label_type;
                uint32 tag_index = 0;
                pb_read_leb_int32(p, p_end, tag_index);

                /* check validity of tag_index against module->tag_count */
                /* check tag index is within the tag index space */
                if (tag_index >= module->import_tag_count + module->tag_count) {
                    snprintf(error_buf, error_buf_size, "unknown tag %d",
                             tag_index);
                    goto fail;
                }

                /* the tag_type is stored in either the WASMTag (section tags)
                 * or WASMTagImport (import tag) */
                WASMFuncType *tag_type = NULL;
                if (tag_index < module->import_tag_count) {
                    tag_type = module->import_tags[tag_index].u.tag.tag_type;
                }
                else {
                    tag_type =
                        module->tags[tag_index - module->import_tag_count]
                            ->tag_type;
                }

                if (tag_type->result_count != 0) {
                    set_error_buf(error_buf, error_buf_size,
                                  "tag type signature does not return void");
                    goto fail;
                }

                int32 available_stack_cell =
                    (int32)(loader_ctx->stack_cell_num
                            - cur_block->stack_cell_num);
                int32 tti;

                /* Check stack values match return types by comparing tag param
                 * types with stack cells */
                uint8 *frame_ref = loader_ctx->frame_ref;
#if WASM_ENABLE_GC != 0
                WASMRefTypeMap *frame_reftype_map =
                    loader_ctx->frame_reftype_map;
                uint32 frame_reftype_map_num = loader_ctx->reftype_map_num;

                /* Temporarily set these values since they may be used in
                   GET_LOCAL_REFTYPE(), remember they must be restored later */
                param_reftype_maps = tag_type->ref_type_maps;
                /* For tag_type function, it shouldn't have result_count = 0 */
                param_reftype_map_count = tag_type->ref_type_map_count;
                param_count = tag_type->param_count;
#endif

                for (tti = (int32)tag_type->param_count - 1; tti >= 0; tti--) {
#if WASM_ENABLE_GC != 0
                    local_type = tag_type->types[tti];
                    local_idx = tti;
                    /* Get the wasm_ref_type if the local_type is multibyte
                       type */
                    GET_LOCAL_REFTYPE();
#endif

                    if (!check_stack_top_values(
                            loader_ctx, frame_ref, available_stack_cell,
#if WASM_ENABLE_GC != 0
                            frame_reftype_map, frame_reftype_map_num,
#endif
                            tag_type->types[tti],
#if WASM_ENABLE_GC != 0
                            &wasm_ref_type,
#endif
                            error_buf, error_buf_size)) {
                        snprintf(error_buf, error_buf_size,
                                 "type mismatch: instruction requires [%s] but "
                                 "stack has [%s]",
                                 tag_type->param_count > 0
                                     ? type2str(tag_type->types[tti])
                                     : "",
                                 available_stack_cell > 0
                                     ? type2str(*(loader_ctx->frame_ref - 1))
                                     : "");
                        goto fail;
                    }
                    frame_ref -= wasm_value_type_cell_num(tag_type->types[tti]);
                    available_stack_cell -=
                        wasm_value_type_cell_num(tag_type->types[tti]);
                }

#if WASM_ENABLE_GC != 0
                /* Restore the values */
                param_reftype_maps = func->func_type->ref_type_maps;
                param_reftype_map_count = func->func_type->ref_type_map_count;
                param_count = func->func_type->param_count;
#endif

                /* throw is stack polymorphic */
                (void)label_type;
                RESET_STACK();

                break;
            }
            case WASM_OP_RETHROW:
            {
                /* must be done before checking branch block */
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);

                /* check the target catching block:  LABEL_TYPE_CATCH */
                if (!(frame_csp_tmp =
                          check_branch_block(loader_ctx, &p, p_end, opcode,
                                             error_buf, error_buf_size)))
                    goto fail;

                if (frame_csp_tmp->label_type != LABEL_TYPE_CATCH
                    && frame_csp_tmp->label_type != LABEL_TYPE_CATCH_ALL) {
                    /* trap according to spectest (rethrow.wast) */
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid rethrow label");
                    goto fail;
                }

                BranchBlock *cur_block = loader_ctx->frame_csp - 1;
                uint8 label_type = cur_block->label_type;
                (void)label_type;
                /* rethrow is stack polymorphic */
                RESET_STACK();
                break;
            }
            case WASM_OP_DELEGATE:
            {
                /* check  target block is valid */
                if (!(frame_csp_tmp = check_branch_block_for_delegate(
                          loader_ctx, &p, p_end, error_buf, error_buf_size)))
                    goto fail;

                BranchBlock *cur_block = loader_ctx->frame_csp - 1;
                uint8 label_type = cur_block->label_type;

                (void)label_type;
                /* DELEGATE ends the block */
                POP_CSP();
                break;
            }
            case WASM_OP_CATCH:
            {
                BranchBlock *cur_block = loader_ctx->frame_csp - 1;

                uint8 label_type = cur_block->label_type;
                uint32 tag_index = 0;
                pb_read_leb_int32(p, p_end, tag_index);

                /* check validity of tag_index against module->tag_count */
                /* check tag index is within the tag index space */
                if (tag_index >= module->import_tag_count + module->tag_count) {
                    LOG_VERBOSE("In %s, unknown tag at WASM_OP_CATCH\n",
                                __FUNCTION__);
                    set_error_buf(error_buf, error_buf_size, "unknown tag");
                    goto fail;
                }

                /* the tag_type is stored in either the WASMTag (section tags)
                 * or WASMTagImport (import tag) */
                WASMFuncType *func_type = NULL;
                if (tag_index < module->import_tag_count) {
                    func_type = module->import_tags[tag_index].u.tag.tag_type;
                }
                else {
                    func_type =
                        module->tags[tag_index - module->import_tag_count]
                            ->tag_type;
                }

                if (func_type->result_count != 0) {
                    set_error_buf(error_buf, error_buf_size,
                                  "tag type signature does not return void");
                    goto fail;
                }

                /* check validity of current label (expect LABEL_TYPE_TRY or
                 * LABEL_TYPE_CATCH) */
                if ((LABEL_TYPE_CATCH != label_type)
                    && (LABEL_TYPE_TRY != label_type)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "Unexpected block sequence encountered.");
                    goto fail;
                }

                /*
                 * replace frame_csp by LABEL_TYPE_CATCH
                 */
                cur_block->label_type = LABEL_TYPE_CATCH;

                /* RESET_STACK removes the values pushed in TRY or previous
                 * CATCH Blocks */
                RESET_STACK();

#if WASM_ENABLE_GC != 0
                WASMRefType *ref_type;
                uint32 j = 0;
#endif

                /* push types on the stack according to caught type */
                for (i = 0; i < func_type->param_count; i++) {
#if WASM_ENABLE_GC != 0
                    if (wasm_is_type_multi_byte_type(func_type->types[i])) {
                        bh_assert(func_type->ref_type_maps[j].index == i);
                        ref_type = func_type->ref_type_maps[j].ref_type;
                        bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                    ref_type,
                                    wasm_reftype_struct_size(ref_type));
                        j++;
                    }
#endif
                    PUSH_TYPE(func_type->types[i]);
                }
                break;
            }
            case WASM_OP_CATCH_ALL:
            {
                BranchBlock *cur_block = loader_ctx->frame_csp - 1;

                /* expecting a TRY or CATCH, anything else will be considered an
                 * error */
                if ((LABEL_TYPE_CATCH != cur_block->label_type)
                    && (LABEL_TYPE_TRY != cur_block->label_type)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "Unexpected block sequence encountered.");
                    goto fail;
                }

                /* no immediates */
                /* replace frame_csp by LABEL_TYPE_CATCH_ALL */
                cur_block->label_type = LABEL_TYPE_CATCH_ALL;

                /* RESET_STACK removes the values pushed in TRY or previous
                 * CATCH Blocks */
                RESET_STACK();

                /* catch_all has no tagtype and therefore no parameters */
                break;
            }
#endif /* end of WASM_ENABLE_EXCE_HANDLING != 0 */
            case WASM_OP_ELSE:
            handle_op_else:
            {
                BranchBlock *block = NULL;
                BlockType block_type;

                if (loader_ctx->csp_num < 2
                    /* the matched if isn't found */
                    || (loader_ctx->frame_csp - 1)->label_type != LABEL_TYPE_IF
                    /* duplicated else is found */
                    || (loader_ctx->frame_csp - 1)->else_addr) {
                    set_error_buf(
                        error_buf, error_buf_size,
                        "opcode else found without matched opcode if");
                    goto fail;
                }
                block = loader_ctx->frame_csp - 1;

                /* check whether if branch's stack matches its result type */
                if (!check_block_stack(loader_ctx, block, error_buf,
                                       error_buf_size))
                    goto fail;

                block->else_addr = p - 1;
                block_type = block->block_type;

#if WASM_ENABLE_GC != 0
                if (!wasm_loader_init_local_use_masks(
                        loader_ctx, local_count, error_buf, error_buf_size)) {
                    goto fail;
                }
#endif

#if WASM_ENABLE_FAST_INTERP != 0
                /* if the result of if branch is in local or const area, add a
                 * copy op */
                if (!reserve_block_ret(loader_ctx, opcode, disable_emit,
                                       error_buf, error_buf_size)) {
                    goto fail;
                }

                emit_empty_label_addr_and_frame_ip(PATCH_END);
                apply_label_patch(loader_ctx, 1, PATCH_ELSE);
#endif
                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(false);

                /* Pass parameters to if-false branch */
                if (BLOCK_HAS_PARAM(block_type)) {
                    for (i = 0; i < block_type.u.type->param_count; i++)
                        PUSH_TYPE(block_type.u.type->types[i]);
                }

#if WASM_ENABLE_FAST_INTERP != 0
                /* Recover top param_count values of frame_offset stack */
                if (BLOCK_HAS_PARAM((block_type))) {
                    uint32 size;
                    size = sizeof(int16) * block_type.u.type->param_cell_num;
                    bh_memcpy_s(loader_ctx->frame_offset, size,
                                block->param_frame_offsets, size);
                    loader_ctx->frame_offset += (size / sizeof(int16));
                }
                loader_ctx->dynamic_offset = block->start_dynamic_offset;
#endif

                break;
            }

            case WASM_OP_END:
            {
                BranchBlock *cur_block = loader_ctx->frame_csp - 1;

                /* check whether block stack matches its result type */
                if (!check_block_stack(loader_ctx, cur_block, error_buf,
                                       error_buf_size))
                    goto fail;

                /* if there is no else branch, make a virtual else opcode for
                   easier integrity check and to copy the correct results to
                   the block return address for fast-interp mode:
                   change if block from `if ... end` to `if ... else end` */
                if (cur_block->label_type == LABEL_TYPE_IF
                    && !cur_block->else_addr) {
                    opcode = WASM_OP_ELSE;
                    p--;
#if WASM_ENABLE_FAST_INTERP != 0
                    p_org = p;
                    skip_label();
                    disable_emit = false;
                    emit_label(opcode);
#endif
                    goto handle_op_else;
                }

                POP_CSP();

#if WASM_ENABLE_FAST_INTERP != 0
                skip_label();
                /* copy the result to the block return address */
                if (!reserve_block_ret(loader_ctx, opcode, disable_emit,
                                       error_buf, error_buf_size)) {
                    /* it could be tmp frame_csp allocated from opcode like
                     * OP_BR and not counted in loader_ctx->csp_num, it won't
                     * be freed in wasm_loader_ctx_destroy(loader_ctx) so need
                     * to free the loader_ctx->frame_csp if fails */
                    free_label_patch_list(loader_ctx->frame_csp);
                    goto fail;
                }

                apply_label_patch(loader_ctx, 0, PATCH_END);
                free_label_patch_list(loader_ctx->frame_csp);
                if (loader_ctx->frame_csp->label_type == LABEL_TYPE_FUNCTION) {
                    int32 idx;
                    uint8 ret_type;

                    emit_label(WASM_OP_RETURN);
                    for (idx = (int32)func->func_type->result_count - 1;
                         idx >= 0; idx--) {
                        ret_type = *(func->func_type->types
                                     + func->func_type->param_count + idx);
                        POP_OFFSET_TYPE(ret_type);
                    }
                }
#endif
                if (loader_ctx->csp_num > 0) {
                    loader_ctx->frame_csp->end_addr = p - 1;
                }
                else {
                    /* end of function block, function will return */
                    if (p < p_end) {
                        set_error_buf(error_buf, error_buf_size,
                                      "section size mismatch");
                        goto fail;
                    }
                }

#if WASM_ENABLE_FAST_INTERP != 0
                if (pending_exception) {
                    set_error_buf(
                        error_buf, error_buf_size,
                        "There is a pending exception needs to be handled");
                    goto fail;
                }
#endif

                break;
            }

            case WASM_OP_BR:
            {
                if (!(frame_csp_tmp =
                          check_branch_block(loader_ctx, &p, p_end, opcode,
                                             error_buf, error_buf_size)))
                    goto fail;

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;
            }

            case WASM_OP_BR_IF:
            {
                POP_I32();

                if (!(frame_csp_tmp =
                          check_branch_block(loader_ctx, &p, p_end, opcode,
                                             error_buf, error_buf_size)))
                    goto fail;

                break;
            }

            case WASM_OP_BR_TABLE:
            {
                uint32 depth = 0, default_arity, arity = 0;
                BranchBlock *target_block;
                BlockType *target_block_type;
#if WASM_ENABLE_FAST_INTERP == 0
                BrTableCache *br_table_cache = NULL;
                uint8 *p_depth_begin, *p_depth, *p_opcode = p - 1;
                uint32 j;
#endif

                pb_read_leb_uint32(p, p_end, count);
#if WASM_ENABLE_FAST_INTERP != 0
                emit_uint32(loader_ctx, count);
#endif
                POP_I32();

                /* Get each depth and check it */
                p_org = p;
                for (i = 0; i <= count; i++) {
                    pb_read_leb_uint32(p, p_end, depth);
                    bh_assert(loader_ctx->csp_num > 0);
                    if (loader_ctx->csp_num - 1 < depth) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown label, "
                                      "unexpected end of section or function");
                        goto fail;
                    }
                }
                p = p_org;

                /* Get the default block's arity */
                target_block = loader_ctx->frame_csp - (depth + 1);
                target_block_type = &target_block->block_type;
                default_arity = block_type_get_arity(target_block_type,
                                                     target_block->label_type);

#if WASM_ENABLE_FAST_INTERP == 0
                p_depth_begin = p_depth = p;
#endif
                for (i = 0; i <= count; i++) {
                    p_org = p;
                    pb_read_leb_uint32(p, p_end, depth);
                    p = p_org;

                    /* Get the target block's arity and check it */
                    target_block = loader_ctx->frame_csp - (depth + 1);
                    target_block_type = &target_block->block_type;
                    arity = block_type_get_arity(target_block_type,
                                                 target_block->label_type);
                    if (arity != default_arity) {
                        set_error_buf(error_buf, error_buf_size,
                                      "type mismatch: br_table targets must "
                                      "all use same result type");
                        goto fail;
                    }

                    if (!(frame_csp_tmp =
                              check_branch_block(loader_ctx, &p, p_end, opcode,
                                                 error_buf, error_buf_size))) {
                        goto fail;
                    }

#if WASM_ENABLE_FAST_INTERP == 0
                    if (br_table_cache) {
                        br_table_cache->br_depths[i] = depth;
                    }
                    else {
                        if (depth > 255) {
                            /* The depth cannot be stored in one byte,
                               create br_table cache to store each depth */
#if WASM_ENABLE_DEBUG_INTERP != 0
                            if (!record_fast_op(module, p_opcode, *p_opcode,
                                                error_buf, error_buf_size)) {
                                goto fail;
                            }
#endif
                            if (!(br_table_cache = loader_malloc(
                                      offsetof(BrTableCache, br_depths)
                                          + sizeof(uint32)
                                                * (uint64)(count + 1),
                                      error_buf, error_buf_size))) {
                                goto fail;
                            }
                            *p_opcode = EXT_OP_BR_TABLE_CACHE;
                            br_table_cache->br_table_op_addr = p_opcode;
                            br_table_cache->br_count = count;
                            /* Copy previous depths which are one byte */
                            for (j = 0; j < i; j++) {
                                br_table_cache->br_depths[j] = p_depth_begin[j];
                            }
                            br_table_cache->br_depths[i] = depth;
                            bh_list_insert(module->br_table_cache_list,
                                           br_table_cache);
                        }
                        else {
                            /* The depth can be stored in one byte, use the
                               byte of the leb to store it */
                            *p_depth++ = (uint8)depth;
                        }
                    }
#endif
                }

#if WASM_ENABLE_FAST_INTERP == 0
                /* Set the tailing bytes to nop */
                if (br_table_cache)
                    p_depth = p_depth_begin;
                while (p_depth < p)
                    *p_depth++ = WASM_OP_NOP;
#endif

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                break;
            }

            case WASM_OP_RETURN:
            {
                WASMFuncType *func_type = func->func_type;
                int32 idx;
                uint8 ret_type;

#if WASM_ENABLE_GC != 0
                uint32 j = func_type->ref_type_map_count - 1;
#endif
                for (idx = (int32)func_type->result_count - 1; idx >= 0;
                     idx--) {
                    ret_type =
                        *(func_type->types + func_type->param_count + idx);
#if WASM_ENABLE_GC != 0
                    if (wasm_is_type_multi_byte_type(ret_type)) {
                        WASMRefType *ref_type =
                            func_type->ref_type_maps[j].ref_type;
                        bh_assert(func_type->ref_type_maps[j].index
                                  == func_type->param_count + idx);
                        bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                    ref_type,
                                    wasm_reftype_struct_size(ref_type));
                        j--;
                    }
#endif
#if WASM_ENABLE_FAST_INTERP != 0
                    /* emit the offset after return opcode */
                    POP_OFFSET_TYPE(ret_type);
#endif
                    POP_TYPE(ret_type);
                }

                RESET_STACK();
                SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);

                break;
            }

            case WASM_OP_CALL:
#if WASM_ENABLE_TAIL_CALL != 0
            case WASM_OP_RETURN_CALL:
#endif
#if WASM_ENABLE_GC != 0
            case WASM_OP_CALL_REF:
            case WASM_OP_RETURN_CALL_REF:
#endif
            {
                WASMFuncType *func_type;
                uint8 type;
                int32 idx;
#if WASM_ENABLE_GC != 0
                WASMRefType *ref_type;
                uint32 type_idx1;
                int32 j;
#endif

#if WASM_ENABLE_GC != 0
                if (opcode == WASM_OP_CALL_REF
                    || opcode == WASM_OP_RETURN_CALL_REF) {
                    pb_read_leb_uint32(p, p_end, type_idx1);
                    if (!check_type_index(module, module->type_count, type_idx1,
                                          error_buf, error_buf_size)) {
                        goto fail;
                    }
                    if (module->types[type_idx1] == NULL
                        || module->types[type_idx1]->type_flag
                               != WASM_TYPE_FUNC) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown function type");
                        goto fail;
                    }
                    if (!wasm_loader_pop_nullable_typeidx(loader_ctx, &type,
                                                          &type_idx, error_buf,
                                                          error_buf_size)) {
                        goto fail;
                    }
                    if (type == VALUE_TYPE_ANY) {
                        type_idx = type_idx1;
                    }
                    if (!check_type_index(module, module->type_count, type_idx,
                                          error_buf, error_buf_size)) {
                        goto fail;
                    }
                    if (module->types[type_idx] == NULL
                        || module->types[type_idx]->type_flag
                               != WASM_TYPE_FUNC) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown function type");
                        goto fail;
                    }
                    if (!wasm_func_type_is_super_of(
                            (WASMFuncType *)module->types[type_idx1],
                            (WASMFuncType *)module->types[type_idx])) {
                        set_error_buf(error_buf, error_buf_size,
                                      "function type mismatch");
                        goto fail;
                    }
                    func_type = (WASMFuncType *)module->types[type_idx];
                }
                else
#endif
                {
                    pb_read_leb_uint32(p, p_end, func_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                    /* we need to emit func_idx before arguments */
                    emit_uint32(loader_ctx, func_idx);
#endif

                    if (!check_function_index(module, func_idx, error_buf,
                                              error_buf_size)) {
                        goto fail;
                    }

                    if (func_idx < module->import_function_count)
                        func_type = module->import_functions[func_idx]
                                        .u.function.func_type;
                    else
                        func_type =
                            module
                                ->functions[func_idx
                                            - module->import_function_count]
                                ->func_type;
                }

                if (func_type->param_count > 0) {
#if WASM_ENABLE_GC != 0
                    j = (int32)(func_type->result_ref_type_maps
                                - func_type->ref_type_maps - 1);
#endif
                    for (idx = (int32)(func_type->param_count - 1); idx >= 0;
                         idx--) {
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_multi_byte_type(
                                func_type->types[idx])) {
                            ref_type = func_type->ref_type_maps[j].ref_type;
                            bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                        ref_type,
                                        wasm_reftype_struct_size(ref_type));
                            j--;
                        }
#endif
#if WASM_ENABLE_FAST_INTERP != 0
                        POP_OFFSET_TYPE(func_type->types[idx]);
#endif
                        POP_TYPE(func_type->types[idx]);
                    }
                }

#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
                if (opcode == WASM_OP_CALL || opcode == WASM_OP_CALL_REF) {
#endif
#if WASM_ENABLE_GC != 0
                    j = (int32)(func_type->result_ref_type_maps
                                - func_type->ref_type_maps);
#endif
                    for (i = 0; i < func_type->result_count; i++) {
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_multi_byte_type(
                                func_type->types[func_type->param_count + i])) {
                            ref_type = func_type->ref_type_maps[j].ref_type;
                            bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                        ref_type,
                                        wasm_reftype_struct_size(ref_type));
                            j++;
                        }
#endif
                        PUSH_TYPE(func_type->types[func_type->param_count + i]);
#if WASM_ENABLE_FAST_INTERP != 0
                        /* Here we emit each return value's dynamic_offset. But
                         * in fact these offsets are continuous, so interpreter
                         * only need to get the first return value's offset.
                         */
                        PUSH_OFFSET_TYPE(
                            func_type->types[func_type->param_count + i]);
#endif
                    }
#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
                }
                else {
#if WASM_ENABLE_GC == 0
                    if (func_type->result_count
                        != func->func_type->result_count) {
                        set_error_buf_v(error_buf, error_buf_size, "%s%u%s",
                                        "type mismatch: expect ",
                                        func->func_type->result_count,
                                        " return values but got other");
                        goto fail;
                    }
                    for (i = 0; i < func_type->result_count; i++) {
                        type = func->func_type
                                   ->types[func->func_type->param_count + i];
                        if (func_type->types[func_type->param_count + i]
                            != type) {
                            set_error_buf_v(error_buf, error_buf_size, "%s%s%s",
                                            "type mismatch: expect ",
                                            type2str(type), " but got other");
                            goto fail;
                        }
                    }
#else
                    if (!wasm_func_type_result_is_subtype_of(
                            func_type, func->func_type, module->types,
                            module->type_count)) {
                        set_error_buf(
                            error_buf, error_buf_size,
                            "type mismatch: invalid func result types");
                        goto fail;
                    }
#endif
                    RESET_STACK();
                    SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                }
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_op_func_call = true;
#endif
                (void)type;
                break;
            }

            /*
             * if disable reference type: call_indirect typeidx, 0x00
             * if enable reference type:  call_indirect typeidx, tableidx
             */
            case WASM_OP_CALL_INDIRECT:
#if WASM_ENABLE_TAIL_CALL != 0
            case WASM_OP_RETURN_CALL_INDIRECT:
#endif
            {
                int32 idx;
                WASMFuncType *func_type;
                uint32 tbl_elem_type;
#if WASM_ENABLE_GC != 0
                WASMRefType *elem_ref_type = NULL;
#endif

                pb_read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
#if WASM_ENABLE_WAMR_COMPILER != 0
                if (p + 1 < p_end && *p != 0x00) {
                    /*
                     * Any non-0x00 byte requires the ref types proposal.
                     * This is different from checking the table_idx value
                     * since `0x80 0x00` etc. are all valid encodings of zero.
                     */
                    module->is_ref_types_used = true;
                }
#endif
                pb_read_leb_uint32(p, p_end, table_idx);
#else
                CHECK_BUF(p, p_end, 1);
                table_idx = read_uint8(p);
#endif
                if (!check_table_index(module, table_idx, error_buf,
                                       error_buf_size)) {
                    goto fail;
                }
                tbl_elem_type =
                    table_idx < module->import_table_count
                        ? module->import_tables[table_idx]
                              .u.table.table_type.elem_type
                        : module->tables[table_idx - module->import_table_count]
                              .table_type.elem_type;

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
                if (tbl_elem_type != VALUE_TYPE_FUNCREF) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "type mismatch: instruction requires table "
                                    "of functions but table %u has externref",
                                    table_idx);
                    goto fail;
                }
#elif WASM_ENABLE_GC != 0
                /* Table element must match type ref null func */
                elem_ref_type =
                    table_idx < module->import_table_count
                        ? module->import_tables[table_idx]
                              .u.table.table_type.elem_ref_type
                        : module->tables[table_idx - module->import_table_count]
                              .table_type.elem_ref_type;

                if (!wasm_reftype_is_subtype_of(
                        tbl_elem_type, elem_ref_type, REF_TYPE_FUNCREF, NULL,
                        module->types, module->type_count)) {
                    set_error_buf_v(error_buf, error_buf_size,
                                    "type mismatch: instruction requires "
                                    "reference type t match type ref null func"
                                    "in table %u",
                                    table_idx);
                    goto fail;
                }
#else
                (void)tbl_elem_type;
#endif

#if WASM_ENABLE_FAST_INTERP != 0
                /* we need to emit before arguments */
#if WASM_ENABLE_TAIL_CALL != 0
                emit_byte(loader_ctx, opcode);
#endif
                emit_uint32(loader_ctx, type_idx);
                emit_uint32(loader_ctx, table_idx);
#endif

#if WASM_ENABLE_MEMORY64 != 0
                table_elem_idx_type = is_table_64bit(module, table_idx)
                                          ? VALUE_TYPE_I64
                                          : VALUE_TYPE_I32;
#endif
                /* skip elem idx */
                POP_TBL_ELEM_IDX();

                if (!check_function_type(module, type_idx, error_buf,
                                         error_buf_size)) {
                    goto fail;
                }

                func_type = (WASMFuncType *)module->types[type_idx];

                if (func_type->param_count > 0) {
                    for (idx = (int32)(func_type->param_count - 1); idx >= 0;
                         idx--) {
#if WASM_ENABLE_FAST_INTERP != 0
                        POP_OFFSET_TYPE(func_type->types[idx]);
#endif
                        POP_TYPE(func_type->types[idx]);
                    }
                }

#if WASM_ENABLE_TAIL_CALL != 0
                if (opcode == WASM_OP_CALL_INDIRECT) {
#endif
                    for (i = 0; i < func_type->result_count; i++) {
                        PUSH_TYPE(func_type->types[func_type->param_count + i]);
#if WASM_ENABLE_FAST_INTERP != 0
                        PUSH_OFFSET_TYPE(
                            func_type->types[func_type->param_count + i]);
#endif
                    }
#if WASM_ENABLE_TAIL_CALL != 0
                }
                else {
                    uint8 type;
                    if (func_type->result_count
                        != func->func_type->result_count) {
                        set_error_buf_v(error_buf, error_buf_size, "%s%u%s",
                                        "type mismatch: expect ",
                                        func->func_type->result_count,
                                        " return values but got other");
                        goto fail;
                    }
                    for (i = 0; i < func_type->result_count; i++) {
                        type = func->func_type
                                   ->types[func->func_type->param_count + i];
                        if (func_type->types[func_type->param_count + i]
                            != type) {
                            set_error_buf_v(error_buf, error_buf_size, "%s%s%s",
                                            "type mismatch: expect ",
                                            type2str(type), " but got other");
                            goto fail;
                        }
                    }
                    RESET_STACK();
                    SET_CUR_BLOCK_STACK_POLYMORPHIC_STATE(true);
                }
#endif
#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_op_func_call = true;
#endif
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_op_call_indirect = true;
#endif
                break;
            }

            case WASM_OP_DROP:
            {
                BranchBlock *cur_block = loader_ctx->frame_csp - 1;
                int32 available_stack_cell =
                    (int32)(loader_ctx->stack_cell_num
                            - cur_block->stack_cell_num);

                if (available_stack_cell <= 0
                    && !cur_block->is_stack_polymorphic) {
                    set_error_buf(error_buf, error_buf_size,
                                  "type mismatch, opcode drop was found "
                                  "but stack was empty");
                    goto fail;
                }

                if (available_stack_cell > 0) {
#if WASM_ENABLE_GC != 0
                    if (wasm_is_type_multi_byte_type(
                            *(loader_ctx->frame_ref - 1))) {
                        bh_assert((int32)(loader_ctx->reftype_map_num
                                          - cur_block->reftype_map_num)
                                  > 0);
                        loader_ctx->frame_reftype_map--;
                        loader_ctx->reftype_map_num--;
                    }
#endif
                    if (is_32bit_type(*(loader_ctx->frame_ref - 1))) {
                        loader_ctx->frame_ref--;
                        loader_ctx->stack_cell_num--;
#if WASM_ENABLE_FAST_INTERP != 0
                        skip_label();
                        loader_ctx->frame_offset--;
                        if ((*(loader_ctx->frame_offset)
                             > loader_ctx->start_dynamic_offset)
                            && (*(loader_ctx->frame_offset)
                                < loader_ctx->max_dynamic_offset))
                            loader_ctx->dynamic_offset--;
#endif
                    }
                    else if (is_64bit_type(*(loader_ctx->frame_ref - 1))) {
                        loader_ctx->frame_ref -= 2;
                        loader_ctx->stack_cell_num -= 2;
#if WASM_ENABLE_FAST_INTERP == 0
                        *(p - 1) = WASM_OP_DROP_64;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
                        skip_label();
                        loader_ctx->frame_offset -= 2;
                        if ((*(loader_ctx->frame_offset)
                             > loader_ctx->start_dynamic_offset)
                            && (*(loader_ctx->frame_offset)
                                < loader_ctx->max_dynamic_offset))
                            loader_ctx->dynamic_offset -= 2;
#endif
                    }
#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
                    else if (*(loader_ctx->frame_ref - 1) == VALUE_TYPE_V128) {
                        loader_ctx->frame_ref -= 4;
                        loader_ctx->stack_cell_num -= 4;
#if WASM_ENABLE_FAST_INTERP != 0
                        skip_label();
                        loader_ctx->frame_offset -= 4;
                        if ((*(loader_ctx->frame_offset)
                             > loader_ctx->start_dynamic_offset)
                            && (*(loader_ctx->frame_offset)
                                < loader_ctx->max_dynamic_offset))
                            loader_ctx->dynamic_offset -= 4;
#endif
                    }
#endif
#endif
                    else {
                        set_error_buf(error_buf, error_buf_size,
                                      "type mismatch");
                        goto fail;
                    }
                }
                else {
#if WASM_ENABLE_FAST_INTERP != 0
                    skip_label();
#endif
                }
                break;
            }

            case WASM_OP_SELECT:
            {
                uint8 ref_type;
                BranchBlock *cur_block = loader_ctx->frame_csp - 1;
                int32 available_stack_cell;
#if WASM_ENABLE_FAST_INTERP != 0
                uint8 *p_code_compiled_tmp = loader_ctx->p_code_compiled;
#endif

                POP_I32();

                available_stack_cell = (int32)(loader_ctx->stack_cell_num
                                               - cur_block->stack_cell_num);

                if (available_stack_cell <= 0
                    && !cur_block->is_stack_polymorphic) {
                    set_error_buf(error_buf, error_buf_size,
                                  "type mismatch or invalid result arity, "
                                  "opcode select was found "
                                  "but stack was empty");
                    goto fail;
                }

                if (available_stack_cell > 0) {
                    switch (*(loader_ctx->frame_ref - 1)) {
                        case VALUE_TYPE_I32:
                        case VALUE_TYPE_F32:
                        case VALUE_TYPE_ANY:
                            break;
                        case VALUE_TYPE_I64:
                        case VALUE_TYPE_F64:
#if WASM_ENABLE_FAST_INTERP == 0
                            *(p - 1) = WASM_OP_SELECT_64;
#else
                            if (loader_ctx->p_code_compiled) {
                                uint8 opcode_tmp = WASM_OP_SELECT_64;
#if WASM_ENABLE_LABELS_AS_VALUES != 0
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                                *(void **)(p_code_compiled_tmp
                                           - sizeof(void *)) =
                                    handle_table[opcode_tmp];
#elif UINTPTR_MAX == UINT64_MAX
                                /* emit int32 relative offset in 64-bit target
                                 */
                                int32 offset =
                                    (int32)((uint8 *)handle_table[opcode_tmp]
                                            - (uint8 *)handle_table[0]);
                                *(int32 *)(p_code_compiled_tmp
                                           - sizeof(int32)) = offset;
#else
                                /* emit uint32 label address in 32-bit target */
                                *(uint32 *)(p_code_compiled_tmp
                                            - sizeof(uint32)) =
                                    (uint32)(uintptr_t)handle_table[opcode_tmp];
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#else  /* else of WASM_ENABLE_LABELS_AS_VALUES */
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                                *(p_code_compiled_tmp - 1) = opcode_tmp;
#else
                                *(p_code_compiled_tmp - 2) = opcode_tmp;
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#endif /* end of WASM_ENABLE_LABELS_AS_VALUES */
                            }
#endif /* end of WASM_ENABLE_FAST_INTERP */
                            break;
#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
                        case VALUE_TYPE_V128:
#if WASM_ENABLE_SIMDE != 0
                            if (loader_ctx->p_code_compiled) {
                                uint8 opcode_tmp = WASM_OP_SELECT_128;
#if WASM_ENABLE_LABELS_AS_VALUES != 0
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                                *(void **)(p_code_compiled_tmp
                                           - sizeof(void *)) =
                                    handle_table[opcode_tmp];
#elif UINTPTR_MAX == UINT64_MAX
                                /* emit int32 relative offset in 64-bit target
                                 */
                                int32 offset =
                                    (int32)((uint8 *)handle_table[opcode_tmp]
                                            - (uint8 *)handle_table[0]);
                                *(int32 *)(p_code_compiled_tmp
                                           - sizeof(int32)) = offset;
#else
                                /* emit uint32 label address in 32-bit target */
                                *(uint32 *)(p_code_compiled_tmp
                                            - sizeof(uint32)) =
                                    (uint32)(uintptr_t)handle_table[opcode_tmp];
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#else  /* else of WASM_ENABLE_LABELS_AS_VALUES */
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                                *(p_code_compiled_tmp - 1) = opcode_tmp;
#else
                                *(p_code_compiled_tmp - 2) = opcode_tmp;
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#endif /* end of WASM_ENABLE_LABELS_AS_VALUES */
                            }
#endif /* end of WASM_ENABLE_FAST_INTERP */
                            break;
#endif /* (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) || \
          (WASM_ENABLE_FAST_INTERP != 0) */
#endif /* WASM_ENABLE_SIMD != 0 */
                        default:
                        {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }
                    }

                    ref_type = *(loader_ctx->frame_ref - 1);
#if WASM_ENABLE_FAST_INTERP != 0
                    POP_OFFSET_TYPE(ref_type);
                    POP_TYPE(ref_type);
                    POP_OFFSET_TYPE(ref_type);
                    POP_TYPE(ref_type);
                    PUSH_OFFSET_TYPE(ref_type);
                    PUSH_TYPE(ref_type);
#else
                    POP2_AND_PUSH(ref_type, ref_type);
#endif
                }
                else {
#if WASM_ENABLE_FAST_INTERP != 0
                    PUSH_OFFSET_TYPE(VALUE_TYPE_ANY);
#endif
                    PUSH_TYPE(VALUE_TYPE_ANY);
                }
                break;
            }

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            case WASM_OP_SELECT_T:
            {
                uint8 vec_len, type;
#if WASM_ENABLE_GC != 0
                WASMRefType *ref_type = NULL;
#endif
#if WASM_ENABLE_FAST_INTERP != 0
                uint8 *p_code_compiled_tmp = loader_ctx->p_code_compiled;
#endif

                pb_read_leb_uint32(p, p_end, vec_len);
                if (vec_len != 1) {
                    /* typed select must have exactly one result */
                    set_error_buf(error_buf, error_buf_size,
                                  "invalid result arity");
                    goto fail;
                }

#if WASM_ENABLE_GC == 0
                CHECK_BUF(p, p_end, 1);
                type = read_uint8(p);
                if (!is_valid_value_type_for_interpreter(type)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "unknown value type");
                    goto fail;
                }
#else
                p_org = p + 1;
                if (!resolve_value_type((const uint8 **)&p, p_end, module,
                                        module->type_count, &need_ref_type_map,
                                        &wasm_ref_type, false, error_buf,
                                        error_buf_size)) {
                    goto fail;
                }
                type = wasm_ref_type.ref_type;
                if (need_ref_type_map) {
                    if (!(ref_type = reftype_set_insert(
                              module->ref_type_set, &wasm_ref_type, error_buf,
                              error_buf_size))) {
                        goto fail;
                    }
                }
#if WASM_ENABLE_FAST_INTERP == 0
                while (p_org < p) {
#if WASM_ENABLE_DEBUG_INTERP != 0
                    if (!record_fast_op(module, p_org, *p_org, error_buf,
                                        error_buf_size)) {
                        goto fail;
                    }
#endif
                    /* Ignore extra bytes for interpreter */
                    *p_org++ = WASM_OP_NOP;
                }
#endif
#endif /* end of WASM_ENABLE_GC == 0 */

                POP_I32();

#if WASM_ENABLE_FAST_INTERP != 0
                if (loader_ctx->p_code_compiled) {
                    uint8 opcode_tmp = WASM_OP_SELECT;

                    if (type == VALUE_TYPE_V128) {
#if WASM_ENABLE_SIMDE != 0
                        opcode_tmp = WASM_OP_SELECT_128;
#else
                        set_error_buf(error_buf, error_buf_size,
                                      "v128 value type requires simd feature");
#endif
                    }
                    else {
                        if (type == VALUE_TYPE_F64 || type == VALUE_TYPE_I64)
                            opcode_tmp = WASM_OP_SELECT_64;
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_reftype(type))
                            opcode_tmp = WASM_OP_SELECT_T;
#endif
#if WASM_ENABLE_LABELS_AS_VALUES != 0
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                        *(void **)(p_code_compiled_tmp - sizeof(void *)) =
                            handle_table[opcode_tmp];
#else
#if UINTPTR_MAX == UINT64_MAX
                        /* emit int32 relative offset in 64-bit target */
                        int32 offset = (int32)((uint8 *)handle_table[opcode_tmp]
                                               - (uint8 *)handle_table[0]);
                        *(int32 *)(p_code_compiled_tmp - sizeof(int32)) =
                            offset;
#else
                        /* emit uint32 label address in 32-bit target */
                        *(uint32 *)(p_code_compiled_tmp - sizeof(uint32)) =
                            (uint32)(uintptr_t)handle_table[opcode_tmp];
#endif
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#else  /* else of WASM_ENABLE_LABELS_AS_VALUES */
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                        *(p_code_compiled_tmp - 1) = opcode_tmp;
#else
                        *(p_code_compiled_tmp - 2) = opcode_tmp;
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#endif /* end of WASM_ENABLE_LABELS_AS_VALUES */
                    }
                }
#endif /* WASM_ENABLE_FAST_INTERP != 0 */

                POP_REF(type);

#if WASM_ENABLE_GC != 0
                if (need_ref_type_map) {
                    bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType), ref_type,
                                wasm_reftype_struct_size(ref_type));
                }
#endif
                POP_REF(type);

#if WASM_ENABLE_GC != 0
                if (need_ref_type_map) {
                    bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType), ref_type,
                                wasm_reftype_struct_size(ref_type));
                }
#endif
                PUSH_REF(type);

#if WASM_ENABLE_WAMR_COMPILER != 0
                module->is_ref_types_used = true;
#endif
                (void)vec_len;
                break;
            }

            /* table.get x. tables[x]. [it] -> [t] */
            /* table.set x. tables[x]. [it t] -> [] */
            case WASM_OP_TABLE_GET:
            case WASM_OP_TABLE_SET:
            {
                uint8 decl_ref_type;
#if WASM_ENABLE_GC != 0
                WASMRefType *ref_type;
#endif

                pb_read_leb_uint32(p, p_end, table_idx);
                if (!get_table_elem_type(module, table_idx, &decl_ref_type,
#if WASM_ENABLE_GC != 0
                                         (void **)&ref_type,
#else
                                         NULL,
#endif
                                         error_buf, error_buf_size))
                    goto fail;

#if WASM_ENABLE_GC != 0
                if (wasm_is_type_multi_byte_type(decl_ref_type)) {
                    bh_assert(ref_type);
                    bh_memcpy_s(&wasm_ref_type, (uint32)sizeof(WASMRefType),
                                ref_type, wasm_reftype_struct_size(ref_type));
                }
#endif

#if WASM_ENABLE_FAST_INTERP != 0
                emit_uint32(loader_ctx, table_idx);
#endif

#if WASM_ENABLE_MEMORY64 != 0
                table_elem_idx_type = is_table_64bit(module, table_idx)
                                          ? VALUE_TYPE_I64
                                          : VALUE_TYPE_I32;
#endif
                if (opcode == WASM_OP_TABLE_GET) {
                    POP_TBL_ELEM_IDX();
#if WASM_ENABLE_FAST_INTERP != 0
                    PUSH_OFFSET_TYPE(decl_ref_type);
#endif
                    PUSH_TYPE(decl_ref_type);
                }
                else {
#if WASM_ENABLE_FAST_INTERP != 0
                    POP_OFFSET_TYPE(decl_ref_type);
#endif
                    POP_TYPE(decl_ref_type);
                    POP_TBL_ELEM_IDX();
                }

#if WASM_ENABLE_WAMR_COMPILER != 0
                module->is_ref_types_used = true;
#endif
                break;
            }
            case WASM_OP_REF_NULL:
            {
                uint8 ref_type;

#if WASM_ENABLE_GC == 0
                CHECK_BUF(p, p_end, 1);
                ref_type = read_uint8(p);

                if (ref_type != VALUE_TYPE_FUNCREF
                    && ref_type != VALUE_TYPE_EXTERNREF) {
                    set_error_buf(error_buf, error_buf_size, "type mismatch");
                    goto fail;
                }
#else
                pb_read_leb_int32(p, p_end, heap_type);
                if (heap_type >= 0) {
                    if (!check_type_index(module, module->type_count, heap_type,
                                          error_buf, error_buf_size)) {
                        goto fail;
                    }
                    wasm_set_refheaptype_typeidx(&wasm_ref_type.ref_ht_typeidx,
                                                 true, heap_type);
                    ref_type = wasm_ref_type.ref_type;
                }
                else {
                    if (!wasm_is_valid_heap_type(heap_type)) {
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown type");
                        goto fail;
                    }
                    ref_type = (uint8)((int32)0x80 + heap_type);
                }
#endif /* end of WASM_ENABLE_GC == 0 */

#if WASM_ENABLE_FAST_INTERP != 0
                PUSH_OFFSET_TYPE(ref_type);
#endif
                PUSH_TYPE(ref_type);

#if WASM_ENABLE_WAMR_COMPILER != 0
                module->is_ref_types_used = true;
#endif
                break;
            }
            case WASM_OP_REF_IS_NULL:
            {
#if WASM_ENABLE_GC == 0
#if WASM_ENABLE_FAST_INTERP != 0
                BranchBlock *cur_block = loader_ctx->frame_csp - 1;
                int32 block_stack_cell_num =
                    (int32)(loader_ctx->stack_cell_num
                            - cur_block->stack_cell_num);
                if (block_stack_cell_num <= 0) {
                    if (!cur_block->is_stack_polymorphic) {
                        set_error_buf(
                            error_buf, error_buf_size,
                            "type mismatch: expect data but stack was empty");
                        goto fail;
                    }
                }
                else {
                    if (*(loader_ctx->frame_ref - 1) == VALUE_TYPE_FUNCREF
                        || *(loader_ctx->frame_ref - 1) == VALUE_TYPE_EXTERNREF
                        || *(loader_ctx->frame_ref - 1) == VALUE_TYPE_ANY) {
                        if (!wasm_loader_pop_frame_ref_offset(
                                loader_ctx, *(loader_ctx->frame_ref - 1),
                                error_buf, error_buf_size)) {
                            goto fail;
                        }
                    }
                    else {
                        set_error_buf(error_buf, error_buf_size,
                                      "type mismatch");
                        goto fail;
                    }
                }
#else
                if (!wasm_loader_pop_frame_ref(loader_ctx, VALUE_TYPE_FUNCREF,
                                               error_buf, error_buf_size)
                    && !wasm_loader_pop_frame_ref(loader_ctx,
                                                  VALUE_TYPE_EXTERNREF,
                                                  error_buf, error_buf_size)) {
                    goto fail;
                }
#endif
#else /* else of WASM_ENABLE_GC == 0 */
                uint8 type;
                if (!wasm_loader_pop_heap_obj(loader_ctx, &type, &wasm_ref_type,
                                              error_buf, error_buf_size)) {
                    goto fail;
                }
#endif
                PUSH_I32();

#if WASM_ENABLE_WAMR_COMPILER != 0
                module->is_ref_types_used = true;
#endif
                break;
            }
            case WASM_OP_REF_FUNC:
            {
                pb_read_leb_uint32(p, p_end, func_idx);

                if (!check_function_index(module, func_idx, error_buf,
                                          error_buf_size)) {
                    goto fail;
                }

                /* Refer to a forward-declared function:
                   the function must be an import, exported, or present in
                   a table elem segment or global initializer to be used as
                   the operand to ref.func */
                if (func_idx >= module->import_function_count) {
                    WASMTableSeg *table_seg = module->table_segments;
                    bool func_declared = false;
                    uint32 j;

                    for (i = 0; i < module->global_count; i++) {
                        if (module->globals[i].type.val_type
                                == VALUE_TYPE_FUNCREF
                            && module->globals[i].init_expr.init_expr_type
                                   == INIT_EXPR_TYPE_FUNCREF_CONST
                            && module->globals[i].init_expr.u.unary.v.u32
                                   == func_idx) {
                            func_declared = true;
                            break;
                        }
                    }

                    if (!func_declared) {
                        /* Check whether the function is declared in table segs,
                           note that it doesn't matter whether the table seg's
                           mode is passive, active or declarative. */
                        for (i = 0; i < module->table_seg_count;
                             i++, table_seg++) {
                            if (table_seg->elem_type == VALUE_TYPE_FUNCREF
#if WASM_ENABLE_GC != 0
                                /* elem type is (ref null? func) or
                                   (ref null? $t) */
                                || ((table_seg->elem_type
                                         == REF_TYPE_HT_NON_NULLABLE
                                     || table_seg->elem_type
                                            == REF_TYPE_HT_NULLABLE)
                                    && (table_seg->elem_ref_type->ref_ht_common
                                                .heap_type
                                            == HEAP_TYPE_FUNC
                                        || table_seg->elem_ref_type
                                                   ->ref_ht_common.heap_type
                                               > 0))
#endif
                            ) {
                                for (j = 0; j < table_seg->value_count; j++) {
                                    if (table_seg->init_values[j]
                                            .u.unary.v.ref_index
                                        == func_idx) {
                                        func_declared = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }

                    if (!func_declared) {
                        /* Check whether the function is exported */
                        for (i = 0; i < module->export_count; i++) {
                            if (module->exports[i].kind == EXPORT_KIND_FUNC
                                && module->exports[i].index == func_idx) {
                                func_declared = true;
                                break;
                            }
                        }
                    }

                    if (!func_declared) {
                        set_error_buf(error_buf, error_buf_size,
                                      "undeclared function reference");
                        goto fail;
                    }
                }

#if WASM_ENABLE_FAST_INTERP != 0
                emit_uint32(loader_ctx, func_idx);
#endif
#if WASM_ENABLE_GC == 0
                PUSH_FUNCREF();
#else
                if (func_idx < module->import_function_count)
                    type_idx =
                        module->import_functions[func_idx].u.function.type_idx;
                else
                    type_idx = module
                                   ->functions[func_idx
                                               - module->import_function_count]
                                   ->type_idx;
                wasm_set_refheaptype_typeidx(&wasm_ref_type.ref_ht_typeidx,
                                             false, type_idx);
                PUSH_REF(wasm_ref_type.ref_type);
#endif

#if WASM_ENABLE_WAMR_COMPILER != 0
                module->is_ref_types_used = true;
#endif
                break;
            }
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

#if WASM_ENABLE_GC != 0
            case WASM_OP_REF_AS_NON_NULL:
            case WASM_OP_BR_ON_NULL:
            {
                uint8 type;
                WASMRefType ref_type;

                /* POP (ref null ht) and get the converted (ref ht) */
                if (!wasm_loader_pop_nullable_ht(loader_ctx, &type, &ref_type,
                                                 error_buf, error_buf_size)) {
                    goto fail;
                }

                if (opcode == WASM_OP_BR_ON_NULL) {
                    if (!(frame_csp_tmp =
                              check_branch_block(loader_ctx, &p, p_end, opcode,
                                                 error_buf, error_buf_size))) {
                        goto fail;
                    }
#if WASM_ENABLE_FAST_INTERP != 0
                    disable_emit = true;
#endif
                }

                /* PUSH the converted (ref ht) */
                if (type != VALUE_TYPE_ANY) {
                    bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType), &ref_type,
                                sizeof(WASMRefType));
                }
                PUSH_REF(type);
                break;
            }

            case WASM_OP_BR_ON_NON_NULL:
            {
                uint8 type;
                WASMRefType ref_type;
                uint32 available_stack_cell =
                    loader_ctx->stack_cell_num
                    - (loader_ctx->frame_csp - 1)->stack_cell_num;

                /* POP (ref null ht) and get the converted (ref ht) */
                if (!wasm_loader_pop_nullable_ht(loader_ctx, &type, &ref_type,
                                                 error_buf, error_buf_size)) {
                    goto fail;
                }

#if WASM_ENABLE_FAST_INTERP != 0
                disable_emit = true;
#endif

                /* Temporarily PUSH back (ref ht), check brach block and
                   then POP it */
                if (available_stack_cell
                    > 0) { /* stack isn't in polymorphic state */
                    if (type != VALUE_TYPE_ANY) {
                        bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                    &ref_type, sizeof(WASMRefType));
                    }
                    PUSH_REF(type);
                }
                if (!(frame_csp_tmp =
                          check_branch_block(loader_ctx, &p, p_end, opcode,
                                             error_buf, error_buf_size))) {
                    goto fail;
                }
                if (available_stack_cell
                    > 0) { /* stack isn't in polymorphic state */
                    POP_REF(type);
#if WASM_ENABLE_FAST_INTERP != 0
                    /* Erase the opnd offset emitted by POP_REF() */
                    wasm_loader_emit_backspace(loader_ctx, sizeof(uint16));
#endif
                }
                break;
            }

            case WASM_OP_REF_EQ:
                POP_REF(REF_TYPE_EQREF);
                POP_REF(REF_TYPE_EQREF);
                PUSH_I32();
                break;
#endif /* end of WASM_ENABLE_GC != 0 */

            case WASM_OP_GET_LOCAL:
            {
                p_org = p - 1;
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();
                PUSH_TYPE(local_type);

#if WASM_ENABLE_GC != 0
                /* Cannot get a non-nullable and unset local */
                if (local_idx >= param_count
                    && wasm_is_reftype_htref_non_nullable(local_type)
                    && !wasm_loader_get_local_status(loader_ctx,
                                                     local_idx - param_count)) {
                    set_error_buf(error_buf, error_buf_size,
                                  "uninitialized local");
                    goto fail;
                }
#endif

#if WASM_ENABLE_FAST_INTERP != 0
                /* Get Local is optimized out */
                skip_label();
                disable_emit = true;
                operand_offset = local_offset;
                PUSH_OFFSET_TYPE(local_type);
#else
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0) \
    && (WASM_ENABLE_FAST_JIT == 0) && (WASM_ENABLE_DEBUG_INTERP == 0)
                if (local_offset < 0x80
#if WASM_ENABLE_GC != 0
                    && !wasm_is_type_reftype(local_type)
#endif
                ) {
                    *p_org++ = EXT_OP_GET_LOCAL_FAST;
                    if (is_32bit_type(local_type)) {
                        *p_org++ = (uint8)local_offset;
                    }
                    else {
                        *p_org++ = (uint8)(local_offset | 0x80);
                    }
                    while (p_org < p) {
                        *p_org++ = WASM_OP_NOP;
                    }
                }
#endif
#endif /* end of WASM_ENABLE_FAST_INTERP != 0 */
                break;
            }

            case WASM_OP_SET_LOCAL:
            {
                p_org = p - 1;
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();

#if WASM_ENABLE_FAST_INTERP != 0
                if (!(preserve_referenced_local(
                        loader_ctx, opcode, local_offset, local_type,
                        &preserve_local, error_buf, error_buf_size)))
                    goto fail;

                if (local_offset < 256
#if WASM_ENABLE_GC != 0
                    && !wasm_is_type_reftype(local_type)
#endif
                ) {
                    skip_label();
                    if ((!preserve_local) && (LAST_OP_OUTPUT_I32())) {
                        if (loader_ctx->p_code_compiled)
                            STORE_U16(loader_ctx->p_code_compiled - 2,
                                      local_offset);
                        loader_ctx->frame_offset--;
                        loader_ctx->dynamic_offset--;
                    }
                    else if ((!preserve_local) && (LAST_OP_OUTPUT_I64())) {
                        if (loader_ctx->p_code_compiled)
                            STORE_U16(loader_ctx->p_code_compiled - 2,
                                      local_offset);
                        loader_ctx->frame_offset -= 2;
                        loader_ctx->dynamic_offset -= 2;
                    }
                    else {
                        if (is_32bit_type(local_type)) {
                            emit_label(EXT_OP_SET_LOCAL_FAST);
                            emit_byte(loader_ctx, (uint8)local_offset);
                        }
                        else if (is_64bit_type(local_type)) {
                            emit_label(EXT_OP_SET_LOCAL_FAST_I64);
                            emit_byte(loader_ctx, (uint8)local_offset);
                        }
#if WASM_ENABLE_SIMDE != 0
                        else if (local_type == VALUE_TYPE_V128) {
                            emit_label(EXT_OP_SET_LOCAL_FAST_V128);
                            emit_byte(loader_ctx, (uint8)local_offset);
                        }
#endif
                        else {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown local type");
                            goto fail;
                        }
                        POP_OFFSET_TYPE(local_type);
                    }
                }
                else { /* local index larger than 255, reserve leb */
                    emit_uint32(loader_ctx, local_idx);
                    POP_OFFSET_TYPE(local_type);
                }
#else
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0) \
    && (WASM_ENABLE_FAST_JIT == 0) && (WASM_ENABLE_DEBUG_INTERP == 0)
                if (local_offset < 0x80
#if WASM_ENABLE_GC != 0
                    && !wasm_is_type_reftype(local_type)
#endif
                ) {
                    *p_org++ = EXT_OP_SET_LOCAL_FAST;
                    if (is_32bit_type(local_type)) {
                        *p_org++ = (uint8)local_offset;
                    }
                    else {
                        *p_org++ = (uint8)(local_offset | 0x80);
                    }
                    while (p_org < p) {
                        *p_org++ = WASM_OP_NOP;
                    }
                }
#endif
#endif /* end of WASM_ENABLE_FAST_INTERP != 0 */

#if WASM_ENABLE_GC != 0
                if (local_idx >= param_count) {
                    wasm_loader_mask_local(loader_ctx, local_idx - param_count);
                }
#endif

                POP_TYPE(local_type);
                break;
            }

            case WASM_OP_TEE_LOCAL:
            {
                p_org = p - 1;
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();
#if WASM_ENABLE_FAST_INTERP != 0
                /* If the stack is in polymorphic state, do fake pop and push on
                    offset stack to keep the depth of offset stack to be the
                   same with ref stack */
                BranchBlock *cur_block = loader_ctx->frame_csp - 1;
                if (cur_block->is_stack_polymorphic) {
                    POP_OFFSET_TYPE(local_type);
                    PUSH_OFFSET_TYPE(local_type);
                }
#endif
                POP_TYPE(local_type);
                PUSH_TYPE(local_type);

#if WASM_ENABLE_FAST_INTERP != 0
                if (!(preserve_referenced_local(
                        loader_ctx, opcode, local_offset, local_type,
                        &preserve_local, error_buf, error_buf_size)))
                    goto fail;

                if (local_offset < 256
#if WASM_ENABLE_GC != 0
                    && !wasm_is_type_reftype(local_type)
#endif
                ) {
                    skip_label();
                    if (is_32bit_type(local_type)) {
                        emit_label(EXT_OP_TEE_LOCAL_FAST);
                        emit_byte(loader_ctx, (uint8)local_offset);
                    }
#if WASM_ENABLE_SIMDE != 0
                    else if (local_type == VALUE_TYPE_V128) {
                        emit_label(EXT_OP_TEE_LOCAL_FAST_V128);
                        emit_byte(loader_ctx, (uint8)local_offset);
                    }
#endif
                    else {
                        emit_label(EXT_OP_TEE_LOCAL_FAST_I64);
                        emit_byte(loader_ctx, (uint8)local_offset);
                    }
                }
                else { /* local index larger than 255, reserve leb */
                    emit_uint32(loader_ctx, local_idx);
                }
                emit_operand(loader_ctx,
                             *(loader_ctx->frame_offset
                               - wasm_value_type_cell_num(local_type)));
#else
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0) \
    && (WASM_ENABLE_FAST_JIT == 0) && (WASM_ENABLE_DEBUG_INTERP == 0)
                if (local_offset < 0x80
#if WASM_ENABLE_GC != 0
                    && !wasm_is_type_reftype(local_type)
#endif
                ) {
                    *p_org++ = EXT_OP_TEE_LOCAL_FAST;
                    if (is_32bit_type(local_type)) {
                        *p_org++ = (uint8)local_offset;
                    }
                    else {
                        *p_org++ = (uint8)(local_offset | 0x80);
                    }
                    while (p_org < p) {
                        *p_org++ = WASM_OP_NOP;
                    }
                }
#endif
#endif /* end of WASM_ENABLE_FAST_INTERP != 0 */

#if WASM_ENABLE_GC != 0
                if (local_idx >= param_count) {
                    wasm_loader_mask_local(loader_ctx, local_idx - param_count);
                }
#endif
                break;
            }

            case WASM_OP_GET_GLOBAL:
            {
#if WASM_ENABLE_GC != 0
                WASMRefType *ref_type;
#endif

                p_org = p - 1;
                pb_read_leb_uint32(p, p_end, global_idx);
                if (global_idx >= global_count) {
                    set_error_buf(error_buf, error_buf_size, "unknown global");
                    goto fail;
                }

                global_type = global_idx < module->import_global_count
                                  ? module->import_globals[global_idx]
                                        .u.global.type.val_type
                                  : module
                                        ->globals[global_idx
                                                  - module->import_global_count]
                                        .type.val_type;
#if WASM_ENABLE_GC != 0
                ref_type =
                    global_idx < module->import_global_count
                        ? module->import_globals[global_idx].u.global.ref_type
                        : module
                              ->globals[global_idx
                                        - module->import_global_count]
                              .ref_type;
                if (wasm_is_type_multi_byte_type(global_type)) {
                    bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType), ref_type,
                                wasm_reftype_struct_size(ref_type));
                }
#endif

                PUSH_TYPE(global_type);

#if WASM_ENABLE_FAST_INTERP == 0
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
#if WASM_ENABLE_DEBUG_INTERP != 0
                    if (!record_fast_op(module, p_org, *p_org, error_buf,
                                        error_buf_size)) {
                        goto fail;
                    }
#endif
                    *p_org = WASM_OP_GET_GLOBAL_64;
                }
#else /* else of WASM_ENABLE_FAST_INTERP */
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    skip_label();
                    emit_label(WASM_OP_GET_GLOBAL_64);
                }
#if WASM_ENABLE_SIMDE != 0
                if (global_type == VALUE_TYPE_V128) {
                    skip_label();
                    emit_label(WASM_OP_GET_GLOBAL_V128);
                }
#endif /* end of WASM_ENABLE_SIMDE */
                emit_uint32(loader_ctx, global_idx);
                PUSH_OFFSET_TYPE(global_type);
#endif /* end of WASM_ENABLE_FAST_INTERP */
                break;
            }

            case WASM_OP_SET_GLOBAL:
            {
                bool is_mutable = false;
#if WASM_ENABLE_GC != 0
                WASMRefType *ref_type;
#endif

                p_org = p - 1;
                pb_read_leb_uint32(p, p_end, global_idx);
                if (global_idx >= global_count) {
                    set_error_buf(error_buf, error_buf_size, "unknown global");
                    goto fail;
                }

                is_mutable = global_idx < module->import_global_count
                                 ? module->import_globals[global_idx]
                                       .u.global.type.is_mutable
                                 : module
                                       ->globals[global_idx
                                                 - module->import_global_count]
                                       .type.is_mutable;
                if (!is_mutable) {
#if WASM_ENABLE_GC == 0
                    set_error_buf(error_buf, error_buf_size,
                                  "global is immutable");
#else
                    set_error_buf(error_buf, error_buf_size,
                                  "immutable global");
#endif
                    goto fail;
                }

                global_type = global_idx < module->import_global_count
                                  ? module->import_globals[global_idx]
                                        .u.global.type.val_type
                                  : module
                                        ->globals[global_idx
                                                  - module->import_global_count]
                                        .type.val_type;
#if WASM_ENABLE_GC != 0
                ref_type =
                    global_idx < module->import_global_count
                        ? module->import_globals[global_idx].u.global.ref_type
                        : module
                              ->globals[global_idx
                                        - module->import_global_count]
                              .ref_type;
                if (wasm_is_type_multi_byte_type(global_type)) {
                    bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType), ref_type,
                                wasm_reftype_struct_size(ref_type));
                }
#endif

#if WASM_ENABLE_FAST_INTERP == 0
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
#if WASM_ENABLE_DEBUG_INTERP != 0
                    if (!record_fast_op(module, p_org, *p_org, error_buf,
                                        error_buf_size)) {
                        goto fail;
                    }
#endif
                    *p_org = WASM_OP_SET_GLOBAL_64;
                }
                else if (module->aux_stack_size > 0
                         && global_idx == module->aux_stack_top_global_index) {
#if WASM_ENABLE_DEBUG_INTERP != 0
                    if (!record_fast_op(module, p_org, *p_org, error_buf,
                                        error_buf_size)) {
                        goto fail;
                    }
#endif
                    *p_org = WASM_OP_SET_GLOBAL_AUX_STACK;
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                    func->has_op_set_global_aux_stack = true;
#endif
                }
#else /* else of WASM_ENABLE_FAST_INTERP */
                if (global_type == VALUE_TYPE_I64
                    || global_type == VALUE_TYPE_F64) {
                    skip_label();
                    emit_label(WASM_OP_SET_GLOBAL_64);
                }
                else if (module->aux_stack_size > 0
                         && global_idx == module->aux_stack_top_global_index) {
                    skip_label();
                    emit_label(WASM_OP_SET_GLOBAL_AUX_STACK);
                }
#if WASM_ENABLE_SIMDE != 0
                else if (global_type == VALUE_TYPE_V128) {
                    skip_label();
                    emit_label(WASM_OP_SET_GLOBAL_V128);
                }
#endif /* end of WASM_ENABLE_SIMDE */
                emit_uint32(loader_ctx, global_idx);
                POP_OFFSET_TYPE(global_type);
#endif /* end of WASM_ENABLE_FAST_INTERP */

                POP_TYPE(global_type);

                break;
            }

            /* load */
            case WASM_OP_I32_LOAD:
            case WASM_OP_I32_LOAD8_S:
            case WASM_OP_I32_LOAD8_U:
            case WASM_OP_I32_LOAD16_S:
            case WASM_OP_I32_LOAD16_U:
            case WASM_OP_I64_LOAD:
            case WASM_OP_I64_LOAD8_S:
            case WASM_OP_I64_LOAD8_U:
            case WASM_OP_I64_LOAD16_S:
            case WASM_OP_I64_LOAD16_U:
            case WASM_OP_I64_LOAD32_S:
            case WASM_OP_I64_LOAD32_U:
            case WASM_OP_F32_LOAD:
            case WASM_OP_F64_LOAD:
            /* store */
            case WASM_OP_I32_STORE:
            case WASM_OP_I32_STORE8:
            case WASM_OP_I32_STORE16:
            case WASM_OP_I64_STORE:
            case WASM_OP_I64_STORE8:
            case WASM_OP_I64_STORE16:
            case WASM_OP_I64_STORE32:
            case WASM_OP_F32_STORE:
            case WASM_OP_F64_STORE:
            {
#if WASM_ENABLE_FAST_INTERP != 0
                /* change F32/F64 into I32/I64 */
                if (opcode == WASM_OP_F32_LOAD) {
                    skip_label();
                    emit_label(WASM_OP_I32_LOAD);
                }
                else if (opcode == WASM_OP_F64_LOAD) {
                    skip_label();
                    emit_label(WASM_OP_I64_LOAD);
                }
                else if (opcode == WASM_OP_F32_STORE) {
                    skip_label();
                    emit_label(WASM_OP_I32_STORE);
                }
                else if (opcode == WASM_OP_F64_STORE) {
                    skip_label();
                    emit_label(WASM_OP_I64_STORE);
                }
#endif
                CHECK_MEMORY();
                pb_read_leb_memarg(p, p_end, align);          /* align */
                pb_read_leb_mem_offset(p, p_end, mem_offset); /* offset */
                if (!check_memory_access_align(opcode, align, error_buf,
                                               error_buf_size)) {
                    goto fail;
                }
#if WASM_ENABLE_FAST_INTERP != 0
                emit_uint32(loader_ctx, mem_offset);
#endif
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_memory_operations = true;
#endif
                switch (opcode) {
                    /* load */
                    case WASM_OP_I32_LOAD:
                    case WASM_OP_I32_LOAD8_S:
                    case WASM_OP_I32_LOAD8_U:
                    case WASM_OP_I32_LOAD16_S:
                    case WASM_OP_I32_LOAD16_U:
                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_I64_LOAD:
                    case WASM_OP_I64_LOAD8_S:
                    case WASM_OP_I64_LOAD8_U:
                    case WASM_OP_I64_LOAD16_S:
                    case WASM_OP_I64_LOAD16_U:
                    case WASM_OP_I64_LOAD32_S:
                    case WASM_OP_I64_LOAD32_U:
                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_I64);
                        break;
                    case WASM_OP_F32_LOAD:
                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_F32);
                        break;
                    case WASM_OP_F64_LOAD:
                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_F64);
                        break;
                    /* store */
                    case WASM_OP_I32_STORE:
                    case WASM_OP_I32_STORE8:
                    case WASM_OP_I32_STORE16:
                        POP_I32();
                        POP_MEM_OFFSET();
                        break;
                    case WASM_OP_I64_STORE:
                    case WASM_OP_I64_STORE8:
                    case WASM_OP_I64_STORE16:
                    case WASM_OP_I64_STORE32:
                        POP_I64();
                        POP_MEM_OFFSET();
                        break;
                    case WASM_OP_F32_STORE:
                        POP_F32();
                        POP_MEM_OFFSET();
                        break;
                    case WASM_OP_F64_STORE:
                        POP_F64();
                        POP_MEM_OFFSET();
                        break;
                    default:
                        break;
                }
                break;
            }

            case WASM_OP_MEMORY_SIZE:
                CHECK_MEMORY();
                pb_read_leb_uint32(p, p_end, memidx);
                check_memidx(module, memidx);
                PUSH_PAGE_COUNT();

                module->possible_memory_grow = true;
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_memory_operations = true;
#endif
                break;

            case WASM_OP_MEMORY_GROW:
                CHECK_MEMORY();
                pb_read_leb_uint32(p, p_end, memidx);
                check_memidx(module, memidx);
                POP_AND_PUSH(mem_offset_type, mem_offset_type);

                module->possible_memory_grow = true;
#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_op_memory_grow = true;
#endif
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_memory_operations = true;
#endif
                break;

            case WASM_OP_I32_CONST:
                pb_read_leb_int32(p, p_end, i32_const);
#if WASM_ENABLE_FAST_INTERP != 0
                skip_label();
                disable_emit = true;
                GET_CONST_OFFSET(VALUE_TYPE_I32, i32_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_I32_CONST);
                    emit_uint32(loader_ctx, i32_const);
                }
#else
                (void)i32_const;
#endif
                PUSH_I32();
                break;

            case WASM_OP_I64_CONST:
                pb_read_leb_int64(p, p_end, i64_const);
#if WASM_ENABLE_FAST_INTERP != 0
                skip_label();
                disable_emit = true;
                GET_CONST_OFFSET(VALUE_TYPE_I64, i64_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_I64_CONST);
                    emit_uint64(loader_ctx, i64_const);
                }
#endif
                PUSH_I64();
                break;

            case WASM_OP_F32_CONST:
                CHECK_BUF(p, p_end, sizeof(float32));
                p += sizeof(float32);
#if WASM_ENABLE_FAST_INTERP != 0
                skip_label();
                disable_emit = true;
                bh_memcpy_s((uint8 *)&f32_const, sizeof(float32), p_org,
                            sizeof(float32));
                GET_CONST_F32_OFFSET(VALUE_TYPE_F32, f32_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_F32_CONST);
                    emit_float32(loader_ctx, f32_const);
                }
#endif
                PUSH_F32();
                break;

            case WASM_OP_F64_CONST:
                CHECK_BUF(p, p_end, sizeof(float64));
                p += sizeof(float64);
#if WASM_ENABLE_FAST_INTERP != 0
                skip_label();
                disable_emit = true;
                /* Some MCU may require 8-byte align */
                bh_memcpy_s((uint8 *)&f64_const, sizeof(float64), p_org,
                            sizeof(float64));
                GET_CONST_F64_OFFSET(VALUE_TYPE_F64, f64_const);

                if (operand_offset == 0) {
                    disable_emit = false;
                    emit_label(WASM_OP_F64_CONST);
                    emit_float64(loader_ctx, f64_const);
                }
#endif
                PUSH_F64();
                break;

            case WASM_OP_I32_EQZ:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_EQ:
            case WASM_OP_I32_NE:
            case WASM_OP_I32_LT_S:
            case WASM_OP_I32_LT_U:
            case WASM_OP_I32_GT_S:
            case WASM_OP_I32_GT_U:
            case WASM_OP_I32_LE_S:
            case WASM_OP_I32_LE_U:
            case WASM_OP_I32_GE_S:
            case WASM_OP_I32_GE_U:
                POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EQZ:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EQ:
            case WASM_OP_I64_NE:
            case WASM_OP_I64_LT_S:
            case WASM_OP_I64_LT_U:
            case WASM_OP_I64_GT_S:
            case WASM_OP_I64_GT_U:
            case WASM_OP_I64_LE_S:
            case WASM_OP_I64_LE_U:
            case WASM_OP_I64_GE_S:
            case WASM_OP_I64_GE_U:
                POP2_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_F32_EQ:
            case WASM_OP_F32_NE:
            case WASM_OP_F32_LT:
            case WASM_OP_F32_GT:
            case WASM_OP_F32_LE:
            case WASM_OP_F32_GE:
                POP2_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_F64_EQ:
            case WASM_OP_F64_NE:
            case WASM_OP_F64_LT:
            case WASM_OP_F64_GT:
            case WASM_OP_F64_LE:
            case WASM_OP_F64_GE:
                POP2_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_CLZ:
            case WASM_OP_I32_CTZ:
            case WASM_OP_I32_POPCNT:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_ADD:
            case WASM_OP_I32_SUB:
            case WASM_OP_I32_MUL:
            case WASM_OP_I32_DIV_S:
            case WASM_OP_I32_DIV_U:
            case WASM_OP_I32_REM_S:
            case WASM_OP_I32_REM_U:
            case WASM_OP_I32_AND:
            case WASM_OP_I32_OR:
            case WASM_OP_I32_XOR:
            case WASM_OP_I32_SHL:
            case WASM_OP_I32_SHR_S:
            case WASM_OP_I32_SHR_U:
            case WASM_OP_I32_ROTL:
            case WASM_OP_I32_ROTR:
                POP2_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_CLZ:
            case WASM_OP_I64_CTZ:
            case WASM_OP_I64_POPCNT:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_ADD:
            case WASM_OP_I64_SUB:
            case WASM_OP_I64_MUL:
            case WASM_OP_I64_DIV_S:
            case WASM_OP_I64_DIV_U:
            case WASM_OP_I64_REM_S:
            case WASM_OP_I64_REM_U:
            case WASM_OP_I64_AND:
            case WASM_OP_I64_OR:
            case WASM_OP_I64_XOR:
            case WASM_OP_I64_SHL:
            case WASM_OP_I64_SHR_S:
            case WASM_OP_I64_SHR_U:
            case WASM_OP_I64_ROTL:
            case WASM_OP_I64_ROTR:
                POP2_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_ABS:
            case WASM_OP_F32_NEG:
            case WASM_OP_F32_CEIL:
            case WASM_OP_F32_FLOOR:
            case WASM_OP_F32_TRUNC:
            case WASM_OP_F32_NEAREST:
            case WASM_OP_F32_SQRT:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_ADD:
            case WASM_OP_F32_SUB:
            case WASM_OP_F32_MUL:
            case WASM_OP_F32_DIV:
            case WASM_OP_F32_MIN:
            case WASM_OP_F32_MAX:
            case WASM_OP_F32_COPYSIGN:
                POP2_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_ABS:
            case WASM_OP_F64_NEG:
            case WASM_OP_F64_CEIL:
            case WASM_OP_F64_FLOOR:
            case WASM_OP_F64_TRUNC:
            case WASM_OP_F64_NEAREST:
            case WASM_OP_F64_SQRT:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_ADD:
            case WASM_OP_F64_SUB:
            case WASM_OP_F64_MUL:
            case WASM_OP_F64_DIV:
            case WASM_OP_F64_MIN:
            case WASM_OP_F64_MAX:
            case WASM_OP_F64_COPYSIGN:
                POP2_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_WRAP_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_TRUNC_S_F32:
            case WASM_OP_I32_TRUNC_U_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I32_TRUNC_S_F64:
            case WASM_OP_I32_TRUNC_U_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EXTEND_S_I32:
            case WASM_OP_I64_EXTEND_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_TRUNC_S_F32:
            case WASM_OP_I64_TRUNC_U_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I64);
                break;

            case WASM_OP_I64_TRUNC_S_F64:
            case WASM_OP_I64_TRUNC_U_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_CONVERT_S_I32:
            case WASM_OP_F32_CONVERT_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_CONVERT_S_I64:
            case WASM_OP_F32_CONVERT_U_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F32);
                break;

            case WASM_OP_F32_DEMOTE_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_CONVERT_S_I32:
            case WASM_OP_F64_CONVERT_U_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_CONVERT_S_I64:
            case WASM_OP_F64_CONVERT_U_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F64);
                break;

            case WASM_OP_F64_PROMOTE_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_REINTERPRET_F32:
                POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_REINTERPRET_F64:
                POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                break;

            case WASM_OP_F32_REINTERPRET_I32:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_F32);
                break;

            case WASM_OP_F64_REINTERPRET_I64:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_F64);
                break;

            case WASM_OP_I32_EXTEND8_S:
            case WASM_OP_I32_EXTEND16_S:
                POP_AND_PUSH(VALUE_TYPE_I32, VALUE_TYPE_I32);
                break;

            case WASM_OP_I64_EXTEND8_S:
            case WASM_OP_I64_EXTEND16_S:
            case WASM_OP_I64_EXTEND32_S:
                POP_AND_PUSH(VALUE_TYPE_I64, VALUE_TYPE_I64);
                break;

#if WASM_ENABLE_GC != 0
            case WASM_OP_GC_PREFIX:
            {
                uint32 opcode1;

                pb_read_leb_uint32(p, p_end, opcode1);
#if WASM_ENABLE_FAST_INTERP != 0
                emit_byte(loader_ctx, ((uint8)opcode1));
#endif

                switch (opcode1) {
                    case WASM_OP_STRUCT_NEW:
                    case WASM_OP_STRUCT_NEW_DEFAULT:
                    {
                        pb_read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, type_idx);
#endif
                        if (!check_type_index(module, module->type_count,
                                              type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }
                        if (module->types[type_idx] == NULL
                            || module->types[type_idx]->type_flag
                                   != WASM_TYPE_STRUCT) {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown struct type");
                            goto fail;
                        }

                        if (opcode1 == WASM_OP_STRUCT_NEW) {
                            int32 j, k;
                            uint8 value_type;
                            uint32 ref_type_struct_size;
                            WASMStructType *struct_type =
                                (WASMStructType *)module->types[type_idx];

                            k = struct_type->ref_type_map_count - 1;
                            for (j = struct_type->field_count - 1; j >= 0;
                                 j--) {
                                value_type = struct_type->fields[j].field_type;
                                if (wasm_is_type_reftype(value_type)) {
                                    if (wasm_is_type_multi_byte_type(
                                            value_type)) {
                                        ref_type_struct_size =
                                            wasm_reftype_struct_size(
                                                struct_type->ref_type_maps[k]
                                                    .ref_type);
                                        bh_memcpy_s(
                                            &wasm_ref_type,
                                            (uint32)sizeof(WASMRefType),
                                            struct_type->ref_type_maps[k]
                                                .ref_type,
                                            ref_type_struct_size);
                                        k--;
                                    }
                                    POP_REF(value_type);
                                }
                                else {
                                    switch (value_type) {
                                        case VALUE_TYPE_I32:
                                        case PACKED_TYPE_I8:
                                        case PACKED_TYPE_I16:
                                            POP_I32();
                                            break;
                                        case VALUE_TYPE_I64:
                                            POP_I64();
                                            break;
                                        case VALUE_TYPE_F32:
                                            POP_F32();
                                            break;
                                        case VALUE_TYPE_F64:
                                            POP_F64();
                                            break;
                                        default:
                                            set_error_buf(error_buf,
                                                          error_buf_size,
                                                          "unknown type");
                                            goto fail;
                                    }
                                }
                            }
                        }

                        /* PUSH struct obj, (ref $t) */
                        wasm_set_refheaptype_typeidx(
                            &wasm_ref_type.ref_ht_typeidx, false, type_idx);
                        PUSH_REF(wasm_ref_type.ref_type);
                        break;
                    }

                    case WASM_OP_STRUCT_GET:
                    case WASM_OP_STRUCT_GET_S:
                    case WASM_OP_STRUCT_GET_U:
                    case WASM_OP_STRUCT_SET:
                    {
                        WASMStructType *struct_type;
                        WASMRefType *ref_type = NULL;
                        uint32 field_idx;
                        uint8 field_type;

                        pb_read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, type_idx);
#endif
                        if (!check_type_index(module, module->type_count,
                                              type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }
                        if (module->types[type_idx] == NULL
                            || module->types[type_idx]->type_flag
                                   != WASM_TYPE_STRUCT) {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown struct type");
                            goto fail;
                        }
                        struct_type = (WASMStructType *)module->types[type_idx];

                        pb_read_leb_uint32(p, p_end, field_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, field_idx);
#endif
                        if (field_idx >= struct_type->field_count) {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown struct field");
                            goto fail;
                        }

                        if (opcode1 == WASM_OP_STRUCT_SET
                            && !(struct_type->fields[field_idx].field_flags
                                 & 1)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "field is immutable");
                            goto fail;
                        }

                        field_type = struct_type->fields[field_idx].field_type;
                        if (is_packed_type(field_type)) {
                            if (opcode1 == WASM_OP_STRUCT_GET) {
                                set_error_buf(error_buf, error_buf_size,
                                              "type mismatch");
                                goto fail;
                            }
                            else {
                                field_type = VALUE_TYPE_I32;
                            }
                        }
                        if (wasm_is_type_multi_byte_type(field_type)) {
                            ref_type = wasm_reftype_map_find(
                                struct_type->ref_type_maps,
                                struct_type->ref_type_map_count, field_idx);
                            bh_assert(ref_type);
                        }
                        if (opcode1 == WASM_OP_STRUCT_SET) {
                            /* POP field */
                            if (wasm_is_type_multi_byte_type(field_type)) {
                                bh_memcpy_s(&wasm_ref_type,
                                            (uint32)sizeof(WASMRefType),
                                            ref_type,
                                            wasm_reftype_struct_size(ref_type));
                            }
                            POP_REF(field_type);
                            /* POP struct obj, (ref null $t) */
                            wasm_set_refheaptype_typeidx(
                                &wasm_ref_type.ref_ht_typeidx, true, type_idx);
                            POP_REF(wasm_ref_type.ref_type);
                        }
                        else {
                            /* POP struct obj, (ref null $t) */
                            wasm_set_refheaptype_typeidx(
                                &wasm_ref_type.ref_ht_typeidx, true, type_idx);
                            POP_REF(wasm_ref_type.ref_type);
                            /* PUSH field */
                            if (wasm_is_type_multi_byte_type(field_type)) {
                                bh_memcpy_s(&wasm_ref_type,
                                            (uint32)sizeof(WASMRefType),
                                            ref_type,
                                            wasm_reftype_struct_size(ref_type));
                            }
                            PUSH_REF(field_type);
                        }
                        break;
                    }

                    case WASM_OP_ARRAY_NEW:
                    case WASM_OP_ARRAY_NEW_DEFAULT:
                    case WASM_OP_ARRAY_NEW_FIXED:
                    case WASM_OP_ARRAY_NEW_DATA:
                    case WASM_OP_ARRAY_NEW_ELEM:
                    {
                        WASMArrayType *array_type;
                        uint8 elem_type;
                        uint32 u32 = 0;

                        pb_read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, type_idx);
#endif
                        if (opcode1 == WASM_OP_ARRAY_NEW_FIXED
                            || opcode1 == WASM_OP_ARRAY_NEW_DATA
                            || opcode1 == WASM_OP_ARRAY_NEW_ELEM) {
                            pb_read_leb_uint32(p, p_end, u32);
#if WASM_ENABLE_FAST_INTERP != 0
                            emit_uint32(loader_ctx, u32);
#endif
                        }

                        if (!check_array_type(module, type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }

                        if (opcode1 != WASM_OP_ARRAY_NEW_FIXED) {
                            /* length */
                            POP_I32();
                        }

                        array_type = (WASMArrayType *)module->types[type_idx];
                        elem_type = array_type->elem_type;

                        if (opcode1 == WASM_OP_ARRAY_NEW
                            || opcode1 == WASM_OP_ARRAY_NEW_FIXED) {
                            if (wasm_is_type_multi_byte_type(elem_type)) {
                                bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                            array_type->elem_ref_type,
                                            wasm_reftype_struct_size(
                                                array_type->elem_ref_type));
                            }
                            if (is_packed_type(elem_type)) {
                                elem_type = VALUE_TYPE_I32;
                            }

                            if (opcode1 == WASM_OP_ARRAY_NEW_FIXED) {
                                uint32 N = u32;
                                for (i = 0; i < N; i++) {
                                    if (wasm_is_type_multi_byte_type(
                                            elem_type)) {
                                        bh_memcpy_s(
                                            &wasm_ref_type, sizeof(WASMRefType),
                                            array_type->elem_ref_type,
                                            wasm_reftype_struct_size(
                                                array_type->elem_ref_type));
                                    }
                                    POP_REF(elem_type);
                                }
                            }
                            else
                                POP_REF(elem_type);
                        }
                        else if (opcode1 == WASM_OP_ARRAY_NEW_DATA) {
                            /* offset of data segment */
                            POP_I32();

                            if (u32 >= module->data_seg_count) {
                                set_error_buf(error_buf, error_buf_size,
                                              "unknown data segment");
                                goto fail;
                            }

                            if (wasm_is_type_reftype(elem_type)) {
                                set_error_buf(error_buf, error_buf_size,
                                              "array elem type mismatch");
                                goto fail;
                            }
                        }
                        else if (opcode1 == WASM_OP_ARRAY_NEW_ELEM) {
                            WASMTableSeg *table_seg =
                                module->table_segments + u32;

                            /* offset of element segment */
                            POP_I32();

                            if (u32 >= module->table_seg_count) {
                                set_error_buf(error_buf, error_buf_size,
                                              "unknown element segment");
                                goto fail;
                            }
                            if (!wasm_reftype_is_subtype_of(
                                    table_seg->elem_type,
                                    table_seg->elem_ref_type, elem_type,
                                    array_type->elem_ref_type, module->types,
                                    module->type_count)) {
                                set_error_buf(error_buf, error_buf_size,
                                              "array elem type mismatch");
                                goto fail;
                            }
                        }

                        /* PUSH array obj, (ref $t) */
                        wasm_set_refheaptype_typeidx(
                            &wasm_ref_type.ref_ht_typeidx, false, type_idx);
                        PUSH_REF(wasm_ref_type.ref_type);
                        break;
                    }

                    case WASM_OP_ARRAY_GET:
                    case WASM_OP_ARRAY_GET_S:
                    case WASM_OP_ARRAY_GET_U:
                    case WASM_OP_ARRAY_SET:
                    {
                        uint8 elem_type;
                        WASMArrayType *array_type;
                        WASMRefType *ref_type = NULL;

                        pb_read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, type_idx);
#endif
                        if (!check_array_type(module, type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }
                        array_type = (WASMArrayType *)module->types[type_idx];

                        if (opcode1 == WASM_OP_ARRAY_SET
                            && !(array_type->elem_flags & 1)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "array is immutable");
                            goto fail;
                        }

                        elem_type = array_type->elem_type;
                        if (is_packed_type(elem_type)) {
                            if (opcode1 != WASM_OP_ARRAY_GET_S
                                && opcode1 != WASM_OP_ARRAY_GET_U
                                && opcode1 != WASM_OP_ARRAY_SET) {
                                set_error_buf(error_buf, error_buf_size,
                                              "type mismatch");
                                goto fail;
                            }
                            else {
                                elem_type = VALUE_TYPE_I32;
                            }
                        }
                        ref_type = array_type->elem_ref_type;

                        if (opcode1 == WASM_OP_ARRAY_SET) {
                            /* POP elem to set */
                            if (wasm_is_type_multi_byte_type(elem_type)) {
                                bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                            ref_type,
                                            wasm_reftype_struct_size(ref_type));
                            }
                            POP_REF(elem_type);
                        }
                        /* elem idx */
                        POP_I32();
                        /* POP array obj, (ref null $t) */
                        wasm_set_refheaptype_typeidx(
                            &wasm_ref_type.ref_ht_typeidx, true, type_idx);
                        POP_REF(wasm_ref_type.ref_type);
                        if (opcode1 != WASM_OP_ARRAY_SET) {
                            /* PUSH elem */
                            if (wasm_is_type_multi_byte_type(elem_type)) {
                                bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                            ref_type,
                                            wasm_reftype_struct_size(ref_type));
                            }
                            PUSH_REF(elem_type);
                        }
                        break;
                    }

                    case WASM_OP_ARRAY_LEN:
                    {
                        POP_REF(REF_TYPE_ARRAYREF);
                        /* length */
                        PUSH_I32();
                        break;
                    }

                    case WASM_OP_ARRAY_FILL:
                    {
                        WASMArrayType *array_type;
                        uint8 elem_type;
                        /* typeidx */
                        pb_read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, type_idx);
#endif
                        if (!check_array_type(module, type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }

                        array_type = (WASMArrayType *)module->types[type_idx];
                        if (!(array_type->elem_flags & 1)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "array is immutable");
                            goto fail;
                        }

                        elem_type = array_type->elem_type;
                        if (is_packed_type(elem_type)) {
                            elem_type = VALUE_TYPE_I32;
                        }

                        POP_I32(); /* length */
#if WASM_ENABLE_FAST_INTERP != 0
                        POP_OFFSET_TYPE(elem_type);
#endif
                        POP_TYPE(elem_type);
                        POP_I32(); /* start */
                        /* POP array obj, (ref null $t) */
                        wasm_set_refheaptype_typeidx(
                            &wasm_ref_type.ref_ht_typeidx, true, type_idx);
                        POP_REF(wasm_ref_type.ref_type);

                        break;
                    }

                    case WASM_OP_ARRAY_COPY:
                    {
                        uint32 src_type_idx;
                        uint8 src_elem_type, dst_elem_type;
                        WASMRefType src_ref_type = { 0 },
                                    *src_elem_ref_type = NULL;
                        WASMRefType dst_ref_type = { 0 },
                                    *dst_elem_ref_type = NULL;
                        WASMArrayType *array_type;

                        /* typeidx1 */
                        pb_read_leb_uint32(p, p_end, type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, type_idx);
#endif
                        /* typeidx2 */
                        pb_read_leb_uint32(p, p_end, src_type_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, src_type_idx);
#endif
                        if (!check_array_type(module, type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }

                        if (!check_array_type(module, src_type_idx, error_buf,
                                              error_buf_size)) {
                            goto fail;
                        }

                        POP_I32();
                        POP_I32();
                        /* POP array obj, (ref null $t) */
                        wasm_set_refheaptype_typeidx(
                            &wasm_ref_type.ref_ht_typeidx, true, src_type_idx);
                        POP_REF(wasm_ref_type.ref_type);
                        bh_memcpy_s(&src_ref_type, (uint32)sizeof(WASMRefType),
                                    &wasm_ref_type,
                                    wasm_reftype_struct_size(&wasm_ref_type));
                        POP_I32();
                        /* POP array obj, (ref null $t) */
                        wasm_set_refheaptype_typeidx(
                            &wasm_ref_type.ref_ht_typeidx, true, type_idx);
                        POP_REF(wasm_ref_type.ref_type);
                        bh_memcpy_s(&dst_ref_type, (uint32)sizeof(WASMRefType),
                                    &wasm_ref_type,
                                    wasm_reftype_struct_size(&wasm_ref_type));

                        array_type = (WASMArrayType *)module->types[type_idx];
                        if (!(array_type->elem_flags & 1)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "destination array is immutable");
                            goto fail;
                        }

                        dst_elem_type = array_type->elem_type;
                        if (wasm_is_type_multi_byte_type(dst_elem_type)) {
                            dst_elem_ref_type = array_type->elem_ref_type;
                        }

                        array_type =
                            (WASMArrayType *)module->types[src_type_idx];
                        src_elem_type = array_type->elem_type;
                        if (wasm_is_type_multi_byte_type(src_elem_type)) {
                            src_elem_ref_type = array_type->elem_ref_type;
                        }

                        if (!wasm_reftype_is_subtype_of(
                                src_elem_type, src_elem_ref_type, dst_elem_type,
                                dst_elem_ref_type, module->types,
                                module->type_count)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "array types do not match");
                            goto fail;
                        }

                        break;
                    }

                    case WASM_OP_REF_I31:
                    {
                        POP_I32();
                        wasm_set_refheaptype_common(
                            &wasm_ref_type.ref_ht_common, false, HEAP_TYPE_I31);
                        PUSH_REF(wasm_ref_type.ref_type);
                        break;
                    }

                    case WASM_OP_I31_GET_S:
                    case WASM_OP_I31_GET_U:
                    {
                        POP_REF(REF_TYPE_I31REF);
                        PUSH_I32();
                        break;
                    }

                    case WASM_OP_REF_TEST:
                    case WASM_OP_REF_CAST:
                    case WASM_OP_REF_TEST_NULLABLE:
                    case WASM_OP_REF_CAST_NULLABLE:
                    {
                        uint8 type;

                        pb_read_leb_int32(p, p_end, heap_type);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, (uint32)heap_type);
#endif
                        if (heap_type >= 0) {
                            if (!check_type_index(module, module->type_count,
                                                  heap_type, error_buf,
                                                  error_buf_size)) {
                                goto fail;
                            }
                        }
                        else {
                            if (!wasm_is_valid_heap_type(heap_type)) {
                                set_error_buf(error_buf, error_buf_size,
                                              "unknown type");
                                goto fail;
                            }
                        }
                        if (!wasm_loader_pop_heap_obj(loader_ctx, &type,
                                                      &wasm_ref_type, error_buf,
                                                      error_buf_size)) {
                            goto fail;
                        }
                        if (opcode1 == WASM_OP_REF_TEST
                            || opcode1 == WASM_OP_REF_TEST_NULLABLE)
                            PUSH_I32();
                        else {
                            bool nullable =
                                (opcode1 == WASM_OP_REF_CAST_NULLABLE) ? true
                                                                       : false;
                            if (heap_type >= 0 || !nullable) {
                                wasm_set_refheaptype_typeidx(
                                    &wasm_ref_type.ref_ht_typeidx, nullable,
                                    heap_type);
                                PUSH_REF(wasm_ref_type.ref_type);
                            }
                            else {
                                PUSH_REF((uint8)((int32)0x80 + heap_type));
                            }
                        }
                        break;
                    }

                    case WASM_OP_BR_ON_CAST:
                    case WASM_OP_BR_ON_CAST_FAIL:
                    {
                        WASMRefType ref_type_tmp = { 0 }, ref_type1 = { 0 },
                                    ref_type2 = { 0 }, ref_type_diff = { 0 };
                        uint8 type_tmp, castflags;
                        uint32 depth;
                        int32 heap_type_dst;
                        bool src_nullable, dst_nullable;

                        CHECK_BUF(p, p_end, 1);
                        castflags = read_uint8(p);
#if WASM_ENABLE_FAST_INTERP != 0
                        /* Emit heap_type firstly */
                        emit_byte(loader_ctx, castflags);
#endif

                        p_org = p;
                        pb_read_leb_uint32(p, p_end, depth);
                        pb_read_leb_int32(p, p_end, heap_type);
#if WASM_ENABLE_FAST_INTERP != 0
                        /* Emit heap_type firstly */
                        emit_uint32(loader_ctx, (uint32)heap_type);
#endif
                        pb_read_leb_int32(p, p_end, heap_type_dst);
#if WASM_ENABLE_FAST_INTERP != 0
                        /* Emit heap_type firstly */
                        emit_uint32(loader_ctx, (uint32)heap_type_dst);
#endif
                        (void)depth;

                        /*
                         * castflags should be 0~3:
                         *  0: (non-null, non-null)
                         *  1: (null, non-null)
                         *  2: (non-null, null)
                         *  3: (null, null)
                         */
                        if (castflags > 3) {
                            set_error_buf(error_buf, error_buf_size,
                                          "invalid castflags");
                            break;
                        }
                        src_nullable =
                            (castflags == 1) || (castflags == 3) ? true : false;
                        dst_nullable =
                            (castflags == 2) || (castflags == 3) ? true : false;

                        /* Pop and backup the stack top's ref type */
                        if (!wasm_loader_pop_heap_obj(loader_ctx, &type_tmp,
                                                      &ref_type_tmp, error_buf,
                                                      error_buf_size)) {
                            goto fail;
                        }

                        /* The reference type rt1 must be valid */
                        if (!init_ref_type(module, &ref_type1, src_nullable,
                                           heap_type, error_buf,
                                           error_buf_size)) {
                            goto fail;
                        }

                        /* The reference type rt2 must be valid. */
                        if (!init_ref_type(module, &ref_type2, dst_nullable,
                                           heap_type_dst, error_buf,
                                           error_buf_size)) {
                            goto fail;
                        }

                        calculate_reftype_diff(&ref_type_diff, &ref_type1,
                                               &ref_type2);

                        /* The reference type rt2 must match rt1. */
                        if (!wasm_reftype_is_subtype_of(
                                ref_type2.ref_type, &ref_type2,
                                ref_type1.ref_type, &ref_type1, module->types,
                                module->type_count)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }

                        p = p_org;
                        /* Push ref type casted for branch block check */
                        if (opcode1 == WASM_OP_BR_ON_CAST) {
                            /* The reference type rt2 must match rt′. */
                            type_tmp = ref_type2.ref_type;
                            if (wasm_is_type_multi_byte_type(type_tmp)) {
                                bh_memcpy_s(
                                    &wasm_ref_type,
                                    wasm_reftype_struct_size(&ref_type2),
                                    &ref_type2,
                                    wasm_reftype_struct_size(&ref_type2));
                            }
                        }
                        else {
                            /* The reference type rt′1 must match rt′. */
                            type_tmp = ref_type_diff.ref_type;
                            if (wasm_is_type_multi_byte_type(type_tmp)) {
                                bh_memcpy_s(
                                    &wasm_ref_type,
                                    wasm_reftype_struct_size(&ref_type_diff),
                                    &ref_type_diff,
                                    wasm_reftype_struct_size(&ref_type_diff));
                            }
                        }
                        PUSH_REF(type_tmp);
                        if (!(frame_csp_tmp = check_branch_block(
                                  loader_ctx, &p, p_end, opcode, error_buf,
                                  error_buf_size))) {
                            goto fail;
                        }
                        /* Ignore heap_types */
                        skip_leb_uint32(p, p_end);
                        skip_leb_uint32(p, p_end);

                        /* Restore the original stack top's ref type */
                        POP_REF(type_tmp);
#if WASM_ENABLE_FAST_INTERP != 0
                        /* Erase the opnd offset emitted by POP_REF() */
                        wasm_loader_emit_backspace(loader_ctx, sizeof(uint16));
#endif
                        if (opcode1 == WASM_OP_BR_ON_CAST) {
                            type_tmp = ref_type_diff.ref_type;
                            if (wasm_is_type_multi_byte_type(type_tmp)) {
                                bh_memcpy_s(
                                    &wasm_ref_type,
                                    wasm_reftype_struct_size(&ref_type_diff),
                                    &ref_type_diff,
                                    wasm_reftype_struct_size(&ref_type_diff));
                            }
                        }
                        else {
                            type_tmp = ref_type2.ref_type;
                            if (wasm_is_type_multi_byte_type(type_tmp)) {
                                bh_memcpy_s(
                                    &wasm_ref_type,
                                    wasm_reftype_struct_size(&ref_type2),
                                    &ref_type2,
                                    wasm_reftype_struct_size(&ref_type2));
                            }
                        }
                        PUSH_REF(type_tmp);

#if WASM_ENABLE_FAST_INTERP != 0
                        /* Erase the opnd offset emitted by PUSH_REF() */
                        wasm_loader_emit_backspace(loader_ctx, sizeof(uint16));
#endif
                        break;
                    }

                    case WASM_OP_ANY_CONVERT_EXTERN:
                    {
                        uint8 type;

                        if (!wasm_loader_pop_heap_obj(loader_ctx, &type,
                                                      &wasm_ref_type, error_buf,
                                                      error_buf_size)) {
                            goto fail;
                        }
                        if (!(type == REF_TYPE_EXTERNREF
                              || (type == REF_TYPE_HT_NON_NULLABLE
                                  && wasm_ref_type.ref_ht_common.heap_type
                                         == HEAP_TYPE_EXTERN)
                              || type == VALUE_TYPE_ANY)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }

                        if (type == REF_TYPE_EXTERNREF)
                            type = REF_TYPE_ANYREF;
                        else {
                            wasm_ref_type.ref_ht_common.heap_type =
                                HEAP_TYPE_ANY;
                        }
                        PUSH_REF(type);
                        break;
                    }

                    case WASM_OP_EXTERN_CONVERT_ANY:
                    {
                        uint8 type;

                        if (!wasm_loader_pop_heap_obj(loader_ctx, &type,
                                                      &wasm_ref_type, error_buf,
                                                      error_buf_size)) {
                            goto fail;
                        }
                        if (type == REF_TYPE_EXTERNREF
                            || ((type == REF_TYPE_HT_NULLABLE
                                 || type == REF_TYPE_HT_NON_NULLABLE)
                                && wasm_ref_type.ref_ht_common.heap_type
                                       == HEAP_TYPE_EXTERN)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }

                        if (type != REF_TYPE_HT_NON_NULLABLE) {
                            /* push (ref null extern) */
                            type = REF_TYPE_EXTERNREF;
                        }
                        else {
                            /* push (ref extern) */
                            type = REF_TYPE_HT_NON_NULLABLE;
                            wasm_set_refheaptype_common(
                                &wasm_ref_type.ref_ht_common, false,
                                HEAP_TYPE_EXTERN);
                        }
                        PUSH_REF(type);
                        break;
                    }

#if WASM_ENABLE_STRINGREF != 0
                    case WASM_OP_STRING_NEW_UTF8:
                    case WASM_OP_STRING_NEW_WTF16:
                    case WASM_OP_STRING_NEW_LOSSY_UTF8:
                    case WASM_OP_STRING_NEW_WTF8:
                    {
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif

                        pb_read_leb_uint32(p, p_end, memidx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, (uint32)memidx);
#endif
                        POP_I32();
                        POP_I32();
                        PUSH_REF(REF_TYPE_STRINGREF);
                        break;
                    }
                    case WASM_OP_STRING_CONST:
                    {
                        uint32 contents;

                        pb_read_leb_uint32(p, p_end, contents);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, (uint32)contents);
#endif
                        PUSH_REF(REF_TYPE_STRINGREF);
                        (void)contents;
                        break;
                    }
                    case WASM_OP_STRING_MEASURE_UTF8:
                    case WASM_OP_STRING_MEASURE_WTF8:
                    case WASM_OP_STRING_MEASURE_WTF16:
                    {
                        POP_STRINGREF();
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRING_ENCODE_UTF8:
                    case WASM_OP_STRING_ENCODE_WTF16:
                    case WASM_OP_STRING_ENCODE_LOSSY_UTF8:
                    case WASM_OP_STRING_ENCODE_WTF8:
                    {
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif

                        pb_read_leb_uint32(p, p_end, memidx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, (uint32)memidx);
#endif
                        POP_I32();
                        POP_STRINGREF();
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRING_CONCAT:
                    {
                        POP_STRINGREF();
                        POP_STRINGREF();
                        PUSH_REF(REF_TYPE_STRINGREF);
                        break;
                    }
                    case WASM_OP_STRING_EQ:
                    {
                        POP_STRINGREF();
                        POP_STRINGREF();
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRING_IS_USV_SEQUENCE:
                    {
                        POP_STRINGREF();
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRING_AS_WTF8:
                    {
                        POP_STRINGREF();
                        PUSH_REF(REF_TYPE_STRINGVIEWWTF8);
                        break;
                    }
                    case WASM_OP_STRINGVIEW_WTF8_ADVANCE:
                    {
                        POP_I32();
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWWTF8);
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_UTF8:
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_LOSSY_UTF8:
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_WTF8:
                    {
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif

                        pb_read_leb_uint32(p, p_end, memidx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, (uint32)memidx);
#endif
                        POP_I32();
                        POP_I32();
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWWTF8);
                        PUSH_I32();
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRINGVIEW_WTF8_SLICE:
                    {
                        POP_I32();
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWWTF8);
                        PUSH_REF(REF_TYPE_STRINGREF);
                        break;
                    }
                    case WASM_OP_STRING_AS_WTF16:
                    {
                        POP_STRINGREF();
                        PUSH_REF(REF_TYPE_STRINGVIEWWTF16);
                        break;
                    }
                    case WASM_OP_STRINGVIEW_WTF16_LENGTH:
                    {
                        POP_REF(REF_TYPE_STRINGVIEWWTF16);
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRINGVIEW_WTF16_GET_CODEUNIT:
                    {
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWWTF16);
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRINGVIEW_WTF16_ENCODE:
                    {
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif

                        pb_read_leb_uint32(p, p_end, memidx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, (uint32)memidx);
#endif
                        POP_I32();
                        POP_I32();
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWWTF16);
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRINGVIEW_WTF16_SLICE:
                    {
                        POP_I32();
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWWTF16);
                        PUSH_REF(REF_TYPE_STRINGREF);
                        break;
                    }
                    case WASM_OP_STRING_AS_ITER:
                    {
                        POP_STRINGREF();
                        PUSH_REF(REF_TYPE_STRINGVIEWITER);
                        break;
                    }
                    case WASM_OP_STRINGVIEW_ITER_NEXT:
                    {
                        POP_REF(REF_TYPE_STRINGVIEWITER);
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRINGVIEW_ITER_ADVANCE:
                    case WASM_OP_STRINGVIEW_ITER_REWIND:
                    {
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWITER);
                        PUSH_I32();
                        break;
                    }
                    case WASM_OP_STRINGVIEW_ITER_SLICE:
                    {
                        POP_I32();
                        POP_REF(REF_TYPE_STRINGVIEWITER);
                        PUSH_REF(REF_TYPE_STRINGREF);
                        break;
                    }
                    case WASM_OP_STRING_NEW_UTF8_ARRAY:
                    case WASM_OP_STRING_NEW_WTF16_ARRAY:
                    case WASM_OP_STRING_NEW_LOSSY_UTF8_ARRAY:
                    case WASM_OP_STRING_NEW_WTF8_ARRAY:
                    {
                        POP_I32();
                        POP_I32();
                        POP_REF(REF_TYPE_ARRAYREF);
                        PUSH_REF(REF_TYPE_STRINGREF);
                        break;
                    }
                    case WASM_OP_STRING_ENCODE_UTF8_ARRAY:
                    case WASM_OP_STRING_ENCODE_WTF16_ARRAY:
                    case WASM_OP_STRING_ENCODE_LOSSY_UTF8_ARRAY:
                    case WASM_OP_STRING_ENCODE_WTF8_ARRAY:
                    {
                        POP_I32();
                        POP_REF(REF_TYPE_ARRAYREF);
                        POP_STRINGREF();
                        PUSH_I32();
                        break;
                    }
#endif /* end of WASM_ENABLE_STRINGREF != 0 */
                    default:
                        set_error_buf_v(error_buf, error_buf_size,
                                        "%s %02x %02x", "unsupported opcode",
                                        0xfb, opcode1);
                        goto fail;
                }
                break;
            }
#endif /* end of WASM_ENABLE_GC != 0 */

            case WASM_OP_MISC_PREFIX:
            {
                uint32 opcode1;

                pb_read_leb_uint32(p, p_end, opcode1);
#if WASM_ENABLE_FAST_INTERP != 0
                emit_byte(loader_ctx, ((uint8)opcode1));
#endif
                switch (opcode1) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                        POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                        POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                        POP_AND_PUSH(VALUE_TYPE_F32, VALUE_TYPE_I64);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        POP_AND_PUSH(VALUE_TYPE_F64, VALUE_TYPE_I64);
                        break;
#if WASM_ENABLE_BULK_MEMORY != 0
                    case WASM_OP_MEMORY_INIT:
                    {
                        pb_read_leb_uint32(p, p_end, data_seg_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, data_seg_idx);
#endif
                        if (module->import_memory_count == 0
                            && module->memory_count == 0)
                            goto fail_unknown_memory;

                        pb_read_leb_uint32(p, p_end, memidx);
                        check_memidx(module, memidx);

                        if (data_seg_idx >= module->data_seg_count) {
                            set_error_buf_v(error_buf, error_buf_size,
                                            "unknown data segment %d",
                                            data_seg_idx);
                            goto fail;
                        }

                        if (module->data_seg_count1 == 0)
                            goto fail_data_cnt_sec_require;

                        POP_I32();
                        POP_I32();
                        POP_MEM_OFFSET();
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_bulk_memory_used = true;
#endif
                        break;
                    }
                    case WASM_OP_DATA_DROP:
                    {
                        pb_read_leb_uint32(p, p_end, data_seg_idx);
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, data_seg_idx);
#endif
                        if (data_seg_idx >= module->data_seg_count) {
                            set_error_buf(error_buf, error_buf_size,
                                          "unknown data segment");
                            goto fail;
                        }

                        if (module->data_seg_count1 == 0)
                            goto fail_data_cnt_sec_require;

#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_bulk_memory_used = true;
#endif
                        break;
                    }
                    case WASM_OP_MEMORY_COPY:
                    {
                        CHECK_BUF(p, p_end, sizeof(int16));
                        /* check both src and dst memory index */
                        pb_read_leb_uint32(p, p_end, memidx);
                        check_memidx(module, memidx);
                        pb_read_leb_uint32(p, p_end, memidx);
                        check_memidx(module, memidx);

                        if (module->import_memory_count == 0
                            && module->memory_count == 0)
                            goto fail_unknown_memory;

                        POP_MEM_OFFSET();
                        POP_MEM_OFFSET();
                        POP_MEM_OFFSET();
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_bulk_memory_used = true;
#endif
                        break;
                    }
                    case WASM_OP_MEMORY_FILL:
                    {
                        pb_read_leb_uint32(p, p_end, memidx);
                        check_memidx(module, memidx);
                        if (module->import_memory_count == 0
                            && module->memory_count == 0) {
                            goto fail_unknown_memory;
                        }
                        POP_MEM_OFFSET();
                        POP_I32();
                        POP_MEM_OFFSET();
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_bulk_memory_used = true;
#endif
                        break;
                    }

                    fail_unknown_memory:
                        set_error_buf(error_buf, error_buf_size,
                                      "unknown memory 0");
                        goto fail;
                    fail_data_cnt_sec_require:
                        set_error_buf(error_buf, error_buf_size,
                                      "data count section required");
                        goto fail;
#endif /* WASM_ENABLE_BULK_MEMORY */
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
                    case WASM_OP_TABLE_INIT:
                    {
                        uint8 seg_type = 0, tbl_type = 0;
#if WASM_ENABLE_GC != 0
                        WASMRefType *seg_ref_type = NULL, *tbl_ref_type = NULL;
#endif

                        pb_read_leb_uint32(p, p_end, table_seg_idx);
                        pb_read_leb_uint32(p, p_end, table_idx);

                        if (!get_table_elem_type(module, table_idx, &tbl_type,
#if WASM_ENABLE_GC != 0
                                                 (void **)&tbl_ref_type,
#else
                                                 NULL,
#endif
                                                 error_buf, error_buf_size))
                            goto fail;

                        if (!get_table_seg_elem_type(module, table_seg_idx,
                                                     &seg_type,
#if WASM_ENABLE_GC != 0
                                                     (void **)&seg_ref_type,
#else
                                                     NULL,
#endif
                                                     error_buf, error_buf_size))
                            goto fail;

#if WASM_ENABLE_GC == 0
                        if (seg_type != tbl_type) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }
#else
                        if (!wasm_reftype_is_subtype_of(
                                seg_type, seg_ref_type, tbl_type, tbl_ref_type,
                                module->types, module->type_count)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }
#endif

#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, table_seg_idx);
                        emit_uint32(loader_ctx, table_idx);
#endif
                        POP_I32();
                        POP_I32();
#if WASM_ENABLE_MEMORY64 != 0
                        table_elem_idx_type = is_table_64bit(module, table_idx)
                                                  ? VALUE_TYPE_I64
                                                  : VALUE_TYPE_I32;
#endif
                        POP_TBL_ELEM_IDX();

#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_ref_types_used = true;
#endif
                        break;
                    }
                    case WASM_OP_ELEM_DROP:
                    {
                        pb_read_leb_uint32(p, p_end, table_seg_idx);
                        if (!get_table_seg_elem_type(module, table_seg_idx,
                                                     NULL, NULL, error_buf,
                                                     error_buf_size))
                            goto fail;
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, table_seg_idx);
#endif

#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_ref_types_used = true;
#endif
                        break;
                    }
                    case WASM_OP_TABLE_COPY:
                    {
                        uint8 src_type, dst_type, src_tbl_idx_type,
                            dst_tbl_idx_type, min_tbl_idx_type;
#if WASM_ENABLE_GC != 0
                        WASMRefType *src_ref_type = NULL, *dst_ref_type = NULL;
#endif
                        uint32 src_tbl_idx, dst_tbl_idx;

                        pb_read_leb_uint32(p, p_end, dst_tbl_idx);
                        if (!get_table_elem_type(module, dst_tbl_idx, &dst_type,
#if WASM_ENABLE_GC != 0
                                                 (void **)&dst_ref_type,
#else
                                                 NULL,
#endif
                                                 error_buf, error_buf_size))
                            goto fail;

                        pb_read_leb_uint32(p, p_end, src_tbl_idx);
                        if (!get_table_elem_type(module, src_tbl_idx, &src_type,
#if WASM_ENABLE_GC != 0
                                                 (void **)&src_ref_type,
#else
                                                 NULL,
#endif
                                                 error_buf, error_buf_size))
                            goto fail;

#if WASM_ENABLE_GC == 0
                        if (src_type != dst_type) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }
#else
                        if (!wasm_reftype_is_subtype_of(
                                src_type, src_ref_type, dst_type, dst_ref_type,
                                module->types, module->type_count)) {
                            set_error_buf(error_buf, error_buf_size,
                                          "type mismatch");
                            goto fail;
                        }
#endif

#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, dst_tbl_idx);
                        emit_uint32(loader_ctx, src_tbl_idx);
#endif

#if WASM_ENABLE_MEMORY64 != 0
                        src_tbl_idx_type = is_table_64bit(module, src_tbl_idx)
                                               ? VALUE_TYPE_I64
                                               : VALUE_TYPE_I32;
                        dst_tbl_idx_type = is_table_64bit(module, dst_tbl_idx)
                                               ? VALUE_TYPE_I64
                                               : VALUE_TYPE_I32;
                        min_tbl_idx_type =
                            (src_tbl_idx_type == VALUE_TYPE_I32
                             || dst_tbl_idx_type == VALUE_TYPE_I32)
                                ? VALUE_TYPE_I32
                                : VALUE_TYPE_I64;
#else
                        src_tbl_idx_type = VALUE_TYPE_I32;
                        dst_tbl_idx_type = VALUE_TYPE_I32;
                        min_tbl_idx_type = VALUE_TYPE_I32;
#endif

                        table_elem_idx_type = min_tbl_idx_type;
                        POP_TBL_ELEM_IDX();
                        table_elem_idx_type = src_tbl_idx_type;
                        POP_TBL_ELEM_IDX();
                        table_elem_idx_type = dst_tbl_idx_type;
                        POP_TBL_ELEM_IDX();

#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_ref_types_used = true;
#endif
                        break;
                    }
                    case WASM_OP_TABLE_SIZE:
                    {
                        pb_read_leb_uint32(p, p_end, table_idx);
                        /* TODO: shall we create a new function to check
                                 table idx instead of using below function? */
                        if (!get_table_elem_type(module, table_idx, NULL, NULL,
                                                 error_buf, error_buf_size))
                            goto fail;

#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, table_idx);
#endif

#if WASM_ENABLE_MEMORY64 != 0
                        table_elem_idx_type = is_table_64bit(module, table_idx)
                                                  ? VALUE_TYPE_I64
                                                  : VALUE_TYPE_I32;
#endif
                        PUSH_TBL_ELEM_IDX();

#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_ref_types_used = true;
#endif
                        break;
                    }
                    case WASM_OP_TABLE_GROW:
                    case WASM_OP_TABLE_FILL:
                    {
                        uint8 decl_type;
#if WASM_ENABLE_GC != 0
                        WASMRefType *ref_type = NULL;
#endif

                        pb_read_leb_uint32(p, p_end, table_idx);
                        if (!get_table_elem_type(module, table_idx, &decl_type,
#if WASM_ENABLE_GC != 0
                                                 (void **)&ref_type,
#else
                                                 NULL,
#endif
                                                 error_buf, error_buf_size))
                            goto fail;
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_multi_byte_type(decl_type)) {
                            bh_memcpy_s(&wasm_ref_type, sizeof(WASMRefType),
                                        ref_type,
                                        wasm_reftype_struct_size(ref_type));
                        }
#endif

                        if (opcode1 == WASM_OP_TABLE_GROW) {
                            if (table_idx < module->import_table_count) {
                                module->import_tables[table_idx]
                                    .u.table.table_type.possible_grow = true;
                            }
                            else {
                                module
                                    ->tables[table_idx
                                             - module->import_table_count]
                                    .table_type.possible_grow = true;
                            }
                        }

#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, table_idx);
#endif

#if WASM_ENABLE_MEMORY64 != 0
                        table_elem_idx_type = is_table_64bit(module, table_idx)
                                                  ? VALUE_TYPE_I64
                                                  : VALUE_TYPE_I32;
#endif
                        POP_TBL_ELEM_IDX();
#if WASM_ENABLE_FAST_INTERP != 0
                        POP_OFFSET_TYPE(decl_type);
#endif
                        POP_TYPE(decl_type);
                        if (opcode1 == WASM_OP_TABLE_GROW)
                            PUSH_TBL_ELEM_IDX();
                        else
                            POP_TBL_ELEM_IDX();

#if WASM_ENABLE_WAMR_COMPILER != 0
                        module->is_ref_types_used = true;
#endif
                        break;
                    }
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */
                    default:
                        set_error_buf_v(error_buf, error_buf_size,
                                        "%s %02x %02x", "unsupported opcode",
                                        0xfc, opcode1);
                        goto fail;
                }
                break;
            }

#if WASM_ENABLE_SIMD != 0
#if (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) \
    || (WASM_ENABLE_FAST_INTERP != 0)
            case WASM_OP_SIMD_PREFIX:
            {
                uint32 opcode1;

#if WASM_ENABLE_WAMR_COMPILER != 0
                /* Mark the SIMD instruction is used in this module */
                module->is_simd_used = true;
#endif

                pb_read_leb_uint32(p, p_end, opcode1);

#if WASM_ENABLE_FAST_INTERP != 0
                emit_byte(loader_ctx, opcode1);
#endif

                /* follow the order of enum WASMSimdEXTOpcode in wasm_opcode.h
                 */
                switch (opcode1) {
                    /* memory instruction */
                    case SIMD_v128_load:
                    case SIMD_v128_load8x8_s:
                    case SIMD_v128_load8x8_u:
                    case SIMD_v128_load16x4_s:
                    case SIMD_v128_load16x4_u:
                    case SIMD_v128_load32x2_s:
                    case SIMD_v128_load32x2_u:
                    case SIMD_v128_load8_splat:
                    case SIMD_v128_load16_splat:
                    case SIMD_v128_load32_splat:
                    case SIMD_v128_load64_splat:
                    {
                        CHECK_MEMORY();

                        pb_read_leb_uint32(p, p_end, align); /* align */
                        if (!check_simd_memory_access_align(
                                opcode1, align, error_buf, error_buf_size)) {
                            goto fail;
                        }

                        pb_read_leb_mem_offset(p, p_end,
                                               mem_offset); /* offset */

#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, mem_offset);
#endif

                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_V128);
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
                        break;
                    }

                    case SIMD_v128_store:
                    {
                        CHECK_MEMORY();

                        pb_read_leb_uint32(p, p_end, align); /* align */
                        if (!check_simd_memory_access_align(
                                opcode1, align, error_buf, error_buf_size)) {
                            goto fail;
                        }

                        pb_read_leb_mem_offset(p, p_end,
                                               mem_offset); /* offset */

#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, mem_offset);
#endif

                        POP_V128();
                        POP_MEM_OFFSET();
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
                        break;
                    }

                    /* basic operation */
                    case SIMD_v128_const:
                    {
#if WASM_ENABLE_FAST_INTERP != 0
                        uint64 high, low;
#endif
                        CHECK_BUF1(p, p_end, 16);
#if WASM_ENABLE_FAST_INTERP != 0
                        wasm_runtime_read_v128(p, &high, &low);
                        emit_uint64(loader_ctx, high);
                        emit_uint64(loader_ctx, low);
#endif
                        p += 16;
                        PUSH_V128();
                        break;
                    }

                    case SIMD_v8x16_shuffle:
                    {
                        V128 mask;

                        CHECK_BUF1(p, p_end, 16);
                        mask = read_i8x16(p, error_buf, error_buf_size);
                        if (!check_simd_shuffle_mask(mask, error_buf,
                                                     error_buf_size)) {
                            goto fail;
                        }
#if WASM_ENABLE_FAST_INTERP != 0
                        uint64 high, low;
                        wasm_runtime_read_v128(p, &high, &low);
                        emit_uint64(loader_ctx, high);
                        emit_uint64(loader_ctx, low);
#endif
                        p += 16;
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_v8x16_swizzle:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    /* splat operation */
                    case SIMD_i8x16_splat:
                    case SIMD_i16x8_splat:
                    case SIMD_i32x4_splat:
                    case SIMD_i64x2_splat:
                    case SIMD_f32x4_splat:
                    case SIMD_f64x2_splat:
                    {
                        uint8 pop_type[] = { VALUE_TYPE_I32, VALUE_TYPE_I32,
                                             VALUE_TYPE_I32, VALUE_TYPE_I64,
                                             VALUE_TYPE_F32, VALUE_TYPE_F64 };
                        POP_AND_PUSH(pop_type[opcode1 - SIMD_i8x16_splat],
                                     VALUE_TYPE_V128);
                        break;
                    }

                    /* lane operation */
                    case SIMD_i8x16_extract_lane_s:
                    case SIMD_i8x16_extract_lane_u:
                    case SIMD_i8x16_replace_lane:
                    case SIMD_i16x8_extract_lane_s:
                    case SIMD_i16x8_extract_lane_u:
                    case SIMD_i16x8_replace_lane:
                    case SIMD_i32x4_extract_lane:
                    case SIMD_i32x4_replace_lane:
                    case SIMD_i64x2_extract_lane:
                    case SIMD_i64x2_replace_lane:
                    case SIMD_f32x4_extract_lane:
                    case SIMD_f32x4_replace_lane:
                    case SIMD_f64x2_extract_lane:
                    case SIMD_f64x2_replace_lane:
                    {
                        uint8 lane;
                        /* clang-format off */
                        uint8 replace[] = {
                            /*i8x16*/ 0x0, 0x0, VALUE_TYPE_I32,
                            /*i16x8*/ 0x0, 0x0, VALUE_TYPE_I32,
                            /*i32x4*/ 0x0, VALUE_TYPE_I32,
                            /*i64x2*/ 0x0, VALUE_TYPE_I64,
                            /*f32x4*/ 0x0, VALUE_TYPE_F32,
                            /*f64x2*/ 0x0, VALUE_TYPE_F64,
                        };
                        uint8 push_type[] = {
                            /*i8x16*/ VALUE_TYPE_I32, VALUE_TYPE_I32,
                                      VALUE_TYPE_V128,
                            /*i16x8*/ VALUE_TYPE_I32, VALUE_TYPE_I32,
                                      VALUE_TYPE_V128,
                            /*i32x4*/ VALUE_TYPE_I32, VALUE_TYPE_V128,
                            /*i64x2*/ VALUE_TYPE_I64, VALUE_TYPE_V128,
                            /*f32x4*/ VALUE_TYPE_F32, VALUE_TYPE_V128,
                            /*f64x2*/ VALUE_TYPE_F64, VALUE_TYPE_V128,
                        };
                        /* clang-format on */

                        CHECK_BUF(p, p_end, 1);
                        lane = read_uint8(p);
                        if (!check_simd_access_lane(opcode1, lane, error_buf,
                                                    error_buf_size)) {
                            goto fail;
                        }
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_byte(loader_ctx, lane);
#endif
                        if (replace[opcode1 - SIMD_i8x16_extract_lane_s]) {
#if WASM_ENABLE_FAST_INTERP != 0
                            if (!(wasm_loader_pop_frame_ref_offset(
                                    loader_ctx,
                                    replace[opcode1
                                            - SIMD_i8x16_extract_lane_s],
                                    error_buf, error_buf_size)))
                                goto fail;
#else
                            if (!(wasm_loader_pop_frame_ref(
                                    loader_ctx,
                                    replace[opcode1
                                            - SIMD_i8x16_extract_lane_s],
                                    error_buf, error_buf_size)))
                                goto fail;
#endif /* end of WASM_ENABLE_FAST_INTERP != 0 */
                        }

                        POP_AND_PUSH(
                            VALUE_TYPE_V128,
                            push_type[opcode1 - SIMD_i8x16_extract_lane_s]);
                        break;
                    }

                    /* i8x16 compare operation */
                    case SIMD_i8x16_eq:
                    case SIMD_i8x16_ne:
                    case SIMD_i8x16_lt_s:
                    case SIMD_i8x16_lt_u:
                    case SIMD_i8x16_gt_s:
                    case SIMD_i8x16_gt_u:
                    case SIMD_i8x16_le_s:
                    case SIMD_i8x16_le_u:
                    case SIMD_i8x16_ge_s:
                    case SIMD_i8x16_ge_u:
                    /* i16x8 compare operation */
                    case SIMD_i16x8_eq:
                    case SIMD_i16x8_ne:
                    case SIMD_i16x8_lt_s:
                    case SIMD_i16x8_lt_u:
                    case SIMD_i16x8_gt_s:
                    case SIMD_i16x8_gt_u:
                    case SIMD_i16x8_le_s:
                    case SIMD_i16x8_le_u:
                    case SIMD_i16x8_ge_s:
                    case SIMD_i16x8_ge_u:
                    /* i32x4 compare operation */
                    case SIMD_i32x4_eq:
                    case SIMD_i32x4_ne:
                    case SIMD_i32x4_lt_s:
                    case SIMD_i32x4_lt_u:
                    case SIMD_i32x4_gt_s:
                    case SIMD_i32x4_gt_u:
                    case SIMD_i32x4_le_s:
                    case SIMD_i32x4_le_u:
                    case SIMD_i32x4_ge_s:
                    case SIMD_i32x4_ge_u:
                    /* f32x4 compare operation */
                    case SIMD_f32x4_eq:
                    case SIMD_f32x4_ne:
                    case SIMD_f32x4_lt:
                    case SIMD_f32x4_gt:
                    case SIMD_f32x4_le:
                    case SIMD_f32x4_ge:
                    /* f64x2 compare operation */
                    case SIMD_f64x2_eq:
                    case SIMD_f64x2_ne:
                    case SIMD_f64x2_lt:
                    case SIMD_f64x2_gt:
                    case SIMD_f64x2_le:
                    case SIMD_f64x2_ge:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    /* v128 operation */
                    case SIMD_v128_not:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_v128_and:
                    case SIMD_v128_andnot:
                    case SIMD_v128_or:
                    case SIMD_v128_xor:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_v128_bitselect:
                    {
                        POP_V128();
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_v128_any_true:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_I32);
                        break;
                    }

                    /* Load Lane Operation */
                    case SIMD_v128_load8_lane:
                    case SIMD_v128_load16_lane:
                    case SIMD_v128_load32_lane:
                    case SIMD_v128_load64_lane:
                    case SIMD_v128_store8_lane:
                    case SIMD_v128_store16_lane:
                    case SIMD_v128_store32_lane:
                    case SIMD_v128_store64_lane:
                    {
                        uint8 lane;

                        CHECK_MEMORY();

                        pb_read_leb_uint32(p, p_end, align); /* align */
                        if (!check_simd_memory_access_align(
                                opcode1, align, error_buf, error_buf_size)) {
                            goto fail;
                        }

                        pb_read_leb_mem_offset(p, p_end,
                                               mem_offset); /* offset */

                        CHECK_BUF(p, p_end, 1);
                        lane = read_uint8(p);
                        if (!check_simd_access_lane(opcode1, lane, error_buf,
                                                    error_buf_size)) {
                            goto fail;
                        }
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, mem_offset);
#endif
                        POP_V128();
                        POP_MEM_OFFSET();
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_byte(loader_ctx, lane);
#endif
                        if (opcode1 < SIMD_v128_store8_lane) {
                            PUSH_V128();
                        }
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
                        break;
                    }

                    case SIMD_v128_load32_zero:
                    case SIMD_v128_load64_zero:
                    {
                        CHECK_MEMORY();

                        pb_read_leb_uint32(p, p_end, align); /* align */
                        if (!check_simd_memory_access_align(
                                opcode1, align, error_buf, error_buf_size)) {
                            goto fail;
                        }

                        pb_read_leb_mem_offset(p, p_end,
                                               mem_offset); /* offset */
#if WASM_ENABLE_FAST_INTERP != 0
                        emit_uint32(loader_ctx, mem_offset);
#endif
                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_V128);
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                        func->has_memory_operations = true;
#endif
                        break;
                    }

                    /* Float conversion */
                    case SIMD_f32x4_demote_f64x2_zero:
                    case SIMD_f64x2_promote_low_f32x4_zero:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    /* i8x16 Operation */
                    case SIMD_i8x16_abs:
                    case SIMD_i8x16_neg:
                    case SIMD_i8x16_popcnt:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i8x16_all_true:
                    case SIMD_i8x16_bitmask:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_I32);
                        break;
                    }

                    case SIMD_i8x16_narrow_i16x8_s:
                    case SIMD_i8x16_narrow_i16x8_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_f32x4_ceil:
                    case SIMD_f32x4_floor:
                    case SIMD_f32x4_trunc:
                    case SIMD_f32x4_nearest:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i8x16_shl:
                    case SIMD_i8x16_shr_s:
                    case SIMD_i8x16_shr_u:
                    {
                        POP_I32();
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i8x16_add:
                    case SIMD_i8x16_add_sat_s:
                    case SIMD_i8x16_add_sat_u:
                    case SIMD_i8x16_sub:
                    case SIMD_i8x16_sub_sat_s:
                    case SIMD_i8x16_sub_sat_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_f64x2_ceil:
                    case SIMD_f64x2_floor:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i8x16_min_s:
                    case SIMD_i8x16_min_u:
                    case SIMD_i8x16_max_s:
                    case SIMD_i8x16_max_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_f64x2_trunc:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i8x16_avgr_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i16x8_extadd_pairwise_i8x16_s:
                    case SIMD_i16x8_extadd_pairwise_i8x16_u:
                    case SIMD_i32x4_extadd_pairwise_i16x8_s:
                    case SIMD_i32x4_extadd_pairwise_i16x8_u:
                    /* i16x8 operation */
                    case SIMD_i16x8_abs:
                    case SIMD_i16x8_neg:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i16x8_q15mulr_sat_s:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i16x8_all_true:
                    case SIMD_i16x8_bitmask:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_I32);
                        break;
                    }

                    case SIMD_i16x8_narrow_i32x4_s:
                    case SIMD_i16x8_narrow_i32x4_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i16x8_extend_low_i8x16_s:
                    case SIMD_i16x8_extend_high_i8x16_s:
                    case SIMD_i16x8_extend_low_i8x16_u:
                    case SIMD_i16x8_extend_high_i8x16_u:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i16x8_shl:
                    case SIMD_i16x8_shr_s:
                    case SIMD_i16x8_shr_u:
                    {
                        POP_I32();
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i16x8_add:
                    case SIMD_i16x8_add_sat_s:
                    case SIMD_i16x8_add_sat_u:
                    case SIMD_i16x8_sub:
                    case SIMD_i16x8_sub_sat_s:
                    case SIMD_i16x8_sub_sat_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_f64x2_nearest:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i16x8_mul:
                    case SIMD_i16x8_min_s:
                    case SIMD_i16x8_min_u:
                    case SIMD_i16x8_max_s:
                    case SIMD_i16x8_max_u:
                    case SIMD_i16x8_avgr_u:
                    case SIMD_i16x8_extmul_low_i8x16_s:
                    case SIMD_i16x8_extmul_high_i8x16_s:
                    case SIMD_i16x8_extmul_low_i8x16_u:
                    case SIMD_i16x8_extmul_high_i8x16_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    /* i32x4 operation */
                    case SIMD_i32x4_abs:
                    case SIMD_i32x4_neg:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i32x4_all_true:
                    case SIMD_i32x4_bitmask:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_I32);
                        break;
                    }

                    case SIMD_i32x4_extend_low_i16x8_s:
                    case SIMD_i32x4_extend_high_i16x8_s:
                    case SIMD_i32x4_extend_low_i16x8_u:
                    case SIMD_i32x4_extend_high_i16x8_u:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i32x4_shl:
                    case SIMD_i32x4_shr_s:
                    case SIMD_i32x4_shr_u:
                    {
                        POP_I32();
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i32x4_add:
                    case SIMD_i32x4_sub:
                    case SIMD_i32x4_mul:
                    case SIMD_i32x4_min_s:
                    case SIMD_i32x4_min_u:
                    case SIMD_i32x4_max_s:
                    case SIMD_i32x4_max_u:
                    case SIMD_i32x4_dot_i16x8_s:
                    case SIMD_i32x4_extmul_low_i16x8_s:
                    case SIMD_i32x4_extmul_high_i16x8_s:
                    case SIMD_i32x4_extmul_low_i16x8_u:
                    case SIMD_i32x4_extmul_high_i16x8_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    /* i64x2 operation */
                    case SIMD_i64x2_abs:
                    case SIMD_i64x2_neg:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i64x2_all_true:
                    case SIMD_i64x2_bitmask:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_I32);
                        break;
                    }

                    case SIMD_i64x2_extend_low_i32x4_s:
                    case SIMD_i64x2_extend_high_i32x4_s:
                    case SIMD_i64x2_extend_low_i32x4_u:
                    case SIMD_i64x2_extend_high_i32x4_u:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i64x2_shl:
                    case SIMD_i64x2_shr_s:
                    case SIMD_i64x2_shr_u:
                    {
                        POP_I32();
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i64x2_add:
                    case SIMD_i64x2_sub:
                    case SIMD_i64x2_mul:
                    case SIMD_i64x2_eq:
                    case SIMD_i64x2_ne:
                    case SIMD_i64x2_lt_s:
                    case SIMD_i64x2_gt_s:
                    case SIMD_i64x2_le_s:
                    case SIMD_i64x2_ge_s:
                    case SIMD_i64x2_extmul_low_i32x4_s:
                    case SIMD_i64x2_extmul_high_i32x4_s:
                    case SIMD_i64x2_extmul_low_i32x4_u:
                    case SIMD_i64x2_extmul_high_i32x4_u:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    /* f32x4 operation */
                    case SIMD_f32x4_abs:
                    case SIMD_f32x4_neg:
                    case SIMD_f32x4_sqrt:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_f32x4_add:
                    case SIMD_f32x4_sub:
                    case SIMD_f32x4_mul:
                    case SIMD_f32x4_div:
                    case SIMD_f32x4_min:
                    case SIMD_f32x4_max:
                    case SIMD_f32x4_pmin:
                    case SIMD_f32x4_pmax:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    /* f64x2 operation */
                    case SIMD_f64x2_abs:
                    case SIMD_f64x2_neg:
                    case SIMD_f64x2_sqrt:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_f64x2_add:
                    case SIMD_f64x2_sub:
                    case SIMD_f64x2_mul:
                    case SIMD_f64x2_div:
                    case SIMD_f64x2_min:
                    case SIMD_f64x2_max:
                    case SIMD_f64x2_pmin:
                    case SIMD_f64x2_pmax:
                    {
                        POP2_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    case SIMD_i32x4_trunc_sat_f32x4_s:
                    case SIMD_i32x4_trunc_sat_f32x4_u:
                    case SIMD_f32x4_convert_i32x4_s:
                    case SIMD_f32x4_convert_i32x4_u:
                    case SIMD_i32x4_trunc_sat_f64x2_s_zero:
                    case SIMD_i32x4_trunc_sat_f64x2_u_zero:
                    case SIMD_f64x2_convert_low_i32x4_s:
                    case SIMD_f64x2_convert_low_i32x4_u:
                    {
                        POP_AND_PUSH(VALUE_TYPE_V128, VALUE_TYPE_V128);
                        break;
                    }

                    default:
                    {
                        if (error_buf != NULL) {
                            snprintf(error_buf, error_buf_size,
                                     "WASM module load failed: "
                                     "invalid opcode 0xfd %02x.",
                                     opcode1);
                        }
                        goto fail;
                    }
                }
                break;
            }
#endif /* end of (WASM_ENABLE_WAMR_COMPILER != 0) || (WASM_ENABLE_JIT != 0) || \
          (WASM_ENABLE_FAST_INTERP != 0) */
#endif /* end of WASM_ENABLE_SIMD */

#if WASM_ENABLE_SHARED_MEMORY != 0
            case WASM_OP_ATOMIC_PREFIX:
            {
                uint32 opcode1;

                pb_read_leb_uint32(p, p_end, opcode1);

#if WASM_ENABLE_FAST_INTERP != 0
                emit_byte(loader_ctx, opcode1);
#endif
                if (opcode1 != WASM_OP_ATOMIC_FENCE) {
                    CHECK_MEMORY();
                    pb_read_leb_uint32(p, p_end, align);          /* align */
                    pb_read_leb_mem_offset(p, p_end, mem_offset); /* offset */
                    if (!check_memory_align_equal(opcode1, align, error_buf,
                                                  error_buf_size)) {
                        goto fail;
                    }
#if WASM_ENABLE_FAST_INTERP != 0
                    emit_uint32(loader_ctx, mem_offset);
#endif
                }
#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0
                func->has_memory_operations = true;
#endif
                switch (opcode1) {
                    case WASM_OP_ATOMIC_NOTIFY:
                        POP_I32();
                        POP_MEM_OFFSET();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_WAIT32:
                        POP_I64();
                        POP_I32();
                        POP_MEM_OFFSET();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_WAIT64:
                        POP_I64();
                        POP_I64();
                        POP_MEM_OFFSET();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_FENCE:
                        /* reserved byte 0x00 */
                        if (*p++ != 0x00) {
                            set_error_buf(error_buf, error_buf_size,
                                          "zero byte expected");
                            goto fail;
                        }
                        break;
                    case WASM_OP_ATOMIC_I32_LOAD:
                    case WASM_OP_ATOMIC_I32_LOAD8_U:
                    case WASM_OP_ATOMIC_I32_LOAD16_U:
                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_I32);
                        break;
                    case WASM_OP_ATOMIC_I32_STORE:
                    case WASM_OP_ATOMIC_I32_STORE8:
                    case WASM_OP_ATOMIC_I32_STORE16:
                        POP_I32();
                        POP_MEM_OFFSET();
                        break;
                    case WASM_OP_ATOMIC_I64_LOAD:
                    case WASM_OP_ATOMIC_I64_LOAD8_U:
                    case WASM_OP_ATOMIC_I64_LOAD16_U:
                    case WASM_OP_ATOMIC_I64_LOAD32_U:
                        POP_AND_PUSH(mem_offset_type, VALUE_TYPE_I64);
                        break;
                    case WASM_OP_ATOMIC_I64_STORE:
                    case WASM_OP_ATOMIC_I64_STORE8:
                    case WASM_OP_ATOMIC_I64_STORE16:
                    case WASM_OP_ATOMIC_I64_STORE32:
                        POP_I64();
                        POP_MEM_OFFSET();
                        break;
                    case WASM_OP_ATOMIC_RMW_I32_ADD:
                    case WASM_OP_ATOMIC_RMW_I32_ADD8_U:
                    case WASM_OP_ATOMIC_RMW_I32_ADD16_U:
                    case WASM_OP_ATOMIC_RMW_I32_SUB:
                    case WASM_OP_ATOMIC_RMW_I32_SUB8_U:
                    case WASM_OP_ATOMIC_RMW_I32_SUB16_U:
                    case WASM_OP_ATOMIC_RMW_I32_AND:
                    case WASM_OP_ATOMIC_RMW_I32_AND8_U:
                    case WASM_OP_ATOMIC_RMW_I32_AND16_U:
                    case WASM_OP_ATOMIC_RMW_I32_OR:
                    case WASM_OP_ATOMIC_RMW_I32_OR8_U:
                    case WASM_OP_ATOMIC_RMW_I32_OR16_U:
                    case WASM_OP_ATOMIC_RMW_I32_XOR:
                    case WASM_OP_ATOMIC_RMW_I32_XOR8_U:
                    case WASM_OP_ATOMIC_RMW_I32_XOR16_U:
                    case WASM_OP_ATOMIC_RMW_I32_XCHG:
                    case WASM_OP_ATOMIC_RMW_I32_XCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I32_XCHG16_U:
                        POP_I32();
                        POP_MEM_OFFSET();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_RMW_I64_ADD:
                    case WASM_OP_ATOMIC_RMW_I64_ADD8_U:
                    case WASM_OP_ATOMIC_RMW_I64_ADD16_U:
                    case WASM_OP_ATOMIC_RMW_I64_ADD32_U:
                    case WASM_OP_ATOMIC_RMW_I64_SUB:
                    case WASM_OP_ATOMIC_RMW_I64_SUB8_U:
                    case WASM_OP_ATOMIC_RMW_I64_SUB16_U:
                    case WASM_OP_ATOMIC_RMW_I64_SUB32_U:
                    case WASM_OP_ATOMIC_RMW_I64_AND:
                    case WASM_OP_ATOMIC_RMW_I64_AND8_U:
                    case WASM_OP_ATOMIC_RMW_I64_AND16_U:
                    case WASM_OP_ATOMIC_RMW_I64_AND32_U:
                    case WASM_OP_ATOMIC_RMW_I64_OR:
                    case WASM_OP_ATOMIC_RMW_I64_OR8_U:
                    case WASM_OP_ATOMIC_RMW_I64_OR16_U:
                    case WASM_OP_ATOMIC_RMW_I64_OR32_U:
                    case WASM_OP_ATOMIC_RMW_I64_XOR:
                    case WASM_OP_ATOMIC_RMW_I64_XOR8_U:
                    case WASM_OP_ATOMIC_RMW_I64_XOR16_U:
                    case WASM_OP_ATOMIC_RMW_I64_XOR32_U:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG16_U:
                    case WASM_OP_ATOMIC_RMW_I64_XCHG32_U:
                        POP_I64();
                        POP_MEM_OFFSET();
                        PUSH_I64();
                        break;
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U:
                        POP_I32();
                        POP_I32();
                        POP_MEM_OFFSET();
                        PUSH_I32();
                        break;
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U:
                        POP_I64();
                        POP_I64();
                        POP_MEM_OFFSET();
                        PUSH_I64();
                        break;
                    default:
                        set_error_buf_v(error_buf, error_buf_size,
                                        "%s %02x %02x", "unsupported opcode",
                                        0xfe, opcode1);
                        goto fail;
                }
                break;
            }
#endif /* end of WASM_ENABLE_SHARED_MEMORY */

            default:
                set_error_buf_v(error_buf, error_buf_size, "%s %02x",
                                "unsupported opcode", opcode);
                goto fail;
        }

#if WASM_ENABLE_FAST_INTERP != 0
        last_op = opcode;
#endif
    }

    if (loader_ctx->csp_num > 0) {
        /* unmatched end opcodes result from unbalanced control flow structures,
         * for example, br_table with inconsistent target count (1 declared, 2
         * given), or simply superfluous end opcodes */
        set_error_buf(
            error_buf, error_buf_size,
            "unexpected end opcodes from unbalanced control flow structures");
        goto fail;
    }

#if WASM_ENABLE_FAST_INTERP != 0
    if (loader_ctx->p_code_compiled == NULL)
        goto re_scan;

    func->const_cell_num = loader_ctx->i64_const_num * 2
                           + loader_ctx->v128_const_num * 4
                           + loader_ctx->i32_const_num;
    if (func->const_cell_num > 0) {
        if (!(func->consts =
                  loader_malloc((uint64)sizeof(uint32) * func->const_cell_num,
                                error_buf, error_buf_size)))
            goto fail;
        if (loader_ctx->i64_const_num > 0) {
            bh_memcpy_s(func->consts,
                        (uint32)sizeof(int64) * loader_ctx->i64_const_num,
                        loader_ctx->i64_consts,
                        (uint32)sizeof(int64) * loader_ctx->i64_const_num);
        }
        if (loader_ctx->i32_const_num > 0) {
            bh_memcpy_s(func->consts
                            + sizeof(int64) * loader_ctx->i64_const_num,
                        (uint32)sizeof(int32) * loader_ctx->i32_const_num,
                        loader_ctx->i32_consts,
                        (uint32)sizeof(int32) * loader_ctx->i32_const_num);
        }
        if (loader_ctx->v128_const_num > 0) {
            bh_memcpy_s(func->consts,
                        (uint32)sizeof(V128) * loader_ctx->v128_const_num,
                        loader_ctx->v128_consts,
                        (uint32)sizeof(V128) * loader_ctx->v128_const_num);
        }
    }

    func->max_stack_cell_num = loader_ctx->preserved_local_offset
                               - loader_ctx->start_dynamic_offset + 1;
#else
    func->max_stack_cell_num = loader_ctx->max_stack_cell_num;
#endif
    func->max_block_num = loader_ctx->max_csp_num;
    return_value = true;

fail:
    wasm_loader_ctx_destroy(loader_ctx);

    (void)table_idx;
    (void)table_seg_idx;
    (void)data_seg_idx;
    (void)i64_const;
    (void)local_offset;
    (void)p_org;
    (void)mem_offset;
    (void)align;
    return return_value;
}
