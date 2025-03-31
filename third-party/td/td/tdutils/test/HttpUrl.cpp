//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/HttpUrl.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tests.h"

#include <utility>

static void test_parse_url(const td::string &url, td::string userinfo, td::string host, bool is_ipv6,
                           int specified_port, int port) {
  for (auto query : {"", "/.com", "#", "?t=1"}) {
    auto http_url = td::parse_url(url + query).move_as_ok();
    ASSERT_EQ(userinfo, http_url.userinfo_);
    ASSERT_EQ(host, http_url.host_);
    ASSERT_EQ(is_ipv6, http_url.is_ipv6_);
    ASSERT_EQ(specified_port, http_url.specified_port_);
    ASSERT_EQ(port, http_url.port_);
  }
}

static void test_parse_url(const td::string &url, td::Slice error_message) {
  for (auto query : {"", "/.com", "#", "?t=1"}) {
    auto error = td::parse_url(url + query).move_as_error();
    ASSERT_EQ(error_message, error.message());
  }
}

TEST(HttpUrl, parse_url) {
  test_parse_url("http://localhost:8080", "", "localhost", false, 8080, 8080);
  test_parse_url("http://lOcAlhOsT:8080", "", "localhost", false, 8080, 8080);
  test_parse_url("http://UsEr:PaSs@lOcAlhOsT:8080", "UsEr:PaSs", "localhost", false, 8080, 8080);
  test_parse_url("http://example.com", "", "example.com", false, 0, 80);
  test_parse_url("https://example.com", "", "example.com", false, 0, 443);
  test_parse_url("https://example.com:65535", "", "example.com", false, 65535, 65535);
  test_parse_url("https://example.com:00000071", "", "example.com", false, 71, 71);
  test_parse_url("example.com?://", "", "example.com", false, 0, 80);
  test_parse_url("example.com/://", "", "example.com", false, 0, 80);
  test_parse_url("example.com#://", "", "example.com", false, 0, 80);
  test_parse_url("@example.com#://", "", "example.com", false, 0, 80);
  test_parse_url("test@example.com#://", "test", "example.com", false, 0, 80);
  test_parse_url("test:pass@example.com#://", "test:pass", "example.com", false, 0, 80);
  test_parse_url("te%ffst:pa%8Dss@examp%9Ele.com#://", "te%ffst:pa%8Dss", "examp%9ele.com", false, 0, 80);
  test_parse_url("http://[2001:db8:85a3:8d3:1319:8a2e:370:7348]", "", "[2001:db8:85a3:8d3:1319:8a2e:370:7348]", true, 0,
                 80);
  test_parse_url("https://test@[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/", "test",
                 "[2001:db8:85a3:8d3:1319:8a2e:370:7348]", true, 443, 443);
  test_parse_url("http://[64:ff9b::255.255.255.255]", "", "[64:ff9b::255.255.255.255]", true, 0, 80);
  test_parse_url("http://255.255.255.255", "", "255.255.255.255", false, 0, 80);
  test_parse_url("http://255.255.255.com", "", "255.255.255.com", false, 0, 80);
  test_parse_url("https://exam%00ple.com", "", "exam%00ple.com", false, 0, 443);

  test_parse_url("example.com://", "Unsupported URL protocol");
  test_parse_url("https://example.com:65536", "Wrong port number specified in the URL");
  test_parse_url("https://example.com:0", "Wrong port number specified in the URL");
  test_parse_url("https://example.com:0x1", "Wrong port number specified in the URL");
  test_parse_url("https://example.com:", "Wrong port number specified in the URL");
  test_parse_url("https://example.com:-1", "Wrong port number specified in the URL");
  test_parse_url("example.com@://", "Wrong port number specified in the URL");
  test_parse_url("example.com@:1//", "URL host is empty");
  test_parse_url("example.com@.:1//", "Host is invalid");
  test_parse_url("exam%0gple.com", "Wrong percent-encoded symbol in URL host");
  test_parse_url("a%g0b@example.com", "Wrong percent-encoded symbol in URL userinfo");

  for (int c = 1; c <= 255; c++) {
    if (c == '%') {
      continue;
    }
    auto ch = static_cast<char>(c);
    if (td::is_alnum(ch) || c >= 128 || td::string(".-_!$,~*\'();&+=").find(ch) != td::string::npos) {
      // allowed character
      test_parse_url(PSTRING() << ch << "a@b" << ch, td::string(1, ch) + "a", "b" + td::string(1, td::to_lower(ch)),
                     false, 0, 80);
    } else if (c == ':') {
      // allowed in userinfo character
      test_parse_url(PSTRING() << ch << "a@b" << ch << 1, td::string(1, ch) + "a", "b", false, 1, 1);
      test_parse_url(PSTRING() << ch << "a@b" << ch, "Wrong port number specified in the URL");
      test_parse_url(PSTRING() << ch << "a@b", td::string(1, ch) + "a", "b", false, 0, 80);
    } else if (c == '#' || c == '?' || c == '/') {
      // special disallowed character
      test_parse_url(PSTRING() << ch << "a@b" << ch, "URL host is empty");
    } else if (c == '@') {
      // special disallowed character
      test_parse_url(PSTRING() << ch << "a@b" << ch, "URL host is empty");
      test_parse_url(PSTRING() << ch << "a@b" << ch << '1', "Disallowed character in URL userinfo");
    } else {
      // generic disallowed character
      test_parse_url(PSTRING() << ch << "a@b" << ch, "Disallowed character in URL host");
      test_parse_url(PSTRING() << "a@b" << ch, "Disallowed character in URL host");
      test_parse_url(PSTRING() << ch << "a@b", "Disallowed character in URL userinfo");
    }
  }
}

