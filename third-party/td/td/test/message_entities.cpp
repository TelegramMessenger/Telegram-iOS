//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/MessageEntity.h"
#include "td/telegram/UserId.h"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tests.h"
#include "td/utils/utf8.h"

#include <algorithm>
#include <utility>

static void check_mention(const td::string &str, const td::vector<td::string> &expected) {
  auto result_slice = td::find_mentions(str);
  td::vector<td::string> result;
  for (auto &it : result_slice) {
    result.push_back(it.str());
  }
  if (result != expected) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result) << td::tag("expected", expected);
  }
}

TEST(MessageEntities, mention) {
  check_mention("@mention", {"@mention"});
  check_mention("@mention ", {"@mention"});
  check_mention(" @mention", {"@mention"});
  check_mention(" @mention ", {"@mention"});
  check_mention("@abc @xyz @abc @xyz @xxx@yyy @ttt", {});
  check_mention("@abcde @xyzxy @abcde @xyzxy @xxxxx@yyyyy @ttttt",
                {"@abcde", "@xyzxy", "@abcde", "@xyzxy", "@xxxxx", "@ttttt"});
  check_mention("no@mention", {});
  check_mention("@n", {});
  check_mention("@abcdefghijklmnopqrstuvwxyz123456", {"@abcdefghijklmnopqrstuvwxyz123456"});
  check_mention("@abcdefghijklmnopqrstuvwxyz1234567", {});
  check_mention("нет@mention", {});
  check_mention(
      "@ya @gif @wiki @vid @bing @pic @bold @imdb @ImDb @coub @like @vote @giff @cap ya cap @y @yar @bingg @bin",
      {"@gif", "@wiki", "@vid", "@bing", "@pic", "@bold", "@imdb", "@ImDb", "@coub", "@like", "@vote", "@giff",
       "@bingg"});
}

static void check_bot_command(const td::string &str, const td::vector<td::string> &expected) {
  auto result_slice = td::find_bot_commands(str);
  td::vector<td::string> result;
  for (auto &it : result_slice) {
    result.push_back(it.str());
  }
  if (result != expected) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result) << td::tag("expected", expected);
  }
}

TEST(MessageEntities, bot_command) {
  // 1..64@3..32
  check_bot_command("/abc", {"/abc"});
  check_bot_command(" /abc", {"/abc"});
  check_bot_command("/abc ", {"/abc"});
  check_bot_command(" /abc ", {"/abc"});
  check_bot_command("/a@abc", {"/a@abc"});
  check_bot_command("/a@b", {});
  check_bot_command("/@bfdsa", {});
  check_bot_command("/test/", {});
}

static void check_hashtag(const td::string &str, const td::vector<td::string> &expected) {
  auto result_slice = td::find_hashtags(str);
  td::vector<td::string> result;
  for (auto &it : result_slice) {
    result.push_back(it.str());
  }
  if (result != expected) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result) << td::tag("expected", expected);
  }
}

TEST(MessageEntities, hashtag) {
  check_hashtag("", {});
  check_hashtag("#", {});
  check_hashtag("##", {});
  check_hashtag("###", {});
  check_hashtag("#a", {"#a"});
  check_hashtag(" #a", {"#a"});
  check_hashtag("#a ", {"#a"});
  check_hashtag(" #я ", {"#я"});
  check_hashtag(" я#a ", {});
  check_hashtag(" #a# ", {});
  check_hashtag(" #123 ", {});
  check_hashtag(" #123a ", {"#123a"});
  check_hashtag(" #a123 ", {"#a123"});
  check_hashtag(" #123a# ", {});
  check_hashtag(" #" + td::string(300, '1'), {});
  check_hashtag(" #" + td::string(256, '1'), {});
  check_hashtag(" #" + td::string(256, '1') + "a ", {});
  check_hashtag(" #" + td::string(255, '1') + "a", {"#" + td::string(255, '1') + "a"});
  check_hashtag(" #" + td::string(255, '1') + "Я", {"#" + td::string(255, '1') + "Я"});
  check_hashtag(" #" + td::string(255, '1') + "a" + td::string(255, 'b') + "# ", {});
  check_hashtag("#a#b #c #d", {"#c", "#d"});
  check_hashtag("#test", {"#test"});
  check_hashtag("#test@", {"#test"});
  check_hashtag("#test@a", {"#test"});
  check_hashtag("#test@ab", {"#test"});
  check_hashtag("#test@abc", {"#test@abc"});
  check_hashtag("#test@a-c", {"#test"});
  check_hashtag("#test@abcdefghijabcdefghijabcdefghijab", {"#test@abcdefghijabcdefghijabcdefghijab"});
  check_hashtag("#test@abcdefghijabcdefghijabcdefghijabc", {"#test@abcdefghijabcdefghijabcdefghijab"});
  check_hashtag("#te·st", {"#te·st"});
  check_hashtag(u8"\U0001F604\U0001F604\U0001F604\U0001F604 \U0001F604\U0001F604\U0001F604#" + td::string(200, '1') +
                    "ООО" + td::string(200, '2'),
                {"#" + td::string(200, '1') + "ООО" + td::string(53, '2')});
  check_hashtag(u8"#a\u2122", {"#a"});
  check_hashtag("#a൹", {"#a"});
  check_hashtag("#aඁං෴ก฿", {"#aඁං෴ก"});
  check_hashtag(
      "#a12345678901234561234567890123456123456789012345612345678901234561234567890123456123456789012345612345678901234"
      "5612345678901234561234567890123456123456789012345612345678901234561234567890123456123456789012345612345678901234"
      "5612345678901234561234567890123456",
      {"#a1234567890123456123456789012345612345678901234561234567890123456123456789012345612345678901234561234567890123"
       "456123456789012345612345678901234561234567890123456123456789012345612345678901234561234567890123456123456789012"
       "34561234567890123456123456789012345"});
}

static void check_cashtag(const td::string &str, const td::vector<td::string> &expected) {
  auto result_slice = td::find_cashtags(str);
  td::vector<td::string> result;
  for (auto &it : result_slice) {
    result.push_back(it.str());
  }
  if (result != expected) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result) << td::tag("expected", expected);
  }
}

TEST(MessageEntities, cashtag) {
  check_cashtag("", {});
  check_cashtag("$", {});
  check_cashtag("$$", {});
  check_cashtag("$$$", {});
  check_cashtag("$a", {});
  check_cashtag(" $a", {});
  check_cashtag("$a ", {});
  check_cashtag(" $я ", {});
  check_cashtag("$ab", {});
  check_cashtag("$abc", {});
  check_cashtag("$", {});
  check_cashtag("$A", {"$A"});
  check_cashtag("$AB", {"$AB"});
  check_cashtag("$ABС", {});
  check_cashtag("$АBC", {});
  check_cashtag("$АВС", {});
  check_cashtag("$ABC", {"$ABC"});
  check_cashtag("$ABCD", {"$ABCD"});
  check_cashtag("$ABCDE", {"$ABCDE"});
  check_cashtag("$ABCDEF", {"$ABCDEF"});
  check_cashtag("$ABCDEFG", {"$ABCDEFG"});
  check_cashtag("$ABCDEFGH", {"$ABCDEFGH"});
  check_cashtag("$ABCDEFGHJ", {});
  check_cashtag("$ABCDEFGH1", {});
  check_cashtag(" $XYZ", {"$XYZ"});
  check_cashtag("$XYZ ", {"$XYZ"});
  check_cashtag(" $XYZ ", {"$XYZ"});
  check_cashtag(" $$XYZ ", {});
  check_cashtag(" $XYZ$ ", {});
  check_cashtag(" $ABC1 ", {});
  check_cashtag(" $1ABC ", {});
  check_cashtag(" 1$ABC ", {});
  check_cashtag(" А$ABC ", {});
  check_cashtag("$ABC$DEF $GHI $KLM", {"$GHI", "$KLM"});
  check_cashtag("$TEST", {"$TEST"});
  check_cashtag("$TEST@", {"$TEST"});
  check_cashtag("$TEST@a", {"$TEST"});
  check_cashtag("$TEST@ab", {"$TEST"});
  check_cashtag("$TEST@abc", {"$TEST@abc"});
  check_cashtag("$TEST@a-c", {"$TEST"});
  check_cashtag("$TEST@abcdefghijabcdefghijabcdefghijab", {"$TEST@abcdefghijabcdefghijabcdefghijab"});
  check_cashtag("$TEST@abcdefghijabcdefghijabcdefghijabc", {"$TEST"});
  check_cashtag("$1INC", {});
  check_cashtag("$1INCH", {"$1INCH"});
  check_cashtag("...$1INCH...", {"$1INCH"});
  check_cashtag("$1inch", {});
  check_cashtag("$1INCHA", {});
  check_cashtag("$1INCHА", {});
  check_cashtag(u8"$ABC\u2122", {"$ABC"});
  check_cashtag(u8"\u2122$ABC", {"$ABC"});
  check_cashtag(u8"\u2122$ABC\u2122", {"$ABC"});
  check_cashtag("$ABC൹", {"$ABC"});
  check_cashtag("$ABCඁ", {});
  check_cashtag("$ABCං", {});
  check_cashtag("$ABC෴", {});
  check_cashtag("$ABCก", {});
  check_cashtag("$ABC฿", {"$ABC"});
}

static void check_media_timestamp(const td::string &str, const td::vector<std::pair<td::string, td::int32>> &expected) {
  auto result = td::transform(td::find_media_timestamps(str),
                              [](auto &&entity) { return std::make_pair(entity.first.str(), entity.second); });
  if (result != expected) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result) << td::tag("expected", expected);
  }
}

TEST(MessageEntities, media_timestamp) {
  check_media_timestamp("", {});
  check_media_timestamp(":", {});
  check_media_timestamp(":1", {});
  check_media_timestamp("a:1", {});
  check_media_timestamp("01", {});
  check_media_timestamp("01:", {});
  check_media_timestamp("01::", {});
  check_media_timestamp("01::", {});
  check_media_timestamp("a1:1a", {});
  check_media_timestamp("a1::01a", {});
  check_media_timestamp("2001:db8::8a2e:f70:13a4", {});
  check_media_timestamp("0:00", {{"0:00", 0}});
  check_media_timestamp("+0:00", {{"0:00", 0}});
  check_media_timestamp("0:00+", {{"0:00", 0}});
  check_media_timestamp("a0:00", {});
  check_media_timestamp("0:00a", {});
  check_media_timestamp("б0:00", {});
  check_media_timestamp("0:00б", {});
  check_media_timestamp("_0:00", {});
  check_media_timestamp("0:00_", {});
  check_media_timestamp("00:00:00:00", {});
  check_media_timestamp("1:1:01 1:1:1", {{"1:1:01", 3661}});
  check_media_timestamp("0:0:00 00:00 000:00 0000:00 00000:00 00:00:00 000:00:00 00:000:00 00:00:000",
                        {{"0:0:00", 0}, {"00:00", 0}, {"000:00", 0}, {"0000:00", 0}, {"00:00:00", 0}});
  check_media_timestamp("00:0:00 0:00:00 00::00 :00:00 00:00: 00:00:0 00:00:", {{"00:0:00", 0}, {"0:00:00", 0}});
  check_media_timestamp("1:1:59 1:1:-1 1:1:60", {{"1:1:59", 3719}});
  check_media_timestamp("1:59:00 1:-1:00 1:60:00", {{"1:59:00", 7140}, {"1:00", 60}});
  check_media_timestamp("59:59 60:00", {{"59:59", 3599}, {"60:00", 3600}});
  check_media_timestamp("9999:59 99:59:59 99:60:59", {{"9999:59", 599999}, {"99:59:59", 360000 - 1}});
  check_media_timestamp("2001:db8::8a2e:f70:13a4", {});
}

static void check_bank_card_number(const td::string &str, const td::vector<td::string> &expected) {
  auto result_slice = td::find_bank_card_numbers(str);
  td::vector<td::string> result;
  for (auto &it : result_slice) {
    result.push_back(it.str());
  }
  if (result != expected) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result) << td::tag("expected", expected);
  }
}

TEST(MessageEntities, bank_card_number) {
  check_bank_card_number("", {});
  check_bank_card_number("123456789015", {});
  check_bank_card_number("1234567890120", {});
  check_bank_card_number("1234567890121", {});
  check_bank_card_number("1234567890122", {});
  check_bank_card_number("1234567890123", {});
  check_bank_card_number("1234567890124", {});
  check_bank_card_number("1234567890125", {});
  check_bank_card_number("1234567890126", {});
  check_bank_card_number("1234567890127", {});
  check_bank_card_number("1234567890128", {"1234567890128"});
  check_bank_card_number("1234567890129", {});
  check_bank_card_number("12345678901500", {"12345678901500"});
  check_bank_card_number("123456789012800", {"123456789012800"});
  check_bank_card_number("1234567890151800", {"1234567890151800"});
  check_bank_card_number("12345678901280000", {"12345678901280000"});
  check_bank_card_number("123456789015009100", {"123456789015009100"});
  check_bank_card_number("1234567890128000000", {"1234567890128000000"});
  check_bank_card_number("12345678901500910000", {});
  check_bank_card_number(" - - - - 1 - -- 2 - - -- 34 - - - 56- - 7890150000  - - - -", {});
  check_bank_card_number(" - - - - 1 - -- 234 - - 56- - 7890150000  - - - -", {"1 - -- 234 - - 56- - 7890150000"});
  check_bank_card_number("4916-3385-0608-2832; 5280 9342 8317 1080 ;345936346788903",
                         {"4916-3385-0608-2832", "5280 9342 8317 1080", "345936346788903"});
  check_bank_card_number("4556728228023269, 4916141675244747020, 49161416752447470, 4556728228023269",
                         {"4556728228023269", "4916141675244747020", "4556728228023269"});
  check_bank_card_number("a1234567890128", {});
  check_bank_card_number("1234567890128a", {});
  check_bank_card_number("1234567890128а", {});
  check_bank_card_number("а1234567890128", {});
  check_bank_card_number("1234567890128_", {});
  check_bank_card_number("_1234567890128", {});
  check_bank_card_number("1234567890128/", {"1234567890128"});
  check_bank_card_number("\"1234567890128", {"1234567890128"});
  check_bank_card_number("+1234567890128", {});
}

static void check_tg_url(const td::string &str, const td::vector<td::string> &expected) {
  auto result_slice = td::find_tg_urls(str);
  td::vector<td::string> result;
  for (auto &it : result_slice) {
    result.push_back(it.str());
  }
  if (result != expected) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result) << td::tag("expected", expected);
  }
}

TEST(MessageEntities, tg_url) {
  check_tg_url("", {});
  check_tg_url("tg://", {});
  check_tg_url("tg://a", {"tg://a"});
  check_tg_url("a", {});
  check_tg_url("stg://a", {"tg://a"});
  check_tg_url("asd  asdas das ton:asd tg:test ton://resolve tg://resolve TON://_-RESOLVE_- TG://-_RESOLVE-_",
               {"ton://resolve", "tg://resolve", "TON://_-RESOLVE_-", "TG://-_RESOLVE-_"});
  check_tg_url("tg:test/", {});
  check_tg_url("tg:/test/", {});
  check_tg_url("tg://test/", {"tg://test/"});
  check_tg_url("tg://test/?", {"tg://test/"});
  check_tg_url("tg://test/#", {"tg://test/#"});
  check_tg_url("tg://test?", {"tg://test"});
  check_tg_url("tg://test#", {"tg://test"});
  check_tg_url("tg://test/―asd―?asd=asd&asdas=―#――――", {"tg://test/―asd―?asd=asd&asdas=―#――――"});
  check_tg_url("tg://test/?asd", {"tg://test/?asd"});
  check_tg_url("tg://test/?.:;,('?!`.:;,('?!`", {"tg://test/"});
  check_tg_url("tg://test/#asdf", {"tg://test/#asdf"});
  check_tg_url("tg://test?asdf", {"tg://test?asdf"});
  check_tg_url("tg://test#asdf", {"tg://test#asdf"});
  check_tg_url("tg://test?as‖df", {"tg://test?as"});
  check_tg_url("tg://test?sa<df", {"tg://test?sa"});
  check_tg_url("tg://test?as>df", {"tg://test?as"});
  check_tg_url("tg://test?as\"df", {"tg://test?as"});
  check_tg_url("tg://test?as«df", {"tg://test?as"});
  check_tg_url("tg://test?as»df", {"tg://test?as"});
  check_tg_url("tg://test?as(df", {"tg://test?as(df"});
  check_tg_url("tg://test?as)df", {"tg://test?as)df"});
  check_tg_url("tg://test?as[df", {"tg://test?as[df"});
  check_tg_url("tg://test?as]df", {"tg://test?as]df"});
  check_tg_url("tg://test?as{df", {"tg://test?as{df"});
  check_tg_url("tg://test?as'df", {"tg://test?as'df"});
  check_tg_url("tg://test?as}df", {"tg://test?as}df"});
  check_tg_url("tg://test?as$df", {"tg://test?as$df"});
  check_tg_url("tg://test?as%df", {"tg://test?as%df"});
  check_tg_url("tg://%30/sccct", {});
  check_tg_url("tg://test:asd@google.com:80", {"tg://test"});
  check_tg_url("tg://google.com", {"tg://google"});
  check_tg_url("tg://google/.com", {"tg://google/.com"});
  check_tg_url("tg://127.0.0.1", {"tg://127"});
  check_tg_url("tg://б.а.н.а.на", {});
}

