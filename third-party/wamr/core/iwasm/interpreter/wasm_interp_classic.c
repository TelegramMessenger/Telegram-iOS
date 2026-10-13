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
#if WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0
#include "../libraries/thread-mgr/thread_manager.h"
#include "../libraries/debug-engine/debug_engine.h"
#endif
#if WASM_ENABLE_FAST_JIT != 0
#include "../fast-jit/jit_compiler.h"
#endif

typedef int32 CellType_I32;
typedef int64 CellType_I64;
typedef float32 CellType_F32;
typedef float64 CellType_F64;

#define BR_TABLE_TMP_BUF_LEN 32

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

#if WASM_ENABLE_MEMORY64 == 0

#if (!defined(OS_ENABLE_HW_BOUND_CHECK) \
     || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0)
#define CHECK_MEMORY_OVERFLOW(bytes)                                           \
    do {                                                                       \
        uint64 offset1 = (uint64)offset + (uint64)addr;                        \
        CHECK_SHARED_HEAP_OVERFLOW(offset1, bytes, maddr)                      \
        if (disable_bounds_checks || offset1 + bytes <= get_linear_mem_size()) \
            /* If offset1 is in valid range, maddr must also                   \
               be in valid range, no need to check it again. */                \
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
             bulk memory operation */                                          \
            maddr = memory->memory_data + offset1;                             \
        else                                                                   \
            goto out_of_bounds;                                                \
    } while (0)

#else /* else of !defined(OS_ENABLE_HW_BOUND_CHECK) || \
         WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 */

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

#endif /* end of !defined(OS_ENABLE_HW_BOUND_CHECK) || \
          WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 */

#else /* else of WASM_ENABLE_MEMORY64 == 0 */

#define CHECK_MEMORY_OVERFLOW(bytes)                                        \
    do {                                                                    \
        uint64 offset1 = (uint64)offset + (uint64)addr;                     \
        CHECK_SHARED_HEAP_OVERFLOW(offset1, bytes, maddr)                   \
        /* If memory64 is enabled, offset1, offset1 + bytes can overflow */ \
        if (disable_bounds_checks                                           \
            || (offset1 >= offset && offset1 + bytes >= offset1             \
                && offset1 + bytes <= get_linear_mem_size()))               \
            maddr = memory->memory_data + offset1;                          \
        else                                                                \
            goto out_of_bounds;                                             \
    } while (0)

#define CHECK_BULK_MEMORY_OVERFLOW(start, bytes, maddr)            \
    do {                                                           \
        uint64 offset1 = (uint64)(start);                          \
        CHECK_SHARED_HEAP_OVERFLOW(offset1, bytes, maddr)          \
        /* If memory64 is enabled, offset1 + bytes can overflow */ \
        if (disable_bounds_checks                                  \
            || (offset1 + bytes >= offset1                         \
                && offset1 + bytes <= get_linear_mem_size()))      \
            /* App heap space is not valid space for               \
             bulk memory operation */                              \
            maddr = memory->memory_data + offset1;                 \
        else                                                       \
            goto out_of_bounds;                                    \
    } while (0)

#endif /* end of WASM_ENABLE_MEMORY64 == 0 */

#define CHECK_ATOMIC_MEMORY_ACCESS()                                 \
    do {                                                             \
        if (((uintptr_t)maddr & (((uintptr_t)1 << align) - 1)) != 0) \
            goto unaligned_atomic;                                   \
    } while (0)

#if WASM_ENABLE_DEBUG_INTERP != 0
#define TRIGGER_WATCHPOINT_SIGTRAP()                              \
    do {                                                          \
        wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TRAP); \
        CHECK_SUSPEND_FLAGS();                                    \
    } while (0)

#define CHECK_WATCHPOINT(list, current_addr)                               \
    do {                                                                   \
        WASMDebugWatchPoint *watchpoint = bh_list_first_elem(list);        \
        while (watchpoint) {                                               \
            WASMDebugWatchPoint *next = bh_list_elem_next(watchpoint);     \
            if (watchpoint->addr <= current_addr                           \
                && watchpoint->addr + watchpoint->length > current_addr) { \
                TRIGGER_WATCHPOINT_SIGTRAP();                              \
            }                                                              \
            watchpoint = next;                                             \
        }                                                                  \
    } while (0)

#define CHECK_READ_WATCHPOINT(addr, offset) \
    CHECK_WATCHPOINT(watch_point_list_read, WASM_ADDR_OFFSET(addr + offset))
#define CHECK_WRITE_WATCHPOINT(addr, offset) \
    CHECK_WATCHPOINT(watch_point_list_write, WASM_ADDR_OFFSET(addr + offset))
#else
#define CHECK_READ_WATCHPOINT(addr, offset) (void)0
#define CHECK_WRITE_WATCHPOINT(addr, offset) (void)0
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

static uint64
read_leb(const uint8 *buf, uint32 *p_offset, uint32 maxbits, bool sign)
{
    uint64 result = 0, byte;
    uint32 offset = *p_offset;
    uint32 shift = 0;

    while (true) {
        byte = buf[offset++];
        result |= ((byte & 0x7f) << shift);
        shift += 7;
        if ((byte & 0x80) == 0) {
            break;
        }
    }
    if (sign && (shift < maxbits) && (byte & 0x40)) {
        /* Sign extend */
        result |= (~((uint64)0)) << shift;
    }
    *p_offset = offset;
    return result;
}

#if WASM_ENABLE_GC != 0
static uint8 *
get_frame_ref(WASMInterpFrame *frame)
{
    WASMFunctionInstance *cur_func = frame->function;
    uint32 all_cell_num;

    if (!cur_func) {
        /* it's a glue frame created in wasm_interp_call_wasm,
           no GC object will be traversed */
        return (uint8 *)frame->lp;
    }
    else if (!frame->ip) {
        /* it's a native method frame created in
           wasm_interp_call_func_native */
        all_cell_num =
            cur_func->param_cell_num > 2 ? cur_func->param_cell_num : 2;
        return (uint8 *)(frame->lp + all_cell_num);
    }
    else {
#if WASM_ENABLE_JIT == 0
        /* it's a wasm bytecode function frame */
        return (uint8 *)frame->csp_boundary;
#else
        return (uint8 *)(frame->lp + cur_func->param_cell_num
                         + cur_func->local_cell_num
                         + cur_func->u.func->max_stack_cell_num);
#endif
    }
}

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
    return get_frame_ref(frame);
}

/* Return the corresponding ref slot of the given address of local
   variable or stack pointer. */

#define COMPUTE_FRAME_REF(ref, lp, p) (ref + (unsigned)((uint32 *)p - lp))

#define FRAME_REF(p) COMPUTE_FRAME_REF(frame_ref, frame_lp, p)

#define FRAME_REF_FOR(frame, p) \
    COMPUTE_FRAME_REF(get_frame_ref(frame), frame->lp, p)

#define CLEAR_FRAME_REF(p, n)                   \
    do {                                        \
        int32 ref_i, ref_n = (int32)(n);        \
        uint8 *ref = FRAME_REF(p);              \
        for (ref_i = 0; ref_i < ref_n; ref_i++) \
            ref[ref_i] = 0;                     \
    } while (0)
#else
#define CLEAR_FRAME_REF(p, n) (void)0
#endif /* end of WASM_ENABLE_GC != 0 */

#define skip_leb(p) while (*p++ & 0x80)

#define PUSH_I32(value)                        \
    do {                                       \
        *(int32 *)frame_sp++ = (int32)(value); \
    } while (0)

#define PUSH_F32(value)                            \
    do {                                           \
        *(float32 *)frame_sp++ = (float32)(value); \
    } while (0)

#define PUSH_I64(value)                   \
    do {                                  \
        PUT_I64_TO_ADDR(frame_sp, value); \
        frame_sp += 2;                    \
    } while (0)

#define PUSH_F64(value)                   \
    do {                                  \
        PUT_F64_TO_ADDR(frame_sp, value); \
        frame_sp += 2;                    \
    } while (0)

#if UINTPTR_MAX == UINT64_MAX
#define PUSH_REF(value)                            \
    do {                                           \
        PUT_REF_TO_ADDR(frame_sp, value);          \
        frame_ref_tmp = FRAME_REF(frame_sp);       \
        *frame_ref_tmp = *(frame_ref_tmp + 1) = 1; \
        frame_sp += 2;                             \
    } while (0)
#define PUSH_I31REF(value)                \
    do {                                  \
        PUT_REF_TO_ADDR(frame_sp, value); \
        frame_sp += 2;                    \
    } while (0)
#else
#define PUSH_REF(value)                      \
    do {                                     \
        PUT_REF_TO_ADDR(frame_sp, value);    \
        frame_ref_tmp = FRAME_REF(frame_sp); \
        *frame_ref_tmp = 1;                  \
        frame_sp++;                          \
    } while (0)
#define PUSH_I31REF(value)                \
    do {                                  \
        PUT_REF_TO_ADDR(frame_sp, value); \
        frame_sp++;                       \
    } while (0)
#endif

#if UINTPTR_MAX == UINT64_MAX
#define PUSH_PTR(value) PUSH_I64(value)
#else
#define PUSH_PTR(value) PUSH_I32(value)
#endif

/* in exception handling, label_type needs to be stored to lookup exception
 * handlers */

#if WASM_ENABLE_EXCE_HANDLING != 0
#define SET_LABEL_TYPE(_label_type) frame_csp->label_type = _label_type
#else
#define SET_LABEL_TYPE(_label_type) (void)0
#endif

#if WASM_ENABLE_MEMORY64 != 0
#define COND_PUSH_TEMPLATE(cond, value)            \
    do {                                           \
        if (cond) {                                \
            PUT_I64_TO_ADDR(frame_sp, value);      \
            frame_sp += 2;                         \
        }                                          \
        else {                                     \
            *(int32 *)frame_sp++ = (int32)(value); \
        }                                          \
    } while (0)
#define PUSH_MEM_OFFSET(value) COND_PUSH_TEMPLATE(is_memory64, value)
#define PUSH_TBL_ELEM_IDX(value) COND_PUSH_TEMPLATE(is_table64, value)
#else
#define PUSH_MEM_OFFSET(value) PUSH_I32(value)
#define PUSH_TBL_ELEM_IDX(value) PUSH_I32(value)
#endif

#define PUSH_PAGE_COUNT(value) PUSH_MEM_OFFSET(value)

#define PUSH_CSP(_label_type, param_cell_num, cell_num, _target_addr) \
    do {                                                              \
        bh_assert(frame_csp < frame->csp_boundary);                   \
        SET_LABEL_TYPE(_label_type);                                  \
        frame_csp->cell_num = cell_num;                               \
        frame_csp->begin_addr = frame_ip;                             \
        frame_csp->target_addr = _target_addr;                        \
        frame_csp->frame_sp = frame_sp - param_cell_num;              \
        frame_csp++;                                                  \
    } while (0)

#define POP_I32() (--frame_sp, *(int32 *)frame_sp)

#define POP_F32() (--frame_sp, *(float32 *)frame_sp)

#define POP_I64() (frame_sp -= 2, GET_I64_FROM_ADDR(frame_sp))

#define POP_F64() (frame_sp -= 2, GET_F64_FROM_ADDR(frame_sp))

#if UINTPTR_MAX == UINT64_MAX
#define POP_REF()                                        \
    (frame_sp -= 2, frame_ref_tmp = FRAME_REF(frame_sp), \
     *frame_ref_tmp = *(frame_ref_tmp + 1) = 0, GET_REF_FROM_ADDR(frame_sp))
#else
#define POP_REF()                                                         \
    (frame_sp--, frame_ref_tmp = FRAME_REF(frame_sp), *frame_ref_tmp = 0, \
     GET_REF_FROM_ADDR(frame_sp))
#endif

#if WASM_ENABLE_MEMORY64 != 0
#define POP_MEM_OFFSET() (is_memory64 ? POP_I64() : (uint32)POP_I32())
#define POP_TBL_ELEM_IDX() (is_table64 ? POP_I64() : (uint32)POP_I32())
#else
#define POP_MEM_OFFSET() POP_I32()
#define POP_TBL_ELEM_IDX() POP_I32()
#endif

#define POP_PAGE_COUNT() POP_MEM_OFFSET()

#define POP_CSP_CHECK_OVERFLOW(n)                      \
    do {                                               \
        bh_assert(frame_csp - n >= frame->csp_bottom); \
    } while (0)

#define POP_CSP()                  \
    do {                           \
        POP_CSP_CHECK_OVERFLOW(1); \
        --frame_csp;               \
    } while (0)

#define POP_CSP_N(n)                                                   \
    do {                                                               \
        uint32 *frame_sp_old = frame_sp;                               \
        uint32 cell_num_to_copy;                                       \
        POP_CSP_CHECK_OVERFLOW(n + 1);                                 \
        frame_csp -= n;                                                \
        frame_ip = (frame_csp - 1)->target_addr;                       \
        /* copy arity values of block */                               \
        frame_sp = (frame_csp - 1)->frame_sp;                          \
        cell_num_to_copy = (frame_csp - 1)->cell_num;                  \
        if (cell_num_to_copy > 0) {                                    \
            word_copy(frame_sp, frame_sp_old - cell_num_to_copy,       \
                      cell_num_to_copy);                               \
            frame_ref_copy(FRAME_REF(frame_sp),                        \
                           FRAME_REF(frame_sp_old - cell_num_to_copy), \
                           cell_num_to_copy);                          \
        }                                                              \
        frame_sp += cell_num_to_copy;                                  \
        CLEAR_FRAME_REF(frame_sp, frame_sp_old - frame_sp);            \
    } while (0)

/* Pop the given number of elements from the given frame's stack.  */
#define POP(N)                        \
    do {                              \
        int n = (N);                  \
        frame_sp -= n;                \
        CLEAR_FRAME_REF(frame_sp, n); \
    } while (0)

#if WASM_ENABLE_EXCE_HANDLING != 0
/* unwind the CSP to a given label and optionally modify the labeltype  */
#define UNWIND_CSP(N, T)                                                   \
    do {                                                                   \
        /* unwind to function frame  */                                    \
        frame_csp -= N;                                                    \
        /* drop handlers and values pushd in try block */                  \
        frame_sp = (frame_csp - 1)->frame_sp;                              \
        (frame_csp - 1)->label_type = T ? T : (frame_csp - 1)->label_type; \
    } while (0)
#endif

#define SYNC_ALL_TO_FRAME()     \
    do {                        \
        frame->sp = frame_sp;   \
        frame->ip = frame_ip;   \
        frame->csp = frame_csp; \
    } while (0)

#define UPDATE_ALL_FROM_FRAME() \
    do {                        \
        frame_sp = frame->sp;   \
        frame_ip = frame->ip;   \
        frame_csp = frame->csp; \
    } while (0)

#define read_leb_int64(p, p_end, res)                  \
    do {                                               \
        uint8 _val = *p;                               \
        if (!(_val & 0x80)) {                          \
            res = (int64)_val;                         \
            if (_val & 0x40)                           \
                /* sign extend */                      \
                res |= 0xFFFFFFFFFFFFFF80LL;           \
            p++;                                       \
        }                                              \
        else {                                         \
            uint32 _off = 0;                           \
            res = (int64)read_leb(p, &_off, 64, true); \
            p += _off;                                 \
        }                                              \
    } while (0)

#define read_leb_uint32(p, p_end, res)                   \
    do {                                                 \
        uint8 _val = *p;                                 \
        if (!(_val & 0x80)) {                            \
            res = _val;                                  \
            p++;                                         \
        }                                                \
        else {                                           \
            uint32 _off = 0;                             \
            res = (uint32)read_leb(p, &_off, 32, false); \
            p += _off;                                   \
        }                                                \
    } while (0)

#define read_leb_int32(p, p_end, res)                  \
    do {                                               \
        uint8 _val = *p;                               \
        if (!(_val & 0x80)) {                          \
            res = (int32)_val;                         \
            if (_val & 0x40)                           \
                /* sign extend */                      \
                res |= 0xFFFFFF80;                     \
            p++;                                       \
        }                                              \
        else {                                         \
            uint32 _off = 0;                           \
            res = (int32)read_leb(p, &_off, 32, true); \
            p += _off;                                 \
        }                                              \
    } while (0)

#if WASM_ENABLE_MEMORY64 != 0
#define read_leb_mem_offset(p, p_end, res)                                \
    do {                                                                  \
        uint8 _val = *p;                                                  \
        if (!(_val & 0x80)) {                                             \
            res = (mem_offset_t)_val;                                     \
            p++;                                                          \
        }                                                                 \
        else {                                                            \
            uint32 _off = 0;                                              \
            res = (mem_offset_t)read_leb(p, &_off, is_memory64 ? 64 : 32, \
                                         false);                          \
            p += _off;                                                    \
        }                                                                 \
    } while (0)
#else
#define read_leb_mem_offset(p, p_end, res) read_leb_uint32(p, p_end, res)
#endif

#if WASM_ENABLE_MULTI_MEMORY != 0
/* If the current memidx differs than the last cached one,
 * update memory related information */
