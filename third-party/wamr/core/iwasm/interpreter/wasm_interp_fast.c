/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "wasm_interp.h"
#include "bh_log.h"
#include "wasm_runtime.h"
#include "wasm_opcode.h"
#include "wasm_loader.h"
#include "wasm_memory.h"
#include "../common/wasm_exec_env.h"
#if WASM_ENABLE_GC != 0
#include "../common/gc/gc_object.h"
#include "mem_alloc.h"
#if WASM_ENABLE_STRINGREF != 0
#include "string_object.h"
#endif
#endif
#if WASM_ENABLE_SHARED_MEMORY != 0
#include "../common/wasm_shared_memory.h"
#endif

#if WASM_ENABLE_SIMDE != 0
#include "simde/wasm/simd128.h"
#endif

typedef int32 CellType_I32;
typedef int64 CellType_I64;
typedef float32 CellType_F32;
typedef float64 CellType_F64;

#if WASM_ENABLE_THREAD_MGR == 0
#define get_linear_mem_size() linear_mem_size
#else
/**
 * Load memory data size in each time boundary check in
 * multi-threading mode since it may be changed by other
 * threads in memory.grow
 */
#define get_linear_mem_size() GET_LINEAR_MEMORY_SIZE(memory)
#endif

#if !defined(OS_ENABLE_HW_BOUND_CHECK) \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
#define CHECK_MEMORY_OVERFLOW(bytes)                                           \
    do {                                                                       \
        uint64 offset1 = (uint64)offset + (uint64)addr;                        \
        CHECK_SHARED_HEAP_OVERFLOW(offset1, bytes, maddr)                      \
        if (disable_bounds_checks || offset1 + bytes <= get_linear_mem_size()) \
            /* If offset1 is in valid range, maddr must also                   \
                be in valid range, no need to check it again. */               \
            maddr = memory->memory_data + offset1;                             \
        else                                                                   \
            goto out_of_bounds;                                                \
    } while (0)

#define CHECK_BULK_MEMORY_OVERFLOW(start, bytes, maddr)                        \
    do {                                                                       \
        uint64 offset1 = (uint32)(start);                                      \
        CHECK_SHARED_HEAP_OVERFLOW(offset1, bytes, maddr)                      \
        if (disable_bounds_checks || offset1 + bytes <= get_linear_mem_size()) \
            /* App heap space is not valid space for                           \
               bulk memory operation */                                        \
            maddr = memory->memory_data + offset1;                             \
        else                                                                   \
            goto out_of_bounds;                                                \
    } while (0)
#else
#define CHECK_MEMORY_OVERFLOW(bytes)                      \
    do {                                                  \
        uint64 offset1 = (uint64)offset + (uint64)addr;   \
        CHECK_SHARED_HEAP_OVERFLOW(offset1, bytes, maddr) \
        maddr = memory->memory_data + offset1;            \
    } while (0)

#define CHECK_BULK_MEMORY_OVERFLOW(start, bytes, maddr)   \
    do {                                                  \
        uint64 offset1 = (uint32)(start);                 \
        CHECK_SHARED_HEAP_OVERFLOW(offset1, bytes, maddr) \
        maddr = memory->memory_data + offset1;            \
    } while (0)
#endif /* !defined(OS_ENABLE_HW_BOUND_CHECK) \
          || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 */

#define CHECK_ATOMIC_MEMORY_ACCESS(align)          \
    do {                                           \
        if (((uintptr_t)maddr & (align - 1)) != 0) \
            goto unaligned_atomic;                 \
    } while (0)

#if WASM_ENABLE_INSTRUCTION_METERING != 0
#define CHECK_INSTRUCTION_LIMIT()                                 \
    if (instructions_left == 0) {                                 \
        wasm_set_exception(module, "instruction limit exceeded"); \
        goto got_exception;                                       \
    }                                                             \
    else if (instructions_left > 0)                               \
        instructions_left--;

#else
#define CHECK_INSTRUCTION_LIMIT() (void)0
#endif

static inline uint32
rotl32(uint32 n, uint32 c)
{
    const uint32 mask = (31);
    c = c % 32;
    c &= mask;
    return (n << c) | (n >> ((0 - c) & mask));
}

static inline uint32
rotr32(uint32 n, uint32 c)
{
    const uint32 mask = (31);
    c = c % 32;
    c &= mask;
    return (n >> c) | (n << ((0 - c) & mask));
}

static inline uint64
rotl64(uint64 n, uint64 c)
{
    const uint64 mask = (63);
    c = c % 64;
    c &= mask;
    return (n << c) | (n >> ((0 - c) & mask));
}

static inline uint64
rotr64(uint64 n, uint64 c)
{
    const uint64 mask = (63);
    c = c % 64;
    c &= mask;
    return (n >> c) | (n << ((0 - c) & mask));
}

static inline float32
f32_min(float32 a, float32 b)
{
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

static inline float32
f32_max(float32 a, float32 b)
{
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

static inline float64
f64_min(float64 a, float64 b)
{
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? a : b;
    else
        return a > b ? b : a;
}

static inline float64
f64_max(float64 a, float64 b)
{
    if (isnan(a) || isnan(b))
        return NAN;
    else if (a == 0 && a == b)
        return signbit(a) ? b : a;
    else
        return a > b ? a : b;
}

static inline uint32
clz32(uint32 type)
{
    uint32 num = 0;
    if (type == 0)
        return 32;
    while (!(type & 0x80000000)) {
        num++;
        type <<= 1;
    }
    return num;
}

static inline uint32
clz64(uint64 type)
{
    uint32 num = 0;
    if (type == 0)
        return 64;
    while (!(type & 0x8000000000000000LL)) {
        num++;
        type <<= 1;
    }
    return num;
}

static inline uint32
ctz32(uint32 type)
{
    uint32 num = 0;
    if (type == 0)
        return 32;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

static inline uint32
ctz64(uint64 type)
{
    uint32 num = 0;
    if (type == 0)
        return 64;
    while (!(type & 1)) {
        num++;
        type >>= 1;
    }
    return num;
}

static inline uint32
popcount32(uint32 u)
{
    uint32 ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

static inline uint32
popcount64(uint64 u)
{
    uint32 ret = 0;
    while (u) {
        u = (u & (u - 1));
        ret++;
    }
    return ret;
}

static float
local_copysignf(float x, float y)
{
    union {
        float f;
        uint32 i;
    } ux = { x }, uy = { y };
    ux.i &= 0x7fffffff;
    ux.i |= uy.i & 0x80000000;
    return ux.f;
}

static double
local_copysign(double x, double y)
{
    union {
        double f;
        uint64 i;
    } ux = { x }, uy = { y };
    ux.i &= UINT64_MAX / 2;
    ux.i |= uy.i & 1ULL << 63;
    return ux.f;
}

#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
#define LOAD_U32_WITH_2U16S(addr) (*(uint32 *)(addr))
#define LOAD_PTR(addr) (*(void **)(addr))
#else /* else of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
static inline uint32
LOAD_U32_WITH_2U16S(void *addr)
{
    union {
        uint32 val;
        uint16 u16[2];
    } u;

    bh_assert(((uintptr_t)addr & 1) == 0);
    u.u16[0] = ((uint16 *)addr)[0];
    u.u16[1] = ((uint16 *)addr)[1];
    return u.val;
}
#if UINTPTR_MAX == UINT32_MAX
#define LOAD_PTR(addr) ((void *)LOAD_U32_WITH_2U16S(addr))
#elif UINTPTR_MAX == UINT64_MAX
static inline void *
LOAD_PTR(void *addr)
{
    uintptr_t addr1 = (uintptr_t)addr;
    union {
        void *val;
        uint32 u32[2];
        uint16 u16[4];
    } u;

    bh_assert(((uintptr_t)addr & 1) == 0);
    if ((addr1 & (uintptr_t)7) == 0)
        return *(void **)addr;

    if ((addr1 & (uintptr_t)3) == 0) {
        u.u32[0] = ((uint32 *)addr)[0];
        u.u32[1] = ((uint32 *)addr)[1];
    }
    else {
        u.u16[0] = ((uint16 *)addr)[0];
        u.u16[1] = ((uint16 *)addr)[1];
        u.u16[2] = ((uint16 *)addr)[2];
        u.u16[3] = ((uint16 *)addr)[3];
    }
    return u.val;
}
#endif /* end of UINTPTR_MAX */
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */

#if WASM_ENABLE_GC != 0
static void
init_frame_refs(uint8 *frame_ref, uint32 cell_num, WASMFunctionInstance *func)
{
    uint32 i, j;

    memset(frame_ref, 0, cell_num);

    for (i = 0, j = 0; i < func->param_count; i++) {
        if (wasm_is_type_reftype(func->param_types[i])
            && !wasm_is_reftype_i31ref(func->param_types[i])) {
            frame_ref[j++] = 1;
#if UINTPTR_MAX == UINT64_MAX
            frame_ref[j++] = 1;
#endif
        }
        else {
            j += wasm_value_type_cell_num(func->param_types[i]);
        }
    }

    for (i = 0; i < func->local_count; i++) {
        if (wasm_is_type_reftype(func->local_types[i])
            && !wasm_is_reftype_i31ref(func->local_types[i])) {
            frame_ref[j++] = 1;
#if UINTPTR_MAX == UINT64_MAX
            frame_ref[j++] = 1;
#endif
        }
        else {
            j += wasm_value_type_cell_num(func->local_types[i]);
        }
    }
}

uint8 *
wasm_interp_get_frame_ref(WASMInterpFrame *frame)
{
    return frame->frame_ref;
}

/* Return the corresponding ref slot of the given slot of local
   variable or stack pointer. */

#define COMPUTE_FRAME_REF(ref, off) (ref + (unsigned)(off))

#define FRAME_REF(off) COMPUTE_FRAME_REF(frame_ref, off)

#if UINTPTR_MAX == UINT64_MAX
#define SET_FRAME_REF(off) *FRAME_REF(off) = *FRAME_REF(off + 1) = 1
#define CLEAR_FRAME_REF(off)                          \
    (unsigned)off >= local_cell_num                   \
        ? (*FRAME_REF(off) = *FRAME_REF(off + 1) = 0) \
        : (void)0
#else
#define SET_FRAME_REF(off) *FRAME_REF(off) = 1
#define CLEAR_FRAME_REF(off) \
    (unsigned)off >= local_cell_num ? (*FRAME_REF(off) = 0) : (void)0
#endif

#define FRAME_REF_FOR(frame, p) \
    COMPUTE_FRAME_REF(frame->frame_ref, p - frame->lp)

#define CLEAR_FRAME_REF_FOR(p, n)               \
    do {                                        \
        int32 ref_i, ref_n = (int32)(n);        \
        uint8 *ref = FRAME_REF(p - frame_lp);   \
        for (ref_i = 0; ref_i < ref_n; ref_i++) \
            ref[ref_i] = 0;                     \
    } while (0)
#endif /* end of WASM_ENABLE_GC != 0 */

#define read_uint32(p) \
    (p += sizeof(uint32), LOAD_U32_WITH_2U16S(p - sizeof(uint32)))

#define GET_LOCAL_INDEX_TYPE_AND_OFFSET()                                \
    do {                                                                 \
        uint32 param_count = cur_func->param_count;                      \
        local_idx = read_uint32(frame_ip);                               \
        bh_assert(local_idx < param_count + cur_func->local_count);      \
        local_offset = cur_func->local_offsets[local_idx];               \
        if (local_idx < param_count)                                     \
            local_type = cur_func->param_types[local_idx];               \
        else                                                             \
            local_type = cur_func->local_types[local_idx - param_count]; \
    } while (0)

#define GET_OFFSET() (frame_ip += 2, *(int16 *)(frame_ip - 2))

#define SET_OPERAND_I32(off, value)                                 \
    do {                                                            \
        *(uint32 *)(frame_lp + *(int16 *)(frame_ip + off)) = value; \
    } while (0)
#define SET_OPERAND_F32(off, value)                                  \
    do {                                                             \
        *(float32 *)(frame_lp + *(int16 *)(frame_ip + off)) = value; \
    } while (0)
#define SET_OPERAND_I64(off, value)                               \
    do {                                                          \
        uint32 *addr_tmp = frame_lp + *(int16 *)(frame_ip + off); \
        PUT_I64_TO_ADDR(addr_tmp, value);                         \
    } while (0)
#define SET_OPERAND_F64(off, value)                               \
    do {                                                          \
        uint32 *addr_tmp = frame_lp + *(int16 *)(frame_ip + off); \
        PUT_F64_TO_ADDR(addr_tmp, value);                         \
    } while (0)
#define SET_OPERAND_REF(off, value)            \
    do {                                       \
        uint32 *addr_tmp;                      \
        opnd_off = *(int16 *)(frame_ip + off); \
        addr_tmp = frame_lp + opnd_off;        \
        PUT_REF_TO_ADDR(addr_tmp, value);      \
        SET_FRAME_REF(ond_off);                \
    } while (0)

#define SET_OPERAND(op_type, off, value) SET_OPERAND_##op_type(off, value)

#define GET_OPERAND_I32(type, off) \
    *(type *)(frame_lp + *(int16 *)(frame_ip + off))
#define GET_OPERAND_F32(type, off) \
    *(type *)(frame_lp + *(int16 *)(frame_ip + off))
#define GET_OPERAND_I64(type, off) \
    (type) GET_I64_FROM_ADDR(frame_lp + *(int16 *)(frame_ip + off))
#define GET_OPERAND_F64(type, off) \
    (type) GET_F64_FROM_ADDR(frame_lp + *(int16 *)(frame_ip + off))
#define GET_OPERAND_V128(off) \
    GET_V128_FROM_ADDR(frame_lp + *(int16 *)(frame_ip + off))
#define GET_OPERAND_REF(type, off) \
    (type) GET_REF_FROM_ADDR(frame_lp + *(int16 *)(frame_ip + off))

#define GET_OPERAND(type, op_type, off) GET_OPERAND_##op_type(type, off)

#define PUSH_I32(value)                              \
    do {                                             \
        *(int32 *)(frame_lp + GET_OFFSET()) = value; \
    } while (0)

#define PUSH_F32(value)                                \
    do {                                               \
        *(float32 *)(frame_lp + GET_OFFSET()) = value; \
    } while (0)

#define PUSH_I64(value)                             \
    do {                                            \
        uint32 *addr_tmp = frame_lp + GET_OFFSET(); \
        PUT_I64_TO_ADDR(addr_tmp, value);           \
    } while (0)

#define PUSH_F64(value)                             \
    do {                                            \
        uint32 *addr_tmp = frame_lp + GET_OFFSET(); \
        PUT_F64_TO_ADDR(addr_tmp, value);           \
    } while (0)

#define PUSH_REF(value)                   \
    do {                                  \
        uint32 *addr_tmp;                 \
        opnd_off = GET_OFFSET();          \
        addr_tmp = frame_lp + opnd_off;   \
        PUT_REF_TO_ADDR(addr_tmp, value); \
        SET_FRAME_REF(opnd_off);          \
    } while (0)

#define PUSH_I31REF(value)                \
    do {                                  \
        uint32 *addr_tmp;                 \
        opnd_off = GET_OFFSET();          \
        addr_tmp = frame_lp + opnd_off;   \
        PUT_REF_TO_ADDR(addr_tmp, value); \
    } while (0)

#define POP_I32() (*(int32 *)(frame_lp + GET_OFFSET()))

#define POP_F32() (*(float32 *)(frame_lp + GET_OFFSET()))

#define POP_I64() (GET_I64_FROM_ADDR(frame_lp + GET_OFFSET()))

#define POP_V128() (GET_V128_FROM_ADDR(frame_lp + GET_OFFSET()))

#define POP_F64() (GET_F64_FROM_ADDR(frame_lp + GET_OFFSET()))

#define POP_REF()                                                    \
    (opnd_off = GET_OFFSET(), CLEAR_FRAME_REF((unsigned)(opnd_off)), \
     GET_REF_FROM_ADDR(frame_lp + opnd_off))

#if WASM_ENABLE_GC != 0
#define SYNC_FRAME_REF() frame->frame_ref = frame_ref
#define UPDATE_FRAME_REF() frame_ref = frame->frame_ref
#else
#define SYNC_FRAME_REF() (void)0
#define UPDATE_FRAME_REF() (void)0
#endif

#define SYNC_ALL_TO_FRAME()   \
    do {                      \
        frame->ip = frame_ip; \
        SYNC_FRAME_REF();     \
    } while (0)

#define UPDATE_ALL_FROM_FRAME() \
    do {                        \
        frame_ip = frame->ip;   \
        UPDATE_FRAME_REF();     \
    } while (0)

#if WASM_ENABLE_LABELS_AS_VALUES != 0
#define UPDATE_FRAME_IP_END() (void)0
#else
#define UPDATE_FRAME_IP_END() frame_ip_end = wasm_get_func_code_end(cur_func)
#endif

#if WASM_ENABLE_GC != 0
#define RECOVER_FRAME_REF() frame_ref = frame->frame_ref
#else
#define RECOVER_FRAME_REF() (void)0
#endif

#define RECOVER_CONTEXT(new_frame)      \
    do {                                \
        frame = (new_frame);            \
        cur_func = frame->function;     \
        prev_frame = frame->prev_frame; \
        frame_ip = frame->ip;           \
        UPDATE_FRAME_IP_END();          \
        frame_lp = frame->lp;           \
        RECOVER_FRAME_REF();            \
    } while (0)

#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
#define GET_OPCODE() opcode = *frame_ip++;
#else
#define GET_OPCODE()    \
    opcode = *frame_ip; \
    frame_ip += 2;
#endif

#define DEF_OP_EQZ(ctype, src_op_type)                                  \
    do {                                                                \
        SET_OPERAND(I32, 2, (GET_OPERAND(ctype, src_op_type, 0) == 0)); \
        frame_ip += 4;                                                  \
    } while (0)

#define DEF_OP_CMP(src_type, src_op_type, cond)                      \
    do {                                                             \
        SET_OPERAND(I32, 4,                                          \
                    GET_OPERAND(src_type, src_op_type, 2)            \
                        cond GET_OPERAND(src_type, src_op_type, 0)); \
        frame_ip += 6;                                               \
    } while (0)

#define DEF_OP_BIT_COUNT(src_type, src_op_type, operation)               \
    do {                                                                 \
        SET_OPERAND(                                                     \
            src_op_type, 2,                                              \
            (src_type)operation(GET_OPERAND(src_type, src_op_type, 0))); \
        frame_ip += 4;                                                   \
    } while (0)

#define DEF_OP_NUMERIC(src_type1, src_type2, src_op_type, operation)       \
    do {                                                                   \
        SET_OPERAND(src_op_type, 4,                                        \
                    GET_OPERAND(src_type1, src_op_type, 2)                 \
                        operation GET_OPERAND(src_type2, src_op_type, 0)); \
        frame_ip += 6;                                                     \
    } while (0)

#define DEF_OP_REINTERPRET(src_type, src_op_type)                           \
    do {                                                                    \
        SET_OPERAND(src_op_type, 2, GET_OPERAND(src_type, src_op_type, 0)); \
        frame_ip += 4;                                                      \
    } while (0)

#define DEF_OP_NUMERIC_64 DEF_OP_NUMERIC

#define DEF_OP_NUMERIC2(src_type1, src_type2, src_op_type, operation)  \
    do {                                                               \
        SET_OPERAND(src_op_type, 4,                                    \
                    GET_OPERAND(src_type1, src_op_type, 2) operation(  \
                        GET_OPERAND(src_type2, src_op_type, 0) % 32)); \
        frame_ip += 6;                                                 \
    } while (0)

#define DEF_OP_NUMERIC2_64(src_type1, src_type2, src_op_type, operation) \
    do {                                                                 \
        SET_OPERAND(src_op_type, 4,                                      \
                    GET_OPERAND(src_type1, src_op_type, 2) operation(    \
                        GET_OPERAND(src_type2, src_op_type, 0) % 64));   \
        frame_ip += 6;                                                   \
    } while (0)

#define DEF_ATOMIC_RMW_OPCODE(OP_NAME, op)                           \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME:                           \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME##8_U:                      \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME##16_U:                     \
    {                                                                \
        uint32 readv, sval;                                          \
                                                                     \
        sval = POP_I32();                                            \
        addr = POP_I32();                                            \
                                                                     \
        if (opcode == WASM_OP_ATOMIC_RMW_I32_##OP_NAME##8_U) {       \
            CHECK_MEMORY_OVERFLOW(1);                                \
            CHECK_ATOMIC_MEMORY_ACCESS(1);                           \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint32)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I32_##OP_NAME##16_U) { \
            CHECK_MEMORY_OVERFLOW(2);                                \
            CHECK_ATOMIC_MEMORY_ACCESS(2);                           \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint32)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else {                                                       \
            CHECK_MEMORY_OVERFLOW(4);                                \
            CHECK_ATOMIC_MEMORY_ACCESS(4);                           \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = LOAD_I32(maddr);                                 \
            STORE_U32(maddr, readv op sval);                         \
            shared_memory_unlock(memory);                            \
        }                                                            \
        PUSH_I32(readv);                                             \
        break;                                                       \
    }                                                                \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME:                           \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME##8_U:                      \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME##16_U:                     \
    case WASM_OP_ATOMIC_RMW_I64_##OP_NAME##32_U:                     \
    {                                                                \
        uint64 readv, sval;                                          \
                                                                     \
        sval = (uint64)POP_I64();                                    \
        addr = POP_I32();                                            \
                                                                     \
        if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##8_U) {       \
            CHECK_MEMORY_OVERFLOW(1);                                \
            CHECK_ATOMIC_MEMORY_ACCESS(1);                           \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint64)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##16_U) { \
            CHECK_MEMORY_OVERFLOW(2);                                \
            CHECK_ATOMIC_MEMORY_ACCESS(2);                           \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint64)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##32_U) { \
            CHECK_MEMORY_OVERFLOW(4);                                \
            CHECK_ATOMIC_MEMORY_ACCESS(4);                           \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint64)LOAD_U32(maddr);                         \
            STORE_U32(maddr, (uint32)(readv op sval));               \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else {                                                       \
            uint64 op_result;                                        \
            CHECK_MEMORY_OVERFLOW(8);                                \
            CHECK_ATOMIC_MEMORY_ACCESS(8);                           \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint64)LOAD_I64(maddr);                         \
            op_result = readv op sval;                               \
            STORE_I64(maddr, op_result);                             \
            shared_memory_unlock(memory);                            \
        }                                                            \
        PUSH_I64(readv);                                             \
        break;                                                       \
    }

#define DEF_OP_MATH(src_type, src_op_type, method)                            \
    do {                                                                      \
        SET_OPERAND(src_op_type, 2,                                           \
                    (src_type)method(GET_OPERAND(src_type, src_op_type, 0))); \
        frame_ip += 4;                                                        \
    } while (0)

#define TRUNC_FUNCTION(func_name, src_type, dst_type, signed_type)  \
    static dst_type func_name(src_type src_value, src_type src_min, \
                              src_type src_max, dst_type dst_min,   \
                              dst_type dst_max, bool is_sign)       \
    {                                                               \
        dst_type dst_value = 0;                                     \
        if (!isnan(src_value)) {                                    \
            if (src_value <= src_min)                               \
                dst_value = dst_min;                                \
            else if (src_value >= src_max)                          \
                dst_value = dst_max;                                \
            else {                                                  \
                if (is_sign)                                        \
                    dst_value = (dst_type)(signed_type)src_value;   \
                else                                                \
                    dst_value = (dst_type)src_value;                \
            }                                                       \
        }                                                           \
        return dst_value;                                           \
    }

TRUNC_FUNCTION(trunc_f32_to_i32, float32, uint32, int32)
TRUNC_FUNCTION(trunc_f32_to_i64, float32, uint64, int64)
TRUNC_FUNCTION(trunc_f64_to_i32, float64, uint32, int32)
TRUNC_FUNCTION(trunc_f64_to_i64, float64, uint64, int64)

static bool
trunc_f32_to_int(WASMModuleInstance *module, uint8 *frame_ip, uint32 *frame_lp,
                 float32 src_min, float32 src_max, bool saturating, bool is_i32,
                 bool is_sign)
{
    float32 src_value = GET_OPERAND(float32, F32, 0);
    uint64 dst_value_i64;
    uint32 dst_value_i32;

    if (!saturating) {
        if (isnan(src_value)) {
            wasm_set_exception(module, "invalid conversion to integer");
            return false;
        }
        else if (src_value <= src_min || src_value >= src_max) {
            wasm_set_exception(module, "integer overflow");
            return false;
        }
    }

    if (is_i32) {
        uint32 dst_min = is_sign ? INT32_MIN : 0;
        uint32 dst_max = is_sign ? INT32_MAX : UINT32_MAX;
        dst_value_i32 = trunc_f32_to_i32(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I32, 2, dst_value_i32);
    }
    else {
        uint64 dst_min = is_sign ? INT64_MIN : 0;
        uint64 dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f32_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I64, 2, dst_value_i64);
    }
    return true;
}

static bool
trunc_f64_to_int(WASMModuleInstance *module, uint8 *frame_ip, uint32 *frame_lp,
                 float64 src_min, float64 src_max, bool saturating, bool is_i32,
                 bool is_sign)
{
    float64 src_value = GET_OPERAND(float64, F64, 0);
    uint64 dst_value_i64;
    uint32 dst_value_i32;

    if (!saturating) {
        if (isnan(src_value)) {
            wasm_set_exception(module, "invalid conversion to integer");
            return false;
        }
        else if (src_value <= src_min || src_value >= src_max) {
            wasm_set_exception(module, "integer overflow");
            return false;
        }
    }

    if (is_i32) {
        uint32 dst_min = is_sign ? INT32_MIN : 0;
        uint32 dst_max = is_sign ? INT32_MAX : UINT32_MAX;
        dst_value_i32 = trunc_f64_to_i32(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I32, 2, dst_value_i32);
    }
    else {
        uint64 dst_min = is_sign ? INT64_MIN : 0;
        uint64 dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f64_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        SET_OPERAND(I64, 2, dst_value_i64);
    }
    return true;
}

#define DEF_OP_TRUNC_F32(min, max, is_i32, is_sign)                        \
    do {                                                                   \
        if (!trunc_f32_to_int(module, frame_ip, frame_lp, min, max, false, \
                              is_i32, is_sign))                            \
            goto got_exception;                                            \
        frame_ip += 4;                                                     \
    } while (0)

#define DEF_OP_TRUNC_F64(min, max, is_i32, is_sign)                        \
    do {                                                                   \
        if (!trunc_f64_to_int(module, frame_ip, frame_lp, min, max, false, \
                              is_i32, is_sign))                            \
            goto got_exception;                                            \
        frame_ip += 4;                                                     \
    } while (0)

#define DEF_OP_TRUNC_SAT_F32(min, max, is_i32, is_sign)                    \
    do {                                                                   \
        (void)trunc_f32_to_int(module, frame_ip, frame_lp, min, max, true, \
                               is_i32, is_sign);                           \
        frame_ip += 4;                                                     \
    } while (0)

