// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/threads/thread_parallel_runner_internal.h"

#include <algorithm>

#if defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER) || \
    defined(THREAD_SANITIZER)
#include "sanitizer/common_interface_defs.h"  // __sanitizer_print_stack_trace
#endif                                        // defined(*_SANITIZER)

#include <jxl/thread_parallel_runner.h>

namespace {

// Important: JXL_ASSERT does not guarantee running the `condition` code,
// use only for debug mode checks.

#if JXL_ENABLE_ASSERT
// Exits the program after printing a stack trace when possible.
bool Abort() {
#if defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER) || \
    defined(THREAD_SANITIZER)
  // If compiled with any sanitizer print a stack trace. This call doesn't crash
  // the program, instead the trap below will crash it also allowing gdb to
  // break there.
  __sanitizer_print_stack_trace();
#endif  // defined(*_SANITIZER)

#ifdef _MSC_VER
  __debugbreak();
  abort();
#else
  __builtin_trap();
#endif
}
#define JXL_ASSERT(condition) \
  do {                        \
    if (!(condition)) {       \
      Abort();                \
    }                         \
  } while (0)
#else
#define JXL_ASSERT(condition) \
  do {                        \
  } while (0)
#endif
}  // namespace

namespace jpegxl {

// static
JxlParallelRetCode ThreadParallelRunner::Runner(
    void* runner_opaque, void* jpegxl_opaque, JxlParallelRunInit init,
    JxlParallelRunFunction func, uint32_t start_range, uint32_t end_range) {
  ThreadParallelRunner* self =
      static_cast<ThreadParallelRunner*>(runner_opaque);
  if (start_range > end_range) return -1;
  if (start_range == end_range) return 0;

  int ret = init(jpegxl_opaque, std::max<size_t>(self->num_worker_threads_, 1));
  if (ret != 0) return ret;

  // Use a sequential run when num_worker_threads_ is zero since we have no
  // worker threads.
  if (self->num_worker_threads_ == 0) {
    const size_t thread = 0;
    for (uint32_t task = start_range; task < end_range; ++task) {
      func(jpegxl_opaque, task, thread);
    }
    return 0;
  }

  if (self->depth_.fetch_add(1, std::memory_order_acq_rel) != 0) {
    return -1;  // Must not re-enter.
  }

  const WorkerCommand worker_command =
      (static_cast<WorkerCommand>(start_range) << 32) + end_range;
  // Ensure the inputs do not result in a reserved command.
  JXL_ASSERT(worker_command != kWorkerWait);
  JXL_ASSERT(worker_command != kWorkerOnce);
  JXL_ASSERT(worker_command != kWorkerExit);

  self->data_func_ = func;
  self->jpegxl_opaque_ = jpegxl_opaque;
  self->num_reserved_.store(0, std::memory_order_relaxed);

  self->StartWorkers(worker_command);
  self->WorkersReadyBarrier();

  if (self->depth_.fetch_add(-1, std::memory_order_acq_rel) != 1) {
    return -1;
  }
  return 0;
}

// static
void ThreadParallelRunner::RunRange(ThreadParallelRunner* self,
                                    const WorkerCommand command,
                                    const int thread) {
  const uint32_t begin = command >> 32;
  const uint32_t end = command & 0xFFFFFFFF;
  const uint32_t num_tasks = end - begin;
  const uint32_t num_worker_threads = self->num_worker_threads_;

  // OpenMP introduced several "schedule" strategies:
  // "single" (static assignment of exactly one chunk per thread): slower.
  // "dynamic" (allocates k tasks at a time): competitive for well-chosen k.
  // "guided" (allocates k tasks, decreases k): computing k = remaining/n
  //   is faster than halving k each iteration. We prefer this strategy
  //   because it avoids user-specified parameters.

  for (;;) {
#if 0
      // dynamic
      const uint32_t my_size = std::max(num_tasks / (num_worker_threads * 4), 1);
#else
    // guided
    const uint32_t num_reserved =
        self->num_reserved_.load(std::memory_order_relaxed);
    // It is possible that more tasks are reserved than ready to run.
    const uint32_t num_remaining =
        num_tasks - std::min(num_reserved, num_tasks);
    const uint32_t my_size =
        std::max(num_remaining / (num_worker_threads * 4), 1u);
#endif
    const uint32_t my_begin = begin + self->num_reserved_.fetch_add(
                                          my_size, std::memory_order_relaxed);
    const uint32_t my_end = std::min(my_begin + my_size, begin + num_tasks);
    // Another thread already reserved the last task.
    if (my_begin >= my_end) {
      break;
    }
    for (uint32_t task = my_begin; task < my_end; ++task) {
      self->data_func_(self->jpegxl_opaque_, task, thread);
    }
  }
}

// static
void ThreadParallelRunner::ThreadFunc(ThreadParallelRunner* self,
                                      const int thread) {
  // Until kWorkerExit command received:
  for (;;) {
    std::unique_lock<std::mutex> lock(self->mutex_);
    // Notify main thread that this thread is ready.
    if (++self->workers_ready_ == self->num_threads_) {
      self->workers_ready_cv_.notify_one();
    }
  RESUME_WAIT:
    // Wait for a command.
    self->worker_start_cv_.wait(lock);
    const WorkerCommand command = self->worker_start_command_;
    switch (command) {
      case kWorkerWait:    // spurious wakeup:
        goto RESUME_WAIT;  // lock still held, avoid incrementing ready.
      case kWorkerOnce:
        lock.unlock();
        self->data_func_(self->jpegxl_opaque_, thread, thread);
        break;
      case kWorkerExit:
        return;  // exits thread
      default:
        lock.unlock();
        RunRange(self, command, thread);
        break;
    }
  }
}

ThreadParallelRunner::ThreadParallelRunner(const int num_worker_threads)
    : num_worker_threads_(num_worker_threads),
      num_threads_(std::max(num_worker_threads, 1)) {
  threads_.reserve(num_worker_threads_);

  // Suppress "unused-private-field" warning.
  (void)padding1;
  (void)padding2;

  // Safely handle spurious worker wakeups.
  worker_start_command_ = kWorkerWait;

  for (uint32_t i = 0; i < num_worker_threads_; ++i) {
    threads_.emplace_back(ThreadFunc, this, i);
  }

  if (num_worker_threads_ != 0) {
    WorkersReadyBarrier();
  }
}

ThreadParallelRunner::~ThreadParallelRunner() {
  if (num_worker_threads_ != 0) {
    StartWorkers(kWorkerExit);
  }

  for (std::thread& thread : threads_) {
    JXL_ASSERT(thread.joinable());
    thread.join();
  }
}
}  // namespace jpegxl