#define read_leb_memidx(p, p_end, res)                        \
    do {                                                      \
        read_leb_uint32(p, p_end, res);                       \
        if (res != memidx_cached) {                           \
            memory = wasm_get_memory_with_idx(module, res);   \
            linear_mem_size = GET_LINEAR_MEMORY_SIZE(memory); \
            memidx_cached = res;                              \
        }                                                     \
    } while (0)
/* First read the alignment, then if it has flag indicating following memidx,
 * read and update memory related information, if it differs than the
 * last(cached) one. If it doesn't have flag reset the
 * memory instance to the default memories[0] */
#define read_leb_memarg(p, p_end, res)                         \
    do {                                                       \
        read_leb_uint32(p, p_end, res);                        \
        if (!(res & OPT_MEMIDX_FLAG))                          \
            memidx = 0;                                        \
        else                                                   \
            read_leb_uint32(p, p_end, memidx);                 \
        if (memidx != memidx_cached) {                         \
            memory = wasm_get_memory_with_idx(module, memidx); \
            linear_mem_size = GET_LINEAR_MEMORY_SIZE(memory);  \
            memidx_cached = memidx;                            \
        }                                                      \
    } while (0)
#else
#define read_leb_memarg(p, p_end, res)  \
    do {                                \
        read_leb_uint32(p, p_end, res); \
        (void)res;                      \
    } while (0)
#define read_leb_memidx(p, p_end, res) read_leb_memarg(p, p_end, res)
#endif

#if WASM_ENABLE_LABELS_AS_VALUES == 0
#define RECOVER_FRAME_IP_END() frame_ip_end = wasm_get_func_code_end(cur_func)
#else
#define RECOVER_FRAME_IP_END() (void)0
#endif

#if WASM_ENABLE_GC != 0
#define RECOVER_FRAME_REF() frame_ref = (uint8 *)frame->csp_boundary
#else
#define RECOVER_FRAME_REF() (void)0
#endif

#define RECOVER_CONTEXT(new_frame)      \
    do {                                \
        frame = (new_frame);            \
        cur_func = frame->function;     \
        prev_frame = frame->prev_frame; \
        frame_ip = frame->ip;           \
        RECOVER_FRAME_IP_END();         \
        frame_lp = frame->lp;           \
        frame_sp = frame->sp;           \
        frame_csp = frame->csp;         \
        RECOVER_FRAME_REF();            \
    } while (0)

#if WASM_ENABLE_LABELS_AS_VALUES != 0
#define GET_OPCODE() opcode = *(frame_ip - 1);
#else
#define GET_OPCODE() (void)0
#endif

#define DEF_OP_I_CONST(ctype, src_op_type)              \
    do {                                                \
        ctype cval;                                     \
        read_leb_##ctype(frame_ip, frame_ip_end, cval); \
        PUSH_##src_op_type(cval);                       \
    } while (0)

#define DEF_OP_EQZ(src_op_type)             \
    do {                                    \
        int32 pop_val;                      \
        pop_val = POP_##src_op_type() == 0; \
        PUSH_I32(pop_val);                  \
    } while (0)

#define DEF_OP_CMP(src_type, src_op_type, cond) \
    do {                                        \
        uint32 res;                             \
        src_type val1, val2;                    \
        val2 = (src_type)POP_##src_op_type();   \
        val1 = (src_type)POP_##src_op_type();   \
        res = val1 cond val2;                   \
        PUSH_I32(res);                          \
    } while (0)

#define DEF_OP_BIT_COUNT(src_type, src_op_type, operation) \
    do {                                                   \
        src_type val1, val2;                               \
        val1 = (src_type)POP_##src_op_type();              \
        val2 = (src_type)operation(val1);                  \
        PUSH_##src_op_type(val2);                          \
    } while (0)

#define DEF_OP_NUMERIC(src_type1, src_type2, src_op_type, operation)  \
    do {                                                              \
        frame_sp -= sizeof(src_type2) / sizeof(uint32);               \
        *(src_type1 *)(frame_sp - sizeof(src_type1) / sizeof(uint32)) \
            operation## = *(src_type2 *)(frame_sp);                   \
    } while (0)

#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0
#define DEF_OP_NUMERIC_64 DEF_OP_NUMERIC
#else
#define DEF_OP_NUMERIC_64(src_type1, src_type2, src_op_type, operation) \
    do {                                                                \
        src_type1 val1;                                                 \
        src_type2 val2;                                                 \
        frame_sp -= 2;                                                  \
        val1 = (src_type1)GET_##src_op_type##_FROM_ADDR(frame_sp - 2);  \
        val2 = (src_type2)GET_##src_op_type##_FROM_ADDR(frame_sp);      \
        val1 operation## = val2;                                        \
        PUT_##src_op_type##_TO_ADDR(frame_sp - 2, val1);                \
    } while (0)
#endif

#define DEF_OP_NUMERIC2(src_type1, src_type2, src_op_type, operation) \
    do {                                                              \
        frame_sp -= sizeof(src_type2) / sizeof(uint32);               \
        *(src_type1 *)(frame_sp - sizeof(src_type1) / sizeof(uint32)) \
            operation## = (*(src_type2 *)(frame_sp) % 32);            \
    } while (0)

#define DEF_OP_NUMERIC2_64(src_type1, src_type2, src_op_type, operation) \
    do {                                                                 \
        src_type1 val1;                                                  \
        src_type2 val2;                                                  \
        frame_sp -= 2;                                                   \
        val1 = (src_type1)GET_##src_op_type##_FROM_ADDR(frame_sp - 2);   \
        val2 = (src_type2)GET_##src_op_type##_FROM_ADDR(frame_sp);       \
        val1 operation## = (val2 % 64);                                  \
        PUT_##src_op_type##_TO_ADDR(frame_sp - 2, val1);                 \
    } while (0)

#define DEF_OP_MATH(src_type, src_op_type, method) \
    do {                                           \
        src_type src_val;                          \
        src_val = POP_##src_op_type();             \
        PUSH_##src_op_type(method(src_val));       \
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
trunc_f32_to_int(WASMModuleInstance *module, uint32 *frame_sp, float32 src_min,
                 float32 src_max, bool saturating, bool is_i32, bool is_sign)
{
    float32 src_value = POP_F32();
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
        PUSH_I32(dst_value_i32);
    }
    else {
        uint64 dst_min = is_sign ? INT64_MIN : 0;
        uint64 dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f32_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        PUSH_I64(dst_value_i64);
    }
    return true;
}

static bool
trunc_f64_to_int(WASMModuleInstance *module, uint32 *frame_sp, float64 src_min,
                 float64 src_max, bool saturating, bool is_i32, bool is_sign)
{
    float64 src_value = POP_F64();
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
        PUSH_I32(dst_value_i32);
    }
    else {
        uint64 dst_min = is_sign ? INT64_MIN : 0;
        uint64 dst_max = is_sign ? INT64_MAX : UINT64_MAX;
        dst_value_i64 = trunc_f64_to_i64(src_value, src_min, src_max, dst_min,
                                         dst_max, is_sign);
        PUSH_I64(dst_value_i64);
    }
    return true;
}

#define DEF_OP_TRUNC_F32(min, max, is_i32, is_sign)                      \
    do {                                                                 \
        if (!trunc_f32_to_int(module, frame_sp, min, max, false, is_i32, \
                              is_sign))                                  \
            goto got_exception;                                          \
    } while (0)

#define DEF_OP_TRUNC_F64(min, max, is_i32, is_sign)                      \
    do {                                                                 \
        if (!trunc_f64_to_int(module, frame_sp, min, max, false, is_i32, \
                              is_sign))                                  \
            goto got_exception;                                          \
    } while (0)

#define DEF_OP_TRUNC_SAT_F32(min, max, is_i32, is_sign)                  \
    do {                                                                 \
        (void)trunc_f32_to_int(module, frame_sp, min, max, true, is_i32, \
                               is_sign);                                 \
    } while (0)

#define DEF_OP_TRUNC_SAT_F64(min, max, is_i32, is_sign)                  \
    do {                                                                 \
        (void)trunc_f64_to_int(module, frame_sp, min, max, true, is_i32, \
                               is_sign);                                 \
    } while (0)

#define DEF_OP_CONVERT(dst_type, dst_op_type, src_type, src_op_type) \
    do {                                                             \
        dst_type value = (dst_type)(src_type)POP_##src_op_type();    \
        PUSH_##dst_op_type(value);                                   \
    } while (0)

#define GET_LOCAL_INDEX_TYPE_AND_OFFSET()                                \
    do {                                                                 \
        uint32 param_count = cur_func->param_count;                      \
        read_leb_uint32(frame_ip, frame_ip_end, local_idx);              \
        bh_assert(local_idx < param_count + cur_func->local_count);      \
        local_offset = cur_func->local_offsets[local_idx];               \
        if (local_idx < param_count)                                     \
            local_type = cur_func->param_types[local_idx];               \
        else                                                             \
            local_type = cur_func->local_types[local_idx - param_count]; \
    } while (0)

#define DEF_ATOMIC_RMW_OPCODE(OP_NAME, op)                           \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME:                           \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME##8_U:                      \
    case WASM_OP_ATOMIC_RMW_I32_##OP_NAME##16_U:                     \
    {                                                                \
        uint32 readv, sval;                                          \
                                                                     \
        sval = POP_I32();                                            \
        addr = POP_MEM_OFFSET();                                     \
                                                                     \
        if (opcode == WASM_OP_ATOMIC_RMW_I32_##OP_NAME##8_U) {       \
            CHECK_MEMORY_OVERFLOW(1);                                \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint32)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I32_##OP_NAME##16_U) { \
            CHECK_MEMORY_OVERFLOW(2);                                \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint32)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else {                                                       \
            CHECK_MEMORY_OVERFLOW(4);                                \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
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
        addr = POP_MEM_OFFSET();                                     \
                                                                     \
        if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##8_U) {       \
            CHECK_MEMORY_OVERFLOW(1);                                \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint64)(*(uint8 *)maddr);                       \
            *(uint8 *)maddr = (uint8)(readv op sval);                \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##16_U) { \
            CHECK_MEMORY_OVERFLOW(2);                                \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint64)LOAD_U16(maddr);                         \
            STORE_U16(maddr, (uint16)(readv op sval));               \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else if (opcode == WASM_OP_ATOMIC_RMW_I64_##OP_NAME##32_U) { \
            CHECK_MEMORY_OVERFLOW(4);                                \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
                                                                     \
            shared_memory_lock(memory);                              \
            readv = (uint64)LOAD_U32(maddr);                         \
            STORE_U32(maddr, (uint32)(readv op sval));               \
            shared_memory_unlock(memory);                            \
        }                                                            \
        else {                                                       \
            uint64 op_result;                                        \
            CHECK_MEMORY_OVERFLOW(8);                                \
            CHECK_ATOMIC_MEMORY_ACCESS();                            \
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

#if WASM_ENABLE_GC != 0
static inline void
frame_ref_copy(uint8 *frame_ref_dest, uint8 *frame_ref_src, unsigned num)
{
    if (frame_ref_dest != frame_ref_src)
        for (; num > 0; num--)
            *frame_ref_dest++ = *frame_ref_src++;
}
#else
#define frame_ref_copy(frame_ref_dst, frame_ref_src, num) (void)0
#endif

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
    char buf[128];
    bool ret;
#if WASM_ENABLE_GC != 0
    WASMFuncType *func_type;
    uint8 *frame_ref;
#endif

    if (!wasm_runtime_detect_native_stack_overflow(exec_env)) {
        return;
    }

    all_cell_num = local_cell_num;
#if WASM_ENABLE_GC != 0
    all_cell_num += (local_cell_num + 3) / 4;
#endif

    if (!(frame =
              ALLOC_FRAME(exec_env, wasm_interp_interp_frame_size(all_cell_num),
                          prev_frame)))
        return;

    frame->function = cur_func;
    frame->ip = NULL;
    frame->sp = frame->lp + local_cell_num;
#if WASM_ENABLE_GC != 0
    /* native function doesn't have operand stack and label stack */
    frame_ref = (uint8 *)frame->sp;
    init_frame_refs(frame_ref, local_cell_num, cur_func);
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
        snprintf(buf, sizeof(buf),
                 "failed to call unlinked import function (%s, %s)",
                 func_import->module_name, func_import->field_name);
        wasm_set_exception(module_inst, buf);
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
        && wasm_is_type_reftype(func_type->types[cur_func->param_count])) {
        frame_ref = (uint8 *)prev_frame->csp_boundary
                    + (unsigned)(uintptr_t)(prev_frame->sp - prev_frame->lp);
        if (!wasm_is_reftype_i31ref(func_type->types[cur_func->param_count])) {
#if UINTPTR_MAX == UINT64_MAX
            *frame_ref = *(frame_ref + 1) = 1;
#else
            *frame_ref = 1;
#endif
        }
    }
#endif

    if (cur_func->ret_cell_num == 1) {
        prev_frame->sp[0] = argv_ret[0];
        prev_frame->sp++;
    }
    else if (cur_func->ret_cell_num == 2) {
        prev_frame->sp[0] = argv_ret[0];
        prev_frame->sp[1] = argv_ret[1];
        prev_frame->sp += 2;
    }

    FREE_FRAME(exec_env, frame);
    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
}

#if WASM_ENABLE_FAST_JIT != 0
bool
fast_jit_invoke_native(WASMExecEnv *exec_env, uint32 func_idx,
                       WASMInterpFrame *prev_frame)
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)exec_env->module_inst;
    WASMFunctionInstance *cur_func = module_inst->e->functions + func_idx;

    wasm_interp_call_func_native(module_inst, exec_env, cur_func, prev_frame);
    return wasm_copy_exception(module_inst, NULL) ? false : true;
}
#endif

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
#if WASM_ENABLE_DEBUG_INTERP != 0
#define CHECK_SUSPEND_FLAGS()                                          \
    do {                                                               \
        os_mutex_lock(&exec_env->wait_lock);                           \
        if (IS_WAMR_TERM_SIG(exec_env->current_status->signal_flag)) { \
            os_mutex_unlock(&exec_env->wait_lock);                     \
            return;                                                    \
        }                                                              \
        if (IS_WAMR_STOP_SIG(exec_env->current_status->signal_flag)) { \
            SYNC_ALL_TO_FRAME();                                       \
            wasm_cluster_thread_waiting_run(exec_env);                 \
        }                                                              \
        os_mutex_unlock(&exec_env->wait_lock);                         \
    } while (0)
#else
#if WASM_SUSPEND_FLAGS_IS_ATOMIC != 0
/* The lock is only needed when the suspend_flags is atomic; otherwise
   the lock is already taken at the time when SUSPENSION_LOCK() is called. */
#define SUSPENSION_LOCK() os_mutex_lock(&exec_env->wait_lock);
#define SUSPENSION_UNLOCK() os_mutex_unlock(&exec_env->wait_lock);
#else
#define SUSPENSION_LOCK()
#define SUSPENSION_UNLOCK()
#endif

#define CHECK_SUSPEND_FLAGS()                                         \
    do {                                                              \
        WASM_SUSPEND_FLAGS_LOCK(exec_env->wait_lock);                 \
        if (WASM_SUSPEND_FLAGS_GET(exec_env->suspend_flags)           \
            & WASM_SUSPEND_FLAG_TERMINATE) {                          \
            /* terminate current thread */                            \
            WASM_SUSPEND_FLAGS_UNLOCK(exec_env->wait_lock);           \
            return;                                                   \
        }                                                             \
        while (WASM_SUSPEND_FLAGS_GET(exec_env->suspend_flags)        \
               & WASM_SUSPEND_FLAG_SUSPEND) {                         \
            /* suspend current thread */                              \
            SUSPENSION_LOCK()                                         \
            os_cond_wait(&exec_env->wait_cond, &exec_env->wait_lock); \
            SUSPENSION_UNLOCK()                                       \
        }                                                             \
        WASM_SUSPEND_FLAGS_UNLOCK(exec_env->wait_lock);               \
    } while (0)
#endif /* WASM_ENABLE_DEBUG_INTERP */
#endif /* WASM_ENABLE_THREAD_MGR */

#if WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0
#if BH_ATOMIC_32_IS_ATOMIC != 0
#define GET_SIGNAL_FLAG()                                             \
    do {                                                              \
        signal_flag =                                                 \
            BH_ATOMIC_32_LOAD(exec_env->current_status->signal_flag); \
    } while (0)
#else
#define GET_SIGNAL_FLAG()                                    \
    do {                                                     \
        os_mutex_lock(&exec_env->wait_lock);                 \
        signal_flag = exec_env->current_status->signal_flag; \
        os_mutex_unlock(&exec_env->wait_lock);               \
    } while (0)
#endif
#endif

#if WASM_ENABLE_LABELS_AS_VALUES != 0

#define HANDLE_OP(opcode) HANDLE_##opcode:
#define FETCH_OPCODE_AND_DISPATCH() goto *handle_table[*frame_ip++]

