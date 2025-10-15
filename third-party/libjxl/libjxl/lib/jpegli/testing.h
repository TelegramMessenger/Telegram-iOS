// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_TESTING_H_
#define LIB_JPEGLI_TESTING_H_

// GTest/GMock specific macros / wrappers.

// gmock unconditionally redefines those macros (to wrong values).
// Lets include it only here and mitigate the problem.
#pragma push_macro("PRIdS")
#pragma push_macro("PRIuS")
#include "gmock/gmock.h"
#pragma pop_macro("PRIuS")
#pragma pop_macro("PRIdS")

#include "gtest/gtest.h"

// googletest before 1.10 didn't define INSTANTIATE_TEST_SUITE_P() but instead
// used INSTANTIATE_TEST_CASE_P which is now deprecated.
#ifdef INSTANTIATE_TEST_SUITE_P
#define JPEGLI_INSTANTIATE_TEST_SUITE_P INSTANTIATE_TEST_SUITE_P
#else
#define JPEGLI_INSTANTIATE_TEST_SUITE_P INSTANTIATE_TEST_CASE_P
#endif

// Ensures that we don't make our test bounds too lax, effectively disabling the
// tests.
MATCHER_P(IsSlightlyBelow, max, "") {
  return max * 0.75 <= arg && arg <= max * 1.0;
}

#endif  // LIB_JPEGLI_TESTING_H_
