// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_TESTING_H_
#define LIB_JXL_TESTING_H_

// GTest/GMock specific macros / wrappers.

// gmock unconditionally redefines those macros (to wrong values).
// Lets include it only here and mitigate the problem.
#pragma push_macro("PRIdS")
#pragma push_macro("PRIuS")
#include "gmock/gmock.h"
#pragma pop_macro("PRIuS")
#pragma pop_macro("PRIdS")

#include <sstream>

#include "gtest/gtest.h"

#ifdef JXL_DISABLE_SLOW_TESTS
#define JXL_SLOW_TEST(X) DISABLED_##X
#else
#define JXL_SLOW_TEST(X) X
#endif  // JXL_DISABLE_SLOW_TESTS

#if JPEGXL_ENABLE_TRANSCODE_JPEG
#define JXL_TRANSCODE_JPEG_TEST(X) X
#else
#define JXL_TRANSCODE_JPEG_TEST(X) DISABLED_##X
#endif  // JPEGXL_ENABLE_TRANSCODE_JPEG

#if JPEGXL_ENABLE_BOXES
#define JXL_BOXES_TEST(X) X
#else
#define JXL_BOXES_TEST(X) DISABLED_##X
#endif  // JPEGXL_ENABLE_BOXES

#ifdef THREAD_SANITIZER
#define JXL_TSAN_SLOW_TEST(X) DISABLED_##X
#else
#define JXL_TSAN_SLOW_TEST(X) X
#endif  // THREAD_SANITIZER

// googletest before 1.10 didn't define INSTANTIATE_TEST_SUITE_P() but instead
// used INSTANTIATE_TEST_CASE_P which is now deprecated.
#ifdef INSTANTIATE_TEST_SUITE_P
#define JXL_GTEST_INSTANTIATE_TEST_SUITE_P INSTANTIATE_TEST_SUITE_P
#else
#define JXL_GTEST_INSTANTIATE_TEST_SUITE_P INSTANTIATE_TEST_CASE_P
#endif

// Ensures that we don't make our test bounds too lax, effectively disabling the
// tests.
MATCHER_P(IsSlightlyBelow, max, "") {
  return max * 0.75 <= arg && arg <= max * 1.0;
}

#define JXL_EXPECT_OK(F)       \
  {                            \
    std::stringstream _;       \
    EXPECT_TRUE(F) << _.str(); \
  }

#define JXL_ASSERT_OK(F)       \
  {                            \
    std::stringstream _;       \
    ASSERT_TRUE(F) << _.str(); \
  }

#endif  // LIB_JXL_TESTING_H_