static void check_is_email_address(const td::string &str, bool expected) {
  bool result = td::is_email_address(str);
  LOG_IF(FATAL, result != expected) << "Expected " << expected << " as result of is_email_address(" << str << ")";
}

TEST(MessageEntities, is_email_address) {
  check_is_email_address("telegram.org", false);
  check_is_email_address("security@telegram.org", true);
  check_is_email_address("security.telegram.org", false);
  check_is_email_address("", false);
  check_is_email_address("@", false);
  check_is_email_address("A@a.a.a.ab", true);
  check_is_email_address("A@a.ab", true);
  check_is_email_address("Test@aa.aa.aa.aa", true);
  check_is_email_address("Test@test.abd", true);
  check_is_email_address("a@a.a.a.ab", true);
  check_is_email_address("test@test.abd", true);
  check_is_email_address("test@test.com", true);
  check_is_email_address("test.abd", false);
  check_is_email_address("a.ab", false);
  check_is_email_address("a.bc@d.ef", true);

  td::vector<td::string> bad_userdatas = {"",
                                          "a.a.a.a.a.a.a.a.a.a.a.a",
                                          "+.+.+.+.+.+",
                                          "*.a.a",
                                          "a.*.a",
                                          "a.a.*",
                                          "a.a.",
                                          "a.a.abcdefghijklmnopqrstuvwxyz0123456789",
                                          "a.abcdefghijklmnopqrstuvwxyz0.a",
                                          "abcdefghijklmnopqrstuvwxyz0.a.a"};
  td::vector<td::string> good_userdatas = {"a.a.a.a.a.a.a.a.a.a.a",
                                           "a+a+a+a+a+a+a+a+a+a+a",
                                           "+.+.+.+.+._",
                                           "aozAQZ0-5-9_+-aozAQZ0-5-9_.aozAQZ0-5-9_.-._.+-",
                                           "a.a.a",
                                           "a.a.abcdefghijklmnopqrstuvwxyz012345678",
                                           "a.abcdefghijklmnopqrstuvwxyz.a",
                                           "a..a",
                                           "abcdefghijklmnopqrstuvwxyz.a.a",
                                           ".a.a"};

  td::vector<td::string> bad_domains = {"",
                                        ".",
                                        "abc",
                                        "localhost",
                                        "a.a.a.a.a.a.a.ab",
                                        ".......",
                                        "a.a.a.a.a.a+ab",
                                        "a+a.a.a.a.a.ab",
                                        "a.a.a.a.a.a.a",
                                        "a.a.a.a.a.a.abcdefghi",
                                        "a.a.a.a.a.a.ab0yz",
                                        "a.a.a.a.a.a.ab9yz",
                                        "a.a.a.a.a.a.ab-yz",
                                        "a.a.a.a.a.a.ab_yz",
                                        "a.a.a.a.a.a.ab*yz",
                                        ".ab",
                                        ".a.ab",
                                        "a..ab",
                                        "a.a.a..a.ab",
                                        ".a.a.a.a.ab",
                                        "abcdefghijklmnopqrstuvwxyz01234.ab",
                                        "ab0cd.abd.aA*sd.0.9.0-9.ABOYZ",
                                        "ab*cd.abd.aAasd.0.9.0-9.ABOYZ",
                                        "ab0cd.abd.aAasd.0.9.0*9.ABOYZ",
                                        "*b0cd.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0c*.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9.0-*.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9.*-9.ABOYZ",
                                        "-b0cd.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0c-.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.-.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9.--9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9.0--.ABOYZ",
                                        "_b0cd.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0c_.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd._.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9._-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9.0-_.ABOYZ",
                                        "-.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.-.0.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9.-.ABOYZ",
                                        "_.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                        "ab0cd.ab_d._.0.9.0-9.ABOYZ",
                                        "ab0cd.ab_d.aA-sd.0.9._.ABOYZ"};
  td::vector<td::string> good_domains = {"a.a.a.a.a.a.ab",
                                         "a.a.a.a.a.a.abcdef",
                                         "a.a.a.a.a.a.aboyz",
                                         "a.a.a.a.a.a.ABOYZ",
                                         "a.a.a.a.a.a.AbOyZ",
                                         "abcdefghijklmnopqrstuvwxyz0123.ab",
                                         "ab0cd.ab_d.aA-sd.0.9.0-9.ABOYZ",
                                         "A.Z.aA-sd.a.z.0-9.ABOYZ"};

  for (auto &userdata : bad_userdatas) {
    for (auto &domain : bad_domains) {
      check_is_email_address(userdata + '@' + domain, false);
      check_is_email_address(userdata + domain, false);
    }
    for (auto &domain : good_domains) {
      check_is_email_address(userdata + '@' + domain, false);
      check_is_email_address(userdata + domain, false);
    }
  }
  for (auto &userdata : good_userdatas) {
    for (auto &domain : bad_domains) {
      check_is_email_address(userdata + '@' + domain, false);
      check_is_email_address(userdata + domain, false);
    }
    for (auto &domain : good_domains) {
      check_is_email_address(userdata + '@' + domain, true);
      check_is_email_address(userdata + domain, false);
    }
  }
}

static void check_url(const td::string &str, const td::vector<td::string> &expected_urls,
                      td::vector<td::string> expected_email_addresses = {}) {
  auto result_slice = td::find_urls(str);
  td::vector<td::string> result_urls;
  td::vector<td::string> result_email_addresses;
  for (auto &it : result_slice) {
    if (!it.second) {
      result_urls.push_back(it.first.str());
    } else {
      result_email_addresses.push_back(it.first.str());
    }
  }
  if (result_urls != expected_urls) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result_urls) << td::tag("expected", expected_urls);
  }
  if (result_email_addresses != expected_email_addresses) {
    LOG(FATAL) << td::tag("text", str) << td::tag("receive", result_email_addresses)
               << td::tag("expected", expected_email_addresses);
  }
}

TEST(MessageEntities, url) {
  check_url("telegram.org", {"telegram.org"});
  check_url("(telegram.org)", {"telegram.org"});
  check_url("\ntelegram.org)", {"telegram.org"});
  check_url(" telegram.org)", {"telegram.org"});
  check_url(".telegram.org)", {});
  check_url("()telegram.org/?q=()", {"telegram.org/?q=()"});
  check_url("\"telegram.org\"", {"telegram.org"});
  check_url(" telegram. org. www. com... telegram.org... ...google.com...", {"telegram.org"});
  check_url(" telegram.org ", {"telegram.org"});
  check_url("Такой сайт: http://www.google.com или такой telegram.org ", {"http://www.google.com", "telegram.org"});
  check_url(" telegram.org. ", {"telegram.org"});
  check_url("http://google,.com", {});
  check_url("http://telegram.org/?asd=123#123.", {"http://telegram.org/?asd=123#123"});
  check_url("[http://google.com](test)", {"http://google.com"});
  check_url("", {});
  check_url(".", {});
  check_url("http://@google.com", {});
  check_url("http://@goog.com", {});  // TODO: server fix
  check_url("http://@@google.com", {});
  check_url("http://a@google.com", {"http://a@google.com"});
  check_url("http://test@google.com", {"http://test@google.com"});
  check_url("google.com:᪉᪉᪉᪉᪉", {"google.com"});
  check_url("https://telegram.org", {"https://telegram.org"});
  check_url("http://telegram.org", {"http://telegram.org"});
  check_url("ftp://telegram.org", {"ftp://telegram.org"});
  check_url("ftps://telegram.org", {});
  check_url("sftp://telegram.org", {});
  check_url("tonsite://telegram.ton", {"tonsite://telegram.ton"});
  check_url("telegram.ton", {"telegram.ton"});
  check_url("telegram.onion", {"telegram.onion"});
  check_url("telegram.tonsite", {});
  check_url("hTtPs://telegram.org", {"hTtPs://telegram.org"});
  check_url("HTTP://telegram.org", {"HTTP://telegram.org"});
  check_url("аHTTP://telegram.org", {"HTTP://telegram.org"});
  check_url("sHTTP://telegram.org", {});
  check_url("://telegram.org", {});
  check_url("google.com:᪀᪀", {"google.com"});
  check_url(
      "http://"
      "abcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkab"
      "cdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcd"
      "efghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdef"
      "ghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefgh"
      "ijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghij"
      "kabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijka"
      "bcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabc"
      "defghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijkabcdefghijk.com",
      {});
  check_url("http://  .com", {});
  check_url("URL:     .com", {});
  check_url("URL: .com", {});
  check_url(".com", {});
  check_url("http://  .", {});
  check_url("http://.", {});
  check_url("http://.com", {});
  check_url("http://  .", {});
  check_url(",ahttp://google.com", {"http://google.com"});
  check_url(".ahttp://google.com", {});
  check_url("http://1.0", {});
  check_url("http://a.0", {});
  check_url("http://a.a", {});
  check_url("google.com:1#ab c", {"google.com:1#ab"});
  check_url("google.com:1#", {"google.com:1"});
  check_url("google.com:1#1", {"google.com:1#1"});
  check_url("google.com:00000001/abs", {"google.com:00000001/abs"});
  check_url("google.com:000000065535/abs", {"google.com:000000065535/abs"});
  check_url("google.com:000000065536/abs", {"google.com"});
  check_url("google.com:000000080/abs", {"google.com:000000080/abs"});
  check_url("google.com:0000000/abs", {"google.com"});
  check_url("google.com:0/abs", {"google.com"});
  check_url("google.com:/abs", {"google.com"});
  check_url("google.com:65535", {"google.com:65535"});
  check_url("google.com:65536", {"google.com"});
  check_url("google.com:99999", {"google.com"});
  check_url("google.com:100000", {"google.com"});
  check_url("127.001", {});
  check_url("127.0.0.1", {"127.0.0.1"});
  check_url("127.0.0.01", {});
  check_url("127.0.0.256", {});
  check_url("127.0.0.300", {});
  check_url("127.0.0.1000", {});
  check_url("127.0.0.260", {});
  check_url("1.0", {});
  check_url("www.🤙.tk", {"www.🤙.tk"});
  check_url("a.ab", {});
  check_url("test.abd", {});
  check_url("ТеСт.Москва", {});
  check_url("ТеСт.МоСкВΑ", {});
  check_url("ТеСт.МоСкВа", {"ТеСт.МоСкВа"});
  check_url("ТеСт.МоСкВач", {});
  check_url("http://ÀТеСт.МоСкВач", {"http://ÀТеСт.МоСкВач"});
  check_url("ÀÁ.com. ÀÁ.com.", {"ÀÁ.com", "ÀÁ.com"});
  check_url("ÀÁ.com,ÀÁ.com.", {"ÀÁ.com", "ÀÁ.com"});
  check_url("teiegram.org/test", {});
  check_url("TeiegraM.org/test", {});
  check_url("http://test.google.com/?q=abc()}[]def", {"http://test.google.com/?q=abc()"});
  check_url("http://test.google.com/?q=abc([{)]}def", {"http://test.google.com/?q=abc([{)]}def"});
  check_url("http://test.google.com/?q=abc(){}]def", {"http://test.google.com/?q=abc(){}"});
  check_url("http://test.google.com/?q=abc){}[]def", {"http://test.google.com/?q=abc"});
  check_url("http://test.google.com/?q=abc(){}[]def", {"http://test.google.com/?q=abc(){}[]def"});
  check_url("http://test-.google.com", {});
  check_url("http://test_.google.com", {"http://test_.google.com"});
  check_url("http://google_.com", {});
  check_url("http://google._com_", {});
  check_url("http://[2001:4860:0:2001::68]/", {});  // TODO
  check_url("tg://resolve", {});
  check_url("test.abd", {});
  check_url("/.b/..a    @.....@/. a.ba", {"a.ba"});
  check_url("bbbbbbbbbbbbbb.@.@", {});
  check_url("http://google.com/", {"http://google.com/"});
  check_url("http://google.com?", {"http://google.com"});
  check_url("http://google.com#", {"http://google.com"});
  check_url("http://google.com##", {"http://google.com##"});
  check_url("http://google.com/?", {"http://google.com/"});
  check_url("https://www.google.com/ab,", {"https://www.google.com/ab"});
  check_url("@.", {});
  check_url(
      "a.b.google.com dfsknnfs gsdfgsg http://códuia.de/ dffdg,\" 12)(cpia.de/())(\" http://гришка.рф/ sdufhdf "
      "http://xn--80afpi2a3c.xn--p1ai/ I have a good time.Thanks, guys!\n\n(hdfughidufhgdis) go#ogle.com гришка.рф "
      "hsighsdf gi почта.рф\n\n✪df.ws/123      "
      "xn--80afpi2a3c.xn--p1ai\n\nhttp://foo.com/blah_blah\nhttp://foo.com/blah_blah/\n(Something like "
      "http://foo.com/blah_blah)\nhttp://foo.com/blah_blah_(wikipedi8989a_Вася)\n(Something like "
      "http://foo.com/blah_blah_(Стакан_007))\nhttp://foo.com/blah_blah.\nhttp://foo.com/blah_blah/.\n<http://foo.com/"
      "blah_blah>\n<http://fo@@@@@@@@@^%#*@^&@$#*@#%^*&!^#o.com/blah_blah/>\nhttp://foo.com/blah_blah,\nhttp://"
      "www.example.com/wpstyle/?p=364.\nhttp://✪df.ws/123\nrdar://1234\nrdar:/1234\nhttp://"
      "userid:password@example.com:8080\nhttp://userid@example.com\nhttp://userid@example.com:8080\nhttp://"
      "userid:password@example.com\nhttp://example.com:8080 "
      "x-yojimbo-item://6303E4C1-xxxx-45A6-AB9D-3A908F59AE0E\nmessage://"
      "%3c330e7f8409726r6a4ba78dkf1fd71420c1bf6ff@mail.gmail.com%3e\nhttp://➡️.ws/䨹\nwww.➡️.ws/"
      "䨹\n<tag>http://example.com</tag>\nJust a www.example.com "
      "link.\n\n➡️.ws/"
      "䨹\n\nabcdefghijklmnopqrstuvwxyz0123456789qwe_sdfsdf.aweawe-sdfs.com\nwww.🤙.tk:1\ngoogle.com:"
      "᪉᪉᪉᪉\ngoogle."
      "com:᪀᪀\nhttp://  .com\nURL:     .com\nURL: "
      ".com\n\ngoogle.com?qwe\ngoogle.com#qwe\ngoogle.com/?\ngoogle.com/#\ngoogle.com?\ngoogle.com#\n",
      {"a.b.google.com",
       "http://códuia.de/",
       "cpia.de/()",
       "http://гришка.рф/",
       "http://xn--80afpi2a3c.xn--p1ai/",
       "гришка.рф",
       "почта.рф",
       "✪df.ws/123",
       "xn--80afpi2a3c.xn--p1ai",
       "http://foo.com/blah_blah",
       "http://foo.com/blah_blah/",
       "http://foo.com/blah_blah",
       "http://foo.com/blah_blah_(wikipedi8989a_Вася)",
       "http://foo.com/blah_blah_(Стакан_007)",
       "http://foo.com/blah_blah",
       "http://foo.com/blah_blah/",
       "http://foo.com/blah_blah",
       "http://foo.com/blah_blah",
       "http://www.example.com/wpstyle/?p=364",
       "http://✪df.ws/123",
       "http://userid:password@example.com:8080",
       "http://userid@example.com",
       "http://userid@example.com:8080",
       "http://userid:password@example.com",
       "http://example.com:8080",
       "http://➡️.ws/䨹",
       "www.➡️.ws/䨹",
       "http://example.com",
       "www.example.com",
       "➡️.ws/䨹",
       "abcdefghijklmnopqrstuvwxyz0123456789qwe_sdfsdf.aweawe-sdfs.com",
       "www.🤙.tk:1",
       "google.com",
       "google.com",
       "google.com?qwe",
       "google.com#qwe",
       "google.com/",
       "google.com/#",
       "google.com",
       "google.com"});
  check_url("https://t.…", {});
  check_url("('http://telegram.org/a-b/?br=ie&lang=en',)", {"http://telegram.org/a-b/?br=ie&lang=en"});
  check_url("https://ai.telegram.org/bot%20bot/test-...", {"https://ai.telegram.org/bot%20bot/test-"});
  check_url("a.bc@c.com", {}, {"a.bc@c.com"});
  check_url("https://a.bc@c.com", {"https://a.bc@c.com"});
  check_url("https://a.de[bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.de/bc@c.com", {"https://a.de/bc@c.com"});
  check_url("https://a.de]bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.de{bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.de}bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.de(bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.de)bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.debc@c.com", {"https://a.debc@c.com"});
  check_url("https://a.de'bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.de`bc@c.com", {"https://a.de"}, {"bc@c.com"});
  check_url("https://a.bcde.fg@c.com", {"https://a.bcde.fg@c.com"});
  check_url("https://a:h.bcde.fg@c.com", {"https://a:h.bcde.fg@c.com"});
  check_url("https://abc@c.com", {"https://abc@c.com"});
  check_url("https://de[bc@c.com", {}, {"bc@c.com"});
  check_url("https://de/bc@c.com", {});
  check_url("https://de]bc@c.com", {}, {"bc@c.com"});
  check_url("https://de{bc@c.com", {}, {"bc@c.com"});
  check_url("https://de}bc@c.com", {}, {"bc@c.com"});
  check_url("https://de(bc@c.com", {}, {"bc@c.com"});
  check_url("https://de)bc@c.com", {}, {"bc@c.com"});
  check_url("https://de\\bc@c.com", {"https://de\\bc@c.com"});
  check_url("https://de'bc@c.com", {}, {"bc@c.com"});
  check_url("https://de`bc@c.com", {}, {"bc@c.com"});
  check_url("https://bc:defg@c.com", {"https://bc:defg@c.com"});
  check_url("https://a:hbc:defg@c.com", {"https://a:hbc:defg@c.com"});
  check_url("https://a.bc@test.com:cd.com", {"https://a.bc@test.com", "cd.com"});
  check_url("telegram.Org", {});
  check_url("telegram.ORG", {"telegram.ORG"});
  check_url("a.b.c.com.a.b.c", {});
  check_url("File '/usr/views.py'", {});  // TODO server fix
  check_url("@views.py'", {});            // TODO server fix
  check_url("#views.py'", {});            // TODO server fix
  check_url("/views.py'", {});            // TODO server fix
  check_url(".views.py", {});
  check_url("'views.py'", {"views.py"});
  check_url("bug.http://test.com/test/+#", {});  // TODO {"http://test.com/test/+#"}
  check_url("//AB.C.D.E.F.GH//", {});
  check_url("<http://www.ics.uci.edu/pub/ietf/uri/historical.html#WARNING>",
            {"http://www.ics.uci.edu/pub/ietf/uri/historical.html#WARNING"});
  check_url("Look :test@example.com", {":test@example.com"}, {});  // TODO {}, {"test@example.com"}
  check_url("Look mailto:test@example.com", {}, {"test@example.com"});
  check_url("http://test.com#a", {"http://test.com#a"});
  check_url("http://test.com#", {"http://test.com"});
  check_url("http://test.com?#", {"http://test.com?#"});
  check_url("http://test.com/?#", {"http://test.com/?#"});
  check_url("https://t.me/abcdef…", {"https://t.me/abcdef"});
  check_url("https://t.me…", {"https://t.me"});
  check_url("https://t.m…", {});
  check_url("https://t.…", {});
  check_url("https://t…", {});
  check_url("👉http://ab.com/cdefgh-1IJ", {"http://ab.com/cdefgh-1IJ"});
  check_url("...👉http://ab.com/cdefgh-1IJ", {});  // TODO
  check_url(".?", {});
  check_url("http://test―‑@―google―.―com―/―–―‐―/―/―/―?―‑―#―――", {"http://test―‑@―google―.―com―/―–―‐―/―/―/―?―‑―#―――"});
  check_url("http://google.com/‖", {"http://google.com/"});
  check_url("a@b@c.com", {}, {});
  check_url("abc@c.com@d.com", {});
  check_url("a@b.com:c@1", {}, {"a@b.com"});
  check_url("test@test.software", {}, {"test@test.software"});
  check_url("a:b?@gmail.com", {});
  check_url("a?:b@gmail.com", {});
  check_url("a#:b@gmail.com", {});
  check_url("a:b#@gmail.com", {});
  check_url("a!:b@gmail.com", {"a!:b@gmail.com"});
  check_url("a:b!@gmail.com", {"a:b!@gmail.com"});
  check_url("http://test_.com", {});
  check_url("test_.com", {});
  check_url("_test.com", {});
  check_url("_.test.com", {"_.test.com"});
}

