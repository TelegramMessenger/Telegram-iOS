//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/misc.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/tests.h"

TEST(StringCleaning, clean_name) {
  ASSERT_EQ("@mention", td::clean_name("@mention", 1000000));
  ASSERT_EQ("@mention", td::clean_name("     @mention    ", 1000000));
  ASSERT_EQ("@MENTION", td::clean_name("@MENTION", 1000000));
  ASSERT_EQ("ЛШТШФУМ", td::clean_name("ЛШТШФУМ", 1000000));
  ASSERT_EQ("....", td::clean_name("....", 1000000));
  ASSERT_EQ(". ASD ..", td::clean_name(".   ASD   ..", 1000000));
  ASSERT_EQ(". ASD", td::clean_name(".   ASD   ..", 10));
  ASSERT_EQ(". ASD", td::clean_name(".\n\n\nASD\n\n\n..", 10));
  ASSERT_EQ("", td::clean_name("\n\n\n\n\n\n", 1000000));
  ASSERT_EQ("",
            td::clean_name("\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0\n\n\n\n\n\n      \n\xC2\xA0 \xC2\xA0 \n", 100000));
  ASSERT_EQ("abc", td::clean_name("\xC2\xA0\xC2\xA0"
                                  "abc\xC2\xA0\xC2\xA0\xC2\xA0\xC2\xA0",
                                  1000000));
}

TEST(StringCleaning, clean_username) {
  ASSERT_EQ("@mention", td::clean_username("@mention"));
  ASSERT_EQ("@mention", td::clean_username("     @mention    "));
  ASSERT_EQ("@mention", td::clean_username("@MENTION"));
  ASSERT_EQ("ЛШТШФУМ", td::clean_username("ЛШТШФУМ"));
  ASSERT_EQ("", td::clean_username("...."));
  ASSERT_EQ("asd", td::clean_username(".   ASD   .."));
}

static void check_clean_input_string(td::string str, const td::string &expected, bool expected_result) {
  auto result = td::clean_input_string(str);
  ASSERT_EQ(expected_result, result);
  if (result) {
    ASSERT_EQ(expected, str);
  }
}

TEST(StringCleaning, clean_input_string) {
  check_clean_input_string("/abc", "/abc", true);
  check_clean_input_string(td::string(50000, 'a'), td::string(34996, 'a'), true);
  check_clean_input_string("\xff", "", false);
  check_clean_input_string("\xc0\x80", "", false);
  check_clean_input_string("\xd0", "", false);
  check_clean_input_string("\xe0\xaf", "", false);
  check_clean_input_string("\xf0\xa6", "", false);
  check_clean_input_string("\xf0\xa6\x88", "", false);
  check_clean_input_string("\xf4\x8f\xbf\xbf", "\xf4\x8f\xbf\xbf", true);
  check_clean_input_string("\xf4\x8f\xbf\xc0", "", false);
  check_clean_input_string("\r\r\r\r\r\r\r", "", true);
  check_clean_input_string("\r\n\r\n\r\n\r\n\r\n\r\n\r", "\n\n\n\n\n\n", true);
  check_clean_input_string(td::Slice("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13"
                                     "\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21")
                               .str(),
                           "          \x0a                     \x21", true);
  check_clean_input_string(
      "\xe2\x80\xa7\xe2\x80\xa8\xe2\x80\xa9\xe2\x80\xaa\xe2\x80\xab\xe2\x80\xac\xe2\x80\xad\xe2\x80\xae\xe2\x80\xaf",
      "\xe2\x80\xa7\xe2\x80\xaf", true);
  check_clean_input_string(
      "\xe2\x80\x8f\xe2\x80\x8f  \xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8c \xe2\x80\x8f\xe2\x80\x8e "
      "\xe2\x80\x8f",
      "\xe2\x80\x8c\xe2\x80\x8f  \xe2\x80\x8c\xe2\x80\x8c\xe2\x80\x8e\xe2\x80\x8c \xe2\x80\x8c\xe2\x80\x8e "
      "\xe2\x80\x8f",
      true);
  check_clean_input_string("\xcc\xb3\xcc\xbf\xcc\x8a", "", true);
}

static void check_strip_empty_characters(td::string str, std::size_t max_length, const td::string &expected,
                                         bool strip_rtlo = false) {
  ASSERT_EQ(expected, td::strip_empty_characters(std::move(str), max_length, strip_rtlo));
}

TEST(StringCleaning, strip_empty_characters) {
  check_strip_empty_characters("/abc", 4, "/abc");
  check_strip_empty_characters("/abc", 3, "/ab");
  check_strip_empty_characters("/abc", 0, "");
  check_strip_empty_characters("/abc", 10000000, "/abc");
  td::string spaces =
      u8"\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u2800\u3000\uFFFC"
      u8"\uFFFC";
  td::string spaces_replace = "                   ";
  td::string rtlo = u8"\u202E";
  td::string empty = "\xE2\x80\x8B\xE2\x80\x8C\xE2\x80\x8D\xE2\x80\x8E\xE2\x80\x8F\xE2\x80\xAE\xC2\xA0\xC2\xA0";

  check_strip_empty_characters(spaces, 1000000, "");
  check_strip_empty_characters(spaces + rtlo, 1000000, "");
  check_strip_empty_characters(spaces + rtlo, 1000000, "", true);
  check_strip_empty_characters(spaces + rtlo + "a", 1000000, rtlo + "a");
  check_strip_empty_characters(spaces + rtlo + "a", 1000000, "a", true);
  check_strip_empty_characters(empty, 1000000, "");
  check_strip_empty_characters(empty + "a", 1000000, empty + "a");
  check_strip_empty_characters(spaces + empty + spaces + "abc" + spaces, 1000000, empty + spaces_replace + "abc");
  check_strip_empty_characters(spaces + spaces + empty + spaces + spaces + empty + empty, 1000000, "");
  check_strip_empty_characters("\r\r\r\r\r\r\r", 1000000, "");
  check_strip_empty_characters("\r\n\r\n\r\n\r\n\r\n\r\n\r", 1000000, "");
  check_strip_empty_characters(td::Slice(" \t\r\n\0\va\v\0\n\r\t ").str(), 1000000, "a");
  check_strip_empty_characters(td::Slice("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12"
                                         "\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21")
                                   .str(),
                               1000000,
                               "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14"
                               "\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21");
  check_strip_empty_characters("\xcc\xb3\xcc\xbf\xcc\x8a", 2, "\xcc\xb3\xcc\xbf");
  check_strip_empty_characters(
      "\xe2\x80\xa7\xe2\x80\xa8\xe2\x80\xa9\xe2\x80\xaa\xe2\x80\xab\xe2\x80\xac\xe2\x80\xad\xe2\x80\xae", 3,
      "\xe2\x80\xa7\xe2\x80\xa8\xe2\x80\xa9");
  check_strip_empty_characters(
      "\xF3\x9F\xBF\xBF\xF3\xA0\x80\x80\xF3\xA0\x80\x81\xF3\xA0\x80\xBF\xF3\xA0\x81\x80\xF3\xA0\x81\x81\xF3\xA0\x81\xBF"
      "\xF3\xA0\x82\x80",
      9, "\xF3\x9F\xBF\xBF      \xF3\xA0\x82\x80");
}
