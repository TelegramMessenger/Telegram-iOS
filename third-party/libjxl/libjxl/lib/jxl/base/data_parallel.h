// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_BASE_DATA_PARALLEL_H_
#define LIB_JXL_BASE_DATA_PARALLEL_H_

// Portable, low-overhead C++11 ThreadPool alternative to OpenMP for
// data-parallel computations.

#include <jxl/parallel_runner.h>
#include <stddef.h>
#include <stdint.h>

#include "lib/jxl/base/bits.h"
#include "lib/jxl/base/status.h"
#if JXL_COMPILER_MSVC
// suppress warnings about the const & applied to function types
#pragma warning(disable : 4180)
#endif

namespace jxl {

class ThreadPool {
 public:
  ThreadPool(JxlParallelRunner runner, void* runner_opaque)
      : runner_(runner ? runner : &ThreadPool::SequentialRunnerStatic),
        runner_opaque_(runner ? runner_opaque : static_cast<void*>(this)) {}

  ThreadPool(const ThreadPool&) = delete;
  ThreadPool& operator&(const ThreadPool&) = delete;

  JxlParallelRunner runner() const { return runner_; }
  void* runner_opaque() const { return runner_opaque_; }

  // Runs init_func(num_threads) followed by data_func(task, thread) on worker
  // thread(s) for every task in [begin, end). init_func() must return a Status
  // indicating whether the initialization succeeded.
  // "thread" is an integer smaller than num_threads.
  // Not thread-safe - no two calls to Run may overlap.
  // Subsequent calls will reuse the same threads.
  //
  // Precondition: begin <= end.
  template <class InitFunc, class DataFunc>
  Status Run(uint32_t begin, uint32_t end, const InitFunc& init_func,
             const DataFunc& data_func, const char* caller = "") {
    JXL_ASSERT(begin <= end);
    if (begin == end) return true;
    RunCallState<InitFunc, DataFunc> call_state(init_func, data_func);
    // The runner_ uses the C convention and returns 0 in case of error, so we
    // convert it to a Status.
    return (*runner_)(runner_opaque_, static_cast<void*>(&call_state),
                      &call_state.CallInitFunc, &call_state.CallDataFunc, begin,
                      end) == 0;
  }

  // Use this as init_func when no initialization is needed.
  static Status NoInit(size_t num_threads) { return true; }

 private:
  // class holding the state of a Run() call to pass to the runner_ as an
  // opaque_jpegxl pointer.
  template <class InitFunc, class DataFunc>
  class RunCallState final {
   public:
    RunCallState(const InitFunc& init_func, const DataFunc& data_func)
        : init_func_(init_func), data_func_(data_func) {}

    // JxlParallelRunInit interface.
    static int CallInitFunc(void* jpegxl_opaque, size_t num_threads) {
      const auto* self =
          static_cast<RunCallState<InitFunc, DataFunc>*>(jpegxl_opaque);
      // Returns -1 when the internal init function returns false Status to
      // indicate an error.
      return self->init_func_(num_threads) ? 0 : -1;
    }

    // JxlParallelRunFunction interface.
    static void CallDataFunc(void* jpegxl_opaque, uint32_t value,
                             size_t thread_id) {
      const auto* self =
          static_cast<RunCallState<InitFunc, DataFunc>*>(jpegxl_opaque);
      return self->data_func_(value, thread_id);
    }

   private:
    const InitFunc& init_func_;
    const DataFunc& data_func_;
  };

  // Default JxlParallelRunner used when no runner is provided by the
  // caller. This runner doesn't use any threading and thread_id is always 0.
  static JxlParallelRetCode SequentialRunnerStatic(
      void* runner_opaque, void* jpegxl_opaque, JxlParallelRunInit init,
      JxlParallelRunFunction func, uint32_t start_range, uint32_t end_range);

  // The caller supplied runner function and its opaque void*.
  const JxlParallelRunner runner_;
  void* const runner_opaque_;
};

template <class InitFunc, class DataFunc>
Status RunOnPool(ThreadPool* pool, const uint32_t begin, const uint32_t end,
                 const InitFunc& init_func, const DataFunc& data_func,
                 const char* caller) {
  if (pool == nullptr) {
    ThreadPool default_pool(nullptr, nullptr);
    return default_pool.Run(begin, end, init_func, data_func, caller);
  } else {
    return pool->Run(begin, end, init_func, data_func, caller);
  }
}

}  // namespace jxl
#if JXL_COMPILER_MSVC
#pragma warning(default : 4180)
#endif

#endif  // LIB_JXL_BASE_DATA_PARALLEL_H_
