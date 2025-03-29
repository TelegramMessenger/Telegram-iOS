//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/JsonBuilder.h"
#include "td/utils/logging.h"
#include "td/utils/Parser.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"

#include <utility>

static void decode_encode(const td::string &str, td::string result = td::string()) {
  auto str_copy = str;
  auto r_value = td::json_decode(str_copy);
  ASSERT_TRUE(r_value.is_ok());
  if (r_value.is_error()) {
    LOG(INFO) << r_value.error();
    return;
  }
  auto new_str = td::json_encode<td::string>(r_value.ok());
  if (result.empty()) {
    result = str;
  }
  ASSERT_EQ(result, new_str);
}

TEST(JSON, array) {
  char tmp[1000];
  td::StringBuilder sb(td::MutableSlice{tmp, sizeof(tmp)});
  td::JsonBuilder jb(std::move(sb));
  jb.enter_value().enter_array() << "Hello" << -123;
  ASSERT_EQ(jb.string_builder().is_error(), false);
  auto encoded = jb.string_builder().as_cslice().str();
  ASSERT_EQ("[\"Hello\",-123]", encoded);
  decode_encode(encoded);
}

TEST(JSON, object) {
  char tmp[1000];
  td::StringBuilder sb(td::MutableSlice{tmp, sizeof(tmp)});
  td::JsonBuilder jb(std::move(sb));
  auto c = jb.enter_object();
  c("key", "value");
  c("1", 2);
  c.leave();
  ASSERT_EQ(jb.string_builder().is_error(), false);
  auto encoded = jb.string_builder().as_cslice().str();
  ASSERT_EQ("{\"key\":\"value\",\"1\":2}", encoded);
  decode_encode(encoded);
}

