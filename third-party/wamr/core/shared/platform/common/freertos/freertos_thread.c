/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "platform_api_vmcore.h"
#include "platform_api_extension.h"

/* clang-format off */
#define bh_assert(v) do {                                   \
    if (!(v)) {                                             \
        int _count = 1;                                     \
        os_printf("\nASSERTION FAILED: %s, at %s, line %d\n",\
                  #v, __FILE__, __LINE__);                  \
        /* divived by 0 to make it abort */                 \
        os_printf("%d\n", _count / (_count - 1));           \
        while (1);                                          \
    }                                                       \
} while (0)
/* clang-format on */

struct os_thread_data;
typedef struct os_thread_wait_node {
    /* Binary semaphore */
    SemaphoreHandle_t sem;
    os_thread_wait_list next;
} os_thread_wait_node;

typedef struct os_thread_data {
    /* Next thread data */
    struct os_thread_data *next;
    /* Thread handle */
    TaskHandle_t handle;
    /* Thread start routine */
    thread_start_routine_t start_routine;
    /* Thread start routine argument */
    void *arg;
    /* Thread local root */
    void *tlr;
    /* Wait node of current thread */
    os_thread_wait_node wait_node;
    /* Lock for waiting list */
    SemaphoreHandle_t wait_list_lock;
    /* Waiting list of other threads who are joining this thread */
    os_thread_wait_list thread_wait_list;
} os_thread_data;

static bool is_thread_sys_inited = false;

/* Lock for thread data list */
static SemaphoreHandle_t thread_data_lock;

/* Thread data list */
static os_thread_data *thread_data_list = NULL;
/* Thread data of supervisor thread */
static os_thread_data supervisor_thread_data;

/* Thread name index */
static int thread_name_index;

static void
thread_data_list_add(os_thread_data *thread_data)
{
    xSemaphoreTake(thread_data_lock, portMAX_DELAY);
    if (!thread_data_list)
        thread_data_list = thread_data;
    else {
        /* If already in list, just return */
        os_thread_data *p = thread_data_list;
        while (p) {
            if (p == thread_data) {
                xSemaphoreGive(thread_data_lock);
                return;
            }
            p = p->next;
        }

        /* Set as head of list */
        thread_data->next = thread_data_list;
        thread_data_list = thread_data;
    }
    xSemaphoreGive(thread_data_lock);
}

static void
thread_data_list_remove(os_thread_data *thread_data)
{
    xSemaphoreTake(thread_data_lock, portMAX_DELAY);
    if (thread_data_list) {
        if (thread_data_list == thread_data)
            thread_data_list = thread_data_list->next;
        else {
            /* Search and remove it from list */
            os_thread_data *p = thread_data_list;
            while (p && p->next != thread_data)
                p = p->next;
            if (p && p->next == thread_data)
                p->next = p->next->next;
        }
    }
    xSemaphoreGive(thread_data_lock);
}

static os_thread_data *
thread_data_list_lookup(TaskHandle_t handle)
{
    xSemaphoreTake(thread_data_lock, portMAX_DELAY);
    if (thread_data_list) {
        os_thread_data *p = thread_data_list;
        while (p) {
            if (p->handle == handle) {
                /* Found */
                xSemaphoreGive(thread_data_lock);
                return p;
            }
            p = p->next;
        }
    }
    xSemaphoreGive(thread_data_lock);
    return NULL;
}

int
os_thread_sys_init()
{
    if (is_thread_sys_inited)
        return BHT_OK;

    if (!(thread_data_lock = xSemaphoreCreateMutex()))
        return BHT_ERROR;

    /* Initialize supervisor thread data */
    memset(&supervisor_thread_data, 0, sizeof(supervisor_thread_data));

    if (!(supervisor_thread_data.wait_node.sem = xSemaphoreCreateBinary())) {
        vSemaphoreDelete(thread_data_lock);
        return BHT_ERROR;
    }

    supervisor_thread_data.handle = xTaskGetCurrentTaskHandle();
    /* Set as head of thread data list */
    thread_data_list = &supervisor_thread_data;

    is_thread_sys_inited = true;
    return BHT_OK;
}

void
os_thread_sys_destroy()
{
    if (is_thread_sys_inited) {
        vSemaphoreDelete(supervisor_thread_data.wait_node.sem);
        vSemaphoreDelete(thread_data_lock);
        is_thread_sys_inited = false;
    }
}

static os_thread_data *
thread_data_current()
{
    TaskHandle_t handle = xTaskGetCurrentTaskHandle();
    return thread_data_list_lookup(handle);
}

