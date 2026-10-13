/*
 * Copyright (C) 2023 Amazon Inc.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_ATOMIC_H
#define _BH_ATOMIC_H

#include "bh_platform.h"
#include "gnuc.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Why don't we use C11 stdatomics here?
 *
 * Unlike C11 stdatomics,
 *
 * - bh_atomic_xxx_t is guaranteed to have the same size as the base type.
 *   Thus more friendly to our AOT conventions.
 *
 * - It's available for C++.
 *   Although C++23 will have C-compatible stdatomics.h, it isn't widely
 *   available yet.
 */

/*
 * Note about BH_ATOMIC_32_IS_ATOMIC
 *
 * If BH_ATOMIC_32_IS_ATOMIC == 0, BH_ATOMIC_xxx operations defined below
 * are not really atomic and require an external lock.
 *
 * Expected usage is:
 *
 *     bh_atomic_32_t var = 0;
 *     uint32 old;
 * #if BH_ATOMIC_32_IS_ATOMIC == 0
 *     lock(&some_lock);
 * #endif
 *     old = BH_ATOMIC_32_FETCH_AND(var, 1);
 * #if BH_ATOMIC_32_IS_ATOMIC == 0
 *     unlock(&some_lock);
 * #endif
 */

typedef uint64 bh_atomic_64_t;
typedef uint32 bh_atomic_32_t;
typedef uint16 bh_atomic_16_t;

/* The flag can be defined by the user if the platform
 * supports atomic 32-bit operations.
 * If left undefined, it will be automatically defined
 * according to the platform.
 */
#ifdef WASM_UINT64_IS_ATOMIC
#define BH_ATOMIC_64_IS_ATOMIC WASM_UINT64_IS_ATOMIC
#endif /* WASM_UINT64_IS_ATOMIC */

#ifdef WASM_UINT32_IS_ATOMIC
#define BH_ATOMIC_32_IS_ATOMIC WASM_UINT32_IS_ATOMIC
#endif /* WASM_UINT32_IS_ATOMIC */

#ifdef WASM_UINT16_IS_ATOMIC
#define BH_ATOMIC_16_IS_ATOMIC WASM_UINT16_IS_ATOMIC
#endif /* WASM_UINT16_IS_ATOMIC */

#if defined(__GNUC_PREREQ)
#if __GNUC_PREREQ(4, 7)
#define CLANG_GCC_HAS_ATOMIC_BUILTIN
#endif
#elif defined(__clang__)
#if __clang_major__ > 3 || (__clang_major__ == 3 && __clang_minor__ >= 0)
#define CLANG_GCC_HAS_ATOMIC_BUILTIN
#endif
#endif

#if defined(CLANG_GCC_HAS_ATOMIC_BUILTIN)
#ifndef BH_ATOMIC_64_IS_ATOMIC
#define BH_ATOMIC_64_IS_ATOMIC 1
#endif
#ifndef BH_ATOMIC_32_IS_ATOMIC
#define BH_ATOMIC_32_IS_ATOMIC 1
#endif
#ifndef BH_ATOMIC_16_IS_ATOMIC
#define BH_ATOMIC_16_IS_ATOMIC 1
#endif
#else
#ifndef BH_ATOMIC_64_IS_ATOMIC
#define BH_ATOMIC_64_IS_ATOMIC 0
#endif
#ifndef BH_ATOMIC_32_IS_ATOMIC
#define BH_ATOMIC_32_IS_ATOMIC 0
#endif
#ifndef BH_ATOMIC_16_IS_ATOMIC
#define BH_ATOMIC_16_IS_ATOMIC 0
#endif
#endif

/* Force disable atomic 16-bit operations on bare-metal RISC-V
 * because the 16-bit atomic operations is emulated by 32-bit
 * atomic operations, which has linkage problem on current toolchain:
 * in function `shared_memory_inc_reference':
 * wasm_shared_memory.c:85:(.text.shared_memory_inc_reference+0x10): undefined
 * reference to `__atomic_fetch_add_2'
 */
#ifndef WASM_UINT16_IS_ATOMIC
#if !defined(__linux__) && !defined(__FreeBSD__) && !defined(__NetBSD__) \
    && !defined(__OpenBSD__) && defined(__riscv)
#undef BH_ATOMIC_16_IS_ATOMIC
#define BH_ATOMIC_16_IS_ATOMIC 0
#endif
#endif

/* On some 32-bit platform, disable 64-bit atomic operations, otherwise
 * undefined reference to `__atomic_load_8', if on Zephyr, can add board related
 * macro in autoconf.h to control */
#ifndef WASM_UINT64_IS_ATOMIC
#if !defined(__linux__) && !defined(__FreeBSD__) && !defined(__NetBSD__) \
    && !defined(__OpenBSD__) && (defined(__riscv) || defined(__arm__))   \
    && UINT32_MAX == UINTPTR_MAX
#undef BH_ATOMIC_64_IS_ATOMIC
#define BH_ATOMIC_64_IS_ATOMIC 0
#endif
#endif

#if BH_ATOMIC_64_IS_ATOMIC != 0