static void check_fix_formatted_text(td::string str, td::vector<td::MessageEntity> entities,
                                     const td::string &expected_str,
                                     const td::vector<td::MessageEntity> &expected_entities, bool allow_empty = true,
                                     bool skip_new_entities = false, bool skip_bot_commands = false,
                                     bool skip_trim = true) {
  ASSERT_TRUE(td::fix_formatted_text(str, entities, allow_empty, skip_new_entities, skip_bot_commands, true, skip_trim)
                  .is_ok());
  ASSERT_STREQ(expected_str, str);
  ASSERT_EQ(expected_entities, entities);
}

static void check_fix_formatted_text(td::string str, td::vector<td::MessageEntity> entities, bool allow_empty,
                                     bool skip_new_entities, bool skip_bot_commands, bool skip_trim) {
  ASSERT_TRUE(td::fix_formatted_text(str, entities, allow_empty, skip_new_entities, skip_bot_commands, true, skip_trim)
                  .is_error());
}

TEST(MessageEntities, fix_formatted_text) {
  td::string str;
  td::string fixed_str;
  for (auto i = 0; i <= 32; i++) {
    str += static_cast<char>(i);
    if (i != 13) {
      if (i != 10) {
        fixed_str += ' ';
      } else {
        fixed_str += str.back();
      }
    }
  }

  check_fix_formatted_text(str, {}, "", {}, true, true, true, true);
  check_fix_formatted_text(str, {}, "", {}, true, true, false, true);
  check_fix_formatted_text(str, {}, "", {}, true, false, true, true);
  check_fix_formatted_text(str, {}, "", {}, true, false, false, true);
  check_fix_formatted_text(str, {}, "", {}, true, false, false, false);
  check_fix_formatted_text(str, {}, false, false, false, false);
  check_fix_formatted_text(str, {}, false, false, false, true);

  check_fix_formatted_text("  aba\n ", {}, "  aba\n ", {}, true, true, true, true);
  check_fix_formatted_text("  aba\n ", {}, "aba", {}, true, true, true, false);
  check_fix_formatted_text("  \n ", {}, "", {}, true, true, true, true);
  check_fix_formatted_text("  \n ", {}, "", {}, true, true, true, false);
  check_fix_formatted_text("  \n ", {}, false, true, true, false);

  str += "a  \r\n  ";
  fixed_str += "a  \n  ";

  for (td::int32 i = 33; i <= 35; i++) {
    td::vector<td::MessageEntity> entities;
    entities.emplace_back(td::MessageEntity::Type::Pre, 0, i);

    td::vector<td::MessageEntity> fixed_entities = entities;
    fixed_entities.back().length = i - 1;
    check_fix_formatted_text(str, entities, fixed_str, fixed_entities, true, false, false, true);

    td::string expected_str = fixed_str.substr(0, 33);
    fixed_entities.back().length = i == 33 ? 32 : 33;
    check_fix_formatted_text(str, entities, expected_str, fixed_entities, false, false, false, false);
  }

  for (td::int32 i = 33; i <= 35; i++) {
    td::vector<td::MessageEntity> entities;
    entities.emplace_back(td::MessageEntity::Type::Bold, 0, i);

    td::vector<td::MessageEntity> fixed_entities;
    fixed_entities.emplace_back(td::MessageEntity::Type::Bold, 0, i - 1 /* deleted \r */);
    check_fix_formatted_text(str, entities, fixed_str, fixed_entities, true, false, false, true);

    td::string expected_str = fixed_str.substr(0, 33);
    if (i != 33) {
      fixed_entities.back().length = 33;
    }
    check_fix_formatted_text(str, entities, expected_str, fixed_entities, false, false, false, false);
  }

  str = "👉 👉  ";
  for (int i = 0; i < 10; i++) {
    td::vector<td::MessageEntity> entities;
    entities.emplace_back(td::MessageEntity::Type::Bold, i, 1);
    if (i != 2 && i != 5 && i != 6) {
      check_fix_formatted_text(str, entities, true, true, true, true);
      check_fix_formatted_text(str, entities, false, false, false, false);
    } else {
      check_fix_formatted_text(str, entities, str, {{td::MessageEntity::Type::Bold, i, 1}}, true, true, true, true);
      if (i == 2) {
        check_fix_formatted_text(str, entities, str.substr(0, str.size() - 2), {{td::MessageEntity::Type::Bold, i, 1}},
                                 false, false, false, false);
      } else {
        check_fix_formatted_text(str, entities, str.substr(0, str.size() - 2), {}, false, false, false, false);
      }
    }
  }

  str = "  /test @abaca #ORD $ABC  telegram.org ";
  for (auto skip_trim : {false, true}) {
    td::int32 shift = skip_trim ? 2 : 0;
    td::string expected_str = skip_trim ? str : str.substr(2, str.size() - 3);

    for (auto skip_new_entities : {false, true}) {
      for (auto skip_bot_commands : {false, true}) {
        td::vector<td::MessageEntity> entities;
        if (!skip_new_entities) {
          if (!skip_bot_commands) {
            entities.emplace_back(td::MessageEntity::Type::BotCommand, shift, 5);
          }
          entities.emplace_back(td::MessageEntity::Type::Mention, shift + 6, 6);
          entities.emplace_back(td::MessageEntity::Type::Hashtag, shift + 13, 4);
          entities.emplace_back(td::MessageEntity::Type::Cashtag, shift + 18, 4);
          entities.emplace_back(td::MessageEntity::Type::Url, shift + 24, 12);
        }

        check_fix_formatted_text(str, {}, expected_str, entities, true, skip_new_entities, skip_bot_commands,
                                 skip_trim);
        check_fix_formatted_text(str, {}, expected_str, entities, false, skip_new_entities, skip_bot_commands,
                                 skip_trim);
      }
    }
  }

  str = "aba \r\n caba ";
  td::UserId user_id(static_cast<td::int64>(1));
  for (td::int32 length = 1; length <= 3; length++) {
    for (td::int32 offset = 0; static_cast<size_t>(offset + length) <= str.size(); offset++) {
      for (auto type : {td::MessageEntity::Type::Bold, td::MessageEntity::Type::Url, td::MessageEntity::Type::TextUrl,
                        td::MessageEntity::Type::MentionName}) {
        for (auto skip_trim : {false, true}) {
          fixed_str = skip_trim ? "aba \n caba " : "aba \n caba";
          auto fixed_length = offset <= 4 && offset + length >= 5 ? length - 1 : length;
          auto fixed_offset = offset >= 5 ? offset - 1 : offset;
          while (static_cast<size_t>(fixed_offset + fixed_length) > fixed_str.size()) {
            fixed_length--;
          }

          td::vector<td::MessageEntity> entities;
          entities.emplace_back(type, offset, length);
          if (type == td::MessageEntity::Type::TextUrl) {
            entities.back().argument = "t.me";
          } else if (type == td::MessageEntity::Type::MentionName) {
            entities.back().user_id = user_id;
          }
          td::vector<td::MessageEntity> fixed_entities;
          if (fixed_length > 0) {
            fixed_entities.emplace_back(type, fixed_offset, fixed_length);
            if (type == td::MessageEntity::Type::TextUrl) {
              fixed_entities.back().argument = "t.me";
            } else if (type == td::MessageEntity::Type::MentionName) {
              fixed_entities.back().user_id = user_id;
            }
          }
          check_fix_formatted_text(str, entities, fixed_str, fixed_entities, true, false, false, skip_trim);
        }
      }
    }
  }

  str = "aba caba";
  for (td::int32 length = -10; length <= 10; length++) {
    for (td::int32 offset = -10; offset <= 10; offset++) {
      td::vector<td::MessageEntity> entities;
      entities.emplace_back(td::MessageEntity::Type::Bold, offset, length);
      if (length < 0 || offset < 0 || (length > 0 && static_cast<size_t>(length + offset) > str.size())) {
        check_fix_formatted_text(str, entities, true, false, false, false);
        check_fix_formatted_text(str, entities, false, false, false, true);
        continue;
      }

      td::vector<td::MessageEntity> fixed_entities;
      if (length > 0) {
        fixed_entities.emplace_back(td::MessageEntity::Type::Bold, offset, length);
      }

      check_fix_formatted_text(str, entities, str, fixed_entities, true, false, false, false);
      check_fix_formatted_text(str, entities, str, fixed_entities, false, false, false, true);
    }
  }

  str = "abadcaba";
  for (td::int32 length = 1; length <= 7; length++) {
    for (td::int32 offset = 0; offset <= 8 - length; offset++) {
      for (td::int32 length2 = 1; length2 <= 7; length2++) {
        for (td::int32 offset2 = 0; offset2 <= 8 - length2; offset2++) {
          if (offset != offset2) {
            td::vector<td::MessageEntity> entities;
            entities.emplace_back(td::MessageEntity::Type::TextUrl, offset, length, "t.me");
            entities.emplace_back(td::MessageEntity::Type::TextUrl, offset2, length2, "t.me");
            entities.emplace_back(td::MessageEntity::Type::TextUrl, offset2 + length2, 1);
            td::vector<td::MessageEntity> fixed_entities = entities;
            fixed_entities.pop_back();
            std::sort(fixed_entities.begin(), fixed_entities.end());
            if (fixed_entities[0].offset + fixed_entities[0].length > fixed_entities[1].offset) {
              fixed_entities.pop_back();
            }
            check_fix_formatted_text(str, entities, str, fixed_entities, false, false, false, false);
          }
        }
      }
    }
  }

  for (auto text : {" \n ➡️ ➡️ ➡️ ➡️  \n ", "\n\n\nab cd ef gh        "}) {
    str = text;
    td::vector<td::MessageEntity> entities;
    td::vector<td::MessageEntity> fixed_entities;

    auto length = td::narrow_cast<int>(td::utf8_utf16_length(str));
    for (int i = 0; i < 10; i++) {
      if ((i + 1) * 3 + 2 <= length) {
        entities.emplace_back(td::MessageEntity::Type::Bold, (i + 1) * 3, 2);
      }
      if ((i + 2) * 3 <= length) {
        entities.emplace_back(td::MessageEntity::Type::Italic, (i + 1) * 3 + 2, 1);
      }

      if (i < 4) {
        fixed_entities.emplace_back(td::MessageEntity::Type::Bold, i * 3, 2);
      }
      if (i < 3) {
        fixed_entities.emplace_back(td::MessageEntity::Type::Italic, i * 3 + 2, 1);
      }
    }

    check_fix_formatted_text(str, entities, td::utf8_utf16_substr(str, 3, 11).str(), fixed_entities, false, false,
                             false, false);
  }

  for (td::string text : {"\t", "\r", "\n", "\t ", "\r ", "\n "}) {
    for (auto type : {td::MessageEntity::Type::Bold, td::MessageEntity::Type::TextUrl}) {
      check_fix_formatted_text(text, {{type, 0, 1, "http://telegram.org/"}}, "", {}, true, false, false, true);
    }
  }
  check_fix_formatted_text("\r ", {{td::MessageEntity::Type::Bold, 0, 2}, {td::MessageEntity::Type::Underline, 0, 1}},
                           "", {}, true, false, false, true);
  check_fix_formatted_text("a \r", {{td::MessageEntity::Type::Bold, 0, 3}, {td::MessageEntity::Type::Underline, 2, 1}},
                           "a ", {{td::MessageEntity::Type::Bold, 0, 2}}, true, false, false, true);
  check_fix_formatted_text("a \r ", {{td::MessageEntity::Type::Bold, 0, 4}, {td::MessageEntity::Type::Underline, 2, 1}},
                           "a  ", {{td::MessageEntity::Type::Bold, 0, 3}}, true, false, false, true);
  check_fix_formatted_text("a \r b",
                           {{td::MessageEntity::Type::Bold, 0, 5}, {td::MessageEntity::Type::Underline, 2, 1}}, "a  b",
                           {{td::MessageEntity::Type::Bold, 0, 4}}, true, false, false, true);

  check_fix_formatted_text("a\rbc\r",
                           {{td::MessageEntity::Type::Italic, 0, 1},
                            {td::MessageEntity::Type::Bold, 0, 2},
                            {td::MessageEntity::Type::Italic, 3, 2},
                            {td::MessageEntity::Type::Bold, 3, 1}},
                           "abc",
                           {{td::MessageEntity::Type::Bold, 0, 1},
                            {td::MessageEntity::Type::Italic, 0, 1},
                            {td::MessageEntity::Type::Bold, 2, 1},
                            {td::MessageEntity::Type::Italic, 2, 1}});
  check_fix_formatted_text("a ", {{td::MessageEntity::Type::Italic, 0, 2}, {td::MessageEntity::Type::Bold, 0, 1}}, "a",
                           {{td::MessageEntity::Type::Bold, 0, 1}, {td::MessageEntity::Type::Italic, 0, 1}}, false,
                           false, false, false);
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 1, 1}, {td::MessageEntity::Type::Italic, 0, 1}},
                           "abc", {{td::MessageEntity::Type::Italic, 0, 2}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 1, 1}, {td::MessageEntity::Type::Italic, 1, 1}},
                           "abc", {{td::MessageEntity::Type::Italic, 1, 1}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 0, 2}, {td::MessageEntity::Type::Italic, 1, 2}},
                           "abc", {{td::MessageEntity::Type::Italic, 0, 3}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 0, 2}, {td::MessageEntity::Type::Italic, 2, 1}},
                           "abc", {{td::MessageEntity::Type::Italic, 0, 3}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 0, 1}, {td::MessageEntity::Type::Italic, 2, 1}},
                           "abc", {{td::MessageEntity::Type::Italic, 0, 1}, {td::MessageEntity::Type::Italic, 2, 1}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 0, 2}, {td::MessageEntity::Type::Bold, 1, 2}},
                           "abc",
                           {{td::MessageEntity::Type::Italic, 0, 1},
                            {td::MessageEntity::Type::Bold, 1, 2},
                            {td::MessageEntity::Type::Italic, 1, 1}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 0, 2}, {td::MessageEntity::Type::Bold, 2, 1}},
                           "abc", {{td::MessageEntity::Type::Italic, 0, 2}, {td::MessageEntity::Type::Bold, 2, 1}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Italic, 0, 1}, {td::MessageEntity::Type::Bold, 2, 1}},
                           "abc", {{td::MessageEntity::Type::Italic, 0, 1}, {td::MessageEntity::Type::Bold, 2, 1}});
  check_fix_formatted_text("@tests @tests", {{td::MessageEntity::Type::Italic, 0, 13}}, "@tests @tests",
                           {{td::MessageEntity::Type::Mention, 0, 6},
                            {td::MessageEntity::Type::Italic, 0, 6},
                            {td::MessageEntity::Type::Italic, 6, 1},
                            {td::MessageEntity::Type::Mention, 7, 6},
                            {td::MessageEntity::Type::Italic, 7, 6}});

  // __a~b~__
  check_fix_formatted_text(
      "ab", {{td::MessageEntity::Type::Underline, 0, 2}, {td::MessageEntity::Type::Strikethrough, 1, 1}}, "ab",
      {{td::MessageEntity::Type::Underline, 0, 1},
       {td::MessageEntity::Type::Underline, 1, 1},
       {td::MessageEntity::Type::Strikethrough, 1, 1}});
  check_fix_formatted_text("ab",
                           {{td::MessageEntity::Type::Underline, 0, 1},
                            {td::MessageEntity::Type::Underline, 1, 1},
                            {td::MessageEntity::Type::Strikethrough, 1, 1}},
                           "ab",
                           {{td::MessageEntity::Type::Underline, 0, 1},
                            {td::MessageEntity::Type::Underline, 1, 1},
                            {td::MessageEntity::Type::Strikethrough, 1, 1}});
  check_fix_formatted_text(
      "ab", {{td::MessageEntity::Type::Strikethrough, 0, 2}, {td::MessageEntity::Type::Underline, 1, 1}}, "ab",
      {{td::MessageEntity::Type::Strikethrough, 0, 1},
       {td::MessageEntity::Type::Underline, 1, 1},
       {td::MessageEntity::Type::Strikethrough, 1, 1}});
  check_fix_formatted_text("ab",
                           {{td::MessageEntity::Type::Strikethrough, 0, 1},
                            {td::MessageEntity::Type::Strikethrough, 1, 1},
                            {td::MessageEntity::Type::Underline, 1, 1}},
                           "ab",
                           {{td::MessageEntity::Type::Strikethrough, 0, 1},
                            {td::MessageEntity::Type::Underline, 1, 1},
                            {td::MessageEntity::Type::Strikethrough, 1, 1}});

  // __||a||b__
  check_fix_formatted_text("ab", {{td::MessageEntity::Type::Underline, 0, 2}, {td::MessageEntity::Type::Spoiler, 0, 1}},
                           "ab",
                           {{td::MessageEntity::Type::Underline, 0, 2}, {td::MessageEntity::Type::Spoiler, 0, 1}});
  check_fix_formatted_text("ab",
                           {{td::MessageEntity::Type::Underline, 0, 1},
                            {td::MessageEntity::Type::Underline, 1, 1},
                            {td::MessageEntity::Type::Spoiler, 0, 1}},
                           "ab",
                           {{td::MessageEntity::Type::Underline, 0, 2}, {td::MessageEntity::Type::Spoiler, 0, 1}});

  // _*a*_\r_*b*_
  check_fix_formatted_text("a\rb",
                           {{td::MessageEntity::Type::Bold, 0, 1},
                            {td::MessageEntity::Type::Italic, 0, 1},
                            {td::MessageEntity::Type::Bold, 2, 1},
                            {td::MessageEntity::Type::Italic, 2, 1}},
                           "ab", {{td::MessageEntity::Type::Bold, 0, 2}, {td::MessageEntity::Type::Italic, 0, 2}});
  check_fix_formatted_text("a\nb",
                           {{td::MessageEntity::Type::Bold, 0, 1},
                            {td::MessageEntity::Type::Italic, 0, 1},
                            {td::MessageEntity::Type::Bold, 2, 1},
                            {td::MessageEntity::Type::Italic, 2, 1}},
                           "a\nb",
                           {{td::MessageEntity::Type::Bold, 0, 1},
                            {td::MessageEntity::Type::Italic, 0, 1},
                            {td::MessageEntity::Type::Bold, 2, 1},
                            {td::MessageEntity::Type::Italic, 2, 1}});

  // ||`a`||
  check_fix_formatted_text("a", {{td::MessageEntity::Type::Pre, 0, 1}, {td::MessageEntity::Type::Spoiler, 0, 1}}, "a",
                           {{td::MessageEntity::Type::Pre, 0, 1}});
  check_fix_formatted_text("a", {{td::MessageEntity::Type::Spoiler, 0, 1}, {td::MessageEntity::Type::Pre, 0, 1}}, "a",
                           {{td::MessageEntity::Type::Pre, 0, 1}});

  check_fix_formatted_text("abc",
                           {{td::MessageEntity::Type::Pre, 0, 3}, {td::MessageEntity::Type::Strikethrough, 1, 1}},
                           "abc", {{td::MessageEntity::Type::Pre, 0, 3}});
  check_fix_formatted_text(
      "abc", {{td::MessageEntity::Type::Pre, 1, 1}, {td::MessageEntity::Type::Strikethrough, 0, 3}}, "abc",
      {{td::MessageEntity::Type::Strikethrough, 0, 1},
       {td::MessageEntity::Type::Pre, 1, 1},
       {td::MessageEntity::Type::Strikethrough, 2, 1}});
  check_fix_formatted_text(
      "abc", {{td::MessageEntity::Type::Pre, 1, 1}, {td::MessageEntity::Type::Strikethrough, 1, 2}}, "abc",
      {{td::MessageEntity::Type::Pre, 1, 1}, {td::MessageEntity::Type::Strikethrough, 2, 1}});
  check_fix_formatted_text(
      "abc", {{td::MessageEntity::Type::Pre, 1, 1}, {td::MessageEntity::Type::Strikethrough, 0, 2}}, "abc",
      {{td::MessageEntity::Type::Strikethrough, 0, 1}, {td::MessageEntity::Type::Pre, 1, 1}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::Pre, 0, 3}, {td::MessageEntity::Type::BlockQuote, 1, 1}},
                           "abc", {{td::MessageEntity::Type::BlockQuote, 1, 1}});
  check_fix_formatted_text("abc", {{td::MessageEntity::Type::BlockQuote, 0, 3}, {td::MessageEntity::Type::Pre, 1, 1}},
                           "abc", {{td::MessageEntity::Type::BlockQuote, 0, 3}, {td::MessageEntity::Type::Pre, 1, 1}});

  check_fix_formatted_text("example.com", {}, "example.com", {{td::MessageEntity::Type::Url, 0, 11}});
  check_fix_formatted_text("example.com", {{td::MessageEntity::Type::Pre, 0, 3}}, "example.com",
                           {{td::MessageEntity::Type::Pre, 0, 3}});
  check_fix_formatted_text("example.com", {{td::MessageEntity::Type::BlockQuote, 0, 3}}, "example.com",
                           {{td::MessageEntity::Type::BlockQuote, 0, 3}});
  check_fix_formatted_text("example.com", {{td::MessageEntity::Type::BlockQuote, 0, 11}}, "example.com",
                           {{td::MessageEntity::Type::BlockQuote, 0, 11}, {td::MessageEntity::Type::Url, 0, 11}});
  check_fix_formatted_text("example.com", {{td::MessageEntity::Type::Italic, 0, 11}}, "example.com",
                           {{td::MessageEntity::Type::Url, 0, 11}, {td::MessageEntity::Type::Italic, 0, 11}});
  check_fix_formatted_text("example.com", {{td::MessageEntity::Type::Italic, 0, 3}}, "example.com",
                           {{td::MessageEntity::Type::Url, 0, 11}, {td::MessageEntity::Type::Italic, 0, 3}});
  check_fix_formatted_text("example.com a", {{td::MessageEntity::Type::Italic, 0, 13}}, "example.com a",
                           {{td::MessageEntity::Type::Url, 0, 11},
                            {td::MessageEntity::Type::Italic, 0, 11},
                            {td::MessageEntity::Type::Italic, 11, 2}});
  check_fix_formatted_text("a example.com", {{td::MessageEntity::Type::Italic, 0, 13}}, "a example.com",
                           {{td::MessageEntity::Type::Italic, 0, 2},
                            {td::MessageEntity::Type::Url, 2, 11},
                            {td::MessageEntity::Type::Italic, 2, 11}});

  for (size_t test_n = 0; test_n < 100000; test_n++) {
    bool is_url = td::Random::fast_bool();
    td::int32 url_offset = 0;
    td::int32 url_end = 0;
    if (is_url) {
      str = td::string(td::Random::fast(1, 5), 'a') + ":example.com:" + td::string(td::Random::fast(1, 5), 'a');
      url_offset = static_cast<td::int32>(str.find('e'));
      url_end = url_offset + 11;
    } else {
      str = td::string(td::Random::fast(1, 20), 'a');
    }

    auto n = td::Random::fast(1, 20);
    td::vector<td::MessageEntity> entities;
    for (int j = 0; j < n; j++) {
      td::int32 type = td::Random::fast(4, static_cast<int>(td::MessageEntity::Type::Size) - 1);
      td::int32 offset = td::Random::fast(0, static_cast<int>(str.size()) - 1);
      auto max_length = static_cast<int>(str.size() - offset);
      if ((test_n & 1) != 0 && max_length > 4) {
        max_length = 4;
      }
      td::int32 length = td::Random::fast(0, max_length);
      entities.emplace_back(static_cast<td::MessageEntity::Type>(type), offset, length);
    }

    auto get_type_mask = [](std::size_t length, const td::vector<td::MessageEntity> &entities) {
      td::vector<td::int32> result(length);
      for (auto &entity : entities) {
        for (auto pos = 0; pos < entity.length; pos++) {
          result[entity.offset + pos] |= (1 << static_cast<td::int32>(entity.type));
        }
      }
      return result;
    };
    auto old_type_mask = get_type_mask(str.size(), entities);
    ASSERT_TRUE(td::fix_formatted_text(str, entities, false, false, true, true, false).is_ok());
    auto new_type_mask = get_type_mask(str.size(), entities);
    auto splittable_mask = (1 << 5) | (1 << 6) | (1 << 14) | (1 << 15) | (1 << 19);
    auto pre_mask = (1 << 7) | (1 << 8) | (1 << 9);
    for (std::size_t pos = 0; pos < str.size(); pos++) {
      if ((new_type_mask[pos] & pre_mask) != 0) {
        ASSERT_EQ(0, new_type_mask[pos] & splittable_mask);
      } else {
        ASSERT_EQ(old_type_mask[pos] & splittable_mask, new_type_mask[pos] & splittable_mask);
      }
    }
    bool keep_url = is_url;
    td::MessageEntity url_entity(td::MessageEntity::Type::Url, url_offset, url_end - url_offset);
    for (auto &entity : entities) {
      if (entity == url_entity) {
        continue;
      }
      td::int32 offset = entity.offset;
      td::int32 end = offset + entity.length;

      if (keep_url && ((1 << static_cast<td::int32>(entity.type)) & splittable_mask) == 0 &&
          !(end <= url_offset || url_end <= offset)) {
        keep_url = ((entity.type == td::MessageEntity::Type::BlockQuote ||
                     entity.type == td::MessageEntity::Type::ExpandableBlockQuote) &&
                    offset <= url_offset && url_end <= end);
      }
    }
    ASSERT_EQ(keep_url, std::count(entities.begin(), entities.end(), url_entity) == 1);

    for (size_t i = 0; i < entities.size(); i++) {
      auto type_mask = 1 << static_cast<td::int32>(entities[i].type);
      for (size_t j = i + 1; j < entities.size(); j++) {
        // sorted
        ASSERT_TRUE(entities[j].offset > entities[i].offset ||
                    (entities[j].offset == entities[i].offset && entities[j].length <= entities[i].length));

        // not intersecting
        ASSERT_TRUE(entities[j].offset >= entities[i].offset + entities[i].length ||
                    entities[j].offset + entities[j].length <= entities[i].offset + entities[i].length);

        if (entities[j].offset < entities[i].offset + entities[i].length) {  // if nested
          // types are different
          ASSERT_TRUE(entities[j].type != entities[i].type);

          // pre can't contain other entities
          ASSERT_TRUE((type_mask & pre_mask) == 0);

          if ((type_mask & splittable_mask) == 0 && entities[i].type != td::MessageEntity::Type::BlockQuote &&
              entities[i].type != td::MessageEntity::Type::ExpandableBlockQuote) {
            // continuous entities can contain only splittable entities
            ASSERT_TRUE(((1 << static_cast<td::int32>(entities[j].type)) & splittable_mask) != 0);
          }
        }
      }
    }
  }

  check_fix_formatted_text(
      "\xe2\x80\x8f\xe2\x80\x8f  \xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8c \xe2\x80\x8f\xe2\x80\x8e "
      "\xe2\x80\x8f a",
      {},
      "\xe2\x80\x8c\xe2\x80\x8f  \xe2\x80\x8c\xe2\x80\x8c\xe2\x80\x8e\xe2\x80\x8c \xe2\x80\x8c\xe2\x80\x8e "
      "\xe2\x80\x8f a",
      {});
  check_fix_formatted_text(
      "\xe2\x80\x8f\xe2\x80\x8f  \xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8c \xe2\x80\x8f\xe2\x80\x8e "
      "\xe2\x80\x8f",
      {}, false, false, false, true);
  check_fix_formatted_text(
      "\xe2\x80\x8f\xe2\x80\x8f  \xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8e\xe2\x80\x8c \xe2\x80\x8f\xe2\x80\x8e "
      "\xe2\x80\x8f",
      {}, "", {});
}

