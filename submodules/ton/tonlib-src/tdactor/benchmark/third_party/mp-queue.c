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

    Copyright 2014-2016 Telegraph Inc
              2014-2016 Nikolai Durov
              2014      Andrey Lopatin
*/

char disable_linker_warning_about_empty_file_mp_queue_cpp;

#ifdef TG_LCR_QUEUE
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <linux/futex.h>
#include <sys/syscall.h>

#include "mp-queue.h"

#undef assert
#ifndef assert
#define assert(x) x
#endif

volatile int mpq_blocks_allocated, mpq_blocks_allocated_max, mpq_blocks_allocations, mpq_blocks_true_allocations,
    mpq_blocks_wasted, mpq_blocks_prepared;
volatile int mpq_small_blocks_allocated, mpq_small_blocks_allocated_max;

__thread int mpq_this_thread_id;
__thread void **thread_hazard_pointers;
volatile int mpq_threads;

struct mp_queue MqGarbageBlocks, MqPreparedBlocks;
struct mp_queue MqGarbageSmallBlocks, MqPreparedSmallBlocks;

static inline void barrier(void) {
  asm volatile("" : : : "memory");
}
static inline void mfence(void) {
  asm volatile("mfence" : : : "memory");
}

/* hazard pointers, one per thread */

void *mqb_hazard_ptr[MAX_MPQ_THREADS][THREAD_HPTRS] __attribute__((aligned(64)));

int is_hazard_ptr(void *ptr, int a, int b) {
  barrier();
  int k = mpq_threads, q = mpq_this_thread_id;
  barrier();
  int i, j, r = 0;
  for (j = a; j <= b; j++) {
    if (mqb_hazard_ptr[q][j] == ptr) {
      r = 1;
      break;
    }
  }
  for (i = 1; i <= k; i++) {
    if (i == q) {
      continue;
    }
    for (j = a; j <= b; j++) {
      if (mqb_hazard_ptr[i][j] == ptr) {
        barrier();
        return r + 2;
      }
    }
  }
  barrier();
  return r;
}

void clear_thread_ids() {
  mpq_threads = 0;
  mpq_this_thread_id = 0;
}
/* initialize this thread id and return it */
int get_this_thread_id(void) {
  int i = mpq_this_thread_id;
  if (i) {
    return i;
  }
  i = __sync_fetch_and_add(&mpq_threads, 1) + 1;
  assert(i > 0 && i < MAX_MPQ_THREADS);
  thread_hazard_pointers = mqb_hazard_ptr[i];
  return mpq_this_thread_id = i;
}

/* custom semaphore implementation using futexes */

int mp_sem_post(mp_sem_t *sem) {
  __sync_fetch_and_add(&sem->value, 1);
  if (sem->waiting > 0) {
    syscall(__NR_futex, &sem->value, FUTEX_WAKE, 1, NULL, 0, 0);
  }
  return 0;
}

int mp_sem_wait(mp_sem_t *sem) {
  int v = sem->value, q = 0;
  while (1) {
    if (v > 0) {
      v = __sync_fetch_and_add(&sem->value, -1);
      if (v > 0) {
        return 0;
      }
      v = __sync_add_and_fetch(&sem->value, 1);
    } else {
      if (v < 0 && q++ < 10) {
        barrier();
        v = sem->value;
        continue;
      }
      __sync_fetch_and_add(&sem->waiting, 1);
      syscall(__NR_futex, &sem->value, FUTEX_WAIT, v, NULL, 0, 0);
      __sync_fetch_and_add(&sem->waiting, -1);
      v = sem->value;
      q = 0;
    }
  }
}

int mp_sem_trywait(mp_sem_t *sem) {
  int v = sem->value;
  if (v > 0) {
    v = __sync_fetch_and_add(&sem->value, -1);
    if (v > 0) {
      return 0;
    }
    __sync_fetch_and_add(&sem->value, 1);
  }
  return -1;
}

/* functions for one mp_queue_block */

