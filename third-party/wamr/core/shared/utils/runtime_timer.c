/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "runtime_timer.h"

#if 1
#define PRINT(...) (void)0
#else
#define PRINT printf
#endif

typedef struct _app_timer {
    struct _app_timer *next;
    uint32 id;
    uint32 interval;
    uint64 expiry;
    bool is_periodic;
} app_timer_t;

struct _timer_ctx {
    app_timer_t *app_timers;
    app_timer_t *idle_timers;
    app_timer_t *free_timers;
    uint32 max_timer_id;
    int pre_allocated;
    uint32 owner;

    /* mutex and condition */
    korp_cond cond;
    korp_mutex mutex;

    timer_callback_f timer_callback;
    check_timer_expiry_f refresh_checker;
};

uint64
bh_get_tick_ms()
{
    return os_time_get_boot_us() / 1000;
}

uint32
bh_get_elpased_ms(uint32 *last_system_clock)
{
    uint32 elapsed_ms;
    /* attention: the bh_get_tick_ms() returns a 64-bit integer, but
       bh_get_elpased_ms() is designed to use a 32-bit clock count */
    uint32 now = (uint32)bh_get_tick_ms();

    /* system clock overrun */
    if (now < *last_system_clock) {
        PRINT("system clock overrun!\n");
        elapsed_ms = now + (UINT32_MAX - *last_system_clock) + 1;
    }
    else {
        elapsed_ms = now - *last_system_clock;
    }

    *last_system_clock = now;
    return elapsed_ms;
}

static app_timer_t *
remove_timer_from(timer_ctx_t ctx, uint32 timer_id, bool active_list)
{
    app_timer_t **head, *prev, *t;

    os_mutex_lock(&ctx->mutex);

    if (active_list)
        head = &ctx->app_timers;
    else
        head = &ctx->idle_timers;

    t = *head;
    prev = NULL;

    while (t) {
        if (t->id == timer_id) {
            if (prev == NULL) {
                *head = t->next;
                PRINT("removed timer [%d] at head from list %d\n", t->id,
                      active_list);
            }
            else {
                prev->next = t->next;
                PRINT("removed timer [%d] after [%d] from list %d\n", t->id,
                      prev->id, active_list);
            }
            os_mutex_unlock(&ctx->mutex);

            if (active_list && prev == NULL && ctx->refresh_checker)
                ctx->refresh_checker(ctx);
            return t;
        }
        else {
            prev = t;
            t = t->next;
        }
    }

    os_mutex_unlock(&ctx->mutex);
    return NULL;
}

static app_timer_t *
remove_timer(timer_ctx_t ctx, uint32 timer_id, bool *active)
{
    app_timer_t *t = remove_timer_from(ctx, timer_id, true);

    if (t) {
        if (active)
            *active = true;
        return t;
    }

    if (active)
        *active = false;
    return remove_timer_from(ctx, timer_id, false);
}

static void
reschedule_timer(timer_ctx_t ctx, app_timer_t *timer)
{
    app_timer_t *t;
    app_timer_t *prev = NULL;

    os_mutex_lock(&ctx->mutex);

    t = ctx->app_timers;
    timer->next = NULL;
    timer->expiry = bh_get_tick_ms() + timer->interval;

    while (t) {
        if (timer->expiry < t->expiry) {
            if (prev == NULL) {
                timer->next = ctx->app_timers;
                ctx->app_timers = timer;
                PRINT("rescheduled timer [%d] at head\n", timer->id);
            }
            else {
                timer->next = t;
                prev->next = timer;
                PRINT("rescheduled timer [%d] after [%d]\n", timer->id,
                      prev->id);
            }

            goto out;
        }
        else {
            prev = t;
            t = t->next;
        }
    }

    if (prev) {
        /* insert to the list end */
        prev->next = timer;
        PRINT("rescheduled timer [%d] at end, after [%d]\n", timer->id,
              prev->id);
    }
    else {
        /* insert at the beginning */
        bh_assert(ctx->app_timers == NULL);
        ctx->app_timers = timer;
        PRINT("rescheduled timer [%d] as first\n", timer->id);
    }

out:
    os_mutex_unlock(&ctx->mutex);

    /* ensure the refresh_checker() is called out of the lock */
    if (prev == NULL && ctx->refresh_checker)
        ctx->refresh_checker(ctx);
}