TEST(MessageEntities, is_visible_url) {
  td::string str = "a telegram.org telegran.org telegrao.org telegram.orc telegrap.org c";
  td::vector<td::MessageEntity> entities;
  entities.emplace_back(td::MessageEntity::Type::TextUrl, 0, 1, "telegrab.org");
  entities.emplace_back(td::MessageEntity::Type::TextUrl, static_cast<td::int32>(str.size()) - 1, 1, "telegrax.org");
  td::fix_formatted_text(str, entities, false, false, false, false, true).ensure();
  td::FormattedText text{std::move(str), std::move(entities)};
  ASSERT_EQ(td::get_first_url(text), "telegrab.org");
  ASSERT_TRUE(!td::is_visible_url(text, "telegrab.org"));
  ASSERT_TRUE(td::is_visible_url(text, "telegram.org"));
  ASSERT_TRUE(td::is_visible_url(text, "telegran.org"));
  ASSERT_TRUE(td::is_visible_url(text, "telegrao.org"));
  ASSERT_TRUE(!td::is_visible_url(text, "telegram.orc"));
  ASSERT_TRUE(td::is_visible_url(text, "telegrap.org"));
  ASSERT_TRUE(!td::is_visible_url(text, "telegraf.org"));
  ASSERT_TRUE(!td::is_visible_url(text, "telegrax.org"));
}

static void check_parse_html(td::string text, const td::string &result, const td::vector<td::MessageEntity> &entities) {
  auto r_entities = td::parse_html(text);
  ASSERT_TRUE(r_entities.is_ok());
  ASSERT_EQ(entities, r_entities.ok());
  ASSERT_STREQ(result, text);
}

static void check_parse_html(td::string text, td::Slice error_message) {
  auto r_entities = td::parse_html(text);
  ASSERT_TRUE(r_entities.is_error());
  ASSERT_EQ(400, r_entities.error().code());
  ASSERT_STREQ(error_message, r_entities.error().message());
}