#define DEF_OP_TRUNC_SAT_F64(min, max, is_i32, is_sign)                    \
    do {                                                                   \
        (void)trunc_f64_to_int(module, frame_ip, frame_lp, min, max, true, \
                               is_i32, is_sign);                           \
        frame_ip += 4;                                                     \
    } while (0)

#define DEF_OP_CONVERT(dst_type, dst_op_type, src_type, src_op_type) \
    do {                                                             \
        dst_type value = (dst_type)(src_type)POP_##src_op_type();    \
        PUSH_##dst_op_type(value);                                   \
    } while (0)

#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
#define CELL_SIZE sizeof(uint8)
#else
#define CELL_SIZE (sizeof(uint8) * 2)
#endif

static bool
copy_stack_values(WASMModuleInstance *module, uint32 *frame_lp, uint32 arity,
#if WASM_ENABLE_GC != 0
                  uint8 *frame_ref,
#endif
                  uint32 total_cell_num, const uint8 *cells,
                  const int16 *src_offsets, const uint16 *dst_offsets)
{
    /* To avoid the overlap issue between src offsets and dst offset,
     * we use 2 steps to do the copy. First step, copy the src values
     * to a tmp buf. Second step, copy the values from tmp buf to dst.
     */
    bool ret = false;
    uint32 buf[16] = { 0 }, i;
    uint32 *tmp_buf = buf;
    uint8 cell;
    int16 src, buf_index = 0;
    uint16 dst;
#if WASM_ENABLE_GC != 0
    uint8 ref_buf[4];
    uint8 *tmp_ref_buf = ref_buf;
#endif

    /* Allocate memory if the buf is not large enough */
    if (total_cell_num > sizeof(buf) / sizeof(uint32)) {
        uint64 total_size = sizeof(uint32) * (uint64)total_cell_num;
        if (total_size >= UINT32_MAX
            || !(tmp_buf = wasm_runtime_malloc((uint32)total_size))) {
            wasm_set_exception(module, "allocate memory failed");
            goto fail;
        }
    }

#if WASM_ENABLE_GC != 0
    if (total_cell_num > sizeof(ref_buf) / sizeof(uint8)) {
        uint64 total_size = sizeof(uint8) * (uint64)total_cell_num;
        if (total_size >= UINT32_MAX
            || !(tmp_ref_buf = wasm_runtime_malloc((uint32)total_size))) {
            wasm_set_exception(module, "allocate memory failed");
            goto fail;
        }
    }
#endif

    /* 1) Copy values from src to tmp buf */
    for (i = 0; i < arity; i++) {
        cell = cells[i * CELL_SIZE];
        src = src_offsets[i];
        if (cell == 1) {
            tmp_buf[buf_index] = frame_lp[src];
#if WASM_ENABLE_GC != 0
            tmp_ref_buf[buf_index] = frame_ref[src];
            frame_ref[src] = 0;
#endif
        }
        else {
            tmp_buf[buf_index] = frame_lp[src];
            tmp_buf[buf_index + 1] = frame_lp[src + 1];
#if WASM_ENABLE_GC != 0
            tmp_ref_buf[buf_index] = frame_ref[src];
            tmp_ref_buf[buf_index + 1] = frame_ref[src + 1];
            frame_ref[src] = 0;
            frame_ref[src + 1] = 0;
#endif
        }
        buf_index += cell;
    }

    /* 2) Copy values from tmp buf to dest */
    buf_index = 0;
    for (i = 0; i < arity; i++) {
        cell = cells[i * CELL_SIZE];
        dst = dst_offsets[i];
        if (cell == 1) {
            frame_lp[dst] = tmp_buf[buf_index];
#if WASM_ENABLE_GC != 0
            frame_ref[dst] = tmp_ref_buf[buf_index];
#endif
        }
        else {
            frame_lp[dst] = tmp_buf[buf_index];
            frame_lp[dst + 1] = tmp_buf[buf_index + 1];
#if WASM_ENABLE_GC != 0
            frame_ref[dst] = tmp_ref_buf[buf_index];
            frame_ref[dst + 1] = tmp_ref_buf[buf_index + 1];
#endif
        }
        buf_index += cell;
    }

    ret = true;

fail:
    if (tmp_buf != buf) {
        wasm_runtime_free(tmp_buf);
    }

#if WASM_ENABLE_GC != 0
    if (tmp_ref_buf != ref_buf) {
        wasm_runtime_free(tmp_ref_buf);
    }
#endif

    return ret;
}

#if WASM_ENABLE_GC != 0
#define RECOVER_BR_INFO()                                                  \
    do {                                                                   \
        uint32 arity;                                                      \
        /* read arity */                                                   \
        arity = read_uint32(frame_ip);                                     \
        if (arity) {                                                       \
            uint32 total_cell;                                             \
            uint16 *dst_offsets = NULL;                                    \
            uint8 *cells;                                                  \
            int16 *src_offsets = NULL;                                     \
            /* read total cell num */                                      \
            total_cell = read_uint32(frame_ip);                            \
            /* cells */                                                    \
            cells = (uint8 *)frame_ip;                                     \
            frame_ip += arity * CELL_SIZE;                                 \
            /* src offsets */                                              \
            src_offsets = (int16 *)frame_ip;                               \
            frame_ip += arity * sizeof(int16);                             \
            /* dst offsets */                                              \
            dst_offsets = (uint16 *)frame_ip;                              \
            frame_ip += arity * sizeof(uint16);                            \
            if (arity == 1) {                                              \
                if (cells[0] == 1) {                                       \
                    frame_lp[dst_offsets[0]] = frame_lp[src_offsets[0]];   \
                    /* Ignore constants because they are not reference */  \
                    if (src_offsets[0] >= 0) {                             \
                        CLEAR_FRAME_REF((unsigned)(src_offsets[0]));       \
                        SET_FRAME_REF(dst_offsets[0]);                     \
                    }                                                      \
                }                                                          \
                else if (cells[0] == 2) {                                  \
                    PUT_I64_TO_ADDR(                                       \
                        frame_lp + dst_offsets[0],                         \
                        GET_I64_FROM_ADDR(frame_lp + src_offsets[0]));     \
                    /* Ignore constants because they are not reference */  \
                    if (src_offsets[0] >= 0) {                             \
                        CLEAR_FRAME_REF((unsigned)src_offsets[0]);         \
                        CLEAR_FRAME_REF((unsigned)(src_offsets[0] + 1));   \
                        SET_FRAME_REF((unsigned)dst_offsets[0]);           \
                        SET_FRAME_REF((unsigned)(dst_offsets[0] + 1));     \
                    }                                                      \
                }                                                          \
                else if (cells[0] == 4) {                                  \
                    PUT_V128_TO_ADDR(                                      \
                        frame_lp + dst_offsets[0],                         \
                        GET_V128_FROM_ADDR(frame_lp + src_offsets[0]));    \
                    /* Ignore constants because they are not reference */  \
                    if (src_offsets[0] >= 0) {                             \
                        CLEAR_FRAME_REF((unsigned)src_offsets[0]);         \
                        CLEAR_FRAME_REF((unsigned)(src_offsets[0] + 1));   \
                        CLEAR_FRAME_REF((unsigned)(src_offsets[0] + 2));   \
                        CLEAR_FRAME_REF((unsigned)(src_offsets[0] + 3));   \
                        SET_FRAME_REF((unsigned)dst_offsets[0]);           \
                        SET_FRAME_REF((unsigned)(dst_offsets[0] + 1));     \
                        SET_FRAME_REF((unsigned)(dst_offsets[0] + 2));     \
                        SET_FRAME_REF((unsigned)(dst_offsets[0] + 3));     \
                    }                                                      \
                }                                                          \
            }                                                              \
            else {                                                         \
                if (!copy_stack_values(module, frame_lp, arity, frame_ref, \
                                       total_cell, cells, src_offsets,     \
                                       dst_offsets))                       \
                    goto got_exception;                                    \
            }                                                              \
        }                                                                  \
        frame_ip = (uint8 *)LOAD_PTR(frame_ip);                            \
    } while (0)
#else
#define RECOVER_BR_INFO()                                                   \
    do {                                                                    \
        uint32 arity;                                                       \
        /* read arity */                                                    \
        arity = read_uint32(frame_ip);                                      \
        if (arity) {                                                        \
            uint32 total_cell;                                              \
            uint16 *dst_offsets = NULL;                                     \
            uint8 *cells;                                                   \
            int16 *src_offsets = NULL;                                      \
            /* read total cell num */                                       \
            total_cell = read_uint32(frame_ip);                             \
            /* cells */                                                     \
            cells = (uint8 *)frame_ip;                                      \
            frame_ip += arity * CELL_SIZE;                                  \
            /* src offsets */                                               \
            src_offsets = (int16 *)frame_ip;                                \
            frame_ip += arity * sizeof(int16);                              \
            /* dst offsets */                                               \
            dst_offsets = (uint16 *)frame_ip;                               \
            frame_ip += arity * sizeof(uint16);                             \
            if (arity == 1) {                                               \
                if (cells[0] == 1)                                          \
                    frame_lp[dst_offsets[0]] = frame_lp[src_offsets[0]];    \
                else if (cells[0] == 2) {                                   \
                    PUT_I64_TO_ADDR(                                        \
                        frame_lp + dst_offsets[0],                          \
                        GET_I64_FROM_ADDR(frame_lp + src_offsets[0]));      \
                }                                                           \
                else if (cells[0] == 4) {                                   \
                    PUT_V128_TO_ADDR(                                       \
                        frame_lp + dst_offsets[0],                          \
                        GET_V128_FROM_ADDR(frame_lp + src_offsets[0]));     \
                }                                                           \
            }                                                               \
            else {                                                          \
                if (!copy_stack_values(module, frame_lp, arity, total_cell, \
                                       cells, src_offsets, dst_offsets))    \
                    goto got_exception;                                     \
            }                                                               \
        }                                                                   \
        frame_ip = (uint8 *)LOAD_PTR(frame_ip);                             \
    } while (0)
#endif

#define SKIP_BR_INFO()                                                        \
    do {                                                                      \
        uint32 arity;                                                         \
        /* read and skip arity */                                             \
        arity = read_uint32(frame_ip);                                        \
        if (arity) {                                                          \
            /* skip total cell num */                                         \
            frame_ip += sizeof(uint32);                                       \
            /* skip cells, src offsets and dst offsets */                     \
            frame_ip += (CELL_SIZE + sizeof(int16) + sizeof(uint16)) * arity; \
        }                                                                     \
        /* skip target address */                                             \
        frame_ip += sizeof(uint8 *);                                          \
    } while (0)

static inline int32
sign_ext_8_32(int8 val)
{
    if (val & 0x80)
        return (int32)val | (int32)0xffffff00;
    return val;
}

static inline int32
sign_ext_16_32(int16 val)
{
    if (val & 0x8000)
        return (int32)val | (int32)0xffff0000;
    return val;
}

static inline int64
sign_ext_8_64(int8 val)
{
    if (val & 0x80)
        return (int64)val | (int64)0xffffffffffffff00LL;
    return val;
}

static inline int64
sign_ext_16_64(int16 val)
{
    if (val & 0x8000)
        return (int64)val | (int64)0xffffffffffff0000LL;
    return val;
}

static inline int64
sign_ext_32_64(int32 val)
{
    if (val & (int32)0x80000000)
        return (int64)val | (int64)0xffffffff00000000LL;
    return val;
}

static inline void
word_copy(uint32 *dest, uint32 *src, unsigned num)
{
    bh_assert(dest != NULL);
    bh_assert(src != NULL);
    bh_assert(num > 0);
    if (dest != src) {
        /* No overlap buffer */
        bh_assert(!((src < dest) && (dest < src + num)));
        for (; num > 0; num--)
            *dest++ = *src++;
    }
}

static inline WASMInterpFrame *
ALLOC_FRAME(WASMExecEnv *exec_env, uint32 size, WASMInterpFrame *prev_frame)
{
    WASMInterpFrame *frame = wasm_exec_env_alloc_wasm_frame(exec_env, size);

    if (frame) {
        frame->prev_frame = prev_frame;
#if WASM_ENABLE_PERF_PROFILING != 0
        frame->time_started = os_time_thread_cputime_us();
#endif
    }
    else {
        wasm_set_exception((WASMModuleInstance *)exec_env->module_inst,
                           "wasm operand stack overflow");
    }

    return frame;
}

static inline void
FREE_FRAME(WASMExecEnv *exec_env, WASMInterpFrame *frame)
{
#if WASM_ENABLE_PERF_PROFILING != 0
    if (frame->function) {
        WASMInterpFrame *prev_frame = frame->prev_frame;
        uint64 time_elapsed = os_time_thread_cputime_us() - frame->time_started;

        frame->function->total_exec_time += time_elapsed;
        frame->function->total_exec_cnt++;

        /* parent function */
        if (prev_frame && prev_frame->function)
            prev_frame->function->children_exec_time += time_elapsed;
    }
#endif
    wasm_exec_env_free_wasm_frame(exec_env, frame);
}

static void
wasm_interp_call_func_native(WASMModuleInstance *module_inst,
                             WASMExecEnv *exec_env,
                             WASMFunctionInstance *cur_func,
                             WASMInterpFrame *prev_frame)
{
    WASMFunctionImport *func_import = cur_func->u.func_import;
    CApiFuncImport *c_api_func_import = NULL;
    unsigned local_cell_num =
        cur_func->param_cell_num > 2 ? cur_func->param_cell_num : 2;
    unsigned all_cell_num;
    WASMInterpFrame *frame;
    uint32 argv_ret[2], cur_func_index;
    void *native_func_pointer = NULL;
    bool ret;
#if WASM_ENABLE_GC != 0
    WASMFuncType *func_type;
    uint8 *frame_ref;
#endif

    all_cell_num = local_cell_num;
#if WASM_ENABLE_GC != 0
    all_cell_num += (local_cell_num + 3) / 4;
#endif

    if (!wasm_runtime_detect_native_stack_overflow(exec_env)) {
        return;
    }

    if (!(frame =
              ALLOC_FRAME(exec_env, wasm_interp_interp_frame_size(all_cell_num),
                          prev_frame)))
        return;

    frame->function = cur_func;
    frame->ip = NULL;
    frame->lp = frame->operand;
#if WASM_ENABLE_GC != 0
    frame->frame_ref = (uint8 *)(frame->lp + local_cell_num);
    init_frame_refs(frame->frame_ref, local_cell_num, cur_func);
#endif

    wasm_exec_env_set_cur_frame(exec_env, frame);

    cur_func_index = (uint32)(cur_func - module_inst->e->functions);
    bh_assert(cur_func_index < module_inst->module->import_function_count);
    if (!func_import->call_conv_wasm_c_api) {
        native_func_pointer = module_inst->import_func_ptrs[cur_func_index];
    }
    else if (module_inst->c_api_func_imports) {
        c_api_func_import = module_inst->c_api_func_imports + cur_func_index;
        native_func_pointer = c_api_func_import->func_ptr_linked;
    }

    if (!native_func_pointer) {
        char buf[128];
        snprintf(buf, sizeof(buf),
                 "failed to call unlinked import function (%s, %s)",
                 func_import->module_name, func_import->field_name);
        wasm_set_exception((WASMModuleInstance *)module_inst, buf);
        return;
    }

    if (func_import->call_conv_wasm_c_api) {
        ret = wasm_runtime_invoke_c_api_native(
            (WASMModuleInstanceCommon *)module_inst, native_func_pointer,
            func_import->func_type, cur_func->param_cell_num, frame->lp,
            c_api_func_import->with_env_arg, c_api_func_import->env_arg);
        if (ret) {
            argv_ret[0] = frame->lp[0];
            argv_ret[1] = frame->lp[1];
        }
    }
    else if (!func_import->call_conv_raw) {
        ret = wasm_runtime_invoke_native(
            exec_env, native_func_pointer, func_import->func_type,
            func_import->signature, func_import->attachment, frame->lp,
            cur_func->param_cell_num, argv_ret);
    }
    else {
        ret = wasm_runtime_invoke_native_raw(
            exec_env, native_func_pointer, func_import->func_type,
            func_import->signature, func_import->attachment, frame->lp,
            cur_func->param_cell_num, argv_ret);
    }

    if (!ret)
        return;

#if WASM_ENABLE_GC != 0
    func_type = cur_func->u.func_import->func_type;
    if (func_type->result_count
        && wasm_is_type_reftype(func_type->types[cur_func->param_count])
        && !wasm_is_reftype_i31ref(func_type->types[cur_func->param_count])) {
        frame_ref = prev_frame->frame_ref + prev_frame->ret_offset;
#if UINTPTR_MAX == UINT64_MAX
        *frame_ref = *(frame_ref + 1) = 1;
#else
        *frame_ref = 1;
#endif
    }
#endif

    if (cur_func->ret_cell_num == 1) {
        prev_frame->lp[prev_frame->ret_offset] = argv_ret[0];
    }
    else if (cur_func->ret_cell_num == 2) {
        prev_frame->lp[prev_frame->ret_offset] = argv_ret[0];
        prev_frame->lp[prev_frame->ret_offset + 1] = argv_ret[1];
    }

    FREE_FRAME(exec_env, frame);
    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
}

#if WASM_ENABLE_MULTI_MODULE != 0
static void
wasm_interp_call_func_bytecode(WASMModuleInstance *module,
                               WASMExecEnv *exec_env,
                               WASMFunctionInstance *cur_func,
                               WASMInterpFrame *prev_frame);

static void
wasm_interp_call_func_import(WASMModuleInstance *module_inst,
                             WASMExecEnv *exec_env,
                             WASMFunctionInstance *cur_func,
                             WASMInterpFrame *prev_frame)
{
    WASMModuleInstance *sub_module_inst = cur_func->import_module_inst;
    WASMFunctionInstance *sub_func_inst = cur_func->import_func_inst;
    WASMFunctionImport *func_import = cur_func->u.func_import;
    uint8 *ip = prev_frame->ip;
    char buf[128];
    WASMExecEnv *sub_module_exec_env = NULL;
    uintptr_t aux_stack_origin_boundary = 0;
    uintptr_t aux_stack_origin_bottom = 0;

    /*
     * perform stack overflow check before calling
     * wasm_interp_call_func_bytecode recursively.
     */
    if (!wasm_runtime_detect_native_stack_overflow(exec_env)) {
        return;
    }

    if (!sub_func_inst) {
        snprintf(buf, sizeof(buf),
                 "failed to call unlinked import function (%s, %s)",
                 func_import->module_name, func_import->field_name);
        wasm_set_exception(module_inst, buf);
        return;
    }

    /* Switch exec_env but keep using the same one by replacing necessary
     * variables */
    sub_module_exec_env = wasm_runtime_get_exec_env_singleton(
        (WASMModuleInstanceCommon *)sub_module_inst);
    if (!sub_module_exec_env) {
        wasm_set_exception(module_inst, "create singleton exec_env failed");
        return;
    }

    /* - module_inst */
    wasm_exec_env_set_module_inst(exec_env,
                                  (WASMModuleInstanceCommon *)sub_module_inst);
    /* - aux_stack_boundary */
    aux_stack_origin_boundary = exec_env->aux_stack_boundary;
    exec_env->aux_stack_boundary = sub_module_exec_env->aux_stack_boundary;
    /* - aux_stack_bottom */
    aux_stack_origin_bottom = exec_env->aux_stack_bottom;
    exec_env->aux_stack_bottom = sub_module_exec_env->aux_stack_bottom;

    /* set ip NULL to make call_func_bytecode return after executing
       this function */
    prev_frame->ip = NULL;

    /* call function of sub-module*/
    wasm_interp_call_func_bytecode(sub_module_inst, exec_env, sub_func_inst,
                                   prev_frame);

    /* restore ip and other replaced */
    prev_frame->ip = ip;
    exec_env->aux_stack_boundary = aux_stack_origin_boundary;
    exec_env->aux_stack_bottom = aux_stack_origin_bottom;
    wasm_exec_env_restore_module_inst(exec_env,
                                      (WASMModuleInstanceCommon *)module_inst);
}
#endif

#if WASM_ENABLE_THREAD_MGR != 0
#define CHECK_SUSPEND_FLAGS()                               \
    do {                                                    \
        WASM_SUSPEND_FLAGS_LOCK(exec_env->wait_lock);       \
        if (WASM_SUSPEND_FLAGS_GET(exec_env->suspend_flags) \
            & WASM_SUSPEND_FLAG_TERMINATE) {                \
            /* terminate current thread */                  \
            WASM_SUSPEND_FLAGS_UNLOCK(exec_env->wait_lock); \
            return;                                         \
        }                                                   \
        /* TODO: support suspend and breakpoint */          \
        WASM_SUSPEND_FLAGS_UNLOCK(exec_env->wait_lock);     \
    } while (0)
#endif

#if WASM_ENABLE_OPCODE_COUNTER != 0
typedef struct OpcodeInfo {
    char *name;
    uint64 count;
} OpcodeInfo;

/* clang-format off */
#define HANDLE_OPCODE(op) \
    {                     \
        #op, 0            \
    }
DEFINE_GOTO_TABLE(OpcodeInfo, opcode_table);
#undef HANDLE_OPCODE
/* clang-format on */

static void
wasm_interp_dump_op_count()
{
    uint32 i;
    uint64 total_count = 0;
    for (i = 0; i < WASM_OP_IMPDEP; i++)
        total_count += opcode_table[i].count;

    os_printf("total opcode count: %ld\n", total_count);
    for (i = 0; i < WASM_OP_IMPDEP; i++)
        if (opcode_table[i].count > 0)
            os_printf("\t\t%s count:\t\t%ld,\t\t%.2f%%\n", opcode_table[i].name,
                      opcode_table[i].count,
                      opcode_table[i].count * 100.0f / total_count);
}
#endif

#if WASM_ENABLE_LABELS_AS_VALUES != 0

/* #define HANDLE_OP(opcode) HANDLE_##opcode:printf(#opcode"\n"); */
#if WASM_ENABLE_OPCODE_COUNTER != 0
#define HANDLE_OP(opcode) HANDLE_##opcode : opcode_table[opcode].count++;
#else
#define HANDLE_OP(opcode) HANDLE_##opcode:
#endif
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
#define FETCH_OPCODE_AND_DISPATCH()                    \
    do {                                               \
        const void *p_label_addr = *(void **)frame_ip; \
        frame_ip += sizeof(void *);                    \
        CHECK_INSTRUCTION_LIMIT();                     \
        goto *p_label_addr;                            \
    } while (0)
#else
#if UINTPTR_MAX == UINT64_MAX
#define FETCH_OPCODE_AND_DISPATCH()                                       \
    do {                                                                  \
        const void *p_label_addr;                                         \
        bh_assert(((uintptr_t)frame_ip & 1) == 0);                        \
        /* int32 relative offset was emitted in 64-bit target */          \
        p_label_addr = label_base + (int32)LOAD_U32_WITH_2U16S(frame_ip); \
        frame_ip += sizeof(int32);                                        \
        CHECK_INSTRUCTION_LIMIT();                                        \
        goto *p_label_addr;                                               \
    } while (0)
#else
#define FETCH_OPCODE_AND_DISPATCH()                                      \
    do {                                                                 \
        const void *p_label_addr;                                        \
        bh_assert(((uintptr_t)frame_ip & 1) == 0);                       \
        /* uint32 label address was emitted in 32-bit target */          \
        p_label_addr = (void *)(uintptr_t)LOAD_U32_WITH_2U16S(frame_ip); \
        frame_ip += sizeof(int32);                                       \
        CHECK_INSTRUCTION_LIMIT();                                       \
        goto *p_label_addr;                                              \
    } while (0)
#endif
#endif /* end of WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS */
#define HANDLE_OP_END() FETCH_OPCODE_AND_DISPATCH()

#else /* else of WASM_ENABLE_LABELS_AS_VALUES */

#define HANDLE_OP(opcode) case opcode:
#define HANDLE_OP_END() continue

#endif /* end of WASM_ENABLE_LABELS_AS_VALUES */

#if WASM_ENABLE_LABELS_AS_VALUES != 0
static void **global_handle_table;
#endif

static inline uint8 *
get_global_addr(uint8 *global_data, WASMGlobalInstance *global)
{
#if WASM_ENABLE_MULTI_MODULE == 0
    return global_data + global->data_offset;
#else
    return global->import_global_inst
               ? global->import_module_inst->global_data
                     + global->import_global_inst->data_offset
               : global_data + global->data_offset;
#endif
}

