/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _BH_QUEUE_H
#define _BH_QUEUE_H

#ifdef __cplusplus
extern "C" {
#endif

#include "bh_platform.h"

struct bh_queue_node;
typedef struct bh_queue_node *bh_message_t;
struct bh_queue;
typedef struct bh_queue bh_queue;

typedef void (*bh_queue_handle_msg_callback)(void *message, void *arg);

#define bh_queue_malloc BH_MALLOC
#define bh_queue_free BH_FREE

#define bh_queue_mutex korp_mutex
#define bh_queue_cond korp_cond

#define bh_queue_mutex_init os_mutex_init
#define bh_queue_mutex_destroy os_mutex_destroy
#define bh_queue_mutex_lock os_mutex_lock
#define bh_queue_mutex_unlock os_mutex_unlock

#define bh_queue_cond_init os_cond_init
#define bh_queue_cond_destroy os_cond_destroy
#define bh_queue_cond_wait os_cond_wait
#define bh_queue_cond_timedwait os_cond_reltimedwait
#define bh_queue_cond_signal os_cond_signal
#define bh_queue_cond_broadcast os_cond_broadcast

typedef void (*bh_msg_cleaner)(void *msg);

bh_queue *
bh_queue_create(void);

void
bh_queue_destroy(bh_queue *queue);

char *
bh_message_payload(bh_message_t message);
uint32
bh_message_payload_len(bh_message_t message);
int
bh_message_type(bh_message_t message);

bh_message_t
bh_new_msg(unsigned short tag, void *body, unsigned int len, void *handler);
void
bh_free_msg(bh_message_t msg);
bool
bh_post_msg(bh_queue *queue, unsigned short tag, void *body, unsigned int len);
bool
bh_post_msg2(bh_queue *queue, bh_message_t msg);

bh_message_t
bh_get_msg(bh_queue *queue, uint64 timeout_us);

unsigned
bh_queue_get_message_count(bh_queue *queue);

void
bh_queue_enter_loop_run(bh_queue *queue, bh_queue_handle_msg_callback handle_cb,
                        void *arg);
void
bh_queue_exit_loop_run(bh_queue *queue);

#ifdef __cplusplus
}
#endif

#endif /* #ifndef _BH_QUEUE_H */