// may invoke mpq_pop()/mpq_push() if allow_recursion=1
struct mp_queue_block *alloc_mpq_block(mqn_value_t first_val, int allow_recursion, int is_small) {
  is_small = 0;
  struct mp_queue_block *QB = 0;
  int prepared = 0, align_bytes = 0;
  long size = (is_small ? MPQ_SMALL_BLOCK_SIZE : MPQ_BLOCK_SIZE);
  if (allow_recursion) {
    QB = mpq_pop(is_small ? &MqGarbageSmallBlocks : &MqGarbageBlocks, MPQF_RECURSIVE);
    if (QB) {
      if (!is_hazard_ptr(QB, 0, 2)) {
        // reclaiming garbage
        assert(QB->mqb_magic == MQ_BLOCK_GARBAGE_MAGIC);
        __sync_fetch_and_add(&mpq_blocks_wasted, -1);
        align_bytes = QB->mqb_align_bytes;
      } else {
        mpq_push(is_small ? &MqGarbageSmallBlocks : &MqGarbageBlocks, QB, MPQF_RECURSIVE);
        QB = 0;
      }
    }
    if (!QB) {
      QB = mpq_pop(is_small ? &MqPreparedSmallBlocks : &MqPreparedBlocks, MPQF_RECURSIVE);
      if (QB) {
        assert(QB->mqb_magic == MQ_BLOCK_PREPARED_MAGIC);
        prepared = 1;
        __sync_fetch_and_add(&mpq_blocks_prepared, -1);
        align_bytes = QB->mqb_align_bytes;
      }
    }
  }
  if (!QB) {
    char *new_block = malloc(offsetof(struct mp_queue_block, mqb_nodes) + size * (2 * sizeof(void *)) +
                             MPQ_BLOCK_ALIGNMENT - sizeof(void *));
    assert(new_block);
    assert(!((long)new_block & (sizeof(void *) - 1)));
    align_bytes = -(int)(long)new_block & (MPQ_BLOCK_ALIGNMENT - 1);
    QB = (struct mp_queue_block *)(new_block + align_bytes);

    __sync_fetch_and_add(&mpq_blocks_true_allocations, 1);
    if (is_small) {
      int t = __sync_fetch_and_add(&mpq_small_blocks_allocated, 1);
      if (t >= mpq_small_blocks_allocated_max) {
        __sync_bool_compare_and_swap(&mpq_small_blocks_allocated_max, mpq_small_blocks_allocated_max, t + 1);
      }
    } else {
      int t = __sync_fetch_and_add(&mpq_blocks_allocated, 1);
      if (t >= mpq_blocks_allocated_max) {
        __sync_bool_compare_and_swap(&mpq_blocks_allocated_max, mpq_blocks_allocated_max, t + 1);
      }
    }
  } else {
    assert(QB->mqb_size == size);
  }
  __sync_fetch_and_add(&mpq_blocks_allocations, 1);

  memset(QB, 0, offsetof(struct mp_queue_block, mqb_nodes));
  QB->mqb_align_bytes = align_bytes;
  QB->mqb_size = size;

  QB->mqb_nodes[0].idx = MQN_SAFE;
  QB->mqb_nodes[0].val = first_val;

  if (!prepared) {
    long i;
    for (i = 1; i < size; i++) {
      QB->mqb_nodes[i].idx = MQN_SAFE + i;
      QB->mqb_nodes[i].val = 0;
    }
  }

  if (first_val) {
    QB->mqb_tail = 1;
  }

  QB->mqb_magic = MQ_BLOCK_USED_MAGIC;
  return QB;
}

void free_mpq_block(struct mp_queue_block *QB) {
  assert(QB->mqb_magic == MQ_BLOCK_USED_MAGIC);
  assert((unsigned)QB->mqb_align_bytes < MPQ_BLOCK_ALIGNMENT && !(QB->mqb_align_bytes & (sizeof(void *) - 1)));
  QB->mqb_magic = MQ_BLOCK_FREE_MAGIC;
  if (QB->mqb_size == MPQ_SMALL_BLOCK_SIZE) {
    __sync_fetch_and_add(&mpq_small_blocks_allocated, -1);
  } else {
    assert(QB->mqb_size == MPQ_BLOCK_SIZE);
    __sync_fetch_and_add(&mpq_blocks_allocated, -1);
  }
  free((char *)QB - QB->mqb_align_bytes);
}

