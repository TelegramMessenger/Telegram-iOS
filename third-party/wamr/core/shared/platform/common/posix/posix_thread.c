/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _GNU_SOURCE
#if !defined(__RTTHREAD__)
#define _GNU_SOURCE
#endif
#endif
#include "platform_api_vmcore.h"
#include "platform_api_extension.h"

#if defined(__APPLE__) || defined(__MACH__)
#include <TargetConditionals.h>
#endif

typedef struct {
    thread_start_routine_t start;
    void *arg;
#ifdef OS_ENABLE_HW_BOUND_CHECK
    os_signal_handler signal_handler;
#endif
} thread_wrapper_arg;

#ifdef OS_ENABLE_HW_BOUND_CHECK
/* The signal handler passed to os_thread_signal_init() */
static os_thread_local_attribute os_signal_handler signal_handler;
#endif

static void *
os_thread_wrapper(void *arg)
{
    thread_wrapper_arg *targ = arg;
    thread_start_routine_t start_func = targ->start;
    void *thread_arg = targ->arg;
#ifdef OS_ENABLE_HW_BOUND_CHECK
    os_signal_handler handler = targ->signal_handler;
#endif

#if 0
    os_printf("THREAD CREATED %jx\n", (uintmax_t)(uintptr_t)pthread_self());
#endif
    BH_FREE(targ);
#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (os_thread_signal_init(handler) != 0)
        return NULL;
#endif
#ifdef OS_ENABLE_WAKEUP_BLOCKING_OP
    os_end_blocking_op();
#endif
#if BH_DEBUG != 0
#if defined __APPLE__
    pthread_setname_np("wamr");
#else
    pthread_setname_np(pthread_self(), "wamr");
#endif
#endif
    start_func(thread_arg);
#ifdef OS_ENABLE_HW_BOUND_CHECK
    os_thread_signal_destroy();
#endif
    return NULL;
}

int
os_thread_create_with_prio(korp_tid *tid, thread_start_routine_t start,
                           void *arg, unsigned int stack_size, int prio)
{
    pthread_attr_t tattr;
    thread_wrapper_arg *targ;

    assert(stack_size > 0);
    assert(tid);
    assert(start);

    pthread_attr_init(&tattr);
    pthread_attr_setdetachstate(&tattr, PTHREAD_CREATE_JOINABLE);
    if (pthread_attr_setstacksize(&tattr, stack_size) != 0) {
        os_printf("Invalid thread stack size %u. "
                  "Min stack size on Linux = %u\n",
                  stack_size, (unsigned int)PTHREAD_STACK_MIN);
        pthread_attr_destroy(&tattr);
        return BHT_ERROR;
    }

    targ = (thread_wrapper_arg *)BH_MALLOC(sizeof(*targ));
    if (!targ) {
        pthread_attr_destroy(&tattr);
        return BHT_ERROR;
    }

    targ->start = start;
    targ->arg = arg;
#ifdef OS_ENABLE_HW_BOUND_CHECK
    targ->signal_handler = signal_handler;
#endif

    if (pthread_create(tid, &tattr, os_thread_wrapper, targ) != 0) {
        pthread_attr_destroy(&tattr);
        BH_FREE(targ);
        return BHT_ERROR;
    }

    pthread_attr_destroy(&tattr);
    return BHT_OK;
}