static void
wasm_interp_call_func_bytecode(WASMModuleInstance *module,
                               WASMExecEnv *exec_env,
                               WASMFunctionInstance *cur_func,
                               WASMInterpFrame *prev_frame)
{
    WASMMemoryInstance *memory = wasm_get_default_memory(module);
#if !defined(OS_ENABLE_HW_BOUND_CHECK)              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0
    uint64 linear_mem_size = 0;
    if (memory)
#if WASM_ENABLE_THREAD_MGR == 0
        linear_mem_size = memory->memory_data_size;
#else
        linear_mem_size = GET_LINEAR_MEMORY_SIZE(memory);
#endif
#endif
    WASMGlobalInstance *globals = module->e ? module->e->globals : NULL;
    WASMGlobalInstance *global;
    uint8 *global_data = module->global_data;
    uint8 opcode_IMPDEP = WASM_OP_IMPDEP;
    WASMInterpFrame *frame = NULL;
    /* Points to this special opcode so as to jump to the
     * call_method_from_entry.  */
    register uint8 *frame_ip = &opcode_IMPDEP; /* cache of frame->ip */
    register uint32 *frame_lp = NULL;          /* cache of frame->lp */
#if WASM_ENABLE_LABELS_AS_VALUES != 0
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 && UINTPTR_MAX == UINT64_MAX
    /* cache of label base addr */
    register uint8 *label_base = &&HANDLE_WASM_OP_UNREACHABLE;
#endif
#endif
#if WASM_ENABLE_GC != 0
    register uint8 *frame_ref = NULL; /* cache of frame->ref */
    uint32 local_cell_num = 0;
    int16 opnd_off;
#endif
    uint8 *frame_ip_end = frame_ip + 1;
    uint32 cond, count, fidx, tidx, frame_size = 0;
    uint32 all_cell_num = 0;
    int16 addr1, addr2, addr_ret = 0;
    int32 didx, val;
    uint8 *maddr = NULL;
    uint32 local_idx, local_offset, global_idx;
    uint8 opcode = 0, local_type, *global_addr;

#if WASM_ENABLE_INSTRUCTION_METERING != 0
    int instructions_left = -1;
    if (exec_env) {
        instructions_left = exec_env->instructions_to_execute;
    }
#endif
#if !defined(OS_ENABLE_HW_BOUND_CHECK) \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
#if WASM_CONFIGURABLE_BOUNDS_CHECKS != 0
    bool disable_bounds_checks = !wasm_runtime_is_bounds_checks_enabled(
        (WASMModuleInstanceCommon *)module);
#else
    bool disable_bounds_checks = false;
#endif
#endif
#if WASM_ENABLE_GC != 0
    WASMObjectRef gc_obj;
    WASMStructObjectRef struct_obj;
    WASMArrayObjectRef array_obj;
    WASMFuncObjectRef func_obj;
    WASMI31ObjectRef i31_obj;
    WASMExternrefObjectRef externref_obj;
    uint32 type_idx;
#if WASM_ENABLE_STRINGREF != 0
    WASMString str_obj;
    WASMStringrefObjectRef stringref_obj;
    WASMStringviewWTF8ObjectRef stringview_wtf8_obj;
    WASMStringviewWTF16ObjectRef stringview_wtf16_obj;
    WASMStringviewIterObjectRef stringview_iter_obj;
#endif
#endif
#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
    bool is_return_call = false;
#endif
#if WASM_ENABLE_SHARED_HEAP != 0
    /* TODO: currently flowing two variables are only dummy for shared heap
     * boundary check, need to be updated when multi-memory or memory64
     * proposals are to be implemented */
    bool is_memory64 = false;
    uint32 memidx = 0;
    (void)is_memory64;
    (void)memidx;
/* #endif */
#endif /* end of WASM_ENABLE_SHARED_HEAP != 0 */

#if WASM_ENABLE_LABELS_AS_VALUES != 0
#define HANDLE_OPCODE(op) &&HANDLE_##op
    DEFINE_GOTO_TABLE(const void *, handle_table);
#undef HANDLE_OPCODE
    if (exec_env == NULL) {
        global_handle_table = (void **)handle_table;
        return;
    }
#endif

#if WASM_ENABLE_LABELS_AS_VALUES == 0
    while (frame_ip < frame_ip_end) {
        opcode = *frame_ip++;
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0
        frame_ip++;
#endif
        switch (opcode) {
#else
    goto *handle_table[WASM_OP_IMPDEP];
#endif
            /* control instructions */
            HANDLE_OP(WASM_OP_UNREACHABLE)
            {
                wasm_set_exception(module, "unreachable");
                goto got_exception;
            }

            HANDLE_OP(WASM_OP_IF)
            {
                cond = (uint32)POP_I32();

                if (cond == 0) {
                    uint8 *else_addr = (uint8 *)LOAD_PTR(frame_ip);
                    if (else_addr == NULL) {
                        frame_ip =
                            (uint8 *)LOAD_PTR(frame_ip + sizeof(uint8 *));
                    }
                    else {
                        frame_ip = else_addr;
                    }
                }
                else {
                    frame_ip += sizeof(uint8 *) * 2;
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_ELSE)
            {
                frame_ip = (uint8 *)LOAD_PTR(frame_ip);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_BR)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
            recover_br_info:
                RECOVER_BR_INFO();
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_BR_IF)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                cond = frame_lp[GET_OFFSET()];

                if (cond)
                    goto recover_br_info;
                else
                    SKIP_BR_INFO();

                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_BR_TABLE)
            {
                uint32 arity, br_item_size;

#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                count = read_uint32(frame_ip);
                didx = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;

                if (!(didx >= 0 && (uint32)didx < count))
                    didx = count;

                /* all br items must have the same arity and item size,
                   so we only calculate the first item size */
                arity = LOAD_U32_WITH_2U16S(frame_ip);
                br_item_size = sizeof(uint32); /* arity */
                if (arity) {
                    /* total cell num */
                    br_item_size += sizeof(uint32);
                    /* cells, src offsets and dst offsets */
                    br_item_size +=
                        (CELL_SIZE + sizeof(int16) + sizeof(uint16)) * arity;
                }
                /* target address */
                br_item_size += sizeof(uint8 *);

                frame_ip += br_item_size * didx;
                goto recover_br_info;
            }

            HANDLE_OP(WASM_OP_RETURN)
            {
                uint32 ret_idx;
                WASMFuncType *func_type;
                int32 off;
                uint32 ret_offset;
                uint8 *ret_types;
                if (cur_func->is_import_func)
                    func_type = cur_func->u.func_import->func_type;
                else
                    func_type = cur_func->u.func->func_type;

                /* types of each return value */
                ret_types = func_type->types + func_type->param_count;
                ret_offset = prev_frame->ret_offset;

                for (ret_idx = 0,
                    off = (int32)sizeof(int16) * (func_type->result_count - 1);
                     ret_idx < func_type->result_count;
                     ret_idx++, off -= (int32)sizeof(int16)) {
                    if (ret_types[ret_idx] == VALUE_TYPE_I64
                        || ret_types[ret_idx] == VALUE_TYPE_F64) {
                        PUT_I64_TO_ADDR(prev_frame->lp + ret_offset,
                                        GET_OPERAND(uint64, I64, off));
                        ret_offset += 2;
                    }
                    else if (ret_types[ret_idx] == VALUE_TYPE_V128) {
                        PUT_V128_TO_ADDR(prev_frame->lp + ret_offset,
                                         GET_OPERAND_V128(off));
                        ret_offset += 4;
                    }
#if WASM_ENABLE_GC != 0
                    else if (wasm_is_type_reftype(ret_types[ret_idx])) {
                        PUT_REF_TO_ADDR(prev_frame->lp + ret_offset,
                                        GET_OPERAND(void *, REF, off));
                        if (!wasm_is_reftype_i31ref(ret_types[ret_idx])) {
                            *(prev_frame->frame_ref + ret_offset) = 1;
#if UINTPTR_MAX == UINT64_MAX
                            *(prev_frame->frame_ref + ret_offset + 1) = 1;
#endif
                        }
                        ret_offset += REF_CELL_NUM;
                    }
#endif
                    else {
                        prev_frame->lp[ret_offset] =
                            GET_OPERAND(uint32, I32, off);
                        ret_offset++;
                    }
                }
                goto return_func;
            }

            HANDLE_OP(WASM_OP_CALL_INDIRECT)
#if WASM_ENABLE_TAIL_CALL != 0
            HANDLE_OP(WASM_OP_RETURN_CALL_INDIRECT)
#endif
            {
                WASMFuncType *cur_type, *cur_func_type;
                WASMTableInstance *tbl_inst;
                uint32 tbl_idx;

#if WASM_ENABLE_TAIL_CALL != 0
                GET_OPCODE();
#endif
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif

                tidx = read_uint32(frame_ip);
                cur_type = (WASMFuncType *)module->module->types[tidx];

                tbl_idx = read_uint32(frame_ip);
                bh_assert(tbl_idx < module->table_count);

                tbl_inst = wasm_get_table_inst(module, tbl_idx);

                val = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;

                if ((uint32)val >= tbl_inst->cur_size) {
                    wasm_set_exception(module, "undefined element");
                    goto got_exception;
                }

                /* clang-format off */
#if WASM_ENABLE_GC == 0
                fidx = (uint32)tbl_inst->elems[val];
                if (fidx == (uint32)-1) {
                    wasm_set_exception(module, "uninitialized element");
                    goto got_exception;
                }
#else
                func_obj = (WASMFuncObjectRef)tbl_inst->elems[val];
                if (!func_obj) {
                    wasm_set_exception(module, "uninitialized element");
                    goto got_exception;
                }
                fidx = wasm_func_obj_get_func_idx_bound(func_obj);
#endif
                /* clang-format on */

                /*
                 * we might be using a table injected by host or
                 * another module. in that case, we don't validate
                 * the elem value while loading
                 */
                if (fidx >= module->e->function_count) {
                    wasm_set_exception(module, "unknown function");
                    goto got_exception;
                }

                /* always call module own functions */
                cur_func = module->e->functions + fidx;

                if (cur_func->is_import_func)
                    cur_func_type = cur_func->u.func_import->func_type;
                else
                    cur_func_type = cur_func->u.func->func_type;

                    /* clang-format off */
#if WASM_ENABLE_GC == 0
                if (cur_type != cur_func_type) {
                    wasm_set_exception(module, "indirect call type mismatch");
                    goto got_exception;
                }
#else
                if (!wasm_func_type_is_super_of(cur_type, cur_func_type)) {
                    wasm_set_exception(module, "indirect call type mismatch");
                    goto got_exception;
                }
#endif
                /* clang-format on */

#if WASM_ENABLE_TAIL_CALL != 0
                if (opcode == WASM_OP_RETURN_CALL_INDIRECT)
                    goto call_func_from_return_call;
#endif
                goto call_func_from_interp;
            }

#if WASM_ENABLE_EXCE_HANDLING != 0
            HANDLE_OP(WASM_OP_TRY)
            HANDLE_OP(WASM_OP_CATCH)
            HANDLE_OP(WASM_OP_THROW)
            HANDLE_OP(WASM_OP_RETHROW)
            HANDLE_OP(WASM_OP_DELEGATE)
            HANDLE_OP(WASM_OP_CATCH_ALL)
            HANDLE_OP(EXT_OP_TRY)
            {
                wasm_set_exception(module, "unsupported opcode");
                goto got_exception;
            }
#endif

            /* parametric instructions */
            HANDLE_OP(WASM_OP_SELECT)
            {
                cond = frame_lp[GET_OFFSET()];
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                if (!cond) {
                    if (addr_ret != addr1)
                        frame_lp[addr_ret] = frame_lp[addr1];
                }
                else {
                    if (addr_ret != addr2)
                        frame_lp[addr_ret] = frame_lp[addr2];
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SELECT_64)
            {
                cond = frame_lp[GET_OFFSET()];
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                if (!cond) {
                    if (addr_ret != addr1)
                        PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                        GET_I64_FROM_ADDR(frame_lp + addr1));
                }
                else {
                    if (addr_ret != addr2)
                        PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                        GET_I64_FROM_ADDR(frame_lp + addr2));
                }
                HANDLE_OP_END();
            }
#if WASM_ENABLE_SIMDE != 0
            HANDLE_OP(WASM_OP_SELECT_128)
            {
                cond = frame_lp[GET_OFFSET()];
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                if (!cond) {
                    if (addr_ret != addr1)
                        PUT_V128_TO_ADDR(frame_lp + addr_ret,
                                         GET_V128_FROM_ADDR(frame_lp + addr1));
                }
                else {
                    if (addr_ret != addr2)
                        PUT_V128_TO_ADDR(frame_lp + addr_ret,
                                         GET_V128_FROM_ADDR(frame_lp + addr2));
                }
                HANDLE_OP_END();
            }
#endif

#if WASM_ENABLE_GC != 0
            HANDLE_OP(WASM_OP_SELECT_T)
            {
                cond = frame_lp[GET_OFFSET()];
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                if (!cond) {
                    if (addr_ret != addr1)
                        PUT_REF_TO_ADDR(frame_lp + addr_ret,
                                        GET_REF_FROM_ADDR(frame_lp + addr1));
                }
                else {
                    if (addr_ret != addr2)
                        PUT_REF_TO_ADDR(frame_lp + addr_ret,
                                        GET_REF_FROM_ADDR(frame_lp + addr2));
                }
                {
                    uint8 orig_ref = 0;
                    /* Ignore constants because they are not reference */
                    if (addr1 >= 0) {
                        orig_ref = *FRAME_REF(addr1);
                        CLEAR_FRAME_REF(addr1);
                    }
                    if (addr2 >= 0) {
                        CLEAR_FRAME_REF(addr2);
                    }
                    if (orig_ref) {
                        SET_FRAME_REF(addr_ret);
                    }
                }

                HANDLE_OP_END();
            }
#endif

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            HANDLE_OP(WASM_OP_TABLE_GET)
            {
                uint32 tbl_idx, elem_idx;
                WASMTableInstance *tbl_inst;

                tbl_idx = read_uint32(frame_ip);
                bh_assert(tbl_idx < module->table_count);

                tbl_inst = wasm_get_table_inst(module, tbl_idx);

                elem_idx = POP_I32();
                if (elem_idx >= tbl_inst->cur_size) {
                    wasm_set_exception(module, "out of bounds table access");
                    goto got_exception;
                }

#if WASM_ENABLE_GC == 0
                PUSH_I32(tbl_inst->elems[elem_idx]);
#else
                PUSH_REF(tbl_inst->elems[elem_idx]);
#endif
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_TABLE_SET)
            {
                uint32 tbl_idx, elem_idx;
                WASMTableInstance *tbl_inst;
                table_elem_type_t elem_val;

                tbl_idx = read_uint32(frame_ip);
                bh_assert(tbl_idx < module->table_count);

                tbl_inst = wasm_get_table_inst(module, tbl_idx);

#if WASM_ENABLE_GC == 0
                elem_val = POP_I32();
#else
                elem_val = POP_REF();
#endif
                elem_idx = POP_I32();
                if (elem_idx >= tbl_inst->cur_size) {
                    wasm_set_exception(module, "out of bounds table access");
                    goto got_exception;
                }

                tbl_inst->elems[elem_idx] = elem_val;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_REF_NULL)
            {
#if WASM_ENABLE_GC == 0
                PUSH_I32(NULL_REF);
#else
                PUSH_REF(NULL_REF);
#endif
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_REF_IS_NULL)
            {
#if WASM_ENABLE_GC == 0
                uint32 ref_val;
                ref_val = POP_I32();
#else
                void *ref_val;
                ref_val = POP_REF();
#endif
                PUSH_I32(ref_val == NULL_REF ? 1 : 0);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_REF_FUNC)
            {
                uint32 func_idx = read_uint32(frame_ip);

#if WASM_ENABLE_GC == 0
                PUSH_I32(func_idx);
#else
                SYNC_ALL_TO_FRAME();
                if (!(gc_obj = wasm_create_func_obj(module, func_idx, true,
                                                    NULL, 0))) {
                    goto got_exception;
                }
                PUSH_REF(gc_obj);
#endif
                HANDLE_OP_END();
            }
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

#if WASM_ENABLE_GC != 0
            HANDLE_OP(WASM_OP_CALL_REF)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                func_obj = POP_REF();
                if (!func_obj) {
                    wasm_set_exception(module, "null function reference");
                    goto got_exception;
                }

                fidx = wasm_func_obj_get_func_idx_bound(func_obj);
                cur_func = module->e->functions + fidx;
                goto call_func_from_interp;
            }
            HANDLE_OP(WASM_OP_RETURN_CALL_REF)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                func_obj = POP_REF();
                if (!func_obj) {
                    wasm_set_exception(module, "null function reference");
                    goto got_exception;
                }

                fidx = wasm_func_obj_get_func_idx_bound(func_obj);
                cur_func = module->e->functions + fidx;
                goto call_func_from_return_call;
            }
            HANDLE_OP(WASM_OP_REF_AS_NON_NULL)
            {
                gc_obj = POP_REF();
                if (gc_obj == NULL_REF) {
                    wasm_set_exception(module, "null reference");
                    goto got_exception;
                }
                PUSH_REF(gc_obj);
                HANDLE_OP_END();
            }
            HANDLE_OP(WASM_OP_REF_EQ)
            {
                WASMObjectRef gc_obj1, gc_obj2;
                gc_obj2 = POP_REF();
                gc_obj1 = POP_REF();
                val = wasm_obj_equal(gc_obj1, gc_obj2);
                PUSH_I32(val);
                HANDLE_OP_END();
            }
            HANDLE_OP(WASM_OP_BR_ON_NULL)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                opnd_off = GET_OFFSET();
                gc_obj = GET_REF_FROM_ADDR(frame_lp + opnd_off);
                if (gc_obj == NULL_REF) {
                    CLEAR_FRAME_REF(opnd_off);
                    goto recover_br_info;
                }
                else {
                    SKIP_BR_INFO();
                }
                HANDLE_OP_END();
            }
            HANDLE_OP(WASM_OP_BR_ON_NON_NULL)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                opnd_off = GET_OFFSET();
                gc_obj = GET_REF_FROM_ADDR(frame_lp + opnd_off);
                if (gc_obj != NULL_REF) {
                    goto recover_br_info;
                }
                else {
                    CLEAR_FRAME_REF(opnd_off);
                    SKIP_BR_INFO();
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_GC_PREFIX)
            {
                GET_OPCODE();

                switch (opcode) {
                    case WASM_OP_STRUCT_NEW:
                    case WASM_OP_STRUCT_NEW_DEFAULT:
                    {
                        WASMModule *wasm_module = module->module;
                        WASMStructType *struct_type;
                        WASMRttType *rtt_type;
                        WASMValue field_value = { 0 };

                        type_idx = read_uint32(frame_ip);
                        struct_type =
                            (WASMStructType *)module->module->types[type_idx];

                        if (!(rtt_type = wasm_rtt_type_new(
                                  (WASMType *)struct_type, type_idx,
                                  wasm_module->rtt_types,
                                  wasm_module->type_count,
                                  &wasm_module->rtt_type_lock))) {
                            wasm_set_exception(module,
                                               "create rtt type failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        struct_obj = wasm_struct_obj_new(exec_env, rtt_type);
                        if (!struct_obj) {
                            wasm_set_exception(module,
                                               "create struct object failed");
                            goto got_exception;
                        }

                        if (opcode == WASM_OP_STRUCT_NEW) {
                            WASMStructFieldType *fields = struct_type->fields;
                            int32 field_count = (int32)struct_type->field_count;
                            int32 field_idx;
                            uint8 field_type;

                            for (field_idx = field_count - 1; field_idx >= 0;
                                 field_idx--) {
                                field_type = fields[field_idx].field_type;
                                if (wasm_is_type_reftype(field_type)) {
                                    field_value.gc_obj = POP_REF();
                                }
                                else if (field_type == VALUE_TYPE_I32
                                         || field_type == VALUE_TYPE_F32
                                         || field_type == PACKED_TYPE_I8
                                         || field_type == PACKED_TYPE_I16) {
                                    field_value.i32 = POP_I32();
                                }
                                else {
                                    field_value.i64 = POP_I64();
                                }
                                wasm_struct_obj_set_field(struct_obj, field_idx,
                                                          &field_value);
                            }
                        }
                        PUSH_REF(struct_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRUCT_GET:
                    case WASM_OP_STRUCT_GET_S:
                    case WASM_OP_STRUCT_GET_U:
                    {
                        WASMStructType *struct_type;
                        WASMValue field_value = { 0 };
                        uint32 field_idx;
                        uint8 field_type;

                        type_idx = read_uint32(frame_ip);
                        field_idx = read_uint32(frame_ip);

                        struct_type =
                            (WASMStructType *)module->module->types[type_idx];

                        struct_obj = POP_REF();

                        if (!struct_obj) {
                            wasm_set_exception(module,
                                               "null structure reference");
                            goto got_exception;
                        }

                        wasm_struct_obj_get_field(
                            struct_obj, field_idx,
                            opcode == WASM_OP_STRUCT_GET_S ? true : false,
                            &field_value);

                        field_type = struct_type->fields[field_idx].field_type;
                        if (wasm_is_reftype_i31ref(field_type)) {
                            PUSH_I31REF(field_value.gc_obj);
                        }
                        else if (wasm_is_type_reftype(field_type)) {
                            PUSH_REF(field_value.gc_obj);
                        }
                        else if (field_type == VALUE_TYPE_I32
                                 || field_type == VALUE_TYPE_F32
                                 || field_type == PACKED_TYPE_I8
                                 || field_type == PACKED_TYPE_I16) {
                            PUSH_I32(field_value.i32);
                        }
                        else {
                            PUSH_I64(field_value.i64);
                        }
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRUCT_SET:
                    {
                        WASMStructType *struct_type;
                        WASMValue field_value = { 0 };
                        uint32 field_idx;
                        uint8 field_type;

                        type_idx = read_uint32(frame_ip);
                        field_idx = read_uint32(frame_ip);

                        struct_type =
                            (WASMStructType *)module->module->types[type_idx];
                        field_type = struct_type->fields[field_idx].field_type;

                        if (wasm_is_type_reftype(field_type)) {
                            field_value.gc_obj = POP_REF();
                        }
                        else if (field_type == VALUE_TYPE_I32
                                 || field_type == VALUE_TYPE_F32
                                 || field_type == PACKED_TYPE_I8
                                 || field_type == PACKED_TYPE_I16) {
                            field_value.i32 = POP_I32();
                        }
                        else {
                            field_value.i64 = POP_I64();
                        }

                        struct_obj = POP_REF();
                        if (!struct_obj) {
                            wasm_set_exception(module,
                                               "null structure reference");
                            goto got_exception;
                        }

                        wasm_struct_obj_set_field(struct_obj, field_idx,
                                                  &field_value);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_ARRAY_NEW:
                    case WASM_OP_ARRAY_NEW_DEFAULT:
                    case WASM_OP_ARRAY_NEW_FIXED:
                    {
                        WASMModule *wasm_module = module->module;
                        WASMArrayType *array_type;
                        WASMRttType *rtt_type;
                        WASMValue array_elem = { 0 };
                        uint32 array_len, i;

                        type_idx = read_uint32(frame_ip);
                        array_type =
                            (WASMArrayType *)wasm_module->types[type_idx];

                        if (!(rtt_type = wasm_rtt_type_new(
                                  (WASMType *)array_type, type_idx,
                                  wasm_module->rtt_types,
                                  wasm_module->type_count,
                                  &wasm_module->rtt_type_lock))) {
                            wasm_set_exception(module,
                                               "create rtt type failed");
                            goto got_exception;
                        }

                        if (opcode != WASM_OP_ARRAY_NEW_FIXED)
                            array_len = POP_I32();
                        else
                            array_len = read_uint32(frame_ip);

                        if (opcode == WASM_OP_ARRAY_NEW) {
                            if (wasm_is_type_reftype(array_type->elem_type)) {
                                array_elem.gc_obj = POP_REF();
                            }
                            else if (array_type->elem_type == VALUE_TYPE_I32
                                     || array_type->elem_type == VALUE_TYPE_F32
                                     || array_type->elem_type == PACKED_TYPE_I8
                                     || array_type->elem_type
                                            == PACKED_TYPE_I16) {
                                array_elem.i32 = POP_I32();
                            }
                            else {
                                array_elem.i64 = POP_I64();
                            }
                        }

                        SYNC_ALL_TO_FRAME();
                        array_obj = wasm_array_obj_new(exec_env, rtt_type,
                                                       array_len, &array_elem);
                        if (!array_obj) {
                            wasm_set_exception(module,
                                               "create array object failed");
                            goto got_exception;
                        }

                        if (opcode == WASM_OP_ARRAY_NEW_FIXED) {
                            for (i = 0; i < array_len; i++) {
                                if (wasm_is_type_reftype(
                                        array_type->elem_type)) {
                                    array_elem.gc_obj = POP_REF();
                                }
                                else if (array_type->elem_type == VALUE_TYPE_I32
                                         || array_type->elem_type
                                                == VALUE_TYPE_F32
                                         || array_type->elem_type
                                                == PACKED_TYPE_I8
                                         || array_type->elem_type
                                                == PACKED_TYPE_I16) {
                                    array_elem.i32 = POP_I32();
                                }
                                else {
                                    array_elem.i64 = POP_I64();
                                }
                                wasm_array_obj_set_elem(
                                    array_obj, array_len - 1 - i, &array_elem);
                            }
                        }

                        PUSH_REF(array_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_ARRAY_NEW_DATA:
                    {
                        WASMModule *wasm_module = module->module;
                        WASMArrayType *array_type;
                        WASMRttType *rtt_type;
                        WASMValue array_elem = { 0 };
                        WASMDataSeg *data_seg;
                        uint8 *array_elem_base;
                        uint32 array_len, data_seg_idx, data_seg_offset;
                        uint32 elem_size = 0;
                        uint64 total_size;

                        type_idx = read_uint32(frame_ip);
                        data_seg_idx = read_uint32(frame_ip);
                        data_seg = wasm_module->data_segments[data_seg_idx];

                        array_type =
                            (WASMArrayType *)wasm_module->types[type_idx];

                        if (!(rtt_type = wasm_rtt_type_new(
                                  (WASMType *)array_type, type_idx,
                                  wasm_module->rtt_types,
                                  wasm_module->type_count,
                                  &wasm_module->rtt_type_lock))) {
                            wasm_set_exception(module,
                                               "create rtt type failed");
                            goto got_exception;
                        }

                        array_len = POP_I32();
                        data_seg_offset = POP_I32();

                        switch (array_type->elem_type) {
                            case PACKED_TYPE_I8:
                                elem_size = 1;
                                break;
                            case PACKED_TYPE_I16:
                                elem_size = 2;
                                break;
                            case VALUE_TYPE_I32:
                            case VALUE_TYPE_F32:
                                elem_size = 4;
                                break;
                            case VALUE_TYPE_I64:
                            case VALUE_TYPE_F64:
                                elem_size = 8;
                                break;
                            default:
                                bh_assert(0);
                        }

                        total_size = (uint64)elem_size * array_len;
                        if (data_seg_offset >= data_seg->data_length
                            || total_size
                                   > data_seg->data_length - data_seg_offset) {
                            wasm_set_exception(module,
                                               "data segment out of bounds");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        array_obj = wasm_array_obj_new(exec_env, rtt_type,
                                                       array_len, &array_elem);
                        if (!array_obj) {
                            wasm_set_exception(module,
                                               "create array object failed");
                            goto got_exception;
                        }

                        array_elem_base =
                            (uint8 *)wasm_array_obj_first_elem_addr(array_obj);
                        bh_memcpy_s(array_elem_base, (uint32)total_size,
                                    data_seg->data + data_seg_offset,
                                    (uint32)total_size);

                        PUSH_REF(array_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_ARRAY_NEW_ELEM:
                    {
                        /* TODO */
                        wasm_set_exception(module, "unsupported opcode");
                        goto got_exception;
                    }
                    case WASM_OP_ARRAY_GET:
                    case WASM_OP_ARRAY_GET_S:
                    case WASM_OP_ARRAY_GET_U:
                    {
                        WASMArrayType *array_type;
                        WASMValue array_elem = { 0 };
                        uint32 elem_idx, elem_size_log;

                        type_idx = read_uint32(frame_ip);
                        array_type =
                            (WASMArrayType *)module->module->types[type_idx];

                        elem_idx = POP_I32();
                        array_obj = POP_REF();

                        if (!array_obj) {
                            wasm_set_exception(module, "null array reference");
                            goto got_exception;
                        }
                        if (elem_idx >= wasm_array_obj_length(array_obj)) {
                            wasm_set_exception(module,
                                               "out of bounds array access");
                            goto got_exception;
                        }

                        wasm_array_obj_get_elem(
                            array_obj, elem_idx,
                            opcode == WASM_OP_ARRAY_GET_S ? true : false,
                            &array_elem);
                        elem_size_log = wasm_array_obj_elem_size_log(array_obj);

                        if (wasm_is_reftype_i31ref(array_type->elem_type)) {
                            PUSH_I31REF(array_elem.gc_obj);
                        }
                        else if (wasm_is_type_reftype(array_type->elem_type)) {
                            PUSH_REF(array_elem.gc_obj);
                        }
                        else if (elem_size_log < 3) {
                            PUSH_I32(array_elem.i32);
                        }
                        else {
                            PUSH_I64(array_elem.i64);
                        }
                        HANDLE_OP_END();
                    }
                    case WASM_OP_ARRAY_SET:
                    {
                        WASMArrayType *array_type;
                        WASMValue array_elem = { 0 };
                        uint32 elem_idx;

                        type_idx = read_uint32(frame_ip);
                        array_type =
                            (WASMArrayType *)module->module->types[type_idx];
                        if (wasm_is_type_reftype(array_type->elem_type)) {
                            array_elem.gc_obj = POP_REF();
                        }
                        else if (array_type->elem_type == VALUE_TYPE_I32
                                 || array_type->elem_type == VALUE_TYPE_F32
                                 || array_type->elem_type == PACKED_TYPE_I8
                                 || array_type->elem_type == PACKED_TYPE_I16) {
                            array_elem.i32 = POP_I32();
                        }
                        else {
                            array_elem.i64 = POP_I64();
                        }

                        elem_idx = POP_I32();
                        array_obj = POP_REF();

                        if (!array_obj) {
                            wasm_set_exception(module, "null array reference");
                            goto got_exception;
                        }
                        if (elem_idx >= wasm_array_obj_length(array_obj)) {
                            wasm_set_exception(module,
                                               "out of bounds array access");
                            goto got_exception;
                        }

                        wasm_array_obj_set_elem(array_obj, elem_idx,
                                                &array_elem);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_ARRAY_LEN:
                    {
                        uint32 array_len;
                        array_obj = POP_REF();
                        if (!array_obj) {
                            wasm_set_exception(module, "null array reference");
                            goto got_exception;
                        }
                        array_len = wasm_array_obj_length(array_obj);
                        PUSH_I32(array_len);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_ARRAY_FILL:
                    {
                        WASMArrayType *array_type;
                        WASMValue fill_value = { 0 };
                        uint32 start_offset, len;

                        type_idx = read_uint32(frame_ip);

                        array_type =
                            (WASMArrayType *)module->module->types[type_idx];

                        len = POP_I32();
                        if (wasm_is_type_reftype(array_type->elem_type)) {
                            fill_value.gc_obj = POP_REF();
                        }
                        else if (array_type->elem_type == VALUE_TYPE_I32
                                 || array_type->elem_type == VALUE_TYPE_F32
                                 || array_type->elem_type == PACKED_TYPE_I8
                                 || array_type->elem_type == PACKED_TYPE_I16) {
                            fill_value.i32 = POP_I32();
                        }
                        else {
                            fill_value.i64 = POP_I64();
                        }
                        start_offset = POP_I32();
                        array_obj = POP_REF();

                        if (!array_obj) {
                            wasm_set_exception(module, "null array reference");
                            goto got_exception;
                        }

                        if (len > 0) {
                            if ((uint64)start_offset + len
                                >= wasm_array_obj_length(array_obj)) {
                                wasm_set_exception(
                                    module, "out of bounds array access");
                                goto got_exception;
                            }

                            wasm_array_obj_fill(array_obj, start_offset, len,
                                                &fill_value);
                        }

                        HANDLE_OP_END();
                    }
                    case WASM_OP_ARRAY_COPY:
                    {
                        uint32 dst_offset, src_offset, len, src_type_index;
                        WASMArrayObjectRef src_obj, dst_obj;

                        type_idx = read_uint32(frame_ip);
                        src_type_index = read_uint32(frame_ip);

                        len = POP_I32();
                        src_offset = POP_I32();
                        src_obj = POP_REF();
                        dst_offset = POP_I32();
                        dst_obj = POP_REF();

                        if (!src_obj || !dst_obj) {
                            wasm_set_exception(module, "null array reference");
                            goto got_exception;
                        }

                        if (len > 0) {
                            if ((dst_offset > UINT32_MAX - len)
                                || (dst_offset + len
                                    > wasm_array_obj_length(dst_obj))
                                || (src_offset > UINT32_MAX - len)
                                || (src_offset + len
                                    > wasm_array_obj_length(src_obj))) {
                                wasm_set_exception(
                                    module, "out of bounds array access");
                                goto got_exception;
                            }

                            wasm_array_obj_copy(dst_obj, dst_offset, src_obj,
                                                src_offset, len);
                        }

                        (void)src_type_index;
                        HANDLE_OP_END();
                    }

                    case WASM_OP_REF_I31:
                    {
                        uint32 i31_val;

                        i31_val = POP_I32();
                        i31_obj = wasm_i31_obj_new(i31_val);
                        PUSH_I31REF(i31_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_I31_GET_S:
                    case WASM_OP_I31_GET_U:
                    {
                        uint32 i31_val;

                        i31_obj = (WASMI31ObjectRef)POP_REF();
                        if (!i31_obj) {
                            wasm_set_exception(module, "null i31 reference");
                            goto got_exception;
                        }
                        i31_val = (uint32)(((uintptr_t)i31_obj) >> 1);
                        if (opcode == WASM_OP_I31_GET_S
                            && (i31_val & 0x40000000) /* bit 30 is 1 */)
                            /* set bit 31 to 1 */
                            i31_val |= 0x80000000;
                        PUSH_I32(i31_val);
                        HANDLE_OP_END();
                    }

                    case WASM_OP_REF_TEST:
                    case WASM_OP_REF_CAST:
                    case WASM_OP_REF_TEST_NULLABLE:
                    case WASM_OP_REF_CAST_NULLABLE:
                    {
                        int32 heap_type;

                        heap_type = (int32)read_uint32(frame_ip);

                        gc_obj = POP_REF();
                        if (!gc_obj) {
                            if (opcode == WASM_OP_REF_TEST
                                || opcode == WASM_OP_REF_TEST_NULLABLE) {
                                if (opcode == WASM_OP_REF_TEST)
                                    PUSH_I32(0);
                                else
                                    PUSH_I32(1);
                            }
                            else if (opcode == WASM_OP_REF_CAST) {
                                wasm_set_exception(module, "cast failure");
                                goto got_exception;
                            }
                            else {
                                PUSH_REF(gc_obj);
                            }
                        }
                        else {
                            bool castable = false;

                            if (heap_type >= 0) {
                                WASMModule *wasm_module = module->module;
                                castable = wasm_obj_is_instance_of(
                                    gc_obj, (uint32)heap_type,
                                    wasm_module->types,
                                    wasm_module->type_count);
                            }
                            else {
                                castable =
                                    wasm_obj_is_type_of(gc_obj, heap_type);
                            }

                            if (opcode == WASM_OP_REF_TEST
                                || opcode == WASM_OP_REF_TEST_NULLABLE) {
                                if (castable)
                                    PUSH_I32(1);
                                else
                                    PUSH_I32(0);
                            }
                            else if (!castable) {
                                wasm_set_exception(module, "cast failure");
                                goto got_exception;
                            }
                            else {
                                PUSH_REF(gc_obj);
                            }
                        }
                        HANDLE_OP_END();
                    }

                    case WASM_OP_BR_ON_CAST:
                    case WASM_OP_BR_ON_CAST_FAIL:
                    {
                        int32 heap_type, heap_type_dst;
                        uint8 castflags;
                        uint16 opnd_off_br;

#if WASM_ENABLE_THREAD_MGR != 0
                        CHECK_SUSPEND_FLAGS();
#endif
                        castflags = *frame_ip++;
                        heap_type = (int32)read_uint32(frame_ip);
                        heap_type_dst = (int32)read_uint32(frame_ip);

                        opnd_off = GET_OFFSET();
                        opnd_off_br = GET_OFFSET();
                        gc_obj = GET_REF_FROM_ADDR(frame_lp + opnd_off);
                        PUT_REF_TO_ADDR(frame_lp + opnd_off_br, gc_obj);

                        if (!gc_obj) {
                            /*
                             * castflags should be 0~3:
                             *  0: (non-null, non-null)
                             *  1: (null, non-null)
                             *  2: (non-null, null)
                             *  3: (null, null)
                             */
                            if (
                                /* op is BR_ON_CAST and dst reftype is nullable
                                 */
                                ((opcode == WASM_OP_BR_ON_CAST)
                                 && ((castflags == 2) || (castflags == 3)))
                                /* op is BR_ON_CAST_FAIL and dst reftype is
                                   non-nullable */
                                || ((opcode == WASM_OP_BR_ON_CAST_FAIL)
                                    && ((castflags == 0)
                                        || (castflags == 1)))) {
                                CLEAR_FRAME_REF(opnd_off);
                                if (!wasm_is_reftype_i31ref(heap_type)) {
                                    SET_FRAME_REF(opnd_off_br);
                                }
                                goto recover_br_info;
                            }
                        }
                        else {
                            bool castable = false;

                            if (heap_type_dst >= 0) {
                                WASMModule *wasm_module = module->module;
                                castable = wasm_obj_is_instance_of(
                                    gc_obj, (uint32)heap_type_dst,
                                    wasm_module->types,
                                    wasm_module->type_count);
                            }
                            else {
                                castable =
                                    wasm_obj_is_type_of(gc_obj, heap_type_dst);
                            }

                            if ((castable && (opcode == WASM_OP_BR_ON_CAST))
                                || (!castable
                                    && (opcode == WASM_OP_BR_ON_CAST_FAIL))) {
                                CLEAR_FRAME_REF(opnd_off);
                                if (!wasm_is_reftype_i31ref(heap_type)) {
                                    SET_FRAME_REF(opnd_off_br);
                                }
                                goto recover_br_info;
                            }
                        }
                        SKIP_BR_INFO();

                        (void)heap_type_dst;
                        HANDLE_OP_END();
                    }

                    case WASM_OP_ANY_CONVERT_EXTERN:
                    {
                        externref_obj = POP_REF();
                        if (externref_obj == NULL_REF)
                            PUSH_REF(NULL_REF);
                        else {
                            gc_obj = wasm_externref_obj_to_internal_obj(
                                externref_obj);
                            PUSH_REF(gc_obj);
                        }
                        HANDLE_OP_END();
                    }
                    case WASM_OP_EXTERN_CONVERT_ANY:
                    {
                        gc_obj = POP_REF();
                        if (gc_obj == NULL_REF)
                            PUSH_REF(NULL_REF);
                        else {
                            if (!(externref_obj =
                                      wasm_internal_obj_to_externref_obj(
                                          exec_env, gc_obj))) {
                                wasm_set_exception(
                                    module, "create externref object failed");
                                goto got_exception;
                            }
                            PUSH_REF(externref_obj);
                        }
                        HANDLE_OP_END();
                    }

#if WASM_ENABLE_STRINGREF != 0
                    case WASM_OP_STRING_NEW_UTF8:
                    case WASM_OP_STRING_NEW_WTF16:
                    case WASM_OP_STRING_NEW_LOSSY_UTF8:
                    case WASM_OP_STRING_NEW_WTF8:
                    {
                        uint32 mem_idx, addr, bytes_length, offset = 0;
                        EncodingFlag flag = WTF8;

                        mem_idx = (uint32)read_uint32(frame_ip);
                        bytes_length = POP_I32();
                        addr = POP_I32();

                        CHECK_MEMORY_OVERFLOW(bytes_length);

                        if (opcode == WASM_OP_STRING_NEW_WTF16) {
                            flag = WTF16;
                        }
                        else if (opcode == WASM_OP_STRING_NEW_UTF8) {
                            flag = UTF8;
                        }
                        else if (opcode == WASM_OP_STRING_NEW_LOSSY_UTF8) {
                            flag = LOSSY_UTF8;
                        }
                        else if (opcode == WASM_OP_STRING_NEW_WTF8) {
                            flag = WTF8;
                        }

                        str_obj = wasm_string_new_with_encoding(
                            maddr, bytes_length, flag);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringref_obj =
                            wasm_stringref_obj_new(exec_env, str_obj);
                        if (!stringref_obj) {
                            wasm_set_exception(module,
                                               "create stringref failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringref_obj);

                        (void)mem_idx;
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_CONST:
                    {
                        WASMModule *wasm_module = module->module;
                        uint32 contents;

                        contents = (uint32)read_uint32(frame_ip);

                        str_obj = wasm_string_new_const(
                            (const char *)
                                wasm_module->string_literal_ptrs[contents],
                            wasm_module->string_literal_lengths[contents]);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringref_obj =
                            wasm_stringref_obj_new(exec_env, str_obj);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create stringref failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringref_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_MEASURE_UTF8:
                    case WASM_OP_STRING_MEASURE_WTF8:
                    case WASM_OP_STRING_MEASURE_WTF16:
                    {
                        int32 target_bytes_length;
                        EncodingFlag flag = WTF8;

                        stringref_obj = POP_REF();

                        if (opcode == WASM_OP_STRING_MEASURE_WTF16) {
                            flag = WTF16;
                        }
                        else if (opcode == WASM_OP_STRING_MEASURE_UTF8) {
                            flag = UTF8;
                        }
                        else if (opcode == WASM_OP_STRING_MEASURE_WTF8) {
                            flag = LOSSY_UTF8;
                        }
                        target_bytes_length = wasm_string_measure(
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj),
                            flag);

                        PUSH_I32(target_bytes_length);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_ENCODE_UTF8:
                    case WASM_OP_STRING_ENCODE_WTF16:
                    case WASM_OP_STRING_ENCODE_LOSSY_UTF8:
                    case WASM_OP_STRING_ENCODE_WTF8:
                    {
                        uint32 mem_idx, addr;
                        int32 target_bytes_length;
                        WASMMemoryInstance *memory_inst;
                        EncodingFlag flag = WTF8;

                        mem_idx = (uint32)read_uint32(frame_ip);
                        addr = POP_I32();
                        stringref_obj = POP_REF();

                        str_obj = (WASMString)wasm_stringref_obj_get_value(
                            stringref_obj);

#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)addr, 1))
                            shared_heap_addr_app_to_native((uint64)addr, maddr);
                        else
#endif
                        {
                            memory_inst = module->memories[mem_idx];
                            maddr = memory_inst->memory_data + addr;
                        }

                        if (opcode == WASM_OP_STRING_ENCODE_WTF16) {
                            flag = WTF16;
                            count = wasm_string_measure(str_obj, flag);
                            target_bytes_length = wasm_string_encode(
                                str_obj, 0, count, maddr, NULL, flag);
                        }
                        else {
                            if (opcode == WASM_OP_STRING_ENCODE_UTF8) {
                                flag = UTF8;
                            }
                            else if (opcode
                                     == WASM_OP_STRING_ENCODE_LOSSY_UTF8) {
                                flag = LOSSY_UTF8;
                            }
                            else if (opcode == WASM_OP_STRING_ENCODE_WTF8) {
                                flag = WTF8;
                            }
                            count = wasm_string_measure(str_obj, flag);
                            target_bytes_length = wasm_string_encode(
                                str_obj, 0, count, maddr, NULL, flag);

                            if (target_bytes_length == -1) {
                                wasm_set_exception(
                                    module, "isolated surrogate is seen");
                                goto got_exception;
                            }
                        }
                        if (target_bytes_length < 0) {
                            wasm_set_exception(module,
                                               "stringref encode failed");
                            goto got_exception;
                        }

                        PUSH_I32(target_bytes_length);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_CONCAT:
                    {
                        WASMStringrefObjectRef stringref_obj1, stringref_obj2;

                        stringref_obj2 = POP_REF();
                        stringref_obj1 = POP_REF();

                        str_obj = wasm_string_concat(
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj1),
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj2));
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringref_obj =
                            wasm_stringref_obj_new(exec_env, str_obj);
                        if (!stringref_obj) {
                            wasm_set_exception(module,
                                               "create stringref failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringref_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_EQ:
                    {
                        WASMStringrefObjectRef stringref_obj1, stringref_obj2;
                        int32 is_eq;

                        stringref_obj2 = POP_REF();
                        stringref_obj1 = POP_REF();

                        is_eq = wasm_string_eq(
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj1),
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj2));

                        PUSH_I32(is_eq);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_IS_USV_SEQUENCE:
                    {
                        int32 is_usv_sequence;

                        stringref_obj = POP_REF();

                        is_usv_sequence = wasm_string_is_usv_sequence(
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj));

                        PUSH_I32(is_usv_sequence);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_AS_WTF8:
                    {
                        stringref_obj = POP_REF();

                        str_obj = wasm_string_create_view(
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj),
                            STRING_VIEW_WTF8);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringview_wtf8_obj =
                            wasm_stringview_wtf8_obj_new(exec_env, str_obj);
                        if (!stringview_wtf8_obj) {
                            wasm_set_exception(module,
                                               "create stringview wtf8 failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringview_wtf8_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_WTF8_ADVANCE:
                    {
                        uint32 next_pos, bytes, pos;

                        bytes = POP_I32();
                        pos = POP_I32();
                        stringview_wtf8_obj = POP_REF();

                        next_pos = wasm_string_advance(
                            (WASMString)wasm_stringview_wtf8_obj_get_value(
                                stringview_wtf8_obj),
                            pos, bytes, NULL);

                        PUSH_I32(next_pos);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_UTF8:
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_LOSSY_UTF8:
                    case WASM_OP_STRINGVIEW_WTF8_ENCODE_WTF8:
                    {
                        uint32 mem_idx, addr, pos, bytes, next_pos;
                        int32 bytes_written;
                        WASMMemoryInstance *memory_inst;
                        EncodingFlag flag = WTF8;

                        if (opcode == WASM_OP_STRINGVIEW_WTF8_ENCODE_UTF8) {
                            flag = UTF8;
                        }
                        else if (opcode
                                 == WASM_OP_STRINGVIEW_WTF8_ENCODE_LOSSY_UTF8) {
                            flag = LOSSY_UTF8;
                        }
                        else if (opcode
                                 == WASM_OP_STRINGVIEW_WTF8_ENCODE_WTF8) {
                            flag = WTF8;
                        }

                        mem_idx = (uint32)read_uint32(frame_ip);
                        bytes = POP_I32();
                        pos = POP_I32();
                        addr = POP_I32();
                        stringview_wtf8_obj = POP_REF();

#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)addr, 1))
                            shared_heap_addr_app_to_native((uint64)addr, maddr);
                        else
#endif
                        {
                            memory_inst = module->memories[mem_idx];
                            maddr = memory_inst->memory_data + addr;
                        }

                        bytes_written = wasm_string_encode(
                            (WASMString)wasm_stringview_wtf8_obj_get_value(
                                stringview_wtf8_obj),
                            pos, bytes, maddr, &next_pos, flag);

                        if (bytes_written < 0) {
                            if (bytes_written == Isolated_Surrogate) {
                                wasm_set_exception(
                                    module, "isolated surrogate is seen");
                            }
                            else {
                                wasm_set_exception(module, "encode failed");
                            }

                            goto got_exception;
                        }

                        PUSH_I32(next_pos);
                        PUSH_I32(bytes_written);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_WTF8_SLICE:
                    {
                        uint32 start, end;

                        end = POP_I32();
                        start = POP_I32();
                        stringview_wtf8_obj = POP_REF();

                        str_obj = wasm_string_slice(
                            (WASMString)wasm_stringview_wtf8_obj_get_value(
                                stringview_wtf8_obj),
                            start, end, STRING_VIEW_WTF8);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringref_obj =
                            wasm_stringref_obj_new(exec_env, str_obj);
                        if (!stringref_obj) {
                            wasm_set_exception(module,
                                               "create stringref failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringref_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_AS_WTF16:
                    {
                        stringref_obj = POP_REF();

                        str_obj = wasm_string_create_view(
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj),
                            STRING_VIEW_WTF16);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringview_wtf16_obj =
                            wasm_stringview_wtf16_obj_new(exec_env, str_obj);
                        if (!stringview_wtf16_obj) {
                            wasm_set_exception(
                                module, "create stringview wtf16 failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringview_wtf16_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_WTF16_LENGTH:
                    {
                        int32 code_units_length;

                        stringview_wtf16_obj = POP_REF();

                        code_units_length = wasm_string_wtf16_get_length(
                            (WASMString)wasm_stringview_wtf16_obj_get_value(
                                stringview_wtf16_obj));

                        PUSH_I32(code_units_length);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_WTF16_GET_CODEUNIT:
                    {
                        int32 pos;
                        uint32 code_unit;

                        pos = POP_I32();
                        stringview_wtf16_obj = POP_REF();

                        code_unit = (uint32)wasm_string_get_wtf16_codeunit(
                            (WASMString)wasm_stringview_wtf16_obj_get_value(
                                stringview_wtf16_obj),
                            pos);

                        PUSH_I32(code_unit);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_WTF16_ENCODE:
                    {
                        uint32 mem_idx, addr, pos, len, offset = 0;
                        int32 written_code_units = 0;

                        mem_idx = (uint32)read_uint32(frame_ip);
                        len = POP_I32();
                        pos = POP_I32();
                        addr = POP_I32();
                        stringview_wtf16_obj = POP_REF();

                        CHECK_MEMORY_OVERFLOW(len * sizeof(uint16));

                        /* check 2-byte alignment */
                        if (((uintptr_t)maddr & (((uintptr_t)1 << 2) - 1))
                            != 0) {
                            wasm_set_exception(module,
                                               "unaligned memory access");
                            goto got_exception;
                        }

                        written_code_units = wasm_string_encode(
                            (WASMString)wasm_stringview_wtf16_obj_get_value(
                                stringview_wtf16_obj),
                            pos, len, maddr, NULL, WTF16);

                        PUSH_I32(written_code_units);
                        (void)mem_idx;
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_WTF16_SLICE:
                    {
                        uint32 start, end;

                        end = POP_I32();
                        start = POP_I32();
                        stringview_wtf16_obj = POP_REF();

                        str_obj = wasm_string_slice(
                            (WASMString)wasm_stringview_wtf16_obj_get_value(
                                stringview_wtf16_obj),
                            start, end, STRING_VIEW_WTF16);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringref_obj =
                            wasm_stringref_obj_new(exec_env, str_obj);
                        if (!stringref_obj) {
                            wasm_set_exception(module,
                                               "create stringref failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringref_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_AS_ITER:
                    {
                        stringref_obj = POP_REF();

                        str_obj = wasm_string_create_view(
                            (WASMString)wasm_stringref_obj_get_value(
                                stringref_obj),
                            STRING_VIEW_ITER);

                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringview_iter_obj =
                            wasm_stringview_iter_obj_new(exec_env, str_obj, 0);
                        if (!stringview_iter_obj) {
                            wasm_set_exception(module,
                                               "create stringview iter failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringview_iter_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_ITER_NEXT:
                    {
                        uint32 code_point;

                        stringview_iter_obj = POP_REF();

                        code_point = wasm_string_next_codepoint(
                            (WASMString)wasm_stringview_iter_obj_get_value(
                                stringview_iter_obj),
                            wasm_stringview_iter_obj_get_pos(
                                stringview_iter_obj));

                        PUSH_I32(code_point);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_ITER_ADVANCE:
                    case WASM_OP_STRINGVIEW_ITER_REWIND:
                    {
                        uint32 code_points_count, code_points_consumed = 0,
                                                  cur_pos, next_pos = 0;

                        code_points_count = POP_I32();
                        stringview_iter_obj = POP_REF();

                        str_obj =
                            (WASMString)wasm_stringview_iter_obj_get_value(
                                stringview_iter_obj);
                        cur_pos = wasm_stringview_iter_obj_get_pos(
                            stringview_iter_obj);

                        if (opcode == WASM_OP_STRINGVIEW_ITER_ADVANCE) {
                            next_pos = wasm_string_advance(
                                str_obj, cur_pos, code_points_count,
                                &code_points_consumed);
                        }
                        else if (opcode == WASM_OP_STRINGVIEW_ITER_REWIND) {
                            next_pos = wasm_string_rewind(
                                str_obj, cur_pos, code_points_count,
                                &code_points_consumed);
                        }

                        wasm_stringview_iter_obj_update_pos(stringview_iter_obj,
                                                            next_pos);

                        PUSH_I32(code_points_consumed);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRINGVIEW_ITER_SLICE:
                    {
                        uint32 code_points_count, cur_pos;

                        code_points_count = POP_I32();
                        stringview_iter_obj = POP_REF();

                        cur_pos = wasm_stringview_iter_obj_get_pos(
                            stringview_iter_obj);

                        str_obj = wasm_string_slice(
                            (WASMString)wasm_stringview_iter_obj_get_value(
                                stringview_iter_obj),
                            cur_pos, cur_pos + code_points_count,
                            STRING_VIEW_ITER);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringref_obj =
                            wasm_stringref_obj_new(exec_env, str_obj);
                        if (!stringref_obj) {
                            wasm_set_exception(module,
                                               "create stringref failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringref_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_NEW_UTF8_ARRAY:
                    case WASM_OP_STRING_NEW_WTF16_ARRAY:
                    case WASM_OP_STRING_NEW_LOSSY_UTF8_ARRAY:
                    case WASM_OP_STRING_NEW_WTF8_ARRAY:
                    {
                        uint32 start, end, array_len;
                        EncodingFlag flag = WTF8;
                        WASMArrayType *array_type;
                        void *arr_start_addr;

                        end = POP_I32();
                        start = POP_I32();
                        array_obj = POP_REF();

                        array_type = (WASMArrayType *)wasm_obj_get_defined_type(
                            (WASMObjectRef)array_obj);
                        arr_start_addr =
                            wasm_array_obj_elem_addr(array_obj, start);
                        array_len = wasm_array_obj_length(array_obj);

                        if (start > end || end > array_len) {
                            wasm_set_exception(module,
                                               "out of bounds array access");
                            goto got_exception;
                        }

                        if (opcode == WASM_OP_STRING_NEW_WTF16_ARRAY) {
                            if (array_type->elem_type != VALUE_TYPE_I16) {
                                wasm_set_exception(module,
                                                   "array type mismatch");
                                goto got_exception;
                            }
                            flag = WTF16;
                        }
                        else {
                            if (array_type->elem_type != VALUE_TYPE_I8) {
                                wasm_set_exception(module,
                                                   "array type mismatch");
                                goto got_exception;
                            }
                            if (opcode == WASM_OP_STRING_NEW_UTF8_ARRAY) {
                                flag = UTF8;
                            }
                            else if (opcode == WASM_OP_STRING_NEW_WTF8_ARRAY) {
                                flag = WTF8;
                            }
                            else if (opcode
                                     == WASM_OP_STRING_NEW_LOSSY_UTF8_ARRAY) {
                                flag = LOSSY_UTF8;
                            }
                        }

                        str_obj = wasm_string_new_with_encoding(
                            arr_start_addr, (end - start), flag);
                        if (!str_obj) {
                            wasm_set_exception(module,
                                               "create string object failed");
                            goto got_exception;
                        }

                        SYNC_ALL_TO_FRAME();
                        stringref_obj =
                            wasm_stringref_obj_new(exec_env, str_obj);
                        if (!stringref_obj) {
                            wasm_set_exception(module,
                                               "create stringref failed");
                            goto got_exception;
                        }

                        PUSH_REF(stringref_obj);
                        HANDLE_OP_END();
                    }
                    case WASM_OP_STRING_ENCODE_UTF8_ARRAY:
                    case WASM_OP_STRING_ENCODE_WTF16_ARRAY:
                    case WASM_OP_STRING_ENCODE_LOSSY_UTF8_ARRAY:
                    case WASM_OP_STRING_ENCODE_WTF8_ARRAY:
                    {
                        uint32 start, array_len, count;
                        int32 bytes_written;
                        EncodingFlag flag = WTF8;
                        WASMArrayType *array_type;
                        void *arr_start_addr;

                        start = POP_I32();
                        array_obj = POP_REF();
                        stringref_obj = POP_REF();

                        str_obj = (WASMString)wasm_stringref_obj_get_value(
                            stringref_obj);

                        array_type = (WASMArrayType *)wasm_obj_get_defined_type(
                            (WASMObjectRef)array_obj);
                        arr_start_addr =
                            wasm_array_obj_elem_addr(array_obj, start);
                        array_len = wasm_array_obj_length(array_obj);

                        if (start > array_len) {
                            wasm_set_exception(module,
                                               "out of bounds array access");
                            goto got_exception;
                        }

                        if (opcode == WASM_OP_STRING_ENCODE_WTF16_ARRAY) {
                            if (array_type->elem_type != VALUE_TYPE_I16) {
                                wasm_set_exception(module,
                                                   "array type mismatch");
                                goto got_exception;
                            }
                            flag = WTF16;
                        }
                        else {
                            if (array_type->elem_type != VALUE_TYPE_I8) {
                                wasm_set_exception(module,
                                                   "array type mismatch");
                                goto got_exception;
                            }
                            if (opcode == WASM_OP_STRING_ENCODE_UTF8_ARRAY) {
                                flag = UTF8;
                            }
                            else if (opcode
                                     == WASM_OP_STRING_ENCODE_WTF8_ARRAY) {
                                flag = WTF8;
                            }
                            else if (
                                opcode
                                == WASM_OP_STRING_ENCODE_LOSSY_UTF8_ARRAY) {
                                flag = LOSSY_UTF8;
                            }
                        }

                        count = wasm_string_measure(str_obj, flag);

                        bytes_written = wasm_string_encode(
                            str_obj, 0, count, arr_start_addr, NULL, flag);

                        if (bytes_written < 0) {
                            if (bytes_written == Isolated_Surrogate) {
                                wasm_set_exception(
                                    module, "isolated surrogate is seen");
                            }
                            else if (bytes_written == Insufficient_Space) {
                                wasm_set_exception(
                                    module, "array space is insufficient");
                            }
                            else {
                                wasm_set_exception(module, "encode failed");
                            }

                            goto got_exception;
                        }

                        PUSH_I32(bytes_written);
                        HANDLE_OP_END();
                    }
#endif /* end of WASM_ENABLE_STRINGREF != 0 */

                    default:
                    {
                        wasm_set_exception(module, "unsupported opcode");
                        goto got_exception;
                    }
                }
            }
#endif /* end of WASM_ENABLE_GC != 0 */

            /* variable instructions */
            HANDLE_OP(EXT_OP_SET_LOCAL_FAST)
            HANDLE_OP(EXT_OP_TEE_LOCAL_FAST)
            {
                /* clang-format off */
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                local_offset = *frame_ip++;
#else
                local_offset = *frame_ip;
                frame_ip += 2;
#endif
                /* clang-format on */
                *(uint32 *)(frame_lp + local_offset) =
                    GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_SET_LOCAL_FAST_I64)
            HANDLE_OP(EXT_OP_TEE_LOCAL_FAST_I64)
            {
                /* clang-format off */
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                local_offset = *frame_ip++;
#else
                local_offset = *frame_ip;
                frame_ip += 2;
#endif
                /* clang-format on */
                PUT_I64_TO_ADDR((uint32 *)(frame_lp + local_offset),
                                GET_OPERAND(uint64, I64, 0));
                frame_ip += 2;
                HANDLE_OP_END();
            }

#if WASM_ENABLE_SIMDE != 0
            HANDLE_OP(EXT_OP_SET_LOCAL_FAST_V128)
            HANDLE_OP(EXT_OP_TEE_LOCAL_FAST_V128)
            {
                /* clang-format off */
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
                local_offset = *frame_ip++;
#else
                local_offset = *frame_ip;
                frame_ip += 2;
#endif
                /* clang-format on */
                PUT_V128_TO_ADDR((uint32 *)(frame_lp + local_offset),
                                 GET_OPERAND_V128(0));
                frame_ip += 2;
                HANDLE_OP_END();
            }
#endif
            HANDLE_OP(WASM_OP_GET_GLOBAL)
            {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr_ret = GET_OFFSET();
                /* clang-format off */
#if WASM_ENABLE_GC == 0
                frame_lp[addr_ret] = *(uint32 *)global_addr;
#else
                if (!wasm_is_type_reftype(global->type))
                    frame_lp[addr_ret] = *(uint32 *)global_addr;
                else {
                    PUT_REF_TO_ADDR(frame_lp + addr_ret,
                                    GET_REF_FROM_ADDR((uint32 *)global_addr));
                    if (!wasm_is_reftype_i31ref(global->type)) {
                        SET_FRAME_REF(addr_ret);
                    }
                }
#endif
                /* clang-format on */
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_GET_GLOBAL_64)
            {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr_ret = GET_OFFSET();
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                GET_I64_FROM_ADDR((uint32 *)global_addr));
                HANDLE_OP_END();
            }
#if WASM_ENABLE_SIMDE != 0
            HANDLE_OP(WASM_OP_GET_GLOBAL_V128)
            {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr_ret = GET_OFFSET();
                PUT_V128_TO_ADDR(frame_lp + addr_ret,
                                 GET_V128_FROM_ADDR((uint32 *)global_addr));
                HANDLE_OP_END();
            }
#endif
            HANDLE_OP(WASM_OP_SET_GLOBAL)
            {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr1 = GET_OFFSET();
                /* clang-format off */
#if WASM_ENABLE_GC == 0
                *(int32 *)global_addr = frame_lp[addr1];
#else
                if (!wasm_is_type_reftype(global->type))
                    *(int32 *)global_addr = frame_lp[addr1];
                else {
                    PUT_REF_TO_ADDR((uint32 *)global_addr,
                                    GET_REF_FROM_ADDR(frame_lp + addr1));
                    CLEAR_FRAME_REF(addr1);
                }
#endif
                /* clang-format on */
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SET_GLOBAL_AUX_STACK)
            {
                uint64 aux_stack_top;

                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                /* TODO: Memory64 the data type depends on mem idx type */
                aux_stack_top = (uint64)frame_lp[GET_OFFSET()];
                if (aux_stack_top <= (uint64)exec_env->aux_stack_boundary) {
                    wasm_set_exception(module, "wasm auxiliary stack overflow");
                    goto got_exception;
                }
                if (aux_stack_top > (uint64)exec_env->aux_stack_bottom) {
                    wasm_set_exception(module,
                                       "wasm auxiliary stack underflow");
                    goto got_exception;
                }
                *(int32 *)global_addr = (uint32)aux_stack_top;
#if WASM_ENABLE_MEMORY_PROFILING != 0
                if (module->module->aux_stack_top_global_index != (uint32)-1) {
                    uint32 aux_stack_used =
                        (uint32)(module->module->aux_stack_bottom
                                 - *(uint32 *)global_addr);
                    if (aux_stack_used > module->e->max_aux_stack_used)
                        module->e->max_aux_stack_used = aux_stack_used;
                }
#endif
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SET_GLOBAL_64)
            {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr1 = GET_OFFSET();
                PUT_I64_TO_ADDR((uint32 *)global_addr,
                                GET_I64_FROM_ADDR(frame_lp + addr1));
                HANDLE_OP_END();
            }
#if WASM_ENABLE_SIMDE != 0
            HANDLE_OP(WASM_OP_SET_GLOBAL_V128)
            {
                global_idx = read_uint32(frame_ip);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                addr1 = GET_OFFSET();
                PUT_V128_TO_ADDR((uint32 *)global_addr,
                                 GET_V128_FROM_ADDR(frame_lp + addr1));
                HANDLE_OP_END();
            }
#endif

            /* memory load instructions */
            HANDLE_OP(WASM_OP_I32_LOAD)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                frame_lp[addr_ret] = LOAD_I32(maddr);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(8);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, LOAD_I64(maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD8_S)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                frame_lp[addr_ret] = sign_ext_8_32(*(int8 *)maddr);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD8_U)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                frame_lp[addr_ret] = (uint32)(*(uint8 *)(maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD16_S)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                frame_lp[addr_ret] = sign_ext_16_32(LOAD_I16(maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD16_U)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                frame_lp[addr_ret] = (uint32)(LOAD_U16(maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD8_S)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                sign_ext_8_64(*(int8 *)maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD8_U)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, (uint64)(*(uint8 *)maddr));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD16_S)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                sign_ext_16_64(LOAD_I16(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD16_U)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, (uint64)(LOAD_U16(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD32_S)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                PUT_I64_TO_ADDR(frame_lp + addr_ret,
                                sign_ext_32_64(LOAD_I32(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD32_U)
            {
                uint32 offset, addr;
                offset = read_uint32(frame_ip);
                addr = GET_OPERAND(uint32, I32, 0);
                frame_ip += 2;
                addr_ret = GET_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                PUT_I64_TO_ADDR(frame_lp + addr_ret, (uint64)(LOAD_U32(maddr)));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_STORE)
            {
                uint32 offset, addr;
                uint32 sval;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint32, I32, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(4);
                STORE_U32(maddr, sval);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_STORE8)
            {
                uint32 offset, addr;
                uint32 sval;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint32, I32, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(1);
                STORE_U8(maddr, (uint8_t)sval);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_STORE16)
            {
                uint32 offset, addr;
                uint32 sval;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint32, I32, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(2);
                STORE_U16(maddr, (uint16)sval);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_STORE)
            {
                uint32 offset, addr;
                uint64 sval;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(8);
                STORE_I64(maddr, sval);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_STORE8)
            {
                uint32 offset, addr;
                uint64 sval;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(1);
                *(uint8 *)maddr = (uint8)sval;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_STORE16)
            {
                uint32 offset, addr;
                uint64 sval;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(2);
                STORE_U16(maddr, (uint16)sval);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_STORE32)
            {
                uint32 offset, addr;
                uint64 sval;
                offset = read_uint32(frame_ip);
                sval = GET_OPERAND(uint64, I64, 0);
                addr = GET_OPERAND(uint32, I32, 2);
                frame_ip += 4;
                CHECK_MEMORY_OVERFLOW(4);
                STORE_U32(maddr, (uint32)sval);
                HANDLE_OP_END();
            }

            /* memory size and memory grow instructions */
            HANDLE_OP(WASM_OP_MEMORY_SIZE)
            {
                uint32 reserved;
                addr_ret = GET_OFFSET();
                frame_lp[addr_ret] = memory->cur_page_count;
                (void)reserved;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_MEMORY_GROW)
            {
                uint32 reserved, delta,
                    prev_page_count = memory->cur_page_count;

                addr1 = GET_OFFSET();
                addr_ret = GET_OFFSET();
                delta = (uint32)frame_lp[addr1];

                /* TODO: multi-memory wasm_enlarge_memory_with_idx() */
                if (!wasm_enlarge_memory(module, delta)) {
                    /* failed to memory.grow, return -1 */
                    frame_lp[addr_ret] = -1;
                }
                else {
                    /* success, return previous page count */
                    frame_lp[addr_ret] = prev_page_count;
                    /* update memory size, no need to update memory ptr as
                       it isn't changed in wasm_enlarge_memory */
#if !defined(OS_ENABLE_HW_BOUND_CHECK)              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0
                    linear_mem_size = GET_LINEAR_MEMORY_SIZE(memory);
#endif
                }

                (void)reserved;
                HANDLE_OP_END();
            }

            /* constant instructions */
            HANDLE_OP(WASM_OP_F64_CONST)
            HANDLE_OP(WASM_OP_I64_CONST)
            {
                uint8 *orig_ip = frame_ip;

                frame_ip += sizeof(uint64);
                addr_ret = GET_OFFSET();

                bh_memcpy_s(frame_lp + addr_ret, sizeof(uint64), orig_ip,
                            sizeof(uint64));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_CONST)
            HANDLE_OP(WASM_OP_I32_CONST)
            {
                uint8 *orig_ip = frame_ip;

                frame_ip += sizeof(uint32);
                addr_ret = GET_OFFSET();

                bh_memcpy_s(frame_lp + addr_ret, sizeof(uint32), orig_ip,
                            sizeof(uint32));
                HANDLE_OP_END();
            }

            /* comparison instructions of i32 */
            HANDLE_OP(WASM_OP_I32_EQZ)
            {
                DEF_OP_EQZ(int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_EQ)
            {
                DEF_OP_CMP(uint32, I32, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_NE)
            {
                DEF_OP_CMP(uint32, I32, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LT_S)
            {
                DEF_OP_CMP(int32, I32, <);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LT_U)
            {
                DEF_OP_CMP(uint32, I32, <);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_GT_S)
            {
                DEF_OP_CMP(int32, I32, >);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_GT_U)
            {
                DEF_OP_CMP(uint32, I32, >);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LE_S)
            {
                DEF_OP_CMP(int32, I32, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LE_U)
            {
                DEF_OP_CMP(uint32, I32, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_GE_S)
            {
                DEF_OP_CMP(int32, I32, >=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_GE_U)
            {
                DEF_OP_CMP(uint32, I32, >=);
                HANDLE_OP_END();
            }

            /* comparison instructions of i64 */
            HANDLE_OP(WASM_OP_I64_EQZ)
            {
                DEF_OP_EQZ(int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_EQ)
            {
                DEF_OP_CMP(uint64, I64, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_NE)
            {
                DEF_OP_CMP(uint64, I64, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LT_S)
            {
                DEF_OP_CMP(int64, I64, <);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LT_U)
            {
                DEF_OP_CMP(uint64, I64, <);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_GT_S)
            {
                DEF_OP_CMP(int64, I64, >);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_GT_U)
            {
                DEF_OP_CMP(uint64, I64, >);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LE_S)
            {
                DEF_OP_CMP(int64, I64, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LE_U)
            {
                DEF_OP_CMP(uint64, I64, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_GE_S)
            {
                DEF_OP_CMP(int64, I64, >=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_GE_U)
            {
                DEF_OP_CMP(uint64, I64, >=);
                HANDLE_OP_END();
            }

            /* comparison instructions of f32 */
            HANDLE_OP(WASM_OP_F32_EQ)
            {
                DEF_OP_CMP(float32, F32, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_NE)
            {
                DEF_OP_CMP(float32, F32, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_LT)
            {
                DEF_OP_CMP(float32, F32, <);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_GT)
            {
                DEF_OP_CMP(float32, F32, >);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_LE)
            {
                DEF_OP_CMP(float32, F32, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_GE)
            {
                DEF_OP_CMP(float32, F32, >=);
                HANDLE_OP_END();
            }

            /* comparison instructions of f64 */
            HANDLE_OP(WASM_OP_F64_EQ)
            {
                DEF_OP_CMP(float64, F64, ==);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_NE)
            {
                DEF_OP_CMP(float64, F64, !=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_LT)
            {
                DEF_OP_CMP(float64, F64, <);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_GT)
            {
                DEF_OP_CMP(float64, F64, >);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_LE)
            {
                DEF_OP_CMP(float64, F64, <=);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_GE)
            {
                DEF_OP_CMP(float64, F64, >=);
                HANDLE_OP_END();
            }

            /* numeric instructions of i32 */
            HANDLE_OP(WASM_OP_I32_CLZ)
            {
                DEF_OP_BIT_COUNT(uint32, I32, clz32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_CTZ)
            {
                DEF_OP_BIT_COUNT(uint32, I32, ctz32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_POPCNT)
            {
                DEF_OP_BIT_COUNT(uint32, I32, popcount32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_ADD)
            {
                DEF_OP_NUMERIC(uint32, uint32, I32, +);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_SUB)
            {
                DEF_OP_NUMERIC(uint32, uint32, I32, -);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_MUL)
            {
                DEF_OP_NUMERIC(uint32, uint32, I32, *);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_DIV_S)
            {
                int32 a, b;

                b = frame_lp[GET_OFFSET()];
                a = frame_lp[GET_OFFSET()];
                addr_ret = GET_OFFSET();
                if (a == (int32)0x80000000 && b == -1) {
                    wasm_set_exception(module, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_DIV_U)
            {
                uint32 a, b;

                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                b = (uint32)frame_lp[addr1];
                a = (uint32)frame_lp[addr2];
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_REM_S)
            {
                int32 a, b;

                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                b = frame_lp[addr1];
                a = frame_lp[addr2];
                if (a == (int32)0x80000000 && b == -1) {
                    frame_lp[addr_ret] = 0;
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_REM_U)
            {
                uint32 a, b;

                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                addr_ret = GET_OFFSET();

                b = (uint32)frame_lp[addr1];
                a = (uint32)frame_lp[addr2];
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                frame_lp[addr_ret] = (a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_AND)
            {
                DEF_OP_NUMERIC(uint32, uint32, I32, &);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_OR)
            {
                DEF_OP_NUMERIC(uint32, uint32, I32, |);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_XOR)
            {
                DEF_OP_NUMERIC(uint32, uint32, I32, ^);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_SHL)
            {
                DEF_OP_NUMERIC2(uint32, uint32, I32, <<);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_SHR_S)
            {
                DEF_OP_NUMERIC2(int32, uint32, I32, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_SHR_U)
            {
                DEF_OP_NUMERIC2(uint32, uint32, I32, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_ROTL)
            {
                uint32 a, b;

                b = (uint32)frame_lp[GET_OFFSET()];
                a = (uint32)frame_lp[GET_OFFSET()];
                frame_lp[GET_OFFSET()] = rotl32(a, b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_ROTR)
            {
                uint32 a, b;

                b = (uint32)frame_lp[GET_OFFSET()];
                a = (uint32)frame_lp[GET_OFFSET()];
                frame_lp[GET_OFFSET()] = rotr32(a, b);
                HANDLE_OP_END();
            }

            /* numeric instructions of i64 */
            HANDLE_OP(WASM_OP_I64_CLZ)
            {
                DEF_OP_BIT_COUNT(uint64, I64, clz64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_CTZ)
            {
                DEF_OP_BIT_COUNT(uint64, I64, ctz64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_POPCNT)
            {
                DEF_OP_BIT_COUNT(uint64, I64, popcount64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_ADD)
            {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, +);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_SUB)
            {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, -);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_MUL)
            {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, *);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_DIV_S)
            {
                int64 a, b;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (a == (int64)0x8000000000000000LL && b == -1) {
                    wasm_set_exception(module, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_DIV_U)
            {
                uint64 a, b;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_REM_S)
            {
                int64 a, b;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (a == (int64)0x8000000000000000LL && b == -1) {
                    *(int64 *)(frame_lp + GET_OFFSET()) = 0;
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_REM_U)
            {
                uint64 a, b;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_AND)
            {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, &);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_OR)
            {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, |);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_XOR)
            {
                DEF_OP_NUMERIC_64(uint64, uint64, I64, ^);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_SHL)
            {
                DEF_OP_NUMERIC2_64(uint64, uint64, I64, <<);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_SHR_S)
            {
                DEF_OP_NUMERIC2_64(int64, uint64, I64, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_SHR_U)
            {
                DEF_OP_NUMERIC2_64(uint64, uint64, I64, >>);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_ROTL)
            {
                uint64 a, b;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), rotl64(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_ROTR)
            {
                uint64 a, b;

                b = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                a = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(), rotr64(a, b));
                HANDLE_OP_END();
            }

            /* numeric instructions of f32 */
            HANDLE_OP(WASM_OP_F32_ABS)
            {
                DEF_OP_MATH(float32, F32, fabsf);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_NEG)
            {
                uint32 u32 = frame_lp[GET_OFFSET()];
                uint32 sign_bit = u32 & ((uint32)1 << 31);
                addr_ret = GET_OFFSET();
                if (sign_bit)
                    frame_lp[addr_ret] = u32 & ~((uint32)1 << 31);
                else
                    frame_lp[addr_ret] = u32 | ((uint32)1 << 31);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_CEIL)
            {
                DEF_OP_MATH(float32, F32, ceilf);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_FLOOR)
            {
                DEF_OP_MATH(float32, F32, floorf);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_TRUNC)
            {
                DEF_OP_MATH(float32, F32, truncf);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_NEAREST)
            {
                DEF_OP_MATH(float32, F32, rintf);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_SQRT)
            {
                DEF_OP_MATH(float32, F32, sqrtf);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_ADD)
            {
                DEF_OP_NUMERIC(float32, float32, F32, +);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_SUB)
            {
                DEF_OP_NUMERIC(float32, float32, F32, -);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_MUL)
            {
                DEF_OP_NUMERIC(float32, float32, F32, *);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_DIV)
            {
                DEF_OP_NUMERIC(float32, float32, F32, /);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_MIN)
            {
                float32 a, b;

                b = *(float32 *)(frame_lp + GET_OFFSET());
                a = *(float32 *)(frame_lp + GET_OFFSET());

                *(float32 *)(frame_lp + GET_OFFSET()) = f32_min(a, b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_MAX)
            {
                float32 a, b;

                b = *(float32 *)(frame_lp + GET_OFFSET());
                a = *(float32 *)(frame_lp + GET_OFFSET());

                *(float32 *)(frame_lp + GET_OFFSET()) = f32_max(a, b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_COPYSIGN)
            {
                float32 a, b;

                b = *(float32 *)(frame_lp + GET_OFFSET());
                a = *(float32 *)(frame_lp + GET_OFFSET());
                *(float32 *)(frame_lp + GET_OFFSET()) = local_copysignf(a, b);
                HANDLE_OP_END();
            }

            /* numeric instructions of f64 */
            HANDLE_OP(WASM_OP_F64_ABS)
            {
                DEF_OP_MATH(float64, F64, fabs);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_NEG)
            {
                uint64 u64 = GET_I64_FROM_ADDR(frame_lp + GET_OFFSET());
                uint64 sign_bit = u64 & (((uint64)1) << 63);
                if (sign_bit)
                    PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(),
                                    (u64 & ~(((uint64)1) << 63)));
                else
                    PUT_I64_TO_ADDR(frame_lp + GET_OFFSET(),
                                    (u64 | (((uint64)1) << 63)));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_CEIL)
            {
                DEF_OP_MATH(float64, F64, ceil);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_FLOOR)
            {
                DEF_OP_MATH(float64, F64, floor);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_TRUNC)
            {
                DEF_OP_MATH(float64, F64, trunc);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_NEAREST)
            {
                DEF_OP_MATH(float64, F64, rint);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_SQRT)
            {
                DEF_OP_MATH(float64, F64, sqrt);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_ADD)
            {
                DEF_OP_NUMERIC_64(float64, float64, F64, +);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_SUB)
            {
                DEF_OP_NUMERIC_64(float64, float64, F64, -);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_MUL)
            {
                DEF_OP_NUMERIC_64(float64, float64, F64, *);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_DIV)
            {
                DEF_OP_NUMERIC_64(float64, float64, F64, /);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_MIN)
            {
                float64 a, b;

                b = POP_F64();
                a = POP_F64();

                PUSH_F64(f64_min(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_MAX)
            {
                float64 a, b;

                b = POP_F64();
                a = POP_F64();

                PUSH_F64(f64_max(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_COPYSIGN)
            {
                float64 a, b;

                b = POP_F64();
                a = POP_F64();
                PUSH_F64(local_copysign(a, b));
                HANDLE_OP_END();
            }

            /* conversions of i32 */
            HANDLE_OP(WASM_OP_I32_WRAP_I64)
            {
                int32 value = (int32)(POP_I64() & 0xFFFFFFFFLL);
                PUSH_I32(value);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_TRUNC_S_F32)
            {
                /* We don't use INT32_MIN/INT32_MAX/UINT32_MIN/UINT32_MAX,
                   since float/double values of ieee754 cannot precisely
                   represent all int32/uint32/int64/uint64 values, e.g.:
                   UINT32_MAX is 4294967295, but (float32)4294967295 is
                   4294967296.0f, but not 4294967295.0f. */
                DEF_OP_TRUNC_F32(-2147483904.0f, 2147483648.0f, true, true);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_TRUNC_U_F32)
            {
                DEF_OP_TRUNC_F32(-1.0f, 4294967296.0f, true, false);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_TRUNC_S_F64)
            {
                DEF_OP_TRUNC_F64(-2147483649.0, 2147483648.0, true, true);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_TRUNC_U_F64)
            {
                DEF_OP_TRUNC_F64(-1.0, 4294967296.0, true, false);
                HANDLE_OP_END();
            }

            /* conversions of i64 */
            HANDLE_OP(WASM_OP_I64_EXTEND_S_I32)
            {
                DEF_OP_CONVERT(int64, I64, int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_EXTEND_U_I32)
            {
                DEF_OP_CONVERT(int64, I64, uint32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_TRUNC_S_F32)
            {
                DEF_OP_TRUNC_F32(-9223373136366403584.0f,
                                 9223372036854775808.0f, false, true);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_TRUNC_U_F32)
            {
                DEF_OP_TRUNC_F32(-1.0f, 18446744073709551616.0f, false, false);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_TRUNC_S_F64)
            {
                DEF_OP_TRUNC_F64(-9223372036854777856.0, 9223372036854775808.0,
                                 false, true);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_TRUNC_U_F64)
            {
                DEF_OP_TRUNC_F64(-1.0, 18446744073709551616.0, false, false);
                HANDLE_OP_END();
            }

            /* conversions of f32 */
            HANDLE_OP(WASM_OP_F32_CONVERT_S_I32)
            {
                DEF_OP_CONVERT(float32, F32, int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_CONVERT_U_I32)
            {
                DEF_OP_CONVERT(float32, F32, uint32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_CONVERT_S_I64)
            {
                DEF_OP_CONVERT(float32, F32, int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_CONVERT_U_I64)
            {
                DEF_OP_CONVERT(float32, F32, uint64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_DEMOTE_F64)
            {
                DEF_OP_CONVERT(float32, F32, float64, F64);
                HANDLE_OP_END();
            }

            /* conversions of f64 */
            HANDLE_OP(WASM_OP_F64_CONVERT_S_I32)
            {
                DEF_OP_CONVERT(float64, F64, int32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_CONVERT_U_I32)
            {
                DEF_OP_CONVERT(float64, F64, uint32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_CONVERT_S_I64)
            {
                DEF_OP_CONVERT(float64, F64, int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_CONVERT_U_I64)
            {
                DEF_OP_CONVERT(float64, F64, uint64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_PROMOTE_F32)
            {
                DEF_OP_CONVERT(float64, F64, float32, F32);
                HANDLE_OP_END();
            }

            /* reinterpretations */
            HANDLE_OP(WASM_OP_I32_REINTERPRET_F32)
            HANDLE_OP(WASM_OP_F32_REINTERPRET_I32)
            {
                DEF_OP_REINTERPRET(uint32, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_REINTERPRET_F64)
            HANDLE_OP(WASM_OP_F64_REINTERPRET_I64)
            {
                DEF_OP_REINTERPRET(int64, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_COPY_STACK_TOP)
            {
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();
                frame_lp[addr2] = frame_lp[addr1];

#if WASM_ENABLE_GC != 0
                /* Ignore constants because they are not reference */
                if (addr1 >= 0) {
                    if (*FRAME_REF(addr1)) {
                        CLEAR_FRAME_REF(addr1);
                        SET_FRAME_REF(addr2);
                    }
                }
#endif

                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_COPY_STACK_TOP_I64)
            {
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();

                PUT_I64_TO_ADDR(frame_lp + addr2,
                                GET_I64_FROM_ADDR(frame_lp + addr1));

#if WASM_ENABLE_GC != 0
                /* Ignore constants because they are not reference */
                if (addr1 >= 0) {
                    if (*FRAME_REF(addr1)) {
                        CLEAR_FRAME_REF(addr1);
                        SET_FRAME_REF(addr2);
                    }
                }
#endif

                HANDLE_OP_END();
            }
#if WASM_ENABLE_SIMDE != 0
            HANDLE_OP(EXT_OP_COPY_STACK_TOP_V128)
            {
                addr1 = GET_OFFSET();
                addr2 = GET_OFFSET();

                PUT_V128_TO_ADDR(frame_lp + addr2,
                                 GET_V128_FROM_ADDR(frame_lp + addr1));

#if WASM_ENABLE_GC != 0
                /* Ignore constants because they are not reference */
                if (addr1 >= 0) {
                    if (*FRAME_REF(addr1)) {
                        CLEAR_FRAME_REF(addr1);
                        SET_FRAME_REF(addr2);
                    }
                }
#endif

                HANDLE_OP_END();
            }
#endif

            HANDLE_OP(EXT_OP_COPY_STACK_VALUES)
            {
                uint32 values_count, total_cell;
                uint8 *cells;
                int16 *src_offsets = NULL;
                uint16 *dst_offsets = NULL;

                /* read values_count */
                values_count = read_uint32(frame_ip);
                /* read total cell num */
                total_cell = read_uint32(frame_ip);
                /* cells */
                cells = (uint8 *)frame_ip;
                frame_ip += values_count * CELL_SIZE;
                /* src offsets */
                src_offsets = (int16 *)frame_ip;
                frame_ip += values_count * sizeof(int16);
                /* dst offsets */
                dst_offsets = (uint16 *)frame_ip;
                frame_ip += values_count * sizeof(uint16);

                if (!copy_stack_values(module, frame_lp, values_count,
#if WASM_ENABLE_GC != 0
                                       frame_ref,
#endif
                                       total_cell, cells, src_offsets,
                                       dst_offsets))
                    goto got_exception;

                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SET_LOCAL)
            {
                opcode = WASM_OP_SET_LOCAL;
                goto handle_op_set_tee_local;
            }
            HANDLE_OP(WASM_OP_TEE_LOCAL)
            {
                opcode = WASM_OP_TEE_LOCAL;
            handle_op_set_tee_local:

                GET_LOCAL_INDEX_TYPE_AND_OFFSET();
                addr1 = GET_OFFSET();

                if (local_type == VALUE_TYPE_I32 || local_type == VALUE_TYPE_F32
#if WASM_ENABLE_REF_TYPES != 0 && WASM_ENABLE_GC == 0
                    || local_type == VALUE_TYPE_FUNCREF
                    || local_type == VALUE_TYPE_EXTERNREF
#endif
                ) {
                    *(int32 *)(frame_lp + local_offset) = frame_lp[addr1];
                }
                else if (local_type == VALUE_TYPE_I64
                         || local_type == VALUE_TYPE_F64) {
                    PUT_I64_TO_ADDR((uint32 *)(frame_lp + local_offset),
                                    GET_I64_FROM_ADDR(frame_lp + addr1));
                }
#if WASM_ENABLE_GC != 0
                else if (wasm_is_type_reftype(local_type)) {
                    PUT_REF_TO_ADDR((uint32 *)(frame_lp + local_offset),
                                    GET_REF_FROM_ADDR(frame_lp + addr1));
                    if (opcode == WASM_OP_SET_LOCAL) {
                        CLEAR_FRAME_REF(addr1);
                    }
                }
#endif
                else {
                    wasm_set_exception(module, "invalid local type");
                    goto got_exception;
                }

                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_EXTEND8_S)
            {
                DEF_OP_CONVERT(int32, I32, int8, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_EXTEND16_S)
            {
                DEF_OP_CONVERT(int32, I32, int16, I32);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_EXTEND8_S)
            {
                DEF_OP_CONVERT(int64, I64, int8, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_EXTEND16_S)
            {
                DEF_OP_CONVERT(int64, I64, int16, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_EXTEND32_S)
            {
                DEF_OP_CONVERT(int64, I64, int32, I64);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_MISC_PREFIX)
            {
                GET_OPCODE();
                switch (opcode) {
                    case WASM_OP_I32_TRUNC_SAT_S_F32:
                        DEF_OP_TRUNC_SAT_F32(-2147483904.0f, 2147483648.0f,
                                             true, true);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_U_F32:
                        DEF_OP_TRUNC_SAT_F32(-1.0f, 4294967296.0f, true, false);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_S_F64:
                        DEF_OP_TRUNC_SAT_F64(-2147483649.0, 2147483648.0, true,
                                             true);
                        break;
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0, 4294967296.0, true, false);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                        DEF_OP_TRUNC_SAT_F32(-9223373136366403584.0f,
                                             9223372036854775808.0f, false,
                                             true);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                        DEF_OP_TRUNC_SAT_F32(-1.0f, 18446744073709551616.0f,
                                             false, false);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                        DEF_OP_TRUNC_SAT_F64(-9223372036854777856.0,
                                             9223372036854775808.0, false,
                                             true);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0, 18446744073709551616.0,
                                             false, false);
                        break;
#if WASM_ENABLE_BULK_MEMORY != 0
                    case WASM_OP_MEMORY_INIT:
                    {
                        uint32 addr, segment;
                        uint64 bytes, offset, seg_len;
                        uint8 *data;

                        segment = read_uint32(frame_ip);

                        bytes = (uint64)(uint32)POP_I32();
                        offset = (uint64)(uint32)POP_I32();
                        addr = POP_I32();

#if WASM_ENABLE_THREAD_MGR != 0
                        linear_mem_size = get_linear_mem_size();
#endif

#ifndef OS_ENABLE_HW_BOUND_CHECK
                        CHECK_BULK_MEMORY_OVERFLOW(addr, bytes, maddr);
#else
#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)(uint32)addr,
                                                    bytes))
                            shared_heap_addr_app_to_native((uint64)(uint32)addr,
                                                           maddr);
                        else
#endif
                        {
                            if ((uint64)(uint32)addr + bytes > linear_mem_size)
                                goto out_of_bounds;
                            maddr = memory->memory_data + (uint32)addr;
                        }
#endif
                        if (bh_bitmap_get_bit(module->e->common.data_dropped,
                                              segment)) {
                            seg_len = 0;
                            data = NULL;
                        }
                        else {
                            seg_len =
                                (uint64)module->module->data_segments[segment]
                                    ->data_length;
                            data = module->module->data_segments[segment]->data;
                        }
                        if (offset + bytes > seg_len)
                            goto out_of_bounds;

                        bh_memcpy_s(maddr, (uint32)(linear_mem_size - addr),
                                    data + offset, (uint32)bytes);
                        break;
                    }
                    case WASM_OP_DATA_DROP:
                    {
                        uint32 segment;

                        segment = read_uint32(frame_ip);
                        bh_bitmap_set_bit(module->e->common.data_dropped,
                                          segment);
                        break;
                    }
                    case WASM_OP_MEMORY_COPY:
                    {
                        uint32 dst, src, len;
                        uint8 *mdst, *msrc;

                        len = POP_I32();
                        src = POP_I32();
                        dst = POP_I32();

#if WASM_ENABLE_THREAD_MGR != 0
                        linear_mem_size = get_linear_mem_size();
#endif

#ifndef OS_ENABLE_HW_BOUND_CHECK
                        CHECK_BULK_MEMORY_OVERFLOW(src, len, msrc);
                        CHECK_BULK_MEMORY_OVERFLOW(dst, len, mdst);
#else /* else of OS_ENABLE_HW_BOUND_CHECK */
#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)src, len))
                            shared_heap_addr_app_to_native((uint64)src, msrc);
                        else
#endif
                        {
                            if ((uint64)(uint32)src + len > linear_mem_size)
                                goto out_of_bounds;
                            msrc = memory->memory_data + (uint32)src;
                        }

#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)dst, len)) {
                            shared_heap_addr_app_to_native((uint64)dst, mdst);
                        }
                        else
#endif
                        {
                            if ((uint64)(uint32)dst + len > linear_mem_size)
                                goto out_of_bounds;
                            mdst = memory->memory_data + (uint32)dst;
                        }
#endif /* end of OS_ENABLE_HW_BOUND_CHECK */

                        /*
                         * avoid unnecessary operations
                         *
                         * since dst and src both are valid indexes in the
                         * linear memory, mdst and msrc can't be NULL
                         *
                         * The spec. converts memory.copy into i32.load8 and
                         * i32.store8; the following are runtime-specific
                         * optimizations.
                         *
                         */
                        if (len && mdst != msrc) {
                            /* allowing the destination and source to overlap */
                            memmove(mdst, msrc, len);
                        }
                        break;
                    }
                    case WASM_OP_MEMORY_FILL:
                    {
                        uint32 dst, len;
                        uint8 fill_val, *mdst;

                        len = POP_I32();
                        fill_val = POP_I32();
                        dst = POP_I32();

#if WASM_ENABLE_THREAD_MGR != 0
                        linear_mem_size = get_linear_mem_size();
#endif

#ifndef OS_ENABLE_HW_BOUND_CHECK
                        CHECK_BULK_MEMORY_OVERFLOW(dst, len, mdst);
#else
#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)(uint32)dst, len))
                            shared_heap_addr_app_to_native((uint64)(uint32)dst,
                                                           mdst);
                        else
#endif
                        {
                            if ((uint64)(uint32)dst + len > linear_mem_size)
                                goto out_of_bounds;
                            mdst = memory->memory_data + (uint32)dst;
                        }
#endif

                        memset(mdst, fill_val, len);
                        break;
                    }
#endif /* WASM_ENABLE_BULK_MEMORY */
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
                    case WASM_OP_TABLE_INIT:
                    {
                        uint32 tbl_idx, elem_idx;
                        uint32 n, s, d;
                        WASMTableInstance *tbl_inst;
                        table_elem_type_t *table_elems;
                        InitializerExpression *tbl_seg_init_values = NULL,
                                              *init_values;
                        uint64 i;
                        uint32 tbl_seg_len = 0;

                        elem_idx = read_uint32(frame_ip);
                        bh_assert(elem_idx < module->module->table_seg_count);

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module->module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);

                        n = (uint32)POP_I32();
                        s = (uint32)POP_I32();
                        d = (uint32)POP_I32();

                        if (!bh_bitmap_get_bit(module->e->common.elem_dropped,
                                               elem_idx)) {
                            /* table segment isn't dropped */
                            tbl_seg_init_values =
                                module->module->table_segments[elem_idx]
                                    .init_values;
                            tbl_seg_len =
                                module->module->table_segments[elem_idx]
                                    .value_count;
                        }

                        if (offset_len_out_of_bounds(s, n, tbl_seg_len)
                            || offset_len_out_of_bounds(d, n,
                                                        tbl_inst->cur_size)) {
                            wasm_set_exception(module,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        if (!n) {
                            break;
                        }

                        table_elems = tbl_inst->elems + d;
                        init_values = tbl_seg_init_values + s;
#if WASM_ENABLE_GC != 0
                        SYNC_ALL_TO_FRAME();
#endif
                        for (i = 0; i < n; i++) {
                            /* UINT32_MAX indicates that it is a null ref */
                            bh_assert(init_values[i].init_expr_type
                                          == INIT_EXPR_TYPE_REFNULL_CONST
                                      || init_values[i].init_expr_type
                                             == INIT_EXPR_TYPE_FUNCREF_CONST);
#if WASM_ENABLE_GC == 0
                            table_elems[i] = (table_elem_type_t)init_values[i]
                                                 .u.unary.v.ref_index;
#else
                            if (init_values[i].u.unary.v.ref_index
                                != UINT32_MAX) {
                                if (!(func_obj = wasm_create_func_obj(
                                          module,
                                          init_values[i].u.unary.v.ref_index,
                                          true, NULL, 0))) {
                                    goto got_exception;
                                }
                                table_elems[i] = func_obj;
                            }
                            else {
                                table_elems[i] = NULL_REF;
                            }
#endif
                        }

                        break;
                    }
                    case WASM_OP_ELEM_DROP:
                    {
                        uint32 elem_idx = read_uint32(frame_ip);
                        bh_assert(elem_idx < module->module->table_seg_count);
                        bh_bitmap_set_bit(module->e->common.elem_dropped,
                                          elem_idx);
                        break;
                    }
                    case WASM_OP_TABLE_COPY:
                    {
                        uint32 src_tbl_idx, dst_tbl_idx;
                        uint32 n, s, d;
                        WASMTableInstance *src_tbl_inst, *dst_tbl_inst;

                        dst_tbl_idx = read_uint32(frame_ip);
                        bh_assert(dst_tbl_idx < module->table_count);

                        dst_tbl_inst = wasm_get_table_inst(module, dst_tbl_idx);

                        src_tbl_idx = read_uint32(frame_ip);
                        bh_assert(src_tbl_idx < module->table_count);

                        src_tbl_inst = wasm_get_table_inst(module, src_tbl_idx);

                        n = (uint32)POP_I32();
                        s = (uint32)POP_I32();
                        d = (uint32)POP_I32();

                        if (offset_len_out_of_bounds(d, n,
                                                     dst_tbl_inst->cur_size)
                            || offset_len_out_of_bounds(
                                s, n, src_tbl_inst->cur_size)) {
                            wasm_set_exception(module,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        /* if s >= d, copy from front to back */
                        /* if s < d, copy from back to front */
                        /* merge all together */
                        bh_memmove_s((uint8 *)dst_tbl_inst
                                         + offsetof(WASMTableInstance, elems)
                                         + d * sizeof(table_elem_type_t),
                                     (uint32)((dst_tbl_inst->cur_size - d)
                                              * sizeof(table_elem_type_t)),
                                     (uint8 *)src_tbl_inst
                                         + offsetof(WASMTableInstance, elems)
                                         + s * sizeof(table_elem_type_t),
                                     (uint32)(n * sizeof(table_elem_type_t)));
                        break;
                    }
                    case WASM_OP_TABLE_GROW:
                    {
                        uint32 tbl_idx, n, orig_tbl_sz;
                        WASMTableInstance *tbl_inst;
                        table_elem_type_t init_val;

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);

                        orig_tbl_sz = tbl_inst->cur_size;

                        n = POP_I32();
#if WASM_ENABLE_GC == 0
                        init_val = POP_I32();
#else
                        init_val = POP_REF();
#endif

                        if (!wasm_enlarge_table(module, tbl_idx, n, init_val)) {
                            PUSH_I32(-1);
                        }
                        else {
                            PUSH_I32(orig_tbl_sz);
                        }

                        break;
                    }
                    case WASM_OP_TABLE_SIZE:
                    {
                        uint32 tbl_idx;
                        WASMTableInstance *tbl_inst;

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);

                        PUSH_I32(tbl_inst->cur_size);
                        break;
                    }
                    case WASM_OP_TABLE_FILL:
                    {
                        uint32 tbl_idx, n, i;
                        WASMTableInstance *tbl_inst;
                        table_elem_type_t fill_val;

                        tbl_idx = read_uint32(frame_ip);
                        bh_assert(tbl_idx < module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);

                        n = POP_I32();
#if WASM_ENABLE_GC == 0
                        fill_val = POP_I32();
#else
                        fill_val = POP_REF();
#endif
                        i = POP_I32();

                        if (offset_len_out_of_bounds(i, n,
                                                     tbl_inst->cur_size)) {
                            wasm_set_exception(module,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        for (; n != 0; i++, n--) {
                            tbl_inst->elems[i] = fill_val;
                        }

                        break;
                    }
#endif /* WASM_ENABLE_REF_TYPES */
                    default:
                        wasm_set_exception(module, "unsupported opcode");
                        goto got_exception;
                }
                HANDLE_OP_END();
            }

#if WASM_ENABLE_SHARED_MEMORY != 0
            HANDLE_OP(WASM_OP_ATOMIC_PREFIX)
            {
                uint32 offset = 0, addr;

                GET_OPCODE();

                if (opcode != WASM_OP_ATOMIC_FENCE) {
                    offset = read_uint32(frame_ip);
                }

                switch (opcode) {
                    case WASM_OP_ATOMIC_NOTIFY:
                    {
                        uint32 notify_count, ret;

                        notify_count = POP_I32();
                        addr = POP_I32();
                        CHECK_MEMORY_OVERFLOW(4);
                        CHECK_ATOMIC_MEMORY_ACCESS(4);

                        ret = wasm_runtime_atomic_notify(
                            (WASMModuleInstanceCommon *)module, maddr,
                            notify_count);
                        if (ret == (uint32)-1)
                            goto got_exception;

                        PUSH_I32(ret);
                        break;
                    }
                    case WASM_OP_ATOMIC_WAIT32:
                    {
                        uint64 timeout;
                        uint32 expect, ret;

                        timeout = POP_I64();
                        expect = POP_I32();
                        addr = POP_I32();
                        CHECK_MEMORY_OVERFLOW(4);
                        CHECK_ATOMIC_MEMORY_ACCESS(4);

                        ret = wasm_runtime_atomic_wait(
                            (WASMModuleInstanceCommon *)module, maddr,
                            (uint64)expect, timeout, false);
                        if (ret == (uint32)-1)
                            goto got_exception;

#if WASM_ENABLE_THREAD_MGR != 0
                        CHECK_SUSPEND_FLAGS();
#endif

                        PUSH_I32(ret);
                        break;
                    }
                    case WASM_OP_ATOMIC_WAIT64:
                    {
                        uint64 timeout, expect;
                        uint32 ret;

                        timeout = POP_I64();
                        expect = POP_I64();
                        addr = POP_I32();
                        CHECK_MEMORY_OVERFLOW(8);
                        CHECK_ATOMIC_MEMORY_ACCESS(8);

                        ret = wasm_runtime_atomic_wait(
                            (WASMModuleInstanceCommon *)module, maddr, expect,
                            timeout, true);
                        if (ret == (uint32)-1)
                            goto got_exception;

#if WASM_ENABLE_THREAD_MGR != 0
                        CHECK_SUSPEND_FLAGS();
#endif

                        PUSH_I32(ret);
                        break;
                    }
                    case WASM_OP_ATOMIC_FENCE:
                    {
                        os_atomic_thread_fence(os_memory_order_seq_cst);
                        break;
                    }

                    case WASM_OP_ATOMIC_I32_LOAD:
                    case WASM_OP_ATOMIC_I32_LOAD8_U:
                    case WASM_OP_ATOMIC_I32_LOAD16_U:
                    {
                        uint32 readv;

                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I32_LOAD8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            shared_memory_lock(memory);
                            readv = (uint32)(*(uint8 *)maddr);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_LOAD16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            shared_memory_lock(memory);
                            readv = (uint32)LOAD_U16(maddr);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            shared_memory_lock(memory);
                            readv = LOAD_I32(maddr);
                            shared_memory_unlock(memory);
                        }

                        PUSH_I32(readv);
                        break;
                    }

                    case WASM_OP_ATOMIC_I64_LOAD:
                    case WASM_OP_ATOMIC_I64_LOAD8_U:
                    case WASM_OP_ATOMIC_I64_LOAD16_U:
                    case WASM_OP_ATOMIC_I64_LOAD32_U:
                    {
                        uint64 readv;

                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I64_LOAD8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            shared_memory_lock(memory);
                            readv = (uint64)(*(uint8 *)maddr);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U16(maddr);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD32_U) {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U32(maddr);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(8);
                            CHECK_ATOMIC_MEMORY_ACCESS(8);
                            shared_memory_lock(memory);
                            readv = LOAD_I64(maddr);
                            shared_memory_unlock(memory);
                        }

                        PUSH_I64(readv);
                        break;
                    }
                    case WASM_OP_ATOMIC_I32_STORE:
                    case WASM_OP_ATOMIC_I32_STORE8:
                    case WASM_OP_ATOMIC_I32_STORE16:
                    {
                        uint32 sval;

                        sval = (uint32)POP_I32();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I32_STORE8) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            shared_memory_lock(memory);
                            *(uint8 *)maddr = (uint8)sval;
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_STORE16) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            shared_memory_lock(memory);
                            STORE_U16(maddr, (uint16)sval);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            shared_memory_lock(memory);
                            STORE_U32(maddr, sval);
                            shared_memory_unlock(memory);
                        }
                        break;
                    }

                    case WASM_OP_ATOMIC_I64_STORE:
                    case WASM_OP_ATOMIC_I64_STORE8:
                    case WASM_OP_ATOMIC_I64_STORE16:
                    case WASM_OP_ATOMIC_I64_STORE32:
                    {
                        uint64 sval;

                        sval = (uint64)POP_I64();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_I64_STORE8) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);
                            shared_memory_lock(memory);
                            *(uint8 *)maddr = (uint8)sval;
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE16) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);
                            shared_memory_lock(memory);
                            STORE_U16(maddr, (uint16)sval);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE32) {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);
                            shared_memory_lock(memory);
                            STORE_U32(maddr, (uint32)sval);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(8);
                            CHECK_ATOMIC_MEMORY_ACCESS(8);
                            shared_memory_lock(memory);
                            STORE_I64(maddr, sval);
                            shared_memory_unlock(memory);
                        }
                        break;
                    }

                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U:
                    {
                        uint32 readv, sval, expect;

                        sval = POP_I32();
                        expect = POP_I32();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);

                            expect = (uint8)expect;
                            shared_memory_lock(memory);
                            readv = (uint32)(*(uint8 *)maddr);
                            if (readv == expect)
                                *(uint8 *)maddr = (uint8)(sval);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);

                            expect = (uint16)expect;
                            shared_memory_lock(memory);
                            readv = (uint32)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);

                            shared_memory_lock(memory);
                            readv = LOAD_I32(maddr);
                            if (readv == expect)
                                STORE_U32(maddr, sval);
                            shared_memory_unlock(memory);
                        }
                        PUSH_I32(readv);
                        break;
                    }
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U:
                    case WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U:
                    {
                        uint64 readv, sval, expect;

                        sval = (uint64)POP_I64();
                        expect = (uint64)POP_I64();
                        addr = POP_I32();

                        if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS(1);

                            expect = (uint8)expect;
                            shared_memory_lock(memory);
                            readv = (uint64)(*(uint8 *)maddr);
                            if (readv == expect)
                                *(uint8 *)maddr = (uint8)(sval);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS(2);

                            expect = (uint16)expect;
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U) {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS(4);

                            expect = (uint32)expect;
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U32(maddr);
                            if (readv == expect)
                                STORE_U32(maddr, (uint32)(sval));
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(8);
                            CHECK_ATOMIC_MEMORY_ACCESS(8);

                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_I64(maddr);
                            if (readv == expect)
                                STORE_I64(maddr, sval);
                            shared_memory_unlock(memory);
                        }
                        PUSH_I64(readv);
                        break;
                    }

                        DEF_ATOMIC_RMW_OPCODE(ADD, +);
                        DEF_ATOMIC_RMW_OPCODE(SUB, -);
                        DEF_ATOMIC_RMW_OPCODE(AND, &);
                        DEF_ATOMIC_RMW_OPCODE(OR, |);
                        DEF_ATOMIC_RMW_OPCODE(XOR, ^);
                        /* xchg, ignore the read value, and store the given
                          value: readv * 0 + sval */
                        DEF_ATOMIC_RMW_OPCODE(XCHG, *0 +);
                }

                HANDLE_OP_END();
            }
#endif

            HANDLE_OP(WASM_OP_IMPDEP)
            {
                frame = prev_frame;
                frame_ip = frame->ip;
#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
                is_return_call = false;
#endif
                goto call_func_from_entry;
            }
#if WASM_ENABLE_SIMDE != 0
#define SIMD_V128_TO_SIMDE_V128(s_v)                                    \
    ({                                                                  \
        bh_assert(sizeof(V128) == sizeof(simde_v128_t));                \
        simde_v128_t se_v;                                              \
        bh_memcpy_s(&se_v, sizeof(simde_v128_t), &(s_v), sizeof(V128)); \
        se_v;                                                           \
    })

#define SIMDE_V128_TO_SIMD_V128(sv, v)                                \
    do {                                                              \
        bh_assert(sizeof(V128) == sizeof(simde_v128_t));              \
        bh_memcpy_s(&(v), sizeof(V128), &(sv), sizeof(simde_v128_t)); \
    } while (0)

            HANDLE_OP(WASM_OP_SIMD_PREFIX)
            {
                GET_OPCODE();

                switch (opcode) {
                    /* Memory */
                    case SIMD_v128_load:
                    {
                        uint32 offset, addr;
                        offset = read_uint32(frame_ip);
                        addr = POP_I32();
                        addr_ret = GET_OFFSET();
                        CHECK_MEMORY_OVERFLOW(16);
                        PUT_V128_TO_ADDR(frame_lp + addr_ret, LOAD_V128(maddr));
                        break;
                    }
#define SIMD_LOAD_OP(simde_func)                       \
    do {                                               \
        uint32 offset, addr;                           \
        offset = read_uint32(frame_ip);                \
        addr = POP_I32();                              \
        addr_ret = GET_OFFSET();                       \
        CHECK_MEMORY_OVERFLOW(8);                      \
                                                       \
        simde_v128_t simde_result = simde_func(maddr); \
                                                       \
        V128 result;                                   \
        SIMDE_V128_TO_SIMD_V128(simde_result, result); \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, result); \
                                                       \
    } while (0)
                    case SIMD_v128_load8x8_s:
                    {
                        SIMD_LOAD_OP(simde_wasm_i16x8_load8x8);
                        break;
                    }
                    case SIMD_v128_load8x8_u:
                    {
                        SIMD_LOAD_OP(simde_wasm_u16x8_load8x8);
                        break;
                    }
                    case SIMD_v128_load16x4_s:
                    {
                        SIMD_LOAD_OP(simde_wasm_i32x4_load16x4);
                        break;
                    }
                    case SIMD_v128_load16x4_u:
                    {
                        SIMD_LOAD_OP(simde_wasm_u32x4_load16x4);
                        break;
                    }
                    case SIMD_v128_load32x2_s:
                    {
                        SIMD_LOAD_OP(simde_wasm_i64x2_load32x2);
                        break;
                    }
                    case SIMD_v128_load32x2_u:
                    {
                        SIMD_LOAD_OP(simde_wasm_u64x2_load32x2);
                        break;
                    }
#define SIMD_LOAD_SPLAT_OP(simde_func, width)          \
    do {                                               \
        uint32 offset, addr;                           \
        offset = read_uint32(frame_ip);                \
        addr = POP_I32();                              \
        addr_ret = GET_OFFSET();                       \
        CHECK_MEMORY_OVERFLOW(width / 8);              \
                                                       \
        simde_v128_t simde_result = simde_func(maddr); \
                                                       \
        V128 result;                                   \
        SIMDE_V128_TO_SIMD_V128(simde_result, result); \
                                                       \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, result); \
    } while (0)

                    case SIMD_v128_load8_splat:
                    {
                        SIMD_LOAD_SPLAT_OP(simde_wasm_v128_load8_splat, 8);
                        break;
                    }
                    case SIMD_v128_load16_splat:
                    {
                        SIMD_LOAD_SPLAT_OP(simde_wasm_v128_load16_splat, 16);
                        break;
                    }
                    case SIMD_v128_load32_splat:
                    {
                        SIMD_LOAD_SPLAT_OP(simde_wasm_v128_load32_splat, 32);
                        break;
                    }
                    case SIMD_v128_load64_splat:
                    {
                        SIMD_LOAD_SPLAT_OP(simde_wasm_v128_load64_splat, 64);
                        break;
                    }
                    case SIMD_v128_store:
                    {
                        uint32 offset, addr;
                        offset = read_uint32(frame_ip);
                        V128 data = POP_V128();
                        addr = POP_I32();

                        CHECK_MEMORY_OVERFLOW(16);
                        STORE_V128(maddr, data);
                        break;
                    }

                    /* Basic */
                    case SIMD_v128_const:
                    {
                        uint8 *orig_ip = frame_ip;

                        frame_ip += sizeof(V128);
                        addr_ret = GET_OFFSET();

                        PUT_V128_TO_ADDR(frame_lp + addr_ret, *(V128 *)orig_ip);
                        break;
                    }
                    /* TODO: Add a faster SIMD implementation */
                    case SIMD_v8x16_shuffle:
                    {
                        V128 indices;
                        bh_memcpy_s(&indices, sizeof(V128), frame_ip,
                                    sizeof(V128));
                        frame_ip += sizeof(V128);

                        V128 v2 = POP_V128();
                        V128 v1 = POP_V128();
                        addr_ret = GET_OFFSET();

                        V128 result;
                        for (int i = 0; i < 16; i++) {
                            uint8_t index = indices.i8x16[i];
                            if (index < 16) {
                                result.i8x16[i] = v1.i8x16[index];
                            }
                            else {
                                result.i8x16[i] = v2.i8x16[index - 16];
                            }
                        }

                        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);
                        break;
                    }
                    case SIMD_v8x16_swizzle:
                    {
                        V128 v2 = POP_V128();
                        V128 v1 = POP_V128();
                        addr_ret = GET_OFFSET();
                        simde_v128_t simde_result = simde_wasm_i8x16_swizzle(
                            SIMD_V128_TO_SIMDE_V128(v1),
                            SIMD_V128_TO_SIMDE_V128(v2));

                        V128 result;
                        SIMDE_V128_TO_SIMD_V128(simde_result, result);

                        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);
                        break;
                    }

                    /* Splat */
#define SIMD_SPLAT_OP(simde_func, pop_func, val_type)  \
    do {                                               \
        val_type v = pop_func();                       \
        addr_ret = GET_OFFSET();                       \
                                                       \
        simde_v128_t simde_result = simde_func(v);     \
                                                       \
        V128 result;                                   \
        SIMDE_V128_TO_SIMD_V128(simde_result, result); \
                                                       \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, result); \
    } while (0)

#define SIMD_SPLAT_OP_I32(simde_func) SIMD_SPLAT_OP(simde_func, POP_I32, uint32)
#define SIMD_SPLAT_OP_I64(simde_func) SIMD_SPLAT_OP(simde_func, POP_I64, uint64)
#define SIMD_SPLAT_OP_F32(simde_func) \
    SIMD_SPLAT_OP(simde_func, POP_F32, float32)
#define SIMD_SPLAT_OP_F64(simde_func) \
    SIMD_SPLAT_OP(simde_func, POP_F64, float64)

                    case SIMD_i8x16_splat:
                    {
                        val = POP_I32();
                        addr_ret = GET_OFFSET();

                        simde_v128_t simde_result = simde_wasm_i8x16_splat(val);

                        V128 result;
                        SIMDE_V128_TO_SIMD_V128(simde_result, result);

                        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);
                        break;
                    }
                    case SIMD_i16x8_splat:
                    {
                        SIMD_SPLAT_OP_I32(simde_wasm_i16x8_splat);
                        break;
                    }
                    case SIMD_i32x4_splat:
                    {
                        SIMD_SPLAT_OP_I32(simde_wasm_i32x4_splat);
                        break;
                    }
                    case SIMD_i64x2_splat:
                    {
                        SIMD_SPLAT_OP_I64(simde_wasm_i64x2_splat);
                        break;
                    }
                    case SIMD_f32x4_splat:
                    {
                        SIMD_SPLAT_OP_F32(simde_wasm_f32x4_splat);
                        break;
                    }
                    case SIMD_f64x2_splat:
                    {
                        SIMD_SPLAT_OP_F64(simde_wasm_f64x2_splat);
                        break;
                    }
#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
#define SIMD_LANE_HANDLE_UNALIGNED_ACCESS()
#else
#define SIMD_LANE_HANDLE_UNALIGNED_ACCESS() (void)*frame_ip++
#endif /* WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0 */

#define SIMD_EXTRACT_LANE_OP(register, return_type, push_elem) \
    do {                                                       \
        uint8 lane = *frame_ip++;                              \
        SIMD_LANE_HANDLE_UNALIGNED_ACCESS();                   \
        V128 v = POP_V128();                                   \
        push_elem((return_type)(v.register[lane]));            \
    } while (0)
#define SIMD_REPLACE_LANE_OP(register, return_type, pop_elem) \
    do {                                                      \
        uint8 lane = *frame_ip++;                             \
        SIMD_LANE_HANDLE_UNALIGNED_ACCESS();                  \
        return_type replacement = pop_elem();                 \
        V128 v = POP_V128();                                  \
        v.register[lane] = replacement;                       \
        addr_ret = GET_OFFSET();                              \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, v);             \
    } while (0)
                    case SIMD_i8x16_extract_lane_s:
                    {
                        SIMD_EXTRACT_LANE_OP(i8x16, int8, PUSH_I32);
                        break;
                    }
                    case SIMD_i8x16_extract_lane_u:
                    {
                        SIMD_EXTRACT_LANE_OP(i8x16, uint8, PUSH_I32);
                        break;
                    }
                    case SIMD_i8x16_replace_lane:
                    {
                        SIMD_REPLACE_LANE_OP(i8x16, int8, POP_I32);
                        break;
                    }
                    case SIMD_i16x8_extract_lane_s:
                    {
                        SIMD_EXTRACT_LANE_OP(i16x8, int16, PUSH_I32);
                        break;
                    }
                    case SIMD_i16x8_extract_lane_u:
                    {
                        SIMD_EXTRACT_LANE_OP(i16x8, uint16, PUSH_I32);
                        break;
                    }
                    case SIMD_i16x8_replace_lane:
                    {
                        SIMD_REPLACE_LANE_OP(i16x8, int16, POP_I32);
                        break;
                    }
                    case SIMD_i32x4_extract_lane:
                    {
                        SIMD_EXTRACT_LANE_OP(i32x4, int32, PUSH_I32);
                        break;
                    }
                    case SIMD_i32x4_replace_lane:
                    {
                        SIMD_REPLACE_LANE_OP(i32x4, int32, POP_I32);
                        break;
                    }
                    case SIMD_i64x2_extract_lane:
                    {
                        SIMD_EXTRACT_LANE_OP(i64x2, int64, PUSH_I64);
                        break;
                    }
                    case SIMD_i64x2_replace_lane:
                    {
                        SIMD_REPLACE_LANE_OP(i64x2, int64, POP_I64);
                        break;
                    }
                    case SIMD_f32x4_extract_lane:
                    {
                        SIMD_EXTRACT_LANE_OP(f32x4, float32, PUSH_F32);
                        break;
                    }
                    case SIMD_f32x4_replace_lane:
                    {
                        SIMD_REPLACE_LANE_OP(f32x4, float32, POP_F32);
                        break;
                    }
                    case SIMD_f64x2_extract_lane:
                    {
                        SIMD_EXTRACT_LANE_OP(f64x2, float64, PUSH_F64);
                        break;
                    }
                    case SIMD_f64x2_replace_lane:
                    {
                        SIMD_REPLACE_LANE_OP(f64x2, float64, POP_F64);
                        break;
                    }

#define SIMD_DOUBLE_OP(simde_func)                                           \
    do {                                                                     \
        V128 v2 = POP_V128();                                                \
        V128 v1 = POP_V128();                                                \
        addr_ret = GET_OFFSET();                                             \
                                                                             \
        simde_v128_t simde_result = simde_func(SIMD_V128_TO_SIMDE_V128(v1),  \
                                               SIMD_V128_TO_SIMDE_V128(v2)); \
                                                                             \
        V128 result;                                                         \
        SIMDE_V128_TO_SIMD_V128(simde_result, result);                       \
                                                                             \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);                       \
    } while (0)

                    /* i8x16 comparison operations */
                    case SIMD_i8x16_eq:
                    {
                        V128 v2 = POP_V128();
                        V128 v1 = POP_V128();
                        addr_ret = GET_OFFSET();

                        simde_v128_t simde_result =
                            simde_wasm_i8x16_eq(SIMD_V128_TO_SIMDE_V128(v1),
                                                SIMD_V128_TO_SIMDE_V128(v2));

                        V128 result;
                        SIMDE_V128_TO_SIMD_V128(simde_result, result);

                        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);
                        break;
                    }
                    case SIMD_i8x16_ne:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_ne);
                        break;
                    }
                    case SIMD_i8x16_lt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_lt);
                        break;
                    }
                    case SIMD_i8x16_lt_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_lt);
                        break;
                    }
                    case SIMD_i8x16_gt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_gt);
                        break;
                    }
                    case SIMD_i8x16_gt_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_gt);
                        break;
                    }
                    case SIMD_i8x16_le_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_le);
                        break;
                    }
                    case SIMD_i8x16_le_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_le);
                        break;
                    }
                    case SIMD_i8x16_ge_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_ge);
                        break;
                    }
                    case SIMD_i8x16_ge_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_ge);
                        break;
                    }

                    /* i16x8 comparison operations */
                    case SIMD_i16x8_eq:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_eq);
                        break;
                    }
                    case SIMD_i16x8_ne:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_ne);
                        break;
                    }
                    case SIMD_i16x8_lt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_lt);
                        break;
                    }
                    case SIMD_i16x8_lt_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_lt);
                        break;
                    }
                    case SIMD_i16x8_gt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_gt);
                        break;
                    }
                    case SIMD_i16x8_gt_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_gt);
                        break;
                    }
                    case SIMD_i16x8_le_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_le);
                        break;
                    }
                    case SIMD_i16x8_le_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_le);
                        break;
                    }
                    case SIMD_i16x8_ge_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_ge);
                        break;
                    }
                    case SIMD_i16x8_ge_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_ge);
                        break;
                    }

                    /*  i32x4 comparison operations */
                    case SIMD_i32x4_eq:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_eq);
                        break;
                    }
                    case SIMD_i32x4_ne:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_ne);
                        break;
                    }
                    case SIMD_i32x4_lt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_lt);
                        break;
                    }
                    case SIMD_i32x4_lt_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_lt);
                        break;
                    }
                    case SIMD_i32x4_gt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_gt);
                        break;
                    }
                    case SIMD_i32x4_gt_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_gt);
                        break;
                    }
                    case SIMD_i32x4_le_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_le);
                        break;
                    }
                    case SIMD_i32x4_le_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_le);
                        break;
                    }
                    case SIMD_i32x4_ge_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_ge);
                        break;
                    }
                    case SIMD_i32x4_ge_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_ge);
                        break;
                    }

                    /* f32x4 comparison operations */
                    case SIMD_f32x4_eq:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_eq);
                        break;
                    }
                    case SIMD_f32x4_ne:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_ne);
                        break;
                    }
                    case SIMD_f32x4_lt:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_lt);
                        break;
                    }
                    case SIMD_f32x4_gt:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_gt);
                        break;
                    }
                    case SIMD_f32x4_le:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_le);
                        break;
                    }
                    case SIMD_f32x4_ge:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_ge);
                        break;
                    }

                    /* f64x2 comparison operations */
                    case SIMD_f64x2_eq:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_eq);
                        break;
                    }
                    case SIMD_f64x2_ne:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_ne);
                        break;
                    }
                    case SIMD_f64x2_lt:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_lt);
                        break;
                    }
                    case SIMD_f64x2_gt:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_gt);
                        break;
                    }
                    case SIMD_f64x2_le:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_le);
                        break;
                    }
                    case SIMD_f64x2_ge:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_ge);
                        break;
                    }

                    /* v128 bitwise operations */
