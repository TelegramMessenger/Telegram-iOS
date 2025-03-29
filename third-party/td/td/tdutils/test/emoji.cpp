//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/emoji.h"
#include "td/utils/tests.h"

TEST(Emoji, is_emoji) {
  ASSERT_TRUE(!td::is_emoji(""));
  ASSERT_TRUE(td::is_emoji("👩🏼‍❤‍💋‍👩🏻"));
  ASSERT_TRUE(td::is_emoji("👩🏼‍❤‍💋‍👩🏻️"));  // not in RGI emoji ZWJ sequence set
  ASSERT_TRUE(td::is_emoji("👩🏼‍❤️‍💋‍👩🏻"));
  ASSERT_TRUE(td::is_emoji("👩🏼‍❤️‍💋‍👩🏻️"));
  ASSERT_TRUE(!td::is_emoji("👩🏼‍❤️️‍💋‍👩🏻"));
  ASSERT_TRUE(td::is_emoji("⌚"));
  ASSERT_TRUE(td::is_emoji("⌚️"));
  ASSERT_TRUE(td::is_emoji("↔"));
  ASSERT_TRUE(td::is_emoji("🪗"));
  ASSERT_TRUE(td::is_emoji("2️⃣"));
  ASSERT_TRUE(td::is_emoji("2⃣"));
  ASSERT_TRUE(!td::is_emoji(" 2⃣"));
  ASSERT_TRUE(!td::is_emoji("2⃣ "));
  ASSERT_TRUE(!td::is_emoji(" "));
  ASSERT_TRUE(!td::is_emoji(""));
  ASSERT_TRUE(!td::is_emoji("1234567890123456789012345678901234567890123456789012345678901234567890"));
  ASSERT_TRUE(td::is_emoji("❤️"));
  ASSERT_TRUE(td::is_emoji("❤"));
  ASSERT_TRUE(td::is_emoji("⌚"));
  ASSERT_TRUE(td::is_emoji("🎄"));
  ASSERT_TRUE(td::is_emoji("🧑‍🎄"));
  ASSERT_TRUE(td::is_emoji("©️"));
  ASSERT_TRUE(td::is_emoji("©"));
  ASSERT_TRUE(!td::is_emoji("©️️"));
  ASSERT_TRUE(td::is_emoji("🕵️‍♂️"));
  ASSERT_TRUE(td::is_emoji("🕵‍♂️"));  // not in RGI emoji ZWJ sequence set
  ASSERT_TRUE(td::is_emoji("🕵️‍♂"));  // not in RGI emoji ZWJ sequence set
  ASSERT_TRUE(td::is_emoji("🕵‍♂"));
  ASSERT_TRUE(td::is_emoji("🏌️‍♂️"));
  ASSERT_TRUE(td::is_emoji("🏋️‍♂️"));
  ASSERT_TRUE(td::is_emoji("🏌‍♂️"));  // not in RGI emoji ZWJ sequence set
  ASSERT_TRUE(td::is_emoji("🏋‍♂️"));  // not in RGI emoji ZWJ sequence set
  ASSERT_TRUE(!td::is_emoji("a‍🤝‍👨"));
  ASSERT_TRUE(!td::is_emoji("👩‍a‍👨"));
  ASSERT_TRUE(!td::is_emoji("👩‍🤝‍a"));
  ASSERT_TRUE(td::is_emoji("👩‍🤝‍👨"));  // not in RGI emoji ZWJ sequence set
}

static void test_get_fitzpatrick_modifier(td::string emoji, int result) {
  ASSERT_EQ(result, td::get_fitzpatrick_modifier(emoji));
}

TEST(Emoji, get_fitzpatrick_modifier) {
  test_get_fitzpatrick_modifier("", 0);
  test_get_fitzpatrick_modifier("👩🏼‍❤‍💋‍👩🏻", 2);
  test_get_fitzpatrick_modifier("👩🏼‍❤️‍💋‍👩🏻", 2);
  test_get_fitzpatrick_modifier("👋", 0);
  test_get_fitzpatrick_modifier("👋🏻", 2);
  test_get_fitzpatrick_modifier("👋🏼", 3);
  test_get_fitzpatrick_modifier("👋🏽", 4);
  test_get_fitzpatrick_modifier("👋🏾", 5);
  test_get_fitzpatrick_modifier("👋🏿", 6);
  test_get_fitzpatrick_modifier("🏻", 2);
  test_get_fitzpatrick_modifier("🏼", 3);
  test_get_fitzpatrick_modifier("🏽", 4);
  test_get_fitzpatrick_modifier("🏾", 5);
  test_get_fitzpatrick_modifier("🏿", 6);
  test_get_fitzpatrick_modifier("⌚", 0);
  test_get_fitzpatrick_modifier("↔", 0);
  test_get_fitzpatrick_modifier("🪗", 0);
  test_get_fitzpatrick_modifier("2️⃣", 0);
  test_get_fitzpatrick_modifier("2⃣", 0);
  test_get_fitzpatrick_modifier("❤️", 0);
  test_get_fitzpatrick_modifier("❤", 0);
  test_get_fitzpatrick_modifier("⌚", 0);
  test_get_fitzpatrick_modifier("🎄", 0);
  test_get_fitzpatrick_modifier("🧑‍🎄", 0);
}

