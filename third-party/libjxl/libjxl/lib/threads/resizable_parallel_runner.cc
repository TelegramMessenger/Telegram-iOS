// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/resizable_parallel_runner.h>

#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <thread>
#include <vector>

namespace jpegxl {
namespace {

// A thread pool that allows changing the number of threads it runs. It also
// runs tasks on the calling thread, which can work better on schedulers for
// heterogeneous architectures.
struct ResizeableParallelRunner {
  void SetNumThreads(size_t num) {
    if (num > 0) {
      num -= 1;
    }
    {
      std::unique_lock<std::mutex> l(state_mutex_);
      num_desired_workers_ = num;
      workers_can_proceed_.notify_all();
    }
    if (workers_.size() < num) {
      for (size_t i = workers_.size(); i < num; i++) {
        workers_.emplace_back([this, i]() { WorkerBody(i); });
      }
    }
    if (workers_.size() > num) {
      for (size_t i = num; i < workers_.size(); i++) {
        workers_[i].join();
      }
      workers_.resize(num);
    }
  }

  ~ResizeableParallelRunner() { SetNumThreads(0); }

  JxlParallelRetCode Run(void* jxl_opaque, JxlParallelRunInit init,
                         JxlParallelRunFunction func, uint32_t start,
                         uint32_t end) {
    if (start + 1 == end) {
      JxlParallelRetCode ret = init(jxl_opaque, 1);
      if (ret != 0) return ret;

      func(jxl_opaque, start, 0);
      return ret;
    }

    size_t num_workers = std::min<size_t>(workers_.size() + 1, end - start);
    JxlParallelRetCode ret = init(jxl_opaque, num_workers);
    if (ret != 0) {
      return ret;
    }

    {
      std::unique_lock<std::mutex> l(state_mutex_);
      // Avoid waking up more workers than needed.
      max_running_workers_ = end - start - 1;
      next_task_ = start;
      end_task_ = end;
      func_ = func;
      jxl_opaque_ = jxl_opaque;
      work_available_ = true;
      num_running_workers_++;
      workers_can_proceed_.notify_all();
    }

    DequeueTasks(0);

    while (true) {
      std::unique_lock<std::mutex> l(state_mutex_);
      if (num_running_workers_ == 0) break;
      work_done_.wait(l);
    }

    return ret;
  }

 private:
  void WorkerBody(size_t worker_id) {
    while (true) {
      {
        std::unique_lock<std::mutex> l(state_mutex_);
        // Worker pool was reduced, resize down.
        if (worker_id >= num_desired_workers_) {
          return;
        }
        // Nothing to do this time.
        if (!work_available_ || worker_id >= max_running_workers_) {
          workers_can_proceed_.wait(l);
          continue;
        }
        num_running_workers_++;
      }
      DequeueTasks(worker_id + 1);
    }
  }

  void DequeueTasks(size_t thread_id) {
    while (true) {
      uint32_t task = next_task_++;
      if (task >= end_task_) {
        std::unique_lock<std::mutex> l(state_mutex_);
        num_running_workers_--;
        work_available_ = false;
        if (num_running_workers_ == 0) {
          work_done_.notify_all();
        }
        break;
      }
      func_(jxl_opaque_, task, thread_id);
    }
  }

  // Checks when the worker has something to do, which can be one of:
  // - quitting (when worker_id >= num_desired_workers_)
  // - having work available for them (work_available_ is true and worker_id >=
  // max_running_workers_)
  std::condition_variable workers_can_proceed_;

  // Workers are done, and the main thread can proceed (num_running_workers_ ==
  // 0)
  std::condition_variable work_done_;

  std::vector<std::thread> workers_;

  // Protects all the remaining variables, except for func_, jxl_opaque_ and
  // end_task_ (for which only the write by the main thread is protected, and
  // subsequent uses by workers happen-after it) and next_task_ (which is
  // atomic).
  std::mutex state_mutex_;

  // Range of tasks still need to be done.
  std::atomic<uint32_t> next_task_;
  uint32_t end_task_;

  // Function to run and its argument.
  JxlParallelRunFunction func_;
  void* jxl_opaque_;  // not owned

  // Variables that control the workers:
  // - work_available_ is set to true after a call to Run() and to false at the
  // end of it.
  // - num_desired_workers_ represents the number of workers that should be
  // present.
  // - max_running_workers_ represents the number of workers that should be
  // executing tasks.
  // - num_running_workers_ represents the number of workers that are executing
  // tasks.
  size_t num_desired_workers_ = 0;
  size_t max_running_workers_ = 0;
  size_t num_running_workers_ = 0;
  bool work_available_ = false;
};
}  // namespace
}  // namespace jpegxl

extern "C" {
JXL_THREADS_EXPORT JxlParallelRetCode JxlResizableParallelRunner(
    void* runner_opaque, void* jpegxl_opaque, JxlParallelRunInit init,
    JxlParallelRunFunction func, uint32_t start_range, uint32_t end_range) {
  return static_cast<jpegxl::ResizeableParallelRunner*>(runner_opaque)
      ->Run(jpegxl_opaque, init, func, start_range, end_range);
}

JXL_THREADS_EXPORT void* JxlResizableParallelRunnerCreate(
    const JxlMemoryManager* memory_manager) {
  return new jpegxl::ResizeableParallelRunner();
}

JXL_THREADS_EXPORT void JxlResizableParallelRunnerSetThreads(
    void* runner_opaque, size_t num_threads) {
  static_cast<jpegxl::ResizeableParallelRunner*>(runner_opaque)
      ->SetNumThreads(num_threads);
}

JXL_THREADS_EXPORT void JxlResizableParallelRunnerDestroy(void* runner_opaque) {
  delete static_cast<jpegxl::ResizeableParallelRunner*>(runner_opaque);
}

JXL_THREADS_EXPORT uint32_t
JxlResizableParallelRunnerSuggestThreads(uint64_t xsize, uint64_t ysize) {
  // ~one thread per group.
  return std::min<uint64_t>(std::thread::hardware_concurrency(),
                            xsize * ysize / (256 * 256));
}
}