TEST(JSON, nested) {
  char tmp[1000];
  td::StringBuilder sb(td::MutableSlice{tmp, sizeof(tmp)});
  td::JsonBuilder jb(std::move(sb));
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

TEST(JSON, json_object_get_field) {
  const td::string encoded_object =
      "{\"null\":null,\"bool\":true,\"int\":\"1\",\"int2\":2,\"long\":\"123456789012\",\"long2\":2123456789012,"
      "\"double\":12345678901.1,\"string\":\"string\",\"string2\":12345e+1,\"array\":[],\"object\":{}}";
  {
    td::string encoded_object_copy = encoded_object;
    auto value = td::json_decode(encoded_object_copy).move_as_ok();
    auto &object = value.get_object();
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("null")), "null");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("bool")), "true");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("bool")), "null");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("int")), "\"1\"");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("int2")), "2");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("int3")), "null");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("long")), "\"123456789012\"");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("long2")), "2123456789012");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("double")), "12345678901.1");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("string")), "\"string\"");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("string2")), "12345e+1");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("array")), "[]");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("object")), "{}");
    ASSERT_EQ(td::json_encode<td::string>(object.extract_field("")), "null");
  }

  {
    td::string encoded_object_copy = encoded_object;
    auto value = td::json_decode(encoded_object_copy).move_as_ok();
    auto &object = value.get_object();
    ASSERT_TRUE(object.extract_optional_field("int", td::JsonValue::Type::Number).is_error());
    ASSERT_TRUE(object.extract_optional_field("int", td::JsonValue::Type::Number).is_error());
    ASSERT_TRUE(object.extract_optional_field("int2", td::JsonValue::Type::Number).is_ok());
    ASSERT_TRUE(object.extract_optional_field("int2", td::JsonValue::Type::Number).is_error());
    ASSERT_TRUE(object.extract_optional_field("int3", td::JsonValue::Type::Number).is_ok());
    ASSERT_TRUE(object.extract_optional_field("int3", td::JsonValue::Type::Null).is_ok());
    ASSERT_EQ(object.extract_optional_field("int", td::JsonValue::Type::String).ok().get_string(), "1");
    ASSERT_TRUE(object.extract_optional_field("int", td::JsonValue::Type::Number).is_error());
    ASSERT_EQ(object.extract_optional_field("int", td::JsonValue::Type::Null).ok().type(), td::JsonValue::Type::Null);

    ASSERT_TRUE(object.extract_required_field("long", td::JsonValue::Type::Number).is_error());
    ASSERT_TRUE(object.extract_required_field("long", td::JsonValue::Type::Number).is_error());
    ASSERT_TRUE(object.extract_required_field("long2", td::JsonValue::Type::Number).is_ok());
    ASSERT_TRUE(object.extract_required_field("long2", td::JsonValue::Type::Number).is_error());
    ASSERT_TRUE(object.extract_required_field("long3", td::JsonValue::Type::Number).is_error());
    ASSERT_TRUE(object.extract_required_field("long3", td::JsonValue::Type::Null).is_error());
    ASSERT_EQ(object.extract_required_field("long", td::JsonValue::Type::String).ok().get_string(), "123456789012");
    ASSERT_TRUE(object.extract_required_field("long", td::JsonValue::Type::Number).is_error());
    ASSERT_EQ(object.extract_required_field("long", td::JsonValue::Type::Null).ok().type(), td::JsonValue::Type::Null);
  }

  td::string encoded_object_copy = encoded_object;
  auto value = td::json_decode(encoded_object_copy).move_as_ok();
  const auto &object = value.get_object();
  ASSERT_TRUE(object.has_field("null"));
  ASSERT_TRUE(object.has_field("object"));
  ASSERT_TRUE(!object.has_field(""));
  ASSERT_TRUE(!object.has_field("objec"));
  ASSERT_TRUE(!object.has_field("object2"));

  ASSERT_TRUE(object.get_optional_bool_field("int").is_error());
  ASSERT_EQ(object.get_optional_bool_field("bool").ok(), true);
  ASSERT_EQ(object.get_optional_bool_field("bool", false).ok(), true);
  ASSERT_EQ(object.get_required_bool_field("bool").ok(), true);
  ASSERT_EQ(object.get_optional_bool_field("bool3").ok(), false);
  ASSERT_EQ(object.get_optional_bool_field("bool4", true).ok(), true);
  ASSERT_TRUE(object.get_required_bool_field("bool5").is_error());

  ASSERT_TRUE(object.get_optional_int_field("null").is_error());
  ASSERT_EQ(object.get_optional_int_field("int").ok(), 1);
  ASSERT_EQ(object.get_optional_int_field("int").ok(), 1);
  ASSERT_EQ(object.get_required_int_field("int").ok(), 1);
  ASSERT_EQ(object.get_optional_int_field("int2").ok(), 2);
  ASSERT_EQ(object.get_optional_int_field("int2").ok(), 2);
  ASSERT_EQ(object.get_required_int_field("int2").ok(), 2);
  ASSERT_EQ(object.get_optional_int_field("int3").ok(), 0);
  ASSERT_EQ(object.get_optional_int_field("int4", 5).ok(), 5);
  ASSERT_TRUE(object.get_required_int_field("int5").is_error());
  ASSERT_EQ(object.get_optional_int_field("long").is_error(), true);
  ASSERT_EQ(object.get_optional_int_field("long2").is_error(), true);

  ASSERT_TRUE(object.get_optional_long_field("null").is_error());
  ASSERT_EQ(object.get_optional_long_field("long").ok(), 123456789012);
  ASSERT_EQ(object.get_optional_long_field("long").ok(), 123456789012);
  ASSERT_EQ(object.get_required_long_field("long").ok(), 123456789012);
  ASSERT_EQ(object.get_optional_long_field("long2").ok(), 2123456789012);
  ASSERT_EQ(object.get_optional_long_field("long2").ok(), 2123456789012);
  ASSERT_EQ(object.get_required_long_field("long2").ok(), 2123456789012);
  ASSERT_EQ(object.get_optional_long_field("long3").ok(), 0);
  ASSERT_EQ(object.get_optional_long_field("long4", 5).ok(), 5);
  ASSERT_TRUE(object.get_required_long_field("long5").is_error());
  ASSERT_EQ(object.get_optional_long_field("int").ok(), 1);
  ASSERT_EQ(object.get_optional_long_field("int2").ok(), 2);

  auto are_equal_double = [](double lhs, double rhs) {
    return rhs - 1e-3 < lhs && lhs < rhs + 1e-3;
  };

  ASSERT_TRUE(object.get_optional_double_field("null").is_error());
  ASSERT_TRUE(are_equal_double(object.get_optional_double_field("double").ok(), 12345678901.1));
  ASSERT_TRUE(are_equal_double(object.get_optional_double_field("double").ok(), 12345678901.1));
  ASSERT_TRUE(are_equal_double(object.get_required_double_field("double").ok(), 12345678901.1));
  ASSERT_TRUE(are_equal_double(object.get_optional_double_field("long2").ok(), 2123456789012.0));
  ASSERT_TRUE(are_equal_double(object.get_optional_double_field("long2").ok(), 2123456789012.0));
  ASSERT_TRUE(are_equal_double(object.get_required_double_field("long2").ok(), 2123456789012.0));
  ASSERT_TRUE(are_equal_double(object.get_optional_double_field("double3").ok(), 0.0));
  ASSERT_TRUE(are_equal_double(object.get_optional_double_field("double4", -5.23).ok(), -5.23));
  ASSERT_TRUE(object.get_required_double_field("double5").is_error());
  ASSERT_TRUE(object.get_optional_double_field("int").is_error());
  ASSERT_TRUE(are_equal_double(object.get_optional_double_field("int2").ok(), 2));

  ASSERT_TRUE(object.get_optional_string_field("null").is_error());
  ASSERT_EQ(object.get_optional_string_field("string").ok(), "string");
  ASSERT_EQ(object.get_optional_string_field("string").ok(), "string");
  ASSERT_EQ(object.get_required_string_field("string").ok(), "string");
  ASSERT_EQ(object.get_optional_string_field("string2").ok(), "12345e+1");
  ASSERT_EQ(object.get_optional_string_field("string2").ok(), "12345e+1");
  ASSERT_EQ(object.get_required_string_field("string2").ok(), "12345e+1");
  ASSERT_EQ(object.get_optional_string_field("string3").ok(), td::string());
  ASSERT_EQ(object.get_optional_string_field("string4", "abacaba").ok(), "abacaba");
  ASSERT_TRUE(object.get_required_string_field("string5").is_error());
  ASSERT_EQ(object.get_optional_string_field("int").ok(), "1");
  ASSERT_EQ(object.get_optional_string_field("int2").ok(), "2");
}