TEST(MessageEntities, parse_html) {
  td::string invalid_surrogate_pair_error_message =
      "Text contains invalid Unicode characters after decoding HTML entities, check for unmatched surrogate code units";
  check_parse_html("&#57311;", invalid_surrogate_pair_error_message);
  check_parse_html("&#xDFDF;", invalid_surrogate_pair_error_message);
  check_parse_html("&#xDFDF", invalid_surrogate_pair_error_message);
  check_parse_html("🏟 🏟&lt;<abacaba", "Unclosed start tag at byte offset 13");
  check_parse_html("🏟 🏟&lt;<abac aba>", "Unsupported start tag \"abac\" at byte offset 13");
  check_parse_html("🏟 🏟&lt;<abac>", "Unsupported start tag \"abac\" at byte offset 13");
  check_parse_html("🏟 🏟&lt;<i   =aba>", "Empty attribute name in the tag \"i\" at byte offset 13");
  check_parse_html("🏟 🏟&lt;<i    aba>", "Can't find end tag corresponding to start tag \"i\"");
  check_parse_html("🏟 🏟&lt;<i    aba  =  ", "Unclosed start tag \"i\" at byte offset 13");
  check_parse_html("🏟 🏟&lt;<i    aba  =  190azAz-.,", "Unexpected end of name token at byte offset 27");
  check_parse_html("🏟 🏟&lt;<i    aba  =  \"&lt;&gt;&quot;>", "Unclosed start tag at byte offset 13");
  check_parse_html("🏟 🏟&lt;<i    aba  =  \'&lt;&gt;&quot;>", "Unclosed start tag at byte offset 13");
  check_parse_html("🏟 🏟&lt;</", "Unexpected end tag at byte offset 13");
  check_parse_html("🏟 🏟&lt;<b></b></", "Unexpected end tag at byte offset 20");
  check_parse_html("🏟 🏟&lt;<i>a</i   ", "Unclosed end tag at byte offset 17");
  check_parse_html("🏟 🏟&lt;<i>a</em   >", "Unmatched end tag at byte offset 17, expected \"</i>\", found \"</em>\"");

  check_parse_html("", "", {});
  check_parse_html("➡️ ➡️", "➡️ ➡️", {});
  check_parse_html("&ge;&lt;&gt;&amp;&quot;&laquo;&raquo;&#12345678;", "&ge;<>&\"&laquo;&raquo;&#12345678;", {});
  check_parse_html("&Or;", "&Or;", {});
  check_parse_html("➡️ ➡️<i>➡️ ➡️</i>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Italic, 5, 5}});
  check_parse_html("➡️ ➡️<em>➡️ ➡️</em>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Italic, 5, 5}});
  check_parse_html("➡️ ➡️<b>➡️ ➡️</b>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Bold, 5, 5}});
  check_parse_html("➡️ ➡️<strong>➡️ ➡️</strong>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Bold, 5, 5}});
  check_parse_html("➡️ ➡️<u>➡️ ➡️</u>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Underline, 5, 5}});
  check_parse_html("➡️ ➡️<ins>➡️ ➡️</ins>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Underline, 5, 5}});
  check_parse_html("➡️ ➡️<s>➡️ ➡️</s>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Strikethrough, 5, 5}});
  check_parse_html("➡️ ➡️<strike>➡️ ➡️</strike>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Strikethrough, 5, 5}});
  check_parse_html("➡️ ➡️<del>➡️ ➡️</del>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Strikethrough, 5, 5}});
  check_parse_html("➡️ ➡️<blockquote>➡️ ➡️</blockquote>", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::BlockQuote, 5, 5}});
  check_parse_html("➡️ ➡️<i>➡️ ➡️</i><b>➡️ ➡️</b>", "➡️ ➡️➡️ ➡️➡️ ➡️",
                   {{td::MessageEntity::Type::Italic, 5, 5}, {td::MessageEntity::Type::Bold, 10, 5}});
  check_parse_html("🏟 🏟<i>🏟 &lt🏟</i>", "🏟 🏟🏟 <🏟", {{td::MessageEntity::Type::Italic, 5, 6}});
  check_parse_html("🏟 🏟<i>🏟 &gt;<b aba   =   caba>&lt🏟</b></i>", "🏟 🏟🏟 ><🏟",
                   {{td::MessageEntity::Type::Italic, 5, 7}, {td::MessageEntity::Type::Bold, 9, 3}});
  check_parse_html("🏟 🏟&lt;<i    aba  =  190azAz-.   >a</i>", "🏟 🏟<a", {{td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_html("🏟 🏟&lt;<i    aba  =  190azAz-.>a</i>", "🏟 🏟<a", {{td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_html("🏟 🏟&lt;<i    aba  =  \"&lt;&gt;&quot;\">a</i>", "🏟 🏟<a",
                   {{td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_html("🏟 🏟&lt;<i    aba  =  '&lt;&gt;&quot;'>a</i>", "🏟 🏟<a",
                   {{td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_html("🏟 🏟&lt;<i    aba  =  '&lt;&gt;&quot;'>a</>", "🏟 🏟<a",
                   {{td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_html("🏟 🏟&lt;<i>🏟 🏟&lt;</>", "🏟 🏟<🏟 🏟<", {{td::MessageEntity::Type::Italic, 6, 6}});
  check_parse_html("🏟 🏟&lt;<i>a</    >", "🏟 🏟<a", {{td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_html("🏟 🏟&lt;<i>a</i   >", "🏟 🏟<a", {{td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_html("🏟 🏟&lt;<b></b>", "🏟 🏟<", {});
  check_parse_html("<i>\t</i>", "\t", {{td::MessageEntity::Type::Italic, 0, 1}});
  check_parse_html("<i>\r</i>", "\r", {{td::MessageEntity::Type::Italic, 0, 1}});
  check_parse_html("<i>\n</i>", "\n", {{td::MessageEntity::Type::Italic, 0, 1}});
  check_parse_html("➡️ ➡️<span class = \"tg-spoiler\">➡️ ➡️</span><b>➡️ ➡️</b>", "➡️ ➡️➡️ ➡️➡️ ➡️",
                   {{td::MessageEntity::Type::Spoiler, 5, 5}, {td::MessageEntity::Type::Bold, 10, 5}});
  check_parse_html("🏟 🏟<span class=\"tg-spoiler\">🏟 &lt🏟</span>", "🏟 🏟🏟 <🏟",
                   {{td::MessageEntity::Type::Spoiler, 5, 6}});
  check_parse_html("🏟 🏟<span class=\"tg-spoiler\">🏟 &gt;<b aba   =   caba>&lt🏟</b></span>", "🏟 🏟🏟 ><🏟",
                   {{td::MessageEntity::Type::Spoiler, 5, 7}, {td::MessageEntity::Type::Bold, 9, 3}});
  check_parse_html("➡️ ➡️<tg-spoiler>➡️ ➡️</tg-spoiler><b>➡️ ➡️</b>", "➡️ ➡️➡️ ➡️➡️ ➡️",
                   {{td::MessageEntity::Type::Spoiler, 5, 5}, {td::MessageEntity::Type::Bold, 10, 5}});
  check_parse_html("🏟 🏟<tg-spoiler>🏟 &lt🏟</tg-spoiler>", "🏟 🏟🏟 <🏟", {{td::MessageEntity::Type::Spoiler, 5, 6}});
  check_parse_html("🏟 🏟<tg-spoiler>🏟 &gt;<b aba   =   caba>&lt🏟</b></tg-spoiler>", "🏟 🏟🏟 ><🏟",
                   {{td::MessageEntity::Type::Spoiler, 5, 7}, {td::MessageEntity::Type::Bold, 9, 3}});
  check_parse_html("<a href=telegram.org>\t</a>", "\t",
                   {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/"}});
  check_parse_html("<a href=telegram.org>\r</a>", "\r",
                   {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/"}});
  check_parse_html("<a href=telegram.org>\n</a>", "\n",
                   {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/"}});
  check_parse_html("<code><i><b> </b></i></code><i><b><code> </code></b></i>", "  ",
                   {{td::MessageEntity::Type::Code, 0, 1},
                    {td::MessageEntity::Type::Bold, 0, 1},
                    {td::MessageEntity::Type::Italic, 0, 1},
                    {td::MessageEntity::Type::Code, 1, 1},
                    {td::MessageEntity::Type::Bold, 1, 1},
                    {td::MessageEntity::Type::Italic, 1, 1}});
  check_parse_html("<i><b> </b> <code> </code></i>", "   ",
                   {{td::MessageEntity::Type::Italic, 0, 3},
                    {td::MessageEntity::Type::Bold, 0, 1},
                    {td::MessageEntity::Type::Code, 2, 1}});
  check_parse_html("<a href=telegram.org> </a>", " ",
                   {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/"}});
  check_parse_html("<a href  =\"telegram.org\"   > </a>", " ",
                   {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/"}});
  check_parse_html("<a   href=  'telegram.org'   > </a>", " ",
                   {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/"}});
  check_parse_html("<a   href=  'telegram.org?&lt;'   > </a>", " ",
                   {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/?<"}});
  check_parse_html("<a> </a>", " ", {});
  check_parse_html("<a>telegram.org </a>", "telegram.org ", {});
  check_parse_html("<a>telegram.org</a>", "telegram.org",
                   {{td::MessageEntity::Type::TextUrl, 0, 12, "http://telegram.org/"}});
  check_parse_html("<a>https://telegram.org/asdsa?asdasdwe#12e3we</a>", "https://telegram.org/asdsa?asdasdwe#12e3we",
                   {{td::MessageEntity::Type::TextUrl, 0, 42, "https://telegram.org/asdsa?asdasdwe#12e3we"}});
  check_parse_html("🏟 🏟&lt;<pre  >🏟 🏟&lt;</>", "🏟 🏟<🏟 🏟<", {{td::MessageEntity::Type::Pre, 6, 6}});
  check_parse_html("🏟 🏟&lt;<code >🏟 🏟&lt;</>", "🏟 🏟<🏟 🏟<", {{td::MessageEntity::Type::Code, 6, 6}});
  check_parse_html("🏟 🏟&lt;<pre><code>🏟 🏟&lt;</code></>", "🏟 🏟<🏟 🏟<",
                   {{td::MessageEntity::Type::Pre, 6, 6}, {td::MessageEntity::Type::Code, 6, 6}});
  check_parse_html("🏟 🏟&lt;<pre><code class=\"language-\">🏟 🏟&lt;</code></>", "🏟 🏟<🏟 🏟<",
                   {{td::MessageEntity::Type::Pre, 6, 6}, {td::MessageEntity::Type::Code, 6, 6}});
  check_parse_html("🏟 🏟&lt;<pre><code class=\"language-fift\">🏟 🏟&lt;</></>", "🏟 🏟<🏟 🏟<",
                   {{td::MessageEntity::Type::PreCode, 6, 6, "fift"}});
  check_parse_html("🏟 🏟&lt;<code class=\"language-fift\"><pre>🏟 🏟&lt;</></>", "🏟 🏟<🏟 🏟<",
                   {{td::MessageEntity::Type::PreCode, 6, 6, "fift"}});
  check_parse_html("🏟 🏟&lt;<pre><code class=\"language-fift\">🏟 🏟&lt;</> </>", "🏟 🏟<🏟 🏟< ",
                   {{td::MessageEntity::Type::Pre, 6, 7}, {td::MessageEntity::Type::Code, 6, 6}});
  check_parse_html("🏟 🏟&lt;<pre> <code class=\"language-fift\">🏟 🏟&lt;</></>", "🏟 🏟< 🏟 🏟<",
                   {{td::MessageEntity::Type::Pre, 6, 7}, {td::MessageEntity::Type::Code, 7, 6}});
  check_parse_html("➡️ ➡️<tg-emoji emoji-id = \"12345\">➡️ ➡️</tg-emoji><b>➡️ ➡️</b>", "➡️ ➡️➡️ ➡️➡️ ➡️",
                   {{td::MessageEntity::Type::CustomEmoji, 5, 5, td::CustomEmojiId(static_cast<td::int64>(12345))},
                    {td::MessageEntity::Type::Bold, 10, 5}});
  check_parse_html("🏟 🏟<tg-emoji emoji-id=\"54321\">🏟 &lt🏟</tg-emoji>", "🏟 🏟🏟 <🏟",
                   {{td::MessageEntity::Type::CustomEmoji, 5, 6, td::CustomEmojiId(static_cast<td::int64>(54321))}});
  check_parse_html("🏟 🏟<b aba   =   caba><tg-emoji emoji-id=\"1\">🏟</tg-emoji>1</b>", "🏟 🏟🏟1",
                   {{td::MessageEntity::Type::Bold, 5, 3},
                    {td::MessageEntity::Type::CustomEmoji, 5, 2, td::CustomEmojiId(static_cast<td::int64>(1))}});
  check_parse_html("<blockquote   cite=\"\" askdlbas nasjdbaj nj12b3>a&lt;<pre  >b;</></>", "a<b;",
                   {{td::MessageEntity::Type::BlockQuote, 0, 4}, {td::MessageEntity::Type::Pre, 2, 2}});
  check_parse_html("<blockquote   expandable>a&lt;<pre  >b;</></>", "a<b;",
                   {{td::MessageEntity::Type::ExpandableBlockQuote, 0, 4}, {td::MessageEntity::Type::Pre, 2, 2}});
  check_parse_html("<blockquote   expandable   asd>a&lt;<pre  >b;</></>", "a<b;",
                   {{td::MessageEntity::Type::ExpandableBlockQuote, 0, 4}, {td::MessageEntity::Type::Pre, 2, 2}});
  check_parse_html("<blockquote   expandable=false>a&lt;<pre  >b;</></>", "a<b;",
                   {{td::MessageEntity::Type::ExpandableBlockQuote, 0, 4}, {td::MessageEntity::Type::Pre, 2, 2}});
}

static void check_parse_markdown(td::string text, const td::string &result,
                                 const td::vector<td::MessageEntity> &entities) {
  auto r_entities = td::parse_markdown_v2(text);
  if (r_entities.is_error()) {
    LOG(ERROR) << r_entities.error();
  }
  ASSERT_TRUE(r_entities.is_ok());
  ASSERT_EQ(entities, r_entities.ok());
  ASSERT_STREQ(result, text);
}

static void check_parse_markdown(td::string text, td::Slice error_message) {
  auto r_entities = td::parse_markdown_v2(text);
  ASSERT_TRUE(r_entities.is_error());
  ASSERT_EQ(400, r_entities.error().code());
  ASSERT_STREQ(error_message, r_entities.error().message());
}

TEST(MessageEntities, parse_markdown) {
  td::Slice reserved_characters("]()>#+-=|{}.!");
  td::Slice begin_characters("_*[~`>");
  for (char c = 1; c < 126; c++) {
    if (begin_characters.find(c) != td::Slice::npos) {
      continue;
    }

    td::string text(1, c);
    if (reserved_characters.find(c) == td::Slice::npos) {
      check_parse_markdown(text, text, {});
    } else {
      check_parse_markdown(
          text, PSLICE() << "Character '" << c << "' is reserved and must be escaped with the preceding '\\'");

      td::string escaped_text = "\\" + text;
      check_parse_markdown(escaped_text, text, {});
    }
  }

  check_parse_markdown("🏟 🏟_abacaba", "Can't find end of Italic entity at byte offset 9");
  check_parse_markdown("🏟 🏟_abac * asd ", "Can't find end of Bold entity at byte offset 15");
  check_parse_markdown("🏟 🏟_abac * asd _", "Can't find end of Italic entity at byte offset 21");
  check_parse_markdown("🏟 🏟`", "Can't find end of Code entity at byte offset 9");
  check_parse_markdown("🏟 🏟```", "Can't find end of Pre entity at byte offset 9");
  check_parse_markdown("🏟 🏟```a", "Can't find end of Pre entity at byte offset 9");
  check_parse_markdown("🏟 🏟```a ", "Can't find end of PreCode entity at byte offset 9");
  check_parse_markdown("🏟 🏟__🏟 🏟_", "Can't find end of Italic entity at byte offset 20");
  check_parse_markdown("🏟 🏟_🏟 🏟__", "Can't find end of Underline entity at byte offset 19");
  check_parse_markdown("🏟 🏟```🏟 🏟`", "Can't find end of Code entity at byte offset 21");
  check_parse_markdown("🏟 🏟```🏟 🏟_", "Can't find end of PreCode entity at byte offset 9");
  check_parse_markdown("🏟 🏟```🏟 🏟\\`", "Can't find end of PreCode entity at byte offset 9");
  check_parse_markdown("[telegram\\.org](asd\\)", "Can't find end of a URL at byte offset 16");
  check_parse_markdown("[telegram\\.org](", "Can't find end of a URL at byte offset 16");
  check_parse_markdown("[telegram\\.org](asd", "Can't find end of a URL at byte offset 16");
  check_parse_markdown("🏟 🏟__🏟 _🏟___", "Can't find end of Italic entity at byte offset 23");
  check_parse_markdown("🏟 🏟__", "Can't find end of Underline entity at byte offset 9");
  check_parse_markdown("🏟 🏟||test\\|", "Can't find end of Spoiler entity at byte offset 9");
  check_parse_markdown("🏟 🏟!", "Character '!' is reserved and must be escaped with the preceding '\\'");
  check_parse_markdown("🏟 🏟>", "Character '>' is reserved and must be escaped with the preceding '\\'");
  check_parse_markdown("🏟 🏟![", "Can't find end of CustomEmoji entity at byte offset 9");
  check_parse_markdown("🏟 🏟![👍", "Can't find end of CustomEmoji entity at byte offset 9");
  check_parse_markdown("🏟 🏟![👍]", "Custom emoji entity must contain a tg://emoji URL");
  check_parse_markdown("🏟 🏟![👍](tg://emoji?id=1234", "Can't find end of a custom emoji URL at byte offset 17");
  check_parse_markdown("🏟 🏟![👍](t://emoji?id=1234)", "Custom emoji URL must have scheme tg");
  check_parse_markdown("🏟 🏟![👍](tg:emojis?id=1234)", "Custom emoji URL must have host \"emoji\"");
  check_parse_markdown("🏟 🏟![👍](tg://emoji#test)", "Custom emoji URL must have an emoji identifier");
  check_parse_markdown("🏟 🏟![👍](tg://emoji?test=1#&id=25)", "Custom emoji URL must have an emoji identifier");
  check_parse_markdown("🏟 🏟![👍](tg://emoji?test=1231&id=025)", "Invalid custom emoji identifier specified");
  check_parse_markdown(">*b\n>ld \n>bo\nld*\nasd\ndef", "Can't find end of Bold entity at byte offset 1");
  check_parse_markdown(">\n*a*>2", "Character '>' is reserved and must be escaped with the preceding '\\'");
  check_parse_markdown(">asd\n>q||e||w||\n||asdad", "Can't find end of Spoiler entity at byte offset 16");
  check_parse_markdown(">asd\n>q||ew\n||asdad", "Can't find end of Spoiler entity at byte offset 7");
  check_parse_markdown(">asd\n>q||e||w__\n||asdad", "Can't find end of Underline entity at byte offset 13");
  check_parse_markdown(">asd\n>q||e||w||a\n||asdad", "Can't find end of Spoiler entity at byte offset 13");

  check_parse_markdown("", "", {});
  check_parse_markdown("\\\\", "\\", {});
  check_parse_markdown("\\\\\\", "\\\\", {});
  check_parse_markdown("\\\\\\\\\\_\\*\\`", "\\\\_*`", {});
  check_parse_markdown("➡️ ➡️", "➡️ ➡️", {});
  check_parse_markdown("🏟 🏟``", "🏟 🏟", {});
  check_parse_markdown("🏟 🏟_abac \\* asd _", "🏟 🏟abac * asd ", {{td::MessageEntity::Type::Italic, 5, 11}});
  check_parse_markdown("🏟 \\.🏟_🏟\\. 🏟_", "🏟 .🏟🏟. 🏟", {{td::MessageEntity::Type::Italic, 6, 6}});
  check_parse_markdown("\\\\\\a\\b\\c\\d\\e\\f\\1\\2\\3\\4\\➡️\\", "\\abcdef1234\\➡️\\", {});
  check_parse_markdown("➡️ ➡️_➡️ ➡️_", "➡️ ➡️➡️ ➡️", {{td::MessageEntity::Type::Italic, 5, 5}});
  check_parse_markdown("➡️ ➡️_➡️ ➡️_*➡️ ➡️*", "➡️ ➡️➡️ ➡️➡️ ➡️",
                       {{td::MessageEntity::Type::Italic, 5, 5}, {td::MessageEntity::Type::Bold, 10, 5}});
  check_parse_markdown("🏟 🏟_🏟 \\.🏟_", "🏟 🏟🏟 .🏟", {{td::MessageEntity::Type::Italic, 5, 6}});
  check_parse_markdown("🏟 🏟_🏟 *🏟*_", "🏟 🏟🏟 🏟",
                       {{td::MessageEntity::Type::Italic, 5, 5}, {td::MessageEntity::Type::Bold, 8, 2}});
  check_parse_markdown("🏟 🏟_🏟 __🏟___", "🏟 🏟🏟 🏟",
                       {{td::MessageEntity::Type::Italic, 5, 5}, {td::MessageEntity::Type::Underline, 8, 2}});
  check_parse_markdown("🏟 🏟__🏟 _🏟_ __", "🏟 🏟🏟 🏟 ",
                       {{td::MessageEntity::Type::Underline, 5, 6}, {td::MessageEntity::Type::Italic, 8, 2}});
  check_parse_markdown("🏟 🏟__🏟 _🏟_\\___", "🏟 🏟🏟 🏟_",
                       {{td::MessageEntity::Type::Underline, 5, 6}, {td::MessageEntity::Type::Italic, 8, 2}});
  check_parse_markdown("🏟 🏟`🏟 🏟```", "🏟 🏟🏟 🏟", {{td::MessageEntity::Type::Code, 5, 5}});
  check_parse_markdown("🏟 🏟```🏟 🏟```", "🏟 🏟 🏟", {{td::MessageEntity::Type::PreCode, 5, 3, "🏟"}});
  check_parse_markdown("🏟 🏟```🏟\n🏟```", "🏟 🏟🏟", {{td::MessageEntity::Type::PreCode, 5, 2, "🏟"}});
  check_parse_markdown("🏟 🏟```🏟\r🏟```", "🏟 🏟🏟", {{td::MessageEntity::Type::PreCode, 5, 2, "🏟"}});
  check_parse_markdown("🏟 🏟```🏟\n\r🏟```", "🏟 🏟🏟", {{td::MessageEntity::Type::PreCode, 5, 2, "🏟"}});
  check_parse_markdown("🏟 🏟```🏟\r\n🏟```", "🏟 🏟🏟", {{td::MessageEntity::Type::PreCode, 5, 2, "🏟"}});
  check_parse_markdown("🏟 🏟```🏟\n\n🏟```", "🏟 🏟\n🏟", {{td::MessageEntity::Type::PreCode, 5, 3, "🏟"}});
  check_parse_markdown("🏟 🏟```🏟\r\r🏟```", "🏟 🏟\r🏟", {{td::MessageEntity::Type::PreCode, 5, 3, "🏟"}});
  check_parse_markdown("🏟 🏟```🏟 \\\\\\`🏟```", "🏟 🏟 \\`🏟", {{td::MessageEntity::Type::PreCode, 5, 5, "🏟"}});
  check_parse_markdown("🏟 🏟**", "🏟 🏟", {});
  check_parse_markdown("||test||", "test", {{td::MessageEntity::Type::Spoiler, 0, 4}});
  check_parse_markdown("🏟 🏟``", "🏟 🏟", {});
  check_parse_markdown("🏟 🏟``````", "🏟 🏟", {});
  check_parse_markdown("🏟 🏟____", "🏟 🏟", {});
  check_parse_markdown("`_* *_`__*` `*__", "_* *_ ",
                       {{td::MessageEntity::Type::Code, 0, 5},
                        {td::MessageEntity::Type::Code, 5, 1},
                        {td::MessageEntity::Type::Bold, 5, 1},
                        {td::MessageEntity::Type::Underline, 5, 1}});
  check_parse_markdown("_* * ` `_", "   ",
                       {{td::MessageEntity::Type::Italic, 0, 3},
                        {td::MessageEntity::Type::Bold, 0, 1},
                        {td::MessageEntity::Type::Code, 2, 1}});
  check_parse_markdown("[](telegram.org)", "", {});
  check_parse_markdown("[ ](telegram.org)", " ", {{td::MessageEntity::Type::TextUrl, 0, 1, "http://telegram.org/"}});
  check_parse_markdown("[ ](as)", " ", {});
  check_parse_markdown("[telegram\\.org]", "telegram.org",
                       {{td::MessageEntity::Type::TextUrl, 0, 12, "http://telegram.org/"}});
  check_parse_markdown("[telegram\\.org]a", "telegram.orga",
                       {{td::MessageEntity::Type::TextUrl, 0, 12, "http://telegram.org/"}});
  check_parse_markdown("[telegram\\.org](telegram.dog)", "telegram.org",
                       {{td::MessageEntity::Type::TextUrl, 0, 12, "http://telegram.dog/"}});
  check_parse_markdown("[telegram\\.org](https://telegram.dog?)", "telegram.org",
                       {{td::MessageEntity::Type::TextUrl, 0, 12, "https://telegram.dog/?"}});
  check_parse_markdown("[telegram\\.org](https://telegram.dog?\\\\\\()", "telegram.org",
                       {{td::MessageEntity::Type::TextUrl, 0, 12, "https://telegram.dog/?\\("}});
  check_parse_markdown("[telegram\\.org]()", "telegram.org", {});
  check_parse_markdown("[telegram\\.org](asdasd)", "telegram.org", {});
  check_parse_markdown("[telegram\\.org](tg:user?id=123456)", "telegram.org",
                       {{0, 12, td::UserId(static_cast<td::int64>(123456))}});
  check_parse_markdown("🏟 🏟![👍](TG://EMoJI/?test=1231&id=25#id=32)a", "🏟 🏟👍a",
                       {{td::MessageEntity::Type::CustomEmoji, 5, 2, td::CustomEmojiId(static_cast<td::int64>(25))}});
  check_parse_markdown("> \n> \n>", " \n \n", {{td::MessageEntity::Type::BlockQuote, 0, 4}});
  check_parse_markdown("> \\>\n \\> \n>", " >\n > \n", {{td::MessageEntity::Type::BlockQuote, 0, 3}});
  check_parse_markdown("abc\n> \n> \n>\ndef", "abc\n \n \n\ndef", {{td::MessageEntity::Type::BlockQuote, 4, 5}});
  check_parse_markdown(">", "", {});
  check_parse_markdown(">a", "a", {{td::MessageEntity::Type::BlockQuote, 0, 1}});
  check_parse_markdown("\r>a", "\ra", {{td::MessageEntity::Type::BlockQuote, 1, 1}});
  check_parse_markdown("\r\r>\r\ra\r\n\r", "\r\r\r\ra\r\n\r", {{td::MessageEntity::Type::BlockQuote, 2, 5}});
  check_parse_markdown(
      ">*bold _italic bold ~italic bold strikethrough ||italic bold strikethrough spoiler||~ __underline italic "
      "bold___ bold*",
      "bold italic bold italic bold strikethrough italic bold strikethrough spoiler underline italic bold bold",
      {{td::MessageEntity::Type::BlockQuote, 0, 103},
       {td::MessageEntity::Type::Bold, 0, 103},
       {td::MessageEntity::Type::Italic, 5, 93},
       {td::MessageEntity::Type::Strikethrough, 17, 59},
       {td::MessageEntity::Type::Spoiler, 43, 33},
       {td::MessageEntity::Type::Underline, 77, 21}});
  check_parse_markdown(">*b\n>ld \n>bo\n>ld*\nasd\ndef", "b\nld \nbo\nld\nasd\ndef",
                       {{td::MessageEntity::Type::BlockQuote, 0, 12}, {td::MessageEntity::Type::Bold, 0, 11}});
  check_parse_markdown("*a\n>b\n>ld \n>bo\n>ld\nasd*\ndef", "a\nb\nld \nbo\nld\nasd\ndef",
                       {{td::MessageEntity::Type::Bold, 0, 17}, {td::MessageEntity::Type::BlockQuote, 2, 12}});
  check_parse_markdown(">`b\n>ld \n>bo\nld`\n>asd\ndef", "b\n>ld \n>bo\nld\nasd\ndef",
                       {{td::MessageEntity::Type::BlockQuote, 0, 18}, {td::MessageEntity::Type::Code, 0, 13}});
  check_parse_markdown("`>b\n>ld \n>bo\nld`\n>asd\ndef", ">b\n>ld \n>bo\nld\nasd\ndef",
                       {{td::MessageEntity::Type::Code, 0, 14}, {td::MessageEntity::Type::BlockQuote, 15, 4}});
  check_parse_markdown(">1", "1", {{td::MessageEntity::Type::BlockQuote, 0, 1}});
  check_parse_markdown(">\n1", "\n1", {{td::MessageEntity::Type::BlockQuote, 0, 1}});
  check_parse_markdown(">\n\r>2", "\n\r2",
                       {{td::MessageEntity::Type::BlockQuote, 0, 1}, {td::MessageEntity::Type::BlockQuote, 2, 1}});
  check_parse_markdown(">\n**>2", "\n2",
                       {{td::MessageEntity::Type::BlockQuote, 0, 1}, {td::MessageEntity::Type::BlockQuote, 1, 1}});
  check_parse_markdown(">**\n>2", "\n2", {{td::MessageEntity::Type::BlockQuote, 0, 2}});
  // check_parse_markdown("*>abcd*", "abcd",
  //                      {{td::MessageEntity::Type::BlockQuote, 0, 4}, {td::MessageEntity::Type::Bold, 0, 4}});
  check_parse_markdown(">*abcd*", "abcd",
                       {{td::MessageEntity::Type::BlockQuote, 0, 4}, {td::MessageEntity::Type::Bold, 0, 4}});
  // check_parse_markdown(">*abcd\n*", "abcd\n",
  //                      {{td::MessageEntity::Type::BlockQuote, 0, 5}, {td::MessageEntity::Type::Bold, 0, 5}});
  check_parse_markdown(">*abcd*\n", "abcd\n",
                       {{td::MessageEntity::Type::BlockQuote, 0, 5}, {td::MessageEntity::Type::Bold, 0, 4}});
  check_parse_markdown("*>abcd\n*", "abcd\n",
                       {{td::MessageEntity::Type::BlockQuote, 0, 5}, {td::MessageEntity::Type::Bold, 0, 5}});
  check_parse_markdown("abc\n>def\n>def\n\r>ghi2\njkl", "abc\ndef\ndef\n\rghi2\njkl",
                       {{td::MessageEntity::Type::BlockQuote, 4, 8}, {td::MessageEntity::Type::BlockQuote, 13, 5}});
  check_parse_markdown(
      ">asd\n>q||e||w||\nasdad", "asd\nqew\nasdad",
      {{td::MessageEntity::Type::ExpandableBlockQuote, 0, 8}, {td::MessageEntity::Type::Spoiler, 5, 1}});
  check_parse_markdown(">asd\n>q||ew||\nasdad", "asd\nqew\nasdad",
                       {{td::MessageEntity::Type::BlockQuote, 0, 8}, {td::MessageEntity::Type::Spoiler, 5, 2}});
  check_parse_markdown(
      ">asd\r\n>q||e||w||\r\nasdad", "asd\r\nqew\r\nasdad",
      {{td::MessageEntity::Type::ExpandableBlockQuote, 0, 10}, {td::MessageEntity::Type::Spoiler, 6, 1}});
  check_parse_markdown(">asd\r\n>q||ew||\r\nasdad", "asd\r\nqew\r\nasdad",
                       {{td::MessageEntity::Type::BlockQuote, 0, 10}, {td::MessageEntity::Type::Spoiler, 6, 2}});
  check_parse_markdown(
      ">asd\r\n>q||e||w||\r\n", "asd\r\nqew\r\n",
      {{td::MessageEntity::Type::ExpandableBlockQuote, 0, 10}, {td::MessageEntity::Type::Spoiler, 6, 1}});
  check_parse_markdown(">asd\r\n>q||ew||\r\n", "asd\r\nqew\r\n",
                       {{td::MessageEntity::Type::BlockQuote, 0, 10}, {td::MessageEntity::Type::Spoiler, 6, 2}});
  check_parse_markdown(
      ">asd\r\n>q||e||w||", "asd\r\nqew",
      {{td::MessageEntity::Type::ExpandableBlockQuote, 0, 8}, {td::MessageEntity::Type::Spoiler, 6, 1}});
  check_parse_markdown(">asd\r\n>q||ew||", "asd\r\nqew",
                       {{td::MessageEntity::Type::BlockQuote, 0, 8}, {td::MessageEntity::Type::Spoiler, 6, 2}});
  check_parse_markdown(">||", "", {});
}

static void check_parse_markdown_v3(td::string text, td::vector<td::MessageEntity> entities,
                                    const td::string &result_text, const td::vector<td::MessageEntity> &result_entities,
                                    bool fix = false) {
  auto parsed_text = td::parse_markdown_v3({std::move(text), std::move(entities)});
  if (fix) {
    ASSERT_TRUE(td::fix_formatted_text(parsed_text.text, parsed_text.entities, true, true, true, true, true).is_ok());
  }
  ASSERT_STREQ(result_text, parsed_text.text);
  ASSERT_EQ(result_entities, parsed_text.entities);
  if (fix) {
    auto markdown_text = td::get_markdown_v3(parsed_text);
    ASSERT_TRUE(parsed_text == markdown_text || parsed_text == td::parse_markdown_v3(markdown_text));
  }
}

static void check_parse_markdown_v3(td::string text, const td::string &result_text,
                                    const td::vector<td::MessageEntity> &result_entities, bool fix = false) {
  check_parse_markdown_v3(std::move(text), td::vector<td::MessageEntity>(), result_text, result_entities, fix);
}

TEST(MessageEntities, parse_markdown_v3) {
  check_parse_markdown_v3("🏟````🏟``🏟`aba🏟```c🏟`aba🏟 daba🏟```c🏟`aba🏟```🏟 `🏟``🏟```",
                          "🏟````🏟``🏟aba🏟```c🏟aba🏟 daba🏟c🏟`aba🏟🏟 `🏟``🏟```",
                          {{td::MessageEntity::Type::Code, 12, 11}, {td::MessageEntity::Type::Pre, 35, 9}});
  check_parse_markdown_v3("🏟````🏟``🏟`aba🏟```c🏟`aba🏟 daba🏟```c🏟`aba🏟🏟```🏟 `🏟``🏟```",
                          {{td::MessageEntity::Type::Italic, 12, 1},
                           {td::MessageEntity::Type::Italic, 44, 1},
                           {td::MessageEntity::Type::Bold, 45, 1},
                           {td::MessageEntity::Type::Bold, 49, 2}},
                          "🏟````🏟``🏟`aba🏟c🏟`aba🏟 daba🏟c🏟`aba🏟🏟🏟 `🏟``🏟",
                          {{td::MessageEntity::Type::Italic, 12, 1},
                           {td::MessageEntity::Type::Pre, 18, 16},
                           {td::MessageEntity::Type::Italic, 38, 1},
                           {td::MessageEntity::Type::Bold, 39, 1},
                           {td::MessageEntity::Type::Bold, 43, 2},
                           {td::MessageEntity::Type::Pre, 45, 10}});
  check_parse_markdown_v3("` `", " ", {{td::MessageEntity::Type::Code, 0, 1}});
  check_parse_markdown_v3("`\n`", "\n", {{td::MessageEntity::Type::Code, 0, 1}});
  check_parse_markdown_v3("` `a", " a", {{td::MessageEntity::Type::Code, 0, 1}}, true);
  check_parse_markdown_v3("`\n`a", "\na", {{td::MessageEntity::Type::Code, 0, 1}}, true);
  check_parse_markdown_v3("``", "``", {});
  check_parse_markdown_v3("`a````b```", "`a````b```", {});
  check_parse_markdown_v3("ab", {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Pre, 1, 1}}, "ab",
                          {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Pre, 1, 1}});

  check_parse_markdown_v3("[a](b[c](t.me)", "[a](b[c](t.me)", {});
  check_parse_markdown_v3("[](t.me)", "[](t.me)", {});
  check_parse_markdown_v3("[ ](t.me)", " ", {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"}});
  check_parse_markdown_v3("[ ](t.me)", "", {}, true);
  check_parse_markdown_v3("[ ](t.me)a", " a", {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"}}, true);
  check_parse_markdown_v3(
      "[ ](t.me) [ ](t.me)",
      {{td::MessageEntity::Type::TextUrl, 8, 1, "http://t.me/"}, {10, 1, td::UserId(static_cast<td::int64>(1))}},
      "[ ](t.me) [ ](t.me)",
      {{td::MessageEntity::Type::TextUrl, 8, 1, "http://t.me/"}, {10, 1, td::UserId(static_cast<td::int64>(1))}});
  check_parse_markdown_v3("[\n](t.me)", "\n", {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"}});
  check_parse_markdown_v3("[\n](t.me)a", "\na", {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"}}, true);
  check_parse_markdown_v3("asd[abcd](google.com)", {{td::MessageEntity::Type::Italic, 0, 5}}, "asdabcd",
                          {{td::MessageEntity::Type::Italic, 0, 3},
                           {td::MessageEntity::Type::TextUrl, 3, 4, "http://google.com/"},
                           {td::MessageEntity::Type::Italic, 3, 1}});
  check_parse_markdown_v3("asd[abcd](google.com)efg[hi](https://t.me?t=1#h)e",
                          {{td::MessageEntity::Type::Italic, 0, 5}, {td::MessageEntity::Type::Italic, 18, 31}},
                          "asdabcdefghie",
                          {{td::MessageEntity::Type::Italic, 0, 3},
                           {td::MessageEntity::Type::TextUrl, 3, 4, "http://google.com/"},
                           {td::MessageEntity::Type::Italic, 3, 1},
                           {td::MessageEntity::Type::Italic, 7, 3},
                           {td::MessageEntity::Type::TextUrl, 10, 2, "https://t.me/?t=1#h"},
                           {td::MessageEntity::Type::Italic, 10, 2},
                           {td::MessageEntity::Type::Italic, 12, 1}});
  check_parse_markdown_v3(
      "🏟🏟🏟[🏟🏟🏟🏟🏟](www.🤙.tk#1)🤙🤙🤙[🏟🏟🏟🏟](www.🤙.tk#2)🤙🤙🤙["
      "🏟🏟🏟🏟](www.🤙.tk#3)🏟🏟🏟[🏟🏟🏟🏟](www.🤙.tk#4)🤙🤙",
      "🏟🏟🏟🏟🏟🏟🏟🏟🤙🤙🤙🏟🏟🏟🏟🤙🤙🤙🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟"
      "🏟🤙🤙",
      {{td::MessageEntity::Type::TextUrl, 6, 10, "http://www.🤙.tk/#1"},
       {td::MessageEntity::Type::TextUrl, 22, 8, "http://www.🤙.tk/#2"},
       {td::MessageEntity::Type::TextUrl, 36, 8, "http://www.🤙.tk/#3"},
       {td::MessageEntity::Type::TextUrl, 50, 8, "http://www.🤙.tk/#4"}});
  check_parse_markdown_v3(
      "[🏟🏟🏟🏟🏟](www.🤙.tk#1)[🏟🏟🏟🏟](www.🤙.tk#2)[🏟🏟🏟🏟](www.🤙.tk#3)["
      "🏟🏟🏟🏟](www.🤙.tk#4)",
      "🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟",
      {{td::MessageEntity::Type::TextUrl, 0, 10, "http://www.🤙.tk/#1"},
       {td::MessageEntity::Type::TextUrl, 10, 8, "http://www.🤙.tk/#2"},
       {td::MessageEntity::Type::TextUrl, 18, 8, "http://www.🤙.tk/#3"},
       {td::MessageEntity::Type::TextUrl, 26, 8, "http://www.🤙.tk/#4"}});
  check_parse_markdown_v3(
      "🏟🏟🏟[🏟🏟🏟🏟🏟](www.🤙.tk)🤙🤙🤙[🏟🏟🏟🏟](www.🤙.tk)🤙🤙🤙["
      "🏟🏟🏟🏟](www.🤙.tk)🏟🏟🏟[🏟🏟🏟🏟](www.🤙.tk)🤙🤙",
      {{td::MessageEntity::Type::Bold, 0, 2},
       {td::MessageEntity::Type::Bold, 4, 2},
       {td::MessageEntity::Type::Bold, 7, 2},
       {td::MessageEntity::Type::Bold, 11, 2},
       {td::MessageEntity::Type::Bold, 15, 2},
       {td::MessageEntity::Type::Bold, 18, 2},
       {td::MessageEntity::Type::Bold, 26, 2},
       {31, 2, td::UserId(static_cast<td::int64>(1))},
       {td::MessageEntity::Type::Bold, 35, 1},
       {td::MessageEntity::Type::Bold, 44, 2},
       {td::MessageEntity::Type::Bold, 50, 2},
       {td::MessageEntity::Type::Bold, 54, 2},
       {56, 2, td::UserId(static_cast<td::int64>(2))},
       {td::MessageEntity::Type::Bold, 58, 7},
       {60, 2, td::UserId(static_cast<td::int64>(3))},
       {td::MessageEntity::Type::Bold, 67, 7},
       {td::MessageEntity::Type::Bold, 80, 7},
       {td::MessageEntity::Type::Bold, 89, 25}},
      "🏟🏟🏟🏟🏟🏟🏟🏟🤙🤙🤙🏟🏟🏟🏟🤙🤙🤙🏟🏟🏟🏟🏟🏟🏟🏟🏟🏟"
      "🏟🤙🤙",
      {{td::MessageEntity::Type::Bold, 0, 2},
       {td::MessageEntity::Type::Bold, 4, 2},
       {td::MessageEntity::Type::TextUrl, 6, 10, "http://www.🤙.tk/"},
       {td::MessageEntity::Type::Bold, 6, 2},
       {td::MessageEntity::Type::Bold, 10, 2},
       {td::MessageEntity::Type::Bold, 14, 2},
       {18, 2, td::UserId(static_cast<td::int64>(1))},
       {td::MessageEntity::Type::TextUrl, 22, 8, "http://www.🤙.tk/"},
       {30, 2, td::UserId(static_cast<td::int64>(2))},
       {td::MessageEntity::Type::Bold, 32, 2},
       {34, 2, td::UserId(static_cast<td::int64>(3))},
       {td::MessageEntity::Type::Bold, 34, 2},
       {td::MessageEntity::Type::TextUrl, 36, 8, "http://www.🤙.tk/"},
       {td::MessageEntity::Type::Bold, 36, 2},
       {td::MessageEntity::Type::Bold, 40, 4},
       {td::MessageEntity::Type::Bold, 44, 4},
       {td::MessageEntity::Type::TextUrl, 50, 8, "http://www.🤙.tk/"},
       {td::MessageEntity::Type::Bold, 50, 8},
       {td::MessageEntity::Type::Bold, 58, 4}});
  check_parse_markdown_v3("[`a`](t.me) [b](t.me)", {{td::MessageEntity::Type::Code, 13, 1}}, "[a](t.me) [b](t.me)",
                          {{td::MessageEntity::Type::Code, 1, 1}, {td::MessageEntity::Type::Code, 11, 1}});
  check_parse_markdown_v3(
      "[text](example.com)",
      {{td::MessageEntity::Type::Strikethrough, 0, 1}, {td::MessageEntity::Type::Strikethrough, 5, 14}}, "text",
      {{td::MessageEntity::Type::TextUrl, 0, 4, "http://example.com/"}});
  check_parse_markdown_v3("[text](example.com)",
                          {{td::MessageEntity::Type::Spoiler, 0, 1}, {td::MessageEntity::Type::Spoiler, 5, 14}}, "text",
                          {{td::MessageEntity::Type::TextUrl, 0, 4, "http://example.com/"}});

  check_parse_markdown_v3("🏟[🏟](t.me) `🏟` [🏟](t.me) `a`", "🏟🏟 🏟 🏟 a",
                          {{td::MessageEntity::Type::TextUrl, 2, 2, "http://t.me/"},
                           {td::MessageEntity::Type::Code, 5, 2},
                           {td::MessageEntity::Type::TextUrl, 8, 2, "http://t.me/"},
                           {td::MessageEntity::Type::Code, 11, 1}});

  check_parse_markdown_v3("__ __", " ", {{td::MessageEntity::Type::Italic, 0, 1}});
  check_parse_markdown_v3("__\n__", "\n", {{td::MessageEntity::Type::Italic, 0, 1}});
  check_parse_markdown_v3("__ __a", " a", {{td::MessageEntity::Type::Italic, 0, 1}}, true);
  check_parse_markdown_v3("__\n__a", "\na", {{td::MessageEntity::Type::Italic, 0, 1}}, true);
  check_parse_markdown_v3("**** __a__ **b** ~~c~~ ||d||", "**** a b c d",
                          {{td::MessageEntity::Type::Italic, 5, 1},
                           {td::MessageEntity::Type::Bold, 7, 1},
                           {td::MessageEntity::Type::Strikethrough, 9, 1},
                           {td::MessageEntity::Type::Spoiler, 11, 1}});
  check_parse_markdown_v3("тест __аааа__ **бббб** ~~вввв~~ ||гггг||", "тест аааа бббб вввв гггг",
                          {{td::MessageEntity::Type::Italic, 5, 4},
                           {td::MessageEntity::Type::Bold, 10, 4},
                           {td::MessageEntity::Type::Strikethrough, 15, 4},
                           {td::MessageEntity::Type::Spoiler, 20, 4}});
  check_parse_markdown_v3("___a___ ***b** ~c~~", "___a___ ***b** ~c~~", {});
  check_parse_markdown_v3(
      "__asd[ab__cd](t.me)", "asdabcd",
      {{td::MessageEntity::Type::Italic, 0, 5}, {td::MessageEntity::Type::TextUrl, 3, 4, "http://t.me/"}});
  check_parse_markdown_v3("__asd[ab__cd](t.me)", "asdabcd",
                          {{td::MessageEntity::Type::Italic, 0, 3},
                           {td::MessageEntity::Type::TextUrl, 3, 4, "http://t.me/"},
                           {td::MessageEntity::Type::Italic, 3, 2}},
                          true);
  check_parse_markdown_v3("__a #test__test", "__a #test__test", {});
  check_parse_markdown_v3("a #testtest", {{td::MessageEntity::Type::Italic, 0, 7}}, "a #testtest",
                          {{td::MessageEntity::Type::Italic, 0, 7}});

  // TODO parse_markdown_v3 is not idempotent now, which is bad
  check_parse_markdown_v3(
      "~~**~~__**a__", {{td::MessageEntity::Type::Strikethrough, 2, 1}, {td::MessageEntity::Type::Bold, 6, 1}},
      "**__**a__", {{td::MessageEntity::Type::Strikethrough, 0, 2}, {td::MessageEntity::Type::Bold, 2, 1}}, true);
  check_parse_markdown_v3("**__**a__",
                          {{td::MessageEntity::Type::Strikethrough, 0, 2}, {td::MessageEntity::Type::Bold, 2, 1}},
                          "__a__", {{td::MessageEntity::Type::Bold, 0, 2}}, true);
  check_parse_markdown_v3("__a__", {{td::MessageEntity::Type::Bold, 0, 2}}, "a",
                          {{td::MessageEntity::Type::Italic, 0, 1}}, true);
  check_parse_markdown_v3("~~__~~#test__test", "__#test__test", {{td::MessageEntity::Type::Strikethrough, 0, 2}});
  check_parse_markdown_v3("__#test__test", {{td::MessageEntity::Type::Strikethrough, 0, 2}}, "#testtest",
                          {{td::MessageEntity::Type::Italic, 0, 5}});

  check_parse_markdown_v3(
      "~~**~~||**a||", {{td::MessageEntity::Type::Strikethrough, 2, 1}, {td::MessageEntity::Type::Bold, 6, 1}},
      "**||**a||", {{td::MessageEntity::Type::Strikethrough, 0, 2}, {td::MessageEntity::Type::Bold, 2, 1}}, true);
  check_parse_markdown_v3("**||**a||",
                          {{td::MessageEntity::Type::Strikethrough, 0, 2}, {td::MessageEntity::Type::Bold, 2, 1}},
                          "||a||", {{td::MessageEntity::Type::Bold, 0, 2}}, true);
  check_parse_markdown_v3("||a||", {{td::MessageEntity::Type::Bold, 0, 2}}, "a",
                          {{td::MessageEntity::Type::Spoiler, 0, 1}}, true);
  check_parse_markdown_v3("~~||~~#test||test", "#testtest", {{td::MessageEntity::Type::Spoiler, 0, 5}});
  check_parse_markdown_v3("||#test||test", {{td::MessageEntity::Type::Strikethrough, 0, 2}}, "#testtest",
                          {{td::MessageEntity::Type::Spoiler, 0, 5}});

  check_parse_markdown_v3("__[ab_](t.me)_", "__ab__", {{td::MessageEntity::Type::TextUrl, 2, 3, "http://t.me/"}});
  check_parse_markdown_v3(
      "__[ab__](t.me)_", "ab_",
      {{td::MessageEntity::Type::TextUrl, 0, 2, "http://t.me/"}, {td::MessageEntity::Type::Italic, 0, 2}});
  check_parse_markdown_v3("__[__ab__](t.me)__", "____ab____",
                          {{td::MessageEntity::Type::TextUrl, 2, 6, "http://t.me/"}});
  check_parse_markdown_v3(
      "__[__ab__](t.me)a__", "____aba",
      {{td::MessageEntity::Type::TextUrl, 2, 4, "http://t.me/"}, {td::MessageEntity::Type::Italic, 6, 1}});
  check_parse_markdown_v3("`a` __ab__", {{td::MessageEntity::Type::Bold, 6, 3}}, "a __ab__",
                          {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Bold, 4, 3}});
  check_parse_markdown_v3("`a` __ab__", {{td::MessageEntity::Type::Underline, 5, 1}}, "a __ab__",
                          {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Underline, 3, 1}});

  check_parse_markdown_v3("||[ab|](t.me)|", "||ab||", {{td::MessageEntity::Type::TextUrl, 2, 3, "http://t.me/"}});
  check_parse_markdown_v3(
      "||[ab||](t.me)|", "ab|",
      {{td::MessageEntity::Type::TextUrl, 0, 2, "http://t.me/"}, {td::MessageEntity::Type::Spoiler, 0, 2}});
  check_parse_markdown_v3("||[||ab||](t.me)||", "||||ab||||",
                          {{td::MessageEntity::Type::TextUrl, 2, 6, "http://t.me/"}});
  check_parse_markdown_v3(
      "||[||ab||](t.me)a||", "||||aba",
      {{td::MessageEntity::Type::TextUrl, 2, 4, "http://t.me/"}, {td::MessageEntity::Type::Spoiler, 6, 1}});
  check_parse_markdown_v3("`a` ||ab||", {{td::MessageEntity::Type::Bold, 6, 3}}, "a ||ab||",
                          {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Bold, 4, 3}});
  check_parse_markdown_v3("`a` ||ab||", {{td::MessageEntity::Type::Underline, 5, 1}}, "a ||ab||",
                          {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Underline, 3, 1}});

  check_parse_markdown_v3("`a` @test__test__test", "a @test__test__test", {{td::MessageEntity::Type::Code, 0, 1}});
  check_parse_markdown_v3("`a` #test__test__test", "a #test__test__test", {{td::MessageEntity::Type::Code, 0, 1}});
  check_parse_markdown_v3("`a` __@test_test_test__", "a @test_test_test",
                          {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Italic, 2, 15}});
  check_parse_markdown_v3("`a` __#test_test_test__", "a #test_test_test",
                          {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Italic, 2, 15}});
  check_parse_markdown_v3("[a](t.me) __@test**test**test__", "a @testtesttest",
                          {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"},
                           {td::MessageEntity::Type::Italic, 2, 13},
                           {td::MessageEntity::Type::Bold, 7, 4}});
  check_parse_markdown_v3("[a](t.me) __#test~~test~~test__", "a #testtesttest",
                          {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"},
                           {td::MessageEntity::Type::Italic, 2, 13},
                           {td::MessageEntity::Type::Strikethrough, 7, 4}});
  check_parse_markdown_v3("[a](t.me) __@test__test__test__", "a @testtesttest",
                          {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"},
                           {td::MessageEntity::Type::Italic, 2, 5},
                           {td::MessageEntity::Type::Italic, 11, 4}});
  check_parse_markdown_v3("__**~~__gh**~~", "gh",
                          {{td::MessageEntity::Type::Bold, 0, 2}, {td::MessageEntity::Type::Strikethrough, 0, 2}});
  check_parse_markdown_v3("__ab**cd~~ef__gh**ij~~", "abcdefghij",
                          {{td::MessageEntity::Type::Italic, 0, 6},
                           {td::MessageEntity::Type::Bold, 2, 6},
                           {td::MessageEntity::Type::Strikethrough, 4, 6}});
  check_parse_markdown_v3("__ab**cd~~ef||gh__ij**kl~~mn||", "abcdefghijklmn",
                          {{td::MessageEntity::Type::Italic, 0, 2},
                           {td::MessageEntity::Type::Bold, 2, 2},
                           {td::MessageEntity::Type::Italic, 2, 2},
                           {td::MessageEntity::Type::Bold, 4, 2},
                           {td::MessageEntity::Type::Italic, 4, 2},
                           {td::MessageEntity::Type::Strikethrough, 4, 2},
                           {td::MessageEntity::Type::Spoiler, 6, 8},
                           {td::MessageEntity::Type::Strikethrough, 6, 6},
                           {td::MessageEntity::Type::Bold, 6, 4},
                           {td::MessageEntity::Type::Italic, 6, 2}},
                          true);
  check_parse_markdown_v3("__ab**[cd~~ef__](t.me)gh**ij~~", "abcdefghij",
                          {{td::MessageEntity::Type::Italic, 0, 6},
                           {td::MessageEntity::Type::Bold, 2, 6},
                           {td::MessageEntity::Type::TextUrl, 2, 4, "http://t.me/"},
                           {td::MessageEntity::Type::Strikethrough, 4, 6}});
  check_parse_markdown_v3("__ab**[cd~~e](t.me)f__gh**ij~~", "abcdefghij",
                          {{td::MessageEntity::Type::Italic, 0, 6},
                           {td::MessageEntity::Type::Bold, 2, 6},
                           {td::MessageEntity::Type::TextUrl, 2, 3, "http://t.me/"},
                           {td::MessageEntity::Type::Strikethrough, 4, 6}});
  check_parse_markdown_v3("__ab**[cd~~](t.me)ef__gh**ij~~", "abcdefghij",
                          {{td::MessageEntity::Type::Italic, 0, 6},
                           {td::MessageEntity::Type::Bold, 2, 6},
                           {td::MessageEntity::Type::TextUrl, 2, 2, "http://t.me/"},
                           {td::MessageEntity::Type::Strikethrough, 4, 6}});
  check_parse_markdown_v3("[__**bold italic link**__](example.com)", "bold italic link",
                          {{td::MessageEntity::Type::TextUrl, 0, 16, "http://example.com/"},
                           {td::MessageEntity::Type::Bold, 0, 16},
                           {td::MessageEntity::Type::Italic, 0, 16}});
  check_parse_markdown_v3(
      "__italic__ ~~strikethrough~~ **bold** `code` ```pre``` __[italic__ text_url](telegram.org) __italic**bold "
      "italic__bold**__italic__ ~~strikethrough~~ **bold** `code` ```pre``` __[italic__ text_url](telegram.org) "
      "__italic**bold italic__bold** ||spoiler|| ```pre\nprecode``` init",
      {{td::MessageEntity::Type::Italic, 271, 4}},
      "italic strikethrough bold code pre italic text_url italicbold italicbolditalic strikethrough bold code pre "
      "italic text_url italicbold italicbold spoiler precode init",
      {{td::MessageEntity::Type::Italic, 0, 6},
       {td::MessageEntity::Type::Strikethrough, 7, 13},
       {td::MessageEntity::Type::Bold, 21, 4},
       {td::MessageEntity::Type::Code, 26, 4},
       {td::MessageEntity::Type::Pre, 31, 3},
       {td::MessageEntity::Type::TextUrl, 35, 15, "http://telegram.org/"},
       {td::MessageEntity::Type::Italic, 35, 6},
       {td::MessageEntity::Type::Italic, 51, 17},
       {td::MessageEntity::Type::Bold, 57, 15},
       {td::MessageEntity::Type::Italic, 72, 6},
       {td::MessageEntity::Type::Strikethrough, 79, 13},
       {td::MessageEntity::Type::Bold, 93, 4},
       {td::MessageEntity::Type::Code, 98, 4},
       {td::MessageEntity::Type::Pre, 103, 3},
       {td::MessageEntity::Type::TextUrl, 107, 15, "http://telegram.org/"},
       {td::MessageEntity::Type::Italic, 107, 6},
       {td::MessageEntity::Type::Italic, 123, 17},
       {td::MessageEntity::Type::Bold, 129, 15},
       {td::MessageEntity::Type::Spoiler, 145, 7},
       {td::MessageEntity::Type::PreCode, 153, 7, "pre"},
       {td::MessageEntity::Type::Italic, 161, 4}});
  check_parse_markdown_v3("```\nsome code\n```", "some code\n", {{td::MessageEntity::Type::Pre, 0, 10}});
  check_parse_markdown_v3("asd\n```\nsome code\n```cabab", "asd\nsome code\ncabab",
                          {{td::MessageEntity::Type::Pre, 4, 10}});
  check_parse_markdown_v3("asd\naba```\nsome code\n```cabab", "asd\nabasome code\ncabab",
                          {{td::MessageEntity::Type::Pre, 7, 10}});
  check_parse_markdown_v3("asd\naba```\nsome code\n```\ncabab", "asd\nabasome code\n\ncabab",
                          {{td::MessageEntity::Type::Pre, 7, 10}});
  check_parse_markdown_v3("asd\naba```a b\nsome code\n```\ncabab", "asd\nabaa b\nsome code\n\ncabab",
                          {{td::MessageEntity::Type::Pre, 7, 14}});
  check_parse_markdown_v3("asd\naba```a!@#$%^&*(b\nsome code\n```\ncabab", "asd\nabasome code\n\ncabab",
                          {{td::MessageEntity::Type::PreCode, 7, 10, "a!@#$%^&*(b"}});
  check_parse_markdown_v3("```aba\n```", "aba\n", {{td::MessageEntity::Type::Pre, 0, 4}});
  check_parse_markdown_v3("```\n```", "\n", {{td::MessageEntity::Type::Pre, 0, 1}});
  check_parse_markdown_v3("```\n```", {{td::MessageEntity::Type::BlockQuote, 0, 7}}, "\n",
                          {{td::MessageEntity::Type::BlockQuote, 0, 1}, {td::MessageEntity::Type::Pre, 0, 1}});

  td::vector<td::string> parts{"a", " #test__a", "__", "**", "~~", "||", "[", "](t.me)", "`"};
  td::vector<td::MessageEntity::Type> types{
      td::MessageEntity::Type::Bold,          td::MessageEntity::Type::Italic,  td::MessageEntity::Type::Underline,
      td::MessageEntity::Type::Strikethrough, td::MessageEntity::Type::Spoiler, td::MessageEntity::Type::Code,
      td::MessageEntity::Type::Pre,           td::MessageEntity::Type::PreCode, td::MessageEntity::Type::TextUrl,
      td::MessageEntity::Type::MentionName,   td::MessageEntity::Type::Cashtag, td::MessageEntity::Type::BlockQuote};
  for (size_t test_n = 0; test_n < 1000; test_n++) {
    td::string str;
    int part_n = td::Random::fast(1, 200);
    for (int i = 0; i < part_n; i++) {
      str += parts[td::Random::fast(0, static_cast<int>(parts.size()) - 1)];
    }
    td::vector<td::MessageEntity> entities;
    int entity_n = td::Random::fast(1, 20);
    for (int i = 0; i < entity_n; i++) {
      auto type = types[td::Random::fast(0, static_cast<int>(types.size()) - 1)];
      td::int32 offset = td::Random::fast(0, static_cast<int>(str.size()) - 1);
      auto max_length = static_cast<int>(str.size() - offset);
      if ((test_n & 1) != 0 && max_length > 4) {
        max_length = 4;
      }
      td::int32 length = td::Random::fast(0, max_length);
      entities.emplace_back(type, offset, length);
    }

    td::FormattedText text{std::move(str), std::move(entities)};
    while (true) {
      ASSERT_TRUE(td::fix_formatted_text(text.text, text.entities, true, true, true, true, true).is_ok());
      auto parsed_text = td::parse_markdown_v3(text);
      ASSERT_TRUE(td::fix_formatted_text(parsed_text.text, parsed_text.entities, true, true, true, true, true).is_ok());
      if (parsed_text == text) {
        break;
      }
      text = std::move(parsed_text);
    }
    ASSERT_EQ(text, td::parse_markdown_v3(text));
    auto markdown_text = td::get_markdown_v3(text);
    ASSERT_TRUE(text == markdown_text || text == td::parse_markdown_v3(markdown_text));
  }
}

static void check_get_markdown_v3(const td::string &result_text, const td::vector<td::MessageEntity> &result_entities,
                                  td::string text, td::vector<td::MessageEntity> entities) {
  auto markdown_text = td::get_markdown_v3({std::move(text), std::move(entities)});
  ASSERT_STREQ(result_text, markdown_text.text);
  ASSERT_EQ(result_entities, markdown_text.entities);
}

TEST(MessageEntities, get_markdown_v3) {
  check_get_markdown_v3("```\n ```", {}, " ", {{td::MessageEntity::Type::Pre, 0, 1}});
  check_get_markdown_v3("` `", {}, " ", {{td::MessageEntity::Type::Code, 0, 1}});
  check_get_markdown_v3("`\n`", {}, "\n", {{td::MessageEntity::Type::Code, 0, 1}});
  check_get_markdown_v3("ab", {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Pre, 1, 1}}, "ab",
                        {{td::MessageEntity::Type::Code, 0, 1}, {td::MessageEntity::Type::Pre, 1, 1}});

  check_get_markdown_v3("[ ](http://t.me/)", {}, " ", {{td::MessageEntity::Type::TextUrl, 0, 1, "http://t.me/"}});
  check_get_markdown_v3(
      "[ ]t.me[)](http://t.me/) [ ](t.me)", {{25, 1, td::UserId(static_cast<td::int64>(1))}}, "[ ]t.me) [ ](t.me)",
      {{td::MessageEntity::Type::TextUrl, 7, 1, "http://t.me/"}, {9, 1, td::UserId(static_cast<td::int64>(1))}});

  check_get_markdown_v3("__ __", {}, " ", {{td::MessageEntity::Type::Italic, 0, 1}});
  check_get_markdown_v3("** **", {}, " ", {{td::MessageEntity::Type::Bold, 0, 1}});
  check_get_markdown_v3("~~ ~~", {}, " ", {{td::MessageEntity::Type::Strikethrough, 0, 1}});
  check_get_markdown_v3("|| ||", {}, " ", {{td::MessageEntity::Type::Spoiler, 0, 1}});
  check_get_markdown_v3("__a__ **b** ~~c~~ ||d|| e", {{td::MessageEntity::Type::PreCode, 24, 1, " C++"}}, "a b c d e",
                        {{td::MessageEntity::Type::Italic, 0, 1},
                         {td::MessageEntity::Type::Bold, 2, 1},
                         {td::MessageEntity::Type::Strikethrough, 4, 1},
                         {td::MessageEntity::Type::Spoiler, 6, 1},
                         {td::MessageEntity::Type::PreCode, 8, 1, " C++"}});
  check_get_markdown_v3("```cpp\ngh```\n`ab`\n```\ncd```\nef", {{td::MessageEntity::Type::PreCode, 28, 2, " C++"}},
                        "gh\nab\ncd\nef",
                        {{td::MessageEntity::Type::PreCode, 0, 2, "cpp"},
                         {td::MessageEntity::Type::Code, 3, 2},
                         {td::MessageEntity::Type::Pre, 6, 2},
                         {td::MessageEntity::Type::PreCode, 9, 2, " C++"}});
  check_get_markdown_v3("__asd__[__ab__cd](http://t.me/)", {}, "asdabcd",
                        {{td::MessageEntity::Type::Italic, 0, 3},
                         {td::MessageEntity::Type::TextUrl, 3, 4, "http://t.me/"},
                         {td::MessageEntity::Type::Italic, 3, 2}});

  check_get_markdown_v3("__ab", {{td::MessageEntity::Type::Italic, 3, 1}}, "__ab",
                        {{td::MessageEntity::Type::Italic, 3, 1}});
  check_get_markdown_v3("__ab__**__cd__**~~**__ef__gh**ij~~", {}, "abcdefghij",
                        {{td::MessageEntity::Type::Italic, 0, 2},
                         {td::MessageEntity::Type::Bold, 2, 2},
                         {td::MessageEntity::Type::Italic, 2, 2},
                         {td::MessageEntity::Type::Strikethrough, 4, 6},
                         {td::MessageEntity::Type::Bold, 4, 4},
                         {td::MessageEntity::Type::Italic, 4, 2}});
  check_get_markdown_v3("[**__bold italic link__**](http://example.com/)", {}, "bold italic link",
                        {{td::MessageEntity::Type::TextUrl, 0, 16, "http://example.com/"},
                         {td::MessageEntity::Type::Bold, 0, 16},
                         {td::MessageEntity::Type::Italic, 0, 16}});
  check_get_markdown_v3("```\nsome code\n```", {}, "some code\n", {{td::MessageEntity::Type::Pre, 0, 10}});
  check_get_markdown_v3("asd\n```\nsome code\n```cabab", {}, "asd\nsome code\ncabab",
                        {{td::MessageEntity::Type::Pre, 4, 10}});
  check_get_markdown_v3("asd\naba```\nsome code\n```cabab", {}, "asd\nabasome code\ncabab",
                        {{td::MessageEntity::Type::Pre, 7, 10}});
  check_get_markdown_v3("asd\naba```\nsome code\n```\ncabab", {}, "asd\nabasome code\n\ncabab",
                        {{td::MessageEntity::Type::Pre, 7, 10}});
  check_get_markdown_v3("asd\naba```\na b\nsome code\n```\ncabab", {}, "asd\nabaa b\nsome code\n\ncabab",
                        {{td::MessageEntity::Type::Pre, 7, 14}});
  check_get_markdown_v3("asd\n```\na b\nsome code\n```\ncabab", {}, "asd\na b\nsome code\n\ncabab",
                        {{td::MessageEntity::Type::Pre, 4, 14}});
  check_get_markdown_v3("asd\naba```a!@#$%^&*(b\nsome code\n```\ncabab", {}, "asd\nabasome code\n\ncabab",
                        {{td::MessageEntity::Type::PreCode, 7, 10, "a!@#$%^&*(b"}});
  check_get_markdown_v3("```\naba\n```", {}, "aba\n", {{td::MessageEntity::Type::Pre, 0, 4}});
  check_get_markdown_v3("```\n```", {}, "\n", {{td::MessageEntity::Type::Pre, 0, 1}});
}
