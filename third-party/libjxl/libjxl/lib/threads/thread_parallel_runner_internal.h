// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//

// C++ implementation using std::thread of a ::JxlParallelRunner.

// The main class in this module, ThreadParallelRunner, implements a static
// method ThreadParallelRunner::Runner than can be passed as a
// JxlParallelRunner when using the JPEG XL library. This uses std::thread
// internally and related synchronization functions. The number of threads
// created is fixed at construction time and the threads are re-used for every
// ThreadParallelRunner::Runner call. Only one concurrent Runner() call per
// instance is allowed at a time.
//
// This is a scalable, lower-overhead thread pool runner, especially suitable
// for data-parallel computations in the fork-join model, where clients need to
// know when all tasks have completed.
//
// This thread pool can efficiently load-balance millions of tasks using an
// atomic counter, thus avoiding per-task virtual or system calls. With 48
// hyperthreads and 1M tasks that add to an atomic counter, overall runtime is
// 10-20x higher when using std::async, and ~200x for a queue-based thread
// pool.
//
// Usage:
//   ThreadParallelRunner runner;
//   JxlDecode(
//       ... , &ThreadParallelRunner::Runner, static_cast<void*>(&runner));

#ifndef LIB_THREADS_THREAD_PARALLEL_RUNNER_INTERNAL_H_
#define LIB_THREADS_THREAD_PARALLEL_RUNNER_INTERNAL_H_

#include <jxl/memory_manager.h>
#include <jxl/parallel_runner.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include <atomic>
#include <condition_variable>  //NOLINT
#include <mutex>               //NOLINT
#include <thread>              //NOLINT
#include <vector>

namespace jpegxl {

// Main helper class implementing the ::JxlParallelRunner interface.
class ThreadParallelRunner {
 public:
  // ::JxlParallelRunner interface.
  static JxlParallelRetCode Runner(void* runner_opaque, void* jpegxl_opaque,
                                   JxlParallelRunInit init,
                                   JxlParallelRunFunction func,
                                   uint32_t start_range, uint32_t end_range);

  // Starts the given number of worker threads and blocks until they are ready.
  // "num_worker_threads" defaults to one per hyperthread. If zero, all tasks
  // run on the main thread.
  explicit ThreadParallelRunner(
      int num_worker_threads = std::thread::hardware_concurrency());

  // Waits for all threads to exit.
  ~ThreadParallelRunner();

  // Returns maximum number of main/worker threads that may call Func. Useful
  // for allocating per-thread storage.
  size_t NumThreads() const { return num_threads_; }

  // Runs func(thread, thread) on all thread(s) that may participate in Run.
  // If NumThreads() == 0, runs on the main thread with thread == 0, otherwise
  // concurrently called by each worker thread in [0, NumThreads()).
  template <class Func>
  void RunOnEachThread(const Func& func) {
    if (num_worker_threads_ == 0) {
      const int thread = 0;
      func(thread, thread);
      return;
    }

    data_func_ = reinterpret_cast<JxlParallelRunFunction>(&CallClosure<Func>);
    jpegxl_opaque_ = const_cast<void*>(static_cast<const void*>(&func));
    StartWorkers(kWorkerOnce);
    WorkersReadyBarrier();
  }

  JxlMemoryManager memory_manager;

 private:
  // After construction and between calls to Run, workers are "ready", i.e.
  // waiting on worker_start_cv_. They are "started" by sending a "command"
  // and notifying all worker_start_cv_ waiters. (That is why all workers
  // must be ready/waiting - otherwise, the notification will not reach all of
  // them and the main thread waits in vain for them to report readiness.)
  using WorkerCommand = uint64_t;

  // Special values; all others encode the begin/end parameters. Note that all
  // these are no-op ranges (begin >= end) and therefore never used to encode
  // ranges.
  static constexpr WorkerCommand kWorkerWait = ~1ULL;
  static constexpr WorkerCommand kWorkerOnce = ~2ULL;
  static constexpr WorkerCommand kWorkerExit = ~3ULL;

  // Calls f(task, thread). Used for type erasure of Func arguments. The
  // signature must match JxlParallelRunFunction, hence a void* argument.
  template <class Closure>
  static void CallClosure(void* f, const uint32_t task, const size_t thread) {
    (*reinterpret_cast<const Closure*>(f))(task, thread);
  }

  void WorkersReadyBarrier() {
    std::unique_lock<std::mutex> lock(mutex_);
    // Typically only a single iteration.
    while (workers_ready_ != threads_.size()) {
      workers_ready_cv_.wait(lock);
    }
    workers_ready_ = 0;

    // Safely handle spurious worker wakeups.
    worker_start_command_ = kWorkerWait;
  }

  // Precondition: all workers are ready.
  void StartWorkers(const WorkerCommand worker_command) {
    mutex_.lock();
    worker_start_command_ = worker_command;
    // Workers will need this lock, so release it before they wake up.
    mutex_.unlock();
    worker_start_cv_.notify_all();
  }

  // Attempts to reserve and perform some work from the global range of tasks,
  // which is encoded within "command". Returns after all tasks are reserved.
  static void RunRange(ThreadParallelRunner* self, const WorkerCommand command,
                       const int thread);

  static void ThreadFunc(ThreadParallelRunner* self, int thread);

  // Unmodified after ctor, but cannot be const because we call thread::join().
  std::vector<std::thread> threads_;

  const uint32_t num_worker_threads_;  // == threads_.size()
  const uint32_t num_threads_;

  std::atomic<int> depth_{0};  // detects if Run is re-entered (not supported).

  std::mutex mutex_;  // guards both cv and their variables.
  std::condition_variable workers_ready_cv_;
  uint32_t workers_ready_ = 0;
  std::condition_variable worker_start_cv_;
  WorkerCommand worker_start_command_;

  // Written by main thread, read by workers (after mutex lock/unlock).
  JxlParallelRunFunction data_func_;
  void* jpegxl_opaque_;

  // Updated by workers; padding avoids false sharing.
  uint8_t padding1[64];
  std::atomic<uint32_t> num_reserved_{0};
  uint8_t padding2[64];
};

}  // namespace jpegxl

#endif  // LIB_THREADS_THREAD_PARALLEL_RUNNER_INTERNAL_H_