#if WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0
#define HANDLE_OP_END()                                                       \
    do {                                                                      \
        /* Record the current frame_ip, so when exception occurs,             \
           debugger can know the exact opcode who caused the exception */     \
        frame_ip_orig = frame_ip;                                             \
        /* Atomic load the exec_env's signal_flag first, and then handle      \
           more with lock if it is WAMR_SIG_SINGSTEP */                       \
        GET_SIGNAL_FLAG();                                                    \
        if (signal_flag == WAMR_SIG_SINGSTEP) {                               \
            os_mutex_lock(&exec_env->wait_lock);                              \
            while (exec_env->current_status->signal_flag == WAMR_SIG_SINGSTEP \
                   && exec_env->current_status->step_count++ == 1) {          \
                exec_env->current_status->step_count = 0;                     \
                SYNC_ALL_TO_FRAME();                                          \
                wasm_cluster_thread_waiting_run(exec_env);                    \
            }                                                                 \
            os_mutex_unlock(&exec_env->wait_lock);                            \
        }                                                                     \
        CHECK_INSTRUCTION_LIMIT();                                            \
        goto *handle_table[*frame_ip++];                                      \
    } while (0)
#else
#define HANDLE_OP_END()        \
    CHECK_INSTRUCTION_LIMIT(); \
    FETCH_OPCODE_AND_DISPATCH()
#endif

#else /* else of WASM_ENABLE_LABELS_AS_VALUES */
#define HANDLE_OP(opcode) case opcode:
#if WASM_ENABLE_THREAD_MGR != 0 && WASM_ENABLE_DEBUG_INTERP != 0
#define HANDLE_OP_END()                                                   \
    /* Record the current frame_ip, so when exception occurs,             \
       debugger can know the exact opcode who caused the exception */     \
    frame_ip_orig = frame_ip;                                             \
    /* Atomic load the exec_env's signal_flag first, and then handle      \
       more with lock if it is WAMR_SIG_SINGSTEP */                       \
    GET_SIGNAL_FLAG();                                                    \
    if (signal_flag == WAMR_SIG_SINGSTEP) {                               \
        os_mutex_lock(&exec_env->wait_lock);                              \
        while (exec_env->current_status->signal_flag == WAMR_SIG_SINGSTEP \
               && exec_env->current_status->step_count++ == 1) {          \
            exec_env->current_status->step_count = 0;                     \
            SYNC_ALL_TO_FRAME();                                          \
            wasm_cluster_thread_waiting_run(exec_env);                    \
        }                                                                 \
        os_mutex_unlock(&exec_env->wait_lock);                            \
    }                                                                     \
    CHECK_INSTRUCTION_LIMIT();                                            \
    continue;
#else
#define HANDLE_OP_END()        \
    CHECK_INSTRUCTION_LIMIT(); \
    continue;
#endif

#endif /* end of WASM_ENABLE_LABELS_AS_VALUES */

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
    WASMFuncType **wasm_types = (WASMFuncType **)module->module->types;
    WASMGlobalInstance *globals = module->e->globals, *global;
    uint8 *global_data = module->global_data;
    uint8 opcode_IMPDEP = WASM_OP_IMPDEP;
    WASMInterpFrame *frame = NULL;
    /* Points to this special opcode so as to jump to the
     * call_method_from_entry.  */
    register uint8 *frame_ip = &opcode_IMPDEP; /* cache of frame->ip */
    register uint32 *frame_lp = NULL;          /* cache of frame->lp */
    register uint32 *frame_sp = NULL;          /* cache of frame->sp */
#if WASM_ENABLE_GC != 0
    register uint8 *frame_ref = NULL; /* cache of frame->ref */
    uint8 *frame_ref_tmp;
#endif
    WASMBranchBlock *frame_csp = NULL;
    BlockAddr *cache_items;
    uint8 *frame_ip_end = frame_ip + 1;
    uint8 opcode;
    uint32 i, depth, cond, count, fidx, tidx, lidx, frame_size = 0;
    uint32 all_cell_num = 0;
    tbl_elem_idx_t val;
    uint8 *else_addr, *end_addr, *maddr = NULL;
    uint32 local_idx, local_offset, global_idx;
    uint8 local_type, *global_addr;
    uint32 cache_index, type_index, param_cell_num, cell_num;

#if WASM_ENABLE_INSTRUCTION_METERING != 0
    int instructions_left = -1;
    if (exec_env) {
        instructions_left = exec_env->instructions_to_execute;
    }
#endif

#if WASM_ENABLE_EXCE_HANDLING != 0
    int32_t exception_tag_index;
#endif
    uint8 value_type;
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
#if WASM_ENABLE_STRINGREF != 0
    WASMString str_obj = NULL;
    WASMStringrefObjectRef stringref_obj;
    WASMStringviewWTF8ObjectRef stringview_wtf8_obj;
    WASMStringviewWTF16ObjectRef stringview_wtf16_obj;
    WASMStringviewIterObjectRef stringview_iter_obj;
#endif
#endif
#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
    bool is_return_call = false;
#endif
#if WASM_ENABLE_MEMORY64 != 0
    /* TODO: multi-memories for now assuming the memory idx type is consistent
     * across multi-memories */
    bool is_memory64 = false;
    bool is_table64 = false;
    if (memory)
        is_memory64 = memory->is_memory64;
#endif
#if WASM_ENABLE_MULTI_MEMORY != 0
    uint32 memidx = 0;
    uint32 memidx_cached = (uint32)-1;
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0
    uint8 *frame_ip_orig = NULL;
    WASMDebugInstance *debug_instance = wasm_exec_env_get_instance(exec_env);
    bh_list *watch_point_list_read =
        debug_instance ? &debug_instance->watch_point_list_read : NULL;
    bh_list *watch_point_list_write =
        debug_instance ? &debug_instance->watch_point_list_write : NULL;
#if WASM_ENABLE_THREAD_MGR != 0
    uint32 signal_flag;
#endif
#endif

#if WASM_ENABLE_LABELS_AS_VALUES != 0
#define HANDLE_OPCODE(op) &&HANDLE_##op
    DEFINE_GOTO_TABLE(const void *, handle_table);
#undef HANDLE_OPCODE
#endif