int
os_thread_create(korp_tid *tid, thread_start_routine_t start, void *arg,
                 unsigned int stack_size)
{
    return os_thread_create_with_prio(tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}

korp_tid
os_self_thread()
{
    return (korp_tid)pthread_self();
}

int
os_mutex_init(korp_mutex *mutex)
{
    return pthread_mutex_init(mutex, NULL) == 0 ? BHT_OK : BHT_ERROR;
}

int
os_recursive_mutex_init(korp_mutex *mutex)
{
    int ret;

    pthread_mutexattr_t mattr;

    assert(mutex);
    ret = pthread_mutexattr_init(&mattr);
    if (ret)
        return BHT_ERROR;

    pthread_mutexattr_settype(&mattr, PTHREAD_MUTEX_RECURSIVE);
    ret = pthread_mutex_init(mutex, &mattr);
    pthread_mutexattr_destroy(&mattr);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int
os_mutex_destroy(korp_mutex *mutex)
{
    int ret;

    assert(mutex);
    ret = pthread_mutex_destroy(mutex);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int
os_mutex_lock(korp_mutex *mutex)
{
    int ret;

    assert(mutex);
    ret = pthread_mutex_lock(mutex);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int
os_mutex_unlock(korp_mutex *mutex)
{
    int ret;

    assert(mutex);
    ret = pthread_mutex_unlock(mutex);

    return ret == 0 ? BHT_OK : BHT_ERROR;
}

int
os_cond_init(korp_cond *cond)
{
    assert(cond);

    if (pthread_cond_init(cond, NULL) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_cond_destroy(korp_cond *cond)
{
    assert(cond);

    if (pthread_cond_destroy(cond) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_cond_wait(korp_cond *cond, korp_mutex *mutex)
{
    assert(cond);
    assert(mutex);

    if (pthread_cond_wait(cond, mutex) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

korp_sem *
os_sem_open(const char *name, int oflags, int mode, int val)
{
    return sem_open(name, oflags, mode, val);
}

int
os_sem_close(korp_sem *sem)
{
    return sem_close(sem);
}

int
os_sem_wait(korp_sem *sem)
{
    return sem_wait(sem);
}

int
os_sem_trywait(korp_sem *sem)
{
    return sem_trywait(sem);
}

int
os_sem_post(korp_sem *sem)
{
    return sem_post(sem);
}

int
os_sem_getvalue(korp_sem *sem, int *sval)
{
#if defined(__APPLE__)
    /*
     * macOS doesn't have working sem_getvalue.
     * It's marked as deprecated in the system header.
     * Mock it up here to avoid compile-time deprecation warnings.
     */
    errno = ENOSYS;
    return -1;
#else
    return sem_getvalue(sem, sval);
#endif
}

int
os_sem_unlink(const char *name)
{
    return sem_unlink(name);
}

static void
msec_nsec_to_abstime(struct timespec *ts, uint64 usec)
{
    struct timeval tv;
    time_t tv_sec_new;
    long int tv_nsec_new;

    gettimeofday(&tv, NULL);

    tv_sec_new = (time_t)(tv.tv_sec + usec / 1000000);
    if (tv_sec_new >= tv.tv_sec) {
        ts->tv_sec = tv_sec_new;
    }
    else {
        /* integer overflow */
        ts->tv_sec = BH_TIME_T_MAX;
        os_printf("Warning: os_cond_reltimedwait exceeds limit, "
                  "set to max timeout instead\n");
    }

    tv_nsec_new = (long int)(tv.tv_usec * 1000 + (usec % 1000000) * 1000);
    if (tv.tv_usec * 1000 >= tv.tv_usec && tv_nsec_new >= tv.tv_usec * 1000) {
        ts->tv_nsec = tv_nsec_new;
    }
    else {
        /* integer overflow */
        ts->tv_nsec = LONG_MAX;
        os_printf("Warning: os_cond_reltimedwait exceeds limit, "
                  "set to max timeout instead\n");
    }

    if (ts->tv_nsec >= 1000000000L && ts->tv_sec < BH_TIME_T_MAX) {
        ts->tv_sec++;
        ts->tv_nsec -= 1000000000L;
    }
}

int
os_cond_reltimedwait(korp_cond *cond, korp_mutex *mutex, uint64 useconds)
{
    int ret;
    struct timespec abstime;

    if (useconds == BHT_WAIT_FOREVER)
        ret = pthread_cond_wait(cond, mutex);
    else {
        msec_nsec_to_abstime(&abstime, useconds);
        ret = pthread_cond_timedwait(cond, mutex, &abstime);
    }

    if (ret != BHT_OK && ret != ETIMEDOUT)
        return BHT_ERROR;

    return ret;
}

int
os_cond_signal(korp_cond *cond)
{
    assert(cond);

    if (pthread_cond_signal(cond) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_cond_broadcast(korp_cond *cond)
{
    assert(cond);

    if (pthread_cond_broadcast(cond) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_rwlock_init(korp_rwlock *lock)
{
    assert(lock);

    if (pthread_rwlock_init(lock, NULL) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_rwlock_rdlock(korp_rwlock *lock)
{
    assert(lock);

    if (pthread_rwlock_rdlock(lock) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_rwlock_wrlock(korp_rwlock *lock)
{
    assert(lock);

    if (pthread_rwlock_wrlock(lock) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_rwlock_unlock(korp_rwlock *lock)
{
    assert(lock);

    if (pthread_rwlock_unlock(lock) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_rwlock_destroy(korp_rwlock *lock)
{
    assert(lock);

    if (pthread_rwlock_destroy(lock) != BHT_OK)
        return BHT_ERROR;

    return BHT_OK;
}

int
os_thread_join(korp_tid thread, void **value_ptr)
{
    return pthread_join(thread, value_ptr);
}

int
os_thread_detach(korp_tid thread)
{
    return pthread_detach(thread);
}

void
os_thread_exit(void *retval)
{
#ifdef OS_ENABLE_HW_BOUND_CHECK
    os_thread_signal_destroy();
#endif
    return pthread_exit(retval);
}

#if defined(os_thread_local_attribute)
static os_thread_local_attribute uint8 *thread_stack_boundary = NULL;
#endif

uint8 *
os_thread_get_stack_boundary()
{
    pthread_t self;
#ifdef __linux__
    pthread_attr_t attr;
    size_t guard_size;
#endif
    uint8 *addr = NULL;
    size_t stack_size, max_stack_size;
    int page_size;

#if defined(os_thread_local_attribute)
    if (thread_stack_boundary)
        return thread_stack_boundary;
#endif

    page_size = getpagesize();
    self = pthread_self();
    max_stack_size =
        (size_t)(APP_THREAD_STACK_SIZE_MAX + page_size - 1) & ~(page_size - 1);

    if (max_stack_size < APP_THREAD_STACK_SIZE_DEFAULT)
        max_stack_size = APP_THREAD_STACK_SIZE_DEFAULT;

#ifdef __linux__
    if (pthread_getattr_np(self, &attr) == 0) {
        pthread_attr_getstack(&attr, (void **)&addr, &stack_size);
        pthread_attr_getguardsize(&attr, &guard_size);
        pthread_attr_destroy(&attr);
        if (stack_size > max_stack_size)
            addr = addr + stack_size - max_stack_size;
        addr += guard_size;
    }
    (void)stack_size;
#elif defined(__APPLE__) || defined(__NuttX__) || defined(__RTTHREAD__)
    if ((addr = (uint8 *)pthread_get_stackaddr_np(self))) {
        stack_size = pthread_get_stacksize_np(self);

        /**
         * Check whether stack_addr is the base or end of the stack,
         * change it to the base if it is the end of stack.
         */
        if (addr <= (uint8 *)&stack_size)
            addr = addr + stack_size;

        if (stack_size > max_stack_size)
            stack_size = max_stack_size;

        addr -= stack_size;
    }
#endif

#if defined(os_thread_local_attribute)
    thread_stack_boundary = addr;
#endif
    return addr;
}

void
os_thread_jit_write_protect_np(bool enabled)
{
#if (defined(__APPLE__) || defined(__MACH__)) && defined(__arm64__) \
    && defined(TARGET_OS_OSX) && TARGET_OS_OSX != 0
    pthread_jit_write_protect_np(enabled);
#endif
}

#ifdef OS_ENABLE_HW_BOUND_CHECK

#define SIG_ALT_STACK_SIZE (32 * 1024)

/**
 * Whether thread signal environment is initialized:
 *   the signal handler is registered, the stack pages are touched,
 *   the stack guard pages are set and signal alternate stack are set.
 */
static os_thread_local_attribute bool thread_signal_inited = false;

#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
/* The signal alternate stack base addr */
static os_thread_local_attribute uint8 *sigalt_stack_base_addr;
/* The previous signal alternate stack */
static os_thread_local_attribute stack_t prev_sigalt_stack;

/*
 * ASAN is not designed to work with custom stack unwind or other low-level
 * things. Ignore a function that does some low-level magic. (e.g. walking
 * through the thread's stack bypassing the frame boundaries)
 */
#if defined(__clang__)
#pragma clang optimize off
__attribute__((no_sanitize_address))
#elif defined(__GNUC__)
#pragma GCC push_options
#pragma GCC optimize("O0")
__attribute__((no_sanitize_address))
#endif
static uint32
touch_pages(uint8 *stack_min_addr, uint32 page_size)
{
    uint8 sum = 0;
    while (1) {
        volatile uint8 *touch_addr = (volatile uint8 *)os_alloca(page_size / 2);
        if (touch_addr < stack_min_addr + page_size) {
            sum += *(stack_min_addr + page_size - 1);
            break;
        }
        *touch_addr = 0;
        sum += *touch_addr;
    }
    return sum;
}
#if defined(__clang__)
#pragma clang optimize on
#elif defined(__GNUC__)
#pragma GCC pop_options
#endif

static bool
init_stack_guard_pages()
{
    uint32 page_size = os_getpagesize();
    uint32 guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    uint8 *stack_min_addr = os_thread_get_stack_boundary();

    if (stack_min_addr == NULL)
        return false;

    /* Touch each stack page to ensure that it has been mapped: the OS
       may lazily grow the stack mapping as a guard page is hit. */
    (void)touch_pages(stack_min_addr, page_size);
    /* First time to call aot function, protect guard pages */
    if (os_mprotect(stack_min_addr, page_size * guard_page_count,
                    MMAP_PROT_NONE)
        != 0) {
        return false;
    }
    return true;
}

static void
destroy_stack_guard_pages()
{
    uint32 page_size = os_getpagesize();
    uint32 guard_page_count = STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT;
    uint8 *stack_min_addr = os_thread_get_stack_boundary();

    os_mprotect(stack_min_addr, page_size * guard_page_count,
                MMAP_PROT_READ | MMAP_PROT_WRITE);
}
#endif /* end of WASM_DISABLE_STACK_HW_BOUND_CHECK == 0 */

/*
 * ASAN is not designed to work with custom stack unwind or other low-level
 * things. Ignore a function that does some low-level magic. (e.g. walking
 * through the thread's stack bypassing the frame boundaries)
 */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((no_sanitize_address))
#endif
static void
mask_signals(int how)
{
    sigset_t set;

    sigemptyset(&set);
    sigaddset(&set, SIGSEGV);
    sigaddset(&set, SIGBUS);
    pthread_sigmask(how, &set, NULL);
}

static struct sigaction prev_sig_act_SIGSEGV;
static struct sigaction prev_sig_act_SIGBUS;

/*
 * ASAN is not designed to work with custom stack unwind or other low-level
 * things. Ignore a function that does some low-level magic. (e.g. walking
 * through the thread's stack bypassing the frame boundaries)
 */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((no_sanitize_address))
#endif
static void
signal_callback(int sig_num, siginfo_t *sig_info, void *sig_ucontext)
{
    void *sig_addr = sig_info->si_addr;
    struct sigaction *prev_sig_act = NULL;

    mask_signals(SIG_BLOCK);

    /* Try to handle signal with the registered signal handler */
    if (signal_handler && (sig_num == SIGSEGV || sig_num == SIGBUS)) {
        signal_handler(sig_addr);
    }

    if (sig_num == SIGSEGV)
        prev_sig_act = &prev_sig_act_SIGSEGV;
    else if (sig_num == SIGBUS)
        prev_sig_act = &prev_sig_act_SIGBUS;

    /* Forward the signal to next handler if found */
    if (prev_sig_act && (prev_sig_act->sa_flags & SA_SIGINFO)) {
        prev_sig_act->sa_sigaction(sig_num, sig_info, sig_ucontext);
    }
    else if (prev_sig_act
             && prev_sig_act->sa_handler
             /* Filter out SIG_DFL and SIG_IGN here, they will
                run into the else branch below */
             && (void *)prev_sig_act->sa_handler != SIG_DFL
             && (void *)prev_sig_act->sa_handler != SIG_IGN) {
        prev_sig_act->sa_handler(sig_num);
    }
    /* Output signal info and then crash if signal is unhandled */
    else {
        switch (sig_num) {
            case SIGSEGV:
                os_printf("unhandled SIGSEGV, si_addr: %p\n", sig_addr);
                break;
            case SIGBUS:
                os_printf("unhandled SIGBUS, si_addr: %p\n", sig_addr);
                break;
            default:
                os_printf("unhandle signal %d, si_addr: %p\n", sig_num,
                          sig_addr);
                break;
        }

        abort();
    }
}

int
os_thread_signal_init(os_signal_handler handler)
{
    struct sigaction sig_act;
#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    stack_t sigalt_stack_info;
    uint32 map_size = SIG_ALT_STACK_SIZE;
    uint8 *map_addr;
#endif

    if (thread_signal_inited)
        return 0;

#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    if (!init_stack_guard_pages()) {
        os_printf("Failed to init stack guard pages\n");
        return -1;
    }

    /* Initialize memory for signal alternate stack of current thread */
    if (!(map_addr = os_mmap(NULL, map_size, MMAP_PROT_READ | MMAP_PROT_WRITE,
                             MMAP_MAP_NONE, os_get_invalid_handle()))) {
        os_printf("Failed to mmap memory for alternate stack\n");
        goto fail1;
    }

    /* Initialize signal alternate stack */
    memset(map_addr, 0, map_size);
    sigalt_stack_info.ss_sp = map_addr;
    sigalt_stack_info.ss_size = map_size;
    sigalt_stack_info.ss_flags = 0;
    memset(&prev_sigalt_stack, 0, sizeof(stack_t));
    /* Set signal alternate stack and save the previous one */
    if (sigaltstack(&sigalt_stack_info, &prev_sigalt_stack) != 0) {
        os_printf("Failed to init signal alternate stack\n");
        goto fail2;
    }
#endif

    memset(&prev_sig_act_SIGSEGV, 0, sizeof(struct sigaction));
    memset(&prev_sig_act_SIGBUS, 0, sizeof(struct sigaction));

    /* Install signal handler */
    sig_act.sa_sigaction = signal_callback;
    sig_act.sa_flags = SA_SIGINFO | SA_NODEFER;
#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    sig_act.sa_flags |= SA_ONSTACK;
#endif
    sigemptyset(&sig_act.sa_mask);
    if (sigaction(SIGSEGV, &sig_act, &prev_sig_act_SIGSEGV) != 0
        || sigaction(SIGBUS, &sig_act, &prev_sig_act_SIGBUS) != 0) {
        os_printf("Failed to register signal handler\n");
        goto fail3;
    }

#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    sigalt_stack_base_addr = map_addr;
#endif

#if defined(os_thread_local_attribute)
    // calculate and cache the new stack boundary.
    // see https://github.com/bytecodealliance/wasm-micro-runtime/issues/3966
    (void)os_thread_get_stack_boundary();
#endif

    signal_handler = handler;
    thread_signal_inited = true;
    return 0;

fail3:
#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    memset(&sigalt_stack_info, 0, sizeof(stack_t));
    sigalt_stack_info.ss_flags = SS_DISABLE;
    sigalt_stack_info.ss_size = map_size;
    sigaltstack(&sigalt_stack_info, NULL);
fail2:
    os_munmap(map_addr, map_size);
fail1:
    destroy_stack_guard_pages();
#endif
    return -1;
}

void
os_thread_signal_destroy()
{
    if (!thread_signal_inited)
        return;

#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
    /* Restore the previous signal alternate stack */
    sigaltstack(&prev_sigalt_stack, NULL);

    os_munmap(sigalt_stack_base_addr, SIG_ALT_STACK_SIZE);

    destroy_stack_guard_pages();
#endif

    thread_signal_inited = false;
}

bool
os_thread_signal_inited()
{
    return thread_signal_inited;
}

void
os_signal_unmask()
{
    mask_signals(SIG_UNBLOCK);
}

void
os_sigreturn()
{
#if WASM_DISABLE_STACK_HW_BOUND_CHECK == 0
#if defined(__APPLE__)
#define UC_RESET_ALT_STACK 0x80000000
    extern int __sigreturn(void *, int);

    /* It's necessary to call __sigreturn to restore the sigaltstack state
       after exiting the signal handler. */
    __sigreturn(NULL, UC_RESET_ALT_STACK);
#endif
#endif
}
#endif /* end of OS_ENABLE_HW_BOUND_CHECK */
