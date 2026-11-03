// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/thread_parallel_runner.h>
#include <string.h>

#include "lib/threads/thread_parallel_runner_internal.h"

namespace {

// Default JxlMemoryManager using malloc and free for the jpegxl_threads
// library. Same as the default JxlMemoryManager for the jpegxl library
// itself.

// Default alloc and free functions.
void* ThreadMemoryManagerDefaultAlloc(void* opaque, size_t size) {
  return malloc(size);
}

void ThreadMemoryManagerDefaultFree(void* opaque, void* address) {
  free(address);
}

// Initializes the memory manager instance with the passed one. The
// MemoryManager passed in |memory_manager| may be NULL or contain NULL
// functions which will be initialized with the default ones. If either alloc
// or free are NULL, then both must be NULL, otherwise this function returns an
// error.
bool ThreadMemoryManagerInit(JxlMemoryManager* self,
                             const JxlMemoryManager* memory_manager) {
  if (memory_manager) {
    *self = *memory_manager;
  } else {
    memset(self, 0, sizeof(*self));
  }
  if (!self->alloc != !self->free) {
    return false;
  }
  if (!self->alloc) self->alloc = ThreadMemoryManagerDefaultAlloc;
  if (!self->free) self->free = ThreadMemoryManagerDefaultFree;

  return true;
}

void* ThreadMemoryManagerAlloc(const JxlMemoryManager* memory_manager,
                               size_t size) {
  return memory_manager->alloc(memory_manager->opaque, size);
}

void ThreadMemoryManagerFree(const JxlMemoryManager* memory_manager,
                             void* address) {
  return memory_manager->free(memory_manager->opaque, address);
}

}  // namespace

JxlParallelRetCode JxlThreadParallelRunner(
    void* runner_opaque, void* jpegxl_opaque, JxlParallelRunInit init,
    JxlParallelRunFunction func, uint32_t start_range, uint32_t end_range) {
  return jpegxl::ThreadParallelRunner::Runner(
      runner_opaque, jpegxl_opaque, init, func, start_range, end_range);
}

/// Starts the given number of worker threads and blocks until they are ready.
/// "num_worker_threads" defaults to one per hyperthread. If zero, all tasks
/// run on the main thread.
void* JxlThreadParallelRunnerCreate(const JxlMemoryManager* memory_manager,
                                    size_t num_worker_threads) {
  JxlMemoryManager local_memory_manager;
  if (!ThreadMemoryManagerInit(&local_memory_manager, memory_manager))
    return nullptr;

  void* alloc = ThreadMemoryManagerAlloc(&local_memory_manager,
                                         sizeof(jpegxl::ThreadParallelRunner));
  if (!alloc) return nullptr;
  // Placement new constructor on allocated memory
  jpegxl::ThreadParallelRunner* runner =
      new (alloc) jpegxl::ThreadParallelRunner(num_worker_threads);
  runner->memory_manager = local_memory_manager;

  return runner;
}

void JxlThreadParallelRunnerDestroy(void* runner_opaque) {
  jpegxl::ThreadParallelRunner* runner =
      reinterpret_cast<jpegxl::ThreadParallelRunner*>(runner_opaque);
  if (runner) {
    JxlMemoryManager local_memory_manager = runner->memory_manager;
    // Call destructor directly since custom free function is used.
    runner->~ThreadParallelRunner();
    ThreadMemoryManagerFree(&local_memory_manager, runner);
  }
}

// Get default value for num_worker_threads parameter of
// InitJxlThreadParallelRunner.
size_t JxlThreadParallelRunnerDefaultNumWorkerThreads() {
  return std::thread::hardware_concurrency();
}