#define SIMD_V128_BITWISE_OP_COMMON(result_expr_0, result_expr_1) \
    do {                                                          \
        V128 result;                                              \
        result.i64x2[0] = (result_expr_0);                        \
        result.i64x2[1] = (result_expr_1);                        \
        addr_ret = GET_OFFSET();                                  \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);            \
    } while (0)

                    case SIMD_v128_not:
                    {
                        V128 value = POP_V128();
                        SIMD_V128_BITWISE_OP_COMMON(~value.i64x2[0],
                                                    ~value.i64x2[1]);
                        break;
                    }
                    case SIMD_v128_and:
                    {
                        V128 v2 = POP_V128();
                        V128 v1 = POP_V128();
                        SIMD_V128_BITWISE_OP_COMMON(v1.i64x2[0] & v2.i64x2[0],
                                                    v1.i64x2[1] & v2.i64x2[1]);
                        break;
                    }
                    case SIMD_v128_andnot:
                    {
                        V128 v2 = POP_V128();
                        V128 v1 = POP_V128();
                        SIMD_V128_BITWISE_OP_COMMON(
                            v1.i64x2[0] & (~v2.i64x2[0]),
                            v1.i64x2[1] & (~v2.i64x2[1]));
                        break;
                    }
                    case SIMD_v128_or:
                    {
                        V128 v2 = POP_V128();
                        V128 v1 = POP_V128();
                        SIMD_V128_BITWISE_OP_COMMON(v1.i64x2[0] | v2.i64x2[0],
                                                    v1.i64x2[1] | v2.i64x2[1]);
                        break;
                    }
                    case SIMD_v128_xor:
                    {
                        V128 v2 = POP_V128();
                        V128 v1 = POP_V128();
                        SIMD_V128_BITWISE_OP_COMMON(v1.i64x2[0] ^ v2.i64x2[0],
                                                    v1.i64x2[1] ^ v2.i64x2[1]);
                        break;
                    }
                    case SIMD_v128_bitselect:
                    {
                        V128 v1 = POP_V128();
                        V128 v2 = POP_V128();
                        V128 v3 = POP_V128();
                        addr_ret = GET_OFFSET();

                        simde_v128_t simde_result = simde_wasm_v128_bitselect(
                            SIMD_V128_TO_SIMDE_V128(v3),
                            SIMD_V128_TO_SIMDE_V128(v2),
                            SIMD_V128_TO_SIMDE_V128(v1));

                        V128 result;
                        SIMDE_V128_TO_SIMD_V128(simde_result, result);

                        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);
                        break;
                    }
                    case SIMD_v128_any_true:
                    {
                        V128 value = POP_V128();
                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] =
                            value.i64x2[0] != 0 || value.i64x2[1] != 0;
                        break;
                    }

