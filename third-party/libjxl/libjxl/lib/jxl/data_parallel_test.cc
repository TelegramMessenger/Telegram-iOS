// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/data_parallel.h"

#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

class DataParallelTest : public ::testing::Test {
 protected:
  // A fake class to verify that DataParallel is properly calling the
  // client-provided runner functions.
  static int FakeRunner(void* runner_opaque, void* jpegxl_opaque,
                        JxlParallelRunInit init, JxlParallelRunFunction func,
                        uint32_t start_range, uint32_t end_range) {
    DataParallelTest* self = static_cast<DataParallelTest*>(runner_opaque);
    self->runner_called_++;
    self->jpegxl_opaque_ = jpegxl_opaque;
    self->init_ = init;
    self->func_ = func;
    self->start_range_ = start_range;
    self->end_range_ = end_range;
    return self->runner_return_;
  }

  ThreadPool pool_{&DataParallelTest::FakeRunner, this};

  // Number of times FakeRunner() was called.
  int runner_called_ = 0;

  // Parameters passed to FakeRunner.
  void* jpegxl_opaque_ = nullptr;
  JxlParallelRunInit init_ = nullptr;
  JxlParallelRunFunction func_ = nullptr;
  uint32_t start_range_ = -1;
  uint32_t end_range_ = -1;

  // Return value that FakeRunner will return.
  int runner_return_ = 0;
};

// JxlParallelRunInit interface.
typedef int (*JxlParallelRunInit)();

}  // namespace

TEST_F(DataParallelTest, RunnerCalledParameters) {
  EXPECT_TRUE(pool_.Run(
      1234, 5678, [](size_t /* num_threads */) { return true; },
      [](uint32_t /* task */, size_t /* thread */) { return; }));
  EXPECT_EQ(1, runner_called_);
  EXPECT_NE(nullptr, init_);
  EXPECT_NE(nullptr, func_);
  EXPECT_NE(nullptr, jpegxl_opaque_);
  EXPECT_EQ(1234u, start_range_);
  EXPECT_EQ(5678u, end_range_);
}

TEST_F(DataParallelTest, RunnerFailurePropagates) {
  runner_return_ = -1;  // FakeRunner return value.
  EXPECT_FALSE(pool_.Run(
      1234, 5678, [](size_t /* num_threads */) { return false; },
      [](uint32_t /* task */, size_t /* thread */) { return; }));
  EXPECT_FALSE(RunOnPool(
      nullptr, 1234, 5678, [](size_t /* num_threads */) { return false; },
      [](uint32_t /* task */, size_t /* thread */) { return; }, "Test"));
}

TEST_F(DataParallelTest, RunnerNotCalledOnEmptyRange) {
  runner_return_ = -1;  // FakeRunner return value.
  EXPECT_TRUE(pool_.Run(
      123, 123, [](size_t /* num_threads */) { return false; },
      [](uint32_t /* task */, size_t /* thread */) { return; }));
  EXPECT_TRUE(RunOnPool(
      nullptr, 123, 123, [](size_t /* num_threads */) { return false; },
      [](uint32_t /* task */, size_t /* thread */) { return; }, "Test"));
  // We don't call the external runner when the range is empty. We don't even
  // need to call the init function.
  EXPECT_EQ(0, runner_called_);
}

}  // namespace jxl