static void test_remove_emoji_modifiers(td::string emoji, const td::string &result, bool remove_selectors = true) {
  ASSERT_STREQ(result, td::remove_emoji_modifiers(emoji, remove_selectors));
  td::remove_emoji_modifiers_in_place(emoji, remove_selectors);
  ASSERT_STREQ(result, emoji);
  ASSERT_STREQ(emoji, td::remove_emoji_modifiers(emoji, remove_selectors));
}

TEST(Emoji, remove_emoji_modifiers) {
  test_remove_emoji_modifiers("", "");
  test_remove_emoji_modifiers("👩🏼‍❤‍💋‍👩🏻", "👩‍❤‍💋‍👩");
  test_remove_emoji_modifiers("👩🏼‍❤️‍💋‍👩🏻", "👩‍❤‍💋‍👩");
  test_remove_emoji_modifiers("👩🏼‍❤️‍💋‍👩🏻", "👩‍❤️‍💋‍👩", false);
  test_remove_emoji_modifiers("👋🏻", "👋");
  test_remove_emoji_modifiers("👋🏼", "👋");
  test_remove_emoji_modifiers("👋🏽", "👋");
  test_remove_emoji_modifiers("👋🏾", "👋");
  test_remove_emoji_modifiers("👋🏿", "👋");
  test_remove_emoji_modifiers("🏻", "🏻");
  test_remove_emoji_modifiers("🏼", "🏼");
  test_remove_emoji_modifiers("🏽", "🏽");
  test_remove_emoji_modifiers("🏾", "🏾");
  test_remove_emoji_modifiers("🏿", "🏿");
  test_remove_emoji_modifiers("⌚", "⌚");
  test_remove_emoji_modifiers("↔", "↔");
  test_remove_emoji_modifiers("🪗", "🪗");
  test_remove_emoji_modifiers("2️⃣", "2⃣");
  test_remove_emoji_modifiers("2⃣", "2⃣");
  test_remove_emoji_modifiers("❤️", "❤");
  test_remove_emoji_modifiers("❤", "❤");
  test_remove_emoji_modifiers("⌚", "⌚");
  test_remove_emoji_modifiers("️", "️");
  test_remove_emoji_modifiers("️️️🏻", "️️️🏻");
  test_remove_emoji_modifiers("️️️🏻a", "a");
  test_remove_emoji_modifiers("🎄", "🎄");
  test_remove_emoji_modifiers("🧑‍🎄", "🧑‍🎄");
}

static void test_remove_emoji_selectors(td::string emoji, const td::string &result) {
  ASSERT_STREQ(result, td::remove_emoji_selectors(result));
  ASSERT_STREQ(result, td::remove_emoji_selectors(emoji));
}

TEST(Emoji, remove_emoji_selectors) {
  test_remove_emoji_selectors("", "");
  test_remove_emoji_selectors("👩🏼‍❤‍💋‍👩🏻", "👩🏼‍❤‍💋‍👩🏻");
  test_remove_emoji_selectors("👩🏼‍❤️‍💋‍👩🏻", "👩🏼‍❤‍💋‍👩🏻");
  test_remove_emoji_selectors("👋🏻", "👋🏻");
  test_remove_emoji_selectors("👋🏼", "👋🏼");
  test_remove_emoji_selectors("👋🏽", "👋🏽");
  test_remove_emoji_selectors("👋🏾", "👋🏾");
  test_remove_emoji_selectors("👋🏿", "👋🏿");
  test_remove_emoji_selectors("🏻", "🏻");
  test_remove_emoji_selectors("🏼", "🏼");
  test_remove_emoji_selectors("🏽", "🏽");
  test_remove_emoji_selectors("🏾", "🏾");
  test_remove_emoji_selectors("🏿", "🏿");
  test_remove_emoji_selectors("⌚", "⌚");
  test_remove_emoji_selectors("↔", "↔");
  test_remove_emoji_selectors("🪗", "🪗");
  test_remove_emoji_selectors("2️⃣", "2⃣");
  test_remove_emoji_selectors("2⃣", "2⃣");
  test_remove_emoji_selectors("❤️", "❤");
  test_remove_emoji_selectors("❤", "❤");
  test_remove_emoji_selectors("⌚", "⌚");
  test_remove_emoji_selectors("🎄", "🎄");
  test_remove_emoji_selectors("🧑‍🎄", "🧑‍🎄");
}
