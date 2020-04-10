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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "td/utils/tests.h"

#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"

#include <tuple>
#include <utility>

REGISTER_TESTS(json)

using namespace td;

static void decode_encode(string str, string result = "") {
  auto str_copy = str;
  auto r_value = json_decode(str_copy);
  ASSERT_TRUE(r_value.is_ok());
  if (r_value.is_error()) {
    LOG(INFO) << r_value.error();
    return;
  }
  auto new_str = json_encode<string>(r_value.ok());
  if (result.empty()) {
    result = str;
  }
  ASSERT_EQ(result, new_str);
}

TEST(JSON, array) {
  char tmp[1000];
  StringBuilder sb(MutableSlice{tmp, sizeof(tmp)});
  JsonBuilder jb(std::move(sb));
  jb.enter_value().enter_array() << "Hello" << -123;
  ASSERT_EQ(jb.string_builder().is_error(), false);
  auto encoded = jb.string_builder().as_cslice().str();
  ASSERT_EQ("[\"Hello\",-123]", encoded);
  decode_encode(encoded);
}
TEST(JSON, object) {
  char tmp[1000];
  StringBuilder sb(MutableSlice{tmp, sizeof(tmp)});
  JsonBuilder jb(std::move(sb));
  auto c = jb.enter_object();
  c << std::tie("key", "value");
  c << std::make_pair("1", 2);
  c.leave();
  ASSERT_EQ(jb.string_builder().is_error(), false);
  auto encoded = jb.string_builder().as_cslice().str();
  ASSERT_EQ("{\"key\":\"value\",\"1\":2}", encoded);
  decode_encode(encoded);
}

TEST(JSON, nested) {
  char tmp[1000];
  StringBuilder sb(MutableSlice{tmp, sizeof(tmp)});
  JsonBuilder jb(std::move(sb));
  {
    auto a = jb.enter_array();
    a << 1;
    { a.enter_value().enter_array() << 2; }
    a << 3;
  }
  ASSERT_EQ(jb.string_builder().is_error(), false);
  auto encoded = jb.string_builder().as_cslice().str();
  ASSERT_EQ("[1,[2],3]", encoded);
  decode_encode(encoded);
}

TEST(JSON, kphp) {
  decode_encode("[]");
  decode_encode("[[]]");
  decode_encode("{}");
  decode_encode("{}");
  decode_encode("\"\\n\"");
  decode_encode(
      "\""
      "some long string \\t \\r \\\\ \\n \\f \\\" "
      "\\u1234"
      "\"");
  decode_encode(
      "{\"keyboard\":[[\"\\u2022 abcdefg\"],[\"\\u2022 hijklmnop\"],[\"\\u2022 "
      "qrstuvwxyz\"]],\"one_time_keyboard\":true}");
  decode_encode(
      "  \n   {  \"keyboard\"  : \n  [[  \"\\u2022 abcdefg\"  ]  , \n [  \"\\u2022 hijklmnop\" \n ],[  \n \"\\u2022 "
      "qrstuvwxyz\"]], \n  \"one_time_keyboard\"\n:\ntrue\n}\n   \n",
      "{\"keyboard\":[[\"\\u2022 abcdefg\"],[\"\\u2022 hijklmnop\"],[\"\\u2022 "
      "qrstuvwxyz\"]],\"one_time_keyboard\":true}");
}