static void test_get_url_query_file_name(const char *prefix, const char *suffix, const char *file_name) {
  auto path = td::string(prefix) + td::string(file_name) + td::string(suffix);
  ASSERT_STREQ(file_name, td::get_url_query_file_name(path));
  ASSERT_STREQ(file_name, td::get_url_file_name("http://telegram.org" + path));
  ASSERT_STREQ(file_name, td::get_url_file_name("http://telegram.org:80" + path));
  ASSERT_STREQ(file_name, td::get_url_file_name("telegram.org" + path));
}

TEST(HttpUrl, get_url_query_file_name) {
  for (auto suffix : {"?t=1#test", "#test?t=1", "#?t=1", "?t=1#", "#test", "?t=1", "#", "?", ""}) {
    test_get_url_query_file_name("", suffix, "");
    test_get_url_query_file_name("/", suffix, "");
    test_get_url_query_file_name("/a/adasd/", suffix, "");
    test_get_url_query_file_name("/a/lklrjetn/", suffix, "adasd.asdas");
    test_get_url_query_file_name("/", suffix, "a123asadas");
    test_get_url_query_file_name("/", suffix, "\\a\\1\\2\\3\\a\\s\\a\\das");
  }
}

static void test_parse_url_query(const td::string &query, const td::vector<td::string> &path,
                                 const td::vector<std::pair<td::string, td::string>> &args) {
  for (auto hash : {"", "#", "#?t=1", "#t=1&a=b"}) {
    auto url_query = td::parse_url_query(query + hash);
    ASSERT_EQ(path, url_query.path_);
    ASSERT_EQ(args, url_query.args_);
  }
}

TEST(HttpUrl, parse_url_query) {
  test_parse_url_query("", {}, {});
  test_parse_url_query("a", {"a"}, {});
  test_parse_url_query("/", {}, {});
  test_parse_url_query("//", {}, {});
  test_parse_url_query("///?a", {}, {{"a", ""}});
  test_parse_url_query("/a/b/c/", {"a", "b", "c"}, {});
  test_parse_url_query("/a/b/?c/", {td::string("a"), td::string("b")}, {{"c/", ""}});
  test_parse_url_query("?", {}, {});
  test_parse_url_query("???", {}, {{"??", ""}});
  test_parse_url_query("?a=b=c=d?e=f=g=h&x=y=z?d=3&", {}, {{"a", "b=c=d?e=f=g=h"}, {"x", "y=z?d=3"}});
  test_parse_url_query("c?&&&a=b", {"c"}, {{"a", "b"}});
  test_parse_url_query("c?&&&=b", {"c"}, {});
}