static inline void mpq_fix_state(struct mp_queue_block *QB) {
  long h, t;
  while (1) {
    barrier();
    t = QB->mqb_tail;
    barrier();
    h = QB->mqb_head;
    barrier();
    if ((unsigned long)h <= (unsigned long)t) {
      break;
    }
    if (QB->mqb_tail != t) {
      continue;
    }
    // here tail < head ; try to advance tail to head
    // (or to some value h such that tail < h <= head)
    if (__sync_bool_compare_and_swap(&QB->mqb_tail, t, h)) {
      break;
    }
  }
}

mqn_value_t mpq_block_pop(struct mp_queue_block *QB) {
  // fprintf (stderr, "%d:mpq_block_pop(%p)\n", mpq_this_thread_id, QB);
  long size = QB->mqb_size;
  while (1) {
    long h = __sync_fetch_and_add(&QB->mqb_head, 1);
    // fprintf (stderr, "%d:  mpq_block_pop(%ld)\n", mpq_this_thread_id, h);
    mpq_node_t *node = &QB->mqb_nodes[h & (size - 1)];
    while (1) {
      mpq_node_t d, e;
      barrier();
      mqn_value_t val = node->val;
      barrier();
      long safe_idx = node->idx;
      barrier();
      long idx = safe_idx & MQN_IDX_MASK;
      if (idx > h) {
        break;
      }
      d.val = val;
      d.idx = safe_idx;
      if (val) {
        if (idx == h) {
          e.idx = safe_idx + size;
          e.val = 0;
          if (__sync_bool_compare_and_swap(&node->pair, d.pair, e.pair)) {
            // fprintf (stderr, "%d:  mpq_block_pop(%ld) -> %lx\n", mpq_this_thread_id, h, (long) val);
            return val;
          }
        } else {
          e.val = val;
          e.idx = idx;  // clear 'safe' flag
          if (__sync_bool_compare_and_swap(&node->pair, d.pair, e.pair)) {
            break;
          }
        }
      } else {
        e.idx = (safe_idx & MQN_SAFE) + h + size;
        e.val = 0;
        if (__sync_bool_compare_and_swap(&node->pair, d.pair, e.pair)) {
          break;
        }
      }
      /* somebody changed this element while we were inspecting it, make another loop iteration */
    }
    barrier();
    long t = QB->mqb_tail & MQN_IDX_MASK;
    barrier();
    if (t <= h + 1) {
      mpq_fix_state(QB);
      return 0;
    }
    /* now try again with a new value of h */
  }
}

long mpq_block_push(struct mp_queue_block *QB, mqn_value_t val) {
  int iterations = 0;
  long size = QB->mqb_size;
  // fprintf (stderr, "%d:mpq_block_push(%p)\n", mpq_this_thread_id, QB);
  while (1) {
    long t = __sync_fetch_and_add(&QB->mqb_tail, 1);
    // fprintf (stderr, "%d:  mpq_block_push(%ld)\n", mpq_this_thread_id, t);
    if (t & MQN_SAFE) {
      return -1L;  // bad luck
    }
    mpq_node_t *node = &QB->mqb_nodes[t & (size - 1)];
    barrier();
    mqn_value_t old_val = node->val;
    barrier();
    long safe_idx = node->idx;
    barrier();
    long idx = safe_idx & MQN_IDX_MASK;
    if (!old_val && idx <= t && ((safe_idx & MQN_SAFE) || QB->mqb_head <= t)) {
      mpq_node_t d, e;
      d.idx = safe_idx;
      d.val = 0;
      e.idx = MQN_SAFE + t;
      e.val = val;
      if (__sync_bool_compare_and_swap(&node->pair, d.pair, e.pair)) {
        // fprintf (stderr, "%d:  mpq_block_push(%ld) <- %lx\n", mpq_this_thread_id, t, (long) val);
        return t;  // pushed OK
      }
    }
    barrier();
    long h = QB->mqb_head;
    barrier();
    if (t - h >= size || ++iterations > 10) {
      __sync_fetch_and_or(&QB->mqb_tail, MQN_SAFE);  // closing queue
      return -1L;                                    // bad luck
    }
  }
}

