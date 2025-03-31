//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/filesystem.h"
#include "td/utils/Slice.h"
#include "td/utils/tests.h"

static void test_clean_filename(td::CSlice name, td::Slice result) {
  ASSERT_STREQ(td::clean_filename(name), result);
}

TEST(Misc, clean_filename) {
  test_clean_filename("-1234567", "-1234567");
  test_clean_filename(".git", "git");
  test_clean_filename("../../.git", "git");
  test_clean_filename(".././..", "");
  test_clean_filename("../", "");
  test_clean_filename("..", "");
  test_clean_filename("test/git/   as   dsa  .   a", "as   dsa.a");
  test_clean_filename("     .    ", "");
  test_clean_filename("!@#$%^&*()_+-=[]{;|:\"}'<>?,.`~", "!@#$%^  ()_+-=[]{;   }    ,.~");
  test_clean_filename("!@#$%^&*()_+-=[]{}\\|:\";'<>?,.`~", ";    ,.~");
  test_clean_filename("عرفها بعد قد. هذا مع تاريخ اليميني واندونيسيا،, لعدم تاريخ لهيمنة الى",
                      "عرفها بعد قد.هذا مع تاريخ الي");
  test_clean_filename(
      "012345678901234567890123456789012345678901234567890123456789adsasdasdsaa.01234567890123456789asdasdasdasd",
      "012345678901234567890123456789012345678901234567890123456789adsa.0123456789012345");
  test_clean_filename(
      "01234567890123456789012345678901234567890123456789adsa<>*?: <>*?:0123456789adsasdasdsaa.   "
      "0123456789`<><<>><><>0123456789asdasdasdasd",
      "01234567890123456789012345678901234567890123456789adsa.0123456789");
  test_clean_filename(
      "012345678901234567890123456789012345678901234567890123<>*?: <>*?:0123456789adsasdasdsaa.   "
      "0123456789`<>0123456789asdasdasdasd",
      "012345678901234567890123456789012345678901234567890123.0123456789   012");
  test_clean_filename("C:/document.tar.gz", "document.tar.gz");
  test_clean_filename("test....", "test");
  test_clean_filename("....test", "test");
  test_clean_filename("test.exe....", "test.exe");  // extension has changed
  test_clean_filename("test.exe01234567890123456789....",
                      "test.exe01234567890123456789");  // extension may be more than 16 characters
  test_clean_filename("....test....asdf", "test.asdf");
  test_clean_filename("കറുപ്പ്.txt", "കറപപ.txt");
}
