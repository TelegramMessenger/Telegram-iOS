/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "bh_queue.h"

typedef struct bh_queue_node {
    struct bh_queue_node *next;
    struct bh_queue_node *prev;
    unsigned short tag;
    unsigned int len;
    void *body;
    bh_msg_cleaner msg_cleaner;
} bh_queue_node;

struct bh_queue {
    bh_queue_mutex queue_lock;
    bh_queue_cond queue_wait_cond;
    unsigned int cnt;
    unsigned int max;
    unsigned int drops;
    bh_queue_node *head;
    bh_queue_node *tail;

    bool exit_loop_run;
};

char *
bh_message_payload(bh_message_t message)
{
    return message->body;
}

uint32
bh_message_payload_len(bh_message_t message)
{
    return message->len;
}

int
bh_message_type(bh_message_t message)
{
    return message->tag;
}

bh_queue *
bh_queue_create()
{
    int ret;
    bh_queue *queue = bh_queue_malloc(sizeof(bh_queue));

    if (queue) {
        memset(queue, 0, sizeof(bh_queue));
        queue->max = DEFAULT_QUEUE_LENGTH;

        ret = bh_queue_mutex_init(&queue->queue_lock);
        if (ret != 0) {
            bh_queue_free(queue);
            return NULL;
        }

        ret = bh_queue_cond_init(&queue->queue_wait_cond);
        if (ret != 0) {
            bh_queue_mutex_destroy(&queue->queue_lock);
            bh_queue_free(queue);
            return NULL;
        }
    }

    return queue;
}

void
bh_queue_destroy(bh_queue *queue)
{
    bh_queue_node *node;

    if (!queue)
        return;

    bh_queue_mutex_lock(&queue->queue_lock);
    while (queue->head) {
        node = queue->head;
        queue->head = node->next;

        bh_free_msg(node);
    }
    bh_queue_mutex_unlock(&queue->queue_lock);

    bh_queue_cond_destroy(&queue->queue_wait_cond);
    bh_queue_mutex_destroy(&queue->queue_lock);
    bh_queue_free(queue);
}

bool
bh_post_msg2(bh_queue *queue, bh_queue_node *msg)
{
    if (queue->cnt >= queue->max) {
        queue->drops++;
        bh_free_msg(msg);
        return false;
    }

    bh_queue_mutex_lock(&queue->queue_lock);

    if (queue->cnt == 0) {
        bh_assert(queue->head == NULL);
        bh_assert(queue->tail == NULL);
        queue->head = queue->tail = msg;
        msg->next = msg->prev = NULL;
        queue->cnt = 1;

        bh_queue_cond_signal(&queue->queue_wait_cond);
    }
    else {
        msg->next = NULL;
        msg->prev = queue->tail;
        queue->tail->next = msg;
        queue->tail = msg;
        queue->cnt++;
    }

    bh_queue_mutex_unlock(&queue->queue_lock);

    return true;
}

bool
bh_post_msg(bh_queue *queue, unsigned short tag, void *body, unsigned int len)
{
    bh_queue_node *msg = bh_new_msg(tag, body, len, NULL);
    if (msg == NULL) {
        queue->drops++;
        if (len != 0 && body)
            BH_FREE(body);
        return false;
    }

    if (!bh_post_msg2(queue, msg)) {
        // bh_post_msg2 already freed the msg for failure
        return false;
    }

    return true;
}

bh_queue_node *
bh_new_msg(unsigned short tag, void *body, unsigned int len, void *handler)
{
    bh_queue_node *msg =
        (bh_queue_node *)bh_queue_malloc(sizeof(bh_queue_node));
    if (msg == NULL)
        return NULL;
    memset(msg, 0, sizeof(bh_queue_node));
    msg->len = len;
    msg->body = body;
    msg->tag = tag;
    msg->msg_cleaner = (bh_msg_cleaner)handler;

    return msg;
}

void
bh_free_msg(bh_queue_node *msg)
{
    if (msg->msg_cleaner) {
        msg->msg_cleaner(msg->body);
        bh_queue_free(msg);
        return;
    }

    // note: sometimes we just use the payload pointer for an integer value
    //       len!=0 is the only indicator about the body is an allocated buffer.
    if (msg->body && msg->len)
        bh_queue_free(msg->body);

    bh_queue_free(msg);
}

bh_message_t
bh_get_msg(bh_queue *queue, uint64 timeout_us)
{
    bh_queue_node *msg = NULL;
    bh_queue_mutex_lock(&queue->queue_lock);

    if (queue->cnt == 0) {
        bh_assert(queue->head == NULL);
        bh_assert(queue->tail == NULL);

        if (timeout_us == 0) {
            bh_queue_mutex_unlock(&queue->queue_lock);
            return NULL;
        }

        bh_queue_cond_timedwait(&queue->queue_wait_cond, &queue->queue_lock,
                                timeout_us);
    }

    if (queue->cnt == 0) {
        bh_assert(queue->head == NULL);
        bh_assert(queue->tail == NULL);
    }
    else if (queue->cnt == 1) {
        bh_assert(queue->head == queue->tail);

        msg = queue->head;
        queue->head = queue->tail = NULL;
        queue->cnt = 0;
    }
    else {
        msg = queue->head;
        queue->head = queue->head->next;
        queue->head->prev = NULL;
        queue->cnt--;
    }

    bh_queue_mutex_unlock(&queue->queue_lock);

    return msg;
}

unsigned
bh_queue_get_message_count(bh_queue *queue)
{
    if (!queue)
        return 0;

    return queue->cnt;
}

void
bh_queue_enter_loop_run(bh_queue *queue, bh_queue_handle_msg_callback handle_cb,
                        void *arg)
{
    if (!queue)
        return;

    while (!queue->exit_loop_run) {
        bh_queue_node *message = bh_get_msg(queue, BHT_WAIT_FOREVER);

        if (message) {
            handle_cb(message, arg);
            bh_free_msg(message);
        }
    }
}

void
bh_queue_exit_loop_run(bh_queue *queue)
{
    if (queue) {
        queue->exit_loop_run = true;
        bh_queue_cond_signal(&queue->queue_wait_cond);
    }
}