#if WASM_ENABLE_LABELS_AS_VALUES == 0
    while (frame_ip < frame_ip_end) {
        opcode = *frame_ip++;
        switch (opcode) {
#else
    FETCH_OPCODE_AND_DISPATCH();
#endif
            /* control instructions */
            HANDLE_OP(WASM_OP_UNREACHABLE)
            {
                wasm_set_exception(module, "unreachable");
                goto got_exception;
            }

            HANDLE_OP(WASM_OP_NOP) { HANDLE_OP_END(); }

#if WASM_ENABLE_EXCE_HANDLING != 0
            HANDLE_OP(WASM_OP_RETHROW)
            {
                int32_t relative_depth;
                read_leb_int32(frame_ip, frame_ip_end, relative_depth);

                /* No frame found with exception handler; validation should
                 * catch it */
                bh_assert(frame_csp >= frame->csp_bottom + relative_depth);

                /* go up the frame stack */
                WASMBranchBlock *tgtframe = (frame_csp - 1) - relative_depth;

                bh_assert(tgtframe->label_type == LABEL_TYPE_CATCH
                          || tgtframe->label_type == LABEL_TYPE_CATCH_ALL);

                /* tgtframe points to the frame containing a thrown
                 * exception */

                uint32 *tgtframe_sp = tgtframe->frame_sp;

                /* frame sp of tgtframe points to caught exception */
                exception_tag_index = *((uint32 *)tgtframe_sp);
                tgtframe_sp++;

                /* get tag type */
                uint8 tag_type_index =
                    module->module->tags[exception_tag_index]->type;
                uint32 cell_num_to_copy =
                    wasm_types[tag_type_index]->param_cell_num;

                /* move exception parameters (if there are any) onto top
                 * of stack */
                if (cell_num_to_copy > 0) {
                    word_copy(frame_sp, tgtframe_sp - cell_num_to_copy,
                              cell_num_to_copy);
                }

                frame_sp += cell_num_to_copy;
                goto find_a_catch_handler;
            }

            HANDLE_OP(WASM_OP_THROW)
            {
                read_leb_int32(frame_ip, frame_ip_end, exception_tag_index);

            /* landing pad for the rethrow ? */
            find_a_catch_handler:
            {
                WASMFuncType *tag_type = NULL;
                uint32 cell_num_to_copy = 0;
                if (IS_INVALID_TAGINDEX(exception_tag_index)) {
                    /*
                     * invalid exception index,
                     * generated if a submodule throws an exception
                     * that has not been imported here
                     *
                     * This should result in a branch to the CATCH_ALL block,
                     * if there is one
                     */
                    tag_type = NULL;
                    cell_num_to_copy = 0;
                }
                else {
                    if (module->e->tags[exception_tag_index].is_import_tag) {
                        tag_type = module->e->tags[exception_tag_index]
                                       .u.tag_import->tag_type;
                    }
                    else {
                        tag_type = module->e->tags[exception_tag_index]
                                       .u.tag->tag_type;
                    }
                    cell_num_to_copy = tag_type->param_cell_num;
                }

                /* browse through frame stack */
                uint32 relative_depth = 0;
                do {
                    POP_CSP_CHECK_OVERFLOW(relative_depth - 1);
                    WASMBranchBlock *tgtframe = frame_csp - relative_depth - 1;

                    switch (tgtframe->label_type) {
                        case LABEL_TYPE_BLOCK:
                        case LABEL_TYPE_IF:
                        case LABEL_TYPE_LOOP:
                        case LABEL_TYPE_CATCH:
                        case LABEL_TYPE_CATCH_ALL:
                            /*
                             * skip that blocks in search
                             * BLOCK, IF and LOOP do not contain handlers and
                             * cannot catch exceptions.
                             * blocks marked as CATCH or
                             * CATCH_ALL did already caught an exception and can
                             * only be a target for RETHROW, but cannot catch an
                             * exception again
                             */
                            break;
                        case LABEL_TYPE_TRY:
                        {
                            uint32 handler_number = 0;
                            uint8 **handlers = (uint8 **)tgtframe->frame_sp;
                            uint8 *handler = NULL;
                            while ((handler = handlers[handler_number]) != 0) {
                                uint8 handler_opcode = *handler;
                                uint8 *target_addr =
                                    handler
                                    + 1; /* first instruction or leb-immediate
                                            behind the handler opcode */
                                switch (handler_opcode) {
                                    case WASM_OP_CATCH:
                                    {
                                        int32 lookup_index = 0;
                                        /* read the tag_index and advance
                                         * target_addr to the first instruction
                                         * in the block */
                                        read_leb_int32(target_addr, 0,
                                                       lookup_index);

                                        if (exception_tag_index
                                            == lookup_index) {
                                            /* set ip */
                                            frame_ip = target_addr;
                                            /* save frame_sp (points to
                                             * exception values) */
                                            uint32 *frame_sp_old = frame_sp;

                                            UNWIND_CSP(relative_depth,
                                                       LABEL_TYPE_CATCH);

                                            /* push exception_tag_index and
                                             * exception values for rethrow */
                                            PUSH_I32(exception_tag_index);
                                            if (cell_num_to_copy > 0) {
                                                word_copy(
                                                    frame_sp,
                                                    frame_sp_old
                                                        - cell_num_to_copy,
                                                    cell_num_to_copy);
                                                frame_sp += cell_num_to_copy;
                                                /* push exception values for
                                                 * catch
                                                 */
                                                word_copy(
                                                    frame_sp,
                                                    frame_sp_old
                                                        - cell_num_to_copy,
                                                    cell_num_to_copy);
                                                frame_sp += cell_num_to_copy;
                                            }

                                            /* advance to handler */
                                            HANDLE_OP_END();
                                        }
                                        break;
                                    }
                                    case WASM_OP_DELEGATE:
                                    {
                                        int32 lookup_depth = 0;
                                        /* read the depth */
                                        read_leb_int32(target_addr, 0,
                                                       lookup_depth);

                                        /* save frame_sp (points to exception
                                         * values) */
                                        uint32 *frame_sp_old = frame_sp;

                                        UNWIND_CSP(relative_depth,
                                                   LABEL_TYPE_CATCH);

                                        /* leave the block (the delegate is
                                         * technically not inside the frame) */
                                        frame_csp--;

                                        /* unwind to delegated frame */
                                        frame_csp -= lookup_depth;

                                        /* push exception values for catch */
                                        if (cell_num_to_copy > 0) {
                                            word_copy(frame_sp,
                                                      frame_sp_old
                                                          - cell_num_to_copy,
                                                      cell_num_to_copy);
                                            frame_sp += cell_num_to_copy;
                                        }

                                        /* tag_index is already stored in
                                         * exception_tag_index */
                                        goto find_a_catch_handler;
                                    }
                                    case WASM_OP_CATCH_ALL:
                                    {
                                        /* no immediate */
                                        /* save frame_sp (points to exception
                                         * values) */
                                        uint32 *frame_sp_old = frame_sp;
                                        /* set ip */
                                        frame_ip = target_addr;

                                        UNWIND_CSP(relative_depth,
                                                   LABEL_TYPE_CATCH_ALL);

                                        /* push exception_tag_index and
                                         * exception values for rethrow */
                                        PUSH_I32(exception_tag_index);
                                        if (cell_num_to_copy > 0) {
                                            word_copy(frame_sp,
                                                      frame_sp_old
                                                          - cell_num_to_copy,
                                                      cell_num_to_copy);
                                            frame_sp += cell_num_to_copy;
                                        }
                                        /* catch_all has no exception values */

                                        /* advance to handler */
                                        HANDLE_OP_END();
                                    }
                                    default:
                                        wasm_set_exception(
                                            module, "WASM_OP_THROW found "
                                                    "unexpected handler type");
                                        goto got_exception;
                                }
                                handler_number++;
                            }
                            /* exception not caught in this frame */
                            break;
                        }
                        case LABEL_TYPE_FUNCTION:
                        {
                            /* save frame_sp (points to exception values) */
                            uint32 *frame_sp_old = frame_sp;

                            UNWIND_CSP(relative_depth, LABEL_TYPE_FUNCTION);
                            /* push exception values for catch
                             * The values are copied to the CALLER FRAME
                             * (prev_frame->sp) same behavior ad WASM_OP_RETURN
                             */
                            if (cell_num_to_copy > 0) {
                                word_copy(prev_frame->sp,
                                          frame_sp_old - cell_num_to_copy,
                                          cell_num_to_copy);
                                prev_frame->sp += cell_num_to_copy;
                            }
                            *((int32 *)(prev_frame->sp)) = exception_tag_index;
                            prev_frame->sp++;

                            /* mark frame as raised exception */
                            wasm_set_exception(module,
                                               "uncaught wasm exception");

                            /* end of function, treat as WASM_OP_RETURN */
                            goto return_func;
                        }
                        default:
                            wasm_set_exception(
                                module,
                                "unexpected or invalid label in THROW or "
                                "RETHROW when searching a catch handler");
                            goto got_exception;
                    }

                    relative_depth++;

                } while (1);
            }

                /* something went wrong. normally, we should always find the
                 * func label. if not, stop the interpreter */
                wasm_set_exception(
                    module, "WASM_OP_THROW hit the bottom of the frame stack");
                goto got_exception;
            }

            HANDLE_OP(EXT_OP_TRY)
            {
                /* read the blocktype */
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                param_cell_num = wasm_types[type_index]->param_cell_num;
                cell_num = wasm_types[type_index]->ret_cell_num;
                goto handle_op_try;
            }

            HANDLE_OP(WASM_OP_TRY)
            {
                value_type = *frame_ip++;
                param_cell_num = 0;
                cell_num = wasm_value_type_cell_num(value_type);

            handle_op_try:

                cache_index = ((uintptr_t)frame_ip)
                              & (uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
                cache_items = exec_env->block_addr_cache[cache_index];
                if (cache_items[0].start_addr == frame_ip) {
                    cache_items[0].start_addr = 0;
                }
                if (cache_items[1].start_addr == frame_ip) {
                    cache_items[1].start_addr = 0;
                }

                /* start at the first opcode following the try and its blocktype
                 */
                uint8 *lookup_cursor = frame_ip;
                uint8 handler_opcode = WASM_OP_UNREACHABLE;

                /* target_addr filled in when END or DELEGATE is found */
                PUSH_CSP(LABEL_TYPE_TRY, param_cell_num, cell_num, 0);

                /* reset to begin of block */
                lookup_cursor = frame_ip;
                do {
                    /* lookup the next CATCH, CATCH_ALL or END for this TRY */
                    if (!wasm_loader_find_block_addr(
                            exec_env, (BlockAddr *)exec_env->block_addr_cache,
                            lookup_cursor, (uint8 *)-1, LABEL_TYPE_TRY,
                            &else_addr, &end_addr)) {
                        /* something went wrong */
                        wasm_set_exception(module, "find block address failed");
                        goto got_exception;
                    }

                    /* place cursor for continuation past opcode */
                    lookup_cursor = end_addr + 1;

                    /* end_addr points to CATCH, CATCH_ALL, DELEGATE or END */
                    handler_opcode = *end_addr;
                    switch (handler_opcode) {
                        case WASM_OP_CATCH:
                            skip_leb(lookup_cursor); /* skip tag_index */
                            PUSH_PTR(end_addr);
                            break;
                        case WASM_OP_CATCH_ALL:
                            PUSH_PTR(end_addr);
                            break;
                        case WASM_OP_DELEGATE:
                            skip_leb(lookup_cursor); /* skip depth */
                            PUSH_PTR(end_addr);
                            /* patch target_addr */
                            (frame_csp - 1)->target_addr = lookup_cursor;
                            break;
                        case WASM_OP_END:
                            PUSH_PTR(0);
                            /* patch target_addr */
                            (frame_csp - 1)->target_addr = end_addr;
                            break;
                        default:
                            /* something went wrong */
                            wasm_set_exception(module,
                                               "find block address returned an "
                                               "unexpected opcode");
                            goto got_exception;
                    }
                    /* ... search until the returned address is the END of the
                     * TRY block */
                } while (handler_opcode != WASM_OP_END
                         && handler_opcode != WASM_OP_DELEGATE);
                /* handler setup on stack complete */

                HANDLE_OP_END();
            }
            HANDLE_OP(WASM_OP_CATCH)
            {
                /* skip the tag_index */
                skip_leb(frame_ip);
                /* leave the frame */
                POP_CSP_N(0);
                HANDLE_OP_END();
            }
            HANDLE_OP(WASM_OP_CATCH_ALL)
            {
                /* leave the frame */
                POP_CSP_N(0);
                HANDLE_OP_END();
            }
            HANDLE_OP(WASM_OP_DELEGATE)
            {
                /* skip the delegate depth */
                skip_leb(frame_ip);
                /* leave the frame like WASM_OP_END */
                POP_CSP();
                HANDLE_OP_END();
            }
#endif /* end of WASM_ENABLE_EXCE_HANDLING != 0 */
            HANDLE_OP(EXT_OP_BLOCK)
            {
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                param_cell_num =
                    ((WASMFuncType *)wasm_types[type_index])->param_cell_num;
                cell_num =
                    ((WASMFuncType *)wasm_types[type_index])->ret_cell_num;
                goto handle_op_block;
            }

            HANDLE_OP(WASM_OP_BLOCK)
            {
                value_type = *frame_ip++;
                param_cell_num = 0;
                cell_num = wasm_value_type_cell_num(value_type);
            handle_op_block:
                cache_index = ((uintptr_t)frame_ip)
                              & (uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
                cache_items = exec_env->block_addr_cache[cache_index];
                if (cache_items[0].start_addr == frame_ip) {
                    end_addr = cache_items[0].end_addr;
                }
                else if (cache_items[1].start_addr == frame_ip) {
                    end_addr = cache_items[1].end_addr;
                }
#if WASM_ENABLE_DEBUG_INTERP != 0
                else if (!wasm_loader_find_block_addr(
                             exec_env, (BlockAddr *)exec_env->block_addr_cache,
                             frame_ip, (uint8 *)-1, LABEL_TYPE_BLOCK,
                             &else_addr, &end_addr)) {
                    wasm_set_exception(module, "find block address failed");
                    goto got_exception;
                }
#endif
                else {
                    end_addr = NULL;
                }
                PUSH_CSP(LABEL_TYPE_BLOCK, param_cell_num, cell_num, end_addr);
                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_LOOP)
            {
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                param_cell_num =
                    ((WASMFuncType *)wasm_types[type_index])->param_cell_num;
                cell_num =
                    ((WASMFuncType *)wasm_types[type_index])->param_cell_num;
                goto handle_op_loop;
            }

            HANDLE_OP(WASM_OP_LOOP)
            {
                value_type = *frame_ip++;
                param_cell_num = 0;
                cell_num = 0;
            handle_op_loop:
                PUSH_CSP(LABEL_TYPE_LOOP, param_cell_num, cell_num, frame_ip);
                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_IF)
            {
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                param_cell_num =
                    ((WASMFuncType *)wasm_types[type_index])->param_cell_num;
                cell_num =
                    ((WASMFuncType *)wasm_types[type_index])->ret_cell_num;
                goto handle_op_if;
            }

            HANDLE_OP(WASM_OP_IF)
            {
                value_type = *frame_ip++;
                param_cell_num = 0;
                cell_num = wasm_value_type_cell_num(value_type);
            handle_op_if:
                cache_index = ((uintptr_t)frame_ip)
                              & (uintptr_t)(BLOCK_ADDR_CACHE_SIZE - 1);
                cache_items = exec_env->block_addr_cache[cache_index];
                if (cache_items[0].start_addr == frame_ip) {
                    else_addr = cache_items[0].else_addr;
                    end_addr = cache_items[0].end_addr;
                }
                else if (cache_items[1].start_addr == frame_ip) {
                    else_addr = cache_items[1].else_addr;
                    end_addr = cache_items[1].end_addr;
                }
                else if (!wasm_loader_find_block_addr(
                             exec_env, (BlockAddr *)exec_env->block_addr_cache,
                             frame_ip, (uint8 *)-1, LABEL_TYPE_IF, &else_addr,
                             &end_addr)) {
                    wasm_set_exception(module, "find block address failed");
                    goto got_exception;
                }

                cond = (uint32)POP_I32();

                if (cond) { /* if branch is met */
                    PUSH_CSP(LABEL_TYPE_IF, param_cell_num, cell_num, end_addr);
                }
                else { /* if branch is not met */
                    /* if there is no else branch, go to the end addr */
                    if (else_addr == NULL) {
                        frame_ip = end_addr + 1;
                    }
                    /* if there is an else branch, go to the else addr */
                    else {
                        PUSH_CSP(LABEL_TYPE_IF, param_cell_num, cell_num,
                                 end_addr);
                        frame_ip = else_addr + 1;
                    }
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_ELSE)
            {
                /* comes from the if branch in WASM_OP_IF */
                frame_ip = (frame_csp - 1)->target_addr;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_END)
            {
                if (frame_csp > frame->csp_bottom + 1) {
                    POP_CSP();
                }
                else { /* end of function, treat as WASM_OP_RETURN */
                    frame_sp -= cur_func->ret_cell_num;
                    for (i = 0; i < cur_func->ret_cell_num; i++) {
#if WASM_ENABLE_GC != 0
                        if (prev_frame->ip) {
                            /* prev frame is not a glue frame and has
                               the frame ref area */
                            *FRAME_REF_FOR(prev_frame, prev_frame->sp) =
                                *FRAME_REF(frame_sp + i);
                        }
#endif
                        *prev_frame->sp++ = frame_sp[i];
                    }
                    goto return_func;
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_BR)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                read_leb_uint32(frame_ip, frame_ip_end, depth);
            label_pop_csp_n:
                POP_CSP_N(depth);
                if (!frame_ip) { /* must be label pushed by WASM_OP_BLOCK */
                    if (!wasm_loader_find_block_addr(
                            exec_env, (BlockAddr *)exec_env->block_addr_cache,
                            (frame_csp - 1)->begin_addr, (uint8 *)-1,
                            LABEL_TYPE_BLOCK, &else_addr, &end_addr)) {
                        wasm_set_exception(module, "find block address failed");
                        goto got_exception;
                    }
                    frame_ip = end_addr;
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_BR_IF)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                read_leb_uint32(frame_ip, frame_ip_end, depth);
                cond = (uint32)POP_I32();
                if (cond)
                    goto label_pop_csp_n;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_BR_TABLE)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                read_leb_uint32(frame_ip, frame_ip_end, count);
                lidx = POP_I32();
                if (lidx > count)
                    lidx = count;
                depth = frame_ip[lidx];
                goto label_pop_csp_n;
            }

            HANDLE_OP(EXT_OP_BR_TABLE_CACHE)
            {
                BrTableCache *node_cache =
                    bh_list_first_elem(module->module->br_table_cache_list);
                BrTableCache *node_next;

#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                lidx = POP_I32();

                while (node_cache) {
                    node_next = bh_list_elem_next(node_cache);
                    if (node_cache->br_table_op_addr == frame_ip - 1) {
                        if (lidx > node_cache->br_count)
                            lidx = node_cache->br_count;
                        depth = node_cache->br_depths[lidx];
                        goto label_pop_csp_n;
                    }
                    node_cache = node_next;
                }
                bh_assert(0);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_RETURN)
            {
                frame_sp -= cur_func->ret_cell_num;
                for (i = 0; i < cur_func->ret_cell_num; i++) {
#if WASM_ENABLE_GC != 0
                    if (prev_frame->ip) {
                        /* prev frame is not a glue frame and has
                           the frame ref area */
                        *FRAME_REF_FOR(prev_frame, prev_frame->sp) =
                            *FRAME_REF(frame_sp + i);
                    }
#endif
                    *prev_frame->sp++ = frame_sp[i];
                }
                goto return_func;
            }

            HANDLE_OP(WASM_OP_CALL)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                read_leb_uint32(frame_ip, frame_ip_end, fidx);
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
                read_leb_uint32(frame_ip, frame_ip_end, fidx);
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

            HANDLE_OP(WASM_OP_CALL_INDIRECT)
#if WASM_ENABLE_TAIL_CALL != 0
            HANDLE_OP(WASM_OP_RETURN_CALL_INDIRECT)
#endif
            {
                WASMFuncType *cur_type, *cur_func_type;
                WASMTableInstance *tbl_inst;
                uint32 tbl_idx;

#if WASM_ENABLE_TAIL_CALL != 0
                opcode = *(frame_ip - 1);
#endif
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif

                /**
                 * type check. compiler will make sure all like
                 * (call_indirect (type $x) (it.const 1))
                 * the function type has to be defined in the module also
                 * no matter it is used or not
                 */
                read_leb_uint32(frame_ip, frame_ip_end, tidx);
                bh_assert(tidx < module->module->type_count);
                cur_type = wasm_types[tidx];

                /* clang-format off */
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
                read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
#else
                frame_ip++;
                tbl_idx = 0;
#endif
                bh_assert(tbl_idx < module->table_count);
                /* clang-format on */

                tbl_inst = wasm_get_table_inst(module, tbl_idx);
#if WASM_ENABLE_MEMORY64 != 0
                is_table64 = tbl_inst->is_table64;
#endif

                val = POP_TBL_ELEM_IDX();
                if (val >= tbl_inst->cur_size) {
                    wasm_set_exception(module, "undefined element");
                    goto got_exception;
                }

                /* clang-format off */
#if WASM_ENABLE_GC == 0
                fidx = tbl_inst->elems[val];
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
                 * another module. In that case, we don't validate
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

            /* parametric instructions */
            HANDLE_OP(WASM_OP_DROP)
            {
                frame_sp--;

#if WASM_ENABLE_GC != 0
                frame_ref_tmp = FRAME_REF(frame_sp);
                *frame_ref_tmp = 0;
#endif
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_DROP_64)
            {
                frame_sp -= 2;

#if WASM_ENABLE_GC != 0
                frame_ref_tmp = FRAME_REF(frame_sp);
                *frame_ref_tmp = 0;
                *(frame_ref_tmp + 1) = 0;
#endif

                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SELECT)
            {
                cond = (uint32)POP_I32();
                frame_sp--;
                if (!cond)
                    *(frame_sp - 1) = *frame_sp;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SELECT_64)
            {
                cond = (uint32)POP_I32();
                frame_sp -= 2;
                if (!cond) {
                    *(frame_sp - 2) = *frame_sp;
                    *(frame_sp - 1) = *(frame_sp + 1);
                }
                HANDLE_OP_END();
            }

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            HANDLE_OP(WASM_OP_SELECT_T)
            {
                uint32 vec_len;
                uint8 type;

                read_leb_uint32(frame_ip, frame_ip_end, vec_len);
                type = *frame_ip++;

                cond = (uint32)POP_I32();
                if (type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64
#if WASM_ENABLE_GC != 0 && UINTPTR_MAX == UINT64_MAX
                    || wasm_is_type_reftype(type)
#endif
                ) {
                    frame_sp -= 2;
                    if (!cond) {
                        *(frame_sp - 2) = *frame_sp;
                        *(frame_sp - 1) = *(frame_sp + 1);
                    }
                }
                else {
                    frame_sp--;
                    if (!cond)
                        *(frame_sp - 1) = *frame_sp;
                }

#if WASM_ENABLE_GC != 0
                frame_ref_tmp = FRAME_REF(frame_sp);
                *frame_ref_tmp = 0;
#if UINTPTR_MAX == UINT64_MAX
                *(frame_ref_tmp + 1) = 0;
#endif
#endif
                (void)vec_len;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_TABLE_GET)
            {
                uint32 tbl_idx;
                tbl_elem_idx_t elem_idx;
                WASMTableInstance *tbl_inst;

                read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                bh_assert(tbl_idx < module->table_count);

                tbl_inst = wasm_get_table_inst(module, tbl_idx);
#if WASM_ENABLE_MEMORY64 != 0
                is_table64 = tbl_inst->is_table64;
#endif

                elem_idx = POP_TBL_ELEM_IDX();
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
                WASMTableInstance *tbl_inst;
                uint32 tbl_idx;
                tbl_elem_idx_t elem_idx;
                table_elem_type_t elem_val;

                read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                bh_assert(tbl_idx < module->table_count);

                tbl_inst = wasm_get_table_inst(module, tbl_idx);
#if WASM_ENABLE_MEMORY64 != 0
                is_table64 = tbl_inst->is_table64;
#endif

#if WASM_ENABLE_GC == 0
                elem_val = POP_I32();
#else
                elem_val = POP_REF();
#endif
                elem_idx = POP_TBL_ELEM_IDX();
                if (elem_idx >= tbl_inst->cur_size) {
                    wasm_set_exception(module, "out of bounds table access");
                    goto got_exception;
                }

                tbl_inst->elems[elem_idx] = elem_val;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_REF_NULL)
            {
                uint32 ref_type;
                read_leb_uint32(frame_ip, frame_ip_end, ref_type);
#if WASM_ENABLE_GC == 0
                PUSH_I32(NULL_REF);
#else
                PUSH_REF(NULL_REF);
#endif
                (void)ref_type;
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
                uint32 func_idx;
                read_leb_uint32(frame_ip, frame_ip_end, func_idx);
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
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
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
                read_leb_uint32(frame_ip, frame_ip_end, type_index);
                func_obj = POP_REF();
                if (!func_obj) {
                    wasm_set_exception(module, "null function reference");
                    goto got_exception;
                }

                fidx = wasm_func_obj_get_func_idx_bound(func_obj);
                cur_func = module->e->functions + fidx;
                goto call_func_from_return_call;
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

            HANDLE_OP(WASM_OP_BR_ON_NULL)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                read_leb_uint32(frame_ip, frame_ip_end, depth);
                gc_obj = GET_REF_FROM_ADDR(frame_sp - REF_CELL_NUM);
                if (gc_obj == NULL_REF) {
                    frame_sp -= REF_CELL_NUM;
                    CLEAR_FRAME_REF(frame_sp, REF_CELL_NUM);
                    goto label_pop_csp_n;
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_BR_ON_NON_NULL)
            {
#if WASM_ENABLE_THREAD_MGR != 0
                CHECK_SUSPEND_FLAGS();
#endif
                read_leb_uint32(frame_ip, frame_ip_end, depth);
                gc_obj = GET_REF_FROM_ADDR(frame_sp - REF_CELL_NUM);
                if (gc_obj != NULL_REF) {
                    goto label_pop_csp_n;
                }
                else {
                    frame_sp -= REF_CELL_NUM;
                    CLEAR_FRAME_REF(frame_sp, REF_CELL_NUM);
                }
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_GC_PREFIX)
            {
                uint32 opcode1;

                read_leb_uint32(frame_ip, frame_ip_end, opcode1);
                /* opcode1 was checked in loader and is no larger than
                   UINT8_MAX */
                opcode = (uint8)opcode1;

                switch (opcode) {
                    case WASM_OP_STRUCT_NEW:
                    case WASM_OP_STRUCT_NEW_DEFAULT:
                    {
                        WASMModule *wasm_module = module->module;
                        WASMStructType *struct_type;
                        WASMRttType *rtt_type;
                        WASMValue field_value = { 0 };

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        struct_type =
                            (WASMStructType *)module->module->types[type_index];

                        if (!(rtt_type = wasm_rtt_type_new(
                                  (WASMType *)struct_type, type_index,
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

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        read_leb_uint32(frame_ip, frame_ip_end, field_idx);
                        struct_type =
                            (WASMStructType *)module->module->types[type_index];

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

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        read_leb_uint32(frame_ip, frame_ip_end, field_idx);

                        struct_type =
                            (WASMStructType *)module->module->types[type_index];
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
                        uint32 array_len;

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        array_type =
                            (WASMArrayType *)wasm_module->types[type_index];

                        if (!(rtt_type = wasm_rtt_type_new(
                                  (WASMType *)array_type, type_index,
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
                            read_leb_uint32(frame_ip, frame_ip_end, array_len);

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

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        read_leb_uint32(frame_ip, frame_ip_end, data_seg_idx);
                        data_seg = wasm_module->data_segments[data_seg_idx];

                        array_type =
                            (WASMArrayType *)wasm_module->types[type_index];

                        if (!(rtt_type = wasm_rtt_type_new(
                                  (WASMType *)array_type, type_index,
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

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        array_type =
                            (WASMArrayType *)module->module->types[type_index];

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

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        array_type =
                            (WASMArrayType *)module->module->types[type_index];
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
                        read_leb_uint32(frame_ip, frame_ip_end, type_index);

                        array_type =
                            (WASMArrayType *)module->module->types[type_index];

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

                        read_leb_uint32(frame_ip, frame_ip_end, type_index);
                        read_leb_uint32(frame_ip, frame_ip_end, src_type_index);

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

                        read_leb_int32(frame_ip, frame_ip_end, heap_type);

                        gc_obj = GET_REF_FROM_ADDR(frame_sp - REF_CELL_NUM);
                        if (!gc_obj) {
                            if (opcode == WASM_OP_REF_TEST
                                || opcode == WASM_OP_REF_TEST_NULLABLE) {
                                (void)POP_REF();
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
                                /* Do nothing for WASM_OP_REF_CAST_NULLABLE */
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
                                (void)POP_REF();
                                if (castable)
                                    PUSH_I32(1);
                                else
                                    PUSH_I32(0);
                            }
                            else if (!castable) {
                                wasm_set_exception(module, "cast failure");
                                goto got_exception;
                            }
                        }
                        HANDLE_OP_END();
                    }

                    case WASM_OP_BR_ON_CAST:
                    case WASM_OP_BR_ON_CAST_FAIL:
                    {
                        int32 heap_type, heap_type_dst;
                        uint8 castflags;

#if WASM_ENABLE_THREAD_MGR != 0
                        CHECK_SUSPEND_FLAGS();
#endif
                        castflags = *frame_ip++;
                        read_leb_uint32(frame_ip, frame_ip_end, depth);
                        read_leb_int32(frame_ip, frame_ip_end, heap_type);
                        read_leb_int32(frame_ip, frame_ip_end, heap_type_dst);

                        gc_obj = GET_REF_FROM_ADDR(frame_sp - REF_CELL_NUM);
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
                                ((opcode1 == WASM_OP_BR_ON_CAST)
                                 && ((castflags == 2) || (castflags == 3)))
                                /* op is BR_ON_CAST_FAIL and dst reftype is
                                   non-nullable */
                                || ((opcode1 == WASM_OP_BR_ON_CAST_FAIL)
                                    && ((castflags == 0) || (castflags == 1))))
                                goto label_pop_csp_n;
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
                                goto label_pop_csp_n;
                            }
                        }

                        (void)heap_type;
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

                        read_leb_uint32(frame_ip, frame_ip_end, mem_idx);
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

                        read_leb_uint32(frame_ip, frame_ip_end, contents);

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
                        if (!stringref_obj) {
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

                        read_leb_uint32(frame_ip, frame_ip_end, mem_idx);
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

                        read_leb_uint32(frame_ip, frame_ip_end, mem_idx);
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

                        read_leb_uint32(frame_ip, frame_ip_end, mem_idx);
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
                        if (written_code_units < 0) {
                            wasm_set_exception(module, "encode failed");
                            goto got_exception;
                        }

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
                        uint32 start, array_len;
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
            HANDLE_OP(WASM_OP_GET_LOCAL)
            {
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();

                switch (local_type) {
                    case VALUE_TYPE_I32:
                    case VALUE_TYPE_F32:
#if WASM_ENABLE_REF_TYPES != 0 && WASM_ENABLE_GC == 0
                    case VALUE_TYPE_FUNCREF:
                    case VALUE_TYPE_EXTERNREF:
#endif
                        PUSH_I32(*(int32 *)(frame_lp + local_offset));
                        break;
                    case VALUE_TYPE_I64:
                    case VALUE_TYPE_F64:
                        PUSH_I64(GET_I64_FROM_ADDR(frame_lp + local_offset));
                        break;
                    default:
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_reftype(local_type)) {
                            if (wasm_is_reftype_i31ref(local_type)) {
                                PUSH_I31REF(
                                    GET_REF_FROM_ADDR(frame_lp + local_offset));
                            }
                            else {
                                PUSH_REF(
                                    GET_REF_FROM_ADDR(frame_lp + local_offset));
                            }
                        }
                        else
#endif
                        {
                            wasm_set_exception(module, "invalid local type");
                            goto got_exception;
                        }
                }

                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_GET_LOCAL_FAST)
            {
                local_offset = *frame_ip++;
                if (local_offset & 0x80)
                    PUSH_I64(
                        GET_I64_FROM_ADDR(frame_lp + (local_offset & 0x7F)));
                else
                    PUSH_I32(*(int32 *)(frame_lp + local_offset));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SET_LOCAL)
            {
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();

                switch (local_type) {
                    case VALUE_TYPE_I32:
                    case VALUE_TYPE_F32:
#if WASM_ENABLE_REF_TYPES != 0 && WASM_ENABLE_GC == 0
                    case VALUE_TYPE_FUNCREF:
                    case VALUE_TYPE_EXTERNREF:
#endif
                        *(int32 *)(frame_lp + local_offset) = POP_I32();
                        break;
                    case VALUE_TYPE_I64:
                    case VALUE_TYPE_F64:
                        PUT_I64_TO_ADDR((uint32 *)(frame_lp + local_offset),
                                        POP_I64());
                        break;
                    default:
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_reftype(local_type)) {
                            PUT_REF_TO_ADDR(frame_lp + local_offset, POP_REF());
                        }
                        else
#endif
                        {
                            wasm_set_exception(module, "invalid local type");
                            goto got_exception;
                        }
                }

                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_SET_LOCAL_FAST)
            {
                local_offset = *frame_ip++;
                if (local_offset & 0x80)
                    PUT_I64_TO_ADDR(
                        (uint32 *)(frame_lp + (local_offset & 0x7F)),
                        POP_I64());
                else
                    *(int32 *)(frame_lp + local_offset) = POP_I32();
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_TEE_LOCAL)
            {
                GET_LOCAL_INDEX_TYPE_AND_OFFSET();

                switch (local_type) {
                    case VALUE_TYPE_I32:
                    case VALUE_TYPE_F32:
#if WASM_ENABLE_REF_TYPES != 0 && WASM_ENABLE_GC == 0
                    case VALUE_TYPE_FUNCREF:
                    case VALUE_TYPE_EXTERNREF:
#endif
                        *(int32 *)(frame_lp + local_offset) =
                            *(int32 *)(frame_sp - 1);
                        break;
                    case VALUE_TYPE_I64:
                    case VALUE_TYPE_F64:
                        PUT_I64_TO_ADDR((uint32 *)(frame_lp + local_offset),
                                        GET_I64_FROM_ADDR(frame_sp - 2));
                        break;
                    default:
#if WASM_ENABLE_GC != 0
                        if (wasm_is_type_reftype(local_type)) {
                            PUT_REF_TO_ADDR(
                                frame_lp + local_offset,
                                GET_REF_FROM_ADDR(frame_sp - REF_CELL_NUM));
                        }
                        else
#endif
                        {
                            wasm_set_exception(module, "invalid local type");
                            goto got_exception;
                        }
                }

                HANDLE_OP_END();
            }

            HANDLE_OP(EXT_OP_TEE_LOCAL_FAST)
            {
                local_offset = *frame_ip++;
                if (local_offset & 0x80)
                    PUT_I64_TO_ADDR(
                        (uint32 *)(frame_lp + (local_offset & 0x7F)),
                        GET_I64_FROM_ADDR(frame_sp - 2));
                else
                    *(int32 *)(frame_lp + local_offset) =
                        *(int32 *)(frame_sp - 1);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_GET_GLOBAL)
            {
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                /* clang-format off */
#if WASM_ENABLE_GC == 0
                PUSH_I32(*(uint32 *)global_addr);
#else
                if (!wasm_is_type_reftype(global->type)) {
                    PUSH_I32(*(uint32 *)global_addr);
                }
                else if (wasm_is_reftype_i31ref(global->type)) {
                    PUSH_I31REF(GET_REF_FROM_ADDR((uint32 *)global_addr));
                }
                else {
                    PUSH_REF(GET_REF_FROM_ADDR((uint32 *)global_addr));
                }
#endif
                /* clang-format on */
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_GET_GLOBAL_64)
            {
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                PUSH_I64(GET_I64_FROM_ADDR((uint32 *)global_addr));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SET_GLOBAL)
            {
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                /* clang-format off */
#if WASM_ENABLE_GC == 0
                *(int32 *)global_addr = POP_I32();
#else
                if (!wasm_is_type_reftype(global->type))
                    *(int32 *)global_addr = POP_I32();
                else
                    PUT_REF_TO_ADDR((uint32 *)global_addr, POP_REF());
#endif
                /* clang-format on */
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_SET_GLOBAL_AUX_STACK)
            {
                uint64 aux_stack_top;

                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
#if WASM_ENABLE_MEMORY64 != 0
                if (is_memory64) {
                    aux_stack_top = *(uint64 *)(frame_sp - 2);
                }
                else
#endif
                {
                    aux_stack_top = (uint64)(*(uint32 *)(frame_sp - 1));
                }
                if (aux_stack_top <= (uint64)exec_env->aux_stack_boundary) {
                    wasm_set_exception(module, "wasm auxiliary stack overflow");
                    goto got_exception;
                }
                if (aux_stack_top > (uint64)exec_env->aux_stack_bottom) {
                    wasm_set_exception(module,
                                       "wasm auxiliary stack underflow");
                    goto got_exception;
                }
#if WASM_ENABLE_MEMORY64 != 0
                if (is_memory64) {
                    *(uint64 *)global_addr = aux_stack_top;
                    frame_sp -= 2;
                }
                else
#endif
                {
                    *(uint32 *)global_addr = (uint32)aux_stack_top;
                    frame_sp--;
                }
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
                read_leb_uint32(frame_ip, frame_ip_end, global_idx);
                bh_assert(global_idx < module->e->global_count);
                global = globals + global_idx;
                global_addr = get_global_addr(global_data, global);
                PUT_I64_TO_ADDR((uint32 *)global_addr, POP_I64());
                HANDLE_OP_END();
            }

            /* memory load instructions */
            HANDLE_OP(WASM_OP_I32_LOAD)
            HANDLE_OP(WASM_OP_F32_LOAD)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                PUSH_I32(LOAD_I32(maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD)
            HANDLE_OP(WASM_OP_F64_LOAD)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(8);
                PUSH_I64(LOAD_I64(maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD8_S)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I32(sign_ext_8_32(*(int8 *)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD8_U)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I32((uint32)(*(uint8 *)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD16_S)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I32(sign_ext_16_32(LOAD_I16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_LOAD16_U)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I32((uint32)(LOAD_U16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD8_S)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I64(sign_ext_8_64(*(int8 *)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD8_U)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(1);
                PUSH_I64((uint64)(*(uint8 *)maddr));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD16_S)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I64(sign_ext_16_64(LOAD_I16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD16_U)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(2);
                PUSH_I64((uint64)(LOAD_U16(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD32_S)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                PUSH_I64(sign_ext_32_64(LOAD_I32(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_LOAD32_U)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
                PUSH_I64((uint64)(LOAD_U32(maddr)));
                CHECK_READ_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            /* memory store instructions */
            HANDLE_OP(WASM_OP_I32_STORE)
            HANDLE_OP(WASM_OP_F32_STORE)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                frame_sp--;
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(4);
#if WASM_ENABLE_MEMORY64 != 0
                if (is_memory64) {
                    STORE_U32(maddr, frame_sp[2]);
                }
                else
#endif
                {
                    STORE_U32(maddr, frame_sp[1]);
                }
                CHECK_WRITE_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_STORE)
            HANDLE_OP(WASM_OP_F64_STORE)
            {
                uint32 flags;
                mem_offset_t offset, addr;

                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                frame_sp -= 2;
                addr = POP_MEM_OFFSET();
                CHECK_MEMORY_OVERFLOW(8);

#if WASM_ENABLE_MEMORY64 != 0
                if (is_memory64) {
                    PUT_I64_TO_ADDR((mem_offset_t *)maddr,
                                    GET_I64_FROM_ADDR(frame_sp + 2));
                }
                else
#endif
                {
                    PUT_I64_TO_ADDR((uint32 *)maddr,
                                    GET_I64_FROM_ADDR(frame_sp + 1));
                }
                CHECK_WRITE_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_STORE8)
            HANDLE_OP(WASM_OP_I32_STORE16)
            {
                uint32 flags;
                mem_offset_t offset, addr;
                uint32 sval;

                opcode = *(frame_ip - 1);
                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                sval = (uint32)POP_I32();
                addr = POP_MEM_OFFSET();

                if (opcode == WASM_OP_I32_STORE8) {
                    CHECK_MEMORY_OVERFLOW(1);
                    *(uint8 *)maddr = (uint8)sval;
                }
                else {
                    CHECK_MEMORY_OVERFLOW(2);
                    STORE_U16(maddr, (uint16)sval);
                }
                CHECK_WRITE_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_STORE8)
            HANDLE_OP(WASM_OP_I64_STORE16)
            HANDLE_OP(WASM_OP_I64_STORE32)
            {
                uint32 flags;
                mem_offset_t offset, addr;
                uint64 sval;

                opcode = *(frame_ip - 1);
                read_leb_memarg(frame_ip, frame_ip_end, flags);
                read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                sval = (uint64)POP_I64();
                addr = POP_MEM_OFFSET();

                if (opcode == WASM_OP_I64_STORE8) {
                    CHECK_MEMORY_OVERFLOW(1);
                    *(uint8 *)maddr = (uint8)sval;
                }
                else if (opcode == WASM_OP_I64_STORE16) {
                    CHECK_MEMORY_OVERFLOW(2);
                    STORE_U16(maddr, (uint16)sval);
                }
                else {
                    CHECK_MEMORY_OVERFLOW(4);
                    STORE_U32(maddr, (uint32)sval);
                }
                CHECK_WRITE_WATCHPOINT(addr, offset);
                HANDLE_OP_END();
            }

            /* memory size and memory grow instructions */
            HANDLE_OP(WASM_OP_MEMORY_SIZE)
            {
                uint32 mem_idx;
                read_leb_memidx(frame_ip, frame_ip_end, mem_idx);
                PUSH_PAGE_COUNT(memory->cur_page_count);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_MEMORY_GROW)
            {
                uint32 mem_idx, prev_page_count;
                mem_offset_t delta;

                read_leb_memidx(frame_ip, frame_ip_end, mem_idx);
                prev_page_count = memory->cur_page_count;
                delta = POP_PAGE_COUNT();

                if (
#if WASM_ENABLE_MEMORY64 != 0
                    delta > UINT32_MAX ||
#endif
                    !wasm_enlarge_memory_with_idx(module, (uint32)delta,
                                                  mem_idx)) {
                    /* failed to memory.grow, return -1 */
                    PUSH_PAGE_COUNT(-1);
                }
                else {
                    /* success, return previous page count */
                    PUSH_PAGE_COUNT(prev_page_count);
                    /* update memory size, no need to update memory ptr as
                       it isn't changed in wasm_enlarge_memory */
#if !defined(OS_ENABLE_HW_BOUND_CHECK)              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0
                    linear_mem_size = GET_LINEAR_MEMORY_SIZE(memory);
#endif
                }

                HANDLE_OP_END();
            }

            /* constant instructions */
            HANDLE_OP(WASM_OP_I32_CONST)
            DEF_OP_I_CONST(int32, I32);
            HANDLE_OP_END();

            HANDLE_OP(WASM_OP_I64_CONST)
            DEF_OP_I_CONST(int64, I64);
            HANDLE_OP_END();

            HANDLE_OP(WASM_OP_F32_CONST)
            {
                uint8 *p_float = (uint8 *)frame_sp++;
                for (i = 0; i < sizeof(float32); i++)
                    *p_float++ = *frame_ip++;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F64_CONST)
            {
                uint8 *p_float = (uint8 *)frame_sp++;
                frame_sp++;
                for (i = 0; i < sizeof(float64); i++)
                    *p_float++ = *frame_ip++;
                HANDLE_OP_END();
            }

            /* comparison instructions of i32 */
            HANDLE_OP(WASM_OP_I32_EQZ)
            {
                DEF_OP_EQZ(I32);
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
                DEF_OP_EQZ(I64);
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

                b = POP_I32();
                a = POP_I32();
                if (a == (int32)0x80000000 && b == -1) {
                    wasm_set_exception(module, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_DIV_U)
            {
                uint32 a, b;

                b = (uint32)POP_I32();
                a = (uint32)POP_I32();
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_REM_S)
            {
                int32 a, b;

                b = POP_I32();
                a = POP_I32();
                if (a == (int32)0x80000000 && b == -1) {
                    PUSH_I32(0);
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_REM_U)
            {
                uint32 a, b;

                b = (uint32)POP_I32();
                a = (uint32)POP_I32();
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I32(a % b);
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

                b = (uint32)POP_I32();
                a = (uint32)POP_I32();
                PUSH_I32(rotl32(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_ROTR)
            {
                uint32 a, b;

                b = (uint32)POP_I32();
                a = (uint32)POP_I32();
                PUSH_I32(rotr32(a, b));
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

                b = POP_I64();
                a = POP_I64();
                if (a == (int64)0x8000000000000000LL && b == -1) {
                    wasm_set_exception(module, "integer overflow");
                    goto got_exception;
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_DIV_U)
            {
                uint64 a, b;

                b = (uint64)POP_I64();
                a = (uint64)POP_I64();
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a / b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_REM_S)
            {
                int64 a, b;

                b = POP_I64();
                a = POP_I64();
                if (a == (int64)0x8000000000000000LL && b == -1) {
                    PUSH_I64(0);
                    HANDLE_OP_END();
                }
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a % b);
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_REM_U)
            {
                uint64 a, b;

                b = (uint64)POP_I64();
                a = (uint64)POP_I64();
                if (b == 0) {
                    wasm_set_exception(module, "integer divide by zero");
                    goto got_exception;
                }
                PUSH_I64(a % b);
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

                b = (uint64)POP_I64();
                a = (uint64)POP_I64();
                PUSH_I64(rotl64(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_ROTR)
            {
                uint64 a, b;

                b = (uint64)POP_I64();
                a = (uint64)POP_I64();
                PUSH_I64(rotr64(a, b));
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
                uint32 u32 = frame_sp[-1];
                uint32 sign_bit = u32 & ((uint32)1 << 31);
                if (sign_bit)
                    frame_sp[-1] = u32 & ~((uint32)1 << 31);
                else
                    frame_sp[-1] = u32 | ((uint32)1 << 31);
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

                b = POP_F32();
                a = POP_F32();

                PUSH_F32(f32_min(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_MAX)
            {
                float32 a, b;

                b = POP_F32();
                a = POP_F32();

                PUSH_F32(f32_max(a, b));
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_F32_COPYSIGN)
            {
                float32 a, b;

                b = POP_F32();
                a = POP_F32();
                PUSH_F32(local_copysignf(a, b));
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
                uint64 u64 = GET_I64_FROM_ADDR(frame_sp - 2);
                uint64 sign_bit = u64 & (((uint64)1) << 63);
                if (sign_bit)
                    PUT_I64_TO_ADDR(frame_sp - 2, (u64 & ~(((uint64)1) << 63)));
                else
                    PUT_I64_TO_ADDR(frame_sp - 2, (u64 | (((uint64)1) << 63)));
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
                   represent all int32/uint32/int64/uint64 values, e.g.
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
                /* frame_sp can't be moved in trunc function, we need to
                  manually adjust it if src and dst op's cell num is
                  different */
                frame_sp--;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I32_TRUNC_U_F64)
            {
                DEF_OP_TRUNC_F64(-1.0, 4294967296.0, true, false);
                frame_sp--;
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
                frame_sp++;
                HANDLE_OP_END();
            }

            HANDLE_OP(WASM_OP_I64_TRUNC_U_F32)
            {
                DEF_OP_TRUNC_F32(-1.0f, 18446744073709551616.0f, false, false);
                frame_sp++;
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
            HANDLE_OP(WASM_OP_I64_REINTERPRET_F64)
            HANDLE_OP(WASM_OP_F32_REINTERPRET_I32)
            HANDLE_OP(WASM_OP_F64_REINTERPRET_I64) { HANDLE_OP_END(); }

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
                uint32 opcode1;

                read_leb_uint32(frame_ip, frame_ip_end, opcode1);
                /* opcode1 was checked in loader and is no larger than
                   UINT8_MAX */
                opcode = (uint8)opcode1;

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
                        frame_sp--;
                        break;
                    case WASM_OP_I32_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0, 4294967296.0, true, false);
                        frame_sp--;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F32:
                        DEF_OP_TRUNC_SAT_F32(-9223373136366403584.0f,
                                             9223372036854775808.0f, false,
                                             true);
                        frame_sp++;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F32:
                        DEF_OP_TRUNC_SAT_F32(-1.0f, 18446744073709551616.0f,
                                             false, false);
                        frame_sp++;
                        break;
                    case WASM_OP_I64_TRUNC_SAT_S_F64:
                        DEF_OP_TRUNC_SAT_F64(-9223372036854777856.0,
                                             9223372036854775808.0, false,
                                             true);
                        break;
                    case WASM_OP_I64_TRUNC_SAT_U_F64:
                        DEF_OP_TRUNC_SAT_F64(-1.0f, 18446744073709551616.0,
                                             false, false);
                        break;
#if WASM_ENABLE_BULK_MEMORY != 0
                    case WASM_OP_MEMORY_INIT:
                    {
                        uint32 segment;
                        mem_offset_t addr;
                        uint64 bytes, offset, seg_len;
                        uint8 *data;

                        read_leb_uint32(frame_ip, frame_ip_end, segment);
#if WASM_ENABLE_MULTI_MEMORY != 0
                        read_leb_memidx(frame_ip, frame_ip_end, memidx);
#else
                        /* skip memory index */
                        frame_ip++;
#endif

                        bytes = (uint64)(uint32)POP_I32();
                        offset = (uint64)(uint32)POP_I32();
                        addr = (mem_offset_t)POP_MEM_OFFSET();

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

                        read_leb_uint32(frame_ip, frame_ip_end, segment);
                        bh_bitmap_set_bit(module->e->common.data_dropped,
                                          segment);
                        break;
                    }
                    case WASM_OP_MEMORY_COPY:
                    {
                        mem_offset_t dst, src, len;
                        uint8 *mdst, *msrc;

                        len = POP_MEM_OFFSET();
                        src = POP_MEM_OFFSET();
                        dst = POP_MEM_OFFSET();

#if WASM_ENABLE_MULTI_MEMORY != 0
                        /* dst memidx */
                        read_leb_memidx(frame_ip, frame_ip_end, memidx);
#else
                        /* skip dst memidx */
                        frame_ip += 1;
#endif
                        // TODO: apply memidx
#if WASM_ENABLE_THREAD_MGR != 0
                        linear_mem_size = get_linear_mem_size();
#endif
                        /* dst boundary check */
#ifndef OS_ENABLE_HW_BOUND_CHECK
                        CHECK_BULK_MEMORY_OVERFLOW(dst, len, mdst);
#else /* else of OS_ENABLE_HW_BOUND_CHECK */
#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)dst, len)) {
                            shared_heap_addr_app_to_native((uint64)dst, mdst);
                        }
                        else
#endif
                        {
                            if ((uint64)dst + len > linear_mem_size)
                                goto out_of_bounds;
                            mdst = memory->memory_data + dst;
                        }
#endif /* end of OS_ENABLE_HW_BOUND_CHECK */

#if WASM_ENABLE_MULTI_MEMORY != 0
                        /* src memidx */
                        read_leb_memidx(frame_ip, frame_ip_end, memidx);
#else
                        /* skip src memidx */
                        frame_ip += 1;
#endif
                        // TODO: apply memidx
#if WASM_ENABLE_THREAD_MGR != 0
                        linear_mem_size = get_linear_mem_size();
#endif
                        /* src boundary check */
#ifndef OS_ENABLE_HW_BOUND_CHECK
                        CHECK_BULK_MEMORY_OVERFLOW(src, len, msrc);
#else
#if WASM_ENABLE_SHARED_HEAP != 0
                        if (app_addr_in_shared_heap((uint64)src, len))
                            shared_heap_addr_app_to_native((uint64)src, msrc);
                        else
#endif
                        {
                            if ((uint64)src + len > linear_mem_size)
                                goto out_of_bounds;
                            msrc = memory->memory_data + src;
                        }
#endif

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
                        mem_offset_t dst, len;
                        uint8 fill_val, *mdst;

#if WASM_ENABLE_MULTI_MEMORY != 0
                        read_leb_memidx(frame_ip, frame_ip_end, memidx);
#else
                        /* skip memory index */
                        frame_ip++;
#endif

                        len = POP_MEM_OFFSET();
                        fill_val = POP_I32();
                        dst = POP_MEM_OFFSET();

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
                        uint32 tbl_idx;
                        tbl_elem_idx_t elem_idx, d;
                        uint32 n, s;
                        WASMTableInstance *tbl_inst;
                        table_elem_type_t *table_elems;
                        InitializerExpression *tbl_seg_init_values = NULL,
                                              *init_values;
                        uint32 tbl_seg_len = 0;

                        read_leb_uint32(frame_ip, frame_ip_end, elem_idx);
                        bh_assert(elem_idx < module->module->table_seg_count);

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                        bh_assert(tbl_idx < module->module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);
#if WASM_ENABLE_MEMORY64 != 0
                        is_table64 = tbl_inst->is_table64;
#endif

                        n = (uint32)POP_I32();
                        s = (uint32)POP_I32();
                        d = (tbl_elem_idx_t)POP_TBL_ELEM_IDX();

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

                        /* TODO: memory64 current implementation of table64
                         * still assumes the max table size UINT32_MAX
                         */
                        if (
#if WASM_ENABLE_MEMORY64 != 0
                            d > UINT32_MAX ||
#endif
                            offset_len_out_of_bounds(s, n, tbl_seg_len)
                            || offset_len_out_of_bounds((uint32)d, n,
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
                        uint32 elem_idx;
                        read_leb_uint32(frame_ip, frame_ip_end, elem_idx);
                        bh_assert(elem_idx < module->module->table_seg_count);

                        bh_bitmap_set_bit(module->e->common.elem_dropped,
                                          elem_idx);
                        break;
                    }
                    case WASM_OP_TABLE_COPY:
                    {
                        uint32 src_tbl_idx, dst_tbl_idx;
                        tbl_elem_idx_t n, s, d;
                        WASMTableInstance *src_tbl_inst, *dst_tbl_inst;

                        read_leb_uint32(frame_ip, frame_ip_end, dst_tbl_idx);
                        bh_assert(dst_tbl_idx < module->table_count);

                        dst_tbl_inst = wasm_get_table_inst(module, dst_tbl_idx);

                        read_leb_uint32(frame_ip, frame_ip_end, src_tbl_idx);
                        bh_assert(src_tbl_idx < module->table_count);

                        src_tbl_inst = wasm_get_table_inst(module, src_tbl_idx);

#if WASM_ENABLE_MEMORY64 != 0
                        is_table64 = src_tbl_inst->is_table64
                                     && dst_tbl_inst->is_table64;
#endif
                        n = (tbl_elem_idx_t)POP_TBL_ELEM_IDX();
#if WASM_ENABLE_MEMORY64 != 0
                        is_table64 = src_tbl_inst->is_table64;
#endif
                        s = (tbl_elem_idx_t)POP_TBL_ELEM_IDX();
#if WASM_ENABLE_MEMORY64 != 0
                        is_table64 = dst_tbl_inst->is_table64;
#endif
                        d = (tbl_elem_idx_t)POP_TBL_ELEM_IDX();

                        if (
#if WASM_ENABLE_MEMORY64 != 0
                            n > UINT32_MAX || s > UINT32_MAX || d > UINT32_MAX
                            ||
#endif
                            offset_len_out_of_bounds((uint32)d, (uint32)n,
                                                     dst_tbl_inst->cur_size)
                            || offset_len_out_of_bounds(
                                (uint32)s, (uint32)n, src_tbl_inst->cur_size)) {
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
                        WASMTableInstance *tbl_inst;
                        uint32 tbl_idx, orig_tbl_sz;
                        tbl_elem_idx_t n;
                        table_elem_type_t init_val;

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                        bh_assert(tbl_idx < module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);
#if WASM_ENABLE_MEMORY64 != 0
                        is_table64 = tbl_inst->is_table64;
#endif

                        orig_tbl_sz = tbl_inst->cur_size;

                        n = POP_TBL_ELEM_IDX();
#if WASM_ENABLE_GC == 0
                        init_val = POP_I32();
#else
                        init_val = POP_REF();
#endif

                        if (
#if WASM_ENABLE_MEMORY64 != 0
                            n > UINT32_MAX ||
#endif
                            !wasm_enlarge_table(module, tbl_idx, (uint32)n,
                                                init_val)) {
                            PUSH_TBL_ELEM_IDX(-1);
                        }
                        else {
                            PUSH_TBL_ELEM_IDX(orig_tbl_sz);
                        }
                        break;
                    }
                    case WASM_OP_TABLE_SIZE:
                    {
                        uint32 tbl_idx;
                        WASMTableInstance *tbl_inst;

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                        bh_assert(tbl_idx < module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);
#if WASM_ENABLE_MEMORY64 != 0
                        is_table64 = tbl_inst->is_table64;
#endif

                        PUSH_TBL_ELEM_IDX(tbl_inst->cur_size);
                        break;
                    }
                    case WASM_OP_TABLE_FILL:
                    {
                        uint32 tbl_idx;
                        tbl_elem_idx_t n, elem_idx;
                        WASMTableInstance *tbl_inst;
                        table_elem_type_t fill_val;

                        read_leb_uint32(frame_ip, frame_ip_end, tbl_idx);
                        bh_assert(tbl_idx < module->table_count);

                        tbl_inst = wasm_get_table_inst(module, tbl_idx);
#if WASM_ENABLE_MEMORY64 != 0
                        is_table64 = tbl_inst->is_table64;
#endif

                        n = POP_TBL_ELEM_IDX();
#if WASM_ENABLE_GC == 0
                        fill_val = POP_I32();
#else
                        fill_val = POP_REF();
#endif
                        elem_idx = POP_TBL_ELEM_IDX();

                        if (
#if WASM_ENABLE_MEMORY64 != 0
                            n > UINT32_MAX || elem_idx > UINT32_MAX ||
#endif
                            offset_len_out_of_bounds((uint32)elem_idx,
                                                     (uint32)n,
                                                     tbl_inst->cur_size)) {
                            wasm_set_exception(module,
                                               "out of bounds table access");
                            goto got_exception;
                        }

                        for (; n != 0; elem_idx++, n--) {
                            tbl_inst->elems[elem_idx] = fill_val;
                        }
                        break;
                    }
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */
                    default:
                        wasm_set_exception(module, "unsupported opcode");
                        goto got_exception;
                }
                HANDLE_OP_END();
            }

#if WASM_ENABLE_SHARED_MEMORY != 0
            HANDLE_OP(WASM_OP_ATOMIC_PREFIX)
            {
                mem_offset_t offset = 0, addr;
                uint32 align = 0;
                uint32 opcode1;

                read_leb_uint32(frame_ip, frame_ip_end, opcode1);
                /* opcode1 was checked in loader and is no larger than
                   UINT8_MAX */
                opcode = (uint8)opcode1;

                if (opcode != WASM_OP_ATOMIC_FENCE) {
                    read_leb_uint32(frame_ip, frame_ip_end, align);
                    read_leb_mem_offset(frame_ip, frame_ip_end, offset);
                }

                switch (opcode) {
                    case WASM_OP_ATOMIC_NOTIFY:
                    {
                        uint32 notify_count, ret;

                        notify_count = POP_I32();
                        addr = POP_MEM_OFFSET();
                        CHECK_MEMORY_OVERFLOW(4);
                        CHECK_ATOMIC_MEMORY_ACCESS();

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
                        addr = POP_MEM_OFFSET();
                        CHECK_MEMORY_OVERFLOW(4);
                        CHECK_ATOMIC_MEMORY_ACCESS();

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
                        addr = POP_MEM_OFFSET();
                        CHECK_MEMORY_OVERFLOW(8);
                        CHECK_ATOMIC_MEMORY_ACCESS();

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
                        /* Skip the memory index */
                        frame_ip++;
                        os_atomic_thread_fence(os_memory_order_seq_cst);
                        break;
                    }

                    case WASM_OP_ATOMIC_I32_LOAD:
                    case WASM_OP_ATOMIC_I32_LOAD8_U:
                    case WASM_OP_ATOMIC_I32_LOAD16_U:
                    {
                        uint32 readv;

                        addr = POP_MEM_OFFSET();

                        if (opcode == WASM_OP_ATOMIC_I32_LOAD8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            readv = (uint32)(*(uint8 *)maddr);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_LOAD16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            readv = (uint32)LOAD_U16(maddr);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS();
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

                        addr = POP_MEM_OFFSET();

                        if (opcode == WASM_OP_ATOMIC_I64_LOAD8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            readv = (uint64)(*(uint8 *)maddr);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U16(maddr);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_LOAD32_U) {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U32(maddr);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(8);
                            CHECK_ATOMIC_MEMORY_ACCESS();
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
                        addr = POP_MEM_OFFSET();

                        if (opcode == WASM_OP_ATOMIC_I32_STORE8) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            *(uint8 *)maddr = (uint8)sval;
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I32_STORE16) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            STORE_U16(maddr, (uint16)sval);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS();
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
                        addr = POP_MEM_OFFSET();

                        if (opcode == WASM_OP_ATOMIC_I64_STORE8) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            *(uint8 *)maddr = (uint8)sval;
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE16) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            STORE_U16(maddr, (uint16)sval);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_I64_STORE32) {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS();
                            shared_memory_lock(memory);
                            STORE_U32(maddr, (uint32)sval);
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(8);
                            CHECK_ATOMIC_MEMORY_ACCESS();
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
                        addr = POP_MEM_OFFSET();

                        if (opcode == WASM_OP_ATOMIC_RMW_I32_CMPXCHG8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = (uint8)expect;
                            shared_memory_lock(memory);
                            readv = (uint32)(*(uint8 *)maddr);
                            if (readv == expect)
                                *(uint8 *)maddr = (uint8)(sval);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I32_CMPXCHG16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = (uint16)expect;
                            shared_memory_lock(memory);
                            readv = (uint32)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS();

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
                        addr = POP_MEM_OFFSET();

                        if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG8_U) {
                            CHECK_MEMORY_OVERFLOW(1);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = (uint8)expect;
                            shared_memory_lock(memory);
                            readv = (uint64)(*(uint8 *)maddr);
                            if (readv == expect)
                                *(uint8 *)maddr = (uint8)(sval);
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG16_U) {
                            CHECK_MEMORY_OVERFLOW(2);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = (uint16)expect;
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U16(maddr);
                            if (readv == expect)
                                STORE_U16(maddr, (uint16)(sval));
                            shared_memory_unlock(memory);
                        }
                        else if (opcode == WASM_OP_ATOMIC_RMW_I64_CMPXCHG32_U) {
                            CHECK_MEMORY_OVERFLOW(4);
                            CHECK_ATOMIC_MEMORY_ACCESS();

                            expect = (uint32)expect;
                            shared_memory_lock(memory);
                            readv = (uint64)LOAD_U32(maddr);
                            if (readv == expect)
                                STORE_U32(maddr, (uint32)(sval));
                            shared_memory_unlock(memory);
                        }
                        else {
                            CHECK_MEMORY_OVERFLOW(8);
                            CHECK_ATOMIC_MEMORY_ACCESS();

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
                frame_sp = frame->sp;
                frame_csp = frame->csp;
#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
                is_return_call = false;
#endif
                goto call_func_from_entry;
            }

#if WASM_ENABLE_DEBUG_INTERP != 0
            HANDLE_OP(DEBUG_OP_BREAK)
            {
                wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TRAP);
                WASM_SUSPEND_FLAGS_FETCH_OR(exec_env->suspend_flags,
                                            WASM_SUSPEND_FLAG_SUSPEND);
                frame_ip--;
                SYNC_ALL_TO_FRAME();
                CHECK_SUSPEND_FLAGS();
                HANDLE_OP_END();
            }
#endif
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
        HANDLE_OP(WASM_OP_SELECT_T)
        HANDLE_OP(WASM_OP_TABLE_GET)
        HANDLE_OP(WASM_OP_TABLE_SET)
        HANDLE_OP(WASM_OP_REF_NULL)
        HANDLE_OP(WASM_OP_REF_IS_NULL)
        HANDLE_OP(WASM_OP_REF_FUNC)
#endif
#if WASM_ENABLE_GC == 0
        HANDLE_OP(WASM_OP_CALL_REF)
        HANDLE_OP(WASM_OP_RETURN_CALL_REF)
        HANDLE_OP(WASM_OP_REF_EQ)
        HANDLE_OP(WASM_OP_REF_AS_NON_NULL)
        HANDLE_OP(WASM_OP_BR_ON_NULL)
        HANDLE_OP(WASM_OP_BR_ON_NON_NULL)
        HANDLE_OP(WASM_OP_GC_PREFIX)
#endif
#if WASM_ENABLE_EXCE_HANDLING == 0
        HANDLE_OP(WASM_OP_TRY)
        HANDLE_OP(WASM_OP_CATCH)
        HANDLE_OP(WASM_OP_THROW)
        HANDLE_OP(WASM_OP_RETHROW)
        HANDLE_OP(WASM_OP_DELEGATE)
        HANDLE_OP(WASM_OP_CATCH_ALL)
        HANDLE_OP(EXT_OP_TRY)
#endif
        /* SIMD isn't supported by interpreter, but when JIT is
           enabled, `iwasm --interp <wasm_file>` may be run to
           trigger the SIMD opcode in interpreter */
        HANDLE_OP(WASM_OP_SIMD_PREFIX)
        HANDLE_OP(WASM_OP_UNUSED_0x16)
        HANDLE_OP(WASM_OP_UNUSED_0x17)
        HANDLE_OP(WASM_OP_UNUSED_0x27)
        /* Used by fast interpreter */
        HANDLE_OP(EXT_OP_SET_LOCAL_FAST_I64)
        HANDLE_OP(EXT_OP_TEE_LOCAL_FAST_I64)
        HANDLE_OP(EXT_OP_COPY_STACK_TOP)
        HANDLE_OP(EXT_OP_COPY_STACK_TOP_I64)
        HANDLE_OP(EXT_OP_COPY_STACK_VALUES)
        {
            wasm_set_exception(module, "unsupported opcode");
            goto got_exception;
        }
#endif /* end of WASM_ENABLE_LABELS_AS_VALUES != 0 */

#if WASM_ENABLE_LABELS_AS_VALUES == 0
        continue;
#else
    FETCH_OPCODE_AND_DISPATCH();
#endif

#if WASM_ENABLE_TAIL_CALL != 0 || WASM_ENABLE_GC != 0
    call_func_from_return_call:
    {
        POP(cur_func->param_cell_num);
        if (cur_func->param_cell_num > 0) {
            word_copy(frame->lp, frame_sp, cur_func->param_cell_num);
        }
        FREE_FRAME(exec_env, frame);
        wasm_exec_env_set_cur_frame(exec_env, prev_frame);
        is_return_call = true;
        goto call_func_from_entry;
    }
#endif
    call_func_from_interp:
    {
        /* Only do the copy when it's called from interpreter.  */
        WASMInterpFrame *outs_area = wasm_exec_env_wasm_stack_top(exec_env);
        if (cur_func->param_cell_num > 0) {
            POP(cur_func->param_cell_num);
            word_copy(outs_area->lp, frame_sp, cur_func->param_cell_num);
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

#if WASM_ENABLE_EXCE_HANDLING != 0
                char uncaught_exception[128] = { 0 };
                bool has_exception =
                    wasm_copy_exception(module, uncaught_exception);
                if (has_exception
                    && strstr(uncaught_exception, "uncaught wasm exception")) {
                    uint32 import_exception;
                    /* initialize imported exception index to be invalid */
                    SET_INVALID_TAGINDEX(import_exception);

                    /* pull external exception */
                    uint32 ext_exception = POP_I32();

                    /* external function came back with an exception or trap */
                    /* lookup exception in import tags */
                    WASMTagInstance *tag = module->e->tags;
                    for (uint32 t = 0; t < module->module->import_tag_count;
                         tag++, t++) {

                        /* compare the module and the external index with the
                         * import tag data */
                        if ((cur_func->u.func_import->import_module
                             == tag->u.tag_import->import_module)
                            && (ext_exception
                                == tag->u.tag_import
                                       ->import_tag_index_linked)) {
                            /* set the import_exception to the import tag */
                            import_exception = t;
                            break;
                        }
                    }
                    /*
                     * exchange the thrown exception (index valid in submodule)
                     * with the imported exception index (valid in this module)
                     * if the module did not import the exception,
                     * that results in a "INVALID_TAGINDEX", that triggers
                     * an CATCH_ALL block, if there is one.
                     */
                    PUSH_I32(import_exception);
                }
#endif /* end of WASM_ENABLE_EXCE_HANDLING != 0 */
            }
            else
#endif /* end of WASM_ENABLE_MULTI_MODULE != 0 */
            {
                wasm_interp_call_func_native(module, exec_env, cur_func,
                                             prev_frame);
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
            }

            /* update memory size, no need to update memory ptr as
               it isn't changed in wasm_enlarge_memory */
#if !defined(OS_ENABLE_HW_BOUND_CHECK)              \
    || WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS == 0 \
    || WASM_ENABLE_BULK_MEMORY != 0
            if (memory)
                linear_mem_size = GET_LINEAR_MEMORY_SIZE(memory);
#endif
            if (wasm_copy_exception(module, NULL)) {
#if WASM_ENABLE_EXCE_HANDLING != 0
                /* the caller raised an exception */
                char uncaught_exception[128] = { 0 };
                bool has_exception =
                    wasm_copy_exception(module, uncaught_exception);

                /* libc_builtin signaled a "exception thrown by stdc++" trap */
                if (has_exception
                    && strstr(uncaught_exception,
                              "exception thrown by stdc++")) {
                    wasm_set_exception(module, NULL);

                    /* setup internal c++ rethrow */
                    exception_tag_index = 0;
                    goto find_a_catch_handler;
                }

                /* when throw hits the end of a function it signals with a
                 * "uncaught wasm exception" trap */
                if (has_exception
                    && strstr(uncaught_exception, "uncaught wasm exception")) {
                    wasm_set_exception(module, NULL);
                    exception_tag_index = POP_I32();

                    /* rethrow the exception into that frame */
                    goto find_a_catch_handler;
                }
#endif /* WASM_ENABLE_EXCE_HANDLING != 0 */
                goto got_exception;
            }
        }
        else {
            WASMFunction *cur_wasm_func = cur_func->u.func;
            WASMFuncType *func_type = cur_wasm_func->func_type;
            uint32 max_stack_cell_num = cur_wasm_func->max_stack_cell_num;
            uint32 cell_num_of_local_stack;
#if WASM_ENABLE_REF_TYPES != 0 && WASM_ENABLE_GC == 0
            uint32 local_cell_idx;
#endif

#if WASM_ENABLE_EXCE_HANDLING != 0
            /* account for exception handlers, bundle them here */
            uint32 eh_size =
                cur_wasm_func->exception_handler_count * sizeof(uint8 *);
            max_stack_cell_num += eh_size;
#endif

            cell_num_of_local_stack = cur_func->param_cell_num
                                      + cur_func->local_cell_num
                                      + max_stack_cell_num;
            all_cell_num = cell_num_of_local_stack
                           + cur_wasm_func->max_block_num
                                 * (uint32)sizeof(WASMBranchBlock) / 4;
#if WASM_ENABLE_GC != 0
            /* area of frame_ref */
            all_cell_num += (cell_num_of_local_stack + 3) / 4;
#endif

            /* param_cell_num, local_cell_num, max_stack_cell_num and
               max_block_num are all no larger than UINT16_MAX (checked
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
            frame_lp = frame->lp;

            frame_sp = frame->sp_bottom =
                frame_lp + cur_func->param_cell_num + cur_func->local_cell_num;
            frame->sp_boundary = frame->sp_bottom + max_stack_cell_num;

            frame_csp = frame->csp_bottom =
                (WASMBranchBlock *)frame->sp_boundary;
            frame->csp_boundary =
                frame->csp_bottom + cur_wasm_func->max_block_num;

#if WASM_ENABLE_GC != 0
            /* frame->sp and frame->ip are used during GC root set enumeration,
             * so we must initialized these fields here */
            frame->sp = frame_sp;
            frame->ip = frame_ip;
            frame_ref = (uint8 *)frame->csp_boundary;
            init_frame_refs(frame_ref, (uint32)cell_num_of_local_stack,
                            cur_func);
#endif

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

            /* Push function block as first block */
            cell_num = func_type->ret_cell_num;
            PUSH_CSP(LABEL_TYPE_FUNCTION, 0, cell_num, frame_ip_end - 1);

            wasm_exec_env_set_cur_frame(exec_env, frame);
        }
#if WASM_ENABLE_THREAD_MGR != 0
        CHECK_SUSPEND_FLAGS();
#endif
        HANDLE_OP_END();
    }

    return_func:
    {
        FREE_FRAME(exec_env, frame);
        wasm_exec_env_set_cur_frame(exec_env, prev_frame);

        if (!prev_frame->ip) {
            /* Called from native. */
            return;
        }

        RECOVER_CONTEXT(prev_frame);
#if WASM_ENABLE_EXCE_HANDLING != 0
        if (wasm_get_exception(module)) {
            wasm_set_exception(module, NULL);
            exception_tag_index = POP_I32();
            goto find_a_catch_handler;
        }
#endif
        HANDLE_OP_END();
    }

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
#if WASM_ENABLE_DEBUG_INTERP != 0
        if (wasm_exec_env_get_instance(exec_env) != NULL) {
            uint8 *frame_ip_temp = frame_ip;
            frame_ip = frame_ip_orig;
            wasm_cluster_thread_send_signal(exec_env, WAMR_SIG_TRAP);
            CHECK_SUSPEND_FLAGS();
            frame_ip = frame_ip_temp;
        }
#endif
        SYNC_ALL_TO_FRAME();
        return;

#if WASM_ENABLE_LABELS_AS_VALUES == 0
    }
#else
    FETCH_OPCODE_AND_DISPATCH();
#endif
}

#if WASM_ENABLE_GC != 0
bool
wasm_interp_traverse_gc_rootset(WASMExecEnv *exec_env, void *heap)
{
    WASMInterpFrame *frame;
    WASMObjectRef gc_obj;
    int i;

    frame = wasm_exec_env_get_cur_frame(exec_env);
    for (; frame; frame = frame->prev_frame) {
        uint8 *frame_ref = get_frame_ref(frame);
        for (i = 0; i < frame->sp - frame->lp; i++) {
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

#if WASM_ENABLE_FAST_JIT != 0
/*
 * ASAN is not designed to work with custom stack unwind or other low-level
 * things. Ignore a function that does some low-level magic. (e.g. walking
 * through the thread's stack bypassing the frame boundaries)
 */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((no_sanitize_address))
#endif
static void
fast_jit_call_func_bytecode(WASMModuleInstance *module_inst,
                            WASMExecEnv *exec_env,
                            WASMFunctionInstance *function,
                            WASMInterpFrame *frame)
{
    JitGlobals *jit_globals = jit_compiler_get_jit_globals();
    JitInterpSwitchInfo info;
    WASMModule *module = module_inst->module;
    WASMFuncType *func_type = function->u.func->func_type;
    uint8 type = func_type->result_count
                     ? func_type->types[func_type->param_count]
                     : VALUE_TYPE_VOID;
    uint32 func_idx = (uint32)(function - module_inst->e->functions);
    uint32 func_idx_non_import = func_idx - module->import_function_count;
    int32 action;

#if WASM_ENABLE_REF_TYPES != 0
    if (type == VALUE_TYPE_EXTERNREF || type == VALUE_TYPE_FUNCREF)
        type = VALUE_TYPE_I32;
#endif

#if WASM_ENABLE_LAZY_JIT != 0
    if (!jit_compiler_compile(module, func_idx)) {
        wasm_set_exception(module_inst, "failed to compile fast jit function");
        return;
    }
#endif
    bh_assert(jit_compiler_is_compiled(module, func_idx));

    /* Switch to jitted code to call the jit function */
    info.out.ret.last_return_type = type;
    info.frame = frame;
    frame->jitted_return_addr =
        (uint8 *)jit_globals->return_to_interp_from_jitted;
    action = jit_interp_switch_to_jitted(
        exec_env, &info, func_idx,
        module_inst->fast_jit_func_ptrs[func_idx_non_import]);
    bh_assert(action == JIT_INTERP_ACTION_NORMAL
              || (action == JIT_INTERP_ACTION_THROWN
                  && wasm_copy_exception(
                      (WASMModuleInstance *)exec_env->module_inst, NULL)));

    /* Get the return values form info.out.ret */
    if (func_type->result_count) {
        switch (type) {
            case VALUE_TYPE_I32:
                *(frame->sp - function->ret_cell_num) = info.out.ret.ival[0];
                break;
            case VALUE_TYPE_I64:
                *(frame->sp - function->ret_cell_num) = info.out.ret.ival[0];
                *(frame->sp - function->ret_cell_num + 1) =
                    info.out.ret.ival[1];
                break;
            case VALUE_TYPE_F32:
                *(frame->sp - function->ret_cell_num) = info.out.ret.fval[0];
                break;
            case VALUE_TYPE_F64:
                *(frame->sp - function->ret_cell_num) = info.out.ret.fval[0];
                *(frame->sp - function->ret_cell_num + 1) =
                    info.out.ret.fval[1];
                break;
            default:
                bh_assert(0);
                break;
        }
    }
    (void)action;
    (void)func_idx;
}
#endif /* end of WASM_ENABLE_FAST_JIT != 0 */

#if WASM_ENABLE_JIT != 0
#if WASM_ENABLE_DUMP_CALL_STACK != 0 || WASM_ENABLE_PERF_PROFILING != 0 \
    || WASM_ENABLE_AOT_STACK_FRAME != 0
#if WASM_ENABLE_GC == 0
bool
llvm_jit_alloc_frame(WASMExecEnv *exec_env, uint32 func_index)
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)exec_env->module_inst;
    WASMInterpFrame *cur_frame, *frame;
    uint32 size = (uint32)offsetof(WASMInterpFrame, lp);

    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    cur_frame = exec_env->cur_frame;
    if (!cur_frame)
        frame = (WASMInterpFrame *)exec_env->wasm_stack.bottom;
    else
        frame = (WASMInterpFrame *)((uint8 *)cur_frame + size);

    if ((uint8 *)frame + size > exec_env->wasm_stack.top_boundary) {
        wasm_set_exception(module_inst, "wasm operand stack overflow");
        return false;
    }

    frame->function = module_inst->e->functions + func_index;
    /* No need to initialize ip, it will be committed in jitted code
       when needed */
    /* frame->ip = NULL; */
    frame->prev_frame = cur_frame;

#if WASM_ENABLE_PERF_PROFILING != 0
    frame->time_started = os_time_thread_cputime_us();
#endif
#if WASM_ENABLE_MEMORY_PROFILING != 0
    {
        uint32 wasm_stack_used =
            (uint8 *)frame + size - exec_env->wasm_stack.bottom;
        if (wasm_stack_used > exec_env->max_wasm_stack_used)
            exec_env->max_wasm_stack_used = wasm_stack_used;
    }
#endif

    exec_env->cur_frame = frame;

    return true;
}

static inline void
llvm_jit_free_frame_internal(WASMExecEnv *exec_env)
{
    WASMInterpFrame *frame = exec_env->cur_frame;
    WASMInterpFrame *prev_frame = frame->prev_frame;

    bh_assert(exec_env->module_inst->module_type == Wasm_Module_Bytecode);

#if WASM_ENABLE_PERF_PROFILING != 0
    if (frame->function) {
        uint64 time_elapsed = os_time_thread_cputime_us() - frame->time_started;

        frame->function->total_exec_time += time_elapsed;
        frame->function->total_exec_cnt++;

        /* parent function */
        if (prev_frame)
            prev_frame->function->children_exec_time += time_elapsed;
    }
#endif
    exec_env->cur_frame = prev_frame;
}

void
llvm_jit_free_frame(WASMExecEnv *exec_env)
{
    llvm_jit_free_frame_internal(exec_env);
}

#else /* else of WASM_ENABLE_GC == 0 */

bool
llvm_jit_alloc_frame(WASMExecEnv *exec_env, uint32 func_index)
{
    WASMModuleInstance *module_inst;
    WASMModule *module;
    WASMInterpFrame *frame;
    uint32 size, max_local_cell_num, max_stack_cell_num;

    bh_assert(exec_env->module_inst->module_type == Wasm_Module_Bytecode);

    module_inst = (WASMModuleInstance *)exec_env->module_inst;
    module = module_inst->module;

    if (func_index >= func_index - module->import_function_count) {
        WASMFunction *func =
            module->functions[func_index - module->import_function_count];

        max_local_cell_num = func->param_cell_num + func->local_cell_num;
        max_stack_cell_num = func->max_stack_cell_num;
    }
    else {
        WASMFunctionImport *func =
            &((module->import_functions + func_index)->u.function);

        max_local_cell_num = func->func_type->param_cell_num > 2
                                 ? func->func_type->param_cell_num
                                 : 2;
        max_stack_cell_num = 0;
    }

    size =
        wasm_interp_interp_frame_size(max_local_cell_num + max_stack_cell_num);

    frame = wasm_exec_env_alloc_wasm_frame(exec_env, size);
    if (!frame) {
        wasm_set_exception(module_inst, "wasm operand stack overflow");
        return false;
    }

    frame->function = module_inst->e->functions + func_index;
#if WASM_ENABLE_PERF_PROFILING != 0
    frame->time_started = os_time_thread_cputime_us();
#endif
    frame->prev_frame = wasm_exec_env_get_cur_frame(exec_env);

    /* No need to initialize ip, it will be committed in jitted code
       when needed */
    /* frame->ip = NULL; */

#if WASM_ENABLE_GC != 0
    frame->sp = frame->lp + max_local_cell_num;

    /* Initialize frame ref flags for import function */
    if (func_index < module->import_function_count) {
        WASMFunctionImport *func =
            &((module->import_functions + func_index)->u.function);
        WASMFuncType *func_type = func->func_type;
        /* native function doesn't have operand stack and label stack */
        uint8 *frame_ref = (uint8 *)frame->sp;
        uint32 i, j, k, value_type_cell_num;

        for (i = 0, j = 0; i < func_type->param_count; i++) {
            if (wasm_is_type_reftype(func_type->types[i])
                && !wasm_is_reftype_i31ref(func_type->types[i])) {
                frame_ref[j++] = 1;
#if UINTPTR_MAX == UINT64_MAX
                frame_ref[j++] = 1;
#endif
            }
            else {
                value_type_cell_num =
                    wasm_value_type_cell_num(func_type->types[i]);
                for (k = 0; k < value_type_cell_num; k++)
                    frame_ref[j++] = 0;
            }
        }
    }
#endif

    wasm_exec_env_set_cur_frame(exec_env, frame);

    return true;
}

static inline void
llvm_jit_free_frame_internal(WASMExecEnv *exec_env)
{
    WASMInterpFrame *frame;
    WASMInterpFrame *prev_frame;

    bh_assert(exec_env->module_inst->module_type == Wasm_Module_Bytecode);

    frame = wasm_exec_env_get_cur_frame(exec_env);
    prev_frame = frame->prev_frame;

#if WASM_ENABLE_PERF_PROFILING != 0
    if (frame->function) {
        uint64 time_elapsed = os_time_thread_cputime_us() - frame->time_started;

        frame->function->total_exec_time += time_elapsed;
        frame->function->total_exec_cnt++;

        /* parent function */
        if (prev_frame)
            prev_frame->function->children_exec_time += time_elapsed;
    }
#endif
    wasm_exec_env_free_wasm_frame(exec_env, frame);
    wasm_exec_env_set_cur_frame(exec_env, prev_frame);
}

void
llvm_jit_free_frame(WASMExecEnv *exec_env)
{
    llvm_jit_free_frame_internal(exec_env);
}
#endif /* end of WASM_ENABLE_GC == 0 */

void
llvm_jit_frame_update_profile_info(WASMExecEnv *exec_env, bool alloc_frame)
{
#if WASM_ENABLE_PERF_PROFILING != 0
    WASMInterpFrame *cur_frame = exec_env->cur_frame;

    if (alloc_frame) {
        cur_frame->time_started = os_time_thread_cputime_us();
    }
    else {
        if (cur_frame->function) {
            WASMInterpFrame *prev_frame = cur_frame->prev_frame;
            uint64 time_elapsed =
                os_time_thread_cputime_us() - cur_frame->time_started;

            cur_frame->function->total_exec_time += time_elapsed;
            cur_frame->function->total_exec_cnt++;

            /* parent function */
            if (prev_frame)
                prev_frame->function->children_exec_time += time_elapsed;
        }
    }
#endif

#if WASM_ENABLE_MEMORY_PROFILING != 0
    if (alloc_frame) {
#if WASM_ENABLE_GC == 0
        uint32 wasm_stack_used = (uint8 *)exec_env->cur_frame
                                 + (uint32)offsetof(WASMInterpFrame, lp)
                                 - exec_env->wasm_stack.bottom;
#else
        uint32 wasm_stack_used =
            exec_env->wasm_stack.top - exec_env->wasm_stack.bottom;
#endif
        if (wasm_stack_used > exec_env->max_wasm_stack_used)
            exec_env->max_wasm_stack_used = wasm_stack_used;
    }
#endif
}
#endif /* end of WASM_ENABLE_DUMP_CALL_STACK != 0 \
          || WASM_ENABLE_PERF_PROFILING != 0      \
          || WASM_ENABLE_AOT_STACK_FRAME != 0 */

static bool
llvm_jit_call_func_bytecode(WASMModuleInstance *module_inst,
                            WASMExecEnv *exec_env,
                            WASMFunctionInstance *function, uint32 argc,
                            uint32 argv[])
{
    WASMFuncType *func_type = function->u.func->func_type;
    uint32 result_count = func_type->result_count;
    uint32 ext_ret_count = result_count > 1 ? result_count - 1 : 0;
    uint32 func_idx = (uint32)(function - module_inst->e->functions);
    bool ret = false;

#if (WASM_ENABLE_DUMP_CALL_STACK != 0) || (WASM_ENABLE_PERF_PROFILING != 0) \
    || (WASM_ENABLE_AOT_STACK_FRAME != 0)
    if (!llvm_jit_alloc_frame(exec_env, function - module_inst->e->functions)) {
        /* wasm operand stack overflow has been thrown,
           no need to throw again */
        return false;
    }
#endif

    if (ext_ret_count > 0) {
        uint32 cell_num = 0, i;
        uint8 *ext_ret_types = func_type->types + func_type->param_count + 1;
        uint32 argv1_buf[32], *argv1 = argv1_buf, *ext_rets = NULL;
        uint32 *argv_ret = argv;
        uint32 ext_ret_cell = wasm_get_cell_num(ext_ret_types, ext_ret_count);
        uint64 size;

        /* Allocate memory all arguments */
        size =
            sizeof(uint32) * (uint64)argc /* original arguments */
            + sizeof(void *)
                  * (uint64)ext_ret_count /* extra result values' addr */
            + sizeof(uint32) * (uint64)ext_ret_cell; /* extra result values */
        if (size > sizeof(argv1_buf)) {
            if (size > UINT32_MAX
                || !(argv1 = wasm_runtime_malloc((uint32)size))) {
                wasm_set_exception(module_inst, "allocate memory failed");
                ret = false;
                goto fail;
            }
        }

        /* Copy original arguments */
        bh_memcpy_s(argv1, (uint32)size, argv, sizeof(uint32) * argc);

        /* Get the extra result value's address */
        ext_rets =
            argv1 + argc + sizeof(void *) / sizeof(uint32) * ext_ret_count;

        /* Append each extra result value's address to original arguments */
        for (i = 0; i < ext_ret_count; i++) {
            *(uintptr_t *)(argv1 + argc + sizeof(void *) / sizeof(uint32) * i) =
                (uintptr_t)(ext_rets + cell_num);
            cell_num += wasm_value_type_cell_num(ext_ret_types[i]);
        }

        ret = wasm_runtime_invoke_native(
            exec_env, module_inst->func_ptrs[func_idx], func_type, NULL, NULL,
            argv1, argc, argv);
        if (!ret) {
            if (argv1 != argv1_buf)
                wasm_runtime_free(argv1);
            goto fail;
        }

        /* Get extra result values */
        switch (func_type->types[func_type->param_count]) {
            case VALUE_TYPE_I32:
            case VALUE_TYPE_F32:
#if WASM_ENABLE_REF_TYPES != 0
            case VALUE_TYPE_FUNCREF:
            case VALUE_TYPE_EXTERNREF:
#endif
                argv_ret++;
                break;
            case VALUE_TYPE_I64:
            case VALUE_TYPE_F64:
                argv_ret += 2;
                break;
#if WASM_ENABLE_SIMD != 0
            case VALUE_TYPE_V128:
                argv_ret += 4;
                break;
#endif
            default:
                bh_assert(0);
                break;
        }

        ext_rets =
            argv1 + argc + sizeof(void *) / sizeof(uint32) * ext_ret_count;
        bh_memcpy_s(argv_ret, sizeof(uint32) * cell_num, ext_rets,
                    sizeof(uint32) * cell_num);

        if (argv1 != argv1_buf)
            wasm_runtime_free(argv1);
        ret = true;
    }
    else {
#if WASM_ENABLE_QUICK_AOT_ENTRY != 0
        /* Quick call if the quick jit entry is registered */
        if (func_type->quick_aot_entry) {
            void (*invoke_native)(void *func_ptr, void *exec_env, uint32 *argv,
                                  uint32 *argv_ret) =
                func_type->quick_aot_entry;
            invoke_native(module_inst->func_ptrs[func_idx], exec_env, argv,
                          argv);
            ret = !wasm_copy_exception(module_inst, NULL);
        }
        else
#endif
        {
            ret = wasm_runtime_invoke_native(
                exec_env, module_inst->func_ptrs[func_idx], func_type, NULL,
                NULL, argv, argc, argv);

            if (ret)
                ret = !wasm_copy_exception(module_inst, NULL);
        }
    }

fail:

#if (WASM_ENABLE_DUMP_CALL_STACK != 0) || (WASM_ENABLE_PERF_PROFILING != 0) \
    || (WASM_ENABLE_AOT_STACK_FRAME != 0)
    llvm_jit_free_frame_internal(exec_env);
#endif

    return ret;
}
#endif /* end of WASM_ENABLE_JIT != 0 */

void
wasm_interp_call_wasm(WASMModuleInstance *module_inst, WASMExecEnv *exec_env,
                      WASMFunctionInstance *function, uint32 argc,
                      uint32 argv[])
{
    WASMRuntimeFrame *frame = NULL, *prev_frame, *outs_area;
    RunningMode running_mode =
        wasm_runtime_get_running_mode((WASMModuleInstanceCommon *)module_inst);
    /* Allocate sufficient cells for all kinds of return values.  */
    bool alloc_frame = true;

    if (argc < function->param_cell_num) {
        char buf[128];
        snprintf(buf, sizeof(buf),
                 "invalid argument count %" PRIu32
                 ", must be no smaller than %u",
                 argc, function->param_cell_num);
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

    if (!function->is_import_func) {
        /* No need to alloc frame when calling LLVM JIT function */
#if WASM_ENABLE_JIT != 0
        if (running_mode == Mode_LLVM_JIT) {
            alloc_frame = false;
        }
#if WASM_ENABLE_LAZY_JIT != 0 && WASM_ENABLE_FAST_JIT != 0
        else if (running_mode == Mode_Multi_Tier_JIT) {
            /* Tier-up from Fast JIT to LLVM JIT, call llvm jit function
               if it is compiled, else call fast jit function */
            uint32 func_idx = (uint32)(function - module_inst->e->functions);
            if (module_inst->module->func_ptrs_compiled
                    [func_idx - module_inst->module->import_function_count]) {
                alloc_frame = false;
            }
        }
#endif
#endif
    }

    if (alloc_frame) {
        unsigned all_cell_num =
            function->ret_cell_num > 2 ? function->ret_cell_num : 2;
        unsigned frame_size;

        prev_frame = wasm_exec_env_get_cur_frame(exec_env);
        /* This frame won't be used by JITed code, so only allocate interp
           frame here.  */
        frame_size = wasm_interp_interp_frame_size(all_cell_num);

        if (!(frame = ALLOC_FRAME(exec_env, frame_size, prev_frame)))
            return;

        outs_area = wasm_exec_env_wasm_stack_top(exec_env);
        frame->function = NULL;
        frame->ip = NULL;
        /* There is no local variable. */
        frame->sp = frame->lp + 0;

        if ((uint8 *)(outs_area->lp + function->param_cell_num)
            > exec_env->wasm_stack.top_boundary) {
            wasm_set_exception(module_inst, "wasm operand stack overflow");
            return;
        }

        if (argc > 0)
            word_copy(outs_area->lp, argv, argc);

        wasm_exec_env_set_cur_frame(exec_env, frame);
    }

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
            wasm_interp_call_func_import(module_inst, exec_env, function,
                                         frame);
        }
        else
#endif
        {
            /* it is a native function */
            wasm_interp_call_func_native(module_inst, exec_env, function,
                                         frame);
        }
    }
    else {
        if (running_mode == Mode_Interp) {
            wasm_interp_call_func_bytecode(module_inst, exec_env, function,
                                           frame);
        }
#if WASM_ENABLE_FAST_JIT != 0
        else if (running_mode == Mode_Fast_JIT) {
            fast_jit_call_func_bytecode(module_inst, exec_env, function, frame);
        }
#endif
#if WASM_ENABLE_JIT != 0
        else if (running_mode == Mode_LLVM_JIT) {
            llvm_jit_call_func_bytecode(module_inst, exec_env, function, argc,
                                        argv);
        }
#endif
#if WASM_ENABLE_LAZY_JIT != 0 && WASM_ENABLE_FAST_JIT != 0 \
    && WASM_ENABLE_JIT != 0
        else if (running_mode == Mode_Multi_Tier_JIT) {
            /* Tier-up from Fast JIT to LLVM JIT, call llvm jit function
               if it is compiled, else call fast jit function */
            uint32 func_idx = (uint32)(function - module_inst->e->functions);
            if (module_inst->module->func_ptrs_compiled
                    [func_idx - module_inst->module->import_function_count]) {
                llvm_jit_call_func_bytecode(module_inst, exec_env, function,
                                            argc, argv);
            }
            else {
                fast_jit_call_func_bytecode(module_inst, exec_env, function,
                                            frame);
            }
        }
#endif
        else {
            /* There should always be a supported running mode selected */
            bh_assert(0);
        }

        (void)wasm_interp_call_func_bytecode;
#if WASM_ENABLE_FAST_JIT != 0
        (void)fast_jit_call_func_bytecode;
#endif
    }

    /* Output the return value to the caller */
    if (!wasm_copy_exception(module_inst, NULL)) {
        if (alloc_frame) {
            uint32 i;
            for (i = 0; i < function->ret_cell_num; i++) {
                argv[i] = *(frame->sp + i - function->ret_cell_num);
            }
        }
    }
    else {
#if WASM_ENABLE_DUMP_CALL_STACK != 0
        if (wasm_interp_create_call_stack(exec_env)) {
            wasm_interp_dump_call_stack(exec_env, true, NULL, 0);
        }
#endif
    }

    if (alloc_frame) {
        wasm_exec_env_set_cur_frame(exec_env, prev_frame);
        FREE_FRAME(exec_env, frame);
    }
}