static void
os_thread_cleanup(void)
{
    os_thread_data *thread_data = thread_data_current();
    os_thread_wait_list thread_wait_list;
    SemaphoreHandle_t wait_list_lock;
    SemaphoreHandle_t wait_node_sem;

    bh_assert(thread_data != NULL);
    wait_list_lock = thread_data->wait_list_lock;
    thread_wait_list = thread_data->thread_wait_list;
    wait_node_sem = thread_data->wait_node.sem;

    xSemaphoreTake(wait_list_lock, portMAX_DELAY);
    if (thread_wait_list) {
        /* Signal each joining thread */
        os_thread_wait_list head = thread_wait_list;
        while (head) {
            os_thread_wait_list next = head->next;
            xSemaphoreGive(head->sem);
            head = next;
        }
    }
    xSemaphoreGive(wait_list_lock);

    /* Free sem and lock */
    vSemaphoreDelete(wait_node_sem);
    vSemaphoreDelete(wait_list_lock);

    thread_data_list_remove(thread_data);
    BH_FREE(thread_data);
}

static void
os_thread_wrapper(void *arg)
{
    os_thread_data *thread_data = arg;

    thread_data->handle = xTaskGetCurrentTaskHandle();
    thread_data_list_add(thread_data);

    thread_data->start_routine(thread_data->arg);
    os_thread_exit(NULL);
}

int
os_thread_create(korp_tid *p_tid, thread_start_routine_t start, void *arg,
                 unsigned int stack_size)
{
    return os_thread_create_with_prio(p_tid, start, arg, stack_size,
                                      BH_THREAD_DEFAULT_PRIORITY);
}

int
os_thread_create_with_prio(korp_tid *p_tid, thread_start_routine_t start,
                           void *arg, unsigned int stack_size, int prio)
{
    os_thread_data *thread_data;
    char thread_name[32];

    if (!p_tid || !stack_size)
        return BHT_ERROR;

    /* Create and initialize thread data */
    if (!(thread_data = BH_MALLOC(sizeof(os_thread_data))))
        return BHT_ERROR;

    memset(thread_data, 0, sizeof(os_thread_data));

    thread_data->start_routine = start;
    thread_data->arg = arg;

    if (!(thread_data->wait_node.sem = xSemaphoreCreateBinary()))
        goto fail1;

    if (!(thread_data->wait_list_lock = xSemaphoreCreateMutex()))
        goto fail2;

    snprintf(thread_name, sizeof(thread_name), "%s%d", "wasm-thread-",
             ++thread_name_index);

    /* Create the thread */
    if (pdPASS
        != xTaskCreate(os_thread_wrapper, thread_name, stack_size / 4,
                       thread_data, prio, &thread_data->handle))
        goto fail3;

    thread_data_list_add(thread_data);
    *p_tid = thread_data->handle;
    return BHT_OK;

fail3:
    vSemaphoreDelete(thread_data->wait_list_lock);
fail2:
    vSemaphoreDelete(thread_data->wait_node.sem);
fail1:
    BH_FREE(thread_data);
    return BHT_ERROR;
}

korp_tid
os_self_thread()
{
    return xTaskGetCurrentTaskHandle();
}

int
os_thread_join(korp_tid thread, void **value_ptr)
{
    os_thread_data *thread_data, *curr_thread_data;
    TaskHandle_t handle = thread;

    (void)value_ptr;

    /* Get thread data of current thread */
    curr_thread_data = thread_data_current();
    curr_thread_data->wait_node.next = NULL;

    /* Get thread data */
    thread_data = thread_data_list_lookup(handle);

    xSemaphoreTake(thread_data->wait_list_lock, portMAX_DELAY);
    if (!thread_data->thread_wait_list)
        thread_data->thread_wait_list = &curr_thread_data->wait_node;
    else {
        /* Add to end of waiting list */
        os_thread_wait_node *p = thread_data->thread_wait_list;
        while (p->next)
            p = p->next;
        p->next = &curr_thread_data->wait_node;
    }
    xSemaphoreGive(thread_data->wait_list_lock);

    /* Wait the sem */
    xSemaphoreTake(curr_thread_data->wait_node.sem, portMAX_DELAY);
    return BHT_OK;
}

int
os_thread_detach(korp_tid thread)
{
    /* Do nothing */
    (void)thread;
    return BHT_OK;
}

void
os_thread_exit(void *retval)
{
    (void)retval;
    os_thread_cleanup();
    vTaskDelete(NULL);
}

int
os_mutex_init(korp_mutex *mutex)
{
    SemaphoreHandle_t semaphore;

    if (!(semaphore = xSemaphoreCreateMutex()))
        return BHT_ERROR;
    mutex->sem = semaphore;
    mutex->is_recursive = false;
    return BHT_OK;
}

