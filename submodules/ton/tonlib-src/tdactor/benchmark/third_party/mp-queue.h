/*
    This file is part of KittenDB-Engine Library.

    KittenDB-Engine Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    KittenDB-Engine Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with KittenDB-Engine Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2014 Telegraph Inc
              2014 Nikolai Durov
              2014 Andrey Lopatin
*/

#ifndef __KDB_MP_QUEUE_H__
#define __KDB_MP_QUEUE_H__

#define MPQ_USE_POSIX_SEMAPHORES 0

#if MPQ_USE_POSIX_SEMAPHORES
#include <semaphore.h>
#endif

typedef struct mp_semaphore {
  volatile int value;
  volatile int waiting;
} mp_sem_t;

#define THREAD_HPTRS 21

#define MPQ_SMALL_BLOCK_SIZE 64
#define MPQ_BLOCK_SIZE 4096  // must be a power of 2
#define MPQ_BLOCK_ALIGNMENT 64

#ifdef _LP64
typedef int int128_t __attribute__((__mode__(TI)));
#define DLONG int128_t
// # define DLONG __int128
#define MQN_SAFE (-1LL << 63)
#else
#define DLONG long long
#define MQN_SAFE (-1L << 31)
#endif

#define MQN_IDX_MASK (~MQN_SAFE)

typedef void *mqn_value_t;

typedef struct mp_queue_node {
  union {
    struct {
      long idx;
      union {
        long mqn_value;
        void *mqn_ptr;
        mqn_value_t val;
      };
    };
    DLONG pair;
  };
} mpq_node_t;

#define MQ_BLOCK_USED_MAGIC 0x1ebacaef
#define MQ_BLOCK_FREE_MAGIC 0x2e4afeda
#define MQ_BLOCK_GARBAGE_MAGIC 0x3a04dc7d
#define MQ_BLOCK_PREPARED_MAGIC 0x4b9b13cd

#define MQ_MAGIC 0x1aed9b43
#define MQ_MAGIC_SEM 0x1aedcd21

struct mp_queue_block {
  long mqb_head __attribute__((aligned(64)));
  int mqb_magic;
  int mqb_align_bytes;
  int mqb_size;  // power of 2; one of MPQ_BLOCK_SIZE or MPQ_SMALL_BLOCK_SIZE
  long mqb_tail __attribute__((aligned(64)));
  struct mp_queue_block *mqb_next;
  int mqb_next_allocators;
  mpq_node_t mqb_nodes[MPQ_BLOCK_SIZE] __attribute__((aligned(64)));
};

struct mp_queue {
  struct mp_queue_block *mq_head __attribute__((aligned(64)));
  int mq_magic;
  struct mp_queue_block *mq_tail __attribute__((aligned(64)));
#if MPQ_USE_POSIX_SEMAPHORES
  sem_t mq_sem __attribute__((aligned(64)));
#else
  mp_sem_t mq_sem __attribute__((aligned(64)));
#endif
};

extern volatile int mpq_blocks_allocated, mpq_blocks_allocated_max, mpq_blocks_allocations, mpq_blocks_true_allocations,
    mpq_blocks_wasted, mpq_blocks_prepared;
extern volatile int mpq_small_blocks_allocated, mpq_small_blocks_allocated_max;

#define MAX_MPQ_THREADS 22
extern __thread int mpq_this_thread_id;
extern __thread void **thread_hazard_pointers;
extern volatile int mpq_threads;

/* initialize this thread id and return it */
void clear_thread_ids(void);
int get_this_thread_id(void);

/* functions for one mp_queue_block */
struct mp_queue_block *alloc_mpq_block(mqn_value_t first_val, int allow_recursion, int is_small);
void free_mpq_block(struct mp_queue_block *QB);

mqn_value_t mpq_block_pop(struct mp_queue_block *QB);
long mpq_block_push(struct mp_queue_block *QB, mqn_value_t val);

/* functions for mp_queue = list of mp_queue_block's */
void init_mp_queue(struct mp_queue *MQ);
struct mp_queue *alloc_mp_queue(void);
struct mp_queue *alloc_mp_queue_w(void);
void init_mp_queue_w(struct mp_queue *MQ);
void clear_mp_queue(struct mp_queue *MQ);  // frees all mpq block chain; invoke only if nobody else is using mp-queue
void free_mp_queue(struct mp_queue *MQ);   // same + invoke free()

// flags for mpq_push / mpq_pop functions
#define MPQF_RECURSIVE 8192
#define MPQF_STORE_PTR 4096
#define MPQF_MAX_ITERATIONS (MPQF_STORE_PTR - 1)

long mpq_push(struct mp_queue *MQ, mqn_value_t val, int flags);
mqn_value_t mpq_pop(struct mp_queue *MQ, int flags);
int mpq_is_empty(struct mp_queue *MQ);

long mpq_push_w(struct mp_queue *MQ, mqn_value_t val, int flags);
mqn_value_t mpq_pop_w(struct mp_queue *MQ, int flags);
mqn_value_t mpq_pop_nw(struct mp_queue *MQ, int flags);

int mp_sem_post(mp_sem_t *sem);
int mp_sem_wait(mp_sem_t *sem);
int mp_sem_trywait(mp_sem_t *sem);

#define COMMON_HAZARD_PTR_NUM 3
int is_hazard_ptr(void *ptr, int a, int b);
extern void *mqb_hazard_ptr[MAX_MPQ_THREADS][THREAD_HPTRS];
void *get_ptr_multithread_copy(void **ptr, void (*incref)(void *ptr));
#endif
