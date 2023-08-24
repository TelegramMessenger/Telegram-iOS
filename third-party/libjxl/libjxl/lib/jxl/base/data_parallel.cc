// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/data_parallel.h"

namespace jxl {

// static
JxlParallelRetCode ThreadPool::SequentialRunnerStatic(
    void* runner_opaque, void* jpegxl_opaque, JxlParallelRunInit init,
    JxlParallelRunFunction func, uint32_t start_range, uint32_t end_range) {
  JxlParallelRetCode init_ret = (*init)(jpegxl_opaque, 1);
  if (init_ret != 0) return init_ret;

  for (uint32_t i = start_range; i < end_range; i++) {
    (*func)(jpegxl_opaque, i, 0);
  }
  return 0;
}

}  // namespace jxl
