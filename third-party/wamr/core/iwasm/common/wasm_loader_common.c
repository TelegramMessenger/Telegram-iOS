/*
 * Copyright (C) 2024 Amazon Inc.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
#include "wasm_loader_common.h"
#include "bh_leb128.h"
#include "bh_log.h"
#if WASM_ENABLE_GC != 0
#include "../common/gc/gc_type.h"
#endif

void
wasm_loader_set_error_buf(char *error_buf, uint32 error_buf_size,
                          const char *string, bool is_aot)
{
    if (error_buf != NULL) {
        snprintf(error_buf, error_buf_size, "%s module load failed: %s",
                 is_aot ? "AOT" : "WASM", string);
    }
}

#if WASM_ENABLE_MEMORY64 != 0
bool
check_memory64_flags_consistency(WASMModule *module, char *error_buf,
                                 uint32 error_buf_size, bool is_aot)
{
    uint32 i;
    bool wasm64_flag, all_wasm64 = true, none_wasm64 = true;

    for (i = 0; i < module->import_memory_count; ++i) {
        wasm64_flag =
            module->import_memories[i].u.memory.mem_type.flags & MEMORY64_FLAG;
        all_wasm64 &= wasm64_flag;
        none_wasm64 &= !wasm64_flag;
    }

    for (i = 0; i < module->memory_count; ++i) {
        wasm64_flag = module->memories[i].flags & MEMORY64_FLAG;
        all_wasm64 &= wasm64_flag;
        none_wasm64 &= !wasm64_flag;
    }

    if (!(all_wasm64 || none_wasm64)) {
        wasm_loader_set_error_buf(
            error_buf, error_buf_size,
            "inconsistent limits wasm64 flags for memory sections", is_aot);
        return false;
    }
    return true;
}
#endif

bool
wasm_memory_check_flags(const uint8 mem_flag, char *error_buf,
                        uint32 error_buf_size, bool is_aot)
{
    /* Check whether certain features indicated by mem_flag are enabled in
     * runtime */
    if (mem_flag > MAX_PAGE_COUNT_FLAG) {
#if WASM_ENABLE_SHARED_MEMORY == 0
        if (mem_flag & SHARED_MEMORY_FLAG) {
            LOG_VERBOSE("shared memory flag was found, please enable shared "
                        "memory, lib-pthread or lib-wasi-threads");
            wasm_loader_set_error_buf(error_buf, error_buf_size,
                                      "invalid limits flags", is_aot);
            return false;
        }
#endif
#if WASM_ENABLE_MEMORY64 == 0
        if (mem_flag & MEMORY64_FLAG) {
            LOG_VERBOSE("memory64 flag was found, please enable memory64");
            wasm_loader_set_error_buf(error_buf, error_buf_size,
                                      "invalid limits flags", is_aot);
            return false;
        }
#endif
    }

    if (mem_flag > MAX_PAGE_COUNT_FLAG + SHARED_MEMORY_FLAG + MEMORY64_FLAG) {
        wasm_loader_set_error_buf(error_buf, error_buf_size,
                                  "invalid limits flags", is_aot);
        return false;
    }
    else if ((mem_flag & SHARED_MEMORY_FLAG)
             && !(mem_flag & MAX_PAGE_COUNT_FLAG)) {
        wasm_loader_set_error_buf(error_buf, error_buf_size,
                                  "shared memory must have maximum", is_aot);
        return false;
    }

    return true;
}

bool
wasm_table_check_flags(const uint8 table_flag, char *error_buf,
                       uint32 error_buf_size, bool is_aot)
{
    /* Check whether certain features indicated by mem_flag are enabled in
     * runtime */
    if (table_flag > MAX_TABLE_SIZE_FLAG) {
        if (table_flag & SHARED_TABLE_FLAG) {
            wasm_loader_set_error_buf(error_buf, error_buf_size,
                                      "tables cannot be shared", is_aot);
        }
#if WASM_ENABLE_MEMORY64 == 0
        if (table_flag & TABLE64_FLAG) {
            wasm_loader_set_error_buf(error_buf, error_buf_size,
                                      "invalid limits flags(table64 flag was "
                                      "found, please enable memory64)",
                                      is_aot);
            return false;
        }
#endif
    }

    if (table_flag > MAX_TABLE_SIZE_FLAG + TABLE64_FLAG) {
        wasm_loader_set_error_buf(error_buf, error_buf_size,
                                  "invalid limits flags", is_aot);
        return false;
    }

    return true;
}