/* functions for mp_queue = list of mp_queue_block's */
void init_mp_queue(struct mp_queue *MQ) {
  assert(MQ->mq_magic != MQ_MAGIC && MQ->mq_magic != MQ_MAGIC_SEM);
  memset(MQ, 0, sizeof(struct mp_queue));
  MQ->mq_head = MQ->mq_tail = alloc_mpq_block(0, 0, 1);
  MQ->mq_magic = MQ_MAGIC;

  if (!MqGarbageBlocks.mq_magic) {
    init_mp_queue(&MqGarbageBlocks);
    init_mp_queue(&MqGarbageSmallBlocks);
  } else if (!MqPreparedBlocks.mq_magic) {
    init_mp_queue(&MqPreparedBlocks);
    init_mp_queue(&MqPreparedSmallBlocks);
  }
}

void init_mp_queue_w(struct mp_queue *MQ) {
  init_mp_queue(MQ);
#if MPQ_USE_POSIX_SEMAPHORES
  sem_init(&MQ->mq_sem, 0, 0);
#endif
  MQ->mq_magic = MQ_MAGIC_SEM;
}

struct mp_queue *alloc_mp_queue(void) {
  struct mp_queue *MQ = NULL;
  assert(!posix_memalign((void **)&MQ, 64, sizeof(*MQ)));
  memset(MQ, 0, sizeof(*MQ));
  init_mp_queue(MQ);
  return MQ;
}

struct mp_queue *alloc_mp_queue_w(void) {
  struct mp_queue *MQ = NULL;
  assert(!posix_memalign((void **)&MQ, 64, sizeof(*MQ)));
  memset(MQ, 0, sizeof(*MQ));
  init_mp_queue_w(MQ);
  return MQ;
}

/* invoke only if sure that nobody else may be using this mp_queue in parallel */
void clear_mp_queue(struct mp_queue *MQ) {
  assert(MQ->mq_magic == MQ_MAGIC || MQ->mq_magic == MQ_MAGIC_SEM);
  assert(MQ->mq_head && MQ->mq_tail);
  struct mp_queue_block *QB = MQ->mq_head, *QBN;
  for (QB = MQ->mq_head; QB; QB = QBN) {
    QBN = QB->mqb_next;
    assert(QB->mqb_next || QB == MQ->mq_tail);
    QB->mqb_next = 0;
    free_mpq_block(QB);
  }
  MQ->mq_head = MQ->mq_tail = 0;
  MQ->mq_magic = 0;
}

void free_mp_queue(struct mp_queue *MQ) {
  clear_mp_queue(MQ);
  free(MQ);
}

// may invoke mpq_push() to discard new empty block
mqn_value_t mpq_pop(struct mp_queue *MQ, int flags) {
  void **hptr = &mqb_hazard_ptr[get_this_thread_id()][0];
  long r = ((flags & MPQF_RECURSIVE) != 0);
  struct mp_queue_block *QB;
  mqn_value_t v;
  while (1) {
    QB = MQ->mq_head;
    barrier();
    hptr[r] = QB;
    barrier();
    __sync_synchronize();
    if (MQ->mq_head != QB) {
      continue;
    }

    v = mpq_block_pop(QB);
    if (v) {
      break;
    }
    barrier();
    if (!QB->mqb_next) {
      QB = 0;
      break;
    }
    v = mpq_block_pop(QB);
    if (v) {
      break;
    }
    if (__sync_bool_compare_and_swap(&MQ->mq_head, QB, QB->mqb_next)) {
      // want to free QB here, but this is complicated if somebody else holds a pointer
      if (is_hazard_ptr(QB, 0, 2) <= 1) {
        free_mpq_block(QB);
      } else {
        __sync_fetch_and_add(&mpq_blocks_wasted, 1);
        // ... put QB into some GC queue? ...
        QB->mqb_magic = MQ_BLOCK_GARBAGE_MAGIC;
        mpq_push(QB->mqb_size == MPQ_SMALL_BLOCK_SIZE ? &MqGarbageSmallBlocks : &MqGarbageBlocks, QB,
                 flags & MPQF_RECURSIVE);
      }
    }
  }
  if (flags & MPQF_STORE_PTR) {
    hptr[2] = QB;
  }
  hptr[r] = 0;
  return v;
}