static void
release_timer(timer_ctx_t ctx, app_timer_t *t)
{
    if (ctx->pre_allocated) {
        os_mutex_lock(&ctx->mutex);
        t->next = ctx->free_timers;
        ctx->free_timers = t;
        PRINT("recycle timer :%d\n", t->id);
        os_mutex_unlock(&ctx->mutex);
    }
    else {
        PRINT("destroy timer :%d\n", t->id);
        BH_FREE(t);
    }
}

void
release_timer_list(app_timer_t **p_list)
{
    app_timer_t *t = *p_list;

    while (t) {
        app_timer_t *next = t->next;
        PRINT("destroy timer list:%d\n", t->id);
        BH_FREE(t);
        t = next;
    }

    *p_list = NULL;
}

/*
 * API exposed
 */

timer_ctx_t
create_timer_ctx(timer_callback_f timer_handler,
                 check_timer_expiry_f expiry_checker, int prealloc_num,
                 unsigned int owner)
{
    timer_ctx_t ctx = (timer_ctx_t)BH_MALLOC(sizeof(struct _timer_ctx));

    if (ctx == NULL)
        return NULL;

    memset(ctx, 0, sizeof(struct _timer_ctx));

    ctx->timer_callback = timer_handler;
    ctx->pre_allocated = prealloc_num;
    ctx->refresh_checker = expiry_checker;
    ctx->owner = owner;

    while (prealloc_num > 0) {
        app_timer_t *timer = (app_timer_t *)BH_MALLOC(sizeof(app_timer_t));

        if (timer == NULL)
            goto cleanup;

        memset(timer, 0, sizeof(*timer));
        timer->next = ctx->free_timers;
        ctx->free_timers = timer;
        prealloc_num--;
    }

    if (os_cond_init(&ctx->cond) != 0)
        goto cleanup;

    if (os_mutex_init(&ctx->mutex) != 0) {
        os_cond_destroy(&ctx->cond);
        goto cleanup;
    }

    PRINT("timer ctx created. pre-alloc: %d\n", ctx->pre_allocated);
    return ctx;

cleanup:
    if (ctx) {
        release_timer_list(&ctx->free_timers);
        BH_FREE(ctx);
    }
    PRINT("timer ctx create failed\n");
    return NULL;
}

void
destroy_timer_ctx(timer_ctx_t ctx)
{
    while (ctx->free_timers) {
        void *tmp = ctx->free_timers;
        ctx->free_timers = ctx->free_timers->next;
        BH_FREE(tmp);
    }

    cleanup_app_timers(ctx);

    os_cond_destroy(&ctx->cond);
    os_mutex_destroy(&ctx->mutex);
    BH_FREE(ctx);
}

unsigned int
timer_ctx_get_owner(timer_ctx_t ctx)
{
    return ctx->owner;
}

void
add_idle_timer(timer_ctx_t ctx, app_timer_t *timer)
{
    os_mutex_lock(&ctx->mutex);
    timer->next = ctx->idle_timers;
    ctx->idle_timers = timer;
    os_mutex_unlock(&ctx->mutex);
}