class JsonStringDecodeBenchmark final : public td::Benchmark {
  td::string str_;

 public:
  explicit JsonStringDecodeBenchmark(td::string str) : str_('"' + str + '"') {
  }

  td::string get_description() const final {
    return td::string("JsonStringDecodeBenchmark") + str_.substr(1, 6);
  }

  void run(int n) final {
    for (int i = 0; i < n; i++) {
      auto str = str_;
      td::Parser parser(str);
      td::json_string_decode(parser).ensure();
    }
  }
};

TEST(JSON, bench_json_string_decode) {
  td::bench(JsonStringDecodeBenchmark(td::string(1000, 'a')));
  td::bench(JsonStringDecodeBenchmark(td::string(1000, '\\')));
  td::string str;
  for (int i = 32; i < 128; i++) {
    if (i == 'u') {
      continue;
    }
    str += "a\\";
    str += static_cast<char>(i);
  }
  td::bench(JsonStringDecodeBenchmark(str));
}

static void test_string_decode(td::string str, const td::string &result) {
  auto str_copy = str;
  td::Parser skip_parser(str_copy);
  auto status = td::json_string_skip(skip_parser);
  ASSERT_TRUE(status.is_ok());
  ASSERT_TRUE(skip_parser.empty());

  td::Parser parser(str);
  auto r_value = td::json_string_decode(parser);
  ASSERT_TRUE(r_value.is_ok());
  ASSERT_TRUE(parser.empty());
  ASSERT_EQ(result, r_value.ok());
}

static void test_string_decode_error(td::string str) {
  auto str_copy = str;
  td::Parser skip_parser(str_copy);
  auto status = td::json_string_skip(skip_parser);
  ASSERT_TRUE(status.is_error());

  td::Parser parser(str);
  auto r_value = td::json_string_decode(parser);
  ASSERT_TRUE(r_value.is_error());
}

TEST(JSON, string_decode) {
  test_string_decode("\"\"", "");
  test_string_decode("\"abacaba\"", "abacaba");
  test_string_decode(
      "\"\\1\\a\\b\\c\\d\\e\\f\\g\\h\\i\\j\\k\\l\\m\\n\\o\\p\\q\\r\\s\\t\\u00201\\v\\w\\x\\y\\z\\U\\\"\\\\\\/\\+\\-\"",
      "1a\bcde\fghijklm\nopq\rs\t 1vwxyzU\"\\/+-");
  test_string_decode("\"\\u0373\\ud7FB\\uD840\\uDC04\\uD840a\\uD840\\u0373\"",
                     "\xCD\xB3\xED\x9F\xBB\xF0\xA0\x80\x84\xed\xa1\x80\x61\xed\xa1\x80\xCD\xB3");

  test_string_decode_error(" \"\"");
  test_string_decode_error("\"");
  test_string_decode_error("\"\\");
  test_string_decode_error("\"\\b'");
  test_string_decode_error("\"\\u\"");
  test_string_decode_error("\"\\u123\"");
  test_string_decode_error("\"\\u123g\"");
  test_string_decode_error("\"\\u123G\"");
  test_string_decode_error("\"\\u123 \"");
  test_string_decode_error("\"\\ug123\"");
  test_string_decode_error("\"\\uG123\"");
  test_string_decode_error("\"\\u 123\"");
  test_string_decode_error("\"\\uD800\\ug123\"");
  test_string_decode_error("\"\\uD800\\u123\"");
}
