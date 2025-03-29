//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/HttpUrl.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Parser.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/SliceBuilder.h"

#include <algorithm>

namespace td {

string HttpUrl::get_url() const {
  string result;
  switch (protocol_) {
    case Protocol::Http:
      result += "http://";
      break;
    case Protocol::Https:
      result += "https://";
      break;
    default:
      UNREACHABLE();
  }
  if (!userinfo_.empty()) {
    result += userinfo_;
    result += '@';
  }
  result += host_;
  if (specified_port_ > 0) {
    result += ':';
    result += to_string(specified_port_);
  }
  LOG_CHECK(!query_.empty() && query_[0] == '/') << query_;
  result += query_;
  return result;
}

Result<HttpUrl> parse_url(Slice url, HttpUrl::Protocol default_protocol) {
  // url == [https?://][userinfo@]host[:port]
  ConstParser parser(url);
  string protocol_str = to_lower(parser.read_till_nofail(":/?#@[]"));

  HttpUrl::Protocol protocol;
  if (parser.try_skip("://")) {
    if (protocol_str == "http") {
      protocol = HttpUrl::Protocol::Http;
    } else if (protocol_str == "https") {
      protocol = HttpUrl::Protocol::Https;
    } else {
      return Status::Error("Unsupported URL protocol");
    }
  } else {
    parser = ConstParser(url);
    protocol = default_protocol;
  }
  Slice userinfo_host_port = parser.read_till_nofail("/?#");

  int port = 0;
  const char *colon = userinfo_host_port.end() - 1;
  while (colon > userinfo_host_port.begin() && *colon != ':' && *colon != ']' && *colon != '@') {
    colon--;
  }
  Slice userinfo_host;
  if (colon > userinfo_host_port.begin() && *colon == ':') {
    Slice port_slice(colon + 1, userinfo_host_port.end());
    while (port_slice.size() > 1 && port_slice[0] == '0') {
      port_slice.remove_prefix(1);
    }
    auto r_port = to_integer_safe<int>(port_slice);
    if (r_port.is_error() || r_port.ok() == 0) {
      port = -1;
    } else {
      port = r_port.ok();
    }
    userinfo_host = Slice(userinfo_host_port.begin(), colon);
  } else {
    userinfo_host = userinfo_host_port;
  }
  if (port < 0 || port > 65535) {
    return Status::Error("Wrong port number specified in the URL");
  }

  auto at_pos = userinfo_host.rfind('@');
  Slice userinfo = at_pos == static_cast<size_t>(-1) ? "" : userinfo_host.substr(0, at_pos);
  Slice host = userinfo_host.substr(at_pos + 1);

  bool is_ipv6 = false;
  if (!host.empty() && host[0] == '[' && host.back() == ']') {
    IPAddress ip_address;
    if (ip_address.init_ipv6_port(host.str(), 1).is_error()) {
      return Status::Error("Wrong IPv6 address specified in the URL");
    }
    CHECK(ip_address.is_ipv6());
    is_ipv6 = true;
  }
  if (host.empty()) {
    return Status::Error("URL host is empty");
  }
  if (host == ".") {
    return Status::Error("Host is invalid");
  }

  int specified_port = port;
  if (port == 0) {
    if (protocol == HttpUrl::Protocol::Http) {
      port = 80;
    } else {
      CHECK(protocol == HttpUrl::Protocol::Https);
      port = 443;
    }
  }

  Slice query = parser.read_all();
  while (!query.empty() && is_space(query.back())) {
    query.remove_suffix(1);
  }
  if (query.empty()) {
    query = Slice("/");
  }
  string query_str;
  if (query[0] != '/') {
    query_str = '/';
  }
  for (auto c : query) {
    if (static_cast<unsigned char>(c) <= 0x20) {
      query_str += '%';
      query_str += "0123456789ABCDEF"[c / 16];
      query_str += "0123456789ABCDEF"[c % 16];
    } else {
      query_str += c;
    }
  }

  auto check_url_part = [](Slice part, Slice name, bool allow_colon) {
    for (size_t i = 0; i < part.size(); i++) {
      char c = part[i];
      if (is_alnum(c) || c == '.' || c == '-' || c == '_' || c == '!' || c == '$' || c == ',' || c == '~' || c == '*' ||
          c == '\'' || c == '(' || c == ')' || c == ';' || c == '&' || c == '+' || c == '=' ||
          (allow_colon && c == ':')) {
        // symbols allowed by RFC 7230 and RFC 3986
        continue;
      }
      if (c == '%') {
        c = part[++i];
        if (is_hex_digit(c)) {
          c = part[++i];
          if (is_hex_digit(c)) {
            // percent encoded symbol as allowed by RFC 7230 and RFC 3986
            continue;
          }
        }
        return Status::Error(PSLICE() << "Wrong percent-encoded symbol in URL " << name);
      }

      // all other symbols aren't allowed
      auto uc = static_cast<unsigned char>(c);
      if (uc >= 128) {
        // but we allow plain UTF-8 symbols
        continue;
      }
      return Status::Error(PSLICE() << "Disallowed character in URL " << name);
    }
    return Status::OK();
  };

  string host_str = to_lower(host);
  if (is_ipv6) {
    for (size_t i = 1; i + 1 < host_str.size(); i++) {
      char c = host_str[i];
      if (c == ':' || ('0' <= c && c <= '9') || ('a' <= c && c <= 'f') || c == '.') {
        continue;
      }
      return Status::Error("Wrong IPv6 URL host");
    }
  } else {
    TRY_STATUS(check_url_part(host_str, "host", false));
    TRY_STATUS(check_url_part(userinfo, "userinfo", true));
  }

  return HttpUrl{protocol, userinfo.str(), std::move(host_str), is_ipv6, specified_port, port, std::move(query_str)};
}

StringBuilder &operator<<(StringBuilder &sb, const HttpUrl &url) {
  sb << tag("protocol", url.protocol_ == HttpUrl::Protocol::Http ? "HTTP" : "HTTPS") << tag("userinfo", url.userinfo_)
     << tag("host", url.host_) << tag("port", url.port_) << tag("query", url.query_);
  return sb;
}

HttpUrlQuery parse_url_query(Slice query) {
  if (!query.empty() && query[0] == '/') {
    query.remove_prefix(1);
  }

  size_t path_size = 0;
  while (path_size < query.size() && query[path_size] != '?' && query[path_size] != '#') {
    path_size++;
  }

  HttpUrlQuery result;
  result.path_ = full_split(url_decode(query.substr(0, path_size), false), '/');
  while (!result.path_.empty() && result.path_.back().empty()) {
    result.path_.pop_back();
  }

  if (path_size < query.size() && query[path_size] == '?') {
    query = query.substr(path_size + 1);
    query.truncate(query.find('#'));

    ConstParser parser(query);
    while (!parser.data().empty()) {
      auto key_value = split(parser.read_till_nofail('&'), '=');
      parser.skip_nofail('&');
      auto key = url_decode(key_value.first, true);
      if (!key.empty()) {
        result.args_.emplace_back(std::move(key), url_decode(key_value.second, true));
      }
    }
    CHECK(parser.status().is_ok());
  }

  return result;
}

bool HttpUrlQuery::has_arg(Slice key) const {
  auto it =
      std::find_if(args_.begin(), args_.end(), [&key](const std::pair<string, string> &s) { return s.first == key; });
  return it != args_.end();
}

Slice HttpUrlQuery::get_arg(Slice key) const {
  auto it =
      std::find_if(args_.begin(), args_.end(), [&key](const std::pair<string, string> &s) { return s.first == key; });
  return it == args_.end() ? Slice() : it->second;
}

string get_url_host(Slice url) {
  auto r_http_url = parse_url(url);
  if (r_http_url.is_error()) {
    return string();
  }
  return r_http_url.ok().host_;
}

string get_url_query_file_name(const string &query) {
  Slice query_slice = query;
  query_slice.truncate(query.find_first_of("?#"));

  auto slash_pos = query_slice.rfind('/');
  if (slash_pos < query_slice.size()) {
    return query_slice.substr(slash_pos + 1).str();
  }
  return query_slice.str();
}

string get_url_file_name(Slice url) {
  auto r_http_url = parse_url(url);
  if (r_http_url.is_error()) {
    LOG(WARNING) << "Receive wrong URL \"" << url << '"';
    return string();
  }
  return get_url_query_file_name(r_http_url.ok().query_);
}

}  // namespace td