#define SIMD_LOAD_LANE_COMMON(vec, register, lane, width)            \
    do {                                                             \
        addr_ret = GET_OFFSET();                                     \
        CHECK_MEMORY_OVERFLOW(width / 8);                            \
        if (width == 64) {                                           \
            vec.register[lane] = GET_I64_FROM_ADDR((uint32 *)maddr); \
        }                                                            \
        else {                                                       \
            vec.register[lane] = *(uint##width *)(maddr);            \
        }                                                            \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, vec);                  \
    } while (0)

#define SIMD_LOAD_LANE_OP(register, width)                 \
    do {                                                   \
        uint32 offset, addr;                               \
        offset = read_uint32(frame_ip);                    \
        V128 vec = POP_V128();                             \
        addr = POP_I32();                                  \
        int lane = *frame_ip++;                            \
        SIMD_LANE_HANDLE_UNALIGNED_ACCESS();               \
        SIMD_LOAD_LANE_COMMON(vec, register, lane, width); \
    } while (0)

                    case SIMD_v128_load8_lane:
                    {
                        SIMD_LOAD_LANE_OP(i8x16, 8);
                        break;
                    }
                    case SIMD_v128_load16_lane:
                    {
                        SIMD_LOAD_LANE_OP(i16x8, 16);
                        break;
                    }
                    case SIMD_v128_load32_lane:
                    {
                        SIMD_LOAD_LANE_OP(i32x4, 32);
                        break;
                    }
                    case SIMD_v128_load64_lane:
                    {
                        SIMD_LOAD_LANE_OP(i64x2, 64);
                        break;
                    }