/*
 * compare with a bigger type set in `wasm_value_type_size_internal()`,
 * this function will only cover global value type, function's param
 * value type and function's result value type.
 *
 * please feel free to add more if there are more requirements
 */
bool
is_valid_value_type(uint8 type)
{
    if (/* I32/I64/F32/F64, 0x7C to 0x7F */
        (type >= VALUE_TYPE_F64 && type <= VALUE_TYPE_I32)
#if WASM_ENABLE_GC != 0
        /* reference types, 0x65 to 0x70 */
        || wasm_is_type_reftype(type)
#elif WASM_ENABLE_REF_TYPES != 0
        || (type == VALUE_TYPE_FUNCREF || type == VALUE_TYPE_EXTERNREF)
#endif
#if WASM_ENABLE_SIMD != 0
        || type == VALUE_TYPE_V128 /* 0x7B */
#endif
    )
        return true;
    return false;
}

bool
is_valid_value_type_for_interpreter(uint8 value_type)
{
#if (WASM_ENABLE_WAMR_COMPILER == 0) && (WASM_ENABLE_JIT == 0) \
    && (WASM_ENABLE_SIMDE == 0)
    /*
     * Note: regardless of WASM_ENABLE_SIMD, our classic interpreters don't
     * have SIMD implemented.
     *
     * WASM_ENABLE_SIMDE is used to control SIMD feaure in fast interpreter
     */
    if (value_type == VALUE_TYPE_V128)
        return false;
#endif
    return is_valid_value_type(value_type);
}

bool
is_valid_func_type(const WASMFuncType *func_type)
{
    unsigned i;
    for (i = 0;
         i < (unsigned)(func_type->param_count + func_type->result_count);
         i++) {
        if (!is_valid_value_type(func_type->types[i]))
            return false;
    }

    return true;
}

/*
 * Indices are represented as a u32.
 */
bool
is_indices_overflow(uint32 import, uint32 other, char *error_buf,
                    uint32 error_buf_size)
{
    if (import > UINT32_MAX - other) {
        snprintf(error_buf, error_buf_size,
                 "too many items in the index space(%" PRIu32 "+%" PRIu32 ").",
                 import, other);
        return true;
    }

    return false;
}

bool
read_leb(uint8 **p_buf, const uint8 *buf_end, uint32 maxbits, bool sign,
         uint64 *p_result, char *error_buf, uint32 error_buf_size)
{
    size_t offset = 0;
    bh_leb_read_status_t status =
        bh_leb_read(*p_buf, buf_end, maxbits, sign, p_result, &offset);

    switch (status) {
        case BH_LEB_READ_SUCCESS:
            *p_buf += offset;
            return true;
        case BH_LEB_READ_TOO_LONG:
            wasm_loader_set_error_buf(error_buf, error_buf_size,
                                      "integer representation too long", false);
            return false;
        case BH_LEB_READ_OVERFLOW:
            wasm_loader_set_error_buf(error_buf, error_buf_size,
                                      "integer too large", false);
            return false;
        case BH_LEB_READ_UNEXPECTED_END:
            wasm_loader_set_error_buf(error_buf, error_buf_size,
                                      "unexpected end", false);
            return false;
        default:
            bh_assert(false);
            return false;
    }
}

#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
void
destroy_init_expr_recursive(InitializerExpression *expr)
{
    if (expr == NULL) {
        return;
    }
    if (is_expr_binary_op(expr->init_expr_type)) {
        destroy_init_expr_recursive(expr->u.binary.l_expr);
        destroy_init_expr_recursive(expr->u.binary.r_expr);
    }
    wasm_runtime_free(expr);
}
#endif /* end of WASM_ENABLE_EXTENDED_CONST_EXPR != 0 */
