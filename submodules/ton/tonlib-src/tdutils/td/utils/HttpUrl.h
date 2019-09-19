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
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class HttpUrl {
 public:
  enum class Protocol { HTTP, HTTPS } protocol_ = Protocol::HTTP;
  string userinfo_;
  string host_;
  bool is_ipv6_ = false;
  int specified_port_ = 0;
  int port_ = 0;
  string query_;

  string get_url() const;

  HttpUrl(Protocol protocol, string userinfo, string host, bool is_ipv6, int specified_port, int port, string query)
      : protocol_(protocol)
      , userinfo_(std::move(userinfo))
      , host_(std::move(host))
      , is_ipv6_(is_ipv6)
      , specified_port_(specified_port)
      , port_(port)
      , query_(std::move(query)) {
  }
};

Result<HttpUrl> parse_url(Slice url,
                          HttpUrl::Protocol default_protocol = HttpUrl::Protocol::HTTP) TD_WARN_UNUSED_RESULT;

StringBuilder &operator<<(StringBuilder &sb, const HttpUrl &url);

string get_url_query_file_name(const string &query);

string get_url_file_name(Slice url);

}  // namespace td
