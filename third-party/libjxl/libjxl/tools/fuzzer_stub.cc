// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/thread_parallel_runner.h>
#include <jxl/thread_parallel_runner_cxx.h>

#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size);

void ProcessInput(const char* filename) {
  std::ifstream ifs(filename, std::ios::binary);
  std::vector<char> contents((std::istreambuf_iterator<char>(ifs)),
                             std::istreambuf_iterator<char>());
  ifs.close();
  std::cout << "Processing " << filename << std::endl;
  LLVMFuzzerTestOneInput(reinterpret_cast<uint8_t*>(contents.data()),
                         contents.size());
}

// Read files listed in args and pass their contents to "fuzzer".
int main(int argc, const char* argv[]) {
  if (argc == 2) {
    // No threaded runner for single inputs.
    ProcessInput(argv[1]);
  } else if (argc > 2) {
    auto runner = JxlThreadParallelRunnerMake(
        nullptr, JxlThreadParallelRunnerDefaultNumWorkerThreads());
    return JxlThreadParallelRunner(
        runner.get(), argv,
        /* init= */ +[](void*, size_t) -> JxlParallelRetCode { return 0; },
        /* func= */
        +[](void* opaque, uint32_t value, size_t) {
          const char** proc_argv = static_cast<const char**>(opaque);
          ProcessInput(proc_argv[value]);
        },
        /* start_range= */ 1, /* end_range= */ argc);
  }
  return 0;
}
