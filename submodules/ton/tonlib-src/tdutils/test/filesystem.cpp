/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/utils/filesystem.h"
#include "td/utils/tests.h"

TEST(Misc, clean_filename) {
  using td::clean_filename;
  ASSERT_STREQ(clean_filename("-1234567"), "-1234567");
  ASSERT_STREQ(clean_filename(".git"), "git");
  ASSERT_STREQ(clean_filename("../../.git"), "git");
  ASSERT_STREQ(clean_filename(".././.."), "");
  ASSERT_STREQ(clean_filename("../"), "");
  ASSERT_STREQ(clean_filename(".."), "");
  ASSERT_STREQ(clean_filename("test/git/   as   dsa  .   a"), "as   dsa.a");
  ASSERT_STREQ(clean_filename("     .    "), "");
  ASSERT_STREQ(clean_filename("!@#$%^&*()_+-=[]{;|:\"}'<>?,.`~"), "!@#$%^  ()_+-=[]{;   }    ,.~");
  ASSERT_STREQ(clean_filename("!@#$%^&*()_+-=[]{}\\|:\";'<>?,.`~"), ";    ,.~");
  ASSERT_STREQ(clean_filename("عرفها بعد قد. هذا مع تاريخ اليميني واندونيسيا،, لعدم تاريخ لهيمنة الى"),
               "عرفها بعد قد.هذا مع تاريخ اليميني");
  ASSERT_STREQ(
      clean_filename(
          "012345678901234567890123456789012345678901234567890123456789adsasdasdsaa.01234567890123456789asdasdasdasd"),
      "012345678901234567890123456789012345678901234567890123456789.01234567890123456789");
  ASSERT_STREQ(clean_filename("01234567890123456789012345678901234567890123456789<>*?: <>*?:0123456789adsasdasdsaa.   "
                              "0123456789`<><<>><><>0123456789asdasdasdasd"),
               "01234567890123456789012345678901234567890123456789.0123456789");
  ASSERT_STREQ(clean_filename("01234567890123456789012345678901234567890123456789<>*?: <>*?:0123456789adsasdasdsaa.   "
                              "0123456789`<><><>0123456789asdasdasdasd"),
               "01234567890123456789012345678901234567890123456789.0123456789       012");
  ASSERT_STREQ(clean_filename("C:/document.tar.gz"), "document.tar.gz");
  ASSERT_STREQ(clean_filename("test...."), "test");
  ASSERT_STREQ(clean_filename("....test"), "test");
  ASSERT_STREQ(clean_filename("test.exe...."), "test.exe");  // extension has changed
  ASSERT_STREQ(clean_filename("test.exe01234567890123456789...."),
               "test.exe01234567890123456789");  // extension may be more then 20 characters
  ASSERT_STREQ(clean_filename("....test....asdf"), "test.asdf");
  ASSERT_STREQ(clean_filename("കറുപ്പ്.txt"), "കറപപ.txt");
}