int
os_recursive_mutex_init(korp_mutex *mutex)
{
    SemaphoreHandle_t semaphore;

    if (!(semaphore = xSemaphoreCreateRecursiveMutex()))
        return BHT_ERROR;
    mutex->sem = semaphore;
    mutex->is_recursive = true;
    return BHT_OK;
}

int
os_mutex_destroy(korp_mutex *mutex)
{
    vSemaphoreDelete(mutex->sem);
    return BHT_OK;
}

int
os_mutex_lock(korp_mutex *mutex)
{
    int ret = -1;

    if (!mutex->is_recursive)
        ret = xSemaphoreTake(mutex->sem, portMAX_DELAY);
    else
        ret = xSemaphoreTakeRecursive(mutex->sem, portMAX_DELAY);
    return ret == pdPASS ? BHT_OK : BHT_ERROR;
}

int
os_mutex_unlock(korp_mutex *mutex)
{
    int ret = -1;

    if (!mutex->is_recursive)
        ret = xSemaphoreGive(mutex->sem);
    else
        ret = xSemaphoreGiveRecursive(mutex->sem);
    return ret == pdPASS ? BHT_OK : BHT_ERROR;
}

int
os_cond_init(korp_cond *cond)
{
    if (!(cond->wait_list_lock = xSemaphoreCreateMutex()))
        return BHT_ERROR;

    cond->thread_wait_list = NULL;
    return BHT_OK;
}

int
os_cond_destroy(korp_cond *cond)
{
    vSemaphoreDelete(cond->wait_list_lock);
    return BHT_OK;
}

static int
os_cond_wait_internal(korp_cond *cond, korp_mutex *mutex, bool timed, int mills)
{
    os_thread_wait_node *node = &thread_data_current()->wait_node;

    node->next = NULL;

    xSemaphoreTake(cond->wait_list_lock, portMAX_DELAY);
    if (!cond->thread_wait_list)
        cond->thread_wait_list = node;
    else {
        /* Add to end of wait list */
        os_thread_wait_node *p = cond->thread_wait_list;
        while (p->next)
            p = p->next;
        p->next = node;
    }
    xSemaphoreGive(cond->wait_list_lock);

    /* Unlock mutex, wait sem and lock mutex again */
    os_mutex_unlock(mutex);
    xSemaphoreTake(node->sem, timed ? mills / portTICK_RATE_MS : portMAX_DELAY);
    os_mutex_lock(mutex);

    /* Remove wait node from wait list */
    xSemaphoreTake(cond->wait_list_lock, portMAX_DELAY);
    if (cond->thread_wait_list == node)
        cond->thread_wait_list = node->next;
    else {
        /* Remove from the wait list */
        os_thread_wait_node *p = cond->thread_wait_list;
        while (p->next != node)
            p = p->next;
        p->next = node->next;
    }
    xSemaphoreGive(cond->wait_list_lock);

    return BHT_OK;
}

int
os_cond_wait(korp_cond *cond, korp_mutex *mutex)
{
    return os_cond_wait_internal(cond, mutex, false, 0);
}

int
os_cond_reltimedwait(korp_cond *cond, korp_mutex *mutex, uint64 useconds)
{
    if (useconds == BHT_WAIT_FOREVER) {
        return os_cond_wait_internal(cond, mutex, false, 0);
    }
    else {
        uint64 mills_64 = useconds / 1000;
        int32 mills;

        if (mills_64 < (uint64)INT32_MAX) {
            mills = (int32)mills_64;
        }
        else {
            mills = INT32_MAX;
            os_printf("Warning: os_cond_reltimedwait exceeds limit, "
                      "set to max timeout instead\n");
        }
        return os_cond_wait_internal(cond, mutex, true, mills);
    }
}

int
os_cond_signal(korp_cond *cond)
{
    /* Signal the head wait node of wait list */
    xSemaphoreTake(cond->wait_list_lock, portMAX_DELAY);
    if (cond->thread_wait_list)
        xSemaphoreGive(cond->thread_wait_list->sem);
    xSemaphoreGive(cond->wait_list_lock);

    return BHT_OK;
}

int
os_cond_broadcast(korp_cond *cond)
{
    /* Signal all of the wait node of wait list */
    xSemaphoreTake(cond->wait_list_lock, portMAX_DELAY);
    if (cond->thread_wait_list) {
        os_thread_wait_node *p = cond->thread_wait_list;
        while (p) {
            xSemaphoreGive(p->sem);
            p = p->next;
        }
    }
    xSemaphoreGive(cond->wait_list_lock);

    return BHT_OK;
}

uint8 *
os_thread_get_stack_boundary()
{
    /* TODO: get freertos stack boundary */
    return NULL;
}

void
os_thread_jit_write_protect_np(bool enabled)
{
    (void)enabled;
}