#define SIMD_STORE_LANE_OP(register, width)               \
    do {                                                  \
        uint32 offset, addr;                              \
        offset = read_uint32(frame_ip);                   \
        V128 vec = POP_V128();                            \
        addr = POP_I32();                                 \
        int lane = *frame_ip++;                           \
        SIMD_LANE_HANDLE_UNALIGNED_ACCESS();              \
        CHECK_MEMORY_OVERFLOW(width / 8);                 \
        if (width == 64) {                                \
            STORE_I64(maddr, vec.register[lane]);         \
        }                                                 \
        else {                                            \
            *(uint##width *)(maddr) = vec.register[lane]; \
        }                                                 \
    } while (0)

                    case SIMD_v128_store8_lane:
                    {
                        SIMD_STORE_LANE_OP(i8x16, 8);
                        break;
                    }

                    case SIMD_v128_store16_lane:
                    {
                        SIMD_STORE_LANE_OP(i16x8, 16);
                        break;
                    }

                    case SIMD_v128_store32_lane:
                    {
                        SIMD_STORE_LANE_OP(i32x4, 32);
                        break;
                    }

                    case SIMD_v128_store64_lane:
                    {
                        SIMD_STORE_LANE_OP(i64x2, 64);
                        break;
                    }
#define SIMD_LOAD_ZERO_OP(register, width)                 \
    do {                                                   \
        uint32 offset, addr;                               \
        offset = read_uint32(frame_ip);                    \
        addr = POP_I32();                                  \
        int32 lane = 0;                                    \
        V128 vec = { 0 };                                  \
        SIMD_LOAD_LANE_COMMON(vec, register, lane, width); \
    } while (0)

                    case SIMD_v128_load32_zero:
                    {
                        SIMD_LOAD_ZERO_OP(i32x4, 32);
                        break;
                    }
                    case SIMD_v128_load64_zero:
                    {
                        SIMD_LOAD_ZERO_OP(i64x2, 64);
                        break;
                    }

#define SIMD_SINGLE_OP(simde_func)                                           \
    do {                                                                     \
        V128 v1 = POP_V128();                                                \
        addr_ret = GET_OFFSET();                                             \
                                                                             \
        simde_v128_t simde_result = simde_func(SIMD_V128_TO_SIMDE_V128(v1)); \
                                                                             \
        V128 result;                                                         \
        SIMDE_V128_TO_SIMD_V128(simde_result, result);                       \
                                                                             \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);                       \
    } while (0)

                    /* Float conversion */
                    case SIMD_f32x4_demote_f64x2_zero:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_demote_f64x2_zero);
                        break;
                    }
                    case SIMD_f64x2_promote_low_f32x4_zero:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_promote_low_f32x4);
                        break;
                    }

                    /* i8x16 operations */
                    case SIMD_i8x16_abs:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i8x16_abs);
                        break;
                    }
                    case SIMD_i8x16_neg:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i8x16_neg);
                        break;
                    }
                    case SIMD_i8x16_popcnt:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i8x16_popcnt);
                        break;
                    }
                    case SIMD_i8x16_all_true:
                    {
                        V128 v1 = POP_V128();

                        bool result = simde_wasm_i8x16_all_true(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }

                    case SIMD_i8x16_bitmask:
                    {
                        V128 v1 = POP_V128();

                        uint32_t result = simde_wasm_i8x16_bitmask(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }
                    case SIMD_i8x16_narrow_i16x8_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_narrow_i16x8);
                        break;
                    }
                    case SIMD_i8x16_narrow_i16x8_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_narrow_i16x8);
                        break;
                    }
                    case SIMD_f32x4_ceil:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_ceil);
                        break;
                    }
                    case SIMD_f32x4_floor:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_floor);
                        break;
                    }
                    case SIMD_f32x4_trunc:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_trunc);
                        break;
                    }
                    case SIMD_f32x4_nearest:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_nearest);
                        break;
                    }