uint32
sys_create_timer(timer_ctx_t ctx, int interval, bool is_period, bool auto_start)
{
    app_timer_t *timer;

    if (ctx->pre_allocated) {
        if (ctx->free_timers == NULL) {
            return (uint32)-1;
        }
        else {
            timer = ctx->free_timers;
            ctx->free_timers = timer->next;
        }
    }
    else {
        timer = (app_timer_t *)BH_MALLOC(sizeof(app_timer_t));
        if (timer == NULL)
            return (uint32)-1;
    }

    memset(timer, 0, sizeof(*timer));

    ctx->max_timer_id++;
    if (ctx->max_timer_id == (uint32)-1)
        ctx->max_timer_id++;
    timer->id = ctx->max_timer_id;
    timer->interval = (uint32)interval;
    timer->is_periodic = is_period;

    if (auto_start)
        reschedule_timer(ctx, timer);
    else
        add_idle_timer(ctx, timer);

    return timer->id;
}

bool
sys_timer_cancel(timer_ctx_t ctx, uint32 timer_id)
{
    bool from_active;
    app_timer_t *t = remove_timer(ctx, timer_id, &from_active);

    if (t == NULL)
        return false;

    add_idle_timer(ctx, t);

    PRINT("sys_timer_stop called\n");
    return from_active;
}

bool
sys_timer_destroy(timer_ctx_t ctx, uint32 timer_id)
{
    bool from_active;
    app_timer_t *t = remove_timer(ctx, timer_id, &from_active);

    if (t == NULL)
        return false;

    release_timer(ctx, t);

    PRINT("sys_timer_destroy called\n");
    return true;
}

bool
sys_timer_restart(timer_ctx_t ctx, uint32 timer_id, int interval)
{
    app_timer_t *t = remove_timer(ctx, timer_id, NULL);

    if (t == NULL)
        return false;

    t->interval = (uint32)interval;

    reschedule_timer(ctx, t);

    PRINT("sys_timer_restart called\n");
    return true;
}

/*
 * API called by the timer manager from another thread or the kernel timer
 * handler
 */

/**
 * lookup the app queue by the module name
 * post a timeout message to the app queue
 */
static void
handle_expired_timers(timer_ctx_t ctx, app_timer_t *expired)
{
    while (expired) {
        app_timer_t *t = expired;
        ctx->timer_callback(t->id, ctx->owner);

        /* get next expired timer first, since the following
           operation may change expired->next */
        expired = expired->next;
        if (t->is_periodic) {
            /* if it is repeating, then reschedule it */
            reschedule_timer(ctx, t);
        }
        else {
            /* else move it to idle list */
            add_idle_timer(ctx, t);
        }
    }
}

uint32
get_expiry_ms(timer_ctx_t ctx)
{
    uint32 ms_to_next_expiry;
    uint64 now = bh_get_tick_ms();

    os_mutex_lock(&ctx->mutex);
    if (ctx->app_timers == NULL)
        ms_to_next_expiry = (uint32)-1;
    else if (ctx->app_timers->expiry >= now)
        ms_to_next_expiry = (uint32)(ctx->app_timers->expiry - now);
    else
        ms_to_next_expiry = 0;
    os_mutex_unlock(&ctx->mutex);

    return ms_to_next_expiry;
}

uint32
check_app_timers(timer_ctx_t ctx)
{
    app_timer_t *t, *expired = NULL, *expired_end = NULL;
    uint64 now = bh_get_tick_ms();

    os_mutex_lock(&ctx->mutex);

    t = ctx->app_timers;
    while (t) {
        if (now >= t->expiry) {
            ctx->app_timers = t->next;

            /* append t to the end of expired list */
            t->next = NULL;
            if (!expired_end) {
                expired = expired_end = t;
            }
            else {
                expired_end->next = t;
                expired_end = t;
            }

            t = ctx->app_timers;
        }
        else {
            break;
        }
    }
    os_mutex_unlock(&ctx->mutex);

    handle_expired_timers(ctx, expired);
    return get_expiry_ms(ctx);
}

void
cleanup_app_timers(timer_ctx_t ctx)
{
    os_mutex_lock(&ctx->mutex);

    release_timer_list(&ctx->app_timers);
    release_timer_list(&ctx->idle_timers);

    os_mutex_unlock(&ctx->mutex);
}