#define BH_ATOMIC_64_LOAD(v) __atomic_load_n(&(v), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_64_STORE(v, val) __atomic_store_n(&(v), val, __ATOMIC_SEQ_CST)
#define BH_ATOMIC_64_FETCH_OR(v, val) \
    __atomic_fetch_or(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_64_FETCH_AND(v, val) \
    __atomic_fetch_and(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_64_FETCH_ADD(v, val) \
    __atomic_fetch_add(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_64_FETCH_SUB(v, val) \
    __atomic_fetch_sub(&(v), (val), __ATOMIC_SEQ_CST)

#else /* else of BH_ATOMIC_64_IS_ATOMIC != 0 */

#define BH_ATOMIC_64_LOAD(v) (v)
#define BH_ATOMIC_64_STORE(v, val) (v) = val
#define BH_ATOMIC_64_FETCH_OR(v, val) nonatomic_64_fetch_or(&(v), val)
#define BH_ATOMIC_64_FETCH_AND(v, val) nonatomic_64_fetch_and(&(v), val)
#define BH_ATOMIC_64_FETCH_ADD(v, val) nonatomic_64_fetch_add(&(v), val)
#define BH_ATOMIC_64_FETCH_SUB(v, val) nonatomic_64_fetch_sub(&(v), val)

static inline uint64
nonatomic_64_fetch_or(bh_atomic_64_t *p, uint64 val)
{
    uint64 old = *p;
    *p |= val;
    return old;
}

static inline uint64
nonatomic_64_fetch_and(bh_atomic_64_t *p, uint64 val)
{
    uint64 old = *p;
    *p &= val;
    return old;
}

static inline uint64
nonatomic_64_fetch_add(bh_atomic_64_t *p, uint64 val)
{
    uint64 old = *p;
    *p += val;
    return old;
}

static inline uint64
nonatomic_64_fetch_sub(bh_atomic_64_t *p, uint64 val)
{
    uint64 old = *p;
    *p -= val;
    return old;
}
#endif

#if BH_ATOMIC_32_IS_ATOMIC != 0

#define BH_ATOMIC_32_LOAD(v) __atomic_load_n(&(v), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_32_STORE(v, val) __atomic_store_n(&(v), val, __ATOMIC_SEQ_CST)
#define BH_ATOMIC_32_FETCH_OR(v, val) \
    __atomic_fetch_or(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_32_FETCH_AND(v, val) \
    __atomic_fetch_and(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_32_FETCH_ADD(v, val) \
    __atomic_fetch_add(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_32_FETCH_SUB(v, val) \
    __atomic_fetch_sub(&(v), (val), __ATOMIC_SEQ_CST)

#else /* else of BH_ATOMIC_32_IS_ATOMIC != 0 */

#define BH_ATOMIC_32_LOAD(v) (v)
#define BH_ATOMIC_32_STORE(v, val) (v) = val
#define BH_ATOMIC_32_FETCH_OR(v, val) nonatomic_32_fetch_or(&(v), val)
#define BH_ATOMIC_32_FETCH_AND(v, val) nonatomic_32_fetch_and(&(v), val)
#define BH_ATOMIC_32_FETCH_ADD(v, val) nonatomic_32_fetch_add(&(v), val)
#define BH_ATOMIC_32_FETCH_SUB(v, val) nonatomic_32_fetch_sub(&(v), val)

static inline uint32
nonatomic_32_fetch_or(bh_atomic_32_t *p, uint32 val)
{
    uint32 old = *p;
    *p |= val;
    return old;
}

static inline uint32
nonatomic_32_fetch_and(bh_atomic_32_t *p, uint32 val)
{
    uint32 old = *p;
    *p &= val;
    return old;
}

static inline uint32
nonatomic_32_fetch_add(bh_atomic_32_t *p, uint32 val)
{
    uint32 old = *p;
    *p += val;
    return old;
}

static inline uint32
nonatomic_32_fetch_sub(bh_atomic_32_t *p, uint32 val)
{
    uint32 old = *p;
    *p -= val;
    return old;
}

#endif

#if BH_ATOMIC_16_IS_ATOMIC != 0

#define BH_ATOMIC_16_IS_ATOMIC 1
#define BH_ATOMIC_16_LOAD(v) __atomic_load_n(&(v), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_16_STORE(v, val) __atomic_store_n(&(v), val, __ATOMIC_SEQ_CST)
#define BH_ATOMIC_16_FETCH_OR(v, val) \
    __atomic_fetch_or(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_16_FETCH_AND(v, val) \
    __atomic_fetch_and(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_16_FETCH_ADD(v, val) \
    __atomic_fetch_add(&(v), (val), __ATOMIC_SEQ_CST)
#define BH_ATOMIC_16_FETCH_SUB(v, val) \
    __atomic_fetch_sub(&(v), (val), __ATOMIC_SEQ_CST)

#else /* else of BH_ATOMIC_16_IS_ATOMIC != 0 */

#define BH_ATOMIC_16_LOAD(v) (v)
#define BH_ATOMIC_16_STORE(v) (v) = val
#define BH_ATOMIC_16_FETCH_OR(v, val) nonatomic_16_fetch_or(&(v), val)
#define BH_ATOMIC_16_FETCH_AND(v, val) nonatomic_16_fetch_and(&(v), val)
#define BH_ATOMIC_16_FETCH_ADD(v, val) nonatomic_16_fetch_add(&(v), val)
#define BH_ATOMIC_16_FETCH_SUB(v, val) nonatomic_16_fetch_sub(&(v), val)

static inline uint16
nonatomic_16_fetch_or(bh_atomic_16_t *p, uint16 val)
{
    uint16 old = *p;
    *p |= val;
    return old;
}

static inline uint16
nonatomic_16_fetch_and(bh_atomic_16_t *p, uint16 val)
{
    uint16 old = *p;
    *p &= val;
    return old;
}

static inline uint16
nonatomic_16_fetch_add(bh_atomic_16_t *p, uint16 val)
{
    uint16 old = *p;
    *p += val;
    return old;
}

static inline uint16
nonatomic_16_fetch_sub(bh_atomic_16_t *p, uint16 val)
{
    uint16 old = *p;
    *p -= val;
    return old;
}

#endif

#ifdef __cplusplus
}
#endif

#endif /* end of _BH_ATOMIC_H */