/* 1 = definitely empty (for some serialization), 0 = possibly non-empty;
   may invoke mpq_push() to discard empty block */
int mpq_is_empty(struct mp_queue *MQ) {
  void **hptr = &mqb_hazard_ptr[get_this_thread_id()][0];
  struct mp_queue_block *QB;
  while (1) {
    QB = MQ->mq_head;
    barrier();
    *hptr = QB;
    barrier();
    __sync_synchronize();
    if (MQ->mq_head != QB) {
      continue;
    }
    barrier();
    long h = QB->mqb_head;
    barrier();
    long t = QB->mqb_tail;
    barrier();
    if (!(t & MQN_SAFE)) {
      *hptr = 0;
      return t <= h;
    }
    t &= MQN_IDX_MASK;
    if (t > h) {
      *hptr = 0;
      return 0;
    }
    barrier();
    if (!QB->mqb_next) {
      *hptr = 0;
      return 1;
    }
    if (__sync_bool_compare_and_swap(&MQ->mq_head, QB, QB->mqb_next)) {
      // want to free QB here, but this is complicated if somebody else holds a pointer
      if (is_hazard_ptr(QB, 0, 2) <= 1) {
        free_mpq_block(QB);
      } else {
        __sync_fetch_and_add(&mpq_blocks_wasted, 1);
        // ... put QB into some GC queue? ...
        QB->mqb_magic = MQ_BLOCK_GARBAGE_MAGIC;
        mpq_push(QB->mqb_size == MPQ_SMALL_BLOCK_SIZE ? &MqGarbageSmallBlocks : &MqGarbageBlocks, QB, 0);
      }
    }
  }
  *hptr = 0;
  return 0;
}

/* may invoke mpq_alloc_block (which recursively invokes mpq_pop)
   or mpq_push() (without needing to hold hazard pointer) to deal with blocks */
long mpq_push(struct mp_queue *MQ, mqn_value_t val, int flags) {
  void **hptr = mqb_hazard_ptr[get_this_thread_id()];
  long r = ((flags & MPQF_RECURSIVE) != 0);
  while (1) {
    struct mp_queue_block *QB = MQ->mq_tail;
    barrier();
    hptr[r] = QB;
    barrier();
    __sync_synchronize();
    if (MQ->mq_tail != QB) {
      continue;
    }

    if (QB->mqb_next) {
      __sync_bool_compare_and_swap(&MQ->mq_tail, QB, QB->mqb_next);
      continue;
    }
    long pos = mpq_block_push(QB, val);
    if (pos >= 0) {
      if (flags & MPQF_STORE_PTR) {
        hptr[2] = QB;
      }
      hptr[r] = 0;
      return pos;
    }
#define DBG(c)  // fprintf (stderr, "[%d] pushing %lx to %p,%p: %c\n", mpq_this_thread_id, (long) val, MQ, QB, c);
    DBG('A');
    /*
    if (__sync_fetch_and_add (&QB->mqb_next_allocators, 1)) {
      // somebody else will allocate next block; busy wait instead of spuruous alloc/free
      DBG('B')
      while (!QB->mqb_next) {
        barrier ();
      }
      DBG('C')
      continue;
    }
    */
    int is_small = (QB == MQ->mq_head);
    struct mp_queue_block *NQB;
    if (!r) {
      assert(!hptr[1]);
      NQB = alloc_mpq_block(val, 1, is_small);
      assert(!hptr[1]);
    } else {
      NQB = alloc_mpq_block(val, 0, is_small);
    }
    assert(hptr[r] == QB);
    DBG('D')
    if (__sync_bool_compare_and_swap(&QB->mqb_next, 0, NQB)) {
      __sync_bool_compare_and_swap(&MQ->mq_tail, QB, NQB);
      DBG('E')
      if (flags & MPQF_STORE_PTR) {
        hptr[2] = NQB;
      }
      hptr[r] = 0;
      return 0;
    } else {
      DBG('F');
      NQB->mqb_magic = MQ_BLOCK_PREPARED_MAGIC;
      mpq_push(is_small ? &MqPreparedSmallBlocks : &MqPreparedBlocks, NQB, 0);
      __sync_fetch_and_add(&mpq_blocks_prepared, 1);
    }
  }
#undef DBG
}