#define SIMD_LANE_SHIFT(simde_func)                     \
    do {                                                \
        int32 c = POP_I32();                            \
        V128 v1 = POP_V128();                           \
        addr_ret = GET_OFFSET();                        \
                                                        \
        simde_v128_t simde_result =                     \
            simde_func(SIMD_V128_TO_SIMDE_V128(v1), c); \
                                                        \
        V128 result;                                    \
        SIMDE_V128_TO_SIMD_V128(simde_result, result);  \
                                                        \
        PUT_V128_TO_ADDR(frame_lp + addr_ret, result);  \
    } while (0)
                    case SIMD_i8x16_shl:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i8x16_shl);
                        break;
                    }
                    case SIMD_i8x16_shr_s:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i8x16_shr);
                        break;
                    }
                    case SIMD_i8x16_shr_u:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_u8x16_shr);
                        break;
                    }
                    case SIMD_i8x16_add:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_add);
                        break;
                    }
                    case SIMD_i8x16_add_sat_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_add_sat);
                        break;
                    }
                    case SIMD_i8x16_add_sat_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_add_sat);
                        break;
                    }
                    case SIMD_i8x16_sub:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_sub);
                        break;
                    }
                    case SIMD_i8x16_sub_sat_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_sub_sat);
                        break;
                    }
                    case SIMD_i8x16_sub_sat_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_sub_sat);
                        break;
                    }
                    case SIMD_f64x2_ceil:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_ceil);
                        break;
                    }
                    case SIMD_f64x2_floor:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_floor);
                        break;
                    }
                    case SIMD_i8x16_min_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_min);
                        break;
                    }
                    case SIMD_i8x16_min_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_min);
                        break;
                    }
                    case SIMD_i8x16_max_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i8x16_max);
                        break;
                    }
                    case SIMD_i8x16_max_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_max);
                        break;
                    }
                    case SIMD_f64x2_trunc:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_trunc);
                        break;
                    }
                    case SIMD_i8x16_avgr_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u8x16_avgr);
                        break;
                    }
                    case SIMD_i16x8_extadd_pairwise_i8x16_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i16x8_extadd_pairwise_i8x16);
                        break;
                    }
                    case SIMD_i16x8_extadd_pairwise_i8x16_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u16x8_extadd_pairwise_u8x16);
                        break;
                    }
                    case SIMD_i32x4_extadd_pairwise_i16x8_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i32x4_extadd_pairwise_i16x8);
                        break;
                    }
                    case SIMD_i32x4_extadd_pairwise_i16x8_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u32x4_extadd_pairwise_u16x8);
                        break;
                    }

                    /* i16x8 operations */
                    case SIMD_i16x8_abs:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i16x8_abs);
                        break;
                    }
                    case SIMD_i16x8_neg:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i16x8_neg);
                        break;
                    }
                    case SIMD_i16x8_q15mulr_sat_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_q15mulr_sat);
                        break;
                    }
                    case SIMD_i16x8_all_true:
                    {
                        V128 v1 = POP_V128();

                        bool result = simde_wasm_i16x8_all_true(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }
                    case SIMD_i16x8_bitmask:
                    {
                        V128 v1 = POP_V128();

                        uint32_t result = simde_wasm_i16x8_bitmask(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }
                    case SIMD_i16x8_narrow_i32x4_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_narrow_i32x4);
                        break;
                    }
                    case SIMD_i16x8_narrow_i32x4_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_narrow_i32x4);
                        break;
                    }
                    case SIMD_i16x8_extend_low_i8x16_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i16x8_extend_low_i8x16);
                        break;
                    }
                    case SIMD_i16x8_extend_high_i8x16_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i16x8_extend_high_i8x16);
                        break;
                    }
                    case SIMD_i16x8_extend_low_i8x16_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u16x8_extend_low_u8x16);
                        break;
                    }
                    case SIMD_i16x8_extend_high_i8x16_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u16x8_extend_high_u8x16);
                        break;
                    }
                    case SIMD_i16x8_shl:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i16x8_shl);
                        break;
                    }
                    case SIMD_i16x8_shr_s:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i16x8_shr);
                        break;
                    }
                    case SIMD_i16x8_shr_u:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_u16x8_shr);
                        break;
                    }
                    case SIMD_i16x8_add:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_add);
                        break;
                    }
                    case SIMD_i16x8_add_sat_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_add_sat);
                        break;
                    }
                    case SIMD_i16x8_add_sat_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_add_sat);
                        break;
                    }
                    case SIMD_i16x8_sub:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_sub);
                        break;
                    }
                    case SIMD_i16x8_sub_sat_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_sub_sat);
                        break;
                    }
                    case SIMD_i16x8_sub_sat_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_sub_sat);
                        break;
                    }
                    case SIMD_f64x2_nearest:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_nearest);
                        break;
                    }
                    case SIMD_i16x8_mul:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_mul);
                        break;
                    }
                    case SIMD_i16x8_min_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_min);
                        break;
                    }
                    case SIMD_i16x8_min_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_min);
                        break;
                    }
                    case SIMD_i16x8_max_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_max);
                        break;
                    }
                    case SIMD_i16x8_max_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_max);
                        break;
                    }
                    case SIMD_i16x8_avgr_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_avgr);
                        break;
                    }
                    case SIMD_i16x8_extmul_low_i8x16_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_extmul_low_i8x16);
                        break;
                    }
                    case SIMD_i16x8_extmul_high_i8x16_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i16x8_extmul_high_i8x16);
                        break;
                    }
                    case SIMD_i16x8_extmul_low_i8x16_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_extmul_low_u8x16);
                        break;
                    }
                    case SIMD_i16x8_extmul_high_i8x16_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u16x8_extmul_high_u8x16);
                        break;
                    }

                    /* i32x4 operations */
                    case SIMD_i32x4_abs:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i32x4_abs);
                        break;
                    }
                    case SIMD_i32x4_neg:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i32x4_neg);
                        break;
                    }
                    case SIMD_i32x4_all_true:
                    {
                        V128 v1 = POP_V128();

                        bool result = simde_wasm_i32x4_all_true(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }
                    case SIMD_i32x4_bitmask:
                    {
                        V128 v1 = POP_V128();

                        uint32_t result = simde_wasm_i32x4_bitmask(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }
                    case SIMD_i32x4_extend_low_i16x8_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i32x4_extend_low_i16x8);
                        break;
                    }
                    case SIMD_i32x4_extend_high_i16x8_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i32x4_extend_high_i16x8);
                        break;
                    }
                    case SIMD_i32x4_extend_low_i16x8_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u32x4_extend_low_u16x8);
                        break;
                    }
                    case SIMD_i32x4_extend_high_i16x8_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u32x4_extend_high_u16x8);
                        break;
                    }
                    case SIMD_i32x4_shl:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i32x4_shl);
                        break;
                    }
                    case SIMD_i32x4_shr_s:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i32x4_shr);
                        break;
                    }
                    case SIMD_i32x4_shr_u:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_u32x4_shr);
                        break;
                    }
                    case SIMD_i32x4_add:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_add);
                        break;
                    }
                    case SIMD_i32x4_sub:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_sub);
                        break;
                    }
                    case SIMD_i32x4_mul:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_mul);
                        break;
                    }
                    case SIMD_i32x4_min_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_min);
                        break;
                    }
                    case SIMD_i32x4_min_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_min);
                        break;
                    }
                    case SIMD_i32x4_max_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_max);
                        break;
                    }
                    case SIMD_i32x4_max_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_max);
                        break;
                    }
                    case SIMD_i32x4_dot_i16x8_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_dot_i16x8);
                        break;
                    }
                    case SIMD_i32x4_extmul_low_i16x8_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_extmul_low_i16x8);
                        break;
                    }
                    case SIMD_i32x4_extmul_high_i16x8_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i32x4_extmul_high_i16x8);
                        break;
                    }
                    case SIMD_i32x4_extmul_low_i16x8_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_extmul_low_u16x8);
                        break;
                    }
                    case SIMD_i32x4_extmul_high_i16x8_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u32x4_extmul_high_u16x8);
                        break;
                    }

                    /* i64x2 operations */
                    case SIMD_i64x2_abs:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i64x2_abs);
                        break;
                    }
                    case SIMD_i64x2_neg:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i64x2_neg);
                        break;
                    }
                    case SIMD_i64x2_all_true:
                    {
                        V128 v1 = POP_V128();

                        bool result = simde_wasm_i64x2_all_true(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }
                    case SIMD_i64x2_bitmask:
                    {
                        V128 v1 = POP_V128();

                        uint32_t result = simde_wasm_i64x2_bitmask(
                            SIMD_V128_TO_SIMDE_V128(v1));

                        addr_ret = GET_OFFSET();
                        frame_lp[addr_ret] = result;
                        break;
                    }
                    case SIMD_i64x2_extend_low_i32x4_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i64x2_extend_low_i32x4);
                        break;
                    }
                    case SIMD_i64x2_extend_high_i32x4_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i64x2_extend_high_i32x4);
                        break;
                    }
                    case SIMD_i64x2_extend_low_i32x4_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u64x2_extend_low_u32x4);
                        break;
                    }
                    case SIMD_i64x2_extend_high_i32x4_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u64x2_extend_high_u32x4);
                        break;
                    }
                    case SIMD_i64x2_shl:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i64x2_shl);
                        break;
                    }
                    case SIMD_i64x2_shr_s:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_i64x2_shr);
                        break;
                    }
                    case SIMD_i64x2_shr_u:
                    {
                        SIMD_LANE_SHIFT(simde_wasm_u64x2_shr);
                        break;
                    }
                    case SIMD_i64x2_add:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_add);
                        break;
                    }
                    case SIMD_i64x2_sub:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_sub);
                        break;
                    }
                    case SIMD_i64x2_mul:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_mul);
                        break;
                    }
                    case SIMD_i64x2_eq:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_eq);
                        break;
                    }
                    case SIMD_i64x2_ne:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_ne);
                        break;
                    }
                    case SIMD_i64x2_lt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_lt);
                        break;
                    }
                    case SIMD_i64x2_gt_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_gt);
                        break;
                    }
                    case SIMD_i64x2_le_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_le);
                        break;
                    }
                    case SIMD_i64x2_ge_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_ge);
                        break;
                    }
                    case SIMD_i64x2_extmul_low_i32x4_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_extmul_low_i32x4);
                        break;
                    }
                    case SIMD_i64x2_extmul_high_i32x4_s:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_i64x2_extmul_high_i32x4);
                        break;
                    }
                    case SIMD_i64x2_extmul_low_i32x4_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u64x2_extmul_low_u32x4);
                        break;
                    }
                    case SIMD_i64x2_extmul_high_i32x4_u:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_u64x2_extmul_high_u32x4);
                        break;
                    }

                    /* f32x4 opertions */
                    case SIMD_f32x4_abs:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_abs);
                        break;
                    }
                    case SIMD_f32x4_neg:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_neg);
                        break;
                    }
                    case SIMD_f32x4_sqrt:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_sqrt);
                        break;
                    }
                    case SIMD_f32x4_add:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_add);
                        break;
                    }
                    case SIMD_f32x4_sub:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_sub);
                        break;
                    }
                    case SIMD_f32x4_mul:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_mul);
                        break;
                    }
                    case SIMD_f32x4_div:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_div);
                        break;
                    }
                    case SIMD_f32x4_min:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_min);
                        break;
                    }
                    case SIMD_f32x4_max:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_max);
                        break;
                    }
                    case SIMD_f32x4_pmin:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_pmin);
                        break;
                    }
                    case SIMD_f32x4_pmax:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f32x4_pmax);
                        break;
                    }

                    /* f64x2 operations */
                    case SIMD_f64x2_abs:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_abs);
                        break;
                    }
                    case SIMD_f64x2_neg:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_neg);
                        break;
                    }
                    case SIMD_f64x2_sqrt:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_sqrt);
                        break;
                    }
                    case SIMD_f64x2_add:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_add);
                        break;
                    }
                    case SIMD_f64x2_sub:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_sub);
                        break;
                    }
                    case SIMD_f64x2_mul:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_mul);
                        break;
                    }
                    case SIMD_f64x2_div:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_div);
                        break;
                    }
                    case SIMD_f64x2_min:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_min);
                        break;
                    }
                    case SIMD_f64x2_max:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_max);
                        break;
                    }
                    case SIMD_f64x2_pmin:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_pmin);
                        break;
                    }
                    case SIMD_f64x2_pmax:
                    {
                        SIMD_DOUBLE_OP(simde_wasm_f64x2_pmax);
                        break;
                    }

                    /* Conversion operations */
                    case SIMD_i32x4_trunc_sat_f32x4_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i32x4_trunc_sat_f32x4);
                        break;
                    }
                    case SIMD_i32x4_trunc_sat_f32x4_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u32x4_trunc_sat_f32x4);
                        break;
                    }
                    case SIMD_f32x4_convert_i32x4_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_convert_i32x4);
                        break;
                    }
                    case SIMD_f32x4_convert_i32x4_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f32x4_convert_u32x4);
                        break;
                    }
                    case SIMD_i32x4_trunc_sat_f64x2_s_zero:
                    {
                        SIMD_SINGLE_OP(simde_wasm_i32x4_trunc_sat_f64x2_zero);
                        break;
                    }
                    case SIMD_i32x4_trunc_sat_f64x2_u_zero:
                    {
                        SIMD_SINGLE_OP(simde_wasm_u32x4_trunc_sat_f64x2_zero);
                        break;
                    }
                    case SIMD_f64x2_convert_low_i32x4_s:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_convert_low_i32x4);
                        break;
                    }
                    case SIMD_f64x2_convert_low_i32x4_u:
                    {
                        SIMD_SINGLE_OP(simde_wasm_f64x2_convert_low_u32x4);
                        break;
                    }

                    default:
                        wasm_set_exception(module, "unsupported SIMD opcode");
                }
                HANDLE_OP_END();
            }
