// Part of the Wasmtime Project, under the Apache License v2.0 with LLVM
// Exceptions. See
// https://github.com/bytecodealliance/wasmtime/blob/main/LICENSE for license
// information.
//
// Significant parts of this file are derived from cloudabi-utils. See
// https://github.com/bytecodealliance/wasmtime/blob/main/lib/wasi/sandboxed-system-primitives/src/LICENSE
// for license information.
//
// The upstream file contains the following copyright notice:
//
// Copyright (c) 2016 Nuxi, https://nuxi.nl/

#ifndef REFCOUNT_H
#define REFCOUNT_H

#include "bh_platform.h"
#include "locking.h"
#include "gnuc.h"

#define PRODUCES(...) LOCKS_SHARED(__VA_ARGS__) NO_LOCK_ANALYSIS
#define CONSUMES(...) UNLOCKS(__VA_ARGS__) NO_LOCK_ANALYSIS

#if CONFIG_HAS_STD_ATOMIC != 0

#include <stdatomic.h>

/* Simple reference counter. */
struct LOCKABLE refcount {
    atomic_uint count;
};

/* Initialize the reference counter. */
static inline void
refcount_init(struct refcount *r, unsigned int count) PRODUCES(*r)
{
    atomic_init(&r->count, count);
}

/* Increment the reference counter. */
static inline void
refcount_acquire(struct refcount *r) PRODUCES(*r)
{
    atomic_fetch_add_explicit(&r->count, 1, memory_order_acquire);
}

/* Decrement the reference counter, returning whether the reference
   dropped to zero. */
static inline bool
refcount_release(struct refcount *r) CONSUMES(*r)
{
    int old =
        (int)atomic_fetch_sub_explicit(&r->count, 1, memory_order_release);
    bh_assert(old != 0 && "Reference count becoming negative");
    return old == 1;
}

#elif defined(BH_PLATFORM_LINUX_SGX)

#include <sgx_spinlock.h>

/* Simple reference counter. */
struct refcount {
    sgx_spinlock_t lock;
    unsigned int count;
};

/* Initialize the reference counter. */
static inline void
refcount_init(struct refcount *r, unsigned int count)
{
    r->lock = SGX_SPINLOCK_INITIALIZER;
    r->count = count;
}

/* Increment the reference counter. */
static inline void
refcount_acquire(struct refcount *r)
{
    sgx_spin_lock(&r->lock);
    r->count++;
    sgx_spin_unlock(&r->lock);
}

/* Decrement the reference counter, returning whether the reference
   dropped to zero. */
static inline bool
refcount_release(struct refcount *r)
{
    int old;
    sgx_spin_lock(&r->lock);
    old = (int)r->count;
    r->count--;
    sgx_spin_unlock(&r->lock);
    bh_assert(old != 0 && "Reference count becoming negative");
    return old == 1;
}

#elif defined(__GNUC_PREREQ)

#if __GNUC_PREREQ(4, 7)

struct refcount {
    unsigned int count;
};

/* Initialize the reference counter. */
static inline void
refcount_init(struct refcount *r, unsigned int count)
{
    __atomic_store_n(&r->count, count, __ATOMIC_SEQ_CST);
}

/* Increment the reference counter. */
static inline void
refcount_acquire(struct refcount *r)
{
    __atomic_fetch_add(&r->count, 1, __ATOMIC_ACQUIRE);
}

/* Decrement the reference counter, returning whether the reference
   dropped to zero. */
static inline bool
refcount_release(struct refcount *r)
{
    int old = (int)__atomic_fetch_sub(&r->count, 1, __ATOMIC_RELEASE);
    bh_assert(old != 0 && "Reference count becoming negative");
    return old == 1;
}

#else /* else of __GNUC_PREREQ (4.7) */
#error "Reference counter isn't implemented"
#endif /* end of __GNUC_PREREQ (4.7) */

#elif defined(_MSC_VER)

/* Simple reference counter. */
struct LOCKABLE refcount {
    LONG count;
};

/* Initialize the reference counter. */
static inline void
refcount_init(struct refcount *r, unsigned int count)
{
    InterlockedExchange(&r->count, (LONG)count);
}

/* Increment the reference counter. */
static inline void
refcount_acquire(struct refcount *r)
{
    InterlockedIncrement(&r->count);
}

/* Decrement the reference counter, returning whether the reference
   dropped to zero. */
static inline bool
refcount_release(struct refcount *r)
{
    return InterlockedDecrement(&r->count) == 0 ? true : false;
}

#else /* else of CONFIG_HAS_STD_ATOMIC */
#error "Reference counter isn't implemented"
#endif /* end of CONFIG_HAS_STD_ATOMIC */

#endif /* end of REFCOUNT_H */
