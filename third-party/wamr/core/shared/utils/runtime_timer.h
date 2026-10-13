/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef LIB_BASE_RUNTIME_TIMER_H_
#define LIB_BASE_RUNTIME_TIMER_H_

#include "bh_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

uint64
bh_get_tick_ms(void);
uint32
bh_get_elpased_ms(uint32 *last_system_clock);

struct _timer_ctx;
typedef struct _timer_ctx *timer_ctx_t;
typedef void (*timer_callback_f)(unsigned int id, unsigned int owner);
typedef void (*check_timer_expiry_f)(timer_ctx_t ctx);

timer_ctx_t
create_timer_ctx(timer_callback_f timer_handler, check_timer_expiry_f,
                 int prealloc_num, unsigned int owner);
void destroy_timer_ctx(timer_ctx_t);
unsigned int
timer_ctx_get_owner(timer_ctx_t ctx);

uint32
sys_create_timer(timer_ctx_t ctx, int interval, bool is_period,
                 bool auto_start);
bool
sys_timer_destroy(timer_ctx_t ctx, uint32 timer_id);
bool
sys_timer_cancel(timer_ctx_t ctx, uint32 timer_id);
bool
sys_timer_restart(timer_ctx_t ctx, uint32 timer_id, int interval);
void
cleanup_app_timers(timer_ctx_t ctx);
uint32
check_app_timers(timer_ctx_t ctx);
uint32
get_expiry_ms(timer_ctx_t ctx);

#ifdef __cplusplus
}
#endif
#endif /* LIB_BASE_RUNTIME_TIMER_H_ */