mqn_value_t mpq_pop_w(struct mp_queue *MQ, int flags) {
  assert(MQ->mq_magic == MQ_MAGIC_SEM);
  int s = -1, iterations = flags & MPQF_MAX_ITERATIONS;
  while (iterations-- > 0) {
#if MPQ_USE_POSIX_SEMAPHORES
    s = sem_trywait(&MQ->mq_sem);
#else
    s = mp_sem_trywait(&MQ->mq_sem);
#endif
    if (!s) {
      break;
    }
#if MPQ_USE_POSIX_SEMAPHORES
    assert(errno == EAGAIN || errno == EINTR);
#endif
  }
  while (s < 0) {
#if MPQ_USE_POSIX_SEMAPHORES
    s = sem_wait(&MQ->mq_sem);
#else
    s = mp_sem_wait(&MQ->mq_sem);
#endif
    if (!s) {
      break;
    }
#if MPQ_USE_POSIX_SEMAPHORES
    assert(errno == EAGAIN);
#endif
  }
  mqn_value_t *v = mpq_pop(MQ, flags);
  assert(v);
  return v;
}

mqn_value_t mpq_pop_nw(struct mp_queue *MQ, int flags) {
  assert(MQ->mq_magic == MQ_MAGIC_SEM);
  int s = -1, iterations = flags & MPQF_MAX_ITERATIONS;
  while (iterations-- > 0) {
#if MPQ_USE_POSIX_SEMAPHORES
    s = sem_trywait(&MQ->mq_sem);
#else
    s = mp_sem_trywait(&MQ->mq_sem);
#endif
    if (s >= 0) {
      break;
    }
#if MPQ_USE_POSIX_SEMAPHORES
    assert(errno == EAGAIN || errno == EINTR);
#endif
  }
  if (s < 0) {
    return 0;
  }
  mqn_value_t *v = mpq_pop(MQ, flags);
  assert(v);
  return v;
}

long mpq_push_w(struct mp_queue *MQ, mqn_value_t v, int flags) {
  assert(MQ->mq_magic == MQ_MAGIC_SEM);
  long res = mpq_push(MQ, v, flags);
#if MPQ_USE_POSIX_SEMAPHORES
  assert(sem_post(&MQ->mq_sem) >= 0);
#else
  assert(mp_sem_post(&MQ->mq_sem) >= 0);
#endif
  return res;
}

void *get_ptr_multithread_copy(void **ptr, void (*incref)(void *ptr)) {
  void **hptr = &mqb_hazard_ptr[get_this_thread_id()][COMMON_HAZARD_PTR_NUM];
  assert(*hptr == NULL);

  void *R;
  while (1) {
    R = *ptr;
    barrier();
    *hptr = R;
    barrier();
    mfence();

    if (R != *ptr) {
      continue;
    }

    incref(R);

    barrier();
    *hptr = NULL;

    break;
  }
  return R;
}
#endif