#endif

            HANDLE_OP(WASM_OP_CALL)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                fidx = read_uint32(frame_ip);
#if WASM_ENABLE_MULTI_MODULE != 0
                if (fidx >= module->e->function_count) {
                    wasm_set_exception(module, "unknown function");
                    goto got_exception;
                }
#endif
                cur_func = module->e->functions + fidx;
                goto call_func_from_interp;
            }

#if WASM_ENABLE_TAIL_CALL != 0
            HANDLE_OP(WASM_OP_RETURN_CALL)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                fidx = read_uint32(frame_ip);
#if WASM_ENABLE_MULTI_MODULE != 0
                if (fidx >= module->e->function_count) {
                    wasm_set_exception(module, "unknown function");
                    goto got_exception;
                }
#endif
                cur_func = module->e->functions + fidx;
                goto call_func_from_return_call;
            }
#endif /* WASM_ENABLE_TAIL_CALL */

#if WASM_ENABLE_LABELS_AS_VALUES == 0
            default:
                wasm_set_exception(module, "unsupported opcode");
                goto got_exception;
        }
#endif

#if WASM_ENABLE_LABELS_AS_VALUES != 0
        HANDLE_OP(WASM_OP_UNUSED_0x0a)
#if WASM_ENABLE_TAIL_CALL == 0
        HANDLE_OP(WASM_OP_RETURN_CALL)
        HANDLE_OP(WASM_OP_RETURN_CALL_INDIRECT)
#endif
#if WASM_ENABLE_SHARED_MEMORY == 0
        HANDLE_OP(WASM_OP_ATOMIC_PREFIX)
#endif
#if WASM_ENABLE_REF_TYPES == 0 && WASM_ENABLE_GC == 0
        HANDLE_OP(WASM_OP_TABLE_GET)
        HANDLE_OP(WASM_OP_TABLE_SET)
        HANDLE_OP(WASM_OP_REF_NULL)
        HANDLE_OP(WASM_OP_REF_IS_NULL)
        HANDLE_OP(WASM_OP_REF_FUNC)
#endif
#if WASM_ENABLE_GC == 0
        /* SELECT_T is converted to SELECT or SELECT_64 */
        HANDLE_OP(WASM_OP_SELECT_T)
        HANDLE_OP(WASM_OP_CALL_REF)
        HANDLE_OP(WASM_OP_RETURN_CALL_REF)
        HANDLE_OP(WASM_OP_REF_EQ)
        HANDLE_OP(WASM_OP_REF_AS_NON_NULL)
        HANDLE_OP(WASM_OP_BR_ON_NULL)
        HANDLE_OP(WASM_OP_BR_ON_NON_NULL)
        HANDLE_OP(WASM_OP_GC_PREFIX)
#endif
#if WASM_ENABLE_EXCE_HANDLING == 0
        /* if exception handling is disabled, these opcodes issue a trap */
        HANDLE_OP(WASM_OP_TRY)
        HANDLE_OP(WASM_OP_CATCH)
        HANDLE_OP(WASM_OP_THROW)
        HANDLE_OP(WASM_OP_RETHROW)
        HANDLE_OP(WASM_OP_DELEGATE)
        HANDLE_OP(WASM_OP_CATCH_ALL)
        HANDLE_OP(EXT_OP_TRY)
#endif
        HANDLE_OP(WASM_OP_UNUSED_0x16)
        HANDLE_OP(WASM_OP_UNUSED_0x17)
        HANDLE_OP(WASM_OP_UNUSED_0x27)
        /* optimized op code */
        HANDLE_OP(WASM_OP_F32_STORE)
        HANDLE_OP(WASM_OP_F64_STORE)
        HANDLE_OP(WASM_OP_F32_LOAD)
        HANDLE_OP(WASM_OP_F64_LOAD)
        HANDLE_OP(EXT_OP_GET_LOCAL_FAST)
        HANDLE_OP(WASM_OP_GET_LOCAL)
        HANDLE_OP(WASM_OP_DROP)
        HANDLE_OP(WASM_OP_DROP_64)
        HANDLE_OP(WASM_OP_BLOCK)
        HANDLE_OP(WASM_OP_LOOP)
        HANDLE_OP(WASM_OP_END)
        HANDLE_OP(WASM_OP_NOP)
        HANDLE_OP(EXT_OP_BLOCK)
        HANDLE_OP(EXT_OP_LOOP)
        HANDLE_OP(EXT_OP_IF)
        HANDLE_OP(EXT_OP_BR_TABLE_CACHE)
#if WASM_ENABLE_SIMDE == 0
        HANDLE_OP(WASM_OP_SIMD_PREFIX)
#endif
        {
            wasm_set_exception(module, "unsupported opcode");
            goto got_exception;
        }
#endif

#if WASM_ENABLE_LABELS_AS_VALUES == 0
        continue;
#else
    FETCH_OPCODE_AND_DISPATCH();
#endif

#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
    call_func_from_return_call:
    {
        uint32 *lp_base = NULL, *lp = NULL;
        int i;

        if (cur_func->param_cell_num > 0
            && !(lp_base = lp = wasm_runtime_malloc(cur_func->param_cell_num
                                                    * sizeof(uint32)))) {
            wasm_set_exception(module, "allocate memory failed");
            goto got_exception;
        }
        for (i = 0; i < cur_func->param_count; i++) {
            if (cur_func->param_types[i] == VALUE_TYPE_I64
                || cur_func->param_types[i] == VALUE_TYPE_F64) {
                PUT_I64_TO_ADDR(
                    lp, GET_OPERAND(uint64, I64,
                                    2 * (cur_func->param_count - i - 1)));
                lp += 2;
            }
            else {
                *lp = GET_OPERAND(uint32, I32,
                                  (2 * (cur_func->param_count - i - 1)));
                lp++;
            }
        }
        frame->lp = frame->operand + cur_func->const_cell_num;
        if (lp - lp_base > 0) {
            word_copy(frame->lp, lp_base, lp - lp_base);
        }
        if (lp_base)
            wasm_runtime_free(lp_base);
        FREE_FRAME(exec_env, frame);
        frame_ip += cur_func->param_count * sizeof(int16);
        wasm_exec_env_set_cur_frame(exec_env, (WASMRuntimeFrame *)prev_frame);
        is_return_call = true;
        goto call_func_from_entry;
    }
#endif /* WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0 */

    call_func_from_interp:
    {
        /* Only do the copy when it's called from interpreter. */
        WASMInterpFrame *outs_area = wasm_exec_env_wasm_stack_top(exec_env);
        int i;

#if WASM_ENABLE_MULTI_MODULE != 0
        if (cur_func->is_import_func) {
            outs_area->lp = outs_area->operand
                            + (cur_func->import_func_inst
                                   ? cur_func->import_func_inst->const_cell_num
                                   : 0);
        }
        else
#endif
        {
            outs_area->lp = outs_area->operand + cur_func->const_cell_num;
        }

        if ((uint8 *)(outs_area->lp + cur_func->param_cell_num)
            > exec_env->wasm_stack.top_boundary) {
            wasm_set_exception(module, "wasm operand stack overflow");
            goto got_exception;
        }

        for (i = 0; i < cur_func->param_count; i++) {
            if (cur_func->param_types[i] == VALUE_TYPE_V128) {
                PUT_V128_TO_ADDR(
                    outs_area->lp,
                    GET_OPERAND_V128(2 * (cur_func->param_count - i - 1)));
                outs_area->lp += 4;
            }
            else if (cur_func->param_types[i] == VALUE_TYPE_I64
                     || cur_func->param_types[i] == VALUE_TYPE_F64) {
                PUT_I64_TO_ADDR(
                    outs_area->lp,
                    GET_OPERAND(uint64, I64,
                                2 * (cur_func->param_count - i - 1)));
                outs_area->lp += 2;
            }
#if WASM_ENABLE_GC != 0
            else if (wasm_is_type_reftype(cur_func->param_types[i])) {
                PUT_REF_TO_ADDR(
                    outs_area->lp,
                    GET_OPERAND(void *, REF,
                                2 * (cur_func->param_count - i - 1)));
                CLEAR_FRAME_REF(
                    *(uint16 *)(frame_ip
                                + (2 * (cur_func->param_count - i - 1))));
                outs_area->lp += REF_CELL_NUM;
            }
#endif
            else {
                *outs_area->lp = GET_OPERAND(
                    uint32, I32, (2 * (cur_func->param_count - i - 1)));
                outs_area->lp++;
            }
        }
        frame_ip += cur_func->param_count * sizeof(int16);
        if (cur_func->ret_cell_num != 0) {
            /* Get the first return value's offset. Since loader emit
             * all return values' offset so we must skip remain return
             * values' offsets.
             */
            WASMFuncType *func_type;
            if (cur_func->is_import_func)
                func_type = cur_func->u.func_import->func_type;
            else
                func_type = cur_func->u.func->func_type;
            frame->ret_offset = GET_OFFSET();
            frame_ip += 2 * (func_type->result_count - 1);
        }
        SYNC_ALL_TO_FRAME();
        prev_frame = frame;
#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
        is_return_call = false;
#endif
    }

    call_func_from_entry:
    {
        if (cur_func->is_import_func) {
#if WASM_ENABLE_MULTI_MODULE != 0
            if (cur_func->import_func_inst) {
                wasm_interp_call_func_import(module, exec_env, cur_func,
                                             prev_frame);
            }
            else
#endif
            {
                wasm_interp_call_func_native(module, exec_env, cur_func,
                                             prev_frame);
            }

#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
            if (is_return_call) {
                /* the frame was freed before tail calling and
                   the prev_frame was set as exec_env's cur_frame,
                   so here we recover context from prev_frame */
                RECOVER_CONTEXT(prev_frame);
            }
            else
#endif
            {
                prev_frame = frame->prev_frame;
                cur_func = frame->function;
                UPDATE_ALL_FROM_FRAME();
            }

            /* update memory size, no need to update memory ptr as
               it isn't changed in wasm_enlarge_memory */
#if !defined(OS_ENABLE_HW_BOUND_CHECK)              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0
            if (memory)
                linear_mem_size = GET_LINEAR_MEMORY_SIZE(memory);
#endif
            if (wasm_copy_exception(module, NULL))
                goto got_exception;
        }
        else {
            WASMFunction *cur_wasm_func = cur_func->u.func;
            uint32 cell_num_of_local_stack;
#if WASM_ENABLE_REF_TYPES != 0 && WASM_ENABLE_GC == 0
            uint32 i, local_cell_idx;
#endif

            cell_num_of_local_stack = cur_func->param_cell_num
                                      + cur_func->local_cell_num
                                      + cur_wasm_func->max_stack_cell_num;
            all_cell_num = cur_func->const_cell_num + cell_num_of_local_stack;
#if WASM_ENABLE_GC != 0
            /* area of frame_ref */
            all_cell_num += (cell_num_of_local_stack + 3) / 4;
            /* cells occupied by locals, POP_REF should not clear frame_ref for
             * these cells */
            local_cell_num =
                cur_func->param_cell_num + cur_func->local_cell_num;
#endif
            /* param_cell_num, local_cell_num, const_cell_num and
               max_stack_cell_num are all no larger than UINT16_MAX (checked
               in loader), all_cell_num must be smaller than 1MB */
            bh_assert(all_cell_num < 1 * BH_MB);

            frame_size = wasm_interp_interp_frame_size(all_cell_num);
            if (!(frame = ALLOC_FRAME(exec_env, frame_size, prev_frame))) {
                frame = prev_frame;
                goto got_exception;
            }

            /* Initialize the interpreter context. */
            frame->function = cur_func;
            frame_ip = wasm_get_func_code(cur_func);
            frame_ip_end = wasm_get_func_code_end(cur_func);

            frame_lp = frame->lp =
                frame->operand + cur_wasm_func->const_cell_num;

            /* Initialize the consts */
            if (cur_wasm_func->const_cell_num > 0) {
                word_copy(frame->operand, (uint32 *)cur_wasm_func->consts,
                          cur_wasm_func->const_cell_num);
            }

            /* Initialize the local variables */
            memset(frame_lp + cur_func->param_cell_num, 0,
                   (uint32)(cur_func->local_cell_num * 4));

#if WASM_ENABLE_REF_TYPES != 0 && WASM_ENABLE_GC == 0
            /* externref/funcref should be NULL_REF rather than 0 */
            local_cell_idx = cur_func->param_cell_num;
            for (i = 0; i < cur_wasm_func->local_count; i++) {
                if (cur_wasm_func->local_types[i] == VALUE_TYPE_EXTERNREF
                    || cur_wasm_func->local_types[i] == VALUE_TYPE_FUNCREF) {
                    *(frame_lp + local_cell_idx) = NULL_REF;
                }
                local_cell_idx +=
                    wasm_value_type_cell_num(cur_wasm_func->local_types[i]);
            }
#endif

#if WASM_ENABLE_GC != 0
            /* frame->ip is used during GC root set enumeration, so we must
             * initialized this field here */
            frame->ip = frame_ip;
            frame_ref = frame->frame_ref =
                (uint8 *)(frame->lp + (uint32)cell_num_of_local_stack);
            init_frame_refs(frame_ref, (uint32)cell_num_of_local_stack,
                            cur_func);
#endif

            wasm_exec_env_set_cur_frame(exec_env, (WASMRuntimeFrame *)frame);
        }
#if WASM_ENABLE_THREAD_MGR != 0
        CHECK_SUSPEND_FLAGS();
#endif
        HANDLE_OP_END();
    }

    return_func:
    {
        FREE_FRAME(exec_env, frame);
        wasm_exec_env_set_cur_frame(exec_env, (WASMRuntimeFrame *)prev_frame);

        if (!prev_frame->ip)
            /* Called from native. */
            return;

        RECOVER_CONTEXT(prev_frame);
#if WASM_ENABLE_GC != 0
        local_cell_num = cur_func->param_cell_num + cur_func->local_cell_num;
#endif
        HANDLE_OP_END();
    }

        (void)frame_ip_end;

#if WASM_ENABLE_SHARED_MEMORY != 0
    unaligned_atomic:
        wasm_set_exception(module, "unaligned atomic");
        goto got_exception;
#endif

#if !defined(OS_ENABLE_HW_BOUND_CHECK)              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0
    out_of_bounds:
        wasm_set_exception(module, "out of bounds memory access");
#endif

    got_exception:
        SYNC_ALL_TO_FRAME();
        return;

#if WASM_ENABLE_LABELS_AS_VALUES == 0
    }
#else
    FETCH_OPCODE_AND_DISPATCH();
#endif
}

#if WASM_ENABLE_LABELS_AS_VALUES != 0
void **
wasm_interp_get_handle_table(void)
{
    WASMModuleInstance module;
    memset(&module, 0, sizeof(WASMModuleInstance));
    wasm_interp_call_func_bytecode(&module, NULL, NULL, NULL);
    return global_handle_table;
}
#endif

#if WASM_ENABLE_GC != 0
bool
wasm_interp_traverse_gc_rootset(WASMExecEnv *exec_env, void *heap)
{
    WASMInterpFrame *frame;
    WASMObjectRef gc_obj;
    WASMFunctionInstance *cur_func;
    uint8 *frame_ref;
    uint32 local_cell_num, i;

    frame = wasm_exec_env_get_cur_frame(exec_env);
    for (; frame; frame = frame->prev_frame) {
        frame_ref = frame->frame_ref;
        cur_func = frame->function;

        if (!cur_func)
            continue;

        local_cell_num = cur_func->param_cell_num;
        if (frame->ip)
            local_cell_num +=
                cur_func->local_cell_num + cur_func->u.func->max_stack_cell_num;

        for (i = 0; i < local_cell_num; i++) {
            if (frame_ref[i]) {
                gc_obj = GET_REF_FROM_ADDR(frame->lp + i);
                if (wasm_obj_is_created_from_heap(gc_obj)) {
                    if (mem_allocator_add_root((mem_allocator_t)heap, gc_obj)) {
                        return false;
                    }
                }
#if UINTPTR_MAX == UINT64_MAX
                bh_assert(frame_ref[i + 1]);
                i++;
#endif
            }
        }
    }
    return true;
}
#endif

void
wasm_interp_call_wasm(WASMModuleInstance *module_inst, WASMExecEnv *exec_env,
                      WASMFunctionInstance *function, uint32 argc,
                      uint32 argv[])
{
    WASMRuntimeFrame *prev_frame = wasm_exec_env_get_cur_frame(exec_env);
    WASMInterpFrame *frame, *outs_area;

    /* Allocate sufficient cells for all kinds of return values.  */
    unsigned all_cell_num =
                 function->ret_cell_num > 2 ? function->ret_cell_num : 2,
             i;
    /* This frame won't be used by JITed code, so only allocate interp
       frame here.  */
    unsigned frame_size;

#if WASM_ENABLE_GC != 0
    all_cell_num += (all_cell_num + 3) / 4;
#endif

    frame_size = wasm_interp_interp_frame_size(all_cell_num);

    if (argc < function->param_cell_num) {
        char buf[128];
        snprintf(buf, sizeof(buf),
                 "invalid argument count %" PRIu32
                 ", must be no smaller than %" PRIu32,
                 argc, (uint32)function->param_cell_num);
        wasm_set_exception(module_inst, buf);
        return;
    }
    argc = function->param_cell_num;

#if defined(OS_ENABLE_HW_BOUND_CHECK) && WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    /*
     * wasm_runtime_detect_native_stack_overflow is done by
     * call_wasm_with_hw_bound_check.
     */
#else
    if (!wasm_runtime_detect_native_stack_overflow(exec_env)) {
        return;
    }
#endif

    if (!(frame =
              ALLOC_FRAME(exec_env, frame_size, (WASMInterpFrame *)prev_frame)))
        return;

    outs_area = wasm_exec_env_wasm_stack_top(exec_env);
    frame->function = NULL;
    frame->ip = NULL;
    /* There is no local variable. */
    frame->lp = frame->operand + 0;
#if WASM_ENABLE_GC != 0
    frame->frame_ref =
        (uint8 *)(frame->lp
                  + (function->ret_cell_num > 2 ? function->ret_cell_num : 2));
#endif
    frame->ret_offset = 0;

    if ((uint8 *)(outs_area->operand + function->const_cell_num + argc)
        > exec_env->wasm_stack.top_boundary) {
        wasm_set_exception((WASMModuleInstance *)exec_env->module_inst,
                           "wasm operand stack overflow");
        return;
    }

    if (argc > 0)
        word_copy(outs_area->operand + function->const_cell_num, argv, argc);

    wasm_exec_env_set_cur_frame(exec_env, frame);

#if defined(os_writegsbase)
    {
        WASMMemoryInstance *memory_inst = wasm_get_default_memory(module_inst);
        if (memory_inst)
            /* write base addr of linear memory to GS segment register */
            os_writegsbase(memory_inst->memory_data);
    }
#endif

    if (function->is_import_func) {
#if WASM_ENABLE_MULTI_MODULE != 0
        if (function->import_module_inst) {
            LOG_DEBUG("it is a function of a sub module");
            wasm_interp_call_func_import(module_inst, exec_env, function,
                                         frame);
        }
        else
#endif
        {
            LOG_DEBUG("it is an native function");
            wasm_interp_call_func_native(module_inst, exec_env, function,
                                         frame);
        }
    }
    else {
        wasm_interp_call_func_bytecode(module_inst, exec_env, function, frame);
    }

    /* Output the return value to the caller */
    if (!wasm_copy_exception(module_inst, NULL)) {
        for (i = 0; i < function->ret_cell_num; i++)
            argv[i] = *(frame->lp + i);
    }
    else {
#if WASM_ENABLE_DUMP_CALL_STACK != 0
        if (wasm_interp_create_call_stack(exec_env)) {
            wasm_interp_dump_call_stack(exec_env, true, NULL, 0);
        }
#endif
    }

    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
    FREE_FRAME(exec_env, frame);
#if WASM_ENABLE_OPCODE_COUNTER != 0
    wasm_interp_dump_op_count();
#endif
}
