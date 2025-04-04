//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/net/HttpOutboundConnection.h"
#include "td/net/HttpQuery.h"
#include "td/net/SslCtx.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

class Wget final : public HttpOutboundConnection::Callback {
 public:
  Wget(Promise<unique_ptr<HttpQuery>> promise, string url, std::vector<std::pair<string, string>> headers = {},
       int32 timeout_in = 10, int32 ttl = 3, bool prefer_ipv6 = false,
       SslCtx::VerifyPeer verify_peer = SslCtx::VerifyPeer::On, string content = {}, string content_type = {});

 private:
  Status try_init();
  void loop() final;
  void handle(unique_ptr<HttpQuery> result) final;
  void on_connection_error(Status error) final;
  void on_ok(unique_ptr<HttpQuery> http_query_ptr);
  void on_error(Status error);

  void tear_down() final;
  void start_up() final;
  void timeout_expired() final;

  Promise<unique_ptr<HttpQuery>> promise_;
  ActorOwn<HttpOutboundConnection> connection_;
  string input_url_;
  std::vector<std::pair<string, string>> headers_;
  int32 timeout_in_;
  int32 ttl_;
  bool prefer_ipv6_ = false;
  SslCtx::VerifyPeer verify_peer_;
  string content_;
  string content_type_;
};

}  // namespace td
